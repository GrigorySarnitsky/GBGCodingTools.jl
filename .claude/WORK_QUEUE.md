# Session work queue

One line per committed item. `- [ ]` open, `- [x]` done. `.claude/hooks/queue-guard.sh` is a Stop
hook that refuses to let the session end while any item is open, so "am I finished?" is answered by
a program rather than by the session's judgement.

Close an item ONLY when it is done and verified. An item closed to end the turn is the defect the
hook exists to prevent. A genuinely blocked item is closed with the blocker written on the line, so
the block shows in the diff instead of being silent.

- [x] SCAN.HTML_STRAY_MATH: a rendered math span holding a backtick or a bracket is a hard finding
- [x] the three quoted-syntax spans in the policy rewritten so they do not render as math
- [x] `gbg round close` writes a deferred instrument change into this queue, not the roadmap

- [x] BUG: the dismissal closure gate compares an items_sha that dismissals.js never writes
- [x] BUG: verify-architecture.js writes a file architecture-fix.schema.json rejects
- [x] BUG: instruments/bug-hunt/schema.json carries a $ref the tool's validator refuses
- [x] BUG: the /bug-hunt witness command cannot load GBGCodingTools in this package
- [x] BUG: /audit-changes lane routing misclassifies this package's covered paths
- [x] BUG: docs/src/guide/verbs.md is declared generated but is hand-written and tracked
- [x] BUG: package.modules names 9 of the 20 modules
- [x] populate this package's .gbg with its own hats, territories, oracles, audit claims, custom scans
- [x] declare the numerical audit engines inapplicable here, as ledger entries with reasons

- [x] a `data` surface kind: TOML, JSON, YAML, JS and template files, optional and off by default
- [x] a reader for each data kind in prose_lines, so the existing engine can walk them
- [x] scans over the data surface, with fixture pairs
- [x] this package turns it on; the four science packages leave it empty
