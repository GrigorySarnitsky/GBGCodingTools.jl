# test/runtests.jl — GBGFixture. `Pkg.test()` is the gate: the package's own tests, the promoted
# witnesses, then the tool's closure gate.
using Test, GBGCodingTools
using GBGFixture

@testset "GBGFixture" begin
    @test twice(3) == 6
    g = Grid(4, 0.5)
    u = [1.0, 2.0, 3.0, 4.0]
    @test scale(u, 2) == [2.0, 4.0, 6.0, 8.0]
    d = similar(u); scale!(d, u, 0.5)
    @test d == u ./ 2
    @test mean_value(u) == 2.5
    @test total_energy(u, g) == 0.5 * 0.5 * sum(abs2, u)
    @test describe(Options(; tolerance = 1e-6, iterations = 10)) == "tolerance 1.0e-6, at most 10 iterations"
    GBGCodingTools.TestHarness.@alloc_below 1 scale!(d, u, 2.0)     # the true zero: strictly below one byte
end

GBGCodingTools.TestHarness.run_regressions(@__DIR__)
GBGCodingTools.TestHarness.gate()
