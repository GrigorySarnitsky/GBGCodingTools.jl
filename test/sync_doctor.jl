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
