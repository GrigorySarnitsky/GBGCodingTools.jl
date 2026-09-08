# SCAN.FIELD_DOCS — RULE.DOC.FIELDS. Source: PF field_docs.py: a documented struct's `The fields are`
# bullets name real fields (GHOST otherwise), every field has a bullet (UNDOC), a struct with fields
# and no list at all is NOLIST; PF's `NO_FIELD_LIST` constant becomes ledger entries `scope = "scan"`,
# target = the type name, which the engine applies by `symbol`. Zero documented structs ⇒ population 0
# (DEAD): a parser broken by a refactor fails loudly instead of passing vacuously.
const FIELD_BULLET = r"^\s*[-*]\s"
const FIELD_NAME_IN_BULLET = r"`([^`:\s,]+)(?:::[^`]*)?`"
const FIELD_DECL = r"^\s{2,}([^\s:=#]+)\s*::"
const DOC_THEN_STRUCT = r"\"\"\"\n(.*?)\n\"\"\"\n(?:mutable\s+)?struct\s+([^\s{<]+)"s

function documented_fields(doc::AbstractString)
    k = findfirst("The fields are", doc)
    k === nothing && return nothing
    names = String[]; inlist = false
    for line in split(doc[first(k):end], '\n')[2:end]
        if occursin(FIELD_BULLET, line)
            inlist = true
            head = first(split(line, r" — | -- "))       # the prose after the dash backticks other identifiers
            for m in eachmatch(FIELD_NAME_IN_BULLET, head); push!(names, m.captures[1]); end
        elseif inlist && !isempty(strip(line)) && !startswith(line, (' ', '\t'))
            break
        end
    end
    return names
end

function real_fields(body::AbstractString)
    out = String[]
    for line in split(body, '\n')
        occursin(r"^\s*function", line) && break        # an inner constructor ends the field list
        occursin(r"^\s*#", line) && continue
        m = match(FIELD_DECL, line)
        m === nothing || push!(out, m.captures[1])
    end
    return out
end

register_scan!("SCAN.FIELD_DOCS", function (cfg, files)
    hits = Hit[]; checked = 0
    for f in files
        surface_kind(cfg, f) == :julia || continue
        src = read(joinpath(cfg["root"], f), String)
        for m in eachmatch(DOC_THEN_STRUCT, src)
            doc, name = m.captures
            body = src[m.offset + ncodeunits(m.match):end]
            e = findfirst("\nend", body); body = e === nothing ? body : body[1:first(e)]
            line = count(==('\n'), src[1:prevind(src, m.offset)]) + 1
            real = real_fields(body)
            documented = documented_fields(doc)
            if documented === nothing
                isempty(real) || push!(hits, Hit(f, line, "NOLIST $name stores $(real) but has no `The fields are` list — add one, or record why not in the ledger"; symbol = name))
                continue
            end
            checked += 1
            ghost = setdiff(documented, real); missed = setdiff(real, documented)
            isempty(ghost) || push!(hits, Hit(f, line, "GHOST $name documents $(ghost), which the struct does not have; its fields are $(real)"; symbol = name))
            isempty(missed) || push!(hits, Hit(f, line, "UNDOC $name: field(s) $(missed) have no bullet"; symbol = name))
        end
    end
    return (hits, checked)
end)
