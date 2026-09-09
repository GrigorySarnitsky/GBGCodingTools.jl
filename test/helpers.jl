# Shared helpers of the self-tests: a fresh copy of the fixture under fixture/.tmp/<name>/ (inside the
# tool repository, so its `dev` pin and its `path` sources stay legal), the derived config that adds the
# defects corpus to the surfaces, and a quiet IO.
using GBGCodingTools, TOML, JSON3
const G = GBGCodingTools
const TOOL = normpath(joinpath(@__DIR__, ".."))
const FIXTURE = joinpath(TOOL, "fixture", "GBG Fixture")
const TMP = joinpath(TOOL, "fixture", ".tmp", string(getpid()))

# The witness runner starts a fresh process on the fixture's TEST environment. A clone carries no
# Manifest there (the tool's first CI run failed on `using GBGFixture` in every witness), so it is
# resolved once per suite here; the manifest is gitignored and every dependency is local or already in the depot.
let proj = joinpath(FIXTURE, "test")
    isfile(joinpath(proj, "Manifest.toml")) || run(`$(Base.julia_cmd()) --startup-file=no --project=$proj -e "using Pkg; Pkg.instantiate()"`)
end

"""A fresh copy of the fixture at fixture/.tmp/<name>/ (build products excluded). Returns its root."""
function fixture_copy(name)
    dst = joinpath(TMP, name)
    rm(dst; recursive = true, force = true); mkpath(dirname(dst))
    cp(FIXTURE, dst; force = true)
    for d in ("docs/build", ".gbg/scratch"); rm(joinpath(dst, d); recursive = true, force = true); end
    # the copy sits deeper than the fixture: its relative paths to the tool repository are recomputed
    c = joinpath(dst, ".gbg", "config.toml")
    write(c, replace(read(c, String), "\"../../catalog/seeds/fixture.toml\"" => "\"" * relpath(joinpath(TOOL, "catalog", "seeds", "fixture.toml"), dst) * "\""))
    for env in ("docs", "test")
        pj = joinpath(dst, env, "Project.toml")
        write(pj, replace(read(pj, String), "GBGCodingTools = {path = \"../../..\"}" => "GBGCodingTools = {path = \"" * relpath(TOOL, joinpath(dst, env)) * "\"}"))
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
    return cfg
end

const DEFECTS = TOML.parsefile(joinpath(FIXTURE, "defects.toml"))
const CATALOG = Dict(r["id"] => r for r in G.scan_catalog())
const REFLECTION = ("SCAN.ARGCOV", "SCAN.SIGNATURE_FIDELITY", "SCAN.XLINK", "SCAN.DUPREF")

quiet(f) = f(devnull)
