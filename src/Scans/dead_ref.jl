# SCAN.DEAD_REF — RULE.DOC.NO_DEAD_REFS, RULE.CIT.NO_INACCESSIBLE (triage). Source: PF/IT `§[0-9]`,
# `docs/(src|…)`, `ARCHITECTURE.md`, `inspiration/` in a docstring: a docstring must read complete at
# the REPL, where none of those is reachable.
register_scan!("SCAN.DEAD_REF", function (cfg, files)
    julia = filter(f -> surface_kind(cfg, f) == :julia, files)
    regex_scan(cfg, julia, r"§\s?[0-9]|docs/(src|[A-Z]+\.md)|[A-Z]{4,}\.md|inspiration/")
end)
