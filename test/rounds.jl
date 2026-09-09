using Test, GBGCodingTools, TOML, JSON3
include("helpers.jl")

# One round lifecycle without agents: preflight → (hand-written lane files) → bank → pass open →
# (hand-written verdicts) → grade → close refusals, on a fresh copy of the fixture. The instrument is
# check-docs with a hand-planted lane file; `prepare` is exercised on its scan half only through the
# engine (the build is the fixture's own test).
@testset "round lifecycle" begin
    root = fixture_copy("round")
    cfg = G.Config.read(root)
    cd(root) do
        io = IOBuffer()
        dry = G.Preflight.preflight(cfg, "check-docs"; dry = true, io)
        dry_out = String(take!(io))
        dry == 0 || println("preflight --dry refused:\n", dry_out)      # the reason, when the arm fails inside the suite
        @test dry == 0
        @test occursin("would open", dry_out)
        @test G.Preflight.preflight(cfg, "check-docs"; io) == 0
        out = String(take!(io))
        @test occursin("Workflow({scriptPath:", out) && occursin("lanes.js", out)
        rounds = G.RoundFiles.rounds(cfg)
        @test length(rounds) == 1 && rounds[1].state == :open
        round = rounds[1].name; dir = rounds[1].dir
        rec = rounds[1].round
        @test rec["instrument"] == "check-docs" && rec["config_sha"] == G.Preflight.config_sha(cfg)
        @test isfile(joinpath(G.Preflight.workflow_dir(cfg, round), "lanes.js"))
        @test isfile(joinpath(G.Preflight.payload_dir(cfg, round), "policy.md"))
        args = JSON3.read(read(joinpath(G.Preflight.workflow_dir(cfg, round), "main.args.json"), String), Dict{String,Any})
        @test all(l -> isfile(l["brief_path"]), args["lanes"])
        @test !haskey(args, "policy")                                         # payloads are paths, never text
        # a second preflight of the same instrument is refused
        @test G.Preflight.preflight(cfg, "check-docs"; io = devnull) == 2
        # the gate refuses a build now, except under GBG_ROUND
        @test G.gate(cfg, "check-docs"; io = devnull) == 1
        withenv("GBG_ROUND" => round) do; @test G.gate(cfg, "check-docs"; io = devnull) == 0; end
        # lane files by hand: every roster lane, one finding in the first, then bank
        lanes = [Dict("nn" => lpad(i, 2, '0'), "key" => r["key"]) for (i, r) in enumerate(rec["roster"])]
        for (k, l) in enumerate(lanes)
            f = Dict("schema_version" => 1, "round" => round, "lane" => l["key"], "candidates_found" => k == 1 ? 1 : 0,
                     "checked" => ["src/FixtureA.jl"], "findings" => k == 1 ? [Dict("type" => "structure", "severity" => "minor", "confidence" => "high",
                        "title" => "a planted finding for the lifecycle test", "locations" => ["src/FixtureA.jl:1: the module docstring"],
                        "description" => "the lifecycle test's one finding, closed by an adjudication below")] : Any[])
            open(joinpath(dir, "findings", "$(l["nn"])-$(l["key"]).json"), "w") do fh; JSON3.write(fh, f); end
        end
        # lane 00-scans as prepare writes it (the scan half alone; the build is the fixture's test)
        open(joinpath(dir, "findings", "00-scans.json"), "w") do fh
            JSON3.write(fh, Dict("schema_version" => 1, "round" => round, "lane" => "scans", "candidates_found" => 0, "checked" => ["scan docs"], "findings" => Any[]))
        end
        # a DEAD lane first: remove one file, bank must refuse and freeze nothing
        victim = joinpath(dir, "findings", "$(lanes[end]["nn"])-$(lanes[end]["key"]).json"); vtext = read(victim, String); rm(victim)
        @test G.Rounds.bank(cfg, round; io = devnull) == 2
        @test !isfile(joinpath(dir, "findings.json"))
        # an INVALID lane file next (a type outside the closed set): quarantined, no first-sight sha kept,
        # rerun forgets the lane, and the replacement the re-run writes banks (the rc.1 round hit this)
        bad = JSON3.read(vtext, Dict{String,Any}); bad["candidates_found"] = 1
        bad["findings"] = [Dict("type" => "formatted", "severity" => "minor", "confidence" => "high", "title" => "a type outside the closed set",
                                "locations" => ["src/FixtureA.jl:1: x"], "description" => "the closed vocabulary refuses this type")]
        open(victim, "w") do fh; JSON3.write(fh, bad); end
        @test G.Rounds.bank(cfg, round; io = devnull) == 2
        @test isfile(victim * ".rejected.json") || isfile(replace(victim, ".json" => ".rejected.json"))
        @test !haskey(get(G.RoundFiles.read_round(dir), "lane_shas", Dict()), lanes[end]["key"])
        @test G.Rounds.rerun(cfg, round, [lanes[end]["key"]]; io = devnull) == 0
        write(victim, vtext)
        @test G.Rounds.bank(cfg, round; io = devnull) == 0
        @test isfile(joinpath(dir, "findings.json")) && isfile(joinpath(dir, "findings.md"))
        rec = G.RoundFiles.read_round(dir)
        @test haskey(rec, "findings_sha") && haskey(rec, "banked")
        findings = JSON3.read(read(joinpath(dir, "findings.json"), String), Dict{String,Any})["findings"]
        @test length(findings) == 1 && findings[1]["id"] == "$round/$(lanes[1]["key"])#1"
        # a changed config refuses every round verb until a regrade
        cpath = joinpath(root, ".gbg", "config.toml"); ctext = read(cpath, String)
        write(cpath, ctext * "\n# a comment changes the sha\n")
        @test_throws G.Rounds.RoundError G.Rounds.guard(G.Config.read(root), round; io = devnull)
        write(cpath, ctext)
        # pass open, then verdicts by hand, then grade
        @test G.Passes.pass_open(cfg, round; io) == 0
        out = String(take!(io)); @test occursin("verify-act.js", out) && occursin("verify-state.js", out)
        pd = joinpath(dir, "verdicts", "pass-1"); pass = TOML.parsefile(joinpath(pd, "pass.toml"))
        id = findings[1]["id"]; lane = lanes[1]
        act = Dict("schema_version" => 1, "lane" => lane["key"], "graded_sha256" => rec["findings_sha"], "pass_nonce" => pass["nonce"],
                   "verdicts" => [Dict("id" => id, "verdict" => "HONORED", "question" => "none", "evidence" => "x"^12, "class_surfaces" => Any[])])
        state = Dict("schema_version" => 1, "lane" => lane["key"], "graded_sha256" => rec["findings_sha"], "pass_nonce" => pass["nonce"],
                     "verdicts" => [Dict("id" => id, "verdict" => "ABSENT", "evidence" => "searched everywhere")])
        open(joinpath(pd, "act", "$(lane["nn"])-$(lane["key"]).json"), "w") do fh; JSON3.write(fh, act); end
        open(joinpath(pd, "state", "$(lane["nn"])-$(lane["key"]).json"), "w") do fh; JSON3.write(fh, state); end
        @test G.Passes.grade(cfg, round; io = devnull) == 1                      # HONORED with no class_surfaces is demoted: open
        t = JSON3.read(read(joinpath(pd, "tally.json"), String), Dict{String,Any})
        @test t["per_id"][id]["act"] == "LINE-ONLY" && t["per_id"][id]["act_demoted"] && t["demoted_by_rule"] == 1
        # a copy-forward verdict (wrong nonce) is REJECTED
        act["pass_nonce"] = "0"^32
        open(joinpath(pd, "act", "$(lane["nn"])-$(lane["key"]).json"), "w") do fh; JSON3.write(fh, act); end
        io2 = IOBuffer(); G.Passes.grade(cfg, round; io = io2); @test occursin("REJECTED", String(take!(io2)))
        # honored properly closes it
        act["pass_nonce"] = pass["nonce"]; act["verdicts"][1]["class_surfaces"] = [Dict("surface" => "src/FixtureA.jl:1", "swept" => true, "evidence" => "the only site")]
        open(joinpath(pd, "act", "$(lane["nn"])-$(lane["key"]).json"), "w") do fh; JSON3.write(fh, act); end
        @test G.Passes.grade(cfg, round; io = devnull) == 0
        t = JSON3.read(read(joinpath(pd, "tally.json"), String), Dict{String,Any})
        @test t["per_id"][id]["closed_by"] == "honored" && isempty(t["open_ids"])
        # close: the copy is untracked in the tool's repository, so "committed" holds vacuously; the
        # closing head is the tool's HEAD and the opening head is an ancestor of it
        @test G.Passes.close(cfg, round; io = devnull) == 0
        rec = G.RoundFiles.read_round(dir)
        @test G.RoundFiles.state(rec) == :closed && haskey(rec["closed_by"], "tally_sha")
        @test G.gate(cfg; io = devnull) == 0
        # a closed round is frozen: ROUND.FROZEN sees a tampered tally
        tj = joinpath(pd, "tally.json"); write(tj, read(tj, String) * "\n")
        checks, _ = G.Doctor.run(cfg; only = ["ROUND.FROZEN"], io = devnull)
        @test first(checks).status == :FAIL
        # abandon is refused on a closed round; a fresh round can be abandoned with its open ids
        @test_throws G.Rounds.RoundError G.Rounds.abandon(cfg, round, "a plateau after three passes"; io = devnull)
    end
end
