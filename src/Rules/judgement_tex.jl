# The design's §7; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.JudgementTex

The `RULE.TEX.*` rules that no program decides: those an agent judges, and those nothing checks at
all. Each carries its statement and the reason it exists, so a reader of the rulebook sees the same
text whether a program enforces it or a person does.

A rule with no check states why in `unchecked_reason` rather than pretending to one; a rule an agent
decides says which of the three admitted reasons a program cannot.
"""
module JudgementTex

using ...Model

const NO_HSCROLL = Model.Rule(
    id = Symbol("RULE.TEX.NO_HSCROLL"),
    statement = "No horizontal scroll: hand-wrap long signatures and display formulas with aligned/gathered.",
    why = "Neither a rendered code block nor display math auto-wraps; inline math reflows and is exempt. Never pack several equations on one line behind `\\quad`.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const CODE_SPAN_JULIA = Model.Rule(
    id = Symbol("RULE.TEX.CODE_SPAN_JULIA"),
    statement = "A backtick span holds only well-formed Julia, never code-looking math.",
    why = "A half-open interval, an inequality, a product, a lone `≤` or `·` glyph is LaTeX; the real operators `×`, `⋅` and `≈` backticked are code and stay.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const IMAGINARY = Model.Rule(
    id = Symbol("RULE.TEX.IMAGINARY"),
    statement = "The imaginary unit is upright \\mathrm{i}; i, j, k are indices.",
    why = "Never a bare italic `i`, never `\\imath` or `\\mathbb{i}`; the differential is likewise upright, `\\,\\mathrm{d}x`.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("The imaginary unit is upright \\mathrm{i}; i, j, k are indices.", Model.WhyAgent.DERIVATION))

const GREEK_AB = Model.Rule(
    id = Symbol("RULE.TEX.GREEK_AB"),
    statement = "The accumulation scalars are Unicode α/β everywhere; the two named ASCII holdouts stay.",
    why = "A hand-written operation spelling them `alpha`/`beta` is drift; a flag naming the α/β variant and an external window-shape `beta` in an English-register block are the recorded exceptions.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[NO_HSCROLL, CODE_SPAN_JULIA, IMAGINARY, GREEK_AB]

end # module JudgementTex
