# Findings — 2026-09-11-audit-changes-01

The work list, by id. Fix the CLASS, not the line; a seeded finding (marked) is never fixed in the corpus.

## lane free-reader

### `2026-09-11-audit-changes-01/free-reader#1` [major/high] audit-changes bank's new lane-verdict-contradiction refusal prints a rerun command that is always refused

- src/CLI/Audit.jl:6-16 (new `lane_verdict_contradictions`)
- src/CLI/Audit.jl:40-48 (new refusal block in `audit_bank`)
- src/CLI/Rounds.jl:662-666 (`rerun`'s DEAD/REJECTED-only guard)
- src/CLI/Rounds.jl:459-472 (the generic `bank` mechanism this new check imitates)

The new self-report/findings consistency check (RULE.TEST.BOTH_DIRECTIONS-motivated, and a good idea on its own) is correct in WHAT it refuses, but its remedy text is not backed by the state write the remedy depends on, so following it fails a second time. The accompanying test (`test/rounds.jl`, "an audit lane's verdict must agree with its findings") only asserts that the refusal message contains the right lane names and that no claim ran — it never calls `gbg round rerun` with that exact invocation, so it does not catch that the suggested next step does not work.

### `2026-09-11-audit-changes-01/free-reader#2` [minor/medium] New lane self-report check treats every non-CLEAN verdict string as CONCERNS, silently accepting a malformed verdict the schema would otherwise reject

- src/CLI/Audit.jl:6-16 (new `lane_verdict_contradictions`)

A narrower guard (`v in ("CLEAN", "CONCERNS")` instead of `v isa AbstractString`) would have deferred any out-of-enum value to the generic bank's schema check as the file header comment already promises ("a file that does not parse, or carries no verdict, is the generic bank's to judge" — an invalid-but-present verdict string is not `nothing` and is silently swallowed here instead of deferred).

## lane executing

### `2026-09-11-audit-changes-01/executing#1` [major/high] The new verdict check reads quarantined *.rejected.json files, so a stale one blocks every later audit bank

- src/CLI/Audit.jl:7 (lane_verdict_contradictions, `for f in sort!(filter(endswith(".json"), readdir(fdir)))`)
- src/CLI/Audit.jl:50 (the rerun hint's key derivation)
- src/CLI/Rounds.jl:347,352,355 (classify_lane quarantines into the same findings/ directory)

The check is meant to judge lane files, but it globs every .json in findings/, including the quarantine copies Rounds.classify_lane leaves in that same directory. RAN: a findings dir holding a valid `01-a.json` (CLEAN, []) and `03-invariants.rejected.json` (CLEAN, 1 finding) gives `[("03-invariants.rejected.json", "CLEAN", 1)]`, and the derived rerun key is `invariants.rejected`.

### `2026-09-11-audit-changes-01/executing#2` [major/high] A lane file with "findings": null now crashes audit_bank (MethodError, exit 3); base quarantined it as DEAD with exit 2

- src/CLI/Audit.jl:10 (`n = length(get(d, "findings", Any[]))`)
- src/CLI/Audit.jl:43-45 (called before the claims and before Rounds.bank)

The code comment says 'a file that does not parse, or carries no verdict, is the generic bank's to judge', but a parsed file with a string verdict and a non-array `findings` isn't handed on to the generic bank. RAN: `G.lane_verdict_contradictions` over a dir holding `{"verdict":"CLEAN","findings":null,"lane":"a"}` gives `null findings THROWS: MethodError`, and over `{"verdict":"CONCERNS","findings":"abc"}` it returns `[]` (no contradiction reported).

### `2026-09-11-audit-changes-01/executing#3` [minor/medium] audit-changes bank now refuses (exit 2) a CLEAN lane that reports findings, which the generic bank accepted before

- src/CLI/Audit.jl:41-50
- test/rounds.jl:140-163 (the new test that certifies the refusal)

Behaviour change on the audit instrument's bank path: a verdict/findings disagreement used to be banked on the findings, and is now a hard refusal. The new test (test/rounds.jl) asserts the new behaviour, so it certifies the change rather than checking it against the earlier contract.

### `2026-09-11-audit-changes-01/executing#4` [minor/medium] init now re-renders a freshly seeded test/Project.toml: it strips the seed's comment and, on the tool-itself branch, adds the tool entry its own comment forbids

- src/CLI/Init.jl:296-298 (`"test" in envs || push!(envs, "test")`)
- src/CLI/Init.jl:290-291 (the comment: 'its test environment lists neither a tool entry nor a pin')

The fix targets a dev pin, but it runs for every pin and on the tool-itself branch as well, so it is wider than the defect it fixes.

### `2026-09-11-audit-changes-01/executing#5` [minor/high] makedocs' public return value changes from nothing to true on a completed build (the measurement claim holds)

- ext/GBGCodingToolsDocumenterExt.jl:47-49
- src/DocLints.jl:604-607
- templates/make.jl.seed:5-6
- docs/make.jl (the `result === nothing || deploydocs(...)` guard)

The fix is warranted, but it changes a public contract, and the change should be recorded as such, not only as a comment in the extension.

### `2026-09-11-audit-changes-01/executing#6` [nit/high] The hard-tier prose-shape baseline was re-baselined in the same change set as 19 units that outgrew it

- docs/prose_shape.csv (19 rows raised)
- src/Scans/prose_shape.jl:112-114 (the GREW ratchet), catalog/scans.toml SCAN.PROSE_SHAPE tier = "hard"

I re-ran the measurement, and the baseline values are exactly what the head tree measures.

## lane under-rejection

### `2026-09-11-audit-changes-01/under-rejection#1` [minor/high] makedocs now returns true on a built site, so the unchanged deploy guard in docs/make.jl passes where it used to refuse every build

- ext/GBGCodingToolsDocumenterExt.jl:47-49 (hunk @@ -44,7 +44,9 @@)
- docs/make.jl:77-80 (unchanged)
- templates/make.jl.seed:4-6

The return-value fix removes a guard that nobody knew was refusing everything. The tool's own deploy guard flips from 'never deploy' to 'deploy on every built run'. The intent matches the base promise, but the flip is unannounced and untested.

### `2026-09-11-audit-changes-01/under-rejection#2` [minor/high] The prose-shape ratchet was re-baselined in the same change set: 20 ceilings raised, including a module docstring from 422 to 589 words

- docs/prose_shape.csv (hunks @@ -7,8 +7,8 @@ through @@ -346,7 +346,7 @@)
- src/Scans/prose_shape.jl:111-114 (the GREW comparison the CSV feeds)

A ratchet ceiling was raised in the window it measures. It is scoped to the diff's own growth and the paragraph cap still binds, so the risk is the pattern, not a hidden absorption. The module docstring is now 3 words under the always-binding paragraph cap.

### `2026-09-11-audit-changes-01/under-rejection#3` [minor/medium] Six rules moved from `weakness` to `panel`, dropping the unpaid-check marker on rules a program can decide, RULE.CIT.DOI among them

- policy/RULES.toml:24 RULE.DOC.HOME_ORDER
- policy/RULES.toml:38 RULE.DOC.ONE_HOME
- policy/RULES.toml:45 RULE.DOC.VARIANT_PAIR
- policy/RULES.toml:241 RULE.DOC.MODULE_MAP
- policy/RULES.toml:381 RULE.TEX.IMAGINARY
- policy/RULES.toml:437 RULE.CIT.DOI

A sentinel was removed from the rule ledger. Under the unchanged classification rule, at least CIT.DOI, MODULE_MAP and TEX.IMAGINARY meet the definition of `weakness` (a check could exist), or, for CIT.DOI, would cite the scan that already exists. The paired panel -> weakness moves on five TEST rules do not offset this: they concern different rules.

## lane behaviour-change

### `2026-09-11-audit-changes-01/behaviour-change#1` [major/high] audit_bank's new verdict refusal prints a rerun remedy that `gbg round rerun` refuses: the round cannot be banked

- src/CLI/Audit.jl:43-52 (audit_bank, the new early return 2)
- src/CLI/Rounds.jl:664-666 (rerun refuses any lane not in dead_lanes)
- src/CLI/Rounds.jl:467-468 (dead_lanes written only inside Rounds.bank)

Refusing a lane whose verdict contradicts its own findings is defensible under RULE.TEST.BOTH_DIRECTIONS. But the refusal was placed ahead of the one step that records a lane as re-runnable. The result is wider than the defect: a mislabeled CLEAN now costs the whole round instead of one lane's re-run, and a CONCERNS-with-no-findings that used to bank harmlessly as :empty now does the same. The fix would be to route contradictions through classify_lane as :rejected, or to write them into dead_lanes before returning.

### `2026-09-11-audit-changes-01/behaviour-change#2` [minor/medium] lane_verdict_contradictions also reads quarantined `*.rejected.json` files, which nothing removes

- src/CLI/Audit.jl:27 (`filter(endswith(".json"), readdir(fdir))`)
- src/CLI/Rounds.jl:347,352,355 (quarantine: `mv(p, replace(p, ".json" => ".rejected.json"))`)

The new scan reads more of the findings directory than the lane set the generic bank classifies. The fix is to restrict it to the expected lane files (`expected_lanes(rec)`) or to exclude `.rejected.json`.

### `2026-09-11-audit-changes-01/behaviour-change#3` [minor/high] makedocs' return value changes from `nothing` to `true` for every normal build, and every push to master now deploys

- ext/GBGCodingToolsDocumenterExt.jl:47-49
- src/DocLints.jl:26-31 (docstring)
- templates/make.jl.seed:5-6
- docs/make.jl:78-80
- .github/workflows/docs.yml (push: master, GITHUB_TOKEN)

Justified and correct in direction. It is recorded here because it silently changes what an existing, unchanged make.jl does on CI. The next CHANGELOG entry needs to state it, and a test would pin `!== nothing` on a built run and `=== nothing` on a frozen one.

### `2026-09-11-audit-changes-01/behaviour-change#4` [minor/high] init now rewrites every seeded test/Project.toml through render_project: wider than the dev-pin defect

- src/CLI/Init.jl:291-298
- src/CLI/Sync.jl:324-355 (render_project)
- templates/test-Project.toml.seed

The fix is correct for the dev pin, but it was applied unconditionally. The narrow fix would gate the push on the dev pin and on the non-tool branch, or render the seed correctly for a dev pin.

### `2026-09-11-audit-changes-01/behaviour-change#5` [minor/medium] hunt.js free-lane prompt now says the brief is the ONE .gbg/ file, contradicting the preamble's invariants grant

- instruments/bug-hunt/workflow/hunt.js:94
- instruments/bug-hunt/workflow/hunt.js:85-86 (FREE_PREAMBLE)
- src/CLI/Preflight.jl:437 (invariants.md written under the payload dir)

An instrument-script edit that removes a grant qualifier and leaves a contradiction the base prompt did not have.

### `2026-09-11-audit-changes-01/behaviour-change#6` [nit/medium] doc-policy and naming-policy hat personas widen what the check-consistency panel reports

- catalog/hats/doc-policy.toml:9-13
- catalog/hats/naming-policy.toml:10

Not a code-computation change. The instrument's output distribution changes, so it needs recording when the next tag's CHANGELOG entry is written.

## lane over-rejection

### `2026-09-11-audit-changes-01/over-rejection#1` [major/high] audit_bank's new verdict refusal prints a rerun remedy that `gbg round rerun` refuses: a first bank has no recovery path

- src/CLI/Audit.jl:43-50 (audit_bank, the new early return)
- src/CLI/Rounds.jl:664-666 (rerun, unchanged)
- src/CLI/Preflight.jl:670 (open sets dead_lanes = String[])

Refusing CONCERNS with zero findings enforces a contract the base prompt already stated ('read as dead'). But the refusal bypasses the one mechanism that makes a dead lane re-runnable: `Rounds.bank` recording it in `dead_lanes`. It should record the contradicting lanes in dead_lanes (or route them through classify_lane as :dead) before returning. As written, the refusal is wider than the defect: it strands the round.

### `2026-09-11-audit-changes-01/over-rejection#2` [minor/medium] A CLEAN lane that reports findings is now refused outright; before, its findings were banked and had to be disposed

- src/CLI/Audit.jl:14 `(v == "CLEAN") == (n == 0) || push!(bad, ...)`

Under RULE.TEST.BOTH_DIRECTIONS it is reasonable to flag the CLEAN+n case, but a refusal that throws away banked evidence is wider than a warning or a normalisation (treat the verdict as CONCERNS when findings are non-empty). Combined with the rerun defect above, this case also has no working re-run path on a first bank.

### `2026-09-11-audit-changes-01/over-rejection#3` [minor/medium] The contradiction check runs before schema validation: a schema-invalid lane file now crashes or is misreported instead of being quarantined as DEAD

- src/CLI/Audit.jl:10-14 (lane_verdict_contradictions)
- src/CLI/Audit.jl:100 (VERBS wrapper rethrows non-RoundError)

The contradiction predicate should apply only to schema-valid roster lane files (after classify_lane), or skip any file whose `findings` is not an array and any file not named `NN-<roster key>.json`.

## lane public-contract

### `2026-09-11-audit-changes-01/public-contract#1` [major/high] makedocs' return value silently changes from always-nothing to true-on-success

- ext/GBGCodingToolsDocumenterExt.jl:47-49
- src/DocLints.jl (makedocs docstring)
- templates/make.jl.seed:5-6

The mandatory makedocs wrapper's return contract changes from 'always nothing' (making the documented deploy-guard impossible to write correctly) to 'true on a real build, nothing on a frozen-round skip'. The change is well-motivated and thoroughly re-documented across DocLints.jl, ARCHITECTURE.md and the make.jl seed's comment, but it is still a return-value contract change on the one function every consumer's docs build calls, and it ships with no CHANGELOG entry in this diff.

### `2026-09-11-audit-changes-01/public-contract#2` [minor/medium] gbg init's --dry-run preview no longer matches what a real run writes for test/Project.toml

- src/CLI/Init.jl:293-298

Fixing the missing dev-pin rewrite on a freshly-seeded test/Project.toml is correct and narrowly scoped, but it introduces a new gap between `gbg init --dry-run`'s promised writes and what a real run performs, and ships with no regression test.

### `2026-09-11-audit-changes-01/public-contract#3` [minor/high] gbg audit-changes bank gains a new exit-2 refusal path for input it previously ran to completion on

- src/CLI/Audit.jl:7-16
- src/CLI/Audit.jl:41-49

A deliberate, well-tested new self-consistency gate on `gbg audit-changes bank` that changes the CLI's exit-code behaviour for a round state that previously reached the claim-running stage.

## lane claim-versus-edit

### `2026-09-11-audit-changes-01/claim-versus-edit#1` [minor/medium] Init.jl's templates#2 fix widens test/ sub-environment rendering to the self-consumer branch it explicitly excludes

- src/CLI/Init.jl:284-298 (the `if !isfile(tp)` block)
- src/CLI/Sync.jl:305-334 (subenv_entries / render_project, unchanged, no PKG_NAME guard)

The claim ('a dev pin gets a path source') describes only the general-consumer half of the branch this edit touches; the edit itself is unconditional and also fires on the self-consumer half, which the surrounding code and comments treat as a case that must NOT receive a tool dep/pin entry. This is exactly a claim narrower in scope than the edit made.

## lane contract-drift

### `2026-09-11-audit-changes-01/contract-drift#1` [major/high] The new audit-bank refusal prints a `gbg round rerun` command that rerun itself refuses

- src/CLI/Audit.jl:43-51 (audit_bank, new refusal)
- src/CLI/Rounds.jl:664-666 (rerun refuses lanes not in rec["dead_lanes"])
- src/CLI/Rounds.jl:468 (the only writer of dead_lanes, inside Rounds.bank)
- test/rounds.jl:757-775

The refusal is a new contract: it rejects lane files the generic bank accepted, and its recovery instruction is false. Either the contradicting lanes must go into `dead_lanes` (saved) before returning, or the refusal belongs inside `classify_lane`, which already quarantines and records DEAD lanes so that `rerun` accepts them.

### `2026-09-11-audit-changes-01/contract-drift#2` [major/medium] The disposition-state closed vocabulary was widened in the schema to fit the code; §6.3 still says three values

- schema/reproduction.schema.json:62-70
- docs/ARCHITECTURE.md:1574 (§6.3 disposition record row, unchanged)
- src/CLI/Rounds.jl:633
- test/schemas.jl:125-135

The contract was rewritten to match the code: the code already wrote `open` at base (Rounds.jl:632 at ed16027). Either §6.3 has to record `open` as the pre-disposition default (a MAJOR vocabulary change, with the frozen-at-bank wording reconciled), or bank should not write a disposition until one is recorded.

### `2026-09-11-audit-changes-01/contract-drift#3` [minor/medium] Six program-decidable rules moved from `weakness` to `panel`, which by the rule's own text hides owed checks

- policy/RULES.toml:24 (RULE.DOC.HOME_ORDER)
- policy/RULES.toml:38 (RULE.DOC.ONE_HOME)
- policy/RULES.toml:45 (RULE.DOC.VARIANT_PAIR)
- policy/RULES.toml:241 (RULE.DOC.MODULE_MAP)
- policy/RULES.toml:437 (RULE.CIT.DOI)
- policy/RULES.toml:381 (RULE.TEX.IMAGINARY)

The change lets a reading panel stand in for a buildable scan, contrary to the rule's own final sentence. RULE.TEX.IMAGINARY is the defensible case, since `i` as an index versus the imaginary unit is a judgment call; the other five are not.

### `2026-09-11-audit-changes-01/contract-drift#4` [minor/high] audit_bank's docstring does not mention its new refusal

- src/CLI/Audit.jl:19-37 (docstring, unchanged)
- src/CLI/Audit.jl:43-51

A behaviour change landed without the contract text that describes it.

### `2026-09-11-audit-changes-01/contract-drift#5` [minor/medium] The makedocs SKIPPED exception was narrowed in the prose to fit the code, contradicting the stated rationale

- src/DocLints.jl:20-24
- docs/ARCHITECTURE.md:491-495 (D9)
- ext/GBGCodingToolsDocumenterExt.jl:46

The documentation now tells the truth, which is an improvement, but it was bent to fit the code. The exception the base contract stated in general terms is now documented as absent in one of its two places.

### `2026-09-11-audit-changes-01/contract-drift#6` [nit/high] makedocs now returns `true` instead of Documenter's `nothing` on a completed build

- ext/GBGCodingToolsDocumenterExt.jl:48-50
- src/DocLints.jl:26-30
- templates/make.jl.seed:4-6

A justified fix that still changes a public return contract; noted so it is not released silently.

### `2026-09-11-audit-changes-01/contract-drift#7` [nit/medium] Init's new `push!(envs, "test")` also fires on the tool-as-own-consumer branch, contradicting the comment just above it

- src/CLI/Init.jl:290-298
- src/CLI/Init.jl:307-310
- src/CLI/Sync.jl:305-313

Scope the push to the non-tool branch, or move it inside the consumer arm of the ternary.

## lane sweep-completeness

### `2026-09-11-audit-changes-01/sweep-completeness#1` [minor/high] docs/make.jl (the tool's own docs build) not swept when templates/make.jl.seed's makedocs-return-value contract was corrected

- templates/make.jl.seed:2-7 (changed by this diff)
- docs/make.jl:76-79 (left unchanged)
- ext/GBGCodingToolsDocumenterExt.jl:47-49 (the behaviour both comments describe)

The `something(result, true)` fix to makedocs's return value was correctly explained in three places (docs/ARCHITECTURE.md D9, src/DocLints.jl's docstring, templates/make.jl.seed) but not in the fourth and most concrete instance of the same fact: the tool's own docs/make.jl, which is the literal analogue of what templates/make.jl.seed renders for every other consumer.

## lane reader-consequence

### `2026-09-11-audit-changes-01/reader-consequence#1` [major/high] audit-changes bank's new lane-verdict-contradiction message tells the session to run a `gbg round rerun` that will always be refused

- src/CLI/Audit.jl:41-50 (lane_verdict_contradictions check in audit_bank)
- src/CLI/Rounds.jl:662-666 (rerun's DEAD/REJECTED guard)
- src/CLI/Rounds.jl:340-361 (classify_lane — what actually earns :dead/:rejected)
- src/CLI/Rounds.jl:452-473 (bank — the only writer of rec["dead_lanes"])

The lane-verdict-contradiction check itself is a reasonable, narrowly-scoped addition (RULE.TEST.BOTH_DIRECTIONS: refuse before the executable claims run rather than after). But its user-facing remedy copies the wording of `Rounds.bank`'s dead-lane message without copying the state write (`rec["dead_lanes"] = ...; save(dir, rec)`) that makes that message's command actually work, and there is no `classify_lane` rule that would ever route a verdict/findings mismatch into DEAD/REJECTED on a later real bank pass either. A reader of the printed output has no way to discover this without reading Rounds.jl's rerun/classify_lane source — exactly the gap this lens is built to catch.

