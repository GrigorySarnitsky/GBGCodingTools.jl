# test/anchors.jl — re-anchoring, shown to work (docs/ARCHITECTURE.md §4.5, §12).
#
# A location is the file, the node, the quote and — only as a hint — the line. This suite moves each of
# those out from under a finding in turn and requires the location to come back where the design says:
# by node where the node still holds the quote, by quote where the node is gone, and OUTDATED where both
# are, never a guess at whatever now sits on the old line.
#
# The BY_DIFF case — the old line mapped through git by `Runs.reanchor` — is not here: `Runs` arrives in
# Phase 4, and this file gains that case with it.
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
