# The design's §7; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.JudgementTest

The `RULE.TEST.*` rules that no program decides: those an agent judges, and those nothing checks at
all. Each carries its statement and the reason it exists, so a reader of the rulebook sees the same
text whether a program enforces it or a person does.

A rule with no check states why in `unchecked_reason` rather than pretending to one; a rule an agent
decides says which of the three admitted reasons a program cannot.
"""
module JudgementTest

using ...Model

const GATE_VS_SURVEY = Model.Rule(
    id = Symbol("RULE.TEST.GATE_VS_SURVEY"),
    statement = "Pkg.test() is a gate; the exhaustive suite is a survey; a specific oracle and every completeness guard go in the gate.",
    why = "A gate re-checks claims already known and must be green or the change does not ship; a survey searches for combinations nobody enumerated and is read, not passed. A universal oracle over a product goes in the survey, and anything that may legitimately be non-green goes there too, because a suppressed failure reads as a pass.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const ORACLE_INDEPENDENT = Model.Rule(
    id = Symbol("RULE.TEST.ORACLE_INDEPENDENT"),
    statement = "In a package that declares the oracle registry, every public value-returning operation is classified in it; relational-only coverage is a finding.",
    why = "The classes are analytic (a closed form derived independently of the package), independent (a direct computation written in the test), property (an invariant that pins the operation without computing it), relational (compared only against other package operations — legitimate as a second layer, never as the only one) and structural (returns metadata or storage). A new operation fails the registry until someone classifies it, which is the moment to notice it has no independent oracle.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session of a package that has declared this contract by calling `TestHarness.oracle_registry` from its suite, where that suite checks it; a package that has not declared it is not bound, and nothing checks it here")

const DEFINITION_OF_DONE = Model.Rule(
    id = Symbol("RULE.TEST.DEFINITION_OF_DONE"),
    statement = "A feature is done when its correctness tests, performance test, four guiding docs, remaining docs, benchmarks (built AND run) and examples (run) are each verified.",
    why = "'Should work' is not done: a step is done when its verification command exits 0 and the exit code was observed. Grep the docs for stale deferred, none-exist and future claims about whatever was just implemented.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const ALLOC_ZERO = Model.Rule(
    id = Symbol("RULE.TEST.ALLOC_ZERO"),
    statement = "In a package that declares the allocation audit, every in-place ! operator is allocation-free and in the audit; a deliberate materializer gets a bounded guard; where a bound covers another nondeterminism a configuration pins the true zero.",
    why = "The audit runs on the CPU, where a materialized temporary is visible; the completeness of its rows is derived from the export list, never remembered.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session of a package that has declared this contract by calling `TestHarness.allocation_completeness` from its suite, where that suite checks it; a package that has not declared it is not bound, and nothing checks it here")

# Proposed by GBGHomogeneousTurbulence and measured there first, on CUDA (2026-10-01): its draws were
# bitwise or within 2.4 epsilon, and a wrong seed was refused on every draw. Ruled by the owner 2026-10-02.
const SEED_PARITY = Model.Rule(
    id = Symbol("RULE.TEST.SEED_PARITY"),
    statement = "In a package that declares seed parity, one seed gives the same draws on every backend it runs: a draw the run uses as drawn is bitwise equal, one it sees through a transform agrees within a stated bound in machine epsilon, and a run from another seed is told apart on every draw.",
    why = "Runs on two machines are then comparable and a regression is reproducible on either. How a package meets it is its own: drawing on the host and moving the numbers, or one counter-based generator on both, which only the comparison shows to agree.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session of a package that has declared this contract by calling `TestHarness.seed_parity` from its GPU tests, where those tests check it; without a GPU they record a skip, never a pass, so it cannot run on CI; a package that has not declared it is not bound, and nothing checks it here")

# Asked for by GBGPeriodicFields, for GBGHomogeneousTurbulence too (the owner, 2026-10-03): the traffic
# audit counts what an operation reads and writes, and an operation at that count can still be slow, the
# excess being computation — HT's `weighted_inner` ran 40–60% over a plain read on its card.
const DEVICE_COST = Model.Rule(
    id = Symbol("RULE.TEST.DEVICE_COST"),
    statement = "In a package that declares the device-cost audit, each audited device operation is timed against the memory it must move, in a ratio to a copy measured in the same run, and holds at or below the ratio frozen for it.",
    why = "A count of reads and writes cannot see computation that costs time; only a timing against the least traffic can. The copy measured beside it keeps the ratio honest under the device's clocks and power limit; the fastest of many runs is the cost, and a frozen bound is refrozen in the commit that changes the operation, with the reason.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session of a package that has declared this contract by calling `TestHarness.device_cost` from its GPU tests, where those tests check it; without a device they record a skip, never a pass, so it cannot run on CI; a package that has not declared it is not bound, and nothing checks it here")

const PASS_AUDIT = Model.Rule(
    id = Symbol("RULE.TEST.PASS_AUDIT"),
    statement = "In a package that declares the traffic audit, every audited operation has a frozen per-array traffic row with a named holder for any gap.",
    why = "A raised count is a fusion regression unless a new holder justifies it; the frozen values are refrozen in the same commit as the change, with the reason.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session of a package that has declared this contract by calling `TestHarness.traffic_completeness` from its suite, where that suite checks it; a package that has not declared it is not bound, and nothing checks it here")

const METHOD_PARITY = Model.Rule(
    id = Symbol("RULE.TEST.METHOD_PARITY"),
    statement = "In a package that declares method parity, the public method set is frozen per generic and per module; any change moves a number.",
    why = "The per-module count is derived from ownership over the whole function surface, internals included, so a method defined under a qualified name cannot hide.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session of a package that has declared this contract by calling `TestHarness.method_parity` from its suite, where that suite checks it; a package that has not declared it is not bound, and nothing checks it here")

const MUTATION = Model.Rule(
    id = Symbol("RULE.TEST.MUTATION"),
    statement = "A symmetric fixture cannot see an asymmetric defect; a self-referential assertion cannot see a shared defect; a stated convention must be falsifiable by its fixture.",
    why = "Inject the defect and require the suite to catch it; a fixture that cannot reach the broken branch proves nothing about it.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const BOTH_DIRECTIONS = Model.Rule(
    id = Symbol("RULE.TEST.BOTH_DIRECTIONS"),
    statement = "Test the check in both directions; a check that cannot fail is not a check; a self-reported field is acceptable only when the missing case is the failing case.",
    why = "The flattering direction is the one nobody guards: a check that demotes sound answers is stopped being read, and a check nobody reads passes everything.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const MISSING_IS_FAILING = Model.Rule(
    id = Symbol("RULE.TEST.MISSING_IS_FAILING"),
    statement = "The missing case is the failing case: derived denominators, absence arms, zero count = dead.",
    why = "An empty witness directory, an empty ledger, an unparsable status — each fails; 'nothing to check' is not 'all clear'.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const EXAMPLES_RUN = Model.Rule(
    id = Symbol("RULE.TEST.EXAMPLES_RUN"),
    statement = "Shipped examples are executed after any public-surface change; nothing else runs them.",
    why = "An example is both a rendered page and a downloadable script; the docs build renders it without running it, and a call that no longer dispatches is found only by running it.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[GATE_VS_SURVEY, ORACLE_INDEPENDENT, DEFINITION_OF_DONE, ALLOC_ZERO, PASS_AUDIT, METHOD_PARITY, SEED_PARITY, DEVICE_COST, MUTATION, BOTH_DIRECTIONS, MISSING_IS_FAILING, EXAMPLES_RUN]

end # module JudgementTest
