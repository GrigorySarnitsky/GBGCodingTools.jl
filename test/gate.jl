using Test, GBGCodingTools, TOML
include("helpers.jl")

@testset "gate" begin
    root = fixture_copy("gate")
    cfg = G.Config.read(root)
    @test G.gate(cfg; io = devnull) == 0
    # an open round, written the way preflight writes it
    st = G.Preflight.stamps(cfg)
    rd = joinpath(root, ".gbg", "rounds", "2026-09-09-bug-hunt-01"); mkpath(rd)
    rec = merge(st, Dict{String,Any}("round" => "2026-09-09-bug-hunt-01", "instrument" => "bug-hunt", "schema_version" => 1,
        "head" => something(G.Git.head(root), "0"^40), "roster" => Any[], "cost" => "economy", "strength" => "economy", "hostname" => "test",
        "model_hint" => "sonnet", "opened" => "2026-09-09T00:00:00", "dead_lanes" => String[], "passes" => 0))
    open(joinpath(rd, "ROUND.toml"), "w") do f; TOML.print(f, rec); end
    @test G.gate(cfg; io = devnull) == 1
    @test G.gate(cfg, "check-docs", "check-consistency"; io = devnull) == 0        # a docs build ignores a hunt round
    @test G.gate(cfg, "bug-hunt", "audit-changes"; io = devnull) == 1
    withenv("GBG_ROUND" => "2026-09-09-bug-hunt-01") do
        @test G.gate(cfg; io = devnull) == 0                                        # exactly this round is ignored
    end
    withenv("GBG_ROUND" => "2026-09-09-bug-hunt-02") do
        @test G.gate(cfg; io = devnull) == 1                                        # another name ignores nothing
    end
    # frozen_rounds names what the gate refuses FOR, so the docs wrapper can tell a frozen build from a
    # broken one. Both directions: a hunt round is named to whoever asks about bug-hunt and to nobody
    # asking about the docs instruments, and GBG_ROUND removes it exactly as it does for the gate.
    @test G.frozen_rounds(cfg, "bug-hunt", "audit-changes") == ["2026-09-09-bug-hunt-01"]
    @test isempty(G.frozen_rounds(cfg, "check-docs", "check-consistency"))
    @test G.frozen_rounds(cfg) == ["2026-09-09-bug-hunt-01"]                        # all four when none is named
    withenv("GBG_ROUND" => "2026-09-09-bug-hunt-01") do
        @test isempty(G.frozen_rounds(cfg))                                         # the round's own build is not frozen out
    end
    rm(joinpath(rd, "ROUND.toml"))
    @test G.gate(cfg; io = devnull) == 2                                            # a directory without a marker
    rm(rd; recursive = true)
    rm(joinpath(root, ".gbg", "rounds"); recursive = true)
    @test G.gate(cfg; io = devnull) == 2                                            # ROUND.DIR: never vacuous
    @test isempty(G.frozen_rounds(cfg))                                             # no rounds directory freezes nothing
end
