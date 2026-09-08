# SCAN.BOLDSYMBOL_UNBRACED — RULE.TEX.BOLDSYMBOL_BRACED. Source: IT `\\boldsymbol(?!\{)` (catches the
# space, digit and `\boldsymbol\omega` forms).
register_scan!("SCAN.BOLDSYMBOL_UNBRACED", function (cfg, files)
    regex_scan(cfg, files, r"\\boldsymbol(?!\{)")
end)
