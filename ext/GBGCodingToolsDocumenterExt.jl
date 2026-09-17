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

It runs beside the old scans while the ninety-five rules are converted, and takes over from them rule by
rule — each conversion deletes the scan it replaces, so nothing is checked twice and nothing stops being
checked. A package with no `.gbg/config.jl` yet has nothing converted to run, which is exit 0.

Returns the exit code: 0 clean, 1 findings.
"""
function rules_and_wiring(root::AbstractString; site = nothing)
    isfile(joinpath(root, ".gbg", "config.jl")) || return 0
    cfg = GBGCodingTools.ConfigIO.read_config(root)
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
    for l in found
        println(stderr, "  RULE   ", l.file, ":", l.line, isempty(l.node) ? "" : "  [" * l.node * "]", "  ", l.text)
    end
    for l in drift
        println(stderr, "  WIRING ", l.file, "  ", l.text, " — run `gbg sync`")
    end
    return 1
end

function makedocs(cfg; kwargs...)
    println("GBGCodingTools v", GBGCodingTools.tool_version(), " makedocs")
    root = cfg["root"]
    check("doctor --only QUICK", GBGCodingTools.doctor(cfg, :QUICK))
    check("scan docs --hard-only", last(GBGCodingTools.scan_docs(cfg; hard_only = true)))
    check("check --only docs", rules_and_wiring(root))
    # Nothing here reads review state any more: a build reports what its checks find and nothing
    # else, and no round can freeze it (docs/ARCHITECTURE.md §5.1, §10 — the closure gate went with the
    # round machinery on 2026-09-17).
    GBGCodingTools.write_public_surface(cfg)
    result = Documenter.makedocs(; kwargs...)
    build_dir = get(Dict(kwargs), :build, joinpath(root, "docs", "build"))
    isabspath(build_dir) || (build_dir = joinpath(root, "docs", build_dir))
    check("scan html", last(GBGCodingTools.scan_html(cfg, build_dir)))
    check("check --site", rules_and_wiring(root; site = build_dir))
    # Documenter returns `nothing` unless `debug = true`, so a build that happened says so with `true`
    return something(result, true)
end

end # module
