# Audit.jl — `gbg audit-changes bank <round>`: the audit's bank RUNS the executable claims itself under
# GBG_ROUND (ARCHITECTURE §6.8) and records their exit codes in audit.json before the generic bank.

# The roster lanes whose lane file's own `verdict` contradicts its `findings` (`Rounds.verdict_contradiction`),
# read without touching anything. Only a roster lane file `NN-<key>.json` is read — a quarantined
# `*.rejected.json` never is — and a file that does not parse, or whose `verdict` or `findings` is not the
# schema's shape, is left to `Rounds.classify_lane`, which refuses it on the schema. Returns the lane keys.
function lane_contradictions(dir::AbstractString, rec::AbstractDict)
    bad = String[]
    for l in Rounds.expected_lanes(rec)
        p = joinpath(dir, "findings", "$(l["nn"])-$(l["key"]).json")
        isfile(p) || continue
        d = try JSON3.read(read(p, String), Dict{String,Any}) catch; continue end
        get(d, "verdict", nothing) in ("CLEAN", "CONCERNS") && get(d, "findings", nothing) isa AbstractVector || continue
        Rounds.verdict_contradiction(d) === nothing || push!(bad, l["key"])
    end
    return bad
end

# The concerns a blind re-rating can move across the disposition gate. `grade` takes the MORE serious of
# the lane's rating and the re-rating, so a concern already `major` or `blocker`, or gated because input
# that worked before now behaves differently (`previously_worked` yes or unknown), is gated whatever the
# re-rating says; re-rating it bought nothing (22 of the 33 concerns of 2026-09-11-audit-changes-01).
recheck_candidates(findings) =
    [x for x in findings if x["severity"] in ("minor", "nit") && !(get(x, "previously_worked", "no") in ("yes", "unknown"))]

"""
    audit_bank(cfg, round; io = stdout) -> Int

`gbg audit-changes bank <round>`: the audit's bank runs the executable claims itself, then the generic
bank. The arguments are:

- `cfg` — the validated config.
- `round` — the round id (`<date>-<instrument>-<NN>`), the instrument being one of the four review
  procedures [`GBGCodingTools`](@ref) binds.
- `io` — where the report goes.

It runs `package.julia_test` (the gate claim) and every file named under `executable_claims` with
`GBG_ROUND` exported, each claim as `julia --project=test <file>` — which is why `test/Project.toml`
names the package itself as a path source, and without that every claim fails to load it and the
audit's account of what runs is built on nothing — records `{command, file, exit, log}` in `audit.json` together with `base`,
`head`, `kind` and the covered paths, then runs [`Rounds.bank`](@ref).

Afterwards it prints the severity re-check Workflow call (an anchor, before "serious" is counted at grade) over the concerns a
re-rating can move across the gate — the `minor` and `nit` ones not already gated by
`previously_worked` — and, when there are none, writes an empty `severity.json` itself. Returns the
bank's exit code.

A lane whose `verdict` contradicts its own findings — `CLEAN` with a concern, `CONCERNS` with none — is
refused before any claim runs: the generic bank is called at once, quarantines that lane as DEAD and
records it, and the `gbg round rerun` it prints re-runs exactly that lane.
"""
function audit_bank(cfg::AbstractDict, round::AbstractString; io::IO = stdout)
    dir, rec = Rounds.guard(cfg, round; io)
    rec["instrument"] == "audit-changes" || (println(io, "audit-changes bank: $round is a $(rec["instrument"]) round"); return 2)
    # a lane whose verdict contradicts its findings fails the bank anyway; the claims are not run for it.
    # The generic bank quarantines the lane as DEAD and records it, so the rerun it prints is accepted
    isempty(lane_contradictions(dir, rec)) || return Rounds.bank(cfg, round; io)
    root = cfg["root"]; scratch = Preflight.scratch_dir(cfg, round)
    claims = Dict{String,Any}[]
    log = joinpath(scratch, "claim-gate.log")
    code = Rounds.run_under_round(cfg, round, cfg["package"]["julia_test"]; log)
    push!(claims, Dict("command" => cfg["package"]["julia_test"], "exit" => code, "log" => log))
    println(io, "  claim gate ($(cfg["package"]["julia_test"])): exit $code")
    for (k, f) in cfg["instruments"]["audit-changes"]["executable_claims"]
        log = joinpath(scratch, "claim-$k.log")
        cmd = "julia --project=test --startup-file=no \"$(joinpath(root, f))\""
        code = Rounds.run_under_round(cfg, round, cmd; log)
        push!(claims, Dict("command" => cmd, "file" => f, "exit" => code, "log" => log))
        println(io, "  claim $k ($f): exit $code")
    end
    audit = Dict{String,Any}("schema_version" => 1, "round" => round, "base" => rec["base"], "head" => rec["head"],
                             "kind" => Preflight.audit_kind(cfg, rec["base"]), "covered" => Preflight.covered_paths(cfg),
                             "diffstat" => Git.diffstat(root, "$(rec["base"])..$(rec["head"])", Preflight.covered_paths(cfg)),
                             "executable_claims" => claims, "dispositions" => Dict{String,Any}(), "verdict_all_clean" => false)
    aj = joinpath(dir, "audit.json")
    if isfile(aj)
        old = JSON3.read(read(aj, String), Dict{String,Any}); audit["dispositions"] = get(old, "dispositions", Dict{String,Any}())
    end
    errs = validate(load_schema("audit"), audit); isempty(errs) || throw(Rounds.RoundError("audit.json would not validate: " * join(errs, "; ")))
    open(aj, "w") do f; JSON3.pretty(f, JSON3.write(audit)); println(f); end
    code = Rounds.bank(cfg, round; io)
    code == 0 || return code
    findings = JSON3.read(read(joinpath(dir, "findings.json"), String), Dict{String,Any})["findings"]
    audit["verdict_all_clean"] = isempty(findings) && all(c -> c["exit"] == 0, claims)
    open(aj, "w") do f; JSON3.pretty(f, JSON3.write(audit)); println(f); end
    rerate = recheck_candidates(findings)
    if !isempty(findings) && isempty(rerate)
        # every concern is gated whatever a re-rating says: nothing to launch, and grade still finds its file
        open(joinpath(dir, "severity.json"), "w") do f
            JSON3.pretty(f, JSON3.write(Dict("schema_version" => 1, "round" => round, "ratings" => Any[]))); println(f)
        end
        println(io, "audit-changes bank: all $(length(findings)) concern(s) are gated whatever a re-rating says — no severity re-check to run; gbg round grade $round")
    elseif !isempty(findings)
        payload = joinpath(Preflight.payload_dir(cfg, round), "severity"); mkpath(payload)
        ip = joinpath(payload, "items.md")
        open(ip, "w") do f
            for x in rerate
                println(f, "--- ", x["id"], " ---"); println(f, "title: ", x["title"])
                for l in x["locations"]; println(f, "location: ", l); end
                for k in ("before", "after", "why_it_matters", "evidence", "description"); haskey(x, k) && println(f, k, ": ", x[k]); end
                println(f)
            end
        end
        a = Dict{String,Any}("schema_version" => 1, "round" => round, "out" => joinpath(dir, "severity.json"), "subject" => "the change set $(first(rec["base"], 8))..$(first(rec["head"], 8)) of $(cfg["package"]["name"])",
                             "items" => [Dict("id" => x["id"]) for x in rerate], "items_path" => ip, "models" => Dict("economy" => Preflight.economy_model()))
        Preflight.save_args(cfg, round, "severity", a)
        println(io, "\nNEXT (an anchor, before \"serious\" is counted): launch the severity re-check exactly as printed — $(length(rerate)) of ",
                "$(length(findings)) concern(s), the rest being gated whatever a re-rating says — then gbg round grade $round:\n")
        println(io, Preflight.workflow_call(joinpath(Preflight.workflow_dir(cfg, round), "severity-recheck.js"), a))
    else
        println(io, "audit-changes bank: no concern banked; verdict_all_clean = $(audit["verdict_all_clean"]) (checked[] on every lane and every claim exit 0)")
    end
    return 0
end
VERBS["audit-changes bank"] = args -> (isempty(args) ? (println(stderr, "usage: gbg audit-changes bank <round>"); 2) : (try audit_bank(Config.read(), args[1]) catch err; err isa Rounds.RoundError || rethrow(); println(stderr, sprint(showerror, err)); 2 end))
