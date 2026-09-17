# test/guard.jl — the change guard, one example per clause and in both directions
# (docs/ARCHITECTURE.md §4.2).
#
# This is the gate the automatic half of the package rests on: what it calls documentation gets committed
# without the owner. So every clause is shown to fire AND to stay quiet — a guard that answers CODE to
# everything would pass a one-directional test and be useless, and one that answers DOCUMENTATION too
# often is how code gets committed behind a prose fix.
#
# The three cases the design names from past failures are here by name: changed doctest output, a changed
# `@autodocs` filter, and a docstring that stops a call from running. Each passed a guard that compared
# only the parsed code.
using Test, GBGCodingTools
include("helpers.jl")

const GD = G.Engine.Guard
const MD = G.Model

cfg() = MD.Config(package = "P", tool = :dev,
                  normative = ["docs/ARCHITECTURE.md"],
                  copies = ["docs/src/architecture.md" => "docs/ARCHITECTURE.md"],
                  filesets = Dict(MD.FileSet.RATIONALE => ["docs/RATIONALE.md"]))

doc(path, before, after; generated = nothing) = GD.classify(cfg(), path, before, after; generated).documentation
why(path, before, after) = GD.classify(cfg(), path, before, after).reason

@testset "the change guard" begin
    @testset "clause 1 — where documentation may live" begin
        prose_a = "# A page\n\nOne sentence.\n"
        prose_b = "# A page\n\nAnother sentence entirely.\n"
        @test doc("docs/src/guide.md", prose_a, prose_b)
        @test doc("README.md", prose_a, prose_b)
        @test doc("docs/RATIONALE.md", prose_a, prose_b)            # a rationale document the config names
        @test !doc("docs/ARCHITECTURE.md", prose_a, prose_b)        # declared normative: never documentation
        @test !doc("docs/src/architecture.md", prose_a, prose_b)    # a declared copy: the source is the text
        @test !doc("CLAUDE.md", prose_a, prose_b)
        @test !doc(".github/workflows/ci.yml", "a: 1\n", "a: 2\n")
        @test !doc(".gbg/config.jl", "Config(package = \"P\")\n", "Config(package = \"Q\")\n")
        @test !doc("test/runtests.jl", "@test f(1) == 1\n", "@test f(1) == 2\n")
        @test !doc("docs/make.jl", "makedocs(x)\n", "makedocs(y)\n")
        @test !doc("Project.toml", "version = \"1.0.0\"\n", "version = \"1.0.1\"\n")
    end

    @testset "clause 2 — the code must be identical" begin
        base = """
        \"\"\"
            measure(u)

        The mean of `u`.
        \"\"\"
        measure(u) = sum(u) / length(u)
        """
        reworded = replace(base, "The mean of `u`." => "The arithmetic mean of the field `u` over its grid.")
        moved = replace(base, "sum(u) / length(u)" => "sum(u) / max(1, length(u))")
        @test doc("src/M.jl", base, reworded)
        @test !doc("src/M.jl", base, moved)
        @test occursin("clause 2", why("src/M.jl", base, moved))

        # a comment is documentation; the line it sits on is not
        @test doc("src/M.jl", "f(x) = x   # old note\n", "f(x) = x   # a different note\n")
        @test !doc("src/M.jl", "f(x) = x   # note\n", "f(x) = x + 1   # note\n")

        # a field docstring inside a struct, and a keyword-default struct
        s_before = "Base.@kwdef struct S\n    \"the first\"\n    a::Int = 1\nend\n"
        s_after  = "Base.@kwdef struct S\n    \"the first field, in more words\"\n    a::Int = 1\nend\n"
        s_code   = "Base.@kwdef struct S\n    \"the first\"\n    a::Int = 2\nend\n"
        @test doc("src/M.jl", s_before, s_after)
        @test !doc("src/M.jl", s_before, s_code)

        # a file that does not parse, on either side, is code: the guard cannot see what changed
        @test !doc("src/M.jl", base, base * "\nfunction broken(\n")
        @test !doc("src/M.jl", base * "\nfunction broken(\n", base)
    end

    @testset "clause 2 — a docstring on a call is not documentation" begin
        # Documenting a call REPLACES it: `@doc "text" f()` documents the call instead of running it, so
        # adding or removing one changes what the file does. This passed a guard that compared code alone.
        before = "register!(:a)\nregister!(:b)\n"
        after  = "\"a note about this one\"\nregister!(:a)\nregister!(:b)\n"
        @test !doc("src/M.jl", before, after)

        # and the same for a macro call that defines nothing
        m_before = "@timed_call compute(x)\n"
        m_after  = "\"describing it\"\n@timed_call compute(x)\n"
        @test !doc("src/M.jl", m_before, m_after)
    end

    @testset "clause 2 — an interpolated docstring is never dropped" begin
        before = "\"\"\"\n\$(SOME_TEXT)\n\"\"\"\nf(x) = x\n"
        after  = "\"\"\"\n\$(OTHER_TEXT)\n\"\"\"\nf(x) = x\n"
        @test !doc("src/M.jl", before, after)          # its text is a program, and the program changed
    end

    @testset "clause 4 — a Literate mark moves what runs" begin
        before = "x = 1      #src\ny = 2\n# a plain comment\n"
        after   = "x = 1      #src\ny = 2\n# a plain comment, reworded\n"
        moved   = "x = 1\ny = 2      #src\n# a plain comment\n"
        @test doc("src/M.jl", before, after)
        @test !doc("src/M.jl", before, moved)
        @test occursin("clause 4", why("src/M.jl", before, moved))
    end

    @testset "clause 5 — a doctest and an `@` block are run, not read" begin
        page_a = """
        # A page

        Some prose.

        ```jldoctest
        julia> 1 + 1
        2
        ```
        """
        page_prose = replace(page_a, "Some prose." => "Some different prose entirely.")
        page_output = replace(page_a, "julia> 1 + 1\n2" => "julia> 1 + 1\n3")
        @test doc("docs/src/p.md", page_a, page_prose)
        @test !doc("docs/src/p.md", page_a, page_output)
        @test occursin("clause 5", why("docs/src/p.md", page_a, page_output))

        autodocs_a = "# API\n\nProse.\n\n```@autodocs\nModules = [P]\nPrivate = false\n```\n"
        autodocs_b = replace(autodocs_a, "Private = false" => "Private = true")
        @test !doc("docs/src/api.md", autodocs_a, autodocs_b)

        # a docstring holding a doctest: the same rule, inside a `.jl` file
        jl_a = "\"\"\"\n    f()\n\n```jldoctest\njulia> f()\n1\n```\n\"\"\"\nf() = 1\n"
        jl_b = replace(jl_a, "julia> f()\n1" => "julia> f()\n2")
        @test !doc("src/M.jl", jl_a, jl_b)
    end

    @testset "clause 0 — a generated file equal to its generator's output" begin
        rendered = "# generated\nkey = \"value\"\n"
        @test doc("docs/src/architecture.md", "# generated\nkey = \"old\"\n", rendered; generated = rendered)
        @test !doc("docs/src/architecture.md", "# generated\nkey = \"old\"\n", "# generated\nkey = \"hand-edited\"\n";
                   generated = rendered)
    end

    @testset "a new or removed file is code" begin
        @test !doc("docs/src/new.md", nothing, "# New\n")
        @test !doc("docs/src/old.md", "# Old\n", nothing)
    end

    @testset "an unchanged file is documentation, trivially" begin
        @test doc("src/M.jl", "f(x) = x\n", "f(x) = x\n")
    end
end
