# SCAN.AI_BANNER — RULE.DOC.AI_BANNER. Source: PF lint_ai_banner: the banner is present on every
# rationale page and every Literate file (as `# ` comments there), and wherever the banner's first
# words appear on ANY page the two lines are verbatim `AI_BANNER` — a drifted copy is the defect.
register_scan!("SCAN.AI_BANNER", function (cfg, files)
    banner = join(AI_BANNER, "\n")
    commented = join("# " .* AI_BANNER, "\n")
    hits = Hit[]
    required = Set(vcat(Config.surface_files(cfg, "rationale"), Config.surface_files(cfg, "literate")))
    for f in files
        text = read(joinpath(cfg["root"], f), String)
        literate = surface_kind(cfg, f) == :literate
        exact = occursin(literate ? commented : banner, text)
        mentions = occursin("Written by AI", text)
        if f in required && !exact
            push!(hits, Hit(f, 0, mentions ? "AI banner present but differs from the fleet text — copy it verbatim" :
                                            "no AI-provenance banner on a page that must carry it"))
        elseif mentions && !exact
            push!(hits, Hit(f, 0, "AI banner text drifted from the fleet's — copy it verbatim"))
        end
    end
    return (hits, length(files))
end)
