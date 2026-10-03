# test/publication.jl — the leak scan's parts that run without Gitleaks, so CI runs them: the rendered
# configuration, and the reader of what a repository publishes besides its files. The scan itself, with
# Gitleaks, is the Phase 9 gate's: test/leak.jl.
using Test, GBGCodingTools, TOML
const G = GBGCodingTools
const P = G.Publication

@testset "the leak scan's configuration and metadata reader" begin
    cfg = G.Model.Config(package = "Example", tool = :dev, leak_emails = ["owner@mailbox.zz"], leak_terms = ["Examplehost"])
    conf = TOML.parse(P.config_toml(cfg))
    ids = Set(r["id"] for r in conf["rules"])
    # every rule with a text pattern: the credential rule is Gitleaks' own pass, and the rule of paths
    # alone is applied by `scan` to every path any commit held
    @test ids == Set(String(r.id) for r in G.Catalogue.Leaks.RULES
                     if !(r.id in (Symbol("RULE.LEAK.CREDENTIAL"), Symbol("RULE.LEAK.NEVER_PUBLISHED"))))
    @test !haskey(conf, "extend")                                  # its own pass: no default allowlist
    email = only(r for r in conf["rules"] if r["id"] == "RULE.LEAK.EMAIL")
    @test any(occursin("owner@mailbox", a) for a in only(email["allowlists"])["regexes"])
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
    @test startswith(at("a tag's message"), "the message of a tag object ")
    # a place names a commit or an object, never the text read, so a leak in a ref's name is not printed
    @test startswith(at("refs/heads/master"), "the name of a ref pointing at ")
    @test !any(p -> occursin("master", p) || occursin("v1", p), places)
    @test startswith(at("a <a@one.example>"), "an author or committer, first in commit ")
    @test count(==("a <a@one.example>"), lines) == 1                  # each person once
    @test all(p -> !occursin('\n', p), places)
end

@testset "a finding of a leak scan is refused by every writer of a tracked record" begin
    Gd = G.Engine.Guard
    @test Gd.refuse_publication("an ordinary line", "a record") === nothing
    @test_throws Gd.PublicationRefused Gd.refuse_publication("$(Gd.LEAK_MARK)   RULE.LEAK.EMAIL  commit 1234abcd a.md:1", "a record")
    @test G.Leak.MARK == Gd.LEAK_MARK
    # through the question store, the writer a session reaches most easily
    dir = mktempdir(; cleanup = true)
    cfg = G.Model.Config(package = "Example", tool = :dev)
    q = G.Model.Question(id = "q-leak", decision = "Is this a leak?",
                         context = "$(Gd.LEAK_MARK)   RULE.LEAK.HOME_PATH  commit 1234abcd notes.md:1",
                         options = [G.Model.Option("Yes", "It is removed.", true),
                                    G.Model.Option("No", "It stays.", false)])
    @test_throws Gd.PublicationRefused G.Engine.Questions.put(q, dir, cfg; io = devnull)
    @test !isfile(G.Engine.Questions.store(dir))
    # and the command line turns the refusal into exit 2, "cannot evaluate", not a crash
    @test occursin("PublicationRefused", read(joinpath(pkgdir(G), "src", "CLI", "Main.jl"), String))
end

@testset "a package's config never lists the private words: it is published" begin
    dir = mktempdir(; cleanup = true); mkpath(joinpath(dir, ".gbg"))
    write(joinpath(dir, ".gbg", "config.jl"), "Config(package = \"Example\", tool = :dev, leak_terms = [\"Examplehost\"])\n")
    @test any(p -> occursin("leak_terms", p), G.ConfigIO.validate(G.ConfigIO.read_config(dir), dir))
end
