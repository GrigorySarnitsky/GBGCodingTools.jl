# Audit.jl — `gbg audit-changes bank <round>`: the audit's bank RUNS the executable claims itself under
# GBG_ROUND (ARCHITECTURE §6.8) and records their exit codes in audit.json before the generic bank.

"""
    audit_bank(cfg, round; io = stdout) -> Int

Runs `package.julia_test` (the gate claim) and every file named under `executable_claims` with
`GBG_ROUND` exported, records `{command, file, exit, log}` in `audit.json` together with `base`,
`head`, `kind` and the covered paths, then runs the generic bank; afterwards prints the severity
re-check Workflow call (an anchor, before "serious" is counted at grade). Returns the bank's code.
"""
function audit_bank(cfg::AbstractDict, round::AbstractString; io::IO = stdout)
    dir, rec = Rounds.guard(cfg, round; io)
    rec["instrument"] == "audit-changes" || (println(io, "audit-changes bank: $round is a $(rec["instrument"]) round"); return 2)
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
    if !isempty(findings)
        payload = joinpath(Preflight.payload_dir(cfg, round), "severity"); mkpath(payload)
        ip = joinpath(payload, "items.md")
        open(ip, "w") do f
            for x in findings
                println(f, "--- ", x["id"], " ---"); println(f, "title: ", x["title"])
                for l in x["locations"]; println(f, "location: ", l); end
                for k in ("before", "after", "why_it_matters", "evidence", "description"); haskey(x, k) && println(f, k, ": ", x[k]); end
                println(f)
            end
        end
        a = Dict{String,Any}("schema_version" => 1, "round" => round, "out" => joinpath(dir, "severity.json"), "subject" => "the change set $(first(rec["base"], 8))..$(first(rec["head"], 8)) of $(cfg["package"]["name"])",
                             "items" => [Dict("id" => x["id"]) for x in findings], "items_path" => ip, "models" => Dict("economy" => Preflight.economy_model()))
        Preflight.save_args(cfg, round, "severity", a)
        println(io, "\nNEXT (an anchor, before \"serious\" is counted): launch the severity re-check exactly as printed, then gbg round grade $round:\n")
        println(io, Preflight.workflow_call(joinpath(Preflight.workflow_dir(cfg, round), "severity-recheck.js"), a))
    else
        println(io, "audit-changes bank: no concern banked; verdict_all_clean = $(audit["verdict_all_clean"]) (checked[] on every lane and every claim exit 0)")
    end
    return 0
end
VERBS["audit-changes bank"] = args -> (isempty(args) ? (println(stderr, "usage: gbg audit-changes bank <round>"); 2) : (try audit_bank(Config.read(), args[1]) catch err; err isa Rounds.RoundError || rethrow(); println(stderr, sprint(showerror, err)); 2 end))
