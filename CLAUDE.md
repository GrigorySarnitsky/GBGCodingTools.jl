<!-- gbg:managed begin vdev sha256:cad586d6ca9739e227392ab71078acead8442e283fcaaa8942189a40490c7837 — rewritten by `gbg sync`; do not edit -->
@.gbg/policy/00-index.md
## GBGCodingTools — this package's parameters and declared deviations
- Package `GBGCodingTools`; leading identity: physical meaning; vectors: none.
- Deviations: `RULE.TEST.ALLOC_ZERO` on `*` — no in-place operator over element storage exists here: this package's `!` functions mutate a registry, a dictionary or a string buffer, and an allocation bound on them measures the Julia runtime, not the package; `RULE.TEST.PASS_AUDIT` on `*` — the traffic audit counts reads and writes per array element; this package holds no array whose traffic is a correctness property, so a frozen row would record the runtime's behaviour and nothing of the package's; `RULE.TEST.EXAMPLES_RUN` on `*` — this package ships no Literate examples: its `literate` surface is empty by design, since a worked example of a review instrument is a round, which is recorded under .gbg/rounds/ rather than executed as a script; `RULE.DOC.LEADING_IDENTITY` on `*` — the leading identity of a docstring is the physical meaning of the quantity it computes; this package computes no physical quantity, so its docstrings lead with what the operation does, which the rubric's own parameterisation already admits; `RULE.API.POSITIONAL` on `*` — no program decides whether an argument affects the result: the rule is semantic, so no scan or doctor check can exist for it. Its `check` in RULES.toml is `panel` — decided by a reading panel inside an instrument that runs, which under `RULE.TEST.RULE_WITH_CHECK` is an answer and not the unpaid debt `weakness` names
- "Check the docs" means run `/check-docs`. Instruments run only on the user's request, in words or by
  slash — never unasked; unasked, run only `Pkg.test()`.
<!-- gbg:managed end -->

# CLAUDE.md — GBGCodingTools

You are in the dev checkout of `GBGCodingTools.jl`, the one shared tooling package of the four GBG Julia
packages and of itself. **It is being rebuilt.** `docs/ARCHITECTURE.md` is the design it is being built
to — normative, adopted by the owner on 2026-09-17 — and `IMPLEMENTATION.md` is the order of the work,
phase by phase, each with the gate it must pass. What the package was before is
`docs/design-record/ARCHITECTURE-v1.md`, and the machinery deleted from it is filed beside that, under
`machinery-v1/`, `instruments-v1/`, `roles-v1/`, `rounds-v1/` and `seeds-v1/`: history, read by nothing.
The managed block above imports the shared policy; this file holds only what is the tool's own.

## Where the rebuild stands

Phase 0 of `IMPLEMENTATION.md`. The round machinery, the instruments, their catalogues, the seeding and
the closure gate are gone; the deterministic half — the scans, the reflection checks, the test harness,
the doctor, the generators and the rulebook prose — is what remains, and the new tree (`Model`, `Texts`,
`Catalogue`, `ConfigIO`, `Engine`, `Render`, `Orchestration`) has not been started. **No instrument runs
here.** A slash command that once opened a round no longer exists; do not look for one, and do not
re-create one outside its phase.

## Modules and wiring

- `src/GBGCodingTools.jl` is the module: constants (`PKG_UUID`, `PKG_NAME`, `JULIA_FLOOR`), then the
  includes in dependency order. `Config` reads and validates `.gbg/config.toml` through `Schema.jl`, the
  one JSON-Schema-subset validator over `schema/*.schema.json`. `Ledger` reads `.gbg/exemptions.toml`.
- Engines: `Scan.jl` (the text-scan engine; one file per scan under `src/Scans/`, registered against
  `catalog/scans.toml`), `Reflection` (argcov, signature fidelity, xlink, dupref, the public surface),
  `TestHarness` (the consumers' test engines), `Witnesses` (the witness runner), `HtmlWalker` and
  `Consolidate.jl` (the built site to reader text), `TreeHash` (git hashing on `SHA`).
- The CLI is `gbg <noun> <verb>`: `Main.jl` dispatches `VERBS`; each `src/CLI/*.jl` file registers its
  verbs and returns the exit code 0 clean, 1 finding, 2 cannot evaluate, 3 crash. `Sync`, `Init`,
  `Doctor`, `Self.jl`, `Install.jl`, `Fleet.jl`, `Bump.jl`, `Release.jl`.
- `ext/GBGCodingToolsDocumenterExt.jl` defines `makedocs`, the mandatory docs-build wrapper; it loads
  only where `Documenter` is. It reads no review state and nothing can freeze it.
- Data, never code: `catalog/scans.toml`, `policy/` (the rule files and `RULES.toml`), `schema/`,
  `templates/`. `fixture/GBG Fixture/` is the toy consumer the tests run over.

## Core invariants

- A consumer holds data; the tool holds behaviour; the only thing connecting them is a pin.
- Nothing a consumer's docs build or test suite runs may read review state, git state or the network:
  both must give the same answer on a fresh clone and on CI (`docs/ARCHITECTURE.md` §5.1, §11).
- Changing documentation is safe and changing code is not: what counts as documentation is listed in
  §4.2 of the design, and everything else — tests, stored data, config, generated files, this file — is
  code, which changes only on the owner's answer.
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
- A verb never `git add`s; the session commits. `sync` refuses a hand-edited managed file and never
  merges. A doctor check is read-only.
- Paths carry spaces (every consumer path has two): quote them in every rendered command.

## Working agreements

- Commit ⇒ push, directly on `master`; every commit message ends with the trailer the session is given;
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
  (`mktempdir()`, `TMPDIR`), never inside the repository. The self-tests still break this:
  `test/helpers.jl` copies the fixture into `fixture/.tmp/<pid>/`, and only `test/runtests.jl` cleans it
  up — so an interrupted run leaves directories behind. On 2026-09-16 that scratch had grown to 61,057
  directories, past the system's inotify watch limit, and Dropbox stopped syncing for everything. After
  running tests, check `fixture/.tmp` and remove what is left; Phase 1 moves it, and this note goes then.

## Release checklist

1. Clean tree on `master`, pushed; `tools/floor.sh` green; `gbgdev doctor --deep` green at the root.
2. `CHANGELOG.md` carries the entry `## <ver> — <date>` with MAJOR | MINOR | PATCH.
3. `gbgdev release <ver>` (or `<ver>-rc.<n>`) tags and pushes; a tag is never moved or re-issued.
4. Nothing else holds a release: no review, no open finding, no unanswered question, no audit.
5. The 1.0.0 line is abandoned: the eleven `v1.0.0-rc.*` tags stand, 1.0.0 is never released, and the
   next release is `2.0.0`, cut where `IMPLEMENTATION.md` §5 says.
