# SCAN.CITATION_CRAMMED — RULE.CIT.BLOCK_LIST (triage). Source: PF/IT `References?:[^"]*;` (multi-line):
# two or more citations run together with semicolons instead of one bullet per line.
register_scan!("SCAN.CITATION_CRAMMED", function (cfg, files)
    hits = Hit[]; n = 0
    for d in docstring_blocks(cfg, files)
        n += 1
        for m in eachmatch(r"References?:[^\n]*(?:\n[^\n]+)*"m, d.body)
            block = m.match
            occursin(';', block) || continue
            off = count(==('\n'), d.body[1:prevind(d.body, m.offset)]) + 1
            push!(hits, Hit(d.file, d.line + off, strip(first(split(block, '\n'))); symbol = d.binding))
        end
    end
    return (hits, n)
end)
