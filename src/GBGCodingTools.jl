"""
    GBGCodingTools

The one shared tooling package of the GBG Julia packages: the review instruments, the docs-build
wrapper and its scans, the test harness, the doctor and the policy prose, at one version pinned by every
consumer.

A consumer is a package that uses the tool — one of the four sibling GBG packages, or the tool itself.
Each consumer pins the tool to one exact version, named in its `.gbg/config.toml` (`tool.version`: a
released `X.Y.Z`, or `dev` for a checkout), which `gbg sync` renders into the consumer's
sub-environment compat entries. A consumer holds data; the tool holds behaviour; the only thing
connecting them is that pinned version.

The terms the rest of the package uses as settled words, bound once here:

- An **instrument** is one of four review procedures: `check-docs`, `check-consistency`, `bug-hunt`,
  `audit-changes`.
- A **round** is one run of one instrument over one consumer, recorded under `.gbg/rounds/`.
- A **surface** is one named file set of `[surfaces]`: `src`, `rationale`, `pages`, `built_html`, …
- A **lane** is one agent's share of a round — one surface, one territory, or one kind of change.
- A **hat** is one persona of the `check-consistency` panel, reading the corpus from a single standpoint.
- A **Workflow** is the instrument's `workflow/*.js` script, launched by the session running the round.
- The **gate**, [`gate`](@ref), is the refusal that stops a build, a test or a commit from stepping
  around an open round.

The module is a map; every part is documented at its home. The command line and its configuration:

- [`main`](@ref) — the one entry point of `gbg <noun> <verb>`; the exit contract is 0 clean,
  1 substantive finding, 2 cannot evaluate, 3 crash. The verbs live under `src/CLI/`, one file per
  noun, each verb a function returning its exit code.
- `Config` — [`Config.read`](@ref) loads and validates a consumer's `.gbg/config.toml`.
- [`makedocs`](@ref) — the mandatory wrapper around `Documenter.makedocs` (defined by the Documenter
  extension; declared in `DocLints`).

The round machinery, one module per concern under `src/CLI/`:

- [`Preflight`](@ref), [`Rounds`](@ref), [`Passes`](@ref) — a round's life: the preflight and the
  open, prepare and bank, then the verification passes, the grade and the close;
  [`demote`](@ref) is the one demotion rule the grade applies to an act verdict.
- [`Seeds`](@ref), [`Recall`](@ref) — the labelled defects a seeded round plants, and the recall
  measured on them.
- [`RoundFiles`](@ref), [`Git`](@ref) — reading what a round wrote, and the git questions the round
  verbs ask.

The upkeep verbs and the rest of `src/CLI/`:

- [`Sync`](@ref), [`Init`](@ref) — rendering the managed files into a consumer, and seeding a new
  consumer's `.gbg/`.
- [`Ledger`](@ref) — the reader of `.gbg/exemptions.toml`; [`Doctor`](@ref) — the read-only health
  check.
- `Hunt.jl`, `Audit.jl` — the verbs particular to `bug-hunt` and `audit-changes`; `Design.jl` —
  [`attack`](@ref) and [`calibrate`](@ref), the checks on the instruments themselves; `Fleet.jl`,
  `Bump.jl`, `Release.jl`, `Install.jl`, `Self.jl`, `Selftest.jl` — the fleet report, the pin bump,
  the release, the install of the `gbg` command, `gbg self verify` and the self-test; `Schema.jl` — the one validator
  of every artefact against `schema/`.

The engines:

- `TestHarness`, `Reflection`, `Witnesses` — the Julia-side engines a consumer's tests and the
  instruments call.
- [`scan_docs`](@ref), [`scan_html`](@ref), [`register_scan!`](@ref) — the deterministic text and
  built-HTML scan engine over `catalog/scans.toml`, one function per scan id under `src/Scans/`.
- `TreeHash` — git blob and tree hashing on the `SHA` stdlib, behind `gbg self verify`.
- `HtmlWalker` — the Gumbo walker shared by the consolidator and the built-HTML scans.
- [`consolidate`](@ref) — the consolidator itself: the built site as one page-marked manuscript. A
  consistency round's hats read it, and its seeds go into it; a docs round seeds lane-file copies.
"""
module GBGCodingTools

using TOML, SHA, Dates, Pkg, Random, JSON3
using Gumbo, AbstractTrees

const PKG_UUID = Base.UUID("3aee1de0-bb62-4679-b1c5-a861fbcaaa51")
const PKG_NAME = "GBGCodingTools"
const JULIA_FLOOR = v"1.12"

include("TreeHash.jl")
include("HtmlWalker.jl")
include("DocLints.jl")
include("CLI/Main.jl")
include("CLI/Schema.jl")
include("CLI/Config.jl")
include("Witnesses.jl")
include("Reflection.jl")
include("TestHarness.jl")
include("CLI/Ledger.jl")
include("Scan.jl")
include("CLI/Consolidate.jl")
include("CLI/Self.jl")
include("CLI/Install.jl")
include("CLI/Sync.jl")
include("CLI/Init.jl")
include("CLI/RoundFiles.jl")
include("CLI/Git.jl")
include("CLI/Doctor.jl")
include("CLI/Gate.jl")
include("CLI/Demote.jl")
include("CLI/Seed.jl")
include("CLI/Recall.jl")
include("CLI/Preflight.jl")
include("CLI/Rounds.jl")
include("CLI/Passes.jl")
include("CLI/Hunt.jl")
include("CLI/Audit.jl")
include("CLI/Design.jl")
include("CLI/Fleet.jl")
include("CLI/Bump.jl")
include("CLI/Release.jl")
include("CLI/Selftest.jl")

end # module
