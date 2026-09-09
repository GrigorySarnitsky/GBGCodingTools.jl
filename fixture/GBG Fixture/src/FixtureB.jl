"""
    FixtureB

The reductions of a value field over a grid. The module is a map:

- [`mean_value`](@ref) — the arithmetic mean of a field.
- [`total_energy`](@ref) — the discrete energy of a field.
"""
module FixtureB

using ..FixtureA: Grid
export mean_value, total_energy

"""
    mean_value(u) -> Number

The arithmetic mean of the field `u` over its nodes: ``\\bar u = \\tfrac{1}{N} \\sum_{i=1}^{N} u_i``.
The argument `u` is the array of node values. Returns the mean.

Reference: J. W. Cooley, J. W. Tukey, [*An algorithm for the machine calculation of complex Fourier
series*](https://doi.org/10.1090/S0025-5718-1965-0178586-1), Mathematics of Computation 19 (1965).
"""
mean_value(u::AbstractVector) = sum(u) / length(u)

"""
    total_energy(u, grid) -> Number

The discrete energy of the field `u` on `grid`, the trapezoid-free sum ``E = \\tfrac{1}{2} h
\\sum_{i=1}^{N} u_i^2`` with ``h`` the grid spacing. The arguments are `u`, the array of node values, and
`grid`, the [`Grid`](@ref) it lives on (its `n` must equal the length of `u`). Returns the energy.
"""
function total_energy(u::AbstractVector, grid::Grid)
    length(u) == grid.n || throw(DimensionMismatch("the field has $(length(u)) values, the grid $(grid.n) nodes"))
    return grid.spacing * sum(abs2, u) / 2
end

end # module FixtureB
