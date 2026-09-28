# The design's §5.2, §7; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.Citations

The `RULE.CIT.*` rules a program decides: that every reference carries a clickable DOI, that the full
reference sits under the docstring's own `# References` heading and says the same thing as the canonical
entry, and — under `gbg check --network` alone — that every such link resolves to the work its title
names.

The first two were one text scan, `SCAN.DOI_CROSSCHECK`, which enforced two rules at once. They are two
checks here, because a rule whose violation is reported under another rule's name is a rule nobody can
waive. The third is the program half of the split the plan's batch d named: the reader's half asks
whether a citation is to something unpublished, this asks whether the link answers.
"""
module Citations

import Downloads, JSON3

using ...Model
using ...Texts
using ..Docstrings: body_line

# A DOI as it is written in prose: the resolver's URL, to whatever the surrounding markup ends it with.
# A parenthesised group inside it is part of it — pre-2000 Elsevier DOIs carry `(84)` routinely — and
# cutting at the first `)` sent the resolver a URL that answers 404 for a correct reference.
const DOI_PATH = raw"(?:[^\s()\]\"]|\([^\s()]*\))+"
const DOI_RE = Regex("doi\\.org/" * DOI_PATH)
# The one admitted citation form: the work's title, italicised, linked to its DOI.
const TITLE_LINK = Regex("\\[(\\*[^\\]]+?\\*)\\]\\((https://doi\\.org/" * DOI_PATH * ")\\)")
const RESOLVABLE_LINK = Regex("\\[([^\\]]*)\\]\\((https://(?:doi\\.org|openlibrary\\.org)/" * DOI_PATH * ")\\)")
# A line that is a reference rather than prose about one: the lone-citation form, or a bullet with a
# year that has the SHAPE of a reference — a title in italics, pages after the year, or an author list
# of surnames with initials followed by the year and then a capitalised title, as in
# `- Pope, S. B. (2000). Turbulent Flows.` A bullet that merely cites author–year, as `RULE.CIT.STYLE`
# asks the prose to, is prose: `- Kolmogorov (1941) gives the 5/3 law.` names a surname with no
# initials and goes on with a verb.
const YEAR = raw"\((19|20)\d\d[a-z]?\)"
const AUTHOR = raw"(?:[A-Z][\w'’-]+,\s+(?:[A-Z]\.[\s-]*)+|(?:[A-Z]\.[\s-]*)+[A-Z][\w'’-]+)"
const REFERENCE_LINE = Regex("^\\s*(Reference:|-\\s+(?=.*" * YEAR * ")(?=.*(?:\\*[^*\\n]+\\*|" * YEAR * "[\\s,.:]*\\d))|" *
                             "-\\s+" * AUTHOR * ".*?" * YEAR * "[.,:]?\\s+[A-Z])")

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
    for (i, line, breaks) in Texts.unwrapped(text)
        # In code ticks the form is NAMED, not used: this rule's own statement quotes it, and so does
        # every page that tells an author which form was retired.
        masked = Texts.mask_code_spans(line)
        for m in eachmatch(r"\[doi:[^\]]+\]", masked)
            push!(out, Model.Location(; file = "", line = Texts.line_at(i, breaks, masked, m.offset),
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
        # A reference with pages after the year and no italic title is a reference; a bullet citing
        # author–year in passing is prose about one.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- Lalescu, Teaca, Carati, Implementation of high order spline interpolations, J. Comput. Phys. 229 (2010) 5862–5869.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "carries a clickable DOI"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- Pope, S. B. (2000). Turbulent Flows. Cambridge University Press.\n- Kolmogorov, A. N. (1941). The local structure of turbulence. Dokl. Akad. Nauk SSSR 30, 301–305.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3), Model.Location(; file = "docs/src/page.md", line = 4)],
            "carries a clickable DOI"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- Kolmogorov (1941) gives the 5/3 law.\n- The fix landed (2024).\n",
            Model.Location[], "carries a clickable DOI"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe spectrum is Kolmogorov's [doi:10.1098/rspa.1991.0075].\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "on its title"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe spectrum is [*Kolmogorov's*](https://doi.org/10.1098/rspa.1991.0075).\n",
            Model.Location[], "on its title"),
        # Each label inside a parenthesis wrapped over lines is reported on its own line, not the first.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe bump is known (Qian, [doi:10.1063/1.864902](https://doi.org/10.1063/1.864902);\n" *
            "Kraichnan, [doi:10.1017/S0022112059000362](https://doi.org/10.1017/S0022112059000362)).\n",
            [Model.Location(; file = "docs/src/page.md", line = 3), Model.Location(; file = "docs/src/page.md", line = 4)],
            "on its title"),
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
        # The rule's own setting alone: one declared under another rule's id would let a typo in the
        # config redirect the canonical list.
        s.rule === FULL_INLINE.id && s.name === :references && s.value isa String && (where_ = s.value)
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
        src = read(joinpath(root, file), String)
        for d in Texts.docstrings_of(src; filename = file)
            body = d.text
            at = findfirst(r"(?m)^#+\s+References\s*$", body)
            opens = body_line(src, d)
            for m in eachmatch(TITLE_LINK, body)
                # The docstring's own line the match sits on, and the file line that is.
                nth = 1 + count(==('\n'), body[1:prevind(body, m.offset)])
                line = opens + nth - 1
                in_section = at !== nothing && m.offset > first(at)
                title, url = m.captures
                if !in_section && !occursin(r"^\s*Reference:", split(body, '\n')[nth])
                    push!(out, Model.Location(; file, line, node = d.node,
                        text = "a full reference in the prose: cite author–year here and put the work under this docstring's `# References` section"))
                    continue
                end
                doi = norm_doi(url)
                if refs === nothing || !(doi in known)
                    push!(out, Model.Location(; file, line, node = d.node,
                        text = "DOI $doi is cited here but absent from the canonical reference list"))
                elseif haskey(titles, doi) && join(split(title), " ") != titles[doi]
                    push!(out, Model.Location(; file, line, node = d.node,
                        text = "the title differs from the canonical entry for $doi: here $(join(split(title), " ")), there $(titles[doi])"))
                end
            end
            # The retired `[doi:…](…)` label is a full reference in the prose too: seen only by
            # `RULE.CIT.DOI`, it met this rule in the round after that one was fixed (HT, 2026-09-28).
            # Quoted in code ticks it is named, not used.
            masked = Texts.mask_code_spans(body)
            for m in eachmatch(LABEL_LINK, masked)
                nth = 1 + count(==('\n'), masked[1:prevind(masked, m.offset)])
                (at !== nothing && m.offset > first(at)) && continue
                occursin(r"^\s*Reference:", split(masked, '\n')[nth]) && continue
                push!(out, Model.Location(; file, line = opens + nth - 1, node = d.node,
                    text = "a full reference in the prose: cite author–year here and put the work under this docstring's `# References` section"))
            end
        end
    end
    return out
end

# A DOI linked on a `[doi:…]` label rather than on a title: the form `RULE.CIT.DOI` retires.
const LABEL_LINK = r"\[doi:[^\]]+\]\(https?://(?:dx\.)?doi\.org/[^)\s]+\)"

"""
    sources(root, cfg) -> Vector{String}

The Julia files whose docstrings this rule reads: the config's docstring set, resolved as every other
rule resolves it — its globs where the package names them, `src/` and `ext/` where it names nothing,
and never a file the package ignores or writes at build time. The arguments are `root`, the package
root, and `cfg`, the package's config. Returns the paths, relative to `root`.
"""
sources(root::AbstractString, cfg) = Texts.files(cfg, root, Model.FileSet.DOCSTRINGS)

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

             The mixing length (Pope 2000, [doi:10.1017/CBO9780511840531](https://doi.org/10.1017/CBO9780511840531)).
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

# ──────────────────────────────────────────────────────────── the link that answers

"""
    RESOLVER

How a link is resolved: a function of the URL returning `(status, title)` — the HTTP status, 0 where
nothing answered, and for a DOI the title the resolver's record carries. The one place the network is
touched; `test/rules.jl` swaps it for a canned one, so the rule's examples run offline.
"""
const RESOLVER = Ref{Function}(url -> resolve_online(url))

"""
    resolve_online(url) -> (status, title)

Asks the resolver for the work behind `url`. The argument is `url`. Returns the HTTP status (0 where
nothing answered within the timeout) and, for a DOI, the title of the record it resolves to.

A DOI is asked for its citation record rather than followed to a publisher's page: the record is what
says which work the DOI names, and a paywall in front of the page is not the reader's inability to open it.
"""
function resolve_online(url::AbstractString)
    buf = IOBuffer()
    response = try
        Downloads.request(String(url); method = "GET", output = buf, throw = false, timeout = 20,
                          headers = ["Accept" => "application/vnd.citationstyles.csl+json",
                                     "User-Agent" => "GBGCodingTools (gbg check --network)"])
    catch
        return (0, "")
    end
    response isa Downloads.Response || return (0, "")
    title = ""
    if occursin("doi.org/", url) && response.status < 400
        title = try
            String(get(JSON3.read(String(take!(buf))), :title, ""))
        catch
            ""
        end
    end
    return (response.status, title)
end

# Whether the linked title and the resolved title are the same work: at least half of the linked title's
# words of four letters or more appear in the record's title. Looser would pass a wrong record; tighter
# would fail a subtitle or a translated article.
function names_the_work(linked::AbstractString, title::AbstractString)
    words = [w for w in split(lowercase(linked), r"[^a-z0-9]+") if length(w) >= 4]
    isempty(words) && return true
    return 2 * count(w -> occursin(w, lowercase(title)), words) >= length(words)
end

"""
    links_resolve(text, cfg) -> Vector{Model.Location}

Every DOI or Open Library link on a title that does not answer, or answers with another work's record.
The arguments are `text`, the prose, and `cfg`, the package's config, which this rule does not read.
Returns one location per link, with what the resolver said.
"""
function links_resolve(text::AbstractString, cfg)
    out = Model.Location[]
    for (i, line, breaks) in Texts.unwrapped(text)
        masked = Texts.mask_math_spans(Texts.mask_code_spans(line))
        for m in eachmatch(RESOLVABLE_LINK, masked)
            at = Texts.line_at(i, breaks, masked, m.offset)
            linked = strip(String(m.captures[1]), ['*', '_', ' '])
            url = String(m.captures[2])
            status, title = RESOLVER[](url)
            if status == 0 || status >= 400
                push!(out, Model.Location(; file = "", line = at,
                    text = url * " does not resolve" * (status == 0 ? " (nothing answered)" : " (HTTP $status)")))
            elseif !isempty(title) && !names_the_work(linked, title)
                push!(out, Model.Location(; file = "", line = at,
                    text = url * " resolves to \"" * title * "\", not to \"" * linked * "\""))
            end
        end
    end
    return out
end

const RESOLVES = Model.Rule(
    id = Symbol("RULE.CIT.RESOLVES"),
    statement = "Every DOI or Open Library link on a title answers, and answers with the work the title names.",
    why = "A link is a promise that the reader can reach the work. A DOI that answers 404, or answers with another paper's record, breaks it and nothing in the text looks different. This reaches the network, so it runs only under `gbg check --network` — on request, never in a build or a test — which is why the reader's rule about inaccessible sources does not ask it.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, links_resolve, true),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- Pope, [*Turbulent Flows*](https://doi.org/10.9999/no.such.record), CUP (2000)\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "answers"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- Pope, [*Turbulent Flows*](https://doi.org/10.1017/CBO9780511840531), CUP (2000)\n",
            Model.Location[], "answers"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- Pope, [*Turbulent Flows*](https://doi.org/10.1098/rspa.1991.0075), CUP (2000)\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "answers with the work the title names"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- Kolmogorov, [*The local structure of turbulence in incompressible viscous fluid*](https://doi.org/10.1098/rspa.1991.0075), Proc. R. Soc. A (1991)\n",
            Model.Location[], "answers with the work the title names"),
        # A `[` inside a math span, eighteen lines and a paragraph break before a correct reference,
        # is not a link opening: the shape GBGPeriodicFields met on the rule's first real run.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe box is ``[o_a, o_a + L_a)`` per axis — origin-aware, and so on.\nMore prose here.\n\nAnother paragraph.\n\n- C. C. Lalescu, B. Teaca, D. Carati, [*Implementation of high order spline interpolations for tracking test particles in discretized fields*](https://doi.org/10.1016/j.jcp.2009.10.046), J. Comput. Phys. **229**(17) (2010) 5862–5869.\n",
            Model.Location[], "answers with the work the title names"),
        # A DOI holding a parenthesised group is asked for whole.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- Canuto, [*A method*](https://doi.org/10.1016/0021-9991(84)90019-3), J. Comput. Phys. (1984)\n",
            Model.Location[], "answers"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[DOI, FULL_INLINE, RESOLVES]

end # module Citations
