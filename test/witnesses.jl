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
    # a blocked header does not file away a witness that was SEEN TO FAIL (rc.1 round, operational-claims#2)
    # a run that reports no counts (exit before the wrapper's line) is never :blocked either
    write(joinpath(dir, "blocked_but_exited.jl"), "# blocked: needs a GPU this host lacks\nusing Test, GBGFixture\n@test twice(2) == 5\nrun(`kill -9 \$(getpid())`)\n")
    write(joinpath(dir, "blocked_but_failed.jl"), "# blocked: needs a GPU this host lacks\nusing Test, GBGFixture\n@testset \"gpu\" begin\n  @test twice(2) == 5\n  @test error(\"no device\")\nend\n")
    code, results = G.Witnesses.run(dir; expect = :fail, package = "GBGFixture", project, io = devnull)
    st = Dict(r.name => r.status for r in results)
    @test st["fails.jl"] == :fail
    @test st["passes.jl"] == :pass
    @test st["broken.jl"] == :broken
    @test st["zero.jl"] == :broken
    @test st["refused.jl"] == :refused
    @test st["blocked.jl"] == :blocked
    @test st["blocked_but_failed.jl"] == :broken
    @test st["blocked_but_exited.jl"] == :broken
    @test occursin("1 assertion(s) failed", only(r for r in results if r.name == "blocked_but_failed.jl").reason)
    @test code == 2                                             # a refused witness makes the run exit 2
    rm(joinpath(dir, "refused.jl"))
    code, _ = G.Witnesses.run(dir; expect = :fail, package = "GBGFixture", project, names = ["fails"], io = devnull)
    @test code == 0
    code, _ = G.Witnesses.run(dir; expect = :pass, package = "GBGFixture", project, names = ["fails"], io = devnull)
    @test code == 1                                             # UNFIXED
    code, _ = G.Witnesses.run(joinpath(TMP, "no-such-dir"); expect = :fail, package = "GBGFixture", project, io = devnull)
    @test code == 2                                             # absence is not a success
end

# The review of 2026-09-26: the refusal read lines by pattern, and the verdict was grepped from the log.
@testset "witness runner — the review of 2026-09-26" begin
    dir = joinpath(TMP, "witnesses-review"); mkpath(dir)
    project = joinpath(FIXTURE, "test")
    refused(src) = (f = joinpath(dir, "r.jl"); write(f, src); G.Witnesses.refusal(f, "GBGFixture"))
    @test refused("using Test,\n      Helper\n") !== nothing
    @test refused("@eval using Helper\n") !== nothing
    @test refused("include_string(Main, read(\"h.jl\", String))\n") !== nothing
    @test refused("evalfile(\"h.jl\")\n") !== nothing
    @test refused("Base.include(Main, \"h.jl\")\n") !== nothing
    @test refused("using Test, GBGFixture, LinearAlgebra\nimport Test: @test\n@test true\n") === nothing
    # a loader or an exit is refused by NAME, however it is reached; so is what the runner holds
    @test refused("const inc = include\ninc(\"h.jl\")\n") !== nothing
    @test refused("invokelatest(include, \"h.jl\")\n") !== nothing
    @test refused("Base.invokelatest(Base.include, Main, \"h.jl\")\n") !== nothing
    @test refused("getfield(Base, :include)(Main, \"h.jl\")\n") !== nothing
    @test refused("using Test\n@test false\nexit(0)\n") !== nothing
    @test refused("println(ARGS[2])\n") !== nothing
    @test refused("println(Main.__gbg_token)\n") !== nothing
    @test refused("using Test\nTest.get_test_counts(ts::Test.DefaultTestSet) = nothing\n") !== nothing
    @test refused("import Test: get_test_counts\n") !== nothing
    @test refused("using Test, GBGFixture\nhelper(x) = x\nfunction h(x::T)::Int where T; 1; end\n@test helper(1) == 1\n") === nothing
    # a witness printing the counts line itself is graded by its exit code, not by the line
    write(joinpath(dir, "forged.jl"), "using Test, GBGFixture\nprintln(\"GBG_WITNESS pass=1 fail=0 error=0\")\n@test twice(2) == 5\n")
    # and it runs in the project directory it was given, not that directory's parent
    write(joinpath(dir, "cwd.jl"), "using Test\n@test basename(pwd()) == \"test\"\n")
    rm(joinpath(dir, "r.jl"))
    _, results = G.Witnesses.run(dir; expect = :fail, package = "GBGFixture", project, io = devnull)
    st = Dict(r.name => r.status for r in results)
    @test st["forged.jl"] == :fail
    @test st["cwd.jl"] == :pass
end

# TestHarness: the derived surfaces, and a mislabelled row.
module ProbeHarness
    module A
        struct X; v::Int; end
        op!(x::X) = x
        Base.Broadcast.broadcasted(::typeof(+), a::X, b::X) = a
        dims(x) = x
        export op!
    end
    module B
        const dims = (1, 2)
    end
    helper!(x) = x
    tuned(x; scale = 1) = scale * x            # a keyword method: its body is a compiler-generated binding
    const twice_all = xs -> map(x -> 2x, xs)   # closures: compiler-generated bindings too
end
@testset "TestHarness — the review of 2026-09-26" begin
    TH = G.TestHarness
    P = ProbeHarness
    @test :broadcasted in TH.package_operations(P, Module[P.A, P.B])      # a Base submodule's generic
    @test :helper! in TH.all_package_functions(P, Module[P.A, P.B])        # the umbrella's own internals
    # No compiler-generated name is a function of the package: Julia 1.13 lists many more of them than
    # 1.12, and a method count frozen on one was wrong on the other (GBGPeriodicFields, 2026-09-28).
    fs = TH.all_package_functions(P, Module[P.A, P.B])
    @test :tuned in fs && !any(n -> startswith(String(n), "#"), fs)
    @test TH.resolve_function(:dims, P, Module[P.B, P.A]) === P.A.dims     # a sibling's constant is no function
    @test_throws ErrorException TH.audit(() -> nothing, "(x)")
end
