"""
    Engine

What runs the rules: the checks over a package's texts and loaded module, the test harness a consumer's
suite calls, the change guard, and the programs that check a question before it is put
(`docs/ARCHITECTURE.md` §5.1).

It is the fifth module of the order and may name `Model`, `Texts`, `Catalogue` and `ConfigIO` — never
`Render`, `Orchestration` or anything a run writes, because what executes inside a consumer's build and
test lives here and must give the same answer on a fresh clone and on CI.

- [`Checks`](@ref) — which files a file set names here, which rules apply, and what they report.
- [`Guard`](@ref) — documentation or code, for one changed file.

`Harness` and `Questions` arrive in the phases that need them.
"""
module Engine

using ..Model
using ..Texts
using ..Catalogue

include("Engine/Checks.jl")
include("Engine/Guard.jl")

end # module Engine
