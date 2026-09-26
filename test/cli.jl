# test/cli.jl — the entry point's exit contract, and the two engines the command line keeps for itself:
# git's tree hash behind `gbg self verify`, and the name resolution the test harness does.
#
# The exit contract stood in test/coverage.jl until Phase 5, beside tests of verbs that no longer exist;
# the tree hash in test/treehash.jl, for a module of its own that is one function of `Self.jl` now.
using Test, GBGCodingTools
include("helpers.jl")

@testset "the exit contract of main()" begin
    root = fixture_copy("main-exit")
    cd(root) do
        redirect_stderr(devnull) do
            @test G.main(["no-such-verb"]) == 2                            # an unknown verb is not a crash
            @test G.main(String[]) == 2                                    # no verb at all
            @test G.main(["docfix"]) == 2                                  # a noun missing its verb
            @test G.main(["--help"]) == 0
        end
        @test G.main(["sync", "--check"]) == 0                             # 0 clean
        # Every exit code is the verb's own, passed through unchanged: 1 is a finding, and an exception
        # escaping a verb is 3, printed with its backtrace so a crash is never read as a finding.
        G.VERBS["__finds"] = args -> 1
        G.VERBS["__crashes"] = args -> error("boom")
        try
            @test G.main(["__finds"]) == 1
            redirect_stderr(devnull) do
                @test G.main(["__crashes"]) == 3
            end
        finally
            delete!(G.VERBS, "__finds"); delete!(G.VERBS, "__crashes")
        end
        # A consumer's config that cannot be read is exit 2 for ANY verb, caught once in `main`. The
        # rebuilt reader's error reached the crash arm — exit 3 with a backtrace — where the contract
        # promises 2 (found in review, 2026-09-23).
        cj = joinpath(root, ".gbg", "config.jl"); had = read(cj, String)
        write(cj, "Config(package = f())\n")                               # a call, not data
        try
            redirect_stderr(devnull) do
                @test G.main(["docfix", "check"]) == 2
            end
        finally
            write(cj, had)
        end
    end
    @test length(G.VERBS) >= 12
end

# The tree hash reproduces git's tree id, empty directories included in the comparison: git tracks none,
# so a tree with an empty subdirectory must hash as if it were absent (rc.1 round, src#1 / operational-claims#1).
@testset "tree hash vs git write-tree" begin
    dir = joinpath(TMP, "treehash"); mkpath(joinpath(dir, "sub")); mkpath(joinpath(dir, "empty"))
    write(joinpath(dir, "a.txt"), "alpha\n"); write(joinpath(dir, "sub", "b.txt"), "beta\n")
    mkpath(joinpath(dir, "sub", "deeper-empty"))
    git(args...) = strip(read(setenv(`git -C $dir $args`, "GIT_AUTHOR_NAME" => "t", "GIT_AUTHOR_EMAIL" => "t@t",
                                     "GIT_COMMITTER_NAME" => "t", "GIT_COMMITTER_EMAIL" => "t@t"), String))
    git("init", "-q"); git("add", "-A")
    @test G.tree_hash(dir) == git("write-tree")
    @test G.blob_hash(joinpath(dir, "a.txt")) == git("hash-object", "a.txt")
end

# RULE.TEST.BOTH_DIRECTIONS. A package function wins its own name against a Base export of the same
# name: `Git.run` and `Git.diff` collide with `Base.run` and `Base.diff`. Ordering the externals last
# does NOT achieve this — `isdefined(pkg, :run)` is true through the implicit `using Base` — so the
# module that OWNS the name is searched first, and this test fails if that ordering is undone.
@testset "a package function wins its own name" begin
    mods = Module[G.Git, G.Wire, G.Render, G.TestHarness]              # the tool itself: it has the collisions
    for n in (:run, :diff, :report)
        f = G.TestHarness.resolve_function(n, G, mods)
        @test f !== nothing && parentmodule(f) !== Base                 # not the Base generic
    end
    @test parentmodule(G.TestHarness.resolve_function(:run, G, mods)) === G.Git
    @test parentmodule(G.TestHarness.resolve_function(:report, G, mods)) === G.Render
end
