# SCAN.FRAC_UNBRACED — RULE.TEX.FRAC_BRACED. Source: IT's wider `\\[dt]?frac\s*[^{\s]` (catches
# `\tfrac N2` and `\frac\pi2`); PF's digit-only form is a subset.
register_scan!("SCAN.FRAC_UNBRACED", function (cfg, files)
    regex_scan(cfg, files, r"\\[dt]?frac\s*[^{\s]")
end)
