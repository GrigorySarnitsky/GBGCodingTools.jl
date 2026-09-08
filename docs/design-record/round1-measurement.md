# Round-1 proposal — the measurement-integrity lens

Author lens: instrument contracts. Everything below is organised around one claim: **a review
instrument is a measuring device, so the package's first job is to make every number it emits
traceable to (a) a frozen instrument version, (b) a frozen input, (c) a grader that is not the
graded party, and (d) a gate whose missing case fails.** The four instruments, the build lints and
the test harnesses are then instances of ONE round contract, not four protocols with family
resemblance.

Evidence citations use the survey files in this directory: `CD` = `survey-checkdocs.md`, `CC` =
`survey-check-consistency.md`, `BH` = `survey-bughunt-auditchanges.md`, `BL` =
`survey-buildlints-hooks-policy.md`, `TP` = `theory-patterns.md`, `PF` = `facts-claude-code-platform.md`,
`REQ` = `00-requirements-draft.md`. Repo paths as in the surveys.

---

## 0. The one contract (read this before the decisions)

Every instrument run is a **round**. A round is a tracked directory in the consumer,
`.gbg/rounds/<YYYY-MM-DD>-<instrument>-<NN>/`, created by the tool's CLI before any agent runs, and
it carries, in this order of life:

1. `ROUND.toml` — the **marker**: instrument, tool version+rev, config hash, git HEAD, roster,
   cost mode, hostname, model, `opened`, later `banked`, `closed` (or `abandoned`). Written only
   by `gbg`, never by an agent or the session by hand.
2. `findings/NN-<lane>.json` — one file per lane, written by the lane's **agent** (a Workflow
   script has no filesystem; its agents do), in the shared finding schema.
3. `findings.json` — the **frozen denominator**: the CLI's validated, ID-assigned union of the lane
   files, with its sha256 in `ROUND.toml`. After banking, findings never change.
4. `verdicts/pass-<k>/pass.toml` + `act/NN-<lane>.json` + `state/NN-<lane>.json` — one pass of the
   two verifiers, in a directory the CLI created (so a stale verdict cannot be mistaken for a
   current one: there is no "current" file, only "the highest-numbered pass").
5. `verdicts/pass-<k>/tally.json` — computed by the CLI from the verdict files, applying the ONE
   demotion predicate and the ONE closure predicate. This is the only tally anything reads.
6. `ground_truth.json` (seeded rounds), `witnesses/` (bug-hunt), `audit.json` (audit-changes),
   `CLOSED.md` (the abandon escape, with its account).

Five properties hold for every instrument, enforced by code in the tool, not by prose:

- **P1 Fail-closed.** No config → exit 2. No round where a gate expects one → fail. A lane whose
  file is absent, unparsable, or reports zero findings without a `checked` enumeration → DEAD, and a
  round with a dead lane cannot close. Unknown verdict string → schema error. (`REQ` R3; `CC` §6.1,
  §6.10; `BH` §5.7.)
- **P2 Grader ≠ graded.** The grader's code lives in the tool repo at a pinned tag; the fixer (the
  main session) can change it only by bumping the pin, which `ROUND.toml` records and the closure
  refuses. Denominators come from the CLI's count of banked files, never from a lane's self-report
  and never from a census agent (`CC` §6.6 — the census agent existed only because the JS could not
  see files; the CLI can). Demotion runs in the CLI, from files, and its share is reported apart
  (`CC` §6.7, §6.8).
- **P3 Frozen instrument per round.** `ROUND.toml.instrument_rev` is checked by every later
  `gbg round …` command; a mismatch is exit 2 ("re-open a pass under the new version with
  `--regrade`, which supersedes the prior passes") — never a silent continuation (`REQ` R4;
  `CC` §6.3; `BH` §5.14).
- **P4 One vocabulary.** Every enum is a constant in `schema/*.json`; the config cannot override one;
  changing one is a MAJOR release with a recalibration (`REQ` R11; `TP` §2e, §5e).
- **P5 Every gate has a must-fail arm.** The tool's own test suite perturbs a fixture consumer and
  requires each gate to fire; a gate whose fixture is absent fails (`REQ` R5; `CC` §6.15, §6.17).

---

## 1. Decisions D1–D19

### D1 Unit of distribution — ONE repo, three faces

**Choice.** One git repo `GBGInstruments` holding (i) a Julia package at its root (the build lints
and the test-side harnesses), (ii) `python/gbg/` — the single CLI and every deterministic gate,
(iii) `workflows/*.js` — the Workflow engines, (iv) `plugin/` — a minimal Claude Code plugin (thin
skills + generic agent personas), (v) `schema/`, `catalog/`, `policy/`, (vi) `fixture/` + `tests/`.
One tag versions all of it.

**Forced by.** R4/R2: a round must name ONE version that covers the JS that spawned the hats, the
Python that graded them and the Julia lint that gates the build — three repos would need three
stamps, and their skew is exactly the "which instrument measured this" question R2 forbids. `BL` §1's
provenance table shows what split ownership does: `lint_inline_math` forked three ways from one
origin in six weeks. R7 (polyglot, versioned together).

**Alternatives.** *Three repos (Julia / plugin / CLI)*: dominated — three pins per consumer, and a
schema change must land in two of them atomically or the CLI reads a vocabulary the Julia gate does
not know. *Julia-only package*: dominated — Workflow scripts and skills cannot be delivered by Pkg.
*Plugin-only*: dominated — a plugin cannot ship Workflow scripts (`PF` §1) nor be a `test/` dep.

### D2 Delivery to a machine — a per-machine clone outside Dropbox, one worktree per tag

**Choice.** `git clone git@github.com:…/GBGInstruments ~/.gbg/instruments/repo`, and
`gbg self ensure` materialises `~/.gbg/instruments/<tag>/` as a `git worktree` for every tag any
local consumer pins. A shim `~/.local/bin/gbg` (installed once by `install.sh`) reads the calling
consumer's pin and executes that worktree's CLI. Both hosts run `install.sh` once; nothing else is
per-machine.

**Forced by.** R8 (reproducible per-machine install, no secrets in repo): the shim + tag worktrees
are reproducible from a URL and a tag. Two consumers pinned to two tags during a staged upgrade
(R9, `TP` §2b) need two checkouts present at once — worktrees give that; one clone on a branch
does not. A clone *inside* Dropbox is dominated: Dropbox syncing `.git/` state between two live
machines corrupts it, and the two machines may legitimately want different tags checked out.

**Alternatives.** *Clone in Dropbox (fleet-synced by construction)*: dominated as above. *Plugin
marketplace install as the only channel*: dominated — no per-project pinning (`PF` §2), and it does
not deliver the Julia package. *Julia registry (LocalRegistry) for everything*: dominated for the
non-Julia halves; kept as the D3 route for the Julia half in a later step (`TP` §8a).

### D3 Binding consumer → tool — a tag in `.gbg/instruments.toml`, resolved by the shim; Julia by `[sources] rev`

**Choice.** `.gbg/instruments.toml` carries `pin = "v1.2.0"`. The `gbg` shim resolves
`~/.gbg/instruments/v1.2.0`. `test/Project.toml` and `docs/Project.toml` carry
`[sources] GBGInstruments = { url = "git@github.com:…/GBGInstruments", rev = "v1.2.0" }`. Skills
ask the CLI for the Workflow `scriptPath` (absolute, inside the pinned worktree) and never hard-code
one. `gbg pin set v1.3.0` rewrites all three places in one commit; `gbg doctor` fails if they
disagree.

**Forced by.** `PF` §1: `${CLAUDE_PLUGIN_ROOT}` is not usable in skill bodies, so a skill cannot find
a plugin-relative script; an absolute worktree path printed by the CLI is the one thing every
component can use. `[sources] rev` needs no registry and works from `test/` and `docs/` envs on
Julia ≥ 1.11 (`TP` §8b; SS's 1.11 floor, `BL` §7). A `rev` is immutable (`TP` §2a).

**Alternatives.** *`~` symlink to one "current" checkout*: dominated — one version fleet-wide, no
staged upgrade, and the version a round ran under is not recorded anywhere the round can read.
*Env var*: dominated — invisible in the repo, so R2 fails. *Submodule / subtree / vendored copy*:
dominated (`TP` §2c: Dropbox + `.git` state, hidden divergence, and vendoring is the disease).
*`[sources] path = "/home/grigory/.gbg/…"`*: works but ties the manifest to a home directory; kept
as a documented offline fallback.

### D4 Version pinning — per-consumer pin, fleet check demands convergence within one sweep

**Choice.** Each consumer pins its own tag (staged upgrades need it). `gbg doctor --fleet` reads
`~/.gbg/fleet.toml` (the four repo paths) and reports the four pins; two distinct pins are a
WARNING for 7 days after the newer tag's date and a FAILURE afterwards. Divergence is detected by
the doctor and by `ROUND.toml` (a round names its version, so cross-consumer comparisons refuse
unequal MAJOR.MINOR — `gbg rounds compare`).

**Forced by.** R1 (same version) against R9 (no big-bang): the one-version rule with a bounded
window (`TP` §2d, §6c).

**Alternatives.** *Single fleet-wide pin file in the tool repo*: dominated — a consumer would then
run code its own repo does not name (R2). *No pin, always HEAD*: dominated by R4 outright.

### D5 Config — one TOML file, one layer, strict schema, compiled to Workflow args by the CLI

**Choice.** `.gbg/instruments.toml` (schema in §3). No layering, no env overrides, no local file;
machine facts (`hostname`, `Threads.nthreads()`, GPU vendor) are read from the machine and printed
by `gbg config effective`. Unknown key → exit 2; missing required key → exit 2; every default is
materialised into the file by `gbg init` so the file is complete on its own. Workflow scripts
receive **only** the args object `gbg <instrument> open` prints (config + round path + stamps +
expected counts); the JS never reads config (it cannot) and never carries a default that the CLI
also carries.

**Forced by.** `PF` §1 (Workflow config only via args); `TP` §7b (layering destroys the "why did this
threshold apply" answer, R2); `CD` §3 — four copies of the surface list inside PF alone (`.md`,
`guards.sh`, `sentence_openers.py`, `make.jl`) is what a single compiled config removes.

**Alternatives.** *JSON*: dominated — no comments, and every consumer's house format is TOML.
*YAML*: dominated — a second parser dependency for nothing. *`.claude/` as the location*:
dominated — the directory is Claude Code's, its tracking policy differs per repo (`BL` §2), and the
tool's artefacts must be greppable as one tree; `.gbg/` is that tree.

### D6 Skills — plugin skills `/gbg:<instrument>`, thin by construction

**Choice.** The tool repo is itself a marketplace (`.claude-plugin/marketplace.json` with
`source = "./plugin"`); each machine adds it once from the local clone. The plugin ships four
skills + `doctor` + `round`, each a ≤ 40-line SKILL.md whose body is: "run
`gbg <instrument> open …`; invoke Workflow with the `scriptPath`/`args` it prints; then
`gbg round bank`; …" — no rubric text, no surface lists, no hat names. Because the skill only calls
the CLI, the plugin version is irrelevant to measurement and the "no per-project pinning" limit
(`PF` §2) costs nothing. Generic hat personas ship as data in `catalog/hats/*.md`, not as plugin
agents (an agent's persona must be composable with the consumer's PREAMBLE, which the JS does).

**Forced by.** R6 (nothing duplicated in a consumer), R10 (a 5th package = config + scaffold, no
command files to port), `CD` §5 (the rubric is quadruplicated inside IT: CLAUDE.md, `.md`,
`lanes.js` preamble, `lint_docstring_shape`).

**Alternatives.** *Generated per-consumer `.claude/commands/*.md` stubs*: kept as the documented
**fallback** if a local-path marketplace turns out unsupported (verify on day 1 — `PF` §2 lists
GitHub/URL/local sources for *plugins*, and adding a marketplace from a local path is the one
untested step). Stubs would be managed files (D13). *Both*: dominated — two places for a stub to
rot.

### D7 Workflow scripts — one generic engine per instrument, catalogues as data

**Choice.** `workflows/` holds `panel.js`, `lanes.js` (check-docs fan-out), `verify-act.js`,
`verify-state.js`, `hunt.js`, `dismissals.js`, `audit.js`, `attack-design.js`, `rubric-audit.js`,
`severity-recheck.js`. Each takes ONE args object (§4) and holds no package string: package
description, deliberate absences, surfaces, personas, lanes, oracles and executable claims arrive in
args. Hat and lane catalogues are data: `catalog/hats.toml` (the eight generic hats plus IT's
generic lenses: free-reader ×3, logician, plain-sense, existence, quantifier, conjunction,
conceptual-clarity, reader-standpoint, fossil-and-drift) with `persona_file`; a consumer adds domain
hats in its own `.gbg/hats/`. Scripts never compute a tally; they return **liveness only**
(`{written, dead, empty, truncated}`) and tell the session to run `gbg round bank|grade`.

**Forced by.** `CC` §4(a): every coupling in `panel.js` is data (22 hits, all persona/preamble);
`BH` §3: `audit.js`'s IT preamble still says "605 lines inserted" on every run — a script that
carries round data rots. P2: a script that both spawns graders and tallies them is the twin problem
(`CC` §5.1, `PF make.jl` "edit the two together").

**Alternatives.** *Per-consumer scripts*: the status quo, dominated by the surveys' drift tables.
*One mega-script switching on instrument*: dominated — a hunt and a panel share nothing but
`agent()`, and a shared file makes an instrument change touch every instrument's version.

### D8 Deterministic helpers — one Python CLI `gbg`; Julia only where Julia is the subject

**Choice.** `python/gbg/` (python3 ≥ 3.10, stdlib only — no `jsonschema` dependency; the schema
validator is 120 lines of stdlib) exposes `gbg <instrument> <verb>` and the cross-instrument verbs
`round`, `gate`, `doctor`, `pin`, `config`, `selftest`, `scaffold`. Julia scripts exist only where
the package must be loaded: `julia/witnesses.jl`, `julia/argcov.jl`, `julia/signature_fidelity.jl`,
`julia/xlink.jl`, and they are always invoked by `gbg`, never by hand. `guards.sh` becomes
`gbg check-docs guards`: a tiered scan engine reading `catalog/scans.toml` (id, tier `hard|soft`,
pattern, surfaces, rationale, must-fail fixture) — a scan without a fixture is refused at tool test
time. Exit-code contract for EVERY `gbg` verb: **0** pass; **1** substantive failure (a finding, an
open round, a stale audit); **2** cannot evaluate (no config, no round, unreadable/unparsable input,
version mismatch) — fail-closed but distinguishable; **3** tool defect (uncaught exception). Never
`0` with a printed problem; never truncated output (`CD` §7.1).

**Forced by.** `CD` §2 (IT retypes greps from prose; PF's `guards.sh` is the postmortem); `CD` §7.2
hard/triage tiers; `BH` §4.5 (two `gate.py` with incompatible piles); `BH` §4.3 (`witnesses.jl`:
PF exits 0 with erroring witnesses; IT hard-codes a `..` path — the shared runner takes the
directory as an argument, quotes paths, uses `Base.julia_cmd()`, and exits non-zero on BROKEN).

**Alternatives.** *Loose scripts as today*: dominated. *Julia for everything*: dominated — a gate
must run before Julia is even resolvable (`BL` "three envs broken at once") and in seconds.
*Bash*: dominated — `CD` §3 records `guards.sh` hard-coding nine file names in one awk line.

### D9 Julia-side library — `GBGInstruments.jl`, a `test/`/`docs/`/`benchmark/` dependency, `julia = "1.11"`

**Choice.** Exports, docs side: `lint_docs(config_path)` (runs every lint the config enables:
inline-math, notation variants with the consumer's banned/prescribed sets, swallowed escapes,
retired claims, API page structure, prose-shape ratchet — IT's always-binding caps and PF's
page-unit extension merged, one CSV schema — AI banner, and post-`makedocs` rendered markup), which
ends by calling `run(gbg gate --instrument docs)` and throws on non-zero. Test side:
`@alloc_below`, `field_threshold`, `CountingArray`/`Traffic`/`audit` (pass audit),
`public_surface(mod)`, `method_parity(baseline_csv)`, `oracle_registry(...)`,
`include_regressions(dir)`, `display_gate(...)`, and `test_gates(pkg)` (Aqua + JET with the
module list from config). Frozen baselines stay in the consumer. Compat `julia = "1.11"` and CI on
1.11 + 1.12: SS's floor (`BL` §7) is the binding one, and nothing here needs 1.12.

**Forced by.** `BL` §5 (the harness matrix: PF-only guards with IT drift on `display.jl`, IT's
`UnionAll` fix never back-ported); `BL` §1 (lint provenance); `TP` §8e (consumed like Aqua).
`lint_review_closure` shells to `gbg gate` because the closure predicate must exist ONCE (`CD`
§7.8) and it lives in Python beside the demotion predicate it depends on.

**Alternatives.** *Reimplement the gate in Julia*: dominated — the twin. *Runtime `[deps]`*:
dominated — a consumer's users would install graders (`TP` §8c).

### D10 Piles and rounds — tracked, one layout, marker written by the CLI, closure per finding

**Choice.** §0. All four instruments bank under `.gbg/rounds/`, **tracked**; gitignored inside a
round: `manuscript/`, `seeded/`, `witnesses/env/`, `scratch/`. The marker is created by `gbg
<instrument> open`, which is the only launch path the skills know, so the "self-reported marker
creation" hole (`IT make.jl` L268-280) closes: no marker → no args → no round. Closure is per
finding through three channels (D11): a HONORED verdict in the latest pass; an entry in
`.gbg/adjudicated.toml` keyed by finding **ID** (`<round>/<lane>#<n>`, so an untitled `## Finding 6`
can be adjudicated — `PF doc-review/CLOSED.md` L23-28); or a `seeded` mark from the round's own
`ground_truth.json`. The wholesale escape is `gbg round abandon --reason "…"`, which writes
`CLOSED.md` and `closed = "abandoned: …"` — it must list every open finding ID it abandons, so the
diff shows exactly what was waved through.

**Forced by.** `CC` §5.4 (each gate has the hole the other closed: PF vacuous on a clone, IT
certifies only that a human wrote an account); `CC` §5.5 and `IT INVENTORY.md` L118-121
(per-finding channel is the routine exit; wholesale is the one you reach for when there is none);
`BH` §5.15 (tracking decides whether a gate can run on a clone). Size is not an argument: PF already
tracks 51 pile files.

**Alternatives.** *Untracked piles + tracked marker (IT)*: dominated — a clone cannot re-grade, so
R2's "what changed between rounds" is unanswerable there. *Round-level `closed:` only*: dominated —
`CC` §5.4. *Title-keyed adjudication (PF)*: dominated by the untitled-heading failure; IDs are
assigned by the CLI at banking and are stable thereafter.

### D11 Schemas — one JSON schema per artefact kind, fixed vocabularies, extension by declared fields

**Choice.** `schema/finding.json`, `verdict-act.json`, `verdict-state.json`, `hunt-candidate.json`,
`reproduction.json`, `dismissal-audit.json`, `audit-concern.json`, `round.json`, `pass.json`,
`tally.json`, `adjudicated.json`, `exemptions.json`, `ground-truth.json`. Vocabularies (constants,
§4.1): severity `blocker|major|minor|nit` for every instrument (audit's `serious` ≡ `blocker|major`);
state verdicts `PRESENT|PARTIAL|REGRESSED|ABSENT|NOT-A-DEFECT|UNCLEAR` (default PRESENT; only
ABSENT and NOT-A-DEFECT are favourable; PARTIAL carries `surviving_class`); act verdicts
`HONORED|ADJACENT|INSERTED|LINE-ONLY|NEW-DEFECT|SCOPE-CREEP|UNDONE|LAUNDERED` (IT's eight; PF's six
are a subset) with `question ∈ fidelity|strategy|implementation|scope|none`; `class_surfaces` is an
**array of `{surface, swept, evidence}`**; reproduction
`REPRODUCED|EVIDENCED|NOT-REPRODUCED|WITNESS-WRONG|NO-WITNESS-POSSIBLE|ALREADY-COVERED|NOT-A-DEFECT`
(confirmed = REPRODUCED ∪ EVIDENCED); hunter `observed ∈ FAILS|PASSES|ERRORS|NOT-WRITABLE`;
`kind ∈ runtime|architecture|api-semantics`; dismissal audit `DISMISSAL-SOUND|UNSAFE|DISMISSAL-WRONG`
(default UNSAFE); dispositions everywhere `fixed|refused|escalated` (a refusal carries `reason`
≥ 24 chars and `evidence`; bug-hunt's `refuted` is `refused` with `evidence = witness-wrong`).
Finding `type` has a shared core enum plus `domain_type` drawn from the consumer's declared
`[schema.finding_types_extra]` list. Every artefact carries `schema_version` (= the tool's MAJOR).

**Forced by.** R11; `BH` §5.1 ("a SCHEMA divergence, not wording: `dismissals`, `closure` and
`finished` all key off it"); `CC` §5.3 (`coverage.py` already anticipates a union); `CC` §5.1 (the
array form is what lets the gate apply the emptiness predicate at all — PF's gate regex-extracts a
string because its artefact is markdown). Markdown is a **rendering** (`gbg round render`), never the
record.

**Alternatives.** *Per-consumer vocabularies*: dominated by R11. *Markdown as the record with
regex parsing*: dominated — `CC` §2 lists four heading forms, two bold spellings, and one hat that
parsed to zero; `CD` §5 the `## 1. CORRECT` collision. *Open extension (`additionalProperties`)*:
dominated — that is how `previously_worked` and `checked` came to exist in one tree each (`BH` §4.4).

### D12 Rubric/policy prose — single source in the tool, rendered into managed consumer copies, deviations declared

**Choice.** `policy/*.md` in the tool (docs-rubric, style-latex, citations, cost-register,
instruments-protocol, definition-of-done, commit-conventions) with **marked variation points**
(`<!-- gbg:option in_place_steer -->`). `gbg scaffold` renders them into `.gbg/policy/*.md` with the
consumer's `[rubric]` choices applied and a generated-file header; `CLAUDE.md` carries ONE managed
block: `@.gbg/policy/00-index.md` (relative import, no approval dialog — `PF` §4). A deviation is
data: `[[rubric.deviations]] rule = "in_place_steer", ruling = "declined", date = 2026-08-25,
reason = "…"`; an undeclared difference between a consumer's CLAUDE.md and the rendered policy is a
doctor finding. The battery reads the rubric from the same rendered files (the lanes' substrate
args name them), so hat, session and lint read one text.

**Forced by.** `CD` §5, `BL` §4 (the rubric triplicated by hand with quoted paraphrase drift; IT's
owner-ruled deviations exist and must stay — `CD` §7.18); R2 ("what does this package deviate in and
why" from committed artefacts — the rendered copy is committed at the consumer's rev, so the rubric a
round ran under is in that repo's history, not only in the tool's).

**Alternatives.** *Import straight from the pinned worktree (`@~/.gbg/…`)*: dominated — the text a
round read is then not in the consumer's history, and every pin bump edits CLAUDE.md. *Keep
CLAUDE.md prose per repo, lint for agreement*: dominated — it is the status quo plus a linter.

### D13 Managed files — exactly these, each with a class

Consumer footprint in §2.2. Classes: **config** (owned, validated), **generated-managed** (header
`# generated by GBGInstruments <tag> from <template>; DO NOT EDIT`, sha256 in `.gbg/MANIFEST.json`,
doctor states OK / MODIFIED / STALE), **seeded-once-then-owned** (created empty by `gbg scaffold`,
never touched again; `_skip_if_exists` in Copier's terms — `TP` §3a), **tracked-pile** (rounds).
Update path: `gbg scaffold --update` re-renders generated-managed files only; a MODIFIED file is
refused (the change belongs in the tool or in config), never merged.

**Forced by.** `TP` §3c vs §3a — three-way merge invites editing rendered text, which is how the
drift started; `CD` §4 (PF's `MANIFEST.txt` listing 3 of 6 scripts: a manifest must be derived,
so `MANIFEST.json` is written by the same command that writes the files).

### D14 Doctor — read-only, stable check IDs, exemptions with reason + expiry, fleet view

**Choice.** `gbg doctor` (per repo) checks: config valid; pin is a tag and the three pin sites
agree; worktree present and its `selftest` stamp green; managed files OK; `make.jl` contains the
`lint_docs` call; `runtests.jl` contains `include_regressions`; `test/regressions/` exists;
`.gitignore` carries the managed lines; no open round older than 14 days; no `MODIFIED` file; every
exemption unexpired; the docs/test environments **load** (`julia -e 'using GBGInstruments'` in
each — `BL` "resolve/instantiate/LOAD are not interchangeable"); no `dev`'d instrument package in a
committed manifest; branch name matches config. Each check has a stable ID (`D-PIN-AGREE`), and an
exemption is `[[exemptions]] check = "D-…", reason, recorded, expires, evidence` in
`.gbg/exemptions.toml`; expired → fail, ≤ 30 days → warn. `gbg doctor --fleet` renders the
scorecard over `~/.gbg/fleet.toml`.

**Forced by.** R1 ("a difference is either declared config or a finding"), R9 (the migration
checklist IS the doctor going green), `TP` §4a-d.

### D15 Self-testing — a fixture consumer, seeded corpus, a must-fail arm per gate, CI on tags

**Choice.** `fixture/GBGFixture/` is a 300-line Julia package with docs, a docstring corpus carrying
every catalogued defect class, a `benchmark/` stub, and a complete `.gbg/`. `tests/` (pytest-free,
stdlib `unittest`, run by `gbg selftest`) covers: (a) every scan in `catalog/scans.toml` against its
fixture (must hit, and must not hit the clean twin); (b) every gate in both directions — `round
close` refuses an open finding, accepts all-HONORED, refuses a dead lane, refuses a version
mismatch, refuses a missing round, refuses a tampered tally (recompute ≠ stored); (c) the demotion
predicate's five falsification cases (`IT verify-fixes.js` L196-203) plus PF's "swept to zero with
no list" case; (d) `recall` arms A–D built in the test, not drawn from a catalogue (`PF
recall_selftest.py` header); (e) `witnesses.jl` classification: pass/fail/broken each from a fixture
file; (f) `argcov` exemption fixture; (g) schema round-trips; (h) `scaffold` idempotence and
MODIFIED detection. Julia-side: `Pkg.test()` of the tool runs the harness self-checks (a
`CountingArray` count fixture, `@alloc_below` on a known allocator, the display gate against a
planted type). CI: GitHub Actions on tag push and manual — small enough not to burn the tier.

**Forced by.** R5; `CC` §6.15/6.17; `CD` §7.4; `IT make.jl` L232-242 six arms — every one of these
today is a comment or a one-off, and "a check that cannot fail is not a check".

### D16 Instrument change discipline — semver with a measurement-specific MAJOR rule, CHANGELOG, stamps, no mid-round upgrade

**Choice.** MAJOR: any change to a vocabulary, a schema, the demotion or closure predicate, a scan's
tier or pattern in `hard`, the seed catalogue mechanism, or a tally formula. MINOR: a new lint,
hat, scan (soft), or verb. PATCH: prose, messages, fixture data. `CHANGELOG.md` is mandatory per
tag and names, for a MAJOR, the recalibration run on the fixture (recall before/after). Stamps:
`ROUND.toml` and every `pass.toml` carry `{tool_version, tool_rev, schema_version,
seed_catalog_sha256, config_sha256, julia_version, hostname, model_hint}`. Mid-round pin bump: any
`gbg round …` verb exits 2 on mismatch; `gbg round pass open --regrade` records
`superseded_by_version` on the earlier passes and starts a new pass series; the closing pass must
be at the round's *current* version.

**Forced by.** R4; `IT INVENTORY.md` "Instrument freeze" (PF's 54.8 → 96.8 % is uninterpretable);
`TP` §5e (SPEC run rules), §2e.

### D17 Migration — PF, then IT, then SS, then CP; doctor-verified steps; deletions listed

§5. Order by strictness and by what each teaches the tool: PF (the canary, richest gates), IT
(the divergences to resolve are PF↔IT), SS (the July fork — pure collapse), CP (nothing to delete;
pure scaffold — proves R10).

### D18 Model/cost policy — economy default in the tool, anchors named in config, fix phase hard-coded full

**Choice.** `[cost] default = "economy"`; a hat/lane is economy unless `anchor = true` in the
consumer's roster (its domain hats) or in the catalogue (the `executing` audit lane, the free hunt
lanes, reproducers, adjudicators, dismissal auditors — these anchors are **not** configurable
because they are the grounding, `BH` §5.5). Economy = `model: 'sonnet'` in the JS; anchors omit
`model` (session model). The fix phase, verification and consolidation are never economised —
there is no config key for it. `strength = "full"` is a per-run flag stamped into `ROUND.toml`.

**Forced by.** R12; `CC` §1.1/1.2 (two vs four anchors are config); `BH` §2 (IT ignores `strength`,
PF honours it — an artefact).

### D19 Name — `GBGInstruments`

`TP` §9's recommendation, and the reason is R2: every doc in the four repos already says
"instrument", "ruler", "calibration", "frozen"; the name binds the metaphor the corpus uses. The
owner's `GBGCodingTools` is accurate but says nothing about measurement, which is the property the
package exists to guarantee; `GBGDevTools` is the safe second. The module docstring's first
sentence binds "instrument" to its metrology meaning.

---

## 2. Layout

### 2.1 The tool repo

```
GBGInstruments/
  Project.toml                  Julia package: lints + test harnesses; julia = "1.11"
  src/GBGInstruments.jl         umbrella; submodules below
  src/DocLints.jl               lint_docs(config): inline math, notation variants (configured sets),
                                swallowed escapes, retired claims, API page structure, prose-shape
                                ratchet (one CSV schema), AI banner, rendered markup; ends with gate
  src/TestHarness.jl            @alloc_below, CountingArray/Traffic/audit, public_surface,
                                method_parity, oracle_registry, include_regressions, display_gate,
                                test_gates (Aqua+JET)
  src/Config.jl                 reads .gbg/instruments.toml (strict keyword struct = the schema)
  test/                         the Julia half's own tests (against fixture/)
  python/gbg/__main__.py        the CLI entry; every verb is python/gbg/<verb>.py
  python/gbg/schema.py          stdlib JSON-schema-lite validator + the vocabularies (loaded from schema/)
  python/gbg/round.py           open/bank/pass/grade/close/abandon/render — the ONE round contract
  python/gbg/gate.py            enumerates rounds; open→1, absent-where-expected→2, tamper→1
  python/gbg/demote.py          THE demotion predicate (emptiness of class_surfaces[]), one place
  python/gbg/recall.py          seeded-defect matching; skipped classes UNDEFINED, kept in report
  python/gbg/seed.py            plants a consumer's catalogue into a scratch manuscript
  python/gbg/consolidate.py     built HTML → manuscript-full/siteonly, withhold list from config
  python/gbg/scans.py           tiered scan engine over catalog/scans.toml (+ consumer overrides)
  python/gbg/doctor.py          checks with stable IDs; --fleet
  python/gbg/scaffold.py        renders managed files; MANIFEST.json; --update; refuses MODIFIED
  python/gbg/pin.py             pin set: instruments.toml + test/docs [sources] rev, one commit
  python/gbg/selftest.py        runs tests/ ; writes SELFTEST.<tag>.ok in the worktree
  python/gbg/instruments/{check_docs,check_consistency,bug_hunt,audit_changes}.py
                                per-instrument open/plan: compile config → Workflow args; print scriptPath
  julia/witnesses.jl            <dir> --expect fail|pass [names…]; quotes paths; Base.julia_cmd(); BROKEN→exit 1
  julia/argcov.jl               exemptions from args; Unicode identifiers; policy triage|gate from config
  julia/signature_fidelity.jl   loads the package (needs --project); triage
  julia/xlink.jl                dry-run by default; --apply
  workflows/panel.js            hats × substrate → findings/NN-<key>.json; returns liveness only
  workflows/lanes.js            check-docs surface + family + cold-reader lanes; same output shape
  workflows/verify-act.js       sees the diff; act verdicts; writes verdicts/pass-k/act/NN-<key>.json
  workflows/verify-state.js     blind; state verdicts; writes verdicts/pass-k/state/NN-<key>.json
  workflows/hunt.js             free lanes + territory lanes → candidates; reproducers (pipeline)
  workflows/dismissals.js       DISMISSAL-SOUND|UNSAFE|DISMISSAL-WRONG over the reproducer's dismissals
  workflows/audit.js            kind=code|prose|both; `base` REQUIRED; executing lane anchored
  workflows/attack-design.js    four attackers vs any lens list (subject from args)
  workflows/rubric-audit.js, severity-recheck.js   IT's calibration extras, generic
  schema/*.json                 the artefact schemas and vocabularies (D11)
  catalog/hats.toml + hats/*.md the generic hats and their persona files
  catalog/lanes.toml            audit lanes (code/prose), hunt free lanes, check-docs lanes
  catalog/scans.toml            every deterministic scan: id, tier, pattern, surfaces, rationale, fixture
  policy/*.md                   the rubric with marked variation points (D12)
  templates/                    managed-file templates (make.jl block, runtests block, gitignore lines,
                                settings.json hook, CLAUDE.md index block)
  plugin/.claude-plugin/plugin.json ; plugin/skills/<name>/SKILL.md   thin skills (D6)
  .claude-plugin/marketplace.json  source = "./plugin"
  fixture/GBGFixture/           the fixture consumer (D15)
  tests/                        selftests (D15)
  install.sh                    clone → ~/.gbg/instruments/repo, shim → ~/.local/bin/gbg, marketplace add
  CHANGELOG.md                  per tag; MAJOR entries name the recalibration
  docs/CONTRACT.md              §0 and §4 of this proposal, kept current
```

### 2.2 The consumer footprint

```
.gbg/
  instruments.toml          config — owned, validated (§3)
  exemptions.toml           seeded-once-then-owned (doctor exemptions with expiry)
  adjudicated.toml          seeded-once-then-owned (per-finding dismissals, ID-keyed; injected into hats)
  seeds.toml                seeded-once-then-owned (the consumer's seed catalogue; never injected)
  hats/*.md                 owned (domain hat personas; generic hats come from the tool)
  policy/*.md               generated-managed (rendered rubric with deviations applied)
  MANIFEST.json             generated-managed (sha256 of every generated file + tool tag)
  rounds/<date>-<instr>-NN/ tracked-pile (§0); inside: manuscript/, seeded/, scratch/, witnesses/env/ gitignored
CLAUDE.md                   seeded skeleton; ONE managed block (the @.gbg/policy/00-index.md import)
docs/make.jl                owned; must contain the managed line `GBGInstruments.lint_docs(@__DIR__)` (doctor)
docs/Project.toml           owned; [sources] rev line managed by `gbg pin`
docs/prose_shape.csv        owned baseline (one schema fleet-wide)
test/Project.toml           owned; [sources] rev line managed by `gbg pin`
test/runtests.jl            owned; must contain `GBGInstruments.include_regressions(@__DIR__)` (doctor)
test/regressions/           owned (promoted witnesses; header convention from tool docs, no README copy)
test/baselines/*.csv        owned frozen baselines (method_parity, pass_audit ideals, allocation exemptions)
.claude/settings.json       seeded-once; the Stop hook line `gbg gate --open-rounds` is managed
.gitignore                  managed lines block (rounds scratch, witnesses env)
```

Deleted from every consumer after migration: `.claude/commands/**` (all instruments and their
scripts, `MANIFEST.txt`, `manifest.py`), every lint body in `docs/make.jl`, `.claude/doc-review*`,
`.claude/review-rounds/`, `.claude/bug-hunt/`, `.claude/audit-changes/`, `.claude/WORK_QUEUE.md` +
`hooks/queue-guard.sh`, `test/regressions/README.md`, `.claude/README.md`/`INVENTORY.md` (their
content moves to `docs/CONTRACT.md` and `CHANGELOG.md`).

---

## 3. Config schema — `.gbg/instruments.toml`

Strict: unknown key → exit 2. `# req` marks required keys; everything else has the default shown,
materialised by `gbg init`. Machine facts are never here.

```toml
schema = 1                                   # req; the tool's MAJOR this file was written for
pin = "v1.2.0"                               # req; must be a tag; must equal test/ and docs/ [sources] rev

[package]
name = "GBGPeriodicFields"                   # req
description = "…one paragraph…"              # req; the PREAMBLE every hat/lane/verifier receives
branch = "master"                            # req; IT: "main"
modules = ["FiberSections", "Fields", …]     # req; JET target_modules, xlink MODS, lane substrates
deliberate_absences = ["no time", "no particles", "no field×field product in spectral representation"]
julia_project = "."                          # the --project for witnesses and Pkg.test
test_command = "julia --project -e 'using Pkg; Pkg.test()'"

[surfaces]                                   # req table; the ONE copy of the surface lists
rationale_docs = ["docs/ARCHITECTURE.md", "docs/FORMALIZATION.md", "docs/TESTING.md", "docs/PERFORMANCE.md"]
doc_pages = ["docs/src/**/*.md"]
generated_copies = ["docs/src/architecture.md", …]   # excluded from scans
src = ["src/*.jl"]
ext = ["ext/*.jl"]
examples = ["examples/HIST_CPU.jl", "examples/gpu/*/*.jl"]   # SS/IT/CP: []
built_html = "docs/build"
decision_log_heading = "## 13. Decision log"  # history exemption boundary; IT: "## 11. Decision log"
references_heading = "## References"

[docs]
doctest = true
notation.banned = ["\\left", "\\right", "\\partial_[ijk]"]    # regex fragments for lint_notation_variants
notation.prescribed = { indicator = "\\mathbf{1}" }            # IT: indicator = "\\boldsymbol{1}", banned += ["\\mathbf"]
retired_claims = ["squared_wavenumber_field is a builder", …] # phrases with the decision-log exemption
prose_shape = { paragraph_words = 120, admonitions = 3, units = "docstrings+pages" }   # IT: "docstrings"
make_extras = ["git checkout -- docs/Project.toml"]           # IT's post-build step; PF: []

[check_docs]
lanes = ["architecture", "rationale", "src-core", "src-ops", "doc-pages", "examples", "built-html", "family", "cold-reader"]
scans.disabled = [ { id = "arg-bullet-not-bold", reason = "SS rubric requires the bold form (SS CLAUDE.md:363)" } ]
scans.extra = [ { id = "ss-unlateralized-sizer", tier = "hard", pattern = "…", surfaces = ["src"], fixture = ".gbg/fixtures/sizer.jl" } ]
idioms = { allocating_form = "Allocating form of", fields_lead = "The fields are" }
argcov = "triage"                            # IT: "gate"
operational_claims = false                   # IT: true (its check-1 second half)
built_html_public_surface = "test/public_surface.jl"   # PF; others: "names" (use names(Module))

[check_consistency]
profile = "core"                             # core|full|explicit
hats = ["consistency-matrix", "software-architect", "structure-consistency", "latex-typesetter",
        "api-user", "citations-integrity", "style-editor", "cold-reader",
        "spectral-methods-mathematician", "differential-geometer"]
core = ["free-reader-a", "consistency-matrix", "logician", "cold-reader", "spectral-methods-mathematician"]
[[check_consistency.domain_hats]]
key = "spectral-methods-mathematician"; anchor = true; persona_file = ".gbg/hats/spectral.md"; substrate = "full"
[[check_consistency.domain_hats]]
key = "differential-geometer"; anchor = true; persona_file = ".gbg/hats/geometer.md"; substrate = "full"
consolidate.withhold = ["architecture", "formalization", "testing", "performance"]  # design docs kept out of siteonly
latex.source_globs = ["src/*.jl", "examples/*.jl"]
latex.rulebook_sections = ["Math in docstrings", "Math spacing and command support"]
finding_types_extra = ["math", "normalization"]           # IT: ["physics","dimensional"]; SS: ["statistics"]
seed_by_default = false                      # IT: true

[bug_hunt]
partition = "territory"                      # territory|class; free lanes are always added
territories = [ { key = "fields", files = ["src/Fields.jl"], brief = "FFT normalization, Nyquist split, …" }, … ]
free_lanes = 2
oracles = ["adjointness", "Parseval", "div(curl)=0", …]
already_covered_grep = "test/"

[audit_changes]
covered_paths = ["src", "test", "docs"]
executable_claims = { gate = "julia --project -e 'using Pkg; Pkg.test()'", allocation = "test/allocations.jl", traffic = "test/pass_audit.jl", method_set = "test/method_parity.jl" }
guard_symbols = ["_check_field_domain_compatibility", "_check_same_domain", …]
invariants_file = "CLAUDE.md#Core invariants"           # section reference the lanes are handed verbatim

[cost]
default = "economy"                          # economy|full

[rubric]
[[rubric.deviations]]
rule = "in_place_steer"; ruling = "declined"; date = 2026-08-25; reason = "owner-ruled; IT CLAUDE.md:179"
[[rubric.deviations]]
rule = "admonition_titles"; ruling = "bare-note-allowed"; date = 2026-08-25; reason = "…"

[commit]
trailer = "Co-Authored-By: Anthropic Claude <noreply@anthropic.com>"   # versionless, owner-decided 2026-09-04
```

**Deliberately NOT configurable** (constants in the tool; changing any is MAJOR): every vocabulary
and schema; the demotion predicate; the closure predicate and the three closure channels; the
round layout and file names; exit codes; the stop rule (closure = zero open, plateau is advisory
only); the fix phase / verification / adjudication running at session strength; which lanes are
grounding anchors (`executing`, reproducers, adjudicators, dismissal auditors, free hunt lanes);
seeds never entering the adjudicated file or a hat preamble; the tiering of a catalogued `hard`
scan (a consumer may *disable* one with a reason, never demote it to soft); `no truncation` of any
output; the `# generated` header on managed files.

Real PF/SS differences the schema expresses: bold argument bullets (a disabled scan with reason),
estimand-first (a domain hat + `finding_types_extra` + a policy variation point), no `\mathbf`
guard (`notation.banned` shorter), 1.11 floor (nothing to configure — the tool supports it), no
examples/built-HTML surfaces (empty lists), the `master`/`main` branch, the trailer.

---

## 4. Run-time contract, end to end — `/gbg:check-consistency`

The other three instruments differ only in the lane engine and in the artefact kinds banked
(§4.3); the round verbs are shared.

### 4.1 Vocabularies and file formats (all instruments)

- `ROUND.toml`: `round, instrument, tool_version, tool_rev, schema_version, config_sha256,
  seed_catalog_sha256, head, base, roster[], cost, strength, hostname, model_hint, opened, banked,
  findings, seeded, dead_lanes[], passes, closed` (string: `"<date> — <account>"` or
  `"abandoned: <reason>"`), `closed_head`.
- `findings/NN-<lane>.json` (written by the lane agent): `{lane, candidates_considered, checked[],
  no_findings_statement?, findings[{type, domain_type?, severity, confidence, title, locations[],
  contradicts?, description, resolution_hint?}]}`. Zero findings **and** empty `checked` → DEAD.
  `candidates_considered > findings.length` → TRUNCATED (reported, not fatal).
- `findings.json` (CLI): each finding gains `id = "<round>/<NN-lane>#<n>"`, `seeded: bool`,
  `seed_class?`, plus `sha256` of the whole.
- `verdicts/pass-<k>/pass.toml`: `pass, opened, head, range, tool_version, tool_rev, expected{lane:n}`.
- `verdicts/pass-<k>/act/NN-<lane>.json`: `{lane, graded_sha256 (of findings.json), verdicts[{id,
  verdict, question, evidence, class_surfaces[{surface, swept, evidence}]}]}`. `graded_sha256`
  ≠ frozen hash → the file is REJECTED (the grader graded something else). Missing lane file → DEAD.
- `verdicts/pass-<k>/state/NN-<lane>.json`: `{lane, graded_sha256, verdicts[{id, verdict,
  surviving_class?, evidence}]}`.
- `tally.json` (CLI): per finding `{id, act, act_demoted: bool, state, closed_by:
  honored|adjudicated|seeded|null}`, totals, `demoted_by_rule`, `dead_lanes`, `open_ids[]`,
  `plateau: {passes_flat: n}`.
- `.gbg/adjudicated.toml`: `[[entry]] id, title, reason, recorded, overturn_when, evidence`.
- Exit codes as D8.

### 4.2 The sequence

1. **Skill.** `/gbg:check-consistency [--profile core|full] [--strength full] [--seed]`. SKILL.md:
   "Run `gbg check-consistency open <flags>`; invoke Workflow exactly as it prints; then follow
   its next-step line." Nothing else.
2. **`gbg check-consistency open`** (CLI, exit 2 on any precondition):
   validates config; runs `julia --project=docs docs/make.jl` and requires exit 0 (the build is the
   consolidation's input; a failed build is exit 2 with the log path); consolidates
   `docs/build` → `rounds/<r>/manuscript/{full,siteonly}.md` (gitignored); if seeding, plants
   `.gbg/seeds.toml` into `rounds/<r>/seeded/` (gitignored) and writes `ground_truth.json`
   (tracked; skipped classes listed as UNDEFINED); writes `ROUND.toml` (all stamps, the roster
   resolved from profile + config, `opened` from the CLI's clock — the JS cannot call `Date.now()`);
   `git add rounds/<r>/ROUND.toml`; prints:
   `WORKFLOW scriptPath=/home/grigory/.gbg/instruments/v1.2.0/workflows/panel.js args=<json>`.
   The args object: `{round_dir, manuscripts, hats[{key, persona, anchor, substrate, siteonly}],
   preamble, deliberate_absences, adjudicated_path, cost, strength, finding_types, opened}`.
3. **Workflow `panel.js`.** Hats run `parallel`; each is told to `Write` its
   `findings/NN-<key>.json` FIRST, then return the same object (schema-forced). The script returns
   `{written[], dead[], empty[], truncated[]}` and logs "run `gbg round bank <r>`". It computes no
   tally.
4. **`gbg round bank <r>`.** Validates each expected lane file against `schema/finding.json`;
   assigns IDs; runs `recall` against `ground_truth.json` and marks seeded findings; writes
   `findings.json` + its sha256 into `ROUND.toml`; renders `findings.md` per lane and a
   `00-SUMMARY.md` skeleton (a reading aid, never a work list — the fix pass is driven from
   `findings.json`, `CC` §6.2); prints recall per class (UNDEFINED for skipped); exit 1 if any DEAD
   lane (re-run with `gbg check-consistency rerun <r> --lanes …`, which appends to the same round —
   the denominator is not frozen until bank exits 0).
5. **Fix pass** — on the owner's word, at session strength, over `findings.md`, never the summary.
6. **`gbg round pass open <r>`** — creates `verdicts/pass-<k>/`, records `head`, `range`
   (`<opened head>..HEAD`), stamps, `expected` counts from `findings.json`; prints two WORKFLOW
   lines: `verify-act.js` (args: round_dir, pass_dir, range, adjudicated_path, expected, preamble)
   and `verify-state.js` (args: round_dir, pass_dir, manuscripts regenerated by this verb after a
   fresh docs build, adjudicated_path, expected; **no range**). Both scripts forbid their agents to
   open `rounds/*/verdicts/` (`CC` §6.21) and require `graded_sha256`.
7. **`gbg round grade <r>`** — validates both verdict sets; applies `demote.py` (HONORED with
   `class_surfaces == []` → LINE-ONLY, counted in `demoted_by_rule`); applies closure channels:
   `closed_by = honored` if act = HONORED (post-demotion) **and** state ∉ {PRESENT, REGRESSED,
   UNCLEAR}; `adjudicated` if the ID is in `adjudicated.toml` (the CLI refuses to add an ID whose
   finding is `seeded`); `seeded` if marked. Writes `tally.json`/`tally.md`; prints the pass series
   and the plateau signal; exit 1 while `open_ids` is non-empty. **Loop 5–7 over the same
   `findings.json`**; the loop terminates because the set is finite and closure is per finding.
8. **`gbg round close <r>`** — requires: latest pass `open_ids == []`, no DEAD lane, every
   `expected` lane graded in that pass, `tool_rev` unchanged since open (else exit 2 → `pass open
   --regrade`), no uncommitted change under `rounds/<r>/`; writes `closed`, `closed_head`; the
   session commits. **`gbg round abandon <r> --reason …`** writes `CLOSED.md` listing every open ID
   and `closed = "abandoned: …"` — the plateau signal is the usual reason, and it is a decision the
   diff shows, never an auto-close.
9. **`gbg gate`** — run by `lint_docs` (instrument = docs rounds) and by the Stop hook
   (`--open-rounds`, files only, milliseconds): any `ROUND.toml` without `closed` → exit 1 naming
   it; a round directory without `ROUND.toml` → exit 2; a closed round whose recomputed tally
   differs from the stored one → exit 1 (tamper/version drift); `.gbg/rounds/` absent in a repo whose
   config enables any instrument → exit 2 (the missing case fails).

### 4.3 Deltas for the other three

- **check-docs.** Step 2 additionally runs `gbg check-docs guards` (tiered scans; `hard` hits are
  banked as lane `00-guards` findings so they enter the same closure loop), `argcov`,
  `doi_crosscheck` (IT's title+decoded-DOI check plus PF's any-form breadth and the unused-reference
  info), `field_docs`, `link_uniformity`, `sentence_openers` (the computed script), IT's
  `abutting_spans`, `dupref`, `signature_fidelity`; the fan-out is `lanes.js` with the surfaces from
  config. Banking and closure are identical — closing the survey's finding that IT's check-docs
  banks nothing (`CD` §1 IT).
- **bug-hunt.** `hunt.js` writes `candidates/NN-<lane>.json` and `witnesses/<lane>-<n>.jl`
  (round-prefixed by directory, so no prefix in the name); reproducers write `reproductions/<id>.json`.
  `gbg bug-hunt bank` runs `julia/witnesses.jl <round>/witnesses --expect fail` and REJECTS any
  `REPRODUCED` whose witness does not fail mechanically (`BH` §5.4). The ledger is `tally.json`
  with dispositions `fixed|refused|escalated` per confirmed finding; `gbg round close` for a hunt
  requires `witnesses --expect pass` green, every `fixed` witness promoted (a file in
  `test/regressions/` whose header names the ID), `Pkg.test()` green, `dismissals.js` run with
  `reopened == []`, and an **audit-changes round over the hunt's range closed** (the fix's damage is
  invisible to the witness gate, `BH` §5.10). Escalated witnesses stay under
  `rounds/<r>/witnesses/escalated/` — tracked, never promoted, never skipped. `closure.py`'s
  follow-up-hunt rule is **not shipped** (D-resolution below).
- **audit-changes.** `audit.js` with `base` required, `kind` from the diff's paths (code/prose/both),
  concerns to `concerns/NN-<lane>.json` with `checked[]`, `candidates_found`, `previously_worked`;
  `gbg audit-changes bank` writes `audit.json`; dispositions are recorded with `gbg round disposition
  <id> fixed|refused|escalated --reason`; `gbg round close` = PF's gate (every blocker/major and
  every `previously_worked` concern answered; refusal ≥ 24 chars; no dead lane; `git diff
  <head>..HEAD -- covered` empty, UNCHECKABLE ≠ clean) plus IT's `verdict_all_clean` requirement
  for an empty audit and its capped-lane report.

### 4.4 The divergences, resolved

| Divergence | Decision | Evidence |
|---|---|---|
| Demotion predicate | **Emptiness of a structured array** (`class_surfaces == []` → LINE-ONLY), applied in `demote.py` only; a coverage-gap finding carries `class_surfaces = [{surface: "none — single site", swept: true, evidence: "…"}]`, which is non-empty by construction. Content is never parsed. | `CC` §5.1: PF's own file records IT's shape as winning; 10 of 13 and 6 of 6 demotions spurious under content rules; the residual (a wrong-but-substantive answer) is caught by the state verifier, which is why two verifiers exist. |
| Staleness | **Neither mtime nor self-stamp.** A pass is a CLI-created directory recording `head`/`range`; verdict files carry `graded_sha256` of the frozen findings, checked for equality; the "current" pass is the highest number. | `CC` §5.2: `RANGE:` was ignored by all eight lanes; mtime misfired once (6-hour bucket, `PF doc-review-checkdocs/CLOSED.md`) and is meaningless on a fresh clone, where git sets every mtime to checkout time — so the mtime gate passes vacuously exactly where R2 needs it. A hash mismatch is a **failing** missing case. |
| Verdict sets | The union vocabularies of D11, fixed. `UNCLEAR` retained as non-passing (an honest "cannot tell" must not be forced into PRESENT and hidden). | `CC` §5.3; `BH` §5.1. |
| Per-finding vs wholesale | Per-finding by ID (three channels); wholesale only as `abandon` with an enumerated ID list. | `CC` §5.5; `PF doc-review/CLOSED.md` L23-28 (untitled headings). |
| Tracked vs untracked piles | Tracked, all instruments; scratch subdirectories ignored. | `BH` §5.15; `IT INVENTORY.md` constraint 2; `IT .claude/README.md` is already wrong about what IT tracks (`BL` §2). |
| `closure.py`'s follow-up-hunt rule | **Deleted.** A hunt runs once; the loop is the verifier over the finite confirmed set; `fixed + refused + escalated == confirmed` is the terminator; a new hunt is a new round. | `BH` §1.2: measured 20, 9, 17, 21, 17 — "a rule that makes finished permanently false is a bad rule"; the retraction is on disk beside the rule it retracts, which "frozen" preserved. |
| Seeds vs closure | Seeds are closed by `ground_truth.json` in the round (tracked, read by `grade`, never injected); the adjudicated file refuses seeded IDs; calibration by default on the fixture consumer, on a real consumer only with `--seed`, and the recall figure is stamped into `ROUND.toml`. | `CC` §6.4; PF CLAUDE.md "the contradiction is unresolved"; `TP` §4b/§6b. The catalogue was always on disk in the repo — the leak was the preamble, which is the one place the seeds now cannot reach. |
| Roster | Emitted by the CLI into `ROUND.toml.roster`, read by both verifiers via args; `expected` counts from `findings.json`. No `hats.json`, no census agent, no hardcoded arrays. | `CC` §5.6, §6.13; `CC` §2 (PF `SITEONLY_HATS` inconsistent with its own panel). |
| `witnesses.jl` | One runner: `<dir> --expect fail\|pass`, quoted paths, `Base.julia_cmd()`, BROKEN → non-zero, subset filter, empty → 2. | `BH` §4.3. |
| Hunt partition | Config (`territory\|class`), free lanes always present and anchored. Default `territory` + 2 free. | `BH` §4.1: IT's own measurement favours free readers; neither tree has both. |
| `audit.js` | `base` required, `test/` in the diff, `kind` switch, `checked[]` + `candidates_found` + `previously_worked` all required; `strength` honoured. | `BH` §4.4, §5.11. |
| `gate.py` staleness | PF's `git diff <audited>..HEAD -- covered` with UNCHECKABLE distinct from clean. | `BH` §4.5. |
| `dismissals` completeness | `complete = dead == 0 && reopened == []`. | `BH` §4.2. |
| `recall` unverifiable seeds | Kept in the denominator and named (PF). | `CC` §5.6, §6.16. |
| `argcov` exit policy | Config (`triage\|gate`); exemption counting + Unicode identifiers + `arg = default` form are the shared engine. | `CD` §4. |
| Prose-shape ratchet | IT's always-binding caps + PF's page units; one CSV schema; missing CSV is an error (never auto-written). | `CD` §4, `BL` §1. |
| `\mathbf` / bold bullets / steer sentence | Config + declared deviations (D12); the tool ships no opinion on them. | `CD` §7.18. |

---

## 5. Migration

Each step ends with `gbg doctor` green for the checks the step introduces; no step deletes anything
its predecessor did not replace; every consumer commit is on its declared branch and pushed.

**Step 0 — the tool.** Extract into `GBGInstruments` from PF's tree at `faa164a1`+HEAD and IT's at
`fdeba74`+HEAD, resolving §4.4 as written; build `fixture/`, `tests/`, `CHANGELOG.md`; tag `v1.0.0`
only when `gbg selftest` is green and both PF's and IT's last closed rounds re-grade to the same
tallies from their banked files (converted by a one-off `gbg round import`) — the acceptance test
that the engine measures what the old copies measured.

**Step 1 — PF (canary).** (a) `install.sh` on Aiporetne; `gbg init` + `gbg scaffold` → `.gbg/`
from the values in `CD` §3(a)/`BH` §3(a); (b) `gbg pin set v1.0.0`; `make.jl` reduced to
`makedocs` + `lint_docs`; `runtests.jl` gains `include_regressions` + `test_gates`; run
`Pkg.test()` and the docs build; (c) `gbg round import` the two tracked check-docs rounds and the
adjudicated file (title → ID map recorded); (d) delete `.claude/commands/**`, the make.jl lint
bodies, `WORK_QUEUE.md` + hook (the Stop hook becomes `gbg gate --open-rounds`),
`test/regressions/README.md`; (e) CLAUDE.md: replace the rubric/style/instrument sections with the
managed import block; the package-specific 2000 lines stay; (f) doctor green; commit.
Collapsed as artefacts: the four surface-list copies, `guards.sh`'s nine-file awk, `RANGE:` stamp,
the "sequential" headers, the `manifest.py`/`MANIFEST.txt` pair, PF's `PARSED TO ZERO`
inconsistency, the unquoted `cd ${REPO}`. Kept as deviations: none — PF is the reference.

**Step 2 — IT.** As step 1 on Enteropia. Additionally: import `review-rounds/` markers and
`bug-hunt/rounds.json` + `OPEN-DEFECTS.md` into rounds (escalated witnesses moved under their
round); `latest.json` → an audit round; delete `closure.py`, `finished.py` (its nine checks are
`gbg round close` for a hunt), the `rubric_*` one-off constants (the engine stays, generic),
`INVENTORY.md`, the stale `.claude/README.md`. Kept as declared deviations: `main` branch,
`\boldsymbol` and the `\mathbf` ban (now `notation.*`), the declined steer sentence, bare
`!!! note`, `argcov = "gate"`, `operational_claims = true`, `doctest = false`, the
`git checkout -- docs/Project.toml` post-build step, `seed_by_default = true`, 27-hat catalogue with
`profile = "core"`. Collapsed: the `main`-vs-`master` *trailer text* (`Claude Opus 4.8` →
versionless, owner-decided), the untracked-pile policy, `witnesses.jl`'s `..` path, the
"605 lines" preamble, `meta.name: 'audit-edits'`, the `.md` hat table drifted from `panel.js`.

**Step 3 — SS.** Pure collapse of the July fork: scaffold; `lint_inline_math` (June ancestor)
replaced; the one untracked round imported; the estimand-first rubric becomes a domain hat +
`finding_types_extra = ["statistics"]` + a policy variation point; the bold-bullet form a disabled
scan with reason; the `\!` before `\left(` sentence (contradicting its own ban) fixed in the
rendered policy, not preserved; `julia = "1.11"` unchanged (the tool supports it; the Aiporetne
1.11 lane is a doctor WARNING until juliaup carries it). The `inspiration/` citation in SS's rubric
is dropped (an inaccessible source).

**Step 4 — CP.** `gbg init && gbg scaffold`; `Aqua persistent_tasks = false` becomes an exemption
with a reason or is dropped; "knobs" ×5 becomes five check-docs findings in its first round. This
step is R10's proof: no deletions, only config.

**Step 5 — fleet.** `~/.gbg/fleet.toml` on both hosts; `gbg doctor --fleet` green; the
"Planned directions — shared instrument package" block in PF's CLAUDE.md and IT's `INVENTORY.md`
become one paragraph pointing at `docs/CONTRACT.md`.

---

## 6. How the package tests itself, and what "provably best" means

### 6.1 Self-test (D15, restated as arms)

For every gate G in {config validation, bank, grade, close, abandon, gate, doctor, scaffold-MODIFIED,
witnesses runner, audit staleness, recall, demotion}: an arm where the fixture is clean and G passes;
an arm per failure mode where a planted defect makes G fail with the documented exit code; and an
**absence arm** where G's input is missing and G exits 2. A scan in `catalog/scans.toml` without a
fixture pair fails the tool's test. `gbg selftest` writes `SELFTEST.<tag>.ok` into the worktree, and
`doctor` reads it — a pin whose selftest never ran on this machine is a doctor failure.

### 6.2 Requirement → decision entailments

- R1 ⇒ one repo (D1), pins visible in each consumer (D3/D4), doctor as the definition of "declared"
  (D14), constants outside config (D5/D11).
- R2 ⇒ stamps in `ROUND.toml`/`pass.toml` (D16), tracked rounds (D10), rendered policy committed in
  the consumer (D12), `CHANGELOG` per tag; "what changed between rounds" = `git diff` of two tags
  plus the two rounds' stamps.
- R3 ⇒ the exit-code contract (D8), DEAD lanes (P1), `gate` exit 2 on absence, `graded_sha256`
  rejection, adjudication refusing seeded IDs.
- R4 ⇒ version check in every round verb, `--regrade` supersession (D16).
- R5 ⇒ D15 and the scan-without-fixture refusal.
- R6 ⇒ the footprint table (§2.2) — no engine text in a consumer; skills thin (D6).
- R7 ⇒ one tag over JS+py+jl+md (D1); JS receives only args (D5/D7).
- R8 ⇒ `install.sh` + shim + worktrees (D2); no tokens in the tool (SSH URLs; `GBG_DEPS_TOKEN`
  stays a CI secret).
- R9 ⇒ per-consumer pin + fleet window (D4); migration steps each doctor-verified (§5).
- R10 ⇒ CP is the proof (§5 step 4); an instrument = `python/gbg/instruments/<x>.py` +
  `workflows/<x>.js` + `schema/<x>-*.json` + `plugin/skills/<x>` + `tests/test_<x>.py` — the doctor
  refuses a tag where one of the five is missing for a registered instrument.
- R11 ⇒ D11.
- R12 ⇒ D18.

### 6.3 What "provably best" honestly means, and the residual judgment calls

The proposal is *entailed* wherever a requirement plus a measured failure fixes the choice: the
demotion predicate, tracked piles, the version-mismatch refusal, per-finding closure, the
follow-up-hunt deletion, the CLI-computed denominator, the single vocabulary. Those are not
preferences; the alternatives are on record as having failed.

Residual judgment calls, named so they can be overruled:

1. **Per-machine clone outside Dropbox** (D2) versus inside it — a topology preference; both satisfy
   R8. Overrule cost: two live clones of one `.git` in Dropbox.
2. **Plugin skills versus generated stubs** (D6) — depends on one unverified platform fact (a
   local-path marketplace). The fallback is designed in.
3. **`UNCLEAR` kept** in the state vocabulary — a choice to make honest uncertainty visible over a
   strict default-PRESENT; either is fail-closed.
4. **Stop hook running `gbg gate --open-rounds`** — the only place the tool touches a session's
   flow; the owner may prefer the docs build as the sole gate.
5. **Territory as the default hunt partition** — IT's measurement favours free readers, not
   territories; the default could equally be `class`. Free lanes are non-negotiable; the rest is
   config.
6. **Hard-coding the anchor lanes** (D18) — a consumer cannot economise the `executing` lane even
   on a trivial diff. Deliberate; the grounding is the point.
7. **`schema.finding_types_extra` as the only extension point** — a consumer wanting a new
   *field* must change the tool (MAJOR). That friction is intentional and could be judged too much.
8. **Seeding real consumers only on request** — IT seeded every round; the fixture now calibrates
   by default. IT can set `seed_by_default = true`, so this is a default, not a constraint.

---

## 7. Name

**`GBGInstruments`.** The corpus of all four repos already reasons in the vocabulary of measurement —
instrument, ruler, calibration, frozen, recall — so the name binds the metaphor the owner's own
documents use, and the package's central guarantee (a stamped, frozen, grader-separated
measurement) is what "instrument" means in metrology. `GBGCodingTools` is not wrong; it merely
promises tools, and this package promises numbers one can trust.
