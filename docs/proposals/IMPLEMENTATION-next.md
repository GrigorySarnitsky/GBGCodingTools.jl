# GBGCodingTools — the implementation plan

This is the migration order from the package as it stands to the target design, `docs/proposals/ARCHITECTURE-next.md`, which
is normative: nothing here re-argues it. Both are still proposals, so this one is `docs/proposals/IMPLEMENTATION-next.md`;
Phase 0 adopts the pair together.

Terms. A **session** is one Claude Code conversation with a finite context. The **floor** is the two commands every commit
passes — `julia --project -e 'using Pkg; Pkg.test()'` and `julia --project=docs docs/make.jl`, each exit 0. Phase 0 writes
them into a tracked `tools/floor.sh` (`#!/bin/sh`, `set -e`, run in the directory its one optional argument names), and every
gate calls that file by path [a variable inside `bash -c '…'` is unset in the new shell and an exported one holding `&&` is
not re-parsed as an operator, so a gate written that way passes without running anything]; no gate uses a pipeline [a pipe's
exit code can hide a match]. A gate that runs in a science package takes that package's path as an argument (`"$1"`, `"$@"`)
supplied after the quoted command, never as a variable inside it; `$PF`, `$CP`, `$IT` and `$SS` stand for those paths, each
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
| `instruments/` (4 protocols, 4 schemas, 12 JavaScript files); `catalog/hats/` (22), `lanes/` (3), `models.toml` (318) | 3,422 | `Instrument` values, one driver; ~40 `AgentRole`s | prose into fields, the scripts into one driver; briefs verbatim into `description` |
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
`docs/ROADMAP.md` records 80 docstrings in the prose form for one of the fifteen. **Nothing is written to PF's
`.claude/WORK_QUEUE.md` here**; findings are printed [its `queue-guard.sh` counts every `- [ ]` line with no heading
exclusion, so a written line would hold every later PF session hostage]. **Owner:** decisions 4–6. **Release `v2.0.0-rc.1`**,
then `gbg install` on the second host.
**Gate** `bash -e -o pipefail -c 'tools/floor.sh && tools/floor.sh "$1" && git -C "$1" diff --quiet && test -z "$(git -C "$1" diff --name-only HEAD~1 -- .claude/WORK_QUEUE.md)"' _ "$PF"` — the last two: the build regenerated nothing, and this phase's commits wrote no work-queue line in PF.

### Phase 4 — Questions and answers, then Documentation review end to end on PF (70 commits, 9–12 sessions)
**Ends with** the instrument the package exists for: the owner asks, agents read PF, findings are collected and anchored,
four fix passes run under the guard, two verifier stages grade them, and he is handed `report.md`, questions he can answer,
and work-queue lines under a heading his hook does not count. **Depends on** Phase 3. **First group, the way to reach him** —
a review has three exits that need it (a possible code defect, a formula edit without agreement, the keep-or-revert at
close): `Engine/Questions.jl`, the five question-language rules (batch e), `src/CLI/Answer.jl`, `.gbg/settled.jl` and its
reader, `test/questions.jl`. **Then** `src/Orchestration/{Agents,Runs}.jl` (the stage machine, the budget, the relaunch-once
rule, `Runs.reanchor`'s git step, collect's remap of a location in a declared build-time copy to its tracked source, close's
two programs), the review's `Instrument` value and its `AgentRole`s (batch g), `Render.report`, `src/CLI/Run.jl`, the rest of
`Docfix` (§4.3 steps 1–4), one fixed Workflow driver replacing eleven scripts, `Render.hook` writing each package's
end-of-turn hook with the uncounted heading **before** any leftover line is written, and `test/{rehearse,driver}.jl`;
`test/anchors.jl` is re-pointed at `Runs.reanchor` and gains the `BY_DIFF` case. **Why it is this large**: it re-derives the
behaviour of the 4,357 lines Phase 0 filed under `machinery-v1/`, against a design that changed every stage; its commits cut
at the design's own handoffs, one group per stage. **Owner:** decisions 7 and 8. Release `v2.0.0-rc.2`.
**Gate** `bash -e -o pipefail -c 'tools/floor.sh && julia --project test/rehearse.jl && julia --project test/driver.jl'` — the rehearsal drives every stage over the fixture from result files recorded in one real Workflow launch (the launch is the session's, since `node` is not installed here), asserting: a stage out of order exits 2; collect exits 2 when a tracked file changed under it; a malformed result file is relaunched once then named; re-anchoring runs before each pass and each verifier stage; a `HIDES_CODE_DEFECT` verdict and a `maybe_code` finding each produce a question that passes `Questions.check`; `MADE_WORSE` reverts; a budget-spent run writes its leftovers under the uncounted heading and the hook still lets the turn end.

### Phase 5 — The rest of the rulebook, and GBGCloudPhysics (45 commits, 5–7 sessions)
**Ends with** all 95 ids converted, re-checked or retired with a reason, a second science package wired, and one machine in
the tree. **Depends on** Phase 4. **Creates** batches b, c, d, f, h and i (§6); `gbg check --network` [the citation
cross-check is the one check the design keeps out of every build]; `Main.jl` rewritten; CP's `.gbg/`. **Deletes** the third
stroke (§7): the remaining `src/Scans/*`, `Scan.jl`, `Reflection.jl`, `DocLints`, `HtmlWalker`, `TreeHash`,
`catalog/scans.toml`, the old `Config` and `Ledger`, the last old verbs, three test files and the conversion adapter;
`policy/` moves to `docs/design-record/policy-v1/` in the commit where the ratchet reaches zero and `Render.policy` takes
over. `LEGACY` is empty and `test/architecture.jl` covers `src/` whole. **Owner:** decisions 9–11. **`v2.0.0` is cut here** —
the rulebook is complete and two packages are wired.
**Gate** `bash -e -o pipefail -c 'tools/floor.sh && tools/floor.sh "$1" && tools/floor.sh "$2" && test -z "$(git ls-files -- src/Scans policy catalog)" && julia --project test/conversion.jl' _ "$PF" "$CP"` — the last at an allowance of zero (§6).

### Phase 6 — Bug hunt, the code fixer and Change audit (45 commits, 5–6 sessions)
**Ends with** the code half: hunters per code area, agents writing failing tests, `gbg run witnesses`,
`test/regressions/escalated/`, the fixer's three-attempt loop on the frozen failing test, and the single audit that follows
an approved fix with its grade. **Depends on** Phase 5 [a hunt without a question store, an answer, an attempt cap and an
audit is the unreviewed-code-change failure the design exists to prevent]. **Creates** the hunt and audit stages in `Runs`,
the two `Instrument` values and their roles, `src/CLI/CodeFix.jl`, `test/hunt.jl`, `escalated/` under the existing
`test/regressions/`, `gbg release`'s two printed lines (open keep-or-revert questions; confirmed failing tests awaiting an
answer), and the extension of the §3 table test to `INSTRUMENTS`, the leak-scan row read as future. `Witnesses.jl` moves into
the witnesses stage; `test/witnesses.jl` goes. **Owner:** none. Release `v2.1.0`.
**Gate** `bash -e -o pipefail -c 'tools/floor.sh && julia --project test/hunt.jl'` — over the fixture with a planted defect and recorded agent output: the witness goes failing then passing; the loop stops at three failed attempts and writes a question; an attempt editing the frozen test does not count; a change under `test/` is named first to the audit; `Pkg.test()` does not run `escalated/`; the audit starts once and never after itself.

### Phase 7 — GBGIsotropicTurbulence, GBGStreamingStatistics, and the legacy deletions (40 commits, 6–7 sessions)
**Ends with** all four science packages wired and on one version, and no legacy instruments left in any of them. **Depends
on** Phase 6. **Creates** IT's and SS's `.gbg/`. **Deletes**, each in its own package's commit and only after a real
documentation review has run there and the owner has read its report: PF's, IT's and SS's legacy instrument directories,
their round folders moving to that package's `docs/design-record/`. **Why it is not three sessions**: two wirings, three full
instrument runs, the fixing each produces, and three owner readings the plan cannot schedule. **Owner:** decision 12. Release
`v2.1.1`.
**Gate** `bash -e -o pipefail -c 'for P in "$@"; do tools/floor.sh "$P"; test -z "$(git -C "$P" ls-files -- .claude/commands .claude/doc-review .claude/audit-changes .claude/bug-hunt)"; done' _ "$PF" "$CP" "$IT" "$SS"`

### Phase 8 — GBGCodingTools as its fifth consumer, and the design review (20 commits, 3–4 sessions)
**Ends with** the tool checked by itself and `gbg attack` available (§13: agents over the design, producing proposals that
become questions or are dismissed with a reason). Last on purpose: the machinery has run on four packages, so its own defects
arrive as ordinary findings rather than as the work. **Depends on** Phase 7. **Creates** this package's full `.gbg/config.jl`
— the four switches §9 names, its two settings, `tool = :dev` — its generated skills and hook, `src/CLI/Attack.jl`, and
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

## 3. Stop anywhere

| Stop after | What the owner has |
|---|---|
| 0 | Today's tooling with the round machinery and its pages gone, the design adopted, the floor green. |
| 1 | In this repository, a program that refuses to commit a code change dressed as a documentation fix — when the session uses `gbg docfix commit` rather than `git commit`. |
| 2 | The engine, the generators and the wiring check, with no package wired and nothing yet enforced. |
| 3 | PF's build and tests run fifteen rules, so what they name cannot return unnoticed — over whatever PF has switched off, with its reasons on its site. |
| 4 | He can ask for a documentation review of PF and get fixed, verified text, a report, and questions he can answer. |
| 5 | The complete rulebook on two science packages, one machine in the tree, released as `2.0.0`. |
| 6 | The code half: hunts that prove defects with failing tests, and graded fixes. |
| 7 | Four science packages on one version, no legacy machinery left. |
| 8 | The tool checked by itself, and a design review he can run. |

He stops between sessions, not phases: every commit leaves the floor green, so a stop costs a capability, not the tree.

## 4. The fleet

Order: **PF, then CP, then IT, then SS**; he may reorder by whatever he is working on. PF first (Phase 3): most active,
heaviest documentation, the only one with Literate examples and live doctests. CP second (Phase 5): sharing none of PF's
habits and holding no legacy machinery, it proves the config is a config. IT and SS last (Phase 7): both are mostly
deletions. Wiring writes more than a config: `.gbg/{config.jl,settled.jl,questions.json,policy/*.md}`, the pin in both
environments, `.claude/{settings.json,WORK_QUEUE.md}`, a skill file per instrument, the tooling block in `.gitignore` and
`CLAUDE.md`, the CI workflow files, and `test/regressions/`. **Wiring refuses to overwrite** an existing
`.github/workflows/*`, `.claude/settings.json`, `WORK_QUEUE.md` or a skill of the same name, printing the diff instead [PF
has hand-written workflows, its own settings, a 168-line queue, and a `.claude/commands/bug-hunt.md` a generated skill would
shadow]; unwiring is reverting those commits, after which `gbg` finds no config and refuses. Each package declares its
`Switch`es, `Setting`s, `code_areas`, `normative` documents, build-time copies and, where it has them, its own `PatternRule`s
and `AgentRole`s.

## 5. Versions and releases

The eleven `v1.0.0-rc.*` tags stay where they are and are never moved. **`1.0.0` is never released**: what those candidates
named does not survive Phase 0, and `Project.toml` names a release that does not exist, so Phase 0 sets it to `2.0.0-DEV` —
MAJOR by any reading, since the config format, the verbs and both entry points change. A candidate is cut at each phase that
changes what a consumer sees: `v2.0.0-rc.1` (Phase 3, the first moment a package can pin anything), `-rc.2` (4), **`v2.0.0`
at the end of Phase 5**, where the rulebook is complete and two packages are wired, then `v2.1.0` (6), `v2.1.1` (7), `v2.2.0`
(8). Until the first candidate no package pins anything, as none does today; this checkout carries `tool = :dev`.
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
| d | the 4 scan-checked `RULE.CIT.*`; `NO_INACCESSIBLE` splits into a program rule and an agent rule (§7) | 5 | `TextExample`s; the cross-check rule is `network = true` and runs only under `gbg check --network` |
| e | the 5 question-language rules | 4 | `QuestionExample`s |
| f | the 10 surviving harness- and test-checked rules (`DOC.BUILD_VERIFY`, seven `RULE.TEST.*`, `INST.WITNESS`, `NO_TRUNCATION`) | 5 | `ModuleExample`s against `Engine.Harness`, `makedocs` and `Render.report` |
| g | 22 hats and 3 lane catalogues into ~40 `AgentRole`s; the 14 panel rules into `AgentCheck`s with their `WhyAgent` value | 4 | a test that every id in `rules` exists and every agent-checked rule belongs to exactly one role |
| h | the 10 rules whose checker Phase 0 deleted: a new check against `Runs`, or retirement with a reason | 5 | `ModuleExample`s against `Orchestration`, or a retirement line in `test/conversion.jl` |
| i | the 3 `RULE.GIT.*` doctor rules and the 22 with no check: an `unchecked_reason`, a new program check, or retirement | 5 | no examples where there is no check; the owner's answers decide (§8) |

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
here, and PF's and IT's instruments never load this package — but it is not free: Phase 4 re-derives its behaviour, which is
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
| 7 | How many agents may one run of each instrument launch? | 4 | past rounds' launch counts and token totals | Economy for readers, full strength for verifiers | No real review runs; the rehearsal uses a placeholder. |
| 8 | Do the leftovers of a spent review go into his own list, or only into the run record? | 4 | one report and one queue as they would look | Both, under a heading the end-of-turn guard does not count | The review runs but its leftovers have nowhere to go. |
| 9 | For each rule with no check today: keep it with the reason it cannot be checked, or retire it? | 5 | the statement and its history, eight at a sitting | Per item, default for anything unanswered: keep, reason drafted | The allowance floors above zero and `v2.0.0` waits. |
| 10 | For each rule a reading panel decides today: is it still a matter of meaning, derivation or reading order? | 5 | the statement and the role that would check it, eight at a sitting | Per item, the drafted reason as the default | The same. |
| 11 | Should the rules about commits and branches be checked by the tool at all? | 5 | the three statements and what a program could see | Retire two; keep the manifest one as a wiring check | Those three ids hold the allowance above zero. |
| 12 | May a package's old review machinery be deleted now that a real review has run there? | 7 | that package's report and its legacy directories | Yes, once he has read the report | Both machineries stay there; the phase cannot end. |
| 13 | Should the tool be wired to check itself? | 8 | its own switches and settings | Yes, last, so its defects arrive as ordinary findings | The tool stays unchecked by its own rules; nothing else blocks. |

## 9. Risks

| Risk | Counter |
|---|---|
| **The rebuild stalls half-done and the owner has neither machine.** | Every phase from 3 ends with a tag a package pins; nothing old is deleted before its replacement is green; PF's and IT's legacy instruments stand until a real review has run in their package. |
| Phase 4 is nine to twelve sessions and sits between him and the capability the package exists for. | Cut at the design's own handoffs, one commit group per stage, each with its assertion in `test/rehearse.jl`, which runs the whole instrument with no model call. |
| Wiring PF exposes an unbounded documentation cleanup in his most active package. | The gate never requires PF to be clean: a rule PF does not satisfy is fixed as PF's own work or switched off with a reason on its site, and the fifteen ship switchable until two packages have shown their counts. |
| A generated file overwrites something he wrote by hand — CI, settings, the queue, a command; or his two hosts drift and the stale one fails silently. | Wiring refuses to overwrite those four and prints the diff, and unwiring is reverting the wiring commits; Phase 1 makes the shim refuse rather than fall back and print the checkout it resolved, and every release phase ends with `gbg install` on the other host, named as his action. |
| `Guard.classify` decides what is committed, and has no ancestor here. | An example per covered clause in both directions is Phase 1's gate — three phases before any fixer can call it; every guarded commit is on `master` and pushed. |
| Self-application returns by the back door before Phase 8. | Three lines of `test/architecture.jl` from Phase 1: the rule set here stays empty, `docs/make.jl` calls Documenter plainly, `.claude/skills/` stays empty — removed in the one Phase 8 commit that turns it on. |
| The 280-example corpus is the quiet majority of the work and could double; and the agent-decided instruments cannot be shown to work at all. | Examples are counted in clauses, not scans, and `test/rules.jl` refuses a rule whose clauses are uncovered, so that cost shows per batch. For the agents there is no counter — the design's declared limit (§12) — beyond building the program-decided half first. |

## 10. History

- `ARCHITECTURE-next.md` → `docs/ARCHITECTURE.md` and this file → `IMPLEMENTATION.md` in Phase 0; the config declares the
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
| Commits | 15 | 14 | 35 | 20 | 70 | 45 | 45 | 40 | 20 | **304** |
| Sessions | 2–3 | 2–3 | 5 | 3 | 9–12 | 5–7 | 5–6 | 6–7 | 3–4 | **40–50** |

Phase 9 adds 12 commits and 2–3 sessions when asked for; PF's cleanup (Phase 3) is his own package work, sized by him.
The first capability in a science package arrives at session 12 to 14. About a third of this work has no precedent here —
five consumer migrations, none ever done, and `Guard`, `reanchor`, `Runs` and `Agents` — and the one calibration available,
12,032 source and 2,732 test lines built in 277 commits over six working days, measures the typing, not the judgement, over
commits that wired zero consumers.

## What writing this plan settled in the design

Five gaps in `ARCHITECTURE-next.md` came out of writing the plan; the owner ruled on all five on 2026-09-17 and
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
  Phase 8 carries it in three commits and nothing else changes.
