# SCAN.DOI_CROSSCHECK — RULE.CIT.FULL_INLINE, RULE.CIT.DOI. Source: PF doi_crosscheck.py ∪ IT
# doi_crosscheck.py. Every DOI cited in a docstring appears in the canonical references (the section
# `surfaces.references_heading` names, or the WHOLE of the first rationale file when it is "absent" —
# PF's script compares against all of ARCHITECTURE.md); DOIs compared percent-DECODED; where the heading
# exists, the inline `[*Title*](https://doi.org/…)` title must equal the canonical title for that DOI;
# the retired `[doi:…]` label form is a hit anywhere in a docstring; with `citations.require_doi`, a
# `Reference:` line or bullet with no DOI or Open Library link is a hit. Added 2026-09-09 with the rule's
# rewrite: a title-as-link outside the docstring's `# References` section is the full reference sitting in
# the running prose, which the rule now forbids — the prose cites author–year and the section carries the
# work. A one-line `Reference: …` stays legal, being the lone-citation form of RULE.CIT.BLOCK_LIST. A canonical DOI no docstring
# cites is information, not a hit (a design doc may cite alone).
const DOI_RE = r"doi\.org/[^\s\)\]\"]+"
const TITLE_LINK = r"\[(\*[^\]]+?\*)\]\((https://doi\.org/[^)\s]*)\)"
percent_decode(s) = replace(String(s), r"%([0-9A-Fa-f]{2})" => x -> string(Char(parse(Int, x[2:3]; base = 16))))
norm_doi(s) = lowercase(rstrip(percent_decode(s), ['.', ',', ')', ';']))

function canonical_references(cfg)
    heading = get(cfg["surfaces"], "references_heading", "absent")
    rationale = Config.surface_files(cfg, "rationale")
    if heading == "absent"
        f = something(findfirst(x -> endswith(x, "ARCHITECTURE.md"), rationale), isempty(rationale) ? nothing : 1)
        f === nothing && return ("", "", false)
        return (rationale[f], read(joinpath(cfg["root"], rationale[f]), String), false)
    end
    file, line, _ = Config.resolve_anchor(cfg["root"], heading)
    line == 0 && return (file, "", true)
    lines = readlines(joinpath(cfg["root"], file))
    return (file, join(lines[line:end], "\n"), true)
end

register_scan!("SCAN.DOI_CROSSCHECK", function (cfg, files)
    reffile, refs, titled = canonical_references(cfg)
    canon = Set(norm_doi(m.match) for m in eachmatch(DOI_RE, refs))
    canon_title = Dict(norm_doi(u) => join(split(t), " ") for (t, u) in (m.captures for m in eachmatch(TITLE_LINK, refs)))
    hits = Hit[]; n = 0
    for d in docstring_blocks(cfg, files)
        n += 1
        for m in eachmatch(DOI_RE, d.body)
            doi = norm_doi(m.match)
            doi in canon || push!(hits, Hit(d.file, d.line, "DOI $(doi) is cited here but absent from the canonical references ($(reffile))"; symbol = d.binding))
        end
        if titled
            for m in eachmatch(TITLE_LINK, d.body)
                t, u = m.captures; doi = norm_doi(u)
                haskey(canon_title, doi) || continue
                flat = join(split(t), " ")
                flat == canon_title[doi] || push!(hits, Hit(d.file, d.line, "inline title differs from the canonical one for $(doi): inline $(flat) / canonical $(canon_title[doi])"; symbol = d.binding))
            end
        end
        # the full reference belongs under the docstring's own `# References` heading, never in its prose
        refs_at = findfirst(r"(?m)^#+\s+References\s*$", d.body)
        for m in eachmatch(TITLE_LINK, d.body)
            (refs_at !== nothing && m.offset > first(refs_at)) && continue
            line = count(==('\n'), d.body[1:prevind(d.body, m.offset)])
            occursin(r"(?m)^\s*Reference:", split(d.body, '\n')[line + 1]) && continue
            push!(hits, Hit(d.file, d.line + line, "a full reference in the prose: cite author–year here and put the work under this docstring's `# References` section"; symbol = d.binding))
        end
        for m in eachmatch(r"\[doi:[^\]]+\]", d.body)
            push!(hits, Hit(d.file, d.line, "retired [doi:…] label form $(m.match) — use the title-as-link form"; symbol = d.binding))
        end
        if get(cfg["citations"], "require_doi", true)
            for (i, l) in enumerate(split(d.body, '\n'))
                occursin(r"^\s*(Reference:|-\s+.*\(\d{4}[a-z]?\))", l) || continue
                occursin(r"\((19|20)\d\d[a-z]?\)", l) || continue
                occursin(r"doi\.org/|openlibrary\.org/", l) || occursin(r"^\s*Reference:\s*$", l) ||
                    push!(hits, Hit(d.file, d.line + i, "a reference without a DOI or Open Library link on its title: " * strip(l); symbol = d.binding))
            end
        end
    end
    isempty(refs) && push!(hits, Hit(reffile, 0, "the canonical reference list could not be read (heading not found or no rationale file)"))
    return (hits, n)
end)
