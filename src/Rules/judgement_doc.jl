# The design's §7; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.JudgementDoc

The `RULE.DOC.*` rules that no program decides: those an agent judges, and those nothing checks at
all. Each carries its statement and the reason it exists, so a reader of the rulebook sees the same
text whether a program enforces it or a person does.

A rule with no check states why in `unchecked_reason` rather than pretending to one; a rule an agent
decides says which of the three admitted reasons a program cannot.

The statements were reworded on 2026-09-19 after three blind taggers, given only the text, were asked
what deciding each rule requires: the wording that split them was rewritten until it did not, and a
rule that named a document the package had no way to declare — its notation page, its formalization
document — now names a parameter the package sets.
"""
module JudgementDoc

using ...Model

const TWO_TIER = Model.Rule(
    id = Symbol("RULE.DOC.TWO_TIER"),
    statement = "A module docstring is a map: one linked one-line entry per operation family, and no formula. A function docstring is a home: the one place where that operation's identity, arguments and defining formula are stated in full.",
    why = "The map states what the module is, its scope and place in the architecture, and its invariants — then a linked one-liner per operation family, and no formulas; every formula lives in the operation's …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("A module docstring is a map: one linked one-line entry per operation family, and no formula. A function docstring is a home: the one place where that operation's identity, arguments and defining formula are stated in full.", Model.WhyAgent.READING_ORDER),
    access = [Model.Access.SIBLINGS])

const HOME_ORDER = Model.Rule(
    id = Symbol("RULE.DOC.HOME_ORDER"),
    statement = "A function docstring is ordered: identity, when-to-use, arguments, one formula, citation, links, caveats, then `# References`, then `# Fields` last. Implementation internals and design rationale are excluded; so is any term that neither the surrounding sentence nor the package's notation page — the file RULE.DOC.ONE_NOTATION's `notation_page` names — defines.",
    why = "In full: (1) a plain one-sentence identity in the user's terms; (2) when to use it, versus the alternatives; (3) each argument (positional and keyword) and its effect; (4) one formula if a clean one …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps",
    access = [Model.Access.OTHER_DOCUMENTS])

"How a docstring's first sentence leads: the physical meaning, or the estimand."
const LEADING_IDENTITY_LEADS = Model.Parameter(:leading_identity, "physical meaning")

const LEADING_IDENTITY = Model.Rule(
    id = Symbol("RULE.DOC.LEADING_IDENTITY"),
    statement = "Item (1) of a docstring is one plain sentence saying what the operation computes — the physical meaning first, or the estimand first, as this rule's `leading_identity` sets for the package. Whether that sentence is true of the code is RULE.DOC.VERIFIED's question, not this rule's.",
    why = "For this package the identity leads with what `leading_identity` names: an operation computed in a derived representation still states what it does to the real object first — with the explicit …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("Item (1) of a docstring is one plain sentence saying what the operation computes — the physical meaning first, or the estimand first, as this rule's `leading_identity` sets for the package. Whether that sentence is true of the code is RULE.DOC.VERIFIED's question, not this rule's.", Model.WhyAgent.MEANING),
    parameters = Model.Parameter[LEADING_IDENTITY_LEADS],
    access = [Model.Access.OTHER_DOCUMENTS],
    needs_discipline = true)

const ONE_HOME = Model.Rule(
    id = Symbol("RULE.DOC.ONE_HOME"),
    statement = "One concept, one home: one docstring per operation on the bare binding; the ! form owns the formula and is listed first; every other variant is a thin wrapper that @ref-links the home and carries no second formula.",
    why = "Per-scheme or per-representation specifics live in the scheme's or the representation's own docstring, linked. Across an `f`/`f!` pair the in-place `!` form is the home — it owns the formula and the …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps",
    access = [Model.Access.SIBLINGS])

const VARIANT_PAIR = Model.Rule(
    id = Symbol("RULE.DOC.VARIANT_PAIR"),
    statement = "Across an f/f! pair or a getter/setter pair, the defining mathematics appears once, in the docstring of the member that is the home under RULE.DOC.ONE_HOME; the other member carries no display formula. The pair is one unit for this rule.",
    why = "Typed twice, the math drifts — one member writing a partial one way and its twin another — and a within-string check cannot see it; a lane that groups each operation's generics and diffs them can.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps",
    access = [Model.Access.OTHER_DOCUMENTS])

"Which `!!!` blocks need a custom title: every one, or only a load-bearing one."
const ADMONITION_TITLES = Model.Parameter(:admonition_titles, "always")

const ADMONITION_TITLE = Model.Rule(
    id = Symbol("RULE.DOC.ADMONITION_TITLE"),
    statement = "Every !!! block carries a custom descriptive title. Where this rule's `admonition_titles` is `load-bearing only`, a block need carry one only when text elsewhere relies on the block's content; a general aside may keep its default title.",
    why = "For this package the rule is what `admonition_titles` says: either every `!!!` block carries a custom descriptive title, or a block carrying one load-bearing claim does while a general aside may stay a …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps",
    parameters = Model.Parameter[ADMONITION_TITLES],
    access = [Model.Access.OTHER_DOCUMENTS, Model.Access.SIBLINGS])

const STEER = Model.Rule(
    id = Symbol("RULE.DOC.STEER"),
    statement = "Every ! form with an allocating sibling carries the in-place steer sentence, verbatim from the template this rule's `why` gives, with `destination` replaced by the ! form's own destination argument and `f` by the allocating sibling's name.",
    why = "The sentence is a template, not a link: `destination` is replaced by the argument the signature actually has and `f` by the allocating sibling's own name, written as an `@ref` link, so the link resolves. The template: Use this in-place form when `destination` is already allocated; the allocating `f` returns a fresh result instead.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps",
    access = [Model.Access.SIBLINGS, Model.Access.OTHER_DOCUMENTS])

const ALIASING_BULLET = Model.Rule(
    id = Symbol("RULE.DOC.ALIASING_BULLET"),
    statement = "An aliasing statement specific to one operation — one that names that operation's own arguments — lives in the bullet for its destination argument. The package-wide aliasing guarantee lives once, in the module docstring, and is not repeated per operation.",
    why = "The package-wide guarantee lives in the module docstring and is not repeated per operation; an operation states it for itself only when it has an operation-specific reason, or when its contract is …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("An aliasing statement specific to one operation — one that names that operation's own arguments — lives in the bullet for its destination argument. The package-wide aliasing guarantee lives once, in the module docstring, and is not repeated per operation.", Model.WhyAgent.MEANING),
    access = [Model.Access.SIBLINGS])

const COVERAGE_BASES = Model.Rule(
    id = Symbol("RULE.DOC.COVERAGE_BASES"),
    statement = "An operation that reduces a field over a measure documents every base the code supports for it — the reduction over a grid and the same reduction over a point set are both stated where the operation is documented.",
    why = "A measure reduction over a grid and the same reduction over a point set are both stated where the operation is documented.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("An operation that reduces a field over a measure documents every base the code supports for it — the reduction over a grid and the same reduction over a point set are both stated where the operation is documented.", Model.WhyAgent.MEANING),
    access = [Model.Access.SOURCE],
    needs_discipline = true)

const GRAMMAR = Model.Rule(
    id = Symbol("RULE.DOC.GRAMMAR"),
    statement = "Every sentence has a subject and a verb; concise means few words, not missing verbs.",
    why = "Concise means few words, not missing verbs — compact prose that still reads as sentences aloud.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("Every sentence has a subject and a verb; concise means few words, not missing verbs.", Model.WhyAgent.MEANING),
    access = [Model.Access.NOTHING])

const VERIFIED = Model.Rule(
    id = Symbol("RULE.DOC.VERIFIED"),
    statement = "Every formula, normalization, adjoint relation and cross-scheme equivalence stated in the documentation is true of what the code computes, established by expanding the statement against the code, never taken on the docstring's word.",
    why = "A plausible 'X is just Y' is a false claim until the expansion matches. Run this as a positive verification — enumerate every formula, constant, relation and quantifier and verify each — not as a …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("Every formula, normalization, adjoint relation and cross-scheme equivalence stated in the documentation is true of what the code computes, established by expanding the statement against the code, never taken on the docstring's word.", Model.WhyAgent.MEANING),
    access = [Model.Access.SOURCE],
    needs_discipline = true)

const SELF_CONTAINED = Model.Rule(
    id = Symbol("RULE.DOC.SELF_CONTAINED"),
    statement = "A rationale doc reads top to bottom without another file: every symbol is bound in plain language at first use.",
    why = "Later uses may be bare; universally standard mathematics may stand unglossed. A decision-log entry browsed on its own meets the same bar.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("A rationale doc reads top to bottom without another file: every symbol is bound in plain language at first use.", Model.WhyAgent.READING_ORDER),
    access = [Model.Access.NOTHING])

const TERMS_DEFINED = Model.Rule(
    id = Symbol("RULE.DOC.TERMS_DEFINED"),
    statement = "A term of art is defined in a clause, or @ref-linked to its definition, before its first use on the same page. The test is a cold read of that page alone.",
    why = "A docstring can bind every symbol and still be unreadable to someone who has not read the module, because its terms of art are nouns, not symbols; parse it with the module's context withheld, and a …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("A term of art is defined in a clause, or @ref-linked to its definition, before its first use on the same page. The test is a cold read of that page alone.", Model.WhyAgent.MEANING),
    access = [Model.Access.NOTHING])

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

# Two rules where there was one. The three clauses below are properties of the `.jl` file; what the page
# made of them is invisible there — `a_b and c_d` reads fine in the source and renders as italic — and is
# LITERATE_RENDERED's, read on the built page.
const LITERATE = Model.Rule(
    id = Symbol("RULE.DOC.LITERATE"),
    statement = "In the source file of a Literate example, every full-line # comment is prose that will render, any mathematics in such a comment is LaTeX, and a comment inside control flow is written ## so that it does not render. The rule is judged on the source file; what the page made of it is RULE.DOC.LITERATE_RENDERED's question.",
    why = "A full-line comment inside a control-flow block splits the code fence, so reserve full-line `# ` for narrative prose at statement boundaries. An underscored identifier in that prose is backticked, …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.LITERATE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps",
    access = [Model.Access.NOTHING])

const LITERATE_RENDERED = Model.Rule(
    id = Symbol("RULE.DOC.LITERATE_RENDERED"),
    statement = "The built page of a Literate example shows its prose as prose: no stray `#`, no italics or code block that a comment's underscores or indentation produced, no mathematics split or broken across comment lines, and no comment landing inside a code fence. The rule is judged on the built page.",
    why = "What a `#` comment becomes is decided by Literate and then by Markdown, and neither is visible in the source: `a_b and c_d` renders as italic, a comment beginning `# 1.` becomes a list item, four spaces of indentation become a code block, and mathematics split across two comment lines is not mathematics. The habits in the source are RULE.DOC.LITERATE's; this rule reads what they produced.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.LITERATE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps",
    access = [Model.Access.RENDERED])

const BUILD_VERIFY = Model.Rule(
    id = Symbol("RULE.DOC.BUILD_VERIFY"),
    statement = "A doc edit is verified by the full docs build exiting 0, never by a diff, a lint subset or a log grep.",
    why = "A lint run standalone cannot see a dangling reference, and grepping a log for error text passes a build that died at load. After editing a Literate example, regenerate it and read the output.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "the rulebook does not check it: harness:makedocs enforces it inside a package's own test suite")

"The page where the package records what each symbol denotes."
const NOTATION_PAGE = Model.Parameter(:notation_page, "docs/src/notation.md")

const ONE_NOTATION = Model.Rule(
    id = Symbol("RULE.DOC.ONE_NOTATION"),
    statement = "One symbol denotes one concept and one concept is denoted by one symbol, as the package's notation page records — the file this rule's `notation_page` names; a local use that conflicts with the notation page is the one that changes.",
    why = "Before introducing a symbol, check it is not a synonym for one already in use, and check the section for the glyph and confirm it is free. When an edit introduces a symbol, retire the old one.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("One symbol denotes one concept and one concept is denoted by one symbol, as the package's notation page records — the file this rule's `notation_page` names; a local use that conflicts with the notation page is the one that changes.", Model.WhyAgent.DERIVATION),
    parameters = Model.Parameter[NOTATION_PAGE],
    access = [Model.Access.OTHER_DOCUMENTS, Model.Access.SIBLINGS],
    needs_discipline = true)

"The one document where matrix and flattening machinery may appear; empty where the package has none."
const FORMALIZATION = Model.Parameter(:formalization, "")

const COORD_FREE = Model.Rule(
    id = Symbol("RULE.DOC.COORD_FREE"),
    statement = "Maps and pairings are stated intrinsically, without flattening a structured space to a bare vector; matrix and flattening machinery appears only in the package's formalization document — the file this rule's `formalization` names — and nowhere when none is named.",
    why = "Component notation for a genuine fiber algebra is fine; the rule targets flattening a structured space to a bare vector. Where a basis form is needed to mirror the code, state the basis and the …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("Maps and pairings are stated intrinsically, without flattening a structured space to a bare vector; matrix and flattening machinery appears only in the package's formalization document — the file this rule's `formalization` names — and nowhere when none is named.", Model.WhyAgent.MEANING),
    parameters = Model.Parameter[FORMALIZATION],
    access = [Model.Access.OTHER_DOCUMENTS],
    needs_discipline = true)

const MODULE_MAP = Model.Rule(
    id = Symbol("RULE.DOC.MODULE_MAP"),
    statement = "A module docstring lists one linked one-liner per operation family and no formula.",
    why = "Its order is identity, then the contents list, then an optional trailing remark.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps",
    access = [Model.Access.SIBLINGS])

const RETURNS = Model.Rule(
    id = Symbol("RULE.DOC.RETURNS"),
    statement = "A type docstring leads with its constructor. A function docstring whose identity sentence does not name the result states it with a '-> Type' arrow or a 'Returns x.' sentence. Whether the stated result is what the code returns is RULE.DOC.VERIFIED's question, not this rule's.",
    why = "A mutator whose signature carries no arrow says what it returns in a sentence before any caveat; a signature carries an arrow only where the return type is fixed by the signature; arrow and sentence …",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps",
    access = [Model.Access.NOTHING])

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[TWO_TIER, HOME_ORDER, LEADING_IDENTITY, ONE_HOME, VARIANT_PAIR, ADMONITION_TITLE, STEER, ALIASING_BULLET, COVERAGE_BASES, GRAMMAR, VERIFIED, SELF_CONTAINED, TERMS_DEFINED, CLASS_SWEEP, BATTERY, LITERATE, LITERATE_RENDERED, BUILD_VERIFY, ONE_NOTATION, COORD_FREE, MODULE_MAP, RETURNS]

end # module JudgementDoc
