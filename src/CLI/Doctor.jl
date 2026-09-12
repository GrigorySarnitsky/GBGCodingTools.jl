# Doctor.jl — `gbg doctor [--deep] [--json] [--effective] [--only <id-or-prefix>[,…]|QUICK]`: the check
# table of ARCHITECTURE §7.3, read-only, stable ids, exit 1 on any FAIL, 2 when the tree is not a
# consumer. The QUICK set runs inside preflight, the makedocs wrapper and TestHarness.gate().

"""
    Doctor

The health check of a consumer's tooling: every check reads the tree and writes nothing, except the
`--deep` set, which runs the package's builds and tests. Every check has a stable id, returns
`PASS`, `WARN`, `FAIL` or `NA`, and can be selected by id or prefix; the `QUICK` set is the subset that
holds on a runner with no shim and a detached HEAD. A `scope = "check"` ledger entry on an exemptable
id (`LEG.*`, `GIT.*`, `AUDIT.*`) turns its FAIL into a WARN naming the reason; the non-exemptable
families are the tool's own enforcement.

`anchor` carries three unrelated senses across this package, and the checks below touch two: a hat's
or lane's `anchor` is whether it runs at full strength rather than on the economy model that
[`GBGCodingTools.Config`](@ref) defines (`CFG.HATS`);
`Config.resolve_anchor`'s is a `file#heading` Markdown reference; a seed class's, in `Seeds.select`,
is the regular expression marking where the seed is planted. No one of them
implies another.
"""
module Doctor

using TOML, Dates, JSON3, Pkg
using ..GBGCodingTools: GBGCodingTools, PKG_NAME, PKG_UUID, JULIA_FLOOR, Config, Ledger, Sync, RoundFiles, Git, Witnesses, Reflection,
      load_schema, instrument_schema, validate, parse_options, VERBS, tool_version, running_dev, tool_sub_envs, manifest_tree_sha, self_verify,
      scan_catalog, run_scan, SCANS, prose_lines, surface_kind

"""
    Check

One doctor result. The fields are:

- `id` — the stable check id.
- `status` — `:PASS`, `:WARN`, `:FAIL` or `:NA`.
- `detail` — one line: what was measured, or what failed and what fixes it.
"""
struct Check
    id::String
    status::Symbol
    detail::String
end
pass(id, d = "") = Check(id, :PASS, d)
warn(id, d) = Check(id, :WARN, d)
fail(id, d) = Check(id, :FAIL, d)
na(id, d) = Check(id, :NA, d)

const NON_EXEMPTABLE = ("PIN.", "CFG.", "EXEMPT.", "WIRE.", "MANAGED.", "SHIM.", "POL.", "ROUND.", "SELF.")
const EXEMPTABLE = ("LEG.", "GIT.", "AUDIT.")
const QUICK = ["CFG.VALID", "CFG.SURFACES", "CFG.HATS", "CFG.SEEDS", "CFG.TERRITORIES", "CFG.EXEMPTIONS", "PIN.CONFIG", "PIN.SOURCES", "PIN.NOT_DEV",
               "EXEMPT.EXPIRED", "EXEMPT.EXPIRING", "EXEMPT.STALE", "EXEMPT.BROAD", "WIRE.MAKEDOCS", "WIRE.RUNTESTS", "WIRE.CI_AUTH",
               "WIRE.GITIGNORE", "WIRE.CLAUDE_MD", "MANAGED.HASH", "ROUND.DIR", "ROUND.MARKER", "ROUND.OPEN", "ROUND.ABANDONED",
               "ROUND.DEV", "ROUND.FROZEN", "POL.SENTINEL", "SELF.CONSUMER", "AUDIT.GAP"]
const DEEP = ["LOAD.ENVS", "BUILD.DOCS", "SELF.DOCS", "TEST.PKG", "WITNESSES.ESCALATED", "WITNESSES.BLOCKED"]
const LEGACY_PILES = Dict(
    "GBGPeriodicFields" => [".claude/doc-review", ".claude/doc-review-prev", ".claude/doc-review-checkdocs", ".claude/audit-changes", ".claude/doc-review-adjudicated.md"],
    "GBGIsotropicTurbulence" => [".claude/doc-review", ".claude/doc-review-prev", ".claude/doc-review-minimal", ".claude/doc-review-round1", ".claude/doc-review-closures",
                                 ".claude/review-rounds", ".claude/rubric-audit", ".claude/audit-changes", ".claude/bug-hunt", ".claude/doc-review-adjudicated.md", ".claude/README.md"],
    "GBGStreamingStatistics" => [".claude/doc-review"],
)

# ---- context -----------------------------------------------------------------------------------------------

mutable struct Ctx
    cfg::Dict{String,Any}
    root::String
    ledger::Vector{Dict{String,Any}}
    ledger_error::String
    deep::Bool
    tool_root::Union{String,Nothing}   # the tool repository in reach: the root itself, the enclosing one, or ~/.gbg/dev
end

function context(cfg::AbstractDict; deep::Bool = false)
    root = cfg["root"]
    ledger, lerr = try
        (Ledger.read(cfg), "")
    catch err
        (Dict{String,Any}[], sprint(showerror, err))
    end
    troot = if Sync.tool_root() !== nothing && (abspath(root) == abspath(Sync.tool_root()) || startswith(abspath(root), abspath(Sync.tool_root()) * "/"))
        abspath(Sync.tool_root())
    else
        p = expanduser("~/.gbg/dev")
        isfile(p) ? strip(read(p, String)) : nothing
    end
    troot !== nothing && !isdir(troot) && (troot = nothing)
    return Ctx(Dict{String,Any}(cfg), root, ledger, lerr, deep, troot)
end

function git(ctx::Ctx, args...)
    argv = String[a for a in args]
    try
        return String(strip(read(pipeline(addenv(`git -C $(ctx.root) $argv`, "LC_ALL" => "C"); stderr = devnull), String)))
    catch
        return nothing
    end
end

strip_code(text) = replace(text, r"\"\"\".*?\"\"\""s => "\"\"", r"\"(?:[^\"\\\n]|\\.)*\"" => "\"\"", r"#=.*?=#"s => "", r"#[^\n]*" => "")

# ---- the checks --------------------------------------------------------------------------------------------

const CHECKS = Pair{String,Function}[]
check!(id, f) = push!(CHECKS, id => f)

check!("ENV.JULIA", ctx -> begin
    j = Sys.which("julia")
    j === nothing && return fail("ENV.JULIA", "no `julia` on PATH")
    VERSION >= JULIA_FLOOR || return fail("ENV.JULIA", "running Julia $VERSION is below the floor $JULIA_FLOOR")
    pass("ENV.JULIA", "julia $VERSION at $j")
end)
check!("ENV.SHIM", ctx -> begin
    p = expanduser("~/.local/bin/gbg")
    isfile(p) || return fail("ENV.SHIM", "$p missing — `gbg install`")
    (filemode(p) & 0o111) != 0 || return fail("ENV.SHIM", "$p is not executable")
    pass("ENV.SHIM", p)
end)
check!("ENV.DEV_CHECKOUT", ctx -> begin
    p = expanduser("~/.gbg/dev")
    isfile(p) || return warn("ENV.DEV_CHECKOUT", "~/.gbg/dev absent (needed only by --dev and the outside-consumer verbs)")
    d = strip(read(p, String))
    isdir(d) || return fail("ENV.DEV_CHECKOUT", "~/.gbg/dev names $d, which is not a directory")
    pj = joinpath(d, "Project.toml")
    (isfile(pj) && get(TOML.parsefile(pj), "name", "") == PKG_NAME) || return fail("ENV.DEV_CHECKOUT", "$d is not a $PKG_NAME checkout")
    pass("ENV.DEV_CHECKOUT", d)
end)
check!("SHIM.HASH", ctx -> begin
    which = Sys.which("gbg"); home = expanduser("~/.local/bin/gbg")
    which === nothing && return fail("SHIM.HASH", "no `gbg` on PATH")
    realpath(which) == realpath(home) || return fail("SHIM.HASH", "`gbg` resolves to $which, not $home — another gbg is earlier on PATH")
    ref = joinpath(pkgdir(GBGCodingTools), "bin", "gbg")
    read(which) == read(ref) || return fail("SHIM.HASH", "the installed shim differs from bin/gbg of this copy (stale shim) — `gbg install`")
    pass("SHIM.HASH", "installed shim equals bin/gbg")
end)

isdevlegal(ctx) = ctx.tool_root !== nothing && (abspath(ctx.root) == ctx.tool_root || startswith(abspath(ctx.root), ctx.tool_root * "/"))
check!("PIN.CONFIG", ctx -> begin
    v = String(ctx.cfg["tool"]["version"])
    if v == "dev"
        isdevlegal(ctx) || return fail("PIN.CONFIG", "pinned at `dev` outside the tool repository — a consumer pins a released tag")
        return pass("PIN.CONFIG", "dev (the tool root or its fixture)")
    end
    occursin(r"^\d+\.\d+\.\d+$", v) || return fail("PIN.CONFIG", "$v is not a released X.Y.Z (a prerelease is never pinned)")
    pass("PIN.CONFIG", "v$v")
end)
check!("PIN.SOURCES", ctx -> begin
    v = String(ctx.cfg["tool"]["version"]); problems = String[]
    envs = tool_sub_envs(ctx.root)
    isempty(envs) && return fail("PIN.SOURCES", "no sub-environment Project.toml lists $PKG_NAME (docs/ at least must)")
    for e in envs
        p = TOML.parsefile(joinpath(ctx.root, e, "Project.toml"))
        want = Sync.subenv_entries(ctx.cfg, e)
        src = get(get(p, "sources", Dict()), PKG_NAME, nothing)
        src === nothing && (push!(problems, "$e: no [sources] entry"); continue)
        if v == "dev"
            have = get(src, "path", nothing)
            have === nothing && (push!(problems, "$e: pinned at dev, a path source is needed"); continue)
            realpath(joinpath(ctx.root, e, have)) == realpath(joinpath(ctx.root, e, want["sources"]["path"])) || push!(problems, "$e: path $have does not resolve to the tool repository")
        else
            get(src, "url", "") == want["sources"]["url"] || push!(problems, "$e: url $(get(src, "url", "∅")) ≠ $(want["sources"]["url"])")
            rev = get(src, "rev", "")
            occursin("-rc.", rev) && abspath(ctx.root) != something(ctx.tool_root, "") && push!(problems, "$e: rev $rev is a prerelease — never pinned by a consumer")
            rev == want["sources"]["rev"] || push!(problems, "$e: rev $rev ≠ $(want["sources"]["rev"])")
            get(get(p, "compat", Dict()), PKG_NAME, "") == want["compat"] || push!(problems, "$e: [compat] $(get(get(p, "compat", Dict()), PKG_NAME, "∅")) ≠ $(want["compat"])")
        end
    end
    isempty(problems) ? pass("PIN.SOURCES", "$(length(envs)) sub-environment(s) agree with the pinned version") : fail("PIN.SOURCES", join(problems, "; "))
end)
function tool_dep()
    try
        for (uuid, d) in Pkg.dependencies()
            uuid == PKG_UUID && return d
        end
    catch
    end
    return nothing
end
check!("PIN.TREESHA", ctx -> begin
    String(ctx.cfg["tool"]["version"]) == "dev" && return warn("PIN.TREESHA", "pinned at dev — no tree hash to compare")
    shas = Dict{String,Union{String,Nothing}}(e => manifest_tree_sha(joinpath(ctx.root, e, "Manifest.toml")) for e in tool_sub_envs(ctx.root))
    missing_ = [e for (e, s) in shas if s === nothing]
    present = unique(filter(!isnothing, collect(values(shas))))
    length(present) > 1 && return fail("PIN.TREESHA", "manifests disagree: " * join(("$e=$(s === nothing ? "∅" : s[1:8])" for (e, s) in shas), ", "))
    d = tool_dep()
    if d !== nothing && d.tree_hash !== nothing && !isempty(present)
        string(d.tree_hash) == present[1] || return fail("PIN.TREESHA", "the resolved copy's tree hash $(string(d.tree_hash)[1:8]) ≠ the manifests' $(present[1][1:8])")
    end
    isempty(missing_) || return warn("PIN.TREESHA", "no manifest in " * join(missing_, ", ") * (isempty(present) ? "" : "; the rest agree at $(present[1][1:8])"))
    pass("PIN.TREESHA", isempty(present) ? "no manifests" : present[1][1:8])
end)
check!("PIN.SELF", ctx -> begin
    io = IOBuffer(); code = try self_verify(ctx.root; io) catch err; 2 end
    out = strip(String(take!(io)))
    code == 0 || return fail("PIN.SELF", replace(out, "\n" => " | "))
    occursin("WARN", out) ? warn("PIN.SELF", replace(out, "\n" => " | ")) : pass("PIN.SELF", "the running copy matches the manifests")
end)
check!("PIN.NOT_DEV", ctx -> begin
    String(ctx.cfg["tool"]["version"]) == "dev" && return warn("PIN.NOT_DEV", "pinned at dev")
    for e in tool_sub_envs(ctx.root)
        m = joinpath(ctx.root, e, "Manifest.toml"); isfile(m) || continue
        man = TOML.parsefile(m); deps = get(man, "deps", man)
        for entry in get(deps, PKG_NAME, Any[])
            haskey(entry, "path") && return fail("PIN.NOT_DEV", "$e/Manifest.toml tracks $PKG_NAME by path (a dev'd copy)")
        end
    end
    pass("PIN.NOT_DEV")
end)
check!("SELF.CONSUMER", ctx -> begin
    ctx.tool_root === nothing && return na("SELF.CONSUMER", "no tool repository in reach (an ordinary consumer)")
    p = joinpath(ctx.tool_root, ".gbg", "config.toml")
    isfile(p) || return fail("SELF.CONSUMER", "the tool root $(ctx.tool_root) carries no .gbg/config.toml (gbg --dev init)")
    c = try TOML.parsefile(p) catch; return fail("SELF.CONSUMER", "$p does not parse") end
    get(get(c, "tool", Dict()), "version", "") == "dev" || return fail("SELF.CONSUMER", "the tool root is pinned at $(get(get(c, "tool", Dict()), "version", "∅")), not dev")
    get(get(c, "package", Dict()), "name", "") == PKG_NAME || return fail("SELF.CONSUMER", "the tool root's [package] name is not $PKG_NAME")
    if String(ctx.cfg["tool"]["version"]) == "dev" && !isdevlegal(ctx)
        return fail("SELF.CONSUMER", "pinned at dev in a consumer outside the tool repository")
    end
    pass("SELF.CONSUMER", ctx.tool_root)
end)

check!("CFG.VALID", ctx -> begin
    for r in RoundFiles.rounds(ctx.cfg)
        r.state == :open || continue
        r.round["instrument"] in ctx.cfg["instruments"]["enabled"] || return fail("CFG.VALID", "open round $(r.name) of the disabled instrument $(r.round["instrument"])")
    end
    pass("CFG.VALID", "config parses, validates, paths resolve")
end)
function pinned_and_managed(ctx)
    files = [".gbg/config.toml", ".gbg/exemptions.toml", ".gbg/seeds.toml", ".gbg/managed.json"]
    d = joinpath(ctx.root, ".gbg", "hats"); isdir(d) && append!(files, [".gbg/hats/" * f for f in readdir(d)])
    append!(files, [e * "/Project.toml" for e in tool_sub_envs(ctx.root)])
    sc = try Sync.read_sidecar(ctx.cfg) catch; Dict("files" => Dict()) end
    append!(files, [k for k in keys(sc["files"]) if !occursin('#', k)])
    return unique(files)
end
check!("CFG.TORN", ctx -> begin
    Git.is_repo(ctx.root) || return na("CFG.TORN", "not a git repository")
    modified = Set(p for (_, p) in Git.porcelain(ctx.root; untracked = false))
    watched = Set(pinned_and_managed(ctx))
    open_rounds = [r.name for r in RoundFiles.rounds(ctx.cfg) if r.state == :open]
    torn = [f for f in modified if f in watched && !any(o -> startswith(f, ".gbg/rounds/$o/"), open_rounds)]
    isempty(torn) ? pass("CFG.TORN", "no pinned or managed file modified") : fail("CFG.TORN", "modified in the working tree: " * join(sort!(torn), ", ") * " — wait for the sync, or commit")
end)
check!("CFG.SURFACES", ctx -> begin
    errs = Config.check_paths(ctx.cfg)
    s = ctx.cfg["surfaces"]
    for anchor in vcat([s["history_exempt"]], get(s, "references_heading", "absent") == "absent" ? String[] : [s["references_heading"]], ctx.cfg["package"]["rulebook_sections"])
        f, line, n = Config.resolve_anchor(ctx.root, anchor)
        n == 1 || push!(errs, "anchor $anchor resolves to $n headings")
    end
    for (k, f) in ctx.cfg["instruments"]["audit-changes"]["executable_claims"]
        (startswith(f, "test/") && isfile(joinpath(ctx.root, f))) || push!(errs, "executable_claims.$k = $f is not an existing file under test/")
    end
    any(x -> occursin("TODO", x), (ctx.cfg["package"]["description"], ctx.cfg["package"]["domain"])) && push!(errs, "package.description or domain still carries the init TODO")
    isempty(errs) ? pass("CFG.SURFACES", "every glob, anchor, module and command resolves") : fail("CFG.SURFACES", join(errs, "; "))
end)
function hat_file(ctx, key)
    for p in (joinpath(ctx.root, ".gbg", "hats", key * ".toml"), joinpath(pkgdir(GBGCodingTools), "catalog", "hats", key * ".toml"))
        isfile(p) && return p
    end
    return nothing
end
function fleet_names()
    p = joinpath(pkgdir(GBGCodingTools), "fleet.toml")
    isfile(p) || return String[]
    return [c["name"] for c in get(TOML.parsefile(p), "consumer", Any[])]
end
# `CFG.HATS` reads a hat's `anchor` — the full-strength sense the `Doctor` docstring binds, not
# `Config.resolve_anchor`'s Markdown one.
check!("CFG.HATS", ctx -> begin
    cc = ctx.cfg["instruments"]["check-consistency"]; errs = String[]
    hats = String.(cc["hats"]); schema = load_schema("hat")
    others = filter(!=(ctx.cfg["package"]["name"]), fleet_names())
    anchors = 0
    for key in hats
        p = hat_file(ctx, key)
        p === nothing && (push!(errs, "hat $key has no persona file (catalogue or .gbg/hats/)"); continue)
        h = TOML.parsefile(p)
        v = validate(schema, h); isempty(v) || push!(errs, "$key: " * join(v, "; "))
        occursin("TODO", get(h, "persona", "")) && push!(errs, "$key: persona still carries the init TODO")
        for o in others
            occursin(o, get(h, "persona", "")) && push!(errs, "$key: persona names the fleet package $o")
        end
        get(h, "anchor", false) && (anchors += 1)
    end
    for d in cc["domain_hats"]
        d["key"] in hats || push!(errs, "domain hat $(d["key"]) is not in the hats list")
        d["anchor"] && (anchors += 1)
    end
    for c in cc["core"]; c in hats || push!(errs, "core hat $c is not in the hats list"); end
    anchors >= 1 || push!(errs, "no anchored hat (at least one hat runs at full strength)")
    for a in ctx.cfg["package"]["rulebook_sections"]
        _, _, n = Config.resolve_anchor(ctx.root, a); n == 1 || push!(errs, "rulebook anchor $a resolves to $n headings")
    end
    isempty(errs) ? pass("CFG.HATS", "$(length(hats)) hats resolve, $anchors anchored") : fail("CFG.HATS", join(errs, "; "))
end)
check!("CFG.SEEDS", ctx -> begin
    cc = ctx.cfg["instruments"]["check-consistency"]
    cc["seed_rounds"] || return pass("CFG.SEEDS", "seed_rounds = false")
    p = joinpath(ctx.root, cc["seed_catalog"])
    isfile(p) || return fail("CFG.SEEDS", "seed_rounds = true but $(cc["seed_catalog"]) is absent")
    inst = instrument_schema("check-consistency")
    errs = validate(inst["\$defs"]["seeds"], TOML.parsefile(p); root = inst)
    isempty(errs) ? pass("CFG.SEEDS", "$(length(TOML.parsefile(p)["class"])) classes") : fail("CFG.SEEDS", join(errs, "; "))
end)
# Every file of the `src` surface is named by some bug-hunt territory. A territory list is a guess about
# where bugs live, and a file in none of them is read by no hunter while the round still reports success —
# which is how `src/CLI/Design.jl` sat outside every territory through the release whose `gbg attack`
# crashed on its first invocation, and how the module entry point the free lanes are pointed at was itself
# unhunted. WARN, not FAIL: a consumer may exclude a file deliberately, and a coverage gap is a thing to
# see rather than a broken config. NA where no territory is configured.
check!("CFG.TERRITORIES", ctx -> begin
    ts = get(get(ctx.cfg["instruments"], "bug-hunt", Dict{String,Any}()), "territories", Any[])
    isempty(ts) && return na("CFG.TERRITORIES", "no bug-hunt territories configured")
    covered = Set{String}()
    for t in ts; union!(covered, GBGCodingTools.Preflight.expand_globs(ctx.root, t["files"])); end
    src = Config.surface_files(ctx.cfg, "src")
    miss = [f for f in src if !(f in covered)]
    isempty(miss) ? pass("CFG.TERRITORIES", "$(length(src)) src file(s), every one in a territory") :
        warn("CFG.TERRITORIES", "$(length(miss)) src file(s) in NO territory — no hunter reads them: " * join(miss, ", "))
end)
known_rule_ids() = Set(r["id"] for r in TOML.parsefile(joinpath(pkgdir(GBGCodingTools), "policy", "RULES.toml"))["rule"])
check!("CFG.EXEMPTIONS", ctx -> begin
    isempty(ctx.ledger_error) || return fail("CFG.EXEMPTIONS", ctx.ledger_error)
    errs = String[]; rules = known_rule_ids(); scans = Set(r["id"] for r in scan_catalog()); checks = Set(first.(CHECKS))
    for e in ctx.ledger
        id = e["id"]; tag = "$(id)@$(e["target"])"
        known = startswith(id, "RULE.") ? id in rules : startswith(id, "SCAN.") ? (id in scans || startswith(id, "SCAN.CUSTOM.")) :
                occursin('/', id) && occursin('#', id) ? true : id in checks || e["scope"] == "harness"
        known || push!(errs, "$tag: unknown id")
        length(e["reason"]) >= 40 || push!(errs, "$tag: reason shorter than 40 characters")
        if e["scope"] == "finding"
            haskey(e, "overturn_when") || push!(errs, "$tag: finding scope needs overturn_when")
            haskey(e, "expires") && push!(errs, "$tag: finding scope carries no expires")
        else
            haskey(e, "expires") || push!(errs, "$tag: expires is required")
            haskey(e, "expires") && e["expires"] > e["recorded"] + Day(365) && push!(errs, "$tag: expires beyond recorded + 365 d")
        end
        if e["scope"] == "check"
            any(p -> startswith(id, p), NON_EXEMPTABLE) && push!(errs, "$tag: $id is non-exemptable")
            e["target"] == "*" && push!(errs, "$tag: target * on scope check")
        end
        if haskey(e, "match")
            e["scope"] in ("scan", "lint", "policy", "harness") || push!(errs, "$tag: match on scope $(e["scope"])")
            if haskey(e["match"], "arg_type") && !(id in ("SCAN.ARGCOV", "SCAN.SIGNATURE_FIDELITY") || startswith(id, "RULE.DOC.ARGCOV") || startswith(id, "RULE.DOC.SIGNATURE"))
                push!(errs, "$tag: arg_type is evaluable by the reflection scans only; a text scan refuses it")
            end
        end
    end
    isempty(errs) ? pass("CFG.EXEMPTIONS", "$(length(ctx.ledger)) entries") : fail("CFG.EXEMPTIONS", join(errs, "; "))
end)
check!("EXEMPT.EXPIRED", ctx -> begin
    ex = [e for e in ctx.ledger if e["scope"] != "finding" && haskey(e, "expires") && e["expires"] < today()]
    isempty(ex) ? pass("EXEMPT.EXPIRED") : fail("EXEMPT.EXPIRED", join(("$(e["id"])@$(e["target"]) expired $(e["expires"])" for e in ex), "; "))
end)
check!("EXEMPT.EXPIRING", ctx -> begin
    ex = [e for e in ctx.ledger if e["scope"] != "finding" && haskey(e, "expires") && today() <= e["expires"] <= today() + Day(30)]
    isempty(ex) ? pass("EXEMPT.EXPIRING") : warn("EXEMPT.EXPIRING", join(("$(e["id"])@$(e["target"]) expires $(e["expires"])" for e in ex), "; "))
end)
function target_exists(ctx, e)
    t = e["target"]
    t == "*" && return true
    isfile(joinpath(ctx.root, t)) && return true
    occursin(r"[*?\[]", t) && return !isempty(Config.glob_files(ctx.root, t))
    if occursin('/', t) && occursin('#', t)
        rd = joinpath(ctx.root, ".gbg", "rounds", first(split(t, '/')))
        fj = joinpath(rd, "findings.json"); isfile(fj) || return false
        return occursin("\"" * t * "\"", read(fj, String))
    end
    re = Regex("\\b" * replace(t, r"([.*+?^${}()|\[\]\\])" => s"\\\1") * "\\b")
    for f in Config.surface_files(ctx.cfg, "all")
        occursin(re, read(joinpath(ctx.root, f), String)) && return true
    end
    return false
end
check!("EXEMPT.STALE", ctx -> begin
    stale = [e for e in ctx.ledger if !target_exists(ctx, e)]
    isempty(stale) ? pass("EXEMPT.STALE") : fail("EXEMPT.STALE", join(("$(e["id"])@$(e["target"]) names nothing that exists" for e in stale), "; "))
end)
check!("EXEMPT.BROAD", ctx -> begin
    broad = String[]; notes = String[]
    for e in ctx.ledger
        haskey(e, "match") || continue
        id = e["id"]
        if id == "SCAN.ARGCOV" || id == "RULE.DOC.ARGCOV"
            hits, population, _ = try Reflection.argcov(ctx.cfg) catch err; push!(notes, "argcov population unavailable: $(sprint(showerror, err))"); continue end
            covered = count(h -> Ledger.matches(e, ctx.root; file = h.file, symbol = h.binding, arg_name = h.parameter, arg_type = Any), hits)
            population > 0 && covered > population ÷ 2 && push!(broad, "$(id)@$(e["target"]) covers $covered of $population triggers")
        elseif startswith(id, "SCAN.") && haskey(SCANS, id)
            row = findfirst(r -> r["id"] == id, scan_catalog()); row === nothing && continue
            r = run_scan(ctx.cfg, scan_catalog()[row]; ledger = Dict{String,Any}[])
            covered = count(h -> Ledger.matches(e, ctx.root; file = h.file, symbol = h.symbol), r.hits)
            length(r.hits) > 0 && covered > length(r.hits) ÷ 2 && push!(broad, "$(id)@$(e["target"]) covers $covered of $(length(r.hits)) triggers")
        end
    end
    isempty(broad) ? pass("EXEMPT.BROAD", isempty(notes) ? "" : join(notes, "; ")) : warn("EXEMPT.BROAD", join(vcat(broad, notes), "; "))
end)

check!("WIRE.MAKEDOCS", ctx -> begin
    p = joinpath(ctx.root, "docs", "make.jl")
    isfile(p) || return fail("WIRE.MAKEDOCS", "docs/make.jl absent")
    t = strip_code(read(p, String))
    occursin("GBGCodingTools.makedocs(", t) || return fail("WIRE.MAKEDOCS", "docs/make.jl does not call GBGCodingTools.makedocs( (a commented-out call does not count)")
    occursin(r"(?<!GBGCodingTools\.)\bmakedocs\(", t) && return fail("WIRE.MAKEDOCS", "a bare makedocs( call bypasses the wrapper")
    occursin("function lint_", t) && return fail("WIRE.MAKEDOCS", "a lint_ function body remains in make.jl")
    # the wrapper returns nothing when a round froze the build; a deploy at column 0 runs anyway and
    # publishes the previous run's directory, or none
    occursin(r"^deploydocs\("m, t) && return fail("WIRE.MAKEDOCS",
        "deploydocs( is called unconditionally — guard it on the wrapper's result, which is nothing when an open round froze the build")
    pass("WIRE.MAKEDOCS")
end)
check!("WIRE.RUNTESTS", ctx -> begin
    p = joinpath(ctx.root, "test", "runtests.jl")
    isfile(p) || return fail("WIRE.RUNTESTS", "test/runtests.jl absent")
    t = strip_code(read(p, String)); errs = String[]
    occursin("TestHarness.run_regressions(", t) || push!(errs, "no TestHarness.run_regressions( call")
    occursin("TestHarness.gate(", t) || push!(errs, "no TestHarness.gate( call")
    isdir(joinpath(ctx.root, "test", "regressions")) || push!(errs, "test/regressions/ absent")
    isempty(errs) ? pass("WIRE.RUNTESTS") : fail("WIRE.RUNTESTS", join(errs, "; "))
end)
check!("WIRE.CI_AUTH", ctx -> begin
    errs = String[]; n = 0
    for (file, snippet, marker) in Sync.WORKFLOWS
        p = joinpath(ctx.root, ".github", "workflows", file); isfile(p) || continue
        n += 1; text = read(p, String)
        occursin(r"python", text) && push!(errs, "$file runs a python step")
        rendered = try Sync.insert_fragments(text, Sync.fragments(Sync.render(Sync.template(snippet), Sync.slots(ctx.cfg; ledger = ctx.ledger))); run_marker = marker) catch err; push!(errs, "$file: $(sprint(showerror, err))"); continue end
        rendered == text || push!(errs, "$file: the auth, run or banner step is missing or out of place (gbg sync places them)")
    end
    n == 0 && return warn("WIRE.CI_AUTH", "no .github/workflows/{CI,docs}.yml")
    isempty(errs) ? pass("WIRE.CI_AUTH", "$n workflow(s) wired") : fail("WIRE.CI_AUTH", join(errs, "; "))
end)
sync_status(ctx) = try Sync.status(ctx.cfg; ledger = ctx.ledger) catch err; Sync.Entry[Sync.Entry("(render)", :MODIFIED, sprint(showerror, err))] end
check!("WIRE.GITIGNORE", ctx -> begin
    e = findfirst(x -> x.path == ".gitignore#gbg:managed", sync_status(ctx)); st = sync_status(ctx)
    e === nothing && return fail("WIRE.GITIGNORE", "no status")
    st[e].state == :OK ? pass("WIRE.GITIGNORE") : fail("WIRE.GITIGNORE", "$(st[e].state): $(st[e].detail)")
end)
check!("WIRE.CLAUDE_MD", ctx -> begin
    st = sync_status(ctx); e = findfirst(x -> x.path == "CLAUDE.md#gbg:managed", st)
    e === nothing && return fail("WIRE.CLAUDE_MD", "no status")
    st[e].state == :OK || return fail("WIRE.CLAUDE_MD", "$(st[e].state): $(st[e].detail)")
    occursin("@.gbg/policy/00-index.md", read(joinpath(ctx.root, "CLAUDE.md"), String)) || return fail("WIRE.CLAUDE_MD", "the import line is gone")
    pass("WIRE.CLAUDE_MD")
end)
check!("MANAGED.HASH", ctx -> begin
    bad = [e for e in sync_status(ctx) if e.state in (:MODIFIED, :UNMANAGED)]
    isempty(bad) ? pass("MANAGED.HASH", "every managed file equals a fresh render") : fail("MANAGED.HASH", join(("$(e.path) $(e.state)" for e in bad), "; "))
end)
check!("MANAGED.STALE", ctx -> begin
    bad = [e for e in sync_status(ctx) if e.state in (:STALE, :MISSING, :ORPHAN)]
    isempty(bad) ? pass("MANAGED.STALE", "every template of v$(ctx.cfg["tool"]["version"]) is rendered and listed") : fail("MANAGED.STALE", join(("$(e.path) $(e.state)" for e in bad), "; ") * " — gbg sync")
end)

check!("LEG.COMMANDS", ctx -> begin
    d = joinpath(ctx.root, ".claude", "commands"); present = String[]
    if isdir(d)
        for f in readdir(d)
            (any(i -> startswith(f, i), Sync.INSTRUMENTS) || f in ("manifest.py", "MANIFEST.txt", "INVENTORY.md")) && push!(present, ".claude/commands/" * f)
        end
    end
    isempty(present) ? pass("LEG.COMMANDS") : fail("LEG.COMMANDS", "legacy instrument files present: " * join(present, ", "))
end)
check!("LEG.PILES", ctx -> begin
    piles = get(LEGACY_PILES, ctx.cfg["package"]["name"], String[])
    present = [p for p in piles if ispath(joinpath(ctx.root, p))]
    isempty(present) ? pass("LEG.PILES") : fail("LEG.PILES", "legacy piles present: " * join(present, ", "))
end)
const HARNESS_BODIES = r"macro alloc_below|struct CountingArray|struct Traffic\b|function audit\(|function display_gate|function thread_digest|const DIGEST_SOURCE|function method_parity\("
check!("LEG.LINTS", ctx -> begin
    errs = String[]
    mk = joinpath(ctx.root, "docs", "make.jl")
    isfile(mk) && occursin(r"^\s*function lint_"m, read(mk, String)) && push!(errs, "lint_ bodies in docs/make.jl")
    td = joinpath(ctx.root, "test")
    if isdir(td)
        for f in readdir(td)
            endswith(f, ".jl") || continue
            occursin(HARNESS_BODIES, read(joinpath(td, f), String)) && push!(errs, "a harness body copy in test/$f")
        end
    end
    isempty(errs) ? pass("LEG.LINTS") : fail("LEG.LINTS", join(errs, "; "))
end)
normalize_ws(s) = strip(replace(s, r"\s+" => " "))
function claude_sentences(ctx)
    p = joinpath(ctx.root, "CLAUDE.md"); isfile(p) || return String[]
    before, _, after = Sync.split_block(read(p, String), "CLAUDE.md")
    text = before * "\n" * after
    text = replace(text, r"```.*?```"s => " ", r"\"[^\"\n]*\"" => " ", r"“[^”]*”" => " ", r"`[^`\n]*`" => x -> replace(x, r"[.!?]" => "·"))
    return [normalize_ws(s) for s in split(text, r"(?<=[.!?])\s+") if !isempty(strip(s))]
end
check!("LEG.SENTINELS", ctx -> begin
    rules = TOML.parsefile(joinpath(pkgdir(GBGCodingTools), "policy", "RULES.toml"))["rule"]
    sentences = claude_sentences(ctx)
    isempty(sentences) && return pass("LEG.SENTINELS", "no CLAUDE.md prose outside the block")
    exact = String[]; runs = String[]
    words(s) = split(lowercase(replace(s, r"[`*_\"“”]" => "")))
    sentwords = [words(s) for s in sentences]
    for r in rules
        sent = normalize_ws(r["sentinel"]); sw = words(sent)
        for (i, s) in enumerate(sentences)
            if normalize_ws(replace(s, r"[`*_]" => "")) == normalize_ws(replace(sent, r"[`*_]" => ""))
                push!(exact, r["id"]); break
            end
            length(sw) >= 12 || continue
            found = false
            for k in 1:length(sw)-11
                run12 = join(sw[k:k+11], " ")
                if occursin(run12, join(sentwords[i], " "))
                    push!(runs, "$(r["id"]) (\"$(run12)…\")"); found = true; break
                end
            end
            found && break
        end
    end
    isempty(exact) || return fail("LEG.SENTINELS", "rule sentinels restated verbatim outside the managed block: " * join(unique(exact), ", "))
    isempty(runs) ? pass("LEG.SENTINELS", "$(length(sentences)) sentences, no sentinel") : warn("LEG.SENTINELS", "twelve-word runs shared with: " * join(unique(runs), "; "))
end)
check!("POL.IMPORT", ctx -> begin
    p = joinpath(ctx.root, "CLAUDE.md")
    isfile(p) || return fail("POL.IMPORT", "CLAUDE.md absent")
    occursin("@.gbg/policy/00-index.md", read(p, String)) || return fail("POL.IMPORT", "CLAUDE.md does not import .gbg/policy/00-index.md")
    isfile(joinpath(ctx.root, ".gbg", "policy", "00-index.md")) || return fail("POL.IMPORT", ".gbg/policy/00-index.md absent (gbg sync)")
    pass("POL.IMPORT")
end)
check!("POL.SENTINEL", ctx -> begin
    p = joinpath(ctx.root, ".gbg", "policy", "00-index.md")
    isfile(p) || return fail("POL.SENTINEL", ".gbg/policy/00-index.md absent")
    first_line = readline(p); v = String(ctx.cfg["tool"]["version"])
    occursin(" v$v ", first_line) ? pass("POL.SENTINEL", "policy copy stamped v$v") : fail("POL.SENTINEL", "policy copy header $(first_line) does not carry v$v")
end)
check!("POL.COLLAPSED", ctx -> begin
    errs = String[]
    log = git(ctx, "log", "-20", "--format=%B")
    log !== nothing && occursin(r"Co-Authored-By:\s*Claude\s+(Opus|Sonnet|Haiku|Fable|Mythos|Code|\d)"i, log) && push!(errs, "a model-versioned trailer in the last 20 commits")
    row = findfirst(r -> r["id"] == "SCAN.REGISTER", scan_catalog())
    r = run_scan(ctx.cfg, scan_catalog()[row]; ledger = ctx.ledger)
    isempty(r.hits) || push!(errs, "$(length(r.hits)) knob/tweak hit(s) in prose")
    mk = joinpath(ctx.root, "docs", "make.jl")
    isfile(mk) && occursin("lint_inline_math", read(mk, String)) && push!(errs, "the June lint_inline_math in make.jl")
    isempty(errs) ? pass("POL.COLLAPSED") : fail("POL.COLLAPSED", join(errs, "; "))
end)
check!("GIT.BRANCH", ctx -> begin
    b = git(ctx, "rev-parse", "--abbrev-ref", "HEAD"); b === nothing && return na("GIT.BRANCH", "not a git repository")
    want = ctx.cfg["git"]["branch"]; errs = String[]
    b == want || push!(errs, "on $b, config says $want")
    origin = git(ctx, "remote", "get-url", "origin"); (origin === nothing || isempty(origin)) && push!(errs, "no origin remote")
    isempty(errs) ? pass("GIT.BRANCH", "$b, origin $origin") : fail("GIT.BRANCH", join(errs, "; "))
end)
check!("GIT.TRAILER", ctx -> begin
    log = git(ctx, "log", "-20", "--format=%H%x00%B%x01"); log === nothing && return na("GIT.TRAILER", "not a git repository")
    commits = filter(!isempty, split(log, '\x01'))
    missing_ = count(c -> !occursin("Co-Authored-By: Anthropic Claude <noreply@anthropic.com>", c), commits)
    # a FAIL, not a WARN: RULE.GIT.TRAILER is a rule, and a check that cannot fail is not a check
    missing_ == 0 ? pass("GIT.TRAILER", "last $(length(commits)) commits carry the trailer") : fail("GIT.TRAILER", "$missing_ of the last $(length(commits)) commits lack the versionless trailer")
end)
check!("ROUND.DIR", ctx -> begin
    isempty(ctx.cfg["instruments"]["enabled"]) && return pass("ROUND.DIR", "no instrument enabled")
    isdir(RoundFiles.rounds_dir(ctx.cfg)) ? pass("ROUND.DIR") : fail("ROUND.DIR", ".gbg/rounds/ absent while instruments are enabled (gbg init writes it with .keep)")
end)
check!("ROUND.MARKER", ctx -> begin
    bad = [r.name for r in RoundFiles.rounds(ctx.cfg) if r.state in (:nomarker, :invalid)]
    isempty(bad) ? pass("ROUND.MARKER") : fail("ROUND.MARKER", "round directories without a valid ROUND.toml: " * join(bad, ", "))
end)
check!("ROUND.OPEN", ctx -> begin
    open_ = [r.name for r in RoundFiles.rounds(ctx.cfg) if r.state == :open]
    isempty(open_) ? pass("ROUND.OPEN", "no open round") : warn("ROUND.OPEN", "open: " * join(open_, ", "))
end)
check!("ROUND.ABANDONED", ctx -> begin
    ab = [r for r in RoundFiles.rounds(ctx.cfg) if r.state == :abandoned]
    isempty(ab) ? pass("ROUND.ABANDONED") : warn("ROUND.ABANDONED", join(("$(r.name) carries $(length(r.round["abandoned"]["open_ids"])) open id(s)" for r in ab), "; "))
end)
# A round is stopped from closing at a dev stamp where that can still be acted on — `Preflight.dev_round`
# refuses to OPEN one. This reports what is already recorded, and a recorded round is frozen: FAILing on
# it made a fact about last week's round the reason `Pkg.test()` and every docs build refused today, with
# no verb able to clear it. What a release leans on is enforced in `Release.release`, on the one round it
# cites. An audit or hunt round at the tool root is off-tag by construction — it reads `base..HEAD` — so
# a dev stamp there is the normal case and never named here.
check!("ROUND.DEV", ctx -> begin
    docs = ("check-docs", "check-consistency")
    bad = [r.name for r in RoundFiles.rounds(ctx.cfg)
           if r.state == :closed && String(r.round["instrument"]) in docs && startswith(String(r.round["tool_version"]), "dev")]
    isempty(bad) ? pass("ROUND.DEV") :
        warn("ROUND.DEV", "closed at a dev stamp, so not comparable across versions and no release may cite " *
                          (length(bad) == 1 ? "it" : "them") * ": " * join(bad, ", "))
end)
check!("ROUND.FROZEN", ctx -> begin
    errs = String[]
    for r in RoundFiles.rounds(ctx.cfg)
        r.state == :closed || continue
        # the shas below cover the evidence, not the stamps, so a hand-edited `tool_version` passed
        # unseen — and re-stamping a round is the one repair that would falsify rather than fix it.
        # Every stamp form names its own revision, so they check each other.
        v = String(get(r.round, "tool_version", "")); rev = String(get(r.round, "tool_rev", ""))
        m = match(r"^dev\+([0-9a-f]{7,40})", v)
        if m !== nothing
            startswith(rev, m.captures[1]) || push!(errs, "$(r.name): tool_rev $rev does not begin with the revision tool_version $v names")
        elseif startswith(rev, "v")
            rev == "v" * v || push!(errs, "$(r.name): tool_rev $rev does not name tool_version $v")
        elseif occursin(r"^\d+\.\d+\.\d+(-rc\.\d+)?$", v) && ctx.tool_root !== nothing
            c = Git.run(ctx.tool_root, "rev-parse", "-q", "--verify", "refs/tags/v$v^{commit}")
            (c === nothing || c == rev) || push!(errs, "$(r.name): tool_version says v$v, whose tag is $(first(c, 8)), but tool_rev is $(first(rev, 8))")
        end
        fj = joinpath(r.dir, "findings.json")
        if haskey(r.round, "findings_sha")
            isfile(fj) && RoundFiles.sha256_file(fj) == r.round["findings_sha"] || push!(errs, "$(r.name): findings.json ≠ findings_sha")
        end
        if haskey(r.round, "reproductions_sha")
            # the disposition is recorded after bank and is excluded; any other field moving is the error
            RoundFiles.reproductions_sha(joinpath(r.dir, "reproductions")) == r.round["reproductions_sha"] ||
                push!(errs, "$(r.name): reproductions/ ≠ reproductions_sha (a verdict, witness sha or id changed since bank)")
        end
        cb = get(r.round, "closed_by", Dict())
        if haskey(cb, "tally_sha")
            k = r.round["passes"]; tj = joinpath(r.dir, "verdicts", "pass-$k", "tally.json")
            isfile(tj) && RoundFiles.sha256_file(tj) == cb["tally_sha"] || push!(errs, "$(r.name): tally.json ≠ the stored tally sha")
        end
    end
    isempty(errs) ? pass("ROUND.FROZEN") : fail("ROUND.FROZEN", join(errs, "; "))
end)
check!("AUDIT.GAP", ctx -> begin
    audits = sort!([r for r in RoundFiles.rounds(ctx.cfg) if r.state == :closed && r.round["instrument"] == "audit-changes"]; by = r -> r.round["opened"])
    gaps = String[]
    for i in 2:length(audits)
        get(audits[i].round, "base", "") == get(audits[i-1].round, "closed_head", audits[i-1].round["head"]) || push!(gaps, "$(audits[i].name) base ≠ $(audits[i-1].name) head")
    end
    # a gap between two audits is a WARN; NO audit at all is not contiguity, it is a repository whose
    # changes have never been audited, and the check said `pass` for it (found by the self-application sweep)
    isempty(audits) && return warn("AUDIT.GAP", "no closed audit-changes round: no change here has ever been audited")
    isempty(gaps) ? pass("AUDIT.GAP", "$(length(audits)) closed audit(s) contiguous") : warn("AUDIT.GAP", join(gaps, "; "))
end)

# --deep
function run_logged(ctx, cmd::Cmd)
    io = IOBuffer()
    ok = try
        Base.run(pipeline(setenv(cmd; dir = ctx.root), stdout = io, stderr = io)); true
    catch
        false
    end
    return (ok, String(take!(io)))
end
shell(cmdline) = `sh -c $cmdline`
check!("LOAD.ENVS", ctx -> begin
    errs = String[]; n = 0
    for e in tool_sub_envs(ctx.root)
        n += 1
        ok, log = run_logged(ctx, `$(Base.julia_cmd()) --startup-file=no --project=$(joinpath(ctx.root, e)) -e "using GBGCodingTools"`)
        ok || push!(errs, "$e: " * last(split(strip(log), '\n')))
    end
    isempty(errs) ? pass("LOAD.ENVS", "$n environment(s) load the tool") : fail("LOAD.ENVS", join(errs, "; "))
end)
check!("BUILD.DOCS", ctx -> begin
    # the frozen-build skip is exit 0 with the banner, so without this a skipped build would PASS
    ok, log = run_logged(ctx, addenv(shell(ctx.cfg["package"]["docs_build"]), "GBG_DOCS_NO_SKIP" => "1"))
    banner = occursin(r"GBGCodingTools v\S+ makedocs", log)
    ok && banner && return pass("BUILD.DOCS", "docs build exit 0 with the makedocs banner")
    fail("BUILD.DOCS", ok ? "exit 0 but no makedocs banner — the wrapper did not run" : "docs build failed: " * last(split(strip(log), '\n')))
end)
check!("SELF.DOCS", ctx -> begin
    (ctx.tool_root !== nothing && abspath(ctx.root) == ctx.tool_root) || return na("SELF.DOCS", "not the tool root")
    # a build skipped because a round is open is not a green build: the release checks read this one
    ok, log = run_logged(ctx, addenv(`$(Base.julia_cmd()) --startup-file=no --project=docs docs/make.jl`, "GBG_DOCS_NO_SKIP" => "1"))
    banner = occursin(r"GBGCodingTools v\S+ makedocs", log)
    ok && banner || return fail("SELF.DOCS", ok ? "no makedocs banner" : "the tool's docs build failed: " * last(split(strip(log), '\n')))
    ok2, log2 = run_logged(ctx, `$(Base.julia_cmd()) --startup-file=no --project=docs -e "using Pkg; d = first(v for (u, v) in Pkg.dependencies() if u == Base.UUID(\"3aee1de0-bb62-4679-b1c5-a861fbcaaa51\")); print(d.is_tracking_path)"`)
    strip(log2) == "true" || return fail("SELF.DOCS", "the docs environment does not track the working tree by path")
    pass("SELF.DOCS")
end)
check!("TEST.PKG", ctx -> begin
    ok, log = run_logged(ctx, shell(ctx.cfg["package"]["julia_test"]))
    banner = occursin(r"GBGCodingTools v\S+ gate", log)
    ok && banner && return pass("TEST.PKG", "Pkg.test() exit 0 with the gate banner")
    fail("TEST.PKG", ok ? "exit 0 but no gate banner — TestHarness.gate() did not run" : "tests failed: " * last(split(strip(log), '\n')))
end)
function witness_dirs(ctx, kind)
    dirs = [joinpath(r.dir, "witnesses", kind) for r in RoundFiles.rounds(ctx.cfg)]
    push!(dirs, joinpath(ctx.root, "test", "regressions", kind))
    return filter(isdir, dirs)
end
header_line(path, key) = (m = match(Regex("^#\\s*" * key * ":\\s*(.*)\$", "m"), read(path, String)); m === nothing ? "(no $key header)" : String(strip(m.captures[1])))
check!("WITNESSES.ESCALATED", ctx -> begin
    dirs = witness_dirs(ctx, "escalated"); isempty(dirs) && return pass("WITNESSES.ESCALATED", "none")
    notes = String[]; promote = String[]; stale = String[]
    for d in dirs
        _, results = Witnesses.run(d; expect = :fail, package = ctx.cfg["package"]["name"], project = joinpath(ctx.root, ctx.cfg["instruments"]["bug-hunt"]["witness_env"]), io = devnull)
        for r in results
            if r.status == :pass
                push!(promote, "$(r.name): PASSES — promote")
            elseif r.status in (:broken, :refused)
                push!(stale, "$(r.name): $(r.status) — stale ($(r.reason))")
            end
            push!(notes, "$(r.name) [$(r.status)] overturn_when: $(header_line(joinpath(d, r.name), "overturn_when"))")
        end
    end
    isempty(promote) && isempty(stale) && return pass("WITNESSES.ESCALATED", join(notes, "; "))
    isempty(stale) ? warn("WITNESSES.ESCALATED", join(promote, "; ")) : fail("WITNESSES.ESCALATED", join(vcat(stale, promote), "; "))
end)
check!("WITNESSES.BLOCKED", ctx -> begin
    dirs = witness_dirs(ctx, "blocked"); isempty(dirs) && return pass("WITNESSES.BLOCKED", "none")
    notes = String[]
    for d in dirs
        _, results = Witnesses.run(d; expect = :fail, package = ctx.cfg["package"]["name"], project = joinpath(ctx.root, ctx.cfg["instruments"]["bug-hunt"]["witness_env"]), io = devnull)
        for r in results; push!(notes, "$(r.name) [$(r.status)] blocked: $(header_line(joinpath(d, r.name), "blocked"))"); end
    end
    warn("WITNESSES.BLOCKED", join(notes, "; "))
end)

# ---- running -------------------------------------------------------------------------------------------------

exemptable(id) = any(p -> startswith(id, p), EXEMPTABLE)

"""
    select(only; deep = false) -> Vector{String}

The check ids a run covers. The arguments are:

- `only` — the ids the run is restricted to: exact ids, prefixes such as `LOAD` or `WIRE`, or the
  literal `QUICK`; every check when `nothing`.
- `deep` — include the deep checks in the default set (it does not filter the ids `only` names).

Returns the ids in table order.
"""
function select(only = nothing; deep::Bool = false)
    ids = [id for (id, _) in CHECKS if deep || !(id in DEEP)]
    only === nothing && return ids
    wanted = String[]
    for o in only
        if o == "QUICK"
            append!(wanted, QUICK)
        else
            append!(wanted, [id for (id, _) in CHECKS if id == o || startswith(id, o * ".") || startswith(id, o)])
        end
    end
    return [id for (id, _) in CHECKS if id in Set(wanted)]
end

"""
    run(cfg; only = nothing, deep = false, io = stdout, json = false, effective = false) -> (checks, code)

Runs the selected checks over a consumer and prints the table. The arguments are:

- `cfg` — the validated config.
- `only` — ids, id prefixes or the literal `QUICK` to restrict the run to; every non-deep check when
  `nothing`.
- `deep` — include the `--deep` checks (they run builds, tests and witnesses).
- `io` — where the report goes.
- `json` — print the results as JSON instead of the table.
- `effective` — print the effective config after the table.

A FAIL on an exemptable id that a live `scope = "check"` ledger entry names becomes a WARN carrying the
entry's reason. Returns the results and the exit code: 1 on any FAIL, else 0.
"""
function run(cfg::AbstractDict; only = nothing, deep::Bool = false, io::IO = stdout, json::Bool = false, effective::Bool = false)
    ctx = context(cfg; deep)
    ids = Set(select(only; deep))
    out = Check[]
    for (id, f) in CHECKS
        id in ids || continue
        c = try
            f(ctx)
        catch err
            fail(id, "check raised: " * sprint(showerror, err))
        end
        if c.status == :FAIL && exemptable(id)
            ex = Ledger.entries(ctx.ledger, id; scope = "check")
            isempty(ex) || (c = warn(id, "exempted — $(ex[1]["reason"]) [$(c.detail)]"))
        end
        push!(out, c)
    end
    if json
        JSON3.pretty(io, JSON3.write(Dict("checks" => [Dict("id" => c.id, "status" => String(c.status), "detail" => c.detail) for c in out],
                                           "effective" => effective ? Dict(k => v for (k, v) in cfg if k != "root") : nothing)))
        println(io)
    else
        for c in out
            println(io, "  ", rpad(String(c.status), 5), " ", rpad(c.id, 22), isempty(c.detail) ? "" : " " * c.detail)
        end
        nf = count(c -> c.status == :FAIL, out); nw = count(c -> c.status == :WARN, out)
        println(io, "doctor: $(length(out)) checks, $nf FAIL, $nw WARN", nf == 0 ? "." : " — exit 1.")
        effective && TOML.print(io, Dict{String,Any}(k => v for (k, v) in cfg if k != "root"); sorted = true)
    end
    return (out, any(c -> c.status == :FAIL, out) ? 1 : 0)
end

"""
    cmd_doctor(args) -> Int

`gbg doctor [--deep] [--json] [--effective] [--only <id-or-prefix>[,…]|QUICK]`: exit 2 when the
working directory is not a consumer (no valid `.gbg/config.toml`), else the run's code. Returns it.
"""
function cmd_doctor(args)
    o = parse_options(args; valued = ["only"])
    cfg = try
        Config.read()
    catch err
        err isa Config.ConfigError || rethrow()
        println("  FAIL  CFG.VALID              ", sprint(showerror, err)); println("doctor: not a consumer — exit 2."); return 2
    end
    only = haskey(o.values, "only") ? String.(split(o.values["only"], ',')) : nothing
    _, code = run(cfg; only, deep = "deep" in o.flags, json = "json" in o.flags, effective = "effective" in o.flags)
    return code
end
VERBS["doctor"] = cmd_doctor

end # module Doctor

"""
    doctor(cfg, set = :QUICK; io = stderr) -> Int

The in-process doctor the `makedocs` wrapper, `TestHarness.gate()` and `gbg preflight` call. The
arguments are:

- `cfg` — the validated config.
- `set` — `:QUICK` for the quick set, `:ALL` for every non-deep check.
- `io` — where the failing lines are printed.

Returns 1 on any FAIL, else 0.
"""
function doctor(cfg::AbstractDict, set::Symbol = :QUICK; io::IO = stderr)
    buf = IOBuffer()
    checks, code = Doctor.run(cfg; only = set == :QUICK ? ["QUICK"] : nothing, io = buf)
    if code != 0
        println(io, "gbg doctor --only $(set):")
        for c in checks
            c.status == :FAIL && println(io, "  FAIL  ", rpad(c.id, 22), " ", c.detail)
        end
    end
    return code
end
