# The design's §5.2, §7; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.Citations

The `RULE.CIT.*` rules a program decides: that every reference carries a clickable DOI, and that the
full reference sits under the docstring's own `# References` heading and says the same thing as the
canonical entry.

Both were one text scan, `SCAN.DOI_CROSSCHECK`, which enforced two rules at once. They are two checks
here, because a rule whose violation is reported under another rule's name is a rule nobody can waive.
"""
module Citations

using ...Model
using ...Texts

# A DOI as it is written in prose: the resolver's URL, to whatever the surrounding markup ends it with.
const DOI_RE = r"doi\.org/[^\s\)\]\"]+"
# The one admitted citation form: the work's title, italicised, linked to its DOI.
const TITLE_LINK = r"\[(\*[^\]]+?\*)\]\((https://doi\.org/[^)\s]*)\)"
# A line that is a reference rather than prose about one: the lone-citation form, or a bullet naming a year.
const REFERENCE_LINE = r"^\s*(Reference:|-\s+.*\((19|20)\d\d[a-z]?\))"

# A DOI is compared decoded and without the punctuation a sentence leaves on it: `10.1017/S0022112096004090.`
# at the end of a sentence and the same DOI mid-list are one DOI, and a reader following either lands
# in the same place.
percent_decode(s) = replace(String(s), r"%([0-9A-Fa-f]{2})" => x -> string(Char(parse(Int, x[2:3]; base = 16))))
# The scheme is stripped too: the canonical list is read with a pattern that starts at `doi.org`, the
# docstring's with one that captures the whole link, and the two must compare equal.
norm_doi(s) = lowercase(rstrip(replace(percent_decode(s), r"^https?://" => ""), ['.', ',', ')', ';']))

"""
    doi_on_title(text, cfg) -> Vector{Model.Location}

Every reference that carries no clickable DOI, and every DOI written as the retired `[doi:…]` label
instead of on the work's title. The arguments are `text`, the file's prose, and `cfg`, the package's
config, which is not read. Returns one location per reference.

A DOI a reader cannot click is a string to retype; one written as a bare label is a DOI the reader
cannot tell from prose.
"""
function doi_on_title(text::AbstractString, cfg)
    out = Model.Location[]
    for (i, line) in Texts.unwrapped(text)
        # In code ticks the form is NAMED, not used: this rule's own statement quotes it, and so does
        # every page that tells an author which form was retired.
        for m in eachmatch(r"\[doi:[^\]]+\]", Texts.mask_code_spans(line))
            push!(out, Model.Location(; file = "", line = i,
                text = "the retired $(m.match) label form — put the DOI on the title, `[*Title*](https://doi.org/…)`"))
        end
        occursin(REFERENCE_LINE, line) || continue
        # `Reference:` alone opens a block list, whose entries are the lines under it.
        occursin(r"^\s*Reference:\s*$", line) && continue
        occursin(r"doi\.org/|openlibrary\.org/", line) && continue
        push!(out, Model.Location(; file = "", line = i,
            text = "a reference with no DOI or Open Library link on its title: " * strip(String(line))))
    end
    return out
end

const DOI = Model.Rule(
    id = Symbol("RULE.CIT.DOI"),
    statement = "Every reference carries a clickable DOI, or an Open Library link for a book, on its title.",
    why = "A DOI a reader cannot click is a string to retype; one written as a bare label is indistinguishable from prose.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, doi_on_title, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- Pope, *Turbulent Flows*, CUP (2000)\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "carries a clickable DOI"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- Pope, [*Turbulent Flows*](https://doi.org/10.1017/CBO9780511840531), CUP (2000)\n",
            Model.Location[], "carries a clickable DOI"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe spectrum is Kolmogorov's [doi:10.1098/rspa.1991.0075].\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "on its title"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe spectrum is [*Kolmogorov's*](https://doi.org/10.1098/rspa.1991.0075).\n",
            Model.Location[], "on its title"),
    ])

# ──────────────────────────────────────────────────────────── the full reference and its canonical entry

"""
    REFERENCES

Where the package keeps its canonical reference list: a file, optionally with `#` and the heading the
list sits under. Every full reference in a docstring is compared against it.
"""
const REFERENCES = Model.Parameter(:references, "docs/ARCHITECTURE.md")

"""
    canonical(root, cfg) -> Union{String,Nothing}

The text of the package's canonical reference list, or `nothing` where the package has none to read.
The arguments are `root`, the package root, and `cfg`, the package's config, which names the list.
Returns the text from the heading onwards where one is named, and the whole file otherwise.
"""
function canonical(root::AbstractString, cfg)
    where_ = REFERENCES.default
    for s in cfg.settings
        s.name === :references && s.value isa String && (where_ = s.value)
    end
    file, _, heading = partition(where_, '#')
    path = joinpath(root, file)
    isfile(path) || return nothing
    isempty(heading) && return read(path, String)
    lines = readlines(path)
    at = findfirst(l -> occursin(r"^#+\s", l) && strip(replace(l, r"^#+\s*" => "")) == strip(heading), lines)
    at === nothing && return nothing
    return join(lines[at:end], "\n")
end

# `partition` as Julia spells it in pieces: the part before the separator, the separator, and the rest.
function partition(s::AbstractString, sep::Char)
    i = findfirst(==(sep), s)
    i === nothing && return (String(s), "", "")
    return (String(s[1:prevind(s, i)]), string(sep), String(s[nextind(s, i):end]))
end

"""
    full_inline(root, cfg) -> Vector{Model.Location}

Every full reference sitting in a docstring's running prose, and every one under its `# References`
heading that disagrees with the canonical entry — a DOI the canonical list does not carry, or a title
that differs from the one it gives. The arguments are `root`, the package root, and `cfg`, the
package's config. Returns one location per disagreement.

The prose cites author–year and the section carries the work: a full reference mid-sentence is the
reader's eye leaving the sentence, and a copy of an entry is a copy that drifts.
"""
function full_inline(root::AbstractString, cfg)
    refs = canonical(root, cfg)
    known = refs === nothing ? Set{String}() : Set(norm_doi(m.match) for m in eachmatch(DOI_RE, refs))
    titles = refs === nothing ? Dict{String,String}() :
        Dict(norm_doi(u) => join(split(t), " ") for (t, u) in (m.captures for m in eachmatch(TITLE_LINK, refs)))

    out = Model.Location[]
    for file in sources(root, cfg)
        for d in Texts.docstrings(joinpath(root, file))
            body = d.text
            at = findfirst(r"(?m)^#+\s+References\s*$", body)
            for m in eachmatch(TITLE_LINK, body)
                # The docstring's own line the match sits on, and the file line that is: the body opens
                # on the line after `d.line`, which is the delimiter's.
                nth = 1 + count(==('\n'), body[1:prevind(body, m.offset)])
                in_section = at !== nothing && m.offset > first(at)
                title, url = m.captures
                if !in_section && !occursin(r"^\s*Reference:", split(body, '\n')[nth])
                    push!(out, Model.Location(; file, line = d.line + nth, node = d.node,
                        text = "a full reference in the prose: cite author–year here and put the work under this docstring's `# References` section"))
                    continue
                end
                doi = norm_doi(url)
                if refs === nothing || !(doi in known)
                    push!(out, Model.Location(; file, line = d.line + nth, node = d.node,
                        text = "DOI $doi is cited here but absent from the canonical reference list"))
                elseif haskey(titles, doi) && join(split(title), " ") != titles[doi]
                    push!(out, Model.Location(; file, line = d.line + nth, node = d.node,
                        text = "the title differs from the canonical entry for $doi: here $(join(split(title), " ")), there $(titles[doi])"))
                end
            end
        end
    end
    return out
end

"""
    sources(root, cfg) -> Vector{String}

The Julia files whose docstrings this rule reads: what the config's docstring set names, or `src/` and
`ext/` where it names nothing. The arguments are `root`, the package root, and `cfg`, the package's
config. Returns the paths, relative to `root`.
"""
function sources(root::AbstractString, cfg)
    named = get(cfg.filesets, Model.FileSet.DOCSTRINGS, String[])
    files = [p for p in named if isfile(joinpath(root, p))]
    isempty(files) || return files
    written = Set(vcat(cfg.generated, first.(cfg.copies)))
    out = String[]
    for (dir, _, fs) in walkdir(root)
        rel = relpath(dir, root)
        startswith(rel, ".git") && continue
        for f in fs
            endswith(f, ".jl") || continue
            p = replace(rel == "." ? f : joinpath(rel, f), '\\' => '/')
            (startswith(p, "src/") || startswith(p, "ext/")) && !(p in written) && push!(out, p)
        end
    end
    return sort!(out)
end

const REFERENCE_ENTRY = "- Pope, [*Turbulent Flows*](https://doi.org/10.1017/CBO9780511840531), CUP (2000)\n"

const FULL_INLINE = Model.Rule(
    id = Symbol("RULE.CIT.FULL_INLINE"),
    statement = "A docstring cites author–year in its prose and carries the full reference in a `# References` section, identical to the canonical entry in title and DOI.",
    why = "A full reference mid-sentence takes the reader's eye out of the sentence, and a hand-copied entry drifts from the one the package keeps.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.FILE_TREE, full_inline, false),
    parameters = Model.Parameter[REFERENCES],
    examples = [
        Model.TreeExample(
            ["docs/ARCHITECTURE.md" => "# Design\n\n" * REFERENCE_ENTRY,
             "src/Example.jl" => """
             module Example
             \"\"\"
                 mix(u)

             The mixing length, following Pope, [*Turbulent Flows*](https://doi.org/10.1017/CBO9780511840531), CUP (2000).
             \"\"\"
             mix(u) = u
             end
             """],
            [Model.Location(; file = "src/Example.jl", line = 5)], "cites author–year in its prose"),
        Model.TreeExample(
            ["docs/ARCHITECTURE.md" => "# Design\n\n" * REFERENCE_ENTRY,
             "src/Example.jl" => """
             module Example
             \"\"\"
                 mix(u)

             The mixing length, following Pope (2000).

             # References

             $(REFERENCE_ENTRY)\"\"\"
             mix(u) = u
             end
             """],
            Model.Location[], "cites author–year in its prose"),
        Model.TreeExample(
            ["docs/ARCHITECTURE.md" => "# Design\n\n" * REFERENCE_ENTRY,
             "src/Example.jl" => """
             module Example
             \"\"\"
                 mix(u)

             The mixing length, following Pope (2000).

             # References

             - Pope, [*Turbulent Flow*](https://doi.org/10.1017/CBO9780511840531), CUP (2000)
             \"\"\"
             mix(u) = u
             end
             """],
            [Model.Location(; file = "src/Example.jl", line = 9)], "identical to the canonical entry"),
        Model.TreeExample(
            ["docs/ARCHITECTURE.md" => "# Design\n\n" * REFERENCE_ENTRY,
             "src/Example.jl" => """
             module Example
             \"\"\"
                 mix(u)

             The mixing length, following Pope (2000).

             # References

             $(REFERENCE_ENTRY)\"\"\"
             mix(u) = u
             end
             """],
            Model.Location[], "identical to the canonical entry"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[DOI, FULL_INLINE]

end # module Citations
