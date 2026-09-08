# SCAN.HTML_RENDERED_MARKUP — RULE.TEX.RENDERED_MARKUP. Source: PF lint_rendered_markup over the built
# site: the article text with code, pre, script, style and math elements removed; an emphasis marker
# (`*x`, `**x`, `__x`) surviving into prose means the source nested emphasis CommonMark cannot resolve.
function article_prose(page::AbstractString)
    doc = HtmlWalker.parse_page(page)
    art = HtmlWalker.article_of(doc)
    art === nothing && return ""
    io = IOBuffer()
    function walk(n)
        if n isa HtmlWalker.HTMLText
            write(io, n.text)
        elseif n isa HtmlWalker.HTMLElement
            t = HtmlWalker.tagname(n)
            t in (:code, :pre, :script, :style) && return
            any(c -> startswith(c, "math") || c == "katex", HtmlWalker.classes(n)) && return
            for c in n.children; walk(c); end
            t in (:p, :li, :div, :h1, :h2, :h3, :h4, :h5, :h6, :br, :tr) && write(io, '\n')
        end
    end
    for c in art.children; walk(c); end
    return String(take!(io))
end

register_scan!("SCAN.HTML_RENDERED_MARKUP", function (cfg, pages)
    hits = Hit[]
    for page in pages
        text = replace(article_prose(page), r"\\\[.*?\\\]"s => " ", r"\\\(.*?\\\)"s => " ", r"\$[^\$\n]*\$" => " ")
        for (i, line) in enumerate(split(text, '\n'))
            for m in eachmatch(r"\*\*?[^\s*]|(?<![\w\\])__[^\s_]", line)
                lo = max(1, m.offset - 70); hi = min(lastindex(line), m.offset + 80)
                excerpt = join(split(SubString(line, thisind(line, lo), thisind(line, hi))), " ")
                push!(hits, Hit(relpath(page, cfg["root"]), 0, "…" * excerpt * "…"))
            end
        end
    end
    return (unique(hits), length(pages))
end)
