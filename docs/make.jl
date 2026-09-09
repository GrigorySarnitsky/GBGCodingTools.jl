# docs/make.jl — the tool's own site, built through its own wrapper (ARCHITECTURE D9, D15): the quick
# doctor, the hard scans, the gate, Documenter, the built-HTML scans, the gate again. WIRE.MAKEDOCS holds
# here as in every consumer. Run as `julia --project=docs docs/make.jl`.
using Documenter, GBGCodingTools
using GBGCodingTools: TestHarness, Reflection, Witnesses, Config, Doctor

const ROOT = normpath(joinpath(@__DIR__, ".."))

# Generated pages: the architecture copy and the doctor's check table, written from the tool's own data
# so they cannot drift. Both are `generated` globs of the tool's config and gitignored.
cp(joinpath(ROOT, "docs", "ARCHITECTURE.md"), joinpath(@__DIR__, "src", "architecture.md"); force = true)
open(joinpath(@__DIR__, "src", "guide", "doctor.md"), "w") do io
    println(io, "# The doctor's checks\n")
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

GBGCodingTools.makedocs(GBGCodingTools.Config.read(ROOT);
    sitename = "GBGCodingTools",
    modules = [GBGCodingTools, TestHarness, Reflection, Witnesses, Config],
    checkdocs = :exports,
    doctest = true,
    warnonly = [:missing_docs, :cross_references],
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", "") == "true", edit_link = "master",
                             size_threshold = 1_500_000, size_threshold_warn = 600_000),   # the architecture record is one long page by design
    pages = [
        "Home" => "index.md",
        "Guide" => ["guide/install.md", "guide/verbs.md", "guide/rounds.md", "guide/doctor.md", "guide/ledger.md", "guide/config.md"],
        "API" => ["api/TestHarness.md", "api/Reflection.md", "api/Witnesses.md", "api/Config.md", "api/CLI.md"],
        "Architecture" => "architecture.md",
    ],
)

deploydocs(repo = "github.com/GrigorySarnitsky/GBGCodingTools.jl", devbranch = "master", push_preview = false)
