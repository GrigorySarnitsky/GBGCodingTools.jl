<!-- gbg:managed begin vdev — rewritten by `gbg sync`; do not edit -->
@.gbg/policy/00-index.md

The rulebook above is the whole of it: the rules, the terms they use, and what GBGCodingTools has
switched off with its reason. Nothing restates a rule outside it — a rule quoted in two files is a
rule that will be reworded in one.

Unasked, run `Pkg.test()` and nothing else; before every push the docs build runs too, through the
push hook, and a failing build stops the push. What a rule finds is reported, never fixed silently:
documentation may be fixed without asking, and anything else waits for an answer.

The readers of a review are derived from the rules and the tool's catalogue of disciplines. A
reader or a discipline this package needs and the tool lacks is requested of the tool, as a request
file the owner has approved, never written here.

A run an earlier session left open is continued before anything else, and the chat says so:
`gbg run next` says what to launch or that the stage is ready to collect, and the run goes on to
its close. It waits for the owner only when `gbg run next` says the tree moved since the launch.

A version is released on the owner's word, with `gbg release <version>` run here, and no other way:
it refuses unless the tree is clean and pushed, `CHANGELOG.md` has a `## <version> — <date>` entry,
`Project.toml` names that version, the tests, the docs build and the wiring check pass, and CI
passed at the commit — start it first with `gh workflow run CI --ref <branch>` — then tags and
pushes, and records a final release in the fleet's registry (`gbg release --register` records one
whose recording failed). A tag is never moved or cut again.
<!-- gbg:managed end -->

# CLAUDE.md — GBGCodingTools

You are in the dev checkout of `GBGCodingTools.jl`, the one shared tooling package of the four GBG Julia
packages and of itself. **It is being rebuilt.** `docs/ARCHITECTURE.md` is the design it is being built
to — normative, adopted by the owner on 2026-09-17 — and `IMPLEMENTATION.md` is the order of the work,
phase by phase, each with the gate it must pass. What the package was before, and the machinery deleted
from it, are in git's history: the design record left the tree on 2026-10-05, read by nothing.
The managed block above imports the shared policy; this file holds only what is the tool's own.

## Where the rebuild stands

**Phases 0–5 and 9 of `IMPLEMENTATION.md` are BUILT.** The version is the latest tag, and the first
entry of `CHANGELOG.md` says what it holds; this file names neither, nor any count a program keeps, so
it cannot go stale with a release. Three science packages are wired and on the rulebook: PF
(2026-09-18), HT (2026-09-30) and SS (2026-10-03, by its own session); CP is Phase 7's, with its wiring
still to rehearse. Which version each pins is in its own `docs/Project.toml`. The `v2.0.0` tag waits on the
owner's word. Deferred on his word: Phase 6 (the bug hunt, the code fixer, the change audit), Phase 10
(the code review) and Phase 11 (the design review). Phase 8, the tool as its own fifth consumer, is
next after CP.

The new tree stands whole: `Model`, `Texts`, `Catalogue`, `ConfigIO`, `Engine` (`Checks`, `Guard`,
`Harness`), `Render`, `Study`, `Publication` and `Orchestration` (`Runs`, `Site`, `Scope`, `Agents`),
with `Wire`, `Check`, `Docfix`, `Run`, `Answer`, `Leak`, `StudyCmd` and `Release` above them. The
documentation review has run over real agents in PF (2026-09-22 and -24) and HT (2026-10-04): `gbg run`
opens it, builds the site, launches the readers through the one driver, collects, fixes through the
guard, verifies blind and then with the diff, and closes with a report and the owner's work queue.
`--scope changed` reads only what moved since the last run like it. The leak scan (`gbg leak`) reads a
repository's whole history and, on `--github`, its GitHub side; what a package has accepted is its
own `.gbg/leak-accepted.txt`.

Every rule is a `Rule` value under `src/Rules/`, each with its check and the examples that show the
check matches its statement (`test/rules.jl`). There are NO scans and no `policy/` — the
rulebook a session loads, `.gbg/policy/`, is written by `Render.policy` from the rule values. What a
package switches off is a `Switch` in its `.gbg/config.jl`. A package's wiring is judged by the WIRING
CHECK — `Render.wiring`, run inside every docs build and every test run. The documentation review is
SWITCHED OFF here until Phase 8, with the reason in `.gbg/config.jl`: the tool reviews itself last.
`.claude/skills/` holds one file per built instrument that applies, written by `Render.skill`; do not
hand-edit one, and do not re-create an instrument outside its phase.

`Witnesses.jl` is the one file of the old tree left, and rests until Phase 6.

## Modules and wiring

- `src/GBGCodingTools.jl` is the module: constants (`PKG_UUID`, `PKG_NAME`, `JULIA_FLOOR`), then the
  includes in dependency order — the new tree first, in its own order, then what is left of the old one.
- The new tree, each module naming only those above it: `Model` (the types), `Texts` (reading a text and
  finding a place in it again), `Catalogue` (the rulebook and the always-on table as values), `ConfigIO`
  (`.gbg/config.jl`, parsed as data and never evaluated), `Engine` (`Checks` runs a rule, `Guard`
  classifies a change, `Harness` is what `test/runtests.jl` calls), `Render` (every generated file).
- The CLI is `gbg <noun> <verb>`: `Main.jl` dispatches `VERBS`; each `src/CLI/*.jl` file registers its
  verbs and returns the exit code 0 clean, 1 finding, 2 cannot evaluate, 3 crash. `Wire` (`init`,
  `sync`), `Check`, `Docfix`, `Bump`, `Release`, `Fleet`, `Install`, `Self`, `Git`.
- `ext/GBGCodingToolsDocumenterExt.jl` defines `makedocs`, the mandatory docs-build wrapper; it loads
  only where `Documenter` is. It reads no review state and nothing can freeze it.
- Data, never code: `.gbg/config.jl` is the one config a package writes; everything else under `.gbg/`
  is generated. `fixture/GBG Fixture/` is the toy consumer the tests run over.

## Core invariants

- A consumer holds data; the tool holds behaviour; the only thing connecting them is a pin.
- Nothing a consumer's docs build or test suite runs may read review state, git state or the network:
  both must give the same answer on a fresh clone and on CI (`docs/ARCHITECTURE.md` §5.1, §11).
- Changing documentation is safe and changing code is not: what counts as documentation is listed in
  §4.2 of the design, and everything else — tests, stored data, config, generated files, this file but
  for the sections its config names in `claude_documentation` — is code, which changes only on the
  owner's answer.
- Exit codes are the contract; a log is never grepped for a verdict. A scan output is never truncated.
- Deterministic first: whatever a program can decide is a program's to decide (§7).

## Code generation rules

- Julia 1.12 floor. Dependencies and external tools are allowed developer-side — in `docs/` and `test/`
  environments — and never in a science package's own `[deps]` (§5.1).
- Every public binding carries a docstring written to `policy/docs-rubric.md`; module docstrings are
  maps. `checkdocs = :exports` in the tool's own build verifies them.
- STRICTER THAN THE FLEET RULE, and this package's alone: `RULE.DOC.AI_BANNER` requires the provenance
  banner on rationale pages and Literate examples; here EVERY page of the site carries it, because the
  owner reviews the four science packages' API prose but not this one's. The home page is exempt
  fleet-wide by the rule itself.
- A verb never `git add`s; the session commits — except `gbg docfix commit`, whose whole point is to
  ask the change guard BEFORE a commit exists. `sync` never merges: it writes what the generator
  returns, and the wiring check is what makes that bargain safe by reporting drift on every build.
- Paths carry spaces (every consumer path has two): quote them in every rendered command.

## Working agreements

- Commit ⇒ push, directly on `master`; every commit message ends with the versionless trailer
  `Co-Authored-By: Anthropic Claude <noreply@anthropic.com>` and nothing else (`RULE.GIT.TRAILER`, ruled 2026-09-08);
  stage with `git add -u` plus new files by name, never `-A`.
- Gate every commit on `tools/floor.sh` — `Pkg.test()` and the docs build, each exit 0. "Should work" is
  not done. Unasked, run only that.
- Every phase of `IMPLEMENTATION.md` says what it creates, what it deletes, and the gate it ends on. A
  mechanism added outside its phase names, in its commit, the requirement or failure it answers.
- The four science packages are read for the ports and edited only in their own phase (3, 5 and 7),
  never on a peer session's request.
- Two hosts (`Aiporetne`, `Enteropia`); per-machine state (`~/.local/bin/gbg`, `~/.gbg/dev`, juliaup) is
  installed on each and never synced; a torn Dropbox file is waited out (`CFG.TORN`).
- EVERY repository here lives inside Dropbox, so scratch goes to a system temporary directory
  (`mktempdir()`, `TMPDIR`), never inside a repository. The self-tests do this since 2026-09-17; the
  defect they had before — a per-test copy under `fixture/.tmp/` that only a complete run cleaned up —
  grew to 61,057 directories, passed this machine's inotify watch limit, and stopped Dropbox syncing for
  every package at once.

## Release checklist

1. Clean tree on `master`, pushed; `tools/floor.sh` green; `gbg sync --check` clean at the root.
2. `CHANGELOG.md` carries the entry `## <ver> — <date>` with MAJOR | MINOR | PATCH.
3. `gbg --dev release <ver>` (or `<ver>-rc.<n>`) tags and pushes, and records a final release in GBGRegistry;
   a tag is never moved or re-issued.
4. Nothing else holds a release: no review, no open finding, no unanswered question, no audit.
5. The 1.0.0 line is abandoned: the eleven `v1.0.0-rc.*` tags stand, 1.0.0 is never released, and the
   next release is `2.0.0`, cut where `IMPLEMENTATION.md` §5 says.
