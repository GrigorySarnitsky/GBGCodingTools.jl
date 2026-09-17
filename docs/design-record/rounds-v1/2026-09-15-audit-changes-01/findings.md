# Findings — 2026-09-15-audit-changes-01

The work list, by id. Fix the CLASS, not the line; a seeded finding (marked) is never fixed in the corpus.

## lane free-reader

### `2026-09-15-audit-changes-01/free-reader#1` [major/high] scripts_refreshed[] gains three required fields with no schema_version gate, breaking any round already recorded under the old 2-field contract

- schema/round.schema.json (scripts_refreshed items.required)
- src/CLI/Rounds.jl :: refresh_scripts (base entry construction, now replaced)
- src/CLI/RoundFiles.jl:86-98 :: rounds() (swallows a schema failure into state = :invalid)
- src/CLI/Doctor.jl :: ROUND.MARKER, ROUND.FROZEN, ROUND.DEV, AUDIT.GAP (all filter RoundFiles.rounds() by state)
- src/CLI/Release.jl :: cites_round (also filters by state == :closed)
- src/TestHarness.jl:604-611 :: gate() (hard error()s on a nonzero QUICK doctor code)
- test/runtests.jl:28 (unconditionally calls TestHarness.gate(; root = TOOL) against the tool's own real .gbg/)

The new required fields (reason, after_pass, scripts) are a real improvement -- they make a rare, exceptional, mid-round operation auditable -- but the change tightens an already-shipped artefact schema with no version selection and no migration of already-persisted records, and no test constructs an old-shape entry to check it still reads. This is precisely the shape the round's own design elsewhere calls out as unacceptable when it happens to a measurement ('a skipped class is UNDEFINED in recall, so the denominator shrinks in silence') -- except here what shrinks in silence is the doctor's and the release gate's own historical coverage of past rounds.

### `2026-09-15-audit-changes-01/free-reader#2` [major/high] A policy waiver on a scan's non-canonical rule, previously honored (if over-broadly), now throws an uncaught LedgerError instead of failing gracefully

- src/Scan.jl :: apply_ledger
- src/CLI/Doctor.jl :: CFG.EXEMPTIONS (new unreachable_waiver_scans check)
- src/CLI/Main.jl :: main() (only Config.ConfigError is caught as exit 2; every other exception is exit 3 with a backtrace)

The underlying defect is real and was explicitly flagged as an open 'known limit' in the docstring this diff replaces, and the fix is well tested (test/scans.jl rewrites the whole scenario across all three two-rule scans, and test/sync_doctor.jl adds a doctor-level check). But the transition is abrupt: there is no deprecation warning, no grace period, and the failure mode for previously-accepted input is a hard crash rather than a graceful diagnostic, because the pre-existing LedgerError path was never wired into the same exit-2 treatment Config.ConfigError just received in this same diff.

### `2026-09-15-audit-changes-01/free-reader#3` [minor/medium] latex_source_globs changes from replace-when-set to always-union-with-the-four-defaults, removing any way to narrow the panel's source surface

- src/CLI/Preflight.jl :: source_globs / SOURCE_SURFACES / render_args
- instruments/check-consistency/schema.json :: instruments.check-consistency.latex_source_globs description
- instruments/check-consistency/workflow/verify-state.js (SCOPE now always CLI-resolved, the ['src','ext','docs/src','docs'] literal fallback removed)

This looks like the correct fix and is thoroughly documented, schema-described, and tested (test/coverage.jl asserts both the unset and set cases, and checks the state verifier's own literal fallback was removed). It reverses a genuine regression from the immediately preceding round (2026-09-12-audit-changes-02, which itself had turned a no-reader bug into a replace-semantics bug). Flagged here only because it is a second, real change in what this key resolves to for identical config input within two rounds, and the 'replace' capability is removed outright rather than kept as an opt-in.

## lane executing

### `2026-09-15-audit-changes-01/executing#1` [major/high] A policy waiver of a two-rule scan's second rule, accepted at base, now crashes gbg scan docs and the makedocs hard-scan gate with exit 3

- src/Scan.jl:398-408 (apply_ledger: the new LedgerError throw for a non-canonical policy entry)
- src/CLI/Main.jl:148-151 (only Config.ConfigError is mapped to exit 2; LedgerError reaches the crash arm)
- ext/GBGCodingToolsDocumenterExt.jl:50 (check("scan docs --hard-only", ...) calls scan_docs, which now throws)
- src/CLI/Doctor.jl:343-346 (CFG.EXEMPTIONS names the entry, for any target)
- test/scans.jl:181-203 (the base test asserting the waiver disables the scan, replaced by @test_throws)

The window replaced 'a waiver on any rule the scan enforces disables it' (base behaviour and base test) with a LedgerError for any policy entry on a non-canonical rule. The refusal is deliberate, and the doctor now names such entries. But the error goes out through the generic crash arm: exit 3 with a stacktrace from `gbg scan docs`, `--hard-only` and the docs wrapper. It is not reported as the consumer's cannot-evaluate (2). The refusal is also wider than the silently-wide defect it answers: it fires for a file-scoped target, which under canonical-only resolution would never have disabled anything.

### `2026-09-15-audit-changes-01/executing#2` [minor/high] A seeded check-consistency round that plants NO seed now opens (exit 0); base refused it, and the check-docs path still does

- src/CLI/Rounds.jl:167-175 (prepare, check-consistency seed branch: refusal replaced by note_seed_skips!, no empty-plan guard)
- src/CLI/Rounds.jl:271-278 (seed_docs_corpus!: the empty-plan refusal kept for check-docs)
- src/CLI/Rounds.jl:225-245 (note_seed_skips! docstring: 'The round still measures the classes that plant, so it is not refused')

The fix turned 'refuse on any skipped class' into 'record and warn'. That is right for a partial skip, but it dropped the refusal for the all-skipped case too, which check-docs keeps. The change is wider than the defect.

### `2026-09-15-audit-changes-01/executing#3` [minor/high] gbg round scripts --reason replaces the frozen scripts BEFORE refusing on a missing HEAD, so the refresh is never recorded

- src/CLI/Rounds.jl:400-424 (refresh_scripts: install_script runs in the loop; the HEAD check and RoundError come after)

The rewrite dropped the placeholder head (a reasonable change), but it checks HEAD after replacing the files instead of before. A refusal that has already done the work, combined with the new 'no-op when nothing differs' rule, leaves the replacement permanently unrecorded.

### `2026-09-15-audit-changes-01/executing#4` [minor/high] The claim-checklist narrowing drops claims of the very kinds it targets: backticked exit codes and subject—predicate clauses split at a spaced dash

- src/CLI/Preflight.jl:344-352 (CLAIM_EXIT third alternative now needs `[0-3]\s+[a-z]`; CLAIM_QUANTIFIER drops all/any/only; CLAIM_TOOL_ID needs a backtick before gbg; CLAIM_CLAUSE splits on ' — ')
- src/CLI/Preflight.jl:410 (qu evaluated per clause)
- test/rounds.jl:245-255 (the new tests pin only the intended exclusions)

The fix was aimed at version-string digits and line-wide conjunction. The narrowing also removes the backticked exit-contract phrasing used on the guide page, and it treats ' — ' as a clause boundary even where the house style uses it parenthetically between subject and predicate. The tests added pin only the intended exclusions, none of these losses.

### `2026-09-15-audit-changes-01/executing#5` [nit/high] script_sources' docstring says a later name replaces none already taken; the code replaces it

- src/CLI/Preflight.jl:797-818 (script_sources docstring vs filter!/push!)

A new entry point's documentation contradicts its implementation on collision order. The behaviour matches base (the later install overwrote), so only the prose is wrong.

## lane under-rejection

### `2026-09-15-audit-changes-01/under-rejection#1` [major/high] Seed-skip refusal deleted: a check-consistency round planting zero seeds now opens

- src/CLI/Rounds.jl:166-175 prepare (check-consistency) — refusal replaced by note_seed_skips!
- src/CLI/Rounds.jl:273-278 seed_docs_corpus! (check-docs) — refusal replaced by note_seed_skips!; only the plan-empty refusal kept
- src/CLI/Rounds.jl:239-248 note_seed_skips!
- src/CLI/Passes.jl:690-691 grade — the only reader of seed_skipped, a printed WARNING
- schema/round.schema.json seed_skipped
- test/seeds.jl:274-294 — tests note_seed_skips! directly, never prepare's outcome

The refusal went from both prepare paths. The stated reason, that refusing a partly plantable round trades a narrowed measurement for none, covers the partial case. It does not cover the check-consistency path, which lost its only guard against an empty plan: check-docs kept its plan-empty refusal and check-consistency never had one. Nothing downstream treats a narrowed measurement differently from a full one either, so the silence the refusal was added to end is now a printed line and a record field no gate reads.

### `2026-09-15-audit-changes-01/under-rejection#2` [major/high] Claim checklist floor narrowed: 140 lines gone, the backticked exit contract among them

- src/CLI/Preflight.jl:348 CLAIM_EXIT
- src/CLI/Preflight.jl:356 CLAIM_QUANTIFIER
- src/CLI/Preflight.jl:357 CLAIM_TOOL_ID
- src/CLI/Preflight.jl:359 CLAIM_CLAUSE
- src/CLI/Preflight.jl:410 claim_checklist qu
- test/rounds.jl:245-255 — the new assertions pin only the unbackticked exit form and the dropped cases

The defects cited were two false positives: the `1` of a version string, and a quantifier anywhere on a line that names any verb. The edit goes further than those need. It drops three quantifiers, requires backticks on `gbg`, scopes the match to a clause (splitting on every `. `, `;` and spaced dash, table cells included), and requires a lowercase word right after the exit digit, which the tool's own backticked guide prose never has. The new tests assert the dropped cases as intended ("`any` is ordinary prose") and check the exit contract only in an unbackticked form the corpus does not use. The oracle was written to fit the narrowed detector.

### `2026-09-15-audit-changes-01/under-rejection#3` [minor/high] Prose-shape ratchet raised on over-cap page units the same change set grew

- docs/prose_shape.csv:18 ARCHITECTURE.md § D7 (376 → 410)
- docs/prose_shape.csv:3 ARCHITECTURE.md § D10 (433 → 442)
- docs/prose_shape.csv:73 ARCHITECTURE.md § §7.3 (1907 → 1930)
- docs/prose_shape.csv:70 ARCHITECTURE.md § §6.8 (256 → 275)
- docs/prose_shape.csv:48 ARCHITECTURE.md § §1 (622 → 638)
- ARCHITECTURE.md § §12.A (3095 → 3096)
- src/Scans/prose_shape.jl:1-8 (the scan's own statement of the escape)

Six page-unit ceilings that bind only through the ratchet were raised to fit prose added in the same change set. Nothing splits the grown paragraphs, although D11 and §8 show the same diff could split one (D11 126 → 93). The new `prose_shape_changes` listing prints RAISED rows but does not stop the write, so a rebaseline still absorbs every growth.

### `2026-09-15-audit-changes-01/under-rejection#4` [minor/medium] gbg round build exits 0 when its ROUND.toml record fails to save

- src/CLI/Rounds.jl:337-350 record_build!
- src/CLI/Rounds.jl:369-377 build
- src/CLI/Rounds.jl:160-161, 200-201 prepare
- src/CLI/Passes.jl:568-569 pass_open

The error is swallowed so that prepare and pass open can keep going after a build they now record. The swallowing also reached `gbg round build`, whose one extra duty is the record. The rollback of `rec["build"]` is correct, but the exit code no longer says whether that duty was done.

### `2026-09-15-audit-changes-01/under-rejection#5` [minor/medium] gbg round scripts: unchecked precondition, and replacements that leave no record

- src/CLI/Rounds.jl:402-425 refresh_scripts
- policy/instruments.md:85-88
- policy/RULES.toml:626 RULE.INST.FROZEN_MIDROUND statement
- docs/ARCHITECTURE.md D7 (the added exception)
- src/CLI/Preflight.jl:952 (a round opens with head "0"^40 when there is no HEAD)

The frozen-mid-round rule was loosened in the policy text, with a condition that sounds narrow, while the code guard that went in (a reason length) does not test that condition. The reordering also lets an early throw leave scripts replaced with nothing recorded. The verb's record was the only visible trace of a mid-round script change, and in both paths that trace can now be missing.

### `2026-09-15-audit-changes-01/under-rejection#6` [minor/medium] Step-0 import relaxations apply to every round and every directory

- schema/round.schema.json:111 config_sha pattern
- src/CLI/Preflight.jl:125, 146 stamps(cfg::Union{AbstractDict,Nothing})
- src/CLI/Rounds.jl:1010-1019 cmd_round import dispatch
- src/CLI/Rounds.jl:884-891 import_empty

The design wanted `import --empty` to run before `init`, and that part is justified. The relaxation, though, was made in shared contracts (the round schema and `stamps`) and in root resolution, with no scoping: the schema could have allowed `config_sha = ""` only with `abandoned` present, and the root could have required a Project.toml or a git repository. The test only covers the happy path in a bare temp directory.

### `2026-09-15-audit-changes-01/under-rejection#7` [minor/low] close now accepts builds from prepare and pass open, including dirty-tree builds

- src/CLI/Passes.jl:1108-1119 build_fails
- src/CLI/Passes.jl:1183 close
- src/CLI/Passes.jl:553-569 pass_open (reuse comment, then record_build!)
- src/CLI/Rounds.jl:160, 200 prepare

Widening the verbs that satisfy close's build condition makes sense for a clean tree. But record_build! does not check porcelain, although pass_open's own reuse logic treats a dirty tree as having no meaningful HEAD.

## lane behaviour-change

### `2026-09-15-audit-changes-01/behaviour-change#1` [major/high] A policy waiver of RULE.DOC.API_GROUPING (or RULE.CIT.DOI / NO_INACCESSIBLE), any target, now crashes scans and fails the QUICK doctor

- src/Scan.jl:400 apply_ledger (the new loop over rules_for_scan(id) that throws Ledger.LedgerError)
- src/Scan.jl:121 unreachable_waiver_scans
- src/CLI/Doctor.jl:343 CFG.EXEMPTIONS (the new `e["scope"] == "policy"` branch)
- policy/RULES.toml:95,434,451 (the comments declaring the three waivers refused)
- test/scans.jl:187 (the base test that a RULE.CIT.DOI waiver disables the scan, replaced by @test_throws)
- test/sync_doctor.jl:150

The defect the prior audit named was narrow: a target-`*` waiver of a two-rule scan's second rule turned off the whole scan. The fix is much wider. It refuses every policy-scope entry, whatever its target, on any rule that appears second in any scan's check list, and it refuses by throwing from the scan engine instead of a doctor line. That covers RULE.DOC.API_GROUPING, a rule that three other scans own canonically, so a waiver that used to work correctly for those three scans is now rejected. The schema already warns against this failure shape: schema/exemptions.schema.json says of its reason floor that raising it 'crashes Ledger.read, and with it sync, every scan and the docs build, where the doctor would have named the entry and carried on'. The replaced test pinned the base contract; its replacement asserts only the refusal. No test checks that an API_GROUPING waiver still reaches the three HTML scans.

### `2026-09-15-audit-changes-01/behaviour-change#2` [minor/high] Claim checklist narrowed past the version-string defect: about 55% of quantifier items dropped, some genuine claims with them

- src/CLI/Preflight.jl:348 CLAIM_EXIT
- src/CLI/Preflight.jl:356 CLAIM_QUANTIFIER
- src/CLI/Preflight.jl:357 CLAIM_TOOL_ID
- src/CLI/Preflight.jl:359 CLAIM_CLAUSE
- src/CLI/Preflight.jl:410 claim_checklist `qu = any(... split(s, CLAIM_CLAUSE))`
- test/rounds.jl:245-255

The defects cited in the new comment were two: the exit alternative matching the `1` of a version string, and a quantifier anywhere on a line with any verb counting as a claim. The `(?!\.\d)` / `[0-3]\s+[a-z]` guard and the clause split address them. Dropping `only`, `all` and `any` outright, and requiring a backtick before `gbg`, removes a further class of real claims the defects did not involve. The commit message states the measured per-lane reduction ("quantifier items 241→110 in all"), so the change is disclosed rather than silent. It is still an instrument-measurement change wider than the defect that prompted it.

### `2026-09-15-audit-changes-01/behaviour-change#3` [minor/high] A check-docs round's state-verifier scope now follows check-consistency's latex_source_globs, which can only add

- src/CLI/Passes.jl:590 pass_open state args (inside `if inst in Sync.DOCS_INSTRUMENTS` at Passes.jl:549, so check-docs too)
- src/CLI/Preflight.jl:776 source_globs
- src/CLI/Preflight.jl:730 render_args `a["source_globs"] = source_globs(cfg)`
- instruments/check-consistency/workflow/verify-state.js:17-21
- instruments/check-consistency/schema.json:175 (description rewritten from replacement to union)
- test/coverage.jl:139-151

The defect was that the panel's first reader of the key replaced the four surfaces. Changing the panel to a union answers that, and it returns an unset key to rc.11 behaviour. The same edit also rewires a check-docs code path, pass_open's state verifier for check-docs rounds, to read a check-consistency key. That path had no reported defect: at base and at rc.11 it always sent the four surfaces. The instrument schema's documented meaning of the key was rewritten in the same commit, from 'the consumer's globs when it set any' to 'added to them, never in place of them'.

### `2026-09-15-audit-changes-01/behaviour-change#4` [minor/high] `gbg round scripts` needs --reason, and the schema now rejects records the base verb wrote

- src/CLI/Rounds.jl:402 refresh_scripts (reason gate, differing-only loop)
- src/CLI/Rounds.jl cmd_round `verb == "scripts" && return refresh_scripts(cfg, round, get(o.values, "reason", ""))`
- schema/round.schema.json scripts_refreshed items `required` += reason, after_pass, scripts (additionalProperties false)
- test/rounds.jl:856-876

Recording a reason and the replaced shas is a reasonable tightening. But existing records gain three required fields with no migration and no schema_version bump, which breaks reading of any round the previous verb touched. The no-op branch also changes what gets recorded: base appended an entry on every run, head appends nothing when no script differs.

### `2026-09-15-audit-changes-01/behaviour-change#5` [minor/high] On a root with no git HEAD, `round scripts` replaces scripts and then throws before recording anything

- src/CLI/Rounds.jl:413-417 refresh_scripts (install_script inside the loop, HEAD check after it)
- src/CLI/Rounds.jl:371 build (new no-HEAD refusal)
- src/CLI/Passes.jl:1108 build_fails (UNCHECKABLE refusal of an unreachable or placeholder head)
- test/rounds.jl:814 (build no-HEAD tested; refresh no-HEAD untested)

Removing the placeholder head was justified: a zero head read as 'nothing changed' in close's staleness diff, and build_fails now refuses that as UNCHECKABLE. The edit applied that decision in the wrong order in refresh_scripts. The HEAD check runs after the side effect, so the refusal no longer protects anything, and nothing records the replacement.

### `2026-09-15-audit-changes-01/behaviour-change#6` [nit/medium] AUDIT.GAP: equal base/closed-head strings now WARN when the commit is unreachable

- src/CLI/Doctor.jl:636 AUDIT.GAP
- docs/ARCHITECTURE.md §7.3 AUDIT.GAP row and §6.8 (contract rewritten from 'equals' to 'or an ancestor of it')
- instruments/audit-changes/PROTOCOL.md:87
- test/sync_doctor.jl:168

The move from equality to an ancestor test is sound, since an overlap leaves no commit unread. The side effect is that a reachability requirement now applies to the equal case too. A cheap string-equality short-circuit before the git call would keep the old verdict for identical shas. This is a WARN only, reported for completeness.

## lane over-rejection

### `2026-09-15-audit-changes-01/over-rejection#1` [major/high] A policy waiver of any rule some scan enforces non-canonically is now a hard error, including where that rule is canonical elsewhere or the target is not *

- src/Scan.jl:121 unreachable_waiver_scans
- src/Scan.jl:400-408 apply_ledger (the new throw loop)
- src/CLI/Doctor.jl:343-346 CFG.EXEMPTIONS (the new FAIL, in QUICK)
- policy/RULES.toml:95-97, 434-436, 450-453 (the comments declaring the refusal)
- test/scans.jl:187-203 (the base assertion that a RULE.CIT.DOI waiver disables the scan flipped to @test_throws)
- test/sync_doctor.jl:150-164

The defect was a target-* waiver of a scan's second rule silently disabling the scan's canonical rule too. The fix is wider in three ways. (1) It refuses the waiver for EVERY scan the rule reaches, even where the rule is canonical for other scans: RULE.DOC.API_GROUPING owns three HTML scans and is only a second rule of SCAN.API_PAGE_STRUCTURE. (2) It refuses entries of any target and any match table, although only target '*' ever disabled anything. (3) It raises in the scan engine and in a QUICK doctor check, so the refusal fails the consumer's test and docs gates instead of warning. A narrower fix would ignore a non-canonical waiver in the engine and WARN when the rule is canonical nowhere, or refuse only target-* entries on rules with no canonical scan. The same window also rewrote the test oracle that asserted the base behaviour.

### `2026-09-15-audit-changes-01/over-rejection#2` [minor/high] A git root with no HEAD is newly refused by round build and round scripts, and scripts refuses only after it has already replaced the frozen copies

- src/CLI/Rounds.jl:371 build (refuses before running docs_build)
- src/CLI/Rounds.jl:408-417 refresh_scripts (install_script loop, then the RoundError)
- src/CLI/Preflight.jl:952 (a round still opens with head = "0"^40 on such a root)
- test/rounds.jl:815 (the new no-commit refusal test)

Refusing a placeholder head so that close cannot be satisfied by an uncheckable build is defensible for the RECORD. The edit is wider than that: `build` stops building rather than building unrecorded, as its siblings do. The check in `refresh_scripts` also sits after the mutation instead of beside the reason check at the top, so the new rejection leaves the round in the unrecorded state.

### `2026-09-15-audit-changes-01/over-rejection#3` [minor/high] gbg round scripts <round>, the base form, is now refused without --reason, and the CLI usage line still omits the flag

- src/CLI/Rounds.jl:403 refresh_scripts
- src/CLI/Rounds.jl:1006 cmd_round usage line
- test/rounds.jl:859-861 (the base call `refresh_scripts(cfg, name)` rewritten to require a reason)

Requiring a recorded reason makes a mid-round script change visible, and the same window rewrote RULE.INST.FROZEN_MIDROUND to admit exactly that. The rejection is proportionate in spirit. It goes past the defect in two small ways: the length floor of 24 differs from the 12 that `import --empty` and `--rebaseline` ask for, and the usage string, the first place a caller looks, was not updated.

### `2026-09-15-audit-changes-01/over-rejection#4` [minor/medium] A ROUND.toml written by the base scripts verb no longer validates, making its round unloadable and every gate fatal

- schema/round.schema.json:240-290 scripts_refreshed items (required reason, after_pass, scripts)
- src/CLI/Rounds.jl:34-43 load (schema failure -> RoundError)
- src/CLI/Gate.jl:73-74 gate_problems (:invalid -> fatal)

Making the new fields required for new refreshes is the change's purpose. Applying the requirement to entries the previous writer produced, with no default and no migration, turns a record the tool itself wrote into a fatal gate error. Required-for-new with optional-for-old, or a schema_version step, would have been the narrow form.

### `2026-09-15-audit-changes-01/over-rejection#5` [nit/medium] AUDIT.GAP now warns when an audit's base equals the previous closed head but that commit is unreachable

- src/CLI/Doctor.jl:643-646 AUDIT.GAP

Widening equality to ancestry was the stated fix, for overlaps. Dropping the exact-equality short-circuit is extra, and it reclassifies a contiguous pair as a gap whenever the commit cannot be resolved. `base == prev ||` ahead of the ancestry test would keep the fix without the new warning.

## lane public-contract

### `2026-09-15-audit-changes-01/public-contract#1` [major/high] A previously-working exemptions.toml waiver now crashes scans instead of running

- src/Scan.jl:400-421 (apply_ledger)
- src/Scan.jl:113-122 (unreachable_waiver_scans, new)
- src/CLI/Doctor.jl:340-346 (CFG.EXEMPTIONS, new FAIL branch)
- policy/RULES.toml:94-97,433-436,617-620 (new waiver-scope comments)
- test/scans.jl:178-201 (rewritten testset)
- test/sync_doctor.jl:148-165 (new CFG.EXEMPTIONS testset)
- ext/GBGCodingToolsDocumenterExt.jl:50 (scan_docs call site)

The underlying fix (a waiver of a scan's non-canonical rule should not silently disable the sibling rule's enforcement) closes a real, previously-documented defect and is thoroughly tested and cross-referenced in policy/RULES.toml and the new CFG.EXEMPTIONS doctor check. But the chosen mechanism — an uncaught `Ledger.LedgerError` thrown from deep inside the scan engine — routes a consumer-configuration mistake through the tool's generic crash path (exit 3, full backtrace) rather than through the exit-2 "cannot evaluate" path the diff itself is simultaneously formalizing for the structurally identical `Config.ConfigError` case in src/CLI/Main.jl. A config or ledger file that was accepted (if imperfectly honored) before this diff now aborts the process for a consumer who runs `gbg scan docs` directly, or whose CI does not run `gbg doctor` before the docs build.

### `2026-09-15-audit-changes-01/public-contract#2` [major/medium] `gbg round scripts` overhaul rejects the old invocation and can make historical round records unreadable

- src/CLI/Rounds.jl:402 (refresh_scripts signature)
- src/CLI/Rounds.jl:1032 (cmd_round dispatch requiring --reason)
- schema/round.schema.json:238-271 (scripts_refreshed[] required/properties)
- policy/RULES.toml:626-629 (RULE.INST.FROZEN_MIDROUND statement)
- policy/instruments.md:82-89
- test/rounds.jl:850-880 (rewritten 'scripts frozen' testset)

Recording why, when and which scripts were force-refreshed is a real improvement over an untraceable freeze-bypass, and the new CLI verb behavior is thoroughly documented (ARCHITECTURE.md D7/§6.2, policy/RULES.toml, policy/instruments.md) and tested for the forward-going case. What is not covered anywhere in the diff or its tests is the backward direction: a round record already on disk in the OLD (pre-diff) shape. Given `gate()` fails closed on any schema-invalid round under `.gbg/rounds/` — a pre-existing, otherwise reasonable design choice — tightening this one schema's required fields with no migration risks stalling the tool's own gate (hence every docs build and round verb) the first time it re-encounters a round refreshed under the prior tool version. I could not directly verify whether such a record is currently present (`.gbg/rounds/` is out of this lane's permitted scope), so I report the mechanism, not a confirmed live break.

## lane numerics

### `2026-09-15-audit-changes-01/numerics#1` [major/high] CLAIM_EXIT's rewritten third alternative silently stops matching real, unchanged exit-contract prose

- src/CLI/Preflight.jl:348 (CLAIM_EXIT, diff hunk under "const CLAIM_NUMBER = ...")
- docs/src/guide/verbs.md:7 (unaffected by this diff, now silently un-flagged)

The fix widened its guard beyond the defect it targeted: excluding a digit that continues into a decimal (the actual false-positive class, e.g. 'v1.0.0', '2.5') only requires a check on what follows the digit (mirrored correctly by the first two alternatives via (?!\.\d)), not a requirement that the digit be immediately followed by whitespace-then-a-lowercase-word. The added \s+[a-z] suffix is unrelated to the stated defect and introduces a new, undisclosed false-negative class: any backtick- or bold-wrapped digit whose describing word sits elsewhere (a markdown line break, punctuation, or a closing '**'/'`' immediately after the digit) is now invisible to the checklist, even though the OLD regex — and a same-line integration test would have shown — correctly caught it. No new test in this diff exercises a backtick- or bold-wrapped exit-code claim, so the regression shipped unnoticed.

### `2026-09-15-audit-changes-01/numerics#2` [minor/medium] CLAIM_TOOL_ID's `gbg <verb>` alternative now requires a literal backtick, narrower than the disclosed rationale

- src/CLI/Preflight.jl:353 (CLAIM_TOOL_ID)

Distinct from the CLAIM_EXIT finding: here the observed effect is small (3 lines in the current corpus) and plausibly intentional collateral of tightening CLAIM_TOOL_ID to 'the tool is quoted as code' (backticked) rather than 'the word gbg appears', which is a defensible tightening on its own — but it is not the change the surrounding comment claims to be making (a same-clause requirement), so a reader auditing the comment against the code would not expect this second, independent narrowing.

## lane invariants

### `2026-09-15-audit-changes-01/invariants#1` [major/high] round.schema.json's scripts_refreshed shape was tightened with no MAJOR bump, invalidating an already-frozen closed round

- schema/round.schema.json (scripts_refreshed.items.required, and the scripts_refreshed.items.properties additions)
- src/CLI/Rounds.jl :: refresh_scripts / record_build! (the new record shape the schema now demands)
- docs/ARCHITECTURE.md D7 and the diff's own removed round.schema.json docstring (both naming round 2026-09-12-check-docs-01 as a round whose scripts_refreshed entry was written under the old two-field shape)
- Project.toml (unchanged at both ends of the diff)

The scripts_refreshed sub-schema and config_sha pattern in schema/round.schema.json were both edited to match the new refresh_scripts/record_build! machinery this diff adds, but the edit widens (config_sha) and tightens (scripts_refreshed, via three new required fields) the same artefact's schema without the MAJOR bump §5.5 requires for any schema change, and without reconciling the tightening against the pre-existing closed round the diff's own prose says already holds an entry in the old, now-noncompliant shape.

## lane contract-drift

### `2026-09-15-audit-changes-01/contract-drift#1` [major/high] A policy waiver of a rule that a two-rule scan also enforces now throws, for any target

- src/Scan.jl:383-412 apply_ledger (docstring and body)
- src/Scan.jl:113-122 unreachable_waiver_scans
- src/CLI/Doctor.jl:340-346 CFG.EXEMPTIONS
- policy/RULES.toml:95-97, 434-436, 451-453 (the three comments)
- test/scans.jl:178-203 (oracle rewritten)
- test/sync_doctor.jl:148-163

The defect was that a target-`*` waiver of the second rule disabled the whole scan. The fix is wider than that. It refuses every live policy entry on the second rule, whatever its target or match, and it refuses before any hit is seen. The docstring, the RULES.toml comments and the test were rewritten in the same window to call the refusal the contract. At base the over-wide disable was recorded as a known limit, and entries on specific targets never reached the scan.

### `2026-09-15-audit-changes-01/contract-drift#2` [major/medium] FROZEN_MIDROUND gains an exception whose stated condition the verb never checks

- policy/RULES.toml:626 RULE.INST.FROZEN_MIDROUND statement
- policy/instruments.md:85-88
- docs/ARCHITECTURE.md:399-403 D7
- schema/round.schema.json:297 scripts_refreshed description
- src/CLI/Rounds.jl:381-424 refresh_scripts docstring and body

The base verb existed and re-copied every script unconditionally, which contradicted a policy that allowed no exception. Head narrows the verb by requiring a reason and replacing only scripts that differ. But it settles the contradiction by rewriting the rule to admit a relaxation, and the text describes that relaxation more narrowly than the code implements it. A related detail: the refresh_scripts docstring says `Preflight.copy_scripts` 'runs at preflight, and otherwise only here'. At head the verb calls install_script, and copy_scripts's only caller is Preflight.jl:969.

### `2026-09-15-audit-changes-01/contract-drift#3` [minor/medium] round.schema tightened in place, and a tool-written record it refuses is reported as exit 2

- schema/round.schema.json:240-296 scripts_refreshed required
- schema/round.schema.json:108 config_sha pattern
- src/CLI/Rounds.jl:33-45 load
- src/CLI/Main.jl:120-160 (the contrasting ConfigWrittenError rule)

Adding required fields makes records written by rc.9 to rc.11 invalid. The new catch in `load` explicitly routes 'one an earlier tool wrote' to exit 2 without a backtrace. The same diff argues the opposite for configs: 'A config this tool has just written failing to validate is a defect of the tool, not of the consumer, so it must reach the crash path'. The catch also turns every ErrorException from read_round into a consumer-side 'cannot evaluate'. Whether any live record carries an old-shape entry could not be checked, because round files are out of this lane's reach.

### `2026-09-15-audit-changes-01/contract-drift#4` [minor/medium] latex_source_globs flipped from replacing the default surfaces to adding to them

- instruments/check-consistency/schema.json:175 source_globs description
- src/CLI/Preflight.jl:755-777 SOURCE_SURFACES, source_globs
- src/CLI/Preflight.jl:730 render_args
- src/CLI/Passes.jl:590 pass_open source_scope
- instruments/check-consistency/workflow/verify-state.js:17-21
- test/coverage.jl:139-152

The replacement semantics were the documented contract at base, where the reader was introduced. Head reverses them to a union and rewrites the description and the test to match. It cites an audit that saw the replacement as a cut. That may be the right design. Still, it is a change to what a configured value does, made silently in both directions within two windows, and there is no longer any form of the key that narrows.

### `2026-09-15-audit-changes-01/contract-drift#5` [minor/medium] Claim checklist's quantifier class cut by half; guide exit-contract line dropped

- src/CLI/Preflight.jl:344-356 CLAIM_EXIT, CLAIM_QUANTIFIER, CLAIM_TOOL_ID, CLAIM_CLAUSE
- src/CLI/Preflight.jl:410 claim_checklist qu
- test/rounds.jl:245-255

The comment keeps the promise that the class targets claims about the tool, but the new tool-id test and clause split exclude such claims written in plain text. The evidence for the cut is sent to a commit message rather than kept with the code.

### `2026-09-15-audit-changes-01/contract-drift#6` [nit/medium] A count base deliberately kept out of ARCHITECTURE is back, justified by a false 'every count'

- docs/ARCHITECTURE.md:102 §5 rubric.signature_types row
- docs/ARCHITECTURE.md:2381 §12.A RULE.DOC.SIGNATURE_MIRROR row

The row was rewritten to put back a measurement the base design had removed on purpose. The universal claim added to excuse it does not hold for the document it describes.

## lane sweep-completeness

### `2026-09-15-audit-changes-01/sweep-completeness#1` [minor/high] PINNED/MANAGED reclassification of managed.json swept into 3 docstrings but left stale in 4 user-facing sites

- src/CLI/Doctor.jl:254 (CFG.TORN pass/fail message)
- src/CLI/Preflight.jl:917 (preflight refusal message)
- src/CLI/Rounds.jl:76 (round-verb guard refusal message)
- docs/ARCHITECTURE.md:1487-1488 (§6.2 step 2 narrative)
- -- corrected sites, for contrast --
- src/CLI/Doctor.jl:231-236 (pinned_and_managed docstring)
- src/CLI/Preflight.jl:874-882 (torn_check docstring)
- docs/ARCHITECTURE.md:1878 (§7.3 CFG.TORN table row)

This is a 'fix the class, not the line' miss: the same descriptive sentence about what CFG.TORN watches is stated at (at least) seven sites in the corpus, and the correction touched three of them while leaving four verbatim, including two live CLI error strings and one architecture narrative paragraph that both point at the exact same fact the docstrings were just corrected to state differently.

### `2026-09-15-audit-changes-01/sweep-completeness#2` [minor/high] install.md's broadened 'consumer' definition points at the glossary entry it contradicts

- docs/src/guide/install.md:6-9
- policy/glossary.md:3

The docs/make.jl change in this same diff gave the Glossary section an `@id glossary` anchor specifically so this cross-reference could be made (`## [Glossary](@id glossary)`), and install.md was edited to use it in the same commit window that widened the consumer definition — but the widened definition was not propagated to the glossary entry it now cites as authoritative.

### `2026-09-15-audit-changes-01/sweep-completeness#3` [minor/high] The 'BATCH is a constant, not an overridable arg' fix applied to verify-act.js/verify-state.js but not to severity-recheck.js's identical pattern

- instruments/check-consistency/workflow/verify-act.js:8-11 (fixed)
- instruments/check-consistency/workflow/verify-state.js:16-18 (fixed)
- instruments/check-consistency/workflow/severity-recheck.js:5-6,42 (left unswept)

Three Workflow scripts share the identical 'group into units of at most `batch` (default 6)' shape (test/coverage.jl's own comment calls this out as one concept, 'the verifiers batch'). This diff hardened two of the three to `const BATCH = 6` with a comment explaining why (no CLI path ever sends `batch`), and updated their Args comments and test/coverage.jl's assertions to match — but left severity-recheck.js's identical `Math.max(1, A.batch || 6)` and its `batch?` Args-doc line untouched, even though the same justification (no `.jl` call site ever sets `"batch"`) applies to it verbatim.

### `2026-09-15-audit-changes-01/sweep-completeness#4` [minor/medium] RULE.INST.CARRY's new round-close refusal clause reached RULES.toml and policy/instruments.md's substance but not its ARCHITECTURE.md §12.A mirror row

- policy/RULES.toml:626-629 (RULE.INST.CARRY statement, updated)
- docs/ARCHITECTURE.md:2428 (§12.A rule-id table row, unchanged)

RULE.INST.CARRY's ARCHITECTURE.md row is written in close paraphrase of the RULES.toml statement (unlike some other rows, e.g. RULE.INST.FROZEN_MIDROUND, which are deliberately terse); this diff updated the statement to add a clause distinguishing the round-close refusal from the release refusal, and the sibling rule (RULE.DOC.SIGNATURE_MIRROR) got both its RULES.toml-adjacent text and its ARCHITECTURE.md row updated in step, but RULE.INST.CARRY's ARCHITECTURE.md row was not touched.

## lane reader-consequence

### `2026-09-15-audit-changes-01/reader-consequence#1` [major/high] install.md widens "consumer" to include the fixture, then cites the glossary as binding a definition that excludes it

- docs/src/guide/install.md hunk (the 'A **consumer** is…' paragraph)
- docs/make.jl hunk (adds two new '[consumer](@ref install)' cross-links from the generated instruments.md and rules.md pages, both now pointing at the contradictory definition)
- policy/glossary.md:3 (unedited by this diff — the definition install.md's new sentence claims is binding)

The diff edits only install.md's own prose to fold the fixture into "consumer" and to assert the glossary is authoritative for the term, but it does not touch policy/glossary.md (confirmed absent from the diffstat and identical to base via `git show`), so the cited authority contradicts the claim that cites it. This is exactly the shape the lens targets: prose that is locally plausible but leaves the reader with a false belief about a defined, fleet-wide term as soon as they check the source the page itself names.

