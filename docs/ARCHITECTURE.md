# GBGCodingTools — architecture

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

This document is the design record of `GBGCodingTools.jl`: the one shared tooling package that four
private sibling Julia packages consume — [`GBGPeriodicFields`](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/) (**PF**), [`GBGIsotropicTurbulence`](https://grigorysarnitsky.github.io/GBGIsotropicTurbulence.jl/)
(**IT**), [`GBGStreamingStatistics`](https://grigorysarnitsky.github.io/GBGStreamingStatistics.jl/) (**SS**), [`GBGCloudPhysics`](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/) (**CP**) — and which consumes itself:
the tool repository is its own fifth consumer (D15). It is self-contained: every
term is bound where it first appears, and no external file is needed to understand it. Evidence
citations point into the design-time surveys (`survey-*.md`, `round1-*.md`, `round2-*.md`,
`facts-claude-code-platform.md`, `theory-patterns.md`) by file and line; those files are the
historical basis, not a dependency of the reader. `04-decision-record.md` is the authoritative
decision record; where this document extends it, §10 says so explicitly.

Vocabulary used throughout:

- **Consumer** — one of the four packages, as a client of the tool; and the tool repository itself,
  its own fifth consumer (D15) — a statement about "a consumer" binds the tool root too unless it
  says otherwise.
- **Instrument** — one of the four review procedures the tool ships: `/check-docs` (the deterministic
  + agent battery over documentation), `/check-consistency` (the multi-hat panel over the rendered
  site), `/bug-hunt` (the code instrument whose only evidence is a failing program), `/audit-changes`
  (the diff audit). "Instrument" keeps the house meaning of a measuring device.
- **Round** — one run of an instrument, recorded as a tracked directory in the consumer.
- **Lane / hat** — one agent of an instrument (a *hat* is a persona in the panel; a *lane* is a
  surface or territory in the other three). Agents run inside Claude Code **Workflow scripts**
  (sandboxed JavaScript with no filesystem, configured only through an `args` object).
- **Anchor** — a hat or lane that runs at full strength instead of the economy model. The word has
  exactly this one meaning. Which *engine* lanes are anchors is a constant of the catalogue (the
  `executing` audit lane, the two free hunt lanes, the dismissal auditor, the severity re-check); which
  *domain* hats are anchors is the consumer's config (`anchor = true|false` per hat). The
  never-economised **phases** (D18) are a different thing and are never called anchors.
- **Gate** — a program whose non-zero exit blocks a build, a test run or a round's closure.
- **Pin** — the tool version a consumer names in its config.
- **Managed file** — a file the tool renders into a consumer and hash-checks thereafter.
- **Ledger** — the consumer's one file of declared exceptions (`.gbg/exemptions.toml`). The word is
  reserved for that file; the bug-hunt's per-finding `fixed|refused|escalated` record is the
  **disposition record** (`reproductions/<id>.json`), never "the ledger".
- **`GBG_ROUND`** — the environment variable the CLI exports (`GBG_ROUND=<round-id[,…]>`) whenever it
  invokes `make.jl`, `Pkg.test()` or an executable claim on behalf of an open round; `gbg gate`
  ignores exactly the open rounds it names and no others (§6.2 step 10).

---

## §0 The design sentence and the requirements

**A consumer holds data; the tool holds behaviour; the only thing connecting them is a pin.** Every
engine, protocol, persona catalogue, verdict vocabulary, gate, lint, harness and policy text lives once,
in the tool, at a version. A consumer carries one config file, one exemptions ledger, its domain
hats, its tracked rounds, and a handful of hash-stamped stubs it regenerates rather than edits. What
differs between consumers is either a value the config schema admits or an entry in the ledger with a
reason — nothing else is admissible, and `gbg doctor` says so.

Requirements (the frame every decision in §2 answers):

| Id | Requirement |
|---|---|
| R1 | **Uniformity.** The four consumers run the SAME instrument code at the SAME version. A difference between consumers is either declared config or a doctor finding. Existing differences default to historic artefacts. |
| R2 | **Transparency.** From committed artefacts alone one can answer: which instrument version measured this round; what this package deviates in and why; what changed in the instrument between two rounds. |
| R3 | **Fail-closed.** The missing case is the failing case: no config → fail; absent round directory → fail; dead lane → cannot evaluate; zero count → dead agent, never clean. |
| R4 | **Instrument integrity.** Instrument changes are their own commits and releases, never folded into a round. A round records its instrument version and cannot close under a different version than it opened with unless re-graded. |
| R5 | **Self-tested.** The tool tests itself against a fixture consumer with must-fail arms; a check that cannot fail is not a check. |
| R6 | **Minimal consumer footprint.** A consumer holds config, piles, and the files that must physically exist (`test/regressions/`, the `make.jl` call, the `CLAUDE.md` import line); nothing else duplicated. |
| R7 | **Polyglot reality.** Workflow JS (no filesystem, args only), Julia, shell, markdown skills, personas, hooks — versioned together; every deterministic engine is Julia inside the one package. |
| R8 | **Two-machine fleet** (`Aiporetne`, `Enteropia`; Dropbox + private GitHub), reproducible per-machine install, no secrets in any repo. |
| R9 | **Migration tractability.** Each consumer migrates by an ordered checklist, a doctor check verifying each step; no big bang. |
| R10 | **Extensibility.** A fifth package = config + scaffold. A new instrument = one directory with a contract (skill, workflow, engine, self-test, schema). |
| R11 | **Comparable measurements.** One shared finding schema and verdict vocabulary; per-package extension only through declared fields. |
| R12 | **Shared cost policy.** Economy lanes by default, anchors named per package, fix phase at full strength. |

---

## §1 The platform / product model

The tool is a **platform**; each consumer is a **product** instantiated from it by configuration
(`theory-patterns.md:9-19`). The commonality/variability analysis below is the deliverable that turns
"1.5–2× line-count drift on same-named files" (`survey-buildlints-hooks-policy.md:173`) into a list.

**Common (lives once, in the tool):** every Workflow engine; every deterministic scan and gate; the
Julia test harnesses and the docs-build wrapper; the verdict vocabularies and schemas; the demotion and
closure predicates; the round layout and stamp fields; the exit contract; the generic hat and lane
catalogues; the seed mechanism (a consumer's seed catalogue is the consumer's own `.gbg/seeds.toml`, §6.4; only the fixture's lives in the tool); the
policy prose with its rule ids; the doctor; the fixture consumer and self-tests; the cost policy's
never-economised phases and the economy model name; the rubric's constants (the upright
``\mathrm{i}``, the ``\partial_{x_i}`` partial, the "Allocating form of" and "The fields are" phrases,
the ≥ 3-arguments-or-a-keyword threshold — none of them a config key).

**Varies (a value in the consumer's config).** The record names FIVE rubric variation points (marked
★); every other row is a package fact (an identity, a path, a list of operations) or a value the
record's "Keep as config" clause admits, never a rubric choice. §10 records this extension of the
record explicitly.

| Variation point | Admissible values | Binding | Evidence it varies for a reason |
|---|---|---|---|
| package identity: name, description, modules, extensions, deliberate absences, terms, domain, `rulebook_sections` (the `file#heading` anchors the catalogue's rulebook hats read) | free text / lists / anchors | config | every persona preamble (`survey-check-consistency.md:199-200`); IT's rulebook hats read IT's `CLAUDE.md` sections |
| package paths: `[paths]` (further directories the audit covers — `examples`, `benchmark`) | relative directories | config (may only ADD to the covered constants) | PF's `examples/` demos are shipped code |
| doc surfaces: rationale docs, pages, generated copies (`optional = true`, tolerated absent on a fresh clone), src, ext, literate examples, built HTML, history-exempt section, references heading (or `"absent"`), glossary | globs / `file#heading` anchors | config | PF 6 surfaces, IT 4, SS 4 (`survey-checkdocs.md:51`) |
| ★ `rubric.leading_identity` | `physical-meaning` \| `estimand` | config enum | SS's estimand-first slot (`survey-checkdocs.md:139`) |
| ★ `notation.vectors` | `component` \| `boldsymbol` \| `none` | config enum | IT bold-italic vectors vs PF components (`survey-check-consistency.md:160`) |
| ★ `notation.mathbf_allowed` | list of strings | config | `\mathbf{1}` prescribed (PF/SS) vs banned (IT), undispositioned (`survey-buildlints-hooks-policy.md:37`) |
| ★ `docs.admonition_titles` | `always` \| `load-bearing` | config enum | PF always / IT bare `!!! note` (`survey-buildlints-hooks-policy.md:95`) |
| ★ `instruments.check-docs.argcov_policy` | `triage` \| `gate` | config enum — the ONE declared exception to "tiers are not configurable" (§5.5) | PF triage, IT exit 1 (`survey-checkdocs.md:159`) |
| `docs.doctest` | bool | config | IT `false` (`survey-buildlints-hooks-policy.md:29`) |
| `docs.retired_claims` | list of `{pattern, reason}` (a per-package phrase list feeding the hard scan `SCAN.RETIRED_CLAIMS`) | config | PF's `lint_retired_claims` bans decision-60 phrasings that IT and SS never had |
| `docs.unexported_base_expected` | list of `Base` names the API pages are expected to leave unexported | config | PF's built-HTML question 1 |
| panel roster, profile, core set, domain hats, anchors | catalogue keys + `.gbg/hats/*.toml` | config | PF 12 hats / 2 anchors, IT 27 / 4 (`survey-check-consistency.md:77-79`) |
| `instruments.check-docs.lanes_extra` | list of `{key, files, brief}` refining the engine's surface lanes | config | PF splits `src` into core/ops lanes; IT does not |
| hunt territories, oracles, witness environment | lists | config | package operations (`survey-bughunt-auditchanges.md:133`) |
| audit executable claims (files under `test/`), guard symbols, invariants section | lists / anchor | config | `survey-bughunt-auditchanges.md:143-151` |
| `seed_catalog` (the path of the consumer's seed catalogue, default `.gbg/seeds.toml`), `seed_rounds` | path, bool | config | IT seeds every round (`survey-check-consistency.md:60`); a catalogue names a consumer's pages and fragments — a package fact |
| `git.branch` | `master` \| `main` | config | IT on `main` (`survey-buildlints-hooks-policy.md:67`) |
| `docs_post` | list of commands | config | IT's `git checkout -- docs/Project.toml` (`survey-checkdocs.md:126`) |
| `schema.finding_types_extra` | list | config (the ONE schema extension point) | per-package `type` enums (`survey-check-consistency.md:202`) |
| `surfaces.data` | list of globs, EMPTY by default | config | the tool's own catalogues, schemas, templates and scripts (Revision 14); a science package leaves it empty and nothing changes |
| `[[scans.custom]]` | regex scans, tier FIXED to `triage` | config | PF's "spectral field" reminder, IT's stale variable names |
| declared deviations from a policy rule | ledger entries with reason (+ expiry, or `overturn_when` for a finding) | ledger | IT's declined steer sentence, SS's keyword smoothing controls |

**Drift (everything else that differed):** collapsed to one side in §9. A difference that is neither a
variation point above nor a ledger entry is a doctor finding.

---
## §2 Decisions D1–D19

Each decision: **choice** / **forced by** (requirement + evidence) / **dominated alternatives**.

### D1 — Unit of distribution: one repository, one version, two faces

**Choice.** One git repository `GBGCodingTools.jl` (private GitHub `GrigorySarnitsky/GBGCodingTools.jl`;
dev checkout `~/Dropbox/Research and Teach/AI Helpers/GBGCodingTools/`) that is simultaneously (i) a
Julia package (root `Project.toml`, module `GBGCodingTools`) which carries the CLI `gbg` as
`src/CLI/*.jl`, the scan engine as `src/Scans/*.jl`, the harness and the docs-build wrapper, and (ii)
the instrument corpus (protocols, Workflow `.js`, catalogues, schemas, policy, templates, fixture).
One `version`, one tag per release, one `CHANGELOG.md`. Every deterministic engine is Julia inside
that one package; JavaScript exists only for the Workflow scripts, `sh` only for the shim and the
Stop hook; there is no Python (the one transitional exception, D8's `consolidate.py`, was deleted on
2026-09-09 when its Julia port passed the byte comparison).

**Forced by.** R1, R4, R7, R2. The divergences that must be *resolved* rather than parameterised all
cross a language boundary: `verify-fixes.js` (JS) and `lint_review_closure` (Julia) were declared
twins and desynced for a day (`survey-checkdocs.md:207`, `survey-buildlints-hooks-policy.md:229`); the
hunt verdict set is keyed off by `dismissals.js`, `closure.py`, `finished.py`
(`survey-bughunt-auditchanges.md:263`). Splitting by language recreates those twins across repos — and a second implementation language
inside the one repository recreates them inside it, which is why the first draft's Python CLI was
retired for Julia (D8).

**Dominated.** *Julia package + separate Claude plugin repo*: two versions, and a plugin cannot ship
Workflow scripts (`facts-claude-code-platform.md:62`). *Vendored copies + manifest*: the status quo
(`survey-checkdocs.md:167`, MANIFEST listing 3 of 6). *Monorepo of all five*: a topology change to
four working repos with their own docs deploys; not needed to get the one-version rule.

### D2 — Delivery: Pkg fetches the pinned copy; a per-machine `sh` shim that execs the docs environment's copy; a registered dev checkout for the owner

**Choice.** Three roles, three locations:

1. **Dev checkout** — the Dropbox clone above, pushed to GitHub. The owner edits and releases here.
   Consumers never read it. Its path is **registered per machine** in `~/.gbg/dev` (one line, the
   absolute path), written by `gbg install [--dev-checkout <path>]` or by `install.sh`; nothing else
   lives under `~/.gbg/`.
2. **Pinned copy** — fetched by Julia `Pkg` into `~/.julia/packages/GBGCodingTools/<slug>/` from each
   consumer sub-environment's `Project.toml` `[sources]` entry (D3) at an immutable tag. Files are
   read-only by Pkg convention (`round2-maintainer.md:10-17`, E1) — and, because convention is not a
   check, `gbg self verify` re-hashes the tree (D3). Every consumer-side invocation — CLI, Workflow
   scripts, protocol text, Julia harness — runs from this copy.
3. **Shim** — `~/.local/bin/gbg`, POSIX `sh`, ~30 lines, versionless, and it selects no depot slug:
   walks up from `$PWD` to the nearest `.gbg/config.toml` (as before) and then
   `exec julia --startup-file=no --project="<root>/docs" -e 'using GBGCodingTools; exit(GBGCodingTools.main(ARGS))' -- "$@"`.
   Pkg's resolution of the consumer's `docs/` environment IS the version selection — stronger than a
   slug match, because the manifest and the `[sources]` entry decide. A `docs/Manifest.toml` that is
   absent or does not list `GBGCodingTools` is **"package not instantiated" → exit 2** with the hint
   `julia --project=docs -e 'using Pkg; Pkg.instantiate()'`. Outside any consumer (no config found)
   it execs the same line against `--project="<dev checkout>"` read from `~/.gbg/dev`, for `fleet`,
   `release`, `new`, `selftest`; no `~/.gbg/dev` → exit 2 "no dev checkout registered".
   `gbg --dev …` (the shim's first argument; `main` accepts the same flag and sets `GBG_DEV=1`)
   inside a consumer routes to the registered dev checkout and stamps
   `tool_version = "dev+<sha>[-dirty]"`; a documentation round does not **open** at such a stamp
   (`Preflight.dev_round`), and one already closed at it is cited by no release (D16, revised
   2026-09-10).
   A config whose pin is the literal `version = "dev"` is legal in exactly two places (D15): a
   consumer enclosed by the tool repository — the fixture — which is routed the same way, to the
   enclosing tool repository (found by walking up to a `Project.toml` with
   `name = "GBGCodingTools"`, execed as its `--project`), else exit 2; and the tool's own root, where
   the walk stops at its first step because the root holding `.gbg/config.toml` IS the tool
   repository, so the shim takes its ordinary route — `--project="<root>/docs"`, the tool's own docs
   environment. **Bootstrap circularity, stated once.** The tool's `docs/Project.toml` lists
   `GBGCodingTools` with `[sources] GBGCodingTools = {path = ".."}`, so that environment loads the
   tool from its own working tree; the shim, run inside the tool repository, execs
   `julia --project=docs` there like anywhere else, and every `gbg` call the tool makes on itself
   therefore runs the working tree — equivalent to `--dev` — the `PIN.*` checks accepting
   `version = "dev"` at the tool root and the stamp recorded as `dev+<sha>[-dirty]`, or as the tag
   itself for a round opened while the tree is clean at a released tag (D16). The tool's docs
   environment is instantiated once per machine
   (`julia --project=docs -e 'using Pkg; Pkg.instantiate()'` in the dev checkout), exactly as a
   consumer's must be. The Julia start (~2–5 s including package load) is paid once per shim
   invocation; where that cost is accepted and where it is forbidden is stated in D6 and D13.

**Bootstrap on a new machine:** `Pkg.instantiate()` in any consumer's `docs/` env (over the same
https credentials the fleet already uses for private sibling deps), then, from that consumer,
`julia --startup-file=no --project=docs -e 'using GBGCodingTools; exit(GBGCodingTools.main(ARGS))' -- install --dev-checkout "<dev checkout>"`,
which writes the shim and `~/.gbg/dev`; the copy that runs is the one Pkg resolved, so no glob over
depot slugs is ever expanded. `install.sh` in the dev checkout runs the same verb against the checkout
itself — a convenience, not the contract. From inside the dev checkout the shim's walk finds the
tool's own `.gbg/config.toml` (D15), so `fleet`, `release`, `new` and `selftest` run there through the
tool's docs environment — the same working tree `~/.gbg/dev` names; the registered path serves the
calls made from outside any consumer.

**Forced by.** R8 (survives a fresh clone and CI without Dropbox or `~/.gbg`), R6, R4 (the pinned copy
is an immutable tree — a mid-round `git pull` of a live checkout would change gates under an open round,
`round2-measurement.md:57-73`). The shim execs the `docs/` environment and no other because
`Pkg.test()` leaves no `test/Manifest.toml` (`round2-maintainer.md:10-17`), so a `--project=test`
lookup is dead on the very machine that ran the tests, while `docs/` always carries a manifest — the
same fact that made the first draft's shim look in `--project=docs` territory for its slug match; a
consumer whose docs environment is not instantiated is exit 2, never a silent fall-through to the dev
checkout (`round2-measurement.md:84-90`, A8). The dev checkout
must be *registered* rather than baked into the shim because `install` runs from the pinned copy,
which cannot know where the owner's checkout is, and `SHIM.HASH` requires the installed body to equal
`bin/gbg` byte for byte.

**Dominated.** *One clone in Dropbox + `~/.gbg/tools` symlink* (round1-consumer): fails a fresh clone
(nothing reports the missing policy), deadlocks a staged upgrade (one checkout at one tag fleet-wide
while `bump` is refused under an open round), and a checkout on one host flips the other's within
seconds (`round2-maintainer.md:53-90`, S1–S5). *Per-machine clone + `git worktree` per tag*
(round1-measurement): three copies of one tag per machine, one of them writable, that a doctor must
prove byte-equal — the twin class the tool exists to abolish (`round2-maintainer.md:92-101`).
*Plugin marketplace*: no per-project pin, no auto-install on clone, no Workflow shipping
(`facts-claude-code-platform.md:114,121,370-372`). *Private Julia registry*: strictly better once there
are several releases; **deferred**, a pure upgrade of D3's pin syntax. *Julia 1.12 workspaces*:
would collapse the sub-environment entries to one; **deferred**, untested in the fleet. *A dev-checkout
path substituted into the shim at install time*: breaks `SHIM.HASH`, which is why the path is a
separate one-line file. *Selecting the depot slug whose `Project.toml` version equals the pin* (the
first draft): a weaker match than Pkg's own resolution — two slugs at one version are told apart only
by the manifest, which that shim never read.

### D3 — Binding: `[sources] url + rev` (https) rendered from one pin into every sub-environment that lists the tool, `[compat] = "=x.y.z"` as a second witness, the pinned tree re-hashed

**Choice.** `.gbg/config.toml [tool] version = "1.0.0"` is the source. `gbg sync` renders into
**every `Project.toml` under the consumer whose `[deps]` lists `GBGCodingTools`** — `test/`, `docs/`
and `benchmark/` by default, and any further sub-environment that lists it (PF's `test/gpu/*`,
`benchmark/gpu/*`, `examples/` if they ever do):

```toml
[deps]
GBGCodingTools = "<uuid>"
[sources]
GBGCodingTools = {url = "https://github.com/GrigorySarnitsky/GBGCodingTools.jl.git", rev = "v1.0.0"}
[compat]
GBGCodingTools = "=1.0.0"
```

The URL is **https** — CP's and IT's CI rewrite only `https://github.com/` through
`url.<token>.insteadOf` (`round2-maintainer.md:24-26,70-72`); an SSH form would break the existing
auth. **Tags are immutable:** `gbg release` refuses to re-tag. **`PIN.TREESHA`** compares the
`git-tree-sha1` recorded across every sub-environment `Manifest.toml` that exists (`docs/`,
`benchmark/`, and `test/` when `Pkg.instantiate()` wrote one — `Pkg.test()` writes none) with the
`tree_hash` that `Pkg.dependencies()[uuid]` reports for the copy the `docs/` environment resolves:
WARN for a sub-environment without a manifest, FAIL on disagreement.
**`gbg self verify`** — run at the start of every `gbg round` verb and of `gbg gate` — recomputes the
git tree hash of the copy it is running from (`pkgdir(GBGCodingTools)`; blob and tree hashing in
Julia on the `SHA` stdlib, `src/TreeHash.jl`, no `git` needed), compares it with
`Pkg.dependencies()[uuid].tree_hash` and the manifests' `git-tree-sha1`, and asserts that entry's
`is_tracking_repo && !is_tracking_path` — a `Pkg.develop`'d copy lives INSIDE the depot at
`~/.julia/dev`, so a path-prefix test cannot tell it from a fetched one: an edited or dev'd pinned
copy is **exit 2**; no manifest to compare against is WARN; a `dev` pin skips it with WARN.
`ROUND.toml` records the computed hash as `tool_tree_sha`. The tool is never a `[deps]` of the package
proper (`theory-patterns.md:148-149`).

**Forced by.** R8, R1/R4 (immutable ref, `theory-patterns.md:25-27`), R2 (`git log -p
test/Project.toml` answers when the pin moved). `[sources]` is honoured only when that project is the
active environment — exactly the sub-environment cases (`theory-patterns.md:144-146`; `Pkg.test()`
verified, `round2-maintainer.md:10-17`). A sub-environment left out of `sync` resolves the tool
outside the pin, silently (attack 10.3), so the walk covers every one that lists it. Nothing but a
re-hash can tell an edited read-only tree from the tag it claims (attack 4.1): `tool_rev` is read from
a manifest an edit never touches.

**Dominated.** *`~` symlink / env var / plugin root*: machine state, invisible to git. *`[sources]
path = ../../AI Helpers/…`*: binds to whatever is checked out, so the pin is not a pin, and breaks CI
and clones outside Dropbox. *Submodule*: two-step clone, Dropbox does not carry `.git` state reliably
(`theory-patterns.md:33-35`). *Vendored copy*: the disease. *A `TREE.sha256` shipped by `release`*:
a second artefact to keep honest, where the manifests already carry the hash Pkg computed.

### D4 — Pinning: fleet-wide one version is the rule; the per-consumer pin is what makes it checkable; a dated window

**Choice.** All four pinned consumers pin the same `MAJOR.MINOR.PATCH` (the tool's own fleet row, D15,
is the tree they pin and pins nothing). Detection: `gbg doctor` in a consumer
(pin ≠ resolved version, entries disagree, tool `dev`'d in a manifest); `gbg fleet` from the dev
checkout (reads `fleet.toml`, one row per consumer; a `path` that does not exist is **exit 2**, never a
skipped row); a round's `ROUND.toml` names its version, so `gbg fleet --diff` (below) refuses unequal
`MAJOR.MINOR`. An upgrade is a **sweep**: `gbg bump` in the canary (PF), its full gate, then the other
three. Two distinct pins are tolerated for a **7-day window** and fail afterwards; the window is
checked by `gbg fleet` and by `gbg bump`, and it is `gbg bump` that starts it — a bump that would
leave the fleet at two versions records the window start in `fleet.toml` `[sweep]` (`started`,
`from`, `to`). `preflight` does **not** check the fleet: a consumer has no `fleet.toml` and no
network is assumed. `gbg bump` refuses (exit 2) while a round is open unless
`--abandon-open-rounds "<account>"`. `gbg fleet` reports every pinned consumer at `1.0.x` after
migration; its fifth row, the tool's own, is the tree they pin (below).

**The `gbg fleet` output contract.** One row per `fleet.toml` consumer, `<name>  <pin>  <status>
<detail>`, with `status` one of: `OK` — `.gbg/config.toml` present, its `QUICK` doctor set green (the
whole table under `--deep`) and its pin equal to the fleet's newest pin; `NOT-INITIALISED` — the
consumer path exists but holds no `.gbg/config.toml` (a consumer before `gbg init`; `<pin>` prints
`—`); `BEHIND` — its pin is older than the newest pin in the fleet (`detail` names both pins and the
window state: `within window` while `[sweep].started` is less than 7 days old, `window closed` after,
`no window` when `[sweep]` is absent — the normal state of a converged fleet and of a fresh dev
checkout); `RED` — its doctor fails (`detail` lists the failing ids). Exit 0 when every row is `OK`;
1 when any row is `NOT-INITIALISED`, `RED`, or `BEHIND` outside the window (`BEHIND` within the window
is printed as a WARN row and keeps exit 0); 2 for a `path` that does not exist or a missing
`fleet.toml`. **The tool's own row.** `fleet.toml` carries `[[consumer]] name = "GBGCodingTools",
path = "."` (D15), so the fleet lists the tool as its fifth row: `<pin>` prints `dev+<sha>[-dirty]`,
`<detail>` says `clean at vX.Y.Z` or `off tag`, and `status` is `OK` or `RED` by its own doctor alone
— the row is excluded from the newest-pin computation and `BEHIND` is never computed for it, since it
is the tree the other rows pin rather than a copy of it.
`gbg fleet --diff <consumer>:<round> <consumer>:<round>` prints two closed rounds'
tallies side by side (the two may sit in one consumer) and refuses (exit 2) when their
`tool_version`s differ in `MAJOR.MINOR` — the cross-version comparison R11 forbids. It is not
`gbg round compare`, which has exactly one meaning: the Step-0 comparison of a re-graded imported
round against a hand-transcribed record (§8).

**Forced by.** R1, R2, R4, R11 (comparable only at one version, `theory-patterns.md:99-101`), and R9:
a sweep is sequential, and a PATCH released for a defect Phase 5.1 finds may land while PF is
mid-round, so two versions must coexist briefly and visibly (`round2-maintainer.md:74-82,117-123`).

**Dominated.** *Per-consumer pins, no fleet rule*: R11 fails. *Fleet version read from the dev
checkout, no per-consumer pin*: not checkable on a clone. *`preflight` polling `git ls-remote --tags`*:
a network dependency inside a skill's `!` block, and offline it degrades to a WARN nobody reads.

### D5 — Config: one TOML file, one layer, one validator (Julia), Workflow args rendered by the CLI

**Choice.** `.gbg/config.toml` (not under `.claude/`, which is Claude Code's discovery namespace).
Format TOML (the `TOML` stdlib). Schema `schema/config.schema.json`: closed keys
(`additionalProperties: false`), explicit `required`, closed enums; unknown key, missing required key,
unknown enum member, a path that does not exist → exit 2. **No layering**: no local file, no env
overrides, no defaults hidden in code — `gbg init` materialises every default into the file; machine
facts (`hostname`, GPU vendor, `Threads.nthreads()`) are read at run time and shown by
`gbg doctor --effective`. **One validator, in Julia**: `src/CLI/Schema.jl` is the JSON-Schema-subset
validator (types, `required`, `enum`, `pattern`, `additionalProperties`, nested objects and arrays)
applied to the `TOML.parsefile` Dict — no JSONSchema.jl dependency, the subset being small and a
dependency being a second implementation to trust. `Config.read()` is that validator called
in-process, defaults materialised; `gbg config --toml|--json` print the same validated object for
humans and scripts, and nothing else parses the config.
Config reaches Workflow scripts **only** as the `args` object the CLI renders — by ONE renderer,
`Preflight.jl`'s, which `gbg preflight` and `gbg round pass open` both call. The FIVE rubric variation
points are config enums (§1); everything else the rubric says is a platform constant or a ledger
deviation. The one schema extension point is `[schema] finding_types_extra`.

**Forced by.** R3, R11, R2, R7 (`facts-claude-code-platform.md:163-174`: args only). Four copies of
one surface list inside PF alone (`survey-checkdocs.md:112`); the layering trap
(`theory-patterns.md:129-131`). Two validators is the twin class (`round2-maintainer.md:173-182`). A
threshold or an idiom string in config is the R1 divergence channel with a schema around it (attack
9.1, 9.2): IT at 5 and PF at 3 under one rule id would be two rules.

**Dominated.** *JSON*: no comments, and the ledger carries prose reasons. *YAML*: no stdlib parser.
*`Project.toml [gbg]` table*: Pkg rewrites the file; Aqua flags it. *Layered defaults/local/env*:
archaeology. *A typed `ConsumerConfig` struct with hand-written unknown-key rejection beside the schema
file*: two implementations of one schema. *JSONSchema.jl*: a dependency to trust for five keywords.

### D6 — Skills: generated per-consumer stubs, bare names, `!`-block preflight, protocol injected, consent as a session rule

**Choice.** `gbg sync` renders one stub per enabled instrument, `.claude/skills/<name>/SKILL.md`,
hash-managed, bare names `/check-docs`, `/check-consistency`, `/bug-hunt`, `/audit-changes`, plus
`/gbg-doctor`. Frontmatter carries `allowed-tools: Bash(gbg *)`; **model invocation is enabled** (no
`disable-model-invocation`). Body: one `!` block running `gbg preflight <instrument> $ARGUMENTS`;
a non-zero exit aborts the skill before any protocol text reaches the model (fail-closed by the
platform, `round2-consumer.md:22-26`, F2). `/gbg-doctor` is not an instrument: its body is the one
`!` block `gbg doctor`, and `SKILL.md.tmpl` says so. Preflight validates config, runs the quick doctor
(the `QUICK` set, §7.3) and `gbg self verify`, refuses on an open round of that instrument / a pin
mismatch / an uncommitted change under a **closed or abandoned** round (an open round's files are
expected to change), **opens the round** (writes `ROUND.toml`; never `git add`), and PRINTS (a) the
protocol text for this instrument (`instruments/<name>/PROTOCOL.md`), (b) the exact
`Workflow({scriptPath, args})` call, (c) the next-step line. The model therefore never reads a file
outside the project, so no permission prompt and no slug-dependent path ever reaches it. The `!`
block pays one Julia start — ~2–5 s including package load, plus `Pkg.instantiate()` on a fresh
clone — once per instrument invocation, noise against the agents' minutes; no PackageCompiler
sysimage (per-GPU-architecture builds on two machines, rejected as uncosted). The **consent
gate** ("an instrument runs only when the user asks, in words or by slash; never unasked") is a session
rule stated in the managed `CLAUDE.md` block, together with the entry-point sentence "'check the docs'
means run `/check-docs`" — not a skill flag, because a user who says "check the docs" has asked
(`round2-consumer.md:406-408`). The tool's own `.claude/skills/` is rendered by the same `gbg --dev sync`
at its root (D15), so a session opened in the tool repository runs `/check-docs` and the other three
over the tool's own docs and code, with the same stubs, protocol injection and consent rule.

**Forced by.** R6, R2 (the stub header carries the version, so `git log` of the stub answers which
protocol a session would load), R3, and the plugin limits (`facts-claude-code-platform.md:114,121,62`).

**Dominated.** *Personal-scope symlinked skills, one per instrument under `~/.claude/skills/`*: deliver the checkout's
protocol, not the consumer's pin (R4); apply to every project on the machine; the `gbg-` prefix costs
every `/check-docs` reference in four corpora for a shadowing benefit that does not exist
(`round2-consumer.md:27-31`, F3). *Plugin skills `/gbg:…`*: untested local marketplace, out-of-tree
copy, second version. *Rendered protocol text in the stub*: the "readable source of truth" copy that
rots (`survey-checkdocs.md:104`). *Model reads `<root>/PROTOCOL.md`*: a path outside the project,
prompting for `Read` and changing every bump (`round2-maintainer.md:192-198`).
*`disable-model-invocation: true`*: withholds the description and blocks the model, so "check the
docs" in prose hand-rolls the battery (`round2-consumer.md:15-21`, F1).

### D7 — Workflow scripts: one generic engine per instrument, args-driven, catalogues as data, liveness only

**Choice.** `instruments/<name>/workflow/*.js` live in the tool only. They are invoked through a
COPY that `gbg preflight` (and `pass open`) writes into the project, `.gbg/scratch/<round>/workflow/`
(gitignored), and names as `scriptPath`; the pinned copy under `~/.julia/packages/` is never named
directly. V1 (2026-09-09, `Aiporetne`, §11) is why: the Workflow tool accepts an outside-project
`scriptPath` only for a file the session may already read — a session scratchpad, or a file it has
`Read` — and refuses a fresh absolute path elsewhere ("scriptPath must be a script path this tool
returned, or a file you can already read"); a `Read` of the pinned copy is exactly the out-of-project
read D6 forbids. A path inside the working directory needs neither. No package string in
any script: description, deliberate absences, surfaces, hats, lanes, oracles, claims arrive in
`args`. **Payloads are files, args carry paths** (Revision 9, 2026-09-09): a Workflow script has no
filesystem and its `args` are re-emitted verbatim by the session from the text preflight printed, so a
manuscript, a diff, a rulebook or a persona can never travel inside `args`; preflight (and `pass open`)
writes every such payload under `.gbg/scratch/<round>/workflow/payload/` and `args` names the paths,
and each agent's prompt lists exactly the paths it may `Read` under `.gbg/` — nothing else there and
nothing under `~/.gbg/`. The forbidding of `.gbg/**` therefore reads "except the payload paths named
in your args"; during the panel the payload directory holds only the seeded manuscripts, the rulebook
and the personas, and the ground truth is written at bank, so the exception exposes no answer key. Catalogues are data — `catalog/hats/*.toml` (generic hats with `{package.*}` placeholders:
the eight shared by PF and IT — `consistency-matrix`, `software-architect`, `structure-consistency`,
`latex-typesetter`, `api-user`, `citations-integrity`, `style-editor`, `cold-reader` — IT's generic
lenses, and the three **rulebook hats** `naming-policy`, `doc-policy`, `invariants-and-decisions`,
whose rulebook-section placeholders are filled from `[package] rulebook_sections`),
`catalog/lanes/*.toml`, `catalog/scans.toml`; a consumer's domain hats are `.gbg/hats/*.toml`,
validated by `schema/hat.schema.json`, refused if a persona names another fleet package. Every agent
a script spawns — hats and verifiers alike — is forbidden to open `.gbg/**` and `~/.gbg/**`. Scripts
**return liveness only** (`{written, dead, empty, truncated}`) and never a tally; the CLI computes
every count from files. No census agent, no `hats.json`. Bug-hunt partition: config **territories +
two free lanes always present and anchored**.

**Forced by.** R7, R10, R11. The coupling is data: `panel.js`'s 22 package hits sit inside persona
strings and one preamble (`survey-check-consistency.md:199-209`); `audit.js`'s IT preamble still says
"605 lines inserted" on every run (`survey-bughunt-auditchanges.md:172`). The denominator never comes
from the graded party (`survey-check-consistency.md:279`); a census agent was a workaround for the JS
not seeing files, which the CLI can (`round2-measurement.md:140-143`, A16). IT's own measurement:
unconstrained readers beat eight class lanes at a third of the cost (`survey-bughunt-auditchanges.md:193`).
A rulebook hat with two homes (catalogue and `.gbg/hats/`) is the twin class again; it has one.

**Dominated.** *Per-consumer scripts*: the drift generator. *Hats as JS constants*: a release to add a
domain hat (R10). *Scripts that tally*: grader tallies itself (`survey-check-consistency.md:281`).
*Absolute `scriptPath` into the pinned copy* (the first draft's choice, verified from a scratchpad on
2026-09-06): refused for a fresh path outside the project on 2026-09-09 (V1); the in-project copy,
drafted as its fallback, is the rule.

### D8 — Deterministic helpers: one Julia CLI `gbg <noun> <verb>`; exit 0/1/2/3; one text-scan engine

**Choice.** Julia, inside the package (`src/CLI/*.jl`, one module per noun), for everything that reads
text, piles, git, HTML, config. `GBGCodingTools.main(ARGS)::Int` is the one entry point; every verb is
a Julia function returning the exit code; an uncaught exception is caught at `main` and returns 3.
Exit codes everywhere: **0** clean; **1** substantive finding (a hit, an open round, a stale audit); **2** cannot
evaluate (missing config, missing round, hash mismatch, version drift, **a dead lane**, UNCHECKABLE, a
missing path); **3** tool crash (uncaught exception — never read as a finding). Never `0` with a
printed problem; never truncated output. Scans are catalogued in `catalog/scans.toml` (the full list
with ids is §12.B) with tier `hard` (must be empty) or `triage` (printed, never fails; exit 2 if it
scanned nothing); tier is not consumer-configurable — a consumer silences a scan only by a ledger
entry. **ONE text-scan engine** (`gbg scan docs`, `src/Scans/`, one function per scan id — Julia now, with no
Python twin): the docs-build wrapper carries no regex twins of its own (D9). **The one transitional
Python file was `consolidate.py`** — the HTML-to-manuscript consolidator the three consumers shared
byte-identically — kept INSIDE the tool (a versioned script in the one package still satisfied "one
engine"; a consumer copy would not) until its Julia port (`Gumbo.jl` + `AbstractTrees`; Gumbo's C
parser is unmaintained and has no CSS-selector traversal, so the walker is hand-rolled tree walking)
was BYTE-COMPARED against it on a real PF and IT build. That comparison was the acceptance test
(Phase 1.6); it passed on 2026-09-09 on 18 PF pages and 22 IT pages, all four manuscripts byte-equal,
and the Python was deleted in that commit. `gbg scan html` (rendered-markup, docstring-once,
public-home, base-leak) uses the same ported walker. This was the riskiest single port in the plan and
was scheduled with the fallback in hand.

**Forced by.** R3 (exit 2 is the missing case, exit 3 keeps a crash from reading as a finding —
`round2-maintainer.md:205-209`); lessons 1–3 (`survey-checkdocs.md:200-202`); `guards.sh` hard-coding
nine filenames (`survey-checkdocs.md:108`); the two `gate.py` with incompatible piles
(`survey-bughunt-auditchanges.md:237`); the cross-language scan twin surviving in every proposal
(`round2-measurement.md:360-364`). Julia rather than the first draft's Python: one language, one test
suite, and no `python3` in any consumer's CI; the cross-language twin lesson (`survey-checkdocs.md:207`)
applies across languages inside one repository exactly as it did across repositories, and a CLI in a
second language is that twin waiting to happen.

**Dominated.** *A Python CLI* (the first draft, retired 2026-09-08): its one argument was a 30 ms start
inside a skill `!` block and a Stop hook; the hook is now pure `sh` and starts no Julia at all (D13),
and the `!` block pays the Julia start once per instrument invocation (D6) — against which a second
language, a second test suite and a `python3` step in four CIs bought nothing. *Loose scripts*: the
status quo. *Bash scans*: `guards.sh`'s awk.

### D9 — Julia side: `GBGCodingTools` with `makedocs` wrapper, `TestHarness`, `Reflection`, `Witnesses`, `Config`; `julia = "1.11"`

**Choice.**
- `GBGCodingTools.makedocs(cfg; kwargs...)` — the **mandatory** wrapper a consumer's `make.jl` calls
  instead of `Documenter.makedocs`; declared `function makedocs end` in the main module and defined by
  the extension `ext/GBGCodingToolsDocumenterExt.jl`, which loads with `Documenter` (the weak
  dependency below). It calls `doctor(:QUICK)` (a set without `CFG.TORN`, so an uncommitted managed
  file never refuses a docs build), `scan_docs(hard_only = true)` and
  `gate("check-docs", "check-consistency")` **in-process** before Documenter, then
  `scan_html(build_dir)` (the rendered-markup and built-page checks) and
  `gate("check-docs", "check-consistency")` again after — the same Julia functions the CLI verbs
  `gbg doctor --only QUICK`, `gbg scan docs --hard-only`, `gbg gate …` and `gbg scan html` wrap, no
  child process — and `error()`s on any non-zero return, EXCEPT the one refusal that is not a breakage:
  a gate that refuses only because a round of a docs instrument is open prints `makedocs: SKIPPED` and
  returns `nothing`, exit 0, so a red docs build keeps meaning something is broken rather than meaning a
  round is open. `GBG_DOCS_NO_SKIP` restores the refusal, and `gbg release` and the deep doctor set it,
  so no release accepts a build that did not happen. The gate is reachable on a CI runner with
  no shim. The docs instruments' gate, never the bare four-instrument `gate()`, so a docs build does
  not fail on an open hunt. It writes the derived public surface
  (`Reflection.package_operations()`) to `.gbg/scratch/public_surface.json` for `scan_html`.
  It prints one banner line `GBGCodingTools v<ver> makedocs` (`BUILD.DOCS`'s witness).
  `gbg doctor` fails on a **bare** `makedocs(` in `make.jl` (`WIRE.MAKEDOCS`, a token check that
  strips comments and strings). The tool's own `docs/make.jl` calls this same wrapper —
  `WIRE.MAKEDOCS` applies to the tool itself (D15) — with `checkdocs = :exports` and
  `doctest = true`, so every docs build of the tool runs the quick doctor, the hard scans over the
  tool's own surfaces and the gate. **This wrapper is the per-push, harness-independent enforcement
  point, and deliberately so:** every consumer's `docs.yml` runs on every push while its `CI.yml` is
  manual and tag-only (`RULE.GIT.CI_MANUAL`), so a later "simplification" that moved the doctor, the
  hard scans or the gate out of the docs build and into the manual CI would take them off the one
  lane that runs unasked — for the tool's own `docs.yml` exactly as for a consumer's.
- **The tool's own Documenter site** (D15). `docs/Project.toml` in the tool: `[deps] Documenter,
  GBGCodingTools` with `[sources] GBGCodingTools = {path = ".."}` (the bootstrap circularity is stated
  once, in D2); `docs/make.jl` calls `GBGCodingTools.makedocs(GBGCodingTools.Config.read(); sitename =
  "GBGCodingTools", checkdocs = :exports, doctest = true, …)` — the same mandatory wrapper every
  consumer uses. Pages: `index.md` (what it is, install, the design sentence), `guide/install.md`
  (bootstrap, shim, `~/.gbg/dev`), `guide/verbs.md` (the closed verb table, rendered from the
  `src/CLI/` docstrings through `@docs` — the same source as the implementation plan's verb table, so
  the two cannot drift), `guide/rounds.md` (the round lifecycle, closure channels, exit codes),
  `guide/doctor.md` (every check id with its fix hint, generated from the doctor's own table),
  `guide/ledger.md` (`[[exemption]]` and `match`), `guide/config.md` (the schema rendered),
  `api/TestHarness.md`, `api/Reflection.md`, `api/Witnesses.md`, `api/Config.md`, `api/CLI.md`, and
  `architecture.md` (a copy of `docs/ARCHITECTURE.md` produced at build time, like the consumers'
  rationale pages). `.github/workflows/docs.yml` deploys on push to `master`; the repository is
  private, so GitHub Pages must be enabled by the owner — an action of the implementation plan's
  Phase 0 — set up exactly as the four consumers' sites are (owner ruling 2026-09-08, Q14: private
  repository, `gh-pages` source, site public by URL; owner-only Pages is an Enterprise feature the
  account does not have) — and the docs build is the tool's per-push enforcement point exactly
  as for a consumer. **Every public binding of the tool carries a docstring written to the shared
  rubric** — `main`, every verb function, `makedocs`, every `TestHarness`/`Reflection`/`Witnesses`/
  `Config` export, every schema struct — and the module docstrings are maps; `checkdocs = :exports`
  is what fails the build on a missing one. The tool's own `CLAUDE.md` carries the managed policy
  block, rendered from its own `policy/`, plus its package-specific content — the design sentence,
  the freeze rule, the release checklist (D12).
- The prose-shape ratchet is a scan like any other (`src/Scans/ProseShape.jl`, `catalog/scans.toml`
  entry `SCAN.PROSE_SHAPE`), one CSV schema
  `docs/prose_shape.csv` (`unit,kind,total_words,longest_paragraph_words,admonitions`; kinds
  `docstring|page|section`): IT's always-binding caps (120 words / 3 admonitions on every docstring),
  PF's page and section units, IT's structure checks (`# Arguments` before any column-0 `!!!`,
  `# Fields` last); a missing CSV is an error — `gbg init` and
  `gbg scan docs --rebaseline prose-shape --reason …` are the ONLY writers.
- `TestHarness`: `@alloc_below` + derived allocation completeness, `CountingArray`/`Traffic`/`audit`,
  method-parity engine (frozen tables stay in the consumer), oracle-registry engine,
  `Reflection.package_operations()`, which it CALLS and does not define (ownership-derived public
  surface — the constant `derived` route; the
  `names()` route PF found blind to extended generics is not offered), `run_regressions(dir)` (the one
  wrapper-module include loop), display gate with IT's `UnionAll` fix, cross-thread subprocess bitwise
  check, `gate()` (calls `doctor(:QUICK)` and `gate("bug-hunt", "audit-changes")` in-process,
  `error()`s on a non-zero return, and prints the banner line
  `GBGCodingTools v<ver> gate` — `TEST.PKG`'s witness).
- `Reflection`: `argcov` (PF's exemption classes + IT's Greek identifiers + `arg = default` form; the
  "Allocating form of" exemption phrase and the ≥ 3 threshold are constants), `signature_fidelity`,
  `xlink` (dry-run default), `dupref`, `public_surface` derivation.
- `Witnesses.run(dir; expect = :fail | :pass, names)`: quoted paths, `Base.julia_cmd()`, BROKEN ⇒
  non-zero, BLOCKED recognised (a `# blocked: <reason>` header is REQUIRED), subset filter, empty ⇒ 2,
  PF's zero-assertion guard (a PASS with no assertion reads BROKEN), and it **refuses a witness that
  `include`s any file or that loads anything outside the package under test, `Test` and the stdlib** —
  the only admissible loads are `pkgdir`-relative package loads, so a witness cannot be weakened
  through a helper it includes.
- `Config`: `read()` = `TOML.parsefile` of `.gbg/config.toml` validated by the one validator
  (`src/CLI/Schema.jl`, D5), defaults materialised, every path checked — the object `gbg config --toml`
  prints, obtained without a child process.
- Compat `julia = "1.11"`; the tool's CI (manual + tags) runs `Pkg.test()` on 1.11 and 1.12
  (`juliaup add 1.11` on one host) AND the tool's own docs build, with no consumer checked out (D15);
  consumer floors untouched (SS stays 1.11). **`Documenter` is a weak dependency**: `[weakdeps]` +
  `[extensions]` (`GBGCodingToolsDocumenterExt = "Documenter"`; Julia 1.11 supports extensions) with
  `ext/GBGCodingToolsDocumenterExt.jl`, the main module declaring `function makedocs end` and the
  extension defining `GBGCodingTools.makedocs(cfg; kwargs...)`; a consumer's `make.jl` already does
  `using Documenter`, so the wrapper is present in the docs environment and nowhere else. A hard
  dependency would have made every consumer's `Pkg.test()` resolve and install Documenter through
  `test/Project.toml`, let the tool's bound constrain every consumer's test AND docs resolution
  fleet-wide, and loaded Documenter before every shim call, `gbg doctor` included. Its **compat bound
  is kept** under `[compat]` (CP resolves 1.19 against 1.17 elsewhere, `round2-consumer.md:181-184`);
  `WIRE.MAKEDOCS` is unchanged. The tool declares its own `[deps]`/`[compat]`
  minimally: the stdlibs `TOML`, `SHA` (the tree hashing of D3), `Dates`, `Pkg` (the pin checks and
`self verify` read `Pkg.dependencies()`), `Random` (the pass nonce) and `Test`, plus `JSON3` (the
  round artefacts — there is no JSON stdlib at the 1.11 floor) and `Gumbo` + `AbstractTrees` (the HTML
  walker behind `scan_html` and the consolidator, D8) — both hard dependencies; no JET/Aqua dependency —
  those stay consumer test deps, so the tool does not inherit SS's `LoweredCodeUtils` pin problem
  (`round2-consumer.md:159-164`). No consumer CI carries a `python3` step.

**Forced by.** The lint matrix — nine lints in PF, four in IT, one in SS, none in CP
(`survey-buildlints-hooks-policy.md:13-33`); the harness matrix — PF-only guards and copies with drift
(`survey-buildlints-hooks-policy.md:150-171`); R6; the twin rule (`survey-checkdocs.md:207`); a wiring
grep satisfied by a commented-out call (`round2-maintainer.md:253-257`); the gate unreachable in CI
through a shim (`round2-measurement.md:75-82`, A7); a witness weakened through an included helper
(attack 6.2).

**Dominated.** *Lints kept in each `make.jl`*: the status quo. *Separate harness package*: a second pin.
*`julia = "1.12"` and collapse SS*: not evidence, a `juliaup add 1.11` away. *The bare four-instrument `gate()`
in the docs build*: fails a docs build on an open hunt round (dry-run 17).
### D10 — Rounds: tracked, one layout, CLI-written marker, frozen denominator, hash-bound verdicts, per-finding closure

**Choice.** `.gbg/rounds/<YYYY-MM-DD>-<instrument>-<NN>/`, **tracked** for all instruments and
consumers, the tool's own `.gbg/rounds/` included (D15). Contents (§6 has formats): `ROUND.toml` (written only by the CLI); `findings/NN-<lane>.json`
(written by lane agents FIRST, schema-forced); `findings.json` (CLI-frozen union, ids
`<round>/<lane>#<n>`, sha256); `findings.md`, `tally.md`, `SUMMARY.md` (CLI-rendered reading aids,
tracked, never the work list); `verdicts/pass-<k>/{pass.toml, act/*.json, state/*.json, tally.json}`;
`ground_truth.json` (seeded rounds, written at BANK); `witnesses/` and `reproductions/` (bug-hunt);
`audit.json` (audit-changes); `import.json` and `recorded.toml` (Step-0 scratch imports only, §8 —
never committed: no consumer carries a pre-tool round, owner ruling 2026-09-08). Manuscripts
and seeded copies live **inside the project**, under
`.gbg/scratch/<round>/` (gitignored) — never under `~/.gbg/`, where a Workflow agent's `Read` prompts,
and never in the tracked round. **Staleness by hash, not mtime**: every verdict file carries
`graded_sha256` (= the sha of `findings.json`) and the `pass_nonce` from `pass.toml`; mismatch →
REJECTED; absent → DEAD. Roster and denominator come from `ROUND.toml` and `findings.json`, counted
by the CLI. A lane file is classified at `bank`: **DEAD** (absent, or unparsable or schema-invalid, which
quarantine the file as `NN-<lane>.rejected.json` — or zero findings with an empty `checked[]`), **EMPTY**
(zero findings, non-empty `checked[]`), **ORPHAN** (a lane file no roster entry expects; reported,
never counted), **TRUNCATED** (`candidates_found > findings.length`; reported, not fatal),
**REJECTED** (a live lane whose sha changed after first sight). A DEAD **or REJECTED** lane is **exit 2** — cannot
evaluate — and nothing is frozen. Closure is per finding id through four channels (§6.5); the
wholesale escape is `gbg round abandon --reason`, which lists every open id. `.gbg/rounds/` is the
SOLE closure record: the tool never reads a work-queue file for **closure** — the Stop hook of D13,
present in every consumer, reads `.claude/WORK_QUEUE.md`, since the hook is not closure (that file is
a session work-item list outside the closure record); IT's `WORK_QUEUE.md`-as-register, its `review-rounds`
marker and both `lint_review_closure`s are retired; and IT's `adjudicated.md` prose list is withdrawn
in favour of finding-scope ledger entries with `overturn_when` (§7.2).

**Forced by.** R2, R3; the two agreed constraints (`survey-check-consistency.md:301`: a script both
builds call; fail when the expected pile is absent); each existing gate has the hole the other closed
(`survey-check-consistency.md:252-254`); mtime is checkout time on a fresh clone, so an mtime gate is
wrong in both directions exactly where R2 re-grades (`round2-measurement.md:147-157`); copy-forward
verdicts pass a hash-only check, hence the nonce (`round2-measurement.md:21-30`, A1); untitled
findings cannot be adjudicated by title (`survey-check-consistency.md:254`); a malformed lane file that
can neither bank nor rerun (attack 2.5).

**Dominated.** *Untracked pile + tracked marker (IT)*: certifies only that a human wrote an account.
*Gitignored pile + `CLOSED.md` (PF)*: vacuous on a clone. *Markdown as the record with one fenced
block*: a second parser and a count-agreement failure mode; markdown is a render. *`git add` at open*:
a tool must not stage into the owner's index (`round2-consumer.md:100-105`). *Manuscripts under
`~/.gbg/state/`*: outside the working directory, where D6's own argument says a `Read` prompts, and
the unseeded manuscript beside the seeded one is a one-line `diff` (attack 3.4).

### D11 — Schemas: one JSON Schema per artefact kind in `schema/`; closed union vocabularies; `schema_version` on every artefact

**Choice.** Eighteen schemas: `schema/{config,exemptions,hat,round,pass,finding,verdict-act,
verdict-state,tally,reproduction,dismissal,architecture-fix,audit,ground-truth,import,managed,carried,
severity}.schema.json`. An instrument's `instruments/<name>/schema.json` is its `args` object plus its
lane-file wrapper and `$ref`s `finding.schema.json` for the findings array; the lane-file wrapper and
`bug-hunt`'s candidate-file shape live inline in each instrument's own `schema.json`, not as files
under `schema/`.
Vocabularies (constants, §6.3). `finding.type` = core enum + `domain_type` from
`[schema] finding_types_extra`. Every artefact carries `schema_version` (= the tool's MAJOR). Changing
any vocabulary is MAJOR.

**Forced by.** R11; `dismissals`/`closure`/`finished` all key off the hunt verdict set
(`survey-bughunt-auditchanges.md:263`); `coverage.py` already anticipates a union
(`survey-check-consistency.md:249`); every measured distinction is kept (`round2-measurement.md:209-223`).

**Dominated.** *Configurable vocabularies*: divergence inside the schema. *Intersection*: loses
`PARTIAL`, `ADJACENT`/`INSERTED`, `REGRESSED`, `NO-WITNESS-POSSIBLE`. *Open extension
(`x_<pkg>` objects)*: fields nobody reads.

### D12 — Policy prose: single source `policy/*.md` with rule ids, copied into `.gbg/policy/`, one managed `CLAUDE.md` block with a relative import

**Choice.** `policy/00-index.md`, `docs-rubric.md`, `latex-idiom.md`, `citations.md`,
`testing-protocol.md`, `instruments.md`, `git-conventions.md`, `glossary.md`; every rule has a stable id
in the `RULE.` namespace (the full table is §12.A — `RULE.DOC.*`, `RULE.TEX.*`, `RULE.CIT.*`,
`RULE.API.*`, `RULE.TEST.*`, `RULE.INST.*`, `RULE.GIT.*` — so no rule id can collide with a doctor
check id such as `GIT.BRANCH`), recorded in `policy/RULES.toml`. `gbg sync` renders them to `.gbg/policy/*.md` (hash-managed): the enumerated
variation points (`rubric.leading_identity`, `notation.vectors`, `docs.admonition_titles`,
`notation.mathbf_allowed`, `instruments.check-docs.argcov_policy`) are substituted so a hat reads ONE statement; everything else is verbatim;
`deviations.md` is rendered from the ledger. `CLAUDE.md` carries one managed block:

```markdown
<!-- gbg:managed begin v1.0.0 sha256:… — rewritten by `gbg sync`; do not edit -->
@.gbg/policy/00-index.md
## GBGCodingTools — this package's parameters and declared deviations
- Package `GBGPeriodicFields`; leading identity: physical-meaning; vectors: component notation.
- Deviations: (none)
- "Check the docs" means run `/check-docs`. Instruments run only on the user's request, in words or by
  slash — never unasked; unasked, run only `Pkg.test()`.
<!-- gbg:managed end -->
```

Package-specific content stays in `CLAUDE.md` outside the block — in ONE section order for every
consumer, `templates/CLAUDE.md.skeleton` (owner ruling 2026-09-09): the managed block, "Modules and
wiring", "Core invariants", the package's own style rules, "Working agreements", and one short "Current
state" paragraph pointing at a tracked `docs/ROADMAP.md`, where live plans go. Finished work is not
kept in `CLAUDE.md` (git history keeps it); `docs/ROADMAP.md` is not a scan surface. `gbg new` seeds the
skeleton; each migration trims to it (the plan's PF-5 and its analogues) — PF's 1500 lines of state and
roadmap and SS's 246 are the reason. The tool's own `CLAUDE.md` is built the same way (D15): the managed
block, rendered from its own `policy/` by `gbg --dev sync`, and outside it the design sentence, the
freeze rule and the release checklist in the skeleton's order. The battery reads the same rule ids: a
ledger deviation on `RULE.TEX.MATHBF` appears in `deviations.md` for the reading model and disables
that scan for the gate.

**Forced by.** R1, R2; the rubric triplicated by hand and quadruplicated inside IT
(`survey-checkdocs.md:182`); an import outside the working directory shows a dialog whose decline is
silent (`facts-claude-code-platform.md:200`, `round2-consumer.md:32-33,71-76`); a copy makes the
rubric diff visible in each consumer's history and present by construction on a clone.

**Dominated.** *`@~/.gbg/tools/…` import*: the dialog, the silent decline, no history. *`.claude/rules/`
as the copy target*: dialog-free too, but the explicit block makes version and boundary visible in
`CLAUDE.md`; noted as an equivalent placement. *Leave each `CLAUDE.md` and diff*: the status quo.

### D13 — Managed files: one sidecar `.gbg/managed.json` as a cache, four classes, wiring checked structurally

**Choice.** One sidecar `.gbg/managed.json` (path → template, tool version, sha256) for **every**
generated file — a JSON file cannot carry a comment header (`round2-maintainer.md:246-248`) — with a
header added where the format allows. The sidecar is a **cache**: `MANAGED.HASH` compares each file
against a FRESH render of the pinned template under the current config, so editing a file and its
sidecar entry together is still MODIFIED. The sidecar also records `inputs_sha`, the hash of the
render inputs (the pin, the config with its hats and ledger, the templates and policy files of the
pinned copy): while it is unchanged a fresh render equals the recorded one, so ANY divergence of a
managed file is a hand edit — MODIFIED whatever its entry says; when the inputs changed (a config edit,
a bump), a file that still equals its recorded sha is STALE and re-rendered, and one that does not is
MODIFIED. Without the inputs hash the two cases are indistinguishable by content hashes alone
(found at implementation, 2026-09-09). The denominator is the pinned version's template list, so a
deleted file and its entry read STALE. Classes: **config** (owned, validated);
**generated-managed** (hash; MODIFIED is refused, never merged); **seeded-once-then-owned**
(created if absent, never touched again, wiring-checked **structurally** — comments and string
literals stripped before the check: `make.jl` must call `GBGCodingTools.makedocs(` and carry no
`makedocs(` token not preceded by `GBGCodingTools.`, `runtests.jl` must call
`TestHarness.run_regressions(` and `TestHarness.gate(`, CI yml must carry the private-dep auth step
and grep both banner lines); **tracked-pile**. Every rendered command that touches
`$CLAUDE_PROJECT_DIR` quotes it (every consumer path holds two spaces). The Stop hook — **in every
consumer, no config switch** (owner ruling 2026-09-09; the former `hooks.work_queue` key is gone) — is a
**generated-managed `sh` file**, `.claude/hooks/queue-guard.sh`
(class G, hash in `managed.json`, rendered by `gbg sync`), and the generated-managed `settings.json`
points at it as `"$CLAUDE_PROJECT_DIR/.claude/hooks/queue-guard.sh"`; its body is **PF's existing
`queue-guard.sh` verbatim**: it guards the `- [ ]` items of `.claude/WORK_QUEUE.md`, keeps the
`stop_hook_active` loop guard, never reads `.gbg/rounds/`, and never starts Julia. `WORK_QUEUE.md`
itself is seeded once (class S, `templates/WORK_QUEUE.md.seed`: the contract header, no items) and owned
by the consumer's sessions thereafter. **The hook guards the work queue; the gate
guards the rounds; the two never overlap.** A hook that blocked the stop while a round was open would
be wrong twice: a round stays open across a whole fix pass (`ROUND.OPEN` says it may span sessions), so
such a hook would block every turn end during a round, the turn in which the session must stop to ask
the owner a question included; and it would silently delete the guard PF relies on. **The Stop hook
never starts Julia** — the former `gbg hook queue-guard` verb is deleted — because a hook runs at every
stop, and a 2–5 s Julia start there is the one place the cost is not noise.

**Forced by.** R6, R9, R1; drift began with editing rendered files (`theory-patterns.md:49-51`); a
grep for a call is satisfied by a commented-out call (`round2-maintainer.md:253-257`, attack 8.2); PF's
unquoted `cd ${REPO}` (`survey-bughunt-auditchanges.md:136`); a sidecar edited alongside the file it
records (attack 8.4).

**Dominated.** *Copier-style three-way merge for everything*: invites edits. *A managed `make.jl`*: the
four carry genuinely different Documenter options.

### D14 — Doctor: read-only, stable check ids, one exemptions ledger with reason + bounded expiry, fleet scorecard, no consumer copies in the tool

**Choice.** `gbg doctor [--deep] [--json] [--effective] [--only <id-or-prefix>[,…]|QUICK]` — the check
table in §7.3; the `QUICK` set runs inside every `gbg preflight`, inside the `makedocs` wrapper and
inside `TestHarness.gate()`, so it is regular. The doctor is **read-only**: where a `--deep` check finds a witness that now passes it PRINTS
"promote" as a recommendation; the session promotes. Ledger `.gbg/exemptions.toml` (§7.2): fields
`id`, `scope ∈ policy|scan|lint|check|finding|harness`, `target`, `reason ≥ 40 chars`, `recorded`,
`expires` (REQUIRED for every scope except `finding`; `expires ≤ recorded + 365 d`; expired → FAIL,
≤ 30 days → WARN), `overturn_when` (REQUIRED for scope `finding` instead of `expires` — the condition
under which the adjudication would be wrong), `evidence`, and an optional `[exemption.match]` table on
the scopes `scan|lint|policy|harness` — ANDed sub-keys `arg_name` (a regex over the argument name),
`arg_type` (the declared type of the matched argument, tested by `<:`; evaluable by the reflection
scans only — a text scan refuses an entry carrying it, exit 2 at `CFG.EXEMPTIONS`, never ignores it),
`path` (a glob), `symbol` (a regex over the owning binding's name) —
under which the entry REFINES the rule (the engine applies the predicate per trigger, reports its
trigger population, and the rule stays live everywhere else) instead of silencing it; `EXEMPT.BROAD`
warns when one `match` covers more than half of a rule's reported trigger population (§7.2). **Non-exemptable** — every check about the
tool's own enforcement: `PIN.*`, `CFG.*`, `EXEMPT.*`, `WIRE.*`, `MANAGED.*`, `SHIM.*`, `POL.*`,
`ROUND.*`, `SELF.*`. **Exemptable**: `LEG.*`, `GIT.*`, `AUDIT.*` and the `scan|lint|harness|policy|finding` scopes
— the one set, restated identically in §7.2 (`AUDIT.*` joined it with `AUDIT.GAP`, which post-dates
ruling 13's list).
`gbg fleet` prints one row per consumer (the row vocabulary and exit contract are D4). No copies of
consumer configs inside the tool repo (no
`contracts/`): the fixture proves the schema; a consumer's config is validated by its own doctor;
the tool's own `.gbg/config.toml` is not such a copy but the tool's config as a consumer of itself
(D15), validated by the same doctor.
Cross-package requests: `.gbg/requests/to-<PKG>-<date>-<topic>.md`, tracked in the requester, status
paragraph at the top — for OPEN requests only: a concluded request is deleted, not kept (owner ruling
2026-09-09; at migration only a request still awaiting the other package moves there).

**Forced by.** R9, R2, R3; `theory-patterns.md:69-77`; exemptions enumerated with reasons and checked
for staleness (`survey-checkdocs.md:211`); a second copy of every consumer's config in another repo is
the disease with a check bolted on (`round2-maintainer.md:266-270`); a dated permanent waiver
(`expires = 2999-12-31`, attack 8.1); a ledger entry that switches the doctor off (attack 8.5); an
adjudicated finding that expires a year later with nothing to decide (attack 2.3).

**Dominated.** *Several ledgers by kind*: three formats, three readers. *No expiry*: a waiver becomes
permanent. *Reviewed-date warning only*: rots invisibly. *Auto-repair in doctor*: `sync` repairs.
*`expires` on finding scope*: reopens nothing (a closed tally is frozen) and fails every build.

### D15 — Self-test: a fixture consumer at a path with a space, pinned `dev`, a must-fail arm per gate, a Step-0 instrument-equivalence test; and the tool as its own fifth consumer

**Choice.** `fixture/GBG Fixture/` — a toy three-module Julia package with docstrings, `docs/`, `test/`
with one regression, a complete `.gbg/`, and `defects.toml` (each planted defect's class, location and
the scan that must catch it). Its `.gbg/config.toml` has `[tool] version = "dev"` and its
sub-environments use `[sources] GBGCodingTools = {path = "../../.."}` (the enclosing tool repository;
from the fixture root that is `../..`). `version = "dev"` is legal in exactly two places — a consumer
enclosed by the tool repository, the fixture (`PIN.CONFIG` walks up and checks), and the tool's own
root (`SELF.CONSUMER`, below) — and a dev round is unclosable except by abandon, exactly as under
`gbg --dev`, unless it was opened at a clean released tag (D16); under a `dev` pin `PIN.TREESHA`, `PIN.NOT_DEV` and
`gbg self verify` report WARN "dev pin". `gbg selftest` runs: every scan against the fixture (must
hit, clean twin must not); every gate in both directions plus an **absence arm** (input missing → exit
2); the demotion predicate's falsification cases; `recall` arms A–D built in the test; the witness
runner over one failing/passing/erroring/blocked witness; doctor perturbations asserting the exact
failing id; schema round-trips; `sync` idempotence and MODIFIED detection; `catalog/scans.toml`
completeness (every scan function registered); schema validation of the fixture config. **`gbg selftest`
IS the package's `Pkg.test()`**: every arm above is a testset of `test/runtests.jl`, and the verb is a
thin wrapper running that suite over the copy it runs from, from a temporary environment.
`gbg selftest --pinned` copies the fixture OUTSIDE the tool
repository, pins it at the released tag with `url + rev`, instantiates, and exercises the pinned-copy
behaviours the in-tree fixture cannot (the shim's resolution through the docs environment,
`PIN.TREESHA`, `self verify`, an edited pinned copy → exit 2). **Step-0 acceptance test**: PF's and IT's banked rounds are imported and re-graded
under the merged engine; the tallies must equal the recorded ones (§8). The imports are SCRATCH:
graded, compared, recorded as one table in the tool's `CHANGELOG.md`, then deleted — a consumer's
`.gbg/rounds/` starts empty at migration (owner ruling 2026-09-08: no history carried). Tool CI: manual + tags (fleet
cost policy): `Pkg.test()` on 1.11 and 1.12 AND the tool's own docs build, with no consumer checked out.

**The tool as its own fifth consumer.** The tool repository carries `.gbg/config.toml` with
`[tool] version = "dev"` — the dev pin already legal inside the tool repository for the fixture,
extended to the tool's own root — `[package] name = "GBGCodingTools"`, its modules, its surfaces
(`src/**/*.jl`, `ext/*.jl`, `docs/src/**/*.md`, `docs/ARCHITECTURE.md`), `instruments.enabled` = all
four, `seed_rounds = false` until a seed catalogue exists, and ONE domain hat, `tooling-maintainer`
(reads the docs as the person who must maintain the tool); §5.6 is the delta. Its
`.gbg/exemptions.toml`, `.gbg/hats/`, `.gbg/policy/` (the rendered copy of its own `policy/`) and
`.gbg/rounds/` (tracked, as for any consumer) exist; `gbg --dev sync` renders its `.claude/skills/`
stubs and its `CLAUDE.md` block. The doctor and the fleet treat the tool root as a consumer whose pin
is `dev` (`SELF.CONSUMER`, `SELF.DOCS`, §7.3; the fleet's fifth row, D4), and the tool's own footprint
is the same set as a consumer's (§4). **Checks the tool passes on itself, enforced:** (a) every docs
build runs the quick doctor, the hard scans over the tool's own surfaces and the gate, through the
wrapper (D9); (b) `test/runtests.jl` calls `TestHarness.gate()` and
`TestHarness.run_regressions(@__DIR__)` besides the engine tests, so `WIRE.RUNTESTS` holds at the
root; (c) `gbg release` refuses unless the release preconditions of D16 and §8 hold; (d) the tool's
CI runs `Pkg.test()` on both Julia lanes AND the docs build with no consumer checked out. The four
instruments run on the tool like on any consumer — `/check-docs` and the others from a session opened
in the tool repository — and their rounds are tracked under the tool's `.gbg/rounds/`; the
implementation plan requires one `/check-docs` round over the tool's own docs, opened at the clean
prerelease tag `v1.0.0-rc.1` and CLOSED, before `v1.0.0` (its Phase 1.10; the prerelease form of
`gbg release` is D16's) — the tool's first real corpus besides the fixture.

**Forced by.** R5 — and R1 with it: a tool that measures four corpora and exempts its own is the one
consumer whose drift nothing would report; a self-check is a script, not a note (`survey-check-consistency.md:288`); the only
proof the merged engine measures what the copies measured (`round2-maintainer.md:283-287`); no fixture
consumer at a path with a space in any proposal (`round2-maintainer.md:263-264`); a fixture pinned at
a tag that does not exist yet cannot build before the release that Phase 1 gates on (dry-run BLOCKER 2).

**Dominated.** *Testing against real consumers by relative path*: skip-when-absent passes; seeds would
land in real docs. *Per-machine `SELFTEST.<tag>.ok`*: hidden machine state. *Fixture pinned at the
tag*: unbuildable before the tag exists.

### D16 — Change discipline: semver with "measurement-affecting ⇒ MAJOR", stamped rounds, no mid-round upgrade or config change

**Choice.** MAJOR: any change to a vocabulary, the demotion or closure predicate, a scan tier or
threshold, the seed mechanism or the fixture's seed catalogue (a consumer's own `.gbg/seeds.toml` is
that consumer's commit, stamped as `seed_catalog_sha`, §6.4), scoring/recall, a schema. MINOR: additive (hat, lane, scan, lint, check,
config key with default). PATCH: no verdict change on the fixture. `CHANGELOG.md` per tag states
"rates comparable: yes/no" and, for a MAJOR, the recall figure on the fixture. Stamps in `ROUND.toml`
and every `pass.toml`. `config_sha` covers `config.toml`, `hats/*.toml` and `exemptions.toml`; **every
`gbg round` verb after `open` refuses (exit 2) a changed `config_sha` or a `tool_version` moved by
`gbg bump`** → `gbg round pass open --regrade`, which re-validates `findings.json` under the current
schema and config, re-stamps, supersedes prior passes, and requires the closing pass at the round's
current stamps. A changed `tool_tree_sha` under an UNCHANGED `tool_version` is "tag moved" —
**abandon-only**, never regradable. `gbg bump` refuses open rounds unless
`--abandon-open-rounds "<account>"`, writes `.gbg/scratch/bump-message.txt` (a commit-message template
listing the managed files it changed; `gbg init --migrate` writes its own,
`.gbg/scratch/commit-message.txt`, for the migration commit), and records the fleet window start
(D4). **Release preconditions.** `gbg release <ver>` runs in the dev checkout only and refuses (exit 2)
unless, at a clean tree: `Pkg.test()` is green; the tool's own docs build exits 0 (`SELF.DOCS`);
`gbg doctor --deep` is green at the tool root; no round is open under the tool's `.gbg/rounds/`; the
`/check-docs` round opened at the latest `<ver>-rc.<n>` tag (next sentence) is closed — `closed` set,
every id `closed_by` honored, adjudicated, rescan, seeded or carried, never `abandoned`; the `CHANGELOG.md` entry for `<ver>`
is present; and the tag is absent — it never re-tags (§8 restates the list). **The prerelease form.**
`gbg release <ver>-rc.<n>` (tags `v1.0.0-rc.1`, `v1.0.0-rc.2`, …) runs the same refusals EXCEPT the
open-round refusal and the closed-`/check-docs`-round precondition: it exists so that the tool's own
instrument rounds before a release have a clean tag to open at. An rc tag is never a consumer pin —
`PIN.CONFIG` accepts only `vX.Y.Z`, and `PIN.SOURCES` refuses a `-rc.` rev in any consumer other than
the tool itself (§7.3). **The dev-round rule, revised 2026-09-10.** A round stamped `dev+<sha>[-dirty]` — opened under
`gbg --dev`, or on the tool's own root (D15) — is refused AT `preflight` for `/check-docs` and
`/check-consistency`, the two instruments whose rounds are measurements compared across versions: the
round is not opened and nothing is spent. `/bug-hunt` and `/audit-changes` read `base..HEAD`, which is
off a tag by construction, so they open, close and carry a dev stamp as the normal case. A closed
dev-stamped documentation round is a record, not a measurement: `ROUND.DEV` names it (WARN),
`Release.cites_round` refuses it a release, and `abandon` takes it back, since a state with no exit
invites editing a frozen record. Until this revision the rule was enforced by nothing — `Passes.close`
held the string only to exempt a dev round from the tag-moved refusal — and the doctor's FAIL on the
frozen record that resulted stopped `Pkg.test()` and every docs build. A refusal belongs where the
answer is still cheap. The earlier form of the rule admitted a round opened at a clean tag: a round whose `tool_version` equals a released tag — a prerelease
`vX.Y.Z-rc.<n>` included — AND whose tree was clean at open (`git describe --exact-match --dirty`
naming that tag with no `-dirty` suffix) is stamped with the tag, not `dev+…`, and is a normal
closable round; this is the tool's own way to run its instruments on a release, and at an rc tag on
the release candidate — the stamp names the rc tag as the instrument that measured the round, which
is what a stamp is for. For such a round at the tool root `tool_tree_sha` is the tree the tag names
(`git rev-parse vX.Y.Z^{tree}`), re-read from the tag by every later verb rather than from the working
tree — the fix commits the round exists to produce move `HEAD` past the tag and must not read as a
moved tag; "tag moved" then means at the root exactly what it means elsewhere, the tag re-pointed,
abandon-only. What this leaves open is stated in §11: a fix to `src/` inside such a round changes the
instrument mid-round, which no other consumer can do.

**Forced by.** R4; the freeze record: a mid-round grader edit made PF's 54.8 → 96.8 % uninterpretable
(`survey-check-consistency.md:276`); `theory-patterns.md:41-43,99-101`; a persona softened or a surface
narrowed between a bank and a rerun (attack 1.5, 4.3); a re-tag laundered through `--regrade` (attack
4.2).

**Dominated.** *SHA pins without semver*: no way to say "comparable". *Calendar versions*: say nothing
about measurement. *`--regraded "<account>"` as a rubber stamp*: prose, not a re-validation.

### D17 — Migration: PF → IT → SS → CP, doctor-verified steps, named collapses and declared deviations

**Choice.** PF first (canary, strictest suite, origin of most engines); IT second — its engine
contributions (the panel profile, attack-design, rubric-audit, severity-recheck, the
`operational-claims` lane, `PARTIAL`/`surviving_class`, `checked[]`/`candidates_found`, required
`base`) are **part of v1.0.0**, verified against IT's imported rounds in Phase 5.1 before IT migrates;
a defect that verification finds is fixed and released as a **1.0.x PATCH**; SS third (a July fork,
replaced wholesale); CP last (greenfield `gbg init`, which also creates its `test/Project.toml`). §9
names each divergence's disposition. Deletions per consumer are listed in the implementation plan.
**Effort:** IT's executability review put the whole programme at roughly 17–23 working sessions, with
the HTML-parser port (D8) the riskiest single item; this plan is larger than IT's, so treat that
figure as a floor, not an estimate. Step 0 runs on the live trees, on scratch imports that it deletes
(D15). **Every consumer migrates to the same footprint (§4) and carries nothing else forward** (owner
ruling 2026-09-08): its `.gbg/rounds/` starts empty; its pre-tool piles are deleted, never imported; its
old adjudication lists are not carried into the ledger; a settled note is deleted, not moved; only a
live artefact — IT's escalated and blocked witnesses, a runbook — is given a tracked home. The tool
itself is initialised as its own consumer in Phase 1, before any release and before PF — not a
migration, since it has no legacy piles, but the first tree the doctor runs on (D15).

**Forced by.** R9; canary (`theory-patterns.md:118-119`); the surveys' inventories (CP has no
instruments; SS no scripts; IT 39 tracked command files); Step 0 re-grades IT's rounds under the
release it will pin, so the mechanisms those rounds used must be in it.

**Dominated.** *All four at once*: no canary. *SS/CP first*: nothing to contribute, migrated twice.
*IT's mechanisms as a 1.1.0 after PF migrates*: Step 0 could not re-grade IT's rounds under 1.0.0,
and the two documents contradicted each other on what 1.0.0 held (dry-run 11).

### D18 — Cost policy: economy default, anchors in the catalogue (engine) and in config (domain hats), never-economised phases as engine constants

**Choice.** `[cost] default = "economy"`; each hat/lane has `anchor = true|false` — engine lanes carry
it in the catalogue as a constant (the `executing` audit lane, the two free hunt lanes, the dismissal
auditor and the severity re-check are `anchor = true` there); domain hats carry it in the consumer's
config (default anchor); generic hats default economy. `catalog/models.toml` holds
`economy = "sonnet"` (the only place the model name appears; a bump is PATCH). **Never economised, not
configurable — exactly the record's five phases:** adjudication, reproduction, verification,
consolidation, the fix pass. `strength = "full"` is a run flag, stamped into `ROUND.toml`.

**Forced by.** R12; PF's cost paragraph is already ported verbatim (`survey-checkdocs.md:24`); IT
ignores `strength` where PF honours it (`survey-bughunt-auditchanges.md:91`).

**Dominated.** *Anchors in the engine for domain hats*: a domain hat is a consumer's. *Model name in
config*: four places for one value. *Extending the never-economised list with lanes*: a lane's
strength is its `anchor`, and calling it a phase blurs the one word the record uses precisely.

### D19 — Name: `GBGCodingTools`

The package is policy + doctor + scaffold + docs lints + test harness + four review instruments;
`GBGInstruments` would name one third of it, and "instrument" stays the house TERM for the four review
procedures. `*Tools` is the Julia idiom for dev-time helpers. Zero renames in the four corpora.
Recorded alternative: `GBGDevTools`. The name is baked into the UUID, twelve `Project.toml`s and
`~/.julia/packages/<Name>`; it is decided once — the record decided it, and it is not an owner question. `GBGInstruments` was
proposed by the IT session and declined: "instrument" is the reserved house term for the four review
procedures — one word, one meaning — and the name would claim it for the whole package; IT's objection
that "tools" is a cover word was withdrawn (2026-09-08).

---

## §3 Repository layout

```
GBGCodingTools.jl/
  Project.toml                  name, uuid, version, julia = "1.11"; deps: TOML, SHA, Dates, Pkg, Random, Test (stdlib), JSON3, Gumbo,
                                AbstractTrees; weakdeps: Documenter (compat-bounded) → extension GBGCodingToolsDocumenterExt
  CHANGELOG.md                  per tag: MAJOR/MINOR/PATCH, instruments affected, "rates comparable: yes|no"
  README.md                     what it is, the three bootstrap commands, the design sentence
  fleet.toml                    dev-side only: name, path (relative to the dev checkout), github, of each consumer, the tool's own
                                row (name = "GBGCodingTools", path = ".") included (D15); [sweep] window
  install.sh                    owner convenience: runs `julia --startup-file=no --project="$PWD" -e '…main(ARGS)…' -- install
                                --dev-checkout "$PWD"` from the dev checkout
  bin/gbg                       the shim body (POSIX sh) that `gbg install` copies to ~/.local/bin/gbg; execs
                                julia --project="<root>/docs" (D2); reads no depot slug
  src/                          the Julia package — ONE language for every deterministic engine
    GBGCodingTools.jl           module; `main(ARGS)::Int` (the one entry point; an uncaught exception → 3); `makedocs(cfg; kwargs...)`
                                declared (`function makedocs end`; the body is ext/'s)
    CLI/                        the CLI `gbg [--dev] <noun> <verb>`, one module per noun; every verb a function returning the exit code
      Main.jl                   argument parsing, `--dev`, `--version`, `probe`, the try/catch → 3
      Config.jl Schema.jl       loader + the ONE JSON-Schema-subset validator (types, required, enum, pattern, additionalProperties)
                                over the TOML.parsefile Dict; no JSONSchema.jl
      Doctor.jl Sync.jl Init.jl Fleet.jl Bump.jl Release.jl Install.jl
      Git.jl                    the git questions the round verbs and the gate ask (Main.jl's stamp and Doctor.jl's GIT.* checks run their own)
      Ledger.jl                 THE reader of `.gbg/exemptions.toml` (scope, target, expiry, the `EXEMPT.*` checks' source)
      Preflight.jl              doctor-quick + self verify + round open + THE Workflow-args renderer (also used by `pass open`)
      Rounds.jl                 open/prepare/build/test/bank/rerun/pass/grade/close/abandon/list/render/import (+ --empty)/compare (--recorded)
      Passes.jl                 the verification half of a round — `pass open`/`grade`/`close`, the dismissal gate, deferral carry
      RoundFiles.jl             reading and hashing what lives under `.gbg/rounds/` (the round record, the lane files, shas)
      Self.jl                   `gbg self verify` — the running copy's tree hash against what `Pkg.dependencies()` and every sub-environment manifest record (D2, D3, D15)
      Gate.jl                   THE closure gate for every instrument (honours GBG_ROUND); called in-process by makedocs and TestHarness.gate()
      Demote.jl                 THE demotion predicate (class_surfaces[] empty, or any entry unswept)
      Scan.jl                   `gbg scan docs|html` — the tiered engine over catalog/scans.toml
      Seed.jl Recall.jl Consolidate.jl Audit.jl Hunt.jl Selftest.jl
    Scans/<ScanId>.jl           the scan catalogue's implementations, one file per scan id (§12.B)
    TreeHash.jl                 git blob/tree hashing on the SHA stdlib; `gbg self verify`, PIN.SELF, PIN.TREESHA
    HtmlWalker.jl               the Gumbo + AbstractTrees walker shared by Consolidate.jl and the SCAN.HTML_* scans
    DocLints.jl                 the bare `function makedocs end` + its docstring (the body is ext/GBGCodingToolsDocumenterExt.jl; no regex twins)
    TestHarness.jl              @alloc_below, CountingArray/Traffic/audit, method parity, oracle registry,
                                run_regressions, display gate, thread-subprocess check, gate()
    Reflection.jl               argcov, signature_fidelity, xlink (dry-run), dupref, public surface
    Witnesses.jl                run(dir; expect, names)
  ext/
    GBGCodingToolsDocumenterExt.jl  the Documenter extension (weak dependency, D9): defines GBGCodingTools.makedocs(cfg; kwargs...);
                                loaded only where Documenter is — a consumer's docs environment
  instruments/                  one directory per instrument = its contract (R10)
    check-docs/         PROTOCOL.md  workflow/lanes.js  schema.json  selftest/
    check-consistency/  PROTOCOL.md  workflow/{panel,verify-act,verify-state,severity-recheck,rubric-audit}.js  schema.json  selftest/
                        (its schema.json also carries the `seeds` definition a consumer's .gbg/seeds.toml validates against, §6.4)
    bug-hunt/           PROTOCOL.md  workflow/{hunt,dismissals,verify-architecture}.js  schema.json  selftest/
    audit-changes/      PROTOCOL.md  workflow/{audit,attack-design}.js  schema.json  selftest/
  catalog/
    hats/*.toml                 generic hats: the eight shared keys (consistency-matrix, software-architect,
                                structure-consistency, latex-typesetter, api-user, citations-integrity, style-editor,
                                cold-reader), IT's lenses (free-reader-a/b/c, logician, plain-sense, existence-auditor,
                                quantifier-auditor, conjunction-coverage, conceptual-clarity, reader-standpoint,
                                fossil-and-drift), the rulebook hats (naming-policy, doc-policy, invariants-and-decisions
                                with {package.rulebook_sections} placeholders); fields key, role, persona, siteonly,
                                substrate, anchor
    lanes/{check-docs,bug-hunt,audit-changes}.toml   engine lanes (constants, anchors marked); free hunt lanes; audit lanes by kind
    scans.toml                  every deterministic scan: id, rule id, tier hard|triage, surfaces key, runner julia|html, fixture pair (§12.B)
    models.toml                 economy = "sonnet"
    seeds/fixture.toml          the fixture's seed catalogue — the ONE seed catalogue in the tool; a consumer's is its own
                                .gbg/seeds.toml (§6.4)
  policy/                       the single-source rubric, rule-numbered
    00-index.md docs-rubric.md latex-idiom.md citations.md testing-protocol.md instruments.md git-conventions.md glossary.md
    RULES.toml                  every `RULE.*` id → file, section, statement, sentinel, enforcement class (§12.A; the ledger
                                validates against it; `LEG.SENTINELS` reads the sentinels)
  schema/*.schema.json          the sixteen of D11
  templates/                    SKILL.md.tmpl settings.json.tmpl queue-guard.sh.tmpl WORK_QUEUE.md.seed CLAUDE.md.skeleton make.jl.seed
                                runtests.jl.seed test-Project.toml.seed
                                CI.yml.snippet docs.yml.snippet (three fragments each, inserted by `sync` at fixed points:
                                the GBG_DEPS_TOKEN insteadOf step FIRST AFTER actions/checkout and before any julia-actions/*
                                step; the build/test step rewritten to tee its output into gbg-run.log; a LAST step grepping that
                                log for the banner the job prints — makedocs in docs.yml, gate in CI.yml; no python step anywhere;
                                a workflow without an actions/checkout step is refused, exit 2)  regressions-README.md gitignore.block
                                claude-md.block commit-message.tmpl bump-message.tmpl
  fixture/GBG Fixture/          the toy consumer (path WITH a space): src/ docs/ test/ .gbg/ defects.toml; pin "dev"
  test/runtests.jl              the package's test suite = `gbg selftest`: every arm of §8 (harness, wrapper, witnesses, scans,
                                gates, doctor, schemas) over the fixture; plus `TestHarness.gate()` and
                                `TestHarness.run_regressions(@__DIR__)` on the tool itself (D15)
  test/regressions/             README.md (rendered) + the promoted witnesses of the tool's own hunts; WIRE.RUNTESTS holds at the root
  docs/                         the tool's own Documenter site (D9, D15), built through its own `makedocs` wrapper
    ARCHITECTURE.md             this document (copied to docs/src/architecture.md at build time)
    Project.toml                [deps] Documenter, GBGCodingTools; [sources] GBGCodingTools = {path = ".."} — the working tree (D2)
    make.jl                     `GBGCodingTools.makedocs(GBGCodingTools.Config.read(); sitename = "GBGCodingTools",
                                checkdocs = :exports, doctest = true, …)`; WIRE.MAKEDOCS applies to the tool itself
    prose_shape.csv             the tool's own ratchet baseline
    src/                        index.md  guide/{install,verbs,rounds,doctor,ledger,config}.md  architecture.md (generated)
                                api/{TestHarness,Reflection,Witnesses,Config,CLI}.md; verbs.md is rendered from the src/CLI/
                                docstrings through @docs and doctor.md from the doctor's own table
  .gbg/                         the tool as its own fifth consumer (D15; §5.6): config.toml (pin "dev"), exemptions.toml,
                                hats/tooling-maintainer.toml, seeds.toml (absent until written; seed_rounds = false),
                                policy/ (rendered from ../policy/), managed.json, rounds/.keep, rounds/<date>-<instrument>-<NN>/
                                (tracked), scratch/ (gitignored)
  .claude/skills/<name>/SKILL.md  the five stubs, rendered by `gbg --dev sync` at the root (D6)
  CLAUDE.md                     the managed policy block + the design sentence, the freeze rule, the release checklist (D12)
  .gitignore                    + the managed block
  .github/workflows/CI.yml      manual + tags: julia 1.11 and 1.12 lanes × `Pkg.test()` (= `gbg selftest`) AND the tool's own docs
                                build, no consumer checked out; the auth step and the banner grep as WIRE.CI_AUTH requires;
                                no python step
  .github/workflows/docs.yml    deploys the tool's site on push to master (the per-push enforcement point, D9); GitHub Pages on
                                the private repository enabled by the owner
```

---

## §4 Consumer footprint

Legend: **C** config (owned, validated) · **G** generated-managed (hash in `.gbg/managed.json`) ·
**S** seeded-once-then-owned (wiring-checked) · **P** tracked-pile · **X** gitignored.

```
<Consumer>/
  .gbg/
    config.toml                        C   the one config (§5)
    exemptions.toml                    C   the one ledger (§7.2)
    hats/<key>.toml                    C   domain hats (anchors or not); schema-validated
    seeds.toml                         C   the seed catalogue (pages + fragments per class; §6.4); schema-validated; sha stamped as seed_catalog_sha
    managed.json                       G   path → template, version, sha256 for every G file (a cache; MANAGED.HASH re-renders)
    policy/00-index.md … deviations.md G   rendered policy copy + rendered deviations
    rounds/.keep                       P   absence ⇒ ROUND.DIR fails
    rounds/<date>-<instrument>-<NN>/   P   §6
    requests/to-<PKG>-<date>-<topic>.md P  OPEN cross-package requests (tracked in the requester; a concluded one is deleted)
    scratch/                           X   <round>/ manuscripts + seeded copies + workflow/ (the round's Workflow scripts, copied
                                           from the pinned copy by preflight — D7, V1); public_surface.json; commit-message.txt;
                                           bump-message.txt
  .claude/
    skills/check-docs/SKILL.md         G   ≤ 15-line stub (D6); likewise check-consistency, bug-hunt, audit-changes, gbg-doctor
    hooks/queue-guard.sh               G   every consumer; PF's queue-guard.sh verbatim (D13): guards WORK_QUEUE.md `- [ ]` items,
                                           never reads .gbg/rounds/, never starts Julia
    settings.json                      G   every consumer; hooks block runs "$CLAUDE_PROJECT_DIR/.claude/hooks/queue-guard.sh"
    WORK_QUEUE.md                      S   the session checklist the hook guards; seeded once (header only), owned thereafter
    settings.local.json                X   gitignored fleet-wide (autoMemoryDirectory is machine/Dropbox state)
  CLAUDE.md                            S   package content in the skeleton's section order (D12) + one G block (the policy import,
                                           parameters, deviations, consent sentence)
  docs/ROADMAP.md                      S   live plans, moved out of CLAUDE.md at migration (D12); not a scan surface
  .gitignore                           S   + one G block (.gbg/scratch/, docs/build, Manifest.toml of sub-envs, *.cov)
  docs/make.jl                         S   must call GBGCodingTools.makedocs(...); WIRE.MAKEDOCS fails on a bare makedocs(
  docs/Project.toml                    S   + G entries [deps]/[sources]/[compat] GBGCodingTools
  docs/prose_shape.csv                 S   the ratchet baseline, one schema fleet-wide; written only by init and --rebaseline
  test/Project.toml                    S   + G entries (created by `gbg init` for CP)
  test/runtests.jl                     S   must call TestHarness.run_regressions(@__DIR__) and TestHarness.gate()
  test/regressions/README.md           G   the promotion contract, one text fleet-wide
  test/regressions/*.jl                S   promoted witnesses (body unchanged at promotion; maintained with the tree thereafter)
  test/regressions/escalated/*.jl      S   pre-tool escalated witnesses carried at migration (IT), header `# overturn_when:`; re-run by --deep
  test/regressions/blocked/*.jl        S   pre-tool blocked witnesses carried at migration (IT), header `# blocked:`; re-run by --deep on a host with the device
  test/method_parity_baseline.toml     S   frozen counts (engine in the tool; written at migration by `gbg migrate baselines`, as are the next two)
  test/pass_audit_baseline.toml        S   frozen traffic table
  test/oracle_registry.toml            S   provenance classification
  benchmark/Project.toml               S   + G entries (where a benchmark env exists); any further sub-env listing the tool likewise
  .github/workflows/{CI,docs}.yml      S   must carry the GBG_DEPS_TOKEN insteadOf step (WIRE.CI_AUTH) and grep both banners; no python step
```

**The tool's own footprint is this same set** (D15), at the tool root, with `[tool] version = "dev"`
and its `docs/Project.toml` on `[sources] GBGCodingTools = {path = ".."}` in place of a `url + rev`
entry; nothing in the list is special-cased for it, `benchmark/Project.toml` being absent as it is for
CP, and its `test/Project.toml` listing no tool entry because the package under test IS the tool.

---
## §5 Config schema

**Anchor semantics (used by every `file#heading` value below).** `path#text` matches the ONE heading
in `path` (any `#` level) whose text starts with `text`; zero or two matches is `CFG.SURFACES` FAIL.
`"absent"` is the literal value meaning "this package has no such section" and is legal only where
the key says so.

### §5.1 PF's complete `.gbg/config.toml`

```toml
# .gbg/config.toml — GBGPeriodicFields.  Schema: schema/config.schema.json in the pinned tool
# (closed keys: an unknown key, a missing required key, an unknown enum member or a path that
# does not exist is exit 2).  `gbg init` materialised every default below; nothing is layered on
# top of this file.

[tool]
version = "1.0.0"                      # the pin; `gbg sync` renders it into every sub-env Project.toml that lists the tool
schema  = 1                            # the tool MAJOR this file was written for

[package]
name        = "GBGPeriodicFields"
description = "Real-valued scalar/vector/second-order-tensor fields on 3D periodic domains, physical and rfft spectral representations, CPU and GPU (CUDA/ROCm); the field layer for pseudospectral solvers."
modules     = ["FiberSections", "Fields", "FieldAlgebra", "DifferentialOperators", "Convolution", "Points", "Interpolation", "Reductions"]
extensions  = ["ext/GBGPeriodicFieldsHDF5Ext.jl"]
deliberate_absences = ["no time, no particles, no physics", "no field×field multiply in spectral representation", "no tensor order above 2"]
terms       = ["base", "fiber", "section", "resolved band", "cutoff", "assignment", "destination"]
domain      = "pseudospectral fields"
rulebook_sections = ["CLAUDE.md#Core invariants", "CLAUDE.md#Code generation rules", "docs/ARCHITECTURE.md#13. Decision log"]
                                       # what the catalogue's rulebook hats (naming-policy, doc-policy, invariants-and-decisions) read
julia_test  = "julia --project -e 'using Pkg; Pkg.test()'"   # CFG.SURFACES requires it to contain `Pkg.test()`; it IS the audit's executable gate
docs_build  = "julia --project=docs docs/make.jl"            # the schema pins the path; CFG.SURFACES requires the file
docs_post   = []                       # IT: ["git checkout -- docs/Project.toml"]

[paths]                                # further directories; every one is a covered path of /audit-changes (adds to the constants, never removes)
examples  = "examples"
benchmark = "benchmark"

[git]
branch = "master"                      # enum: master | main

[surfaces]                             # the ONE copy of every surface list
rationale  = ["docs/ARCHITECTURE.md", "docs/FORMALIZATION.md", "docs/TESTING.md", "docs/PERFORMANCE.md"]
pages      = ["docs/src/**/*.md"]
generated  = {globs = ["docs/src/architecture.md", "docs/src/formalization.md", "docs/src/testing.md", "docs/src/performance.md", "docs/src/examples/*.md"], optional = true}
                                       # build products; `optional = true` exempts them from CFG.SURFACES' existence check on a fresh clone
src        = ["src/*.jl"]
ext        = ["ext/*.jl"]
literate   = ["examples/HIST_CPU.jl", "examples/gpu/*/*.jl"]   # a Literate example IS a rendered page; SS/IT/CP: []
built_html = "docs/build"              # "" disables the built-HTML surface
history_exempt     = "docs/ARCHITECTURE.md#13. Decision log"   # append-only history, exempt from currency scans
references_heading = "absent"          # PF's canonical list is a bold paragraph, not a heading: no title cross-check, and the DOI
                                       # scan compares against the WHOLE of docs/ARCHITECTURE.md, as PF's script does. IT: "docs/ARCHITECTURE.md#References"
glossary   = "docs/src/notation.md"    # optional; a package without a notation page omits the key (CP)

[docs]
doctest           = true
admonition_titles = "always"           # enum: always | load-bearing   (variation point)
unexported_base_expected = ["size", "eltype", "axes", "copy", "copyto!", "getindex", "setindex!", "ndims", "in", "show"]
retired_claims    = [                  # phrases the hard scan SCAN.RETIRED_CLAIMS bans, each with its reason (PF's lint_retired_claims list)
  {pattern = "kernel\\s+is\\s+itself\\s+a\\s+scalar\\s+field",                      reason = "decision 60 — a field in spectral representation is not a kernel"},
  {pattern = "kernel\\s+is\\s+held\\s+either\\s+as\\s+a\\s+scalar\\s+field",         reason = "decision 60 — a kernel is a SpectralKernel, not one of two storage roles of a field"},
  {pattern = "field\\s+passed\\s+as\\s+a\\s+kernel",                                 reason = "decision 60 — a bare field does not dispatch as a kernel; it is wrapped in StoredKernel"},
  {pattern = "(?:kernel|window)\\s+as\\s+a\\s+scalar\\s+field\\s+in\\s+spectral\\s+representation", reason = "decision 60 — name the kernel class returned"},
  {pattern = "expand\\s+it\\s+into\\s+a\\s+scalar\\s+field\\s+in\\s+spectral\\s+representation",   reason = "decision 60 — materialize_kernel returns a StoredKernel"},
  {pattern = "accepted\\s+directly\\s+wherever\\s+a\\s+kernel\\s+is\\s+taken",       reason = "decision 60 — only a SpectralKernel is accepted"},
  {pattern = "squared_wavenumber_field",                                               reason = "decision 60 removed the binding; write radial_kernel(identity, mult)"},
]

[rubric]
leading_identity = "physical-meaning"  # enum: physical-meaning | estimand  (variation point; item 1 of the docstring home)
# No other key: the "Allocating form of" and "The fields are" phrases, the ≥ 3-arguments-or-a-keyword
# threshold, the upright \mathrm{i} and \partial_{x_i} are platform constants (D5).

[notation]
vectors        = "component"           # enum: component | boldsymbol | none   (variation point)
mathbf_allowed = ["\\mathbf{1}"]       # the only admitted \mathbf strings (variation point); IT: [] until dispositioned

[citations]
require_doi = true

[instruments]
enabled = ["check-docs", "check-consistency", "bug-hunt", "audit-changes"]

[instruments.check-docs]
argcov_policy = "triage"               # enum: triage | gate   (variation point — the ONE configurable tier, §5.5)
lanes_extra   = [                      # refinements of the engine's lanes; a file named here leaves the engine's surface lane
  {key = "src-core", files = ["src/FiberSections.jl", "src/Fields.jl", "src/FieldAlgebra.jl"], brief = "types, layout, algebra"},
  {key = "src-ops",  files = ["src/DifferentialOperators.jl", "src/Convolution.jl", "src/Points.jl", "src/Interpolation.jl", "src/Reductions.jl"], brief = "operators, transfer, reductions"} ]
# The engine lanes are constants and cannot be dropped: one lane per non-empty surface key
# (rationale, pages, src, ext, literate, built-html) plus family, cold-reader, operational-claims.

[instruments.check-consistency]
profile     = "all"                    # enum: all | core | explicit
hats        = ["consistency-matrix", "software-architect", "gpu-kernel-practitioner", "structure-consistency",
               "latex-typesetter", "api-user", "normalization-convention-auditor", "citations-integrity",
               "style-editor", "cold-reader", "spectral-methods-mathematician", "differential-geometer"]
core        = ["consistency-matrix", "cold-reader", "spectral-methods-mathematician", "differential-geometer"]
seed_rounds  = true                    # default true: the only non-self-reported dead-lane signal
seed_catalog = ".gbg/seeds.toml"        # the consumer's seed catalogue (class C, written by init, schema-validated); refused if absent while seed_rounds = true
design_docs_withheld = ["architecture", "formalization", "testing", "performance"]   # the site-only manuscript
latex_source_globs   = ["src/*.jl", "examples/*.jl"]
[[instruments.check-consistency.domain_hats]]   # every non-catalogue hat: persona in .gbg/hats/<key>.toml
key = "spectral-methods-mathematician"
anchor = true
substrate = "full"
[[instruments.check-consistency.domain_hats]]
key = "differential-geometer"
anchor = true
substrate = "full"
[[instruments.check-consistency.domain_hats]]
key = "gpu-kernel-practitioner"          # PF-specific persona (panel.js:96); a domain hat, not a catalogue hat
anchor = false
substrate = "full"
[[instruments.check-consistency.domain_hats]]
key = "normalization-convention-auditor" # PF's persona (panel.js:119) differs from SS's; each package holds its own
anchor = false
substrate = "full"

[instruments.bug-hunt]
territories = [
  {key = "fields",     files = ["src/Fields.jl", "src/FiberSections.jl"],            brief = "layout, plans, multipliers, reality condition"},
  {key = "algebra",    files = ["src/FieldAlgebra.jl", "src/Points.jl"],              brief = "codegen families, α/β, aliasing"},
  {key = "operators",  files = ["src/DifferentialOperators.jl", "src/Convolution.jl"], brief = "Nyquist split, kernels, projector"},
  {key = "transfer",   files = ["src/Interpolation.jl"],                               brief = "adjoint pair, traversal order, NUFFT"},
  {key = "reductions", files = ["src/Reductions.jl"],                                  brief = "measure, Parseval, shell binning"} ]
oracles     = ["adjointness", "Parseval", "div(curl)=0", "curl(grad)=0", "the documented definition over raw arrays"]
witness_env = "test"                   # the --project a witness runs under

[instruments.audit-changes]
# covered paths: the constants src, test, ext, docs, Project.toml, plus every [paths] entry — nothing here can remove one
executable_claims   = { allocation = "test/allocations.jl", traffic = "test/pass_audit.jl", method_set = "test/method_parity.jl" }
                                       # existing files under test/; the gate claim IS package.julia_test (no separate key)
guard_symbols       = ["_check_field_domain_compatibility", "_check_same_domain", "_check_contractible", "_check_multipliers_compatibility", "_check_owned_storage"]
invariants_section  = "CLAUDE.md#Core invariants"

[cost]
default = "economy"                    # enum: economy | full

[schema]
finding_types_extra = ["math", "normalization"]   # the ONE schema extension point

[[scans.custom]]                       # optional; tier is FIXED to triage; each needs a reason
id = "PF.PHYSICAL_MEANING_FIRST_MARKER"
pattern = "spectral field"
surfaces = ["src", "pages", "rationale"]
reason = "invariant 2's banned phrase; a triage reminder, the hard rule lives in the rubric"
```

### §5.2 SS delta

`package.*` (SS's identity; `extensions = ["ext/GBGStreamingStatisticsHDF5Ext.jl"]`; `domain =
"streaming statistics"`; `rulebook_sections = ["CLAUDE.md#Core invariants"]`); `[paths]` empty;
`surfaces.literate = []`, `built_html = ""`, `references_heading = "docs/ARCHITECTURE.md#References"`
(SS's `## References` at L910); `rubric.leading_identity = "estimand"`; `notation.vectors = "none"`
(the `\boldsymbol` scans are inapplicable by config, as SS's own record says); `docs.retired_claims =
[]`; `instruments.enabled` gains `bug-hunt`/`audit-changes` only when SS gets `test/regressions/`
(init creates it); `check-consistency.hats` = the eight generic hats + `statistics-theoretician`,
`streaming-stability-practitioner`, `normalization-convention-auditor` from `.gbg/hats/` (SS's own
persona for the last, distinct from PF's), anchors the first two; `seed_rounds = false` until
SS writes its `.gbg/seeds.toml` (a consumer commit, no tool release); `schema.finding_types_extra =
["statistics"]`; `[[scans.custom]]` for `\\quad.*\\quad` and the
un-lateralised sizer (triage). Ledger: `RULE.API.POSITIONAL` (keyword smoothing controls). Bold argument
bullets: owner decision (§9).

### §5.3 IT delta

`git.branch = "main"` until renamed; `docs_post = ["git checkout -- docs/Project.toml"]`;
`rulebook_sections = ["CLAUDE.md#Core invariants", "CLAUDE.md#Style", "docs/ARCHITECTURE.md#9. Invariants",
"docs/ARCHITECTURE.md#11. Decision log"]`; `[paths]` = `{examples = "examples"}` if IT has one, else
empty; `surfaces.rationale = ["docs/ARCHITECTURE.md"]`, `generated = {globs = ["docs/src/architecture.md",
"docs/src/decisions.md"], optional = true}`, `literate = []`, `history_exempt =
"docs/ARCHITECTURE.md#11. Decision log"`, `references_heading = "docs/ARCHITECTURE.md#References"`
(IT's `## References` at L2712; the DOI scan then checks title AND decoded DOI against that section and
refuses the retired `[doi:…]` label form outside the `Phenomenology` leaf); `docs.doctest = false`;
`docs.admonition_titles`: owner decision (§9); `docs.retired_claims = []` until IT names one;
`notation.vectors = "boldsymbol"`, `mathbf_allowed = []`; `check-docs.argcov_policy = "gate"`,
`lanes_extra = []`; `check-consistency.profile = "core"` with IT's 26-hat roster (the generic lenses
AND the three rulebook hats come from the catalogue: free-reader-a/b/c, logician, plain-sense,
existence-auditor, quantifier-auditor, conjunction-coverage, conceptual-clarity, reader-standpoint,
fossil-and-drift, naming-policy, doc-policy, invariants-and-decisions; domain hats
`turbulence-theoretician`, `dns-practitioner`, `external-standard`, `dimensional` from `.gbg/hats/`;
`pf-parity` dropped — its substrate is a gitignored clone), anchors `turbulence-theoretician`,
`dimensional`, `plain-sense`, `logician`; `seed_catalog = ".gbg/seeds.toml"` (written at `init` from
IT's own seed list);
`finding_types_extra = ["physics", "dimensional"]`; `[[scans.custom]]` for the stale variable names
`uh|phih|velocity|vorticity` (triage). Ledger: `RULE.DOC.STEER` (declined, owner-ruled 2026-08-25),
`RULE.DOC.MODULE_MAP` (deliberately tighter), `RULE.GIT.MANIFEST_TRACKED` (root Manifest tracked until a
registry).

### §5.4 CP delta

`package.*`: `name = "GBGCloudPhysics"`; `modules = ["Thermodynamics", "Processes", "Systems",
"State", "Observables", "Cache", "Generator", "Propagator", "ParcelModels", "StatisticalModels",
"SimulationRun"]` (the `module` blocks under `src/`, in include order — the file names differ from two
of them); `extensions = []`; `deliberate_absences`, `terms` and `domain = "cloud microphysics"`
transcribed by the implementer from CP's `CLAUDE.md` "What this is"; `rulebook_sections =
["CLAUDE.md#Conventions", "docs/ARCHITECTURE.md#13. Decision log"]`; `julia_test`/`docs_build` as
PF's; `docs_post = []`. `[paths]` empty (no `examples/`, no benchmark environment — the tool is
rendered into `test/` and `docs/` only). `git.branch = "master"`. `[surfaces]`: `rationale =
["docs/ARCHITECTURE.md"]`, `pages = ["docs/src/**/*.md"]`, `generated = {globs = [], optional = true}`,
`src = ["src/*.jl"]`, `ext = []`, `literate = []`, `built_html = "docs/build"`, `history_exempt =
"docs/ARCHITECTURE.md#13. Decision log"`, `references_heading = "docs/ARCHITECTURE.md#14. References"`,
`glossary` omitted (optional). `[docs]`: `doctest = true`, `admonition_titles = "always"`,
`unexported_base_expected = []`, `retired_claims = []`. `rubric.leading_identity = "physical-meaning"`;
`notation.vectors = "component"`, `mathbf_allowed = ["\\mathbf{1}"]`; `citations.require_doi = true`.
`instruments.enabled` = all four (`init` creates `test/regressions/`); `check-docs.argcov_policy =
"triage"`, `lanes_extra = []`; `check-consistency`: `profile = "all"`, `hats` = the eight generic hats
+ `cloud-microphysicist`, `core = ["consistency-matrix", "cold-reader", "cloud-microphysicist"]`,
`seed_rounds = false` (no `.gbg/seeds.toml` yet — CP writes one, a consumer commit, when it runs its
first panel), `seed_catalog = ".gbg/seeds.toml"` (the default path; `CFG.SEEDS` checks existence only
while `seed_rounds = true`), `design_docs_withheld = ["architecture"]`, `latex_source_globs = ["src/*.jl"]`,
and ONE `[[domain_hats]]` entry `{key = "cloud-microphysicist", anchor = true, substrate = "full"}`
whose persona `gbg init` writes to `.gbg/hats/cloud-microphysicist.toml` as a placeholder (a
one-sentence persona naming the domain, headed `# placeholder — rewrite before the first panel`);
the roster key and the file are written together, so `CFG.HATS` is green from `init` (it checks
resolution, anchors and the fleet-name rule, not the prose). `bug-hunt.territories = [{key = "core",
files = ["src/Thermodynamics.jl", "src/Processes.jl", "src/Systems.jl", "src/State.jl"], brief =
"constitutive core, phase/process graph, state"}, {key = "model", files = ["src/Observables.jl",
"src/Cache.jl", "src/Generator.jl", "src/Propagator.jl", "src/ParcelModel.jl",
"src/StatisticalModel.jl", "src/SimulationRun.jl"], brief = "model layer, propagation, runs"}]`,
`oracles = ["the documented definition evaluated by hand"]` (the implementer extends the list from
CP `docs/ARCHITECTURE.md` "10. Validation and testing"), `witness_env = "test"`.
`audit-changes.executable_claims = {}` (CP has no allocation, traffic or method-set audit; the gate
claim is `julia_test` regardless), `guard_symbols = []`, `invariants_section = "CLAUDE.md#Conventions"`.
`cost.default = "economy"`; `schema.finding_types_extra = ["physics"]`; no
`[[scans.custom]]`. Ledger: empty (Q4, ruled: `persistent_tasks = false` is dropped rather than
recorded). This is the whole of CP's migration besides `test/Project.toml` (D17): config, no deletions.

### §5.5 Deliberately NOT configurable (changing any is MAJOR)

Every verdict vocabulary and schema; the demotion predicate; the closure predicates and the four
channels; the round layout, file names and stamp fields; the exit contract; **scan tiers** (a consumer
may silence a `hard` scan by a ledger entry, never demote it) — with ONE declared exception,
`instruments.check-docs.argcov_policy`, which chooses whether the argument-coverage check is `triage`
or `gate`: it is admitted because IT's `# Arguments` corpus was written under the gate and PF's
prose-form corpus was not, so one tier would either fail every PF build or silence IT's only
enforcement of the rule; it is the sole configurable tier and it is listed in §1 as such; the
never-economised phases and the catalogue's engine-lane anchors (D18); the economy model name; the
seed mechanism (salted per-round selection, §6.4); the staleness mechanism (hash + nonce); the "zero
count = dead lane" rule; the regression include spelling; the managed-file mechanism and header; the
`no truncation` rule; the definition of "closed"; the engine lanes of `/check-docs` (`lanes_extra` can
only refine them); the covered-path constants of `/audit-changes` (`src`, `test`, `ext`, `docs`,
`Project.toml`; `[paths]` can only add); the public-surface route (`derived`); the audit's executable
gate (it is `package.julia_test`); the rubric's idiom strings and the ≥ 3-arguments threshold.

### §5.6 The tool's own delta (the fifth consumer, D15)

`package.*`: `name = "GBGCodingTools"`; `description` = the design sentence's first clause; `modules`
= the noun modules of `src/CLI/` plus `Config`, `TestHarness`, `Reflection`, `Witnesses`, as the tree
of §3 defines them; `extensions = ["ext/GBGCodingToolsDocumenterExt.jl"]`; `deliberate_absences =
["no layering in config", "no consumer copies in the tool", "no Python"]`; `terms` = the vocabulary of
this document's head (`consumer`, `instrument`, `round`, `lane`, `hat`, `anchor`, `gate`, `pin`,
`managed file`, `ledger`); `domain = "review tooling"`; `rulebook_sections =
["docs/ARCHITECTURE.md#§0", "docs/ARCHITECTURE.md#§5.5", "CLAUDE.md#Release checklist"]` (each a
one-heading anchor); `julia_test`/`docs_build` as PF's; `docs_post = []`. `[paths]` =
`{instruments = "instruments", catalog = "catalog", policy = "policy", schema = "schema",
templates = "templates", fixture = "fixture"}` — the instrument corpus is what `/audit-changes` must
cover on the tool, or R4's frozen-instrument rule has no auditor. `git.branch = "master"`.
`[surfaces]`: `rationale = ["docs/ARCHITECTURE.md"]`, `pages = ["docs/src/**/*.md"]`, `generated =
{globs = ["docs/src/architecture.md", "docs/src/guide/verbs.md", "docs/src/guide/doctor.md"],
optional = true}`, `src = ["src/**/*.jl"]`, `ext = ["ext/*.jl"]`, `literate = []`, `built_html =
"docs/build"`, `history_exempt = "docs/ARCHITECTURE.md#Revision history"` (the one heading under
which the implementation plan's Phase 1.10 gathers this document's revision notes — the anchor needs
exactly one match), `references_heading = "absent"`, `glossary` omitted. `[docs]`: `doctest = true`,
`admonition_titles = "always"`, `unexported_base_expected = ["showerror", "getindex", "setindex!", "size", "parent"]` (the
error types' `showerror` and `CountingArray`'s `AbstractArray` interface are internal by design; the same
allowance excuses a Base extension from `SCAN.HTML_PUBLIC_HOME`), `retired_claims = []`.
`rubric.leading_identity = "physical-meaning"` (the enum has no third member; for a tool it reads as
the plain identity sentence the rubric's item (1) asks for); `notation.vectors = "none"`,
`mathbf_allowed = []`; `citations.require_doi = true`. `instruments.enabled` = all four
(`test/regressions/` exists from Phase 1.10); `check-docs.argcov_policy = "gate"` (a fresh corpus,
written under the rule), `lanes_extra = []`; `check-consistency`: `profile = "all"`, `hats` = the
eight generic hats + `tooling-maintainer`, `core = ["consistency-matrix", "cold-reader",
"tooling-maintainer"]`, `seed_rounds = false` (no `.gbg/seeds.toml` until the tool writes one — a
tool commit, not a release: the catalogue is a consumer fact even here), `seed_catalog =
".gbg/seeds.toml"`, `design_docs_withheld = ["architecture"]`, `latex_source_globs = []`, and ONE
`[[domain_hats]]` entry `{key = "tooling-maintainer", anchor = true, substrate = "full"}` whose
persona, `.gbg/hats/tooling-maintainer.toml`, reads the docs as the person who must maintain the tool.
`bug-hunt.territories` = one per `src/` subtree — `{key = "cli", files = ["src/CLI/*.jl"]}`, `{key =
"scans", files = ["src/Scans/*.jl"]}`, `{key = "harness", files = ["src/TestHarness.jl",
"src/Reflection.jl", "src/Witnesses.jl"]}`, `{key = "core", files = ["src/TreeHash.jl",
"src/HtmlWalker.jl", "src/DocLints.jl", "ext/GBGCodingToolsDocumenterExt.jl"]}` — `oracles = ["the
fixture's defects.toml", "the exit contract", "git's own tree hash", "the documented definition over
raw files"]`, `witness_env = "test"`. `audit-changes.executable_claims = {}` (the gate claim is
`julia_test`, which IS `gbg selftest`), `guard_symbols = []`, `invariants_section =
"docs/ARCHITECTURE.md#§5.5"`. `cost.default = "economy"`;
`schema.finding_types_extra = []`; no `[[scans.custom]]`. Ledger: empty until a hard scan over the
tool's own surfaces needs a reason (Phase 1.10 runs them). This delta is what `gbg --dev init` writes
at the tool root, which must work when the dev checkout IS the consumer.

---
## §6 The round contract

### §6.1 File formats (all instruments)

- `ROUND.toml` (CLI-only). The COMPLETE field list — a field not named here is a schema error:
  `round, instrument, schema_version, tool_version, tool_rev, tool_tree_sha, config_sha, catalog_sha,
  seed_catalog_sha, seed_salt?, head, base?, roster[] ({key, anchor, substrate, not_applicable?}),
  cost, strength, hostname, model_hint, opened, lane_shas? ({lane: sha256}), banked?, findings_sha?,
  reproductions_sha?, dead_lanes[], passes, closed?, closed_head?, closed_by? ({adjudicated: [ids]}),
  abandoned? ({reason, open_ids[]})`. `config_sha` is the sha256 over `config.toml`, `hats/*.toml` and
  `exemptions.toml` in that order.
- `findings/NN-<lane>.json` (lane agent, FIRST, before returning): `{schema_version, round, lane,
  candidates_found, checked[], findings[{type, domain_type?, severity, confidence, title,
  locations[], contradicts?, description, resolution_hint?}]}`. Classified at bank per D10 (DEAD,
  EMPTY, ORPHAN, TRUNCATED, REJECTED).
- `findings.json` (CLI at bank): each finding gains `id = "<round>/<lane>#<n>"`, `seeded: bool`,
  `seed_class?`; the file's sha256 is `ROUND.toml.findings_sha`. Written ONLY when `bank` exits 0;
  frozen from that moment.
- `verdicts/pass-<k>/pass.toml` (CLI): `pass, nonce (random 128-bit hex), opened, head, range,
  expected{lane: n}, tool_version, tool_rev, tool_tree_sha, config_sha, superseded_by?`.
- `verdicts/pass-<k>/act/NN-<lane>.json` (act verifier agent): `{schema_version, lane, graded_sha256,
  pass_nonce, verdicts[{id, verdict, question, evidence, class_surfaces[{surface, swept, evidence}]}]}`.
- `verdicts/pass-<k>/state/NN-<lane>.json` (state verifier agent): `{schema_version, lane,
  graded_sha256, pass_nonce, verdicts[{id, verdict, surviving_class?, evidence}]}`.
- `verdicts/pass-<k>/tally.json` (CLI): per id `{act, act_demoted, state, closed_by ∈
  honored|adjudicated|seeded|rescan|null, adjudicated_entry?}`, totals, `demoted_by_rule`,
  `adjudicated_share`, `suspect_hats[]`, `dead_lanes`, `rejected_files`, `open_ids[]`,
  `plateau: {passes_flat}`; sha256 in `ROUND.toml` at close.
- `ground_truth.json` (seeded rounds, written at BANK): `{salt, seeded[{id, class, page,
  original_context, mutated_context}], skipped[class]}`.
- `import.json` (Step-0 scratch imports only, written by `gbg round import`; `schema/import.schema.json`):
  `{schema_version, source (the pile path, or "none" under --empty), source_sha256?, format ∈
  pf-doc-review|pf-check-docs|pf-findings-json|it-closure|it-audit-latest|it-rounds-json|none,
  title_to_id {title: id}, imported (CLI clock)}`.
- `recorded.toml` (Step-0 scratch imports only, transcribed by hand from the pre-tool record, living
  beside the import until Phase 2 deletes it): the four counts `gbg round compare --recorded` checks
  the re-graded tally against; the format and the reading rules are in §8. Neither file is ever
  committed: the comparison table in the tool's `CHANGELOG.md` is what remains.
- `.gbg/exemptions.toml` entries with `scope = "finding"` are the adjudication channel (§7.2).

### §6.2 `/check-consistency` end to end

1. **Skill.** `/check-consistency [--profile all|core|explicit] [--strength full] [--no-seed] [--dry]`.
   The stub's `!` block runs `gbg preflight check-consistency $ARGUMENTS`; `--dry` opens nothing and
   prints what would be run.
2. **Preflight** (exit 2 aborts the skill): validates config; quick doctor (`QUICK`); the torn-file
   guard `CFG.TORN` — exit 2 when `git status --porcelain` shows any pinned or managed file modified,
   round files under an open round excepted — which `preflight` and every `gbg round` verb run and
   which `QUICK` does not carry (a file that fails to parse is `CFG.VALID`); `gbg self
   verify`; refuses on an open check-consistency round, pin ≠ resolved, an uncommitted change under a
   **closed or abandoned** round; writes `.gbg/rounds/<date>-check-consistency-<NN>/ROUND.toml` (roster
   resolved from profile + config, a hat with an empty substrate recorded `not_applicable` rather than
   expected; stamps incl. `config_sha` and `tool_tree_sha`; `opened` from the CLI clock — a Workflow
   script cannot call `Date.now()`); prints the protocol text, the Workflow call (args:
   `{round_dir, scratch_dir, manuscripts, hats[{key, persona, anchor, substrate, siteonly}], preamble,
   deliberate_absences, adjudicated_titles[], cost, strength, finding_types, opened}`), and the
   next-step line. Hats receive the adjudicated list as titles only, never ids, never seeds.
3. **Prepare.** `gbg round prepare <round>` (the session runs it per the protocol): exports
   `GBG_ROUND=<round>` and runs `docs_build`, requiring exit 0 (a failed build is exit 2 with the log
   path) — the wrapper's `gbg gate` inside that build ignores exactly this round; consolidates
   `docs/build` into `.gbg/scratch/<round>/manuscript-{full,siteonly}.md`; if seeding, selects the
   seeds from the catalogue with a **per-round salt** (the round id salts the nth-occurrence offset of
   every class, so two rounds never plant the same set) and plants them into the manuscripts in place —
   during the panel ONLY the seeded manuscripts exist under `.gbg/scratch/<round>/`; `ground_truth.json`
   is NOT written yet.
4. **Panel.** `Workflow({scriptPath: "<root>/.gbg/scratch/<round>/workflow/panel.js", args})` — the
   copy preflight wrote from the pinned copy's `instruments/check-consistency/workflow/` (D7, V1).
   Hats run in parallel; each is told to `Write` `findings/NN-<key>.json` FIRST, then return the same
   object (schema-forced); each is forbidden to open `.gbg/**` and `~/.gbg/**` except the payload
   files its `args` name — its manuscript, its persona, the rulebook where its substrate grants it —
   under `.gbg/scratch/<round>/workflow/payload/` (D7, Revision 9). The script returns `{written, dead,
   empty, truncated}` and logs the next line. No tally.
5. **Bank.** `gbg round bank <round>` (like every `gbg round` verb it runs `gbg self verify` and
   `CFG.TORN` first): refuses a changed `config_sha` (exit 2 → `pass open
   --regrade`); validates each expected lane file against `instruments/check-consistency/schema.json`;
   records the sha of every present lane file at first sight in `ROUND.toml.lane_shas`; classifies
   (D10) — absent, unparsable or invalid ⇒ DEAD, the last two quarantining the file as
   `NN-<lane>.rejected.json` (there is nothing to quarantine when it is absent);
   assigns ids; regenerates the UNSEEDED manuscripts (a fresh consolidation), recomputes ground truth
   deterministically from the seed catalogue, the salt and the unseeded manuscript, and writes
   `ground_truth.json`; marks seeded findings by fragment match; prints recall per class (skipped
   classes UNDEFINED, kept in the denominator and named) and flags **SUSPECT** every hat with ≥ 2 seeds
   on its substrate and zero matches (reported in the tally, not fatal); writes `findings.json` and
   `findings_sha`; renders `findings.md` + `SUMMARY.md` (seeded hits subtracted, corroboration with a
   denominator, capped hats marked — a reading aid). **Any DEAD or REJECTED lane ⇒ exit 2 and NOTHING is
   frozen** (`lane_shas` stays). `gbg round rerun <round> --lanes …` accepts only lanes `bank`
   classified DEAD; a live lane whose sha changed since first sight is REJECTED.
6. **Fix pass** — on the owner's word, at session strength, driven from `findings.md` by finding id,
   never from `SUMMARY.md`. A build or test run during the pass is `gbg round build <round>` /
   `gbg round test <round>`, which export `GBG_ROUND` around `docs_build` / `julia_test`; a bare
   `julia --project=docs docs/make.jl` under an open round is refused by the gate, by design.
7. **Verify.** `gbg round pass open <round>` refuses a changed `config_sha` unless `--regrade`, and
   refuses outright — `--sweep-ok` overrides — while an open finding names a file the fix pass did not
   touch, since a pass spent learning that a fix stopped at the line it quoted is a pass wasted (the
   rc.1 round spent five of ten that way). It creates `verdicts/pass-<k>/`, records `head`, `range`
   (`<opened head>..HEAD`), the nonce, `expected`, the `scope`, the stamps; regenerates the manuscripts after a fresh build under `GBG_ROUND`; prints
   two Workflow lines rendered by **`Preflight.jl`'s renderer** (the one renderer; `pass open` renders
   no args of its own): `verify-act.js` (sees the diff; args add `range`, `pass_dir`, `nonce`,
   `expected`) and `verify-state.js` (blind; no range; same nonce). Both forbid their agents to open
   `.gbg/**` and `~/.gbg/**`; both require `graded_sha256` and `pass_nonce`; both receive every
   finding's text **unabridged**, so a real defect co-quoted with a seed is graded on its own claim.
   Seeded findings are graded by the state verifier only. **A pass after the first verifies only its
   `scope`**: the ids the previous pass left open, any it closed whose named locations the fix
   pass has since touched, and any it closed that names no location at all — a closed finding being able
   to regress only where its own evidence lives, and one with no evidence anywhere being re-verified
   every pass rather than never.
   Every other id keeps the entry that closed it. The rc.1 round verified 56 findings ten times over
   where 90 verifications were owed, and the panel is the round's whole cost.
8. **Grade.** `gbg round grade <round>`: refuses a changed `config_sha` (exit 2); validates both
   verdict sets; a file whose `graded_sha256` or `pass_nonce` mismatches is REJECTED, an absent one
   DEAD (exit 2); applies `Demote.jl` (HONORED → LINE-ONLY iff `class_surfaces == []` or any entry is `swept: false`, counted apart as
   `demoted_by_rule`); applies the closure channels (§6.5); writes `tally.json`/`tally.md`; prints the
   pass series and the plateau signal; exit 1 while `open_ids` is non-empty and equally while any id is
   `pending_state` — closed by the act verifier with no blind reading to confirm it. **Loop 6–8 over the same
   `findings.json`**; it terminates because the set is finite and closure is per finding.
9. **Close.** `gbg round close <round>`: requires the latest pass `open_ids == []`, no DEAD lane, every
   expected lane graded in that pass, `config_sha` and `tool_version` unchanged since open or the round
   re-graded (else exit 2 → `pass open --regrade`), `tool_tree_sha` unchanged under the same
   `tool_version` (else "tag moved" → abandon-only), `ROUND.toml.head` an ancestor of `HEAD`
   (`git merge-base --is-ancestor`; else `pass open --regrade`), the round's existing files committed;
   runs `dismissals.js` over every `scope = "finding"` ledger entry recorded after `opened` and
   requires `reopened == []` — for EVERY instrument, not the hunt alone; snapshots the adjudicated ids
   used into `ROUND.toml.closed_by`; writes `closed`, `closed_head`, the tally sha (its own writes are
   what the session then commits and pushes). `gbg round abandon <round> --reason "…"` writes
   `abandoned = {reason, open_ids}` — a plateau is the usual reason, and it is a decision the diff
   shows.
10. **Gate.** `gbg gate [instrument…]` — the CLI face of `gate(instruments...)`, called in-process as
    `gate("check-docs", "check-consistency")` by `GBGCodingTools.makedocs` and as
    `gate("bug-hunt", "audit-changes")` by `TestHarness.gate()`, bare (all four) as `gbg gate` by hand
    and by the CI snippets: it runs `gbg self verify` first; scans **every** round
    directory, enabled instrument or not; any open round → 1 (names it) — EXCEPT the rounds named in
    `GBG_ROUND`, which the CLI exports only while it invokes a build, a test or an executable claim on
    behalf of that open round (`prepare`, `build`, `test`, `pass open`, `close`, `audit-changes bank`);
    an open round of a **disabled** instrument → `CFG.VALID` FAIL; in a working tree (not CI) an open
    round whose directory is untracked or modified while `HEAD ≠ ROUND.toml.head` → 1 (the fixes were
    committed without the round); a round directory without `ROUND.toml` → 2; `.gbg/rounds/` absent
    while instruments are enabled → 2 (`ROUND.DIR`: the gate fails, never passes vacuously, when the
    round directory an enabled instrument implies is absent — the closing of the vacuous-pass hole
    both freeze notes recorded); closed rounds are NOT re-graded on every build (their tally is
    frozen with its hash); re-grading is explicit (`gbg round pass open --regrade`). CI never sets `GBG_ROUND`, so the
    commit/CI gate stays fail-closed; a `GBG_ROUND` set by hand outside a CLI invocation is a stated
    residue (§11). The Stop hook of D13 runs in every consumer, and its body is the managed `sh`
    file — PF's `queue-guard.sh` verbatim, which guards `WORK_QUEUE.md` and never reads a
    round — never a Julia call; it is not part of the gate.

### §6.3 Vocabularies (constants)

| Artefact | Vocabulary | Default / rule |
|---|---|---|
| state verdict | `PRESENT \| PARTIAL(surviving_class) \| REGRESSED \| ABSENT \| NOT-A-DEFECT \| UNCLEAR` | default PRESENT; only ABSENT, NOT-A-DEFECT are favourable |
| act verdict | `HONORED \| ADJACENT \| INSERTED \| LINE-ONLY \| NEW-DEFECT \| SCOPE-CREEP \| UNDONE \| LAUNDERED` + `question ∈ fidelity\|strategy\|implementation\|scope\|none` | HONORED demoted to LINE-ONLY iff `class_surfaces == []` or any entry is `swept: false` |
| severity (every instrument) | `blocker \| major \| minor \| nit`; `serious ≡ blocker \| major` | audit-changes runs `severity-recheck.js` (anchor) before "serious" is counted |
| confidence | `high \| medium \| low` | |
| hunter `observed` | `FAILS \| PASSES \| ERRORS \| NOT-WRITABLE` | only FAILS reaches reproduction |
| reproduction | `REPRODUCED \| EVIDENCED \| NOT-REPRODUCED \| WITNESS-WRONG \| NO-WITNESS-POSSIBLE \| BLOCKED \| ALREADY-COVERED \| NOT-A-DEFECT` | default NOT-REPRODUCED; confirmed = REPRODUCED ∪ EVIDENCED; REPRODUCED ⇒ `witness_path` in the bank-time fail set; EVIDENCED ⇒ `kind = architecture`; ALREADY-COVERED ⇒ `evidence = <file:line of the assertion>`; BLOCKED ⇒ `reason = environment`, assignable only at bank to a witness that ERRORED and was never observed FAILS |
| candidate `kind` | `runtime \| architecture \| api-semantics` | |
| disposition record (`reproductions/<id>.json`) | `fixed \| refused(reason ≥ 24 chars) \| escalated(overturn_when)` | terminator `fixed + refused + escalated == confirmed`; a refutation happens at reproduction and never enters a disposition; frozen at bank (`reproductions_sha`) |
| dismissal audit | `DISMISSAL-SOUND \| UNSAFE \| DISMISSAL-WRONG` | default UNSAFE; `complete = dead == 0 && reopened == []` |
| tally `per_id.state` | the state verdicts above, plus `PASS \| FAIL \| BROKEN \| BLOCKED \| REFUSED` | a bug-hunt finding whose witness was re-run records that witness's status, not a verifier's verdict; widened from six values to ten, which is MAJOR under §5.5 |
| rule `check` (`policy/RULES.toml`) | `scan:<id> \| doctor:<id> \| test:<path> \| harness:<binding> \| panel \| weakness` | what catches the rule's next violation (`RULE.TEST.RULE_WITH_CHECK`); `panel` only where a running instrument decides it |
| architecture fix | `FIXED \| RELOCATED \| PARTIAL \| ABSENT \| NOT-A-DEFECT` | default ABSENT |
| audit concern | `severity` as above; `justified ∈ yes\|no\|unclear`; `previously_worked ∈ yes\|no\|unknown` (required on the behaviour-change lane; `unknown` gated like `yes`); per lane `checked[]` + `candidates_found` required | |
| finding `type` | core: `math \| notation \| structure \| citation \| style \| operational \| currency \| self-containment`; `domain_type` from config | |

Every enum above defaults unfavourable and the `question` axis is universal. **Precondition for every
consumer's adoption:** before it adopts, audit its tally and adjudication code for closed switches over
the old enums — a switch written for the old set silently misreads the new one.

### §6.4 Seeds

`seed_rounds = true` by default for check-consistency — seeded recall is the only non-self-reported
dead-lane signal (`round2-measurement.md:103-111`). A seed catalogue names a consumer's pages and
fragments — a package fact — so it lives in the CONSUMER as `.gbg/seeds.toml` (class C, written by
`gbg init` from the package's former seed list, validated by `CFG.SEEDS` against the `seeds`
definition in `instruments/check-consistency/schema.json`; its sha is stamped as `seed_catalog_sha`
exactly as before, so a round records which catalogue seeded it); `config.seed_catalog` names its
path. Only the fixture's catalogue, `catalog/seeds/fixture.toml`, stays in the tool — D14's "no
copies of consumer configs inside the tool" and the tool's CI running with no consumer checked out
both require it. The seed MECHANISM (below) is the tool's, and a change to it is MAJOR. Selection is
**salted per round**: the round id salts the nth-occurrence offset of every
class, so no two rounds plant the same set and a closed round's tracked `ground_truth.json` is not the
next round's answer key. Seeded manuscripts live under `.gbg/scratch/<round>/` inside the project
(gitignored); during the panel only the seeded copies exist, the unseeded ones being regenerated at
bank; `ground_truth.json` is written at bank, not open; hats never receive it and, like the verifiers,
are forbidden `.gbg/**` and `~/.gbg/**`; the adjudication channel refuses a seeded id; consolidation
subtracts seeded hits before the summary; a hat with ≥ 2 seeds on its substrate and zero matches is
flagged SUSPECT in the tally (reported, not fatal). Two residues are STATED as limits in
`policy/instruments.md` and §11, not claimed closed: a session that opens the seeded copy or
hand-invokes a Workflow, and a hat that diffs the seeded copy it was handed against `docs/build`.

### §6.5 Closure channels (per finding id; PARTIAL never closes)

| Channel | Condition |
|---|---|
| `honored` | act = HONORED after demotion AND state ∈ {ABSENT, NOT-A-DEFECT} in the same pass |
| `adjudicated` | a ledger entry `scope = "finding"`, `target = <id>`, reason ≥ 40 chars, `overturn_when` present; the CLI refuses a seeded id; every such entry recorded after `opened` is audited by `dismissals.js` at close |
| `seeded` | fragment match AND state ∈ {ABSENT, NOT-A-DEFECT} (a real defect co-quoted with a seed comes back PRESENT and stays open; a seeded id wrongly graded PRESENT needs no fix and no adjudication — the next pass re-grades it) |
| `rescan` | a deterministic-scan hit (lane `00-scans`) closes when `grade` re-runs the scan and it no longer fires — never by a graded verdict; when the silence coincides with a `scope = "scan"` ledger entry recorded after `opened`, the closure is written `closed_by = adjudicated` naming that entry (`adjudicated_entry`), never `rescan` |

### §6.6 Deltas — `/check-docs`

Preflight identical; the round additionally runs `gbg scan docs` (every `hard` hit banked as lane
`00-scans`, closed by `rescan`; every `triage` scan printed in full — the catalogue is §12.B), the Julia
checks `argcov` under `argcov_policy`, `signature_fidelity`, `dupref` and `xlink` (dry-run); then the
build (exit 0, under `GBG_ROUND`) and `gbg scan html` (the rendered-markup scan and the built-HTML
questions: no docstring rendered on two pages, every derived public operation on a public page, no
unexpected `Base.` leak into the internal sections — `docs.unexported_base_expected` is the allowance
— and, as a read rather than a scan, each page blurb against its `@docs` contents). Fan-out `lanes.js`
with the surfaces and lanes from config: the engine lanes — one per non-empty surface key, refined by
`lanes_extra`, plus `family`, `cold-reader` with the `?name` substrate rule, and `operational-claims`
on the docstring surface — surface lanes at economy. Banking, verification (the same act verifier with
`lanes` as the roster; the state verifier blind), grading and closure are identical — which closes
the finding that IT's check-docs banks nothing (`survey-checkdocs.md:29`).

### §6.7 Deltas — `/bug-hunt`

Round contents add `candidates/NN-<lane>.json`, `reproductions/<id>.json` (the disposition records),
`witnesses/<lane>-<n>.jl`, `witnesses/escalated/`, `witnesses/blocked/`. `hunt.js`: territory lanes
from config + two free lanes (anchored), hunters produce hypotheses (`kind`, `severity`, `mechanism`,
`witness_plan`, `files_read`); a `pipeline` hands each candidate to a reproducer (session strength)
that writes the witness, runs it with quoted paths under `witness_env`, and derives the expected value
from an oracle independent of the assertion (default WITNESS-WRONG when it cannot). **Bank**
(`gbg round bank`): runs `Witnesses.run(<round>/witnesses; expect = :fail)`, which refuses any witness
that `include`s a file or loads anything outside the package, `Test` and the stdlib; REJECTS any
REPRODUCED whose witness does not fail mechanically; records the **sha256 of each failing witness
body**; assigns BLOCKED only to a witness that ERRORED, was never observed FAILS and carries a
`# blocked: <reason>` header, moving it to `witnesses/blocked/`; **freezes `reproductions/*.json`**
(`reproductions_sha` in `ROUND.toml`) — a bank-time failing witness ends promoted, escalated or refused,
never relabelled BLOCKED. **Fix** (never economised). **Close** requires, in this order: the round's
existing files committed (the hunt directory is untracked until the session commits it; `close` and
the audit round it needs both refuse otherwise); `Witnesses.run(…; expect = :pass)` green; every
`fixed` witness **promoted** into `test/regressions/` with the promoted body (provenance header
stripped) hash-equal to the bank-time body; `Pkg.test()` green under `GBG_ROUND` (`gbg round test`);
`dismissals.js` run with `reopened == []`; **then** an audit-changes round with `base == ROUND.head`
(the hunt's opening head) and `head == HEAD`, closed; the disposition arithmetic
`fixed + refused + escalated == confirmed`; `ROUND.head` an ancestor of `HEAD`; BLOCKED witnesses
listed in the close account with their reasons; clean tree; pushed. Escalated witnesses stay under
`witnesses/escalated/`, never promoted; their disposition carries `overturn_when`; `gbg doctor --deep`
re-runs them (a PASS — with at least one assertion, else BROKEN — prints "promote", the session
promotes; BROKEN ⇒ register stale) and re-runs `blocked/` on a host that has the device. The same two
checks also run over `test/regressions/escalated/` and `test/regressions/blocked/` — consumer-owned
directories (class S, §4) that hold the pre-tool escalated and blocked witnesses a migration carries
(IT's; each file's header carries its `# overturn_when:` or `# blocked:` line), since no imported round
exists to hold them (D17).
`closure.py`'s follow-up-hunt rule is deleted (`survey-bughunt-auditchanges.md:50-52`).

### §6.8 Deltas — `/audit-changes`

`base` REQUIRED (pin the norm at base; `test/` is in the diff); `kind ∈ code|prose|both` derived from
the diff's paths; lanes from `catalog/lanes/audit-changes.toml` (code: free-reader, executing†,
under-rejection†, backend-portability, behaviour-change†, over-rejection†, public-contract, numerics,
invariants, claim-versus-edit; prose: contract-drift†, sweep-completeness, reader-consequence; † =
anchor); `strength` honoured. Concern schema: `{severity, title, file, before, after, why_it_matters,
justified, previously_worked, evidence}` + per lane `checked[]`, `candidates_found`;
`severity-recheck.js` (anchor) runs before "serious" is counted. **Covered paths** are the constants
`src`, `test`, `ext`, `docs`, `Project.toml` plus every `[paths]` entry — config can only ADD.
**Bank** (`gbg audit-changes bank`) itself RUNS the executable claims — `package.julia_test` as the
gate claim, plus each file named in `executable_claims` — under `GBG_ROUND` and records their exit
codes in `audit.json`; the `executing` lane's account is corroborated by a program. **Gate**: every
serious concern and every `previously_worked ∈ {yes, unknown}` concern carries a disposition
`fixed|refused|escalated` (refusal ≥ 24 chars); no dead lane; an empty audit's `verdict_all_clean`
requires `checked[]` on every lane AND the recorded executable-claim exit codes all zero; staleness
`git diff <audited>..HEAD -- <covered>` with UNCHECKABLE ≠ clean; `AUDIT.GAP` (doctor, WARN) when
`base` ≠ the previous closed audit's `head`. `attack-design.js` (four attackers, generic `subject`) is
the instrument every lens list must survive.

**An audit round is disposed, never corrected inside.** The staleness rule and the frozen bank say so
together: a correction moves a covered path, `close` then refuses the round, and `bank` will not run
twice, so the round can never be closed and every disposition recorded in it is lost. `fixed` therefore
names a correction the NEXT change set carries and the next audit covers — the chain `AUDIT.GAP` watches.
The rc.1 audit learned this the expensive way: 49 concerns were corrected inside the round, and the
round could not close.

---
## §7 Policy, managed files, ledger, doctor

### §7.1 Policy migration map (which consumer sections become which policy file)

| Policy file | Sources (by `CLAUDE.md` heading) |
|---|---|
| `docs-rubric.md` | PF "Documentation policy — the docstring rubric" (two-tier, one-home, four shape rules, aliasing, exemptions, API pages, coverage, cross-referencing, review unit, Literate pages, verify-by-build, tables, one-notation, coordinate-free, doc-edit checklist); IT "Documentation policy — physical-meaning first" + "Doc-edit checklist" (constructor-first type docstrings, `# Fields` demoted, `-> Type`, `Returns x.`, display-vs-inline — generic rules join); SS "Documentation policy — estimand first, estimator second" (estimator-variant blocks as the `estimand` value of `leading_identity`); CP "Conventions" (the five-point check). |
| `latex-idiom.md` | PF "Style" (math in docstrings, silent-rendering micro-rules, math spacing/command support, `\left` ban, Greek α/β, signature mirroring); IT/SS/CP paraphrases collapse to PF's text. |
| `citations.md` | PF "Style" citations paragraph; IT's dated adoptions; SS gains the DOI rule. |
| `testing-protocol.md` | PF "Verification workflow" (gate vs survey, definition of done, oracle provenance, mutation audit rule, both-directions, allocation contract as a harness rule); IT "Known weaknesses — self-guards" (the generic guards: "a rule and its check belong in the same commit"); SS "Definition of done". |
| `instruments.md` | PF "Verification workflow" (consent gate, four instruments, witness rule, closure loop, self-reported closure, seeds); IT "Verification workflow"; the honest limits (§11). |
| `git-conventions.md` | PF "Working agreements" (commit ⇒ push on `master`, versionless trailer, CI manual-only, no shims); IT/SS trailer text collapses. |
| `glossary.md` | PF `docs/src/notation.md` conventions + the base/fiber/section bindings; the general terms only. |

Package-specific rules (PF's "representation qualifier trails", "operators are not spectral", the
`\mathbb` cases, cost register — a time-free library's rule) stay in the consumer's `CLAUDE.md`; a rule
that turns out to be shared is promoted into the policy by a MINOR release. The rule ids each file
carries are listed in §12.A.

### §7.2 The ledger `.gbg/exemptions.toml`

```toml
[[exemption]]
id       = "RULE.DOC.STEER"            # a `RULE.*` policy rule id, a `SCAN.*` scan id, a doctor check id, a finding id (`<round>/<lane>#<n>`), or a harness op
scope    = "policy"                    # policy | scan | lint | check | finding | harness
target   = "*"                         # or a symbol / file / finding id
reason   = "In-place steer sentence declined (owner-ruled 2026-08-25): IT's `!` forms are compute/cached-read pairs, not fill-a-destination forms."
recorded = 2026-08-25
expires  = 2027-08-25                  # REQUIRED for every scope but `finding`; ≤ recorded + 365 d; expired → FAIL; ≤ 30 d → WARN
evidence = "IT CLAUDE.md:179-182"

[[exemption]]
id       = "2026-09-01-check-consistency-01/cold-reader#4"
scope    = "finding"                   # the adjudication channel: no `expires`; `overturn_when` instead
target   = "2026-09-01-check-consistency-01/cold-reader#4"
reason   = "The glossary page defines `section`; the umbrella docstring binds it in plain language since 2026-08-04, so the REPL reader the finding imagines already sees the definition."
recorded = 2026-09-02
overturn_when = "the umbrella docstring's base/fiber/section paragraph is removed or the glossary page loses the entry"
evidence = "src/GBGPeriodicFields.jl:12-19"

[[exemption]]
id       = "SCAN.ARGCOV"
scope    = "scan"                      # with `match` the entry REFINES the rule: the predicate is applied per trigger; the rule stays live elsewhere
target   = "src/Interpolation.jl"
reason   = "The stencil-width argument class is documented once on the scheme type; a per-method repetition would violate RULE.DOC.ONE_HOME."
recorded = 2026-09-08
expires  = 2027-09-08
evidence = "src/Interpolation.jl: LalescuSpline, LagrangeSpline"
[exemption.match]                      # optional; scopes scan|lint|policy|harness only; the sub-keys are ANDed
arg_name = "^(n|m|width)$"             # a regex over the argument name
arg_type = "Integer"                   # the declared type of the MATCHED ARGUMENT, tested by `<:`; a reflection scan evaluates it, a text scan refuses the entry
symbol   = "^(LalescuSpline|LagrangeSpline)$"   # a regex over the owning binding's name
```

It replaces `doc-review-adjudicated.md` (scope `finding`, keyed by id — for rounds run under the tool;
the pre-tool adjudication lists are NOT carried over, owner ruling 2026-09-08, and a finding a later
round raises again is adjudicated afresh), the do-not-re-flag lists in
`CLAUDE.md`, `field_docs.py`'s `NO_FIELD_LIST` (scope `scan`, target the type), the allocation audit's
exemption list (scope `harness`), and `CLOSED.md` (replaced by `abandon`). `finding`-scope entries are
injected into hats as titles only; a closed round's tally is frozen, so nothing ever reopens it — which
is why a finding-scope entry carries `overturn_when` (the condition under which the adjudication would
be wrong, for a reader) and no `expires`. Every other scope's `expires` is bounded by
`recorded + 365 d`, so a waiver is renewed on purpose or lapses. An entry carrying an
`[exemption.match]` table (scopes `scan|lint|policy|harness`; the sub-keys are ANDed: `arg_name` — a
regex over the argument name; `arg_type` — the declared type of the **matched argument**, tested by
`<:`, which only the reflection scans (`SCAN.ARGCOV`, `SCAN.SIGNATURE_FIDELITY`, anything under
`Reflection`) can evaluate, so a text scan **refuses** an entry carrying `arg_type` — exit 2 at
`CFG.EXEMPTIONS` — and never ignores it; `path` — a glob; and `symbol` — a regex over the **owning
binding's name**) does **not** silence its rule: the engine applies the predicate per trigger
and the rule stays live on every trigger the predicate does not cover, which is what a class-level
exception is (the stencil-width argument class is a refinement of `SCAN.ARGCOV`'s rule
`RULE.DOC.ARGCOV`, not a disabled rule). Every engine with a trigger population — `Reflection.argcov`
included — applies the predicate itself and reports the population; `EXEMPT.BROAD` (WARN) runs the
predicate dry over that reported population and flags a `match` that covers more than half of it —
an engine that reported no population would leave it nothing to dry-run. **Non-exemptable ids**: `PIN.*`,
`CFG.*`, `EXEMPT.*`, `WIRE.*`, `MANAGED.*`, `SHIM.*`, `POL.*`, `ROUND.*`, `SELF.*` — a `scope = "check"` entry
naming one is itself `CFG.EXEMPTIONS` FAIL. **Exemptable**: `LEG.*`, `GIT.*`, `AUDIT.*`, and every
`policy|scan|lint|harness|finding` target (the one set; D14 states the same). `CFG.EXEMPTIONS` refuses a `target = "*"` on scope `check`.

### §7.3 The doctor check table (stable ids; exit 1 on any FAIL, 2 if the repo is not a consumer)

**Sets.** `QUICK` = `{CFG.* (CFG.TORN excepted), PIN.CONFIG, PIN.SOURCES, PIN.NOT_DEV, EXEMPT.*, WIRE.*,
MANAGED.HASH, ROUND.*, POL.SENTINEL, SELF.CONSUMER, AUDIT.GAP}` — the checks that hold on a runner with no shim and a detached
HEAD; it is what `gbg preflight`, the `makedocs` wrapper and `TestHarness.gate()` run, and what
`--only QUICK` names. `CFG.TORN`, `ENV.*`, `SHIM.*`, `GIT.*`, `LEG.*`,
`PIN.TREESHA`, `PIN.SELF`, `MANAGED.STALE`, `POL.IMPORT`, `POL.COLLAPSED`, `AUDIT.*` other than
`AUDIT.GAP`, `SELF.DOCS` and every other `--deep` check are never in `QUICK` — `CFG.TORN` runs in `gbg preflight` and in every `gbg round` verb only, so
the `makedocs` wrapper and `TestHarness.gate()` never refuse a build or a test over an uncommitted
managed file. `--only <id-or-prefix>[,…]` selects by exact id or by prefix
(`--only LOAD`, `--only WITNESSES`, `--only LEG.SENTINELS`). This table is the final list; the
implementation plan refers to it and adds no id of its own.

| Id | Check | Fails when |
|---|---|---|
| `ENV.JULIA` | `julia` on PATH; channel ≥ the consumer's floor | otherwise |
| `ENV.SHIM` | `~/.local/bin/gbg` exists and is executable | missing |
| `ENV.DEV_CHECKOUT` | `~/.gbg/dev` exists and names a directory whose `Project.toml` is `GBGCodingTools` | WARN when absent (needed only by `--dev` and outside-consumer verbs) |
| `SHIM.HASH` | `command -v gbg` resolves to `~/.local/bin/gbg` and its body equals `bin/gbg` of the pinned copy | another `gbg` earlier on PATH; differs (stale shim) |
| `PIN.CONFIG` | `[tool] version` is a released tag `vX.Y.Z` (never a prerelease `vX.Y.Z-rc.<n>`, D16); the literal `dev` only at the tool's own root and in a consumer enclosed by the tool repository (the fixture; D15) | not a tag / `dev+…` / `dev` outside the tool repo |
| `PIN.SOURCES` | every sub-env `Project.toml` listing the tool agrees with the pin (url https, rev, `[compat] =`; under a `dev` pin: the `path` source resolving to the tool repository — the enclosing one for the fixture, the root itself (`path = ".."` from `docs/`) for the tool); a `-rc.` rev is refused in any consumer other than the tool itself — an rc tag is never a consumer pin (D16) | any differs or missing; a `-rc.` rev outside the tool root |
| `PIN.TREESHA` | the `git-tree-sha1` agrees across every sub-env `Manifest.toml` that exists and equals `Pkg.dependencies()[uuid].tree_hash` for the copy the `docs/` environment resolves — the copy the shim execs | disagreement; WARN per sub-env without a manifest; WARN "dev pin" |
| `PIN.SELF` | `gbg self verify`: the running copy's recomputed git tree hash (`src/TreeHash.jl` over `pkgdir(GBGCodingTools)`) equals `Pkg.dependencies()[uuid].tree_hash` and the manifests' `git-tree-sha1`, and that entry reports `is_tracking_repo && !is_tracking_path` (a `Pkg.develop`'d copy lives inside the depot at `~/.julia/dev`, which a path-prefix test cannot catch) | edited or dev'd pinned copy (exit 2 from every `round` verb and `gate`); WARN with no manifest / dev pin |
| `PIN.NOT_DEV` | no `dev`'d GBGCodingTools in any manifest | found; WARN "dev pin" |
| `SELF.CONSUMER` | the tool repository — the current root when that root IS the tool, the enclosing repository for the fixture, the registered dev checkout under `--dev` — carries a valid `.gbg/config.toml` with `[tool] version = "dev"` and `[package] name = "GBGCodingTools"` (D15); the literal `dev` is carried by the tool root and the fixture and by nothing else (`PIN.CONFIG` refuses it where the doctor runs; this check is the tool root's own); in an ordinary consumer with no tool repository in reach it is reported not applicable, never as a pass; in `QUICK`, non-exemptable | no config at the tool root, a pin there other than `dev`, a `[package] name` other than `GBGCodingTools`, or a `dev` pin anywhere but the root and the fixture |
| `CFG.VALID` | config parses, schema-valid, closed keys, required present, every path exists; no open round of a disabled instrument | otherwise |
| `CFG.TORN` | the torn-file guard (non-exemptable; **not in `QUICK`** — run by `gbg preflight` and by every `gbg round` verb, and by nothing the `makedocs` wrapper or `TestHarness.gate()` runs): `git status --porcelain` shows none of the pinned or managed files modified — `.gbg/config.toml`, `exemptions.toml`, `hats/*.toml`, `seeds.toml`, `managed.json`, every sub-environment `Project.toml` listing the tool, the SKILL stubs, the rendered policy; round files under an open round are exempt, which keeps this distinct from the "uncommitted change under a closed round" refusal (both machines edit Dropbox-synced checkouts, and a half-synced config would grade a round under a config nobody wrote); whether a file parses is `CFG.VALID`, not this check | a modified pinned/managed file (exit 2 from `preflight` and every `round` verb) |
| `CFG.SURFACES` | every non-optional surface glob matches ≥ 1 file; every `file#heading` anchor resolves to exactly one heading; every module exists; every `[paths]` entry is a directory; the `glossary` file exists and a non-empty `built_html` has a `docs/` directory beside it; `docs/make.jl` exists (the config schema is what pins `docs_build` to name it); `julia_test` contains `Pkg.test()`; every `executable_claims` file exists under `test/` | otherwise |
| `CFG.HATS` | every hat key resolves (catalogue or `.gbg/hats/`); anchors ⊆ hats; ≥ 1 anchor; no persona names another fleet package; a hat with empty substrate is marked, not expected; every `rulebook_sections` anchor resolves | otherwise |
| `CFG.SEEDS` | `seed_rounds = true` ⇒ the file `seed_catalog` names (default `.gbg/seeds.toml`) exists and validates against the `seeds` definition of `instruments/check-consistency/schema.json` | missing or invalid |
| `CFG.EXEMPTIONS` | every entry: known id by its prefix (`RULE.` in `policy/RULES.toml`, `SCAN.` in the catalogue, a doctor check, a finding id, a harness op), reason ≥ 40, `expires` present and ≤ `recorded + 365 d` (or `overturn_when` on scope `finding`), no non-exemptable id, no `target = "*"` on scope `check`; a `match` table only on scope `scan\|lint\|policy\|harness` and only with the four sub-keys; no `arg_type` sub-key on an entry a text scan would apply — only the reflection scans can evaluate it, and such an entry is refused (exit 2), never ignored | otherwise |
| `EXEMPT.EXPIRED` / `EXEMPT.EXPIRING` | expiry passed / within 30 d (finding scope skipped) | FAIL / WARN |
| `EXEMPT.STALE` | the target still exists (a symbol, a file, a finding id) | gone |
| `EXEMPT.BROAD` | a dry run of every `[exemption.match]` predicate over the trigger population its engine reports in the consumer (every engine with a trigger population, `Reflection.argcov` included, applies the predicate itself and reports the population): no single `match` covers more than half of it | covers more than half (WARN) |
| `WIRE.MAKEDOCS` | `docs/make.jl`, comments and strings stripped, calls `GBGCodingTools.makedocs(` and contains no `makedocs(` token not preceded by `GBGCodingTools.` and no `function lint_` | otherwise |
| `WIRE.RUNTESTS` | `test/runtests.jl`, comments and strings stripped, calls `TestHarness.run_regressions(` and `TestHarness.gate(`; `test/regressions/` exists | otherwise |
| `WIRE.CI_AUTH` | `.github/workflows/{CI,docs}.yml` carry the `GBG_DEPS_TOKEN` `insteadOf` step as the first step after `actions/checkout`, and a last step grepping the tee'd `gbg-run.log` for the banner that job prints (the snippet's insertion points, §3) | missing or out of place |
| `WIRE.GITIGNORE` | the managed block is present and intact | otherwise |
| `WIRE.CLAUDE_MD` | the managed block present, equals the render of config; import line intact | edited / stale |
| `MANAGED.HASH` | every managed file equals a FRESH render of the pinned template under the current config (`managed.json` is a cache) | MODIFIED |
| `MANAGED.STALE` | every template of the pinned version is rendered and listed | STALE (missing or older template) |
| `LEG.COMMANDS` | no `.claude/commands/{check-docs,check-consistency,bug-hunt,audit-changes}*`, `manifest.py`, `MANIFEST.txt`, `INVENTORY.md` | present |
| `LEG.PILES` | none of the piles the migration imported or deleted is present — PF: `.claude/{doc-review,doc-review-prev,doc-review-checkdocs,check-docs-*,audit-changes,doc-review-adjudicated.md}`; IT: `.claude/{doc-review,doc-review-prev,doc-review-minimal,doc-review-round1,doc-review-closures,review-rounds,rubric-audit,audit-changes,bug-hunt,doc-review-adjudicated.md,README.md}`; SS: `.claude/doc-review`. IT's history piles kept under Q12 (`arch-research/`, `archive/`, `*-pile.md`, `OPEN-ITEMS.md`, the dated notes) are NOT in the list | present |
| `LEG.LINTS` | no `lint_*` function bodies in `make.jl`; no copies of the harness bodies in `test/` | present |
| `LEG.SENTINELS` | `CLAUDE.md` outside the managed block, whitespace-normalised and split into sentences — text inside quotation marks and fenced blocks ignored, so a postmortem that QUOTES a rule verbatim (IT's "Known weaknesses — self-guards") is not a duplicate — contains no sentence equal to a rule's `sentinel` in `policy/RULES.toml` (the first sentence of that rule's paragraph in `policy/*.md`, verbatim) | an exact sentinel match is FAIL; a sentence sharing a run of twelve consecutive words with a sentinel is WARN, never FAIL |
| `POL.IMPORT` | `@.gbg/policy/00-index.md` resolves | otherwise |
| `POL.SENTINEL` | the policy copy's version stamp == the pin | otherwise |
| `POL.COLLAPSED` | collapsed artefacts absent: model-versioned trailer, "knob"/"tweak" in prose (quoted words and code spans ignored), the June `lint_inline_math` | present |
| `GIT.BRANCH` | current branch == `git.branch`; `origin` set | otherwise |
| `GIT.TRAILER` | last 20 commits carry the versionless trailer | otherwise (WARN) |
| `ROUND.DIR` | `.gbg/rounds/` exists while any instrument is enabled | absent |
| `ROUND.MARKER` | every round directory has `ROUND.toml` | one without |
| `ROUND.OPEN` | lists open rounds (WARN; never FAIL — a fix pass may span sessions) | — |
| `ROUND.ABANDONED` | lists abandoned rounds with their carried `open_ids` (WARN) | — |
| `ROUND.DEV` | lists closed `/check-docs` and `/check-consistency` rounds stamped `dev+` or `dev` — recorded, not comparable, and citable by no release (WARN; the refusal is at `preflight`, where the round can still not be opened, and in `gbg release`, on the round it cites). An audit or hunt round reads `base..HEAD` and is off-tag by construction, so it is never named | — |
| `ROUND.FROZEN` | every closed round's stored tally sha matches `ROUND.toml`; every closed round's `findings.json` sha matches `findings_sha`; `reproductions_sha` where present; and every stamp names its own revision — `dev+<sha>` begins `tool_rev`, a pinned `vX.Y.Z` equals it, a tag stamp resolves to it where the tool repository is in reach (the shas cover the evidence, not the stamps, so a re-stamped record passed unseen) | tampered |
| `AUDIT.GAP` | every closed audit round's `base` equals the previous closed audit's `head` | otherwise (WARN) |
| `LOAD.ENVS` (`--deep`) | `using GBGCodingTools` loads in every sub-env that lists it (resolve/instantiate/LOAD are not interchangeable; `Pkg.gc()` can remove a copy referenced only by a test sandbox — instantiate restores it) | error |
| `BUILD.DOCS` (`--deep`) | `docs_build` exits 0 and the build log carries the `GBGCodingTools v<ver> makedocs` banner | otherwise |
| `SELF.DOCS` (`--deep`) | at the tool root only (not applicable in a consumer): the tool's own docs build — `julia --project=docs docs/make.jl` in the dev checkout — exits 0, its log carries the `GBGCodingTools v<ver> makedocs` banner, and its docs environment resolved `GBGCodingTools` by path (`Pkg.dependencies()[uuid].is_tracking_path` — the working tree, D2's bootstrap circularity made checkable); what `gbg release` and the fleet's fifth row run; a release precondition, never a selftest arm (§8); non-exemptable | otherwise |
| `TEST.PKG` (`--deep`) | `julia_test` exits 0 and its log carries the `GBGCodingTools v<ver> gate` banner printed by `TestHarness.gate()` | otherwise |
| `WITNESSES.ESCALATED` (`--deep`) | every round's `witnesses/escalated/*.jl`, and `test/regressions/escalated/*.jl` (the pre-tool ones carried at migration, §6.7), still FAILS; prints each `overturn_when` | PASS with ≥ 1 assertion ⇒ prints "promote" (the session promotes); PASS with zero assertions or BROKEN ⇒ stale |
| `WITNESSES.BLOCKED` (`--deep`) | on a host with the device, every round's `witnesses/blocked/*.jl` and `test/regressions/blocked/*.jl` re-run and reported | informational |

---
## §8 Self-test and versioning

**Fixture.** `fixture/GBG Fixture/` (the space is deliberate — every real consumer path has two):
three modules, docstrings carrying every catalogued defect class at known positions (`defects.toml`,
one entry per `hard` scan of §12.B and one per triage scan that has a deterministic true positive),
a `docs/` site, `test/` with one regression and the harness calls, a complete `.gbg/` with two domain
hats and a config that validates — pinned `[tool] version = "dev"`, its sub-environments on the
`path` source to the enclosing tool repository (D15), so it builds before any tag exists. Its seed
catalogue is `catalog/seeds/fixture.toml` — the one catalogue that stays in the tool (§6.4) — named by
its config as `seed_catalog = "../../catalog/seeds/fixture.toml"`. `gbg selftest --pinned` exercises the pinned-copy
behaviours on a throwaway copy outside the repository, pinned at the released tag.

**Must-fail arms (every gate, both directions, plus absence).** For each gate in {config validation,
preflight, bank, grade, close, abandon, gate, doctor, sync-MODIFIED/STALE, witnesses runner, audit gate,
recall, demotion, scans, self verify}: a clean arm that passes; one arm per failure mode on a perturbed
COPY of a fixture round that fails with the documented exit code; an absence arm (input missing → exit
2). Named cases: copy-forward verdicts (old nonce → REJECTED); PARTIAL with HONORED (stays open); seeded
id in the ledger (refused); a co-quoted seed with state PRESENT (stays open); `bank` on a DEAD lane
(exit 2, nothing frozen); a malformed lane file (DEAD, quarantined); `rerun` on a live lane (refused);
a live lane whose sha changed (REJECTED); a hat with two seeds and no match (SUSPECT in the tally);
weakened witness at promotion (hash mismatch); a witness that `include`s a helper (refused); a
REPRODUCED witness relabelled BLOCKED after bank (`reproductions_sha` mismatch); a bare `makedocs(`
and a commented-out `GBGCodingTools.makedocs(` (both WIRE.MAKEDOCS); a managed file edited together
with its `managed.json` entry (MODIFIED); **the gate ignores exactly the round named in `GBG_ROUND`
and fails on any other open round**; a changed `config_sha` under an open round (every `round` verb
exit 2); a torn config — `config.toml` modified in the working tree — (`CFG.TORN`: `preflight` and every
`round` verb exit 2, while the `makedocs` wrapper and `TestHarness.gate()` run to completion on the
same tree, `CFG.TORN` being outside `QUICK`); a `match` covering more than half of a rule's triggers
(`EXEMPT.BROAD` WARN); an `arg_type` sub-key on an entry a text scan would apply (`CFG.EXEMPTIONS`
exit 2); a quoted
sentinel sentence in `CLAUDE.md` (`LEG.SENTINELS` silent) beside a bare one (FAIL) and a twelve-word run
(WARN); an edited pinned copy (`self verify` exit 2, under `--pinned`); a `tool_tree_sha` change
under an unchanged version (abandon-only); `expires` beyond `recorded + 365 d` (CFG.EXEMPTIONS); a
`scope = "check"` entry on a non-exemptable id (refused); a scan missing its fixture pair (selftest
fails); the doctor perturbations (delete the import line, edit a managed file, move the pin, open a
stale round, expire an exemption, add a `.claude/commands/check-docs.md`, put another `gbg` first on
PATH); the `SELF.CONSUMER` perturbations on a copy of the tool root (its `.gbg/config.toml` removed,
its pin moved off `dev`, a `dev` pin planted in a consumer copy outside the tool repository — each the
exact id); a round on a perturbed tool-root copy — opened at a clean tag (a throwaway git repository
tagged `v9.9.9`, clean) closes, opened at a clean prerelease tag (`v9.9.9-rc.1`) closes likewise and
is stamped with that tag, opened with the tree dirtied first refuses `close`, abandon-only (D16).
A scan in `catalog/scans.toml` without a fixture pair fails the tool's test.

**Release preconditions (not selftest arms).** `gbg release <ver>` refuses (exit 2) unless, in the dev
checkout at a clean tree: `Pkg.test()` is green; the tool's own docs build exits 0 (`SELF.DOCS`);
`gbg doctor --deep` is green at the tool root; no round is open under the tool's `.gbg/rounds/`; the
`/check-docs` round opened at the latest `<ver>-rc.<n>` tag is closed (through any of the five
closure channels — honored, adjudicated, rescan, seeded, carried — never abandoned); the `CHANGELOG.md` entry for `<ver>` is present; the tag is absent (D16). The prerelease
form `gbg release <ver>-rc.<n>` runs the same refusals except the open-round refusal and the
closed-round precondition (D16); an rc tag is never a consumer pin. "The tool's own docs build green"
is a release precondition and deliberately NOT a selftest arm: `Pkg.test()` IS `gbg selftest`, and a
test suite that built the package's own site on every run would make the docs environment a test
dependency and double the suite's time for a check the release verb and `docs.yml` already run. The
tool's own rounds (D15) are recorded under its `.gbg/rounds/`; the first is the `/check-docs` round the
implementation plan's Phase 1.10 opens at the clean `v1.0.0-rc.1` tag and closes before `v1.0.0`.

**Step-0 instrument-equivalence test.** Runs on the LIVE working trees, not scratch clones — PF's
largest round is the UNTRACKED `.claude/doc-review/` on `Aiporetne`'s working tree, and a clone does
not contain it; IT on `Enteropia` or the Dropbox copy. Three verbs carry it, and they are defined here:

- **`gbg round import <pile…>`** writes into the consumer's `.gbg/rounds/<round>/` (creating
  `.gbg/rounds/` if absent; the imports are SCRATCH — graded, compared and deleted inside Phase 2,
  never staged, so every consumer's `.gbg/rounds/` starts empty at migration; owner ruling
  2026-09-08), one round per pile — or per `rounds.json` entry / closure directory —
  named `<record date>-<instrument>-<NN>`. It writes `ROUND.toml` (`tool_version` and
  `tool_tree_sha` of the running copy; `config_sha` of the config present at import, or the empty
  string when `.gbg/config.toml` does not exist yet — the Phase 2 case; `head` = HEAD at import;
  `opened`/`closed` = the record's dates where it carries them, else the import time;
  `abandoned = {reason, open_ids}` from the record's own open list), `findings.json` (ids from the
  title → id map), the verdict passes the pile lets it reconstruct, the witnesses where the pile has
  them, and `import.json` (§6.1). It needs no `.gbg/config.toml` — the one `round` verb that runs
  before `init`; `self verify` still precedes it — and refuses (exit 2) an existing target round, so
  an import repeated on the same tree cannot double up. `gbg round import --empty <round> --reason
  "…"` writes a round holding only `ROUND.toml` (`abandoned = {reason, open_ids = []}`) and
  `import.json` (`source = "none"`), for a record that has witnesses but no round entry (IT's round 4).
- **`gbg round grade <round>`** on an imported round re-computes the tally from the imported verdict
  files — the one case in which `grade` accepts a round that is not open.
- **`gbg round compare --recorded <recorded.toml> <round>`** compares that re-graded tally with a
  record transcribed by hand into `.gbg/rounds/<round>/recorded.toml`:

```toml
# recorded.toml — transcribed by hand from the pre-tool record; lives with the scratch import (deleted with it)
source      = ".claude/doc-review/CLOSED.md:3,63"   # where the numbers were read
findings    = 67     # banked findings, seeded included
seeded      = 11     # 0 for an unseeded round
honored     = 59     # HONORED at the last pass, after demotion
# adjudicated: not carried by this record — omitted, printed UNRECORDED
```

  The four count keys are the only ones compared; a key the record does not carry is omitted and
  printed as UNRECORDED, never compared; a file with none of the four is exit 2. For a bug-hunt
  record the keys are read as `findings` = confirmed, `honored` = fixed, `adjudicated` = refused +
  escalated, `seeded` = 0; for an audit record `findings` = concerns, `honored` = fixed,
  `adjudicated` = refused + escalated. Exit 0 when every present key equals the re-graded tally; 1 on
  any difference, each printed; 2 for a missing file or a round that was not imported.

The re-graded tallies must equal the recorded ones before `v1.0.0` is tagged. The targets, per round:

| Source pile | Imported as | Recorded target |
|---|---|---|
| PF `.claude/doc-review/` (untracked, 2026-09-01 panel) | `2026-09-01-check-consistency-01` | 67 findings, 11 seeded, HONORED 39 → 59 → 59 at the last pass (`CLOSED.md` L3, L63) |
| PF `.claude/check-docs-2026-09-01/` (tracked) | `2026-09-01-check-docs-01` | 18 findings banked across 11 lanes, 18 closed (17 fixed, 1 dismissed) (`CLOSED.md` L3) |
| PF `.claude/doc-review-checkdocs/` (tracked, 2026-08-27) | `2026-08-27-check-docs-01` | 8 findings across 5 lanes; 30 HONORED verdicts and the predicate measurement as its `CLOSED.md` records |
| PF `.claude/check-docs-2026-07-22-findings.json` | `2026-07-22-check-docs-01` | 134 findings, all fixed or dismissed (per PF `CLAUDE.md`) |
| IT `.claude/review-rounds/2026-08-24-check-consistency.md` + `.claude/doc-review-closures/{panel-r1,round-1,round-2,round-3}` + `.claude/doc-review-round1/` | one check-consistency round per closure directory | each marker's `closed:` account and per-round closure counts |
| IT `.claude/audit-changes/latest.json` | one audit-changes round | its recorded verdicts |
| IT `.claude/bug-hunt/rounds.json` (rounds 1, 2, 3, 5, 6) | one bug-hunt round each; an entry without counts (round 3) imports as `abandoned` | `confirmed/fixed/refuted/escalated` counts where recorded |

A difference is a finding in the port, not a re-baseline. The mechanisms IT's rounds exercised
(profile, `PARTIAL`/`surviving_class`, `checked[]`/`candidates_found`, required `base`) are in 1.0.0
(D17); a defect this test finds after the tag is fixed and released as 1.0.x. PF's untracked
`.claude/doc-review-prev/` — the closed round 6 of 2026-08-15 (65 findings, no verdict files, closed to
the self-report standard of its day) — is not in the table: with no verdicts there is nothing to
re-grade, and it is discarded at PF's migration (Q13). What the test leaves behind is the comparison
table in the tool's `CHANGELOG.md` and nothing in any consumer.

**Semver rule.** As D16. **CHANGELOG** entry shape: version, date, MAJOR|MINOR|PATCH, instruments
affected, "rates comparable: yes|no", for a MAJOR the fixture recall before/after. **Stamps**:
`ROUND.toml` and every `pass.toml` carry `tool_version, tool_rev, tool_tree_sha, schema_version,
config_sha, catalog_sha, seed_catalog_sha, hostname, model_hint`; every artefact carries
`schema_version`.

---

## §9 Resolution table

Class: **collapsed** (historic artefact, one side wins) · **config** (a variation point) ·
**deviation** (a ledger entry with reason and expiry) · **owner** (owner to decide at migration;
default in brackets) · **consumer ruling (not tooling)** (a decision about a consumer that the tool
supports either way; ruled separately by the owner, never bundled with the adoption commit).

| Divergence | Resolution | Class |
|---|---|---|
| Demotion by content (PF) vs emptiness (IT) — `survey-check-consistency.md:237-239` | CONTENT since 2026-09-10: any `class_surfaces[]` entry `swept: false` demotes, emptiness included. Emptiness alone fired 0 times in 571 verdicts while admitting 21 closures whose own list named an unswept surface | PF's option, restored on the measurement |
| Staleness mtime (PF) vs none (IT) — `:242-244` | hash + nonce, no mtime | collapsed (neither) |
| State/act verdict sets — `:247-249` | the unions of §6.3 | collapsed (union) |
| Closure gate: untracked pile + `CLOSED.md` (PF) vs marker + `closed:` (IT) — `:252-254` | tracked rounds, per-finding by id, `abandon` with enumerated ids | collapsed |
| Adjudication by title (PF) vs prose bullets (IT) — `:257-259` | ledger entries by id, `overturn_when` | collapsed |
| Roster hardcoded (PF) vs `hats.json` census (IT) — `:262` | CLI-known roster from `ROUND.toml`; no census agent | collapsed (neither) |
| `recall.py` unverifiable seeds dropped (IT) vs kept (PF) — `:265` | kept in the denominator, named UNDEFINED | collapsed (PF) |
| Seeding optional (PF) vs every round (IT) — `:82` | `seed_rounds = true` default; salted per round | config (default IT) |
| Panel profile (IT) vs fixed roster (PF) — `:77` | profile mechanism in the engine; `profile = "all"` (PF) / `"core"` (IT) | config |
| Anchors 2 vs 4 | per-hat `anchor` (domain hats in config; engine lanes in the catalogue) | config |
| IT rulebook hats vs PF's package-specific personas | rulebook hats generic in the catalogue over `rulebook_sections`; PF's `gpu-kernel-practitioner`/`normalization-convention-auditor` are PF domain hats | collapsed / config |
| Hunt partition territory (PF) vs class + free (IT) — `survey-bughunt-auditchanges.md:193` | territories + two free anchored lanes | collapsed (engine) |
| Who writes the witness — `:194` | IT's reproducer stage + the mandatory mechanical re-run | collapsed |
| Hunt verdict set — `:196` | §6.3 reproduction vocabulary (+ BLOCKED) | collapsed (union) |
| Witness round prefix — `:197` | rounds are directories; `<lane>-<n>.jl` | collapsed |
| `dismissals` `complete` — `:210` | `dead == 0 && reopened == []`, run at every instrument's close | collapsed (PF) |
| `witnesses.jl` exit on BROKEN, pile as argument — `:217-223` | BROKEN ⇒ non-zero (IT); directory as argument (PF); `Base.julia_cmd()` (IT); no `include` | collapsed (union) |
| Audit `base`, pin-at-base, test-in-diff, `kind` — `:227-228` | required (IT) | collapsed (IT) |
| Audit `checked[]`/`candidates_found` (IT) vs `previously_worked` (PF) — `:230` | all required | collapsed (union) |
| Audit `strength` ignored (IT) — `:231` | honoured | collapsed (PF) |
| Gate staleness `git log -1` (IT) vs `git diff` + UNCHECKABLE (PF) — `:238` | PF's | collapsed (PF) |
| Empty audit `verdict_all_clean` (IT, written by the session) — `:241` | `checked[]` on every lane + the CLI runs the executable claims and records exit codes | collapsed (neither) |
| Audit severity `serious/notable/minor` — `:64` | unified `blocker/major/minor/nit`, serious ≡ blocker\|major, re-checked by `severity-recheck.js` | collapsed |
| IT `closure.py` follow-up hunt — `:50-52` | deleted | collapsed |
| `argcov` triage (PF) vs gate (IT) — `survey-checkdocs.md:159` | `argcov_policy` (the one configurable tier) | config |
| `argcov` Greek identifiers, `arg = default` (IT) vs exemption classes (PF) — `:157-158` | union | collapsed |
| DOI cross-check breadth — `:164` | IT's checks + PF's breadth + info direction; `references_heading` or `"absent"` | collapsed (union) |
| Sentence-opener grep (IT) vs computed script (PF) — `:151` | PF's script (`SCAN.SENTENCE_OPENER`) | collapsed |
| Prose-shape ratchets — `:169`, `survey-buildlints-hooks-policy.md:21` | one Julia scan, one CSV schema, always-binding caps + page units + structure checks; re-baselined once per consumer | collapsed (MAJOR-class baseline) |
| PF `lint_retired_claims` (PF only) | `docs.retired_claims` feeding `SCAN.RETIRED_CLAIMS`; `[]` elsewhere | config |
| `\mathbf` banned (IT) vs `\mathbf{1}` prescribed (PF/SS) — `survey-buildlints-hooks-policy.md:37` | one rule `RULE.TEX.MATHBF` with `mathbf_allowed`, and `\mathbf{1}` admitted in every package whatever that list holds (RULE.TEX.MATHBB's indicator); IT `[]` until dispositioned | config |
| `\boldsymbol` vectors (IT) vs components (PF) | `notation.vectors` | config |
| Estimand-first (SS) | `rubric.leading_identity = "estimand"` | config |
| Admonition titles always (PF) vs bare `!!! note` (IT; no ruling on disk) | `docs.admonition_titles` supports both; which value IT takes is a decision about IT, ruled separately, never bundled with the adoption commit | consumer ruling (not tooling) |
| In-place steer sentence declined (IT, owner-ruled 2026-08-25) | ledger `RULE.DOC.STEER` | deviation |
| Module map "deliberately tighter" (IT) | ledger `RULE.DOC.MODULE_MAP` | deviation |
| Bold argument bullets required (SS) vs forbidden (PF) — `survey-checkdocs.md:109` | SS's corpus counted 2026-09-08: 0 bold, 80 plain — the bold form lived only in SS's old command prose; the hard scan applies to SS unchanged | collapsed (PF; owner-ruled 2026-09-08) |
| Result-affecting smoothing controls as keywords (SS) | ledger `RULE.API.POSITIONAL` | deviation |
| SS `julia = "1.11"` | tool supports 1.11; SS floor untouched | config (kept) |
| IT `doctest = false` | `docs.doctest` | config |
| IT `git checkout -- docs/Project.toml` post-build | `docs_post` | config |
| IT on `main` | `git.branch` supports both; a rename is a decision about IT, ruled separately, never bundled with the adoption commit | consumer ruling (not tooling) |
| Trailer names a model version (IT/SS) | versionless trailer, owner-ruled 2026-09-04 | collapsed |
| `.claude` tracking policies differ | `.gbg/rounds` tracked everywhere, `settings.local.json` gitignored everywhere | collapsed |
| Request files tracked (PF) / untracked (IT) | `.gbg/requests/` tracked in the requester, OPEN requests only; a concluded request is deleted at migration (PF's two July files; IT's nine read for status) | collapsed (owner-ruled 2026-09-09) |
| `CLAUDE.md` shape: PF 2697 lines (≈1500 of state and roadmap), SS 680 (246 roadmap), IT 504, CP 133 | one skeleton (D12); finished work deleted, live plans to a tracked `docs/ROADMAP.md`, trimmed at each migration | collapsed (owner-ruled 2026-09-09) |
| IT tracked root `Manifest.toml` | kept until a registry | deviation `RULE.GIT.MANIFEST_TRACKED` |
| IT `INVENTORY.md`, `README.md`, `MANIFEST.txt`/`manifest.py` (both) | content → tool `CHANGELOG`/`ARCHITECTURE`; files deleted; `managed.json` replaces manifests | collapsed |
| IT `rubric_extract.py` constants, `xlink.jl` `APPLY=1`, U+200B path, PF unquoted `cd` — surveys | engine generic; dry-run default; gone with the files | collapsed |
| IT `lanes.js` dated rename note, `audit.js` "605 lines" preamble — `survey-checkdocs.md:132`, `survey-bughunt-auditchanges.md:172` | gone; args carry the round | collapsed |
| SS June `lint_inline_math`, July panel fork | replaced wholesale | collapsed |
| SS symbol/arg tables required in reports | dropped (a PF-era report format) | collapsed |
| SS `inspiration/` citation as style reference | dropped (inaccessible source) | collapsed |
| CP "knobs" ×5 | reworded at migration (register rule `RULE.DOC.REGISTER`) | collapsed |
| CP `persistent_tasks = false` | dropped at CP's migration: its recorded reason (a flaky probe under solver dependencies) names dependencies CP no longer has | collapsed (owner-ruled 2026-09-08) |
| Pre-tool review piles (PF five, IT six, SS one) | deleted at each migration, never imported; Step 0 reads PF's and IT's on scratch and keeps one CHANGELOG table; `.gbg/rounds/` starts empty everywhere; old adjudications not carried | collapsed (owner-ruled 2026-09-08: no history) |
| IT's fourteen non-instrument notes under `.claude/` | removed by IT's own pre-migration commit (the live TurTLE runbook → `validation/RUNBOOK.md`; `OPEN-ITEMS.md` until its open items are ruled); every consumer's `.claude/` ends with the same shape | collapsed (owner-ruled 2026-09-08) |
| CP no `test/Project.toml` | created by `gbg init` (switches CP's test env from `[extras]/[targets]` to a project — stated, not silent) | collapsed |
| CP floating `[sources] url` for SS (root `Project.toml` L19–20 AND `docs/Project.toml`) | both gain a `rev` in the same pass | collapsed |
| PF `WORK_QUEUE` Stop hook | fleet-wide: the managed `sh` hook of D13 — PF's script verbatim — and a seeded `WORK_QUEUE.md` in every consumer, no config switch; the tool never reads `WORK_QUEUE.md` for closure | collapsed (owner-ruled 2026-09-09) |
| `.claude/settings.json` generated | yes, in every consumer (it wires the fleet-wide hook) | collapsed (owner-ruled 2026-09-08/09) |
| Display gate `UnionAll` fix (IT) not back-ported; regression loop spelling | one engine in `TestHarness` | collapsed |
| SS GPU suite hand-built twins vs PF `adapt` | out of scope (a consumer test, not tooling); noted | — |
| Two config validators (every proposal) | one, in Julia (`Schema.jl`), called in-process by `Config.read()` and by every verb | collapsed |
| Two text-scan engines (Julia lints + Python scans) | one Julia catalogue (`src/Scans/`), called in-process by the docs-build wrapper — no twin in any language | collapsed |

---

## §10 Entailments, extensions of the record, and residual judgment calls

**Requirement → decision (forced, not chosen):**

- R1 + R4 + R7 ⇒ one repo, one version (D1); R1 + R11 ⇒ closed vocabularies (D11); R1 ⇒ the default
  disposition of a difference is collapse (D17, §9).
- R2 ⇒ a committed pin (D3), stamped rounds (D10/D16), policy copied so its diff is in the consumer's
  history (D12), `doctor --effective` (D5), `CHANGELOG` per tag.
- R3 ⇒ exit 2 as a first-class outcome and exit 3 for a crash (D8); `ROUND.DIR` absent = fail; DEAD
  lanes = 2; hash-bound verdicts; the adjudication channel refusing seeded ids; preflight aborting the
  skill.
- R4 ⇒ semver with measurement-affecting = MAJOR; `close` refusing a moved pin or config; `bump`
  refusing open rounds; dev rounds unclosable; the pinned tree re-hashed (D16, D2, D3).
- R5 ⇒ fixture at a path with a space, pinned `dev`, must-fail and absence arms, the Step-0
  equivalence test on the live trees — and, with R1, the tool as its own fifth consumer, subject to
  its own doctor, scans, gate and instruments (D15, D16; Revision 6).
- R6 ⇒ stubs not copies (D6), engines by absolute path (D7), harness as a package (D9), one sidecar (D13).
- R7 ⇒ one tag over JS + Julia + sh + markdown; JS receives only args (D5/D7).
- R8 ⇒ Pkg-fetched pinned copy, a shim that execs the docs environment's resolution, registered dev
  checkout, https URLs, no Dropbox
  dependency for a consumer (D2/D3).
- R9 ⇒ doctor-driven checklist, canary order, the 7-day fleet window started by `bump` (D4, D14, D17).
- R10 ⇒ `instruments/<name>/` as the contract; `gbg init`/`new`; catalogues as data (D7, D10).
- R11 ⇒ D11; `schema_version` on every artefact.
- R12 ⇒ anchors in config for domain hats and in the catalogue for engine lanes, the five
  never-economised phases in the engine (D18).
- Platform facts ⇒ no plugin channel; stubs with `!` injection and `allowed-tools`; the protocol injected
  rather than read; policy by relative import of a local copy; manuscripts inside the project (D6, D7,
  D10, D12).

**Where this document extends `04-decision-record.md` (recorded here so the record and the schema
agree):**

- *Config keys beyond the record's five variation points.* The record says everything else is a
  platform constant or a declared deviation; this design admits, in addition, package FACTS and values
  the record's "Keep as config" clause already allows: `package.*` incl. `rulebook_sections`,
  `[paths]`, every `[surfaces]` key incl. `references_heading`, `docs.doctest`,
  `docs.unexported_base_expected`, `docs.retired_claims`, `git.branch`, `docs_post`,
  `check-docs.lanes_extra`, the check-consistency roster keys (`profile`, `hats`, `core`,
  `seed_rounds`, `seed_catalog`, `design_docs_withheld`, `latex_source_globs`, `domain_hats`), the
  bug-hunt `territories`/`oracles`/`witness_env`, the audit `executable_claims`/`guard_symbols`/
  `invariants_section`, `cost.default`, `schema.finding_types_extra`,
  `[[scans.custom]]`. None of them is a rubric choice, a threshold, a tier (save the declared
  `argcov_policy`) or a vocabulary.
- *Gate granularity.* The record's `makedocs` runs "`gbg gate docs`"; here it is
  `gbg gate check-docs check-consistency` (the two docs instruments by name), before and after
  Documenter.
- *Two renderers, one machinery.* The record says config reaches Workflow scripts only as args
  rendered by `gbg preflight`; `gbg round pass open` also prints Workflow lines, rendered by the same
  `Preflight.jl` renderer — one renderer, two callers.
- *`ROUND.toml` fields.* The record's list plus `round` (the round id, so a `ROUND.toml` read outside
  its directory still names itself), `tool_tree_sha`, `seed_salt`, `base`, `lane_shas`,
  `reproductions_sha`, `closed_by`, `abandoned`, `roster[].not_applicable`, and `tool_rev`,
  `tool_tree_sha`, `config_sha` stamped on every `pass.toml`; §6.1 is the complete list.
- *Cost policy.* The never-economised phases are exactly the record's five; the `executing` audit
  lane, the free hunt lanes, the dismissal auditor and the severity re-check are engine-lane anchors in
  the catalogue, which is a different mechanism.
- *Doctor.* Read-only, as the record says; a `--deep` witness re-run prints a recommendation and
  writes nothing.
- *Delivery example.* The record's `rev = "v1.4.0"` / `"=1.4.0"` is an example value; the first
  release is `v1.0.0`.
- *The tool as its own consumer.* The record's four consumers are five: the tool repository carries a
  `.gbg/` at its root (pin `dev`), a Documenter site built through its own `makedocs` wrapper, tracked
  rounds, and a row in `fleet.toml`; the dev-round rule gains its clean-tag exception (Revision 6;
  D15, D16, §5.6).

**Residual judgment calls — all ruled by the owner on 2026-09-08 (the implementation plan's §A holds
the rulings; the standing principle behind them: every package organised as uniformly as possible, no
history carried):**

1–2. *Removed 2026-09-08 (IT amendment 16):* IT's branch and IT's bare `!!! note` are decisions about
the consumer, not the tool, which supports both through `git.branch` and `docs.admonition_titles`;
each is a separate owner ruling, never bundled with the adoption (§9). 3. SS bold
argument bullets — collapsed (0 bold / 80 plain measured). 4. CP `persistent_tasks = false` — dropped.
5. `.claude/settings.json` generated — yes, only with hooks. 6. `seed_rounds` default — true.
7. `[[scans.custom]]` admitted as config-declared triage-only regex scans — yes. 8. IT's `.claude/`
notes — cleaned out by IT's own pre-migration commit; `LEG.PILES` does not name them.
9. PF's untracked `.claude/doc-review-prev/` — discarded at PF-2, never imported; it is the closed round 6
of 2026-08-15, not a copy of the 2026-09-01 panel. 10. Pages for the tool's site — deployed as the
consumers' are, public by URL from a private repository. 11. No consumer carries a pre-tool round:
Step 0 runs on scratch imports; `.gbg/rounds/` starts empty everywhere; IT's live escalated and blocked
witnesses move to `test/regressions/{escalated,blocked}/`. 12. The commit trailer stays the versionless
one in every repository. 13. (2026-09-09) The Stop hook is fleet-wide; `hooks.work_queue` is gone.
14. Only open cross-package requests move to `.gbg/requests/`; concluded ones are deleted. 15. Every
`CLAUDE.md` follows one skeleton; live plans live in a tracked `docs/ROADMAP.md`, finished work is
deleted.

**Decided by the record, not open** (they appeared as questions in an earlier draft and are stated
in the implementation plan's working agreements): the Julia floor stays `1.11` with a 1.11 CI lane; the
name is `GBGCodingTools`; the CLI re-runs the executable claims at `gbg audit-changes bank`;
`.gbg/requests/` is a tracked pile; `UNCLEAR` is kept as a non-passing state verdict; the policy copy
lives at `.gbg/policy/` behind the explicit block (not `.claude/rules/`).

---

## §11 Honest limits (verbatim from the decision record, then the residues this design adds)

- Grader/graded separation holds for code and prompts, not for files a session can forge; the residue
  is transcript-visible, not gate-visible.
- ground_truth is on disk after bank; the seeded copy lives outside the repo; a hat that opens it
  leaves a Read in its transcript.
- Outside-project Workflow scriptPath is unverified until day 1.

Appended to the decision record on 2026-09-06 and reproduced verbatim: "The Workflow tool ACCEPTS a
`scriptPath` outside the project directory and passes `args` through unchanged (probe run
`wf_897eab77-64d`: script at `/tmp/.../scratchpad/design/probe/echo.js`, returned
`{"ok":true,"echoed":{"probe":"outside-project scriptPath","n":1}}`). The day-1 item for this becomes
a re-check, not an open question; the `.gbg/scratch` copy fallback stays documented but is not expected
to be needed." And: "`Pkg.test()` honours `[sources] url+rev` in `test/Project.toml` and leaves no
`test/Manifest.toml` (maintainer critic's experiment) — hence the Julia-free shim."

The second quoted fact stands and its conclusion was revised on 2026-09-08 (IT amendment 3): the shim
is no longer Julia-free — it execs `julia --project="<root>/docs"` — and that fact is exactly why it
targets the `docs/` environment, the one that always carries a manifest (D2).

**Day-1 verifications (the implementation plan's Phase 0 and 1.9; date, host, result):**

- **V1 — 2026-09-09, `Aiporetne`: FAILED as first stated, fallback adopted as the rule.** Three probes
  of `Workflow({scriptPath, args: {n}})` with the echo script: (i) `/tmp/gbg-probe/echo.js`, a fresh
  path outside the project — REFUSED before launch: "scriptPath must be a script path this tool
  returned, or a file you can already read (the working directory or a directory you have added)";
  (ii) the same script under the session scratchpad — accepted, returned `{"ok":true,"echoed":{"n":1}}`
  (run `wf_953a8a2f-378`), which is what the 2026-09-06 probe had measured; (iii) the `/tmp` path again
  after the session had `Read` the file — accepted, returned `{"ok":true,"echoed":{"n":2}}` (run
  `wf_7bdc504f-e46`). So the tool admits an
  outside-project script only when the session may already read it, and the pinned copy under
  `~/.julia/packages/` is neither readable-by-default nor to be `Read` (D6). D7 now names the
  in-project copy, `.gbg/scratch/<round>/workflow/`, as the mechanism; `preflight` and `pass open`
  write it. The first quoted fact above is thereby narrowed, not contradicted.
- **V2 — 2026-09-09, `Aiporetne`, in PF: PASSED, with a syntax correction.** A bare `!gbg probe` line
  is not expanded by the client at all: it reached the session as literal text. The documented form,
  an exclamation mark followed by the command in backticks, injected `PROBE OK` with no permission
  prompt (`allowed-tools: Bash(gbg *)`, zero permission denials), and `--fail` (exit 2) aborted the
  skill before its body: zero turns, empty result, the sentinel sentence never reached the model.
  `SKILL.md.tmpl` renders the backtick form since commit 2f7e009. Measured in print mode; the
  interactive client shares the preprocessor.
- **V3 — 2026-09-09, `Aiporetne`: PASSED on what it measures.** A copy of the fixture outside the tool
  repository, `[sources] GBGCodingTools = {url, rev = "v1.0.0-rc.1"}` and `[compat] "=1.0.0"` in
  `test/` and `docs/`: both environments instantiated and loaded the tool from one read-only depot tree
  (`~/.julia/packages/GBGCodingTools/TcNy0`), and `Pkg.test()` resolved the tool from the tag before
  running the fixture's suite. That suite then stopped in `TestHarness.gate()`, whose quick doctor
  refuses a prerelease pin outside the tool root (`PIN.CONFIG`, `PIN.SOURCES`) — the refusal D16
  specifies, not a Pkg failure; a released `vX.Y.Z` tag is what a consumer pins. The plan's throwaway
  `v0.0.1` tag was not created: the tool's `Project.toml` says `1.0.0` at every commit, so a `=0.0.1`
  compat could never resolve.
- **V4 — 2026-09-09, `Aiporetne`, PF and CP: PASSED.** One fine-grained PAT (`GBG fleet CI`, Contents
  read-only, all five repositories) in the secret `GBG_DEPS_TOKEN` of all four consumers; probe branches
  `probe/gbg-v4` in fresh clones of PF and CP with the tool pinned in `docs/Project.toml` and the
  snippet's `auth` and `run` steps; manual `workflow_dispatch` of both `docs.yml`s green, each log
  showing `Cloning git-repo …GBGCodingTools.jl.git` and `+ GBGCodingTools v1.0.0 …#v1.0.0-rc.1`
  (Documenter's `Deploying: ✘` is its refusal to deploy from a non-default branch). Branches deleted.
- **V5 — 2026-09-09, `Aiporetne`: PASSED.** Zero `python3` mentions in both V4 logs and in the tool's
  own `CI.yml` dispatch; zero python steps in `CI.yml`, `CI.yml.snippet` and `docs.yml.snippet`. That
  first CI dispatch failed on its test matrix for an unrelated reason recorded in the CHANGELOG: a fresh
  clone carries no manifest in the fixture's `test/` environment, so every witness errored on
  `using GBGFixture`; the suite resolves that environment once now.
- **V6 — 2026-09-09, `Aiporetne`: PASSED** (`Pkg.test()` green on 1.11 and 1.12); `Enteropia` still
  needs `juliaup add 1.11`.

**Residues this design states rather than closes** (each is transcript- or diff-visible, none
gate-visible):

- The seeded copy now lives INSIDE the project (`.gbg/scratch/<round>/`, gitignored), which is what
  keeps a Workflow agent's `Read` prompt-free; the second bullet above therefore reads "inside the
  project, gitignored" for this design, and its residue is unchanged — a hat that opens the copy, or
  that **diffs the seeded manuscript it was handed against `docs/build`**, leaves a `Read`/`Bash` in its
  transcript and nothing in the tally except, sometimes, a SUSPECT flag on the hats that did not.
- `GBG_ROUND` exported by hand outside a CLI invocation makes `gbg gate` ignore that round exactly as
  a CLI-run build would; the export is in the transcript, and CI never sets it.
- A working tree's gate can see an open round that was not committed; CI proves only the PUSHED
  state — a fix pass committed without its round is green on the runner and red on the next local
  `gbg gate`.
- The fleet window is checked only where `gbg fleet` and `gbg bump` run — the dev checkout — so a
  consumer left behind is found by the owner's next sweep, not by the consumer's own doctor; and a
  fix pass longer than the window fails `gbg fleet` until it closes, which is a report, not a block.
- A tag force-moved on GitHub is caught only through the manifest's `git-tree-sha1` disagreeing with
  the tree Pkg fetched (`PIN.TREESHA`/`PIN.SELF`) on the next instantiate; a machine that never
  re-instantiates keeps the old tree and stays green.
- The tool's own rounds (D15) grade a moving instrument: the corpus and the instrument share one
  tree, so a fix to `src/` inside a round at the tool root changes the instrument mid-round, which no
  other consumer can do. The round's `head..closed_head` range shows exactly that change, `gbg release`
  refuses while the round is open, and a round opened off a clean tag is abandon-only (D16) — which is
  why such a round opens at a prerelease tag `vX.Y.Z-rc.<n>` (D16's prerelease form) — a report and a
  refusal, not a gate on the instrument change itself.

---
## §12 Appendix — the identifier tables

Three tables the ledger, the catalogue and the doctor validate against. They are derived from the
real sources: PF `CLAUDE.md`'s rubric, style and verification headings (with IT's and SS's
additions), PF `.claude/commands/check-docs/{guards.sh,sentence_openers.py,field_docs.py,
link_uniformity.py,doi_crosscheck.py}`, PF `docs/make.jl`'s lints, IT
`.claude/commands/check-docs/abutting_spans.py`, IT `docs/make.jl`'s `lint_notation_variants` and
`lint_docstring_shape`, and IT `check-docs.md`'s deterministic-scan block.

### §12.A Rule ids (`policy/RULES.toml`)

Each id names one rule and lives in the `RULE.` namespace — `RULE.<FAMILY>.<NAME>`, the family
being the policy file's prefix — so a rule id can never collide with a doctor check id (the bare
prefixes of §7.3) or a scan id (`SCAN.`); the ledger's `scope = "policy"` entries and the scans'
`rule` column cite these. `policy/RULES.toml` records per id the file, the section, the one-line
statement below, a `sentinel` — the first sentence of the rule's paragraph in `policy/*.md`,
verbatim — which `LEG.SENTINELS` matches against a consumer's `CLAUDE.md`, and a `check`: what catches
the rule's next violation (`RULE.TEST.RULE_WITH_CHECK`), one or more of `scan:<id>`, `doctor:<id>`,
`test:<path>`, `harness:<binding>`, `panel` or `weakness`. "Source" is the
`CLAUDE.md` heading or bold lead the text comes from (PF unless marked).

| Id | File | Statement | Source |
|---|---|---|---|
| `RULE.DOC.TWO_TIER` | docs-rubric | A module docstring is a map (linked one-liners, no formulas); a function docstring is a home. | "Two-tier structure." |
| `RULE.DOC.HOME_ORDER` | docs-rubric | A function docstring is ordered: identity, when-to-use, arguments, one formula, citation, links, caveats, then `# References`, then `# Fields` last; internals, jargon and rationale are excluded. The tail order lives in this rule alone. | "Function docstring = home"; the owner's ruling 2026-09-10 |
| `RULE.DOC.LEADING_IDENTITY` | docs-rubric | Item (1) is a plain one-sentence identity — physical-meaning first, or estimand first (★ `rubric.leading_identity`). | "Physical-space meaning first"; SS "estimand first" |
| `RULE.DOC.ONE_HOME` | docs-rubric | One concept, one home: one docstring per operation on the bare binding; the `!` form owns the formula and is listed first; every other variant is a thin wrapper that `@ref`-links the home and carries no second formula. | "One concept, one home." |
| `RULE.DOC.VARIANT_PAIR` | docs-rubric | Across an `f`/`f!` or getter/setter pair the defining math appears once; the wrapper carries no display formula (the review unit is the variant set). | "The review unit is the operation's whole variant set" |
| `RULE.DOC.ARGS_FORM` | docs-rubric | Three or more arguments, or any keyword, use the bulleted form led by `The arguments are:`; fewer are bound in prose; never mixed; a thin wrapper and an internal `_` helper are exempt (threshold 3 is a constant). | shape rule (1) |
| `RULE.DOC.FIELDS` | docs-rubric | A type with named, user-readable fields documents them under `The fields are`, one bullet per field, every bullet a real field and every field a bullet. | shape rule (2); `field_docs.py` |
| `RULE.DOC.ADMONITION_TITLE` | docs-rubric | Every `!!!` block carries a custom descriptive title (★ `docs.admonition_titles`: always, or load-bearing only). | shape rule (3) |
| `RULE.DOC.STEER` | docs-rubric | Every `!` form with an allocating sibling carries the verbatim in-place steer sentence, naming its own destination argument. | shape rule (4) |
| `RULE.DOC.ALIASING_BULLET` | docs-rubric | An operation-specific aliasing statement lives in the `destination` bullet; the package-wide guarantee lives in the module docstring. | shape rule (5) |
| `RULE.DOC.INTERNAL_API` | docs-rubric | An `## Internal API` section splits into `### Types`/`### Functions` only when it holds both, comes last, and opens with the disclaimer sentence. | "An `## Internal API` section splits…"; `lint_api_page_structure` |
| `RULE.DOC.REF_ABUT` | docs-rubric | A `@ref` never abuts a second code span; the whole call is the link text. | "a `@ref` never abuts a second code span" |
| `RULE.DOC.API_GROUPING` | docs-rubric | API pages are math-grouped under hand-written headers via `@docs`; each object once; `f`/`f!` together, `!` first; no `@index`; no empty `@docs` block; every public operation on a public page. | "API pages are math-grouped." |
| `RULE.DOC.COVERAGE_BASES` | docs-rubric | A measure reduction documents every base it supports. | "Coverage." |
| `RULE.DOC.GRAMMAR` | docs-rubric | Every sentence has a subject and a verb; concise means few words, not missing verbs. | "Prose is grammatical." |
| `RULE.DOC.SENTENCE_OPENER` | docs-rubric | A sentence opens with a capitalized ordinary word, never a lowercase identifier or a formula; bullets, comments, headings and fenced code are exempt. | "A sentence opens with a capitalized ordinary word" |
| `RULE.DOC.VERIFIED` | docs-rubric | Every formula, normalization, adjoint relation and cross-scheme equivalence is verified by expansion against the code, never asserted. | "Correctness is verified, not asserted."; "Mathematical correctness is its own check" |
| `RULE.DOC.SELF_CONTAINED` | docs-rubric | A rationale doc reads top to bottom without another file: every symbol is bound in plain language at first use. | "`docs/ARCHITECTURE.md` is self-contained" |
| `RULE.DOC.TERMS_DEFINED` | docs-rubric | A term of art is defined in a clause or `@ref`-linked on first use; the acceptance test is the cold read. | doc-edit checklist (2); "Cold-reader opacity" |
| `RULE.DOC.CURRENT` | docs-rubric | No stale claim; a summary naming a subset of what the code provides is stale; retired phrasings are listed per package (`docs.retired_claims`). | doc-edit checklist (4); `lint_retired_claims` |
| `RULE.DOC.CLASS_SWEEP` | docs-rubric | A flagged instance is a sample of a class: sweep every surface for the class and fix all in one pass. | "A flagged instance is a sample of a class" |
| `RULE.DOC.BATTERY` | docs-rubric | "Check the docs" means the complete battery over every surface, never one check or one file. | "'Check the docs' = the complete battery" |
| `RULE.DOC.LITERATE` | docs-rubric | A Literate example is a rendered page: full-line `# ` comments are prose, their math is LaTeX, control-flow-internal comments use `##`. | "A Literate example … IS a rendered doc page" |
| `RULE.DOC.BUILD_VERIFY` | docs-rubric | A doc edit is verified by the full docs build exiting 0, never by a diff, a lint subset or a log grep. | "Verify a doc edit by BUILDING the page" |
| `RULE.DOC.TABLE_TOP_LEVEL` | docs-rubric | A Markdown table is top-level, never indented in a list item; no literal `\|` in a cell. | "Markdown tables must be top-level" |
| `RULE.DOC.ONE_NOTATION` | docs-rubric | One notation per concept and one concept per notation; a local use yields to a package-wide glyph. | "One notation per concept" |
| `RULE.DOC.COORD_FREE` | docs-rubric | Maps and pairings are stated intrinsically; matrix/flattening machinery is confined to the formalization doc. | "Prefer coordinate-free notation" |
| `RULE.DOC.LINKS` | docs-rubric | Cross-referencing is discriminating-minimalist: a target linked at most once per docstring; never the own binding, arguments or `Base`; a family is one destination unless members must be chosen between; sibling names in one list are all linked or all plain. | "Cross-referencing — discriminating-minimalist"; `link_uniformity.py` |
| `RULE.DOC.SIBLING_LINK` | docs-rubric | The first mention of a sibling GBG package in a page, rationale document, Literate example or docstring links to that package's documentation site; a later mention does not link that site again, though it may deep-link a page of it; a package never links its own name. | the owner's home-page review, 2026-09-09 |
| `RULE.DOC.NO_DEAD_REFS` | docs-rubric | A docstring or error message cites no `§` number, repo path or inaccessible source; it reads complete at the REPL. | "No dead references on the user-facing surface" |
| `RULE.DOC.AI_BANNER` | docs-rubric | Every AI-written page carries the one provenance banner verbatim (as `# ` comments in a Literate file); the home page never carries it. | `lint_ai_banner`; the home-page clause is the owner's ruling 2026-09-09 |
| `RULE.DOC.SHAPE` | docs-rubric | A docstring's longest paragraph ≤ 120 words and admonitions ≤ 3, on every docstring and every NEW page unit; no unit grows past its baseline, a baselined page unit held by the ratchet alone; `# Arguments` precedes any column-0 `!!!`; `# Fields` is last. | `lint_prose_shape`; IT `lint_docstring_shape` |
| `RULE.DOC.MODULE_MAP` | docs-rubric | A module docstring lists one linked one-liner per operation family and no formula. | "Module docstring = map"; IT deviation |
| `RULE.DOC.ARG_BULLET` | docs-rubric | An argument or field bullet names its argument in a plain code span, never a bold one. | `guards.sh` "argument bullet is not bolded"; SS deviation candidate |
| `RULE.DOC.SIGNATURE_MIRROR` | docs-rubric | A docstring signature mirrors the code's types; only the docstring wraps, to ≤ 88 columns with a hanging indent. | "A docstring signature mirrors the code's types" |
| `RULE.DOC.SIGNATURE_FIDELITY` | docs-rubric | The displayed signature set and the defined method table agree per exported binding (symmetric difference reported). | IT `signature_fidelity.jl` |
| `RULE.DOC.XLINK` | docs-rubric | A cross-module name is `@ref`-linked at its first mention, qualified so the link resolves. | IT `xlink.jl`; PF "cross-module @ref is qualified" |
| `RULE.DOC.ARGCOV` | docs-rubric | Every argument in a docstring signature, positional and keyword, is documented in its body; run from the signature. (★ `argcov_policy` chooses triage or gate.) | "Argument coverage (signature-driven)" |
| `RULE.DOC.REGISTER` | docs-rubric | A tunable is an option, setting or keyword argument — never a "knob" or "tweak". | "Neutral reference register" |
| `RULE.DOC.RETURNS` | docs-rubric | A type docstring leads with its constructor; a `-> Type` arrow or a `Returns x.` sentence states the result where the identity sentence does not. | IT "Documentation policy" (generic rules join) |
| `RULE.TEX.RENDERED_MATH` | latex-idiom | All math in docstrings and pages is rendered LaTeX in a double-backtick span or a `math` fence, never Unicode glyphs, single-backtick code or dollar signs; every code object is bound to its symbol on first mention. | "Math in docstrings and doc pages" |
| `RULE.TEX.CODE_IN_MATH` | latex-idiom | A code identifier never sits inside a math span; inside a formula it is `\texttt{…}`. | micro-rule (a) |
| `RULE.TEX.ONE_SPAN` | latex-idiom | A formula is one LaTeX span, never split across a math span and an adjacent code span. | micro-rule (b); IT `abutting_spans.py` |
| `RULE.TEX.INLINE_ONE_LINE` | latex-idiom | An inline math span stays on one source line (a list-leader continuation drops it out of math mode). | micro-rule (c); `lint_inline_math` |
| `RULE.TEX.NO_HSCROLL` | latex-idiom | No horizontal scroll: hand-wrap long signatures and display formulas with `aligned`/`gathered`. | micro-rule (d) |
| `RULE.TEX.CODE_SPAN_JULIA` | latex-idiom | A backtick span holds only well-formed Julia, never code-looking math. | micro-rule (d), last clause |
| `RULE.TEX.SPACING` | latex-idiom | Never manual `\;`/`\:`/`\,` around a relation or operator, `\!` before a `\bigl`, `\!\!` before a sum, or `\,` except before `\mathrm{d}`. | "Math spacing and command support" |
| `RULE.TEX.MATHBB` | latex-idiom | `\mathbb` only on `A`–`Z` or `k`; the indicator is `\mathbf{1}`. | same |
| `RULE.TEX.MATHBF` | latex-idiom | `\mathbf` is admitted only for the strings in `notation.mathbf_allowed` (★), plus `\mathbf{1}` in every package whatever that list holds; vectors follow `notation.vectors` (★). | same; IT `\mathbf` ban |
| `RULE.TEX.LEFTRIGHT` | latex-idiom | `\left`/`\right` are banned; size by hand with `\bigl`/`\Bigl`; sole exception `\left\{ … \right.`. | same; fleet-wide rule 2026-07-17 |
| `RULE.TEX.PARTIAL` | latex-idiom | A partial derivative is `\partial_{x_i}`; a bare-index `\partial_i` is banned. | "Notation"; `lint_notation_variants` |
| `RULE.TEX.IMAGINARY` | latex-idiom | The imaginary unit is upright `\mathrm{i}`; `i, j, k` are indices. | "Notation" |
| `RULE.TEX.FRAC_BRACED` | latex-idiom | Every fraction argument is braced (`\tfrac{1}{2}`, never `\tfrac12` or `\tfrac N2`). | `lint_notation_variants` (PF, IT) |
| `RULE.TEX.BOLDSYMBOL_BRACED` | latex-idiom | Every `\boldsymbol` argument is braced. | IT `lint_notation_variants` |
| `RULE.TEX.SWALLOWED_ESCAPE` | latex-idiom | Inside a Julia docstring every LaTeX backslash is doubled; a single-backslash `\a \b \e \f \n \r \t \v \0-7 \x \u \U` is swallowed by the parser. | `lint_swallowed_escapes` |
| `RULE.TEX.RENDERED_MARKUP` | latex-idiom | No emphasis marker survives into rendered prose (overlapping `*a **b***`). | `lint_rendered_markup` |
| `RULE.TEX.GREEK_AB` | latex-idiom | The accumulation scalars are Unicode `α`/`β` everywhere; the two named ASCII holdouts stay. | "Greek scalars" |
| `RULE.CIT.STYLE` | citations | In-text author–year: author-prominent → parenthesized year; ≤ 3 authors named, `First et al.` for four or more. | "Citations — one uniform style" |
| `RULE.CIT.FULL_INLINE` | citations | A docstring cites author–year in its prose and carries the full reference in a `# References` section after the home's prose and before any `# Fields`, verbatim-identical to the canonical entry (title and DOI compared). | same; `doi_crosscheck.py` (PF + IT) |
| `RULE.CIT.DOI` | citations | Every reference carries a clickable DOI (or an Open Library link for a book) on its title, identical in every copy. | same; `citations.require_doi` |
| `RULE.CIT.BLOCK_LIST` | citations | Two or more citations form a bullet list, one per line; a lone citation is `Reference: …`. | same; "crammed citation block" |
| `RULE.CIT.NO_INACCESSIBLE` | citations | Never cite an inaccessible source (`inspiration/`, an accompanying thesis, an appendix the reader cannot open) on any user-facing surface. | same; memory rule |
| `RULE.API.POSITIONAL` | docs-rubric | A result-affecting argument is positional; a performance hint or a builder's cost/accuracy tunable is a keyword; exceptions are recorded. | "Positional vs keyword arguments" |
| `RULE.TEST.GATE_VS_SURVEY` | testing-protocol | `Pkg.test()` is a gate; the exhaustive suite is a survey; a specific oracle and every completeness guard go in the gate. | "`Pkg.test()` is a GATE; `test/exhaustive/` is a SURVEY" |
| `RULE.TEST.ORACLE_INDEPENDENT` | testing-protocol | Every public value-returning operation is classified in the oracle registry; relational-only coverage is a finding. | "Oracle provenance is enforced" |
| `RULE.TEST.DEFINITION_OF_DONE` | testing-protocol | A feature is done when its correctness tests, performance test, four guiding docs, remaining docs, benchmarks (built AND run) and examples (run) are each verified. | "Definition of done" |
| `RULE.TEST.ALLOC_ZERO` | testing-protocol | Every in-place `!` operator is allocation-free and in the audit; a deliberate materializer gets a bounded guard; where a bound covers another's nondeterminism a configuration pins the true zero. | invariant 13 as a harness rule |
| `RULE.TEST.PASS_AUDIT` | testing-protocol | Every audited operation has a frozen per-array traffic row with a named holder for any gap. | decision 36 |
| `RULE.TEST.METHOD_PARITY` | testing-protocol | The public method set is frozen per generic and per module; any change moves a number. | "Method parity after codegen edits" |
| `RULE.TEST.MUTATION` | testing-protocol | A symmetric fixture cannot see an asymmetric defect; a self-referential assertion cannot see a shared defect; a stated convention must be falsifiable by its fixture. | "Mutation audit" |
| `RULE.TEST.BOTH_DIRECTIONS` | testing-protocol | Test the check in both directions; a check that cannot fail is not a check; a self-reported field is acceptable only when the missing case is the failing case. | "Test the check in BOTH directions" |
| `RULE.TEST.MISSING_IS_FAILING` | testing-protocol | The missing case is the failing case: derived denominators, absence arms, zero count = dead. | R3 throughout |
| `RULE.TEST.RULE_WITH_CHECK` | testing-protocol | A rule and its check land in the same commit; a stated rule without a check is a known weakness. | IT "Known weaknesses — self-guards" |
| `RULE.TEST.EXAMPLES_RUN` | testing-protocol | Shipped examples are executed after any public-surface change; nothing else runs them. | "The examples, RUN" |
| `RULE.TEST.COUNTS_REMEASURED` | testing-protocol | A count nothing asserts is re-measured, never cited; a drop is a finding. | "re-measure rather than cite" |
| `RULE.INST.CONSENT` | instruments | Unasked, run only `Pkg.test()`; every instrument, survey, benchmark and panel runs only on the user's request, in words or by slash. | "Consent gate" |
| `RULE.INST.FOUR_OBJECTS` | instruments | The four instruments audit different objects: changes, source prose, rendered prose, code. | "Four instruments" |
| `RULE.INST.WITNESS` | instruments | A static claim about code is a hypothesis; the only evidence is a program that fails; a fixed witness is promoted unchanged. | "`/bug-hunt` … one rule" |
| `RULE.INST.SELF_REPORT` | instruments | Self-reported closure is not closure; the act verifier sees the diff, the state verifier is blind; the demotion is mechanical. | "Self-reported closure is not closure." |
| `RULE.INST.AUDIT_AFTER_CODE` | instruments | A fix pass that changed code is audited before its round closes: always for a hunt, and for a check-docs round whose pass touched `src` or `ext`. | the owner's ruling 2026-09-09, on the rc.1 round, whose documentation pass changed three code behaviours unaudited |
| `RULE.INST.CLOSURE_LOOP` | instruments | The closure loop runs over the banked findings by id, never by re-running the battery; abandon is the only wholesale exit and names every open id. | "The closure loop is BUILD-ENFORCED" |
| `RULE.INST.CARRY` | instruments | A round may close by carrying a minor or nit finding into the next round of its instrument, on a severity re-rated by someone other than the lane that reported it; it is re-banked there after the lanes run, never rediscovered, and a final release requires the backlog to be draining and nothing carried three times. | the owner's ruling 2026-09-10 |
| `RULE.INST.AUDIT_DISPOSED` | instruments | An audit round is closed by disposing its concerns, never by correcting them inside it; a correction moves the tree, the staleness check refuses the close, and there is no re-bank, so the correction rides the next change set. | the abandoned `2026-09-09-audit-changes-01`, 2026-09-10 |
| `RULE.INST.FIX_FROM_LANES` | instruments | A fix pass is driven from the per-lane findings by id, never from the consolidated summary. | "a fix pass is driven from the banked per-hat reports" |
| `RULE.INST.SEEDS` | instruments | A seeded finding is never fixed in the corpus and never enters the ledger. | "The seeded calibration and the closure gate" |
| `RULE.INST.NO_TRUNCATION` | instruments | A scan's output is never truncated (`head`, `tail`, a limit); count first, then read all. | `guards.sh` header |
| `RULE.INST.FROZEN_MIDROUND` | instruments | An instrument is never changed mid-round; a change is its own commit and release. | "The instruments are FROZEN in-tree" |
| `RULE.INST.ECONOMY` | instruments | Economy lanes by default; the five never-economised phases; `strength = full` on explicit request. | "Cost modes" |
| `RULE.GIT.PUSH` | git-conventions | Commit ⇒ push, directly on the configured branch; no feature branches. | "Commit ⇒ push, on `master`." |
| `RULE.GIT.TRAILER` | git-conventions | Every commit ends with the versionless `Co-Authored-By: Anthropic Claude <noreply@anthropic.com>` trailer; never `[skip ci]`. | same |
| `RULE.GIT.CI_MANUAL` | git-conventions | CI is manual-only; the matrix runs locally before a commit; docs deploy on push. | "CI is manual-only" |
| `RULE.GIT.NO_SHIMS` | git-conventions | The API is not frozen; no backward-compatibility shims. | "Working agreements" |
| `RULE.GIT.BRANCH` | git-conventions | The working branch is `git.branch` (`master` by default; IT `main` until renamed). | D14 doctor |
| `RULE.GIT.MANIFEST_TRACKED` | git-conventions | Sub-environment manifests are gitignored; a tracked root manifest is a declared deviation. | IT deviation |
| `RULE.GIT.REQUESTS` | git-conventions | A cross-package request is a tracked file `.gbg/requests/to-<PKG>-<date>-<topic>.md` in the requester with a status paragraph on top; a concluded request is deleted, not kept. | D14 |

### §12.B Scan catalogue (`catalog/scans.toml`)

Columns: scan id · rule · tier (`hard` must be empty, `triage` printed in full, or the declared
`argcov_policy`) · surfaces (config keys; `docs` = `rationale + pages + literate`, `all` = `docs +
src + ext`) · runner, collapsed to `julia|html` (`julia` = a function under `src/Scans/`, or under
`Reflection` for the four reflection scans; `html` = the `SCAN.HTML_*` functions over the built site
through the `Gumbo` walker of `scan_html`) · source · fixture defect class in `defects.toml`. Every `#`-comment line in a `.jl`
surface is skipped by every scan (the house exemption); a `.jl` surface is read only inside `"""`
docstrings except by `SCAN.SWALLOWED_ESCAPE`, which is what that scan is for.

| Scan id | Rule | Tier | Surfaces | Runner | Source | Fixture class |
|---|---|---|---|---|---|---|
| `SCAN.TABLE_INDENTED` | `RULE.DOC.TABLE_TOP_LEVEL` | hard | rationale, pages | julia | PF `guards.sh` "indented markdown table"; IT | `indented-table` |
| `SCAN.REGISTER` | `RULE.DOC.REGISTER` | hard | all | julia | PF/IT `\b(knobs?\|tweaks?)\b` (quoted words and code spans ignored) | `knob` |
| `SCAN.PARTIAL_BARE` | `RULE.TEX.PARTIAL` | hard | all | julia | PF/IT `\\partial_[ijk]`; PF/IT `lint_notation_variants` | `bare-partial` |
| `SCAN.THIN_SPACE` | `RULE.TEX.SPACING` | hard | all | julia | PF/IT gratuitous `\,` (not before `\mathrm{d}` / `\mathrm d`) | `thin-space` |
| `SCAN.FRAC_UNBRACED` | `RULE.TEX.FRAC_BRACED` | hard | all | julia | IT's wider `\\[dt]?frac\s*[^{\s]` (catches `\tfrac N2`); PF's digit form is a subset | `frac-unbraced` |
| `SCAN.NEG_THIN_BIGL` | `RULE.TEX.SPACING` | hard | all | julia | PF `\!` before `\bigl`/`\Bigr` | `neg-thin-bigl` |
| `SCAN.NEG_THIN_DOUBLE` | `RULE.TEX.SPACING` | hard | all | julia | PF/IT `\!\!` | `neg-thin-double` |
| `SCAN.MATHBB_DIGIT` | `RULE.TEX.MATHBB` | hard | all | julia | PF/IT `\mathbb` on a digit | `mathbb-digit` |
| `SCAN.MATHBF` (admits `\mathbf{1}` in every package, RULE.TEX.MATHBF's standing exception, whatever `notation.mathbf_allowed` holds) | `RULE.TEX.MATHBF` | hard | all | julia | IT `\\mathbf` ban, restricted to strings outside `notation.mathbf_allowed` | `mathbf-banned` |
| `SCAN.BOLDSYMBOL_UNBRACED` | `RULE.TEX.BOLDSYMBOL_BRACED` | hard | all | julia | IT `\\boldsymbol(?!\{)` | `boldsymbol-unbraced` |
| `SCAN.LEFTRIGHT` | `RULE.TEX.LEFTRIGHT` | hard | all | julia | IT must-be-empty `\\(left\|right)(?![a-zA-Z])`, with `\left\{`/`\right.` (the system idiom) excluded by the pattern | `left-right` |
| `SCAN.REF_ABUT_CODE` | `RULE.DOC.REF_ABUT` | hard | src, rationale | julia | PF: a `@ref` link immediately followed by a backtick | `ref-abut` |
| `SCAN.FIELD_DOCS` | `RULE.DOC.FIELDS` | hard | src, ext | julia | PF `field_docs.py` (GHOST / UNDOC / NOLIST / STALE; `NO_FIELD_LIST` becomes ledger `scope = "scan"` entries; zero types matched ⇒ exit 2) | `ghost-field`, `undoc-field` |
| `SCAN.LINK_UNIFORMITY` | `RULE.DOC.LINKS` | hard | src | julia | PF `link_uniformity.py` (adjacent-run unit; operators and the own binding excluded; no exports parsed ⇒ exit 2) | `mixed-link-run` |
| `SCAN.SIBLING_LINK` | `RULE.DOC.SIBLING_LINK` | hard | all | julia | new (owner's home-page review 2026-09-09): per page, rationale document, Literate file or docstring, the FIRST mention of each sibling must sit inside `[`Name`](site)` and no LATER mention may link that site again, a deep link to a named page of it being a cross-reference and not a hit; names and sites from the shipped `fleet.toml` | `bare-sibling`, `linked-later-mention` |
| `SCAN.ARG_BULLET_BOLD` | `RULE.DOC.ARG_BULLET` | hard | src, ext | julia | PF: a list bullet opening with a bold backtick span (ledger `RULE.DOC.ARG_BULLET` silences it for SS if the owner so decides) | `bold-arg-bullet` |
| `SCAN.INLINE_MATH_SPLIT` | `RULE.TEX.INLINE_ONE_LINE` | hard | all | julia | PF/IT/SS `lint_inline_math` (fence- and docstring-aware; list-leader continuation inside an open double-backtick span) | `inline-math-split` |
| `SCAN.SWALLOWED_ESCAPE` | `RULE.TEX.SWALLOWED_ESCAPE` | hard | src, ext | julia | PF `lint_swallowed_escapes` `(?<!\\)\\[abefnrtv0-7xuU]` inside docstrings | `swallowed-escape` |
| `SCAN.RETIRED_CLAIMS` | `RULE.DOC.CURRENT` | hard | all | julia | PF `lint_retired_claims`; patterns from `docs.retired_claims` (whitespace-normalised over whole files, so a wrapped phrase is caught) | `retired-claim` (fixture config lists one) |
| `SCAN.API_PAGE_STRUCTURE` | `RULE.DOC.INTERNAL_API`, `RULE.DOC.API_GROUPING` | hard | pages (`docs/src/api/`) | julia | PF `lint_api_page_structure` (`## Internal API` last; no empty `@docs`) | `internal-api-not-last`, `empty-docs-block` |
| `SCAN.PROSE_SHAPE` | `RULE.DOC.SHAPE` | hard | src (docstrings), rationale, pages | julia | PF `lint_prose_shape` + IT `lint_docstring_shape`: caps 120 words / 3 admonitions on every docstring and every NEW page unit, a baselined page unit held by the ratchet alone; ratchet against `docs/prose_shape.csv` (units: docstring, page, section incl. numbered items and `**(x)**` findings); `# Arguments` before column-0 `!!!`, `# Fields` last; missing CSV = error | `paragraph-over-cap`, `fields-not-last` |
| `SCAN.AI_BANNER` | `RULE.DOC.AI_BANNER` | hard | rationale, literate, pages | julia | PF `lint_ai_banner`: present on every rationale page and Literate file, and verbatim-identical wherever it appears | `banner-drift` |
| — | — | — | — | — | the same scan also refuses the banner ON `docs/src/index.md` (the owner's ruling 2026-09-09) | `docs/src/index.md` clean twin |
| `SCAN.DOI_CROSSCHECK` | `RULE.CIT.FULL_INLINE`, `RULE.CIT.DOI` | hard | src vs `references_heading` (or the whole of `docs/ARCHITECTURE.md` when `"absent"`) | julia | PF `doi_crosscheck.py` (both directions; unused-reference info) ∪ IT `doi_crosscheck.py` (decoded DOI, title check, retired `[doi:…]` label refused, the `Phenomenology` leaf exempt by ledger) | `doi-missing` |
| `SCAN.HTML_RENDERED_MARKUP` | `RULE.TEX.RENDERED_MARKUP` | hard | `built_html` | html | PF `lint_rendered_markup` (article text with code/pre/math stripped; `*`/`__` survivors) | `emphasis-survives` |
| `SCAN.HTML_STRAY_MATH` | `RULE.TEX.RENDERED_MATH` | hard | `built_html` | html | new 2026-09-09: a rendered math span holding a backtick, a Markdown link or an admonition marker is prose Julia Markdown read as math (a double-backtick span IS math) | `stray-math` |
| `SCAN.HTML_DOCSTRING_ONCE` | `RULE.DOC.API_GROUPING` | hard | `built_html` | html | IT built-HTML question 1 (a docstring rendered on two pages) | `docstring-twice` |
| `SCAN.HTML_PUBLIC_HOME` | `RULE.DOC.API_GROUPING` | hard | `built_html` + `.gbg/scratch/public_surface.json` | html | PF built-HTML question 3 / IT question 2 (every derived public operation on a public page) | `unhomed-export` |
| `SCAN.HTML_BASE_LEAK` | `RULE.DOC.API_GROUPING` | hard | `built_html` | html | PF built-HTML questions 1–2 (`Base.` names in an internal section not in `docs.unexported_base_expected`; a name in both a public and an internal section) | `base-leak` |
| `SCAN.ARGCOV` | `RULE.DOC.ARGCOV` | ★ `argcov_policy` | src | julia | PF `argcov.jl` exemption classes ∪ IT identifier class + `arg = default`; a signature with a keyword in the fixture | `undocumented-last-positional` |
| `SCAN.ARGS_FORM` | `RULE.DOC.ARGS_FORM` | triage | src, ext | julia | new 2026-09-09: three or more arguments, or any keyword argument, must be bulleted under `The arguments are:`; fewer are bound in running prose and the two forms are never mixed | `wrong-args-form` |
| `SCAN.FORMULA_IN_BACKTICKS` | `RULE.TEX.RENDERED_MATH` | triage | all | julia | PF/IT: a single-backtick span holding one of the glyphs ≤ ≥ ≠ ∈ ∉ ∇ Δ ⟨ ⟩ ‖ √ × ⋅ (FP: real Julia operators) | `formula-backticks` |
| `SCAN.STRAY_TEX_DOLLAR` | `RULE.TEX.RENDERED_MATH` | triage | rationale, pages | julia | PF/IT `\$[^$]*[\\_^{}][^$]*\$` | `stray-dollar` |
| `SCAN.MANUAL_SPACING` | `RULE.TEX.SPACING` | triage | all | julia | PF/IT `\\[;:](?![a-zA-Z])` | `manual-spacing` |
| `SCAN.CODE_IN_MATH` | `RULE.TEX.CODE_IN_MATH` | triage | all | julia | IT's span-only filter (a bare multi-letter run inside a math span, `\texttt`/`\text`/`\mathrm` arguments removed first) | `code-in-math` |
| `SCAN.CITATION_CRAMMED` | `RULE.CIT.BLOCK_LIST` | triage | src | julia | PF/IT `References?:[^"]*;` | `crammed-citation` |
| `SCAN.DEAD_REF` | `RULE.DOC.NO_DEAD_REFS`, `RULE.CIT.NO_INACCESSIBLE` | triage | src | julia | PF/IT `§[0-9]`, `docs/(src\|ARCHITECTURE\|…)`, `inspiration/` in a docstring | `dead-section-ref` |
| `SCAN.SENTENCE_OPENER` | `RULE.DOC.SENTENCE_OPENER` | triage | all | julia | PF `sentence_openers.py` (computed sentence starts: after `. `, after a line ending a sentence, after a blank line; the link form; exemptions as the rule's; zero surfaces ⇒ exit 2) | `lowercase-opener` |
| `SCAN.SIGNATURE_WIDE` | `RULE.DOC.SIGNATURE_MIRROR` | triage | src | julia | PF/IT awk (docstring signature line > 88 columns, per-file `FNR`) | `wide-signature` |
| `SCAN.ABUTTING_SPANS` | `RULE.TEX.ONE_SPAN` | triage | src, rationale, pages | julia | IT `abutting_spans.py` (bare or linked code span beside a double-backtick span, either order) | `abutting-span` |
| `SCAN.SIGNATURE_FIDELITY` | `RULE.DOC.SIGNATURE_FIDELITY` | triage | src | julia | IT `signature_fidelity.jl` (displayed vs defined, accent-normalised spectral pairs) | `stale-keyword` |
| `SCAN.XLINK` | `RULE.DOC.XLINK` | triage | src | julia | IT `xlink.jl`, dry-run default (`apply = true` explicit) | `unlinked-cross-module` |
| `SCAN.DUPREF` | `RULE.DOC.LINKS` | triage | src | julia | IT `dupref.jl` (a target linked twice in one docstring) | `double-link` |
| `SCAN.CUSTOM.<id>` | (consumer's reason) | triage, fixed | as declared | julia | `[[scans.custom]]` — PF "spectral field", IT `uh\|phih\|velocity\|vorticity`, SS `\\quad.*\\quad` | none required |

**Completeness guard.** `gbg selftest` fails when a scan function under `src/Scans/` is not registered in
`catalog/scans.toml`, when a registered `hard` or `triage` scan has no fixture pair in
`defects.toml` (a must-hit and a clean twin), or when a scan reports zero surfaces scanned on the
fixture (the dead-lane exit 2, `SCAN.SENTENCE_OPENER`/`SCAN.FIELD_DOCS`/`SCAN.LINK_UNIFORMITY`
already carry it and every scan inherits it from the engine).

### §12.C Doctor ids

The doctor's ids are the table in §7.3, which is the final list; the implementation plan cites those
ids and defines none of its own. The `QUICK` set, the non-exemptable set and the `--deep` set are
stated there once. The id families are disjoint by construction: a rule id starts with `RULE.`, a
scan id with `SCAN.`, a doctor check id with one of the bare prefixes of §7.3 (`ENV`, `SHIM`, `PIN`,
`CFG`, `EXEMPT`, `WIRE`, `MANAGED`, `LEG`, `POL`, `GIT`, `ROUND`, `AUDIT`, `LOAD`, `BUILD`, `TEST`,
`WITNESSES`, `SELF`), a finding id contains `/` and `#`, and a harness op is a bare symbol. The ledger
resolves an id by that prefix and nowhere else — `GIT.BRANCH` is only ever the doctor check and
`RULE.GIT.BRANCH` only ever the rule — so every id has exactly one meaning.

---

## Revision history

The per-revision notes of this document, appended in order; the append-only history the
`history_exempt` anchor of §5.6 names, exempt from the currency scans.

### Revision 2 (2026-09-07)

Applied from `out/REVIEW-dryrun.md`: items 1–57 (1–5 BLOCKER, 6–23 MAJOR, 24–47 MINOR, 48–57
deviations), each as ruled by `05-fix-rulings.md` where a ruling overrides the review's own fix
(the rows `out/FIXLOG.md` marks "Applied (ruling N)" — the one list, not restated here). Applied from `out/REVIEW-attack.md`: 1.4, 1.5,
1.6 (as ruling 14's SUSPECT flag), 1.7, 2.1–2.7, 3.1, 3.3 (as ruling 14's salted selection), 3.4,
3.5, 4.1–4.3, 5.1–5.3, 6.2–6.7, 7.1 (superseded by ruling 17's constants), 7.2, 7.5, 7.6, 8.1–8.5,
9.1–9.6, 10.1 (as ruling 18), 10.2, 10.3, the vocabulary unification (`candidates_found`) and the two
"not configurable" contradictions plus the anchor ambiguity. Rulings 1–22 applied in full; the
per-item mapping is `out/FIXLOG.md`.

### Revision 3 (2026-09-07)

Applied from `out/REVIEW-verify.md`, every item: the PARTIAL ruling (R20 — `round` added to §10's
`ROUND.toml` extension list, so §6.1 and §10 agree); the nine consistency mismatches (4.1 — every
rule id moved into the `RULE.` namespace, §12.A/§12.C rewritten and every citation updated, so a
rule id and a doctor id cannot collide; 4.2 — one exemptable set, `AUDIT.*` included, stated
identically in D14 and §7.2; 4.3 — as R20; 4.4 — `gbg probe` in the verb table; 4.5 — `gbg round
compare` given its one meaning, D4's cross-version comparison renamed `gbg fleet --diff`; 4.6 — the
`regrade` alias deleted, `pass open --regrade` everywhere; 4.7 — the `gbg fleet` row vocabulary
(`OK`/`NOT-INITIALISED`/`BEHIND`/`RED`) and exit contract defined in D4; 4.8 — both revision footers
cite FIXLOG's marks instead of three disagreeing lists; 4.9 — FIXLOG's two counts corrected to 91 and
39 + custom); and the residual blockers 5.1–5.14 (Phase 1.9 for V2–V6; the dev-checkout invocation as
Phase 2's (respelled by Revision 4); `round import` into `.gbg/rounds/` with `import.json`, `recorded.toml` and
`--empty` defined in §8 and §6.1; PF-0 `init` before PF-1 `sync`; `gbg migrate baselines`; Phase 5.1
under `--dev` at the tag; the CP delta as §5.4, the former §5.4 now §5.5; Q13; `LEG.SENTINELS` reads
`RULES.toml`'s `sentinel`; the fleet output contract; `gbg config --toml` parsed by the stdlib `TOML`;
the CI-snippet insertion points in §3 and `WIRE.CI_AUTH`). The per-item mapping is `out/FIXLOG.md`
"Revision 3".

### Revision 4 (2026-09-08) — IT amendments + Python retirement

Applied from `07-IT-amendments.md`, every amendment by number, with `06-python-retirement.md`'s mapping
where the two agree and the amendment where they differ: **(1)** D19 records `GBGInstruments` proposed
and declined; **(2)** D1 two faces, D8 retitled to one Julia CLI with `main(ARGS)::Int` and exceptions
→ 3, §3 `gbg/` → `src/CLI/*.jl`, `scans/` → `src/Scans/*.jl`, `tree.py` → `src/TreeHash.jl` on `SHA`,
§12.B's runner column collapsed to `julia|html`; **(3)** D2 item 3 — the shim execs
`julia --startup-file=no --project="<root>/docs"` and scans no depot slug, "not instantiated" → 2, the
bootstrap and `install.sh` respelled, D3/§7.3 `PIN.TREESHA`/`PIN.SELF` on `Pkg.dependencies()` with
`is_tracking_repo && !is_tracking_path`; **(4)** D6 states where the Julia start is paid, D13 renders
`.claude/hooks/queue-guard.sh` as a managed `sh` file and deletes `gbg hook queue-guard` (its
round-grepping body retracted by Revision 5: the body is PF's script verbatim), D9/§6.2/§7.3
replace `run_gate` with in-process calls and remove `PYTHONDONTWRITEBYTECODE`, `ENV.PYTHON` and the
`python3 --version` CI step (`WIRE.CI_AUTH`, §3 templates); **(5)** D5 one validator in Julia
(`Schema.jl`, no JSONSchema.jl), `Config.read()` in-process, D9 deps gain `JSON3`; **(6)** D8/§3
`consolidate.py` as the one transitional file inside the tool, Gumbo + AbstractTrees walker, byte
comparison as the acceptance test; **(7)** D7 unchanged; **(8)** D10 names `.gbg/rounds/` the sole
closure record and retires IT's register, marker and both `lint_review_closure`s, §6.2 step 10 states
`ROUND.DIR` as the closing of the vacuous-pass hole, `hooks.work_queue` off by default with the `sh`
body; **(9)** §7.2/D14/`CFG.EXEMPTIONS` gain `[exemption.match]`, §7.3 gains `EXEMPT.BROAD` (WARN);
**(10)** §7.3 gains `CFG.TORN` (`QUICK`, non-exemptable — its `QUICK` membership retracted by
Revision 5), §6.2 step 2 and every round verb run it;
**(11)** D9 names the docs build the per-push, harness-independent enforcement point; **(12)** §6.3
gains the adoption precondition; **(13)** `LEG.SENTINELS` softened — exact match FAIL, twelve-word run
WARN, quotes and fences ignored; **(14)** §3/§4/§5/§6.4/`CFG.SEEDS`/D16 move the seed catalogues to the
consumer's `.gbg/seeds.toml` (class C), `catalog/seeds/fixture.toml` alone staying; **(15)** D17
carries the effort floor; **(16)** §9's two rows and §10's residuals 1–2 reclassified as consumer
rulings; **(17)** the `git add -u` line is in the implementation plan §B. Deliberate survivors of the
Python grep: the `consolidate.py` transitional mentions and the historical citations of the old
scripts as the sources of a port. The per-item mapping is `out/FIXLOG.md` "Revision 4".

### Revision 5 (2026-09-08) — IT corrections A–D

Applied from `08-IT-corrections.md`, exactly the four corrections and nothing else; (A) and (B) retract
parts of Revision 4's (4b) and (10). **(A)** D13, §4, §5.1, §6.2 step 10, §9, the Revision 4 note: the
rendered `.claude/hooks/queue-guard.sh` is PF's existing script **verbatim** — it guards the `- [ ]`
items of `.claude/WORK_QUEUE.md`, keeps the `stop_hook_active` loop guard, never reads `.gbg/rounds/`
and never starts Julia (the round-grepping body of (4b) is gone: a round spans a fix pass, so that hook
would have blocked every turn end during one and deleted PF's guard); it stays a generated-managed `sh`
file rendered by `gbg sync` under `hooks.work_queue = true`; D13 states once that the hook guards the
work queue, the gate guards the rounds, and the two never overlap; D10's (8b) sentence now says the
tool never reads `WORK_QUEUE.md` for *closure* while the hook may read it. **(B)** D9, §6.2 step 2,
§7.3 (the `QUICK` set and the row), §8 arms, the Revision 4 note: `CFG.TORN` is **not in `QUICK`** — it
is exit 2 in `gbg preflight` and in every `gbg round` verb only, so the `makedocs` wrapper and
`TestHarness.gate()` never run it; its "fails to parse" clause is dropped (that is `CFG.VALID`); it
stays non-exemptable. **(C)** D9's dependency bullet and `makedocs` bullet, the §3 tree (`ext/` added,
`DocLints.jl` and the module line reworded): `Documenter` is a `[weakdeps]` entry with
`[extensions] GBGCodingToolsDocumenterExt = "Documenter"` and `ext/GBGCodingToolsDocumenterExt.jl`,
the main module declaring `function makedocs end` and the extension defining
`GBGCodingTools.makedocs(cfg; kwargs...)`; the compat bound is kept; `Gumbo` and `JSON3` stay hard
dependencies; `WIRE.MAKEDOCS` is unchanged. **(D)** §7.2 (the third example replaced: `id =
"SCAN.ARGCOV"`, `scope = "scan"`, `target = "src/Interpolation.jl"`, `[exemption.match]` with
`arg_name`, `arg_type = "Integer"`, `symbol = "^(LalescuSpline|LagrangeSpline)$"` — the old example put
a scan id in `target`, which the header reserves for a symbol, a file or a finding id, and typed the
argument with the scheme type rather than the matched argument's own), the paragraph after it, D14, the
`CFG.EXEMPTIONS` and `EXEMPT.BROAD` rows, §8 arms: `arg_type` is the declared type of the **matched
argument**, tested by `<:`, evaluable by the reflection scans only, and a text scan **refuses** an entry
carrying it (exit 2 at `CFG.EXEMPTIONS`), never ignores it; `symbol` is a regex over the owning
binding's name; every engine with a trigger population, `Reflection.argcov` included, applies the
predicate itself and reports the population, or `EXEMPT.BROAD` has nothing to dry-run. §12 lists no
match keys and is untouched. The Revision 4 note keeps its wording with the two retractions marked
inline. The per-item mapping is `out/FIXLOG.md` "Revision 5".

### Revision 6 (2026-09-09) — the tool as its own consumer

Applied from `09-revision6-self-application.md`, exactly the eight rulings and nothing else. **(1)** D15
(retitled) makes the tool its own FIFTH consumer — `.gbg/config.toml` at the tool root with
`[tool] version = "dev"` (the dev pin's legality extended from the fixture to the root), `[package]
name = "GBGCodingTools"`, the surfaces, all four instruments, `seed_rounds = false`, the one domain hat
`tooling-maintainer`, the ledger, hats, rendered policy and tracked rounds; §5.6 is its config delta;
D4 gives the fleet its fifth row (`path = "."`, `dev+<sha>[-dirty]`, `OK`/`RED` by its own doctor, never
`BEHIND`); D16 extends the dev-round rule — a round opened at a clean released tag is a normal closable
round, with `tool_tree_sha` read from the tag; D10, D14, D17 and the head paragraph name the tool root
wherever "a consumer" is said. **(2)** D9 gains the tool's own Documenter site: `docs/Project.toml` with
`[sources] path = ".."`, `docs/make.jl` through the same mandatory wrapper (`WIRE.MAKEDOCS` applies to the
tool), the page list, `docs.yml` on push to `master`, private Pages as an owner action; §3's tree gains
`docs/{ARCHITECTURE.md,Project.toml,make.jl,prose_shape.csv,src/…}`, `.gbg/`, the stubs, `CLAUDE.md`,
`docs.yml`, `test/regressions/`, and `ci.yml` is spelled `CI.yml` as `WIRE.CI_AUTH` names it. **(3)** D9
and D12: every public binding carries a rubric docstring, module docstrings are maps, `checkdocs =
:exports` and `doctest = true` in the tool's `makedocs` call; the tool's `CLAUDE.md` carries the managed
block plus the design sentence, the freeze rule and the release checklist. **(4)** D15 lists the four
checks the tool passes on itself; D16 and §8 carry the release preconditions (`Pkg.test()`, the docs
build, `gbg doctor --deep`, no open round, the CHANGELOG entry, the tag absent); D9 and D15 state the
CI matrix (1.11 and 1.12 × `Pkg.test()` AND the docs build, no consumer checked out). **(5)** D6 and D15:
the stubs rendered into the tool's own `.claude/skills/`, its rounds under its `.gbg/rounds/`; §8 says
"the tool's own docs build green" is a release precondition, not a selftest arm. **(6)** D2 states the
bootstrap circularity once — the docs environment loads the working tree by path, the shim execs
`julia --project=docs` at the tool root like anywhere else, `PIN.*` accept `dev` there and stamp
`dev+<sha>[-dirty]` (the tag itself for a clean-tag round). **(7)** §7.3 gains `SELF.CONSUMER` (in
`QUICK`, non-exemptable) and `SELF.DOCS` (`--deep`); D14 and §7.2 add `SELF.*` to the one non-exemptable
set; §12.C adds the `SELF` prefix; `PIN.CONFIG`, `PIN.SOURCES` and `ROUND.DEV` are reworded for the root.
**(8)** is the implementation plan's. §4 states that the tool's own footprint is the same set as a
consumer's; §10 and §11 record the extension of the record and the residue it leaves (a round on the tool
grades a moving instrument). D19 and §0 are untouched. The per-item mapping is `out/FIXLOG.md`
"Revision 6".

### Revision 7 (2026-09-09) — the prerelease tag

One ruling, replacing the collision resolution Revision 6 wrote (the tool's first `/check-docs` round
"recorded by `abandon` listing no open id"): the tool's own instrument rounds before a release are opened
at a PRERELEASE TAG. D16 gains the prerelease form — `gbg release <ver>-rc.<n>` (tags `v1.0.0-rc.1`, …)
runs the same refusals except the open-round refusal and the closed-`/check-docs`-round precondition; a
round opened at the tool root with a clean tree at an rc tag is a normal closable round stamped with the
rc tag (the extension now says "a released tag — a prerelease included"); the final `gbg release 1.0.0`
requires that round closed through any of the five closure channels, never abandon, and refuses any open round.
Semver: an rc tag is never a consumer pin — `PIN.CONFIG` accepts only `vX.Y.Z` and `PIN.SOURCES` refuses
a `-rc.` rev in any consumer other than the tool itself (§7.3, both rows reworded; `ROUND.DEV` names the
rc tag). D15 and §8 say the first round is opened at `v1.0.0-rc.1` and closed; §8's selftest arms gain
the rc-tag round that closes; §11's residue names the prerelease tag as the reason. No "abandon listing
none" sentence survives in this document. The per-item mapping is `out/FIXLOG.md` "Revision 7".

### Revision 8 (2026-09-08) — the owner's rulings

Applied by the implementing session from the owner's answers to the implementation plan's §A, given
one by one before Phase 0 (that document's Revision 8 note lists the plan side). The standing principle
the owner stated: every package organised as uniformly as possible, and no history carried. On this
document: D17 states the principle as the migration rule (same footprint, `.gbg/rounds/` empty, piles
deleted not imported, old adjudications not carried, settled notes deleted not moved, only live
artefacts rehomed); D15, D10, §6.1 and §8 make Step 0's imports SCRATCH — graded, compared, deleted,
with the comparison table in the tool's `CHANGELOG.md` the one artefact — and §8 names PF's
`doc-review-prev` for what it is (the closed round 6 of 2026-08-15, no verdict files, discarded); §4,
§6.7 and §7.3 give the carried live witnesses their home, `test/regressions/{escalated,blocked}/`, which
`WITNESSES.ESCALATED` and `WITNESSES.BLOCKED` also run over; §7.2 says the pre-tool adjudication lists
are not carried; D9 records Q14 as ruled — the tool's site deployed as the consumers' are, public by
URL from a private repository (owner-only Pages being unavailable on the account); §9 turns the three
owner rows into collapses (SS bullets measured 0 bold / 80 plain; CP's flag dropped; `settings.json`
managed with hooks) and adds the pre-tool-piles and IT-notes rows; §10's residual calls are marked
ruled, with the four new ones (Pages, no old rounds, the witnesses' home, the versionless trailer).
Nothing in §0–§2's requirements, D1–D16, D18–D19, §5, §6.2–§6.6, §11 or §12 changes.

**Added 2026-09-09, PF's leftovers ruled** (same revision): **the Stop hook is fleet-wide** — D13
renders `queue-guard.sh` and `settings.json` in every consumer and seeds `WORK_QUEUE.md` (class S,
`templates/WORK_QUEUE.md.seed`); the config key `hooks.work_queue` is removed from §1's variation table
and from §5.1, §5.2, §5.4 and §5.6; D10 and §6.2 step 10 say "every consumer"; §3's template list and
§4's footprint gain the two files. **Requests**: D14, §4 and `RULE.GIT.REQUESTS` keep only open requests
in `.gbg/requests/`; a concluded one is deleted. **`CLAUDE.md` skeleton**: D12 defines the one section
order (`templates/CLAUDE.md.skeleton`) and the tracked `docs/ROADMAP.md` for live plans, §4 lists both;
§9 gains the two rows and reclassifies the hook and `settings.json` rows as collapses; §10 gains
residuals 13–15.

### Revision 9 (2026-09-09) — payloads are files, args carry paths

Found at implementation of the preflight (Phase 1): the `workflow-authoring` reference states that a
Workflow script has no filesystem or Node API and that `args` is the value the session passes in the
tool call — the session re-emits the printed call verbatim. A `/check-consistency` manuscript is
0.4–1.1 MB (PF and IT, measured at the 1.6 acceptance), an `/audit-changes` diff is unbounded, a hat's
persona is a kilobyte; none can travel inside `args`, and a printed call the session must retype has
to stay in the low kilobytes. D7 and §6.2 step 4 now state the rule: preflight writes every payload —
manuscripts, rulebook and rulebook sections, personas, lane briefs, the diff, diffstat and claims, the
findings' unabridged text for the verifiers, the dismissal and severity items, the design under attack
— under `.gbg/scratch/<round>/workflow/payload/` (gitignored, inside the project), `args` carries
their paths and small scalars only, and every agent prompt lists the exact paths it may `Read` under
`.gbg/`; everything else under `.gbg/` and all of `~/.gbg/` stay forbidden. The eleven scripts and the
four `instruments/<name>/schema.json` args objects carry the new keys (`persona_path`, `brief_path`,
`policy_path`, `rulebook_path`, `findings_path`, `items_path`, `diff_path`, `diffstat_path`,
`claims_path`, `invariants_path`, `design_path`, `personas_path`, `defect_path`, `substrate_path`;
`manuscripts.{full,siteonly}` are paths). The seed-secrecy argument of §6.4 is unchanged: the payload
directory holds the seeded copies alone until bank writes the ground truth. §11 gains this as the
second platform residue beside V1; nothing in the vocabularies, the round contract's files or the
closure channels changes.

### Revision 10 (2026-09-09) — the rc.1 `/check-docs` round

The first round over the tool's own docs (opened at `v1.0.0-rc.1`, 22 banked findings) amended this
record in place: D1, D8 and the §3 tree now state the consolidator port in the past tense (the Python
was deleted on 2026-09-09 when the byte comparison passed); D9's dependency list names `Pkg` and
`Random`; the §12 rule and scan tables no longer nest a backtick inside a double-backtick span (Julia
Markdown renders such a span as math, and the built page carried the raw source). Nothing in the
vocabularies, the round contract or the closure channels changes.

The round also found three defects in the code the docstrings described (`TreeHash.tree_hash` never omitted an empty directory; the rescan
needle was cut in bytes; a witness that both failed and errored was filed `:blocked`) — each fixed with
its test in the same pass.

### Revision 11 (2026-09-09) — the owner's home-page review

Two rulings from the owner's first read of the built site. The home page defines tool, consumer and pin
before it states the principle that uses them, and its AI banner is gone: the owner reviews that page
regularly in EVERY package, which the rule now states fleet-wide; `RULE.DOC.AI_BANNER` otherwise binds rationale pages and Literate examples, not a page a human
keeps. And sibling packages are always links: `RULE.DOC.SIBLING_LINK` with the hard `SCAN.SIBLING_LINK`
(§12), one uniform target per package derived from the shipped `fleet.toml`, enforced in every consumer
and in the tool. A MINOR change; the fixture gains the `bare-sibling` class. The owner also ruled the
noun "pin" out of reader-facing text: every page, docstring, message and template says "pinned
version" (or "pinned at `dev`"); the `PIN.*` check ids and this record's vocabulary keep the word.

### Revision 12 (2026-09-09) — a documentation round that changed code is audited

`RULE.INST.AUDIT_AFTER_CODE`, with its refusal in `Passes.close`. The hunt's close has always required a
closed `/audit-changes` round based at its opening head; a `/check-docs` round now does too, whenever its
fix pass touched the `src` or `ext` surfaces. The rc.1 round is the evidence: a documentation round
changed three code behaviours (`TreeHash.tree_hash`, the rescan needle, the witness classification) and
nothing asked whether those edits were proportionate or whether behaviour moved for input that worked
before. The two verifiers answer a different question, per finding and from the finding's own text; the
audit reads the diff whole and runs what the diff claims. A prose-only pass stays ungated, the audit's
prose lenses run on judgment. MINOR; the closed vocabularies and the closure channels are unchanged.

### Revision 13 (2026-09-09) — the scan the rc.1 round was owed, and where a deferral goes

`SCAN.HTML_STRAY_MATH`: a rendered math span holding a backtick, a Markdown link or an admonition marker
is a hard finding. A double-backtick span is math in Julia Markdown, so prose that quotes backticked
syntax inside one is handed to KaTeX, which cannot parse a backtick and leaves the raw source on the
page. The rc.1 round found the class by reading the build, could not add a scan mid-round, and the
deferral was written to `docs/ROADMAP.md`, which nothing reads; the class then shipped three times on the
generated rules page. Two changes, not one: the scan exists, and `RULE.INST.FROZEN_MIDROUND` now says a
deferral is one line in the round's `deferred.md`, which `gbg round close` carries into
`.claude/WORK_QUEUE.md`, where the Stop hook holds the next session to it. A note is not a mechanism.
MINOR; the closed vocabularies are unchanged.

### Revision 14 (2026-09-09) — the optional data surface

`surfaces.data`, empty in every consumer and on in the tool. The scan surfaces were derived from four
numerical packages, where a package's meaning lives in docstrings and rendered mathematics. Most of this
package is neither: catalogues, schemas, templates, the rulebook and eleven fan-out scripts, whose
comment prose no scan had ever read. The surface is a list of globs like any other; what is new is the
reader. `surface_kind` returns `:hashcomment` (TOML, YAML, `sh`, a template), `:slashcomment`
(JavaScript) or `:jsondoc` (JSON, which has no comment syntax, so its prose is the value of every
`description` string), and `data_prose_lines` walks them. Only a FULL-LINE comment is prose, so a
pattern inside a value is never a hit. `SCAN.REGISTER`, `SCAN.RETIRED_CLAIMS` and `SCAN.SENTENCE_OPENER`
read the surface where a package declares one; the fixture gains the `data-knob` class and its clean
twin. The compound key `all` deliberately does NOT include `data`: a scan reads it only by naming it, so
no existing scan changed meaning. Here the surface is 79 files and 319 prose lines that nothing had ever
examined. MINOR: a new optional key, no vocabulary changed, every consumer unaffected until it opts in.

