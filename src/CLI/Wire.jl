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
states out loud — it reports drift on every build so that nothing is lost silently.
"""
module Wire

using TOML

using ..GBGCodingTools: GBGCodingTools, ConfigIO, Model, Render, parse_options, VERBS

"""
    CONFIG_SEED

The `.gbg/config.jl` a package receives at `init`: its name (from its `Project.toml`), the pin, and the
two commands this package runs on its behalf. Everything else has a default, and a package writes a line only where the default
is wrong for it — a config full of restated defaults is a config nobody reads.
"""
const CONFIG_SEED = """
# .gbg/config.jl — this package's settings, as data.
#
# Read by `ConfigIO`, which parses this file and evaluates nothing: only literals and the constructors
# of `Model` are accepted. Every field not written here takes its default; write a line only where the
# default is wrong for this package.
Config(
    package = "{PACKAGE}",
    tool = :dev,
    docs_build = ["julia", "--project=docs", "docs/make.jl"],
    test = ["julia", "--project", "-e", "using Pkg; Pkg.test()"],
)
"""

"""
    init(root; io = stdout) -> Int

Writes `.gbg/config.jl` for the package at `root` if it has none, then writes every generated file. The
arguments are:

- `root` — the package root.
- `io` — where the report goes.

It NEVER overwrites an existing config: a package's config is the one file here that is the package's
own, holding what it has switched off and why, and a verb that rewrote it would throw that away on a
re-run. Where one exists, this is `sync` and says so.

Exit 0 when the package is wired, 2 when the config it wrote or found cannot be read.
"""
function init(root::AbstractString; io::IO = stdout)
    path = joinpath(root, ".gbg", "config.jl")
    if isfile(path)
        println(io, "init: ", relpath(path, root), " exists and is kept — this is `gbg sync`.")
    else
        mkpath(dirname(path))
        # The name comes from `Project.toml`, never from the directory: a checkout may sit in a directory
        # called anything, and a config that names the directory is wrong in a way every later check
        # inherits — the rules that ask "is this mention the package's own name?" all read this field.
        proj = joinpath(root, "Project.toml")
        name = isfile(proj) ? get(TOML.parsefile(proj), "name", "") : ""
        isempty(name) && (name = basename(abspath(root)))
        write(path, replace(CONFIG_SEED, "{PACKAGE}" => name))
        println(io, "init: wrote ", relpath(path, root), " — read it, then commit it.")
    end
    return sync(root; io)
end

"""
    sync(root; check = false, io = stdout) -> Int

Writes every generated file of the package at `root`, or, with `check`, reports which of them is not
what the running copy would write and changes nothing. The arguments are:

- `root` — the package root.
- `check` — report instead of writing.
- `io` — where the report goes.

Exit 0 when the package is wired (or, under `check`, already was), 1 when `check` found drift, 2 when
the config cannot be read.
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

    changed = Render.write_all(cfg, root)
    isempty(changed) ? println(io, "sync: already wired at ", Render.version_tag(cfg), "; nothing written.") :
                       println(io, "sync: wrote ", length(changed), " path(s) at ", Render.version_tag(cfg), ":")
    for p in changed; println(io, "  ", p); end
    return 0
end

function cmd_init(args)
    o = parse_options(args)
    return init(isempty(o.positional) ? pwd() : o.positional[1])
end

function cmd_sync(args)
    o = parse_options(args)
    return sync(GBGCodingTools.Config.find_root(); check = "check" in o.flags)
end

VERBS["init"] = cmd_init
VERBS["sync"] = cmd_sync

end # module Wire
