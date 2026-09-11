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
packages and of itself. The design is `docs/ARCHITECTURE.md` (every decision with its evidence; the
vocabulary at its head binds the terms); the build plan is `IMPLEMENTATION.md`; `docs/design-record/`
is provenance. The managed block above imports the shared policy; this file holds only what is the
tool's own.

## Modules and wiring

- `src/GBGCodingTools.jl` is the module: constants (`PKG_UUID`, `PKG_NAME`, `JULIA_FLOOR`), then the
  includes in dependency order. `Config` reads and validates `.gbg/config.toml` through `Schema.jl`, the
  one JSON-Schema-subset validator over `schema/*.schema.json`. `Ledger` reads `.gbg/exemptions.toml`.
- Engines: `Scan.jl` (the text-scan engine; one file per scan under `src/Scans/`, registered against
  `catalog/scans.toml`), `Reflection` (argcov, signature fidelity, xlink, dupref, the public surface),
  `TestHarness` (the consumers' test engines and `gate()`), `Witnesses` (the witness runner),
  `HtmlWalker` and `Consolidate.jl` (the built site to reader text), `TreeHash` (git hashing on `SHA`).
- The CLI is `gbg <noun> <verb>`: `Main.jl` dispatches `VERBS`; each `src/CLI/*.jl` file registers its
  verbs and returns the exit code 0 clean, 1 finding, 2 cannot evaluate, 3 crash. `Sync`, `Init`,
  `Doctor`, `Gate.jl`, `Preflight`, `Rounds`, `Passes`, `Hunt.jl`, `Audit.jl`, `Self.jl`, `Install.jl`.
- `ext/GBGCodingToolsDocumenterExt.jl` defines `makedocs`, the mandatory docs-build wrapper; it loads
  only where `Documenter` is.
- Data, never code: `catalog/` (hats, lanes, scans, models), `policy/` (the rule files and
  `RULES.toml`), `schema/`, `templates/`, `instruments/<name>/` (`PROTOCOL.md`, `schema.json`,
  `workflow/*.js`). `fixture/GBG Fixture/` is the toy consumer the tests run over.

## Core invariants

- A consumer holds data; the tool holds behaviour; the only thing connecting them is a pin. No package
  string, path or round datum in a Workflow script, a catalogue file or a policy file: they arrive
  through `args`, the config, or a slot.
- Instruments are frozen mid-round: a change to a scan, a script, a catalogue or a policy file is its own
  commit and its own release, never an edit inside a consumer and never folded into a round it scores.
- Closed vocabularies (ARCHITECTURE §6.3) and the config's non-configurable set (§5.5): changing either
  is MAJOR. Every artefact carries `schema_version`.
- Exit codes are the contract; a log is never grepped for a verdict. A scan output is never truncated.
- The tool is its own fifth consumer (D15): its `.gbg/`, its rounds, its managed files are rendered by
  the same verbs, and `Pkg.test()` runs `TestHarness.gate()` on the tool itself.

## Code generation rules

- Julia 1.12 floor; no Python anywhere; no child process except the consumer commands the design names
  (`docs_build`, `julia_test`, the witnesses, git) and the `--deep` doctor checks.
- Every public binding carries a docstring written to `policy/docs-rubric.md`; module docstrings are
  maps. `checkdocs = :exports` in the tool's own build verifies them.
- STRICTER THAN THE FLEET RULE, and this package's alone: `RULE.DOC.AI_BANNER` requires the provenance
  banner on rationale pages and Literate examples; here EVERY page of the site carries it, the API and
  generated guide pages included, because the owner reviews the four science packages' API prose but
  not this one's — AI is this package's main reader. The home page is not an exception of this
  package's: the rule itself exempts it fleet-wide, the owner reviewing that page in every package.
- A verb never `git add`s; the session commits. `sync` refuses a hand-edited managed file and never
  merges. A doctor check is read-only.
- Paths carry spaces (every consumer path has two): quote them in every rendered command.

## Working agreements

- Commit ⇒ push, directly on `master`; every commit message ends with
  `Co-Authored-By: Anthropic Claude <noreply@anthropic.com>`; stage with `git add -u` plus new files by
  name, never `-A`.
- Gate every commit on exit codes (`bash -e -o pipefail`); "should work" is not done; unasked, run only
  `Pkg.test()`, `gbgdev selftest` and the docs build (`gbgdev` is `gbg --dev`, the shim routed to the
  dev checkout `~/.gbg/dev` names).
- The four consumers are read for the ports and edited only in their migration phase (4–7), never on
  a peer session's request. Their instruments are frozen until then.
- Two hosts (`Aiporetne`, `Enteropia`); per-machine state (`~/.local/bin/gbg`, `~/.gbg/dev`, juliaup)
  is installed on each and never synced; a torn Dropbox file is waited out (`CFG.TORN`).

## Release checklist

1. Clean tree on `master`, pushed; `Pkg.test()` green on 1.12; `julia --project=docs
   docs/make.jl` exits 0 (`SELF.DOCS`); `gbgdev doctor --deep` green at the root.
2. `CHANGELOG.md` carries the entry `## <ver> — <date>` with MAJOR | MINOR | PATCH, the instruments
   affected and "rates comparable: yes | no" (a MAJOR states the fixture recall before and after).
3. For a final release: no round open under `.gbg/rounds/`, and the `/check-docs` round opened at the
   latest `<ver>-rc.<n>` tag closed by honored, adjudicated, rescan, seeded or carried ids, never
   abandoned.
4. `gbgdev release <ver>` (or `<ver>-rc.<n>`) tags and pushes; a tag is never moved or re-issued.
5. Consumers adopt with `gbg bump <ver>` in their own commits; the fleet is at one version within the
   `[sweep]` window `gbg fleet` reports.

## Current state

Phase 1 of `IMPLEMENTATION.md` is built and released as candidates `v1.0.0-rc.1` onward; the final
`1.0.0` waits on the serious findings `.gbg/carried.toml` holds and on `.claude/WORK_QUEUE.md`. Live
plans are in `docs/ROADMAP.md`.
