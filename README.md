# GBGCodingTools.jl

> **Being rebuilt.** This package is being rebuilt to the design in `docs/ARCHITECTURE.md`, adopted
> 2026-09-17, in the order `IMPLEMENTATION.md` sets out. The review instruments it once ran do not
> run today; what remains is the deterministic half — the scans, the reflection checks, the test
> harness, the doctor and the generators.

**A consumer holds data; the tool holds behaviour; the only thing connecting them is the pinned version.**

The one shared tooling package of the four GBG Julia packages (`GBGPeriodicFields`,
`GBGIsotropicTurbulence`, `GBGStreamingStatistics`, `GBGCloudPhysics`) and of itself: the four review
instruments (`/check-docs`, `/check-consistency`, `/bug-hunt`, `/audit-changes`), the docs-build wrapper
and its scans, the test harness, the doctor, the policy prose and the migration scaffolding — one
version, pinned by every consumer through its sub-environment `Project.toml` files.

**Documentation:** <https://grigorysarnitsky.github.io/GBGCodingTools.jl/> — the guide (install, the
verbs, rounds, the doctor, the ledger, the config), the API pages and the architecture record, built
from `master` by the Docs workflow.

The design is `docs/ARCHITECTURE.md`; the build plan is `IMPLEMENTATION.md`; `docs/design-record/` is
the provenance.

## Bootstrap on a machine

```sh
# 1. in any consumer: fetch the pinned copy
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
# 2. from that consumer: install the shim and register the owner's dev checkout
julia --startup-file=no --project=docs -e 'using GBGCodingTools; exit(GBGCodingTools.main(ARGS))' -- install --dev-checkout "<dev checkout>"
# 3. check
gbg doctor
```

`install.sh` in the dev checkout runs step 2 against the checkout itself.

## Exit contract

Every verb: **0** clean · **1** substantive finding · **2** cannot evaluate (a missing config, round or
path; a dead lane; a hash mismatch) · **3** crash (an uncaught exception, never read as a finding).
Output is never truncated.
