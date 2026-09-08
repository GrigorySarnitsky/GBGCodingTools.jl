# GBGCodingTools.jl — seed directory (not yet a package)

This directory is the starting point for the session that IMPLEMENTS `GBGCodingTools`, the one
shared tooling package for `GBGPeriodicFields`, `GBGIsotropicTurbulence`, `GBGStreamingStatistics`
and `GBGCloudPhysics`: the four review instruments (`/check-docs`, `/check-consistency`, `/bug-hunt`,
`/audit-changes`), the docs-build lints, the test harnesses, the shared policy prose, the doctor and
the migration scaffolding — one version, pinned by every consumer. The tool is its own fifth consumer:
it carries a Documenter site built through its own wrapper, and its docstrings and rounds pass the same
checks it applies to the others.

Read, in order:

1. `IMPLEMENTATION.md` — the ordered, checkable plan (owner questions first, then Phases 0–8 with a
   definition of done and verification commands each).
2. `docs/ARCHITECTURE.md` — the design and every decision with its evidence and alternatives.
3. `docs/design-record/` — provenance (surveys of the four packages, three proposals, three
   critiques, the decision record, the red-team reviews). Consult, do not re-derive.

The first commit of the implementing session turns this directory into the git repository
(`git init -b master`; remote `GrigorySarnitsky/GBGCodingTools.jl`, private), keeping these files.
