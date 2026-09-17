"""
    Rules.JudgementApi

The `RULE.API.*` rules that no program decides: those an agent judges, and those nothing checks at
all. Each carries its statement and the reason it exists, so a reader of the rulebook sees the same
text whether a program enforces it or a person does.

A rule with no check states why in `unchecked_reason` rather than pretending to one; a rule an agent
decides says which of the three admitted reasons a program cannot (`docs/ARCHITECTURE.md` §7).
"""
module JudgementApi

using ...Model

const POSITIONAL = Model.Rule(
    id = Symbol("RULE.API.POSITIONAL"),
    statement = "A result-affecting argument is positional; a performance hint or a builder cost/accuracy tunable is a keyword; exceptions are recorded.",
    why = "In an operation, every argument that affects the result is positional, defaults included; an argument that cannot change the result is a keyword. An exception is a ledger deviation with its reason.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES],
    check = Model.AgentCheck("A result-affecting argument is positional; a performance hint or a builder cost/accuracy tunable is a keyword; exceptions are recorded.", Model.WhyAgent.MEANING))

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[POSITIONAL]

end # module JudgementApi
