# SCAN.THIN_SPACE — RULE.TEX.SPACING. Source: PF/IT gratuitous `\,`: the thin space is admitted only
# before the differential, `\,\mathrm{d}` or `\,\mathrm d` (IT's wider lookahead).
register_scan!("SCAN.THIN_SPACE", function (cfg, files)
    regex_scan(cfg, files, r"\\,(?!\\mathrm[ {]d)"; mask_code = true)
end)
