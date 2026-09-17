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
GBGCodingTools.cmd_probe
```

## Consumer setup

```@docs
GBGCodingTools.Init.init
GBGCodingTools.Init.migrate_baselines
GBGCodingTools.Init.new
GBGCodingTools.Sync.sync
GBGCodingTools.Sync.cmd_sync
GBGCodingTools.cmd_config
GBGCodingTools.cmd_schema
```

## Checks and scans

```@docs
GBGCodingTools.Doctor.run
GBGCodingTools.Doctor.cmd_doctor
GBGCodingTools.doctor
GBGCodingTools.cmd_scan
GBGCodingTools.scan_docs
GBGCodingTools.scan_html
GBGCodingTools.write_public_surface
```

The round verbs and the two design checks stood here until 2026-09-17. The machinery that ran them is
filed under `docs/design-record/machinery-v1/`, and what replaces it — a run, its stages and its report —
is `docs/ARCHITECTURE.md` §10.

## Fleet and release

```@docs
GBGCodingTools.Fleet
GBGCodingTools.Fleet.latest_tag
GBGCodingTools.Fleet.rows
GBGCodingTools.bump
GBGCodingTools.release
GBGCodingTools.selftest
```
