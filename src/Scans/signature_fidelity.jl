# SCAN.SIGNATURE_FIDELITY — RULE.DOC.SIGNATURE_FIDELITY (triage). Source: IT signature_fidelity.jl in
# `Reflection.signature_fidelity`: per exported binding, the displayed argument set against the defined
# method table (accent-normalised), the symmetric difference reported. Loads the package.
register_scan!("SCAN.SIGNATURE_FIDELITY", function (cfg, files)
    # the population is the number of bindings COMPARED, never the file count: this printed clean over 74
    # files while examining zero, because the package exports nothing at top level (2026-09-09)
    examined = Ref(0)
    rows = Reflection.signature_fidelity(cfg; examined)
    hits = [Hit("", 0, r; symbol = String(first(split(r, ':')))) for r in rows if !occursin("EXTENSION-HOMED", r)]
    return (hits, examined[])
end)
