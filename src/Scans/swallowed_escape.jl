# SCAN.SWALLOWED_ESCAPE — RULE.TEX.SWALLOWED_ESCAPE. Source: PF lint_swallowed_escapes
# `(?<!\\)\\[abefnrtv0-7xuU]` inside docstrings: a single-backslash escape Julia's parser consumes before
# Documenter sees the text (`\nabla`, `\alpha`, `\theta`, `\varepsilon`, `\frac` are the usual victims).
# This scan reads the RAW docstring line, which is what makes the doubled form visible.
register_scan!("SCAN.SWALLOWED_ESCAPE", function (cfg, files)
    julia = filter(f -> surface_kind(cfg, f) == :julia, files)
    regex_scan(cfg, julia, r"(?<!\\)\\[abefnrtv0-7xuU]"; on = :raw, skip_comments = false)
end)
