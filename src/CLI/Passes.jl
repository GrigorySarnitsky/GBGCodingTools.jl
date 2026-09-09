# Passes.jl — the verification half of a round: `gbg round pass open`, `grade`, `close` (ARCHITECTURE
# §6.2 steps 7–9, §6.5, §6.7, §6.8). The demotion is Demote.jl; the args renderer is Preflight's.

"""
    Passes

[`Passes.pass_open`](@ref) opens a verification pass (nonce, range, expected counts, the regenerated
manuscripts, the verifiers' Workflow calls); [`Passes.grade`](@ref) validates the verdict files, applies
the demotion and the four closure channels and writes the tally; [`Passes.close`](@ref) checks every
closing condition of the instrument in order and stamps the round closed.
"""
module Passes

using TOML, JSON3, Dates, SHA, Random
using ..GBGCodingTools: GBGCodingTools, Config, Ledger, Sync, RoundFiles, Git, Preflight, Rounds, Witnesses, demote,
      load_schema, instrument_schema, validate, consolidate, scan_catalog, run_scan, self_verify

const RoundError = Rounds.RoundError
const FAVOURABLE = ("ABSENT", "NOT-A-DEFECT")

read_json(p) = JSON3.read(read(p, String), Dict{String,Any})
write_json(p, d) = (mkpath(dirname(p)); open(p, "w") do f; JSON3.pretty(f, JSON3.write(d)); println(f); end)
findings_of(dir) = read_json(joinpath(dir, "findings.json"))["findings"]
pass_dir(dir, k) = joinpath(dir, "verdicts", "pass-$k")

# ---- pass open ---------------------------------------------------------------------------------------------

function findings_text_file(path, findings)
    io = IOBuffer()
    for f in findings
        println(io, "--- ", f["id"], " ---")
        println(io, "title: ", f["title"]); println(io, "lane: ", f["lane"], "   type: ", get(f, "type", ""), "   severity: ", f["severity"], "   confidence: ", f["confidence"])
        for l in f["locations"]; println(io, "location: ", l); end
        haskey(f, "contradicts") && !isempty(f["contradicts"]) && println(io, "contradicts: ", f["contradicts"])
        for k in ("file", "second_location", "mechanism", "witness_plan", "observed", "before", "after", "why_it_matters", "justified", "previously_worked", "evidence")
            haskey(f, k) && !isempty(string(f[k])) && println(io, k, ": ", f[k])
        end
        println(io, "description: ", f["description"])
        haskey(f, "resolution_hint") && !isempty(f["resolution_hint"]) && println(io, "hint: ", f["resolution_hint"])
        haskey(f, "claimed_fix") && println(io, "claimed fix: ", f["claimed_fix"])
        println(io)
    end
    mkpath(dirname(path)); write(path, String(take!(io)))
    return path
end

"""
    pass_open(cfg, round; regrade = false, io = stdout) -> Int

`gbg round pass open <round> [--regrade]`: opens a verification pass. The arguments are:

- `cfg` — the validated config.
- `round` — the round id.
- `regrade` — accept a changed stamp (`config_sha`, or the tool stamps) and re-stamp it; the round is
  re-graded from here, and the pass records `regrade = true`.
- `io` — where the calls and messages are printed.

It refuses a changed `config_sha` unless `regrade`; creates `verdicts/pass-<k>/pass.toml` with the
nonce, `head`, `range = <opening head>..HEAD`, the expected verdict count per lane and the stamps; for
the doc instruments rebuilds under `GBG_ROUND` and regenerates the manuscripts; writes the findings'
unabridged text as a payload file; prints the verifiers' Workflow calls rendered by Preflight's
renderer. Returns the exit code.
"""
function pass_open(cfg::AbstractDict, round::AbstractString; regrade::Bool = false, io::IO = stdout)
    dir, rec = Rounds.guard(cfg, round; io, allow_config_change = regrade)
    haskey(rec, "banked") || (println(io, "pass open: $round is not banked yet"); return 2)
    root = cfg["root"]; inst = rec["instrument"]
    k = rec["passes"] + 1; pd = pass_dir(dir, k); mkpath(joinpath(pd, "act")); mkpath(joinpath(pd, "state"))
    st = Preflight.stamps(cfg; record = rec)
    if regrade
        moved = [x for x in ("config_sha", "tool_version", "tool_rev", "tool_tree_sha") if st[x] != get(rec, x, nothing)]
        for x in moved; rec[x] = st[x]; end
        println(io, "pass open --regrade: re-stamped ", isempty(moved) ? "nothing (the stamps had not moved)" : join(moved, ", "))
    end
    head = something(Git.head(root), "0"^40)
    findings = findings_of(dir)
    expected_act = Dict{String,Int}(); expected_state = Dict{String,Int}()
    for f in findings
        expected_state[f["lane"]] = get(expected_state, f["lane"], 0) + 1
        get(f, "seeded", false) || (expected_act[f["lane"]] = get(expected_act, f["lane"], 0) + 1)
    end
    nonce = bytes2hex(rand(RandomDevice(), UInt8, 16))
    pass = merge(Dict{String,Any}("pass" => k, "nonce" => nonce, "opened" => Rounds.timestamp(), "head" => head, "range" => "$(rec["head"])..$head",
                                  "expected" => expected_state, "regrade" => regrade),
                 Dict(x => st[x] for x in ("tool_version", "tool_rev", "tool_tree_sha", "config_sha")))
    errs = validate(load_schema("pass"), pass); isempty(errs) || throw(RoundError("pass.toml would not validate: " * join(errs, "; ")))
    open(joinpath(pd, "pass.toml"), "w") do f; TOML.print(f, pass); end
    k > 1 && begin
        prev = joinpath(pass_dir(dir, k - 1), "pass.toml")
        if isfile(prev); p = TOML.parsefile(prev); p["superseded_by"] = k; open(prev, "w") do f; TOML.print(f, p); end; end
    end
    rec["passes"] = k; Rounds.save(dir, rec)
    graded_sha = rec["findings_sha"]
    payload = joinpath(Preflight.payload_dir(cfg, round), "pass-$k"); mkpath(payload)
    fpath = findings_text_file(joinpath(payload, "findings.md"), findings)
    ledger = Ledger.read(cfg)
    base = Dict{String,Any}("schema_version" => 1, "round" => round, "round_dir" => dir, "pass_dir" => pd, "repo" => root, "nonce" => nonce,
                            "graded_sha256" => graded_sha, "package" => Preflight.package_block(cfg), "models" => Dict("economy" => Preflight.economy_model()),
                            "strength" => rec["strength"], "adjudicated_titles" => Preflight.adjudicated_titles(cfg, ledger), "findings_path" => fpath)
    wdir = Preflight.workflow_dir(cfg, round)
    println(io, "pass $k opened for $round — nonce $nonce, range $(pass["range"])")
    if inst in ("check-consistency", "check-docs")
        manuscripts = nothing
        if inst == "check-consistency"
            log = joinpath(Preflight.scratch_dir(cfg, round), "pass-$k-build.log")
            code = Rounds.run_under_round(cfg, round, cfg["package"]["docs_build"]; log)
            code == 0 || (println(io, "pass open: the docs build failed (exit $code) — see $log; the pass stays open, fix and re-run pass open"); return 2)
            build = joinpath(root, cfg["surfaces"]["built_html"])
            full = joinpath(payload, "manuscript-full.md"); site = joinpath(payload, "manuscript-siteonly.md")
            consolidate(build, String.(cfg["instruments"]["check-consistency"]["design_docs_withheld"]); out_full = full, out_siteonly = site)
            manuscripts = Dict("full" => full, "siteonly" => site)
        end
        lanes = [Dict("nn" => lpad(i, 2, '0'), "key" => r["key"], "substrate" => get(r, "substrate", "")) for (i, r) in enumerate(rec["roster"]) if !get(r, "not_applicable", false)]
        inst == "check-docs" && pushfirst!(lanes, Dict("nn" => "00", "key" => "scans", "substrate" => "scans"))
        act = merge(base, Dict("range" => pass["range"], "mode" => "lanes",
                    "lanes" => [Dict("nn" => l["nn"], "key" => l["key"], "expected" => get(expected_act, l["key"], 0)) for l in lanes if l["key"] != "scans"],
                    "findings" => [Dict("id" => f["id"], "lane" => f["lane"], "n" => f["n"], "title" => f["title"]) for f in findings if !get(f, "seeded", false) && f["lane"] != "scans"]))
        state = merge(base, Dict("lanes" => [Dict("nn" => l["nn"], "key" => l["key"], "substrate" => l["substrate"], "expected" => get(expected_state, l["key"], 0)) for l in lanes if l["key"] != "scans"],
                      "findings" => [Dict("id" => f["id"], "lane" => f["lane"], "n" => f["n"], "title" => f["title"], "seeded" => get(f, "seeded", false)) for f in findings if f["lane"] != "scans"],
                      "source_scope" => ["src", "ext", "docs/src", "docs"]))
        manuscripts === nothing || (state["manuscripts"] = manuscripts)
        Preflight.save_args(cfg, round, "pass-$k-act", act); Preflight.save_args(cfg, round, "pass-$k-state", state)
        println(io, "\nLaunch BOTH verifiers exactly as printed (the act verifier sees the diff; the state verifier is blind), then gbg round grade $round:\n")
        println(io, Preflight.workflow_call(joinpath(wdir, "verify-act.js"), act), "\n")
        println(io, Preflight.workflow_call(joinpath(wdir, "verify-state.js"), state))
        println(io, "\n(lane 00-scans is closed by rescan at grade, never by a verdict)")
    elseif inst == "bug-hunt"
        arch = [f for f in findings if get(f, "kind", "") == "architecture"]
        for f in arch
            rp = joinpath(dir, "reproductions", replace(f["id"], "/" => "__", "#" => "_") * ".json")
            isfile(rp) && (f["claimed_fix"] = get(get(read_json(rp), "disposition", Dict()), "reason", ""))
        end
        findings_text_file(joinpath(payload, "findings.md"), findings)
        if isempty(arch)
            println(io, "no architecture-class finding: the runtime and api-semantics classes re-run mechanically at grade; run gbg round grade $round")
        else
            a = merge(base, Dict("range" => pass["range"], "findings" => [Dict("id" => f["id"], "title" => f["title"]) for f in arch]))
            delete!(a, "adjudicated_titles"); delete!(a, "strength"); delete!(a, "round_dir")
            Preflight.save_args(cfg, round, "pass-$k-architecture", a)
            println(io, "\nLaunch the architecture verifier exactly as printed, then gbg round grade $round:\n")
            println(io, Preflight.workflow_call(joinpath(wdir, "verify-architecture.js"), a))
        end
    else
        println(io, "an audit round has no adversarial verifier (§6.8): the disposition gate is the closure — record dispositions in audit.json, then gbg round grade $round")
    end
    return 0
end

# ---- grade -------------------------------------------------------------------------------------------------

function read_verdicts(pd, kind, lane, nonce, sha, schema_name)
    p = joinpath(pd, kind, lane * ".json")
    isfile(p) || return (:dead, nothing, "absent")
    d = try read_json(p) catch; return (:dead, nothing, "unparsable") end
    errs = validate(load_schema(schema_name), d)
    isempty(errs) || return (:dead, nothing, "invalid: " * first(errs))
    d["pass_nonce"] == nonce || return (:rejected, nothing, "pass_nonce mismatch (a copy-forward verdict)")
    d["graded_sha256"] == sha || return (:rejected, nothing, "graded_sha256 mismatch (graded against another finding set)")
    return (:ok, d, "")
end

# the first 40 characters (never bytes: a hit's text carries Greek and math glyphs) of a hit's quoted line
hit_needle(text::AbstractString) = first(strip(last(split(text, ": "))), 40)

function rescan_alive(cfg, f)
    m = match(r"^(SCAN\.[A-Z0-9_.]+) — ", f["title"]); m === nothing && return true
    id = m.captures[1]
    row = findfirst(r -> r["id"] == id, scan_catalog())
    row === nothing && return true
    r = run_scan(cfg, scan_catalog()[row])
    loc = first(f["locations"]); file = first(split(loc, ':'))
    return any(h -> h.file == file && occursin(hit_needle(h.text), loc), r.hits) || any(h -> h.file == file, r.hits) && length(r.hits) > 0
end

function ledger_adjudication(ledger, id, opened::AbstractString)
    od = Date(first(opened, 10))
    for e in ledger
        e["scope"] == "finding" && e["target"] == id && e["recorded"] >= od && length(e["reason"]) >= 40 && haskey(e, "overturn_when") && return e
    end
    return nothing
end

"""
    grade(cfg, round; io = stdout) -> Int

`gbg round grade <round>`: grades the latest pass. The arguments are `cfg`, the validated config;
`round`, the round id; and `io`, where the tally lines are printed.

It validates the pass's verdict files (a wrong nonce or sha is REJECTED, an absent file with a
non-zero expectation is DEAD ⇒ exit 2), applies the demotion, then the closure channels per id —
`honored`, `adjudicated`, `seeded`, `rescan`; for a hunt the disposition records and the witness
re-run; for an audit the disposition gate after the severity re-check — and writes `tally.json` and
`tally.md` with the pass series and the plateau signal. Exit 1 while `open_ids` is non-empty, 0 when
every id is closed.
"""
function grade(cfg::AbstractDict, round::AbstractString; io::IO = stdout)
    dir, rec = Rounds.guard(cfg, round; io, allow_config_change = true)
    k = rec["passes"]; k >= 1 || (println(io, "grade: no pass opened yet — gbg round pass open $round"); return 2)
    pd = pass_dir(dir, k); pass = TOML.parsefile(joinpath(pd, "pass.toml"))
    if !get(pass, "regrade", false) && Preflight.config_sha(cfg) != rec["config_sha"]
        println(io, "grade: the config changed since the round opened — gbg round pass open $round --regrade"); return 2
    end
    inst = rec["instrument"]; findings = findings_of(dir); ledger = Ledger.read(cfg)
    per_id = Dict{String,Any}(); dead = String[]; rejected = String[]; demoted = 0; adjudicated = 0
    opened = rec["opened"]
    if inst in ("check-consistency", "check-docs")
        lanes = unique(f["lane"] for f in findings if f["lane"] != "scans")
        acts = Dict{String,Any}(); states = Dict{String,Any}()
        for lane in lanes
            nn = something(findfirst(r -> r["key"] == lane, rec["roster"]), 0); nnlabel = lpad(nn, 2, '0')
            exp_act = count(f -> f["lane"] == lane && !get(f, "seeded", false), findings); exp_state = count(f -> f["lane"] == lane, findings)
            if exp_act > 0
                st, d, note = read_verdicts(pd, "act", "$nnlabel-$lane", pass["nonce"], rec["findings_sha"], "verdict-act")
                st == :ok ? (for v in d["verdicts"]; acts[v["id"]] = v; end) : st == :rejected ? push!(rejected, "act/$nnlabel-$lane: $note") : push!(dead, "act/$nnlabel-$lane: $note")
            end
            if exp_state > 0
                st, d, note = read_verdicts(pd, "state", "$nnlabel-$lane", pass["nonce"], rec["findings_sha"], "verdict-state")
                st == :ok ? (for v in d["verdicts"]; states[v["id"]] = v; end) : st == :rejected ? push!(rejected, "state/$nnlabel-$lane: $note") : push!(dead, "state/$nnlabel-$lane: $note")
            end
        end
        for f in findings
            id = f["id"]; entry = Dict{String,Any}("act" => nothing, "act_demoted" => false, "state" => nothing, "closed_by" => nothing)
            if f["lane"] == "scans"
                alive = rescan_alive(cfg, f)
                if !alive
                    m = match(r"^(SCAN\.[A-Z0-9_.]+) — ", f["title"]); sid = m === nothing ? "" : m.captures[1]
                    e = findfirst(x -> x["id"] == sid && x["scope"] == "scan" && x["recorded"] >= Date(first(opened, 10)), ledger)
                    if e === nothing; entry["closed_by"] = "rescan" else entry["closed_by"] = "adjudicated"; entry["adjudicated_entry"] = "$(ledger[e]["id"])@$(ledger[e]["target"])"; adjudicated += 1; end
                end
                per_id[id] = entry; continue
            end
            a = get(acts, id, nothing); s = get(states, id, nothing)
            if a !== nothing
                a2, dm = demote(a); entry["act"] = a2["verdict"]; entry["act_demoted"] = dm; dm && (demoted += 1)
            end
            s === nothing || (entry["state"] = s["verdict"])
            fav = s !== nothing && s["verdict"] in FAVOURABLE
            if get(f, "seeded", false)
                fav && (entry["closed_by"] = "seeded")
            elseif entry["act"] == "HONORED" && fav
                entry["closed_by"] = "honored"
            else
                e = ledger_adjudication(ledger, id, opened)
                e !== nothing && (entry["closed_by"] = "adjudicated"; entry["adjudicated_entry"] = "$(e["id"])@$(e["target"])"; adjudicated += 1)
            end
            per_id[id] = entry
        end
    elseif inst == "bug-hunt"
        project = Witnesses.witness_project(cfg["root"], cfg["instruments"]["bug-hunt"]["witness_env"], cfg["package"]["name"])
        st, arch, note = (any(f -> get(f, "kind", "") == "architecture", findings) ? read_verdicts(pd, "act", "architecture", pass["nonce"], rec["findings_sha"], "architecture-fix") : (:ok, Dict("verdicts" => []), ""))
        st == :ok || (st == :rejected ? push!(rejected, "act/architecture: $note") : push!(dead, "act/architecture: $note"))
        archv = st == :ok ? Dict(v["id"] => v for v in arch["verdicts"]) : Dict{String,Any}()
        for f in findings
            id = f["id"]; entry = Dict{String,Any}("act" => nothing, "act_demoted" => false, "state" => nothing, "closed_by" => nothing)
            rp = joinpath(dir, "reproductions", replace(id, "/" => "__", "#" => "_") * ".json")
            disp = isfile(rp) ? get(read_json(rp), "disposition", Dict("state" => "open")) : Dict("state" => "open")
            dstate = get(disp, "state", "open")
            if dstate == "refused" && length(get(disp, "reason", "")) >= 24
                entry["closed_by"] = "adjudicated"; entry["adjudicated_entry"] = "reproductions: refused"; adjudicated += 1
            elseif dstate == "escalated" && haskey(disp, "overturn_when")
                entry["closed_by"] = "adjudicated"; entry["adjudicated_entry"] = "reproductions: escalated"; adjudicated += 1
            elseif dstate == "fixed"
                if get(f, "kind", "") == "architecture"
                    v = get(archv, id, nothing); entry["act"] = v === nothing ? nothing : v["verdict"]
                    v !== nothing && v["verdict"] == "FIXED" && (entry["closed_by"] = "honored")
                else
                    wp = joinpath(dir, get(f, "witness_path", ""))
                    if isfile(wp)
                        code, results = Witnesses.run(dirname(wp); expect = :pass, package = cfg["package"]["name"], project, names = [basename(wp)], io = devnull)
                        r = isempty(results) ? nothing : first(results)
                        entry["state"] = r === nothing ? nothing : uppercase(String(r.status))
                        r !== nothing && r.status == :pass && (entry["closed_by"] = "honored")
                    end
                end
            end
            per_id[id] = entry
        end
    else
        audit = isfile(joinpath(dir, "audit.json")) ? read_json(joinpath(dir, "audit.json")) : Dict{String,Any}("dispositions" => Dict())
        sev = isfile(joinpath(dir, "severity.json")) ? Dict(r["id"] => r["severity"] for r in read_json(joinpath(dir, "severity.json"))["ratings"]) : nothing
        sev === nothing && !isempty(findings) && (println(io, "grade: the severity re-check has not run — gbg audit-changes bank $round printed its Workflow call; run it first (\"serious\" is counted after the re-check)"); return 2)
        rank = Dict("blocker" => 4, "major" => 3, "minor" => 2, "nit" => 1)
        for f in findings
            id = f["id"]; entry = Dict{String,Any}("act" => nothing, "act_demoted" => false, "state" => nothing, "closed_by" => nothing)
            s = max(rank[f["severity"]], rank[get(sev, id, f["severity"])])
            gated = s >= 3 || get(f, "previously_worked", "no") in ("yes", "unknown")
            disp = get(audit["dispositions"], id, nothing)
            if !gated
                entry["closed_by"] = "honored"
            elseif disp !== nothing && (disp["state"] == "fixed" || (disp["state"] == "refused" && length(get(disp, "reason", "")) >= 24) || (disp["state"] == "escalated" && haskey(disp, "overturn_when")))
                entry["closed_by"] = disp["state"] == "fixed" ? "honored" : "adjudicated"; disp["state"] != "fixed" && (entry["adjudicated_entry"] = "audit.json: " * disp["state"]; adjudicated += 1)
            end
            per_id[id] = entry
        end
    end
    if !isempty(dead) || !isempty(rejected)
        foreach(d -> println(io, "  DEAD      ", d), dead); foreach(r -> println(io, "  REJECTED  ", r), rejected)
        println(io, "grade: the pass is incomplete — re-launch the verifier(s) named above for this pass (same nonce), then grade again")
        isempty(dead) || return 2
    end
    open_ids = sort!([id for (id, e) in per_id if e["closed_by"] === nothing])
    prev_open = k > 1 && isfile(joinpath(pass_dir(dir, k - 1), "tally.json")) ? length(read_json(joinpath(pass_dir(dir, k - 1), "tally.json"))["open_ids"]) : -1
    flat = 0
    for j in k-1:-1:1
        tj = joinpath(pass_dir(dir, j), "tally.json"); isfile(tj) || break
        length(read_json(tj)["open_ids"]) == length(open_ids) ? (flat += 1) : break
    end
    bank = isfile(joinpath(dir, "bank.json")) ? read_json(joinpath(dir, "bank.json")) : Dict{String,Any}()
    closed = count(e -> e["closed_by"] !== nothing, values(per_id))
    tally = Dict{String,Any}("schema_version" => 1, "round" => round, "pass" => k, "per_id" => per_id,
        "totals" => Dict("findings" => length(findings), "seeded" => count(f -> get(f, "seeded", false), findings), "closed" => closed, "open" => length(open_ids)),
        "demoted_by_rule" => demoted, "adjudicated_share" => isempty(findings) ? 0.0 : adjudicated / length(findings),
        "suspect_hats" => get(bank, "suspect_hats", String[]), "dead_lanes" => dead, "rejected_files" => rejected, "open_ids" => open_ids,
        "plateau" => Dict("passes_flat" => flat), "recall" => get(bank, "recall", Dict()))
    errs = validate(load_schema("tally"), tally); isempty(errs) || throw(RoundError("tally.json would not validate: " * join(errs, "; ")))
    write_json(joinpath(pd, "tally.json"), tally)
    md = IOBuffer()
    println(md, "# Tally — $round pass $k\n\n$(closed)/$(length(findings)) closed, $(length(open_ids)) open; demoted by rule: $demoted; adjudicated share: $(Base.round(tally["adjudicated_share"]; digits = 2)); plateau: $flat pass(es) flat.\n")
    for id in sort!(collect(keys(per_id)))
        e = per_id[id]
        println(md, "- `$id` act=$(something(e["act"], "—"))$(e["act_demoted"] ? " (demoted)" : "") state=$(something(e["state"], "—")) → $(something(e["closed_by"], "OPEN"))", haskey(e, "adjudicated_entry") ? " [$(e["adjudicated_entry"])]" : "")
    end
    write(joinpath(pd, "tally.md"), String(take!(md)))
    series = join(("pass $j: $(length(read_json(joinpath(pass_dir(dir, j), "tally.json"))["open_ids"])) open" for j in 1:k if isfile(joinpath(pass_dir(dir, j), "tally.json"))), " → ")
    println(io, "grade: $series")
    flat >= 2 && println(io, "grade: PLATEAU — the open count has not moved for $flat passes; adjudicate what is not a defect, or gbg round abandon")
    isempty(open_ids) ? (println(io, "grade: every id closed — gbg round close $round"); return 0) : (println(io, "grade: $(length(open_ids)) open id(s): ", join(open_ids, ", ")); return 1)
end

# ---- close -------------------------------------------------------------------------------------------------

"""
    audit_after_code(cfg, rec) -> Vector{String}

`RULE.INST.AUDIT_AFTER_CODE` for a documentation round: the refusals when the fix pass of the round
`rec` changed code and no `/audit-changes` round based at its opening head is closed. The arguments are
`cfg`, the validated config, and `rec`, the round record. A pass that touched only prose is not gated.
Returns the refusals, empty when none applies.
"""
function audit_after_code(cfg::AbstractDict, rec::AbstractDict)
    root = cfg["root"]
    # the leading directory of each `src`/`ext` surface glob (`src/**/*.jl` → `src`), as a git pathspec
    globs = vcat(get(cfg["surfaces"], "src", String[]), get(cfg["surfaces"], "ext", String[]))
    dirs = unique(filter(!isempty, [rstrip(String(first(split(String(g), r"[*?\[]"; limit = 2))), '/') for g in globs]))
    isempty(dirs) && return String[]
    touched = Git.changed_paths(root, "$(rec["head"])..HEAD", dirs)
    isempty(touched) && return String[]
    base = first(rec["head"], 8)
    any(r -> r.state == :closed && r.round["instrument"] == "audit-changes" && get(r.round, "base", "") == rec["head"],
        RoundFiles.rounds(cfg)) && return String[]
    return ["the fix pass changed code (" * join(first(touched, 3), ", ") * (length(touched) > 3 ? ", …" : "") *
            ") and no closed audit-changes round has base = $base — run /audit-changes --base $base and close it"]
end

"""
    carry_deferrals(cfg, dir, round; io = stdout) -> Int

Carries a round's deferrals into the session work queue (`RULE.INST.FROZEN_MIDROUND`). The arguments are
`cfg`, the validated config; `dir`, the round directory; `round`, the round id; and `io`, where the
carried lines are printed.

A fix pass that cannot make a change inside the round — an instrument change, which is its own commit and
release — writes one line per deferral in `<round>/deferred.md`; `#` lines and blank lines are ignored.
Each line becomes an open item of `.claude/WORK_QUEUE.md`, whose Stop hook then refuses to let a session
end while it stands, so a deferral outlives the context that made it. A line already in the queue is not
added twice. Returns the number of items added, zero when the file or the queue is absent.
"""
function carry_deferrals(cfg::AbstractDict, dir::AbstractString, round::AbstractString; io::IO = stdout)
    src = joinpath(dir, "deferred.md")
    queue = joinpath(cfg["root"], ".claude", "WORK_QUEUE.md")
    (isfile(src) && isfile(queue)) || return 0
    lines = [strip(l) for l in readlines(src)]
    items = [l for l in lines if !isempty(l) && !startswith(l, "#")]
    isempty(items) && return 0
    text = read(queue, String); added = 0
    open(queue, "a") do f
        for it in items
            body = "$it (deferred by $round)"
            occursin(body, text) && continue
            println(f, "- [ ] ", body); added += 1
        end
    end
    added > 0 && println(io, "close: carried $added deferral(s) into .claude/WORK_QUEUE.md — the Stop hook now holds the session to them")
    return added
end

function dismissal_items(cfg, dir, rec, findings, ledger)
    items = Dict{String,Any}[]
    od = Date(first(rec["opened"], 10))
    for e in ledger
        e["scope"] == "finding" && e["recorded"] >= od && push!(items, Dict("id" => e["target"], "title" => "ledger adjudication of $(e["target"])", "location" => get(e, "evidence", ""),
                                                                           "claim" => e["reason"], "verdict" => "adjudicated", "reasoning" => get(e, "overturn_when", "")))
    end
    rdir = joinpath(dir, "reproductions")
    if rec["instrument"] == "bug-hunt" && isdir(rdir)
        for f in readdir(rdir)
            r = read_json(joinpath(rdir, f))
            v = r["verdict"]; d = get(r, "disposition", Dict("state" => ""))
            if v in ("NOT-REPRODUCED", "WITNESS-WRONG", "NOT-A-DEFECT", "ALREADY-COVERED") || get(d, "state", "") == "refused"
                push!(items, Dict("id" => r["id"], "title" => r["title"], "location" => get(r, "witness_path", ""), "claim" => r["observed"],
                                  "verdict" => get(d, "state", "") == "refused" ? "refused" : v, "reasoning" => get(d, "state", "") == "refused" ? get(d, "reason", "") : get(r, "evidence", "")))
            end
        end
    end
    if rec["instrument"] == "audit-changes" && isfile(joinpath(dir, "audit.json"))
        for (id, d) in read_json(joinpath(dir, "audit.json"))["dispositions"]
            d["state"] == "refused" && push!(items, Dict("id" => id, "title" => "refused audit concern $id", "location" => "", "claim" => "", "verdict" => "refused", "reasoning" => get(d, "reason", "")))
        end
    end
    return items
end

function items_file(path, items)
    io = IOBuffer()
    for d in items
        println(io, "--- ", d["id"], " ---"); for k in ("title", "location", "claim", "verdict", "reasoning"); println(io, k, ": ", get(d, k, "")); end; println(io)
    end
    mkpath(dirname(path)); write(path, String(take!(io))); return path
end

"""
    close(cfg, round; io = stdout) -> Int

`gbg round close <round>`: checks every closing condition in the instrument's order and stamps the
round closed. The arguments are `cfg`, the validated config; `round`, the round id; and `io`, where
the refusals are listed.

The conditions (§6.2 step 9; §6.7 for the hunt; §6.8 for the audit): the latest pass fully closed, no
dead lane, the round's files committed, the stamps unchanged (tool version and config, else regrade;
tool tree sha, else abandon-only), the opening head an ancestor of HEAD, the dismissal auditor run over
every adjudication and refusal with `reopened == []` (its Workflow call is printed when it has not
run), the hunt's witness, promotion, test and audit conditions, and for a check-docs round whose fix
pass changed code, [`Passes.audit_after_code`](@ref). Then `closed`, `closed_head` and the
tally sha are stamped. Returns 0 when closed, 1 when a condition is unmet, 2 on a stamp mismatch.
"""
function close(cfg::AbstractDict, round::AbstractString; io::IO = stdout)
    dir, rec = Rounds.guard(cfg, round; io, allow_config_change = true)
    root = cfg["root"]; inst = rec["instrument"]; k = rec["passes"]
    fails = String[]
    haskey(rec, "banked") || push!(fails, "not banked")
    tj = joinpath(pass_dir(dir, k), "tally.json")
    if k == 0 || !isfile(tj)
        push!(fails, "no graded pass")
    else
        t = read_json(tj)
        isempty(t["open_ids"]) || push!(fails, "$(length(t["open_ids"])) open id(s) in pass $k")
        isempty(t["dead_lanes"]) || push!(fails, "dead lane(s) in pass $k: " * join(t["dead_lanes"], ", "))
    end
    isempty(rec["dead_lanes"]) || push!(fails, "dead lanes at bank: " * join(rec["dead_lanes"], ", "))
    rel = relpath(dir, root)
    dirty = [p for (_, p) in Git.porcelain(root) if startswith(p, rel * "/") || p == rel]
    isempty(dirty) || push!(fails, "the round's files are not committed: " * join(first(dirty, 5), ", ") * (length(dirty) > 5 ? " …" : ""))
    st = Preflight.stamps(cfg; record = rec)
    latest_regrade = k >= 1 && isfile(joinpath(pass_dir(dir, k), "pass.toml")) && get(TOML.parsefile(joinpath(pass_dir(dir, k), "pass.toml")), "regrade", false)
    (st["config_sha"] == rec["config_sha"] || latest_regrade) || push!(fails, "config changed since open — gbg round pass open $round --regrade")
    (st["tool_version"] == rec["tool_version"] || latest_regrade) || push!(fails, "tool version moved ($(rec["tool_version"]) → $(st["tool_version"])) — regrade")
    if st["tool_tree_sha"] != rec["tool_tree_sha"] && st["tool_version"] == rec["tool_version"] && !startswith(st["tool_version"], "dev")
        println(io, "close: the tool's tree hash changed under the same version — the tag moved; this round is abandon-only"); return 2
    end
    head = something(Git.head(root), "")
    Git.is_ancestor(root, rec["head"], head) || push!(fails, "the opening head $(first(rec["head"], 8)) is not an ancestor of HEAD — gbg round pass open $round --regrade")
    findings = isfile(joinpath(dir, "findings.json")) ? findings_of(dir) : Dict{String,Any}[]
    ledger = Ledger.read(cfg)
    items = dismissal_items(cfg, dir, rec, findings, ledger)
    dj = joinpath(dir, "dismissals.json")
    if !isempty(items)
        want_sha = bytes2hex(sha256(JSON3.write(items)))
        # validated, not just read: the script, this gate and dismissal.schema.json disagreed on the file's
        # shape for as long as no round had an adjudication to close (found 2026-09-09)
        ok = false
        if isfile(dj)
            d = try read_json(dj) catch; nothing end
            errs = d === nothing ? ["unparsable"] : validate(load_schema("dismissal"), d)
            isempty(errs) || push!(fails, "dismissals.json is invalid: " * first(errs))
            ok = d !== nothing && isempty(errs) && get(d, "items_sha", "") == want_sha && d["complete"] && isempty(d["reopened"])
        end
        if !ok
            payload = joinpath(Preflight.payload_dir(cfg, round), "dismissals"); ip = items_file(joinpath(payload, "items.md"), items)
            a = Dict{String,Any}("schema_version" => 1, "round" => round, "repo" => root, "package" => Preflight.package_block(cfg),
                                 "items" => [Dict("id" => d["id"], "title" => d["title"]) for d in items], "items_path" => ip, "out" => dj,
                                 "models" => Dict("economy" => Preflight.economy_model()), "items_sha" => want_sha)
            Preflight.save_args(cfg, round, "dismissals", a)
            push!(fails, "the dismissal audit over $(length(items)) dismissal(s)/adjudication(s) has not run (or does not hold) — launch:\n    " *
                         Preflight.workflow_call(joinpath(Preflight.workflow_dir(cfg, round), "dismissals.js"), a) *
                         "\n  then close again (the script writes $dj; items_sha $want_sha is copied from its args)")
        end
    end
    if inst == "bug-hunt"
        append!(fails, hunt_close_conditions(cfg, dir, rec, findings; io))
    elseif inst == "check-docs"
        append!(fails, audit_after_code(cfg, rec))
    elseif inst == "audit-changes"
        aj = joinpath(dir, "audit.json")
        if isfile(aj)
            a = read_json(aj)
            bad = [c for c in get(a, "executable_claims", Any[]) if c["exit"] != 0]
            isempty(bad) || push!(fails, "executable claim(s) failed at bank: " * join((c["command"] for c in bad), "; "))
            stale = Git.changed_paths(root, "$(a["head"])..HEAD", Preflight.covered_paths(cfg))
            Git.run(root, "cat-file", "-e", a["head"] * "^{commit}") === nothing ? push!(fails, "staleness UNCHECKABLE: the audited head $(first(a["head"], 8)) is unreachable") :
                (isempty(stale) || push!(fails, "stale: covered paths changed since the audited head: " * join(first(stale, 5), ", ")))
        else
            push!(fails, "audit.json absent — gbg audit-changes bank $round")
        end
    end
    if !isempty(fails)
        println(io, "close: refused —"); foreach(f -> println(io, "  - ", f), fails); return 1
    end
    carry_deferrals(cfg, dir, round; io)
    rec["closed"] = Rounds.timestamp(); rec["closed_head"] = head
    used = [e["target"] for e in ledger if e["scope"] == "finding" && startswith(e["target"], round * "/")]
    rec["closed_by"] = Dict{String,Any}("adjudicated" => used, "tally_sha" => RoundFiles.sha256_file(tj))
    Rounds.save(dir, rec)
    println(io, "close: $round CLOSED at $(first(head, 8)) — commit ⇒ push the round (ROUND.toml changed); cite the closure per lane and id in the message")
    return 0
end

strip_provenance(text) = join(Iterators.dropwhile(l -> startswith(strip(l), "#") || isempty(strip(l)), split(text, '\n')), "\n")

function hunt_close_conditions(cfg, dir, rec, findings; io)
    fails = String[]; root = cfg["root"]
    project = Witnesses.witness_project(root, cfg["instruments"]["bug-hunt"]["witness_env"], cfg["package"]["name"])
    rdir = joinpath(dir, "reproductions")
    reps = isdir(rdir) ? [read_json(joinpath(rdir, f)) for f in readdir(rdir)] : Dict{String,Any}[]
    confirmed = [r for r in reps if r["verdict"] in ("REPRODUCED", "EVIDENCED")]
    have_sha = isdir(rdir) ? bytes2hex(sha256(join(sort!([read(joinpath(rdir, f), String) for f in readdir(rdir)]), "\n"))) : ""
    # dispositions may change (they are the record of the fix pass), but verdicts, witness shas and ids may not
    for r in reps
        d = get(r, "disposition", Dict("state" => "open")); s = d["state"]
        r["verdict"] in ("REPRODUCED", "EVIDENCED") || continue
        s in ("fixed", "refused", "escalated") || push!(fails, "$(r["id"]) has no disposition (fixed | refused ≥ 24 chars | escalated with overturn_when) — a dropped finding")
        s == "refused" && length(get(d, "reason", "")) < 24 && push!(fails, "$(r["id"]): refusal reason shorter than 24 characters")
        s == "escalated" && !haskey(d, "overturn_when") && push!(fails, "$(r["id"]): escalated without overturn_when")
        if s == "fixed" && r["kind"] != "architecture"
            wp = joinpath(dir, get(r, "witness_path", "")); name = basename(wp)
            if isfile(wp)
                _, results = Witnesses.run(dirname(wp); expect = :pass, package = cfg["package"]["name"], project, names = [name], io = devnull)
                (isempty(results) || first(results).status != :pass) && push!(fails, "$(r["id"]): its witness $name does not PASS under the runner")
                promoted = joinpath(root, "test", "regressions", name)
                if !isfile(promoted)
                    push!(fails, "$(r["id"]): witness $name not promoted into test/regressions/")
                else
                    bytes2hex(sha256(strip_provenance(read(promoted, String)))) == bytes2hex(sha256(strip_provenance(read(wp, String)))) ||
                        push!(fails, "$(r["id"]): the promoted body of $name differs from the bank-time witness (a witness edited to pass is not evidence)")
                end
            else
                push!(fails, "$(r["id"]): fixed but its witness file is missing")
            end
        end
        if s == "escalated" && r["kind"] != "architecture"
            wp = joinpath(dir, get(r, "witness_path", "")); isfile(wp) && push!(fails, "$(r["id"]): escalated — move its witness to witnesses/escalated/ (never promoted)")
        end
    end
    nf = count(r -> get(get(r, "disposition", Dict()), "state", "") == "fixed", confirmed); nr = count(r -> get(get(r, "disposition", Dict()), "state", "") == "refused", confirmed); ne = count(r -> get(get(r, "disposition", Dict()), "state", "") == "escalated", confirmed)
    nf + nr + ne == length(confirmed) || push!(fails, "disposition arithmetic: fixed $nf + refused $nr + escalated $ne ≠ confirmed $(length(confirmed))")
    log = joinpath(Preflight.scratch_dir(cfg, dir |> basename), "close-test.log")
    code = Rounds.run_under_round(cfg, basename(dir), cfg["package"]["julia_test"]; log)
    code == 0 || push!(fails, "Pkg.test() under GBG_ROUND exit $code — $log")
    audits = [r for r in RoundFiles.rounds(cfg) if r.state == :closed && r.round["instrument"] == "audit-changes" && get(r.round, "base", "") == rec["head"]]
    isempty(audits) && push!(fails, "no closed audit-changes round with base = $(first(rec["head"], 8)) (this hunt's opening head) — run /audit-changes --base $(first(rec["head"], 8)) and close it")
    blocked = joinpath(dir, "witnesses", "blocked")
    isdir(blocked) && !isempty(readdir(blocked)) && println(io, "close: BLOCKED witnesses (re-run by gbg doctor --deep on a host with the device): ", join(readdir(blocked), ", "))
    all_dirty = Git.porcelain(root)
    isempty(all_dirty) || push!(fails, "the tree is not clean ($(length(all_dirty)) path(s))")
    ahead = Git.run(root, "rev-list", "--count", "@{u}..HEAD")
    ahead !== nothing && ahead != "0" && push!(fails, "$ahead commit(s) not pushed")
    return fails
end

end # module Passes
