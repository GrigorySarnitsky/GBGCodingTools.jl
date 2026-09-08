# SCAN.REGISTER — RULE.DOC.REGISTER. Source: PF/IT `\b(knobs?|tweaks?)\b` over docs, src and examples.
# Quoted words and code spans are removed before the match, so a rule that NAMES the banned word (or
# an identifier that happens to contain it) is not a hit.
const REGISTER_RE = r"\b(knobs?|tweaks?)\b"i
register_scan!("SCAN.REGISTER", function (cfg, files)
    hits = Hit[]
    for f in files, p in prose_lines(cfg, f)
        p.indocstring && p.comment && continue
        s = replace(p.text, r"`[^`]*`" => " ", r"\"[^\"]*\"" => " ", r"“[^”]*”" => " ")
        occursin(REGISTER_RE, s) && push!(hits, Hit(f, p.n, strip(p.text)))
    end
    return (hits, length(files))
end)
