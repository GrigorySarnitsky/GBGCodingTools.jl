# SCAN.ARGS_FORM — RULE.DOC.ARGS_FORM (triage). New 2026-09-09: the rule had no enforcer anywhere, which
# the self-application sweep found. A docstring taking three or more arguments, or any keyword, uses the
# bulleted form led by `The arguments are:`; with fewer it binds them in running prose; the two are never
# mixed in one docstring. Exempt, as the rule states: a thin allocating wrapper (it documents none), an
# internal `_`-prefixed helper, and a docstring whose signature line could not be parsed.
const ARGS_BULLET = "The arguments are:"
const ARGS_PROSE = r"The arguments? (is|are) `"

register_scan!("SCAN.ARGS_FORM", function (cfg, files)
    hits = Hit[]; population = 0
    for d in docstring_blocks(cfg, files)
        startswith(d.binding, "_") && continue                       # an internal helper documents as it likes
        occursin(Reflection.WRAPPER_PHRASE, d.body) && continue      # a thin wrapper documents no arguments
        occursin("The fields are:", d.body) && continue               # a type documents fields (RULE.DOC.FIELDS)
        sig = d.signature
        o = findfirst('(', sig); c = findlast(')', sig)
        (o === nothing || c === nothing || c <= o) && continue        # no argument list to judge
        pos, kw = Reflection.signature_parameters(sig[nextind(sig, o):prevind(sig, c)])
        isempty(pos) && isempty(kw) && continue
        population += 1
        bulleted = occursin(ARGS_BULLET, d.body)
        prosed = occursin(ARGS_PROSE, d.body)
        wants_bullets = length(pos) + length(kw) >= Reflection.ARGS_THRESHOLD || !isempty(kw)
        if bulleted && prosed
            push!(hits, Hit(d.file, d.line, "`$(d.binding)` mixes the two argument forms in one docstring"; symbol = d.binding))
        elseif wants_bullets && !bulleted
            push!(hits, Hit(d.file, d.line, "`$(d.binding)` takes $(length(pos)) positional and $(length(kw)) keyword argument(s): the bulleted `$ARGS_BULLET` form, not prose"; symbol = d.binding))
        elseif !wants_bullets && bulleted
            push!(hits, Hit(d.file, d.line, "`$(d.binding)` takes $(length(pos) + length(kw)) argument(s): bind them in running prose, not bullets"; symbol = d.binding))
        end
    end
    return (hits, population)
end)
