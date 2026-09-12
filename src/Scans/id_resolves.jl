# SCAN.ID_RESOLVES — RULE.DOC.CURRENT (triage). New 2026-09-12. A tool identifier in prose is a claim about
# a REGISTER: `RULE.X.Y` says the rulebook holds that rule, `SCAN.X` that the catalogue holds that scan,
# `LEG.X`/`CFG.X`/`PIN.X`/… that the doctor runs that check. The registers are the RUNNING COPY's, so a
# consumer's prose is checked against the tool version it pins, and an id renamed in the tool lights up
# every consumer sentence still citing the old one.
#
# WHY THIS CLASS IS A SCAN AND ITS TWO SIBLINGS ARE NOT. Three mechanical classes were proposed together;
# all three were MEASURED over this package's own surfaces before any was built (2026-09-12), and only one
# survived:
#   * IDS — 964 references, 11 unresolved, and all 11 were artefacts of the pattern rather than defects.
#     Tightened as below, the class is silent on a clean corpus and speaks exactly when a register moves
#     under the prose that cites it. It is worth a scan.
#   * COUNTS — 24 references in surface, of which 17 name a SUBSET ("two rules", "three verbs", "two
#     instruments") rather than an inventory, and nothing lexical separates the two readings. The scan
#     would have been 17 false positives and no true one.
#   * PATHS — 1705 references, 143 unresolved, and the unresolved ones are overwhelmingly CORRECT: the
#     rationale describes a CONSUMER's tree (`src/Interpolation.jl`, `test/pass_audit.jl`), which by design
#     does not exist here.
# Both losers stay with the lanes, on the computed claim checklist, where a reader settles them one by one.
#
# Three shapes are deliberately NOT hits, each a false positive that measurement produced:
#   * a family PREFIX (`RULE.DOC`, `RULE.TEX`) — prose naming a family, not citing a member;
#   * a wildcard STEM (`SCAN.HTML_`, `SCAN.CUSTOM.<id>`) — a pattern, not an id;
#   * anything under the `history_exempt` heading — append-only history correctly names RETIRED ids
#     (`ENV.PYTHON` in this package's own Revision history), so the scan takes prose_text's history cut.
# The first two are one test: a string that some known id CONTINUES is a mention of the namespace, not a
# citation of an id.
#
# The population is the file count, as every text scan's is. Counting id REFERENCES instead would make a
# corpus that legitimately cites none read as DEAD, and "measured nothing" is the wrong verdict for a
# consumer whose docstrings simply do not name the tool's registers.

register_scan!("SCAN.ID_RESOLVES", function (cfg, files)
    tool = pkgdir(GBGCodingTools)
    known = Set{String}()
    for r in TOML.parsefile(joinpath(tool, "policy", "RULES.toml"))["rule"]; push!(known, String(r["id"])); end
    for r in scan_catalog(); push!(known, String(r["id"])); end
    for (id, _) in Doctor.CHECKS; push!(known, String(id)); end
    push!(known, "SCAN.CUSTOM")                                     # the declared consumer namespace, and
    for c in get(get(cfg, "scans", Dict{String,Any}()), "custom", Any[])
        push!(known, "SCAN.CUSTOM." * String(c["id"]))              # this consumer's own custom scans
    end
    namespaces = sort!(unique(String(first(split(i, "."))) for i in known))
    # only a namespace some register actually uses: an ALL-CAPS dotted pair is otherwise ordinary prose
    re = Regex("\\b(?:" * join(namespaces, "|") * ")\\.[A-Z][A-Z0-9_]*(?:\\.[A-Z][A-Z0-9_]*)?")
    mention(id) = any(k -> k != id && startswith(k, id), known)
    afile, aline, _ = Config.resolve_anchor(cfg["root"], get(cfg["surfaces"], "history_exempt", ""))
    hits = Hit[]
    for f in files
        cut = (afile == f && aline > 0) ? aline : typemax(Int)
        for p in prose_lines(cfg, f)
            p.n < cut || continue
            p.indocstring && p.comment && continue                  # the house exemption
            for m in eachmatch(re, p.text)
                id = String(m.match)
                (id in known || mention(id)) && continue
                push!(hits, Hit(f, p.n, "`$id` resolves to no rule, scan or doctor check of the running copy — " * strip(p.text)))
            end
        end
    end
    return (hits, length(files))
end)
