# Findings — 2026-09-12-audit-changes-01

The work list, by id. Fix the CLASS, not the line; a seeded finding (marked) is never fixed in the corpus.

## lane free-reader

### `2026-09-12-audit-changes-01/free-reader#1` [minor/high] main()'s own docstring is now false for a ConfigError, and no test covers the new branch

- src/CLI/Main.jl:116-125 (module docstring for `main`, untouched by this diff)
- src/CLI/Main.jl:144-155 (the new catch hunk)

The diff correctly centralizes ConfigError handling so a hand-edited bad config.toml reads as exit 2 ("cannot evaluate") instead of exit 3 ("crash") on every verb, not just the three that already special-cased it — a real and narrowly-scoped fix, and it does not collide with the three verbs that already catch-and-return-2 themselves (they never rethrow, so the outer branch never double-handles them). But the change is left half-finished: `main`'s own docstring still states unconditionally that "an exception escaping a verb is printed with its backtrace ... and returns 3", which the new branch now falsifies for the whole ConfigError class, and nothing in test/ pins the new exit-2-no-backtrace path. For a package whose entire discipline is that a docstring is the contract and every behaviour change gets a test, shipping the behaviour change without touching either is exactly the kind of gap this instrument exists to catch.

## lane under-rejection

### `2026-09-12-audit-changes-01/under-rejection#1` [major/high] The ConfigError→exit 2 arm sits at main()'s outermost catch, so a config the TOOL just wrote is reported as the user's bad config, without a backtrace

- src/CLI/Main.jl:147-151 (the new arm in main()'s catch)
- src/CLI/Bump.jl:36 — `cfg2 = Config.read(root)` AFTER `write(p, new)` rewrote .gbg/config.toml
- src/CLI/Init.jl:565 — `cfg = Config.read(root; check = false)` after `init(root; io)` wrote the config
- test/coverage.jl:8-30 — the `the exit contract of main()` testset, in this change set, gains no case for the new branch

The underlying fix is right: a structurally bad consumer config is exit 2 by D8, and most verbs reported it as a crash. But the edit is wider than that defect. Placed in main()'s catch-all it cannot distinguish a ConfigError thrown before the verb did anything from one thrown after the verb rewrote the consumer's config, and it deletes the backtrace for both. The two post-write re-reads (Bump.jl:36, Init.jl:565) are exactly the case where exit 3 carried information nothing else carries. No test was added: the testset that owns main()'s exit contract is itself in this change set and enumerates the other exit codes case by case, so the new branch is the one arm of that contract with no oracle.

### `2026-09-12-audit-changes-01/under-rejection#2` [minor/high] Two guards the design promised are withdrawn from the contract rather than built, with the code left exactly as it was

- docs/ARCHITECTURE.md:616 (D10) — the ORPHAN class
- docs/ARCHITECTURE.md:1447-1448 (§6.1 file formats) — the classification list
- IMPLEMENTATION.md:403 (step 1.6, outside the audit's covered paths) — the same list
- docs/ARCHITECTURE.md:1979-1986 (§8 step-0 `gbg round import`) — the `self verify` promise
- src/CLI/Rounds.jl:470-490 (bank iterates the roster) and 736-757 (`import_empty`) — unchanged

One class, two instances: a guard the base contract promised is deleted from the contract, the code is untouched, and the head prose presents the unguarded state as the design. Bringing stale prose current is right in general; here the stale prose was the only record that a guard was owed, so the edit converts an unpaid debt into a settled fact. The ORPHAN withdrawal also spans IMPLEMENTATION.md, which lies outside this audit's covered paths, so one member of the class would not have been visible to a lane reading only the covered diff.

### `2026-09-12-audit-changes-01/under-rejection#3` [minor/medium] The prose-shape ratchet is re-recorded in the same commit as the growth it would have caught, and one paragraph crosses the rule's own 120-word cap under cover of it

- docs/prose_shape.csv:3-4 (D10 589→604, D11 124→170 / longest 80→126)
- docs/prose_shape.csv — §7.3 1979→2044, §8 1521→1615, §12.A, §12.B, §1, §6.1, §6.8, item 2, config.md, install.md, ledger.md, rounds.md, Passes::Passes 223→303, Passes::close, Preflight::torn_check 43→107, Rounds::Rounds (18 rows raised, 1 added)
- docs/ARCHITECTURE.md:643-646 — the §D11 paragraph the raised row covers
- src/Scans/prose_shape.jl:95-120 (the ratchet and the cap gate)

The policy does sanction a deliberate re-record (docs-rubric.md: "the shape baseline is re-recorded deliberately, never by accident"), and every raised row does map to a file this diff edits — I checked, and no row was lowered or removed, so this is not a blanket reset hiding unrelated drift. What remains is that the guard and the growth land in one commit with nothing recording the deliberation, and that one unit now sits above the absolute cap the rule states, reachable only because the ratchet was the sole check on it and the ratchet was moved. The cheap discipline the rule implies — rewrite the D11 paragraph instead of appending to it — would have kept the row where it was.

## lane behaviour-change

### `2026-09-12-audit-changes-01/behaviour-change#1` [minor/high] Main's blanket ConfigError catch also reclassifies mid-verb failures, after side effects, as exit 2

- src/CLI/Main.jl:147-151 — the new catch arm (the only control-flow hunk in the change set)
- src/CLI/Bump.jl:35-36 — `write(p, new)` then `cfg2 = Config.read(root)`, a ConfigError raised after the pin is already rewritten
- src/CLI/Init.jl:565 — `Config.read(root; check = false)` after init writes the config
- src/CLI/Rounds.jl:855 — cmd_round's `Config.read()` sits outside its own try, so round verbs are the intended beneficiaries

The defect the comment names is that ConfigError from the initial config read escaped as exit 3 in every verb but three. A defect-sized fix catches it where the config is read (or wraps the read), leaving genuine mid-verb ConfigErrors as crashes with their backtrace. The edit instead catches the class for the whole verb table, so it changes the exit code and suppresses the backtrace for failures that are NOT "the user handed me a bad config" — specifically the ones where the tool wrote the config itself moments earlier. Both the behaviour (3 → 2) and the diagnostics (backtrace → one line) change for input that was valid before. The fix's own comment claims only the read case ("reported a hand-edited config.toml as exit 3"), so the widening is undeclared.

### `2026-09-12-audit-changes-01/behaviour-change#2` [minor/medium] The prose-shape ratchet's ceilings were raised in the same commit as the prose they measure

- docs/prose_shape.csv:3-4 — D10 589→604, D11 124→170
- docs/prose_shape.csv:39 — item 2 212→228
- docs/prose_shape.csv:48 — §1 842→859
- docs/prose_shape.csv:53-54 — §12.A 3209→3220, §12.B 1686→1706
- docs/prose_shape.csv:64 — §6.1 315→331
- docs/prose_shape.csv:71 — §6.8 340→348
- docs/prose_shape.csv:75-76 — §7.3 1979→2044, §8 1521→1615
- docs/prose_shape.csv:222,231 — Passes 223→303, close 273→302
- docs/prose_shape.csv:240,249 — torn_check 43→107, Rounds 67→77
- docs/prose_shape.csv:258,268-269,275 — config.md, install.md, ledger.md, rounds.md
- src/Scans/prose_shape.jl — the ratchet that reads it (`u.words > w || u.longest > l` ⇒ Hit)

A frozen baseline re-baselined in the commit whose prose it measures is the self-certifying shape, and it is worth the owner seeing even though this instance checks out. The re-baseline is sanctioned by the rule and by the scan's own hit message, the unconditional caps still bind, and every raised row here corresponds to an edit in this change set. What the mechanism does not give is any guarantee of that last property: the writer is wholesale, so the reviewer's only defence is reading the CSV diff row by row against the prose diff, as I did. A `--rebaseline` that printed the rows it was about to raise, or refused rows whose unit is untouched by the working diff, would make the guarantee mechanical instead of manual.

## lane over-rejection

### `2026-09-12-audit-changes-01/over-rejection#1` [minor/high] The Step-0 import design was narrowed to the CLI's restriction instead of the CLI being fixed

- docs/ARCHITECTURE.md:1982-1985 (hunk @@ -1972,8 +1979,10 @@)
- docs/ARCHITECTURE.md:1975 at base af1adec
- src/CLI/Rounds.jl:856 (cmd_round)
- src/CLI/Rounds.jl:736-755 (import_empty)
- instruments/audit-changes/PROTOCOL.md is unaffected; the promise lived only in §8

A design promise that `round import` needs no config and runs before `init` was rewritten, in the same window that documents the verb as NOT YET BUILT, into a statement that the CLI does not allow it. The restriction is real (Rounds.jl:856 reads the config for every round verb) and cheap to lift for the one implemented `--empty` path; the change set recorded it as design instead. The companion clause `self verify still precedes it` was dropped for the same reason — the implemented path omits the call. Nothing that worked stopped working; what changed is that the owed behaviour is no longer owed in writing.

### `2026-09-12-audit-changes-01/over-rejection#2` [minor/high] RULE.INST.CARRY's new CARRY_LIMIT clause names the release refusal and hides the close refusal

- policy/RULES.toml:575 (hunk @@ -572,7 +572,7 @@, RULE.INST.CARRY statement)
- src/CLI/Passes.jl:1085-1087 (carry_conditions)
- src/CLI/Release.jl:46-47 (carry_release_fails)

The edit set out to make the rule statement current about CARRY_LIMIT and made it current in one direction only. Release.jl:46 does refuse at `carries >= CARRY_LIMIT`, so the added clause is not wrong; but the refusal that bites first — close's own, at Passes.jl:1086, unconditional on the pass budget — is still unstated, and the sentence now reads as though closing over a 3×-carried finding is available. The rule's own `check` is `test:test/rounds.jl`, whose CARRY_LIMIT case (test/rounds.jl:577-578) exercises the close refusal, so the behaviour the statement omits is the one the check actually pins.

### `2026-09-12-audit-changes-01/over-rejection#3` [nit/high] The prose-span guard dropped the `of` exemption that no defect implicated

- test/coverage.jl:124 (hunk @@ -113,7 +113,15 @@)
- test/coverage.jl:117-123 (the rationale comment added with it)
- test/coverage.jl:194-197 (the two new positive assertions)
- instruments/check-consistency/workflow/verify-act.js:126 (the defect fixed)
- instruments/check-consistency/workflow/verify-state.js:113 (the defect fixed)

One of the two exemptions removed was implicated in the BLOCKER (`in`), the other was not (`of`), and the commit removes both. The test's own comment concedes the second: "Neither operator is ever followed by a template literal in these scripts" and "no such form occurs in the eleven scripts or the prelude (checked 2026-09-12)" — i.e. the `of` exemption protected nothing and, symmetrically, its removal catches nothing that exists. This is a guard made wider than the defect required, on a frozen-script surface where every future edit must pass it. Note a side effect neither the comment nor the new assertions mention: because the lookbehinds match the last three characters and not a word, `(?<!in )` and `(?<!of )` had also been exempting every word ENDING in "in " or "of " ("within", "again", "proof"), so the tightening is broader than the two keywords named.

## lane public-contract

### `2026-09-12-audit-changes-01/public-contract#1` [minor/high] main()'s exit-code behavior changed but its own docstring still claims exit 3 unconditionally

- src/CLI/Main.jl:147-154 (the new `err isa Config.ConfigError && (...); return 2` branch)
- src/CLI/Main.jl:115-124 (the unmodified `main(args) -> Int` docstring, both at base and head)

The change itself is a justified, narrowly-scoped bug fix — it makes every verb's exit code match the pre-existing documented contract instead of only the three verbs that special-cased `ConfigError` themselves — but the diff does not update `main()`'s own docstring, which still states unconditionally that an escaping exception returns 3 with a backtrace. That statement is now false for `Config.ConfigError`. No test in this diff exercises the new branch either (test/coverage.jl is the only test file touched, and it is unrelated). A reader who consults the one docstring that documents this exit-code contract would not learn that this class of failure now returns 2 without a backtrace.

## lane claim-versus-edit

### `2026-09-12-audit-changes-01/claim-versus-edit#1` [minor/high] c7db4e5's own itemized claim omits two of its own files

- c7db4e5 — templates/README.md (SKILL.md.tmpl exception)
- c7db4e5 — docs/src/guide/install.md (the consumer gloss)

The fix-pass commit c7db4e5 presents itself as a complete, categorised inventory of what it fixed (RATIONALE/SRC/SCRIPTS/REGISTERS, 8+7+6+4=25 items covering 28 of 37 findings), but its actual diff touches two files — templates/README.md and docs/src/guide/install.md — that appear in none of the four paragraphs. Both edits are individually sound (verified against the current templates/SKILL.md.tmpl file and the install.md @ref target), so this is not a behaviour or contract defect; it is a gap between what the commit claims to account for and what it actually changed, the specific shape this lane is built to surface.

## lane contract-drift

### `2026-09-12-audit-changes-01/contract-drift#1` [minor/high] Removing ORPHAN from D10 left a dangling article: the paragraph now reads "or live. An A lane file no roster entry expects..."

- docs/ARCHITECTURE.md:615-616 (D10, the bank classification paragraph)
- diff.patch hunk docs/ARCHITECTURE.md @@ -613,7 +613,7 @@

The correction itself is right: `bank` iterates the roster (src/CLI/Rounds.jl `lanes = expected_lanes(rec)`, then `classify_lane` per roster entry, with no `readdir` of `findings/`), so nothing ever reported an ORPHAN and the base sentence promised a classification the tool does not perform. What is wrong is the mechanics of the removal — the deleted text began mid-sentence after "or live. An" on the preceding context line, and the replacement opens a new sentence without removing that article.

### `2026-09-12-audit-changes-01/contract-drift#2` [minor/high] The new PINNED/MANAGED taxonomy files the sync sidecar `.gbg/managed.json` under "the tool never renders", which `gbg sync` rewrites on every run

- docs/ARCHITECTURE.md:1867 (§7.3 CFG.TORN row)
- docs/ARCHITECTURE.md:1481-1482 (preflight step 2)
- src/CLI/Doctor.jl:228-236 (new `pinned_and_managed` docstring)
- src/CLI/Preflight.jl:804-807 (`torn_check` docstring)
- src/CLI/Doctor.jl:253, src/CLI/Preflight.jl:848, src/CLI/Rounds.jl:69 (the rendered pass/refusal strings)

The base text used one word, "pinned or managed", for a set that genuinely holds two kinds, and splitting it was warranted. But the split as written misclassifies its own pivot: the sidecar the MANAGED kind is read from is listed under the PINNED kind whose defining property is that the tool never renders it. `Doctor.pinned_and_managed` builds exactly this list — the four `.gbg/` files, the hats, the sub-env manifests, then `Sync.read_sidecar` keys — so the code draws no such line and the distinction exists only in the prose that now claims to explain it. Either `managed.json` belongs to the MANAGED kind, or the PINNED kind needs a definition that admits a file the tool writes but never re-renders from a template.

### `2026-09-12-audit-changes-01/contract-drift#3` [minor/medium] RULE.CIT.NO_INACCESSIBLE's check now names a src-only scan whose canonical rule is a different one, so a policy waiver of either rule misses

- policy/RULES.toml:448-452 (RULE.CIT.NO_INACCESSIBLE `check`)
- diff.patch hunk policy/RULES.toml @@ -448,7 +448,7 @@
- catalog/scans.toml:302-307 (SCAN.DEAD_REF row)
- src/Scans/dead_ref.jl:4-7

The addition is defensible bookkeeping — ARCHITECTURE §12.B has always listed RULE.CIT.NO_INACCESSIBLE as SCAN.DEAD_REF's second rule, and the scan's own header names both — and `panel` is retained, so the debt is not erased. What drifts is the strength of the promise: a rule whose check was a declared reading-panel debt now reads as program-checked, on one surface of many and through a scan the ledger indexes under a different rule. The same shape applies to the sibling edit at RULE.DOC.API_GROUPING (SCAN.API_PAGE_STRUCTURE's canonical rule is RULE.DOC.INTERNAL_API), though there the surfaces do match the rule's scope.

### `2026-09-12-audit-changes-01/contract-drift#4` [nit/high] verify-act.js's rewritten args header drops `round_dir`, which the CLI always sends, and adds `batch?`, which no CLI path ever sends

- instruments/check-consistency/workflow/verify-act.js:8-10 (the Args comment)
- diff.patch hunk instruments/check-consistency/workflow/verify-act.js @@ -5,9 +5,9 @@
- src/CLI/Passes.jl:543-546 (the `base` args dict), :581 (`act = merge(base, …)`), :609 (the only `delete!(a, "round_dir")`)

Two of the three header changes are real corrections — `quote_probe` and `class_candidates` are sent (Passes.jl:544) and `rulebook_summary` is sent nowhere, so removing it was right. The third pair goes the other way: the one key present in every act-verifier args file was dropped from the list, and an optional key the CLI never writes was added to it. This is the smallest kind of contract drift, but it is drift introduced by an edit whose stated point was to make the header match the args.

### `2026-09-12-audit-changes-01/contract-drift#5` [nit/medium] The signature-types measurement was replaced by "a handful" while the ID_RESOLVES counts beside it were kept as a dated snapshot

- docs/ARCHITECTURE.md:102 (§1 variation-point table, `rubric.signature_types`)
- docs/ARCHITECTURE.md:2371 (§12.A, RULE.DOC.SIGNATURE_MIRROR)
- docs/ARCHITECTURE.md:2484 (§12.B SCAN.ID_RESOLVES row, edited in the same diff)

This is the lens's classic direction — an exact quantifier weakened to a vague one — with a real justification attached, so I report it at nit rather than pressing it as a defect. The concern is the inconsistency within one edit: if a measured figure goes stale the moment it is written, the ID_RESOLVES figures are as stale as the signature figures were; if a dated snapshot is acceptable, the signature figures could have been dated too. One of the two treatments should be the house convention.

## lane sweep-completeness

### `2026-09-12-audit-changes-01/sweep-completeness#1` [minor/high] The new 'consumer' glossary link was swept to three guide pages but not to the two others that use the same unglossed term

- docs/src/guide/config.md:6 (hunk, fixed)
- docs/src/guide/ledger.md:6 (hunk, fixed)
- docs/src/guide/rounds.md:6 (hunk, fixed)
- docs/src/guide/install.md:8 (hunk, defines the term)
- docs/src/guide/instruments.md:43 (left behind)
- docs/src/guide/rules.md:7 (left behind)

This is exactly the incomplete-sweep shape the lens is built to catch: one instance of a term-definition edit applied to a sample of the sites that state the same fact (four guide pages) while two siblings using the identical phrase and needing the identical fix (rules.md, instruments.md) were left as they were. Grepping the whole corpus for '@ref install' confirms only three of the five guide pages carrying the word 'consumer' actually link it.

### `2026-09-12-audit-changes-01/sweep-completeness#2` [minor/high] ARCHITECTURE.md now says round import needs a config the CLI does not yet allow skipping, but IMPLEMENTATION.md's Phase 2 plan still asserts the old, false claim

- docs/ARCHITECTURE.md:1979-1988 (hunk, corrected)
- IMPLEMENTATION.md:290 (left stating the retired claim)
- IMPLEMENTATION.md:644-653 (Phase 2 procedure that depends on the retired claim)
- src/CLI/Rounds.jl:856-880 (cmd_round: Config.read() runs before every verb dispatch, import --empty included)

The diff corrects one restatement of this fact (ARCHITECTURE.md's Step-0 section, explicitly flagging the gap between the design and the built CLI) but leaves a second, load-bearing restatement of the exact same fact uncorrected in the build plan that a future session will follow verbatim. This is not a design absence the package accepts — the new ARCHITECTURE.md text itself calls it out as a gap ('which the CLI does not yet allow') — so the sibling site is a real leftover, not a deliberate omission.

