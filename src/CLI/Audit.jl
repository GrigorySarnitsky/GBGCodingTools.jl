# Audit.jl — `gbg audit-changes bank <round>`: the audit's bank RUNS the executable claims itself under
# GBG_ROUND (ARCHITECTURE §6.8) and records their exit codes in audit.json before the generic bank.

# The lane files under `fdir` whose own `verdict` contradicts their `findings`: `CLEAN` with one or more,
# `CONCERNS` with none. Returns `(file, verdict, count)` per contradiction; a file that does not parse, or
# carries no verdict, is the generic bank's to judge.
function lane_verdict_contradictions(fdir::AbstractString)
    bad = Tuple{String,String,Int}[]
    isdir(fdir) || return bad
    for f in sort!(filter(endswith(".json"), readdir(fdir)))
        d = try JSON3.read(read(joinpath(fdir, f), String), Dict{String,Any}) catch; continue end
        v = get(d, "verdict", nothing); v isa AbstractString || continue
        n = length(get(d, "findings", Any[]))
        (v == "CLEAN") == (n == 0) || push!(bad, (f, String(v), n))
    end
    return bad
end

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
`head`, `kind` and the covered paths, then runs [`Rounds.bank`](@ref); afterwards it prints the
severity re-check Workflow call (an anchor, before "serious" is counted at grade). Returns the bank's
exit code.
"""
function audit_bank(cfg::AbstractDict, round::AbstractString; io::IO = stdout)
    dir, rec = Rounds.guard(cfg, round; io)
    rec["instrument"] == "audit-changes" || (println(io, "audit-changes bank: $round is a $(rec["instrument"]) round"); return 2)
    # a lane's `verdict` is its own report, kept only where its findings bear it out: CLEAN with a
    # concern, or CONCERNS with none, is refused before the claims run (RULE.TEST.BOTH_DIRECTIONS)
    bad = lane_verdict_contradictions(joinpath(dir, "findings"))
    if !isempty(bad)
        for (f, v, n) in bad
            println(io, "audit-changes bank: $f reports $v with $n finding(s) — its verdict contradicts its own findings")
        end
        println(io, "  re-run it: gbg round rerun $round --lanes ", join([replace(f, r"^\d+-" => "", r"\.json$" => "") for (f, _, _) in bad], ","))
        return 2
    end
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
