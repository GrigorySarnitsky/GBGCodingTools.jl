# GBGFixture

`GBGFixture` is the toy consumer of [`GBGCodingTools`](https://grigorysarnitsky.github.io/GBGCodingTools.jl/): a grid, a value field over it, two reductions and
an options record. Its documentation is written to the shared rubric so the tool can be tested against
a clean corpus. The grid is a [`Grid`](@ref); values are scaled with [`scale!`](@ref) and reduced with
[`mean_value`](@ref) and [`total_energy`](@ref); a run's settings are an [`Options`](@ref) record.

```@docs
GBGFixture
```
