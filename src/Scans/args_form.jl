# SCAN.ARGS_FORM — RULE.DOC.ARGS_FORM (triage). New 2026-09-09: the rule had no enforcer anywhere, which
# the self-application sweep found. A docstring taking three or more arguments, or any keyword, uses the
# bulleted form led by `The arguments are:`; with fewer it binds them in running prose; the two are never
# mixed in one docstring. Exempt, as the rule states: a thin allocating wrapper (it documents none), an
# internal `_`-prefixed helper, and a docstring whose signature line could not be parsed.
# whitespace-tolerant: the marker line-wraps in this package's own prose, and a literal substring missed it
const ARGS_BULLET = r"The\s+arguments\s+are:"
const ARGS_PROSE = r"The\s+arguments?\s+(is|are)\s+`"

register_scan!("SCAN.ARGS_FORM", function (cfg, files)
    hits = Hit[]; population = 0
    for d in docstring_blocks(cfg, files)
        startswith(d.binding, "_") && continue                       # an internal helper documents as it likes
        occursin(Reflection.WRAPPER_PHRASE, d.body) && continue      # a thin wrapper documents no arguments
        occursin(r"The\s+fields\s+are:", d.body) && continue          # a type documents fields (RULE.DOC.FIELDS)
        sig = replace(d.signature, r"\s*->.*$" => "")            # the return annotation is not a parameter list
        o = findfirst('(', sig); c = findlast(')', sig)
        (o === nothing || c === nothing || c <= o) && continue        # no argument list to judge
        inside = sig[nextind(sig, o):prevind(sig, c)]
        pos, kw = Reflection.signature_parameters(inside)
        # a splat (`args...`, `kwargs...`) is a parameter the rule counts, but it is not an identifier,
        # so `signature_parameters` drops it: without this, `f(cfg; kwargs...)` reads as prose-form
        semi = findfirst(';', inside)
        splats(s) = [String(m.match) for m in eachmatch(r"[A-Za-z_][A-Za-z0-9_]*\.\.\.", s)]
        append!(pos, splats(semi === nothing ? inside : inside[1:prevind(inside, semi)]))
        semi === nothing || append!(kw, splats(inside[nextind(inside, semi):end]))
        isempty(pos) && isempty(kw) && continue
        population += 1
        bulleted = occursin(ARGS_BULLET, d.body)
        prosed = occursin(ARGS_PROSE, d.body)
        wants_bullets = length(pos) + length(kw) >= Reflection.ARGS_THRESHOLD || !isempty(kw)
        if bulleted && prosed
            push!(hits, Hit(d.file, d.line, "`$(d.binding)` mixes the two argument forms in one docstring"; symbol = d.binding))
        elseif wants_bullets && !bulleted
            push!(hits, Hit(d.file, d.line, "`$(d.binding)` takes $(length(pos)) positional and $(length(kw)) keyword argument(s): the bulleted `The arguments are:` form, not prose"; symbol = d.binding))
        elseif !wants_bullets && bulleted
            push!(hits, Hit(d.file, d.line, "`$(d.binding)` takes $(length(pos) + length(kw)) argument(s): bind them in running prose, not bullets"; symbol = d.binding))
        end
    end
    return (hits, population)
end)
