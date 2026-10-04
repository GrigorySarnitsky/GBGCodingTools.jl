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
# The sentence that ENDS at "are" or "are:" with bullets under it. Any text after "are" on the line made a
# prose binding followed by an unrelated list read as a bulleted one (found in review, 2026-09-29).
const UNDER_PHRASE = r"The\s+arguments\s+are:?[ \t]*\n\s*\n?\s*[-*]\s"
const IN_PROSE = r"The\s+arguments?\s+(is|are)\s+`"
const WRAPPER_PHRASE = "Allocating form of"
const THRESHOLD = 3

"""
    documents_in_full(e) -> Bool

Whether a docstring documents its own arguments in full, as a delegate's must: it displays a signature,
names every one of its arguments as code — a bare name, or with its type, default or dots — and lists
them in the form `RULE.DOC.ARGS_FORM` asks. The argument is `e`, the docstring. Returns the verdict.
No exemption applies: a private or short delegate is held to naming them all like any other.
"""
function documents_in_full(e)
    names = Texts.signature_names(e.text)
    isempty(names) && return false
    named(n) = occursin(Regex("`\\Q" * n * "\\E(?:\\.\\.\\.)?(?:\\s*(?:::|=)[^`]*)?`"), e.text)
    return all(named, names) && isempty(args_form_one(e; exempt = false))
end

"""
    delegation_verdict(d, docs) -> Union{Nothing,Symbol,String}

Whether a docstring's argument delegation stands. The arguments are `d`, the docstring, and `docs`,
every docstring of its file. Returns `nothing` where `d` delegates nothing, `:ok` where the delegation
stands, and the reason in words where it does not.

It stands when the delegate — matched by its last name — is documented in the same file, by a docstring
that delegates nothing and [`documents_in_full`](@ref); when every argument of `d`'s signature is one
of the delegate's; and when every argument of the delegate's that `d` lacks is named as code in the
delegating paragraph, as "without `normalize`" does
([GBGStreamingStatistics](https://grigorysarnitsky.github.io/GBGStreamingStatistics.jl/)' request, 2026-10-04).
Both rules judge a delegation by this one verdict, so a fault in it is the same fault under both.
"""
function delegation_verdict(d, docs)
    del = Texts.delegation(d.text)
    del === nothing && return nothing
    f = del.delegate
    targets = [e for e in docs if last(split(e.node, '.')) == f && e.text != d.text]
    isempty(targets) && return "delegates its arguments to `$f`, which has no docstring in this file"
    any(e -> Texts.delegation(e.text) !== nothing, targets) &&
        return "delegates its arguments to `$f`, which delegates its own: a delegation is not chained"
    all(documents_in_full, targets) ||
        return "delegates its arguments to `$f`, whose own docstring does not document them in full"
    mine = Texts.signature_names(d.text)
    isempty(mine) && return "delegates its arguments to `$f` and displays no signature of its own"
    theirs = unique(vcat((Texts.signature_names(e.text) for e in targets)...))
    extra = setdiff(mine, theirs)
    isempty(extra) || return "delegates its arguments to `$f`, which does not take " * join("`" .* extra .* "`", ", ")
    unsaid = [n for n in setdiff(theirs, mine) if !occursin(Regex("`\\Q" * n * "\\E(?:\\.\\.\\.)?`"), del.paragraph)]
    isempty(unsaid) || return "delegates its arguments to `$f` and does not say it lacks " * join("`" .* unsaid .* "`", ", ")
    return :ok
end

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
    docs = Texts.docstrings_of(src)
    for d in docs
        own = args_form_one(d)
        # A delegation answers for the list only where one is missing; an exempt docstring stays exempt.
        isempty(own) && continue
        verdict = delegation_verdict(d, docs)
        verdict === :ok && continue
        if verdict isa String
            push!(out, Model.Location(; file = "", line = Texts.docstring_line(d, Texts.delegation(d.text).offset),
                                       node = d.node, text = "`$(d.node)` " * verdict))
            continue
        end
        append!(out, own)
    end
    return out
end

# One docstring's verdict under the rule, delegation aside.
function args_form_one(d; exempt = true)
    out = Model.Location[]
    begin
        exempt && startswith(d.node, "_") && return out
        exempt && occursin(WRAPPER_PHRASE, d.text) && return out

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
        npos + nkw == 0 && return out

        prosed = occursin(IN_PROSE, d.text)
        bulleted = occursin(BULLETED, d.text)
        # The rule's last exemption, and no wider: ONE element-type keyword BOUND IN A PROSE CLAUSE. A
        # docstring that binds nothing at all is not a prose clause, and exempting it would turn a hit
        # into silence — the direction that costs a reader something.
        element_type = nkw == 1 && length(keyword) == 1 && first(keyword) in ("T", "eltype", "element_type") &&
                       prosed && npos + nkw < THRESHOLD
        wants_bullets = npos + nkw >= THRESHOLD || (nkw > 0 && !element_type)
        # Bullets under the old sentence are judged AFTER the count: a two-argument call bulleted so was
        # told to add a heading, where the rule wants it in prose (found in review, 2026-09-28).
        # Bullets heading the arguments' own names under ANY sentence, outside a `# Fields` section, are the
        # bulleted form without its heading: read only under "The arguments are", "The arguments run from
        # the largest scale to the smallest:" was told to use bullets it already had (HT, 2026-09-29).
        names = Set(replace.(vcat(positional, keyword), r"\.\.\.$" => ""))
        loose = bulleted ? nothing : argument_bullets(d.text, names)
        if !bulleted && (occursin(UNDER_PHRASE, d.text) || loose !== nothing)
            at = occursin(UNDER_PHRASE, d.text) ? Texts.docstring_line(d, match(UNDER_PHRASE, d.text).offset) :
                                                  Texts.docstring_line(d, loose)
            push!(out, Model.Location(; file = "", line = at, node = d.node,
                text = wants_bullets ?
                    "`$(d.node)` lists its arguments under a sentence: put the bullets under an `# Arguments` heading" :
                    "`$(d.node)` takes $(npos + nkw) argument(s): bind them in running prose, not bullets"))
            return out
        end

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

# The offset of the first bullet outside a `# Fields` section whose head names an argument, or nothing.
function argument_bullets(text::AbstractString, names)
    offset = 1; in_fields = false
    for l in split(text, '\n')
        h = match(r"^ {0,3}#{1,6}\s+(.*?)\s*$", l)
        h === nothing || (in_fields = strip(h.captures[1]) == "Fields")
        !in_fields && any(in(names), Texts.bullet_head_names(l)) && return offset
        offset += ncodeunits(l) + 1
    end
    return nothing
end

doc(binding, body) = "\"\"\"\n    " * binding * "\n\n" * body * "\n\"\"\"\n" *
                     first(split(binding, "(")) * "(x) = x\n"

"""
    ARGS_FORM

Three or more arguments, or any keyword, go under `# Arguments`; fewer are bound in running prose.
"""
const ARGS_FORM = Model.Rule(
    id = Symbol("RULE.DOC.ARGS_FORM"),
    statement = "Three or more arguments, or any keyword, are listed as bullets under an `# Arguments` heading, where several may head one bullet together; fewer are bound in running prose, as in \"The arguments are `a`, the first, and `b`, the second.\"; the two are never mixed. A type lists its constructor's arguments so too, even where its `# Fields` section repeats them. A docstring that delegates its arguments as `RULE.DOC.ARGCOV` states takes neither form.",
    why = "A reader looking for one argument of many needs a list; a reader of a two-argument call needs a sentence; a reader of a function that takes another's arguments needs the one list they both take.",
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
            [Model.Location(; file = "src/Example.jl", line = 12)], "under an `# Arguments` heading"),
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
        # several arguments at the head of one bullet are the list form (the owner, 2026-09-29)
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a; lo = 0, hi = 1)", "Does a thing.\n\n# Arguments\n\n- `a` — the first.\n- `lo`, `hi` — the bounds, at most one given."),
            Model.Location[], "under an `# Arguments` heading"),
        # arguments bound in prose, and an unrelated list after them: no finding
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b)", "Does a thing. The arguments are `a`, the first, and `b`, the second.\n\n- one note.\n- another."),
            Model.Location[], "fewer are bound in running prose"),
        # a delegation stands for the list, and one that breaks a condition is reported at its paragraph
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third.") *
            doc("g(a, b, c; d = 1)", "Does another thing.\n\nArguments: as for [`f`](@ref)."),
            [Model.Location(; file = "src/Example.jl", line = 18)], "takes neither form"),
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third.") *
            doc("g(a, b; c = 1)", "Does another thing.\n\nArguments: as for [`f`](@ref)."),
            Model.Location[], "takes neither form"),
        # the arguments bulleted under another sentence: the heading is what is missing, at the bullets
        Model.TextExample(Model.FileSet.CODE,
            doc("f(a, b, c)", "Does a thing. They run from the largest to the smallest:\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third."),
            [Model.Location(; file = "src/Example.jl", line = 6)], "under an `# Arguments` heading"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[ARGS_FORM]

end # module Arguments
