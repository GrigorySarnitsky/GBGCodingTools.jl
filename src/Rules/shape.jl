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
    longest = isempty(paragraphs) ? 0 : maximum(words(p) for p in paragraphs)
    return (words = words(text), longest = longest, admonitions = count(r"^\s*!!! "m, text))
end

# The words of a prose text: mathematics is not prose, so a formula counts as one word however it is
# laid out — breaking a long one into aligned rows, which RULE.TEX.NO_HSCROLL asks for, grew a unit by
# the `&` and `\\` it added — and a dash standing alone between words is not a word (both found by PF,
# 2026-09-24).
function words(text::AbstractString)
    # the stand-in carries no spaces, so a formula and the punctuation on it stay one word, as they were
    t = replace(String(text), r"```math.*?```"s => "M", r"(?<!`)``(?!`).*?(?<!`)``(?!`)"s => "M",
                r"\\\[.*?\\\]"s => "M", r"(?<!\$)\$[^\$\n]+\$(?!\$)" => "M")
    return count(w -> !(w in ("—", "–", "-")), split(t))
end

"""
    units(root, files) -> Dict{String,NamedTuple}

Every unit of prose in the files, keyed by where it is: a docstring by its file and binding, a page
section by its file and heading. The arguments are `root`, the package root, and `files`, the paths to
read. Returns the units with their metrics.

A heading, a numbered top-level item and a bold lettered finding each open a new unit, which is what lets
an append-only document grow by NEW units rather than by swelling one. A key is where the unit is, never
its position among others of its name; two units that would still share one are listed in `collisions`
and the later is left out, since no number given to it would stay with it.
"""
function units(root::AbstractString, files, owners::Union{Nothing,Dict{String,String}} = nothing,
               collisions::Vector{String} = String[])
    out = Dict{String,NamedTuple}()
    note_owner!(key, f) = owners === nothing ? nothing : (owners[key] = f)
    # A file is named by its basename, which every recorded row uses — and by its path where two files
    # read share a basename, or their units would be one.
    shared = Set(b for b in basename.(files) if count(==(b), basename.(files)) > 1)
    label(f) = basename(f) in shared ? f : basename(f)
    # A key that already exists is a DIFFERENT unit with the same name. It used to take a positional
    # suffix, `(2)`, which moved to another unit whenever one of the same name was inserted above it —
    # silently re-pointing a baseline row. It is reported instead, and the author gives it a name.
    function add!(key, m, f)
        haskey(out, key) && (push!(collisions, key); return)
        out[key] = m; note_owner!(key, f)
    end
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
                add!("$(label(f)) :: $(first(isempty(sig) ? d.node : sig, 60))", metrics(d.text), f)
            end
        else
            # The heading is cut to sixty characters and the item or finding after it is kept whole:
            # cutting the joined text left `… / item ` for every item under a long heading, one key.
            section = "(preamble)"; tail = ""; heading = ""; buf = IOBuffer(); fenced = false
            flush!() = begin
                body = String(take!(buf))
                isempty(strip(body)) || add!("$(label(f)) § $(first(section, 60))$tail", metrics(body), f)
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
                    flush!(); heading = strip(replace(String(line), r"^#+" => "")); section = heading; tail = ""
                elseif (m = match(r"^(\d+)\. ", line)) !== nothing
                    # Keyed UNDER its heading. A document restarts its numbering in each section, so
                    # `item 1` occurs three times in one file here; keyed by the number alone they are
                    # one unit and two of the three are tracked by nothing. A positional suffix would
                    # also separate them, and would move every later one when an item is inserted —
                    # silently re-pointing the baseline rows. GBGPeriodicFields' own lint carries the
                    # heading for this reason, and it is the better answer.
                    flush!(); section = heading; tail = (isempty(heading) ? "" : " / ") * "item " * m.captures[1]
                    println(buf, line)
                elseif (m = match(r"^\*\*\(([a-z]{1,2})\) ", line)) !== nothing
                    flush!(); section = heading; tail = (isempty(heading) ? "" : " / ") * "finding (" * m.captures[1] * ")"
                    println(buf, line)
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
    allowance(n) -> Int

How many words a unit recorded at `n` may grow by inside a run: ten, or five percent of `n` where that
is more. The argument is `n`, the recorded count. Returns the allowance.

A fix that must ADD a qualifier to be correct was refused for one word, and paid for it by cutting
elsewhere; the first wording that fit read badly ([GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/)' finding 005, 2026-09-24). Outside
a run the ratchet is strict, and the close records what grew within the allowance [ruled 2026-09-26].
"""
allowance(n::Integer) = max(10, ceil(Int, 0.05 * n))

# Whether the check runs on behalf of an open run, which grants the allowance: `false` unless a verb that
# knows a run is open — `gbg docfix` — sets it for the length of its own call. Process-local and never
# read from disk, because a build's verdict may not depend on review state, and this rule read the run
# directory from inside every docs build until 2026-09-26.
const IN_RUN = Ref(false)

"""
    record_grown(root, cfg) -> Vector{String}

Re-records every unit that grew past its recorded numbers by no more than the [`allowance`](@ref),
and only those, leaving every other row as it was. The arguments are `root`, the package root, and
`cfg`, the package's config. Returns one line per unit re-recorded.

The close calls it: what a run's fixes grew within the allowance is written to the baseline with the
run's record, so the growth is deliberate and visible in one commit rather than refused at the next
build [ruled 2026-09-26]. Growth past it is the build's to refuse, never the close's to record.
"""
function record_grown(root::AbstractString, cfg)
    base = something(baseline(root), Dict{String,NTuple{3,Int}}())
    us = units(root, files_of(root, cfg))
    grown = String[]
    for k in sort!(collect(keys(us)))
        u = us[k]; key = csvkey(k); now = (u.words, u.longest, u.admonitions)
        b = get(base, key, nothing)
        (b !== nothing && any(now .> b)) || continue
        (now[1] <= b[1] + allowance(b[1]) && now[2] <= b[2] + allowance(b[2]) && now[3] <= b[3]) || continue
        base[key] = (max(now[1], b[1]), max(now[2], b[2]), max(now[3], b[3]))
        push!(grown, "$key: words $(b[1])→$(now[1]), longest paragraph $(b[2])→$(now[2])")
    end
    isempty(grown) && return grown
    path = joinpath(root, BASELINE)
    open(path, "w") do io
        println(io, "unit,words,longest_paragraph,admonitions")
        for k in sort!(collect(keys(base)))
            w, l, a = base[k]
            println(io, "\"", k, "\",", w, ",", l, ",", a)
        end
    end
    return grown
end

"""
    prose_shape(root, cfg) -> Vector{Model.Location}

Every unit of prose that breaks its cap or has grown past its recorded numbers, and every name two
units share. The arguments are `root`, the package root, and `cfg`, the package's config, which names
the files. Returns one location per unit.

A unit the baseline does not hold is NEW and is held to the caps; one it holds may fall and never rise,
except by the [`allowance`](@ref) while a run is open.
"""
function prose_shape(root::AbstractString, cfg)
    cat = parentmodule(@__MODULE__)
    files = files_of(root, cfg)
    base = baseline(root)
    slack = IN_RUN[] ? allowance : (n -> 0)
    out = Model.Location[]
    owners = Dict{String,String}()
    collisions = String[]
    us = units(root, files, owners, collisions)
    for key in unique(collisions)
        push!(out, Model.Location(; file = get(owners, key, ""), line = 0,
            text = "$key: two units share this name, and a number given to the second would move whenever one is inserted above it — give it a heading of its own"))
    end
    for (key, u) in sort!(collect(us))
        recorded = base === nothing ? nothing : get(base, csvkey(key), nothing)
        # The finding NAMES its file. It carried an empty one, so a per-file switch could never reach
        # this rule and a reader was left to find the unit from the key alone.
        where_ = get(owners, key, "")
        if recorded === nothing
            u.longest > PARAGRAPH_CAP && push!(out, Model.Location(; file = where_, line = 0,
                text = "$key: longest paragraph $(u.longest) > $PARAGRAPH_CAP words"))
            u.admonitions > ADMONITION_CAP && push!(out, Model.Location(; file = where_, line = 0,
                text = "$key: $(u.admonitions) admonitions > $ADMONITION_CAP"))
        elseif u.words > recorded[1] + slack(recorded[1]) || u.longest > recorded[2] + slack(recorded[2]) ||
               u.admonitions > recorded[3]
            push!(out, Model.Location(; file = where_, line = 0,
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
    for (dir, _, fs) in walkdir(root; onerror = _ -> nothing)
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
    write_baseline(root, cfg; only = "") -> Int

Writes the baseline from the prose as it stands and returns how many units it recorded. The arguments are:

- `root` — the package root.
- `cfg` — the package's config.
- `only` — a text the units to re-record must hold, every other row kept; empty to write them all.

It is called only by a person asking for it, with a reason — never by a check. A baseline a check could
rewrite is a ratchet that resets itself.
"""
function write_baseline(root::AbstractString, cfg; only::AbstractString = "")
    us = units(root, files_of(root, cfg))
    rows = Dict{String,NTuple{3,Int}}(csvkey(k) => (u.words, u.longest, u.admonitions) for (k, u) in us)
    # Named units only: every other row stays as it was, so a reviewer of the commit sees the one raise
    # that was meant and not a hundred rows lowered beside it (found by PF, 2026-09-24).
    if !isempty(only)
        kept = something(baseline(root), Dict{String,NTuple{3,Int}}())
        for (k, v) in rows
            occursin(only, k) && (kept[k] = v)
        end
        rows = kept
    end
    path = joinpath(root, BASELINE)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "unit,words,longest_paragraph,admonitions")
        for k in sort!(collect(keys(rows)))
            w, l, a = rows[k]
            println(io, "\"", k, "\",", w, ",", l, ",", a)
        end
    end
    return length(rows)
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
    # Per file set, and through the same expander every other rule uses. Reading the package's patterns
    # with `isfile` dropped every GLOB, and taking the fallback only when ALL THREE sets were silent
    # meant a package naming its rationale documents — the one thing this instruction asks it to do —
    # silently stopped this rule reading its code and its pages at all.
    for fs in (Model.FileSet.CODE, Model.FileSet.PAGES, Model.FileSet.RATIONALE)
        append!(files, Texts.files(cfg, root, fs))
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
            [Model.Location(; file = "docs/src/page.md", line = 0)], "a paragraph stays inside the cap"),
        Model.TreeExample(["docs/src/page.md" => "# A page\n\n" * join(fill("word", 40), " ") * "\n"],
            Model.Location[], "a paragraph stays inside the cap"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[SHAPE]

end # module Shape
