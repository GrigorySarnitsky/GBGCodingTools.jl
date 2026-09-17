# The design's §11; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Bump

`gbg bump <version>`: moves a package's pin to a released version of this one and rewrites its wiring
at that version.

It runs the new version's checks FIRST and refuses to move the pin while any of them finds something,
printing the count per rule. A pin moved silently is a package that finds out at its next build, on
someone else's time, that a newer rulebook has opinions about its prose; a package told first can fix
what it wants to fix and switch off what it does not, and then bump.
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

Exit 0 when the pin moved, 1 when the new version's rules found something and it did not, 2 when the
config could not be read or the pin line could not be found.
"""
function bump(root::AbstractString, version::VersionNumber; io::IO = stdout)
    isempty(version.prerelease) || (println(io, "bump: $version is a prerelease, and a prerelease is never pinned"); return 2)
    cfg = try
        ConfigIO.read_config(root)
    catch err
        err isa ConfigIO.ConfigError || rethrow()
        println(io, sprint(showerror, err))
        return 2
    end

    found = counts(cfg, root)
    if !isempty(found)
        println(io, "bump: ", Render.version_tag(cfg), " → v", version, " is refused; its rules find ",
                sum(last, found), " thing(s) here:")
        for (id, n) in found; println(io, "  ", lpad(n, 5), "  ", id); end
        println(io, "Fix what you mean to fix, switch the rest off in .gbg/config.jl with a reason, then bump.")
        println(io, "Nothing was changed.")
        return 1
    end

    set_pin(root, version) || (println(io, "bump: no `tool = …` line in .gbg/config.jl to move"); return 2)
    cfg = ConfigIO.read_config(root)                 # we just wrote it; failing to read it back is a crash
    changed = Render.write_all(cfg, root)
    println(io, "bump: pinned at v", version, "; ", length(changed), " path(s) rewritten.")
    for p in changed; println(io, "  ", p); end
    println(io, "Commit the config and the rewritten paths together: the pin and what it generates are one change.")
    return 0
end

function cmd_bump(args)
    o = parse_options(args)
    isempty(o.positional) && (println(stderr, "usage: gbg bump <version>"); return 2)
    v = tryparse(VersionNumber, o.positional[1])
    v === nothing && (println(stderr, "bump: $(o.positional[1]) is not a version"); return 2)
    return bump(GBGCodingTools.Config.find_root(), v)
end
VERBS["bump"] = cmd_bump

end # module Bump
