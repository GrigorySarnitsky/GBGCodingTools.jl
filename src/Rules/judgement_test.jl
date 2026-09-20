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
    statement = "Every public value-returning operation is classified in the oracle registry; relational-only coverage is a finding.",
    why = "The classes are analytic (a closed form derived independently of the package), independent (a direct computation written in the test), property (an invariant that pins the operation without computing it), relational (compared only against other package operations — legitimate as a second layer, never as the only one) and structural (returns metadata or storage). A new operation fails the registry until someone classifies it, which is the moment to notice it has no independent oracle.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session until a package wires the harness contract `TestHarness.oracle_registry`, which no wired package calls today; checked by nothing until then")

const DEFINITION_OF_DONE = Model.Rule(
    id = Symbol("RULE.TEST.DEFINITION_OF_DONE"),
    statement = "A feature is done when its correctness tests, performance test, four guiding docs, remaining docs, benchmarks (built AND run) and examples (run) are each verified.",
    why = "'Should work' is not done: a step is done when its verification command exits 0 and the exit code was observed. Grep the docs for stale deferred, none-exist and future claims about whatever was just implemented.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const ALLOC_ZERO = Model.Rule(
    id = Symbol("RULE.TEST.ALLOC_ZERO"),
    statement = "Every in-place ! operator is allocation-free and in the audit; a deliberate materializer gets a bounded guard; where a bound covers another nondeterminism a configuration pins the true zero.",
    why = "The audit runs on the CPU, where a materialized temporary is visible; the completeness of its rows is derived from the export list, never remembered.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session until a package wires the harness contract `TestHarness.allocation_completeness`, which no wired package calls today; checked by nothing until then")

const PASS_AUDIT = Model.Rule(
    id = Symbol("RULE.TEST.PASS_AUDIT"),
    statement = "Every audited operation has a frozen per-array traffic row with a named holder for any gap.",
    why = "A raised count is a fusion regression unless a new holder justifies it; the frozen values are refrozen in the same commit as the change, with the reason.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session until a package wires the harness contract `TestHarness.traffic_completeness`, which no wired package calls today; checked by nothing until then")

const METHOD_PARITY = Model.Rule(
    id = Symbol("RULE.TEST.METHOD_PARITY"),
    statement = "The public method set is frozen per generic and per module; any change moves a number.",
    why = "The per-module count is derived from ownership over the whole function surface, internals included, so a method defined under a qualified name cannot hide.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.TESTS, Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session until a package wires the harness contract `TestHarness.method_parity`, which no wired package calls today; checked by nothing until then")

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
const RULES = Model.Rule[GATE_VS_SURVEY, ORACLE_INDEPENDENT, DEFINITION_OF_DONE, ALLOC_ZERO, PASS_AUDIT, METHOD_PARITY, MUTATION, BOTH_DIRECTIONS, MISSING_IS_FAILING, EXAMPLES_RUN]

end # module JudgementTest
