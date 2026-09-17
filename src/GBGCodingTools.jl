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

This package is being rebuilt to the design in `docs/ARCHITECTURE.md`, adopted on 2026-09-17, in the
order `IMPLEMENTATION.md` sets out. The round machinery — the stage machine, the fix passes and their
grading, the preflight, the seeds and the recall, the closure gate — was deleted on that day and is
filed under `docs/design-record/machinery-v1/`. What is here now is the deterministic half: the scans,
the reflection checks, the test harness, the doctor, the generators and the rulebook prose.

The terms the rest of the package uses as settled words, bound once here:

- An **instrument** is a review procedure the owner asks a session to run. The new design names four
  (`docs/ARCHITECTURE.md` §3); none of them runs from this tree today.
- A **surface** is one named file set of `[surfaces]`: `src`, `rationale`, `pages`, `built_html`, …
- A **hat** is one persona of a reading panel, reading the corpus from a single standpoint.

The module is a map; every part is documented at its home. The command line and its configuration:

- [`main`](@ref) — the one entry point of `gbg <noun> <verb>`; the exit contract is 0 clean,
  1 substantive finding, 2 cannot evaluate, 3 crash. The verbs live under `src/CLI/`, one file per
  noun, each verb a function returning its exit code.
- `Config` — [`Config.read`](@ref) loads and validates a consumer's `.gbg/config.toml`.
- [`makedocs`](@ref) — the mandatory wrapper around `Documenter.makedocs` (defined by the Documenter
  extension; declared in `DocLints`). It reads no review state and nothing can freeze it.

The upkeep verbs and the rest of `src/CLI/`:

- [`Sync`](@ref), [`Init`](@ref) — rendering the managed files into a consumer, and seeding a new
  consumer's `.gbg/`.
- [`Ledger`](@ref) — the reader of `.gbg/exemptions.toml`; [`Doctor`](@ref) — the read-only health
  check; [`Git`](@ref) — the git questions the verbs ask.
- `Fleet.jl`, `Bump.jl`, `Release.jl`, `Install.jl`, `Self.jl`, `Selftest.jl` — the fleet report, the
  pin bump, the release, the install of the `gbg` command, `gbg self verify` and the self-test;
  `Schema.jl` — the one validator of every artefact against `schema/`.

The engines:

- `TestHarness`, `Reflection`, `Witnesses` — the Julia-side engines a consumer's tests call.
- [`scan_docs`](@ref), [`scan_html`](@ref), [`register_scan!`](@ref) — the deterministic text and
  built-HTML scan engine over `catalog/scans.toml`, one function per scan id under `src/Scans/`.
- `TreeHash` — git blob and tree hashing on the `SHA` stdlib, behind `gbg self verify`.
- `HtmlWalker` — the Gumbo walker shared by the consolidator and the built-HTML scans.
- [`consolidate`](@ref) — the consolidator: the built site as one page-marked manuscript.
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
include("CLI/Git.jl")
include("CLI/Doctor.jl")
include("CLI/Fleet.jl")
include("CLI/Bump.jl")
include("CLI/Release.jl")
include("CLI/Selftest.jl")

end # module
