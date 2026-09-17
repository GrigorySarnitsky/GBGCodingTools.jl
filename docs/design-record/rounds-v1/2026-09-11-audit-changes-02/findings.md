# Findings — 2026-09-11-audit-changes-02

The work list, by id. Fix the CLASS, not the line; a seeded finding (marked) is never fixed in the corpus.

## lane executing

### `2026-09-11-audit-changes-02/executing#1` [major/high] docs_build_skipped now fails, instead of skipping, a local docs build during an open docs round whose files are uncommitted after HEAD moved — wider than the :disabled defect it fixed

- src/DocLints.jl:47-51 (docs_build_skipped)
- src/CLI/Gate.jl:83-85 (:committed problem)
- test/gate.jl:55-64 (only :disabled is tested)

The fix switched the skip test from 'any exit-1 refusal while a docs round is open' to 'every gate_problems entry is :open'. That excludes both :disabled (the reported defect) and :committed (never mentioned as a defect). The second exclusion changes the outcome of a previously valid local docs build mid-round.

### `2026-09-11-audit-changes-02/executing#2` [minor/high] docs/prose_shape.csv, the ratchet's frozen baseline, was re-baselined in the same window as the prose it guards, silencing 25 GREW hits

- docs/prose_shape.csv (whole-file re-baseline)
- src/Scans/prose_shape.jl:122-124 (the GREW ratchet)

The prose-shape ratchet baseline was regenerated in the window that grew the prose. Each silenced row is a place where the ratchet's 'rewrite, do not append' was waived without a per-row record.

### `2026-09-11-audit-changes-02/executing#3` [minor/medium] ScanResult/report DEAD contract narrowed to match the code: a zero-population scan with a ledger-exempted hit is now declared not DEAD

- src/Scan.jl:36-37 (ScanResult population field)
- src/Scan.jl:449-452 (report docstring)
- src/Scan.jl:458 (dead(r))

The public DEAD guarantee of ScanResult and report was weakened in prose to admit a code path that contradicts the base contract. The retained next sentence now contradicts it.

### `2026-09-11-audit-changes-02/executing#4` [nit/medium] TestHarness.resolve_function docstring's new example `Ledger.read` does not hold when Config is also in `modules`

- src/TestHarness.jl:303-305 (resolve_function docstring)

The docstring fix replaced a wrong example with one that is only half-right: the lookup is by bare name, and the first owning module listed wins.

### `2026-09-11-audit-changes-02/executing#5` [nit/medium] ext comment swaps an existing rule id for a design decision about something else

- ext/GBGCodingToolsDocumenterExt.jl:51

A comment-only edit replaced a valid rule citation with a less specific design-section citation.

## lane under-rejection

### `2026-09-11-audit-changes-02/under-rejection#1` [nit/low] The new public gate_problems leaves out two of gate's refusals, and returns 'no problem' where gate never passes vacuously

- src/CLI/Gate.jl:60-64 (gate_problems, the `isdir(RoundFiles.rounds_dir(cfg)) || return (fatal, problems)` early return)
- src/CLI/Gate.jl:28-35 (gate keeps self_verify and ROUND.DIR to itself)
- docs/src/guide/verbs.md:51 (gate_problems added to the public API page)

Moving the loop into gate_problems was justified: docs_build_skipped needs the kinds of the problems to fix the skip that swallowed a :disabled refusal. But the helper's docstring claims to list what gate refuses for, while the function silently returns 'no problems' for two conditions gate refuses (self-verify failure; ROUND.DIR absent while instruments are enabled). Either the docstring should name the two refusals gate_problems leaves out, or it should say that it is only meaningful after gate returned 1.

## lane behaviour-change

### `2026-09-11-audit-changes-02/behaviour-change#1` [minor/high] The docs-build skip now also fails on a :committed refusal, which is wider than the disabled-instrument defect it fixed

- src/DocLints.jl:47-51 (docs_build_skipped)
- src/CLI/Gate.jl:82-85 (the :committed push in gate_problems)
- ext/GBGCodingToolsDocumenterExt.jl:32-44 (gate_or_skip)

The stated defect (the new test cites ext#4 of 2026-09-11-check-docs-02) is that the skip swallowed an open round of a DISABLED instrument. The fix requires every problem to be `:open`, so it also turns the `:committed` refusal from a skip into a failure. No test covers that case: the added assertions exercise only :open plus :disabled. The base contracts disagree about which behaviour was promised. Base docs_build_skipped said a skip happens "when the gate refused with exit `1` and `GBG_DOCS_NO_SKIP` is unset", which was the old behaviour. Base gate_or_skip said "only because a round of a docs instrument is open", which reads toward the new one. The new DocLints docstring was rewritten in the same hunk to state the widened rule: "or a round whose fixes were committed without it, fails the build". The change may be the intended reading, but it goes beyond the defect cited, it changes the exit of a previously green local build, and no test shows it was considered.

### `2026-09-11-audit-changes-02/behaviour-change#2` [nit/medium] The hard SCAN.PROSE_SHAPE ratchet was re-baselined in the same change that grew the units, including an appended design section

- docs/prose_shape.csv (whole-file rewrite, 30+ rows)
- src/Scans/prose_shape.jl:111-114 (the GREW ratchet)
- catalog/scans.toml SCAN.PROSE_SHAPE tier = "hard"

The scan does allow a deliberate re-baseline when the growth is new content ("re-baseline deliberately if the growth is new content"), and most of the growth is new definitional prose added for cold-reader findings. I record it because the task treats a baseline moved in the same change as a claim: the re-baseline certifies the change set's own prose growth, including the D10 append, and the ratchet no longer compares against pre-change sizes.

## lane over-rejection

### `2026-09-11-audit-changes-02/over-rejection#1` [minor/medium] A bare local docs build during an open docs round now throws whenever the round's files are uncommitted after HEAD moved, where it used to skip with exit 0

- src/DocLints.jl:47-51 (docs_build_skipped)
- src/CLI/Gate.jl:84-88 (the :committed problem inside gate_problems)
- ext/GBGCodingToolsDocumenterExt.jl:32-44 (gate_or_skip, the caller)

The defect the round names (ext#4, per the test comment 'beside an open round of a disabled instrument the build fails') is the disabled-instrument case, and the only new test covers that case alone. The fix goes wider: it also ends the skip for :committed, a signal that at build time cannot tell 'fixes committed without the round' from 'round files not committed yet'. The commit message says the :committed exclusion is intended. Even so, it converts a known over-approximation of the gate, which the skip used to absorb, into a hard failure of the local docs build, and no test checks it.

## lane public-contract

### `2026-09-11-audit-changes-02/public-contract#1` [minor/high] docs_build_skipped() now fails a build it used to silently skip

- src/DocLints.jl:37-51 (docs_build_skipped)
- test/gate.jl:54-63

The exit-1 skip/fail split for makedocs() moved from being keyed purely on the gate's return code to being keyed on the KIND of every problem the gate found; a mixed refusal (open docs round + a disabled-instrument round, or + an uncommitted-round problem) that used to be swallowed as a skip is now a build failure. This is the one behavioural change in an otherwise docstring-only diff, and it is well-tested and well-documented, but it is exactly the shape the lane watches for: a previously-working input (from makedocs' caller's point of view) now takes a different path.

### `2026-09-11-audit-changes-02/public-contract#2` [nit/medium] gate_problems' new element type (Pair{Symbol,String}) is a genuinely new surface, not a change to gate()'s contract

- src/CLI/Gate.jl:31-72 (gate, gate_problems)
- docs/src/guide/verbs.md:47-50

Recorded only because the lane asks specifically about return-value type changes; this one is additive (a brand-new function) rather than a change to an existing contract, so it does not itself break anything, but it is the shape of change (new element type Pair vs the old ad-hoc String) that would be worth watching if any external tooling starts depending on gate_problems' shape before it stabilizes.

## lane invariants

### `2026-09-11-audit-changes-02/invariants#1` [nit/medium] Passes.jl docstring names a "fifth channel" inside a §5.5 closed vocabulary of four

- src/CLI/Passes.jl:18-25 (module docstring)

This is a documentation-only change (no code or schema in the diff touches the four closure channels, Demote.jl's predicate, or any schema file), so it does not itself alter behavior for any previously-valid input. It is reported because it is the one place in the diff that brushes up against the §5.5 closed-vocabulary invariant: it introduces new terminology ("the fifth channel") for a mechanism that the design's own §6.5 heading defines as never closing, inside the exact module docstring that is supposed to be the map of the four-channel closed set.

## lane claim-versus-edit

### `2026-09-11-audit-changes-02/claim-versus-edit#1` [nit/high] Design.jl calibrate() wording fix ('own rubric' -> 'persona') is a drive-by not itemized in the fix-pass-1 commit message

- src/CLI/Design.jl:125 (calibrate docstring)
- commit 47db044

The commit message for 47db044 itemizes every other touched file's finding id precisely, but the Design.jl edit to calibrate()'s docstring is present in the diff with no corresponding bullet, deferred item, or code-claim covering it -- a small but real drive-by against an otherwise complete self-report.

## lane contract-drift

### `2026-09-11-audit-changes-02/contract-drift#1` [major/medium] The DEAD-scan guarantee was reworded to match the code, which exempts a scan whose counter is broken if the ledger ate its hits

- src/Scan.jl:36-37 (ScanResult population field)
- src/Scan.jl:449-451 (report docstring)
- src/Scan.jl:458 dead(r)

A guarantee lost a condition so that it matches what the code does. Behaviour is unchanged. What changed is that the documented refusal now covers the one case the counter exists to expose, when the ledger has exempted its hits. Either the code is right and the 192a336 reasoning should be withdrawn explicitly, or the base promise was right and dead(r) should drop `&& r.exempted == 0`. The edit does neither; it quietly settles the question by rewording.

### `2026-09-11-audit-changes-02/contract-drift#2` [minor/high] The prose-shape ratchet baseline was re-baselined in the same change set that grew the units it guards

- docs/prose_shape.csv (27 rows re-baselined)
- src/Scans/prose_shape.jl (the GREW check)

An oracle re-baselined alongside the edits it would have flagged. Some growth is new content (the gate_problems, economy_model and seeded-copy exception paragraphs). The D10 paragraph growth is appending to an already over-cap paragraph, the case the scan message forbids.

### `2026-09-11-audit-changes-02/contract-drift#3` [minor/high] Section 6.4 now covers docs rounds but still says only the seeded copies exist during the panel

- docs/ARCHITECTURE.md:1612-1614 (section 6.4 Seeds)

A guarantee extended to a case it does not hold for. The same edit left section 11's residue bullet saying 'its residue is unchanged'. For a docs round, though, the answer key is the working tree itself, and diffing against it is easier than diffing against docs/build.

### `2026-09-11-audit-changes-02/contract-drift#4` [minor/medium] D10's docs-round exception drops the design's own reason for keeping seeded copies inside the project, and says nothing of what that costs

- docs/ARCHITECTURE.md:599-605 (D10)
- docs/ARCHITECTURE.md:2235-2239 (section 11 residue bullet)

A principle the design states is quietly narrowed to fit the code, and the honest-limits entry that should record the trade-off still claims nothing changed.

### `2026-09-11-audit-changes-02/contract-drift#5` [minor/medium] docs_build_skipped now fails the build on the ':committed' problem too, which is wider than the disabled-instrument defect it fixed, and no test covers it

- src/DocLints.jl:37-51
- src/CLI/Gate.jl:60-89 (gate_problems)
- test/gate.jl:55-64

The fix follows one of two conflicting base promises. It goes beyond the disabled-instrument defect named in the test comment and also fails on a committed-without-the-round state. That may be intended, but it is an untested behaviour change for local builds in the middle of a round.

### `2026-09-11-audit-changes-02/contract-drift#6` [nit/medium] Demote now defines class_surfaces as 'every OTHER surface', which makes the empty-list demotion contradict its own reasoning

- src/CLI/Demote.jl:8-15
- src/CLI/Demote.jl demote(): `isempty(cs) || any(c -> !get(c, "swept", false), cs)`

The definition was narrowed to match the prompt, but the demotion rule depends on the broader definition and was not reconciled with it.

### `2026-09-11-audit-changes-02/contract-drift#7` [nit/high] The Passes module now says carrying applies only after a spent pass budget, but carry_conditions also allows it below the budget

- src/CLI/Passes.jl:21-24 (module docstring)
- src/CLI/Passes.jl carry_conditions docstring

New prose that describes only half of the carried channel's contract.

## lane sweep-completeness

### `2026-09-11-audit-changes-02/sweep-completeness#1` [major/high] TestHarness.jl drops a false Base-collision example the twin test still asserts

- src/TestHarness.jl:304 (package_operations docstring)
- test/scans.jl:51,58 (unchanged by this diff)

This diff corrected one stated instance of a false claim (that `Scan.report` collides with a `Base` export) inside a docstring, but the identical claim, embedded as the premise of a test loop rather than prose, was left unswept in the same corpus.

### `2026-09-11-audit-changes-02/sweep-completeness#2` [major/high] policy/instruments.md's Honest limits still state the seeded copy lives inside the project unconditionally

- docs/ARCHITECTURE.md:600-604,2232-2237 (edited in this diff)
- policy/instruments.md:95-98 (not touched by this diff)

ARCHITECTURE.md's own D10 section and its Residues bullet were updated in this diff to carry the new check-docs seeding exception, but the policy prose stating the identical residue almost verbatim (word for word: 'a hat that opens it... leaves a read/Read in its transcript') was not swept to match.

### `2026-09-11-audit-changes-02/sweep-completeness#3` [minor/medium] Rounds.jl documents classify_lane's decision ORDER; ARCHITECTURE D10's own enumeration (edited in the same diff) still lists REJECTED last

- src/CLI/Rounds.jl:328-340 (classify_lane docstring, rewritten in this diff)
- docs/ARCHITECTURE.md:608-610 (same paragraph edited in this diff for an unrelated sentence, this sentence untouched)

A precision correction to one docstring's account of an existing (unchanged) code path was not carried into the design document's parallel description of the identical classification, edited elsewhere in the same diff hunk's neighborhood.

### `2026-09-11-audit-changes-02/sweep-completeness#4` [minor/medium] calibrate()'s 'persona' correction leaves rubric-audit.js still calling it the hat's 'own rubric'

- src/CLI/Design.jl:125 (calibrate docstring, edited in this diff)
- instruments/check-consistency/workflow/rubric-audit.js:10 (not touched by this diff)

A docstring's terminology fix (hat 'rubric' -> hat 'persona', avoiding collision with the package's other, defined sense of 'rubric') was not carried to the instrument script whose name and self-description use the identical retired phrase — though instruments are frozen mid-round and such a change would need its own release, per this package's own rule, so this may be a deliberate deferral rather than an oversight.

### `2026-09-11-audit-changes-02/sweep-completeness#5` [minor/low] Preflight.jl's own D16 citations in tag_tree/stamps were left when a sibling docstring's D-number/section citation was dropped

- src/CLI/Preflight.jl:58 (config_sha docstring, edited in this diff)
- src/CLI/Preflight.jl:87,120 (tag_tree and stamps docstrings, same file, not touched)

Low-confidence: this may simply be out of this diff's chosen scope (the D16 citations describe a different, unrelated design point) rather than a left-behind instance of the same edit; flagged because the pattern (drop a D-number citation from a docstring) is otherwise applied consistently across every other touched file.

