# SCAN.TABLE_INDENTED — RULE.DOC.TABLE_TOP_LEVEL. Source: PF guards.sh "indented markdown table", IT's
# same grep. A table separator row indented inside a list item renders as code, not as a table.
register_scan!("SCAN.TABLE_INDENTED", function (cfg, files)
    regex_scan(cfg, files, r"^[ \t]+\|[-:| ]+\|"; on = :raw)
end)
