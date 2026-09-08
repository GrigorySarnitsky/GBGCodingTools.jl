# SCAN.STRAY_TEX_DOLLAR — RULE.TEX.RENDERED_MATH (triage). Source: PF/IT `\$[^$]*[\\_^{}][^$]*\$` over the
# Markdown surfaces: `$…$` is not math in Documenter; use ``…`` or ```math```.
register_scan!("SCAN.STRAY_TEX_DOLLAR", function (cfg, files)
    md = filter(f -> surface_kind(cfg, f) != :julia, files)
    regex_scan(cfg, md, r"\$[^$\n]*[\\_^{}][^$\n]*\$")
end)
