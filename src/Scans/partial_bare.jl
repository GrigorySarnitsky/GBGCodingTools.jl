# SCAN.PARTIAL_BARE — RULE.TEX.PARTIAL. Source: PF/IT `\\partial_[ijk]` and both lint_notation_variants.
# A partial derivative subscripts the coordinate, `\partial_{x_i}`, never the bare index.
register_scan!("SCAN.PARTIAL_BARE", function (cfg, files)
    regex_scan(cfg, files, r"\\partial_[ijk](?![A-Za-z])"; mask_code = true)
end)
