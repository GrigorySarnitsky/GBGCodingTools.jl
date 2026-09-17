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

include("Rules/rendering.jl")     # one file per batch of the conversion
include("Rules/docstrings.jl")
include("Rules/arguments.jl")
include("Rules/latex.jl")

"""
    RULES

The rulebook: every rule as a value, beside the check that decides it and the examples that show the
check matches the statement. The ninety-five rules of `policy/RULES.toml` are converted in batches
(`IMPLEMENTATION.md` §6), one file of `src/Rules/` per batch; `test/conversion.jl` holds the count still
outstanding, which may only fall.
"""
const RULES = Model.Rule[Rendering.RULES..., Docstrings.RULES..., Arguments.RULES..., Latex.RULES...]

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

"""
    ALWAYS_ON_RULES

The rules no package may switch off: the ones catching text that renders wrongly and the ones holding the
shape of a docstring (`docs/ARCHITECTURE.md` §9).

It is EMPTY, and deliberately. The design's own ruling is that the set ships switchable until two packages
have run those rules over their own prose and their counts are known: a rule nobody may escape, settled
before anyone has read what it reports, is how a package ends up with a red build and no way out. Filling
this list is a MAJOR release, and after it the only escape is changing the rule for every package.
"""
const ALWAYS_ON_RULES = Symbol[]

"""
    known_ids() -> Set{Symbol}

Every id a package's config may name in a switch: each rule of the rulebook, each agent role of each
instrument, and each instrument. Returns the set.
"""
function known_ids()
    ids = Set{Symbol}(r.id for r in RULES)
    for i in INSTRUMENTS
        push!(ids, i.id)
        for r in i.roles; push!(ids, r.id); end
    end
    for a in ALWAYS_ON; push!(ids, a.id); end
    return ids
end

"""
    doc(x) -> String

The docstring of a rule, an agent role, an instrument or an always-on check, written from the value
itself. A rule's prose is written once, in the value, and the docstring a reader sees on the package's own
site is derived from it — so the two cannot disagree, and a rule reworded in one place is reworded in
both.

The argument is `x`, the value to describe. Returns the docstring text, which the source attaches with
`@doc doc(x) x`.
"""
function doc(r::Model.Rule)
    io = IOBuffer()
    println(io, "    ", r.id, "\n")
    println(io, r.statement, "\n")
    isempty(r.why) || println(io, r.why, "\n")
    println(io, "- Intention: ", lowercase(replace(string(r.intention), "_" => " ")), ".")
    println(io, "- Decided by: ", check_words(r.check), ".")
    isempty(r.filesets) || println(io, "- Runs over: ", join(lowercase.(string.(r.filesets)), ", "), ".")
    r.check === nothing && println(io, "- Unchecked because: ", r.unchecked_reason)
    isempty(r.examples) || println(io, "- Shown by ", length(r.examples), " example(s), over ",
                                  length(unique(e.clause for e in r.examples)), " clause(s).")
    return String(take!(io))
end

function doc(role::Model.AgentRole)
    io = IOBuffer()
    println(io, "    ", role.id, "\n")
    println(io, role.description, "\n")
    println(io, "- Launched by: ", role.instrument, ".")
    println(io, "- Reads: ", isempty(role.reads) ? "nothing named" : join(lowercase.(string.(role.reads)), ", "),
            role.site ? ", as the built site" : "", role.kept_from_code ? "; the code is kept from it" : "", ".")
    println(io, "- Checks: ", isempty(role.rules) ? "no rule by name — an open reader, looking for what no rule names yet" :
                              join(string.(role.rules), ", "), ".")
    println(io, "- Strength: ", lowercase(string(role.strength)), "; at most ", role.cap, " distinct defects.")
    return String(take!(io))
end

function doc(i::Model.Instrument)
    io = IOBuffer()
    println(io, "    ", i.id, "\n")
    println(io, i.purpose, "\n")
    println(io, "- Intention: ", lowercase(replace(string(i.intention), "_" => " ")), ".")
    println(io, "- Decided by: ", lowercase(replace(string(i.decider), "_" => " ")), ".")
    println(io, "- Fixed by: ", lowercase(replace(string(i.fixer), "_" => " ")), ".")
    println(io, "- Runs: ", i.when, ".")
    println(io, "- A run ends when: ", i.ends, ".")
    println(io, "- One run may launch ", i.budget.agent_launches, " agent(s) and make ",
            i.budget.fix_passes, " fix pass(es).")
    return String(take!(io))
end

function doc(a::Model.AlwaysOn)
    io = IOBuffer()
    println(io, "    ", a.id, "\n")
    println(io, a.purpose, "\n")
    println(io, "- Intention: ", lowercase(replace(string(a.intention), "_" => " ")), ".")
    println(io, "- Fixed by: ", lowercase(replace(string(a.fixer), "_" => " ")), ".")
    println(io, "- Runs: ", a.when, ". It has no runs of its own and nobody starts it.")
    return String(take!(io))
end

check_words(c::Model.ProgramCheck) = "a program" * (c.network ? ", which reaches the network and runs only under `gbg check --network`" : "")
check_words(c::Model.AgentCheck) = "an agent, because this needs " * lowercase(replace(string(c.why), "_" => " "))
check_words(::Nothing) = "nothing yet"

end # module Catalogue
