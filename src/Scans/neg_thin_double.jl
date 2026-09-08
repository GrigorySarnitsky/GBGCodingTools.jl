# SCAN.NEG_THIN_DOUBLE — RULE.TEX.SPACING. Source: PF/IT `\!\!` (the double negative thin space before a
# sum or integral): juxtapose instead.
register_scan!("SCAN.NEG_THIN_DOUBLE", function (cfg, files)
    regex_scan(cfg, files, r"\\!\\!")
end)
