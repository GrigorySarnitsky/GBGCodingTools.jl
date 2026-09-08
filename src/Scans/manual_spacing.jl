# SCAN.MANUAL_SPACING — RULE.TEX.SPACING (triage). Source: PF/IT `\\[;:](?![a-zA-Z])`: manual `\;`/`\:`
# spacing around a relation or operator; the false positive is a `\;` separating arguments after a comma.
register_scan!("SCAN.MANUAL_SPACING", function (cfg, files)
    regex_scan(cfg, files, r"\\[;:](?![a-zA-Z])")
end)
