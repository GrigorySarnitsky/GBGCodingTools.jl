# The design's §5.1; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Engine

What runs the rules: the checks over a package's texts and loaded module, the test harness a consumer's
suite calls, the change guard, and the programs that check a question before it is put
.

It is the fifth module of the order and may name `Model`, `Texts`, `Catalogue` and `ConfigIO` — never
`Render`, `Orchestration` or anything a run writes, because what executes inside a consumer's build and
test lives here and must give the same answer on a fresh clone and on CI.

- [`Checks`](@ref) — which files a file set names here, which rules apply, and what they report.
- [`Harness`](@ref) — what a package's test suite calls: the code rules and its own contracts.
- [`Guard`](@ref) — documentation or code, for one changed file.

`Harness` and `Questions` arrive in the phases that need them.
"""
module Engine

using ..Model
using ..Texts
using ..Catalogue
using ..ConfigIO

include("Engine/Checks.jl")
include("Engine/Harness.jl")
include("Engine/Guard.jl")

end # module Engine
