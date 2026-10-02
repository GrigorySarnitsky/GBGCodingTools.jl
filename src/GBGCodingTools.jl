# The design's §3; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    GBGCodingTools

The one shared tooling package of the GBG Julia packages: the rulebook and the programs that check
it, the docs-build wrapper, the test harness, the documentation review and the generated files that
connect a package to all of that, at one version pinned by every consumer.

A consumer is a package that uses the tool — one of the four sibling GBG packages, or the tool itself.
Each consumer pins the tool to one exact version, named in its `.gbg/config.jl` (`tool`: a released
version, or `:dev` for a checkout), which `gbg sync` renders into the consumer's sub-environment compat
entries. A consumer holds data; the tool holds behaviour; the only thing connecting them is that pin.

The module is a map; every part is documented at its home. The tree, each module naming only those
above it, begins with the data:

- [`Model`](@ref) — the types: a rule, a config, a finding, a run, a question, and nothing that acts.
- [`Texts`](@ref) — reading the texts a rule is about, and finding a place in them again.
- [`Catalogue`](@ref) — what this package knows, as values: the rulebook, the table, the disciplines.
- [`ConfigIO`](@ref) — `.gbg/config.jl`, read as data and never evaluated.

Above them, what acts:

- [`Engine`](@ref) — `Checks` runs a rule, `Guard` classifies a change, `Questions` asks the owner,
  `Harness` is what a package's `test/runtests.jl` calls.
- [`Render`](@ref) — every generated file, and the wiring check that compares them.
- `Study` — the rule wording study: agreement between readers, measured.
- `Orchestration` — a run, its site, its scope and its agents; what no build or test may reach.

The command line is `gbg <noun> <verb>`: [`main`](@ref) dispatches the closed table [`VERBS`](@ref),
and the exit contract is 0 clean, 1 substantive finding, 2 cannot evaluate, 3 crash.

The verbs live under `src/CLI/`, one file per noun, each verb a function returning its exit code:
[`Wire`](@ref) (`init`, `sync`), `Check`, `Docfix`, `Answer`, `Run`, `StudyCmd`, `Bump`, `Release`,
`Fleet`, `Install`, `Self` and [`Git`](@ref), the git questions the verbs ask.

Two engines a consumer's own build and tests call: [`makedocs`](@ref), the mandatory wrapper around
`Documenter.makedocs`, which reads no review state and nothing can freeze; and
[`TestHarness`](@ref), with [`Witnesses`](@ref), the Julia-side engines a consumer's `test/` runs.
"""
module GBGCodingTools

using TOML, SHA, Dates, Pkg, Random, JSON3

const PKG_UUID = Base.UUID("3aee1de0-bb62-4679-b1c5-a861fbcaaa51")
const PKG_NAME = "GBGCodingTools"
const JULIA_FLOOR = v"1.12"

# The design's §5.1, §10; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    makedocs(root; kwargs...)

The mandatory docs-build wrapper a consumer's `docs/make.jl` calls instead of `Documenter.makedocs`.
The body is defined by the Documenter extension (`ext/GBGCodingToolsDocumenterExt.jl`), which Julia
loads once `Documenter` is in the environment — a consumer's `make.jl` already does `using Documenter`.

# Arguments

- `root` — the package root, the directory holding `.gbg/config.jl`.
- `kwargs...` — the [keyword arguments](https://docs.julialang.org/en/v1/manual/functions/#Keyword-Arguments)
  passed to `Documenter.makedocs` unchanged (`sitename`, `pages`, `modules`, `checkdocs`, `format`, …).

Before Documenter runs it runs, in-process, the documentation rules of the rulebook and the wiring
check; after Documenter it runs the rules that read the built site. Any non-zero
return is an `error`, so the build fails. It prints one banner line, `GBGCodingTools v<ver> makedocs`,
which a consumer's CI greps for.

A build reads no review state and nothing can freeze it: the closure gate that used to refuse a build
while a round was open went with the round machinery on 2026-09-17, because a check that runs inside a
consumer's build must give the same answer on a fresh clone and on CI.

Returns what `Documenter.makedocs` returns, `true` when that is `nothing` — as it is unless `debug =
true` is passed.
"""
function makedocs end

include("Model.jl")          # the new tree begins here: types only, no behaviour
include("Texts.jl")          # reading the texts a rule is about, and finding a place in them again
include("Catalogue.jl")      # what this package knows, as values: the table, the rulebook, the register
include("ConfigIO.jl")       # a package's own settings, read as data and never evaluated
include("Engine.jl")         # what runs the rules; for now, the change guard
include("Render.jl")
include("Publication.jl")    # the leak scan's engine: what a repository would publish, read whole
include("Study.jl")                 # the rule wording study: agreement, measured
include("Orchestration.jl")         # every file that connects a package to this one
include("CLI/Main.jl")
include("Witnesses.jl")
include("TestHarness.jl")
include("CLI/Self.jl")
include("CLI/Install.jl")
include("CLI/Git.jl")
include("CLI/StudyCmd.jl")
include("CLI/Wire.jl")
include("CLI/Check.jl")
include("CLI/Docfix.jl")
include("CLI/Fleet.jl")
include("CLI/Bump.jl")
include("CLI/Answer.jl")
include("CLI/Run.jl")
include("CLI/Release.jl")
include("CLI/Leak.jl")

end # module
