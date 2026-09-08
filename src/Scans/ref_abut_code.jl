# SCAN.REF_ABUT_CODE — RULE.DOC.REF_ABUT. Source: PF guards.sh `\]\(@ref[^)]*\)\``: a `@ref` link
# immediately followed by a code span renders as two adjacent monospace chips with a visible seam.
register_scan!("SCAN.REF_ABUT_CODE", function (cfg, files)
    regex_scan(cfg, files, r"\]\(@ref[^)]*\)`"; on = :raw)
end)
