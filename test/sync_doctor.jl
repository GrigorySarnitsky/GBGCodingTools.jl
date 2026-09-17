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
    # The end-of-turn hook left the sidecar on 2026-09-17 — `Render` writes it and the wiring check
    # compares it (test/wiring.jl) — so this uses a policy file, which `sync` still renders.
    @testset "a managed file edited (and its sidecar) is MODIFIED" begin
        managed = joinpath(root, ".gbg", "policy", "glossary.md")
        open(managed, "a") do io; println(io, "<!-- edited -->"); end
        sc = joinpath(root, ".gbg", "managed.json"); d = JSON3.read(read(sc, String), Dict{String,Any})
        d["files"][".gbg/policy/glossary.md"]["sha256"] = bytes2hex(G.Sync.sha256(read(managed)))
        open(sc, "w") do io; JSON3.pretty(io, JSON3.write(d)); end
        @test run_only(["MANAGED.HASH"])["MANAGED.HASH"].status == :FAIL
        @test G.Sync.sync(cfg; io = devnull) == 2
        rm(managed); @test G.Sync.sync(cfg; io = devnull) == 0          # removed, re-rendered
        @test run_only(["MANAGED.HASH"])["MANAGED.HASH"].status == :PASS
    end
    # The dev-stamped-round testset stood here until 2026-09-17: ROUND.DEV named a closed round whose
    # tool stamp was a dev build. Rounds and that check went together (docs/design-record/machinery-v1/).

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
    end
    @testset "doctor exit and json" begin
        checks, code = G.Doctor.run(cfg; only = ["QUICK"], io = devnull)
        @test code == 0 && !isempty(checks)
        io = IOBuffer(); G.Doctor.run(cfg; only = ["WIRE"], json = true, io)
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
# The unreachable-waiver testset stood here until 2026-09-17: CFG.EXEMPTIONS warned when a policy waiver
# named the second rule of a two-rule scan, which the scan could not honour, and `deviations.md` said so.
# The last two-rule scan was retired with the rules it carried, so nothing can be unreachable this way.

# The AUDIT.GAP testset stood here until 2026-09-17: it planted two closed audit rounds and checked
# that a base past the previous audit's closed head warns. The check and the rounds went together.

