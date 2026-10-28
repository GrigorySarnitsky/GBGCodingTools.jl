# The design's §11; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Bump

`gbg bump <version>`: moves a package's pin to a released version of this one and rewrites its wiring
at that version.

It moves the pin and regenerates; it checks nothing first. The new version's rules are not installed
until the environments move, after the bump, so a check here ran the old rules and could refuse nothing
it existed to refuse (removed 2026-09-27, the owner's word). The package's next docs build and test run
the new rules, and that is where a newer rulebook's opinions about its prose appear.
"""
module Bump

using TOML
using ..GBGCodingTools: GBGCodingTools, ConfigIO, Model, Render, parse_options, VERBS

"""
    set_pin(root, version) -> Bool

Rewrites the `tool` line of the package's `.gbg/config.jl` to name `version`. The arguments are `root`,
the package root, and `version`, the released version. Returns whether the line was found and changed.

The file is a Julia expression read as data, so the line is rewritten rather than the file regenerated:
everything else in it — what the package has switched off, and why — is the package's own text, and a
verb that rewrote it would lose the reasons.
"""
function set_pin(root::AbstractString, version::VersionNumber)
    path = joinpath(root, ".gbg", "config.jl")
    isfile(path) || return false
    text = read(path, String)
    new = replace(text, r"(?m)^(\s*tool\s*=\s*)(:dev|v\"[^\"]*\")" => SubstitutionString("\\1v\"$version\""); count = 1)
    new == text && return false
    write(path, new)
    return true
end

"""
    bump(root, version; io = stdout) -> Int

Moves the pin of the package at `root` to `version` and rewrites its wiring.

# Arguments

- `root` — the package root.
- `version` — the released version to pin, `X.Y.Z`.
- `io` — where the report goes.

Exit 0 when the pin moved, 1 when a generated path is the package's own file and was kept, 2 when the
config, or an environment's `Project.toml`, could not be read, or the pin line could not be found.

A prerelease may be pinned. It was refused here until 2026-09-18, on the reasoning that a candidate is
not a release; the refusal bought nothing and the cost was concrete. A tag is immutable whether or not
it carries `-rc.N`, so a candidate resolves from GitHub exactly as a release does.

Refusing it left the first wired package pinned to an absolute path on one machine, its CI resolving
nothing and running none of these rules, for as long as the final release was away. What judges a pin
is the package's next build, under the new version, whatever the version is called.
"""
function bump(root::AbstractString, version::VersionNumber; io::IO = stdout)
    cfg = try
        ConfigIO.read_config(root)
    catch err
        err isa ConfigIO.ConfigError || rethrow()
        println(io, sprint(showerror, err))
        return 2
    end

    # an environment that does not parse would be left behind on the old pin, so nothing moves at all
    broken = [e for e in Render.pin_envs(root) if isfile(joinpath(root, e, "Project.toml")) &&
                                                  !(TOML.tryparse(read(joinpath(root, e, "Project.toml"), String)) isa Dict)]
    isempty(broken) || (println(io, "bump: ", join(broken .* "/Project.toml", ", "), " does not parse; fix it first"); return 2)
    set_pin(root, version) || (println(io, "bump: no `tool = …` line in .gbg/config.jl to move"); return 2)
    cfg = ConfigIO.read_config(root)                 # we just wrote it; failing to read it back is a crash
    changed, refused = Render.write_all(cfg, root)
    println(io, "bump: pinned at v", version, "; ", length(changed), " path(s) rewritten.")
    for p in changed; println(io, "  ", p); end
    println(io, "Commit the config and the rewritten paths together: the pin and what it generates are one change.")
    if !isempty(refused)
        println(io, "bump: these paths are the package's own, not a generator's, and were not written over:")
        for (p, line) in refused; println(io, "  ", p, "\n      it begins: ", first(line, 70)); end
    end
    stale_warning(io, version, pkgversion(GBGCodingTools), root)
    return isempty(refused) ? 0 : 1
end

"""
    stale_warning(io, version, running, root)

Says that what was just written is the running version's, not the pinned one's, and prints the commands
that move each environment onto the pinned tag.

# Arguments

- `io` — where it goes.
- `version` — the version just pinned.
- `running` — the version of the copy that wrote.
- `root` — the package root, whose environments the commands move.

The pin moves first and the regeneration follows, and the regeneration runs on the code that is loaded —
which is the version the environment's manifest still holds, not the one just pinned. So every generated file it writes is the
old version's content under the new version's banner: a file the new version would add is absent, and a
file it would word differently is worded the old way. [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/) met this on 2026-09-22 going
from rc.5 to rc.7 — sixteen paths where twenty were due, with the new rulebook file and three skills
missing — and the drift is invisible until the next build runs the wiring check.

It cannot be fixed by regenerating harder: the right content does not exist in this process. What closes
it is resolving the environments onto the new tag and running `gbg sync` again, under the new code. Each
environment's command is the one [`move_command`](@ref) returns for it.
"""
function stale_warning(io::IO, version, running, root::AbstractString)
    println(io, "")
    println(io, "NOT FINISHED. What was just written is v", running, "'s content under a v", version, " banner,")
    println(io, "and the rules that let the pin move were v", running, "'s too: `bump` runs with the code that")
    println(io, "is RUNNING, and the running code is whatever the environments' manifests still hold — not")
    println(io, "what you have just pinned. Move them, then regenerate under the new code:")
    println(io, "")
    for env in Render.pin_envs(root)
        c = move_command(root, env)
        isempty(c) || println(io, "    ", c)
    end
    println(io, "    gbg sync")
    println(io, "")
    println(io, "`Pkg.update` where a manifest exists, and not `Pkg.resolve`: a resolve keeps what the manifest")
    println(io, "holds, so it keeps the tool's old tree hash under the new revision (seen at rc.4 and rc.7), and it")
    println(io, "fails where the tool cannot sit beside a version the manifest holds (Parsers 3, GBGCloudPhysics,")
    println(io, "2026-10-28). Where there is no manifest there is nothing to keep and a resolve fetches the tag;")
    println(io, "a test environment with no manifest is resolved by `Pkg.test()` itself.")
end

"""
    move_command(root, env) -> String

The command that moves the environment `env` of the package at `root` onto the tag just pinned, or an
empty string when there is nothing to move. The arguments are `root`, the package root, and `env`, the
environment's directory under it, one of `Render.pin_envs`.

Returns an update of the whole environment where it has a manifest, and a resolve where it has none. A
test environment with no manifest gets nothing: `Pkg.test()` resolves it, and resolving it alone fails
when it names an unregistered package that only the root environment says where to find.

The update alone was printed until 2026-09-28, and on a first wiring it fails: an update of a package
no manifest holds says "expected package `GBGCodingTools` to be registered". Both environments of
[GBGHomogeneousTurbulence](https://grigorysarnitsky.github.io/GBGHomogeneousTurbulence.jl/) failed so in its wiring rehearsal.
And a resolve of a manifest that does not hold the tool keeps every version it holds: a package's docs
manifest held Parsers 3, which the tool's JSON3 does not accept, and its resolve failed where an update
moved Parsers back (a wiring rehearsal, 2026-10-28).
"""
function move_command(root::AbstractString, env::AbstractString)
    isfile(joinpath(root, env, "Project.toml")) || return ""
    # Julia reads a version's own manifest, `Manifest-v1.12.toml`, before the plain one; the plain one was
    # the only one looked at, and a versioned one holding the tool got the resolve that keeps its old hash.
    manifests = filter(f -> occursin(r"^Manifest(-v[0-9.]+)?\.toml$", f), readdir(joinpath(root, env)))
    if isempty(manifests)
        env == "test" && return ""
        return "julia --project=\"$env\" -e 'using Pkg; Pkg.resolve()'"
    end
    return "julia --project=\"$env\" -e 'using Pkg; Pkg.update()'"
end

function cmd_bump(args)
    o = parse_options(args)
    isempty(o.positional) && (println(stderr, "usage: gbg bump <version>"); return 2)
    v = tryparse(VersionNumber, o.positional[1])
    v === nothing && (println(stderr, "bump: $(o.positional[1]) is not a version"); return 2)
    root = ConfigIO.require_root("bump")
    root === nothing && return 2
    return bump(root, v)
end
VERBS["bump"] = cmd_bump

end # module Bump
