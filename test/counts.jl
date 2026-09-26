# test/counts.jl — prose measured against the program: a count cited in a sentence is re-measured here,
# and a rule reaches the rulebook a session loads. These stood in test/schemas.jl until Phase 5, the
# last of what that file held once the schemas became Julia types.
using Test, GBGCodingTools
include("helpers.jl")

@testset "counts and reach" begin
    @testset "no source cites a count of scans, verbs or checks" begin
        # the config, Init's defaults and the plan all carried "the 39 scans" while the catalogue held 41,
        # and the plan documented `gbg seed` and `gbg recall`, which are not verbs (2026-09-09). A count in
        # prose that a program can measure belongs in the program, not the sentence.
        files = [joinpath(r, f) for (r, _, fs) in walkdir(joinpath(TOOL, "src")) for f in fs if endswith(f, ".jl")]
        for f in files
            text = read(f, String)
            @test !occursin(r"\b\d+ scans\b", text)
            @test !occursin(r"\b\d+ (verbs|read-only checks)\b", text)
        end
    end

    @testset "the home page's counts are the real ones" begin
        # every number the home page cites is re-measured here; a cited count nothing asserts drifts
        page = read(joinpath(TOOL, "docs", "src", "index.md"), String)
        n(re) = (m = match(re, page); m === nothing ? -1 : parse(Int, m.captures[1]))
        @test n(r"There are (\d+)\s*\n?\s*verbs") == length(G.VERBS)
        @test n(r"The policy is (\d+) rules") == length(G.Catalogue.RULES)
    end

    # `RULES.toml matches the policy files` and the `check`-column half of RULE.TEST.RULE_WITH_CHECK stood
    # here until 2026-09-17. Both compared two copies of the rulebook — a TOML register and a directory
    # of prose — and `policy/` is deleted: a rule is one value, and the rulebook is rendered from it.
    @testset "every rule declares what catches its next violation" begin
        for r in G.Catalogue.RULES
            @test r.check !== nothing || !isempty(r.unchecked_reason)   # a check, or why there is none
            @test !isempty(r.statement) && !isempty(r.why)
        end
        # and every one of them reaches the rendered rulebook a session loads: a rule in no file is a
        # rule nobody reads, which is the same silence the register's empty `check` column was
        rendered = join(G.Render.produce(e.generator, G.ConfigIO.read_config(TOOL)) for e in G.Render.POLICY_FILES)
        for r in G.Catalogue.RULES
            @test occursin("### " * String(r.id) * "\n", rendered)
        end
    end
end
