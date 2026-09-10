# Round-1 proposal — the consumer lens

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.


Architect lens: what a session inside a consumer does on day one, how an instrument is invoked and
finds its configuration, the smallest honest footprint, how the shared policy reaches each
`CLAUDE.md`, which recorded deviations survive, the per-consumer migration checklist with a doctor
verifying each step, the doctor and the fleet view, and how a fifth package joins.

Inputs read in the brief's order (00, 01, the four surveys, the platform facts, the theory notes),
PF's "shared instrument package is DEFERRED" block, IT's `INVENTORY.md`, the four repos'
`.claude/` trees, `.gitignore`s, `Project.toml` compat lines and the deviation passages in the three
non-PF `CLAUDE.md`s, plus the current Claude Code docs for memory imports and skills (fetched
2026-09-06). Facts established beyond the surveys and used below:

- `~/.claude/skills/<name>/SKILL.md` is a personal-scope skill visible in every project; personal
  overrides project on a name collision; skills do **not** support `@imports`; a `!`-block that
  exits non-zero **aborts the whole invocation** ("Claude never sees the skill content"), which is a
  fail-closed gate we get for free; `${CLAUDE_PROJECT_DIR}` and `${CLAUDE_SKILL_DIR}` substitute in
  skill content.
- `@path` imports in a project `CLAUDE.md` accept `~/…` and absolute paths, nest four deep, skip
  code spans, and show a **one-time approval dialog per project** when the path resolves outside the
  working directory; declining disables the imports silently and the dialog does not return.
  Nothing in the docs says what a space in the path does, so the design never puts one there.
- Block-level HTML comments in `CLAUDE.md` are stripped before injection — a managed-block marker
  written as an HTML comment costs no context.
- `~/.claude/` on this host holds no `skills/`, no `rules/`; `~/.claude/settings.json` has no hooks;
  the only registered marketplace is Anthropic's. Both hosts are `/home/grigory` with the same
  Dropbox layout (`autoMemoryDirectory` in every `settings.local.json` is `~/Dropbox/Research and
  Teach/AI Helpers/claude-memory/<Package>`, identical on both machines by the recorded memory rule).
- CP has `.claude/settings.local.json` and nothing else; SS has a July-vintage `check-consistency/`
  plus two command files and no `test/regressions/`; IT is on `main`; SS declares `julia = "1.11"`
  while `juliaup` here has only 1.12.7.

---

## 0. The shape in one paragraph

One repository, **GBGCodingTools**, cloned once into the Dropbox tree beside the memory directory and
reached on every machine through a space-free symlink `~/.gbg/tools`. It contains a Python 3.12
stdlib CLI `gbg` (doctor, fleet, init, sync, preflight, guards, round, gate, witnesses, recall,
bump), a Julia package `GBGCodingTools.jl` (the docs lints and the test harnesses), the Workflow
scripts, the skills, the hat catalogue, the seed catalogue, the JSON schemas, the policy prose, a
fixture consumer, and its own tests. A consumer holds **one directory, `.gbg/`** — a hand-written
`config.toml`, an exemptions ledger, its domain hats, its tracked rounds — plus five wiring lines it
cannot avoid (an `@import` in `CLAUDE.md`, one call in `docs/make.jl`, one call in
`test/runtests.jl`, one `[sources]` entry each in `test/Project.toml` and `docs/Project.toml`) and
the directory `test/regressions/`. The skills are installed once per machine into
`~/.claude/skills/` as symlinks into the checkout, so a consumer carries **no** skill, command,
script, hat, verifier or lint of its own. Every instrument starts with `gbg preflight`, which
refuses to run on a mismatched pin, a dirty checkout, an invalid config or a missing round marker,
and prints the exact `Workflow(...)` call with its `args`; every instrument ends with
`gbg round close`, which the docs build re-checks through `gbg round gate`. The doctor is the
adoption path: a consumer is migrated when `gbg doctor` is green, and `gbg fleet` shows all four.

---

## 1. Decision points D1–D19

Each: **(a)** the choice, **(b)** the requirement and the evidence forcing it, **(c)** the
alternatives and why each is dominated. Requirement ids are R1–R12 from `00-requirements-draft.md`.

### D1 — Unit of distribution

**(a)** One git repository `GBGCodingTools` holding everything: the Julia package at the root
(`Project.toml`, `src/`), `bin/gbg` (Python), `workflows/`, `skills/`, `catalog/`, `schemas/`,
`policy/`, `templates/`, `fixture/`, `tests/`. One version number covers all of it.

**(b)** R7 ("all versioned together"), R4 (a round records *the* instrument version — impossible if
the Julia lints, the JS lanes and the Python gates carry three versions), R2 ("what changed in the
instrument between two rounds" must be one diff). Evidence that split versions rot: PF's
`lint_review_closure()` is declared a "twin" of `verify-fixes.js` and desynced for a day
(`survey-buildlints-hooks-policy.md` §1, `PF:make.jl:388–389`; `survey-checkdocs.md` §7 item 8); PF's
`check-docs/MANIFEST.txt` lists 3 of 6 scripts (`survey-checkdocs.md` §4).

**(c)** *Three repos (Julia pkg / plugin / CLI)* — three pins per consumer, three CHANGELOGs, and the
twin problem reappears across repos; dominated on R4. *Julia package only, everything else vendored
per consumer* — is the status quo that drifted 1.5–2× (`INVENTORY.md` "Sizes"); dominated on R1.

### D2 — Delivery to a machine

**(a)** A git clone of the tools repo at `~/Dropbox/Research and Teach/AI Helpers/GBGCodingTools`
(fleet-synced by Dropbox, mirrored on private GitHub like every sibling), plus a per-machine symlink
`~/.gbg/tools → <that clone>` created by `gbg install`. The symlink is the only path the consumers,
the skills, the `@import` line and the Workflow `scriptPath` ever name.

**(b)** R8 (per-machine install reproducible; two machines) and the platform facts: `@import` paths
and skill `!`-blocks are text, so they need a path that is identical on both hosts and contains no
space — the Dropbox path has two. `~/.gbg/tools` is identical on both hosts (`/home/grigory` on each)
and space-free. Delivery by Dropbox needs no second sync step, which the surveys show is where
sibling clones went stale (SS's `inspiration/` clone is a **July** snapshot,
`survey-buildlints-hooks-policy.md` §3).

**(c)** *Claude plugin marketplace install* — plugins cannot ship Workflow scripts and cannot be
pinned per project (`facts-claude-code-platform.md` §1, §2), and the install copies the plugin out of
our control; dominated on R4/R7. *Per-machine plain clone at `~/.gbg/tools` (not in Dropbox)* —
reproducible, but adds a `git pull` step per machine that nothing forces; the survey's evidence
(SS's July clone, CP's 1–2-days-behind clone) is that unforced sync steps are skipped. Kept as the
documented route for a third machine. *Julia registry (LocalRegistry)* — serves the Julia half only
and does nothing for skills, workflows and policy; deferred, see D3.

### D3 — Binding from a consumer to the tool

**(a)** Three bindings, each explicit, none discovered:
1. `.gbg/config.toml` → `[tools] version = "1.3.0"` (the pin).
2. `test/Project.toml` and `docs/Project.toml` → `[sources] GBGCodingTools = {url =
   "git@github.com:GrigorySarnitsky/GBGCodingTools.jl.git", rev = "v1.3.0"}` (the Julia half,
   the same route IT and CP already use for PF and SS).
3. `CLAUDE.md` → `@~/.gbg/tools/policy/GBG-POLICY.md` (the policy prose); skills and Workflow
   scripts are reached by absolute path under `~/.gbg/tools/` printed by `gbg preflight`.

`gbg doctor` requires all three to name the same version (`PIN-01`, `PIN-02`).

**(b)** R2 (which version measured this round — the pin is committed in the consumer and stamped
into `round.toml`), R4 (a bump is a visible consumer commit — the pre-commit `rev` model,
`theory-patterns.md` §2a), R8 (CI on GitHub has no `~/.gbg`, so the Julia half must resolve from a
URL; `IT:docs.yml` and `CP:CI.yml` already carry `GBG_DEPS_TOKEN` for exactly this,
`survey-buildlints-hooks-policy.md` §7).

**(c)** *`[sources] path = "/home/grigory/.gbg/tools"`* — breaks CI and a fresh clone; dominated on
R8. *Environment variable `GBG_TOOLS`* — a fourth layer of config that no committed artefact
records; dominated on R2 (`theory-patterns.md` §7b, no layering). *Git submodule* — Dropbox does
not carry `.git` state reliably and every pull needs a second step (`theory-patterns.md` §2c).
*Vendored copy* — the status quo.

### D4 — Version pinning

**(a)** **Fleet-wide single version as policy, per-consumer pin as the record.** The checkout at
`~/.gbg/tools` is at one tag; each consumer's `[tools] version` must equal it; an upgrade is a sweep
(`gbg bump v1.4.0` run in each consumer the same sitting, canary PF first). Divergence is detected
by `gbg doctor` (`PIN-01/02`, exit 1) and shown by `gbg fleet`. A bump is **refused** while the
consumer has an open round (`gbg round status` non-empty) unless `--regrade`, which reopens the
round's verification under the new version and records both versions in `round.toml`.

**(b)** R4 verbatim ("a round cannot close under a different version than it opened with"); R1
("SAME version"); Google's one-version rule and its approximation for multiple repos
(`theory-patterns.md` §2d). The Dropbox-synced checkout makes a per-consumer *checkout* impossible
anyway (a `git checkout v1.2.0` on one machine flips the other), so the honest statement is one
version per fleet.

**(c)** *Per-consumer worktrees `~/.gbg/versions/<tag>/`* — supports two versions at once, which the
one-version rule forbids and which nobody needs inside a same-day sweep; adds `git worktree`
metadata with absolute paths inside Dropbox; dominated on complexity with no requirement behind it.
*No pin, checkout is the truth* — loses R2's answer on a clone and the visible bump commit.

### D5 — Config

**(a)** `.gbg/config.toml`, TOML, hand-written, **one file, no layering, no env overrides**; read by
Python (`tomllib`), Julia (`TOML` stdlib) and, through `gbg preflight`, by the Workflow scripts as
`args`. Validated against `schemas/config.schema.json` (required keys, closed enums,
`additionalProperties: false`) by a small stdlib validator in `bin/gbg` — an unknown key is an error,
a missing required key is an error, and every default is materialised into the file by `gbg init`
so the file is complete on its own. Machine facts (`hostname`, GPU vendor, thread count) are read
from the machine, never from config. Schema in §3.

**(b)** R3 (no config → fail), R11 (one schema), R12 (anchors named per package), the survey's
classification of every package-specific datum as **(a) config data** (`survey-checkdocs.md` §3,
`survey-check-consistency.md` §4, `survey-bughunt-auditchanges.md` §3 — "overwhelmingly (a)");
`theory-patterns.md` §7 (no layering; verdict vocabularies not configurable).

**(c)** *Under `.claude/`* — ties a file read by `make.jl`, `runtests.jl` and Python to Claude's
directory, and the consumer footprint would then straddle two directories; `.gbg/` holds config,
ledger, hats, rounds and requests in one place. *JSON* — no comments, hostile to hand editing;
*YAML* — no stdlib parser in either runtime. *Layered defaults/local/env* — the transparency trap
(`theory-patterns.md` "Traps").

### D6 — Skills

**(a)** Skills live in the tools repo (`skills/<name>/SKILL.md`) and are installed **per machine** as
symlinks `~/.claude/skills/gbg-<name> → ~/.gbg/tools/skills/<name>` by `gbg install`
(fallback if a symlinked skill dir is ever not picked up: `gbg install --copy`, header-stamped,
hash-checked by `ENV-03`). Names carry the `gbg-` prefix: `/gbg-check-docs`,
`/gbg-check-consistency`, `/gbg-bug-hunt`, `/gbg-audit-changes`, `/gbg-doctor`, `/gbg-round`.
Every instrument skill has `disable-model-invocation: true` (the consent gate: an instrument runs
only when the user types it) and opens with a fenced `!` block:

```
```!
"$HOME/.gbg/tools/bin/gbg" preflight check-docs --project "$CLAUDE_PROJECT_DIR" --strength "$0"
```
```

whose non-zero exit aborts the invocation before the protocol text is even shown. The skill body is
the protocol (phases, what to bank where, when to stop) and quotes the `Workflow(...)` call verbatim
from preflight's output. A consumer holds **no** skill or command file.

**(b)** R6 (nothing duplicated), R3 (fail-closed: preflight failing = no run), R1 (the same protocol
text in every consumer — today PF/IT/SS carry three hand-adapted `check-docs.md`s of 400/296/200
lines, `survey-checkdocs.md` §1), the consent gate (PF `CLAUDE.md` "unasked, run ONLY `Pkg.test()`").
Personal-scope skills are the one Claude Code mechanism that reaches every project on a machine
without a per-project file and without a plugin.

**(c)** *Generated per-consumer `.claude/commands/*.md` stubs* — one more managed file per instrument
per consumer, and the stubs are exactly what got edited in place (`survey-checkdocs.md` §7 item 20:
inline "readable source of truth" copies rot). *Plugin skills (`/gbg:check-docs`)* — cleaner
namespace, but plugins cannot ship the Workflow scripts, cannot be pinned, and are installed by copy
out of sight; the `gbg-` prefix buys the namespace we need. *Bare names `/check-docs`* — a personal
skill silently shadows a consumer's leftover `.claude/commands/check-docs.md`, so a half-migrated
consumer would run the new instrument without knowing; the prefix makes the leftover visible and the
doctor flags it (`LEG-01`).

### D7 — Workflow scripts

**(a)** One generic engine per instrument phase, in the tools repo (`workflows/check-docs/lanes.js`,
`workflows/check-consistency/{panel,verify,verify-fixes}.js`, `workflows/bug-hunt/{hunt,dismissals}.js`,
`workflows/audit-changes/{audit,attack-design}.js`), parameterised **only** by `args`. `args` is a
single JSON object built by `gbg preflight` from config + catalogue: `{tools_version, project,
package, description, absences, surfaces, modules, hats:[{key, persona, tier, substrate}],
anchors, strength, pile, adjudicated, round_id, julia, branch}`. Hat and lane catalogues are **data**
in `catalog/hats/*.md` (frontmatter `key, tier, kind: generic|domain, substrate, instruments`) and a
consumer's domain hats are data in `.gbg/hats/*.md` with the same frontmatter; preflight validates
both against `schemas/hat.schema.json` and refuses a hat whose persona names another package.

**(b)** R7 (Workflow scripts have no filesystem and take config only via `args` — the survey's
execution-model finding in all three instruments), R11 (the returned object's schema is the
engine's), and the survey's (a)/(c) split: `panel.js`'s 22 package hits sit inside persona strings
and one preamble (`INVENTORY.md` "The split"), IT's `lanes.js:51` bakes a dated rename note into a
persistent prompt (`survey-checkdocs.md` §3, (c)).

**(c)** *Per-consumer scripts* — the drift generator. *Hats as code inside the JS* — the roster then
lives in three hardcoded arrays that `coverage.py` has to guard (`survey-check-consistency.md` §5.6);
IT's `hats.json` shape (roster emitted by the panel, read by the verifiers) is kept, and the roster
*input* comes from data.

### D8 — Deterministic helpers

**(a)** One CLI, `bin/gbg`, Python 3.12 **stdlib only** (`tomllib`, `json`, `hashlib`, `subprocess`,
`argparse`; no pip), invoked as `~/.gbg/tools/bin/gbg <command> [args]`. It calls Julia helpers
(`julia --startup-file=no --project=<consumer>/test …`) for anything needing reflection. Exit-code
contract, uniform: **0** clean, **1** a finding or a failed gate, **2** the harness could not decide
(bad usage, unreadable config, uncheckable diff, dead lane, empty pile). Two tiers inside every
scanning command: `hard` (must be empty; contributes to exit 1) and `triage` (printed in full,
never fails). Output is never truncated.

Subcommands: `install`, `doctor`, `fleet`, `init`, `sync`, `preflight`, `guards`, `round`
(`open|status|close|gate`), `coverage`, `recall`, `witnesses`, `audit-gate`, `manifest`, `bump`,
`schema`.

**(b)** R7, R3, `survey-checkdocs.md` §7 items 1–3 (never truncate; hard vs triage; the missing case
fails) and item 20; `theory-patterns.md` §4d (`brew doctor` shape). Python because the survey's
zero-coupling scripts are already mostly Python (`gate.py`, `coverage.py`, `recall.py`,
`manifest.py`) and `python3` 3.12 is on both hosts; stdlib-only because there is no package manager
step on either host and a `pip install` is one more unforced sync.

**(c)** *Loose scripts as today* — each carries its own root-finding, exit policy and `head`
temptation. *A Julia CLI* — 5–15 s startup per invocation for text scans, and the `!`-block preflight
runs on every skill invocation. *Bash* — `guards.sh` is the model for the scan tier, but the schema
validation, JSON args and hashing want a real language.

### D9 — Julia-side library

**(a)** `GBGCodingTools.jl` at the repo root, `julia = "1.12"` compat, consumed as a **test and docs
dependency only** (never `[deps]` of the consumer) through `[sources]` (D3). Exports:
- `lint_docs(config_path; build_dir)` — every build lint from the union of PF and IT
  (`lint_inline_math`, `lint_notation_variants` with the `\mathbf{1}` carve-out, `lint_swallowed_escapes`,
  `lint_retired_claims`, `lint_api_page_structure`, `lint_prose_shape` with IT's always-binding caps
  **and** PF's page units, `lint_ai_banner`, `lint_rendered_markup` after `makedocs`), each taking
  its surfaces from the config, plus `closure_gate()` which shells `gbg round gate` (one predicate,
  one place — D10).
- Test harnesses: `@alloc_below`, `CountingArray`/`Traffic`/`audit`, `method_parity`,
  `package_operations` (ownership-derived public surface), `oracle_registry`,
  `include_regressions!(@__DIR__)`, `display_gate` (with IT's `UnionAll` fix).
- `read_config()` — the same TOML the CLI reads.

**(b)** R6 (engine out of the consumer; frozen baselines stay in), `survey-buildlints-hooks-policy.md`
§5 (the harnesses are PF-only or copies-with-drift: the display gate's `UnionAll` fix never came
back, the regression loop's spelling diverged), `theory-patterns.md` §8e (Aqua's consumption shape).
Compat 1.12 because CP calls it "the fleet's floor", PF raised to 1.12 on 2026-07-19 for a measured
compile-time reason, and this host has no 1.11; SS's `1.11` is collapsed (D17).

**(c)** *Separate Julia repo* — D1. *Consumers keep their own `make.jl` lints and only the harnesses
move* — the lint matrix (`survey-buildlints-hooks-policy.md` §1) is where three packages have 9/4/1/0
lints; that is the uniformity gap R1 exists for.

### D10 — Piles and rounds

**(a)** One layout for every instrument, **tracked**:

```
.gbg/rounds/<instrument>/<YYYY-MM-DD>[-<n>]/
  round.toml           opened, tools_version, tools_sha, config_sha256, model, strength, hats_run,
                       closed = "" | "<date>", account = "" | "<why>", regraded_from = ""
  NN-<lane>.md         banked lane/hat output (agents Write these; schema §4)
  closure/NN-<lane>.md verify-fixes verdicts;  state/NN-<lane>.md  blind-verify verdicts
  witnesses/*.jl       (bug-hunt)      ground_truth.json (seeded rounds)   latest.json (audit)
  CLOSED.md            the wholesale escape — an account, never a rubber stamp
```

A round is **open** when `round.toml` has an empty `closed`. `gbg round open <instrument>` writes
the marker (refusing on a dirty or untagged checkout unless `GBG_DEV=1`, which stamps
`tools_version = "dev+<sha>[-dirty]"` and makes the round **unclosable** except by `CLOSED.md`);
`gbg round gate <dir>` is the per-finding closure predicate (every `## Finding N` HONORED with a
non-empty `class_surfaces` **array** in the verdict's fenced JSON block, or its title in
`.gbg/adjudicated.md`, or a `CLOSED.md` with an account; mtime staleness; dead-lane rule);
`gbg round close` runs the gate and stamps `closed`. `make.jl`'s `closure_gate()` calls
`gbg round gate --all` and fails the build on any open round older than the config's
`rounds.max_open_days` (default 14) or any closed round whose gate no longer passes. Scratch that
must not be tracked (`docs/build` copies, manuscripts) goes to `.gbg/scratch/` (gitignored).

**(b)** R2 (committed artefacts), R3 (absent pile → fail: the gate takes the round directory it
expects and exits 2 when it is missing, `INVENTORY.md` constraint 2), the survey's judgment that PF's
per-finding gate and IT's tracked marker each close the other's hole (`survey-check-consistency.md`
§5.4), the "must become a script both builds call" constraint (`INVENTORY.md` constraint 1), and
the demotion-by-emptiness ruling (`survey-check-consistency.md` §5.1 — hence the structured
`class_surfaces` array the gate reads instead of PF's ≥60-character string).

**(c)** *Untracked piles + tracked marker (IT)* — passes vacuously on a clone for every finding
(`INVENTORY.md`). *Untracked piles + `CLOSED.md` (PF)* — same on a clone. *Per-instrument layouts* —
`coverage.py` and the gate would need one parser each; R11.

### D11 — Finding and verdict schemas

**(a)** `schemas/*.schema.json`, platform constants, **not configurable**: `finding` (`{type,
severity: blocker|major|minor|nit, confidence, title, locations[], contradicts, description,
resolution_hint}`; `type` is an open string), `state-verdict` = `PRESENT|PARTIAL|ABSENT|UNCLEAR|
NOT-A-DEFECT` (+ `surviving_class` on PARTIAL), `act-verdict` = `HONORED|LINE-ONLY|NEW-DEFECT|
SCOPE-CREEP|UNDONE|LAUNDERED|ADJACENT|INSERTED` (+ `class_surfaces: string[]`, `question`),
`hunt` (`observed: FAILS|PASSES|ERRORS|NOT-WRITABLE`; adjudication `CONFIRMED|WITNESS-WRONG|
NOT-REPRODUCED|ALREADY-COVERED|NOT-A-DEFECT|EVIDENCED`, the last only for `kind = architecture`),
`dismissal` = `DISMISSAL-SOUND|UNSAFE|DISMISSAL-WRONG`, `audit` (`severity: serious|notable|minor`,
`justified`, `previously_worked`, `checked[]`, `candidates_found`, `disposition` starting
`fixed|refused|escalated`, refusal ≥ 24 chars), `round`, `config`, `hat`, `exemption`. Extension
policy: a consumer may add fields **only** under an `x_<package>` object; a script ignores them; the
validator rejects any other unknown key. Changing an enum is a MAJOR release (D16).

**(b)** R11 verbatim; `survey-bughunt-auditchanges.md` §5 item 1 and `INVENTORY.md` ("a SCHEMA
divergence, not wording"); `theory-patterns.md` §5e. The unions above are the survey's own judgments:
IT's `PARTIAL`, IT's `ADJACENT/INSERTED`, PF's `ALREADY-COVERED` and `previously_worked`, IT's
`checked[]/candidates_found`.

**(c)** *Per-package vocabularies* — the four diverge inside the schema instead of outside it
(`theory-patterns.md` "Traps"). *Free-form markdown only* — `coverage.py` already regex-parses two
vocabularies; a fenced JSON block per finding/verdict in the banked markdown is what lets a stdlib
script read them without a second parser.

### D12 — Rubric and policy prose

**(a)** `policy/` in the tools repo, one entry file `GBG-POLICY.md` importing `docstrings.md`,
`math.md`, `citations.md`, `instruments.md`, `verification.md`, `working-agreements.md` (four hops
suffice). A consumer's `CLAUDE.md` carries exactly one import line **and** a managed block rendered
by `gbg sync` from config:

```
<!-- gbg:begin managed (do not edit; `gbg sync` rewrites) -->
@~/.gbg/tools/policy/GBG-POLICY.md
## GBGCodingTools — this package's parameters and declared deviations
- Package: GBGStreamingStatistics; identity sentence: **estimand first** (`rubric.leading_identity`).
- Deviation `docs.positional-result-affecting` (ruled 2026-06-24, reviewed 2026-09-06): smoothing
  controls are keywords by the object → query → smoothing → modifiers convention …
<!-- gbg:end -->
```

The block is the session's view of *what this package deviates in and why*; the battery reads the
same facts from `config.toml`, so prose and check cannot disagree. The first session in each
consumer on each machine sees the external-import approval dialog once; accepting it is a migration
step (`MIG-9`), and `/gbg-doctor` asks the session to quote the policy sentinel line ("GBG policy
v1.3.0 loaded") so a declined import is caught in-session — the missing case fails.

**(b)** R1 (differences are declared config or findings), R2 ("what does this package deviate in
and why" from a committed artefact), `survey-buildlints-hooks-policy.md` §4 (the rubric is
triplicated by hand-adaptation, PF ≈ 687 policy lines, and *quadruplicated* inside IT:
`CLAUDE.md`, `check-docs.md`, `lanes.js` PREAMBLE, `lint_docstring_shape`).

**(c)** *`.claude/rules/gbg → ~/.gbg/tools/policy` symlink* — documented as supported and would skip
the dialog, but a symlink inside a Dropbox-synced repo has undocumented sync behaviour (Dropbox may
materialise it as a directory on the other host, which git then sees as a tree replacing a link);
the `@import` line is plain text and deterministic. *`~/.claude/CLAUDE.md` import* — no dialog, but
applies to every project on the machine (the Dropbox tree has 26 unrelated folders) and is
per-machine, unsynced. *Copying the policy into each `CLAUDE.md`* — the status quo.

### D13 — Scaffolding and managed files

**(a)** Four classes, each named in `.gbg/managed.json` (generated by `gbg sync`, sha256 per file):
- **config** (hand-owned, schema-validated): `.gbg/config.toml`.
- **generated-managed** (header-stamped, hash-checked, rewritten by `gbg sync`, never hand-edited):
  the `CLAUDE.md` managed block, the `.gitignore` managed block, `test/regressions/README.md`,
  `.gbg/managed.json`, the `[sources]`/`[deps]` lines the doctor checks by parsing.
- **seeded-once-then-owned**: `.gbg/exemptions.toml`, `.gbg/adjudicated.md`, `.gbg/hats/*.md`,
  `.gbg/seeds.toml`, `test/regressions/` (the directory), the required lines in `docs/make.jl`
  and `test/runtests.jl` (inserted by `gbg init`, thereafter checked by grep — `WIRE-02/03`).
- **tracked-pile**: `.gbg/rounds/**`, `.gbg/requests/*.md`.

Nothing is three-way merged; a managed file with a hash mismatch is `MODIFIED` (fail) and one
whose template changed in the pinned version is `STALE` (fail until `gbg sync`).

**(b)** R6, R9 (each step verifiable), `theory-patterns.md` §3c (header + hash beats merge for files
the consumer must not touch) and §3a (`_skip_if_exists` is the name of the seeded-once class).

**(c)** *Copier-style three-way merge everywhere* — invites edits to rendered protocol text, the
disease. *A managed `docs/make.jl` stub* — tempting, but the four `make.jl`s carry genuinely
different Documenter options (IT's `DocumenterInterLinks`, PF's `size_threshold_ignore`, IT's
`doctest = false`); a required line is the honest round-1 contract, a stub is a round-2 option once
those options are config.

### D14 — Doctor and conformance

**(a)** `gbg doctor [--project P] [--deep] [--json]`: read-only, stable check ids, one line per
check `OK|WARN|FAIL|SKIP(reason)|EXEMPT(reason)`, exit 1 on any FAIL, 2 if it could not read the
config. Exemptions come only from `.gbg/exemptions.toml` (`[[exemption]] check = "WIRE-02" reason
= "…" recorded = 2026-09-06 reviewed = 2026-09-06`); the doctor prints them as `EXEMPT` and fails
an exemption whose `reviewed` is older than 365 days. `gbg fleet` runs the doctor over every entry
of `~/.gbg/tools/fleet.toml` and prints the scorecard. Full check list in §7.

**(b)** R9 (doctor per step), R1 (a difference is config or a finding), `theory-patterns.md` §4a/4d.

**(c)** *A CI check* — CI is manual-only fleet-wide by cost policy; the doctor runs locally and in
every skill preflight. *Exemptions inline in `CLAUDE.md`* — the do-not-re-flag lists are what rot
(the closed-items paragraphs in PF's `CLAUDE.md`).

### D15 — Self-testing of the tool

**(a)** `fixture/GBGFixture/` — a toy Julia package (three modules, docstrings with the seed
corpus's defect classes planted at known positions, `docs/`, `test/` with `regressions/`, a
`.gbg/config.toml`, two domain hats). `tests/` (Python `unittest`) runs: schema validation of every
catalogue entry; `gbg doctor` on the fixture must be green and, after each of 12 scripted
perturbations (delete the import line, edit a managed file, bump the pin, open a stale round, …),
must fail with the expected id; every gate's selfcheck (`gbg round gate` over a fixture round with a
missing verdict, a HONORED-in-a-demotion-note, an empty `class_surfaces`, a stale mtime — each must
fail); `gbg recall --selftest` (PF's arms A–D on built fixtures); `gbg witnesses` over a fixture pile
with one failing, one passing, one erroring witness (exit 1, and the erroring one reported apart);
Julia `Pkg.test()` of the library against the fixture (`lint_docs` finds exactly the planted
defects; the harness macros). The tools repo's CI runs on push (minutes, not the 33-minute matrix).

**(b)** R5 ("a check that cannot fail is not a check"), `survey-check-consistency.md` §6 items 15–17,
`survey-checkdocs.md` §7 item 4.

**(c)** *Testing against a real consumer* — seeds would land in real docs (the recorded seed/closure
contradiction); the fixture dissolves it (`theory-patterns.md` §6b).

### D16 — Instrument change discipline

**(a)** Semver tags `vMAJOR.MINOR.PATCH`, `CHANGELOG.md` with a "What this changes about
measurements" line per entry. **MAJOR**: any change to a verdict vocabulary, demotion predicate,
gate rule, scoring, seed catalogue, or config schema that removes/renames a key. **MINOR**: a new
lint, hat, check id, optional config key. **PATCH**: everything else. Every round stamps
`tools_version` and `tools_sha`; a rate is comparable only across rounds with equal MAJOR.MINOR.
Mid-round: `gbg bump` refuses with an open round; `--regrade` re-runs verification only, never the
lanes, and records `regraded_from`. An instrument edit made from inside a consumer session is made
in `~/.gbg/tools` on `master`, committed and tagged there, and reaches the consumer by a bump
commit — never as a consumer edit.

**(b)** R4; the freeze rationale (`INVENTORY.md` "Instrument freeze — 2026-08-27"; PF's round 3→4
54.8→96.8 % uninterpretable); `theory-patterns.md` §2e, §5e.

**(c)** *Calendar versions* — say nothing about measurement compatibility. *No tags, pin by SHA* —
loses the MAJOR signal.

### D17 — Migration

**(a)** Order **PF → IT → SS → CP**. PF first because it is the canary (strictest suite, origin of
most engines, both closure mechanisms half-present) and because the tools repo is seeded from PF's
and IT's scripts, so PF's migration is where the union is proven. IT second because every recorded
behavioural divergence is PF-vs-IT and must be resolved there. SS third: a July fork, so almost
everything is delete-and-adopt. CP last and cheapest: nothing to delete. Per-consumer checklist and
the deviation rulings in §5.

**(b)** R9; `theory-patterns.md` §6c (canary); the surveys' inventories (CP: no instruments; SS: no
scripts; IT: 33 files).

**(c)** *All four in one sweep* — no canary. *CP first because it is empty* — proves nothing about the
union and would freeze an engine untested on the two real corpora.

### D18 — Model and cost policy

**(a)** Encoded in the **engines**, not config: economy is the default; hats with `tier = economy`
run on the platform constant `economy_model = "sonnet"`; hats with `tier = anchor` run on the session
model; verification, consolidation, adjudication and the fix phase are never economised; `strength =
"full"` is a skill argument (`/gbg-check-consistency full`), never a config key. A consumer names
its domain anchors in config (`[check_consistency] anchors = [...]`, each a key in `.gbg/hats/`), and
preflight refuses fewer than one anchor. Generic hats and their tiers come from the catalogue.

**(b)** R12 verbatim; PF's cost-mode paragraph ported verbatim to IT (`survey-checkdocs.md` §1);
IT's `audit.js` ignoring `strength` while PF honours it (`survey-bughunt-auditchanges.md` §4.4) —
one behaviour, in one place.

**(c)** *Model ids in config* — the four drift by editing a string.

### D19 — Name

**(a)** **`GBGCodingTools`** — the owner's working name, kept. Julia package `GBGCodingTools.jl`,
CLI `gbg`, skills `gbg-*`, consumer directory `.gbg/`.

**(b/c)** The package is broader than the four review instruments — it also carries the policy
prose, the doctor, the scaffolding and the test harnesses — so "instruments" (the theory note's
choice) names a part for the whole; "coding tools" names the whole, and the word *instrument* stays
free for the four things the corpus already calls instruments.

---

## 2. Repository layouts

### 2.1 The tools repo `GBGCodingTools`

```
GBGCodingTools/
  Project.toml                 Julia package GBGCodingTools.jl (name, uuid, version = the tag)
  VERSION                      the same version string, read by `gbg` without Julia
  CHANGELOG.md                 per release: what changed, and what it changes about measurements
  fleet.toml                   the consumers: name, path under ~/Dropbox/Research and Teach, github
  bin/gbg                      the CLI (python3, stdlib only)
  gbg/                         its modules: config.py schema.py doctor.py fleet.py init.py sync.py
                               preflight.py guards.py rounds.py gate.py coverage.py recall.py
                               witnesses.py audit_gate.py manifest.py bump.py
  src/GBGCodingTools.jl        docs lints, test harnesses, read_config (Julia)
  src/lints/*.jl               one lint per file, each a function (config) -> findings
  src/harness/*.jl             alloc_below.jl counting_array.jl method_parity.jl public_surface.jl
                               oracle_registry.jl regressions.jl display_gate.jl
  workflows/<instrument>/*.js  the Workflow scripts (args-only; header states the args schema)
  skills/<name>/SKILL.md       gbg-check-docs, gbg-check-consistency, gbg-bug-hunt,
                               gbg-audit-changes, gbg-doctor, gbg-round
  catalog/hats/*.md            generic hats (frontmatter: key, tier, kind, substrate, instruments)
  catalog/lanes/*.toml         check-docs surface lanes, bug-hunt territory templates, audit lanes
  catalog/seeds/*.toml         seed-defect classes (mechanism); anchors are per consumer
  schemas/*.schema.json        config, hat, exemption, round, finding, verdicts, hunt, audit
  policy/GBG-POLICY.md         the entry file a consumer imports (+ docstrings.md math.md
                               citations.md instruments.md verification.md working-agreements.md)
  templates/                   config.toml.tmpl, CLAUDE-block.md.tmpl, gitignore-block.tmpl,
                               regressions-README.md, make.jl.snippet, runtests.jl.snippet
  fixture/GBGFixture/          the toy consumer (planted defects, .gbg/config.toml, hats)
  tests/                       python unittest: schemas, doctor perturbations, gate selfchecks,
                               recall selftest, witnesses runner, manifest
  test/runtests.jl             Julia tests of the library against the fixture
  docs/                        the tools' own docs (how to adopt, check ids, schema reference)
  .github/workflows/ci.yml     on push: tests/ + Pkg.test(); minutes
```

### 2.2 The consumer footprint (every file, with its class)

```
<Consumer>/
  CLAUDE.md                          hand-owned; contains ONE managed block          [generated block]
  .gitignore                         hand-owned; contains ONE managed block (.gbg/scratch/) [generated block]
  .gbg/config.toml                   the config                                        [config]
  .gbg/managed.json                  hashes of managed files + pin (gbg sync)          [generated-managed]
  .gbg/exemptions.toml               doctor exemptions, reason + reviewed date         [seeded-once-then-owned]
  .gbg/adjudicated.md                per-finding do-not-re-flag entries (title-keyed)  [seeded-once-then-owned]
  .gbg/hats/<key>.md                 domain hats and anchors                           [seeded-once-then-owned]
  .gbg/seeds.toml                    the package's seed anchors (text positions)       [seeded-once-then-owned]
  .gbg/rounds/<instr>/<date>/...     banked rounds, verdicts, witnesses, latest.json   [tracked-pile]
  .gbg/requests/to-<PKG>-<date>.md   cross-package requests (tracked in the requester) [tracked-pile]
  .gbg/scratch/                      manuscripts, docs/build copies, temp piles        [gitignored]
  docs/make.jl                       hand-owned; must call GBGCodingTools.lint_docs   [seeded line]
  docs/Project.toml                  hand-owned; [deps]+[sources] GBGCodingTools       [checked lines]
  test/runtests.jl                   hand-owned; must call include_regressions!        [seeded line]
  test/Project.toml                  hand-owned; [deps]+[sources] GBGCodingTools       [checked lines]
  test/regressions/README.md         the promotion contract                            [generated-managed]
  test/regressions/*.jl              promoted witnesses (unchanged, provenance header) [tracked-pile]
  .claude/settings.local.json        autoMemoryDirectory (already present, untouched)  [outside the tools]
```

Deleted from every consumer by the migration: `.claude/commands/**` (all instrument `.md`s, script
dirs, `manifest.py`, `MANIFEST.txt`, IT's `INVENTORY.md` after its content moves to the tools
docs), `.claude/doc-review*`, `.claude/doc-review-adjudicated.md` (moved to `.gbg/adjudicated.md`),
`.claude/review-rounds/`, `.claude/audit-changes/`, `.claude/bug-hunt/` (ledger and open-defects
move to `.gbg/rounds/bug-hunt/`), every `lint_*` function body in `docs/make.jl`, `docs/*.csv`
shape baselines (regenerated under `.gbg/baselines/prose_shape.csv` by the shared ratchet), the
policy prose sections of `CLAUDE.md` that the imported files now carry. PF's `WORK_QUEUE.md`/Stop
hook is PF-local workflow, not an instrument; it stays in PF and is out of scope.

---

## 3. Config schema — `.gbg/config.toml`

Rendered from `schemas/config.schema.json`; `gbg schema config` prints it with every default.
`R` = required. Unknown keys are errors. PF's and SS's real differences are expressible; what is
deliberately **not** configurable follows the table.

```toml
[tools]
version = "1.3.0"                                  # R  the pin (must equal the checkout tag)
schema  = 1                                        # R  config schema version

[package]
name        = "GBGStreamingStatistics"             # R
description = "Streaming (one-pass, mergeable) univariate and conditional statistics …"  # R ≤ 600 chars
modules     = ["Accumulators", "Histograms", "Kernels", "Expectations", "LocalPolynomial", "MarginalDensity",
               "ConditionalExpectations", "ConditionalDensity", "Bandwidth"]     # R  src/<Module>.jl
extensions  = ["ext/GBGStreamingStatisticsHDF5Ext.jl"]
absences    = ["no vector/tensor notation", "no GPU-specific estimators"]   # deliberate absences hats must not flag
julia       = "julia --project"                    # the invocation witnesses and executing lanes use
test        = "julia --project -e 'using Pkg; Pkg.test()'"
docs_build  = "julia --project=docs docs/make.jl"
docs_post   = []                                   # IT: ["git checkout -- docs/Project.toml"]

[git]
branch = "master"                                  # R  enum: master | main  (IT's main until renamed)
push_on_commit = true

[surfaces]                                         # R  every doc surface; globs; must exist (CFG-02)
rationale = ["docs/ARCHITECTURE.md", "docs/FORMALIZATION.md", "docs/TESTING.md", "docs/PERFORMANCE.md"]
pages     = ["docs/src/*.md", "docs/src/api/**/*.md"]
literate  = []                                     # PF: ["examples/HIST_CPU.jl", "examples/gpu/*/*.jl"]
generated = ["docs/src/architecture.md", "docs/src/formalization.md", "docs/src/testing.md", "docs/src/performance.md"]
built_api = "docs/build/api"                       # the built-HTML surface; "" disables surface 6
history_exempt = "docs/ARCHITECTURE.md#Decision log"   # append-only section exempt from currency checks

[rubric]                                           # the docstring rubric's PARAMETERS (not its rules)
leading_identity   = "estimand"                    # enum: physical-meaning | estimand   (item 1 of the home)
argument_bullet    = "plain"                       # enum: plain   (SS's bold form is collapsed, §5)
in_place_steer     = true                          # IT sets false — a declared deviation, see [[deviation]]
admonition_titles  = "always"                      # enum: always | load-bearing   (IT: load-bearing, §5)
arguments_form_min = 3                             # the ≥3-args-or-keyword threshold
allocating_wrapper_phrase = "Allocating form of"   # idiom string argcov keys on
fields_phrase      = "The fields are"

[notation]
vectors      = "components"                        # enum: components | boldsymbol   (IT: boldsymbol)
imaginary    = "\\mathrm{i}"
partial      = "\\partial_{x_i}"
banned       = ["\\left", "\\right", "\\imath"]   # beyond the shared idiom set
mathbf_allowed = ["\\mathbf{1}"]                   # the indicator carve-out; IT: []
stale_names  = []                                  # IT: ["uh", "phih", "velocity", "vorticity"]
glossary     = "docs/src/notation.md"

[citations]
references_section = "docs/ARCHITECTURE.md#References"
require_doi = true

[check_docs]
lanes   = ["rationale", "docstrings", "pages", "literate", "built-html", "family", "cold-reader", "operational-claims"]
argcov_policy = "triage"                           # enum: triage | gate   (PF triage, IT gate)
public_surface = "test/public_surface.jl:package_operations"   # "" ⇒ names(Module) fallback
unexported_base_expected = ["size", "eltype", "axes", "copy", "copyto!", "getindex", "setindex!", "ndims", "in", "show"]

[check_consistency]
hats    = ["consistency-matrix", "software-architect", "structure-consistency", "latex-typesetter",
           "api-user", "citations-integrity", "style-editor", "cold-reader", "logician", "plain-sense",
           "statistics-theoretician", "streaming-stability-practitioner", "normalization-convention-auditor"]
anchors = ["statistics-theoretician", "streaming-stability-practitioner"]   # R ≥ 1; each a domain hat
design_docs_withheld = ["architecture", "formalization", "testing", "performance"]   # consolidate.py
seed_every_round = false

[bug_hunt]
territories = ["src/Accumulators.jl src/Histograms.jl — the mergeable-monoid contract, …", "…"]  # ≥ 3
oracles     = ["a closed-form moment of a known distribution", "merge(a,b) == merge(b,a)", "…"]
witness_env = "test"                               # the --project a witness runs under

[audit_changes]
covered_paths     = ["src", "test", "docs"]
executable_claims = ["julia --project -e 'using Pkg; Pkg.test()'", "test/allocations.jl"]
guards            = ["_check_compatible", "_check_bins"]      # the validation symbols lanes look for
invariants_file   = "CLAUDE.md#Core invariants"

[rounds]
max_open_days = 14

[[deviation]]                                      # a declared exemption from a shared RULE (not a doctor check)
rule     = "api.positional-result-affecting"       # R  a rule id listed in policy/RULES.toml
reason   = "SS orders every function object → query → smoothing keywords → modifiers; the bandwidth, kernel and degree are keywords by that convention (docs/ARCHITECTURE.md §3), and changing them is breaking."   # R ≥ 40 chars
ruled    = 2026-06-24                              # R
reviewed = 2026-09-06                              # R  doctor warns > 365 d
```

PF's file differs in: `leading_identity = "physical-meaning"`, `literate` non-empty, `built_api`
set, `notation.vectors = "components"`, PF's territories/oracles/guards, no `[[deviation]]`. IT's:
`git.branch = "main"` (until renamed), `docs_post`, `rubric.in_place_steer = false` with its
deviation, `admonition_titles = "load-bearing"` if the owner keeps it (§5), `notation.vectors =
"boldsymbol"`, `mathbf_allowed = []`, `stale_names`, `argcov_policy = "gate"`, `surfaces.rationale =
["docs/ARCHITECTURE.md"]`, `history_exempt = "docs/ARCHITECTURE.md#11. Decision log"`.

**Deliberately not configurable** (schema has no key; the validator rejects one): every verdict
vocabulary; the demotion predicate; the gate rules and mtime staleness; the economy model id and
which phases are economised; the plateau/stop rules; the finding schema; the seed-class mechanism
(only the anchors are per package); the round layout; the exit-code contract; the header format of
managed files; the `~/.gbg/tools` path.

---

## 4. Run-time contract of one instrument — `/gbg-check-docs`, end to end

1. **Skill.** The user types `/gbg-check-docs` (optionally `full`). `~/.claude/skills/gbg-check-docs`
   → `~/.gbg/tools/skills/check-docs/SKILL.md` (`disable-model-invocation: true`). Its `!` block runs
   `gbg preflight check-docs --project "$CLAUDE_PROJECT_DIR" --strength "${0:-economy}"`.
2. **Preflight** (read-only; exit 2 aborts the skill): `ENV-01/02`, `PIN-01/02`, `CFG-01..04`,
   `WIRE-01..05`, `LEG-01` (the quick doctor set, `QUICK`); refuses if a check-docs round is already open. Prints:
   the effective config (JSON), the round id it *will* create (`2026-09-06`), and the literal calls
   for steps 4–8 with their `args` filled in — the session copies them; it never composes args.
3. **Open the round.** `gbg round open check-docs` writes `.gbg/rounds/check-docs/2026-09-06/round.toml`
   (stamps tools version + sha, config sha256, model, strength). Exit 1 if the checkout is dirty or
   untagged (override `GBG_DEV=1` ⇒ an unclosable dev stamp).
4. **Deterministic tier.** `gbg guards check-docs` runs every scan from `catalog/lanes/check-docs.toml`
   over the config's surfaces: hard scans (tables indented, register, `\left`, code-in-math, bare
   partial, `\mathbf` outside `mathbf_allowed`, abutting spans, dead `§` refs, crammed citations,
   field-list fidelity, link uniformity, DOI cross-check both directions) and triage scans (computed
   sentence openers, argument coverage under `argcov_policy`, signature fidelity, wide signatures,
   duplicate refs). Full output to `<round>/00-guards.md` + `00-guards.json`; exit 1 on a hard hit
   (the session fixes the class, re-runs to zero, continues), 2 if any scan scanned nothing.
5. **Build** `docs_build` and require exit 0; consolidate the built HTML into `.gbg/scratch/` for
   surface 6 (`gbg guards --built`, the five built-HTML questions with `public_surface`).
6. **Lanes.** `Workflow({scriptPath: "/home/grigory/.gbg/tools/workflows/check-docs/lanes.js",
   args: <preflight JSON>})` — one lane per entry of `check_docs.lanes` (surface lanes at economy,
   family and cold-reader lanes, IT's operational-claims lane on the docstring surface), each told to
   `Write` `<round>/NN-<lane>.md` **first** (schema: `## Finding N — <title>` sections, each with a
   fenced ```json finding``` block validating against `finding.schema.json`, and a `## Summary`
   with `candidates_considered`), then return. The script returns `{results, dead, empty,
   truncated, lanes_run}`; `dead` ≠ [] is reported as UNSCANNED, not clean.
7. **Coverage.** `gbg coverage <round>` — exit 1 on a missing lane file, a lane parsed to zero
   without a literal "No findings", an orphan file, or an empty pile.
8. **Fix pass** (full strength, main thread), driven from the `NN-*.md` files by finding number.
   Then `Workflow({scriptPath: ".../check-consistency/verify-fixes.js", args: {…, range:
   "<sha-at-open>..HEAD", lanes: [...]}})`; each verifier lane `Write`s `<round>/closure/NN-<lane>.md`
   with one fenced ```json verdict``` per finding (`act-verdict` schema, `class_surfaces` an array).
   `gbg round gate <round>` applies the emptiness demotion mechanically, reports the mechanical share
   apart, checks mtimes (verdict newer than lane; all verdicts within one 6-hour bucket, WARN not
   FAIL), and exits 1 while any finding is neither HONORED nor in `.gbg/adjudicated.md`. Loop fix →
   verify **over the same banked set**; the lanes are never re-run; stop at a plateau (three rounds
   flat) or zero open.
9. **Close.** `gbg round close <round>` runs the gate once more and stamps `closed`; the wholesale
   escape is a `CLOSED.md` with an account (`gbg round close --closed-md` refuses an empty account).
   Commit and push on `git.branch` with the policy's trailer.
10. **Build enforcement.** Every later `docs/make.jl` run calls `GBGCodingTools.closure_gate()` →
    `gbg round gate --all --project .` → fails the build on an open round past `max_open_days`, a
    closed round whose gate no longer passes, or a `.gbg/rounds/` directory with no `round.toml`
    (a pile with no marker is a finding, IT's rule).

File formats: `round.toml` (TOML), banked findings and verdicts (markdown with fenced JSON blocks —
readable by humans, parsed by the CLI without a second grammar), `00-guards.json`,
`ground_truth.json`, `latest.json` (audit), `managed.json`. Exit codes everywhere: 0 / 1 / 2 as in D8.

The same skeleton serves the other three: `/gbg-check-consistency` swaps steps 4–6 for consolidate →
optional seed (fixture-calibrated; a real-package seed round closes each seeded finding through an
`exemptions.toml` entry whose `evidence` is `ground_truth.json`, which the gate reads and the panel
preamble never sees) → panel (`hats.json` emitted) → verify pair; `/gbg-bug-hunt` banks
`witnesses/` in the round, runs `gbg witnesses <round> fail` (exit 1 on any pass, **and** on any
error — PF's exit-0-on-error is closed), promotes with `gbg witnesses promote <name>` (copies
unchanged, prepends the provenance header, renames `<op>-<symptom>.jl`); `/gbg-audit-changes`
requires `base`, writes `latest.json`, and `gbg audit-gate` answers every serious or
`previously_worked` finding.

---

## 5. Migration — per consumer, with the doctor verifying each step

### 5.1 The deviations: kept as declared, or collapsed

| Recorded difference | Ruling | Why |
|---|---|---|
| IT bans `\mathbf`; PF/SS prescribe `\mathbf{1}` for the indicator | **Collapsed into one rule**: `\mathbf` is banned except the strings in `notation.mathbf_allowed`; IT sets `[]`, PF/SS `["\\mathbf{1}"]` | Not a contradiction once the carve-out is a parameter; IT's own `OPEN-ITEMS.md` records the ban as "never dispositioned" |
| IT `\boldsymbol{u}` bold-italic vectors vs PF component notation | **Declared config** `notation.vectors` | Domain: IT writes physics register, PF's fiber is one Cartesian frame by design (invariant, §2) |
| IT declined the verbatim in-place steer sentence (owner-ruled 2026-08-25) | **Kept as declared deviation** (`rubric.in_place_steer = false` + `[[deviation]]` with the recorded reason) | Owner-ruled with a reason that is true of IT's corpus (compute/cached-read pairs) |
| IT allows a bare `!!! note` for asides; PF requires a custom title always | **Collapse to PF's rule, owner to confirm at IT's migration** (`admonition_titles = "always"`); if the owner keeps IT's, it is a declared deviation with the reason from `IT:CLAUDE.md:205` | A titled note is a strict superset; the shared lint is simpler with one form; but both were owner decisions, so the collapse is proposed, not imposed |
| SS `- **`arg`**` bold argument bullets (required) vs PF forbids | **Collapsed as historic artefact** (`argument_bullet = "plain"`); a one-shot `gbg sync --rewrite-arg-bullets` does the sed | Purely typographic, no domain reason, and 2 of 3 rubric holders use plain |
| SS estimand-first rubric | **Declared config** `rubric.leading_identity = "estimand"` | The same slot (item 1 of the docstring home) with a domain value; PF's "physical-meaning first" is the other value |
| SS result-affecting smoothing controls as keywords | **Kept as declared deviation** of `api.positional-result-affecting` | A coherent, documented argument-order convention; breaking to change |
| IT on `main` | **Collapse: rename to `master`** (GitHub branch rename + `docs.yml` edit), executed in IT's migration; `git.branch` carries `main` until then so nothing breaks if deferred | Topology, not domain; the fleet's three others are `master`, and the policy prose says "on `master`" |
| IT/SS commit trailer names a model version (`Claude Opus 4.8`) | **Collapsed** to PF's versionless trailer, stated once in `policy/working-agreements.md` | Owner-ruled 2026-09-04 with the reason recorded in PF's `CLAUDE.md` |
| SS `julia = "1.11"` | **Collapsed**: SS bumps to `1.12` | CP calls 1.12 the fleet floor; the host cannot run 1.11; PF's compile-time measurement |
| CP "Damköhler knobs" ×5 | **Collapsed**: reworded (`option`/`setting`) | The register rule every other package holds |
| `.claude` tracking policies (PF tracks 90 files, IT untracks piles by convention, SS/CP nothing) | **Collapsed**: `.gbg/rounds` tracked, `.gbg/scratch` ignored, everywhere | R2/R3 |
| Request files tracked in PF, untracked in IT | **Collapsed**: `.gbg/requests/to-<PKG>-<date>.md`, tracked in the requester, status paragraph at the top | R2 |
| IT's `argcov` exits 1, PF's triages | **Declared config** `check_docs.argcov_policy` | IT's corpus uses `# Arguments` sections; a rubric-shape difference, not drift |
| PF bug-hunt lanes by territory, IT by class + free readers | **Collapsed** into one engine: N territory lanes from config + one free lane always (the measured winner) | `survey-bughunt-auditchanges.md` §4.1: neither was the measured optimum; the free lane is |
| IT tracks its root `Manifest.toml`; PF/SS/CP do not | **Kept** (topology: IT's unregistered PF dependency) | Necessary until a registry exists |

### 5.2 Day one in each consumer

**CP (no instruments today).** A session opens in `GBGCloudPhysics`, `~/.gbg/tools` exists (installed
once per machine). The session runs `gbg init --project .` which: writes `.gbg/config.toml` from
the template with `[package]` filled from `Project.toml` and `src/`, seeds `exemptions.toml`,
`adjudicated.md`, `hats/` (empty, with a README asking for ≥ 1 domain anchor), `seeds.toml`,
`test/regressions/` + README; inserts the managed block into `CLAUDE.md` and `.gitignore`; inserts
the `lint_docs` line into `docs/make.jl` and `include_regressions!` into `test/runtests.jl`; adds
`GBGCodingTools` to `test/Project.toml` and `docs/Project.toml` with `[sources]` at the checkout's
tag; writes `managed.json`. Then `gbg doctor` → red on `CFG-03` (no anchor) and `LOAD-01` (envs
not instantiated); the session writes one domain hat (`cloud-microphysicist.md`), instantiates,
accepts the import dialog on its next start, and the doctor is green. `/gbg-check-docs` then runs
the same battery PF runs — CP has never had one.

**SS (July fork).** `gbg init` refuses because `.claude/commands/` exists → the session runs the
migration checklist below; the only judgment items are the three deviation rows above (bold bullets
collapse; estimand-first becomes config; smoothing keywords become a declared deviation).

### 5.3 The checklist (one per consumer; each step names the doctor check that verifies it)

| Step | Action | Verified by |
|---|---|---|
| MIG-0 | Per machine, once: `git clone` the tools repo into `AI Helpers/` (Dropbox); `~/.gbg/tools/bin/gbg install` (creates `~/.gbg/tools` symlink, `~/.claude/skills/gbg-*`, checks `julia`/`python3`) | `ENV-01..04` |
| MIG-1 | Checkout at the target tag: `git -C ~/.gbg/tools checkout v1.3.0` | `ENV-02` |
| MIG-2 | `gbg init --project .` (refuses if legacy dirs exist; `--migrate` moves `doc-review-adjudicated.md` → `.gbg/adjudicated.md`, tracked round dirs → `.gbg/rounds/<instr>/<date>/`, `bug-hunt/{rounds.json,OPEN-DEFECTS.md}` → `.gbg/rounds/bug-hunt/`) | `CFG-01`, `WIRE-01..05` |
| MIG-3 | Fill `config.toml`: description, modules, surfaces, hats/anchors, territories, oracles, guards; write `.gbg/hats/*.md` from the package's `panel.js` personas (data only, package names stripped) | `CFG-02..04` |
| MIG-4 | Record the deviations from §5.1 as `[[deviation]]`; apply the collapses (bullet sed, trailer, knobs, julia floor) | `CFG-04`, `POL-02` |
| MIG-5 | Delete `.claude/commands/**`, `.claude/doc-review*`, `.claude/review-rounds`, `.claude/audit-changes`, `.claude/bug-hunt`; strip `lint_*` bodies from `docs/make.jl`; delete the shape CSVs; strip the policy prose the import now carries from `CLAUDE.md` (keep package-specific sections) | `LEG-01..03` |
| MIG-6 | `[sources]`+`[deps]` in `test/` and `docs/` Project.toml; `Pkg.instantiate()` both; `julia --project=test -e 'using GBGCodingTools'` | `PIN-02`, `LOAD-01` |
| MIG-7 | `docs_build` exits 0 with the shared lints; `Pkg.test()` green with the shared harnesses (baselines refrozen where a harness's counting changed, reason in the commit) | `BUILD-01`, `TEST-01` (`--deep`) |
| MIG-8 | Re-run `gbg round gate --all` over migrated rounds; close any that cannot be graded with a `CLOSED.md` account ("migrated from the pre-tools layout; verdicts not re-graded") | `ROUND-01..03` |
| MIG-9 | Start a session; accept the import dialog; `/gbg-doctor` (the session quotes the policy sentinel) | `POL-01` (file) + in-session sentinel |
| MIG-10 | Commit + push; `gbg fleet` shows the column green | fleet |

Order PF → IT → SS → CP; PF and IT are also where the engine union is *proven* (their existing
rounds are the regression corpus for the ported gates: `gbg round gate` over PF's two tracked
check-docs rounds and IT's `review-rounds` must reproduce their recorded closures before the
migration commit lands).

### 5.4 Adding a fifth package

1. Create the repo as today (Dropbox + GitHub). 2. Add one entry to `~/.gbg/tools/fleet.toml`
(`name, path, github`) — a tools PATCH release. 3. In the new repo: `gbg init --project .`,
fill config, write ≥ 1 domain hat, instantiate, `gbg doctor` green, accept the dialog. 4. Nothing
else: the skills are already on the machine, the policy is already imported, the engines already
run. `gbg fleet` shows five columns.

---

## 6. The doctor and the fleet view

### 6.1 `gbg doctor`

`gbg doctor [--project P] [--deep] [--json] [--only ENV,PIN,…]`. Read-only. Prints one line per
check, then a summary; exit 0/1/2. `--deep` adds the slow checks (LOAD, BUILD, TEST). Stable ids:

| Id | Check | Fails when |
|---|---|---|
| ENV-01 | `~/.gbg/tools` is a symlink to a git checkout of GBGCodingTools | missing / not a repo |
| ENV-02 | checkout clean and at a tag (`git describe --exact-match --dirty`) | dirty or untagged (WARN under `GBG_DEV=1`) |
| ENV-03 | `~/.claude/skills/gbg-*` resolve into the checkout (or copies with matching hash) | any missing/foreign |
| ENV-04 | `julia` ≥ 1.12 on PATH, `python3` ≥ 3.11 | otherwise |
| PIN-01 | `[tools] version` == checkout tag | mismatch |
| PIN-02 | `test/` and `docs/` Project.toml declare GBGCodingTools in `[deps]` and `[sources] rev` == pin | either missing or ≠ |
| PIN-03 | no `dev`'d GBGCodingTools in a tracked Manifest | found |
| CFG-01 | config parses, schema-valid, no unknown keys, required present | otherwise |
| CFG-02 | every surface glob matches ≥ 1 file; every module exists as `src/<M>.jl`; `docs_build` file exists | otherwise |
| CFG-03 | every hat key resolves (catalogue or `.gbg/hats/`); `anchors ⊆ hats`; ≥ 1 anchor; no hat persona names another fleet package | otherwise |
| CFG-04 | each `[[deviation]]` names a rule in `policy/RULES.toml`, reason ≥ 40 chars, `reviewed` ≤ 365 d (WARN) | otherwise |
| WIRE-01 | `CLAUDE.md` managed block present, equals the render of config, import line intact | edited / stale |
| WIRE-02 | `docs/make.jl` contains `GBGCodingTools.lint_docs(` and no `function lint_` of its own | otherwise |
| WIRE-03 | `test/runtests.jl` contains `include_regressions!(`; `test/regressions/` exists; README hash ok | otherwise |
| WIRE-04 | `.gitignore` managed block present (`.gbg/scratch/`) | otherwise |
| WIRE-05 | every `managed.json` entry: hash matches (`MODIFIED`), template unchanged in pinned version (`STALE`) | either |
| LEG-01 | no `.claude/commands/{check-docs,check-consistency,bug-hunt,audit-changes}*`, `manifest.py`, `MANIFEST.txt` | present |
| LEG-02 | no `.claude/doc-review*`, `review-rounds/`, `audit-changes/`, `bug-hunt/` dirs | present |
| LEG-03 | `CLAUDE.md` carries none of 12 policy-sentinel phrases the import now provides (e.g. "Function docstring = home") | duplicated prose |
| POL-01 | the import path resolves to the checkout's `policy/GBG-POLICY.md`; its sentinel version == pin | otherwise |
| POL-02 | collapsed artefacts absent: model-versioned trailer text, "knob" in `CLAUDE.md`/docs, bold arg bullets, `julia` compat < 1.12 | present |
| GIT-01 | current branch == `git.branch`; remote `origin` set | otherwise |
| ROUND-01 | no open round older than `max_open_days` (WARN at half) | otherwise |
| ROUND-02 | `gbg round gate` passes on every closed round; every `.gbg/rounds/**` dir has a `round.toml` | otherwise |
| ROUND-03 | no closed round stamped `dev+…` | present |
| LOAD-01 (`--deep`) | `julia --project=test -e 'using GBGCodingTools'` and the docs env load | error |
| BUILD-01 (`--deep`) | `docs_build` exits 0 | otherwise |
| TEST-01 (`--deep`) | `test` exits 0 | otherwise |

Exemption: an entry in `.gbg/exemptions.toml` turns FAIL into `EXEMPT(reason)`; the doctor fails an
exemption with no reason, an unknown check id, or `reviewed` > 365 days. There is no exemption for
`PIN-*`, `CFG-01`, `ROUND-02`, `POL-01`.

Self-test: `tests/test_doctor.py` copies the fixture, applies each perturbation, asserts the exact
failing id — a check that stays green under its own perturbation fails the tools' CI.

### 6.2 `gbg fleet`

Reads `~/.gbg/tools/fleet.toml`, runs the doctor in every consumer (quick by default, `--deep`
optional), prints:

```
package                   pin     branch  doctor  open rounds  last round (instr, version)   deviations
GBGPeriodicFields         1.3.0   master  OK      0            2026-09-01 check-docs 1.3.0   0
GBGIsotropicTurbulence    1.3.0   main    FAIL    1 (bug-hunt, 9d)  2026-09-05 audit 1.3.0   1 (in-place steer)
GBGStreamingStatistics    1.2.0   master  FAIL    0            —                             2
GBGCloudPhysics           —       master  NOT-INITIALISED
tools checkout: v1.3.0 (clean)   fleet policy: one version — 2 of 4 mismatched
```

Exit 1 if any column is not OK or any pin differs from the checkout — the fleet view is the
one-version rule's check (D4). `--json` for the memory note or a request file.

---

## 7. How the package tests itself, and what "provably best" means here

**Self-tests** (D15): schema tests for every catalogue file and template; doctor perturbation tests;
gate selfchecks in both directions (a closure that must fail and a clean one that must pass; a
`HONORED` inside a demotion note that must not count); `recall --selftest` arms A–D built in the
test, not drawn from the catalogue; witnesses-runner tests with one failing/passing/erroring
fixture witness; manifest regeneration idempotence; Julia lints against the fixture reproducing the
planted defect list exactly (and nothing else); the harness macros against the fixture package. The
contract from each consumer (`fleet.toml` + the four `config.toml`s copied into `tests/contracts/`
at each release) is validated against the schema in the tools' CI, so a MAJOR change is a contract
failure seen before the tag.

**Requirement → decision entailments** (what the requirements *force*; everything else is judgment):

| Requirement | Entails |
|---|---|
| R1 same code, same version | one repo (D1); one checkout per fleet (D4); differences only as config or `[[deviation]]` or doctor findings (D5, D14) |
| R2 answerable from committed artefacts | tracked rounds with `round.toml` stamps (D10); pin in config (D3); the managed `CLAUDE.md` block (D12) |
| R3 missing case fails | schema-required keys (D5); preflight aborting the skill (D6); gate exit 2 on an absent round (D10); dead lane ≠ clean (D7) |
| R4 instrument integrity | tags + MAJOR rules (D16); bump refused with an open round (D4); `GBG_DEV` rounds unclosable |
| R5 self-tested | fixture consumer + perturbation tests (D15) |
| R6 minimal footprint | personal-scope skills (D6); `.gbg/` + five wiring lines (D13) |
| R7 polyglot, versioned together | D1; `args` from preflight (D7); stdlib Python CLI (D8) |
| R8 two machines | Dropbox clone + `~/.gbg/tools` symlink (D2); URL+rev for CI (D3) |
| R9 tractable migration | checklist with check ids (D17, §5.3); doctor (D14) |
| R10 extensibility | `fleet.toml` entry + `gbg init` (§5.4); an instrument = `workflows/<i>/` + `skills/<i>/` + `catalog/lanes/<i>.toml` + `schemas/<i>.schema.json` + `tests/test_<i>.py` |
| R11 one schema | `schemas/` constants, `x_<pkg>` extension only (D11) |
| R12 shared cost policy | tiers in the engines, anchors in config (D18) |

**Residual judgment calls** (not entailed; stated so they can be overruled):
1. Dropbox-synced clone vs per-machine clone (D2) — chosen for zero sync steps; the cost is that one
   machine's uncommitted instrument edit is visible on the other (mitigated by `ENV-02`).
2. `.gbg/` as the consumer directory rather than `.claude/` (D5).
3. The `gbg-` skill prefix rather than bare names (D6).
4. A required line in `docs/make.jl` rather than a managed stub (D13).
5. Collapsing IT's bare-`!!! note` rule and IT's `main` (§5.1) — proposed, owner-confirmed.
6. Python for the CLI rather than Julia (D8) — startup time and the existing zero-coupling scripts.
7. The name (D19).

Nothing here is "provably best" in a stronger sense than: every mechanism traces to a requirement
or to a recorded failure in the surveys, no requirement is left without a mechanism, and the seven
choices above are the complete list of places where a different owner could reasonably choose
differently.
