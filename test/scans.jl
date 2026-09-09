using Test, GBGCodingTools, TOML, Dates
include("helpers.jl")

@testset "scans" begin
    @testset "registry ≡ catalogue, every scan has a fixture pair" begin
        ids = Set(keys(CATALOG)); reg = Set(keys(G.SCANS))
        @test ids == reg
        planted = Set(d["scan"] for d in DEFECTS["defect"])
        for (id, row) in CATALOG
            row["tier"] == "argcov_policy" && continue
            @test id in planted                                            # a must-hit
        end
        for row in values(CATALOG)
            @test all(c -> any(d -> d["class"] == c, DEFECTS["defect"]), row["fixture"])
        end
    end
    cfg = defects_config()
    loaded = try G.Reflection.load_package(cfg); true catch err; @warn "the fixture package did not load" err; false end
    @test loaded                                                        # a silent skip of the four reflection scans is not a pass
    @testset "must-hit: $(d["class"])" for d in DEFECTS["defect"]
        id = d["scan"]
        (!loaded && id in REFLECTION) && (@test_skip false; continue)
        html = startswith(d["file"], "defects/html")
        files = html ? G.built_pages(joinpath(FIXTURE, d["file"])) : nothing
        if html
            mkpath(joinpath(FIXTURE, ".gbg", "scratch"))
            cp(joinpath(FIXTURE, "defects", "html", "public_surface.json"), joinpath(FIXTURE, ".gbg", "scratch", "public_surface.json"); force = true)
        end
        r = G.run_scan(cfg, CATALOG[id]; ledger = Dict{String,Any}[], files)
        @test r.population > 0
        @test any(h -> occursin(d["fragment"], h.text) && (html || occursin(basename(d["file"]), h.file) || h.file == ""), r.hits)
    end
    @testset "clean twin: $(c["scan"]) on $(c["file"])" for c in DEFECTS["clean"]
        id = c["scan"]
        (!loaded && id in REFLECTION) && (@test_skip false; continue)
        html = startswith(c["file"], "defects/html")
        files = html ? G.built_pages(joinpath(FIXTURE, c["file"])) : nothing
        r = G.run_scan(cfg, CATALOG[id]; ledger = Dict{String,Any}[], files)
        @test isempty([h for h in r.hits if html || h.file == c["file"]])
    end
    @testset "the clean fixture passes every hard scan" begin
        results, code = G.scan_docs(G.Config.read(FIXTURE); hard_only = true, io = devnull)
        @test code == 0
        @test all(r -> r.population > 0 || r.exempted > 0, results)
    end
    @testset "a dead scan is exit 2" begin
        c2 = fixture_config()                                            # every surface the scan reads, emptied
        c2["surfaces"]["rationale"] = String[]; c2["surfaces"]["literate"] = String[]; c2["surfaces"]["pages"] = String[]
        r = G.run_scan(c2, CATALOG["SCAN.AI_BANNER"]; ledger = Dict{String,Any}[])
        @test r.population == 0
        @test G.report([r]; io = devnull) == 2
    end
    @testset "the ledger disables and refines" begin
        row = CATALOG["SCAN.REGISTER"]
        led = [Dict{String,Any}("id" => "SCAN.REGISTER", "scope" => "scan", "target" => "*", "reason" => "x"^40, "recorded" => Dates.today())]
        r = G.run_scan(cfg, row; ledger = led)
        @test isempty(r.hits) && r.exempted > 0
        led2 = [Dict{String,Any}("id" => "SCAN.REGISTER", "scope" => "scan", "target" => "defects/Defects.jl", "reason" => "x"^40, "recorded" => Dates.today())]
        r2 = G.run_scan(cfg, row; ledger = led2)
        # a file-targeted entry exempts THAT file and nothing else: the planted data-surface hit survives
        @test r2.exempted == 1 && length(r2.hits) == 1 && r2.hits[1].file == "defects/data-defects.toml"
        led3 = [Dict{String,Any}("id" => "SCAN.REGISTER", "scope" => "scan", "target" => "*", "reason" => "x"^40, "recorded" => Dates.today(), "match" => Dict("arg_type" => "Integer"))]
        @test_throws G.Ledger.LedgerError G.run_scan(cfg, row; ledger = led3)   # a text scan refuses arg_type
    end
    @testset "the home page never carries the AI banner" begin
        root = fixture_copy("home-banner")
        c = G.Config.read(root)
        idx = joinpath(root, "docs", "src", "index.md")
        row = CATALOG["SCAN.AI_BANNER"]
        @test isempty(G.run_scan(c, row; ledger = Dict{String,Any}[]).hits)          # the clean twin
        write(idx, join(G.AI_BANNER, "\n") * "\n\n" * read(idx, String))
        hits = G.run_scan(c, row; ledger = Dict{String,Any}[]).hits
        @test length(hits) == 1 && hits[1].file == "docs/src/index.md" && occursin("never carries", hits[1].text)
    end
    @testset "prose extraction" begin
        pl = G.prose_lines(cfg, "src/FixtureA.jl")
        @test all(p -> p.indocstring, pl)
        @test !any(p -> occursin(r"^function|^end$|^struct", strip(p.raw)), pl)
        ds = G.Reflection.docstrings(FIXTURE, ["src/FixtureA.jl"])
        @test length(ds) == 5 && all(d -> !startswith(d.signature, "function"), ds)
    end
end
