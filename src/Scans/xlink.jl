# SCAN.XLINK — RULE.DOC.XLINK (triage). Source: IT xlink.jl in `Reflection.xlink`, dry-run: a
# cross-module public name mentioned bare in a docstring at its first mention should be @ref-linked,
# qualified with its owner. `Reflection.xlink(cfg; apply = true)` performs the edit on request.
register_scan!("SCAN.XLINK", function (cfg, files)
    sites = Reflection.xlink(cfg; apply = false)
    hits = [Hit(s.file, s.line, "`$(s.name)` (owned by $(s.owner)) is mentioned bare; link it as [`$(s.owner).$(s.name)`](@ref)") for s in sites]
    return (hits, length(files))
end)
