# The design's §5.2, §7, §6; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.Rendering

The rules that catch text which renders wrongly: prose that looks right in the source and comes out as
something else on the page. Each is a rule value carrying its own statement, the program that decides it,
and the examples that show the two agree.

These are documentation rules, so they run in every docs build. They are the first batch of the
conversion: each arrives here with the scan it replaces deleted in the
same commit, so nothing is checked twice and nothing stops being checked.
"""
module Rendering

using ...Model
using ...Texts
import Markdown

# The character of a line that opens or closes a fenced block — ``` or `~~~`, both CommonMark fences —
# or `nothing` for any other line.
function fence_char(line::AbstractString)
    s = strip(line)
    return startswith(s, "```") ? '`' : startswith(s, "~~~") ? '~' : nothing
end

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
    out = Model.Location[]
    fenced = nothing                   # the open fence's character
    for (i, line) in pairs(split(text, '\n'))
        # A fenced block is not the page's own markup: a page showing an example of Markdown shows an
        # indented table on purpose, and it renders as the example it is.
        # `~~~` fences as ``` does, and a fence closes only on its own character.
        c = fence_char(line)
        c === nothing || ((fenced = fenced === nothing ? c : c == fenced ? nothing : fenced); continue)
        fenced === nothing || continue
        occursin(INDENTED_TABLE, line) && push!(out, Model.Location(; file = "", line = i, text = strip(String(line))))
    end
    return out
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
        # Inside a fence the table is an example being shown, not markup being rendered.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nNot this:\n\n```markdown\n- An item:\n\n  | a | b |\n  |---|---|\n```\n",
            Model.Location[], "never indented inside a list item"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nNot this:\n\n~~~markdown\n- An item:\n\n  | a | b |\n  |---|---|\n~~~\n",
            Model.Location[], "never indented inside a list item"),
    ])

# ─────────────────────────────────────────────────────────── a code identifier inside a math span

const MATH_MARKER = r"(?<!`)``(?!`)"
const MATH_COMMAND_ARGS = r"\\(texttt|text|mathrm|operatorname|mathit|mathsf|mathbf|boldsymbol|label|mathcal)\{[^}]*\}"
const MATH_CONTROL_WORD = r"\\[a-zA-Z]+"
# The whole group after `_` or `^`, whatever it holds: `e^{-ikx}` is an exponent, and reading only a
# group of letters as an index left the plane wave reported as a code identifier. A group is dropped
# only when it holds no name, though: `e^{-maxiter}`, `u_{grid_size}` and `x^{n_iter}` are settings set
# as an exponent, and dropping every group hid them. A name there is a run of five letters, or a word
# joined to another by an underscore; `x_i` inside `\sigma_{x_i}` is a nested index, not a name.
const MATH_BRACED_INDEX = r"[_^]\{[^{}]*\}"
const INDEX_NAME = r"[A-Za-z]{2,}_[A-Za-z]|[A-Za-z]_[A-Za-z]{2,}|[a-z]{5,}"
# Three letters, not two. A two-letter run in a physics formula is almost always a product of single
# scalars — `ck_a`, `ac - bd`, `dx` — and reading those as code identifiers reported correct mathematics
# in GBGPeriodicFields. A code identifier short enough to be missed by this is short enough that the
# renderer's italic product looks the same as the name anyway.
const BARE_WORD = r"[a-z]{3,}"
# Four inside a braced group or a parenthesised argument. `\exp(ikx)` and `\frac{abc}{2}` are products
# of scalars set as an argument — the commonest exponent in a spectral package — and a code name
# short enough to hide there is short enough that the italic product reads the same.
const MATH_GROUP = r"\{[^{}]*\}|\([^()]*\)"
const GROUPED_WORD = r"[a-z]{4,}"

"""
    math_spans(text) -> Vector{Tuple{Int,String}}

The inline ```` ``…`` ```` math spans of a text, each as the line it opens on and the span's content. The
argument is `text`, the file's content.

The markers are paired left to right with the open state carried across lines, so a span wrapped over a
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

Every math span holding what is almost certainly a code identifier: a run of three or more lowercase
letters left over once the control words, the arguments of the text-setting commands and the braced
indices holding no name are taken out. The arguments are `text`, the file's content, and `cfg`, which
this rule does not read. Returns one location per span.

The renderer sets such a run as a product of italic single letters, so `maxiter` comes out as seven
italic letters multiplied together rather than as the name of a setting.
"""
function code_in_math(text::AbstractString, cfg)
    out = Model.Location[]
    for (line, span) in math_spans(text)
        stripped = replace(span, MATH_COMMAND_ARGS => " ")
        stripped = replace(stripped, MATH_CONTROL_WORD => " ")
        named_index = any(m -> occursin(INDEX_NAME, m.match), eachmatch(MATH_BRACED_INDEX, stripped))
        stripped = replace(stripped, MATH_BRACED_INDEX => " ")
        grouped = [m.match for m in eachmatch(MATH_GROUP, stripped)]
        rest = replace(stripped, MATH_GROUP => " ")
        (named_index || occursin(BARE_WORD, rest) || any(g -> occursin(GROUPED_WORD, g), grouped)) &&
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
    why = "The renderer sets a run of letters in a math span as a product of italic single letters, not as a name. That remedy is for a name taking part in a formula which says more than the name itself: where the formula only names what the code denotes, the name stays a code span and a connective joins the two (`RULE.TEX.ONE_SPAN`).",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, code_in_math, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe cap ``maxiter`` bounds the loop.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never inside a math span"),
        # A product of single scalars is not an identifier, however many letters sit side by side.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe real part is ``ac - bd`` here.\n",
            Model.Location[], "never inside a math span"),
        # An exponent, an argument or a numerator holding a product of scalars is mathematics; a name
        # long enough to be a name is reported wherever it sits.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe wave ``e^{-ikx}`` is ``\\exp(ikx)`` over ``\\frac{abc}{2}``.\n",
            Model.Location[], "never inside a math span"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe wave ``\\exp(maxiter)`` here.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never inside a math span"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe decay ``e^{-maxiter}`` here.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never inside a math span"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe field ``u_{grid_size}`` and ``x^{n_iter}`` here, over ``\\sigma_{x_i}``.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3), Model.Location(; file = "docs/src/page.md", line = 3)], "never inside a math span"),
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

const ABUT_CODE = "(?:\\[`" * Texts.NAME * "`\\]\\([^)\\n]*\\)|`" * Texts.NAME * "`)"
# Bounded by the backticks alone: the longest formulas are the namings — a symbol and then its whole
# definition — and a length cap dropped exactly those.
const ABUT_MATH = raw"``[^`\n]+``"
const ABUT = Regex("(?:" * ABUT_MATH * raw"\s*" * ABUT_CODE * "|" * ABUT_CODE * raw"\s*" * ABUT_MATH * ")")
const CODE_THEN_MATH = Regex(ABUT_CODE * raw"\s*" * ABUT_MATH)
const MATH_THEN_CODE = Regex(ABUT_MATH * raw"\s*" * ABUT_CODE)
# A formula left open at an edge continues past that edge, and what continues it is the code span on
# that side. Open at the right — an equation ending in a relation — and the name after it is the
# right-hand side. Open at the left, and the name before it is the left-hand side.
#
# A relation, not any operator. `\times` is what closes `` ``\approx 48\times`` ``, a self-contained
# measurement, and a leading `-` opens `` ``-92.0\%`` ``, a self-contained figure; reading either as an
# open edge reported fourteen measurement rows of one package as split formulas with no rewrite.
#
# Each control word ends where the word ends. Without the boundary `\\in` matched the front of `\\int`
# and `\\infty`, `\\le` of `\\left` and `\\ell`, `\\e` — what `\\g?eq?` reduced to — of `\\exp`, `\\eta`
# and `\\epsilon`, and a finished formula opening with any of them was reported as split.
const RELATION = "(?:=|<|>|\\\\(?:equiv|neq|ne|geq|ge|leq|le|to|mapsto|sim|approx|subset|in)(?![A-Za-z]))"
const OPEN_RIGHT = Regex(RELATION * raw"\s*$")
const OPEN_LEFT = Regex("^" * raw"\s*" * RELATION)

"""
    one_span(text, cfg) -> Vector{Model.Location}

Every place a math span and a code span sit against each other, in either order. The arguments are
`text`, the file's prose, and `cfg`, the package's config, which this rule does not read. Returns one
location per line.

Two abutting spans render as two disjoint runs at different sizes, and the reader is left to guess
whether the second continues the first, qualifies it, or defines it. Which remedy applies depends on
what the name is doing, and the rule's own prose says how to choose.

An attributive modifier is not reported, because it has no remedy and needs none: a finished formula
naming a size, a smoothness class or a measurement, set beside the name it qualifies, stands exactly
where an English adjective stands. A connective between them produces a comma where no English sentence has one, so the
rule would be asking for a rewrite that does not exist.

A formula left open at its right edge is a different thing and is still reported. An equation ending in
a relation, whose right-hand side is the name that follows it, is a naming and wants a connective. Span
order alone cannot tell the two apart — that was tried, fits three of the four packages, and fails on
the fourth, whose author writes the naming symbol-first.
"""
function one_span(text::AbstractString, cfg)
    out = Model.Location[]
    # Continuation lines are joined first: prose is hard-wrapped, and one package's policy block ends a
    # line with a name and opens the next with the formula naming it. Deciding adjacency line by line
    # pairs each span with the wrong neighbour — which is what happened to the session converting them.
    for (i, line) in Texts.wrapped_lines(text)
        inner_of(m) = strip(String(match(Regex(ABUT_MATH), m).match)[3:end-2])
        report = false
        m = match(CODE_THEN_MATH, line)
        m === nothing || (report = occursin(OPEN_LEFT, inner_of(m.match)))
        if !report
            m = match(MATH_THEN_CODE, line)
            m === nothing || (report = occursin(OPEN_RIGHT, inner_of(m.match)))
        end
        report && push!(out, Model.Location(; file = "", line = i, text = strip(line)))
    end
    return out
end

"""
    ONE_SPAN

A code span and a math span are never set against each other; which remedy applies depends on what the
name is doing in the sentence.
"""
const ONE_SPAN = Model.Rule(
    id = Symbol("RULE.TEX.ONE_SPAN"),
    statement = "A code span and a math span are never set against each other where the formula continues into or out of the name: where it says more than the name — a definition, or a symbol and then its definition — the name goes inside it as \\texttt{…}, and where it only names what the code denotes, a connective joins the two. A formula finished at the edge the name sits on is not continued by it and is left as it is.",
    why = "Abutting spans render as two disjoint runs at different sizes, leaving the reader to guess whether the second continues the first, qualifies it, or defines it. Apposition says which: `atol` (``\\varepsilon``) keeps the name styled as code — clickable, and the same as every other name on the page — while `\\texttt{atol}` is the math renderer's monospace, and a link wrapped round the whole formula makes its every operator a link to the name.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, one_span, false),
    examples = [
        # The formula names what the code denotes: two spans, joined. A parenthesis, an em dash, a
        # comma or a colon all serve; `≡` is not a connective, it is the thing the connective replaces.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe tolerance `atol` ``\\equiv \\varepsilon`` is fixed.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "a connective joins the two"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe tolerance `atol` (``\\varepsilon``) is fixed.\n",
            Model.Location[], "a connective joins the two"),
        # The same naming with the whole definition after the symbol, which is the longest a formula gets.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe tolerance `atol` ``\\equiv \\varepsilon_{\\mathrm{abs}} + \\varepsilon_{\\mathrm{rel}} \\lvert u \\rvert + \\delta_{\\mathrm{floor}}`` is fixed.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "a connective joins the two"),
        # A membership continues out of the name; a formula opening with `\\int`, `\\exp` or `\\infty`
        # is finished, however alike the first letters look.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe count `n` ``\\in \\mathbb{N}`` is fixed.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "a connective joins the two"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe kernel `kernel` ``\\exp(-r^2)`` and the total `total` ``\\int u\\,dx`` up to `n` ``\\infty``.\n",
            Model.Location[], "a connective joins the two"),
        # The formula says more than the name: one span, the name set as text inside it.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe loop runs while `maxiter` ``\\le n`` holds.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "inside it as \\texttt{…}"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe loop runs while ``\\texttt{maxiter} \\le n`` holds.\n",
            Model.Location[], "inside it as \\texttt{…}"),
        # The naming and the definition in one chain — name, symbol, then what the symbol is. Apposition
        # cannot carry this: the symbol is used again in later formulas, so it must be introduced as a
        # symbol, not parenthesised as an aside. GBGHomogeneousTurbulence writes seventeen of these.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe energy ``\\texttt{kinetic\\_energy} \\equiv k = \\tfrac{1}{2}\\langle u^2 \\rangle`` is reported.\n",
            Model.Location[], "inside it as \\texttt{…}"),
        # A finished formula before a code span is a value used as an adjective, exactly where an English
        # adjective stands, and there is no rewrite: "the (2n+2)×(2m+2), `SMatrix`" is not English.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nIt runs on a ``512^3`` `Float64` grid.\n",
            Model.Location[], "a finished formula is an adjective"),
        # One left open at its right edge is an equation continuing into the name, which is a naming.
        # Span order cannot tell these apart: this one is a naming written symbol-first.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe first bandwidth ``h_1 =`` `hx` is set by the caller.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "a finished formula is an adjective"),
        # A measurement beside a name, which is what a performance document is made of. Not an equation
        # at either edge, so nothing continues and there is nothing to join.
        Model.TextExample(Model.FileSet.RATIONALE,
            "# Measurements\n\n`operators` ``-92.0\\%`` on the CPU path, an ``\\approx 48\\times`` `Float64` gap.\n",
            Model.Location[], "a finished formula is an adjective"),
        # A naming split by a line wrap is still one naming; a list's two items are not one line.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- [`curl`](@ref)\n  ``\\equiv \\nabla\\times`` returns the curl.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "a finished formula is an adjective"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- it uses `foo`\n- ``\\equiv bar`` is the other one.\n",
            Model.Location[], "a finished formula is an adjective"),
    ])

"""
    indented_code(text, cfg) -> Vector{Model.Location}

Every code block in a Markdown page or rationale document that is indented rather than fenced. The
arguments are `text`, the document, and `cfg`, the package's config, which this rule does not read.
Returns one location per block, at its first line.

The page is read by Julia's own Markdown parser, the one Documenter renders with, so a block is
reported exactly when the page would show it as code: a paragraph indented as a list item's
continuation is not one, and a list item's bullets left indented after two blank lines are, which is
how a decision of one package's log rendered as a code block (found measuring this rule,
2026-09-29). Every fence opener is first tagged in its language field, which keeps the text's structure
as it is, and a block the parser returns without the tag is an indented one.
"""
function indented_code(text::AbstractString, cfg)
    lines = split(String(text), '\n')
    tagged = copy(lines); fenced = falses(length(lines)); fence = nothing
    for (i, l) in pairs(lines)
        m = match(r"^(\s*)(`{3,}|~{3,})(.*)$", l)
        if fence === nothing
            m === nothing && continue
            fence = m.captures[2]; fenced[i] = true
            tagged[i] = m.captures[1] * m.captures[2] * FENCE_TAG * m.captures[3]
        else
            fenced[i] = true
            m !== nothing && m.captures[2][1] == fence[1] && length(m.captures[2]) >= length(fence) &&
                isempty(strip(m.captures[3])) && (fence = nothing)
        end
    end
    out = Model.Location[]; from = 1
    for c in code_blocks(Markdown.parse(join(tagged, '\n')))
        startswith(c.language, FENCE_TAG) && continue
        # Where the block is: the first line at or after the last block found, indented by a tab or four
        # spaces, from which every line of the block follows, compared as the parser saw the text. A block
        # of a tab or of an indented fence was dropped, and a block was placed at an earlier line with the
        # same text, until review (2026-09-29).
        code = split(c.code, '\n')
        # and the parser, asked again with a mark on that line, puts the mark in an unfenced code block:
        # a list's paragraph can hold the same text and is not code
        is_code(k) = begin
            marked = copy(tagged); marked[k] = replace(marked[k], r"\S.*$" => "GBGMARK" * strip(marked[k]))
            any(x -> !startswith(x.language, FENCE_TAG) && occursin("GBGMARK", x.code),
                code_blocks(Markdown.parse(join(marked, '\n'))))
        end
        same(k) = k + length(code) - 1 <= length(tagged) &&
                  occursin(r"^(\t| {4})", tagged[k]) &&
                  all(i -> strip(tagged[k + i - 1]) == strip(code[i]), eachindex(code)) && is_code(k)
        n = findfirst(same, from:length(tagged))
        n === nothing && continue
        n = from + n - 1; from = n + length(code)
        push!(out, Model.Location(; file = "", line = n,
            text = "an indented code block: fence it with three backticks, or unindent it if it is prose"))
    end
    return out
end

const FENCE_TAG = "gbgfenced"

# Every code block of a parsed document, in lists, admonitions, quotes and footnotes too.
function code_blocks(x, acc = Markdown.Code[])
    x isa Markdown.Code && push!(acc, x)
    if x isa Markdown.MD || x isa Markdown.Admonition || x isa Markdown.BlockQuote
        foreach(c -> code_blocks(c, acc), x.content)
    elseif x isa Markdown.List
        foreach(item -> foreach(c -> code_blocks(c, acc), item), x.items)
    elseif x isa Markdown.Footnote
        x.text === nothing || foreach(c -> code_blocks(c, acc), x.text)
    end
    return acc
end

const FENCED_CODE = Model.Rule(
    id = Symbol("RULE.DOC.FENCED_CODE"),
    statement = "A code block in a page or a rationale document is fenced with three backticks, never indented; a docstring's indented signature is exempt.",
    why = "An indented block is code only by context, so a program reading the page cannot tell it from an indented paragraph without the parser's whole reading, and a list item left indented after a blank line renders as code nobody wrote.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, indented_code, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES, "# Page\n\nRun it:\n\n    julia --project\n",
            [Model.Location(; file = "docs/src/page.md", line = 5)], "fenced with three backticks, never indented"),
        Model.TextExample(Model.FileSet.PAGES, "# Page\n\nRun it:\n\n```sh\njulia --project\n```\n",
            Model.Location[], "fenced with three backticks, never indented"),
        # A list item's continuation paragraph is indented and is prose; a fence inside an item, and the
        # item's next paragraph after it, keep their structure.
        Model.TextExample(Model.FileSet.PAGES, "# Page\n\n1. First item,\n    continued.\n\n    A second paragraph of it.\n\n    ```julia\n    x = 1\n    ```\n\n    And prose after the code.\n",
            Model.Location[], "fenced with three backticks, never indented"),
        # Two blank lines end the item, and its bullets left indented are a code block.
        Model.TextExample(Model.FileSet.PAGES, "# Page\n\n1. An item.\n\n\n    - **A bullet.** Of the item.\n",
            [Model.Location(; file = "docs/src/page.md", line = 6)], "fenced with three backticks, never indented"),
        # a tab-indented block, and a fence indented four spaces, which renders with its backticks showing
        Model.TextExample(Model.FileSet.PAGES, "# Page\n\nRun it:\n\n\tjulia --project\n",
            [Model.Location(; file = "docs/src/page.md", line = 5)], "fenced with three backticks, never indented"),
        Model.TextExample(Model.FileSet.PAGES, "# Page\n\nRun it:\n\n    ```sh\n    julia --project\n    ```\n",
            [Model.Location(; file = "docs/src/page.md", line = 5)], "fenced with three backticks, never indented"),
        # the block, not an earlier list paragraph with the same text
        Model.TextExample(Model.FileSet.PAGES, "# Page\n\n1. An item,\n\n    x = 1\n\nThen:\n\n    x = 1\n",
            [Model.Location(; file = "docs/src/page.md", line = 9)], "fenced with three backticks, never indented"),
    ])

"""
    RULES

The rules of this batch, in the order they were converted.
"""
const RULES = Model.Rule[TABLE_TOP_LEVEL, CODE_IN_MATH, SWALLOWED_ESCAPE, REF_ABUT_RULE, ONE_SPAN, FENCED_CODE]

end # module Rendering