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

# The bulleted form is an `# Arguments` heading over the bullets (ruled 2026-09-28); the prose form is
# the marker phrase, "The arguments are `a`, …", in a sentence. A bulleted list under the marker phrase —
# the form this rule asked for until that ruling — is neither, and is told so by name, so a consumer
# converting is pointed at the heading and not merely told the form is wrong. A type is held to the rule
# like any call, whatever its `# Fields` section says: it was exempt until the owner's ruling of
# 2026-09-28, which left the arguments of a constructor that are not its fields documented nowhere as
# arguments (GBGPeriodicFields' `LalescuSpline(n, m = 1; T = Float64)`, whose fields are none of them).
# Where a default constructor's arguments repeat the fields, the repetition is the price, ruled so.
# A line may lead into the bullets inside the section — "All keyword, all required:" — and the list is
# still under the heading; a bullet past the next heading is not.
const BULLETED = r"(?m)^#\s+Arguments\s*\n(?:(?!#)[^\n]*\n)*?\s*[-*]\s"
const UNDER_PHRASE = r"The\s+arguments\s+are\b[^\n]*\n\s*\n?\s*[-*]\s"
const IN_PROSE = r"The\s+arguments?\s+(is|are)\s+`"
const WRAPPER_PHRASE = "Allocating form of"
const THRESHOLD = 3

"""
    args_form(src, cfg) -> Vector{Model.Location}

Every docstring that lists its arguments in the wrong form: bullets where prose is called for, prose
where bullets are, or both in one docstring. The arguments are `src`, the Julia source, and `cfg`, which
this rule does not read. Returns one location per docstring.

Three or more arguments, or any keyword, want an `# Arguments` heading over one bullet each; fewer
are bound in running prose. Exempt, as the rule itself says: an internal helper whose name opens with
an underscore, a thin allocating wrapper, a signature with no argument list, and one element-type
keyword bound in a prose clause. A type is not exempt, though its `# Fields` repeat the arguments.
"""
function args_form(src::AbstractString, cfg)
    out = Model.Location[]
    for d in Texts.docstrings_of(src)
        startswith(d.node, "_") && continue
        occursin(WRAPPER_PHRASE, d.text) && continue

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
        if !bulleted && occursin(UNDER_PHRASE, d.text)
            push!(out, Model.Location(; file = "", line = Texts.docstring_line(d, match(UNDER_PHRASE, d.text).offset), node = d.node,
                text = "`$(d.node)` lists its arguments under a sentence: put the bullets under an `# Arguments` heading"))
            continue
        end
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

Three or more arguments, or any keyword, go under `# Arguments`; fewer are bound in running prose.
"""
const ARGS_FORM = Model.Rule(
    id = Symbol("RULE.DOC.ARGS_FORM"),
    statement = "Three or more arguments, or any keyword, are listed under an `# Arguments` heading, one bullet per argument; fewer are bound in running prose, as in \"The arguments are `a`, the first, and `b`, the second.\"; the two are never mixed. A type lists its constructor's arguments so too, even where its `# Fields` section repeats them.",
    why = "A reader looking for one argument of many needs a list; a reader of a two-argument call needs a sentence.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, args_form, false),
    examples = [
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing. The arguments are `a`, the first, `b`, the second, and `c`, the third."),
            [Model.Location(; file = "src/Example.jl", line = 1)], "three or more are listed"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third."),
            Model.Location[], "three or more are listed"),
        # The bulleted list under the marker phrase, the form asked for before 2026-09-28, is a list
        # with no heading over it.
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing. The arguments are:\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third."),
            [Model.Location(; file = "src/Example.jl", line = 4)], "under an `# Arguments` heading"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing. The arguments are\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third."),
            [Model.Location(; file = "src/Example.jl", line = 4)], "under an `# Arguments` heading"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third.\n\nReturns nothing."),
            Model.Location[], "under an `# Arguments` heading"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing.\n\n# Arguments\n\nAll three required:\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third."),
            Model.Location[], "under an `# Arguments` heading"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing.\n\n# Arguments\n\nAll three required.\n\n# Notes\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third."),
            [Model.Location(; file = "src/Example.jl", line = 1)], "under an `# Arguments` heading"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a; opt = 1)", "Does a thing. The arguments are `a`, the first, and `opt`, the option."),
            [Model.Location(; file = "src/Example.jl", line = 1)], "any keyword is listed"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a; opt = 1)", "Does a thing.\n\n# Arguments\n\n- `a` — the first.\n- `opt` — the option."),
            Model.Location[], "any keyword is listed"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b)", "Does a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second."),
            [Model.Location(; file = "src/Example.jl", line = 1)], "fewer are bound in running prose"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b)", "Does a thing. The arguments are `a`, the first, and `b`, the second."),
            Model.Location[], "fewer are bound in running prose"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing. The arguments are `a`, the first.\n\n# Arguments\n\n- `b` — the second.\n- `c` — the third."),
            [Model.Location(; file = "src/Example.jl", line = 1)], "the two are never mixed"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third."),
            Model.Location[], "the two are never mixed"),
        # A type's constructor arguments are listed though its `# Fields` section lists the same names:
        # the fields alone leave the arguments undocumented as arguments (ruled 2026-09-28).
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S(; a = 1, b = 2)\n\nA thing.\n\n# Fields\n\n- `a` — the first.\n- `b` — the second.\n\"\"\"\nBase.@kwdef struct S\n    a = 1\n    b = 2\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "a type lists its constructor's arguments"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S(; a = 1, b = 2)\n\nA thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n\n# Fields\n\n- `a` — the first.\n- `b` — the second.\n\"\"\"\nBase.@kwdef struct S\n    a = 1\n    b = 2\nend\n",
            Model.Location[], "a type lists its constructor's arguments"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[ARGS_FORM]

end # module Arguments
