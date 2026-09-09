using Test, GBGCodingTools
include("helpers.jl")

@testset "witness runner" begin
    dir = joinpath(TMP, "witnesses"); mkpath(dir)
    project = joinpath(FIXTURE, "test")
    write(joinpath(dir, "fails.jl"), "using Test, GBGFixture\n@testset \"twice is wrong\" begin\n  @test twice(2) == 5\nend\n")
    write(joinpath(dir, "passes.jl"), "using Test, GBGFixture\n@testset \"twice\" begin\n  @test twice(2) == 4\nend\n")
    write(joinpath(dir, "broken.jl"), "using Test, GBGFixture\n@testset \"throws outside\" begin\n  error(\"boom\")\nend\n")
    write(joinpath(dir, "zero.jl"), "using Test, GBGFixture\n@testset \"asserts nothing\" begin\nend\n")
    write(joinpath(dir, "refused.jl"), "using Test, GBGFixture\ninclude(\"helper.jl\")\n@testset \"x\" begin\n  @test true\nend\n")
    write(joinpath(dir, "blocked.jl"), "# blocked: needs a GPU this host lacks\nusing Test, GBGFixture\n@testset \"gpu\" begin\n  error(\"no device\")\nend\n")
    code, results = G.Witnesses.run(dir; expect = :fail, package = "GBGFixture", project, io = devnull)
    st = Dict(r.name => r.status for r in results)
    @test st["fails.jl"] == :fail
    @test st["passes.jl"] == :pass
    @test st["broken.jl"] == :broken
    @test st["zero.jl"] == :broken
    @test st["refused.jl"] == :refused
    @test st["blocked.jl"] == :blocked
    @test code == 2                                             # a refused witness makes the run exit 2
    rm(joinpath(dir, "refused.jl"))
    code, _ = G.Witnesses.run(dir; expect = :fail, package = "GBGFixture", project, names = ["fails"], io = devnull)
    @test code == 0
    code, _ = G.Witnesses.run(dir; expect = :pass, package = "GBGFixture", project, names = ["fails"], io = devnull)
    @test code == 1                                             # UNFIXED
    code, _ = G.Witnesses.run(joinpath(TMP, "no-such-dir"); expect = :fail, package = "GBGFixture", project, io = devnull)
    @test code == 2                                             # absence is not a success
end
