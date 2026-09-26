# The design's §11; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Bump

`gbg bump <version>`: moves a package's pin to a released version of this one and rewrites its wiring
at that version.

It runs the checks of the copy that is RUNNING first — `pkgversion`, the version the environment
resolved, which is the old pin until the environments move — and refuses to move the pin while any of
them finds something, printing the count per rule. A pin moved silently is a package that finds out at
its next build, on someone else's time, that a newer rulebook has opinions about its prose; a package
told first can fix what it wants to fix and switch off what it does not, and then bump.
"""
module Bump

using ..GBGCodingTools: GBGCodingTools, Catalogue, ConfigIO, Engine, Model, Render, parse_options, VERBS

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
    counts(cfg, root) -> Vector{Pair{Symbol,Int}}

How many findings each rule has in the package at `root`, most first. The arguments are `cfg`, the
package's config, and `root`, the package root. Returns one pair per rule that found anything.
"""
function counts(cfg::Model.Config, root::AbstractString)
    out = Dict{Symbol,Int}()
    for rule in Catalogue.RULES
        n = length(Engine.Checks.run_rule(rule, cfg, root))
        n > 0 && (out[rule.id] = n)
    end
    return sort!(collect(out), by = last, rev = true)
end

"""
    bump(root, version; io = stdout) -> Int

Moves the pin of the package at `root` to `version` and rewrites its wiring, or refuses and changes
nothing. The arguments are:

- `root` — the package root.
- `version` — the released version to pin, `X.Y.Z`.
- `io` — where the report goes.

Exit 0 when the pin moved, 1 when the running version's rules found something and it did not, or a
generated path is the package's own file, 2 when the config could not be read or the pin line could not
be found. The rules that guard the move are the RUNNING copy's, `pkgversion(GBGCodingTools)`, and the
report says so: they are the new version's only once the environments resolve it.

A PRERELEASE may be pinned. It was refused here until 2026-09-18, on the reasoning that a candidate is
not a release; the refusal bought nothing and the cost was concrete. A tag is immutable whether or not
it carries `-rc.N`, so a candidate resolves from GitHub exactly as a release does.

Refusing it left the first wired package pinned to an absolute path on one machine, its CI resolving
nothing and running none of these rules, for as long as the final release was away. What guards a bad
pin is the check below, which will not move a pin while the new version finds anything, and that guard
does not care what the version is called.
"""
function bump(root::AbstractString, version::VersionNumber; io::IO = stdout)
    cfg = try
        ConfigIO.read_config(root)
    catch err
        err isa ConfigIO.ConfigError || rethrow()
        println(io, sprint(showerror, err))
        return 2
    end

    running = pkgversion(GBGCodingTools)
    found = counts(cfg, root)
    if !isempty(found)
        println(io, "bump: ", Render.version_tag(cfg), " → v", version, " is refused; the rules of the running v",
                running, " find ", sum(last, found), " thing(s) here:")
        for (id, n) in found; println(io, "  ", lpad(n, 5), "  ", id); end
        println(io, "Fix what you mean to fix, switch the rest off in .gbg/config.jl with a reason, then bump.")
        println(io, "Nothing was changed.")
        return 1
    end
    println(io, "bump: the rules of the running v", running, " find nothing here.")

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
    stale_warning(io, version, running)
    return isempty(refused) ? 0 : 1
end

"""
    stale_warning(io, version, running)

Says that what was just written is the RUNNING version's, not the pinned one's. The arguments are:

- `io` — where it goes.
- `version` — the version just pinned.
- `running` — the version of the copy that wrote.

The pin moves first and the regeneration follows, and the regeneration runs on the code that is LOADED —
which is the version the environment's manifest still holds, not the one just pinned. So every generated file it writes is the
old version's content under the new version's banner: a file the new version would add is absent, and a
file it would word differently is worded the old way. [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/) met this on 2026-09-22 going
from rc.5 to rc.7 — sixteen paths where twenty were due, with the new rulebook file and three skills
missing — and the drift is invisible until the next build runs the wiring check.

It cannot be fixed by regenerating harder: the right content does not exist in this process. What closes
it is resolving the environments onto the new tag and running `gbg sync` again, under the new code.
"""
function stale_warning(io::IO, version, running)
    println(io, "")
    println(io, "NOT FINISHED. What was just written is v", running, "'s content under a v", version, " banner,")
    println(io, "and the rules that let the pin move were v", running, "'s too: `bump` runs with the code that")
    println(io, "is RUNNING, and the running code is whatever the environments' manifests still hold — not")
    println(io, "what you have just pinned. Move them, then regenerate under the new code:")
    println(io, "")
    println(io, "    julia --project=docs -e 'using Pkg; Pkg.update(\"GBGCodingTools\")'")
    println(io, "    julia --project=test -e 'using Pkg; Pkg.update(\"GBGCodingTools\")'")
    println(io, "    gbg sync")
    println(io, "")
    println(io, "`Pkg.update` and not `Pkg.resolve`: a resolve writes the new rev while keeping the old")
    println(io, "tree hash where the clone has never fetched the tag, which leaves the old code running")
    println(io, "under the new revision — seen twice, at rc.4 and at rc.7.")
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
