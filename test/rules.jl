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
end
