# SCAN.MATHBF — RULE.TEX.MATHBF. Source: IT's `\\mathbf` ban, restricted to the strings outside
# `notation.mathbf_allowed` (PF admits `\mathbf{1}`; a package on `notation.vectors = "boldsymbol"`
# lists nothing more). The hit text is the offending `\mathbf{…}` itself.
register_scan!("SCAN.MATHBF", function (cfg, files)
    allowed = Set(String.(cfg["notation"]["mathbf_allowed"]))
    hits = Hit[]
    for f in files, p in prose_lines(cfg, f)
        p.indocstring && p.comment && continue
        for m in eachmatch(r"\\mathbf(\{[^}]*\})?", p.text)
            m.match in allowed || push!(hits, Hit(f, p.n, m.match * "  in: " * strip(p.text)))
        end
    end
    return (hits, length(files))
end)
