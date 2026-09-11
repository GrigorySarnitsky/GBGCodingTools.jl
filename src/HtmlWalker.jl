# HtmlWalker.jl — the Gumbo + AbstractTrees walker shared by Consolidate.jl and the SCAN.HTML_* scans.
# Gumbo has no CSS selectors, so the traversal is hand-rolled.

"""
    HtmlWalker

The one HTML reader of the tool: Gumbo parses a built page ([`HtmlWalker.parse_page`](@ref)), and these
helpers walk it — the article element Documenter renders into ([`HtmlWalker.article_of`](@ref)), the
text of a node ([`HtmlWalker.text_of`](@ref)), the elements matching a predicate
([`HtmlWalker.elements`](@ref)), and a node's tag, classes and attributes ([`HtmlWalker.tagname`](@ref),
[`HtmlWalker.classes`](@ref), [`HtmlWalker.attr`](@ref)). Both the consolidator and the built-HTML scans
go through here, so the rendered site is read one way.
"""
module HtmlWalker

using Gumbo, AbstractTrees

export parse_page, article_of, text_of, elements, tagname, classes, attr

"""
    parse_page(path) -> HTMLDocument

Parses the HTML file at `path` with Gumbo, keeping whitespace-only text nodes (Gumbo.jl drops them by
default, and a dropped space between two inline elements changes the reader text — the 1.6 byte
comparison against the Python consolidator is what caught it). Returns the document; its root is
`doc.root`.
"""
parse_page(path::AbstractString) = parsehtml(read(path, String); preserve_whitespace = true)

"""
    tagname(node) -> Symbol

The tag of an element node (`:div`, `:p`, …), or `:text` for a text node (Gumbo drops comments at
parse time, so no comment node exists). Returns the symbol.
"""
tagname(::HTMLText) = :text
tagname(el::HTMLElement{T}) where {T} = T
tagname(::Any) = :other

"""
    classes(el) -> Vector{String}

The `class` attribute of `el` split on whitespace, empty for a node without one. Returns the list.
"""
classes(el) = el isa HTMLElement ? String.(split(get(el.attributes, "class", ""))) : String[]

"""
    attr(el, name, default = "") -> String

The named attribute of a node, or a fallback. The arguments are:

- `el` — the node; anything that is not an `HTMLElement` (a text node) carries no attributes and
  always takes `default`.
- `name` — the attribute name.
- `default` — the value taken when `el` has no such attribute; `""` unless given.

Returns the string.
"""
attr(el, name::AbstractString, default = "") = el isa HTMLElement ? get(el.attributes, name, default) : default

"""
    elements(root, pred) -> Vector

Every element node under `root` (inclusive, document order) for which `pred(el)` is true. Returns the
list; `pred` receives `HTMLElement`s only.
"""
function elements(root, pred)
    out = Any[]
    for n in PreOrderDFS(root)
        n isa HTMLElement && pred(n) && push!(out, n)
    end
    return out
end

"""
    text_of(node) -> String

The concatenated text of every text node under `node` (comments excluded), as BeautifulSoup's
`get_text()` would give it. Returns the string.
"""
function text_of(node)
    io = IOBuffer()
    for n in PreOrderDFS(node)
        n isa HTMLText && write(io, n.text)
    end
    return String(take!(io))
end

"""
    article_of(doc) -> Union{HTMLElement,Nothing}

The `<article class="content">` Documenter renders a page's body into, or `nothing` when the page has
none (the search page, an asset). Returns the element.
"""
function article_of(doc::HTMLDocument)
    hits = elements(doc.root, e -> tagname(e) == :article && "content" in classes(e))
    return isempty(hits) ? nothing : first(hits)
end

end # module HtmlWalker
