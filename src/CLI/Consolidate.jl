# Consolidate.jl — the built site → the two reader-text manuscripts. The Julia port of the consumers'
# shared consolidate.py over HtmlWalker (Gumbo + AbstractTrees). ACCEPTANCE (1.6): byte-equal output to
# src/CLI/consolidate.py on a real PF build and a real IT build; the Python is deleted in the commit
# that passes. Every rendering rule below mirrors the Python one for one; a divergence is a port defect.

"""
    consolidate(build_dir, withheld; out_full, out_siteonly) -> (pages, nfull, nsite)

Renders every page of the Documenter build under `build_dir` into reader text — headings as `#`,
code as fences, tables as ` | ` rows, admonition titles as `[ADMONITION]`, list items as `- `,
formulas as their raw TeX (Documenter renders KaTeX client-side, so the TeX is the page's text) —
delimited by `===== PAGE: <name> =====` banners, discovered from the build so the manuscript stays
complete when pages are added. Writes two manuscripts: `out_full` with every page, and `out_siteonly`
without the pages whose relative path contains one of the `withheld` words (the design documents the
config names under `design_docs_withheld`). Returns the page count and the two character counts.
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

Every `index.html` under `build_dir` except the `search/` and `assets/` trees, as `(title, path,
relative path)`, sorted by depth then name; the top page is titled `Home`, every other by its directory
with `/` rendered as ` / `. Returns the list.
"""
function discover_pages(build_dir::AbstractString)
    pages = Tuple{String,String,String}[]
    for (dir, _, files) in walkdir(build_dir)
        "index.html" in files || continue
        path = joinpath(dir, "index.html")
        rel = relpath(path, build_dir)
        top = first(splitpath(rel))
        top in ("search", "assets") && continue
        d = dirname(rel)
        title = d in ("", ".") ? "Home" : replace(d, "/" => " / ")
        push!(pages, (title, path, rel))
    end
    sort!(pages; by = p -> (count(==('/'), p[3]), p[3]))
    return pages
end

const CONTAINERS = Set([:p, :div, :section, :article, :ul, :ol, :blockquote, :header, :span,
                        :strong, :em, :b, :i, :sup, :sub, :dl, :dt, :dd])
const BLOCK_END = Set([:p, :div, :section, :blockquote, :dt, :dd])

function render_node!(out::IOBuffer, el, parent_tag::Symbol)
    if el isa HtmlWalker.HTMLText
        write(out, el.text); return                       # bs4: str(NavigableString). NOTE: bs4 also emits
    end                                                   # HTML comments here; Gumbo drops them at parse time.
                                                          # A Documenter article carries none; 1.6's byte
                                                          # comparison is what confirms it.
    el isa HtmlWalker.HTMLElement || return
    name = HtmlWalker.tagname(el); cls = HtmlWalker.classes(el)
    if name in (:script, :style)
        return
    elseif name == :a && "docs-heading-anchor" in cls
        return
    elseif name in (:h1, :h2, :h3, :h4, :h5, :h6)
        txt = strip(replace(HtmlWalker.text_of(el), r"\s+" => " "))
        write(out, "\n\n", "#"^parse(Int, String(name)[2:2]), " ", txt, "\n"); return
    elseif name == :pre
        write(out, "\n```\n", rstrip(HtmlWalker.text_of(el)), "\n```\n"); return
    elseif name == :code && parent_tag != :pre
        write(out, "`", HtmlWalker.text_of(el), "`"); return
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
        push!(rows, join([strip(replace(HtmlWalker.text_of(c), r"\s+" => " ")) for c in cells], " | "))
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

"""
    consolidate_py(build_dir, withheld; out_full, out_siteonly)

TRANSITIONAL: runs the carried `src/CLI/consolidate.py` (the consumers' shared script, verbatim) with
`python3` — the fallback held in hand until the Julia port above is byte-compared against it on a
real PF and a real IT build (1.6). The withheld list is the script's own constant, so `withheld` is
ignored. Returns `nothing`; deleted together with the script in the commit that passes the comparison.
"""
function consolidate_py(build_dir::AbstractString, withheld; out_full::AbstractString, out_siteonly::AbstractString)
    script = joinpath(pkgdir(GBGCodingTools), "src", "CLI", "consolidate.py")
    Base.run(`python3 $script $build_dir $out_full $out_siteonly`)
    return nothing
end
