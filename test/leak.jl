# test/leak.jl — Phase 9's gate: the leak scan, with the pinned Gitleaks, over a planted repository.
#
#     julia --project test/leak.jl
#
# It is not in `Pkg.test()` and must not be: it runs Gitleaks, which CI does not install, and
# `gbg install --gitleaks` reaches the network. What runs without Gitleaks is test/publication.jl, in the
# suite. Here the three places a careless scan misses are planted — a credential in a file an old commit
# held and a later one deleted, a credential in a commit message, an address in a commit's author field —
# and each must be reported, no line printed may hold what was planted, and the repository is left as it was.
using Test, GBGCodingTools
const G = GBGCodingTools

isfile(G.Publication.gitleaks()) || error("Gitleaks $(G.Publication.GITLEAKS.version) is not installed: run `gbg install --gitleaks`")

const TOKEN = "ghp_" * "0123456789abcdefghijABCDEFGHIJ012345"         # a GitHub token's shape, planted
const ADDRESS = "someone@" * "private.example"

@testset "the leak scan finds what a careless scan misses, and prints none of it" begin
    dir = mktempdir(; cleanup = true)
    env = ["GIT_CONFIG_GLOBAL=/dev/null", "HOME=$dir", "GIT_AUTHOR_NAME=someone", "GIT_AUTHOR_EMAIL=$ADDRESS",
           "GIT_COMMITTER_NAME=someone", "GIT_COMMITTER_EMAIL=$ADDRESS"]
    g(args...) = run(pipeline(setenv(`git -C $dir $args`, env); stdout = devnull, stderr = devnull))
    g("init", "-q", "-b", "master")
    write(joinpath(dir, "old.toml"), "key = \"$TOKEN\"\n"); g("add", "old.toml"); g("commit", "-q", "-m", "one")
    g("rm", "-q", "old.toml"); g("commit", "-q", "-m", "two: the key was $TOKEN")
    write(joinpath(dir, "notes.md"), "Kept at /home/someone/Dropbox/notes.\n"); g("add", "notes.md"); g("commit", "-q", "-m", "three")
    before = read(setenv(`git -C $dir status --porcelain --ignored`, env), String)

    cfg = G.Model.Config(package = "Planted", tool = :dev)
    found = G.Publication.scan(dir, cfg).findings
    has(rule, place) = any(f -> f.rule === Symbol(rule) && occursin(place, f.place), found)
    @test has("RULE.LEAK.CREDENTIAL", "old.toml:1")                   # in a file deleted since
    @test has("RULE.LEAK.CREDENTIAL", "the message of commit")         # in a commit message
    @test has("RULE.LEAK.EMAIL", "the author or committer")            # in the author field
    @test has("RULE.LEAK.HOME_PATH", "notes.md:1") && has("RULE.LEAK.SYNCED_PATH", "notes.md:1")

    out = IOBuffer()
    @test G.Leak.scan(dir; io = out) == 1
    printed = String(take!(out))
    @test !occursin(TOKEN, printed) && !occursin(ADDRESS, printed) && !occursin("/home/someone", printed)
    @test all(l -> startswith(l, G.Leak.MARK), filter(!isempty, split(printed, '\n')))
    @test read(setenv(`git -C $dir status --porcelain --ignored`, env), String) == before   # nothing written

    # an approved address and a switched-off rule are not findings
    ok = G.Model.Config(package = "Planted", tool = :dev, leak_emails = [ADDRESS],
                        switches = [G.Model.Switch(target = Symbol("RULE.LEAK.SYNCED_PATH"), reason = "planted")])
    again = G.Publication.scan(dir, ok).findings
    @test !any(f -> f.rule === Symbol("RULE.LEAK.EMAIL"), again)
    @test !any(f -> f.rule === Symbol("RULE.LEAK.SYNCED_PATH"), again)
end
