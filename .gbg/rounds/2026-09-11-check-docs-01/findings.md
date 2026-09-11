# Findings — 2026-09-11-check-docs-01

The work list, by id. Fix the CLASS, not the line; a seeded finding (marked) is never fixed in the corpus.

## lane rationale

### `2026-09-11-check-docs-01/rationale#1` [minor/high] §3's tree places `Scan.jl` under `src/CLI/`, but it lives at `src/Scan.jl`

- docs/ARCHITECTURE.md:981 — "      Scan.jl                   `gbg scan docs|html` — the tiered engine over catalog/scans.toml" (6-space indent, nested under `CLI/`)
- src/GBGCodingTools.jl:65 — `include("Scan.jl")` (listed among the top-level src/ includes, between Reflection.jl/TestHarness.jl and CLI/Ledger.jl, not among the `CLI/*.jl` includes)

§3's repository-layout diagram indents `Scan.jl` at the same 6-space level as `Gate.jl`, `Demote.jl`, `Seed.jl`, `Recall.jl`, `Consolidate.jl`, `Audit.jl`, `Hunt.jl`, `Selftest.jl` — all of which the diagram correctly places under `CLI/` and which the module does `include("CLI/<name>.jl")`. But the actual file is `src/Scan.jl` (confirmed by `find src -type f`, which lists it as a sibling of `TreeHash.jl`, `HtmlWalker.jl`, `Reflection.jl`, `Witnesses.jl`, `TestHarness.jl`, `DocLints.jl`) and the module includes it as `include("Scan.jl")`, not `include("CLI/Scan.jl")`. A reader locating the scan engine by this diagram would look in the wrong directory.

_hint:_ Move the `Scan.jl` line out from under `CLI/` in §3's tree to the 4-space level, alongside `TreeHash.jl`/`HtmlWalker.jl`/`DocLints.jl`/`TestHarness.jl`/`Reflection.jl`/`Witnesses.jl`.

### `2026-09-11-check-docs-01/rationale#2` [minor/high] D9 cites `src/Scans/ProseShape.jl`, but the file is `src/Scans/prose_shape.jl`

- docs/ARCHITECTURE.md:531-533 — "The prose-shape ratchet is a scan like any other (`src/Scans/ProseShape.jl`, `catalog/scans.toml` entry `SCAN.PROSE_SHAPE`)…"
- src/Scans/ (directory listing) — the file is `prose_shape.jl`, and every other scan file in the directory (`abutting_spans.jl`, `ai_banner.jl`, `field_docs.jl`, …) is likewise lower_snake_case, never PascalCase

Every scan implementation file under `src/Scans/` is named in lower_snake_case matching its scan function (e.g. `prose_shape.jl`, `ai_banner.jl`, `field_docs.jl`); none use PascalCase. D9's parenthetical names the file `ProseShape.jl`, which does not exist — the actual path is `src/Scans/prose_shape.jl`. This is the one file-path citation in the document that departs from the project's own (and the document's own, elsewhere — e.g. §3's `Scans/<ScanId>.jl`, §12.B's scan table) convention of naming scan files by their lower_snake_case function name.

_hint:_ Change `src/Scans/ProseShape.jl` to `src/Scans/prose_shape.jl` in D9.

## lane pages

### `2026-09-11-check-docs-01/pages#1` [major/high] index.md's doctor-check count (47) is stale against the code's 49  **[SEEDED — count-drift]**

- /tmp/jl_sVK6Mv/docs/src/index.md:51 — "47 read-only checks that a package is wired correctly"
- /tmp/jl_sVK6Mv/src/CLI/Doctor.jl:104-679 — 49 distinct check!("ID", ...) registrations
- /tmp/jl_sVK6Mv/src/CLI/Doctor.jl:48 — const QUICK = [...] (26 ids)
- /tmp/jl_sVK6Mv/src/CLI/Doctor.jl:52 — const DEEP = ["LOAD.ENVS", "BUILD.DOCS", "SELF.DOCS", "TEST.PKG", "WITNESSES.ESCALATED", "WITNESSES.BLOCKED"]

index.md states gbg doctor runs '47 read-only checks'. Counting every check!("ID", ...) registration in src/CLI/Doctor.jl (the only file that registers checks) gives 49 distinct ids — confirmed both by a raw check!( count (50, minus the one-line check! function definition = 49) and by sort -u of every check!("[A-Z_.]+" match (49 unique). Neither way gbg doctor actually runs matches 47 either: a default (non---deep) run executes 43 checks (49 minus the 6-entry DEEP set), and --deep executes all 49. So 47 is not the total, the quick-run count, or the deep-run count under any reading — a stale figure, violating RULE.DOC.CURRENT.

_hint:_ Update the sentence to the current true count — 49 total doctor checks (43 in a default run, all 49 with --deep) — remeasured from the code (RULE.TEST.COUNTS_REMEASURED), not cited from memory.

## lane src

### `2026-09-11-check-docs-01/src#1` [major/high] The package's own top-level module docstring is not a map of the module any more

- src/GBGCodingTools.jl:26-45: "The module is a map; every part is documented at its home. The command line and its configuration: … The engines: …"

GBGCodingTools's module docstring explicitly bills itself as the map of the whole package ("The module is a map; every part is documented at its home", RULE.DOC.MODULE_MAP) and then names exactly nine things: main, Config, makedocs, TestHarness, Reflection, Witnesses, the scan-engine trio, TreeHash, HtmlWalker and consolidate. The module's own include list (lines 55-86) names 29 files, and the map gives no linked one-liner — not even a bare mention — for Sync (the managed-file renderer), Doctor, Ledger, RoundFiles, Git, Schema, Seed, Recall, Preflight, Rounds, Passes (the whole round-lifecycle: open, bank, grade, close — arguably the tool's central mechanism), Init, Demote, Hunt, Audit, Fleet, Bump, Release or Selftest. A cold reader of the map has no way to learn any of this machinery exists. RULE.DOC.CURRENT: "a summary that names only a subset of what the code now provides is stale even if literally true."

_hint:_ Add at least a linked one-liner per operation family the omitted files own (e.g. Preflight/Rounds/Passes — the round lifecycle; Sync — the managed-file renderer; Doctor — the health check; Ledger — the exemption reader) to the map, the way the engines section already covers TestHarness/Reflection/Witnesses.

### `2026-09-11-check-docs-01/src#2` [minor/high] apply_ledger's docstring overstates when a wildcard ledger entry disables a scan

- src/Scan.jl:344-345: "with target `*` disables the scan (every hit exempted, `disabled = true`)"
- src/Scan.jl:356: `any(e -> e["target"] == "*" && !haskey(e, "match"), scan_entries) && return (Hit[], length(hits), true)`

The docstring says a scope = "scan" entry with target = "*" always disables the scan. The code only disables it when that entry ALSO carries no match table (!haskey(e, "match")); a target = "*" entry that does carry a match table falls through to the per-hit loop below and is applied like any other exemption (only hits whose file/symbol/arg satisfy the match are exempted, the rest are kept). match alongside target = "*" is a legal combination under schema/exemptions.schema.json (nothing forbids it), so this is a reachable, not merely theoretical, case the docstring gets wrong. (The scope = "policy" disable check just above it, lines 351-352, has no such match guard and is described correctly.)

_hint:_ Qualify the scan-scope clause: "…with target `*` and no `match` table disables the scan…", distinguishing it from a wildcard entry that does carry match, which is instead evaluated per hit.

### `2026-09-11-check-docs-01/src#3` [nit/high] TestHarness's module map omits its own exported counting helper

- src/TestHarness.jl:10-18: the module docstring's "the element-traffic audit ([`TestHarness.CountingArray`](@ref), [`TestHarness.Traffic`](@ref), [`TestHarness.audit`](@ref))"
- src/TestHarness.jl:26: `export @alloc_below, CountingArray, Traffic, counting, audit, run_regressions, gate`

counting is one of only seven names TestHarness exports, and it has its own docstring (line 133), but the module docstring's map of the element-traffic audit lists CountingArray, Traffic and audit and never mentions counting — the constructor a user actually calls to wrap an array before auditing it.

_hint:_ Add [`TestHarness.counting`](@ref) to the element-traffic-audit bullet, e.g. "([`TestHarness.counting`](@ref), [`TestHarness.CountingArray`](@ref), [`TestHarness.Traffic`](@ref), [`TestHarness.audit`](@ref))".

## lane built-html

### `2026-09-11-check-docs-01/built-html#1` [minor/high] Built site's module docstring is stale relative to current src/GBGCodingTools.jl  **[SEEDED — exit-code-drift]**

- docs/build/index.html: rendered GBGCodingTools module docstring reads "the exit contract is 0 clean, 1 substantive finding, 2 cannot evaluate, 3 crash"
- src/GBGCodingTools.jl:28-29: current source reads "the exit contract is 0 clean, 1 substantive finding, 2 a second finding, 3 crash"
- contradicts: src/CLI/Main.jl's own `main` docstring ("0 clean, 1 substantive finding, 2 cannot evaluate, 3 crash") and CLAUDE.md's "exit code 0 clean, 1 finding, 2 cannot evaluate, 3 crash"

The built site (index.html and guide/verbs.html, both of which quote the module docstring's exit-code sentence) currently show the correct, sensible text "2 cannot evaluate" — but the live src/GBGCodingTools.jl module docstring this page is supposed to be rendered from has since been edited to the nonsensical "2 a second finding", which contradicts the identical 0/1/2/3 contract stated verbatim in main's own docstring (src/CLI/Main.jl, rendered correctly on guide/verbs.html), in the tool's own CLAUDE.md, and in index.html's separate hand-written paragraph ("0 when clean, 1 when it found something, 2 when it could not evaluate, 3 when it crashed"). Documenter renders a docstring verbatim from source at build time, so this built page can only currently read correctly because docs/build predates this source edit — the checked-in HTML artifact no longer reflects the current source it claims to document. The next docs rebuild (required before any release, per CLAUDE.md's release checklist and RULE.DOC.BUILD_VERIFY) will ship the broken sentence to the live site unless the source is fixed first. Failure scenario: a maintainer runs `julia --project=docs docs/make.jl` to cut a release; the regenerated index.html now advertises a self-contradictory exit-code contract ("2 a second finding") that no verb in the codebase actually implements.

_hint:_ Fix the module docstring in src/GBGCodingTools.jl line 29 to read "...1 substantive finding, 2 cannot evaluate, 3 crash..." (matching main's own docstring and the rest of the page), then rebuild docs/ so the built HTML reflects it.

## lane workflow-scripts

### `2026-09-11-check-docs-01/workflow-scripts#1` [major/high] rubric-audit.js and attack-design.js are never invoked by any CLI verb

- instruments/check-consistency/workflow/rubric-audit.js:1
- instruments/audit-changes/workflow/attack-design.js:1
- src/CLI/Preflight.jl:579 — `main_script(instrument) = Dict("check-consistency" => "panel.js", ... )[instrument]`
- src/CLI/Passes.jl:528, :958, :1068 — launch lines exist for verify-architecture.js/severity-recheck.js/dismissals.js, none for these two

Of the eleven workflow scripts, nine are wired into a gbg verb that builds their args and prints their launch line (every "*.js" literal in src/ and ext/ is only: audit.js, dismissals.js, hunt.js, lanes.js, panel.js, severity-recheck.js, verify-act.js, verify-architecture.js, verify-state.js). rubric-audit.js and attack-design.js never appear anywhere in src/ or ext/. Neither script's args/output shape is documented in its instrument's schema.json, and no schema/*.json exists for either output, unlike every other script. docs/ARCHITECTURE.md documents both as delivered v1.0.0 contributions (D17, §6.8: "attack-design.js ... is the instrument every lens list must survive"), but no gbg command can actually launch either.

_hint:_ Add a CLI verb (or fold into an existing one) that constructs args for rubric-audit.js and attack-design.js and prints their launch line, plus matching schema entries.

### `2026-09-11-check-docs-01/workflow-scripts#2` [minor/high] dismissals.js and verify-architecture.js never instruct the agent to echo the finding id

- instruments/bug-hunt/workflow/dismissals.js:19-28 (SCHEMA `id: { type: 'string' }`, no description) and :31-51 (prompt never says "return id=...")
- instruments/bug-hunt/workflow/verify-architecture.js:20-29 and :32-47 (same pattern)
- instruments/check-consistency/workflow/severity-recheck.js:43 — `Return {id: "${it.id}", severity, reason}.` (contrast)
- instruments/check-consistency/workflow/verify-act.js:35 — `id: { type: 'string', description: 'the finding id EXACTLY as given' }` (contrast)

dismissals.js and verify-architecture.js ask one agent per finding to return {id, verdict, evidence,...} but never tell it what to put in id — no schema description, no explicit "return id=" instruction — unlike severity-recheck.js and verify-act.js which do this explicitly. schema/dismissal.schema.json and schema/architecture-fix.schema.json both require id to match a strict `round/lane#n` pattern, and each script's own liveness check (`A.items.filter(i => !verdicts.some(v => v.id === i.id))`) silently reclassifies a correctly-audited finding as "auditor DIED" if the model paraphrases the id.

_hint:_ Add description: 'the finding id EXACTLY as given' to the id property, and an explicit Return {id: "${f.id}", ...} line, matching severity-recheck.js/verify-act.js.

### `2026-09-11-check-docs-01/workflow-scripts#3` [minor/high] severity-recheck.js and attack-design.js write A.round without validating it was supplied

- instruments/check-consistency/workflow/severity-recheck.js:15 (required list omits 'round') vs :48 (`round: A.round` written)
- instruments/audit-changes/workflow/attack-design.js:14 (required list omits 'round') vs :71 (`round: A.round` written)

Both scripts document 'round' as part of Args and write it into their output, but neither's required-arg guard (`for (const k of [...]) if (A[k]===undefined) throw`) includes 'round', unlike every sibling script that writes round (lanes.js, panel.js, audit.js, hunt.js, dismissals.js all validate it). If round were omitted, JSON.stringify silently drops the undefined property instead of throwing the clear 'args.round is required' error every other script gives.

_hint:_ Add 'round' to the required-arg check list in both scripts.

### `2026-09-11-check-docs-01/workflow-scripts#4` [minor/high] hunt.js's free-lane prompt references invariants that were never named

- instruments/bug-hunt/workflow/hunt.js:94 — `(the one file under .gbg/ you may open besides the invariants named above)`
- instruments/bug-hunt/workflow/hunt.js:68-76 (FREE_PREAMBLE, used for this branch, never mentions invariants)
- instruments/bug-hunt/workflow/hunt.js:85 — the invariants line lives only in HUNT_PREAMBLE, the other branch

For a kind==='free' lane, the prompt is FREE_PREAMBLE + "WHERE TO START: ... (the one file under .gbg/ you may open besides the invariants named above)". But FREE_PREAMBLE never names any invariants file — only HUNT_PREAMBLE (the other branch) conditionally adds the invariants line when A.invariants_path is set. The free-lane agent is told invariants were 'named above' when nothing was ever named in its own prompt — a dangling reference copied from the territory-lane phrasing.

_hint:_ Either add the invariants line to FREE_PREAMBLE too, or drop 'besides the invariants named above' from the free-lane suffix.

### `2026-09-11-check-docs-01/workflow-scripts#5` [nit/medium] attack-design.js's header comment documents an args field the code never reads

- instruments/audit-changes/workflow/attack-design.js:5 — `// Args: { ..., subject: {object, defect, defects, lanes, context, directions, standpoint, source}, ... }`
- instruments/audit-changes/workflow/attack-design.js:16-19 — only object, defects (plural), context, standpoint, source are read

The header comment lists subject.defect (singular) as an args field, but the code only ever reads S.defects (plural); subject.defect is never referenced anywhere in the file.

_hint:_ Drop 'defect' from the header comment's args listing.

## lane catalogues

### `2026-09-11-check-docs-01/catalogues#1` [major/medium] audit-changes.toml's anchor flags contradict the D18 they cite

- catalog/lanes/audit-changes.toml:3 — "diffstat arrive in args. † anchors are constants (D18)."
- catalog/lanes/audit-changes.toml:22,38,44,78 — anchor = true on under-rejection, behaviour-change, over-rejection, contract-drift
- docs/ARCHITECTURE.md:923-925 (D18) — "engine lanes carry it in the catalogue as a constant (the `executing` audit lane, the two free hunt lanes, the dismissal auditor and the severity re-check are `anchor = true` there)"
- docs/ARCHITECTURE.md:2086-2088 — restates the identical list a second time
- docs/design-record/survey-bughunt-auditchanges.md:233 — "IT five (executing, under-rejection, behaviour-change, over-rejection, contract-drift)" — the set actually shipped

The catalogue file's own comment says its `anchor` column instantiates D18. But D18, stated twice in ARCHITECTURE.md in near-identical wording, names only the `executing` lane as an anchor among the audit-changes lanes (plus the two free hunt lanes, the dismissal auditor and the severity re-check — none of which are audit-changes rows). The shipped file actually marks FIVE audit-changes lanes anchor=true: executing, under-rejection, behaviour-change, over-rejection and contract-drift. The design-record survey shows this five-lane set was the deliberate IT-derived choice (over PF's rival five, which swapped `invariants` for `over-rejection`), so the catalogue itself looks like the intended, adopted state — it is ARCHITECTURE.md's D18 paragraph that under-lists what it claims to define exhaustively. Either way, one of the two texts a reader is told to treat as authoritative is currently wrong about the other, and the catalogue's own citation of D18 is the false claim as written.

_hint:_ Expand D18's parenthetical (both occurrences, ARCHITECTURE.md:923-925 and :2086-2088) to name all five audit-changes anchors (executing, under-rejection, behaviour-change, over-rejection, contract-drift), or drop the `(D18)` citation from catalog/lanes/audit-changes.toml:3 if the anchor set is no longer meant to be read off that paragraph.

### `2026-09-11-check-docs-01/catalogues#2` [minor/low] doc-policy and naming-policy carry a `source` grant their persona text never invokes

- catalog/hats/doc-policy.toml:55 — needs = ["rulebook", "source"]
- catalog/hats/naming-policy.toml:142 — needs = ["rulebook", "source"]
- instruments/check-consistency/workflow/panel.js:86 — the `source` grant's payoff: "ALSO the AUTHORED SOURCE (read it with Read/Grep; quote findings at file:line)"
- catalog/hats/invariants-and-decisions.toml:111 — the sibling rulebook hat that DOES use its `source` grant: "check the invariants and decision log against the code and docs BOTH WAYS"
- catalog/hats/latex-typesetter.toml:120 — another `source`-needing hat that explicitly instructs "quote each finding at its SOURCE file:line"

Of the three catalogue "rulebook hats" (naming-policy, doc-policy, invariants-and-decisions — docs/ARCHITECTURE.md:417, design-record/05-fix-rulings.md:9), all three carry `needs = ["rulebook", "source"]`, and every other hat that carries a `source` grant (fossil-and-drift, latex-typesetter) explicitly tells the hat to open src/ext and quote file:line. invariants-and-decisions does too ("against the code"). doc-policy and naming-policy do not: their checklists (docstring section order/shape; public-name meaning and uniqueness) are entirely answerable from the rendered manuscript their `full` substrate already grants, and their own output instructions ask only for a quoted rule/name, never a file:line. The `source` grant on these two looks copied uniformly across the three rulebook hats rather than set per hat's actual need.

_hint:_ Either add a sentence to doc-policy's and naming-policy's persona text that uses the source grant (e.g. verifying a docstring's displayed section order against the raw `"""..."""` source rather than the rendered page), or drop `"source"` from their `needs` lists if the rendered manuscript alone suffices.

## lane rulebook

### `2026-09-11-check-docs-01/rulebook#1` [major/high] Six rules tagged check=["weakness"] are already checked by a panel, contradicting RULE.TEST.RULE_WITH_CHECK's own bar

- policy/RULES.toml:24 — RULE.DOC.HOME_ORDER `check = ["weakness"]`
- policy/RULES.toml:38 — RULE.DOC.ONE_HOME `check = ["weakness"]`
- policy/RULES.toml:45 — RULE.DOC.VARIANT_PAIR `check = ["weakness"]`
- policy/RULES.toml:241 — RULE.DOC.MODULE_MAP `check = ["weakness"]`
- policy/RULES.toml:381 — RULE.TEX.IMAGINARY `check = ["weakness"]`
- policy/RULES.toml:437 — RULE.CIT.DOI `check = ["weakness"]`
- catalog/hats/doc-policy.toml:8 — states HOME_ORDER's order, MODULE_MAP's map content, and ONE_HOME/VARIANT_PAIR's f/f! rule almost verbatim
- catalog/lanes/check-docs.toml:26 — the 'family' cross-lane explicitly checks ONE_HOME and VARIANT_PAIR
- catalog/hats/structure-consistency.toml:6 — restates the HOME_ORDER skeleton as its audit template
- catalog/hats/latex-typesetter.toml:9 — lists 'the upright imaginary unit \mathrm{i}' among enforced house-set items
- catalog/hats/citations-integrity.toml:6 — checks the clickable-DOI / Open-Library requirement

RULE.TEST.RULE_WITH_CHECK reserves 'weakness' for a rule with no check at all, distinct from 'panel' ('a rule a reading panel decides inside an instrument that runs'). For these six rules a reading panel already does decide them — doc-policy.toml and structure-consistency.toml (check-consistency instrument) state HOME_ORDER's/MODULE_MAP's content almost verbatim, the check-docs 'family' cross-lane exists specifically to check ONE_HOME/VARIANT_PAIR, latex-typesetter.toml names the imaginary-unit rule explicitly, and citations-integrity.toml names the DOI rule explicitly. Left as 'weakness', the rule registry's own debt ledger overstates unchecked debt for six rules that are in fact covered — the registry drift RULE.TEST.RULE_WITH_CHECK exists to prevent.

_hint:_ Re-tag these six rules' check field to include "panel" (matching sibling rules like TWO_TIER and LEADING_IDENTITY that already use it for the same doc-policy coverage).

### `2026-09-11-check-docs-01/rulebook#2` [major/high] RULE.DOC.ALIASING_BULLET is tagged check=["panel"] but no hat or lane names its actual (placement) requirement

- policy/RULES.toml:80 — RULE.DOC.ALIASING_BULLET `check = ["panel"]`
- catalog/hats/doc-policy.toml:8 — enumerates its enforcement list; no mention of aliasing or the destination bullet
- catalog/seeds/fixture.toml:55-59 — the only 'alias' hit in catalog/: the 'false-property' seed negates an aliasing CLAIM's truth (VERIFIED's territory), not its placement

RULE.DOC.ALIASING_BULLET's content is structural: the aliasing statement must live in the destination argument's bullet, not as standalone prose. A case-insensitive grep of every file under catalog/ and instruments/ for 'alias' finds only bug-hunt's generic 'aliasing' bug-kind and the seeds fixture's content-truth test — neither checks placement. Unlike its neighbours (ONE_HOME, TWO_TIER, LINKS, NO_DEAD_REFS), which doc-policy.toml names explicitly, no persona or lane brief names ALIASING_BULLET's placement rule, so no panel visibly decides it — the mirror-image of finding 1.

_hint:_ Add a clause to doc-policy.toml's persona naming the destination-bullet placement rule, or re-tag ALIASING_BULLET's check to "weakness" until one exists.

### `2026-09-11-check-docs-01/rulebook#3` [minor/low] Five testing-protocol rules tagged check=["panel"] have no corresponding hat/lane/workflow reference in the available ground truth

- policy/RULES.toml — RULE.TEST.GATE_VS_SURVEY, RULE.TEST.DEFINITION_OF_DONE, RULE.TEST.MUTATION, RULE.TEST.BOTH_DIRECTIONS, RULE.TEST.MISSING_IS_FAILING (all `check = ["panel"]`)
- catalog/hats/*.toml, catalog/lanes/*.toml, instruments/*/workflow/*.js — grepped for 'oracle', 'mutation', 'both direction(s)', 'gate...survey', 'definition of done', 'symmetric fixture'; no hit names these rules' substance

None of the four instruments' declared objects (changes to code, source prose, rendered prose, the code) is 'the test suite's own construction discipline', and no catalog hat or lane brief in this snapshot names gate-vs-survey placement, mutation-testing discipline, bidirectional-check review, or missing-case-is-failing review. Reported at low confidence because each consumer's own .gbg/config.toml (out of scope here) could in principle add a bug-hunt territory or lanes_extra entry covering this without it appearing in the shared catalog.

_hint:_ Confirm via the tool's own .gbg/config.toml whether any running instrument's panel actually reads new tests against these five rules; if none does, re-tag them "weakness".

## lane templates

### `2026-09-11-check-docs-01/templates#1` [major/high] SKILL.md.tmpl's shared body text is false when rendered for the gbg-doctor skill

- templates/SKILL.md.tmpl:7-11 — "opens the round, and prints this instrument's protocol, the exact `Workflow` call and the next step"
- templates/SKILL.md.tmpl:15 — "Follow the protocol printed above, exactly and to its end."
- src/CLI/Sync.jl:212-217 (plan()) — the same template body is rendered for every entry of vcat(INSTRUMENTS, ["gbg-doctor"])
- src/CLI/Doctor.jl:772-784 (cmd_doctor) — gbg doctor only runs checks and prints pass/fail lines; never opens a round or prints a protocol/Workflow call

Sync.plan renders the ONE SKILL.md.tmpl body for all five skills alike, varying only frontmatter and {{skill.command}}. The opening sentence matches Preflight.preflight's real behaviour for the four instrument skills, but is false for gbg-doctor, whose command is plain `gbg doctor`: cmd_doctor only runs the check suite and prints pass/warn/fail lines — it never opens a round, prints 'this instrument's protocol', or prints a Workflow call/next step. The template's own parenthetical concedes the round-opening claim is false for gbg-doctor but leaves the 'prints this instrument's protocol, the exact Workflow call and the next step' claim and the closing 'Follow the protocol printed above' line uncorrected, both still false in the rendered .claude/skills/gbg-doctor/SKILL.md shipped to every consumer. Failure scenario: a consumer running /gbg-doctor is told by the skill's own prose to follow a 'protocol' and 'Workflow call' that gbg doctor never prints — its real output is only a PASS/WARN/FAIL checklist.

_hint:_ Give SKILL.md.tmpl a doctor-specific branch or separate template describing gbg doctor's actual read-only check-and-report behaviour instead of reusing the preflight-instrument paragraph with a single parenthetical patch.

### `2026-09-11-check-docs-01/templates#2` [major/high] test-Project.toml.seed always writes a git rev source, breaking a dev-pinned consumer's first Pkg.instantiate()

- templates/test-Project.toml.seed:9 — "GBGCodingTools = {url = \"{{tool.url}}\", rev = \"v{{tool.version}}\"}"
- src/CLI/Init.jl:293-294 — seeds test/Project.toml via Sync.render(Sync.template("test-Project.toml.seed"), s) whenever the consumer isn't the tool root itself
- src/CLI/Sync.jl:305-314 (subenv_entries) — branches to a path source when pin(cfg) == "dev", a branch the seed path never takes
- src/CLI/Init.jl:317 — "Next: `julia --project=docs -e 'using Pkg; Pkg.instantiate()'` (and test/), then `gbg sync`."

subenv_entries, the function gbg sync uses to (re)write every sub-environment's tool entry, correctly switches to a local path source when the config's pin is the literal "dev" (schema/config.schema.json admits "dev" only for "tool root and fixture only"). But the one-time seed at gbg init writes test/Project.toml directly from test-Project.toml.seed via plain Sync.render, which always substitutes {{tool.url}}/v{{tool.version}}, so it always emits a git-rev [sources] entry even for the fixture, the one non-tool-root consumer that is dev-pinned. That yields rev = "vdev", not a resolvable git ref. init's own final message tells the operator to run Pkg.instantiate() for test/ BEFORE gbg sync (the step that would later fix the entry), so the very first instantiate a dev-pinned consumer is told to run fails to resolve GBGCodingTools. Failure scenario: gbg init --migrate seeds the fixture (pin = "dev"); its printed next step tells the operator to run Pkg.instantiate() for test/ before gbg sync; test/Project.toml's freshly seeded [sources] reads rev = "vdev", which Pkg cannot resolve, so Pkg.instantiate() errors before gbg sync ever corrects the entry.

_hint:_ Have Init.jl build test/Project.toml's tool entries via Sync.subenv_entries(cfg, "test") (as gbg sync does) instead of substituting them from the static test-Project.toml.seed slots, or reorder init's printed instructions so gbg sync runs before the test-environment Pkg.instantiate().

### `2026-09-11-check-docs-01/templates#3` [major/high] make.jl.seed's deploydocs-guard comment describes a check that can never distinguish its two cases

- templates/make.jl.seed:4-5 — "It returns nothing when an open round of a docs instrument froze the build ...: that is exit 0, not a failure, so guard any deploydocs call on the value it returns."
- ext/GBGCodingToolsDocumenterExt.jl (makedocs) — frozen path returns nothing; success path returns Documenter.makedocs(; kwargs...)'s own result
- ~/.julia/packages/Documenter/AXNMp/src/makedocs.jl:274,286 — function makedocs(; debug = false, ...); return debug ? document : nothing end
- templates/make.jl.seed:9-17 — the seeded call passes no debug keyword

The comment tells a consumer to guard any deploydocs(...) call on GBGCodingTools.makedocs's return value, on the premise a frozen (skipped) build is distinguishable from a real one by that value. But the success path returns whatever Documenter.makedocs(; kwargs...) returns, and Documenter.makedocs itself returns nothing unless debug = true is passed (confirmed in the installed Documenter source). The seed's own call passes no debug keyword, so under the exact template every consumer starts from, a normal successful build also returns nothing — identical to the frozen-skip path's explicit return nothing. A consumer who follows the comment literally would silently never deploy on any build, successful or frozen. Failure scenario: a consumer adds deploydocs(...) guarded as result === nothing || deploydocs(...); every ordinary successful docs build also returns nothing (Documenter's own default with no debug kwarg), so deploydocs never runs and the site never deploys, with no error anywhere.

_hint:_ Pass debug = true in the seed's call so a real build returns a non-nothing Document distinguishable from the frozen-skip nothing (and say so in the comment), or replace the return-value guard with an explicit signal such as checking GBGCodingTools.frozen_rounds(cfg, ...) directly in make.jl.seed before calling deploydocs.

## lane schemas

### `2026-09-11-check-docs-01/schemas#1` [blocker/high] reproduction.schema.json's disposition.state enum omits "open", the value the tool itself writes

- schema/reproduction.schema.json:62-68
- src/CLI/Rounds.jl:632
- src/CLI/Rounds.jl:633-634

The `disposition` object's `state` property is `"enum": ["fixed", "refused", "escalated"]` (schema/reproduction.schema.json:65-67). But `Rounds.hunt_bank!` sets `rep["disposition"] = Dict("state" => "open")` for every REPRODUCED/EVIDENCED finding (Rounds.jl:632) and immediately validates that same `rep` against `load_schema("reproduction")` two lines later (Rounds.jl:633-634), which throws `RoundError` when validation fails. "open" is not a stray typo: `Passes.jl` treats it as the normal not-yet-disposed state throughout — `get(disp, "state", "open")` (Passes.jl:700), `Dict("state" => "open")` as the fallback when no disposition file exists yet (Passes.jl:699, 1137) — so "open" is the documented initial value of the field the schema is supposed to describe. As written, the schema cannot validate the artefact the tool actually produces at the moment a bug-hunt round confirms any REPRODUCED or EVIDENCED finding, which would abort `gbg round bank` on the ordinary, non-error path of the instrument.

_hint:_ Add "open" to schema/reproduction.schema.json's disposition.state enum (making it ["open", "fixed", "refused", "escalated"]), or, if "open" is meant to be represented by the ABSENCE of a disposition key rather than an explicit state, change Rounds.jl:632 to omit rep["disposition"] entirely until a real disposition is recorded and update every get(disp, "state", "open") fallback to match that convention consistently.

### `2026-09-11-check-docs-01/schemas#2` [major/high] audit-changes lane_file schema requires a self-reported verdict (CLEAN/CONCERNS) that no code path ever reads

- instruments/audit-changes/schema.json:179 (required)
- instruments/audit-changes/schema.json:192-197 (enum)
- src/CLI/Audit.jl:42,52 (verdict_all_clean computed independently)
- src/CLI/Rounds.jl:340-361 (classify_lane, generic across instruments, never reads data["verdict"])

instruments/audit-changes/schema.json's `lane_file` is the only one of the four instrument lane-file schemas that adds `"verdict"` to `required` and types it as an enum `["CLEAN", "CONCERNS"]` (lines 179, 192-197) — the analogous wrappers in check-docs, check-consistency and bug-hunt do not have this field at all. Grepping the whole `src/` tree for any read of this value (`data["verdict"]`, `"CLEAN"`, `"CONCERNS"`) turns up nothing: `Rounds.classify_lane`, the single function that consumes every instrument's `lane_file`, only reads `lane`, `findings`, `checked` and `candidates_found` (Rounds.jl:340-361). The audit's own idea of "clean" — `audit["verdict_all_clean"]` in Audit.jl:52 — is computed independently from `isempty(findings)` and the executable claims' exit codes, never cross-checked against what each lane self-reported. The schema therefore enforces the SHAPE of a field whose VALUE is inert: a lane could emit findings while self-reporting "CLEAN", or emit none while self-reporting "CONCERNS", and nothing in the tool would notice — the exact self-report-without-verification pattern RULE.INST.SELF_REPORT exists to rule out elsewhere.

_hint:_ Either wire classify_lane (or an audit-changes-specific check at bank) to cross-validate data["verdict"] against isempty(data["findings"]) and reject/flag a lane whose self-report disagrees with its own findings list, or drop the required "verdict" field from instruments/audit-changes/schema.json's lane_file if the field is genuinely vestigial.

## lane cold-reader

### `2026-09-11-check-docs-01/cold-reader#1` [major/high] "act verifier" / "state verifier" and the HONORED/LINE-ONLY verdict vocabulary are used with no definition anywhere in the source

- src/CLI/Demote.jl:6-9: "The one demotion rule over an act verdict — the act verifier's grade of what the fix pass DID to one finding, from the diff (the state verifier grades, blind to the diff, whether the defect is still there). `class_surfaces` is the list the verifier fills…"
- src/CLI/Demote.jl:11-12: "An act verdict `HONORED` becomes `LINE-ONLY` when that list is empty…"
- src/CLI/Passes.jl:283-285 (pass_scope): "An id the previous pass left `pending_state` — graded by the act verifier, never read by the blind one — is a suspect too…"
- src/CLI/Passes.jl:587-591 (grade): "applies the demotion to the rest, then the closure channels per id — `honored`, `adjudicated`, `seeded`, `rescan`… A re-checked id — closed earlier, back in scope — keeps the act verdict that closed it…"

A cold reader meets `?GBGCodingTools.demote` (Demote.jl is included right after Doctor.jl, well before Passes.jl) and is immediately handed four unglossed terms of art at once: "act verdict", "the act verifier" (vs. "the state verifier", elsewhere called "the blind verifier" — three names for what turn out to be two roles), "class_surfaces", and "swept". None is a plain-English read: an "act verifier" does not mean a verifier that acts, and "swept" here means specifically "a location a finding names that the fix pass's diff touched" (RULE.DOC.CLASS_SWEEP's sense), not the ordinary sense used two lines earlier in Reflection.jl ("whose `src` surface names the files swept", meaning merely "read"). The closed verdict vocabulary itself — `HONORED`, `LINE-ONLY`, and later `PHANTOM`/`UNFIXED`/`ABSENT`/`NOT-A-DEFECT` (Witnesses.jl, Passes.jl) — is never enumerated or explained as a vocabulary anywhere a `?name` lookup would land; each docstring just uses the members as already-known constants. I verified this is not merely a link I missed: I grepped the whole `src/` and `ext/` tree for "act verifier", "state verifier", "blind verifier", "class_surfaces", "HONORED", "LINE-ONLY" and every occurrence is inside a docstring or comment that USES the term, none DEFINES it (the closest thing to a definition, RULE.INST.SELF_REPORT's "the act verifier sees the diff, the state verifier is blind", lives only in the policy rulebook, which a `?name` REPL read never surfaces). By contrast, every other overloaded-but-central term in this package (`consumer`, `instrument`, `round`, `lane`, `hat`, `gate`, the three senses of `anchor`, `surface`, `managed file`, DEAD/REJECTED/EMPTY/TRUNCATED lane statuses) gets exactly this kind of module-docstring or first-use definition elsewhere in the same corpus, which is what makes its absence here conspicuous rather than a house style.

_hint:_ Bind "act verifier"/"state verifier" (and retire the third name "blind verifier" in favour of whichever the module docstring uses) once, either in the `GBGCodingTools` module docstring alongside `instrument`/`round`/`lane`/`gate`, or in the `Passes` module docstring (which already introduces `demote`, `grade`, `close`) — then `@ref`-link the first mention in `Demote.jl`'s docstring per RULE.DOC.XLINK. State the closed verdict vocabulary (at minimum HONORED, LINE-ONLY, and the exit-vocabulary PHANTOM/UNFIXED/BROKEN a reader meets soon after in Witnesses.jl) in the same place, and use "swept"/"class_surfaces" only after that anchor exists.

### `2026-09-11-check-docs-01/cold-reader#2` [minor/medium] "shim" is used at its first two mentions (Main.jl) before any docstring says what a shim is

- src/CLI/Main.jl:70-71 (running_dev): "`GBG_DEV` is set (the shim's `--dev` route or `main`'s own flag), or the package directory holds a `.git` entry…"
- src/CLI/Main.jl:118-119 (main): "The one entry point of the command line: the shim execs `julia -e 'using GBGCodingTools; exit(GBGCodingTools.main(ARGS))'`…"

`running_dev` and `main` are the fourth and fifth docstrings in the whole source (CLI/Main.jl is the first CLI file included), and both lean on "the shim" as an already-known noun — a plain-English word here standing in for one specific artifact (the executable at `bin/gbg`, installed to `~/.local/bin/gbg`). Nothing before this point, and nothing in these two docstrings themselves, says what the shim is; the reader only gets it eleven files later, and even then only by inference from `Install.jl`'s `shim_source()`/`shim_target()` docstrings ("The path of `bin/gbg` inside the running copy — the shim body `gbg install` copies"), which describe where it lives and how it is installed but never state in one sentence "the shim is the small script at `bin/gbg` that execs `julia -e 'using GBGCodingTools; ...'`" — the reader has to assemble that themselves by noticing `main`'s docstring already quoted that exact exec line. This is much lower-stakes than the act/state-verifier gap (the word is generic engineering vocabulary and the surrounding sentence makes the general shape — some wrapper script — inferable immediately), but it is exactly the ordinary-word-with-a-specific-referent pattern the cold read is meant to catch, and it is avoidable: `Install.jl`'s own module-level comment ("the shim and the registered dev checkout") could have been one clause added to `running_dev`'s or `main`'s docstring, or `shim` could `@ref`-link `shim_source` at first mention.

_hint:_ Add one clause to `running_dev`'s or `main`'s docstring at first use — "the shim (`bin/gbg`, the small script `gbg install` copies to `~/.local/bin/gbg`)" — or `@ref`-link the first "shim" to `[`shim_source`](@ref)`.

## lane operational-claims

### `2026-09-11-check-docs-01/operational-claims#1` [major/high] Module docstring misstates what exit code 2 means  **[SEEDED — exit-code-drift]**

- src/GBGCodingTools.jl:28-30: "the exit contract is 0 clean, 1 substantive finding, 2 a second finding, 3 crash."
- src/CLI/Main.jl:120-121: "returns that function's exit code: 0 clean, 1 substantive finding, 2 cannot evaluate, 3 crash."
- contradicts: src/CLI/Main.jl:108 and :121, and CLAUDE.md's 'Modules and wiring' section ('each verb a function returning its exit code 0 clean, 1 finding, 2 cannot evaluate, 3 crash')

The package's very first docstring (the module doc of GBGCodingTools.jl) states the CLI's exit contract as '0 clean, 1 substantive finding, 2 a second finding, 3 crash.' Every other statement of the same contract disagrees: Main.jl's own `main` docstring, the `usage()` banner ('2 cannot evaluate'), and CLAUDE.md all say exit 2 means 'cannot evaluate.' Checking actual call sites (Main.jl's unknown-verb handler, Scan.jl's cmd_scan usage errors, Doctor.jl's not-a-consumer case, Config.jl's unreadable-config case, and every 'usage: gbg ...' refusal across the CLI files) confirms 2 is used uniformly for cannot-evaluate/usage-error conditions, never to report 'a second finding' as a distinct concept from exit 1.

_hint:_ Change 'a second finding' to 'cannot evaluate' in the GBGCodingTools.jl module docstring so it matches Main.jl, usage(), and CLAUDE.md.

### `2026-09-11-check-docs-01/operational-claims#2` [minor/high] bank() docstring claims reproductions/ is already written by an exit where it is not

- src/CLI/Rounds.jl:447 (bank() docstring): "By the last two exits a hunt's `reproductions/` and a seeded round's `ground_truth.json` are already written, so a re-bank rewrites them rather than creating them."
- src/CLI/Rounds.jl:604-609 (hunt_bank!): "any(r -> r.status == :refused, results) && (println(io, \"bank: a witness loads what it may not (REFUSED) — fix it before anything is banked\"); return 2)" followed by "rdir = joinpath(dir, \"reproductions\"); mkpath(rdir)"

bank()'s docstring enumerates five exit-2 conditions and then asserts that 'by the last two exits' (the hunt-could-not-decide exit and the finding-schema-validation exit) reproductions/ and ground_truth.json are already on disk, so a re-bank only rewrites them. But hunt_bank! has exactly one non-zero return path — the REFUSED-witness check — and that `return 2` executes strictly before `rdir = joinpath(dir, "reproductions"); mkpath(rdir)` and before any reproduction JSON file is written for this bank attempt. So when bank() exits via 'on a hunt, a witness the runner could not decide (hunt_bank! returns its own code),' reproductions/ has NOT yet been created or written for this run, contrary to the docstring's claim. (The claim does hold for the fifth/last exit, the core-schema-validation failure, since for a hunt round hunt_bank! must have already returned 0 — i.e. finished writing reproductions/ — before that check is reached.)

_hint:_ Narrow the claim to the schema-validation exit only, or note explicitly that the hunt-refusal exit precedes reproductions/ being written (mkpath(rdir) sits after the REFUSED check).

### `2026-09-11-check-docs-01/operational-claims#3` [minor/medium] makedocs docstring implies the open-round skip applies to both gate calls; only the first has it

- src/DocLints.jl (makedocs docstring): "after Documenter it runs the built-HTML scans and that gate again. Any non-zero return is an `error`, so the build fails — except a gate refusing only because a docs round is open, which prints a skip line and returns `nothing`, exit 0, unless `GBG_DOCS_NO_SKIP` is set."
- ext/GBGCodingToolsDocumenterExt.jl:32-38 (pre-build gate call with skip handling) vs :46 (post-build gate call: "check(\"gate check-docs check-consistency\", GBGCodingTools.gate(cfg, \"check-docs\", \"check-consistency\"))")

The docstring states the 'gate refusing only because a docs round is open ⇒ skip, exit 0' behavior as a general exception to 'any non-zero return is an error,' right after describing that the gate runs both before and after Documenter ('that gate again'). In the implementation, only the pre-Documenter gate call (lines 32-38) checks `frozen_rounds` and prints the skip line before returning nothing; the post-Documenter gate call (line 46) is a bare `check(...)` with no frozen-round check at all — any non-zero code there (including one caused solely by a docs round opening, e.g. by another session, while Documenter.makedocs was running) unconditionally throws via `error(...)`, hard-failing the build rather than skipping it.

_hint:_ Either give the post-build gate call the same frozen_rounds/skip handling as the pre-build one, or state in the docstring that the skip exception applies only to the gate check taken before Documenter runs.

