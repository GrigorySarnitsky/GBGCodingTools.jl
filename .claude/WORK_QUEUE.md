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
- [x] E1 pass open's sweep refusal must not apply to an audit round: its tree never moves, so every concern is unswept and no audit pass can open (deferred by 2026-09-10-audit-changes-01) — DONE: an audit round is exempt; pass_open branches on inst
- [x] E2 unswept compares a whole-tree file set against a covered-paths-only diff, so a fix outside the covered paths never clears it (deferred by 2026-09-10-audit-changes-01) — DONE: the diff is now asked for the whole tree
- [x] E3 a finding whose locations name no real file is exempt from re-verification for ever, and from the sweep refusal (deferred by 2026-09-10-audit-changes-01) — DONE: such a finding is re-verified every pass and never trips the refusal; both locked by test
- [x] E4 a scoped pass writes demoted_by_rule and adjudicated_share over its scope against a denominator of every banked id, so the tally gbg fleet --diff reads reports a zero rate (deferred by 2026-09-10-audit-changes-01) — DONE: both rates now count the carried entries too, so they are over the round
- [x] E5 the round-lifecycle test was re-baselined to assert the refusal, so nothing exercises the default pass open path (deferred by 2026-09-10-audit-changes-01) — DONE: the default path is exercised by the predicate test above it, said so in the lifecycle
- [x] E6 the adjudicated and deferred closure channels close a finding without touching its files, which the sweep refusal then blocks (deferred by 2026-09-10-audit-changes-01) — DONE: closed with E3: a finding naming no file never trips the refusal
- [x] F1 TestHarness.resolve_function's reorder is inert (pkg is searched first and isdefined is true for every Base export), its new docstring states a contract the code does not keep, and a commit message claims it as a code fix (deferred by 2026-09-10-audit-changes-01) — DONE: a module that owns the name is searched first, so read/list/report denote the package; locked by test and recorded in the CHANGELOG
- [x] G1 the tally state vocabulary went from six values to ten and two artefact schemas closed their maps: record both in ARCHITECTURE 6.3 and re-grade the CHANGELOG entry against 5.5's MAJOR rule (deferred by 2026-09-10-audit-changes-01) — DONE: both are in ARCHITECTURE 6.3, and the CHANGELOG grades the cycle MAJOR under 5.5
- [x] H1 gbg sync throws uncaught on a .gbg/managed.json an older tool version wrote (deferred by 2026-09-10-audit-changes-01) — DONE: cmd_sync names a SyncError and returns 2; both directions tested
- [x] I1 SCAN.ARGS_FORM's element-type exemption fires on a keyword's name alone, and it counts a bare splat so a prose-form f(x; kwargs...) is a hit (deferred by 2026-09-10-audit-changes-01) — DONE: the exemption is T/eltype/element_type bound in a prose clause, and no wider; the splat count was already fixed
- [x] J1 SCAN.SIBLING_LINK's later-mention half is hard-tier and its pattern matches any URL under a sibling's site, a deep link included (deferred by 2026-09-10-audit-changes-01) — DONE: only a later link repeating the site is a hit; a deep link is a cross-reference
- [x] K1 check_paths scans docs_build by regex: a refusal the config schema makes unreachable, beside a per-token existence check that fires on any .jl-shaped word (deferred by 2026-09-10-audit-changes-01) — DONE: the schema pins the path, check_paths verifies the file, and the dead branch is gone
- [x] L1 RULE.TEST.RULE_WITH_CHECK counts session, a working agreement no artefact records, as a check, two lines above saying that remembering a rule is not enforcement (deferred by 2026-09-10-audit-changes-01) — DONE: the session class is gone; a panel counts only inside a running instrument, and the six rules that rested on habit are weakness
- [x] M1 the \mathbf{1} standing exception reached five sites but not the ARCHITECTURE rule table, RULES.toml's statement or the latex-typesetter hat (deferred by 2026-09-10-audit-changes-01) — DONE 2026-09-10: ARCHITECTURE §12.A RULE.TEX.MATHBF row and §9 resolution row now state the standing exception; RULES.toml and latex-typesetter.toml carried it earlier in the batch
- [x] N1 RULE.DOC.SHAPE's ratchet clause reached the scan catalogue but not its own policy paragraph or the rule table (deferred by 2026-09-10-audit-changes-01) — DONE 2026-09-10: docs-rubric.md's RULE.DOC.SHAPE paragraph and the §12.A row now carry the ratchet clause
- [x] O1 the panel-versus-weakness distinction was not carried into this package's own deviation entry in CLAUDE.md (deferred by 2026-09-10-audit-changes-01) — DONE 2026-09-10: the RULE.API.POSITIONAL deviation in .gbg/exemptions.toml now says its check is `panel`, an answer under RULE.TEST.RULE_WITH_CHECK, not a weakness; rendered into CLAUDE.md and deviations.md
- [x] P1 --sweep-ok is absent from IMPLEMENTATION.md's CLI verb table (deferred by 2026-09-10-audit-changes-01) — DONE 2026-09-10: IMPLEMENTATION.md's verb table carries `[--sweep-ok]` with what it opens
- [x] Q1 the 'an audit is disposed, never corrected inside' rule was appended inside RULE.INST.AUDIT_AFTER_CODE with no id, register statement or check (deferred by 2026-09-10-audit-changes-01) — DONE 2026-09-10: split into its own RULE.INST.AUDIT_DISPOSED with a section, a RULES.toml row and a check (test:test/rounds.jl); Rounds.bank_next extracted and tested both directions; §12.A and the 93→94 count carried
- [x] R1 the signature_fidelity test cannot fail on the defect it names: on the fixture it evaluates to 8 >= 0 (deferred by 2026-09-10-audit-changes-01) — DONE 2026-09-10: the assertion was vacuous (8 >= 0). It now compares on a package whose displayed surface is entirely extension-homed, where the count must be 0 and would be 1 if the increment moved above the skip
- [x] S1 the Workflow-prompt guard still flags ordinary JavaScript its own both-directions test claims it passes (deferred by 2026-09-10-audit-changes-01) — DONE 2026-09-10: the lookbehind dropped `,` and `:` and excludes the JS keywords, so `{phase: `x`}`, `f(a, `b`)`, `return `done`` and eight more ordinary forms stop being findings; the defect and the eleven scripts are still judged right
- [x] T1 the comment recording why the fixture must be a test dependency was deleted and nothing replaced it (deferred by 2026-09-10-audit-changes-01) — DONE 2026-09-10: both comments restored in test/Project.toml, and the seed template carries the executable-claims one for every consumer
- [x] U1 pass open now refuses by default where it used to succeed, and that is absent from the CHANGELOG (deferred by 2026-09-10-audit-changes-01) — DONE 2026-09-10: the CHANGELOG states the refusal, the scoped pass and --sweep-ok under the Unreleased MAJOR
- [x] V1 signature_fidelity's population no longer counts extension-homed bindings, adding a DEAD path for a package whose exports are all extension-homed (deferred by 2026-09-10-audit-changes-01) — DONE 2026-09-10: a scan may return a third element, its note; SCAN.SIGNATURE_FIDELITY names the extension-homed bindings it could not compare, so the DEAD verdict carries its reason
- [x] W1 carry_deferrals treats every line of deferred.md as an item, so a wrapped bullet becomes one queue item per line (this queue, 38 fragments) (deferred by 2026-09-10-audit-changes-01) — DONE: an item is a bullet, a wrapped bullet is one item, prose outside every bullet is none; locked in both directions
- [x] X1 ESCALATED, owner: RULE.DOC.HOME_ORDER ends a docstring at the caveats and RULE.CIT.FULL_INLINE ends it at # References; both cannot be last (deferred by 2026-09-10-audit-changes-01) — BLOCKED on the owner: two fleet-wide rules cannot both be last in a docstring, and which one yields changes every consumer's prose
- [x] X2 ESCALATED, owner: whether the shape caps bind on a page unit already in the baseline (deferred by 2026-09-10-audit-changes-01) — BLOCKED on the owner: whether the shape caps bind on a page unit already in the baseline is a rule change, not an implementation choice
- [x] X3 ESCALATED, owner: tag 1.0.0-rc.2 so a round can close at a tag; a round closed from the dev checkout fails ROUND.DEV (deferred by 2026-09-10-audit-changes-01) — BLOCKED on the owner: 2026-09-09-check-docs-02 cannot close until the tool is on a tag (ROUND.DEV); tagging 1.0.0-rc.2 is the owner's call and a tag is never re-issued
- [x] X4 ESCALATED, owner: commit c6b6c1a on master is authored `t <t@t>` and carries no trailer, so GIT.TRAILER fails the doctor; it is pushed, so the choice is a force-push rewrite or waiting for it to leave the 20-commit window (found 2026-09-10) — RULED 2026-09-10, owner: wait for it to leave the 20-commit window; c6b6c1a is not rewritten. It is 9 commits back, so GIT.TRAILER stays FAIL for 12 more commits, and `gbg release` needs a green `doctor --deep`
- [ ] `substrate` names six views of the corpus and only two of them exist. `panel.js` splits the manuscript once, `siteonly` against everything else, so `rawhtml`, `docstrings`, `rulebook` and `none` are briefs over the full text, not narrower corpora. Either the panel delivers a corpus per substrate, or the closed set drops the four values that narrow nothing (MAJOR, ARCHITECTURE §6.3). Adjudicated for this round as `2026-09-09-check-docs-02/operational-claims#10`. (deferred by 2026-09-09-check-docs-02)
