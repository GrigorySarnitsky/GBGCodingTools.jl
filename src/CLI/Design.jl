# Design.jl — the two checks on the instruments themselves, run outside any round: `gbg attack <instrument>`
# puts four adversaries against an instrument's lens set (`attack-design.js`), and `gbg calibrate` scores
# the check-consistency hats against the defects a human read of the site found (`rubric-audit.js`). Each
# keeps its record under `.gbg/attacks/` or `.gbg/calibrations/` and prints the Workflow call; `read`
# validates what the script wrote.

# The next free id `<date>-<stem>-NN` under `.gbg/<store>/`.
function design_id(cfg::AbstractDict, store::AbstractString, stem::AbstractString)
    d = Dates.format(today(), dateformat"yyyy-mm-dd"); dir = joinpath(cfg["root"], ".gbg", store)
    n = 1
    while isdir(joinpath(dir, "$d-$stem-$(lpad(n, 2, '0'))")); n += 1; end
    return "$d-$stem-$(lpad(n, 2, '0'))"
end

# The lens set as the attacker reads it: every lane or hat of the instrument's current roster for this
# package, with the brief or persona it is handed and, for a docs lane, the files it reads.
function render_design(cfg::AbstractDict, instrument::AbstractString, roster)
    io = IOBuffer()
    println(io, "# The lens set of /$instrument over $(cfg["package"]["name"]) — every lane or hat of its current roster\n")
    for r in roster
        kind = get(r, "kind", get(r, "substrate", ""))
        println(io, "## ", r["key"], isempty(kind) ? "" : " ($kind)", get(r, "anchor", false) ? " — anchor" : "")
        files = get(r, "files", String[]); isempty(files) || println(io, "\nreads: ", join(files, ", "))
        println(io, "\n", strip(get(r, "brief", get(r, "persona", ""))), "\n")
    end
    return String(take!(io))
end

# A design check's result, parsed and validated against `schema`; `(nothing, message)` when it is not there.
function read_design_result(p::AbstractString, schema::AbstractDict)
    isfile(p) || return nothing, "$p absent — launch the Workflow call its verb printed first"
    d = try JSON3.read(read(p, String), Dict{String,Any}) catch; nothing end
    d === nothing && return nothing, "$p does not parse"
    errs = validate(schema, d)
    return isempty(errs) ? (d, "") : (nothing, "$p does not validate: " * join(errs, "; "))
end

"""
    attack(cfg, instrument; subject = nothing, io = stdout) -> Int

`gbg attack <instrument> [--subject <file>]`: puts four adversaries — a logician, a philosopher, a
counterexample hunter and a measurement specialist — against an instrument's lens set and asks what
harmful defect passes every lane: the check a lens list must survive, run outside any round. The
arguments are:

- `cfg` — the validated config.
- `instrument` — the instrument whose lanes (or, for `check-consistency`, hats) are attacked.
- `subject` — a TOML file naming what the instrument examines, what it must catch, from whose
  standpoint and where the real material is (`schema/attack-subject.schema.json`); the tool's own
  `catalog/attack/<instrument>.toml` when `nothing`.
- `io` — where the report and the Workflow call go.

It renders the instrument's current roster for this package — each lane's brief or hat's persona, and
the files a docs lane reads — into `.gbg/attacks/<id>/design.md`, fills the subject's `{package.…}`
placeholders and keeps it beside the design as `subject.toml`, copies `attack-design.js` into the
scratch directory and prints its Workflow call. The script writes `attack.json` into the same record;
[`attack_read`](@ref) reads it. Returns 0, or 2 for an instrument without a subject or a subject that
does not validate.
"""
function attack(cfg::AbstractDict, instrument::AbstractString; subject = nothing, io::IO = stdout)
    catdir = joinpath(pkgdir(GBGCodingTools), "catalog", "attack")
    known = sort!([replace(f, ".toml" => "") for f in readdir(catdir) if endswith(f, ".toml")])
    subject === nothing && !(instrument in known) && (println(io, "attack: no subject for $instrument — one of ", join(known, ", "), ", or --subject <file>"); return 2)
    instrument in ("check-docs", "check-consistency", "bug-hunt", "audit-changes") || (println(io, "attack: $instrument is not an instrument"); return 2)
    sp = subject === nothing ? joinpath(catdir, instrument * ".toml") : abspath(subject)
    isfile(sp) || (println(io, "attack: no subject file $sp"); return 2)
    raw = TOML.parsefile(sp)
    errs = validate(load_schema("attack-subject"), raw)
    isempty(errs) || (println(io, "attack: the subject $sp does not validate: ", join(errs, "; ")); return 2)
    subj = Dict{String,Any}(k => Preflight.substitute(String(v), cfg) for (k, v) in raw)
    roster = Preflight.resolve_roster(cfg, instrument)
    id = design_id(cfg, "attacks", "attack-$instrument")
    rd = joinpath(cfg["root"], ".gbg", "attacks", id); mkpath(rd)
    design = joinpath(rd, "design.md"); write(design, render_design(cfg, instrument, roster))
    open(joinpath(rd, "subject.toml"), "w") do f
        println(f, "# the subject this attack was given, its placeholders filled; from ", sp)
        TOML.print(f, subj; sorted = true)
    end
    wd = Preflight.workflow_dir(cfg, id); mkpath(wd)
    cp(joinpath(Preflight.instrument_dir("audit-changes"), "workflow", "attack-design.js"), joinpath(wd, "attack-design.js"); force = true)
    a = Dict{String,Any}("schema_version" => 1, "round" => id, "repo" => cfg["root"], "design_path" => design, "subject" => subj,
                         "out" => joinpath(rd, "attack.json"), "models" => Dict("economy" => Preflight.economy_model()))
    Preflight.save_args(cfg, id, "attack", a)
    println(io, "attack $id: the $(length(roster)) lens(es) of /$instrument against four attackers; the record is .gbg/attacks/$id/")
    println(io, "\nLaunch exactly this, then gbg attack read $id:\n")
    println(io, Preflight.workflow_call(joinpath(wd, "attack-design.js"), a))
    return 0
end

"""
    attack_read(cfg, id; io = stdout) -> Int

`gbg attack read <id>`: validates an attack's result against `schema/attack.schema.json` and prints
every gap the attackers found, fatal first, each with its evading example and the lens proposed to catch
it. The arguments are:

- `cfg` — the validated config.
- `id` — the attack's id, a directory under `.gbg/attacks/`.
- `io` — where the report goes.

Returns 0 when every attacker ran and none broke the lens set, 1 when a gap was found, and 2 when the
result is absent, invalid or incomplete: an attacker that died leaves its angle untested, never sound.
"""
function attack_read(cfg::AbstractDict, id::AbstractString; io::IO = stdout)
    d, msg = read_design_result(joinpath(cfg["root"], ".gbg", "attacks", id, "attack.json"), load_schema("attack"))
    d === nothing && (println(io, "attack read: ", msg); return 2)
    gaps = d["gaps"]
    println(io, "attack $id: ", isempty(gaps) ? "SOUND — no attacker constructed a defect that passes every lane" :
            "$(length(gaps)) gap(s) — " * join(["$(count(g -> g["severity"] == s, gaps)) $s" for s in ("fatal", "serious", "worth-fixing")], ", "))
    for s in ("fatal", "serious", "worth-fixing"), g in gaps
        g["severity"] == s || continue
        println(io, "  ", uppercase(s), " [", g["role"], "] ", g["gap"])
        println(io, "      evading example: ", g["evading_example"])
        println(io, "      why each lane misses: ", g["why_each_lane_misses"])
        println(io, "      proposed lens: ", g["proposed_lens"])
    end
    isempty(d["dead"]) || (println(io, "attack read: attacker(s) died — ", join(d["dead"], ", "), "; those angles are UNTESTED, not sound: launch the attack again"); return 2)
    return isempty(gaps) ? 0 : 1
end

"""
    calibrate(cfg; io = stdout) -> Int

`gbg calibrate`: scores the `check-consistency` hats against the defects a human read of the rendered
site found — for each defect, which hat's own rubric should have caught it, and whether that hat, run
blind on the passage alone, does. The arguments are:

- `cfg` — the validated config.
- `io` — where the report and the Workflow call go.

The defects are the owner's record `.gbg/human-findings.toml` (`schema/human-findings.schema.json`):
one `[[finding]]` per defect with its `id`, `title`, `page`, the `passage` verbatim, the `defect` and
the date it was `recorded`. Every applicable hat's persona and each finding's passage and defect are
written as separate payload files, so the blind hat is handed the passage and never the defect; the
findings are copied into `.gbg/calibrations/<id>/` with the result the script writes there, and
[`calibrate_read`](@ref) reads it. Returns 0, or 2 when the record is absent, invalid or empty, or
repeats an id.
"""
function calibrate(cfg::AbstractDict; io::IO = stdout)
    hp = joinpath(cfg["root"], ".gbg", "human-findings.toml")
    isfile(hp) || (println(io, "calibrate: no .gbg/human-findings.toml — record there the defects a human read of the site found, one [[finding]] each (id, title, page, passage, defect, recorded; schema/human-findings.schema.json)"); return 2)
    raw = TOML.parsefile(hp)
    errs = validate(load_schema("human-findings"), raw)
    isempty(errs) || (println(io, "calibrate: .gbg/human-findings.toml does not validate: ", join(errs, "; ")); return 2)
    found = get(raw, "finding", Any[])
    isempty(found) && (println(io, "calibrate: .gbg/human-findings.toml records no finding — an empty calibration is not a clean one"); return 2)
    ids = [String(f["id"]) for f in found]
    length(unique(ids)) == length(ids) || (println(io, "calibrate: a finding id repeats in .gbg/human-findings.toml"); return 2)
    hats = [h for h in Preflight.resolve_hats(cfg; profile = "all") if !h["not_applicable"]]
    id = design_id(cfg, "calibrations", "calibration")
    rd = joinpath(cfg["root"], ".gbg", "calibrations", id); mkpath(rd)
    pd = Preflight.payload_dir(cfg, id); mkpath(joinpath(pd, "hats")); mkpath(joinpath(pd, "items"))
    personas = joinpath(pd, "personas.md")
    open(personas, "w") do f
        for h in hats; println(f, "### ", h["key"], "\n\n", h["persona"], "\n"); end
    end
    hatargs = Dict{String,Any}[]
    for h in hats
        p = joinpath(pd, "hats", h["key"] * ".md"); write(p, "### " * h["key"] * "\n\n" * h["persona"] * "\n")
        push!(hatargs, Dict{String,Any}("key" => h["key"], "persona_path" => p))
    end
    items = Dict{String,Any}[]
    for f in found
        # the passage file is all the blind hat reads: it never carries the defect
        dp = joinpath(pd, "items", f["id"] * "-defect.md"); sp = joinpath(pd, "items", f["id"] * "-passage.md")
        write(dp, "$(f["title"])\n\npage: $(f["page"])\n\n$(f["defect"])\n")
        write(sp, "page: $(f["page"])\n\n$(f["passage"])\n")
        push!(items, Dict{String,Any}("id" => f["id"], "title" => f["title"], "defect_path" => dp, "substrate_path" => sp))
    end
    cp(hp, joinpath(rd, "human-findings.toml"); force = true)
    wd = Preflight.workflow_dir(cfg, id)
    cp(joinpath(Preflight.instrument_dir("check-consistency"), "workflow", "rubric-audit.js"), joinpath(wd, "rubric-audit.js"); force = true)
    a = Dict{String,Any}("schema_version" => 1, "round" => id, "subject" => "the rendered documentation of $(cfg["package"]["name"])",
                         "hats" => hatargs, "items" => items, "personas_path" => personas,
                         "models" => Dict("economy" => Preflight.economy_model()), "out" => joinpath(rd, "rubric-audit.json"))
    Preflight.save_args(cfg, id, "calibrate", a)
    println(io, "calibration $id: $(length(items)) human finding(s) against $(length(hats)) hat(s); the record is .gbg/calibrations/$id/")
    println(io, "\nLaunch exactly this, then gbg calibrate read $id:\n")
    println(io, Preflight.workflow_call(joinpath(wd, "rubric-audit.js"), a))
    return 0
end

"""
    calibrate_read(cfg, id; io = stdout) -> Int

`gbg calibrate read <id>`: validates a calibration's result against `schema/rubric-audit.schema.json`
and prints how the hats fared against the human findings — the findings no persona's rubric covers, and
every one a hat missed or only half caught, with the hat's own words. The arguments are:

- `cfg` — the validated config.
- `id` — the calibration's id, a directory under `.gbg/calibrations/`.
- `io` — where the report goes.

Returns 0 when a hat caught every human finding, 1 when one was missed, partly caught or covered by no
rubric, and 2 when the result is absent or invalid.
"""
function calibrate_read(cfg::AbstractDict, id::AbstractString; io::IO = stdout)
    d, msg = read_design_result(joinpath(cfg["root"], ".gbg", "calibrations", id, "rubric-audit.json"), load_schema("rubric-audit"))
    d === nothing && (println(io, "calibrate read: ", msg); return 2)
    t = d["tally"]
    println(io, "calibration $id: CAUGHT $(t["CAUGHT"]), PARTIAL $(t["PARTIAL"]), MISSED $(t["MISSED"]); ",
            "$(length(d["unassigned"])) finding(s) no persona's rubric covers")
    for u in d["unassigned"]; println(io, "  NO RUBRIC ", u["id"], ": ", u["why"]); end
    for g in d["gaps"]; println(io, "  ", rpad(g["verdict"], 9), " ", g["id"], " [", g["hat"], "] ", g["evidence"]); end
    return t["PARTIAL"] + t["MISSED"] == 0 && isempty(d["unassigned"]) ? 0 : 1
end

design_verb(f) = args -> (try f(args) catch err; err isa Config.ConfigError || rethrow(); println(stderr, sprint(showerror, err)); 2 end)
VERBS["attack"] = design_verb(args -> (o = parse_options(args; valued = ["subject"]);
    length(o.pos) == 1 ? attack(Config.read(), o.pos[1]; subject = get(o.vals, "subject", nothing)) :
                         (println(stderr, "usage: gbg attack <instrument> [--subject <file>]"); 2)))
VERBS["attack read"] = design_verb(args -> length(args) == 1 ? attack_read(Config.read(), args[1]) :
                                           (println(stderr, "usage: gbg attack read <id>"); 2))
VERBS["calibrate"] = design_verb(args -> isempty(args) ? calibrate(Config.read()) : (println(stderr, "usage: gbg calibrate"); 2))
VERBS["calibrate read"] = design_verb(args -> length(args) == 1 ? calibrate_read(Config.read(), args[1]) :
                                              (println(stderr, "usage: gbg calibrate read <id>"); 2))
