# The design's §5.2; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.Arguments

The rule that decides how a docstring lists what its operation takes: in bullets or in running prose,
never both. It is the last of the docstring-shape rules and the one with the most exemptions, each of
which is the rule's own.
"""
module Arguments

using ...Model
using ...Texts

# What tells the two forms apart is the BULLET, not the colon. Both open with the same marker phrase, so
# a pattern that stops at the phrase matches the prose form too; and one that demands a colon misses a
# consumer that writes the marker without one, which had three of its field lists read as argument lists
# and reported for using the wrong argument form.
const BULLETED = r"The\s+arguments\s+are\b[^\n]*\n\s*\n?\s*[-*]\s"
const IN_PROSE = r"The\s+arguments?\s+(is|are)\s+`"
const FIELDS_LIST = r"The\s+fields\s+are\b[^\n]*\n\s*\n?\s*[-*]\s"
const WRAPPER_PHRASE = "Allocating form of"
const THRESHOLD = 3

"""
    args_form(src, cfg) -> Vector{Model.Location}

Every docstring that lists its arguments in the wrong form: bullets where prose is called for, prose
where bullets are, or both in one docstring. The arguments are `src`, the Julia source, and `cfg`, which
this rule does not read. Returns one location per docstring.

Three or more arguments, or any keyword, want the bulleted form — the marker phrase, then a colon, then
one bullet per argument; fewer are bound in running prose. Exempt, as the rule itself says: an internal helper whose name opens with an
underscore, a thin allocating wrapper, which documents no arguments of its own, a type documenting its
fields rather than arguments, a signature that holds no argument list, and a single element-type keyword
bound in one prose clause.
"""
function args_form(src::AbstractString, cfg)
    out = Model.Location[]
    for d in Texts.docstrings_of(src)
        startswith(d.node, "_") && continue
        occursin(WRAPPER_PHRASE, d.text) && continue
        occursin(FIELDS_LIST, d.text) && continue

        # The WIDEST of the displayed signatures, not the first: a docstring showing a two- and a
        # four-argument form is a docstring whose reader meets four, and the bulleted form is for them.
        positional, keyword = String[], String[]
        npos, nkw = 0, 0
        for sig in Texts.signature_lines(d.text)
            inside = Texts.argument_list(sig)
            inside === nothing && continue
            a, b = Texts.arity(inside)
            a + b > npos + nkw || continue
            npos, nkw = a, b
            positional, keyword = Texts.parameters(inside)      # the NAMES of the widest, for the carve-out
        end
        npos + nkw == 0 && continue

        prosed = occursin(IN_PROSE, d.text)
        bulleted = occursin(BULLETED, d.text)
        # The rule's last exemption, and no wider: ONE element-type keyword BOUND IN A PROSE CLAUSE. A
        # docstring that binds nothing at all is not a prose clause, and exempting it would turn a hit
        # into silence — the direction that costs a reader something.
        element_type = nkw == 1 && length(keyword) == 1 && first(keyword) in ("T", "eltype", "element_type") &&
                       prosed && npos + nkw < THRESHOLD
        wants_bullets = npos + nkw >= THRESHOLD || (nkw > 0 && !element_type)

        if bulleted && prosed
            push!(out, Model.Location(; file = "", line = d.line, node = d.node,
                text = "`$(d.node)` mixes the two argument forms in one docstring"))
        elseif wants_bullets && !bulleted
            push!(out, Model.Location(; file = "", line = d.line, node = d.node,
                text = "`$(d.node)` takes $npos positional and $nkw keyword argument(s): the bulleted form, not prose"))
        elseif !wants_bullets && bulleted
            push!(out, Model.Location(; file = "", line = d.line, node = d.node,
                text = "`$(d.node)` takes $(npos + nkw) argument(s): bind them in running prose, not bullets"))
        end
    end
    return out
end

doc(binding, body) = "\"\"\"\n    " * binding * "\n\n" * body * "\n\"\"\"\n" *
                     first(split(binding, "(")) * "(x) = x\n"

"""
    ARGS_FORM

Three or more arguments, or any keyword, use the bulleted form; fewer are bound in running prose.
"""
const ARGS_FORM = Model.Rule(
    id = Symbol("RULE.DOC.ARGS_FORM"),
    statement = "Three or more arguments, or any keyword, use the bulleted form, led by the marker phrase and a colon; fewer are bound in running prose; the two are never mixed.",
    why = "A reader looking for one argument of many needs a list; a reader of a two-argument call needs a sentence.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, args_form, false),
    examples = [
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing. The arguments are `a`, the first, `b`, the second, and `c`, the third."),
            [Model.Location(; file = "src/Example.jl", line = 1)], "three or more use the bulleted form"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing. The arguments are:\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third."),
            Model.Location[], "three or more use the bulleted form"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a; opt = 1)", "Does a thing. The arguments are `a`, the first, and `opt`, the option."),
            [Model.Location(; file = "src/Example.jl", line = 1)], "any keyword uses the bulleted form"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a; opt = 1)", "Does a thing. The arguments are:\n\n- `a` — the first.\n- `opt` — the option."),
            Model.Location[], "any keyword uses the bulleted form"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b)", "Does a thing. The arguments are:\n\n- `a` — the first.\n- `b` — the second."),
            [Model.Location(; file = "src/Example.jl", line = 1)], "fewer are bound in running prose"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b)", "Does a thing. The arguments are `a`, the first, and `b`, the second."),
            Model.Location[], "fewer are bound in running prose"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing. The arguments are `a`, the first. The arguments are:\n\n- `b` — the second.\n- `c` — the third."),
            [Model.Location(; file = "src/Example.jl", line = 1)], "the two are never mixed"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing. The arguments are:\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third."),
            Model.Location[], "the two are never mixed"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[ARGS_FORM]

end # module Arguments
