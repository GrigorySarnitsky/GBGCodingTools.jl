# test/anchors.jl — re-anchoring, shown to work (docs/ARCHITECTURE.md §4.5, §12).
#
# A location is the file, the node, the quote and — only as a hint — the line. This suite moves each of
# those out from under a finding in turn and requires the location to come back where the design says:
# by node where the node still holds the quote, by quote where the node is gone, and OUTDATED where both
# are, never a guess at whatever now sits on the old line.
#
# The BY_DIFF case is at the foot of the file: the old line mapped through git by `Runs.reanchor`, which
# is the wrapper a run calls. The git step lives there and not in `Texts` because nothing a consumer's
# build or test runs may read git state, and `Texts` is reached from both.
using Test, GBGCodingTools
include("helpers.jl")

const T = G.Texts
const M = G.Model

const JULIA_FIXTURE = """
module Sample

\"\"\"
    measure(u)

The mean of `u` over the grid. The arguments are `u`, the field. Returns the mean.
\"\"\"
measure(u) = sum(u) / length(u)

\"\"\"
    scale!(d, u, a)

Writes `a * u` into `d`. Returns `d`.
\"\"\"
function scale!(d, u, a)
    d .= a .* u
    return d
end

end
"""

const MARKDOWN_FIXTURE = """
# The guide

Some opening prose.

## Installing it

Run the installer and wait.

## Using it

The tolerance defaults to 1e-6 and the iteration cap to 10.

### A detail

Nothing turns on this.
"""

function in_tree(f)
    dir = mktempdir(; cleanup = true)
    write(joinpath(dir, "Sample.jl"), JULIA_FIXTURE)
    write(joinpath(dir, "guide.md"), MARKDOWN_FIXTURE)
    return f(dir)
end

@testset "re-anchoring" begin
    @testset "a fresh location is found by its node" begin
        in_tree() do dir
            loc = M.Location(; file = "Sample.jl", node = "scale!", text = "Writes `a * u` into `d`", line = 15)
            got = T.reanchor(dir, loc)
            @test got.found == M.Anchor.BY_NODE
            @test readlines(joinpath(dir, "Sample.jl"))[got.line] == "Writes `a * u` into `d`. Returns `d`."
        end
    end

    @testset "lines inserted above it move nothing" begin
        in_tree() do dir
            p = joinpath(dir, "Sample.jl")
            loc = T.reanchor(dir, M.Location(; file = "Sample.jl", node = "scale!", text = "Writes `a * u` into `d`", line = 15))
            write(p, "# a new comment\n" ^ 40 * read(p, String))
            got = T.reanchor(dir, loc)
            @test got.found == M.Anchor.BY_NODE
            @test got.line == loc.line + 40                      # the hint moved; the node found it anyway
            @test occursin("Writes `a * u` into `d`", readlines(p)[got.line])
        end
    end

    @testset "a renamed binding falls back to the quote" begin
        in_tree() do dir
            p = joinpath(dir, "Sample.jl")
            loc = M.Location(; file = "Sample.jl", node = "scale!", text = "Writes `a * u` into `d`", line = 15)
            write(p, replace(read(p, String), "scale!" => "写scale_into!"))
            got = T.reanchor(dir, loc)
            @test got.found == M.Anchor.BY_QUOTE
            @test occursin("Writes `a * u` into `d`", readlines(p)[got.line])
            @test got.node == "写scale_into!"                     # and it says where it landed
        end
    end

    # A node that survives does NOT anchor a finding whose quote is gone. The finding was about that
    # text; rewritten past recognition, it can no longer be confirmed, and the design's answer is to close
    # it as no longer locatable and let the next run find it again if it is still wrong — never to point a
    # fixer at a paragraph it was not written about (§4.5, §10).
    @testset "a reworded quote is OUTDATED even where its node survives" begin
        in_tree() do dir
            p = joinpath(dir, "Sample.jl")
            loc = M.Location(; file = "Sample.jl", node = "measure", text = "The mean of `u` over the grid", line = 6)
            write(p, replace(read(p, String), "The mean of `u` over the grid." => "The average of `u` across the grid."))
            got = T.reanchor(dir, loc)
            @test got.found == M.Anchor.OUTDATED
            @test !isempty(T.find_node(dir, "Sample.jl", "measure"))     # the node is still right there
        end
    end

    @testset "a location with a node and no quote anchors to the node" begin
        in_tree() do dir
            loc = M.Location(; file = "Sample.jl", node = "measure", line = 99)
            got = T.reanchor(dir, loc)
            @test got.found == M.Anchor.BY_NODE
            @test got.line == first(T.find_node(dir, "Sample.jl", "measure"))
        end
    end

    @testset "both gone is OUTDATED, never a guess" begin
        in_tree() do dir
            p = joinpath(dir, "Sample.jl")
            loc = M.Location(; file = "Sample.jl", node = "measure", text = "The mean of `u` over the grid", line = 6)
            write(p, "module Sample\nend\n")
            got = T.reanchor(dir, loc)
            @test got.found == M.Anchor.OUTDATED
            @test got.line == loc.line                            # left as it was, pointed at nothing new
        end
    end

    @testset "a missing file is OUTDATED" begin
        in_tree() do dir
            rm(joinpath(dir, "Sample.jl"))
            got = T.reanchor(dir, M.Location(; file = "Sample.jl", node = "measure", text = "x", line = 6))
            @test got.found == M.Anchor.OUTDATED
        end
    end

    @testset "a Markdown heading path holds a place" begin
        in_tree() do dir
            p = joinpath(dir, "guide.md")
            loc = M.Location(; file = "guide.md", node = "The guide / Using it", text = "tolerance defaults to 1e-6", line = 12)
            @test T.reanchor(dir, loc).found == M.Anchor.BY_NODE
            # a section inserted above it, and a sibling renamed: the path still names this section
            write(p, replace(read(p, String), "## Installing it\n\nRun the installer and wait." =>
                             "## Before you begin\n\nCheck the version.\n\n## Installing it\n\nRun the installer, then wait."))
            got = T.reanchor(dir, loc)
            @test got.found == M.Anchor.BY_NODE
            @test occursin("tolerance defaults to 1e-6", readlines(p)[got.line])
        end
    end

    @testset "a renamed heading falls back to the quote, and reports the new path" begin
        in_tree() do dir
            p = joinpath(dir, "guide.md")
            loc = M.Location(; file = "guide.md", node = "The guide / Using it", text = "tolerance defaults to 1e-6", line = 12)
            write(p, replace(read(p, String), "## Using it" => "## Running it"))
            got = T.reanchor(dir, loc)
            @test got.found == M.Anchor.BY_QUOTE
            @test got.node == "The guide / Running it"
        end
    end

    @testset "the nearest occurrence wins when a quote repeats" begin
        in_tree() do dir
            p = joinpath(dir, "guide.md")
            write(p, "# T\n\nthe same sentence here.\n\n## A\n\nthe same sentence here.\n\n## B\n\nthe same sentence here.\n")
            loc = M.Location(; file = "guide.md", node = "gone", text = "the same sentence here", line = 10)
            got = T.reanchor(dir, loc)
            @test got.found == M.Anchor.BY_QUOTE
            @test got.line == 11                                  # 3, 7 and 11: the one nearest the hint
        end
    end

    @testset "a location that is just a file comes back as it went" begin
        in_tree() do dir
            loc = M.Location(; file = "guide.md")
            @test T.reanchor(dir, loc) == loc
        end
    end
end

# ── BY_DIFF: what git says, once the node and the quote have both failed ─────────────────────────────
#
# This is the LAST resort and it is reached only when the text at the location was rewritten — which is
# exactly when the node and the quote fail. A mapping that gave up on a rewritten span would therefore
# never fire at all, and the first version of it did not: it returned `nothing` for any line inside a
# changed hunk, so every case that reached it came back OUTDATED.
const RN = G.Orchestration.Runs

function in_git(f)
    dir = mktempdir(; cleanup = true)
    gg(a...) = run(setenv(Cmd(["git", "-C", dir, a...]); dir = dir))
    gg("init", "-q"); gg("config", "user.name", "t"); gg("config", "user.email", "t@t")
    mkpath(joinpath(dir, "docs"))
    write(joinpath(dir, "docs", "page.md"), "# Title\n\nalpha\n\nbeta\n\nthe decisive line\n\ngamma\n")
    gg("add", "--all", "."); gg("commit", "-q", "-m", "first")
    base = strip(read(setenv(Cmd(["git", "-C", dir, "rev-parse", "HEAD"]); dir = dir), String))
    f(dir, gg, base)
end

@testset "the old line, mapped through git" begin
    @testset "a rewritten span maps to where that span now begins" begin
        in_git() do dir, gg, base
            # Lines added ABOVE it, and the line itself replaced: neither the node nor the quote can find it.
            write(joinpath(dir, "docs", "page.md"),
                  "# Title\n\nnew\nlines\nadded\n\nalpha\n\nbeta\n\nrewritten entirely\n\ngamma\n")
            gg("add", "--all", "."); gg("commit", "-q", "-m", "second")
            loc = M.Location(; file = "docs/page.md", text = "the decisive line", line = 7)
            @test T.reanchor(dir, loc).found == M.Anchor.OUTDATED      # files alone cannot say
            got = RN.reanchor(dir, loc; since = base)
            @test got.found == M.Anchor.BY_DIFF
            @test strip(readlines(joinpath(dir, "docs", "page.md"))[got.line]) == "rewritten entirely"
        end
    end

    @testset "a quote that survives never reaches the diff" begin
        in_git() do dir, gg, base
            write(joinpath(dir, "docs", "page.md"),
                  "# Title\n\nnew\nlines\nadded\n\nalpha\n\nbeta\n\nthe decisive line\n\ngamma\n")
            gg("add", "--all", "."); gg("commit", "-q", "-m", "second")
            loc = M.Location(; file = "docs/page.md", text = "the decisive line", line = 7)
            @test RN.reanchor(dir, loc; since = base).found == M.Anchor.BY_QUOTE
        end
    end

    # A file that is GONE is outdated whatever git says. `git diff` over a path that no longer exists
    # prints nothing, and an empty patch otherwise means "nothing moved" — so this came back BY_DIFF at
    # its original line, which is the one answer the design forbids.
    @testset "a deleted file is outdated, not unmoved" begin
        in_git() do dir, gg, base
            rm(joinpath(dir, "docs", "page.md"))
            gg("add", "--all", "."); gg("commit", "-q", "-m", "deleted")
            loc = M.Location(; file = "docs/page.md", text = "the decisive line", line = 7)
            @test RN.reanchor(dir, loc; since = base).found == M.Anchor.OUTDATED
        end
    end

    @testset "with no commit to compare against, the answer is the files' own" begin
        in_git() do dir, gg, base
            write(joinpath(dir, "docs", "page.md"), "# Title\n\nnothing of the sort\n")
            loc = M.Location(; file = "docs/page.md", text = "the decisive line", line = 7)
            @test RN.reanchor(dir, loc).found == M.Anchor.OUTDATED
        end
    end
end

# A quote read somewhere that is not a file — a built page — is placed by searching the documentation
# for it. One file holding it is an answer; two is a coin toss, and the honest answer is none.
@testset "placing a quote across the documentation" begin
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".gbg")); mkpath(joinpath(root, "docs", "src")); mkpath(joinpath(root, "src"))
    write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
    write(joinpath(root, "docs", "src", "index.md"), "# Home\n\nThe grid is spectral.\n")
    write(joinpath(root, "docs", "src", "guide.md"), "# Guide\n\nA sentence the build\nre-wrapped over two lines.\n")
    write(joinpath(root, "src", "Sample.jl"), """
    module Sample
    \"\"\"
        f(x) -> Int

    The one place this exact sentence is written. The argument is `x`. Returns one.
    \"\"\"
    f(x) = 1
    end
    """)
    cfg = G.ConfigIO.read_config(root)

    @test G.Texts.place(cfg, root, "The one place this exact sentence is written.").file == joinpath("src", "Sample.jl")
    @test G.Texts.place(cfg, root, "The one place this exact sentence is written.").node == "f"
    # a sentence the build re-wrapped is still found, and the line is where it starts
    wrapped = G.Texts.place(cfg, root, "A sentence the build re-wrapped over two lines.")
    @test wrapped.file == joinpath("docs", "src", "guide.md") && wrapped.line == 3
    # nothing holds it, or two files do: not placed
    @test G.Texts.place(cfg, root, "words nobody wrote") === nothing
    write(joinpath(root, "docs", "src", "notation.md"), "# Notation\n\nThe grid is spectral.\n")
    @test G.Texts.place(G.ConfigIO.read_config(root), root, "The grid is spectral.") === nothing
    @test G.Texts.place(cfg, root, "   ") === nothing
end

# ── What a review of 2026-09-23 found placing findings, each case the shape it was found in ──────────

@testset "a line the finding never had is not carried" begin
    # An unplaced finding is OUTDATED at line 0; with no edit since, git's empty diff said "unmoved" and
    # it came back BY_DIFF at line 0, so the fixer was sent to a place that was never one.
    in_git() do dir, gg, base
        loc = M.Location(; file = "docs/page.md", text = "words nobody wrote", line = 0)
        @test RN.reanchor(dir, loc; since = base).found == M.Anchor.OUTDATED
        @test RN.mapped_line(dir, loc, base) === nothing
    end
end

@testset "an insertion right after the line does not move it" begin
    in_git() do dir, gg, base
        lines = readlines(joinpath(dir, "docs", "page.md"))
        write(joinpath(dir, "docs", "page.md"), join(vcat(lines[1:7], ["one", "two", "three"], lines[8:end]), "\n") * "\n")
        @test RN.mapped_line(dir, M.Location(; file = "docs/page.md", line = 7), base) == 7
        @test RN.mapped_line(dir, M.Location(; file = "docs/page.md", line = 8), base) == 11
    end
end

@testset "a line found again on a later pass is not shifted a second time" begin
    in_git() do dir, gg, base
        page = joinpath(dir, "docs", "page.md")
        write(page, "# Title\n\n1\n2\n3\n4\n5\n\nalpha\n\nbeta\n\nthe decisive line\n\ngamma\n")
        gg("add", "--all", "."); gg("commit", "-q", "-m", "pass 1")
        first_pass = RN.reanchor(dir, M.Location(; file = "docs/page.md", text = "the decisive line", line = 7); since = base)
        @test first_pass.found == M.Anchor.BY_QUOTE && first_pass.line == 13
        @test !isempty(first_pass.at)                          # stamped with the tree it was read in
        # the record round trip keeps the stamp
        @test RN.loc_of(RN.loc_dict(first_pass)).at == first_pass.at
        write(page, replace(read(page, String), "the decisive line" => "rewritten entirely"))
        gg("add", "--all", "."); gg("commit", "-q", "-m", "pass 2")
        second = RN.reanchor(dir, first_pass; since = base)
        @test second.found == M.Anchor.BY_DIFF && second.line == 13
    end
end

@testset "every definition of a scope is a node, named by its callee" begin
    dir = mktempdir(; cleanup = true)
    write(joinpath(dir, "M.jl"), """
    module M
    @inline helper(x) = x
    \"\"\"
        after(x)

    The one after the helper.
    \"\"\"
    after(x) = 1
    \"\"\"
        f(x::T) where {T}

    A method with a where clause.
    \"\"\"
    function f(x::T) where {T}
        return x
    end
    g(x)::Int = 1
    end
    """)
    names = [s.name for s in T.definitions(joinpath(dir, "M.jl"))]
    @test "after" in names && "helper" in names
    @test "f" in names && "g" in names
    @test !any(n -> occursin("where", n) || occursin("(", n), names)
    @test !isempty(T.find_node(dir, "M.jl", "f"))
end

@testset "a quote is looked for in every method the node names" begin
    dir = mktempdir(; cleanup = true)
    write(joinpath(dir, "M.jl"), """
    module M
    \"\"\"
        k(x)

    The shared sentence.
    \"\"\"
    k(x) = 1
    \"\"\"
        h(x::Int)

    The first method.
    \"\"\"
    h(x::Int) = 1
    \"\"\"
        h(x::Float64)

    The shared sentence.
    \"\"\"
    h(x::Float64) = 2
    end
    """)
    got = T.reanchor(dir, M.Location(; file = "M.jl", node = "h", text = "The shared sentence."))
    @test got.found == M.Anchor.BY_NODE && got.line == 17
end

@testset "a quote as the page reads it is found in the source that wrote it" begin
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".gbg")); mkpath(joinpath(root, "docs", "src")); mkpath(joinpath(root, "src"))
    write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
    write(joinpath(root, "docs", "src", "guide.md"), """
    # Guide

    The layout is [`RealFourierLayout`](@ref), and the **same** layout
    holds for ``\\hat f(k)`` on every grid.

    - A list item whose sentence
      wraps.
    """)
    write(joinpath(root, "src", "Sample.jl"), """
    module Sample
    \"\"\"
        f(x)

    Rotates by ``\\\\alpha`` about the axis.
    \"\"\"
    f(x) = 1
    end
    """)
    cfg = G.ConfigIO.read_config(root)
    page = "The layout is RealFourierLayout, and the same layout holds for \$\\hat f(k)\$ on every grid."
    p = T.place(cfg, root, page)
    @test p !== nothing && p.file == joinpath("docs", "src", "guide.md") && p.line == 3
    # the file named, the quote spelled as on the page, and wrapped in the source
    got = T.reanchor(root, M.Location(; file = "docs/src/guide.md", text = page))
    @test got.found == M.Anchor.BY_QUOTE && got.line == 3
    @test T.reanchor(root, M.Location(; file = "docs/src/guide.md", text = "A list item whose sentence wraps.")).line == 6
    # a docstring's escaped backslash reads as one
    d = T.place(cfg, root, "Rotates by \$\\alpha\$ about the axis.")
    @test d !== nothing && d.file == joinpath("src", "Sample.jl") && d.node == "f"
end

@testset "a Literate page is its example, and its comment marks are not text" begin
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".gbg")); mkpath(joinpath(root, "docs", "src", "examples")); mkpath(joinpath(root, "examples"))
    write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
    write(joinpath(root, "examples", "EX.jl"), "# # The example\n#\n# A sentence the example\n# wraps over two comment lines.\nx = 1\n")
    write(joinpath(root, "docs", "src", "examples", "ex.md"),
          "```@meta\nEditURL = \"../../../examples/EX.jl\"\n```\n\n# The example\n\nA sentence the example\nwraps over two comment lines.\n")
    @test G.Orchestration.Site.source_of(root, "examples/ex/index.html") == "examples/EX.jl"
    got = T.reanchor(root, M.Location(; file = "examples/EX.jl", text = "A sentence the example wraps over two comment lines."))
    @test got.found == M.Anchor.BY_QUOTE && got.line == 3
    # an EditURL that leaves the package, or is a web address, is not followed
    write(joinpath(root, "docs", "src", "examples", "ex.md"), "```@meta\nEditURL = \"https://example.org/EX.jl\"\n```\n")
    @test G.Orchestration.Site.source_of(root, "examples/ex/index.html") == joinpath("docs", "src", "examples", "ex.md")
end

@testset "the page text keeps its blocks apart" begin
    doc = T.parsehtml("<html><body><article class=\"content\"><h2>Fields</h2><p>One field.</p><ul><li>Grid</li><li>Layout</li></ul></article></body></html>")
    t = T.page_text(T.article_of(doc))
    @test !occursin("FieldsOne", t) && !occursin("field.Grid", t) && !occursin("GridLayout", t)
    @test T.reading(t) == "Fields One field. Grid Layout"
end

@testset "the formulas of a quote are found however they are delimited" begin
    @test T.formulas("a real field's coefficients satisfy ``\\hat f(-k) = \\overline{\\hat f(k)}``, always") ==
          ["\\hat f(-k) = \\overline{\\hat f(k)}"]
    @test T.formulas("so \$\\hat u_k\$ holds") == ["\\hat u_k"]
    # a quote cut mid-formula does not make the prose between two formulas one
    @test !("for the velocity," in T.formulas("\\hat{\\cdot}\$ for the velocity, \$u\$"))
end

@testset "a sentence a rationale document repeats is still the docstring's" begin
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".gbg")); mkpath(joinpath(root, "docs")); mkpath(joinpath(root, "src"))
    write(joinpath(root, ".gbg", "config.jl"),
          """Config(package = "Sample", tool = :dev, filesets = Dict(FileSet.RATIONALE => ["docs/DECISIONS.md"]))""")
    write(joinpath(root, "docs", "DECISIONS.md"), "# Decisions\n\nThe spectrum is stored in half.\n")
    write(joinpath(root, "src", "Sample.jl"), "module Sample\n\"\"\"\n    f(x)\n\nThe spectrum is stored in half.\n\"\"\"\nf(x) = 1\nend\n")
    p = T.place(G.ConfigIO.read_config(root), root, "The spectrum is stored in half.")
    @test p !== nothing && p.file == joinpath("src", "Sample.jl")
    # alone in the rationale document, it is placed there
    @test T.place(G.ConfigIO.read_config(root), root, "Decisions").file == joinpath("docs", "DECISIONS.md")
end

@testset "a formula the quote cut open is still searched for" begin
    @test T.formulas("a real field's coefficients satisfy ``\\hat f(-k) =") == ["\\hat f(-k) ="]
    @test T.formulas("\\overline{\\hat f(k)}``, so only half is stored") == ["\\overline{\\hat f(k)}"]
    @test T.formulas("``a_1`` and then ``b_2``") == ["a_1", "b_2"]      # closed pairs are not reopened
    @test isempty(T.formulas("plain prose, with ``code`` only"))
end

# ── The source's own spelling comes first (review, 2026-09-24) ───────────────────────────────────────
#
# Tried first, the reading form lost 1769 of a real package's quotes spelled as the source spells them,
# sent a decision-log sentence to a code comment, listed text already written right as a copy of a markup
# defect, and let a verifier ground a verdict in a file that was never fixed.

function spelled_tree()
    root = mktempdir(; cleanup = true)
    for d in (".gbg", "docs/src", "src"); mkpath(joinpath(root, d)); end
    write(joinpath(root, ".gbg", "config.jl"),
          """Config(package = "Sample", tool = :dev, filesets = Dict(FileSet.RATIONALE => ["docs/DECISIONS.md"]))""")
    write(joinpath(root, "docs", "src", "a.md"), "# A\n\nThe method was published by Rogallo in\n1981. The truncation removes the corner modes.\n\nThe **same** layout holds.\n")
    write(joinpath(root, "docs", "src", "b.md"), "# B\n\nThe same layout holds.\n\nSee [§10](@ref \"10. The layer (grid to points)\"). Same fibers, different base.\n")
    write(joinpath(root, "docs", "DECISIONS.md"), "# Decisions\n\nTwo fields of one concrete type hold identical values by construction.\n")
    write(joinpath(root, "src", "S.jl"), """
    module S
    \"\"\"
        f(x)

    The size of the box in each spatial direction.
    - `domain_size::NTuple{3, T}` — the lengths.

    ```math
    a \\\\\\\\ b
    ```
    \"\"\"
    f(x) = 1
    # Two fields of one concrete type hold identical values
    # by construction.
    g(x) = 2
    end
    """)
    return root
end

@testset "a quote spelled as the source spells it is found across a wrap" begin
    root = spelled_tree(); cfg = G.ConfigIO.read_config(root)
    p = T.place(cfg, root, "in each spatial direction. - `domain_size::NTuple{3, T}` — the lengths.")
    @test p !== nothing && p.file == joinpath("src", "S.jl") && p.line == 5
    q = T.place(cfg, root, "published by Rogallo in 1981. The truncation removes")
    @test q !== nothing && q.file == joinpath("docs", "src", "a.md") && q.line == 3
end

@testset "a decision-log sentence is the log's, not a code comment that reads like it" begin
    root = spelled_tree(); cfg = G.ConfigIO.read_config(root)
    p = T.place(cfg, root, "Two fields of one concrete type hold identical values by construction.")
    @test p !== nothing && p.file == joinpath("docs", "DECISIONS.md")
end

@testset "a copy is the same spelling, and a verifier's quote is the text as written" begin
    root = spelled_tree(); cfg = G.ConfigIO.read_config(root)
    @test [l.file for l in T.occurrences(cfg, root, "The **same** layout holds.")] == [joinpath("docs", "src", "a.md")]
    # the fixed spelling does not hold in a file that still has the old one
    strict = T.reanchor(root, M.Location(; file = "docs/src/a.md", text = "The same layout holds."); loose = false)
    @test strict.found == M.Anchor.OUTDATED
    @test T.reanchor(root, M.Location(; file = "docs/src/a.md", text = "The same layout holds.")).found == M.Anchor.BY_QUOTE
end

@testset "the page's reading of an escaped backslash, a link with parentheses, and a Literate filter" begin
    root = spelled_tree(); cfg = G.ConfigIO.read_config(root)
    # a docstring's `\\\\` is the page's `\\`, a LaTeX line break
    @test T.reanchor(root, M.Location(; file = "src/S.jl", text = "\\[a \\\\ b\\]")).found != M.Anchor.OUTDATED
    p = T.place(cfg, root, "See §10. Same fibers, different base.")
    @test p !== nothing && p.file == joinpath("docs", "src", "b.md")
    @test T.reading_line("#md # the autocorrelation, read off") == "the autocorrelation, read off"
    @test T.reading_line("x = 1 #src") == "x = 1"
end

@testset "an EditURL that leaves the package is not followed" begin
    # the package and the file outside it both inside one scratch directory, which the test owns
    outer = mktempdir(; cleanup = true)
    root = joinpath(outer, "pkg")
    mkpath(joinpath(root, "docs", "src", "examples"))
    write(joinpath(outer, "outside.jl"), "# outside\n")
    write(joinpath(root, "docs", "src", "examples", "ex.md"), "```@meta\nEditURL = \"../../../../outside.jl\"\n```\n")
    @test G.Orchestration.Site.source_of(root, "examples/ex/index.html") == joinpath("docs", "src", "examples", "ex.md")
end

@testset "a quote cut open pairs its formulas from the pieces, not from the left" begin
    @test T.formulas("\\hat f(k)`` holds, and ``u_k`` is the velocity") == ["\\hat f(k)", "u_k"]
    @test T.formulas("\\hat f(k)`` where N = 2 and ``u_k^2`` is the energy") == ["\\hat f(k)", "u_k^2"]
    @test T.formulas("then \$|u|\$ and \$a + b + c\$") == ["|u|", "a + b + c"]
end

# ── The review of 2026-09-26: the readers of this module, each case the shape it was found in ────────

@testset "a page's link is text with its target, and a page with one does not throw" begin
    doc = T.parsehtml("<html><body><article class=\"content\"><h2 id=\"f\"><a class=\"docs-heading-anchor\" href=\"#f\">Fields</a></h2><p>See <a href=\"guide/\">the guide</a>.</p></article></body></html>")
    t = T.page_text(T.article_of(doc))
    @test occursin("[the guide](guide/)", t) && occursin("[Fields](#f)", t)
    @test T.reading(t) == "Fields See the guide."
end

@testset "a .gitignore is read as git reads it" begin
    root = mktempdir(; cleanup = true)
    for d in ("build", "docs/gen", "docs/a/b/gen", "data", ".github", "foo(1)"); mkpath(joinpath(root, d)); end
    write(joinpath(root, ".gitignore"), "foo(1).txt\nfoo\\ \n[!a]*.md\n**/build\ndocs/**/gen\nout/**\nx)\n")
    write(joinpath(root, "data", ".gitignore"), "*\n!keep.md\n!.gitignore\n")
    write(joinpath(root, ".github", ".gitignore"), "secret.md\n")
    ig = T.ignored(root)
    # a metacharacter is literal, and a line holding one does not throw out of every check
    @test ig("foo(1).txt") && !ig("foo1.txt") && ig("x)") && !ig("x")
    @test ig("foo ") && !ig("foo")                                    # an escaped trailing space is kept
    @test ig("b.md") && !ig("a.md")                                   # git's negated class
    @test ig("build") && ig("build/x.o") && ig("src/build/y")         # `**/` matches no directory too
    @test ig("docs/gen") && ig("docs/gen/z") && ig("docs/a/b/gen") && !ig("docs/genx")
    @test ig("out/deep/er/z.md") && !ig("out")                        # a trailing `/**` is everything below
    # a nested file applies strictly below its directory, so the `*` / `!keep` idiom keeps what it says
    @test !ig("data/keep.md") && !ig("data/.gitignore") && ig("data/other.md")
    @test ig(".github/secret.md") && !ig(".github/workflow.yml")     # `.github/` is not `.git/`
end

@testset "the walk and the guard's test read one pattern the same way" begin
    root = mktempdir(; cleanup = true)
    for d in ("docs/n (old)", "docs/n old", "docs/a+b", "docs/ab", "docs/deep/er"); mkpath(joinpath(root, d)); end
    for f in ("docs/n (old)/y.md", "docs/n old/y.md", "docs/a+b/x.md", "docs/ab/x.md", "docs/top.md", "docs/deep/er/z.md")
        write(joinpath(root, f), "# x\n")
    end
    @test T.expand(root, "docs/n (old)/*.md") == ["docs/n (old)/y.md"]
    @test T.expand(root, "docs/a+b/*.md") == ["docs/a+b/x.md"]
    @test sort(T.expand(root, "docs/**")) == sort(["docs/n (old)/y.md", "docs/n old/y.md", "docs/a+b/x.md", "docs/ab/x.md", "docs/top.md", "docs/deep/er/z.md"])
    @test sort(T.expand(root, "docs/**/*.md")) == sort(T.expand(root, "docs/**"))
    for p in ("docs/n (old)/*.md", "docs/a+b/*.md", "docs/**", "docs/**/*.md", "docs/*.md")
        for f in T.expand(root, "docs/**")
            @test T.glob_matches(p, f) == (f in T.expand(root, p))
        end
    end
    @test T.glob_matches("docs/**", "docs/deep/er/z.md") && !T.glob_matches("docs/**", "src/x.jl")
end

@testset "every documented thing has a node: @doc, an abstract type, a bare name, a signature, a tuple, an enum, a callable" begin
    dir = mktempdir(; cleanup = true)
    write(joinpath(dir, "M.jl"), """
    module M
    @doc raw\"\"\"
        h(x)

    Rotates by \\\\alpha.
    \"\"\" h(x) = x
    \"\"\"abs\"\"\" abstract type A{T} <: B end
    \"\"\"prim\"\"\" primitive type P 8 end
    \"\"\"bare\"\"\" f
    \"\"\"sig\"\"\" g(::Int)
    \"\"\"call\"\"\" function (c::C)(x) end
    \"\"\"tuple\"\"\" const P1, Q1 = 1, 2
    \"\"\"enum\"\"\" @enum E a b
    \"\"\"plain\"\"\" k = 1
    const R1 = Rule(; id = :a, statement = "s")
    module Inner
    q(x) = 1
    end
    end
    """)
    docs = T.docstrings(joinpath(dir, "M.jl"))
    @test Dict(d.node => d.text for d in docs)["h"] == "    h(x)\n\nRotates by \\\\alpha."
    @test [d.node for d in docs] == ["h", "A", "P", "f", "g", "C", "P1", "E", "k"]
    names = [s.name for s in T.definitions(joinpath(dir, "M.jl"))]
    for n in ("h", "A", "P", "f", "g", "C", "P1", "E", "k", "R1.id", "R1.statement", "q")
        @test n in names
    end
    @test !("c::C" in names) && !("P1, Q1" in names) && !("Inner.q" in names)
    @test !isempty(T.find_node(dir, "M.jl", "h"))
    # the @doc docstring is prose to the rules, and the lines keep their numbers
    prose = split(T.prose_text(joinpath(dir, "M.jl"); comments = false), '\n')
    @test prose[5] == "Rotates by \\\\alpha." && prose[2] == "@doc raw\"\"\""
    # a broken file yields what parsed, which is what the docstring promises
    write(joinpath(dir, "B.jl"), "\"\"\"one\"\"\"\nf(x) = 1\nfunction g(\n")
    @test [s.name for s in T.definitions(joinpath(dir, "B.jl"))] ⊇ ["f"]
end

@testset "a heading inside any fence is not a heading" begin
    dir = mktempdir(; cleanup = true)
    write(joinpath(dir, "p.md"), "# Top\n\n````markdown\n```\n# not a heading\n```\n````\n\n## Real\n\n~~~\n# also not\n~~~\n\n## Last\n")
    @test [h.name for h in T.headings(joinpath(dir, "p.md"))] == ["Top", "Top / Real", "Top / Last"]
end

@testset "an escaped dollar reads as the page shows it, and is not a formula" begin
    @test T.reading_line("costs \\\$5 here") == "costs 5 here"
    @test T.reading_line("costs \\\\\\\$5 here"; escaped = true) == "costs 5 here"   # a docstring's three backslashes
    @test T.reading_line("costs \\\\\$5 here"; escaped = true) == "costs 5 here"
    @test isempty(T.formulas("costs \\\$5 and \\\$6 today"))
    @test T.formulas("so \$\\hat u_k\$ holds") == ["\\hat u_k"]
end
