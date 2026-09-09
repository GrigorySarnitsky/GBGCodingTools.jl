<!-- gbg:managed policy/testing-protocol.md vdev — rewritten by `gbg sync`; do not edit -->
# The testing protocol (`RULE.TEST.*`)

### RULE.TEST.GATE_VS_SURVEY
`Pkg.test()` is a gate and the exhaustive suite is a survey; a specific oracle and every completeness
guard go in the gate. A gate re-checks claims already known and must be green or the change does not
ship; a survey searches for combinations nobody enumerated and is read, not passed. A universal oracle
over a product goes in the survey, and anything that may legitimately be non-green goes there too,
because a suppressed failure reads as a pass.

### RULE.TEST.ORACLE_INDEPENDENT
Every public value-returning operation is classified in the oracle registry, and relational-only coverage
is a finding. The classes are analytic (a closed form derived independently of the package), independent
(a direct computation written in the test), property (an invariant that pins the operation without
computing it), relational (compared only against other package operations — legitimate as a second layer,
never as the only one) and structural (returns metadata or storage). A new operation fails the registry
until someone classifies it, which is the moment to notice it has no independent oracle.

### RULE.TEST.DEFINITION_OF_DONE
A feature is done when its correctness tests, its performance test, the guiding documents, the remaining
documents, the benchmarks built and run, and the examples run are each verified, not assumed. "Should
work" is not done: a step is done when its verification command exits 0 and the exit code was observed.
Grep the docs for stale deferred, none-exist and future claims about whatever was just implemented.

### RULE.TEST.ALLOC_ZERO
Every in-place `!` operator is allocation-free and appears in the allocation audit, a deliberate
materializer gets a bounded guard, and where a bound covers another component's nondeterminism a
configuration pins the true zero. The audit runs on the CPU, where a materialized temporary is visible;
the completeness of its rows is derived from the export list, never remembered.

### RULE.TEST.PASS_AUDIT
Every audited operation has a frozen per-array traffic row, the fused ideal documented beside it, and a
named holder for any gap. A raised count is a fusion regression unless a new holder justifies it; the
frozen values are refrozen in the same commit as the change, with the reason.

### RULE.TEST.METHOD_PARITY
The public method set is frozen per generic and per module, and any change moves a number that is then
refrozen deliberately, with the reason. The per-module count is derived from ownership over the whole
function surface, internals included, so a method defined under a qualified name cannot hide.

### RULE.TEST.MUTATION
A symmetric fixture cannot see an asymmetric defect, a self-referential assertion cannot see a shared
defect, and a stated convention must be falsifiable by its fixture. Inject the defect and require the
suite to catch it; a fixture that cannot reach the broken branch proves nothing about it.

### RULE.TEST.BOTH_DIRECTIONS
Test the check in both directions: a check that cannot fail is not a check, and a self-reported field is
acceptable only when the missing case is the failing case. The flattering direction is the one nobody
guards: a check that demotes sound answers is stopped being read, and a check nobody reads passes
everything.

### RULE.TEST.MISSING_IS_FAILING
The missing case is the failing case: a denominator is derived, an absence arm exits non-zero, and a zero
count is a dead lane rather than a clean one. An empty witness directory, an empty ledger, an unparsable
status — each fails; "nothing to check" is not "all clear".

### RULE.TEST.RULE_WITH_CHECK
A rule and its check land in the same commit, and a stated rule without a check is a known weakness. A
rule is written by whoever has just fixed an instance, at the moment they are most confident the class is
handled — which is precisely when nobody builds the check; afterwards the rule's presence reads as
compliance. When a rule is written down, name what would catch its next violation in its `RULES.toml` `check`
field: a `scan:`, `doctor:` or `test:` id, a `harness:` binding the tool enforces it by, `panel` for a
rule only a reading panel can decide, `session` for a working agreement no artefact records, or
`weakness` — a check is possible and none is built. `panel` and `session` are answers; `weakness` is a
debt. A rule this rulebook has long called a known weakness because no program could ever decide it
is `panel`, not `weakness`: `weakness` is reserved for the check that could exist and does not.
"Someone remembering this rule" is not enforcement. A sweep reporting zero is the one to distrust:
falsify it against a fixture carrying a known positive before believing it.

### RULE.TEST.EXAMPLES_RUN
Shipped examples are executed after any change to the public surface, because nothing else runs them. An
example is both a rendered page and a downloadable script; the docs build renders it without running it,
and a call that no longer dispatches is found only by running it.

### RULE.TEST.COUNTS_REMEASURED
A count nothing asserts is re-measured, never cited, and a drop against the last recorded figure is a
finding. A test count, a testset count, a coverage figure — each is measured at the time it is stated.
