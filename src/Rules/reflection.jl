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
        # The line of each link, not just its target: a module docstring runs to seventy lines, and a
        # finding anchored at its first one sends the fixer to search the whole of it for the repeat.
        seen = Dict{String,Int}()
        repeats = Dict{String,Vector{Int}}()
        for m in eachmatch(r"\[`([^`]+)`\]\(@ref[^)]*\)", d.text)
            t = String(m.captures[1])
            at = d.line + 1 + count(==('\n'), d.text[1:prevind(d.text, m.offset)])   # the body opens after the delimiter
            haskey(seen, t) ? push!(get!(repeats, t, Int[]), at) : (seen[t] = at)
        end
        for t in sort!(collect(keys(repeats)))
            for at in repeats[t]
                push!(out, Model.Location(; file = "", line = at, node = d.node,
                    text = "`$t` is linked here and again at line $(seen[t]); the first mention carries the link"))
            end
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
            [Model.Location(; file = "src/Example.jl", line = 4)], "linked at most once"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(x)\n\nSee [`g`](@ref), which does the rest.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "linked at most once"),
    ])

# ─────────────────────────────────────────────────────── one run of names, linked or bare, not both

const RUN_ITEM = raw"(?:\[`[A-Za-z_]\w*!?`\]\(@ref[^)]*\)|`[A-Za-z_!*/+\-]\w*!?`)"
const RUN_SEP = raw"(?:,\s+|\s+and\s+|\s+or\s+|\s*/\s*)"
const NAME_RUN = Regex(RUN_ITEM * "(?:" * RUN_SEP * RUN_ITEM * ")+")
const RUN_LINKED = r"\[`([A-Za-z_]\w*!?)`\]\(@ref"
const RUN_BARE = r"(?<!\[)`([A-Za-z_]\w*!?)`(?!\]\()"

"""
    exported_names(src) -> Set{String}

Every name the source exports. The argument is `src`, the Julia source. Returns the names.
"""
function exported_names(src::AbstractString)
    names = Set{String}()
    for block in eachmatch(r"^export\s+(.+?)(?=^\s*\$|^\w)"ms, src)
        for t in eachmatch(r"[A-Za-z_]\w*!?", block.captures[1]); push!(names, t.match); end
    end
    return names
end

"""
    link_uniformity(src, cfg) -> Vector{Model.Location}

Every run of names in one docstring where some are linked and others are not. The arguments are `src`,
the Julia source, and `cfg`, the package's config, which this rule does not read. Returns one location
per run.

A list where one name is a link and the next is not reads as though the difference meant something. The
docstring's own binding is not counted: a docstring does not link to itself.
"""
function link_uniformity(src::AbstractString, cfg)
    public = exported_names(src)
    out = Model.Location[]
    for d in Texts.docstrings_of(src)
        doc = join(split(d.text), " ")
        for run in eachmatch(NAME_RUN, doc)
            text = run.match
            linked = [m.captures[1] for m in eachmatch(RUN_LINKED, text)]
            bare = [m.captures[1] for m in eachmatch(RUN_BARE, text) if m.captures[1] in public && m.captures[1] != d.node]
            (isempty(linked) || isempty(bare)) && continue
            push!(out, Model.Location(; file = "", line = d.line, node = d.node,
                text = "linked $(linked) beside bare $(bare) in one run: " * first(String(text), 90)))
        end
    end
    return out
end

const LINK_UNIFORMITY = Model.Rule(
    id = Symbol("RULE.DOC.LINK_UNIFORMITY"),
    statement = "In one run of names, either every name is linked or none is.",
    why = "A list where one name links and the next does not reads as though the difference meant something.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, link_uniformity, false),
    examples = [
        Model.TextExample(Model.FileSet.CODE,
            "export f, g\n\n\"\"\"\n    h(x)\n\nSee [`f`](@ref), `g` and more.\n\"\"\"\nh(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 3)], "either every name is linked or none is"),
        Model.TextExample(Model.FileSet.CODE,
            "export f, g\n\n\"\"\"\n    h(x)\n\nSee [`f`](@ref), [`g`](@ref) and more.\n\"\"\"\nh(x) = x\n",
            Model.Location[], "either every name is linked or none is"),
    ])

# ───────────────────────────────────────────────────── a rule id that names something that exists

"""
    live_ids() -> Set{String}

Every identifier a document may cite and expect to resolve: the rules of the rulebook, the always-on
checks and the instruments. Returns the ids.
"""
function live_ids()
    cat = parentmodule(@__MODULE__)
    ids = Set{String}(String(r.id) for r in cat.RULES)
    for a in cat.ALWAYS_ON; push!(ids, String(a.id)); end
    for i in cat.INSTRUMENTS; push!(ids, String(i.id)); end
    return ids
end

"""
    id_resolves(text, cfg) -> Vector{Model.Location}

Every dotted identifier in the `RULE.` namespace that names no rule of the running copy. The arguments
are `text`, the file's prose, and `cfg`, the package's config, which this rule does not read. Returns one
location per mention.

A rule id that resolves to nothing is a citation of something that was renamed or removed, and it reads
exactly like one that resolves.
"""
function id_resolves(text::AbstractString, cfg)
    known = live_ids()
    mention(id) = any(k -> k != id && startswith(k, id), known)
    out = Model.Location[]
    for (i, line) in pairs(split(text, '\n'))
        for m in eachmatch(r"\bRULE\.[A-Z][A-Z0-9_]*(?:\.[A-Z][A-Z0-9_]*)?", line)
            id = String(m.match)
            (id in known || mention(id)) && continue
            push!(out, Model.Location(; file = "", line = i, text = "`$id` names no rule of the running copy"))
        end
    end
    return out
end

const CURRENT = Model.Rule(
    id = Symbol("RULE.DOC.CURRENT"),
    statement = "No stale claim: a rule cited by id names a rule that exists, and a retired phrasing is not used.",
    why = "A citation of something renamed or removed reads exactly like one that resolves, which is why it survives.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, id_resolves, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nAs RULE.DOC.NO_SUCH_THING says.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "a rule cited by id exists"),
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nAs RULE.DOC.ARGCOV says.\n",
            Model.Location[], "a rule cited by id exists"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[ARGCOV, LINKS, LINK_UNIFORMITY, CURRENT]

end # module Reflection