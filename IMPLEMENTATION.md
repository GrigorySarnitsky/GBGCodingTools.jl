# GBGCodingTools — the implementation plan

This is the migration order from the package as it stands to the target design, `docs/ARCHITECTURE.md`, which is
normative: nothing here re-argues it. The owner adopted both on 2026-09-17, with the five rulings this plan's last
section records, and said the code as it stands is abandoned; Phase 0 began that day. The design each phase builds
towards is `docs/ARCHITECTURE.md`; what the package was before is `docs/design-record/ARCHITECTURE-v1.md`.

Terms. A **session** is one Claude Code conversation with a finite context. The **floor** is the two commands every commit
passes — `julia --project -e 'using Pkg; Pkg.test()'` and `julia --project=docs docs/make.jl`, each exit 0. Phase 0 writes
them into a tracked `tools/floor.sh` (`#!/bin/sh`, `set -e`, run in the directory its one optional argument names), and every
gate calls that file by path [a variable inside `bash -c '…'` is unset in the new shell and an exported one holding `&&` is
not re-parsed as an operator, so a gate written that way passes without running anything]; no gate uses a pipeline [a pipe's
exit code can hide a match]. A gate that runs in a science package takes that package's path as an argument (`"$1"`, `"$@"`)
supplied after the quoted command, never as a variable inside it; `$PF`, `$CP`, `$HT` and `$SS` stand for those paths, each
of which holds a space. To **harvest** is to move measured content into the new tree rather than
re-derive it; a **stroke** is one moment at which a group of files is deleted (§7); a **batch** is one commit's worth of rule
conversion (§6). This package's `CLAUDE.md` is binding instruction here and is **code** under §4.2, so no documentation fixer
may repair it: every phase that makes a line of it false rewrites that line in the same commit.

## 1. The ruling: rewrite the frame, harvest the leaves

A new `src/` in the target's module order — Model → Texts → Catalogue → ConfigIO → Engine → Render → Orchestration → CLI —
written additively while the old tree still compiles, with measured content moved across. **Why the frame is rewritten.**
Today's tree inverts that order: `src/CLI/` is 8,477 of 12,032 source lines and the engines sit under it; 34 source files
read the parsed `config.toml` as a dictionary where the target has a `Config` struct; every scan returns `Hit(file, line,
text, symbol)` where a check must return `Vector{Location}`, whose `node` field is the whole anti-drift mechanism (§4.5); and
`GBGCodingTools.gate` is called from `ext/GBGCodingToolsDocumenterExt.jl` and `TestHarness.gate()` from `test/runtests.jl`,
so a consumer's docs build *and* its test suite read run state — exactly what §5.1 forbids. Evolving in place is the same
conversion file by file inside a flat module graph, where no layering gate can be written until the last file lands [a gate
that cannot run until the end is not a gate]. **Why the leaves are harvested.** The scan bodies, reflection checks, harness
contracts, witness runner, prose extraction, rule paragraphs and role briefs are the only parts of this package measured
against real defects, and the target alters none of their judgements. The cost is two vocabularies in one tree for a while,
held visible by `LEGACY` in `test/architecture.jl`, printed every run and never allowed to grow.

| Today | Lines | Target | Fate |
|---|---|---|---|
| `src/Scans/*.jl` (44 files) | 1,152 | `src/Rules/*.jl`, each beside its `Rule` | bodies harvested; the wrapper returns `Location` |
| `Scan.jl`: prose extraction (264); catalogue, ledger, tiers, report (422) | 686 | `Texts`; `Engine.Checks`, `Render.report` | moved; rewritten, about 150 kept |
| `Reflection.jl` readers with `HtmlWalker.jl` (~347) and its four checks (268); `TestHarness.jl` less `gate()` (9 lines); `Witnesses.jl` | 1,469 | `Texts`; four `ProgramCheck`s; `Engine.Harness`; the witnesses stage | moved, the docstring reader replaced by JuliaSyntax; bodies harvested; `gate()` deleted in Phase 0 |
| `CLI/Sync.jl`, `Init.jl` (1,302); `templates/` (313, 16 files); `CLI/Doctor.jl`, `Consolidate.jl` (1,006) | 2,621 | `Render`; `Engine.Checks`, `ConfigIO.validate` | about 860 kept; templates become Julia functions, slots become `Setting`s; the doctor's live checks become the wiring check |
| `CLI/{Main,Bump,Release,Install,Git}.jl` (669); `CLI/Config.jl` (371) | 1,040 | `CLI`; `ConfigIO` | reshaped, the exit-code contract unchanged; the reader rewritten, literals only |
| the round machinery (11 files) | 4,493 | `Orchestration` re-derives its behaviour | deleted from `src/`, **filed** as `docs/design-record/machinery-v1/` — Phase 4's named source |
| `CLI/{Schema,Ledger,Fleet,Self,Selftest}.jl`, `TreeHash.jl`, `DocLints.jl`, `schema/` (22 files) | 3,454 | — | deleted (§7); the live schema shapes are `Model` types |
| `instruments/` (4 protocols, 4 schemas, 12 JavaScript files); `catalog/hats/` (22), `lanes/` (3), `models.toml` (318) | 3,422 | `Instrument` values, one driver; readers DERIVED from the rules' tags, two open standpoints and six disciplines written by hand | prose into fields, the scripts into one driver; two briefs survive as standpoints, the rest as the disciplines' descriptions |
| `policy/*.md` (710), `RULES.toml` (686, the 95 ids); `fixture/…/defects.toml` (342) | 1,738 | `Rule.statement`, `Rule.why`; `Example`s | prose verbatim, live until the ratchet reaches zero (§6); 50 planted defects over all 44 scans, 28 clean twins over 25 |
| `test/*.jl` (13 files); `docs/src/` (1,710 hand-written, 2,782 the copied architecture) | 7,224 | `test/{rules,architecture,rehearse,…}.jl`; the new site | about 400 test lines kept; the site cut in Phase 0 to what survives and regrown per phase |

About 4,560 source lines are harvested. New code with no ancestor here is about **6,000** lines, not 3,000: `Model`,
`ConfigIO`, `Guard.classify`, `Texts.reanchor`, `Questions`, `Render`, and above all `Orchestration.Runs` and `Agents`, which
re-derive the behaviour of 4,357 deleted lines of stage machine, grading, preflight and pass-closing — plus ~1,700
documentation lines rewritten and a docstring per new public binding. **One dispatcher**: new verbs register into the same
`VERBS` dictionary every CLI file writes into at load, so neither tree edits the other.

## 2. The phases

Every commit ends green on the floor and is pushed on `master`. The order is what the owner gets, not the design's reading
order: a science package is the first consumer of everything [self-application is what went wrong before — the four packages
this exists for never received it]. No review round runs here during the rebuild, and from Phase 1 `test/architecture.jl`
enforces that rather than leaving it to prose.

### Phase 0 — Adopt and stabilise (15 commits, 2–3 sessions)
**Ends with** the design adopted, no round machinery anywhere, every reader of it corrected in the same commit, and the floor
green at each step. **Depends on** the owner's adoption. **Creates** `docs/ARCHITECTURE.md` and `IMPLEMENTATION.md` (both
moved), `tools/floor.sh`, and under `docs/design-record/`: `ARCHITECTURE-v1.md`, `IMPLEMENTATION-v1.md`, `RULES-v1.toml`,
`machinery-v1/`, `rounds-v1/`, `instruments-v1/`, `roles-v1/`, `attacks-v1/`, `seeds-v1/`, `carried-v1.toml`; `Project.toml`
at `2.0.0-DEV`. **Deletes** the round machinery (11 files, 4,493 lines) and `test/{rounds,seeds,gate}.jl`, **correcting every
reader in the same commits**: `ext/GBGCodingToolsDocumenterExt.jl` (the `GBGCodingTools.gate` call, both `gate_or_skip`
sites, `doctor(cfg, :QUICK)`), `TestHarness.gate()`, `test/runtests.jl` (three includes and the gate line),
`test/coverage.jl` (five deleted-verb assertions), `fixture/GBG Fixture/test/runtests.jl`, `templates/runtests.jl.seed`,
`src/CLI/{Doctor,Release,Bump,Fleet,Init,Config,DocLints}.jl`, `src/GBGCodingTools.jl`'s module map, this package's and the
fixture's `.gbg/config.toml` (`[paths]` and `seed_rounds`, which throw a `ConfigError` the moment their target is gone), the
five `.claude/skills/*/SKILL.md` (each runs `gbg preflight`; generated again in Phase 8), and `CLAUDE.md`. **The site is part
of it**: `docs/make.jl`'s instruments- and doctor-page blocks, the round `@docs` entries of `docs/src/api/CLI.md` and
`docs/src/guide/rounds.md` with its `pages` entry go, leaving the home page, the architecture and the design record
[`warnonly = [:missing_docs]` does not cover a `@docs` block on a deleted binding]. **Owner:** decisions 1–3.
**Gate** `bash -e -o pipefail -c 'test -x tools/floor.sh && test -z "$(git ls-files -- src/CLI/Rounds.jl src/CLI/Passes.jl src/CLI/Preflight.jl src/CLI/RoundFiles.jl src/CLI/Recall.jl src/CLI/Seed.jl src/CLI/Demote.jl src/CLI/Gate.jl src/CLI/Audit.jl src/CLI/Design.jl src/CLI/Hunt.jl .gbg/rounds instruments catalog/seeds catalog/attack docs/src/guide/rounds.md)" && test -d docs/design-record/machinery-v1 && test -d docs/design-record/attacks-v1 && ! git grep -qE "GBGCodingTools\.gate\(|TestHarness\.gate|Preflight\.|Rounds\.|Passes\.|RoundFiles\.|Recall\.|Seeds\." -- src ext test docs/src docs/make.jl fixture templates .claude && ! git grep -q seed_rounds -- .gbg fixture && tools/floor.sh'` [the grep scope excludes `docs/design-record/`, where the moved records legitimately name the deleted modules].

### Phase 1 — Foundation: the two mechanisms with no ancestor (14 commits, 2–3 sessions)
**Ends with** a program that classifies a working-tree change as documentation or code, a verb that commits only when every
changed path came back documentation, and findings that survive moving text. **Depends on** Phase 0. **Creates**
`src/Model.jl` (every struct and enum of §5.2 at once — the vocabulary is cheap to write and expensive to revise);
`src/Texts/` (docstring and page reading on JuliaSyntax, the Markdown heading path, the field-of-a-constant node
`ARGS_FORM.statement` that §4.5 needs, `reanchor` by node and by quote); `src/ConfigIO.jl`; `src/Engine/Guard.jl` — clauses
1, 2, 4 and 5 only, since clause 0 needs `Catalogue.GENERATED` and a generator and clause 3 needs a `Rule` call to exist,
both Phase 2; `src/CLI/Docfix.jl`; a two-field `.gbg/config.jl` here and a `bin/gbg` that accepts either config file and
**refuses rather than falling back** when it cannot read one, printing its version and the checkout it resolved [the old
shim, finding no config, execs the dev checkout silently]; `test/{guard,anchors,architecture}.jl`, of which
`test/architecture.jl` holds `LAYERS` (new files with their module rank) and `LEGACY` (the old ones) and fails if a file is
in neither, if a `LAYERS` file references a module above its rank, if anything under `Engine`, `Render` or `ext/` names
`Orchestration`, `.gbg/runs`, the question store or `settled.jl`, if `LEGACY` grew, or if this package's rule set is
non-empty, its `docs/make.jl` does not call `Documenter.makedocs` plainly, or `.claude/skills/` here is non-empty [three
lines of program instead of a promise not to point the tool at itself early; they leave in Phase 8]. The fixture's scratch
moves into `mktempdir()` [it grew to 61,057 directories and stopped Dropbox syncing]. **Owner:** none, but `gbg install` on
the second host is his to run before he uses `gbg` there.
**Gate** `bash -e -o pipefail -c 'tools/floor.sh && test ! -e fixture/.tmp && ! git grep -qE "\"\.tmp\"" -- src test'` — `test/guard.jl` holds a breaking and a complying example per covered clause of §4.2, the design's three named cases included, and asserts that `gbg docfix commit` over a planted code edit in a scratch clone returns 1 and leaves `git status` unchanged; `test/anchors.jl` shows `BY_NODE`, `BY_QUOTE` and `OUTDATED`.

### Phase 2 — Catalogue, Engine, Render and the verbs (35 commits, 5 sessions)
**Ends with** a program that can run a rule over a package, generate every file that wires one, and compare what it generated
— no package wired yet. **Depends on** Phase 1. **Creates** `src/Catalogue.jl`: `RULES`, the three `AlwaysOn` values of §3,
`GENERATED`, and `doc(x)` with the `@doc doc(x) x` convention, the one-more-backtick fencing rule and the rule that every
docstring in the module comes from such a call and matches the source. Also `src/Engine/{Checks,Harness}.jl` with the reader
for `Config.rules` (a package's own `PatternRule`s); `src/Render.jl` (pin, policy, gitignore, CI, hook, pages, report, wiring
check); Guard clause 0, regenerated by `gbg docfix commit` and handed to `Guard` as an argument [§5.1 forbids `Engine`
calling `Render`]; `ConfigIO.validate` with §9's three exit-2 refusals (unknown target, missing reason, a switch against an
always-on rule); the verbs `init`, `sync`, `check --wiring`, `bump` (§11: it runs the new checks first and exits 1 with
counts per new rule, changing nothing) and `release`; the Documenter extension rewritten; `test/{rules,conversion,wiring}.jl`
and `test/architecture.jl`'s whole-table test of §3 against `ALWAYS_ON`; a `docs/src/` page per landed module. **Deletes**
`schema/` (2,690) with `CLI/Schema.jl`, the old `Doctor`, `Consolidate`, `Selftest`, `Sync` and `Init`, `templates/`,
`.gbg/{exemptions.toml,managed.json,hats/}` and the tests of those, editing `docs/make.jl` and `docs/src/api/*.md` in the
same commits. This package's `.gbg/policy/` is regenerated here — converted rules from `Catalogue.RULES`, the rest from the
tracked `policy/*.md`, the outstanding count at its head — so the rulebook every session here loads is never an orphan.
**Owner:** none.
**Gate** `bash -e -o pipefail -c 'tools/floor.sh && julia --project test/wiring.jl'` — which builds the fixture in `mktempdir()`, regenerates every `GENERATED` path, flips one byte in each in turn and requires the wiring check to exit 1 each time and 0 on the clean copy.

### Phase 3 — The fifteen always-on rules, and GBGPeriodicFields wired (20 commits, 3 sessions)
**Ends with** PF's documentation build and `Pkg.test()` running the fifteen rules, the pin in both environments, and every
generated file compared against its generator. **Depends on** Phase 2. **Creates** the fifteen rules under `src/Rules/`
(batch a, §6); `Render.pages`, called by PF's `docs/make.jl`, so PF's site shows its rules and any rule it has switched off
with the reason (§9); PF's `.gbg/config.jl`, generated files and pin. **Deletes** each rule's `src/Scans/*.jl` file in the
commit that converts it. **PF is wired with the fifteen on**: its first `gbg check` exits 1, and each rule PF does not yet
satisfy is either fixed — PF's own documentation work, in PF's own commits, **outside this plan's sizes** — or carries a
`Switch` with its reason, which the design provides and PF's site shows. The phase ends when PF's build and tests are green
under whatever switches PF declares, not when PF is clean. What is probably owed: a fence-aware replay of four of the fifteen
over PF's tracked source and documentation gives 55 live hits before the noisier structure rules, and this package's own
**Nothing is written to PF's
`.claude/WORK_QUEUE.md` here**; findings are printed [its `queue-guard.sh` counts every `- [ ]` line with no heading
exclusion, so a written line would hold every later PF session hostage]. **Owner:** decisions 4–6. **Release `v2.0.0-rc.1`**,
then `gbg install` on the second host.
**Gate** `bash -e -o pipefail -c 'tools/floor.sh && tools/floor.sh "$1" && git -C "$1" diff --quiet && test -z "$(git -C "$1" diff --name-only HEAD~1 -- .claude/WORK_QUEUE.md)"' _ "$PF"` — the last two: the build regenerated nothing, and this phase's commits wrote no work-queue line in PF.

### Phase 4 — Questions and answers, then Documentation review end to end on PF (amended 2026-09-21)

**Ends with** the instrument the package exists for: the owner asks, derived readers read PF, findings are collected and
anchored, four fix passes run under the guard, two verifier stages grade them, and he is handed `report.md`, questions he
can answer, and work-queue lines under a heading his hook does not count. **Depends on** Phase 3. The amendment
`docs/proposals/ROADMAP-AMENDMENT-2026-09-20.md` re-grouped this phase after eight adversarial rounds; its §8 records the
owner's answers of 2026-09-21. The phase is five pieces:

- **4a — done** (ten commits from `71993cc`, 2026-09-19/20): the question language and `gbg ask`/`answer`; `Runs`,
  `gbg run` and the one driver, `drivers/run.js`, tracked here (ruled 2026-09-21); the rehearsal; 17 agent-decided rules
  reworded until three blind taggers stopped splitting on them; the readers **derived** from the rules' access and
  discipline tags (`Roles.derive`), the hand-written roles deleted; `--readers bound|open|both`; thirteen rules retired
  on the record and every rule given its cover (a program, a reader, an instruction); fourteen defects of the find half
  fixed; no launch budget; the stage machine by position; agents' files under `.gbg/scratch/<run>/`.
- **4b — the review made whole** (50–70 commits, 6–9 sessions). **Done 2026-09-21**, in fifteen commits:
  the pass stages (fix, blind verifier, diff verifier) graded by a program with the quote rule, `DocFix`
  records, reverts and the four-pass cap; the work-queue lines at close; `gbg docfix commit --finding`;
  `gbg run abandon`; a start refused on a dirty tree and a collect refused when the tree moved under the
  agents; an interrupted run continued by the next session; carry-over; the site built inside the run
  with the withheld reader launched once per page and its verifier given the same page rebuilt; a quote
  placed across the documentation; `Run.model` and sequential launch; `gbg docfix check`'s real checks;
  close's red-build restore; `Render.skill` and the per-instrument skill files; a readers page and an
  instruments page; the glossary's new terms; `Release` off the legacy config. Then the other-copies search; the formula
  rule, which the owner settled by ruling that NO edit inside a math span is automatic (guard clause 6);
  `gbg init`'s refusal to overwrite a file the package wrote itself; and the §5.2-versus-`Model` test.
  **4b is complete**; what was written as its scope, for the record: the fix half of §4.3 — re-anchor before each pass, the
  guarded fix, the other-copies search, the formula-edit rule, `gbg docfix check`'s real checks, the blind and the diff
  verifier with their own output schema, grading, `DocFix` and `Verdict` records, the pass driver and the four-pass cap;
  the guard's clause 3; an interrupted run continued by the next session (§10) and `gbg run abandon`; sequential launch;
  the named careful model recorded on the run; what a reader is given — the withheld reader one built page's article
  body per launch from a site built inside the run, the rendered reader `docs/build`, a verifier its finding's reader's
  bundle; `Render.skill` and `Wire`'s `settled.jl`, `questions.json` and skill, with §11's refusals; a readers page and
  an instruments page; the glossary's new terms; `Release` off the legacy config; the work-queue lines at close;
  carry-over; the switch that keeps the review off this package until Phase 8; and every text this makes false. **Gate**
  — `test/rehearse.jl` over the `gbg run` verbs on a git-initialised copy of the fixture with its site built in the
  test, from reader, fixer and verifier files recorded in one real launch: a review runs to four passes and a fifth is
  refused; a run interrupted with one reader uncollected is continued, that reader alone relaunched, each finding
  collected once; a `DONE` run with findings open after four passes writes one queue line per finding under the
  uncounted heading; a malformed result file is named and `collect` exits 2; a question put at find is in the record at
  close and `gbg answer` reaches it; `HIDES_CODE_DEFECT` becomes a question that passes `Questions.check`; `MADE_WORSE`
  reverts; a moved location comes back `BY_DIFF`; collect exits 2 when a tracked file changed under the readers; a start
  on a dirty tree, and a bug hunt, are refused; close on a red build restores the documentation through a guarded
  commit; a second run carries the first's open findings; every withheld launch names exactly one unit and no source; a
  verifier names its finding's reader's bundle; a guarded commit succeeds while a run is open, with the trailer; nothing
  under `.gbg/runs/` but the record, the report and the open-run files; `test/guard.jl` holds clause 3 in both
  directions; `Wire` refuses to overwrite a skill the package owns.
- **4f — the six disciplines attacked** (three sessions, one commit). **Done 2026-09-21**, in one session:
  seven rounds of eight lenses took the descriptions from thirty-two substantive objections to none — and
  produced six auditors, which the owner ruled were not experts. The six were rewritten as experts with a
  licence to judge appropriateness, accountable through the standard, the alternative and what the stated
  reason leaves unanswered, and beat the seven-round texts in two blind, package-grounded comparisons in
  every field. Adopted by the owner as decision 28; `spectral_numerics` keeps its id; filed as
  `docs/design-record/08-discipline-attack.md`. Before any package declares one.
- **Release `v2.0.0-rc.6`** after 4b and 4f, with a CHANGELOG entry covering everything since rc.5, which holds no
  Phase 4 commit; `docs/PF-WIRING.md` rewritten for it. **Then PF**, in its own session and on its own pin: it proposes
  its disciplines, sets `formalization` and confirms the other three parameters, declares `copies` for its five built
  rationale documents, narrows its `literate` set, bumps, adds the two page entries, and runs the review. PF's legacy
  `.claude` commands stay until Phase 7.
- **4d — scope**. **Done 2026-09-22**: `--scope full|changed`, the base per reader combination — the commit that
  added the last finished run's record with that `readers` value — invalidated by a tool bump or a config or switch
  change since; the diff-to-units mapping per access tag. **Gate**: replayed from recorded files over the fixture copy,
  one edited docstring, one added sibling, one edited notation page, one edited hand page and one edited function body
  produce exactly the set the mapping gives, and nothing else; a paused or `CANNOT_EVALUATE` run is no base; a tool bump
  reads full. `test/scope.jl` holds it. One thing the plan did not foresee: a `.jl` file is DOCSTRINGS and CODE at once,
  so by name an edited body and an edited docstring are one event and the reader the code is kept from would be launched
  for both; the file's docstrings are extracted at the base and at the head and compared.
- **4e — the rule wording study**. **Done 2026-09-22**: whether a rule's text says what deciding it requires,
  MEASURED and not argued — blind taggers are given only the text and their agreement is the result, so it converges on
  nothing and there is nothing to converge. Formerly called an attack on rules, renamed 2026-09-21 because that name
  imports the convergence reading of a method this project has since measured as harmful. Run
  through the one driver with a second output schema; kappa, splits and flags as a program over the round-1 fixtures
  filed under `test/`; a drift between the majority and a rule's tag reported as a proposal that becomes a question.
  **Gate**: the arithmetic over the filed fixtures reproduces round 1 — 0.90 / 0.91, 8 flagged, 3 splits — and
  `test/driver.jl`'s one-driver assertion still holds. The votes of both rounds had never been filed and the four
  numbers rested on a session transcript; they were recovered from it into `test/tagging/`, and `test/study.jl`
  reproduces round 0 (0.74 / 0.93, 9 splits) as well. Over today's rulebook the round proposes exactly one tag change,
  which is the machinery working rather than a defect.

**Owner:** the decisions of the amendment's §6, all answered on 2026-09-21.

### Phase 5 — The rest of the rulebook, and GBGCloudPhysics (amended 2026-09-21)

**Ends with** the rulebook finished — every rule checked by a program, judged by a reader, or an instruction the session
is given (ruled 2026-09-21), and nothing else remaining — a second science package wired, and one machine in the tree.
**Depends on** Phase 4. The coverage sittings the plan foresaw (decisions 9–11) were settled by the owner on
2026-09-22, and Phase 5 builds his answers rather than asking them:

- **The seven git instructions split three ways.** Three are decidable from the FILES and become programs in
  `Pkg.test()`: `CI_MANUAL` (the workflow triggers), `MANIFEST_TRACKED` (the ignore file), `REQUESTS` (a request's
  name and its status paragraph). Three ask about commits and branches — `BRANCH`, `PUSH`, `TRAILER` — and so may
  never run in a build [§5.1: a fresh clone and CI must answer alike]; they become programs in the end-of-turn hook,
  and the rulebook SAYS that a hook check is weaker than a build check, since a hook can be skipped and a failing
  test cannot. `NO_SHIMS` stays an instruction: what counts as a shim is judgement. The earlier "four over the tree"
  was one too many, and this is the correction.
- **The four harness contracts are not fleet law in their present form** (owner: the fleet law is that SOME testing
  exists; its structure, type, size and robustness are the package's). Each states one package's method as though it
  were a floor. They are reworded to bind a package that has DECLARED the capability, which is what their own
  `unchecked_reason` already says, and the wiring of any package's contracts belongs to the phase that touches that
  package, with the owner watching — not to a commit here that turns three builds red at once.
- **A third state, the DEFERRAL.** A switch says a rule does not apply and is an answer; a deferral says a package
  means to meet a rule and has not yet, and is a question with a condition on it. Recording "not yet" as a switch
  buries an intention in a file nobody revisits and publishes "does not apply" where the truth is "owed". A deferral
  declares the rule, records what would close it, is rendered beside the switches on the package's own site and
  printed by a verb, and never fails a build. It is not about testing: any rule a package means to meet later has
  this shape, and today the only honest choices are to switch it off or to fail.
- **The eleven remaining instructions stay rules**, the two `INST` ones included (owner: keep them). They tell a
  session working in any package how to behave, which is what a rule is for; the design holds what the TOOL does.
- **A retired rule says where its content went.** `Catalogue.RETIRED` records an id, a date and a reason, and eleven
  of the thirteen reasons name a design section — but nothing asserts the section exists, and two name a test
  instead. A retired rule now declares one of two fates: MOVED, naming the section that holds it, with a test that
  the section is there; or OBSOLETE, held by nothing because nothing needs to hold it (owner: "a rule could become
  just completely obsolete"). The thirteen already retired are classified in the same commit.
- **Targets and material** (ruled 2026-09-23, built the same day, ahead of the rest of this phase). Agents read two kinds
  of document: a TARGET — a docstring, a hand-written page, a Literate example, the one document `architecture_doc` names —
  which is what a user reads, where a finding may be located and the only thing a fixer is handed; and MATERIAL — the source,
  plus what a package lists in the new config field `material`, empty by default — which a reader may open to judge a target
  and never report on. The other rationale documents are read by nobody unless listed. The site walk keeps only target
  pages; the collect marks a finding located only in material and routes it to the owner, unfixed, in its own section of the
  report; program checks are untouched; a change to a non-target rationale document reaches no reader under `--scope
  changed`. Measured on GBGPeriodicFields' built site: the withheld reader launches over 16 pages (the architecture page
  among them, which the rc.9 walk had dropped with every other copy), and the full reader and each discipline stop being
  handed four documents of ~164k tokens. **Creates** what those answers
say; `gbg release --counts`, which prints for `v2.0.0` alone what still holds it and refuses nothing (ruled 2026-09-16);
`Main.jl` rewritten and the last old verbs; an `HT-WIRING.md` (the disciplines HT may propose — turbulence theory
certainly, and the Fourier discipline it shares with PF); HT wired by HT's own session on the last candidate after 4d.
HT moved here from Phase 7 on the owner's word of 2026-09-21: he wants PF and HT on the package first, and nothing in
the order was a dependency. **Deletes** the third stroke (§7) in full — `Scan.jl`, `Reflection.jl`, `DocLints.jl`,
`HtmlWalker.jl`, `TreeHash.jl`, `CLI/Config.jl`, `CLI/Ledger.jl`, `.gbg/config.toml` here and in the fixture, the
fixture's `.gbg/hats/`, `.gbg/rounds/.keep`, `catalog/scans.toml`, `TestHarness.jl` harvested or wired as answered —
with what reads them: this repository's `docs/make.jl`, the extension's `makedocs(cfg::AbstractDict)` and
`write_public_surface`, `CLI/Self.jl`'s `TreeHash`, `CLI/Main.jl`'s `LedgerError`, `test/{helpers,schemas,config,scans,
treehash,coverage}.jl`, `test/architecture.jl`'s `config.toml` line, `test/runtests.jl`'s legacy includes, the site's
`api/{Reflection,TestHarness,Config}.md` and `guide/install.md`'s `config.toml` lines. `LAYERS` gains
`GBGCodingTools.jl`, `CLI/{Main,Bump,Release,Fleet,Install,Self,Git}.jl` and, if kept, `TestHarness.jl`;
`LEGACY_CEILING` falls to 1 (`Witnesses.jl`), and rests there while Phase 6 is deferred. **`v2.0.0` is cut here.**
**Gate** `bash -e -o pipefail -c 'tools/floor.sh && tools/floor.sh "$1" && tools/floor.sh "$2" && test -z "$(git ls-files -- src/Scans policy catalog .gbg/config.toml .gbg/rounds "fixture/GBG Fixture/.gbg/config.toml" "fixture/GBG Fixture/.gbg/hats" src/Scan.jl src/Reflection.jl src/DocLints.jl src/HtmlWalker.jl src/TreeHash.jl src/CLI/Config.jl src/CLI/Ledger.jl)" && julia --project test/conversion.jl && test "$(gbg release --counts)" = "0"' _ "$PF" "$HT"` — the last a printed count, the checklist's to read, not a refusal.

### Phase 6 — Bug hunt, the code fixer and Change audit (45 commits, 5–6 sessions; on request; deferred 2026-09-21)
Deferred on the owner's word so that the documentation half reaches the four science packages first: it is the largest
remaining phase and nothing before or after it depends on what it builds. Phase 7 now follows Phase 5 directly. What
deferring costs, precisely: this package changes no code until it is built, so a code defect an instrument meets stays
what it is today, a question to the owner; `Witnesses.jl` stays in the tree, so `LEGACY_CEILING` rests at 1 rather than
0; `gbg release` prints neither of its two code lines; and the §3 rows for Bug hunt and Change audit are marked future,
which is how the table test reads them.
**Ends with** the code half: hunters per code area, agents writing failing tests, `gbg run witnesses`,
`test/regressions/escalated/`, the fixer's three-attempt loop on the frozen failing test, and the single audit that follows
an approved fix with its grade. **Depends on** Phase 5 [a hunt without a question store, an answer, an attempt cap and an
audit is the unreviewed-code-change failure the design exists to prevent]. **Creates** the hunt and audit stages in `Runs`,
the two `Instrument` values and their roles, `src/CLI/CodeFix.jl`, `test/hunt.jl`, `escalated/` under the existing
`test/regressions/`, `gbg release`'s two printed lines (open keep-or-revert questions; confirmed failing tests awaiting an
answer), and the extension of the §3 table test to `INSTRUMENTS`, the leak-scan row read as future. `Witnesses.jl` moves into
the witnesses stage; `test/witnesses.jl` goes. **Owner:** none. Its release is a MINOR one, numbered when it is
asked for: deferring it handed `v2.1.0` to Phase 7.
**Gate** `bash -e -o pipefail -c 'tools/floor.sh && julia --project test/hunt.jl'` — over the fixture with a planted defect and recorded agent output: the witness goes failing then passing; the loop stops at three failed attempts and writes a question; an attempt editing the frozen test does not count; a change under `test/` is named first to the audit; `Pkg.test()` does not run `escalated/`; the audit starts once and never after itself.

### Phase 7 — GBGStreamingStatistics, GBGCloudPhysics, and the legacy deletions (40 commits, 6–7 sessions)
**Ends with** all four science packages wired and on one version, and no legacy instruments left in any of them. **Depends
on** Phase 6. **Creates** SS's and CP's `.gbg/`, and a `CP-WIRING.md` (CP's `[extras]`/`[targets]` test declaration becomes a
`test/Project.toml` the pin can land in). **Deletes**, each in its own package's commit and only after a real
documentation review has run there and the owner has read its report: PF's, HT's and SS's legacy instrument directories,
their round folders moving to that package's `docs/design-record/`. **Why it is not three sessions**: two wirings, three full
instrument runs, the fixing each produces, and three owner readings the plan cannot schedule. **Owner:** decision 12. Release
`v2.1.0`.
**Gate** `bash -e -o pipefail -c 'for P in "$@"; do tools/floor.sh "$P"; test -z "$(git -C "$P" ls-files -- .claude/commands .claude/doc-review .claude/audit-changes .claude/bug-hunt)"; done' _ "$PF" "$CP" "$HT" "$SS"`

### Phase 8 — GBGCodingTools as its fifth consumer (20 commits, 3–4 sessions)
**Ends with** the tool checked by itself. The design review that stood here is deferred to Phase 11 (§13). Last on purpose: the machinery has run on four packages, so its own defects
arrive as ordinary findings rather than as the work. **Depends on** Phase 7. **Creates** this package's full `.gbg/config.jl`
— the switches §9 names, its settings, `tool = :dev` — its generated skill and hook, and
`test/switches.jl` (§9's own test: a page built with a rendering fault under this package's switches must fail the build).
`docs/make.jl` here switches to the wrapper and `test/runtests.jl` to `Harness.test`, and the three self-application lines
leave `test/architecture.jl` in that same commit — the one commit that turns self-application on, visibly. **Owner:**
decision 13. Release `v2.2.0`.
**Gate** `bash -e -o pipefail -c 'tools/floor.sh && sh bin/gbg check && julia --project test/switches.jl && ! git grep -q "Documenter.makedocs" -- docs/make.jl'`

### Phase 9 — The leak scan (12 commits, 2–3 sessions, on request)
The design marks this row future (§3), so it is last and only when asked: its rules, the reader of every branch, commit
message and `Manifest.toml` path, the `PUBLICATION` intention, its `Instrument` value, and `Guard.refuse_publication` —
called by every writer of a tracked file (run record, report, question store, settled rulings, work queue) and exiting 2 on
text from a publication run.
**Gate** `bash -e -o pipefail -c 'tools/floor.sh && julia --project test/leak.jl'`, which asserts that a publication run writes no tracked file.

### Phase 10 — The code review (on request; not designed)
Asked for by the owner on 2026-09-21, beside the leak scan: an instrument that reads the CODE of a package for the
classical habits of bad design — duplication as a flag of a missing abstraction, optimization made before its cost
was measured, control flow the field has long advised against, and their kin — from a computer scientist's
perspective and not the physical domain's. It is not the documentation review's architect, who reads the design as
the documentation states it and never the code. Its shape by the design's principles: intention code; whatever a
program can decide is a rule with a check (exact duplication, forbidden constructs), and only the judgement half —
whether a duplication is a missing abstraction or a deliberate specialization — is an agent's; every finding ends as
a question to the owner, since code changes only on his answer. A design decision recorded before it is built; its
row joins §3's table marked future when the decision is taken.

### Phase 11 — The design review (on request; deferred 2026-09-21)
It stood at the end of Phase 8 and the owner moved it here, to reach PF and HT sooner: nothing depends on it, and
deferring it leaves nothing unchecked, because the rulebook's TEXT is 4e's subject and not an attack's. What it would
be (§13): `gbg attack` runs agents over this design, producing proposals that become questions to the owner or are
dismissed with a reason, and writing no tracked file. **Creates** `src/CLI/Attack.jl`.

Two conditions are on it, and both come from a measured failure rather than a preference. It attacks a MECHANISM — a
reader panel, a guard, a lens set — never prose. And every attacker owes a concrete EVADING EXAMPLE: the defect that
gets through, where it sits, and why each part of the mechanism misses it. The one round the deleted machinery ran
worked that way and returned eighteen gaps, two of them fatal, each with a real file and line; the seven rounds of
objections over the six discipline texts converged on nothing useful and narrowed every one of them, which is what
`docs/design-record/08-discipline-attack.md` records.

### Phase 12 — A package's own rules (on request; to study, 2026-09-22)
A question the owner raised and deferred rather than answered: should a package's OWN rules live in the same format
as the fleet's, and be read by the same mechanism? The relevant fact is that the mechanism half exists and does
nothing — a `PatternRule` in a package's config carries a statement, a file set, a pattern and examples, is rendered
onto the switches page, and is executed by NOTHING. A package that moves a live convention into one has traded
enforcement for a promise. One decision settles it: either a package's own rules are first-class, and a `PatternRule`
gets a check and a place in the test run, or they are documentation and should stop looking like rules. Deferred past
`2.0.0` because it changes what a config IS, and Phase 5 is the release.

## 3. Stop anywhere

| Stop after | What the owner has |
|---|---|
| 0 | Today's tooling with the round machinery and its pages gone, the design adopted, the floor green. |
| 1 | In this repository, a program that refuses to commit a code change dressed as a documentation fix — when the session uses `gbg docfix commit` rather than `git commit`. |
| 2 | The engine, the generators and the wiring check, with no package wired and nothing yet enforced. |
| 3 | PF's build and tests run fifteen rules, so what they name cannot return unnoticed — over whatever PF has switched off, with its reasons on its site. |
| 4 | He can ask for a documentation review of PF and get fixed, verified text, a report, and questions he can answer. |
| 5 | The complete rulebook on two science packages, one machine in the tree, released as `2.0.0`. |
| 6 | *(on request)* The code half: hunts that prove defects with failing tests, and graded fixes. |
| 7 | Four science packages on one version, no legacy machinery left. |
| 8 | The tool checked by itself. |

He stops between sessions, not phases: every commit leaves the floor green, so a stop costs a capability, not the tree.

## 4. The fleet

Order: **PF, then HT, then SS, then CP**, set by the owner on 2026-09-21; he may reorder again by whatever he is working
on, since nothing in the order is a dependency — every wiring needs the rulebook and the review, and both exist. PF
first (Phase 3): most active, heaviest documentation, the only one with Literate examples and live doctests. HT second
(Phase 5), because it is the package he works in beside PF and the two share a discipline. SS and CP last (Phase 7). The
earlier order put CP second to prove the config is a config on a package sharing none of PF's habits; that argument is
now Phase 7's to make, and the cost of losing it early is that PF and HT are alike enough for a PF-shaped assumption to
survive both. Wiring writes more than a config: `.gbg/{config.jl,settled.jl,questions.json,policy/*.md}`, the pin in both
environments, `.claude/{settings.json,WORK_QUEUE.md}`, a skill file per instrument, the tooling block in `.gitignore` and
`CLAUDE.md`, the CI workflow files, and `test/regressions/`. **Wiring refuses to overwrite** an existing
`.github/workflows/*`, `.claude/settings.json`, `WORK_QUEUE.md` or a skill of the same name, printing the diff instead [PF
has hand-written workflows, its own settings, a 168-line queue, and a `.claude/commands/bug-hunt.md` a generated skill would
shadow]; unwiring is reverting those commits, after which `gbg` finds no config and refuses. Each package declares its
`Switch`es, `Setting`s, `code_areas`, `normative` documents, build-time copies, the disciplines it declares and, where it
has them, its own `PatternRule`s; a reader or a discipline it needs and the tool lacks is requested from the tooling
session, never written in the package (ruled 2026-09-20).

## 5. Versions and releases

The eleven `v1.0.0-rc.*` tags stay where they are and are never moved. **`1.0.0` is never released**: what those candidates
named does not survive Phase 0, and `Project.toml` names a release that does not exist, so Phase 0 sets it to `2.0.0-DEV` —
MAJOR by any reading, since the config format, the verbs and both entry points change. A candidate is cut at each phase that
changes what a consumer sees: `v2.0.0-rc.1` (Phase 3, the first moment a package can pin anything), `-rc.2` to `-rc.5` (Phases 3 and 4's
first half, cut as PF needed them), `-rc.6` (4b and 4f), `-rc.7` (the question channel, cut 2026-09-21 before PF upgraded), **`v2.0.0` at the end of
Phase 5**, where the rulebook is complete and two packages are wired, then `v2.1.0` (7) and `v2.2.0` (8). A phase on
request is numbered when it is asked for. Until the first candidate no package pins anything, as none does today; this checkout carries `tool = :dev`.
`CHANGELOG.md` gains one MAJOR `## 2.0.0`: rates are not comparable and nothing re-measures them (§12).

## 6. The content conversion, and its ratchet

The register holds 95 ids. Recounted from `policy/RULES.toml`, by family and check: **DOC 40** (19 scan, 11 panel, 2 harness,
8 none); **TEX 17** (13 scan, 1 panel, 3 none); **CIT 5** (3 scan, 1 scan-and-panel, 1 panel); **TEST 12** (5 harness, 2
test, 5 none); **INST 13** (7 harness, 4 test, 2 none); **GIT 7** (3 doctor, 4 none); **API 1** (panel). So 36 rules have
scan checks (over the 44 scan files, several named by two rules), 14 are panel-decided and 22 have no check. Of the 20
harness- and test-checked rules, **ten lose their checker in Phase 0** (`RULE.DOC.BATTERY` and nine `RULE.INST.*`, checked by
`Preflight`, `Passes.grade` or `test/rounds.jl`), and three `RULE.GIT.*` lose theirs with the doctor in Phase 2: thirteen
re-derivations, not harvests.

| Batch | Content | Phase | How it is checked |
|---|---|---|---|
| a | the fifteen always-on: five rendering rules (`TEX.RENDERED_MATH`, `RENDERED_MARKUP`, `CODE_IN_MATH`, `ONE_SPAN`, `SWALLOWED_ESCAPE`), `DOC.TABLE_TOP_LEVEL`, `REF_ABUT`, and eight structure and reflection rules (`ARGS_FORM`, `ARG_BULLET`, `FIELDS`, `SHAPE`, `SENTENCE_OPENER`, `REGISTER`, `ARGCOV`, `SIGNATURE_FIDELITY`) | 3 | `TextExample`s, `ModuleExample`s, and `SiteExample`s for the two rendering rules with built-site scans |
| b | the other 9 scan-checked `RULE.DOC.*` | 5 | `TextExample`s, `ModuleExample`s, one `SiteExample` set for `API_GROUPING` |
| c | the other 8 scan-checked `RULE.TEX.*` | 5 | `TextExample`s |
| d | the 4 scan-checked `RULE.CIT.*`; `NO_INACCESSIBLE` split into the reader's rule and `RULE.CIT.RESOLVES` — done 2026-09-21 | 4 | `TextExample`s; the resolving rule is `network = true`, runs only under `gbg check --network`, and is tested on a canned resolver |
| e | the 5 question-language rules | 4 | `QuestionExample`s |
| f | the 10 surviving harness- and test-checked rules (`DOC.BUILD_VERIFY`, seven `RULE.TEST.*`, `INST.WITNESS`, `NO_TRUNCATION`) | 5 | `ModuleExample`s against `Engine.Harness`, `makedocs` and `Render.report` |
| g | the readers DERIVED from tags on the rules (`Roles.derive`), the hats deleted — done 2026-09-20 | 4 | `test/readers.jl`: every tagged rule on exactly one bound reader or a named gap |
| h | the 10 rules whose checker Phase 0 deleted: eight retired as dead machinery and two (`DOC.BATTERY`, `INST.NO_TRUNCATION`) kept as instructions — done 2026-09-21 | 4 | `Catalogue.RETIRED`, read by `test/conversion.jl` and `known_ids` |
| i | the 3 `RULE.GIT.*` doctor rules and the 22 with no check: every one is now an instruction to the session or a reader's, by cover (ruled 2026-09-21); whether the git ones get programs is Phase 5's remaining question | 4–5 | `test/conversion.jl`: every rule has one of the three covers |

15 + 9 + 8 + 4 (the scan-checked 36) + 10 + 14 + 10 + 3 + 22 = 95: every id of the register is in exactly one batch, and
batch e's five question-language rules are new in the design, outside it. One commit per batch of 8 to 12 rules, each
moving the paragraph into `statement` and `why` and the scan body into `ProgramCheck.run`, writing the examples, and
deleting that `src/Scans/*.jl` file.

**Examples are per clause, and the largest single piece of work here.** §5.2 requires a breaking example per clause and a
complying text differing as little as possible; 71 of the 95 statements are multi-clause, so for ~50 program-checked rules at
~2.5 clauses each the corpus is **on the order of 280 examples, of which 78 are harvested** from the fixture; the other ~200
are written by hand, and that writing — not the check bodies — sets the size of Phases 3 and 5. `test/rules.jl` materialises
every example and requires a breaking and a complying one per distinct `clause`.

**The ratchet.** `RULES` is a plain vector: an unconverted rule is absent, so nothing runs it and nothing fails; completeness
is separate. The 95-id register is frozen in Phase 0 as `RULES-v1.toml`, and `test/conversion.jl` requires every id in it to
be converted with its clauses covered, listed as retired with a reason **in that test file**, or counted in an **allowance**
written there — starting at 95, lowered by each batch commit, never raised, zero in Phase 5. Until then every wired package's
generated `.gbg/policy/*.md` carries the outstanding count at its head and renders the unconverted rules from the tracked
`policy/*.md` [a session must never be told the rulebook is complete when it is not]. One adapter, `Checks.from_scan` (~60
lines), carries a harvested body into `ProgramCheck.run`'s signature and dies with the last batch. Schemas are deleted, not
converted: the types are the schema.

## 7. What is deleted, and when

Three strokes; nothing goes before its content is harvested, and a content-bearing file is moved to `docs/design-record/`
rather than deleted when it stops being live.

| Stroke | Phase | What goes | Lines |
|---|---|---|---|
| 1 | 0 | the round machinery (filed as `machinery-v1/`), its three test files, every reader corrected in the same commit; the closed rounds, instruments, hats, lanes, seeds, attacks and `carried.toml` move to the design record; the round pages of the site | ~6,200 |
| 2 | 2 | `schema/` and `Schema.jl`, `Doctor`, `Consolidate`, `Selftest`, the old `Sync` and `Init`, `templates/`, `.gbg/{exemptions.toml,managed.json,hats}` and their tests | ~5,100 |
| 3 | 5 | the old engines — `Scan.jl`, the last of `src/Scans/`, `Reflection.jl`, `DocLints`, `HtmlWalker`, `TreeHash`, `catalog/scans.toml` — with the old `Config`, `Ledger` and the last old verbs | ~2,900 |

The first stroke has no user left once its readers are corrected in the same commits — the owner has stopped running rounds
here, and PF's and HT's instruments never load this package — but it is not free: Phase 4 re-derives its behaviour, which is
why it is filed rather than dropped. The third waits because every rule using those engines must be converted first. Seeding,
recall and the ledger survive in no form [recall measured nothing after the seed-delivery defect; an exemption is a
`Switch`].

## 8. The owner's decisions

| # | Question | Phase | Exhibit | Recommendation | If the answer is late |
|---|---|---|---|---|---|
| 1 | Do we adopt the new architecture and this plan together, now? | 0 | both documents | Yes — the plan is written against it | Nothing starts. |
| 2 | Should the unreleased 1.0.0 line be abandoned and the next release called 2.0.0? | 0 | the eleven candidate tags | Yes — every public surface changes | Phase 0 lands without the bump; Phase 3 cannot cut a candidate. |
| 3 | Should the release checklist stop asking for a recall number? | 0 | the checklist line | Yes — nothing measures it any more | The checklist keeps asking for a number no program produces. |
| 4 | Is the most active science package the right one to protect first? | 3 | the four packages, with sizes and recent commits | Yes — heaviest documentation, most readers | Phase 3 stops after the rules; no package is wired. |
| 5 | Are these fifteen the rules every package must always satisfy? | 3 | the fifteen statements, each with its finding count in that package | Yes to all fifteen — they catch text that renders wrongly, and docstring structure | The phase cannot end: nothing is wired until the set is fixed. Chosen, the set can never be switched off in any package — changing it later is a MAJOR release and a bump — so it ships switchable until two packages have shown their counts. |
| 6 | How much of his own documentation does he want cleaned before the rest is switched off with a reason? | 3 | the finding list, by rule, for that package | Fix the two smallest, switch the rest off with reasons, revisit at the next release | The phase cannot end: that package's build stays red until each rule is fixed or switched off. |
| 7 | ~~How many agents may one run of each instrument launch?~~ Superseded 2026-09-21: no launch ceiling; the design bounds launches. Every reader on the careful model (2026-09-20). | 4 | — | — | — |
| 8 | ~~Do the leftovers of a spent review go into his own list?~~ Moot 2026-09-19: a run cut short is unfinished and continued, not filed; a finished run's leftovers go to both places as before. | 4 | — | — | — |
| 9 | ~~For each rule with no check today: keep it with the reason, or retire it?~~ Answered 2026-09-21 by the three covers: every rule is a program's, a reader's or an instruction; thirteen retired. What remains is whether the seven git instructions get programs. | 5 | the seven statements and what a program could see | as Phase 5 says | Those seven stay instructions. |
| 10 | ~~For each rule a reading panel decides: still meaning, derivation or reading order?~~ Answered another way: the tagging study says what each rule needs; the `WhyAgent` on the 14 agent checks is metadata a reader is not shown. | 5 | — | — | — |
| 11 | Should the rules about commits and branches be checked by a program at all, now that they are instructions? | 5 | the three statements and what the end-of-turn hook could see | Give all three the hook check | They stay instructions; nothing holds. |
| 12 | May a package's old review machinery be deleted now that a real review has run there? | 7 | that package's report and its legacy directories | Yes, once he has read the report | Both machineries stay there; the phase cannot end. |
| 13 | Should the tool be wired to check itself? | 8 | its own switches and settings | Yes, last, so its defects arrive as ordinary findings | The tool stays unchecked by its own rules; nothing else blocks. |

## 9. Risks

| Risk | Counter |
|---|---|
| **The rebuild stalls half-done and the owner has neither machine.** | Every phase from 3 ends with a tag a package pins; nothing old is deleted before its replacement is green; PF's and IT's legacy instruments stand until a real review has run in their package. |
| Phase 4 is eleven to fifteen sessions and sits between him and the capability the package exists for. | Cut at the design's own handoffs, one commit group per stage, each with its assertion in `test/rehearse.jl`, which runs the whole instrument with no model call. |
| Wiring PF exposes an unbounded documentation cleanup in his most active package. | The gate never requires PF to be clean: a rule PF does not satisfy is fixed as PF's own work or switched off with a reason on its site, and the fifteen ship switchable until two packages have shown their counts. |
| A generated file overwrites something he wrote by hand — CI, settings, the queue, a command; or his two hosts drift and the stale one fails silently. | Wiring refuses to overwrite those four and prints the diff, and unwiring is reverting the wiring commits; Phase 1 makes the shim refuse rather than fall back and print the checkout it resolved, and every release phase ends with `gbg install` on the other host, named as his action. |
| `Guard.classify` decides what is committed, and has no ancestor here. | An example per covered clause in both directions is Phase 1's gate — three phases before any fixer can call it; every guarded commit is on `master` and pushed. |
| Self-application returns by the back door before Phase 8. | Three lines of `test/architecture.jl` from Phase 1: the rule set here stays empty, `docs/make.jl` calls Documenter plainly, `.claude/skills/` stays empty — removed in the one Phase 8 commit that turns it on. |
| The 280-example corpus is the quiet majority of the work and could double; and the agent-decided instruments cannot be shown to work at all. | Examples are counted in clauses, not scans, and `test/rules.jl` refuses a rule whose clauses are uncovered, so that cost shows per batch. For the agents there is no counter — the design's declared limit (§12) — beyond building the program-decided half first. |

## 10. History

- The adopted design took the name `docs/ARCHITECTURE.md` and this plan took `IMPLEMENTATION.md`, in Phase 0; the config declares the
  architecture normative, so §4.2 makes it code. The old pair (2,782 and 1,076 lines, its Phases 0–3 built and 4–8 never run)
  goes to `docs/design-record/` with dated headers, and that directory (28 files, otherwise untouched) grows: `machinery-v1/`
  (4,493 lines, Phase 4's named source), `rounds-v1/` (15 closed rounds), `instruments-v1/` (3,104), `roles-v1/` (318),
  `attacks-v1/`, `seeds-v1/`, `carried-v1.toml`, `policy-v1/` (1,396, Phase 5) and `RULES-v1.toml` (686) — named by no file
  set, so no rule runs on it and no agent reads it.
- `carried-v1.toml` holds two findings: the minor at `Passes.jl` and `Demote.jl`; the major at the three Workflow schemas,
  `schema/finding.schema.json` (deleted in Phase 2) and `Rounds.jl`, whose substance — a per-agent output schema looser than
  what the banking step enforced — is a live lesson for the agent output schemas Phase 4 generates, so it is quoted in that
  phase's commit rather than closed.
- `.claude/WORK_QUEUE.md` (113 lines) has 98 done items and **no open ones**. It stays with its end-of-turn hook; Phase 0
  trims the closed items to one summary line, and from Phase 4 each run writes its leftovers under the uncounted heading,
  here and in each wired package once its hook is regenerated. `CHANGELOG.md` keeps every entry; `.gbg/runs/` is a new
  directory.

## 11. Size

| Phase | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | Total |
|---|---|---|---|---|---|---|---|---|---|---|
| Commits | 15 | 14 | 35 | 20 | 10 + 69–89 | 25–35 | 45 | 40 | 20 | **293–323** |
| Sessions | 2–3 | 2–3 | 5 | 3 | 11–15 | 4–6 | 5–6 | 6–7 | 3–4 | **41–52** |

Phase 9 adds 12 commits and 2–3 sessions when asked for; PF's cleanup (Phase 3) is his own package work, sized by him.
The first capability in a science package arrives at session 12 to 14. About a third of this work has no precedent here —
five consumer migrations, none ever done, and `Guard`, `reanchor`, `Runs` and `Agents` — and the one calibration available,
12,032 source and 2,732 test lines built in 277 commits over six working days, measures the typing, not the judgement, over
commits that wired zero consumers.

## What writing this plan settled in the design

Five gaps in the design came out of writing the plan; the owner ruled on all five on 2026-09-17 and
they are now in that document, not here. They are listed only so a reader of this plan knows where its
assumptions come from.

- The change guard takes the generator's current output as an argument, supplied by the verb that holds the
  generators, so `Engine` never reaches `Render` (§4.2, §5.1) — which is why Phase 2, not Phase 1, carries
  clause 0.
- A rule is retired by removing its value, on the record: the question names the id and the reason, the
  changelog records it, and the id is never reused (§13) — which is what batches h and i rest on (§6).
- The always-on set ships switchable until two packages have shown their counts; fixing it is a MAJOR release
  (§9) — the recommendation in decision 5 (§8).
- `gbg init` never overwrites a file the package wrote itself; it prints the difference and exits 1 (§11) — the
  refusal §4 relies on when wiring PF.
- The design review writes no tracked file; its proposals reach the owner as questions (§13) — which is why
  deferring it to Phase 11 costs nothing that another phase has to carry.
