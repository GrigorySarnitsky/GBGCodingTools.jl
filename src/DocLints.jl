"""
    makedocs(cfg; kwargs...)

The mandatory docs-build wrapper a consumer's `docs/make.jl` calls instead of `Documenter.makedocs`.
The body is defined by the Documenter extension (`ext/GBGCodingToolsDocumenterExt.jl`), which Julia
loads once `Documenter` is in the environment — a consumer's `make.jl` already does `using Documenter`.

The arguments are:

- `cfg` — the validated config object [`Config.read`](@ref) returns; it names the surfaces the scans
  read and the instruments whose open rounds gate the build (a round is one run of an instrument over
  the consumer, tracked under `.gbg/rounds/`).
- `kwargs...` — passed through to `Documenter.makedocs` unchanged (`sitename`, `pages`, `modules`,
  `checkdocs`, `doctest`, `format`, …).

Before Documenter runs it runs, in-process, the quick doctor set, the hard scans over the source
surfaces and the closure gate of the two docs instruments; after Documenter it runs the built-HTML scans
and the gate again. Any non-zero return is an `error`, so the build fails. It prints one banner line,
`GBGCodingTools v<ver> makedocs`, which a consumer's CI greps for. Returns whatever `Documenter.makedocs`
returns.
"""
function makedocs end
