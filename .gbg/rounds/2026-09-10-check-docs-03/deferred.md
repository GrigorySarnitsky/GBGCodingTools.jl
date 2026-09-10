# Deferrals of 2026-09-10-check-docs-03 — each is an instrument change, which is its own
# commit and its own release, never an edit inside the round it would score. `gbg round close`
# carries every bullet below into .claude/WORK_QUEUE.md.

- `Recall.suspect_hats` decides a lane's visibility with a HAT's notion of substrate
  (`full` / `siteonly`), so for a check-docs round every seed counts as visible to every lane no
  matter which files that lane actually reads. A docs lane sees a file set, not a manuscript view:
  give `suspect_hats` a per-instrument visibility predicate — the lane's own `files[]` for
  check-docs — or its SUSPECT flag measures nothing for this instrument.

- `Passes.class_candidates` greps the whole tree, so it offers surfaces that live in gitignored
  build products (`docs/src/architecture.md`, `docs/src/guide/rules.md`, `docs/build/**`). Those are
  regenerated from their sources and can never be swept by a fix; offering them invites a verifier to
  mark a class unswept at a file no fix pass may touch. Filter the candidate list by the config's own
  surfaces, or by `git check-ignore`, before it reaches the verifier.

- `pass open`'s unswept refusal is computed over the CURRENT fix range only, so a location fixed in
  an earlier fix range and verified swept there is reported untouched at every later pass. Pass 2 of
  this round had to be opened with `--sweep-ok` for 13 ids whose named locations were already correct.
  The refusal should compare against every fix range since the finding was banked, not only the last.

- The nonce and `graded_sha256` reach a verdict file by an agent RETYPING them, and a one-character
  slip is indistinguishable from the copy-forward the check exists to catch: pass 7 of this round had
  `…ec5662` for `…ed5662` in two of three act lanes and both were REJECTED. The scribe step should
  write those two fields from the args it already holds rather than from the model's transcription —
  `scribe()` in `verify-act.js`/`verify-state.js` can stamp them after the agent returns.

- `pass open` opens a NEW pass whenever the config stamp has moved, so adjudicating between a pass's
  verifiers and its `grade` throws that pass's verdicts away — a ledger entry moves `config_sha`.
  Nothing says so; the loop only discovers it when `grade` refuses. Either `--regrade` should be able
  to re-stamp the CURRENT pass in place when its verdicts are complete, or `grade` should say plainly
  that the stamp moved because the ledger grew and name the pass that will be lost.

- `pass open --regrade` re-stamps `tool_tree_sha`, which defeats `close`'s abandon-only refusal for a
  moved tag: refuse, regrade, close, and the round closes stamped with the moved tag. The regrade
  branch should re-stamp `config_sha`, `tool_version` and `tool_rev` only, never `tool_tree_sha` under
  an unchanged non-dev `tool_version`. Found by the dismissal auditor's fifth reading of this round.

- `dismissals.js`'s final `write-dismissals` agent was blocked by a safety classifier on two of five
  runs, leaving `dismissals.json` stale while all 26 item agents had returned. The aggregate is a
  mechanical assembly of returns the script already holds; it should be written by the script's own
  scribe path (as the lane files are), not by an agent asked to retype the whole object.
