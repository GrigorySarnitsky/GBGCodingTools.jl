# The design's §5.2 and §7; the coordinates live here rather than in a docstring, which must read
# complete at the REPL.
"""
    Rules.Reflection

The rules that hold a docstring against the thing it documents: every argument accounted for, and no
target linked twice in one docstring. Both read the source rather than the loaded package, because what
they compare is the docstring's own signature with its own body.

These are the fifth batch of the conversion. The two that need the package LOADED — the displayed
signature against the method table, and a cross-module name linked at its first mention — are the batch
after this one.
"""
module Reflection

using ...Model
using ...Texts

const WRAPPER_PHRASE = "Allocating form of"
const THRESHOLD = 3

"""
    argcov(src, cfg) -> Vector{Model.Location}

Every argument of a docstring's signature that its body never mentions. The arguments are `src`, the
Julia source, and `cfg`, the package's config, which this rule does not read. Returns one location per
undocumented argument.

It runs FROM THE SIGNATURE, not from the prose: a body that lists three arguments where the signature
takes four is the case this exists to catch, and a check that reads the prose first cannot see the
fourth. Exempt, as the rule says: an internal helper, a thin allocating wrapper, and a call short enough
to bind its arguments in prose.
"""
function argcov(src::AbstractString, cfg)
    out = Model.Location[]
    for d in Texts.docstrings_of(src)
        startswith(d.node, "_") && continue
        occursin(WRAPPER_PHRASE, d.text) && continue
        signature = replace(Texts.signature_line(d.text), r"\s*->.*$" => "")
        inside = Texts.argument_list(signature)
        inside === nothing && continue
        positional, keyword = Texts.parameters(inside)
        length(positional) + length(keyword) < THRESHOLD && isempty(keyword) && continue
        for p in vcat(positional, keyword)
            # A splat may be documented by its base name or with its dots — `rows` or `kwargs...` — and
            # both are the same argument to a reader.
            base = replace(p, r"\.\.\.$" => "")
            q = "\\Q" * base * "\\E"
            documented = occursin(Regex("`" * q * "(?:\\.\\.\\.)?`"), d.text) ||
                         occursin(Regex("`" * q * "\\s*=[^`]*`"), d.text)
            documented && continue
            push!(out, Model.Location(; file = "", line = d.line, node = d.node,
                                       text = "`$p` of `$(strip(signature))` is undocumented"))
        end
    end
    return out
end

const ARGCOV = Model.Rule(
    id = Symbol("RULE.DOC.ARGCOV"),
    statement = "Every argument in a docstring's signature, positional and keyword, is documented in its body.",
    why = "A reader passing an argument the docstring never mentions has to read the source to learn what it does.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, argcov, false),
    examples = [
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b, c)\n\nDoes a thing. The arguments are:\n\n- `a` — the first.\n- `b` — the second.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "every argument is documented"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b, c)\n\nDoes a thing. The arguments are:\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "every argument is documented"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    _helper(a, b, c)\n\nAn internal helper.\n\"\"\"\n_helper(x) = x\n",
            Model.Location[], "an internal helper is exempt"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    g(a, b, c)\n\nAn ordinary operation.\n\"\"\"\ng(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 1),
             Model.Location(; file = "src/Example.jl", line = 1),
             Model.Location(; file = "src/Example.jl", line = 1)],   # one per undocumented argument
            "an internal helper is exempt"),
    ])

"""
    dupref(src, cfg) -> Vector{Model.Location}

Every cross-reference target linked more than once inside one docstring. The arguments are `src`, the
Julia source, and `cfg`, the package's config, which this rule does not read. Returns one location per
repeated target.

The second link is invisible in the rendered text and tells the reader nothing the first did not: the
rubric caps a target at its first genuine mention.
"""
function dupref(src::AbstractString, cfg)
    out = Model.Location[]
    for d in Texts.docstrings_of(src)
        targets = [String(m.captures[1]) for m in eachmatch(r"\[`([^`]+)`\]\(@ref[^)]*\)", d.text)]
        for t in unique(targets)
            n = count(==(t), targets)
            n > 1 && push!(out, Model.Location(; file = "", line = d.line, node = d.node,
                                                text = "`$t` is linked $n times in one docstring"))
        end
    end
    return out
end

const LINKS = Model.Rule(
    id = Symbol("RULE.DOC.LINKS"),
    statement = "Cross-referencing is discriminating: a target is linked at most once in one docstring, at its first genuine mention.",
    why = "A second link to the same target is invisible in the rendered text and tells the reader nothing new.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, dupref, false),
    examples = [
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(x)\n\nSee [`g`](@ref) and then [`g`](@ref) again.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "linked at most once"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(x)\n\nSee [`g`](@ref), which does the rest.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "linked at most once"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[ARGCOV, LINKS]

end # module Reflection
