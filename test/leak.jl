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

    # the token deleted from old.toml is still in inline.toml at HEAD, so that finding is current
    @test pick("RULE.LEAK.CREDENTIAL", "old.toml:1").current
end

# A credential the owner judged false, that only the history holds, is recorded with his reason and leaves
# the blocking tier; nothing else is recorded so, and a credential still in the current files under any
# name, or hidden from an archive, is not one the history alone holds (GBGHomogeneousTurbulence and the
# review, 2026-10-22).
@testset "a credential judged false is recorded one at a time, and only from history" begin
    tok(seed) = (rng = G.Random.MersenneTwister(seed); "ghp_" * String([rand(rng, ['a':'z'; 'A':'Z'; '0':'9']) for _ in 1:36]))
    aws = "AKIA" * "QYLPMN5HHHFPZAM2"
    dir = mktempdir(; cleanup = true)
    env = ["GIT_AUTHOR_NAME" => "t", "GIT_AUTHOR_EMAIL" => "t@users.noreply.github.com",
           "GIT_COMMITTER_NAME" => "t", "GIT_COMMITTER_EMAIL" => "t@users.noreply.github.com", "HOME" => dir]
    g(a...) = run(pipeline(setenv(`git -C $dir $a`, env); stdout = devnull, stderr = devnull))
    w(path, text) = (mkpath(dirname(joinpath(dir, path))); write(joinpath(dir, path), text))
    g("init", "-q", "--initial-branch=master")
    w("gone.toml", "hat = \"$(tok(1))\"\n")                                   # deleted below: history only
    w("pair.toml", "a = \"$(tok(2))\"  b = \"$aws\"\n")                       # two on one line, deleted below
    w("moved.toml", "k = \"$(tok(3))\"\n")                                     # renamed below: still current
    w("kept.toml", "k = \"$(tok(4))\"\n"); w(".gitattributes", "kept.toml export-ignore\n")
    g("add", "-A"); g("commit", "-q", "-m", "one")
    g("rm", "-q", "gone.toml", "pair.toml"); g("mv", "moved.toml", "renamed.toml"); g("commit", "-q", "-m", "two")
    fs = G.Publication.scan(dir, G.Model.Config(package = "P", tool = :dev)).findings
    creds = [f for f in fs if f.rule === Symbol("RULE.LEAK.CREDENTIAL")]
    at(file) = [f for f in creds if f.file == file]
    @test length(at("pair.toml")) == 2 && length(unique(f.fingerprint for f in at("pair.toml"))) == 2
    @test !only(at("gone.toml")).current
    @test all(f -> f.current, at("moved.toml"))                    # renamed, its secret still at HEAD
    @test all(f -> f.current, at("kept.toml"))                     # export-ignore hides nothing
    said(; kw...) = (b = IOBuffer(); code = G.Leak.scan(dir; io = b, kw...); (code, String(take!(b))))
    gone = only(at("gone.toml")).fingerprint
    @test occursin("run it with --github", said(not_credential = gone, why = "a panel name, not a key")[2])
    @test occursin("in the current files", said(not_credential = first(at("moved.toml")).fingerprint, why = "a panel name, not a key", local_only = true)[2])
    @test occursin("in the current files", said(not_credential = first(at("kept.toml")).fingerprint, why = "a panel name, not a key", local_only = true)[2])
    @test occursin("--why holds something", said(not_credential = gone, why = "it is $(tok(5)) anyway", local_only = true)[2])
    @test occursin("--why needs", said(not_credential = gone, why = "a reason\rhidden", local_only = true)[2])
    blocking(out) = parse(Int, match(r"finding\(s\): (\d+) blocking", out).captures[1])
    before = blocking(said()[2])
    code, out = said(not_credential = gone, why = "a panel name, not a key", local_only = true)
    @test occursin("recorded [$gone] as not a credential", out)
    @test occursin("recorded already", said(not_credential = gone, why = "a panel name, not a key", local_only = true)[2])
    after = said()[2]
    @test blocking(after) == before - 1 && !occursin(gone, after)
    # one of the two on a line recorded, the other stays
    pa, pb = (f.fingerprint for f in at("pair.toml"))
    said(not_credential = pa, why = "the first is a test value", local_only = true)
    left = said()[2]
    @test !occursin(pa, left) && occursin(pb, left)
    # a reason too short to be one, written by hand, is not honoured; `--accept` keeps every reason
    open(joinpath(dir, G.Publication.ACCEPTED), "a") do io; println(io, pb, "  not a credential: x"); end
    @test !(pb in G.Publication.not_credentials(dir))
    said(accept = true)
    @test gone in G.Publication.not_credentials(dir) && pa in G.Publication.not_credentials(dir)

    # a credential in a file Gitleaks reads as binary when it reads a directory (an archive) is still
    # current while the default branch holds that file; one only the default branch holds whole, added
    # over two commits, is a finding of its own (second review, 2026-10-22)
    src = mkpath(joinpath(dir, "packed")); write(joinpath(src, "inner.toml"), "k = \"$(tok(6))\"\n")
    run(pipeline(setenv(`tar -cf $(joinpath(dir, "bundle.tar")) -C $src inner.toml`, env); stdout = devnull))
    rm(src; recursive = true)
    g("add", "bundle.tar"); g("commit", "-q", "-m", "three")
    half = tok(7)
    w("split.toml", "k = \"" * half[1:20]); g("add", "split.toml"); g("commit", "-q", "-m", "four")
    w("split.toml", "k = \"" * half * "\"\n"); g("add", "split.toml"); g("commit", "-q", "-m", "five")
    fs2 = G.Publication.scan(dir, G.Model.Config(package = "P", tool = :dev)).findings
    packed = [f for f in fs2 if f.rule === Symbol("RULE.LEAK.CREDENTIAL") && f.file == "bundle.tar"]
    @test !isempty(packed) && all(f -> f.current, packed)
    @test occursin("in the current files", said(not_credential = first(packed).fingerprint, why = "a panel name, not a key", local_only = true)[2])
    @test any(f -> f.rule === Symbol("RULE.LEAK.CREDENTIAL") && f.current && occursin("split.toml", f.place), fs2)
end

# The runner's home, and each form of it Gitleaks cuts short at a chunk boundary, is allowed; a real home
# is not, whole or cut (GBGHomogeneousTurbulence, 2026-10-22).
@testset "the runner's home, whole or cut short, and nothing else" begin
    allowed(s) = any(p -> occursin(Regex(p), s), G.Catalogue.Leaks.RUNNER_HOMES)
    @test all(allowed, ["/home/runner", "/home/runne", "/home/r", "/Users/run", "C:\\Users\\runneradmin", "C:\\Users\\runnera"])
    @test !any(allowed, ["/home/rob", "/home/runners", "/home/grigory", "/Users/alice", "C:\\Users\\rob"])
end

# A dependency's uuid on a line of a Julia project or manifest is no credential; the same text anywhere
# else, or a line that is not `name = "<uuid>"`, still is.
@testset "a dependency's uuid in a manifest is not a credential" begin
    isfile(G.Publication.gitleaks()) || return
    dir = mktempdir(; cleanup = true); t = mkpath(joinpath(dir, "t", "docs"))
    uuid = "8f75cd03-7ff8-4ecb-9b8f-daf728133b1b"
    write(joinpath(dir, "t", "Manifest.toml"), "[[deps.Foo]]\n\n    [deps.Foo.weakdeps]\n    oneAPI = \"$uuid\"\n")
    write(joinpath(dir, "t", "settings.txt"), "oneAPI = \"$uuid\"\n")
    write(joinpath(t, "Project.toml"), "api_token = \"$uuid\" # x\n")
    conf = joinpath(dir, "d.toml")
    write(conf, G.Publication.with_dependency_uuids(G.Publication.without_global_allowlist(read(G.Publication.defaults_file(), String))))
    found = sort([basename(String(r.File)) for r in G.Publication.pass(["dir", joinpath(dir, "t")], conf, dir)])
    @test found == ["Project.toml", "settings.txt"]
end

# A log GitHub refuses is a log not read, never one no longer kept: eight downloads at a time ran into the
# rate limit, and every pass read a different part of the logs and called itself complete (GBGPeriodicFields,
# 2026-10-11). A stand-in `gh` answers as GitHub does.
@testset "a refused workflow log is retried, then reported unread, never as gone" begin
    bin = mktempdir(; cleanup = true); dir = mktempdir(; cleanup = true)
    count_file = joinpath(dir, "calls")
    gh = joinpath(bin, "gh")
    write(gh, """#!/usr/bin/env bash
    n=\$(cat "$count_file" 2>/dev/null || echo 0); n=\$((n + 1)); echo \$n > "$count_file"
    case "\$2" in
      */gone/logs)    echo "gh: Not Found (HTTP 410)" >&2; exit 1 ;;
      */limited/logs) echo "gh: API rate limit exceeded (HTTP 403)" >&2; exit 1 ;;
      */late/logs)    [ \$n -ge 2 ] && { printf 'PK'; exit 0; }; echo "gh: API rate limit exceeded (HTTP 403)" >&2; exit 1 ;;
    esac
    """); chmod(gh, 0o755)
    withenv("PATH" => bin * ":" * ENV["PATH"]) do
        zip = joinpath(dir, "x.zip")
        @test G.Publication.fetch_log("o/r", "gone", zip; waits = (0, 0, 0)) === :expired
        @test G.Publication.fetch_log("o/r", "limited", zip; waits = (0, 0, 0)) === :refused
        rm(count_file; force = true)
        @test G.Publication.fetch_log("o/r", "late", zip; waits = (0, 0, 0)) === :read     # waited out
        # a run that wrote no log is served as an archive holding no file: read, with nothing in it
        empty = tempname()
        write(empty, UInt8[0x50, 0x4b, 0x05, 0x06], zeros(UInt8, 18))
        @test G.Publication.empty_archive(empty)
        write(empty, UInt8[0x50, 0x4b, 0x03, 0x04], zeros(UInt8, 18))
        @test !G.Publication.empty_archive(empty)
        @test !G.Publication.empty_archive(tempname())
        # a shared pace: a hold delays every download, not only the one refused
        pace = G.Publication.Throttle(0.0)
        G.Publication.hold!(pace, 1.0)
        t0 = time(); G.Publication.slot!(pace); @test time() - t0 >= 0.9
    end
end

# Each GitHub-side item is scanned as its own file and placed by it: joined into one text and placed again
# by line number, every one of ten findings in GBGPeriodicFields' logs named a run whose log held nothing
# (2026-10-11).
@testset "a GitHub-side finding names the item that holds it" begin
    items = mktempdir(; cleanup = true); work = mktempdir(; cleanup = true)
    places = Dict{String,String}()
    for k in 1:200
        f = "item-$k.txt"
        write(joinpath(items, f), k == 137 ? "line one\nbuilt in /home/someone/work/pkg\n" : "ordinary\r\nlog " * "x"^(k * 50) * "\n")
        places[f] = "the log of workflow run $(1000 + k)"
    end
    fs, skipped = G.Publication.item_findings(items, places, G.Model.Config(package = "P", tool = :dev), work)
    @test skipped == 0
    # a file Gitleaks takes for binary is skipped by it in silence: here it is counted, an item not read
    write(joinpath(items, "item-201.txt"), "%PDF-1.4\n/home/someone/hidden\n"); places["item-201.txt"] = "issue #201"
    @test last(G.Publication.item_findings(items, places, G.Model.Config(package = "P", tool = :dev), mktempdir(; cleanup = true))) == 1
    rm(joinpath(items, "item-201.txt")); delete!(places, "item-201.txt")
    @test [f.place for f in fs if f.rule === Symbol("RULE.LEAK.HOME_PATH")] == ["the log of workflow run 1137"]
    @test all(f -> f.current, fs)
end

# The whole GitHub side through a stand-in `gh`: an issue whose title reads as a PDF is still scanned, two
# comments on one issue are two findings, a log names its run, and a log GitHub refuses leaves the pass
# incomplete (review, 2026-10-11).
@testset "the GitHub side, read through gh, end to end" begin
    work = mktempdir(; cleanup = true); bin = joinpath(work, "bin"); mkpath(bin)
    logs = joinpath(work, "logs"); mkpath(logs)
    for (k, body) in (1 => "2026-07-01T00:00:00Z clean line\n", 2 => "2026-07-01T00:00:00Z built at /home/eve/w\n")
        write(joinpath(logs, "job.txt"), body)
        run(pipeline(`zip -qj $(joinpath(logs, "$k.zip")) $(joinpath(logs, "job.txt"))`; stdout = devnull))
    end
    write(joinpath(bin, "gh"), """#!/usr/bin/env bash
    p="\$2"; [ "\$p" = "--paginate" ] && p="\$3"
    case "\$p" in
      repos/o/r/issues\\?*)        echo '["5","An issue\\nfirst line"]'; echo '["6","%PDF-1.4 title\\n/home/bob/b"]' ;;
      repos/o/r/pulls/*/reviews*)  : ;;
      repos/o/r/issues/comments*)  echo '["5","see /home/carol/c"]'; echo '["5","see /home/carol/c"]' ;;
      repos/o/r/pulls/comments*|repos/o/r/comments*|repos/o/r/releases*) : ;;
      repos/o/r/actions/runs\\?*)  echo 101; echo 102; echo 103 ;;
      repos/o/r/actions/runs/101/logs) cat "$(joinpath(logs, "1.zip"))" ;;
      repos/o/r/actions/runs/102/logs) cat "$(joinpath(logs, "2.zip"))" ;;
      repos/o/r/actions/runs/103/logs) echo "gh: API rate limit exceeded (HTTP 403)" >&2; exit 1 ;;
      *) echo "unknown \$p" >&2; exit 1 ;;
    esac
    """); chmod(joinpath(bin, "gh"), 0o755)
    repo = joinpath(work, "repo"); mkpath(repo)
    run(pipeline(`git -C $repo init -q`; stdout = devnull)); run(pipeline(`git -C $repo remote add origin https://github.com/o/r.git`; stdout = devnull))
    withenv("PATH" => bin * ":" * ENV["PATH"]) do
        gdir, files, missed, unread = G.Publication.github(repo; io = devnull, waits = (0, 0))
        fs, skipped = G.Publication.item_findings(gdir, files, G.Model.Config(package = "P", tool = :dev), work)
        homes = sort([f.place for f in fs if f.rule === Symbol("RULE.LEAK.HOME_PATH")])
        @test homes == ["a comment on #5", "a comment on #5", "issue or pull request #6", "the log of workflow run 102"]
        @test length(unique(f.fingerprint for f in fs if f.place == "a comment on #5")) == 2
        @test skipped == 0 && unread == 1
    end
end

