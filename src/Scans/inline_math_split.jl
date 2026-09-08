# SCAN.INLINE_MATH_SPLIT — RULE.TEX.INLINE_ONE_LINE. Source: PF/IT/SS lint_inline_math: an inline ``…``
# span left open at a line end and continued on a line that starts with a list or blockquote leader
# drops out of math mode (the leader is parsed first). Fence- and docstring-aware, per file.
register_scan!("SCAN.INLINE_MATH_SPLIT", function (cfg, files)
    leader = r"^\s{0,3}([-*+>]|\d+[.)])\s"
    twobacktick = r"(?<!`)``(?!`)"
    hits = Hit[]
    for f in files
        inspan = false; lastdoc = false
        for p in prose_lines(cfg, f)
            p.indocstring != lastdoc && (inspan = false; lastdoc = p.indocstring)   # a new docstring resets the span state
            inspan && occursin(leader, p.text) &&
                push!(hits, Hit(f, p.n, "inline ``math`` broken across a line by a list/blockquote leader: " * strip(p.text)))
            isodd(count(twobacktick, p.text)) && (inspan = !inspan)
        end
    end
    return (hits, length(files))
end)
