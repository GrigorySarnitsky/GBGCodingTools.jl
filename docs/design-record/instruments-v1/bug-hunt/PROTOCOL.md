# /bug-hunt — the CODE instrument

This text is injected into the session by `gbg preflight bug-hunt`, which has already validated the
config, run the quick doctor set (the `QUICK` selection of checks, the ones that hold on any machine with no build and no network), verified the running copy and OPENED the round named in the lines that
follow it. Everything below is done in that round, through the `gbg` verbs.

## The one rule

> **A static claim about code is a hypothesis. The only admissible evidence is a program that FAILS.**

`/check-docs` and `/check-consistency` audit prose; neither asks whether the code is correct. This one
hunts the code, and it is a correction for a measured failure mode, not a preference: an agent reading
code and reporting what "looks wrong" produces fluent, confident, unfalsifiable prose, and here that
costs a fix pass on WORKING code — strictly worse than the imagined bug, because the tree gets edited,
the suite still passes, and afterwards nobody can tell whether anything was ever wrong. So the hunt is
static and the confirmation is dynamic. Every candidate reduces to a WITNESS: a self-contained
`@testset` asserting the CORRECT behaviour, therefore observed to FAIL on this tree.

| the witness … | means |
|---|---|
| FAILS | the finding. Unchanged, it is the regression test the fix must flip. |
| PASSES | not a bug. Discarded, however good the argument. |
| ERRORS | evidence about the witness, not the package. Fixed and re-run, or BLOCKED with a reason. |
| cannot be written | a latent hazard: reported, never fixed on that evidence. |

A failing witness is necessary and NOT sufficient: a witness can fail because the WITNESS is wrong, and
a test asserting a false identity fails on perfectly correct code. The reproducer therefore derives
the expected value INDEPENDENTLY of the assertion — from the documented contract, an analytic case, a
mathematical identity, or a second route to the same quantity — and returns `WITNESS-WRONG` when that
derivation agrees with the code. Two classes escape the witness rule and are handled explicitly:
ARCHITECTURE (duplication, divergent copies, a leaked abstraction, an invariant broken in code — no
test can fail on it, so the evidence is two quoted locations a reader can diff plus the stated
maintenance consequence; verdict `EVIDENCED`), and API-SEMANTICS (a claim about what `Base` or a
dependency does — the official documentation fetched and quoted with its URL AND a witness that runs).

## Lanes

The consumer's TERRITORIES (from its config) plus two FREE lanes that are always present and anchored:
lanes differ by territory so coverage spreads; the free lanes carry no list, because a list is a
hypothesis about where bugs live and a defect outside every class is invisible to every class lane by
construction while the run still reports complete. Hunters produce hypotheses with a witness plan;
a pipeline hands each candidate to a REPRODUCER at session strength, which writes the witness under
the round's `witnesses/`, runs it with quoted paths under the configured witness environment, and
rules. Hunt lanes run at economy by default; reproduction is never economised. Every agent is
forbidden `.gbg/` except the round's own `witnesses/` directory, and `~/.gbg/`.

## The round, step by step

1. **Hunt.** Launch the `Workflow` call preflight printed, exactly as printed. Each lane `Write`s
   `candidates/NN-<lane>.json` and, through its reproducers, the witnesses `witnesses/<lane>-<n>.jl`.
   The script returns liveness only. A lane that died is UNHUNTED territory, not clean territory.
2. **Bank.** `gbg round bank <round>` runs the witness runner itself over `witnesses/` expecting
   failure — the lane's ACCOUNT of a failing program is not the program. It refuses any witness that
   `include`s a file or loads anything outside the package under test, `Test` and the stdlib; REJECTS a
   `REPRODUCED` whose witness does not fail mechanically; records the sha256 of every failing witness
   body; assigns `BLOCKED` only to a witness that ERRORED, was never observed to fail, and carries a
   `# blocked: <reason>` header (moved to `witnesses/blocked/`); freezes `findings.json` and the
   disposition records `reproductions/<id>.json`. A DEAD or REJECTED lane is exit 2 and nothing is frozen.
3. **Fix** — on the owner's word, at session strength, never economised, driven from `findings.md` by
   id. A witness is never edited to suit a fix: a witness edited to pass has stopped being evidence.
   Builds and tests during the pass are `gbg round build|test <round>`.
4. **Dispose.** Every confirmed finding ends in exactly one of three states in its disposition record:
   `fixed` (its witness flips), `refused` (with a reason of at least 24 characters and the measurement
   recorded at the site), or `escalated` (a design decision put to the owner, with `overturn_when`; its
   witness stays under `witnesses/escalated/` and is never promoted, so nothing reads green over it).
   A finding in none of these is a DROPPED finding and `close` fails on the arithmetic.
5. **Promote.** Each `fixed` witness is promoted into `test/regressions/` by explicit path, per
   finding as it closes, with its provenance header stripped and its body otherwise unchanged — the
   promoted body must hash-equal the bank-time body. Never `cp witnesses/*.jl`: a still-open witness
   promoted turns the suite red for what looks like a bad fix, and a name reused across rounds
   overwrites an older regression test. A witness locates files through `pkgdir`, never by counting
   `..` hops.
6. **Verify the architecture class.** `gbg round pass open <round>` prints the architecture verifier
   (`FIXED` / `RELOCATED` / `PARTIAL` / `ABSENT` / `NOT-A-DEFECT`, default `ABSENT`); it hunts
   `RELOCATED`, the duplicate moved to a new file that reads as a fix in a diff and as a defect in the
   tree. `gbg round grade <round>` folds it in.
7. **Audit the edits.** Before close, an `/audit-changes` round with `base` = this round's opening head
   and `head` = HEAD must be run and closed: a witness exists only for a defect the hunt FOUND, so a
   regression introduced by a FIX is invisible to the witness gate — measured: `NEWLY BROKEN = 0` while
   two regressions were live.
8. **Close.** `gbg round close <round>` requires, in order: the round's files committed; the witness
   of every `fixed` finding PASSING under the runner (`gbg witnesses pass <round>`); every `fixed` witness promoted with a
   hash-equal body; `Pkg.test()` green under `GBG_ROUND` (`gbg round test`); the dismissal auditor run
   over every refusal and adjudication with `reopened == []` (a filed dismissal is never revisited
   otherwise, and two of a real round's were wrong, one a blocker — it defaults to `UNSAFE`); the
   audit-changes round closed; `fixed + refused + escalated == confirmed`; the opening head an ancestor
   of HEAD; a clean tree; pushed. BLOCKED witnesses are listed in the close account with their reasons
   and re-run by `gbg doctor --deep` on a host that has the device.
9. **The pass budget.** A hunt has `max_passes` verification passes (3 by default); past it `pass open`
   refuses, and `close` carries every finding still open into the next hunt, a `blocker` or `major`
   included, which then holds a final release back. A carried finding owes this round no disposition
   and takes its evidence with it: the next hunt's bank copies its witness in and re-runs it, so a
   defect still failing is confirmed again, and one whose witness now passes leaves the carried ledger.

## Run the hunt ONCE; loop the disposition

The finding set is fixed by one hunt. What loops is fix → witness → dispose over that set, which
terminates because the set is finite. A follow-up hunt confirming "nothing new" is not a closure
condition: each round's fixes seed the next round's findings (measured across five rounds: 20, 9, 17,
21, 17), so such a rule makes "finished" permanently false and licenses unbounded edits to CODE. Run a
new hunt as a new round, on the owner's word, never as the way to close this one.
