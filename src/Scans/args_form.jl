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
        occursin(r"The\s+fields\s+are:", d.body) && continue          # a type documents fields (RULE.DOC.FIELDS);
        # tolerant like the marker above, and for the same reason: the phrase wraps in real prose, and a
        # literal match would judge a fields list as though it documented arguments
        # The parameter list is the FIRST parenthesis and the one that closes it. Stripping a `-> …`
        # return annotation first is unsound: a default that holds an arrow (`exempt = (hit -> false)`)
        # is cut in half by the leftmost match, and the signature then parses as nothing at all.
        sig = d.signature
        o = findfirst('(', sig); c = nothing; depth = 0
        if o !== nothing
            i = o
            while i <= lastindex(sig)
                sig[i] == '(' && (depth += 1)
                if sig[i] == ')'
                    depth -= 1
                    if depth == 0
                        c = i
                        break
                    end
                end
                i = nextind(sig, i)
            end
        end
        (o === nothing || c === nothing) && continue                  # no argument list to judge
        inside = sig[nextind(sig, o):prevind(sig, c)]
        pos, kw = Reflection.signature_parameters(inside)
        # A splat is a parameter the rule counts, but `kwargs...` is not an identifier and
        # `signature_parameters` drops it: without this, `f(cfg; kwargs...)` reads as prose-form. Only
        # the BARE splat is missing — `src::AbstractArray...` already came back as `src`, and matching
        # the raw text would count it twice and push a two-argument docstring over the threshold.
        semi = findfirst(';', inside)
        bare(r) = String(strip(split(split(r, "::")[1], "=")[1]))
        splats(s) = [x for x in bare.(split(s, ',')) if occursin(r"^[A-Za-z_][A-Za-z0-9_]*\.\.\.$", x)]
        append!(pos, splats(semi === nothing ? inside : inside[1:prevind(inside, semi)]))
        semi === nothing || append!(kw, splats(inside[nextind(inside, semi):end]))
        isempty(pos) && isempty(kw) && continue
        population += 1
        bulleted = occursin(ARGS_BULLET, d.body)
        prosed = occursin(ARGS_PROSE, d.body)
        # RULE.DOC.ARGS_FORM's own last exemption: "a single element-type keyword bound in one prose
        # clause". A lone `T`/`eltype`/`*_type` keyword under the threshold is that clause, and the rule
        # is rendered into every consumer, so a scan that flagged it would manufacture a dismissal every
        # time the written exemption is exercised.
        eltype_kw = length(kw) == 1 && occursin(r"^(T|eltype|[A-Za-z_][A-Za-z0-9_]*_type)$", first(kw))
        wants_bullets = length(pos) + length(kw) >= Reflection.ARGS_THRESHOLD ||
                        (!isempty(kw) && !(eltype_kw && length(pos) + length(kw) < Reflection.ARGS_THRESHOLD))
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
