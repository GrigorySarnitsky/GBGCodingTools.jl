# Seed.jl — the seed MECHANISM (ARCHITECTURE §6.4): the catalogue is the consumer's; the selection is
# salted per round; the planting is in place on the manuscripts; the ground truth is recomputed at bank.

"""
    Seeds

Plants labelled defects into the consolidated manuscripts so a panel's recall is measurable.
[`Seeds.select`](@ref) picks one occurrence per class with a per-round salt, [`Seeds.plant`](@ref)
mutates the manuscripts, and the same `select` over the unseeded manuscript at bank is the ground truth.
"""
module Seeds

using SHA, TOML
using ..GBGCodingTools: instrument_schema, validate

"""
    salt_offset(round, class) -> Int

A deterministic offset from the round id and the class name (the first 8 hex digits of their sha256),
so no two rounds plant the same occurrence of a class.
"""
salt_offset(round::AbstractString, class::AbstractString) = parse(Int, bytes2hex(sha256(codeunits(round * "/" * class)))[1:8]; base = 16)

"""
    page_of(text, pos) -> String

The `===== PAGE: <name> =====` banner that precedes byte position `pos`, or `"?"`.
"""
function page_of(text::AbstractString, pos::Int)
    page = "?"
    for m in eachmatch(r"===== PAGE: (.+?) =====", text)
        m.offset >= pos && break
        page = m.captures[1]
    end
    return page
end

"""
    select(catalog, full, round) -> (seeded, skipped)

The seed plan for a round. The arguments are `catalog`, the consumer's seed catalogue (the `seeds`
shape); `full`, the FULL manuscript text; and `round`, the round id that salts the selection.

For every `[[class]]`: the occurrences of `anchor` in `full`; the chosen one is `((occurrence - 1 +
salt_offset) mod count) + 1`; a class whose anchor occurs nowhere is skipped and named. Returns the
plan `[{id, class, page, start, stop, original, replacement, original_context, mutated_context}]` (byte
positions into `full`) and the skipped classes.
"""
function select(catalog::AbstractDict, full::AbstractString, round::AbstractString)
    seeded = Dict{String,Any}[]; skipped = String[]
    for (i, c) in enumerate(catalog["class"])
        hits = collect(eachmatch(Regex(c["anchor"]), full))
        isempty(hits) && (push!(skipped, c["name"]); continue)
        nth = mod(c["occurrence"] - 1 + salt_offset(round, c["name"]), length(hits)) + 1
        m = hits[nth]
        start = m.offset; stop = m.offset + ncodeunits(m.match) - 1
        lo = max(1, thisind(full, max(1, start - 60))); hi = min(lastindex(full), thisind(full, min(lastindex(full), stop + 60)))
        original_context = String(full[lo:hi])
        mutated_context = String(full[lo:prevind(full, start)]) * c["replacement"] * String(full[nextind(full, stop):hi])
        push!(seeded, Dict("id" => "seed-$(lpad(i, 2, '0'))-$(c["name"])", "class" => c["name"], "page" => page_of(full, start),
                           "start" => start, "stop" => stop, "original" => String(m.match), "replacement" => c["replacement"],
                           "original_context" => original_context, "mutated_context" => mutated_context))
    end
    return (seeded, skipped)
end

"""
    plant(full, siteonly, plan) -> (full′, siteonly′)

The manuscripts with every planned seed applied. The arguments are `full` and `siteonly`, the two
manuscript texts, and `plan`, the selection [`select`](@ref) returned. In `full` the seeds are applied
at the recorded positions (from the end, so positions stay valid); in `siteonly` by locating the same
`original_context` (the site is a subset of the full manuscript, so a seed on a withheld page is
absent there by design). Returns both.
"""
function plant(full::AbstractString, siteonly::AbstractString, plan::AbstractVector)
    f = String(full)
    for s in sort(plan; by = x -> x["start"], rev = true)
        f = f[1:prevind(f, s["start"])] * s["replacement"] * f[nextind(f, s["stop"]):end]
    end
    site = String(siteonly)
    for s in plan
        k = findfirst(s["original_context"], site)
        k === nothing && continue
        site = site[1:prevind(site, first(k))] * s["mutated_context"] * site[nextind(site, last(k)):end]
    end
    return (f, site)
end

"""
    read_catalog(path) -> Dict

The consumer's seed catalogue, validated against the `seeds` definition of the check-consistency schema.
"""
function read_catalog(path::AbstractString)
    cat = TOML.parsefile(path)
    inst = instrument_schema("check-consistency")
    errs = validate(inst["\$defs"]["seeds"], cat; root = inst)
    isempty(errs) || error("seed catalogue $path is invalid:\n  " * join(errs, "\n  "))
    return cat
end

end # module Seeds
