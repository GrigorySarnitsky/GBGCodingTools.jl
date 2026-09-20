# test/readers.jl — the readers of a documentation review are derived from the rules' tags, and the
# derivation says what it cannot cover (docs/ARCHITECTURE.md §4.1; owner's rulings of 2026-09-20/21).
#
# What is held: every rule with an access tag lands on exactly one bound reader or is named as a gap;
# a rule needing NOTHING lands only on the reader given nothing; a rule naming a discipline goes to
# that discipline's reader and to nobody — said aloud — where it is not declared; a declared discipline
# is an open reader whether or not a rule binds it; a switch turns a reader off by name; and the tagged
# count moves only on purpose.
using Test, GBGCodingTools
include("helpers.jl")

const DR = G.Catalogue.DocumentationReview
const AC = G.Model.Access

cfg(; disciplines = Symbol[], switches = G.Model.Switch[]) =
    G.Model.Config(package = "Sample", tool = :dev, disciplines = disciplines, switches = switches)

tagged() = [r for r in G.Catalogue.RULES if !isempty(r.access)]

@testset "the readers follow from the rules" begin

    @testset "the tags themselves" begin
        @test length(tagged()) == 26                          # the reader's rules; a change here is a decision
        for r in tagged()
            @test !(AC.NOTHING in r.access && length(r.access) > 1)   # NOTHING is exclusive
            @test r.check === nothing || r.check isa G.Model.AgentCheck  # a program's rule needs no reader
        end
        # One rule names a discipline: the owner's ruling of 2026-09-21, on the record of what checked
        # each rule before — formulas, notation, coverage and the identity sentence are a generalist's
        # with the source; stating maps without flattening is a geometer's.
        @test [r.id for r in tagged() if r.discipline !== nothing] == [Symbol("RULE.DOC.COORD_FREE")]
        @test only(r for r in tagged() if r.discipline !== nothing).discipline in DR.DISCIPLINE_IDS
    end

    @testset "with no discipline declared: three bound readers, two open, and the gap said by name" begin
        roles, gaps = DR.derive(G.Catalogue.RULES, cfg())
        @test [r.id for r in roles] == [:withheld, :full, :rendered, :plain_sense, :logician]
        bound = filter(r -> !isempty(r.rules), roles)
        @test length(bound) == 3
        @test all(r -> r.strength === G.Model.Strength.FULL, roles)     # the smaller panel runs careful
        # every generic tagged rule is on exactly one bound reader, or is a gap
        placed = vcat([r.rules for r in bound]...)
        @test length(placed) == length(unique(placed))
        for r in tagged()
            r.discipline === nothing || continue
            @test (r.id in placed) ⊻ any(g -> startswith(g, String(r.id)), gaps)
        end
        # the four formerly "expert" rules are the full reader's now
        full = only(filter(r -> r.id === :full, roles))
        for id in ("RULE.DOC.VERIFIED", "RULE.DOC.ONE_NOTATION", "RULE.DOC.COVERAGE_BASES", "RULE.DOC.LEADING_IDENTITY")
            @test Symbol(id) in full.rules
        end
        # the geometer's rule is on no reader, and the gap names the discipline
        @test !(Symbol("RULE.DOC.COORD_FREE") in placed)
        @test any(g -> startswith(g, "RULE.DOC.COORD_FREE") && occursin("differential_geometry", g), gaps)
        # the citation rule's reader half is the full reader's; its network half is a program (decision 17)
        @test Symbol("RULE.CIT.NO_INACCESSIBLE") in full.rules
        @test !any(g -> startswith(g, "RULE.CIT.NO_INACCESSIBLE"), gaps)
    end

    @testset "a rule needing nothing goes only to the reader given nothing" begin
        roles, _ = DR.derive(G.Catalogue.RULES, cfg())
        withheld = only(filter(r -> r.id === :withheld, roles))
        @test withheld.kept_from_code && withheld.site
        for r in tagged()
            r.discipline === nothing || continue
            @test (r.id in withheld.rules) == (r.access == [AC.NOTHING])
        end
        rendered = only(filter(r -> r.id === :rendered, roles))
        @test Symbol("RULE.TEX.NO_HSCROLL") in rendered.rules
        @test Symbol("RULE.DOC.LITERATE_RENDERED") in rendered.rules
        @test Symbol("RULE.DOC.LITERATE") in withheld.rules     # the source habits, judged on the file alone
    end

    @testset "a declared discipline is an open expert, bound only to a rule that names it" begin
        roles, gaps = DR.derive(G.Catalogue.RULES, cfg(disciplines = [:differential_geometry, :spectral_numerics]))
        @test [r.id for r in roles] == [:withheld, :full, :rendered, :differential_geometry, :spectral_numerics, :plain_sense, :logician]
        geo = only(filter(r -> r.id === :differential_geometry, roles))
        num = only(filter(r -> r.id === :spectral_numerics, roles))
        @test geo.rules == [Symbol("RULE.DOC.COORD_FREE")] && !geo.kept_from_code
        @test isempty(num.rules)                                        # open, with a standpoint
        @test occursin("open reader", geo.description) && occursin("open reader", num.description)
        @test !any(g -> occursin("COORD_FREE", g), gaps)
        # bound runs launch the geometer for its rule; open runs launch both experts
        @test [r.id for r in DR.select(roles, :bound)] == [:withheld, :full, :rendered, :differential_geometry]
        @test [r.id for r in DR.select(roles, :open)] == [:differential_geometry, :spectral_numerics, :plain_sense, :logician]
        @test DR.select(roles, :both) == roles
        @test_throws ArgumentError DR.select(roles, :all)
        # a discipline the catalogue lacks is a gap here and a config problem at read
        _, gaps2 = DR.derive(G.Catalogue.RULES, cfg(disciplines = [:phrenology]))
        @test any(g -> occursin("phrenology", g), gaps2)
    end

    @testset "a switch turns a reader off by name" begin
        off = [G.Model.Switch(target = :logician, reason = "this package has no arguments to check")]
        roles, _ = DR.derive(G.Catalogue.RULES, cfg(switches = off))
        @test !any(r -> r.id === :logician, roles)
        @test :logician in G.Catalogue.known_ids()                       # so the switch is a legal one
        off2 = [G.Model.Switch(target = :differential_geometry, reason = "no geometry in this package")]
        roles2, gaps2 = DR.derive(G.Catalogue.RULES, cfg(disciplines = [:differential_geometry], switches = off2))
        @test !any(r -> r.id === :differential_geometry, roles2)
    end

    @testset "a switched-off rule reaches no reader" begin
        off = [G.Model.Switch(target = Symbol("RULE.TEX.GREEK_AB"), reason = "no accumulation scalars here")]
        roles, gaps = DR.derive(G.Catalogue.RULES, cfg(switches = off))
        @test !any(r -> Symbol("RULE.TEX.GREEK_AB") in r.rules, roles)
        @test !any(g -> occursin("GREEK_AB", g), gaps)
    end
end
