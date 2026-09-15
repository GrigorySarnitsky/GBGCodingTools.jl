using Test, GBGCodingTools, Dates, JSON3
include("helpers.jl")

@testset "sync and doctor" begin
    root = fixture_copy("doctor")
    cfg = G.Config.read(root)
    @test G.Sync.sync(cfg; check = true, io = devnull) == 0
    @test G.doctor(cfg, :QUICK; io = devnull) == 0
    run_only(ids) = Dict(c.id => c for c in first(G.Doctor.run(cfg; only = ids, io = devnull)))
    # A sidecar an older copy wrote fails the schema this release closed. That is a refusal to name and a
    # next step to give — exit 2 — never a backtrace out of the verb whose job is to repair managed files.
    @testset "a sidecar the schema refuses is exit 2, not a crash" begin
        sc = joinpath(root, ".gbg", "managed.json")
        keep = read(sc, String)
        d = JSON3.read(keep, Dict{String,Any})
        first_file = first(keys(d["files"])); d["files"][first_file]["recorded_by"] = "an older copy"
        write(sc, JSON3.write(d))
        @test_throws G.Sync.SyncError G.Sync.read_sidecar(cfg)          # the schema does refuse it
        @test cd(() -> G.Sync.cmd_sync(String[]), root) == 2            # and the verb names it
        write(sc, keep)
    end
    @testset "a managed file edited (and its sidecar) is MODIFIED" begin
        hook = joinpath(root, ".claude", "hooks", "queue-guard.sh")
        open(hook, "a") do io; println(io, "# edited"); end
        sc = joinpath(root, ".gbg", "managed.json"); d = JSON3.read(read(sc, String), Dict{String,Any})
        d["files"][".claude/hooks/queue-guard.sh"]["sha256"] = bytes2hex(G.Sync.sha256(read(hook)))
        open(sc, "w") do io; JSON3.pretty(io, JSON3.write(d)); end
        @test run_only(["MANAGED.HASH"])["MANAGED.HASH"].status == :FAIL
        @test G.Sync.sync(cfg; io = devnull) == 2
        rm(hook); @test G.Sync.sync(cfg; io = devnull) == 0             # removed, re-rendered
        @test run_only(["MANAGED.HASH"])["MANAGED.HASH"].status == :PASS
    end
    # A closed round stamped `dev` is recorded, not invalid: ROUND.DEV names it as uncomparable and no
    # release may cite it, but it does not FAIL — a fact about a frozen record cannot be repaired, and
    # failing on it stopped `Pkg.test()` and every docs build until nothing could be shipped at all. Both
    # directions, and the scope: an audit round reads `base..HEAD` and is off-tag by construction, so it
    # is never named; a tag-stamped docs round is clean.
    @testset "a closed dev-stamped round is named, not failed" begin
        rd = joinpath(root, ".gbg", "rounds", "2026-01-01-check-docs-09"); mkpath(rd)
        st = G.Preflight.stamps(cfg)
        rec = merge(st, Dict{String,Any}("round" => "2026-01-01-check-docs-09", "instrument" => "check-docs",
            "schema_version" => 1, "head" => "0"^40, "roster" => Any[], "cost" => "economy", "strength" => "economy",
            "hostname" => "t", "model_hint" => "sonnet", "opened" => "2026-01-01T00:00:00", "dead_lanes" => String[],
            "passes" => 0, "closed" => "2026-01-02T00:00:00"))
        rec["tool_version"] = "dev+abc1234"; rec["tool_rev"] = "abc1234" * "0"^33
        write_round(rd, rec)
        r = run_only(["ROUND.DEV"])["ROUND.DEV"]
        @test r.status == :WARN && occursin("2026-01-01-check-docs-09", r.detail)
        rec["instrument"] = "audit-changes"; rec["base"] = "0"^40; write_round(rd, rec)
        @test run_only(["ROUND.DEV"])["ROUND.DEV"].status == :PASS      # an audit is off-tag by construction
        rec["instrument"] = "check-docs"; delete!(rec, "base")
        rec["tool_version"] = "1.0.0-rc.1"; rec["tool_rev"] = "v1.0.0-rc.1"; write_round(rd, rec)
        @test run_only(["ROUND.DEV"])["ROUND.DEV"].status == :PASS      # stamped with a tag: comparable
        # ROUND.FROZEN hashes the evidence; the stamps were unhashed, so re-stamping a frozen record —
        # the one "repair" that falsifies instead of fixing — passed unseen. Each stamp form names its
        # own revision now, so a tool_version that its tool_rev does not support is caught.
        @test run_only(["ROUND.FROZEN"])["ROUND.FROZEN"].status == :PASS
        rec["tool_rev"] = "9"^40; write_round(rd, rec)                  # a version whose rev is somebody else's
        f = run_only(["ROUND.FROZEN"])["ROUND.FROZEN"]
        @test f.status == :FAIL && occursin("2026-01-01-check-docs-09", f.detail)
        rec["tool_version"] = "dev+abc1234"; rec["tool_rev"] = "9"^40; write_round(rd, rec)
        @test run_only(["ROUND.FROZEN"])["ROUND.FROZEN"].status == :FAIL   # dev+<sha> that its rev denies
        rm(rd; recursive = true)
        @test run_only(["ROUND.DEV", "ROUND.FROZEN"])["ROUND.DEV"].status == :PASS
    end
    @testset "wiring" begin
        mk = joinpath(root, "docs", "make.jl"); orig = read(mk, String)
        write(mk, replace(orig, "GBGCodingTools.makedocs(" => "# GBGCodingTools.makedocs(\nmakedocs("))
        @test run_only(["WIRE.MAKEDOCS"])["WIRE.MAKEDOCS"].status == :FAIL     # a commented-out call and a bare one
        write(mk, orig)
        # the wrapper returns nothing when a round froze the build, so an unguarded deploy publishes the
        # previous run's directory or none. Both directions: at column 0 it fails, guarded it passes.
        write(mk, orig * "\ndeploydocs(repo = \"github.com/x/y.jl\")\n")
        @test run_only(["WIRE.MAKEDOCS"])["WIRE.MAKEDOCS"].status == :FAIL
        write(mk, orig * "\nresult === nothing || deploydocs(repo = \"github.com/x/y.jl\")\n")
        @test run_only(["WIRE.MAKEDOCS"])["WIRE.MAKEDOCS"].status == :PASS
        write(mk, orig)
        cm = joinpath(root, "CLAUDE.md"); co = read(cm, String)
        write(cm, replace(co, "@.gbg/policy/00-index.md" => "@.gbg/policy/00-index.md (edited)"))
        r = run_only(["WIRE.CLAUDE_MD", "POL.IMPORT"])
        @test r["WIRE.CLAUDE_MD"].status == :FAIL
        write(cm, co)
        write(cm, co * "\n\nA module docstring is a map and a function docstring is a home.\n")
        @test run_only(["LEG.SENTINELS"])["LEG.SENTINELS"].status == :FAIL        # a sentinel restated bare
        write(cm, co * "\n\nThe rule says \"A module docstring is a map and a function docstring is a home.\"\n")
        @test run_only(["LEG.SENTINELS"])["LEG.SENTINELS"].status == :PASS        # quoted: not a duplicate
        write(cm, co)
    end
    @testset "pin and legacy" begin
        cp_ = joinpath(root, ".gbg", "config.toml"); co = read(cp_, String)
        write(cp_, replace(co, "version = \"dev\"" => "version = \"1.0.0-rc.1\""))
        @test_throws G.Config.ConfigError G.Config.read(root)                     # a prerelease is never a pin: refused by the schema (CFG.VALID)
        write(cp_, co)
        mkpath(joinpath(root, ".claude", "commands")); touch(joinpath(root, ".claude", "commands", "check-docs.md"))
        @test run_only(["LEG.COMMANDS"])["LEG.COMMANDS"].status == :FAIL
        rm(joinpath(root, ".claude", "commands"); recursive = true)
        mkpath(joinpath(root, ".gbg", "rounds", "2026-01-01-check-docs-01"))
        @test run_only(["ROUND.MARKER"])["ROUND.MARKER"].status == :FAIL
        rm(joinpath(root, ".gbg", "rounds", "2026-01-01-check-docs-01"); recursive = true)
    end
    @testset "doctor exit and json" begin
        checks, code = G.Doctor.run(cfg; only = ["QUICK"], io = devnull)
        @test code == 0 && !isempty(checks)
        io = IOBuffer(); G.Doctor.run(cfg; only = ["ROUND"], json = true, io)
        @test haskey(JSON3.read(String(take!(io))), :checks)
    end
end

# init rewrites a freshly seeded test/Project.toml only where the seed is wrong: a consumer pinned dev,
# whose seed names a tag that does not resolve. Never the tool itself, whose test environment carries no
# tool entry, nor a release pin, nor a test/ that already has its Project.toml (2026-09-11-audit-changes-01
# found the rewrite applied to all four).
@testset "init rewrites a seeded test environment only for a dev pin" begin
    root = mktempdir()
    c(name, v) = Dict{String,Any}("package" => Dict{String,Any}("name" => name), "tool" => Dict{String,Any}("version" => v))
    @test G.Init.seeded_test_rewritten(c("Foo", "dev"), root)
    @test !G.Init.seeded_test_rewritten(c("Foo", "1.0.0"), root)                 # a release pin: the seed is right
    @test !G.Init.seeded_test_rewritten(c(G.PKG_NAME, "dev"), root)              # the tool itself: no tool entry
    mkpath(joinpath(root, "test")); touch(joinpath(root, "test", "Project.toml"))
    @test !G.Init.seeded_test_rewritten(c("Foo", "dev"), root)                   # nothing was seeded
end

# CFG.TORN had NO test, and a work-queue item of 2026-09-12-check-docs-01 doubted it: one doctor run
# reported `CFG.EXEMPTIONS 10 entries` — a count only the edited ledger yields — while CFG.TORN in the
# same run reported nothing modified. By hand the guard could not be made to miss, so the doubt is pinned
# here in BOTH directions rather than left standing on one unexplained reading.
# The root needs its OWN repository. `fixture_copy` is a plain copy under fixture/.tmp/, which the tool's
# .gitignore excludes, so its .gbg/ files are untracked, `git status --untracked-files=no` reports nothing,
# and a test written against it would PASS while asserting nothing at all — the vacuous shape that lets a
# guard rot unnoticed. `git init` inside the copy makes `rev-parse --show-toplevel` equal the root, so
# porcelain's prefix is empty and a tracked file behaves as it does in a real consumer.
@testset "CFG.TORN fails on a modified pinned file, and only while it is modified" begin
    root = fixture_copy("torn")
    git(args...) = run(pipeline(setenv(`git -C $root -c user.email=t@t -c user.name=t $args`,
                                       "HOME" => root, "PATH" => ENV["PATH"]); stdout = devnull, stderr = devnull))
    git("init", "-q", "-b", "master"); git("add", "-A"); git("commit", "-q", "-m", "base")
    cfg = G.Config.read(root)
    torn() = Dict(c.id => c for c in first(G.Doctor.run(cfg; only = ["CFG.TORN"], io = devnull)))["CFG.TORN"]
    @test torn().status == :PASS                                                 # committed: nothing is torn
    led = joinpath(root, ".gbg", "exemptions.toml"); keep = read(led, String)
    open(led, "a") do io; println(io, "\n# a half-synced edit, the case this guard exists for"); end
    t = torn()
    @test t.status == :FAIL && occursin("exemptions.toml", t.detail)             # the ledger, named
    write(led, keep)
    @test torn().status == :PASS                                                 # restored: torn no more
end

# a policy waiver of the second rule of a two-rule scan does not reach that scan, which keeps running: the
# doctor WARNs and names the scan (a FAIL here broke every gate over a deviation that was legitimate —
# 2026-09-15-audit-changes-01), deviations.md says the same, and a waiver of the canonical rule passes
@testset "CFG.EXEMPTIONS names a policy waiver the scan cannot honour" begin
    root = fixture_copy("unreachable-waiver")
    led = joinpath(root, ".gbg", "exemptions.toml")
    entry(rule) = "\n[[exemption]]\nid = \"$rule\"\nscope = \"policy\"\ntarget = \"*\"\n" *
                  "reason = \"a deviation recorded for the test of the doctor's waiver check\"\n" *
                  "recorded = 2026-01-01\nexpires = 2026-12-31\n"
    exemptions() = Dict(c.id => c for c in first(G.Doctor.run(G.Config.read(root); only = ["CFG.EXEMPTIONS"], io = devnull)))["CFG.EXEMPTIONS"]
    keep = read(led, String)
    write(led, keep * entry("RULE.CIT.FULL_INLINE"))
    @test exemptions().status == :PASS
    write(led, keep * entry("RULE.CIT.DOI"))
    c = exemptions()
    @test c.status == :WARN && occursin("RULE.CIT.DOI", c.detail) && occursin("SCAN.DOI_CROSSCHECK", c.detail)
    cfg = G.Config.read(root)
    dev = only(f for f in G.Sync.plan(cfg) if endswith(f.path, "deviations.md"))
    @test occursin("does not reach `SCAN.DOI_CROSSCHECK`", dev.content)
end

# AUDIT.GAP asks whether commits went unaudited between two closed audits: a later base AT or BEFORE the
# earlier audit's closed head leaves none (an overlap re-reads some), a base PAST it leaves some. It
# compared for equality, and warned on an overlap that left nothing unread.
@testset "AUDIT.GAP warns on a base past the previous audit, never on an overlap" begin
    root = fixture_copy("audit-gap")
    git(args...) = run(pipeline(setenv(`git -C $root -c user.email=t@t -c user.name=t $args`,
                                       "HOME" => root, "PATH" => ENV["PATH"]); stdout = devnull, stderr = devnull))
    git("init", "-q", "-b", "master"); git("add", "-A"); git("commit", "-q", "-m", "c0")
    shas = [G.Git.head(root)]
    for n in 1:3
        write(joinpath(root, "note$n.txt"), "$n\n"); git("add", "-A"); git("commit", "-q", "-m", "c$n"); push!(shas, G.Git.head(root))
    end
    cfg = G.Config.read(root)
    audit(name, base, closed, opened) = begin
        d = joinpath(root, ".gbg", "rounds", name); mkpath(d)
        write_round(d, merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => name, "instrument" => "audit-changes",
            "schema_version" => 1, "head" => closed, "base" => base, "closed_head" => closed, "roster" => Any[],
            "cost" => "economy", "strength" => "economy", "hostname" => "t", "model_hint" => "sonnet",
            "opened" => opened, "dead_lanes" => String[], "passes" => 0, "closed" => opened)))
    end
    gap() = Dict(c.id => c for c in first(G.Doctor.run(G.Config.read(root); only = ["AUDIT.GAP"], io = devnull)))["AUDIT.GAP"]
    audit("2026-01-01-audit-changes-01", shas[1], shas[3], "2026-01-01T00:00:00")     # audited c0..c2
    for (b, want) in ((shas[2], :PASS), (shas[3], :PASS), (shas[4], :WARN))            # overlap, contiguous, past it
        audit("2026-01-02-audit-changes-01", b, shas[4], "2026-01-02T00:00:00")
        @test gap().status == want
    end
    # an exact match whose commit this checkout does not have (a shallow clone, a rewritten history) is
    # still contiguous: the strings say so, and no git object is needed (2026-09-15-audit-changes-01)
    gone = "e"^40
    audit("2026-01-01-audit-changes-01", shas[1], gone, "2026-01-01T00:00:00")
    audit("2026-01-02-audit-changes-01", gone, shas[4], "2026-01-02T00:00:00")
    @test gap().status == :PASS
end
