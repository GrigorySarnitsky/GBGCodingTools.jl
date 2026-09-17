# Config.jl — `Config.read`: TOML.parsefile of .gbg/config.toml, validated by Schema.jl, defaults
# materialised, every path checked. The object it returns is what every other module receives and what
# `gbg config --toml|--json` prints.

"""
    Config

The loader of a consumer's `.gbg/config.toml`. [`Config.read`](@ref) is the one way the config is
obtained — by every verb and by the `makedocs` wrapper — and
[`Config.ConfigError`](@ref) is what a config that cannot be used raises; [`Config.find_root`](@ref)
finds the consumer root a directory lies in, and [`Config.check_paths`](@ref) runs every existence check
the config implies (the doctor's `CFG.SURFACES`). The helpers [`Config.glob_files`](@ref), over
[`Config.glob_to_regex`](@ref), and [`Config.resolve_anchor`](@ref) are the two readers of the config's path vocabulary (globs and
`file#heading` anchors), shared with the doctor and the scans.

Two words this package overloads, both first met here. A SURFACE is the config's unit of "what gets
read": a named set of files — `rationale`, `pages`, `src`, `ext`, `literate`, `data`, and the compounds
`docs` and `all` — that every scan, engine, doctor check and instrument works over. An ANCHOR here is a
`file#heading` reference into a document, and NOTHING else: elsewhere the same word is a hat or lane
that runs at full strength rather than on the economy model (`Preflight.resolve_hats`), and a regular
expression marking where a seed is planted (`Seeds.select`). Three unrelated senses, one word.

The ECONOMY MODEL is the cheaper AI model the tool's model catalogue names (`Preflight.economy_model`):
in an economy round every lane and hat that is not an anchor runs on it, and an anchor runs at full
strength, on the session's own model.
"""
module Config

using TOML, Dates
import ..GBGCodingTools
import ..GBGCodingTools: load_schema, validate, materialize!, SchemaError

export ConfigError

"""
    ConfigError <: Exception

A config that cannot be used: absent, unparsable, invalid against the schema, or naming a path that
does not resolve. The fields are:

- `msg` — the message, with every violation listed.
"""
struct ConfigError <: Exception
    msg::String
end
Base.showerror(io::IO, e::ConfigError) = print(io, "config error: ", e.msg)

"""
    ConfigWrittenError <: Exception

A config the running verb wrote ITSELF did not read back. The fields are:

- `msg` — the underlying [`ConfigError`](@ref)'s message.

Deliberately not a subtype of `ConfigError`. The command line reports a `ConfigError` as exit 2, "cannot
evaluate": the consumer's config is bad and the consumer can fix it. A config this tool has just written
failing to validate is a defect of the tool, not of the consumer, so it must reach the crash path — exit 3
with its backtrace — and a subtype would be caught as the consumer's mistake.
"""
struct ConfigWrittenError <: Exception
    msg::String
end
Base.showerror(io::IO, e::ConfigWrittenError) =
    print(io, "a config this verb just wrote does not read back (a tool defect, not the consumer's): ", e.msg)

"""
    read_written(root; check = true) -> Dict

[`read`](@ref) for a config the calling verb has itself just written. The arguments are:

- `root` — the consumer root.
- `check` — whether to run the path check, as for `read`.

Returns what `read` returns; throws a [`ConfigWrittenError`](@ref) where `read` would throw a
`ConfigError`, so the failure is reported as the tool's crash rather than as the consumer's bad config.
"""
function read_written(root::AbstractString; check::Bool = true)
    try
        return read(root; check)
    catch err
        err isa ConfigError || rethrow()
        throw(ConfigWrittenError(err.msg))
    end
end

"""
    find_root(start = pwd()) -> Union{String,Nothing}

Walks up from `start` to the first directory holding `.gbg/config.toml` — the consumer root, the same
walk the shim does. Returns that directory, or `nothing` when none is found.
"""
function find_root(start::AbstractString = pwd())
    d = abspath(start)
    while true
        isfile(joinpath(d, ".gbg", "config.toml")) && return d
        p = dirname(d)
        p == d && return nothing
        d = p
    end
end

"""
    glob_to_regex(pattern) -> Regex

Turns a glob over `/`-separated relative paths into a regex: `**` matches any run of directories
(including none), `*` any run of characters within one segment, `?` one character. Returns the anchored
regex.
"""
function glob_to_regex(pattern::AbstractString)
    out = IOBuffer(); write(out, '^')
    i = 1; n = lastindex(pattern)
    while i <= n
        c = pattern[i]
        if c == '*' && i < n && pattern[nextind(pattern, i)] == '*'
            j = nextind(pattern, nextind(pattern, i))
            if j <= n && pattern[j] == '/'
                write(out, "(?:.*/)?"); i = nextind(pattern, j)
            else
                write(out, ".*"); i = j
            end
            continue
        elseif c == '*'
            write(out, "[^/]*")
        elseif c == '?'
            write(out, "[^/]")
        elseif c in ".+()^\$|{}[]\\"
            write(out, '\\', c)
        else
            write(out, c)
        end
        i = nextind(pattern, i)
    end
    write(out, '$')
    return Regex(String(take!(out)))
end

"""
    glob_files(root, pattern) -> Vector{String}

Every regular file under `root` whose `/`-separated relative path matches the glob `pattern`
(see [`glob_to_regex`](@ref)), as relative paths, sorted. A pattern without a wildcard names one file
and matches it if it exists. Returns the list, empty when nothing matches.
"""
function glob_files(root::AbstractString, pattern::AbstractString)
    if !occursin(r"[*?\[]", pattern)
        return isfile(joinpath(root, pattern)) ? [String(pattern)] : String[]
    end
    re = glob_to_regex(pattern)
    # walk only the fixed prefix of the pattern
    prefix = join(Iterators.takewhile(s -> !occursin(r"[*?\[]", s), split(pattern, '/')), "/")
    base = isempty(prefix) ? root : joinpath(root, prefix)
    isdir(base) || return String[]
    hits = String[]
    for (dir, _, files) in walkdir(base; follow_symlinks = false)
        for f in files
            rel = relpath(joinpath(dir, f), root)
            occursin(re, rel) && push!(hits, rel)
        end
    end
    return sort!(hits)
end

"""
    resolve_anchor(root, anchor) -> (file, line, count)

Resolves a `file#heading` ANCHOR — this sense of the word only, a Markdown reference to one heading.
A hat's or lane's `anchor` is a different thing (whether it runs at full strength rather than on the
economy model the module docstring defines, `Preflight.resolve_hats`), and a seed class's a third
(`Seeds.select`).
Here: `file` relative to `root`, `heading` a prefix of the text of exactly
one Markdown heading (any `#` level) in it. Returns the file, the 1-based line of the match and the
number of headings that matched — `0` or `2+` is a config error to the caller; the line is `0` when
the file is absent or nothing matched.
"""
function resolve_anchor(root::AbstractString, anchor::AbstractString)
    k = findfirst('#', anchor)
    k === nothing && return (anchor, 0, 0)
    file = anchor[1:prevind(anchor, k)]; text = strip(anchor[nextind(anchor, k):end])
    path = joinpath(root, file)
    isfile(path) || return (file, 0, 0)
    line = 0; count = 0; infence = false
    for (i, l) in enumerate(eachline(path))
        startswith(l, "```") && (infence = !infence)
        infence && continue
        m = match(r"^#{1,6}\s+(.*?)\s*$", l)
        m === nothing && continue
        if startswith(m.captures[1], text)
            count += 1; line == 0 && (line = i)
        end
    end
    return (file, line, count)
end

"""
    surface_files(cfg, key) -> Vector{String}

The files of one surface key of `cfg["surfaces"]` — `rationale`, `pages`, `src`, `ext`, `literate`,
`data`, or the compound keys `docs` (rationale + pages + literate) and `all` (docs + src + ext) —
relative to the
root, each file once, sorted. Generated pages (`surfaces.generated.globs`) are removed from `pages`,
since they are build products. Returns the list.
"""
function surface_files(cfg::AbstractDict, key::AbstractString)
    root = cfg["root"]; s = cfg["surfaces"]
    keys_ = key == "docs" ? ["rationale", "pages", "literate"] :
            key == "all" ? ["rationale", "pages", "literate", "src", "ext"] : [key]
    files = String[]
    for k in keys_
        for g in get(s, k, String[])
            append!(files, glob_files(root, g))
        end
    end
    gen = Set(Iterators.flatten(glob_files(root, g) for g in get(get(s, "generated", Dict()), "globs", String[])))
    return sort!(unique!(filter!(f -> !(f in gen), files)))
end

"""
    check_paths(cfg) -> Vector{String}

Every existence check the config implies (the doctor's `CFG.SURFACES`): each non-optional surface glob
matches at least one file; each `file#heading` anchor resolves to exactly one heading; each module has
a `module <Name>` block under `src/`; each `[paths]` entry is a directory; the `glossary` file exists and
a non-empty `built_html` has a `docs/` directory beside it; each `extensions` file, the `docs/make.jl`
the config schema pins `docs_build` to name, each `executable_claims` file and, while `seed_rounds` is
on, the seed catalogue exist. Returns the problems found, empty when all hold.
"""
function check_paths(cfg::AbstractDict)
    root = cfg["root"]; errs = String[]
    s = cfg["surfaces"]
    for k in ("rationale", "pages", "src", "ext", "literate", "data")
        for g in get(s, k, String[])
            isempty(glob_files(root, g)) && push!(errs, "surfaces.$k: glob $(repr(g)) matches no file")
        end
    end
    if !get(s["generated"], "optional", true)
        for g in s["generated"]["globs"]
            isempty(glob_files(root, g)) && push!(errs, "surfaces.generated: glob $(repr(g)) matches no file")
        end
    end
    anchors = Pair{String,String}["surfaces.history_exempt" => s["history_exempt"]]
    s["references_heading"] != "absent" && push!(anchors, "surfaces.references_heading" => s["references_heading"])
    for (i, a) in enumerate(cfg["package"]["rulebook_sections"])
        push!(anchors, "package.rulebook_sections[$i]" => a)
    end
    ac = get(get(cfg, "instruments", Dict{String,Any}()), "audit-changes", Dict{String,Any}())
    haskey(ac, "invariants_section") && push!(anchors, "instruments.audit-changes.invariants_section" => ac["invariants_section"])
    for (what, a) in anchors
        file, line, count = resolve_anchor(root, a)
        if !isfile(joinpath(root, file))
            push!(errs, "$what: file $(repr(file)) does not exist")
        elseif count != 1
            push!(errs, "$what: heading of $(repr(a)) matched $count headings (need exactly one)")
        end
    end
    haskey(s, "glossary") && !isfile(joinpath(root, s["glossary"])) && push!(errs, "surfaces.glossary: $(repr(s["glossary"])) does not exist")
    !isempty(s["built_html"]) && !isdir(joinpath(root, "docs")) && push!(errs, "surfaces.built_html: no docs/ directory")
    for (k, p) in cfg["paths"]
        isdir(joinpath(root, p)) || push!(errs, "paths.$k: $(repr(p)) is not a directory")
    end
    for e in cfg["package"]["extensions"]
        isfile(joinpath(root, e)) || push!(errs, "package.extensions: $(repr(e)) does not exist")
    end
    # `docs_build` is pinned to name docs/make.jl by the config SCHEMA (`"pattern": "docs/make\\.jl"`), so
    # the command and the path cannot diverge and there is nothing here to parse: this checks the file
    # exists. Scanning the command for `.jl`-shaped words instead added a dead branch the schema makes
    # unreachable and a refusal that fired on any such word in it.
    isfile(joinpath(root, "docs", "make.jl")) || push!(errs, "package.docs_build: docs/make.jl does not exist")
    srcfiles = vcat((glob_files(root, g) for g in s["src"])...)
    for m in cfg["package"]["modules"]
        re = Regex("^\\s*(baremodule|module)\\s+" * m * "\\b", "m")
        any(f -> occursin(re, Base.read(joinpath(root, f), String)), srcfiles) || push!(errs, "package.modules: no `module $m` block under the src surface")
    end
    for (k, f) in get(ac, "executable_claims", Dict{String,Any}())
        (startswith(f, "test/") && isfile(joinpath(root, f))) || push!(errs, "instruments.audit-changes.executable_claims.$k: $(repr(f)) is not an existing file under test/")
    end
    cc = get(get(cfg, "instruments", Dict{String,Any}()), "check-consistency", Dict{String,Any}())
    if get(cc, "seed_rounds", false) && !isfile(joinpath(root, cc["seed_catalog"]))
        push!(errs, "instruments.check-consistency: seed_rounds = true but $(repr(cc["seed_catalog"])) does not exist")
    end
    return errs
end

"""
    read(root = find_root(); check = true) -> Dict

Loads `<root>/.gbg/config.toml`, validates it against `schema/config.schema.json`, materialises every
default and checks every path. The arguments are:

- `root` — the consumer root, found by walking up from the working directory when not given.
- `check` — whether to run the path check (false for a config read from a tree that is not fully
  present).

Returns the validated `Dict` with `cfg["root"]` set; throws a [`ConfigError`](@ref) otherwise.
"""
function read(root::Union{AbstractString,Nothing} = find_root(); check::Bool = true)
    root === nothing && throw(ConfigError("no .gbg/config.toml found walking up from $(pwd())"))
    root = abspath(root)
    path = joinpath(root, ".gbg", "config.toml")
    isfile(path) || throw(ConfigError("$path does not exist"))
    text = try
        Base.read(path, String)
    catch err
        throw(ConfigError("$path cannot be read: " * sprint(showerror, err)))
    end
    return parse(text; root, check)
end

"""
    Config.parse(text; root, check = true) -> Dict

The same validation, materialisation and path check as [`Config.read`](@ref) over the TOML `text` of a
config instead of the file under `root/.gbg/` — what the self-tests and the Step-0 scratch runs use to
describe a tree without writing into it. The arguments are:

- `text` — the config as TOML.
- `root` — the tree it describes.
- `check` — whether to run the path check.

Returns the validated `Dict` with `cfg["root"] = root`.
"""
function parse(text::AbstractString; root::AbstractString, check::Bool = true)
    root = abspath(root)
    cfg = try
        TOML.parse(String(text))
    catch err
        throw(ConfigError("config does not parse: " * sprint(showerror, err)))
    end
    schema = load_schema("config")
    errs = validate(schema, cfg)
    isempty(errs) || throw(ConfigError(".gbg/config.toml is invalid:\n  " * join(errs, "\n  ")))
    materialize!(schema, cfg)
    cfg["root"] = root
    if check
        perrs = check_paths(cfg)
        isempty(perrs) || throw(ConfigError(".gbg/config.toml names paths that do not resolve:\n  " * join(perrs, "\n  ")))
    end
    return cfg
end

"""
    expand_globs(root, files) -> Vector{String}

`files` with every glob replaced by the files it names, in order and deduplicated. The arguments are
`root`, the consumer root, and `files`, a lane's or a territory's list.

A pattern matching nothing is KEPT as written: a directory a lane names (`catalog`, `policy`) is not a
glob, and dropping it would silently empty that lane. Both roster resolvers share this one home, because
a lane receives its files VERBATIM in its prompt — an unexpanded `src/Scans/*.jl` reaches the agent as a
pattern rather than as the files it names, and the same unexpanded string never matches the engine's own
surface list when a refinement is subtracted from it. Returns the expanded list.
"""
expand_globs(root::AbstractString, files) =
    unique!(reduce(vcat, (isempty(glob_files(root, String(g))) ? [String(g)] : glob_files(root, String(g)) for g in files); init = String[]))

end # module Config

"""
    cmd_config(args) -> Int

`gbg config --toml|--json [--effective]`: prints the validated config with every default materialised —
the object `Config.read()` returns in-process. `--toml` (the default) prints TOML, `--json` prints JSON;
`--effective` adds the machine facts read at run time (`hostname`, `Threads.nthreads()`, the Julia
version and the running tool version) under a `[effective]` table. Returns 0, or 2 when the config
cannot be read (the reason is printed to `stderr`).
"""
function cmd_config(args)
    o = parse_options(args)
    cfg = try
        Config.read()
    catch err
        err isa Config.ConfigError || rethrow()
        println(stderr, sprint(showerror, err)); return 2
    end
    out = Dict{String,Any}(k => v for (k, v) in cfg if k != "root")
    if "effective" in o.flags
        out["effective"] = Dict("root" => cfg["root"], "hostname" => gethostname(),
            "nthreads" => Threads.nthreads(), "julia" => string(VERSION), "tool" => tool_version())
    end
    if "json" in o.flags
        JSON3.pretty(stdout, JSON3.write(out)); println()
    else
        TOML.print(stdout, out; sorted = true)
    end
    return 0
end
VERBS["config"] = cmd_config
