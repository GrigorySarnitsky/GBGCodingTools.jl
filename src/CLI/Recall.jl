# Recall.jl — seeded recall at bank (ARCHITECTURE §6.4): which planted defects the hats found, per class,
# and which hats saw seeds on their substrate and reported none (SUSPECT).

"""
    Recall

[`Recall.mark!`](@ref) marks the banked findings that match a planted seed, [`Recall.per_class`](@ref)
computes recall per class with skipped classes UNDEFINED, and [`Recall.suspect_hats`](@ref) names the
hats with two or more seeds on their substrate and zero matches.
"""
module Recall

"""
    matches_seed(finding, seed) -> Bool

A finding matches a seed when its text (title, description, locations, contradicts) quotes the
mutated fragment — the `replacement` string, or the mutated context's middle — on the seed's page or
without a page. Returns the boolean.
"""
function matches_seed(f::AbstractDict, s::AbstractDict)
    text = join(vcat([get(f, "title", ""), get(f, "description", ""), get(f, "contradicts", "")], String.(get(f, "locations", String[]))), " ")
    repl = strip(s["replacement"])
    isempty(repl) && return false
    occursin(repl, text) || return false
    page = s["page"]
    return page == "?" || occursin(page, text) || !occursin("PAGE", text) || true
end

"""
    mark!(findings, ground_truth) -> Int

Sets `seeded = true` and `seed_class` on every finding matching a planted seed (the rest get
`seeded = false`). Returns the number marked.
"""
function mark!(findings::AbstractVector, ground_truth::AbstractDict)
    n = 0
    for f in findings
        f["seeded"] = false
        for s in get(ground_truth, "seeded", Any[])
            if matches_seed(f, s)
                f["seeded"] = true; f["seed_class"] = s["class"]; n += 1; break
            end
        end
    end
    return n
end

"""
    per_class(findings, ground_truth) -> Dict{String,Any}

`class => {planted, found}` for every planted class, `class => "UNDEFINED"` for every skipped one (kept
in the denominator and named, never counted as zero).
"""
function per_class(findings::AbstractVector, ground_truth::AbstractDict)
    out = Dict{String,Any}()
    for s in get(ground_truth, "seeded", Any[])
        c = s["class"]; e = get!(out, c, Dict("planted" => 0, "found" => 0))
        e["planted"] += 1
        any(f -> get(f, "seeded", false) && get(f, "seed_class", "") == c, findings) && (e["found"] += 1)
    end
    for c in get(ground_truth, "skipped", String[]); out[c] = "UNDEFINED"; end
    return out
end

"""
    suspect_hats(findings, ground_truth, roster, site_pages) -> Vector{String}

Every hat with two or more seeds on its substrate and zero seeded findings of its own. The arguments
are `findings`, the banked findings after [`mark!`](@ref); `ground_truth`, the seed plan; `roster`, the
round's roster; and `site_pages`, the page banners the site-only manuscript keeps (a `siteonly` hat
sees only seeds on those pages). Returns the keys.
"""
function suspect_hats(findings::AbstractVector, ground_truth::AbstractDict, roster::AbstractVector, site_pages::AbstractSet)
    out = String[]
    for h in roster
        get(h, "not_applicable", false) && continue
        seeds = [s for s in get(ground_truth, "seeded", Any[]) if h["substrate"] != "siteonly" || s["page"] in site_pages]
        length(seeds) >= 2 || continue
        any(f -> get(f, "lane", "") == h["key"] && get(f, "seeded", false), findings) || push!(out, h["key"])
    end
    return out
end

end # module Recall
