# Consolidate.jl — the built site → the two reader-text manuscripts. The Julia port of the consumers'
# shared consolidate.py over HtmlWalker (Gumbo + AbstractTrees). ACCEPTANCE (1.6) PASSED 2026-09-09:
# byte-equal output to the Python on a real PF build (18 pages) and a real IT build (22 pages), all four
# manuscripts; the Python was deleted in that commit. Every rendering rule below mirrors the Python's one
# for one, including BeautifulSoup's two whitespace behaviours (bs_string) — a divergence is a port defect.

"""
    consolidate(build_dir, withheld; out_full, out_siteonly) -> (pages, nfull, nsite)

Renders every page of the Documenter build under `build_dir` into reader text — headings as `#`,
code as fences, tables as ` | ` rows, admonition titles as `[ADMONITION]`, list items as `- `,
formulas as their raw TeX (Documenter renders KaTeX client-side, so the TeX is the page's text) —
delimited by `===== PAGE: <name> =====` banners, discovered from the build so the manuscript stays
complete when pages are added. Writes two manuscripts. The arguments are:

- `build_dir` — the Documenter build whose pages are discovered and rendered.
- `withheld` — the words that withhold a page (the design documents the config names under
  `design_docs_withheld`).
- `out_full` — the manuscript written with every page.
- `out_siteonly` — the manuscript written without the pages whose relative path contains one of the
  `withheld` words.

Returns the page count and the two character counts.
"""
function consolidate(build_dir::AbstractString, withheld::AbstractVector{<:AbstractString};
                     out_full::AbstractString, out_siteonly::AbstractString)
    pages = discover_pages(build_dir)
    full = IOBuffer(); site = IOBuffer()
    for (title, path, rel) in pages
        banner = "\n\n===== PAGE: $title =====\n"
        text = page_text(path)
        write(full, banner); write(full, text)
        low = lowercase(rel)
        if !any(d -> occursin(lowercase(d), low), withheld)
            write(site, banner); write(site, text)
        end
    end
    f = String(take!(full)); s = String(take!(site))
    write(out_full, f); write(out_siteonly, s)
    return (length(pages), length(f), length(s))
end

"""
    discover_pages(build_dir) -> Vector{Tuple{String,String,String}}

Every rendered page under `build_dir` except the `search/` and `assets/` trees and the search page, as
`(title, path, relative path)`, sorted by depth then name; under `prettyurls` a page is its directory's
`index.html` and is titled by the directory with `/` rendered as ` / ` (the top page `Home`); without
`prettyurls` a page is `<name>.html` and is titled by its path without the extension. The `index.html`
form is byte-identical to the consumers' Python consolidator (1.6). Returns the list.
"""
function discover_pages(build_dir::AbstractString)
    pages = Tuple{String,String,String}[]
    for (dir, _, files) in walkdir(build_dir)
        rel_dir = relpath(dir, build_dir)
        top = first(splitpath(rel_dir))
        top in ("search", "assets") && continue
        for f in files
            endswith(f, ".html") || continue
            f == "search.html" && continue
            path = joinpath(dir, f)
            rel = relpath(path, build_dir)
            d = dirname(rel)
            title = f == "index.html" ? (d in ("", ".") ? "Home" : replace(d, "/" => " / ")) :
                    replace(rel[1:end-5], "/" => " / ")
            push!(pages, (title, path, rel))
        end
    end
    sort!(pages; by = p -> (count(==('/'), p[3]), p[3]))
    return pages
end

const CONTAINERS = Set([:p, :div, :section, :article, :ul, :ol, :blockquote, :header, :span,
                        :strong, :em, :b, :i, :sup, :sub, :dl, :dt, :dd])
const BLOCK_END = Set([:p, :div, :section, :blockquote, :dt, :dd])

# BeautifulSoup's `endData` rule, mirrored: a whitespace-only string outside <pre> becomes one "\n" if
# it contains a newline, else one " " (its ASCII_SPACES are space, \n, \t, \f, \r). Gumbo keeps such
# nodes whole (parse_page asks it to), so the collapse is applied here; strings with content are untouched.
const BS_SPACES = (' ', '\n', '\t', '\f', '\r')
bs_string(t::AbstractString) = (!isempty(t) && all(c -> c in BS_SPACES, t)) ? (occursin('\n', t) ? "\n" : " ") : String(t)

# bs4's get_text() over a non-<pre> element: every descendant string, each collapsed by the rule above.
function bs_text(node)
    io = IOBuffer()
    for n in AbstractTrees.PreOrderDFS(node)
        n isa HtmlWalker.HTMLText && write(io, bs_string(n.text))
    end
    return String(take!(io))
end

function render_node!(out::IOBuffer, el, parent_tag::Symbol)
    if el isa HtmlWalker.HTMLText
        write(out, bs_string(el.text)); return            # bs4: str(NavigableString) after endData. NOTE: bs4
    end                                                   # also emits HTML comments here; Gumbo drops them at
                                                          # parse time. A Documenter article carries none; 1.6's
                                                          # byte comparison is what confirms it.
    el isa HtmlWalker.HTMLElement || return
    name = HtmlWalker.tagname(el); cls = HtmlWalker.classes(el)
    if name in (:script, :style)
        return
    elseif name == :a && "docs-heading-anchor" in cls
        return
    elseif name in (:h1, :h2, :h3, :h4, :h5, :h6)
        txt = strip(replace(bs_text(el), r"\s+" => " "))
        write(out, "\n\n", "#"^parse(Int, String(name)[2:2]), " ", txt, "\n"); return
    elseif name == :pre
        write(out, "\n```\n", rstrip(HtmlWalker.text_of(el)), "\n```\n"); return
    elseif name == :code && parent_tag != :pre
        write(out, "`", bs_text(el), "`"); return
    elseif name == :table
        write(out, "\n", render_table(el), "\n"); return
    elseif name == :br
        write(out, "\n"); return
    elseif name == :li
        write(out, "\n- ")
        for c in el.children; render_node!(out, c, name); end
        return
    elseif name in CONTAINERS
        "admonition-title" in cls && write(out, "\n[ADMONITION] ")
        for c in el.children; render_node!(out, c, name); end
        name in BLOCK_END && write(out, "\n")
        return
    end
    for c in el.children; render_node!(out, c, name); end
end

function render_table(tbl)
    rows = String[]
    for tr in HtmlWalker.elements(tbl, e -> HtmlWalker.tagname(e) == :tr)
        cells = HtmlWalker.elements(tr, e -> HtmlWalker.tagname(e) in (:th, :td))
        push!(rows, join([strip(replace(bs_text(c), r"\s+" => " ")) for c in cells], " | "))
    end
    return join(rows, "\n")
end

"""
    page_text(path) -> String

The reader text of one built page: the children of its `<article class="content">` rendered, runs of
three or more newlines collapsed to two. Returns the string, empty for a page without an article.
"""
function page_text(path::AbstractString)
    doc = HtmlWalker.parse_page(path)
    art = HtmlWalker.article_of(doc)
    out = IOBuffer()
    if art !== nothing
        for c in art.children
            render_node!(out, c, :article)
        end
    end
    return replace(String(take!(out)), r"\n{3,}" => "\n\n")
end
