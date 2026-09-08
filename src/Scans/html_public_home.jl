# SCAN.HTML_PUBLIC_HOME — RULE.DOC.API_GROUPING. Source: PF built-HTML question 3 / IT question 2: every
# derived public operation (`.gbg/scratch/public_surface.json`, written by the makedocs wrapper from
# `Reflection.package_operations`) is rendered on some page OUTSIDE an `Internal API` section. A
# missing surface file is DEAD (population 0).
register_scan!("SCAN.HTML_PUBLIC_HOME", function (cfg, pages)
    path = joinpath(cfg["root"], ".gbg", "scratch", "public_surface.json")
    isfile(path) || return (Hit[], 0)
    surface = JSON3.read(read(path, String), Dict{String,Any})
    ops = Set(String.(surface["operations"]))
    homed = Set{String}(); anywhere = Set{String}()
    for page in pages, b in page_bindings(page)
        name = last(split(b.name, '.'))
        push!(anywhere, name)
        occursin("Internal API", b.section) || push!(homed, name)
    end
    hits = Hit[]
    for op in sort!(collect(ops))
        op in homed && continue
        push!(hits, Hit(".gbg/scratch/public_surface.json", 0,
            op in anywhere ? "`$op` is public (a method of a package module) but rendered only under Internal API" :
                             "`$op` is public (a method of a package module) but rendered on no page"; symbol = op))
    end
    return (hits, length(ops))
end)
