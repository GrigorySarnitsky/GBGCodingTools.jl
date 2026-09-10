# GBGCodingTools

## What it is

`GBGCodingTools.jl` is a private Julia package, on GitHub, holding the review procedures, scans, test
engines and writing rules of four Julia research packages:
[`GBGPeriodicFields`](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/),
[`GBGIsotropicTurbulence`](https://grigorysarnitsky.github.io/GBGIsotropicTurbulence.jl/),
[`GBGStreamingStatistics`](https://grigorysarnitsky.github.io/GBGStreamingStatistics.jl/) and
[`GBGCloudPhysics`](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/). AI coding sessions do
much of the writing, testing and reviewing in those four packages; this package holds the rules those
sessions are given and the scans, checks and test engines that verify the rules, so the four packages
are held to one standard by the same programs.

Each of the four packages keeps only its own data, under its `.gbg/` directory: its configuration,
the roles its AI reviewers adopt, its [ledger](@ref ledger) of waived rules, and the records of its past reviews. It
names one exact released version of `GBGCodingTools`, and nothing else passes between the package and
this one. This package carries a `.gbg/` directory too and is checked by its own tools.

## The four review procedures

The procedures, called instruments, are slash commands inside [Claude Code](https://claude.com/claude-code)
(the AI coding tool the sessions run in); a person types the command, nothing starts them
automatically. Their full protocols are on [The instruments](@ref instruments). Each command opens a
[round](@ref rounds): a directory under the package's `.gbg/rounds/` holding the findings, the fixes and their
independent verification, open until every finding is fixed or dismissed with a recorded reason. An
open `/check-docs` or `/check-consistency` round fails the package's docs build; an open `/bug-hunt` or
`/audit-changes` round fails the package's tests.

- [`/check-docs`](@ref check-docs) — checks that the pages and docstrings say what the code does and follow the
  documentation rules: deterministic scans, then AI agents that read every documentation file, then a
  fix pass, then two AI graders, one of which does not see the edits.
- [`/check-consistency`](@ref check-consistency) — AI reviewers, each in one role (logician, LaTeX typesetter, citations
  auditor, and others), read the rendered pages for contradictions, mathematical errors and dead
  citations.
- [`/bug-hunt`](@ref bug-hunt) — a reported defect counts only with a witness: a Julia program that fails before the
  fix and passes after it, kept as a regression test.
- [`/audit-changes`](@ref audit-changes) — over a range of commits: were the edits justified, did behaviour change silently,
  do the commit messages match the diff.

## The command-line program `gbg`

`gbg` is a program run from a terminal, in the directory of one of the packages. It is invoked as
`gbg <noun> <verb>`, where the noun names what is acted on and the verb what is done, as in
`gbg round close`; a bare verb is allowed where the noun is obvious, as in `gbg doctor`. There are 21
verbs, listed on [The verbs](@ref verbs), and every one exits with `0` when clean, `1` when it found something, `2` when it could not
evaluate, `3` when it crashed. The two a person runs most:

- [`gbg doctor`](@ref "The doctor's checks") — 49 read-only checks that a package is wired correctly: the installed version matches
  the pinned one, no generated file was hand-edited, the docs build and the tests call this package.
- [`gbg scan docs`](@ref GBGCodingTools.scan_docs) and [`gbg scan html`](@ref GBGCodingTools.scan_html) — 42 scans over docstrings, pages and the built site: banned
  LaTeX idioms, undocumented arguments, unlinked sibling packages, prose that grew past its baseline.

## What a package's docs build and tests call

- [`GBGCodingTools.makedocs`](@ref) — what a package's `docs/make.jl` calls instead of `Documenter.makedocs`.
  It runs the quick doctor checks and the build-failing scans before building the site, and the
  built-site scans after.
- [`GBGCodingTools.TestHarness`](@ref) — the engines a package's `test/runtests.jl` calls: a bound on what a
  call allocates ([`@alloc_below`](@ref GBGCodingTools.TestHarness.@alloc_below)); recorded baselines for an in-place operation's reads and writes and
  for the public method set, failing the test suite when either moves unannounced; an oracle class on
  every public value-returning operation — `analytic`, `independent`, `property`, `relational` or
  `structural`, and none resting on `relational` alone; and [a run of the witnesses](@ref GBGCodingTools.TestHarness.run_regressions) kept from bug hunts.

## The written rules

The policy is 95 rules of prose, on [The rules](@ref rules), each with an id like
[`RULE.DOC.ARGCOV`](@ref RULE.DOC.ARGCOV) (every argument of a function appears in its docstring): a documentation rubric, the LaTeX idiom, the citation style, the testing
protocol, the rules of the four instruments, and git conventions. [`gbg sync`](@ref GBGCodingTools.Sync.sync) renders the rules into
every package, where the AI sessions read them; the scans and the doctor enforce the ones a program can
check.

## How a package adopts it

Running [`gbg init`](@ref GBGCodingTools.Init.init) in the package writes its [`.gbg/config.toml`](@ref config). Running `gbg sync` then renders the
copy of the rules, the four slash commands and a managed block of the package's `CLAUDE.md`, and writes
`GBGCodingTools = "=X.Y.Z"` into the package's docs and test environments. A small launcher script,
also named `gbg` and installed once per machine by [`gbg install`](@ref GBGCodingTools.cmd_install), runs whichever version the package in
the current directory pins.

## Where to start

- [Install](@ref install): the launcher, the pinned version, the dev checkout.
- [The verbs](@ref verbs): the closed table of `gbg <noun> <verb>`.
- [Rounds](@ref rounds): what an instrument round is, its files, its closure channels and exit codes.
- [The doctor](@ref "The doctor's checks"): every check id.
- [The ledger](@ref ledger) and [the config](@ref config).
- [Architecture](@ref "GBGCodingTools — architecture"): the full design record with every decision and its evidence.

## The module

```@docs
GBGCodingTools
```
