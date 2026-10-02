# Install.jl — `gbg install [--dev-checkout <path>]`: the shim and the registered dev checkout.

"""
    shim_source() -> String

The path of `bin/gbg` inside the running copy — the shim body `gbg install` copies and `SHIM.HASH`
compares against `~/.local/bin/gbg`. Returns the path.
"""
shim_source() = joinpath(pkgdir(GBGCodingTools), "bin", "gbg")

"""
    shim_target() -> String

The path the shim is installed at, `~/.local/bin/gbg`. Returns the path.
"""
shim_target() = joinpath(homedir(), ".local", "bin", "gbg")

"""
    dev_pointer() -> String

The path of the per-machine dev-checkout pointer, `~/.gbg/dev` — one line, the absolute path of the
dev checkout; nothing else lives under `~/.gbg/`. Returns the path.
"""
dev_pointer() = joinpath(homedir(), ".gbg", "dev")

"""
    julia_floor_ok() -> Bool

Whether the running Julia is at or above the tool's floor (`julia = "1.12"`). Returns the comparison.
"""
julia_floor_ok() = VERSION >= JULIA_FLOOR

"""
    cmd_install(args) -> Int

`gbg install [--dev-checkout <path>]`: copies the running copy's `bin/gbg` to `~/.local/bin/gbg`,
mode 755, and with the option writes the one-line pointer `~/.gbg/dev`; `gbg install --gitleaks`
installs the leak scan's pinned Gitleaks instead
([`Publication.install`](@ref GBGCodingTools.Publication.install)). It runs from whichever copy Pkg
resolved; no depot glob is expanded. Returns 0 when done, 2 when the Julia in use is below the floor,
when `--dev-checkout` names no `GBGCodingTools` checkout, or when `~/.local/bin` is not on `PATH`, where
the shim would never be found.
"""
function cmd_install(args)
    o = parse_options(args; valued = ["dev-checkout"])
    # The leak scan's engine, pinned and checked (§3.1); the one install that reaches the network.
    "gitleaks" in o.flags && return Publication.install()
    if !julia_floor_ok()
        println(stderr, "gbg install: julia $(VERSION) is below the floor $(JULIA_FLOOR); use juliaup"); return 2
    end
    bindir = dirname(shim_target())
    onpath = any(p -> abspath(p) == abspath(bindir), split(get(ENV, "PATH", ""), ':'))
    if !onpath
        println(stderr, "gbg install: $bindir is not on PATH; add it before installing the shim"); return 2
    end
    if haskey(o.values, "dev-checkout")
        dev = abspath(expanduser(o.values["dev-checkout"]))
        proj = joinpath(dev, "Project.toml")
        if !(isfile(proj) && get(TOML.parsefile(proj), "name", "") == PKG_NAME)
            println(stderr, "gbg install: $dev is not a GBGCodingTools checkout (no Project.toml naming it)"); return 2
        end
        mkpath(dirname(dev_pointer()))
        write(dev_pointer(), dev * "\n")
        println("wrote ", dev_pointer(), " → ", dev)
    end
    mkpath(bindir)
    cp(shim_source(), shim_target(); force = true)
    chmod(shim_target(), 0o755)
    println("installed ", shim_target(), " from ", shim_source())
    return 0
end
VERBS["install"] = cmd_install
