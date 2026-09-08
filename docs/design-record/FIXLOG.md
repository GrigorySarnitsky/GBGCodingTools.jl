# FIXLOG — Revisions 2 and 3 (2026-09-07)

Every item of `REVIEW-dryrun.md` (1–57), every scenario of `REVIEW-attack.md` and every ruling of
`05-fix-rulings.md`, mapped to what changed. `A` = `out/ARCHITECTURE.md`, `I` = `out/IMPLEMENTATION.md`.
"Applied (ruling N)" means the ruling's version of the fix was used where it differs from the review's.

## Rulings 1–22

| Ruling | Where | What changed |
|---|---|---|
| 1 gate vs own round | A vocabulary (`GBG_ROUND`), D9, §6.2 steps 3/6/7/9/10, §6.7, §6.8, §8 arms, §11; I §B, 1.3 (`round build\|test`), 1.4, 1.6, 1.8 | `GBG_ROUND=<round-id[,…]>` exported by the CLI around `make.jl`/`Pkg.test()`/executable claims; `gbg gate` ignores exactly those rounds; CI never sets it; manual export a stated residue |
| 2 fixture pin | A D2, D15, §3, §8; I 1.2 (4), 1.7 fixture, Phase 1 DoD, Phase 3 | fixture `[tool] version = "dev"`; sub-envs `path` source to the enclosing tool repo (written as `../../..` from a sub-env, `../..` from the fixture root — the ruling's `../..` counted from the fixture root); `dev` legal only inside the tool repo (`PIN.CONFIG`); dev rounds abandon-only |
| 3 `$DEV` in `bash -c` | I header (exports), Phase 1 DoD, Phase 3, Phase 4 DoD | `export B DEV PF IT SS CP`; every `bash -c` block now double-quoted |
| 4 shim ↔ dev checkout | A D2, §3, §7.3 (`ENV.DEV_CHECKOUT`, `SHIM.HASH`); I 1.2, 1.3 (`install --dev-checkout`), Phase 3 | `~/.gbg/dev` one-line file; shim reads it for `--dev` and outside a consumer; `SHIM.HASH` compares the body only |
| 5 QUICK | A D14, §7.3 header; I 1.3, 1.4 | `QUICK = {CFG.*, PIN.CONFIG, PIN.SOURCES, PIN.NOT_DEV, EXEMPT.*, WIRE.*, MANAGED.HASH, ROUND.*, POL.SENTINEL}`; `ENV/SHIM/GIT/LEG/--deep` never; `run_gate` uses it; `--only QUICK` documented as a named set |
| 6 PIN.TREESHA + self verify | A D3, D2, §6.1 (`tool_tree_sha`), §6.2 steps 2/9/10, §7.3 (`PIN.TREESHA`, `PIN.SELF`), §8; I 1.3 (`gbg self verify`), 1.6 (`tree.py`), Phase 3 | over every existing sub-env manifest, WARN when absent, FAIL on disagreement; `self verify` re-hashes the running copy in Python at the start of every `round` verb and `gate`; edited copy ⇒ exit 2 |
| 7 Step 0 on live trees | A D15, §8 (target table); I Phase 2, PF-2, 5.2 | live working trees (Aiporetne PF, Enteropia/Dropbox IT); the untracked `.claude/doc-review/` imported; targets per round stated (67/11/59; 18/18; 8 findings, 30 HONORED; 134; IT markers) |
| 8 config anchors | A §5 header (anchor semantics), §5.1–§5.3, §7.3 `CFG.SURFACES` | `history_exempt = "docs/ARCHITECTURE.md#13. Decision log"`; `references_heading` optional with `"absent"` (PF) ⇒ whole-file DOI scan; IT/SS/CP set to their real `## References` headings |
| 9 hats | A D7, §3, §5.1 (`domain_hats` ×4, `rulebook_sections`), §5.3, §9 row, §12; I 1.7, PF-1, 5.2 | `gpu-kernel-practitioner`/`normalization-convention-auditor` are PF domain hats; rulebook hats generic in the catalogue over `[package] rulebook_sections` |
| 10 versions | A D4, D17, §8, §10; I 5.1, 5.2 DoD, Phase 8 | 1.0.0 holds the whole engine; 5.1 = verify IT mechanisms, defect ⇒ 1.0.x; every other "1.1.0" removed (one mention survives inside D17's dominated alternative, as history); `gbg fleet` shows all at 1.0.x |
| 11 schema/config | A §1, D5, §5.1–§5.4, §10; I 1.6, 1.7 | `docs.retired_claims` added; `arguments_form_min`, `allocating_wrapper_phrase`, `fields_phrase`, `notation.imaginary`, `notation.partial` removed; `lanes` → `lanes_extra`; `public_surface` and `executable_claims.gate` constants; missing path ⇒ exit 2; `sync`/`PIN.SOURCES` walk every sub-env; `argcov_policy` declared as the tier exception in §5.5 (§5.4 at Revision 2) with the `# Arguments` reason |
| 12 exit codes | A D8, D10, §6.1, §6.2 steps 5/8, §8 | DEAD ⇒ 2 everywhere; absent/unparsable/invalid lane file ⇒ DEAD, quarantined |
| 13 doctor/ledger | A D14, §7.2, §7.3, D9 (`TestHarness.gate()` banner), D13, §6.2 step 2 | non-exemptable/exemptable sets; `expires` required except finding scope (`overturn_when`), ≤ recorded + 365 d; `command -v gbg` in `SHIM.HASH`; `MANAGED.HASH` fresh render; `TEST.PKG` banner witness; disabled instruments still gated (`CFG.VALID`); dirty-tree refusal on closed/abandoned rounds only |
| 14 seeds | A D7, D10, §6.2 steps 3/4/5/7, §6.4, §11; I 1.5 common changes, 1.6 `seed.py`, 1.8 | salted per-round selection; hats forbidden `.gbg/**` and `~/.gbg/**`; manuscripts under `.gbg/scratch/<round>/`; SUSPECT flag in the tally; the diff-against-`docs/build` residue stated |
| 15 config_sha | A D16, §6.1, §6.2 steps 5/7/8/9 | covers `config.toml`, `hats/*.toml`, `exemptions.toml`; every `round` verb refuses a change (exit 2 → `pass open --regrade`, re-validates and re-stamps) |
| 16 bug-hunt | A D9 (`Witnesses.run` refusal), §6.3, §6.7, §7.3 `WITNESSES.*`; I 1.4, 1.5 `hunt.js` | `reproductions/*.json` frozen at bank (`reproductions_sha`); `include(`/outside loads refused; `ROUND.head` ancestor of HEAD at close (else `--regrade`); BLOCKED needs a header reason and is listed in the close account |
| 17 audit-changes | A §1 (`[paths]`), §5.1, §5.5 (§5.4 at Revision 2), §6.8, §7.3 `AUDIT.GAP` | covered constants `src, test, ext, docs, Project.toml` + `[paths]`; config only ADDS; `AUDIT.GAP` WARN; empty audit's `verdict_all_clean` needs the executable claims run with exit codes recorded |
| 18 fleet | A D4, D16, §3 (`[sweep]`), §11; I 1.1 `fleet.toml`, 1.3 `bump`/`fleet` | window checked by `gbg fleet` and `gbg bump`; the bump that opens a second version records `[sweep]`; preflight does NOT check the fleet |
| 19 owner questions | A §10; I §A, §B | Q1–Q7, Q12 kept; Q8–Q11 deleted and their decisions stated in §B (and A §10 "Decided by the record") |
| 20 record deviations | A D9, D16, D18, §6.1, §6.2 step 7, §7.3 `WITNESSES.ESCALATED`, §10 | `gbg gate check-docs check-consistency`; never-economised = the record's five; `init --migrate` writes `commit-message.txt`, `bump` writes `bump-message.txt`; `pass open` renders through `preflight.py`'s renderer; doctor prints "promote"; §6.1 `ROUND.toml` list is the complete one |
| 21 fill tables | A §12.A (rule ids, 91 — this row said 90), §12.B (scan ids with tiers, 39 + `SCAN.CUSTOM.<id>` — this row said 41 + custom), §7.3 (doctor ids, final) + §12.C | derived from PF `CLAUDE.md` headings, `guards.sh`, the four PF `.py` scans, PF `make.jl` lints, IT `abutting_spans.py`, IT `lint_notation_variants`/`lint_docstring_shape`, IT `check-docs.md` deterministic block |
| 22 minor citations | see dry-run 24–47 below | all applied |

## `REVIEW-dryrun.md` items 1–57

| # | Status | Where / what |
|---|---|---|
| 1 | Applied (ruling 1) | A §6.2 steps 3/6/7/9/10, D9, §6.7, §6.8, §8 arm; I 1.4, 1.6, 1.8, §B. The review's "banked-and-not-closed" predicate was NOT adopted — ruling 1 keeps "any open round → 1" and exempts only `GBG_ROUND` |
| 2 | Applied (ruling 2) | A D15, §8; I 1.7, Phase 1 DoD, Phase 3 (`gbg selftest --pinned` for the pinned-copy behaviours) |
| 3 | Applied (ruling 3) | I header exports; `__main__.py` accepts `--dev` (I 1.3, A D2) |
| 4 | Applied (ruling 4) | `~/.gbg/dev` instead of `~/.config/gbg/dev-checkout`; `ENV.DEV_CHECKOUT` WARN added (A §7.3) |
| 5 | Applied (ruling 5) | QUICK set (A §7.3, D14; I 1.4); `ENV/SHIM/GIT` excluded rather than "skipped when CI is set" |
| 6 | Applied (ruling 6) | A D3, §7.3 `PIN.TREESHA` (manifests that exist; two slugs ⇒ FAIL) |
| 7 | Applied (ruling 7) | A §8 target table; I Phase 2, PF-2 |
| 8 | Applied (ruling 8) | A §5 anchor semantics; `#13. Decision log`; PF `references_heading = "absent"` (not the review's `@**References.**` marker) |
| 9 | Applied (ruling 9) | eight catalogue keys named (A D7, §3; I 1.7); PF `domain_hats` ×4 with `anchor = false`; PF-1 hats from `panel.js:88,93,96,119` (that step is PF-0 since Revision 3) |
| 10 | Applied (ruling 9 — opposite side) | rulebook hats have ONE home, the catalogue (A D7, §5.3; I 1.7, 5.2), not `.gbg/hats/` as the review proposed |
| 11 | Applied (ruling 10) | option (a): 1.0.0 = everything (A D17, D4; I 5.1) |
| 12 | Applied (ruling 11) | `docs.retired_claims` in §5.1 with PF's list, §1 row, `SCAN.RETIRED_CLAIMS` |
| 13 | Applied (ruling 12) | DEAD ⇒ 2 (A D8, D10, §6.2 step 5) |
| 14 | Applied | `lane_shas` at first sight; `findings.json` only on exit 0; `rerun` DEAD-only; changed live lane ⇒ REJECTED (A §6.1, §6.2 step 5, D10) |
| 15 | Applied | PF-0 step (PAT, `GBG_DEPS_TOKEN` in PF and SS and CP, snippets via `sync`); V4 probes PF and CP (I Phase 0, PF-0, Phase 6, Phase 7; A §4, §7.3 `WIRE.CI_AUTH`) |
| 16 | Applied | `/check-consistency [--profile all\|core\|explicit] [--strength full] [--no-seed] [--dry]` (A §6.2 step 1; I 1.3) |
| 17 | Applied | `run_gate("gate", "check-docs", "check-consistency")` before AND after (A D9; I 1.4) |
| 18 | Applied (ruling 5) | `--only <id-or-prefix>[,…]\|QUICK`, QUICK a named set (A §7.3, D14; I 1.3) |
| 19 | Applied (ruling 21) | A §12.A/B/C |
| 20 | Applied (ruling 11) | the five constants deleted from config (A §5.1 `[rubric]`/`[notation]`, D5, §5.4) |
| 21 | Applied | ledger seeding moved into PF-2 after the title → id map (I PF-2) |
| 22 | Applied | loose witnesses by `r<N>-` prefix, `env/` discarded, round 3 imports `abandoned`, `r4-architecture-03-probe.jl` placed (I 5.2) |
| 23 | Applied | `rm -rf` of untracked/ignored piles after import (I PF-6, 5.2, Phase 6); `LEG.PILES` limited to the piles the plan deletes/imports, Q12 survivors excluded (A §7.3) |
| 24 | Applied | `panel.js:88,93` (I PF-1) |
| 25 | Applied | IT 39 files; 125 promoted witnesses (I 5.2; A D17) |
| 26 | Applied | PF-3 line ranges L44–568 (+ L425–488), L571/L574–580, L653–682/L684; keep `remove_jupyter_files`/`copy_rationale_pages`/`build_examples`; `build_examples()` before the wrapper (I PF-3) |
| 27 | Applied | IT `copy_rationale_pages` (L12–24) kept; calls L305–308 removed (I 5.2) |
| 28 | Applied | source files named with real spellings `severity_recheck.js`, `rubric_audit.js`, `attack-design.js` (I 1.5) |
| 29 | Applied | `survey-checkdocs.md:104` (A D6) |
| 30 | Applied (ruling 22) | `generated = {globs = […], optional = true}` (A §5.1, §5.3, §7.3 `CFG.SURFACES`) |
| 31 | Applied | `CFG.SURFACES`: `docs_build` names `docs/make.jl` and it exists; `julia_test` contains `Pkg.test()` (A §7.3) |
| 32 | Applied | `gbg --version`, `init --dry-run`, `round compare --recorded`, `round build\|test`, `self verify`, `selftest --pinned` defined; `sync --rewrite-arg-bullets` and `calibrate rubric` removed (I 1.3, 1.6, Phase 6, Phase 8) |
| 33 | Applied (ruling 20) | `bump` writes `.gbg/scratch/bump-message.txt`, `init --migrate` writes `.gbg/scratch/commit-message.txt`; both gitignored (A D16, §4; I PF-8, 1.3, 1.7) |
| 34 | Applied | instrument `schema.json` = args + lane-file wrapper `$ref`-ing `finding.schema.json` (A D11; I 1.7) |
| 35 | Applied | "disposition record" for the hunt (A vocabulary, §6.3, §6.7) |
| 36 | Applied | classes DEAD / EMPTY / ORPHAN / TRUNCATED / REJECTED defined (A D10, §6.1; I 1.6); SHORT dropped |
| 37 | Applied | `/gbg-doctor` body is `gbg doctor` (A D6; I 1.7) |
| 38 | Applied | two-slug glob: `install` refuses a second path argument and names the right one (A D2; I Phase 3) |
| 39 | Applied | eighteen schemas incl. `lane-file`, `import`, `managed` (A D11, §3; I 1.7) |
| 40 | Applied | probe tag `v0.0.1` (a `vX.Y.Z` tag), deleted after V3, pinned from a fixture copy outside `$DEV` (I Phase 0 V3) |
| 41 | Applied | re-measure; a DROP is a finding (I PF-4) |
| 42 | Applied | CP root `Project.toml` L19–20 and `docs/Project.toml` L11 both gain a `rev` (I Phase 7; A §9) |
| 43 | Applied | `gbg init` and `--rebaseline` are the only CSV writers (A D9, §4) |
| 44 | Applied | `"$HOME/.local/bin/gbg" hook queue-guard` (A D13, §4; I 1.7) |
| 45 | Applied (ruling 3) | Phase 3 block double-quoted with exported `$DEV` |
| 46 | Applied (with attack 2.2) | "the round's existing files committed" first in §6.7's close ordering; dirty = closed/abandoned rounds |
| 47 | Applied | `PYTHONDONTWRITEBYTECODE=1` in `run_gate` (A D9; I 1.4) |
| 48 | Applied | noted as a recorded extension (A §10) |
| 49 | Applied | the config-key extension listed explicitly in §10; §1 marks the five ★ variation points |
| 50 | Applied (ruling 20) | never-economised = exactly five; the extra lanes are catalogue anchors (A D18, §10) |
| 51 | Applied (ruling 10) | no 1.1.0 (A D17, D4; I 5.1) |
| 52 | Applied (ruling 19) | Q8–Q11 deleted, decisions in §B; A §10 "Decided by the record" |
| 53 | Applied (ruling 20) | one renderer in `preflight.py`, called by `preflight` and `pass open` (A D5, §6.2 step 7, §10; I 1.3) |
| 54 | Applied (ruling 20) | `bump` writes its own template; `init` writes the migration one (A D16; I PF-8) |
| 55 | Applied (ruling 20) | §6.1's `ROUND.toml` list is complete and §10 lists the extensions over the record |
| 56 | Applied (ruling 20) | `WITNESSES.ESCALATED` prints "promote" (A §7.3, D14, §6.7) |
| 57 | Applied | noted in §10 that the record's `v1.4.0` is an example value |

## `REVIEW-attack.md` scenarios

| Scenario | Status | Where / what |
|---|---|---|
| 1.1–1.3, 1.7 | DEFEATED already; 1.7's optional `ROUND.ABANDONED` WARN added | A §7.3 |
| 1.4 | Applied | `close` runs `dismissals.js` over finding-scope entries recorded after `opened`, `reopened == []`, every instrument; `adjudicated_share` in the tally (A §6.2 step 9, §6.1, §6.5) |
| 1.5 | Applied (ruling 15 for the first half) | config_sha refusal by every verb; rescan coinciding with a post-open scan-scope entry ⇒ `closed_by = adjudicated` naming it (A §6.5, §6.1 `adjudicated_entry`) |
| 1.6 | Applied as ruling 14 | SUSPECT flag in the tally (reported, not fatal) instead of the review's UNMEASURED-as-DEAD (A §6.2 step 5, §6.4) |
| 2.1 | Applied (ruling 1) | `GBG_ROUND`; `gbg round build\|test` as the hand build (A §6.2 steps 6/10; I §B, 1.3) |
| 2.2 | Applied (ruling 13) | dirty-tree refusal on closed/abandoned rounds only; `close` requires the round's existing files committed, then writes its own (A D6, §6.2 steps 2/9, §6.7) |
| 2.3 | Applied as ruling 13 | finding scope carries `overturn_when`, no `expires` at all (not the review's "only when escalated") (A D14, §7.2, §7.3) |
| 2.4 | Applied (ruling 6) | manifests that exist; WARN when absent (A D3, §7.3) |
| 2.5 | Applied (ruling 12) | absent/unparsable/invalid ⇒ DEAD, quarantined `NN-<lane>.rejected.json` (A D10, §6.2 step 5) |
| 2.6 | Superseded by ruling 18 | the window starts at the `bump` that opens a second version, recorded in `[sweep]`, which removes the tag-to-bump lag; a fix pass longer than the window still fails `gbg fleet` — stated as a residue in A §11 |
| 2.7 | Applied | `POL.COLLAPSED` and `SCAN.REGISTER` ignore quoted words and code spans (A §7.3, §12.B) |
| 3.1 | Applied | verifiers receive finding text unabridged (A §6.2 step 7) |
| 3.2 | DEFEATED already | — |
| 3.3 | Applied as ruling 14 | salted per-round selection so a closed round's answer key is not the next round's; hats forbidden `.gbg/**` and `~/.gbg/**`; the review's hashing of contexts NOT adopted (A §6.4, D7, §6.2 step 4) |
| 3.4 | Applied (ruling 14) | manuscripts under `.gbg/scratch/<round>/`; only the seeded copy exists during the panel; unseeded regenerated at bank (A D10, §6.2 steps 3/5). V7 NOT added: ruling 14 removed every outside-project read, so the experiment has nothing to test |
| 3.5 | Applied | stated in §6.5 |
| 4.1 | Applied as ruling 6 | `gbg self verify` (Python tree hash) at every `round` verb and `gate`, exit 2 on an edited copy; `tool_tree_sha` in `ROUND.toml`; the review's `TREE.sha256`/`PIN.INTEGRITY` NOT adopted (A D3, §7.3 `PIN.SELF`) |
| 4.2 | Applied | `--regrade` only for a `bump`-moved `tool_version` or a changed `config_sha`; a changed `tool_tree_sha` under one version is "tag moved" ⇒ abandon-only (A D16, §6.2 step 9, §8 arm) |
| 4.3 | Applied (ruling 15) | `config_sha` covers config, hats, ledger; every verb after `open` refuses a change |
| 4.4, 5.4 | DEFEATED already | — |
| 5.1 | Applied | working-tree gate: open round untracked/modified AND `HEAD ≠ ROUND.toml.head` ⇒ 1; §11 states CI proves the pushed state (A §6.2 step 10, §11) |
| 5.2 | Applied (ruling 5) | QUICK set; `PIN.TREESHA` outside QUICK (A §7.3) |
| 5.3 | Applied | gate scans every round directory; open round of a disabled instrument ⇒ `CFG.VALID` FAIL (A §6.2 step 10, §7.3) |
| 6.1 | DEFEATED already | — |
| 6.2 | Applied (ruling 16) | `Witnesses.run` refuses `include(` and outside loads (A D9, §6.7; I 1.4) |
| 6.3 | Applied (ruling 16) | `reproductions/*.json` frozen at bank; BLOCKED only at bank for an ERRORED never-FAILS witness (A §6.3, §6.7) |
| 6.4 | Applied | `WITNESSES.ESCALATED`: PASS with zero assertions reads BROKEN (A §7.3, §6.7) |
| 6.5 | Applied | cross-referenced to `GBG_ROUND` (A §6.7 "under `GBG_ROUND` (`gbg round test`)") |
| 6.6 | Applied (ruling 16) | `git merge-base --is-ancestor` at close, else `--regrade` (A §6.2 step 9, §6.7) |
| 6.7 | Applied | an `escalated` disposition carries `overturn_when`; `WITNESSES.ESCALATED` prints it and re-runs on every `--deep` (A §6.3, §6.7, §7.3) |
| 7.1 | Superseded by ruling 17 | `test` is a constant not removable even by ledger, so no `AUDIT.COVERED_TEST` rule is needed (A §6.8, §5.4) |
| 7.2 | Applied (ruling 17) | constants `src, test, ext, docs, Project.toml` + `[paths]` (A §6.8) |
| 7.3, 7.4 | DEFEATED already | — |
| 7.5 | Applied (ruling 17) | `AUDIT.GAP` WARN (A §7.3, §6.8) |
| 7.6 | Applied | `severity-recheck.js` (anchor) runs before "serious" is counted in an audit (A §6.3, §6.8; I 1.5) |
| 7.7 | Applied (ruling 1) | audit bank runs the claims under `GBG_ROUND` (A §6.8; I 1.3) |
| 8.1 | Applied (ruling 13) | `expires ≤ recorded + 365 d` (A D14, §7.2, §7.3 `CFG.EXEMPTIONS`) |
| 8.2 | Applied (ruling 13) | WIRE.* strip comments/strings; "bare" defined; `TestHarness.gate()` banner + `TEST.PKG`; CI snippets grep both banners (A D13, §7.3; I 1.4, 1.7) |
| 8.3 | Applied (ruling 13) | `SHIM.HASH` requires `command -v gbg` = `~/.local/bin/gbg` (A §7.3) |
| 8.4 | Applied (ruling 13) | `MANAGED.HASH` compares against a fresh render; `managed.json` is a cache (A D13, §7.3) |
| 8.5 | Applied (ruling 13) | non-exemptable set; `target = "*"` on scope `check` refused (A D14, §7.2, §7.3) |
| 9.1, 9.2 | Applied (ruling 11) | the keys deleted; constants (A §5.1, §5.4, D5) |
| 9.3 | Applied (ruling 11) | `lanes_extra` refines; engine lanes constants (A §5.1, §5.4, §6.6) |
| 9.4 | Applied (ruling 11) | `public_surface` constant `derived` (A D9, §5.4) |
| 9.5 | Applied (ruling 11) | gate claim IS `julia_test`; `CFG.SURFACES` requires `Pkg.test()`/`docs/make.jl`; other claims existing files under `test/` (A §5.1, §7.3, §6.8) |
| 9.6 | Applied (ruling 11) | `docs.retired_claims` in §5.1 and §1 |
| 10.1 | Applied as ruling 18 | window checked by `gbg fleet` and `gbg bump`; the review's preflight `ls-remote` NOT adopted (A D4) |
| 10.2 | Applied (ruling 11) | missing `fleet.toml` path ⇒ exit 2 (A D4, D5; I 1.1) |
| 10.3 | Applied (ruling 11) | `sync`/`PIN.SOURCES` walk every sub-env `Project.toml` listing the tool (A D3, §7.3; I 1.3) |
| Vocabulary check | Applied | `candidates_found` everywhere (A §6.1, §6.3) |
| "Not configurable" contradictions | Applied | `arguments_form_min` deleted; `argcov_policy` named as the one tier exception in §5.4 and §1 |
| Anchor ambiguity | Applied | "Anchor" defined once in the vocabulary; §5.4 says "the catalogue's engine-lane anchors" (A vocabulary, D18) |

## Not applied (with reason)

- Dry-run 1's "opened-but-unbanked round is WARN for the gate": ruling 1 keeps every open round
  blocking and exempts only the rounds in `GBG_ROUND`.
- Dry-run 4's `~/.config/gbg/dev-checkout` + `$GBG_DEV_CHECKOUT`: ruling 4 fixes `~/.gbg/dev`.
- Dry-run 8's `@**References.**` paragraph marker: ruling 8 makes the heading optional (`"absent"`).
- Dry-run 10's `.gbg/hats/` home for IT's rulebook hats: ruling 9 puts them in the catalogue.
- Attack 1.6's UNMEASURED-as-DEAD: ruling 14's SUSPECT flag (reported, not fatal).
- Attack 2.3's "expires only when escalated": ruling 13's `overturn_when` on every finding-scope entry.
- Attack 2.6's window-from-tag-date: ruling 18's `[sweep]` start at the bump; residue stated in §11.
- Attack 3.3's hashed contexts in tracked artefacts: ruling 14's salted selection makes the answer key
  round-specific instead.
- Attack 3.4's V7: no outside-project read remains after ruling 14, so the experiment is empty.
- Attack 4.1's `TREE.sha256` + `PIN.INTEGRITY`: ruling 6's `gbg self verify` against the manifests.
- Attack 7.1's `AUDIT.COVERED_TEST` rule id: ruling 17 makes `test` non-removable outright.
- Attack 10.1's preflight `git ls-remote`: ruling 18 says preflight does not check the fleet.

Counts: dry-run 57/57 applied (13 of them in the ruling's form rather than the review's); attack 55
scenarios — 17 previously DEFEATED confirmed, 38 acted on (35 applied, 3 superseded by a ruling with
the residue stated: 2.6, 7.1, 3.4's V7); rulings 22/22 applied.

## Revision 3 — every item of `out/REVIEW-verify.md`

Rulings for the items that needed one are the owner's of 2026-09-07 (a)–(g), applied as given.

| Item | Status | Where / what |
|---|---|---|
| R20 PARTIAL (4.3) | Fixed | A §10 extension list gains `round` (the round id), so §6.1's complete list and §10 agree by one field, as the ruling asked |
| 4.1 id collision | Fixed (ruling a) | every rule id now `RULE.<FAMILY>.<NAME>` — §12.A rewritten (91 rows), §12.B `rule` column, D12's family list, §7.2's example (`RULE.DOC.STEER`), §5.2/§5.3 ledger ids (`RULE.API.POSITIONAL`, `RULE.DOC.STEER`, `RULE.DOC.MODULE_MAP`, `RULE.GIT.MANIFEST_TRACKED`), §9, §3 `RULES.toml`, `CFG.EXEMPTIONS`; I Q3, 5.2, Phase 6. §12.C rewritten: the families are disjoint by prefix (`RULE.`, `SCAN.`, the bare doctor prefixes, a finding id, a harness op) and the ledger resolves by prefix and nowhere else; `GIT.BRANCH`/`GIT.TRAILER` stay doctor ids, `RULE.GIT.BRANCH`/`RULE.GIT.TRAILER` are the rules. Mechanically checked: 0 bare old-family ids, 0 double prefixes, every `RULE.*` citation resolves |
| 4.2 exemptable set | Fixed | ONE set — `LEG.*`, `GIT.*`, `AUDIT.*` + the five scopes — in D14 and §7.2, each saying the other states the same; D14 notes `AUDIT.*` joined with `AUDIT.GAP` (post-dates ruling 13) |
| 4.4 `gbg probe` | Fixed (ruling b) | verb-table row: `gbg probe [--fail]`, exists for V2 and nothing else; the completeness sentence names it |
| 4.5 `round compare` | Fixed (ruling c) | ONE meaning (Step-0, re-graded vs recorded); D4's cross-version comparison is `gbg fleet --diff <consumer>:<round> <consumer>:<round>`, defined in D4 and the verb table |
| 4.6 `regrade` | Fixed (ruling d) | alias deleted from I 1.3, A §3 `rounds.py`, A §6.2 step 10; `pass open --regrade` everywhere (0 other spellings remain) |
| 4.7 `NOT-INITIALISED` | Fixed (ruling e) | D4 "The `gbg fleet` output contract": `OK` / `NOT-INITIALISED` (a consumer path with no `.gbg/config.toml`) / `BEHIND` (with `within window` / `window closed` / `no window`) / `RED`, and the exit contract 0/1/2; D14 and I 1.3 point at it; Phase 3, PF-8, Phase 7 DoDs restated in that vocabulary |
| 4.8 footers | Fixed (ruling g) | both Revision-2 footers now cite "the rows FIXLOG marks Applied (ruling N)" instead of two disagreeing lists |
| 4.9 counts | Fixed (ruling g) | ruling-21 row above corrected in place: 91 rule rows, 39 named scans + `SCAN.CUSTOM.<id>` |
| 5.1 Phase 0 unrunnable | Fixed (ruling f) | Phase 0 keeps V1; new **Phase 1.9** holds V2–V6 in the order V2, V3, V4, V5, V6 (V4 pins V3's `v0.0.1`, deleted after V4), run with `python3 "$DEV/gbg" --dev` (a throwaway `PATH` wrapper for V2's stub only), with a clean-up that collects the `0.0.1` slug so Phase 3's `install` glob names one directory |
| 5.2 Phase 2 before the shim | Fixed (ruling f) | Phase 2 states `python3 "$DEV/gbg" --dev …` as its invocation, every command spelled that way |
| 5.3 import location | Fixed (ruling f) | `round import` writes `.gbg/rounds/<round>/` (creating the directory; untracked until the migration commit) with `import.json` (§6.1 format) — defined in A §8 and the verb table; it needs no config and refuses an existing round; PF-2 finds Phase 2's rounds instead of re-importing |
| 5.4 Phase 2 DoD | Fixed (ruling f) | `compare --recorded` takes `.gbg/rounds/<round>/recorded.toml` with the four keys `findings`/`seeded`/`honored`/`adjudicated` (format, omission = UNRECORDED, the hunt/audit key mapping, exit codes in A §8); Phase 2 step 2 transcribes each round's file from the record it names; `import --empty` covers a record with no round entry |
| 5.5 PF-0/PF-1 order | Fixed (ruling f) | PF-0 = `init --migrate` + instantiate; PF-1 = secret + `sync` (which validates the config `init` wrote); PF-5/PF-6 no longer re-insert what PF-1 rendered; IT/SS/CP steps renumbered to match; `init` and `sync` rows state exactly what each renders |
| 5.6 frozen tables | Fixed (ruling f) | `gbg migrate baselines [--dry-run]` (run by `init --migrate`): a textual converter — inputs `test/method_parity.jl` (the `baseline` tuples + `MODULE_BASELINE`), `test/pass_audit.jl` (the `audit(…, Traffic(…))` rows, counts kept symbolic over `P`/`M`), `test/oracle_registry.jl` (`ORACLE_PROVENANCE`); outputs the three S-class TOMLs with their schemas; absence = skipped, unparsable = exit 2, existing TOML refused; I 1.3, 1.6, PF-0, PF-4, A §4 |
| 5.7 Phase 5.1 | Fixed (ruling f) | runs under `gbg --dev` with the dev checkout clean at the `v1.0.0` tag (`git describe --exact-match`), over the rounds Phase 2 imported, until IT is pinned in 5.2 |
| 5.8 empty round 4 | Fixed (ruling f) | `gbg round import --empty <round> --reason "…"` defined (A §8, I 1.3); 5.2 uses it for round 4 |
| 5.9 CP config | Fixed (ruling f) | new A §5.4 CP delta (modules from CP `src/` in include order, no `[paths]`, no benchmark env, `seed_rounds = false`, the one `domain_hats` entry `cloud-microphysicist` with a placeholder persona written by `init` so `CFG.HATS` is green, territories, empty `executable_claims`, `references_heading = "#14. References"`); the former §5.4 is §5.5 and its two citations moved; Phase 7 restated against it |
| 5.10 `doc-review-prev` | Fixed | Q13 in I §A (default: discard) and A §10 residual 9; PF-2 cites it |
| 5.11 `LEG.SENTINELS` | Fixed | `RULES.toml` carries a `sentinel` per rule (the first sentence of the rule's paragraph, verbatim); the check normalises whitespace, splits the block-free `CLAUDE.md` into sentences, fails on equality or a shared run of twelve words — A §7.3, §12.A intro, §3; I 1.7, PF-5 |
| 5.12 fleet contract | Fixed | as 4.7; `no window` is the stated state of a fresh dev checkout |
| 5.13 `Config.jl` reader | Fixed | `gbg config --toml` added; `Config.jl` parses it with the stdlib `TOML`; `--json` kept for humans and scripts — A D5, D9, §3; I 1.3, 1.4 |
| 5.14 snippet insertion | Fixed | three fragments per snippet with fixed insertion points (the `insteadOf` step first after `actions/checkout`, `python3 --version` next, the build/test step tee'd to `gbg-run.log` and grepped last; no checkout step ⇒ `sync` exit 2) — A §3 templates, `WIRE.CI_AUTH`; I 1.7 |

Grep pass (scripted, after the edits): 91 §12.A rows, 40 §12.B rows; every `RULE.*`, `SCAN.*` and
doctor id cited anywhere in A or I resolves to its table; every `gbg …` invocation in A or I is a row
(or a sub-verb of the `round …` row) of I 1.3; every dotted config key cited in prose is a key of
§5.1; no `round regrade`, no `config --json` as the Julia route, no `--recorded <CLOSED`, no
`PF-0 needs no secret`; the D12/§12.C wildcard families read `RULE.<FAMILY>.*`.

Counts: verify 1 PARTIAL + 9 mismatches + 12 substantive + 2 minor = 24 items, 24 fixed, 0 dismissed.

## Revision 4 — IT amendments + Python retirement (2026-09-08)

Inputs: `07-IT-amendments.md` (17 numbered amendments, owner-ordered, applied in full; its final block
lists what stays unchanged) and `06-python-retirement.md` (the owner's mapping notes; where it conflicts
with amendments (3)/(4)/(5)/(6) the amendment wins — the shim execs `julia --project="<root>/docs"` and
scans no depot slug, there is no separate `cli/` environment, the validator is a hand-ported subset
rather than JSONSchema.jl, and `consolidate.py` ships inside the tool as the one transitional file).
A = `ARCHITECTURE.md`, I = `IMPLEMENTATION.md`.

| # | Amendment | Status | Where |
|---|---|---|---|
| 1 | Name — `GBGCodingTools` stands; record `GBGInstruments` declined | Applied | A D19 (one sentence: "instrument" is the reserved house term; IT's "cover word" objection withdrawn) |
| 2 | Python retired — Julia CLI | Applied | A R7, D1 (three faces → two), D8 (retitled; `main(ARGS)::Int`, every verb a function returning the exit code, uncaught exception → 3), §3 (`gbg/` → `src/CLI/*.jl`, `scans/` → `src/Scans/*.jl`, `tree.py` → `src/TreeHash.jl` on `SHA`), §9 (validator and scan-engine rows), §10 (R7/R8 entailments), §12.B (runner column collapsed to `julia\|html`, 32 `python` cells → `julia`, completeness guard); I 1.1 tree, 1.3 (exit contract, module column, `gbgdev`), 1.4, 1.6 |
| 3 | Shim execs `--project="<root>/docs"`; `PIN.TREESHA`/`PIN.SELF` via `Pkg.dependencies()` + `is_tracking_repo && !is_tracking_path` | Applied (over 06's `<pinned>/cli` env) | A D2 (title, item 3, bootstrap, forced-by, a new dominated alternative — the slug match), D3, §7.3 rows `PIN.TREESHA`/`PIN.SELF`, §11 (the verbatim quote kept, its conclusion corrected beneath); I 1.2 rewritten, 1.3 `self verify` row, 1.4 `TreeHash.jl`, Phase 3 `install` from the pinned fixture's docs env |
| 4a | Julia startup paid once per instrument invocation; no sysimage | Applied | A D2 item 3 (pointer), D6 (the `!` block's cost), D8 dominated |
| 4b | Stop hook never starts Julia; `gbg hook queue-guard` deleted; `queue-guard.sh` rendered as class G | Applied (over 06's "PF's script stamped verbatim") | A D13, §4 (`.claude/hooks/queue-guard.sh` G, `settings.json` points at it), §5.1 `work_queue` comment, §6.2 step 10, §9 row; I 1.3 (row deleted, note after the table), 1.6 (`templates/queue-guard.sh.tmpl` row), 1.7, PF-1 (`git rm` the hand-written hook before `sync`), PF-6, the deletion list, 5.2 |
| 4c | `run_gate` gone — in-process calls; `PYTHONDONTWRITEBYTECODE`, `ENV.PYTHON`, the `python3 --version` CI step removed; banners stay | Applied | A D9 (`makedocs`, `TestHarness.gate()`, `Config`, deps), D14, §6.2 step 10, §7.3 (sets; `ENV.PYTHON` row deleted; `WIRE.CI_AUTH`), §3 templates, §4; I 1.4, 1.7, V5 |
| 5 | One validator in Julia (subset port, no JSONSchema.jl); `gbg config --toml\|--json` printers; `JSON3` declared; `julia = "1.11"` kept | Applied (over 06's JSONSchema.jl option) | A D5 (title, choice, dominated), D9 deps; I 1.1 `Project.toml` (`SHA`, `Dates`, `JSON3`, `Gumbo`, `AbstractTrees` with UUIDs verified against the local registry), 1.3 `config`/`schema` rows and the note after the table, 1.4 `Config.jl` |
| 6 | `consolidate.py` the ONE transitional file, inside the tool; Gumbo + AbstractTrees port; byte comparison on a real PF and IT build is the acceptance test; deleted in the same commit | Applied | A D1, D8, §3 (`src/CLI/consolidate.py`, `HtmlWalker.jl`), D9 deps; I 1.1 tree, 1.4 `HtmlWalker.jl`, 1.6 transitional row (STEP 1 / STEP 2 / ACCEPTANCE), Phase 1 DoD `test ! -e src/CLI/consolidate.py` |
| 7 | Workflow scripts unchanged | No change needed | A D7, I 1.5 untouched |
| 8 | `.gbg/rounds/` the SOLE closure record; IT's register/marker/`lint_review_closure` retired; `ROUND.DIR` stated as the vacuous-pass closure; `hooks.work_queue` optional, off, `sh` body; `adjudicated.md` withdrawn | Applied | A D10 (choice), §6.2 step 10 (`ROUND.DIR` sentence; hook sentence), §9 `WORK_QUEUE` row |
| 9 | `[exemption.match]` on `scan\|lint\|policy\|harness`; refines, never silences; `EXEMPT.BROAD` WARN | Applied | A D14, §7.2 (a third ledger entry with a `match` table + the paragraph), §7.3 (`CFG.EXEMPTIONS`, new `EXEMPT.BROAD` row), §8 arms; I 1.7 schemas, 1.8 arms |
| 10 | `CFG.TORN` in `QUICK`, non-exemptable, every `gbg round` verb | Applied | A §6.2 steps 2 and 5, §7.3 (new row, `QUICK` set), §8 arms; I 1.3 `round` row, 1.8 arms |
| 11 | Docs build named the per-push, harness-independent enforcement point | Applied | A D9 `makedocs` bullet (one sentence citing `RULE.GIT.CI_MANUAL`); I 1.4 |
| 12 | Verdict vocabularies kept; the adoption precondition stated | Applied | A §6.3 (paragraph after the table) |
| 13 | `LEG.SENTINELS` softened: exact match FAIL, twelve-word run WARN, quotes and fences ignored | Applied | A §7.3 row, §8 arms; I 1.8 arms |
| 14 | Seed catalogues move to the consumer's `.gbg/seeds.toml` (class C, schema-validated, `seed_catalog_sha` as now); only `fixture.toml` stays | Applied | A §1 (common/varies), §3 (`catalog/seeds/fixture.toml`), §4 (`seeds.toml` C), §5.1–§5.4 (`seed_catalog` = a path), §6.4, §7.3 `CFG.SEEDS`, §8 (the fixture's `seed_catalog`), D16 (MAJOR scope); I 1.1, 1.3 `init`/`seed` rows, 1.6 `Seed.jl`, 1.7, PF-0, 5.1, 5.2, Phase 6, Phase 8 |
| 15 | Migration order kept; effort floor 17–23 sessions stated | Applied | A D17 |
| 16 | Q1/Q2 are consumer rulings, not tooling; removed from the checklist; never bundled | Applied | A §9 (two rows reclassified, legend gains `consumer ruling (not tooling)`), §10 residuals 1–2; I §A (rows removed, note added), 5.2 ("not applied here") |
| 17 | `git add -u` plus new files by name, never `-A` | Applied | I §B; PF-8 stages that way |

**Python retirement sweep (the ~90 sites).** Classes and counts, both documents: `python`/`python3`
statements → 0 positive mentions (every survivor is a negation — "no python step", "no `python3`
needed" — or the transitional `consolidate.py`); `.py` module names as TARGETS → 0 (every `.py`
that remains is a SOURCE citation of an old script being ported, or a file in a deletion list);
`run_gate` → 0 outside the revision notes; `gbg/` (the Python tree; `.gbg/` excluded) → 0;
`PYTHONDONTWRITEBYTECODE`, `ENV.PYTHON`, `tomllib`, `__main__` → 0; `hook queue-guard` → only the
sentences saying it is deleted; `catalog/seeds/GBG` → 0; `python3 "$DEV/gbg" --dev` → `gbgdev`
(6 sites). §11's verbatim record quote ("hence the Julia-free shim") is kept as a quote with its
correction stated beneath it, per the revision-note convention.

**Verified after the edits (scripted):** every `old` span matched exactly once (`rev4_arch.py`,
`rev4_impl.py`, two spans corrected on the second run); every id cited in the new rows — `CFG.TORN`,
`EXEMPT.BROAD`, `LEG.SENTINELS`, `PIN.TREESHA`, `PIN.SELF`, `CFG.SEEDS`, `CFG.EXEMPTIONS`,
`WIRE.CI_AUTH`, `ROUND.DIR` — resolves to a §7.3 row; every verb cited in I is a row of I 1.3 (the
`hook` row is gone and no caller of it remains; `selftest --pinned`'s fixed directory is stated in its
row so Phase 3 introduces no new flag); every module named in I 1.6's target column exists in A §3's
tree; the `seed_catalog` key keeps its name and becomes a path in all four consumer deltas and the
fixture.

Counts: 17 amendments — 16 applied, 1 no-change (7); 0 dismissed.

## Revision 5 — IT corrections A–D (2026-09-08)

Input: `08-IT-corrections.md` (four corrections received after IT read Revision 4; (A) and (B) retract
parts of IT's own amendments (4b) and (10) in `07-IT-amendments.md`; its closing paragraph lists what
IT verified sound and kept). Applied exactly as stated; nothing else changed. A = `ARCHITECTURE.md`,
I = `IMPLEMENTATION.md`.

| Item | Status | Where / what |
|---|---|---|
| A — Stop hook: PF's `queue-guard.sh` verbatim; guards `WORK_QUEUE.md` `- [ ]` items; `stop_hook_active` kept; never reads `.gbg/rounds/`; never starts Julia; still a generated-managed `sh` file rendered by `sync` under `hooks.work_queue = true`; "the hook guards the work queue; the gate guards the rounds; the two never overlap" stated once (D13); (8b)'s sentence: never reads `WORK_QUEUE.md` for CLOSURE, the hook may read it | Applied (retracts Revision 4's (4b) body) | A D13 (body rewritten; the overlap sentence and the two reasons the round-grepping hook was wrong), D10 (the (8b) sentence), §4 row, §5.1 comment, §6.2 step 10, §9 `WORK_QUEUE` row, Revision 4 note marked; I 1.3 `sync` row + the note after the table, 1.6 template row, 1.7 templates, PF-1, the deletion list |
| B — `CFG.TORN` out of `QUICK`: exit 2 in `gbg preflight` and every `gbg round` verb only; the docs wrapper and the test gate do not run it; "fails to parse" dropped (`CFG.VALID`); non-exemptable kept | Applied (retracts Revision 4's (10) "in `QUICK`") | A D9 `makedocs` bullet (`doctor(:QUICK)` glossed as a set without `CFG.TORN`), §6.2 step 2, §7.3 `QUICK` set (`CFG.TORN` excepted, listed among the never-in-`QUICK` ids with the reason) and the `CFG.TORN` row (parse clause removed; callers named; fail column "from `preflight` and every `round` verb"), §8 arms (the same tree passes the wrapper and the gate), Revision 4 note marked; I 1.3 `preflight` row (+ `CFG.TORN`) and `round` row (its only callers), 1.4 (`QUICK` excludes `CFG.TORN` at both in-process callers), 1.8 arm, Phase 4 (one sentence after the table: PF-3/PF-4 run with the uncommitted sub-env `Project.toml` files) |
| C — `Documenter` a weak dependency: `[weakdeps]` + `[extensions] GBGCodingToolsDocumenterExt = "Documenter"`, `ext/GBGCodingToolsDocumenterExt.jl` defining `GBGCodingTools.makedocs(cfg; kwargs...)`, the main module declaring `function makedocs end`; compat kept; `Gumbo`/`JSON3` hard; `WIRE.MAKEDOCS` unchanged | Applied | A D9 dependency bullet (the three costs of a hard dependency stated) and `makedocs` bullet, §3 tree (`Project.toml` line, module line, `DocLints.jl` line, new `ext/` entry); I 1.1 `Project.toml` (+ a paragraph) and tree, 1.4 `makedocs` and `DocLints.jl` bullets, 1.7 fixture docs-environment note, Phase 7 compat sentence |
| D — `[exemption.match]`: `arg_type` = declared type of the MATCHED ARGUMENT, `<:`, reflection scans only, a text scan REFUSES (exit 2 at `CFG.EXEMPTIONS`), never ignores; `symbol` = regex over the owning binding's name; every engine with a trigger population (`Reflection.argcov` included) applies the predicate and reports the population; the example replaced | Applied | A §7.2 third example (`id = "SCAN.ARGCOV"`, `scope = "scan"`, `target = "src/Interpolation.jl"`, `arg_name`/`arg_type = "Integer"`/`symbol = "^(LalescuSpline\|LagrangeSpline)$"`; `AbstractSplineScheme` gone) and the paragraph after it, D14, §7.3 `CFG.EXEMPTIONS` and `EXEMPT.BROAD` rows, §8 arms; §12 lists no match keys (unchanged); I 1.7 schema bullet, 1.4 `Reflection` clause, 1.8 arm |

**Verified after the edits (scripted, `rev5.py`):** every `old` span matched exactly once; the greps
the correction asked for — `ROUND.toml` within reach of `queue-guard`, `CFG.TORN` beside `QUICK`,
`Documenter`, `arg_type`, `AbstractSplineScheme` — leave no stale text outside the revision-history
notes, where Revision 4's two retracted items are marked inline rather than rewritten.

Counts: 4 corrections — 4 applied; 0 dismissed. Pre-edit copies: `ARCHITECTURE.rev4.bak`,
`IMPLEMENTATION.rev4.bak`, `FIXLOG.rev4.bak`.

## Revision 6 — the tool as its own consumer (2026-09-09)

Input: `09-revision6-self-application.md` (eight owner-ordered rulings). Applied exactly as stated;
entailments the rulings force but do not spell are marked *(entailment)*. A = `ARCHITECTURE.md`,
I = `IMPLEMENTATION.md`.

| Ruling | Status | Where / what |
|---|---|---|
| 1 — the tool is its own fifth consumer: `.gbg/config.toml` at the root with `[tool] version = "dev"` (the dev pin legal in the fixture AND at the root), `[package] name = "GBGCodingTools"`, modules, the four surfaces, all four instruments, `seed_rounds = false`, ONE domain hat `tooling-maintainer`; ledger, hats, rendered policy, tracked rounds; the doctor and fleet treat the root as a consumer pinned `dev`; the fleet's fifth row (`fleet.toml` `[[consumer]] name = "GBGCodingTools", path = "."`); the dev-round rule extended — a round opened at a clean released tag (`git describe --exact-match --dirty`) is a normal closable round, stated as D16's extension | Applied | A head paragraph + `Consumer` vocabulary; D2 item 3 (the dev pin's second legal place; the cross-reference to D16); D4 (the fifth row's pin/detail/status, excluded from newest-pin and `BEHIND`); D10, D14, D17 (the root named wherever "a consumer" is said; the tool's own config is not a consumer copy); D15 (retitled; the dev pin's two legal places; the "tool as its own fifth consumer" paragraph; the R1 clause in Forced by); D16 (the extension; *(entailment)* `tool_tree_sha` of a clean-tag round at the root is the tag's tree, re-read from the tag, or every fix commit would read as "tag moved"); §3 tree (`.gbg/` at the root, `fleet.toml` line); §4 (the footprint sentence); **§5.6 new** (the tool's own config delta — *(entailment)* the keys the ruling leaves unnamed take the values stated there, notably `[paths]` covering the instrument corpus, `argcov_policy = "gate"` for a fresh corpus, and `history_exempt` anchored on a `## Revision history` heading 1.10 adds, an anchor needing exactly one match); §7.3 `PIN.CONFIG`/`PIN.SOURCES`/`ROUND.DEV` reworded; §10, §11 (the residue: a round on the tool grades a moving instrument); I 1.1 `fleet.toml`, 1.3 `fleet` row, Phases 3/4/6/7 counting the fifth row |
| 2 — the Documenter site: `docs/Project.toml` (`[deps] Documenter, GBGCodingTools`, `[sources] path = ".."`), `docs/make.jl` through the mandatory wrapper (`WIRE.MAKEDOCS` applies to the tool), the thirteen pages (`guide/verbs.md` from the `src/CLI/` docstrings via `@docs`, `guide/doctor.md` from the doctor table, `architecture.md` copied at build), `docs.yml` on push to `master`, private Pages enabled by the owner in Phase 0, the docs build as the tool's per-push enforcement point | Applied | A D9 (the wrapper bullet's tool sentence; the new "tool's own Documenter site" bullet), §3 tree (`docs/{ARCHITECTURE.md,Project.toml,make.jl,prose_shape.csv,src/…}`, `docs.yml`; `ci.yml` → `CI.yml` to match `WIRE.CI_AUTH` *(entailment)*); I 1.1 tree, 1.10 items 2 and 5, Phase 0 (the owner action), V7 |
| 3 — every public binding a rubric docstring (`main`, every verb, `makedocs`, every `TestHarness`/`Reflection`/`Witnesses`/`Config` export, every schema struct), module docstrings as maps, `checkdocs = :exports` and `doctest = true`, the tool's `CLAUDE.md` = managed block + design sentence, freeze rule, release checklist | Applied | A D9 (the docstring sentences), D12 (the tool's `CLAUDE.md`); I 1.4 (the docstring bullet), 1.10 items 1 and 3 |
| 4 — enforced self-checks: (a) every docs build runs the quick doctor, the hard scans and the gate through the wrapper; (b) `runtests.jl` calls `TestHarness.gate()` and `run_regressions(@__DIR__)`; (c) `gbg release` refuses unless, at a clean tree, `Pkg.test()` green, the docs build exit 0, `gbg doctor --deep` green, no open round, CHANGELOG entry present, tag absent; (d) CI runs `Pkg.test()` on 1.11 and 1.12 AND the docs build, no consumer checked out | Applied | A D9 (a, d), D15 (the enforced list), D16 (the release preconditions), §8 (restated; "not selftest arms"), §3 tree (`CI.yml`, `test/regressions/`); I 1.3 `release` row, 1.10 items 4–5, Phase 3's block and comment, Phase 1's definition of done |
| 5 — the four instruments run on the tool; stubs rendered by `gbg sync` into the tool's `.claude/skills/`; rounds under its `.gbg/rounds/`; Phase 1's definition of done gains one `/check-docs` round over the tool's docs, closed, before v1.0.0; §8's list says the docs build green is a release precondition, not a selftest arm | Applied; the collision it raised is RE-RULED by Revision 7 | A D6, D15, §8; I 1.10 item 7 and the definition of done. **Collision:** ruling 1 makes a dev-stamped round closable only at a clean released tag and 4(c) has `release` refuse an open round, so before the first tag no tool round can close. Revision 6 resolved it by an `abandon` listing no open id; that resolution is deleted everywhere and replaced by Revision 7's prerelease tag — the round is opened at the clean `v1.0.0-rc.1` tag and CLOSED (see Revision 7 below) |
| 6 — bootstrap circularity, stated once: the docs env loads the working tree by path; the shim, inside the tool repo, execs `julia --project=docs` like anywhere else, so the tool's own `gbg` calls run the working tree (≡ `--dev`); `PIN.*` accept `dev` at the root and record `dev+<sha>[-dirty]` | Applied | A D2 item 3 ("Bootstrap circularity, stated once"; the shim's ordinary route at the root — *(entailment)* the dev-pin walk-up applies to an ENCLOSED consumer only; at the root the walk's first step is the tool), D2 bootstrap paragraph (`fleet`/`release` from the dev checkout now go through its docs environment), D9 pointer; I 1.2 step (4) |
| 7 — doctor additions `SELF.CONSUMER` (the root's valid config with `version = "dev"`; only the root and the fixture may carry `dev`) and `SELF.DOCS` (`--deep`: the tool's docs build exits 0); the fleet row | Applied | A §7.3 (`SELF.CONSUMER` in `QUICK`, non-exemptable; `SELF.DOCS` among the `--deep` ids — *(entailment)* it also asserts the docs environment resolved the tool by path, ruling 6 made checkable, so it is not `BUILD.DOCS` under a second name), D14 and §7.2 (`SELF.*` in the one non-exemptable set), §12.C (the `SELF` prefix), D4 (the row); I 1.8 arms, 1.10 item 6 |
| 8 — IMPLEMENTATION: Phase 1.10; Phase 0's Pages enablement + V7; Phase 1's definition of done; Phase 3's refusal list; Phase 8's note; §A gains Q14 only if a visibility choice exists | Applied | I §A (Q14 — the private repository forces the choice), Phase 0 (owner action, V7 row, the V1-only sentence, the definition of done), 1.1, 1.2, 1.3, 1.4, 1.8, **1.10 new**, Phase 1's definition of done, Phase 3, PF-8, Phases 6–8, the Revision 6 note |

**Verified after the edits (scripted, `rev6.py`):** every `old` span matched exactly once; every doctor
id cited in either document resolves to a §7.3 row (`SELF.CONSUMER`, `SELF.DOCS` included); every verb
used in I is a row of I 1.3 (`round abandon`, `gate`, `scan docs`, `doctor --deep`, `init`, `sync`,
`release` — no new verb); every path the rulings name is in the §3 tree (`docs/{make.jl,Project.toml,
src/…}`, `.gbg/` at the root, `docs.yml`, `CI.yml`, `.claude/skills/`, `CLAUDE.md`, `test/regressions/`);
the identifiers `SELF.CONSUMER`, `SELF.DOCS`, `tooling-maintainer`, `seed_rounds`, `dev+<sha>[-dirty]`,
`WIRE.MAKEDOCS`, `checkdocs = :exports`, `doctest = true` are spelled identically everywhere; `ci.yml`
survives only in the revision notes that record its renaming. D19 and §0 are untouched; two spans
were rewrapped and one anchor named on a second pass.

Counts: 8 rulings — 8 applied (one with a named collision, re-ruled by Revision 7); 0 dismissed. Pre-edit copies:
`ARCHITECTURE.rev5.bak`, `IMPLEMENTATION.rev5.bak`, `FIXLOG.rev5.bak`.

## Revision 7 — the prerelease tag (2026-09-09)

Input: one owner ruling replacing Revision 6's collision resolution (row 5 above; I 1.10 item 7).
Entailments the ruling forces but does not spell are marked *(entailment)*. A = `ARCHITECTURE.md`,
I = `IMPLEMENTATION.md`.

| Ruling | Status | Where / what |
|---|---|---|
| The tool's own instrument rounds before a release open at a PRERELEASE TAG: `gbg release <ver>` also accepts `<ver>-rc.<n>` (tags `v1.0.0-rc.1`, …), running the same refusals EXCEPT the open-round refusal and the closed-`/check-docs`-round precondition; a round opened at the tool root with a clean tree at an rc tag is a normal, closable round whose stamp names the rc tag as the instrument that measured it; the final `gbg release 1.0.0` requires that round closed (honored/adjudicated, never abandon) and refuses any open round; "abandon listing none" deleted everywhere; the rc rule stated in D16 beside the clean-tag extension, in I 1.3's `release` row, 1.10 item 7 and Phase 3; semver: an rc tag is never a consumer pin (`PIN.SOURCES` refuses a `-rc.` rev in a consumer other than the tool itself) | Applied | A D16 ("Release preconditions" gains the closed-round precondition; new "The prerelease form" sentence beside "The dev-round rule, extended", whose released tag now reads "a prerelease `vX.Y.Z-rc.<n>` included"; the stamp sentence); D15 (the first round "opened at the clean prerelease tag `v1.0.0-rc.1` and CLOSED"); §7.3 `PIN.CONFIG` ("never a prerelease"), `PIN.SOURCES` (the `-rc.` refusal outside the tool root, in the fail column too), `ROUND.DEV` (the rc tag named) — *(entailment)* `PIN.CONFIG` is reworded because "a released tag `vX.Y.Z`" must be read as excluding the rc form, not silently; §8 (the restated preconditions, the prerelease form, the first round "opens at the clean `v1.0.0-rc.1` tag and closes"; *(entailment)* a selftest arm — a throwaway repository tagged `v9.9.9-rc.1`, clean, closes and is stamped with that tag — or the closable rc round would be the one clean-tag behaviour without an arm); §11 (the residue names the prerelease tag as the reason); the Revision 7 note. I 1.1 (`CHANGELOG.md` gains the `## 1.0.0-rc.1 — <date>` entry the rc release requires — *(entailment)* of "the same refusals", which include the CHANGELOG-entry refusal); 1.3 `release` row (the rc form; the closed-round precondition); 1.8 (the rc arm); 1.10 item 7 (rewritten: commit, `gbgdev release 1.0.0-rc.1`, the round at the clean rc tag, closed by `gbgdev round close`, never `abandon`; the optional `1.0.0-rc.2`) and item 8 (commits twice); Phase 1's definition of done (round closed, rc tag on GitHub); Phase 3 (the opening paragraph, the block's comment); the Revision 6 note marked superseded; the Revision 7 note |

**Verified after the edit (scripted, `rev7.py`; the consistency re-run is `out/REVIEW-final.md`):** every
`old` span matched exactly once; the phrases "listing no open id", "lists no open id" and "abandon that
lists no open id" occur in neither A nor I outside the sentences that record their retirement; every
`gbg release` spelling used is the 1.3 row's (`<ver>` or `<ver>-rc.<n>`); no new doctor id, path, rule id
or scan id was introduced.

Counts: 1 ruling — 1 applied; 0 dismissed. Pre-edit copies: `ARCHITECTURE.rev6.bak`,
`IMPLEMENTATION.rev6.bak`, `FIXLOG.rev6.bak`.
