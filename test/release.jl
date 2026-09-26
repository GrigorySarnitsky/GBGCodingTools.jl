# test/release.jl — what `gbg release` refuses, and where it reads the branch from.
#
# A tag is permanent, so a test must never reach `git tag`: everything testable is in the refusal list,
# which reads the tree and writes nothing. That separation exists because a defect lived past nine
# releases in the part no test could reach (2026-09-12 work queue).
using Test, GBGCodingTools
include("helpers.jl")

"""A git repository with a config, a changelog entry and one commit. Returns its root and a `git`."""
function repo(entry::AbstractString; settings = G.Model.Setting[])
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".gbg"))
    lines = ["""Config(package = "Sample", tool = :dev"""]
    isempty(settings) || push!(lines, """, settings = [Setting(rule = Symbol("RULE.GIT.BRANCH"), name = :branch, value = "$(settings[1].value)")]""")
    push!(lines, ")")
    write(joinpath(root, ".gbg", "config.jl"), join(lines))
    write(joinpath(root, "CHANGELOG.md"), "# Changelog\n\n## $entry — 2026-09-20\n\nMAJOR.\n")
    write(joinpath(root, "Project.toml"), "name = \"Sample\"\nversion = \"$entry\"\n")
    gg(a...) = Base.run(pipeline(setenv(Cmd(["git", "-C", root, a...]); dir = root);
                                 stdout = devnull, stderr = devnull))
    gg("init", "-q", "--initial-branch=master"); gg("config", "user.name", "t"); gg("config", "user.email", "t@t")
    gg("add", "--all", "."); gg("commit", "-q", "-m", "first")
    return root, gg
end

# `--counts` prints what still holds v2.0.0 — the conversion ratchet's outstanding count — and refuses
# nothing; the Phase 5 gate reads the printed number.
@testset "release --counts prints the outstanding conversion count and nothing else" begin
    io = IOBuffer()
    @test G.counts(; io) == 0
    @test strip(String(take!(io))) == "0"
    @test G.main(["release", "--counts"]) == 0
end

@testset "what a release refuses" begin

    # The branch is a RULE PARAMETER, not a constant of the verb and no longer a field of a config file
    # this package stopped reading: the rule and the verb that enforces it read one value.
    @testset "the branch comes from the rulebook" begin
        cfg = G.Model.Config(package = "Sample", tool = :dev)
        @test G.Catalogue.branch_of(cfg) == "master"
        named = G.Model.Config(package = "Sample", tool = :dev,
                               settings = [G.Model.Setting(rule = Symbol("RULE.GIT.BRANCH"), name = :branch,
                                                           value = "main")])
        @test G.Catalogue.branch_of(named) == "main"
        rule = only(r for r in G.Catalogue.RULES if r.id === Symbol("RULE.GIT.BRANCH"))
        @test only(rule.parameters).name === :branch          # and the rule says so itself
    end

    @testset "a clean master with its changelog entry is not refused for any of these" begin
        root, _ = repo("2.0.0")
        cfg = G.ConfigIO.read_config(root)
        fails = G.release_fails(cfg, root, "2.0.0", "2.0.0", false)
        @test !any(f -> occursin("tree is not clean", f), fails)
        @test !any(f -> occursin("on branch", f), fails)
        @test !any(f -> occursin("CHANGELOG", f), fails)
    end

    @testset "a dirty tree, a wrong branch and a missing entry are each named" begin
        root, gg = repo("2.0.0")
        cfg = G.ConfigIO.read_config(root)
        write(joinpath(root, "CHANGELOG.md"), "# Changelog\n")          # entry gone, tree dirty
        fails = G.release_fails(cfg, root, "2.0.0", "2.0.0", false)
        @test any(f -> occursin("tree is not clean", f), fails)
        @test any(f -> occursin("no `## 2.0.0 — <date>` entry", f), fails)

        gg("checkout", "-q", "-b", "sidetrack")
        @test any(f -> occursin("on branch sidetrack, not master", f),
                  G.release_fails(cfg, root, "2.0.0", "2.0.0", false))
    end

    # A package that renamed its branch is not refused for working on it.
    @testset "a package that named its own branch is held to that one" begin
        root, gg = repo("2.0.0"; settings = [(value = "main",)])
        cfg = G.ConfigIO.read_config(root)
        @test G.Catalogue.branch_of(cfg) == "main"
        @test any(f -> occursin("on branch master, not main", f),
                  G.release_fails(cfg, root, "2.0.0", "2.0.0", false))
        gg("checkout", "-q", "-b", "main")
        @test !any(f -> occursin("on branch", f), G.release_fails(cfg, root, "2.0.0", "2.0.0", false))
    end
end

# The code review of 2026-09-26: a refused tag or push was one line with no cause, because every git
# call discarded stderr. The write commands now say what git said. Shown on a throwaway repository,
# with a tag that already exists — never on this one.
@testset "a git command that writes reports git's reason" begin
    root, gg = repo("2.0.0")
    gg("tag", "v2.0.0")
    ok, said = G.Git.said(root, "tag", "v2.0.0")
    @test !ok && occursin("already exists", said)
    ok, said = G.Git.said(root, "tag", "v2.0.1")
    @test ok
end
