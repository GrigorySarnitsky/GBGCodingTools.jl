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

The engines:

- `TestHarness`, `Reflection`, `Witnesses` — the Julia-side engines a consumer's tests and the
  instruments call.
- [`scan_docs`](@ref), [`scan_html`](@ref), [`register_scan!`](@ref) — the deterministic text and
  built-HTML scan engine over `catalog/scans.toml`, one function per scan id under `src/Scans/`.
- `TreeHash` — git blob and tree hashing on the `SHA` stdlib, behind `gbg self verify`.
- `HtmlWalker` — the Gumbo walker shared by the consolidator and the built-HTML scans.
"""
module GBGCodingTools

using TOML, SHA, Dates, Pkg, Random, JSON3
using Gumbo, AbstractTrees

const PKG_UUID = Base.UUID("3aee1de0-bb62-4679-b1c5-a861fbcaaa51")
const PKG_NAME = "GBGCodingTools"
const JULIA_FLOOR = v"1.11"

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
include("CLI/Fleet.jl")
include("CLI/Bump.jl")
include("CLI/Release.jl")
include("CLI/Selftest.jl")

end # module
