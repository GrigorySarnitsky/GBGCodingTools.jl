# The design's §7; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.JudgementCit

The `RULE.CIT.*` rules that no program decides: those an agent judges, and those nothing checks at
all. Each carries its statement and the reason it exists, so a reader of the rulebook sees the same
text whether a program enforces it or a person does.

A rule with no check states why in `unchecked_reason` rather than pretending to one; a rule an agent
decides says which of the three admitted reasons a program cannot.
"""
module JudgementCit

using ...Model

const STYLE = Model.Rule(
    id = Symbol("RULE.CIT.STYLE"),
    statement = "In-text author–year: author-prominent takes a parenthesized year; up to 3 authors are named, 'First et al.' for four or more.",
    why = "Keep enough surnames to disambiguate two works that would otherwise collide. An eponymous method name takes no year unless the work is actually cited.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("In-text author–year: author-prominent takes a parenthesized year; up to 3 authors are named, 'First et al.' for four or more.", Model.WhyAgent.MEANING))

const NO_INACCESSIBLE = Model.Rule(
    id = Symbol("RULE.CIT.NO_INACCESSIBLE"),
    statement = "Never cite an inaccessible source on any user-facing surface: not a gitignored monograph, an accompanying thesis, an appendix or figure the reader cannot open, nor working notes.",
    why = "A citation the reader cannot follow is the author telling themselves where they got it; the reader is left with an assertion and nowhere to check it.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.LITERATE],
    check = Model.AgentCheck("Does every source this text cites exist somewhere the reader can open it? A gitignored monograph, an accompanying thesis, an appendix, a figure or a set of working notes is not such a place.", Model.WhyAgent.MEANING))

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[STYLE, NO_INACCESSIBLE]

end # module JudgementCit
