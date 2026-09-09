# Rounds.jl — the `gbg round` verbs that run BEFORE verification: prepare, build, test, bank, rerun, list,
# render, abandon (ARCHITECTURE §6; the passes are Passes.jl). Every verb runs `gbg self verify` and
# `CFG.TORN` first and refuses a changed `config_sha` (exit 2 → `pass open --regrade`).

"""
    Rounds

The round store's writers before verification. [`Rounds.prepare`](@ref) builds, consolidates, scans or
diffs as the instrument needs (one of the four review procedures [`GBGCodingTools`](@ref) binds); [`Rounds.bank`](@ref) validates the lane files, classifies dead lanes,
assigns ids, marks seeds and freezes `findings.json`; [`Rounds.rerun`](@ref) re-launches dead lanes;
[`Rounds.abandon`](@ref) is the only wholesale exit. `build` and `test` run the consumer's commands
under `GBG_ROUND` so the gate inside them ignores this round.
"""
module Rounds

using TOML, JSON3, Dates, SHA
using ..GBGCodingTools: GBGCodingTools, Config, Ledger, Sync, RoundFiles, Git, Preflight, Seeds, Recall, Witnesses,
      parse_options, VERBS, self_verify, load_schema, instrument_schema, validate, consolidate, scan_docs, scan_html,
      scan_catalog, run_scan, Reflection, ScanResult

struct RoundError <: Exception
    msg::String
end
Base.showerror(io::IO, e::RoundError) = print(io, "round: ", e.msg)

# ---- common ------------------------------------------------------------------------------------------------

"""
    load(cfg, round) -> (dir, record)

The round directory and its parsed `ROUND.toml`; a `RoundError` when absent.
"""
function load(cfg::AbstractDict, round::AbstractString)
    dir = Preflight.round_dir(cfg, round)
    r = RoundFiles.read_round(dir)
    r === nothing && throw(RoundError("no round $round under .gbg/rounds/ (no ROUND.toml)"))
    return (dir, r)
end

function save(dir::AbstractString, rec::AbstractDict)
    errs = validate(load_schema("round"), rec)
    isempty(errs) || throw(RoundError("ROUND.toml would not validate (a tool defect):\n  " * join(errs, "\n  ")))
    open(joinpath(dir, "ROUND.toml"), "w") do f
        println(f, "# ROUND.toml — written by the gbg round verbs; never edited by hand (ARCHITECTURE §6.1)")
        TOML.print(f, rec)
    end
end

"""
    guard(cfg, round; io = stderr, allow_config_change = false, need_open = true) -> (dir, record)

What every `round` verb does first. The arguments are:

- `cfg` — the validated config.
- `round` — the round id.
- `io` — where a torn file is named.
- `allow_config_change` — accept a `config_sha` that moved since the round opened (regrade, abandon,
  close).
- `need_open` — require the round to be open.

It runs `gbg self verify` (exit 2 on mismatch) and `CFG.TORN`, loads the round, and checks its
`config_sha` (else exit 2 with the `pass open --regrade` hint). Throws a `RoundError` carrying the
message; the CLI prints it and returns 2. Returns the directory and the record.
"""
function guard(cfg::AbstractDict, round::AbstractString; io::IO = stderr, allow_config_change::Bool = false, need_open::Bool = true)
    sv = self_verify(cfg["root"]; io = devnull)
    sv == 0 || throw(RoundError("gbg self verify exit $sv — the running copy is not the pinned one"))
    Preflight.torn_check(cfg; io) || throw(RoundError("CFG.TORN — a pinned or managed file is modified in the working tree; wait for the sync or commit"))
    dir, rec = load(cfg, round)
    need_open && RoundFiles.state(rec) != :open && throw(RoundError("$round is $(RoundFiles.state(rec)); the verb needs an open round"))
    if !allow_config_change && Preflight.config_sha(cfg) != rec["config_sha"]
        throw(RoundError("the config changed since $round opened (config.toml, hats or the ledger) — `gbg round pass open $round --regrade` re-stamps it"))
    end
    return (dir, rec)
end

timestamp() = Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS")

"""
    run_under_round(cfg, round, cmdline; log) -> Int

Runs a shell command line from the consumer root with `GBG_ROUND=<round>` exported, its output tee'd
into a log. The arguments are:

- `cfg` — the validated config.
- `round` — the round the gate must ignore.
- `cmdline` — the command line (`sh -c`).
- `log` — the log file.

Returns the exit code.
"""
function run_under_round(cfg::AbstractDict, round::AbstractString, cmdline::AbstractString; log::AbstractString)
    mkpath(dirname(log))
    cmd = setenv(`sh -c $cmdline`, merge(ENV, Dict("GBG_ROUND" => round)); dir = cfg["root"])
    code = open(log, "w") do lf
        p = Base.run(pipeline(cmd; stdout = lf, stderr = lf); wait = false)
        wait(p); p.exitcode
    end
    return code
end

roster_lanes(rec) = [r for r in rec["roster"] if !get(r, "not_applicable", false)]

# ---- prepare -----------------------------------------------------------------------------------------------

function consolidate_to(cfg, round, tag)
    build = joinpath(cfg["root"], cfg["surfaces"]["built_html"])
    pd = Preflight.payload_dir(cfg, round); mkpath(pd)
    full = joinpath(pd, "manuscript-full$(tag).md"); site = joinpath(pd, "manuscript-siteonly$(tag).md")
    n, nf, ns = consolidate(build, String.(cfg["instruments"]["check-consistency"]["design_docs_withheld"]); out_full = full, out_siteonly = site)
    return (full, site, n, nf, ns)
end

function scan_finding(r::ScanResult, h)
    fam = split(r.rule, '.')
    type = length(fam) >= 2 && fam[2] == "TEX" ? "notation" : length(fam) >= 2 && fam[2] == "CIT" ? "citation" :
           r.rule == "RULE.DOC.CURRENT" ? "currency" : startswith(r.rule, "RULE.DOC") ? "structure" : "style"
    Dict{String,Any}("type" => type, "severity" => "major", "confidence" => "high",
        "title" => "$(r.id) — $(r.rule): $(first(h.text, 80))",
        "locations" => [h.line > 0 ? "$(h.file):$(h.line): $(h.text)" : "$(h.file): $(h.text)"],
        "description" => "Hard scan hit of $(r.id) (rule $(r.rule)); banked by the CLI as lane 00-scans and closed by rescan when the scan no longer fires — never by a graded verdict.",
        "resolution_hint" => "Fix the class across every surface, then `gbg round grade` re-runs the scan.")
end

"""
    prepare(cfg, round; io = stdout) -> Int

`gbg round prepare <round>`, by instrument ([`GBGCodingTools`](@ref) binds the term). The arguments are:

- `cfg` — the validated config.
- `round` — the round id.
- `io` — where the report goes.

check-consistency: the docs build under `GBG_ROUND` (exit 0 required; the log path is printed
otherwise), the two manuscripts consolidated into the payload directory, and — when the round is
seeded — the seeds planted in place (ground truth NOT written). check-docs: `scan docs` with every
hard hit banked as lane `00-scans`, the reflection checks, the build under `GBG_ROUND`, `scan html`
(its hard hits banked too), the full report saved. audit-changes: the diff, diffstat and claims
regenerated. bug-hunt: nothing to prepare. Returns the exit code.
"""
function prepare(cfg::AbstractDict, round::AbstractString; io::IO = stdout)
    dir, rec = guard(cfg, round; io)
    inst = rec["instrument"]; root = cfg["root"]; scratch = Preflight.scratch_dir(cfg, round)
    if inst == "check-consistency"
        log = joinpath(scratch, "build.log")
        code = run_under_round(cfg, round, cfg["package"]["docs_build"]; log)
        code == 0 || (println(io, "prepare: the docs build failed (exit $code) — see $log"); return 2)
        for post in cfg["package"]["docs_post"]; run_under_round(cfg, round, post; log = joinpath(scratch, "docs_post.log")); end
        full, site, n, nf, ns = consolidate_to(cfg, round, "")
        println(io, "prepare: $n pages consolidated → $(basename(full)) ($nf chars), $(basename(site)) ($ns chars)")
        if haskey(rec, "seed_salt")
            cat = Seeds.read_catalog(joinpath(root, cfg["instruments"]["check-consistency"]["seed_catalog"]))
            f = read(full, String); s = read(site, String)
            plan, skipped = Seeds.select(cat, f, rec["seed_salt"])
            f2, s2 = Seeds.plant(f, s, plan)
            write(full, f2); write(site, s2)
            println(io, "prepare: $(length(plan)) seed(s) planted (salt $(rec["seed_salt"]))", isempty(skipped) ? "" : "; skipped classes (anchor absent): " * join(skipped, ", "))
            println(io, "         the payload directory now holds the SEEDED copies only; the ground truth is written at bank — do not open the manuscripts yourself")
        end
        return 0
    elseif inst == "check-docs"
        report = joinpath(scratch, "scans.txt"); mkpath(scratch)
        banked = Dict{String,Any}[]
        open(report, "w") do rio
            results, _ = scan_docs(cfg; io = rio)
            for r in results
                r.tier == "hard" || continue
                # measured nothing ⇒ DEAD, hits or no hits; the hits are still banked below, and a scan
                # that hit while counting zero is a scan whose own counter is wrong — the same in `report`
                (r.population == 0 && r.exempted == 0) && println(io, "prepare: DEAD scan $(r.id) — $(r.note)")
                for h in r.hits; push!(banked, scan_finding(r, h)); end
            end
            println(rio, "\n=== REFLECTION CHECKS ===")
            for (name, f) in (("signature_fidelity", () -> Reflection.signature_fidelity(cfg)), ("dupref", () -> string.(Reflection.dupref(cfg))), ("xlink (dry run)", () -> string.(Reflection.xlink(cfg; apply = false))))
                try
                    rows = f(); println(rio, "  ", lpad(length(rows), 4), "  ", name); foreach(x -> println(rio, "          ", x), rows)
                catch err
                    println(rio, "  DEAD  ", name, " — ", sprint(showerror, err))
                end
            end
        end
        log = joinpath(scratch, "build.log")
        code = run_under_round(cfg, round, cfg["package"]["docs_build"]; log)
        code == 0 || (println(io, "prepare: the docs build failed (exit $code) — see $log; the scans so far are in $report"); return 2)
        open(report, "a") do rio
            println(rio, "\n=== BUILT HTML ===")
            results, _ = scan_html(cfg, joinpath(root, cfg["surfaces"]["built_html"]); io = rio)
            for r in results, h in r.hits; push!(banked, scan_finding(r, h)); end
        end
        lane = Dict{String,Any}("schema_version" => 1, "round" => round, "lane" => "scans", "candidates_found" => length(banked),
                                "checked" => ["scan docs", "scan html", "reflection checks"], "findings" => banked)
        mkpath(joinpath(dir, "findings"))
        open(joinpath(dir, "findings", "00-scans.json"), "w") do f; JSON3.pretty(f, JSON3.write(lane)); println(f); end
        println(io, "prepare: $(length(banked)) hard scan hit(s) banked as lane 00-scans (key `scans`); the full report (every triage line) is $report — read ALL of it")
        return 0
    elseif inst == "audit-changes"
        roster = [Dict{String,Any}(r) for r in rec["roster"]]
        Preflight.write_payloads(cfg, inst, round, Preflight.resolve_audit_lanes(cfg, Preflight.audit_kind(cfg, rec["base"])); base = rec["base"])
        println(io, "prepare: diff, diffstat and claims regenerated for $(rec["base"])..HEAD under $(Preflight.payload_dir(cfg, round))")
        return 0
    else
        mkpath(joinpath(dir, "witnesses")); println(io, "prepare: nothing to prepare for a hunt; launch the Workflow call preflight printed"); return 0
    end
end

"""
    build(cfg, round; io = stdout) -> Int

`gbg round build <round>`: the consumer's `docs_build` under `GBG_ROUND`, the log under the round's
scratch. The arguments are:

- `cfg` — the validated config.
- `round` — the round id.
- `io` — where the exit and the log path are printed.

Returns the command's exit code; [`test`](@ref) is its twin for `julia_test`.
"""
function build(cfg::AbstractDict, round::AbstractString; io::IO = stdout)
    guard(cfg, round; io)
    log = joinpath(Preflight.scratch_dir(cfg, round), "build.log")
    code = run_under_round(cfg, round, cfg["package"]["docs_build"]; log)
    println(io, "build: exit $code — $log"); return code
end
"""
    test(cfg, round; io = stdout) -> Int

`gbg round test <round>`: the consumer's `julia_test` under `GBG_ROUND`, the log under the round's
scratch. The arguments are:

- `cfg` — the validated config.
- `round` — the round id.
- `io` — where the exit and the log path are printed.

Returns the command's exit code.
"""
function test(cfg::AbstractDict, round::AbstractString; io::IO = stdout)
    guard(cfg, round; io)
    log = joinpath(Preflight.scratch_dir(cfg, round), "test.log")
    code = run_under_round(cfg, round, cfg["package"]["julia_test"]; log)
    println(io, "test: exit $code — $log"); return code
end

# ---- bank --------------------------------------------------------------------------------------------------

"""
    classify_lane(dir, inst, lane; first_sha = nothing) -> (status, data, sha, note)

Classifies one lane file. The arguments are:

- `dir` — the round directory.
- `inst` — the instrument (its lane-file schema).
- `lane` — the roster entry (`nn`, `key`).
- `first_sha` — the file's sha at first sight, when the bank has seen it before.

The status is `:dead` (absent, or — renamed to `<name>.rejected.json` beside itself — unparsable or
invalid), `:rejected`
(present but its sha changed since first sight), `:empty` (zero findings, non-empty checked),
`:truncated` (candidates_found > findings), or `:live`. Returns the status, the parsed object (or
nothing), the file's sha and a note.
"""
function classify_lane(dir::AbstractString, inst::AbstractString, lane::AbstractDict; first_sha = nothing)
    p = joinpath(dir, "findings", "$(lane["nn"])-$(lane["key"]).json")
    isfile(p) || return (:dead, nothing, nothing, "absent")
    sha = RoundFiles.sha256_file(p)
    first_sha !== nothing && first_sha != sha && return (:rejected, nothing, sha, "changed since first sight")
    data = try JSON3.read(read(p, String), Dict{String,Any}) catch err; nothing end
    if data === nothing
        mv(p, replace(p, ".json" => ".rejected.json"); force = true); return (:dead, nothing, sha, "unparsable (quarantined)")
    end
    schema = instrument_schema(inst)
    errs = validate(schema["properties"]["lane_file"], data; root = schema)
    if !isempty(errs)
        mv(p, replace(p, ".json" => ".rejected.json"); force = true)
        return (:dead, nothing, sha, "invalid (quarantined): " * first(errs))
    end
    data["lane"] == lane["key"] || (mv(p, replace(p, ".json" => ".rejected.json"); force = true); return (:dead, nothing, sha, "lane field $(data["lane"]) ≠ $(lane["key"])"))
    n = length(data["findings"])
    (n == 0 && isempty(get(data, "checked", []))) && return (:dead, data, sha, "zero findings AND empty checked[] — a dead lane, not a clean one")
    n == 0 && return (:empty, data, sha, "")
    get(data, "candidates_found", 0) > n && return (:truncated, data, sha, "weighed $(data["candidates_found"]), reported $n")
    return (:live, data, sha, "")
end

expected_lanes(rec) = vcat(rec["instrument"] == "check-docs" ? [Dict("nn" => "00", "key" => "scans")] : Dict{String,Any}[],
                           [Dict("nn" => lpad(i, 2, '0'), "key" => r["key"]) for (i, r) in enumerate(rec["roster"]) if !get(r, "not_applicable", false)])

function render_findings_md(dir, round, findings)
    io = IOBuffer()
    println(io, "# Findings — $round\n\nThe work list, by id. Fix the CLASS, not the line; a seeded finding (marked) is never fixed in the corpus.\n")
    for lane in unique(f["lane"] for f in findings)
        println(io, "## lane $lane\n")
        for f in filter(f -> f["lane"] == lane, findings)
            seeded = get(f, "seeded", false) ? "  **[SEEDED — $(get(f, "seed_class", ""))]**" : ""
            println(io, "### `$(f["id"])` [$(f["severity"])/$(f["confidence"])] $(f["title"])$seeded\n")
            for l in f["locations"]; println(io, "- $l"); end
            haskey(f, "contradicts") && !isempty(f["contradicts"]) && println(io, "- contradicts: $(f["contradicts"])")
            println(io, "\n$(f["description"])\n")
            haskey(f, "resolution_hint") && !isempty(f["resolution_hint"]) && println(io, "_hint:_ $(f["resolution_hint"])\n")
        end
    end
    write(joinpath(dir, "findings.md"), String(take!(io)))
end

normtitle(t) = lowercase(replace(t, r"[^\p{L}\p{N} ]" => "", r"\s+" => " "))
const SEV_RANK = Dict("blocker" => 4, "major" => 3, "minor" => 2, "nit" => 1)

function render_summary_md(dir, round, findings, rec, statuses)
    n_hats = count(r -> !get(r, "not_applicable", false), rec["roster"])
    groups = Dict{String,Vector{Any}}()
    for f in findings
        get(f, "seeded", false) && continue
        push!(get!(groups, normtitle(f["title"]), Any[]), f)
    end
    rows = [(maximum(SEV_RANK[f["severity"]] for f in g) * length(unique(f["lane"] for f in g)), g) for g in values(groups)]
    sort!(rows; by = first, rev = true)
    io = IOBuffer()
    println(io, "# SUMMARY — $round (a reading aid, never the input to a fix pass)\n")
    println(io, "$(length(findings)) findings banked, $(count(f -> get(f, "seeded", false), findings)) seeded (subtracted below), $(length(rows)) distinct after deduplication by title; ranked by severity × corroboration (k of $n_hats lanes).\n")
    capped = [l for (l, s) in statuses if s == :truncated]
    isempty(capped) || println(io, "Capped lanes (candidates_found > reported; re-run narrowed if needed): ", join(capped, ", "), "\n")
    for (score, g) in rows
        lanes = unique(f["lane"] for f in g)
        println(io, "- **$(g[1]["severity"])** ($(length(lanes))/$n_hats: $(join(lanes, ", "))) $(g[1]["title"]) — ", join(("`$(f["id"])`" for f in g), " "))
    end
    write(joinpath(dir, "SUMMARY.md"), String(take!(io)))
end

"""
    bank(cfg, round; io = stdout) -> Int

`gbg round bank <round>`. The arguments are:

- `cfg` — the validated config.
- `round` — the round id.
- `io` — where the classification and the recall are printed.

It validates every expected lane file, records each classified file's sha at first sight (`lane_shas`;
a DEAD lane's file is not recorded, and [`Rounds.rerun`](@ref) forgets the sha of a lane it re-runs),
classifies (DEAD, REJECTED, EMPTY, TRUNCATED), assigns ids `<round>/<lane>#<n>`; for a seeded round
regenerates the unseeded manuscripts, recomputes the ground truth, marks seeded findings, prints recall
per class and SUSPECT hats; for a hunt runs the witness runner over `witnesses/` expecting failure and
freezes the disposition records; writes `findings.json` and `findings_sha`, `findings.md` and
`SUMMARY.md`. Any DEAD lane ⇒ exit 2 and nothing frozen (`lane_shas` stays). Returns the exit code.
"""
function bank(cfg::AbstractDict, round::AbstractString; io::IO = stdout)
    dir, rec = guard(cfg, round; io)
    haskey(rec, "banked") && (println(io, "bank: $round is already banked (findings.json is frozen); the closure loop is pass open → grade"); return 2)
    inst = rec["instrument"]
    lanes = expected_lanes(rec)
    shas = get(rec, "lane_shas", Dict{String,Any}())
    statuses = Dict{String,Symbol}(); datas = Dict{String,Any}(); notes = String[]
    for l in lanes
        st, data, sha, note = classify_lane(dir, inst, l; first_sha = get(shas, l["key"], nothing))
        # first sight is recorded for a file that classified (a quarantined one is gone; its re-run replaces it)
        st in (:rejected, :dead) || sha === nothing || haskey(shas, l["key"]) || (shas[l["key"]] = sha)
        statuses[l["key"]] = st; datas[l["key"]] = data
        println(io, "  ", rpad(uppercase(String(st)), 10), l["nn"], "-", l["key"], isempty(note) ? "" : "  — " * note)
    end
    rec["lane_shas"] = shas
    dead = [k for (k, s) in statuses if s in (:dead, :rejected)]
    rec["dead_lanes"] = sort!(dead)
    if !isempty(dead)
        save(dir, rec)
        println(io, "bank: $(length(dead)) DEAD/REJECTED lane(s) — nothing frozen. Re-run only them: gbg round rerun $round --lanes ", join(dead, ","))
        return 2
    end
    findings = Dict{String,Any}[]
    for l in lanes
        data = datas[l["key"]]; data === nothing && continue
        for (n, f) in enumerate(data["findings"])
            g = Dict{String,Any}(f); g["id"] = "$round/$(l["key"])#$n"; g["lane"] = l["key"]; g["n"] = n; g["seeded"] = false
            push!(findings, g)
        end
    end
    bankrec = Dict{String,Any}("suspect_hats" => String[], "recall" => Dict{String,Any}(), "statuses" => Dict(k => String(v) for (k, v) in statuses))
    if inst == "check-consistency" && haskey(rec, "seed_salt")
        full, site, _, _, _ = consolidate_to(cfg, round, ".unseeded")
        cat = Seeds.read_catalog(joinpath(cfg["root"], cfg["instruments"]["check-consistency"]["seed_catalog"]))
        plan, skipped = Seeds.select(cat, read(full, String), rec["seed_salt"])
        gt = Dict{String,Any}("schema_version" => 1, "round" => round, "salt" => rec["seed_salt"], "skipped" => skipped,
                              "seeded" => [Dict("id" => s["id"], "class" => s["class"], "page" => s["page"], "original_context" => s["original_context"], "mutated_context" => s["mutated_context"]) for s in plan])
        errs = validate(load_schema("ground-truth"), gt)          # the schema existed and nothing read it
        isempty(errs) || throw(RoundError("ground_truth.json would not validate: " * join(errs, "; ")))
        open(joinpath(dir, "ground_truth.json"), "w") do f; JSON3.pretty(f, JSON3.write(gt)); println(f); end
        marked = Recall.mark!(findings, Dict("seeded" => plan, "skipped" => skipped))
        recall = Recall.per_class(findings, Dict("seeded" => plan, "skipped" => skipped))
        site_pages = Set(m.captures[1] for m in eachmatch(r"===== PAGE: (.+?) =====", read(site, String)))
        suspect = Recall.suspect_hats(findings, Dict("seeded" => plan), rec["roster"], site_pages)
        bankrec["recall"] = recall; bankrec["suspect_hats"] = suspect
        println(io, "bank: recall per class — ", join(("$c: " * (v isa AbstractDict ? "$(v["found"])/$(v["planted"])" : "UNDEFINED") for (c, v) in sort!(collect(recall); by = first)), ", "))
        isempty(suspect) || println(io, "bank: SUSPECT hats (≥ 2 seeds on their substrate, zero matches): ", join(suspect, ", "))
        println(io, "bank: $marked seeded finding(s) marked; they are never fixed in the corpus")
    end
    if inst == "bug-hunt"
        code = hunt_bank!(cfg, dir, rec, findings; io)
        code == 0 || return code
    end
    # The schema existed and nothing validated against it. It is the CORE finding shape: an instrument's
    # own schema `$ref`s it and adds its own fields (bug-hunt's `kind`, `verdict`, `file`, `line`,
    # `mechanism`, …), and `bank` adds `id`, `lane`, `n`, `seeded`. Since the core schema closes its
    # property set, every finding is projected onto the keys the core names before it is checked; the
    # instrument's own fields were already validated against its own schema at `classify_lane`.
    core = load_schema("finding"); coreprops = keys(core["properties"])
    for f in findings
        errs = validate(core, Dict{String,Any}(k => v for (k, v) in f if k in coreprops))
        # exit 2, never a throw: every other refusal in bank names its reason and leaves a next step,
        # and this one fires after the whole panel and every witness have already been paid for
        isempty(errs) || (println(io, "bank: banked finding $(get(f, "id", "?")) does not validate: ", first(errs),
                                  " — fix the lane file and gbg round rerun $round --lanes $(get(f, "lane", "?"))"); return 2)
    end
    open(joinpath(dir, "findings.json"), "w") do f
        JSON3.pretty(f, JSON3.write(Dict("schema_version" => 1, "round" => round, "findings" => findings))); println(f)
    end
    rec["findings_sha"] = RoundFiles.sha256_file(joinpath(dir, "findings.json"))
    rec["banked"] = timestamp()
    open(joinpath(dir, "bank.json"), "w") do f; JSON3.pretty(f, JSON3.write(bankrec)); println(f); end
    save(dir, rec)
    render_findings_md(dir, round, findings)
    render_summary_md(dir, round, findings, rec, statuses)
    println(io, "bank: $(length(findings)) finding(s) frozen in findings.json (sha $(rec["findings_sha"][1:12])); findings.md is the work list, SUMMARY.md the reading aid")
    println(io, "NEXT: the fix pass on the owner's word, then gbg round pass open $round")
    return 0
end

"""
    hunt_bank!(cfg, dir, rec, findings; io = stdout) -> Int

The hunt's bank. The arguments are:

- `cfg` — the validated config.
- `dir` — the round directory.
- `rec` — the round record (it gains `reproductions_sha`).
- `findings` — the candidates, reduced in place to the confirmed set.
- `io` — where the runner reports.

It runs `Witnesses.run(witnesses/; expect = :fail)`; a REPRODUCED finding whose witness does not fail
mechanically is REJECTED (recorded as WITNESS-WRONG); the sha of each failing witness body is recorded;
a witness that ERRORED and carries a `# blocked:` header becomes BLOCKED and moves to
`witnesses/blocked/`; every candidate gets a `reproductions/<id>.json` record, frozen. Returns 0, or 2
when the runner refuses.
"""
function hunt_bank!(cfg::AbstractDict, dir::AbstractString, rec::AbstractDict, findings::Vector{Dict{String,Any}}; io::IO = stdout)
    wdir = joinpath(dir, "witnesses"); mkpath(wdir)
    project = Witnesses.witness_project(cfg["root"], cfg["instruments"]["bug-hunt"]["witness_env"], cfg["package"]["name"])
    results = Witnesses.WitnessResult[]
    if any(f -> endswith(f, ".jl"), readdir(wdir))
        code, results = Witnesses.run(wdir; expect = :fail, package = cfg["package"]["name"], project, io)
        any(r -> r.status == :refused, results) && (println(io, "bank: a witness loads what it may not (REFUSED) — fix it before anything is banked"); return 2)
    end
    byname = Dict(r.name => r for r in results)
    rdir = joinpath(dir, "reproductions"); mkpath(rdir)
    confirmed = Dict{String,Any}[]
    for f in findings
        wp = get(f, "witness_path", ""); wname = basename(wp)
        r = get(byname, wname, nothing)
        verdict = f["verdict"]
        if verdict == "REPRODUCED"
            if r === nothing || r.status != :fail
                verdict = "WITNESS-WRONG"; f["observed"] = "REJECTED at bank: the witness $(isempty(wname) ? "(none named)" : wname) did not fail mechanically ($(r === nothing ? "not found" : String(r.status))); " * f["observed"]
            end
        elseif verdict == "BLOCKED"
            if r !== nothing && r.status == :blocked
                mkpath(joinpath(wdir, "blocked")); mv(joinpath(wdir, wname), joinpath(wdir, "blocked", wname); force = true)
            else
                verdict = "NOT-REPRODUCED"; f["observed"] = "BLOCKED refused at bank: no `# blocked:` header or the witness was observed to FAIL/PASS; " * f["observed"]
            end
        end
        f["verdict"] = verdict
        rep = Dict{String,Any}("schema_version" => 1, "id" => f["id"], "title" => f["title"], "kind" => f["kind"], "severity" => f["severity"],
                               "verdict" => verdict, "observed" => f["observed"], "evidence" => get(f, "evidence", ""))
        !isempty(wp) && (rep["witness_path"] = relpath(joinpath(wdir, wname), dir))
        verdict == "REPRODUCED" && (rep["witness_sha256"] = bytes2hex(sha256(read(joinpath(wdir, wname)))))
        haskey(f, "docs_url") && !isempty(f["docs_url"]) && (rep["docs_url"] = f["docs_url"])
        verdict in ("REPRODUCED", "EVIDENCED") && (rep["disposition"] = Dict("state" => "open"); push!(confirmed, f))
        errs = validate(load_schema("reproduction"), rep)         # likewise: written, never validated
        isempty(errs) || throw(RoundError("the reproduction record of $(f["id"]) would not validate: " * join(errs, "; ")))
        name = replace(f["id"], "/" => "__", "#" => "_")
        open(joinpath(rdir, name * ".json"), "w") do fh; JSON3.pretty(fh, JSON3.write(rep)); println(fh); end
    end
    rec["reproductions_sha"] = bytes2hex(sha256(join(sort!([read(joinpath(rdir, f), String) for f in readdir(rdir)]), "\n")))
    println(io, "bank: $(length(confirmed)) confirmed (REPRODUCED ∪ EVIDENCED) of $(length(findings)) candidates; disposition records frozen (reproductions_sha $(rec["reproductions_sha"][1:12]))")
    empty!(findings); append!(findings, confirmed)
    return 0
end

# ---- rerun, list, render, abandon ----------------------------------------------------------------------------

"""
    rerun(cfg, round, lanes; io = stdout) -> Int

`gbg round rerun <round> --lanes a,b`: prints the call to the instrument's Workflow (its `workflow/*.js`
script) restricted to the lanes
the last bank classified DEAD. The arguments are:

- `cfg` — the validated config.
- `round` — the round id.
- `lanes` — the lane keys.
- `io` — where the call is printed.

A live lane is refused; the first-sight sha of each named lane is forgotten, since the re-run replaces
its file. Returns the exit code.
"""
function rerun(cfg::AbstractDict, round::AbstractString, lanes::AbstractVector{<:AbstractString}; io::IO = stdout)
    dir, rec = guard(cfg, round; io)
    dead = Set(String.(rec["dead_lanes"]))
    bad = [l for l in lanes if !(l in dead)]
    isempty(bad) || (println(io, "rerun: refused — not classified DEAD by the last bank: ", join(bad, ", "), " (a live lane is never re-run)"); return 2)
    argp = joinpath(Preflight.workflow_dir(cfg, round), "main.args.json")
    isfile(argp) || (println(io, "rerun: no saved args for $round"); return 2)
    a = JSON3.read(read(argp, String), Dict{String,Any})
    key = rec["instrument"] == "check-consistency" ? "hats" : "lanes"
    a[key] = [x for x in a[key] if x["key"] in lanes]
    isempty(a[key]) && (println(io, "rerun: none of the named lanes is in the round's roster"); return 2)
    Preflight.save_args(cfg, round, "rerun", a)
    # the re-run replaces the lane file: its first-sight sha (if any was kept) no longer guards anything
    shas = get(rec, "lane_shas", Dict{String,Any}()); for l in lanes; delete!(shas, l); end; rec["lane_shas"] = shas; save(dir, rec)
    println(io, "Launch exactly this, then gbg round bank $round again:\n")
    println(io, Preflight.workflow_call(joinpath(Preflight.workflow_dir(cfg, round), Preflight.main_script(rec["instrument"])), a))
    return 0
end

"""
    import_empty(cfg, round, reason; io = stdout) -> Int

`gbg round import --empty <round> --reason "…"`: writes a round holding only an abandoned `ROUND.toml`
and an `import.json` with `source = "none"` — the Step-0 scratch form for a legacy pile that yields
nothing. The arguments are:

- `cfg` — the validated config.
- `round` — the round id to create (refused when it exists).
- `reason` — the abandon reason.
- `io` — where the outcome is printed.

The six legacy pile readers (`pf-doc-review`, `pf-check-docs`, `pf-findings-json`, `it-closure`,
`it-audit-latest`, `it-rounds-json`) are Phase 2's scratch tools and are written when those imports
run; until then `gbg round import <pile>` refuses, naming this. Returns the exit code.
"""
function import_empty(cfg::AbstractDict, round::AbstractString, reason::AbstractString; io::IO = stdout)
    occursin(r"^\d{4}-\d{2}-\d{2}-(check-docs|check-consistency|bug-hunt|audit-changes)-\d{2}$", round) || (println(io, "import: $round is not a round id <date>-<instrument>-<NN>"); return 2)
    length(strip(reason)) >= 12 || (println(io, "import --empty needs --reason (≥ 12 characters)"); return 2)
    dir = Preflight.round_dir(cfg, round)
    isdir(dir) && (println(io, "import: $round exists; an existing round is never overwritten"); return 2)
    mkpath(dir)
    inst = match(r"-(check-docs|check-consistency|bug-hunt|audit-changes)-", round).captures[1]
    st = Preflight.stamps(cfg)
    rec = merge(st, Dict{String,Any}("round" => round, "instrument" => inst, "schema_version" => 1, "head" => something(Git.head(cfg["root"]), "0"^40),
        "roster" => Any[], "cost" => "economy", "strength" => "economy", "hostname" => gethostname(), "model_hint" => Preflight.economy_model(),
        "opened" => timestamp(), "dead_lanes" => String[], "passes" => 0, "abandoned" => Dict("reason" => reason, "open_ids" => String[])))
    save(dir, rec)
    imp = Dict{String,Any}("schema_version" => 1, "source" => "none", "format" => "none", "title_to_id" => Dict{String,Any}(),
                           "imported" => timestamp(), "reason" => reason)
    errs = validate(load_schema("import"), imp)                  # the schema existed and nothing validated against it
    isempty(errs) || throw(RoundError("import.json would not validate: " * first(errs)))
    open(joinpath(dir, "import.json"), "w") do f
        JSON3.pretty(f, JSON3.write(imp)); println(f)
    end
    println(io, "import --empty: $round written (abandoned, source none) — a Step-0 scratch round; never commit it (ARCHITECTURE Revision 8)")
    return 0
end

"""
    list(cfg; io = stdout) -> Int

`gbg round list`: one line per round — state, instrument, opened, passes, open ids of the latest
tally. The arguments are:

- `cfg` — the validated config.
- `io` — where the lines go.

Returns 0.
"""
function list(cfg::AbstractDict; io::IO = stdout)
    rs = RoundFiles.rounds(cfg)
    isempty(rs) && (println(io, "no rounds under .gbg/rounds/"); return 0)
    for r in rs
        if r.round === nothing
            println(io, "  ", rpad(String(r.state), 10), r.name); continue
        end
        openids = ""
        k = r.round["passes"]
        tj = joinpath(r.dir, "verdicts", "pass-$k", "tally.json")
        isfile(tj) && (t = JSON3.read(read(tj, String), Dict{String,Any}); openids = "  open ids: $(length(t["open_ids"]))")
        println(io, "  ", rpad(String(r.state), 10), rpad(r.name, 40), rpad(r.round["instrument"], 18), "opened ", r.round["opened"], "  passes ", k, openids)
    end
    return 0
end

"""
    render(cfg, round; io = stdout) -> Int

`gbg round render <round>`: regenerates `findings.md` and `SUMMARY.md` from the frozen files.
The arguments are:

- `cfg` — the validated config.
- `round` — the round id.
- `io` — where the outcome is printed.

Returns 0, or 2 for a round not banked.
"""
function render(cfg::AbstractDict, round::AbstractString; io::IO = stdout)
    dir, rec = load(cfg, round)
    fj = joinpath(dir, "findings.json")
    isfile(fj) || (println(io, "render: $round is not banked"); return 2)
    findings = JSON3.read(read(fj, String), Dict{String,Any})["findings"]
    statuses = Dict{String,Symbol}()
    bj = joinpath(dir, "bank.json"); isfile(bj) && (statuses = Dict(k => Symbol(v) for (k, v) in JSON3.read(read(bj, String), Dict{String,Any})["statuses"]))
    render_findings_md(dir, round, findings); render_summary_md(dir, round, findings, rec, statuses)
    println(io, "render: findings.md and SUMMARY.md regenerated"); return 0
end

"""
    abandon(cfg, round, reason; io = stdout) -> Int

`gbg round abandon <round> --reason "…"`: the only wholesale exit. The arguments are:

- `cfg` — the validated config.
- `round` — the round id.
- `reason` — at least 12 characters (a plateau is the usual one).
- `io` — where the outcome is printed.

It writes `abandoned = {reason, open_ids}` with every id still open (all banked ids when no pass was
graded). Returns 0.
"""
function abandon(cfg::AbstractDict, round::AbstractString, reason::AbstractString; io::IO = stdout)
    length(strip(reason)) >= 12 || (println(io, "abandon: --reason needs at least 12 characters; a plateau is the usual reason"); return 2)
    dir, rec = guard(cfg, round; io, allow_config_change = true)
    open_ids = String[]
    k = rec["passes"]; tj = joinpath(dir, "verdicts", "pass-$k", "tally.json")
    if isfile(tj)
        open_ids = String.(JSON3.read(read(tj, String), Dict{String,Any})["open_ids"])
    elseif isfile(joinpath(dir, "findings.json"))
        open_ids = [f["id"] for f in JSON3.read(read(joinpath(dir, "findings.json"), String), Dict{String,Any})["findings"] if !get(f, "seeded", false)]
    end
    rec["abandoned"] = Dict("reason" => reason, "open_ids" => open_ids)
    save(dir, rec)
    println(io, "abandon: $round abandoned with $(length(open_ids)) open id(s) — the decision shows in the diff; commit the round")
    return 0
end

# ---- CLI ---------------------------------------------------------------------------------------------------

function cmd_round(args)
    o = parse_options(args; valued = ["lanes", "reason"])
    isempty(o.positional) && (println(stderr, "usage: gbg round prepare|build|test|bank|rerun|grade|close|abandon|list|render <round> | gbg round pass open <round> [--regrade] [--sweep-ok]"); return 2)
    verb = o.positional[1]
    cfg = Config.read()
    try
        verb == "list" && return list(cfg)
        if verb == "pass"
            (length(o.positional) >= 3 && o.positional[2] == "open") || (println(stderr, "usage: gbg round pass open <round> [--regrade] [--sweep-ok]"); return 2)
            return GBGCodingTools.Passes.pass_open(cfg, o.positional[3]; regrade = "regrade" in o.flags, sweep_ok = "sweep-ok" in o.flags)
        end
        length(o.positional) >= 2 || (println(stderr, "round $verb needs <round>"); return 2)
        round = o.positional[2]
        verb == "import" && "empty" in o.flags && (round = o.positional[2])
        verb == "prepare" && return prepare(cfg, round)
        verb == "build" && return build(cfg, round)
        verb == "test" && return test(cfg, round)
        verb == "bank" && return bank(cfg, round)
        verb == "rerun" && return rerun(cfg, round, String.(split(get(o.values, "lanes", ""), ','; keepempty = false)))
        verb == "render" && return render(cfg, round)
        verb == "abandon" && return abandon(cfg, round, get(o.values, "reason", ""))
        verb == "grade" && return GBGCodingTools.Passes.grade(cfg, round)
        verb == "close" && return GBGCodingTools.Passes.close(cfg, round)
        if verb == "import"
            "empty" in o.flags && return import_empty(cfg, round, get(o.values, "reason", ""))
            println(stderr, "round import <pile>: the legacy pile readers are Phase 2's scratch tools (IMPLEMENTATION Phase 2 step 1); only `--empty` exists yet"); return 2
        end
        verb == "compare" && (println(stderr, "round compare --recorded: written with Phase 2's scratch imports"); return 2)
        println(stderr, "round: unknown verb $verb"); return 2
    catch err
        err isa RoundError || rethrow()
        println(stderr, sprint(showerror, err)); return 2
    end
end
VERBS["round"] = cmd_round

end # module Rounds
