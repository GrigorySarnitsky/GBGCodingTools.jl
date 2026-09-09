# SCAN.LEFTRIGHT — RULE.TEX.LEFTRIGHT. Source: IT's must-be-empty `\\(left|right)(?![a-zA-Z])`, with the
# system idiom `\left\{ … \right.` excluded by the pattern (so `\leftarrow` and `\rightarrow` never
# match either).
register_scan!("SCAN.LEFTRIGHT", function (cfg, files)
    regex_scan(cfg, files, r"\\left(?![a-zA-Z]|\\\{)|\\right(?![a-zA-Z]|\.)"; mask_code = true)
end)
