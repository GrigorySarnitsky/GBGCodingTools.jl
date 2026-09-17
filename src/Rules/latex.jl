# The design's §6; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.Latex

The LaTeX idiom: the spellings the house uses inside a formula, and the ones that render badly or not at
all. Each rule is a pattern over the prose, with code spans masked first so that a pattern about
mathematics never matches a code span that merely looks like one.

These are the third batch of the conversion. They are small, and they
are numerous for the same reason: each records one way a formula came out wrong on a page.
"""
module Latex

using ...Model
using ...Texts
using ...Texts

"""
    matching(pattern; mask = true) -> Function

A check that reports every line matching `pattern`. The arguments are:

- `pattern` — the pattern to look for.
- `mask` — whether single-backtick code spans are blanked first.

Returns the check function, which takes the text and the config and gives back one location per matching
line.
"""
function matching(pattern::Regex; mask::Bool = true)
    return function (text::AbstractString, cfg)
        out = Model.Location[]
        for (i, line) in pairs(split(text, '\n'))
            occursin(pattern, mask ? Texts.mask_code_spans(line) : String(line)) &&
                push!(out, Model.Location(; file = "", line = i, text = strip(String(line))))
        end
        return out
    end
end

"""
    pattern_rule(id, statement, why, pattern, breaking, complying, clause;
                 mask = true, filesets = …) -> Model.Rule

One rule of this family: a pattern, the two examples that show the check matches the statement, and the
prose that says why it exists. The arguments are:

- `id` — the rule's identifier.
- `statement` — the rule in plain English.
- `why` — what goes wrong without it.
- `pattern` — what the check looks for.
- `breaking` — a line the rule forbids.
- `complying` — the same line written correctly.
- `clause` — the clause of the statement these two are for.
- `mask` — whether code spans are blanked before matching.
- `filesets` — the file sets it runs over.

Returns the rule.
"""
function pattern_rule(id, statement, why, pattern, breaking, complying, clause;
                      mask::Bool = true,
                      filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS])
    page(body) = "# A page\n\n" * body * "\n"
    return Model.Rule(
        id = Symbol(id), statement = statement, why = why,
        intention = Model.Intention.DOCUMENTATION,
        filesets = filesets,
        check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, matching(pattern; mask), false),
        examples = [
            Model.TextExample(Model.FileSet.PAGES, page(breaking),
                              [Model.Location(; file = "docs/src/page.md", line = 3)], clause),
            Model.TextExample(Model.FileSet.PAGES, page(complying), Model.Location[], clause),
        ])
end

const DOLLAR_MATH = r"\$[^$\n]*[\\_^{}][^$\n]*\$"
const FORMULA_GLYPHS = r"[≤≥≠∈∉∇Δ⟨⟩‖√×⋅]"
# Every glyph above is also legal Julia — `≤`, `×`, `⋅`, `√` and `∈` are operators, `Δ` is an ordinary
# letter in a name — so the glyph alone cannot tell a formula from code. What tells them apart is
# SYNTAX: a call, an index, a keyword argument, an assignment, a field access or a lambda arrow is code
# and nothing else. A code span holding one of those is naming code, however mathematical it looks.
const CODE_SYNTAX = r"[(\[{=;\"]|->|\w\.\w"
# Julia prints an array's dimensions this way, and a docstring quoting that print is quoting code.
const DIMENSIONS = r"^\d+(?:×\d+)+$"

"""
    rendered_math(text, cfg) -> Vector{Model.Location}

Every formula written so that it does not render as mathematics: one delimited by dollar signs, and one
put inside a code span. The arguments are `text`, the file's prose, and `cfg`, which this rule does not
read. Returns one location per line.

Both come out as something else on the page — dollars and backslashes as literal text, a code span as
monospace at the wrong size and weight — which is why one rule covers the two: they are the same defect
with two spellings.
"""
function rendered_math(text::AbstractString, cfg)
    out = Model.Location[]
    for (i, line) in pairs(split(text, '\n'))
        raw = String(line)
        if occursin(DOLLAR_MATH, raw)
            push!(out, Model.Location(; file = "", line = i, text = strip(raw)))
            continue
        end
        for m in eachmatch(r"(?<!`)`([^`\n]+)`(?!`)", raw)
            span = m.captures[1]
            occursin(FORMULA_GLYPHS, span) || continue
            occursin(CODE_SYNTAX, span) && continue                 # a call, an index, an assignment: code
            occursin(DIMENSIONS, strip(span)) && continue           # `64×64×64`, as Julia prints it
            occursin(Regex("^\\s*" * Texts.NAME * "?\\s*\$"), strip(span)) && continue   # one token: an operator named
            length(split(strip(span))) == 1 && !occursin(r"\s", strip(span)) && continue     # `⋅` and its like
            push!(out, Model.Location(; file = "", line = i, text = "`" * span * "`"))
            break
        end
    end
    return out
end

const RENDERED_MATH = Model.Rule(
    id = Symbol("RULE.TEX.RENDERED_MATH"),
    statement = "Mathematics is written in a double-backtick span: never between dollar signs, and never inside a code span.",
    why = "Dollars render as literal text and a code span renders as monospace; neither comes out as mathematics.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, rendered_math, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nThe bound \$\\varepsilon_0\$ here.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never between dollar signs"),
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nThe bound ``\\varepsilon_0`` here.\n",
            Model.Location[], "never between dollar signs"),
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nThe bound `x ≤ y` holds.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never inside a code span"),
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nThe bound ``x \\le y`` holds.\n",
            Model.Location[], "never inside a code span"),
        # A code span holding CODE is not mathematics, however mathematical its glyphs look: `⋅` and `×`
        # are Julia operators, and `64×64×64` is how Julia prints an array's dimensions.
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nThe bound `x ≤ y` in `clamp(x ≤ y, lo, hi)`.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never inside a code span"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe operator `⋅` contracts a `64×64×64` grid through `dot(u ⋅ v, w)`.\n",
            Model.Location[], "never inside a code span"),
    ])

const SPACING_PATTERNS = [
    (r"\\,(?!\\mathrm[ {]d)", "a thin space by hand", "The integral ``\\int f \\, g`` converges.", "The integral ``\\int f g`` converges."),
    (r"\\[;:](?![a-zA-Z])", "a medium or thick space by hand", "The product ``a \\; b`` is associative.", "The product ``a b`` is associative."),
    (r"\\!\\[bB]ig[lr]", "a negative thin space before a sized delimiter", "The sum ``\\!\\bigl( a \\bigr)`` is finite.", "The sum ``\\bigl( a \\bigr)`` is finite."),
    (r"\\!\\!", "doubled negative thin spaces", "The integral ``\\int\\!\\! f`` over the domain.", "The integral ``\\int f`` over the domain."),
]

"""
    spacing(text, cfg) -> Vector{Model.Location}

Every place spacing inside a formula is set by hand rather than left to the renderer: a thin space, a
medium or thick space, a negative thin space pulling a sized delimiter closer, and two of those doubled.
The arguments are `text`, the file's prose, and `cfg`, which this rule does not read. Returns one
location per line.

The exception is the one the rule states: a thin space before a differential is idiom, not tuning.
"""
function spacing(text::AbstractString, cfg)
    out = Model.Location[]
    for (i, line) in pairs(split(text, '\n'))
        masked = Texts.mask_code_spans(line)
        any(p -> occursin(p[1], masked), SPACING_PATTERNS) &&
            push!(out, Model.Location(; file = "", line = i, text = strip(String(line))))
    end
    return out
end

const SPACING = Model.Rule(
    id = Symbol("RULE.TEX.SPACING"),
    statement = "Spacing inside a formula is the renderer's: no thin space, no medium or thick space, no negative thin space before a sized delimiter, and none of them doubled.",
    why = "Hand spacing is tuned to one renderer at one font size and is wrong in every other setting.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, spacing, false),
    examples = vcat([[Model.TextExample(Model.FileSet.PAGES, "# A page\n\n" * breaking * "\n",
                                        [Model.Location(; file = "docs/src/page.md", line = 3)], clause),
                      Model.TextExample(Model.FileSet.PAGES, "# A page\n\n" * complying * "\n",
                                        Model.Location[], clause)]
                     for (_, clause, breaking, complying) in SPACING_PATTERNS]...))

const MATHBB_DIGIT = pattern_rule("RULE.TEX.MATHBB",
    "A blackboard-bold digit is not a set; the identity is written \\mathbb{1} only where it means one.",
    "A blackboard digit renders as an outline numeral, which means nothing to a reader of mathematics.",
    r"\\mathbb\s*\{?\s*[0-9]",
    "The field ``\\mathbb 2`` of two elements.",
    "The field ``\\mathbb{F}_2`` of two elements.",
    "a blackboard-bold digit is not a set")

const FRAC_UNBRACED = pattern_rule("RULE.TEX.FRAC_BRACED",
    "Both arguments of a fraction are braced.",
    "An unbraced fraction takes one character as its numerator and silently drops the rest.",
    r"\\[dt]?frac\s*[^{\s]",
    "The ratio ``\\frac12`` is a half.",
    "The ratio ``\\frac{1}{2}`` is a half.",
    "both arguments are braced")

const LEFTRIGHT = pattern_rule("RULE.TEX.LEFTRIGHT",
    "A sized delimiter names what it sizes: \\left( pairs with \\right), and neither stands alone.",
    "An unpaired sizing command is a LaTeX error, and the whole formula fails to render.",
    r"\\left(?![a-zA-Z]|\\\{)|\\right(?![a-zA-Z]|\.)",
    "The norm ``\\left\\| u \\right.`` is bounded.",
    "The norm ``\\lVert u \\rVert`` is bounded.",
    "neither stands alone")

const PARTIAL_BARE = pattern_rule("RULE.TEX.PARTIAL",
    "A partial derivative names its index as a symbol, not as a bare letter subscript.",
    "A bare index reads as a variable named i rather than as the direction differentiated in.",
    r"\\partial_[ijk](?![A-Za-z])",
    "The divergence ``\\partial_i u_i`` vanishes.",
    "The divergence ``\\partial_{x_i} u_i`` vanishes.",
    "not as a bare letter subscript")

const BOLDSYMBOL_UNBRACED = pattern_rule("RULE.TEX.BOLDSYMBOL_BRACED",
    "A bold symbol braces its argument.",
    "Unbraced, it bolds the next character alone and leaves the rest of the name upright.",
    r"\\boldsymbol(?!\{)",
    "The velocity ``\\boldsymbol u`` is solenoidal.",
    "The velocity ``\\boldsymbol{u}`` is solenoidal.",
    "braces its argument")

const INLINE_LEADER = r"^\s{0,3}([-*+>]|\d+[.)])\s"
const TWO_BACKTICK = r"(?<!`)``(?!`)"

"""
    inline_math_split(text, cfg) -> Vector{Model.Location}

Every place an inline math span is broken across a line by a list or blockquote leader. The arguments are
`text`, the file's prose, and `cfg`, which this rule does not read. Returns one location per break.

A span that opens on one line and is continued after a bullet marker does not close where its author
thinks: the marker lands inside the formula, and everything to the next marker renders as mathematics.
"""
function inline_math_split(text::AbstractString, cfg)
    out = Model.Location[]
    inspan = false
    for (i, line) in pairs(split(text, '\n'))
        inspan && occursin(INLINE_LEADER, line) &&
            push!(out, Model.Location(; file = "", line = i, text = strip(String(line))))
        isodd(count(TWO_BACKTICK, String(line))) && (inspan = !inspan)
    end
    return out
end

const INLINE_MATH_SPLIT = Model.Rule(
    id = Symbol("RULE.TEX.INLINE_ONE_LINE"),
    statement = "An inline math span opens and closes on one line, never across a list or blockquote marker.",
    why = "A marker inside an open span lands in the formula, and the prose after it renders as mathematics.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, inline_math_split, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe bound ``x \\le\n- y`` holds.\n",
            [Model.Location(; file = "docs/src/page.md", line = 4)], "never across a marker"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe bound ``x \\le y`` holds.\n\n- And a bullet.\n",
            Model.Location[], "never across a marker"),
    ])

# ────────────────────────────────────────────────────────────── the bold symbols a package admits

"""
    MATHBF_ALLOWED

The `\\mathbf` strings a package admits. Every package is granted `\\mathbf{1}`, the identity; anything
else is the package's own notation and is listed by a [`Model.Setting`](@ref).
"""
const MATHBF_ALLOWED = Model.Parameter(:mathbf_allowed, String[])

"""
    mathbf(text, cfg) -> Vector{Model.Location}

Every use of bold that the package has not admitted. The arguments are `text`, the file's prose, and
`cfg`, the package's config, which supplies the admitted strings. Returns one location per use.

Bold in mathematics means one thing in a package and another in the next; a package states which strings
it uses, and every other one is a reader's guess.
"""
function mathbf(text::AbstractString, cfg)
    allowed = Set{String}(["\\mathbf{1}"])
    for s in cfg.settings
        s.name === :mathbf_allowed && s.value isa Vector{String} && union!(allowed, s.value)
    end
    out = Model.Location[]
    for (i, line) in pairs(split(text, '\n'))
        for m in eachmatch(r"\\mathbf(\{[^}]*\})?", Texts.mask_code_spans(line))
            m.match in allowed && continue
            push!(out, Model.Location(; file = "", line = i, text = m.match * " in: " * strip(String(line))))
        end
    end
    return out
end

const MATHBF = Model.Rule(
    id = Symbol("RULE.TEX.MATHBF"),
    statement = "Bold is admitted only for the strings a package lists, plus the identity, which every package is granted.",
    why = "Bold means one thing in one package and another in the next; unlisted, it is a reader's guess.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, mathbf, false),
    parameters = Model.Parameter[MATHBF_ALLOWED],
    examples = [
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nThe velocity ``\\mathbf{u}`` is solenoidal.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "only the strings a package lists"),
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nThe identity ``\\mathbf{1}`` acts trivially.\n",
            Model.Location[], "only the strings a package lists"),
    ])

"""
    RULES

The rules of this batch, in the order they were converted.
"""
const RULES = Model.Rule[RENDERED_MATH, SPACING, MATHBB_DIGIT, FRAC_UNBRACED, LEFTRIGHT,
                         PARTIAL_BARE, BOLDSYMBOL_UNBRACED, INLINE_MATH_SPLIT, MATHBF]

end # module Latex