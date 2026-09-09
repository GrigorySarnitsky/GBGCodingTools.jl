# Attack review of ARCHITECTURE.md + IMPLEMENTATION.md (attack-design lens, round 3)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.


Method as in `round2-measurement.md`: per requested area, a concrete action sequence by a lazy or mistaken session
(EVADE) or a legitimate workflow (BLOCK), tested against the documents AS WRITTEN. Attacks already answered in
`04-decision-record.md` / `round2-measurement.md` (A1, A3, A5-residue, A9, A10, A12, A14, S1, S2, W1, W4, W5, `test`
constant, `previously_worked` enum) are re-run and recorded DEFEATED with the section that defeats them. `§n` =
ARCHITECTURE.md; `I §n` = IMPLEMENTATION.md. Every EVADES / BLOCKS-WRONGLY carries the minimal textual fix.

## 1. The closure gate reporting closure falsely

1.1 **Copy-forward verdicts** (pass-2 act files copied into pass 3, eleven edited to HONORED). `pass.toml` nonce
(§6.1); `grade` REJECTS a mismatch (§6.2 step 8). **DEFEATED.**

1.2 **Session-written verdict files** with the right nonce. The forgery residue, stated in §6.4/§11. **DEFEATED**
(honest limit).

1.3 **PARTIAL laundering** (act HONORED + state PARTIAL). §6.5: `honored` needs state ∈ {ABSENT, NOT-A-DEFECT};
PARTIAL never closes. **DEFEATED.**

1.4 **Wholesale adjudication.** 19 open ids; the session appends 19 ledger entries `scope = "finding"` with a 40-char
boilerplate reason; `close` snapshots them into `closed_by.adjudicated` (§6.2 step 9). Only a SEEDED id is refused
(§6.5). Bug-hunt runs `dismissals.js` (default UNSAFE) over its refusals before close (§6.7); the doc instruments have
no dismissal auditor, though D18 lists "dismissal auditors" as never-economised. Diff-visible, gate-invisible.
**EVADES.** Fix (§6.2 step 9): `close` runs `dismissals.js` over every finding-scope entry recorded after `opened`,
`reopened == []` required, for every instrument; `tally.json` reports the adjudicated share beside `demoted_by_rule`.

1.5 **`rescan` closed by narrowing.** Lane `00-scans` banks a hard `TEX.LEFTRIGHT` hit; the session adds a ledger entry
`scope = "scan"` (§5.4 permits silencing) or narrows `surfaces.src`; `grade` re-runs the scan, it no longer fires,
`closed_by = rescan` (§6.5). `config_sha` is stamped (§6.1) but no verb refuses a changed one. **EVADES.** Fix: every
`gbg round` verb after `open` exits 2 when `config_sha` ≠ stamped; a `rescan` closure coinciding with a scan-scope
ledger entry recorded after `opened` is written `closed_by = adjudicated` naming the entry.

1.6 **The UNMEASURED hat counts as live.** Economy `cold-reader` returns `checked: ["docs/build/index.html"]`, zero
findings, zero of the 4 seeds on its substrate. DEAD = zero findings AND empty `checked[]` (§6.1) — self-report; recall
is only PRINTED at bank (§6.2 step 5). The one non-self-reported liveness signal (§6.4's own justification) never
reaches `dead_lanes[]`. **EVADES.** Fix (§6.2 step 5): a hat with ≥ 2 seeds on its substrate and zero matches is
UNMEASURED, banked like DEAD (exit 1, nothing frozen; `rerun` accepts it once; twice → abandon-only).

1.7 **Abandon as shipping** (`abandon --reason "plateau"` everywhere). The enumerated open ids in the diff are the
stated decision surface (D10). **DEFEATED** (optional `ROUND.ABANDONED` WARN listing carried ids).

## 2. A gate wrongly blocking a legitimate round

2.1 **The build/test deadlock.** `preflight` opens the round (§6.2 step 2) BEFORE `prepare` runs `docs_build`
(step 3) and `pass open` "regenerates the manuscripts after a fresh build" (step 7). `docs_build` calls
`GBGCodingTools.makedocs`, which runs `gbg gate check-docs check-consistency` first (D9, step 10): "any open round →
1", `run_gate` `error()`s, `prepare` exits 2. Bug-hunt: `close` needs `Pkg.test()` green (§6.7) while `runtests.jl`
calls `TestHarness.gate()` → the open hunt → red; `gbg audit-changes bank` runs `executable_claims.gate` under the
open audit round → recorded exit 1 (§6.8). The policy's "verify a doc edit by BUILDING the page" is unfollowable for
the whole fix pass. **BLOCKS-WRONGLY.** Fix (§6.2 step 10, D9): the CLI exports `GBG_ROUNDS_IN_PROGRESS=<ids>`
whenever it invokes `docs_build`/`julia_test` (`prepare`, `pass open`, `close`, `audit-changes bank`); `gbg gate`
treats exactly those rounds as expected-open; a hand build during a fix pass is `gbg round build|test <round>`; CI
never sets it, so the commit/CI gate stays fail-closed.

2.2 **"Dirty `.gbg/rounds/`" refuses the audit the hunt needs.** Hunt close requires an audit round (§6.7);
`preflight` refuses on a dirty rounds dir (step 2); the hunt's directory is untracked until committed (the CLI never
`git add`s, D10). Step 9's "no uncommitted change under the round directory" is also unsatisfiable at the instant
`close` writes into it. **BLOCKS-WRONGLY.** Fix: dirty = uncommitted changes under a CLOSED/ABANDONED round;
`close` requires the round's existing files committed, then writes its own, which the session commits.

2.3 **Finding-scope expiry fails the doctor on closed rounds.** `expires` REQUIRED on every entry, expired → FAIL
(§7.2, §7.3); the quick doctor runs inside every `run_gate` (D9). A year after an adjudicated doc round every docs
build and preflight fails on an entry with nothing to decide (A14 relocated to the doctor). **BLOCKS-WRONGLY.** Fix:
finding-scope entries carry `expires` only when the disposition is `escalated`; `EXEMPT.*` skips the rest.

2.4 **`PIN.TREESHA` needs three manifests; `test/` never has one** (D2, verified), `benchmark/` is gitignored (§4).
Undefined with manifests absent; if absent = FAIL, every clone is red. **BLOCKS-WRONGLY** (ambiguity). Fix: "over
the manifests that exist, ≥ 1 required".

2.5 **A schema-invalid lane file can neither bank nor rerun.** `bank` validates; `rerun` accepts only lanes
classified DEAD (§6.2 step 5); malformed JSON is neither. **BLOCKS-WRONGLY.** Fix: absent, unparsable or invalid ⇒
DEAD (file quarantined as `NN-<lane>.rejected.json`).

2.6 **7-day fleet window vs a fix pass spanning sessions.** `bump` refused while a round is open (D4); `ROUND.OPEN`
allows multi-session passes (§7.3); on day 8 `gbg fleet` FAILS a mandatory state. **BLOCKS-WRONGLY** (mild). Fix
(D4): the window counts from max(tag date, close of rounds open at tag time).

2.7 **`POL.COLLAPSED` fails on prose quoting the banned word** ("never 'knob'" in PF's kept paragraphs). **BLOCKS-WRONGLY**
(mild). Fix: ignore quoted and code spans.

## 3. Seeded findings

3.1 **Real defect co-quoted with a seed.** `seeded` closure needs state ∈ {ABSENT, NOT-A-DEFECT} on the real tree
(§6.5); the real claim returns PRESENT. **DEFEATED** (state in step 7 that the verifier gets the finding text
unabridged).

3.2 **Ledger title leak.** Titles only; seeded ids refused entry (§6.5, §7.2). **DEFEATED.**

3.3 **The answer key persists ACROSS rounds, tracked.** `ground_truth.json` (`page`, `original_context`,
`mutated_context`) and `findings.json` (`seeded`, `seed_class`, `locations`) of every closed round are tracked (§6.1,
D10); the catalogue is deterministic and reused (§6.4). Only the VERIFIERS are forbidden `.gbg/**` (§6.2 step 7);
nothing forbids the panel hats, and `grep -rl 2012 .gbg/rounds` reads as diligence. §11 states the mid-round residue
only. **EVADES.** Fix: hats forbidden `.gbg/**` and `~/.gbg/**` as the verifiers are; a closed round's
`ground_truth.json` stores sha256 of the contexts (plaintext under `~/.gbg/state/`); `seed_class`/`locations` of
seeded findings hashed likewise in the frozen `findings.json`.

3.4 **Manuscripts outside the project.** `prepare` writes what the hats read to `~/.gbg/state/…` (§6.2 step 3) —
outside the working directory, where D6's own argument says a `Read` prompts; and the UNSEEDED manuscript sits beside
the seeded one for a one-line `diff`. **BLOCKS-WRONGLY** (platform; no I §Phase 0 row). Fix: manuscripts under
`.gbg/scratch/<round>/`; during the panel only the SEEDED one exists, the unseeded regenerated at `bank`; add V7: a
Workflow subagent `Read` of a `~/.gbg/…` path with no prompt.

3.5 **A seeded id wrongly graded PRESENT** — no fix, no adjudication. Another pass re-grades it (loop 6–8).
**DEFEATED** (say so in §6.5).

## 4. A mid-round instrument change going unnoticed

4.1 **`chmod +w` and edit the pinned copy** (`demote.py` so `[{surface: ""}]` counts). `close` checks `tool_rev`
"unchanged since open" (§6.2 step 9) — read from the manifest/`Project.toml`, untouched by an edit; `PIN.TREESHA`
compares manifests to each other and to the directory name; `SHIM.HASH` hashes the shim only. Nothing hashes the
pinned tree — A5's `M` case, "read-only by convention". **EVADES.** Fix (§7.3, §6.2): `gbg release` ships
`TREE.sha256`; quick check `PIN.INTEGRITY` re-hashes the pinned copy against it; every `gbg round` verb runs it
(exit 2); `tool_rev` is that computed hash, re-verified at `close`.

4.2 **Re-tag laundered through `--regrade`.** `git tag -f v1.0.0` on an edited checkout, re-instantiate. `close`
sees `tool_rev` changed → exit 2 → `pass open --regrade` (§6.2 step 9, D16) proceeds: one version string, two trees.
**EVADES.** Fix (D16): `--regrade` only when `tool_version` changed via `gbg bump`; a changed `tool_rev` under an
unchanged version is "tag moved" → abandon-only.

4.3 **Consumer inputs edited mid-round** (an anchor persona softened between a DEAD bank and `rerun`; surfaces
narrowed, 1.5). `config_sha` has no consumer. **EVADES.** Fix: `config_sha` covers `config.toml`, `hats/*.toml` and
the non-finding ledger entries; every verb after `open` refuses a change.

4.4 **`--dev` rounds.** Unclosable except by abandon (D2); `ROUND.DEV` (§7.3). **DEFEATED.**

## 5. Fresh clone / CI passing vacuously

5.1 **Fixes pushed, round not.** The CLI never stages (D10); `git commit -am` commits the fixes and skips the
untracked round; push. `Enteropia` and CI see no round: vacuous while the pass is half done. **EVADES.** Fix (§6.2
step 10): in a working tree (not CI) `gbg gate` exits 1 when an open round is untracked/modified AND `HEAD ≠
ROUND.toml.head`; §11 states that CI proves only the pushed state.

5.2 **The quick doctor inside `run_gate` on a runner.** `ENV.SHIM`, `SHIM.HASH`, `PIN.TREESHA` ("the shim-selected
directory"), `GIT.BRANCH` (tag/PR checkouts are detached) all FAIL (§7.3); `--only QUICK` (I §1.4) is undefined.
**BLOCKS-WRONGLY.** Fix (§7.3): QUICK = PIN.CONFIG, PIN.SOURCES, PIN.NOT_DEV, CFG.*, EXEMPT.*, WIRE.*, MANAGED.*,
POL.*, ROUND.*; ENV.*, SHIM.*, GIT.*, PIN.TREESHA are host checks; `PIN.TREESHA` resolves against `pkgdir` when no
shim exists.

5.3 **Disabling an instrument hides its open rounds** if the gate scans only enabled ones. **EVADES** (ambiguity).
Fix: the gate scans every round directory; an open round of a disabled instrument is `CFG.VALID` FAIL.

5.4 **`rm -rf` an uncommitted round.** The A15-class residue. **DEFEATED** (stated).

## 6. The bug-hunt witness lifecycle

6.1 **Weakened witness.** Promoted body hash-equal to the bank-time body (§6.7). **DEFEATED.**

6.2 **Weakened through an included helper.** The witness `include("common.jl")` for its tolerance; the fix loosens
`common.jl`; body unchanged. Only "no `..`-hop paths" is required. **EVADES.** Fix (§6.7): `Witnesses.run` refuses
a body containing `include(` or a `using`/`import` outside the package, `Test` and stdlib.

6.3 **REPRODUCED relabelled BLOCKED after bank.** Move a hard witness to `witnesses/blocked/` with `# blocked:`,
edit `reproductions/<id>.json`; `confirmed` shrinks; the arithmetic holds. Bank freezes witness hashes, not the
reproduction verdicts. **EVADES.** Fix: `bank` freezes `reproductions/*.json` (sha in `ROUND.toml`); BLOCKED is
assignable only at bank to a witness that ERRORED and was never observed FAILS; a bank-time failing witness ends
promoted, escalated or refused.

6.4 **Escalated witness "fixed incidentally" by a skip.** A device-guarded witness passes with zero assertions on a
CPU host; `--deep` promotes. `Witnesses.run` carries PF's `!asserted` guard (I §1.4). **DEFEATED**, but §7.3
`WITNESSES.ESCALATED` should say "PASS with zero assertions reads BROKEN".

6.5 **promote → audit → close; `base == ROUND.head`, `head == HEAD`.** Stated (§6.7). **DEFEATED** in ordering —
unexecutable under 2.1 (`Pkg.test()` red while hunt and audit are open); cross-reference 2.1's fix.

6.6 **`ROUND.head` no longer an ancestor of HEAD** (a rebase mid-fix); `git diff` still runs. **EVADES** (minor).
Fix: `close` requires `git merge-base --is-ancestor ROUND.head HEAD`.

6.7 **Escalations never age.** `WITNESSES.ESCALATED` fails only on PASS/BROKEN. As ledger dispositions (§6.3) they
carry `expires` under 2.3's split, forcing a decision. **DEFEATED** once 2.3 lands.

## 7. The audit-changes gate

7.1 **`test/` dropped.** Constant, removable only by ledger entry (§6.8). **DEFEATED** — but no id names it, so the
entry is unwritable; add `AUDIT.COVERED_TEST` to `RULES.toml`.

7.2 **Behaviour moved to an uncovered code path.** PF's `ext/GBGPeriodicFieldsHDF5Ext.jl` and `Project.toml` (a
compat bump) are outside `src`,`test`(+`docs`); invisible to `git diff <audited>..HEAD -- <covered>`, and whether
lanes see `ext/` is unstated. **EVADES.** Fix (§6.8): constants = `src`, `test`, `Project.toml`, every path in
`package.extensions`.

7.3 **`previously_worked` omitted / "unknown".** Enum, required, `unknown` gated like `yes` (§6.3). **DEFEATED.**

7.4 **Staleness UNCHECKABLE.** ≠ clean, exit 2 (§6.8). **DEFEATED.**

7.5 **A standalone audit with a chosen base** (`HEAD~1` of a twelve-commit series). Only a hunt pins `base`.
**EVADES** (soft). Fix: doctor `AUDIT.GAP` WARN when `base` ≠ the previous closed audit's `head`.

7.6 **Severity self-report** (everything `minor` ⇒ no disposition). `severity-recheck.js` is wired to
check-consistency only (§3, I §1.5). **EVADES** (mild). Fix (§6.8): run it (anchor) before "serious" is counted.

7.7 **Executable claims under an open round.** Red by 2.1. **BLOCKS-WRONGLY** (same fix).

## 8. The doctor exempted or bypassed

8.1 **No expiry** → `CFG.EXEMPTIONS` FAIL: **DEFEATED.** **`expires = 2999-12-31`**: a dated permanent waiver.
**EVADES.** Fix (§7.2): `expires ≤ recorded + 365 d`.

8.2 **Wiring grep satisfied by a comment.** `# GBGCodingTools.makedocs(cfg)` above `Documenter.makedocs(` (is that
"bare"? undefined) passes `WIRE.MAKEDOCS`; `# TestHarness.gate()` passes `WIRE.RUNTESTS`. D13 promised a structural
check; §7.3 reads as substring presence — and an uncalled wrapper never runs the quick doctor from the build, so
nothing fires. The real witnesses are `BUILD.DOCS`'s banner (`--deep`) and nothing for `gate()`. **EVADES.** Fix
(§7.3): WIRE.* strip comments/strings; "bare" = a `makedocs(` token not preceded by `GBGCodingTools.`;
`TestHarness.gate()` prints a banner and `TEST.PKG` requires it; the CI snippets grep both banners (CI-enforced).

8.3 **A different `gbg` earlier on PATH.** Checks inspect `~/.local/bin/gbg`, not `command -v gbg`. **EVADES**
(minor). Fix: `SHIM.HASH` hashes `$(command -v gbg)` and requires it to be `~/.local/bin/gbg`.

8.4 **Managed file and `managed.json` edited together.** `MANAGED.HASH` compares to the recorded sha; green.
**EVADES.** Fix: compare to the RENDER of the pinned template under the current config; `managed.json` is a cache.

8.5 **The ledger switches the doctor off.** Non-exemptable are only `PIN.*`, `CFG.VALID`, `ROUND.*`, `POL.IMPORT`
(§7.2). One entry `id = "EXEMPT.EXPIRED", scope = "check", target = "*"` disables expiry; `CFG.EXEMPTIONS` exempts
the ledger's own validation; `MANAGED.HASH`, `WIRE.*`, `SHIM.*` likewise. **EVADES.** Fix: non-exemptable = every
check about the tool's own enforcement: `PIN.*`, `SHIM.*`, `CFG.VALID`, `CFG.EXEMPTIONS`, `EXEMPT.*`, `WIRE.*`,
`MANAGED.*`, `POL.*`, `ROUND.*`.

## 9. The config schema admitting a divergence

9.1 **`rubric.arguments_form_min = 3`** is a THRESHOLD in config (§5.1) while §5.4/D16 make thresholds MAJOR and
non-configurable, and §1's table omits it: IT at 5, PF at 3, one rule id. **EVADES** (a §5.4 contradiction). Fix:
delete the key; 3 is a policy constant.

9.2 **`allocating_wrapper_phrase`, `fields_phrase`** are the strings `argcov`/`field_docs` key on; a consumer that
changes one changes what the scan recognises (the critic's D5 note). Not in §1. **EVADES** (minor). Fix: constants,
or listed in §1 with evidence.

9.3 **`instruments.check-docs.lanes`** lets a consumer drop `family`, `cold-reader`, `operational-claims` — the lanes
for the classes a per-docstring pass structurally misses. **EVADES.** Fix: `lanes` names surface lanes only; the
three engine lanes are constants (as the two free hunt lanes are).

9.4 **`docs.public_surface = "names"`** re-admits the `names()` route PF found blind to extended generics.
**EVADES.** Fix: constant `derived`.

9.5 **Free-text commands as gates.** `julia_test`, `docs_build`, `executable_claims.gate` are arbitrary strings;
`gate = "true"` makes the audit's corroboration and `TEST.PKG` vacuous. **EVADES.** Fix: `executable_claims.gate` IS
`julia_test` (no separate key); `CFG.SURFACES` requires `julia_test` to contain `Pkg.test()` and `docs_build` to name
`docs/make.jl`; other claims are existing files under `test/`.

9.6 **`docs.retired_claims`** is read by the ported `lint_retired_claims` (I §1.6) but absent from §5.1's closed
schema — `CFG.VALID` rejects the config IMPLEMENTATION requires. **BLOCKS-WRONGLY** (inconsistency). Fix: add it
to §5.1 and §1 (a per-package phrase list feeding a hard scan, declared like `mathbf_allowed`).

## 10. The fleet one-version rule silently violated

10.1 **Nothing runs `gbg fleet`.** Dev-checkout, owner-initiated only (D4, I §1.3); every consumer's doctor is green
at its own pin; the window fires only when someone remembers. **EVADES.** Fix (D4, §6.2 step 2): `preflight` runs
`git ls-remote --tags <tool url>` (WARN offline) and exits 2 when a newer tag is older than the window.

10.2 **A `fleet.toml` path that does not exist** — skipped row ⇒ a moved consumer leaves the fleet silently.
**EVADES** (ambiguity). Fix: a missing path is exit 2.

10.3 **Sub-environments beyond the three.** PF's `test/gpu/*`, `benchmark/gpu/*`, `examples/` envs; any listing the
tool in `[deps]` resolves outside the pin; `sync` renders three (D3). **EVADES.** Fix: `sync` and `PIN.SOURCES` walk
every `Project.toml` under the consumer that lists `GBGCodingTools`.

## Vocabulary check (§6.3 vs `04-decision-record.md`)

State, act (+`question`), hunter, reproduction (8 incl. BLOCKED, ALREADY-COVERED with evidence, the three cross-field
constraints), ledger `fixed|refused|escalated` (the record deliberately drops the critic's `refuted`), dismissal
(default UNSAFE, `complete` rule), architecture-fix (default ABSENT), audit (`blocker|major|minor|nit`, `justified`,
`previously_worked`, `checked[]`/`candidates_found`), `finding.type` + `domain_type`: **no distinction lost.** One
naming split: `candidates_considered` (§6.1 lane files) vs `candidates_found` (§6.3 audit lanes) — unify.

## "Not configurable" (§5.4) vs the schema (§5.1)

Absent as promised: vocabularies, demotion, closure channels, round layout/stamps, exit contract, `[[scans.custom]]`
tier, economy model name, seed/staleness mechanisms, zero-count rule, include spelling, managed-file mechanism,
"closed". **Two contradictions:** `arguments_form_min` (9.1); `argcov_policy = triage|gate` is a tier choice for a
check — declared in §1, so §5.4 must name it as the one exception. **One ambiguity:** "which lanes are grounding
anchors" is not configurable while per-hat `anchor` is (D18) — two meanings of one word; define both once.

## Tally

55 scenarios: **DEFEATED 17 · EVADES 27 · BLOCKS-WRONGLY 11** (8.1 carries one of each half; 2.1/6.5/7.7 are one
defect). Most consequential: **2.1** (the round loop cannot run under its own gate), **4.1** (a mid-round tool edit
is invisible — the very thing R4 exists for), **3.3** (the answer key is tracked across rounds), **9.6** (the two
documents disagree on the schema).
