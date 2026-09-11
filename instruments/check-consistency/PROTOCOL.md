# /check-consistency — the fresh-eyed multi-hat panel over the RENDERED docs

This text is injected into the session by `gbg preflight check-consistency`, which has already
validated the config, run the quick doctor set (the `QUICK` selection of checks, the ones that hold on any machine with no build and no network), verified the running copy and OPENED the round named in
the lines that follow it. Everything below is done in that round, through the `gbg` verbs; nothing is
done by hand that a verb does.

## What it is

An expert panel of fresh-eyed agents reads the rendered documentation site as a reader would — a
reader-text manuscript consolidated from the built HTML, math as its TeX, one `PAGE:` banner per page —
and collects every internal-consistency and expert-instinct defect: a quantity or normalization defined
two ways across pages, a mathematical or category error, a structure or design smell, an unreachable
citation, a cold-read gap. It is the judgment-level counterpart of `/check-docs`, which runs the
deterministic battery against the source. Mechanical, pattern-matchable idioms (a gratuitous `\,`, an
unbraced fraction, a bare-index partial) belong to `/check-docs`'s scans, several of them
build-enforced; do not lean on the panel for them.

Most hats read ONLY their manuscript. A few are granted more because their defect class is invisible in
the rendered output: the typesetting hat reads the authored source and the rendered policy; the three
rulebook hats read the rulebook sections the config names, because a convention the corpus breaks
everywhere is invisible to a hat that infers norms from the corpus; the fossil hat reads git history.
Every hat is forbidden `.gbg/` and `~/.gbg/`. The panel is COLLECT-ONLY: it never edits `src/` or
`docs/`; the session acts only when the owner says fix.

## The round, step by step

1. **Prepare.** `gbg round prepare <round>` builds the docs (exit 0 required; the build runs under
   `GBG_ROUND`, so the gate inside it ignores this round), consolidates `docs/build` into the two
   manuscripts under `.gbg/scratch/<round>/` (`manuscript-full.md`, and `manuscript-siteonly.md` with the
   design docs the config withholds), and — when the round is seeded — plants the labelled defects of the
   consumer's seed catalogue into them with a per-round salt. During the panel ONLY the seeded copies
   exist; the ground truth is written at bank, never before. Do not open the manuscripts yourself.
2. **Panel.** Launch the `Workflow` call preflight printed, exactly as printed. The hats run
   concurrently; each `Write`s `findings/NN-<key>.json` FIRST and then returns the same object. The
   script returns liveness only (`written`, `dead`, `empty`, `truncated`); no tally. A DEAD hat is a hat
   that produced no file; an EMPTY hat wrote a file with zero findings and a non-empty `checked[]`; the
   two are not the same thing, and the bank tells them apart.
3. **Bank.** `gbg round bank <round>`: validates every lane file against the schema, quarantines an
   invalid one as `.rejected.json`, assigns ids `<round>/<lane>#<n>`, regenerates the UNSEEDED
   manuscripts, recomputes the ground truth, marks seeded findings by fragment match, prints recall per
   class (a skipped class is UNDEFINED, not zero) and flags SUSPECT any hat with two or more seeds on its
   substrate and zero matches, freezes `findings.json`, and renders `findings.md` and `SUMMARY.md`.
   **Any DEAD or REJECTED lane is exit 2 and nothing is frozen**; re-run only the dead lanes with
   `gbg round rerun <round> --lanes …` and bank again. A live lane whose file changed after first sight
   is REJECTED.
4. **Read.** `findings.md` is the work list, by id; `SUMMARY.md` is a reading aid — deduplicated, ranked
   by severity × corroboration (k of the n hats whose substrate could see it), seeded hits subtracted,
   capped hats marked — and never the input to a fix pass. A severity in the summary never overrides
   the hat's own.
5. **Fix pass** — only on the owner's word, at session strength, never economised. Work from
   `findings.md` by id. A flagged instance is a sample of a class: sweep every surface for the class.
   A build or test during the pass is `gbg round build <round>` / `gbg round test <round>`; a bare
   `julia --project=docs docs/make.jl` under an open round is refused by the gate, by design. Never fix
   the corpus from a seeded finding (bank marks them); never close a finding by declaring it "by design"
   or "for symmetry" — fix it, or put it to the owner as an adjudication with the trade-off.
6. **Verify.** `gbg round pass open <round>` refuses while an open finding names a file the fix pass
   left untouched (`--sweep-ok` overrides) or once the round's `max_passes` budget (3 by default) is
   spent; verifies only the ids still open, any closed one the fix pass has touched again, and any closed
   one that names no location at all — the act verifier the open ids, the state verifier all of them, a
   closed id back in scope being a re-check it alone reads; records the fix range and a nonce, regenerates the
   manuscripts after a fresh build, and prints two `Workflow` calls: the act verifier (sees the diff;
   grades `HONORED` / `ADJACENT` / `INSERTED` / `LINE-ONLY` / `NEW-DEFECT` / `SCOPE-CREEP` / `UNDONE` /
   `LAUNDERED`, `HONORED` earned by an enumerated `class_surfaces[]` list read from the finding's own
   text, never from the diff) and the state verifier (blind to the diff; `PRESENT` / `PARTIAL` /
   `REGRESSED` / `ABSENT` / `NOT-A-DEFECT` / `UNCLEAR`, default `PRESENT`). Launch both as printed. Each
   verdict file carries the nonce and the sha of `findings.json`; a copy-forward verdict is REJECTED.
7. **Grade.** `gbg round grade <round>` applies the demotion (`HONORED` becomes `LINE-ONLY`,
   mechanically, when `class_surfaces[]` is empty and equally when any entry in it is `swept: false`),
   the closure channels (`honored`, `adjudicated`, `seeded`, `rescan`, `carried`) and prints the pass
   series and the plateau signal; exit 1 while any id is open, and equally while any id is
   `pending_state` — closed by the act verifier with no state reading to confirm it.
   Loop 5–7 over the SAME `findings.json`: the denominator is fixed, so it converges. Re-running the
   panel over a just-edited corpus is a new search, not the closure loop; do it after closure if at all.
8. **Adjudicate.** A finding that is not a defect is closed by a ledger entry in `.gbg/exemptions.toml`
   with `scope = "finding"`, the id as `target`, a reason of at least 40 characters and an
   `overturn_when` condition. The CLI refuses a seeded id. Every such entry is audited by the dismissal
   auditor at close.
9. **Close.** `gbg round close <round>` when the latest pass has no open id, no lane is dead, the round's
   files are committed and the stamps are unchanged (a changed config or a moved pinned version means
   `gbg round pass open --regrade` first). Once the pass budget is spent it carries every id still open
   into the next round on a blind severity re-check, a serious one included, which then holds a final
   release back. Commit ⇒ push the round; cite the closure per lane and id in the commit message. `gbg round abandon <round> --reason "…"` is the only wholesale exit and lists
   every open id — a plateau is the usual reason.

## The rules that carry the weight

- Collect-only until the owner says fix. Verify before you trust: a rendered-text read is not ground
  truth — confirm a blocker against the current source and the built HTML before relaying it.
- Self-reported closure is not closure: the act verifier sees the diff, the state verifier is blind, the
  demotion is mechanical, and a zero count for a hat is a DEAD lane, not a clean hat.
- The seeded copy is disposable and the ground truth reaches no hat. A hat that opens `.gbg/scratch/`
  or diffs its manuscript against `docs/build` leaves a `Read` in its transcript; that residue is
  stated, not closed.
- Loop to a plateau, not to a good round: three passes flat within noise, with no dead lanes, is
  closure.
- Seeds measure recall only for the defects someone thought to plant. The panel is measured against a
  human read as well: `gbg calibrate` runs each hat blind on the passages recorded in
  `.gbg/human-findings.toml` and names every defect a hat missed and every one no persona's rubric
  covers — outside any round, whenever the owner has read the site.
