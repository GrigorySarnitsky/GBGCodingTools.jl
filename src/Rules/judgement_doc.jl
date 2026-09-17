"""
    Rules.JudgementDoc

The `RULE.DOC.*` rules that no program decides: those an agent judges, and those nothing checks at
all. Each carries its statement and the reason it exists, so a reader of the rulebook sees the same
text whether a program enforces it or a person does.

A rule with no check states why in `unchecked_reason` rather than pretending to one; a rule an agent
decides says which of the three admitted reasons a program cannot (`docs/ARCHITECTURE.md` §7).
"""
module JudgementDoc

using ...Model

const TWO_TIER = Model.Rule(
    id = Symbol("RULE.DOC.TWO_TIER"),
    statement = "A module docstring is a map (linked one-liners, no formulas); a function docstring is a home.",
    why = "The map states what the module is, its scope and place in the architecture, and its invariants — then a linked one-liner per operation family, and no formulas; every formula lives in the operation's …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("A module docstring is a map (linked one-liners, no formulas); a function docstring is a home.", Model.WhyAgent.READING_ORDER))

const HOME_ORDER = Model.Rule(
    id = Symbol("RULE.DOC.HOME_ORDER"),
    statement = "A function docstring is ordered: identity, when-to-use, arguments, one formula, citation, links, caveats, then `# References`, then `# Fields` last; internals, jargon and rationale are excluded.",
    why = "In full: (1) a plain one-sentence identity in the user's terms; (2) when to use it, versus the alternatives; (3) each argument (positional and keyword) and its effect; (4) one formula if a clean one …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const LEADING_IDENTITY = Model.Rule(
    id = Symbol("RULE.DOC.LEADING_IDENTITY"),
    statement = "Item (1) is a plain one-sentence identity, physical-meaning first or estimand first (rubric.leading_identity).",
    why = "For this package the identity leads with {{rubric.leading_identity}}: an operation computed in a derived representation still states what it does to the real object first — with the explicit …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("Item (1) is a plain one-sentence identity, physical-meaning first or estimand first (rubric.leading_identity).", Model.WhyAgent.MEANING))

const ONE_HOME = Model.Rule(
    id = Symbol("RULE.DOC.ONE_HOME"),
    statement = "One concept, one home: one docstring per operation on the bare binding; the ! form owns the formula and is listed first; every other variant is a thin wrapper that @ref-links the home and carries no second formula.",
    why = "Per-scheme or per-representation specifics live in the scheme's or the representation's own docstring, linked. Across an `f`/`f!` pair the in-place `!` form is the home — it owns the formula and the …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const VARIANT_PAIR = Model.Rule(
    id = Symbol("RULE.DOC.VARIANT_PAIR"),
    statement = "Across an f/f! or getter/setter pair the defining math appears once; the wrapper carries no display formula (the review unit is the variant set).",
    why = "Typed twice, the math drifts — one member writing a partial one way and its twin another — and a within-string check cannot see it; a lane that groups each operation's generics and diffs them can.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const ADMONITION_TITLE = Model.Rule(
    id = Symbol("RULE.DOC.ADMONITION_TITLE"),
    statement = "Every !!! block carries a custom descriptive title (docs.admonition_titles: always, or load-bearing only).",
    why = "For this package the rule is {{docs.admonition_titles}}: either every `!!!` block carries a custom descriptive title, or a block carrying one load-bearing claim does while a general aside may stay a …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const STEER = Model.Rule(
    id = Symbol("RULE.DOC.STEER"),
    statement = "Every ! form with an allocating sibling carries the verbatim in-place steer sentence, naming its own destination argument.",
    why = "The sentence is the template below — a template, not a link: `destination` is replaced by the argument the signature actually has and `f` by the allocating sibling's own name, so the `@ref` resolves …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const ALIASING_BULLET = Model.Rule(
    id = Symbol("RULE.DOC.ALIASING_BULLET"),
    statement = "An operation-specific aliasing statement lives in the destination bullet; the package-wide guarantee lives in the module docstring.",
    why = "The package-wide guarantee lives in the module docstring and is not repeated per operation; an operation states it for itself only when it has an operation-specific reason, or when its contract is …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("An operation-specific aliasing statement lives in the destination bullet; the package-wide guarantee lives in the module docstring.", Model.WhyAgent.MEANING))

const COVERAGE_BASES = Model.Rule(
    id = Symbol("RULE.DOC.COVERAGE_BASES"),
    statement = "A measure reduction documents every base it supports.",
    why = "A measure reduction over a grid and the same reduction over a point set are both stated where the operation is documented.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("A measure reduction documents every base it supports.", Model.WhyAgent.MEANING))

const GRAMMAR = Model.Rule(
    id = Symbol("RULE.DOC.GRAMMAR"),
    statement = "Every sentence has a subject and a verb; concise means few words, not missing verbs.",
    why = "Concise means few words, not missing verbs — compact prose that still reads as sentences aloud.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("Every sentence has a subject and a verb; concise means few words, not missing verbs.", Model.WhyAgent.MEANING))

const VERIFIED = Model.Rule(
    id = Symbol("RULE.DOC.VERIFIED"),
    statement = "Every formula, normalization, adjoint relation and cross-scheme equivalence is verified by expansion against the code, never asserted.",
    why = "A plausible 'X is just Y' is a false claim until the expansion matches. Run this as a positive verification — enumerate every formula, constant, relation and quantifier and verify each — not as a …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("Every formula, normalization, adjoint relation and cross-scheme equivalence is verified by expansion against the code, never asserted.", Model.WhyAgent.MEANING))

const SELF_CONTAINED = Model.Rule(
    id = Symbol("RULE.DOC.SELF_CONTAINED"),
    statement = "A rationale doc reads top to bottom without another file: every symbol is bound in plain language at first use.",
    why = "Later uses may be bare; universally standard mathematics may stand unglossed. A decision-log entry browsed on its own meets the same bar.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("A rationale doc reads top to bottom without another file: every symbol is bound in plain language at first use.", Model.WhyAgent.READING_ORDER))

const TERMS_DEFINED = Model.Rule(
    id = Symbol("RULE.DOC.TERMS_DEFINED"),
    statement = "A term of art is defined in a clause or @ref-linked on first use; the acceptance test is the cold read.",
    why = "A docstring can bind every symbol and still be unreadable to someone who has not read the module, because its terms of art are nouns, not symbols; parse it with the module's context withheld, and a …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("A term of art is defined in a clause or @ref-linked on first use; the acceptance test is the cold read.", Model.WhyAgent.MEANING))

const CLASS_SWEEP = Model.Rule(
    id = Symbol("RULE.DOC.CLASS_SWEEP"),
    statement = "A flagged instance is a sample of a class: sweep every surface for the class and fix all in one pass.",
    why = "Fixing only the pointed-at line and waiting to be handed the next instance is the failure this rule exists to stop. After a class fix, enumerate the surfaces from the finding's own text, not from …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("A flagged instance is a sample of a class: sweep every surface for the class and fix all in one pass.", Model.WhyAgent.MEANING))

const BATTERY = Model.Rule(
    id = Symbol("RULE.DOC.BATTERY"),
    statement = "'Check the docs' means the complete battery over every surface, never one check or one file.",
    why = "When asked to check, review or audit the documentation in any words, run the full matrix — every check across every surface — and report it; do not run one check, sweep one file, and stop.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const LITERATE = Model.Rule(
    id = Symbol("RULE.DOC.LITERATE"),
    statement = "A Literate example is a rendered page: full-line # comments are prose, their math is LaTeX, control-flow-internal comments use ##.",
    why = "A full-line comment inside a control-flow block splits the code fence, so reserve full-line `# ` for narrative prose at statement boundaries. An underscored identifier in that prose is backticked, …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const BUILD_VERIFY = Model.Rule(
    id = Symbol("RULE.DOC.BUILD_VERIFY"),
    statement = "A doc edit is verified by the full docs build exiting 0, never by a diff, a lint subset or a log grep.",
    why = "A lint run standalone cannot see a dangling reference, and grepping a log for error text passes a build that died at load. After editing a Literate example, regenerate it and read the output.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "the rulebook does not check it: harness:makedocs enforces it inside a package's own test suite")

const ONE_NOTATION = Model.Rule(
    id = Symbol("RULE.DOC.ONE_NOTATION"),
    statement = "One notation per concept and one concept per notation; a local use yields to a package-wide glyph.",
    why = "Before introducing a symbol, check it is not a synonym for one already in use, and check the section for the glyph and confirm it is free. When an edit introduces a symbol, retire the old one.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("One notation per concept and one concept per notation; a local use yields to a package-wide glyph.", Model.WhyAgent.DERIVATION))

const COORD_FREE = Model.Rule(
    id = Symbol("RULE.DOC.COORD_FREE"),
    statement = "Maps and pairings are stated intrinsically; matrix/flattening machinery is confined to the formalization doc.",
    why = "Component notation for a genuine fiber algebra is fine; the rule targets flattening a structured space to a bare vector. Where a basis form is needed to mirror the code, state the basis and the …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("Maps and pairings are stated intrinsically; matrix/flattening machinery is confined to the formalization doc.", Model.WhyAgent.MEANING))

const MODULE_MAP = Model.Rule(
    id = Symbol("RULE.DOC.MODULE_MAP"),
    statement = "A module docstring lists one linked one-liner per operation family and no formula.",
    why = "Its order is identity, then the contents list, then an optional trailing remark.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const RETURNS = Model.Rule(
    id = Symbol("RULE.DOC.RETURNS"),
    statement = "A type docstring leads with its constructor; a '-> Type' arrow or a 'Returns x.' sentence states the result where the identity sentence does not.",
    why = "A mutator whose signature carries no arrow says what it returns in a sentence before any caveat; a signature carries an arrow only where the return type is fixed by the signature; arrow and sentence …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[TWO_TIER, HOME_ORDER, LEADING_IDENTITY, ONE_HOME, VARIANT_PAIR, ADMONITION_TITLE, STEER, ALIASING_BULLET, COVERAGE_BASES, GRAMMAR, VERIFIED, SELF_CONTAINED, TERMS_DEFINED, CLASS_SWEEP, BATTERY, LITERATE, BUILD_VERIFY, ONE_NOTATION, COORD_FREE, MODULE_MAP, RETURNS]

end # module JudgementDoc
