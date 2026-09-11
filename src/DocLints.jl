"""
    makedocs(cfg; kwargs...)

The mandatory docs-build wrapper a consumer's `docs/make.jl` calls instead of `Documenter.makedocs`.
The body is defined by the Documenter extension (`ext/GBGCodingToolsDocumenterExt.jl`), which Julia
loads once `Documenter` is in the environment — a consumer's `make.jl` already does `using Documenter`.

The arguments are:

- `cfg` — the validated config object [`Config.read`](@ref) returns; it names the surfaces the scans
  read and the instruments whose open rounds gate the build (an instrument is one of the four review
  procedures and a round is one run of one over the consumer, tracked under `.gbg/rounds/`;
  [`GBGCodingTools`](@ref) binds both terms).
- `kwargs...` — passed through to `Documenter.makedocs` unchanged (`sitename`, `pages`, `modules`,
  `checkdocs`, `doctest`, `format`, …).

Before Documenter runs it runs, in-process, the quick doctor set — the `:QUICK` selection of
[`GBGCodingTools.doctor`](@ref), the checks that hold on any machine with no build and no network — the hard scans over the source
surfaces and [`GBGCodingTools.gate`](@ref), the closure gate, over the two docs instruments; after
Documenter it runs the built-HTML scans and that gate again.

Any non-zero return is an `error`, so the build fails — except either gate refusing only because a
docs round is open, which prints a skip line and returns `nothing`, exit 0, unless `GBG_DOCS_NO_SKIP`
is set: before Documenter nothing is built, and after it (a round opened while the site built) the site
is built and not deployed. It prints one banner line, `GBGCodingTools v<ver> makedocs`, which a
consumer's CI greps for.

Returns what `Documenter.makedocs` returns, `true` when that is `nothing` — as it is unless `debug =
true` is passed — or `nothing` when an open round of a docs instrument froze the build
([`GBGCodingTools.frozen_rounds`](@ref)): the skip is exit 0, so a red docs run keeps meaning something
is broken, and a `make.jl` deploys only when the value is not `nothing`. `GBG_DOCS_NO_SKIP`
turns the skip back into the refusal, which is how `gbg release` and the deep doctor run it.
"""
function makedocs end

"""
    docs_build_skipped(cfg, code) -> Vector{String}

The rounds that make a docs-build gate's refusal a skip rather than a failure: the open rounds of the
two docs instruments ([`GBGCodingTools.frozen_rounds`](@ref)) when the gate refused with exit `1` for
those rounds alone — every problem [`GBGCodingTools.gate_problems`](@ref) reports is `:open` — and
`GBG_DOCS_NO_SKIP` is unset, and otherwise none. A refusal that also names an open round of a disabled
instrument, or a round whose fixes were committed without it, fails the build. Both of
[`makedocs`](@ref)' gates ask it, so they share the one exception. The arguments are `cfg`, the
validated config, and `code`, the gate's exit code.
"""
function docs_build_skipped(cfg::AbstractDict, code::Integer)
    (code == 1 && !haskey(ENV, "GBG_DOCS_NO_SKIP")) || return String[]
    all(p -> first(p) == :open, last(gate_problems(cfg, "check-docs", "check-consistency"))) || return String[]
    return frozen_rounds(cfg, "check-docs", "check-consistency")
end
