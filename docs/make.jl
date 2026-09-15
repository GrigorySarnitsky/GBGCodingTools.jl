# docs/make.jl — the tool's own site, built through its own wrapper (ARCHITECTURE D9, D15): the quick
# doctor set (QUICK: the checks that hold on any machine), the hard scans, the gate, Documenter, the built-HTML scans, the gate again. WIRE.MAKEDOCS holds
# here as in every consumer. Run as `julia --project=docs docs/make.jl`.
using Documenter, GBGCodingTools
using GBGCodingTools: TestHarness, Reflection, Witnesses, Config, Doctor

const ROOT = normpath(joinpath(@__DIR__, ".."))

# Generated pages: the architecture copy and the doctor's check table, written from the tool's own data
# so they cannot drift. Both are `generated` globs of the tool's config and gitignored.
cp(joinpath(ROOT, "docs", "ARCHITECTURE.md"), joinpath(@__DIR__, "src", "architecture.md"); force = true)
open(joinpath(@__DIR__, "src", "guide", "doctor.md"), "w") do io
    println(io, "# The doctor's checks\n")
    println(io, "!!! info \"Written by AI, not regularly reviewed\"\n    This page is written by AI and is not reviewed regularly by a human.\n")
    println(io, "Generated at build time from the doctor's own table (`Doctor.CHECKS`): every stable id, its family, whether")
    println(io, "the `QUICK` set runs it, whether it needs `--deep`, and whether a `scope = \"check\"` ledger entry may")
    println(io, "exempt it. The check's own detail line says what failed and what fixes it; ARCHITECTURE §7.3 is the")
    println(io, "authoritative table with the failure conditions.\n")
    println(io, "| Id | Family | QUICK | `--deep` | Exemptable |\n|---|---|---|---|---|")
    for (id, _) in Doctor.CHECKS
        fam = first(split(id, '.'))
        println(io, "| `", id, "` | ", fam, " | ", id in Doctor.QUICK ? "yes" : "", " | ", id in Doctor.DEEP ? "yes" : "", " | ", Doctor.exemptable(id) ? "yes" : "no", " |")
    end
end

# The four instruments' protocols and the rendered rulebook, as pages: the protocol files under
# instruments/<name>/ and the tool's own rendered policy copy under .gbg/policy/, headings demoted one level,
# each instrument and each rule given an @id the home page links to. Both are generated globs, gitignored.
demote(line) = startswith(line, "#") ? "#" * line : line
open(joinpath(@__DIR__, "src", "guide", "instruments.md"), "w") do io
    println(io, "# [The instruments](@id instruments)\n")
    println(io, "!!! info \"Written by AI, not regularly reviewed\"\n    This page is written by AI and is not reviewed regularly by a human.\n")
    println(io, "Generated at build time from `instruments/<name>/PROTOCOL.md`: the text `gbg preflight <name>` injects into the")
    println(io, "session that runs the instrument, verbatim. Each protocol assumes the round its preflight opened, and")
    println(io, "\"the consumer\" in each is the [consumer](@ref install) — the package that pins this tool — the round runs in.\n")
    for name in ("check-docs", "check-consistency", "bug-hunt", "audit-changes")
        lines = readlines(joinpath(ROOT, "instruments", name, "PROTOCOL.md"))
        println(io, "## [`/", name, "`](@id ", name, ")\n")
        for l in lines[2:end]; println(io, startswith(l, "#") ? demote(l) : l); end
        println(io)
    end
end
open(joinpath(@__DIR__, "src", "guide", "rules.md"), "w") do io
    println(io, "# [The rules](@id rules)\n")
    println(io, "!!! info \"Written by AI, not regularly reviewed\"\n    This page is written by AI and is not reviewed regularly by a human.\n")
    println(io, "Generated at build time from this package's rendered policy copy under `.gbg/policy/`: the shared rulebook")
    println(io, "every [consumer](@ref install) imports, with this package's parameters substituted. A rule's id is stable; the scans and the")
    println(io, "doctor cite it.\n")
    for f in ("docs-rubric.md", "latex-idiom.md", "citations.md", "testing-protocol.md", "instruments.md", "git-conventions.md", "glossary.md", "deviations.md")
        for l in readlines(joinpath(ROOT, ".gbg", "policy", f))
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
    modules = [GBGCodingTools, TestHarness, Reflection, Witnesses, Config],
    checkdocs = :exports,
    doctest = true,
    warnonly = [:missing_docs],       # explicit @docs blocks, no `export`: :exports checkdocs has nothing to say
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", "") == "true", edit_link = "master",
                             size_threshold = 1_500_000, size_threshold_warn = 600_000),   # the architecture record is one long page by design
    pages = [
        "Home" => "index.md",
        # The guide reads as a sequence first (set up, run a review, see what it produces, read what it judges
        # against), then the four reference tables, most consulted first (2026-09-09, the owner's ruling).
        "Guide" => ["guide/install.md", "guide/instruments.md", "guide/rounds.md", "guide/rules.md",
                    "guide/verbs.md", "guide/doctor.md", "guide/config.md", "guide/ledger.md"],
        "API" => ["api/TestHarness.md", "api/Reflection.md", "api/Witnesses.md", "api/Config.md", "api/CLI.md"],
        "Architecture" => "architecture.md",
    ],
)

# The wrapper returns nothing when a docs round froze the build, before Documenter or after it: nothing
# built under a frozen round is deployed, and an unguarded deploy would publish the previous run's
# directory or none at all (WIRE.MAKEDOCS). A build that ran returns `true` (Documenter's own result is
# nothing unless `debug = true`), so a push or a tag with no docs round open deploys the site.
result === nothing ||
    deploydocs(repo = "github.com/GrigorySarnitsky/GBGCodingTools.jl", devbranch = "master", push_preview = false)
