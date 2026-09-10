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
Documenter it runs the built-HTML scans and that gate again. Any non-zero return is an `error`, so the build fails. It prints one banner line,
`GBGCodingTools v<ver> makedocs`, which a consumer's CI greps for.

Returns whatever `Documenter.makedocs` returns, or `nothing` when an open round of a docs instrument
froze the build ([`GBGCodingTools.frozen_rounds`](@ref)): the skip is exit 0, so a red docs run keeps
meaning something is broken, and a `make.jl` deploys only when a result comes back. `GBG_DOCS_NO_SKIP`
turns the skip back into the refusal, which is how `gbg release` and the deep doctor run it.
"""
function makedocs end
