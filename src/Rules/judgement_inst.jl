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
    statement = "Unasked, run only Pkg.test(); every instrument, survey, benchmark and panel runs only on the user's request, in words or by slash.",
    why = "The correct output when one would be informative is to name it and its cost and wait. This is a consent boundary, not licence to leave work unfinished: finish the code, run the gate, and report what …",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const FOUR_OBJECTS = Model.Rule(
    id = Symbol("RULE.INST.FOUR_OBJECTS"),
    statement = "The four instruments audit different objects: changes, source prose, rendered prose, code.",
    why = "A flawless docstring on a function returning the wrong number passes both prose instruments; an edit that is a correct fix and still wider than the defect passes the hunt; each exists for what the …",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const WITNESS = Model.Rule(
    id = Symbol("RULE.INST.WITNESS"),
    statement = "A static claim about code is a hypothesis; the only evidence is a program that fails; a fixed witness is promoted unchanged.",
    why = "A passing witness means not a bug, discarded however good the argument; no witness writable means a latent hazard, reported and not fixed; a failing witness is the finding and, once the fix lands, …",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "the rulebook does not check it: harness:Witnesses.run enforces it inside a package's own test suite")

const SELF_REPORT = Model.Rule(
    id = Symbol("RULE.INST.SELF_REPORT"),
    statement = "Self-reported closure is not closure; the act verifier sees the diff, the state verifier is blind; the demotion is mechanical.",
    why = "Both default to the unfavourable verdict so a truncated lane fails safe; a zero count is a dead lane rather than a clean hat; the denominator never comes from the party being measured; and a …",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const CLOSURE_LOOP = Model.Rule(
    id = Symbol("RULE.INST.CLOSURE_LOOP"),
    statement = "The closure loop runs over the banked findings by id, never by re-running the battery; abandon is the only wholesale exit and names every open id.",
    why = "Closing a banked round terminates because the denominator is fixed; re-running the lanes over a just-edited corpus is a new search with no fixed point. Stop on a plateau — three passes flat within …",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const CARRY = Model.Rule(
    id = Symbol("RULE.INST.CARRY"),
    statement = "A round may close by carrying a finding into the next round of its instrument — a minor or nit at will, anything still open once its pass budget is spent — on a re-rated severity; it is re-banked there, never rediscovered. A round refuses to close by carrying a finding already carried CARRY_LIMIT (3) times — the owner rules on it instead — and a final release refuses while a carried blocker or major stands, while anything has been carried CARRY_LIMIT times, or while the backlog is not draining.",
    why = "The budget is `max_passes` verification passes, 3 by default: every pass re-runs both verifiers, and past the third 2026-09-10-check-docs-03 spent six more re-verif",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const AUDIT_AFTER_CODE = Model.Rule(
    id = Symbol("RULE.INST.AUDIT_AFTER_CODE"),
    statement = "A fix pass that changed code is audited before its round closes — always for a hunt, and for a check-docs round whose pass touched src or ext — by an audit that read the round's last code change.",
    why = "`/bug-hunt` always qualifies, and so does a `/check-docs` round whose pass touched the `src` or `ext` surfaces: closing refuses until a `/audit-changes` round based at the closing round's opening …",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const AUDIT_DISPOSED = Model.Rule(
    id = Symbol("RULE.INST.AUDIT_DISPOSED"),
    statement = "An audit round is closed by disposing its concerns, never by correcting them inside it; a correction rides the next change set, which the next audit covers.",
    why = "A correction moves the tree, the staleness check then refuses the close, and there is no re-bank; the round would be permanently unclosable. Each gated concern takes a disposition record instead, …",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const FIX_FROM_LANES = Model.Rule(
    id = Symbol("RULE.INST.FIX_FROM_LANES"),
    statement = "A fix pass is driven from the per-lane findings by id, never from the consolidated summary.",
    why = "Consolidation is lossy by design, which is what makes it readable; a severity in the summary never overrides the lane's own, and closure is reported per lane and per id.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const SEEDS = Model.Rule(
    id = Symbol("RULE.INST.SEEDS"),
    statement = "A seeded finding is never fixed in the corpus and never enters the ledger.",
    why = "Seeds are planted in a disposable copy to measure recall; the ground truth reaches no hat; a class at zero seeded recall is unmeasured, not clean; and recording a seed as adjudicated would hand the …",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const NO_TRUNCATION = Model.Rule(
    id = Symbol("RULE.INST.NO_TRUNCATION"),
    statement = "A scan output is never truncated (head, tail, a limit); count first, then read all.",
    why = "Adding a limit to keep the output readable is how a class gets half-swept and reported closed; a deterministic check that depends on who types it is not deterministic.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "the rulebook does not check it: harness:report enforces it inside a package's own test suite")

const FROZEN_MIDROUND = Model.Rule(
    id = Symbol("RULE.INST.FROZEN_MIDROUND"),
    statement = "An instrument is never changed mid-round; a change is its own commit and release; a deferral is written in the round's deferred.md and carried into the work queue at close; a round whose own frozen verifiers or auditors cannot run has those differing copies replaced by gbg round scripts --reason, never a lens, recorded in ROUND.toml.",
    why = "A change the round wanted and could not make is written one line per deferral in the round's `deferred.md`, and `gbg round close` carries each into `.claude/WORK_QUEUE.md`, where the Stop hook holds …",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

const ECONOMY = Model.Rule(
    id = Symbol("RULE.INST.ECONOMY"),
    statement = "Economy lanes by default; the five never-economised phases; strength = full on explicit request.",
    why = "A cheap lane's false positive is caught downstream; a false negative in a lane with no downstream verifier is why some lanes are anchors and stay at full strength in every mode.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "no program decides it yet: it is a habit the rulebook states and a reader keeps")

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[CONSENT, FOUR_OBJECTS, WITNESS, SELF_REPORT, CLOSURE_LOOP, CARRY, AUDIT_AFTER_CODE, AUDIT_DISPOSED, FIX_FROM_LANES, SEEDS, NO_TRUNCATION, FROZEN_MIDROUND, ECONOMY]

end # module JudgementInst
