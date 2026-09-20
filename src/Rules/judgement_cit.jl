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
    statement = "An in-text citation is author–year. An author-prominent citation puts the year in parentheses. Up to three authors are named in full; four or more are written 'First et al.'. The author count is read from the package's reference list, the file RULE.CIT.FULL_INLINE's `references` names.",
    why = "Keep enough surnames to disambiguate two works that would otherwise collide. An eponymous method name takes no year unless the work is actually cited.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.AgentCheck("An in-text citation is author–year. An author-prominent citation puts the year in parentheses. Up to three authors are named in full; four or more are written 'First et al.'. The author count is read from the package's reference list, the file RULE.CIT.FULL_INLINE's `references` names.", Model.WhyAgent.MEANING),
    access = [Model.Access.OTHER_DOCUMENTS])

const NO_INACCESSIBLE = Model.Rule(
    id = Symbol("RULE.CIT.NO_INACCESSIBLE"),
    statement = "Never cite an inaccessible source on any user-facing surface: not a gitignored monograph, an accompanying thesis, an appendix or figure the reader cannot open, nor working notes. Whether a link answers is RULE.CIT.RESOLVES's question, not this rule's.",
    why = "A citation the reader cannot follow is the author telling themselves where they got it; the reader is left with an assertion and nowhere to check it.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.LITERATE],
    check = Model.AgentCheck("Is every source this text cites a published work a reader could obtain — one with its entry in the package's reference list — rather than a gitignored monograph, an accompanying thesis, an appendix or figure the site does not carry, or working notes? Judge from the citation and the reference list; whether a link answers is not asked here.", Model.WhyAgent.MEANING),
    access = [Model.Access.OTHER_DOCUMENTS])

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[STYLE, NO_INACCESSIBLE]

end # module JudgementCit
