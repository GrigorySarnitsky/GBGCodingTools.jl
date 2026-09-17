# The design's §5.2, §7, §6; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.Rendering

The rules that catch text which RENDERS WRONGLY: prose that looks right in the source and comes out as
something else on the page. Each is a rule value carrying its own statement, the program that decides it,
and the examples that show the two agree.

These are documentation rules, so they run in every docs build. They are the first batch of the
conversion: each arrives here with the scan it replaces deleted in the
same commit, so nothing is checked twice and nothing stops being checked.
"""
module Rendering

using ...Model

# ─────────────────────────────────────────────────────────────────── a table indented into a list

const INDENTED_TABLE = r"^[ \t]+\|[-:| ]+\|"

"""
    indented_table(text, cfg) -> Vector{Model.Location}

Every separator row of a Markdown table that is indented rather than at the left margin. The arguments
are `text`, the file's content, and `cfg`, the package's config, which this rule does not read. Returns
one location per offending row.

Indentation is what decides it: Markdown reads an indented block as code, so an indented table renders as
the literal pipes and dashes a reader sees in the source rather than as a table.
"""
function indented_table(text::AbstractString, cfg)
    return [Model.Location(; file = "", line = i, text = strip(String(line)))
            for (i, line) in pairs(split(text, '\n')) if occursin(INDENTED_TABLE, line)]
end

"""
    TABLE_TOP_LEVEL

A Markdown table is top-level, never indented inside a list item.
"""
const TABLE_TOP_LEVEL = Model.Rule(
    id = Symbol("RULE.DOC.TABLE_TOP_LEVEL"),
    statement = "A Markdown table is top-level, never indented inside a list item.",
    why = "Markdown reads an indented block as code, so an indented table renders as the pipes and dashes themselves.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, indented_table, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- An item, and its table:\n\n  | a | b |\n  |---|---|\n  | 1 | 2 |\n",
            [Model.Location(; file = "docs/src/page.md", line = 6)], "never indented inside a list item"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- An item, and its table:\n\n| a | b |\n|---|---|\n| 1 | 2 |\n",
            Model.Location[], "never indented inside a list item"),
    ])

# ─────────────────────────────────────────────────────────── a code identifier inside a math span

const MATH_MARKER = r"(?<!`)``(?!`)"
const MATH_COMMAND_ARGS = r"\\(texttt|text|mathrm|operatorname|mathit|mathsf|mathbf|boldsymbol|label|mathcal)\{[^}]*\}"
const MATH_CONTROL_WORD = r"\\[a-zA-Z]+"
const MATH_BRACED_INDEX = r"[_^]\{[a-z]+\}"
const BARE_WORD = r"[a-z]{2,}"

"""
    math_spans(text) -> Vector{Tuple{Int,String}}

The inline ```` ``…`` ```` math spans of a text, each as the line it opens on and the span's content. The
argument is `text`, the file's content.

The markers are paired left to right with the open state carried ACROSS lines, so a span wrapped over a
line break pairs correctly rather than leaving every span after it misread. Returns the spans.
"""
function math_spans(text::AbstractString)
    out = Tuple{Int,String}[]
    open_ = false; buf = IOBuffer(); startline = 0
    for (n, line) in pairs(split(text, '\n'))
        parts = split(line, MATH_MARKER)
        for (i, part) in enumerate(parts)
            if i > 1
                if open_
                    push!(out, (startline, String(take!(buf)))); open_ = false
                else
                    open_ = true; startline = n
                end
            end
            open_ && write(buf, part)
        end
        open_ && write(buf, " ")
    end
    return out
end

"""
    code_in_math(text, cfg) -> Vector{Model.Location}

Every math span holding what is almost certainly a code identifier: a run of two or more lowercase letters
left over once the control words, the arguments of the text-setting commands and the braced indices are
taken out. The arguments are `text`, the file's content, and `cfg`, the package's config, which this rule
does not read. Returns one location per span.

The renderer sets such a run as a product of italic single letters, so `maxiter` comes out as seven
italic letters multiplied together rather than as the name of a setting.
"""
function code_in_math(text::AbstractString, cfg)
    out = Model.Location[]
    for (line, span) in math_spans(text)
        stripped = replace(span, MATH_COMMAND_ARGS => " ")
        stripped = replace(stripped, MATH_CONTROL_WORD => " ", MATH_BRACED_INDEX => " ")
        occursin(BARE_WORD, stripped) &&
            push!(out, Model.Location(; file = "", line, text = "``" * strip(span) * "``"))
    end
    return out
end

"""
    CODE_IN_MATH

A code identifier never sits inside a math span; inside a formula it is `\\texttt{…}`.
"""
const CODE_IN_MATH = Model.Rule(
    id = Symbol("RULE.TEX.CODE_IN_MATH"),
    statement = "A code identifier never sits inside a math span; inside a formula it is written \\texttt{…}.",
    why = "The renderer sets a run of letters in a math span as a product of italic single letters, not as a name.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, code_in_math, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe cap ``maxiter`` bounds the loop.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never inside a math span"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe cap `maxiter` bounds the loop.\n",
            Model.Location[], "never inside a math span"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nIn a formula it is ``\\texttt{maxiter} \\le n``.\n",
            Model.Location[], "written \\texttt{…} inside a formula"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nIn a formula it is ``maxiter \\le n``.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "written \\texttt{…} inside a formula"),
    ])

# ─────────────────────────────────────────────────────────── a LaTeX escape the parser swallows

const SWALLOWED = r"(?<!\\)\\[abefnrtv0-7xuU]"

"""
    swallowed_escape(text, cfg) -> Vector{Model.Location}

Every single-backslash escape inside a Julia docstring that the parser consumes before the documentation
build ever sees it. The arguments are `text`, the file's prose, and `cfg`, the package's config, which
this rule does not read. Returns one location per line holding one.

`\\alpha` written with one backslash reaches Documenter as a bell character and a word; the docstring
renders with the formula silently missing. Doubling the backslash is the whole fix, which is why this
reads the raw line rather than the parsed string.
"""
function swallowed_escape(text::AbstractString, cfg)
    return [Model.Location(; file = "", line = i, text = strip(String(line)))
            for (i, line) in pairs(split(text, '\n')) if occursin(SWALLOWED, line)]
end

"""
    SWALLOWED_ESCAPE

Inside a Julia docstring every LaTeX backslash is doubled.
"""
const SWALLOWED_ESCAPE = Model.Rule(
    id = Symbol("RULE.TEX.SWALLOWED_ESCAPE"),
    statement = "Inside a Julia docstring every LaTeX backslash is doubled; a single-backslash escape is swallowed by the parser.",
    why = "Julia consumes the escape when it reads the string, so the formula never reaches the documentation build at all.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, swallowed_escape, false),
    examples = [
        Model.TextExample(Model.FileSet.DOCSTRINGS,
            "\"\"\"\n    f(x)\n\nThe gradient \\nabla f of the field.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 4)], "every backslash is doubled"),
        Model.TextExample(Model.FileSet.DOCSTRINGS,
            "\"\"\"\n    f(x)\n\nThe gradient \\\\nabla f of the field.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "every backslash is doubled"),
    ])

# ────────────────────────────────────────────────────────── a link abutting a second code span

const REF_ABUT = r"\]\(@ref[^)]*\)`"

"""
    ref_abut(text, cfg) -> Vector{Model.Location}

Every cross-reference link immediately followed by a code span. The arguments are `text`, the file's
prose, and `cfg`, the package's config, which this rule does not read. Returns one location per line.

The two render as adjacent monospace chips with a visible seam down the middle, as though the name had
been cut in half; the whole call belongs inside the link text.
"""
function ref_abut(text::AbstractString, cfg)
    return [Model.Location(; file = "", line = i, text = strip(String(line)))
            for (i, line) in pairs(split(text, '\n')) if occursin(REF_ABUT, line)]
end

"""
    REF_ABUT

A cross-reference never abuts a second code span; the whole call is the link text.
"""
const REF_ABUT_RULE = Model.Rule(
    id = Symbol("RULE.DOC.REF_ABUT"),
    statement = "A cross-reference never abuts a second code span; the whole call is the link text.",
    why = "The two render as adjacent monospace chips with a seam, as though the name had been cut in half.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, ref_abut, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nCall [`measure`](@ref)`(u)` on the field.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never abuts a second code span"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nCall [`measure(u)`](@ref measure) on the field.\n",
            Model.Location[], "never abuts a second code span"),
    ])

# ──────────────────────────────────────────────────── a formula split across two kinds of span

const ABUT_CODE = raw"(?:\[`[A-Za-z_][A-Za-z0-9_!]*`\]\([^)\n]*\)|`[A-Za-z_][A-Za-z0-9_!]*`)"
const ABUT_MATH = raw"``[^`\n]{1,60}``"
const ABUT = Regex("(?:" * ABUT_MATH * raw"\s*" * ABUT_CODE * "|" * ABUT_CODE * raw"\s*" * ABUT_MATH * ")")

"""
    one_span(text, cfg) -> Vector{Model.Location}

Every place a math span and a code span sit against each other, in either order. The arguments are
`text`, the file's prose, and `cfg`, the package's config, which this rule does not read. Returns one
location per line.

Binding a code object to its symbol is ONE span — `\\texttt{name} \\equiv \\varepsilon` — because two
abutting spans render as two disjoint runs at different sizes. The known false positive is plain
adjacency of unrelated things, which is why this rule is worth reading before obeying.
"""
function one_span(text::AbstractString, cfg)
    return [Model.Location(; file = "", line = i, text = strip(String(line)))
            for (i, line) in pairs(split(text, '\n')) if occursin(ABUT, line)]
end

"""
    ONE_SPAN

A formula is one LaTeX span, never split across a math span and an adjacent code span.
"""
const ONE_SPAN = Model.Rule(
    id = Symbol("RULE.TEX.ONE_SPAN"),
    statement = "A formula is one LaTeX span, never split across a math span and an adjacent code span.",
    why = "Two abutting spans render as two disjoint runs at different sizes, not as one binding.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, one_span, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe tolerance `atol` ``\\equiv \\varepsilon`` is fixed.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never split across two spans"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe tolerance ``\\texttt{atol} \\equiv \\varepsilon`` is fixed.\n",
            Model.Location[], "never split across two spans"),
    ])

"""
    RULES

The rules of this batch, in the order they were converted.
"""
const RULES = Model.Rule[TABLE_TOP_LEVEL, CODE_IN_MATH, SWALLOWED_ESCAPE, REF_ABUT_RULE, ONE_SPAN]

end # module Rendering