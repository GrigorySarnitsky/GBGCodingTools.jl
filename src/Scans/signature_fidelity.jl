# SCAN.SIGNATURE_FIDELITY — RULE.DOC.SIGNATURE_FIDELITY (triage). Source: IT signature_fidelity.jl in
# `Reflection.signature_fidelity`: per exported binding, the displayed argument set against the defined
# method table (accent-normalised), the symmetric difference reported. Loads the package.
register_scan!("SCAN.SIGNATURE_FIDELITY", function (cfg, files)
    rows = Reflection.signature_fidelity(cfg)
    hits = [Hit("", 0, r; symbol = String(first(split(r, ':')))) for r in rows if !occursin("EXTENSION-HOMED", r)]
    return (hits, length(files))
end)
