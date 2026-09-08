# Scan.jl — the ONE text-scan engine (ARCHITECTURE D8, §12.B). A scan is a function registered under its
# id; the catalogue (catalog/scans.toml) says which rule it enforces, its tier, the config surfaces it
# reads and its fixture classes. The engine resolves the surfaces, extracts the prose the same way for
# every scan, runs each scan, applies the ledger, and never truncates its output.

"""
    Hit(file, line, text; symbol = "")

One scan hit: the surface file (relative to the consumer root), the 1-based line (0 when the hit is
about a whole file) and the excerpt or message a reader needs; `symbol` names the owning binding when
the scan knows it, which is what a ledger entry's `symbol` predicate is matched against.
"""
struct Hit
    file::String
    line::Int
    text::String
    symbol::String
end
Hit(file, line, text; symbol = "") = Hit(String(file), Int(line), String(text), String(symbol))

"""
    ScanResult

The outcome of one scan: `id`, `rule`, the resolved `tier` (`hard` or `triage`; the `argcov_policy`
tier resolved from config), the surviving `hits`, the `population` the scan measured (files, docstrings,
exports, arguments or pages — zero means the scan measured nothing and is DEAD), the number of hits
the ledger `exempted`, and `note` for a scan-level message (an error, a dead-lane reason).
"""
struct ScanResult
    id::String
    rule::String
    tier::String
    hits::Vector{Hit}
    population::Int
    exempted::Int
    note::String
end

"""
    SCANS

The registry `id => function`. Every file under `src/Scans/` registers exactly one scan with
[`register_scan!`](@ref); `gbg selftest` fails when a registered id is absent from the catalogue or a
catalogued id has no function.
"""
const SCANS = Dict{String,Function}()

"""
    register_scan!(id, f)

Registers `f` as the scan `id`. The contract: `f(cfg, files)` receives the validated config and the
surface files (relative paths) the catalogue resolves for the scan, and returns `(hits::Vector{Hit},
population::Int)`; an HTML scan receives the built pages instead of source files. Returns `f`.
"""
function register_scan!(id::AbstractString, f::Function)
    haskey(SCANS, id) && error("scan $id registered twice")
    SCANS[String(id)] = f
end

"""
    scan_catalog() -> Vector{Dict}

The `[[scan]]` rows of `catalog/scans.toml` in the running copy, in file order. Returns the rows.
"""
scan_catalog() = TOML.parsefile(joinpath(pkgdir(GBGCodingTools), "catalog", "scans.toml"))["scan"]

"""
    AI_BANNER

The one AI-provenance banner every AI-written page carries verbatim (`RULE.DOC.AI_BANNER`): two lines
of Markdown, or the same two lines as `# ` comments in a Literate file.
"""
const AI_BANNER = ["!!! info \"Written by AI, not regularly reviewed\"",
                   "    This page is written by AI and is not reviewed regularly by a human."]

# ---- prose extraction: the one reader every text scan shares -----------------------------------------

"""
    ProseLine

One line of rendered prose from a surface: `n` its 1-based line number, `raw` the line as written,
`text` the line as a reader of the rendered page would see its markup (a Literate `# ` prefix stripped;
in a Julia docstring the doubled backslashes collapsed, so `\\\\alpha` in source reads `\\alpha`),
`indocstring` whether it came from a `\"\"\"` docstring, `comment` whether it is a `#`-leading line
inside prose (a Markdown heading in a docstring, or a stray comment — the house exemption skips
these in `.jl` surfaces).
"""
struct ProseLine
    n::Int
    raw::String
    text::String
    indocstring::Bool
    comment::Bool
end

"""
    surface_kind(cfg, file) -> Symbol

`:literate` for a file the `surfaces.literate` globs name, `:julia` for any other `.jl`, `:markdown`
otherwise. Returns the symbol.
"""
function surface_kind(cfg::AbstractDict, file::AbstractString)
    endswith(file, ".jl") || return :markdown
    for g in get(cfg["surfaces"], "literate", String[])
        occursin(Config.glob_to_regex(g), file) && return :literate
    end
    return :julia
end

"""
    prose_lines(cfg, file) -> Vector{ProseLine}

The rendered-prose lines of one surface file: a Markdown file outside its fenced blocks; a Julia file
only inside `\"\"\"` docstrings (a one-line `\"\"\"…\"\"\"` docstring is one prose line); a Literate
file's full-line `# ` comments with the marker stripped, outside fences. Fence lines themselves are
not returned. Returns the lines; an empty vector for a file with no prose.
"""
function prose_lines(cfg::AbstractDict, file::AbstractString)
    kind = surface_kind(cfg, file)
    out = ProseLine[]
    lines = readlines(joinpath(cfg["root"], file))
    indoc = kind != :julia
    infence = false
    for (n, raw) in enumerate(lines)
        line = raw
        if kind == :literate
            if startswith(raw, "# ")
                line = raw[3:end]
            elseif strip(raw) == "#"
                line = ""
            else
                continue
            end
        elseif kind == :julia
            s = strip(raw)
            c = count("\"\"\"", raw)
            if !indoc
                if c >= 2 && startswith(s, "\"\"\"")            # one-line docstring
                    inner = strip(s[4:end-3])
                    push!(out, ProseLine(n, raw, unescape_docstring(inner), true, startswith(inner, "#")))
                    continue
                elseif isodd(c) && startswith(s, "\"\"\"")       # opener (the design writes it alone on its line)
                    indoc = true
                    rest = strip(s[4:end])
                    isempty(rest) || push!(out, ProseLine(n, raw, unescape_docstring(rest), true, startswith(rest, "#")))
                    continue
                else
                    continue
                end
            elseif isodd(c)                                     # closer
                indoc = false; infence = false
                continue
            end
        end
        if startswith(strip(line), "```")
            infence = !infence
            continue
        end
        infence && continue
        text = kind == :julia ? unescape_docstring(line) : line
        push!(out, ProseLine(n, raw, text, kind == :julia, occursin(r"^\s*#", line)))
    end
    return out
end

"""
    unescape_docstring(line) -> String

The Julia string-literal reading of a docstring source line: `\\\\` becomes `\\` and `\\\$` becomes
`\$`. Other escapes are left as written — the swallowed-escape scan is what reports them. Returns the
string.
"""
unescape_docstring(line::AbstractString) = replace(String(line), "\\\\" => "\\", "\\\$" => "\$")

"""
    prose_text(cfg, file; history_cut = true) -> String

The whole prose of `file` as one string (the `text` of every prose line joined by newlines); with
`history_cut`, a file named by `surfaces.history_exempt` is cut at that heading, so the append-only
history is not scanned for currency. Returns the string.
"""
function prose_text(cfg::AbstractDict, file::AbstractString; history_cut::Bool = true)
    pl = prose_lines(cfg, file)
    if history_cut
        anchor = get(cfg["surfaces"], "history_exempt", "")
        afile, aline, _ = Config.resolve_anchor(cfg["root"], anchor)
        if afile == file && aline > 0
            pl = filter(p -> p.n < aline, pl)
        end
    end
    return join((p.text for p in pl), "\n")
end

"""
    regex_scan(cfg, files, re; skip_comments = true, on = :text, exclude = nothing) -> (hits, population)

The engine's plain-pattern scan: every prose line of every file matching `re` is a hit (the line as its
excerpt), `#`-leading lines in Julia surfaces skipped unless `skip_comments = false`, the match run
over the rendered `text` or the `raw` line per `on`, and a line for which `exclude(line)` is true
dropped. Returns the hits and the file count.
"""
function regex_scan(cfg::AbstractDict, files, re::Regex; skip_comments::Bool = true, on::Symbol = :text, exclude = nothing)
    hits = Hit[]
    for f in files
        for p in prose_lines(cfg, f)
            skip_comments && p.indocstring && p.comment && continue
            s = on == :raw ? p.raw : p.text
            occursin(re, s) || continue
            exclude !== nothing && exclude(s) && continue
            push!(hits, Hit(f, p.n, strip(s)))
        end
    end
    return (hits, length(files))
end

"""
    docstring_blocks(cfg, files) -> Vector

Every `\"\"\"` docstring of the Julia surfaces among `files`, as `(file, line, signature, body,
binding)` — `line` the opening delimiter's line, `signature` the first line of the body, `binding` the
name before the first `(` of the signature (or the bare word). Returns the vector; a Literate file
contributes none.
"""
function docstring_blocks(cfg::AbstractDict, files)
    out = NamedTuple[]
    for f in files
        surface_kind(cfg, f) == :julia || continue
        for d in Reflection.docstrings(cfg["root"], [f])
            sig = d.signature
            binding = String(strip(first(split(first(split(sig, '(')), ' '))))
            push!(out, (file = d.file, line = d.line, signature = sig, body = d.body, binding = binding))
        end
    end
    return out
end

# ---- the run --------------------------------------------------------------------------------------------

resolve_tier(cfg, tier) = tier == "argcov_policy" ?
    (cfg["instruments"]["check-docs"]["argcov_policy"] == "gate" ? "hard" : "triage") : tier

function resolve_surfaces(cfg::AbstractDict, keys_)
    files = String[]
    for k in keys_
        k == "built_html" && continue
        append!(files, Config.surface_files(cfg, k))
    end
    return sort!(unique!(files))
end

"""
    apply_ledger(cfg, ledger, row, hits) -> (kept, exempted, disabled)

Applies the ledger to one scan's hits: an entry `scope = "scan"` on the scan id, or `scope =
"policy"` on its rule with target `*`, disables the scan (every hit exempted, `disabled = true`); any
other live `scan`-scope entry on the id drops the hits it [`Ledger.matches`](@ref). A text scan meets
an `arg_type` predicate as an error. Returns the kept hits, the exempted count and the flag.
"""
function apply_ledger(cfg::AbstractDict, ledger, row, hits::Vector{Hit})
    id = row["id"]; rule = row["rule"]
    for e in Ledger.entries(ledger, rule; scope = "policy")
        e["target"] == "*" && return (Hit[], length(hits), true)
    end
    scan_entries = Ledger.entries(ledger, id; scope = "scan")
    isempty(scan_entries) && return (hits, 0, false)
    any(e -> e["target"] == "*" && !haskey(e, "match"), scan_entries) && return (Hit[], length(hits), true)
    reflection = id in ("SCAN.ARGCOV", "SCAN.SIGNATURE_FIDELITY")
    kept = Hit[]
    for h in hits
        covered = any(scan_entries) do e
            reflection || !haskey(get(e, "match", Dict()), "arg_type") ||
                throw(Ledger.LedgerError("$(e["id"]) on $(e["target"]) carries match.arg_type; $id is a text scan and cannot evaluate it"))
            Ledger.matches(e, cfg["root"]; file = h.file, symbol = h.symbol, arg_type = reflection ? Any : nothing)
        end
        covered || push!(kept, h)
    end
    return (kept, length(hits) - length(kept), false)
end

"""
    run_scan(cfg, row; ledger, files = nothing) -> ScanResult

Runs the catalogued scan `row` over its resolved surfaces (or `files`), applies the ledger and returns
the result. A scan function that throws yields a result with an empty population and the error as
`note`, so a broken scan reads DEAD rather than clean.
"""
function run_scan(cfg::AbstractDict, row::AbstractDict; ledger = Ledger.read(cfg), files = nothing)
    id = row["id"]; tier = resolve_tier(cfg, row["tier"])
    f = get(SCANS, id, nothing)
    f === nothing && return ScanResult(id, row["rule"], tier, Hit[], 0, 0, "no scan function registered for $id")
    files = files === nothing ? resolve_surfaces(cfg, row["surfaces"]) : files
    hits, population, note = try
        h, p = f(cfg, files)
        (h, p, "")
    catch err
        err isa Ledger.LedgerError && rethrow()
        (Hit[], 0, "scan raised: " * sprint(showerror, err))
    end
    kept, exempted, disabled = apply_ledger(cfg, ledger, row, hits)
    disabled && (note = isempty(note) ? "disabled by the ledger" : note)
    return ScanResult(id, row["rule"], tier, kept, population, exempted, note)
end

function custom_rows(cfg::AbstractDict)
    rows = Dict{String,Any}[]
    for c in get(get(cfg, "scans", Dict()), "custom", Any[])
        id = "SCAN.CUSTOM." * c["id"]
        haskey(SCANS, id) || register_scan!(id, (cfg2, files) -> regex_scan(cfg2, files, Regex(c["pattern"])))
        push!(rows, Dict("id" => id, "rule" => "CUSTOM", "tier" => "triage", "surfaces" => c["surfaces"], "runner" => "julia", "fixture" => String[]))
    end
    return rows
end

"""
    scan_docs(cfg; hard_only = false, only = nothing, io = stdout) -> (results, code)

Runs every catalogued text scan (and the consumer's `[[scans.custom]]` rows) over the source surfaces
and prints the full report: every hard hit and every triage hit, never truncated. The exit `code`
follows the contract: 2 when any scan is DEAD (measured nothing, or raised), else 1 when any hard scan
has a hit, else 0; triage hits never change it. `hard_only` runs the hard tier alone (what `makedocs`
calls); `only` restricts to the ids (or id prefixes) given. Returns the results and the code.
"""
function scan_docs(cfg::AbstractDict; hard_only::Bool = false, only = nothing, io::IO = stdout)
    ledger = Ledger.read(cfg)
    rows = vcat(scan_catalog(), custom_rows(cfg))
    results = ScanResult[]
    for row in rows
        get(row, "runner", "julia") == "html" && continue
        tier = resolve_tier(cfg, row["tier"])
        hard_only && tier != "hard" && continue
        only === nothing || any(o -> row["id"] == o || startswith(row["id"], o * "."), only) || continue
        push!(results, run_scan(cfg, row; ledger))
    end
    return (results, report(results; io))
end

"""
    report(results; io = stdout) -> Int

Prints the scan report — the MUST BE EMPTY block, then TRIAGE — with every hit on its own line, and
returns the exit code (2 dead, 1 hard hits, 0 clean).
"""
function report(results::AbstractVector{ScanResult}; io::IO = stdout)
    code = 0
    hard = filter(r -> r.tier == "hard", results); triage = filter(r -> r.tier != "hard", results)
    isempty(hard) || println(io, "=== MUST BE EMPTY ===")
    for r in hard
        if r.population == 0 && r.exempted == 0
            println(io, "  DEAD  ", rpad(r.id, 30), " measured nothing", isempty(r.note) ? "" : " — " * r.note)
            code = 2
        elseif !isempty(r.hits)
            println(io, "  FAIL  ", rpad(r.id, 30), " ", length(r.hits), " hit(s)", r.exempted > 0 ? " ($(r.exempted) exempted)" : "")
            for h in r.hits; println(io, "          ", format_hit(h)); end
            code = max(code, 1)
        else
            println(io, "  ok    ", rpad(r.id, 30), " (", r.population, r.exempted > 0 ? "; $(r.exempted) exempted" : "",
                    isempty(r.note) ? "" : "; " * r.note, ")")
        end
    end
    isempty(triage) || println(io, "\n=== TRIAGE (heuristics — read every line; a count is not a verdict) ===")
    for r in triage
        if r.population == 0 && r.exempted == 0
            println(io, "  DEAD  ", rpad(r.id, 30), " measured nothing", isempty(r.note) ? "" : " — " * r.note)
            code = 2
            continue
        end
        println(io, "  ", lpad(length(r.hits), 4), "  ", r.id, r.exempted > 0 ? " ($(r.exempted) exempted)" : "")
        for h in r.hits; println(io, "          ", format_hit(h)); end
    end
    return code
end

format_hit(h::Hit) = h.line > 0 ? "$(h.file):$(h.line): $(h.text)" : "$(h.file): $(h.text)"

# ---- the built site -------------------------------------------------------------------------------------

"""
    built_pages(build_dir) -> Vector{String}

Every `index.html` under `build_dir` outside `search/` and `assets/`, sorted. Returns the paths.
"""
function built_pages(build_dir::AbstractString)
    pages = String[]
    for (dir, _, files) in walkdir(build_dir)
        "index.html" in files || continue
        rel = relpath(dir, build_dir)
        first(splitpath(rel)) in ("search", "assets") && continue
        push!(pages, joinpath(dir, "index.html"))
    end
    return sort!(pages)
end

"""
    scan_html(cfg, build_dir; only = nothing, io = stdout) -> (results, code)

Runs the built-HTML scans (`runner = "html"`) over the pages under `build_dir` through the Gumbo
walker, applies the ledger, prints the report and returns the results and the exit code, as
[`scan_docs`](@ref) does. A missing or empty build is DEAD, exit 2. `SCAN.HTML_PUBLIC_HOME` reads
`.gbg/scratch/public_surface.json`, which [`write_public_surface`](@ref) writes before the build.
"""
function scan_html(cfg::AbstractDict, build_dir::AbstractString; only = nothing, io::IO = stdout)
    ledger = Ledger.read(cfg)
    pages = isdir(build_dir) ? built_pages(build_dir) : String[]
    results = ScanResult[]
    for row in scan_catalog()
        row["runner"] == "html" || continue
        only === nothing || any(o -> row["id"] == o || startswith(row["id"], o * "."), only) || continue
        push!(results, run_scan(cfg, row; ledger, files = pages))
    end
    return (results, report(results; io))
end

"""
    write_public_surface(cfg; pkg = Reflection.load_package(cfg)) -> String

Writes `.gbg/scratch/public_surface.json`: the package's exported names and the public operations
`Reflection.package_operations` derives (every function with a method in a package module), so the
built-HTML scan `SCAN.HTML_PUBLIC_HOME` can ask whether each has a public home. Returns the path.
"""
function write_public_surface(cfg::AbstractDict; pkg::Module = Reflection.load_package(cfg))
    mods = Reflection.package_modules(pkg, cfg)
    ops = sort!(String.(collect(Reflection.package_operations(pkg, mods))))
    exports = sort!(String.(filter(n -> n != nameof(pkg), names(pkg))))
    dir = joinpath(cfg["root"], ".gbg", "scratch"); mkpath(dir)
    path = joinpath(dir, "public_surface.json")
    open(path, "w") do io
        JSON3.pretty(io, JSON3.write(Dict("schema_version" => 1, "package" => cfg["package"]["name"],
                                           "operations" => ops, "exports" => exports)))
        println(io)
    end
    return path
end

"""
    cmd_scan(args) -> Int

`gbg scan docs [--hard-only] [--only id,…] [--rebaseline prose-shape --reason "…"]` and
`gbg scan html <build_dir>`: the CLI face of [`scan_docs`](@ref) and [`scan_html`](@ref). Returns the
scan exit code; a rebaseline writes `docs/prose_shape.csv` and returns 0.
"""
function cmd_scan(args)
    o = parse_options(args; valued = ["only", "rebaseline", "reason"])
    isempty(o.positional) && (println(stderr, "usage: gbg scan docs|html …"); return 2)
    cfg = Config.read()
    only = haskey(o.values, "only") ? String.(split(o.values["only"], ',')) : nothing
    if o.positional[1] == "docs"
        if haskey(o.values, "rebaseline")
            o.values["rebaseline"] == "prose-shape" || (println(stderr, "only --rebaseline prose-shape exists"); return 2)
            haskey(o.values, "reason") && length(o.values["reason"]) >= 12 ||
                (println(stderr, "--rebaseline needs --reason \"…\" (≥ 12 characters); the reason goes in the commit"); return 2)
            n = write_prose_shape_baseline(cfg)
            println("prose-shape baseline WRITTEN: $n units → $(PROSE_SHAPE_BASELINE) (reason: $(o.values["reason"]))")
            return 0
        end
        _, code = scan_docs(cfg; hard_only = "hard-only" in o.flags, only)
        return code
    elseif o.positional[1] == "html"
        length(o.positional) >= 2 || (println(stderr, "usage: gbg scan html <build_dir>"); return 2)
        _, code = scan_html(cfg, o.positional[2]; only)
        return code
    end
    println(stderr, "unknown scan target $(o.positional[1]); docs or html"); return 2
end
VERBS["scan"] = cmd_scan

for f in sort!(filter!(x -> endswith(x, ".jl"), readdir(joinpath(@__DIR__, "Scans"))))
    include(joinpath(@__DIR__, "Scans", f))
end
