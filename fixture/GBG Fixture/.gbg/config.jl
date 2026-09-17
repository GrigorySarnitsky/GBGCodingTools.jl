# The toy consumer's settings, in the format the rebuilt package reads: data, never evaluated.
# .gbg/config.toml stays beside it until the tree being replaced is gone.
Config(
    package = "GBGFixture",
    tool = :dev,
    docs_build = ["julia", "--project=docs", "docs/make.jl"],
    test = ["julia", "--project", "-e", "using Pkg; Pkg.test()"],
    filesets = Dict(
        FileSet.CODE => ["src/FixtureA.jl", "src/FixtureB.jl", "src/FixtureC.jl", "src/GBGFixture.jl"],
        FileSet.PAGES => ["docs/src/index.md", "docs/src/notation.md", "docs/src/api/fixture.md"],
        FileSet.RATIONALE => ["docs/ARCHITECTURE.md"],
        FileSet.LITERATE => ["examples/walkthrough.jl"],
    ),
)
