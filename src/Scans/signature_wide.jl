# SCAN.SIGNATURE_WIDE — RULE.DOC.SIGNATURE_MIRROR (triage). Source: PF/IT awk over docstring signature
# lines: an indented signature line in the header block wider than 88 columns renders with a horizontal
# scroll; only the docstring wraps (hanging indent), the code never.
const SIGNATURE_WIDTH = 88
register_scan!("SCAN.SIGNATURE_WIDE", function (cfg, files)
    hits = Hit[]; n = 0
    for d in docstring_blocks(cfg, files)
        n += 1
        for (i, l) in enumerate(split(d.body, '\n'))
            startswith(l, "    ") || break                     # the header block ends at the first unindented line
            length(l) > SIGNATURE_WIDTH && push!(hits, Hit(d.file, d.line + i, "$(length(l)) columns: " * strip(l); symbol = d.binding))
        end
    end
    return (hits, n)
end)
