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
using ..Catalogue: FLEET, site_of

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
# A Literate source becomes a PAGE; a script beside it does not, however alike they look on disk. What
# separates them is the Markdown structure Literate renders — a `# #` heading — not the directory or the
# extension. GBGPeriodicFields keeps three runnable scripts beside its one rendered example, and this
# rule reported a missing banner on all three: a banner for a reader of a page nobody publishes.
# `[ \t]`, not `\s`: `\s` matches a newline, so `^#\s+#` matched any two consecutive comment lines and
# called every script a Literate page.
const LITERATE_HEADING = r"(?m)^#[ \t]+#"

function ai_banner(text::AbstractString, cfg)
    # A Markdown page is a page. A Julia file is one only if Literate renders it, and what Literate
    # renders is the Markdown structure in its comments — a `# #` heading. Fenced blocks are removed
    # before looking for code, or a page holding a `julia` example would read as a script itself.
    unfenced = replace(text, r"(?ms)^```.*?^```" => "")
    is_script = occursin(r"(?m)^(using|import|function|const|module|struct|macro)\s", unfenced)
    is_script && !occursin(LITERATE_HEADING, text) && return Model.Location[]
    # Literate renders a full-line `# ` comment as prose, so the banner in a Literate source carries that
    # prefix on every line and MUST: without it the admonition would render as a code block. Comparing
    # the raw text called the correct thing drifted. The file is not the page.
    unprefixed = replace(text, r"(?m)^#[ \t]?" => "")
    (occursin(BANNER, text) || occursin(BANNER, unprefixed)) && return Model.Location[]
    # Whether this is a banner that has DRIFTED or no banner at all, which is a different repair and so
    # a different message. It tested for `Written by AI`, the title's wording, and the body says
    # `written by AI` — so a page whose TITLE had been reworded, the commonest drift there is, reported
    # as carrying no banner and sent a reader looking for something that was in front of them.
    mentions = occursin(r"written by AI"i, text) || occursin(r"written by AI"i, unprefixed)
    return [Model.Location(; file = "", line = 1,
                            text = mentions ? "the banner has drifted from the fleet's text — copy it verbatim" :
                                              "no provenance banner on a page that must carry one")]
end

"""
    BANNER_PAGES

The pages this package requires the provenance banner on, as globs. Unset — the default — the rule reads
its file sets, the rationale documents and the rendered Literate examples.

A package sets it where its list is its own: this one requires the banner on EVERY page of its site,
because the owner reviews the four science packages' API prose and not this one's, and that requirement
was written in `CLAUDE.md` and enforced by nothing until 2026-09-18. It is not `rationale`, which other
rules read; naming the pages here leaves those sets alone.
"""
const BANNER_PAGES = Model.Parameter(:banner_pages, String[])

const AI_BANNER = Model.Rule(
    id = Symbol("RULE.DOC.AI_BANNER"),
    statement = "A rationale page and a rendered Literate example carry the provenance banner, verbatim; a script that is never rendered is not a page and carries none.",
    why = "A banner reworded in one package is a banner a reader learns to skim past in all of them.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.RATIONALE, Model.FileSet.LITERATE],
    files_parameter = :banner_pages,
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, ai_banner, false),
    parameters = [BANNER_PAGES],
    examples = [
        Model.TextExample(Model.FileSet.RATIONALE, "# A rationale\n\nThe reasoning.\n",
            [Model.Location(; file = "docs/RATIONALE.md", line = 1)], "carries the banner"),
        # A runnable script beside the rendered example: no Literate heading, so no page, so no banner.
        Model.TextExample(Model.FileSet.LITERATE,
            "using Printf\n\n# Re-render the figures from a saved dump.\nfunction main()\n    return 1\nend\n",
            Model.Location[], "a script that is never rendered is not a page"),
        # The same file once it is a Literate source: a heading, so a page, so the banner is owed.
        Model.TextExample(Model.FileSet.LITERATE,
            "# # The worked example\n#\n# What it shows.\n\nusing Printf\n",
            [Model.Location(; file = "examples/example.jl", line = 1)], "a script that is never rendered is not a page"),
        # The banner as Literate requires it: every line prefixed `# `, which is not drift.
        Model.TextExample(Model.FileSet.LITERATE,
            "# # The worked example\n#\n" * join("# " .* split(BANNER, "\n"), "\n") * "\n\nusing Printf\n",
            Model.Location[], "carries the banner"),
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
            # A semicolon inside brackets is punctuation, not a separator between citations: a link's
            # target, or a parenthetical note — "(deposition / charge assignment; the NGP and CIC
            # windows)" — is one citation's own text, and reading it as two reported a correct reference.
            bare = replace(m.match, r"\([^()]*\)" => " ", r"\[[^\[\]]*\]" => " ")
            occursin(';', bare) || continue
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
        # One citation carrying a parenthetical note of its own is still one citation.
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(x)\n\nDoes a thing.\n\nReference: Smith 1999 (the window; and its width)\n\"\"\"\nf(x) = x\n",
            Model.Location[], "never run together with semicolons"),
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

# ─────────────────────────────────────────────────────────────── an API page's own structure

"""
    api_structure(text, cfg) -> Vector{Model.Location}

Every place an API page departs from the house structure: an internal-API section that is not last, an
empty block of collected docstrings, and an index block. The arguments are `text`, the page, and `cfg`,
the package's config, which this rule does not read. Returns one location per departure.

Each renders as something a reader must work around: a section of internals in the middle of the public
surface, a heading with nothing under it, and a machine-ordered index on a page whose whole point is that
a person grouped it.
"""
function api_structure(text::AbstractString, cfg)
    out = Model.Location[]
    sections = [m.captures[1] for m in eachmatch(r"^## (.+)$"m, text)]
    k = findfirst(==("Internal API"), sections)
    if k !== nothing && k != length(sections)
        push!(out, Model.Location(; file = "", line = 1,
            text = "`## Internal API` is section $k of $(length(sections)) — it comes last"))
    end
    for m in eachmatch(r"```@docs\n(.*?)```"s, text)
        isempty(strip(m.captures[1])) || continue
        push!(out, Model.Location(; file = "", line = count(==('\n'), text[1:prevind(text, m.offset)]) + 1,
                                   text = "an empty block of collected docstrings renders as a heading with nothing under it"))
    end
    for m in eachmatch(r"```@index"s, text)
        push!(out, Model.Location(; file = "", line = count(==('\n'), text[1:prevind(text, m.offset)]) + 1,
                                   text = "an index block: an API page is grouped by a person, never indexed"))
    end
    return out
end

const INTERNAL_API = Model.Rule(
    id = Symbol("RULE.DOC.INTERNAL_API"),
    statement = "An API page puts its internal section last, holds no empty block of collected docstrings, and is never indexed.",
    why = "Internals in the middle of the public surface, and an index on a hand-grouped page, both make a reader work around the page.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, api_structure, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# API\n\n## Internal API\n\nThe internals.\n\n## Public\n\nThe public part.\n",
            [Model.Location(; file = "docs/src/page.md", line = 1)], "its internal section last"),
        Model.TextExample(Model.FileSet.PAGES,
            "# API\n\n## Public\n\nThe public part.\n\n## Internal API\n\nThe internals.\n",
            Model.Location[], "its internal section last"),
        Model.TextExample(Model.FileSet.PAGES,
            "# API\n\n## Public\n\n```@docs\n```\n",
            [Model.Location(; file = "docs/src/page.md", line = 5)], "no empty block of collected docstrings"),
        Model.TextExample(Model.FileSet.PAGES,
            "# API\n\n## Public\n\n```@docs\nf\n```\n",
            Model.Location[], "no empty block of collected docstrings"),
        Model.TextExample(Model.FileSet.PAGES,
            "# API\n\n## Public\n\n```@index\n```\n",
            [Model.Location(; file = "docs/src/page.md", line = 5)], "never indexed"),
        Model.TextExample(Model.FileSet.PAGES,
            "# API\n\n## Public\n\nGrouped by hand.\n",
            Model.Location[], "never indexed"),
    ])

# ───────────────────────────────────────────────────────── naming a sibling package, and its site

"""
    SIBLING_SITES

The sibling packages a first mention links to, and where their sites are. A package overrides this with a
[`Model.Setting`](@ref); the default is the fleet as it stands.

DERIVED from `Catalogue.FLEET`, which is the fleet's one home, rather than being a second list of the
same packages: two lists diverge, and this pair diverging is silent both ways.
"""
const SIBLING_SITES = Model.Parameter(:sibling_sites,
                                      [c.name => site_of(c.github) for c in FLEET])

"""
    sibling_link(text, cfg) -> Vector{Model.Location}

Every first mention of a sibling package that is not a link to that package's site, and every later
mention that links the site again where a bare name belongs. The arguments are `text`, the file's prose,
and `cfg`, the package's config, which names the package doing the mentioning. Returns one location per
mention.

A reader meeting a sibling's name for the first time needs to be able to reach it; meeting it a fourth
time, linked again, learns only that the writer was not reading.
"""
function sibling_link(text::AbstractString, cfg)
    out = Model.Location[]
    lines = split(text, '\n')
    for (name, site) in SIBLING_SITES.default
        name == cfg.package && continue
        # `.jl` is part of the name wherever a package is named as a repository — which is how its own
        # link text and its URL both spell it. Reading the bare name only, the rule found the first
        # mention INSIDE a link it did not recognise and reported the link as missing.
        name_re = Regex("(?<![A-Za-z0-9_])" * name * "(?:\\.jl)?(?![A-Za-z0-9_])")
        # The trailing slash of a site is optional in a link, and the table carries one. Matching it
        # literally, a correct link to `…/Package.jl` did not count, and the rule reported the first
        # mention — which was the link's own text — as unlinked.
        bare_site = rstrip(site, '/')
        link_re = Regex("\\[`?" * name * "(?:\\.jl)?`?\\]\\(\\Q" * bare_site * "\\E/?")
        home_re = Regex("\\[`?" * name * "(?:\\.jl)?`?\\]\\(\\Q" * bare_site * "\\E/?[\"')]")
        seen = false
        for (n, raw) in pairs(lines)
            o = findfirst(name_re, raw); o === nothing && continue
            m = match(link_re, raw)
            linked = m !== nothing && m.offset <= first(o) <= m.offset + ncodeunits(m.match)
            if !seen
                seen = true
                linked || push!(out, Model.Location(; file = "", line = n,
                    text = "the first mention of `$name` is not a link to its site"))
            elseif linked && match(home_re, raw) !== nothing
                push!(out, Model.Location(; file = "", line = n,
                    text = "a later mention of `$name` links its site again where a bare name belongs"))
            end
        end
    end
    return out
end

const SIBLING_LINK = Model.Rule(
    id = Symbol("RULE.DOC.SIBLING_LINK"),
    statement = "The first mention of a sibling package links to that package's site; later mentions are bare.",
    why = "A reader meeting the name for the first time must be able to reach it, and a fourth link teaches nothing.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, sibling_link, false),
    parameters = Model.Parameter[SIBLING_SITES],
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nAs GBGCloudPhysics does it.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "the first mention links"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nAs [GBGCloudPhysics](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/) does it.\n",
            Model.Location[], "the first mention links"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nAs [GBGCloudPhysics](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/) does it.\n" *
            "And again, [GBGCloudPhysics](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/), linked twice.\n",
            [Model.Location(; file = "docs/src/page.md", line = 4)], "later mentions are bare"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nAs [GBGCloudPhysics](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/) does it.\n" *
            "And again, GBGCloudPhysics, bare.\n",
            Model.Location[], "later mentions are bare"),
    ])

"""
    RULES

The rules of this batch, in the order they were converted.
"""


# ───────────────────────────────────────────────── a claim this package has retired, said again

"""
    RETIRED_CLAIMS

The phrases this package has retired, as [`Model.RetiredClaim`](@ref) values. Empty by default, and a
package that has retired nothing has nothing to ban.
"""
const RETIRED_CLAIMS = Model.Parameter(:retired_claims, Model.RetiredClaim[])

"""
    retired_claims(text, cfg) -> Vector{Model.Location}

Every place this package asserts something it has retired. The arguments are `text`, the file's prose,
and `cfg`, the package's config, which carries the phrases. Returns one location per occurrence, each
carrying the reason the claim was retired.

Whitespace is flattened before matching: the phrases worth banning are sentences, a sentence in a
hard-wrapped document crosses a line, and a check that matches only within a line is blind to most of
what it is looking for. Matching is case-insensitive, since a claim at the start of a sentence is the
same claim.

The phrase is LITERAL. It is escaped before it is used, so nothing a package writes in its config is
compiled as a pattern inside its own docs build.
"""
function retired_claims(text::AbstractString, cfg)
    entries = Model.RetiredClaim[]
    for s in cfg.settings
        s.name === :retired_claims && s.value isa Vector{Model.RetiredClaim} && append!(entries, s.value)
    end
    isempty(entries) && return Model.Location[]
    out = Model.Location[]
    for e in entries
        words = split(strip(e.phrase))
        isempty(words) && continue
        # Escaped word by word, joined by "any run of whitespace". Built from a literal, never from a
        # pattern the package wrote: a config that could name a regular expression would have it
        # compiled inside every build of that package.
        pattern = Regex(join((replace(w, r"([\\^$.|?*+()\[\]{}])" => s"\\\1") for w in words), "\\s+"), "i")
        for m in eachmatch(pattern, text)
            line = count(==('\n'), SubString(text, 1, prevind(text, m.offset))) + 1
            reason = isempty(e.decision) ? e.reason : e.reason * " (" * e.decision * ")"
            push!(out, Model.Location(; file = "", line = line,
                                       text = "a retired claim, said again: " * reason))
        end
    end
    return sort!(out; by = l -> l.line)
end

# The one package setting the examples above are judged under: without it every example of a rule whose
# phrases come from a package would comply, and the rule would carry no demonstration that it fires.
const RETIRED_EXAMPLE = [Model.Setting(rule = Symbol("RULE.DOC.RETIRED_CLAIMS"), name = :retired_claims,
                                       value = [Model.RetiredClaim(phrase = "the kernel is itself a scalar field",
                                                                   reason = "a field in spectral representation is not a kernel",
                                                                   decision = "decision 60")])]

const RETIRED = Model.Rule(
    id = Symbol("RULE.DOC.RETIRED_CLAIMS"),
    statement = "A phrase a package has retired does not reappear in its documentation.",
    why = "A claim retired once is retired because it was wrong, and the way a wrong claim comes back is that somebody copies the sentence that carried it. A DECISION LOG quotes what it retires, in order to record that it was retired, so this rule fires on a package's own history and is right to: keep the log in a file of its own and switch the rule off for that file, never for the design document the log was buried in, which is where the guard is worth most. The check is only as good as the list, and the list is kept by the party being checked: nothing in a repository knows that a claim was retired, so a claim dropped from the list is invisible here, and a ban whose reason was itself later overturned stays in force until someone notices.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, retired_claims, false),
    parameters = [RETIRED_CLAIMS],
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe kernel is itself a scalar field, so it scales.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)],
            "a retired phrase does not reappear", RETIRED_EXAMPLE),
        # The same claim, wrapped — which is how it appears in a hard-wrapped document, and what a
        # check matching within one line cannot see.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe kernel is itself a\nscalar field, so it scales.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)],
            "a retired phrase does not reappear", RETIRED_EXAMPLE),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe kernel is a weight, not a field.\n",
            Model.Location[], "a retired phrase does not reappear", RETIRED_EXAMPLE),
        # With nothing retired the rule is silent, which is the honest answer and not a gap.
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe kernel is itself a scalar field, so it scales.\n",
            Model.Location[], "a retired phrase does not reappear"),
    ],
)

const RULES = Model.Rule[AI_BANNER, SIGNATURE_MIRROR, BLOCK_LIST, NO_DEAD_REFS, INTERNAL_API, SIBLING_LINK, RETIRED]

end # module Pages