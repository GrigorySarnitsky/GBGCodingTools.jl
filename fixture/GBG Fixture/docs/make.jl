# docs/make.jl — GBGFixture. The build goes through the tool's wrapper (WIRE.MAKEDOCS). Run it as
# `julia --project=docs docs/make.jl` from the fixture root.
using Documenter, GBGCodingTools
using GBGFixture

const ROOT = normpath(joinpath(@__DIR__, ".."))
cp(joinpath(ROOT, "docs", "ARCHITECTURE.md"), joinpath(@__DIR__, "src", "architecture.md"); force = true)

GBGCodingTools.makedocs(ROOT;
    sitename = "GBGFixture",
    modules = [GBGFixture, GBGFixture.FixtureA, GBGFixture.FixtureB, GBGFixture.FixtureC],
    checkdocs = :exports,
    doctest = true,
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", "") == "true"),
    pages = ["Home" => "index.md", "Notation" => "notation.md",
             "API" => ["api/FixtureA.md", "api/FixtureB.md", "api/FixtureC.md"],
             "Architecture" => "architecture.md"],
)
