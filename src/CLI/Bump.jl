# Bump.jl — `gbg bump <ver> [--abandon-open-rounds "…"]`: moves a consumer's pinned version, syncs, writes the
# bump commit message, records the fleet sweep window (ARCHITECTURE D4, D16).

"""
    bump(cfg, ver; abandon = nothing, io = stdout) -> Int

Moves the pinned version of the consumer at `cfg["root"]` to `ver` (a released `X.Y.Z`), refusing (exit 2) while a
round is open unless `abandon` gives the reason every open round is abandoned with; rewrites the
`[tool] version` line of `.gbg/config.toml`, runs `sync` (which re-renders every managed file and the
sub-environment entries), writes `.gbg/scratch/bump-message.txt` from the template, and records the
`[sweep]` window in the dev checkout's `fleet.toml` when the bump leaves the fleet at two versions.
The arguments are:

- `cfg` — the validated config.
- `ver` — the target version.
- `abandon` — the abandon reason, or `nothing`.
- `io` — where the report goes.

Returns the exit code.
"""
function bump(cfg::AbstractDict, ver::AbstractString; abandon = nothing, io::IO = stdout)
    occursin(r"^\d+\.\d+\.\d+$", ver) || (println(io, "bump: $ver is not a released X.Y.Z (a prerelease is never pinned)"); return 2)
    root = cfg["root"]; from = String(cfg["tool"]["version"])
    open_rounds = [r for r in RoundFiles.rounds(cfg) if r.state == :open]
    if !isempty(open_rounds)
        abandon === nothing && (println(io, "bump: refused — open round(s): " * join((r.name for r in open_rounds), ", ") * "; close them, or --abandon-open-rounds \"<reason>\""); return 2)
        for r in open_rounds
            code = Rounds.abandon(cfg, r.name, abandon; io)
            code == 0 || return code
        end
    end
    p = joinpath(root, ".gbg", "config.toml"); text = read(p, String)
    new = replace(text, r"^(version\s*=\s*)\"[^\"]*\""m => SubstitutionString("\\1\"$ver\""); count = 1)
    new == text && (println(io, "bump: could not find the [tool] version line in .gbg/config.toml"); return 2)
    write(p, new)
    cfg2 = Config.read(root)
    code = Sync.sync(cfg2; io)
    code == 0 || return code
    files = [e.path for e in Sync.status(cfg2) if e.state == :OK]
    abandoned = isempty(open_rounds) ? "" : " Open rounds abandoned for the bump (" * abandon * "): " * join((r.name for r in open_rounds), ", ") * "."
    msg = Sync.render(Sync.template("bump-message.tmpl"), merge(Sync.slots(cfg2), Dict("from" => from, "to" => ver, "files" => join("- " .* files, "\n"), "abandoned" => abandoned)))
    mkpath(joinpath(root, ".gbg", "scratch")); write(joinpath(root, ".gbg", "scratch", "bump-message.txt"), msg)
    # the sweep window: the dev checkout's fleet.toml, when the fleet is now at two versions
    fp = Fleet.fleet_path()
    if isfile(fp)
        fleet = TOML.parsefile(fp); base = dirname(fp)
        pins = Set{String}()
        for c in get(fleet, "consumer", Any[])
            c["path"] == "." && continue
            cp_ = joinpath(base, c["path"], ".gbg", "config.toml"); isfile(cp_) || continue
            v = get(get(TOML.parsefile(cp_), "tool", Dict()), "version", ""); occursin(r"^\d+\.\d+\.\d+$", v) && push!(pins, v)
        end
        ftext = read(fp, String)
        if length(pins) >= 2 && !occursin(r"^started\s*="m, ftext)
            ftext = replace(ftext, r"^\[sweep\][^\n]*\n"m => "[sweep]\nstarted = $(today())\nfrom = \"$from\"\nto = \"$ver\"\n"; count = 1)
            write(fp, ftext); println(io, "bump: fleet at two versions — [sweep] window started today in fleet.toml (7 days)")
        elseif length(pins) <= 1 && occursin(r"^started\s*="m, ftext)
            ftext = replace(ftext, r"^started\s*=[^\n]*\n(from\s*=[^\n]*\n)?(to\s*=[^\n]*\n)?"m => ""); write(fp, ftext)
            println(io, "bump: the fleet converged on $ver — [sweep] window closed")
        end
    end
    println(io, "bump: $(cfg2["package"]["name"]) $from → $ver; commit with `git commit -F .gbg/scratch/bump-message.txt` (stage -u plus the managed files by name), then push")
    return 0
end

function cmd_bump(args)
    o = parse_options(args; valued = ["abandon-open-rounds"])
    isempty(o.positional) && (println(stderr, "usage: gbg bump <ver> [--abandon-open-rounds \"…\"]"); return 2)
    return bump(Config.read(), o.positional[1]; abandon = get(o.values, "abandon-open-rounds", nothing))
end
VERBS["bump"] = cmd_bump
