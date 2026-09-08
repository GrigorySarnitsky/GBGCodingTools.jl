# SCAN.ABUTTING_SPANS — RULE.TEX.ONE_SPAN (triage). Source: IT abutting_spans.py: a bare or linked code
# span beside a ``math`` span, in either order, renders as two disjoint runs; the binding of a code
# object to its symbol is ONE LaTeX span, `\texttt{name} \equiv \varepsilon`. The common false positive
# is plain adjacency of unrelated things (a grid size next to a strategy name).
const ABUT_CODE = raw"(?:\[`[A-Za-z_][A-Za-z0-9_!]*`\]\([^)\n]*\)|`[A-Za-z_][A-Za-z0-9_!]*`)"
const ABUT_MATH = raw"``[^`\n]{1,60}``"
const ABUT_RE = Regex("(?:" * ABUT_MATH * raw"\s*" * ABUT_CODE * "|" * ABUT_CODE * raw"\s*" * ABUT_MATH * ")")
register_scan!("SCAN.ABUTTING_SPANS", function (cfg, files)
    regex_scan(cfg, files, ABUT_RE)
end)
