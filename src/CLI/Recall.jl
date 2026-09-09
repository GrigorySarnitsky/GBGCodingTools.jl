# Recall.jl — seeded recall at bank (ARCHITECTURE §6.4): which planted defects the hats found, per class,
# and which hats saw seeds on their substrate and reported none (SUSPECT).

"""
    Recall

[`Recall.mark!`](@ref) marks the banked findings that match a planted seed, [`Recall.per_class`](@ref)
computes recall per class with skipped classes UNDEFINED, and [`Recall.suspect_hats`](@ref) names the
hats with two or more seeds on their substrate (the view of the corpus a hat reads) and zero matches.
"""
module Recall

"""
    matches_seed(finding, seed) -> Bool

A finding matches a seed when its text (title, description, locations, contradicts) quotes the
mutated text: the `replacement` alone when it is distinctive (six characters or more), else the
replacement with its immediate neighbourhood from the mutated context (a one-letter replacement such
as a bare `i` would otherwise match every finding). Whitespace is normalised on both sides. Returns
the boolean.
"""
function matches_seed(finding::AbstractDict, seed::AbstractDict)
    text = join(vcat([get(finding, "title", ""), get(finding, "description", ""), get(finding, "contradicts", "")], String.(get(finding, "locations", String[]))), " ")
    norm(x) = replace(strip(x), r"\s+" => " ")
    text = norm(text)
    repl = norm(seed["replacement"])
    isempty(repl) && return false
    length(repl) >= 6 && return occursin(repl, text)
    ctx = norm(seed["mutated_context"])
    k = findfirst(repl, ctx); k === nothing && return occursin(repl, text)
    lo = max(firstindex(ctx), prevind(ctx, first(k), min(12, first(k) - 1))); hi = min(lastindex(ctx), nextind(ctx, last(k), min(12, lastindex(ctx) - last(k))))
    probe = ctx[lo:hi]
    return occursin(probe, text) || occursin(strip(probe, ['.', ',', ';', ':']), text)
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

# Which planted seeds a hat was actually shown. This follows the DELIVERY, not the substrate's name:
# `panel.js` splits the corpus exactly once, `siteonly` against everything else, and hands every other
# hat — `rawhtml`, `docstrings`, `rulebook` and `none` included — the same seed-laden full manuscript a
# `full` hat gets. A narrower name does not narrow the text, so it must not narrow the seed set either:
# marking those four blind would hide the real failure, a hat handed the seeds that reports none.
sees_seed(substrate, seed, site_pages) =
    substrate == "siteonly" ? seed["page"] in site_pages : true

"""
    suspect_hats(findings, ground_truth, roster, site_pages) -> Vector{String}

Every hat handed two or more seeds and reporting no seeded finding of its own.
The arguments are:

- `findings` — the banked findings after [`mark!`](@ref).
- `ground_truth` — the seed plan.
- `roster` — the round's roster.
- `site_pages` — the page banners the site-only manuscript keeps; a `siteonly` hat sees only seeds on
  those pages.

A hat is judged only on the seeds it was actually handed, which follows the delivery and not the
substrate's name. The panel splits the corpus once, `siteonly` against everything else: a `siteonly`
hat sees only the seeds on a kept page, and every other substrate — `rawhtml`, `docstrings`, `rulebook`
and `none` as much as `full` — is handed the whole seeded manuscript and is judged on all of them.
Returns the keys.
"""
function suspect_hats(findings::AbstractVector, ground_truth::AbstractDict, roster::AbstractVector, site_pages::AbstractSet)
    out = String[]
    for h in roster
        get(h, "not_applicable", false) && continue
        seeds = [s for s in get(ground_truth, "seeded", Any[]) if sees_seed(h["substrate"], s, site_pages)]
        length(seeds) >= 2 || continue
        any(f -> get(f, "lane", "") == h["key"] && get(f, "seeded", false), findings) || push!(out, h["key"])
    end
    return out
end

end # module Recall
