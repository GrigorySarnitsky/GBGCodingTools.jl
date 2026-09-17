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

# ───────────────────────────────────────────────────────────── an argument bullet set in bold

const BOLD_BULLET = r"^\s*[-*]\s+\*\*`"

"""
    arg_bullet(text, cfg) -> Vector{Model.Location}

Every argument or field bullet that names its argument in a bold code span rather than a plain one. The
arguments are `text`, the file's prose, and `cfg`, the package's config, which this rule does not read.
Returns one location per bullet.

A bold PROSE label — `- **Positions.**` — is a different device and is not a hit: the backtick must
follow the asterisks, which is what makes it a name rather than a heading.
"""
function arg_bullet(text::AbstractString, cfg)
    return [Model.Location(; file = "", line = i, text = strip(String(line)))
            for (i, line) in pairs(split(text, '\n')) if occursin(BOLD_BULLET, line)]
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
            "# A page\n\nThe arguments are:\n\n- **`u`** — the field.\n",
            [Model.Location(; file = "docs/src/page.md", line = 5)], "a plain code span, never a bold one"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe arguments are:\n\n- `u` — the field.\n",
            Model.Location[], "a plain code span, never a bold one"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- **Positions.** Where each sits.\n",
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
    field_docs(path, cfg) -> Vector{Model.Location}

Every documented type whose field list does not match its fields: one that names a field the type does
not have, one that leaves a field out, and one with fields and no list at all. The arguments are `src`,
the Julia source, and `cfg`, the package's config, which this rule does not read. Returns one location
per type, quoting what is wrong.

It reads the parse tree rather than the text, so a keyword-default type — `Base.@kwdef struct` — is the
same case as any other. Pairing a docstring with the next `struct` by eye is what made an earlier
version of this check misread every type after one of those.
"""
function field_docs(src::AbstractString, cfg)
    out = Model.Location[]
    lines = split(src, '\n')
    for d in Texts.docstrings_of(src)
        fields = struct_fields(lines, d.node)
        isempty(fields) && continue
        documented = documented_fields(d.text)
        if documented === nothing
            push!(out, Model.Location(; file = "", line = d.line, node = d.node,
                                       text = "$(d.node) stores $(join(fields, ", ")) and documents no fields"))
            continue
        end
        ghost = setdiff(documented, fields)
        missed = setdiff(fields, documented)
        isempty(ghost) || push!(out, Model.Location(; file = "", line = d.line, node = d.node,
            text = "$(d.node) documents $(join(ghost, ", ")), which it does not have"))
        isempty(missed) || push!(out, Model.Location(; file = "", line = d.line, node = d.node,
            text = "$(d.node) has no bullet for $(join(missed, ", "))"))
    end
    return out
end

# The fields a struct declares, by name, read from the lines its node spans.
function struct_fields(lines, node::AbstractString)
    isempty(node) && return String[]
    opened = false
    out = String[]
    for line in lines
        if !opened
            occursin(Regex("\\bstruct\\s+" * replace(node, "!" => "!") * "\\b"), line) && (opened = true)
            continue
        end
        strip(line) == "end" && break
        m = match(r"^\s{2,}([A-Za-z_][A-Za-z0-9_!]*)\s*::", line)
        m === nothing || push!(out, String(m.captures[1]))
    end
    return out
end

# The field names a docstring's list claims, or `nothing` where it holds no list at all.
function documented_fields(doc::AbstractString)
    k = findfirst("The fields are", doc)
    k === nothing && return nothing
    names = String[]
    inlist = false
    for line in split(doc[first(k):end], '\n')[2:end]
        if occursin(FIELD_BULLET, line)
            inlist = true
            head = first(split(line, r" — | -- "))
            for m in eachmatch(FIELD_NAME, head); push!(names, String(m.captures[1])); end
        elseif inlist && !isempty(strip(line)) && !startswith(line, (' ', '\t'))
            break
        end
    end
    return names
end

"""
    FIELDS

A type with named fields documents them under "The fields are", one bullet per field.
"""
const FIELDS = Model.Rule(
    id = Symbol("RULE.DOC.FIELDS"),
    statement = "A type with named fields documents them under \"The fields are\", one bullet per field: every bullet a real field, and every field a bullet.",
    why = "A field list that has drifted is worse than none: it names what does not exist and hides what does.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, field_docs, false),
    examples = [
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing. The fields are:\n\n- `a` — the first.\n\"\"\"\nstruct S\n    a::Int\n    b::Int\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "every field a bullet"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing. The fields are:\n\n- `a` — the first.\n- `b` — the second.\n\"\"\"\nstruct S\n    a::Int\n    b::Int\nend\n",
            Model.Location[], "every field a bullet"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing. The fields are:\n\n- `a` — the first.\n- `c` — no such field.\n\"\"\"\nstruct S\n    a::Int\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "every bullet a real field"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing. The fields are:\n\n- `a` — the first.\n\"\"\"\nstruct S\n    a::Int\nend\n",
            Model.Location[], "every bullet a real field"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing with fields and no list.\n\"\"\"\nstruct S\n    a::Int\nend\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "documents them under \"The fields are\""),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    S\n\nA thing. The fields are:\n\n- `a` — the first.\n\"\"\"\nstruct S\n    a::Int\nend\n",
            Model.Location[], "documents them under \"The fields are\""),
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
const RULES = Model.Rule[ARG_BULLET, REGISTER, FIELDS, SENTENCE_OPENER]

end # module Docstrings