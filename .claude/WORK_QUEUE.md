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

## The sweep remainder (2026-09-09)

- [x] A1 the exit contract: main() and the verb dispatch invoked by a test
- [x] A2 Rounds.prepare, scan_finding, consolidate_to and rescan_alive under test
- [x] A3 a golden test for Consolidate over the fixture's built site
- [x] A4 the doctor's checks asserted, the --deep set first
- [x] A5 the reflection scans stop skipping silently: assert the package loaded
- [x] A6 every Workflow script parsed by a test
- [x] A7 the round lifecycle for the other three instruments
- [x] B1 SCAN.SIGNATURE_FIDELITY reports the bindings it compared, not the file count
- [x] B2 AUDIT.GAP is not vacuous and runs in QUICK
- [x] B3 the docs build stops hiding missing docstrings behind warnonly
- [x] B4 GIT.TRAILER fails rather than warns
- [x] C1 RULE.DOC.ARGS_FORM gets an enforcer, or is declared a known weakness with a reason
- [x] C2 RULE.API.POSITIONAL likewise
- [x] D1 the design record's 28 files carry the provenance banner
- [x] D2 the false claims the sweep found in off-surface prose
- [x] D3 the dead schemas: loaded, or deleted
- [ ] Every concern disposed `fixed` in this round names a correction the NEXT change set carries, which the (deferred by 2026-09-10-audit-changes-01)
- [ ] next audit covers. An audit round is never corrected inside it, so this file is where that commitment (deferred by 2026-09-10-audit-changes-01)
- [ ] lives, and `close` carries these lines into `.claude/WORK_QUEUE.md`. (deferred by 2026-09-10-audit-changes-01)
- [ ] The 44 corrections owed, by what they belong to: (deferred by 2026-09-10-audit-changes-01)
- [ ] - **The scoped pass and the sweep refusal**, both added this week to make a round cheaper, and both (deferred by 2026-09-10-audit-changes-01)
- [ ] wrong in ways the round found by running them. `pass open` refuses every audit round outright, because (deferred by 2026-09-10-audit-changes-01)
- [ ] an audit's tree must not move and so nothing is ever touched. The tally's `demoted_by_rule` and (deferred by 2026-09-10-audit-changes-01)
- [ ] `adjudicated_share` count only the ids in the pass's scope against a denominator of every banked id, (deferred by 2026-09-10-audit-changes-01)
- [ ] so a round that adjudicated ten of forty writes a zero rate into the tally `gbg fleet --diff` reads. (deferred by 2026-09-10-audit-changes-01)
- [ ] `unswept` compares a whole-tree file set against a covered-paths-only diff, so a fix outside the (deferred by 2026-09-10-audit-changes-01)
- [ ] covered paths can never clear it. A finding whose locations name no real file is exempt from (deferred by 2026-09-10-audit-changes-01)
- [ ] re-verification for ever. And the round-lifecycle test was re-baselined to assert the refusal, so (deferred by 2026-09-10-audit-changes-01)
- [ ] nothing exercises the default path any more. (deferred by 2026-09-10-audit-changes-01)
- [ ] - **`TestHarness.resolve_function`.** The reorder is inert: `pkg` is searched first and `isdefined` (deferred by 2026-09-10-audit-changes-01)
- [ ] is true for every Base export through the implicit `using Base`, so the externals tuple is unreachable (deferred by 2026-09-10-audit-changes-01)
- [ ] for exactly the names the fix cited. 421 names resolve identically either way. The docstring it gained (deferred by 2026-09-10-audit-changes-01)
- [ ] states a contract the code does not keep, and the commit message claims a code fix that changed no (deferred by 2026-09-10-audit-changes-01)
- [ ] behaviour. (deferred by 2026-09-10-audit-changes-01)
- [ ] - **Two closed vocabularies shipped as MINOR.** The tally's `state` went from six values to ten and two (deferred by 2026-09-10-audit-changes-01)
- [ ] artefact schemas closed their maps, which §5.5 makes MAJOR. §6.3, the closed-vocabulary table, was (deferred by 2026-09-10-audit-changes-01)
- [ ] never touched, and `gbg sync` now throws uncaught on a sidecar an older copy wrote. (deferred by 2026-09-10-audit-changes-01)
- [ ] - **Three scans over-reach.** The argument-form scan's element-type exemption fires on a keyword's name (deferred by 2026-09-10-audit-changes-01)
- [ ] alone; it counts a bare splat so a prose-form `f(x; kwargs...)` is a hit; the sibling rule's new (deferred by 2026-09-10-audit-changes-01)
- [ ] later-mention half is hard-tier and its pattern matches any URL under a sibling's site; and (deferred by 2026-09-10-audit-changes-01)
- [ ] `check_paths` scans the build command by regex, so a refusal the config schema makes unreachable sits (deferred by 2026-09-10-audit-changes-01)
- [ ] beside a per-token existence check that fires on any `.jl`-shaped word. (deferred by 2026-09-10-audit-changes-01)
- [ ] - **A rule that now contradicts its own next sentence.** RULE.TEST.RULE_WITH_CHECK counts `session`, "a (deferred by 2026-09-10-audit-changes-01)
- [ ] working agreement no artefact records", as a check, two lines above "someone remembering this rule is (deferred by 2026-09-10-audit-changes-01)
- [ ] not enforcement". Six rules rest on it. (deferred by 2026-09-10-audit-changes-01)
- [ ] - **Sweeps that stopped short**, again: the indicator-glyph exception reached five sites but not the (deferred by 2026-09-10-audit-changes-01)
- [ ] rule table, the register statement or the typesetting hat; the shape rule's ratchet clause reached the (deferred by 2026-09-10-audit-changes-01)
- [ ] scan catalogue but not its own policy paragraph; the panel-versus-weakness distinction was not carried (deferred by 2026-09-10-audit-changes-01)
- [ ] into this package's own deviation entry; and `--sweep-ok` is absent from the build plan's verb table. (deferred by 2026-09-10-audit-changes-01)
- [ ] - **A fleet rule appended with no id.** The "an audit is disposed, never corrected inside" sentence went (deferred by 2026-09-10-audit-changes-01)
- [ ] into RULE.INST.AUDIT_AFTER_CODE's paragraph without an id of its own, a register statement or a check. (deferred by 2026-09-10-audit-changes-01)
- [ ] Three concerns are escalated rather than owed, each with the condition that would overturn it: the two (deferred by 2026-09-10-audit-changes-01)
- [ ] halves of the docstring-order contradiction with `RULE.CIT.FULL_INLINE`, which cannot both be last, and (deferred by 2026-09-10-audit-changes-01)
- [ ] the shape caps on a page unit already in the baseline. (deferred by 2026-09-10-audit-changes-01)
