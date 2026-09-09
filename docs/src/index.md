# GBGCodingTools

`GBGCodingTools.jl` is a private Julia package, on GitHub, holding the review procedures, scans, test
engines and writing rules of four Julia research packages:
[`GBGPeriodicFields`](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/),
[`GBGIsotropicTurbulence`](https://grigorysarnitsky.github.io/GBGIsotropicTurbulence.jl/),
[`GBGStreamingStatistics`](https://grigorysarnitsky.github.io/GBGStreamingStatistics.jl/) and
[`GBGCloudPhysics`](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/). AI coding sessions do
much of the writing, testing and reviewing in them; this package holds the rules those sessions are
given and the scans, checks and test engines that verify the rules, so the four packages are held to
one standard by the same programs.

Each package keeps only its own data under `.gbg/`: its configuration, the roles its AI reviewers
adopt, its ledger of waived rules, and the records of past reviews. It names one exact released
version of this package, and nothing else passes between them. This package carries a `.gbg/` too and
is checked the same way.

Four review procedures — the instruments — are slash commands in Claude Code, run only when a human
asks. Each opens a round: a directory under `.gbg/rounds/` holding the findings, the fixes and their
independent verification, open until every finding is fixed or dismissed with a recorded reason. An
open `/check-docs` or `/check-consistency` round fails the docs build; an open `/bug-hunt` or
`/audit-changes` round fails the tests.

- `/check-docs` — checks that the pages and docstrings say what the code does and follow the rubric:
  scans, then AI agents that read every surface, a fix pass, then two AI graders, one blind to the diff.
- `/check-consistency` — AI reviewers, each in one role (logician, LaTeX typesetter, citations
  auditor), read the rendered pages for contradictions, mathematical errors, dead citations.
- `/bug-hunt` — a defect counts only with a witness: a Julia program that fails before the fix and
  passes after, kept as a regression test.
- `/audit-changes` — over a commit range: were the edits justified, did behaviour change silently, do
  the messages match the diff.

The rest runs from a shell, a build or a test.

- **`gbg`** — the command line, 21 verbs exiting `0` clean, `1` a finding, `2` cannot evaluate, `3`
  crash:
    - `gbg doctor`: 49 read-only checks — the installed version matches the pinned one, no
      generated file was hand-edited, docs and tests are wired.
    - `gbg scan docs`, `gbg scan html`: 40 scans over docstrings, pages and the built site — banned
      LaTeX idioms, undocumented arguments, unlinked sibling packages.
- **`GBGCodingTools.makedocs`** — what `docs/make.jl` calls instead of `Documenter.makedocs`: the
  quick doctor and the build-failing scans first, the built-site scans after.
- **`GBGCodingTools.TestHarness`** — the engines `test/runtests.jl` calls: a bound on what a call
  allocates (`@alloc_below`); baselines for an in-place operation's reads and writes and for the public
  method set, failing the suite when either moves unannounced; an independent reference for every
  public value-returning operation; the witnesses kept from bug hunts.
- **The policy** — 92 rules with ids like `RULE.DOC.ARGCOV`, rendered into every package by
  `gbg sync`; the scans and the doctor enforce the mechanical ones.
- **The shim** — the per-machine `gbg` script that runs each package's pinned version.

A package adopts it by running `gbg init`, which writes `.gbg/config.toml`, then `gbg sync`, which
renders the policy copy, the slash commands and the managed `CLAUDE.md` block, and writes
`GBGCodingTools = "=X.Y.Z"` into its docs and test environments.

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
