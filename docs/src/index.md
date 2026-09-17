# GBGCodingTools

!!! warning "Being rebuilt"
    This package is being rebuilt to a new design, adopted on 2026-09-17: `docs/ARCHITECTURE.md` in the
    repository is what it is being built to, and `IMPLEMENTATION.md` is the order of the work. The round
    machinery described in earlier versions of this page is gone, and the pages below describe what is in
    the tree today, which is less than the site once documented and less than the design asks for.

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

## The review procedures

The procedures, called instruments, are slash commands inside [Claude Code](https://claude.com/claude-code)
(the AI coding tool the sessions run in); a person types the command, nothing starts them automatically.
They are being rebuilt: the machinery that ran them — the rounds, their fix passes, their verifiers and
the gate that froze a build while one was open — was deleted on 2026-09-17, and what replaces it is
described in `docs/ARCHITECTURE.md` §3 and §4. Nothing a package's docs build or test suite runs reads
review state any more.

## The command-line program `gbg`

The program `gbg` is run from a terminal, in the directory of one of the packages. It is invoked as
`gbg <noun> <verb>`, where the noun names what is acted on and the verb what is done, as in
`gbg sync status`; a bare verb is allowed where the noun is obvious, as in `gbg doctor`. There are 17
verbs, listed on [The verbs](@ref verbs), and every one exits with `0` when clean, `1` when it found something, `2` when it could not
evaluate, `3` when it crashed. The two a person runs most:

- [`gbg doctor`](@ref "The doctor's checks") — 41 checks that a package is wired correctly (read-only, except that `--deep` builds and tests it): the installed version matches
  the pinned one, no generated file was hand-edited, the docs build and the tests call this package.
- [`gbg scan docs`](@ref GBGCodingTools.scan_docs) and [`gbg scan html`](@ref GBGCodingTools.scan_html) — 3 scans over docstrings, pages and the built site: banned
  LaTeX idioms, undocumented arguments, unlinked sibling packages, prose that grew past its baseline.

## What a package's docs build and tests call

- [`GBGCodingTools.makedocs`](@ref) — what a package's `docs/make.jl` calls instead of `Documenter.makedocs`.
  It runs the quick doctor set — the `QUICK` selection of [`GBGCodingTools.doctor`](@ref), the checks
  that hold on any machine with no build and no network — and the build-failing scans before building
  the site, and the built-site scans after.
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
- [The doctor](@ref "The doctor's checks"): every check id.
- [The ledger](@ref ledger) and [the config](@ref config).
- [Architecture](@ref "GBGCodingTools — architecture"): the full design record with every decision and its evidence.

## The module

```@docs
GBGCodingTools
```
