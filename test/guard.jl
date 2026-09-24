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

    @testset "clause 2 — a docstring on a bare name IS documentation" begin
        # The other half of the same distinction, and the one this package had no example of: a whole
        # generic documented above methods written one per backend. Removing the docstring leaves the
        # name alone, which runs nothing, so rewording its prose is a documentation change. Nineteen
        # targets in GBGPeriodicFields were refused as code until 2026-09-23.
        before = "\"the sum of two fields\"\n+\n\nf(a, b) = a\n"
        after  = "\"adds two fields, componentwise\"\n+\n\nf(a, b) = a\n"
        @test doc("src/M.jl", before, after)

        # rewording an existing docstring is prose wherever it stands: nothing structural moves
        @test doc("src/M.jl", "\"one\"\nBase.mean\n", "\"another\"\nBase.mean\n")
        @test doc("src/M.jl", "x = 1\n\"one\"\nx\n", "x = 1\n\"another\"\nx\n")

        # and changing the NAME itself is still code, docstring or not
        @test !doc("src/M.jl", "\"the sum\"\n+\n", "\"the sum\"\n-\n")
    end

    # Found in review, 2026-09-23: each of these is a behaviour change the guard called documentation.
    @testset "clause 2 — what only LOOKS like documentation inside code" begin
        g(before, after) = doc("src/M.jl", before, after)
        # a string default in a struct, and a string an inner constructor passes, are values
        @test !g("Base.@kwdef struct S\n    sep::String = \", \"\nend\n", "Base.@kwdef struct S\n    sep::String = \"; \"\nend\n")
        @test !g("struct S\n    x::String\n    S() = new(\"default\")\nend\n", "struct S\n    x::String\n    S() = new(\"other\")\nend\n")
        # while a field docstring, standing directly in the body, is still prose
        @test g("struct S\n    \"the separator\"\n    sep::String\nend\n", "struct S\n    \"what separates\"\n    sep::String\nend\n")
        # a string that is a block's value is what the block returns
        @test !g("function greet()\n    \"hello\"\nend\n", "function greet()\n    \"goodbye\"\nend\n")
        @test !g("const X = begin\n    \"a\"\nend\n", "const X = begin\n    \"b\"\nend\n")
        @test !g("f(c) = if c\n    \"yes\"\nelse\n    \"no\"\nend\n", "f(c) = if c\n    \"no\"\nelse\n    \"yes\"\nend\n")
        # and one standing alone before the value is code too: no string Julia does not attach is removed,
        # since the same form in a macro's argument block or a `quote` is data (the review of 2026-09-23)
        @test !g("function f()\n    \"a note\"\n    1\nend\n", "function f()\n    \"another note\"\n    1\nend\n")
        @test !g("const S = @strs begin\n    \"a\"\n\n    1\nend\n", "const S = @strs begin\n    \"b\"\n\n    1\nend\n")
        @test !g("const Q = quote\n    \"a\"\n\n    1\nend\n", "const Q = quote\n    \"b\"\n\n    1\nend\n")
        # a docstring inside a block is the block's value, not documentation
        @test !g("y = begin\n    x = 1\n    x\nend\n", "y = begin\n    x = 1\n    \"doc\"\n    x\nend\n")
        # a docstring on a macro call that defines nothing replaces what runs
        @test !g("@eval x = 1\n", "\"doc\"\n@eval x = 1\n")
        @test !g("@reg x = 1\n", "\"doc\"\n@reg x = 1\n")
        # while Base's annotating macros around a definition are the form fast code documents most
        @test g("\"old\"\n@inline f(x) = x\n", "\"new\"\n@inline f(x) = x\n")
        @test g("\"old\"\nBase.@propagate_inbounds function f(x)\n    x\nend\n", "\"new\"\nBase.@propagate_inbounds function f(x)\n    x\nend\n")
        @test !g("\"old\"\n@inline f(x) = x\n", "\"old\"\n@inline f(x) = x + 1\n")
        # the last string of a Literate chunk is its displayed output, and of a file what `include` returns
        @test !doc("examples/x.jl", "# Text\nx = 1\n\"answer: 1\"\n# More\n", "# Text\nx = 1\n\"answer: 2\"\n# More\n")
        # a macro reading its own source line, and a line moved with the count unchanged
        @test !g("macro here() __source__.line end\n\"\"\"doc\"\"\"\nf() = 1\nconst L = @here\n",
                 "macro here() __source__.line end\n\"\"\"doc\nmore\"\"\"\nf() = 1\nconst L = @here\n")
        @test !g("\"\"\"doc\"\"\"\nf() = 1\nconst L = @__LINE__\n# a\n# b\n", "\"\"\"doc\nmore\"\"\"\nf() = 1\nconst L = @__LINE__\n# a b\n")
        # a Rule METHOD's keyword default is code, not a rule's prose
        @test !G.Engine.Guard.classify(G.Model.Config(package = "GBGCodingTools", tool = :dev), "src/M.jl",
                  "Rule(; statement = \"fallback\") = make(statement)\n", "Rule(; statement = \"other\") = make(statement)\n").documentation
        # an explicit `@doc` is left to the owner: a package may define its own `@doc` that runs its text
        @test !g("@doc raw\"\"\"\nThe \\alpha.\n\"\"\"\nf(x) = x\n", "@doc raw\"\"\"\nThe \\alpha, reworded.\n\"\"\"\nf(x) = x\n")
        # the review's third pass: each of these changed what runs, and each was called documentation
        @test !g("new() = 1\n@deprecate old new\n", "new() = 1\n\"Deprecated.\"\n@deprecate old new\n")
        @test !g("@nospecialize f\n", "\"doc\"\n@nospecialize f\n")
        @test !g("x = 5\n", "\"doc\"\nx = 5\n")
        @test !g("macro doc(s, ex); :(println(\$s); \$(esc(ex))); end\n@doc \"alpha\" x = 1\n",
                 "macro doc(s, ex); :(println(\$s); \$(esc(ex))); end\n@doc \"beta\" x = 1\n")
        @test !g("@labels struct S\n    \"alpha\"\n    x::Int\nend\n", "@labels struct S\n    \"beta\"\n    x::Int\nend\n")
        @test !g("const T = quote\n    struct S\n        \"alpha\"\n        x::Int\n    end\nend\n", "const T = quote\n    struct S\n        \"beta\"\n        x::Int\n    end\nend\n")
        # a comment in ordinary source is prose, wherever it stands
        @test g("f(x) = x   # old\n", "f(x) = x   # new, and longer\n")
        # the simple rule (ruled 2026-09-23): a comment's text may change, a comment may not be added
        @test !g("f(x) = x\n", "# a note added\nf(x) = x\n")
        # an interpolated string standing alone runs code
        @test !g("function f()\n    1\nend\n", "function f()\n    \"\$(rm(\"x\"))\"\n    1\nend\n")
        @test !g("x = 1\n", "x = 1\n\"\$(run(`true`))\"\n")
        # whitespace inside a literal is its value
        @test !g("s(xs) = join(xs, \", \")\n", "s(xs) = join(xs, \",\")\n")
        # a literal cannot spell another shape
        @test !g("f(\"a\", \"b\")\n", "f(\"a)) (string (String b\")\n")
        # a file that reads its own line numbers is code when a line moves
        @test !g("\"\"\"doc\"\"\"\nf() = 1\nconst L = @__LINE__\n", "\"\"\"doc\nmore\"\"\"\nf() = 1\nconst L = @__LINE__\n")
    end

    # The fourth review pass, 2026-09-23: each changed what runs and was called documentation.
    @testset "clause 2 — attaching, detaching, and what a docstring's presence does" begin
        g(b, a) = doc("src/M.jl", b, a)
        @test !g("\"note\"\n\nprintln(\"ran\")\n", "\"note\"\nprintln(\"ran\")\n")          # attached by a blank line
        @test !g("\"note\"\n# c\nprintln(\"ran\")\n", "\"note\" # c\nprintln(\"ran\")\n")      # or by moving a comment
        @test !g("module M\n\"The fast path.\"\nfast\nf() = 1\nend\n", "module M\nfast\nf() = 1\nend\n")   # a bare name's docstring removed
        @test g("module M\n\"The fast path.\"\nfast\nf() = 1\nend\n", "module M\n\"The quick path.\"\nfast\nf() = 1\nend\n")  # reworded: fine
        @test !g("baremodule B\nend\n", "\"The bare core.\"\nbaremodule B\nend\n")
        @test !g("@enum Colour red blue\n", "\"Colours.\"\n@enum Colour red blue\n")
        # a package's own `@kwdef` may read its field strings; an annotation that calls runs twice
        @test !g("macro kwdef(e) e end\n@kwdef struct P\n    \"velocity\"\n    u::Int\nend\n", "macro kwdef(e) e end\n@kwdef struct P\n    \"the velocity\"\n    u::Int\nend\n")
        @test !g("@kwdef struct P\n    \"velocity\"\n    u::Int\nend\n", "@kwdef struct P\n    \"the velocity\"\n    u::Int\nend\n")    # a bare `@kwdef` may be a package's
        # a string inside a docstring's interpolation runs at load; the docstring's own text is prose
        @test !g("\"\"\"\n\$(parse(Int, \"1\"))\nReturns it.\n\"\"\"\nf() = 1\n", "\"\"\"\n\$(parse(Int, \"42\"))\nReturns it.\n\"\"\"\nf() = 1\n")
        @test g("\"\"\"\n\$(SIGNATURES)\nReturns it.\n\"\"\"\nf() = 1\n", "\"\"\"\n\$(SIGNATURES)\nReturns the value.\n\"\"\"\nf() = 1\n")
        @test !g("\"\"\"\n\$(SIGNATURES)\n```jldoctest\njulia> f()\n1\n```\n\"\"\"\nf() = 1\n", "\"\"\"\n\$(SIGNATURES)\n```jldoctest\njulia> f()\n2\n```\n\"\"\"\nf() = 1\n")
        @test g("Base.@kwdef struct P\n    \"velocity\"\n    u::Int = 1\nend\n", "Base.@kwdef struct P\n    \"the velocity\"\n    u::Int = 1\nend\n")
        @test !g("function f(x::tick())\n    x\nend\ng() = 1\n", "\"Documented.\"\nfunction f(x::tick())\n    x\nend\ng() = 1\n")
        @test !g("function f(x::Int)\n    x\nend\ng() = 1\n", "\"Documented.\"\nfunction f(x::Int)\n    x\nend\ng() = 1\n")
        @test g("\"Colours.\"\n@enum Colour red blue\n", "\"The colours.\"\n@enum Colour red blue\n")
        @test !g("g() = 1\nf(x) = x\n", "g() = 1\n\"The identity.\"\nf(x) = x\n")          # the file's last statement
        # the simple rule (ruled 2026-09-23): a docstring added or removed is the owner's to approve
        @test !g("f(x) = x\ng() = 1\n", "\"The identity.\"\nf(x) = x\ng() = 1\n")
        @test !g("\"The identity.\"\nf(x) = x\ng() = 1\n", "f(x) = x\ng() = 1\n")
        # tokens either side of a block comment, whitespace in a `var` name
        @test !g("v = [10]\n", "v = [1#= =#0]\n")
        @test g("v = [1 #= old =# 0]\n", "v = [1 #= new, longer =# 0]\n")
        @test !g("var\"a \n\nb\" = 1\n", "var\"a\nb\" = 1\n")
        # a non-ASCII file: byte ranges end inside characters
        @test g("\"The α.\"\nf(α) = α\ng() = 1\n", "\"The α, reworded.\"\nf(α) = α\ng() = 1\n")
        @test !g("\"The α.\"\nf(α) = α\ng() = 1\n", "\"The α.\"\nf(α) = 2α\ng() = 1\n")
    end

    @testset "clause 3 — only the Rule call's own keywords are its prose" begin
        cfg3 = G.Model.Config(package = "GBGCodingTools", tool = :dev)
        r(b, a) = G.Engine.Guard.classify(cfg3, "src/Rules/x.jl", b, a).documentation
        @test r("R = Rule(id = :a, statement = \"old\", check = c)\n", "R = Rule(id = :a, statement = \"new\", check = c)\n")
        @test !r("R = Rule(id = :a, statement = \"s\", check = t -> report(t; why = \"old\"))\n",
                 "R = Rule(id = :a, statement = \"s\", check = t -> report(t; why = \"new\"))\n")
        @test !r("R = Rule(id = :a, check = t -> (statement = \"x\"; occursin(statement, t)))\n",
                 "R = Rule(id = :a, check = t -> (statement = \"y\"; occursin(statement, t)))\n")
        # a Rule(…) nested in code, whose statement the code reads, is not a rule's prose
        @test !r("limit() = length(Rule(id = :y, statement = \"abc\").statement)\n", "limit() = length(Rule(id = :y, statement = \"abcd\").statement)\n")
    end

    @testset "clause 5 and 6 — what the Markdown parser reads, wherever it stands" begin
        md(b, a) = doc("docs/src/a.md", b, a)
        @test !md("> ```jldoctest\n> julia> 1+1\n> 2\n> ```\n", "> ```jldoctest\n> julia> 1+1\n> 3\n> ```\n")
        @test !md("- ```jldoctest\n  julia> 1+1\n  2\n  ```\n", "- ```jldoctest\n  julia> 1+1\n  3\n  ```\n")
        @test !md("> ```math\n> E = mc^2\n> ```\n", "> ```math\n> E = mc^3\n> ```\n")
        @test !md("Energy \$E =\nmc^2\$ holds.\n", "Energy \$E =\nmc^3\$ holds.\n")
        @test !md("A ``a \\\\ b`` break.\n", "A ``a \\ b`` break.\n")
        @test !md("```julia\ns = \"``\"\n```\n\nThen ``E = mc^2``.\n", "```julia\ns = \"``\"\n```\n\nThen ``E = mc^3``.\n")
        @test !md("`a``b` ``E = mc^2``\n", "`a``b` ``E = mc^3``\n")
        @test !doc("src/M.jl", "const OPEN = \"``\"\n\"The ``k^2`` term.\"\nf() = 1\n", "const OPEN = \"``\"\n\"The ``k^3`` term.\"\nf() = 1\n")
        # a formula moved from one function's docstring to another's is a change
        @test !doc("src/M.jl", "\"The energy ``E = m c^2``.\"\nenergy() = 1\n\"The momentum.\"\nmomentum() = 1\ng() = 1\n",
                               "\"The energy.\"\nenergy() = 1\n\"The momentum ``E = m c^2``.\"\nmomentum() = 1\ng() = 1\n")
        # swapping a formula's text with a code span's is not a respelling
        @test !md("The energy is ``E = m c^2``; the code writes `E = m c^3`.\n", "The energy is ``E = m c^3``; the code writes `E = m c^2`.\n")
        # mathematics is what the parser reads as mathematics: a dollar sign in code prose is not
        @test doc("src/M.jl", "\"Errors name \\\$x in their text.\"\nf() = error(\"\$(1) and \$(2)\")\ng() = 1\n",
                              "\"Errors name \\\$x in their message.\"\nf() = error(\"\$(1) and \$(2)\")\ng() = 1\n")
        # respelling a code span as a math span with the same text is the LaTeX rules' own fix, not mathematics
        @test md("The cost is `O(N^2)`.\n", "The cost is ``O(N^2)``.\n")
        @test md("The cost is ``O(N^2)``.\n", "The cost is `O(N^2)`.\n")
        @test !md("The cost is `O(N^2)`.\n", "The cost is ``O(N^3)``.\n")
    end

    @testset "clause 5 — every spelling of a block that runs" begin
        @test !doc("docs/src/a.md", "~~~jldoctest\njulia> 1+1\n2\n~~~\n", "~~~jldoctest\njulia> 1+1\n3\n~~~\n")
        @test !doc("docs/src/a.md", "~~~@example\nrun(`ls`)\n~~~\n", "~~~@example\nrun(`rm x`)\n~~~\n")
        @test !doc("src/M.jl", "\"f\\n```jldoctest\\njulia> f()\\n1\\n```\"\nf() = 1\n",
                               "\"f\\n```jldoctest\\njulia> f()\\n2\\n```\"\nf() = 1\n")
        @test !doc("examples/x.jl", "# ```jldoctest\n# julia> 1\n# 2\n# ```\nx = 1\n",
                                    "# ```jldoctest\n# julia> 1\n# 3\n# ```\nx = 1\n")
    end

    @testset "clause 2 — an interpolated docstring is never dropped" begin
        before = "\"\"\"\n\$(SOME_TEXT)\n\"\"\"\nf(x) = x\n"
        after  = "\"\"\"\n\$(OTHER_TEXT)\n\"\"\"\nf(x) = x\n"
        @test !doc("src/M.jl", before, after)          # its text is a program, and the program changed
    end

    # In a Literate example, and only there, a comment is Markdown and where comment lines stand decides
    # what runs. A mark is code; so are its `#!` negations, a `#-` separator, a `#=` block, and a prose
    # comment line moved into or out of a code chunk (the review of 2026-09-23).
    @testset "clause 4 — a Literate mark moves what runs" begin
        L(b, a) = doc("examples/x.jl", b, a)
        # `#` and `##` trade places [ruled 2026-09-24]: RULE.DOC.LITERATE's fix is a comment inside a loop
        # made `##`, and which one a line is decides only whether it shows on the page. A chunk it splits
        # is the docs build's to catch, which a run must pass before it closes.
        loop(m) = "for i in 1:2\n    $m print it\n    println(i)\nend\n"
        @test L(loop("#"), loop("##")) && L(loop("##"), loop("#"))
        @test L(loop("##"), "for i in 1:2\n    ## print each\n    println(i)\nend\n")    # a comment's words, as anywhere
        @test !L(loop("#"), loop("###"))                                  # not a third kind
        @test !L(loop("#"), loop("#md"))                                  # not a mark
        @test !L(loop("##"), "for i in 1:2\n    \n    println(i)\nend\n")      # not removed
        @test !L("x = 1\n# prose\ny = 2\n", "x = 1\n\ny = 2\n")                   # prose made a blank line
        @test !L("f(1,\n\n2)\n", "f(1,\n# prose\n2)\n")                            # a blank line made prose
        # the fifth pass: a trailing negated mark, a tab after `#`, and a prose fence left open
        @test !L("y = x + 41 # the answer\n", "y = x + 41 # the answer #!md\n")
        @test !L("for i in 1:2\n    #\tadd it\n    s = i\nend\n", "for i in 1:2\n    # add it\n    s = i\nend\n")
        @test !L("# Now the answer.\ny = 42\n", "# Now the answer:\n#\n# ````text\ny = 42\n")
        # a run block or a formula spanning a mark line is seen whole
        @test !L("# ```@example\n# x = 1 + 1\n#md # println(x)\n# ```\ny = 1\n", "# ```@example\n# x = error(\"boom\")\n#md # println(x)\n# ```\ny = 1\n")
        @test !L("# ```math\n# E = m c^2\n#md # + 0\n# ```\ny = 1\n", "# ```math\n# E = m c^3\n#md # + 0\n# ```\ny = 1\n")
        before = "x = 1      #src\ny = 2\n# a plain comment\n"
        @test L(before, "x = 1      #src\ny = 2\n# a plain comment, reworded\n")
        @test !L(before, "x = 1      #src\ny = 2\n# a plain comment,\n# over two lines\n")   # a comment line added
        @test !L(before, "x = 1\ny = 2      #src\n# a plain comment\n")
        @test !L("x = 1\n#!nb x = 1\n", "x = 1\n#!nb run(`true`)\n")
        @test !L("x = [1,2,3]\ny = x .+ 1\n", "x = [1,2,3]\n#-\ny = x .+ 1\n")
        @test !L("x = [1,2,3]\ny = x .+ 1\n", "x = [1,2,3]\n# a note\ny = x .+ 1\n")
        @test !L("#=\nold\n=#\nx = 1\n", "#=\nnew\n=#\nx = 1\n")
        # in ordinary source a comment's text may change, but not where it stands
        @test doc("src/M.jl", "x = 1      #src\ny = 2\n", "x = 1      #src, reworded\ny = 2\n")
        @test !doc("src/M.jl", "x = 1      #src\ny = 2\n", "x = 1\ny = 2      #src\n")
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

    # Clause 3: in GBGCodingTools alone, a change confined to a rule's statement or why is documentation.
    # It is the one code-like text the fixer may touch (§4.3 step 3), and everything else about a rule —
    # its id, check, examples, tags, argument order, an interpolated statement — stays code.
    @testset "clause 3 — the prose of a rule, in the tooling package only" begin
        tool = MD.Config(package = "GBGCodingTools", tool = :dev)
        rule(id, st, why; check = "Model.AgentCheck(\"q\", Model.WhyAgent.MEANING)", access = "[Model.Access.NOTHING]") =
            "const R_$id = Model.Rule(\n    id = Symbol(\"RULE.T.$id\"),\n    statement = $st,\n    why = $why,\n" *
            "    check = $check,\n    access = $access)\n"
        before = "module M\nusing ..Model\n" * rule("A", "\"one\"", "\"because\"") * rule("B", "\"two\"", "\"since\"") * "end\n"
        reworded = "module M\nusing ..Model\n" * rule("A", "\"one, reworded\"", "\"because, reworded\"") * rule("B", "\"two, reworded\"", "\"since\"") * "end\n"
        ruling = GD.classify(tool, "src/Rules/t.jl", before, reworded)
        @test ruling.documentation && occursin("clause 3", ruling.reason)           # two statements and a why
        @test !GD.classify(cfg(), "src/Rules/t.jl", before, reworded).documentation  # elsewhere it is code
        # and each of these is code, in the tooling package too
        @test !GD.classify(tool, "src/Rules/t.jl", before, "module M\nusing ..Model\n" * rule("A", "\"one\"", "\"because\""; check = "Model.AgentCheck(\"q2\", Model.WhyAgent.MEANING)") * rule("B", "\"two\"", "\"since\"") * "end\n").documentation
        @test !GD.classify(tool, "src/Rules/t.jl", before, "module M\nusing ..Model\n" * rule("A", "\"one\"", "\"because\""; access = "[Model.Access.SOURCE]") * rule("B", "\"two\"", "\"since\"") * "end\n").documentation
        @test !GD.classify(tool, "src/Rules/t.jl", before, "module M\nusing ..Model\n" * rule("A2", "\"one\"", "\"because\"") * rule("B", "\"two\"", "\"since\"") * "end\n").documentation
        @test !GD.classify(tool, "src/Rules/t.jl", before, "module M\nusing ..Model\n" * rule("A", "\"one \$(x)\"", "\"because\"") * rule("B", "\"two\"", "\"since\"") * "end\n").documentation
        swapped = "module M\nusing ..Model\n" * rule("B", "\"two\"", "\"since\"") * rule("A", "\"one\"", "\"because\"") * "end\n"
        @test !GD.classify(tool, "src/Rules/t.jl", before, swapped).documentation
        role_before = "module M\nconst X = Model.AgentRole(id = :x, instrument = :i, description = \"a\", cap = 1)\nend\n"
        role_after = "module M\nconst X = Model.AgentRole(id = :x, instrument = :i, description = \"b\", cap = 1)\nend\n"
        @test !GD.classify(tool, "src/Roles/t.jl", role_before, role_after).documentation
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
    # CLAUSE 6, ruled 2026-09-21: no edit inside a math span is made automatically. A program has no
    # oracle for whether a formula is true — only the code it documents, and code that is itself wrong
    # would then certify prose matching it — so a changed symbol, number or sign becomes a question.
    @testset "mathematics changed is the owner's to answer" begin
        cfg = G.Model.Config(package = "Sample", tool = :dev)
        page(body) = "# Page\n\n" * body * "\n"
        rule(before, after) = G.Engine.Guard.classify(cfg, "docs/src/index.md", page(before), page(after))

        # prose around a formula may change freely
        @test rule(raw"The energy is $E = \tfrac12 h \sum_i u_i^2$ here.",
                   raw"The discrete energy is $E = \tfrac12 h \sum_i u_i^2$ at every node.").documentation
        # a sign, a factor or a symbol inside one does not
        for (was, now) in ((raw"$E = \tfrac12 h \sum_i u_i^2$", raw"$E = \tfrac13 h \sum_i u_i^2$"),
                           (raw"$d_i = \alpha s_i$",             raw"$d_i = -\alpha s_i$"),
                           (raw"$\bar u$",                       raw"$\hat u$"))
            r = rule("Take $was.", "Take $now.")
            @test !r.documentation
            @test occursin("mathematics changed", r.reason)
        end
        # a formula ADDED where there was none is the same question
        @test !rule("Take the mean.", raw"Take the mean $\bar u$.").documentation
        # one REMOVED is the same question too, and so is a swap: taking away a condition or reversing
        # an inequality changes what the text asserts as surely as adding one (reversed 2026-09-23, from
        # the review: "one removed is not, nothing new is asserted" let both through)
        @test !rule(raw"Take the mean $\bar u$.", "Take the mean.").documentation
        @test !rule(raw"Here $a<b$ and $b<a$.", raw"Here $b<a$ and $a<b$.").documentation
        # every spelling of mathematics is seen, the one the rulebook requires first
        for (was, now) in (("``E = mc^2``", "``E = mc^3``"),
                           (":\n\n```math\nE = mc^2\n```\n", ":\n\n```math\nE = mc^3\n```\n"),
                           (raw"$$E = mc^2$$", raw"$$E = mc^3$$"))
            @test !rule("Take $was.", "Take $now.").documentation
        end
        # and in a docstring, where the backslash is doubled
        jl(d) = "\"\"\"\n    f(k)\n\nThe wavenumber " * d * ".\n\"\"\"\nf(k) = k\n"
        @test !G.Engine.Guard.classify(cfg, "src/M.jl", jl("``k^2``"), jl("``k^3``")).documentation
        @test G.Engine.Guard.classify(cfg, "src/M.jl", jl("``k^2`` squared"), jl("``k^2``, squared")).documentation
        # re-wrapping a formula across a line is not a change to it
        @test G.Engine.Guard.math_changed(raw"$E = \tfrac12 h$", raw"$E =  \tfrac12   h$") == []
        # and a year in a citation is not mathematics
        @test rule("Cooley and Tukey (1965).", "Cooley and Tukey (1965), as cited.").documentation
    end

end

# A generated page is not documentation a fixer may edit. It is written from this package's own values,
# so a fix in it is gone at the next build, and the rulebook page is by construction full of text that
# breaks the rules it states — it quotes every banned spelling in order to ban them. Missing here until
# 2026-09-22, when three readers were launched against such pages on PF's first real run.
@testset "a generated page is not a fixer's to edit" begin
    cfg = G.Model.Config(package = "Sample", tool = :dev,
                         generated = ["docs/src/gbg-rules.md", "docs/src/gbg-readers.md"],
                         copies = ["docs/src/architecture.md" => "docs/ARCHITECTURE.md"],
                         filesets = Dict(G.Model.FileSet.RATIONALE => ["docs/ARCHITECTURE.md"]))
    doc = G.Engine.Guard.on_documentation_list

    @test !doc(cfg, "docs/src/gbg-rules.md")        # generated
    @test !doc(cfg, "docs/src/gbg-readers.md")
    @test !doc(cfg, "docs/src/architecture.md")     # a copy, refused before this and still
    @test doc(cfg, "docs/ARCHITECTURE.md")          # its source, which IS the fixer's
    @test doc(cfg, "docs/src/tutorial.md")          # an ordinary page, untouched by any of it

    # A page not declared generated by THIS package is ordinary: the list is the package's own word.
    bare = G.Model.Config(package = "Sample", tool = :dev)
    @test doc(bare, "docs/src/gbg-rules.md")
end

# A Literate example is a `.jl` file that both runs and renders. Two rules judge it, and until
# 2026-09-22 no path here admitted it, so every finding on one could only park on the owner's queue —
# raisable and unfixable. Reported by PF on its first real run; the hole belonged to every package with
# an examples directory, since the DEFAULT pattern is `examples/**/*.jl` whether or not it is declared.
@testset "a Literate example is a path where documentation lives" begin
    doc = G.Engine.Guard.on_documentation_list
    declared = G.Model.Config(package = "P", tool = :dev,
                              filesets = Dict(G.Model.FileSet.LITERATE => ["examples/HIST_CPU.jl"]))
    bare = G.Model.Config(package = "P", tool = :dev)

    @test doc(declared, "examples/HIST_CPU.jl")           # named by the package
    @test !doc(declared, "examples/other.jl")             # and a narrowed set stays narrow
    @test doc(bare, "examples/HIST_CPU.jl")               # the default pattern, at the top
    @test doc(bare, "examples/gpu/rocm/HIST_ROCm.jl")     # and nested, since `**` spans directories
    @test !doc(bare, "benchmark/run.jl")                  # not an example at all

    # Nothing downstream changed, and this is why: the clauses after the path decide per CHANGE. A
    # comment may be edited; a statement may not; a Literate mark may not move.
    prose = "# a comment\nf(x) = x\n"
    @test G.Engine.Guard.classify(bare, "examples/HIST_CPU.jl", prose, "# a better comment\nf(x) = x\n").documentation
    @test !G.Engine.Guard.classify(bare, "examples/HIST_CPU.jl", prose, "# a comment\nf(x) = x + 1\n").documentation
end
