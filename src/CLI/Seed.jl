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

The seed plan for a round. The arguments are:

- `catalog` — the consumer's seed catalogue (the `seeds` shape).
- `full` — the FULL manuscript text.
- `round` — the round id that salts the selection.

A class's `anchor` here is a third sense of the word: the regular expression whose match in the
manuscript marks where the seed is planted. It is neither a `file#heading` reference, which is what
`Config.resolve_anchor` resolves, nor a hat's full-strength flag, which is what `Preflight.resolve_hats`
returns.

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

The manuscripts with every planned seed applied. The arguments are:

- `full` — the FULL manuscript text.
- `siteonly` — the site-only manuscript text.
- `plan` — the selection [`select`](@ref) returned.

In `full` the seeds are applied at the recorded positions (from the end, so positions stay valid); in
`siteonly` each seed is located as the same occurrence of its `original` text within the same page (the
site is a subset of the full manuscript page by page, so a seed on a withheld page is absent there by
design, and a neighbouring seed already applied cannot hide it). Returns both.
"""
function plant(full::AbstractString, siteonly::AbstractString, plan::AbstractVector)
    f = String(full)
    for s in sort(plan; by = x -> x["start"], rev = true)
        f = f[1:prevind(f, s["start"])] * s["replacement"] * f[nextind(f, s["stop"]):end]
    end
    # the site: per seed, the page and the index of `original` within that page, read from the untouched
    # full manuscript; then the same index within the same page of the site, applied from the end
    fpages = page_spans(full); spages = page_spans(siteonly)
    edits = Tuple{Int,Int,String}[]
    for s in plan
        fp = findfirst(p -> p.start <= s["start"] <= p.stop, fpages); fp === nothing && continue
        page = fpages[fp]
        idx = count(m -> m.offset < s["start"], eachmatch(Regex("\\Q" * s["original"] * "\\E"), SubString(full, page.start, page.stop))) + 1
        sp = findfirst(p -> p.name == page.name, spages); sp === nothing && continue
        site_page = spages[sp]
        hits = collect(eachmatch(Regex("\\Q" * s["original"] * "\\E"), SubString(siteonly, site_page.start, site_page.stop)))
        idx <= length(hits) || continue
        m = hits[idx]; a = site_page.start + m.offset - 1
        push!(edits, (a, a + ncodeunits(m.match) - 1, s["replacement"]))
    end
    site = String(siteonly)
    for (a, b, r) in sort(edits; by = first, rev = true)
        site = site[1:prevind(site, a)] * r * site[nextind(site, b):end]
    end
    return (f, site)
end

"""
    page_spans(text) -> Vector{NamedTuple}

The pages of a manuscript as `(name, start, stop)` byte spans, from the `===== PAGE: <name> =====`
banners; text before the first banner is page `"?"`. Returns the spans in order.
"""
function page_spans(text::AbstractString)
    banners = collect(eachmatch(r"===== PAGE: (.+?) =====", text))
    out = NamedTuple[]
    isempty(banners) && return [(name = "?", start = 1, stop = lastindex(text))]
    banners[1].offset > 1 && push!(out, (name = "?", start = 1, stop = prevind(text, banners[1].offset)))
    for (i, b) in enumerate(banners)
        stop = i < length(banners) ? prevind(text, banners[i+1].offset) : lastindex(text)
        push!(out, (name = String(b.captures[1]), start = b.offset, stop = stop))
    end
    return out
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
