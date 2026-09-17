# test/config.jl — what the OLD config reader still guarantees.
#
# `.gbg/config.toml` is the legacy config, read by what is left of the old tree and deleted with it in
# Phase 5. Its JSON-Schema validation went with `schema/` on 2026-09-17, and with it the three refusals
# this file used to assert — an unknown table, a branch that is not `master`, a `docs_build` command
# naming a script other than `docs/make.jl`. Nothing replaces them here: the config that matters is
# `.gbg/config.jl`, whose refusals are Julia and are held by test/configio.jl.
#
# `Init.derive_config` was tested here too, and went with `Init`. A package's config is written by
# `gbg init` from a seed now, and read rather than derived: a config guessed from a tree is a config
# nobody wrote and nobody owns.
#
# What is left is what the reader still does for its remaining callers: read, resolve a surface, find
# an anchor, and refuse a path that does not exist.
using Test, GBGCodingTools, TOML
include("helpers.jl")

@testset "config" begin
    cfg = G.Config.read(FIXTURE)
    @test cfg["package"]["name"] == "GBGFixture"
    @test cfg["tool"]["version"] == "dev"
    @test "docs/src/index.md" in G.Config.surface_files(cfg, "pages")
    @test G.Config.resolve_anchor(FIXTURE, "docs/ARCHITECTURE.md#3. Decision log")[3] == 1
    @test isempty(G.Config.check_paths(cfg))
    # a path that names nothing is still a refusal, and it is the one this reader is kept for
    let text = read(joinpath(FIXTURE, ".gbg", "config.toml"), String)
        @test_throws G.Config.ConfigError G.Config.parse(
            replace(text, "src = [\"src/*.jl\"]" => "src = [\"nowhere/*.jl\"]"); root = FIXTURE)
    end
end
