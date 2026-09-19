# test/questions.jl — the language rules as they are APPLIED, which is a different thing from the rules
# themselves (docs/ARCHITECTURE.md §8).
#
# `test/rules.jl` shows each check matches its statement, example by example. What is held here is the
# runner around them: that it selects the rules rather than holding a list, that a package can switch one
# off, that a setting moves a limit, and that the agent-decided rule is not run by a program pretending
# to decide it.
using Test, GBGCodingTools
include("helpers.jl")

const Q = G.Engine.Questions
const MQ = G.Model

plain_cfg() = MQ.Config(package = "Example", tool = :dev)

@testset "putting a question to the owner" begin

    # The rules are SELECTED, never listed. A list here would be a second copy of the rulebook, and the
    # one thing this package will not have is a rule written down twice: batch e added five rules and
    # nothing in this module was edited to know about them.
    @testset "the language rules are found, not listed" begin
        ids = [r.id for r in Q.rules()]
        @test !isempty(ids)
        @test all(r -> r.check isa MQ.ProgramCheck && r.check.input === MQ.Input.QUESTION, Q.rules())
        # The agent-decided one is a language rule and is NOT in here: an agent judges it before the
        # question is shown, and a program that returned a verdict for it would be inventing one.
        @test !(Symbol("RULE.ASK.PLAIN") in ids)
        @test any(r -> r.check isa MQ.AgentCheck, G.Catalogue.Questions.RULES)
    end

    @testset "a question that may be put, and one that may not" begin
        good = MQ.Question(id = "q1", decision = "Should the tolerance stay at its present value?",
                           context = "It was chosen once and has not been revisited.")
        @test isempty(Q.check(good, plain_cfg()))
        @test isempty(Q.report(good, plain_cfg()))

        # Four faults in one question, one per program rule: two sentences, a rule id, one of this
        # package's own words, and a decision far past the limit.
        bad = MQ.Question(id = "q2",
                          decision = "The pin is old. Should RULE.DOC.SHAPE stay on " * join(fill("here", 45), " ") * "?",
                          context = "Every consumer would have to be told.")
        found = Q.check(bad, plain_cfg())
        @test Set(first.(found)) == Set(Symbol.(["RULE.ASK.ONE_DECISION", "RULE.ASK.SHORT",
                                                 "RULE.ASK.NO_COORDINATES", "RULE.ASK.NO_HOUSE_TERMS"]))
        # The report names the rule that failed, which is what the owner is shown when a question is put
        # anyway after one rewrite: a question he can see the tool knew about beats one he cannot.
        @test occursin("RULE.ASK.NO_COORDINATES", Q.report(bad, plain_cfg()))
    end

    # A package may switch a language rule off, like any other, and then it is not applied. There is no
    # set a package cannot escape (owner's ruling, 2026-09-17).
    @testset "a switched-off language rule is not applied" begin
        q = MQ.Question(id = "q3", decision = "Should this ratchet stay where it is?")
        @test !isempty(Q.check(q, plain_cfg()))
        off = MQ.Config(package = "Example", tool = :dev,
                        switches = [MQ.Switch(target = Symbol("RULE.ASK.NO_HOUSE_TERMS"),
                                              reason = "this package's owner wrote the word")])
        @test isempty(Q.check(q, off))
    end

    @testset "a package moves a limit" begin
        long = MQ.Question(id = "q4", decision = join(fill("word", 60), " ") * "?")
        @test any(id -> id === Symbol("RULE.ASK.SHORT"), first.(Q.check(long, plain_cfg())))
        roomier = MQ.Config(package = "Example", tool = :dev,
                            settings = [MQ.Setting(rule = Symbol("RULE.ASK.SHORT"), name = :decision_words,
                                                   value = 100)])
        @test !any(id -> id === Symbol("RULE.ASK.SHORT"), first.(Q.check(long, roomier)))
    end

    # The exhibit carries the commits, the diffs and the definitions, and is deliberately not measured:
    # a limit on it pushes the evidence out of the question instead of shortening the question.
    @testset "the exhibit is not measured" begin
        q = MQ.Question(id = "q5", decision = "Should it stay?",
                        exhibit = join(fill("deadbeef src/Thing.jl Thing.method()", 200), " "))
        @test isempty(Q.check(q, plain_cfg()))
    end
end
