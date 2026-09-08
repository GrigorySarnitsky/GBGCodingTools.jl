# SCAN.CODE_IN_MATH — RULE.TEX.CODE_IN_MATH (triage). Source: IT's span-only filter: inside each ``…``
# math span, remove the control words, the braced arguments of \texttt/\text/\mathrm/\operatorname/
# \mathit and one-letter subscripts; a bare run of two or more lowercase letters that remains renders
# as a letter product and is usually a code identifier that should be `\texttt{…}`. Span parity is
# carried across lines, so a math span wrapped over a line break pairs correctly.

"""
    math_spans(lines) -> Vector{Tuple{Int,String}}

The inline ``…`` math spans of a sequence of prose lines as `(line number, span text)`, pairing the
double-backtick markers left to right with the open/closed state carried across lines (a span that
wraps is attributed to the line it opens on). Returns the spans.
"""
function math_spans(lines)
    out = Tuple{Int,String}[]
    open_ = false; buf = IOBuffer(); startline = 0
    for (n, text) in lines
        parts = split(text, r"(?<!`)``(?!`)")
        for (i, part) in enumerate(parts)
            if i > 1                                    # a marker preceded this part
                if open_
                    push!(out, (startline, String(take!(buf)))); open_ = false
                else
                    open_ = true; startline = n
                end
            end
            open_ && write(buf, part)
        end
        open_ && write(buf, " ")
    end
    return out
end

register_scan!("SCAN.CODE_IN_MATH", function (cfg, files)
    hits = Hit[]
    for f in files
        pl = [(p.n, p.text) for p in prose_lines(cfg, f) if !(p.indocstring && p.comment)]
        for (n, span) in math_spans(pl)
            s = replace(span, r"\\(texttt|text|mathrm|operatorname|mathit|mathsf|mathbf|boldsymbol|label|mathcal)\{[^}]*\}" => " ")
            s = replace(s, r"\\[a-zA-Z]+" => " ", r"_\{[a-z]+\}" => " ", r"\^\{[a-z]+\}" => " ")
            occursin(r"[a-z]{2,}", s) && push!(hits, Hit(f, n, "``" * strip(span) * "``"))
        end
    end
    return (hits, length(files))
end)
