# [The verbs](@id verbs)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

`gbg <noun> <verb>` is the whole command line; the table is closed, and every verb below is rendered
from its own docstring so the page cannot drift from the code. The exit contract is one for all: `0`
clean, `1` a substantive finding, `2` cannot evaluate (a precondition not met, missing input, torn
file), `3` crash.

## Entry point

```@docs
GBGCodingTools.main
GBGCodingTools.parse_options
GBGCodingTools.Options
```

## Machine and self

```@docs
GBGCodingTools.cmd_install
GBGCodingTools.self_verify
GBGCodingTools.cmd_self_verify
```

## Consumer setup

```@docs
GBGCodingTools.Wire.init
GBGCodingTools.Wire.sync
```

## Checks

```@docs
GBGCodingTools.Check.run
```

The doctor's verbs stood here until 2026-09-17: `gbg doctor` judged a package's wiring, and the wiring
check judges it now, inside every build and every test run rather than on request.

The round verbs and the two design checks stood here until 2026-09-17. The machinery that ran them is
in git's history, and what replaces it — a run, its stages and its report —
is `docs/ARCHITECTURE.md` §10.

## The leak scan

```@docs
GBGCodingTools.Leak
GBGCodingTools.Leak.scan
GBGCodingTools.Leak.roots
GBGCodingTools.Leak.MARK
GBGCodingTools.Publication
GBGCodingTools.Publication.GITLEAKS
GBGCodingTools.Publication.gitleaks
GBGCodingTools.Publication.machine_terms
GBGCodingTools.Publication.mirror
GBGCodingTools.Publication.paths
GBGCodingTools.Publication.loose_blobs
GBGCodingTools.Publication.install
GBGCodingTools.Publication.config_toml
GBGCodingTools.Publication.Finding
GBGCodingTools.Publication.ACCEPTED
GBGCodingTools.Publication.accepted
GBGCodingTools.Publication.blocking
GBGCodingTools.Publication.metadata
GBGCodingTools.Publication.github
GBGCodingTools.Publication.scan
```

## The rulebook, measured

```@docs
GBGCodingTools.StudyCmd.rules
```

## Fleet and release

```@docs
GBGCodingTools.Fleet
GBGCodingTools.UsageError
GBGCodingTools.Fleet.rows
GBGCodingTools.Bump.bump
GBGCodingTools.release
GBGCodingTools.release_fails
GBGCodingTools.ci_verdict
GBGCodingTools.register
```
