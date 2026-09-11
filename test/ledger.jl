using Test, GBGCodingTools, Dates, TOML
include("helpers.jl")

@testset "ledger" begin
    root = fixture_copy("ledger")
    cfg = G.Config.read(root)
    write(joinpath(root, ".gbg", "exemptions.toml"), """
    [[exemption]]
    id = "SCAN.REGISTER"
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
    @test length(G.Ledger.entries(led, "SCAN.REGISTER"; scope = "scan")) == 1
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

# The settled list every panel and verifier prompt carries is the owner's not-a-defect rulings only: a
# `scoped` adjudication closes a real defect without a fix, and 26 such reasons once told every later
# round not to flag defects that were real. Both directions; an absent `ruling` reads as not-a-defect.
@testset "only a not-a-defect ruling is shown as settled" begin
    e(r, ruling) = (d = Dict{String,Any}("scope" => "finding", "reason" => r); ruling === nothing || (d["ruling"] = ruling); d)
    led = [e("ruled no defect", nothing), e("ruled so explicitly", "not-a-defect"), e("put out of scope", "scoped"),
           Dict{String,Any}("scope" => "scan", "reason" => "a scan waiver, never a finding")]
    @test G.Preflight.adjudicated_titles(Dict{String,Any}(), led) == ["ruled no defect", "ruled so explicitly"]
    entry(ruling) = Dict{String,Any}("exemption" => [Dict{String,Any}("id" => "2026-01-01-check-docs-01/src#1", "scope" => "finding",
        "target" => "2026-01-01-check-docs-01/src#1", "reason" => "a reason long enough to be a reason at all",
        "recorded" => Date(2026, 1, 1), "overturn_when" => "the finding reappears", "ruling" => ruling)])
    schema = G.load_schema("exemptions")
    @test isempty(G.validate(schema, entry("scoped"))) && !isempty(G.validate(schema, entry("fixed")))   # a closed set
end
