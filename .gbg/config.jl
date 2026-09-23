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
    generated = ["docs/src/gbg-rules.md", "docs/src/gbg.md"],
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
        Switch(target = :documentation_review,
               reason = "the review reads a package's documentation with the rulebook this package writes; running it here while the rulebook and the run machinery are still being built would grade the tool against rules it is in the middle of changing. It is switched on in Phase 8, when the tool reviews itself last"),
    ],
    # STRICTER THAN THE FLEET, and this package's alone: every page of this site carries the provenance
    # banner, because the owner reviews the four science packages' API prose and not this one's.
    # `CLAUDE.md` has said so since Phase 1 and nothing enforced it — the rule read `rationale` and
    # `literate`, which for this package is two documents and no examples at all.
    settings = [
        Setting(rule = Symbol("RULE.DOC.AI_BANNER"), name = :banner_pages,
                # The site's pages and the rationale document behind one of them. The home page is
                # exempt FLEET-WIDE and is not exempt here, which is what "every page" means.
                # `IMPLEMENTATION.md` is not on the site and is not listed.
                value = ["docs/src/**/*.md", "docs/ARCHITECTURE.md"]),
    ],
)
