# Release.jl — `gbg release <ver>` and `gbg release <ver>-rc.<n>`: the tag, from the dev checkout at a
# clean tree, after every precondition of ARCHITECTURE D16 and §8 (IMPLEMENTATION 1.10 item 7).

"""
    cites_round(cfg, tag) -> Bool

Whether the consumer `cfg` holds the review a release at `tag` leans on: a CLOSED `/check-docs` round
stamped with that tag, every id of its last tally closed through `honored`, `adjudicated`, `rescan` or
`seeded` — or carried into the next round, which `ROUND.toml`'s `closed_by.carried` records and which is
a disposal, not an open id. `tag` is the git tag (`vX.Y.Z`, `vX.Y.Z-rc.N`); the round's stamp is written without the `v`
(`Preflight.stamps`), and comparing the two raw made this precondition unsatisfiable — no final release
could pass it, and it would have rejected a correctly stamped round.

This is where "the released version was reviewed" is enforced. `ROUND.DEV` only reports what is already
recorded; the refusal that keeps a round citable is `Preflight.dev_round`, at the door. Returns the answer.
"""
function cites_round(cfg::AbstractDict, tag::AbstractString)
    return any(RoundFiles.rounds(cfg)) do r
        (r.state == :closed && String(r.round["instrument"]) == "check-docs" && "v" * String(r.round["tool_version"]) == tag) || return false
        tj = joinpath(r.dir, "verdicts", "pass-$(r.round["passes"])", "tally.json")
        isfile(tj) || return false
        # a carried id is disposed, not open: re-rated, and re-banked in the next round. Whether the
        # BACKLOG is acceptable — a serious one in it above all — is a release condition, not a round's
        carried = Set(String.(get(get(r.round, "closed_by", Dict{String,Any}()), "carried", String[])))
        all(pairs(JSON3.read(read(tj, String), Dict{String,Any})["per_id"])) do (id, e)
            get(e, "closed_by", nothing) in ("honored", "adjudicated", "rescan", "seeded") || String(id) in carried
        end
    end
end

"""
    carry_release_fails(led) -> Vector{String}

Why the carry ledger `led` (`Passes.carry_ledger`) holds a final release back; empty when it does not.

Three things do. A carried `blocker` or `major`: a round past its pass budget may carry a serious finding
in order to close, but severity decides releasability, so a final release fixes it first. A finding
carried `Passes.CARRY_LIMIT` times, which is no longer a deferral and is the owner's to rule on. And a
backlog that has not fallen since the last release: carrying is free while the pile drains and stops
being free when it does not. Returns the refusals.
"""
function carry_release_fails(led::AbstractDict)
    fails = String[]; out = led["carried"]; hist = led["history"]
    serious = [String(e["id"]) for e in out if String(get(e, "severity", "")) in ("blocker", "major")]
    isempty(serious) || push!(fails, "a serious finding is carried: " * join(serious, ", ") * " — carrying closed its round; a final release fixes it first")
    over = [String(e["id"]) for e in out if Int(e["carries"]) >= Passes.CARRY_LIMIT]
    isempty(over) || push!(fails, "carried $(Passes.CARRY_LIMIT)× and still unfixed: " * join(over, ", ") * " — escalate, do not release over it")
    if !isempty(out) && !isempty(hist)
        was = Int(last(hist)["backlog"])
        length(out) < was || push!(fails, "the carry backlog is $(length(out)) and was $was at $(last(hist)["version"]): a final release needs it falling")
    end
    return fails
end

"""
    release(ver; io = stdout, skip_tests = false) -> Int

Tags and pushes `v<ver>` from the dev checkout. The arguments are:

- `ver` — the version to tag, `X.Y.Z` or `X.Y.Z-rc.N`.
- `io` — where the checks are reported.
- `skip_tests` — skips `Pkg.test()`, the docs build and the deep doctor; for the self-tests of this
  verb only, never set by the CLI.

Refused (exit 2) unless: the tree is clean and on the configured branch; the tag is absent; `CHANGELOG.md`
carries `## <ver> — `; `Project.toml`'s version equals the release version (the base version for a
prerelease); `Pkg.test()` is green; the tool's own docs build exits 0 (`SELF.DOCS`); `gbg doctor --deep`
is green at the root; and, for a final release only, no round is open under `.gbg/rounds/` and the
`/check-docs` round opened at the latest `<ver>-rc.<n>` tag is closed — every id through `honored`,
`adjudicated`, `rescan` or `seeded`, or carried into the next round ([`cites_round`](@ref)) — and
nothing in the carry ledger holds it back (`carry_release_fails`). A tag is never moved or re-issued.
Returns the exit code.
"""
function release(ver::AbstractString; io::IO = stdout, skip_tests::Bool = false)
    m = match(r"^(\d+\.\d+\.\d+)(-rc\.(\d+))?$", ver)
    m === nothing && (println(io, "release: $ver is neither X.Y.Z nor X.Y.Z-rc.N"); return 2)
    base = m.captures[1]; rc = m.captures[2] !== nothing
    root = pkgdir(GBGCodingTools)
    running_dev() || (println(io, "release: the dev checkout only"); return 2)
    cfg = Config.read(root)
    fails = String[]
    isempty(Git.porcelain(root)) || push!(fails, "the tree is not clean")
    branch = Git.run(root, "rev-parse", "--abbrev-ref", "HEAD")
    branch == cfg["git"]["branch"] || push!(fails, "on branch $branch, not $(cfg["git"]["branch"])")
    Git.run(root, "rev-parse", "-q", "--verify", "refs/tags/v$ver") === nothing || push!(fails, "tag v$ver exists — a tag is never re-issued")
    occursin("## $ver — ", read(joinpath(root, "CHANGELOG.md"), String)) || push!(fails, "CHANGELOG.md has no `## $ver — <date>` entry")
    pv = String(TOML.parsefile(joinpath(root, "Project.toml"))["version"])
    pv == base || push!(fails, "Project.toml version is $pv, the release is $base")
    if !rc
        open_ = [r.name for r in RoundFiles.rounds(cfg) if r.state == :open]
        isempty(open_) || push!(fails, "open round(s): " * join(open_, ", "))
        tags = Git.run(root, "tag", "--list", "v$base-rc.*")
        rcs = tags === nothing ? String[] : filter(!isempty, split(tags, '\n'))
        if isempty(rcs)
            push!(fails, "no v$base-rc.N tag: a final release follows a candidate whose /check-docs round is closed")
        else
            latest = last(sort(rcs; by = t -> parse(Int, last(split(t, ".")))))
            cites_round(cfg, latest) || push!(fails, "no closed /check-docs round stamped $latest under .gbg/rounds/")
            # a carried finding is a debt, and a final release is where the debt is called
            append!(fails, carry_release_fails(Passes.carry_ledger(cfg)))
        end
    end
    if !isempty(fails)
        println(io, "release: refused —"); foreach(f -> println(io, "  - ", f), fails); return 2
    end
    if !skip_tests
        for (label, cmd) in (("Pkg.test()", `$(Base.julia_cmd()) --startup-file=no --project=$root -e "using Pkg; Pkg.test()"`),
                             ("docs build (SELF.DOCS)", addenv(`$(Base.julia_cmd()) --startup-file=no --project=$(joinpath(root, "docs")) $(joinpath(root, "docs", "make.jl"))`, "GBG_DOCS_NO_SKIP" => "1")))
            println(io, "release: running $label …"); flush(io)
            ok = success(pipeline(setenv(cmd; dir = root); stdout = devnull, stderr = devnull))
            ok || (println(io, "release: refused — $label failed"); return 2)
        end
        println(io, "release: running gbg doctor --deep …"); flush(io)
        _, dcode = Doctor.run(cfg; deep = true, io = devnull)
        dcode == 0 || (println(io, "release: refused — gbg doctor --deep is not green"); return 2)
    end
    Git.run(root, "tag", "-a", "v$ver", "-m", "GBGCodingTools v$ver") === nothing && (println(io, "release: git tag failed"); return 3)
    Git.run(root, "push", "origin", "v$ver") === nothing && (println(io, "release: tag created but the push failed — push it by hand: git push origin v$ver"); return 3)
    led = Passes.carry_ledger(cfg)
    push!(led["history"], Dict{String,Any}("version" => ver, "date" => string(Dates.today()), "backlog" => length(led["carried"])))
    (isempty(led["carried"]) && length(led["history"]) == 1) || Passes.save_carry(cfg, led)
    println(io, "release: v$ver tagged and pushed", rc ? " (a prerelease: nothing pins it; the /check-docs round opens at it)" : "",
            isempty(led["carried"]) ? "" : " — carry backlog: $(length(led["carried"]))")
    return 0
end

function cmd_release(args)
    o = parse_options(args)
    isempty(o.positional) && (println(stderr, "usage: gbg release <ver> | gbg release <ver>-rc.<n>"); return 2)
    return release(o.positional[1])
end
VERBS["release"] = cmd_release
