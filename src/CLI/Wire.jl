# The design's §6, §11; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Wire

The two verbs that write a package's wiring, `gbg init` and `gbg sync`. The first puts a package under
this one; the second brings an already-wired package up to what the running copy generates.

One module, because they are one act at two moments. The first writes the config a package could not
have written itself and then calls the second; everything after that is the second alone, and there is
no third path by which a generated file comes into being.

Neither merges. A generated file is the return value of a function, so there is nothing to merge WITH:
`sync` writes what the function returns, and a hand edit is lost. That is the bargain the wiring check
states out loud — it reports drift on every build so that nothing is lost silently. What is never lost
is a file the package wrote itself at a generated path: both verbs refuse it and say so.
"""
module Wire

using TOML

using ..GBGCodingTools: GBGCodingTools, ConfigIO, Model, Render, parse_options, VERBS

"""
    config_seed(root, name) -> String

The `.gbg/config.jl` a package receives at `init`: its name (from its `Project.toml`), the pin, and the
commands this package runs on its behalf — each only where the script it names is there, since a
config naming a `docs/make.jl` the package does not have is one its own `sync` refuses. The arguments
are `root`, the package root, and `name`, the package's name. Returns the file.

Everything else has a default, and a package writes a line only where the default is wrong for it — a
config full of restated defaults is a config nobody reads.
"""
function config_seed(root::AbstractString, name::AbstractString)
    lines = ["    package = \"$name\",", "    tool = :dev,"]
    isfile(joinpath(root, "docs", "make.jl")) &&
        push!(lines, "    docs_build = [\"julia\", \"--project=docs\", \"docs/make.jl\"],")
    isfile(joinpath(root, "test", "runtests.jl")) &&
        push!(lines, "    test = [\"julia\", \"--project\", \"-e\", \"using Pkg; Pkg.test()\"],")
    return """
    # .gbg/config.jl — this package's settings, as data.
    #
    # Read by `ConfigIO`, which parses this file and evaluates nothing: only literals and the constructors
    # of `Model` are accepted. Every field not written here takes its default; write a line only where the
    # default is wrong for this package.
    Config(
    $(join(lines, '\n'))
    )
    """
end

"""
    init(root; io = stdout) -> Int

Writes `.gbg/config.jl` for the package at `root` if it has none, then writes every generated file.

# Arguments

- `root` — the package root.
- `io` — where the report goes.

It NEVER overwrites an existing config: a package's config is the one file here that is the package's
own, holding what it has switched off and why, and a verb that rewrote it would throw that away on a
re-run. Where one exists, this is `sync` and says so.

Exit 0 when the package is wired, 1 when a generated path is already the package's own — nothing is
written, the first run included — and 2 when the config it wrote or found cannot be read.
"""
function init(root::AbstractString; io::IO = stdout)
    path = joinpath(root, ".gbg", "config.jl")
    # The name comes from `Project.toml`, never from the directory: a checkout may sit in a directory
    # called anything, and a config that names the directory is wrong in a way every later check
    # inherits — the rules that ask "is this mention the package's own name?" all read this field.
    proj = joinpath(root, "Project.toml")
    name = isfile(proj) ? get(TOML.parsefile(proj), "name", "") : ""
    isempty(name) && (name = basename(abspath(root)))
    seed = config_seed(root, name)
    # What the package wrote itself is never overwritten. This is asked BEFORE the config is written, so
    # a refusal leaves the package exactly as it was — on the first run against the config about to be
    # written, which until 2026-09-26 was the one run that never asked.
    cfg = if isfile(path)
        try ConfigIO.read_config(root) catch; nothing end
    else
        scratch = mktempdir(); write(joinpath(scratch, "config.jl"), seed)
        try ConfigIO.read_value(joinpath(scratch, "config.jl")) catch; nothing end
    end
    if cfg !== nothing
        clash = Render.collisions(cfg, root)
        if !isempty(clash)
            println(io, "init: these paths are the package's own, not a generator's, and are kept:")
            for (p, line) in clash; println(io, "  ", p, "\n      it begins: ", first(line, 70)); end
            println(io, "Move or keep each, then run `gbg init` again. Nothing was written.")
            return 1
        end
    end
    if isfile(path)
        println(io, "init: ", relpath(path, root), " exists and is kept — this is `gbg sync`.")
    else
        mkpath(dirname(path))
        write(path, seed)
        println(io, "init: wrote ", relpath(path, root), " — read it, then commit it.")
    end
    return sync(root; io)
end

"""
    sync(root; check = false, io = stdout) -> Int

Writes every generated file of the package at `root`, or, with `check`, reports which of them is not
what the running copy would write and changes nothing.

# Arguments

- `root` — the package root.
- `check` — report instead of writing.
- `io` — where the report goes.

Exit 0 when the package is wired (or, under `check`, already was), 1 when `check` found drift or a
generated path is the package's own file and was refused, 2 when the config cannot be read.
"""
function sync(root::AbstractString; check::Bool = false, io::IO = stdout)
    cfg = try
        ConfigIO.read_config(root)
    catch err
        err isa ConfigIO.ConfigError || rethrow()
        println(io, sprint(showerror, err))
        return 2
    end
    problems = ConfigIO.validate(cfg, root)
    if !isempty(problems)
        println(io, "sync: the config describes a package this is not:")
        for p in problems; println(io, "  - ", p); end
        return 2
    end

    if check
        drift = Render.wiring(cfg, root)
        if isempty(drift)
            println(io, "sync: ", length(Render.GENERATED), " generated path(s) and the pin are what ",
                    Render.version_tag(cfg), " writes.")
            return 0
        end
        for l in drift; println(io, "  ", rpad(l.file, 34), l.text); end
        println(io, "sync: ", length(drift), " path(s) adrift — run `gbg sync` to rewrite them.")
        return 1
    end

    changed, refused = Render.write_all(cfg, root)
    isempty(changed) ? println(io, "sync: already wired at ", Render.version_tag(cfg), "; nothing written.") :
                       println(io, "sync: wrote ", length(changed), " path(s) at ", Render.version_tag(cfg), ":")
    for p in changed; println(io, "  ", p); end
    isempty(refused) && return 0
    println(io, "sync: these paths are the package's own, not a generator's, and were not written over:")
    for (p, line) in refused; println(io, "  ", p, "\n      it begins: ", first(line, 70)); end
    println(io, "Move each, then run `gbg sync` again; the wiring check reports them until then.")
    return 1
end

"""
    package_root(start) -> Union{String,Nothing}

The package at or above `start`: the nearest directory whose `Project.toml` names a package. The
argument is `start`, where to begin. Returns the root, or `nothing` where no package encloses it.

A `Project.toml` alone is not a package. Every consumer's `docs/` and `test/` hold one, listing the
environment's dependencies and no `name`, and `gbg init` run from `PF/docs` wired `PF/docs` as a
package called `docs` — fifteen generated files in the wrong place, and a nested `.gbg/config.jl` that
then captured every later verb.
"""
function package_root(start::AbstractString)
    root = abspath(start)
    while true
        proj = joinpath(root, "Project.toml")
        if isfile(proj)
            named = try !isempty(get(TOML.parsefile(proj), "name", "")) catch; false end
            named && return root
        end
        parent = dirname(root)
        parent == root && return nothing
        root = parent
    end
end

function cmd_init(args)
    o = parse_options(args)
    isempty(o.positional) || return init(o.positional[1])
    root = package_root(pwd())
    root === nothing && (println(stderr, "init: no Project.toml naming a package here or above — run it in a package"); return 2)
    return init(root)
end

function cmd_sync(args)
    o = parse_options(args)
    root = ConfigIO.require_root("sync")
    root === nothing && return 2
    return sync(root; check = "check" in o.flags)
end

VERBS["init"] = cmd_init
VERBS["sync"] = cmd_sync

end # module Wire
