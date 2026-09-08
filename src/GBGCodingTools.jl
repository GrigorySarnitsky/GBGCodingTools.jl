"""
    GBGCodingTools

The one shared tooling package of the GBG Julia packages: the review instruments, the docs-build
wrapper and its scans, the test harness, the doctor and the policy prose, at one version pinned by every
consumer. A consumer holds data; the tool holds behaviour; the only thing connecting them is a pin.

The module is a map; every part is documented at its home:

- [`main`](@ref) — the one entry point of the command line `gbg <noun> <verb>`; the exit contract is
  0 clean, 1 substantive finding, 2 cannot evaluate, 3 crash.
- `Config` — [`Config.read`](@ref) loads and validates a consumer's `.gbg/config.toml`.
- [`makedocs`](@ref) — the mandatory wrapper around `Documenter.makedocs` (defined by the Documenter
  extension; declared in `DocLints`).
- `TestHarness`, `Reflection`, `Witnesses` — the Julia-side engines a consumer's tests and the
  instruments call.
- `TreeHash` — git blob and tree hashing on the `SHA` stdlib, behind `gbg self verify`.
- `HtmlWalker` — the Gumbo walker shared by the consolidator and the built-HTML scans.
- The CLI files under `src/CLI/`, one per noun, each verb a function returning its exit code.
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
include("CLI/Self.jl")
include("CLI/Install.jl")
include("CLI/Consolidate.jl")

end # module
