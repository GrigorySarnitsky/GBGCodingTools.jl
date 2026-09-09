# GBGCodingTools

`GBGCodingTools` is the **tool**: the one shared tooling package of the four GBG Julia packages,
[`GBGPeriodicFields`](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/), [`GBGIsotropicTurbulence`](https://grigorysarnitsky.github.io/GBGIsotropicTurbulence.jl/),
[`GBGStreamingStatistics`](https://grigorysarnitsky.github.io/GBGStreamingStatistics.jl/), [`GBGCloudPhysics`](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/). A package that uses it is a
**consumer**: each of the four, and the tool itself. Each consumer **pins** the tool to one exact
version, named in its `.gbg/config.toml`, which `gbg sync` writes into the consumer's sub-environment
`Project.toml` files as an exact compat entry; that pinned version is the only thing that connects a
consumer to the tool.

**A consumer holds data; the tool holds behaviour; the only thing connecting them is the pinned version.** Everything
that varies by package (its config, hats, ledger, rounds and frozen baselines) lives in the consumer as
data; every check, scan, instrument and verb lives in the tool as code; a consumer selects a version and
nothing else.

The tool holds the four review instruments (`/check-docs`, `/check-consistency`, `/bug-hunt`,
`/audit-changes`), the docs-build wrapper and its deterministic scans, the test harness the consumers'
suites call, the read-only doctor, and the policy prose every consumer imports.

## What a consumer has

A consumer carries a `.gbg/` directory: one config file, one exemption ledger, its domain hats (the
reviewer personas of `/check-consistency`, one per aspect of the package's field), its seed catalogue, the rendered policy copy, and its review rounds. Everything else — the skill stubs, the
Stop hook, the CI fragments, the managed blocks of `CLAUDE.md` and `.gitignore` — is rendered by
[`gbg sync`](@ref GBGCodingTools.Sync.sync) from the pinned templates and checked by
[`gbg doctor`](@ref GBGCodingTools.Doctor.run). The consumer's `docs/make.jl` calls
[`GBGCodingTools.makedocs`](@ref), which runs the quick doctor, the hard scans and the closure gate
around `Documenter.makedocs`; its `test/runtests.jl` calls
[`TestHarness.gate`](@ref GBGCodingTools.TestHarness.gate) and
[`TestHarness.run_regressions`](@ref GBGCodingTools.TestHarness.run_regressions).

## Where to start

- [Install](@ref install): the shim, the pinned version, the dev checkout.
- [The verbs](@ref verbs): the closed table of `gbg <noun> <verb>`.
- [Rounds](@ref rounds): what an instrument round is, its files, its closure channels and exit codes.
- [The doctor](@ref "The doctor's checks"): every check id.
- [The ledger](@ref ledger) and [the config](@ref config).
- [Architecture](@ref "GBGCodingTools — architecture"): the full design record with every decision and its evidence.

## The module

```@docs
GBGCodingTools
```
