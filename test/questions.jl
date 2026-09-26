# test/questions.jl — the language rules as they are APPLIED, which is a different thing from the rules
# themselves (docs/ARCHITECTURE.md §8).
#
# `test/rules.jl` shows each check matches its statement, example by example. What is held here is the
# runner around them: that it selects the rules rather than holding a list, that a package can switch one
# off, that a setting moves a limit, and that the agent-decided rule is not run by a program pretending
# to decide it.
using Test, GBGCodingTools, Dates, JSON3
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
    # The round trip: put, list, answer, settle. What matters most here is that the file the WRITER
    # produces is readable by the literal-only parser — `.gbg/settled.jl` is written by a verb and read
    # by a reader that evaluates nothing, and a writer emitting anything that parser refuses would put a
    # package into a state where its own ruling file could not be loaded.
    @testset "a question is put, answered once, and settled" begin
        root = mktempdir(; cleanup = true); mkpath(joinpath(root, ".gbg"))
        write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
        cfg = G.ConfigIO.read_config(root)
        q = MQ.Question(id = "q-tol", decision = "Should the tolerance stay at its present value?",
                        context = "It was chosen once and has not been revisited.",
                        options = [MQ.Option("keep", "nothing changes", true),
                                   MQ.Option("tighten", "some runs get slower", false)])
        @test Q.put(q, root, cfg)
        @test !Q.put(q, root, cfg)                                  # a question is put once
        @test G.Answer.ask(root; io = devnull) == 1                 # one is waiting

        @test G.Answer.answer(root, "q-tol", "nope"; io = devnull) == 2       # not one of its options
        @test G.Answer.answer(root, "q-nope", "keep"; io = devnull) == 2      # no such question
        @test G.Answer.answer(root, "q-tol", "keep"; direction = "revisit next year",
                              settled = true, io = devnull) == 0
        # An answered question never returns: the second answer is refused, not recorded over the first.
        @test G.Answer.answer(root, "q-tol", "tighten"; io = devnull) == 2
        @test G.Answer.ask(root; io = devnull) == 0

        settled = G.ConfigIO.read_settled(root)                     # parsed, never evaluated
        @test length(settled) == 1
        @test settled[1].question == "q-tol"
        @test settled[1].text == "revisit next year"                # his words, not the option label
        @test occursin(r"^\d{4}-\d{2}-\d{2}$", settled[1].date)

        # Appended, not rewritten: a second ruling leaves the first where it was.
        G.ConfigIO.append_settled(root, MQ.Settled(question = "q-2", text = "leave it", date = "2026-09-19"))
        again = G.ConfigIO.read_settled(root)
        @test [x.question for x in again] == ["q-tol", "q-2"]
    end

    # A question asked per ITEM is answered per item, and is not done until every item is.
    @testset "a question with items is answered item by item" begin
        root = mktempdir(; cleanup = true); mkpath(joinpath(root, ".gbg"))
        write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
        cfg = G.ConfigIO.read_config(root)
        q = MQ.Question(id = "q-two", decision = "Which of these stay as they are?",
                        options = [MQ.Option("keep", "nothing changes", true),
                                   MQ.Option("drop", "it goes", false)],
                        items = [MQ.Item(text = "the first one"), MQ.Item(text = "the second one")])
        @test Q.put(q, root, cfg)
        @test G.Answer.answer(root, "q-two", "keep"; io = devnull) == 2       # name the item
        @test G.Answer.answer(root, "q-two", "keep"; item = "the first one", io = devnull) == 0
        @test G.Answer.ask(root; io = devnull) == 1                           # one item still open
        @test G.Answer.answer(root, "q-two", "drop"; item = "the second one", io = devnull) == 0
        @test G.Answer.ask(root; io = devnull) == 0
    end
end

# The two ends of the channel, wired 2026-09-21. Before that `Questions.put` was called by nothing in
# `src/`, so `.gbg/questions.json` was never written by any verb: `ask` always said nothing was waiting,
# and `answer` had nothing to answer. And a question a RUN put lived in that run's record, where `answer`
# could not reach it, while the report of every run that parked a finding told the owner to use it.
@testset "the CLI puts a question, and answers one a run put" begin

    @testset "gbg ask puts one, and lists it" begin
        root = mktempdir(; cleanup = true); mkpath(joinpath(root, ".gbg"))
        write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
        @test G.Answer.ask(root; io = devnull) == 0                          # nothing waiting yet
        @test G.Answer.put(root, "Should the floor move to 1.13?";
                           options = ["keep 1.12", "move to 1.13"], io = devnull) == 0
        @test G.Answer.ask(root; io = devnull) == 1                          # now one is
        ids = [q["id"] for q in Q.open_questions(root)]
        @test length(ids) == 1 && startswith(only(ids), string(Dates.today()))
        # A second on the same day gets its own id rather than colliding with the first.
        @test G.Answer.put(root, "Should the examples move too?";
                           options = ["yes", "no"], io = devnull) == 0
        @test length(Q.open_questions(root)) == 2
        @test G.Answer.answer(root, last([q["id"] for q in Q.open_questions(root)]), "no"; io = devnull) == 0
    end

    @testset "a question with one answer is refused" begin
        root = mktempdir(; cleanup = true); mkpath(joinpath(root, ".gbg"))
        write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
        @test G.Answer.put(root, "Is this fine?"; options = ["yes"], io = devnull) == 2
        @test G.Answer.put(root, ""; options = ["yes", "no"], io = devnull) == 2
        @test isempty(Q.open_questions(root))
    end

    @testset "a run's question is answered, and 'not a defect' settles it" begin
        root = mktempdir(; cleanup = true); mkpath(joinpath(root, ".gbg"))
        write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
        loc = MQ.Location(file = "src/A.jl", node = "f", text = "the claim", line = 3)
        finding = MQ.Finding("F1", :full, MQ.Decider.AGENT,
                             MQ.FindingDraft(rule = Symbol("RULE.DOC.SHAPE"),
                                             claim = "the docstring is wrong", locations = [loc]))
        q = MQ.Question(id = "F1-code", decision = "Is the code right here, or the documentation?",
                        options = [MQ.Option("fix the code", "the code is changed", true),
                                   MQ.Option("fix the documentation instead", "the edit stands", false),
                                   MQ.Option(G.Answer.NOT_A_DEFECT, "the finding is closed", false)])
        run = MQ.Run(id = "r1", instrument = :documentation_review, tool_version = "vdev",
                     first_commit = "abc", budget = MQ.Budget(), stage = :close,
                     findings = [finding], questions = [q])
        G.Orchestration.Runs.save(root, run)

        # It is not in `.gbg/questions.json`, and before this it could not be answered at all.
        @test isempty(Q.open_questions(root))
        @test G.Answer.answer(root, "F1-code", "no such option"; io = devnull) == 2
        @test G.Answer.answer(root, "F1-code", G.Answer.NOT_A_DEFECT; io = devnull) == 0

        back = G.Orchestration.Runs.load(root, "r1")
        @test only(back.questions).answer == G.Answer.NOT_A_DEFECT
        @test G.Answer.answer(root, "F1-code", "fix the code"; io = devnull) == 2   # answered once

        # "not a defect" settles it without the flag, carrying the finding's own locations, so the next
        # run's readers are told not to raise it again.
        settled = G.ConfigIO.read_settled(root)
        @test length(settled) == 1
        @test only(settled).question == "F1-code"
        @test only(settled).locations == [loc]
    end

    @testset "a closed run's record is amended, not shadowed by a draft" begin
        root = mktempdir(; cleanup = true); mkpath(joinpath(root, ".gbg"))
        write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
        q = MQ.Question(id = "r2-F9-code", decision = "Which half is right?",
                        options = [MQ.Option("the code", "", true), MQ.Option("the documentation", "", false)])
        run = MQ.Run(id = "r2", instrument = :documentation_review, tool_version = "vdev",
                     first_commit = "abc", budget = MQ.Budget(), stage = :close, questions = [q])
        # A CLOSED run: its record is `run.json`, which `load` prefers over any draft beside it.
        d = joinpath(root, ".gbg", "runs", "r2"); mkpath(d)
        write(joinpath(d, "run.json"), JSON3.write(G.Orchestration.Runs.as_dict(run)))
        @test G.Answer.answer(root, "r2-F9-code", "the code"; io = devnull) == 0
        @test only(G.Orchestration.Runs.load(root, "r2").questions).answer == "the code"
        @test !isfile(joinpath(d, "run.draft.json"))
    end
end
