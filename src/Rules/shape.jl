# The design's §5.2 and §7; the coordinates live here rather than in a docstring, which must read
# complete at the REPL.
"""
    Rules.Shape

The rule that holds the SHAPE of prose: a paragraph no longer than the house cap, few enough admonitions,
and — for text that was already there when the cap arrived — no growth. It is the one rule with a frozen
baseline, because the cap alone would have failed thousands of lines of prose written before it.

A unit is one docstring or one section of a page. A NEW unit is held to the caps; an existing one is held
to its own recorded numbers, which may fall and never rise. The baseline is rewritten only deliberately,
with a reason, which is what keeps "rewrite, do not append" from becoming "re-baseline and carry on".
"""
module Shape

using ...Model
using ...Texts

const PARAGRAPH_CAP = 120
const ADMONITION_CAP = 3
const BASELINE = joinpath("docs", "prose_shape.csv")

"""
    metrics(text) -> NamedTuple

The three numbers a unit of prose is held to: its words, its longest paragraph in words, and how many
admonitions it carries. The argument is `text`, the unit's text. Returns them as `(words, longest,
admonitions)`.
"""
function metrics(text::AbstractString)
    paragraphs = split(text, r"\n\s*\n")
    longest = isempty(paragraphs) ? 0 : maximum(length(split(p)) for p in paragraphs)
    return (words = length(split(text)), longest = longest, admonitions = count(r"^\s*!!! "m, text))
end

"""
    units(root, files) -> Dict{String,NamedTuple}

Every unit of prose in the files, keyed by where it is: a docstring by its file and binding, a page
section by its file and heading. The arguments are `root`, the package root, and `files`, the paths to
read. Returns the units with their metrics.

A heading, a numbered top-level item and a bold lettered finding each open a new unit, which is what lets
an append-only document grow by NEW units rather than by swelling one.
"""
function units(root::AbstractString, files)
    out = Dict{String,NamedTuple}()
    for f in files
        path = joinpath(root, f)
        isfile(path) || continue
        if endswith(f, ".jl")
            for d in Texts.docstrings_of(read(path, String))
                isempty(strip(d.text)) && continue
                # Keyed by the SIGNATURE a docstring displays, falling back to the binding where it
                # shows none — a module or a type documented without one. Two methods of a generic have
                # one binding and two docstrings, so a key that is only the binding collapses them and
                # matches neither in a package's recorded baseline.
                sig = Texts.signature_line(d.text)
                out["$(basename(f)) :: $(first(isempty(sig) ? d.node : sig, 60))"] = metrics(d.text)
            end
        else
            section = "(preamble)"; buf = IOBuffer(); fenced = false
            flush!() = begin
                body = String(take!(buf))
                isempty(strip(body)) || (out["$(basename(f)) § $(first(section, 60))"] = metrics(body))
            end
            for line in split(read(path, String), '\n')
                # A fenced block is code, a diagram or a doctest — never prose a reader parses, and
                # counting its words measures the example rather than the writing.
                if startswith(strip(line), "```")
                    fenced = !fenced
                    continue
                end
                fenced && continue
                if startswith(line, "#")
                    flush!(); section = strip(replace(String(line), r"^#+" => ""))
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
    end
    return out
end

"""
    baseline(root) -> Union{Dict{String,NTuple{3,Int}},Nothing}

The recorded numbers each unit was at when the baseline was last written, or `nothing` where the package
keeps none. The argument is `root`, the package root. Returns the rows.

A MISSING baseline is not an empty one: a package with prose and no baseline has never been measured, and
saying so is the point — a check that passes vacuously is worse than one that refuses.
"""
function baseline(root::AbstractString)
    path = joinpath(root, BASELINE)
    isfile(path) || return nothing
    rows = Dict{String,NTuple{3,Int}}()
    for line in Iterators.drop(eachline(path), 1)
        m = match(r"^\"(.*)\",(\d+),(\d+),(\d+)$", line)
        m === nothing && continue
        rows[m.captures[1]] = (parse(Int, m.captures[2]), parse(Int, m.captures[3]), parse(Int, m.captures[4]))
    end
    return rows
end

csvkey(k) = replace(k, "\"" => "'")

"""
    prose_shape(root, cfg) -> Vector{Model.Location}

Every unit of prose that breaks its cap or has grown past its recorded numbers. The arguments are `root`,
the package root, and `cfg`, the package's config, which names the files. Returns one location per unit.

A unit the baseline does not hold is NEW and is held to the caps; one it holds may fall and never rise.
"""
function prose_shape(root::AbstractString, cfg)
    cat = parentmodule(@__MODULE__)
    files = files_of(root, cfg)
    base = baseline(root)
    out = Model.Location[]
    for (key, u) in sort!(collect(units(root, files)))
        recorded = base === nothing ? nothing : get(base, csvkey(key), nothing)
        if recorded === nothing
            u.longest > PARAGRAPH_CAP && push!(out, Model.Location(; file = "", line = 0,
                text = "$key: longest paragraph $(u.longest) > $PARAGRAPH_CAP words"))
            u.admonitions > ADMONITION_CAP && push!(out, Model.Location(; file = "", line = 0,
                text = "$key: $(u.admonitions) admonitions > $ADMONITION_CAP"))
        elseif u.words > recorded[1] || u.longest > recorded[2] || u.admonitions > recorded[3]
            push!(out, Model.Location(; file = "", line = 0,
                text = "$key GREW: words $(recorded[1])→$(u.words), longest paragraph $(recorded[2])→$(u.longest) — rewrite, do not append"))
        end
    end
    return out
end

# Where prose lives in a package that has said nothing. A page written at build time is left out, as it
# is everywhere else: the rules page necessarily holds text that breaks the rules it lists, and a copy's
# prose belongs to the source it came from.
function default_files(root::AbstractString, cfg)
    written = Set(vcat(cfg.generated, first.(cfg.copies)))
    skip = Texts.ignored(root)
    out = String[]
    for (dir, _, fs) in walkdir(root)
        rel = relpath(dir, root)
        startswith(rel, ".git") && continue
        for f in fs
            p = rel == "." ? f : joinpath(rel, f)
            p = replace(p, '\\' => '/')
            (p in written || skip(p)) && continue
            (startswith(p, "src/") && endswith(p, ".jl")) || (startswith(p, "docs/src/") && endswith(p, ".md")) || continue
            push!(out, p)
        end
    end
    return out
end

"""
    write_baseline(root, cfg) -> Int

Writes the baseline from the prose as it stands and returns how many units it recorded. The arguments are
`root`, the package root, and `cfg`, the package's config.

It is called only by a person asking for it, with a reason — never by a check. A baseline a check could
rewrite is a ratchet that resets itself.
"""
function write_baseline(root::AbstractString, cfg)
    us = units(root, files_of(root, cfg))
    path = joinpath(root, BASELINE)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "unit,words,longest_paragraph,admonitions")
        for k in sort!(collect(keys(us)))
            u = us[k]
            println(io, "\"", csvkey(k), "\",", u.words, ",", u.longest, ",", u.admonitions)
        end
    end
    return length(us)
end

"""
    changes(root, cfg) -> Vector{String}

What rewriting the baseline would change, one line per row: `RAISED` where a unit's numbers would go up,
`NEW` for a unit the baseline does not hold, `DROPPED` for a row no unit carries any more. The arguments
are `root`, the package root, and `cfg`, the package's config.

A row that only goes down is not listed: a lowered ceiling constrains more, never less. Returns the
lines, sorted.
"""
function changes(root::AbstractString, cfg)
    base = something(baseline(root), Dict{String,NTuple{3,Int}}())
    us = units(root, files_of(root, cfg))
    out = String[]
    for k in sort!(collect(keys(us)))
        u = us[k]; now = (u.words, u.longest, u.admonitions); key = csvkey(k)
        b = get(base, key, nothing)
        if b === nothing
            push!(out, "NEW      $key: words $(now[1]), longest paragraph $(now[2]), admonitions $(now[3])")
        elseif any(now .> b)
            push!(out, "RAISED   $key: words $(b[1])→$(now[1]), longest paragraph $(b[2])→$(now[2]), admonitions $(b[3])→$(now[3])")
        end
    end
    kept = Set(csvkey.(keys(us)))
    append!(out, ["DROPPED  $k" for k in sort!([k for k in keys(base) if !(k in kept)])])
    return out
end

"""
    files_of(root, cfg) -> Vector{String}

The files this rule reads in the package: what its file sets name, or the defaults where they name
nothing. The arguments are `root`, the package root, and `cfg`, the package's config. Returns the paths.
"""
function files_of(root::AbstractString, cfg)
    files = String[]
    for fs in (Model.FileSet.CODE, Model.FileSet.PAGES, Model.FileSet.RATIONALE)
        patterns = get(cfg.filesets, fs, String[])
        append!(files, [p for p in patterns if isfile(joinpath(root, p))])
    end
    isempty(files) && return default_files(root, cfg)
    skip = Texts.ignored(root)
    return filter(!skip, files)
end

const SHAPE = Model.Rule(
    id = Symbol("RULE.DOC.SHAPE"),
    statement = "A paragraph of prose stays inside the house cap, an admonition count stays inside its own, and prose that was here before the cap may shrink but never grow.",
    why = "Prose grows by accretion: each addition is small, nobody rewrites, and the paragraph nobody can read was never written in one sitting.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.ProgramCheck(Model.Input.FILE_TREE, prose_shape, false),
    examples = [
        Model.TreeExample(["docs/src/page.md" => "# A page\n\n" * join(fill("word", 130), " ") * "\n"],
            [Model.Location(; file = "", line = 0)], "a paragraph stays inside the cap"),
        Model.TreeExample(["docs/src/page.md" => "# A page\n\n" * join(fill("word", 40), " ") * "\n"],
            Model.Location[], "a paragraph stays inside the cap"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[SHAPE]

end # module Shape
