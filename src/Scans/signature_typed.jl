# SCAN.SIGNATURE_TYPED — RULE.DOC.SIGNATURE_MIRROR (triage). New 2026-09-12 with the narrowed rule: the
# signature line shows the argument names and defaults, and a type belongs to the argument's own bullet.
# The rule's other half, the 88-column wrap, is SCAN.SIGNATURE_WIDE's.
#
# The parameter list is the FIRST parenthesis and the one that closes it, exactly as SCAN.ARGS_FORM reads
# it: stripping a `-> …` return annotation first is unsound, since a default holding an arrow
# (`exempt = (hit -> false)`) is cut in half by the leftmost match. Reading the list this way is also what
# keeps a typed RETURN — `demote(verdict) -> (verdict′, demoted::Bool)` — from being read as a typed
# argument: it lies outside the parentheses the scan judges.
register_scan!("SCAN.SIGNATURE_TYPED", function (cfg, files)
    hits = Hit[]; population = 0
    for d in docstring_blocks(cfg, files)
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
        population += 1
        occursin("::", inside) || continue
        typed = [strip(a) for a in split(inside, ',') if occursin("::", a)]
        push!(hits, Hit(d.file, d.line, "`$(d.binding)` types its argument(s) in the signature line ($(join(typed, ", "))): the name and its default belong there, the type in the argument's bullet";
                        symbol = d.binding))
    end
    return (hits, population)
end)
