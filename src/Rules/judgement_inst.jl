# The design's §7; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.JudgementInst

The `RULE.INST.*` rules that no program decides: those an agent judges, and those nothing checks at
all. Each carries its statement and the reason it exists, so a reader of the rulebook sees the same
text whether a program enforces it or a person does.

A rule with no check states why in `unchecked_reason` rather than pretending to one; a rule an agent
decides says which of the three admitted reasons a program cannot.
"""
module JudgementInst

using ...Model

const CONSENT = Model.Rule(
    id = Symbol("RULE.INST.CONSENT"),
    statement = "Unasked, run only Pkg.test(), and before every push the docs build, which the push hook runs; every instrument, survey, benchmark and panel runs only on the user's request, in words or by slash.",
    why = "The correct output when one would be informative is to name it and its cost and wait. This is a consent boundary, not licence to leave work unfinished: finish the code, run the gate, and report what remains unverified and why. \"Check the docs\" is such a request: it means run `/check-docs`.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const NO_TRUNCATION = Model.Rule(
    id = Symbol("RULE.INST.NO_TRUNCATION"),
    statement = "A scan output is never truncated (head, tail, a limit); count first, then read all.",
    why = "Adding a limit to keep the output readable is how a class gets half-swept and reported closed; a deterministic check that depends on who types it is not deterministic.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[CONSENT, NO_TRUNCATION]

end # module JudgementInst
