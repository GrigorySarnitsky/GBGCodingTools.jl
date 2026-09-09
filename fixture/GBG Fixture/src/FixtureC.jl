"""
    FixtureC

The options record and its display. The module is a map:

- [`Options`](@ref) — the record of a run's settings.
- [`describe`](@ref) — the one-line description of a record.
"""
module FixtureC

export Options, describe

"""
    Options(; tolerance = 1e-8, iterations = 100)

The settings of a run. The fields are:

- `tolerance` — the convergence tolerance.
- `iterations` — the iteration ceiling.

The arguments of the constructor are the two fields, as keywords.
"""
struct Options
    tolerance::Float64
    iterations::Int
end
Options(; tolerance::Real = 1e-8, iterations::Integer = 100) = Options(Float64(tolerance), Int(iterations))

"""
    describe(options) -> String

The one-line description of an [`Options`](@ref) record, tolerance first. The argument `options` is the
record. Returns the string.
"""
describe(options::Options) = "tolerance $(options.tolerance), at most $(options.iterations) iterations"

"""
    _clamp_iterations(n) -> Int

The iteration ceiling clamped to at least one. The argument `n` is the requested ceiling. Returns the
clamped value.
"""
_clamp_iterations(n::Integer) = max(n, 1)

end # module FixtureC
