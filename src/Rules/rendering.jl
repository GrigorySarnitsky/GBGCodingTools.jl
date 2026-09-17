"""
    Rules.Rendering

The rules that catch text which RENDERS WRONGLY: prose that looks right in the source and comes out as
something else on the page. Each is a rule value carrying its own statement, the program that decides it,
and the examples that show the two agree (`docs/ARCHITECTURE.md` §5.2, §7).

These are documentation rules, so they run in every docs build. They are the first batch of the
conversion (`IMPLEMENTATION.md` §6, batch a): each arrives here with the scan it replaces deleted in the
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

"""
    RULES

The rules of this batch, in the order they were converted.
"""
const RULES = Model.Rule[TABLE_TOP_LEVEL, CODE_IN_MATH]

end # module Rendering
