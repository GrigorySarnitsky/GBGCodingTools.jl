# SCAN.MATHBB_DIGIT — RULE.TEX.MATHBB. Source: PF/IT `\mathbb` on a digit, which falls back to a plain
# glyph; the indicator is `\mathbf{1}`.
register_scan!("SCAN.MATHBB_DIGIT", function (cfg, files)
    regex_scan(cfg, files, r"\\mathbb\s*\{?\s*[0-9]")
end)
