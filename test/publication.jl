# test/publication.jl — the leak scan's parts that run without Gitleaks, so CI runs them: the rendered
# configuration, and the reader of what a repository publishes besides its files. The scan itself, with
# Gitleaks, is the Phase 9 gate's: test/leak.jl.
using Test, GBGCodingTools, TOML
const G = GBGCodingTools
const P = G.Publication

@testset "the leak scan's configuration and metadata reader" begin
    cfg = G.Model.Config(package = "Example", tool = :dev, leak_emails = ["owner@example.org"], leak_terms = ["Examplehost"])
    conf = TOML.parse(P.config_toml(cfg))
    ids = Set(r["id"] for r in conf["rules"])
    # every rule with a pattern, and the credential rule left to Gitleaks' own pass
    @test ids == Set(String(r.id) for r in G.Catalogue.Leaks.RULES if r.id !== Symbol("RULE.LEAK.CREDENTIAL"))
    @test !haskey(conf, "extend")                                  # its own pass: no default allowlist
    email = only(r for r in conf["rules"] if r["id"] == "RULE.LEAK.EMAIL")
    @test any(occursin("owner@example", a) for a in only(email["allowlists"])["regexes"])
    # a config naming no private word renders no rule for it
    @test !occursin("RULE.LEAK.TERM", P.config_toml(G.Model.Config(package = "Example", tool = :dev)))

    # The metadata: names, messages and people, each line with the place it came from.
    dir = mktempdir(; cleanup = true)
    env = ["GIT_CONFIG_GLOBAL=/dev/null", "GIT_AUTHOR_NAME=a", "GIT_AUTHOR_EMAIL=a@one.example",
           "GIT_COMMITTER_NAME=c", "GIT_COMMITTER_EMAIL=c@two.example", "HOME=$dir"]
    g(args...) = run(pipeline(setenv(`git -C $dir $args`, env); stdout = devnull, stderr = devnull))
    g("init", "-q", "-b", "master"); g("commit", "-q", "--allow-empty", "-m", "first line\n\nsecond line")
    g("commit", "-q", "--allow-empty", "-m", "another"); g("tag", "-a", "v1", "-m", "a tag's message")
    text, places = P.metadata(dir)
    lines = split(text, '\n')
    @test length(lines) == length(places)
    at(s) = places[findfirst(==(s), lines)]
    @test startswith(at("second line"), "the message of commit ")
    @test at("a tag's message") == "the message of tag v1"
    @test at("master") == "the name of master"
    @test occursin("of 2 commit(s)", at("a <a@one.example>"))          # each person once, with the count
    @test count(==("a <a@one.example>"), lines) == 1
end
