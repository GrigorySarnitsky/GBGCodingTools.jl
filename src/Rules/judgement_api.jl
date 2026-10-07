# The design's §7; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.JudgementApi

The `RULE.API.*` rules that no program decides: those an agent judges, and those nothing checks at
all. Each carries its statement and the reason it exists, so a reader of the rulebook sees the same
text whether a program enforces it or a person does.

A rule with no check states why in `unchecked_reason` rather than pretending to one; a rule an agent
decides says which of the three admitted reasons a program cannot.
"""
module JudgementApi

using ...Model

# Reworded 2026-10-06 on GBGStreamingStatistics' request and the owner's ruling. Until then it read "an
# argument that can change the result is positional" — GBGPeriodicFields' own convention, written as fleet
# law — which no source states and which Julia's Base, its only style guide with a criterion (SciML) and
# every other language's guideline contradict; the research is filed with the owner.
const POSITIONAL = Model.Rule(
    id = Symbol("RULE.API.POSITIONAL"),
    statement = "In an operation, the required inputs and any argument whose type selects the method are positional, the latter passed as an instance; every other argument with a default — an option, a tunable, a hint — is a keyword, whether or not it changes the result. An argument whose type selects among the operation's methods is positional whether or not it has a default; a value that parametrises a single method is a keyword however it is typed. An operation that extends or mirrors a function of Base, a standard library or another package follows that function's arguments instead, and names it where the operation is documented, so a reader can compare the two signatures. Any other exception is a `Switch` on this rule in the package's own config, with its reason.",
    why = "Methods are dispatched on positional arguments alone, so what selects the method must be one, and as an instance rather than a type so a later option extends it without breaking a call. A keyword names its value at the call site and may be given in any order or left out; an optional positional can be neither skipped nor named, and each default adds a method to disambiguate. An argument that selects the method stays positional when it is optional, since a keyword dispatches only through a second, internal call: Julia's `round(x, r::RoundingMode = RoundNearest; digits)` and `lu!(A, pivot = RowMaximum(); check)` do so (GBGPeriodicFields' request, 2026-10-07). This is Julia's own practice — `sort(v; by, rev)`, `round(x; digits)`, `solve(prob, Tsit5(); abstol)` — and no guideline in any language makes an argument positional for changing the result (researched 2026-10-06). A method that extends `Statistics.var` must take `corrected` as a keyword or it is no extension, and `mul!(C, A, B, α, β)`'s weights are positional wherever a package mirrors it: the mirrored function decides, and naming it lets a reader check the claim (GBGPeriodicFields' request, 2026-10-07).",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES],
    check = Model.AgentCheck("In an operation, the required inputs and any argument whose type selects the method are positional, the latter passed as an instance; every other argument with a default — an option, a tunable, a hint — is a keyword, whether or not it changes the result. An argument whose type selects among the operation's methods is positional whether or not it has a default; a value that parametrises a single method is a keyword however it is typed. An operation that extends or mirrors a function of Base, a standard library or another package follows that function's arguments instead, and names it where the operation is documented, so a reader can compare the two signatures. Any other exception is a `Switch` on this rule in the package's own config, with its reason.", Model.WhyAgent.MEANING),
    access = [Model.Access.SOURCE, Model.Access.OTHER_DOCUMENTS])

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[POSITIONAL]

end # module JudgementApi
