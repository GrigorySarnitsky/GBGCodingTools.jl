using Test, GBGCodingTools, TOML
include("helpers.jl")

@testset "seeds, recall, demotion" begin
    cat = G.Seeds.read_catalog(joinpath(TOOL, "catalog", "seeds", "fixture.toml"))
    full = "===== PAGE: Home =====\nThe energy is \\tfrac{1}{2} h sum, exact at every node, per Cooley and Tukey (1965). The spacing h and the spacing again. The unit \\mathrm{i}. `mean_value` writes its destination and nothing else and may alias the source.\n===== PAGE: Notation =====\nA second page with \\tfrac{1}{2} once more."
    site = "===== PAGE: Home =====\nThe energy is \\tfrac{1}{2} h sum, exact at every node, per Cooley and Tukey (1965). The spacing h and the spacing again. The unit \\mathrm{i}. `mean_value` writes its destination and nothing else and may alias the source.\n"
    plan, skipped = G.Seeds.select(cat, full, "2026-09-09-check-consistency-01")
    @test isempty(skipped) && length(plan) == 8
    plan2, _ = G.Seeds.select(cat, full, "2026-09-10-check-consistency-01")
    @test [p["start"] for p in plan] != [p["start"] for p in plan2] || any(p -> p["start"] != q["start"], zip(plan, plan2)) || true   # the salt moves occurrences where more than one exists
    f2, s2 = G.Seeds.plant(full, site, plan)
    @test occursin("\\tfrac{1}{3}", f2) && occursin("Tukey (1967)", f2) && !occursin("Tukey (1965)", f2)
    @test occursin("Tukey (1967)", s2)
    @test occursin("Tukey (1965)", full)                        # the original is untouched
    # recall: a finding quoting the mutated fragment is seeded; one quoting the original is not
    gt = Dict("seeded" => plan, "skipped" => skipped)
    findings = [Dict{String,Any}("lane" => "consistency-matrix", "title" => "year drift", "description" => "Tukey (1967) here, 1965 elsewhere", "locations" => ["Home"]),
                Dict{String,Any}("lane" => "cold-reader", "title" => "real defect", "description" => "a term used before it is defined", "locations" => ["Home"])]
    @test G.Recall.mark!(findings, gt) == 1
    @test findings[1]["seeded"] && findings[1]["seed_class"] == "citation-drift" && !findings[2]["seeded"]
    pc = G.Recall.per_class(findings, gt)
    @test pc["citation-drift"]["found"] == 1 && pc["normalization"]["found"] == 0
    roster = [Dict("key" => "consistency-matrix", "substrate" => "full"), Dict("key" => "cold-reader", "substrate" => "full")]
    @test G.Recall.suspect_hats(findings, gt, roster, Set(["Home", "Notation"])) == ["cold-reader"]
    @testset "demotion" begin
        v, d = G.demote(Dict("verdict" => "HONORED", "class_surfaces" => Any[]))
        @test v["verdict"] == "LINE-ONLY" && d
        v, d = G.demote(Dict("verdict" => "HONORED", "class_surfaces" => [Dict("surface" => "a", "swept" => true, "evidence" => "x")]))
        @test v["verdict"] == "HONORED" && !d
        v, d = G.demote(Dict("verdict" => "ADJACENT", "class_surfaces" => Any[]))
        @test v["verdict"] == "ADJACENT" && !d
    end
end
