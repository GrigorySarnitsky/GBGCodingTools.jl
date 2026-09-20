"""
    GBGCodingToolsDocumenterExt

The `Documenter` extension of `GBGCodingTools`: it defines the body of [`GBGCodingTools.makedocs`](@ref),
the mandatory wrapper a consumer's `docs/make.jl` calls. It loads only where `Documenter` is, which is a
consumer's docs environment and nowhere else, so no shim call ever loads `Documenter`.
"""
module GBGCodingToolsDocumenterExt

using GBGCodingTools, Documenter
import GBGCodingTools: makedocs

"""
    check(verb, code)

Turns the exit code `code` of the verb `verb` into a build failure: returns `nothing` when `code == 0`, else throws
`ErrorException("gbg <verb> returned <code>")`.
"""
check(verb::AbstractString, code::Integer) = code == 0 ? nothing : error("gbg $verb returned $code")

"""
    rules_and_wiring(root) -> Int

The documentation rules of the rulebook and the wiring check, run over the package at `root`: the new
engine's half of what a build must satisfy. The arguments are `root`, the package root, and `site`, the
built site's directory after Documenter has run — `nothing` before it, which is when the wiring check
runs and the rules that read a rendered page do not.

It is the whole of what a build checks. It ran beside the text scans while the rules were converted;
the last scan was retired on 2026-09-17, and nothing else remains to run. A package with no
`.gbg/config.jl` has no rules to run over it, which is exit 0.

Returns the exit code: 0 clean, 1 findings.
"""
function rules_and_wiring(root::AbstractString; site = nothing)
    isfile(joinpath(root, ".gbg", "config.jl")) || return 0
    cfg = GBGCodingTools.ConfigIO.read_config(root)
    # The config is validated here as it is in the test suite: an unknown discipline, a switch naming
    # nothing or a file set matching nothing must not pass the build while failing the tests.
    problems = GBGCodingTools.ConfigIO.validate(cfg, root)
    if !isempty(problems)
        for p in problems; println(stderr, "  CONFIG  ", p); end
        return 2
    end
    # The package itself, where it can be loaded: a build has it on the path already, and the rules that
    # compare a docstring with the module it documents need it. A package that cannot be loaded is not a
    # silent pass — `Checks.not_run` names what went unchecked.
    pkg = try
        Base.require(Main, Symbol(cfg.package))
    catch
        nothing
    end
    found = GBGCodingTools.Engine.Checks.run_all(cfg, root;
                intention = GBGCodingTools.Model.Intention.DOCUMENTATION, site, pkg)
    skipped = GBGCodingTools.Engine.Checks.not_run(cfg; pkg, site)
    isempty(skipped) || println(stderr, "  NOT RUN  ", join(String.(skipped), ", "),
                                site === nothing ? " (before the site is built)" : "")
    drift = site === nothing ? GBGCodingTools.Render.wiring(cfg, root) : GBGCodingTools.Model.Location[]
    isempty(found) && isempty(drift) && return 0
    for (id, l) in found
        println(stderr, "  ", rpad(String(id), 30), " ", l.file, ":", l.line,
                isempty(l.node) ? "" : "  [" * l.node * "]", "  ", l.text)
    end
    for l in drift
        println(stderr, "  WIRING ", l.file, "  ", l.text, " — run `gbg sync`")
    end
    return 1
end

# A package wired by `gbg init` has `.gbg/config.jl` and NO `.gbg/config.toml`, so it cannot produce the
# dictionary this once required — and `Model.Config` carries no root to take one from. Passing the root
# is what a new consumer can actually do, and what its `docs/make.jl` already has to hand.
makedocs(root::AbstractString; kwargs...) = makedocs_at(root, nothing; kwargs...)
makedocs(cfg::AbstractDict; kwargs...) = makedocs_at(cfg["root"], cfg; kwargs...)

function makedocs_at(root::AbstractString, cfg; kwargs...)
    println("GBGCodingTools v", GBGCodingTools.tool_version(), " makedocs")
    # The quick doctor set and the hard scans ran here until 2026-09-17. The doctor is deleted and the
    # scan catalogue is empty: every one of them is a rule now, and `rules_and_wiring` runs them all.
    check("check --only docs", rules_and_wiring(root))
    # Nothing here reads review state any more: a build reports what its checks find and nothing
    # else, and no round can freeze it (docs/ARCHITECTURE.md §5.1, §10 — the closure gate went with the
    # round machinery on 2026-09-17).
    # The public-surface file belongs to the tree being replaced and is written only where the old
    # config exists to describe it; a package wired by `gbg init` needs none of it.
    cfg === nothing || GBGCodingTools.write_public_surface(cfg)
    result = Documenter.makedocs(; kwargs...)
    build_dir = get(Dict(kwargs), :build, joinpath(root, "docs", "build"))
    isabspath(build_dir) || (build_dir = joinpath(root, "docs", build_dir))
    check("check --site", rules_and_wiring(root; site = build_dir))
    # Documenter returns `nothing` unless `debug = true`, so a build that happened says so with `true`
    return something(result, true)
end

end # module
