# SCAN.NEG_THIN_BIGL — RULE.TEX.SPACING. Source: PF `\!` before `\bigl`/`\Bigr`: the negative thin
# space before a sized delimiter is a manual correction the idiom forbids.
register_scan!("SCAN.NEG_THIN_BIGL", function (cfg, files)
    regex_scan(cfg, files, r"\\!\\[bB]ig[lr]"; mask_code = true)
end)
