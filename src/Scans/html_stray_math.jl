# SCAN.HTML_STRAY_MATH — RULE.TEX.RENDERED_MATH. Added 2026-09-09 after the generated rules page shipped
# three of them. A double-backtick span is MATH in Julia Markdown, so prose that QUOTES backticked syntax
# inside one is handed to KaTeX; KaTeX cannot parse a backtick and leaves the raw source in the page.
# The rc.1 round found the class by reading the build and deferred the scan (an instrument is never
# changed mid-round); this is the check it was owed.
#
# KaTeX renders in the browser, so the served page carries the math SOURCE, `<span>$…$</span>`. A backtick
# inside it is decisive: LaTeX uses one only for an opening quote in text mode, which this fleet's notation
# never does. A Markdown link or admonition marker inside math is decisive for the same reason. Brackets
# alone are NOT a marker — an interval is legitimate math.
const STRAY_MATH_RE = r"`|\]\(@ref|\]\(http|!!!"

"""
    math_sources(page) -> Vector{String}

The unrendered source of every math span on a built page, delimited as the page carries it (`\$…\$`
inline, `\\[…\\]` display). Returns the sources in page order, empty for a page with no article.
"""
function math_sources(page::AbstractString)
    doc = HtmlWalker.parse_page(page)
    art = HtmlWalker.article_of(doc)
    out = String[]
    art === nothing && return out
    for el in HtmlWalker.elements(art, e -> HtmlWalker.tagname(e) in (:span, :div, :p))
        t = strip(HtmlWalker.text_of(el))
        inline = length(t) > 1 && startswith(t, "\$") && endswith(t, "\$")
        display = startswith(t, "\\[") && endswith(t, "\\]")
        (inline || display) && push!(out, String(t))
    end
    return out
end

register_scan!("SCAN.HTML_STRAY_MATH", function (cfg, pages)
    hits = Hit[]
    for page in pages, src in math_sources(page)
        occursin(STRAY_MATH_RE, src) || continue
        push!(hits, Hit(relpath(page, cfg["root"]), 0, "a rendered math span holds Markdown, not LaTeX: " * first(src, 120)))
    end
    return (unique(hits), length(pages))
end)
