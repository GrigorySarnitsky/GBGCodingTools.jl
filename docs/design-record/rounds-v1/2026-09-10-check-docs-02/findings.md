# Findings — 2026-09-10-check-docs-02

The work list, by id. Fix the CLASS, not the line; a seeded finding (marked) is never fixed in the corpus.

## lane rationale

### `2026-09-10-check-docs-02/rationale#1` [major/high] D9 and §7.3 describe makedocs as erroring on any gate failure; the code silently skips the build instead when a docs round is open

- docs/ARCHITECTURE.md:483-488 — "gate(\"check-docs\", \"check-consistency\") **in-process** before Documenter ... `error()`s on any non-zero return, so the gate is reachable on a CI runner with no shim"
- docs/ARCHITECTURE.md:1777 — `WIRE.MAKEDOCS` row: "calls `GBGCodingTools.makedocs(` and contains no `makedocs(` token not preceded by `GBGCodingTools.` and no `function lint_`" (no mention of the deploydocs guard clause)
- contradicts: ext/GBGCodingToolsDocumenterExt.jl:24-31 — "if code == 1 && !isempty(frozen) && !haskey(ENV, \"GBG_DOCS_NO_SKIP\") ... println(\"makedocs: SKIPPED — \", ...); return nothing end"; src/CLI/Doctor.jl:381-386 — the WIRE.MAKEDOCS check also fails on an unconditional `deploydocs(` because "the wrapper returns nothing when a round froze the build"

D9 states the makedocs wrapper `error()`s on any non-zero return from `gate("check-docs", "check-consistency")`, and calls this the tool's 'per-push, harness-independent enforcement point' precisely because every push runs it. But the actual `ext/GBGCodingToolsDocumenterExt.jl` body has a documented exception: when the gate returns 1 because a docs-instrument round is open (RULE.INST.FROZEN_MIDROUND), it does NOT error — it prints a 'SKIPPED' line and returns `nothing` without ever calling `Documenter.makedocs`, exiting 0, unless the environment variable `GBG_DOCS_NO_SKIP` is set (which only `gbg release` and the deep doctor set). This is not a stray implementation detail: it is load-bearing enough that a second doctor check, `WIRE.MAKEDOCS`, was extended to fail on an unconditional `deploydocs(` call specifically because 'the wrapper returns nothing when a round froze the build' (src/CLI/Doctor.jl comment). The `makedocs` docstring in src/DocLints.jl documents this skip behaviour clearly and accurately, so the feature is real and current — but ARCHITECTURE.md, whose purpose is exactly to record such design decisions with their 'forced by' rationale, never mentions it anywhere (no revision entry references `GBG_DOCS_NO_SKIP`, 'SKIPPED', or 'frozen' in this sense outside of D10/D13's round-freeze vocabulary). A reader relying on D9's account would wrongly conclude that `docs.yml` fails loudly on every push while a `/check-docs` or `/check-consistency` round is open, when it actually degrades to a silent no-op build (exit 0) — the opposite of what 'per-push, harness-independent enforcement point' promises.

_hint:_ Add a clause to D9's makedocs bullet (and to the §7.3 WIRE.MAKEDOCS row) stating the frozen-round exception: makedocs returns `nothing` and prints a SKIPPED line instead of erroring when `frozen_rounds` reports an open docs-instrument round, unless `GBG_DOCS_NO_SKIP` is set (as `gbg release` and the deep doctor do); cross-reference `Gate.frozen_rounds`'s own docstring, which already states the rationale precisely.

### `2026-09-10-check-docs-02/rationale#2` [minor/high] D5's list of supported JSON-Schema-subset keywords omits minLength/minimum/maximum, which Schema.jl already validates

- docs/ARCHITECTURE.md:334-336 — "the JSON-Schema-subset validator (types, `required`, `enum`, `pattern`, `additionalProperties`, nested objects and arrays)"
- docs/ARCHITECTURE.md:962 — "the ONE JSON-Schema-subset validator (types, required, enum, pattern, additionalProperties)"
- contradicts: src/CLI/Schema.jl:107-117 — the validator also checks `minLength` (line 113-114), `minimum` (line 116) and `maximum` (line 117) in addition to type/enum/pattern/additionalProperties

RULE.DOC.CURRENT says a summary naming only a subset of what the code now provides is stale even if every listed item is literally true. D5's two enumerations of Schema.jl's supported keywords (repeated near-verbatim at two places in the document) both omit `minLength`, `minimum` and `maximum`, which src/CLI/Schema.jl's `validate()` function implements alongside the listed keywords. This is a minor completeness gap rather than a behavioural contradiction, but it is the kind of stale enumerated list the doc-edit checklist's currency item exists to catch, and it recurs at two locations (a small class).

_hint:_ Extend both enumerations to "(types, `required`, `enum`, `pattern`, `minLength`, `minimum`, `maximum`, `additionalProperties`, nested objects and arrays)" so the parenthetical is exhaustive rather than illustrative, or explicitly mark it as illustrative if that is the intent.

## lane pages

### `2026-09-10-check-docs-02/pages#1` [major/high] index.md links to headings that do not exist anywhere in the docs source

- docs/src/index.md:49 — `[`gbg doctor`](@ref "The doctor's checks")`
- docs/src/index.md:85 — `[The doctor](@ref "The doctor's checks")`
- docs/src/index.md:24,30,33,36,38,66,67,87 — `@ref instruments`, `@ref check-docs`, `@ref check-consistency`, `@ref bug-hunt`, `@ref audit-changes`, `@ref rules`, `@ref RULE.DOC.ARGCOV`, `@ref "GBGCodingTools — architecture"`

index.md's `@ref "The doctor's checks"` (used twice) does not resolve to any heading in the docs tree: `find docs -type f` returns exactly the 12 files that exist (docs/ARCHITECTURE.md plus this lane's 11 files), none titled 'The doctor's checks', and no guide/doctor.md file exists at all — though src/CLI/Init.jl:141 shows one is meant to (docs/src/guide/doctor.md is named in the tool's own surfaces.generated.globs). The same class of dead ref hits every other quoted-heading/id @ref in index.md pointing outside this lane's 11 files: instruments, check-docs, check-consistency, bug-hunt, audit-changes, rules, RULE.DOC.ARGCOV, and "GBGCodingTools — architecture" — none of these ids/headings are defined anywhere in the shipped docs/src tree (only ledger, rounds, config, install, verbs — the 5 @ids actually declared in guide/*.md — resolve). RULE.DOC.NO_DEAD_REFS bars exactly this, and an unresolved Documenter @ref fails the build (RULE.DOC.BUILD_VERIFY), contradicting the release checklist's `julia --project=docs docs/make.jl` exiting 0.

_hint:_ Either write the missing pages/anchors (instruments.md, rules.md, docs/src/architecture.md, docs/src/guide/doctor.md with a heading Documenter can resolve as "The doctor's checks") before wiring these links, or drop the forward @refs from index.md until those pages exist so the site it currently describes actually builds.

### `2026-09-10-check-docs-02/pages#2` [minor/high] "47 read-only checks" is stale — the doctor registers 49  **[SEEDED — count-drift]**

- docs/src/index.md:49 — "47 read-only checks that a package is wired correctly"
- src/CLI/Doctor.jl — 49 check!("…", …) registrations (lines 98–674), 6 of them in const DEEP (line 46)

grep -c '^check!("' src/CLI/Doctor.jl counts 49 registered checks, not 47: 43 run by default and 6 more (LOAD.ENVS, BUILD.DOCS, SELF.DOCS, TEST.PKG, WITNESSES.ESCALATED, WITNESSES.BLOCKED) only under --deep. Neither the full count (49) nor the non-deep subset (43) matches the stated "47", so the figure is stale against the current check registry — a RULE.DOC.CURRENT violation, which requires every summary to match the code's present state.

_hint:_ Re-measure and update to the current count (49 total / 43 without --deep), phrased to match whichever set `gbg doctor` runs by default.

## lane src

### `2026-09-10-check-docs-02/src#1` [major/high] pass_open's displayed signature omits its real full_state keyword

- src/CLI/Passes.jl:299 — "pass_open(cfg, round; regrade = false, sweep_ok = false, io = stdout) -> Int"
- src/CLI/Passes.jl:324-325 — "function pass_open(cfg::AbstractDict, round::AbstractString; regrade::Bool = false, sweep_ok::Bool = false, full_state::Bool = false, io::IO = stdout)"
- contradicts: RULE.DOC.SIGNATURE_FIDELITY / RULE.DOC.SIGNATURE_MIRROR

The docstring's own displayed signature line for pass_open lists only regrade, sweep_ok and io, but the method defined two lines later also takes full_state::Bool = false — which the docstring's own arguments bullets two lines further down DO document. The argument is documented in prose but missing from the signature header shown to the reader.

_hint:_ Add full_state = false to the displayed signature line at Passes.jl:299.

### `2026-09-10-check-docs-02/src#2` [major/high] makedocs docstring claims every non-zero check errors, but the closure gate's non-zero return is swallowed as a skip

- src/DocLints.jl:17-19 — "Any non-zero return is an `error`, so the build fails."
- ext/GBGCodingToolsDocumenterExt.jl:32-38 — frozen-round skip returns nothing on a non-zero gate code
- contradicts: the docstring's own following paragraph

The makedocs docstring's own next paragraph says the wrapper returns nothing when an open round of a docs instrument froze the build, so the blanket claim two sentences earlier — 'Any non-zero return is an error' — is false in exactly the default frozen-round case, unless GBG_DOCS_NO_SKIP is set.

_hint:_ Qualify the sentence to carve out the frozen-round skip described in the following paragraph.

### `2026-09-10-check-docs-02/src#3` [major/high] demote()'s rendered docstring cites a bare section number, which RULE.DOC.NO_DEAD_REFS forbids

- src/CLI/Demote.jl:18 — "§12 records the fork, content against emptiness"
- contradicts: RULE.DOC.NO_DEAD_REFS

RULE.DOC.NO_DEAD_REFS forbids a rendered docstring citing a section number or inaccessible source. demote()'s rendered prose (inside the triple-quoted docstring, not a # comment) cites '§12' plus an unlinked historical round id and finding id, none resolvable from a REPL read of ?demote. This is exactly the pattern SCAN.DEAD_REF's own regex is built to catch.

_hint:_ Move the historical justification to docs/design-record/ or ARCHITECTURE.md; keep the docstring self-contained.

### `2026-09-10-check-docs-02/src#4` [major/high] gbg selftest --pinned's docstring claims it runs the QUICK doctor, but the code runs a bespoke narrower selection

- src/CLI/Selftest.jl:10-11 — "runs the QUICK doctor there — the pinned-copy behaviours (PIN.SELF, PIN.TREESHA, PIN.SOURCES)"
- src/CLI/Selftest.jl:40 — doctor invoked with --only "PIN,CFG.VALID,SELF.CONSUMER"
- contradicts: src/CLI/Doctor.jl's own QUICK constant

The QUICK doctor is a specific named preset in Doctor.jl that does not even include PIN.SELF or PIN.TREESHA, and does include many checks the actual --only "PIN,CFG.VALID,SELF.CONSUMER" call never runs. Calling this bespoke selection 'the QUICK doctor' misdescribes what actually executes.

_hint:_ Replace 'runs the QUICK doctor there' with a description of the actual --only selection.

### `2026-09-10-check-docs-02/src#5` [major/medium] release()'s closing condition for the cited rc round is narrower than what cites_round actually accepts

- src/CLI/Release.jl:43-44 — "closed by honored or adjudicated ids"
- src/CLI/Release.jl:24-26 — accepts closed_by in (honored, adjudicated, rescan, seeded) or a carried id
- contradicts: CLAUDE.md's own Release checklist item 3

release()'s docstring (matching CLAUDE.md's Release checklist verbatim) states the precondition as ids closed by honored or adjudicated ids, but cites_round actually accepts a materially wider set including rescan, seeded closures, or carried ids.

_hint:_ Align the docstring (and CLAUDE.md) with the real accepted set, or tighten cites_round to match the documented rule.

### `2026-09-10-check-docs-02/src#6` [minor/high] SCAN.XLINK's suggested manual fix uses a different link form than Reflection.xlink's own auto-apply

- src/Scans/xlink.jl:6 — "link it as [`$(s.owner).$(s.name)`](@ref)"
- src/Reflection.jl:497 — apply=true writes "[`p`](@ref Package.Owner.p)"
- contradicts: Reflection.xlink's own apply=true code path

The dry-run hit suggests a two-part qualified link with an implicit target, but Reflection.xlink(apply=true) — the function the scan itself calls — writes a bare-name link text with an explicit three-part target for the identical case. The manual guidance and the automatic fix disagree.

_hint:_ Make the Hit's suggested text match what apply=true actually writes.

### `2026-09-10-check-docs-02/src#7` [minor/high] formula_in_backticks.jl's comment misstates its own regex's real false positives

- src/Scans/formula_in_backticks.jl:1-3 — pattern shown includes ≠ but the false-positive list names ×, ⋅, ≈
- contradicts: the pattern literal shown one line earlier in the same comment

The comment displays FORMULA_GLYPHS as [≤≥≠∈∉∇Δ⟨⟩‖√×⋅], then names its false-positive class as ×, ⋅, ≈ — but ≈ never appears in the pattern at all, while ≠, which is in the pattern and is a real Julia operator (used legitimately elsewhere in this package, e.g. `frozen ≠ ideal` in TestHarness.jl), is omitted from the exemption list.

_hint:_ Correct the comment to name ×, ⋅ and ≠ as the real-operator false positives; drop ≈.

### `2026-09-10-check-docs-02/src#8` [minor/high] Fleet.rows' MISSING status is never named in either docstring's enumeration

- src/CLI/Fleet.jl:7-10 — enumerates only OK, NOT-INITIALISED, BEHIND, RED
- src/CLI/Fleet.jl:70 — code assigns status = "MISSING" for a nonexistent path

Both the Fleet module docstring and the Fleet.rows function docstring enumerate exactly four status values, and the function docstring even separately states 'a missing path is exit 2' without naming the status string. The code produces a fifth, distinct status literal, MISSING, that appears in neither enumeration.

_hint:_ Add MISSING to both enumerations.

### `2026-09-10-check-docs-02/src#9` [minor/medium] apply_ledger's docstring overstates when a scan-scope wildcard entry fully disables a scan

- src/Scan.jl:344-346 — describes scan-scope target="*" as always disabling
- src/Scan.jl:357 — code requires target=="*" && !haskey(e,"match") to disable a scan-scope entry

For scope=policy, target * alone disables, matching the docstring. For scope=scan the code additionally requires the entry to carry no match table; one that does falls through to per-hit matching instead. The docstring's combined sentence omits this exception for the scan-scope case.

_hint:_ Split the sentence to state the match-table exception for scan-scope wildcard entries.

### `2026-09-10-check-docs-02/src#10` [nit/medium] cmd_install's docstring overstates that success always means two files were written

- src/CLI/Install.jl:36-38 — "Returns 0 when both files are written"

The docstring's own preceding sentence says the dev pointer file is written only with --dev-checkout. Without that flag only one file (the shim) is ever written, yet the function still returns 0 on success, so 'both files' overstates the ordinary flag-less success path.

_hint:_ Reword to 'Returns 0 on success (the shim always, the dev pointer only with --dev-checkout)'.

## lane ext

### `2026-09-10-check-docs-02/ext#1` [major/high] Comment miscites RULE.INST.FROZEN_MIDROUND for the docs-build skip mechanism  **[SEEDED — false-mechanism]**

- ext/GBGCodingToolsDocumenterExt.jl:26 — "A round of a docs instrument freezes the build (`RULE.INST.FROZEN_MIDROUND`)."
- .gbg/policy/instruments.md (RULE.INST.FROZEN_MIDROUND) — "An instrument is never changed mid-round; a change is its own commit and release"
- docs/ARCHITECTURE.md:2304 — sentinel "An instrument is never changed mid-round; a change is its own commit and release."

The comment cites RULE.INST.FROZEN_MIDROUND as the reason the docs build is skipped while a check-docs/check-consistency round is open. But that rule's actual content (confirmed identically in the rendered policy and in ARCHITECTURE.md's sentinel table) governs a different thing: an instrument's own definition (its scans, scripts, catalogue) may not be edited while a round using it is open. It says nothing about a docs build being refused or skipped because a round is merely open — that behavior is gate()/frozen_rounds()'s own design (Gate.jl: 'A build refused ONLY for these is frozen, not broken'), not an instance of FROZEN_MIDROUND. No other citation of RULE.INST.FROZEN_MIDROUND in the source ties it to build-skipping; the only other hit (Passes.jl:713, carrying deferrals into the work queue) matches the rule's real meaning. This is a false citation of a specific, load-bearing rule id in a codebase where rule ids are meant to be traceable one-to-one to RULES.toml.

_hint:_ Either drop the parenthetical rule-id citation and just describe the mechanism in the wrapper's own terms (point to frozen_rounds/gate instead), or, if a policy rule is wanted, name one that actually governs closure discipline rather than instrument immutability — FROZEN_MIDROUND is not it.

### `2026-09-10-check-docs-02/ext#2` [minor/medium] Module docstring uses the term of art "consumer" unglossed and unlinked

- ext/GBGCodingToolsDocumenterExt.jl:5 — "the mandatory wrapper a consumer's `docs/make.jl` calls"
- src/GBGCodingTools.jl:7 — "A consumer is a package that uses the tool — one of the four sibling GBG packages, or the tool itself."
- src/DocLints.jl:10-13 — the sibling home docstring for the same makedocs operation defines 'instrument'/'round' inline and links [`GBGCodingTools`](@ref) on first use

"Consumer" is one of the package's bound terms of art (defined once, in GBGCodingTools's own module docstring: "A consumer is a package that uses the tool"). The ext module docstring uses it at its first mention ("a consumer's docs/make.jl calls") with no defining clause and no @ref link back to the module that binds it, failing the cold-read test RULE.DOC.TERMS_DEFINED sets. This is the same docstring's own sibling — src/DocLints.jl's home docstring for the identical makedocs operation — which does exactly this for 'instrument' and 'round', explicitly linking [`GBGCodingTools`](@ref) as the term's home. The ext module docstring breaks that established pattern for 'consumer'.

_hint:_ Add [`GBGCodingTools`](@ref) at consumer's first mention (e.g. "the mandatory wrapper a [`consumer`](@ref GBGCodingTools)'s docs/make.jl calls") or a short parenthetical, matching DocLints.jl's practice for the same function.

### `2026-09-10-check-docs-02/ext#3` [minor/high] check()'s docstring signature omits the method's argument types

- ext/GBGCodingToolsDocumenterExt.jl:14 — "    check(verb, code)"
- ext/GBGCodingToolsDocumenterExt.jl:19 — "check(verb::AbstractString, code::Integer) = code == 0 ? nothing : error(...)"

RULE.DOC.SIGNATURE_MIRROR requires the docstring's shown signature to mirror the method's types ("An argument typed in the method is typed in the docstring"). The method declares verb::AbstractString and code::Integer, but the docstring's code block shows the untyped check(verb, code), so a reader copying the shown signature would not see the actual type constraints.

_hint:_ Change the docstring's signature line to check(verb::AbstractString, code::Integer).

## lane built-html

### `2026-09-10-check-docs-02/built-html#1` [blocker/high] Assigned surface docs/build does not exist in the round's ground truth — dead lane, not a clean one

- /tmp/jl_XGd0LR/docs/build — directory absent
- /tmp/jl_XGd0LR/docs/ — contains only ARCHITECTURE.md and src/

The lane brief designates `/tmp/jl_XGd0LR/docs/build` as the surface to audit ('read every API page's rendered content'), but that directory does not exist anywhere under the ground-truth root, and no `.html` file exists anywhere in `/tmp/jl_XGd0LR`. No @docs/@autodocs block's rendered content, no API page's built prose, and none of the HTML-only defect classes this lane exists to catch (base-URL leaks, rendered-markup asterisks surviving CommonMark, stray unrendered math, cross-links resolving to the wrong anchor, the public-home scan's target) can be inspected from this ground truth. Per the package's own RULE.TEST.MISSING_IS_FAILING ('the missing case is the failing case... a zero count is a dead lane rather than a clean one') and RULE.INST.SELF_REPORT ('a zero count is a dead lane rather than a clean hat'), an empty findings list here is not evidence the built HTML is clean — it is evidence the built HTML was never produced for this round's snapshot. Inspection of docs/make.jl and the Documenter extension shows a plausible mechanism consistent with this: GBGCodingToolsDocumenterExt.makedocs prints 'makedocs: SKIPPED' and returns `nothing` without calling `Documenter.makedocs` whenever a check-docs or check-consistency round is open at build time (RULE.INST.FROZEN_MIDROUND) — i.e. the very round this lane serves may itself be the reason no fresh docs/build was ever written into this round's ground-truth snapshot. This is reported as a self-containment/coverage defect of the round's ground truth, not of the package's source prose, and should not be scored as 'built-html surface reviewed clean.'

_hint:_ Either (a) populate the ground-truth root with a docs/build produced with GBG_DOCS_NO_SKIP=1 (or produced before the review round opened) so this lane has an actual surface to audit, or (b) if the built-HTML lane is meant to be structurally unable to run while a check-docs round is open, say so explicitly in the lane brief and drop it from the battery for such rounds rather than presenting it as a normal lane with a normal 'clean' result.

## lane workflow-scripts

### `2026-09-10-check-docs-02/workflow-scripts#1` [blocker/high] The whole workflow-scripts surface is absent — nothing on this lane can be evaluated

- /tmp/jl_XGd0LR/instruments/{check-docs,check-consistency,bug-hunt,audit-changes}/ — only schema.json present, no workflow/ subdirectory, no PROTOCOL.md
- /tmp/jl_XGd0LR/src/CLI/Preflight.jl:551 — `src = joinpath(instrument_dir(instrument), "workflow"); ... for f in readdir(src)`
- /tmp/jl_XGd0LR/src/CLI/Preflight.jl:578 — `main_script(instrument) = Dict("check-consistency" => "panel.js", "check-docs" => "lanes.js", "bug-hunt" => "hunt.js", "audit-changes" => "audit.js")[instrument]`
- /tmp/jl_XGd0LR/src/CLI/Preflight.jl:685 — `println(io, read(joinpath(instrument_dir(instrument), "PROTOCOL.md"), String))`
- /tmp/jl_XGd0LR/src/GBGCodingTools.jl:21 — "A **Workflow** is the instrument's `workflow/*.js` script, launched by the session running the round."

This lane's charter is to read the eleven Workflow scripts under instruments/{check-docs,check-consistency,bug-hunt,audit-changes}/workflow as code and check what they Write against instruments/<name>/schema.json, their arg validation, silent-death paths, prompt self-consistency, and hard-coded package/path/round data. None of those files exist in the checked-out tree: every one of the four instrument directories holds only schema.json, `find -type d -iname workflow` and `find -iname '*.js'` both return no matches anywhere under the tree, and there is no PROTOCOL.md either. Meanwhile the Julia source unconditionally depends on that surface: `Preflight.copy_scripts` (Preflight.jl:551) does `readdir(joinpath(instrument_dir(instrument), "workflow"))` with no existence guard, `main_script` (Preflight.jl:578) names four required entry scripts (`panel.js`, `lanes.js`, `hunt.js`, `audit.js`), Passes.jl and Audit.jl call out `verify-act.js`, `verify-state.js`, `verify-architecture.js`, `severity-recheck.js` and `dismissals.js` by literal path, and Preflight.jl:685 reads `PROTOCOL.md` from each instrument directory unconditionally. Every one of these calls would throw (readdir/read on a nonexistent path) the first time `gbg round open` or `gbg round rerun` ran against this tree. This is not a wording defect inside a script — it means the check-docs battery's own workflow-scripts lane has zero material to apply its six checks (correct, self-contained, notation, formatted, current & complete, cited) to, and per the testing protocol a zero count here is a dead lane, not a clean one.

_hint:_ Either the instruments/<name>/workflow/*.js scripts and PROTOCOL.md files need to be added to this checkout before this lane can run (they are Phase-1 deliverables the engines/CLI already assume exist), or, if they were deliberately withheld from this scratch checkout, the round should record this lane as cannot-evaluate rather than banking an empty findings list as a pass.

## lane catalogues

### `2026-09-10-check-docs-02/catalogues#1` [blocker/high] The catalogues surface assigned to this lane is entirely absent from the round's ground-truth checkout

- /tmp/jl_XGd0LR/catalog — directory does not exist
- src/Scan.jl:80 — `scan_catalog() = TOML.parsefile(joinpath(pkgdir(GBGCodingTools), "catalog", "scans.toml"))["scan"]`
- src/CLI/Doctor.jl:250 — `joinpath(pkgdir(GBGCodingTools), "catalog", "hats", key * ".toml")`

This lane's brief and the round's task both name `/tmp/jl_XGd0LR/catalog` as the surface to audit — the hats, lanes, scans, models and seeds catalogues the engine reads at runtime (per `src/Scan.jl:80`, `src/CLI/Doctor.jl:250`, `src/CLI/Seed.jl`, `src/CLI/Init.jl:135`). No `catalog/` directory, nor any `scans.toml`, `hats/*.toml` or `seeds/*.toml` file, exists anywhere under the ground-truth root `/tmp/jl_XGd0LR` (confirmed by a full recursive listing and a repo-wide grep for 'catalog', which returns only the source code's own references to those paths, never the files themselves). `policy/RULES.toml` and `fixture/defects.toml` — the two files this lane's five per-row checks (rule-exists, fixture-class-exists, surfaces-name-real-keys, persona/substrate consistency, row contradiction) are supposed to be run against — are likewise absent from this checkout. None of the five per-row catalogue checks in the lane brief could be executed: there is no row to enumerate, so none of CORRECT/SELF-CONTAINED/NOTATION/FORMATTED/CURRENT/CITED could be verified on this surface either. Per this package's own RULE.TEST.MISSING_IS_FAILING ('a zero count is a dead lane rather than a clean one') and RULE.INST.SELF_REPORT ('a zero count is a dead lane rather than a clean hat'), this must be reported as a dead lane — unable to evaluate — never as a clean pass on the catalogues surface. Failure scenario: a consolidator or closure loop reading this lane's empty findings as 'catalogues surface clean' would bank the round as though every scan/hat/seed row were verified against RULES.toml and defects.toml, when the entire surface was never on disk to check — exactly the silent coverage hole the package's own dead-lane rule exists to prevent.

_hint:_ Fix the round/workflow snapshot step that assembles /tmp/jl_XGd0LR for the check-docs engine so it copies catalog/ (and, for this lane's cross-checks, policy/RULES.toml and fixture/defects.toml) alongside src/, ext/, docs/ and instruments/; then re-run this lane against the corrected snapshot before the round closes it as evaluated. Until re-run, record this lane in the round as 'cannot evaluate' rather than 'clean', consistent with RULE.TEST.MISSING_IS_FAILING.

## lane rulebook

### `2026-09-10-check-docs-02/rulebook#1` [major/high] LEADING_IDENTITY deviation claims a parameterisation escape hatch that does not exist

- workflow/payload/policy.md:72-79 — rendered RULE.DOC.LEADING_IDENTITY: "For this package the identity leads with the physical meaning — what the operation does to its object, before how it is computed"
- workflow/payload/policy.md:732 — deviations.md: "this package computes no physical quantity, so its docstrings lead with what the operation does, which the rubric's own parameterisation already admits"
- src/CLI/Sync.jl:78-81 — `const IDENTITY_TEXT = Dict("physical-meaning" => "the physical meaning — ...", "estimand" => "the estimand — ...")`
- src/CLI/Init.jl:150 — `"rubric" => Dict("leading_identity" => "physical-meaning")` seeded unconditionally for every new consumer
- contradicts: workflow/payload/policy.md:732 (deviations.md's own LEADING_IDENTITY entry) vs. workflow/payload/policy.md:72-79 (the rule it is describing) and src/CLI/Sync.jl:78-81

The deviations ledger excuses GBGCodingTools from RULE.DOC.LEADING_IDENTITY on the ground that the rubric's own per-package parameterisation 'already admits' non-physical wording ('leads with what the operation does') for a package that computes no physical quantity. But Sync.jl's IDENTITY_TEXT dictionary has exactly two values, 'physical-meaning' and 'estimand', and both keep the literal phrase 'the physical meaning'; Init.jl seeds every consumer, including this one, with 'physical-meaning'. There is no config value that renders as 'what the operation does' without that phrase, and the rule as actually rendered in this same policy.md still reads 'the identity leads with the physical meaning' — directly contradicting the deviation's own premise. Contrast with the vector-notation parameter, which has a genuine "none" => "not used (the package has no vector quantities)" escape hatch (Sync.jl:85); LEADING_IDENTITY has no equivalent third value.

_hint:_ Add a third `rubric.leading_identity` value (e.g. "operational") whose IDENTITY_TEXT drops the 'physical meaning' phrase, or correct the deviation's wording so it stops claiming the parameterisation already admits this and instead states plainly that this package's docstrings keep the physical-meaning template though it does not compute physical quantities.

### `2026-09-10-check-docs-02/rulebook#2` [minor/high] FULL_INLINE's unconditional 'one bullet per work' contradicts BLOCK_LIST's lone-citation form

- workflow/payload/policy.md:439-443 — RULE.CIT.FULL_INLINE: "carries the full reference in a `# References` section ... one bullet per work"
- workflow/payload/policy.md:453-455 — RULE.CIT.BLOCK_LIST: "a lone citation stays inline as `Reference: …`"
- src/Scans/doi_crosscheck.jl:10 — "A one-line `Reference: …` stays legal, being the lone-citation form of RULE.CIT.BLOCK_LIST."

RULE.CIT.FULL_INLINE states the docstring's own `# References` section is always 'one bullet per work' with no exception for a single reference. RULE.CIT.BLOCK_LIST and the actual scan (SCAN.DOI_CROSSCHECK, which explicitly treats a bare `Reference:` line as legal even under a docstring's `# References` heading) both establish that a single reference takes the unbulleted inline 'Reference: …' form instead. A reader following FULL_INLINE's own sentence literally would bullet even a single-reference docstring, which the implemented and cross-referenced rule forbids.

_hint:_ Add FULL_INLINE's single-reference exception (or an explicit cross-reference to BLOCK_LIST, mirroring how HOME_ORDER's own text resolves its three-way 'end of docstring' overlap) so the two rules state one consistent format.

### `2026-09-10-check-docs-02/rulebook#3` [minor/medium] STEER and RETURNS are mechanically checkable rules with no scan implementing them

- workflow/payload/policy.md:115-120 — RULE.DOC.STEER: the exact verbatim in-place steer sentence
- workflow/payload/policy.md:303-307 — RULE.DOC.RETURNS: "arrow and sentence never both appear"
- src/Scans/ (41 files) — `grep -rl steer src/Scans/` and `grep -rl RETURNS src/Scans/` both return nothing
- src/Scans/ai_banner.jl:1-27 — the structurally identical verbatim-sentence rule RULE.DOC.AI_BANNER DOES have SCAN.AI_BANNER, built on a shared `AI_BANNER` text constant

STEER requires an exact, verbatim sentence naming the destination argument — exactly the shape AI_BANNER's rule takes, and AI_BANNER has its own scan (SCAN.AI_BANNER) comparing page text against a shared constant. RETURNS forbids an arrow and a 'Returns' sentence from co-occurring, a plain syntactic check. Neither rule has an entry among the 41 files in src/Scans/, nor any reference in src/CLI/Doctor.jl. This lane's ground-truth snapshot did not include policy/RULES.toml, catalog/scans.toml or test/, so it is possible RULES.toml legitimately records `panel` for one or both with a stated reason — but nothing visible in src/, ext/, docs/ or instruments/*/schema.json backs that, and per RULE.TEST.RULE_WITH_CHECK's own warning an unchecked-but-checkable rule's mere presence 'reads as compliance.'

_hint:_ Confirm and record an explicit `panel` check (with reason) for STEER and RETURNS in RULES.toml if that is the intended tier, or add scans analogous to SCAN.AI_BANNER.

## lane templates

### `2026-09-10-check-docs-02/templates#1` [blocker/high] This lane's assigned surface was not included in the round's ground-truth checkout

- /tmp/jl_XGd0LR/templates — directory does not exist
- project root templates/ — exists in the live repository (confirmed outside .gbg/), so the tool does have a templates surface

The lane brief names `/tmp/jl_XGd0LR/templates` as the surface to audit, but the round's ground-truth checkout at /tmp/jl_XGd0LR contains only docs/, ext/, instruments/ and src/ — no templates/, catalog/, policy/ or schema/ directory was exported into it at all. The live project repository does contain a populated templates/ directory at its root (outside .gbg/), so the package genuinely has this surface; it simply was not carried into this round's snapshot. Per RULE.TEST.MISSING_IS_FAILING ('a zero count is a dead lane rather than a clean one') and RULE.INST.SELF_REPORT, this must be reported as a dead lane, not as a clean pass with zero findings. Concretely: the consolidated round report would otherwise read 'templates: 0 findings, surface clean' when zero files were ever read, and any genuine drift in a rendered template (a stray `{{slot}}` the renderer never fills, or a template that would render invalid YAML/JSON/sh) would silently pass every round that reuses this same broken checkout.

_hint:_ Fix the round's checkout/export step so it copies templates/ (and the other data directories under `catalog/`, `policy/`, `schema/` the tool ships, per CLAUDE.md's 'Data, never code' list) into the /tmp/jl_XGd0LR snapshot, then re-run the templates lane against the corrected ground truth before this round closes; do not bank this lane's result as a clean zero.

## lane schemas

### `2026-09-10-check-docs-02/schemas#1` [major/high] The assigned surface directory schema/ is absent from this round's /tmp snapshot

- /tmp/jl_XGd0LR/schema — does not exist; find /tmp/jl_XGd0LR -maxdepth 2 -type d lists only docs, ext, instruments, src

The lane brief names /tmp/jl_XGd0LR/schema as the primary surface to audit (the 17 canonical *.schema.json files), but that directory was never populated in this round's snapshot — only docs/, ext/, instruments/ and src/ exist under /tmp/jl_XGd0LR. This is not a defect in the package: the live project tree (outside .gbg/, so permitted to read) has a complete schema/ directory of 17 files. To still cover 3 of my 4 checklist items against real content, I read those 17 files from the live working tree and cross-checked them against the code actually present in /tmp/jl_XGd0LR/src. Their newest mtimes (2026-09-10 15:26-16:25) predate the /tmp snapshot's own creation (17:00) and nothing in this session edited them, so the substitution is very likely faithful, but that is inferred from timestamps, not a hash match against whatever the snapshot step intended to copy.

_hint:_ Fix whichever preflight/round-open step populates a round's /tmp scratch checkout so it includes schema/ next time a schemas lane runs; until then, treat this lane's findings about schema/*.schema.json content as verified against the live tree rather than the round's own snapshot.

### `2026-09-10-check-docs-02/schemas#2` [major/high] Design record and a source comment wrongly claim per-instrument schemas $ref finding.schema.json

- docs/ARCHITECTURE.md:629 — "lane-file wrapper and $ref's finding.schema.json for the findings array"
- src/CLI/Rounds.jl:514-515 — "an instrument's / own schema $ref's it and adds its own fields"
- src/CLI/Schema.jl:62 — startswith(ref, "#/") || throw(ArgumentError("only local $ref is supported: $ref"))
- instruments/check-docs/schema.json:183 (and the equivalent line in the other 3 instrument schema.json files) — "$ref": "#/$defs/finding"

ARCHITECTURE.md D11 and a Rounds.jl comment both assert that each instrument's schema.json '$ref's finding.schema.json' for its findings array. That mechanism cannot exist as described: Schema.jl's _deref only resolves a same-document fragment ('#/...') and throws ArgumentError on anything else, so a genuine cross-file $ref into schema/finding.schema.json is structurally impossible with this validator. What each of the 4 instrument schema.json files actually does is define its own separate, hand-typed $defs.finding (bug-hunt: $defs.hunt_finding) — a subset of schema/finding.schema.json's fields (missing the bank-assigned n/lane/seeded/id/carried_from/seed_class, which is correct) but otherwise a manual duplicate of the shared fields (severity/confidence/title/locations/description/type enums), not a reference to the one canonical copy. The core-shape re-check at Rounds.jl:519 narrows a banked finding onto the core schema's property set before validating, which catches an extra key but not a shared-field enum or pattern that has quietly drifted between the 5 hand-typed copies — exactly the single-source guarantee the design record and the comment both claim already exists.

_hint:_ Either extend Schema.jl's $ref resolution to support a cross-file pointer and change the 4 instrument schema.json files to actually reference it, or correct the ARCHITECTURE.md D11 prose and the Rounds.jl:514-515 comment to describe the real mechanism (a hand-synchronized duplicate subset, not a $ref).

### `2026-09-10-check-docs-02/schemas#3` [minor/high] ARCHITECTURE D11's 'Sixteen schemas' enumeration omits carried.schema.json

- docs/ARCHITECTURE.md:626-628 — "Sixteen schemas: schema/{config,exemptions,hat,round,pass,finding,verdict-act, verdict-state,tally,reproduction,dismissal,architecture-fix,audit,ground-truth,import, managed}.schema.json."
- schema/carried.schema.json (exists in the live tree)
- src/CLI/Passes.jl:97 — errs = validate(load_schema("carried"), d)

D11's enumerated list names sixteen schema files and does not include carried, yet schema/carried.schema.json exists, is loaded by literal name and validated at Passes.jl:97, and backs RULE.INST.CARRY's persisted .gbg/carried.toml record of findings carried between rounds. The live schema/ directory holds seventeen *.schema.json files, not sixteen; every name D11 does list is still accurate, but the list as a whole no longer names everything the code ships, which RULE.DOC.CURRENT treats as stale.

_hint:_ Add carried to the D11 enumeration and change 'Sixteen' to 'Seventeen'.

### `2026-09-10-check-docs-02/schemas#4` [minor/high] carried.schema.json alone declares JSON Schema draft-07 instead of 2020-12

- schema/carried.schema.json:2 — "$schema": "http://json-schema.org/draft-07/schema#"
- schema/round.schema.json:2 — "$schema": "https://json-schema.org/draft/2020-12/schema" (representative of the other 16 files, including the 4 instruments/*/schema.json)

Every schema file in schema/ and instruments/*/schema.json declares $schema: https://json-schema.org/draft/2020-12/schema except carried.schema.json, which declares the older draft-07 identifier. Schema.jl's validator ignores $schema entirely, so this has no functional effect on validation, but it is a visible inconsistency in a corpus that ARCHITECTURE D11 advertises as 'one JSON Schema per artefact kind' — a uniform mechanism whose own metadata is not in fact uniform.

_hint:_ Change carried.schema.json's $schema value to the 2020-12 URL used by every other schema file.

## lane cold-reader

### `2026-09-10-check-docs-02/cold-reader#1` [major/high] 'bank' is used as a load-bearing term of art in four docstrings before any docstring defines it

- src/Witnesses.jl:195 — "`:fail` (a hunt's bank: every witness must fail on this tree) or `:pass` (after the fix)"
- src/CLI/Seed.jl:9 — "the same `select` over the unseeded manuscript at bank is the ground truth" (Seeds module docstring)
- src/CLI/Recall.jl:7 — "[`Recall.mark!`](@ref) marks the banked findings that match a planted seed" (Recall module docstring)
- src/CLI/Rounds.jl:8-9 — "[`Rounds.bank`](@ref) validates the lane files, classifies dead lanes, assigns ids, marks seeds and freezes `findings.json`" (the first actual definition, Rounds module docstring)

A cold reader following the package's own include order (which is the order src/GBGCodingTools.jl loads the modules in, and the order in which their vocabulary accumulates) meets the bare word 'bank' as an unglossed, unlinked noun in Witnesses.jl's `run` docstring (position 7 of 32 files) — 'a hunt's bank: every witness must fail on this tree' — with nothing before it in the source establishing what 'bank' means. The word reads as ordinary English (a place things are stored) and gives no hint that it names a specific, mechanical CLI verb (`gbg round bank`) that validates every lane file, classifies dead lanes, assigns ids, marks seeds and freezes `findings.json` — the one irreversible step of a round (`bank: $round is already banked ... findings.json is frozen`, src/CLI/Rounds.jl:411). The same bare, unglossed use recurs in two more module docstrings (Seeds, Recall) before the term is ever defined, in Rounds.jl's own module docstring, 18 files later in the reading order. 'bank' is not in the package's own declared terms-of-art list (src/CLI/Init.jl:128: consumer, instrument, round, lane, hat, anchor, gate, pin, managed file, ledger) nor in policy/glossary.md's term list, despite being at least as load-bearing and at least as opaque to a newcomer as 'gate' or 'ledger', both of which ARE glossed at first mention in the GBGCodingTools module docstring. This is exactly the class RULE.DOC.TERMS_DEFINED targets: a noun that silently assumes context the cold reader does not yet have.

_hint:_ Add 'bank' to the package's declared terms of art (src/CLI/Init.jl's `terms` list and policy/glossary.md), and either move its definition to the GBGCodingTools module docstring (alongside instrument/round/lane/hat/gate) or add an explicit `[`Rounds.bank`](@ref)` link at each of the three early bare uses (Witnesses.jl, Seed.jl, Recall.jl) so a cold reader hits a resolvable pointer instead of an assumed noun.

### `2026-09-10-check-docs-02/cold-reader#2` [major/high] A fourth, undisambiguated colloquial sense of 'anchor' appears after three technical senses were already carefully told apart

- src/CLI/Config.jl:113-119 — `resolve_anchor(root, anchor)`: the first technical sense, a `file#heading` Markdown reference
- src/CLI/Preflight.jl:260-262 — `resolve_hats`: "`anchor` is whether the hat runs at full strength rather than on the economy model ... It is unrelated to the `file#heading` anchors of [`Config.resolve_anchor`](@ref)" (second sense, self-disambiguated)
- src/CLI/Seed.jl:47-50 — `select`: "A class's `anchor` here is a third sense of the word: the regular expression whose match in the manuscript marks where the seed is planted" (third sense, explicitly labelled as such)
- src/CLI/Audit.jl:20 — `audit_bank`: "afterwards it prints the severity re-check Workflow call (an anchor, before \"serious\" is counted at grade)" (fourth, unflagged, colloquial sense)

'anchor' is one of the package's own ten declared terms of art (src/CLI/Init.jl:128) and, by the time a cold reader reaches src/CLI/Audit.jl (include position 28 of 32), the source has already trained them to expect it to carry precise, mutually-exclusive technical meanings: it has introduced a first technical sense (a Markdown `file#heading` locator, Config.resolve_anchor), a second (a hat/lane's full-strength flag, Preflight.resolve_hats — which goes out of its way to say the two are unrelated), and a third (a seed class's matching regex, Seeds.select — which explicitly announces itself as 'a third sense of the word' and disclaims the other two). Having been taught by the source itself that 'anchor' is precise, disambiguated vocabulary, the reader then meets a fourth occurrence in Audit.jl's `audit_bank` docstring — 'an anchor, before \"serious\" is counted at grade' — that is neither the file-heading sense, nor the hat/lane sense, nor the seed-regex sense: it is ordinary English for 'a required step that must happen first', used here for the severity re-check Workflow call. Unlike every other sense, this one carries no disambiguating note at all, so a reader who tries (reasonably, given the pattern established three times already) to resolve it against one of the three known technical meanings gets no match and no help.

_hint:_ Either drop the word 'anchor' from this aside (e.g. 'a required step, run before "serious" is counted at grade') or add the same kind of disambiguating clause the other three senses carry ('a fourth, informal sense: ...') so the cold reader is told this is not the fourth technical meaning of the package's own term of art.

### `2026-09-10-check-docs-02/cold-reader#3` [minor/medium] 'act verifier' / 'state verifier' are introduced as already-known jargon in a single dense docstring with no prior binding

- src/CLI/Demote.jl:6-8 — "the act verifier's grade of what the fix pass DID to one finding, from the diff (the state verifier grades, blind to the diff, whether the defect is still there)"

src/CLI/Demote.jl (include position 21 of 32) is the first file in the source's own reading order to use 'act verifier' and 'state verifier' — a foundational pair of roles that Passes.jl (positions 26+) goes on to build its whole verification model around (pass_open, grade, close all assume the reader already knows the two verifiers and what each is blind to). Demote.jl's docstring does attempt an inline gloss in the same breath it uses the terms, but the gloss is folded into one dense parenthetical alongside 'class_surfaces', 'HONORED' and 'LINE-ONLY' (three more unglossed enum-like values, with no hint of what other verdicts exist), asking a cold reader to resolve five new technical objects in three sentences with no module map that lists this pair the way the GBGCodingTools module docstring lists instrument/round/lane/hat/gate. A reader who has not yet reached Passes.jl (five files later) has to reconstruct the act/state verifier split from this one compressed aside.

_hint:_ Bind 'act verifier' and 'state verifier' once, plainly, in a module docstring a cold reader meets earlier (GBGCodingTools's own map, or Passes.jl's module docstring, which already introduces pass_open/grade/close) and have Demote.jl's docstring link to that definition instead of re-deriving it inline.

## lane operational-claims

### `2026-09-10-check-docs-02/operational-claims#1` [major/high] Rounds.close: "2 on a stamp mismatch" is true for only one of three stamp mismatches

- src/CLI/Passes.jl:867: "Returns 0 when closed, 1 when a condition is unmet, 2 on a stamp mismatch."
- src/CLI/Passes.jl:890: "(st[\"config_sha\"] == rec[\"config_sha\"] || latest_regrade) || push!(fails, \"config changed since open ...\")"
- src/CLI/Passes.jl:891: "(st[\"tool_version\"] == rec[\"tool_version\"] || latest_regrade) || push!(fails, \"tool version moved (...) ...\")"
- src/CLI/Passes.jl:892: "if st[\"tool_tree_sha\"] != rec[\"tool_tree_sha\"] && st[\"tool_version\"] == rec[\"tool_version\"] && !startswith(...) ... return 2"

close()'s docstring states the exit contract as "0 when closed, 1 when a condition is unmet, 2 on a stamp mismatch", reading as if any stamp disagreement (config_sha, tool_version, tool_tree_sha) yields exit 2. The body only returns 2 for the tool_tree_sha-under-same-version anomaly (a moved tag). A changed config_sha or a moved tool_version is instead pushed onto `fails` and returns 1 like any other unmet condition.

_hint:_ Reword to: "2 only when the tool's tree hash moved under an unchanged version (a moved tag, abandon-only); a changed config_sha or tool_version is an ordinary refused condition (exit 1, fixed by --regrade)."

### `2026-09-10-check-docs-02/operational-claims#2` [major/high] Release.release: cites_round's closure test is narrower in the docstring than in the code

- src/CLI/Release.jl:44: "the `/check-docs` round opened at the latest `<ver>-rc.<n>` tag is closed by honored or adjudicated ids"
- src/CLI/Release.jl:25: "get(e, \"closed_by\", nothing) in (\"honored\", \"adjudicated\", \"rescan\", \"seeded\") || String(id) in carried"

The `release` docstring says the gating round must have every id "closed by honored or adjudicated ids", but `cites_round` (the function that actually performs this check) accepts four closure channels — honored, adjudicated, rescan, seeded — plus any id in the round's carried-forward set.

_hint:_ List all four closure channels plus the carried-id exemption, matching cites_round's actual `in ("honored","adjudicated","rescan","seeded")` test.

### `2026-09-10-check-docs-02/operational-claims#3` [major/high] Rounds.classify_lane omits the zero-findings/empty-checked path to :dead

- src/CLI/Rounds.jl:305-309: "The status is `:dead` (absent, or — renamed to `<name>.rejected.json` beside itself — unparsable or invalid), `:rejected` ... `:empty` (zero findings, non-empty checked), `:truncated` (candidates_found > findings), or `:live`."
- src/CLI/Rounds.jl:328: "(n == 0 && isempty(get(data, \"checked\", []))) && return (:dead, data, sha, \"zero findings AND empty checked[] — a dead lane, not a clean one\")"

The docstring enumerates every path to :dead as only 'absent, or ... unparsable or invalid' (all renamed-to-.rejected cases). It never mentions the distinct branch where a schema-valid, correctly-named lane file with zero findings AND an empty checked[] is also :dead (not renamed) — exactly the RULE.TEST.MISSING_IS_FAILING mechanism.

_hint:_ Add a fourth :dead case: "or — not renamed — zero findings with an empty checked[] (a dead lane that never ran, not a clean one)."

### `2026-09-10-check-docs-02/operational-claims#4` [major/high] Rounds.seed_docs_corpus! has two distinct exit-2 paths but the docstring names only one

- src/CLI/Rounds.jl:220: "Returns 0, or 2 when the catalogue plants nothing."
- src/CLI/Rounds.jl:228-232: "if isempty(plan) ... return 2 end"
- src/CLI/Rounds.jl:241-247: "if length(planted) < length(plan) ... return 2 end"

The docstring's return contract describes only the isempty(plan) branch. A second, independent branch also returns 2 when the catalogue matched something but plant_files() only planted SOME of it — a materially different failure (partial planting) with its own message, never mentioned.

_hint:_ State both conditions: "Returns 0, or 2 when the catalogue matches nothing in the lane surfaces, or when some matched seeds fail to plant into the copied files."

### `2026-09-10-check-docs-02/operational-claims#5` [minor/high] Install.cmd_install: "Returns 0 when both files are written" overstates the normal (no --dev-checkout) path

- src/CLI/Install.jl:38: "Returns 0 when both files are written, 2 when the Julia in use is below the floor, ..."
- src/CLI/Install.jl:53-65: the `--dev-checkout` block (writes dev_pointer()) runs only `if haskey(o.values, "dev-checkout")`; the shim copy always runs

In the common invocation `gbg install` with no `--dev-checkout`, only the shim file is ever written — dev_pointer() is skipped — and the function still returns 0, contradicting "Returns 0 when both files are written".

_hint:_ Split the claim: "Returns 0 when the shim is written (and, with --dev-checkout, the pointer too); 2 when ...".

### `2026-09-10-check-docs-02/operational-claims#6` [minor/medium] Git.changed_paths's docstring doesn't flag that an empty `paths` means UNRESTRICTED, not "no paths"

- src/CLI/Git.jl:128-133: "The files changed in a commit range under a set of paths ... `paths` — the paths the listing is restricted to."
- src/CLI/Passes.jl:281-283: "# the diff is asked for the WHOLE tree: scoping it to the covered paths while the named set is not scoped at all ... touched = Set(Git.changed_paths(root, range, String[]))"

changed_paths's docstring describes `paths` uniformly as restricting the listing. Passing an empty vector actually means NO restriction at all (git's `--` semantics) — the opposite of restricting — as the one caller's own comment has to explain because the function's docstring gives no warning.

_hint:_ Add: "an empty `paths` restricts to nothing being excluded — i.e. the WHOLE tree — not to zero files."

### `2026-09-10-check-docs-02/operational-claims#7` [minor/medium] Fleet's docstrings enumerate four row statuses; the code produces a fifth ("MISSING")

- src/CLI/Fleet.jl:7-9: "computes one row per consumer of `fleet.toml` — `OK`, `NOT-INITIALISED`, `BEHIND` or `RED` with a detail"
- src/CLI/Fleet.jl:70: "push!(out, (name = c[\"name\"], pin = \"—\", status = \"MISSING\", detail = \"$(c[\"path\"]) does not exist\")); code = 2"

Both the module docstring and Fleet.rows's docstring name exactly four status values. The code assigns a fifth literal, "MISSING", for a consumer whose path doesn't exist; the exit-2 behaviour is documented but this status string never appears in either enumeration.

_hint:_ Add MISSING to the enumerated statuses.

### `2026-09-10-check-docs-02/operational-claims#8` [nit/medium] Audit.audit_bank's "afterwards it prints the severity re-check" is conditional, not unconditional

- src/CLI/Audit.jl:19-21: "then runs [`Rounds.bank`](@ref); afterwards it prints the severity re-check Workflow call ..."
- src/CLI/Audit.jl:54-72: `if !isempty(findings) ... println(...severity re-check...) else println(io, "audit-changes bank: no concern banked; ...") end`

The docstring presents printing the severity re-check call as unconditional. The body only does this when the bank produced at least one finding; a clean bank prints a 'no concern banked' line instead and never renders the call.

_hint:_ Qualify: "when the bank produced any finding, it afterwards prints the severity re-check Workflow call; otherwise it reports a clean bank."

