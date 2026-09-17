# Findings — 2026-09-12-audit-changes-02

The work list, by id. Fix the CLASS, not the line; a seeded finding (marked) is never fixed in the corpus.

## lane free-reader

### `2026-09-12-audit-changes-02/free-reader#1` [major/medium] close()'s new docs-build staleness check trusts an unreachable recorded head as 'not stale' instead of refusing

- src/CLI/Passes.jl:1158-1169 (the new build-record gate in close())
- src/CLI/Passes.jl:907-916 (audit_coverage, the sibling pattern this claims to reuse)
- src/CLI/Git.jl:147 (changed_paths, the shared primitive)

The new build-staleness gate in Passes.close() reuses the raw `Git.changed_paths` diffing primitive but not the reachability guard (`cat-file -e`) that makes the same primitive safe in `audit_coverage`, so an unreachable or invalid `b["head"]` is silently read as 'the build is still fresh' instead of refusing.

### `2026-09-12-audit-changes-02/free-reader#2` [minor/high] The new required arg source_globs was added to the schema and to the message it feeds, but not to panel.js's own contract comment or its own required-key guard

- instruments/check-consistency/workflow/panel.js:10-13 (the 'Args (...)' contract comment)
- instruments/check-consistency/workflow/panel.js:20 (the gbg:prelude required-key loop)
- instruments/check-consistency/workflow/panel.js:86 (the new A.source_globs use)
- instruments/check-consistency/schema.json (source_globs added to required and properties)

panel.js's own enumerated args contract (a header comment) and its own defensive required-args check were not updated for the new `source_globs` field the diff makes both the schema and the code depend on, so the 'loud, never silent' guarantee claimed for this field is only enforced upstream, not in the script that actually consumes it.

### `2026-09-12-audit-changes-02/free-reader#3` [minor/high] A seed catalogue with any class that cannot anchor now hard-refuses prepare, where it previously proceeded on the classes that did plant

- src/CLI/Rounds.jl:161-167 (prepare, check-consistency branch)
- src/CLI/Rounds.jl:248-254 (seed_docs_corpus!, check-docs)

prepare (check-consistency) and seed_docs_corpus! (check-docs) turned a previously-tolerated partial seed-class match into a hard refusal, so a seed catalogue that used to prepare successfully with a warning now blocks round preparation outright.

## lane executing

### `2026-09-12-audit-changes-02/executing#1` [major/high] close gained a build precondition no documented procedure satisfies; the tests were amended to supply it instead

- src/CLI/Passes.jl:1159-1176 — the new `if inst in Sync.DOCS_INSTRUMENTS` block in close
- src/CLI/Rounds.jl:323 — the only writer of rec["build"]
- src/CLI/Rounds.jl:152 and :198 — prepare's own builds, which record nothing
- test/rounds.jl:546, :659, :723 — "build" spliced into three existing round records
- test/rounds.jl:1018-1022 — the lifecycle testset writes the record by hand
- instruments/check-docs/PROTOCOL.md:51-62 — step 7 (close), unchanged by this diff
- docs/src/guide/rounds.md:24 and :39 — the lifecycle, unchanged

The underlying defect is real — a red docs build rode through two graded passes of 2026-09-12-check-docs-01 — but the fix puts the new obligation on a verb the protocol treats as optional ("Builds and tests during the pass go through `gbg round build|test <round>`") and leaves the mandatory path silent. Either prepare and pass open should record the build they already run, or the frozen protocol and rounds guide owe the new step. As it stands the only artefacts that know about the requirement are close itself and the tests this commit edited.

### `2026-09-12-audit-changes-02/executing#2` [major/high] latex_source_globs repurposed as the hat's whole source surface: a consumer that set it loses three of the four surfaces it used to read

- src/CLI/Preflight.jl:730-731 — `globs = String.(get(…, "latex_source_globs", String[]))`; `a["source_globs"] = isempty(globs) ? ["src", "ext", "docs/src", "docs"] : globs`
- instruments/check-consistency/workflow/panel.js:86
- instruments/check-consistency/schema.json:169-176
- test/coverage.jl:106-126 — the new testset
- schema/config.schema.json:441-443 — the key's whole declared contract

The defect was a path list hardcoded in a Workflow script, which the core invariant forbids. Lifting it into the CLI is the fix. Adopting a differently-named key — whose entire declared contract in schema/config.schema.json is `"$ref": "#/$defs/strlist", "default": []`, and whose name says LaTeX sources — as the definition of the hat's complete authored-source surface is wider than the defect, and it changes behaviour for every consumer that already set the key for the purpose its name states. The tool's own config is `[]`, which takes the default branch, so its own rounds see nothing of this.

### `2026-09-12-audit-changes-02/executing#3` [major/high] a policy waiver now silences two scans it was inert on, and the docstring books that hazard as inherited

- src/Scan.jl:405-407 — `enforced = unique!(vcat(String(row["rule"]), rules_for_scan(id)))`, `for rule in enforced, e in Ledger.entries(ledger, rule; scope = "policy")`
- src/Scan.jl:383-395 — the docstring's "known limit" paragraph
- test/scans.jl:166-180 — the new testset, DOI only

The reported defect was one rule: RULE.CIT.DOI, whose only declared check is SCAN.DOI_CROSSCHECK, so its documented waiver was void. Fixing that case is right. Applying the same resolution to all 44 scans hands two further rules a power they did not have, and those are exactly the mirror case the docstring calls "NOT fixed and a known limit" — written as though the hazard pre-existed, when for RULE.CIT.NO_INACCESSIBLE and RULE.DOC.API_GROUPING this change creates it. The new test pins the DOI case and the negative case (an unrelated rule waives nothing); neither of the two newly-empowered siblings is asserted on.

### `2026-09-12-audit-changes-02/executing#4` [major/high] close's new staleness test reads an unreachable build head as fresh — the sibling it cites guards that exact case

- src/CLI/Passes.jl:1163-1170 — `moved = Git.changed_paths(root, "$(b["head"])..HEAD", Preflight.covered_paths(cfg))`
- src/CLI/Passes.jl:1157-1158 — the comment claiming parity with audit_after_code
- src/CLI/Passes.jl:1240-1241 — the sibling, with the guard
- src/CLI/Rounds.jl:323 — `something(Git.head(cfg["root"]), "0"^40)`

The guard is new and warranted; the defect is that it is narrower than its own comment claims. Git.changed_paths swallows a failed git invocation (`something(run(…), "")`), so an unresolvable range is indistinguishable from a clean one. The sibling four hundred lines down already models the right shape — check reachability, and refuse with a named UNCHECKABLE fail — and the comment asserts parity with it that the code does not have.

### `2026-09-12-audit-changes-02/executing#5` [minor/high] the quantifier class enlarges every lane's mandatory checklist by 46%, a burden the affordability comment never measures

- src/CLI/Preflight.jl:342-347 — CLAIM_QUANTIFIER, CLAIM_TOOL_ID and the affordability comment
- src/CLI/Preflight.jl:401-406 — the tagging in claim_checklist
- catalog/lanes/check-docs.toml:12 — the brief that makes each item compulsory
- instruments/check-docs/PROTOCOL.md:19-21

The class itself is well motivated — two of five planted seeds were quantifier mutations and both were missed — and the narrowing does work: 267 of 2268 quantifier-bearing lines survive the tool-identifier conjunction, so the comment's "it is a fraction of that" is true as a ratio. But the ratio is not the cost. The number that governs whether the class is affordable is the per-lane discharge count, and it is nowhere measured in the change set; I report it here because nothing else in the round will.

### `2026-09-12-audit-changes-02/executing#6` [minor/high] prepare turns a printed warning into a hard refusal and leaves its own now-dead skipped-classes branch standing

- src/CLI/Rounds.jl:161-168 — the new refusal in the check-consistency path
- src/CLI/Rounds.jl:170 — the surviving unreachable ternary
- src/CLI/Rounds.jl:248-257 — the same refusal in seed_docs_corpus!

The reasoning is sound: a skipped class is UNDEFINED in recall and narrows the denominator silently, and 2026-09-12-check-docs-01 measured 5 of 6 that way. But the defect is the silence, and the change set had a cheaper answer available — record the skipped classes in ROUND.toml the way this same diff records builds and script refreshes — instead of refusing a round that can still measure five of six classes honestly. The ternary left dangling one line below the new refusal is the evidence the edit stopped at the first branch that made the symptom go away.

### `2026-09-12-audit-changes-02/executing#7` [minor/high] three of the new comments' cited measurements do not reproduce, and one counts two homes this diff created

- src/CLI/Preflight.jl:341 — "`exit contract` alone occurs on 12 lines corpus-wide"
- src/CLI/Preflight.jl:342 — "A quantifier alone matches 2526 lines of this corpus"
- src/CLI/Sync.jl:26-30 — "The pair was written out at SIX sites (DocLints twice, Doctor, Preflight, Release, Passes)"
- src/CLI/Sync.jl:31 — const DOCS_INSTRUMENTS

None of this moves behaviour; the constant is right and the regex is right. It matters because this lane exists precisely because a measurement written in a comment gets certified by readers. Two of the four measurements in these comments do reproduce exactly — the ZERO checklist items from src/GBGCodingTools.jl, and the three multi-rule scans — which is what makes the other three worth naming rather than dismissing as rounding.

## lane under-rejection

### `2026-09-12-audit-changes-02/under-rejection#1` [major/high] A policy waiver on ANY rule a scan enforces now disables the whole scan, withdrawing enforcement of rules the consumer never exempted

- src/Scan.jl:395-399 — apply_ledger, the widened policy loop
- src/Scan.jl:390-393 — the docstring paragraph recording the limit
- src/Scan.jl:82-112 — rules_register / rules_for_scan, the new resolver
- test/scans.jl:172-181 — the testset added with it

The underlying defect — a documented `RULE.CIT.DOI` waiver being silently void because apply_ledger resolved only the catalogue's canonical `rule` column — was real and worth fixing. The edit is wider than that defect: it makes EVERY rule in the scan's `check` closure a kill switch for the whole scan, in both directions, for all three multi-rule scans. The diff's own docstring concedes the consequence ("a waiver on either rule still disables the WHOLE scan, so it withdraws enforcement of a sibling rule the consumer never exempted") and calls it a known limit, but the limit is not pre-existing: before this diff a waiver on the non-canonical rule did nothing at all, so nothing could be withdrawn by it. A narrower repair was available and is not attempted — refusing (or reporting DEAD) when a policy waiver names a rule the scan enforces but cannot attribute, which converts a silent withdrawal of enforcement into a loud one, is the direction the rest of this package takes (`apply_ledger` already throws LedgerError when a text scan meets an `arg_type` predicate it cannot evaluate). The oracle does not cover the new direction: the added testset asserts the DOI case, the canonical case, and that `RULE.DOC.NO_DEAD_REFS` waives nothing — but RULE.DOC.NO_DEAD_REFS is unrelated to SCAN.DOI_CROSSCHECK, so the assertion that an unrelated rule waives nothing says nothing about the sibling-withdrawal case, and neither SCAN.DEAD_REF nor SCAN.API_PAGE_STRUCTURE is exercised at all.

### `2026-09-12-audit-changes-02/under-rejection#2` [major/high] close's new build-staleness branch fails open: any git failure, and the `0`×40 head build records itself, make it pass vacuously

- src/CLI/Passes.jl:1160-1171 — the new close block
- src/CLI/Rounds.jl:323 — the head the record is written with
- src/CLI/Passes.jl:1241 — the sibling guard the comment cites
- test/rounds.jl:546, 659, 723, 1018-1025 — the four records re-baselined to satisfy it

The guard itself is warranted — 2026-09-12-check-docs-01 graded two passes over a red build — and the missing/red branches are sound. The staleness branch is not. Its comment claims "The staleness test is the one `audit_after_code` uses", but the test it actually copies from lives 70 lines below in the same function (the audit-changes branch, Passes.jl:1241) and is a PAIR: `Git.run(root, "cat-file", "-e", a["head"] * "^{commit}") === nothing ? push!(fails, "staleness UNCHECKABLE: the audited head … is unreachable") : (isempty(stale) || push!(fails, …))`. The reachability half — the half that converts an unanswerable question into a refusal rather than a pass — is dropped. Nothing else compensates: `Rounds.build` writes `"0"^40` rather than refusing when `Git.head` returns nothing, and round.schema.json's `^[0-9a-f]{40}$` pattern accepts that sentinel, so a record that is structurally valid can be semantically unanswerable. The oracle is on the wrong side of this too: the three new close branches have no test at all (no test/ file mentions "no docs build is recorded", "the recorded docs build" or the stale message), while four pre-existing round records were edited in the same diff to carry `"build" => Dict("code" => 0, "head" => …)` and the round-lifecycle testset now writes that record by hand rather than calling `Rounds.build` — the guard is satisfied everywhere it is met and asserted nowhere.

### `2026-09-12-audit-changes-02/under-rejection#3` [major/high] The panel's authored-source grant is REPLACED by latex_source_globs, so a consumer that set that key loses ext/, docs/src/ and docs/ from five hats' reading surface

- src/CLI/Preflight.jl:726-731 — the resolution
- instruments/check-consistency/workflow/panel.js:86 — the substrate text
- instruments/check-consistency/schema.json:169-176 — the new required arg
- test/coverage.jl:106-121 — the testset added with it

Two defects were being fixed: panel.js carrying package paths as literals (a core-invariant breach) and latex_source_globs having no reader. Both are real. The edit is wider than either: it does not give the key a reader, it makes the key the DEFINITION of a different and larger surface. The key's own name, its schema entry (`$ref: strlist`, `default: []`, no description) and its ARCHITECTURE examples all describe LaTeX source globs for the typesetting hat; nothing in the config's documented contract says setting it narrows what every source hat may read. The stated motivation — "a consumer naming examples/*.jl had its Literate surface silently never read" — is served by a UNION with the four default surfaces, which adds the missing surface without removing three; replacement is the only variant that can subtract. The change is invisible to the consumer: no verb reports which globs a hat received, and the fallback hides it from the tool itself, whose own config sets `latex_source_globs = []` (ARCHITECTURE line 1418), so the tool as its own fifth consumer exercises only the default branch. The new coverage test asserts that panel.js reads `A.source_globs` and that preflight emits a non-empty value — over `fixture_config()`, which is likewise the empty-key branch — so the narrowing direction is asserted nowhere.

### `2026-09-12-audit-changes-02/under-rejection#4` [minor/high] gbg release now admits every open docs round to its own SELF.DOCS build, suppressing the gate's per-round refusals including :committed

- src/CLI/Release.jl:167-169 — the admission
- src/CLI/Release.jl:56-70 — admitted_rounds
- src/CLI/Gate.jl:86 — `r.name in ignored && continue`
- test/gate.jl:41-74 — the testset added with it

The dead-branch diagnosis is correct and the intent is defensible: `if !rc` was written to let a candidate be cut mid-round and could never be exercised. But the admission is unconditional and unscoped — it is computed for a final release too (harmless only because release_fails refuses on any open round first), and it admits open rounds of BOTH docs instruments regardless of which one, if any, the release relates to. The narrower edit that matches the stated intent is to admit rounds only on the rc path, and only for the reason given. The `:committed` leak is largely covered in practice, because release_fails' `isempty(Git.porcelain(root))` refuses an unclean tree before the build runs and an untracked or modified round directory makes it unclean; that is why this is minor rather than major. It is reported because the weakening is not the one the comment describes: the comment says the build is admitted, the code says the round is excused from every per-round refusal the gate makes.

### `2026-09-12-audit-changes-02/under-rejection#5` [minor/high] release gained a `root` keyword while `running_dev()` still tests the RUNNING copy, so the guard no longer names the checkout that gets tagged and pushed

- src/CLI/Release.jl:148-156 — the new signature and the unchanged guard
- src/CLI/Release.jl:178-179 — the tag and push, now over `root`
- docs/prose_shape.csv:44 — the documented signature, re-measured 178 → 242 words

The motive — the verb was untestable and its rc branch had never run — is sound, and lifting `release_fails` out was the right half of the change. The `root` keyword is the half that widens a public, documented binding (it carries a docstring and appears in the prose-shape register) in order to reach a test, and it decouples the one guard the verb has from the object the verb acts on. Two narrower shapes were available and are not taken: give only `release_fails` the `root` (which is what all the new tests but one actually exercise — `release_fails(cfg, root, …)` is called directly in the second testset), or re-derive the guard from the argument (`ispath(joinpath(root, ".git"))`), so that the thing checked and the thing tagged stay the same object. The docstring's own defence, "the CLI never passes it", is a statement about one caller, not a guard.

## lane behaviour-change

### `2026-09-12-audit-changes-02/behaviour-change#1` [major/high] A policy waiver on a sibling rule now disables the whole scan, withdrawing enforcement nobody exempted

- src/Scan.jl:395-397 — apply_ledger, the `enforced` loop
- src/Scan.jl:111-112 — rules_for_scan
- src/Scan.jl:382-390 — the docstring paragraph that declares the mirror case a known limit
- test/scans.jl:166-180 — the new testset, which asserts only the disabling direction

The defect being fixed was real and one-directional: a documented RULE.CIT.DOI waiver resolved against nothing, so it was void. The fix, however, is symmetric — it makes ANY of a scan's rules a master switch for ALL of them — and the diff itself records the consequence as a known limit rather than narrowing it. A waiver could have been made to exempt only the hits of the rule it names (or, failing per-hit attribution, to be refused loudly for a multi-rule scan) instead of silently enlarging the meaning of ledger entries already on disk. The test added in the same commit pins the disabling direction four ways and pins nothing about the sibling rule that loses its enforcement, so the oracle cannot fail on the half that regressed.

### `2026-09-12-audit-changes-02/behaviour-change#2` [major/high] close refuses every docs round that has no ROUND.toml build record, including every round already open

- src/CLI/Passes.jl:1160-1170 — the new refusal block in close
- src/CLI/Rounds.jl:314-326 — build becomes the only writer of rec["build"]
- schema/round.schema.json:214-237 — the new `build` object
- test/rounds.jl:543-546, 656-660, 720-724, 1015-1023 — four existing close tests re-baselined with an injected build record

The defect — a red build riding through graded passes of a check-docs round — is real and worth a gate. The remedy is wider than it: it applies to both docs instruments though only check-docs lacked a re-check, it credits none of the green builds the round already required, and it gives rounds in flight at the moment of upgrade no migration path. `Rounds.build` also changes character from a runner to a writer: it now re-validates the entire record through `save` (schema/round.schema.json is additionalProperties:false), so a record the current schema rejects makes `gbg round build` throw a RoundError instead of building. ARCHITECTURE §6.2 step 9, which enumerates close's preconditions, was not amended, so the documented contract and the code now disagree about what close requires.

### `2026-09-12-audit-changes-02/behaviour-change#3` [major/high] One rotted seed anchor now refuses the whole round where the round used to run with the rest planted

- src/CLI/Rounds.jl:160-167 — the check-consistency refusal in prepare
- src/CLI/Rounds.jl:245-256 — the check-docs refusal in seed_docs_corpus!
- src/CLI/Rounds.jl:172 and src/CLI/Rounds.jl:297 — the reporting branches the refusals made unreachable

The stated defect is that a skipped class leaves recall UNDEFINED and quietly narrows the denominator. That is a reporting defect and admits a reporting remedy — record the skipped classes in ROUND.toml / the recall report and make them loud at grade. Turning it into a hard refusal at preflight is a wider edit: it blocks the round rather than the silent measurement, and it does so for both instruments at once. The edit also leaves two now-dead reporting branches behind (Rounds.jl:172, 297 still compose "; skipped classes (anchor absent): …" on a path where `skipped` is provably empty), which is the visible sign that the refusal was bolted in front of the reporting rather than replacing it.

### `2026-09-12-audit-changes-02/behaviour-change#4` [major/high] source_globs repurposes latex_source_globs, narrowing the authored-source substrate for any consumer that set it

- src/CLI/Preflight.jl:726-731 — the resolution and the fallback
- instruments/check-consistency/workflow/panel.js:86 — the substrate sentence
- instruments/check-consistency/schema.json:25,169-176 — source_globs added to args.required
- src/CLI/Passes.jl:588 and instruments/check-consistency/workflow/verify-state.js:21 — the same path list still hardcoded

Wiring a key that had no reader is right; overloading it as the definition of the whole authored-source substrate is wider than that, because the consumer wrote its value under the old meaning and gets a narrowed panel without being asked. A union (defaults plus the consumer's globs), or a new key, would have given the Literate surface its reader without taking anything away. The change is also only half-applied: `pass open` still hands the state verifier a hardcoded `source_scope` of ["src", "ext", "docs/src", "docs"] (Passes.jl:588) and verify-state.js keeps the same literal as its fallback, so after this commit a consumer's panel hats and its state verifier read different corpora on the same round. Finally, `source_globs` is `required` in the instrument schema, so a round whose args were rendered by the previous CLI no longer validates against the current schema.

### `2026-09-12-audit-changes-02/behaviour-change#5` [major/high] The quantifier class enlarges every lane's mandatory claim checklist by a third to two fifths

- src/CLI/Preflight.jl:352-353 — CLAIM_QUANTIFIER and CLAIM_TOOL_ID
- src/CLI/Preflight.jl:400-406 — the tagging conjunction
- src/CLI/Preflight.jl:344 — the third CLAIM_EXIT alternative
- catalog/lanes/check-docs.toml:12 — the brief that makes every item a debt

The class is worth having — two of five planted seeds were quantifier mutations and both were missed — and the conjunction with a tool identifier is a genuine narrowing from the 2526-line raw match. But the narrowing is looser than the comment's "a fraction of that" suggests, because CLAIM_TOOL_ID admits the bare phrase `gbg <word>` and CLAIM_QUANTIFIER admits `all`, `any` and `only`, which occur in ordinary prose on lines that merely mention a verb. A tighter identifier set, or a cap per surface, would have bought the seeded class without a 40% rise in mandatory items. Separately, the new CLAIM_EXIT alternative `\bexit\s+contract\b[^.]{0,60}?[0-3]\b` matches any digit 0-3 within 60 characters of the phrase, including the trailing digit of a larger number, so it can tag a line that states no exit code; one docs line already flips from `count` to `exit` in the measurement.

### `2026-09-12-audit-changes-02/behaviour-change#6` [minor/high] Admitting the open rounds to the release build also waives the gate's committed-without-the-round refusal

- src/CLI/Release.jl:70 — admitted_rounds
- src/CLI/Release.jl:167-169 — GBG_ROUND on the SELF.DOCS build
- src/CLI/Gate.jl:82-88 — `r.name in ignored && continue` ahead of the :committed check

Restoring the `if !rc` permission is correct — it had been unreachable for nine releases. The admission is broader than the permission needs: it hands the build the whole set of open docs rounds through a switch that suppresses every round-based refusal for them, rather than suppressing only the `:open` kind the release deliberately tolerates. GBG_DOCS_NO_SKIP still guarantees a build that did not happen cannot pass, so the loss is confined to the committed-with-the-round guarantee, but that guarantee is exactly what protects a release cut in the middle of a fix pass.

### `2026-09-12-audit-changes-02/behaviour-change#7` [minor/high] gbg round scripts unfreezes a round's Workflow scripts mid-round, and its own docstring still says nothing does

- src/CLI/Rounds.jl:338 — the docstring claim
- src/CLI/Rounds.jl:346-354 — refresh_scripts, the second caller of copy_scripts
- src/CLI/Rounds.jl:909, 924 — the usage line and the dispatch
- schema/round.schema.json:238-261 — scripts_refreshed

The motivating case is real — a round whose own finding is an unparseable verifier cannot verify itself, and the hand-fix that unblocked 2026-09-12-check-docs-01 left no trace at all. But the verb as written grants the unfreeze generally, for any round, at any point in its life, and the invariant it relaxes is documented nowhere as relaxed: the protocols and ARCHITECTURE still describe preflight as the moment the scripts are fixed. The new docstring is itself already false on this point — it asserts `copy_scripts` "runs there and nowhere else" in the body of the second function that runs it.

## lane over-rejection

### `2026-09-12-audit-changes-02/over-rejection#1` [major/high] A seeded round now refuses to open when ONE seed class has no anchor, where it used to plant the rest and name the class

- src/CLI/Rounds.jl:164-169 (check-consistency prepare, hunk @@ -158,6 +158,15 @@)
- src/CLI/Rounds.jl:252-257 (seed_docs_corpus!, hunk @@ -236,6 +245,16 @@)
- src/CLI/Rounds.jl:172 and src/CLI/Rounds.jl:297 (the now-unreachable `isempty(skipped) ? "" : "; skipped classes (anchor absent): "` branches)
- src/CLI/Recall.jl:58-73 (unchanged contract)
- src/CLI/Rounds.jl:244 (the pre-existing total-failure refusal the new one duplicates and widens)

The fix is wider than the defect. The defect (a class quietly absent from the denominator) is a REPORTING defect, and the round already carries the fact it needs: `skipped` is written to the ground truth and to the tally. Turning it into a hard exit 2 converts a recoverable, documented partial measurement into a blocked instrument, and leaves the old, now-unreachable 'skipped classes (anchor absent)' suffixes at Rounds.jl:172 and :297 as dead evidence that the tolerant path was deliberate. Nothing in the diff migrates existing consumer seed catalogues, and no flag exists to accept a partial plan: `--no-seed` is all-or-nothing.

### `2026-09-12-audit-changes-02/over-rejection#2` [major/high] close now demands a build record only `gbg round build` can write — every round open at this commit, and every round built through prepare or pass open, is refused

- src/CLI/Passes.jl:1159-1171 (hunk @@ -1151,6 +1151,24 @@)
- src/CLI/Rounds.jl:323 (the only writer of `rec["build"]`)
- src/CLI/Rounds.jl:152 and src/CLI/Rounds.jl:198 (prepare's builds, recording nothing)
- src/CLI/Passes.jl:567 (pass open's build, recording nothing)
- src/CLI/Passes.jl:1102-1125 (close's docstring, unchanged)
- docs/src/guide/instruments.md:83-89, docs/src/guide/instruments.md:182-187
- test/rounds.jl:543-546, :656-659, :720-723, :1015-1022 (four existing round records re-baselined with a green build block)

The underlying defect is real — a red build rode through two graded passes — but the gate implemented is wider than it: it rejects rounds whose build WAS run and green (through prepare or pass open), rejects every in-flight round unconditionally, and treats any change under the audit's covered paths, not the docs surfaces, as invalidating. The narrow fix is to record the verdict at all three call sites, and to test staleness against the surfaces the build actually reads. The contract was also not updated where readers look: close's own docstring still enumerates the conditions without the build, and the guide's two close sections (instruments.md:83, :182) still say close needs 'no id open, no lane dead, the files committed and the stamps unchanged'.

### `2026-09-12-audit-changes-02/over-rejection#3` [major/high] A consumer that set latex_source_globs now has docs/src and docs/ REMOVED from the hat's source surface — the key replaces the four surfaces instead of adding to them

- src/CLI/Preflight.jl:724-731 (hunk @@ -701,6 +721,14 @@)
- instruments/check-consistency/workflow/panel.js:86
- instruments/check-consistency/schema.json:22-27 (source_globs added to args.required)
- schema/config.schema.json:441-444
- docs/ARCHITECTURE.md:1241, docs/ARCHITECTURE.md:1353
- test/coverage.jl:106-121

One key now carries two different meanings — the LaTeX-notation source list it was defined as, and the whole authored-source substrate of a hat — and the second silently overrides a surface set the consumer never asked to narrow. Nothing warns when the resolved globs omit `docs/src` or `docs/`, and the new test asserts only that `source_globs` is non-empty (`@test !isempty(a["source_globs"]) && a["source_globs"] isa AbstractVector`) over the fixture, whose value is `[]` — i.e. it exercises the default branch only, never the branch that drops surfaces.

### `2026-09-12-audit-changes-02/over-rejection#4` [major/high] The widened waiver resolution silently switches OFF two scans nobody exempted, for ledgers written under the old rule

- src/Scan.jl:395-399 (hunk @@ -341,15 +373,29 @@ and the apply_ledger body)
- src/Scan.jl:96-113 (rules_for_scan, new)
- catalog/scans.toml:7-11
- test/scans.jl:166-181

This is my lens inverted: nothing new is rejected, but previously valid input (an exemptions ledger that used to leave a scan enforcing) now produces a materially weaker result, and the direction of the change is toward silence. The narrow repair for the reported defect — a documented RULE.CIT.DOI waiver being void — is to resolve the waiver and drop only that rule's hits, which the docstring says is impossible because a `Hit` carries no rule id; the shipped alternative buys the DOI half by giving away the DEAD_REF and API_PAGE_STRUCTURE halves. The new test pins that an UNRELATED rule waives nothing (`@test !isempty(G.run_scan(d, row; ledger = pol("RULE.DOC.NO_DEAD_REFS")).hits)`) but never asks the question this finding asks — that a SIBLING rule's waiver now disables a scan it did not before.

### `2026-09-12-audit-changes-02/over-rejection#5` [minor/high] The quantifier class adds ~500 mandatory checklist items corpus-wide — the padding the adjacent comment warns against

- src/CLI/Preflight.jl:352-353 (CLAIM_QUANTIFIER, CLAIM_TOOL_ID)
- src/CLI/Preflight.jl:345 (CLAIM_EXIT's third alternative)
- src/CLI/Preflight.jl:400-406 (the tagging)
- catalog/lanes/check-docs.toml:12
- instruments/check-docs/PROTOCOL.md:19-21

The class is worth catching — two of five seeds were quantifier mutations — but the filter shipped is far wider than the seeds it missed, and the cost lands on the lanes as an unbounded per-item verdict obligation at economy strength. A narrower conjunction (the universal and the tool identifier in the same CLAUSE, or the universal governing a named verb or rule) would keep the seeded cases; nothing in the diff measures what the new checklist costs a lane, and the round's own lane briefs were updated only in wording.

### `2026-09-12-audit-changes-02/over-rejection#6` [minor/high] `gbg round build` now mutates ROUND.toml — an undocumented side effect that can make the verb fail where it used to run

- src/CLI/Rounds.jl:314-325 (hunk @@ -293,11 +312,47 @@)
- src/CLI/Rounds.jl:302-312 (the docstring, unchanged)
- src/CLI/Rounds.jl:41-48 (save validates the whole record)
- docs/src/guide/rounds.md:24, docs/src/guide/instruments.md:156, docs/src/guide/instruments.md:266

Recording the verdict is the right mechanism for the defect, but the verb's documented contract — run, log, return the code — was not updated to say it now persists state into ROUND.toml and validates the whole record while doing so. The new testset pins the recording over a fresh, valid record only; nothing exercises build over a record that fails validation, which is the case where a previously working verb now throws.

## lane public-contract

### `2026-09-12-audit-changes-02/public-contract#1` [major/high] apply_ledger widened so one waiver can silently disable a sibling rule's enforcement

- src/Scan.jl:395-411 (apply_ledger)
- src/Scan.jl:100-111 (rules_for_scan/rules_register)
- test/scans.jl: "a policy waiver on any rule a scan enforces disables it"

The claimed defect was narrow — a documented, accepted `RULE.CIT.DOI` waiver had zero effect because apply_ledger only checked the scan's single catalogue-canonical rule. The fix is correct for that direction (the waiver now has an effect) but is implemented as "disable the entire scan on a hit against ANY rule it enforces", which is wider than the defect requires: it also makes a rule that scan enforces but that the consumer never exempted (FULL_INLINE) silently stop being enforced whenever the sibling rule (DOI) carries a target-`*` policy waiver, since Hit carries no rule id to filter by. The docstring names this as a known, deliberately un-fixed limitation rather than treating it as an open defect, so the change was shipped as a widened contract by design, not by oversight — but the widening is still real, silent to the exemptions-ledger author, and never called out in the fix as something requiring re-review of existing ledgers.

### `2026-09-12-audit-changes-02/public-contract#2` [minor/high] gbg round close now refuses check-docs/check-consistency rounds with no recorded build, rejecting a previously-successful invocation

- src/CLI/Passes.jl:1159-1170 (close)
- src/CLI/Rounds.jl:340-350 (build now writes rec["build"])
- schema/round.schema.json: new "build" object

The refusal is scoped tightly to the two instruments that actually build docs (via the same Sync.DOCS_INSTRUMENTS constant used elsewhere), matches the concrete defect described (a RED build riding through graded passes to close), and is thoroughly documented in the schema, the docstring and inline comments — including a staleness check reusing the existing audit_after_code pattern rather than inventing a new one. Flagged for completeness per the lens brief (a previously-working `gbg round close` invocation can now exit 2), not because the change looks unjustified.

### `2026-09-12-audit-changes-02/public-contract#3` [minor/medium] gbg round prepare now refuses on any partially-unanchored seed catalogue, rejecting a previously-tolerated invocation

- src/CLI/Rounds.jl:160-172 (prepare, check-consistency seeding)
- src/CLI/Rounds.jl:248-259 (seed_docs_corpus!, check-docs seeding)

The change targets a real, named defect (a class with a rotted anchor reads as UNDEFINED and silently shrinks the recall denominator, exactly the failure mode that let a 2026-09-12-check-docs-01 seed go unmeasured) and is symmetric across both docs-round paths that plant seeds. It does reject previously-tolerated input, which the lens asks to be surfaced, but the narrowing is proportionate to the defect (a partially-plantable catalogue is precisely the case that made the recall metric silently unreliable) rather than over-broad.

## lane invariants

### `2026-09-12-audit-changes-02/invariants#1` [major/high] close() gets a brand-new, universally-required docs-build gate that nothing in the normal lifecycle populates

- src/CLI/Passes.jl:1151-1276 (the `if inst in Sync.DOCS_INSTRUMENTS ... "no docs build is recorded" ...` block)
- src/CLI/Rounds.jl:312-322 (build() now sets rec["build"] and saves it)
- src/CLI/Rounds.jl:923 (build is invoked ONLY from `verb == "build"` in cmd_round — nowhere else)
- instruments/check-docs/PROTOCOL.md:57 (unchanged: 'Builds and tests during the pass go through `gbg round build|test <round>`' — described as something done during fixing, not a mandatory pre-close step)
- test/rounds.jl:960-967 (round-lifecycle test manually writes r["build"] into ROUND.toml rather than exercising the verb, to make an otherwise-unrelated existing test pass)

The commit's own rationale (a red build silently riding through two graded passes) is real and cited (2026-09-12-check-docs-01, work queue), but the fix changes 'the definition of closed' and 'the closure predicates' — both named in §5.5 as non-configurable, MAJOR-to-change invariants — by adding a universal new precondition, without wiring the automatic build step (prepare's inline build) into the same recording path, and without updating PROTOCOL.md to make the new verb a mandatory step. The result is a closure predicate that rejects the previously-valid, undocumented-as-required path of never calling `gbg round build` explicitly.

### `2026-09-12-audit-changes-02/invariants#2` [major/high] a partially-anchored seed catalogue escalates from a tolerated, logged skip to a hard refusal, in two call sites, with no test either way

- src/CLI/Rounds.jl:161-170 (prepare(), check-consistency branch: new `if !isempty(skipped) ... return 2` before planting)
- src/CLI/Rounds.jl:248-257 (seed_docs_corpus!(), check-docs branch: the same new `if !isempty(skipped) ... return 2`)
- src/CLI/Rounds.jl:172 (the now-unreachable success-path println still branches on `isempty(skipped) ? "" : "; skipped classes (anchor absent): " * join(skipped, ", ")`, left in place though `skipped` can no longer be non-empty at that point)

The defect motivating this (a skipped class reads as UNDEFINED in recall, silently shrinking the denominator rather than reporting a broken catalogue) is real and well cited, but the fix is a blanket, untested hard-refusal in two call sites rather than, e.g., a warning plus an explicit override — and it is stricter than the pre-existing 'plants nothing at all' refusal it sits beside, which was the only refusal before.

### `2026-09-12-audit-changes-02/invariants#3` [major/medium] a ledger waiver that used to be silently void now silences the entire scan, including hits of rules the consumer never named

- src/Scan.jl:706-710 (apply_ledger: `enforced = unique!(vcat(String(row["rule"]), rules_for_scan(id))); for rule in enforced, e in Ledger.entries(ledger, rule; scope = "policy") ...`)
- src/Scan.jl:659-672 (new rules_for_scan()/rules_register())
- test/scans.jl:986-996 (new testset demonstrating a RULE.CIT.DOI-only waiver empties `.hits` for SCAN.DOI_CROSSCHECK, which also enforces RULE.CIT.FULL_INLINE)

The narrow bug being fixed (a documented waiver that was silently void, defeating the exemption it was meant to grant) is real and well-evidenced, and the residual over-breadth is honestly disclosed as an architectural limit rather than concealed — but the audit still needs it on record because it changes what an unedited, previously-accepted ledger file does.

## lane claim-versus-edit

### `2026-09-12-audit-changes-02/claim-versus-edit#1` [major/high] Two 'one home' consolidation claims are only partly done; the old duplicate sites survive untouched

- src/CLI/Sync.jl:26-31 (DOCS_INSTRUMENTS definition and its own comment)
- src/CLI/Passes.jl:549 (unconverted)
- src/CLI/Passes.jl:711 (unconverted)
- src/Scan.jl:88-98 (rules_register() docstring claim)
- src/CLI/Doctor.jl:333 (unconverted)
- src/CLI/Doctor.jl:503 (unconverted)

13cd1e2 and 1028b7d each add a shared source of truth (Sync.DOCS_INSTRUMENTS; Scan.rules_register/rules_for_scan) and each commit message/docstring frames the fix as a completed consolidation of every existing hardcoded copy. Neither migration is complete: Passes.jl's two `inst in ("check-consistency","check-docs")` checks and Doctor.jl's two inline RULES.toml parses were never touched by this diff, so the claim ('for all six sites', 'One home, too... and nowhere else') is wider than what the edit actually did.

### `2026-09-12-audit-changes-02/claim-versus-edit#2` [minor/high] The seed-anchor refusal (f64b542) leaves two now-unreachable 'skipped classes' branches behind it

- src/CLI/Rounds.jl:160-173 (prepare, check-consistency branch)
- src/CLI/Rounds.jl:242-297 (seed_docs_corpus!, check-docs)

The refusal added by f64b542 is a correct, narrowly-scoped fix in both call sites it touches, but the commit did not remove the two now-dead conditional message fragments it made unreachable, leaving stale text that describes a state the code can no longer enter.

