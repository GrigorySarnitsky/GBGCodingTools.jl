# test/conversion.jl — the ratchet over the rulebook's conversion (IMPLEMENTATION.md §6).
#
# The rulebook is being moved from ninety-five rows of prose in policy/RULES.toml into `Rule` values
# beside their checks. While that is under way `Catalogue.RULES` is simply short, and nothing fails
# because a rule is absent — an unconverted rule runs nowhere, so no build goes red for it.
#
# Completeness is measured separately, and honestly, HERE. Every id of the frozen register must be
# converted, retired with a reason, or counted in the ALLOWANCE below. The allowance only ever falls: a
# commit that raises it fails this test. That is the whole mechanism — a number a program holds, rather
# than a plan nobody re-reads.
using Test, GBGCodingTools, TOML
include("helpers.jl")

# The register as it stood when the rebuild began: 95 ids, frozen, read by nothing but this test.
const REGISTER = joinpath(TOOL, "docs", "design-record", "RULES-v1.toml")

# Rules dropped rather than converted, each with the reason. A retirement is a code change like any other
# (docs/ARCHITECTURE.md §13): the question that proposed it named the id and why, and the id is never
# reused. Nothing is here yet.
const RETIRED = Dict{String,String}()

# How many ids are still neither converted nor retired. LOWER THIS AND NEVER RAISE IT.
const ALLOWANCE = 5

@testset "the rulebook conversion" begin
    ids = [String(r["id"]) for r in TOML.parsefile(REGISTER)["rule"]]
    @test length(ids) == 95 && length(unique(ids)) == 95

    converted = Set(String(r.id) for r in G.Catalogue.RULES)
    outstanding = [id for id in ids if !(id in converted) && !haskey(RETIRED, id)]

    @testset "the allowance is a ratchet" begin
        @test length(outstanding) <= ALLOWANCE
        # and it is not left far above the truth, which would stop it measuring anything
        @test length(outstanding) >= ALLOWANCE - 8
    end

    @testset "nothing is converted twice, or retired and converted" begin
        @test length(converted) == length(G.Catalogue.RULES)
        @test isempty(intersect(converted, keys(RETIRED)))
    end

    @testset "every retirement carries its reason" begin
        for (id, reason) in RETIRED
            @test id in ids                                   # a retirement names an id that existed
            @test length(strip(reason)) >= 24                 # and says why, at more than a word
        end
    end

    @testset "a converted rule is not a bare copy of the row" begin
        # The conversion is not a rename: a rule that arrives with no check and no reason for having none
        # has been moved, not converted, and would leave the package believing it is enforced.
        for r in G.Catalogue.RULES
            @test r.check !== nothing || !isempty(r.unchecked_reason)
            @test !isempty(r.statement)
        end
    end
end
