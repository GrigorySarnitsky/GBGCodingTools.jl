# Shared helpers of the self-tests: a fresh copy of the fixture under a system temporary directory, the
# derived config that adds the defects corpus to the surfaces, and a quiet IO.
#
# The scratch is NEVER inside the repository. Every repository here lives in Dropbox, and this scratch
# once grew to 61,057 directories — the fixture is copied per test and only runtests.jl cleaned up, so an
# interrupted run left its copies behind — which passed the system's inotify watch limit and stopped
# Dropbox syncing for every package at once (2026-09-16). `mktempdir` puts it under TMPDIR, outside any
# synced tree, and the copy's `dev` pin stays legal because its docs/ and test/ environments name this
# checkout as a `[sources]` path, which is what the doctor's rule now asks for.
using GBGCodingTools, TOML, JSON3
const G = GBGCodingTools
const TOOL = normpath(joinpath(@__DIR__, ".."))
const FIXTURE = joinpath(TOOL, "fixture", "GBG Fixture")
const TMP = mktempdir(; prefix = "gbg-selftest-", cleanup = true)

# The witness runner starts a fresh process on the fixture's TEST environment. A clone carries no
# Manifest there (the tool's first CI run failed on `using GBGFixture` in every witness), so it is
# resolved once per suite here; the manifest is gitignored and every dependency is local or already in the depot.
# Under `Pkg.test()` the inherited JULIA_LOAD_PATH names the sandbox and no stdlib, so the child gets the
# stdlib back explicitly (or `using Pkg` fails, as the second CI dispatch showed).
let proj = joinpath(FIXTURE, "test"), sep = Sys.iswindows() ? ";" : ":"
    isfile(joinpath(proj, "Manifest.toml")) ||
        run(addenv(`$(Base.julia_cmd()) --startup-file=no --project=$proj -e "using Pkg; Pkg.instantiate()"`, "JULIA_LOAD_PATH" => "@" * sep * "@stdlib"))
end

"""A fresh copy of the fixture at `TMP/<name>/` (build products excluded). Returns its root."""
function fixture_copy(name)
    dst = joinpath(TMP, name)
    rm(dst; recursive = true, force = true); mkpath(dirname(dst))
    cp(FIXTURE, dst; force = true)
    for d in ("docs/build", ".gbg/scratch"); rm(joinpath(dst, d); recursive = true, force = true); end
    # the copy sits outside the repository: its paths to the tool checkout are recomputed as absolute
    for env in ("docs", "test")
        pj = joinpath(dst, env, "Project.toml")
        write(pj, replace(read(pj, String), "GBGCodingTools = {path = \"../../..\"}" => "GBGCodingTools = {path = \"" * TOOL * "\"}"))
    end
    # the copy's managed files were rendered for the fixture's own inputs; re-sync so its sidecar is its own
    G.Sync.sync(G.Config.read(dst); io = devnull)
    return dst
end

fixture_config(root = FIXTURE; check = false) = G.Config.parse(read(joinpath(FIXTURE, ".gbg", "config.toml"), String); root, check)

"""The fixture's config with the defects corpus added to every surface it belongs to."""
function defects_config(root = FIXTURE)
    cfg = fixture_config(root)
    push!(cfg["surfaces"]["src"], "defects/Defects.jl")
    append!(cfg["surfaces"]["pages"], ["defects/page.md", "defects/api/defects.md"])
    push!(cfg["surfaces"]["rationale"], "defects/RATIONALE.md")
    push!(cfg["surfaces"]["literate"], "defects/literate-no-banner.jl")
    cfg["surfaces"]["data"] = ["defects/data-*.toml"]      # the optional data surface, on for the corpus
    return cfg
end

const DEFECTS = TOML.parsefile(joinpath(FIXTURE, "defects.toml"))
const CATALOG = Dict(r["id"] => r for r in G.scan_catalog())
# The scans that must load the package. SCAN.SIGNATURE_FIDELITY was the last of them and went on
# 2026-09-17; the tuple is empty rather than gone, because the next scan converted is read here too.
const REFLECTION = ()

quiet(f) = f(devnull)

# A ROUND.toml as `preflight` writes it, for a test that needs a round in a given state without paying
# for one. The banner line is what `RoundFiles` and the doctor read past.
function write_round(dir, rec)
    open(joinpath(dir, "ROUND.toml"), "w") do f
        println(f, "# ROUND.toml — written by gbg preflight; the CLI's marker, never edited by hand (ARCHITECTURE §6.1)")
        TOML.print(f, rec)
    end
end
