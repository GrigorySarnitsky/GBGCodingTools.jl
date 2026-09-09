# GBGCodingTools

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

**A consumer holds data; the tool holds behaviour; the only thing connecting them is a pin.**

`GBGCodingTools` is the one shared tooling package of the GBG Julia packages — `GBGPeriodicFields`,
`GBGIsotropicTurbulence`, `GBGStreamingStatistics`, `GBGCloudPhysics` — and of itself. It holds the four
review instruments (`/check-docs`, `/check-consistency`, `/bug-hunt`, `/audit-changes`), the
docs-build wrapper and its deterministic scans, the test harness the consumers' suites call, the
read-only doctor, and the policy prose every consumer imports, at one version pinned by every consumer
through its sub-environment `Project.toml` files.

## What a consumer has

A consumer carries a `.gbg/` directory: one config file, one exemption ledger, its domain hats, its
seed catalogue, the rendered policy copy, and its review rounds. Everything else — the skill stubs, the
Stop hook, the CI fragments, the managed blocks of `CLAUDE.md` and `.gitignore` — is rendered by
[`gbg sync`](@ref GBGCodingTools.Sync.sync) from the pinned templates and checked by
[`gbg doctor`](@ref GBGCodingTools.Doctor.run). The consumer's `docs/make.jl` calls
[`GBGCodingTools.makedocs`](@ref), which runs the quick doctor, the hard scans and the closure gate
around `Documenter.makedocs`; its `test/runtests.jl` calls
[`TestHarness.gate`](@ref GBGCodingTools.TestHarness.gate) and
[`TestHarness.run_regressions`](@ref GBGCodingTools.TestHarness.run_regressions).

## Where to start

- [Install](@ref install): the shim, the pin, the dev checkout.
- [The verbs](@ref verbs): the closed table of `gbg <noun> <verb>`.
- [Rounds](@ref rounds): what an instrument round is, its files, its closure channels and exit codes.
- [The doctor](@ref "The doctor's checks"): every check id.
- [The ledger](@ref ledger) and [the config](@ref config).
- [Architecture](@ref "GBGCodingTools — architecture"): the full design record with every decision and its evidence.

## The module

```@docs
GBGCodingTools
```
