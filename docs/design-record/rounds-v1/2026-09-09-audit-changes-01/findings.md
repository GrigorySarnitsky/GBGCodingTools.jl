# Findings — 2026-09-09-audit-changes-01

The work list, by id. Fix the CLASS, not the line; a seeded finding (marked) is never fixed in the corpus.

## lane executing

### `2026-09-09-audit-changes-01/executing#1` [blocker/high] The tally schema now validates per_id entries, and the state Passes.grade writes for a witness-verified bug-hunt finding is outside its enum — every such grade throws

- schema/tally.schema.json:68 (per_id)
- schema/tally.schema.json $defs.entry.state
- src/CLI/Passes.jl:274
- src/CLI/Passes.jl:318

The schema reformat carried one real tightening: per_id entries are now checked against $defs.entry. Nothing checked that the code writing per_id obeys that entry shape, and it does not — the bug-hunt branch reuses `state` to carry a witness status, whose spelling was never in the state vocabulary. The tool's own test suite exercises no bug-hunt grade, so the gate is green while the verb is broken. Either the enum must admit the witness statuses (they are a different axis and probably want their own key) or line 274 must map them onto the state vocabulary; the tightening itself is right and should stay.

### `2026-09-09-audit-changes-01/executing#2` [major/high] Dropping `rulebook` from the latex-typesetter hat's needs forbids it the very file its persona is told to treat as authoritative

- catalog/hats/latex-typesetter.toml:4
- instruments/check-consistency/workflow/panel.js:61
- instruments/check-consistency/workflow/panel.js:87
- src/CLI/Preflight.jl:369

The edit reads as a tidy-up of a redundant grant but is the opposite: it strips the hat's authoritative substrate. A check-consistency round run after this change gives the LaTeX hat a persona that commands it to read a file it is explicitly forbidden to open, so the hat must fall back on generic taste — which its own first sentence rules out (`Your rubric is NOT generic taste`). It also changes `not_applicable`: at base a package with no `rulebook_sections` skipped this hat, at head it runs blind.

### `2026-09-09-audit-changes-01/executing#3` [major/high] SCAN.MATHBF now hard-codes `\mathbf{1}` over the consumer's configured mathbf_allowed, and only one of the four places that state the contract was amended

- src/Scans/mathbf.jl:6
- policy/latex-idiom.md:59
- policy/RULES.toml:357
- docs/ARCHITECTURE.md:2242, 2308, §5.5

The substantive call — that RULE.TEX.MATHBB's indicator should not be bannable — may well be right, but it is a fleet-wide narrowing of a documented variation point made in a scan file, with the register, the rule statement and the scan catalogue left stating the old contract and the non-configurable set left unamended. A consumer reading RULES.toml (the rendered rulebook the hats and the ledger cite) is told something the code no longer does.

### `2026-09-09-audit-changes-01/executing#4` [major/high] Raising the ledger reason bound from 24 to 40 in the schema turns a reported CFG.EXEMPTIONS failure into a crash of sync, scan and the docs build

- schema/exemptions.schema.json:61
- src/CLI/Ledger.jl:38
- src/CLI/Main.jl (main's catch-all -> 3)

Aligning the schema with CFG.EXEMPTIONS is defensible, but it changes the failure MODE of previously-loadable input from a graded finding to an unhandled exception, and it does so for the four consumers' existing ledgers, none of which were migrated in this commit and none of which the diff inspects. If the alignment is wanted, either the callers must catch LedgerError and degrade to an empty ledger the way Doctor.context does, or the migration must come first.

### `2026-09-09-audit-changes-01/executing#5` [minor/high] The CFG.SURFACES contract row was rewritten to drop the `docs_build names docs/make.jl` clause while check_paths is byte-identical, and the parallel julia_test clause was left in place

- docs/ARCHITECTURE.md §7.3 CFG.SURFACES row
- docs/ARCHITECTURE.md:1120
- src/CLI/Config.jl:164 (check_paths docstring)
- src/CLI/Config.jl check_paths body

Three of the added clauses ([paths] entries are directories, glossary, built_html/docs) are genuine currency corrections that the code does perform. The removal is the problem: a documented check disappeared from the check table in the same window in which the code was not touched, and the sibling clause that would have made the inconsistency visible was left standing. Either both clauses belong on the CFG.VALID row, or both belong here.

### `2026-09-09-audit-changes-01/executing#6` [minor/high] The prose-shape cap contract was rewritten from `Caps bind ALWAYS` to `docstrings and NEW page units only` with the scan code untouched, and the rule it implements still says always

- src/Scans/prose_shape.jl:1-9 (header comment)
- docs/ARCHITECTURE.md §12.B SCAN.PROSE_SHAPE row
- policy/RULES.toml:231 (RULE.DOC.SHAPE statement)
- policy/docs-rubric.md RULE.DOC.SHAPE
- docs/prose_shape.csv

The prose is now honest about what the scan does, which is an improvement over the base comment. What makes it an audit concern is that the correction was applied to the two places a maintainer reads (the scan header, the scan catalogue row) and not to the rule the fleet is governed by, so RULES.toml — the register the ledger validates against and LEG.SENTINELS reads — and the ARCHITECTURE §12.B row now disagree about the same rule, with the weaker reading in the place a reader checks when a page grows.

### `2026-09-09-audit-changes-01/executing#7` [minor/high] The new coverage assertion is wider than the defect: it rejects any interpolation-free template literal in a Workflow script, valid JS included

- test/coverage.jl:53-55
- test/coverage.jl:59-64

The regression itself is real and the both-directions twin is correct (I ran it: unescaping hunt.js yields 13 matches, and the pre-existing even-backtick check passes on that broken file, so a second check was genuinely needed). The concern is scope: the assertion bans a legal construct rather than detecting the one that breaks the template literal. A narrower shape — a bare pair inside a template literal, or a pair whose contents look like a path or flag — would catch the defect without conscripting all future JS.

### `2026-09-09-audit-changes-01/executing#8` [minor/high] SCAN.SIBLING_LINK gained a second, hard-tier hit class, so a page that links a sibling package twice now fails the docs build where it passed

- src/Scans/sibling_link.jl:18-30
- catalog/scans.toml SCAN.SIBLING_LINK (tier hard)

The second half of RULE.DOC.SIBLING_LINK (`later mentions are bare`) was always in the rule and in RULES.toml's statement; the scan simply never enforced it, and closing that gap is right. The audit concern is only that a hard-tier scan gained a hit class that will fire on previously-green consumer corpora, in a change set that reads as documentation work, with no note of the migration cost.

## lane under-rejection

### `2026-09-09-audit-changes-01/under-rejection#1` [major/high] The DEAD-scan refusal gained a conjunct: a scan whose population counter reads zero no longer stops the run when it happens to have hits

- src/Scan.jl:453 (the hard-tier loop of `report`)
- src/Scan.jl:467 (the triage loop of `report`)
- src/CLI/Rounds.jl:169 (`prepare`, the check-docs arm)

The comment added with the change — 'a scan that HIT measured something: its hits are never dropped by the dead branch' — names a REPORTING defect (the DEAD branch printed no hits) and fixes it by deleting the DEAD verdict instead. The narrow fix is to print the hits and still mark DEAD with code 2. As written the edit is wider than the defect twice over: it removes the refusal rather than the silence, and it removes it in three places at once including `prepare`'s independent warning. It is also redundant with the same commit's own narrower fix — `src/Scans/field_docs.jl` was separately re-counted so its NOLIST hits no longer land with population 0 — so the concrete case that motivated the change was already handled at its source.

### `2026-09-09-audit-changes-01/under-rejection#2` [major/high] SCAN.FIELD_DOCS now counts structs it could say nothing about, defeating the vacuous-pass guard its own header still describes

- src/Scans/field_docs.jl:50-53
- src/Scans/field_docs.jl:4-5 (the header sentence left in place)

The defect being fixed (a NOLIST-only run reading as DEAD) is real, but the fix redefines the scan's population from 'structs whose bullets were compared' to 'structs opened', which is not what population means anywhere else in `Scan.jl` ('what the scan measured'). A fix that preserves the guard is to count a struct as measured when EITHER a documented list or a real field list was successfully parsed — that admits the NOLIST run and still reports DEAD when both parsers come back empty. The header comment stating the old contract was left verbatim, so the file now documents a guard its code no longer has.

### `2026-09-09-audit-changes-01/under-rejection#3` [major/high] SCAN.MATHBF hardcodes `\mathbf{1}` into the allowed set, making `notation.mathbf_allowed` partly inert and this package's own empty list a lie

- src/Scans/mathbf.jl:6
- src/Scans/mathbf.jl:1-4 (the header rewritten in the same commit)
- policy/latex-idiom.md:59-60 (the rule paragraph amended in the same commit)
- policy/RULES.toml:357 (the register's statement, unchanged)

This is the shape the audit brief names: a guard removed from the code and, in the same commit, the prose that stated the guard rewritten to legitimise the removal — `policy/latex-idiom.md` gained 'it is not a package's to withhold' while `RULES.toml`'s one-line statement and sentinel, which are the register the instruments cite and `LEG.SENTINELS` reads, still say the config list is the sole authority. The stated motive (RULE.TEX.MATHBB names `\mathbf{1}` as the indicator) argues for adding `\mathbf{1}` to the SCHEMA DEFAULT — which already carries it (`schema/config.schema.json:304-309`) — not for overriding a package that explicitly cleared the list. As it stands the tool's own config says one thing and the scan does another, with no ledger entry recording the deviation.

### `2026-09-09-audit-changes-01/under-rejection#4` [major/high] The latex-typesetter hat lost its `rulebook` need, so it is no longer handed the rulebook its persona orders it to read first

- catalog/hats/latex-typesetter.toml:4
- instruments/check-consistency/workflow/panel.js:87 (the line that is now never emitted for this hat)
- src/CLI/Preflight.jl:230-231 (`not_applicable`, which this hat can no longer reach)

The comment justifies the removal by claiming the persona reads the rendered policy file rather than a `rulebook_sections` grant, but the rendered policy file is delivered BY that grant — `rulebook_text` writes the policy files and the sections into one payload, and `needs = ["rulebook"]` is the only switch that puts its path in the prompt. `catalog/hats/doc-policy.toml` kept `needs = ["rulebook", "source"]` for the same reason, so the two rulebook hats are now inconsistent. Either the persona's first sentence should have been rewritten with the need, or the need should have stayed; removing one half leaves a dead pointer in an instrument that is frozen mid-round.

### `2026-09-09-audit-changes-01/under-rejection#5` [major/high] The requirement that `docs_build` name `docs/make.jl` was deleted from the specification instead of being implemented

- docs/ARCHITECTURE.md:1746 (the `CFG.SURFACES` row)
- docs/ARCHITECTURE.md:1123 (the annotated config example)
- src/CLI/Config.jl:167-169 (the `check_paths` docstring)

Correcting a docstring that overstated a check is right; deleting the requirement from the DESIGN RECORD in the same edit is not the same act, and it leaves no trace that a stated refusal was dropped. The commit that introduces `RULE.TEST.RULE_WITH_CHECK`'s `check` field — whose whole point is that a rule without a check is a declared weakness rather than a silent one — resolves this gap in the opposite direction, by removing the rule. The honest forms were to keep the §7.3 wording and add the two-line check to `check_paths`, or to keep it and record the gap.

### `2026-09-09-audit-changes-01/under-rejection#6` [minor/high] RULE.DOC.SHAPE is registered as mechanically checked in the same commit that records the check does not enforce it on baselined page units

- policy/RULES.toml:233 (`check = ["scan:SCAN.PROSE_SHAPE"]`)
- src/Scans/prose_shape.jl:3-6 (the header rewritten)
- docs/ARCHITECTURE.md:2320 (the §12.B row rewritten)

Two of the three documents describing this cap were relaxed to match the code and the third, the rule itself, was left strict; the new `check` field then asserts the relaxed check enforces the strict rule. Either the rule paragraph should have been relaxed with them (a policy change, with its own ledger consequences) or the `check` entry should have carried a recorded partiality. The new test in `test/schemas.jl` cannot tell the difference: it only asserts the scan id exists in the catalogue.

### `2026-09-09-audit-changes-01/under-rejection#7` [minor/medium] The new rule-check oracle verifies a `harness:` binding by bare substring — the exact match the same file's other test was narrowed to reject

- test/schemas.jl:161-162 (the `harness:` arm)
- test/schemas.jl:96-97 (the sibling test narrowed in the same commit)

All eleven `harness:` targets happen to resolve to real bindings today, so nothing is currently mis-certified; the concern is the guard, not the present state. A rename or deletion of `Passes.grade`, `Witnesses.run` or `Preflight.render_args` leaves three rules claiming an enforcer that no longer exists and this test green, because some other `grade(`/`run(`/`render_args(` survives in 60-odd source files. The narrowing the sibling test received — require the token on a line that also carries the defining construct — applies here unchanged.

### `2026-09-09-audit-changes-01/under-rejection#8` [nit/medium] SCAN.ARGS_FORM's type exemption was widened from a literal to a whitespace-tolerant regex, skipping docstrings it previously judged

- src/Scans/args_form.jl:9 (the exemption)
- src/Scans/args_form.jl:6-7 (the two markers)

The motive stated in the added comment — 'the marker line-wraps in this package's own prose, and a literal substring missed it' — is a real false negative and the regex is the right shape for the two argument markers. The fields exemption is the collateral: it was not the false negative being fixed, and widening a whole-docstring skip is the one edit in this file that removes hits rather than adding them. Recorded at nit because the surface is small and the same commit's other edits to this scan (balanced-paren signature parsing, splat counting) move it firmly in the strict direction.

## lane behaviour-change

### `2026-09-09-audit-changes-01/behaviour-change#1` [major/high] SCAN.ARGS_FORM now parses a different parameter list and counts splats, inverting its verdict on docstrings that were clean

- src/Scans/args_form.jl:20-43 (the depth-matched close paren and the splat append)
- src/Scans/args_form.jl:7 (ARGS_BULLET String -> Regex)

Two independent widenings landed in one edit. The close-paren fix is warranted (the base `findlast(')')` genuinely mis-parsed any signature with a parenthesised return or a parenthesised default) and its comment names the defect. The splat append is a separate rule reading — that `args...`/`kwargs...` counts toward the threshold and, as a keyword splat, forces the bulleted form on its own — that RULE.DOC.ARGS_FORM does not state (the rule says "three or more arguments, or any keyword argument"; whether a keyword SPLAT is "a keyword argument" is the judgement being silently made here). Neither the rule text nor the fixture case `wrong-args-form` was touched, so nothing outside the scan records the new reading, and the splat regex matches the type of a typed splat as well as the splat itself.

### `2026-09-09-audit-changes-01/behaviour-change#2` [major/high] SCAN.SIBLING_LINK, a hard scan, now also fails a LATER linked mention — prose that passed before now blocks the docs build

- src/Scans/sibling_link.jl:26-37

The second half of RULE.DOC.SIBLING_LINK ("Later mentions in the same unit are bare code spans") was genuinely unenforced, and the rule text is IDENTICAL at base and head — this is a real gap being closed, not a rule invented to justify an edit. The concern is not the fix but its shape: it turns a previously unreachable half of a HARD scan on, fleet-wide, in a window whose diffstat is otherwise docstring reflow, with no CHANGELOG entry in the change set (CHANGELOG.md is not in the diff) stating the widened scan, and with the scan's fixture still carrying only the one direction (`fixture = ["bare-sibling"]`), so the new branch has no positive case proving it fires only where it should.

### `2026-09-09-audit-changes-01/behaviour-change#3` [major/high] exemptions.schema.json reason minLength 24 -> 40 turns a doctor FAIL into a thrown LedgerError in every verb that reads the ledger

- schema/exemptions.schema.json:61 (reason.minLength)
- src/CLI/Ledger.jl:37-38 (the throwing loader)

Aligning the schema with the check CFG.EXEMPTIONS already enforced is defensible, and the old description explicitly recorded the split ("CFG.EXEMPTIONS checks the longer bound"), so the 24 was deliberate, not an oversight: the schema was the permissive gate and the doctor the strict one, on purpose, so that a too-short reason was REPORTED rather than fatal. Collapsing the two removes the reporting path. If the tightening is wanted, the ledger loader is the place that should keep degrading gracefully — or the change belongs in a release note, since it rejects a consumer file that was valid under every previous pin.

### `2026-09-09-audit-changes-01/behaviour-change#4` [major/high] SCAN.MATHBF now admits \mathbf{1} unconditionally, so notation.mathbf_allowed no longer controls the scan it names

- src/Scans/mathbf.jl:6
- policy/latex-idiom.md:59-60 (the rule amended in the same commit)

The substantive claim is sound: RULE.TEX.MATHBB does name `\mathbf{1}` as the indicator and identity, so a package banning it contradicts a sibling rule, and the config schema's own default already lists it. The concern is scope and channel — a config key's meaning narrowed in the scan body while the rule paragraph is edited in the same commit that ships the scan, which is the shape the package's own invariant forbids ("Instruments are frozen mid-round: a change to a scan … is its own commit and its own release"). A reader of the ledger cannot exempt their way back either: the hit no longer exists to exempt.

### `2026-09-09-audit-changes-01/behaviour-change#5` [major/high] RULE.DOC.HOME_ORDER reorders the docstring skeleton fleet-wide: a docstring that obeyed the rule now violates it

- policy/docs-rubric.md:11-18 (RULE.DOC.HOME_ORDER)
- policy/RULES.toml:18-24 (statement + sentinel)
- catalog/hats/doc-policy.toml:9
- catalog/hats/structure-consistency.toml:5

Nothing in the change set says WHY the order moved; the reorder arrives with no defect it repairs and no note in the diff (CHANGELOG.md is not in the change set). It is a MINOR-or-worse policy change by the package's own reckoning — the rendered policy is a managed file in every consumer and `LEG.SENTINELS` matches the sentinel verbatim, and the sentinel changed too, so a consumer `CLAUDE.md` that restated the old sentence is affected. Reordering the rule and both hat personas in the same commit means no round can ever be graded against the old order again to see which reading the corpus was written to.

### `2026-09-09-audit-changes-01/behaviour-change#6` [minor/medium] managed.schema.json and tally.schema.json close their open maps, so a sidecar or tally that validated now throws

- schema/managed.schema.json (properties.files.additionalProperties)
- schema/tally.schema.json (properties.per_id.additionalProperties)
- src/CLI/Sync.jl:503, src/CLI/Passes.jl:318

Wiring an already-written `$defs/entry` that nothing referenced is a real dead-schema fix and is consistent with the other "the schema existed and nothing validated against it" edits in this commit. What makes it a behaviour change rather than a no-op is that these two artefacts are PERSISTED consumer state written by earlier versions, not freshly built objects: unlike `import.json` and the banked-findings projection (both constructed in the same function that validates them), `managed.json` and `tally.json` come off disk. No migration, no `schema_version` bump and no fallback accompanies the tightening.

### `2026-09-09-audit-changes-01/behaviour-change#7` [minor/high] The DEAD guard now yields to hits: a scan that measured nothing but hit returns exit 1 instead of exit 2

- src/Scan.jl:453 and src/Scan.jl:467 (report)
- src/CLI/Rounds.jl:169 (prepare's mirror)
- src/Scans/field_docs.jl:50 (the population that made it reachable)

The fix is right and the two halves belong together — a scan that produced hits demonstrably measured something, and counting a struct as examined the moment it is opened is the honest population. It is reported here because it silently changes an exit code for input that was valid before, in a package whose stated invariant is that exit codes are the contract, and because the loud symptom it repairs (hits swallowed by the DEAD branch) is the same thing that hid the defect until now: nobody can tell from the outside which consumers were affected, since the swallowed hits were never printed.

### `2026-09-09-audit-changes-01/behaviour-change#8` [minor/medium] signature_fidelity stops counting extension-homed bindings, so its population can now fall to zero and mark the scan DEAD

- src/Reflection.jl:418-424

The base docstring already said `examined` is "how many bindings were actually compared, which is the scan's population", so the code was wrong against its own base contract and the move is the correct repair — the norm pinned at base supports the edit rather than undermining it. It is reported here only because it changes a scan verdict, in the DEAD direction, for input that previously passed, and because the same commit deliberately relaxed the DEAD branch elsewhere (Scan.report) while tightening this population, so the two edits push a consumer's exit code in opposite directions with no note tying them together.

## lane over-rejection

### `2026-09-09-audit-changes-01/over-rejection#1` [major/high] SCAN.SIBLING_LINK gains a second, hard-tier refusal the frozen catalogue row does not declare and no fixture falsifies

- src/Scans/sibling_link.jl:20-38 (the `seen`/`elseif linked` hunk)
- catalog/scans.toml:121-126 (unchanged: tier = "hard", fixture = ["bare-sibling"])
- docs/ARCHITECTURE.md:2314 (§12.B row, byte-identical at base and HEAD)

The base scan judged the first line naming a sibling and `break`ed. HEAD keeps going and turns every later linked mention into a hit. The rule text does say "later mentions are bare", so enforcing the second half is defensible in principle — but the widening is wider than the rule's target in one concrete way and undeclared in two: (a) the site match is a prefix, so a deep link INTO the sibling's docs, which the rule was never about, is refused as if it were a duplicated bare-name link; (b) ARCHITECTURE §12.B's SCAN.SIBLING_LINK row, which is the scan's frozen description, was not updated in this diff; (c) the fixture list still carries only `bare-sibling`, so nothing proves the new arm fires or that it does not over-fire. A hard-tier scan that gained an arm mid-diff without its catalogue row or its fixture is exactly the shape RULE.INST.FROZEN_MIDROUND and RULE.TEST.RULE_WITH_CHECK guard against.

### `2026-09-09-audit-changes-01/over-rejection#2` [major/high] A ledger reason of 24-39 characters turns from one doctor FAIL into an exit-3 crash of every ledger-reading verb

- schema/exemptions.schema.json:36-38 (reason minLength)
- src/CLI/Ledger.jl:30-40 (Ledger.read throws LedgerError on a schema failure)
- src/CLI/Doctor.jl:308 (CFG.EXEMPTIONS already enforced >= 40)
- src/CLI/Main.jl:143-149 (an uncaught throw is exit 3)

Making the schema agree with CFG.EXEMPTIONS is defensible as a statement of intent, but the two layers were deliberately different: the schema is the parse gate for every engine, the doctor is the reporting gate. Moving the bound up collapses a reportable exit-1 finding into an unreportable exit-3 crash across the whole CLI, and does so for input the whole tool previously accepted and worked with. If the tightening is wanted, `Ledger.read` should degrade to a named refusal (exit 2) rather than an uncaught throw, or the bound should stay in the doctor where it already lived.

### `2026-09-09-audit-changes-01/over-rejection#3` [major/high] The new Workflow-script backtick test rejects any short plain template literal, not just a bare code span inside a prompt

- test/coverage.jl:57-58 (the new assertion)
- test/coverage.jl:61-66 (its both-directions twin)

The change is wider than the defect it fixes. The failure it names — `hunt.js` gaining ``--glob '!.gbg/**'`` in prompt prose, which closes and reopens the template literal — is a bare span nested in an open template. The check written for it is context-free: it condemns any short bare backtick pair, including a top-level ``literal`` that is perfectly well-formed JS. The both-directions twin at test/coverage.jl:61-66 only demonstrates that the regex fires on the defect; nothing demonstrates that it does not fire on legitimate code, and empirically it does. A narrower predicate (a bare pair on a line already inside an unterminated template, or simply requiring every backtick inside a template-literal prompt to be escaped) would catch the same defect without foreclosing the construct.

### `2026-09-09-audit-changes-01/over-rejection#4` [minor/high] SCAN.ARGS_FORM double-counts a TYPED splat, so a two-argument prose docstring is now told to use bullets

- src/Scans/args_form.jl:36-40 (the splats append)
- src/Reflection.jl:112-113 (clean() strips `::T...` back to the identifier, which already passes IDENT)

Counting a splat as a parameter is the right correction (it fixed `f(cfg; kwargs...)` reading as prose-form). Applying the regex to the raw signature text rather than to the parameters `signature_parameters` dropped is the over-reach: an UNTYPED splat (`args...`) fails the anchored IDENT and is genuinely missing, but a TYPED splat (`rows::Traffic...`) is already present as its identifier and gets a second, spurious entry named after its TYPE. The hit message inherits the wrong count as well. Only the untyped case needs the append. In this package it is currently latent (`audit(operation!, name, rows::Traffic...; print = false)` counts 4 positional instead of 3 but is over the threshold either way); it becomes a real refusal in a consumer at exactly two real arguments. The scan is `triage`, so it does not gate a build, but it does bank into a check-docs round as a finding a fix pass must dispose of.

### `2026-09-09-audit-changes-01/over-rejection#5` [minor/medium] Moving the signature_fidelity population counter past the EXTENSION-HOMED branch turns a clean all-extension package into exit 2, and the paired `isempty(hits)` relaxation cannot rescue it

- src/Reflection.jl:418-421 (the moved `examined[] += 1`)
- src/Scans/signature_fidelity.jl:9 (EXTENSION-HOMED rows are filtered OUT of hits)
- src/Scan.jl:466-468 (the triage DEAD branch, code = 2)

The move itself is principled: an extension-homed binding is skipped, not compared, and RULE.TEST.MISSING_IS_FAILING says a scan that measured nothing must not print clean. But the same commit that made this stricter also wrote the compensating relaxation in `Scan.report` and did not check that the compensation reaches this scan. The result is that the one scan the move affects is the one the relaxation cannot help. Either the EXTENSION-HOMED rows should count toward the population as skips reported separately, or the scan should surface them as a note so the DEAD branch is not the outcome for a package that has nothing comparable.

### `2026-09-09-audit-changes-01/over-rejection#6` [minor/medium] The new RULES.toml test forbids a rule from declaring a mechanical check alongside `panel`, `session` or `weakness`

- test/schemas.jl:531-535 (`@test length(cs) == 1`)
- policy/testing-protocol.md:57-64 (the rule text the test claims to enforce)

The prose the test enforces (policy/testing-protocol.md, rewritten in this same diff) says `panel` and `session` are answers and `weakness` is a debt; it does not say a rule may carry only one kind of answer. The exclusivity is invented at the test, not stated at the rule, and the rule text is itself part of this change set — a contract written to match the check rather than a check written to match the contract. Since the field is new, nothing that previously validated now fails; the cost is entirely forward-looking, which is why this is minor rather than major.

### `2026-09-09-audit-changes-01/over-rejection#7` [minor/medium] The schema-coverage test now accepts only two spellings of "a schema is loaded", so a legitimate loader fails it

- test/schemas.jl:93-99

The tightening is warranted in direction — the base disjunct `occursin("\"" * name * "\"", src)` matched any coincidental occurrence of `"finding"` anywhere in the source, which is exactly the hole the comment names. But the replacement swings past the target: instead of asking "is this schema loaded", it asks "does the literal sit on a line mentioning one of two names I know about". The whitelist `load_schema`/`read_verdicts` is not derived from anything; it is the current call sites, frozen. A loader-shaped predicate (collect the arguments actually passed to `load_schema` and its wrappers) would answer the real question without banning other spellings.

### `2026-09-09-audit-changes-01/over-rejection#8` [minor/medium] bank's new core-finding validation throws instead of returning 2, and fires after the panel and the witness runner have already been paid for

- src/CLI/Rounds.jl:399-405 (the new loop)
- src/CLI/Main.jl:143-149 (an uncaught RoundError is exit 3, not the round verbs' exit 2)

I checked whether the loop can actually reject anything a lane file did not already have to pass, and it very nearly cannot: the four `instruments/*/schema.json` finding definitions carry the same core required list, the same enums and the same minLengths that `schema/finding.schema.json` carries, `classify_lane` already validated against them, and the four keys `bank` adds (`id`, `lane`, `n`, `seeded`) cannot fail because `schema/config.schema.json` already pins every lane and hat key to `^[a-z0-9][a-z0-9-]*$`. So the loop is close to a check that cannot fail — which is the shape RULE.TEST.BOTH_DIRECTIONS names — while the one path on which it can fail is the most expensive moment in the round and exits 3 rather than 2. Reporting the offending id and returning 2 would cost nothing and keep the exit contract.

## lane public-contract

### `2026-09-09-audit-changes-01/public-contract#1` [minor/high] gbg scan's DEAD/exit-code semantics changed for the population==0-with-hits case

- src/Scan.jl:453 (report, hard branch)
- src/Scan.jl:467 (report, triage branch)
- src/CLI/Rounds.jl:169 (prepare)
- src/Scans/field_docs.jl:50-51 (root cause)

Both of Scan.jl's report() loops (hard and triage) and Rounds.jl's prepare() mirror of the same guard now require `isempty(r.hits)` before classifying a scan DEAD; previously a scan whose population counter under-counted (as SCAN.FIELD_DOCS's did, fixed in the same diff) could have real hits silently swallowed under a DEAD/exit-2 verdict instead of being reported and exit 1. The fix is correct, internally consistent, and traceable to a real root-cause bug in field_docs.jl's population counter, but it is a genuine, unannounced change to `gbg scan`'s exit-code and report-content contract for that edge case.

## lane numerics

### `2026-09-09-audit-changes-01/numerics#1` [major/medium] exemptions.schema.json reason minLength raised 24→40 turns a graceful per-entry FAIL into a whole-ledger crash

- schema/exemptions.schema.json (reason.minLength)
- src/CLI/Ledger.jl:29-36 (Ledger.read)
- src/CLI/Doctor.jl:305 (CFG.EXEMPTIONS reason check, unchanged)
- src/Scan.jl:423 (scan_docs, `ledger = Ledger.read(cfg)` unguarded)

The fix narrows a genuine schema/code inconsistency (schema said 24, the doctor's own code required 40) but does so by moving the enforcement point earlier, from an itemized, gracefully-reported doctor FAIL naming just the bad entry, into an unguarded exception that (a) empties the whole ledger rather than rejecting only the one entry and (b) is only caught at one of several call sites (Doctor.jl), not at Scan.jl's `scan_docs`/`scan_html`, which read the ledger directly and uncaught. The defect being fixed (a stale schema description) did not require widening the failure's blast radius or its exit-code path.

### `2026-09-09-audit-changes-01/numerics#2` [minor/medium] signature_fidelity's `examined` counter now silently excludes extension-homed bindings, with no test locking in either value

- src/Reflection.jl:418-423 (signature_fidelity)
- src/Scans/signature_fidelity.jl (only caller, unchanged)

The reordering makes `examined` consistent with the long-standing docstring sentence 'an extension-homed binding with no methods loaded is reported as skipped' (present, unchanged in wording, at both base and head) — skipped bindings were nonetheless being counted as 'examined/compared' before this diff, which is the same class of bug the scan's own comment warns about, just in an extension-homed rather than zero-export package. The fix is narrowly scoped to the one branch it corrects.

## lane claim-versus-edit

### `2026-09-09-audit-changes-01/claim-versus-edit#1` [major/high] 175fe95 silently added a new hard-fail validation to bank() that no claim in its own message names, and it was broken on arrival

- src/CLI/Rounds.jl:393-398 (as introduced by commit 175fe95f90b3cd8dab7f48fea024f77be9dd0142)
- src/CLI/Rounds.jl (as corrected by commit 235d292f7be008f5c6b6a0763ec6728ee3b02bea)
- test/schemas.jl (regression test added by 235d292)

The commit that claims to be "the fix pass, by id" for 56 named documentation findings also introduced new, unrelated runtime enforcement in Rounds.bank, without naming it as a change, and that enforcement was defective from the moment it landed.

### `2026-09-09-audit-changes-01/claim-versus-edit#2` [minor/medium] Three JSON schemas were tightened inside 175fe95 (a doc-fix commit) with no claim naming them, one of them changing a live crash-vs-report boundary

- schema/exemptions.schema.json (properties.exemption.items.properties.reason.minLength)
- schema/managed.schema.json (properties.files.additionalProperties)
- schema/tally.schema.json (properties.per_id.additionalProperties)
- src/CLI/Ledger.jl:38-39 (Ledger.read, which enforces the exemptions schema on every read)

Three schema-file tightenings ride inside the huge documentation fix-pass commit with no line in its message naming schema/ at all; the exemptions one moves a validation boundary from a graceful doctor report to a thrown exception for input that used to parse.

## lane contract-drift

### `2026-09-09-audit-changes-01/contract-drift#1` [blocker/high] The latex-typesetter hat lost the only lawful copy of its own authoritative rulebook

- catalog/hats/latex-typesetter.toml:4 (the changed line)
- instruments/check-consistency/workflow/panel.js:61, :69, :87
- src/CLI/Preflight.jl:330-341 (rulebook_text)

The stated reason for the edit is factually wrong about this codebase. The comment says the persona "reads the rendered policy file, never a `rulebook_sections` grant", but the `rulebook` need is not a rulebook_sections grant — it is the grant that hands over rulebook.md, whose first section IS the rendered policy files, before any rulebook_sections are appended. The real motivation is visible in resolve_hats: `("rulebook" in needs && isempty(cfg["package"]["rulebook_sections"]))` marks the hat not_applicable in a package with no rulebook sections. The defect is in that not_applicable predicate (it conflates two sources), and the fix taken instead strips the hat's rubric in every package, including the four that do declare rulebook_sections. Note the contrast with catalog/hats/doc-policy.toml, untouched at `needs = ["rulebook", "source"]`, whose persona asks for `docs-rubric.md` by exactly the same mechanism.

### `2026-09-09-audit-changes-01/contract-drift#2` [major/high] A scan that measured nothing is no longer DEAD when it has hits, contradicting its own field docstring

- src/Scan.jl:453 and src/Scan.jl:467 (report)
- src/CLI/Rounds.jl:169 (prepare)
- src/Scan.jl:36-37 (the ScanResult docstring, unchanged in this respect)

The edit is wider than the defect it was written for. The defect was SCAN.FIELD_DOCS counting only structs that carried a field list, so a NOLIST hit could arrive with population 0 — and that defect is fixed independently in the same commit, by moving `checked += 1` above the `documented === nothing` branch in src/Scans/field_docs.jl. With that fix in place the report guard changes nothing for field_docs and everything for the other 41 scans: it removes the zero-population alarm from all of them. The ScanResult docstring in the same file was edited in this commit (the `note` bullet gained a lane gloss) but the `population` bullet was left promising the old behaviour, so the shipped contract and the shipped code now disagree inside one docstring. policy/testing-protocol.md RULE.TEST.MISSING_IS_FAILING, unchanged, still reads "a zero count is a dead lane rather than a clean one".

### `2026-09-09-audit-changes-01/contract-drift#3` [major/high] CFG.SURFACES quietly stopped promising that `docs_build` names docs/make.jl

- src/CLI/Config.jl:164-171 (check_paths docstring)
- docs/ARCHITECTURE.md:1746 (the §7.3 CFG.SURFACES row)
- docs/ARCHITECTURE.md:1123 (the config sample comment)

A guarantee lost the condition it depended on. The asymmetry is the tell: the twin claim on the same line, "`julia_test` contains `Pkg.test()`", is backed by real code and survives untouched; only the claim with no code behind it was reworded away. The replacement phrasing ("the fixed path docs/make.jl a consumer's docs_build command is expected to run") is careful to state an expectation where the base stated a check, which is the shape of a promise being retired rather than kept. Nothing in the change set records the decision, and ARCHITECTURE's own text about the mandatory makedocs wrapper still assumes the two are the same file.

### `2026-09-09-audit-changes-01/contract-drift#4` [major/high] SCAN.PROSE_SHAPE's "caps bind ALWAYS" weakened to match unchanged code, leaving the rule register saying "always"

- src/Scans/prose_shape.jl:3-6 (header comment)
- docs/ARCHITECTURE.md:2320 (§12.B row)
- policy/RULES.toml:231 and docs/ARCHITECTURE.md:2225 (RULE.DOC.SHAPE statement, unchanged)

The rewrite left the register contradicting the engine. policy/RULES.toml:231 still states RULE.DOC.SHAPE as "A docstring's longest paragraph is at most 120 words and it has at most 3 admonitions, always; …", and ARCHITECTURE §12.A line 2225 repeats "admonitions ≤ 3 always", while §12.B line 2320 and the scan header now say the caps hold only for docstrings and NEW page units. One of the two must be edited; this change edited the enforcement-side description and left the rule-side statement, so the rulebook a consumer pins and the scan that is declared its check (`check = ["scan:SCAN.PROSE_SHAPE"]`, added in this same commit) now promise different things. If the weakening is the intended policy, RULE.DOC.SHAPE's statement is the place it has to be recorded; if it is not, the scan is the thing to fix.

### `2026-09-09-audit-changes-01/contract-drift#5` [major/medium] RULE.DOC.HOME_ORDER reordered fleet-wide, with both judging personas rewritten to the new order in the same commit

- policy/docs-rubric.md:12-18 (RULE.DOC.HOME_ORDER)
- policy/RULES.toml (HOME_ORDER statement + sentinel), docs/ARCHITECTURE.md:2195
- catalog/hats/doc-policy.toml:8, catalog/hats/structure-consistency.toml:6

The change set contains no recorded rationale for the reorder, and it moves in the direction that makes an existing corpus compliant rather than the direction that makes it conform. The structure-consistency hat is the sharper case: its binding DIRECTION RULE, untouched, says it "is FORBIDDEN to name the majority side the norm or the minority side the defect" because "a widespread arrangement can be the wrong one, and a vote would certify it" — and this commit edits the very template it is seeded with ("e.g. one-sentence identity -> … -> caveats … -> one formula -> citation -> cross-links" becomes "… -> one formula -> citation -> cross-links -> caveats … last"), priming the hat toward one side of exactly the split it is forbidden to arbitrate. If the reorder is an owner decision it should be recorded as one; as it stands, the rule, its sentinel, its §12.A row and both judges moved together in a commit whose other work is a mass rewrite of this package's own docstrings.

### `2026-09-09-audit-changes-01/contract-drift#6` [major/high] SCAN.SIBLING_LINK gained a second hard-tier hit class that no catalogue row, architecture row or fixture records

- src/Scans/sibling_link.jl:18-38
- catalog/scans.toml:121-126
- docs/ARCHITECTURE.md:2314

The underlying widening is warranted — RULE.DOC.SIBLING_LINK has always said "later mentions are bare", and the base scan enforced only half its own rule — but the change stopped at the code. ARCHITECTURE §12.B line 2314 still describes the scan as "per page, rationale document, Literate file or docstring, the first mention of each sibling must sit inside `[`Name`](site)`", with no second clause, and catalog/scans.toml still lists `fixture = ["bare-sibling"]` alone. RULE.TEST.BOTH_DIRECTIONS asks that a check be falsifiable by a fixture carrying a known positive; the new arm has none, so nothing in the suite would notice if `elseif linked` stopped firing. A rate-comparability note is owed too: this scan's hit counts before and after are not comparable.

### `2026-09-09-audit-changes-01/contract-drift#7` [minor/medium] A ledger reason of 24-39 characters now makes the whole toolchain throw instead of the doctor reporting it

- schema/exemptions.schema.json (the `reason` node)
- src/CLI/Ledger.jl:31-41 (Ledger.read)
- src/Scan.jl:423, src/Scan.jl:520; src/CLI/Doctor.jl:308

The schema's base description recorded the division of labour deliberately — the schema held the loose floor so the doctor could report the strict bound with the offending entry named — and the edit deleted that division rather than the inconsistency it was there to manage. The tightening is defensible as an alignment with ARCHITECTURE §7.3 ("reason ≥ 40"), but it is wider than an alignment: it converts a reported, per-entry FAIL into a whole-file hard refusal across four commands, with no CHANGELOG entry and no migration note for consumer ledgers written under the 24-character floor.

### `2026-09-09-audit-changes-01/contract-drift#8` [minor/medium] resolve_function's search-order promise was rewritten to match a resolution order that shadows package functions

- src/TestHarness.jl:290-299 (docstring)
- src/TestHarness.jl:303-309 (body, unchanged)

This is documentation bent to fit the code. The mismatch itself predates the diff and belongs to /bug-hunt, but the choice made inside this window does not: given a promise and a body that disagree, the edit rewrote the promise. Nothing records why externals-before-package-modules is the wanted order, and the rewritten sentence states the mechanism without stating what it costs, so the next reader has no way to tell that the ordering is a decision rather than an accident. If the order is deliberate the docstring should say why a Base generic outranks a package module; if it is not, the one-token fix is in the body.

## lane sweep-completeness

### `2026-09-09-audit-changes-01/sweep-completeness#1` [major/high] New .gbg/-containment grep-scoping guard swept into 2 of ~9 workflow scripts that need it

- instruments/bug-hunt/workflow/hunt.js:74 (fixed)
- instruments/check-consistency/workflow/panel.js:88 (fixed)
- instruments/bug-hunt/workflow/dismissals.js:38 (left behind, edited in this same diff)
- instruments/audit-changes/workflow/audit.js:71 (left behind, edited in this same diff)
- instruments/audit-changes/workflow/attack-design.js:47 (left behind)
- instruments/bug-hunt/workflow/verify-architecture.js:39 (left behind)

This diff adds a concrete, actionable `--glob '!.gbg/**'` grep-scoping instruction to two workflow scripts (RULE.DOC.CLASS_SWEEP: "a flagged instance is a sample of a class; fix the class, not the line") but the class — every workflow script that grants broad tree-read access adjacent to `.gbg/` round data — has at least four other members, two of which (dismissals.js, audit.js) were touched in this identical diff for unrelated reasons and left with the older, weaker wording.

### `2026-09-09-audit-changes-01/sweep-completeness#2` [minor/high] New module-level glossary duplicates its own 'hat' definition verbatim, unlinked, in the one sibling site the same diff didn't sweep

- src/GBGCodingTools.jl:20 (new canonical definition)
- src/CLI/Preflight.jl:200 (new, unlinked duplicate, same diff)
- src/Witnesses.jl:13, src/CLI/RoundFiles.jl:7, src/CLI/Rounds.jl:9,128, src/CLI/Schema.jl:41-42, src/DocLints.jl:11-12, src/CLI/Gate.jl:15-16 (sibling terms correctly linked back)

The diff establishes one canonical home for "hat" (and five sibling terms) in the module docstring and sweeps every other explanation site to @ref back to it — except the one other site (Preflight.jl:200) that states the identical sentence, which it added fresh in this same diff without the backlink the sibling terms all received.

### `2026-09-09-audit-changes-01/sweep-completeness#3` [minor/high] IMPLEMENTATION.md still claims 'eighteen schemas' and names two files this diff's own D11 rewrite says don't exist

- IMPLEMENTATION.md:143
- IMPLEMENTATION.md:430-431
- docs/ARCHITECTURE.md:625 (fixed in this diff)

The diff corrects the stale 'eighteen schemas / lane-file / hunt-candidate' claim in docs/ARCHITECTURE.md but leaves the identical claim, word for word in substance, standing in IMPLEMENTATION.md — a live document, not a frozen design-record entry.

## lane reader-consequence

### `2026-09-09-audit-changes-01/reader-consequence#1` [minor/high] New SCAN.ARGS_FORM enforces a narrower exemption set than the standing RULE.DOC.ARGS_FORM promise

- policy/docs-rubric.md:43-49 (RULE.DOC.ARGS_FORM, unedited by this diff)
- src/Scans/args_form.jl:9-18 (new file, this diff)
- docs/ARCHITECTURE.md §12.B SCAN.ARGS_FORM row (new, this diff)
- policy/RULES.toml RULE.DOC.ARGS_FORM check field (new, this diff)

The diff builds the first mechanical enforcer for a rule whose text (left untouched, so it is the honest baseline of what the package promises) names three exemptions; the enforcer implements only two of them. This is exactly the shape of a check shipped without checking it against its own rule's stated exceptions — the kind of gap RULE.TEST.RULE_WITH_CHECK's self-application sweep (also new in this diff) was meant to surface, but the sweep only verifies that a `check` field exists, not that the check matches the rule's text.

