# Recall.jl — seeded recall at bank (ARCHITECTURE §6.4): which planted defects the hats found, per class,
# and which hats saw seeds on their substrate and reported none (SUSPECT).

"""
    Recall

[`Recall.mark!`](@ref) marks the banked findings that match a planted seed, [`Recall.per_class`](@ref)
computes recall per class with skipped classes UNDEFINED, and [`Recall.suspect_hats`](@ref) names the
hats that were handed two or more seeds and reported none. A HAT is one persona of a consistency
panel, its SUBSTRATE the corpus view that hat is given, and the ROSTER the hats a round resolved to
run: only a `siteonly` substrate is handed a narrowed manuscript, and every other gets the whole
seeded one.
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

# Which planted seeds a hat was actually shown. This follows the DELIVERY: `panel.js` splits the corpus
# exactly once, `siteonly` against `full`, so a `siteonly` hat sees the seeds on a kept page and a `full`
# hat sees them all. The substrate set once named four more views that narrowed nothing; marking a hat
# blind by such a name would have hidden the real failure, a hat handed the seeds that reports none.
sees_seed(substrate, seed, site_pages) =
    substrate == "siteonly" ? seed["page"] in site_pages : true

# Whether a docs lane reading `files` (files, or directories standing for everything under them) is
# handed a seed, whose `page` is the file it was planted in; a lane naming no files reads everything.
lane_sees(files, seed) =
    isempty(files) || any(f -> seed["page"] == f || startswith(seed["page"], rstrip(f, '/') * "/"), files)

"""
    suspect_hats(findings, ground_truth, roster, site_pages; lane_files = nothing) -> Vector{String}

Every hat handed two or more seeds and reporting no seeded finding of its own.
The arguments are:

- `findings` — the banked findings after [`mark!`](@ref).
- `ground_truth` — the seed plan.
- `roster` — the round's roster: the hats it resolved to run, each with its substrate.
- `site_pages` — the page banners the site-only manuscript keeps; a `siteonly` hat sees only seeds on
  those pages, so an EMPTY set means a `siteonly` hat sees none and can never be SUSPECT, while a
  `full` hat is unaffected.
- `lane_files` — a docs round's view: lane key → the files and directories that lane reads. Given, it
  replaces the substrate test.

A hat is judged only on the seeds it was actually handed, which follows the delivery. The panel splits
the corpus once, `siteonly` against `full`: a `siteonly` hat sees only the seeds on a kept page, a
`full` hat is handed the whole seeded manuscript and is judged on all of them.

A docs lane reads a file set, not a manuscript view, so a check-docs round passes `lane_files`: a lane
sees a seed planted in one of its files or under one of its directories, and a lane naming no files — a
cross lane, which reads the whole corpus — sees every seed. Before, a docs lane was judged on every seed
in the round, including seeds in files it never opened. Returns the keys.
"""
function suspect_hats(findings::AbstractVector, ground_truth::AbstractDict, roster::AbstractVector, site_pages::AbstractSet;
                      lane_files = nothing)
    out = String[]
    for h in roster
        get(h, "not_applicable", false) && continue
        sees(s) = lane_files === nothing ? sees_seed(h["substrate"], s, site_pages) : lane_sees(get(lane_files, h["key"], String[]), s)
        seeds = [s for s in get(ground_truth, "seeded", Any[]) if sees(s)]
        length(seeds) >= 2 || continue
        any(f -> get(f, "lane", "") == h["key"] && get(f, "seeded", false), findings) || push!(out, h["key"])
    end
    return out
end

end # module Recall
