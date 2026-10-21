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
using ..Catalogue: FLEET, REGISTRY, site_of
using ..Docstrings: body_line
import Pkg

const JS = Texts.JS

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
# A Literate source becomes a page; a script beside it does not, however alike they look on disk. What
# separates them is the Markdown structure Literate renders — a `# #` heading — not the directory or the
# extension. GBGPeriodicFields keeps three runnable scripts beside its one rendered example, and this
# rule reported a missing banner on all three: a banner for a reader of a page nobody publishes.
# `[ \t]`, not `\s`: `\s` matches a newline, so `^#\s+#` matched any two consecutive comment lines and
# called every script a Literate page.
const LITERATE_HEADING = r"(?m)^#[ \t]+#"

function ai_banner(text::AbstractString, cfg)
    # A Markdown page is a page. A Julia file is one only if Literate renders it, and what Literate
    # renders is the Markdown structure in its comments — a `# #` heading. Fenced blocks are removed
    # before looking for code, or a page holding a `julia` example would read as a script itself. And
    # a script parses as Julia, which a page of prose never does: a page whose wrapping put `module`
    # or `const` at the start of a line was taken for a script and let through without its banner.
    unfenced = replace(text, r"(?ms)^```.*?^```" => "")
    is_script = occursin(r"(?m)^(using|import|function|const|module|struct|macro)\s", unfenced) && parses(text)
    is_script && !occursin(LITERATE_HEADING, text) && return Model.Location[]
    # Literate renders a full-line `# ` comment as prose, so the banner in a Literate source carries that
    # prefix on every line and must: without it the admonition would render as a code block. Comparing
    # the raw text called the correct thing drifted. The file is not the page.
    unprefixed = replace(text, r"(?m)^#[ \t]?" => "")
    (occursin(BANNER, text) || occursin(BANNER, unprefixed)) && return Model.Location[]
    # Whether this is a banner that has drifted or no banner at all, which is a different repair and so
    # a different message. It tested for `Written by AI`, the title's wording, and the body says
    # `written by AI` — so a page whose title had been reworded, the commonest drift there is, reported
    # as carrying no banner and sent a reader looking for something that was in front of them.
    mentions = occursin(r"written by AI"i, text) || occursin(r"written by AI"i, unprefixed)
    return [Model.Location(; file = "", line = 1,
                            text = mentions ? "the banner has drifted from the fleet's text — copy it verbatim" :
                                              "no provenance banner on a page that must carry one")]
end

# Whether the text is Julia the parser accepts whole.
parses(text::AbstractString) = try
    JS.parseall(JS.SyntaxNode, text; filename = "source.jl")
    true
catch
    false
end

"""
    BANNER_PAGES

The pages this package requires the provenance banner on, as globs. Unset — the default — the rule reads
its file sets, the rationale documents and the rendered Literate examples.

A package sets it where its list is its own: this one requires the banner on every page of its site,
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
        # Prose wrapped so that a line opens with a Julia keyword is prose still.
        Model.TextExample(Model.FileSet.RATIONALE, "# Design\n\nThe map is what a\nmodule docstring says about itself.\n",
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
a wide line there wraps in the rendered page and in every terminal that shows the docstring. It is
measured as rendered, without the four spaces that make it a code block, which no reader sees.
"""
function signature_width(src::AbstractString, cfg)
    out = Model.Location[]
    for d in Texts.docstrings_of(src)
        for (i, line) in pairs(split(d.text, '\n'))
            startswith(line, "    ") || break
            width = length(line) - 4
            width > SIGNATURE_WIDTH &&
                push!(out, Model.Location(; file = "", line = d.line + i, node = d.node,
                                           text = "$width columns: " * strip(String(line))))
        end
    end
    return out
end

const SIGNATURE_MIRROR = Model.Rule(
    id = Symbol("RULE.DOC.SIGNATURE_MIRROR"),
    statement = "A docstring's signature block fits the house column of 88 characters, as rendered, and repeats only as much of the method as a reader needs.",
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
        # 88 characters as rendered: the code block's four-space indent is not the reader's
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(" * "a"^85 * ")\n\nDoes a thing.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "of 88 characters, as rendered"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(" * "a"^86 * ")\n\nDoes a thing.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 2)], "of 88 characters, as rendered"),
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
            at = body_line(src, d) + count(==('\n'), d.text[1:prevind(d.text, m.offset)])
            push!(out, Model.Location(; file = "", line = at, node = d.node,
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

# The program half of the rule, and no wider. A section number and a gitignored directory are citations
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
    statement = "A docstring cites no section number and no inaccessible source; it reads complete at the REPL.",
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

The sibling packages a first mention links to, and where their sites are: the fleet as it stands. No
package sets it — a config holds no list of pairs, and the rule reads only this — so it is not among
the rule's parameters.

Derived from `Catalogue.FLEET`, which is the fleet's one home, rather than being a second list of the
same packages: two lists diverge, and this pair diverging is silent both ways.
"""
const SIBLING_SITES = Model.Parameter(:sibling_sites,
                                      [c.name => site_of(c.github) for c in FLEET])

"""
    sibling_link(text, cfg) -> Vector{Model.Location}

Every first mention of a sibling package that is not a link to that package's site, and every later
mention that links the site again where a bare name belongs. The arguments are `text`, the file's prose,
and `cfg`, the package's config, which names the package doing the mentioning; the sites are the
fleet's, from [`SIBLING_SITES`](@ref). Returns one location per mention.

A mention is the name as a reader sees it: a link's destination — a URL, an `@ref` or `@extref`
target — is read only to decide whether a visible mention links the site. Counted as mentions, the
targets of HT's `@extref`s took the first-mention slot, so a correct link after them was reported as a
re-link and a bare first mention after them was not reported at all (2026-09-28).
"""
function sibling_link(text::AbstractString, cfg)
    out = Model.Location[]
    lines = split(text, '\n')
    for (name, site) in SIBLING_SITES.default
        name == cfg.package && continue
        # `.jl` is part of the name wherever a package is named as a repository — which is how its own
        # link text and its URL both spell it. Reading the bare name only, the rule found the first
        # mention inside a link it did not recognise and reported the link as missing.
        name_re = Regex("(?<![A-Za-z0-9_])" * name * "(?:\\.jl)?(?![A-Za-z0-9_])")
        # The trailing slash of a site is optional in a link, and the table carries one. Matching it
        # literally, a correct link to `…/Package.jl` did not count, and the rule reported the first
        # mention — which was the link's own text — as unlinked.
        bare_site = rstrip(site, '/')
        link_re = Regex("\\[`?" * name * "(?:\\.jl)?`?\\]\\(\\Q" * bare_site * "\\E/?")
        home_re = Regex("\\[`?" * name * "(?:\\.jl)?`?\\]\\(\\Q" * bare_site * "\\E/?[\"')]")
        seen = false; fence = nothing
        for (n, raw) in pairs(lines)
            # A code listing is no mention either: `using GBGPeriodicFields` in one can carry no link, and
            # read once the `@extref` targets stopped taking the slot, it became the first (HT, gpu.md).
            f = Texts.fence_of(raw)
            if fence === nothing
                f === nothing || (fence = f; continue)
            else
                f !== nothing && f[1] == fence[1] && f[2] >= fence[2] && (fence = nothing)
                continue
            end
            o = findfirst(name_re, visible_text(raw)); o === nothing && continue
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

# The line with every link destination blanked to spaces, byte for byte, so an offset into it is an offset
# into the line: the `(…)` of `[text](dest)`, balanced, and the target of a `[label]: dest` definition.
function visible_text(line::AbstractString)
    b = Vector{UInt8}(codeunits(line))
    d = match(r"^\s*\[[^\]]+\]:\s*", line)
    d === nothing || (b[ncodeunits(d.match)+1:end] .= UInt8(' '))
    i = 1
    while (k = findnext(codeunits("]("), b, i)) !== nothing
        j = last(k) + 1; depth = 1
        while j <= length(b)
            b[j] == UInt8('(') && (depth += 1)
            b[j] == UInt8(')') && (depth -= 1; depth == 0 && break)
            j += 1
        end
        b[last(k)+1:min(j, length(b) + 1)-1] .= UInt8(' ')
        i = j
    end
    return String(b)
end

const SIBLING_LINK = Model.Rule(
    id = Symbol("RULE.DOC.SIBLING_LINK"),
    statement = "The first mention of a sibling package links to that package's site; later mentions are bare.",
    why = "A reader meeting the name for the first time must be able to reach it, and a fourth link teaches nothing.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.DOCSTRINGS],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, sibling_link, false),
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
        # a destination is not a mention: the bare name after an `@extref` target is the first one
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nSee [`f`](@extref GBGCloudPhysics GBGCloudPhysics.f).\nAs GBGCloudPhysics does it.\n",
            [Model.Location(; file = "docs/src/page.md", line = 4)], "the first mention links"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n```julia\nusing GBGCloudPhysics\n```\n\nAs [GBGCloudPhysics](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/) does it.\n",
            Model.Location[], "the first mention links"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nSee [the guide](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/dev/guide/).\n" *
            "As [GBGCloudPhysics](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/) does it.\n",
            Model.Location[], "later mentions are bare"),
    ])

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

The phrase is literal. It is escaped before it is used, so nothing a package writes in its config is
compiled as a pattern inside its own docs build.
"""
function retired_claims(text::AbstractString, cfg)
    entries = Model.RetiredClaim[]
    for s in cfg.settings
        # The rule's own setting alone: one declared under another rule's id is a mistake in the
        # config, and honouring it would let a typo redirect a rule.
        s.rule === RETIRED.id && s.name === :retired_claims && s.value isa Vector{Model.RetiredClaim} &&
            append!(entries, s.value)
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

"""
    MANUAL_SECTIONS

The Julia constructs a reader may not know, each with its official home in the Julia manual: what
`RULE.DOC.JULIA_MANUAL` asks a docstring or page using one to link. Each entry is the construct's name,
the pattern that finds a use of it, and the manual section. The keyword splat and the `do` block were
ruled on 2026-09-29; another construct is one more entry.
"""
const MANUAL_SECTIONS = [
    (name = "a keyword splat (`kwargs...`)",
     # inside one call's parentheses, after its `;`, across lines and one level of nested parentheses:
     # prose "; and so on...", a `vcat` splat `[a; rest...]` and `f(args...)` are none (found in review)
     uses = r"\((?:[^()]|\([^()]*\))*;(?:[^()]|\([^()]*\))*?(?<![\w.])(?<splat>[\p{L}_][\p{L}\p{N}_!]*\.\.\.)\s*\)",
     url = "https://docs.julialang.org/en/v1/manual/functions/#Keyword-Arguments"),
    (name = "a `do` block",
     # a call's closing parenthesis, `do`, and at most its arguments' names to the line's end: prose
     # ") do not store" is none, and `map(xs) do ξ` is one (found in review)
     # — or written inline in a signature, `run!(sim) do sim … end`
     uses = r"\)[ \t]+do(?:[ \t]+\(?[\p{L}_][\p{L}\p{N}_!]*(?:[ \t]*,[ \t]*[\p{L}_][\p{L}\p{N}_!]*)*\)?)?[ \t]*(?:$|[ \t]*(?:…|\.\.\.|;)[^\n]*\bend\b)"m,
     url = "https://docs.julialang.org/en/v1/manual/functions/#Do-Block-Syntax-for-Function-Arguments"),
]

"""
    julia_manual(root, cfg) -> Vector{Model.Location}

Every docstring and hand-written page that uses a construct of [`MANUAL_SECTIONS`](@ref) and does not
link its manual section. The arguments are `root`, the package root, and `cfg`, its config, which names
the files. Returns one location per construct per unit, at its first use.

A docstring is judged alone, since it is read alone at the REPL; a page is judged whole. A keyword
splat counts in a docstring's signature or in code anywhere in the unit, and a `do` block where a call's
closing parenthesis is followed by `do`, which is the only way to write one.
"""
function julia_manual(root::AbstractString, cfg)
    out = Model.Location[]
    function judge(file, text, first_line)
        for s in MANUAL_SECTIONS
            m = match(s.uses, text)
            m === nothing && continue
            occursin(s.url, text) && continue
            # at the splat itself where the pattern names it, since a signature may run over lines
            at = haskey(m, :splat) && m[:splat] !== nothing ? m.offsets[1] : m.offset
            line = first_line + count(==('\n'), SubString(text, 1, prevind(text, at)))
            push!(out, Model.Location(; file, line,
                text = "uses $(s.name) and does not link its Julia manual section: $(s.url)"))
        end
    end
    for f in Texts.files(cfg, root, Model.FileSet.CODE)
        for d in Texts.docstrings_of(read(joinpath(root, f), String))
            judge(f, d.text, d.text_line)
        end
    end
    for f in Texts.files(cfg, root, Model.FileSet.PAGES)
        judge(f, read(joinpath(root, f), String), 1)
    end
    return out
end

const JULIA_MANUAL = Model.Rule(
    id = Symbol("RULE.DOC.JULIA_MANUAL"),
    statement = "A docstring or page that uses a keyword splat (`kwargs...`) or a `do` block links the Julia manual's section on it.",
    why = "A reader who has not met the construct learns it where it is used, and the manual is its official home: a paraphrase of it drifts, and a link does not.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE, Model.FileSet.PAGES],
    check = Model.ProgramCheck(Model.Input.FILE_TREE, julia_manual, false),
    examples = [
        Model.TreeExample(["src/Example.jl" => "\"\"\"\n    f(a; kwargs...)\n\nCalls `g` with `a`.\n\n# Arguments\n\n- `a` — the input.\n- `kwargs...` — passed to `g`.\n\"\"\"\nf(a; kwargs...) = a\n"],
                          [Model.Location(; file = "src/Example.jl", line = 2)], "a keyword splat links the manual"),
        Model.TreeExample(["src/Example.jl" => "\"\"\"\n    f(a; kwargs...)\n\nCalls `g` with `a`.\n\n# Arguments\n\n- `a` — the input.\n- `kwargs...` — [keyword arguments](https://docs.julialang.org/en/v1/manual/functions/#Keyword-Arguments) passed to `g`.\n\"\"\"\nf(a; kwargs...) = a\n"],
                          Model.Location[], "a keyword splat links the manual"),
        Model.TreeExample(["docs/src/guide.md" => "# Guide\n\n```julia\nopen(path) do io\n    write(io, \"x\")\nend\n```\n"],
                          [Model.Location(; file = "docs/src/guide.md", line = 4)], "a `do` block links the manual"),
        Model.TreeExample(["docs/src/guide.md" => "# Guide\n\nWith a [`do` block](https://docs.julialang.org/en/v1/manual/functions/#Do-Block-Syntax-for-Function-Arguments):\n\n```julia\nopen(path) do io\n    write(io, \"x\")\nend\n```\n"],
                          Model.Location[], "a `do` block links the manual"),
        # a sentence ending in "do" is no `do` block
        Model.TreeExample(["docs/src/guide.md" => "# Guide\n\nRun it as the tests do\n"],
                          Model.Location[], "a `do` block links the manual"),
        # none of these is a keyword splat or a `do` block (found in review, 2026-09-29)
        Model.TreeExample(["docs/src/guide.md" => "# Guide\n\nIt stacks `[a; rest...]`; and so on...\nThe windows) do not store it.\nCall `f(args...)` and `x = 1; y = g(z...)`.\n"],
                          Model.Location[], "a keyword splat links the manual"),
        # a splat on a signature's continuation line, reported there; a do block over a non-ASCII argument
        Model.TreeExample(["src/Example.jl" => "\"\"\"\n    f(a;\n      tol = 1,\n      kwargs...)\n\nCalls `g`.\n\"\"\"\nf(a; kwargs...) = a\n"],
                          [Model.Location(; file = "src/Example.jl", line = 4)], "a keyword splat links the manual"),
        Model.TreeExample(["docs/src/guide.md" => "# Guide\n\n```julia\nmap(xs) do ξ\n    2ξ\nend\n```\n"],
                          [Model.Location(; file = "docs/src/guide.md", line = 4)], "a `do` block links the manual"),
        Model.TreeExample(["src/Example.jl" => "\"\"\"\n    run!(sim) do sim … end\n\nRuns a simulation.\n\"\"\"\nrun!(f, sim) = f(sim)\n"],
                          [Model.Location(; file = "src/Example.jl", line = 2)], "a `do` block links the manual"),
    ])

# ─────────────────────────────────────────────────────────────── a released package installs by name

# A fleet package's repository URL, in any spelling Pkg accepts; the registry's; the fleet's names; and
# `General`'s uuid, by which it may be added too.
const FLEET_URL = Regex("github\\.com[/:](?:" * join((replace(r.github, "." => "\\.") for r in FLEET), "|") * ")(?:\\.git)?/?\$", "i")
const REGISTRY_SLUG = Regex("github\\.com[/:]" * replace(match(r"github\.com/(.+?)(?:\.git)?$", REGISTRY).captures[1], "." => "\\.") * "(?:\\.git)?/?\$", "i")
const FLEET_NAMES = Set(r.name for r in FLEET)
const GENERAL_UUID = "23338594-aafe-5451-b93e-139f81909106"

# What one command does: adds registries (`general`, `fleet`), or installs packages (`url`, `named`,
# `branch` over the fleet's), placed by its line within the code it stands in.
struct InstallCommand
    line::Int
    registry::Bool
    general::Bool
    fleet::Bool
    url::Bool
    named::Bool
    branch::Bool
end

fleet_spec(name, url) = (name !== nothing && replace(String(name), r"\.jl$" => "") in FLEET_NAMES) ||
                        (url !== nothing && occursin(FLEET_URL, String(url)))

# A command at the `pkg>` prompt, read by Pkg's own parser, so `#rev`, `@version` and `Name.jl` mean what
# they mean to Pkg; `nothing` for any command but adding a package or a registry, or one Pkg cannot read.
function prompt_command(cmd::AbstractString, line::Int)
    statements = try Pkg.REPLMode.parse(String(cmd)) catch; return InstallCommand[] end
    out = InstallCommand[]
    for st in statements
        # Pkg says what it makes of a local directory of that name, which a page's reading must not depend on
        c = try Base.CoreLogging.with_logger(() -> Pkg.REPLMode.Command(st), Base.CoreLogging.NullLogger()) catch; continue end
        c.spec.canonical_name == "add" || continue
        if c.spec === Pkg.REPLMode.SPECS["registry"]["add"]
            regs = [a for a in c.arguments if a isa Pkg.Registry.RegistrySpec]
            general = isempty(regs) || any(r -> (r.name !== nothing && is_general(r.name)) || string(r.uuid) == GENERAL_UUID ||
                                                (r.url !== nothing && is_general(r.url)), regs)
            push!(out, InstallCommand(line, true, general, any(r -> r.url !== nothing && occursin(REGISTRY_SLUG, r.url), regs), false, false, false))
        else
            specs = [a for a in c.arguments if a isa Pkg.Types.PackageSpec && fleet_spec(a.name, a.url)]
            push!(out, InstallCommand(line, false, false, false, any(s -> s.url !== nothing, specs), !isempty(specs),
                                      any(s -> s.rev !== nothing, specs)))
        end
    end
    return out
end

# A call's dotted name, `Pkg.Registry.add`; "" for anything else.
callee(x) = x isa Symbol ? String(x) : x isa QuoteNode ? callee(x.value) :
            (x isa Expr && x.head === :. && length(x.args) == 2) ? callee(x.args[1]) * "." * callee(x.args[2]) : ""

# A call's keyword arguments and positional ones, however written: `f(a; k = v)` and `f(a, k = v)`.
function call_parts(ex::Expr)
    pos, kw = Any[], Dict{Symbol,Any}()
    for a in ex.args[2:end]
        if a isa Expr && a.head === :parameters
            for p in a.args; p isa Expr && p.head === :kw && p.args[1] isa Symbol && (kw[p.args[1]] = p.args[2]); end
        elseif a isa Expr && a.head === :kw
            a.args[1] isa Symbol && (kw[a.args[1]] = a.args[2])   # `url::String = …` names nothing
        else
            push!(pos, a)
        end
    end
    return pos, kw
end
literal(x) = x isa String ? x : nothing
revision(x) = x === :nothing ? nothing : x          # `rev = nothing` asks for no revision

# The packages a `Pkg.add` call names, as `(name, url, rev)`: a string, a vector of them, `PackageSpec(…)`
# calls, positional or with keywords, or the call's own keywords; only a string literal names anything.
function add_specs(ex::Expr)
    pos, kw = call_parts(ex)
    out = Tuple{Any,Any,Any}[]
    function one(x)
        if x isa String
            push!(out, occursin(FLEET_URL, x) ? (nothing, x, nothing) : (x, nothing, nothing))
        elseif x isa Expr && x.head === :call && callee(x.args[1]) in PACKAGE_SPEC
            p, k = call_parts(x)
            name = isempty(p) ? literal(get(k, :name, nothing)) : literal(p[1])
            push!(out, (name, literal(get(k, :url, nothing)), revision(get(k, :rev, nothing))))
        elseif x isa Expr && x.head in (:vect, :tuple)
            foreach(one, x.args)
        end
    end
    foreach(one, pos)
    isempty(kw) || push!(out, (literal(get(kw, :name, nothing)), literal(get(kw, :url, nothing)), revision(get(kw, :rev, nothing))))
    return out
end

# Whether a registry named or located so is `General`, or the fleet's.
const GENERAL_URL = r"github\.com[/:]JuliaRegistries/General(?:\.jl)?(?:\.git)?/?$"i
is_general(t) = t == "General" || t == GENERAL_UUID || occursin(GENERAL_URL, t)
const REGISTRY_SPEC = ("RegistrySpec", "Pkg.RegistrySpec", "Registry.RegistrySpec", "Pkg.Registry.RegistrySpec")
const PACKAGE_SPEC = ("PackageSpec", "Pkg.PackageSpec", "Pkg.Types.PackageSpec")

# The registries a `Pkg.Registry.add` call adds, as `(general, fleet)`: with no argument the default ones,
# `General` among them; otherwise each string, vector or `RegistrySpec(…)` it is handed.
function registry_adds(ex::Expr)
    pos, kw = call_parts(ex)
    isempty(pos) && isempty(kw) && return (true, false)
    texts = String[]
    function one(x)
        if x isa String
            push!(texts, x)
        elseif x isa Expr && x.head === :call && callee(x.args[1]) in REGISTRY_SPEC
            p, k = call_parts(x)
            append!(texts, [v for v in vcat(p, collect(values(k))) if v isa String])
        elseif x isa Expr && x.head in (:vect, :tuple)
            foreach(one, x.args)
        end
    end
    foreach(one, pos)
    append!(texts, [v for v in values(kw) if v isa String])
    return (any(is_general, texts), any(t -> occursin(REGISTRY_SLUG, t), texts))
end

# A block longer than this is not read: no install a page shows comes near it.
const MAX_CODE = 10_000
# Code longer than `SHALLOW` bytes is parsed on a stack of `PARSER_STACK` bytes. Every level of nesting
# costs at least a byte, and the default 8 MB stack held 421 levels of the shallowest form measured, `(`,
# under the bounds checks `Pkg.test` runs with, so code half that long cannot overflow it; the deep stack
# is about three times what the deepest `MAX_CODE` bytes were measured to need, 165 MB on 1.12
# (2026-10-21).
const SHALLOW = 200
const PARSER_STACK = 1 << 29

# One long-lived task holding the deep stack, so a page of many blocks reserves it once. A job comes
# with its own reply channel, so a caller interrupted while it waits cannot hand its answer to the next.
const DEEP = Ref{Any}(nothing)
const DEEP_LOCK = ReentrantLock()

function deep_worker()
    lock(DEEP_LOCK) do
        if DEEP[] === nothing || istaskdone(DEEP[][1])
            jobs = Channel{Any}(Inf)
            # each job at the latest world, so a method redefined since the worker started is the one run
            worker = Task(() -> for (g, reply) in jobs
                                    put!(reply, try (Base.invokelatest(g),) catch; nothing end)
                                end, PARSER_STACK)
            schedule(worker)
            DEEP[] = (worker, jobs)
        end
        return DEEP[]
    end
end

# `f()`, on the deep stack when `code` is longer than `SHALLOW` bytes, or `nothing` if it throws. A job
# already on the deep stack runs in place.
function parse_safely(f, code::AbstractString)
    (ncodeunits(code) <= SHALLOW || (DEEP[] !== nothing && current_task() === DEEP[][1])) &&
        return try f() catch; nothing end
    worker, jobs = deep_worker()
    reply = Channel{Any}(1)
    put!(jobs, (f, reply))
    r = take!(reply)
    return r === nothing ? nothing : r[1]
end

# Every install and registry command in a piece of code, in the order written. A line at the `pkg>`
# prompt (`]add …`, `julia> ]add …`, `pkg> add …`, `(@v1.12) pkg> add …`) is Pkg's to read, unless it
# stands inside a Julia comment or string; a shell line running `julia -e '…'` is the Julia it quotes;
# a fence line is nothing; the rest, `julia>` prompts taken off, is Julia, parsed by JuliaSyntax. A line
# that does not parse is skipped, and the code after it still read.
function commands(code::AbstractString)
    out = InstallCommand[]
    (occursin("add", code) && ncodeunits(code) <= MAX_CODE) || return out
    lines = split(code, '\n')
    starts = cumsum(vcat(1, [ncodeunits(l) + 1 for l in lines[1:end-1]]))
    quoted = something(parse_safely(() -> [t.range for t in JS.tokenize(code) if JS.kind(t) in (JS.K"Comment", JS.K"String", JS.K"CmdString")], code),
                       UnitRange{UInt32}[])
    julia = String[]
    for (n, l) in enumerate(lines)
        # `]` opens a prompt only before a command's name: the `])` closing a vector is Julia
        m = match(r"^\s*(?:(?:julia>\s*)?\](?=\s*[A-Za-z])|(?:\([^)\n]*\)\s*)?pkg>)\s*(.*)$", l)
        shell = match(r"\bjulia\b[^'\"\n]*?\s-e\s+(?:'([^']*)'|\"((?:[^\"\\]|\\.)*)\")", l)
        inside = any(r -> starts[n] in r, quoted)     # a line that opens in a comment or string is Julia's
        if m !== nothing && !inside
            append!(out, prompt_command(m.captures[1], n)); push!(julia, "")
        elseif shell !== nothing && !inside
            push!(julia, something(shell.captures[1], replace(something(shell.captures[2], ""), "\\\"" => "\"")))
        elseif occursin(r"^\s*(?:`{3,}|~{3,})", l)
            push!(julia, "")
        else
            push!(julia, replace(l, r"^\s*julia>\s?" => ""))
        end
    end
    source = join(julia, '\n')
    line = 1; base = 0
    function visit(x)
        x isa LineNumberNode && (line = base + x.line; return)
        x isa Expr || return
        if x.head === :macrocall && x.args[1] === Symbol("@pkg_str")
            for a in x.args; a isa LineNumberNode && (line = base + a.line); end
            cmd = findfirst(a -> a isa String, x.args)
            if cmd !== nothing
                # a `pkg"""` alone on its line starts its commands on the next one
                after = 1 <= line <= length(julia) && occursin(r"pkg\"\"\"\s*$", julia[line])
                for (k, c) in enumerate(split(x.args[cmd], '\n'))
                    append!(out, prompt_command(c, line + k - 1 + after))
                end
            end
            return
        end
        if x.head === :call
            f = callee(x.args[1])
            if f in ("Pkg.Registry.add", "Registry.add")
                g, r = registry_adds(x)
                push!(out, InstallCommand(line, true, g, r, false, false, false))
            elseif f == "Pkg.add"
                specs = [s for s in add_specs(x) if fleet_spec(s[1], s[2])]
                push!(out, InstallCommand(line, false, false, false, any(s -> s[2] !== nothing, specs), !isempty(specs),
                                          any(s -> s[3] !== nothing, specs)))
            end
        end
        foreach(visit, x.args)
    end
    # code JuliaSyntax refuses as a whole is read a line at a time, so a refused line, as a run of
    # thousands of unclosed brackets is, does not take the install beside it; a line longer than
    # `SHALLOW` bytes is not reread, since no install line is that long
    if parse_safely(() -> (visit(JS.parseall(Expr, source; ignore_errors = true)); true), source) !== true
        for (k, l) in enumerate(julia)
            (isempty(strip(l)) || ncodeunits(l) > SHALLOW) && continue
            base = k - 1
            parse_safely(() -> visit(JS.parseall(Expr, l; ignore_errors = true)), l)
        end
    end
    return sort!(out; by = c -> c.line)                # stable: one line's commands keep their order
end

# A file's text, readable whatever its encoding and line ends: a byte that is not UTF-8 becomes U+FFFD,
# and a CRLF or a lone CR a LF.
readable(text) = replace(isvalid(String, text) ? String(text) : String(map(c -> isvalid(c) ? c : '�', collect(text))),
                         "\r\n" => "\n", "\r" => "\n")

# A line without its block-quote marks, `> > text` read as `text`; counted byte by byte, since a mark
# is ASCII, so a run of them costs nothing.
function unquote(l::AbstractString)
    i = 1; n = ncodeunits(l)
    while true
        j = i; spaces = 0
        while j <= n && codeunit(l, j) == UInt8(' ') && spaces < 3; j += 1; spaces += 1; end
        (j <= n && codeunit(l, j) == UInt8('>')) || break
        j += 1; (j <= n && codeunit(l, j) == UInt8(' ')) && (j += 1)
        i = j
    end
    return SubString(l, i)
end

# The inline code of a paragraph, as `(first byte, byte after it, code)`, the way Markdown pairs backticks: a run opens a
# span closed by the next run of the same length, and a run never closed is literal text. One pass over
# the runs, so a page of stray backticks costs no more than a page of text.
function code_spans(t::AbstractString)
    runs = Tuple{Int,Int}[]                            # (first byte, length)
    i = 1; n = ncodeunits(t)
    while i <= n
        if codeunit(t, i) == UInt8('`')
            j = i; while j <= n && codeunit(t, j) == UInt8('`'); j += 1; end
            push!(runs, (i, j - i)); i = j
        else
            i += 1
        end
    end
    by_length = Dict{Int,Vector{Int}}()
    for (k, r) in enumerate(runs); push!(get!(by_length, r[2], Int[]), k); end
    out = Tuple{Int,Int,String}[]
    k = 1
    while k <= length(runs)
        start, len = runs[k]
        same = by_length[len]
        at = searchsortedfirst(same, k + 1)
        if at > length(same)
            k += 1; continue
        end
        close = same[at]
        stop = runs[close][1]
        body = SubString(t, start + len, prevind(t, stop))
        push!(out, (start, stop + len, String(strip(replace(body, '\n' => ' ')))))
        k = close + 1
    end
    return out
end

# A file cut into what a reader sees, in order, each with the line it starts on: `(:block, line, code)`
# for a code block, fenced or indented four columns past the content it stands in (the page, an
# admonition's body, a list item's text, a footnote's), a block quote's included; `(:inline, line, code)`
# for inline code; and `(:prose, line, text)` for a paragraph, a heading, a list item or an admonition's
# title, its marks taken off. An HTML comment is blanked first where `hide_comments`, keeping its lines:
# GitHub hides one, and Documenter shows it.
function install_units(text::AbstractString; hide_comments::Bool)
    hide_comments && (text = replace(text, r"<!--.*?-->"s => m -> replace(m, r"[^\n]" => "")))
    out = Tuple{Symbol,Int,String}[]
    para = String[]; para_line = 0
    function prose!(line, t)
        t = String(t)                                  # its own text, not a view of the whole file
        push!(out, (:prose, line, t))
        nl = findall(==('\n'), t)
        for (o, _, c) in code_spans(t)
            push!(out, (:inline, line + searchsortedfirst(nl, o) - 1, c))
        end
    end
    flush_para!() = (isempty(para) || prose!(para_line, join(para, '\n')); empty!(para))
    indented = String[]; indented_line = 0
    flush_indented!() = (isempty(indented) || push!(out, (:block, indented_line, join(indented, '\n'))); empty!(indented))
    fence = nothing; code = String[]; code_line = 0
    containers = [0]                                   # the content column of each container the line is in
    blank_before = true
    for (n, raw) in enumerate(split(text, '\n'))
        l = unquote(raw)
        m = match(r"^[ \t]*(`{3,}|~{3,})(.*)$", l)
        if fence !== nothing
            if m !== nothing && m.captures[1][1] == fence[1] && length(m.captures[1]) >= length(fence) && isempty(strip(m.captures[2]))
                push!(out, (:block, code_line, join(code, '\n'))); fence = nothing; blank_before = true
            else
                push!(code, l)
            end
            continue
        end
        if isempty(strip(l))
            flush_para!(); isempty(indented) || push!(indented, ""); blank_before = true
            continue
        end
        indent = sum(c -> c == '\t' ? 4 : 1, match(r"^[ \t]*", l).match; init = 0)
        opens_fence = m !== nothing && !(m.captures[1][1] == '`' && occursin('`', m.captures[2]))
        opener = match(r"^(\s*)!!!\s*\w*\s*(.*)$", l)
        footnote = match(r"^(\s*)\[\^[^\]]+\]:\s*(.*)$", l)
        heading = occursin(r"^\s{0,3}#{1,6}(?:\s|$)", l)
        item = match(r"^(\s*)((?:[-*+]|\d+[.)])(?:\s+|$))", l)
        starts_block = opens_fence || opener !== nothing || footnote !== nothing || heading || item !== nothing
        # a line leaves the containers it is dedented out of, unless it continues a paragraph lazily
        if isempty(para) || starts_block
            while length(containers) > 1 && containers[end] > indent; pop!(containers); end
        end
        if indent >= containers[end] + 4 && isempty(para) && (blank_before || !isempty(indented))
            isempty(indented) && (indented_line = n); push!(indented, l); blank_before = false
            continue
        end
        flush_indented!()
        blank_before = false
        if opens_fence
            flush_para!(); fence = m.captures[1]; empty!(code); code_line = n + 1
        elseif opener !== nothing
            flush_para!(); push!(containers, length(opener.captures[1]) + 4)
            prose!(n, strip(opener.captures[2], ['"', ' '])); blank_before = true
        elseif heading
            flush_para!(); prose!(n, l); blank_before = true
        elseif footnote !== nothing || item !== nothing
            flush_para!()
            if footnote !== nothing
                push!(containers, length(footnote.captures[1]) + 4); rest = footnote.captures[2]
            else
                push!(containers, length(item.captures[1]) + length(item.captures[2])); rest = SubString(l, ncodeunits(item.match) + 1)
            end
            para_line = n; push!(para, rest)
        else
            isempty(para) && (para_line = n); push!(para, l)
        end
    end
    flush_para!(); flush_indented!()
    fence === nothing || push!(out, (:block, code_line, join(code, '\n')))
    # a paragraph's inline code is placed after the paragraph it stands in
    return sort!(out; by = u -> (u[2], u[1] === :inline))
end

# A release is a level-two `CHANGELOG.md` heading opening on a version that is not a prerelease, the
# entry `gbg release` will not tag without: `## 0.1.0 — <date>` is one, `## 0.1.0-rc.1 — <date>` is
# not, and a line in a code block is no heading.
function released(root::AbstractString)
    log = joinpath(root, "CHANGELOG.md")
    isfile(log) || return false
    return any(u -> u[1] === :prose && occursin(r"^\s{0,3}##[ \t]+v?\d+\.\d+\.\d+(?=\s|$)", u[3]),
               install_units(readable(read(log, String)); hide_comments = true))
end

# The sentences of a paragraph, each with the line its word `unregistered` stands on, or its first line;
# a sentence ends at `.`, `!` or `?` before a space or the end. Inline code that is only a name reads as
# the name; other code, and a link's target, read as nothing; a heading's marks are dropped.
function sentences(text::AbstractString, first_line::Int)
    buf = IOBuffer(); last = 1
    for (o, after, c) in code_spans(text)
        print(buf, SubString(text, last, prevind(text, o)))
        # the span's line breaks are kept, so every line after it is still counted right
        print(buf, occursin(r"^[\w.]+$", c) ? c : " ", repeat('\n', count(==('\n'), SubString(text, o, prevind(text, after)))))
        last = after
    end
    last <= ncodeunits(text) && print(buf, SubString(text, last))
    t = replace(String(take!(buf)), r"\]\([^)\n]*\)" => "]", r"^\s{0,3}#{1,6}\s+" => "")
    nl = findall(==('\n'), t)
    out = Tuple{Int,String}[]
    start = 1
    for (i, c) in pairs(t)
        stop = c in ".!?" && (i == lastindex(t) || isspace(t[nextind(t, i)]))
        (stop || i == lastindex(t)) || continue
        sentence = SubString(t, start, i)
        w = findfirst(r"\bunregistered\b"i, sentence)
        at = w === nothing ? start : start + first(w) - 1
        push!(out, (first_line + searchsortedfirst(nl, at) - 1, String(sentence)))
        start = nextind(t, i)
    end
    return out
end

# What may stand between the package's `is` and `unregistered`: an article or an adjective, and not a
# word that turns the sentence onto something else ("It is the dependency that is unregistered").
const NOT_ABOUT_PACKAGE = Set(["that", "which", "who", "the", "how", "what", "where", "why", "to", "not", "no", "never"])

"""
    install(root, cfg) -> Vector{Model.Location}

`RULE.DOC.INSTALL` over a released package's `README.md` and hand-written pages. The arguments are
`root`, the package root, and `cfg`, its config, which names the package and its pages. Returns a
location for each install of a fleet package by its URL or at a branch; for each set of instructions
that installs one before adding `General` and the fleet's registry; and for each sentence that calls the
package unregistered.

A set of instructions is a code block, fenced or indented, in a list, an admonition, a footnote or a
quote, which a reader copies and runs alone; inline code is judged against everything above it in the
file, blocks included. Text that is not code is never a command, nor is an HTML comment in `README.md`,
which GitHub hides; on a page Documenter shows one, and it is read.

Code is read by the parsers that run it: a line at the `pkg>` prompt by Pkg's own, so `#rev`,
`@version` and `Name.jl` mean what they mean to Pkg; Julia, and the Julia a shell's `julia -e` quotes,
by JuliaSyntax, so a comment or a string holds no command. Only a string literal names a package, a URL
or a registry, so a URL held in a variable is not followed; `Pkg.develop` is not read, nor a block that
never says `add` or is longer than `MAX_CODE` bytes.

Code longer than `SHALLOW` bytes is parsed on a stack deep enough for
any nesting a block that size can hold, and shorter code cannot nest deep enough to overflow the
default 8 MB one, so no code overflows the parsers; code JuliaSyntax refuses as a whole is
read a line at a time, its lines of at most `SHALLOW` bytes.

A sentence calls the package unregistered when it says what the package is and then, within three
words none of which turns it elsewhere, `unregistered`: `This package is`, `The package is` or its name
and `is` (or `'s`) anywhere in it, and `This is` or `It is` where it opens, past an alert's marker or a `Note:`
label, emphasis marks aside. A package is released once its `CHANGELOG.md` has a level-two heading
opening on a version that is not a prerelease; before that, nothing is reported.
"""
function install(root::AbstractString, cfg)
    released(root) || return Model.Location[]
    files = Texts.files(cfg, root, Model.FileSet.PAGES)
    isfile(joinpath(root, "README.md")) && !Texts.excluded(cfg, "README.md") && pushfirst!(files, "README.md")
    out = Model.Location[]
    name = replace(cfg.package, "." => "\\.")
    # the package named, anywhere in a sentence; `This is` and `It is` only where the sentence opens, past
    # an alert's marker or a label, since anywhere else they may be about something else. Emphasis marks
    # are taken off the sentence first, so neither pattern backtracks over a run of them.
    between = "(?:\\s+is|['’]s)\\s+((?:[\\w-]+,?\\s+){0,3}?)unregistered\\b"
    named = Regex("(?<![\\w.])\\[?(?:this package|the package|$name(?:\\.jl)?)\\]?" * between, "i")
    opening = Regex("^\\s*(?:\\[![A-Za-z]+\\]\\s*)?(?:note:\\s*)?(?:this|it)" * between, "i")
    for file in unique(files)
        above = Set{Symbol}()                          # what the file has added so far, blocks included
        units = install_units(readable(read(joinpath(root, file), String)); hide_comments = file == "README.md")
        for (kind, first_line, text) in units
            if kind === :prose
                for (line, sentence) in sentences(text, first_line)
                    occursin(r"unregistered"i, sentence) || continue
                    plain = replace(sentence, r"[*_`]+" => "")
                    m = something(match(named, plain), match(opening, plain), Some(nothing))
                    (m !== nothing && !any(w -> lowercase(strip(w, [',', '*', '_'])) in NOT_ABOUT_PACKAGE, split(m.captures[1]))) || continue
                    push!(out, Model.Location(; file, line,
                        text = "calls the package unregistered, which a released package is not: it is in the fleet's registry, $REGISTRY"))
                end
                continue
            end
            have = kind === :block ? Set{Symbol}() : above
            reported = false
            for c in commands(text)
                line = first_line + c.line - 1
                if c.registry
                    c.general && (push!(have, :general); push!(above, :general))
                    c.fleet && (push!(have, :fleet); push!(above, :fleet))
                    continue
                end
                c.named || continue
                c.url && push!(out, Model.Location(; file, line,
                    text = "installs a fleet package by its URL, which is its newest commit; install it by name, which is its latest release"))
                c.branch && push!(out, Model.Location(; file, line,
                    text = "installs a fleet package at a branch or commit; install it by name, which is its latest release"))
                if !reported && !(:general in have && :fleet in have)
                    push!(out, Model.Location(; file, line,
                        text = "installs a fleet package before adding `General` and the fleet's registry: `Pkg.Registry.add(\"General\")`, then `Pkg.Registry.add(url = \"$REGISTRY\")`"))
                    reported = true                    # one finding per set of instructions
                end
            end
        end
    end
    return out
end

const INSTALL_STEPS = "```julia\nusing Pkg\nPkg.Registry.add(\"General\")\nPkg.Registry.add(url = \"https://github.com/GrigorySarnitsky/GBGRegistry\")\nPkg.add(\"GBGPeriodicFields\")\n```\n"
const RELEASE_LOG = "CHANGELOG.md" => "# Changelog\n\n## 0.1.0 — 2026-10-21\n\nMINOR.\n"
const PF_URL = "https://github.com/GrigorySarnitsky/GBGPeriodicFields.jl"
const GBG_REG = "https://github.com/GrigorySarnitsky/GBGRegistry"
install_readme(body) = [RELEASE_LOG, "README.md" => "# P\n\n" * body]
install_at(file, lines...) = [Model.Location(; file, line = l) for l in lines]

const INSTALL = Model.Rule(
    id = Symbol("RULE.DOC.INSTALL"),
    statement = "Once a package is released, its README and its pages install it as released: every set of instructions adds `General` and the fleet's registry before it installs, installs a fleet package by its name, never by its URL or at a branch, and no sentence calls the package unregistered.",
    why = "Installed by its URL, or at a branch, a package is a commit no release vouches for; installed by name through the fleet's registry it is its latest release, and moves only between releases (a package's request, the owner's ruling, 2026-10-21). `General` is added too because adding any registry to a fresh Julia stops Pkg from adding `General` itself, and every dependency outside the fleet is there. A package is released once its `CHANGELOG.md` has an entry for a final version; before that, its URL is the only way to install it.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES],
    check = Model.ProgramCheck(Model.Input.FILE_TREE, install, false),
    examples = [
        # unreleased, its URL is the only way; a prerelease's entry is no release
        Model.TreeExample(["README.md" => "# P\n\n```julia\n]add $PF_URL\n```\n"], Model.Location[], "Once a package is released"),
        Model.TreeExample(install_readme("```julia\n]add $PF_URL\n```\n"), install_at("README.md", 4, 4), "Once a package is released"),
        Model.TreeExample(["CHANGELOG.md" => "# Changelog\n\n## 0.1.0-rc.1 — 2026-10-21\n", "README.md" => "# P\n\n```julia\n]add $PF_URL\n```\n"],
                          Model.Location[], "Once a package is released"),
        # the registries, in any order, before the install; a comment that names `General` adds nothing
        Model.TreeExample(install_readme(INSTALL_STEPS), Model.Location[], "adds `General` and the fleet's registry before it installs"),
        Model.TreeExample(install_readme("```julia\nusing Pkg\nPkg.Registry.add(url = \"$GBG_REG\")   # General is added by Pkg\nPkg.add(\"GBGPeriodicFields\")\n```\n"),
                          install_at("README.md", 6), "adds `General` and the fleet's registry before it installs"),
        Model.TreeExample(install_readme("```julia\nusing Pkg\nPkg.Registry.add(\n    url = \"$GBG_REG.git\",\n)\nPkg.Registry.add(\"General\")\nPkg.add(\"GBGPeriodicFields\")\n```\n"),
                          Model.Location[], "adds `General` and the fleet's registry before it installs"),
        Model.TreeExample(install_readme("```julia\nusing Pkg\nPkg.add(\"GBGPeriodicFields\")\nPkg.Registry.add(\"General\")\nPkg.Registry.add(url = \"$GBG_REG\")\n```\n"),
                          install_at("README.md", 5), "adds `General` and the fleet's registry before it installs"),
        # each block is run alone, an admonition's indented one included; the prompt's and the macro's forms
        Model.TreeExample([RELEASE_LOG, "docs/src/index.md" => "# P\n\n```\n]registry add General $GBG_REG\n]add GBGPeriodicFields\n```\n\nOr:\n\n```julia\nusing Pkg; Pkg.add(\"GBGPeriodicFields\")\n```\n"],
                          install_at("docs/src/index.md", 11), "every set of instructions adds `General` and the fleet's registry before it installs"),
        Model.TreeExample([RELEASE_LOG, "docs/src/index.md" => "# P\n\n!!! note \"Once\"\n    ```julia\n    using Pkg; Pkg.Registry.add(\"General\"); Pkg.Registry.add(url = \"$GBG_REG\")\n    ```\n\n!!! tip \"Then\"\n    ```\n    pkg> add GBGPeriodicFields\n    ```\n"],
                          install_at("docs/src/index.md", 10), "every set of instructions adds `General` and the fleet's registry before it installs"),
        Model.TreeExample([RELEASE_LOG, "docs/src/index.md" => "# P\n\n```julia\nusing Pkg; Pkg.Registry.add(\"General\"); Pkg.Registry.add(url = \"$GBG_REG.git\"); Pkg.add([\"GBGPeriodicFields\", \"GBGHomogeneousTurbulence\"])\n```\n\nThen `pkg\"add GBGPeriodicFields\"` updates it.\n"],
                          Model.Location[], "every set of instructions adds `General` and the fleet's registry before it installs"),
        # an install in the prose reads what came above it; a block does not read the prose
        Model.TreeExample(install_readme("Install with `]add GBGPeriodicFields`.\n\n```\n]add GBGHomogeneousTurbulence\n```\n"),
                          install_at("README.md", 3, 6), "every set of instructions adds `General` and the fleet's registry before it installs"),
        # by URL, in a call across lines, in the macro, at a branch
        Model.TreeExample(install_readme(replace(INSTALL_STEPS, "Pkg.add(\"GBGPeriodicFields\")" => "Pkg.add(\n    url = \"$PF_URL\",\n)")),
                          install_at("README.md", 7), "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme(replace(INSTALL_STEPS, "Pkg.add(\"GBGPeriodicFields\")" => "pkg\"add $PF_URL\"")),
                          install_at("README.md", 7), "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme(replace(INSTALL_STEPS, "Pkg.add(\"GBGPeriodicFields\")" => "Pkg.add(PackageSpec(url = \"$PF_URL\"))")),
                          install_at("README.md", 7), "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme(replace(INSTALL_STEPS, "Pkg.add(\"GBGPeriodicFields\")" => "Pkg.add(name = \"GBGPeriodicFields\", rev = \"master\")")),
                          install_at("README.md", 7), "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("```\n]registry add General $GBG_REG\n]add GBGPeriodicFields#master\n```\n"),
                          install_at("README.md", 5), "installs a fleet package by its name, never by its URL or at a branch"),
        # another package by URL, a developer's checkout, a fleet name in a comment, a URL in a sentence
        Model.TreeExample(install_readme(replace(INSTALL_STEPS, "Pkg.add(\"GBGPeriodicFields\")" => "Pkg.add(\"GBGPeriodicFields\"); Pkg.add(url = \"https://github.com/example/Other.jl\")")),
                          Model.Location[], "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("The source is at $PF_URL.\n\n```julia\nusing Pkg\nPkg.develop(url = \"$PF_URL\")\nPkg.develop(PackageSpec(url = \"$PF_URL\"))\nPkg.add(\"Plots\")   # to plot GBGPeriodicFields output\n```\n"),
                          Model.Location[], "installs a fleet package by its name, never by its URL or at a branch"),
        # the package called unregistered, and sentences that are not that
        Model.TreeExample(install_readme("This is an unregistered package.\n\n" * INSTALL_STEPS), install_at("README.md", 3), "no sentence calls the package unregistered"),
        Model.TreeExample([RELEASE_LOG, "README.md" => "# Example\n\nExample is\nunregistered in `General`.\n\n" * INSTALL_STEPS], install_at("README.md", 4), "no sentence calls the package unregistered"),
        Model.TreeExample(install_readme("It is not in the `General` registry, but in the fleet's own. Its dependency `Foo` is unregistered.\nSee [the manual](https://pkgdocs.julialang.org/v1/managing-packages/#Adding-unregistered-packages).\n\n" * INSTALL_STEPS * "\n```julia\n# this adds an unregistered dependency\n```\n"),
                          Model.Location[], "no sentence calls the package unregistered"),
        Model.TreeExample([RELEASE_LOG, "README.md" => "# Example\n\nExample.jl is an unregistered package.\n\n" * INSTALL_STEPS], install_at("README.md", 3), "no sentence calls the package unregistered"),
        Model.TreeExample(install_readme("This package needs `Foo`, which is unregistered.\n\n<!-- ]add $PF_URL -->\n\n" * INSTALL_STEPS), Model.Location[], "no sentence calls the package unregistered"),
        # what the parsers make of it: a comment, a block comment and Markdown are no command
        Model.TreeExample(install_readme(replace(INSTALL_STEPS, "Pkg.add(\"GBGPeriodicFields\")" => "Pkg.add(\"GBGPeriodicFields\")   # never ]add $PF_URL\n#= Pkg.add(url = \"$PF_URL\") =#")),
                          Model.Location[], "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("- [x] add GBGPeriodicFields to the project\n\n" * INSTALL_STEPS), Model.Location[], "every set of instructions adds `General` and the fleet's registry before it installs"),
        Model.TreeExample(install_readme("See issue #3: run `Pkg.add(url = \"$PF_URL\")`.\n"), install_at("README.md", 3, 3), "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("Run `]registry add General $GBG_REG`, then `]add $PF_URL`.\n"), install_at("README.md", 3), "installs a fleet package by its name, never by its URL or at a branch"),
        # Pkg's own reading of the prompt: a revision after a space, `Name.jl`, and a version, which is a release
        Model.TreeExample(install_readme("```\n]registry add General $GBG_REG\n]add GBGPeriodicFields #master\n```\n"), install_at("README.md", 5), "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("```\n]registry add General $GBG_REG\n]add GBGPeriodicFields@0.1\n```\n"), Model.Location[], "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("```\n]add GBGPeriodicFields.jl\n```\n"), install_at("README.md", 4), "every set of instructions adds `General` and the fleet's registry before it installs"),
        # a vector across lines, `Registry.add()` adding the default registries, and a revision on another package
        Model.TreeExample(install_readme("```julia\nusing Pkg\nPkg.Registry.add(url = \"$GBG_REG\")\nPkg.add([\n    \"GBGPeriodicFields\",\n])\n```\n"), install_at("README.md", 6), "every set of instructions adds `General` and the fleet's registry before it installs"),
        Model.TreeExample(install_readme("```julia\nusing Pkg\nPkg.Registry.add()\nPkg.Registry.add(url = \"$GBG_REG\")\nPkg.add([PackageSpec(name = \"GBGPeriodicFields\"), PackageSpec(url = \"https://github.com/example/Other.jl\", rev = \"main\")])\n```\n"),
                          Model.Location[], "every set of instructions adds `General` and the fleet's registry before it installs"),
        # placed on its own line: the same inline code twice, blocks whose first line is empty, a sentence over two lines
        Model.TreeExample(install_readme("`]add GBGPeriodicFields`\n\n`]add GBGPeriodicFields`\n"), install_at("README.md", 3, 5), "every set of instructions adds `General` and the fleet's registry before it installs"),
        Model.TreeExample(install_readme("```\n\n]add $PF_URL\n```\n\n```\n\n]add $PF_URL\n```\n"), install_at("README.md", 5, 5, 10, 10), "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("Foo is unregistered somewhere\nbut. This is an unregistered package.\n"), install_at("README.md", 4), "no sentence calls the package unregistered"),
        # a `pkg>` line inside a Julia block comment or string is Julia's; an indented code block is no set of instructions
        Model.TreeExample(install_readme(replace(INSTALL_STEPS, "Pkg.add(\"GBGPeriodicFields\")" => "#=\n]add $PF_URL\n=#\ns = \"\"\"\npkg> add $PF_URL\n\"\"\"\nPkg.add(\"GBGPeriodicFields\")")),
                          Model.Location[], "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("Para.\n\n    ]add $PF_URL\n"), install_at("README.md", 5, 5), "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("!!! note \"Install\"\n    This is an unregistered package.\n\n        ]add GBGPeriodicFields\n\n- This is an unregistered package too.\n> It is unregistered.\n\n[^1]: This is an unregistered package.\n"),
                          install_at("README.md", 4, 6, 8, 9, 11), "no sentence calls the package unregistered"),
        # the package's name in backticks, `This package is`, and a heading
        Model.TreeExample([RELEASE_LOG, "README.md" => "# Example\n\n`Example.jl` is unregistered.\n\n" * INSTALL_STEPS], install_at("README.md", 3), "no sentence calls the package unregistered"),
        Model.TreeExample([RELEASE_LOG, "README.md" => "# Example is unregistered\n\nThis package is unregistered too.\n\n" * INSTALL_STEPS], install_at("README.md", 1, 3), "no sentence calls the package unregistered"),
        # `General` by its URL or in a vector; a `PackageSpec` named positionally; the lines of a `pkg\"\"\"…\"\"\"`
        Model.TreeExample(install_readme("```julia\nusing Pkg\nPkg.Registry.add([RegistrySpec(url = \"https://github.com/JuliaRegistries/General\"), RegistrySpec(url = \"$GBG_REG\")])\nPkg.add(\"GBGPeriodicFields\")\n```\n"),
                          Model.Location[], "adds `General` and the fleet's registry before it installs"),
        Model.TreeExample(install_readme("```julia\nusing Pkg\nPkg.add(PackageSpec(\"GBGPeriodicFields\"))\n```\n"), install_at("README.md", 5), "adds `General` and the fleet's registry before it installs"),
        Model.TreeExample(install_readme("```julia\nusing Pkg\npkg\"\"\"\nregistry add General $GBG_REG\nadd $PF_URL\n\"\"\"\n```\n"), install_at("README.md", 7), "installs a fleet package by its name, never by its URL or at a branch"),
        # a file that is not UTF-8 is read, not a crash
        Model.TreeExample(["CHANGELOG.md" => "## 0.1.0 caf\xe9\n", "README.md" => "## Caf\xe9\n\n" * INSTALL_STEPS], Model.Location[], "Once a package is released"),
        # the forms a README writes: `julia> ]add`, a shell's `julia -e`, a code block in a GitHub alert, code under a heading
        Model.TreeExample(install_readme("```julia-repl\njulia> ] add $PF_URL\n```\n"), install_at("README.md", 4, 4), "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("```sh\njulia -e 'using Pkg; Pkg.add(url = \"$PF_URL\")'\n```\n"), install_at("README.md", 4, 4), "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("> [!NOTE]\n> ```julia\n> ]add $PF_URL\n> ```\n"), install_at("README.md", 5, 5), "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("## Install\n    ]add GBGPeriodicFields\n"), install_at("README.md", 4), "every set of instructions adds `General` and the fleet's registry before it installs"),
        # a list item's own paragraphs are prose, and inline code may break across lines
        Model.TreeExample(install_readme("- Install\n    - once per machine\n\n    Then:\n\n    Run `]add\n    GBGPeriodicFields`.\n"), install_at("README.md", 8), "every set of instructions adds `General` and the fleet's registry before it installs"),
        # `RegistrySpec` reached through `Pkg.Registry`; a sentence about something else
        Model.TreeExample(install_readme("```julia\nusing Pkg\nPkg.Registry.add(Pkg.Registry.RegistrySpec(name = \"General\"))\nPkg.Registry.add(Pkg.Registry.RegistrySpec(url = \"$GBG_REG\"))\nPkg.add(\"GBGPeriodicFields\")\n```\n"),
                          Model.Location[], "adds `General` and the fleet's registry before it installs"),
        Model.TreeExample(install_readme("It is the dependency Foo that is unregistered, not this package. This is how to add an unregistered dependency.\n\n" * INSTALL_STEPS),
                          Model.Location[], "no sentence calls the package unregistered"),
        # a `pkg\"\"\"…\"\"\"` starting on its own line; an HTML comment, hidden in a README and shown on a page
        Model.TreeExample(install_readme("```julia\nusing Pkg\npkg\"\"\"registry add General $GBG_REG\nadd $PF_URL\"\"\"\n```\n"), install_at("README.md", 6), "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample([RELEASE_LOG, "README.md" => "# P\n\n<!-- Run `]add $PF_URL` -->\n", "docs/src/index.md" => "# P\n\n<!-- Run `]add $PF_URL` -->\n"],
                          install_at("docs/src/index.md", 3, 3), "installs a fleet package by its name, never by its URL or at a branch"),
        # a lead-in before the package, emphasis on the word; a keyword that names nothing; a shell's escaped quotes
        Model.TreeExample(install_readme("> [!NOTE]\n> This package is unregistered.\n\n**Note:** this is *still* unregistered.\n\nCurrently, the package is **unregistered**.\n\n" * INSTALL_STEPS),
                          install_at("README.md", 4, 6, 8), "no sentence calls the package unregistered"),
        Model.TreeExample(install_readme("Foo needs a fork, and it is unregistered.\n\n" * INSTALL_STEPS), Model.Location[], "no sentence calls the package unregistered"),
        Model.TreeExample(install_readme("```julia\nPkg.add(url::String = \"$PF_URL\")\n```\n"), Model.Location[], "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("```bat\njulia -e \"using Pkg; Pkg.add(url=\\\"$PF_URL\\\")\"\n```\n"), install_at("README.md", 4, 4), "installs a fleet package by its name, never by its URL or at a branch"),
        # `rev = nothing` asks for no revision; "It's"; a shell line in a comment; a deep unclosed nest keeps its prompt lines
        Model.TreeExample(install_readme(replace(INSTALL_STEPS, "Pkg.add(\"GBGPeriodicFields\")" => "Pkg.add(PackageSpec(name = \"GBGPeriodicFields\", rev = nothing))")),
                          Model.Location[], "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("It's unregistered for now.\n\n" * INSTALL_STEPS), install_at("README.md", 3), "no sentence calls the package unregistered"),
        Model.TreeExample(install_readme(replace(INSTALL_STEPS, "Pkg.add(\"GBGPeriodicFields\")" => "# from a shell: julia -e 'using Pkg; Pkg.add(url=\"$PF_URL\")'\nPkg.add(\"GBGPeriodicFields\")")),
                          Model.Location[], "installs a fleet package by its name, never by its URL or at a branch"),
        Model.TreeExample(install_readme("```julia\nx = " * "("^150 * "\n]add $PF_URL\n```\n"), install_at("README.md", 5, 5), "installs a fleet package by its name, never by its URL or at a branch"),
        # a block JuliaSyntax refuses as a whole, read a line at a time
        Model.TreeExample(install_readme("```julia\nPkg.add(url = \"$PF_URL\")\n" * "("^9000 * "\n```\n"), install_at("README.md", 4, 4), "installs a fleet package by its name, never by its URL or at a branch"),
        # a version heading in a CHANGELOG's code block is no release
        Model.TreeExample(["CHANGELOG.md" => "# Changelog\n\n```\n## 1.0.0 — 2026-10-21\n```\n", "README.md" => "# P\n\n```julia\n]add $PF_URL\n```\n"],
                          Model.Location[], "Once a package is released"),
    ])

# ─────────────────────────────────────────────────────────────── bold marks structure, never stress

# A line that is its own block: a heading, a table row, an admonition's opening line.
const OWN_BLOCK = r"^\s{0,3}(?:#{1,6}\s|\||!!!)"
# A line that opens a block after its leader: a list item.
const LEADER = r"^\s*(?:[-*+]|\d+[.)])\s+"
# The markers of a quotation, nested or not, which the page renders as the block they hold.
const QUOTE_MARK = r"^\s*(?:>[ \t]?)+"
# Bold, opened and closed by two asterisks against text; bold italic is three.
const BOLD_SPAN = r"(?s)(?<![\\*])\*\*(?=[^\s*])(.+?)(?<=[^\s\\])\*\*(?!\*)"
const BOLD_ITALIC = r"\*\*\*(?=\S)|(?<=\S)\*\*\*|\*\*_(?=\S)|_\*\*(?=\S)"

# The prose of a Literate source, as the page it renders to: a full-line `# ` comment, or one Literate
# keeps for the page alone (`#md # `), is Markdown with its prefix taken off, and every other line is
# blank. The line numbering is kept.
const LITERATE_PROSE = r"^(?:#md[ \t]+)?#(?:[ \t]|$)"
literate_prose(text) = join((occursin(LITERATE_PROSE, l) ? replace(l, r"^(?:#md[ \t]+)?#[ \t]?" => "") : "" for l in split(text, '\n')), '\n')

# Code spans, mathematics and escaped asterisks filled with a letter, one per code unit, so an asterisk in
# any of them is not markup, every offset stays where it was, and a bold span that opens or closes on a
# code span still opens and closes against text (blanked to spaces, `**`x`**` was no bold at all, and
# about 120 spans in three packages went unseen; found in review).
const MASKED = [r"``[^`\n]+?``", r"(?<!`)`[^`\n]+`(?!`)", r"\$[^$\n]+\$", r"\\\*"]
function emphasis_mask(line)
    out = String(line)
    for re in MASKED
        out = replace(out, re => m -> "x"^ncodeunits(m))
    end
    return out
end

"""
    emphasis(text, cfg) -> Vector{Model.Location}

Every bold span that does not open a block, and every bold italic. The arguments are `text`, the file's
prose, and `cfg`, the package's config, which this rule does not read. Returns one location per span.

A block is a paragraph, a list item, a quotation or a table cell; a heading and an admonition's title are
structure whole. Bold that opens one is a run-in head, which is what bold is for; bold anywhere after its
first word is stress or a definition, which are italic. A Literate source is read as the page it renders
to, and code spans, mathematics and fenced code are not prose.
"""
function emphasis(text::AbstractString, cfg)
    occursin(LITERATE_HEADING, text) && (text = literate_prose(text))
    lines = split(text, '\n')
    out = Model.Location[]
    # The open block: its text so far, with the line each character came from; and whether bold anywhere
    # in it is structure, as in a heading.
    # the block as masked, the same block as written, and the line each code unit came from
    buf = IOBuffer(); src = IOBuffer(); from = Int[]; whole = false
    function close_block()
        body = String(take!(buf)); written = String(take!(src))
        if !whole && !isempty(strip(body))
            lead = ncodeunits(body) - ncodeunits(lstrip(body))
            for m in eachmatch(BOLD_SPAN, body)
                m.offset - 1 == lead && continue              # a run-in head: the block opens with it
                line = from[clamp(m.offset, 1, length(from))]
                quoted = written[m.offset:prevind(written, m.offset + ncodeunits(m.match))]
                push!(out, Model.Location(; file = "", line = line, text = first(split(quoted, '\n'))))
            end
        end
        empty!(from); whole = false
    end
    function add(segment, original, line)
        for _ in 1:ncodeunits(segment); push!(from, line); end
        write(buf, segment); write(src, original)
    end
    fence = false; depth = 0
    unquote(l) = (q = match(QUOTE_MARK, l); q === nothing ? l : " "^ncodeunits(q.match) * l[ncodeunits(q.match) + 1:end])
    for (i, raw) in pairs(lines)
        line = String(raw)
        # A quotation is read as the block it renders as: its markers are blanked, each line of it then
        # read as any other — a fence, a table, a list — and a quotation that begins, or nests one level
        # deeper, opens a block; one falling back a level continues the paragraph, as CommonMark joins
        # it. Read line by line as blocks of their own, a span across two of its lines went unseen and one
        # opening a later line passed as a run-in head (found by GBGHomogeneousTurbulence, 2026-10-17).
        q = match(QUOTE_MARK, line)
        level = q === nothing ? 0 : count(==('>'), q.match)
        level > depth && close_block()
        depth = level
        line = unquote(line)
        if occursin(r"^\s*(```|~~~)", line)
            close_block(); fence = !fence; continue
        end
        fence && continue
        masked = emphasis_mask(line)
        for m in eachmatch(BOLD_ITALIC, masked)
            push!(out, Model.Location(; file = "", line = i, text = strip(line)))
            break
        end
        if isempty(strip(masked)) || occursin("\"\"\"", line)
            close_block(); continue
        end
        if occursin(OWN_BLOCK, masked)
            close_block()
            if occursin(r"^\s*\|", masked)
                # a table row: each cell is a block of its own, and the header row, over its separator,
                # is structure whole
                header = i < length(lines) && occursin(r"^\s*\|?\s*:?-{3,}", unquote(String(lines[i + 1])))
                at = 1
                for cell in split(masked, r"(?<!\\)\|")
                    n = ncodeunits(cell)
                    whole = header; add(cell, String(codeunits(line)[at:at + n - 1]), i); close_block()
                    at += n + 1
                end
            else
                whole = true; add(masked, line, i); close_block()     # a heading or an admonition's title
            end
            continue
        end
        if occursin(LEADER, masked)
            # a list item opens a block; its leader is blanked, so the block opens where its text does
            close_block()
            lead = ncodeunits(match(LEADER, masked).match)
            add(" "^lead * masked[lead + 1:end], " "^lead * line[lead + 1:end], i)
            continue
        end
        if position(buf) > 0
            write(buf, "\n"); write(src, "\n"); push!(from, i)
        end
        add(masked, line, i)
    end
    close_block()
    return sort!(out; by = l -> l.line)
end

const EMPHASIS = Model.Rule(
    id = Symbol("RULE.DOC.EMPHASIS"),
    statement = "Bold marks structure alone: a heading, an admonition's title, a table's header row, and a run-in head that opens a paragraph, a list item, a quotation or a table cell. Bold anywhere else in a sentence, and bold italic, is never used; what it marked is stress or a term at its definition, which are italic, or a sentence that should carry its weight by its order.",
    why = "One mark doing three jobs tells the reader none of them: in one package bold opened bullets, introduced defined terms and stressed `not`, hundreds of times inside a sentence. The authorities agree that emphasis and a defined term are italic and bold is for structure — Knuth slants the emphasised `not` and never bolds it (The TeXbook, ch. 4), LaTeX's `\\emph` sets italic, SIAM's style manual says \"Bold is not used for emphasis\", and the Chicago, Google, Microsoft and Apple guides and Wikipedia agree — and a reader finds a run-in head by where bold stands, which bold scattered through the sentences hides. A journal's volume in a reference is plain as well: some citation styles bold it, and no rule here asks for it (the owner, 2026-10-17). Where a bold span stands decides the question, so a program does; whether its italic is earned is `RULE.DOC.EMPHASIS_RARE`'s (the owner, 2026-10-16, on GBGHomogeneousTurbulence's request).",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.LITERATE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, emphasis, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe solver does **not** form the product.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "Bold anywhere else in a sentence"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe solver does *not* form the product.\n\n**Kept.** The old form stays.\n\n- **Positions.** Where each sits.\n\n| **Grid** | **Points** |\n|---|---|\n| **cubic** | 64 |\n\n## A **bold** heading\n",
            Model.Location[], "Bold anywhere else in a sentence"),
        # a run-in head written in the middle of a paragraph opens nothing
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe rate holds. **The state.** A run settles.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "Bold anywhere else in a sentence"),
        # a span wrapped onto the next line is found on the line it opens
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe solver is\nexact for **every\nmode** of the grid.\n",
            [Model.Location(; file = "docs/src/page.md", line = 4)], "Bold anywhere else in a sentence"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n***Never*** do this.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "bold italic"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n*Never* do this.\n",
            Model.Location[], "bold italic"),
        # code spans, mathematics and fences are not prose
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nThe power `a**b` and ``x^{**}`` are code.\n\n```julia\ny = x ** 2  # **not** prose\n```\n",
            Model.Location[], "Bold anywhere else in a sentence"),
        Model.TextExample(Model.FileSet.DOCSTRINGS,
            "\"\"\"\n    f(x)\n\nReturns **both** halves.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 4)], "Bold anywhere else in a sentence"),
        Model.TextExample(Model.FileSet.DOCSTRINGS,
            "\"\"\"\n    f(x)\n\nReturns the halves.\n\n!!! note \"Cost\"\n    **One pass.** It reads the input once.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "Bold anywhere else in a sentence"),
        # a Literate source is read as the page it renders to
        Model.TextExample(Model.FileSet.LITERATE,
            "# # The example\n#\n# **Setup.** The grid is **cubic**.\n\nx = 2^3\n",
            [Model.Location(; file = "examples/example.jl", line = 3)], "Bold anywhere else in a sentence"),
        # a line Literate keeps for the page alone is on the page
        Model.TextExample(Model.FileSet.LITERATE,
            "# # The example\n\nx = 1\n#md # The heart is **no allocation** here.\n",
            [Model.Location(; file = "examples/example.jl", line = 4)], "Bold anywhere else in a sentence"),
        # bold that opens or closes on a code span is bold all the same
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\nIt lives in **`Fields`**, a sibling, and the **`f` alias** too.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3), Model.Location(; file = "docs/src/page.md", line = 3)],
            "Bold anywhere else in a sentence"),
        # after the first words of a list item, a quotation or a table cell, bold is inside a sentence
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n- The item is **bold** late.\n\n> The quotation is **bold** late.\n\n| Grid | Speed-up |\n|---|---|\n| cubic | about **5.1×** |\n",
            [Model.Location(; file = "docs/src/page.md", line = 3), Model.Location(; file = "docs/src/page.md", line = 5),
             Model.Location(; file = "docs/src/page.md", line = 9)], "Bold anywhere else in a sentence"),
        # a quotation is the block it renders as: a span across its lines, and one opening a later line
        Model.TextExample(Model.FileSet.PAGES,
            "# Probe\n\n> A quote with a **span\n> across lines** in it, and **one** on a line.\n> **lead** at a continuation line start.\n\nA paragraph with a **span\nacross lines** in it.\n\n> **Head.** A quote that opens with a head.\n\n> - **Item.** A list in a quotation.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3), Model.Location(; file = "docs/src/page.md", line = 4),
             Model.Location(; file = "docs/src/page.md", line = 5), Model.Location(; file = "docs/src/page.md", line = 7)],
            "Bold anywhere else in a sentence"),
        # a deeper quotation opens a block; a quoted table's header and a quoted fence are what they are
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n> Outer text here\n> > **Inner.** text\n\n> | The **x** column | y |\n> |---|---|\n> | 1 | 2 |\n\n> ```\n> a **b** c\n> ```\n",
            Model.Location[], "Bold anywhere else in a sentence"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n> **Note.** A quotation's run-in head.\n\n| The **x** column | y |\n|---|---|\n| 1 | 2 |\n",
            Model.Location[], "a table's header row"),
        Model.TextExample(Model.FileSet.PAGES,
            "# A page\n\n| x | y |\n|---|---|\n| the **one** | 2 |\n",
            [Model.Location(; file = "docs/src/page.md", line = 5)], "a table's header row"),
    ])

"""
    RULES

The rules of this batch, in the order they were converted.
"""
const RULES = Model.Rule[AI_BANNER, SIGNATURE_MIRROR, BLOCK_LIST, NO_DEAD_REFS, INTERNAL_API, SIBLING_LINK, RETIRED, JULIA_MANUAL, EMPHASIS, INSTALL]

end # module Pages