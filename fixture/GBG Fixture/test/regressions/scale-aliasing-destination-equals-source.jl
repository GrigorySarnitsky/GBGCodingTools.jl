# Witness promoted from the fixture's own hunt (the seed of the regression suite): `scale!` with the
# destination aliasing the source scaled every entry twice before decision 2 fixed the loop order.
# Defect observed 2026-09-09; fixed in the same commit that promoted this file.
using Test, GBGFixture
@testset "scale! with destination === source scales once" begin
    u = [1.0, 2.0, 3.0]
    scale!(u, u, 3.0)
    @test u == [3.0, 6.0, 9.0]
end
