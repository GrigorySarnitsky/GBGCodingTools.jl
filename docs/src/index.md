# GBGCodingTools

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

!!! warning "Being rebuilt"
    This package is being rebuilt to a new design, adopted on 2026-09-17: `docs/ARCHITECTURE.md` in the
    repository is what it is being built to, and `IMPLEMENTATION.md` is the order of the work. The round
    machinery described in earlier versions of this page is gone, and the pages below describe what is in
    the tree today, which is less than the site once documented and less than the design asks for.

## What it is

`GBGCodingTools.jl` is a private Julia package, on GitHub, holding the review procedures, scans, test
engines and writing rules of four Julia research packages:
[`GBGPeriodicFields`](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/),
[`GBGHomogeneousTurbulence`](https://grigorysarnitsky.github.io/GBGHomogeneousTurbulence.jl/),
[`GBGStreamingStatistics`](https://grigorysarnitsky.github.io/GBGStreamingStatistics.jl/) and
[`GBGCloudPhysics`](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/). AI coding sessions do
much of the writing, testing and reviewing in those four packages; this package holds the rules those
sessions are given and the scans, checks and test engines that verify the rules, so the four packages
are held to one standard by the same programs.

Each of the four packages keeps only its own data, under its `.gbg/` directory: its configuration,
the disciplines its readers need, what it switches off and why, and its past reviews. It
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
`gbg sync --check`; a bare verb is allowed where the noun is obvious, as in `gbg check`. There are 14
verbs, listed on [The verbs](@ref verbs), and every one exits with `0` when clean, `1` when it found something, `2` when it could not
evaluate, `3` when it crashed. The two a person runs most:

- `gbg check` — runs the rulebook over this package and reports what it finds. It repairs nothing:
  what a rule found is the work of whoever ran it.
- `gbg sync` — writes every file that connects this package to that one, and with `--check` reports
  which of them has been hand-edited instead of writing.

## What a package's docs build and tests call

- [`GBGCodingTools.makedocs`](@ref) — what a package's `docs/make.jl` calls instead of `Documenter.makedocs`.
  It runs the documentation rules of the rulebook and the wiring check before building the site, and
  the rules that read the built site after.
- [`GBGCodingTools.TestHarness`](@ref) — the engines a package's `test/runtests.jl` calls: a bound on what a
  call allocates ([`@alloc_below`](@ref GBGCodingTools.TestHarness.@alloc_below)); recorded baselines for an in-place operation's reads and writes and
  for the public method set, failing the test suite when either moves unannounced; an oracle class on
  every public value-returning operation — `analytic`, `independent`, `property`, `relational` or
  `structural`, and none resting on `relational` alone; and [a run of the witnesses](@ref GBGCodingTools.TestHarness.run_regressions) kept from bug hunts.

## The written rules

The policy is 115 rules, on [The rules](@ref gbg-rules), each with an id like
[`RULE.DOC.ARGCOV`](@ref RULE.DOC.ARGCOV) (every argument of a function appears in its docstring): a documentation rubric, the LaTeX idiom, the citation style, the testing
protocol, the rules of the instruments, and git conventions. Each is a Julia value carrying its own
check and the examples that show the check matches it; `Render.policy` writes them into every package,
where the sessions read them.

## How a package adopts it

Running [`gbg init`](@ref GBGCodingTools.Wire.init) in the package writes its `.gbg/config.jl` and then everything that config
generates: the rulebook under `.gbg/policy/`, a managed block of the package's `CLAUDE.md`, the
end-of-turn hook, and `GBGCodingTools = "=X.Y.Z"` in each environment naming the tool. A small launcher script,
also named `gbg` and installed once per machine by [`gbg install`](@ref GBGCodingTools.cmd_install), runs whichever version the package in
the current directory pins.

## Where to start

- [Install](@ref install): the launcher, the pinned version, the dev checkout.
- [The verbs](@ref verbs): the closed table of `gbg <noun> <verb>`.
- [The config](@ref config): what a package states about itself.
- [Architecture](@ref "GBGCodingTools — architecture"): the full design record with every decision and its evidence.

## The module

```@docs
GBGCodingTools
```
