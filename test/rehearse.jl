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
# see, a close that accepted a run still at `pass`, a silent reader read as a clean one — was invisible
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

"""Write what one reader found, as the driver would have written it."""
function reader_found(root, id, role, claim; file = "docs/src/guide.md", quote_ = "The grid is spectral.")
    write(joinpath(RUNS.dir(root, id), "results", role * ".json"),
          """{"findings":[{"claim":"$claim","fix":"say which","locations":[{"file":"$file","text":"$quote_"}]}]}""")
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

            # The arguments are what the session needs and nothing it does not.
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            @test args["run"] == id
            @test !isempty(args["roles"])
            @test all(r -> haskey(r, "result_file") && haskey(r, "cap"), args["roles"])
            @test args["launches_left"] == args["launches_left"]   # present, and a number

            reader_found(root, id, "cold_reader", "a term is used before it is defined")
            @test G.Run.collect(root; io = devnull) == 2          # other readers wrote nothing: NOT clean
            @test to_close(root, id) === :close
            @test G.Run.close_run(root; io = devnull) == 1        # closed, with a finding

            rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
            @test occursin("used before it is defined", rep)
            @test occursin("Written by AI", rep)                  # a report is a page like any other
            @test occursin("docs/src/guide.md", rep)
            @test isfile(joinpath(RUNS.dir(root, id), "run.json"))
            @test !isfile(joinpath(RUNS.dir(root, id), "run.draft.json"))
            @test G.Run.open_run(root) === nothing                # and it is no longer open
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

    # The budget is fixed at start and nothing raises it. A stage that recomputed its allowance from the
    # instrument would spend the whole budget again on every pass.
    @testset "the budget is what is left, not what was allowed" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            first_left = G.JSON3.read(read(AGENTS.arguments_path(root, id), String),
                                      Dict{String,Any})["launches_left"]
            reader_found(root, id, "cold_reader", "something")
            G.Run.collect(root; io = devnull)
            G.Run.next(root; io = devnull)
            later = G.JSON3.read(read(AGENTS.arguments_path(root, id), String),
                                 Dict{String,Any})["launches_left"]
            @test later < first_left
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

    # A location the agents named is re-anchored on the way in, and the LINE is this package's to fill:
    # a line an agent reported would be its count of the text it was shown, not the file's.
    @testset "the line comes from the file, not from the agent" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            reader_found(root, id, "cold_reader", "a claim about line three")
            G.Run.collect(root; io = devnull)
            run = RUNS.load(root, id)
            @test length(run.findings) == 1
            loc = only(run.findings[1].draft.locations)
            @test loc.line == 3                                       # where the quote actually is
            @test loc.found !== MRun.Anchor.OUTDATED
        end
    end
end
