# SCAN.ARG_BULLET_BOLD — RULE.DOC.ARG_BULLET. Source: PF guards.sh `^\s*[-*]\s+\*\*\``: an argument or
# field bullet names its argument in a plain code span, never a bold one (a bold PROSE label
# `- **Positions.**` is a different device and does not match: the backtick must follow the `**`).
register_scan!("SCAN.ARG_BULLET_BOLD", function (cfg, files)
    regex_scan(cfg, files, r"^\s*[-*]\s+\*\*`"; on = :raw)
end)
