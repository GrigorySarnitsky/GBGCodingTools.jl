# GBGCodingTools — implementation plan

An ordered, checkable plan for the session that implements `GBGCodingTools.jl` from `ARCHITECTURE.md`
(read that first; section numbers `§n` below refer to it). Every phase ends with a definition of done
and the commands that verify it. Nothing is done until its verification command exits 0.

Paths — **exported**, because every verification block below is a `bash -c '…'` child shell and an
unexported plan variable expands to nothing there:

```bash
export B="$HOME/Dropbox/Research and Teach"
export DEV="$B/AI Helpers/GBGCodingTools"          # the dev checkout
export PF="$B/Isotropic Turbulence/GBGPeriodicFields"
export IT="$B/Isotropic Turbulence/GBGIsotropicTurbulence"
export SS="$B/Statistics/GBGStreamingStatistics"
export CP="$B/Cloud Physics/GBGCloudPhysics"
```

Every one of these paths contains spaces: **quote them everywhere**, inside `bash -c` strings too
(double quotes, never single, around any string that must expand `$DEV`/`$B`).

Until Phase 3 installs the shim, the dev checkout is invoked through one exported shell function (the
CLI is Julia inside the package, 1.3; `main` accepts `--dev` itself):

```bash
gbgdev() { julia --startup-file=no --project="$DEV" -e 'using GBGCodingTools; exit(GBGCodingTools.main(ARGS))' -- --dev "$@"; }
export -f gbgdev                                   # so the `bash -c` verification blocks see it
```

---

## A. Owner rulings (answered 2026-09-08 on `Aiporetne`, one by one, before Phase 0)

Ids are kept from the record's list; Q8–Q11 were decided by the record and are stated in §B, not asked.

**Separate owner rulings, not bundled with adoption (IT amendment 16).** Q1 (IT's branch, `main` →
`master`?) and Q2 (IT's bare `!!! note` → always titled?) are no longer in this table: both are
decisions about the consumer, not the tool, which supports either value through `git.branch` and
`docs.admonition_titles`. The owner rules on each separately, and the migration must not bundle a
branch rename or a retitling sweep with a tooling adoption commit — Phase 5.2 applies IT's current
values and waits.

**The standing principle behind the rulings (owner, 2026-09-08):** every package is organised as
uniformly as possible, and history is not dragged along. Where a choice lies between carrying an old
artefact into the new layout and starting clean, start clean; git history keeps every tracked file.
Anything still LIVE (a runbook, an escalated witness) gets a proper tracked home.

| # | Question | Ruling |
|---|---|---|
| Q3 | SS's bold argument bullets: collapse to PF's plain form, or a ledger deviation `RULE.DOC.ARG_BULLET`? | **Collapse.** Measured 2026-09-08: SS `src/*.jl` holds 0 bold and 80 plain bullets; the bold form existed only in SS's old `check-docs.md` prose, which Phase 6 deletes. No SS source edit, no ledger entry. |
| Q4 | CP's `Aqua persistent_tasks = false`: drop, or a ledger entry with the reason? | **Drop** at Phase 7. Its recorded reason (a flaky probe under solver dependencies CP once carried) no longer applies; CP now depends only on PF, SS, `Random`, `Statistics`. |
| Q5 | Generate `.claude/settings.json` as a managed file? | **Yes** — and, by the Stop-hook ruling below, in every consumer: the file holds nothing but the hook wiring, so it is rendered wherever the hook is, which is everywhere. |
| — | The end-of-turn guard — PF's Stop hook `queue-guard.sh`, which refuses to let a session stop while `.claude/WORK_QUEUE.md` holds an open `- [ ]` item: PF only, all four, or nowhere? | **All four packages** (ruled 2026-09-09). The config switch `hooks.work_queue` is gone; the hook script, the `settings.json` that wires it and an empty `WORK_QUEUE.md` (seeded once, then owned) are part of every consumer's footprint, the tool root included. PF's 93 done lines are deleted at PF-6; the mechanism is unchanged. |
| — | Cross-package request files (PF's two `to-IT-*.md`, IT's nine `pf-request-*.md`/`ss-request-*.md`)? | **Only a request still awaiting the other package moves to `.gbg/requests/`** (with its status paragraph); a concluded one is deleted at that package's migration. PF's two July files are concluded. |
| — | `CLAUDE.md` shape (PF 2697 lines, of which ≈1500 are state and roadmap; SS 680 with a 246-line roadmap; IT 504; CP 133)? | **One skeleton for all five** (`templates/CLAUDE.md.skeleton`): the managed block, "Modules and wiring", "Core invariants", the package's own style rules, "Working agreements", and one short "Current state" paragraph pointing at `docs/ROADMAP.md`. At each migration the package's session trims to it: finished work is deleted (git history keeps it), live plans move to a tracked `docs/ROADMAP.md` (not a scan surface). |
| Q6 | `seed_rounds` default `true` for `/check-consistency`? | **True.** |
| Q7 | Admit `[[scans.custom]]` (consumer-declared regex scans, tier fixed to triage)? | **Yes.** |
| Q12 | IT's fourteen non-instrument notes under `.claude/` (`arch-research/`, `archive/`, the reading and docstring-review piles, `panel-reaudit.md`, `observables-cache-notes.md`, `pf-api-survey-2026-08-05.md`, the untracked `OPEN-ITEMS.md`, `panel-rubric-reaudit-2026-08-22.md`, `turtle-comparison-spec.md`)? | **Cleaned out to the uniform shape by the IT session itself**, in one IT commit before adoption (asked and done 2026-09-08): the eleven tracked notes and the obsolete reaudit deleted (git history keeps them); `turtle-comparison-spec.md` → `validation/RUNBOOK.md` (live); `OPEN-ITEMS.md` kept untracked until its six open items are ruled at 5.2, then deleted. `LEG.PILES` does not name them. |
| Q13 | PF's untracked `.claude/doc-review-prev/`? | **Discard at PF-2, never imported.** Correction (PF session, 2026-09-08): it is NOT a superseded copy of the 2026-09-01 panel but the complete, closed `/check-consistency` round 6 of 2026-08-15 (65 findings, fix commit `571060c0`), archived by the protocol's `mv doc-review doc-review-prev` step; no verdict files exist for it. |
| Q14 | GitHub Pages for the tool's own docs site (`docs.yml`, 1.10; a private repository)? | **Deploy exactly as the four consumers do**: repository private, site public by URL from `gh-pages`. Owner-only Pages is an Enterprise-only feature and unavailable on this account; all four consumer sites are already public by URL. |
| — | Pre-tool review rounds: does a consumer carry its old piles into `.gbg/rounds/` as imported rounds? | **No.** Phase 2's equivalence test runs on SCRATCH imports (created, graded, compared, deleted); only the comparison table is kept, in the tool's `CHANGELOG.md`. Every consumer starts at migration with an empty `.gbg/rounds/`; old adjudications are not carried into the ledger; IT's escalated and blocked witnesses (live checks) move to `test/regressions/escalated/` and `test/regressions/blocked/`. |
| — | Commit trailer under the harness's own attribution request? | **Versionless** `Co-Authored-By: Anthropic Claude <noreply@anthropic.com>`, no `Claude-Session` line, in every repository (`GIT.TRAILER` checks it). |

---

## B. Working agreements for the implementing session

- **Commit ⇒ push, on `master`**, in the tool repo and in every consumer. End every commit message with
  `Co-Authored-By: Anthropic Claude <noreply@anthropic.com>` (versionless, owner-decided 2026-09-04).
  Never `[skip ci]`.
- **Stage with `git add -u` PLUS every new file by name** — `-u` skips untracked files (it cost IT a
  follow-up commit on 2026-09-04) — and never `git add -A`, which sweeps in whatever the working tree
  holds.
- **Decided by the record, not open (former Q8–Q11):** the tool declares `julia = "1.11"` and its CI
  carries a 1.11 lane (`juliaup add 1.11` on both hosts; SS's floor untouched); the name is
  `GBGCodingTools` (`GBGDevTools` recorded as the alternative, not asked again);
  `gbg audit-changes bank` re-runs the executable claims itself and records their exit codes (minutes
  per audit, accepted); `.gbg/requests/` is a tracked pile in the requester (PF's `to-IT-*.md` and IT's
  `pf-request-*.md`/`ss-request-*.md` move there).
- **Never edit an instrument mid-round.** An instrument change is its own commit in `$DEV`, released by
  `gbg release`, and reaches a consumer by a `gbg bump` commit. If a defect in the tool is found while a
  consumer round is open, record it in the tool's `CHANGELOG.md` "Unreleased" and finish or abandon the
  round first.
- **"Should work" is not done.** A step is done when its verification command exits 0 and the exit code
  was observed, not inferred from a log.
- **Gate every commit on exit codes**: run verification as `bash -e -o pipefail -c "…"`; never gate on a
  grep of a log; never `| head` a scan's output.
- **A build or test run under an open round goes through the CLI** (`gbg round build|test <round>`,
  `gbg round prepare`, `gbg round pass open`, `gbg round close`, `gbg audit-changes bank`), which
  exports `GBG_ROUND` so `gbg gate` ignores that round and no other. A bare `julia --project=docs
  docs/make.jl` under an open round is refused by design; do not export `GBG_ROUND` by hand.
- **Owner consent**: unasked, run only `Pkg.test()`, the tool's `gbg selftest`, and the docs build; the
  four instruments, the exhaustive survey and benchmarks run only when the owner asks.
- **No secrets in any repo**: the CI PAT is the repo secret `GBG_DEPS_TOKEN` in EVERY consumer (IT has
  it; PF, SS and CP gain it in their migration step); the https `insteadOf` rewrite is the only auth
  mechanism.
- **A flagged instance is a sample of a class** — when a migration step finds one leftover, sweep the
  consumer for the class before continuing.
- **Uniform, and no history carried** (owner, 2026-09-08; §A): after migration the five consumers —
  the tool root included — have the same footprint (§4 of `ARCHITECTURE.md`) and nothing else that the
  tool put there or that the old instruments left behind; `.gbg/rounds/` starts empty in every
  consumer; a pre-tool pile is deleted, not imported; a settled note is deleted, not moved; only a LIVE
  artefact (a runbook, an escalated witness) is given a tracked home.

---

## Phase 0 — Preconditions and day-1 verifications

Preconditions: `hostname` is `Aiporetne` or `Enteropia`; `juliaup` with `release` 1.12.7 (no `python3`
is needed anywhere in this plan); `~/.local/bin` on `PATH`; the four consumer clones present;
GitHub push access to `GrigorySarnitsky/*`. Create the empty private repo
`GrigorySarnitsky/GBGCodingTools.jl` on GitHub before Phase 1, and **enable GitHub Pages on it** — an
OWNER action (repository settings → Pages, source = the `gh-pages` branch `deploydocs` pushes, exactly
as the four consumers are set up — Q14: private repository, site public by URL): a private repository
serves no Pages until it is, and the tool's own site (1.10) deploys on every push to `master` like a
consumer's.

Each verification (here and in Phase 1.9) is an experiment with a pass criterion and a fallback.
Record the outcome in `$DEV/docs/ARCHITECTURE.md` §11 (date, host, result).

| # | Verification | Experiment | Pass | Fallback if it fails |
|---|---|---|---|---|
| V1 | Outside-project Workflow `scriptPath` — **DONE 2026-09-09 on `Aiporetne`: FAILED for a fresh outside path; fallback adopted as the rule** (`ARCHITECTURE.md` §11) | `Workflow({scriptPath: "/tmp/gbg-probe/echo.js", args: {n: 1}})` with `echo.js` = `export const meta = {name:'probe',description:'echo'}; return {ok:true, echoed: args}` — refused before launch ("scriptPath must be … a file you can already read"); the same script under the session scratchpad returned `{ok:true, echoed:{n:1}}`; the `/tmp` path was accepted only after the session had `Read` it | (not met for the pinned-copy path) | ADOPTED: `preflight` and `pass open` copy the instrument's `workflow/*.js` into `.gbg/scratch/<round>/workflow/` (gitignored, inside the working directory) and print that path (§2 D7, §6.2 step 4); 1.3's `preflight` row and 1.5 state it |
| V7 | The private-repository Pages deploy works | After 1.10 has pushed `docs.yml` (listed here because the enablement is the owner action above, taken before Phase 1): a push to `master` runs `docs.yml`; open `https://grigorysarnitsky.github.io/GBGCodingTools.jl/` | the job is green; the site serves `index.md` and `guide/verbs.md` with the verb table rendered, as the four consumer sites do | if Pages cannot be served: keep `docs.yml` as the per-push BUILD with `deploydocs` skipped — the build, not the deploy, is the enforcement point (§2 D9) — and record the choice |
Only V1 can run before the skeleton exists; V2–V6 need a verb, a tag, a template, `CI.yml` and the
tool's `Project.toml` respectively, and are Phase 1.9; V7's enablement is done now and its verification
follows 1.10.

**Definition of done.** V1 recorded with its outcome; Pages enabled on the tool repository (V7's
verification follows 1.10); `$DEV/docs/ARCHITECTURE.md` §11 updated.

**Done 2026-09-09 on `Aiporetne`:** `git init -b master`, seed commit `d53249e`, private repository
`GrigorySarnitsky/GBGCodingTools.jl` created and `master` pushed; `juliaup add 1.11` (1.11.9 beside
1.12.7; `Enteropia` still to do); V1 run three ways and recorded in §11 (fallback adopted as the rule).
Pages: enabled through the API once the first `docs.yml` deploy has created `gh-pages` (1.10), the
consumers' setup exactly; nothing needed from the owner unless the API refuses.

---

## Phase 1 — The repository skeleton

### 1.1 Create the repo

```bash
mkdir -p "$DEV" && cd "$DEV" && git init -b master
julia -e 'using UUIDs; println(uuid4())'          # → the uuid for Project.toml
```

`Project.toml`:

```toml
name = "GBGCodingTools"
uuid = "<uuid4 above>"
version = "1.0.0"
[deps]
TOML = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
SHA = "ea8e919c-243c-51af-8825-aaa63cd721ce"
Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
Gumbo = "708ec375-b3d6-5a57-a7ce-8257bf98657a"
AbstractTrees = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
[weakdeps]
Documenter = "e30172f5-a6a5-5a46-863b-614d45cd2de4"
[extensions]
GBGCodingToolsDocumenterExt = "Documenter"
[compat]
julia = "1.11"
JSON3 = "1"
Gumbo = "0.8"
AbstractTrees = "0.4"
Documenter = "1.17 - 1.19"
```

`Documenter` is a **weak** dependency (§2 D9): the main module declares `function makedocs end`, and
`ext/GBGCodingToolsDocumenterExt.jl` defines `GBGCodingTools.makedocs(cfg; kwargs...)`; the compat
bound stays and binds only environments that hold Documenter. `Gumbo` and `JSON3` are hard
dependencies.

Tree (create every directory; one-line purposes in §3):

```
Project.toml CHANGELOG.md README.md fleet.toml install.sh bin/gbg
src/{GBGCodingTools.jl,DocLints.jl,TestHarness.jl,Reflection.jl,Witnesses.jl,TreeHash.jl,HtmlWalker.jl}
ext/GBGCodingToolsDocumenterExt.jl                     # the Documenter extension (weak dependency): defines GBGCodingTools.makedocs
src/CLI/{Main.jl,Config.jl,Schema.jl,Doctor.jl,Sync.jl,Init.jl,Fleet.jl,Bump.jl,Release.jl,Install.jl,
         Preflight.jl,Rounds.jl,Gate.jl,Demote.jl,Scan.jl,Seed.jl,Recall.jl,Consolidate.jl,
         Audit.jl,Hunt.jl,Selftest.jl,consolidate.py}     # consolidate.py: the ONE transitional Python file; deleted in 1.6
src/Scans/<one file per scan id of §12.B>.jl
instruments/{check-docs,check-consistency,bug-hunt,audit-changes}/{PROTOCOL.md,schema.json,workflow/,selftest/}
catalog/{hats/,lanes/,scans.toml,models.toml,seeds/fixture.toml}
policy/{00-index.md,docs-rubric.md,latex-idiom.md,citations.md,testing-protocol.md,instruments.md,git-conventions.md,glossary.md,RULES.toml}
schema/*.schema.json   templates/*   "fixture/GBG Fixture/"   test/runtests.jl   test/regressions/   docs/ARCHITECTURE.md
docs/{Project.toml,make.jl,prose_shape.csv,src/index.md,src/guide/,src/api/}   .gbg/   .claude/skills/   CLAUDE.md
.github/workflows/{CI.yml,docs.yml}                    # docs/, .gbg/, .claude/skills/, CLAUDE.md's block and docs.yml are 1.10's
```

`CHANGELOG.md`: `## Unreleased` then `## 1.0.0 — <date>` with the entry shape of §8 (1.10 item 7 adds
the `## 1.0.0-rc.1 — <date>` entry the prerelease release requires, above it). `README.md`: the
design sentence, the three bootstrap commands, the exit contract. `fleet.toml`:

```toml
[sweep]                                  # written by `gbg bump` when a bump leaves the fleet at two versions
# started = 2026-09-20, from = "1.0.0", to = "1.0.1"
[[consumer]]                             # the tool's own row (§2 D15): pin dev+<sha>[-dirty], OK/RED by its own doctor, never BEHIND
name = "GBGCodingTools";         path = ".";                                                   github = "GrigorySarnitsky/GBGCodingTools.jl"
[[consumer]]
name = "GBGPeriodicFields";      path = "../../Isotropic Turbulence/GBGPeriodicFields";      github = "GrigorySarnitsky/GBGPeriodicFields.jl"
[[consumer]]
name = "GBGIsotropicTurbulence"; path = "../../Isotropic Turbulence/GBGIsotropicTurbulence"; github = "GrigorySarnitsky/GBGIsotropicTurbulence.jl"
[[consumer]]
name = "GBGStreamingStatistics"; path = "../../Statistics/GBGStreamingStatistics";           github = "GrigorySarnitsky/GBGStreamingStatistics.jl"
[[consumer]]
name = "GBGCloudPhysics";        path = "../../Cloud Physics/GBGCloudPhysics";               github = "GrigorySarnitsky/GBGCloudPhysics.jl"
```

A `path` that does not exist is exit 2 for `gbg fleet`, never a skipped row; the tool's own row is `OK`
or `RED` by its doctor alone (§2 D4). Copy `docs/ARCHITECTURE.md` from the design output verbatim (1.10
makes its one structural edit, the `## Revision history` heading).

### 1.2 The shim `bin/gbg` (POSIX sh, ≤ 30 lines)

Semantics (write exactly this; the shim holds no Julia code and reads no depot slug — it only decides
which `--project` to exec Julia against). The exec line, written once:
`exec julia --startup-file=no --project="$P" -e 'using GBGCodingTools; exit(GBGCodingTools.main(ARGS))' -- "$@"`.
(1) `--dev` as first argument → `shift`, read the dev checkout path from `~/.gbg/dev` (exit 2 "no dev
checkout registered" if absent), `P="<dev>"`, `GBG_DEV=1`, exec. (2) Walk up from `$PWD` to the first
directory holding `.gbg/config.toml`; none → the same `~/.gbg/dev` route (for `fleet`, `release`,
`new`, `selftest`). (3) Read the first `version = "…"` line after the `[tool]` line with `awk`. (4) If it
is `dev` and the root found in (2) itself holds a `Project.toml` containing `name = "GBGCodingTools"` —
the tool's own root, its own consumer (1.10) — fall through to (5): the tool's `docs/` environment
resolves the tool by `path = ".."`, so this is the working tree (§2 D2's bootstrap circularity); if it
is `dev` otherwise (the fixture): walk up further to a `Project.toml` containing
`name = "GBGCodingTools"`, `P="<that dir>"`, exec; none → exit 2. (5) Otherwise `P="<root>/docs"`; if `"$P/Manifest.toml"` is absent or does not
contain `GBGCodingTools` → print `package not instantiated` and
`run: julia --project=docs -e 'using Pkg; Pkg.instantiate()'` to stderr, `exit 2`; else exec — Pkg's
resolution of the docs environment (its manifest and `[sources]` entry) IS the version selection.
`gbg install [--dev-checkout <path>]` copies this file to `~/.local/bin/gbg` with mode 755 and writes
`~/.gbg/dev` (one line) when the option is given; `install.sh` in the dev checkout runs the verb
against the checkout itself (`julia --startup-file=no --project="$PWD" -e '…main(ARGS)…' -- install
--dev-checkout "$PWD"`). `SHIM.HASH` compares the two bodies and requires `command -v gbg` to be
`~/.local/bin/gbg`; `ENV.DEV_CHECKOUT` (WARN) checks `~/.gbg/dev`.

### 1.3 The CLI: verbs, exit contract, modules

Exit contract (every verb): **0** clean · **1** substantive finding · **2** cannot evaluate (incl. a
DEAD lane and a missing path) · **3** crash. `GBGCodingTools.main(ARGS)::Int` (`src/CLI/Main.jl`) is
the one entry point: it dispatches `<noun> <verb>` to a Julia function that returns the exit code and
wraps that call in `try … catch` → the backtrace to stderr, return 3, so an exception is never read
as a finding. Output is never truncated. `main` accepts `--dev` as its first argument exactly as the
shim does (sets `GBG_DEV=1`, stamps `dev+<sha>[-dirty]`), so the dev checkout runs without the shim
through the `gbgdev` function defined at the top of this plan.

| Verb | Does | Module |
|---|---|---|
| `gbg --version` | prints the running copy's version (`dev+<sha>` under `--dev`) | `Main.jl` |
| `gbg install [--dev-checkout <path>]` | writes `~/.local/bin/gbg` and, with the option, `~/.gbg/dev`; checks `julia` (≥ the floor, via `juliaup`); runs from whichever copy Pkg resolved — no depot glob | `Install.jl` |
| `gbg doctor [--deep] [--json] [--effective] [--only <id-or-prefix>[,…]\|QUICK]` | §7.3; read-only; `QUICK` is the named set of §7.3 | `Doctor.jl` |
| `gbg self verify` | recomputes the running copy's git tree hash and compares with the manifests (`PIN.SELF`); run by every `round` verb and by `gate`; git blob/tree hashing on the `SHA` stdlib, checked against `Pkg.dependencies()[uuid].tree_hash` and `is_tracking_repo && !is_tracking_path` | `TreeHash.jl` |
| `gbg fleet [--deep] [--diff <consumer>:<round> <consumer>:<round>]` | scorecard over `fleet.toml` (dev checkout only): one row per consumer with `status ∈ OK\|NOT-INITIALISED\|BEHIND\|RED` and the exit contract of D4; the 7-day `[sweep]` window; missing path ⇒ 2; `--diff` prints two closed rounds' tallies side by side and refuses unequal `MAJOR.MINOR`; the tool's own row (`path = "."`, 1.10) prints `dev+<sha>[-dirty]` with `clean at vX.Y.Z` or `off tag` as its detail, is `OK`/`RED` by its own doctor and never `BEHIND` (§2 D4) | `Fleet.jl` |
| `gbg probe [--fail]` | exists for V2 (Phase 1.9) and nothing else: prints `PROBE OK`, exit 0; `--fail` prints `PROBE FAIL` to stderr, exit 2; no file is read or written | `Main.jl` |
| `gbg init [--migrate] [--dry-run]` | seeds `.gbg/` (the config from the package tree, a placeholder persona file for every `domain_hats` key without one, `.gbg/seeds.toml` where the package has a seed list to migrate — PF, IT; SS and CP write theirs when they first seed), the S-class files, `test/Project.toml` if absent, and renders the `[deps]/[sources]/[compat]` entries into every sub-env that lists the tool (so `Pkg.instantiate()` can follow before `sync`); it does NOT render the G files or the CI snippets — that is `sync`, which validates the config `init` wrote; `--migrate` additionally runs `migrate baselines` and writes `.gbg/scratch/commit-message.txt`; legacy piles are imported by `round import`, a separate step; `--dry-run` prints what it would write; it works when the consumer IS the tool root — `$DEV`, 1.10 — writing the pin `dev` and the `path = ".."` source into `docs/Project.toml` | `Init.jl` |
| `gbg migrate baselines [--dry-run]` | run by `init --migrate` and by hand: a TEXTUAL converter (Julia regexes over the file text — the `.jl` files are read, never `include`d) from the consumer's existing test files to the three S-class TOMLs `TestHarness` reads — `test/method_parity.jl` → `test/method_parity_baseline.toml` (every `baseline = (("<name>", <f>, <n>), …)` tuple of a `@testset`, keyed by the testset name, as `[[generic]] set, name, count`, plus `const MODULE_BASELINE = (<Module> = <n>, …)` as `[module] <Module> = <n>`; a `#` comment beside a count kept as `reason`); `test/pass_audit.jl` → `test/pass_audit_baseline.toml` (every `audit(() -> …, "<row>", Traffic("<label>", …, (<reads>, <writes>)), …)` call as `[[row]] name, arrays = [{label, reads, writes}]`, the counts kept as the symbolic strings the file writes — `"3P"`, `"2M"`, `"0"` over the two symbols `P`/`M` it defines — which `TestHarness.audit` evaluates against the fixture grid at run time; a holder comment kept as `holder`); `test/oracle_registry.jl` → `test/oracle_registry.toml` (`const ORACLE_PROVENANCE = Dict(:<op> => (:<class>, "<evidence>"), …)` as `[[operation]] name, class, evidence`). A literal it does not find is reported and skipped (IT, SS and CP hold none of the three; exit 0); a literal found but not parsed to its closing paren is exit 2 naming the line; an existing TOML is refused (exit 2) unless `--dry-run`, which prints instead of writing; the `.jl` files are never edited — PF-4 does that by hand | `Init.jl` |
| `gbg new <Pkg>` | `init` for a fifth package + a `fleet.toml` entry | `Init.jl` |
| `gbg sync [--check]` | validates the config, then renders every G file (the skills, `managed.json`, `.gbg/policy/`, the `CLAUDE.md` and `.gitignore` blocks, `.claude/hooks/queue-guard.sh` (PF's script verbatim, pure sh) and `.claude/settings.json` — in every consumer, §A's Stop-hook ruling — `test/regressions/README.md`), seeds `.claude/WORK_QUEUE.md` if absent (class S: the header alone, never touched again), the `[deps]/[sources]/[compat]` entries into every sub-env `Project.toml` that lists the tool, and the CI snippets at the insertion points of 1.7; refuses MODIFIED; idempotent | `Sync.jl` |
| `gbg config --toml\|--json [--effective]` | prints the validated config with defaults materialised — the object `Config.read()` returns in-process (the validator is `Schema.jl`, called by both); `--toml` and `--json` are printers for humans and scripts | `Config.jl` |
| `gbg preflight <instrument> [--profile all\|core\|explicit] [--strength full] [--no-seed] [--dry]` | quick doctor + `CFG.TORN` + self verify + round open + copies the instrument's `workflow/*.js` from the running copy into `.gbg/scratch/<round>/workflow/` (V1: a Workflow `scriptPath` must lie inside the project) + prints protocol, Workflow call (naming that copy), next step; `--dry` opens nothing and copies nothing, printing the path it would use; owns THE Workflow-args renderer (`pass open` calls it for the verifier scripts, copied the same way) | `Preflight.jl` |
| `gbg round prepare\|build\|test\|bank\|rerun\|grade\|close\|abandon\|list\|render <round>`, `gbg round pass open <round> [--regrade]` | §6; `build`/`test` run `docs_build`/`julia_test` under `GBG_ROUND`; re-grading is only ever `pass open --regrade` (no `regrade` alias); every `round` verb runs `self verify` and `CFG.TORN` first (`CFG.TORN` is outside `QUICK`: `preflight` and the `round` verbs are its only callers) | `Rounds.jl` |
| `gbg round import <pile…>`, `gbg round import --empty <round> --reason "…"` | §8: converts each legacy pile into `.gbg/rounds/<round>/` (creating `.gbg/rounds/` if absent) with `ROUND.toml`, `findings.json`, the reconstructible passes/witnesses and `import.json`; needs no `.gbg/config.toml` (the one `round` verb that runs before `init`); refuses an existing round (exit 2); `--empty` writes a round holding only `ROUND.toml` (`abandoned`) and `import.json` (`source = "none"`). **Phase 2's scratch verb**: an imported round is graded, compared and DELETED in the same phase, never committed (§A, the no-history ruling); a consumer's `.gbg/rounds/` starts empty | `Rounds.jl` |
| `gbg round compare --recorded <recorded.toml> <round>` | §8: compares an imported round's re-graded tally with the four counts of a hand-transcribed `recorded.toml`; one meaning only (the cross-version round comparison is `gbg fleet --diff`) | `Rounds.jl` |
| `gbg gate [instrument…]` | the closure gate; honours `GBG_ROUND`; scans every round directory; the CLI face of `gate(instruments...)`, which `makedocs` and `TestHarness.gate()` call in-process | `Gate.jl` |
| `gbg scan docs [--hard-only] [--rebaseline prose-shape --reason …]`, `gbg scan html <build_dir>` | the tiered scan engine (§12.B); `scan_docs`/`scan_html` are what `makedocs` calls in-process | `Scan.jl` + `src/Scans/` |
| `gbg seed <round>` / `gbg recall <round>` | called by `prepare`/`bank`; also standalone; the catalogue is the consumer's `.gbg/seeds.toml` | `Seed.jl`, `Recall.jl` |
| `gbg witnesses fail\|pass <round> [names…]` | wraps `Witnesses.run` | `Hunt.jl` |
| `gbg audit-changes bank <round>` / `gbg bug-hunt bank <round>` | instrument-specific bank steps (the audit bank runs the executable claims under `GBG_ROUND`) | `Audit.jl`, `Hunt.jl` |
| `gbg bump <ver> [--abandon-open-rounds "…"]` | moves the pin, runs `sync`, writes `.gbg/scratch/bump-message.txt`, records the fleet `[sweep]` window | `Bump.jl` |
| `gbg release <ver>`, `gbg release <ver>-rc.<n>` | dev checkout only, at a clean tree; refuses (exit 2) unless `Pkg.test()` is green, the tool's own docs build exits 0 (`SELF.DOCS`), `gbg doctor --deep` is green at the tool root, no round is open under the tool's `.gbg/rounds/`, the `/check-docs` round opened at the latest `<ver>-rc.<n>` tag is closed (honored/adjudicated, never abandoned), the CHANGELOG entry is present and the tag is absent (§2 D16, §8) → tag + push; never re-tags. The prerelease form (tags `v1.0.0-rc.1`, …) runs the same refusals EXCEPT the open-round refusal and the closed-`/check-docs`-round precondition — the clean tag the tool's own instrument rounds open at (1.10 item 7); an rc tag is never a consumer pin (`PIN.SOURCES` refuses a `-rc.` rev outside the tool root) | `Release.jl` |
| `gbg selftest [--pinned]` | a thin wrapper: runs the package's own `Pkg.test()` — which IS every arm of §8 — over the copy it runs from, from a temporary environment; `--pinned` copies the fixture to `${TMPDIR:-/tmp}/gbg-pinned-fixture/`, pins it at the released tag, instantiates `docs/`, exercises the pinned-copy behaviours and leaves the copy in place (Phase 3's `install` runs from it) | `Selftest.jl` |
| `gbg schema <name>` | prints a schema with defaults | `Schema.jl` |

No other verb exists; a verb used anywhere in this plan is in this table (`gbg probe` is the one verb with no consumer purpose, kept because V2 needs a `gbg` that exits both ways). The former
`gbg hook queue-guard` does not exist: the Stop hook is a rendered `sh` file (1.6, 1.7) — PF's
`queue-guard.sh` verbatim, guarding `WORK_QUEUE.md`, never reading `.gbg/rounds/` — and never
starts Julia. `Schema.jl`: the JSON-Schema-subset validator (types, `required`, `enum`, `pattern`,
`additionalProperties`, nested objects/arrays) over a `Dict` — ~150 lines, no JSONSchema.jl;
`Config.jl` loads TOML (`TOML.parsefile`), validates, materialises defaults, checks every path; every
other module receives the validated `Dict`.

### 1.4 Julia modules

- `src/GBGCodingTools.jl`: the module; includes `src/CLI/*.jl` (the verbs and `main`), `src/Scans/*.jl`,
  `TreeHash.jl`, `HtmlWalker.jl` and the four modules below. There is no child process anywhere: a
  verb's function is called directly. `makedocs(cfg; kwargs...)` — declared `function makedocs end`
  in the main module and DEFINED by the extension `ext/GBGCodingToolsDocumenterExt.jl`, which Julia
  loads once `Documenter` is in the environment (a consumer's `make.jl` already does
  `using Documenter`, so the wrapper exists in the docs environment and nowhere else; `gbg doctor` and
  every other shim call load no Documenter) — = `check(doctor(:QUICK))` (`QUICK` excludes
  `CFG.TORN`), `check(scan_docs(cfg; hard_only = true))`, `check(gate("check-docs", "check-consistency"))`, write
  `.gbg/scratch/public_surface.json` from `TestHarness.package_operations()`,
  `Documenter.makedocs(; kwargs...)`, `check(scan_html(build_dir))`,
  `check(gate("check-docs", "check-consistency"))` again — where `check(code)` is
  `code == 0 || error("gbg <verb> returned $code")`; prints one banner line
  `GBGCodingTools v<ver> makedocs` (the `BUILD.DOCS` witness). Never the bare `gate()` over all four
  instruments — a docs build must not fail on an open hunt round. Inside a
  `gbg round prepare|build|pass open`, the CLI has exported `GBG_ROUND`, so the gate inside this
  wrapper ignores that round. This wrapper is the per-push enforcement point (§2 D9): the doctor, the
  hard scans and the gate stay here, never moved into the manual CI. The tool's own `docs/make.jl`
  (1.10) calls this same wrapper with `checkdocs = :exports` and `doctest = true`.
- **Docstrings, every module.** Every public binding carries a docstring written to the shared rubric
  (`policy/docs-rubric.md`): `main`, every verb function, `makedocs`, every `TestHarness`/`Reflection`/
  `Witnesses`/`Config` export, every schema struct (`The fields are` bullets); each module docstring
  is a map. `checkdocs = :exports` in the tool's own `makedocs` call fails the build on a missing one,
  and `guide/verbs.md` and `api/CLI.md` are rendered from these docstrings through `@docs`, so the verb
  table of 1.3 has one source.
- `src/CLI/Config.jl`: `read(root = pwd())` → `TOML.parsefile(".gbg/config.toml")` validated by
  `Schema.jl`, defaults materialised, paths checked — the object `gbg config --toml` prints.
- `src/TreeHash.jl`: git blob and tree hashing on the `SHA` stdlib (~80 lines; `gbg self verify`,
  `PIN.SELF`, `PIN.TREESHA`), compared with `Pkg.dependencies()[uuid].tree_hash` and asserting
  `is_tracking_repo && !is_tracking_path` (a `Pkg.develop`'d copy lives inside the depot, §2 D3).
- `src/HtmlWalker.jl`: the `Gumbo` + `AbstractTrees` walker (hand-rolled traversal — Gumbo has no CSS
  selectors) shared by `Consolidate.jl` and the four `SCAN.HTML_*` scans.
- `DocLints.jl`: the bare `function makedocs end` declaration and its docstring, exported; the body
  is the extension's (`ext/GBGCodingToolsDocumenterExt.jl`).
- `TestHarness.jl`: port from PF — `@alloc_below` + `field_threshold` + the derived completeness check
  (`test/allocations.jl:45-61, 600-624`), `CountingArray`/`Traffic`/`audit` (`test/pass_audit.jl:57-122`),
  the method-parity engine (`test/method_parity.jl:277-318`; frozen tables become
  `test/method_parity_baseline.toml` in the consumer), the oracle-registry engine
  (`test/oracle_registry.jl:146-198`), `package_operations` (`test/public_surface.jl:27-74`; the only
  public-surface route), `run_regressions(dir)` (`test/runtests.jl:47-52`, one spelling), the display gate
  (`test/display.jl:36-75` + IT's `!(object isa UnionAll)` clause and planted-type falsification,
  `IT/test/display.jl:65-66,100-102`), the cross-`-t` subprocess bitwise check (`test/threading.jl`),
  `gate()` = `check(doctor(:QUICK))` (`QUICK` excludes `CFG.TORN`) +
  `check(gate("bug-hunt", "audit-changes"))` in-process + the
  banner line `GBGCodingTools v<ver> gate` (the `TEST.PKG` witness).
- `Reflection.jl`: `argcov` (PF `check-docs/argcov.jl` exemption classes + IT's identifier class
  `[A-Za-zα-ωΑ-Ω][…̂]*` + the `arg = default` form; the "Allocating form of" exemption phrase and the
  ≥ 3 threshold as constants; tier from `argcov_policy`; applies an entry's `[exemption.match]`
  predicate itself and reports its trigger population, §7.2), `signature_fidelity`
  (IT `signature_fidelity.jl`, package from config), `xlink` (IT `xlink.jl`, dry-run default,
  `apply = true` explicit), `dupref` (IT `dupref.jl`).
- `Witnesses.jl`: `run(dir; expect::Symbol, names = String[])` from PF `witnesses.jl` (directory as
  argument, PF's `!asserted` guard — a PASS with zero assertions reads BROKEN) + IT `witnesses.jl`
  (`Base.julia_cmd()`, `--project=<witness_env>`, `(\d+) errored` regex, BROKEN ⇒ non-zero, subset
  filter, empty ⇒ 2); adds `BLOCKED` (a witness whose header declares `# blocked: <reason>` — the reason
  REQUIRED — and errors is reported apart, exit unaffected); **refuses** (exit 2, naming the file) any
  witness body containing `include(` or a `using`/`import` of anything but the package under test,
  `Test` and the stdlib.

### 1.5 Workflow scripts (migrated; each source named, each change named)

Common changes to every script: `args` parsed as `typeof args === 'string' ? JSON.parse(args) : args`;
**no package name, no path, no round data in the source** — all from `args`; every agent told to
`Write` its JSON lane file FIRST, then return the same object; every agent forbidden to open `.gbg/**`
and `~/.gbg/**`; the script returns liveness only (`{written, dead, empty, truncated}`), never a tally;
economy `model` from `args.models.economy`; anchors from `args`; a one-line header naming the args
schema. Source paths are `<consumer>/.claude/commands/…` with their REAL spellings (IT's
check-consistency scripts use underscores).

| Target | Sources | Changes beyond the common ones |
|---|---|---|
| `instruments/check-consistency/workflow/panel.js` | PF `check-consistency/panel.js` (parallel, dead/empty/TRUNCATED), IT `check-consistency/panel.js` (profile/subset `:254-286`, hats.json) | hats arrive resolved and numbered in `args.hats[]` (the CLI applies profile/subset and assigns `NN`); delete the census agent and `hats.json`; delete the "sequential" header; adjudicated titles from `args.adjudicated_titles`; manuscripts, rulebook and personas as FILES under the round's payload directory, their paths in `args` (ARCHITECTURE Revision 9 — a script has no filesystem and the session re-emits `args` verbatim, so no payload travels inside them) |
| `…/verify-act.js` | PF `check-consistency/verify-fixes.js` (per-lane over hat piles, mechanical demotion note), IT `check-consistency/verify-fixes.js` (eight verdicts, `question`, array `class_surfaces`, `batches`) | verdict object `{id, verdict, question, evidence, class_surfaces[{surface, swept, evidence}]}`; output must carry `graded_sha256` and `pass_nonce` from args; `range` required; `mode ∈ lanes\|batches` from args; no demotion inside (the CLI does it); delete the `RANGE:` first-line request; finding text passed unabridged |
| `…/verify-state.js` | PF `check-consistency/verify.js` (blind, regenerated manuscripts), IT `check-consistency/verify.js` (PARTIAL/`surviving_class`, repo grep, `--glob '!.claude/**'`) | vocabulary of §6.3 incl. UNCLEAR; grep scope `--glob '!.gbg/**'`; nonce + sha; no census |
| `…/severity-recheck.js`, `…/rubric-audit.js` | IT `check-consistency/severity_recheck.js`, IT `check-consistency/rubric_audit.js` (underscores in the sources; hyphens in the targets) | generic `subject` from args; `severity-recheck.js` also invoked by the audit-changes round before "serious" is counted |
| `instruments/check-docs/workflow/lanes.js` | IT `check-docs/lanes.js` (fan-out), PF `check-docs.md` mechanism (Write-first banking, family and cold-reader lanes, the `?name` substrate rule) | surfaces and lanes from `args` (engine lanes + `lanes_extra` resolved by the CLI); delete the dated rename note (`lanes.js:51`); `operational-claims` lane on the docstring surface |
| `instruments/bug-hunt/workflow/hunt.js` | IT `bug-hunt/hunt.js` (pipeline, reproducer stage, `kind`/`severity`/`files_read`, quoted paths), PF `bug-hunt/hunt.js` (territories, mandatory mechanical re-run) | lanes = `args.territories` + two free lanes (anchored); witness file `witnesses/<lane>-<n>.jl` inside `args.round_dir`; `lanes` subset only as the CLI passes it (DEAD lanes); ALREADY-COVERED requires `evidence` (file:line); BLOCKED admitted with a header reason; oracle list from args; no `include(` in a witness |
| `…/dismissals.js` | PF `bug-hunt/dismissals.js` (`complete = dead == 0 && reopened == []`, third shape) | postmortem examples removed (package-neutral); invoked at EVERY instrument's close over the finding-scope ledger entries |
| `…/verify-architecture.js` | IT `bug-hunt/verify-fixes.js` | renamed; vocabulary `FIXED\|RELOCATED\|PARTIAL\|ABSENT\|NOT-A-DEFECT`, default ABSENT |
| `instruments/audit-changes/workflow/audit.js` | IT `audit-changes/audit.js` (`base` required, `kind` switch, `checked[]`, `candidates_found`, pin-at-base, test-in-diff), PF `audit-changes/audit.js` (`previously_worked`, `strength` honoured) | lanes from `catalog/lanes/audit-changes.toml` via args; `previously_worked ∈ yes\|no\|unknown` required on behaviour-change; diffstat, claims, guard symbols, invariants text from args (delete "605 lines…" and the round-specific candidate lists, `audit.js:67,134-140`); `meta.name = 'audit-changes'` |
| `…/attack-design.js` | IT `audit-changes/attack-design.js` | generic; default CONTEXT removed, `subject` required |

### 1.6 Engines (migrated to Julia — the sources are the old scripts; the targets are `src/CLI/*.jl` and `src/Scans/*.jl`)

| Target | Sources | Changes |
|---|---|---|
| `src/CLI/Gate.jl` | PF `audit-changes/gate.py` (staleness `git diff <audited>..HEAD -- covered`, UNCHECKABLE, refusal ≥ 24), IT `audit-changes/gate.py` (empty-audit rule, capped-lane report), PF `make.jl` `lint_review_closure` (per-finding), IT `make.jl` `lint_review_closure` (marker rule) | one gate over `.gbg/rounds/`; per-finding by id; §6.2 step 10 incl. `GBG_ROUND`, every round directory, the untracked-round rule |
| `src/CLI/Rounds.jl` `bank` | PF/IT `check-consistency/coverage.py` | roster from `ROUND.toml`; classes DEAD/EMPTY/ORPHAN/TRUNCATED/REJECTED (D10); JSON lane files; DEAD ⇒ exit 2, nothing frozen; `lane_shas`; SUSPECT flag; `reproductions_sha` for hunts |
| `src/CLI/Demote.jl` | IT `check-consistency/verify-fixes.js:196-210` (emptiness rule) | the ONE predicate; share reported |
| `src/CLI/Recall.jl` | PF `check-consistency/recall.py` (unverifiable seeds kept, UNDEFINED), PF `check-consistency/recall_selftest.py` (arms A–D) | arms built in the test; SUSPECT computed here |
| `src/CLI/Seed.jl` | PF/IT `check-consistency/seed_defects.py` | mechanism only; catalogue from the consumer's `.gbg/seeds.toml` (`config.seed_catalog`; the fixture's is `catalog/seeds/fixture.toml`); per-round salt; writes to `.gbg/scratch/<round>/` |
| `src/CLI/consolidate.py` → `src/CLI/Consolidate.jl` (**transitional**) | the three byte-identical `check-consistency/consolidate.py` | STEP 1: copy the shared script into the tool as `src/CLI/consolidate.py` — the ONE transitional Python file, versioned inside the package — and have `Consolidate.jl` `run` it ONLY while the port is pending (withhold list from config; output under `.gbg/scratch/<round>/`). STEP 2: write `Consolidate.jl` over `HtmlWalker.jl` (`Gumbo` + `AbstractTrees`, hand-rolled tree walking — Gumbo's C parser is unmaintained and has no CSS-selector traversal). **ACCEPTANCE TEST:** run both over a real PF build AND a real IT build (`docs/build` after each consumer's `julia --project=docs docs/make.jl`) and `cmp` the resulting `manifest-{full,siteonly}.md` pairs — all four must be byte-equal; the commit that passes deletes `consolidate.py` and the `run` call in the same change, and `test/runtests.jl` asserts the file is absent from then on. The riskiest single port in either plan: do it with the fallback in hand, and do not tag 1.0.0 with the Python still present |
| `src/TreeHash.jl` | new (git blob/tree hashing on the `SHA` stdlib, ~80 lines) | `gbg self verify`; `PIN.SELF`; `PIN.TREESHA` |
| `src/CLI/Rounds.jl` `import` / `compare` | new: one reader per legacy pile format of §8's table (`pf-doc-review`, `pf-check-docs`, `pf-findings-json`, `it-closure`, `it-audit-latest`, `it-rounds-json`) | writes `.gbg/rounds/<round>/` + `import.json`; `--empty`; `compare --recorded` over `recorded.toml` (§8) |
| `src/CLI/Init.jl` `migrate baselines` | new (~120 lines, Julia regexes over the file text) | the textual literal → TOML converter of 1.3; the `.jl` files are read, never `include`d |
| `src/Scans/*.jl` | the sources column of §12.B: PF `check-docs/{sentence_openers.py, field_docs.py, link_uniformity.py, doi_crosscheck.py}`, IT `check-docs/{abutting_spans.py, doi_crosscheck.py}`, PF `check-docs/guards.sh` (every `hard`/`soft` line), IT `check-docs.md` deterministic block, PF `docs/make.jl` `lint_inline_math`/`lint_notation_variants`/`lint_swallowed_escapes`/`lint_retired_claims`/`lint_api_page_structure`/`lint_prose_shape`/`lint_ai_banner`/`lint_rendered_markup`, IT `docs/make.jl` `lint_notation_variants` (the five regexes) and `lint_docstring_shape` | one file per scan id, registered in `catalog/scans.toml` with `id, rule, tier, surfaces, runner (julia\|html), fixture`; the four `SCAN.HTML_*` scans share `HtmlWalker.jl` with the consolidator; surfaces from config; `docs.retired_claims` from config; `NO_FIELD_LIST` from the ledger; comment-line filters kept; `references_heading = "absent"` ⇒ whole-file DOI comparison |
| `src/CLI/Rounds.jl` `close` (hunt) | IT `bug-hunt/finished.py` (nine checks) | delegates to the audit gate; ordering of §6.7; `closure.py` deleted |
| `templates/queue-guard.sh.tmpl` → rendered as `.claude/hooks/queue-guard.sh` (class G) | PF `.claude/hooks/queue-guard.sh` | PF's script **verbatim**, pure `sh`, rendered by `sync` in EVERY consumer (§A's Stop-hook ruling; no config switch): guards the `- [ ]` items of `.claude/WORK_QUEUE.md`, the `stop_hook_active` loop guard kept; it never reads `.gbg/rounds/` and never starts Julia — the hook guards the work queue, the gate guards the rounds, and the two never overlap (§2 D13). `templates/WORK_QUEUE.md.seed` is the header of PF's file (the contract paragraph, no items), seeded once by `sync` where the file is absent |
| deleted | IT `bug-hunt/closure.py`, both `manifest.py`/`MANIFEST.txt`, IT `check-consistency/rubric_extract.py`/`rubric_prep.py` (their constants are package-specific; the rubric-audit mechanism ships only as `rubric-audit.js` — no `calibrate` verb, see Phase 8 deferred) | — |

### 1.7 Catalogues, schemas, templates, policy, fixture

- `catalog/hats/*.toml`: the eight generic hats shared by PF and IT — `consistency-matrix`,
  `software-architect`, `structure-consistency`, `latex-typesetter`, `api-user`, `citations-integrity`,
  `style-editor`, `cold-reader` (PF `check-consistency/panel.js:80-124` personas with
  `{package.description}`, `{package.terms}` placeholders) + IT's generic lenses (`free-reader-a/b/c`,
  `logician`, `plain-sense`, `existence-auditor`, `quantifier-auditor`, `conjunction-coverage`,
  `conceptual-clarity`, `reader-standpoint`, `fossil-and-drift`) + the three rulebook hats
  (`naming-policy`, `doc-policy`, `invariants-and-decisions`, generic, their rulebook sections filled
  from `{package.rulebook_sections}`). Domain hats never enter the catalogue: PF's
  `gpu-kernel-practitioner` and `normalization-convention-auditor` are PF's `.gbg/hats/`, as are
  IT's `turbulence-theoretician`, `dns-practitioner`, `external-standard`, `dimensional`.
- `catalog/lanes/`: `check-docs.toml` (the engine lanes: one per surface key + `family` +
  `cold-reader` + `operational-claims`), `bug-hunt.toml` (the two free lanes, `anchor = true`),
  `audit-changes.toml` (IT's code and prose lanes, anchors marked; `executing` anchored).
- `catalog/scans.toml` (§12.B verbatim), `catalog/models.toml` (`economy = "sonnet"`),
  `catalog/seeds/fixture.toml` (eight classes anchored to the fixture text — the ONE seed catalogue in
  the tool; a consumer's is its own `.gbg/seeds.toml`, class C, written by `gbg init` at Phases 4 and 5
  from PF `check-consistency/seed_defects.py:39-56` and IT `check-consistency/seed_defects.py:31-48`).
- `schema/*.schema.json`: the eighteen of §2 D11 — `config, exemptions, hat, round, pass, lane-file,
  finding, verdict-act, verdict-state, tally, hunt-candidate, reproduction, dismissal,
  architecture-fix, audit, ground-truth, import, managed` — closed enums of §6.3; each instrument's
  `schema.json` = args + lane-file wrapper `$ref`-ing `finding.schema.json`; `exemptions.schema.json`
  admits the optional `[exemption.match]` table on the scopes `scan|lint|policy|harness` only, with
  the ANDed sub-keys `arg_name` (a regex over the argument name), `arg_type` (the declared type of the
  matched argument, tested by `<:` — evaluable by the reflection scans `SCAN.ARGCOV`,
  `SCAN.SIGNATURE_FIDELITY` and anything under `Reflection` only; the schema admits the key and
  `CFG.EXEMPTIONS` REFUSES it, exit 2, on an entry a text scan would apply — never ignores it), `path`
  (a glob) and `symbol` (a regex over the owning binding's name); every engine with a trigger
  population, `Reflection.argcov` included, applies the predicate itself and reports the population,
  which is what `EXEMPT.BROAD` dry-runs over; the `seeds` definition a consumer's `.gbg/seeds.toml`
  validates against lives in `instruments/check-consistency/schema.json`, not among the eighteen.
- `templates/`: `SKILL.md.tmpl` (frontmatter `name`, `description` with version, `allowed-tools: Bash(gbg *)`;
  body = the managed header + one `!` block `gbg preflight <instrument> $ARGUMENTS`; for `gbg-doctor`
  the block is `gbg doctor` — it is not an instrument; ≤ 15 lines), `settings.json.tmpl` (hook command
  `"$CLAUDE_PROJECT_DIR/.claude/hooks/queue-guard.sh"`), `queue-guard.sh.tmpl` (PF's `queue-guard.sh` verbatim — the
  pure-sh Stop hook body of 1.6, rendered in every consumer), `WORK_QUEUE.md.seed` (the checklist's
  header, seeded once), `CLAUDE.md.skeleton` (the uniform section order every consumer's `CLAUDE.md`
  follows after migration — §A: managed block, "Modules and wiring", "Core invariants", the package's own
  style rules, "Working agreements", one "Current state" paragraph pointing at `docs/ROADMAP.md`; used by
  `gbg new` as the seed and by each migration's trim step as the target), `make.jl.seed`
  (`using GBGCodingTools; GBGCodingTools.makedocs(GBGCodingTools.Config.read(); sitename = …)`),
  `runtests.jl.seed` (Aqua/JET calls left to the consumer; `TestHarness.run_regressions(@__DIR__)`,
  `TestHarness.gate()`), `test-Project.toml.seed`, `CI.yml.snippet`/`docs.yml.snippet` (three
  fragments each, with the insertion points `sync` applies and `WIRE.CI_AUTH` checks — §3: the
  `GBG_DEPS_TOKEN` `insteadOf` step as the first step after `actions/checkout`, before any
  `julia-actions/*` step; the build/test step rewritten to tee its output into `gbg-run.log`; a last
  step grepping that log for the banner the job prints — `makedocs` in `docs.yml`, `gate` in `CI.yml`;
  no python step anywhere; a workflow with no `actions/checkout` step makes `sync` exit 2),
  `regressions-README.md` (PF's promotion contract), `gitignore.block` (`.gbg/scratch/` included),
  `claude-md.block`, `commit-message.tmpl` (rendered by `init --migrate`), `bump-message.tmpl`
  (rendered by `bump`).
- `policy/*.md` with the rule ids of §12.A, migrated by heading per §7.1: from PF `CLAUDE.md`
  "Documentation policy — the docstring rubric" (L180–321) and "Style" (L322–893; the shared parts),
  "Verification workflow" (L894–1131; consent gate, instruments, definition of done, oracle
  provenance, both-directions), "Working agreements" (L2657–2685); from IT `CLAUDE.md` "Documentation
  policy" (L135–321), "Doc-edit checklist" (L322–363), "Known weaknesses — self-guards" (L404–504,
  generic guards only); from SS `CLAUDE.md` "Documentation policy — estimand first" (L225–382, as the
  `estimand` value); from CP `CLAUDE.md` "Conventions" (L78–98). Package-specific paragraphs stay
  behind. Write `policy/RULES.toml` (§12.A: id → file, section, statement, `sentinel` = the first sentence
  of the rule's paragraph, verbatim — what `LEG.SENTINELS` matches) and mark the four
  substituted variation points as `{{rubric.leading_identity}}`, `{{notation.vectors}}`,
  `{{docs.admonition_titles}}`, `{{notation.mathbf_allowed}}` slots (`argcov_policy`, the fifth, is a
  tier, not prose).
- `fixture/GBG Fixture/`: a three-module package (`FixtureA`, `FixtureB`, `FixtureC`), docstrings
  planting every scan's defect class of §12.B (`defects.toml`), `docs/` (`make.jl` using the wrapper; its
  `docs/Project.toml` lists `Documenter`, which is what loads the extension that defines the
  wrapper), `test/` (harness calls, one regression), `.gbg/config.toml` validating with
  `[tool] version = "dev"`, one `docs.retired_claims` entry and
  `seed_catalog = "../../catalog/seeds/fixture.toml"`, its sub-env `Project.toml`s carrying
  `[sources] GBGCodingTools = {path = "../../.."}`, two domain hats, no rounds.

### 1.8 Self-tests (`gbg selftest` + `test/runtests.jl`)

Implement every arm of §8: scan/fixture pairs (must hit; clean twin must not); gates both directions +
absence; demotion falsification (IT's five cases + PF's "swept to zero with no list"); recall arms A–D
+ the SUSPECT flag; witness runner over failing/passing/erroring/blocked fixtures + the `include(`
refusal; doctor perturbations with exact ids (incl. a second `gbg` first on PATH, a managed file edited
with its sidecar, a commented-out `GBGCodingTools.makedocs(`); **the gate ignoring exactly the round
in `GBG_ROUND` and failing on any other open round**; a changed `config_sha` refused by every `round`
verb; `--pinned`: an edited pinned copy ⇒ `self verify` exit 2, a `tool_tree_sha` change under one
version ⇒ abandon-only; schema round-trips; `sync` idempotence and MODIFIED; scans-catalogue
completeness; fixture config validation; `CFG.TORN` on a modified `config.toml` (`preflight` and every `round`
verb exit 2, and the same tree passes the `makedocs` wrapper and `TestHarness.gate()` — `CFG.TORN` is
not in `QUICK`); `EXEMPT.BROAD` on a `match` covering more than half of a rule's triggers (WARN); an
`arg_type` sub-key on an entry a text scan would apply (`CFG.EXEMPTIONS` exit 2);
`LEG.SENTINELS` silent on a quoted sentinel, FAIL on a bare one, WARN on a twelve-word run; the
`SELF.CONSUMER` perturbations on a copy of the tool root (its `.gbg/config.toml` removed, its pin moved
off `dev`, a `dev` pin planted in a consumer copy outside the repository — each the exact id; `SELF.DOCS`
is NOT an arm but a release precondition, §8); a round on a perturbed tool-root copy — opened at a
clean tag (a throwaway git repository tagged `v9.9.9`, clean) closes, opened at a clean prerelease tag
(`v9.9.9-rc.1`) closes likewise and is stamped with that tag, opened with the tree dirtied first
refuses `close`, abandon-only (§2 D16); the
Julia tests (`CountingArray` count fixture, `@alloc_below` on a known allocator, the display gate on a
planted type, `makedocs` wrapper on the fixture). Every arm is a testset of `test/runtests.jl`:
`Pkg.test()` IS `gbg selftest`.

### 1.10 The tool as its own consumer (§2 D15)

The tool repository is the fifth consumer; this step writes its footprint (§4: the same set as any
consumer's), in this order, every command from `$DEV`:

1. **Docstrings.** Write every public docstring of 1.4's docstring bullet; `checkdocs = :exports` below
   is what verifies them.
2. **`docs/`.** `docs/Project.toml`: `[deps] Documenter, GBGCodingTools` with `[sources] GBGCodingTools =
   {path = ".."}` — the working tree, §2 D2's bootstrap circularity. `docs/make.jl`: `using Documenter,
   GBGCodingTools; GBGCodingTools.makedocs(GBGCodingTools.Config.read(); sitename = "GBGCodingTools",
   checkdocs = :exports, doctest = true, pages = […]); deploydocs(repo =
   "github.com/GrigorySarnitsky/GBGCodingTools.jl")` — `WIRE.MAKEDOCS` applies to the tool itself. Pages:
   `index.md` (what it is, install, the design sentence), `guide/install.md` (bootstrap, shim,
   `~/.gbg/dev`), `guide/verbs.md` (the closed verb table of 1.3, rendered from the `src/CLI/` docstrings
   through `@docs` so it cannot drift), `guide/rounds.md` (the round lifecycle, closure channels, exit
   codes), `guide/doctor.md` (every check id with its fix hint, generated from the doctor's own table by a
   `make.jl` step, like the consumers' generated pages), `guide/ledger.md` (`[[exemption]]` and `match`),
   `guide/config.md` (the schema rendered), `api/{TestHarness,Reflection,Witnesses,Config,CLI}.md`,
   `architecture.md` (copied from `docs/ARCHITECTURE.md` at build time). Gather this document's revision
   notes under one `## Revision history` heading (the per-revision headings become `###`) — the one
   heading the `history_exempt` anchor of §5.6 needs. Then
   `julia --project=docs -e 'using Pkg; Pkg.instantiate()'`.
3. **`.gbg/`.** `gbgdev init` at the tool root — `init` must work when `$DEV` IS the consumer: the pin it
   writes is `dev`, the source it renders into `docs/Project.toml` is the `path = ".."` form, and it
   refuses nothing on the tool's own name. It writes §5.6's config (`[package] name = "GBGCodingTools"`,
   the surfaces `src/**/*.jl`, `ext/*.jl`, `docs/src/**/*.md`, `docs/ARCHITECTURE.md`, all four
   instruments, `seed_rounds = false`, the one domain hat `tooling-maintainer` with its persona file
   `.gbg/hats/tooling-maintainer.toml`), an empty `.gbg/exemptions.toml`, `.gbg/rounds/.keep`,
   `test/regressions/`, and `docs/prose_shape.csv`; then `gbgdev sync`, which renders `.gbg/policy/` from
   the tool's own `policy/`, `managed.json`, the five stubs into `.claude/skills/`, the `CLAUDE.md` block
   (the package-specific content — the design sentence, the freeze rule, and the release checklist
   under a `## Release checklist` heading, the anchor §5.6's `rulebook_sections` names — is written by
   hand outside it), the `.gitignore` block, `test/regressions/README.md`, and inserts the CI
   snippets into `CI.yml` and `docs.yml` (the tool holds the `GBG_DEPS_TOKEN` secret like every consumer;
   a by-path resolution never uses it, and `WIRE.CI_AUTH` is checked uniformly).
4. **`test/runtests.jl`** gains `TestHarness.gate()` and `TestHarness.run_regressions(@__DIR__)` besides
   the engine tests (`WIRE.RUNTESTS` holds at the root).
5. **`docs.yml`** deploys on push to `master` (V7 verifies the private-Pages deploy); `CI.yml` (manual +
   tags) runs `Pkg.test()` on 1.11 and 1.12 AND `julia --project=docs docs/make.jl`, with no consumer
   checked out.
6. **Scans and doctor on the tool itself.** `gbgdev scan docs` at the root: fix every `hard` hit or
   ledger it with a reason — `docs/ARCHITECTURE.md` is a rationale surface and meets the same scans (the
   AI banner, the DOI check against the whole file, the prose-shape ratchet `init` baselined);
   `gbgdev doctor --deep` green (`SELF.CONSUMER`, `SELF.DOCS`; `PIN.TREESHA`/`PIN.NOT_DEV`/`PIN.SELF` WARN
   "dev pin").
7. **The prerelease tag, then the first round.** Commit ⇒ push items 1–6 (item 8's command), then at
   the clean tree `gbgdev release 1.0.0-rc.1` — the prerelease form of `release` (§2 D16, 1.3): the same
   refusals as the final release except the open-round refusal and the closed-round precondition, so it
   needs `Pkg.test()` green, the tool's own docs build exit 0, `gbgdev doctor --deep` green, the
   `## 1.0.0-rc.1 — <date>` entry in `CHANGELOG.md` and the tag absent; it tags and pushes `v1.0.0-rc.1`
   (a tag nothing ever pins: `PIN.SOURCES` refuses a `-rc.` rev outside the tool root). From a session
   opened in `$DEV` at that clean tag (`git describe --exact-match --dirty` prints `v1.0.0-rc.1`):
   `/check-docs` over the tool's own docs — the tool's first real corpus besides the fixture. The round
   is stamped `v1.0.0-rc.1`, not `dev+…`, and is a normal closable round (§2 D16; its `tool_tree_sha` is
   read from the tag, so the fix commits that move `HEAD` past it are not "tag moved"); drive it to
   `open_ids == []` and close it with `gbgdev round close <round>` — through honored/adjudicated ids,
   never `abandon`. `gbg release 1.0.0` (Phase 3) requires exactly this round closed and refuses any open
   round. A second candidate (`gbgdev release 1.0.0-rc.2`, a new round at it) is issued only when the
   closed round's fixes are themselves to be measured before the tag.
8. Commit ⇒ push (`git add -u` plus `.gbg .claude/skills CLAUDE.md docs test/regressions
   .github/workflows/docs.yml` by name, §B) — once before the rc tag (item 7 needs the clean tree) and
   again with the round's fix commits and its closed record.

**Definition of done (Phase 1).**

```bash
cd "$DEV" && bash -e -o pipefail -c "
  julia --project -e 'using Pkg; Pkg.test()'                  # IS gbg selftest; runs TestHarness.gate() on the tool itself
  julia +1.11 --project -e 'using Pkg; Pkg.test()'
  julia --project=\"fixture/GBG Fixture/docs\" \"fixture/GBG Fixture/docs/make.jl\"
  ( cd \"fixture/GBG Fixture\" && gbgdev doctor )
  julia --project=docs docs/make.jl                            # the tool's own site, through its own wrapper (1.10)
  gbgdev doctor --deep                                         # at the tool root: SELF.CONSUMER, SELF.DOCS green
  gbgdev gate                                                  # no open round: 1.10's /check-docs round (opened at v1.0.0-rc.1) is closed
  test ! -e src/CLI/consolidate.py                            # 1.6's byte comparison passed and deleted it
  git status --porcelain | wc -l | grep -qx 0 "
```
All exit 0 (`$DEV` is exported, and the outer quotes are double so it expands; the fixture builds
against the enclosing checkout through its `path` source and `dev` pin, no tag needed, and the tool's
own site builds through its docs environment's `path` source likewise; the doctor under `--dev` reports
`PIN.TREESHA`/`PIN.NOT_DEV`/`PIN.SELF` as WARN "dev pin" and everything else green, at the fixture and
at the root); the `/check-docs` round of 1.10 sits under `.gbg/rounds/` closed — opened at
`v1.0.0-rc.1`, every id `closed_by` honored or adjudicated, never abandoned; the tag `v1.0.0-rc.1` is on
GitHub; `git log` shows the skeleton committed and pushed to `master`.

---

## Phase 1.9 — Verifications that need the skeleton (V2–V6)

Phase 0's remaining experiments, runnable only now: V2 needs the `gbg probe` verb and a skill stub,
V3 a pushed skeleton and a tag, V4 the CI snippet template (1.7) and a tool entry to pin, V5 `CI.yml`,
V6 the tool's `Project.toml`. **No shim exists yet** (Phase 3 installs it), so every `gbg` invocation
here is `gbgdev …` — except inside V2's skill stub, whose `!` block needs a `gbg` on
`PATH`: for V2 alone, put a throwaway wrapper first on `PATH` and remove it afterwards:

```bash
mkdir -p /tmp/gbg-probe-bin && printf '#!/bin/sh\nexec julia --startup-file=no --project="%s" -e "using GBGCodingTools; exit(GBGCodingTools.main(ARGS))" -- --dev "$@"\n' "$DEV" > /tmp/gbg-probe-bin/gbg
chmod 755 /tmp/gbg-probe-bin/gbg && export PATH="/tmp/gbg-probe-bin:$PATH"      # V2 only; unset after
```

Run in this order — V4 pins the tag V3 creates, and the tag is deleted only after V4:

| # | Verification | Experiment | Pass | Fallback if it fails |
|---|---|---|---|---|
| V2 | `!`-block skill injection aborts on non-zero and needs `allowed-tools` | Throwaway `.claude/skills/gbg-probe/SKILL.md` in `$PF` with frontmatter `allowed-tools: Bash(gbg *)` and a body that is one `!` block (a fenced block opened with three backticks and `!`) containing `gbg probe $ARGUMENTS` (the verb of 1.3: `PROBE OK` exit 0; `--fail` → stderr, exit 2) | `/gbg-probe` shows `PROBE OK` in the injected context with no permission prompt; `/gbg-probe --fail` aborts before the body, no prompt | if a prompt appears: `gbg sync` also renders `permissions.allow: ["Bash(gbg *)"]` into the managed `.claude/settings.json`; if no abort: the stub body opens with "If the block above reports GBG PREFLIGHT FAILED, stop." |
| V3 | `[sources] url + rev` honoured by `Pkg.test()` and by the docs env | Tag `v0.0.1` on the Phase 1 push of the skeleton (a `vX.Y.Z` tag, so `PIN.CONFIG` accepts the pin `0.0.1`; deleted from GitHub after V4 — nothing ever pins it, and `gbg release` never issued it); in a COPY of the fixture outside `$DEV` pinned at `0.0.1`: `test/Project.toml` and `docs/Project.toml` with the `[sources]`/`[compat]` entries; `julia --project=test -e 'using Pkg; Pkg.instantiate(); using GBGCodingTools'`, `julia --project=docs -e '…'`, `Pkg.test()` | all load the tagged version; `ls -ld ~/.julia/packages/GBGCodingTools/*/` shows one read-only tree | `[sources] path = "<per-machine clone>"` as the documented offline fallback (breaks CI; record it) |
| V4 | https token auth in CI reaches a fourth private repo — probed on PF AND CP | Add `GBGCodingTools.jl` to the PAT's repository list; create the `GBG_DEPS_TOKEN` secret in PF (it has none today — its `docs.yml` uses only `GITHUB_TOKEN`) and in CP if absent; on a throwaway branch `probe/gbg-v4` in PF and in CP — pushed only for the dispatch, never merged, deleted with the tag after V4 (the branch rule concerns work; this is a probe) — put `[sources] GBGCodingTools = {url = …, rev = "v0.0.1"}` + `[compat] GBGCodingTools = "=0.0.1"` in `docs/Project.toml` and insert `templates/docs.yml.snippet` by hand at the insertion points 1.7 states; manual `workflow_dispatch` of both `docs.yml`s on that branch | both runners green; logs show the tool cloned at `v0.0.1` | a second secret and a second `insteadOf` line in `templates/docs.yml.snippet` |
| V5 | No `python3` is needed on the runner | read V4's two runner logs and the tool's own `CI.yml` on a manual dispatch: confirm `templates/docs.yml.snippet`, `templates/CI.yml.snippet` and `CI.yml` contain no python step and that no step invoked `python3` | zero python steps in all three and the jobs green without one | a python step found is a leftover of the retired draft — delete it from the snippet and re-run V4 |
| V6 | juliaup 1.11 lane | `juliaup add 1.11 && julia +1.11 --project="$DEV" -e 'using Pkg; Pkg.test()'` | green on both hosts | if 1.11 cannot install, set `julia = "1.12"`, collapse SS's floor, and record it as an owner decision, never silently |

Clean-up, in this order: delete the two probe branches; `git push --delete origin v0.0.1 && git tag -d
v0.0.1`; delete V3's fixture copy, then `julia -e 'using Pkg, Dates; Pkg.gc(; collect_delay = Day(0))'`
so the orphaned `0.0.1` slug leaves `~/.julia/packages/GBGCodingTools/` (nothing selects by slug any
more, but a fetched tree nothing pins is depot litter); remove `/tmp/gbg-probe-bin` from `PATH`; `rm -rf "$PF/.claude/skills/gbg-probe"`.

**Definition of done.** V2–V6 recorded in `$DEV/docs/ARCHITECTURE.md` §11 (date, host, result),
committed ⇒ pushed; `git ls-remote --tags origin | grep -c v0.0.1` prints 0; `ls
~/.julia/packages/GBGCodingTools/ 2>/dev/null | wc -l` prints 0 on both hosts.

---

## Phase 2 — Step-0 instrument-equivalence test

Runs on the LIVE working trees, never scratch clones: PF's largest round is the UNTRACKED
`.claude/doc-review/` on `Aiporetne`'s working tree, which a clone does not contain; IT's piles are read
on `Enteropia` or from the Dropbox copy. No shim exists yet, so every command below is
**`gbgdev …`** (the function at the top of this plan; 1.3: `main` accepts `--dev` itself). Nothing of the
consumer's is deleted in this phase; `init --migrate --dry-run` writes no `.gbg/`. **The imports are
scratch** (§A, the no-history ruling): `round import` writes the rounds into the consumer's
`.gbg/rounds/` (§8 — creating the directory), they are graded and compared there, and step 4 below
deletes them again; nothing under `.gbg/rounds/` is ever staged, and every consumer's migration (Phases
4–7) starts with an empty `.gbg/rounds/`. PF's `.claude/doc-review-prev/` (round 6, 2026-08-15, no
verdict files — Q13) is not imported: there is nothing to re-grade.

1. In `$PF` (on `Aiporetne`): `gbgdev init --migrate --dry-run`, then
   `gbgdev round import ".claude/doc-review" ".claude/check-docs-2026-09-01" ".claude/doc-review-checkdocs" ".claude/check-docs-2026-07-22-findings.json"`
   (four rounds under `.gbg/rounds/`, each with its `import.json` title → id map and `abandoned`).
   In `$IT`: import `.claude/review-rounds/2026-08-24-check-consistency.md` +
   `.claude/doc-review-closures/{panel-r1,round-1,round-2,round-3}` + `.claude/doc-review-round1/` +
   `.claude/audit-changes/latest.json` + `.claude/bug-hunt/rounds.json` (rounds 1, 2, 3, 5, 6; round 3,
   whose entry carries no counts, imports as `abandoned` with every id open).
2. Write each round's `recorded.toml` by hand (§8's format), reading the record: PF
   `2026-09-01-check-consistency-01` — `findings = 67`, `seeded = 11`, `honored = 59`
   (`.claude/doc-review/CLOSED.md` L3, L63; `adjudicated` omitted); PF `2026-09-01-check-docs-01` —
   `findings = 18`, `seeded = 0`, `honored = 17`, `adjudicated = 1` (its `CLOSED.md` L3: 18 closed, 17
   fixed, 1 dismissed); PF `2026-08-27-check-docs-01` — `findings = 8`, `seeded = 0`, `honored` and
   `adjudicated` as its `CLOSED.md` records them per finding (the 30 HONORED it reports are verdicts
   across passes, not findings — read the per-finding table, and omit what it does not carry); PF
   `2026-07-22-check-docs-01` — `findings = 134`, `honored`/`adjudicated` counted from the per-finding
   status in the JSON (134 in total, fixed or dismissed); IT's check-consistency rounds from each
   marker's `closed:` account, the audit round from `latest.json`'s verdicts, the hunt rounds from
   `rounds.json` under §8's mapping (`findings` = confirmed, `honored` = fixed, `adjudicated` =
   refused + escalated). Then `gbgdev round grade <each>` and
   `gbgdev round compare --recorded ".gbg/rounds/<each>/recorded.toml" <each>`.
3. Every difference is a finding in the port; fix the engine, never the recorded numbers. Record the
   final comparison table in `CHANGELOG.md` under 1.0.0 — the ONE artefact this phase leaves behind.
4. Delete the scratch imports: `rm -rf .gbg/rounds` in `$PF` and in `$IT` (the directory did not exist
   before step 1 in either; `gbg init` recreates it empty, with `.keep`, at PF-0 and 5.2). The legacy
   piles themselves stay in place until each consumer's migration deletes them (PF-6, 5.2, Phase 6).

**Definition of done.** `gbgdev round compare --recorded … <round>` exited 0 for
every imported round (an UNRECORDED key is not a difference); the table is in the CHANGELOG;
`test ! -e "$PF/.gbg" && test ! -e "$IT/.gbg"` exits 0 (nothing of the scratch imports remains).

---

## Phase 3 — Release v1.0.0

The `/check-docs` round of 1.10 was opened at `v1.0.0-rc.1` and is closed; that closed round is a
precondition of the final release below (§2 D16). If its fixes are themselves to be measured before the
tag, issue `gbgdev release 1.0.0-rc.2` first and open and close a round at it — the prerelease form
refuses nothing about rounds. The rc tags stay on GitHub (tags are immutable); nothing pins them.

```bash
cd "$DEV" && bash -e -o pipefail -c "
  julia --project -e 'using Pkg; Pkg.test()' && git status --porcelain | wc -l | grep -qx 0   # the selftest, clean tree
  julia --project=docs docs/make.jl && gbgdev doctor --deep && gbgdev gate                    # observed here, re-run by release
  gbgdev release 1.0.0                 # refuses (exit 2) unless, at a clean tree: Pkg.test() green, the tool's own docs build
                                       # exit 0 (SELF.DOCS), gbg doctor --deep green at the root, no open round under
                                       # .gbg/rounds/, the /check-docs round opened at the latest v1.0.0-rc.<n> tag closed
                                       # (honored/adjudicated, never abandoned), the CHANGELOG entry present, the tag absent (§2 D16, §8)
  git push --tags"
```
Then on **both** hosts: exercise the pinned copy on a throwaway fixture outside the repo, and install
the shim with the dev checkout registered:

```bash
cd "$DEV" && gbgdev selftest --pinned             # copies the fixture to ${TMPDIR:-/tmp}/gbg-pinned-fixture/, pins 1.0.0, instantiates docs/, runs the pinned arms, leaves the copy
( cd "${TMPDIR:-/tmp}/gbg-pinned-fixture" && julia --startup-file=no --project=docs -e 'using GBGCodingTools; exit(GBGCodingTools.main(ARGS))' -- install --dev-checkout "$DEV" )
                                                  # `install` runs from the PINNED copy that fixture's docs env resolved (D2), never from the dev checkout; no depot glob
gbg --version                                     # outside any consumer: routes via ~/.gbg/dev, prints dev+<sha>
( cd "$DEV/fixture/GBG Fixture" && gbg --version ) # inside the dev-pinned fixture: prints dev+<sha> via the enclosing repo
```

**Definition of done.** Tag `v1.0.0` on GitHub; `gbg selftest --pinned` green on both hosts (its arms
cover `SHIM.HASH`, `PIN.TREESHA`, `PIN.SELF` against the released tag); `gbg doctor` green inside the
dev-pinned fixture on both hosts (the three "dev pin" WARNs expected); `gbg fleet` runs from `$DEV`
(through the tool's own docs environment, the root being a consumer since 1.10), prints its own row
`GBGCodingTools dev+<sha> OK clean at v1.0.0` and the four consumers `NOT-INITIALISED` with `no window`,
and exits 1 (D4's contract).

---

## Phase 4 — Migrate PF (canary)

Run on `Aiporetne`. Each step: action → commands → the doctor check that verifies it. Do not proceed
while the named check is red.

| Step | Action | Commands | Verified by |
|---|---|---|---|
| PF-0 | Bootstrap the pin | `cd "$PF" && gbg --dev init --migrate` (writes `.gbg/config.toml` from §5.1; `.gbg/hats/{spectral-methods-mathematician,differential-geometer,gpu-kernel-practitioner,normalization-convention-auditor}.toml` from `panel.js:88,93,96,119`; `.gbg/seeds.toml` from `check-consistency/seed_defects.py:39-56`; renders the `[deps]/[sources]/[compat]` entries into every sub-env that lists the tool; runs `gbg migrate baselines`, which writes `test/method_parity_baseline.toml`, `test/pass_audit_baseline.toml` and `test/oracle_registry.toml` from the Julia literals 1.3 names; writes `.gbg/scratch/commit-message.txt`) then `for e in test docs benchmark; do julia --project="$e" -e 'using Pkg; Pkg.instantiate()'; done` | `PIN.CONFIG`, `PIN.SOURCES`, `PIN.TREESHA`, `PIN.SELF`, `LOAD.ENVS` (`gbg doctor --deep --only LOAD`) |
| PF-1 | CI auth, then `sync` | the PAT lists `GBGCodingTools.jl` and PF holds the `GBG_DEPS_TOKEN` secret since V4 (create them now if V4 ran elsewhere); then `git rm .claude/hooks/queue-guard.sh .claude/settings.json` (the hand-written copies the managed renders replace with the same bodies under a hash — removed BEFORE `sync` so the render meets no unmanaged file at either path), then `gbg --dev sync`, which renders every G file (the skills, `managed.json`, `.gbg/policy/`, the `CLAUDE.md` and `.gitignore` blocks, `.claude/hooks/queue-guard.sh` and `.claude/settings.json` — the pure-sh body of 1.6, PF's own script verbatim, so the guard on `WORK_QUEUE.md` is unchanged; `WORK_QUEUE.md` itself exists, so it is not seeded — `test/regressions/README.md`) and inserts `templates/CI.yml.snippet` and `docs.yml.snippet` into `.github/workflows/{CI,docs}.yml` at 1.7's insertion points — `sync` validates the config `init` wrote, which is why it cannot precede PF-0 | `WIRE.CI_AUTH`, `MANAGED.HASH`, `MANAGED.STALE`, `WIRE.GITIGNORE`, `WIRE.CLAUDE_MD` (locally); a `workflow_dispatch` of PF's `docs.yml` green |
| PF-2 | Empty rounds, empty ledger | `.gbg/rounds/` holds only `.keep` (PF-0 wrote it; Phase 2's scratch imports were deleted at its step 4 — `gbg round list` prints no round); `.gbg/exemptions.toml` is the empty ledger `init` wrote: the old `.claude/doc-review-adjudicated.md` adjudications are NOT carried over (the no-history ruling, §A) — a finding a future panel raises again is adjudicated afresh under the new ledger; `rm -rf .claude/doc-review-prev` per Q13 (the closed round 6 of 2026-08-15, discarded, never imported) | `ROUND.DIR`, `ROUND.MARKER`, `CFG.EXEMPTIONS` |
| PF-3 | `make.jl` | delete the lint DEFINITIONS `_doc_lint_sources` and every `lint_*` — L44–568, which includes `_prose_metrics`/`_prose_units` (L425–488) — and `lint_rendered_markup` (L653–682) with its call (L684); delete the lint CALLS at L571 and L574–580; KEEP `remove_jupyter_files()` (L570), `copy_rationale_pages()` (L572) and `build_examples()` (L573) — `build_examples()` must still run BEFORE `GBGCodingTools.makedocs`, the Literate page being a scanned surface; replace `makedocs(` (L591) with `GBGCodingTools.makedocs(GBGCodingTools.Config.read(); <same kwargs>)`; `gbg scan docs --rebaseline prose-shape --reason "unified schema"` (the reason goes in the commit); `julia --project=docs docs/make.jl` must exit 0 | `WIRE.MAKEDOCS`, `LEG.LINTS`, `BUILD.DOCS` |
| PF-4 | `runtests.jl` + harness files | replace the engine bodies with `TestHarness` calls: `public_surface.jl` → `TestHarness.package_operations`; `allocations.jl` macro/completeness; `pass_audit.jl` CountingArray; `method_parity.jl` engine (its tables now read from `test/method_parity_baseline.toml`, written at PF-0 by `gbg migrate baselines` — `gbg migrate baselines --dry-run` re-derives them for comparison if a literal moved); `pass_audit.jl` rows from `test/pass_audit_baseline.toml`; `oracle_registry.jl` engine (from `test/oracle_registry.toml`); `display.jl` engine; the regression loop → `TestHarness.run_regressions(@__DIR__)`; add `TestHarness.gate()`; `julia --project -e 'using Pkg; Pkg.test()'` green — **re-measure the test and testset counts and record them; a DROP against the last recorded figure (9657 / 143 on 2026-09-05) is a finding, a rise from `gate()`'s own assertions is expected** | `WIRE.RUNTESTS`, `TEST.PKG` |
| PF-5 | `CLAUDE.md` | cut the policy sections named in §7.1 (≈ 700 lines) — the managed block was inserted at PF-1; run the sentinel check (`gbg doctor --only LEG.SENTINELS`, which matches `RULES.toml`'s `sentinel` sentences against the block-free `CLAUDE.md`) until zero; every cut sentence must exist in `policy/*.md` or be package-specific and kept. THEN trim to `templates/CLAUDE.md.skeleton` (§A's `CLAUDE.md` ruling): "Current state and roadmap" (L1132–2006) and "Planned directions" (L2007–2668) are read item by item — finished work is deleted (git history keeps it), live plans move to a new tracked `docs/ROADMAP.md`, and one "Current state" paragraph pointing at it remains; "Modules and wiring", "Core invariants", "Code generation rules" (PF's own style) and "Working agreements" stay | `WIRE.CLAUDE_MD`, `POL.IMPORT`, `POL.SENTINEL`, `LEG.SENTINELS` |
| PF-6 | Delete legacy | `git rm -r .claude/commands .claude/doc-review-adjudicated.md .claude/check-docs-2026-09-01 .claude/doc-review-checkdocs .claude/check-docs-2026-07-22-findings.json .claude/audit-changes`; `rm -rf .claude/doc-review .claude/doc-review-prev .claude/audit-changes` (the untracked and ignored contents `git rm` leaves on disk); `git rm .claude/to-IT-triage-reply-2026-07-19.md .claude/to-IT-phase-shift-questions-2026-07-28.md` (both concluded in July — §A's requests ruling: a concluded request is deleted, only an open one would move to `.gbg/requests/to-IT-<date>-<topic>.md`); `rmdir .claude/worktrees` (empty); `git rm --cached .claude/settings.local.json`; trim `.claude/WORK_QUEUE.md` to its header — the 93 `- [x]` lines are history and go; `gbg sync` again (idempotent — the G files, `.claude/hooks/queue-guard.sh` and `.claude/settings.json` among them, were rendered at PF-1; the re-run confirms the deletions touched nothing managed) | `LEG.COMMANDS`, `LEG.PILES`, `MANAGED.HASH`, `MANAGED.STALE`, `WIRE.GITIGNORE` |
| PF-7 | Skills dry run | in a session: `/check-docs --dry`, `/check-consistency --dry`, `/bug-hunt --dry`, `/audit-changes --dry` — each injects the protocol and the Workflow line and opens nothing; `/gbg-doctor` runs the doctor | `gbg doctor` green |
| PF-8 | Commit ⇒ push | `git add -u && git add .gbg .claude/skills .claude/hooks .claude/settings.json docs/ROADMAP.md test/regressions/README.md test/method_parity_baseline.toml test/pass_audit_baseline.toml test/oracle_registry.toml && git commit -F .gbg/scratch/commit-message.txt && git push` (§B: `-u` plus every new file by name, never `-A`) (the template `gbg init --migrate` wrote, under the gitignored `.gbg/scratch/`); `cd "$DEV" && gbg fleet` | fleet rows: the tool's own `OK`, PF `1.0.0 OK`; the other three `NOT-INITIALISED`, so exit 1 until Phase 7 (D4's contract) |

`CFG.TORN` is outside `QUICK` (§7.3), so PF-3's docs build and PF-4's `Pkg.test()` run with the tracked
`test/` and `docs/` `Project.toml` files PF-0 modified and leaves uncommitted until PF-8; only
`gbg preflight` and the `gbg round` verbs would refuse that tree.

**Deleted from PF** (complete list): `.claude/commands/**` (30 tracked files: the four `.md`,
`MANIFEST.txt`, `manifest.py`, `check-docs/{argcov.jl,doi_crosscheck.py,field_docs.py,guards.sh,
link_uniformity.py,sentence_openers.py,MANIFEST.txt}`, `check-consistency/{consolidate.py,coverage.py,
panel.js,recall.py,recall_selftest.py,seed_defects.py,verify-fixes.js,verify.js,MANIFEST.txt,.gitignore}`,
`bug-hunt/{dismissals.js,hunt.js,witnesses.jl,MANIFEST.txt}`, `audit-changes/{audit.js,gate.py,MANIFEST.txt}`);
`.claude/hooks/queue-guard.sh` (the hand-written copy — replaced at PF-1 by the managed render of the same body at the same path); `.claude/doc-review-adjudicated.md`; the two tracked round directories,
the 2026-07-22 findings file and the untracked `.claude/doc-review` and `.claude/doc-review-prev` (all
deleted, none imported — Phase 2 read four of them on scratch; `doc-review-prev` is the 2026-08-15
round 6, discarded per Q13);
`.claude/audit-changes/.gitignore` and the directory; the nine lint functions, `_doc_lint_sources`,
`_prose_metrics`/`_prose_units` and `lint_rendered_markup` in `docs/make.jl`; `test/public_surface.jl`;
the engine parts of `allocations.jl`, `pass_audit.jl`, `method_parity.jl`, `oracle_registry.jl`,
`display.jl`, `runtests.jl`; `test/regressions/README.md` (regenerated); ≈ 700 policy lines of
`CLAUDE.md` plus its finished-work entries (the live plans go to `docs/ROADMAP.md`); the two concluded
`to-IT-*.md` requests; the empty `.claude/worktrees/`; the 93 done lines of `WORK_QUEUE.md`. Kept:
baselines, `test/regressions/*.jl`, `WORK_QUEUE.md` (header), `CLAUDE.md` in the skeleton's shape,
`benchmark/`, `remove_jupyter_files`/`copy_rationale_pages`/`build_examples` in `make.jl`. After PF-8
PF's `.claude/` holds `skills/`, `hooks/`, `settings.json`, `WORK_QUEUE.md` and the gitignored
`settings.local.json` — the shape every consumer ends with.

**Definition of done (Phase 4).**

```bash
cd "$PF" && bash -e -o pipefail -c "
  gbg doctor --deep
  julia --project -e 'using Pkg; Pkg.test()'
  julia --project=docs docs/make.jl
  julia --project=examples examples/HIST_CPU.jl --smoke
  git status --porcelain | wc -l | grep -qx 0"
cd "$DEV" && gbg fleet
```

---

## Phase 5 — IT

### 5.1 Verify the IT mechanisms against IT's imported rounds — no release unless a defect is found

Everything IT contributed is already in 1.0.0 (D17, §8): the panel **profile** mechanism
(`profile = all|core|explicit`, IT `check-consistency/panel.js:254-286`, applied by the CLI); IT's
generic lenses and the three rulebook hats in `catalog/hats/`; the `operational-claims` check-docs lane
(IT `check-docs.md:58-74`); `attack-design.js`, `rubric-audit.js`, `severity-recheck.js`;
`verify-architecture.js` and the `architecture` reproduction path; the prose audit lanes;
`argcov_policy = "gate"`; `docs_post`; the seed engine over a consumer's catalogue (IT's becomes its `.gbg/seeds.toml` at 5.2); IT's `finished.py`
nine checks as the hunt `close`; `PARTIAL`/`surviving_class`; `checked[]`/`candidates_found`; required
`base`. This step RE-RUNS Phase 2's IT half on `Enteropia` under `gbg --dev` — IT has no pin until 5.2, so
the versioned route does not exist yet — with the dev checkout at the `v1.0.0` tag and clean
(`git -C "$DEV" describe --exact-match` prints `v1.0.0`, `git -C "$DEV" status --porcelain` is empty,
`gbg --version` prints `dev+<that sha>`), which is byte for byte the tree the tag names:
`gbg --dev round grade <each>` over the rounds Phase 2 imported (still untracked in IT's tree) and
`gbg --dev round compare --recorded ".gbg/rounds/<each>/recorded.toml" <each>`. **A defect found here is fixed in
`$DEV` and released as `1.0.x`** (`CHANGELOG`: "rates comparable: yes"; `gbg release 1.0.1`), after
which PF runs `gbg bump 1.0.1` (refused if PF has an open round) and commits ⇒ pushes, and the fleet
window opened by that bump closes when IT pins the same. No defect ⇒ no release; IT migrates at 1.0.0.

### 5.2 Migrate IT (on `Enteropia`)

**Not applied here (IT amendment 16):** IT's branch stays `main` (`git.branch = "main"`) and its
`docs.admonition_titles` is whatever IT rules — both are decisions about IT that the tool supports
either way; the owner rules on each separately, and neither a branch rename nor a retitling sweep is
bundled with this adoption commit.

Steps PF-0 … PF-8 with these differences: PF-1 needs no secret (IT already has `GBG_DEPS_TOKEN` and
the `insteadOf` step; `gbg sync` adds the banner grep and nothing else to the auth block; IT has no
hand-written hook or `settings.json`, so PF-1's `git rm` does not apply and `sync` renders
`queue-guard.sh`, `settings.json` and seeds an empty `WORK_QUEUE.md` — §A's Stop-hook ruling); PF-0's
`gbg init --migrate` seeds the IT config (§5.3) and writes `.gbg/seeds.toml` from IT
`check-consistency/seed_defects.py:31-48` — `migrate baselines` finds none of the three literals
in IT and writes nothing — and `.gbg/hats/{turbulence-theoretician,dns-practitioner,external-standard,dimensional}.toml`
from IT `check-consistency/panel.js` — the rulebook hats `naming-policy`, `doc-policy`,
`invariants-and-decisions` are NOT written there, they come from the catalogue over
`[package] rulebook_sections`; the ledger entries `RULE.DOC.STEER`, `RULE.DOC.MODULE_MAP`,
`RULE.GIT.MANIFEST_TRACKED` — rule deviations, which are carried; the finding-scope adjudications of
`.claude/doc-review-adjudicated.md` are NOT (the no-history ruling, as PF-2); **no rounds import** —
Phase 2 read IT's piles (`review-rounds/`, `doc-review-closures/`, `doc-review-round1/`,
`audit-changes/latest.json`, `bug-hunt/rounds.json`) on scratch and deleted the imports; here they are
simply deleted, and `.gbg/rounds/` holds only `.keep`; **the live witnesses move**: from
`.claude/bug-hunt/witnesses/`, `escalated/*.jl` → `test/regressions/escalated/` (each keeps its
provenance header and gains an `# overturn_when: <reason>` line transcribed from `rounds.json`),
`needs-gpu/*.jl` → `test/regressions/blocked/` (each given a `# blocked: needs a GPU` header); every
other witness there is either already promoted (the 125 in `test/regressions/`) or history —
`r<N>-*.jl`, `NN-r<N>-*.jl`, `withdrawn/`, the untracked `env/`, and the tracked
`r4-architecture-03-probe.jl` — and is deleted with the pile; `gbg doctor --deep --only WITNESSES`
re-runs the two new directories (§7.3);
`make.jl`: delete `_doc_lint_sources` (L28–39), `_docstring_shapes` (L73–108) and the four lints
(L110–302), and their four CALLS at L305–308; KEEP `copy_rationale_pages()` (L12–24, called at L304);
wrap `makedocs(` (L338); `docs/docstring_shape.csv` → `docs/prose_shape.csv` re-baselined;
`runtests.jl` loop → `run_regressions` (the **125** promoted witnesses in `test/regressions/`
untouched), `display.jl` engine → `TestHarness`; `CLAUDE.md` cuts (≈ 323 lines), then the trim to
`templates/CLAUDE.md.skeleton` ("Known weaknesses — self-guards" stays as IT's own rules; IT has no
roadmap section, so `docs/ROADMAP.md` is created from `OPEN-ITEMS.md`'s six open items once ruled, and
`OPEN-ITEMS.md` is then deleted); requests: each of the nine `.claude/pf-request-*.md` and
`.claude/ss-request-*.md` is read for its status — one still awaiting PF or SS moves to
`.gbg/requests/to-PF-<date>-<topic>.md` / `to-SS-<date>-<topic>.md` with a status paragraph on top, a
concluded one is deleted (§A's requests ruling); after the import `rm -rf .claude/doc-review .claude/doc-review-prev
.claude/doc-review-minimal .claude/doc-review-round1 .claude/doc-review-closures .claude/rubric-audit
.claude/bug-hunt .claude/audit-changes` (the untracked and ignored contents `git rm` leaves).

**Deleted from IT**: `.claude/commands/**` (**39** tracked files incl. `INVENTORY.md`, `manifest.py`,
`MANIFEST.txt`, `bug-hunt/{closure.py,finished.py,verify-fixes.js,witnesses.jl,hunt.js,dismissals.js}`,
`check-consistency/{rubric_extract.py,rubric_prep.py,rubric_audit.js,severity_recheck.js,…}`,
`check-docs/{lanes.js,xlink.jl,abutting_spans.py,dupref.jl,signature_fidelity.jl,…}`,
`audit-changes/{attack-design.js,audit.js,gate.py}`); `.claude/README.md`;
`.claude/doc-review-adjudicated.md`; the legacy piles (`review-rounds/`, `doc-review-closures/`,
`doc-review-round1/`, `audit-changes/`, `bug-hunt/` — none imported) and the untracked `doc-review/`,
`doc-review-prev/`, `doc-review-minimal/`; `.claude/bug-hunt/.gitignore`; `.claude/rubric-audit/`; the
lint bodies; `docs/docstring_shape.csv`. Per Q12, IT's own pre-migration commit (2026-09-08) already
removed the fourteen non-instrument notes (`arch-research/`, `archive/`, the `*-pile.md` files, the dated
notes; `turtle-comparison-spec.md` became `validation/RUNBOOK.md`); `OPEN-ITEMS.md` is deleted in this
migration once its six open items are ruled; `LEG.PILES` names none of them. After 5.2 IT's `.claude/`
holds `skills/`, `hooks/`, `settings.json`, `WORK_QUEUE.md` and the gitignored `settings.local.json`,
like PF's, SS's and CP's.

**Definition of done.** As Phase 4's block, run in IT (`Pkg.test()`, docs build, `gbg doctor --deep`,
`gbg fleet` shows PF and IT at the same `1.0.x` OK), plus `gbg doctor --deep --only WITNESSES`
reporting the escalated and blocked witnesses under `test/regressions/{escalated,blocked}/`.

---

## Phase 6 — SS

Q3 is ruled (§A): SS's corpus was counted on 2026-09-08 — 0 bold, 80 plain argument bullets — so the
hard scan `SCAN.ARG_BULLET_BOLD` applies to SS unchanged; no `sed`, no ledger entry. Re-run the two
counts at migration and record them in the commit; a bold bullet that appeared since is fixed, not
ledgered.

PF-0 for SS: `gbg init --migrate` with §5.2's config (`migrate baselines` writes nothing — SS holds
none of the three literals); PF-1 for SS: create the `GBG_DEPS_TOKEN` secret (SS's `docs.yml` uses
only `GITHUB_TOKEN`) and `gbg sync` inserts the snippets;
`.gbg/hats/{statistics-theoretician,streaming-stability-practitioner,normalization-convention-auditor}.toml`
from SS `check-consistency/panel.js:66,69,81`; ledger `RULE.API.POSITIONAL`; `rm -rf` the one untracked
round `.claude/doc-review/` (12 files, July; never verified, not imported — the no-history ruling);
`make.jl`: delete `lint_inline_math` (L11–49), wrap `makedocs`; `runtests.jl` gains `run_regressions` +
`gate()` and `test/regressions/` is created; `CLAUDE.md` cuts (≈ 197 lines; the `inspiration/` citation
and the `\!` before `\left(` sentence go), then the trim to the skeleton — SS's 246-line "Current state
and roadmap": finished work deleted, live plans to a new tracked `docs/ROADMAP.md`; `sync` renders the
Stop hook, `settings.json` and seeds `WORK_QUEUE.md` as everywhere; `julia = "1.11"` untouched; `seed_rounds = false`
(no `.gbg/seeds.toml` yet — SS writes one, a consumer commit with no tool release, when it runs its
first panel).

**Deleted from SS**: `.claude/commands/{check-consistency.md,check-docs.md,check-consistency/{.gitignore,consolidate.py,panel.js}}`,
`.claude/doc-review/` (deleted, not imported), `lint_inline_math` in `make.jl`, the policy lines in `CLAUDE.md`.

**Definition of done.** Phase 4's block in SS (`Pkg.test()` under `julia +1.11` as well, since SS's floor
is 1.11); `gbg fleet` shows PF, IT and SS `OK` beside the tool's own row.

---

## Phase 7 — CP

PF-0 for CP: `gbg init` (no `--migrate`) writes `.gbg/config.toml` exactly as §5.4 states it (modules
from the `module` blocks under `src/`, no `[paths]`, no benchmark environment, `seed_rounds = false`,
`references_heading = "docs/ARCHITECTURE.md#14. References"`, and the ONE `domain_hats` entry
`cloud-microphysicist` together with its placeholder persona file `.gbg/hats/cloud-microphysicist.toml`
— the roster key and the file are written in the same step, so `CFG.HATS` is green from `init`; the
persona is rewritten before CP's first panel), **creates `test/Project.toml`** (moving
`[extras]`/`[targets]` deps there — state this in the commit, it changes how `Pkg.test()` resolves and
what Aqua's `project_extras` sees), seeds `test/regressions/`, the `runtests.jl` lines and the
`make.jl` wrapper. PF-1 for CP: the `GBG_DEPS_TOKEN` secret exists since V4 (create it if V4's CP
probe ran elsewhere); `gbg sync` renders the G files and inserts the CI snippets. Then, in the same
migration commit: SS's floating `[sources] url` gains a `rev` in BOTH places it appears — the root
`Project.toml` (L19–20) and `docs/Project.toml` (L11); Q4 (ruled): drop `persistent_tasks = false`
from `test/aqua.jl` together with its three-line comment — the flaky-probe reason names solver
dependencies CP no longer has; if the probe fails again it is a finding, not a setting;
reword the five "knobs" in `CLAUDE.md` (`option`/`setting`) and reorder its 133 lines to the skeleton
("Direction — refactor in progress" becomes `docs/ROADMAP.md`); `sync` renders the Stop hook,
`settings.json` and seeds `WORK_QUEUE.md` as everywhere.
Documenter 1.19 is inside the tool's `[weakdeps]` compat bound, which binds only environments holding
Documenter (V3/V5 confirm the build).

**Definition of done.** Phase 4's block in CP; `gbg fleet` every row `OK` — the four pinned consumers and the tool's own — exit 0. This phase is R10's proof:
no deletions, only config (§5.4 is the whole delta).

---

## Phase 8 — Fleet green, notes, deferred items

1. `cd "$DEV" && gbg fleet --deep` green on both hosts (run on each; a host reports its own resolution);
   every consumer at the same `1.0.x`.
2. Consumer `CLAUDE.md`: every one follows `templates/CLAUDE.md.skeleton` after its migration's trim
   step (PF-5 and its analogues); the "Current state" paragraph of each points at its `docs/ROADMAP.md`
   and at `GBGCodingTools/docs/ARCHITECTURE.md` with the pin. PF's former "Planned directions — the
   instruments are FROZEN in-tree" block and IT's former `INVENTORY.md` content are gone with the trim.
3. Memory notes (each package's `claude-memory/<Package>/`): `gbgcodingtools-adopted.md` — the pin, the
   verbs, "instruments run from the pinned copy; never edit `~/.julia/packages/…`; `gbg --dev` for an
   unreleased tool; a build under an open round goes through `gbg round build|test`; the shim execs
   `julia --project=docs`, so a consumer's docs environment must be instantiated before `gbg` works
   there; the tool has its own docs site — `guide/verbs.md` is the verb table, `guide/doctor.md` every
   check id with its fix hint — deployed by its `docs.yml` on every push to `master` to
   `https://grigorysarnitsky.github.io/GBGCodingTools.jl/`, public by URL like the four consumer sites
   (Q14): read it before the tool's `ARCHITECTURE.md`"; the per-machine
   `~/.claude/CLAUDE.md` gains the shim line, `~/.gbg/dev`, and the bootstrap commands.
4. Deferred, recorded in the tool's `CHANGELOG.md` "Unreleased" and `ARCHITECTURE.md` §2 D2: a private
   Julia registry (LocalRegistry) as the upgrade of the pin syntax — also turns PF→IT and SS→CP into
   normal versioned deps; Julia 1.12 workspaces to collapse the sub-environment entries; `.claude/rules/`
   as an alternative policy placement; IT's rubric-audit calibration
   triple (`rubric_extract.py`/`rubric_prep.py` + `rubric_audit.js`) as an optional instrument with a
   verb of its own — not a verb of this plan.

**Definition of done.** `gbg fleet --deep` exit 0 on both hosts; every consumer's last commit is pushed;
the tool at one tag across the fleet; the memory notes written.

---

## Revision 2 (2026-09-07)

Applied from `out/REVIEW-dryrun.md`: items 1–5 (BLOCKER), 6–23 (MAJOR), 24–47 (MINOR), 48–57
(deviations), as ruled by `05-fix-rulings.md` where a ruling overrides the review's own fix (the rows
`out/FIXLOG.md` marks "Applied (ruling N)" — the one list, not restated here). Applied from `out/REVIEW-attack.md`: 2.1, 2.2, 2.4, 2.5, 3.4
(V7 superseded by ruling 14 — no outside-project read remains), 4.1–4.3, 5.1–5.3, 6.2–6.6, 7.2, 7.5,
7.6, 8.2–8.5, 9.1–9.6, 10.2, 10.3. Rulings 1–22 applied in full; the per-item mapping is
`out/FIXLOG.md`.

## Revision 3 (2026-09-07)

Applied from `out/REVIEW-verify.md`, every item — see `ARCHITECTURE.md`'s Revision 3 note for the
list; on this document: Q13; Phase 0 reduced to V1 and the new Phase 1.9 (V2–V6, ordered so V4 pins
the tag V3 creates, with the clean-up that leaves one slug for Phase 3); Phase 2 under
the dev-checkout invocation (respelled by Revision 4) with `round import` into `.gbg/rounds/` and a `recorded.toml` per round;
the verb table gains `gbg probe`, `gbg migrate baselines`, `gbg fleet --diff`, `gbg round import
--empty`, `gbg config --toml`, loses the `regrade` alias, and `init`/`sync` state what each renders;
`Config.jl` reads TOML; PF-0 is `init`, PF-1 is `sync`, PF-2 finds Phase 2's rounds and discards
`doc-review-prev` per Q13, PF-4 reads the migrated baselines; 5.1 under `--dev` at the tag; IT's round
4 by `import --empty`; SS and CP steps renumbered to the same order, CP's config named as §5.4; the
rule ids cited here carry the `RULE.` prefix. The per-item mapping is `out/FIXLOG.md` "Revision 3".

## Revision 4 (2026-09-08) — IT amendments + Python retirement

Applied from `07-IT-amendments.md` by number (see `ARCHITECTURE.md`'s Revision 4 note for the design
side), on this document: **(2)/(3)/(4)/(5)/(6)** — the `gbgdev` invocation at the top; §A keeps the
table minus Q1/Q2; Phase 0 drops the `python3` precondition; 1.1's `Project.toml` gains `SHA`, `Dates`,
`JSON3`, `Gumbo`, `AbstractTrees` and the tree replaces `gbg/*.py` with `src/CLI/*.jl`, `src/Scans/*.jl`,
`src/TreeHash.jl`, `src/HtmlWalker.jl` and the transitional `src/CLI/consolidate.py`; 1.2's shim execs
`julia --startup-file=no --project="<root>/docs"` and scans no slug; 1.3's exit contract is
`main(ARGS)::Int` with exceptions → 3, the verb table's module column is `src/CLI/*.jl`, `gbg hook
queue-guard` is deleted, `gbg migrate baselines` and the validator are Julia, `gbg selftest` is the
`Pkg.test()` wrapper; 1.4 has no `run_gate` — `makedocs` and `TestHarness.gate()` call `doctor`,
`scan_docs`, `scan_html` and `gate` in-process; 1.6 is retitled, its targets are `src/CLI/*.jl` and
`src/Scans/*.jl`, and the `consolidate.py` row carries the byte-comparison acceptance test with the
deletion in the same commit; 1.7's templates gain `queue-guard.sh.tmpl` and lose the python CI step;
Phase 1's definition of done asserts `consolidate.py` is gone; Phase 1.9's V5 becomes "no `python3`
needed on the runner"; Phases 2–3 use `gbgdev`, `install` runs from the pinned fixture's docs env.
**(14)** — `catalog/seeds/` keeps `fixture.toml` alone; PF-0 and 5.2 write each consumer's
`.gbg/seeds.toml` at `init`; Phase 6/8 no longer promise SS/CP catalogues as tool releases. **(4b)** —
PF-1 removes the hand-written hook before `sync` renders the managed `queue-guard.sh`; PF-6 and the
deletion list follow. **(16)** — §A's note and Phase 5.2's "not applied here" paragraph. **(17)** —
§B's `git add -u` line, and PF-8 stages that way. **(10)/(9)/(13)** — 1.3's `round` row runs
`CFG.TORN`, 1.7's schemas admit `[exemption.match]`, 1.8's arms cover `CFG.TORN`, `EXEMPT.BROAD` and
the softened `LEG.SENTINELS`. The per-item mapping is `out/FIXLOG.md` "Revision 4".

## Revision 5 (2026-09-08) — IT corrections A–D

Applied from `08-IT-corrections.md` (see `ARCHITECTURE.md`'s Revision 5 note for the design side), on
this document and nothing else: **(A)** 1.3's `sync` row and the note after the table, 1.6's
`queue-guard.sh.tmpl` row, 1.7's templates, PF-1 and the deletion list — the rendered hook is PF's
`queue-guard.sh` verbatim (guards `WORK_QUEUE.md` `- [ ]` items, `stop_hook_active` kept, never reads
`.gbg/rounds/`, never starts Julia), so PF-1's `git rm` + `sync` replaces the hand-written copy with
the same body under a hash; **(B)** 1.3's `preflight` and `round` rows, 1.4's `makedocs` and
`TestHarness.gate()`, 1.8's arm, and one sentence after Phase 4's table — `CFG.TORN` is outside
`QUICK`, run by `preflight` and the `round` verbs only, so PF-3's docs build and PF-4's `Pkg.test()`
run with the sub-environment `Project.toml` files PF-0 modified and PF-8 first commits; **(C)** 1.1's
`Project.toml` (`Documenter` under `[weakdeps]`, `[extensions] GBGCodingToolsDocumenterExt =
"Documenter"`, compat kept) and tree (`ext/GBGCodingToolsDocumenterExt.jl`), 1.4's `makedocs` and
`DocLints.jl` bullets, the fixture's docs-environment note in 1.7, Phase 7's compat sentence; **(D)**
1.7's `exemptions.schema.json` bullet (the `arg_type` semantics and the text-scan refusal at
`CFG.EXEMPTIONS` exit 2, `symbol` over the owning binding's name, engines reporting their trigger
population), 1.4's `Reflection.argcov` clause, 1.8's arm. The per-item mapping is `out/FIXLOG.md`
"Revision 5".

## Revision 6 (2026-09-09) — the tool as its own consumer

Applied from `09-revision6-self-application.md` (see `ARCHITECTURE.md`'s Revision 6 note for the design
side), on this document: **(8)** Phase 1 gains **1.10 "the tool as its own consumer"** — the docstrings,
`docs/` (Project.toml on `path = ".."`, `make.jl` through the wrapper with `checkdocs = :exports` and
`doctest = true`, the page list, the `## Revision history` heading), `gbgdev init` on the tool root
(`init` must work when `$DEV` IS the consumer) and `gbgdev sync`, the `runtests.jl` calls, `docs.yml` and
`CI.yml`, the scans and doctor on the tool, the first `/check-docs` round, the commit; Phase 0 gains the
GitHub Pages enablement as an owner action and V7 (verify the private-Pages deploy; runs after 1.10);
Phase 1's definition of done gains the tool's own docs build, `gbgdev doctor --deep` and `gbgdev gate` at
the root and the recorded `/check-docs` round; 1.3's `gbg release` row carries ruling 4(c)'s refusal
list and Phase 3's block runs the same checks before it; Phase 8's memory notes mention the docs site.
Also: §A gains **Q14** (Pages visibility, default private owner-only — the one choice the private
repository forces); 1.1's tree and `fleet.toml` gain the tool's own entries; 1.2's shim falls through to
the ordinary `--project=docs` route at the tool root; 1.3's `fleet` and `init` rows name the tool's row
and the tool-root `init`; 1.4 gains the docstring bullet; 1.8 gains the `SELF.CONSUMER` arms and the
clean-tag round arm; Phases 3, 4 (PF-8), 6 and 7 count the fleet's fifth row; `ci.yml` is spelled
`CI.yml`. **One collision between the rulings was named here** — ruling 5 asks for a `/check-docs`
round on the tool *closed* before `v1.0.0`, while ruling 1 makes a dev-stamped round closable only at a
clean released tag and ruling 4(c) has `gbg release` refuse an open round, so before the first tag no
tool round could close — and its Revision 6 resolution (record the round by an `abandon` listing no open
id) is SUPERSEDED by Revision 7's prerelease tag. The per-item mapping is `out/FIXLOG.md` "Revision 6".

## Revision 7 (2026-09-09) — the prerelease tag

One ruling (see `ARCHITECTURE.md`'s Revision 7 note for the design side), on this document: 1.3's
`gbg release` row gains the prerelease form `gbg release <ver>-rc.<n>` (the same refusals except the
open-round refusal and the closed-`/check-docs`-round precondition) and the final release's new
precondition (the round opened at the latest rc tag closed — honored/adjudicated, never abandoned);
1.10 item 7 is rewritten — commit, `gbgdev release 1.0.0-rc.1`, open the `/check-docs` round at that
clean tag (stamped with it, a normal closable round), drive it to zero open ids and CLOSE it with
`gbgdev round close`, never `abandon`; item 8 commits twice (before the rc tag, and with the fixes and the
closed record); Phase 1's definition of done asserts the round closed and the rc tag on GitHub; Phase 3
opens with the closed-round precondition and the optional `1.0.0-rc.2`, and its block's comment carries
the new precondition; 1.1's `CHANGELOG.md` shape gains the rc entry; 1.8's arms gain the round opened at
a clean `v9.9.9-rc.1` that closes. The "abandon listing no open id" resolution is deleted from item 7
and marked superseded in the Revision 6 note. The per-item mapping is `out/FIXLOG.md` "Revision 7".

## Revision 8 (2026-09-08) — the owner's rulings

Applied by the implementing session from the owner's answers to §A, given one by one on `Aiporetne`
(see `ARCHITECTURE.md`'s Revision 8 note for the design side). On this document: §A is retitled and
holds the rulings — Q3 (collapse; SS counted 0 bold / 80 plain), Q4 (drop), Q5 (yes), Q6 (true), Q7
(yes), Q12 (IT's fourteen notes cleaned out by the IT session in its own pre-migration commit), Q13
(discard — with the correction that `doc-review-prev` is the closed 2026-08-15 round 6, not a copy of
the 2026-09-01 panel), Q14 (deploy like the consumers: private repository, site public by URL; owner-only
Pages is unavailable on the account), the versionless trailer, and **the no-history ruling**: no consumer
carries a pre-tool round. §B gains the "uniform, and no history carried" agreement. Phase 0 and V7 name
the consumers' Pages setup as the target. 1.3's `round import` row calls the verb Phase 2's scratch verb.
Phase 2 imports on scratch, keeps the CHANGELOG table alone and deletes the imports in a new step 4; its
definition of done asserts that nothing remains. PF-2 becomes "empty rounds, empty ledger" (no
adjudications carried; `doc-review-prev` discarded with its true identity); PF's deletion list is
reworded. 5.2 drops the rounds import, deletes IT's piles, moves the live escalated and blocked witnesses
to `test/regressions/{escalated,blocked}/`, drops the carried adjudications, and records IT's own
clean-out under Q12. Phase 6 states Q3 as ruled and deletes SS's July pile unimported. Phase 7 states Q4
as ruled. Phase 8's memory note names the public site URL.

**Added 2026-09-09, PF's leftovers ruled** (same revision; `ARCHITECTURE.md`'s Revision 8 note lists
the design side): **the Stop hook is fleet-wide** — the switch `hooks.work_queue` is gone, `sync`
renders `queue-guard.sh` and `settings.json` in every consumer and seeds `WORK_QUEUE.md` (new
`templates/WORK_QUEUE.md.seed`); 1.3's `sync` row, 1.6's template row, 1.7, PF-1, PF-6, 5.2, Phases 6
and 7 say so, and PF-6 trims PF's 93 done lines; **requests** — PF-6 deletes PF's two concluded July
files, 5.2 reads IT's nine for status and moves only an open one; **`CLAUDE.md` skeleton** — new
`templates/CLAUDE.md.skeleton`; PF-5, 5.2, Phase 6 and Phase 7 gain the trim step (finished work
deleted, live plans to a tracked `docs/ROADMAP.md`), PF-8 stages `docs/ROADMAP.md`, Phase 8 item 2 is
rewritten; PF-6 also removes the empty `.claude/worktrees/`. §A carries the three rulings and Q5's
consequence (`settings.json` everywhere).
