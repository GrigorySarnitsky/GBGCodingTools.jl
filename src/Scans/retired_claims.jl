# SCAN.RETIRED_CLAIMS — RULE.DOC.CURRENT. Source: PF lint_retired_claims; the patterns come from the
# consumer's `docs.retired_claims` (each with its reason), matched over the whitespace-normalised prose
# of a whole file so a phrase wrapped across lines is still caught; the file named by
# `surfaces.history_exempt` is cut at that heading (append-only history may quote a retired claim).
register_scan!("SCAN.RETIRED_CLAIMS", function (cfg, files)
    claims = get(cfg["docs"], "retired_claims", Any[])
    hits = Hit[]
    for f in files
        flat = replace(prose_text(cfg, f), r"\s+" => " ")
        for c in claims
            m = match(Regex(c["pattern"]), flat)
            m === nothing && continue
            push!(hits, Hit(f, 0, "retired claim \"" * m.match * "\" — " * c["reason"]))
        end
    end
    return (hits, length(files))
end)
