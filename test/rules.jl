# test/rules.jl — every rule's check is shown to match the rule it names (docs/ARCHITECTURE.md §5.2, §7).
#
# A rule carries examples: texts, trees, sources, pages or questions the check must judge a known way.
# This file MATERIALISES each one — a text as a text, a tree as a temporary directory — runs the rule's
# check over it, and requires the locations reported to equal what the example expects, in file and line.
#
# Both directions, per clause. A breaking example alone passes a check that always fires; a complying
# example alone passes a check that never does. So a program check is required to carry, for every clause
# of its statement, one example that breaks it and one that complies and differs from the breaking one as
# little as possible.
#
# The rulebook is empty while the ninety-five rules are converted in batches, so the loop over it is
# vacuous today and `test/conversion.jl` is what says how far that has got. The materialiser itself is
# NOT vacuous: it is exercised below on rules defined here, so it is known to work before sixty rules
# depend on it.
using Test, GBGCodingTools
include("helpers.jl")

const CK = G.Engine.Checks
const MR = G.Model

"""Run one example through its rule's check and return the locations reported."""
# Where a file set's example is written, and what it is called there. A set with no default patterns —
# RATIONALE has none, since a package names its own — is DECLARED in the config the example runs under,
# or the runner would look for it nowhere and the example would pass by finding nothing.
const EXAMPLE_PATH = Dict(MR.FileSet.PAGES => "docs/src/page.md",
                          MR.FileSet.RATIONALE => "docs/RATIONALE.md",
                          MR.FileSet.LITERATE => "examples/example.jl",
                          MR.FileSet.DOCSTRINGS => "src/Example.jl",
                          MR.FileSet.CODE => "src/Example.jl",
                          MR.FileSet.TESTS => "test/example.jl")

function materialise(rule, example)
    if example isa MR.TextExample
        dir = mktempdir(; cleanup = true)
        path = get(EXAMPLE_PATH, example.fileset, "src/Example.jl")
        mkpath(joinpath(dir, dirname(path)))
        write(joinpath(dir, path), example.text)
        cfg = MR.Config(package = "Example", tool = :dev,
                        filesets = Dict(example.fileset => [path]))
        r = MR.Rule(; id = rule.id, statement = rule.statement, filesets = [example.fileset], check = rule.check)
        return CK.run_rule(r, cfg, dir)
    elseif example isa MR.ModuleExample
        # A rule that reads the LOADED package is shown on source loaded into a fresh module: the same
        # text on disk, so the check sees both halves it compares.
        dir = mktempdir(; cleanup = true)
        mkpath(joinpath(dir, "src"))
        write(joinpath(dir, "src", "Example.jl"), example.source)
        holder = Module(:ExampleHolder)
        Base.include_string(holder, "module Holder\n" * example.source * "\nend")
        # The module is named in the source; fetching it needs `invokelatest`, since it was defined after
        # this method's world age and is otherwise invisible here.
        name = Symbol(match(r"^\s*module\s+([A-Za-z_][A-Za-z0-9_]*)"m, example.source).captures[1])
        inner = Base.invokelatest(getfield, holder, :Holder)
        pkg = Base.invokelatest(getfield, inner, name)
        cfg = MR.Config(package = "Example", tool = :dev,
                        filesets = Dict(MR.FileSet.CODE => ["src/Example.jl"]))
        # `invokelatest`: the module was defined a moment ago, and a check reading its names cannot see
        # them from this method's world age.
        return Base.invokelatest(CK.run_rule, rule, cfg, dir; pkg)
    elseif example isa MR.SiteExample
        # A rule that reads the BUILT site is shown on built pages: the example's pages are the rendered
        # HTML a reader meets, which is what the check is about. Running Documenter to produce them would
        # test Documenter, not the rule.
        dir = mktempdir(; cleanup = true)
        for (path, content) in example.pages
            mkpath(joinpath(dir, dirname(path)))
            write(joinpath(dir, path), content)
        end
        cfg = MR.Config(package = "Example", tool = :dev)
        return CK.run_rule(rule, cfg, dir; site = dir)
    elseif example isa MR.TreeExample
        cfg = MR.Config(package = "Example", tool = :dev)
        dir = mktempdir(; cleanup = true)
        for (path, content) in example.files
            mkpath(joinpath(dir, dirname(path)))
            write(joinpath(dir, path), content)
        end
        return CK.run_rule(rule, cfg, dir)
    end
    return nothing                      # module, site and question examples arrive with the checks that need them
end

"""The clauses an example set covers, and whether each has both a breaking and a complying example."""
function clause_coverage(rule)
    clauses = unique(e.clause for e in rule.examples)
    return Dict(c => (any(e -> e.clause == c && !isempty(e.expect), rule.examples),
                      any(e -> e.clause == c && isempty(e.expect), rule.examples)) for c in clauses)
end

# ── the materialiser, exercised on rules written here ────────────────────────────────────────────────

lines_with(needle) = (text, _) -> [MR.Location(; file = "", line = i, text = strip(String(l)))
                                   for (i, l) in pairs(split(text, '\n')) if occursin(needle, l)]

const NO_TODO = MR.Rule(
    id = :NO_TODO,
    statement = "No TODO is left in a shipped page.",
    filesets = [MR.FileSet.PAGES],
    check = MR.ProgramCheck(MR.Input.SOURCE_TEXT, lines_with("TODO"), false),
    examples = [
        MR.TextExample(MR.FileSet.PAGES, "# A page\n\nTODO: write this.\n",
                       [MR.Location(; file = "docs/src/page.md", line = 3)], "no TODO"),
        MR.TextExample(MR.FileSet.PAGES, "# A page\n\nWritten.\n", MR.Location[], "no TODO"),
    ])

const NO_BARE_URL = MR.Rule(
    id = :NO_BARE_URL,
    statement = "A link is written as Markdown, never as a bare URL.",
    filesets = [MR.FileSet.PAGES],
    check = MR.ProgramCheck(MR.Input.SOURCE_TEXT, lines_with("https://"), false),
    examples = [
        MR.TextExample(MR.FileSet.PAGES, "# A page\n\nSee https://example.com for more.\n",
                       [MR.Location(; file = "docs/src/page.md", line = 3)], "written as Markdown"),
        MR.TextExample(MR.FileSet.PAGES, "# A page\n\nSee [the site](x) for more.\n", MR.Location[],
                       "written as Markdown"),
    ])

# A rule never reads a file the package's own `.gitignore` excludes: that file is build output, and a
# finding in it names a line the next build deletes. GBGPeriodicFields copies four rationale documents
# into `docs/src/` and renders a Literate example beside them, all ignored and all globbed by the default
# pages pattern — 264 findings against 108 real ones, and a build that would have linted its own output.
@testset "an ignored file is never read" begin
    dir = mktempdir(; cleanup = true)
    mkpath(joinpath(dir, "docs", "src", "examples"))
    for f in ("index.md", "generated.md"); write(joinpath(dir, "docs", "src", f), "# A page\n\nTODO: x\n"); end
    write(joinpath(dir, "docs", "src", "examples", "rendered.md"), "# A page\n\nTODO: x\n")
    cfg = MR.Config(package = "P", tool = :dev, filesets = Dict(MR.FileSet.PAGES => ["docs/src/**/*.md"]))
    @test length(CK.files(cfg, dir, MR.FileSet.PAGES)) == 3          # nothing ignored yet
    write(joinpath(dir, ".gitignore"), "docs/src/generated.md\ndocs/src/examples/\n")
    @test CK.files(cfg, dir, MR.FileSet.PAGES) == ["docs/src/index.md"]

    # a nested .gitignore decides its own directory, and a deeper rule overrides a shallower one
    write(joinpath(dir, ".gitignore"), "*.md\n")
    @test isempty(CK.files(cfg, dir, MR.FileSet.PAGES))
    write(joinpath(dir, "docs", "src", ".gitignore"), "!index.md\n")
    @test CK.files(cfg, dir, MR.FileSet.PAGES) == ["docs/src/index.md"]

    # anchoring is read before the leading slash is stripped, or a negation leaks to every depth
    rules = G.Texts.gitignore_rules_of("Manifest.toml\n!/Manifest.toml\n")
    hit(f) = (h = false; for (rx, neg) in rules; occursin(rx, f) && (h = !neg); end; h)
    @test !hit("Manifest.toml") && hit("docs/Manifest.toml")
end

# Four shapes a real package's signatures take that a naive reader gets wrong, each one a finding that
# GBGPeriodicFields would have been asked to fix in prose that was already correct.
@testset "a signature is read whole" begin
    T = G.Texts
    # several displayed arities: the widest is what a reader meets
    doc = "    f(a, b)\n    f(a, b, c, d)\n\nProse.\n"
    @test length(T.signature_lines(doc)) == 2
    @test T.arity(T.argument_list(last(T.signature_lines(doc)))) == (4, 0)
    # a signature wrapped across lines is one signature
    @test T.signature_lines("    f(a,\n      b, c)\n\nProse.\n") == ["f(a, b, c)"]
    # a comma inside a type is not a separator
    @test T.arity("multipliers::Mult, offset::NTuple{3, Real}") == (2, 0)
    @test T.arity("x::AbstractArray{Complex{T}, 3}, y::Grid{T}; opt = 1") == (2, 1)
    # an unnamed typed positional is an argument the caller passes
    @test T.arity("grid::Grid3D, layout::Layout, ::Val{R}") == (3, 0)
    @test length(first(T.parameters("grid::Grid3D, layout::Layout, ::Val{R}"))) == 2   # but it has no NAME
    # only the leading block counts: an indented line further down is an example
    @test T.signature_lines("    f(a)\n\nProse.\n\n    g(b, c, d)\n") == ["f(a)"]
end

# Three shapes real consumers write that the rules misread, each reported by the session wiring one.
@testset "what a real consumer's source looks like" begin
    # an inner constructor's arguments are spelled like fields and are not fields
    src = split("""
    struct S
      a::Int
      b::Int

      function S(a::Int,
          b::Int)
        new(a, b)
      end
    end
    """, '\n')
    @test G.Catalogue.Docstrings.struct_fields(src, "S") == ["a", "b"]

    # a site's trailing slash is optional in a link to it
    dir = mktempdir(; cleanup = true); mkpath(joinpath(dir, "docs", "src"))
    site = last(first(p for p in G.Catalogue.Pages.SIBLING_SITES.default if first(p) != "P"))
    other = first(first(p for p in G.Catalogue.Pages.SIBLING_SITES.default if first(p) != "P"))
    cfg = MR.Config(package = "P", tool = :dev, filesets = Dict(MR.FileSet.PAGES => ["docs/src/page.md"]))
    r = G.Catalogue.RULES[findfirst(x -> String(x.id) == "RULE.DOC.SIBLING_LINK", G.Catalogue.RULES)]
    write(joinpath(dir, "docs", "src", "page.md"), "# A page\n\nBuilt on [`$other`]($(rstrip(site, '/'))), which helps.\n")
    @test isempty(CK.run_rule(r, cfg, dir))                      # no trailing slash: still a link
    write(joinpath(dir, "docs", "src", "page.md"), "# A page\n\nBuilt on [`$other`]($site), which helps.\n")
    @test isempty(CK.run_rule(r, cfg, dir))                      # with one: still a link
    write(joinpath(dir, "docs", "src", "page.md"), "# A page\n\nBuilt on `$other`, which helps.\n")
    @test length(CK.run_rule(r, cfg, dir)) == 1                  # bare: still a finding
end

# The ratchet must be able to CLOSE: a rule that only reads a baseline leaves a legitimate finding with
# no remedy, which is why a consumer kept its own prose lint after wiring.
@testset "a ratchet a package can close" begin
    dir = mktempdir(; cleanup = true)
    mkpath(joinpath(dir, ".gbg")); mkpath(joinpath(dir, "docs", "src"))
    write(joinpath(dir, ".gbg", "config.jl"), """Config(package = "P", tool = :dev)""")
    page = joinpath(dir, "docs", "src", "page.md")
    write(page, "# A page\n\n" * join(fill("word", 130), " ") * "\n")
    cfg = G.ConfigIO.read_config(dir)
    r = G.Catalogue.RULES[findfirst(x -> String(x.id) == "RULE.DOC.SHAPE", G.Catalogue.RULES)]
    @test !isempty(CK.run_rule(r, cfg, dir))                      # over the cap, and no baseline
    @test G.Check.rebaseline(dir; io = devnull) == 0
    @test isempty(CK.run_rule(r, cfg, dir))                       # recorded, so it is the ceiling now
    write(page, "# A page\n\n" * join(fill("word", 160), " ") * "\n")
    @test !isempty(CK.run_rule(r, cfg, dir))                      # and it may not rise above it
end

# A unit whose name repeats is a DIFFERENT unit: one document restarting its numbering under a later
# heading had 28 of 144 entries tracked by nothing, in both this rule and the lint it was compared with.
@testset "two units of one name are two units" begin
    dir = mktempdir(; cleanup = true); mkpath(joinpath(dir, "docs", "src"))
    write(joinpath(dir, "docs", "src", "page.md"),
          "# A page\n\n## First\n\n1. one\n\n## Second\n\n1. another\n")
    u = G.Catalogue.Shape.units(dir, ["docs/src/page.md"])
    ks = collect(keys(u))
    @test count(k -> occursin("item 1", k), ks) == 2
    # Keyed under the HEADING, not by position: inserting an item earlier must not re-point the rows
    # that follow it, which a positional suffix would.
    @test any(k -> occursin("First / item 1", k), ks)
    @test any(k -> occursin("Second / item 1", k), ks)
end

@testset "the rulebook" begin
    @testset "the materialiser judges an example as the rule says" begin
        for rule in (NO_TODO, NO_BARE_URL), example in rule.examples
            got = materialise(rule, example)
            @test got !== nothing
            @test [(l.file, l.line) for l in got] == [(l.file, l.line) for l in example.expect]
        end
    end

    @testset "it would catch a check that always fires, and one that never does" begin
        always = MR.Rule(; id = :ALWAYS, statement = "x", filesets = [MR.FileSet.PAGES],
                         check = MR.ProgramCheck(MR.Input.SOURCE_TEXT, (t, _) -> [MR.Location(; file = "", line = 1)], false),
                         examples = NO_TODO.examples)
        never = MR.Rule(; id = :NEVER, statement = "x", filesets = [MR.FileSet.PAGES],
                        check = MR.ProgramCheck(MR.Input.SOURCE_TEXT, (t, _) -> MR.Location[], false),
                        examples = NO_TODO.examples)
        @test [(l.file, l.line) for l in materialise(always, always.examples[2])] != []   # the complying one fires
        @test isempty(materialise(never, never.examples[1]))                              # the breaking one does not
    end

    @testset "a file tree example is materialised as a tree" begin
        rule = MR.Rule(; id = :README_EXISTS, statement = "A package has a README.",
                       filesets = [MR.FileSet.PAGES],
                       check = MR.ProgramCheck(MR.Input.FILE_TREE,
                                               (root, _) -> isfile(joinpath(root, "README.md")) ? MR.Location[] :
                                                            [MR.Location(; file = "README.md", line = 0)], false))
        breaking = MR.TreeExample(["src/P.jl" => "module P end\n"], [MR.Location(; file = "README.md", line = 0)], "has one")
        complying = MR.TreeExample(["src/P.jl" => "module P end\n", "README.md" => "# P\n"], MR.Location[], "has one")
        @test length(materialise(rule, breaking)) == 1
        @test isempty(materialise(rule, complying))
    end

    # What a package turns off, and for which files — the mechanism that replaces the ledger.
    @testset "a switch turns a rule off, wholly or for named files" begin
        dir = mktempdir(; cleanup = true)
        mkpath(joinpath(dir, "docs", "src"))
        write(joinpath(dir, "docs", "src", "page.md"), "# A page\n\nTODO: write this.\n")
        write(joinpath(dir, "docs", "src", "other.md"), "# Another\n\nTODO: this one too.\n")
        base = MR.Config(package = "P", tool = :dev,
                         filesets = Dict(MR.FileSet.PAGES => ["docs/src/page.md", "docs/src/other.md"]))
        @test length(CK.run_rule(NO_TODO, base, dir)) == 2                      # on, both files

        off = MR.Config(package = "P", tool = :dev, filesets = base.filesets,
                        switches = [MR.Switch(target = NO_TODO.id, reason = "this package ships no pages at all")])
        @test isempty(CK.run_rule(NO_TODO, off, dir))                           # off for the package

        partly = MR.Config(package = "P", tool = :dev, filesets = base.filesets,
                           switches = [MR.Switch(target = NO_TODO.id, reason = "that page is a worked example",
                                                 files = ["docs/src/other.md"])])
        hits = CK.run_rule(NO_TODO, partly, dir)
        @test length(hits) == 1 && first(hits).file == "docs/src/page.md"        # off for one file only
    end

    # ── and then the rulebook itself ─────────────────────────────────────────────────────────────────
    @testset "every converted rule is shown to match its check" begin
        for rule in G.Catalogue.RULES
            @testset "$(rule.id)" begin
                if rule.check isa MR.ProgramCheck
                    @test !isempty(rule.examples)                       # a program check without examples shows nothing
                    for (clause, (breaks, complies)) in clause_coverage(rule)
                        @test breaks                                     # one that breaks this clause
                        @test complies                                   # and one that does not
                    end
                    for example in rule.examples
                        got = materialise(rule, example)
                        got === nothing && continue
                        @test [(l.file, l.line) for l in got] == [(l.file, l.line) for l in example.expect]
                    end
                elseif rule.check === nothing
                    @test !isempty(rule.unchecked_reason)                # a rule nobody checks says why
                end
            end
        end
    end
    # A rule whose file list is the package's, not the file sets'. `RULE.DOC.AI_BANNER` reads `rationale`
    # and `literate` by default; which pages a package requires the banner on is its own question and has
    # nothing to do with which pages are rationale. Expressed as a file set it could only be answered by
    # widening one that other rules also read.
    #
    # This is the defect GBGPeriodicFields hit on 2026-09-18: a page of theirs carrying a reworded banner
    # passed, not because the comparison is loose — it is verbatim — but because the rule never opened the
    # file. A check that does not reach the page it is required to judge has not run, and reported clean.
    @testset "a package names the files one rule reads" begin
        P = GBGCodingTools.Catalogue.Pages
        root = mktempdir(; cleanup = true)
        mkpath(joinpath(root, "docs", "src"))
        write(joinpath(root, "docs", "src", "ok.md"), P.BANNER * "\n\n# Page\n\nProse.\n")
        write(joinpath(root, "docs", "src", "drifted.md"),
              replace(P.BANNER, "Written by AI, not regularly reviewed" => "Notes") * "\n\n# Page\n\nProse.\n")

        # The default: neither page is rationale or literate, so the rule reads nothing and says nothing.
        plain = MR.Config(package = "Sample", tool = :dev)
        @test isempty(G.Engine.Checks.reading(P.AI_BANNER, plain, root))
        @test isempty(G.Engine.Checks.run_rule(P.AI_BANNER, plain, root))

        # Named by the package, the rule reads both and reports the drifted one AS drift, which is a
        # different repair from a missing banner and used to be reported as one: the drift branch tested
        # for `Written by AI`, the title's wording, while the body says `written by AI`.
        named = MR.Config(package = "Sample", tool = :dev,
                          settings = [MR.Setting(rule = P.AI_BANNER.id, name = :banner_pages,
                                                 value = ["docs/src/**/*.md"])])
        @test length(G.Engine.Checks.reading(P.AI_BANNER, named, root)) == 2
        found = G.Engine.Checks.run_rule(P.AI_BANNER, named, root)
        @test length(found) == 1
        @test found[1].file == "docs/src/drifted.md"
        @test occursin("drifted", found[1].text)

        # A setting naming another rule's parameter is not this rule's file list.
        other = MR.Config(package = "Sample", tool = :dev,
                          settings = [MR.Setting(rule = Symbol("RULE.DOC.SIBLING_LINK"), name = :banner_pages,
                                                 value = ["docs/src/**/*.md"])])
        @test isempty(G.Engine.Checks.reading(P.AI_BANNER, other, root))
    end
end
