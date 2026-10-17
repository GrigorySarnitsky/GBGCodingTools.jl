# The design's §3 and §6; the coordinates live here rather than in a docstring, which must read complete
# at the REPL.
"""
    Rules.Site

The rules that read the built site rather than its source: what a reader actually meets on the page. A
formula that did not render, markup showing as literal asterisks, and one docstring collected onto two
pages are all invisible in the source and obvious on the page.

A check here takes the built site's directory, which only a docs build can hand it. Where no site has
been built the rule is not run and the caller is told so, rather than the run reporting clean.
"""
module Site

using ...Model
using ...Texts

"""
    pages_of(build, cfg) -> Vector{String}

Every rendered page under the built site that a rule may read. The arguments are `build`, the site's
directory, and `cfg`, the package's config. Returns the paths, sorted.

A page built from a file the config excludes is left out before any rule reads it: filtering the
findings afterwards made a rule comparing pages depend on which page sorted first, so a docstring shown
on an excluded page and a kept one was reported or not by the pages' names (found in review, 2026-09-29).
"""
pages_of(build::AbstractString, cfg) =
    sort!([joinpath(r, f) for (r, _, fs) in walkdir(build) for f in fs
           if endswith(f, ".html") && !Texts.excluded(cfg, "docs/build/" * replace(relpath(joinpath(r, f), build), '\\' => '/'))])

const STRAY_MARKUP = r"`|\]\(@ref|\]\(http|!!!"

"""
    rendered_math(build, cfg) -> Vector{Model.Location}

Every math span on the built site whose source still holds markup — a backtick, a link, an admonition
marker — which means the formula did not render as mathematics at all. The arguments are `build`, the
site's directory, and `cfg`, the package's config, which this rule does not read. Returns one location
per span.

The source half of this rule catches the same defect before the build; this half catches what only the
rendered page can show.
"""
function rendered_math(build::AbstractString, cfg)
    out = Model.Location[]
    for page in pages_of(build, cfg)
        doc = Texts.parse_page(page)
        art = Texts.article_of(doc)
        art === nothing && continue
        # The innermost block holding the span: a `div` whose only text is its `p`'s formula has the same
        # text, and reporting both counted one defect once per enclosing block.
        is_span(el) = (t = strip(Texts.text_of(el));
                       ((length(t) > 1 && startswith(t, "\$") && endswith(t, "\$")) ||
                        (startswith(t, "\\[") && endswith(t, "\\]"))) && occursin(STRAY_MARKUP, t))
        block(e) = Texts.tagname(e) in (:span, :div, :p)
        for el in Texts.elements(art, e -> block(e) && is_span(e))
            any(d -> d !== el && block(d) && is_span(d), Texts.elements(el, _ -> true)) && continue
            push!(out, Model.Location(; file = page, line = 0, text = first(String(strip(Texts.text_of(el))), 120)))
        end
    end
    return out
end

const RENDERED_MATH_SITE = Model.Rule(
    id = Symbol("RULE.TEX.RENDERED_MATH_SITE"),
    statement = "On the built page, every math span has rendered: none still shows its own markup.",
    why = "A span that renders as its own source is a formula the reader never sees, and the source looks right.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES],
    check = Model.ProgramCheck(Model.Input.BUILT_SITE, rendered_math, false),
    examples = [
        Model.SiteExample(["p.html" => "<html><body><article class=\"content\"><p>\$x = `y`\$</p></article></body></html>"],
            [Model.Location(; file = "p.html", line = 0)], "every math span has rendered"),
        # One unrendered formula nested in two blocks is one finding.
        Model.SiteExample(["p.html" => "<html><body><article class=\"content\"><div><p>\\[x = `y`\\]</p></div></article></body></html>"],
            [Model.Location(; file = "p.html", line = 0)], "every math span has rendered"),
        Model.SiteExample(["p.html" => "<html><body><article class=\"content\"><p><span class=\"math\">x = y</span></p></article></body></html>"],
            Model.Location[], "every math span has rendered"),
    ])

"""
    article_prose(page) -> String

The rendered prose of a page with its code, its mathematics and its scripts removed: what a reader reads.
The argument is `page`, the built page. Returns the text, one line per block element.
"""
function article_prose(page::AbstractString)
    doc = Texts.parse_page(page)
    art = Texts.article_of(doc)
    art === nothing && return ""
    io = IOBuffer()
    function walk(n)
        if n isa Texts.HTMLText
            write(io, n.text)
        elseif n isa Texts.HTMLElement
            t = Texts.tagname(n)
            t in (:code, :pre, :script, :style) && return
            any(c -> startswith(c, "math") || c == "katex", Texts.classes(n)) && return
            for c in n.children; walk(c); end
            t in (:p, :li, :div, :h1, :h2, :h3, :h4, :h5, :h6, :br, :tr) && write(io, '\n')
        end
    end
    for c in art.children; walk(c); end
    return String(take!(io))
end

const UNRENDERED = r"\*\*[^\s*][^*\n]*?\*\*|(?<![\w*])\*[^\s*][^*\n]*?(?<!\s)\*(?![\w*])|(?<![\w\\])__[^\s_][^_\n]*?__"

"""
    rendered_markup(build, cfg) -> Vector{Model.Location}

Every place markup shows on the page as literal characters — asterisks or underscores that were meant to
set emphasis and did not. The arguments are `build`, the site's directory, and `cfg`, the package's
config, which this rule does not read. Returns one location per place.
"""
function rendered_markup(build::AbstractString, cfg)
    out = Model.Location[]
    for page in pages_of(build, cfg)
        text = replace(article_prose(page), r"\\\[.*?\\\]"s => " ", r"\\\(.*?\\\)"s => " ", r"\$[^\$\n]*\$" => " ")
        for line in split(text, '\n')
            # A paired span, which is what emphasis that failed to render leaves: a lone asterisk — a
            # glob, a product — is not markup, and Markdown left it because it was not. One per line.
            m = match(UNRENDERED, line)
            m === nothing && continue
            lo = max(1, m.offset - 70); hi = min(lastindex(line), m.offset + 80)
            excerpt = join(split(SubString(line, thisind(line, lo), thisind(line, hi))), " ")
            push!(out, Model.Location(; file = page, line = 0, text = "…" * excerpt * "…"))
        end
    end
    return out
end

const RENDERED_MARKUP = Model.Rule(
    id = Symbol("RULE.TEX.RENDERED_MARKUP"),
    statement = "No markup shows on the built page as literal characters.",
    why = "Asterisks meant to set emphasis, shown as asterisks, are the mark of prose nobody read after building.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES],
    check = Model.ProgramCheck(Model.Input.BUILT_SITE, rendered_markup, false),
    examples = [
        Model.SiteExample(["p.html" => "<html><body><article class=\"content\"><p>a **bold** word</p></article></body></html>"],
            [Model.Location(; file = "p.html", line = 0)], "no markup shows as literal characters"),
        Model.SiteExample(["p.html" => "<html><body><article class=\"content\"><p>a <strong>bold</strong> word</p></article></body></html>"],
            Model.Location[], "no markup shows as literal characters"),
        # A glob and a product are not markup; two unrendered spans on one line are one finding.
        Model.SiteExample(["p.html" => "<html><body><article class=\"content\"><p>every *.md file under docs, and 2*3 is six</p></article></body></html>"],
            Model.Location[], "no markup shows as literal characters"),
        Model.SiteExample(["p.html" => "<html><body><article class=\"content\"><p>a *slanted* and a __strong__ word</p></article></body></html>"],
            [Model.Location(; file = "p.html", line = 0)], "no markup shows as literal characters"),
    ])

"""
    page_bindings(page) -> Vector{NamedTuple}

Every rendered docstring on a page as `(id, name, section)`: its anchor, the name displayed, and the
section it sits under. The argument is `page`, the built page. Returns them in page order.

Documenter 1.x renders a docstring as `<details class="docstring">` whose binding is the
`a.docstring-binding` in its summary; older versions used `<article class="docstring">`. Both are read,
and the binding's own link is taken, not the first link inside — which may be one in the docstring's
prose. Reading `<article>` alone found no docstring at all on a real site.
"""
function page_bindings(page::AbstractString)
    doc = Texts.parse_page(page)
    art = Texts.article_of(doc)
    out = NamedTuple[]
    art === nothing && return out
    section = Ref("")
    function walk(n)
        n isa Texts.HTMLElement || return
        t = Texts.tagname(n)
        t === :h2 && (section[] = strip(Texts.text_of(n)))
        if t in (:details, :article) && "docstring" in Texts.classes(n)
            bound = Texts.elements(n, e -> Texts.tagname(e) === :a && "docstring-binding" in Texts.classes(e))
            anchors = isempty(bound) ? Texts.elements(n, e -> Texts.tagname(e) === :a) : bound
            if !isempty(anchors)
                header = first(anchors)
                href = Texts.attr(header, "href", "")
                id = isempty(href) ? Texts.attr(header, "id", "") : replace(href, "#" => "")
                push!(out, (id = id, name = strip(Texts.text_of(header)), section = section[]))
            end
        end
        for c in n.children; walk(c); end
    end
    walk(art)
    return out
end

"""
    api_grouping(build, cfg) -> Vector{Model.Location}

Every docstring collected onto more than one page of the built site, and every extension of a Base
function rendered under the internal section. The arguments are `build`, the site's directory, and `cfg`,
the package's config, which this rule does not read. Returns one location per finding.

One docstring on two pages is two homes for one thing, and a reader who finds the second learns nothing
he did not already have; a Base function a package extends is part of its public surface whatever the
page it was filed under.
"""
function api_grouping(build::AbstractString, cfg)
    out = Model.Location[]
    where_ = Dict{String,Vector{String}}()
    for page in pages_of(build, cfg)
        for b in page_bindings(page)
            push!(get!(where_, b.id, String[]), page)
            occursin("Internal API", b.section) && startswith(b.name, "Base.") &&
                push!(out, Model.Location(; file = page, line = 0,
                    text = "`$(b.name)` is rendered under the internal section, though a Base function the package extends is public"))
        end
    end
    for (id, ps) in sort!(collect(where_))
        length(unique(ps)) > 1 &&
            push!(out, Model.Location(; file = first(ps), line = 0,
                text = "the docstring `$id` is rendered on $(length(unique(ps))) pages"))
    end
    return out
end

# A built page and one docstring on it, in the shape Documenter 1.x writes them (`docs/build/api/*.html`
# of this package is the pattern): the examples are only as good as their likeness to a real site.
page_of(body) = "<html><body><div class=\"docs-main\"><article class=\"content\">" * body * "</article></div></body></html>"
docstring_html(binding, prose = "") =
    "<article><details class=\"docstring\" open=\"true\"><summary id=\"$binding\"><a class=\"docstring-binding\" href=\"#$binding\"><code>$binding</code></a> — <span class=\"docstring-category\">Function</span></summary><section><div><pre><code class=\"language-julia hljs\">$binding(x)</code></pre><p>" *
    replace(prose, r"\[(\w+)\]\((#\w+)\)" => s"<a href=\"\2\"><code>\1</code></a>") *
    "</p></div></section></details></article>"

const API_GROUPING = Model.Rule(
    id = Symbol("RULE.DOC.API_GROUPING"),
    statement = "One docstring has one home on the built site, and a Base function the package extends is public.",
    why = "Two homes for one docstring is two things to keep true, and the second teaches a reader nothing.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES],
    check = Model.ProgramCheck(Model.Input.BUILT_SITE, api_grouping, false),
    examples = [
        # In the markup Documenter 1.x emits: a `details` per docstring, its binding the summary's
        # `a.docstring-binding`, and a link in the docstring's prose that is not the binding.
        Model.SiteExample(["a.html" => page_of(docstring_html("f", "See [g](#g).")),
                           "b.html" => page_of(docstring_html("f"))],
            [Model.Location(; file = "a.html", line = 0)], "one docstring has one home"),
        Model.SiteExample(["a.html" => page_of(docstring_html("f", "See [g](#g).")),
                           "b.html" => page_of(docstring_html("g"))],
            Model.Location[], "one docstring has one home"),
        Model.SiteExample(["a.html" => page_of("<h2 id=\"Internal-API\">Internal API</h2>" * docstring_html("Base.show"))],
            [Model.Location(; file = "a.html", line = 0)], "a Base function the package extends is public"),
        Model.SiteExample(["a.html" => page_of("<h2 id=\"Public\">Public</h2>" * docstring_html("Base.show"))],
            Model.Location[], "a Base function the package extends is public"),
    ])

"""
    RULES

The rules of this batch. Their examples are built pages written out as HTML, in the markup Documenter
emits, rather than a Documenter build: running one would test Documenter, not the rule.
"""
const RULES = Model.Rule[RENDERED_MATH_SITE, RENDERED_MARKUP, API_GROUPING]

end # module Site
