"""
    GBGFixture

The toy consumer of `GBGCodingTools`: a package small enough to read in one sitting whose documentation
is written to the shared rubric, so the tool's own tests have a clean corpus to scan, build and gate.
The module is a map:

- [`FixtureA`](@ref) — a grid and the operations on values over it.
- [`FixtureB`](@ref) — the reductions of a value field.
- [`FixtureC`](@ref) — the options record and its display.
"""
module GBGFixture

include("FixtureA.jl")
include("FixtureB.jl")
include("FixtureC.jl")

using .FixtureA, .FixtureB, .FixtureC
export Grid, twice, scale!, scale, mean_value, total_energy, Options, describe

end # module GBGFixture
