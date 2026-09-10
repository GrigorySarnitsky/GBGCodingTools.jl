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
    check(verb::AbstractString, code::Integer)

Turns the exit code `code` of the verb `verb` into a build failure: returns `nothing` when `code == 0`, else throws
`ErrorException("gbg <verb> returned <code>")`.
"""
check(verb::AbstractString, code::Integer) = code == 0 ? nothing : error("gbg $verb returned $code")

function makedocs(cfg; kwargs...)
    println("GBGCodingTools v", GBGCodingTools.tool_version(), " makedocs")
    root = cfg["root"]
    check("doctor --only QUICK", GBGCodingTools.doctor(cfg, :QUICK))
    check("scan docs --hard-only", last(GBGCodingTools.scan_docs(cfg; hard_only = true)))
    # A round of a docs instrument freezes the build (`RULE.INST.FROZEN_MIDROUND`). That is not a
    # breakage, and failing on it turned every push during a round red — 25 in a row, and a red run
    # that means "a round is open" is a red run nobody reads. It prints the skip and exits 0 instead;
    # `GBG_DOCS_NO_SKIP` restores the refusal, and `gbg release` and the deep doctor set it, so no
    # release ever accepts a build that did not happen.
    buf = IOBuffer()                                   # held back: a frozen build prints the skip, not a refusal
    code = GBGCodingTools.gate(cfg, "check-docs", "check-consistency"; io = buf)
    frozen = GBGCodingTools.frozen_rounds(cfg, "check-docs", "check-consistency")
    if code == 1 && !isempty(frozen) && !haskey(ENV, "GBG_DOCS_NO_SKIP")
        println("makedocs: SKIPPED — ", join(frozen, ", "), " open; the instruments are frozen mid-round. ",
                "Nothing was built and nothing is deployed. Set GBG_DOCS_NO_SKIP=1 to make this a refusal again.")
        return nothing
    end
    print(stderr, String(take!(buf)))
    check("gate check-docs check-consistency", code)
    GBGCodingTools.write_public_surface(cfg)
    result = Documenter.makedocs(; kwargs...)
    build_dir = get(Dict(kwargs), :build, joinpath(root, "docs", "build"))
    isabspath(build_dir) || (build_dir = joinpath(root, "docs", build_dir))
    check("scan html", last(GBGCodingTools.scan_html(cfg, build_dir)))
    check("gate check-docs check-consistency", GBGCodingTools.gate(cfg, "check-docs", "check-consistency"))
    return result
end

end # module
