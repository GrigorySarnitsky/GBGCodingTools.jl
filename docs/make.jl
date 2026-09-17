# docs/make.jl — the tool's own site, built through its own wrapper: the documentation rules and the
# wiring check, then Documenter, then the rules that read the built site. It holds here as in every
# consumer. Run as `julia --project=docs docs/make.jl`.
using Documenter, GBGCodingTools
using GBGCodingTools: TestHarness, Reflection, Witnesses, Config

const ROOT = normpath(joinpath(@__DIR__, ".."))

# The architecture copy, a generated glob of the tool's config and gitignored. The doctor's check table
# was generated beside it until 2026-09-17; the doctor is deleted and the page with it.
cp(joinpath(ROOT, "docs", "ARCHITECTURE.md"), joinpath(@__DIR__, "src", "architecture.md"); force = true)

# The four instruments' protocols and the rendered rulebook, as pages: the protocol files under
# instruments/<name>/ and the tool's own rendered policy copy under .gbg/policy/, headings demoted one level,
# each instrument and each rule given an @id the home page links to. Both are generated globs, gitignored.
demote(line) = startswith(line, "#") ? "#" * line : line
# The instruments page was generated here from instruments/<name>/PROTOCOL.md until 2026-09-17. The
# protocols are filed under docs/design-record/instruments-v1/; the new design generates a page per
# instrument from Instrument values instead (docs/ARCHITECTURE.md §6), in IMPLEMENTATION.md Phase 4.
open(joinpath(@__DIR__, "src", "guide", "rules.md"), "w") do io
    println(io, "# [The rules](@id rules)\n")
    println(io, "!!! info \"Written by AI, not regularly reviewed\"\n    This page is written by AI and is not reviewed regularly by a human.\n")
    println(io, "Generated at build time from this package's rendered policy copy under `.gbg/policy/`: the shared rulebook")
    println(io, "every [consumer](@ref install) imports, with this package's parameters substituted. A rule's id is stable; the scans and the")
    println(io, "rules cite it.\n")
    for f in GBGCodingTools.Render.policy_paths()
        for l in readlines(joinpath(ROOT, f))
            startswith(l, "<!-- gbg:managed") && continue
            m = match(r"^### (RULE\.[A-Z]+\.[A-Z_]+)\s*$", l)
            g = match(r"^# (Glossary\b.*)$", l)                  # the terms, given an id the guide pages link to
            println(io, m !== nothing ? "#### [`$(m.captures[1])`](@id $(m.captures[1]))" :
                        g !== nothing ? "## [$(g.captures[1])](@id glossary)" : demote(l))
        end
        println(io)
    end
end

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
        "Guide" => ["guide/install.md", "guide/rules.md", "guide/verbs.md", "guide/config.md"],
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
