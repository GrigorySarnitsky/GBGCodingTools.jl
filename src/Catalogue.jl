"""
    Catalogue

What this package knows, as values rather than as files: the always-on checks, the instruments, the
rulebook, and the register of everything a generator writes (`docs/ARCHITECTURE.md` §3, §5.3, §6).

It is the third module of the order and holds DATA — a rule sits here beside the check that decides it,
and nothing here runs anything. What is in it today is the instrument table; the rules arrive with the
conversion (`IMPLEMENTATION.md` §6) and the agent roles with the instruments that launch them.

The table is the design's §3, and `test/architecture.jl` compares the two cell by cell: a row whose
purpose, intention, decider, fixer, timing or ending drifts from the document fails the suite, so the
document and the code cannot quietly disagree about what an instrument is for.
"""
module Catalogue

using ..Model

"""
    ALWAYS_ON

The checks every build and every test runs. Nobody starts one, none of them has a run, and what one finds
is fixed by whoever ran the build or the test as part of the work in hand.
"""
const ALWAYS_ON = Model.AlwaysOn[
    Model.AlwaysOn(
        id = :documentation_checks,
        purpose = "Documentation has the house structure and formatting and renders as written",
        intention = Model.Intention.DOCUMENTATION,
        fixer = Model.Fixer.ORDINARY_WORK,
        when = "Every docs build"),
    Model.AlwaysOn(
        id = :code_checks,
        purpose = "The code keeps its tested contracts and every accepted failing test passes",
        intention = Model.Intention.CODE,
        fixer = Model.Fixer.ORDINARY_WORK,
        when = "Every `Pkg.test()`"),
    Model.AlwaysOn(
        id = :wiring_check,
        purpose = "Every generated file or part of a file equals its generator's output",
        intention = Model.Intention.CODE,
        fixer = Model.Fixer.REGENERATE,
        when = "Every build and test"),
]

"""
    INSTRUMENTS

The review procedures the owner starts, in words or by slash command. Each carries the three values that
separate it from every other — what its defects are in, what decides that a finding is real, and who
fixes what it found — and the two sentences the table prints.

The roles each launches are empty here and are filled in the phase that builds that instrument; the leak
scan is not here at all, because the design marks its row future.
"""
const INSTRUMENTS = Model.Instrument[
    Model.Instrument(
        id = :documentation_review,
        purpose = "Documentation is true to the code, correct, consistent and self-contained; the change guard, the checks and a verifier agent check each fix",
        intention = Model.Intention.DOCUMENTATION,
        decider = Model.Decider.AGENT,
        fixer = Model.Fixer.DOCUMENTATION_FIXER,
        when = "Owner's request",
        ends = "Nothing is open, or the budget is spent",
        budget = Model.Budget(fix_passes = 4, agent_launches = 40)),
    Model.Instrument(
        id = :bug_hunt,
        purpose = "The code does what its documentation says",
        intention = Model.Intention.CODE,
        decider = Model.Decider.FAILING_TEST,
        fixer = Model.Fixer.CODE_FIXER,
        when = "Owner's request",
        ends = "Every candidate is confirmed or discarded, once",
        budget = Model.Budget(fix_passes = 0, agent_launches = 30)),
    Model.Instrument(
        id = :change_audit,
        purpose = "A code change is no wider than the defect and the owner's direction and still accepts input that worked before; it grades the fix and changes nothing",
        intention = Model.Intention.CODE,
        decider = Model.Decider.AGENT,
        fixer = Model.Fixer.CODE_FIXER,
        when = "After each approved code fix, and on request",
        ends = "One pass over the change",
        budget = Model.Budget(fix_passes = 0, agent_launches = 15)),
]

"""
    RULES

The rulebook: every rule as a value, beside the check that decides it and the examples that show the
check matches the statement. It is empty while the ninety-five rules of `policy/RULES.toml` are converted
in batches (`IMPLEMENTATION.md` §6); `test/conversion.jl` holds the count that may only fall.
"""
const RULES = Model.Rule[]

"""
    GENERATED

Every path, or part of a path, that a Julia function writes in a package, with the generator that writes
it. The wiring check regenerates each and compares only that part. It is empty until the generators
exist.
"""
const GENERATED = Model.Generated[]

"""
    axes(x) -> Tuple

The three values that separate one check or instrument from every other: what its defects are in, what
decides that a finding is real, and who fixes what it found. The argument is `x`, an
[`Model.AlwaysOn`](@ref) or an [`Model.Instrument`](@ref). Returns the three, in that order.
"""
axes(x) = (x.intention, x.decider, x.fixer)

"""
    rule(id) -> Union{Model.Rule,Nothing}

The rule with that id, or `nothing` where the rulebook holds none. The argument is `id`, the rule's
identifier. Returns the rule.
"""
rule(id::Symbol) = findfirst(r -> r.id === id, RULES) === nothing ? nothing : RULES[findfirst(r -> r.id === id, RULES)]

end # module Catalogue
