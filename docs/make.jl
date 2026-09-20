# docs/make.jl — the tool's own site, built through its own wrapper: the documentation rules and the
# wiring check, then Documenter, then the rules that read the built site. It holds here as in every
# consumer. Run as `julia --project=docs docs/make.jl`.
using Documenter, GBGCodingTools
using GBGCodingTools: TestHarness, Reflection, Witnesses, Config

const ROOT = normpath(joinpath(@__DIR__, ".."))

# The architecture copy, a generated glob of the tool's config and gitignored. The doctor's check table
# was generated beside it until 2026-09-17; the doctor is deleted and the page with it.
cp(joinpath(ROOT, "docs", "ARCHITECTURE.md"), joinpath(@__DIR__, "src", "architecture.md"); force = true)

# The rulebook as a page, written by the generator every consumer calls. It was built by hand here until
# 2026-09-18; a consumer could not have copied that, which is the whole reason it is a generator now.
# The instruments page was generated here from instruments/<name>/PROTOCOL.md until 2026-09-17; the new
# design generates one per instrument from `Instrument` values, in IMPLEMENTATION.md Phase 4.
GBGCodingTools.Render.pages(GBGCodingTools.ConfigIO.read_config(ROOT), ROOT)

result = GBGCodingTools.makedocs(GBGCodingTools.Config.read(ROOT);
    sitename = "GBGCodingTools",
    modules = [GBGCodingTools, TestHarness, Reflection, Witnesses, Config,
               GBGCodingTools.Model, GBGCodingTools.Texts, GBGCodingTools.Catalogue,
               GBGCodingTools.ConfigIO, GBGCodingTools.Render, GBGCodingTools.Engine.Checks,
               GBGCodingTools.Engine.Guard, GBGCodingTools.Engine.Harness],
    checkdocs = :exports,
    doctest = true,
    warnonly = [:missing_docs],       # explicit @docs blocks, no `export`: :exports checkdocs has nothing to say
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", "") == "true", edit_link = "master",
                             size_threshold = 1_500_000, size_threshold_warn = 600_000),   # the architecture record is one long page by design
    pages = [
        "Home" => "index.md",
        # The guide reads as a sequence first (set up, run a review, see what it produces, read what it judges
        # against), then the four reference tables, most consulted first (2026-09-09, the owner's ruling).
        "Guide" => ["guide/install.md", "gbg-rules.md", "gbg-readers.md", "gbg-instruments.md",
                    "guide/verbs.md", "guide/config.md"],
        # The new tree in its own order — a module may name only the modules above it — then what is
        # left of the old one.
        "API" => ["api/Model.md", "api/Texts.md", "api/Catalogue.md", "api/ConfigIO.md", "api/Engine.md",
                  "api/Render.md", "api/TestHarness.md", "api/Reflection.md", "api/Witnesses.md",
                  "api/Config.md", "api/CLI.md"],
        "Architecture" => "architecture.md",
    ],
)

# The wrapper returns nothing when a docs round froze the build, before Documenter or after it: nothing
# built under a frozen round is deployed, and an unguarded deploy would publish the previous run's
# directory or none at all (WIRE.MAKEDOCS). A build that ran returns `true` (Documenter's own result is
# nothing unless `debug = true`), so a push or a tag with no docs round open deploys the site.
result === nothing ||
    deploydocs(repo = "github.com/GrigorySarnitsky/GBGCodingTools.jl", devbranch = "master", push_preview = false)
