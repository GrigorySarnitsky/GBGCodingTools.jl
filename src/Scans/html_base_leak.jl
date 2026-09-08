# SCAN.HTML_BASE_LEAK — RULE.DOC.API_GROUPING. Source: PF built-HTML questions 1–2: a `Base.` binding
# rendered under an `Internal API` section is a leak unless `docs.unexported_base_expected` names it
# (Documenter cannot tell that an extended Base function is public, so `Public = false` sweeps it in);
# and a binding rendered under both a public and an internal section is filed twice.
register_scan!("SCAN.HTML_BASE_LEAK", function (cfg, pages)
    expected = Set(String.(cfg["docs"]["unexported_base_expected"]))
    public = Dict{String,String}(); internal = Dict{String,String}()
    hits = Hit[]
    for page in pages, b in page_bindings(page)
        rel = relpath(page, cfg["root"])
        if occursin("Internal API", b.section)
            internal[b.name] = rel
            if startswith(b.name, "Base.") && !(last(split(b.name, '.')) in expected)
                push!(hits, Hit(rel, 0, "`$(b.name)` rendered under Internal API — a Base function the package extends is public; list it in docs.unexported_base_expected only if it is meant to be internal"; symbol = b.name))
            end
        else
            public[b.name] = rel
        end
    end
    for (name, rel) in sort!(collect(internal))
        haskey(public, name) && push!(hits, Hit(rel, 0, "`$name` rendered under both a public section ($(public[name])) and Internal API"; symbol = name))
    end
    return (hits, length(pages))
end)
