# Fleet.jl — `gbg fleet [--deep]`: the scorecard over
# `Catalogue.FLEET` (ARCHITECTURE D4), dev checkout only.

"""
    Fleet

The fleet scorecard: [`Fleet.rows`](@ref) computes one row per package of `Catalogue.FLEET` — `OK`,
`NOT-INITIALISED`, `BEHIND` or `RED` with a detail. The exit contract is D4's: 0 when every row is `OK`; 1 on `NOT-INITIALISED`,
`RED`, or `BEHIND` outside the 7-day sweep window; 2 when a listed path does not exist.
"""
module Fleet

using TOML, Dates, JSON3
using ..GBGCodingTools: GBGCodingTools, Config, Git, parse_options, VERBS, running_dev, git_stamp

const WINDOW = Day(7)

fleet_path() = joinpath(pkgdir(GBGCodingTools), "fleet.toml")
# Only the sweep state is read from the file now; the roster is `Catalogue.FLEET`, its one home. The
# file may be absent — a checkout without it still has a fleet.
read_fleet() = isfile(fleet_path()) ? TOML.parsefile(fleet_path()) : Dict{String,Any}()
roster() = GBGCodingTools.Catalogue.FLEET

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

One row per package of `Catalogue.FLEET`: `(name, pin, status, detail)`. A consumer without `.gbg/config.jl` is
`NOT-INITIALISED`; one whose generated files are adrift is `RED`; one whose pinned version
is older than the fleet's newest is `BEHIND` with both versions and the window state; else `OK`. The
tool's own row (`path = "."`) shows `dev+<sha>[-dirty]` with `clean at vX.Y.Z` or `off tag`, is
`OK`/`RED` by its own wiring and never `BEHIND`. A missing path is exit 2. The arguments are:

- `deep` — run every check, the `--deep` ones included, as each consumer's doctor pass instead of the
  `QUICK` set.

Returns the rows and the exit code.
"""
function rows(; deep::Bool = false)
    fleet = read_fleet(); base = dirname(fleet_path())
    out = NamedTuple[]; code = 0
    pins = Dict{String,VersionNumber}()
    consumers = roster()
    for c in consumers
        c.path == "." && continue
        cfg = try GBGCodingTools.ConfigIO.read_config(joinpath(base, c.path)) catch; nothing end
        cfg === nothing && continue
        cfg.tool isa VersionNumber && isempty(cfg.tool.prerelease) && (pins[c.name] = cfg.tool)
    end
    newest = isempty(pins) ? nothing : maximum(values(pins))
    sweep = get(fleet, "sweep", Dict())
    started = haskey(sweep, "started") ? (sweep["started"] isa Date ? sweep["started"] : Date(string(sweep["started"]))) : nothing
    window = started === nothing ? "no window" : today() - started < WINDOW ? "within window" : "window closed"
    for c in consumers
        p = normpath(joinpath(base, c.path))
        if !isdir(p)
            push!(out, (name = c.name, pin = "—", status = "MISSING", detail = "$(c.path) does not exist")); code = 2; continue
        end
        # `.gbg/config.toml`, read here until 2026-09-18, has not existed since Phase 2 replaced it with
        # `config.jl`. The verb therefore looked for a file no package has and called every one of them
        # NOT-INITIALISED — five wrong rows, GBGPeriodicFields wired and reported as unwired.
        if !isfile(joinpath(p, ".gbg", "config.jl"))
            push!(out, (name = c.name, pin = "—", status = "NOT-INITIALISED", detail = "no .gbg/config.jl (gbg init)")); code = max(code, 1); continue
        end
        cfg, err = try (GBGCodingTools.ConfigIO.read_config(p), "") catch e; (nothing, sprint(showerror, e)) end
        if cfg === nothing
            push!(out, (name = c.name, pin = "?", status = "RED", detail = "CFG: " * first(err, 120))); code = max(code, 1); continue
        end
        pin = GBGCodingTools.Render.version_tag(cfg)
        # The doctor's check list was read here until 2026-09-17. A package's wiring is the wiring
        # check's to judge now, and it answers in one word: adrift, or not.
        fails = GBGCodingTools.Wire.sync(p; check = true, io = devnull) == 0 ? String[] : ["WIRING"]
        if c.path == "."
            stamp = git_stamp(p); tag = Git.run(p, "describe", "--exact-match", "--tags", "HEAD")
            detail = (tag !== nothing && !endswith(stamp, "-dirty")) ? "clean at $tag" : "off tag"
            st = isempty(fails) ? "OK" : "RED"
            push!(out, (name = c.name, pin = stamp, status = st, detail = st == "OK" ? detail : detail * "; " * join(fails, ", ")))
            st == "RED" && (code = max(code, 1)); continue
        end
        if !isempty(fails)
            push!(out, (name = c.name, pin = pin, status = "RED", detail = join(fails, ", "))); code = max(code, 1)
        elseif newest !== nothing && haskey(pins, c.name) && pins[c.name] < newest
            push!(out, (name = c.name, pin = pin, status = "BEHIND", detail = "pinned at $pin, newest $newest — $window"))
            window == "within window" || (code = max(code, 1))
        else
            push!(out, (name = c.name, pin = pin, status = "OK", detail = "wired"))
        end
    end
    return (out, code)
end

# `gbg fleet --diff` stood here until 2026-09-17: it put two closed rounds' tallies side by side.
# Rounds no longer exist, and the new design records a run rather than a round
# (docs/ARCHITECTURE.md §5.2, §12), so nothing here reads one.


function cmd_fleet(args)
    o = parse_options(args)
    running_dev() || (println(stderr, "fleet: the dev checkout only (gbg --dev fleet)"); return 2)
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
