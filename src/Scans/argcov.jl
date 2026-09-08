# SCAN.ARGCOV — RULE.DOC.ARGCOV (tier = the consumer's `argcov_policy`). Source: PF argcov.jl's exemption
# classes ∪ IT's identifier class and `arg = default` form, all in `Reflection.argcov`; the ledger's
# `match` predicates (arg_name, arg_type, symbol, path) are applied by the engine per trigger, and the
# population is the argument count, which `EXEMPT.BROAD` dry-runs over.
register_scan!("SCAN.ARGCOV", function (cfg, files)
    hits, population, _ = Reflection.argcov(cfg)
    out = [Hit(h.file, h.line, "`$(h.parameter)` of `$(first(h.signature, 70))` is undocumented"; symbol = h.binding) for h in hits]
    return (out, population)
end)
