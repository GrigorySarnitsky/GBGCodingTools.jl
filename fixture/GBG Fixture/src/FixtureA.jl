"""
    FixtureA

The grid and the operations on values over it. The module is a map:

- [`Grid`](@ref) — a uniform one-dimensional grid.
- [`twice`](@ref) — the doubling of a value.
- [`scale!`](@ref) — the in-place scaling of a value field; [`scale`](@ref) is its allocating form.
"""
module FixtureA

export Grid, twice, scale!, scale

"""
    Grid(n, spacing)

A uniform one-dimensional grid of `n` nodes at a constant spacing.

The arguments of the constructor are the two fields.

# Fields

- `n` — the number of nodes.
- `spacing` — the distance between neighbouring nodes.
"""
struct Grid
    n::Int
    spacing::Float64
end

"""
    twice(x) -> typeof(x)

The double of a number: ``2x``. The argument `x` is the number. Returns the double.
"""
twice(x::Number) = 2x

"""
    scale!(destination, source, α) -> destination

Scales a value field in place: every entry of `source` multiplied by the scalar ``\\alpha`` and written
into `destination`, which may alias `source`.

# Arguments

- `destination` — the array written; the same length as `source`.
- `source` — the array read.
- `α` — the scalar factor.

The operation is ``d_i = \\alpha s_i`` for every node ``i``. Returns `destination`.
"""
function scale!(destination::AbstractVector, source::AbstractVector, α::Number)
    length(destination) == length(source) || throw(DimensionMismatch("destination and source differ in length"))
    @inbounds for i in eachindex(source)
        destination[i] = α * source[i]
    end
    return destination
end

"""
    scale(source, α) -> Vector

Allocating form of [`scale!`](@ref): allocate the result and return it. The arguments are `source`,
the array read, and `α`, the scalar factor. Returns the scaled copy.
"""
scale(source::AbstractVector, α::Number) = scale!(similar(source, promote_type(eltype(source), typeof(α))), source, α)

end # module FixtureA
