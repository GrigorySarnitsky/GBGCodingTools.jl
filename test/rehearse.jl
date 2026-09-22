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
const SITE = G.Orchestration.Site

"""
A git-initialised copy of the TRACKED FIXTURE, with one sentence of our own on its home page and the
site builder replaced. Returns its root and a `git` command for it.

The fixture rather than a package invented here: its config, its pages and its source are the ones a
consumer really has, so the units a reader is given are real pages and a quote found on one of them is
in a real file. The one seam is the BUILD — Documenter is not installed for the fixture, and a rehearsal
that built a site at every stage would cost minutes a test cannot spend — so `Site.BUILDER` renders each
configured page into the article body Documenter would have put it in. Everything after the build is the
run's own code: the pages, the units, one launch each, and the source a quote is placed in.
"""
function package(f)
    root = fixture_copy("rehearse-" * string(hash(f), base = 16))
    gg(a...) = Base.run(pipeline(setenv(Cmd(["git", "-C", root, a...]); dir = root);
                                 stdout = devnull, stderr = devnull))
    write(joinpath(root, "docs", "src", "index.md"), HOME_PAGE)
    gg("init", "-q"); gg("config", "user.name", "t"); gg("config", "user.email", "t@t")
    gg("add", "--all", "."); gg("commit", "-q", "-m", "the fixture, as it stands")
    old = SITE.BUILDER[]
    SITE.BUILDER[] = write_site
    try
        f(root, gg)
    finally
        SITE.BUILDER[] = old
    end
end

const HOME_PAGE = """
# GBG Fixture

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

The grid is spectral.
"""

"""
The site a build would have produced: every configured page as an article body, where the run's own
code then finds the pages, cuts them into units and maps each back to the file it was written in.
"""
function write_site(root, cfg; io = devnull)
    dir = joinpath(root, "docs", "build")
    src = joinpath(root, "docs", "src")
    for page in G.Texts.files(cfg, root, G.Model.FileSet.PAGES)
        stem = replace(relpath(joinpath(root, page), src), r"\.md$" => "")
        out = stem == "index" ? joinpath(dir, "index.html") : joinpath(dir, stem, "index.html")
        mkpath(dirname(out))
        body = replace(read(joinpath(root, page), String), "&" => "&amp;", "<" => "&lt;")
        write(out, "<html><body><nav>side bar</nav><article class=\"content\">" * body * "</article></body></html>")
    end
    return dir
end

"""
A build that refuses a page holding `BREAKS THE BUILD`, so a fix can be made to leave the site red.
"""
function picky_site(root, cfg; io = devnull)
    for page in G.Texts.files(cfg, root, G.Model.FileSet.PAGES)
        occursin("BREAKS THE BUILD", read(joinpath(root, page), String)) && return nothing
    end
    return write_site(root, cfg; io)
end

"""The reader given the home page alone: the key a result file of that launch is named by."""
const HOME_READER = "withheld@home"

"""Where the sentence the readers report sits in the home page: the line a program must find for itself."""
const HOME_LINE = findfirst(l -> occursin("The grid is spectral.", l), split(HOME_PAGE, '\n'))

"""A real change to code, which the guard must never call documentation: a new statement, not a comment."""
code_change(root) = write(joinpath(root, "src", "FixtureA.jl"),
    replace(read(joinpath(root, "src", "FixtureA.jl"), String),
            "end # module FixtureA" => "shadow(x) = x\n\nend # module FixtureA"))

"""
Write what one reader found, as the driver would have written it, into the current stage's results.

The payload goes through `JSON3.write` rather than string interpolation: a quote carrying a backslash —
which any quote of a formula does — is not JSON until it is escaped, and a file that does not parse is
read as a reader that wrote nothing, so the test would pass by testing nothing.
"""
function reader_found(root, id, role, claim; file = "docs/src/index.md", quote_ = "The grid is spectral.")
    mkpath(AGENTS.results_dir(root, id))
    payload = Dict("findings" => [Dict("claim" => claim, "fix" => "say which",
                                       "locations" => [Dict("file" => file, "text" => quote_)])],
                   "checked" => [file])
    write(joinpath(AGENTS.results_dir(root, id), role * ".json"), G.JSON3.write(payload))
end

"""Write one verifier's verdict, as the driver would have written it, for the current stage."""
function verifier_said(root, id, stage, finding, verdict; quote_ = "")
    mkpath(AGENTS.results_dir(root, id))
    write(joinpath(AGENTS.results_dir(root, id), string(stage, "-", finding, ".json")),
          """{"verdict":"$verdict","quote":"$quote_"}""")
end

"""Every launched reader but the named ones reports clean, so a collect is not exit 2 for their silence."""
function all_clean(root, id; except = String[])
    args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
    mkpath(AGENTS.results_dir(root, id))
    for r in args["roles"]
        key = String(r["key"])
        key in except && continue
        write(joinpath(AGENTS.results_dir(root, id), key * ".json"),
              """{"findings":[],"checked":["docs/src/index.md"]}""")
    end
end

"""A run with one finding collected, at its first collect: the pass machinery starts here."""
function with_one_finding(root)
    G.Run.start(root, :documentation_review; io = devnull)
    id = G.Run.open_run(root)
    reader_found(root, id, HOME_READER, "the grid is named but not said to be a lattice")
    all_clean(root, id; except = [HOME_READER])
    @test G.Run.collect(root; io = devnull) == 1
    return id, only(RUNS.load(root, id).findings).id
end

"""Commit a documentation edit as the fixer would, through the guard, for one finding."""
function fixed_as(root, fid, text)
    write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => text))
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

            reader_found(root, id, HOME_READER, "a term is used before it is defined")
            @test G.Run.collect(root; io = devnull) == 2          # other readers wrote nothing: NOT clean
            run = RUNS.load(root, id)
            @test run.agent_launches == 1                          # what arrived, not the panel's size
            @test only(run.findings).source === Symbol(HOME_READER)          # the finding names its reader
            @test to_close(root, id) === :close
            @test G.Run.close_run(root; io = devnull) == 1        # closed, with a finding

            rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
            @test occursin("used before it is defined", rep)
            @test occursin("Reported by `" * HOME_READER * "`", rep)
            @test occursin("Written by AI", rep)                  # a report is a page like any other
            @test occursin("docs/src/index.md", rep)
            @test isfile(joinpath(RUNS.dir(root, id), "run.json"))
            @test !isfile(joinpath(RUNS.dir(root, id), "run.draft.json"))
            @test !isdir(AGENTS.scratch_dir(root, id))            # the agents' files went with the run
            @test sort(readdir(RUNS.dir(root, id))) == ["report.md", "run.json", "stage"]
            @test G.Run.open_run(root) === nothing                # and it is no longer open
        end
    end

    # The withheld bundle is ONE PAGE: a single agent handed every page at once would be the reader with
    # siblings that the rules tagged for this bundle were kept away from.
    @testset "the reader given a page alone is launched once per built page" begin
        package() do root, gg
            @test G.Run.start(root, :documentation_review; io = devnull) == 0
            id = G.Run.open_run(root)
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            cfg = G.ConfigIO.read_config(root)
            built = SITE.pages(joinpath(root, "docs", "build"), G.ConfigIO.read_config(root), root)
            @test length(built) == length(G.Texts.files(cfg, root, G.Model.FileSet.PAGES))
            @test args["site"] == joinpath(root, "docs", "build")

            units = [r for r in args["roles"] if !isempty(String(r["unit"]))]
            @test length(units) == length(built)                     # one launch per page
            @test Set(String(r["key"]) for r in units) == Set("withheld@" * p.key for p in built)
            for r in units
                @test isfile(String(r["unit"]))
                @test r["kept_from_code"] === true
                text = read(String(r["unit"]), String)
                @test !occursin("side bar", text)                    # the article body, not the furniture
                @test !isempty(strip(text))
            end
            home = only(filter(r -> String(r["key"]) == HOME_READER, units))
            @test occursin("The grid is spectral.", read(String(home["unit"]), String))
            @test String(home["unit_source"]) == joinpath("docs", "src", "index.md")

            # the reader of the WHOLE site is one launch, with no unit
            whole = only(filter(r -> String(r["key"]) == "rendered", args["roles"]))
            @test isempty(String(whole["unit"])) && whole["site"] === true
            # and the reader with the source is neither
            full = only(filter(r -> String(r["key"]) == "full", args["roles"]))
            @test isempty(String(full["unit"])) && full["site"] === false
        end
    end

    # What judged the package is part of the record, and so is how its agents were launched.
    @testset "the model and the launch order are the run's own, and are recorded" begin
        package() do root, gg
            @test G.Run.start(root, :documentation_review; io = devnull, model = "opus", sequential = true) == 0
            id = G.Run.open_run(root)
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            @test args["sequential"] === true
            @test args["models"]["full"] == "opus" && args["models"]["economy"] == AGENTS.ECONOMY_MODEL
            all_clean(root, id)
            G.Run.collect(root; io = devnull)
            to_close(root, id); G.Run.close_run(root; io = devnull)
            record = G.JSON3.read(read(joinpath(RUNS.dir(root, id), "run.json"), String), Dict{String,Any})
            @test record["model"] == "opus" && record["sequential"] === true
        end
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)     # named none: the session's own
            id = G.Run.open_run(root)
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            @test args["models"]["full"] == "session" && args["sequential"] === false
        end
    end

    # A panel launched without its rendered readers is not the panel the rules were tagged for.
    @testset "a build that fails leaves the run where it stood" begin
        package() do root, gg
            SITE.BUILDER[] = (r, c; io = devnull) -> nothing
            try
                @test G.Run.start(root, :documentation_review; io = devnull) == 2
                id = G.Run.open_run(root)
                @test RUNS.stage_of(root, id) === :start              # not at find with nothing written
                SITE.BUILDER[] = write_site
                @test G.Run.next(root; io = devnull) == 0             # and the build fixed, it goes on
                @test RUNS.stage_of(root, id) === :find
            finally
                SITE.BUILDER[] = write_site
            end
        end
    end

    # A verifier is given what the reader was given: for a reader given one page, that page as it now
    # stands, rebuilt after the fix.
    @testset "a verifier of a page reader is given that page, rebuilt" begin
        package() do root, gg
            id, fid = with_one_finding(root)
            G.Run.next(root; io = devnull)                            # fix
            fixed_as(root, fid, "The grid is a lattice.")
            G.Run.next(root; io = devnull)                            # verify
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            v = only(args["roles"])
            @test v["kind"] == "verifier" && !isempty(String(v["unit"]))
            page = read(String(v["unit"]), String)
            @test occursin("The grid is a lattice.", page)            # the page as it now stands
            @test !occursin("The grid is spectral.", page)
        end
    end

    # A reader given one built page quotes the PAGE, and the words may have been rendered from a
    # docstring in the source. The collector searches the documentation for them, so the fixer is sent
    # to the file the sentence is written in rather than to the page it was read on.
    @testset "a quote rendered from a docstring is placed in the file it is written in" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            reader_found(root, id, "withheld@api-FixtureA", "the allocating form does not say what it allocates";
                         file = "docs/src/api/FixtureA.md",
                         quote_ = "Allocating form of")
            all_clean(root, id; except = ["withheld@api-FixtureA"])
            @test G.Run.collect(root; io = devnull) == 1
            loc = only(only(RUNS.load(root, id).findings).draft.locations)
            @test loc.file == joinpath("src", "FixtureA.jl")          # not the page it was read on
            @test loc.found !== MRun.Anchor.OUTDATED
            @test occursin("scale", loc.node)                          # and the binding it sits in
        end
    end

    # A reader whose file does not parse, or that reports nothing and says it examined nothing, is
    # SILENT: the design relaunches it once and then names it, and never reads it as clean.
    @testset "a malformed or empty result is a silent reader, not a clean one" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            mkpath(AGENTS.results_dir(root, id))
            write(joinpath(AGENTS.results_dir(root, id), HOME_READER * ".json"), "{not json")
            write(joinpath(AGENTS.results_dir(root, id), "full.json"), """{"findings":[],"checked":[]}""")
            write(joinpath(AGENTS.results_dir(root, id), "rendered.json"), """{"findings":[],"checked":["docs/src/index.md"]}""")
            _, _, silent, arrived, wrote = AGENTS.collect_results(root, id, G.ConfigIO.read_config(root))
            @test wrote == 1
            @test arrived == 3
            @test HOME_READER in silent && "full" in silent && !("rendered" in silent)
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

    # A sentence is written in more places than the reader who reported it looked at. A fix made only
    # where it was reported leaves the rest standing, and a fourth copy of a corrected formula once
    # survived a whole run.
    @testset "the fix pass finds the other copies of what a finding quotes" begin
        package() do root, gg
            # the same sentence, and the same formula, on a second page
            write(joinpath(root, "docs", "src", "notation.md"),
                  read(joinpath(root, "docs", "src", "notation.md"), String) *
                  "\n\nThe grid is spectral.\n")
            gg("add", "--all", "."); gg("commit", "-q", "-m", "a second page says the same")
            id, fid = with_one_finding(root)
            G.Run.next(root; io = devnull)                               # fix
            todo = G.JSON3.read(read(joinpath(AGENTS.stage_dir(root, id), "findings.json"), String))
            files = [String(l["file"]) for l in todo[1]["locations"]]
            @test joinpath("docs", "src", "index.md") in files
            @test joinpath("docs", "src", "notation.md") in files        # the copy the reader never saw
            @test length(files) == 2
        end
    end

    # A formula travels between documents without the sentence that carried it, so a fix that followed
    # only the sentence would leave the formula wrong wherever it was written alone.
    @testset "a formula inside a quote is searched for on its own" begin
        package() do root, gg
            energy = raw"E = \tfrac{1}{2} h \sum_i u_i^2"
            write(joinpath(root, "docs", "src", "index.md"),
                  replace(HOME_PAGE, "The grid is spectral." => "The energy is \$$energy\$ at every node."))
            # the same formula on another page, in a sentence of its own
            write(joinpath(root, "docs", "src", "notation.md"),
                  read(joinpath(root, "docs", "src", "notation.md"), String) *
                  "\n\nThe discrete energy is \$$energy\$.\n")
            gg("add", "--all", "."); gg("commit", "-q", "-m", "a formula written twice")
            cfg = G.ConfigIO.read_config(root)

            @test G.Texts.formulas("The energy is \$$energy\$ at every node.") == [energy]
            @test isempty(G.Texts.formulas("no mathematics here"))
            @test G.Texts.formulas(raw"a single $x$ is not searched for") == []

            found = G.Texts.occurrences(cfg, root, energy)
            # the fixture writes this formula in its own documents too, which is the point: every copy
            @test joinpath("docs", "src", "index.md") in [l.file for l in found]
            @test joinpath("docs", "src", "notation.md") in [l.file for l in found]
            @test length(unique(l.file for l in found)) >= 3
            @test all(l -> l.found === MRun.Anchor.BY_QUOTE, found)

            # and a finding reported on one page reaches the other through the fix pass
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            reader_found(root, id, HOME_READER, "the one half is unexplained";
                         file = joinpath("docs", "src", "index.md"),
                         quote_ = "The energy is \$$energy\$ at every node.")
            all_clean(root, id; except = [HOME_READER])
            G.Run.collect(root; io = devnull)
            G.Run.next(root; io = devnull)
            todo = G.JSON3.read(read(joinpath(AGENTS.stage_dir(root, id), "findings.json"), String))
            @test joinpath("docs", "src", "notation.md") in [String(l["file"]) for l in todo[1]["locations"]]
        end
    end

    # A red docs build must not be left on the branch by a run whose whole subject was the documentation.
    @testset "close puts the documentation back when the build is red" begin
        package() do root, gg
            id, fid = with_one_finding(root)
            SITE.BUILDER[] = picky_site
            try
                G.Run.next(root; io = devnull)                       # fix
                fixed_as(root, fid, "BREAKS THE BUILD.")
                @test occursin("BREAKS THE BUILD", read(joinpath(root, "docs", "src", "index.md"), String))
                @test length(RUNS.guarded_commits(root, RUNS.load(root, id).first_commit)) == 1
                # the verifier stage cannot build either, so the run goes to close through abandonment
                # of the pass: drive it to close and let close do the restoring
                RUNS.write_stage(root, id, length(RUNS.STAGES[:documentation_review]))
                @test G.Run.close_run(root; io = devnull) == 2       # reverted, and not evaluable
                @test !occursin("BREAKS THE BUILD", read(joinpath(root, "docs", "src", "index.md"), String))
                @test occursin("The grid is spectral.", read(joinpath(root, "docs", "src", "index.md"), String))
                record = G.JSON3.read(read(joinpath(RUNS.dir(root, id), "run.json"), String), Dict{String,Any})
                @test record["stop"] == "CANNOT_EVALUATE"
                @test occursin("The documentation was put back", read(joinpath(RUNS.dir(root, id), "report.md"), String))
                # the revert went through the guard, so close does not also call it unguarded code
                @test isempty(RUNS.unguarded_code(root, RUNS.load(root, id).first_commit))
            finally
                SITE.BUILDER[] = write_site
            end
        end
    end

    # A build that was red before the run is not the run's to repair.
    @testset "a build red before the run is not undone by it" begin
        package() do root, gg
            write(joinpath(root, "docs", "src", "notation.md"),
                  read(joinpath(root, "docs", "src", "notation.md"), String) * "\nBREAKS THE BUILD\n")
            gg("add", "--all", "."); gg("commit", "-q", "-m", "a page that will not build")
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            all_clean(root, id); G.Run.collect(root; io = devnull)
            SITE.BUILDER[] = picky_site
            try
                to_close(root, id)
                @test G.Run.close_run(root; io = devnull) == 0       # the run found nothing and broke nothing
                # nothing of the package was reverted: the run committed nothing
                @test occursin("BREAKS THE BUILD", read(joinpath(root, "docs", "src", "notation.md"), String))
                rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
                @test occursin("The site does not build", rep)       # and the report says so
                record = G.JSON3.read(read(joinpath(RUNS.dir(root, id), "run.json"), String), Dict{String,Any})
                @test record["stop"] == "DONE"                       # the red build is older than the run
            finally
                SITE.BUILDER[] = write_site
            end
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
            @test !occursin(fid, read(joinpath(root, ".claude", "WORK_QUEUE.md"), String))
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
            reader_found(root, id, HOME_READER, "one")
            reader_found(root, id, "full", "two")
            before = length(G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})["roles"])
            @test G.Run.next(root; io = devnull) == 0                    # continue: the rest are missing
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            launch = Dict(String(r["key"]) => r["launch"] for r in args["roles"])
            @test launch[HOME_READER] === false && launch["full"] === false && launch["rendered"] === true
            @test length(args["roles"]) == before                        # the collect still expects everyone
            all_clean(root, id; except = [HOME_READER, "full"])
            @test G.Run.next(root; io = devnull) == 2                    # every agent wrote: collect
            @test G.Run.collect(root; io = devnull) == 1
            @test length(RUNS.load(root, id).findings) == 2              # each collected once
            @test RUNS.load(root, id).agent_launches == before
        end
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            reader_found(root, id, HOME_READER, "one")
            write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
            gg("add", "--all", "."); gg("commit", "-q", "-m", "the tree moves under the run")
            @test G.Run.next(root; io = devnull) == 2                    # moved: the owner decides
            @test RUNS.stage_of(root, id) === :find                      # and nothing was taken
            @test G.Run.abandon(root; io = devnull) == 0
        end
    end

    # The agents read one tree; a collect over another would anchor their quotes in the wrong text.
    @testset "a tree that changed under the agents is not collected" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            reader_found(root, id, HOME_READER, "one"); all_clean(root, id; except = [HOME_READER])
            code_change(root)
            @test G.Run.collect(root; io = devnull) == 2                 # an uncommitted edit
            @test RUNS.stage_of(root, id) === :find && isempty(RUNS.load(root, id).findings)
            gg("add", "src"); gg("commit", "-q", "-m", "committed under the readers")
            @test G.Run.collect(root; io = devnull) == 2                 # a commit
            gg("reset", "-q", "--hard", "HEAD~1")                        # the tree restored (the run's files are untracked)
            @test G.Run.collect(root; io = devnull) == 1                 # collected
        end
    end

    # What a run leaves open, the next run of the same instrument carries, under the old id.
    @testset "a second run carries the first's open findings" begin
        package() do root, gg
            id, fid = with_one_finding(root)
            cap = RUNS.load(root, id).budget.fix_passes
            for p in 1:cap
                G.Run.next(root; io = devnull); G.Run.next(root; io = devnull)
                verifier_said(root, id, "verify", fid, "NOT_FIXED")
                G.Run.collect(root; io = devnull); G.Run.next(root; io = devnull); G.Run.collect(root; io = devnull)
            end
            G.Run.next(root; io = devnull)
            @test G.Run.close_run(root; io = devnull) == 1
            # the session commits the closed run and the queue line it wrote, as it commits any run
            gg("add", "--all", "."); gg("commit", "-q", "-m", "the first run, closed")
            @test G.Run.start(root, :documentation_review; io = devnull) == 0
            id2 = G.Run.open_run(root)
            @test id2 != id
            second = RUNS.load(root, id2)
            @test [f.id for f in second.findings] == [fid]                # carried, under its old id
            @test only(second.findings).source === Symbol(HOME_READER)
            @test only(only(second.findings).draft.locations).line == HOME_LINE   # re-anchored
            @test to_close(root, id2) === :close
            @test G.Run.close_run(root; io = devnull) == 1
            rep = read(joinpath(RUNS.dir(root, id2), "report.md"), String)
            @test occursin("carried over from an earlier run", rep)
            queue = read(joinpath(root, ".claude", "WORK_QUEUE.md"), String)
            @test count("- [ ] " * fid, queue) == 1                        # one line, not one per run
            # A third start after an abandoned run carries nothing: the owner dropped them. This run
            # launched nothing, but it was CARRYING the finding, so `abandon` keeps its record — the
            # record is what makes the drop stick. Delete it and the next start reads past it to the run
            # before, and the findings he dropped come back (ruled 2026-09-22).
            gg("add", "--all", "."); gg("commit", "-q", "-m", "the second run, closed")
            G.Run.start(root, :documentation_review; io = devnull)
            kept = RUNS.dir(root, G.Run.open_run(root))
            @test G.Run.abandon(root; io = devnull) == 0
            @test isfile(joinpath(kept, "run.json"))
            gg("add", "--all", "."); gg("commit", "-q", "-m", "the abandoned run")
            G.Run.start(root, :documentation_review; io = devnull)
            @test isempty(RUNS.load(root, G.Run.open_run(root)).findings)
        end
    end

    # A tracked change already in the tree would be committed by the fixer under the guard's name.
    @testset "a start on a dirty tree is refused" begin
        package() do root, gg
            code_change(root)
            @test G.Run.start(root, :documentation_review; io = devnull) == 2
            @test G.Run.open_run(root) === nothing
            write(joinpath(root, "docs", "src", "untracked.md"), "# New\n")     # untracked does not count
            gg("checkout", "--", "src/FixtureA.jl")
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
            reader_found(root, id, HOME_READER, "something")
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
            G.Run.collect(root; io = devnull)                            # the readers are in; the change comes after
            code_change(root)
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
            G.Run.collect(root; io = devnull)
            write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
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
            write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
            # Not without a finding, while a run is open: the verifiers find a fix by that trailer, so
            # one committed without it is never verified and its finding stays open with nothing saying
            # why. Nothing is committed, so the edit is still there to commit properly.
            @test G.Docfix.commit(root, "a prose fix"; io = devnull) == 2
            @test !occursin(RUNS.GUARD_TRAILER, readchomp(setenv(`git -C $root log -1 --format=%B`; dir = root)))
            @test G.Docfix.commit(root, "a prose fix"; io = devnull, finding = id * "-f1") == 0
            log = readchomp(setenv(`git -C $root log -1 --format=%B`; dir = root))
            @test occursin(RUNS.GUARD_TRAILER, log)
            @test occursin(RUNS.FINDING_TRAILER * id * "-f1", log)
            tracked = readchomp(setenv(`git -C $root ls-files .gbg/runs`; dir = root))
            @test isempty(tracked)                                     # the run's record was not staged
            @test isempty(RUNS.unguarded_code(root, RUNS.load(root, id).first_commit))
        end
    end

    # The queue is the session's note of what it still owes, and the hook that reads it is what keeps a
    # session walking a run to its end — so it is at its most useful while a run is open. Until
    # 2026-09-23 writing one line into it made every remaining fix of the pass uncommittable, because
    # the fixer classifies the whole tree and refuses if one file is code. The session had to choose
    # between the machine that keeps it working and the machine that lets it work.
    @testset "the work queue does not block a fix commit" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            mkpath(joinpath(root, ".claude"))
            write(joinpath(root, ".claude", "WORK_QUEUE.md"), "# Work queue\n\n- [ ] keep going\n")
            gg("add", "--all", "."); gg("commit", "-q", "-m", "a queue to keep")
            write(joinpath(root, ".claude", "WORK_QUEUE.md"), "# Work queue\n\n- [x] keep going\n")
            write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
            @test G.Docfix.commit(root, "a prose fix"; io = devnull, finding = id * "-f1") == 0
            # committed the prose, left the queue for the close
            @test occursin("WORK_QUEUE", readchomp(setenv(`git -C $root status --porcelain`; dir = root)))
            @test !occursin("WORK_QUEUE", readchomp(setenv(`git -C $root show --name-only --format= HEAD`; dir = root)))
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
            @test todo[1]["locations"][1]["line"] == HOME_LINE       # re-anchored before the fixer sees it

            fixed_as(root, fid, "The grid is a lattice.")
            @test RUNS.fix_commits(root, run.first_commit, fid) |> length == 1

            @test G.Run.next(root; io = devnull) == 0                  # → verify: one blind verifier
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            @test length(args["roles"]) == 1
            v = args["roles"][1]
            @test v["kind"] == "verifier" && v["key"] == "verify-" * fid
            # The finding is a PATH, and the diff is absent: the blind verifier is not shown the change,
            # and what it IS shown is a file it reads rather than a paragraph in the arguments.
            @test v["finding"] == fid && v["diff_file"] == ""
            @test isfile(v["finding_file"])
            @test G.JSON3.read(read(v["finding_file"], String), Dict{String,Any})["id"] == fid
            @test v["kept_from_code"] == true                        # what the withheld reader was given
            @test "HIDES_CODE_DEFECT" in v["verdicts"]
            verifier_said(root, id, "verify", fid, "FIXED"; quote_ = "The grid is a lattice.")
            @test G.Run.collect(root; io = devnull) == 1              # graded; still open until the diff agrees
            @test only(RUNS.load(root, id).fixes).blind === MRun.Verdict.FIXED

            @test G.Run.next(root; io = devnull) == 0                  # → diff: the same finding, with its diff
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            d = only(args["roles"])
            @test d["key"] == "diff-" * fid && d["strength"] == "economy"
            @test occursin("lattice", read(d["diff_file"], String))
            # The standpoint is in the shared table under the key the role names, not written out here.
            @test haskey(args["briefs"], d["brief"]) && !isempty(args["briefs"][d["brief"]])
            verifier_said(root, id, "diff", fid, "FIXED"; quote_ = "The grid is a lattice.")
            @test G.Run.collect(root; io = devnull) == 0              # nothing open
            fix = only(RUNS.load(root, id).fixes)
            @test fix.with_diff === MRun.Verdict.FIXED && fix.pass == 1 && !isempty(fix.commit)

            @test G.Run.next(root; io = devnull) == 0                  # → close
            @test G.Run.close_run(root; io = devnull) == 0
            rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
            @test occursin("pass 1: blind verifier `FIXED`, with the diff `FIXED`", rep)
            @test occursin("1 of 4 fix pass", rep)
            @test !occursin(fid, read(joinpath(root, ".claude", "WORK_QUEUE.md"), String))  # nothing left over
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
            @test occursin("- [ ] " * fid * " the grid is named but not said to be a lattice — `docs/src/index.md`", queue)
            @test count("- [ ] " * fid, queue) == 1
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
            @test occursin("spectral", read(joinpath(root, "docs", "src", "index.md"), String))
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
            @test occursin("spectral", read(joinpath(root, "docs", "src", "index.md"), String))
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
            reader_found(root, id, HOME_READER, "a claim about line three")
            G.Run.collect(root; io = devnull)
            run = RUNS.load(root, id)
            @test length(run.findings) == 1
            loc = only(run.findings[1].draft.locations)
            @test loc.line == HOME_LINE                               # where the quote actually is
            @test loc.found !== MRun.Anchor.OUTDATED
        end
    end
end

# A run that launched nothing must not report a clean package. This is the dead-lane-read-as-clean
# failure the instrument exists to prevent, and until 2026-09-22 it appeared in the instrument's own
# output: both runs GBGPeriodicFields abandoned wrote "Every reader wrote its file and none of them
# reported a defect", three lines under a sentence saying 0 agents had launched. A report is a
# publishable page carrying the provenance banner, so a document asserting that a package was read and
# found clean when it was never read is worse than no document at all.
@testset "a run that read nothing does not report a clean package" begin
    cfg = G.Model.Config(package = "Sample", tool = :dev)
    base = (instrument = :documentation_review, tool_version = "vdev", first_commit = "abc",
            budget = G.Model.Budget())

    @testset "nothing launched says nothing was READ" begin
        run = G.Model.Run(; id = "r-none", base..., stage = :close, agent_launches = 0,
                          stop = G.Model.Stop.OWNER_STOPPED)
        text = G.Render.report(run, cfg)
        @test occursin("Nothing was read", text)
        @test occursin("says NOTHING about Sample", text)
        @test !occursin("Nothing was found", text)
        @test !occursin("none of them reported a defect", text)
    end

    @testset "agents launched and nothing found says so, and says which readers" begin
        run = G.Model.Run(; id = "r-clean", base..., stage = :close, agent_launches = 7,
                          stop = G.Model.Stop.DONE)
        text = G.Render.report(run, cfg)
        @test occursin("Nothing was found", text)
        @test occursin("Every reader that was launched", text)
        @test !occursin("Nothing was read", text)
    end

    # The two are told apart by whether an agent ran, not by how the run ended: a run the owner stopped
    # AFTER its readers had reported is a different thing from one that never launched.
    @testset "the distinction is the launches, not the ending" begin
        stopped_late = G.Model.Run(; id = "r-late", base..., stage = :close, agent_launches = 4,
                                   stop = G.Model.Stop.OWNER_STOPPED)
        @test occursin("Nothing was found", G.Render.report(stopped_late, cfg))
        never_ran = G.Model.Run(; id = "r-never", base..., stage = :close, agent_launches = 0,
                                stop = G.Model.Stop.CANNOT_EVALUATE)
        @test occursin("Nothing was read", G.Render.report(never_ran, cfg))
    end

    # The third reading, and the one the fix above left standing: `abandon` empties the list and leaves
    # the launch count alone, so a run that found a hundred and was stopped looked, in the record, exactly
    # like a run that looked and found nothing. `dropped` is what separates them.
    @testset "findings thrown away are not findings absent" begin
        stopped = G.Model.Run(; id = "r-dropped", base..., stage = :close, agent_launches = 26,
                              stop = G.Model.Stop.OWNER_STOPPED, dropped = 142)
        text = G.Render.report(stopped, cfg)
        @test occursin("142 finding(s) were thrown away", text)
        @test occursin("says NOTHING about Sample", text)
        @test !occursin("Nothing was found", text)
        @test !occursin("none of them reported a defect", text)
    end

    # And a run stopped with nothing in hand still reads as clean-but-unstood-behind, not as dropped:
    # the count is the evidence, and zero is no evidence.
    @testset "a stopped run that found nothing is not reported as dropping anything" begin
        empty_handed = G.Model.Run(; id = "r-empty", base..., stage = :close, agent_launches = 4,
                                   stop = G.Model.Stop.OWNER_STOPPED, dropped = 0)
        @test occursin("Nothing was found", G.Render.report(empty_handed, cfg))
        @test !occursin("thrown away", G.Render.report(empty_handed, cfg))
    end
end

# What `gbg run abandon` leaves behind, which turns on whether an agent ever ran — the same line the
# report draws between "nothing was read" and "nothing was found" (ruled 2026-09-22).
@testset "abandoning leaves evidence, or leaves nothing" begin
    function opened(; launches::Int)
        root = mktempdir(; cleanup = true); mkpath(joinpath(root, ".gbg"))
        write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
        id = "2026-09-22-documentation-review-01"
        run = G.Model.Run(id = id, instrument = :documentation_review, tool_version = "vdev",
                          first_commit = "abc", budget = G.Model.Budget(), stage = :find,
                          agent_launches = launches)
        mkpath(G.Orchestration.Runs.dir(root, id))
        G.Orchestration.Runs.save(root, run)
        G.Orchestration.Runs.write_stage(root, id, 2)
        return root, id
    end

    @testset "a run that launched nothing and carried nothing is deleted, id and all" begin
        root, id = opened(launches = 0)
        @test isdir(G.Orchestration.Runs.dir(root, id))
        out = IOBuffer()
        @test G.Run.abandon(root; io = out) == 0
        @test occursin("its record is deleted", String(take!(out)))
        @test !isdir(G.Orchestration.Runs.dir(root, id))      # nothing to keep and nothing to commit
        @test G.Run.open_run(root) === nothing                # and nothing is open any more
    end

    # A run that launched nothing but was CARRYING findings keeps its record: abandoning it DROPS those
    # findings, and the record is what makes the drop stick. Without it the next run reads past to the
    # run before and the dropped findings come back — caught by the rehearsal the hour this was written.
    @testset "a run carrying findings keeps its record even having launched nothing" begin
        root, id = opened(launches = 0)
        run = G.Orchestration.Runs.load(root, id)
        carried = G.Model.Finding("F1", :full, G.Model.Decider.AGENT,
                                  G.Model.FindingDraft(claim = "carried in from the last run"))
        G.Orchestration.Runs.save(root, G.Orchestration.Runs.with_questions(run, run.questions))
        G.Orchestration.Runs.save(root, G.Model.Run(id = run.id, instrument = run.instrument,
            tool_version = run.tool_version, first_commit = run.first_commit, budget = run.budget,
            stage = run.stage, findings = [carried], agent_launches = 0))
        out = IOBuffer()
        @test G.Run.abandon(root; io = out) == 0
        @test occursin("Commit .gbg/runs/", String(take!(out)))
        @test isfile(joinpath(G.Orchestration.Runs.dir(root, id), "run.json"))
    end

    @testset "a run whose agents ran keeps its record, to be committed" begin
        root, id = opened(launches = 5)
        out = IOBuffer()
        @test G.Run.abandon(root; io = out) == 0
        text = String(take!(out))
        @test occursin("Commit .gbg/runs/", text)
        @test isfile(joinpath(G.Orchestration.Runs.dir(root, id), "run.json"))
        @test isfile(joinpath(G.Orchestration.Runs.dir(root, id), "report.md"))
        # Its agents read the package, so the report may not say the package was never read.
        @test !occursin("Nothing was read", read(joinpath(G.Orchestration.Runs.dir(root, id), "report.md"), String))
    end
end

# The stop hook holds a session open while a RUN is open, not only while the work queue is. A run is
# walked stage by stage by the session, so stopping in the middle spends its agents for nothing and
# leaves a run that blocks the next one — and the queue cannot catch it, because a run writes its queue
# lines at CLOSE, the point it has not reached. Added 2026-09-22, after the first real review stopped
# between stages to report.
@testset "the stop hook holds a session open while a run is" begin
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".claude")); write(joinpath(root, ".claude", "WORK_QUEUE.md"), "# queue\n")
    sh = joinpath(root, "hook.sh")
    write(sh, G.Render.hook(G.Model.Config(package = "P", tool = :dev))); chmod(sh, 0o755)

    function fire(payload)
        err = IOBuffer()
        cmd = setenv(`bash $sh`, ["CLAUDE_PROJECT_DIR" => root]; dir = root)
        p = run(pipeline(cmd; stdin = IOBuffer(payload), stdout = devnull, stderr = err); wait = false)
        wait(p)
        return p.exitcode, String(take!(err))
    end

    @test first(fire("{}")) == 0                       # nothing open: the turn may end
    d = joinpath(root, ".gbg", "runs", "2026-09-22-documentation-review-01")
    mkpath(d); write(joinpath(d, "stage"), "4")        # a stage and no run.json is an open run

    code, msg = fire("{}")
    @test code == 2                                    # held open
    @test occursin("A RUN IS OPEN", msg) && occursin("documentation-review-01", msg)
    @test occursin("stage 4", msg)                     # and says where it stands
    # Abandoning drops the findings, so it is never offered as the way to end a turn.
    @test occursin("Do NOT abandon", msg)
    @test occursin("leave it OPEN", msg)

    # A harness, not a cage: a session already being held open is not blocked a second time.
    @test first(fire("{\"stop_hook_active\": true}")) == 0

    write(joinpath(d, "run.json"), "{}")               # closed or abandoned
    @test first(fire("{}")) == 0
end

# A record is written as JSON and read back, and the two halves are written by hand, side by side, in
# one file. Nothing made them agree. Twice now a field reached the record and not the reader, and the
# symptom is the same both times and invisible: the value is silently the default on the next load, so
# a run remembers less of itself at every stage boundary and no test fails. The questions went that way
# once; `dropped` would have gone the same way. This walks `fieldnames` rather than a list, so the
# NEXT field is covered by a test written before it existed.
@testset "every field of a record survives being written and read" begin
    run = G.Model.Run(id = "roundtrip-01", instrument = :documentation_review, tool_version = "v9.9.9",
                      first_commit = "0123456789abcdef", budget = G.Model.Budget(fix_passes = 2),
                      stage = :verify, agent_launches = 26, tokens = 4242,
                      stop = G.Model.Stop.OWNER_STOPPED, readers = :both, passes = 3,
                      model = "opus", sequential = true, scope = :changed, base = "feedface",
                      driver = "e3b0c44298fc1c14", already_failing = [:PROSE_SHAPE, :ARGS_FORM],
                      dropped = 142)
    back = RUNS.from_dict(G.JSON3.read(G.JSON3.write(RUNS.as_dict(run)), Dict{String,Any}))
    for f in fieldnames(G.Model.Run)
        # The four list-valued fields carry their own types and are round-tripped by the suites that
        # build them; every scalar is compared here, and a new scalar joins this loop by being declared.
        f in (:findings, :fixes, :questions, :code_fixes) && continue
        @test getfield(back, f) == getfield(run, f)
    end
    # And the default is never mistaken for a value that was written: a record with no `dropped` key —
    # every record written before this field existed — reads as zero, not as missing.
    old = RUNS.as_dict(run); delete!(old, "dropped")
    @test RUNS.from_dict(G.JSON3.read(G.JSON3.write(old), Dict{String,Any})).dropped == 0
end
