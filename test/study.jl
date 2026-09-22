# test/study.jl — the rule wording study's arithmetic, over the rounds it was actually run on.
#
# The gate Phase 4e ends on. The two rounds of 2026-09-19 are filed under `test/tagging/`, votes and all,
# and the numbers this package prints for them today are the numbers that were printed then: agreement
# 0.74 → 0.90 on what a rule needs, 0.93 → 0.91 on whether it needs a discipline, nine splits down to
# three, eight rules flagged. A measurement nobody can re-run is a claim, and this is what makes it not
# one.
#
# The votes were recovered from the session that ran the study; they had never been filed, so until this
# commit the four numbers in the plan rested on a transcript.
using Test, GBGCodingTools
include("helpers.jl")

const ST = G.Study
const TAGS = joinpath(TOOL, "test", "tagging")

@testset "the rounds of 2026-09-19 reproduce" begin

    @testset "round 0, before any rewording" begin
        r = ST.read_round(joinpath(TAGS, "round0.tsv"))
        @test length(r.rules) == 27
        @test round(r.needs_kappa; digits = 2) == 0.74
        @test round(r.discipline_kappa; digits = 2) == 0.93
        @test length(r.splits) == 9
        @test isempty(r.flagged)            # round 0 recorded no flag column
    end

    @testset "round 1, after the rewording" begin
        r = ST.read_round(joinpath(TAGS, "round1.tsv"))
        @test length(r.rules) == 25
        @test round(r.needs_kappa; digits = 2) == 0.90
        @test round(r.discipline_kappa; digits = 2) == 0.91
        @test length(r.splits) == 3
        @test length(r.flagged) == 8
    end

    # The claim the study was run to settle: rewording moved agreement up and splits down. Held as a
    # comparison rather than as two numbers, so it survives a round 2 being added beside them.
    @testset "the rewording converged" begin
        a = ST.read_round(joinpath(TAGS, "round0.tsv"))
        b = ST.read_round(joinpath(TAGS, "round1.tsv"))
        @test b.needs_kappa > a.needs_kappa
        @test length(b.splits) < length(a.splits)
    end
end

@testset "the arithmetic itself" begin

    tag(rule, reader, needs; disc = false, flag = false) =
        ST.Tag(rule = rule, reader = reader, needs = Set(needs), discipline = disc, flagged = flag)

    @testset "perfect agreement is 1, and is not an accident of one label" begin
        # Three readers, two rules, every answer the same: kappa is 1 by the convention, since the
        # formula divides by zero when one label is all there is.
        tags = [tag("A", r, ["SOURCE"]) for r in ("X", "Y", "Z")]
        append!(tags, [tag("B", r, ["SOURCE"]) for r in ("X", "Y", "Z")])
        r = ST.measure(tags, ["A", "B"])
        @test r.needs_kappa == 1.0
        @test isempty(r.splits)
    end

    @testset "a split is a rule they answered differently about" begin
        tags = [tag("A", "X", ["SOURCE"]), tag("A", "Y", ["SIBLINGS"]), tag("A", "Z", ["SOURCE"]),
                tag("B", "X", String[]), tag("B", "Y", String[]), tag("B", "Z", String[])]
        r = ST.measure(tags, ["A", "B"])
        @test r.splits == ["A"]
        @test r.needs_kappa < 1.0
    end

    @testset "one reader's flag flags the rule" begin
        tags = [tag("A", "X", ["SOURCE"]; flag = true), tag("A", "Y", ["SOURCE"]), tag("A", "Z", ["SOURCE"])]
        @test ST.measure(tags, ["A"]).flagged == ["A"]
    end

    @testset "the order of a need does not make a disagreement" begin
        tags = [tag("A", "X", ["SOURCE", "SIBLINGS"]), tag("A", "Y", ["SIBLINGS", "SOURCE"]),
                tag("A", "Z", ["SOURCE", "SIBLINGS"])]
        r = ST.measure(tags, ["A"])
        @test isempty(r.splits)
        @test r.needs_kappa == 1.0
    end

    @testset "a shorthand and its full name are one answer" begin
        # A vote may say OTHER where the rulebook says OTHER_DOCUMENTS. Read as two answers, every rule
        # needing another document would drift from the rulebook by spelling alone.
        @test ST.spelled("OTHER") == "OTHER_DOCUMENTS"
        @test ST.spelled("CITED") == "CITED_WORK"
        @test ST.spelled("SOURCE") == "SOURCE"          # a name already in full is left alone
    end
end

@testset "what the study proposes, and what it never does" begin

    @testset "a split proposes nothing, having no majority to propose" begin
        tags = [ST.Tag(rule = "DOC.GRAMMAR", reader = "X", needs = Set(["SOURCE"])),
                ST.Tag(rule = "DOC.GRAMMAR", reader = "Y", needs = Set{String}()),
                ST.Tag(rule = "DOC.GRAMMAR", reader = "Z", needs = Set(["SIBLINGS"]))]
        r = ST.measure(tags, ["DOC.GRAMMAR"])
        @test r.splits == ["DOC.GRAMMAR"]
        @test isempty(ST.drift(r, G.Catalogue.RULES))
    end

    @testset "a drift is a question with two answers and no third" begin
        r = ST.read_round(joinpath(TAGS, "round1.tsv"))
        drifts = ST.drift(r, G.Catalogue.RULES)
        @test !isempty(drifts)                          # the round does disagree with today's rulebook
        q = ST.question_of(first(drifts))
        @test length(q.options) == 2                    # keep the tag, or move it
        @test q.answer === nothing                      # a measurement answers nothing
        @test occursin(first(drifts).rule, q.exhibit)
        @test any(o -> o.recommended, q.options)
    end

    @testset "reading a round changes no rule" begin
        before = [(r.id, copy(r.access)) for r in G.Catalogue.RULES]
        ST.read_round(joinpath(TAGS, "round1.tsv"))
        ST.drift(ST.read_round(joinpath(TAGS, "round1.tsv")), G.Catalogue.RULES)
        @test [(r.id, r.access) for r in G.Catalogue.RULES] == before
    end
end

@testset "the verb" begin
    @testset "it reports a round and exits 1 while anything is open" begin
        out = IOBuffer()
        code = G.StudyCmd.rules(TOOL, joinpath(TAGS, "round1.tsv"); io = out)
        text = String(take!(out))
        @test code == 1                                  # splits, flags and a drift are all open
        @test occursin("25 rule(s)", text)
        @test occursin("0.9", text)
    end

    @testset "a file that is not there, and one with no votes" begin
        @test G.StudyCmd.rules(TOOL, joinpath(TAGS, "nothing-here.tsv"); io = devnull) == 2
        empty_ = joinpath(mktempdir(; cleanup = true), "empty.tsv")
        write(empty_, "rule\tA_w\tA_c\tB_w\tB_c\tC_w\tC_c\n")
        @test G.StudyCmd.rules(TOOL, empty_; io = devnull) == 2
    end

    @testset "a round that agrees with the rulebook everywhere exits 0" begin
        # Three readers, one rule, answering what the rulebook already says: nothing is open.
        path = joinpath(mktempdir(; cleanup = true), "agreed.tsv")
        write(path, "rule\tA_w\tA_c\tA_f\tB_w\tB_c\tB_f\tC_w\tC_c\tC_f\n" *
                    "DOC.GRAMMAR\tNOTHING\tG\t0\tNOTHING\tG\t0\tNOTHING\tG\t0\n")
        out = IOBuffer()
        @test G.StudyCmd.rules(TOOL, path; io = out) == 0
        @test occursin("no tag the readers would move", String(take!(out)))
    end
end
