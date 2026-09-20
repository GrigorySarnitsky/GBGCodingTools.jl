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

"""Drive the open run forward until it is ready to close."""
function to_close(root, id)
    for _ in 1:8
        RUNS.stage_of(root, id) === :close && break
        G.Run.next(root; io = devnull)
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
            _, silent, arrived = AGENTS.collect_results(root, id)
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
            @test RUNS.stage_of(root, id) === :find                    # and nothing moved
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
