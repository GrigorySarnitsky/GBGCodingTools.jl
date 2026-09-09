# Fleet.jl — `gbg fleet [--deep] [--diff <consumer>:<round> <consumer>:<round>]`: the scorecard over
# fleet.toml (ARCHITECTURE D4), dev checkout only.

"""
    Fleet

The fleet scorecard: [`Fleet.rows`](@ref) computes one row per consumer of `fleet.toml` — `OK`,
`NOT-INITIALISED`, `BEHIND` or `RED` with a detail — and [`Fleet.diff`](@ref) prints two closed rounds'
tallies side by side. The exit contract is D4's: 0 when every row is `OK`; 1 on `NOT-INITIALISED`,
`RED`, or `BEHIND` outside the 7-day sweep window; 2 when a listed path does not exist.
"""
module Fleet

using TOML, Dates, JSON3
using ..GBGCodingTools: GBGCodingTools, Config, Doctor, Git, RoundFiles, Sync, parse_options, VERBS, running_dev, git_stamp

const WINDOW = Day(7)

fleet_path() = joinpath(pkgdir(GBGCodingTools), "fleet.toml")
read_fleet() = TOML.parsefile(fleet_path())

"""
    latest_tag(root) -> Union{VersionNumber,Nothing}

The newest released `vX.Y.Z` tag of the repository at `root` (prereleases excluded), or `nothing`.
"""
function latest_tag(root)
    out = Git.run(root, "tag", "--list", "v*")
    out === nothing && return nothing
    vs = VersionNumber[]
    for t in split(out, '\n')
        m = match(r"^v(\d+\.\d+\.\d+)$", t); m === nothing || push!(vs, VersionNumber(m.captures[1]))
    end
    return isempty(vs) ? nothing : maximum(vs)
end

"""
    Fleet.rows(; deep = false) -> (rows, code)

One row per `[[consumer]]`: `(name, pin, status, detail)`. A consumer without `.gbg/config.toml` is
`NOT-INITIALISED`; one whose QUICK doctor fails is `RED` with the failing ids; one whose pinned version
is older than the fleet's newest is `BEHIND` with both versions and the window state; else `OK`. The
tool's own row (`path = "."`) shows `dev+<sha>[-dirty]` with `clean at vX.Y.Z` or `off tag`, is
`OK`/`RED` by its own doctor and never `BEHIND`. A missing path is exit 2. The arguments are:

- `deep` — run every check, the `--deep` ones included, as each consumer's doctor pass instead of the
  `QUICK` set.

Returns the rows and the exit code.
"""
function rows(; deep::Bool = false)
    fleet = read_fleet(); base = dirname(fleet_path())
    out = NamedTuple[]; code = 0
    pins = Dict{String,VersionNumber}()
    consumers = get(fleet, "consumer", Any[])
    for c in consumers
        c["path"] == "." && continue
        p = joinpath(base, c["path"]); cfgp = joinpath(p, ".gbg", "config.toml")
        isfile(cfgp) || continue
        v = get(get(TOML.parsefile(cfgp), "tool", Dict()), "version", "")
        occursin(r"^\d+\.\d+\.\d+$", v) && (pins[c["name"]] = VersionNumber(v))
    end
    newest = isempty(pins) ? nothing : maximum(values(pins))
    sweep = get(fleet, "sweep", Dict())
    started = haskey(sweep, "started") ? (sweep["started"] isa Date ? sweep["started"] : Date(string(sweep["started"]))) : nothing
    window = started === nothing ? "no window" : today() - started < WINDOW ? "within window" : "window closed"
    for c in consumers
        p = normpath(joinpath(base, c["path"]))
        if !isdir(p)
            push!(out, (name = c["name"], pin = "—", status = "MISSING", detail = "$(c["path"]) does not exist")); code = 2; continue
        end
        cfgp = joinpath(p, ".gbg", "config.toml")
        if !isfile(cfgp)
            push!(out, (name = c["name"], pin = "—", status = "NOT-INITIALISED", detail = "no .gbg/config.toml (gbg init)")); code = max(code, 1); continue
        end
        cfg, err = try (Config.read(p), "") catch e; (nothing, sprint(showerror, e)) end
        if cfg === nothing
            push!(out, (name = c["name"], pin = "?", status = "RED", detail = "CFG.VALID: " * first(err, 120))); code = max(code, 1); continue
        end
        pin = String(cfg["tool"]["version"])
        checks, dcode = Doctor.run(cfg; only = deep ? nothing : ["QUICK"], deep, io = devnull)
        fails = [ch.id for ch in checks if ch.status == :FAIL]
        if c["path"] == "."
            stamp = git_stamp(p); tag = Git.run(p, "describe", "--exact-match", "--tags", "HEAD")
            detail = (tag !== nothing && !endswith(stamp, "-dirty")) ? "clean at $tag" : "off tag"
            st = isempty(fails) ? "OK" : "RED"
            push!(out, (name = c["name"], pin = stamp, status = st, detail = st == "OK" ? detail : detail * "; " * join(fails, ", ")))
            st == "RED" && (code = max(code, 1)); continue
        end
        if !isempty(fails)
            push!(out, (name = c["name"], pin = pin, status = "RED", detail = join(fails, ", "))); code = max(code, 1)
        elseif newest !== nothing && haskey(pins, c["name"]) && pins[c["name"]] < newest
            push!(out, (name = c["name"], pin = pin, status = "BEHIND", detail = "pinned at $pin, newest $newest — $window"))
            window == "within window" || (code = max(code, 1))
        else
            push!(out, (name = c["name"], pin = pin, status = "OK", detail = "doctor green"))
        end
    end
    return (out, code)
end

"""
    Fleet.diff(a, b; io = stdout) -> Int

`gbg fleet --diff <consumer>:<round> <consumer>:<round>`: two closed rounds' tallies side by side. The
arguments are:

- `a`, `b` — the two rounds, each `<consumer>:<round>` naming a consumer of `fleet.toml` and a closed
  round of it; `a` is the left column.
- `io` — where the table is printed.

The table holds the totals, the closure channels, the demotions, the adjudicated share and the recall.
Rounds whose tool versions differ in `MAJOR.MINOR` are refused (exit 2), since their rates are not
comparable. Returns the exit code.
"""
function diff(a::AbstractString, b::AbstractString; io::IO = stdout)
    fleet = read_fleet(); base = dirname(fleet_path())
    function load(spec)
        name, round = split(spec, ':'; limit = 2)
        c = findfirst(x -> x["name"] == name, fleet["consumer"]); c === nothing && throw(ArgumentError("no consumer $name in fleet.toml"))
        dir = joinpath(base, fleet["consumer"][c]["path"], ".gbg", "rounds", round)
        rec = RoundFiles.read_round(dir); rec === nothing && throw(ArgumentError("no round $round in $name"))
        RoundFiles.state(rec) == :closed || throw(ArgumentError("$spec is not closed"))
        tally = JSON3.read(read(joinpath(dir, "verdicts", "pass-$(rec["passes"])", "tally.json"), String), Dict{String,Any})
        return (spec, rec, tally)
    end
    A, B = load(a), load(b)
    mm(v) = (x = match(r"^v?(\d+)\.(\d+)", String(v)); x === nothing ? "dev" : x.captures[1] * "." * x.captures[2])
    mm(A[2]["tool_version"]) == mm(B[2]["tool_version"]) || (println(io, "fleet --diff: refused — tool versions $(A[2]["tool_version"]) and $(B[2]["tool_version"]) differ in MAJOR.MINOR; the rates are not comparable"); return 2)
    println(io, rpad("", 22), rpad(A[1], 40), B[1])
    for (label, f) in (("instrument", r -> r[2]["instrument"]), ("tool", r -> r[2]["tool_version"]), ("findings", r -> r[3]["totals"]["findings"]),
                       ("closed", r -> r[3]["totals"]["closed"]), ("seeded", r -> get(r[3]["totals"], "seeded", 0)), ("demoted by rule", r -> r[3]["demoted_by_rule"]),
                       ("adjudicated share", r -> round(r[3]["adjudicated_share"]; digits = 2)), ("passes", r -> r[3]["pass"]), ("suspect hats", r -> join(r[3]["suspect_hats"], ",")))
        println(io, rpad(label, 22), rpad(string(f(A)), 40), string(f(B)))
    end
    for ch in ("honored", "adjudicated", "seeded", "rescan")
        n(r) = count(e -> e["closed_by"] == ch, values(r[3]["per_id"]))
        println(io, rpad("closed by " * ch, 22), rpad(string(n(A)), 40), string(n(B)))
    end
    return 0
end

function cmd_fleet(args)
    o = parse_options(args)
    running_dev() || (println(stderr, "fleet: the dev checkout only (gbg --dev fleet)"); return 2)
    if "diff" in o.flags
        length(o.positional) == 2 || (println(stderr, "usage: gbg fleet --diff <consumer>:<round> <consumer>:<round>"); return 2)
        return try diff(o.positional[1], o.positional[2]) catch err; err isa ArgumentError || rethrow(); println(stderr, "fleet --diff: ", err.msg); 2 end
    end
    rs, code = rows(; deep = "deep" in o.flags)
    for r in rs
        println("  ", rpad(r.name, 26), rpad(r.pin, 22), rpad(r.status, 17), r.detail)
    end
    sweep = get(read_fleet(), "sweep", Dict())
    haskey(sweep, "started") && println("  sweep: started $(sweep["started"]), $(get(sweep, "from", "?")) → $(get(sweep, "to", "?")) (7-day window)")
    return code
end
VERBS["fleet"] = cmd_fleet

end # module Fleet
