using Test, GBGCodingTools, TOML, Dates
include("helpers.jl")

# a rebaseline names every ceiling it raises before it writes (2026-09-12-audit-changes-01)
@testset "a prose-shape rebaseline lists what it raises" begin
    root = fixture_copy("rebaseline")
    cfg = G.Config.read(root)
    G.Catalogue.Shape.write_baseline(root, G.ConfigIO.read_config(root))
    @test isempty(G.Catalogue.Shape.changes(root, G.ConfigIO.read_config(root)))
    page = joinpath(root, "docs", "src", "notation.md")
    write(page, read(page, String) * "\n" * "one more word "^10 * "\n\n## A section no baseline row has\n\nnew text here\n")
    ch = G.Catalogue.Shape.changes(root, G.ConfigIO.read_config(root))
    @test any(l -> startswith(l, "RAISED") && occursin("notation.md", l), ch)
    @test any(l -> startswith(l, "NEW") && occursin("A section no baseline row has", l), ch)
    G.Catalogue.Shape.write_baseline(root, G.ConfigIO.read_config(root))
    @test isempty(G.Catalogue.Shape.changes(root, G.ConfigIO.read_config(root)))
end

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
    # RULE.TEST.BOTH_DIRECTIONS. A package function wins its own name against a Base export of the same
    # name: `Config.read` and `Git.run` collide with `Base.read` and `Base.run`. Ordering the externals
    # last does NOT achieve this — `isdefined(pkg, :read)` is true through the implicit `using Base` — so
    # the module that OWNS the name is searched first, and this test fails if that ordering is undone.
    @testset "a package function wins its own name" begin
        tcfg = G.Config.read(TOOL)                                       # the tool itself: it has the collisions
        pkg = G.Reflection.load_package(tcfg)
        mods = [getfield(pkg, Symbol(m)) for m in tcfg["package"]["modules"] if isdefined(pkg, Symbol(m))]
        # `list` was Rounds.list and went with the round machinery on 2026-09-17; `run` and `diff` collide
        # with Base the same way and are here in its place.
        for n in (:read, :run, :diff, :report)
            f = G.TestHarness.resolve_function(n, pkg, mods)
            @test f !== nothing && parentmodule(f) !== Base             # not the Base generic
        end
        @test parentmodule(G.TestHarness.resolve_function(:read, pkg, mods)) === G.Config
    end
    # The two signature_fidelity testsets stood here until 2026-09-17 — the population it counted and the
    # extension-homed binding it skips. The scan is retired: RULE.DOC.SIGNATURE_FIDELITY is a value now,
    # and what it judges is shown by the rule's own examples in test/rules.jl.
    # RULE.DOC.SIGNATURE_MIRROR's variation point, `rubric.signature_types`, in BOTH its forms over the
    # same corpus: under `names` a type in the signature's argument list is the hit, under `mirror` an
    # argument the method types and the signature leaves bare. A return annotation after `->` is not an
    # argument and is never a hit either way, which is the half a `::`-anywhere pattern would get wrong.
    # The two SIGNATURE_TYPED testsets stood here until 2026-09-17. That scan's rule is a value now
    # (RULE.DOC.SIGNATURE_MIRROR), and what it judges is shown by the rule's own examples in test/rules.jl.
    # SCAN.ID_RESOLVES. Its three false-positive shapes were MEASURED over the tool's own corpus before it
    # was built (964 references, 11 unresolved, all 11 artefacts), and each is a direction here: a dead id
    # is the hit, a LIVE id is not, and a bare family PREFIX is not. RULE.TEST.BOTH_DIRECTIONS — a scan
    # hitting every citation alike would pass the must-hit and be worthless.
    # The live-id testset stood here until 2026-09-17: RULE.DOC.CURRENT is a value now and its own
    # examples show what resolves and what does not (test/rules.jl).
    @testset "the clean fixture passes every hard scan" begin
        results, code = G.scan_docs(G.Config.read(FIXTURE); hard_only = true, io = devnull)
        @test code == 0
        @test all(r -> r.population > 0 || r.exempted > 0, results)
    end
    # The ledger testset stood here until 2026-09-17. It had moved from scan to scan as each rule was
    # converted, which was the sign to stop: what a package turns off is a `Switch` in the new design, and
    # `Checks.applies` decides it — held by the switch tests in test/rules.jl.
    # A policy waiver resolves against the scan's CANONICAL rule only. A waiver of the SECOND rule of a
    # two-rule scan was first silently void (RULE.CIT.DOI rendered into deviations.md as granted while the
    # scan kept failing: 2026-09-12-check-docs-01 catalogues#1), then silently wide (it disabled the whole
    # scan, the canonical rule with it: 2026-09-12-audit-changes-02), then an error that crashed every scan
    # (2026-09-15-audit-changes-01). Now the scan keeps running and SAYS the waiver does not reach it, for
    # every target shape, on all three two-rule scans, and the canonical waiver still works. Each case
    # asserts the scan hits at all, since "disabled" and "had no hits anyway" look identical from outside.
    @testset "a policy waiver reaches a scan through its canonical rule, and no other" begin
        pol(rule) = [Dict{String,Any}("id" => rule, "scope" => "policy", "target" => "*",
                                      "reason" => "x"^40, "recorded" => Dates.today())]
        d = defects_config()
        # SCAN.DEAD_REF and SCAN.API_PAGE_STRUCTURE left this list as their rules were converted; one
        # two-rule scan remains to hold the behaviour.
        for (scan, canonical, second) in (("SCAN.DOI_CROSSCHECK", "RULE.CIT.FULL_INLINE", "RULE.CIT.DOI"),)
            row = CATALOG[scan]
            @test Set(G.rules_for_scan(scan)) == Set([canonical, second]) && row["rule"] == canonical
            @test G.unreachable_waiver_scans(second) == [scan] && isempty(G.unreachable_waiver_scans(canonical))
            @test !isempty(G.run_scan(d, row; ledger = Dict{String,Any}[]).hits)          # it hits at all
            r = G.run_scan(d, row; ledger = pol(canonical))
            @test isempty(r.hits) && r.exempted > 0                                       # the canonical waiver works
            for target in ("*", "src/FixtureA.jl")                                         # neither refused nor a disable
                led = [merge(pol(second)[1], Dict{String,Any}("target" => target))]
                r2 = G.run_scan(d, row; ledger = led)
                @test length(r2.hits) == length(G.run_scan(d, row; ledger = Dict{String,Any}[]).hits) && r2.exempted == 0
                @test occursin("does not reach this scan", r2.note) && occursin(second, r2.note)
            end
            @test isempty(G.unreached_waivers(pol(canonical), row))
        end
        @test !isempty(G.run_scan(d, CATALOG["SCAN.DOI_CROSSCHECK"]; ledger = pol("RULE.TEX.MATHBF")).hits)  # an unrelated rule waives nothing
    end
    # The AI-banner testsets stood here until 2026-09-17: RULE.DOC.AI_BANNER is a value now, and it runs
    # over the rationale and Literate file sets alone, so the home page is outside it by construction.
    @testset "prose extraction" begin
        pl = G.prose_lines(cfg, "src/FixtureA.jl")
        @test all(p -> p.indocstring, pl)
        @test !any(p -> occursin(r"^function|^end$|^struct", strip(p.raw)), pl)
        ds = G.Reflection.docstrings(FIXTURE, ["src/FixtureA.jl"])
        @test length(ds) == 5 && all(d -> !startswith(d.signature, "function"), ds)
    end
end
