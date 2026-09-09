# Round-2 critique — measurement-integrity lens (attack-design style)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.


Method: for every gate a proposal claims, construct (i) an EVADE — a lazy or mistaken session's
action sequence under which the gate reports closure or cleanliness falsely — and (ii) a BLOCK — a
legitimate round the gate refuses. Every "fail-closed" claim is tested against *the missing case
must be the failing case* (CC §6.1, §6.25; BH §5.7). Abbreviations: `M` = round1-measurement.md,
`P` = round1-platform.md, `C` = round1-consumer.md; `CC`/`BH`/`CD`/`BL` = the surveys. Line
numbers are the proposals'. Repo facts were re-checked in PF/IT (`make.jl`, `verify-fixes.js`,
`gate.py`, `witnesses.jl`, `finished.py`, `seed_defects.py`, `recall.py`, `doc-review/CLOSED.md`).

Headline: `M`'s round contract (§0, D10) is the only one whose closure predicate is per finding,
CLI-computed, clone-safe and version-checked at every verb — and it still has four holes (PARTIAL
passes closure; verdict files not bound to their pass; seeded closure is an unreviewed heuristic;
the worktree is mutable mid-round). `P` and `C` each carry a dead staleness design, leave the
state verifier out of closure, and (`C`) cannot run the gate in CI at all.

---

## 1. The round contract under attack

**A1 — copy-forward verdicts (EVADE, all three).** Pass 2 graded 40 findings; the session fixes
the eleven LINE-ONLYs, opens pass 3, and — lazily or by a `cp -r` habit — copies
`verdicts/pass-2/act/*` into `pass-3/act/`, editing the eleven verdicts to HONORED.
- `M` (L621–623): `graded_sha256` is the hash of `findings.json`, which is FROZEN for the round,
  so every pass carries the same hash; the copy validates. Nothing binds a verdict file to the
  pass it claims to belong to. FIX: `pass open` writes a random `pass_nonce` into `pass.toml`;
  every verdict file must carry `pass_nonce` and the grader is given it in args; `grade` rejects a
  mismatch. A copied file carries the old nonce and fails; a hand-edited nonce is a deliberate act
  of the class the surveys accept as residue (IT `make.jl` L268–280).
- `P` (L852): mtime — the copy is newer than the lane, passes. `C` (L702): same.

**A2 — hand-written verdicts (EVADE, all three; no fix exists).** The fixer writes
`pass-3/act/01.json` itself: all HONORED, `class_surfaces` non-empty. Nothing in any proposal can
tell an agent-written file from a session-written one; `M` P2's "the grader's code lives in the
tool repo" (L44) is true of the *prompt* and false of the *artefact*. All three claim grader ≠
graded as a structural property; for files it is a discipline. State the limit: the round
contract defeats laziness and error, not forgery by the session. The only partial mitigation is
that `verify-act.js` returns its verdict object to the session transcript, which a later reader
can diff against the banked file — a human check, not a gate.

**A3 — PARTIAL closes a finding (EVADE, `M` only, and it is `M`'s own contradiction).** `M`
D11 (L271–272): "only ABSENT and NOT-A-DEFECT are favourable". `M` §4.2 step 7 (L668–669):
`closed_by = honored` iff act = HONORED and state ∉ {PRESENT, REGRESSED, UNCLEAR}. PARTIAL is not
in the excluded set, so a finding whose act verdict is HONORED with a non-empty `class_surfaces`
and whose blind state verdict is PARTIAL with `surviving_class = "three siblings on the API
page"` CLOSES. That is LINE-ONLY seen from the other side — the exact defect the two-verifier
design exists to catch. FIX: `closed_by = honored` requires state ∈ {ABSENT, NOT-A-DEFECT}.

**A4 — the state verifier is decorative (EVADE, `P` and `C`).** `P` step 9 (L855–857) closes on
"HONORED in `verdicts/act`, or an exemption, or SEEDED" — the blind verifier's PRESENT/PARTIAL is
listed in step 8 as a "disagreement" and never read by the gate. `C` step 8 (L703): "exits 1
while any finding is neither HONORED nor in `.gbg/adjudicated.md`". In both, a grader who writes
HONORED with any non-empty array closes a finding the blind verifier says is still there. This is
PF's status quo (`make.jl` reads only `closure/`); both proposals inherit it while claiming the
pair. FIX as A3.

**A5 — mid-round instrument edit (EVADE, `M` and `C`; `P` immune).** Pass 2 demotes six
verdicts; the session edits `demote.py` in the pinned checkout so `[{surface: ""}]` counts, reruns
`grade`, closes. `M` D2: the tag worktree at `~/.gbg/instruments/v1.2.0/` is a writable git
worktree; P3 (L50–53) checks `ROUND.toml.instrument_rev` against the *pin*, which did not move.
`C`: `ENV-02` (L812, checkout clean and at a tag) runs in `doctor`/`preflight`, not in `round
grade`/`close` (L290–294). `P`: the CLI runs from `~/.julia/packages/<slug>/`, which Pkg installs
read-only; an edit needs a `chmod` — deliberate. FIX for `M`/`C`: every `gbg round` verb checks
`git -C <tool> status --porcelain` empty AND `HEAD == tag` (exit 2 otherwise), and `ROUND.toml`
stamps the tool tree's `git-tree-sha1`, re-verified at `close`. Or adopt `P`'s delivery.

**A6 — the Dropbox checkout flips under an open round (EVADE, `C` only).** Aiporetne is in pass 2
of a PF round at v1.3.0. Enteropia runs `git -C ~/.gbg/tools checkout v1.4.0` for IT's migration.
Dropbox syncs the working tree; Aiporetne's `~/.gbg/tools` symlink now resolves v1.4.0 code;
`gbg round grade` runs under v1.4.0 with a stamp saying v1.3.0 — `C` checks `PIN-01` in the
doctor, not in the round verbs (L129–131, L815). `C` D4(b) concedes the mechanism ("a `git checkout`
on one machine flips the other"). This violates R4 by construction; `C`'s D2 is dominated for
measurement, whatever its sync ergonomics.

**A7 — the closure gate cannot run in CI (BLOCK → then EVADE, `C`; ambiguous in `M`).** `C` D9
(L256) and step 10 (L709–712): `make.jl` calls `closure_gate()` → `gbg round gate` at
`~/.gbg/tools/bin/gbg`. `docs.yml` runs on every push on a GitHub runner with no `~/.gbg`
(`C` L114 itself says so). The docs deploy fails on every push; the owner wraps the call in
`isdir(...) && …`; the gate is now skipped wherever the pile is absent — CI green, IT's vacuous
shape (CC §6.1). `M` (L225–226): "calling `run(gbg gate …)`" — if via the `~/.local/bin/gbg` shim,
same failure. `P` (L277–279, L605): `run_gate` executes `python3 <pkgdir>/gbg …` from the
Pkg-fetched copy, which exists in CI. Only `P` works; `M` must say pkgdir explicitly.

**A8 — the shim falls open (EVADE, `P`).** `P` D2 (L68–73): inside a consumer the shim asks
`julia --project=test` for the package location and "outside any consumer it falls back to the
dev checkout". Fresh clone, test env not yet instantiated: `locate_package` returns `nothing`,
the shim treats it as "not a consumer" and runs the DEV checkout — whatever version is checked
out in Dropbox — and `gbg doctor`/`gbg args` report from a version the consumer never pinned.
FIX: inside a directory that has `.gbg/config.toml`, an unresolvable package is exit 2
("instantiate `test/` first"); the dev fallback applies only where no config exists.

**A9 — re-roll a hat (EVADE, `M`).** `bank` exits 1 on a DEAD lane and `rerun --lanes X`
"appends to the same round" (L657–658). Nothing says rerun is limited to dead lanes. A session
whose `spectral-methods-mathematician` returned 12 findings reruns it until it returns 3. FIX:
`rerun` accepts only lanes `bank` classified DEAD; a present, parsable lane file is frozen from
the moment it is written (record its sha at first sight in `ROUND.toml`).

**A10 — bank writes the frozen hash on exit 1 (EVADE, `M`, spec ambiguity).** Step 4 lists
"writes `findings.json` + its sha256 into `ROUND.toml`" and "exit 1 if any DEAD lane" in one
sentence. If the hash is written before the exit-1 return, a later `pass open` proceeds against a
denominator that excludes the dead lane. FIX: nothing frozen until exit 0.

**A11 — dead-lane detection is self-report (EVADE, all three).** `M` P1: zero findings with an
empty `checked[]` → DEAD. `P`/`C`: parse-to-zero without a "No findings" sentence → dead. A lazy
economy hat returns `checked: ["docs/ARCHITECTURE.md"]` and zero findings; all three read it as
clean. The only non-self-reported liveness signal in the corpus is seeded recall (CC §6.18: a hat
that misses every seed on its own substrate is UNMEASURED). `M` L559 and `P` L770 both set real-
round seeding OFF by default and move calibration to the fixture — which measures the INSTRUMENT's
sensitivity, not THIS ROUND's hats. IT seeds every round (CC §1.2) for exactly this reason.
Verdict: `seed_by_default = true` fleet-wide; the fixture calibrates the tool, real-round seeds
calibrate the run. Cost is hat tokens only, since seeded findings never reach a verifier pass.

**A12 — a hat with no substrate blocks closure (BLOCK, all three).** SS sets `built_api = ""`;
its roster still lists `structure-consistency` (SITEONLY). The hat has nothing to read, returns
zero, is DEAD, the round cannot close. FIX: `open` resolves the roster against the surfaces and
records a hat with an empty substrate as `not_applicable` in `ROUND.toml`, not as expected.

**A13 — the Stop hook (BLOCK, `M` L487, L679–680).** `gbg gate --open-rounds` as a Stop hook
exits non-zero while any round is open. A fix pass spanning three sessions is a legitimately open
round; every Stop is refused; the owner disables the hook; enforcement is gone (the "disabled the
first time it is inconvenient" rule the proposals quote). If a hook is kept, it may block only on
a round that is OPENED and not BANKED — findings that exist only in a Workflow result and will
evaporate — never on "open".

**A14 — closed rounds reopen on every build (BLOCK, `P`; latent in `M`).** `P` L349–351 and
`C` L710–711 re-run the gate over every CLOSED round on every build. `P` D14 (L483) makes
`expires` REQUIRED on every ledger entry including `scope = "finding"`. A round closed in 2026 by
an adjudicated finding reopens in 2027 when the entry expires, and the docs build fails on a
year-old round. `M` recomputes the closed tally from `adjudicated.toml`, which can lose an entry.
FIX: a dismissed finding does not become undismissed by calendar — no expiry on finding-scope
entries (`M` already splits doctor exemptions from adjudications; `P` must); and at `close`, copy
the adjudicated entries the round used into the round, so its tally recomputes from its own files.

**A15 — the hand-invoked Workflow (residue, all three).** A session calls Workflow with typed
args pointing hats at `/tmp`. No `ROUND.toml`, nothing in the repo, gate silent. All three accept
this as the deliberate-act residue; correct, but it should be written down beside A2 rather than
implied closed by "no marker → no args → no round" (`M` L245–246), which is true only for the
skill path.

**A16 — `hats.json` by census agent (`P` L840–841, L952; `C` L220, L721).** The roster and
denominator written by an agent are self-report; IT's shape existed because the JS cannot see
files (CC §6.6). The CLI can. `M` L724 is right; `P`'s "census denominator vs self-report logged"
(L852–853) keeps a check that compares one agent's account with another's.

---

## 2. Staleness — the three designs

| Design | Fresh clone / CI (git sets every mtime to checkout time) | Dropbox / branch switch | Lazy copy-forward (A1) | Missing case fails? |
|---|---|---|---|---|
| (1) mtime, PF today; `P` L852, L813 ("engine constant") | `mtime(verdict) < mtime(lane)` is decided by checkout ORDER — spurious BLOCK on roughly half the lanes, or vacuous PASS; the platform's own CI gate (A7) runs on a fresh clone every push | `git checkout other && git checkout master` rewrites both files; 6-hour bucket misfired once already (CC §5.2) | passes | no: absent verdict file = "" then `mtime` errors or reads 0 |
| (2) self-stamp `RANGE:`, PF's first design | independent of mtime | independent | a copied file carries the OLD range, so it fails iff the range differs per pass — two passes at one HEAD (fix pass uncommitted) share a range and the copy passes | only if the gate FAILS on a missing stamp; PF's did not, and "all eight lanes ignored it" |
| (3) CLI-created pass directory + `graded_sha256`, `M` L718 | pass directories are empty until written this pass; absent = DEAD | independent | passes (hash is of the frozen findings) — needs the per-pass nonce of A1 | yes: no file in the current pass = DEAD; wrong hash = REJECTED |

Verdict: (3) plus a per-pass nonce survives; (1) is dead — it is wrong in BOTH directions on the
one machine (`P`'s CI runner) where `P` chose to run the gate; (2) is compliance, not evidence.
`P`'s resolution table (L949, "mtime; the 6-hour bucket dropped") should be reversed. `C` (L702,
mtime with the bucket as WARN) has the same clone defect.

---

## 3. Seeded defects — the three designs

**(M)** `.gbg/seeds.toml` in the consumer; `ground_truth.json` written at `open` into the tracked
round; `bank` marks `seeded` by `recall`'s fragment match; `grade` sets `closed_by = seeded`;
`adjudicated.toml` refuses seeded IDs (L248–250, L723).
**(P)** Calibration anchored to the fixture (L515–516); real-round seeding closed by an
`exemptions.toml` entry with `evidence = ground_truth.json` (L489–492) — but step 9 (L855–857)
says the gate reads `ground_truth.json` directly. Two mechanisms in one proposal.
**(C)** Same as `P`'s ledger route (L718–721); title-keyed `adjudicated.md` injected into hats.

Attacks:
- **S1 — co-quoted seed closes a real finding (EVADE, `M`; latent in all).** Seed 6 flips the
  third `N/M` to `M/N`. A hat files a REAL, unrelated defect on that page and quotes the
  paragraph, mutated `M/N` included. `recall`'s substring match (PF `recall.py` L50) attributes
  seed-06 to it; `M`'s `bank` sets `seeded = true`; `grade` closes it; nobody fixes the real
  defect. PF's `recall.py` says "the printed match list is for hand review" — `M` turned a
  hand-reviewed heuristic into an automatic closure channel in the flattering direction. FIX:
  `closed_by = seeded` requires the fragment match AND a state verdict ∈ {ABSENT, NOT-A-DEFECT}
  from the blind verifier on the real tree (PF's `doc-review/CLOSED.md` shows the verifier
  establishing exactly this on its own). A real defect co-quoted with a seed comes back PRESENT
  and stays open.
- **S2 — the answer key is on disk during the panel (all three; `M` misstates it).** `M` L723:
  "the leak was the preamble, which is the one place the seeds now cannot reach". False.
  `ground_truth.json` is written at `open` into the round directory (L640–642), tracked, and every
  hat has `Read`/`Bash`; the seeded manuscript sits beside `docs/build`, and one `diff` reveals
  every seed. Today's exposure is the same (the catalogue lives under `.claude/commands`, and PF's
  verifier found a seed by `git log -S`). Prohibition in the hat prompt is the only guard, and it
  cannot be made structural. What CAN be done: do not write `ground_truth.json` until `bank`
  (recompute it deterministically from `seeds.toml` + the unseeded manuscript at bank time), and
  keep the seeded manuscript outside the repo (`~/.gbg/state/<round>/`). Then a cheating hat must
  diff two manuscripts it was told not to open, which at least leaves a `Read` in its transcript.
- **S3 — ledger leak (`P`).** L353–354: the panel preamble receives exemptions "as titles only";
  L489–492: a seeded finding is closed by an exemption entry. The entry's title IS the hat's
  finding title ("Lalescu year reads 2012 on page X"). Unless the renderer excludes seeded entries
  by a machine-readable field — `P` says "strips ids and seeds" without saying how a seed is
  recognised — the next round's hats receive the answer. And the catalogue is deterministic, so
  every round adds one entry per seed per detecting hat (11 in PF's last round) forever. `M`'s
  round-local `ground_truth.json` channel has neither defect. `P` should keep its step-9 version
  and drop the D14 one.
- **S4 — untitled findings (`C`).** `C` keeps title-keyed `.gbg/adjudicated.md` (L291–292, L534).
  PF's `cold-reader` writes bare `## Finding 6` headings (`doc-review/CLOSED.md` L24–27); such a
  finding can never be adjudicated and never seeded-closed by title. `M`/`P` key by ID.

Survivor: `M`'s channel with S1's state-verdict guard and S2's deferred ground truth.

---

## 4. Verdict vocabularies — what each union loses

| Set | `M` | `P` | `C` | Lost distinction |
|---|---|---|---|---|
| State | +UNCLEAR, REGRESSED, PARTIAL | IT's five (no UNCLEAR) | drops REGRESSED | `C` loses REGRESSED (a fix that made it worse — measured in IT). UNCLEAR: either is fail-closed; keep as non-passing (M). |
| Act | IT's eight; `class_surfaces[{surface,swept,evidence}]` | eight; array | eight; `string[]` | none; object form lets the schema require `surface` non-empty (structural, not the vocabulary-matching IT banned). |
| Reproduction | 7 incl. ALREADY-COVERED; CONFIRMED→REPRODUCED | 7 | CONFIRMED+EVIDENCED, drops NO-WITNESS-POSSIBLE | `C` loses NO-WITNESS-POSSIBLE (reproducer-stage, distinct from the hunter's NOT-WRITABLE). |
| ALREADY-COVERED | admitted unguarded | admitted | admitted | Near-vacuous: if the suite already catches it, `Pkg.test()` is red NOW; if the suite's assertion is weaker, it is NOT covered. Admit only with `test_name` and a red `Pkg.test()` on it; otherwise it is PF `dismissals.js`'s third dismissal shape ("the suite would catch it") wearing a verdict. |
| Architecture-fix | ABSENT from `M` (no `verify-architecture.js` in L442–450) | FIXED/RELOCATED/PARTIAL/ABSENT/NOT-A-DEFECT | absent | `M` loses RELOCATED — IT's measured "fix by relocation". |
| Ledger | `refuted` → `refused` + evidence (L280) | `fixed/refuted/escalated` (no `refused`) | audit only | `M` loses refuted (not a defect after all → the DISMISSAL audit's input) vs refused (a real defect, won't fix → a decision). `P` cannot record IT's "parked, do not fix" case. Union: `fixed|refused|refuted|escalated`. |
| Audit severity | mapped into blocker/major/minor/nit | `serious/notable/minor` kept | kept | `M`'s mapping is unstated churn; the gate's "serious" has a meaning. Keep per-instrument. |
| Cross-field constraints | none stated | none | EVIDENCED ⇒ architecture | All need: REPRODUCED ⇒ `witness_path` present AND in the bank-time fail set; EVIDENCED ⇒ kind = architecture. |

`P`'s set is the most complete; `M`'s artefact structure is the best; `C`'s set loses two
measured distinctions and its title key loses closure.

---

## 5. Bug-hunt witness lifecycle

- **W1 — weaken between fail and pass (EVADE, all three).** `bank` verified the witness FAILS. The
  fix is partial; the session loosens `≈ … atol` in the round's witness; `--expect pass` is green;
  `M` L699 "every `fixed` witness promoted (a file whose header names the ID)" — a name check.
  `C` L723's CLI copy makes the copy itself unchanged but copies the weakened file. FIX: `bank`
  records `sha256` of each failing witness body in `tally.json`; `close` requires the promoted
  body (header stripped) to hash-match the BANK-time body. "Unchanged" is thereby a promotion-time
  property, as BH §5.2 asks; thereafter the tree owns it.
- **W2 — blocked-by-environment (UNDER-BUILD, all three).** IT's `needs-gpu/` holds witnesses the
  CPU environment reports BROKEN, kept "because a skipped test passes". `M` bans BROKEN at bank
  (exit non-zero) and offers `NO-WITNESS-POSSIBLE` (a different thing: no program can distinguish)
  — a GPU-only claim is then deleted or mislabelled. Add `BLOCKED` (reason = environment) to the
  reproduction set: tracked under `witnesses/blocked/`, never promoted, never counted confirmed,
  listed in the close account, and a doctor `--deep` line on a host that HAS the device: "N
  blocked witnesses runnable here". No proposal has it.
- **W3 — escalated witnesses rot (UNDER-BUILD).** `M` L702–703: tracked, never promoted, never
  skipped — and never re-run. IT's OPEN-DEFECTS.md: "five of seven reported nothing at all" after
  renames. Doctor `--deep`: `witnesses --expect fail` over every round's `escalated/`; PASS ⇒ the
  defect was fixed incidentally (promote); BROKEN ⇒ the register is stale.
- **W4 — audit/promotion deadlock (BLOCK, `M`).** `M` L699–701 requires, for a hunt's close: every
  `fixed` witness promoted, AND an audit-changes round over the hunt's range closed, whose gate
  requires `git diff <audited>..HEAD -- covered` empty with `test` covered. Promotion after the
  audit touches `test/regressions/` ⇒ STALE ⇒ the hunt cannot close; promotion before the audit
  is the only order, and no proposal states it. State it, or exempt from staleness a
  `test/regressions/` file whose body hash equals a banked witness of the closing hunt.
- **W5 — "over the hunt's range" is unchecked (EVADE, `M`).** The session audits `base = HEAD~1`
  of a twelve-commit fix series. FIX: hunt `close` requires `audit.base == ROUND.head` (the hunt's
  opening head) and `audit.head == HEAD`.
- `M` deletes `closure.py`'s follow-up-hunt terminator and keeps `fixed+refused+escalated ==
  confirmed` (L722): correct; `C` leaves bug-hunt closure unspecified beyond `witnesses promote`.

---

## 6. Audit-changes gate

- **Base pinned:** `M`/`P` require `base`; `C` "requires `base`" (L724) and nothing else. W5 above.
- **`test/` in the diff:** all three put `covered_paths` in CONFIG (`M` L569, `P` L784, `C`
  L637); a consumer writes `["src"]` and the oracle drops out silently. IT's rule is "the oracle is
  part of the change set" — make `test` a constant member, removable only by a ledger entry.
- **`previously_worked` escalation:** free text in all three. EVADE: an economy lane writes
  "unknown" ⇒ escalated ⇒ the session dispositions `refused, because previously_worked was a
  guess……` (≥ 24 chars) ⇒ passes. Or omits it ⇒ not escalated. FIX: enum `{yes, no, unknown}`,
  required on the `behaviour-change` lane, `unknown` gated like `yes`.
- **UNCHECKABLE ≠ clean:** `M`/`P` adopt PF's `git diff <audited>..HEAD` (correct; IT's `git log
  -1 -- covered` reports STALE after any covered-path commit at all). `C` names no mechanism.
- **Empty audit:** IT's `verdict_all_clean: true` is written BY THE SESSION into `latest.json` (a
  manual step in both packages today, BH §2). `M`'s `bank` derives it from lane files with
  non-empty `checked[]` (self-report, but the lane's not the fixer's). Better anchor no proposal
  has: `gbg audit-changes bank` RUNS `executable_claims` itself and records exit codes — the
  `executing` lane's report is an agent's account of a program, the third instance of the class
  `witnesses.jl` closed.
- **Dispositions keyed by title** (PF `gate.py`) inherit the untitled/renamed hole; `M` keys by id.

---

## 7. D1–D19, from this lens

- **D1** All three: one repo. Entailed by R2/R4 (one stamp). No scenario separates them.
- **D2** `P` (Pkg-fetched read-only copy) survives A5; `M` (worktrees) needs the per-verb dirty
  check; `C` (Dropbox clone + symlink) fails A6 by construction. Best: `P` with A8's fail-open
  removed. `M`'s worktree-per-tag is over-build once Pkg gives one copy per version for free.
- **D3** Equivalent (config pin + `[sources] rev`); `P` adds `[compat] "=x"`. `C`'s absolute
  `~/.gbg/tools` in `@import` and `scriptPath` is what breaks A7.
- **D4** `M` (per-consumer pin, 7-day window, `rounds compare` refusing unequal MAJOR.MINOR) is
  the only one that turns comparability into a refusal; `C`'s single checkout makes R4 violable (A6).
- **D5** Equivalent. Note: `M` lets `notation.banned` regexes vary per consumer — a `hard` scan
  whose pattern is config is not "the same instrument" across consumers; recall figures then
  compare only within a consumer. Declare it.
- **D6** The mechanism that matters is `C`'s `!`-block preflight whose non-zero exit aborts the
  skill (L173–182) — fail-closed by the platform, not by prose. `P`'s stub "tells the model to
  stop" (L823–824); `M`'s plugin route rests on an untested local marketplace. Best: `P`'s
  per-consumer stub (version visible in git, R2) carrying `C`'s abort. Verify the abort fact on
  day 1 alongside the marketplace fact.
- **D7** Equivalent, with `M`'s rule that scripts return liveness only and never a tally (L185–186)
  the one that closes the grader-tallies-itself twin. `P`/`C` keep the census agent (A16).
- **D8** `M`: exit 3 for a tool crash (a crashed gate exiting 1 reads as "a finding"); scans
  without a must-fail fixture refused at tool test. Best.
- **D9** Not this lens, except A7: the Julia package must reach the Python gate through `pkgdir`
  (`P` L605), never the shim.
- **D10** `M` with fixes A1, A3, A9, A10, A12, A14, S1, S2. `P`: mtime (§2), state verifier not
  in closure (A4), finding-scope expiry (A14), census roster. `C`: title key (S4), mtime, state
  verifier not in closure, CI-blind gate (A7), bug-hunt closure unspecified.
- **D11** `P`'s set ∪ `M`'s structure ∪ `fixed|refused|refuted|escalated` ∪ BLOCKED ∪ the
  cross-field constraints of §4. `C` loses REGRESSED and NO-WITNESS-POSSIBLE.
- **D12** `M`/`P`: rendered copy committed in the consumer ⇒ the rubric a round ran under is at the
  round's `head`. `C`: `@~/.gbg/tools/policy/…` — not in the consumer's history, and A6 changes
  it under every open round on both hosts. `C`'s "session quotes the sentinel" (L354–355) is
  self-report with no failing missing case (the model can quote last session's line).
- **D13** Equivalent; `P`'s wiring-check for seeded files is the useful extra.
- **D14** `M`: expiry on doctor exemptions only. `P`: expiry on everything (A14). `C`: 365-day
  `reviewed` WARN — fine for deviations.
- **D15** `M`'s `SELFTEST.<tag>.ok` per machine, read by the doctor (L798–799), is the only
  proposal proving the pinned instrument passes its own tests on THIS host (Python/Julia versions
  differ per host). Keep. `touch`-able, deliberate.
- **D16** `M`: `--regrade` supersedes passes and the CLOSING pass must be at the current version
  (L371–374). `P`: `--regraded` "with an account" (L536) — a rubber stamp. `C`: re-runs
  verification, does not say close must be at the new version. Under-build in all: a MAJOR may
  change the FINDING schema; `--regrade` must re-validate `findings.json` under it or the round can
  only be abandoned.
- **D17** `M` step 0 (L742–746) and `C` L787–790 both require the ported gate to REPRODUCE PF's
  and IT's recorded closures before v1.0.0 — the only measurement-preserving acceptance test. `P`
  has none.
- **D18** Equivalent; `M` hard-codes the grounding anchors (executing lane, reproducers,
  adjudicators, dismissal auditors) as non-configurable — right.
- **D19** Irrelevant to measurement.

---

## 8. Over-build and under-build

Over-build (no requirement forces it):
- `M` worktree per tag (D2) — Pkg copies give per-version immutability for free.
- `M` Stop hook on open rounds (A13).
- `P` re-grading every closed round on every build (A14) — cost grows with history, and with
  expiring entries it is a regression generator.
- `P` `CONTRACT.SYNC` (L472): a second copy of each consumer's config inside the platform, kept
  in sync by hand — a manifest-drift generator. `C`'s "copied into `tests/contracts/` at each
  release" is derived, not maintained.
- `C` sentinel-quote check (D12).
- `M` banking `hard` scan hits as `00-guards` findings that then need an AGENT verifier's HONORED
  (L687–689): a deterministic hit closes by RE-RUNNING THE SCAN (`closed_by = rescan`), never by
  a graded verdict. Grading regex output with a Sonnet lane is cost with no information.

Under-build (no proposal satisfies):
1. Verdict-to-pass binding (A1 nonce).
2. Witness body hash at bank vs promotion (W1).
3. BLOCKED-by-environment state (W2); escalated re-run (W3).
4. Seeded closure guarded by the state verdict (S1); ground truth off-disk during the panel (S2).
5. `--regrade` re-validating findings under a new schema (D16).
6. Audit staleness vs promotion order (W4); `audit.base == hunt head` (W5).
7. `test` as a constant member of `covered_paths`.
8. The CLI re-running executable claims at audit bank.
9. Two text-scan engines: Julia `lint_notation_variants` and the Python scan catalogue both match
   `\partial_[ijk]` (PF today: `guards.sh` and `make.jl`). `M` keeps `catalog/scans.toml` (py) +
   `DocLints` (jl); `P` keeps `scans.toml` + `lints.toml`; `C` `gbg guards` + `lint_docs`. The
   cross-language twin the surveys measured (CD §7.8) survives in all three. One catalogue, one
   engine; the Julia side calls it.
10. `rerun` limited to DEAD lanes (A9); frozen hash only on exit 0 (A10).
11. The forgery residue stated as a limit (A2, A15).
12. `hats.json`/census retired in `P` and `C` (A16).

---

## 9. Ten most consequential disagreements, ranked

1. **Staleness**: mtime (`P`, `C`) vs CLI pass directories + hash (`M`). Verdict: `M` + per-pass
   nonce. mtime is wrong in both directions on every fresh clone, including `P`'s CI gate.
2. **Does the blind state verifier bind closure?** `M` yes (with the PARTIAL hole); `P`/`C` no.
   Verdict: yes, state ∈ {ABSENT, NOT-A-DEFECT} required. Otherwise the second verifier is theatre.
3. **Where the pinned instrument runs**: read-only Pkg copy (`P`) vs mutable worktree (`M`) vs
   Dropbox-synced clone (`C`). Verdict: `P`'s copy + `M`'s per-verb version check; `C` violates R4.
4. **Seeded closure channel**: round-local `ground_truth.json` (`M`) vs exemption ledger entries
   (`P` D14, `C`). Verdict: `M`, with the state-verdict guard and deferred ground truth.
5. **Adjudication key**: ID (`M`, `P`) vs title (`C`). Verdict: ID; titles cannot close an
   untitled finding. Cross-round re-flag needs a new entry — a deliberate act, acceptable.
6. **Denominator and roster**: CLI (`M`) vs census agent (`P`, `C`). Verdict: CLI.
7. **Gate reachable in CI**: `pkgdir` (`P`) vs shim (`M`, unstated) vs `~/.gbg` symlink (`C`,
   broken). Verdict: `pkgdir`, stated explicitly.
8. **Vocabulary union**: `P` most complete; `M` loses RELOCATED and refuted; `C` loses REGRESSED
   and NO-WITNESS-POSSIBLE. Verdict: §4's union; ALREADY-COVERED guarded or dropped.
9. **Real-round seeding by default**: off (`M`, `P`) vs IT's every-round. Verdict: on — it is the
   only non-self-reported dead-lane signal (A11).
10. **Skill fail-closed mechanism**: `!`-block abort (`C`) vs prose (`P`) vs plugin (`M`).
    Verdict: `C`'s abort inside `P`'s per-consumer stub.

---

## 10. Residual judgment calls (evidence cannot settle)

- Whether a deterministic per-pass nonce is enough, or the session's own verdict forgery (A2) is
  worth a transcript-diff discipline — a cost/paranoia call.
- `seed_by_default = true` on real rounds (recommended) vs the token cost of 8–11 seeded findings
  per round.
- Keep `UNCLEAR` (honest, blocks) or force default-PRESENT (blocks equally, hides uncertainty).
- ALREADY-COVERED: guard it or drop it.
- Unify severity across instruments (`M`) or keep the audit's `serious/notable/minor` (`P`).
- Stop hook: none, or "opened-not-banked" only.
- Whether a closed round's tally is frozen with its adjudications (recommended) or live.
- Whether the CLI re-runs executable claims at audit bank (minutes per audit) or trusts the
  `executing` lane's account.

---

## 11. What all three missed

- The grader ≠ graded property holds for prompts and not for files; none states the forgery
  residue (A2) or the hand-invoked Workflow residue (A15) as limits — each claims closure.
- The seeded manuscript beside `docs/build`, and `ground_truth.json` in the tree during the panel,
  are one `diff`/`Read` away from any hat (S2); `M` explicitly and wrongly says the preamble was
  the only leak.
- PARTIAL is the state-side LINE-ONLY, and none of the three closure predicates excludes it — `M`
  because of a slip against its own D11, `P` and `C` because the state verifier is not consulted.
- A deterministic scan's finding closes by re-scan, not by a graded verdict.
- The audit-then-promote ordering deadlock (W4) and `audit.base` unchecked against the hunt (W5).
- `needs-gpu` — the one witness state IT documented with a reason ("a skipped test passes") — has
  no place in any vocabulary.
- The overlapping Julia/Python text-scan engines reproduce the measured cross-language twin.
- mtime's behaviour on a fresh clone was never checked by the two proposals that chose it, though
  the platform runs its gate on fresh clones by design.
