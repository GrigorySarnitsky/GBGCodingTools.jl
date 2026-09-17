# The design's §3 and §6; the coordinates live here rather than in a docstring, which must read complete
# at the REPL.
"""
    Rules.Site

The rules that read the BUILT SITE rather than its source: what a reader actually meets on the page. A
formula that did not render, markup showing as literal asterisks, and one docstring collected onto two
pages are all invisible in the source and obvious on the page.

A check here takes the built site's directory, which only a docs build can hand it. Where no site has
been built the rule is not run and the caller is told so, rather than the run reporting clean.
"""
module Site

using ...Model
using ...Texts

"""
    pages_of(build) -> Vector{String}

Every rendered page under the built site. The argument is `build`, the site's directory. Returns the
paths, sorted.
"""
pages_of(build::AbstractString) = sort!([joinpath(r, f) for (r, _, fs) in walkdir(build)
                                         for f in fs if endswith(f, ".html")])

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
    for page in pages_of(build)
        doc = Texts.parse_page(page)
        art = Texts.article_of(doc)
        art === nothing && continue
        for el in Texts.elements(art, e -> Texts.tagname(e) in (:span, :div, :p))
            t = strip(Texts.text_of(el))
            inline = length(t) > 1 && startswith(t, "\$") && endswith(t, "\$")
            display = startswith(t, "\\[") && endswith(t, "\\]")
            (inline || display) || continue
            occursin(STRAY_MARKUP, t) &&
                push!(out, Model.Location(; file = page, line = 0, text = first(String(t), 120)))
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

"""
    rendered_markup(build, cfg) -> Vector{Model.Location}

Every place markup shows on the page as literal characters — asterisks or underscores that were meant to
set emphasis and did not. The arguments are `build`, the site's directory, and `cfg`, the package's
config, which this rule does not read. Returns one location per place.
"""
function rendered_markup(build::AbstractString, cfg)
    out = Model.Location[]
    for page in pages_of(build)
        text = replace(article_prose(page), r"\\\[.*?\\\]"s => " ", r"\\\(.*?\\\)"s => " ", r"\$[^\$\n]*\$" => " ")
        for line in split(text, '\n')
            for m in eachmatch(r"\*\*?[^\s*]|(?<![\w\\])__[^\s_]", line)
                lo = max(1, m.offset - 70); hi = min(lastindex(line), m.offset + 80)
                excerpt = join(split(SubString(line, thisind(line, lo), thisind(line, hi))), " ")
                push!(out, Model.Location(; file = page, line = 0, text = "…" * excerpt * "…"))
            end
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
    ])

"""
    page_bindings(page) -> Vector{NamedTuple}

Every rendered docstring on a page as `(id, name, section)`: its anchor, the name displayed, and the
section it sits under. The argument is `page`, the built page. Returns them in page order.
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
        if t === :article && "docstring" in Texts.classes(n)
            anchors = Texts.elements(n, e -> Texts.tagname(e) === :a)
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
    for page in pages_of(build)
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

const API_GROUPING = Model.Rule(
    id = Symbol("RULE.DOC.API_GROUPING"),
    statement = "One docstring has one home on the built site, and a Base function the package extends is public.",
    why = "Two homes for one docstring is two things to keep true, and the second teaches a reader nothing.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES],
    check = Model.ProgramCheck(Model.Input.BUILT_SITE, api_grouping, false),
    examples = [
        Model.SiteExample(
            ["a.html" => "<html><body><article class=\"content\"><article class=\"docstring\"><a href=\"#f\">f</a></article></article></body></html>",
             "b.html" => "<html><body><article class=\"content\"><article class=\"docstring\"><a href=\"#f\">f</a></article></article></body></html>"],
            [Model.Location(; file = "a.html", line = 0)], "one docstring has one home"),
        Model.SiteExample(
            ["a.html" => "<html><body><article class=\"content\"><article class=\"docstring\"><a href=\"#f\">f</a></article></article></body></html>",
             "b.html" => "<html><body><article class=\"content\"><article class=\"docstring\"><a href=\"#g\">g</a></article></article></body></html>"],
            Model.Location[], "one docstring has one home"),
        Model.SiteExample(
            ["a.html" => "<html><body><article class=\"content\"><h2>Internal API</h2><article class=\"docstring\"><a href=\"#x\">Base.show</a></article></article></body></html>"],
            [Model.Location(; file = "a.html", line = 0)], "a Base function the package extends is public"),
        Model.SiteExample(
            ["a.html" => "<html><body><article class=\"content\"><h2>Public</h2><article class=\"docstring\"><a href=\"#x\">Base.show</a></article></article></body></html>"],
            Model.Location[], "a Base function the package extends is public"),
    ])

"""
    RULES

The rules of this batch. None carries examples: an example of a built site is a site, and the design's
own answer is that site examples are materialised in one Documenter build — which arrives with the
instrument that needs it.
"""
const RULES = Model.Rule[RENDERED_MATH_SITE, RENDERED_MARKUP, API_GROUPING]

end # module Site
