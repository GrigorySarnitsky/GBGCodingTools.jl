# The design's §3; the coordinates live here rather than in a docstring, which must read complete at the REPL.
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

This package is being rebuilt to the design in, adopted on 2026-09-17, in the
order sets out. The round machinery — the stage machine, the fix passes and their
grading, the preflight, the seeds and the recall, the closure gate — was deleted on that day and is
filed under `docs/design-record/machinery-v1/`. What is here now is the deterministic half: the scans,
the reflection checks, the test harness, the doctor, the generators and the rulebook prose.

The terms the rest of the package uses as settled words, bound once here:

- An **instrument** is a review procedure the owner asks a session to run. The new design names four
; none of them runs from this tree today.
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

- [`Wire`](@ref) — `gbg init` and `gbg sync`: everything that connects a package to this one, written
  from the config by `Render` and compared by the wiring check.
- [`Ledger`](@ref) — the reader of `.gbg/exemptions.toml`, which goes with the old config;
  [`Git`](@ref) — the git questions the verbs ask.
- `Fleet.jl`, `Bump.jl`, `Release.jl`, `Install.jl`, `Self.jl` — the fleet report, the pin bump, the
  release, the install of the `gbg` command, and `gbg self verify`.

The engines:

- `TestHarness`, `Reflection`, `Witnesses` — the Julia-side engines a consumer's tests call.
- `TreeHash` — git blob and tree hashing on the `SHA` stdlib, behind `gbg self verify`.
- `HtmlWalker` — the Gumbo walker the rules that read a built site use.
- [`scan_docs`](@ref), [`scan_html`](@ref), [`register_scan!`](@ref) — the text-scan engine, whose
  catalogue and registry are empty since the last scan became a rule; it goes in Phase 5.
"""
module GBGCodingTools

using TOML, SHA, Dates, Pkg, Random, JSON3
using Gumbo, AbstractTrees

const PKG_UUID = Base.UUID("3aee1de0-bb62-4679-b1c5-a861fbcaaa51")
const PKG_NAME = "GBGCodingTools"
const JULIA_FLOOR = v"1.12"

include("Model.jl")          # the new tree begins here: types only, no behaviour
include("Texts.jl")          # reading the texts a rule is about, and finding a place in them again
include("Catalogue.jl")      # what this package knows, as values: the table, the rulebook, the register
include("ConfigIO.jl")       # a package's own settings, read as data and never evaluated
include("Engine.jl")         # what runs the rules; for now, the change guard
include("Render.jl")
include("Orchestration.jl")         # every file that connects a package to this one
include("TreeHash.jl")
include("HtmlWalker.jl")
include("DocLints.jl")
include("CLI/Main.jl")
include("CLI/Config.jl")
include("Witnesses.jl")
include("Reflection.jl")
include("TestHarness.jl")
include("CLI/Ledger.jl")
include("Scan.jl")
include("CLI/Self.jl")
include("CLI/Install.jl")
include("CLI/Git.jl")
include("CLI/Wire.jl")
include("CLI/Check.jl")
include("CLI/Docfix.jl")
include("CLI/Fleet.jl")
include("CLI/Bump.jl")
include("CLI/Answer.jl")
include("CLI/Run.jl")
include("CLI/Release.jl")

end # module
