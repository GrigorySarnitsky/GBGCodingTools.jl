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

# The character of a line that opens or closes a fenced block — ``` or `~~~`, both CommonMark fences —
# or `nothing` for any other line.
function fence_char(line::AbstractString)
    s = strip(line)
    return startswith(s, "```") ? '`' : startswith(s, "~~~") ? '~' : nothing
end

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
                 mask = true, filesets = …, more = …) -> Model.Rule

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
- `more` — further examples, as `(body, breaks, clause)` triples, for a statement with a second clause.

Returns the rule.
"""
function pattern_rule(id, statement, why, pattern, breaking, complying, clause;
                      mask::Bool = true,
                      filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
                      more = Tuple{String,Bool,String}[])
    page(body) = "# A page\n\n" * body * "\n"
    hit = [Model.Location(; file = "docs/src/page.md", line = 3)]
    return Model.Rule(
        id = Symbol(id), statement = statement, why = why,
        intention = Model.Intention.DOCUMENTATION,
        filesets = filesets,
        check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, matching(pattern; mask), false),
        examples = vcat([
            Model.TextExample(Model.FileSet.PAGES, page(breaking), hit, clause),
            Model.TextExample(Model.FileSet.PAGES, page(complying), Model.Location[], clause),
        ], [Model.TextExample(Model.FileSet.PAGES, page(b), breaks ? hit : Model.Location[], c)
            for (b, breaks, c) in more]))
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
    fenced = nothing                   # the open fence's character
    for (i, line) in pairs(split(text, '\n'))
        raw = String(line)
        # A fenced block is code, and a code span is code: an interpolation such as `"\$(a)_\$(b)"` has
        # two dollars with an underscore between them and is not a formula. Both were read as one.
        # `~~~` fences as ``` does, and a fence closes only on its own character.
        c = fence_char(raw)
        c === nothing || ((fenced = fenced === nothing ? c : c == fenced ? nothing : fenced); continue)
        fenced === nothing || continue
        if occursin(DOLLAR_MATH, Texts.mask_code_spans(raw))
            push!(out, Model.Location(; file = "", line = i, text = strip(raw)))
            continue
        end
        for m in eachmatch(r"(?<!`)`([^`\n]+)`(?!`)", raw)
            span = m.captures[1]
            occursin(FORMULA_GLYPHS, span) || continue
            occursin(CODE_SYNTAX, span) && continue                 # a call, an index, an assignment: code
            occursin(DIMENSIONS, strip(span)) && continue           # `64×64×64`, as Julia prints it
            occursin(Regex("^\\s*" * Texts.NAME * "?\\s*\$"), strip(span)) && continue   # one token: an operator named
            # A lone glyph names an operator. A formula written tight — `u×v`, `∇⋅u` — is still a
            # formula, and skipping every span without whitespace let those through.
            length(strip(span)) == 1 && continue                    # `⋅` and its like
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
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nThe cross `u×v` and `∇⋅u` here.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never inside a code span"),
        # Dollars in code are not mathematics: a docstring's fenced example and a code span hold
        # interpolations, and the same text in prose is reported.
        Model.TextExample(Model.FileSet.DOCSTRINGS,
            "\"\"\"\n    f(x)\n\nWrites `\"\\\$(a)_\\\$(b)\"`:\n\n```julia\nname = \"\\\$(a)_\\\$(b).h5\"\n```\n\"\"\"\nf(x) = x\n",
            Model.Location[], "never between dollar signs"),
        Model.TextExample(Model.FileSet.DOCSTRINGS,
            "\"\"\"\n    f(x)\n\nWrites `\"\\\$(a)_\\\$(b)\"`:\n\n~~~julia\nname = \"\\\$(a)_\\\$(b).h5\"\n~~~\n\"\"\"\nf(x) = x\n",
            Model.Location[], "never between dollar signs"),
        Model.TextExample(Model.FileSet.DOCSTRINGS,
            "\"\"\"\n    f(x)\n\nThe bound \\\$\\\\varepsilon_0\\\$ here.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 4)], "never between dollar signs"),
    ])

# The thin space before a differential is the one the statement excepts, in every spelling of the
# differential: `\\,\\mathrm{d}x`, `\\, \\mathrm{d}x`, `\\,dx` and `\\,d^3x`. A differential is `d`
# and ONE variable — a letter or a control word such as `\\theta` — and then no letter: `a\\,d_k` is
# a product with an index, and reading any `d` as a differential let it through.
const DIFFERENTIAL = r"\\,(?!\s*(?:\\mathrm\s*\{\s*d\s*\}|\\mathrm\s+d|d)\s*(?:\^\{?\d+\}?)?\s*(?:\\[A-Za-z]+|[A-Za-z])(?![A-Za-z]))"
const SPACING_PATTERNS = [
    (DIFFERENTIAL, "a thin space by hand", "The integral ``\\int f \\, g`` converges.", "The integral ``\\int f g`` converges."),
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
        # Read in the page's spelling whichever surface this is: a docstring doubles every LaTeX
        # backslash, and each pattern below was written against a single one.
        masked = Texts.single_escapes(Texts.mask_code_spans(line))
        any(p -> occursin(p[1], masked), SPACING_PATTERNS) &&
            push!(out, Model.Location(; file = "", line = i, text = strip(String(line))))
    end
    return out
end

const SPACING = Model.Rule(
    id = Symbol("RULE.TEX.SPACING"),
    statement = "Spacing inside a formula is the renderer's: no thin space except before a differential, no medium or thick space, no negative thin space before a sized delimiter, and none of them doubled.",
    why = "Hand spacing is tuned to one renderer at one font size and is wrong in every other setting.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, spacing, false),
    examples = vcat([[Model.TextExample(Model.FileSet.PAGES, "# A page\n\n" * breaking * "\n",
                                        [Model.Location(; file = "docs/src/page.md", line = 3)], clause),
                      Model.TextExample(Model.FileSet.PAGES, "# A page\n\n" * complying * "\n",
                                        Model.Location[], clause)]
                     for (_, clause, breaking, complying) in SPACING_PATTERNS]...,
                    # The exception, in each spelling of the differential; the same thin space before
                    # anything else is the first clause's hit.
                    [Model.TextExample(Model.FileSet.PAGES,
                        "# A page\n\nThe integral ``\\int f \\, \\mathrm{d}x + \\int g\\,dx + \\int h\\,\\mathrm{d}x`` converges.\n",
                        Model.Location[], "except before a differential"),
                     Model.TextExample(Model.FileSet.PAGES,
                        "# A page\n\nThe integral ``\\int f \\, g \\, \\mathrm{d}x`` converges.\n",
                        [Model.Location(; file = "docs/src/page.md", line = 3)], "except before a differential"),
                     Model.TextExample(Model.FileSet.PAGES,
                        "# A page\n\nThe integrals ``\\int f\\,dx^2``, ``\\int g\\,d\\theta`` and ``\\int h\\,\\mathrm{d}^3x`` converge.\n",
                        Model.Location[], "except before a differential"),
                     Model.TextExample(Model.FileSet.PAGES,
                        "# A page\n\nThe product ``a\\,d_k`` here.\n",
                        [Model.Location(; file = "docs/src/page.md", line = 3)], "except before a differential")],
                    # The same rule on the other surface, where every LaTeX backslash is doubled. Both
                    # directions: a hand-spaced formula in a docstring is still reported, and the
                    # differential — which a docstring must write `\\\\,\\\\mathrm{d}x` — is not.
                    [Model.TextExample(Model.FileSet.DOCSTRINGS,
                        "module M\n\"\"\"\n    f(x)\n\nThe product ``a \\\\; b`` is associative.\n\"\"\"\nf(x) = x\nend\n",
                        [Model.Location(; file = "src/Example.jl", line = 5)], "a medium or thick space by hand"),
                     Model.TextExample(Model.FileSet.DOCSTRINGS,
                        "module M\n\"\"\"\n    f(x)\n\nThe integral ``\\\\int_\\\\Omega f\\\\,\\\\mathrm{d}x`` vanishes.\n\"\"\"\nf(x) = x\nend\n",
                        Model.Location[], "a medium or thick space by hand")]))

const MATHBB_DIGIT = pattern_rule("RULE.TEX.MATHBB",
    "A blackboard-bold digit is not a set; the identity is written \\mathbb{1} only where it means one.",
    "A blackboard digit renders as an outline numeral, which means nothing to a reader of mathematics.",
    # Any digit but a lone 1, which the statement grants as the identity.
    r"\\mathbb\s*\{?\s*(?:[02-9]|1[0-9])",
    "The field ``\\mathbb 2`` of two elements.",
    "The field ``\\mathbb{F}_2`` of two elements.",
    "a blackboard-bold digit is not a set";
    more = [("The identity ``\\mathbb{1}`` acts trivially.", false, "the identity is written \\mathbb{1}"),
            ("The identity ``\\mathbb{12}`` acts trivially.", true, "the identity is written \\mathbb{1}")])

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
    opened = 0
    for (i, line) in pairs(split(text, '\n'))
        # A blank line ends a paragraph, and a span cannot cross one: carried past it, one stray marker
        # — a docstring quoting the marker, a generated empty span — turned every list in the rest of
        # the file into findings three hundred lines away from it.
        isempty(strip(line)) && (opened = 0; continue)
        opened > 0 && occursin(INLINE_LEADER, line) &&
            push!(out, Model.Location(; file = "", line = i, text = "the span opened at line $opened: " * strip(String(line))))
        isodd(count(TWO_BACKTICK, String(line))) && (opened = opened > 0 ? 0 : i)
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
        # A stray marker in one paragraph says nothing about the list after the next blank line.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nUnset, it is ``.\n\n- And a bullet.\n- And another.\n",
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
        s.rule === MATHBF.id && s.name === :mathbf_allowed && s.value isa Vector{String} && union!(allowed, s.value)
    end
    out = Model.Location[]
    for (i, line) in pairs(split(text, '\n'))
        masked = Texts.mask_code_spans(line)
        for m in eachmatch(r"\\mathbf", masked)
            use = "\\mathbf" * braced_group(masked, m.offset + ncodeunits(m.match))
            use in allowed && continue
            push!(out, Model.Location(; file = "", line = i, text = use * " in: " * strip(String(line))))
        end
    end
    return out
end

# The brace group opening at `from`, matched by depth, or nothing where none opens there: a package
# admits `\\mathbf{\\hat{k}}`, and a match that stopped at the first `}` never equalled what it listed.
function braced_group(line::AbstractString, from::Int)
    (from <= lastindex(line) && line[from] == '{') || return ""
    depth = 0; i = from
    while i <= lastindex(line)
        line[i] == '{' && (depth += 1)
        line[i] == '}' && (depth -= 1; depth == 0 && return String(line[from:i]))
        i = nextind(line, i)
    end
    return String(line[from:end])
end

# The one package setting the nested-brace examples run under.
const MATHBF_EXAMPLE = [Model.Setting(rule = Symbol("RULE.TEX.MATHBF"), name = :mathbf_allowed,
                                      value = ["\\mathbf{\\hat{k}}"])]

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
        # A listed string with nested braces is admitted whole, and an unlisted one beside it is not.
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nThe unit vector ``\\mathbf{\\hat{k}}`` here.\n",
            Model.Location[], "only the strings a package lists", MATHBF_EXAMPLE),
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nThe unit vector ``\\mathbf{\\hat{u}}`` here.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "only the strings a package lists", MATHBF_EXAMPLE),
    ])

"""
    RULES

The rules of this batch, in the order they were converted.
"""
const RULES = Model.Rule[RENDERED_MATH, SPACING, MATHBB_DIGIT, FRAC_UNBRACED, LEFTRIGHT,
                         PARTIAL_BARE, BOLDSYMBOL_UNBRACED, INLINE_MATH_SPLIT, MATHBF]

end # module Latex