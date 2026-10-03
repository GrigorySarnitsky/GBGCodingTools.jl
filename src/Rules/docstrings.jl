# The design's §6; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.Docstrings

The rules that hold the SHAPE of documentation: how an argument or a field is named, what a type's
docstring must list, and the words the house does not use. Each is a rule value carrying its own
statement, the program that decides it and the examples that show the two agree.

These are the second batch of the conversion. Unlike the rendering
rules, what they catch does not look wrong on the page — it reads perfectly and tells the reader
something untrue, or tells him nothing where the shape promised something.
"""
module Docstrings

using ...Model
using ...Texts

const JS = Texts.JS

"""
    body_line(src, d) -> Int

The line of the source on which a docstring's body — its text as [`Texts.docstrings_of`](@ref) gives
it — begins. The arguments are `src`, the Julia source, and `d`, the docstring. Returns the line.

The docstring's own `line` is its opening delimiter's, and its text is stripped of the blank lines
after that delimiter; a rule counting newlines from the body's start to place a finding needs the line
the body actually opens on, or every docstring that opens with a blank line is reported one line early.
"""
function body_line(src::AbstractString, d)
    lines = split(src, '\n')
    d.line <= length(lines) || return d.line + 1
    # `@doc raw"""` and `@doc """` open a docstring on the macro's line: read past the macro as well.
    opener = replace(lines[d.line], r"^\s*(?:(?:Base\.)?@doc\s+)?(?:raw)?\"{1,3}" => "")
    isempty(strip(opener)) || return d.line                   # a one-line docstring opens on its own line
    i = d.line + 1
    while i <= length(lines) && isempty(strip(lines[i])); i += 1; end
    return i
end

# ───────────────────────────────────────────────────────────── an argument bullet set in bold

const BOLD_BULLET = r"^\s*[-*]\s+\*\*`"
# The heading that opens an argument or field list — `# Arguments` or `# Fields`, the sections
# `RULE.DOC.ARGS_FORM` and `RULE.DOC.FIELDS` ask for (ruled 2026-09-28), at any level on a page. Without
# it a bulleted name is not an argument bullet: a design document's type glossary is a bulleted list of
# names with prose about each, and reading it as an argument list reported fourteen entries of one
# package's §10 for using bold where it means bold.
const LIST_MARKER = r"^\s*#+\s+(Arguments|Fields)\s*$"

"""
    arg_bullet(text, cfg) -> Vector{Model.Location}

Every argument or field bullet that names its argument in a bold code span rather than a plain one. The
arguments are `text`, the file's prose, and `cfg`, the package's config, which this rule does not read.
Returns one location per bullet.

A bold PROSE label — `- **Positions.**` — is a different device and is not a hit: the backtick must
follow the asterisks, which is what makes it a name rather than a heading. Nor is a bulleted name
OUTSIDE an argument or field list, which is why the list's heading has to be found first: a design
document indexes its types that way, and bold there is doing the job bold is for.
"""
function arg_bullet(text::AbstractString, cfg)
    out = Model.Location[]
    in_list = false
    for (i, raw) in pairs(split(text, '\n'))
        line = String(raw)
        occursin(LIST_MARKER, line) && (in_list = true; continue)
        body = strip(line)
        # A blank line or an indented continuation keeps the list open; anything else closes it.
        in_list && !(isempty(body) || startswith(body, "-") || startswith(body, "*") || startswith(line, "  ")) &&
            (in_list = false)
        in_list && occursin(BOLD_BULLET, line) &&
            push!(out, Model.Location(; file = "", line = i, text = body))
    end
    return out
end

"""
    ARG_BULLET

An argument or field bullet names its argument in a plain code span, never a bold one.
"""
const ARG_BULLET = Model.Rule(
    id = Symbol("RULE.DOC.ARG_BULLET"),
    statement = "An argument or field bullet names its argument in a plain code span, never a bold one.",
    why = "Bold marks emphasis; a name set in bold reads as a heading over the paragraph rather than as the argument.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, arg_bullet, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n# Arguments\n\n- **`u`** — the field.\n",
            [Model.Location(; file = "docs/src/page.md", line = 5)], "a plain code span, never a bold one"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n# Arguments\n\n- `u` — the field.\n",
            Model.Location[], "a plain code span, never a bold one"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- **Positions.** Where each sits.\n",
            Model.Location[], "a plain code span, never a bold one"),
        Model.TextExample(Model.FileSet.DOCSTRINGS,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- **`a`** — the first.\n\"\"\"\nstruct S\n    a::Int\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 8)], "a plain code span, never a bold one"),
        # A design document's glossary of types is a bulleted list of NAMES, not of arguments, and bold
        # there is doing the job bold is for.
        Model.TextExample(Model.FileSet.RATIONALE,
            "# The design\n\nThe types are, in layers:\n\n- **`Point{T}`** — a single position.\n",
            Model.Location[], "a plain code span, never a bold one"),
    ])

# ──────────────────────────────────────────────────────────────────── the words the house uses

const OFF_REGISTER = r"\b(knobs?|tweaks?)\b"i
const QUOTED = [r"`[^`]*`" => " ", r"\"[^\"]*\"" => " ", r"“[^”]*”" => " "]

"""
    register(text, cfg) -> Vector{Model.Location}

Every line calling a setting a `knob` or a `tweak`. The arguments are `text`, the file's prose, and `cfg`,
the package's config, which this rule does not read. Returns one location per line.

Quoted words and code spans are taken out before the match, so a sentence that NAMES the banned word —
this rule's own statement, for one — is not a hit.
"""
function register(text::AbstractString, cfg)
    out = Model.Location[]
    for (i, line) in pairs(split(text, '\n'))
        stripped = String(line)
        for pair in QUOTED; stripped = replace(stripped, pair); end
        occursin(OFF_REGISTER, stripped) &&
            push!(out, Model.Location(; file = "", line = i, text = strip(String(line))))
    end
    return out
end

"""
    REGISTER

A tunable is an option, a setting or a keyword argument, never a `knob` or a `tweak`.
"""
const REGISTER = Model.Rule(
    id = Symbol("RULE.DOC.REGISTER"),
    statement = "A tunable is an option, a setting or a keyword argument, never a `knob` or a `tweak`.",
    why = "The house register is plain and exact; `knob` is neither, and reads as though the value did not matter.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, register, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nTurn the knob until it converges.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never a `knob` or a `tweak`"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nRaise the tolerance until it converges.\n",
            Model.Location[], "never a `knob` or a `tweak`"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe rule forbids the word `knob`.\n",
            Model.Location[], "never a `knob` or a `tweak`"),   # quoted: naming the word is not using it
    ])

# ───────────────────────────────────────────────────────── a type that documents its own fields

const FIELD_BULLET = r"^\s*[-*]\s"
const FIELD_NAME = r"`([^`:\s,]+)(?:::[^`]*)?`"

"""
    field_docs(src, cfg) -> Vector{Model.Location}

Every documented type whose field list does not match its fields: one that names a field the type does
not have, one that leaves a field out, and one with fields and no `# Fields` section. The arguments are `src`,
the Julia source, and `cfg`, the package's config, which this rule does not read. Returns one location
per type, quoting what is wrong.

It reads the parse tree rather than the text, so a keyword-default type — `Base.@kwdef struct` — is the
same case as any other, an untyped or `const` field is a field, and a docstring is paired with the
definition under it: an outer constructor's docstring names the type and documents arguments, and
pairing by name held it to a field list it was right not to have.
"""
function field_docs(src::AbstractString, cfg)
    out = Model.Location[]
    typed = documented_types(src)
    for d in Texts.docstrings_of(src)
        fields = get(typed, d.line, String[])
        isempty(fields) && continue
        documented = documented_fields(d.text)
        if documented === nothing
            # The sentence-led list this rule asked for until 2026-09-28 is named, so a package
            # converting is told where its list goes rather than that it has none.
            phrase = match(r"The\s+fields\s+are\b", d.text)
            under_phrase = phrase !== nothing
            push!(out, Model.Location(; file = "", line = under_phrase ? Texts.docstring_line(d, phrase.offset) : d.line, node = d.node,
                text = under_phrase ? "$(d.node) lists its fields under a sentence: put them under a `# Fields` heading" :
                                      "$(d.node) stores $(join(fields, ", ")) and has no `# Fields` section"))
            continue
        end
        ghost = setdiff(documented, fields)
        missed = setdiff(fields, documented)
        heading = match(r"(?m)^#\s+Fields\s*$", d.text)                 # the list's own line, where it has one
        at = heading === nothing ? d.line : Texts.docstring_line(d, heading.offset)
        isempty(ghost) || push!(out, Model.Location(; file = "", line = at, node = d.node,
            text = "$(d.node) documents $(join(ghost, ", ")), which it does not have"))
        isempty(missed) || push!(out, Model.Location(; file = "", line = at, node = d.node,
            text = "$(d.node) has no bullet for $(join(missed, ", "))"))
    end
    return out
end

# The fields of every documented type, keyed by the line its docstring opens on — which is how the
# docstring is paired with the definition under it and with nothing else in the file.
function documented_types(src::AbstractString)
    out = Dict{Int,Vector{String}}()
    tree = try
        JS.parseall(JS.SyntaxNode, src; filename = "source.jl", ignore_errors = true)
    catch
        return out
    end
    function walk(node)
        cs = JS.children(node)
        cs === nothing && return
        for c in cs
            if JS.kind(c) === JS.K"doc"
                kids = something(JS.children(c), ())
                s = length(kids) >= 2 ? struct_node(kids[2]) : nothing
                s === nothing || (out[JS.source_line(c)] = fields_of(s))
            end
            walk(c)
        end
    end
    walk(tree)
    return out
end

# The struct a definition declares, through the macro call a keyword-default type is wrapped in, or
# nothing where the definition is not a type.
function struct_node(def)
    JS.kind(def) === JS.K"struct" && return def
    JS.kind(def) === JS.K"macrocall" || return nothing
    for c in something(JS.children(def), ())
        s = struct_node(c)
        s === nothing || return s
    end
    return nothing
end

# The fields a struct declares, by name: a bare name, a typed one, one with a default, a `const` one
# and one carrying a docstring of its own are each a field; an inner constructor is not, and neither
# is anything else in the body.
function fields_of(node)
    out = String[]
    cs = something(JS.children(node), ())
    body = findfirst(c -> JS.kind(c) === JS.K"block", cs)
    body === nothing && return out
    for c in something(JS.children(cs[body]), ())
        name = field_name(c)
        name === nothing || push!(out, name)
    end
    return out
end

function field_name(c)
    k = JS.kind(c)
    k === JS.K"Identifier" && return Texts.node_text(c)
    kids = something(JS.children(c), ())
    isempty(kids) && return nothing
    k in (JS.K"::", JS.K"=", JS.K"const") && return field_name(first(kids))
    k === JS.K"doc" && length(kids) >= 2 && return field_name(kids[2])
    return nothing
end

"""
    struct_fields(src, name) -> Vector{String}

The fields the struct called `name` declares in the Julia source `src`, by name, or none where no such
struct is defined there. The arguments are `src` and `name`. Returns the names in declaration order.
"""
function struct_fields(src::AbstractString, name::AbstractString)
    tree = try
        JS.parseall(JS.SyntaxNode, src; filename = "source.jl", ignore_errors = true)
    catch
        return String[]
    end
    found = Ref{Union{Nothing,Vector{String}}}(nothing)
    function walk(node)
        cs = JS.children(node)
        (cs === nothing || found[] !== nothing) && return
        for c in cs
            s = struct_node(c)
            s !== nothing && Texts.bound_name(s) == name && (found[] = fields_of(s); return)
            walk(c)
        end
    end
    walk(tree)
    return something(found[], String[])
end

# The field names a docstring's `# Fields` section claims, or `nothing` where it has no such section.
# The list is the bullets under the heading, to the first line that is neither a bullet, its indented
# continuation nor blank; a heading before any bullet ends it too, so an empty section claims nothing.
const FIELDS_HEADING = r"(?m)^#\s+Fields\s*$"
function documented_fields(doc::AbstractString)
    k = findfirst(FIELDS_HEADING, doc)
    k === nothing && return nothing
    names = String[]
    inlist = false
    section = String[]
    for line in split(doc[first(k):end], '\n')[2:end]
        startswith(line, "#") && break
        if occursin(FIELD_BULLET, line)
            inlist = true
        elseif inlist && !isempty(strip(line)) && !startswith(line, (' ', '\t'))
            break
        end
        push!(section, line)
    end
    # a bullet's head of names may wrap onto its continuation lines
    for b in Texts.bullets(join(section, '\n')); append!(names, Texts.bullet_head_names(b)); end
    return names
end

"""
    FIELDS

A type with named fields documents them under `# Fields`, each heading a bullet.
"""
const FIELDS = Model.Rule(
    id = Symbol("RULE.DOC.FIELDS"),
    statement = "A type with named fields documents them in a `# Fields` section, in bullets: every bullet a real field, and every field at the head of a bullet, alone or with others; a field named only inside another's bullet has none. A sentence listing them, \"The fields are …\", is no such section.",
    why = "A field list that has drifted is worse than none: it names what does not exist and hides what does.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, field_docs, false),
    examples = [
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a` — the first.\n\"\"\"\nstruct S\n    a::Int\n    b::Int\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 6)], "every field a bullet"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a` — the first.\n- `b` — the second.\n\"\"\"\nstruct S\n    a::Int\n    b::Int\nend\n",
            Model.Location[], "every field a bullet"),
        # An outer constructor's docstring is paired with the constructor, not with the type of the
        # same name: it documents arguments, and owes no field list.
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a` — the first.\n\"\"\"\nstruct S\n    a::Int\nend\n\n\"\"\"\n    S(n; scale = 1)\n\nBuilds one from `n`.\n\"\"\"\nS(n; scale = 1) = S(n * scale)\n",
            Model.Location[], "every field a bullet"),
        # An untyped field and a `const` one are fields, and a type made of them alone is held to the
        # rule like any other.
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a` — the first.\n- `b` — the second.\n\"\"\"\nmutable struct S\n    const a::Int\n    b\nend\n",
            Model.Location[], "every field a bullet"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a` — the first.\n\"\"\"\nmutable struct S\n    const a::Int\n    b\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 6)], "every field a bullet"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a` — the first.\n- `c` — no such field.\n\"\"\"\nstruct S\n    a::Int\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 6)], "every bullet a real field"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a` — the first.\n\"\"\"\nstruct S\n    a::Int\nend\n",
            Model.Location[], "every bullet a real field"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing with fields and no list.\n\"\"\"\nstruct S\n    a::Int\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "documents them in a `# Fields` section"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing with untyped fields and no list.\n\"\"\"\nBase.@kwdef struct S\n    a = 1\n    b\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "documents them in a `# Fields` section"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a` — the first.\n\"\"\"\nstruct S\n    a::Int\nend\n",
            Model.Location[], "documents them in a `# Fields` section"),
        # The sentence-led list, the form asked for before 2026-09-28, complete as it is, is no section.
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing. The fields are:\n\n- `a` — the first.\n\"\"\"\nstruct S\n    a::Int\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 4)], "is no such section"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a` — the first.\n\"\"\"\nstruct S\n    a::Int\nend\n",
            Model.Location[], "is no such section"),
        # A field described inside another field's bullet has no bullet; two named at one bullet's head do
        # (the owner, 2026-09-29).
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a` — the first, and `b` the second.\n\"\"\"\nstruct S\n    a::Int\n    b::Int\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 6)], "every field at the head of a bullet"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a`, `b` — the two ends.\n\"\"\"\nstruct S\n    a::Int\n    b::Int\nend\n",
            Model.Location[], "every field at the head of a bullet"),
        # The colon form heads a bullet as the dash form does, and a name inside its description is none.
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a`: the first, and `b` the second.\n\"\"\"\nstruct S\n    a::Int\n    b::Int\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 6)], "every field at the head of a bullet"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a`: the first, not `k`.\n- `b`: the second.\n\"\"\"\nstruct S\n    a::Int\n    b::Int\nend\n",
            Model.Location[], "every bullet a real field"),
        # Any number of names may head one bullet: all of them are seen at a glance (the owner, 2026-09-29).
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a`, `b`, `c` — the three corners.\n\"\"\"\nstruct S\n    a::Int\n    b::Int\n    c::Int\nend\n",
            Model.Location[], "every field at the head of a bullet"),
        # a bullet's head of names wraps onto its next line and still heads it
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a`,\n  `b` — the two ends.\n\"\"\"\nstruct S\n    a::Int\n    b::Int\nend\n",
            Model.Location[], "every field at the head of a bullet"),
    ])

# ───────────────────────────────────────────────────────── how a sentence is allowed to open

const OPENER_LEADER = r"^\s*([-*+>|]|\d+[.)])\s"
const OPENER_LOWER = r"^(\[?`[a-z_][\w!]*`|``[^`])"
const ENDS_SENTENCE = r"[.!?]\*{0,2}[\"')]?$"
const ABBREVIATION = r"(e\.g|i\.e|cf|vs|incl)\.\s*$"i
const OPENER_INLINE = r"(?<!\.)\.\s+(\[?`[a-z_][\w!]*`|``[^`])"

"""
    sentence_opener(text, cfg) -> Vector{Model.Location}

Every sentence that opens with a lowercase identifier or a formula rather than an ordinary capitalised
word. The arguments are `text`, the file's prose, and `cfg`, the package's config, which this rule does
not read. Returns one location per sentence.

Where a sentence STARTS is computed rather than matched: the beginning of a line whose predecessor ended
one or was blank, and any point after a full stop within a line. A reader meeting a lowercase name at a
full stop cannot tell whether a new sentence has begun or the last one is still running.

Exempt, because none of them is prose a reader parses that way: bullets and their wrapped continuations,
comment lines, headings, indented lines such as signatures and continuations, the abbreviations e.g.,
i.e., cf., vs. and incl., and the tick marker used as a bullet.
"""
function sentence_opener(text::AbstractString, cfg)
    out = Model.Location[]
    previous = ""; inlist = false
    for (n, line) in pairs(split(text, '\n'))
        if occursin(OPENER_LEADER, line)
            inlist = true
        elseif isempty(strip(line)) || !startswith(line, (' ', '\t'))
            inlist = false
        end
        if occursin(r"^\s*#", line) || occursin(OPENER_LEADER, line) || inlist
            previous = line; continue
        end
        stripped = rstrip(line)
        if !startswith(line, (' ', '\t')) && occursin(OPENER_LOWER, line) && !startswith(line, "``\\checkmark``")
            if isempty(strip(previous)) || (occursin(ENDS_SENTENCE, rstrip(previous)) && !occursin(ABBREVIATION, rstrip(previous)))
                push!(out, Model.Location(; file = "", line = n, text = first(String(stripped), 100)))
                previous = line; continue
            end
        end
        for m in eachmatch(OPENER_INLINE, line)
            before = rstrip(line[1:m.offset])
            (occursin(ABBREVIATION, before) || occursin("checkmark", line)) && continue
            push!(out, Model.Location(; file = "", line = n, text = first(String(stripped), 100)))
            break
        end
        previous = line
    end
    return out
end

"""
    SENTENCE_OPENER

A sentence opens with a capitalised ordinary word, never a lowercase identifier or a formula.
"""
const SENTENCE_OPENER = Model.Rule(
    id = Symbol("RULE.DOC.SENTENCE_OPENER"),
    statement = "A sentence opens with a capitalised ordinary word, never a lowercase identifier or a formula; bullets, comments, headings and fenced code are exempt.",
    why = "At a full stop a reader cannot tell a new sentence beginning with a lowercase name from the old one running on.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, sentence_opener, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n`measure` returns the mean.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never a lowercase identifier"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe operation `measure` returns the mean.\n",
            Model.Location[], "never a lowercase identifier"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nIt is the mean. ``\\varepsilon`` bounds the error.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "never a formula"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nIt is the mean. The tolerance ``\\varepsilon`` bounds the error.\n",
            Model.Location[], "never a formula"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- `measure` returns the mean.\n",
            # An EXEMPTION is not a clause: it can have no breaking example, so these two are complying
            # examples of the clauses they exempt — a bullet, and an abbreviation that ends no sentence.
            Model.Location[], "never a lowercase identifier"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nSee e.g. `measure` for this.\n",
            Model.Location[], "never a lowercase identifier"),
    ])

"""
    RULES

The rules of this batch, in the order they were converted.
"""
# ───────────────────────────────────────────────────────────── where a caveat sits among the sections

"""
    section_order(src, cfg) -> Vector{Model.Location}

Every caveat admonition at a docstring's margin that sits out of `RULE.DOC.HOME_ORDER`'s order: after the
`# Fields` section, or before an `# Arguments` section. The arguments are `src`, the Julia source, and
`cfg`, which is not read. Returns one location per misplaced line. An admonition indented under a list
item belongs to that item, and a line in a fenced block is code, so neither counts.
"""
function section_order(src::AbstractString, cfg)
    out = Model.Location[]
    for d in Texts.docstrings_of(src)
        fields = false; caveat = false; fence = false; offset = 1
        for line in split(d.text, '\n')
            here = offset; offset += ncodeunits(line) + 1
            startswith(lstrip(line), "```") && (fence = !fence; continue)
            fence && continue
            if rstrip(line) == "# Fields"
                fields = true
            elseif startswith(line, "!!! ")
                fields && push!(out, Model.Location(; file = "", line = Texts.docstring_line(d, here), node = d.node,
                                                   text = "a caveat admonition after `# Fields`, which comes last"))
                caveat = true
            elseif rstrip(line) == "# Arguments" && caveat
                push!(out, Model.Location(; file = "", line = Texts.docstring_line(d, here), node = d.node,
                                           text = "`# Arguments` after a caveat admonition, which comes after the arguments"))
            end
        end
    end
    return out
end

# a function's docstring over a one-line method, for the examples below
order_doc(binding, body) = "\"\"\"\n    " * binding * "\n\n" * body * "\n\"\"\"\n" * first(split(binding, "(")) * "(x) = x\n"

# The program half of RULE.DOC.HOME_ORDER, which a reader decides whole: its two consequences no reading
# is needed for, asked for by GBGHomogeneousTurbulence so its own lint could go (2026-10-03).
const SECTION_ORDER = Model.Rule(
    id = Symbol("RULE.DOC.SECTION_ORDER"),
    statement = "A caveat admonition at a docstring's margin comes after its `# Arguments` section and before its `# Fields` section.",
    why = "`RULE.DOC.HOME_ORDER` orders a docstring: the arguments, then the caveats that close its prose, then `# References`, then `# Fields` last. These two places are where a caveat most often lands wrongly, and a program can find them; an admonition indented under a list item is that item's.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, section_order, false),
    examples = [
        Model.TextExample(Model.FileSet.CODE,
            order_doc("f(a, b, c)", "Does a thing.\n\n!!! warning \"Slow\"\n    It is slow.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third."),
            [Model.Location(; file = "src/Example.jl", line = 9)], "after its `# Arguments` section"),
        Model.TextExample(Model.FileSet.CODE,
            order_doc("f(a, b, c)", "Does a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third.\n\n!!! warning \"Slow\"\n    It is slow."),
            Model.Location[], "after its `# Arguments` section"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n# Fields\n\n- `a` — the first.\n\n!!! note\n    Late.\n\"\"\"\nstruct S\n    a::Int\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 10)], "before its `# Fields` section"),
        # indented under a list item, or in a fence, it is not the docstring's own caveat
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing.\n\n!!! note\n    Early.\n\n# Fields\n\n- `a` — the first.\n    !!! tip\n        The item's.\n\n```\n!!! not a caveat\n```\n\"\"\"\nstruct S\n    a::Int\nend\n",
            Model.Location[], "before its `# Fields` section"),
    ])

const RULES = Model.Rule[ARG_BULLET, REGISTER, FIELDS, SENTENCE_OPENER, SECTION_ORDER]

end # module Docstrings