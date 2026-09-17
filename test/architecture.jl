# test/architecture.jl — the design's own structural rules, as a program rather than as prose
# (docs/ARCHITECTURE.md §5.1, §2; IMPLEMENTATION.md Phase 1).
#
# Three things are held here. The MODULE ORDER: each module of the new tree may name only modules below
# it, so a check cannot reach the machinery that runs it and the harness cannot reach a run record. The
# SHRINKING LEGACY: every file of the old tree is listed with a count that only falls, so a reader knows
# which machine is live by running the suite rather than by looking. And SELF-APPLICATION: this package
# is the LAST consumer of its own instruments (Phase 8), because pointing them at itself is what went
# wrong before — the machine became the work — and a promise not to is worth less than a test.
using Test, GBGCodingTools, TOML
include("helpers.jl")

# The new tree, each file with its rank in the order Model → Texts → Catalogue → ConfigIO → Engine →
# Render → Orchestration → CLI. A file lands here in the phase that writes it.
const LAYERS = Dict("src/Model.jl" => 1, "src/Texts.jl" => 2, "src/ConfigIO.jl" => 4,
                    "src/Engine.jl" => 5, "src/Engine/Guard.jl" => 5)

const RANK_OF_MODULE = Dict("Model" => 1, "Texts" => 2, "Catalogue" => 3, "ConfigIO" => 4,
                            "Engine" => 5, "Render" => 6, "Orchestration" => 7, "CLI" => 8)

# The tree being replaced. This number only falls; a commit that raises it fails here, which is what
# makes "two machines in one tree" a measured state rather than a feeling.
const LEGACY_CEILING = 67

legacy_files() = sort([relpath(joinpath(r, f), TOOL) for (r, _, fs) in walkdir(joinpath(TOOL, "src"))
                       for f in fs if endswith(f, ".jl") && !haskey(LAYERS, relpath(joinpath(r, f), TOOL))])

@testset "the module order, the legacy count, and self-application" begin
    @testset "every source file is in one tree or the other" begin
        all_jl = [relpath(joinpath(r, f), TOOL) for (r, _, fs) in walkdir(joinpath(TOOL, "src"))
                  for f in fs if endswith(f, ".jl")]
        for f in all_jl
            @test haskey(LAYERS, f) || f in legacy_files()
        end
        @test !isempty(LAYERS)
    end

    @testset "the legacy tree only shrinks" begin
        n = length(legacy_files())
        @test n <= LEGACY_CEILING
        # and the ceiling is not left far above the truth, which would make it stop measuring anything
        @test n >= LEGACY_CEILING - 8
    end

    @testset "no file of the new tree reaches a module above it" begin
        for (file, rank) in LAYERS
            text = read(joinpath(TOOL, file), String)
            for (mod, r) in RANK_OF_MODULE
                r <= rank && continue
                @test !occursin(Regex("\\b" * mod * "\\.[A-Za-z_]"), text)
            end
        end
    end

    # The rule the science packages depend on: what runs inside a consumer's build or test may not read
    # review state, because CI and a fresh clone must give the same answer. It is checked over the whole
    # tree, old and new, since the extension and the harness are what a consumer actually runs.
    @testset "nothing a build or a test runs reads review state" begin
        for f in ("ext/GBGCodingToolsDocumenterExt.jl", "src/TestHarness.jl", "src/DocLints.jl")
            text = read(joinpath(TOOL, f), String)
            for forbidden in (".gbg/runs", ".gbg/rounds", "questions.json", "settled.jl", "Orchestration.")
                @test !occursin(forbidden, text)
            end
        end
    end

    # Self-application, three ways. Not the fourth the plan named — that this package's docs/make.jl call
    # `Documenter.makedocs` plainly — because the owner ruled on 2026-09-15 that the DETERMINISTIC checks
    # keep working here (rogue formatting, uniform docstring structure) while the domain-specific parts
    # stay off. The wrapper is that deterministic half, so it stays; what must not come back early is an
    # instrument.
    @testset "this package is its own last consumer, not its first" begin
        cfg = TOML.parsefile(joinpath(TOOL, ".gbg", "config.toml"))
        @test !haskey(cfg, "instruments")                               # no instrument is configured here
        skills = joinpath(TOOL, ".claude", "skills")
        @test !isdir(skills) || issubset(Set(readdir(skills)), Set(["gbg-doctor"]))
        @test !isdir(joinpath(TOOL, ".gbg", "runs"))                    # no run has been recorded here
        @test occursin("GBGCodingTools.makedocs", read(joinpath(TOOL, "docs", "make.jl"), String))
    end
end
