# Init.jl — `gbg init [--migrate] [--dry-run]`, `gbg migrate baselines`, `gbg new <Pkg>`: the consumer's
# `.gbg/` and the seeded-once files seeded from the package tree (ARCHITECTURE §4, §5; IMPLEMENTATION 1.3).

"""
    Init

Seeds a consumer: [`Init.derive_config`](@ref) reads the package tree into a config that validates,
[`Init.init`](@ref) writes `.gbg/` and the seeded-once files and renders the tool's entries into every
sub-environment, [`Init.migrate_baselines`](@ref) converts the three Julia test literals to their TOML
form textually, [`Init.migrate_seeds`](@ref) converts a former `seed_defects.py` catalogue, and
[`Init.new`](@ref) adds a fifth package. `init` never renders the generated files (the skill stubs,
the hook, the CI fragments, the managed blocks): that is `gbg sync`, which validates what `init` wrote.
"""
module Init

using TOML, Dates
using ..GBGCodingTools: GBGCodingTools, PKG_NAME, Config, Sync, parse_options, VERBS, load_schema, validate, materialize!
using ..GBGCodingTools: write_prose_shape_baseline, AI_BANNER

struct InitError <: Exception
    msg::String
end
Base.showerror(io::IO, e::InitError) = print(io, "init: ", e.msg)

const GENERIC_HATS = ["consistency-matrix", "software-architect", "structure-consistency", "latex-typesetter",
                      "api-user", "citations-integrity", "style-editor", "cold-reader"]

"""
    is_tool_root(root) -> Bool

Whether `root` is the tool repository itself (its `Project.toml` names `GBGCodingTools`). Returns the
boolean.
"""
function is_tool_root(root::AbstractString)
    p = joinpath(root, "Project.toml")
    isfile(p) || return false
    return get(TOML.parsefile(p), "name", "") == PKG_NAME
end

"""
    enclosed_by_tool(root) -> Bool

Whether `root` lies inside the tool repository (the fixture does), which is where pinning at the
literal `dev` is legal besides the tool root itself. Returns the boolean.
"""
enclosed_by_tool(root::AbstractString) = startswith(abspath(root), abspath(Sync.tool_root()) * "/")

first_heading(path, re) = (isfile(path) || return nothing;
    for l in eachline(path)
        m = match(r"^#{1,6}\s+(.*?)\s*$", l)
        m !== nothing && occursin(re, m.captures[1]) && return String(m.captures[1])
    end; nothing)

function module_names(root, pkgname)
    names = String[]
    for (dir, _, files) in walkdir(joinpath(root, "src")), f in files
        endswith(f, ".jl") || continue
        for m in eachmatch(r"^\s*(?:bare)?module\s+([A-Za-z_][A-Za-z0-9_]*)"m, read(joinpath(dir, f), String))
            n = m.captures[1]
            n == pkgname || n in names || push!(names, n)
        end
    end
    return names
end

function guard_symbols(root)
    out = String[]
    for (dir, _, files) in walkdir(joinpath(root, "src")), f in files
        endswith(f, ".jl") || continue
        for m in eachmatch(r"^function\s+(_check_[A-Za-z0-9_]+)"m, read(joinpath(dir, f), String))
            m.captures[1] in out || push!(out, m.captures[1])
        end
    end
    return sort!(out)
end

function literate_files(root)
    out = String[]
    ex = joinpath(root, "examples"); isdir(ex) || return out
    for (dir, _, files) in walkdir(ex), f in files
        endswith(f, ".jl") || continue
        text = read(joinpath(dir, f), String)
        (occursin("# " * AI_BANNER[1], text) || occursin(r"^# #"m, text) || occursin(r"^# [A-Z][a-z]+ [a-z]+ [a-z]+"m, text)) &&
            push!(out, relpath(joinpath(dir, f), root))
    end
    return sort!(out)
end

"""
    derive_config(root) -> Dict

The best config the package tree supports (ARCHITECTURE §5): name and description from
`Project.toml`, modules from the `module` declarations under `src/`, the surfaces that exist, the
history and references anchors found by heading, the executable claims and guard symbols present,
one bug-hunt territory per source file, the eight generic hats. The tool root gets its own delta
(§5.6); a tree inside the tool repository is pinned `dev`. The result validates against the schema
with defaults materialised; a value the tree cannot supply is written with a `TODO` the doctor will
flag, never invented. Returns the config (without `root`).
"""
function derive_config(root::AbstractString)
    root = abspath(root)
    proj = TOML.parsefile(joinpath(root, "Project.toml"))
    name = String(proj["name"])
    tool = is_tool_root(root); inside = enclosed_by_tool(root)
    # the pinned version: `dev` at the tool root and inside the tool repository (the fixture); elsewhere the version
    # the running copy IS — its Project.toml — which `gbg release` tags before a consumer adopts it
    version = tool || inside ? "dev" : String(TOML.parsefile(joinpath(Sync.tool_root(), "Project.toml"))["version"])
    arch = joinpath(root, "docs", "ARCHITECTURE.md")
    rationale = [relpath(joinpath(root, "docs", f), root) for f in ("ARCHITECTURE.md", "FORMALIZATION.md", "TESTING.md", "PERFORMANCE.md") if isfile(joinpath(root, "docs", f))]
    generated = [relpath(joinpath(root, "docs", "src", lowercase(basename(f))), root) for f in rationale if isfile(joinpath(root, "docs", "src", lowercase(basename(f))))]
    isdir(joinpath(root, "docs", "src", "examples")) && push!(generated, "docs/src/examples/*.md")
    hist = first_heading(arch, r"Decision log|Decisions|Revision history"i)
    refs = first_heading(arch, r"^References"i)
    core = first_heading(joinpath(root, "CLAUDE.md"), r"^Core invariants"i)
    style = first_heading(joinpath(root, "CLAUDE.md"), r"^(Style|Code generation rules)"i)
    modules = module_names(root, name)
    srcfiles = sort!([relpath(joinpath(d, f), root) for (d, _, fs) in walkdir(joinpath(root, "src")) for f in fs if endswith(f, ".jl")])
    claims = Dict{String,Any}(k => "test/$f" for (k, f) in (("allocation", "allocations.jl"), ("traffic", "pass_audit.jl"), ("method_set", "method_parity.jl")) if isfile(joinpath(root, "test", f)))
    cfg = Dict{String,Any}(
        "tool" => Dict("version" => version, "schema" => 1),
        "package" => Dict{String,Any}(
            "name" => name,
            "description" => tool ? "The one shared tooling package of the GBG Julia packages: review instruments, docs-build wrapper and scans, test harness, doctor and policy prose, at one version pinned by every consumer." :
                                    "TODO: one-sentence description of $name (at least 20 characters; written at migration)",
            "modules" => tool ? ["Config", "TestHarness", "Reflection", "Witnesses", "Sync", "Init", "Ledger", "HtmlWalker", "TreeHash"] : (isempty(modules) ? [name] : modules),
            "extensions" => sort!([relpath(joinpath(root, "ext", f), root) for f in (isdir(joinpath(root, "ext")) ? readdir(joinpath(root, "ext")) : String[]) if endswith(f, ".jl")]),
            "deliberate_absences" => tool ? ["no layering in config", "no consumer copies in the tool", "no Python"] : String[],
            "terms" => tool ? ["consumer", "instrument", "round", "lane", "hat", "anchor", "gate", "pin", "managed file", "ledger"] : String[],
            "domain" => tool ? "review tooling" : "TODO: the package's field",
            "rulebook_sections" => tool ? ["docs/ARCHITECTURE.md#§0", "docs/ARCHITECTURE.md#§5.5", "CLAUDE.md#Release checklist"] :
                                   filter(!isempty, [core === nothing ? "" : "CLAUDE.md#" * core, style === nothing ? "" : "CLAUDE.md#" * style, hist === nothing ? "" : "docs/ARCHITECTURE.md#" * hist]),
            "julia_test" => "julia --project -e 'using Pkg; Pkg.test()'",
            "docs_build" => "julia --project=docs docs/make.jl",
            "docs_post" => String[]),
        "paths" => tool ? Dict("instruments" => "instruments", "catalog" => "catalog", "policy" => "policy", "schema" => "schema", "templates" => "templates", "fixture" => "fixture") :
                          Dict{String,Any}(k => k for k in ("examples", "benchmark") if isdir(joinpath(root, k))),
        "git" => Dict("branch" => "master"),
        "surfaces" => Dict{String,Any}(
            "rationale" => tool ? ["docs/ARCHITECTURE.md"] : rationale,
            "pages" => ["docs/src/**/*.md"],
            "generated" => Dict("globs" => tool ? ["docs/src/architecture.md", "docs/src/guide/verbs.md", "docs/src/guide/doctor.md"] : generated, "optional" => true),
            "src" => tool ? ["src/**/*.jl"] : (any(f -> count(==('/'), f) > 1, srcfiles) ? ["src/*.jl", "src/*/*.jl"] : ["src/*.jl"]),
            "ext" => isdir(joinpath(root, "ext")) ? ["ext/*.jl"] : String[],
            "literate" => tool ? String[] : literate_files(root),
            "built_html" => "docs/build",
            "history_exempt" => tool ? "docs/ARCHITECTURE.md#Revision history" : "docs/ARCHITECTURE.md#" * something(hist, "TODO: the append-only history heading"),
            "references_heading" => refs === nothing ? "absent" : "docs/ARCHITECTURE.md#" * refs),
        "docs" => Dict{String,Any}("doctest" => true, "admonition_titles" => "always",
                                   "unexported_base_expected" => tool ? ["showerror", "getindex", "setindex!", "size", "parent"] : String[], "retired_claims" => Any[]),
        "rubric" => Dict("leading_identity" => "physical-meaning"),
        "notation" => Dict("vectors" => tool ? "none" : "component", "mathbf_allowed" => tool ? String[] : ["\\mathbf{1}"]),
        "citations" => Dict("require_doi" => true),
        "instruments" => Dict{String,Any}(
            "enabled" => ["check-docs", "check-consistency", "bug-hunt", "audit-changes"],
            "check-docs" => Dict("argcov_policy" => tool ? "gate" : "triage", "lanes_extra" => Any[]),
            "check-consistency" => Dict{String,Any}(
                "profile" => "all",
                "hats" => tool ? vcat(GENERIC_HATS, ["tooling-maintainer"]) : GENERIC_HATS,
                "core" => tool ? ["consistency-matrix", "cold-reader", "tooling-maintainer"] : ["consistency-matrix", "cold-reader"],
                "seed_rounds" => false,
                "seed_catalog" => ".gbg/seeds.toml",
                "design_docs_withheld" => tool ? ["architecture"] : [lowercase(splitext(basename(f))[1]) for f in rationale],
                "latex_source_globs" => String[],
                "domain_hats" => tool ? [Dict("key" => "tooling-maintainer", "anchor" => true, "substrate" => "full")] : Any[]),
            "bug-hunt" => Dict{String,Any}(
                "territories" => tool ? [Dict("key" => "cli", "files" => ["src/CLI/*.jl"], "brief" => "the verbs, config, schema, sync, init, ledger"),
                                         Dict("key" => "scans", "files" => ["src/Scan.jl", "src/Scans/*.jl"], "brief" => "the scan engine and its scans"),
                                         Dict("key" => "harness", "files" => ["src/TestHarness.jl", "src/Reflection.jl", "src/Witnesses.jl"], "brief" => "the Julia-side engines"),
                                         Dict("key" => "core", "files" => ["src/TreeHash.jl", "src/HtmlWalker.jl", "src/DocLints.jl", "ext/GBGCodingToolsDocumenterExt.jl"], "brief" => "hashing, the HTML walker, the wrapper")] :
                                        [Dict("key" => lowercase(splitext(basename(f))[1]), "files" => [f], "brief" => "TODO: what this file owns") for f in srcfiles if basename(f) != name * ".jl"],
                "oracles" => tool ? ["the fixture's defects.toml", "the exit contract", "git's own tree hash", "the documented definition over raw files"] : ["the documented definition over raw arrays"],
                "witness_env" => "test"),
            "audit-changes" => Dict{String,Any}("executable_claims" => tool ? Dict{String,Any}() : claims, "guard_symbols" => tool ? String[] : guard_symbols(root),
                                                 (tool ? ["invariants_section" => "docs/ARCHITECTURE.md#§5.5"] : (core === nothing ? [] : ["invariants_section" => "CLAUDE.md#" * core]))...)),
        "cost" => Dict("default" => "economy"),
        "schema" => Dict("finding_types_extra" => String[]),
        "scans" => Dict("custom" => Any[]))
    if !isdir(joinpath(root, "docs", "src")) && !tool
        cfg["surfaces"]["pages"] = String[]
    end
    schema = load_schema("config")
    errs = validate(schema, cfg)
    isempty(errs) || throw(InitError("the derived config does not validate — a tool defect:\n  " * join(errs, "\n  ")))
    materialize!(schema, cfg)
    return cfg
end

const CONFIG_HEADER = """
# .gbg/config.toml — {name}.  Schema: schema/config.schema.json in the pinned tool (closed keys: an
# unknown key, a missing required key, an unknown enum member or a path that does not exist is exit 2).
# Written by `gbg init` on {date} from the package tree; every default is materialised, nothing is
# layered on top of this file. A `TODO` value is a fact the tree could not supply — `gbg doctor`
# (CFG.SURFACES, CFG.HATS) reports it until it is written.
"""

"""
    write_config(root, cfg) -> String

Writes `.gbg/config.toml` (header comment + the config in TOML) and returns the text.
"""
function write_config(root::AbstractString, cfg::AbstractDict)
    c = Dict{String,Any}(k => v for (k, v) in cfg if k != "root")
    io = IOBuffer()
    print(io, replace(CONFIG_HEADER, "{name}" => c["package"]["name"], "{date}" => string(today())))
    println(io)
    TOML.print(io, c; sorted = true, by = k -> (findfirst(==(k), ["tool", "package", "paths", "git", "surfaces", "docs", "rubric", "notation", "citations", "instruments", "cost", "schema", "scans"]) === nothing ? 100 : findfirst(==(k), ["tool", "package", "paths", "git", "surfaces", "docs", "rubric", "notation", "citations", "instruments", "cost", "schema", "scans"]), k))
    text = String(take!(io))
    p = joinpath(root, ".gbg", "config.toml"); mkpath(dirname(p)); write(p, text)
    return text
end

const LEDGER_HEADER = """
# .gbg/exemptions.toml — the one ledger (ARCHITECTURE §7.2). One [[exemption]] per waiver or adjudication:
# id (a RULE.* rule, a SCAN.* scan, a doctor check, a finding id <round>/<lane>#<n>, or a harness op),
# scope (policy | scan | lint | check | finding | harness), target, reason (≥ 40 characters), recorded,
# and expires (≤ recorded + 365 d) — or overturn_when instead of expires on scope finding. An optional
# [exemption.match] table (arg_name, arg_type, path, symbol) REFINES a scan|lint|policy|harness entry.
# Empty until a rule needs a reason here; `gbg doctor` validates every entry (CFG.EXEMPTIONS).
"""

"""
    init(root = pwd(); migrate = false, dry_run = false, io = stdout) -> Int

`gbg init [--migrate] [--dry-run]`: seeds a consumer. The arguments are:

- `root` — the package root (the directory holding `Project.toml`).
- `migrate` — also convert the test baselines and a former `seed_defects.py`, and write
  `.gbg/scratch/commit-message.txt` for the migration commit.
- `dry_run` — print what would be written, write nothing.
- `io` — where the report goes.

It writes `.gbg/config.toml` from the tree, an empty ledger, `.gbg/rounds/.keep`, a placeholder persona
for every domain hat without one ([`Preflight.resolve_hats`](@ref) binds the term), the seeded-once files that are absent (`test/Project.toml`,
`docs/make.jl`, `test/runtests.jl`, `test/regressions/`, `docs/ROADMAP.md`, `docs/prose_shape.csv`),
and the tool's entries into `docs/`, `test/` and every sub-environment that lists the tool. It refuses
an existing `.gbg/config.toml` (exit 2). Returns the exit code.
"""
function init(root::AbstractString = pwd(); migrate::Bool = false, dry_run::Bool = false, io::IO = stdout)
    root = abspath(root)
    isfile(joinpath(root, "Project.toml")) || (println(io, "init: no Project.toml at $root — run it at a package root"); return 2)
    cfgpath = joinpath(root, ".gbg", "config.toml")
    isfile(cfgpath) && !dry_run && (println(io, "init: $cfgpath exists; init never overwrites a config (edit it, or remove it first)"); return 2)
    cfg = derive_config(root)
    cfg["root"] = root
    writes = String[]
    note(p) = push!(writes, p)
    note(".gbg/config.toml")
    note(".gbg/exemptions.toml"); note(".gbg/rounds/.keep")
    for h in cfg["instruments"]["check-consistency"]["domain_hats"]
        note(".gbg/hats/$(h["key"]).toml (placeholder persona)")
    end
    isfile(joinpath(root, "test", "Project.toml")) || note("test/Project.toml (seed)")
    isfile(joinpath(root, "docs", "make.jl")) || note("docs/make.jl (seed)")
    isfile(joinpath(root, "test", "runtests.jl")) || note("test/runtests.jl (seed)")
    isdir(joinpath(root, "test", "regressions")) || note("test/regressions/")
    isfile(joinpath(root, "docs", "ROADMAP.md")) || note("docs/ROADMAP.md (seed)")
    isfile(joinpath(root, "docs", "prose_shape.csv")) || note("docs/prose_shape.csv (baseline)")
    envs = unique(vcat([e for e in ("docs", "test") if isdir(joinpath(root, e))], GBGCodingTools.tool_sub_envs(root)))
    for e in envs; note("$e/Project.toml ([deps]/[sources]/[compat] $PKG_NAME)"); end
    migrate && (note("test/*_baseline.toml, test/oracle_registry.toml (migrate baselines, where the literals exist)"); note(".gbg/seeds.toml (from seed_defects.py, where it exists)"); note(".gbg/scratch/commit-message.txt"))
    if dry_run
        println(io, "init --dry-run: would write"); for w in writes; println(io, "  ", w); end
        println(io, "\n# .gbg/config.toml would be:\n"); TOML.print(io, Dict{String,Any}(k => v for (k, v) in cfg if k != "root"); sorted = true)
        return 0
    end
    write_config(root, cfg)
    write(joinpath(root, ".gbg", "exemptions.toml"), LEDGER_HEADER)
    mkpath(joinpath(root, ".gbg", "rounds")); touch(joinpath(root, ".gbg", "rounds", ".keep"))
    mkpath(joinpath(root, ".gbg", "hats"))
    for h in cfg["instruments"]["check-consistency"]["domain_hats"]
        p = joinpath(root, ".gbg", "hats", h["key"] * ".toml")
        isfile(p) && continue
        write(p, """
        # .gbg/hats/$(h["key"]).toml — a domain hat of $(cfg["package"]["name"]) (schema/hat.schema.json). The persona is
        # this package's own; write it, then remove this line. Placeholders {package.domain}, {package.terms},
        # {package.deliberate_absences} are substituted by preflight.
        key = "$(h["key"])"
        role = "TODO: what this hat reads the docs as, in one clause"
        substrate = "$(h["substrate"])"
        needs = []
        anchor = $(h["anchor"])
        domain = true
        persona = '''TODO: the persona, at least 80 characters — who this reader is, what they hold the text to, and what class of defect only they see.'''
        """)
    end
    s = Sync.slots(cfg)
    tp = joinpath(root, "test", "Project.toml")
    if !isfile(tp)
        mkpath(dirname(tp))
        # the tool as its own consumer: the package under test IS the tool, so its test environment lists
        # neither a tool entry nor a pin — Pkg.test provides the package itself
        text = cfg["package"]["name"] == PKG_NAME ? "[deps]\nTest = \"8dfed614-e22c-5e08-85e1-65c5234f0b40\"\n" :
               Sync.render(Sync.template("test-Project.toml.seed"), s)
        write(tp, text)
    end
    mkpath(joinpath(root, "test", "regressions"))
    for (path, tmpl) in ((joinpath("docs", "make.jl"), "make.jl.seed"), (joinpath("test", "runtests.jl"), "runtests.jl.seed"))
        p = joinpath(root, path)
        isfile(p) || (mkpath(dirname(p)); write(p, Sync.render(Sync.template(tmpl), s)))
    end
    rm_ = joinpath(root, "docs", "ROADMAP.md")
    isfile(rm_) || (mkpath(dirname(rm_)); write(rm_, "# Roadmap — $(cfg["package"]["name"])\n\nLive plans and open directions, one section per theme; finished work is deleted (git history keeps it).\nThis file is not a scan surface. `CLAUDE.md`'s \"Current state\" paragraph points here.\n"))
    for e in envs
        text, changed = Sync.render_project(cfg, e)
        changed && (mkpath(joinpath(root, e)); write(joinpath(root, e, "Project.toml"), text))
    end
    isfile(joinpath(root, "docs", "prose_shape.csv")) || (n = write_prose_shape_baseline(cfg); println(io, "  prose-shape baseline: $n units"))
    if migrate
        migrate_baselines(root; io)
        migrate_seeds(root, cfg; io)
        mkpath(joinpath(root, ".gbg", "scratch"))
        msg = Sync.render(Sync.template("commit-message.tmpl"), merge(s, Dict("files" => join("- " .* writes, "\n"))))
        write(joinpath(root, ".gbg", "scratch", "commit-message.txt"), msg)
    end
    for w in writes; println(io, "  wrote ", w); end
    println(io, "init: .gbg/ seeded for $(cfg["package"]["name"]), pinned at $(cfg["tool"]["version"]). Next: `julia --project=docs -e 'using Pkg; Pkg.instantiate()'` (and test/), then `gbg sync`.")
    return 0
end

# ---- migrate baselines -------------------------------------------------------------------------------------

"""
    balanced_span(text, start) -> UnitRange

The range of the parenthesised expression opening at `start` (a `(`), through its matching `)`,
skipping string literals and `#` comments. Throws an `InitError` when the parenthesis never closes.
"""
function balanced_span(text::AbstractString, start::Int)
    depth = 0; i = start; instr = false
    while i <= lastindex(text)
        c = text[i]
        if instr
            c == '\\' && (i = nextind(text, i))
            c == '"' && (instr = false)
        elseif c == '"'
            instr = true
        elseif c == '#'
            j = findnext('\n', text, i); i = j === nothing ? lastindex(text) : j
        elseif c == '('
            depth += 1
        elseif c == ')'
            depth -= 1
            depth == 0 && return start:i
        end
        i = nextind(text, i)
    end
    line = count(==('\n'), text[1:start]) + 1
    throw(InitError("a literal opened at line $line never closes its parenthesis"))
end

trailing_comment(text, i) = (j = findnext('\n', text, i); seg = text[i:(j === nothing ? lastindex(text) : prevind(text, j))];
    m = match(r"#\s*(.*)$", seg); m === nothing ? "" : String(strip(m.captures[1])))

"""
    convert_method_parity(text) -> Union{Dict,Nothing}

`test/method_parity.jl` → the `[[generic]] set, name, count, module` rows (every `baseline = ((…), …)`
tuple of a `@testset`, keyed by the testset name; the module is the enclosing module of the tested
generic and is written as the package's first module until the session names it) and the `[module]`
table from `const MODULE_BASELINE = (…)`, a `#` comment beside a count kept as `reason`. Returns the
document or `nothing` when the file holds no such literal.
"""
function convert_method_parity(text::AbstractString, modules)
    generics = Any[]; found = false
    for m in eachmatch(r"@testset\s+\"([^\"]+)\"\s+begin\s*\n\s*baseline\s*=\s*\(", text)
        found = true
        set = m.captures[1]
        span = balanced_span(text, m.offset + ncodeunits(m.match) - 1)
        body = text[span]
        for t in eachmatch(r"\(\s*\"([^\"]+)\"\s*,\s*[^,()]+?\s*,\s*(\d+)\s*\)", body)
            push!(generics, Dict("set" => set, "name" => t.captures[1], "count" => parse(Int, t.captures[2]),
                                 "module" => isempty(modules) ? "TODO" : first(modules)))
        end
    end
    modtable = Dict{String,Any}(); reasons = Dict{String,Any}()
    mm = match(r"const\s+MODULE_BASELINE\s*=\s*\(", text)
    if mm !== nothing
        found = true
        span = balanced_span(text, mm.offset + ncodeunits(mm.match) - 1)
        body = text[span]
        for e in eachmatch(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(\d+)\s*,?(?:\s*#\s*(.*))?$"m, body)
            modtable[e.captures[1]] = parse(Int, e.captures[2])
            e.captures[3] === nothing || (reasons[e.captures[1]] = strip(e.captures[3]))
        end
    end
    found || return nothing
    doc = Dict{String,Any}("generic" => generics, "module" => modtable)
    isempty(reasons) || (doc["module_reason"] = reasons)
    return doc
end

"""
    convert_pass_audit(text) -> Union{Dict,Nothing}

`test/pass_audit.jl` → `[[row]] name, arrays = [{label, reads, writes, holder?}]` from every
`audit(() -> …, "<row>", Traffic("<label>", …, (<reads>, <writes>)), …)` call; the counts are kept as
the symbolic strings the file writes (`"3P"`, `"2M"`, `"0"`), a holder comment beside a
[`TestHarness.Traffic`](@ref) kept as `holder`. Returns the document or `nothing`.
"""
function convert_pass_audit(text::AbstractString)
    rows = Any[]
    for m in eachmatch(r"\baudit\(\s*\(\)\s*->", text)
        span = balanced_span(text, m.offset + ncodeunits("audit") )
        call = text[span]
        nm = match(r"^\(\s*\(\)\s*->.*?,\s*\"([^\"]+)\"\s*,"s, call)
        nm === nothing && continue
        arrays = Any[]
        for t in eachmatch(r"Traffic\(\s*\"([^\"]+)\"\s*,.*?\(\s*([0-9A-Za-z_*+\- ]+?)\s*,\s*([0-9A-Za-z_*+\- ]+?)\s*\)\s*\)(?:[^\n]*?#\s*([^\n]*))?"s, call)
            a = Dict{String,Any}("label" => t.captures[1], "reads" => strip(t.captures[2]), "writes" => strip(t.captures[3]))
            t.captures[4] === nothing || (a["holder"] = strip(t.captures[4]))
            push!(arrays, a)
        end
        push!(rows, Dict("name" => nm.captures[1], "arrays" => arrays))
    end
    return isempty(rows) ? nothing : Dict{String,Any}("row" => rows)
end

"""
    convert_oracle_registry(text) -> Union{Dict,Nothing}

`test/oracle_registry.jl` → `[[operation]] name, class, evidence` from
`const ORACLE_PROVENANCE = Dict(:<op> => (:<class>, "<evidence>"), …)`. Returns the document or `nothing`.
"""
function convert_oracle_registry(text::AbstractString)
    m = match(r"const\s+ORACLE_PROVENANCE\s*=\s*Dict[^(]*\(", text)
    m === nothing && return nothing
    span = balanced_span(text, m.offset + ncodeunits(m.match) - 1)
    body = text[span]
    ops = Any[]
    # the evidence is one string literal, or several joined by `*` across lines
    strlit = raw"\"(?:[^\"\\]|\\.)*\""
    entry = Regex(raw":([A-Za-z_][A-Za-z0-9_!]*)\s*=>\s*\(\s*:([a-z_]+)\s*,\s*(" * strlit * raw"(?:\s*\*\s*" * strlit * raw")*)\s*\)", "s")
    for e in eachmatch(entry, body)
        parts = [chop(m.match; head = 1, tail = 1) for m in eachmatch(Regex(strlit), e.captures[3])]
        push!(ops, Dict("name" => e.captures[1], "class" => e.captures[2], "evidence" => replace(join(parts), "\\\"" => "\"")))
    end
    return Dict{String,Any}("operation" => ops)
end

const BASELINES = (
    ("test/method_parity.jl", "test/method_parity_baseline.toml", :parity),
    ("test/pass_audit.jl", "test/pass_audit_baseline.toml", :audit),
    ("test/oracle_registry.jl", "test/oracle_registry.toml", :oracle),
)

"""
    migrate_baselines(root = pwd(); dry_run = false, io = stdout) -> Int

`gbg migrate baselines`: the textual converter from the consumer's existing test files to the three
frozen TOML baselines `TestHarness` reads. The arguments are:

- `root` — the package root.
- `dry_run` — print the TOML instead of writing it.
- `io` — where the report goes.

The `.jl` files are read, never `include`d or edited. A literal not found is reported and skipped
(exit 0); a literal that does not parse to its closing paren is exit 2 naming the line; an existing
TOML is refused (exit 2) unless `dry_run`. Returns the exit code.
"""
function migrate_baselines(root::AbstractString = pwd(); dry_run::Bool = false, io::IO = stdout)
    root = abspath(root)
    modules = try derive_config(root)["package"]["modules"] catch; String[] end
    code = 0
    for (src, dst, kind) in BASELINES
        sp = joinpath(root, src); dp = joinpath(root, dst)
        isfile(sp) || (println(io, "  migrate: $src absent — nothing to convert"); continue)
        text = read(sp, String)
        doc = try
            kind == :parity ? convert_method_parity(text, modules) : kind == :audit ? convert_pass_audit(text) : convert_oracle_registry(text)
        catch err
            err isa InitError || rethrow()
            println(io, "  migrate: $src — ", err.msg); code = 2; continue
        end
        doc === nothing && (println(io, "  migrate: $src holds no literal of the expected shape — skipped"); continue)
        header = "# $dst — frozen by `gbg migrate baselines` from $src on $(today()); refreeze deliberately, with the reason.\n\n"
        if dry_run
            println(io, "  migrate --dry-run: $dst would be:\n"); print(io, header); TOML.print(io, doc); println(io)
        elseif isfile(dp)
            println(io, "  migrate: $dst exists; refused (remove it to reconvert)"); code = 2
        else
            open(dp, "w") do f; print(f, header); TOML.print(f, doc); end
            n = kind == :parity ? length(doc["generic"]) : kind == :audit ? length(doc["row"]) : length(doc["operation"])
            println(io, "  migrate: wrote $dst ($n entries)")
        end
    end
    return code
end

"""
    migrate_seeds(root, cfg; io = stdout) -> Int

Converts a former `.claude/commands/check-consistency/seed_defects.py` `CATALOG` (tuples of class,
description, anchor regex, replacement, occurrence) into `.gbg/seeds.toml` as the `seeds` definition
states. The arguments are:

- `root` — the package root.
- `cfg` — the derived config (for the package name).
- `io` — where the report goes.

An absent source writes nothing, exit 0; an existing `seeds.toml` is left alone. Returns the exit code.
"""
function migrate_seeds(root::AbstractString, cfg::AbstractDict; io::IO = stdout)
    src = joinpath(root, ".claude", "commands", "check-consistency", "seed_defects.py")
    dst = joinpath(root, ".gbg", "seeds.toml")
    isfile(src) || (println(io, "  migrate: no seed_defects.py — no seed catalogue written (seed_rounds stays false)"); return 0)
    isfile(dst) && (println(io, "  migrate: .gbg/seeds.toml exists; left alone"); return 0)
    text = read(src, String)
    m = match(r"CATALOG\s*=\s*\[", text)
    m === nothing && (println(io, "  migrate: seed_defects.py has no CATALOG list — skipped"); return 0)
    body = text[m.offset + ncodeunits(m.match):end]
    e = findfirst(r"^\]"m, body); body = e === nothing ? body : body[1:first(e)-1]
    pystr = raw"(?:r?\"((?:[^\"\\]|\\.)*)\"|r?'((?:[^'\\]|\\.)*)')"
    tuple_re = Regex(raw"\(\s*" * pystr * raw"\s*,\s*" * pystr * raw"\s*,\s*" * pystr * raw"\s*,\s*" * pystr * raw"\s*,\s*(\d+)\s*\)", "s")
    classes = Any[]
    pick(c1, c2) = c1 === nothing ? c2 : c1
    for t in eachmatch(tuple_re, body)
        c = t.captures
        name, desc, anchor, repl, nth = pick(c[1], c[2]), pick(c[3], c[4]), pick(c[5], c[6]), pick(c[7], c[8]), parse(Int, c[9])
        push!(classes, Dict("name" => name, "description" => desc, "anchor" => anchor, "replacement" => repl, "occurrence" => nth))
    end
    isempty(classes) && (println(io, "  migrate: CATALOG parsed to zero classes — skipped"); return 0)
    open(dst, "w") do f
        println(f, "# .gbg/seeds.toml — $(cfg["package"]["name"])'s seed catalogue (the `seeds` definition of instruments/check-consistency/schema.json),")
        println(f, "# converted by `gbg init --migrate` from seed_defects.py on $(today()). Each class plants one labelled defect a hat exists")
        println(f, "# to catch: `anchor` is a regex over the FULL manuscript, `replacement` the mutated text, `occurrence` the base 1-based")
        println(f, "# occurrence the per-round salt offsets. The sha of this file is stamped into every seeded round as seed_catalog_sha.\n")
        TOML.print(f, Dict("class" => classes))
    end
    println(io, "  migrate: wrote .gbg/seeds.toml ($(length(classes)) classes); set instruments.check-consistency.seed_rounds = true to seed rounds")
    return 0
end

"""
    new(pkgname; parent = pwd(), io = stdout) -> Int

`gbg new <Pkg>`: `init` for a fifth package. The arguments are:

- `pkgname` — the package name.
- `parent` — the directory holding the package (or the package root itself).
- `io` — where the report goes.

The package tree must already exist with a `Project.toml`. Besides `init`, it seeds `CLAUDE.md` from the
skeleton and adds a `[[consumer]]` row to the dev checkout's `fleet.toml`. Returns the exit code.
"""
function new(pkgname::AbstractString; parent::AbstractString = pwd(), io::IO = stdout)
    root = isfile(joinpath(parent, "Project.toml")) && get(TOML.parsefile(joinpath(parent, "Project.toml")), "name", "") == pkgname ? abspath(parent) : joinpath(abspath(parent), pkgname)
    isfile(joinpath(root, "Project.toml")) || (println(io, "new: $root has no Project.toml — create the package first (Pkg.generate)"); return 2)
    code = init(root; io)
    code == 0 || return code
    cfg = Config.read(root; check = false)
    s = Sync.slots(cfg)
    for (path, tmpl) in (("CLAUDE.md", "CLAUDE.md.skeleton"),)
        p = joinpath(root, path)
        isfile(p) && continue
        mkpath(dirname(p)); write(p, Sync.render(Sync.template(tmpl), s)); println(io, "  wrote $path (seed)")
    end
    fleet = joinpath(Sync.tool_root(), "fleet.toml")
    if isfile(fleet)
        f = TOML.parsefile(fleet)
        if !any(c -> c["name"] == pkgname, get(f, "consumer", Any[]))
            open(fleet, "a") do fio
                println(fio, "\n[[consumer]]\nname = ", repr(pkgname), "\npath = ", repr(relpath(root, Sync.tool_root())), "\ngithub = ", repr("GrigorySarnitsky/$pkgname.jl"))
            end
            println(io, "  fleet.toml: added $pkgname")
        end
    end
    return 0
end

function cmd_init(args)
    o = parse_options(args)
    return init(pwd(); migrate = "migrate" in o.flags, dry_run = "dry-run" in o.flags)
end
function cmd_migrate_baselines(args)
    o = parse_options(args)
    return migrate_baselines(pwd(); dry_run = "dry-run" in o.flags)
end
function cmd_new(args)
    o = parse_options(args)
    isempty(o.positional) && (println(stderr, "usage: gbg new <Pkg>"); return 2)
    return new(o.positional[1])
end
VERBS["init"] = cmd_init
VERBS["migrate baselines"] = cmd_migrate_baselines
VERBS["new"] = cmd_new

end # module Init
