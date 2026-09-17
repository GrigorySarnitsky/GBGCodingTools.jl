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
    generated = ["docs/src/guide/rules.md"],
    copies = ["docs/src/architecture.md" => "docs/ARCHITECTURE.md"],
    # What this package does not hold itself to. These were entries in `.gbg/exemptions.toml` with a
    # recorded date and an expiry; a switch carries the reason and nothing else, because an expiry on a
    # deviation that is structural — this package computes no physical quantity, and will not next year —
    # only schedules the work of writing it down again.
    switches = [
        Switch(target = Symbol("RULE.TEST.ALLOC_ZERO"),
               reason = "no in-place operator over element storage exists here: this package's `!` functions mutate a registry, a dictionary or a string buffer, and an allocation bound on them measures the Julia runtime, not the package"),
        Switch(target = Symbol("RULE.TEST.PASS_AUDIT"),
               reason = "the traffic audit counts reads and writes per array element; this package holds no array whose traffic is a correctness property, so a frozen row would record the runtime's behaviour and nothing of the package's"),
        Switch(target = Symbol("RULE.TEST.EXAMPLES_RUN"),
               reason = "this package ships no Literate examples: a worked example of a review instrument is a review, which is recorded rather than executed as a script"),
        Switch(target = Symbol("RULE.DOC.LEADING_IDENTITY"),
               reason = "the leading identity of a docstring is the physical meaning of the quantity it computes; this package computes no physical quantity, so its docstrings lead with what the operation does, which the rule's own parameter already admits"),
        Switch(target = Symbol("RULE.API.POSITIONAL"),
               reason = "no program decides whether an argument affects the result, and this package's own reading panels do not run over it yet; it is switched off here until they do"),
    ],
)
