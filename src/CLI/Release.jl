# Release.jl — `gbg release <ver>` and `gbg release <ver>-rc.<n>`: the tag, from the dev checkout at a
# clean tree, after every precondition of ARCHITECTURE D16 and §8 (IMPLEMENTATION 1.10 item 7).

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
`/check-docs` round opened at the latest `<ver>-rc.<n>` tag is closed by honored or adjudicated ids.
A tag is never moved or re-issued. Returns the exit code.
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
            ok = any(RoundFiles.rounds(cfg)) do r
                r.state == :closed && r.round["instrument"] == "check-docs" && String(r.round["tool_version"]) == latest &&
                    all(e -> e["closed_by"] in ("honored", "adjudicated", "rescan", "seeded"), values(JSON3.read(read(joinpath(r.dir, "verdicts", "pass-$(r.round["passes"])", "tally.json"), String), Dict{String,Any})["per_id"]))
            end
            ok || push!(fails, "no closed /check-docs round stamped $latest under .gbg/rounds/")
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
    println(io, "release: v$ver tagged and pushed", rc ? " (a prerelease: nothing pins it; the /check-docs round opens at it)" : "")
    return 0
end

function cmd_release(args)
    o = parse_options(args)
    isempty(o.positional) && (println(stderr, "usage: gbg release <ver> | gbg release <ver>-rc.<n>"); return 2)
    return release(o.positional[1])
end
VERBS["release"] = cmd_release
