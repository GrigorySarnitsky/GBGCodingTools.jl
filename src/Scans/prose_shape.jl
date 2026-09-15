# SCAN.PROSE_SHAPE — RULE.DOC.SHAPE. Source: PF lint_prose_shape + IT lint_docstring_shape. Units: every
# docstring (src), every page and every section of a rationale page — a heading, a top-level numbered
# item `NN. ` or a `**(x) ` finding opens a new unit, so an append-only log grows by NEW units. Caps
# (longest paragraph ≤ 120 words, ≤ 3 admonitions) bind on every docstring and every NEW page unit; a
# page unit already in the baseline is held by the ratchet alone, the one place IT's lesson — a cap that
# applies only to new units is escaped by re-baselining or renaming — is traded for an append-only log. The ratchet compares every unit with
# docs/prose_shape.csv (`unit,words,longest_paragraph,admonitions`), written only by `gbg init` and
# `gbg scan docs --rebaseline prose-shape`; a missing CSV is DEAD (exit 2), never a silent pass. In a
# docstring, `# Arguments` precedes any column-0 `!!!` and `# Fields` is the last heading.
const PROSE_PARAGRAPH_CAP = 120
const PROSE_ADMONITION_CAP = 3
const PROSE_SHAPE_BASELINE = joinpath("docs", "prose_shape.csv")

function prose_metrics(text::AbstractString)
    paragraphs = split(text, r"\n\s*\n")
    longest = isempty(paragraphs) ? 0 : maximum(length(split(p)) for p in paragraphs)
    (words = length(split(text)), longest = longest, admonitions = count(r"^\s*!!! "m, text))
end

"""
    prose_units(cfg) -> Dict{String,NamedTuple}

Every prose unit of the shape scan keyed `"<file> :: <signature>"` (a docstring) or `"<file> § <section>"`
(a page section), with its `(words, longest, admonitions)`. Returns the dictionary.
"""
function prose_units(cfg::AbstractDict)
    units = Dict{String,NamedTuple}()
    src = Config.surface_files(cfg, "src")
    pages = unique(vcat(Config.surface_files(cfg, "rationale"), Config.surface_files(cfg, "pages")))
    # The unit key names the file by its basename (PF's CSV schema, kept fleet-wide so an existing
    # baseline stays readable); a basename two surface files share falls back to the relative path.
    allfiles = vcat(src, pages)
    dup = Set(b for b in basename.(allfiles) if count(==(b), basename.(allfiles)) > 1)
    label(f) = basename(f) in dup ? f : basename(f)
    for d in docstring_blocks(cfg, src)
        isempty(d.signature) && continue
        units["$(label(d.file)) :: $(first(d.signature, 60))"] = prose_metrics(d.body)
    end
    for f in pages
        section = "(preamble)"; buf = IOBuffer()
        function flush!()
            body = String(take!(buf))
            isempty(strip(body)) && return
            units["$(label(f)) § $(first(section, 60))"] = prose_metrics(body)
        end
        for p in prose_lines(cfg, f)
            line = p.text
            if startswith(line, "#")
                flush!(); section = strip(replace(line, r"^#+" => ""))
            elseif (m = match(r"^(\d+)\. ", line)) !== nothing
                flush!(); section = "item " * m.captures[1]; println(buf, line)
            elseif (m = match(r"^\*\*\(([a-z]{1,2})\) ", line)) !== nothing
                flush!(); section = "finding (" * m.captures[1] * ")"; println(buf, line)
            else
                println(buf, line)
            end
        end
        flush!()
    end
    return units
end

csvkey(k) = replace(k, "\"" => "'")

"""
    write_prose_shape_baseline(cfg) -> Int

Writes `docs/prose_shape.csv` from the current units. Returns the unit count.
"""
function write_prose_shape_baseline(cfg::AbstractDict)
    units = prose_units(cfg)
    path = joinpath(cfg["root"], PROSE_SHAPE_BASELINE); mkpath(dirname(path))
    open(path, "w") do io
        println(io, "unit,words,longest_paragraph,admonitions")
        for k in sort!(collect(keys(units)))
            u = units[k]
            println(io, "\"", csvkey(k), "\",", u.words, ",", u.longest, ",", u.admonitions)
        end
    end
    return length(units)
end

"""
    prose_shape_changes(cfg) -> Vector{String}

What a `--rebaseline prose-shape` would change, one line per row, printed before it writes: `RAISED`
for a unit whose words, longest paragraph or admonitions would go up, `NEW` for a unit not in the
current baseline, `DROPPED` for a row no unit carries any more. A row that only goes down is not listed
— a lowered ceiling constrains more, never less. The argument is `cfg`, the validated config. Returns
the lines, sorted by unit.
"""
function prose_shape_changes(cfg::AbstractDict)
    base = something(read_prose_shape_baseline(cfg), Dict{String,NTuple{3,Int}}())
    units = prose_units(cfg); out = String[]
    for k in sort!(collect(keys(units)))
        u = units[k]; now = (u.words, u.longest, u.admonitions); key = csvkey(k)
        b = get(base, key, nothing)
        if b === nothing
            push!(out, "NEW      $key: words $(now[1]), longest paragraph $(now[2]), admonitions $(now[3])")
        elseif any(now .> b)
            push!(out, "RAISED   $key: words $(b[1])→$(now[1]), longest paragraph $(b[2])→$(now[2]), admonitions $(b[3])→$(now[3])")
        end
    end
    kept = Set(csvkey.(keys(units)))
    append!(out, ["DROPPED  $k" for k in sort!([k for k in keys(base) if !(k in kept)])])
    return out
end

function read_prose_shape_baseline(cfg::AbstractDict)
    path = joinpath(cfg["root"], PROSE_SHAPE_BASELINE)
    isfile(path) || return nothing
    base = Dict{String,NTuple{3,Int}}()
    for (i, line) in enumerate(eachline(path))
        i == 1 && continue
        m = match(r"^\"(.*)\",(\d+),(\d+),(\d+)$", line)
        m === nothing && continue
        base[m.captures[1]] = (parse(Int, m.captures[2]), parse(Int, m.captures[3]), parse(Int, m.captures[4]))
    end
    return base
end

register_scan!("SCAN.PROSE_SHAPE", function (cfg, files)
    base = read_prose_shape_baseline(cfg)
    base === nothing && return (Hit[], 0)           # DEAD: no baseline — `gbg init` or `--rebaseline` writes it
    units = prose_units(cfg)
    hits = Hit[]
    for k in sort!(collect(keys(units)))
        u = units[k]; file = first(split(k, r" :: | § "))
        file = something(findfirst(f -> basename(f) == file || f == file, files), 0) == 0 ? file : files[findfirst(f -> basename(f) == file || f == file, files)]
        b = get(base, csvkey(k), nothing)
        # The caps bind ALWAYS on a docstring (the rule's unit) and on a NEW page unit (PF's newcomer
        # cap); a baselined page section is held by the ratchet alone.
        if occursin(" :: ", k) || b === nothing
            u.longest > PROSE_PARAGRAPH_CAP && push!(hits, Hit(file, 0, "$k: longest paragraph $(u.longest) > $PROSE_PARAGRAPH_CAP words"))
            u.admonitions > PROSE_ADMONITION_CAP && push!(hits, Hit(file, 0, "$k: $(u.admonitions) admonitions > $PROSE_ADMONITION_CAP"))
        end
        b === nothing && continue
        w, l, a = b
        (u.words > w || u.longest > l || u.admonitions > a) &&
            push!(hits, Hit(file, 0, "$k GREW: words $w→$(u.words), longest paragraph $l→$(u.longest), admonitions $a→$(u.admonitions) — rewrite, do not append; re-baseline deliberately if the growth is new content"))
    end
    for d in docstring_blocks(cfg, Config.surface_files(cfg, "src"))
        lines = split(d.body, '\n')
        args = findfirst(l -> occursin(r"^# Arguments\b", l), lines)
        adm = findfirst(l -> startswith(l, "!!! "), lines)
        flds = findfirst(l -> occursin(r"^# Fields\b", l), lines)
        args !== nothing && adm !== nothing && adm < args &&
            push!(hits, Hit(d.file, d.line + adm, "a column-0 `!!!` admonition precedes `# Arguments`"; symbol = d.binding))
        if flds !== nothing
            later = findfirst(l -> occursin(r"^# \w", l), lines[flds+1:end])
            later === nothing || push!(hits, Hit(d.file, d.line + flds + later, "a heading follows `# Fields`, which must be last"; symbol = d.binding))
        end
    end
    return (hits, length(units))
end)
