# Round-1 proposal — the platform/product lens

Lens: software product lines, configuration-over-code, the pre-commit / toolchain-manager
distribution model, Julia `Pkg` mechanics, Claude Code plugin/skill/import mechanics. Optimised for
**uniformity by construction**, **one place for every behaviour**, and a **pinning story that
survives the two-machine Dropbox+GitHub fleet and a fresh clone**.

Evidence citations are `survey-<name>.md:§` (section) or `file:line` inside the surveys; requirement
ids R1–R12 are from `00-requirements-draft.md`. `PF`/`IT`/`SS`/`CP` as in the brief. The package is
called `GBGCodingTools` throughout (D19 argues why); its CLI is `gbg`; its Julia module is
`GBGCodingTools`.

---

## 0. The one design sentence

**A consumer holds data; the platform holds behaviour; the only thing that connects them is a pin.**
Every consumer carries one config file, one exemptions ledger, one pin, its tracked rounds, and a
handful of hash-stamped stubs that are regenerated rather than edited. Every engine, protocol,
persona catalogue, verdict vocabulary, gate, lint, harness and policy text lives once, in the
platform, at a version. The four consumers cannot drift because the lines that drifted are no
longer in them (theory §1c, §3c). What differs between consumers is either a value in the config
schema or an entry in the exemptions ledger with a reason — nothing else is admissible, and
`gbg doctor` says so.

---

## 1. Decisions D1–D19

### D1 — Unit of distribution: ONE repository, ONE version, three consumption surfaces

**(a) Choice.** One git repository, `GBGCodingTools.jl` (private GitHub, dev checkout in Dropbox
beside the other four), that is simultaneously (i) a Julia package (root `Project.toml`, module
`GBGCodingTools`), (ii) a Python CLI (`gbg/`, stdlib-only, Python ≥ 3.11 for `tomllib`), and (iii)
the instrument corpus (protocol `.md`s, Workflow `.js` scripts, persona/scan catalogues, policy
prose, schemas, templates, fixture consumer). One `version` field, one tag per release, one
CHANGELOG.

**(b) Forced by.** R1 ("SAME instrument code at the SAME version"), R4 (a round records *one*
version), R7 (polyglot pieces "all versioned together"), R2 (one answer to "which version measured
this round"). The behavioural divergences that have to be *resolved* rather than parameterised
(`survey-check-consistency.md:§4(b)`, `survey-bughunt-auditchanges.md:§5.1`) all cross the
language boundary — `verify-fixes.js` (JS) and `lint_review_closure` (Julia) were declared "twins"
and desynced for a day (`survey-checkdocs.md:§7.8`); the hunt verdict set is keyed off by
`dismissals.js`, `closure.py`, `finished.py` (JS+Python). Splitting the repo by language would
re-create exactly those twins across repos.

**(c) Alternatives.** *Julia package + separate Claude plugin repo*: two versions to keep in step,
and a plugin cannot ship Workflow scripts at all (`facts-claude-code-platform.md` §1, "Workflows in
Plugins: NOT directly supported"), so the split buys nothing and costs a second pin. *Instruments
vendored per consumer with a manifest*: this is the status quo plus a manifest — the survey
measured the drift it produces (1.5–2× line counts on same-named files,
`survey-buildlints-hooks-policy.md:§5`). *Monorepo of all five packages*: would give the one-version
rule for free (theory §2d) but is a topology change to four working repos with their own docs
deploys; out of scope and not needed to get the rule.

### D2 — Delivery: Pkg fetches the pinned copy; Dropbox holds only the dev checkout; a per-machine shim

**(a) Choice.** Three roles, three locations:
1. **Dev checkout** — `~/Dropbox/Research and Teach/AI Helpers/GBGCodingTools/` (a git clone,
   synced by Dropbox exactly like the four packages; pushed to GitHub). This is where the owner
   edits and releases the platform. Consumers never read it.
2. **Pinned copy** — fetched by Julia's `Pkg` into `~/.julia/packages/GBGCodingTools/<slug>/` from
   the consumer's `test/Project.toml` `[sources]` entry at an immutable tag (D3). Every consumer-side
   invocation — Julia lints, test harness, the Python CLI, the Workflow scripts, the skill protocol
   text — runs from this copy. It exists per machine, per pinned version, and is immutable by Pkg
   convention.
3. **Per-machine shim** — `~/.local/bin/gbg` (installed once by `bin/install.sh` from the dev
   checkout, ~25 lines of POSIX sh, versionless). It finds the consumer root by walking up to
   `.gbg/config.toml`, asks Julia where the pinned copy is
   (`julia --startup-file=no --project=test -e 'print(Base.locate_package(Base.identify_package("GBGCodingTools")))'`,
   ≈0.4 s), and `exec`s `python3 <pinned>/gbg/__main__.py "$@"`. Outside any consumer it falls back
   to the dev checkout (for `gbg fleet`, `gbg selftest`, `gbg release`, `gbg new`).

**Fresh clone story.** `git clone <consumer>` → `julia --project=test -e 'using Pkg; Pkg.instantiate()'`
(fetches the pinned platform over the same GitHub credentials the fleet already uses for its
private sibling deps — CP `Project.toml` `[sources] url=`, IT's tracked Manifest,
`survey-buildlints-hooks-policy.md:§7`) → `gbg doctor` green. No Dropbox needed for a consumer.
CI: the docs and test workflows already authenticate private deps via `GBG_DEPS_TOKEN`
(`CP/.github/workflows/CI.yml`); the platform is one more such dep, nothing new.

**What breaks if the Dropbox tree differs between hosts.** Nothing in the consumer path: the pin is
a URL+tag. Only the dev-side `gbg fleet` (which locates the four consumers through
`fleet.toml`'s relative paths from the dev checkout) reports the missing consumers by path and exits
2; `autoMemoryDirectory` already carries the same assumption today.

**(b) Forced by.** R8 (reproducible per-machine install, no secrets), R6 (nothing duplicated in the
consumer), the "one-version" rule (theory §2d), and the toolchain-manager principle that a shim is
versionless and the *directory* selects the version (theory §2b). The Pkg route is the only one of
the candidates that both survives a fresh clone and pins immutably.

**(c) Alternatives.** *Git clone in Dropbox only, consumers reading it by absolute path*: synced by
construction, but then one checkout serves every consumer, so a per-consumer pin cannot be satisfied
during a staged upgrade, `.git` inside Dropbox is a hazard already tolerated only because the
alternative was worse, and a fresh clone outside Dropbox has no tool at all. Kept for the *dev*
role only. *Claude plugin marketplace install*: no per-project pinning ("only session-level",
facts §2), no auto-install on clone, cannot ship Workflow scripts, and the plugin version would be a
second version beside the Julia one. Rejected as a distribution channel; the plugin *mechanics* the
design does want (namespaced skills, `${CLAUDE_PLUGIN_ROOT}`) are reproduced by generated stubs
(D6). *Julia private registry (LocalRegistry.jl)*: strictly better than `[sources]` once there are
several releases and it would also turn the PF→IT and SS→CP dependencies into normal versioned ones
(theory §8a). Deferred, not rejected: it is a pure upgrade of D3's pin syntax with no other change,
and it costs a registry repo plus one `register` per release. Recorded as the step after migration.
*Per-machine `git clone` outside Dropbox*: needs a per-machine path convention, a per-machine
`git pull` discipline, and gives no pin — the pre-commit model's explicit warning (theory §2a).

### D3 — Binding from a consumer: `[sources]` URL + immutable tag in the three sub-environments, rendered from one pin

**(a) Choice.** The consumer's `.gbg/config.toml` carries `[tool] version = "1.4.0"`. `gbg sync`
renders that into a managed entry in each of `test/Project.toml`, `docs/Project.toml`, and
(where present) `benchmark/Project.toml`:

```toml
[sources]
GBGCodingTools = {url = "https://github.com/GrigorySarnitsky/GBGCodingTools.jl", rev = "v1.4.0"}
[compat]
GBGCodingTools = "=1.4.0"
```

Pkg's `[sources]` is honoured only when that project is the active environment, which is exactly the
three cases (`Pkg` toml docs, theory §8b). The platform is **never** a `[deps]` entry of the package
proper (theory §8c). `gbg doctor` checks the three entries agree with the pin and with the resolved
package version (`Manifest.toml` `git-tree-sha1` + the package's own `Project.toml` version).

**(b) Forced by.** R8 (survives a clone), R1/R4 (an immutable ref; "pins are immutable refs, never
branches", theory §2a), R2 (the pin is a line in a committed file, so `git log -p test/Project.toml`
answers "when did this repo move instrument version"). The `rev` form is the Julia spelling of
pre-commit's `rev`.

**(c) Alternatives.** *`~` symlink / env var / plugin root*: machine state, invisible to git, no pin.
*`[sources] path = "../../../AI Helpers/GBGCodingTools"`*: works on the fleet (identical Dropbox
layout — the convention every `inspiration/` clone already relies on) and is Julia-free, but it binds
to the *dev* checkout (whatever is checked out is the version), so the pin is not a pin, and it breaks
CI and a clone outside Dropbox. *Submodule*: two-step clone, detached-HEAD footguns, and Dropbox does
not carry `.git` state reliably (theory §2c). *Subtree/vendored copy*: hides divergence — the disease
itself. *Julia 1.12 workspaces* (one manifest for `test/`, `docs/`, `benchmark/`): would collapse the
three entries to one; semantics are new and untested in the fleet, so it is noted as a later
simplification, not adopted now.

### D4 — Pinning: fleet-wide ONE version is the rule; the per-consumer pin is the mechanism that makes the rule checkable

**(a) Choice.** The rule (R1) is that all four consumers pin the same `MAJOR.MINOR.PATCH`. The
mechanism is a per-consumer pin (D3), because a rule with no per-repo artefact cannot be checked
from a clone. Divergence is detected at three points: `gbg doctor` in a consumer (pin ≠ resolved
version, or the three `Project.toml` entries disagree, or the manifest has the platform `dev`'d —
theory §8d); `gbg fleet` from the dev checkout (a table of the four pins; any two differing is a
finding, exit 1); and the platform's own CI running the four consumer contracts (D15) against HEAD.
An upgrade is a **sweep**: `gbg bump 1.5.0` in the canary consumer (PF), its full gate, then the
other three the same day. A staged state is visible in `gbg fleet` and tolerated only inside one
sweep; `gbg bump` refuses (exit 2) while the consumer has an open round (D16).

**(b) Forced by.** R1, R2, R4, R11 ("measurements are comparable" — only at one version, theory
§5e). The survey's own note: `manifest.py` was kept "demoted rather than retired" precisely because
"a shared package can be PINNED AT TWO VERSIONS in two consumers" (`IT/INVENTORY.md` "What
manifest.py is for"); `gbg fleet` is that check made structural.

**(c) Alternatives.** *Per-consumer pins with no fleet rule*: what pre-commit users do at scale, and
it is where "which version measured this?" stops having one answer across consumers — violates R11.
*Fleet-wide version with no per-consumer pin (read the version from the Dropbox checkout)*: not
checkable on a clone; see D2.

### D5 — Config: one TOML file, `.gbg/config.toml`, schema-validated, no layering; Workflow args are rendered from it by `gbg args`

**(a) Choice.** Location `.gbg/config.toml` (not `.claude/`): the file is read by Julia (`make.jl`,
`runtests.jl`), Python (`gbg`) and Claude alike; `.claude/` is Claude Code's discovery namespace and
holding piles there pollutes skill/command discovery and the settings merge. `.gbg/` holds
consumer *state* (config, exemptions, rounds); `.claude/` holds only *generated Claude stubs*.
Format TOML (house format; `tomllib` in Python 3.11+; `TOML.jl` stdlib). Validation: the platform
owns the schema as a strict Julia keyword struct **and** an equivalent Python dataclass loader —
no, one place: the schema is `schema/config.schema.json` (JSON Schema, closed `additionalProperties:
false`, `required` explicit, enums closed) and both languages validate against it with a tiny
stdlib validator (the subset used: types, required, enum, additionalProperties, pattern). A missing
required key, an unknown key, or an unknown enum member is exit 2. **No layering**: no
`settings.local`, no env overrides, no defaults hidden in code — `gbg init` materialises every
default into the file so it reads complete on its own; machine facts (`hostname`, GPU vendor,
`Threads.nthreads()`) are read from the machine at run time and printed by
`gbg doctor --effective`. Config reaches Workflow scripts **only** as `args`: `gbg args <instrument>
[--strength full] [--hats a,b]` prints one JSON object (config ∪ catalogue ∪ round paths ∪ resolved
personas); the skill stub injects it verbatim (D6). Nothing in a Workflow script names a package.

**(b) Forced by.** R3 (no config → fail), R11 (one shared schema), R2 (the effective configuration is
one committed file), R7 (Workflow scripts are "config only via `args`"). The layering trap is theory
§7b; the survey found config data in 4 copies of one doc-surface list inside PF alone
(`survey-checkdocs.md:§3`, "fourth copy of the surface list").

**(c) Alternatives.** *JSON*: no comments, and the exemptions ledger needs prose reasons. *YAML*: not
in either stdlib. *`.claude/gbg.toml`*: see location argument. *Layered defaults < package < local*:
rejected on transparency (theory §7b, "every 'why did this threshold apply' becomes archaeology").
*Config in `Project.toml` `[gbg]` table*: Pkg rewrites `Project.toml` on `add`, and Aqua's
`project_toml_formatting` would flag it.

### D6 — Skills: generated per-consumer `.claude/skills/<name>/SKILL.md` stubs (≤ 15 lines each), never plugin skills; the stub finds the tool root through `gbg root`

**(a) Choice.** `gbg sync` renders one stub per enabled instrument, e.g.
`.claude/skills/check-consistency/SKILL.md`:

```markdown
---
name: check-consistency
description: The fresh-eyed multi-hat RENDERED-docs panel (GBGCodingTools v1.4.0).
disable-model-invocation: true
---
<!-- gbg-managed v1.4.0 sha256:3f9c… — DO NOT EDIT; run `gbg sync` -->
Platform root for this repo (pinned copy): !`gbg root`
Rendered args for this instrument:
```!
gbg args check-consistency $ARGUMENTS
```
Read `$(gbg root)/instruments/check-consistency/PROTOCOL.md` and follow it exactly, passing the
JSON above verbatim as the Workflow `args`. Config: `.gbg/config.toml`; rounds: `.gbg/rounds/`.
```

Dynamic-context injection (`` !`cmd` ``) runs once at skill load (facts §3), so the protocol receives
the pinned root and the rendered args without the model typing either. Skill names stay
un-namespaced (`/check-consistency`), preserving every reference in the four `CLAUDE.md` corpora.
Also generated: `.claude/settings.json` (managed) carrying the hooks block for the enabled hooks,
each command spelled `gbg hook <name>` so the shim resolves the pinned root (hook command paths are
static strings, facts §5).

**(b) Forced by.** Plugins cannot pin per project or auto-install on clone (facts §2 summary table)
and cannot ship Workflow scripts; R6 wants the consumer footprint minimal; R2 wants the version
visible — the stub header carries it. The stub is a *pointer*, so the protocol text has one home
(theory §3c: "prefer thin stubs … so nearly nothing per repo needs merging").

**(c) Alternatives.** *Plugin skills `/gbg:check-docs`*: rejected above; additionally every
`CLAUDE.md` cross-reference to `/check-docs` would need rewriting in four repos. *Both plugin and
stubs*: two mechanisms for one thing. *Rendered protocol text in the stub*: reintroduces the
"readable source of truth" copy that rots (`survey-checkdocs.md:§7.20`). *`.claude/commands/*.md`*:
legacy flat form; skills are the current standard and support the frontmatter used here.

### D7 — Workflow scripts: one generic engine per instrument in the platform, invoked by absolute path from the pinned copy; catalogues are data

**(a) Choice.** `instruments/<name>/workflow/*.js` live in the platform only. The protocol invokes
`Workflow({scriptPath: "<pinned-root>/instruments/check-consistency/workflow/panel.js", args})` —
the Workflow tool accepts an absolute path outside the repo (it persists its own scripts under the
session directory and re-runs them by path). No `.js` is ever copied into a consumer. All package
coupling moves into `args`: `package.{name, description, deliberate_absences, terms}`, `paths`,
`hats[]` (resolved persona text), `lanes[]`, `models`, `pile`, `adjudicated`, `strength`. The hat and
lane catalogues are **data** in `catalog/hats/*.toml` (generic hats with `{package.description}`-style
placeholders) and `catalog/lanes/*.toml`; a consumer's own domain hats (its anchors) are TOML files
under `.gbg/hats/`, validated by the same schema, referenced by key from `config.toml`. Verdict
vocabularies, demotion predicates, `complete` logic, dead/empty/truncated distinctions are engine
constants.

**(b) Forced by.** R7, R10 (adding an instrument = one directory), R11. The surveys classify the
coupling as overwhelmingly (a) data — "almost all inside its 27 `persona:` strings plus one
package-description paragraph" (`IT/INVENTORY.md`, `survey-check-consistency.md:§4`), and the (b)
divergences are engine decisions this document resolves once (§5 below).

**(c) Alternatives.** *Per-consumer scripts generated from templates*: needs a copy per consumer
(footprint), and a rendered script invites edits — the origin of the drift. *Personas as code
(JS constants)*: the platform would need a release to add a domain hat; a consumer must be able to
add its anchor persona in config (R10, R12).

### D8 — Deterministic helpers: one `gbg` CLI in Python; Julia only where Julia reflection or an in-process testset is required; a fixed exit-code contract

**(a) Choice.** Language rule: **Python** (3.11+, stdlib only) for everything that reads text, piles,
git, HTML and config — doctor, sync, args, rounds, gates, coverage, recall, seeding, consolidation,
sentence openers, field docs, link uniformity, DOI cross-check, manifests, fleet; **Julia** for what
must run inside a Julia process or needs reflection — the docs lints called from `make.jl`, the test
harnesses, `argcov`/`signature_fidelity`/`xlink` (method tables, `pathof`), the witness runner
(spawns `julia`); **sh** only for the shim and hook entry points. Entry: `gbg <noun> <verb>`:

```
gbg doctor [--effective] [--fleet]      gbg sync            gbg init | gbg new <Pkg>
gbg args <instrument> [opts]            gbg root            gbg bump <ver> [--abandon-open-rounds]
gbg round open|close|list <instrument>  gbg gate [<instrument>|--all]
gbg scan docs [--hard-only]             gbg verify <round>  gbg coverage <round>
gbg seed <round> | gbg recall <round>   gbg witnesses fail|pass <round> [name…]
gbg hook <name>                         gbg selftest        gbg fleet | gbg release <ver>
```

Exit codes, everywhere: **0** clean; **1** a hard finding; **2** cannot check — bad config, missing
input, dead lane, UNCHECKABLE staleness (never "nothing changed"). Triage scans print and exit 0 but
exit 2 when they scanned nothing. Hard vs triage is a property of each scan in
`catalog/scans.toml`, not consumer-configurable; a consumer silences a scan only through an
exemption entry (D14). `make.jl` reaches Python gates through `GBGCodingTools.run_gate(...)`, which
executes `python3 <pkgdir>/gbg …` and `error()`s on non-zero — one implementation, reached from the
build. (`python3` is on the CI runners.)

**(b) Forced by.** "One place for every behaviour" (the closure gate must not exist twice — the
PF/IT pair is the measured failure, `survey-buildlints-hooks-policy.md:§1` "same name, different
mechanism"); R3 (the exit contract *is* fail-closed: 2 for the missing case); the survey's lessons
1–3 (`survey-checkdocs.md:§7`: never truncate, tiers, dead-lane detection). Python is chosen for the
orchestration half because every consumer host has it, it starts in 30 ms (a Julia CLI would cost
1–2 s per `gbg args` inside a skill preamble), and the existing zero-coupling scripts are already
Python (`gate.py`, `coverage.py`, `recall.py`, `manifest.py`).

**(c) Alternatives.** *All-Julia*: one language, but a 1–2 s startup on every skill-load injection
and every hook, and the Python corpus is the mature half. *Loose scripts (status quo)*: the
`MANIFEST.txt` that lists 3 of 6 is the measurement (`survey-checkdocs.md:§4`). *Shell for scans
(`guards.sh`)*: its self-check idea is kept (every scan file must be registered in
`catalog/scans.toml`, checked by `gbg selftest`), the bash body is not — its wide-signature `awk`
hardcoded nine filenames (`survey-checkdocs.md:§3`).

### D9 — Julia side: `GBGCodingTools` with submodules `DocLints`, `TestHarness`, `Witnesses`, `Config`; consumed from `test/`, `docs/`, `benchmark/` envs; `julia = "1.11"`

**(a) Choice.**
- `GBGCodingTools.DocLints` — every build lint as an exported function taking the surfaces from the
  config: `inline_math`, `notation_variants`, `swallowed_escapes`, `retired_claims`,
  `api_page_structure`, `prose_shape` (the union: IT's always-binding caps + docstring structure
  checks, PF's page/section units, one CSV schema `docs/prose_shape.csv`), `ai_banner`,
  `rendered_markup` (post-`makedocs`), and `review_closure` (which calls `gbg gate check-docs
  check-consistency` via `run_gate`). The consumer's `make.jl` shrinks to
  `GBGCodingTools.DocLints.pre(cfg)` / `makedocs(...)` / `GBGCodingTools.DocLints.post(cfg)`.
- `GBGCodingTools.TestHarness` — `@alloc_below`, the derived allocation-completeness check,
  `CountingArray` + `Traffic` + `audit`, method-parity engine (frozen tables stay in the consumer),
  oracle-registry engine, `package_operations()` (ownership-derived public surface),
  `run_regressions(dir)` (the wrapper-module include loop, one spelling), the display gate (with
  IT's `UnionAll` fix), the cross-`-t` subprocess bitwise check, `gate()` for `bug-hunt` and
  `audit-changes` rounds (again via `run_gate`). Consumed exactly like Aqua: one call from
  `runtests.jl` per lane the consumer enables (theory §8e).
- `GBGCodingTools.Witnesses` — `run(round, :fail|:pass; names)` (IT's required expectation, PF's
  pile-as-argument, IT's broken-fails-exit, `Base.julia_cmd()` inheritance).
- `GBGCodingTools.Config` — the loader/validator shared by the above.
- Compat `julia = "1.11"` (so the package does not *force* SS's floor question; `[sources]` itself
  needs ≥ 1.11). Tested on the fleet's 1.12.7 and CI's `'1'`.

**(b) Forced by.** The survey's lint matrix (`survey-buildlints-hooks-policy.md:§1`): nine lints in
PF, four in IT (two rewritten with different CSV schemas), one ancestor in SS, none in CP — the
definition of a platform asset; and the test-guard matrix (§5): eight PF-only harness ideas and two
"copy with drift" cases (display gate, regression loop). D9 puts each in one module.

**(c) Alternatives.** *Keep lints in each `make.jl` and share by copy*: the status quo. *A separate
`GBGTestHarness.jl` package*: a second pin (D1). *Register with the General registry*: private.

### D10 — Rounds: `.gbg/rounds/<YYYY-MM-DD>-<instrument>-<seq>/`, TRACKED, one layout for every instrument, `round.toml` is the open-round marker and the version stamp

**(a) Choice.**

```
.gbg/rounds/2026-09-06-check-consistency-1/
  round.toml            # stamp: instrument, tool_version, tool_rev, config_hash, catalog_hash,
                        #   julia, model, strength, hats/lanes run, opened, [closed = "<account>"]
  lanes/NN-<key>.md     # banked findings, one file per hat/lane, written by the agent FIRST
  verdicts/state/NN-<key>.md   # blind verifier (verify.js)
  verdicts/act/NN-<key>.md     # diff-seeing verifier (verify-fixes.js)
  calibration/ground_truth.json   # only when the round was seeded (D15)
  witnesses/*.jl        # bug-hunt only; status in round.toml [[witness]] table
  audit.json            # audit-changes only (PF's {head, covered_paths, concerns, dispositions})
  SUMMARY.md            # consolidated reading artefact — never the fix work-list
```

Every banked markdown file ends with a fenced ```` ```json gbg-findings ```` block holding the same
structured array the agent returned (ids `<round>/<key>/<n>`, the schema of D11); the prose above
it is for humans, the block is what every script parses, and `gbg coverage` fails when the two
disagree in count. Verdict files carry the same block with `class_surfaces` as an **array**, so the
demotion predicate is emptiness (D11). **Tracked in git** for all four consumers; `-prev` archives are
just older rounds. The closure gate (`gbg gate`) exits 2 if `.gbg/rounds/` is absent (never
scaffolded), 1 if any round of the requested instrument is open or has a finding neither HONORED nor
adjudicated nor SEEDED, 0 otherwise. `make.jl` gates the two doc instruments; `Pkg.test()` gates
`bug-hunt` and `audit-changes`. Adjudication is per finding **by id**, in `.gbg/exemptions.toml`
(D14), which the panel preamble receives as the *titles-only* rendering (`gbg args` strips ids and
seeds) — so hats see the do-not-re-flag list and never the answer key.

**(b) Forced by.** R3 and the two agreed constraints in `IT/INVENTORY.md` ("a gate reading only an
untracked pile passes vacuously"; "must become a script both builds call"); R2 (the stamp); the
"grader's verdicts, never the graded party's file" rule (`survey-check-consistency.md:§6.8`) — the
structured block is written by the grader and post-processed by script. Tracking is PF's answer
(51 files) generalised; the cost is kilobytes of text.

**(c) Alternatives.** *IT's tracked marker + untracked pile*: certifies only "a human wrote an
account" (`survey-check-consistency.md:§5.4`). *PF's gitignored pile + `CLOSED.md`*: vacuous on a
clone. *Title-keyed adjudication*: misses untitled findings (`PF doc-review/CLOSED.md` L24–27) —
ids fix it. *Per-instrument layouts*: one gate cannot read them (R10).

### D11 — Schemas: one JSON Schema per instrument in `schema/`; closed platform vocabularies; consumer extension only through declared `type` enums

**(a) Choice.** `schema/finding.schema.json` (common core: `id, title, severity∈{blocker,major,minor,nit},
confidence∈{high,medium,low}, locations[], description, resolution_hint, type`), with
`schema/<instrument>.schema.json` extending it. **Closed platform enums** (not configurable):
- state verdicts: `PRESENT | PARTIAL | REGRESSED | ABSENT | NOT-A-DEFECT` (IT's set; `PARTIAL`
  carries `surviving_class[]`);
- act verdicts: `HONORED | LINE-ONLY | NEW-DEFECT | SCOPE-CREEP | UNDONE | LAUNDERED | ADJACENT |
  INSERTED` plus `question∈{fidelity,strategy,implementation,scope,none}` (the union; PF's six are a
  subset, IT's two extras encode measured fixer failures);
- hunt: hunter `observed∈{FAILS,PASSES,ERRORS,NOT-WRITABLE}`; adjudication
  `REPRODUCED | EVIDENCED | NOT-REPRODUCED | WITNESS-WRONG | NO-WITNESS-POSSIBLE | NOT-A-DEFECT |
  ALREADY-COVERED`; ledger `fixed | refuted | escalated`; dismissal audit
  `DISMISSAL-SOUND | UNSAFE | DISMISSAL-WRONG` (default UNSAFE); architecture-fix
  `FIXED | RELOCATED | PARTIAL | ABSENT | NOT-A-DEFECT`;
- audit concerns: `severity∈{serious,notable,minor}`, `justified∈{yes,no,unclear}`,
  `previously_worked`, `before/after/why_it_matters`, per-lane `checked[]` and `candidates_found`
  (IT's), dispositions `fixed|refused|escalated` with the ≥24-char refusal rule (PF's).
**Consumer extension**: exactly one open point — `finding.type` is a per-package enum declared in
`config.toml` (`[schema] finding_types = ["math","normalization",…]`), validated as closed *after*
merge. Any other divergence is a platform MAJOR (D16).

**(b) Forced by.** R11 verbatim; `IT/INVENTORY.md` ("a SCHEMA divergence, not wording: `dismissals`,
`closure` and `finished` all key off it"); `survey-check-consistency.md:§5.3` ("a shared package
needs one union vocabulary because `coverage.py` and any gate parse it").

**(c) Alternatives.** *Configurable vocabularies*: the four diverge inside the schema instead of
outside it (theory §Synthesis, trap 4). *Minimal intersection instead of union*: loses `PARTIAL`
("the verdict that earns the instrument") and `ADJACENT/INSERTED` (measured fixer failures).

### D12 — Policy prose: single source `policy/*.md` in the platform, copied into the consumer as generated-managed files under `.gbg/policy/`, imported from `CLAUDE.md` by one managed block; deviations are ledger entries rendered into `deviations.md`

**(a) Choice.** The platform ships the rubric as rule-numbered sections: `policy/docs-rubric.md`
(the two-tier structure, four shape rules, aliasing, cross-referencing, physical-meaning-first,
cost register…), `policy/latex-idiom.md`, `policy/citations.md`, `policy/testing-protocol.md`
(gate vs survey, definition of done, oracle provenance, witness rule), `policy/instruments.md`
(consent gate, cost modes, freeze, closure, both-directions), `policy/git-conventions.md` (commit ⇒
push, trailer, CI manual-only). Every rule carries a stable id (`DOC.STEER`, `TEX.MATHBF`,
`DOC.ADMONITION_TITLE`, `GIT.BRANCH`, `API.POSITIONAL`). `gbg sync` copies them to
`.gbg/policy/*.md` with the managed header and renders `.gbg/policy/deviations.md` from the
consumer's declared deviations (D14). `CLAUDE.md` carries one managed block:

```markdown
<!-- gbg:policy v1.4.0 begin — managed by `gbg sync` -->
@.gbg/policy/00-index.md
<!-- gbg:policy end -->
```

`00-index.md` imports the rest (depth ≤ 4 is allowed, facts §4). The battery reads the same ids: a
surface lane's prompt is given `policy_files` from `args`; the deterministic scans are keyed by rule
id in `catalog/scans.toml`, and a declared deviation on `TEX.MATHBF` both appears in
`deviations.md` for the reading model and disables that scan for the gate. Everything
package-specific — invariants, module maps, roadmap, decision-log pointers, postmortems — stays in
the consumer's `CLAUDE.md` outside the block; the *policy* leaves it. (PF's 2685-line file is ≈ 687
policy / 1998 specific by the survey's estimate, `survey-buildlints-hooks-policy.md:§4`.)

**(b) Forced by.** R1 ("existing differences … historic artefacts"), R2 ("what does this package
deviate in and why"), the measured triplication-by-hand-adaptation of the rubric plus its
quadruplication inside IT (`survey-checkdocs.md:§5`), and the survey's rule 18 that owner-ruled
divergences "must stay configurable, not silently unified" (`survey-checkdocs.md:§7.18`). A copied
file with a hash is chosen over an import of the pinned copy (`@~/.julia/packages/…/<slug>/…`)
because imports outside the working directory trigger an approval dialog (facts §4), the slug
changes on every bump, and a copy makes the policy diff visible in each consumer's history — R2.

**(c) Alternatives.** *Import the pinned copy directly*: above. *`.claude/rules/*.md`*: same
mechanism with auto-discovery; not chosen only because the explicit block makes the version and
the boundary visible in `CLAUDE.md` itself. *Leave each `CLAUDE.md` as is and diff*: the status quo.

### D13 — Managed files: four classes, hash-stamped where generated, wiring-checked where owned

**(a) Choice.** Every file the platform touches in a consumer belongs to one of:
1. **config** — owned by the consumer, schema-validated: `.gbg/config.toml`, `.gbg/exemptions.toml`,
   `.gbg/hats/*.toml`.
2. **generated-managed** — rendered by `gbg sync`, first line
   `# gbg-managed v<ver> sha256:<hash of body> — DO NOT EDIT; run \`gbg sync\``; `doctor` reports
   `OK | MODIFIED | STALE(version)`: `.claude/skills/*/SKILL.md`, `.claude/settings.json`,
   `.gbg/policy/*.md`, the `[sources]`/`[compat]` entries in the three `Project.toml`s (managed
   *entries*, since Pkg rewrites those files), the `gbg:` blocks in `CLAUDE.md` and `.gitignore`,
   `test/regressions/README.md`.
3. **seeded-once-then-owned** — created by `gbg init` if absent, never touched again, but
   *wiring-checked* by `doctor` (a grep for the required calls): `docs/make.jl` (must call
   `DocLints.pre`, `makedocs`, `DocLints.post`), `test/runtests.jl` (must call
   `TestHarness.run_regressions(@__DIR__)` and `TestHarness.gate()`), `.github/workflows/{CI,docs}.yml`
   (must authenticate the private platform dep), frozen baselines (`docs/prose_shape.csv`,
   `test/method_parity_baseline.toml`, pass-audit tables), `test/regressions/*.jl`.
4. **tracked-pile** — `.gbg/rounds/**`, written by rounds, read by gates, never rendered.

**(b) Forced by.** R6, R9, R1 — and the precise disease: "the drift began" with editing rendered
files (theory §3a caution). Class 2 makes editing impossible to hide; class 3 keeps the files the
consumer legitimately owns out of the merge problem; the wiring check is the cheapest guard against
"the lint was silently removed from `make.jl`".

**(c) Alternatives.** *Copier-style three-way merge for everything*: invites edits (theory §3a).
*Hash-manage `make.jl`*: `makedocs` arguments are package-specific, so the file would need a
template language — a second mechanism for one file.

### D14 — Doctor and conformance: `gbg doctor` (read-only, stable check ids), one exemptions ledger with reason + expiry, `gbg fleet` as the scorecard

**(a) Choice.** Checks (each with an id, a one-line fix hint, exit 1 if any fails, 2 if the repo is
not a consumer): `PIN.AGREES` (config ↔ three `Project.toml` ↔ resolved manifest), `PIN.NOT_DEV`,
`ENV.LOADS` (`using GBGCodingTools` in each env — "resolve/instantiate/LOAD are not
interchangeable"), `CONFIG.VALID`, `MANAGED.HASH` per class-2 file, `WIRING.MAKEJL`,
`WIRING.RUNTESTS`, `WIRING.CI_AUTH`, `ROUNDS.DIR`, `ROUNDS.OPEN` (list), `EXEMPT.EXPIRED`,
`EXEMPT.EXPIRING` (warn ≤ 30 d), `EXEMPT.STALE` (target no longer exists — PF's
`field_docs.py` self-detection generalised), `GIT.BRANCH`, `GIT.TRAILER` (last 20 commits),
`JULIA.CHANNEL`, `CONTRACT.SYNC` (the consumer's config equals the copy in the platform's
`contracts/`). `--effective` prints the machine facts. **Ledger** `.gbg/exemptions.toml`, one shape
for every escape hatch:

```toml
[[exemption]]
id        = "DOC.STEER"                 # a policy rule, a scan, a lint, or a finding id
scope     = "policy"                    # policy | scan | lint | finding | harness
target    = "*"                         # or a symbol / file / finding id
reason    = "In-place steer sentence declined (owner-ruled 2026-08-25): IT's `!` forms …"
recorded  = 2026-08-25
expires   = 2027-08-25                  # required; the doctor fails on expiry
evidence  = "CLAUDE.md §Documentation policy"   # or rounds/<r>/calibration/ground_truth.json
```

This one ledger replaces `doc-review-adjudicated.md` (scope `finding`), the do-not-re-flag lists in
`CLAUDE.md`, `field_docs.py`'s `NO_FIELD_LIST`, the allocation audit's exemption list (scope
`harness`), and `CLOSED.md` (scope `finding`, `target = "<round>/*"`, reason = the account). The
seed contradiction dissolves: a seeded finding is closed by the gate reading
`calibration/ground_truth.json` (scope `finding`, `evidence` pointing at it), and `gbg args` never
passes seeds or ids to a hat. **Fleet view**: `gbg fleet` runs `doctor` in each consumer listed in
the platform's `fleet.toml` and prints one row per (consumer × check) — the scorecard whose going
green *is* the migration (theory §4a).

**(b) Forced by.** R9, R2, R3; theory §4b/§4c (expiring exceptions are what keep a committed escape
from rotting); the survey's rule 12 ("exemptions are enumerated with reasons and checked for
staleness", `survey-checkdocs.md:§7.12`).

**(c) Alternatives.** *Several ledgers by kind (adjudicated, CLOSED, exemptions)*: the current state;
three formats, three readers. *No expiry*: a waiver becomes permanent silently. *Auto-repair in
doctor*: `brew doctor` separates diagnose from repair for a reason (theory §4d); `sync` repairs.

### D15 — Self-testing: a fixture consumer in the platform, every gate with a perturbation self-test, four consumer contracts, and the platform's own CI

**(a) Choice.** `fixture/GBGFixture/` is a complete toy consumer (a 3-module Julia package with
docstrings, a `docs/` site, a `test/` with one regression, a `.gbg/`), holding a **known-defect
corpus** (`fixture/defects.toml`: each defect's class, location, the check that must catch it).
`gbg selftest` runs: (i) every scan/lint against the fixture and asserts each listed defect is
found and the clean twin is not; (ii) the perturbation arms of every gate — coverage, closure,
recall, witness runner, audit gate, demotion — on a perturbed copy of a fixture round (PF's
`recall_selftest.py` shape, generalised: "a test passing over a catalog is a property of the
CATALOG"); (iii) schema validation of all four `contracts/<consumer>/config.toml` and a dry
`gbg args` for every enabled instrument of each; (iv) `Pkg.test()` of the Julia package against the
fixture. The seeded-defect **calibration catalogue is anchored to the fixture**, not to any real
package (`seed_defects.py`'s "the catalog is PF's own" becomes "the catalog is the fixture's");
seeding a real package's round stays possible and is closed via the ledger. Platform CI (manual +
tags, like the consumers) runs `gbg selftest`; a MAJOR bump additionally requires a recorded
recall figure on the fixture in the CHANGELOG.

**(b) Forced by.** R5 verbatim; theory §5b, §6a, §6b; `survey-check-consistency.md:§6.15` ("a
self-check is a script, not a note"); the contradiction record ("seeds must never enter the
adjudicated file", §6.4).

**(c) Alternatives.** *Test against the real consumers by relative path*: skip-when-absent passes.
*No fixture, only unit tests*: cannot exercise an end-to-end round.

### D16 — Instrument change discipline: semver with a "measurement-affecting ⇒ MAJOR" rule, a stamped round, no mid-round upgrade

**(a) Choice.** `MAJOR`: any change to a verdict vocabulary, demotion predicate, scan tier, threshold
default, seed catalogue, scoring/recall formula, or schema; `MINOR`: a new hat, lane, scan, lint,
check, or config key with a default; `PATCH`: a fix that changes no verdict on the fixture. Each
CHANGELOG entry names the affected instruments and whether cross-round rates remain comparable.
`round.toml` stamps `tool_version`, `tool_rev`, `config_hash`, `catalog_hash` at open; `gbg round
close` refuses (exit 2) if the current pin differs from the stamp unless `--regraded` is given with
an account, which is written into the round; `gbg bump` refuses while any round is open unless
`--abandon-open-rounds "<account>"`, which closes them with that account. `gbg release <ver>` tags
the dev checkout, runs `gbg selftest`, and pushes the tag; nothing else is a release.

**(b) Forced by.** R4 verbatim; theory §2e ("define what incompatible means … a change in a verdict
vocabulary … is MAJOR"), §5e; the freeze record (`IT/INVENTORY.md` "Instrument freeze") and its
measurement that a mid-round grader edit made round 3→4 uninterpretable.

**(c) Alternatives.** *Commit-SHA pins without semver*: no way to say "comparable". *Floating
branch pin*: pre-commit's explicit anti-pattern.

### D17 — Migration: PF → IT → SS → CP, each by the scorecard, with named collapses and declared deviations (§5 below)

**(a) Choice.** Order: **PF** first (canary: strictest suite, origin of most engines, the owner's
working tree), then **IT** (largest engine contribution to merge: operational-claims check,
`attack-design`, `finished` checks, profiles, `hats.json`), then **SS** (a July fork — almost
everything is a historic artefact and is replaced wholesale), then **CP** (greenfield: `gbg init`).
Per consumer the steps are the doctor's checks turning green in order (§5). Deletions: every
`.claude/commands/**` file, every lint body in `make.jl`, the copied harnesses in `test/`, the
policy sections of `CLAUDE.md`, `doc-review-adjudicated.md`, `CLOSED.md`s, `MANIFEST.txt` +
`manifest.py`, `WORK_QUEUE`'s hook script. Kept: baselines, `test/regressions/*.jl`, package-specific
`CLAUDE.md` content, the rounds (moved under `.gbg/rounds/` by a migration script).

**(b) Forced by.** R9; theory §6c (canary); the survey's classification of each difference as
(a)/(b)/(c) — §5 below lists them by name.

**(c) Alternatives.** *Big-bang all four*: no canary. *SS/CP first because they are small*: they have
nothing to contribute to the engine merge and would be migrated twice.

### D18 — Model/cost policy: economy default, anchors are a property of a hat in config, the model names and the never-economised phases are platform constants

**(a) Choice.** `config.toml [cost] default = "economy"`; each hat/lane entry has `anchor = true|false`
(domain hats default to anchor; generic ones to economy); `catalog/models.toml` holds
`economy = "sonnet"` (the only place the model name appears — a bump is a PATCH). The engine applies:
anchors inherit the session model, non-anchors get the economy model under economy strength;
adjudication, reproduction, verification, consolidation and the fix pass are never economised
(engine constant, not configurable — R12 "fix phase full strength"). `strength = "full"` is a skill
argument passed through `gbg args`, never a config value (it is a per-run decision).

**(b) Forced by.** R12; the PF/IT cost-mode paragraph is verbatim-ported already
(`survey-checkdocs.md:§1`) — it is common; the *anchor set* is the only per-package datum
(`survey-check-consistency.md:§1.4`: PF two anchors, IT four).

**(c) Alternatives.** *Anchors in the engine*: a domain hat is a consumer's (R10). *Model name in
consumer config*: four places for one value.

### D19 — Name: `GBGCodingTools`

The package covers policy, test harness, docs lints, scaffolding **and** the review instruments;
`GBGInstruments` would name one third of it, and `*Tools` is the Julia idiom for dev-time helpers
(`BenchmarkTools`, `DocumenterTools`). Keeping the owner's working name also costs zero renames in
the four `CLAUDE.md` corpora; the CLI `gbg` is short enough for a skill preamble. Second choice
`GBGDevTools` (signals "never a runtime dep"); `GBGInstruments` is bound as the *term* for the
review half inside the docs, so the house vocabulary survives.

---

## 2. Repository layout of `GBGCodingTools.jl`

```
GBGCodingTools.jl/
  Project.toml                 # name, uuid, version = "1.4.0", julia = "1.11", deps: TOML, Test, Documenter (weak)
  CHANGELOG.md                 # per release: MAJOR/MINOR/PATCH, instruments affected, "rates comparable: yes/no"
  README.md                    # what it is, install (3 commands), the one design sentence
  fleet.toml                   # dev-side only: relative paths of the four consumers for `gbg fleet`
  bin/
    install.sh                 # per-machine: writes ~/.local/bin/gbg (the shim), checks python3/julia
    gbg                        # the shim body (copied by install.sh)
  src/                         # the Julia package
    GBGCodingTools.jl          # module; `run_gate(args…)` = python3 <pkgdir>/gbg … with exit → error()
    Config.jl                  # load + validate .gbg/config.toml against schema/config.schema.json
    DocLints.jl                # pre(cfg)/post(cfg) + every lint as a function taking surfaces
    TestHarness.jl             # @alloc_below, CountingArray/Traffic, method parity, oracle registry,
                               #   package_operations, run_regressions, display gate, gate()
    Witnesses.jl               # run(round, :fail|:pass; names)
    Reflection.jl              # argcov, signature_fidelity, xlink (dry-run default), dupref
  gbg/                         # the Python CLI (stdlib only)
    __main__.py                # `gbg <noun> <verb>`; exit-code contract
    config.py  schema.py       # loader + minimal JSON-Schema validator (shared with Julia via the same file)
    doctor.py  sync.py  init.py  fleet.py  bump.py  release.py
    args.py                    # config ∪ catalogue → one JSON object per instrument
    rounds.py                  # open/close/list, round.toml, stamps
    gate.py                    # THE closure gate for every instrument (per finding by id; SEEDED via ground_truth)
    coverage.py  recall.py  seed.py  consolidate.py  verify_post.py   # post-processing (demotion by emptiness)
    scans/                     # deterministic text scans: sentence_openers, field_docs, link_uniformity,
                               #   doi_crosscheck, abutting_spans, tables, register, tex_idiom, stale_refs…
    witnesses.py               # thin wrapper calling julia Witnesses.run
    hooks/queue_guard.py       # optional Stop hook (PF's WORK_QUEUE), reached via `gbg hook queue-guard`
    selftest.py                # runs every perturbation arm + fixture corpus + contracts
  instruments/                 # one directory per instrument = its contract (R10)
    check-docs/
      PROTOCOL.md              # the protocol the skill stub points at; no inline script copies
      workflow/lanes.js        # surface lanes + family + cold-reader, args-driven
      schema.json              # instrument-specific finding schema (extends schema/finding.schema.json)
      selftest/                # fixture rounds + perturbation arms
    check-consistency/
      PROTOCOL.md  workflow/{panel.js, verify.js, verify-fixes.js, severity-recheck.js, rubric-audit.js}
      schema.json  selftest/
    bug-hunt/
      PROTOCOL.md  workflow/{hunt.js, dismissals.js, verify-architecture.js}  schema.json  selftest/
    audit-changes/
      PROTOCOL.md  workflow/{audit.js, attack-design.js}  schema.json  selftest/
  catalog/
    hats/*.toml                # generic hats: key, role, persona (with {package.*} placeholders), siteonly, substrate
    lanes/*.toml               # hunt territories/classes, audit lanes (code/prose), check-docs surface lanes
    scans.toml                 # every deterministic scan: id, tier hard|triage, rule id, surfaces key
    lints.toml                 # every DocLints function: id, rule id, default on/off
    models.toml                # economy = "sonnet"
    seeds/fixture.toml         # calibration catalogue anchored to the FIXTURE text
  policy/                      # the single-source rubric, rule-numbered
    00-index.md  docs-rubric.md  latex-idiom.md  citations.md  testing-protocol.md
    instruments.md  git-conventions.md  glossary.md
  schema/
    config.schema.json  exemptions.schema.json  hat.schema.json  finding.schema.json
    round.schema.json   audit.schema.json
  templates/                   # rendered by init/sync (class 2 and class 3 seeds)
    SKILL.md.tmpl  settings.json.tmpl  make.jl.seed  runtests.jl.seed  CI.yml.seed  docs.yml.seed
    regressions-README.md  gitignore.block  claude-md.block
  contracts/                   # consumer-driven contracts: a committed copy of each consumer's config (+ hats)
    GBGPeriodicFields/  GBGIsotropicTurbulence/  GBGStreamingStatistics/  GBGCloudPhysics/
  fixture/GBGFixture/          # the toy consumer: src/, docs/, test/, .gbg/, defects.toml
  test/runtests.jl             # Julia tests of DocLints/TestHarness/Witnesses over the fixture
  .github/workflows/ci.yml     # manual + tags: julia Pkg.test + `gbg selftest`
```

---

## 3. Footprint left in a consumer (PF as the example)

Legend: **C** config (owned), **G** generated-managed (hash-stamped), **S** seeded-once-then-owned
(wiring-checked), **P** tracked-pile.

```
GBGPeriodicFields/
  .gbg/
    config.toml                         C   the one config (schema in §4)
    exemptions.toml                     C   the one ledger (policy deviations, scan/lint/harness exemptions, adjudicated findings)
    hats/spectral-methods-mathematician.toml   C   the consumer's domain hats (anchors)
    hats/differential-geometer.toml     C
    policy/00-index.md … git-conventions.md, deviations.md   G   copies of the platform policy + rendered deviations
    rounds/.keep                        P   (absence = ROUNDS.DIR fails)
    rounds/2026-09-01-check-docs-1/…    P   migrated from .claude/check-docs-2026-09-01
    rounds/2026-08-27-check-consistency-1/…   P   migrated from .claude/doc-review-checkdocs
  .claude/
    skills/check-docs/SKILL.md          G   ≤15-line stub (D6)
    skills/check-consistency/SKILL.md   G
    skills/bug-hunt/SKILL.md            G
    skills/audit-changes/SKILL.md       G
    settings.json                       G   hooks block only (`gbg hook queue-guard` if enabled)
    settings.local.json                 —   gitignored fleet-wide; Dropbox-synced; `autoMemoryDirectory` key re-rendered by `gbg init`
  CLAUDE.md                             S   package-specific content + one G block (`<!-- gbg:policy … -->`)
  .gitignore                            S   + one G block (Manifest.toml, docs/build, .claude/settings.local.json, *.cov)
  docs/make.jl                          S   `DocLints.pre(cfg)` / `makedocs(…)` / `DocLints.post(cfg)` — wiring-checked
  docs/Project.toml                     S   + G entries: [sources]/[compat] GBGCodingTools
  docs/prose_shape.csv                  S   frozen baseline (one schema fleet-wide)
  test/runtests.jl                      S   includes `TestHarness.run_regressions(@__DIR__)`, `TestHarness.gate()` — wiring-checked
  test/Project.toml                     S   + G entries
  test/regressions/README.md            G   the promotion contract, one text fleet-wide
  test/regressions/*.jl                 S   promoted witnesses (unchanged at promotion; maintained with the tree thereafter — stated)
  test/method_parity_baseline.toml      S   frozen counts (engine in the platform)
  test/pass_audit_baseline.toml         S   frozen traffic table
  test/oracle_registry.toml             S   provenance classification
  benchmark/Project.toml                S   + G entries (PF only today)
  .github/workflows/CI.yml, docs.yml    S   must contain the private-dep auth step — wiring-checked
```

Gone from the consumer after migration: `.claude/commands/**` (all 30 PF / 41 IT files),
`.claude/hooks/`, `.claude/doc-review*`, `.claude/*-adjudicated.md`, `CLOSED.md`, `MANIFEST.txt`,
`manifest.py`, the nine lint functions in `make.jl`, `test/public_surface.jl`, the `@alloc_below`
macro and `CountingArray` bodies, the regression include loop, the policy ≈700 lines of `CLAUDE.md`.

---

## 4. Config schema (`.gbg/config.toml`) — complete enough for PF and SS

```toml
# gbg config — schema: GBGCodingTools/schema/config.schema.json (closed: unknown keys fail)
[tool]
version = "1.4.0"                       # the pin (D3); rendered into the three Project.toml [sources]

[package]
name        = "GBGPeriodicFields"
description = "real-valued scalar/vector/second-order-tensor fields on 3D periodic domains, physical and rfft spectral representations, CPU and GPU (CUDA/ROCm); the field layer for pseudospectral solvers"
modules     = ["FiberSections","Fields","FieldAlgebra","DifferentialOperators","Convolution","Points","Interpolation","Reductions"]
extensions  = ["ext/GBGPeriodicFieldsHDF5Ext.jl"]
deliberate_absences = ["no time, no particles, no physics", "no field×field multiply in spectral representation", "no tensor order above 2"]
terms       = ["base","fiber","section","resolved band","cutoff","assignment","destination"]   # cold-reader term list
domain      = "pseudospectral fields"    # free text used by generic personas
finding_types = ["math","normalization","structure","notation","citation","style","operational"]  # the ONE schema extension point

[git]
branch  = "master"
trailer = "Co-Authored-By: Anthropic Claude <noreply@anthropic.com>"

[julia]
channel   = "1.12"                      # juliaup channel the instruments assume
test_cmd  = "julia --project -e 'using Pkg; Pkg.test()'"
threads_ci = [1, 4]

[paths]                                  # every surface list lives HERE and nowhere else
rationale_docs = ["docs/ARCHITECTURE.md","docs/FORMALIZATION.md","docs/TESTING.md","docs/PERFORMANCE.md"]
generated_copies = ["docs/src/architecture.md","docs/src/formalization.md","docs/src/testing.md","docs/src/performance.md"]
doc_pages   = ["docs/src/**/*.md"]
examples    = ["examples/HIST_CPU.jl","examples/gpu/*/*.jl"]   # Literate = rendered page
built_html  = "docs/build"
decision_log_heading = "## 13. Decision log"                  # append-only history, exempt from current-state scans
references_heading   = "## References"

[docs]
doctest      = true
checkdocs    = "exports"
size_threshold_ignore = ["architecture.md","performance.md"]
lints_off    = []                        # by lint id; each entry needs an exemption with a reason

[tests]
harness_lanes = ["allocations","pass_audit","method_parity","oracle_registry","display","regressions","threading_subprocess","exhaustive_ledger"]
allocation_slack_per_thread = 4096
audited_ops_from = "public_surface"      # derived denominators, never listed

[instruments]
enabled = ["check-docs","check-consistency","bug-hunt","audit-changes"]

[instruments.check-docs]
surfaces = ["rationale","docstrings","pages","examples","built_html"]
checks   = ["correct","operational","self_contained","notation","formatted","current","cited","variant_pairs"]
lanes_extra = ["family","cold-reader"]

[instruments.check-consistency]
hats    = ["consistency-matrix","software-architect","gpu-kernel-practitioner","structure-consistency",
           "latex-typesetter","api-user","normalization-convention-auditor","citations-integrity",
           "style-editor","cold-reader",
           "spectral-methods-mathematician","differential-geometer"]   # last two: .gbg/hats/, anchor = true
profile = "all"                          # or "core" (IT) — a named subset declared in this table
design_docs_withheld = ["architecture","formalization","testing","performance"]   # consolidate.py's site-only view
seed_rounds = false                      # calibration lives on the fixture; true = seed real rounds (closed via ledger)

[instruments.bug-hunt]
partition = "territory"                  # territory | class | both  (an engine-supported enum, D7)
territories = [
  {key="fields",     files=["src/Fields.jl","src/FiberSections.jl"],        brief="layout, plans, multipliers, reality condition"},
  {key="algebra",    files=["src/FieldAlgebra.jl","src/Points.jl"],          brief="codegen families, α/β, aliasing"},
  {key="operators",  files=["src/DifferentialOperators.jl","src/Convolution.jl"], brief="Nyquist split, kernels, projector"},
  {key="transfer",   files=["src/Interpolation.jl"],                          brief="adjoint pair, traversal order, NUFFT"},
  {key="reductions", files=["src/Reductions.jl"],                             brief="measure, Parseval, shell binning"} ]
oracles = ["adjointness","Parseval","div(curl)=0","curl(grad)=0","the documented definition over raw arrays"]
witness_env = "test"                     # the --project a witness runs under

[instruments.audit-changes]
covered_paths = ["src","test","docs"]
executable_claims = { "allocation-free" = "test/allocations.jl", "traffic" = "test/pass_audit.jl", "method set unchanged" = "test/method_parity.jl" }
guard_symbols = ["_check_field_domain_compatibility","_check_same_domain","_check_contractible","_check_multipliers_compatibility","_check_owned_storage"]

[cost]
default = "economy"

[hooks]
work_queue = true                        # PF only; renders the Stop hook into .claude/settings.json

[notation]
vectors   = "component"                  # component | boldsymbol  (IT: boldsymbol) — a domain choice, not a deviation
indicator = "\\mathbf{1}"                # the ONE admitted \mathbf; IT has no indicator and simply never writes it
partial   = "\\partial_{x_i}"
```

**SS's real differences, expressed:** `package.domain = "streaming statistics"`, `finding_types`
adds `"statistics"`; `[instruments.check-docs] checks` adds `"estimand_first"` (a platform check
that exists because SS contributed it — MINOR); `[instruments.check-consistency] hats` names
`statistics-theoretician`, `streaming-stability-practitioner` from `.gbg/hats/` as anchors and
drops `gpu-kernel-practitioner`; `[paths]` names its `ext/` file; `[notation] vectors = "none"`
(no vector/tensor notation, so the `\boldsymbol`/`\partial_i` scans are inapplicable *by config*,
not by exemption — as SS's own record says). SS's **bold argument bullets** and its
**keyword smoothing controls** are *not* config: they are policy deviations, and appear in
`.gbg/exemptions.toml` with reasons (§5).

**Deliberately NOT configurable** (platform constants; changing any is a MAJOR): every verdict
vocabulary; the demotion predicate (emptiness of `class_surfaces[]`); severity/confidence enums;
scan tiers (hard/triage); the never-economised phase list; the model name for economy; the
staleness mechanism (filesystem mtime + UNCHECKABLE); the "zero count = dead lane" rule; the
seeded-defect catalogue; the round layout and stamp fields; the exit-code contract; the definition
of "closed"; the regression include spelling; the managed-file header format.

---

## 5. Run-time contract of one instrument end to end — `/check-consistency`

1. **Skill.** `/check-consistency [strength=full] [hats=a,b]` loads `.claude/skills/check-consistency/SKILL.md`
   (G). Its `!` injections run `gbg root` → `/home/grigory/.julia/packages/GBGCodingTools/Ab12c` and
   `gbg args check-consistency --strength full` → one JSON object. If `.gbg/config.toml` is
   missing/invalid the injection prints the doctor's error and the skill body tells the model to stop
   (R3). The model reads `<root>/instruments/check-consistency/PROTOCOL.md`.
2. **Round open.** `gbg round open check-consistency` → creates
   `.gbg/rounds/<date>-check-consistency-<n>/round.toml` with the stamp (`tool_version`, `tool_rev`,
   `config_hash`, `catalog_hash`, `julia`, `model` (from the session, passed as an arg),
   `strength`, `hats`, `opened`); refuses (exit 2) if another round of this instrument is open.
3. **Build + consolidate.** `julia --project=docs docs/make.jl` must **exit 0** (it runs
   `DocLints.pre/post`, which include `gbg gate check-docs check-consistency` — so an unclosed
   earlier round already fails here). `gbg consolidate <round>` writes
   `<round>/manuscript-full.md` and `manuscript-siteonly.md` (gitignored inside the round by a
   `.gitignore` the platform writes; they are regenerable).
4. **(Optional) seeding.** Only if `seed_rounds = true`: `gbg seed <round>` mutates the manuscripts and
   writes `<round>/calibration/ground_truth.json`. The hats' args never contain it.
5. **Panel.** `Workflow({scriptPath: "<root>/instruments/check-consistency/workflow/panel.js", args})`.
   `panel.js` runs the hats in `parallel`, each agent told to **Write `<round>/lanes/NN-<key>.md`
   first** (prose + the ```` ```json gbg-findings ```` block) and return the same object; the script
   returns `{results, dead, empty, truncated, hats_run}` and asks one census agent to write
   `<round>/hats.json` (IT's roster mechanism). Hats receive the adjudicated list as titles only.
6. **Bank check.** `gbg coverage <round>` — every hat in `hats.json` has a lane file; parse-to-zero
   with no "No findings" sentence = dead (exit 1); JSON block count ≠ heading count = exit 1;
   `<round>/SUMMARY.md` is produced by `gbg consolidate --summary` from the JSON blocks (seeded hits
   subtracted, corroboration with a denominator, capped hats marked), for reading only.
7. **Fix pass** (main thread, full strength, on the owner's word), driven from `lanes/*.md` by finding
   id.
8. **Verify.** `verify-fixes.js` (args add `range = <open commit>..HEAD`) writes
   `<round>/verdicts/act/NN-<key>.md`; `verify.js` (blind; corpus search scoped
   `--glob '!.gbg/**'`) writes `<round>/verdicts/state/NN-<key>.md`. Then `gbg verify <round>`
   post-processes: demotion HONORED→LINE-ONLY iff `class_surfaces` is an empty array (mechanical,
   reported separately), staleness by mtime (verdict older than lane = stale), the census
   denominator vs self-report logged, disagreements between the two verifiers listed. Output:
   `<round>/verdicts/tally.json`.
9. **Gate.** `gbg gate check-consistency` → per finding id: HONORED in `verdicts/act`, or an
   `exemptions.toml` entry with `scope = "finding"`, or an id in `calibration/ground_truth.json`
   (SEEDED). Anything else: open. Exit 1 while open; exit 2 if `rounds/` or `hats.json` is absent.
10. **Loop.** Fix → step 8 → step 9 over the *same* banked set; stop when the gate is 0 or the tally
    is flat three rounds (printed by `gbg verify` as `plateau: true`, which is an *account*, not a
    pass — closing on a plateau requires `--abandon "<reason>"`).
11. **Close.** `gbg round close <round>` writes `closed = "<ISO date>: <account>"` into `round.toml`;
    refuses if the pin moved since `opened` (unless `--regraded`), if the gate is non-zero, or if the
    working tree has unstaged changes under `.gbg/rounds/<round>`. Commit + push (branch from
    `[git]`). The build gate now passes; the docs deploy is unblocked.

**File formats.** `round.toml` (schema `round.schema.json`); lane/verdict files: markdown + one
fenced JSON block validated against `instruments/check-consistency/schema.json`; `hats.json`,
`tally.json`, `ground_truth.json` as today with ids added. **Exit codes** as in D8 throughout.

The other three instruments follow the same skeleton: `bug-hunt` (hunt lanes → reproducers via
`pipeline` → `gbg witnesses fail <round>` → fix → `gbg witnesses pass` → promote by id →
`dismissals.js` → `/audit-changes` over the round's diff → `gbg gate bug-hunt`, which is IT's
`finished.py` nine checks minus the retracted follow-up-hunt terminator, plus PF's stricter
`complete`); `audit-changes` (`audit.js` with required `base`, IT's pin-at-base and test-is-audited
rules, PF's gate staleness with UNCHECKABLE, IT's `verdict_all_clean` and capped-lane report; the
audit is a round, `audit.json` tracked); `check-docs` (surface lanes bank like hats, `gbg scan docs`
is the deterministic tier, `gbg verify` reuses the same act verifier with `lanes` as the roster).

---

## 6. Migration plan per consumer

Common preamble (once): create the platform repo from PF's and IT's current instruments merged per
§7's resolution table; `bin/install.sh` on both hosts; `gbg release 1.0.0`.

### PF (canary) — steps, each ending with `gbg doctor` naming the next red check
1. `gbg init` in PF: writes `.gbg/config.toml` (from a PF template in `contracts/`), the ledger with
   PF's existing exemptions and adjudicated titles converted to ids, `.gbg/hats/` for the two
   mathematicians; renders the G files; pins `test/docs/benchmark/Project.toml`; instantiates the
   three envs; `ENV.LOADS` green.
2. Move rounds: `gbg migrate rounds` copies `.claude/check-docs-2026-09-01`, `.claude/doc-review-checkdocs`
   into `.gbg/rounds/…` with a synthesised `round.toml` (`closed = "migrated: <CLOSED.md account>"`),
   `ROUNDS.*` green. Delete the `.claude/doc-review*` gitignore lines (G block replaces them).
3. `make.jl`: replace the nine lint functions with `DocLints.pre/post`; keep `makedocs(...)`. Build
   must exit 0; `prose_shape.csv` re-baselined once under the unified schema (recorded in the commit).
   `WIRING.MAKEJL` green.
4. `runtests.jl`: `public_surface.jl`, the `@alloc_below` macro, `CountingArray`, the parity engine,
   the oracle-registry engine, the regression loop move to `TestHarness`; frozen tables stay as
   `.toml` baselines; `Pkg.test()` must stay at 9657/143 (a count change is a finding).
   `WIRING.RUNTESTS` green.
5. `CLAUDE.md`: cut the policy sections (≈ 700 lines) and insert the managed block; a diff review
   confirms every cut sentence exists in `policy/*.md` or is package-specific and kept.
6. Delete `.claude/commands/**`, `.claude/hooks/`, `manifest.py`, `MANIFEST.txt`; `settings.json`
   regenerated; `settings.local.json` gitignored. Run each of the four skills in `--dry` mode (the
   protocol's step 1–2 only). `MANAGED.*` green. Commit ⇒ push. `gbg fleet` shows PF at 1.0.0.

### IT
1–6 as PF, plus: IT's engine contributions land in the platform **before** IT migrates (they are
platform work, released as 1.1.0): the operational-claims check, `attack-design.js`, the profile
mechanism, `hats.json`, `finished`'s nine checks, `PARTIAL`/`surviving_class`, `checked[]`/
`candidates_found`, the required `base`. Collapses: `main` → `master` (config value, but R1 says
collapse; one `git branch -m` on each host + `docs.yml` regenerated — owner to confirm); trailer →
versionless; tracked root `Manifest.toml` stays (necessary: unregistered PF dep) until the registry
step; `closure.py` deleted (retracted rule); `rubric_extract.py`'s one-off constants deleted;
`xlink.jl` stays dry-run-only in `Reflection`. Declared deviations (ledger): `DOC.STEER`
(declined, owner-ruled 2026-08-25), `DOC.ADMONITION_TITLE` (bare `!!! note` for asides, owner-ruled),
`DOC.MODULE_MAP` ("deliberately tighter"). Config, not deviation: `[notation] vectors =
"boldsymbol"`, `profile = "core"`, four anchors, `doctest = false`. The `\mathbf` "ban" collapses:
the fleet rule is "`\mathbf` only as the indicator `\mathbf{1}`", which IT's corpus already
satisfies — the recorded IT "PF-parity divergence never dispositioned" closes as *no divergence*.

### SS
The July fork is replaced, not migrated: delete `.claude/commands/**` and `doc-review/`; `gbg init`
from a fresh template; anchors `statistics-theoretician`, `streaming-stability-practitioner`
written as `.gbg/hats/`; `estimand_first` contributed to the platform as a check (MINOR). Collapses
(historic artefacts, owner to confirm): the June `lint_inline_math` (superseded twice); the
symbol/arg **tables** requirement in reports (a PF-era report format); the missing DOI rule
(adopted); the missing cost modes/banking/verifiers/closure (adopted); trailer; `julia = "1.11"` →
`"1.12"` (the floor is untested on the fleet — juliaup has only 1.12.7 — so the claim is currently
unfalsifiable; if the owner keeps it, it stays as config `[julia] channel = "1.11"` with a doctor
check that the channel is installed). Declared deviations: `DOC.ARG_BULLET_BOLD` (SS requires
`- **`arg`**`; PF forbids) — proposed **collapse to PF's form** as an artefact, else a ledger entry;
`API.POSITIONAL` (result-affecting smoothing controls as keywords) — a ledger entry with the reason
"API stability; revisit at the next breaking round".

### CP
`gbg new`-style init: config from a minimal template, `make.jl` seeded with `DocLints`, `Aqua`
via the harness (`persistent_tasks = false` dropped as an artefact unless CP can show why), the
"knobs" register scan will fire five times on `CLAUDE.md` — fixed, not exempted. CP's private dep
via `[sources] url=` (floating) gains a `rev` as part of the same pass.

---

## 7. Resolution table — divergences collapsed vs kept

| Divergence (survey ref) | Resolution | Class |
|---|---|---|
| demotion by content (PF) vs emptiness (IT) — `survey-check-consistency.md:§5.1` | emptiness of `class_surfaces[]` (structured block makes it reachable by the gate) | engine constant |
| staleness mtime (PF) vs self-report (IT) — §5.2 | mtime; the 6-hour coherence bucket dropped (misfired once); IT's search-scoping rule kept beside it | engine constant |
| state/act verdict sets — §5.3 | union (D11) | schema |
| closure gate: untracked pile+`CLOSED.md` vs marker+`closed:` — §5.4 | tracked rounds, per-finding by id, `closed = "<account>"` as the wholesale escape that leaves an artefact | engine |
| roster: hardcoded (PF) vs `hats.json` (IT) — §5.6 | `hats.json` written by a census agent; coverage's ORPHAN kept as the fallback detector | engine |
| `recall.py` unverifiable seeds — §5.6 | PF's: kept in the denominator and printed as UNDEFINED | engine |
| hunt partition territory vs class — `survey-bughunt-auditchanges.md:§4.1` | engine supports `territory\|class\|both`; consumer chooses; the platform records the measured verdict (free readers won) in `catalog/lanes/README` | config enum |
| who writes the witness — §4.1 | IT's reproducer stage + PF's mandatory mechanical re-run (both) | engine |
| round prefix on witnesses — §4.1 | always `<round>-<lane>-NN` (rounds are directories, so collision is structural) | engine |
| `dismissals` `complete` — §4.2 | PF's (dead == 0 && reopened == 0) | engine |
| `witnesses.jl` exit on broken — §4.3 | IT's (broken ⇒ non-zero); pile as argument (PF) | engine |
| audit `base`, pin-at-base, test-in-diff — §4.4 | IT's, required | engine |
| audit lane sets `kind` — §4.4 | IT's `kind∈{code,prose,both}` | engine + args |
| gate staleness — §4.5 | PF's `git diff <audited>..HEAD -- covered` with UNCHECKABLE | engine |
| IT `closure.py` follow-up hunt — §1.2 | deleted (retracted rule; would make "finished" permanently false) | artefact |
| `argcov` exit policy PF triage / IT gate — `survey-checkdocs.md:§4` | triage, with PF's exemption classes counted and IT's Greek/`arg = default` recognition | engine |
| DOI cross-check breadth — §4 | IT's title+decoded-DOI checks + PF's bare-DOI breadth + info direction | engine |
| sentence-opener grep (IT) — §4 | PF's computed script | artefact |
| prose-shape ratchets — `survey-buildlints-hooks-policy.md:§1` | one CSV schema; IT's always-binding caps; PF's page units; IT's structure checks | engine (MAJOR-class for the baseline; re-baselined once per consumer) |
| `\mathbf` — §1 provenance | one rule: only `\mathbf{1}`; no deviation needed | collapsed |
| admonition titles; in-place steer; module-map tightness (IT) — §4 | ledger deviations, owner-ruled | kept, declared |
| bold arg bullets; keyword smoothing controls (SS) — §4 | bullets: collapse (artefact, confirm); keywords: ledger deviation | one each |
| `main`/`master`; trailer text; `.claude` tracking; `settings.local.json` tracking; request-file tracking — §2 | collapse to `master`, versionless trailer, tracked rounds, gitignored local settings, requests as tracked `.gbg/requests/` in the *requester* | artefacts |
| `lint_review_closure`'s U+200B dead path (IT); PF's unquoted `cd ${REPO}` — surveys | gone with the files | artefacts |

---

## 8. How the platform tests itself, and what "provably best" honestly means

**Self-tests (D15):** fixture corpus (every scan and lint must find its listed defect and not its
clean twin); perturbation arms for every gate (coverage, closure, recall, witnesses, audit gate,
demotion, staleness — each arm perturbs a *copy* of a fixture round so the arms keep working when
the real count is zero, PF's `selfcheck` lesson); the four contracts validated and rendered; the
Julia harness against the fixture package; a `catalog/scans.toml` completeness check (every script
under `gbg/scans/` registered — `guards.sh`'s self-check generalised); `gbg selftest` is the
platform's CI and a MAJOR bump's precondition, together with a recall figure on the fixture.

**Entailments (requirement → decision).** These are forced, not chosen:
- R1 + R4 + R7 ⇒ one repo, one version (D1); R1 + R11 ⇒ closed vocabularies (D11); R1 ⇒ the
  default disposition of a difference is *collapse* (D17, §7).
- R2 ⇒ a committed pin (D3), a stamped round (D10/D16), policy copied so its diff is in the
  consumer's history (D12), `doctor --effective` (D5).
- R3 ⇒ exit 2 as a first-class outcome (D8), `ROUNDS.DIR` absent = fail, `hats.json` absent =
  fail, no vacuous gate on a clone ⇒ tracked rounds (D10).
- R4 ⇒ semver with measurement-affecting = MAJOR, `close` refusing a moved pin, `bump` refusing an
  open round (D16).
- R5 ⇒ fixture consumer + perturbation arms + contracts (D15).
- R6 ⇒ stubs not copies (D6), engines by absolute path (D7), harness as a package (D9).
- R8 ⇒ Pkg-fetched pinned copy + versionless shim, no Dropbox dependency for a consumer (D2).
- R9 ⇒ doctor-driven ordered checklist and the canary order (D14, D17).
- R10 ⇒ `instruments/<name>/` as the contract; `gbg new`; catalogues as data (D7, D10 one layout).
- R12 ⇒ anchors in config, never-economised phases in the engine (D18).
- The platform facts ⇒ no plugin as channel (no per-project pin, no workflow shipping), skill
  stubs with `!` injection (D6), Workflow scripts by absolute path (D7), policy by `@` import of a
  local copy rather than an external path (D12).

**Residual judgment calls (not entailed; the owner's):**
1. `.gbg/` vs `.claude/` for consumer state (D5) — either works; the argument is discovery hygiene.
2. Python vs Julia for the orchestration CLI (D8) — startup time vs one language.
3. Tracking rounds in git (D10) — kilobytes of churn in exchange for a non-vacuous gate.
4. Copying policy into consumers vs importing the pinned copy (D12) — a visible diff and no
   approval dialog, at the cost of four hash-checked copies.
5. `[sources]` now vs a private registry now (D2/D3) — the registry is the better end state.
6. Which SS/IT differences are artefacts (§6) — flagged individually for confirmation: `main`,
   SS's 1.11 floor, SS's bold bullets, CP's `persistent_tasks`.
7. Whether `finding.type` should be the *only* extension point, or whether per-package custom
   scans (SS's `\quad.*\quad`, IT's stale-variable names) should be admitted as config-declared
   regex scans under a `[scans.custom]` table with tier fixed to `triage` — proposed **yes**, with
   the tier fixed, because it is data and it is what keeps a domain-specific grep from becoming a
   fork.

"Provably best" here can only mean: every decision above is either entailed by a stated
requirement and the platform's documented constraints (and the entailment is written down), or is
listed as a judgment call with its trade-off. Nothing else is claimed.
