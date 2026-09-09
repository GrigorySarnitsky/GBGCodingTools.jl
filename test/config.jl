using Test, GBGCodingTools, TOML
include("helpers.jl")

@testset "config" begin
    cfg = G.Config.read(FIXTURE)
    @test cfg["package"]["name"] == "GBGFixture"
    @test cfg["tool"]["version"] == "dev"
    @test "docs/src/index.md" in G.Config.surface_files(cfg, "pages")
    @test G.Config.resolve_anchor(FIXTURE, "docs/ARCHITECTURE.md#3. Decision log")[3] == 1
    @test isempty(G.Config.check_paths(cfg))
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
