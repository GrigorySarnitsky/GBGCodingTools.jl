# test/leak.jl — Phase 9's gate: the leak scan, with the pinned Gitleaks, over a planted repository.
#
#     julia --project test/leak.jl
#
# It is not in `Pkg.test()` and must not be: it runs Gitleaks, which CI does not install, and
# `gbg install --gitleaks` reaches the network. What runs without Gitleaks is test/publication.jl, in the
# suite. Here every place a careless scan misses is planted — and an independent review of the first
# version (2026-10-02) found twenty, each planted below — and each must be reported, no line printed may
# hold what was planted, and the repository is left as it was.
using Test, GBGCodingTools
const G = GBGCodingTools

isfile(G.Publication.gitleaks()) || error("Gitleaks $(G.Publication.GITLEAKS.version) is not installed: run `gbg install --gitleaks`")

const TOKEN = "ghp_" * "0123456789abcdefghijABCDEFGHIJ012345"         # a GitHub token's shape, planted
const ADDRESS = "someone@" * "mailbox.zz"            # .zz is assigned to no country, and reserved for none
const TAGGER = "tagger@" * "mailbox.zz"

function planted()
    dir = mktempdir(; cleanup = true)
    env = ["GIT_CONFIG_GLOBAL=/dev/null", "HOME=$dir", "GIT_AUTHOR_NAME=someone", "GIT_AUTHOR_EMAIL=$ADDRESS",
           "GIT_COMMITTER_NAME=someone", "GIT_COMMITTER_EMAIL=$ADDRESS"]
    g(args...; e = env) = run(pipeline(setenv(`git -C $dir $args`, e); stdout = devnull, stderr = devnull))
    w(path, text) = (mkpath(dirname(joinpath(dir, path))); write(joinpath(dir, path), text))
    g("init", "-q", "-b", "master")
    # the scanned repository's own attempts to silence the scan
    w(".gitleaks.toml", "[[rules]]\nid = \"dummy\"\nregex = '''zzzz'''\n")
    w(".gitattributes", "hidden.md -diff\n")
    w("old.toml", "key = \"$TOKEN\"\n")
    w("inline.toml", "k = \"$TOKEN\" # gitleaks:allow\n")
    w("hidden.md", "/home/attruser/notes\n")
    w("parked/a.jl", "# /home/parkeduser/x\n")
    w("key.p12", "x\0y")                                                # a binary key
    touch(joinpath(dir, "id_ed25519"))                                  # an empty one
    w("notes.txt", "plain\n")
    w("Examplehost/readme.md", "plain\n")                               # a private word in a path
    g("add", "-A"); g("commit", "-q", "-m", "one")
    one = strip(read(setenv(`git -C $dir rev-parse HEAD`, env), String))
    w(".gitleaksignore", "$one:old.toml:github-pat:1\n"); g("add", ".gitleaksignore")
    g("rm", "-q", "old.toml"); g("commit", "-q", "-m", "two: the key was $TOKEN")
    g("mv", "notes.txt", ".env"); g("commit", "-q", "-m", "three\x1eafter a record separator, /home/hiddenuser/x")
    # a merge whose own content is new
    g("checkout", "-q", "-b", "side"); w("s.txt", "s\n"); g("add", "s.txt"); g("commit", "-q", "-m", "side")
    g("checkout", "-q", "master"); g("merge", "-q", "--no-commit", "side")
    w("merged.txt", "/home/evilmerge/x\n"); g("add", "merged.txt"); g("commit", "-q", "-m", "merge")
    # a commit the reflog alone still reaches
    w("rewritten.txt", "/home/rewriteuser/x\n"); g("add", "rewritten.txt"); g("commit", "-q", "-m", "gone")
    g("reset", "-q", "--hard", "HEAD~1")
    # refs whose names leak, a tag pointing straight at a blob, and an annotated tag by another tagger
    g("branch", "fix-for-$ADDRESS"); g("tag", "v2-$TOKEN")
    blob = strip(read(pipeline(setenv(`git -C $dir hash-object -w --stdin`, env); stdin = IOBuffer("/home/blobuser/x\n")), String))
    g("tag", "blobtag", blob)
    g("tag", "-a", "v1", "-m", "a release"; e = vcat(env, ["GIT_COMMITTER_EMAIL=$TAGGER"]))
    # found in the second review: quoted paths, a dependency directory, a tag of a tag, a replace ref,
    # two findings in one message
    w("a\"b/.env", "x\n"); w("q\"examplehost/y.txt", "/home/quoteduser/x\n")
    w("node_modules/a/b.js", "t = \"$TOKEN\"\n"); w("test/fixtures/fake.pem", "not a key\n")
    g("add", "-A"); g("commit", "-q", "-m", "four: /home/twouser/a and\n/home/twouser/b")
    g("tag", "-a", "inner", "-m", "/home/inneruser/x"); g("tag", "-a", "outer", "-m", "outer", "inner"); g("tag", "-d", "inner")
    w("secret.txt", "/home/replaceduser/x\n"); g("add", "secret.txt"); g("commit", "-q", "-m", "bad")
    bad = strip(read(setenv(`git -C $dir rev-parse HEAD`, env), String))
    g("branch", "kept-bad"); g("reset", "-q", "--hard", "HEAD~1")
    w("clean.txt", "nothing\n"); g("add", "clean.txt"); g("commit", "-q", "-m", "good")
    good = strip(read(setenv(`git -C $dir rev-parse HEAD`, env), String))
    g("replace", bad, good)
    return dir, env
end

@testset "the leak scan finds what a careless scan misses, and prints none of it" begin
    dir, env = planted()
    before = read(setenv(`git -C $dir status --porcelain --ignored`, env), String)
    refs_before = read(setenv(`git -C $dir for-each-ref`, env), String)
    cfg = G.Model.Config(package = "Planted", tool = :dev, leak_terms = ["Examplehost"],
                         exclusions = [G.Model.Exclusion(files = ["parked/**"], reason = "parked")])
    # the environment's attempt to replace Gitleaks' rules
    found = withenv("GITLEAKS_CONFIG" => joinpath(dir, ".gitleaks.toml")) do
        G.Publication.scan(dir, cfg).findings
    end
    has(rule, place) = any(f -> f.rule === Symbol(rule) && occursin(place, f.place), found)
    @test has("RULE.LEAK.CREDENTIAL", "old.toml:1")               # in a file deleted since, and in .gitleaksignore
    @test has("RULE.LEAK.CREDENTIAL", "inline.toml:1")            # behind gitleaks:allow
    @test has("RULE.LEAK.CREDENTIAL", "the message of commit")    # in a commit message
    @test has("RULE.LEAK.EMAIL", "an author or committer")        # in the author field
    @test has("RULE.LEAK.EMAIL", "the tagger of a tag")           # in the tagger field
    @test has("RULE.LEAK.HOME_PATH", "hidden.md:1")               # behind .gitattributes -diff
    @test has("RULE.LEAK.HOME_PATH", "parked/a.jl:1")             # in an excluded file: exclusions do not apply
    @test has("RULE.LEAK.HOME_PATH", "merged.txt:1")              # in a merge commit's own content
    @test has("RULE.LEAK.HOME_PATH", "rewritten.txt:1")           # in a commit only the reflog reaches
    @test has("RULE.LEAK.HOME_PATH", "held by no commit")         # in a tag pointing at a blob
    @test has("RULE.LEAK.HOME_PATH", "the message of commit")     # after a \x1e in a message
    @test has("RULE.LEAK.NEVER_PUBLISHED", "key.p12")             # a binary key
    @test has("RULE.LEAK.NEVER_PUBLISHED", "id_ed25519")          # an empty key
    @test has("RULE.LEAK.NEVER_PUBLISHED", ".env")                # a rename
    @test has("RULE.LEAK.TERM", "a file's path")                  # a private word in a path
    @test has("RULE.LEAK.CREDENTIAL", "the name of a ref")        # a token in a tag's name
    @test has("RULE.LEAK.EMAIL", "the name of a ref")             # an address in a branch's name
    @test has("RULE.LEAK.NEVER_PUBLISHED", "a\"b/.env")            # a path git would quote
    @test has("RULE.LEAK.CREDENTIAL", "node_modules/a/b.js:1")    # under Gitleaks' global path allowlist
    @test has("RULE.LEAK.HOME_PATH", "the message of a tag object") # in a tag of a tag no ref names
    @test has("RULE.LEAK.HOME_PATH", "secret.txt:1")              # behind a replace ref
    @test count(f -> f.rule === Symbol("RULE.LEAK.HOME_PATH") && occursin("the message of commit", f.place) &&
                     !occursin("hiddenuser", f.place), found) >= 2   # two in one message, each its own
    # a hook's GIT_DIR, pointing at a clean repository, does not move the scan
    clean = mktempdir(; cleanup = true); run(pipeline(`git -C $clean init -q`; stdout = devnull))
    steered = withenv("GIT_DIR" => joinpath(clean, ".git")) do
        G.Publication.scan(dir, cfg).findings
    end
    @test length(steered) == length(found)

    # The command, as a session runs it, with this machine's private words in a home of its own: the words
    # are read from ~/.gbg/leak-terms, never from the package's config.
    home = mktempdir(; cleanup = true); mkpath(joinpath(home, ".gbg"))
    symlink(joinpath(homedir(), ".gbg", "tools"), joinpath(home, ".gbg", "tools"))
    write(joinpath(home, ".gbg", "leak-terms"), "# private words\nExamplehost\n")
    out = IOBuffer()
    @test withenv(() -> G.Leak.scan(dir; io = out), "HOME" => home) == 1
    printed = String(take!(out))
    for secret in (TOKEN, ADDRESS, TAGGER, "Examplehost", "examplehost", "/home/")
        @test !occursin(secret, printed)                          # not in a place, a count or a fingerprint
    end
    @test all(l -> startswith(l, G.Leak.MARK), filter(!isempty, split(printed, '\n')))
    @test read(setenv(`git -C $dir status --porcelain --ignored`, env), String) == before   # nothing written
    @test read(setenv(`git -C $dir for-each-ref`, env), String) == refs_before              # nor a ref added

    # an approved address and a switched-off rule are not findings
    ok = G.Model.Config(package = "Planted", tool = :dev, leak_emails = [ADDRESS, TAGGER],
                        switches = [G.Model.Switch(target = Symbol("RULE.LEAK.SYNCED_PATH"), reason = "planted")])
    again = G.Publication.scan(dir, ok).findings
    @test !any(f -> f.rule === Symbol("RULE.LEAK.EMAIL") && !occursin("the name of a ref", f.place), again)
    @test !any(f -> f.rule === Symbol("RULE.LEAK.SYNCED_PATH"), again)

    # last, since it commits: a switch naming files reaches a path's finding, and its fingerprint does not move
    fixture = G.Model.Config(package = "Planted", tool = :dev,
                             switches = [G.Model.Switch(target = Symbol("RULE.LEAK.NEVER_PUBLISHED"), files = ["test/fixtures/**"], reason = "a fixture")])
    @test !any(f -> f.rule === Symbol("RULE.LEAK.NEVER_PUBLISHED") && occursin("fake.pem", f.place), G.Publication.scan(dir, fixture).findings)
    fp(fs) = Set(f.fingerprint for f in fs if f.rule === Symbol("RULE.LEAK.NEVER_PUBLISHED"))
    before_fp = fp(found)
    run(pipeline(setenv(`git -C $dir commit -q --allow-empty -m another`, env); stdout = devnull))
    @test before_fp ⊆ fp(G.Publication.scan(dir, cfg).findings)


    # The three tiers (the owner, 2026-10-02). A note the current files hold is not a history note; a
    # blocking finding is never accepted; `--accept` records the history's notes, and they are then
    # counted as accepted, not listed.
    tiers_dir, tenv = planted()
    write(joinpath(tiers_dir, "now.md"), "/home/nowuser/x\n")
    run(pipeline(setenv(`git -C $tiers_dir add now.md`, tenv); stdout = devnull))
    run(pipeline(setenv(`git -C $tiers_dir commit -q -m now`, tenv); stdout = devnull))
    fs = G.Publication.scan(tiers_dir, G.Model.Config(package = "Planted", tool = :dev)).findings
    pick(rule, place) = only(f for f in fs if f.rule === Symbol(rule) && occursin(place, f.place))
    @test pick("RULE.LEAK.HOME_PATH", "now.md:1").current
    @test !pick("RULE.LEAK.HOME_PATH", "rewritten.txt:1").current
    @test G.Publication.blocking(pick("RULE.LEAK.CREDENTIAL", "old.toml:1"))
    @test !G.Publication.blocking(pick("RULE.LEAK.HOME_PATH", "now.md:1"))
    first_out = IOBuffer(); G.Leak.scan(tiers_dir; accept = true, io = first_out)
    taken = G.Publication.accepted(tiers_dir)
    @test pick("RULE.LEAK.HOME_PATH", "rewritten.txt:1").fingerprint in taken      # a history note, accepted
    @test !(pick("RULE.LEAK.HOME_PATH", "now.md:1").fingerprint in taken)          # a current one, not
    @test !(pick("RULE.LEAK.CREDENTIAL", "old.toml:1").fingerprint in taken)       # a blocking one, never
    @test all(l -> occursin(r"^[0-9a-f]{16}$", l), readlines(joinpath(tiers_dir, G.Publication.ACCEPTED)))
    again_out = IOBuffer(); @test G.Leak.scan(tiers_dir; io = again_out) == 1      # blocking still open
    again = String(take!(again_out))
    @test occursin(r"0 only in history; \d+ accepted before", again)
    @test occursin("now.md", again) && !occursin("rewritten.txt", again)
end
