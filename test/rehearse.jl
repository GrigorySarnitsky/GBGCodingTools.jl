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
function reader_found(root, id, role, claim; file = "docs/src/index.md", quote_ = "The grid is spectral.",
                      rule = nothing)
    mkpath(AGENTS.results_dir(root, id))
    f = Dict{String,Any}("claim" => claim, "fix" => "say which",
                         "locations" => [Dict("file" => file, "text" => quote_)])
    rule === nothing || (f["rule"] = rule)
    payload = Dict("findings" => [f],
                   "checked" => [file])
    write(joinpath(AGENTS.results_dir(root, id), role * ".json"), G.JSON3.write(payload))
end

"""Write one verifier's verdict, as the driver would have written it, for the current stage."""
function verifier_said(root, id, stage, finding, verdict; quote_ = "")
    # One verifier per unit answers for every finding of it: the result file is the role's whose
    # finding list names this finding, and holds one verdict per finding.
    args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
    role = findfirst(r -> finding in strip.(split(String(r["finding"]), ",")), args["roles"])
    role === nothing && error("no verifier of this stage is asked about $finding")
    key = String(args["roles"][role]["key"])
    path = joinpath(AGENTS.results_dir(root, id), key * ".json")
    have = isfile(path) ? G.JSON3.read(read(path, String), Dict{String,Any}) : Dict{String,Any}("verdicts" => Any[])
    vs = Any[v for v in get(have, "verdicts", Any[]) if String(get(v, "finding", "")) != finding]
    push!(vs, Dict("finding" => finding, "verdict" => verdict, "quote" => quote_))
    mkpath(dirname(path))
    write(path, G.JSON3.write(Dict("verdicts" => vs)))
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

"""
One role as the driver sees it: the wire entry, its kind's shared fields, and the three paths built from
the key and a directory. The tests read roles this way so they see what an agent is given, not the wire.
"""
function whole(args, r)
    k = args["kinds"][r["kind"]]
    out = merge(Dict{String,Any}(k), Dict{String,Any}(r))
    out["kind"] = k["kind"]
    out["result_file"] = joinpath(args["dirs"]["results"], r["key"] * ".json")
    out["finding_file"] = isempty(r["finding"]) ? "" : joinpath(args["dirs"]["material"], r["key"] * ".json")
    out["diff_file"] = k["diff"] ? joinpath(args["dirs"]["material"], r["key"] * ".diff") : ""
    return out
end

"""The launch marks the DRIVER copy carries, read off the arguments spliced into it."""
function spliced_launches(root, id)
    text = read(joinpath(AGENTS.scratch_dir(root, id), "run.js"), String)
    m = match(r"globalThis\.args = (.*);\n", text)
    args = G.JSON3.read(m.captures[1], Dict{String,Any})
    return Dict(String(r["key"]) => r["launch"] for r in args["roles"])
end

"""
Collect the current stage through the one relaunch of silent readers: the first collect asks for them
again and moves nothing, the second moves on and names whoever is still silent.
"""
function collect_twice(root; io = devnull)
    id = G.Run.open_run(root); at = RUNS.stage_index(root, id)
    r = G.Run.collect(root; io)
    RUNS.stage_index(root, id) == at || return r
    G.Run.next(root; io)                               # what a session does: marks the silent to launch again
    return G.Run.collect(root; io)
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
            @test all(r -> haskey(whole(args, r), "result_file") && haskey(whole(args, r), "cap"), args["roles"])
            @test all(r -> !haskey(r, "result_file") && !haskey(r, "cap"), args["roles"])   # and the wire carries neither
            @test !haskey(args, "launches_left")                   # nothing caps launches (ruled 2026-09-21)
            @test all(r -> r["launch"] === true, args["roles"])       # a fresh stage launches everyone
            @test args["commit"] == RUNS.load(root, id).first_commit

            reader_found(root, id, HOME_READER, "a term is used before it is defined")
            @test G.Run.collect(root; io = devnull) == 2          # other readers wrote nothing: launched again
            @test RUNS.stage_of(root, id) === :find                # and nothing moved yet
            G.Run.next(root; io = devnull)
            @test G.Run.collect(root; io = devnull) == 2          # still silent: named, and the stage moves on
            run = RUNS.load(root, id)
            @test run.agent_launches == 2 * length(args["roles"]) - 1   # all once, the silent ones twice
            @test !isempty(run.silent)
            @test only(run.findings).source === Symbol(HOME_READER)          # the finding names its reader
            @test to_close(root, id) === :close
            @test G.Run.close_run(root; io = devnull) == 2        # closed, and not evaluable: readers were silent

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
            # the site reader is handed the kept pages by name, and no other file under the site
            @test Set(args["site_pages"]) == Set(joinpath(root, "docs", "build", p.path) for p in built)

            all_units = [whole(args, r) for r in args["roles"] if !isempty(String(r["unit"]))]
            units = [r for r in all_units if r["source_unit"] !== true]
            @test length(units) == length(built)                     # one launch per page
            @test Set(String(r["key"]) for r in units) == Set("withheld@" * p.key for p in built)
            # and one per Literate example's SOURCE, carrying only the rule judged there, which no
            # built page can show (found in review, 2026-09-23)
            sources = [r for r in all_units if r["source_unit"] === true]
            @test [String(r["unit_source"]) for r in sources] == G.Texts.files(cfg, root, G.Model.FileSet.LITERATE)
            @test all(r -> r["rules"] == ["RULE.DOC.LITERATE"], sources)
            @test all(r -> !("RULE.DOC.LITERATE" in r["rules"]), units)
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
            site_reader = whole(args, only(filter(r -> String(r["key"]) == "rendered", args["roles"])))
            @test isempty(String(site_reader["unit"])) && site_reader["site"] === true
            # and the reader with the source is neither
            full = whole(args, only(filter(r -> String(r["key"]) == "full", args["roles"])))
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
            v = whole(args, only(args["roles"]))
            @test v["kind"] == "verifier" && !isempty(String(v["unit"]))
            @test v["kept_from_code"] == false                      # it sees the diff too (ruled 2026-09-26)
            briefs = [String(b) for b in values(args["briefs"])]
            @test !any(b -> occursin("or the diff", b), briefs)        # its quote is of the current text alone
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
            collect_twice(root)
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
            # the dropped finding's TEXT stays on the record, marked dropped (ruled 2026-09-26), and is
            # carried into no later run
            @test record["stop"] == "OWNER_STOPPED" && length(record["findings"]) == 1
            @test record["dropped"] == 1 && record["dropped_ids"] == [fid]
            @test isempty(RUNS.open_findings(RUNS.load(root, id)))
            rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
            @test occursin("The owner stopped it.", rep) && occursin("- `" * fid * "` the grid is named", rep)
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
            # the FRESH find stage's driver carries its arguments too: `next` placed the driver a second
            # time without them, so every first launch read an undefined `args` (found verifying, 2026-09-27)
            @test occursin("globalThis.args = {", read(joinpath(AGENTS.scratch_dir(root, id), "run.js"), String))
            @test RUNS.load(root, id).driver == AGENTS.driver_sha(root, id)
            reader_found(root, id, HOME_READER, "one")
            reader_found(root, id, "full", "two"; quote_ = "an options record")   # a second defect, elsewhere
            before = length(G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})["roles"])
            @test G.Run.next(root; io = devnull) == 0                    # continue: the rest are missing
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            launch = Dict(String(r["key"]) => r["launch"] for r in args["roles"])
            @test launch[HOME_READER] === false && launch["full"] === false && launch["rendered"] === true
            @test length(args["roles"]) == before                        # the collect still expects everyone
            # and the DRIVER carries the same marks: it reads its spliced copy, not the file, and a copy
            # left from the launch marked every role again (found in review, 2026-09-26)
            @test spliced_launches(root, id) == launch
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
            @test RUNS.stage_of(root, id) === :find && isempty(RUNS.open_findings(RUNS.load(root, id)))
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
                G.Run.next(root; io = devnull)                              # fix
                fixed_as(root, fid, "The grid is a lattice, pass $p.")
                G.Run.next(root; io = devnull)                              # verify
                verifier_said(root, id, "verify", fid, "NOT_FIXED")
                G.Run.collect(root; io = devnull)
            end
            G.Run.next(root; io = devnull)
            @test G.Run.close_run(root; io = devnull) == 1
            # the session commits the closed run and the queue line it wrote, as it commits any run
            gg("add", "--all", "."); gg("commit", "-q", "-m", "the first run, closed")
            @test G.Run.start(root, :documentation_review; io = devnull) == 0
            id2 = G.Run.open_run(root)
            @test id2 != id
            all_clean(root, id2)
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
            # A third start, abandoned before it launched anything, has no standing over the finding it
            # was carrying: its record is deleted whole and the next start reads past it to the run that
            # found the finding, which carries it again (ruled 2026-09-23, decision 14, superseding the
            # ruling of 2026-09-22 that the record made the drop stick).
            gg("add", "--all", "."); gg("commit", "-q", "-m", "the second run, closed")
            G.Run.start(root, :documentation_review; io = devnull)
            gone = RUNS.dir(root, G.Run.open_run(root))
            @test G.Run.abandon(root; io = devnull) == 0
            @test !isdir(gone)                                             # nothing to commit
            G.Run.start(root, :documentation_review; io = devnull)
            @test [f.id for f in RUNS.load(root, G.Run.open_run(root)).findings] == [fid]
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
            collect_twice(root)                                           # the readers are in; the change comes after
            code_change(root)
            gg("add", "src/FixtureA.jl"); gg("commit", "-q", "-m", "a code change nobody guarded")
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
            all_clean(root, id)
            collect_twice(root)
            write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
            gg("add", "docs/src/index.md"); gg("commit", "-q", "-m", "prose only")
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
            id, fid = with_one_finding(root)
            G.Run.next(root; io = devnull)                                 # → fix
            write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
            # Not without a finding, while a run is open: the verifiers find a fix by that trailer, so
            # one committed without it is never verified and its finding stays open with nothing saying
            # why. Nothing is committed, so the edit is still there to commit properly.
            @test G.Docfix.commit(root, "a prose fix"; io = devnull) == 2
            @test !occursin(RUNS.GUARD_TRAILER, readchomp(setenv(`git -C $root log -1 --format=%B`; dir = root)))
            @test G.Docfix.commit(root, "a prose fix"; io = devnull, finding = fid) == 0
            log = readchomp(setenv(`git -C $root log -1 --format=%B`; dir = root))
            @test occursin(RUNS.GUARD_TRAILER, log)
            @test occursin(RUNS.FINDING_TRAILER * fid, log)
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
            mkpath(joinpath(root, ".claude"))
            write(joinpath(root, ".claude", "WORK_QUEUE.md"), "# Work queue\n\n- [ ] keep going\n")
            gg("add", ".claude"); gg("commit", "-q", "-m", "a queue to keep")
            id, fid = with_one_finding(root)
            G.Run.next(root; io = devnull)                                 # → fix
            write(joinpath(root, ".claude", "WORK_QUEUE.md"), "# Work queue\n\n- [x] keep going\n")
            write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
            @test G.Docfix.commit(root, "a prose fix"; io = devnull, finding = fid) == 0
            # committed the prose, left the queue for the close
            @test occursin("WORK_QUEUE", readchomp(setenv(`git -C $root status --porcelain`; dir = root)))
            @test !occursin("WORK_QUEUE", readchomp(setenv(`git -C $root show --name-only --format= HEAD`; dir = root)))
            @test isempty(RUNS.unguarded_code(root, RUNS.load(root, id).first_commit))
        end
    end

    # ── the pass: fix, then one verifier per place with the diff, graded by a program (design §4.3)

    # The whole happy path: a finding, a guarded fix carrying its trailer, one verifier given the
    # finding, the page as it now stands and the diff, and a run that closes clean with the pass on record.
    @testset "a fix a verifier stands behind closes its finding, and the run closes clean" begin
        package() do root, gg
            id, fid = with_one_finding(root)
            @test G.Run.next(root; io = devnull) == 0                  # → fix, pass 1
            @test RUNS.stage_of(root, id) === :fix
            run = RUNS.load(root, id)
            @test run.passes == 1 && !isempty(run.pass_since)          # the pass knows where it began
            todo = G.JSON3.read(read(joinpath(AGENTS.stage_dir(root, id), "findings.json"), String))
            @test length(todo) == 1 && todo[1]["id"] == fid
            @test todo[1]["locations"][1]["line"] == HOME_LINE       # re-anchored before the fixer sees it

            fixed_as(root, fid, "The grid is a lattice.")
            @test RUNS.fix_commits(root, run.first_commit, fid) |> length == 1

            @test G.Run.next(root; io = devnull) == 0                  # → verify: one verifier for the page
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            @test length(args["roles"]) == 1
            v = whole(args, args["roles"][1])
            @test v["kind"] == "verifier" && v["key"] == "verify-unit-home"
            # The findings are a FILE holding a list, and the diff is a file beside it: what the verifier
            # is shown is what it reads, not a paragraph in the arguments.
            @test v["finding"] == fid
            @test isfile(v["finding_file"])
            @test only(G.JSON3.read(read(v["finding_file"], String)))["id"] == fid
            @test occursin("lattice", read(v["diff_file"], String))
            @test v["kept_from_code"] == false
            @test "HIDES_CODE_DEFECT" in v["verdicts"] && "MADE_WORSE" in v["verdicts"]
            # The standpoint is in the shared table under the key the role names, not written out here.
            @test haskey(args["briefs"], v["brief"]) && !isempty(args["briefs"][v["brief"]])
            @test length(args["roles"][1]) == 6                      # a role carries only what is its own
            # the driver's copy carries the arguments spliced in, so the call passes none
            @test occursin("globalThis.args = {", read(joinpath(AGENTS.scratch_dir(root, id), "run.js"), String))
            verifier_said(root, id, "verify", fid, "FIXED"; quote_ = "The grid is a lattice.")
            @test G.Run.collect(root; io = devnull) == 0              # nothing open
            fix = only(RUNS.load(root, id).fixes)
            @test fix.blind === MRun.Verdict.FIXED && fix.with_diff === nothing && fix.pass == 1 && !isempty(fix.commit)
            @test isempty(fix.note)

            @test G.Run.next(root; io = devnull) == 0                  # → close
            @test G.Run.close_run(root; io = devnull) == 0
            rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
            @test occursin("pass 1: verifier `FIXED`", rep)
            @test occursin("1 of 1 fix pass", rep)
            @test !occursin(fid, read(joinpath(root, ".claude", "WORK_QUEUE.md"), String))  # nothing left over
            record = G.JSON3.read(read(joinpath(RUNS.dir(root, id), "run.json"), String), Dict{String,Any})
            @test record["passes"] == 1 && length(record["fixes"]) == 1
        end
    end

    # Several findings of one place go to ONE verifier, which answers each by id; a finding it leaves
    # out is NOT_FIXED with the reason on record.
    @testset "the findings of one place share a verifier, and one it skips is graded not fixed" begin
        package() do root, gg
            G.Run.start(root, :documentation_review; io = devnull)
            id = G.Run.open_run(root)
            reader_found(root, id, HOME_READER, "the grid is named but not said to be a lattice")
            reader_found(root, id, "full", "the record is not called a record"; quote_ = "an options record")
            all_clean(root, id; except = [HOME_READER, "full"])
            G.Run.collect(root; io = devnull)
            found = RUNS.load(root, id).findings
            home_id = only(f.id for f in found if f.source === Symbol(HOME_READER))
            full_id = only(f.id for f in found if f.source === :full)
            G.Run.next(root; io = devnull)                                # fix
            write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
            @test G.Docfix.commit(root, "fix for " * home_id; io = devnull, finding = home_id) == 0
            G.Run.next(root; io = devnull)                                # verify
            args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
            keys_ = sort([String(r["key"]) for r in args["roles"]])
            @test keys_ == ["verify-file-docs-src-index-md", "verify-unit-home"]   # the full reader's file, the page's unit
            verifier_said(root, id, "verify", home_id, "FIXED"; quote_ = "The grid is a lattice.")
            @test G.Run.collect(root; io = devnull) == 2                  # the other verifier wrote nothing
            write(joinpath(AGENTS.results_dir(root, id), "verify-file-docs-src-index-md.json"), """{"verdicts":[]}""")
            @test G.Run.collect(root; io = devnull) == 2                  # still nothing: silent, but the run goes on
            run = RUNS.load(root, id)
            @test RUNS.closed(run, home_id) && !RUNS.closed(run, full_id)
            k = findfirst(x -> x.finding == full_id, run.fixes)
            @test run.fixes[k].blind === MRun.Verdict.NOT_FIXED && occursin("no verifier answered", run.fixes[k].note)
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
            fix = only(RUNS.load(root, id).fixes)
            @test fix.blind === MRun.Verdict.NOT_FIXED
            @test occursin("quote is not in the text", fix.note)         # the demotion is on the record
            @test G.Run.next(root; io = devnull) == 0                    # one pass: → close
            @test RUNS.stage_of(root, id) === :close
            # a quote of two spans joined by "..." holds when each span does (found by PF, 2026-09-24)
            f = only(RUNS.load(root, id).findings)
            @test G.Run.quote_holds(root, f, "The grid is ... lattice.")
            @test !G.Run.quote_holds(root, f, "The grid is ... spectral.")
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
                fixed_as(root, fid, "The grid is a lattice, pass $p.")
                @test G.Run.next(root; io = devnull) == 0 && RUNS.stage_of(root, id) === :verify
                verifier_said(root, id, "verify", fid, "NOT_FIXED")
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
            @test count("verifier `NOT_FIXED`", rep) == cap
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
            verifier_said(root, id, "verify", fid, "MADE_WORSE"; quote_ = "The grid is a lattice.")
            @test G.Run.collect(root; io = devnull) == 1
            @test occursin("spectral", read(joinpath(root, "docs", "src", "index.md"), String))
            @test only(RUNS.load(root, id).fixes).blind === MRun.Verdict.MADE_WORSE
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
            G.Run.next(root; io = devnull)                               # fix
            fixed_as(root, fid, "The grid is spectral, that is, a lattice.")   # something committed, or nothing is verified
            G.Run.next(root; io = devnull)                               # verify
            verifier_said(root, id, "verify", fid, "NOT_A_DEFECT"; quote_ = "The grid is spectral")
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
            collect_twice(root)
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

    # A run that launched nothing but was CARRYING findings is deleted whole: it has no standing over
    # findings it never looked at, and the run that found them carries them again (ruled 2026-09-23,
    # decision 14; the ruling of 2026-09-22 that the record made the drop stick is superseded).
    @testset "a run carrying findings, having launched nothing, is deleted and the findings go back" begin
        root, id = opened(launches = 0)
        run = G.Orchestration.Runs.load(root, id)
        carried = G.Model.Finding("F1", :full, G.Model.Decider.AGENT,
                                  G.Model.FindingDraft(claim = "carried in from the last run"))
        G.Orchestration.Runs.save(root, G.Model.Run(id = run.id, instrument = run.instrument,
            tool_version = run.tool_version, first_commit = run.first_commit, budget = run.budget,
            stage = run.stage, findings = [carried], agent_launches = 0))
        out = IOBuffer()
        @test G.Run.abandon(root; io = out) == 0
        text = String(take!(out))
        @test occursin("carried again", text) && !occursin("Commit .gbg/runs/", text)
        @test !isdir(G.Orchestration.Runs.dir(root, id))
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
                      dropped = 142, unreverted = ["abc123"], silent = ["full"])
    back = RUNS.from_dict(G.JSON3.read(G.JSON3.write(RUNS.as_dict(run)), Dict{String,Any}))
    for f in fieldnames(G.Model.Run)
        # The four list-valued fields carry their own types and are round-tripped by the suites that
        # build them; every scalar is compared here, and a new scalar joins this loop by being declared.
        f in (:findings, :fixes, :questions, :code_fixes) && continue
        @test getfield(back, f) == getfield(run, f)
    end
    # A finding goes round too, its newest flag included: a flag that reached the writer and not the
    # reader would silently make every finding in the working notes a fixer's on the next load.
    loc = G.Model.Location(file = "docs/ROADMAP.md", node = "", text = "we decided", line = 3)
    draft = G.Model.FindingDraft(rule = nothing, locations = [loc], claim = "the notes contradict the page",
                                 evidence = "e", fix = "f", maybe_code = true, in_material = true)
    withf = G.Model.Run(id = "roundtrip-02", instrument = :documentation_review, tool_version = "v9",
                        first_commit = "abc", budget = G.Model.Budget(), stage = :collect,
                        findings = [G.Model.Finding("roundtrip-02-f1", :full, G.Model.Decider.AGENT, draft)])
    back2 = RUNS.from_dict(G.JSON3.read(G.JSON3.write(RUNS.as_dict(withf)), Dict{String,Any}))
    f2 = only(back2.findings)
    @test f2.draft.in_material && f2.draft.maybe_code && f2.draft.claim == draft.claim
    @test only(f2.draft.locations).text == "we decided"

    # And the default is never mistaken for a value that was written: a record with no `dropped` key —
    # every record written before this field existed — reads as zero, not as missing.
    old = RUNS.as_dict(run); delete!(old, "dropped")
    @test RUNS.from_dict(G.JSON3.read(G.JSON3.write(old), Dict{String,Any})).dropped == 0
end


# ── targets and material (ruled 2026-09-23) ─────────────────────────────────────────────────────────
#
# The review is for the text a user reads. A reader is GIVEN targets — docstrings, hand-written pages,
# Literate examples, the one architecture document — and, if the package lists any, material it may open
# and never report on. The other rationale documents are read by nobody. On GBGPeriodicFields the withheld
# reader had been launched over a 72,000-token decision log as "one page", under two rules that had that
# day been ruled not to apply to it; 72% of what it read was the package's working notes.

"""The fixture's config with the roadmap declared a rationale document, and optionally listed as material."""
function notes_config(; material = String[])
    return """
    Config(
        package = "GBGFixture",
        tool = :dev,
        docs_build = ["julia", "--project=docs", "docs/make.jl"],
        test = ["julia", "--project", "-e", "using Pkg; Pkg.test()"],
        filesets = Dict(
            FileSet.CODE => ["src/FixtureA.jl", "src/FixtureB.jl", "src/FixtureC.jl", "src/GBGFixture.jl"],
            FileSet.PAGES => ["docs/src/index.md", "docs/src/notation.md", "docs/src/api/FixtureA.md", "docs/src/api/FixtureB.md", "docs/src/api/FixtureC.md"],
            FileSet.RATIONALE => ["docs/ARCHITECTURE.md", "docs/ROADMAP.md"],
            FileSet.LITERATE => ["examples/scaling.jl"],
        ),
        material = $(repr(material)),
    )
    """
end

@testset "what is a target, and what is read by nobody" begin
    package() do root, gg
        write(joinpath(root, ".gbg", "config.jl"), notes_config())
        cfg = G.ConfigIO.read_config(root)
        @test G.Catalogue.architecture_doc(cfg) == "docs/ARCHITECTURE.md"
        @test G.Catalogue.target(cfg, "docs/ARCHITECTURE.md")          # the one rationale document that is
        @test !G.Catalogue.target(cfg, "docs/ROADMAP.md")              # working notes
        @test G.Catalogue.target(cfg, "docs/src/index.md")
        @test G.Catalogue.target(cfg, "src/FixtureA.jl")
        @test G.Catalogue.target(cfg, "examples/scaling.jl")
        @test !G.Catalogue.target(cfg, "test/runtests.jl")
        @test !G.Catalogue.target(cfg, "")

        # the surfaces an agent is handed: of the rationale set, the architecture document alone
        sur = Dict(AGENTS.surfaces(cfg, root))
        @test sur["rationale"] == ["docs/ARCHITECTURE.md"]
        @test AGENTS.material(cfg, root) == String[]                   # nothing listed, nothing given

        # listed as material, it is given as material — and still not a target
        write(joinpath(root, ".gbg", "config.jl"), notes_config(material = ["docs/ROADMAP.md", "docs/MISSING.md"]))
        cfg = G.ConfigIO.read_config(root)
        @test AGENTS.material(cfg, root) == ["docs/ROADMAP.md"]         # a listed path that is no file is not handed out
        @test Dict(AGENTS.surfaces(cfg, root))["rationale"] == ["docs/ARCHITECTURE.md"]
        @test !G.Catalogue.target(cfg, "docs/ROADMAP.md")

        # the path a reader names, in every spelling a reader has used (found in review, 2026-09-23)
        np(x) = G.Catalogue.normal_path(cfg, root, x)
        @test np(joinpath(root, "docs", "src", "index.md")) == "docs/src/index.md"
        @test np("./docs/src/index.md") == "docs/src/index.md"
        @test np(".//docs/src/index.md") == "docs/src/index.md"
        @test np("docs\\src\\index.md") == "docs/src/index.md"
        @test np(root * "-other/docs/x.md") == ""                     # a sibling whose name begins with the root's
        @test np("/etc/passwd") == ""                                  # outside the package: names nothing here
        @test np(root) == ""
        @test np("") == ""
        @test np(".") == ""
        @test np("docs/../src/FixtureA.jl") == "src/FixtureA.jl"       # `..` resolved, a target again
        @test np("../escape.md") == ""                                  # climbing out names nothing here
        @test np("docs/../../escape.md") == ""
        @test np(joinpath(root, "..", "escape.md")) == ""
        @test G.Catalogue.target(cfg, "docs/../src/FixtureA.jl")

        # a setting is normalised the way a reader's path is, and an empty one is no setting
        dotted = G.Model.Config(package = "GBGFixture", tool = :dev,
                                settings = [G.Model.Setting(rule = Symbol("RULE.DOC.SELF_CONTAINED"), name = :architecture_doc, value = "./docs/ARCHITECTURE.md")])
        @test G.Catalogue.architecture_doc(dotted) == "docs/ARCHITECTURE.md" && G.Catalogue.target(dotted, "docs/ARCHITECTURE.md")
        @test isempty(G.Catalogue.missing_documents(dotted, root))
        backslashed = G.Model.Config(package = "GBGFixture", tool = :dev,
                                     settings = [G.Model.Setting(rule = Symbol("RULE.DOC.SELF_CONTAINED"), name = :architecture_doc, value = "docs\\ARCHITECTURE.md")])
        @test isempty(G.Catalogue.missing_documents(backslashed, root))
        blank = G.Model.Config(package = "GBGFixture", tool = :dev,
                               settings = [G.Model.Setting(rule = Symbol("RULE.DOC.SELF_CONTAINED"), name = :architecture_doc, value = ""),
                                           G.Model.Setting(rule = Symbol("RULE.DOC.TERMS_DEFINED"), name = :architecture_doc, value = "docs/ARCHITECTURE.md")])
        @test G.Catalogue.architecture_doc(blank) == "docs/ARCHITECTURE.md"
        @test !any(m -> occursin("different documents", m), G.Catalogue.missing_documents(blank, root))

        # a glob pattern is literal but for its two wildcards
        @test G.Texts.glob_matches("docs/a+b.md", "docs/a+b.md") && !G.Texts.glob_matches("docs/a+b.md", "docs/ab.md")
        @test G.Texts.glob_matches("docs/(x).md", "docs/(x).md") && !G.Texts.glob_matches("docs/(x).md", "docs/x.md")

        # material by pattern, as the fixer and the scope see it; a generated page is nobody's to fix
        glob = G.Model.Config(package = "GBGFixture", tool = :dev,
                              filesets = Dict(G.Model.FileSet.RATIONALE => ["docs/*.md"]),
                              generated = ["docs/src/gbg-rules.md"])
        @test G.Catalogue.material_doc(glob, "docs/ROADMAP.md")
        @test !G.Catalogue.material_doc(glob, "docs/ARCHITECTURE.md")   # the one target among them
        @test G.Catalogue.material_doc(glob, "docs/src/gbg-rules.md")
        @test !G.Catalogue.material_doc(glob, "README.md") && !G.Catalogue.material_doc(glob, "")

        # two rules set to different documents: the first wins, and the disagreement is reported
        split_ = G.Model.Config(package = "GBGFixture", tool = :dev,
                                settings = [G.Model.Setting(rule = Symbol("RULE.DOC.TERMS_DEFINED"), name = :architecture_doc, value = "docs/ARCHITECTURE.md"),
                                            G.Model.Setting(rule = Symbol("RULE.DOC.SELF_CONTAINED"), name = :architecture_doc, value = "docs/ROADMAP.md")])
        @test G.Catalogue.architecture_doc(split_) in ("docs/ARCHITECTURE.md", "docs/ROADMAP.md")
        @test any(m -> occursin("set to different documents", m), G.Catalogue.missing_documents(split_, root))
        @test !any(m -> occursin("set to different documents", m), G.Catalogue.missing_documents(cfg, root))
    end
end

@testset "an abandoned run that kept a fixed finding still says what it threw away" begin
    package() do root, gg
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        reader_found(root, id, HOME_READER, "the grid is named but not said to be a lattice")
        reader_found(root, id, "full", "the notation page is silent on the grid"; file = "docs/src/notation.md", quote_ = "")
        all_clean(root, id; except = [HOME_READER, "full"])
        G.Run.collect(root; io = devnull)
        run = RUNS.load(root, id)
        fid = only(f.id for f in run.findings if f.source === Symbol(HOME_READER))
        G.Run.next(root; io = devnull)                                # → fix
        fixed_as(root, fid, "The grid is a lattice.")
        G.Run.next(root; io = devnull)                                # → verify (one verifier per place)
        for f in RUNS.workable(RUNS.load(root, id))
            verifier_said(root, id, "verify", f.id, f.id == fid ? "FIXED" : "NOT_FIXED"; quote_ = f.id == fid ? "The grid is a lattice." : "")
        end
        G.Run.collect(root; io = devnull)
        @test G.Run.abandon(root; io = devnull) == 0
        record = G.JSON3.read(read(joinpath(RUNS.dir(root, id), "run.json"), String), Dict{String,Any})
        @test record["dropped"] == 1 && length(record["findings"]) == 2 && length(record["dropped_ids"]) == 1
        rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
        @test occursin("## 1 finding(s) were thrown away", rep)       # said even though one was kept
        @test occursin("## Findings — 1", rep)
        @test !occursin("says NOTHING", rep)                          # something WAS stood behind
    end
end

@testset "a pre-ruling record naming a copy is carried as working notes, and the fix stage leaves it alone" begin
    package() do root, gg
        write(joinpath(root, ".gbg", "config.jl"), replace(notes_config(),
              "material = String[]," => "material = String[], copies = [\"docs/src/roadmap.md\" => \"docs/ROADMAP.md\"],"))
        write(joinpath(root, "docs", "ROADMAP.md"), "# Roadmap\n\nThe grid is spectral.\n")
        write(joinpath(root, "docs", "src", "roadmap.md"), "# Roadmap\n\nThe grid is spectral.\n")
        old_id = "documentation-review-2026-09-20-02"
        loc = G.Model.Location(file = "docs/src/roadmap.md", text = "The grid is spectral.", line = 3)   # the COPY, as pre-rc.13 collects wrote
        prev = G.Model.Run(id = old_id, instrument = :documentation_review, tool_version = "v2.0.0-rc.10",
                           first_commit = "abc", budget = G.Model.Budget(), stage = :close,
                           findings = [G.Model.Finding(old_id * "-001", :full, G.Model.Decider.AGENT,
                                       G.Model.FindingDraft(claim = "in the notes", locations = [loc]))])
        mkpath(RUNS.dir(root, old_id))
        write(joinpath(RUNS.dir(root, old_id), "run.json"), G.JSON3.write(RUNS.as_dict(prev)))
        gg("add", "--all", "."); gg("commit", "-q", "-m", "an old record naming a copy")
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        carried = only(RUNS.load(root, id).findings)
        @test carried.draft.in_material
        @test only(carried.draft.locations).file == "docs/ROADMAP.md"    # the source, not the copy
        # a target finding beside it, so the fix stage runs; the notes finding must not grow a target location
        reader_found(root, id, HOME_READER, "the grid is named but not said to be a lattice")
        all_clean(root, id; except = [HOME_READER])
        G.Run.collect(root; io = devnull)
        G.Run.next(root; io = devnull)                                # → fix: re-anchors everything
        after = only(f for f in RUNS.load(root, id).findings if f.id == carried.id)
        @test after.draft.in_material && all(l -> l.file == "docs/ROADMAP.md", after.draft.locations)
    end
end


@testset "the site walk keeps only target pages" begin
    package() do root, gg
        cfg = G.Model.Config(package = "GBGFixture", tool = :dev,
                             filesets = Dict(G.Model.FileSet.PAGES => ["docs/src/index.md"],
                                             G.Model.FileSet.RATIONALE => ["docs/ARCHITECTURE.md", "docs/ROADMAP.md"]),
                             copies = ["docs/src/architecture.md" => "docs/ARCHITECTURE.md",
                                       "docs/src/roadmap.md" => "docs/ROADMAP.md"])
        dir = write_site(root, cfg)
        # the build's copies of both rationale documents — the copied file under docs/src, which a clean
        # checkout does not have, and the page built from it
        for stem in ("architecture", "roadmap")
            write(joinpath(root, "docs", "src", stem * ".md"), "# $stem, copied\n")
            mkpath(joinpath(dir, stem))
            write(joinpath(dir, stem, "index.html"),
                  "<html><body><article class=\"content\"><p>The $stem, copied.</p></article></body></html>")
        end
        keys_ = Set(p.key for p in SITE.pages(dir, cfg, root))
        @test "home" in keys_
        @test "architecture" in keys_                                  # its source is the one target
        @test !("roadmap" in keys_)                                    # its source is working notes
    end
end

@testset "a finding in the working notes goes to the owner, not the fixer" begin
    package() do root, gg
        write(joinpath(root, ".gbg", "config.jl"), notes_config(material = ["docs/ROADMAP.md"]))
        write(joinpath(root, "docs", "ROADMAP.md"), "# Roadmap\n\nWe decided the grid is a lattice.\n")
        gg("add", "--all", "."); gg("commit", "-q", "-m", "notes as material")
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
        @test args["material"] == ["docs/ROADMAP.md"]
        @test !any(r -> occursin("roadmap", String(r["key"])), args["roles"])   # no launch over it

        # the full reader, given the notes as material, finds something only there
        reader_found(root, id, "full", "the notes say lattice and the page says spectral";
                     file = "docs/ROADMAP.md", quote_ = "We decided the grid is a lattice.")
        all_clean(root, id; except = ["full"])
        @test G.Run.collect(root; io = devnull) == 1                   # it is a finding
        run = RUNS.load(root, id)
        f = only(run.findings)
        @test f.draft.in_material
        @test isempty(RUNS.workable(run))                              # and nobody's to fix
        @test isempty(RUNS.open_findings(run))                         # nor a leftover, nor carried
        @test only(RUNS.in_material(run)).id == f.id

        # a finding in the working notes is not one any pass works on, so no fix may be committed for it,
        # in the notes or anywhere else
        write(joinpath(root, "docs", "ROADMAP.md"), "# Roadmap\n\nWe decided the grid is spectral.\n")
        @test G.Docfix.commit(root, "tidy the notes"; io = devnull, finding = f.id) == 2
        gg("checkout", "--", "docs/ROADMAP.md")

        @test to_close(root, id) === :close
        @test G.Run.close_run(root; io = devnull) == 0                 # nothing open in the targets
        rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
        @test occursin("## In the working notes — 1", rep)
        @test occursin("the notes say lattice", rep)
        @test occursin("## Findings — 0", rep)
        @test !occursin("Nothing was found", rep)                      # something WAS found
        queue = read(joinpath(root, ".claude", "WORK_QUEUE.md"), String)
        @test occursin("IN THE WORKING NOTES, for the owner", queue)
        @test occursin(f.id, queue)
    end
end


# ── what the review of 2026-09-23 found in the day's own work, each reproduced, each held here ─────

@testset "a finding in the working notes survives the fix stage, and the fixer is never sent there" begin
    package() do root, gg
        write(joinpath(root, ".gbg", "config.jl"), notes_config(material = ["docs/ROADMAP.md"]))
        # the notes quote the home page's sentence, so the copy-finder WOULD extend a finding into them
        write(joinpath(root, "docs", "ROADMAP.md"), "# Roadmap\n\nThe grid is spectral.\n\nWe decided the grid is a lattice.\n")
        gg("add", "--all", "."); gg("commit", "-q", "-m", "notes")
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        reader_found(root, id, HOME_READER, "the grid is named but not said to be a lattice")
        reader_found(root, id, "full", "the notes say lattice and the page says spectral";
                     file = "docs/ROADMAP.md", quote_ = "We decided the grid is a lattice.")
        all_clean(root, id; except = [HOME_READER, "full"])
        @test G.Run.collect(root; io = devnull) == 1
        run = RUNS.load(root, id)
        target_id = only(f.id for f in run.findings if !f.draft.in_material)
        notes_id = only(f.id for f in run.findings if f.draft.in_material)

        @test G.Run.next(root; io = devnull) == 0                     # → fix
        todo = G.JSON3.read(read(joinpath(AGENTS.stage_dir(root, id), "findings.json"), String))
        @test [String(t["id"]) for t in todo] == [target_id]          # the notes finding is not handed out
        @test all(!occursin("ROADMAP", String(l["file"])) for l in only(todo)["locations"])   # nor is its copy
        run = RUNS.load(root, id)
        @test only(f for f in run.findings if f.id == notes_id).draft.in_material   # the flag survived re-anchoring
        @test [f.id for f in RUNS.workable(run)] == [target_id]

        fixed_as(root, target_id, "The grid is a lattice.")
        @test G.Run.next(root; io = devnull) == 0                     # → verify: one verifier, for the target
        args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
        @test [String(r["key"]) for r in args["roles"]] == ["verify-unit-home"]
        verifier_said(root, id, "verify", target_id, "FIXED"; quote_ = "The grid is a lattice.")
        G.Run.collect(root; io = devnull)
        @test to_close(root, id) === :close
        @test G.Run.close_run(root; io = devnull) == 0
        rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
        @test occursin("## In the working notes — 1", rep) && occursin("## Findings — 1", rep)
        queue = read(joinpath(root, ".claude", "WORK_QUEUE.md"), String)
        @test occursin(notes_id * " IN THE WORKING NOTES", queue) && !occursin(target_id, queue)
    end
end

@testset "a record written before the ruling is re-classified when carried" begin
    package() do root, gg
        write(joinpath(root, ".gbg", "config.jl"), notes_config())
        write(joinpath(root, "docs", "ROADMAP.md"), "# Roadmap\n\nWe decided the grid is a lattice.\n")
        old_id = "documentation-review-2026-09-20-01"
        loc = G.Model.Location(file = "docs/ROADMAP.md", text = "We decided the grid is a lattice.", line = 3)
        prev = G.Model.Run(id = old_id, instrument = :documentation_review, tool_version = "v2.0.0-rc.10",
                           first_commit = "abc", budget = G.Model.Budget(), stage = :close,
                           findings = [G.Model.Finding(old_id * "-001", :full, G.Model.Decider.AGENT,
                                       G.Model.FindingDraft(claim = "the notes say lattice", locations = [loc]))])
        mkpath(RUNS.dir(root, old_id))
        write(joinpath(RUNS.dir(root, old_id), "run.json"), G.JSON3.write(RUNS.as_dict(prev)))
        gg("add", "--all", "."); gg("commit", "-q", "-m", "an old record")
        G.Run.start(root, :documentation_review; io = devnull)
        run = RUNS.load(root, G.Run.open_run(root))
        carried = only(run.findings)
        @test carried.id == old_id * "-001"
        @test carried.draft.in_material                              # decided again, against today's config
        @test isempty(RUNS.workable(run))
    end
end

@testset "abandon keeps what was fixed and verified, and counts only what it throws away" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)                                # → fix
        fixed_as(root, fid, "The grid is a lattice.")
        G.Run.next(root; io = devnull)                                # → verify
        verifier_said(root, id, "verify", fid, "FIXED"; quote_ = "The grid is a lattice.")
        @test G.Run.collect(root; io = devnull) == 0
        @test G.Run.abandon(root; io = devnull) == 0
        record = G.JSON3.read(read(joinpath(RUNS.dir(root, id), "run.json"), String), Dict{String,Any})
        @test record["dropped"] == 0
        @test length(record["findings"]) == 1 && length(record["fixes"]) == 1
        rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
        @test occursin("## Findings — 1", rep) && !occursin("thrown away", rep) && !occursin("Nothing was found", rep)
    end
end

@testset "in material means in material: a path's spelling, a test file or the README do not route to the owner" begin
    package() do root, gg
        write(joinpath(root, ".gbg", "config.jl"), notes_config(material = ["docs/ROADMAP.md"]))
        write(joinpath(root, "docs", "ROADMAP.md"), "# Roadmap\n\nWe decided the grid is a lattice.\n")
        write(joinpath(root, "README.md"), "# Fixture\n\nA readme sentence.\n")
        gg("add", "--all", "."); gg("commit", "-q", "-m", "notes and a readme")
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        mkpath(AGENTS.results_dir(root, id))
        cases = [("absolute", joinpath(root, "docs", "src", "index.md"), "The grid is spectral."),
                 ("dotted", "./docs/src/index.md", "The grid is spectral."),
                 ("readme", "README.md", "A readme sentence."),
                 ("test", "test/runtests.jl", "using Test"),
                 ("notes", "docs/ROADMAP.md", "We decided the grid is a lattice.")]
        payload = Dict("findings" => [Dict("claim" => name, "fix" => "x",
                                           "locations" => [Dict("file" => file, "text" => text)]) for (name, file, text) in cases],
                       "checked" => ["docs/src/index.md"])
        write(joinpath(AGENTS.results_dir(root, id), "full.json"), G.JSON3.write(payload))
        all_clean(root, id; except = ["full"])
        G.Run.collect(root; io = devnull)
        by = Dict(f.draft.claim => f for f in RUNS.load(root, id).findings)
        @test !by["absolute"].draft.in_material && only(by["absolute"].draft.locations).file == "docs/src/index.md"
        @test !by["dotted"].draft.in_material && only(by["dotted"].draft.locations).file == "docs/src/index.md"
        @test !by["readme"].draft.in_material
        @test !by["test"].draft.in_material
        @test by["notes"].draft.in_material
    end
end

@testset "docfix check sees the tree commit sees" begin
    package() do root, gg
        write(joinpath(root, ".gbg", "config.jl"), notes_config())
        write(joinpath(root, "docs", "ROADMAP.md"), "# Roadmap\n\nNotes.\n")
        mkpath(joinpath(root, ".claude")); write(joinpath(root, ".claude", "WORK_QUEUE.md"), "# Work queue\n")
        gg("add", "--all", "."); gg("commit", "-q", "-m", "notes")
        G.Run.start(root, :documentation_review; io = devnull)
        write(joinpath(root, ".claude", "WORK_QUEUE.md"), "# Work queue\n\n- [ ] keep going\n")
        write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
        io = IOBuffer()
        @test G.Docfix.check(root; build = false, io) == 0            # the record and the queue are looked past
        out = String(take!(io))
        @test !occursin("WORK_QUEUE", out) && !occursin(".gbg/runs", out)
        write(joinpath(root, "docs", "ROADMAP.md"), "# Roadmap\n\nTidier notes.\n")
        io = IOBuffer()
        @test G.Docfix.check(root; build = false, io) == 1            # the notes are not the fixer's while a run is open
        @test occursin("NOTE", String(take!(io)))
    end
end

@testset "a stage launched under the old wire shape is refused, not misread" begin
    package() do root, gg
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        path = AGENTS.arguments_path(root, id)
        write(path, G.JSON3.write(Dict("run" => id, "commit" => AGENTS.head(root), "roles" =>
              [Dict("key" => "verify-x", "kind" => "verifier", "launch" => true, "result_file" => "r.json")])))
        io = IOBuffer()
        @test G.Run.next(root; io) == 2
        @test occursin("older GBGCodingTools", String(take!(io)))
        io = IOBuffer()
        @test G.Run.collect(root; io) == 2
        @test occursin("older GBGCodingTools", String(take!(io)))
        @test RUNS.stage_of(root, id) === :find                      # nothing advanced, nothing read
    end
end

@testset "the architecture document is a target on either rule's setting, and is handed out by default" begin
    package() do root, gg
        for rule in ("RULE.DOC.SELF_CONTAINED", "RULE.DOC.TERMS_DEFINED")
            cfg = G.Model.Config(package = "GBGFixture", tool = :dev,
                                 settings = [G.Model.Setting(rule = Symbol(rule), name = :architecture_doc, value = "docs/DESIGN.md")])
            @test G.Catalogue.architecture_doc(cfg) == "docs/DESIGN.md"
            @test G.Catalogue.target(cfg, "docs/DESIGN.md")
        end
        # no rationale set declared: the architecture document is handed to the readers even so
        cfg = G.Model.Config(package = "GBGFixture", tool = :dev)
        @test Dict(AGENTS.surfaces(cfg, root))["rationale"] == ["docs/ARCHITECTURE.md"]
    end
end

# ── the commit path under the guard, found in review 2026-09-23 ──────────────────────────────────────

@testset "the close classifies every commit, and the guard's mark proves nothing" begin
    package() do root, gg
        base = RUNS.head_commit(root)
        a = joinpath(root, "src", "FixtureA.jl")
        # a code change amended into a guarded documentation commit
        write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
        @test G.Docfix.commit(root, "a prose fix"; io = devnull) == 0
        write(a, read(a, String) * "\nevil() = 1\n")
        gg("add", "--all", "."); gg("commit", "-q", "--amend", "--no-edit")
        @test !isempty(RUNS.unguarded_code(root, base))
        # a plain commit that types the trailer itself
        gg("reset", "-q", "--hard", base)
        write(a, read(a, String) * "\nevil() = 2\n")
        gg("add", "--all", "."); gg("commit", "-q", "-m", "refactor\n\n" * RUNS.GUARD_TRAILER)
        @test !isempty(RUNS.unguarded_code(root, base))
        # and a genuinely guarded prose commit is still clean
        gg("reset", "-q", "--hard", base)
        write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
        @test G.Docfix.commit(root, "a prose fix"; io = devnull) == 0
        @test isempty(RUNS.unguarded_code(root, base))
    end
end

@testset "a file with a non-ASCII or spaced name is seen, and fixed" begin
    package() do root, gg
        k = joinpath(root, "src", "Kernels ä.jl")
        write(k, "k() = 1\n"); gg("add", "--all", "."); gg("commit", "-q", "-m", "a kernel")
        base = RUNS.head_commit(root)
        write(k, "k() = 2\n"); gg("add", "--all", "."); gg("commit", "-q", "-m", "change it")
        @test any(l -> occursin("Kernels ä.jl", l), RUNS.unguarded_code(root, base))
        # a documentation page with a space and one with a non-ASCII letter can be fixed
        for name in ("two words.md", "Schrödinger.md")
            p = joinpath(root, "docs", "src", name)
            write(p, "# P\n\nOne sentence.\n"); gg("add", "--all", "."); gg("commit", "-q", "-m", "a page")
            write(p, "# P\n\nAnother sentence.\n")
            @test G.Docfix.commit(root, "fix " * name; io = devnull) == 0
        end
    end
end

@testset "a revert that conflicts is aborted, and a revert is recognised only as the exact inverse" begin
    package() do root, gg
        base = RUNS.head_commit(root)
        idx = joinpath(root, "docs", "src", "index.md")
        write(idx, replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
        @test G.Docfix.commit(root, "fix one"; io = devnull) == 0
        first_fix = RUNS.head_commit(root)
        write(idx, replace(HOME_PAGE, "The grid is spectral." => "The grid is a periodic lattice."))
        @test G.Docfix.commit(root, "fix two"; io = devnull) == 0
        @test RUNS.revert!(root, first_fix) == false                      # conflicts with fix two
        status = readchomp(setenv(`git -C $root status --porcelain`; dir = root))
        @test isempty(status)                                             # aborted: no markers, no REVERT_HEAD
        @test !occursin("<<<<<<<", read(idx, String))
        # a clean revert carries a real trailer in its body, and the close reads it as what it is
        @test RUNS.revert!(root, RUNS.head_commit(root))
        body = readchomp(setenv(`git -C $root log -1 --format=%b`; dir = root))
        @test occursin(RUNS.GUARD_TRAILER, body) && occursin(RUNS.REVERT_TRAILER, body)
        @test !occursin("\\n", readchomp(setenv(`git -C $root log -1 --format=%s`; dir = root)))
        @test isempty(RUNS.unguarded_code(root, base))
        # and a revert of a fix that REMOVED a formula, which puts mathematics back, is still the run's own
        gg("reset", "-q", "--hard", base)
        write(idx, HOME_PAGE * "\nEnergy ``E = mc^2`` holds.\n"); gg("add", "--all", "."); gg("commit", "-q", "-m", "a formula")
        b2 = RUNS.head_commit(root)
        gg("commit", "-q", "--allow-empty", "-m", "marker")
        write(idx, HOME_PAGE * "\nEnergy holds.\n"); gg("add", "--all", "."); gg("commit", "-q", "-m", "drop it\n\n" * RUNS.GUARD_TRAILER)
        dropped = RUNS.head_commit(root)
        @test RUNS.revert!(root, dropped)
        @test length(RUNS.unguarded_code(root, b2)) == 1                  # the drop itself; its revert is exact
    end
end

@testset "a finding's commits are found by the whole trailer line, less those reverted" begin
    package() do root, gg
        base = RUNS.head_commit(root)
        idx = joinpath(root, "docs", "src", "index.md")
        for (id, text) in (("R-100", "a lattice"), ("R-1000", "a periodic lattice"))
            write(idx, replace(HOME_PAGE, "The grid is spectral." => "The grid is $text."))
            gg("add", "--all", "."); gg("commit", "-q", "-m", "fix $id\n\n" * RUNS.GUARD_TRAILER * "\n" * RUNS.FINDING_TRAILER * id)
        end
        @test length(RUNS.fix_commits(root, base, "R-100")) == 1
        @test length(RUNS.fix_commits(root, base, "R-1000")) == 1
        @test RUNS.revert!(root, only(RUNS.fix_commits(root, base, "R-1000")))
        @test isempty(RUNS.fix_commits(root, base, "R-1000"))               # reverted: no longer its fix
        @test length(RUNS.guarded_commits(root, base)) == 1                 # the revert is not an edit to undo
    end
end

@testset "a revert is skipped only when it is exactly this run's revert of this run's fix" begin
    package() do root, gg
        a = joinpath(root, "src", "FixtureA.jl")
        # an old code commit, from before the run, undone by a commit that names it
        write(a, read(a, String) * "\nevil() = 1\n"); gg("add", "--all", "."); gg("commit", "-q", "-m", "old code")
        old = readchomp(setenv(`git -C $root rev-parse HEAD`; dir = root))
        base = RUNS.head_commit(root)
        write(a, replace(read(a, String), "\nevil() = 1\n" => "")); gg("add", "--all", ".")
        gg("commit", "-q", "-m", "undo old\n\n" * RUNS.GUARD_TRAILER * "\n" * RUNS.REVERT_TRAILER * old)
        @test !isempty(RUNS.unguarded_code(root, base))
        # a fake revert that differs only in whitespace — `[1 - 1]` against `[1 -1]` is two elements
        gg("reset", "-q", "--hard", base)
        write(a, read(a, String) * "\nconst OFF = [1 - 1]  # the offset\n"); gg("add", "--all", "."); gg("commit", "-q", "-m", "setup")
        b2 = RUNS.head_commit(root)
        write(a, replace(read(a, String), "# the offset" => "# the shift"))
        @test G.Docfix.commit(root, "comment"; io = devnull) == 0
        fix = readchomp(setenv(`git -C $root rev-parse HEAD`; dir = root))
        write(a, replace(read(a, String), "[1 - 1]  # the shift" => "[1 -1]  # the offset")); gg("add", "--all", ".")
        gg("commit", "-q", "-m", "fake\n\n" * RUNS.GUARD_TRAILER * "\n" * RUNS.REVERT_TRAILER * fix)
        @test !isempty(RUNS.unguarded_code(root, b2))
        # a typed revert trailer in a fix message is refused, and hides no other fix
        idx = joinpath(root, "docs", "src", "index.md")
        write(idx, replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
        @test G.Docfix.commit(root, "fix\n\n" * RUNS.REVERT_TRAILER * "a"; io = devnull) == 2
    end
end

@testset "a symlink or a mode change is never prose" begin
    package() do root, gg
        base = RUNS.head_commit(root)
        idx = joinpath(root, "docs", "src", "index.md")
        write(joinpath(root, "docs", "src", "other.md"), "# Other\n\n```@example\nrun(`true`)\n```\n")
        gg("add", "--all", "."); gg("commit", "-q", "-m", "a page"); b2 = RUNS.head_commit(root)
        rm(idx); symlink("other.md", idx); gg("add", "--all", "."); gg("commit", "-q", "-m", "link\n\n" * RUNS.GUARD_TRAILER)
        @test !isempty(RUNS.unguarded_code(root, b2))
        gg("reset", "-q", "--hard", b2)
        chmod(idx, 0o755); gg("add", "--all", "."); gg("commit", "-q", "-m", "mode")
        @test !isempty(RUNS.unguarded_code(root, b2))
    end
end

@testset "nobody's staged work is swept into a fix or a revert, or lost" begin
    package() do root, gg
        b = joinpath(root, "src", "FixtureB.jl")
        idx = joinpath(root, "docs", "src", "index.md")
        write(idx, replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
        @test G.Docfix.commit(root, "fix"; io = devnull) == 0
        fix = readchomp(setenv(`git -C $root rev-parse HEAD`; dir = root))
        write(b, read(b, String) * "\nstaged() = 9\n"); gg("add", "src/FixtureB.jl")
        @test RUNS.revert!(root, fix) == false                          # refused: something is staged
        @test occursin("staged() = 9", read(b, String))
        @test occursin("M  src/FixtureB.jl", readchomp(setenv(`git -C $root status --porcelain`; dir = root)))
        write(idx, replace(HOME_PAGE, "The grid is spectral." => "The grid is periodic."))
        @test G.Docfix.commit(root, "another"; io = devnull) == 2          # refused too, work kept staged
        @test occursin("M  src/FixtureB.jl", readchomp(setenv(`git -C $root status --porcelain`; dir = root)))
    end
end

@testset "the tool's own revert is recognised when a later fix touched the same page" begin
    package() do root, gg
        base = RUNS.head_commit(root)
        idx = joinpath(root, "docs", "src", "index.md")
        write(idx, HOME_PAGE * "\nA second sentence.\n"); gg("add", "--all", "."); gg("commit", "-q", "-m", "two sentences")
        b2 = RUNS.head_commit(root)
        write(idx, replace(read(idx, String), "The grid is spectral." => "The grid is a lattice."))
        @test G.Docfix.commit(root, "fix A"; io = devnull, finding = "R-001") == 0
        write(idx, replace(read(idx, String), "A second sentence." => "A second sentence, reworded."))
        @test G.Docfix.commit(root, "fix B"; io = devnull, finding = "R-002") == 0
        @test RUNS.revert!(root, only(RUNS.fix_commits(root, b2, "R-001")))
        @test isempty(RUNS.fix_commits(root, b2, "R-001"))              # recognised: no longer A's fix
        @test length(RUNS.fix_commits(root, b2, "R-002")) == 1
        @test isempty(RUNS.unguarded_code(root, b2))
        # but one that also changes a mode is not a revert
        fixb = only(RUNS.fix_commits(root, b2, "R-002"))
        write(idx, replace(read(idx, String), "A second sentence, reworded." => "A second sentence."))
        chmod(idx, 0o755); gg("add", "--all", ".")
        gg("commit", "-q", "-m", "fake\n\n" * RUNS.GUARD_TRAILER * "\n" * RUNS.REVERT_TRAILER * fixb)
        @test !isempty(RUNS.unguarded_code(root, b2))
    end
end

@testset "the fixer refuses a mode change, a bad finding id, and leaves nothing staged when git fails" begin
    package() do root, gg
        idx = joinpath(root, "docs", "src", "index.md")
        write(idx, replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice.")); chmod(idx, 0o755)
        @test G.Docfix.commit(root, "fix"; io = devnull) == 1
        chmod(idx, 0o644)
        @test G.Docfix.commit(root, "fix"; io = devnull, finding = "F-1\n" * RUNS.REVERT_TRAILER * "0") == 2
        hook = joinpath(root, ".git", "hooks", "pre-commit"); write(hook, "#!/bin/sh\nexit 1\n"); chmod(hook, 0o755)
        @test G.Docfix.commit(root, "fix"; io = devnull) == 3
        @test isempty(readchomp(setenv(`git -C $root diff --cached --name-only`; dir = root)))
        rm(hook)
        @test G.Docfix.commit(root, "fix"; io = devnull) == 0
    end
end

@testset "a revert that cannot apply is reported, and the run cannot end as evaluated" begin
    package() do root, gg
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        idx = joinpath(root, "docs", "src", "index.md")
        reader_found(root, id, HOME_READER, "the grid is named but not said to be a lattice")
        all_clean(root, id; except = [HOME_READER])
        G.Run.collect(root; io = devnull)
        fid = only(RUNS.load(root, id).findings).id
        G.Run.next(root; io = devnull)                                  # → fix
        fixed_as(root, fid, "The grid is a lattice.")
        # a later edit to the same line, outside any finding, so the revert of the fix conflicts
        write(idx, replace(read(idx, String), "The grid is a lattice." => "The grid is a periodic lattice."))
        gg("add", "docs/src/index.md"); gg("commit", "-q", "-m", "later\n\n" * RUNS.GUARD_TRAILER * "\n" * RUNS.FINDING_TRAILER * "OTHER")
        G.Run.next(root; io = devnull)                                  # → verify
        verifier_said(root, id, "verify", fid, "MADE_WORSE"; quote_ = "The grid is a periodic lattice.")
        out = IOBuffer(); G.Run.collect(root; io = out)
        @test occursin("could NOT be reverted", String(take!(out)))
        @test !isempty(RUNS.load(root, id).unreverted)
        # a dirty tree refuses the close outright
        @test to_close(root, id) === :close
        write(idx, read(idx, String) * "\nstray\n")
        @test G.Run.close_run(root; io = devnull) == 2
        gg("checkout", "--", "docs/src/index.md")
        @test G.Run.close_run(root; io = devnull) == 2                   # CANNOT_EVALUATE
        record = G.JSON3.read(read(joinpath(RUNS.dir(root, id), "run.json"), String), Dict{String,Any})
        @test record["stop"] == "CANNOT_EVALUATE" && !isempty(record["unreverted"])
    end
end

# ── the stage machine, found in review 2026-09-23 ───────────────────────────────────────────────────

"A run parked on a code question and closed: the page is back to its old text, the question stands."
function parked_run(root)
    id, fid = with_one_finding(root)
    G.Run.next(root; io = devnull)
    fixed_as(root, fid, "The grid is a lattice.")
    G.Run.next(root; io = devnull)
    verifier_said(root, id, "verify", fid, "HIDES_CODE_DEFECT"; quote_ = "The grid is a lattice.")
    G.Run.collect(root; io = devnull)
    to_close(root, id); G.Run.close_run(root; io = devnull)
    return id, fid, RUNS.code_question_id(RUNS.load(root, id), fid)
end

@testset "the owner's answer to a code question does what its option says" begin
    package() do root, gg
        id, fid, qid = parked_run(root)
        idx = joinpath(root, "docs", "src", "index.md")
        @test occursin("spectral", read(idx, String))
        out = IOBuffer(); @test G.Answer.ask(root; io = out) == 1           # listed while it stands
        @test occursin(qid, String(take!(out)))
        gg("add", ".gbg"); gg("commit", "-q", "-m", "the record")
        @test G.Answer.answer(root, qid, "fix the documentation instead"; io = devnull) == 0
        @test occursin("lattice", read(idx, String))                       # the edit is made again
        run = RUNS.load(root, id)
        @test RUNS.closed(run, fid) && !RUNS.parked(run, fid)
        rep = G.Render.report(run, G.ConfigIO.read_config(root))
        @test occursin("**Answered:** fix the documentation instead", rep)
        @test G.Answer.ask(root; io = devnull) == 0
    end
    package() do root, gg
        id, fid, qid = parked_run(root)
        @test G.Answer.answer(root, qid, "not a defect"; io = devnull) == 0
        @test RUNS.closed(RUNS.load(root, id), fid)
    end
    package() do root, gg
        id, fid, qid = parked_run(root)
        @test G.Answer.answer(root, qid, "fix the code"; io = devnull, direction = "the lattice is right") == 0
        run = RUNS.load(root, id)
        @test isempty(RUNS.workable(run)) && isempty(RUNS.open_findings(run))
        @test only(RUNS.to_owner(run)).id == fid
    end
end

@testset "a parked finding stays in sight after the next run closes" begin
    package() do root, gg
        id, fid, qid = parked_run(root)
        gg("add", ".gbg", ".claude"); gg("commit", "-q", "-m", "the record")
        # a second run with a finding of its own, closed: its queue section is rewritten whole
        G.Run.start(root, :documentation_review; io = devnull)
        id2 = G.Run.open_run(root)
        reader_found(root, id2, HOME_READER, "a different defect")
        all_clean(root, id2; except = [HOME_READER])
        G.Run.collect(root; io = devnull)
        to_close(root, id2); G.Run.close_run(root; io = devnull)
        queue = read(joinpath(root, ".claude", "WORK_QUEUE.md"), String)
        @test occursin(qid, queue) && occursin("a different defect", queue)
    end
end

@testset "the queue's section is the exact heading, rewritten whole, and nothing of the owner's is touched" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        q = joinpath(root, ".claude", "WORK_QUEUE.md"); mkpath(dirname(q))
        mine = "# Owner notes\n\n- [ ] owner item\n\n## From the last reviewers' meeting\n\n- [ ] owner item A\n\n" *
               "## From the last review\n\n- [ ] stale-001 an old line\n\n### sub of mine\n\n- [ ] owner item B\n"
        write(q, mine); gg("add", ".claude"); gg("commit", "-q", "-m", "queue")
        G.Run.next(root; io = devnull); fixed_as(root, fid, "The grid is a lattice.")
        G.Run.next(root; io = devnull); verifier_said(root, id, "verify", fid, "FIXED"; quote_ = "The grid is a lattice.")
        G.Run.collect(root; io = devnull)
        to_close(root, id); @test G.Run.close_run(root; io = devnull) == 0
        text = read(q, String)
        @test !occursin("stale-001", text)                             # rewritten even with nothing left
        for keep in ("owner item\n", "owner item A", "owner item B", "## From the last reviewers' meeting", "### sub of mine")
            @test occursin(keep, text)
        end
    end
end

@testset "the hook counts the owner's sections and prints the file's line numbers" begin
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".claude"))
    q = joinpath(root, ".claude", "WORK_QUEUE.md")
    write(q, "# queue\n\n## From the last review\n\n- [ ] r1-001 not counted\n\n# Owner notes\n\n- [ ] my item\n")
    sh = joinpath(root, "hook.sh"); write(sh, G.Render.hook(G.Model.Config(package = "P", tool = :dev))); chmod(sh, 0o755)
    err = IOBuffer()
    p = run(pipeline(setenv(`bash $sh`, ["CLAUDE_PROJECT_DIR" => root]; dir = root); stdin = IOBuffer("{}"), stdout = devnull, stderr = err); wait = false); wait(p)
    msg = String(take!(err))
    @test p.exitcode == 2
    @test occursin("9:- [ ] my item", msg) && !occursin("r1-001", msg)
end

@testset "a reader that wrote nothing is launched once more, then named" begin
    package() do root, gg
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        reader_found(root, id, HOME_READER, "a term is used before it is defined")
        all_clean(root, id; except = [HOME_READER, "full"])
        write(joinpath(AGENTS.results_dir(root, id), "full.json"), "Here is my answer: {}")    # not readable
        @test G.Run.collect(root; io = devnull) == 2
        c = AGENTS.continue_stage(root, id)
        @test c.missing == ["full"]                                      # exactly the silent one
        @test G.Run.collect(root; io = devnull) == 2                     # still silent: exit 2, never a quiet 0 or 1
        run = RUNS.load(root, id)
        @test run.silent == ["full"]
        to_close(root, id); G.Run.close_run(root; io = devnull)
        rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
        @test occursin("Readers that wrote nothing", rep) && occursin("full", rep)
    end
end

@testset "abandon keeps an interrupted stage whose readers wrote, and a dirty tree stops a verifier launch" begin
    package() do root, gg
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        reader_found(root, id, HOME_READER, "found before the session died")
        @test G.Run.abandon(root; io = devnull) == 0
        @test isfile(joinpath(RUNS.dir(root, id), "run.json"))            # an agent ran: the record stays
    end
    package() do root, gg
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)                                   # → fix
        write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
        @test G.Run.next(root; io = devnull) == 2                        # uncommitted: no verifier is launched
        @test RUNS.stage_of(root, id) === :fix
    end
end

@testset "a fix the close reverts to get the build back is open again, and carried" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)
        fixed_as(root, fid, "The grid is a lattice. BREAKS THE BUILD.")
        G.Run.next(root; io = devnull); verifier_said(root, id, "verify", fid, "FIXED"; quote_ = "The grid is a lattice.")
        G.Run.collect(root; io = devnull)
        @test to_close(root, id) === :close
        old = SITE.BUILDER[]; SITE.BUILDER[] = picky_site
        try
            @test G.Run.close_run(root; io = devnull) == 2
        finally
            SITE.BUILDER[] = old
        end
        @test !RUNS.closed(RUNS.load(root, id), fid)
        gg("add", ".gbg"); gg("commit", "-q", "-m", "the record")
        G.Run.start(root, :documentation_review; io = devnull)
        @test [f.id for f in RUNS.load(root, G.Run.open_run(root)).findings] == [fid]
    end
end


# ── the second stage-machine review, 2026-09-23: nothing lost, whatever the order ───────────────────

@testset "\"fix the code\" lands on the owner's list and survives every close" begin
    package() do root, gg
        id, fid, qid = parked_run(root)
        gg("add", ".gbg", ".claude"); gg("commit", "-q", "-m", "the record")
        @test G.Answer.answer(root, qid, "fix the code"; io = devnull, direction = "the lattice\nis right") == 0
        q = joinpath(root, ".claude", "WORK_QUEUE.md")
        @test occursin("## Code the owner asked for", read(q, String)) && occursin(fid, read(q, String))
        @test !occursin("lattice\nis", read(q, String))                   # one line, whatever the text held
        gg("add", ".gbg", ".claude"); gg("commit", "-q", "-m", "answered")
        # a second run that finds nothing and closes: the owner's list is untouched
        G.Run.start(root, :documentation_review; io = devnull)
        id2 = G.Run.open_run(root); all_clean(root, id2)
        collect_twice(root); to_close(root, id2); G.Run.close_run(root; io = devnull)
        @test occursin(fid, read(q, String))
    end
end

@testset "an answer is refused where it cannot do what it says, and records nothing" begin
    package() do root, gg
        id, fid, qid = parked_run(root)
        gg("add", ".gbg", ".claude"); gg("commit", "-q", "-m", "the record")
        @test G.Answer.answer(root, qid, "fix the code"; io = devnull, settled = true) == 2
        G.Run.start(root, :documentation_review; io = devnull)             # a run is open
        @test G.Answer.answer(root, qid, "fix the documentation instead"; io = devnull) == 2
        @test RUNS.answer_of(RUNS.load(root, id), fid) === nothing          # nothing recorded
        # "not a defect" writes the settled list, a tracked file that would block the open run's collect
        # and every fix it commits: refused while another run is open (found in review, 2026-09-24)
        @test G.Answer.answer(root, qid, "not a defect"; io = devnull) == 2
        @test RUNS.answer_of(RUNS.load(root, id), fid) === nothing
        @test !isfile(joinpath(root, ".gbg", "settled.jl"))
        id2 = G.Run.open_run(root); all_clean(root, id2)
        @test collect_twice(root) in (0, 1)
    end
end

@testset "the open run's own question answered \"not a defect\" is settled when it closes" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)
        fixed_as(root, fid, "The grid is a lattice.")
        G.Run.next(root; io = devnull)
        verifier_said(root, id, "verify", fid, "HIDES_CODE_DEFECT"; quote_ = "The grid is a lattice.")
        G.Run.collect(root; io = devnull)
        qid = RUNS.code_question_id(RUNS.load(root, id), fid)
        @test G.Answer.answer(root, qid, "not a defect"; io = devnull) == 0
        @test !isfile(joinpath(root, ".gbg", "settled.jl"))                 # not while the run is open
        @test RUNS.answer_of(RUNS.load(root, id), fid) == "not a defect"
        to_close(root, id); G.Run.close_run(root; io = devnull)
        @test occursin(qid, read(joinpath(root, ".gbg", "settled.jl"), String))
    end
end

@testset "a question of a run that could not be evaluated is on the queue" begin
    package() do root, gg
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        reader_found(root, id, HOME_READER, "the grid is named but not said to be a lattice")
        all_clean(root, id; except = [HOME_READER, "full"])            # `full` stays silent
        @test collect_twice(root) == 2
        fid = only(RUNS.load(root, id).findings).id
        G.Run.next(root; io = devnull)
        fixed_as(root, fid, "The grid is a lattice.")
        G.Run.next(root; io = devnull)
        verifier_said(root, id, "verify", fid, "HIDES_CODE_DEFECT"; quote_ = "The grid is a lattice.")
        G.Run.collect(root; io = devnull)
        to_close(root, id)
        @test G.Run.close_run(root; io = devnull) == 2                    # a silent reader: not evaluated
        qid = RUNS.code_question_id(RUNS.load(root, id), fid)
        @test occursin(qid, read(joinpath(root, ".claude", "WORK_QUEUE.md"), String))
    end
end

@testset "a later pass reads only its own results" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        RUNS.save(root, G.Run.with(RUNS.load(root, id); budget = G.Model.Budget(fix_passes = 2)))   # two passes, for this
        G.Run.next(root; io = devnull)
        fixed_as(root, fid, "The grid is a lattice.")
        G.Run.next(root; io = devnull)
        verifier_said(root, id, "verify", fid, "NOT_FIXED")
        G.Run.collect(root; io = devnull)
        G.Run.next(root; io = devnull)                                    # → fix, pass 2
        @test RUNS.load(root, id).passes == 2 && RUNS.stage_of(root, id) === :fix
        fixed_as(root, fid, "The grid is a periodic lattice.")
        G.Run.next(root; io = devnull)                                    # its verify stage
        @test !isfile(joinpath(AGENTS.results_dir(root, id), "verify-unit-home.json"))   # pass 1's is gone
        @test G.Run.collect(root; io = devnull) == 2                      # silent: launched again, in pass 2 too
        # and the pass's fix is the commit made in it, not pass 1's (found by PF, 2026-09-24)
        write(joinpath(AGENTS.results_dir(root, id), "verify-unit-home.json"), """{"verdicts":[]}""")
        G.Run.collect(root; io = devnull)
        fixes = RUNS.load(root, id).fixes
        @test length(fixes) == 2 && fixes[1].commit != fixes[2].commit && all(f -> !isempty(f.commit), fixes)
    end
end

@testset "an answer that re-makes an edit makes all of it or none" begin
    # Two fixes of one finding reverted; the owner then changes what one of them touched, so re-making
    # that one fails. Whichever is tried first, the tree is left where it was and the question stands,
    # and once the conflict is gone the same answer succeeds (found in review, 2026-09-24).
    for clash in ("# GBG Fixture", "The grid is spectral.")
        package() do root, gg
            id, fid = with_one_finding(root)
            G.Run.next(root; io = devnull)
            idx = joinpath(root, "docs", "src", "index.md")
            fixed_as(root, fid, "The grid is a lattice.")
            write(idx, replace(read(idx, String), "# GBG Fixture" => "# GBG Fixture, a toy"))
            @test G.Docfix.commit(root, "second fix for " * fid; io = devnull, finding = fid) == 0
            G.Run.next(root; io = devnull)
            verifier_said(root, id, "verify", fid, "HIDES_CODE_DEFECT"; quote_ = "The grid is a lattice.")
            G.Run.collect(root; io = devnull)
            to_close(root, id); G.Run.close_run(root; io = devnull)
            qid = RUNS.code_question_id(RUNS.load(root, id), fid)
            gg("add", ".gbg", ".claude"); gg("commit", "-q", "-m", "the record")
            before = read(idx, String)
            write(idx, replace(before, clash => clash == "# GBG Fixture" ? "# The fixture" : "The grid is odd."))
            gg("add", "-u"); gg("commit", "-q", "-m", "the owner's own edit")
            head = RUNS.head_commit(root)
            @test G.Answer.answer(root, qid, "fix the documentation instead"; io = devnull) == 2
            @test RUNS.head_commit(root) == head
            @test RUNS.answer_of(RUNS.load(root, id), fid) === nothing
            gg("revert", "--no-edit", "HEAD")                              # the owner takes his edit back
            @test G.Answer.answer(root, qid, "fix the documentation instead"; io = devnull) == 0
            @test occursin("lattice", read(idx, String)) && occursin("a toy", read(idx, String))
        end
    end
end

@testset "a reader relaunched that then writes is not silent, and silence is exit 2" begin
    package() do root, gg
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        all_clean(root, id; except = ["full"])
        @test G.Run.collect(root; io = devnull) == 2                     # silent: launched again
        write(joinpath(AGENTS.results_dir(root, id), "full.json"), """{"findings":[],"checked":["x"]}""")
        @test G.Run.collect(root; io = devnull) == 0
        @test isempty(RUNS.load(root, id).silent)
    end
    package() do root, gg
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        all_clean(root, id; except = ["full"])
        @test collect_twice(root) == 2                                   # still silent after the relaunch
        @test RUNS.load(root, id).silent == ["full"]
        to_close(root, id); @test G.Run.close_run(root; io = devnull) == 2   # could not be fully evaluated
    end
end

@testset "a pass commits only for a finding it works on" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)
        write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a lattice."))
        @test G.Docfix.commit(root, "fix"; io = devnull, finding = "not-a-finding") == 2
        @test G.Docfix.commit(root, "fix"; io = devnull, finding = fid) == 0
    end
end

@testset "the hook reads the heading with a trailing space or a carriage return" begin
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".claude"))
    write(joinpath(root, ".claude", "WORK_QUEUE.md"), "# queue\r\n\r\n## From the last review \r\n\r\n- [ ] r1-001 not counted\r\n")
    sh = joinpath(root, "hook.sh"); write(sh, G.Render.hook(G.Model.Config(package = "P", tool = :dev))); chmod(sh, 0o755)
    p = run(pipeline(setenv(`bash $sh`, ["CLAUDE_PROJECT_DIR" => root]; dir = root); stdin = IOBuffer("{}"), stdout = devnull, stderr = devnull); wait = false); wait(p)
    @test p.exitcode == 0
end

# ── What each agent is given: a review of 2026-09-23, each case the shape it was found in ────────────

@testset "one defect several readers filed is one finding, and every reader's claim is kept" begin
    package() do root, gg
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        rule = "RULE.DOC.TERMS_DEFINED"
        reader_found(root, id, HOME_READER, "the grid is named but not said to be a lattice"; rule)
        reader_found(root, id, "full", "the grid's kind is unstated"; rule)
        all_clean(root, id; except = [HOME_READER, "full"])
        @test G.Run.collect(root; io = devnull) == 1
        f = only(RUNS.load(root, id).findings)
        said = f.draft.claim * "\n" * f.draft.evidence
        @test occursin("the grid's kind is unstated", said) && occursin("not said to be a lattice", said)
        @test occursin("Fix proposed: say which", f.draft.evidence)      # the second reader's fix is kept
    end
    loc(text; line = 3) = G.Model.Location(file = "docs/src/index.md", text = text, line = line, found = G.Model.Anchor.BY_QUOTE)
    d(rule, claim = "c"; text = "x") = G.Model.FindingDraft(rule = rule, locations = [loc(text)], claim = claim, evidence = "", fix = "")
    cfg = G.Model.Config(package = "P", tool = :dev)
    # under two different rules, one sentence is two defects
    @test length(G.Run.merge_same([("a", d(:R1)), ("b", d(:R2))], cfg)) == 2
    @test length(G.Run.merge_same([("a", d(:R1)), ("b", d(:R1))], cfg)) == 1
    # one line is not one defect: two quotes of one long paragraph under one rule are two classes
    @test length(G.Run.merge_same([("a", d(:R1; text = "term A")), ("b", d(:R1; text = "term B"))], cfg)) == 2
    # under no rule, two readers saying two things of one sentence are two findings (review, 2026-09-24)
    @test length(G.Run.merge_same([("a", d(nothing, "E is undefined")), ("b", d(nothing, "the law is wrong"))], cfg)) == 2
    @test length(G.Run.merge_same([("a", d(nothing, "E is undefined")), ("b", d(nothing, "E is  undefined"))], cfg)) == 1
    # a whole-file finding, with no quote, merges with nothing
    @test length(G.Run.merge_same([("a", d(:R1; text = "")), ("b", d(:R1; text = ""))], cfg)) == 2
end

@testset "a finding under a rule switched off for its files is the switch's" begin
    loc(f) = G.Model.Location(file = f, text = "x", line = 1)
    d(files) = G.Model.FindingDraft(rule = Symbol("RULE.DOC.TERMS_DEFINED"), locations = loc.(files),
                                    claim = "c", evidence = "", fix = "")
    cfg = G.Model.Config(package = "P", tool = :dev,
                         switches = [G.Model.Switch(target = Symbol("RULE.DOC.TERMS_DEFINED"),
                                                    files = ["docs/src/index.md"], reason = "r")])
    @test G.Run.switched_off(cfg, d(["docs/src/index.md"]))
    @test !G.Run.switched_off(cfg, d(["docs/src/index.md", "docs/src/guide.md"]))   # one file still judged
    @test !G.Run.switched_off(G.Model.Config(package = "P", tool = :dev), d(["docs/src/index.md"]))
end

@testset "the verifier is shown every commit of the fix, or every fix of the pass when it has none" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        run = RUNS.load(root, id)
        @test G.Run.fix_diff(root, run, [run.findings[1]]) == ""        # nothing committed yet
        fixed_as(root, fid, "The grid is a spectral lattice.")
        write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a periodic spectral lattice."))
        @test G.Docfix.commit(root, "second half of " * fid; io = devnull, finding = fid) == 0
        both = G.Run.fix_diff(root, run, [run.findings[1]])
        @test occursin("fix for", both) && occursin("second half of", both)
        @test findfirst("fix for", both)[1] < findfirst("second half of", both)[1]   # oldest first
        other = G.Model.Finding("other-001", :full, G.Model.Decider.AGENT,
                                G.Model.FindingDraft(rule = nothing, locations = G.Model.Location[], claim = "c", evidence = "", fix = ""))
        none = G.Run.fix_diff(root, run, [other])
        @test startswith(none, "# No commit names these findings") && occursin("second half of", none)
    end
end

@testset "a finding on an example's source is verified on that file, which is not withheld from it" begin
    package() do root, gg
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        args = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
        src = only(String(r["key"]) for r in args["roles"] if whole(args, r)["source_unit"] === true)
        reader_found(root, id, src, "a full-line comment inside the code is prose that will not render";
                     file = "examples/scaling.jl", quote_ = "is scaled in place by", rule = "RULE.DOC.LITERATE")
        all_clean(root, id; except = [src])
        @test G.Run.collect(root; io = devnull) == 1
        fid = only(RUNS.load(root, id).findings).id
        G.Run.next(root; io = devnull)                                    # fix
        ex = joinpath(root, "examples", "scaling.jl")
        write(ex, replace(read(ex, String), "is scaled in place by" => "is scaled, in place, by"))
        @test G.Docfix.commit(root, "fix for " * fid; io = devnull, finding = fid) == 0
        G.Run.next(root; io = devnull)                                    # verify
        v = G.JSON3.read(read(AGENTS.arguments_path(root, id), String), Dict{String,Any})
        role = whole(v, only(v["roles"]))
        @test role["source_unit"] === true && role["kept_from_code"] === false
        @test String(role["unit"]) == ex
    end
end

@testset "two examples are two units, and the fingerprint moves with the readers" begin
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, "examples"))
    write(joinpath(root, "examples", "a-b.jl"), "# a\n"); write(joinpath(root, "examples", "a.b.jl"), "# b\n")
    cfg = G.Model.Config(package = "P", tool = :dev)
    keys_ = [u.key for u in G.Run.source_units(cfg, root)]
    @test length(keys_) == 2 && allunique(keys_)
    # a declared discipline adds a reader, and a changed-scope base read without it no longer stands
    with_expert = G.Model.Config(package = "P", tool = :dev, disciplines = [:differential_geometry])
    @test RUNS.rulebook_digest(cfg, :documentation_review) != RUNS.rulebook_digest(with_expert, :documentation_review)
    @test RUNS.rulebook_digest(cfg, :documentation_review) == RUNS.rulebook_digest(cfg, :documentation_review)
end

# `bump` wrote every file and the pin, then crashed on its closing message with a MethodError, exit 3,
# from the day the message was added: nothing ran it end to end (found upgrading GBGPeriodicFields,
# 2026-09-24).
@testset "bump runs to its end" begin
    package() do root, gg
        out = IOBuffer()
        @test G.Bump.bump(root, v"2.0.0-rc.99"; io = out) == 0
        text = String(take!(out))
        @test occursin("pinned at v2.0.0-rc.99", text) && occursin("NOT FINISHED", text)
        @test occursin("v\"2.0.0-rc.99\"", read(joinpath(root, ".gbg", "config.jl"), String))
    end
end

# A finding whose fix only the owner may make — the config, code, a formula — could not be committed or
# verified, cost a verifier every pass, and reached him only at close. `gbg run park` hands it to him at
# the fix stage, through the same question a verifier's code verdict puts (ruled 2026-09-24).
@testset "a finding only the owner may fix is parked at the fix stage, and reaches him at once" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        @test G.Run.park(root, fid; why = "a switch in .gbg/config.jl", io = devnull) == 2   # not at a fix stage
        G.Run.next(root; io = devnull)                                    # fix
        @test G.Run.park(root, fid; io = devnull) == 2                    # no reason given
        @test G.Run.park(root, "no-such-finding"; why = "x", io = devnull) == 2
        out = IOBuffer()
        @test G.Run.park(root, fid; why = "a switch in .gbg/config.jl", io = out) == 0
        run = RUNS.load(root, id)
        qid = RUNS.code_question_id(run, fid)
        printed = String(take!(out))
        @test occursin(qid, printed)
        # the question passed the language rules on its way in, and the path it names is reported
        # with the rule named, as `gbg ask` reports one (§8; found in review, 2026-09-26)
        @test occursin("RULE.ASK.NO_COORDINATES", printed)
        @test RUNS.parked(run, fid) && isempty(RUNS.workable(run))
        @test G.Run.park(root, fid; why = "again", io = devnull) == 2     # already waiting on the owner
        # nothing to verify and nothing committed: the run goes to its close
        G.Run.next(root; io = devnull)
        @test RUNS.stage_of(root, id) === :close
        # his answer does what it does to a code question: on his list, and out of the run
        @test G.Answer.answer(root, qid, "fix the code"; io = devnull) == 2          # not an option of a parked finding
        @test G.Answer.answer(root, qid, "I make the change"; io = devnull) == 0
        run = RUNS.load(root, id)
        @test !RUNS.parked(run, fid) && fid in [f.id for f in RUNS.to_owner(run)]
        @test occursin(fid, read(joinpath(root, ".claude", "WORK_QUEUE.md"), String))
    end
    # "fix it on my ruling": the finding is the fixer's again, its commit carries the id, and a verifier
    # closes it (ruled 2026-09-26; PF fixed eight parked findings with no answer that said so)
    package() do root, gg
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)
        @test G.Run.park(root, fid; why = "the formula changes", io = devnull) == 0
        qid = RUNS.code_question_id(RUNS.load(root, id), fid)
        @test G.Answer.answer(root, qid, "fix it on my ruling"; io = devnull, direction = "write lattice") == 0
        run = RUNS.load(root, id)
        @test !RUNS.parked(run, fid) && [f.id for f in RUNS.workable(run)] == [fid]
        fixed_as(root, fid, "The grid is a lattice.")                    # docfix accepts the id again
        G.Run.next(root; io = devnull)
        verifier_said(root, id, "verify", fid, "FIXED"; quote_ = "The grid is a lattice.")
        @test G.Run.collect(root; io = devnull) == 0
        @test RUNS.closed(RUNS.load(root, id), fid)
    end
end

# Two helpers rebuilt the record field by field from a list written by hand, and both dropped `rulebook`,
# added after them: every stage and every answer erased the digest a changed-scope run compares
# (found 2026-09-24). They read the fields off the type now; this holds them to every field there is.
@testset "rebuilding the record keeps every field" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        run = RUNS.load(root, id)
        @test !isempty(run.rulebook)                                      # survived the collect's save
        again = G.Run.with(run; stage = :fix)
        for f in fieldnames(G.Model.Run)
            f === :stage || @test getfield(again, f) == getfield(run, f)
        end
        qs = RUNS.with_questions(run, G.Model.Question[])
        for f in fieldnames(G.Model.Run)
            f === :questions || @test getfield(qs, f) == getfield(run, f)
        end
    end
end

# ── Measured on GBGPeriodicFields' first full review (2026-09-24) ─────────────────────────────────────

@testset "the record keeps what a stage cost, summed from the agents' transcripts" begin
    package() do root, gg
        G.Run.start(root, :documentation_review; io = devnull)
        id = G.Run.open_run(root)
        dir = mktempdir(; cleanup = true)
        @test G.Run.cost(root, dir; io = devnull) == 2                    # not at a collect yet
        all_clean(root, id)
        G.Run.collect(root; io = devnull)
        @test G.Run.cost(root, dir; io = devnull) == 2                    # nothing under it
        rec(u; id = nothing) = G.JSON3.write(Dict("type" => "assistant",
                                                  "message" => id === nothing ? Dict("usage" => u) : Dict("usage" => u, "id" => id))) * "\n"
        # one message written as two lines — a thinking block and a text block — carries its usage twice
        # and is paid once (measured on a PF transcript, 2026-09-26: 2.5× the real figure summed per line)
        twice = Dict("input_tokens" => 5, "cache_creation_input_tokens" => 100, "cache_read_input_tokens" => 1000, "output_tokens" => 7)
        write(joinpath(dir, "agent-a.jsonl"), rec(twice; id = "msg_1") * rec(twice; id = "msg_1") *
                                               "not json\n" *
                                               rec(Dict("input_tokens" => 1, "cache_creation_input_tokens" => 10,
                                                        "cache_read_input_tokens" => 200, "output_tokens" => 3); id = "msg_2"))
        mkpath(joinpath(dir, "sub")); write(joinpath(dir, "sub", "agent-b.jsonl"), rec(Dict("output_tokens" => 2)))
        write(joinpath(dir, "journal.jsonl"), """{"type":"started","key":"x"}\n""")   # no usage: not an agent
        out = IOBuffer()
        @test G.Run.cost(root, dir; io = out) == 0
        u = only(RUNS.load(root, id).usage)
        @test u.stage == "find" && u.pass == 0 && u.agents == 2
        @test (u.input, u.cache_write, u.cache_read, u.output) == (6, 110, 1200, 12)
        @test G.Run.cost(root, dir; io = devnull) == 0 && length(RUNS.load(root, id).usage) == 1   # replaced, not doubled
        to_close(root, id); G.Run.close_run(root; io = devnull)
        rep = read(joinpath(RUNS.dir(root, id), "report.md"), String)
        @test occursin("| find | 0 | 2 | 110 | 1200 | 6 | 12 |", rep)
    end
end

@testset "a verifier whose file never appeared is read from what the driver returned" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)
        fixed_as(root, fid, "The grid is a lattice.")
        G.Run.next(root; io = devnull)
        write(joinpath(AGENTS.stage_dir(root, id), "returned.json"), G.JSON3.write(Dict(
            "run" => id, "stage" => "verify", "silent" => [],
            "results" => Dict("verify-unit-home" => Dict("verdicts" => [Dict("finding" => fid, "verdict" => "FIXED", "quote" => "The grid is a lattice.")])))))
        @test G.Run.collect(root; io = devnull) == 0                      # no result file, and still graded
        @test RUNS.closed(RUNS.load(root, id), fid)
    end
end

@testset "a commit that breaks a rule the run opened clean on is refused" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)
        # a fix that grows the page past its recorded size breaks RULE.DOC.SHAPE, which the run opened
        # clean on — the case PF met, where check reported it and commit went ahead (2026-09-24)
        long = "The grid is a lattice, " * repeat("and this sentence goes on and on, ", 24) * "as no fix should."   # past the 120-word paragraph cap
        write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => long))
        out = IOBuffer()
        @test G.Docfix.commit(root, "fix for " * fid; io = out, finding = fid) == 1
        @test occursin("breaks", String(take!(out))) 
        @test isempty(RUNS.fix_commits(root, RUNS.load(root, id).first_commit, fid))
        fixed_as(root, fid, "The grid is a lattice.")                    # a clean fix still goes through
    end
end

@testset "help on a run verb acts on nothing" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        cd(root) do
            @test G.Run.cmd_run(["abandon", "--help"]) == 0
        end
        @test G.Run.open_run(root) == id                                  # still open
    end
end

@testset "a re-baseline of one unit leaves every other row as it was" begin
    package() do root, gg
        cfg = G.ConfigIO.read_config(root)
        G.Catalogue.Shape.write_baseline(root, cfg)
        before = G.Catalogue.Shape.baseline(root)
        write(joinpath(root, "docs", "src", "index.md"), HOME_PAGE * "\nA new paragraph of prose, with more words than before.\n")
        write(joinpath(root, "docs", "src", "notation.md"), read(joinpath(root, "docs", "src", "notation.md"), String) * "\nAnd more words here too.\n")
        @test G.Check.rebaseline(root; only = "index.md", io = devnull) == 0
        after = G.Catalogue.Shape.baseline(root)
        grew = [k for k in keys(after) if haskey(before, k) && after[k] != before[k]]
        @test !isempty(grew) && all(k -> occursin("index.md", k), grew)
    end
end

# Inside a run a unit may grow by a small allowance — ten words, or five percent — and the close records
# what grew; outside a run the ratchet is strict (ruled 2026-09-26, PF's item 5).
@testset "a fix may grow a unit a little inside a run, and the close records it" begin
    package() do root, gg
        cfg = G.ConfigIO.read_config(root)
        G.Catalogue.Shape.write_baseline(root, cfg)
        gg("add", "--all", "."); gg("commit", "-q", "-m", "baseline")
        idx = joinpath(root, "docs", "src", "index.md")
        grow(n) = write(idx, replace(HOME_PAGE, "The grid is spectral." => "The grid is spectral, " * join(fill("truly", n), " ") * "."))
        shape() = [l.text for l in G.Catalogue.Shape.prose_shape(root, cfg) if occursin("index.md", l.text)]
        grow(6)
        @test !isempty(shape())                                          # no run open: strict
        write(idx, HOME_PAGE)
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)
        # The allowance is the fixer's verb's to grant, for its own call, never a file a build reads
        # (F-1, 2026-09-26): what `gbg docfix` sets, set here around the direct call.
        in_run(f) = (G.Catalogue.Shape.IN_RUN[] = true; try f() finally G.Catalogue.Shape.IN_RUN[] = false end)
        grow(6)
        @test in_run(() -> isempty(shape()))                            # within the allowance
        @test !isempty(shape())                                          # a build, run open or not: strict
        grow(14)
        @test in_run(() -> !isempty(shape()))                           # past it
        write(idx, HOME_PAGE); grow(6)
        @test G.Docfix.commit(root, "fix for " * fid; io = devnull, finding = fid) == 0
        G.Run.next(root; io = devnull)
        verifier_said(root, id, "verify", fid, "FIXED"; quote_ = "truly truly")
        G.Run.collect(root; io = devnull)
        to_close(root, id)
        out = IOBuffer()
        @test G.Run.close_run(root; io = out) == 0
        @test occursin("grew within the allowance", String(take!(out)))
        after = G.Catalogue.Shape.baseline(root)
        @test isempty(shape())                                           # recorded: strict again, and clean
        @test G.Catalogue.Shape.allowance(20) == 10 && G.Catalogue.Shape.allowance(400) == 20
    end
end

# A red build at `gbg run next` names the pass's commits that touched the files it complains about, and
# `docfix check` warns of a reference it cannot resolve without refusing (ruled 2026-09-26, PF's item 7).
@testset "a red build after a fix stage names the commits to look at; a dead reference is a warning" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)
        write(joinpath(root, "docs", "src", "index.md"), replace(HOME_PAGE, "The grid is spectral." => "The grid is a [`no_such_thing`](@ref) lattice."))
        out = IOBuffer()
        @test G.Docfix.check(root; build = false, io = out) in (0, 1)
        @test occursin("cannot resolve", String(take!(out))) && occursin("no_such_thing", String(take!(out)) * "no_such_thing")
        out = IOBuffer()
        @test G.Docfix.commit(root, "fix for " * fid; io = out, finding = fid) == 0   # a warning, not a refusal
        @test occursin("no_such_thing", String(take!(out)))
        # a resolvable reference draws no warning
        write(joinpath(root, "docs", "src", "notation.md"), read(joinpath(root, "docs", "src", "notation.md"), String) * "\nSee [`Grid`](@ref).\n")
        out = IOBuffer(); G.Docfix.check(root; build = false, io = out)
        @test !occursin("cannot resolve", String(take!(out)))
        write(joinpath(root, "docs", "src", "notation.md"), read(joinpath(root, "docs", "src", "notation.md"), String) * "\nBREAKS THE BUILD\n")
        @test G.Docfix.commit(root, "second fix for " * fid; io = devnull, finding = fid) == 0
        old = SITE.BUILDER[]; SITE.BUILDER[] = (r, c; io = devnull) -> (println(io, "ERROR: docs/src/notation.md: no such thing"); nothing)
        try
            out = IOBuffer()
            @test G.Run.next(root; io = out) == 2                          # the build is red: the run stays at fix
            text = String(take!(out))
            @test occursin("these commits of pass 1 touched", text) && occursin("docs/src/notation.md", text) && occursin(fid, text)
            @test RUNS.stage_of(root, id) === :fix
        finally
            SITE.BUILDER[] = old
        end
    end
end

# ── The review of 2026-09-26: the run path, each case the shape it was found in ──────────────────────

@testset "a finding parked, ruled on, fixed and judged again carries one question, not two" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)
        @test G.Run.park(root, fid; why = "the formula changes", io = devnull) == 0
        qid = RUNS.code_question_id(RUNS.load(root, id), fid)
        @test G.Answer.answer(root, qid, "fix it on my ruling"; io = devnull, direction = "write lattice") == 0
        fixed_as(root, fid, "The grid is a lattice.")
        G.Run.next(root; io = devnull)
        verifier_said(root, id, "verify", fid, "HIDES_CODE_DEFECT"; quote_ = "The grid is a lattice.")
        @test G.Run.collect(root; io = devnull) == 1
        run = RUNS.load(root, id)
        @test count(q -> q.id == qid, run.questions) == 1            # replaced, not appended
        @test RUNS.parked(run, fid) && isempty(RUNS.workable(run))    # and the finding waits again
        @test RUNS.answer_of(run, fid) === nothing
        # and the ruling the fix was made on is carried into the new question, not lost (verified 2026-09-27)
        q = only(x for x in run.questions if x.id == qid)
        @test occursin("fix it on my ruling", q.context) && occursin("write lattice", q.context)
    end
end

@testset "a stage's arguments clear what the driver returned last time" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)
        fixed_as(root, fid, "The grid is a lattice.")
        # what an older launch of the verify stage returned, beside where its results will be
        stale = joinpath(AGENTS.scratch_dir(root, id), "5-verify", "returned.json")
        mkpath(dirname(stale))
        write(stale, G.JSON3.write(Dict("results" => Dict("verify-unit-home" =>
            Dict("verdicts" => [Dict("finding" => fid, "verdict" => "FIXED", "quote" => "The grid is a lattice.")])))))
        G.Run.next(root; io = devnull)                                   # verify: the arguments are written
        @test !isfile(stale)
        @test G.Run.collect(root; io = devnull) == 2                     # the verifier wrote nothing: silent, not graded
        @test !RUNS.closed(RUNS.load(root, id), fid)
    end
end

@testset "abandon takes a dropped finding's question with it" begin
    package() do root, gg
        id, fid = with_one_finding(root)
        G.Run.next(root; io = devnull)
        @test G.Run.park(root, fid; why = "a formula", io = devnull) == 0
        qid = RUNS.code_question_id(RUNS.load(root, id), fid)
        @test G.Run.abandon(root; io = devnull) == 0
        @test isempty(RUNS.open_questions(root))                        # nobody holds the finding: nobody is asked
        @test fid in RUNS.load(root, id).dropped_ids
        gg("add", "--all", "."); gg("commit", "-q", "-m", "the record")
        G.Run.start(root, :documentation_review; io = devnull)
        id2 = G.Run.open_run(root); all_clean(root, id2)
        collect_twice(root); to_close(root, id2); G.Run.close_run(root; io = devnull)
        q = joinpath(root, ".claude", "WORK_QUEUE.md")
        @test !isfile(q) || !occursin(qid, read(q, String))
    end
end
