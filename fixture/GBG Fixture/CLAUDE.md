<!-- gbg:managed begin vdev — rewritten by `gbg sync`; do not edit -->
@.gbg/policy/00-index.md

The rulebook above is the whole of it: the rules, the terms they use, and what GBGFixture has
switched off with its reason. Nothing restates a rule outside it — a rule quoted in two files is a
rule that will be reworded in one.

Unasked, run `Pkg.test()` and nothing else. What a rule finds is reported, never fixed silently:
documentation may be fixed without asking, and anything else waits for an answer.

The readers of a review are derived from the rules and the tool's catalogue of disciplines. A
reader or a discipline this package needs and the tool lacks is requested from the tool's own
session, never written here.

A run an earlier session left open is continued before anything else, and the chat says so:
`gbg run next` says what to launch or that the stage is ready to collect, and the run goes on to
its close. It waits for the owner only when `gbg run next` says the tree moved since the launch.
<!-- gbg:managed end -->

# CLAUDE.md — GBGFixture

The toy consumer of `GBGCodingTools`. It exists to be scanned, built and gated by the tool's tests;
its content is deliberately small and written to the shared rubric.

## Modules and wiring

- `FixtureA` (grid, scaling), `FixtureB` (reductions), `FixtureC` (options, display); the umbrella
  re-exports all three.

## Core invariants

- An in-place operation writes its destination and nothing else; the destination may alias the source.
- A reduction never allocates a field-sized temporary.
- The energy convention is one half; no other factor appears anywhere.

## Code generation rules

- Every formula is LaTeX; every code object is bound to its symbol on the notation page.

## Working agreements

- The fixture changes only together with the tool test that reads it.

## Current state

Complete for its purpose. Live plans are in `docs/ROADMAP.md`.
