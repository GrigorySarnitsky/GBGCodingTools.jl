# Survey: `/bug-hunt` and `/audit-changes` in PF and IT

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.


All paths are under `/home/grigory/Dropbox/Research and Teach/Isotropic Turbulence/`. `PF` = `GBGPeriodicFields`, `IT` = `GBGIsotropicTurbulence`. Line numbers are from `cat -n` of the files as they stand today (2026-09-06). Every file named in the brief was read in full.

**Siblings:** `GBGStreamingStatistics` has `.claude/commands/{check-consistency.md, check-docs.md, check-consistency/{consolidate.py, panel.js}}` and a `.claude/doc-review/` pile — **no bug-hunt, no audit-changes, no `test/regressions/`**. `GBGCloudPhysics` has only `.claude/settings.local.json` — no instruments, no `test/regressions/`. Neither CLAUDE.md mentions witness/bug-hunt/audit-changes. So the survey is a two-package one.

---

## 1. Protocol, per instrument, per package

### 1.1 `/bug-hunt` — PF

**Files:** `PF/.claude/commands/bug-hunt.md` (100 lines), `bug-hunt/hunt.js` (213), `bug-hunt/dismissals.js` (109), `bug-hunt/witnesses.jl` (72), `bug-hunt/MANIFEST.txt`.

**Phases (hunt.js:41 `phases: [Hunt, Adjudicate]`):**

1. **Hunt** — five lanes split by *territory* (module group), never by defect class (`hunt.js:50-59`; rationale `:28-31`, `bug-hunt.md:47-55`). Run as a `parallel(...)` barrier (`hunt.js:132`). Each hunter **writes AND runs its own witness** (`hunt.js:96-99`: "Write a self-contained witness to `${PILE}/witness-<short-name>.jl` … RUN IT: `cd ${REPO} && julia --project ${PILE}/witness-<short-name>.jl`"), records `observed ∈ {FAILS, PASSES, ERRORS, NOT-WRITABLE}` (`hunt.js:72`) and quotes `run_output`. Filenames must be lane-prefixed `witness-<lane.key>-<short-name>.jl` (`hunt.js:140-142`), because lanes run concurrently (`:123-131`). Writes a markdown lane report `${PILE}/hunt-<lane>.md` (`:144`).
2. **Filter** — only `observed === 'FAILS'` reaches adjudication; `NOT-WRITABLE` becomes a "latent hazard" list (`hunt.js:159-164`).
3. **Adjudicate** — one agent per failing candidate, always at session strength (`hunt.js:179-204`; `bug-hunt.md:64-65` "adjudication is never economized"). It must (1) re-run the witness itself and (2) **derive the correct behaviour independently from an oracle**, defaulting to WITNESS-WRONG if it cannot (`hunt.js:188-192`), and check ALREADY-COVERED by grepping `test/` (`:194-195`).
4. **Promotion** — a CONFIRMED witness is promoted into `test/regressions/` **unchanged**, then fixed (`hunt.js:210-213`, `bug-hunt.md:89-90`, `test/regressions/README.md:3-10`). Naming on promotion is `<operation>-<one-line-symptom>.jl` (`README.md:12`) — i.e. the file is *renamed* and a provenance header is *prepended* (`nufft-odd-width-mis-centered.jl:8-9` "Promoted UNCHANGED from the witness; only this provenance header was prepended"); "unchanged" governs the testset body.
5. **Dismissal audit** — a separate workflow, `dismissals.js`, fed with `hunt.js`'s `dismissed` array (`dismissals.js:27-28` "The array is what hunt.js returns as `dismissed`, so the two compose directly").
6. **Mechanical re-run** — `witnesses.jl <pile> <repo>` re-runs every `witness-*.jl` in the pile outside the agents (`bug-hunt.md:69-85`).

**Verdict vocabularies (PF):**
- Hunter `observed`: `FAILS | PASSES | ERRORS | NOT-WRITABLE` (`hunt.js:72`).
- Adjudicator `verdict`: `CONFIRMED | WITNESS-WRONG | NOT-REPRODUCED | ALREADY-COVERED` (`hunt.js:172`), plus booleans `reproduced`, `witness_is_correct`.
- Dismissal auditor: `DISMISSAL-SOUND | UNSAFE | DISMISSAL-WRONG`, default UNSAFE (`dismissals.js:46,69`).
- No `kind`, no `severity` anywhere in PF's schema.

**Closure / stopping rules (PF):** none mechanical for the hunt. The pile is "disposable" (`hunt.js:35-36`); the only durable output is `test/regressions/`. `hunt.js` returns `{confirmed, dismissed, hazards}` with **no `complete` flag** (`:213`). `dismissals.js` returns `complete: dead === 0 && reopened.length === 0` (`:110`). `witnesses.jl` exits 1 if any witness *passes* (`:72`) — note erroring witnesses do **not** fail its exit. `docs/make.jl`'s `lint_review_closure()` (`:297-335`) scans only `doc-review*` directories (`:307`) — it does **not** reach a bug-hunt pile. Hazards are "recorded, not fixed" (`bug-hunt.md:93-94`).

**Run in anger:** once — commit `1adef43e` ("fix: the NUFFT window stencil was mis-centred at odd widths (/bug-hunt finding)"), 2026-08-27. `test/regressions/` holds 3 files, of which one is the hunt's; the other two came from the exhaustive-survey ledger (`pointvalues-…:9-10`) and the doc-panel item (`callable-field-…`). The PF audit-changes pile `.claude/audit-changes/` contains only a `.gitignore` (`latest.json`, `*.diff`) — no audit has ever been recorded there.

### 1.2 `/bug-hunt` — IT

**Files:** `IT/.claude/commands/bug-hunt.md` (247), `bug-hunt/hunt.js` (324), `closure.py` (115), `dismissals.js` (102), `finished.py` (206), `verify-fixes.js` (81), `witnesses.jl` (112), `MANIFEST.txt`.

**Phases (hunt.js:48 `phases: [Hunt, Reproduce]`):**

1. **Hunt** — ten lanes: **two free** (`free-hot-path`, `free-modules`; `hunt.js:158-161`, anchors) and **eight by defect class** (`:163-179`: aliasing-and-mutation, numerics-and-types, api-contracts, gpu-and-hot-loop, edge-cases, state-machine, architecture, test-critic). Optional `lanes` subset arg to re-run a dead lane (`:37, 182-185`). Hunters produce **hypotheses only** — `kind ∈ {runtime, architecture, api-semantics}`, `severity ∈ {blocker, major, minor}`, `mechanism`, `witness_plan`, optional `second_location` (`:59-82`), and `files_read` "cross-checked against the tree" (`:63-64, 127, 147`). Cap 6 candidates per lane (`:129, 149`).
2. **Reproduce** — a `pipeline(selected, huntStage, reproduceStage)` with **no barrier** (`:192-194`): each candidate goes to a reproducer agent that **writes the witness, runs it, and derives the expected value independently** (`:214-285`). Default verdict NOT-REPRODUCED (`:224`). Kind decides the evidence: runtime → failing `@testset`; api-semantics → official docs fetched with URL **and** a run (`:261-265`); architecture → two quoted diffable locations (`:267-272`). Witness slug `${ROUND}${lane.key}-NN` (`:278-282`), the round prefix preventing cross-round overwrites (measured: `bug-hunt.md:218-221`).
3. **Post-hunt, in order** (`bug-hunt.md:163-196`): `witnesses.jl fail` (all confirmed witnesses must fail on the untouched tree) → fix (main thread, never economized) → `witnesses.jl pass` → `verify-fixes.js` for the architecture class → promote passing witnesses into `test/regressions/` and `Pkg.test()` → `dismissals.js` → `/audit-changes` over the hunt's diff + `gate.py` → `finished.py`.

**Verdict vocabularies (IT):**
- Reproducer: `REPRODUCED | NOT-REPRODUCED | WITNESS-WRONG | NO-WITNESS-POSSIBLE | EVIDENCED | NOT-A-DEFECT` (`hunt.js:88`). "Confirmed" = `REPRODUCED ∪ EVIDENCED` (`:310`).
- Dismissal auditor: `DISMISSAL-SOUND | UNSAFE | DISMISSAL-WRONG` (`dismissals.js:46`).
- Architecture fix verifier: `FIXED | RELOCATED | PARTIAL | ABSENT | NOT-A-DEFECT`, default ABSENT (`verify-fixes.js:30, 56-57`).
- Ledger states (`bug-hunt.md:128-136`): every confirmed finding ends `fixed | refuted | escalated`; `finished.py:117-124` enforces `fixed + escalated + refuted == confirmed`.

**Closure / stopping rules (IT) — and a live contradiction on disk:**
- The **current** rule: "Run the hunt ONCE; loop the VERIFIER" (`bug-hunt.md:112-161`); the finding set is fixed by one hunt and the loop terminates because it is finite. `finished.py:95-127` implements this ("BOUNDED TO ONE HUNT (corrected 2026-08-21)").
- The **superseded** rule still on disk: `closure.py:18-20, 83-100` demands a FOLLOW-UP HUNT recording `followup_confirmed == 0`. `bug-hunt.md:119-126` and `finished.py:97-102` explicitly retract this ("measured across five rounds: 20, 9, 17, 21, 17 … A rule that makes 'finished' permanently false is a bad rule"). `rounds.json` carries no `followup_confirmed` field, so `closure.py` would fail on every round; it is unrevised (MANIFEST: 2026-08-20) and still listed as "mechanical, mandatory". **Classification: historic artefact contradicting the current stopping rule.**
- `finished.py` is the effective closure gate: nine checks, each answered by a program, none may pass by vacuity (`:13-17`).
- Escalated findings keep their witness in `witnesses/escalated/` **deliberately not promoted** "so nothing reads green over it" (`bug-hunt.md:133`; `OPEN-DEFECTS.md` round-6 header); `needs-gpu/README.md` holds witnesses the CPU environment reports BROKEN, "not withdrawn: their claims are unverified, not refuted", and explicitly refuses the skip-when-absent option because "a skipped test passes".

**Pile (`IT/.claude/bug-hunt/`):** tracked — `rounds.json` (ledger, rounds 1,2,3,5,6), `OPEN-DEFECTS.md` (escalation register), `edit-audit.json` (the pre-lift-out edit audit, 33 findings, schema `{base, head_of_src, counts, findings[{severity,title,file,before,after,why_it_matters,justified,lane,disposition}]}`), `r4-architecture-03-probe.jl`; untracked — `witnesses/` (`.gitignore:1`) with subdirs `escalated/`, `needs-gpu/`, `withdrawn/`, and `env/{Project,Manifest}.toml` (a witness environment declaring IT + PF + HDF5). `test/regressions/` holds 123 files across rounds 1–7.

### 1.3 `/audit-changes` — PF

**Files:** `PF/.claude/commands/audit-changes.md` (80), `audit-changes/audit.js` (130), `audit-changes/gate.py` (107), `MANIFEST.txt`.

**Phases:** one — `Audit` (`audit.js:23`). Ten lanes run as one `parallel` barrier (`:80`): `free-reader`, `executing` (anchor), `under-rejection` (anchor), `over-rejection`, `behaviour-change` (anchor), `invariants` (anchor), `backend-portability`, `claim-versus-edit`, `contract-drift` (anchor), `sweep-completeness` (`:55-76`). Economy mode puts non-anchors on `sonnet` (`:113`). Note: **the code marks five anchors; `audit-changes.md:51` says "Four are anchors"** — a prose/code mismatch.

**Concern schema:** `{title, severity∈{serious,notable,minor}, justified∈{yes,no,unclear}, location, previously_worked, evidence}` (`:36-48`). Returns `{concerns, serious, unjustified, regressions, deadLanes, covered_paths:['src','test','docs']}` (`:130`).

**Gate (`gate.py`):** reads `.claude/audit-changes/latest.json` (`:29`), expecting `{head, covered_paths, concerns[], dispositions{title→text}, deadLanes}`. (1) Staleness: `git diff --name-only <audited> HEAD -- <covered>`; a **failed diff is `UNCHECKABLE`, never "nothing changed"** (`:53-66`). (2) Every serious concern — **and any concern with non-empty `previously_worked`, whatever its severity** (`:75-80`) — must have a disposition beginning `fixed|refused|escalated` (`:30, 85-89`); a refusal under 24 chars is `REFUSAL WITHOUT A REASON` (`:90-91`). (3) Dead lanes fail the gate (`:93-95`). Exit 0/1/2 (`:23`). **PF gitignores `latest.json`** (`.claude/audit-changes/.gitignore`), so on a fresh clone the gate exits 2.

### 1.4 `/audit-changes` — IT

**Files:** `IT/.claude/commands/audit-changes.md` (100), `audit-changes/audit.js` (176), `gate.py` (87), `attack-design.js` (136), `MANIFEST.txt`.

**Phases:** one `Audit` (`audit.js:31`). `kind ∈ {code, prose, both}` selects **ten code lanes** (`:120-145`: free-reader, executing†, under-rejection†, backend-portability, behaviour-change†, over-rejection†, public-contract, numerics, invariants, claim-versus-edit) and/or **three prose lanes** (`:151-155`: contract-drift†, sweep-completeness, reader-consequence); † = anchor. Non-anchors are **always** `sonnet` (`:165`) — there is no `strength` arg. Two structural rules in the preamble that PF's port dropped: **"PIN THE NORM AT BASE, NOT AT HEAD"** (`:73-77`, `audit-changes.md:53-56`) and **"THE ORACLE IS PART OF THE CHANGE SET — `test/` is in this diff"** (`:79-82`, `.md:58-59`). Requires `base` (`:37`).

**Finding schema:** `{severity, title, file, before, after, why_it_matters, justified}` plus per-lane `checked[]` (required, "especially when CLEAN", `:46-47`) and `candidates_found` (pre-cap count, `:48-49`). Cap 8 per lane (`:102`).

**Gate (`gate.py`):** expects `{head, covered_paths, findings[{severity, disposition}], lanes[{candidates_found, findings}], verdict_all_clean}`. (1) Staleness: `audit.head` must equal `git log -1 --format=%H -- <covered>` (`:41-49`). (2) Serious findings must have a non-empty `disposition` (`:56-61`) — no wording check. (3) An empty audit without `verdict_all_clean: true` fails (`:53-55`). (4) Capped lanes are reported "NOT FATAL, BUT KNOW IT" (`:63-71`). **IT tracks `latest.json`** (`git ls-files` confirms).

**Design attacker (`attack-design.js`):** four roles — logician†, philosopher†, counterexample† (renamed from `red-team`, reasoning `:25-31`), measurement — each must produce a **concrete evading example** that passes every lane (`:14-17, 103-107`); generalized over a `subject` block (`:50-66`). Its record: "eleven fatal gaps" against a seven-lane version, three attackers converging on "not a single lane ran anything" → the `executing` lane (`audit-changes.md:63-77`).

---

## 2. Execution model

**All four `.js` files are Workflow-tool scripts, not `claude -p` spawners.** Evidence: `export const meta = {name, description, phases}` at the top of each (`PF hunt.js:38-42`, `IT hunt.js:45-49`, `PF audit.js:20-24`, `IT audit.js:28-32`, both `dismissals.js`, `verify-fixes.js:14-18`, `attack-design.js:32-36`); bodies use the script API `agent(prompt, {label, phase, schema, agentType, model})`, `parallel([...thunks])`, `pipeline(items, stage, stage)`, `phase()`, `log()`, and the `args` global (`typeof args === 'string' ? JSON.parse(args) : args` in every file). The `.md` files invoke them as `Workflow scriptPath=".claude/commands/bug-hunt/hunt.js" args='{...}'` (`PF bug-hunt.md:60-61`, `IT bug-hunt.md:108-110`). The workflow-authoring reference confirms `agent()` spawns a subagent through the session (default agentType overridden here to `general-purpose`), `schema` forces StructuredOutput, `model: 'sonnet'` is the economy tier, and **a workflow script has no filesystem access** — which the instruments know: `attack-design.js:41-42` ("A workflow script has no filesystem access, but its agents do") and `INVENTORY.md:111-113` ("a workflow script cannot write files … verifiers return them as workflow results").

**Consequence for I/O:** nothing in the `.js` files writes to disk. All persistence happens either inside subagents (witness files, PF's `hunt-<lane>.md` lane reports) or by the main thread after the workflow returns (`latest.json`, `rounds.json` via `closure.py --record`). The `.md` files say "Then record the audit … as `.claude/audit-changes/latest.json`" (`PF audit-changes.md:43`, `IT audit-changes.md:45`) — a manual step. `INVENTORY.md:111-114` records this as the reason the closure gate could not be strengthened to per-finding HONORED before the freeze.

**Models/strength:**
- PF hunt: hunters `sonnet` in economy, adjudicators always session model (`hunt.js:147-148, 203-204`).
- IT hunt: class lanes `sonnet` in economy, free lanes + reproducers always session model (`hunt.js:188, 208, 286`).
- PF audit: non-anchors `sonnet` if economy (`audit.js:113`). IT audit: non-anchors always `sonnet` (`audit.js:165`); `strength` ignored.
- `verify-fixes.js:67` has `...(A.strength === 'full' ? {} : {})` — a no-op; strength is vestigial there.
- Both `dismissals.js` files: session model, no economy option.

**Concurrency:** PF hunt = barrier then barrier (`parallel` at `:132`, `:180`); IT hunt = `pipeline` (`:194`), so reproducers start while slower lanes still read. All audits/dismissals/attack = single `parallel`.

**Return objects (what the caller gets back):**
- PF `hunt.js:213` → `{confirmed, dismissed, hazards}`.
- IT `hunt.js:319-323` → `{tally, anomalies, complete, lanes_run, files_read, confirmed, results}`.
- PF `audit.js:130` → `{concerns, serious, unjustified, regressions, deadLanes, covered_paths}`.
- IT `audit.js:176` → `{bySeverity, findings, dead, complete}`.
- Both `dismissals.js` → `{tally, verdicts, reopened, dead, complete}`; `verify-fixes.js:81` → `{tally, verdicts, dead, complete, open}`; `attack-design.js:136` → `{bySeverity, gaps, dead, complete}`.

**`witnesses.jl` — how a witness runs:**

| | PF `witnesses.jl` | IT `witnesses.jl` |
|---|---|---|
| Invocation | `julia --startup-file=no witnesses.jl <pile> [repo]` (`:13, 17-18`) | `julia --project witnesses.jl <fail\|pass> [name…]` — expectation **required, no default** (`:18-19, 36-38`) |
| Witness location | pile from ARGS; files `witness-*.jl` (`:20-21`) | hardcoded `joinpath(@__DIR__, "..", "..", "bug-hunt", "witnesses")` (`:33`) — a `..`-hop path, the exact shape `finished.py:162-173` forbids in *witnesses* |
| Child process | `julia --startup-file=no --project=$repo $f`, `dir=repo`, bare `julia` from PATH (`:31`) | `$(Base.julia_cmd()) --project=$(dirname(Base.active_project())) --startup-file=no $path` — inherits the parent's julia binary and active project (`:64`); "a fresh process per witness" (`:62-63`) |
| Threads | not set (inherits nothing; default 1) | `Base.julia_cmd()` carries the parent's `-t`; otherwise 1 |
| Pass/fail/broken | `ok` = `run` did not throw; `broken = ("Test threw exception"\|"Error During Test") && !"Test Failed"` (`:47-49`); postmortem `:41-46` on why `LoadError` was the wrong discriminator | `code == 0` → pass; `errored = "Error During Test" \|\| /(\d+) errored/`; `testfail = !errored && ("Test Failed"\|"Some tests did not pass")` (`:76-82`) |
| Exit | 0 unless any **passes**; 1 on no witnesses (`:22, 72`). **Erroring witnesses do not affect the exit** | 0 only if no `wrong` and no `broken` (`:109`); 2 on usage / missing dir / no match / empty (`:36-56`) |
| Single-witness selection | none | substring filter `args[2:end]` (`:48-52`) |

**Regression wiring (both packages identical in shape):** `runtests.jl` includes every `test/regressions/*.jl` each in its own module `Regression_<name>` (`PF test/runtests.jl:47-51`; `IT test/runtests.jl:27-31`), so a promoted witness is a permanent gate and helper-name reuse cannot collide.

**Pile schemas:**
- IT `latest.json` (tracked, 47 findings): `{head, base, covered_paths, instrument, findings[{severity, title, lane, file, disposition}]}` — a hand-consolidated form (the `instrument` field is free text naming two workflow run ids). It has **no `lanes` array**, so IT gate's capped-lane check is vacuous on the real pile.
- IT `rounds.json`: `[{round, confirmed, fixed, escalated, refuted, open, note, …}]` — round 3 has no counts; round 5 carries prose fields.
- PF's expected `latest.json`: `{head, covered_paths, concerns[], dispositions{title: text}, deadLanes}` — **none exists**.

---

## 3. Config coupling — every package-specific datum, classified

(a) = config data; (b) = genuinely different logic; (c) = historic artefact.

### PF

| File:line | Datum | Class |
|---|---|---|
| `hunt.js:53-59` | The five `LANES` territories: `src/Fields.jl …`, `src/FiberSections.jl and src/FieldAlgebra.jl …`, etc., each naming PF operations and contracts ("FFT normalization", "Nyquist split", "`M*inner(Wf,q)==N*inner(f,Wtq)`") | (a) — but also (b): PF's lane *partition principle* is territory, IT's is defect class |
| `hunt.js:82` | "You are hunting for REAL DEFECTS in the CODE of GBGPeriodicFields, a Julia library of real-valued scalar/vector/tensor fields on 3D periodic domains…" | (a) package description |
| `hunt.js:96` | "It must `using GBGPeriodicFields`" | (a) |
| `hunt.js:98, 185` | ``cd ${REPO} && julia --project ${PILE}/witness-….jl`` — **unquoted**; PF's real path contains spaces (`Research and Teach`). IT's port warns "NOTE THE QUOTES, these paths contain spaces" (`IT hunt.js:236-238`); PF's version dropped the quotes | (b) — a port defect |
| `hunt.js:116-118` | "The package is deliberately a math library with NO time, NO particles and NO physics… no field*field multiply in spectral representation, no tensor order above 2" | (a) deliberate-absence list |
| `hunt.js:119` | "if `Pkg.test()` would fail on it, it is not latent" | (a) test command |
| `dismissals.js:55-57` | package description repeated | (a) |
| `dismissals.js:83-87` | "PF is dense with recorded decisions, so this shape is the likeliest one here — but note the converse: PF's deliberate absences … ARE design" | (a) |
| `dismissals.js:88` | third shape "the suite would catch it" — PF-added | (b) |
| `witnesses.jl:31` | `julia --startup-file=no --project=$repo` | (a) invocation |
| `audit.js:59` | "`julia --project -e 'using Pkg; Pkg.test()'` for the gate; `test/allocations.jl` for any 'allocation-free' claim; `test/pass_audit.jl` for any traffic claim; `test/method_parity.jl` for any 'the method set is unchanged' claim" | (a) executable-claims list |
| `audit.js:61` | `_check_field_domain_compatibility`, `_check_same_domain`, `_check_contractible`, `_check_multipliers_compatibility`, `_check_owned_storage` | (a) guard symbols |
| `audit.js:63` | "PF's stated rule is that an absence must encode MATHEMATICS, not convenience" | (a) |
| `audit.js:65` | "PF asserts bitwise thread-count invariance on CPU and tolerance across backends" | (a) |
| `audit.js:67` | invariants (1),(3),(4),(5),(6),(9),(10),(11),(13),(14) restated inline | (a) — a copy of CLAUDE.md that can drift |
| `audit.js:69` | "`Pkg.test()` runs entirely on `Array`, and the GPU suite is opt-in … `CuArray`/`ROCArray` … `FFTW` flags" | (a) |
| `audit.js:75` | "PF states this rule as 'a flagged instance is a sample of a class; fix the class, not the line'" | (a) |
| `audit.js:81-83` | package description in preamble | (a) |
| `audit.js:130` | `covered_paths: ['src','test','docs']` | (a) |
| `gate.py:29` | `.claude/audit-changes/latest.json` | (a) path |
| `bug-hunt.md:36-39` | oracle list (adjointness, Parseval, `div(curl)=0`…) | (a) |
| `bug-hunt.md:42-45` | "Decision 52's mutation audit … Decision 55's oracle registry" | (a) cross-refs to PF decisions |

### IT

| File:line | Datum | Class |
|---|---|---|
| `hunt.js:100, 131` | "GBGIsotropicTurbulence, a Julia pseudospectral DNS of homogeneous isotropic turbulence (velocity + passive scalar…, integrating-factor time stepping, pluggable forcing and dealiasing, a deposit-driven observables cache, Lagrangian tracers). GPU-primary: the time loop is in-place and allocation-free…" | (a) |
| `hunt.js:133` | "THE CODE IS `${REPO}/src/*.jl` and `${REPO}/src/phenomenology/*.jl`" | (a) source layout |
| `hunt.js:159-160` | free-lane starting points: `SimulationRun.advance!`, "the generator's stages, the integrator, the deposit, the tracer push" | (a) |
| `hunt.js:164-178` | class-lane briefs naming `ω_consumed`, `u_consumed`, `step!`/`deposit!`/`advect!`, `NoForcing`, `side_length`, `prepare!`, `record`, `deposit_sample!`, `test/validation.jl`, "PF/SS" | (a) |
| `hunt.js:230, 238` | `using Test, GBGIsotropicTurbulence`; `cd "${REPO}" && julia --project --startup-file=no "…"` | (a) |
| `witnesses.jl:33` | `.claude/bug-hunt/witnesses` relative path | (a) |
| `closure.py:33-35`, `finished.py:25-27` | `WIT`, `REG`, `LEDGER` paths | (a) |
| `closure.py:65, 78`, `finished.py:52, 81` | `julia --project .claude/commands/bug-hunt/witnesses.jl pass`; `julia --project -e "using Pkg; Pkg.test()"` | (a) |
| `finished.py:88-90` | docs build: `Pkg.develop(PackageSpec(path=pwd()))` then `julia --project=docs docs/make.jl` then `git checkout -- docs/Project.toml` | (a) — and a PF-incompatible step (PF's docs env is already dev-linked; the `git checkout` would be a no-op or wrong) |
| `finished.py:178` | `git status --porcelain src test docs CLAUDE.md .claude/commands` | (a) |
| `finished.py:137-139` | "a CFL ceiling cutting the timestep 1.9x on ordinary runs, and a `fields_modified!(sim)` that always threw" | (c) postmortem |
| `dismissals.js:12-19` | `Cache.particle_velocities`, `_base_cfl`, `allocate_buffers`, `IFRK2`'s 0.25 | (c) postmortem (also in PF's port, anonymized: `PF dismissals.js:16-20`) |
| `audit.js:67` | "The edits were made by an automated defect hunt over five rounds: **605 lines inserted, 129 deleted, across 11 source files**" — hardcoded into the preamble of every run | (c) — stale on every subsequent invocation |
| `audit.js:134` | behaviour-change candidates: "the empty-band guard's test, the CFL timestep's ceiling, the integral-scale denominator, the forcing target factor's numeric type, the max-speed reduction, the epoch bookkeeping around deposits, the sample-history relocation" | (c) — a specific round's diff baked into the lane |
| `audit.js:136` | over-rejection: "(viscosity, schmidt, cfl, kinetic_energy, scalar_variance, number_of_particles, forcing targets…)" | (c) same round |
| `audit.js:138` | public-contract: "`ModelSpectrum`, `step!`, `MultistepBuffers`, `ObservablesCache`" | (a)/(c) |
| `audit.js:140` | numerics: "band-emptiness test … CFL ceiling … retained-Nyquist cutoff" | (c) |
| `audit.js:142` | invariants: "minimal memory footprint trumps compute cost; physics stays thin … frozen audit ledgers in test/" | (a) |
| `audit.js:29` | `meta.name: 'audit-edits'` vs the file/command name `audit-changes` | (c) rename residue |
| `attack-design.js:59-63` | default CONTEXT: "605 inserted and 129 deleted lines across 11 source files of a Julia pseudospectral turbulence solver" | (c) — defaults preserve the original framing by design (`:50-53`) |
| `verify-fixes.js:40` | "architecture defect in GBGIsotropicTurbulence" | (a) |
| `bug-hunt.md:71-81` | lane table with `advance!`, `step!`/`deposit!`/`advect!`, `NoForcing` | (a) |

**Summary of the coupling shape:** in both packages the coupling is overwhelmingly (a) — prompt strings (package description, lane briefs, deliberate-absence lists, executable-claim commands, guard symbol names) and paths/invocations. The (b) items are few and named in §4. The (c) items cluster in IT's `audit.js` preamble and lane briefs, which still describe the single change set they were first written for.

---

## 4. Divergences, PF vs IT, same-named files

### 4.1 `hunt.js` — 213 vs 324 lines

| Aspect | PF | IT | Judgment |
|---|---|---|---|
| Lane partition | 5 territories (module groups), "never by defect class" (`:28-31`) | 2 free + 8 class lanes (`:151-179`); free lanes are anchors | **Behaviour.** IT's own postmortem favours PF's direction: "unconstrained readers beating eight defect-class lanes at a third of the cost, and catching four regressions" (`PF hunt.js:28-29`; `IT audit.js:106-108`; `attack-design.js:5-7`). IT kept its eight class lanes anyway; PF went territory-only. PF's split is closer to IT's measured conclusion, but PF has no free reader with no territory at all — each PF lane is constrained by files. Neither is the measured optimum. |
| Who writes the witness | The **hunter** writes + runs it (`:96-99`), then an adjudicator re-runs and derives the oracle (`:185-192`) | The hunter gives a `witness_plan`; a separate **reproducer** writes, runs, and derives (`:214-256`) | **Behaviour.** PF's shape has the witness executed twice by two agents (hunter, adjudicator) plus once mechanically; IT's has it once by the reproducer plus mechanically. PF's `bug-hunt.md:75-80` argues the hunter's self-report is exactly the self-reporting shape closed elsewhere, hence the mandatory `witnesses.jl` re-run. Both are consistent with "adjudication re-derives from an oracle"; the IT gap ("a failing witness is necessary and not sufficient") was closed on **2026-08-27 by PF's reverse-transfer** (`IT bug-hunt.md:208-217`, IT commit `f0428ca`). |
| Candidate metadata | `title, location, claim (with oracle), witness_path, observed, run_output` (`:67-75`) | `kind, severity, title, file, line, mechanism, witness_plan, second_location` + lane `files_read` (`:63-79`) | **Behaviour.** PF has no `kind` (so no architecture or api-semantics class) and no `severity`. IT's `files_read` "cross-checked against the tree" (`:127`) has no PF counterpart (PF: `territory_note`, free text). |
| Verdict set | `CONFIRMED / WITNESS-WRONG / NOT-REPRODUCED / ALREADY-COVERED` | `REPRODUCED / NOT-REPRODUCED / WITNESS-WRONG / NO-WITNESS-POSSIBLE / EVIDENCED / NOT-A-DEFECT` | **Schema.** PF's `ALREADY-COVERED` has no IT equivalent (IT tells hunters "A defect the suite ALREADY catches…" only implicitly via test-critic). IT's `EVIDENCED`/`NOT-A-DEFECT` exist only because IT admits the architecture class. IT's `NO-WITNESS-POSSIBLE` is PF's hunter-level `NOT-WRITABLE`. `INVENTORY.md:58` already flags this as "a SCHEMA divergence, not wording: `dismissals`, `closure` and `finished` all key off it". |
| Round prefix | none; lane-key prefix only (`:140`) | `r${round}-` prefix (`:56, 278-282`), from a measured overwrite (`bug-hunt.md:218-221`) | **Behaviour.** PF sidesteps it by renaming on promotion (`README.md:12`) and treating the pile as disposable; IT promotes under the pile name and so needs the prefix. |
| Orchestration | two barriers | `pipeline`, no barrier (`:192-194`) | Behaviour; IT's is the lower-latency shape the Workflow reference recommends. |
| Dead lane | logged, "UNHUNTED, not clean" (`:153`); no `complete` flag | `anomalies[]`, `complete: anomalies.length === 0` (`:293-320`) | IT stronger — PF's return object carries no completeness signal for a caller to gate on. |
| Lane subset re-run | none | `lanes` arg (`:37, 182-185`) | IT only. |
| Path quoting | unquoted `cd ${REPO}` (`:98, 185`) | quoted with an explicit warning (`:236-238`) | **IT is right; PF's port regressed** on a repo whose path contains spaces. |
| Caps | "Prefer FEW, SHARP, RUN candidates" (`:114`) | "Cap: your 6 most substantial" (`:129, 149`) | Commentary/tuning. |

**Commentary-only differences:** both headers restate the one rule and the IT-measured free-lane result; PF's is shorter and cites IT; IT's carries the architecture/api-semantics rationale (`:22-30`).

### 4.2 `dismissals.js` — 109 vs 102 lines

Near-identical logic (PF is "Ported … 2026-08-27 (mechanism only)", `:1-2`). Differences:
- **Input field names** follow each package's `hunt.js` output: PF `{title, location, claim, verdict, reasoning|observed}` (`:59-63`), IT `{title, file, line, mechanism, verdict, observed}` (`:59-63`). Coupled to the hunt schema, not to the package.
- **`complete`**: PF `dead === 0 && reopened.length === 0` (`:110`); IT `dead === 0` (`:103`). **Behaviour.** PF's is stricter — an audit that reopens a dismissal is not "complete". IT's reads "complete" as "every auditor returned", which is the weaker claim. PF's wins by the instruments' own "missing case must be the failing case" rule.
- PF adds a **third dismissal shape** — "the suite would catch it. Only true if a test actually asserts it. Grep for the assertion." (`:88`) — and the PF-absences caveat (`:83-87`). Behaviour (prompt), PF-specific.
- PF's empty-array error adds "and a run over nothing must not report success" (`:40`). Commentary.

### 4.3 `witnesses.jl` — 72 vs 112 lines

Table in §2. The **behavioural** differences and which is better:
- **Direction:** IT has `fail|pass` as a required expectation (`:18-19`) — the fix verifier is the same program as the hunt verifier. PF only checks the hunt direction (exit 1 if any passes, `:72`); PF's "pass" direction is delegated to `Pkg.test()` after promotion. IT's is the more complete instrument; PF's is honest about its narrower role (`bug-hunt.md:82`).
- **Broken witnesses:** IT fails the exit on `broken` (`:109`) with a 1200-char dump (`:85-86`); PF reports them apart with 4 lines (`:53-58`) but **exit ignores them** (`:72`). By the instruments' own rule ("a broken witness is evidence of nothing … counting it as a failure is how a phantom gets promoted", `IT witnesses.jl:25-27`) IT's non-zero exit is the safer default; PF's exit-0-with-erroring-witnesses is a silent-anomaly path.
- **Classification:** IT's `(\d+) errored` regex additionally catches an errored testset summary (`:76-77`); PF relies on `"Test threw exception"|"Error During Test"` with the `!asserted` guard (`:47-49`). Each file carries a postmortem of a misclassification (PF `:41-46`: `LoadError` was wrong; IT `:72-75`: "Some tests did not pass" alone was wrong).
- **Location of witnesses:** PF takes the pile as an argument (portable); IT hardcodes a `..`-hop path from `@__DIR__` (`:33`) — the very pattern `finished.py:162-173` bans for witnesses. Config-vs-logic: PF's is the shareable shape.
- **Julia binary/project:** IT inherits via `Base.julia_cmd()` and `Base.active_project()` (`:64`) — so it must itself be run with `--project`; PF invokes bare `julia --project=$repo` (`:31`). IT's inherits threads and the exact binary; PF's does not.
- **Subset selection** (IT `:48-52`) — IT only.
- **Empty run:** both refuse (PF `:22` exit 1; IT `:56` exit 2).

### 4.4 `audit.js` — 130 vs 176 lines

- **Args:** PF `{repo, diff, claims, strength}`; IT `{repo, diff, base, head, claims, kind, scale}` with `base` required (`:37`). **PF has no `base`** and so **dropped the two structural rules** IT's `.md` calls out as "each from a demonstrated failure" (`IT audit-changes.md:52-59`): pinning the norm at BASE (`IT audit.js:73-77`) and treating `test/` as audited material (`:79-82`). Only PF's `contract-drift` brief mentions "at the base commit" (`:73`), but no lane is told how to reach it. **Behaviour: a real loss in the port.**
- **Lane sets:** PF folds IT's code + prose lanes into one 10-lane list, dropping `public-contract`, `numerics`, `reader-consequence`, and adding nothing new; IT's `kind` switch exists because "a lane that cannot fire on the diff at hand teaches the reader to discount CLEAN verdicts everywhere" (`IT audit-changes.md:41-43`, `audit.js:147-150`). PF runs the numerics-free set on every diff, prose included. Behaviour.
- **Anchors:** PF five (`executing, under-rejection, behaviour-change, invariants, contract-drift`); IT five (`executing, under-rejection, behaviour-change, over-rejection, contract-drift`) — `invariants` ↔ `over-rejection` swapped. PF's `.md` says four. Config.
- **Schema:** IT requires `checked[]` and `candidates_found` (`:46-49, 64`); PF has neither, so PF cannot detect a lane that did nothing or a cap hiding findings (IT `audit-changes.md:90-93, 98-100`). PF adds `previously_worked` (`:44`) and `location` and drops `before/after/why_it_matters`. **Behaviour** — PF's `previously_worked` is the field its gate escalates on; IT's `checked`/`candidates_found` are the fields its gate reports on. Neither has the other's.
- **Strength:** PF honours `strength`; IT always economizes non-anchors. Behaviour.
- **Preamble artefacts:** IT's "605 lines inserted, 129 deleted, across 11 source files" (`:67`) and the round-specific candidate lists in four lane briefs (`:134, 136, 138, 140`) are (c). PF's port replaced them with PF's own anchors and generic phrasing (`:53-54` "the anchors and examples are PF's, because a lane that names another package's symbols would send every reader hunting for things that are not here").
- **Return shape:** PF `{concerns, …, deadLanes, covered_paths}`; IT `{bySeverity, findings, dead, complete}`. The gates expect different pile shapes accordingly (§4.5).

### 4.5 `gate.py` — 107 vs 87 lines

- **Pile schema:** PF `concerns[]` + `dispositions{title→text}` + `deadLanes`; IT `findings[].disposition` + `lanes[].candidates_found` + `verdict_all_clean`. **Not interchangeable**: PF's gate run on IT's tracked `latest.json` would see zero concerns and pass; IT's gate on a PF-shaped file would see no findings and fail on `verdict_all_clean`.
- **Staleness:** IT compares `audit.head` to `git log -1 --format=%H -- <covered>` (`:41-49`) — which reports STALE whenever the audited HEAD is *later* than the last commit touching covered paths (e.g. an audit taken after a CLAUDE.md-only commit). PF diffs `<audited>..HEAD -- <covered>` and distinguishes **UNCHECKABLE** (unreachable commit) from "nothing changed" (`:53-70`) — with a postmortem that "that inversion made a stale audit PASS when this gate was first falsified" (`:55-57`). **PF's is the corrected, later version** (2026-08-27 vs IT's 2026-08-21) and is better on both counts.
- **Disposition validation:** PF checks the wording (`fixed|refused|escalated` prefix, refusal ≥ 24 chars, `:30, 85-91`); IT checks non-emptiness only (`:57`). PF stricter.
- **Regression escalation:** PF treats any concern with `previously_worked` as serious (`:75-80`); IT has no such field.
- **Empty audit:** IT fails an audit with no findings unless `verdict_all_clean: true` (`:53-55`); PF has no equivalent (an all-CLEAN PF audit passes silently, though `deadLanes` is checked). IT better here.
- **Capped lanes:** IT reports (non-fatal, `:63-71`); PF cannot (no `candidates_found`).
- **ROOT fallback:** PF `or "."` (`:27-28`); IT none.
- **MANIFEST derivation:** PF's `audit-changes/MANIFEST.txt:11` shows `gate.py … -` (no purpose), because PF's `manifest.py` reads the first `#` comment and `gate.py` opens with a docstring; IT's manifest resolves the same file's docstring. A `manifest.py` divergence, not a `gate.py` one.

### 4.6 Files with no PF counterpart

| File | What it does | Does PF lack the capability or do it elsewhere? |
|---|---|---|
| `closure.py` (IT) | Four checks: witnesses pass, all promoted, `Pkg.test()`, and **a follow-up hunt confirming zero** (`:13-20`); `--record` writes `rounds.json` (`:42-51`). | **Superseded in IT itself** (§1.2) — the follow-up-hunt terminator was retracted in `bug-hunt.md:119-126` and `finished.py:97-108`. PF never had it and, by IT's own correction, should not. The ledger-recording half (`--record`) has no PF equivalent; PF has no round ledger at all. |
| `finished.py` (IT) | Nine program-answered checks: witnesses pass, promoted, no clobber via `git status`, `Pkg.test()`, docs build, ledger arithmetic `fixed+escalated+refuted == confirmed`, delegates to `audit-changes/gate.py` (`:144-159`), no `..`-hop paths, clean tree, pushed (`:47-192`). Design rules `:13-17`. | **PF lacks it.** PF's nearest analogues: `lint_review_closure()` in `docs/make.jl` (scans only `doc-review*` dirs, `:307`) for the doc rounds, and `gate.py` for audits. Nothing in PF asks "is the hunt finished?" mechanically; PF's hunt has no ledger, and its pile is disposable by design. |
| `verify-fixes.js` (IT) | Agent audit of **architecture-class** fixes, hunting `RELOCATED`; default `ABSENT` (`:9-11, 56-57`). | PF lacks it *and* lacks the class it serves — PF's hunt admits no architecture findings (no `kind`). A `verify-fixes.js` also exists under IT's and PF's `check-consistency/` for the doc instruments (different file; the `HONORED/LINE-ONLY/…` vocabulary in CLAUDE.md refers to that one, not this). |
| `attack-design.js` (IT) | Four-role adversarial attack on any instrument's lens list, demanding concrete evading examples (`:12-17, 103-107`); generalized via `subject` (`:50-66`). | **PF lacks it entirely.** PF's `audit.js:53` says "The kinds are IT's" — PF inherited the post-attack lane set without the attacker. `IT audit-changes.md:80` claims "Any instrument's lane list should have to survive it"; PF's five hunt territories never did. |

**Reverse direction (PF has, IT lacks):** `lint_review_closure()` (build-enforced, doc rounds only), `recall_selftest.py`, `guards.sh` — per `INVENTORY.md:68-75`, none of which is bug-hunt/audit-specific. And PF's `test/regressions/README.md` (the promotion contract written down: runnable alone, oracle-backed, header naming defect/date/commit) has **no IT counterpart file**; IT's promoted witnesses carry a defect header by convention (`01-api-contracts-01.jl:1-9`, `r6-reality-check.jl:1-5`).

---

## 5. Design constraints and lessons a shared package must honour

Each with the evidence that established it.

1. **The verdict vocabulary is a schema consumed by several scripts, and it currently differs.** `INVENTORY.md:58` names it unresolved; the consumers are `dismissals.js` (its input `verdict` field, `PF:63`, `IT:62`), `closure.py`/`finished.py` (ledger states `fixed/escalated/refuted`, `finished.py:117-124`), `verify-fixes.js` (architecture class only exists if `EVIDENCED` does). PF's set (`hunt.js:172`) and IT's (`hunt.js:88`) overlap on `NOT-REPRODUCED`/`WITNESS-WRONG` only; `CONFIRMED` vs `REPRODUCED|EVIDENCED`, `ALREADY-COVERED` vs nothing, `NOT-A-DEFECT` vs nothing. Likewise the audit pile schema (`concerns/dispositions` vs `findings[].disposition`) is read by two incompatible `gate.py`s (§4.5) and, in IT, by `finished.py:152`.

2. **A witness is promoted UNCHANGED, and the test that proves the fix is the test that proved the bug.** `PF hunt.js:210-213`; `PF test/regressions/README.md:3-10, 14-18`; `IT bug-hunt.md:29-31, 203-207`; `IT witnesses.jl:5-13`. Observed lifetime of the rule: at promotion it holds byte-for-byte (`diff` of `r6-edge-cases-01.jl` pile vs promoted: identical), but the promoted copy is thereafter maintained with the tree — `r6-test-critic-02-…jl` differs from its pile copy by the `point_coordinates → point_positions` rename PF shipped 2026-09-02, and 20+ `test/regressions/*.jl` share the `Sep 3 23:32` mtime of that sweep. "Unchanged" is a promotion-time property, not a permanent one; a shared package should say which.

3. **Adjudication re-derives the expected value from an oracle independent of the assertion; a failing witness is necessary, not sufficient.** `PF hunt.js:23-26, 188-192`; `PF bug-hunt.md:28-31`; `IT hunt.js:243-256` ("the step most likely to be skipped"); `IT bug-hunt.md:208-217` records it as a PF→IT transfer on 2026-08-27, with the measurement "the second happened twice on round 1 at full strength" (`:102-103`). Default when the derivation cannot be made: WITNESS-WRONG (`PF hunt.js:192`).

4. **The only admissible evidence is a program that fails — and an agent's account of that program is not the program.** `PF witnesses.jl:4-11`, `PF bug-hunt.md:69-85`: the mechanical re-run exists because the hunter self-reports `observed`. Corollary in both runners: a passing witness is not a bug, and a **broken** witness is evidence of nothing in either direction (`IT witnesses.jl:25-27, 104-107`; `PF witnesses.jl:38-46`), with `needs-gpu/README.md` refusing skip-when-absent because "a skipped test passes".

5. **The `executing` lane is the audit's anchor, and the audit deliberately has no adversarial verifier.** `PF audit.js:58-59`; `IT audit.js:122-124`; `IT audit-changes.md:63-70` (three of four attackers converged on "not a single lane ran anything"); `PF gate.py:4-8` / `IT gate.py:4-7` ("a second adversarial layer auditing the auditor is where the regress begins and the grounding ends"). It is never economized (`PF audit.js:58` `anchor: true`; `IT:122`).

6. **The gate demands every serious finding be ANSWERED — fixed, refused with a reason, or escalated — never absent.** `PF gate.py:12-15, 82-91`; `IT gate.py:11-14, 56-61`; `PF audit-changes.md:69-70`; `IT audit-changes.md:97-98`. PF extends "serious" to any `previously_worked` concern regardless of lane severity (`gate.py:75-80`) because "its severity is not the reporting lane's to downgrade" (`audit-changes.md:74-76`).

7. **The missing case must be the failing case — no vacuous pass, no silent success.** Every script has an explicit refusal: empty pile (`PF witnesses.jl:22`, `IT:56`), empty dismissals/findings arrays (`PF dismissals.js:40`, `IT:41`, `verify-fixes.js:24`), dead lanes/auditors counted as UNHUNTED/UNAUDITED/UNAPPLIED not clean (`PF hunt.js:153`, `PF audit.js:123`, `PF dismissals.js:95-97`, `IT hunt.js:314-316`), `finished.py:13-14` ("A check that finds nothing to inspect FAILS"), `IT gate.py:53-55`, `PF gate.py:53-57` (UNCHECKABLE ≠ clean). Known exceptions that violate it today: PF `witnesses.jl` exits 0 with erroring witnesses (`:72`); PF `hunt.js` returns no `complete`; `INVENTORY.md:81-84` — a shared closure gate would pass vacuously on IT's untracked pile.

8. **Self-reported closure is not closure; the measurement sits outside the party measured.** `PF witnesses.jl:4-8` (third instance of one class); `finished.py:5-9` ("Every one of them REPORTED SUCCESS OVER ITS OWN GAP"); `INVENTORY.md:111-114` ("Must read the GRADER's verdicts, never the graded party's file — PF's gate read 30 HONORED against its script's authoritative 23"). The dismissal audit exists because filed verdicts are otherwise never revisited, and its default is UNSAFE (`PF dismissals.js:24-25`, `IT:25-28`), with two measured wrong dismissals, one a blocker (`IT dismissals.js:10-22`).

9. **The instrument runs ONCE; the loop is over the banked findings, and it terminates because the set is finite.** `IT bug-hunt.md:112-161`; `finished.py:97-108`; the retracted alternative in `closure.py:18-20, 83-100` with its measured non-convergence (20, 9, 17, 21, 17). A shared package must not ship `closure.py`'s check 4.

10. **A fix's damage is invisible to the witness gate; the edit audit is a separate instrument with its own gate, and `finished.py` delegates to it rather than reimplementing it.** `IT bug-hunt.md:150-158`; `finished.py:144-148` ("one definition of 'audited' rather than two that can drift"); `PF audit-changes.md:23-29`; measured: `NEWLY BROKEN = 0` with two live regressions (`IT audit.js:12-13`, `finished.py:136-139`).

11. **Pin the norm at BASE and treat `test/` as audited material.** `IT audit.js:73-82`; `IT audit-changes.md:52-59`. PF's port lost both (no `base` arg). A shared `audit.js` needs `base` as a required argument, as IT's has (`:37`).

12. **Lists are hypotheses; every lens set should survive `attack-design.js`, and a free lane exists as insurance.** `IT audit.js:104-119`; `attack-design.js:3-17`; `IT audit-changes.md:62-80`; `PF hunt.js:28-31`. PF's five territories and PF's ten audit lanes have never been attacked (PF has no attacker).

13. **Witness filenames and paths must not collide or depend on depth.** Round prefix (`IT hunt.js:38-40, 278-282`; `bug-hunt.md:218-221`); lane prefix for concurrent lanes (`PF hunt.js:123-127, 140-142`); promote per finding after its fix lands, never `cp witnesses/*.jl` (`IT bug-hunt.md:222-225`); locate files with `pkgdir`, never `..` hops, and not "first `Project.toml`" either since `test/` has one (`IT bug-hunt.md:226-230`; `finished.py:162-173`) — a rule IT's own `witnesses.jl:33` breaks for the runner itself; quote paths with spaces (`IT hunt.js:236-238`; PF regressed, `hunt.js:98, 185`).

14. **Instruments are frozen; a change to one is its own commit, never folded into a round it scores.** `INVENTORY.md:92-107` (PF at `faa164a1`, IT at `fdeba74`, 2026-08-27). Note that IT's tree carries both the frozen `closure.py` and its retraction — so "frozen" preserved a contradiction, which a shared package inherits unless it resolves it explicitly.

15. **Pile persistence differs by standing decision and determines whether a gate can run on a clone.** IT tracks `latest.json`, `rounds.json`, `OPEN-DEFECTS.md`, `edit-audit.json` and gitignores only `witnesses/`; PF gitignores `latest.json` and `*.diff`, treats the hunt pile as disposable, and has no ledger. `INVENTORY.md:81-84` states the consequence for any shared gate.

16. **Manifests are derived, not typed, and stay demoted rather than retired after sharing.** Both `MANIFEST.txt` headers (`:5-6` "PURPOSE is DERIVED from each file's first substantive comment … A dash means the file does not say what it is, which is a finding"); `INVENTORY.md:86-90`. PF's `gate.py` currently shows the dash.