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

# A package releases itself: run in a package, the verb reads that package, with its own build and test
# commands; until 2026-10-21 it read the tool's own checkout wherever it was run.
@testset "run in a package, the release is the package's" begin
    root, gg = repo("0.1.0")
    out = mktemp() do path, io
        redirect_stdout(io) do
            cd(root) do
                @test G.cmd_release(["0.2.0"]) == 2
            end
        end
        close(io); read(path, String)
    end
    @test occursin("Project.toml version is 0.1.0, the release is 0.2.0", out)   # the package's, not the tool's
    @test occursin("no `## 0.2.0 — <date>` entry", out)
    # the gates run what the package's config names, with the `julia` running here
    j = G.gate_command(["julia", "--project=docs", "docs/make.jl"], `-e 1`)
    @test j.exec[end-1:end] == ["--project=docs", "docs/make.jl"] && occursin("julia", j.exec[1])
    @test G.gate_command(String[], `-e 1`).exec[end-1:end] == ["-e", "1"]
    @test G.gate_command(["make", "docs"], `-e 1`).exec == ["make", "docs"]
end

# A final release is recorded in the fleet's registry; shown on a registry and an origin made here, never
# the real ones. The identity is the test's own: a clean checkout on CI has none, and a registry commits.
@testset "a release is recorded in the registry, once" begin
    withenv("GIT_AUTHOR_NAME" => "t", "GIT_AUTHOR_EMAIL" => "t@t", "GIT_COMMITTER_NAME" => "t", "GIT_COMMITTER_EMAIL" => "t@t") do
        regdir = mktempdir(; cleanup = true)
        bare, origin, work = joinpath(regdir, "registry.git"), joinpath(regdir, "origin.git"), joinpath(regdir, "work")
        quiet(c) = Base.run(pipeline(c; stdout = devnull, stderr = devnull))
        G.LocalRegistry.create_registry(work, bare; description = "a test registry", push = false)
        quiet(`git init -q --bare $bare`); quiet(`git init -q --bare $origin`)
        quiet(`git -C $work push -q $bare HEAD:master`)
        root, gg = repo("0.1.0")
        open(joinpath(root, "Project.toml"), "a") do io; println(io, "uuid = \"8e7c1a5b-0f3d-4c2e-9a1b-2c3d4e5f6a7b\""); end
        mkpath(joinpath(root, "src")); write(joinpath(root, "src", "Sample.jl"), "module Sample end\n")
        gg("add", "--all", "."); gg("commit", "-q", "-m", "a package"); gg("remote", "add", "origin", origin)
        gg("push", "-q", "origin", "master")
        io = IOBuffer()
        said() = String(take!(io))
        @test G.register(root; io, registry = bare) == 2                  # not tagged: nothing to record
        @test occursin("not tagged v0.1.0", said())
        gg("tag", "v0.1.0-rc.1")                                           # a prerelease's tag is not the release's
        @test G.register(root; io, registry = bare) == 2
        said()
        gg("tag", "v0.1.0")                                                # tagged here, never pushed
        @test G.register(root; io, registry = bare) == 2
        @test occursin("not on `origin`", said())
        gg("push", "-q", "origin", "v0.1.0")
        @test G.register(root; io, registry = bare) == 0
        @test occursin("recorded in the registry", said())
        @test G.register(root; io, registry = bare) == 0                  # once is enough
        @test occursin("in the registry already", said())
        check = joinpath(regdir, "check")
        quiet(`git clone -q $bare $check`)
        @test haskey(G.TOML.parsefile(joinpath(check, "S", "Sample", "Versions.toml")), "0.1.0")
        # the same version at another tree is refused, never recorded over
        write(joinpath(root, "src", "Sample.jl"), "module Sample\nend\n"); gg("commit", "-q", "-am", "another tree")
        gg("tag", "-d", "v0.1.0"); gg("push", "-q", "origin", ":v0.1.0"); gg("tag", "v0.1.0"); gg("push", "-q", "origin", "master", "v0.1.0")
        @test G.register(root; io, registry = bare) == 2
        @test occursin("at another tree", said())
        # a dependency no registry knows would make the package uninstallable by name
        open(joinpath(root, "Project.toml"), "w") do f
            print(f, "name = \"Sample\"\nuuid = \"8e7c1a5b-0f3d-4c2e-9a1b-2c3d4e5f6a7b\"\nversion = \"0.2.0\"\n\n[deps]\nNobodysDep = \"11111111-2222-3333-4444-555555555555\"\n")
        end
        gg("commit", "-q", "-am", "0.2.0"); gg("tag", "v0.2.0"); gg("push", "-q", "origin", "master", "v0.2.0")
        @test G.register(root; io, registry = bare) == 2
        @test occursin("no registry knows NobodysDep", said())
    end
end

# The registry records a URL anyone can clone: GitHub in every spelling, and never a credential.
@testset "the URL a release is recorded under" begin
    for u in ("git@github.com:O/R.git", "git@github.com:O/R", "git@github.com:O/R.git/", "ssh://git@github.com/O/R.git",
              "https://github.com/O/R", "https://github.com/O/R/", "https://github.com/O/R.git", "http://github.com/O/R",
              "https://tok:x-oauth@github.com/O/R", "ssh://git@github.com:22/O/R.git", "git+ssh://git@github.com/O/R.git",
              "https://www.github.com/O/R", "https://GitHub.com/O/R", "github.com:O/R.git")
        @test G.public_url(u) == "https://github.com/O/R.git"
    end
    @test G.public_url("https://user:pw@example.org/R.git/") == "https://example.org/R.git"
    @test G.public_url("/a/local/path") == "/a/local/path"
    @test G.public_url("  ") === nothing
    @test G.public_url("git@github-work:O/R.git") === nothing           # an ssh alias only its owner can reach
    @test G.public_url("git@example.org:O/R.git") === nothing
end
