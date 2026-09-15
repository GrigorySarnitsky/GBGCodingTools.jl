# /check-docs — the complete documentation-quality battery over the SOURCE

This text is injected into the session by `gbg preflight check-docs`, which has already validated the
config, run the quick doctor set (the `QUICK` selection of checks, the ones that hold on any machine with no build and no network), verified the running copy and OPENED the round named in the lines that
follow it. Everything below is done in that round, through the `gbg` verbs.

## What it is

The full matrix of every check × every documentation surface, run to completion in one round — not one
check, not one file. The surfaces come from the config: the rationale documents, the hand-written pages,
the docstrings of `src/` and `ext/`, the Literate examples, and the BUILT HTML after the docs build
(what each `@docs` block actually collected is visible only there). The checks: correct, self-contained,
notation, formatted, current and complete, cited, consistent across variant pairs — and the operational
claims of each docstring against its body, which no other instrument holds together.

The deterministic half runs first, in the CLI; the judgment half is a fan-out of lanes, one per surface
plus three cross-cutting lanes (`one-home`, `cold-reader`, `operational-claims`). A rationale surface
that is one document is cut into `rationale_lanes` slices on its own headings, the first keeping the key
`rationale`. Every surface lane is handed a computed CLAIM CHECKLIST — each cited number, each
exit-code claim and each quantifier claim on its own surface — and owes a verdict per item in
`claims_checked[]`. A lane reports
CLASSES, never sites: a recurring defect is ONE finding whose `locations` name every site, and
`finding_cap` bounds those findings, so a class with forty sites costs one. The lanes run at economy by
default; the fix pass is never economised.

## The round, step by step

1. **Prepare.** `gbg round prepare <round>` runs the scan engine (`gbg scan docs`): every `hard` hit is
   banked as lane `00-scans`, closed later by `rescan`, never by a verdict; every `triage` scan is printed
   in full — count first, then read all of it; NEVER pipe a scan through `head` or `tail`. It then runs
   the reflection checks (argument coverage under the package's `argcov_policy`, signature fidelity,
   `dupref`, `xlink` dry-run), builds the docs under `GBG_ROUND` (exit 0 required) and runs the built-HTML
   scans (`gbg scan html`): no docstring rendered on two pages, every derived public operation on a public
   page, no unexpected `Base.` name in an internal section (the config's allowance excepted). When the
   round is seeded (`check-docs.seed_rounds`), it also plants the labelled defects of the consumer's seed
   catalogue into a DISPOSABLE COPY of the lane files under the round's `seed_root`, with a per-round
   salt, and the lanes read that copy in place of the working tree. The ground truth is written at bank,
   never before; do not open the seeded copy yourself. One question
   is a read, not a scan: each API page's blurb against what its `@docs` block holds — read it from the
   build.
2. **Lanes.** Launch the `Workflow` call preflight printed, exactly as printed. Each lane first discharges
   its claim checklist, then runs the six checks as POSITIVE procedures on its surface — enumerate, then
   verify each item, with `src/` as ground truth and the decisive line quoted — and `Write`s
   `findings/NN-<lane>.json` FIRST, then returns the same object. The cold-reader lane reads the `?name` view: the module docstring and EVERY method
   docstring of a generic; verify each of its findings against source before fixing, since a term may be
   defined on a sibling method it did not open. Every lane is forbidden `.gbg/` and `~/.gbg/`.
3. **Bank.** `gbg round bank <round>`: schema-validates each lane file, quarantines an invalid one,
   assigns ids, freezes `findings.json`, renders `findings.md` and `SUMMARY.md`. A DEAD or REJECTED lane is exit 2 and
   nothing is frozen; `gbg round rerun <round> --lanes …` re-runs only the dead ones. On a seeded round it
   also recomputes the ground truth from the untouched tree and the salt, marks the seeded findings (they
   are never fixed in the corpus), prints recall per class and the SUSPECT lanes — those handed two or
   more seeds that reported none — and deletes the seeded copy.
4. **Fix pass** — on the owner's word, at session strength. Work from `findings.md` by id. Fix the class,
   not the line. Drop the genuine false positives with a reason (universally standard math, the real Julia
   operators `×` `⋅` `≈`, comment-line hits, a kwarg correctly backticked). The build is the oracle for
   link resolution: a clean exit refutes a "dead link" finding. Builds and tests during the pass go
   through `gbg round build|test <round>`.
5. **Verify.** `gbg round pass open <round>` prints the act verifier (sees the diff) and the state
   verifier (blind) with this instrument's lanes as the roster; launch both as printed. It refuses to
   open while an open finding names a file the fix pass did not touch — fix the class at every location
   the finding names, or re-open with `--sweep-ok` when the fix rightly lives elsewhere. A pass after
   the first verifies only the ids still open, any closed one the fix pass has touched again, and any
   closed one that names no location at all; everything else keeps the entry that closed it. The act
   verifier grades only the open ids; a closed id back in scope is a re-check, read by the state verifier
   alone, and it stays closed while that reading is still `ABSENT`. The round has a budget of
   `max_passes` passes (3 by default); past it `pass open` refuses. A dismissal is a
   verdict the verifier grades like any other: it must name the rule or recorded decision that licenses
   it, and a dismissal the verifier cannot confirm is `UNDONE`, not closed.
6. **Grade.** `gbg round grade <round>`: demotion, closure channels, plateau signal; a `hard` scan
   finding closes when `grade` re-runs the scan and it no longer fires. Loop 4–6 over the same
   `findings.json`; do NOT re-run the lanes to check the work — a fresh battery over an edited corpus
   always returns new findings, so it has no termination condition.
7. **Adjudicate and close.** Ledger entries with `scope = "finding"` and `overturn_when` for what is not
   a defect; `gbg round close <round>` when no id is open, no lane is dead, the files are committed, the
   stamps are unchanged and the last recorded docs build is green with nothing under the covered paths
   changed since (`prepare` and `gbg round build` record theirs, over committed covered paths only: after a last fix, commit it, build, commit the round) — or, once the pass budget is spent, with every id still open carried into the
   next round on a blind severity re-check, a serious one included, which then holds a final release back. If the fix pass touched `src/` or `ext/` — an operational finding fixed in the
   code, not in the prose — closing refuses until `/audit-changes --base <this round's opening head>` is
   itself closed and has read the round's LAST code change, so it runs after the final fix pass
   (`RULE.INST.AUDIT_AFTER_CODE`): the verifiers graded each finding, and nothing yet asked
   whether the edits were proportionate or whether behaviour moved for input that worked before.
   A class the pass could not fix because the fix is an INSTRUMENT change (a new scan, a changed lane) is
   one BULLET in `<round>/deferred.md` (a bullet may wrap; prose outside every bullet is carried nowhere); `close` carries it into `.claude/WORK_QUEUE.md`, where the Stop hook
   holds the next session to it. Never the roadmap: nothing reads the roadmap. Commit ⇒ push the round with the per-lane closure counts in the message.

## The rules that carry the weight

- Verify by EXIT CODE, never by grepping a log: a lint failure prints `ERROR: LoadError:`, which no
  `^┌ Error` pattern matches, and three false "docs clean" reports once stood on that mismatch.
- A scan's output is never truncated. A class swept from a truncated list is reported closed while
  half of it survives.
- The fix pass is verified, not self-reported: bank, verify, grade, loop over the banked set.
- "Check the docs" means this complete battery, never one check or one file.
