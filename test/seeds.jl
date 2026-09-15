using Test, GBGCodingTools, TOML
include("helpers.jl")

# A documentation round's corpus is the source TREE, not a rendered manuscript, so its seeds are planted
# in a copy outside the repository and the lanes are pointed at that. Two properties carry the whole
# design: the repository is never mutated, and the ground truth is REPRODUCIBLE from the untouched tree
# plus the salt — which is why nothing on disk between prepare and bank can answer the panel.
@testset "a docs round is seeded in a copy, never in the tree" begin
    root = fixture_copy("seeded-docs")
    files = ["src/FixtureA.jl", "docs/src/notation.md"]
    a = joinpath(root, files[1])
    write(a, read(a, String) * "\n# the exit contract: 2 cannot evaluate\n")
    before = read(a, String)
    cat = G.Seeds.read_catalog(joinpath(TOOL, ".gbg", "seeds.toml"))
    m = G.Seeds.file_manuscript(root, files)
    @test occursin("===== PAGE: src/FixtureA.jl =====", m) && occursin("2 cannot evaluate", m)
    plan, _ = G.Seeds.select(cat, m, "2026-01-01-check-docs-01")
    @test !isempty(plan) && any(s -> s["page"] == "src/FixtureA.jl", plan)
    # a lane's surface is a file OR a directory: copying only the files left six of thirteen lanes with
    # no corpus at all, and two of them reported on the fragments they could still reach
    dirsurface = "docs/src"
    dest = mktempdir()
    for f in vcat(files, [dirsurface])
        src = joinpath(root, f); d = joinpath(dest, f); mkpath(dirname(d)); cp(src, d; force = true)
    end
    @test isdir(joinpath(dest, dirsurface)) && !isempty(readdir(joinpath(dest, dirsurface)))
    planted = G.Seeds.plant_files(dest, m, plan)
    @test length(planted) == length(plan)          # every planned seed lands, or the round measures a lie
    # the occurrence index is counted INSIDE the page: `eachmatch` over a SubString reports offsets
    # relative to it, and comparing them with the seed's absolute start asks for one occurrence past the
    # end — which skipped the seed in silence. A page with the anchor twice is the case that catches it.
    twice = joinpath(root, "src", "FixtureB.jl")
    write(twice, "# 2 cannot evaluate here\n# and again: 2 cannot evaluate\n")
    m2 = G.Seeds.file_manuscript(root, ["docs/src/notation.md", "src/FixtureB.jl"])
    p2, _ = G.Seeds.select(cat, m2, "2026-01-01-check-docs-01")
    hit = [s for s in p2 if s["page"] == "src/FixtureB.jl"]
    if !isempty(hit)
        d2 = mktempdir()
        for f in ("docs/src/notation.md", "src/FixtureB.jl")
            mkpath(dirname(joinpath(d2, f))); cp(joinpath(root, f), joinpath(d2, f); force = true)
        end
        @test length(G.Seeds.plant_files(d2, m2, p2)) == length(p2)
        @test occursin("2 a second finding", read(joinpath(d2, "src", "FixtureB.jl"), String))
        rm(d2; recursive = true, force = true)
    end
    @test occursin("2 a second finding", read(joinpath(dest, files[1]), String))   # the copy carries the seed
    @test read(a, String) == before                                                # the tree is untouched
    @test !occursin("2 a second finding", read(a, String))
    # the ground truth is recomputed at bank from the untouched tree: same salt, same plan
    again, _ = G.Seeds.select(cat, G.Seeds.file_manuscript(root, files), "2026-01-01-check-docs-01")
    @test [s["id"] for s in again] == [s["id"] for s in plan]
    @test [s["original"] for s in again] == [s["original"] for s in plan]
    # a different round salts differently, so two rounds do not plant the same occurrence by construction
    other, _ = G.Seeds.select(cat, G.Seeds.file_manuscript(root, files), "2026-02-02-check-docs-07")
    @test [s["id"] for s in other] == [s["id"] for s in plan]                       # same classes
    rm(dest; recursive = true, force = true)
end

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
    # a docs lane reads a file set, so it is judged only on the seeds planted in its own files (a
    # directory standing for everything under it), and a lane naming no files — a cross lane — on every
    # seed. Both directions: without `lane_files` every docs lane was judged on every seed in the round.
    sg = Dict("seeded" => [Dict("page" => p) for p in ("docs/a.md", "docs/a.md", "src/x.jl", "catalog/h/y.toml")])
    lanes = [Dict("key" => k, "substrate" => "surface") for k in ("pages", "src", "catalogues", "cold-reader")]
    lf = Dict("pages" => ["docs/a.md"], "src" => ["src/x.jl"], "catalogues" => ["catalog"], "cold-reader" => String[])
    @test G.Recall.suspect_hats(Dict{String,Any}[], sg, lanes, Set{String}(); lane_files = lf) == ["pages", "cold-reader"]
    @test length(G.Recall.suspect_hats(Dict{String,Any}[], sg, lanes, Set{String}())) == 4   # the old view
    @testset "demotion" begin
        v, d = G.demote(Dict("verdict" => "HONORED", "class_surfaces" => Any[]))
        @test v["verdict"] == "LINE-ONLY" && d
        v, d = G.demote(Dict("verdict" => "HONORED", "class_surfaces" => [Dict("surface" => "a", "swept" => true, "evidence" => "x")]))
        @test v["verdict"] == "HONORED" && !d
        v, d = G.demote(Dict("verdict" => "ADJACENT", "class_surfaces" => Any[]))
        @test v["verdict"] == "ADJACENT" && !d
    end
end

# A class whose anchor rotted out of the corpus is not planted. The round is NOT refused for it — it still
# measures the classes that plant — but the skip is recorded in ROUND.toml and named, never silent
# (2026-09-12-audit-changes-02, where a refusal had replaced the silence with no measurement at all).
@testset "a seed class that cannot plant is recorded, not refused" begin
    root = fixture_copy("seed-skip")
    cfg = G.Config.read(root)
    name = "2026-01-01-check-docs-01"
    dir = joinpath(root, ".gbg", "rounds", name); mkpath(dir)
    rec = merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => name, "instrument" => "check-docs",
        "schema_version" => 1, "head" => "0"^40, "roster" => Any[], "cost" => "economy", "strength" => "economy",
        "hostname" => "t", "model_hint" => "sonnet", "opened" => "2026-01-01T00:00:00", "dead_lanes" => String[],
        "passes" => 0, "seed_salt" => name))
    write_round(dir, rec)
    cat = G.Seeds.read_catalog(joinpath(TOOL, ".gbg", "seeds.toml"))
    m = G.Seeds.file_manuscript(root, ["docs/src/notation.md"])
    plan, skipped = G.Seeds.select(cat, m, name)
    @test !isempty(skipped)                                  # the fixture page carries few of the tool's anchors
    out = IOBuffer()
    G.Rounds.note_seed_skips!(dir, rec, skipped, ".gbg/seeds.toml"; io = out)
    @test occursin("NOT planted", String(take!(out)))
    @test G.RoundFiles.read_round(dir)["seed_skipped"] == sort(skipped)       # recorded, and schema-valid
    G.Rounds.note_seed_skips!(dir, rec, String[], ".gbg/seeds.toml"; io = devnull)
    @test !haskey(G.RoundFiles.read_round(dir), "seed_skipped")               # re-anchored: the record clears
    # but a plan that plants NOTHING is refused, by both documentation instruments' prepare
    # (the consistency path lost this with the partial refusal: 2026-09-15-audit-changes-01)
    nothing_at_all, all_skipped = G.Seeds.select(cat, "no anchor of any class occurs in this text", name)
    @test isempty(nothing_at_all)
    out = IOBuffer()
    @test G.Rounds.plants_nothing(nothing_at_all, all_skipped, ".gbg/seeds.toml", "the manuscript"; io = out)
    @test occursin("plants nothing measures nothing", String(take!(out)))
    @test !G.Rounds.plants_nothing([Dict{String,Any}("id" => "one planted seed")], all_skipped, ".gbg/seeds.toml", "the manuscript"; io = devnull)
    src = read(joinpath(TOOL, "src", "CLI", "Rounds.jl"), String)
    @test count(r"plants_nothing\(plan, skipped, .*\) && return 2", src) == 2   # both prepare paths ask it
    # the skip reaches the tally beside recall, which is where a narrowed measurement is compared
    t = Dict{String,Any}("schema_version" => 1, "round" => name, "pass" => 1, "per_id" => Dict{String,Any}(),
        "totals" => Dict("findings" => 0, "seeded" => 0, "closed" => 0, "open" => 0), "demoted_by_rule" => 0,
        "adjudicated_share" => 0.0, "suspect_hats" => String[], "dead_lanes" => String[], "rejected_files" => String[],
        "open_ids" => String[], "pending_state" => String[], "plateau" => Dict("passes_flat" => 0), "seed_skipped" => sort(skipped))
    @test isempty(G.validate(G.load_schema("tally"), t))
    @test occursin("tally[\"seed_skipped\"] = sk", read(joinpath(TOOL, "src", "CLI", "Passes.jl"), String))
end
