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
# every other language's guideline contradict; the research is filed with the owner. Settled 2026-10-09
# (the owner: one coherent policy, which does not move and breaks nothing): the required argument is the
# package's, the argument with a default is a keyword unless it selects the method.
const POSITIONAL = Model.Rule(
    id = Symbol("RULE.API.POSITIONAL"),
    statement = "In an operation, a required argument is positional or keyword as the package chooses, operation by operation. An argument with a default — an option, a tunable, a hint, a value that parametrises a single method however it is typed — is a keyword, whether or not it changes the result, unless its type selects among the operation's methods: then it is positional, passed as an instance. An operation that extends or mirrors a function of Base, a standard library or another package follows that function's arguments instead, and names it where the operation is documented, so a reader can compare the two signatures. Any other exception is a `Switch` on this rule in the package's own config, with its reason.",
    why = "A keyword names its value at the call site and may be given in any order or left out; an optional positional can be neither skipped nor named, and each default adds a method to disambiguate. So an argument with a default is a keyword, as in `sort(v; by, rev)`, `round(x; digits)` and `solve(prob, Tsit5(); abstol)`, and no guideline in any language makes one positional for changing the result (researched 2026-10-06). The one exception is an optional argument whose type selects the method: Julia picks a method by its positional arguments, and a keyword reaches dispatch only through a second, internal call, so such an argument stays positional, as an instance so a later option extends it without breaking a call — `round(x, r::RoundingMode = RoundNearest; digits)`, `lu!(A, pivot = RowMaximum(); check)`. On a REQUIRED argument the sources part — Julia's manual gives names for an interface with many arguments, SciML's guide prefers positional and warns against abusing required keywords — and the fleet does both: GBGPeriodicFields passes required arguments positionally, the other three name required parameters, selectors among them (`dealiasing::DealiasingStrategy`, `domain::Domain`). A rule deciding it would report one package or three, so the package decides, operation by operation (the owner, 2026-10-09). A method that extends `Statistics.var` must take `corrected` as a keyword or it is no extension, and `mul!(C, A, B, α, β)`'s weights are positional wherever a package mirrors it: the mirrored function decides, and naming it lets a reader check the claim.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.PAGES],
    check = Model.AgentCheck("In an operation, a required argument is positional or keyword as the package chooses, operation by operation. An argument with a default — an option, a tunable, a hint, a value that parametrises a single method however it is typed — is a keyword, whether or not it changes the result, unless its type selects among the operation's methods: then it is positional, passed as an instance. An operation that extends or mirrors a function of Base, a standard library or another package follows that function's arguments instead, and names it where the operation is documented, so a reader can compare the two signatures. Any other exception is a `Switch` on this rule in the package's own config, with its reason.", Model.WhyAgent.MEANING),
    access = [Model.Access.SOURCE, Model.Access.OTHER_DOCUMENTS])

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[POSITIONAL]

end # module JudgementApi
