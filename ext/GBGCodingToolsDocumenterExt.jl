"""
    GBGCodingToolsDocumenterExt

The Documenter extension of `GBGCodingTools`: it defines the body of [`GBGCodingTools.makedocs`](@ref),
the mandatory wrapper a consumer's `docs/make.jl` calls. It loads only where `Documenter` is, which is a
consumer's docs environment and nowhere else, so no shim call ever loads Documenter.
"""
module GBGCodingToolsDocumenterExt

using GBGCodingTools, Documenter
import GBGCodingTools: makedocs

"""
    check(verb, code)

Turns a verb's exit code into a build failure: returns `nothing` when `code == 0`, else throws
`ErrorException("gbg <verb> returned <code>")`.
"""
check(verb::AbstractString, code::Integer) = code == 0 ? nothing : error("gbg $verb returned $code")

function makedocs(cfg; kwargs...)
    println("GBGCodingTools v", GBGCodingTools.tool_version(), " makedocs")
    root = cfg["root"]
    check("doctor --only QUICK", GBGCodingTools.doctor(cfg, :QUICK))
    check("scan docs --hard-only", last(GBGCodingTools.scan_docs(cfg; hard_only = true)))
    check("gate check-docs check-consistency", GBGCodingTools.gate(cfg, "check-docs", "check-consistency"))
    GBGCodingTools.write_public_surface(cfg)
    result = Documenter.makedocs(; kwargs...)
    build_dir = get(Dict(kwargs), :build, joinpath(root, "docs", "build"))
    isabspath(build_dir) || (build_dir = joinpath(root, "docs", build_dir))
    check("scan html", last(GBGCodingTools.scan_html(cfg, build_dir)))
    check("gate check-docs check-consistency", GBGCodingTools.gate(cfg, "check-docs", "check-consistency"))
    return result
end

end # module
