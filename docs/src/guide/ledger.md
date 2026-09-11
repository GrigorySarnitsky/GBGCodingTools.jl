# [The ledger](@id ledger)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

`.gbg/exemptions.toml` is the one place a consumer records a waiver or an adjudication. One
`[[exemption]]` per entry:

```toml
[[exemption]]
id       = "RULE.DOC.STEER"       # a RULE.* rule, a SCAN.* scan, a doctor check, a finding id, or a harness op
scope    = "policy"               # policy | scan | lint | check | finding | harness
target   = "*"                    # or a symbol, a file, a glob, a finding id
reason   = "at least 40 characters: what is declined and why"
recorded = 2026-08-25
expires  = 2027-08-25             # required for every scope but finding; at most recorded + 365 days
evidence = "IT CLAUDE.md:179-182"
```

A `scope = "finding"` entry is the adjudication channel: it carries `overturn_when` instead of
`expires`, closes exactly one banked finding, and is audited by the dismissal auditor at close. Its
optional `ruling` says which kind of adjudication it is: `not-a-defect` (the default) rules the finding
no defect, and its reason reaches every later panel and verifier as settled; `scoped` puts a real
defect outside the round's reach, closes it, and is never shown as settled. An
optional `[exemption.match]` table (`arg_name`, `arg_type`, `path`, `symbol`, ANDed) **refines** a
`scan`, `lint`, `policy` or `harness` entry: the engine applies the predicate per trigger and the rule
stays live elsewhere; `arg_type` is evaluable by the reflection scans only, and a text scan refuses it.

The doctor's `CFG.EXEMPTIONS` validates every entry; `EXEMPT.EXPIRED` fails on a lapsed one,
`EXEMPT.EXPIRING` warns within 30 days, `EXEMPT.STALE` on a target that no longer exists, and
`EXEMPT.BROAD` when one `match` covers more than half of its rule's triggers. The families `PIN.*`,
`CFG.*`, `EXEMPT.*`, `WIRE.*`, `MANAGED.*`, `SHIM.*`, `POL.*`, `ROUND.*`, `SELF.*` are never exemptable.

```@docs
GBGCodingTools.Ledger.read
GBGCodingTools.Ledger.entries
GBGCodingTools.Ledger.matches
```
