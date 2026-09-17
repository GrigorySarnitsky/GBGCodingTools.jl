# .gbg/config.jl — this package's settings, as data (docs/ARCHITECTURE.md §5.2).
#
# Read by ConfigIO, which parses this file and evaluates nothing: only literals and the constructors of
# Model are accepted here. It is two fields and one list while the rebuild is in Phase 1; the file sets,
# switches and settings arrive with the rulebook, and .gbg/config.toml stays until the old tree goes.
Config(
    package = "GBGCodingTools",
    tool = :dev,
    normative = ["docs/ARCHITECTURE.md", "IMPLEMENTATION.md"],
    # Written by docs/make.jl at build time. No rule reads one: a page that LISTS the rules necessarily
    # holds text that breaks them, and a page copied from elsewhere belongs to what it was copied from.
    generated = ["docs/src/guide/rules.md", "docs/src/guide/doctor.md"],
    copies = ["docs/src/architecture.md" => "docs/ARCHITECTURE.md"],
)
