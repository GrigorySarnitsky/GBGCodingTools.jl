using Test, GBGCodingTools, JSON3, TOML
include("helpers.jl")

@testset "schemas" begin
    names = [replace(f, ".schema.json" => "") for f in readdir(joinpath(TOOL, "schema")) if endswith(f, ".schema.json")]
    @test length(names) == 18
    for n in names
        s = G.load_schema(n)
        @test s["type"] == "object"
    end
    for inst in ("check-docs", "check-consistency", "bug-hunt", "audit-changes")
        s = G.instrument_schema(inst)
        @test haskey(s["properties"], "args") && haskey(s["properties"], "lane_file")
    end
    @testset "validator keywords" begin
        s = Dict("type" => "object", "additionalProperties" => false, "required" => ["a"],
                 "properties" => Dict("a" => Dict("type" => "integer", "minimum" => 1), "b" => Dict("type" => ["string", "null"]),
                                      "c" => Dict("allOf" => [Dict("required" => ["a"])])))
        @test isempty(G.validate(s, Dict("a" => 2, "b" => nothing)))
        @test !isempty(G.validate(s, Dict("a" => 0)))                      # minimum
        @test !isempty(G.validate(s, Dict("a" => 1, "z" => 1)))            # closed keys
        @test !isempty(G.validate(s, Dict("b" => "x")))                    # required
        @test !isempty(G.validate(Dict("type" => "string", "pattern" => "^v"), "1.0"))
    end
    @testset "every hat validates" begin
        hat = G.load_schema("hat")
        for f in readdir(joinpath(TOOL, "catalog", "hats"); join = true)
            endswith(f, ".toml") && @test isempty(G.validate(hat, TOML.parsefile(f)))
        end
    end
    @testset "the home page's counts are the real ones" begin
        # every number the home page cites is re-measured here; a cited count nothing asserts drifts
        page = read(joinpath(TOOL, "docs", "src", "index.md"), String)
        n(re) = (m = match(re, page); m === nothing ? -1 : parse(Int, m.captures[1]))
        @test n(r"There are (\d+)\s*\n?\s*verbs") == length(G.VERBS)
        @test n(r"(\d+) scans over docstrings") == length(G.scan_catalog())
        @test n(r"(\d+) read-only checks") == length(G.Doctor.CHECKS)
        @test n(r"The policy is (\d+) rules") == length(TOML.parsefile(joinpath(TOOL, "policy", "RULES.toml"))["rule"])
    end
    @testset "the transitional Python is gone (1.6)" begin
        @test !isfile(joinpath(TOOL, "src", "CLI", "consolidate.py"))
        @test isempty(filter(f -> endswith(f, ".py"), vcat([joinpath(d, f) for (d, _, fs) in walkdir(joinpath(TOOL, "src")) for f in fs],
                                                          [joinpath(d, f) for (d, _, fs) in walkdir(joinpath(TOOL, "instruments")) for f in fs])))
    end
    @testset "RULES.toml matches the policy files" begin
        rules = TOML.parsefile(joinpath(TOOL, "policy", "RULES.toml"))["rule"]
        # the two sets, each derived — a hard-coded count drifts silently (RULE.TEST.COUNTS_REMEASURED),
        # which it did: two rules were added and this test still asserted the old number
        headings = Set{String}()
        for f in readdir(joinpath(TOOL, "policy"); join = true)
            endswith(f, ".md") || continue
            for m in eachmatch(r"^### (RULE\.[A-Z]+\.[A-Z_]+)\s*$"m, read(f, String)); push!(headings, m.captures[1]); end
        end
        @test Set(r["id"] for r in rules) == headings
        for r in rules
            text = replace(read(joinpath(TOOL, "policy", r["file"]), String), r"\s+" => " ")
            @test occursin(r["sentinel"], text)
            @test occursin("### " * r["id"], read(joinpath(TOOL, "policy", r["file"]), String))
        end
    end
end
