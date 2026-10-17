# GBGCodingTools.jl

**A consumer holds data; the tool holds behaviour; the only thing connecting them is the pinned version.**

The one shared tooling package of the four GBG Julia packages — `GBGPeriodicFields`,
`GBGHomogeneousTurbulence`, `GBGStreamingStatistics`, `GBGCloudPhysics` — and of itself. It holds the
rules the AI coding sessions in those packages are given, and the programs that verify them: the
rulebook, each rule a Julia value with its own check and examples; the docs-build wrapper that
runs the rules before and after Documenter; the test harness a package's suite calls; the documentation
review, run by agents through one driver; the leak scan, before a package goes public; and the `gbg`
command that wires a package, checks it, and moves its pin. Every package names one exact released
version in the `Project.toml` of each environment that uses the tool, and nothing else passes between
them.

**Documentation:** <https://grigorysarnitsky.github.io/GBGCodingTools.jl/> — the guide (install, the
verbs, the config), the rules, the API pages and the architecture, built from `master` by the Docs
workflow. The design is `docs/ARCHITECTURE.md`; the plan of the rebuild, phase by phase, is
`IMPLEMENTATION.md`; the provenance is git's history.

## Bootstrap on a machine

```sh
# 1. in any wired package: fetch the pinned copy
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
# 2. from that package: install the launcher, and register the owner's dev checkout
julia --startup-file=no --project=docs -e 'using GBGCodingTools; exit(GBGCodingTools.main(ARGS))' -- install --dev-checkout "<dev checkout>"
# 3. check the package's wiring
gbg check
```

`install.sh` in the dev checkout runs step 2 against the checkout itself. The launcher runs whichever
version the package in the current directory pins; `gbg --dev` runs the dev checkout.

## Exit contract

Every verb: `0` clean · `1` a finding · `2` cannot evaluate (a missing config or path, a tool not
on the path) · `3` crash (an uncaught exception, never read as a finding). Output is never truncated,
and a log is never read for a verdict.
