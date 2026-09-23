# test/scope.jl — what a `changed` run reads, and when it refuses to be one.
#
# Two questions, and they fail differently. The BASE is a fact about history: which commit the last run
# like this one read, and whether anything since makes that reading stale. The MAPPING is a fact about
# readers: which of them a given change reaches. A wrong base reads too little and misses a defect; a
# wrong mapping launches an agent over a corpus nothing touched. Both are tested over a real repository,
# because both are answers git gives.
using Test, GBGCodingTools, Dates, JSON3
include("helpers.jl")

const SC = G.Orchestration.Scope
const RN = G.Orchestration.Runs

# A package with a git history, a config, and whatever files the caller names.
function scope_repo(files::AbstractDict = Dict{String,String}())
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".gbg"))
    write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = v"2.0.0-rc.7")""")
    for (f, text) in files
        mkpath(joinpath(root, dirname(f)))
        write(joinpath(root, f), text)
    end
    for args in (("init", "-q", "-b", "master"), ("config", "user.email", "t@example.com"),
                 ("config", "user.name", "T"), ("add", "-A"), ("commit", "-q", "-m", "first"))
        run(pipeline(setenv(`git -C $root $args`; dir = root); stdout = devnull, stderr = devnull))
    end
    return root
end

# `--allow-empty` so "nothing changed" is a commit like any other and the base still precedes HEAD.
commit_all(root, msg) = for args in (("add", "-A"), ("commit", "-q", "--allow-empty", "-m", msg))
    run(pipeline(setenv(`git -C $root $args`; dir = root); stdout = devnull, stderr = devnull))
end

# A finished run of `readers`, its record committed, as a closed run leaves it.
function close_a_run(root, id, readers; stop = G.Model.Stop.DONE, tool = "2.0.0-rc.7",
                     rulebook = RN.rulebook_digest(G.ConfigIO.read_config(root), :documentation_review))
    run_ = G.Model.Run(id = id, instrument = :documentation_review, tool_version = tool,
                       first_commit = "abc", budget = G.Model.Budget(), stage = :close,
                       readers = readers, stop = stop, rulebook = rulebook)
    d = joinpath(root, ".gbg", "runs", id); mkpath(d)
    write(joinpath(d, "run.json"), JSON3.write(RN.as_dict(run_)))
    commit_all(root, "close $id")
    return run_
end

@testset "the base a changed run measures from" begin

    @testset "no closed run is no base, and the reason says so" begin
        root = scope_repo()
        cfg = G.ConfigIO.read_config(root)
        @test SC.base(root, :documentation_review, :bound, cfg) === nothing
        @test occursin("has closed here", SC.why_full(root, :documentation_review, :bound, cfg))
    end

    @testset "a closed run is the base, and it is per reader combination" begin
        root = scope_repo()
        cfg = G.ConfigIO.read_config(root)
        close_a_run(root, "2026-09-22-a", :bound)
        got = SC.base(root, :documentation_review, :bound, cfg)
        @test got !== nothing && last(got) == "2026-09-22-a"
        @test SC.why_full(root, :documentation_review, :bound, cfg) == ""
        # A `bound` run says nothing about what an `open` reader would have found.
        @test SC.base(root, :documentation_review, :open, cfg) === nothing
        @test occursin("open", SC.why_full(root, :documentation_review, :open, cfg))
    end

    @testset "a run that stopped short is no base" begin
        for stop in (G.Model.Stop.CANNOT_EVALUATE, G.Model.Stop.OWNER_STOPPED)
            root = scope_repo()
            cfg = G.ConfigIO.read_config(root)
            close_a_run(root, "2026-09-22-b", :bound; stop)
            @test SC.base(root, :documentation_review, :bound, cfg) === nothing
            @test occursin("stopped as", SC.why_full(root, :documentation_review, :bound, cfg))
        end
    end

    @testset "the rules moving reads full" begin
        root = scope_repo()
        cfg = G.ConfigIO.read_config(root)
        close_a_run(root, "2026-09-22-c", :bound; rulebook = "0"^64)   # the run read an older rulebook
        @test SC.base(root, :documentation_review, :bound, cfg) === nothing
        @test occursin("the rules or the readers moved", SC.why_full(root, :documentation_review, :bound, cfg))
        # the version is not what is compared: an unchanged rulebook under another version is a base
        root = scope_repo()
        close_a_run(root, "2026-09-22-c", :bound; tool = "2.0.0-rc.6")
        @test SC.base(root, :documentation_review, :bound, cfg) !== nothing
    end

    @testset "a record from before the digest compares the version that ran" begin
        root = scope_repo()
        cfg = G.ConfigIO.read_config(root)
        close_a_run(root, "2026-09-22-g", :bound; tool = "2.0.0-rc.6", rulebook = "")
        @test occursin("the tool moved", SC.why_full(root, :documentation_review, :bound, cfg))
        root = scope_repo()
        close_a_run(root, "2026-09-22-g", :bound; tool = string(RN.GBG_VERSION[]), rulebook = "")
        @test SC.base(root, :documentation_review, :bound, cfg) !== nothing
    end

    @testset "a change to the docs build's script reads full" begin
        root = scope_repo(Dict("docs/make.jl" => "# builds the site\n"))
        cfg = G.ConfigIO.read_config(root)
        close_a_run(root, "2026-09-22-h", :bound)
        @test SC.base(root, :documentation_review, :bound, cfg) !== nothing
        write(joinpath(root, "docs", "make.jl"), "# builds the site, with Literate now\n")
        commit_all(root, "build the examples")
        @test SC.base(root, :documentation_review, :bound, cfg) === nothing
        @test occursin("docs/make.jl changed", SC.why_full(root, :documentation_review, :bound, cfg))
    end

    @testset "a config change reads full" begin
        root = scope_repo()
        cfg = G.ConfigIO.read_config(root)
        close_a_run(root, "2026-09-22-d", :bound)
        @test SC.base(root, :documentation_review, :bound, cfg) !== nothing
        write(joinpath(root, ".gbg", "config.jl"),
              """Config(package = "Sample", tool = v"2.0.0-rc.7", disciplines = [:differential_geometry])""")
        commit_all(root, "declare a discipline")
        @test SC.base(root, :documentation_review, :bound, G.ConfigIO.read_config(root)) === nothing
        @test occursin("config.jl changed", SC.why_full(root, :documentation_review, :bound, G.ConfigIO.read_config(root)))
    end

    @testset "an uncommitted record is no base" begin
        root = scope_repo()
        cfg = G.ConfigIO.read_config(root)
        run_ = G.Model.Run(id = "2026-09-22-e", instrument = :documentation_review, tool_version = "2.0.0-rc.7",
                           first_commit = "abc", budget = G.Model.Budget(), stage = :close, readers = :bound)
        d = joinpath(root, ".gbg", "runs", "2026-09-22-e"); mkpath(d)
        write(joinpath(d, "run.json"), JSON3.write(RN.as_dict(run_)))   # written, never committed
        @test SC.base(root, :documentation_review, :bound, cfg) === nothing
        @test occursin("not committed", SC.why_full(root, :documentation_review, :bound, cfg))
    end
end

@testset "which readers a change reaches" begin
    files = Dict("docs/src/index.md" => "# Home\n\nProse.\n",
                 "docs/src/notation.md" => "# Notation\n\nSymbols.\n",
                 "docs/src/api.md" => "# API\n\n```@docs\nf\n```\n",
                 "src/A.jl" => "\"\"\"f docstring\"\"\"\nf(x) = x\n")
    root = scope_repo(files)
    cfg = G.ConfigIO.read_config(root)
    close_a_run(root, "2026-09-22-f", :bound)
    b = SC.base(root, :documentation_review, :bound, cfg)
    @test b !== nothing
    commit = first(b)

    panel = G.Catalogue.roles_of(:documentation_review, cfg; readers = :bound)
    byid = Dict(r.id => r for r in panel)
    @test haskey(byid, :withheld) && haskey(byid, :full)

    @testset "an edited function body reaches the reader given the source, not the one kept from it" begin
        write(joinpath(root, "src", "A.jl"), "\"\"\"f docstring\"\"\"\nf(x) = x + 0\n")
        commit_all(root, "edit a body")
        sets = SC.sets_of(cfg, root, SC.changed_since(root, commit), commit)
        @test haskey(sets, G.Model.FileSet.CODE)
        @test !haskey(sets, G.Model.FileSet.DOCSTRINGS)   # the prose did not move
        @test SC.reaches(byid[:full], sets)          # the source is beside it
        @test !SC.reaches(byid[:withheld], sets)     # the code is kept from it
    end

    @testset "an edited page reaches both, since both read pages" begin
        root2 = scope_repo(files)
        cfg2 = G.ConfigIO.read_config(root2)
        close_a_run(root2, "2026-09-22-g", :bound)
        c2 = first(SC.base(root2, :documentation_review, :bound, cfg2))
        write(joinpath(root2, "docs", "src", "index.md"), "# Home\n\nOther prose.\n")
        commit_all(root2, "edit a page")
        sets = SC.sets_of(cfg2, root2, SC.changed_since(root2, c2), c2)
        @test haskey(sets, G.Model.FileSet.PAGES)
        @test SC.reaches(byid[:full], sets)
        @test SC.reaches(byid[:withheld], sets)
    end

    # Code reaches a bound reader only through a rule that needs the source (found in review, 2026-09-23).
    @testset "an edited function body does not reach the reader of the built site" begin
        rendered = G.Model.AgentRole(id = :rendered, instrument = :documentation_review,
                                     reads = [G.Model.FileSet.PAGES], site = true, description = "r",
                                     rules = [Symbol("RULE.TEX.NO_HSCROLL")], cap = 1)
        sets = Dict(G.Model.FileSet.CODE => ["src/A.jl"])
        @test !SC.reaches(rendered, sets)
        open_reader = G.Model.AgentRole(id = :logician, instrument = :documentation_review,
                                        reads = [G.Model.FileSet.PAGES], description = "l", cap = 1)
        @test SC.reaches(open_reader, sets)
    end

    @testset "a deleted page reaches the readers of pages" begin
        root2 = scope_repo(files)
        cfg2 = G.ConfigIO.read_config(root2)
        close_a_run(root2, "2026-09-22-k", :bound)
        c2 = first(SC.base(root2, :documentation_review, :bound, cfg2))
        rm(joinpath(root2, "docs", "src", "notation.md"))
        commit_all(root2, "delete the notation page")
        sets = SC.sets_of(cfg2, root2, SC.changed_since(root2, c2), c2)
        @test get(sets, G.Model.FileSet.PAGES, String[]) == ["docs/src/notation.md"]
        @test SC.reaches(byid[:full], sets)
    end

    @testset "nothing changed reaches nobody" begin
        sets = SC.sets_of(cfg, root, String[])
        @test isempty(sets)
        @test !SC.reaches(byid[:full], sets)
        @test !SC.reaches(byid[:withheld], sets)
    end
end

@testset "which units a change reaches" begin
    files = Dict("docs/src/index.md" => "# Home\n\nProse.\n",
                 "docs/src/notation.md" => "# Notation\n\nSymbols.\n",
                 "docs/src/api.md" => "# API\n\n```@docs\nf\n```\n",
                 "src/A.jl" => "\"\"\"f docstring\"\"\"\nf(x) = x\n")
    root = scope_repo(files)
    cfg = G.ConfigIO.read_config(root)
    close_a_run(root, "2026-09-22-h", :bound)
    commit = first(SC.base(root, :documentation_review, :bound, cfg))

    # The units a built site would give, named the way `Site.pages` names them.
    unit(p) = (path = p, key = G.Orchestration.Site.key_of(p), text = "")
    home, notation, api = unit("index.html"), unit("notation/index.html"), unit("api/index.html")

    @testset "an edited hand page is its own unit and no other" begin
        write(joinpath(root, "docs", "src", "notation.md"), "# Notation\n\nMore symbols.\n")
        commit_all(root, "edit the notation page")
        changed = SC.changed_since(root, commit)
        sets, added = SC.sets_of(cfg, root, changed, commit), SC.added_since(root, commit)
        @test SC.unit_touched(root, cfg, notation, sets, added)
        @test !SC.unit_touched(root, cfg, home, sets, added)
        @test !SC.unit_touched(root, cfg, api, sets, added)
    end

    # A rationale document that is not a target is read by nobody, so a change to it reaches nobody;
    # and the architecture page — built from a declared copy — is judged by its SOURCE, which the
    # walk without the config never did (both found in review, 2026-09-23).
    @testset "the working notes reach no reader; the architecture page is re-read from its source" begin
        write(joinpath(root, "docs", "ROADMAP.md"), "# Roadmap\n\nNotes.\n")
        write(joinpath(root, "docs", "ARCHITECTURE.md"), "# Design\n\nThe design.\n")
        write(joinpath(root, "docs", "src", "architecture.md"), "# Design\n\nThe design.\n")
        write(joinpath(root, ".gbg", "config.jl"), """
            Config(package = "Sample", tool = :dev,
                   filesets = Dict(FileSet.RATIONALE => ["docs/ARCHITECTURE.md", "docs/ROADMAP.md"]),
                   copies = ["docs/src/architecture.md" => "docs/ARCHITECTURE.md"])
            """)
        commit_all(root, "notes, a design, and its copy")
        cfg2 = G.ConfigIO.read_config(root)
        @test !haskey(SC.sets_of(cfg2, root, ["docs/ROADMAP.md"]), G.Model.FileSet.RATIONALE)
        sets = SC.sets_of(cfg2, root, ["docs/ARCHITECTURE.md"])
        @test sets[G.Model.FileSet.RATIONALE] == ["docs/ARCHITECTURE.md"]
        @test SC.unit_touched(root, cfg2, unit("architecture/index.html"), sets, String[])
        @test !SC.unit_touched(root, cfg2, home, sets, String[])
    end

    @testset "an edited docstring is every page that collects docstrings, and only those" begin
        root2 = scope_repo(files)
        cfg2 = G.ConfigIO.read_config(root2)
        close_a_run(root2, "2026-09-22-i", :bound)
        c2 = first(SC.base(root2, :documentation_review, :bound, cfg2))
        write(joinpath(root2, "src", "A.jl"), "\"\"\"f, said again\"\"\"\nf(x) = x\n")
        commit_all(root2, "edit a docstring")
        sets = SC.sets_of(cfg2, root2, SC.changed_since(root2, c2), c2)
        added = SC.added_since(root2, c2)
        @test haskey(sets, G.Model.FileSet.DOCSTRINGS)    # the prose did move
        @test SC.unit_touched(root2, cfg2, api, sets, added)        # it has an @docs block
        @test !SC.unit_touched(root2, cfg2, home, sets, added)      # it has none
        @test !SC.unit_touched(root2, cfg2, notation, sets, added)
    end

    @testset "an added sibling is read, having been read by nobody" begin
        root3 = scope_repo(files)
        cfg3 = G.ConfigIO.read_config(root3)
        close_a_run(root3, "2026-09-22-j", :bound)
        c3 = first(SC.base(root3, :documentation_review, :bound, cfg3))
        write(joinpath(root3, "docs", "src", "guide.md"), "# Guide\n\nNew prose.\n")
        commit_all(root3, "add a sibling page")
        sets = SC.sets_of(cfg3, root3, SC.changed_since(root3, c3), c3)
        added = SC.added_since(root3, c3)
        @test "docs/src/guide.md" in added
        @test SC.unit_touched(root3, G.ConfigIO.read_config(root3), unit("guide/index.html"), sets, added)
        @test !SC.unit_touched(root3, G.ConfigIO.read_config(root3), home, sets, added)
    end

    @testset "a page whose source cannot be found is read" begin
        sets = SC.sets_of(cfg, root, String[])
        @test SC.unit_touched(root, cfg, unit("generated/thing/index.html"), sets, String[])
    end
end

# The gate Phase 4d ends on: the five changes the plan names, each producing exactly the launches the
# mapping gives and nothing else. Over one repository, five times, each from the same base — so the sets
# are comparable and a change that reached too far shows up as a launch its neighbour did not make.
@testset "the five changes, and exactly what each reaches" begin
    files = Dict("docs/src/index.md" => "# Home\n\nProse about the package.\n",
                 "docs/src/notation.md" => "# Notation\n\nThe symbols this package binds.\n",
                 "docs/src/api.md" => "# API\n\n```@docs\nf\n```\n",
                 "src/A.jl" => "\"\"\"\n    f(x)\n\nWhat f does.\n\"\"\"\nf(x) = x\n")

    # Every page of the site, named as the builder names them, with the unit each reader would be given.
    units = [(path = "index.html", key = "home", text = ""),
             (path = "notation/index.html", key = "notation", text = ""),
             (path = "api/index.html", key = "api", text = "")]

    # One change, applied to a fresh repository, answered as the run would answer it.
    function after(change!)
        root = scope_repo(files)
        cfg = G.ConfigIO.read_config(root)
        close_a_run(root, "2026-09-22-gate", :bound)
        commit = first(SC.base(root, :documentation_review, :bound, cfg))
        change!(root)
        commit_all(root, "the change")
        changed = SC.changed_since(root, commit)
        sets = SC.sets_of(cfg, root, changed, commit)
        added = SC.added_since(root, commit)
        panel = G.Catalogue.roles_of(:documentation_review, cfg; readers = :bound)
        whole = Set(r.id for r in panel if !(r.site && r.kept_from_code) && SC.reaches(r, sets))
        pages = Set(u.key for u in units if SC.unit_touched(root, cfg, u, sets, added))
        per_page = any(r -> r.site && r.kept_from_code && SC.reaches(r, sets), panel) ? pages : Set{String}()
        return (whole = whole, pages = per_page)
    end

    @testset "an edited docstring" begin
        got = after(r -> write(joinpath(r, "src", "A.jl"), "\"\"\"\n    f(x)\n\nWhat f does, said better.\n\"\"\"\nf(x) = x\n"))
        @test :full in got.whole                       # the whole documentation, with the source
        @test got.pages == Set(["api"])                # only the page that collects docstrings
    end

    @testset "an added sibling" begin
        got = after(r -> write(joinpath(r, "docs", "src", "guide.md"), "# Guide\n\nA new page.\n"))
        @test :full in got.whole
        @test got.pages == Set{String}()               # the three that existed are untouched
    end

    @testset "an edited notation page" begin
        got = after(r -> write(joinpath(r, "docs", "src", "notation.md"), "# Notation\n\nThe symbols, restated.\n"))
        @test :full in got.whole
        @test got.pages == Set(["notation"])
    end

    @testset "an edited hand page" begin
        got = after(r -> write(joinpath(r, "docs", "src", "index.md"), "# Home\n\nOther prose entirely.\n"))
        @test :full in got.whole
        @test got.pages == Set(["home"])
    end

    @testset "an edited function body" begin
        got = after(r -> write(joinpath(r, "src", "A.jl"), "\"\"\"\n    f(x)\n\nWhat f does.\n\"\"\"\nf(x) = x + 0\n"))
        @test :full in got.whole                       # the source is beside it
        @test !(:withheld in got.whole)                # the code is kept from it
        @test got.pages == Set{String}()               # and no built page moved
    end

    @testset "nothing changed reaches nobody at all" begin
        got = after(_ -> nothing)
        @test isempty(got.whole)
        @test isempty(got.pages)
    end
end

# Which BUILT pages a reader is given, and under what name a finding in one is reported. Until
# 2026-09-22 this walk took a directory and no config, so it could honour neither the generated list nor
# the copies — while the file surfaces dropped both in one filter. On GBGPeriodicFields's first real run
# that cost three readers launched against pages that state the rulebook (17 findings nobody should act
# on), and 31 findings citing a rationale document and its build-time copy as two separate places.
@testset "the built-page walk hears what the package declared" begin
    SITE = G.Orchestration.Site

    function built(root, pages)
        for (rel, body) in pages
            dir = joinpath(root, "docs", "build", dirname(rel)); mkpath(dir)
            write(joinpath(root, "docs", "build", rel),
                  "<html><body><nav>side bar</nav><article class=\"content\">" * body * "</article></body></html>")
        end
        return joinpath(root, "docs", "build")
    end

    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".gbg")); mkpath(joinpath(root, "docs", "src"))
    write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
    for f in ("index.md", "tutorial.md", "gbg-rules.md", "architecture.md")
        write(joinpath(root, "docs", "src", f), "# $f\n")
    end
    write(joinpath(root, "docs", "ARCHITECTURE.md"), "# the source\n")
    site = built(root, ["index.html" => "home prose", "tutorial/index.html" => "tutorial prose",
                        "gbg-rules/index.html" => "the rulebook, quoting every banned spelling",
                        "architecture/index.html" => "the architecture prose"])

    plain = G.Model.Config(package = "Sample", tool = :dev)
    declared = G.Model.Config(package = "Sample", tool = :dev,
                              generated = ["docs/src/gbg-rules.md"],
                              copies = ["docs/src/architecture.md" => "docs/ARCHITECTURE.md"])

    @testset "a package that declared nothing is given every page" begin
        keys_ = Set(p.key for p in SITE.pages(site, plain, root))
        @test keys_ == Set(["home", "tutorial", "gbg-rules", "architecture"])
    end

    @testset "a generated page is not handed to a reader" begin
        keys_ = Set(p.key for p in SITE.pages(site, declared, root))
        @test !("gbg-rules" in keys_)
        @test "tutorial" in keys_ && "home" in keys_
    end

    # A copy is kept or dropped by its SOURCE (ruled 2026-09-23): the architecture document is the one
    # rationale document that is a target, so its page is read under the source's name; a copy of the
    # working notes is not read at all. Until that ruling every copy was dropped, and the one document the
    # owner holds to a cold read was the one built page no reader was launched over.
    @testset "a copy's page follows its source: the architecture stays, the working notes go" begin
        @test "architecture" in Set(p.key for p in SITE.pages(site, declared, root))
        write(joinpath(root, "docs", "DECISIONS.md"), "# decided\n")
        write(joinpath(root, "docs", "src", "decisions.md"), "# decided\n")
        mkpath(joinpath(root, "docs", "build", "decisions"))
        write(joinpath(root, "docs", "build", "decisions", "index.html"),
              "<html><body><article class=\"content\">we decided</article></body></html>")
        notes = G.Model.Config(package = "Sample", tool = :dev,
                               generated = ["docs/src/gbg-rules.md"],
                               filesets = Dict(G.Model.FileSet.RATIONALE => ["docs/ARCHITECTURE.md", "docs/DECISIONS.md"]),
                               copies = ["docs/src/architecture.md" => "docs/ARCHITECTURE.md",
                                         "docs/src/decisions.md" => "docs/DECISIONS.md"])
        keys_ = Set(p.key for p in SITE.pages(site, notes, root))
        @test "architecture" in keys_
        @test !("decisions" in keys_)
        @test "tutorial" in keys_ && "home" in keys_ && !("gbg-rules" in keys_)
        rm(joinpath(root, "docs", "build", "decisions"); recursive = true)   # the fixture the tests below share
        rm(joinpath(root, "docs", "src", "decisions.md")); rm(joinpath(root, "docs", "DECISIONS.md"))
    end

    @testset "a finding in a copy is reported under its source" begin
        # Without the config the old answer stands, which is what every other caller still gets.
        @test SITE.source_of(root, "architecture/index.html") == joinpath("docs", "src", "architecture.md")
        # With it, the file the text is actually written in — the one a fix survives in.
        @test SITE.source_of(root, "architecture/index.html"; cfg = declared) == "docs/ARCHITECTURE.md"
        @test SITE.source_of(root, "tutorial/index.html"; cfg = declared) == joinpath("docs", "src", "tutorial.md")
    end
end
