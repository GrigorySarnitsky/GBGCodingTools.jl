using Test, GBGCodingTools, TOML, Dates
include("helpers.jl")

# A package whose whole displayed surface is homed in an extension that is not loaded: `ghost` is
# declared and never given a method, exactly as `makedocs` is homed in this tool's Documenter extension.
module ExtensionHomed
    function ghost end
end

# a rebaseline names every ceiling it raises before it writes (2026-09-12-audit-changes-01)
@testset "a prose-shape rebaseline lists what it raises" begin
    root = fixture_copy("rebaseline")
    cfg = G.Config.read(root)
    G.write_prose_shape_baseline(cfg)
    @test isempty(G.prose_shape_changes(cfg))
    page = joinpath(root, "docs", "src", "notation.md")
    write(page, read(page, String) * "\n" * "one more word "^10 * "\n\n## A section no baseline row has\n\nnew text here\n")
    ch = G.prose_shape_changes(cfg)
    @test any(l -> startswith(l, "RAISED") && occursin("notation.md", l), ch)
    @test any(l -> startswith(l, "NEW") && occursin("A section no baseline row has", l), ch)
    G.write_prose_shape_baseline(cfg)
    @test isempty(G.prose_shape_changes(cfg))
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
    # signature_fidelity's `examined` is the scan's population, and population 0 is the DEAD refusal. It
    # counts what was COMPARED: an extension-homed binding with no methods loaded is skipped, so it must
    # not be counted, and a package of nothing but those is DEAD rather than clean.
    # RULE.TEST.BOTH_DIRECTIONS. A package function wins its own name against a Base export of the same
    # name: `Config.read` and `Git.run` collide with `Base.read` and `Base.run`. Ordering the externals
    # last does NOT achieve this — `isdefined(pkg, :read)` is true through the implicit `using Base` — so
    # the module that OWNS the name is searched first, and this test fails if that ordering is undone.
    @testset "a package function wins its own name" begin
        tcfg = G.Config.read(TOOL)                                       # the tool itself: it has the collisions
        pkg = G.Reflection.load_package(tcfg)
        mods = [getfield(pkg, Symbol(m)) for m in tcfg["package"]["modules"] if isdefined(pkg, Symbol(m))]
        for n in (:read, :list, :report)
            f = G.TestHarness.resolve_function(n, pkg, mods)
            @test f !== nothing && parentmodule(f) !== Base             # not the Base generic
        end
        @test parentmodule(G.TestHarness.resolve_function(:read, pkg, mods)) === G.Config
    end
    # `examined` is the scan's population and counts what was COMPARED. Both directions, and the second
    # is the one that can fail: on the fixture every displayed binding has methods, so the count is the
    # whole surface; on a package whose displayed surface is entirely extension-homed nothing is
    # compared, the count is 0 — moving the increment above the skip would make it 1 — and the scan is
    # DEAD carrying the names as its reason, since "measured nothing" without the why is a puzzle.
    @testset "signature_fidelity counts what it compared" begin
        n = Ref(0)
        rows = G.Reflection.signature_fidelity(G.Config.read(FIXTURE); examined = n)
        @test n[] > 0                                                    # population 0 would be DEAD
        @test isempty(rows)                                              # the fixture skips nothing
        root = fixture_copy("extension-homed")
        write(joinpath(root, "src", "Ghost.jl"), """
        \"\"\"
            ghost(x; opt = 1)

        A binding whose methods live in an extension that is not loaded.
        \"\"\"
        function ghost end
        """)
        gcfg = G.Config.read(root)
        m = Ref(0)
        grows = G.Reflection.signature_fidelity(gcfg; pkg = ExtensionHomed, examined = m)
        @test any(r -> occursin("ghost", r) && occursin("EXTENSION-HOMED", r), grows)
        @test m[] == 0                                                   # a skipped binding is NOT compared
        res = G.ScanResult("SCAN.SIGNATURE_FIDELITY", "RULE.DOC.SIGNATURE_FIDELITY", "triage", G.Hit[], m[], 0,
                           "1 extension-homed binding(s) not compared (no methods loaded): ghost")
        io = IOBuffer(); @test G.report([res]; io) == 2                   # DEAD, not clean
        out = String(take!(io))
        @test occursin("DEAD", out) && occursin("measured nothing", out) && occursin("ghost", out)
        # the wrapper builds that reason itself, and run_scan carries a scan's third element as its note:
        # this tool homes `makedocs` in its Documenter extension, so the note names it while the
        # population stays what was compared
        r = G.run_scan(G.Config.read(TOOL), CATALOG["SCAN.SIGNATURE_FIDELITY"]; ledger = Dict{String,Any}[])
        @test occursin("makedocs", r.note) && occursin("not compared", r.note)
        @test r.population > 0 && all(h -> !occursin("EXTENSION-HOMED", h.text), r.hits)
    end
    # RULE.DOC.SIGNATURE_MIRROR's variation point, `rubric.signature_types`, in BOTH its forms over the
    # same corpus: under `names` a type in the signature's argument list is the hit, under `mirror` an
    # argument the method types and the signature leaves bare. A return annotation after `->` is not an
    # argument and is never a hit either way, which is the half a `::`-anywhere pattern would get wrong.
    @testset "a typed argument in a signature, and a typed return that is not one" begin
        r = G.run_scan(cfg, CATALOG["SCAN.SIGNATURE_TYPED"]; ledger = Dict{String,Any}[])
        @test r.population > 0
        @test any(h -> occursin("typed_signature", h.text), r.hits)
        @test !any(h -> occursin("returns_typed", h.text), r.hits)      # `-> Bool` is a return, not an argument
    end
    @testset "the stricter form, which PF takes: a bare argument the method types" begin
        strict = defects_config(); strict["rubric"]["signature_types"] = "mirror"
        r = G.run_scan(strict, CATALOG["SCAN.SIGNATURE_TYPED"]; ledger = Dict{String,Any}[])
        @test r.population > 0
        @test any(h -> occursin("mirrored_bare", h.text) && occursin("`v`", h.text), r.hits)  # the method types it
        @test !any(h -> occursin("typed_signature", h.text), r.hits)    # it mirrors already: no hit under mirror
        @test !any(h -> occursin("returns_typed", h.text), r.hits)      # its method leaves `x` untyped too
        # and the two forms disagree about the same corpus, which is what a variation point means
        names_hits = G.run_scan(defects_config(), CATALOG["SCAN.SIGNATURE_TYPED"]; ledger = Dict{String,Any}[]).hits
        @test Set(h.text for h in names_hits) != Set(h.text for h in r.hits)
    end
    # SCAN.ID_RESOLVES. Its three false-positive shapes were MEASURED over the tool's own corpus before it
    # was built (964 references, 11 unresolved, all 11 artefacts), and each is a direction here: a dead id
    # is the hit, a LIVE id is not, and a bare family PREFIX is not. RULE.TEST.BOTH_DIRECTIONS — a scan
    # hitting every citation alike would pass the must-hit and be worthless.
    @testset "a dead tool id, and the live id and family prefix that are not" begin
        r = G.run_scan(cfg, CATALOG["SCAN.ID_RESOLVES"]; ledger = Dict{String,Any}[])
        @test r.population > 0
        @test any(h -> occursin("RULE.DOC.NOSUCHRULE", h.text), r.hits)
        @test !any(h -> occursin("`RULE.DOC.CURRENT` resolves", h.text), r.hits)   # a rule that exists
        @test !any(h -> occursin("`RULE.DOC` resolves", h.text), r.hits)           # a family, not an id
        # The clean direction is the TOOL's own corpus, which cites its registers constantly: every id in it
        # resolves, so the scan is silent. This is the assertion that fails when a rule or check is renamed
        # and the prose citing it is not, which is the whole reason the scan exists.
        rt = G.run_scan(G.Config.read(TOOL), CATALOG["SCAN.ID_RESOLVES"]; ledger = Dict{String,Any}[])
        @test rt.population > 0
        @test isempty(rt.hits)
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
        # zero population is DEAD whatever the ledger removed: a scan that measured nothing yet hit something
        # has a broken counter, and an exemption must not hide it (2026-09-11-audit-changes-02)
        hid = G.ScanResult("SCAN.X", "RULE.X", "hard", G.Hit[], 0, 1, "")
        @test G.report([hid]; io = devnull) == 2
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
    # A policy waiver resolves against the scan's CANONICAL rule only. A waiver of the SECOND rule of a
    # two-rule scan was first silently void (RULE.CIT.DOI rendered into deviations.md as granted while the
    # scan kept failing: 2026-09-12-check-docs-01 catalogues#1), then silently wide (it disabled the whole
    # scan, the canonical rule with it: 2026-09-12-audit-changes-02). It is refused now, on all three
    # two-rule scans, and the canonical waiver still works. Each case asserts the scan hits at all, since
    # "disabled" and "had no hits anyway" look identical from the outside.
    @testset "a policy waiver reaches a scan through its canonical rule, and no other" begin
        pol(rule) = [Dict{String,Any}("id" => rule, "scope" => "policy", "target" => "*",
                                      "reason" => "x"^40, "recorded" => Dates.today())]
        d = defects_config()
        for (scan, canonical, second) in (("SCAN.DOI_CROSSCHECK", "RULE.CIT.FULL_INLINE", "RULE.CIT.DOI"),
                                          ("SCAN.DEAD_REF", "RULE.DOC.NO_DEAD_REFS", "RULE.CIT.NO_INACCESSIBLE"),
                                          ("SCAN.API_PAGE_STRUCTURE", "RULE.DOC.INTERNAL_API", "RULE.DOC.API_GROUPING"))
            row = CATALOG[scan]
            @test Set(G.rules_for_scan(scan)) == Set([canonical, second]) && row["rule"] == canonical
            @test G.unreachable_waiver_scans(second) == [scan] && isempty(G.unreachable_waiver_scans(canonical))
            @test !isempty(G.run_scan(d, row; ledger = Dict{String,Any}[]).hits)          # it hits at all
            r = G.run_scan(d, row; ledger = pol(canonical))
            @test isempty(r.hits) && r.exempted > 0                                       # the canonical waiver works
            @test_throws G.Ledger.LedgerError G.run_scan(d, row; ledger = pol(second))     # the second rule's is refused
        end
        @test !isempty(G.run_scan(d, CATALOG["SCAN.DOI_CROSSCHECK"]; ledger = pol("RULE.TEX.MATHBF")).hits)  # an unrelated rule waives nothing
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
