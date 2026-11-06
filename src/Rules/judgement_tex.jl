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
    unchecked_reason = "judged by a reader; no program can decide it",
    access = [Model.Access.RENDERED])

const CODE_SPAN_JULIA = Model.Rule(
    id = Symbol("RULE.TEX.CODE_SPAN_JULIA"),
    statement = "A code span holds literal code or input in some language — Julia, shell, TOML, a path, LaTeX source — and never mathematics, which is written as math.",
    why = "Code formatting marks text to be typed or read as code in any language: a shell flag, a path, an environment variable, a TOML key, LaTeX source on a notation page. A half-open interval, an inequality, a product, a lone `≤` or `·` glyph is mathematics and is set as such; the real operators `×`, `⋅` and `≈` backticked are code and stay. Reworded on GBGPeriodicFields' request [ruled 2026-09-26]: the old wording, 'only well-formed Julia', made every shell command a finding.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "judged by a reader; no program can decide it",
    access = [Model.Access.NOTHING])

const IMAGINARY = Model.Rule(
    id = Symbol("RULE.TEX.IMAGINARY"),
    statement = "The imaginary unit is upright \\mathrm{i}; i, j, k are indices.",
    why = "Never a bare italic `i`, never `\\imath` or `\\mathbb{i}`; the differential is likewise upright, `\\,\\mathrm{d}x`.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("The imaginary unit is upright \\mathrm{i}; i, j, k are indices.", Model.WhyAgent.DERIVATION),
    access = [Model.Access.NOTHING])

const UPRIGHT_LABEL_STATEMENT = "A subscript or superscript that stands for a quantity, a variable or a running index is italic; one that stands for a word, a name or a label is upright: `\\kappa_{\\mathrm{p}}` for the peak wavenumber, `C_{\\mathrm{K}}` for the Kolmogorov constant, `u^{\\mathrm{ref}}` for a reference velocity, but `u_i` for a component and `C_p` at constant pressure. Which it is depends on what the letter means where it stands, so one letter may be an italic index in one formula and an upright label in another: `u_i` for a component, `L_{\\mathrm{i}}` for ice."

const UPRIGHT_LABEL = Model.Rule(
    id = Symbol("RULE.TEX.UPRIGHT_LABEL"),
    statement = UPRIGHT_LABEL_STATEMENT,
    why = "ISO 80000-1, which replaced ISO 31-0, prints a subscript that represents a physical quantity or a mathematical variable, such as a running number, in italic, and every other subscript upright; a superscript follows the same rule. IEC 60050, the IUPAC Green Book and NIST SP 811 (§10.2.1) agree. An italic label misreads: `\\kappa_p` reads as κ at an index p, not as the peak wavenumber. `RULE.TEX.IMAGINARY` applies the same principle to the imaginary unit and the differential. A reader decides it, because a letter's meaning is not in the TeX; it is read where the symbol is defined. Asked by GBGHomogeneousTurbulence [ruled 2026-11-06].",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck(UPRIGHT_LABEL_STATEMENT, Model.WhyAgent.MEANING),
    access = [Model.Access.OTHER_DOCUMENTS])

const GREEK_AB = Model.Rule(
    id = Symbol("RULE.TEX.GREEK_AB"),
    statement = "The accumulation scalars are written as Unicode α and β wherever they appear. Two ASCII spellings stay, both named in this rule's `why`: a flag whose name carries the α/β variant, and an external window-shape parameter `beta` inside an English-register block.",
    why = "A hand-written operation spelling them `alpha`/`beta` is drift; a flag naming the α/β variant and an external window-shape `beta` in an English-register block are the recorded exceptions.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    unchecked_reason = "judged by a reader; no program can decide it",
    access = [Model.Access.OTHER_DOCUMENTS])

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[NO_HSCROLL, CODE_SPAN_JULIA, IMAGINARY, UPRIGHT_LABEL, GREEK_AB]

end # module JudgementTex
