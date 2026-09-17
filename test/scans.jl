# test/scans.jl — what survives of the text-scan engine's self-tests.
#
# This file was the scan engine's whole evidence: registry ≡ catalogue, a planted must-hit and a clean
# twin per scan over the fixture corpus, the ledger's reach, and one testset per scan whose false
# positives had been measured. Every scan is a `Rule` value now — the last, SCAN.DOI_CROSSCHECK, on
# 2026-09-17 — and a rule carries its own evidence: an example that breaks each clause of its statement
# and one that complies, run by test/rules.jl. A corpus planted in a second repository, with a third file
# naming which hit belongs to which class, is what that replaces.
#
# What is left here is not about scans at all: the prose-shape baseline, the name resolution the test
# harness does, and the docstring extraction the rules stand on.
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

@testset "the corpus the rules read" begin
    @testset "the catalogue is empty, and the engine reads it as none" begin
        # An empty TOML file has no `scan` key at all, which is a catalogue of no scans rather than a
        # missing one; `scan_catalog` says so instead of throwing, and `gbg scan docs` runs nothing.
        @test isempty(G.scan_catalog()) && isempty(G.SCANS)
        _, code = G.scan_docs(G.Config.read(FIXTURE); hard_only = true, io = devnull)
        @test code == 0
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

    @testset "prose extraction" begin
        cfg = defects_config()
        pl = G.prose_lines(cfg, "src/FixtureA.jl")
        @test all(p -> p.indocstring, pl)
        @test !any(p -> occursin(r"^function|^end$|^struct", strip(p.raw)), pl)
        ds = G.Reflection.docstrings(FIXTURE, ["src/FixtureA.jl"])
        @test length(ds) == 5 && all(d -> !startswith(d.signature, "function"), ds)
    end
end
