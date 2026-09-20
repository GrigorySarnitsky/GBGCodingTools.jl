# test/rehearse.jl — a whole run driven over a fixture, from result files rather than from agents
# (docs/ARCHITECTURE.md §6, §12; IMPLEMENTATION.md Phase 4).
#
# Julia cannot launch an agent and only a session can, so the one thing this suite may not do is run the
# instrument for real. What it CAN do is everything either side of that: the stages in order, the
# arguments written for the session, the results read back, the record, the report, and every refusal.
# The agents' half is a file, and a file can be written here.
#
# This is the gate Phase 4 ends on. What it is guarding against is a stage machine that looks right and
# has never been driven: every defect found while writing it — a report naming a constant it could not
# see, a close that accepted a run still at `pass`, a silent reader read as a clean one, a malformed
# file read as a reader that wrote, a stage list with a repeated name looping for ever — was invisible
# from the source and obvious on the first run.
using Test, GBGCodingTools
include("helpers.jl")

const RUNS = G.Orchestration.Runs
const AGENTS = G.Orchestration.Agents
const MRun = G.Model

"""A package with a docs surface, a source file and one commit, in a temporary directory."""
function package(f)
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".gbg")); mkpath(joinpath(root, "docs", "src")); mkpath(joinpath(root, "src"))
    gg(a...) = Base.run(pipeline(setenv(Cmd(["git", "-C", root, a...]); dir = root);
                                 stdout = devnull, stderr = devnull))
    gg("init", "-q"); gg("config", "user.name", "t"); gg("config", "user.email", "t@t")
    write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
    write(joinpath(root, "docs", "src", "guide.md"), "# Guide\n\nThe grid is spectral.\n")
    write(joinpath(root, "src", "Sample.jl"), "module Sample\nend\n")
    gg("add", "--all", "."); gg("commit", "-q", "-m", "first")
    f(root, gg)
end

"""Write what one reader found, as the driver would have written it, into the current stage's results."""
function reader_found(root, id, role, claim; file = "docs/src/guide.md", quote_ = "The grid is spectral.")
    mkpath(AGENTS.results_dir(root, id))
    write(joinpath(AGENTS.results_dir(root, id), role * ".json"),
          """{"findings":[{"claim":"$claim","fix":"say which","locations":[{"file":"$file","text":"$quote_"}]}],"checked":["$file"]}""")
end

"""Write one verifier's verdict, as the driver would have written it, for the current stage."""
function verifier_said(root, id, stage, finding, verdict; quote_ = "")
    mkpath(AGENTS.results_dir(root, id))
    write(joinpath(AGENTS.results_dir(root, id), string(stage, "-", finding, ".json")),
          """{"verdict":"$verdict","quote":"$quote_"}""")
end

"""The other two bound readers report clean, so a collect is not exit 2 for their silence."""
function others_clean(root, id; but = "withheld")
    for role in ("withheld", "full", "rendered")
        role == but && continue
        write(joinpath(AGENTS.results_dir(root, id), role * ".json"),
              """{"findings":[],"checked":["docs/src/guide.md"]}""")
    end
end

"""A run with one finding collected, at its first collect: the pass machinery starts here."""
function with_one_finding(root)
    G.Run.start(root, :documentation_review; io = devnull)
    id = G.Run.open_run(root)
    reader_found(root, id, "withheld", "the grid is named but not said to be a lattice")
    others_clean(root, id)
    @test G.Run.collect(root; io = devnull) == 1
    return id, only(RUNS.load(root, id).findings).id
end

"""Commit a documentation edit as the fixer would, through the guard, for one finding."""
function fixed_as(root, fid, text)
    write(joinpath(root, "docs", "src", "guide.md"), "# Guide\n\n$text\n")
    @test G.Docfix.commit(root, "fix for " * fid; io = devnull, finding = fid) == 0
end

"""Drive the open run forward until it is ready to close: collecting where agents were launched, moving on elsewhere."""
function to_close(root, id)
    order = RUNS.STAGES[:documentation_review]
    for _ in 1:40
        at = RUNS.stage_index(root, id)
        order[at] === :close && break
        order[at + 1] === :collect ? G.Run.collect(root; io = devnull) : G.Run.next(root; io = devnull)
    end
    return RUNS.stage_of(root, id)
end

@testset "a documentation review, driven end to end" begin

    @testset "the stages run in order, and the record and report are written" begin
        package() do root, gg
            @test G.Run.start(root, :documentation_review; io = devnull) == 0
            id = G.Run.open_run(root)
            @test id !== nothing
            @test RUNS.stage_of(root, id) === :find             # start writes the first stage's arguments
            @test RUNS.stage_index(root, id) == 2

            # The arguments are what the session needs and nothing it does not, under the run's scratch.
            args_path = AGENTS.arguments_path(root, id)
            @test startswith(relpath(args_path, root), joinpath(".gbg", "scratch", id))
            args = G.JSON3.read(read(args_path, String), Dict{String,Any})
            @test args["run"] == id
            @test !isempty(args["roles"])
            @test all(r -> haskey(r, "result_file") && haskey(r, "cap"), args["roles"])
            @test !haskey(args, "launches_left")                   # nothing caps launches (ruled 2026-09-21)
            @test all(r -> r["launch"] === true, args["roles"])       # a fresh stage launches everyone
            @test args["commit"] == RUNS.load(root, id).first_commit

            reader_found(root, id, "withheld", "a term is used before it is defined")
            @test G.Run.collect(root; io = devnull) == 2          # other readers wrote nothing: NOT clean
            run = RUNS.load(root, id)
            @test run.agent_launches == 1                          # what arrived, not the panel's size
            @test only(run.findings).source === :withheld          # the finding names its reader
            @test to_close(root, id) === :close
            @test G.Run.close_run(root; io = devnull) == 1        # closed, with a finding

            rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
            @test occursin("used before it is defined", rep)
            @test occursin("Reported by `withheld`", rep)
            @test occursin("Written by AI", rep)                  # a report is a page like any other
            @test occursin("docs/src/guide.md", rep)
            @test isfile(joinpath(RUNS.dir(root, id), "run.json"))
            @test !isfile(joinpath(RUNS.dir(root, id), "run.draft.json"))
            @test !isdir(AGENTS.scratch_dir(root, id))            # the agents' files went with the run
            @test sort(readdir(RUNS.dir(root, id))) == ["report.md", "run.json", "stage"]
            @test G.Run.open_run(root) === nothing                # and it is no longer open
        end
    end

    # A reader whose file does not parse, or that reports nothing and says it examined nothing, is
    # SILENT: the design relaunches it once and then names it, and never reads it as clean.
    @testset "a malformed or empty result is a silent reader, not a clean one" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            mkpath(AGENTS.results_dir(root, id))
            write(joinpath(AGENTS.results_dir(root, id), "withheld.json"), "{not json")
            write(joinpath(AGENTS.results_dir(root, id), "full.json"), """{"findings":[],"checked":[]}""")
            write(joinpath(AGENTS.results_dir(root, id), "rendered.json"), """{"findings":[],"checked":["docs/src/guide.md"]}""")
            _, _, silent, arrived, wrote = AGENTS.collect_results(root, id)
            @test wrote == 1
            @test arrived == 3
            @test "withheld" in silent && "full" in silent && !("rendered" in silent)
            @test G.Run.collect(root; io = devnull) == 2
        end
    end

    # Every refusal, because a stage machine that cannot refuse is a stage machine that is not there.
    @testset "a stage out of order is refused" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            @test !RUNS.advance!(root, id, :close; io = devnull)       # skipping collect and the passes
            @test !RUNS.advance!(root, id, :start; io = devnull)       # and never backwards
            @test G.Run.close_run(root; io = devnull) == 2             # close refuses a run still at find
            @test G.Run.next(root; io = devnull) == 0                  # next continues the stage, never skips it
            @test RUNS.stage_of(root, id) === :find                    # and nothing moved
            G.Run.collect(root; io = devnull)
            @test RUNS.stage_of(root, id) === :collect
            @test G.Run.collect(root; io = devnull) == 2               # a stage is collected once
        end
    end

    # The owner stopping a run: OWNER_STOPPED on the record, the findings dropped rather than queued, the
    # id kept, the agents' files gone, and the next run free to start.
    @testset "abandon ends the run as the owner's, with its findings dropped" begin
        package() do root, gg
            id, fid = with_one_finding(root)
            G.Run.next(root; io = devnull)                               # into the first fix pass
            @test G.Run.abandon(root; io = devnull) == 0
            @test G.Run.open_run(root) === nothing
            record = G.JSON3.read(read(joinpath(RUNS.dir(root, id), "run.json"), String), Dict{String,Any})
            @test record["stop"] == "OWNER_STOPPED" && isempty(record["findings"])
            @test occursin("The owner stopped it.", read(joinpath(RUNS.dir(root, id), "report.md"), String))
            @test !isdir(AGENTS.scratch_dir(root, id))
            @test !isfile(joinpath(root, ".claude", "WORK_QUEUE.md"))
            @test G.Run.abandon(root; io = devnull) == 2                # nothing open now
            @test G.Run.start(root, :documentation_review; io = devnull) == 0
            @test G.Run.open_run(root) != id                             # the id is never reused
        end
    end

    # A run interrupted with readers uncollected is continued: the readers that wrote are kept, the one
    # that did not is launched again alone, each finding is collected once — and a tree that moved since
    # the launch stops the continuation for the owner.
    @testset "an interrupted stage is continued, relaunching only what did not write" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            reader_found(root, id, "withheld", "one")
            reader_found(root, id, "full", "two")
            @test G.Run.next(root; io = devnull) == 0                    # continue: rendered is missing
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            launch = Dict(r["key"] => r["launch"] for r in args["roles"])
            @test launch == Dict("withheld" => false, "full" => false, "rendered" => true)
            @test length(args["roles"]) == 3                             # the collect still expects everyone
            reader_found(root, id, "rendered", "three")
            @test G.Run.next(root; io = devnull) == 2                    # every agent wrote: collect
            @test G.Run.collect(root; io = devnull) == 1
            @test length(RUNS.load(root, id).findings) == 3              # each collected once
            @test RUNS.load(root, id).agent_launches == 3
        end
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            reader_found(root, id, "withheld", "one")
            write(joinpath(root, "docs", "src", "guide.md"), "# Guide\n\nThe grid is a lattice.\n")
            gg("add", "--all", "."); gg("commit", "-q", "-m", "the tree moves under the run")
            @test G.Run.next(root; io = devnull) == 2                    # moved: the owner decides
            @test RUNS.stage_of(root, id) === :find                      # and nothing was taken
            @test G.Run.abandon(root; io = devnull) == 0
        end
    end

    # A tracked change already in the tree would be committed by the fixer under the guard's name.
    @testset "a start on a dirty tree is refused" begin
        package() do root, gg
            write(joinpath(root, "src", "Sample.jl"), "module Sample\nf() = 1\nend\n")
            @test G.Run.start(root, :documentation_review; io = devnull) == 2
            @test G.Run.open_run(root) === nothing
            write(joinpath(root, "docs", "src", "untracked.md"), "# New\n")     # untracked does not count
            gg("checkout", "--", "src/Sample.jl")
            @test G.Run.start(root, :documentation_review; io = devnull) == 0
        end
    end

    @testset "a run never starts another" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            @test RUNS.start(:documentation_review, root; io = devnull) === nothing
        end
    end

    # An instrument with no derived readers does not open: a bug hunt today would launch nobody and
    # close clean.
    @testset "an instrument with no readers refuses to start" begin
        package() do root, gg
            @test RUNS.start(:bug_hunt, root; io = devnull) === nothing
            @test G.Run.open_run(root) === nothing
        end
    end

    # The stage machine finds its place by POSITION, not by name: the bug hunt's list repeats `collect`,
    # and a machine that looked the name up went from the second collect back to `witnesses` for ever.
    @testset "a stage list with a repeated name advances to close" begin
        package() do root, gg
            id = "2026-01-01-bug-hunt-01"
            mkpath(RUNS.dir(root, id))
            RUNS.save(root, MRun.Run(id = id, instrument = :bug_hunt, tool_version = "dev", first_commit = "",
                                     budget = MRun.Budget(fix_passes = 0), stage = :start))
            RUNS.write_stage(root, id, 1)
            for to in (:hunt, :collect, :witnesses, :collect, :close)
                @test RUNS.advance!(root, id, to; io = devnull)
            end
            @test RUNS.stage_of(root, id) === :close
            @test RUNS.stage_index(root, id) == 6
            # and a stage file written before positions existed still reads
            write(joinpath(RUNS.dir(root, id), "stage"), "hunt")
            @test RUNS.stage_index(root, id) == 2
        end
    end

    # A question put during a run is part of its record, and survives every stage after it.
    @testset "the record keeps its questions" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            run = RUNS.load(root, id)
            q = MRun.Question(id = "q-1", decision = "Keep the new formula?",
                              options = [MRun.Option("Keep", "it stays", true), MRun.Option("Revert", "it goes", false)],
                              items = [MRun.Item(text = "the one in convolve", recommended = "Keep")])
            RUNS.save(root, MRun.Run(id = run.id, instrument = run.instrument, tool_version = run.tool_version,
                                     first_commit = run.first_commit, budget = run.budget, stage = run.stage,
                                     questions = [q], readers = run.readers))
            reader_found(root, id, "withheld", "something")
            G.Run.collect(root; io = devnull)
            G.Run.next(root; io = devnull)
            again = RUNS.load(root, id)
            @test length(again.questions) == 1
            @test again.questions[1].decision == "Keep the new formula?"
            @test again.questions[1].options[1].recommended
            @test again.questions[1].items[1].recommended == "Keep"
        end
    end

    # A code change made around `gbg docfix commit` is what close exists to catch: the guard is what
    # decides a change is documentation, so a change that went around it is the one nobody looked at.
    @testset "code committed outside the guard ends the run CANNOT_EVALUATE" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            write(joinpath(root, "src", "Sample.jl"), "module Sample\nf() = 1\nend\n")
            gg("add", "--all", "."); gg("commit", "-q", "-m", "a code change nobody guarded")
            to_close(root, id)
            @test G.Run.close_run(root; io = devnull) == 2
            record = G.JSON3.read(read(joinpath(RUNS.dir(root, id), "run.json"), String), Dict{String,Any})
            @test record["stop"] == "CANNOT_EVALUATE"
        end
    end

    @testset "a documentation commit is not a code change" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            write(joinpath(root, "docs", "src", "guide.md"), "# Guide\n\nThe grid is a lattice.\n")
            gg("add", "--all", "."); gg("commit", "-q", "-m", "prose only")
            to_close(root, id)
            @test G.Run.close_run(root; io = devnull) == 0             # nothing found, nothing unguarded
            record = G.JSON3.read(read(joinpath(RUNS.dir(root, id), "run.json"), String), Dict{String,Any})
            @test record["stop"] == "DONE"
        end
    end

    # A guarded commit made while a run is open looks past the run's own untracked record, stages only
    # the ruled paths, and carries the trailer close trusts.
    @testset "a guarded commit succeeds while a run is open, and carries the trailer" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            write(joinpath(root, "docs", "src", "guide.md"), "# Guide\n\nThe grid is a lattice.\n")
            @test G.Docfix.commit(root, "a prose fix"; io = devnull) == 0
            log = readchomp(setenv(`git -C $root log -1 --format=%B`; dir = root))
            @test occursin(RUNS.GUARD_TRAILER, log)
            tracked = readchomp(setenv(`git -C $root ls-files .gbg/runs`; dir = root))
            @test isempty(tracked)                                     # the run's record was not staged
            @test isempty(RUNS.unguarded_code(root, RUNS.load(root, id).first_commit))
        end
    end

    # ── the pass: fix, verify blind, verify with the diff, graded by a program (design §4.3)

    # The whole happy path: a finding, a guarded fix carrying its trailer, a blind verifier that quotes
    # the new text, a diff verifier that agrees, and a run that closes clean with the pass on record.
    @testset "a fix verified twice closes its finding, and the run closes clean" begin
        package() do root, gg
            id, fid = with_one_finding(root)
            @test G.Run.next(root; io = devnull) == 0                  # → fix, pass 1
            @test RUNS.stage_of(root, id) === :fix
            run = RUNS.load(root, id)
            @test run.passes == 1
            todo = G.JSON3.read(read(joinpath(AGENTS.stage_dir(root, id), "findings.json"), String))
            @test length(todo) == 1 && todo[1]["id"] == fid
            @test todo[1]["locations"][1]["line"] == 3                # re-anchored before the fixer sees it

            fixed_as(root, fid, "The grid is a lattice.")
            @test RUNS.fix_commits(root, run.first_commit, fid) |> length == 1

            @test G.Run.next(root; io = devnull) == 0                  # → verify: one blind verifier
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            @test length(args["roles"]) == 1
            v = args["roles"][1]
            @test v["kind"] == "verifier" && v["key"] == "verify-" * fid
            @test v["finding"]["id"] == fid && v["diff"] == ""        # blind: no diff
            @test v["kept_from_code"] == true                        # what the withheld reader was given
            @test "HIDES_CODE_DEFECT" in v["verdicts"]
            verifier_said(root, id, "verify", fid, "FIXED"; quote_ = "The grid is a lattice.")
            @test G.Run.collect(root; io = devnull) == 1              # graded; still open until the diff agrees
            @test only(RUNS.load(root, id).fixes).blind === MRun.Verdict.FIXED

            @test G.Run.next(root; io = devnull) == 0                  # → diff: the same finding, with its diff
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            d = only(args["roles"])
            @test d["key"] == "diff-" * fid && occursin("lattice", d["diff"]) && d["strength"] == "economy"
            verifier_said(root, id, "diff", fid, "FIXED"; quote_ = "The grid is a lattice.")
            @test G.Run.collect(root; io = devnull) == 0              # nothing open
            fix = only(RUNS.load(root, id).fixes)
            @test fix.with_diff === MRun.Verdict.FIXED && fix.pass == 1 && !isempty(fix.commit)

            @test G.Run.next(root; io = devnull) == 0                  # → close
            @test G.Run.close_run(root; io = devnull) == 0
            rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
            @test occursin("pass 1: blind verifier `FIXED`, with the diff `FIXED`", rep)
            @test occursin("1 of 4 fix pass", rep)
            @test !isfile(joinpath(root, ".claude", "WORK_QUEUE.md"))   # nothing was left over
            record = G.JSON3.read(read(joinpath(RUNS.dir(root, id), "run.json"), String), Dict{String,Any})
            @test record["passes"] == 1 && length(record["fixes"]) == 1
        end
    end

    # A verdict is worth its quote: FIXED with words the text does not hold is NOT_FIXED, and the
    # finding goes round again.
    @testset "a verdict without a quote in the text is NOT_FIXED" begin
        package() do root, gg
            id, fid = with_one_finding(root)
            G.Run.next(root; io = devnull)                               # fix
            fixed_as(root, fid, "The grid is a lattice.")
            G.Run.next(root; io = devnull)                               # verify
            verifier_said(root, id, "verify", fid, "FIXED"; quote_ = "words nobody wrote")
            @test G.Run.collect(root; io = devnull) == 1
            @test only(RUNS.load(root, id).fixes).blind === MRun.Verdict.NOT_FIXED
            @test G.Run.next(root; io = devnull) == 0                    # → diff, with nobody to ask
            @test RUNS.stage_of(root, id) === :diff
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            @test isempty(args["roles"])                                 # nothing was called fixed
            @test G.Run.collect(root; io = devnull) == 1
            @test G.Run.next(root; io = devnull) == 0                    # → fix again, pass 2
            @test RUNS.stage_of(root, id) === :fix && RUNS.load(root, id).passes == 2
        end
    end

    # The passes are capped: after the last one a further fix is refused, what is open carries over,
    # and each leftover is one line in the work queue under the heading the hook does not count.
    @testset "after the last pass the run closes, and what is open goes to the work queue" begin
        package() do root, gg
            id, fid = with_one_finding(root)
            cap = RUNS.load(root, id).budget.fix_passes
            for p in 1:cap
                @test G.Run.next(root; io = devnull) == 0 && RUNS.stage_of(root, id) === :fix
                @test G.Run.next(root; io = devnull) == 0 && RUNS.stage_of(root, id) === :verify
                verifier_said(root, id, "verify", fid, "NOT_FIXED")
                @test G.Run.collect(root; io = devnull) == 1
                @test G.Run.next(root; io = devnull) == 0 && RUNS.stage_of(root, id) === :diff
                @test G.Run.collect(root; io = devnull) == 1
            end
            @test RUNS.load(root, id).passes == cap
            @test !RUNS.advance!(root, id, :fix; io = devnull)           # a further pass is refused
            @test G.Run.next(root; io = devnull) == 0
            @test RUNS.stage_of(root, id) === :close
            @test G.Run.close_run(root; io = devnull) == 1
            queue = read(joinpath(root, ".claude", "WORK_QUEUE.md"), String)
            @test occursin("## From the last review", queue)
            @test occursin("- [ ] " * fid * " the grid is named but not said to be a lattice — `docs/src/guide.md`", queue)
            @test count("- [ ]", queue) == 1
            rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
            @test occursin("$cap of $cap fix pass", rep)
            @test count("blind verifier `NOT_FIXED`", rep) == cap
            # a second close over the same queue replaces the section rather than appending to it
            write(joinpath(root, ".claude", "WORK_QUEUE.md"), queue * "\n## Mine\n\n- [ ] the owner's own item\n")
            G.Run.queue_leftovers(root, RUNS.load(root, id))
            again = read(joinpath(root, ".claude", "WORK_QUEUE.md"), String)
            @test count("- [ ] " * fid, again) == 1 && occursin("the owner's own item", again)
        end
    end

    # The diff verifier's MADE_WORSE reverts the fix with a guarded revert: the old text is back, close
    # sees no code around the guard, and the finding stays open for the next pass.
    @testset "MADE_WORSE reverts the fix" begin
        package() do root, gg
            id, fid = with_one_finding(root)
            G.Run.next(root; io = devnull)
            fixed_as(root, fid, "The grid is a lattice.")
            G.Run.next(root; io = devnull)
            verifier_said(root, id, "verify", fid, "FIXED"; quote_ = "The grid is a lattice.")
            G.Run.collect(root; io = devnull)
            G.Run.next(root; io = devnull)
            verifier_said(root, id, "diff", fid, "MADE_WORSE"; quote_ = "The grid is a lattice.")
            @test G.Run.collect(root; io = devnull) == 1
            @test occursin("spectral", read(joinpath(root, "docs", "src", "guide.md"), String))
            @test only(RUNS.load(root, id).fixes).with_diff === MRun.Verdict.MADE_WORSE
            @test isempty(RUNS.unguarded_code(root, RUNS.load(root, id).first_commit))
            @test length(RUNS.open_findings(RUNS.load(root, id))) == 1
        end
    end

    # HIDES_CODE_DEFECT reverts too, puts a question to the owner, and parks the finding: no pass works
    # on it again, so the run closes rather than spending its passes describing code that looks wrong.
    @testset "HIDES_CODE_DEFECT reverts, asks the owner, and parks the finding" begin
        package() do root, gg
            id, fid = with_one_finding(root)
            G.Run.next(root; io = devnull)
            fixed_as(root, fid, "The grid is a lattice.")
            G.Run.next(root; io = devnull)
            verifier_said(root, id, "verify", fid, "HIDES_CODE_DEFECT"; quote_ = "The grid is a lattice.")
            @test G.Run.collect(root; io = devnull) == 1
            run = RUNS.load(root, id)
            @test occursin("spectral", read(joinpath(root, "docs", "src", "guide.md"), String))
            @test length(run.questions) == 1 && occursin("code right", run.questions[1].decision)
            @test RUNS.parked(run, fid)
            @test G.Run.next(root; io = devnull) == 0                    # nothing workable: straight to close
            @test RUNS.stage_of(root, id) === :close
            @test G.Run.close_run(root; io = devnull) == 1
            queue = read(joinpath(root, ".claude", "WORK_QUEUE.md"), String)
            @test occursin("waits on the owner's answer", queue)
        end
    end

    # NOT_A_DEFECT closes the finding for this run without a fix.
    @testset "NOT_A_DEFECT closes the finding" begin
        package() do root, gg
            id, fid = with_one_finding(root)
            G.Run.next(root; io = devnull)                               # fix: the session decides not to
            G.Run.next(root; io = devnull)                               # verify
            verifier_said(root, id, "verify", fid, "NOT_A_DEFECT"; quote_ = "The grid is spectral.")
            @test G.Run.collect(root; io = devnull) == 0
            @test RUNS.closed(RUNS.load(root, id), fid)
            @test G.Run.next(root; io = devnull) == 0 && RUNS.stage_of(root, id) === :close
            @test G.Run.close_run(root; io = devnull) == 0
        end
    end

    # A location the agents named is re-anchored on the way in, and the LINE is this package's to fill:
    # a line an agent reported would be its count of the text it was shown, not the file's.
    @testset "the line comes from the file, not from the agent" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            reader_found(root, id, "withheld", "a claim about line three")
            G.Run.collect(root; io = devnull)
            run = RUNS.load(root, id)
            @test length(run.findings) == 1
            loc = only(run.findings[1].draft.locations)
            @test loc.line == 3                                       # where the quote actually is
            @test loc.found !== MRun.Anchor.OUTDATED
        end
    end
end
