# SCAN.API_PAGE_STRUCTURE — RULE.DOC.INTERNAL_API, RULE.DOC.API_GROUPING. Source: PF lint_api_page_structure
# over the API pages (the `pages` surface files under an `api/` directory): `## Internal API` comes
# last; no empty `@docs` block (it renders as a heading with no content); no `@index` block.
register_scan!("SCAN.API_PAGE_STRUCTURE", function (cfg, files)
    api = filter(f -> occursin(r"(^|/)api/", f) && endswith(f, ".md"), files)
    hits = Hit[]
    for f in api
        text = read(joinpath(cfg["root"], f), String)
        sections = [m.captures[1] for m in eachmatch(r"^## (.+)$"m, text)]
        k = findfirst(==("Internal API"), sections)
        k === nothing || k == length(sections) ||
            push!(hits, Hit(f, 0, "`## Internal API` is section $k of $(length(sections)) — it must come last"))
        for m in eachmatch(r"```@docs\n(.*?)```"s, text)
            isempty(strip(m.captures[1])) || continue
            line = count(==('\n'), text[1:prevind(text, m.offset)]) + 1
            push!(hits, Hit(f, line, "an empty `@docs` block renders as a heading with no content"))
        end
        for m in eachmatch(r"```@index"s, text)
            line = count(==('\n'), text[1:prevind(text, m.offset)]) + 1
            push!(hits, Hit(f, line, "an `@index` block: API pages are hand-grouped, never indexed"))
        end
    end
    return (hits, length(api))
end)
