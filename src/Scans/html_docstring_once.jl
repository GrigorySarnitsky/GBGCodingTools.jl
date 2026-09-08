# SCAN.HTML_DOCSTRING_ONCE — RULE.DOC.API_GROUPING. Source: IT built-HTML question 1: a docstring rendered
# on two pages. Documenter marks each rendered docstring with `<a class="docstring-binding" id=…>`; the
# same binding id on more than one page is the hit.
"""
    page_bindings(page) -> Vector{NamedTuple}

Every rendered docstring on a built page as `(id, name, section)`: the binding anchor's target (its `href` without the `#`), its
displayed name and the `<h2>` section it sits under (`""` before the first). Returns the list in page
order.
"""
function page_bindings(page::AbstractString)
    doc = HtmlWalker.parse_page(page)
    art = HtmlWalker.article_of(doc)
    out = NamedTuple[]; art === nothing && return out
    section = Ref("")
    function walk(n)
        n isa HtmlWalker.HTMLElement || return
        t = HtmlWalker.tagname(n)
        t == :h2 && (section[] = strip(HtmlWalker.text_of(n)))
        if t == :a && "docstring-binding" in HtmlWalker.classes(n)
            # Documenter puts the binding's anchor in the href (`#Module.name`), not in an id attribute.
            id = lstrip(HtmlWalker.attr(n, "href", HtmlWalker.attr(n, "id")), '#')
            push!(out, (id = String(id), name = strip(HtmlWalker.text_of(n)), section = section[]))
        end
        for c in n.children; walk(c); end
    end
    walk(art)
    return out
end

register_scan!("SCAN.HTML_DOCSTRING_ONCE", function (cfg, pages)
    where_ = Dict{String,Vector{String}}()
    for page in pages, b in page_bindings(page)
        push!(get!(where_, b.id, String[]), relpath(page, cfg["root"]))
    end
    hits = Hit[]
    for (id, ps) in sort!(collect(where_))
        length(unique(ps)) > 1 && push!(hits, Hit(first(ps), 0, "docstring `$id` rendered on $(length(unique(ps))) pages: " * join(unique(ps), ", ")))
    end
    return (hits, length(pages))
end)
