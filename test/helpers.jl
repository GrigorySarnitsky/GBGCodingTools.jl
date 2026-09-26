# Shared helpers of the self-tests: the tool's root, the fixture, and a fresh copy of the fixture under a
# system temporary directory.
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
    # the copy's generated files name a path to the tool that the copy does not have; rewrite them where
    # they stand, which is what the copy's own `gbg sync` would do
    G.Wire.sync(dst; io = devnull)
    return dst
end
