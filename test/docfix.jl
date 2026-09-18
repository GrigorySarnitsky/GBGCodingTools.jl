# test/docfix.jl — the one verb that commits, and what it refuses to commit
# (docs/ARCHITECTURE.md §4.3 step 2).
#
# The guard is tested in test/guard.jl; what is tested here is that the VERB acts on it — that a code
# change leaves the repository exactly as it found it, rather than being reported and committed anyway.
# A session that committed first and asked afterwards would already have pushed what it was not allowed
# to touch.
using Test, GBGCodingTools
include("helpers.jl")

const DF = G.Docfix

const CONFIG = """
Config(package = "Sample", tool = :dev, normative = ["docs/SPEC.md"])
"""

const SOURCE = """
module Sample

\"\"\"
    measure(u)

The mean of `u`.
\"\"\"
measure(u) = sum(u) / length(u)

end
"""

function sample_repo()
    dir = mktempdir(; cleanup = true)
    mkpath(joinpath(dir, ".gbg")); mkpath(joinpath(dir, "src")); mkpath(joinpath(dir, "docs", "src"))
    write(joinpath(dir, ".gbg", "config.jl"), CONFIG)
    write(joinpath(dir, "src", "Sample.jl"), SOURCE)
    write(joinpath(dir, "docs", "src", "guide.md"), "# Guide\n\nOne sentence.\n")
    write(joinpath(dir, "docs", "SPEC.md"), "# Spec\n\nThe contract.\n")
    # The repository carries its own identity, in its own config. Passing `-c user.name=…` covers only
    # the commit made HERE; the one the VERB makes is a child process of its own, and with no identity in
    # the repository it fell back to whatever the machine had globally. So this passed on a developer's
    # machine and failed on CI, where there is none — three tests, the whole first testset, on the
    # v2.0.0-rc.2 tag. A real package always has an identity; the fixture now does too.
    for args in (("init", "-q"), ("config", "user.name", "t"), ("config", "user.email", "t@t"),
                 ("add", "--all", "."), ("commit", "-q", "-m", "first"))
        run(setenv(`git -C $dir $args`, "HOME" => dir, "GIT_AUTHOR_NAME" => "t", "GIT_AUTHOR_EMAIL" => "t@t",
                   "GIT_COMMITTER_NAME" => "t", "GIT_COMMITTER_EMAIL" => "t@t", "PATH" => ENV["PATH"]))
    end
    return dir
end

head_count(dir) = parse(Int, strip(read(setenv(`git -C $dir rev-list --count HEAD`, "PATH" => ENV["PATH"]), String)))
dirty(dir) = !isempty(strip(read(setenv(`git -C $dir status --porcelain`, "PATH" => ENV["PATH"]), String)))

@testset "gbg docfix commit" begin
    @testset "a documentation change is committed" begin
        dir = sample_repo()
        before = head_count(dir)
        p = joinpath(dir, "src", "Sample.jl")
        write(p, replace(read(p, String), "The mean of `u`." => "The arithmetic mean of `u` over its grid."))
        write(joinpath(dir, "docs", "src", "guide.md"), "# Guide\n\nOne sentence, rewritten.\n")
        code = DF.commit(dir, "docs: reworded"; io = devnull)
        @test code == 0
        @test head_count(dir) == before + 1
        @test !dirty(dir)
    end

    @testset "a code change is refused, and the tree is left as it was" begin
        dir = sample_repo()
        before = head_count(dir)
        p = joinpath(dir, "src", "Sample.jl")
        write(p, replace(read(p, String), "sum(u) / length(u)" => "sum(u) / max(1, length(u))"))
        status_before = read(setenv(`git -C $dir status --porcelain`, "PATH" => ENV["PATH"]), String)
        code = DF.commit(dir, "docs: reworded"; io = devnull)
        @test code == 1
        @test head_count(dir) == before                                  # nothing was committed
        @test read(setenv(`git -C $dir status --porcelain`, "PATH" => ENV["PATH"]), String) == status_before
        @test occursin("max(1, length(u))", read(p, String))             # and the edit is still there to fix
    end

    @testset "one code file among documentation stops the whole commit" begin
        dir = sample_repo()
        before = head_count(dir)
        write(joinpath(dir, "docs", "src", "guide.md"), "# Guide\n\nRewritten.\n")
        write(joinpath(dir, "docs", "SPEC.md"), "# Spec\n\nThe contract, quietly amended.\n")
        @test DF.commit(dir, "docs: reworded"; io = devnull) == 1        # SPEC.md is normative
        @test head_count(dir) == before
    end

    @testset "a new file is code, however much prose it holds" begin
        dir = sample_repo()
        write(joinpath(dir, "docs", "src", "new.md"), "# New\n\nProse.\n")
        @test DF.commit(dir, "docs: a new page"; io = devnull) == 1
    end

    @testset "check says the same and changes nothing" begin
        dir = sample_repo()
        p = joinpath(dir, "src", "Sample.jl")
        write(p, replace(read(p, String), "sum(u) / length(u)" => "sum(u) / 2"))
        @test DF.check(dir; io = devnull) == 1
        @test dirty(dir)                                                  # untouched, still uncommitted
        @test DF.check(sample_repo(); io = devnull) == 2                  # nothing has changed at all
    end
end
