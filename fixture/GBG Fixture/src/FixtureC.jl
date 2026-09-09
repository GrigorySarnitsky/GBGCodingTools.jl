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

The one-line description of an [`Options`](@ref) record, tolerance first, in the tabular convention of
Cooley & Tukey (1965). The argument `options` is the record. Returns the string.

# References

  * J. W. Cooley, J. W. Tukey, [*An algorithm for the machine calculation of complex Fourier series*](https://doi.org/10.1090/S0025-5718-1965-0178586-1), Mathematics of Computation 19 (1965)
"""
describe(options::Options) = "tolerance $(options.tolerance), at most $(options.iterations) iterations"

"""
    span(options) -> (lo, hi)

The iteration bounds of an [`Options`](@ref) record; internal, so it needs no page home. The argument
`options` is the record. Returns the pair.

Two arguments and a returned tuple: RULE.DOC.ARGS_FORM binds fewer than three in running prose, and
SCAN.ARGS_FORM must read the parameter list as the parenthesis that closes the first one — a parser
that stopped at the last `)` counted the return tuple as three more parameters and demanded bullets.
"""
span(options::Options) = (1, options.iterations)

"""
    _clamp_iterations(n) -> Int

The iteration ceiling clamped to at least one. The argument `n` is the requested ceiling. Returns the
clamped value.
"""
_clamp_iterations(n::Integer) = max(n, 1)

end # module FixtureC
