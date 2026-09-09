# SCAN.MATHBF — RULE.TEX.MATHBF. Source: IT's `\\mathbf` ban, restricted to the strings outside
# `notation.mathbf_allowed`. `\mathbf{1}` — RULE.TEX.MATHBB's indicator and identity — is admitted in
# every package whatever that list holds, so it is never a hit. The hit text is the offending
# `\mathbf{…}` itself.
register_scan!("SCAN.MATHBF", function (cfg, files)
    allowed = Set(String.(cfg["notation"]["mathbf_allowed"])); push!(allowed, "\\mathbf{1}")
    hits = Hit[]
    for f in files, p in prose_lines(cfg, f)
        p.indocstring && p.comment && continue
        for m in eachmatch(r"\\mathbf(\{[^}]*\})?", mask_code_spans(p.text))
            m.match in allowed || push!(hits, Hit(f, p.n, m.match * "  in: " * strip(p.text)))
        end
    end
    return (hits, length(files))
end)
