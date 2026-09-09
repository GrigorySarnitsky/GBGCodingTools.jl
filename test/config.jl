using Test, GBGCodingTools, TOML
include("helpers.jl")

@testset "config" begin
    cfg = G.Config.read(FIXTURE)
    @test cfg["package"]["name"] == "GBGFixture"
    @test cfg["tool"]["version"] == "dev"
    @test "docs/src/index.md" in G.Config.surface_files(cfg, "pages")
    @test G.Config.resolve_anchor(FIXTURE, "docs/ARCHITECTURE.md#3. Decision log")[3] == 1
    @test isempty(G.Config.check_paths(cfg))
    # CFG.SURFACES checks the script `docs_build` NAMES, not a fixed path: a consumer whose command runs
    # another file had the file it never runs checked and the one it runs ignored. Both directions.
    @test isempty(G.Config.check_paths(merge(cfg, Dict("package" => merge(cfg["package"],
                  Dict("docs_build" => "julia --project=docs docs/make.jl"))))))
    let bad = G.Config.check_paths(merge(cfg, Dict("package" => merge(cfg["package"],
                  Dict("docs_build" => "julia --project=docs docs/build_the_site.jl")))))
        @test any(e -> occursin("build_the_site.jl", e) && occursin("docs_build", e), bad)
    end
    @testset "refusals" begin
        text = read(joinpath(FIXTURE, ".gbg", "config.toml"), String)
        @test_throws G.Config.ConfigError G.Config.parse(replace(text, "branch = \"master\"" => "branch = \"trunk\""); root = FIXTURE)
        @test_throws G.Config.ConfigError G.Config.parse(text * "\n[unknown]\nx = 1\n"; root = FIXTURE)
        @test_throws G.Config.ConfigError G.Config.parse(replace(text, "src = [\"src/*.jl\"]" => "src = [\"nowhere/*.jl\"]"); root = FIXTURE)
    end
    @testset "derive_config on the fixture tree" begin
        d = G.Init.derive_config(FIXTURE)
        @test d["tool"]["version"] == "dev"          # inside the tool repository
        @test "FixtureA" in d["package"]["modules"]
        @test d["surfaces"]["references_heading"] == "docs/ARCHITECTURE.md#References"
    end
end
