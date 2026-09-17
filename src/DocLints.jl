"""
    makedocs(cfg; kwargs...)

The mandatory docs-build wrapper a consumer's `docs/make.jl` calls instead of `Documenter.makedocs`.
The body is defined by the Documenter extension (`ext/GBGCodingToolsDocumenterExt.jl`), which Julia
loads once `Documenter` is in the environment — a consumer's `make.jl` already does `using Documenter`.

The arguments are:

- `cfg` — the validated config object [`Config.read`](@ref) returns; it names the surfaces the scans
  read.
- `kwargs...` — passed through to `Documenter.makedocs` unchanged (`sitename`, `pages`, `modules`,
  `checkdocs`, `doctest`, `format`, …).

Before Documenter runs it runs, in-process, the quick doctor set — the `:QUICK` selection of
[`GBGCodingTools.doctor`](@ref), the checks that hold on any machine with no build and no network — and
the hard scans over the source surfaces; after Documenter it runs the built-HTML scans. Any non-zero
return is an `error`, so the build fails. It prints one banner line, `GBGCodingTools v<ver> makedocs`,
which a consumer's CI greps for.

A build reads no review state and nothing can freeze it: the closure gate that used to refuse a build
while a round was open went with the round machinery on 2026-09-17, because a check that runs inside a
consumer's build must give the same answer on a fresh clone and on CI (docs/ARCHITECTURE.md §5.1, §10).

Returns what `Documenter.makedocs` returns, `true` when that is `nothing` — as it is unless `debug =
true` is passed.
"""
function makedocs end
