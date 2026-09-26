# The toy consumer's settings: data, never evaluated.
Config(
    package = "GBGFixture",
    tool = :dev,
    docs_build = ["julia", "--project=docs", "docs/make.jl"],
    test = ["julia", "--project", "-e", "using Pkg; Pkg.test()"],
    filesets = Dict(
        FileSet.CODE => ["src/FixtureA.jl", "src/FixtureB.jl", "src/FixtureC.jl", "src/GBGFixture.jl"],
        FileSet.PAGES => ["docs/src/index.md", "docs/src/notation.md", "docs/src/api/FixtureA.md", "docs/src/api/FixtureB.md", "docs/src/api/FixtureC.md"],
        FileSet.RATIONALE => ["docs/ARCHITECTURE.md"],
        FileSet.LITERATE => ["examples/scaling.jl"],
    ),
)
