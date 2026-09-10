# [The verbs](@id verbs)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

`gbg <noun> <verb>` is the whole command line; the table is closed, and every verb below is rendered
from its own docstring so the page cannot drift from the code. The exit contract is one for all: `0`
clean, `1` a substantive finding, `2` cannot evaluate (refused, missing input, torn file), `3` crash.

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
GBGCodingTools.cmd_probe
```

## Consumer setup

```@docs
GBGCodingTools.Init.init
GBGCodingTools.Init.migrate_baselines
GBGCodingTools.Init.new
GBGCodingTools.Sync.sync
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
GBGCodingTools.gate
GBGCodingTools.frozen_rounds
```

## Rounds

```@docs
GBGCodingTools.Preflight.preflight
GBGCodingTools.Rounds.prepare
GBGCodingTools.Rounds.build
GBGCodingTools.Rounds.test
GBGCodingTools.Rounds.bank
GBGCodingTools.Rounds.rerun
GBGCodingTools.Passes.pass_open
GBGCodingTools.Passes.grade
GBGCodingTools.Passes.close
GBGCodingTools.Passes.audit_after_code
GBGCodingTools.Rounds.abandon
GBGCodingTools.Rounds.list
GBGCodingTools.Rounds.render
GBGCodingTools.cmd_witnesses
GBGCodingTools.audit_bank
```

## Fleet and release

```@docs
GBGCodingTools.Fleet
GBGCodingTools.Fleet.latest_tag
GBGCodingTools.Fleet.rows
GBGCodingTools.Fleet.diff
GBGCodingTools.bump
GBGCodingTools.release
GBGCodingTools.selftest
```
