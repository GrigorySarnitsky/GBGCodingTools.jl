# SCAN.SIGNATURE_TYPED — RULE.DOC.SIGNATURE_MIRROR (triage). New 2026-09-12 with the rule's variation
# point: `rubric.signature_types` says how much of the method a signature repeats, and this scan checks
# whichever form the package took. Under `names` (the default) a type in the signature's argument list is
# the hit; under `mirror` an argument the METHOD types and the signature leaves bare is the hit. The
# rule's other half, the 88-column wrap, is SCAN.SIGNATURE_WIDE's.
#
# The parameter list is the FIRST parenthesis and the one that closes it, exactly as SCAN.ARGS_FORM reads
# it: stripping a `-> …` return annotation first is unsound, since a default holding an arrow
# (`exempt = (hit -> false)`) is cut in half by the leftmost match. Reading the list this way is also what
# keeps a typed RETURN — `demote(verdict) -> (verdict′, demoted::Bool)` — from being read as a typed
# argument under either form: it lies outside the parentheses the scan judges.

# the text between the first parenthesis of `sig` and the one that closes it, or nothing
function signature_list(sig::AbstractString)
    o = findfirst('(', sig); o === nothing && return nothing
    depth = 0; i = o
    while i <= lastindex(sig)
        sig[i] == '(' && (depth += 1)
        if sig[i] == ')'
            depth -= 1
            depth == 0 && return sig[nextind(sig, o):prevind(sig, i)]
        end
        i = nextind(sig, i)
    end
    return nothing
end

# `a, b::T = d; io::IO = stdout` → the parameters, split at the top level only: a default may hold a comma
# inside its own brackets (`exempt = Dict{Symbol,String}()`), and splitting on every comma halves it.
function signature_params(inside::AbstractString)
    out = String[]; depth = 0; buf = IOBuffer()
    for c in inside
        c in "([{" && (depth += 1)
        c in ")]}" && (depth -= 1)
        if (c == ',' || c == ';') && depth == 0
            s = strip(String(take!(buf))); isempty(s) || push!(out, s); continue
        end
        print(buf, c)
    end
    s = strip(String(take!(buf))); isempty(s) || push!(out, s)
    return out
end

param_name(p::AbstractString) = strip(replace(first(split(first(split(p, "=")), "::")), "..." => ""))
param_typed(p::AbstractString) = occursin("::", first(split(p, "=")))

register_scan!("SCAN.SIGNATURE_TYPED", function (cfg, files)
    hits = Hit[]; population = 0
    mirror = get(get(cfg, "rubric", Dict{String,Any}()), "signature_types", "names") == "mirror"
    # a docstring's `file` is relative to the consumer root, and the mirror form reads the definition that
    # follows it: resolve against the root, and read each file once rather than once per docstring
    sources = Dict{String,Vector{String}}()
    lines_of(f) = get!(() -> readlines(isabspath(f) ? f : joinpath(cfg["root"], f)), sources, f)
    for d in docstring_blocks(cfg, files)
        inside = signature_list(d.signature)
        inside === nothing && continue                                 # no argument list to judge
        shown = signature_params(inside)
        isempty(shown) && continue
        population += 1
        if !mirror
            typed = [p for p in shown if param_typed(p)]
            isempty(typed) && continue
            push!(hits, Hit(d.file, d.line, "`$(d.binding)` types its argument(s) in the signature line ($(join(typed, ", "))): the name and its default belong there, the type in the argument's bullet";
                            symbol = d.binding))
        else
            # the definition the docstring documents is the first non-blank line after its closing
            # delimiter; without one there is nothing to mirror and the docstring is left alone
            lines = lines_of(d.file)
            j = d.line + 1
            while j <= length(lines) && strip(lines[j]) != "\"\"\""; j += 1; end
            j += 1
            while j <= length(lines) && isempty(strip(lines[j])); j += 1; end
            j <= length(lines) || continue
            def = signature_list(join(lines[j:min(j + 6, length(lines))], " "))
            def === nothing && continue
            shownt = Dict(param_name(p) => param_typed(p) for p in shown)
            bare = [param_name(p) for p in signature_params(def) if param_typed(p) && get(shownt, param_name(p), true) == false]
            isempty(bare) && continue
            push!(hits, Hit(d.file, d.line, "`$(d.binding)` leaves $(join(("`" * b * "`" for b in bare), ", ")) bare where the method types it: this package mirrors the method's types in the signature";
                            symbol = d.binding))
        end
    end
    return (hits, population)
end)
