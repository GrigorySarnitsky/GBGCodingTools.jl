# SCAN.FORMULA_IN_BACKTICKS — RULE.TEX.RENDERED_MATH (triage). Source: PF/IT
# `` `[^`]*[≤≥≠∈∉∇Δ⟨⟩‖√×⋅][^`]*` `` — a mathematical glyph inside a code span is usually a formula that
# should be LaTeX; the false positives are real Julia operators (`×`, `⋅`, `≈`), which is why it is triage.
# Code spans are paired left to right (the grep's pattern also matched the prose BETWEEN two spans).
const FORMULA_GLYPHS = r"[≤≥≠∈∉∇Δ⟨⟩‖√×⋅]"
register_scan!("SCAN.FORMULA_IN_BACKTICKS", function (cfg, files)
    hits = Hit[]
    for f in files, p in prose_lines(cfg, f)
        p.indocstring && p.comment && continue
        for m in eachmatch(r"(?<!`)`([^`\n]+)`(?!`)", p.text)
            occursin(FORMULA_GLYPHS, m.captures[1]) || continue
            push!(hits, Hit(f, p.n, "`" * m.captures[1] * "`  in: " * strip(p.text))); break
        end
    end
    return (hits, length(files))
end)
