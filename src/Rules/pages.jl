"""
    Rules.Pages

The rules about a page or a docstring as a whole: the provenance banner it must carry, how wide its
signature may be, how it cites, how it names a sibling package, and the references it must not make.

These are the fourth batch of the conversion. Several read a value the
package sets — the banner text, the sibling sites — which arrives as a [`Model.Parameter`](@ref) rather
than as a line in a config the rule has to know about.
"""
module Pages

using ...Model
using ...Texts

const BANNER = "!!! info \"Written by AI, not regularly reviewed\"\n    This page is written by AI and is not reviewed regularly by a human."

"""
    ai_banner(text, cfg) -> Vector{Model.Location}

Whether a page that must carry the provenance banner carries it, verbatim. The arguments are `text`, the
page, and `cfg`, the package's config, which this rule does not read. Returns one location for a page
that lacks it or carries a drifted copy, and none otherwise.

Verbatim is the point: a banner reworded in one package is a banner a reader learns to skim. A page that
mentions the words without the exact text is reported as drifted rather than as missing, which is the
more useful thing to be told.
"""
function ai_banner(text::AbstractString, cfg)
    occursin(BANNER, text) && return Model.Location[]
    mentions = occursin("Written by AI", text)
    return [Model.Location(; file = "", line = 1,
                            text = mentions ? "the banner has drifted from the fleet's text — copy it verbatim" :
                                              "no provenance banner on a page that must carry one")]
end

const AI_BANNER = Model.Rule(
    id = Symbol("RULE.DOC.AI_BANNER"),
    statement = "A rationale page and a Literate example carry the provenance banner, verbatim.",
    why = "A banner reworded in one package is a banner a reader learns to skim past in all of them.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.RATIONALE, Model.FileSet.LITERATE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, ai_banner, false),
    examples = [
        Model.TextExample(Model.FileSet.RATIONALE, "# A rationale\n\nThe reasoning.\n",
            [Model.Location(; file = "docs/RATIONALE.md", line = 1)], "carries the banner"),
        Model.TextExample(Model.FileSet.RATIONALE, "# A rationale\n\n" * BANNER * "\n\nThe reasoning.\n",
            Model.Location[], "carries the banner"),
        Model.TextExample(Model.FileSet.RATIONALE,
            "# A rationale\n\n!!! info \"Written by AI\"\n    Roughly the same words.\n",
            [Model.Location(; file = "docs/RATIONALE.md", line = 1)], "verbatim"),
        Model.TextExample(Model.FileSet.RATIONALE, "# A rationale\n\n" * BANNER * "\n",
            Model.Location[], "verbatim"),
    ])

const SIGNATURE_WIDTH = 88

"""
    signature_width(src, cfg) -> Vector{Model.Location}

Every signature line of a docstring wider than the house column. The arguments are `src`, the Julia
source, and `cfg`, the package's config, which this rule does not read. Returns one location per line.

The header block ends at the first line that is not indented, so only the signature itself is measured:
a wide line there wraps in the rendered page and in every terminal that shows the docstring.
"""
function signature_width(src::AbstractString, cfg)
    out = Model.Location[]
    for d in Texts.docstrings_of(src)
        for (i, line) in pairs(split(d.text, '\n'))
            startswith(line, "    ") || break
            length(line) > SIGNATURE_WIDTH &&
                push!(out, Model.Location(; file = "", line = d.line + i, node = d.node,
                                           text = "$(length(line)) columns: " * strip(String(line))))
        end
    end
    return out
end

const SIGNATURE_MIRROR = Model.Rule(
    id = Symbol("RULE.DOC.SIGNATURE_MIRROR"),
    statement = "A docstring's signature block fits the house column and repeats only as much of the method as a reader needs.",
    why = "A signature wider than the column wraps in the rendered page and in every terminal that shows it.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, signature_width, false),
    examples = [
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(" * "a"^90 * ")\n\nDoes a thing.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 2)], "fits the house column"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a)\n\nDoes a thing.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "fits the house column"),
    ])

"""
    crammed_citation(src, cfg) -> Vector{Model.Location}

Every references block in a docstring that runs several citations together with semicolons instead of
listing them. The arguments are `src`, the Julia source, and `cfg`, the package's config, which this rule
does not read. Returns one location per block.

A reader looking for one reference in a semicolon-separated run has to parse the whole paragraph; a list
gives each its own line and its own link.
"""
function crammed_citation(src::AbstractString, cfg)
    out = Model.Location[]
    for d in Texts.docstrings_of(src)
        for m in eachmatch(r"References?:[^\n]*(?:\n[^\n]+)*"m, d.text)
            occursin(';', m.match) || continue
            offset = count(==('\n'), d.text[1:prevind(d.text, m.offset)]) + 1
            push!(out, Model.Location(; file = "", line = d.line + offset, node = d.node,
                                       text = strip(first(split(m.match, '\n')))))
        end
    end
    return out
end

const BLOCK_LIST = Model.Rule(
    id = Symbol("RULE.CIT.BLOCK_LIST"),
    statement = "References are listed one to a line, never run together with semicolons.",
    why = "A reader looking for one reference in a semicolon-separated run has to parse the whole paragraph.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, crammed_citation, false),
    examples = [
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(x)\n\nDoes a thing.\n\nReferences: Smith 1999; Jones 2001\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 6)], "never run together with semicolons"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(x)\n\nDoes a thing.\n\n# References\n\n- Smith 1999.\n- Jones 2001.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "never run together with semicolons"),
    ])

# The PROGRAM half of the rule, and no wider. A section number and a gitignored directory are citations
# whatever the sentence around them: neither can be followed from the REPL, ever. A file name is not —
# a docstring for the verb that writes `CLAUDE.md` must name it, and telling that apart from a citation
# needs the meaning of the sentence, which is the agent half (RULE.CIT.NO_INACCESSIBLE).
const DEAD_REFERENCE = r"§\s?[0-9]|inspiration/"

"""
    dead_reference(text, cfg) -> Vector{Model.Location}

Every reference to a document by path or section number rather than by link. The arguments are `text`,
the file's prose, and `cfg`, the package's config, which this rule does not read. Returns one location
per line.

A section number and a file path both go stale silently: the section is renumbered, the file is renamed,
and the sentence still reads as though it pointed somewhere.
"""
function dead_reference(text::AbstractString, cfg)
    return [Model.Location(; file = "", line = i, text = strip(String(line)))
            for (i, line) in pairs(split(text, '\n')) if occursin(DEAD_REFERENCE, line)]
end

const NO_DEAD_REFS = Model.Rule(
    id = Symbol("RULE.DOC.NO_DEAD_REFS"),
    statement = "A docstring or error message cites no section number and no inaccessible source; it reads complete at the REPL.",
    why = "At the REPL there are no links: a section number cannot be followed, and it is renumbered besides.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, dead_reference, false),
    examples = [
        Model.TextExample(Model.FileSet.DOCSTRINGS,
            "\"\"\"\n    f(x)\n\nAs §4 of the design says.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 4)], "cites no section number"),
        Model.TextExample(Model.FileSet.DOCSTRINGS,
            "\"\"\"\n    f(x)\n\nAs the design says.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "cites no section number"),
        Model.TextExample(Model.FileSet.DOCSTRINGS,
            "\"\"\"\n    f(x)\n\nAs the notes in inspiration/ explain.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 4)], "no inaccessible source"),
        Model.TextExample(Model.FileSet.DOCSTRINGS,
            "\"\"\"\n    f(x)\n\nAs the published derivation explains.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "no inaccessible source"),
    ])

"""
    RULES

The rules of this batch, in the order they were converted.
"""
const RULES = Model.Rule[AI_BANNER, SIGNATURE_MIRROR, BLOCK_LIST, NO_DEAD_REFS]

end # module Pages
