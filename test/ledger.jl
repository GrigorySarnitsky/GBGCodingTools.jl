using Test, GBGCodingTools, Dates, TOML
include("helpers.jl")

@testset "ledger" begin
    root = fixture_copy("ledger")
    cfg = G.Config.read(root)
    write(joinpath(root, ".gbg", "exemptions.toml"), """
    [[exemption]]
    id = "SCAN.XLINK"
    scope = "scan"
    target = "src/FixtureA.jl"
    reason = "a forty-character reason for the ledger arm of the self-tests here"
    recorded = $(today())
    expires = $(today() + Day(10))
    [[exemption]]
    id = "$(basename(root))/cold-reader#1"
    scope = "finding"
    target = "2026-01-01-check-consistency-01/cold-reader#1"
    reason = "adjudicated: the glossary defines the term; a forty-character reason"
    recorded = $(today())
    overturn_when = "the glossary loses the entry"
    """)
    led = G.Ledger.read(cfg)
    @test length(led) == 2
    @test length(G.Ledger.entries(led, "SCAN.XLINK"; scope = "scan")) == 1
    @test G.Ledger.matches(led[1], root; file = "src/FixtureA.jl")
    @test !G.Ledger.matches(led[1], root; file = "src/FixtureB.jl")
    checks, _ = G.Doctor.run(cfg; only = ["CFG.EXEMPTIONS", "EXEMPT"], io = devnull)
    st = Dict(c.id => c.status for c in checks)
    @test st["CFG.EXEMPTIONS"] == :PASS
    @test st["EXEMPT.EXPIRING"] == :WARN
    @test st["EXEMPT.STALE"] == :FAIL                       # the finding id names no round
    @testset "refusals" begin
        bad = replace(read(joinpath(root, ".gbg", "exemptions.toml"), String), "expires = $(today() + Day(10))" => "expires = $(today() + Day(400))")
        write(joinpath(root, ".gbg", "exemptions.toml"), bad)
        checks, _ = G.Doctor.run(cfg; only = ["CFG.EXEMPTIONS"], io = devnull)
        @test first(checks).status == :FAIL                  # beyond recorded + 365 d
        write(joinpath(root, ".gbg", "exemptions.toml"), """
        [[exemption]]
        id = "PIN.CONFIG"
        scope = "check"
        target = "*"
        reason = "trying to switch the pin check off, which the ledger must refuse to do"
        recorded = $(today())
        expires = $(today() + Day(30))
        """)
        checks, _ = G.Doctor.run(cfg; only = ["CFG.EXEMPTIONS"], io = devnull)
        @test first(checks).status == :FAIL && occursin("non-exemptable", first(checks).detail)
    end
end

# The settled-titles testset stood here until 2026-09-17: it held `Preflight.adjudicated_titles`, the
# reader that told every panel which rulings were the owner's not-a-defect ones. That reader went
# with the round machinery; the new design keeps such rulings in `.gbg/settled.jl` and gives them to
# agents from there (docs/ARCHITECTURE.md §8).

