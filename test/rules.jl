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
    if example isa MR.TextExample && rule.check isa MR.ProgramCheck && rule.check.input === MR.Input.PUBLICATION
        # A publication rule is run by `gbg leak` alone, which hands its check each text it reads; so is
        # it here, on a config approving one address and keeping one word private.
        cfg = MR.Config(package = "Example", tool = :dev, leak_emails = ["owner@mailbox.zz"], leak_terms = ["Examplehost"])
        return rule.check.run(example.text, cfg)
    elseif example isa MR.TextExample
        dir = mktempdir(; cleanup = true)
        path = get(EXAMPLE_PATH, example.fileset, "src/Example.jl")
        mkpath(joinpath(dir, dirname(path)))
        write(joinpath(dir, path), example.text)
        cfg = MR.Config(package = "Example", tool = :dev,
                        filesets = Dict(example.fileset => [path]), settings = example.settings)
        r = MR.Rule(; id = rule.id, statement = rule.statement, filesets = [example.fileset], check = rule.check)
        # A check that reaches the network is shown on a CANNED resolver: the examples say what each
        # link would answer, so the rule's judgement is tested and the network is never touched here.
        rule.check isa MR.ProgramCheck && rule.check.network || return CK.run_rule(r, cfg, dir)
        was = G.Catalogue.Citations.RESOLVER[]
        G.Catalogue.Citations.RESOLVER[] = url ->
            occursin("10.1017/CBO9780511840531", url) ? (200, "Turbulent Flows") :
            occursin("10.1098/rspa.1991.0075", url) ? (200, "The local structure of turbulence in incompressible viscous fluid for very large Reynolds numbers") :
            occursin("10.1016/j.jcp.2009.10.046", url) ? (200, "Implementation of high order spline interpolations for tracking test particles in discretized fields") :
            # answers only when asked for whole: a DOI cut at its first `)` is a 404
            endswith(url, "10.1016/0021-9991(84)90019-3") ? (200, "A method") :
            (404, "")
        try
            return CK.run_rule(r, cfg, dir; network = true)
        finally
            G.Catalogue.Citations.RESOLVER[] = was
        end
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
    elseif example isa MR.QuestionExample
        # A question is judged where it is PUT, so there is no tree to materialise: the check reads the
        # value itself. `Engine.Questions.check` is what the runner uses, and using it here is what makes
        # these examples a test of the path a real question takes rather than of the function alone.
        cfg = MR.Config(package = "Example", tool = :dev)
        return [loc for (id, loc) in G.Engine.Questions.check(example.question, cfg) if id == rule.id]
    elseif example isa MR.TreeExample
        cfg = MR.Config(package = "Example", tool = :dev)
        dir = mktempdir(; cleanup = true)
        for (path, content) in example.files
            mkpath(joinpath(dir, dirname(path)))
            write(joinpath(dir, path), content)
        end
        return CK.run_rule(rule, cfg, dir)
    elseif example isa MR.HistoryExample
        # A rule the end-of-turn hook decides is shown on a repository its script builds, run through
        # the check the way `gbg check` runs it — which is the hook's own lines.
        dir = mktempdir(; cleanup = true)
        run(pipeline(setenv(`bash -c $(example.script)`; dir = dir); stdout = devnull, stderr = devnull))
        cfg = MR.Config(package = "Example", tool = :dev)
        return CK.run_rule(rule, cfg, dir; history = true)
    end
    return nothing                      # an example kind with no materialiser yet
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

    # a file under an excluded directory stays excluded whatever a deeper `.gitignore` says, as git
    # decides it: a nested clone's `!/Manifest.toml` re-included its manifest into this package's tree
    mkpath(joinpath(dir, "inspiration", "Other"))
    write(joinpath(dir, ".gitignore"), "inspiration/\n")
    write(joinpath(dir, "inspiration", "Other", ".gitignore"), "Manifest.toml\n!/Manifest.toml\n")
    write(joinpath(dir, "inspiration", "Other", "Manifest.toml"), "# v2\n")
    @test G.Texts.ignored(dir)("inspiration/Other/Manifest.toml")
    @test G.Texts.ignored(dir)("inspiration/Other/docs/Manifest.toml")

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
    src = """
    struct S
      a::Int
      b::Int

      function S(a::Int,
          b::Int)
        new(a, b)
      end
    end
    """
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

# Found in the review of 2026-09-26, each a check that read too little or matched too much; the rule's
# own examples carry most of them, and these are the ones an example cannot show.
@testset "what the review of 2026-09-26 found" begin
    rule(id) = G.Catalogue.RULES[findfirst(x -> String(x.id) == id, G.Catalogue.RULES)]
    S = G.Catalogue.Shape

    # The close re-records growth within the allowance and nothing past it.
    dir = mktempdir(; cleanup = true); mkpath(joinpath(dir, "docs", "src"))
    page = joinpath(dir, "docs", "src", "p.md")
    write(page, "# P\n\n## Notes\n\none two three\n")
    cfg = MR.Config(package = "P", tool = :dev)
    S.write_baseline(dir, cfg)
    write(page, "# P\n\n## Notes\n\n" * join(fill("word", 500), " ") * "\n")
    @test isempty(S.record_grown(dir, cfg))                                # 3 → 500 is past the allowance
    @test any(l -> occursin("GREW", l.text), S.prose_shape(dir, cfg))        # and the build still refuses it
    write(page, "# P\n\n## Notes\n\n" * join(fill("word", 8), " ") * "\n")
    @test length(S.record_grown(dir, cfg)) == 1                            # 3 → 8 is within it
    @test isempty(S.prose_shape(dir, cfg))

    # A unit's key does not move when a section of the same name is inserted above it: the two are
    # reported as sharing a name, and no row is silently re-pointed.
    write(page, "# P\n\n## Notes\n\ntwo words\n\n## Other\n\nx\n")
    S.write_baseline(dir, cfg)
    before = collect(keys(S.units(dir, ["docs/src/p.md"])))
    write(page, "# P\n\n## Notes\n\nnew\n\n## Notes\n\ntwo words\n\n## Other\n\nx\n")
    @test !any(k -> occursin("(2)", k), keys(S.units(dir, ["docs/src/p.md"])))
    @test any(l -> occursin("share this name", l.text), S.prose_shape(dir, cfg))
    # a long heading keeps each item's number, which cutting the joined key lost
    long = "A heading long enough that sixty characters end before the item number"
    write(page, "# P\n\n## $long\n\n1. one\n\n2. two\n")
    ks = collect(keys(S.units(dir, ["docs/src/p.md"])))
    @test any(endswith("/ item 1"), ks) && any(endswith("/ item 2"), ks)
    # two files of one basename are two files
    mkpath(joinpath(dir, "docs", "src", "a")); mkpath(joinpath(dir, "docs", "src", "b"))
    write(joinpath(dir, "docs", "src", "a", "index.md"), "# I\n\nOne.\n")
    write(joinpath(dir, "docs", "src", "b", "index.md"), "# I\n\nTwo.\n")
    @test length(S.units(dir, ["docs/src/a/index.md", "docs/src/b/index.md"])) == 2

    # The rules that read the loaded package and the docstring set resolve the config's GLOBS, and a
    # default config names no file at all.
    dir = mktempdir(; cleanup = true); mkpath(joinpath(dir, "src", "Public"))
    write(joinpath(dir, "src", "Public", "a.jl"), "\"\"\"\n    measure(u; tol = 1e-6) -> Float64\n\nThe mean.\n\"\"\"\nmeasure(u; atol = 1e-6) = u\n")
    for c in (MR.Config(package = "P", tool = :dev),
              MR.Config(package = "P", tool = :dev, filesets = Dict(MR.FileSet.CODE => ["src/**/*.jl"])))
        shown, _, _, where_ = G.Catalogue.Modules.displayed_signatures(dir, c)
        @test haskey(shown, (:measure, "src/Public/a.jl")) && where_[(:measure, "src/Public/a.jl")] == 1
    end
    write(joinpath(dir, "src", "other.jl"), "x = 1\n")
    globbed = MR.Config(package = "P", tool = :dev, filesets = Dict(MR.FileSet.DOCSTRINGS => ["src/Public/**/*.jl"]))
    @test G.Catalogue.Citations.sources(dir, globbed) == ["src/Public/a.jl"]

    # A setting is its rule's alone: one declared under another rule's id redirects nothing.
    q = MR.Question(id = "q", decision = "Should the C++ binding stay?")
    own = MR.Config(package = "P", tool = :dev, settings = [MR.Setting(rule = Symbol("RULE.ASK.NO_HOUSE_TERMS"), name = :house_terms, value = ["C++", "f(x)"])])
    @test length(G.Catalogue.Questions.no_house_terms(q, own)) == 1        # a literal, never a pattern
    @test isempty(G.Catalogue.Questions.no_house_terms(MR.Question(id = "q", decision = "Should fx stay?"), own))
    stray = MR.Config(package = "P", tool = :dev, settings = [MR.Setting(rule = Symbol("RULE.DOC.SIBLING_LINK"), name = :house_terms, value = ["C++"])])
    @test isempty(G.Catalogue.Questions.no_house_terms(q, stray))

    # A history rule that cannot run says so, rather than reporting clean.
    dir = mktempdir(; cleanup = true)
    got = withenv("PATH" => "") do
        rule("RULE.GIT.PUSH").check.run(dir, MR.Config(package = "P", tool = :dev))
    end
    @test length(got) == 1 && startswith(got[1].text, "cannot evaluate: ")

    # Documenter 1.x's markup: a docstring's binding is read from the summary, not from the first link.
    dir = mktempdir(; cleanup = true)
    Si = G.Catalogue.Site
    write(joinpath(dir, "a.html"), Si.page_of(Si.docstring_html("M.f", "See [g](#g).")))
    @test [b.id for b in Si.page_bindings(joinpath(dir, "a.html"))] == ["M.f"]
end

# Found in the verification of the review's fixes (2026-09-27): each a fix that broke what it touched.
@testset "what the verification of 2026-09-27 found" begin
    S = G.Catalogue.Shape

    # One function documented in two files is held to the union of what both display.
    dir = mktempdir(; cleanup = true); mkpath(joinpath(dir, "src"))
    a = "\"\"\"\n    f(x; a = 1)\n\nOne.\n\"\"\"\nf(x; a = 1) = x\n"
    b = "\"\"\"\n    f(x, y; b = 2)\n\nTwo.\n\"\"\"\nf(x, y; b = 2) = x\n"
    write(joinpath(dir, "src", "Example.jl"), a); write(joinpath(dir, "src", "b.jl"), b)
    holder = Module(:SigHolder)
    Base.include_string(holder, "module Example\nexport f, g\ng() = 1\nend", "Example.jl")
    ex = Base.invokelatest(getfield, holder, :Example)
    Base.include_string(ex, a, joinpath(dir, "src", "Example.jl"))
    Base.include_string(ex, b, joinpath(dir, "src", "b.jl"))
    cfg = MR.Config(package = "Example", tool = :dev,
                    filesets = Dict(MR.FileSet.CODE => ["src/Example.jl", "src/b.jl"]))
    fid = G.Catalogue.Modules.signature_fidelity
    @test isempty(Base.invokelatest(fid, (pkg = ex, root = dir), cfg))
    # and a keyword one file shows wrongly is reported at that file's docstring
    write(joinpath(dir, "src", "b.jl"), replace(b, "    f(x, y; b = 2)" => "    f(x, y; c = 2)"))
    got = Base.invokelatest(fid, (pkg = ex, root = dir), cfg)
    @test any(l -> l.file == "src/b.jl" && l.line == 1 && occursin("`c`", l.text), got)
    @test any(l -> l.file == "src/Example.jl" && occursin("`b` appears in no", l.text), got)

    # The site build a run starts grants the allowance through its environment; nothing else does.
    dir = mktempdir(; cleanup = true); mkpath(joinpath(dir, "docs", "src"))
    page = joinpath(dir, "docs", "src", "p.md")
    write(page, "# P\n\n## Notes\n\none two three\n")
    pcfg = MR.Config(package = "P", tool = :dev)
    S.write_baseline(dir, pcfg)
    write(page, "# P\n\n## Notes\n\n" * join(fill("word", 8), " ") * "\n")
    @test withenv(() -> !isempty(S.prose_shape(dir, pcfg)), S.RUN_ALLOWANCE => nothing)
    @test withenv(() -> isempty(S.prose_shape(dir, pcfg)), S.RUN_ALLOWANCE => "1")
    write(joinpath(dir, "docs", "make.jl"),
          "mkpath(\"docs/build\"); write(\"docs/build/flag\", get(ENV, \"$(S.RUN_ALLOWANCE)\", \"\"))\n")
    @test withenv(() -> G.Orchestration.Site.build_with_make(dir, pcfg; io = devnull), S.RUN_ALLOWANCE => nothing) !== nothing
    @test read(joinpath(dir, "docs", "build", "flag"), String) == "1"

    # A row recorded under the key a unit had before the keys changed still holds it, and a rewrite
    # records it under the new key.
    dir = mktempdir(; cleanup = true); mkpath(joinpath(dir, "docs", "src"))
    long = "A heading long enough that sixty characters end before the item number"
    write(joinpath(dir, "docs", "src", "p.md"),
          "# P\n\n## $long\n\nIntro.\n\n1. " * join(fill("word", 130), " ") * "\n")
    old = "p.md § " * first(long, 60)
    write(joinpath(dir, "docs", "prose_shape.csv"),
          "unit,words,longest_paragraph,admonitions\n\"$old\",1,1,0\n\"$old (2)\",200,200,0\n")
    found = S.prose_shape(dir, pcfg)
    @test !any(l -> occursin("item 1", l.text), found)                  # held by its `(2)` row
    @test !any(l -> occursin("DROPPED", l), S.changes(dir, pcfg))
    S.write_baseline(dir, pcfg)
    @test any(k -> endswith(k, "/ item 1"), keys(S.baseline(dir)))

    # Two docstrings of one file sharing a key are two units, and neither is told to take a heading.
    dir = mktempdir(; cleanup = true); mkpath(joinpath(dir, "src"))
    sig = "    measure(u::AbstractArray{Float64,3}, grid::Grid; tolerance_absolute = 1e-6)"
    write(joinpath(dir, "src", "M.jl"), "\"\"\"\n$sig\n\nOne.\n\"\"\"\nf(x) = 1\n\n\"\"\"\n$sig\n\nTwo.\n\"\"\"\nf(x, y) = 1\n")
    S.write_baseline(dir, pcfg)
    @test length(S.baseline(dir)) == 2
    @test !any(l -> occursin("heading", l.text), S.prose_shape(dir, pcfg))

    # `@doc raw"""` opens a docstring on the macro's line.
    src = "x = 1\n@doc raw\"\"\"\n    f(x)\n\nBody.\n\"\"\"\nf(x) = x\n"
    d = only(G.Texts.docstrings_of(src))
    @test G.Catalogue.Docstrings.body_line(src, d) == 3
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

        # A deferral holds the rule off the same way — owed, not answered — and never fails a build.
        owed = MR.Config(package = "P", tool = :dev, filesets = base.filesets,
                         deferrals = [MR.Deferral(rule = NO_TODO.id, until = "the pages are rewritten")])
        @test isempty(CK.run_rule(NO_TODO, owed, dir))
        @test !CK.applies(owed, NO_TODO.id)
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

# a rebaseline names every ceiling it raises before it writes (2026-09-12-audit-changes-01); stood in
# test/scans.jl until Phase 5
@testset "a prose-shape rebaseline lists what it raises" begin
    root = fixture_copy("rebaseline")
    G.Catalogue.Shape.write_baseline(root, G.ConfigIO.read_config(root))
    @test isempty(G.Catalogue.Shape.changes(root, G.ConfigIO.read_config(root)))
    page = joinpath(root, "docs", "src", "notation.md")
    write(page, read(page, String) * "\n" * "one more word "^10 * "\n\n## A section no baseline row has\n\nnew text here\n")
    ch = G.Catalogue.Shape.changes(root, G.ConfigIO.read_config(root))
    @test any(l -> startswith(l, "RAISED") && occursin("notation.md", l), ch)
    @test any(l -> startswith(l, "NEW") && occursin("A section no baseline row has", l), ch)
    G.Catalogue.Shape.write_baseline(root, G.ConfigIO.read_config(root))
    @test isempty(G.Catalogue.Shape.changes(root, G.ConfigIO.read_config(root)))
end

# A docstring's prose line that begins "module for …" is not the module's declaration: read as one, it
# named the module `for`, and every function of the real module was reported as foreign to it
# (found upgrading GBGPeriodicFields, 2026-09-27).
@testset "the module a file declares is its declaration line, not prose" begin
    src = """
    \"\"\"
        Algebra

    The operations of the algebra; see the point
    module for what the point layer provides. Uses `helper`.
    \"\"\"
    module Algebra
    helper(x) = x
    end
    """
    m = match(r"^(?:bare)?module\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:#.*)?$"m, src)
    @test m !== nothing && m.captures[1] == "Algebra"
    body = read(joinpath(TOOL, "src", "Rules", "modules.jl"), String)
    @test occursin("(?:#.*)?\$\"m, src)", body)            # the rule reads it the same way
end

# A standard-library generic a package module extends and re-exports is owned by no package module, so
# a sibling's docstring mentioning it is not reported (found upgrading GBGPeriodicFields, 2026-09-27).
@testset "an extended Base generic is nobody's in the package" begin
    holder = Module(:XlinkHolder)
    Base.include_string(holder, """
    module P
    module A
    import Base: length                            # a standard generic, as LinearAlgebra's `norm` is in PF
    export length, mine
    struct T end
    length(::T) = 0
    mine(x) = x
    end
    using .A
    export length, mine
    end
    """)
    P = Base.invokelatest(getfield, holder, :P)
    own = Base.invokelatest(G.Catalogue.Modules.owners, P, MR.Config(package = "P", tool = :dev))
    @test !haskey(own, "length")                   # Base's, extended here
    @test get(own, "mine", nothing) === :A         # the package's own function keeps its owner
end

# A signature block reads across the blank lines between its signatures (GBGPeriodicFields' request of
# 2026-09-27): a keyword shown only in a later signature was reported missing, and a stale name there
# was never compared.
@testset "a signature block reads past a blank line" begin
    T = G.Texts
    @test T.signature_lines("    f(a)\n\n    f(a, b; k = 1)\n\nProse.\n") == ["f(a)", "f(a, b; k = 1)"]
    @test T.signature_lines("    f(a)\n\nProse.\n\n    g(b, c, d)\n") == ["f(a)"]       # an example below prose is not one
    dir = mktempdir(; cleanup = true); mkpath(joinpath(dir, "src"))
    write(joinpath(dir, "src", "Example.jl"), """
    module Example
    \"\"\"
        make(n)

        make(n, m; origin = 0)

    Makes one.
    \"\"\"
    make(n) = n
    make(n, m; origin = 0) = n + m + origin
    end
    """)
    holder = Module(:SigHolder)
    Base.include_string(holder, read(joinpath(dir, "src", "Example.jl"), String))
    pkg = Base.invokelatest(getfield, holder, :Example)
    cfg = MR.Config(package = "Example", tool = :dev, filesets = Dict(MR.FileSet.CODE => ["src/Example.jl"]))
    r = only(x for x in G.Catalogue.RULES if x.id === Symbol("RULE.DOC.SIGNATURE_FIDELITY"))
    @test isempty(Base.invokelatest(CK.run_rule, r, cfg, dir; pkg))                 # `origin` is shown, second
end

# A short call bulleted under the old sentence is told to use prose, not to add a heading: the check
# looked at the form before it counted (fixed 2026-09-29). The location is the same either way, so the
# message is what is asserted.
@testset "ARGS_FORM counts before it judges bullets under the old sentence" begin
    r = only(x for x in G.Catalogue.RULES if x.id === Symbol("RULE.DOC.ARGS_FORM"))
    two = "\"\"\"\n    f(a, b)\n\nDoes a thing. The arguments are:\n\n- `a` — the first.\n- `b` — the second.\n\"\"\"\nf(a, b) = a\n"
    three = "\"\"\"\n    f(a, b, c)\n\nDoes a thing. The arguments are:\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third.\n\"\"\"\nf(a, b, c) = a\n"
    cfg = G.Model.Config(package = "P", tool = :dev)
    @test occursin("running prose", only(r.check.run(two, cfg)).text)
    @test occursin("`# Arguments` heading", only(r.check.run(three, cfg)).text)
end
