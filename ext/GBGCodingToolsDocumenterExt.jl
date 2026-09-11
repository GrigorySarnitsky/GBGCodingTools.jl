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

"""
    gate_or_skip(cfg, what) -> Bool

Runs the closure gate over the two docs instruments and says whether the build is skipped: `true` when
the gate refuses only because a round of a docs instrument is open and `GBG_DOCS_NO_SKIP` is unset,
after printing the skip line with `what` (the state the build is left in); otherwise the gate's own
report goes to `stderr` and its exit code through [`check`](@ref), which throws on any refusal, and the
result is `false`. The arguments are `cfg`, the validated config, and `what`, the sentence the skip line
ends with. Both of `makedocs`' gates go through here, so they share the one exception.
"""
function gate_or_skip(cfg, what::AbstractString)
    buf = IOBuffer()                                   # held back: a frozen build prints the skip, not a refusal
    code = GBGCodingTools.gate(cfg, "check-docs", "check-consistency"; io = buf)
    frozen = GBGCodingTools.docs_build_skipped(cfg, code)
    if !isempty(frozen)
        println("makedocs: SKIPPED — ", join(frozen, ", "), " open; the instruments are frozen mid-round. ", what,
                " Set GBG_DOCS_NO_SKIP=1 to make this a refusal again.")
        return true
    end
    print(stderr, String(take!(buf)))
    check("gate check-docs check-consistency", code)
    return false
end

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
    gate_or_skip(cfg, "Nothing was built and nothing is deployed.") && return nothing
    GBGCodingTools.write_public_surface(cfg)
    result = Documenter.makedocs(; kwargs...)
    build_dir = get(Dict(kwargs), :build, joinpath(root, "docs", "build"))
    isabspath(build_dir) || (build_dir = joinpath(root, "docs", build_dir))
    check("scan html", last(GBGCodingTools.scan_html(cfg, build_dir)))
    # a round opened while the site built is the same non-breakage as one open before it: the site was
    # built, but nothing built under a frozen round is deployed, so this skip returns `nothing` too
    gate_or_skip(cfg, "The site was built and is not deployed.") && return nothing
    # Documenter returns `nothing` unless `debug = true`, which is the frozen skip's own value, so a
    # build that happened says so with `true`
    return something(result, true)
end

end # module
