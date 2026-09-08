# SCAN.DUPREF — RULE.DOC.LINKS (triage). Source: IT dupref.jl in `Reflection.dupref`: a target linked
# more than once in one docstring (the at-most-once clause).
register_scan!("SCAN.DUPREF", function (cfg, files)
    rows = Reflection.dupref(cfg)
    hits = [Hit(r.file, r.line, "`$(r.target)` linked $(r.count)× in `$(r.signature)`"; symbol = first(split(r.signature, '('))) for r in rows]
    return (hits, length(files))
end)
