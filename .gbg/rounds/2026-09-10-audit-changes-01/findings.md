# Findings — 2026-09-10-audit-changes-01

The work list, by id. Fix the CLASS, not the line; a seeded finding (marked) is never fixed in the corpus.

## lane free-reader

### `2026-09-10-audit-changes-01/free-reader#1` [major/medium] A closed finding whose locations never resolve to a real file is exempt from re-verification forever, and from the new sweep-refusal too

- src/CLI/Passes.jl:58-66 (finding_files)
- src/CLI/Passes.jl:84-116 (pass_scope)
- src/CLI/Passes.jl:119-133 (unswept)

The scoped-reverification feature (new in this diff, extensively documented as an intentional cost-saving change) has an undocumented failure mode: it assumes every finding's `locations` field resolves to at least one real repository file, and when that assumption fails the finding is not flagged as a corner case — it is silently and permanently treated as un-suspectable, which is a stronger exemption than 'not yet re-verified' and was not called out anywhere the design or tests describe the feature.

### `2026-09-10-audit-changes-01/free-reader#2` [minor/high] The new docs_build script-existence check drops a quoted, space-containing script path to a bare filename fragment and then reports it missing

- src/CLI/Config.jl:210-215 (check_paths)

The fix correctly targets a real defect (the old check verified an unrelated fixed path instead of what `docs_build` actually runs), but its regex-based extraction of `.jl` tokens is narrower than the paths the package's own conventions require it to handle, so it swaps one false-pass defect for a new false-fail one on exactly the input shape (space-containing, quoted paths) this codebase calls out as a live concern.

### `2026-09-10-audit-changes-01/free-reader#3` [minor/medium] managed.json's `files` map and tally.json's `per_id` map went from unconstrained additionalProperties to a closed `entry` shape, which can hard-fail sync and grading on a sidecar/tally an older tool version wrote

- schema/managed.schema.json:16 (properties.files.additionalProperties)
- schema/tally.schema.json:69 (properties.per_id.additionalProperties)
- src/CLI/Sync.jl (read_sidecar)
- src/CLI/Passes.jl (grade — the `carried` dict merged into `per_id` before the final schema validate)

A validation-tightening fix that is correctly scoped to the defect it targets (closing a schema hole nothing previously checked), but is wider in effect than a normal PATCH/MINOR-shaped fix because it can retroactively invalidate data files written by any prior release of the tool, and the diff does not add a migration or a softer failure mode for that transition — it is disclosed only in a docstring's prose ('a sidecar an older copy wrote can fail here'), not in any compatibility note.

### `2026-09-10-audit-changes-01/free-reader#4` [nit/high] resolve_function's search order was reversed (externals before modules -> modules before externals), which changes which method-count a consumer's method_parity baseline measures for any name shared with Base

- src/TestHarness.jl:305 (resolve_function)

A narrowly-scoped, well-justified one-line fix to a real defect, included here only because it is a genuine change to a previously-computed result (which method's methods get counted) for any consumer whose surface shadows a Base generic through a submodule, and that class of consumer is named explicitly in the fix's own comment as existing.

## lane executing

### `2026-09-10-audit-changes-01/executing#1` [major/high] resolve_function's reorder is inert, and the docstring it gained states a contract the code does not keep

- src/TestHarness.jl:305 — the loop
- src/TestHarness.jl:293-301 — the new `externals` bullet

The search order of TestHarness.resolve_function was changed and a new docstring bullet was added to justify it. Re-running both orders shows the change has no effect on this package at all, and the docstring's three named examples are wrong: Base has no `report`, and `read`/`run` still resolve to Base after the change because the umbrella module shadows Base in the first tuple element. Either the loop should also stop preferring `pkg` for Base-shadowed names, or the bullet should say what the order actually does.

### `2026-09-10-audit-changes-01/executing#2` [major/high] tally.schema.json widens the closed `state` vocabulary from six values to ten, undeclared in §6.3 and in the CHANGELOG

- schema/tally.schema.json:177 — the added enum members
- schema/tally.schema.json — properties.per_id.additionalProperties
- docs/ARCHITECTURE.md §6.3 — the state-verdict row, untouched by this diff
- CHANGELOG.md — the Unreleased entry

Two changes to tally.schema.json land together: per_id's value schema is closed against `$defs/entry` (which base never referenced — I verified `additionalProperties: true` made it unreachable), and the `state` enum grows by PASS, FAIL, BROKEN, BLOCKED. The widening is NECESSARY given the tightening — Passes.grade already wrote `uppercase(String(r.status))` into `state` for hunt findings at base, so a hunt tally would now throw RoundError — but the necessity is precisely what makes the omission from §6.3 and from the CHANGELOG's classification a problem: the artefact vocabulary and the design record now disagree, and the release is labelled MINOR.

### `2026-09-10-audit-changes-01/executing#3` [major/high] The new signature_fidelity test cannot fail on the defect it names: on the fixture it evaluates to 8 >= 0

- test/scans.jl:41-49 — the added @testset
- src/Reflection.jl:418-421 — the moved counter

The counter move in Reflection.signature_fidelity is correct and matches the base docstring's own words ('how many bindings were actually compared'), but the test added in the same commit to pin it is written against the fixture, which has no extension-homed binding and produces no rows. It measures nothing about the change. Pinning it against the tool's own config (where the EXTENSION-HOMED row exists) would make it discriminate.

### `2026-09-10-audit-changes-01/executing#4` [minor/high] The fixture regression planted for the signature parser states a measurement that is false for its own example

- fixture/GBG Fixture/src/FixtureC.jl:41-50 — the new `span` docstring
- src/Scans/args_form.jl:16-31 — the balanced-paren walk

A new binding was added to the clean fixture as the regression for the args_form parser fix, and its docstring records a measurement of the old behaviour. Re-run, the old parser yields one positional for this signature and raises no hit, so neither the defect nor the fix is observable on the planted case. The parser fix itself is warranted — I confirmed two genuine victims in the tool's own source.

### `2026-09-10-audit-changes-01/executing#5` [minor/high] The new Workflow-prompt guard flags ordinary JavaScript its own both-directions test claims it passes

- test/coverage.jl:38-40 — SPAN_IN_PROSE
- test/coverage.jl:63 — the guard over all 11 scripts
- test/coverage.jl:69-78 — the both-directions testset

A new suite-level guard was added to catch a bare Markdown code span inside a Workflow prompt template. It is a real class and the guard catches it, but its stated contract (ordinary JavaScript is never a finding) is falsified by re-running it on the commonest JS form that ends a word before a template literal. Anchoring on the escape state rather than on the preceding character class, or excluding a `return`/`:` predecessor, would keep the true positives.

### `2026-09-10-audit-changes-01/executing#6` [minor/high] A new test comment reports a regression that never existed: nothing validated against finding.schema.json at base

- test/schemas.jl:104-116 — the added @testset and its comment
- src/CLI/Rounds.jl:397-409 — the validation loop added in the same change set

The added test is harmless in itself (it asserts that the core schema rejects an unprojected hunt finding and accepts the projected one), but its comment misdescribes the base state, and it exercises `validate` directly rather than `bank`, so the projection the change actually introduces is never run by the test. Correcting the comment and driving the assertion through Rounds.bank would make the record honest and the test load-bearing.

### `2026-09-10-audit-changes-01/executing#7` [minor/high] bank's new core-schema refusal is unreachable: every instrument's finding shape already validates after projection

- src/CLI/Rounds.jl:397-409 — the added loop and its exit 2

The loop is defensible as belt-and-braces, but as written it is provably a no-op given the current schema set, and the change set presents it (in test/schemas.jl and in the CHANGELOG's spirit) as closing a real gap. Either the core schema should carry a requirement the instrument schemas do not (so the check discriminates), or the projection should be dropped in favour of validating what is actually written to findings.json.

## lane under-rejection

### `2026-09-10-audit-changes-01/under-rejection#1` [major/high] SCAN.MATHBF now admits `\mathbf{1}` unconditionally, overriding the consumer's `notation.mathbf_allowed`, and the policy that forbade it was rewritten in the same change set

- src/Scans/mathbf.jl:6 — `allowed = Set(String.(cfg["notation"]["mathbf_allowed"])); push!(allowed, "\\mathbf{1}")`
- policy/latex-idiom.md:56-60 — RULE.TEX.MATHBF
- schema/config.schema.json — notation.mathbf_allowed description

The guard removed is the config-driven whitelist itself. At base the scan asked exactly one question — is this `\mathbf{…}` string in the list this package declared? — and the tool held no literal of its own. At head the tool injects `\mathbf{1}` into every consumer's allowed set before the test, so no package can refuse it. If a fleet-wide standing exception is genuinely intended, it belongs where the other non-configurable facts live (ARCHITECTURE §5.5's non-configurable set, or the schema's `const`/`minItems` so an author who empties the list is told), not as a silent `push!` that leaves the key looking configurable. Note also the direction of the invariant the package states for itself: "A consumer holds data; the tool holds behaviour... No package string... in a Workflow script, a catalogue file or a policy file" — a package-visible notation literal now lives in the tool's scan body. The narrower point stands regardless of that reading: input that was previously refused (a `\mathbf{1}` under a config that did not admit it) now yields a clean scan.

### `2026-09-10-audit-changes-01/under-rejection#2` [major/high] Scoped passes retire "every pass verifies every id", and the two mechanisms that decide re-verification silently exclude whole classes of finding

- src/CLI/Passes.jl:56-70 — `finding_files`
- src/CLI/Passes.jl:72-100 — `pass_scope`
- src/CLI/Passes.jl:102-127 — `unswept`
- src/CLI/Passes.jl:322-331 — `grade`'s `carried` merge

The cost argument for scoping is real and is recorded (ARCHITECTURE §6.2 step 7: "the rc.1 round verified 56 findings ten times over where 90 verifications were owed"). What is not justified is the fail-open shape of the two predicates that implement it. Both `unswept` and `pass_scope` treat "I could not resolve a file for this finding" as "nothing to check", when the safe reading of an unresolvable location is the opposite: verify it. A minimal repair is to keep an id in scope whenever `finding_files` comes back empty, and to compute `touched` over the whole tree (or at least to include a named path that no longer exists as touched) rather than over `covered_paths`. Note the quantifier trap the brief names: none of this shows up as "input that used to work now behaves differently" — the affected findings are ones the previous pass CLOSED, so no other lane's question reaches them.

### `2026-09-10-audit-changes-01/under-rejection#3` [major/high] SCAN.ARGS_FORM's new element-type exemption fires on the keyword's NAME alone, so a docstring documenting neither of its arguments now passes a hard scan

- src/Scans/args_form.jl:52-58 — `eltype_kw` and `wants_bullets`

The exemption itself is warranted — `git show <base>:policy/docs-rubric.md` shows the element-type clause already in RULE.DOC.ARGS_FORM at base, so this is not a rule invented to fit the code. The implementation is wider than the rule in the direction that fails silently: it exempts on a name pattern instead of on the presence of the prose binding the rule requires. Gating `eltype_kw` on `prosed` (i.e. exempt only when the docstring actually binds the arguments in running prose) would restore the rule's meaning and cost nothing. The same edit is also narrower than the rule in the loud direction, which is worth stating because it is the same line: for a two-argument docstring with a `T` keyword written in bullets — clean at base, since `wants_bullets` was true — head now takes the `!wants_bullets && bulleted` branch and hits with "bind them in running prose, not bullets", converting the rule's permission into an obligation.

### `2026-09-10-audit-changes-01/under-rejection#4` [minor/high] RULE.DOC.SHAPE's statement was weakened to match what the scan already did, while the policy paragraph the consumers read was left saying the stronger thing

- policy/RULES.toml — `[[rule]]` RULE.DOC.SHAPE `statement`
- docs/ARCHITECTURE.md §12.B — the `SCAN.PROSE_SHAPE` row
- src/Scans/prose_shape.jl:1-9 — the header comment
- policy/docs-rubric.md:206-210 — RULE.DOC.SHAPE (unchanged)

This is the "contract rewritten to match the behaviour" shape with the behaviour standing still. The defensible options were: change the code so a baselined page unit is still capped (which is what "always" promised and what IT's own recorded lesson argues for), or, if the trade is deliberate, change all three surfaces together and say so in `CHANGELOG.md` as a policy relaxation. What was done instead relaxes the rule index and ARCHITECTURE while leaving the rendered policy paragraph stronger, so a consumer reading `.gbg/policy/docs-rubric.md` and a hat reading the RULES.toml statement are now enforcing different rules. Flagged as minor rather than major only because the underlying under-enforcement pre-dates this window; the relaxation of the written norm is inside it.

### `2026-09-10-audit-changes-01/under-rejection#5` [minor/medium] The round-lifecycle test no longer exercises the default `pass open` path — the same commit that added the sweep refusal re-baselined the assertion that used to cover it

- test/rounds.jl:149-153 — the "round lifecycle" testset

The re-baseline itself is honest: the comment added beside it says plainly that "this lifecycle plants verdicts instead of fixing, so it says so rather than pretending otherwise", and the new `@testset "a pass verifies what is open, and refuses an unswept fix"` does test `unswept`, `finding_files` and `pass_scope` as units. What is missing is a lifecycle run through the default path — a fixture round whose fix pass actually touches the files its findings name, so `pass_open` returns 0 without `sweep_ok`. Without it, the flag that exists for the exceptional case is the only case the integration test covers, and the guard added in this commit is the reason. This is the oracle-inside-the-change-set shape: the test that would have caught a default-path regression was edited by the commit that introduced the branch.

### `2026-09-10-audit-changes-01/under-rejection#6` [minor/medium] `TestHarness.resolve_function` now prefers a package binding over the Base generic it extends, which can make `module_method_count` undercount methods a consumer's frozen parity baseline was written to cover

- src/TestHarness.jl:304-311 — `resolve_function`
- src/TestHarness.jl:326-333 — `module_method_count`
- src/TestHarness.jl:352-372 — `method_parity`

The stated motive ("a package function always wins its own name") is reasonable and the docstring names three examples in this very package, but the change is to a public harness engine that this repository does not exercise: there is no `test/method_parity.jl` and no `method_parity_baseline.toml` under `test/`, and the tool's declared deviations put the allocation and traffic contracts out of scope here. Its only consumers are the four science packages, whose frozen baselines were not and could not be regenerated in this change set. That leaves a computed count altered with no oracle anywhere in the tree, and the first evidence either way will be a consumer's `Pkg.test()` after the next `gbg bump`. Confidence is medium, not high, because the practical reach depends on whether `isdefined(pkg, name)` already resolved a Base-exported name at the umbrella — in which case the reorder is inert for exported generics and bites only for the shadowed submodule case described above.

### `2026-09-10-audit-changes-01/under-rejection#7` [nit/high] `CFG.SURFACES` no longer requires `docs/make.jl` to exist; the guard survives only because `WIRE.MAKEDOCS` still hardcodes the path

- src/CLI/Config.jl:205-212 — `check_paths`
- src/CLI/Doctor.jl:377-382 — `WIRE.MAKEDOCS`

The fix itself is right and the base text was the defect: checking a fixed path while ignoring the script the command actually runs meant the file that runs went unchecked. The residue is that the unconditional `docs/make.jl` requirement was dropped from `CFG.SURFACES` while `WIRE.MAKEDOCS` still demands `docs/make.jl` by name (`isfile(p) || return fail("WIRE.MAKEDOCS", "docs/make.jl absent")`), so the loosening is fully shadowed for any real consumer: `WIRE.MAKEDOCS` is in `QUICK` and in `NON_EXEMPTABLE`. Hence nit, not minor. Worth a line only so that a later relaxation of `WIRE.MAKEDOCS` — which the new `CFG.SURFACES` text invites, since it now speaks of "every `.jl` script the `docs_build` command names" — is not made on the assumption that `CFG.SURFACES` is still holding that requirement.

## lane behaviour-change

### `2026-09-10-audit-changes-01/behaviour-change#1` [blocker/high] The new sweep refusal in `pass open` contradicts the audit's own staleness rule: an audit round can no longer open a pass at all

- src/CLI/Passes.jl:172-181 — the `if !sweep_ok … return 2` block added in pass_open
- src/CLI/Passes.jl:119-135 — `unswept`, which skips only seeded and `scans`-lane findings
- src/CLI/Passes.jl:574-576 — close's pre-existing audit condition `stale = Git.changed_paths(root, "$(a["head"])..HEAD", covered)` must be EMPTY
- instruments/audit-changes/PROTOCOL.md:76-79 — the step-4 paragraph added in this change set
- src/CLI/Rounds.jl:421-423 — bank's new audit NEXT line

The defect the edit claims to fix is real and narrow ("the rc.1 round spent five of ten passes" learning that a fix stopped at one location). The remedy chosen is a hard, default-on refusal applied to every instrument, including the one whose protocol forbids the very tree movement the refusal demands. A warning printed at `pass open`, or the gate restricted to `check-docs`/`check-consistency`/`bug-hunt` and to non-adjudicated ids, would fix the defect without making a whole instrument unusable by default.

### `2026-09-10-audit-changes-01/behaviour-change#2` [major/high] A scoped pass silently deflates `demoted_by_rule` and `adjudicated_share` in the tally, the two rates `gbg fleet --diff` compares

- src/CLI/Passes.jl:329-331 — `findings = scope === nothing ? all_findings : …` then `per_id = copy(carried); … demoted = 0; adjudicated = 0`
- src/CLI/Passes.jl:437-440 — the tally's `totals`, `demoted_by_rule` and `adjudicated_share`
- src/CLI/Fleet.jl:103-115 — `Fleet.diff`, whose table "holds the totals, the closure channels, the demotions, the adjudicated share and the recall"

Carrying closed entries forward is the point of the scoping change and is done correctly for `per_id`, `closed` and `open_ids`. The two aggregate counters were simply not carried with them: they are re-derived from scratch each pass over a set that is no longer the whole round. Summing the carried entries (counting `haskey(e, "adjudicated_entry")` and `e["act_demoted"]` over `carried`) would have kept them whole.

### `2026-09-10-audit-changes-01/behaviour-change#3` [major/high] SCAN.MATHBF now admits `\mathbf{1}` whatever the config says, and RULE.TEX.MATHBF was amended in the same commit to license it

- src/Scans/mathbf.jl:6 — `allowed = Set(String.(cfg["notation"]["mathbf_allowed"])); push!(allowed, "\\mathbf{1}")`
- policy/latex-idiom.md:59-60 — the sentence added to RULE.TEX.MATHBF
- schema/config.schema.json:309 — the new `description` on `mathbf_allowed`
- docs/src/guide/config.md:17-18

Granting `\mathbf{1}` fleet-wide may well be the owner's intent, but it is a change to a closed per-package configuration point and to the fleet rulebook, and it is delivered as a hard-coded `push!` that the config can no longer override in either direction. If the exception is genuinely universal, the honest implementation is to remove `mathbf_allowed` from the config's range or to refuse a list that omits it at CFG.VALID, not to accept the knob and ignore it.

### `2026-09-10-audit-changes-01/behaviour-change#4` [major/medium] `TestHarness.resolve_function` reordered its search, changing which function object a colliding name denotes and therefore the counts of four consumers' frozen method-parity baselines

- src/TestHarness.jl:305 — `for mod in Iterators.flatten(((pkg,), modules, externals))`
- src/TestHarness.jl:326-333 — `module_method_count`, which sums `count(m -> m.module === mod, methods(f))` over that resolution
- src/TestHarness.jl:352-379 — `method_parity`, which asserts those counts against `test/method_parity_baseline.toml`

The docstring added in the same hunk asserts the defect ("`Config.read`, `Git.run` and `Scan.report` all share one with a `Base` export, and Base ahead of them handed the caller the wrong generic"), and the new order is very likely the right one. What is missing is any check that the fix is inert or any record that it is not: a harness function whose whole purpose is to make frozen counts reproducible had its resolution order changed with no test, no baseline update and no note that consumer baselines will move.

### `2026-09-10-audit-changes-01/behaviour-change#5` [minor/high] SCAN.SIBLING_LINK gained a second hit class on a hard, build-gating scan, so a corpus that passed its docs build now fails it

- src/Scans/sibling_link.jl:24-36 — the `seen` flag replacing `break`
- catalog/scans.toml:120-126 — `tier = "hard"`, `surfaces = ["all"]`
- fixture/GBG Fixture/defects/page.md:10-11 and defects.toml — the new `linked-later-mention` fixture

RULE.DOC.SIBLING_LINK already said both halves at base — "Later mentions in the same unit are bare code spans" — so the scan was under-enforcing a written rule and the fix is warranted; the fixture gained the matching defect and the catalogue row lists it. What the change set does not carry is any acknowledgement that a hard gate widened: no CHANGELOG entry is in the covered paths, and a first-mention miss now also produces a second hit for each later link on the same unit.

### `2026-09-10-audit-changes-01/behaviour-change#6` [minor/high] RULE.DOC.HOME_ORDER moved caveats from position (4) to (7), changing the standard four frozen corpora are judged against

- policy/docs-rubric.md:12-20 — the reordered rule
- policy/RULES.toml:21-22 — the statement and the LEG.SENTINELS sentinel rewritten to match
- catalog/hats/doc-policy.toml:10 and catalog/hats/structure-consistency.toml:36 — the two personas rewritten to the new order
- docs/ARCHITECTURE.md:2216 — the §12.A row

Reordering a fleet rubric is the owner's call and may well be right (it matches the `# Fields`-last convention). The audit point is that it arrives inside a change set whose stated business is elsewhere, with no migration note, no deviation ledger entry, and the two hats' personas quietly rewritten in the same commit so that the instrument and the rule agree with each other and with nothing that was written before.

### `2026-09-10-audit-changes-01/behaviour-change#7` [minor/high] `check_paths` now rejects a `docs_build` command that names no `.jl` script, so `Config.read` throws and every `gbg` verb refuses

- src/CLI/Config.jl:208-214 — the regex extraction replacing the fixed-path test
- src/CLI/Config.jl:237-247 — `Config.read`, which raises the collected problems as a `ConfigError`
- docs/ARCHITECTURE.md:1122 and 2196 — the CFG.SURFACES row and the annotated example

Checking the script the command actually runs is the right fix for the defect named in the comment. Requiring the command to name a `.jl` file at all is a separate, stricter rule that was added with it and is not the defect: a `docs_build` naming no script could simply skip the loop, leaving the wrapper case as valid as it was. The new test in test/config.jl covers only the two `.jl`-naming directions and never the wrapper case, so the new rejection is untested.

### `2026-09-10-audit-changes-01/behaviour-change#8` [minor/medium] SCAN.ARGS_FORM now counts a bare splat as a parameter, so prose-form docstrings of `f(x; kwargs...)` become hits

- src/Scans/args_form.jl:41-48 — the `splats` helper and the two `append!` calls
- src/Scans/args_form.jl:6-7 — the whitespace-tolerant `ARGS_BULLET`/`ARGS_PROSE` regexes
- src/Scans/args_form.jl:54-56 — `wants_bullets`

Two of the three edits in this scan are clean defect fixes with fixture coverage: the balanced-paren parameter list (the `span(options) -> (lo, hi)` case planted in FixtureC.jl) and the eltype-keyword exemption, which restores a written exemption the scan was ignoring. The splat counting is a third, independent widening — it asserts that `kwargs...` is "a parameter the rule counts", which RULE.DOC.ARGS_FORM does not say — and it ships with no fixture and no test.

## lane over-rejection

### `2026-09-10-audit-changes-01/over-rejection#1` [major/high] pass_open's new sweep refusal makes every audit-changes round unopenable, and the same commit adds the protocol rule that guarantees it

- src/CLI/Passes.jl:173-181 — the `if !sweep_ok` block in pass_open
- src/CLI/Passes.jl:119-133 — unswept
- instruments/audit-changes/PROTOCOL.md step 4 — the added paragraph
- src/CLI/Passes.jl:575-577 — close()'s `no graded pass` condition

The guard is written for the doc instruments, where a fix pass moves files between bank and pass open, but it is applied unconditionally in `pass_open`, which every instrument shares. For audit-changes the premise is false by the design this very commit records, and the refusal is total rather than incidental. Either the guard should skip `inst == "audit-changes"` (as it already skips seeded findings and the `scans` lane for exactly this kind of reason — "never fixed in the corpus"), or the audit protocol must name `--sweep-ok` as its normal invocation. As shipped, a correct audit workflow is refused by default and the operator learns it only from the refusal text.

### `2026-09-10-audit-changes-01/over-rejection#2` [major/high] unswept compares a whole-tree `named` set against a covered-paths-only `touched` set, so a fix outside src/test/ext/docs can never clear the refusal

- src/CLI/Passes.jl:58-66 — finding_files
- src/CLI/Passes.jl:120-121 — `touched = Set(Git.changed_paths(root, range, Preflight.covered_paths(cfg)))`
- src/CLI/Preflight.jl:400 — covered_paths

The two sets are drawn from different universes. Either `finding_files` should keep only paths under the covered paths (so the guard judges what it can observe), or `touched` should be taken over the whole tree (`Git.changed_paths(root, range, ["."])`). As written, a legitimate, complete fix is reported as a half-fix, and the escape hatch is all-or-nothing rather than per-finding.

### `2026-09-10-audit-changes-01/over-rejection#3` [major/high] The adjudicated and deferred closure channels close a finding without touching its files, and the new refusal blocks the pass that would record them

- src/CLI/Passes.jl:122-124 — unswept's skip list
- src/CLI/Passes.jl:173-181 — the refusal in pass_open
- src/CLI/Passes.jl:482-500 — carry_deferrals

The skip list encodes exactly the right idea — "a finding that is not fixed in the corpus is not evidence of a half-fix" — but names only two of the four cases. Adjudication and deferral belong in it, or the refusal has to be per-finding rather than a whole-pass exit 2. The docstring's own escape ("for the fix that rightly lives somewhere else") concedes the case exists; it just makes the operator pay for it across every other finding.

### `2026-09-10-audit-changes-01/over-rejection#4` [major/high] The only test covering pass_open in a normal round lifecycle was re-baselined from 0 to 2 in the same commit as the guard

- test/rounds.jl:151-152
- src/CLI/Passes.jl:173-181

Re-baselining the oracle in the same commit as the behaviour is the certifies-itself shape. The honest form here would be to make the lifecycle fixture sweep its findings' locations (a one-line touch of the quoted files before `pass open`) so the test still asserts 0, and to add a separate assertion for the refusal. As it stands, if the guard were later made unconditional or its escape removed, this test would keep passing.

### `2026-09-10-audit-changes-01/over-rejection#5` [major/high] check_paths' new docs_build scan adds a refusal the config schema makes unreachable and a per-token existence check that fires on any `.jl`-ending substring

- src/CLI/Config.jl:208-214
- schema/config.schema.json — package.docs_build `"pattern": "docs/make\\.jl"`
- test/config.jl:11-18
- docs/ARCHITECTURE.md §7.3 CFG.SURFACES row

Wider than any defect it can fix, and the contract prose was rewritten to match: docs/ARCHITECTURE.md's CFG.SURFACES row moved from "`docs_build` names `docs/make.jl` and that file exists" to "every `.jl` script the `docs_build` command names exists". The new oracle in test/config.jl reaches the asserted behaviour only by hand-merging a Dict — `Dict("docs_build" => "julia --project=docs docs/build_the_site.jl")` — that the config schema's own pattern refuses, so the test certifies a state no real consumer config can be in.

### `2026-09-10-audit-changes-01/over-rejection#6` [minor/medium] SCAN.SIBLING_LINK's new later-mention half is hard-tier and its link pattern matches any URL under the sibling's site, including a deep link

- src/Scans/sibling_link.jl:26-36
- catalog/scans.toml:123 — `fixture = ["bare-sibling", "linked-later-mention"]`, tier `hard`

The half being added was already written policy at base ("Later mentions in the same unit are bare code spans"), so enforcing it is licensed by RULE.TEST.RULE_WITH_CHECK; the concern is that the check is wider than the rule and lands at hard tier with no triage step. Two files in this change set had to be edited to comply (fixture/GBG Fixture/docs/src/index.md and the fixture's prose_shape.csv re-baselined from 61 to 81 words), which is the corpus telling you existing prose was newly rejected. A narrower `link_re` — anchored to the site's own index, `\Qsite\E["')]` — would enforce the rule without foreclosing the deep link.

### `2026-09-10-audit-changes-01/over-rejection#7` [minor/high] SCAN.ARGS_FORM now counts a bare splat as an argument, so `f(cfg; kwargs...)` documented in prose becomes a hit

- src/Scans/args_form.jl:44-49
- src/Scans/args_form.jl:4-5 — the marker regexes
- src/DocLints.jl — the makedocs docstring rewritten in the same commit

The tier is `triage` in both base and head, so this warns rather than fails a build — that is why it is minor and not major. Still, it is a widening of what the scan rejects that was not required by any defect the diff names: the comment justifies counting the splat only as "a parameter the rule counts", which the rule text does not say. The new `eltype_kw` exemption in the same hunk moves the other way and is well-founded, quoting the rule's own last clause.

### `2026-09-10-audit-changes-01/over-rejection#8` [minor/medium] signature_fidelity's population no longer counts extension-homed bindings, adding a DEAD (exit 2) path for a package whose exports all live in an extension

- src/Reflection.jl:418-424
- test/scans.jl:41-48 — the oracle added with it

The move is correct on its own terms and the comment explains it well. Reported here only because it converts a previously-passing configuration into an exit 2 with no ledger route named in the message and no test in the failing direction; a consumer meeting it will read "measured nothing" and have nothing to do about it.

## lane public-contract

### `2026-09-10-audit-changes-01/public-contract#1` [blocker/high] managed.json/tally.json schemas newly reject shapes they used to accept, and the throw is uncaught in `gbg sync`

- schema/managed.schema.json:15-23 (files.additionalProperties)
- schema/tally.schema.json:68-76 (per_id.additionalProperties)
- src/CLI/Sync.jl:494-503 (read_sidecar, SyncError message)
- src/CLI/Sync.jl:600-604 (sync() calling status()/read_sidecar with no try/catch)

A JSON-Schema tightening on two persisted, cross-version artifacts (the managed-file sidecar and a round's tally) turns a previously-permissive validation into a closed one, and the resulting throw is not caught at the one CLI verb (`gbg sync`) that reads the newly-strict file on every run — for a class of breakage the authors themselves flagged (and partially reverted) in the same commit.

### `2026-09-10-audit-changes-01/public-contract#2` [major/high] TestHarness.resolve_function's search order flipped (externals before modules -> modules before externals), silently changing which colliding function every consumer's method_parity/oracle_registry count

- src/TestHarness.jl:304-310 (resolve_function)

A one-line reorder in a shared, pinned test-harness primitive changes which of two colliding functions is resolved for a name — a genuine bug fix per its own comment, but a computed-result change for every consumer with no changelog entry, and no test in this repository exercises the collision case it fixes.

### `2026-09-10-audit-changes-01/public-contract#3` [major/high] `gbg round pass open` now refuses by default (exit 2) on calls that previously succeeded (exit 0), and the change is absent from CHANGELOG.md

- src/CLI/Passes.jl:96-115 (pass_open signature and new sweep_ok logic)
- test/rounds.jl:149-153

A new keyword defaulting to a stricter mode changes the CLI's default outcome for previously-valid invocations of `gbg round pass open`; the change is real, intentional, and documented in the source and the architecture doc, but not in the changelog a reader would check for exactly this kind of change.

### `2026-09-10-audit-changes-01/public-contract#4` [minor/high] `gbg round bank` gained a new exit-2 refusal path (core-schema validation) after every witness/panel cost is already spent

- src/CLI/Rounds.jl:395-410 (bank(), new core-schema validation block)

This is a narrowly-scoped, well-tested fix for a real prior gap (the core finding shape was never checked at bank time), added with a paired regression test — but it is still a new failure mode for previously-accepted lane files, arriving at the most expensive possible point in the round's cost.

### `2026-09-10-audit-changes-01/public-contract#5` [minor/medium] SCAN.SIBLING_LINK (hard tier, gates the docs build) now fails on a sibling name that is correctly linked TWICE, which used to be clean

- src/Scans/sibling_link.jl:20-33 (sibling_link_hits!)
- catalog/scans.toml (SCAN.SIBLING_LINK fixture list)

An intentional, documented and fixture-tested strengthening of a hard-tier scan's rule (RULES.toml and catalog/scans.toml were updated in the same commit, and a new fixture defect/clean-twin pair was added) — but it is exactly the shape the audit brief calls out: it rejects a previously-clean usage under a scan whose exit code gates a real build.

## lane numerics

### `2026-09-10-audit-changes-01/numerics#1` [major/high] grade()'s adjudicated_share and demoted_by_rule silently undercount from pass 2 onward under the new scoped-pass carry-forward

- src/CLI/Passes.jl:317-341 (scope/carried setup)
- src/CLI/Passes.jl:436-440 (closed vs demoted_by_rule/adjudicated_share)

The scoped-grading feature is a legitimate, well-motivated addition (it avoids re-verifying ids nobody touched), and `closed`/`open`/`totals.findings` were correctly adjusted to stay cumulative. `demoted_by_rule` and `adjudicated_share`, however, were left as simple per-call accumulators — an oversight, not a deliberate design choice, since the fix for `closed` (deriving it from the full `per_id` map rather than a running counter) was already at hand two lines away and simply wasn't applied to the other two statistics.

### `2026-09-10-audit-changes-01/numerics#2` [minor/medium] SCAN.ARGS_FORM's new eltype-keyword exemption regex is wider than the written exemption it implements

- src/Scans/args_form.jl:57-59

The fix correctly closes a real gap (the written exemption existed in policy/docs-rubric.md at base but SCAN.ARGS_FORM never implemented it), but the implementation is wider than the rule's own wording: "element-type" became "any name ending in _type", silently widening what a keyword-bearing docstring can get away with in prose form.

## lane invariants

### `2026-09-10-audit-changes-01/invariants#1` [major/high] Two artefact schemas were closed (additionalProperties widened to strict $ref) and shipped as MINOR, contradicting §5.5's own MAJOR rule for schema changes

- schema/managed.schema.json:12-17 (files.additionalProperties)
- schema/tally.schema.json (per_id.additionalProperties)
- src/CLI/Sync.jl:494-497 (read_sidecar docstring/message)
- CHANGELOG.md Unreleased section

The underlying motivation (closing an unvalidated map so a malformed sidecar/tally entry is caught rather than silently accepted) is reasonable, but the package's own written invariant classifies any schema change as MAJOR, and this diff both under-declares the severity (MINOR) and, by its own admission, did not disclose the schema tightening in the responsible commit message. The fix is real but the compatibility break for pre-existing artefacts is not scoped or announced to match the package's own rule for this exact kind of change.

### `2026-09-10-audit-changes-01/invariants#2` [minor/medium] TestHarness.resolve_function's module search order was reversed (externals now searched last, not first), silently changing which module 'owns' a name-colliding method for method_parity counting fleet-wide

- src/TestHarness.jl (resolve_function)

This appears to be a genuine, well-motivated bug fix (the tool's own operations were being misattributed to Base), and it is the correct behavior a reader of module_method_count's docstring would expect. It is not disclosed in the CHANGELOG's Unreleased section at all, unlike the schema tightening above, even though it is a fleet-wide, silently-behavior-changing edit to a frozen-baseline harness contract that every consumer inherits on bump.

## lane claim-versus-edit

### `2026-09-10-audit-changes-01/claim-versus-edit#1` [minor/high] fc7eca35 claims resolve_function's search order was one of three CODE fixes; the commit never touches the loop order

- src/TestHarness.jl:304 (current `for mod in Iterators.flatten(((pkg,), modules, externals))`)
- commit fc7eca35631fe20d77098cf810edd91b1290e48e — src/TestHarness.jl docstring hunk (@@ -295,7 +295,8)

This is the shape the claim-versus-edit lane exists to catch: the commit's own prose describes an edit ('code the earlier edit never reached', now presumably reached) that is not in its diff. The docstring edit is real and small, but it documents the pre-existing (still-buggy, per the later commit's own words) order rather than fixing it, so the claim overstates what this specific commit does.

### `2026-09-10-audit-changes-01/claim-versus-edit#2` [nit/medium] fc7eca35 says 'instrument' was cross-linked in eleven modules; the diff shows eight

- commit fc7eca35631fe20d77098cf810edd91b1290e48e — src/CLI/Audit.jl, Gate.jl, Passes.jl, RoundFiles.jl, Rounds.jl, Sync.jl, TestHarness.jl, Witnesses.jl

A numeric overclaim in the commit message (11 vs 8 files touched for this specific cross-link). Could be an honest miscount rather than scope creep, and it does not correspond to any missing or extra edit found elsewhere in the round's later passes (which would have caught a truly bare 'instrument' mention).

## lane contract-drift

### `2026-09-10-audit-changes-01/contract-drift#1` [major/high] RULE.TEST.RULE_WITH_CHECK now counts "a working agreement no artefact records" as a check, in the same paragraph that still says remembering a rule is not enforcement

- policy/testing-protocol.md:56-67 (the RULE.TEST.RULE_WITH_CHECK paragraph)
- policy/RULES.toml:1-8 (the header defining the check classes) and the 25 rows carrying check = ["panel"] or check = ["session"]
- test/schemas.jl:5415-5439 of the diff (the new "every rule declares what catches its next violation" testset)

The taxonomy is a reasonable bookkeeping addition, but it was written so that the two new classes are declared "answers". A defensible version records `panel` and `session` as sub-kinds of the debt rather than as satisfaction of it; that would have kept the sentence about remembering intact and left the 25 rows visible as weaknesses. As edited, the rulebook's one self-policing rule can no longer be violated: every rule now declares something, and three of the six declarable values require nothing to be built.

### `2026-09-10-audit-changes-01/contract-drift#2` [major/high] RULE.DOC.HOME_ORDER's docstring order reversed fleet-wide, and the new order contradicts RULE.CIT.FULL_INLINE's "# References at its end"

- policy/docs-rubric.md:12-22 (RULE.DOC.HOME_ORDER)
- policy/RULES.toml:21-23 (statement, sentinel, check)
- policy/citations.md:9-11 (RULE.CIT.FULL_INLINE, unchanged in substance)
- catalog/hats/doc-policy.toml:9 and catalog/hats/structure-consistency.toml:35

The reordering may be defensible, but the change set does not carry the evidence for it and does not carry the consequence. Nothing in this package forced it: the re-baselined docs/prose_shape.csv shows admonitions = 0 on every docstring unit of src/, so the tool's own corpus has no docstring caveat to place. The two personas that would report the divergence — doc-policy and structure-consistency — were rewritten to the new order in the same commit, so the instrument that judges the order and the order it judges moved together. Neither the rule paragraph nor RULE.CIT.FULL_INLINE was amended to say which of the two owns the end of a docstring.

### `2026-09-10-audit-changes-01/contract-drift#3` [major/high] A new binding fleet rule was appended inside RULE.INST.AUDIT_AFTER_CODE's paragraph, with no id, no register statement and a check that tests something else

- policy/instruments.md:38-43 (RULE.INST.AUDIT_AFTER_CODE)
- policy/RULES.toml:571-576 (id, statement, sentinel, check)
- instruments/audit-changes/PROTOCOL.md step 4 (the parallel new paragraph)
- docs/ARCHITECTURE.md §6.8 (the parallel new paragraph)
- src/CLI/Rounds.jl bank(): the new instrument-specific NEXT line

The substance may well be right (the staleness check does make a corrected audit round unclosable). The defect is the delivery: a rule that changes how every consumer runs /audit-changes was given no id of its own, no one-line statement, no sentinel and therefore no way for the ledger, the doctor or a scan to reach it, while inheriting a check earned by a different requirement. Compare RULE.DOC.ARGS_FORM in this same change set, which was given its own id, statement, sentinel and scan:SCAN.ARGS_FORM.

### `2026-09-10-audit-changes-01/contract-drift#4` [major/high] SCAN.PROSE_SHAPE's "Caps bind ALWAYS" and the caveat naming re-baselining as the escape were rewritten away — with the scan's code byte-identical, in the change set that re-baselines the CSV wholesale

- src/Scans/prose_shape.jl:3-6 (the header comment)
- src/Scans/prose_shape.jl:96-115 (the register body — unchanged at base and head)
- policy/RULES.toml:231 (RULE.DOC.SHAPE statement)
- docs/ARCHITECTURE.md §12.B, the SCAN.PROSE_SHAPE row
- docs/prose_shape.csv (~100 re-baselined rows)

The honest correction is defensible in the scan header, where a comment contradicted the function two lines below it. It is not defensible in policy/RULES.toml, which is rendered into four consumers as the statement of RULE.DOC.SHAPE: there "always" was a promise about the fleet's prose, and dropping it lowers the standard for every consumer's pages without any consumer asking. If the caps genuinely cannot bind a baselined page unit, the entry owed is a ledger deviation or a `weakness`, not a quieter rule. Nothing in the diff records the lesson's loss as a debt.

### `2026-09-10-audit-changes-01/contract-drift#5` [major/high] SCAN.MATHBF now admits \mathbf{1} whatever the config says, while RULE.TEX.MATHBF's register statement still reads "admitted only for the strings in notation.mathbf_allowed"

- src/Scans/mathbf.jl:6
- policy/latex-idiom.md:56-60 (RULE.TEX.MATHBF)
- policy/RULES.toml:357-359 (statement, sentinel — unchanged)
- schema/config.schema.json:309
- docs/src/guide/config.md and docs/ARCHITECTURE.md §12.B (the SCAN.MATHBF row)

The exception is coherent with RULE.TEX.MATHBB, which does name \mathbf{1} as the indicator and identity, and the schema description and the guide page were both updated. What was not done is the register row, which the design (§12.A) makes the one-line authority. Two of the three places that state the rule now say opposite things about whether the config can withhold \mathbf{1}.

### `2026-09-10-audit-changes-01/contract-drift#6` [major/medium] The tally artefact's `state` vocabulary was widened by four values without §6.3, the design's closed-vocabulary table, being touched

- schema/tally.schema.json:170-181 (the state enum of $defs/entry)
- docs/ARCHITECTURE.md:1530 (§6.3, the state-verdict row — unchanged)
- src/CLI/Passes.jl:398 (entry["state"] = … uppercase(String(r.status)), unchanged in the window)

A schema widened to admit values the code already produced is the right repair. The drift is that the authoritative vocabulary table is the design document, not the schema file, and only the schema moved. Either §6.3 gains the four values with the note that they arrive from the witness re-run, or the grade path stops overloading `state` with a witness status — but the two cannot say different things while §6.3 is cited as the constant.

### `2026-09-10-audit-changes-01/contract-drift#7` [minor/high] CFG.SURFACES no longer requires docs_build to name docs/make.jl; the fleet constant was dropped and replaced by a regex over the command string

- src/CLI/Config.jl:208-214 (check_paths)
- src/CLI/Config.jl:165-170 (the check_paths docstring)
- docs/ARCHITECTURE.md:1123 (the config example's comment) and :1759 (the CFG.SURFACES row)
- test/config.jl:5238-5245 of the diff (the new assertions)

The doc was updated in both places, so this is disclosed rather than silent, which is why it is minor. What is missing is any replacement for the dropped constant: nothing in the change set says whether a consumer may now point docs_build anywhere, or whether docs/make.jl remains required by some other check. The regex is also looser than the prose: [^\s"']+\.jl picks a .jl token out of any part of the command line, including one inside a -e script body, and each such token is then required to exist as a file.

### `2026-09-10-audit-changes-01/contract-drift#8` [minor/high] The comment recording why the fixture must be a test dependency was deleted, and nothing replaced it

- test/Project.toml (the [sources] block)
- src/CLI/Audit.jl:16-18 (where the parallel note for the tool's own path source was added)

Nothing in the edit required removing the comment: the change to this file is the addition of a dep and a source. The deletion is collateral, and it removes a warning rather than a stale claim — the claim is still true at head.

## lane sweep-completeness

### `2026-09-10-audit-changes-01/sweep-completeness#1` [major/high] RULE.DOC.SHAPE's new ratchet-scoping clause reached the scan catalogue but not its own declared source paragraph or the rule table

- policy/RULES.toml:231 (statement)
- policy/docs-rubric.md:205-209 (### RULE.DOC.SHAPE, unchanged)
- docs/ARCHITECTURE.md:2238 (§12.A RULE.DOC.SHAPE row, unchanged)
- docs/ARCHITECTURE.md:2333 (§12.B SCAN.PROSE_SHAPE row, updated)

A real behavioural relaxation (an already-baselined page unit is now held by the ratchet alone, not by the fixed 120-word/3-admonition cap) was swept into the scan catalogue's own descriptive row (§12.B) and into RULES.toml's summary statement, but not into the rulebook paragraph RULES.toml is generated from, nor into the twin rule-id table (§12.A) that sits a few hundred lines away in the same file and describes the identical rule.

### `2026-09-10-audit-changes-01/sweep-completeness#2` [major/high] \mathbf{1}'s new unconditional, fleet-wide exception reached five sites but not the rule table, RULES.toml's statement, or the LaTeX-typesetter hat's persona

- policy/RULES.toml:357-358 (statement/sentinel, unchanged)
- docs/ARCHITECTURE.md:2255 (§12.A RULE.TEX.MATHBF row, unchanged)
- docs/ARCHITECTURE.md:2321 (§12.B SCAN.MATHBF row, updated)
- catalog/hats/latex-typesetter.toml:9 (persona, unchanged)

A behavioural and policy change (a consumer that sets `notation.mathbf_allowed = []` can no longer be flagged for writing `\mathbf{1}`) was propagated to the scan implementation, the rulebook paragraph, the config schema description and the config guide, and to the §12.B scan-catalogue mirror — but not to the §12.A rule-id mirror two hundred lines above it in the same ARCHITECTURE.md, not to RULES.toml's own one-line statement of the rule, and not to the latex-typesetter hat's persona, which this very diff touched (its `needs` line) without touching the now-contradicted "where the rulebook allows it" clause a few lines below.

### `2026-09-10-audit-changes-01/sweep-completeness#3` [major/high] The new panel-vs-weakness distinction, written to correct exactly this case, was not carried into CLAUDE.md's own deviation entry — even though this diff re-rendered that very line

- policy/testing-protocol.md:63-69 (new panel/weakness/session taxonomy)
- policy/RULES.toml:296 (RULE.API.POSITIONAL check=["panel"])
- CLAUDE.md:5 (deviation entry, still "KNOWN WEAKNESS")

testing-protocol.md's new text is self-referential ("a rule this rulebook has long called a known weakness") and RULES.toml was updated in lock-step to classify RULE.API.POSITIONAL as `panel`, but the one place that actually spells out RULE.API.POSITIONAL's deviation in prose — CLAUDE.md, touched by this very diff for an unrelated formatting reason — still asserts the terminology the new rule explicitly retires.

### `2026-09-10-audit-changes-01/sweep-completeness#4` [minor/high] The new `--sweep-ok` flag on `gbg round pass open` reached six sites but not IMPLEMENTATION.md's own CLI verb table

- IMPLEMENTATION.md:289
- docs/ARCHITECTURE.md:1474-1476
- src/CLI/Passes.jl:138
- src/CLI/Rounds.jl:646,652

IMPLEMENTATION.md is the package's own build-plan spec table for exact CLI signatures, so it is exactly the kind of site this rule's sweep should have reached; the new flag was added to the ARCHITECTURE narrative, the code, the usage strings, and two instrument protocols, but the CLI-signature reference table describing the very same verb was left untouched.

## lane reader-consequence

### `2026-09-10-audit-changes-01/reader-consequence#1` [minor/high] New fixture docstring cites internal RULE./SCAN. ids meaningless to a REPL reader

- fixture/GBG Fixture/src/FixtureC.jl:41-49 (new `span` function and its docstring)

The diff adds a new `span(options)` fixture function whose docstring, after the ordinary identity/argument/returns prose, appends an explanatory paragraph about why the SCAN.ARGS_FORM parenthesis-matching bug in GBGCodingTools' own scanner used to mis-parse this exact signature. That explanation is meta-commentary for a future maintainer reading the source, not documentation of what `span` does — but it lives inside the rendered docstring body, so it is exactly as reachable to a REPL reader as the rest of the text, in a package whose own rubric (RULE.DOC.NO_DEAD_REFS, RULE.DOC.SELF_CONTAINED, RULE.DOC.HOME_ORDER's exclusion list) exists specifically to keep this kind of content out.

