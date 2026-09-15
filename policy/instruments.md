# The instruments (`RULE.INST.*`)

### RULE.INST.CONSENT
Unasked, run only `Pkg.test()`; every instrument, survey, benchmark and panel runs only on the user's
request, in words or by slash. The correct output when one would be informative is to name it and its
cost and wait. This is a consent boundary, not licence to leave work unfinished: finish the code, run the
gate, and report what remains unverified and why. "Check the docs" is such a request: it means run
`/check-docs`.

### RULE.INST.FOUR_OBJECTS
The four instruments audit four different objects: `/audit-changes` the changes to code, `/check-docs`
the source prose, `/check-consistency` the rendered prose, `/bug-hunt` the code. A flawless docstring on
a function returning the wrong number passes both prose instruments; an edit that is a correct fix and
still wider than the defect passes the hunt; each exists for what the others cannot see.

### RULE.INST.WITNESS
A static claim about code is a hypothesis; the only admissible evidence is a program that fails; a fixed
witness is promoted unchanged. A passing witness means not a bug, discarded however good the argument; no
witness writable means a latent hazard, reported and not fixed; a failing witness is the finding and, once
the fix lands, the regression test — necessary and not sufficient, since a witness can fail because the
witness is wrong, so adjudication derives the expected value independently of the assertion.

### RULE.INST.SELF_REPORT
Self-reported closure is not closure: the act verifier sees the diff, the state verifier is blind, and the
demotion is mechanical. Both default to the unfavourable verdict so a truncated lane fails safe; a zero
count is a dead lane rather than a clean hat; the denominator never comes from the party being measured;
and a dismissal is a verdict the verifier grades like any other.

### RULE.INST.CLOSURE_LOOP
The closure loop runs over the banked findings by id, never by re-running the battery, and abandon is the
only wholesale exit and names every open id. Closing a banked round terminates because the denominator is
fixed; re-running the lanes over a just-edited corpus is a new search with no fixed point. Stop on a
plateau — three passes flat within noise, with no dead lane — never on a good round.

### RULE.INST.CARRY
A round may close by CARRYING a finding into the next round of its instrument: a `minor` or a `nit`
whenever the owner chooses, and every finding still open once the round has spent its pass budget, a
`blocker` or a `major` among them. The budget is `max_passes` verification passes, 3 by default: every
pass re-runs both verifiers, and past the third 2026-09-10-check-docs-03 spent six more re-verifying
fixes already made. Past the budget severity decides releasability, not closability: a final release
refuses while a carried `blocker` or `major` stands. The severity that counts is a re-rating by someone
other than the lane that reported it, because a rating that can defer a finding is a rating its author
has a reason to lower. A carried finding is re-banked into the next round after its lanes have run —
never shown to the searching panel, and never left to be rediscovered, since a fresh battery is a fresh
search and a finding trusted to luck is a finding dropped. Across rounds the constraint is that the pile
drains, which a final release checks, and no finding rides more than three rounds before the owner
rules on it instead.

### RULE.INST.AUDIT_AFTER_CODE
A fix pass that changed code is audited before its round closes. `/bug-hunt` always qualifies, and so does
a `/check-docs` round whose pass touched the `src` or `ext` surfaces: closing refuses until a `/audit-changes`
round based at the closing round's opening head is itself closed and has read the round's last code
change, so it runs after the final fix pass. The two verifiers grade each finding as
asked; neither reads the diff whole, runs anything, or asks whether input that worked before still does.
A prose-only pass is not gated: run the audit's prose lenses on judgment when the pass rewrote docstrings
that state a contract.

### RULE.INST.AUDIT_DISPOSED
An audit round is closed by disposing its concerns, never by correcting them inside it. A correction moves
the tree, the staleness check then refuses the close, and there is no re-bank; the round would be
permanently unclosable. Each gated concern takes a disposition record instead, and a correction the
audit asks for rides the next change set, which the next audit covers. This is why `bank` on an audit
round names the disposition and not a fix pass.

### RULE.INST.FIX_FROM_LANES
A fix pass is driven from the per-lane findings by id, never from the consolidated summary. Consolidation
is lossy by design, which is what makes it readable; a severity in the summary never overrides the lane's
own, and closure is reported per lane and per id.

### RULE.INST.SEEDS
A seeded finding is never fixed in the corpus and never enters the ledger. Seeds are planted in a
disposable copy to measure recall; the ground truth reaches no hat; a class at zero seeded recall is
unmeasured, not clean; and recording a seed as adjudicated would hand the next round its answer key.

### RULE.INST.NO_TRUNCATION
A scan's output is never truncated by `head`, `tail` or a limit: count first, then read all. Adding a
limit to keep the output readable is how a class gets half-swept and reported closed; a deterministic
check that depends on who types it is not deterministic.

### RULE.INST.FROZEN_MIDROUND
An instrument is never changed mid-round; a change is its own commit and release, and reaches a consumer
by a bump. A change the round wanted and could not make is written one line per deferral in the round's
`deferred.md`, and `gbg round close` carries each into `.claude/WORK_QUEUE.md`, where the Stop hook holds
the next session to it. A deferral recorded anywhere else is a note, and a note is not a mechanism. A round records the instrument version that measured it and cannot close under a different
one unless re-graded; a rate sequence means something only at a fixed instrument. One relaxation is
recorded rather than hidden: a round whose own frozen Workflow scripts cannot run — its verifiers
unparseable, so it could never verify — has the differing copies replaced by `gbg round scripts
--reason`, which writes the reason, the pass count and each script's sha into `ROUND.toml`.

### RULE.INST.ECONOMY
Economy lanes are the default, the five phases — adjudication, reproduction, verification, consolidation,
the fix pass — are never economised, and full strength runs on explicit request. A cheap lane's false
positive is caught downstream; a false negative in a lane with no downstream verifier is why some lanes
are anchors and stay at full strength in every mode.

## Honest limits

Stated, not claimed closed: grader/graded separation holds for code and prompts, not for files a session
can forge — the residue is transcript-visible, not gate-visible. A consistency round's seeded copy lives inside
the project, gitignored, and a docs round's in a temporary directory outside it that bank deletes; a hat that opens it, or diffs its manuscript against the built site, leaves a read in
its transcript and nothing in the tally except, sometimes, a suspect flag on the hats that did not. A
`GBG_ROUND` exported by hand outside a CLI invocation makes the gate ignore that round exactly as a
CLI-run build would; the export is in the transcript, and CI never sets it. A working tree's gate can see
an open round that was not committed; CI proves only the pushed state.
