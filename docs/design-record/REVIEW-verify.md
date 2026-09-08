# Verification of Revision 2 (2026-09-07) — ARCHITECTURE.md (A) + IMPLEMENTATION.md (I)

Method: every ruling and every listed review item opened at the location FIXLOG names and confirmed
against the revised text (line numbers as of this revision); then a mechanical cross-check of every
doctor id, rule id, scan id, CLI verb, config key, exit code and file path that appears in more than
one place; then I read end to end as the implementing session. Nothing was fixed.

## 1. Rulings 1–22

1. R1 `GBG_ROUND` — CONFIRMED. A vocab L34; §6.2 step 3 L1027, 6 L1054, 7 L1058, 10 L1084–1096 (CI never sets it; hand export = §11 L1545 residue); §6.7 L1173; §6.8 L1194. I §B L62–63; 1.3 `round build|test` L191; 1.4 L219.
2. R2 fixture pin — CONFIRMED. A D15 L572–577 (`version = "dev"`, `path = "../../.."` from a sub-env — the ruling's `../..` counted from the fixture root, stated), §7.3 `PIN.CONFIG` L1273, `ROUND.DEV` L1305; I 1.2 (4) L161, 1.7 L333–334, Phase 1 DoD L353–363.
3. R3 `$DEV` — CONFIRMED. I L7–18 `export B DEV PF IT SS CP`; the only remaining `bash -c '…'` is the prose at L7 describing the hazard; Phase 1/3/4 blocks are double-quoted (L353, L398, L455).
4. R4 shim ↔ dev checkout — CONFIRMED. A D2 L145–146, L158–159, L170–172; §7.3 `ENV.DEV_CHECKOUT` L1271, `SHIM.HASH` L1272 (body only). I 1.2 L157–169; 1.3 `install [--dev-checkout]` L182; Phase 3 L410.
5. R5 QUICK — CONFIRMED. A §7.3 header L1258–1263 (exact set; `ENV/SHIM/GIT/LEG/PIN.TREESHA/PIN.SELF/--deep` never); D9 L375 `makedocs` runs `--only QUICK`; D14 L543. I 1.4 L212; 1.3 L183.
6. R6 PIN.TREESHA + self verify — CONFIRMED. A D3 L216–224 (manifests that exist, WARN absent, FAIL disagree, Python tree hash, exit 2, `tool_tree_sha`); §7.3 L1275–1276; step 10 L1086; §6.1 L987. I 1.3 L184; 1.6 `tree.py` L279.
7. R7 Step 0 on live trees — CONFIRMED. A §8 L1346–1361 (target table, per round); I Phase 2 L370–394; PF-2 L430.
8. R8 config anchors — CONFIRMED. A §5 L775–778 (anchor semantics), `history_exempt = "…#13. Decision log"` L822, `references_heading = "absent"` L823 (whole-file DOI scan), §5.2/§5.3 real headings L927, L946; `CFG.SURFACES` L1279.
9. R9 hats — CONFIRMED. A D7 L326–332, §5.1 `domain_hats` ×4 L878–893, `rulebook_sections` L800, §5.3 L951–956, §9 L1393; I 1.7 L288–296, PF-1 L429, 5.2 L493–496.
10. R10 versions — CONFIRMED. A D17 L627–641 (1.0.0 whole; defect ⇒ 1.0.x), D4 L252; the one surviving "1.1.0" (L640) is the dominated alternative. I 5.1 L468–481; Phase 8 L579.
11. R11 schema/config — CONFIRMED. `docs.retired_claims` A L831–839; `[rubric]`/`[notation]` reduced to the variation points L841–848; `lanes_extra` L858; constants in D9 L392–393 and §5.4 L977–979; missing path ⇒ 2 D5 L267; sub-env walk D3 L201–204, `PIN.SOURCES` L1274; `argcov_policy` exception with the `# Arguments` reason §5.4 L967–972. Zero hits for the five deleted keys in either document.
12. R12 exit codes — CONFIRMED. DEAD ⇒ 2 at A D8 L356, D10 L445, step 5 L1051, §8 L1332; absent/unparsable/invalid ⇒ DEAD quarantined L442, L1044. I 1.3 L173–174, 1.6 L274. No "exit 1 … DEAD" survives.
13. R13 doctor/ledger — CONFIRMED (one wording mismatch, item 4.3). Non-exemptable set D14 L550–552, §7.2 L1251–1253; `expires ≤ recorded + 365 d` / `overturn_when` L548–549, L1232, L1282; `command -v gbg` L1272; fresh render D13 L521, L1290; `TEST.PKG` banner L1310 + D9 L399; disabled instruments gated L1278, step 10 L1090; dirty tree = closed/abandoned D6 L297, step 2 L1020.
14. R14 seeds — CONFIRMED. Salt A step 3 L1031–1032, §6.4 L1120–1121, `seed_salt` L988, `ground_truth.salt` L1010; hats forbidden `.gbg/**` and `~/.gbg/**` D7 L333, step 4 L1038; `.gbg/scratch/<round>/` D10 L436–438; SUSPECT step 5 L1048, tally L1008; residue §11 L1541–1544. I 1.5 L250, 1.6 L277, 1.8 L340.
15. R15 config_sha — CONFIRMED. A §6.1 L991–992 (three files, order fixed); D16 L605–609; steps 5/7/8/9 L1041, L1058, L1067, L1074; `--regrade` re-validates and re-stamps L606–608.
16. R16 bug-hunt — CONFIRMED. `reproductions_sha` at bank §6.7 L1167–1168, §6.1 L990; `Witnesses.run` refusal D9 L406–409, §6.7 L1163–1164, I 1.4 L242–244; ancestor at close step 9 L1077 (else `--regrade`), §6.7 L1176; BLOCKED header + close account L1166–1167, L1177.
17. R17 audit-changes — CONFIRMED. Constants + `[paths]` only ADD §6.8 L1191–1192, §5.1 L806–809, L902, §5.4 L977; `AUDIT.GAP` WARN L1199, L1307; empty audit needs the claims run with exit codes L1197–1198.
18. R18 fleet — CONFIRMED. A D4 L246–251 (window checked by `fleet` and `bump`; `bump` starts it; preflight does NOT); `[sweep]` §3 L677; I 1.1 L139–140, 1.3 `bump` L197, `fleet` L185.
19. R19 owner questions — CONFIRMED. I §A L28–38 = Q1–Q7, Q12; §B L46–51 states the former Q8–Q11 decisions; A §10 L1516–1521.
20. R20 record deviations — PARTIAL. All six sub-points present (`gate check-docs check-consistency` D9 L378; five phases D18 L650; `init --migrate` → `commit-message.txt`, `bump` → `bump-message.txt` D16 L611–613; one renderer D5 L272–273, step 7 L1061; doctor prints "promote" D14 L545, L1311; §6.1 L986–991 the complete field list). Gap: §6.1's list contains `round`, which is neither in the record's list nor in §10's extension list (L1496–1498) — the ruling asked for the list to match once.
21. R21 fill tables — CONFIRMED. §12.A 91 rule rows (FIXLOG says 90), §12.B 40 scan rows including `SCAN.CUSTOM.<id>` (FIXLOG says "41 + custom"), §7.3 47 doctor ids; every id cited anywhere in A or I resolves to its table (item 2 below). FIXLOG's two counts are off by one; the tables themselves are complete.
22. R22 minor citations — CONFIRMED. `panel.js:88,93` I L429; IT 39 files I L516, A L636; 125 witnesses I L509; PF-3 ranges + kept calls I L431; `survey-checkdocs.md:104` A L316; the six verbs defined (I 1.3), `--rewrite-arg-bullets`/`calibrate rubric` gone; `LEG.PILES` limited to imported/deleted piles A L1293; CP root `Project.toml` L19–20 I L566, A L1438; PF-0 CI auth I L428; `optional = true` A L816–817.

## 2. Dry-run BLOCKERs 1–5 and MAJORs 6–23

1. CONFIRMED (ruling 1) — A step 10 L1084–1096; I §B L62–63, 1.4 L219–220, 1.8 L340–342 selftest arm; A §8 L1337–1338.
2. CONFIRMED (ruling 2) — A D15 L572–577, L586–589 (`selftest --pinned`); I Phase 1 DoD L353–363, Phase 3 L406–419.
3. CONFIRMED — I L7–18 exports; `__main__.py --dev` I 1.3 L175–177, A D2 L161.
4. CONFIRMED (ruling 4) — `~/.gbg/dev`; `ENV.DEV_CHECKOUT` A L1271.
5. CONFIRMED (ruling 5) — QUICK set A L1258–1263; `ENV/SHIM/GIT` excluded outright.
6. CONFIRMED — A D3 L216–219, `PIN.TREESHA` L1275 (two slugs ⇒ FAIL).
7. CONFIRMED — A §8 table L1352–1361 (three PF targets + 2026-07-22); I Phase 2 L378–388.
8. CONFIRMED — A §5 L775–778, L800, L822–823; `CFG.SURFACES` L1279.
9. CONFIRMED — A §5.1 L883–893 (`anchor = false`), D7 L326–329 eight keys; I 1.7 L288–296, PF-1 L429.
10. CONFIRMED (ruling 9, catalogue side) — A D7 L330–331, L347–348; §5.3 L951–953; I 1.7 L293–294, 5.2 L494–496.
11. CONFIRMED (ruling 10, option a) — A D17 L627–631; I 5.1 L470–478.
12. CONFIRMED — `docs.retired_claims` A L831–839, §1 L99, `SCAN.RETIRED_CLAIMS` L1697.
13. CONFIRMED (ruling 12) — DEAD ⇒ 2 everywhere.
14. CONFIRMED — A §6.1 L993–995 (`findings.json` only on exit 0), step 5 L1043–1053 (`lane_shas` at first sight; `rerun` DEAD-only; changed live lane ⇒ REJECTED), D10 L444–445.
15. CONFIRMED — I PF-0 L428, V4 probes PF and CP L89, Phase 6 L541, Phase 7 L560; A §4 L769, `WIRE.CI_AUTH` L1287.
16. CONFIRMED — A step 1 L1015 (`--profile all|core|explicit --strength full --no-seed --dry`); I 1.3 L190.
17. CONFIRMED — A D9 L375–379, L422–423; I 1.4 L212–218 ("never the bare `run_gate("gate")`").
18. CONFIRMED (ruling 5) — A D14 L543, §7.3 L1262–1263; I 1.3 L183.
19. CONFIRMED (ruling 21) — §12.A/B/C L1570–1736.
20. CONFIRMED (ruling 11) — A §5.1 L841–848, D5 L273–274, §5.4 L979.
21. CONFIRMED — I PF-2 L430 ("THEN seed `.gbg/exemptions.toml` … keyed by the ids the import's title → id map now provides").
22. CONFIRMED — I 5.2 L499–506 (`r<N>-` prefix map, `env/` discarded, round 3 `abandoned`, `r4-architecture-03-probe.jl` → round 4).
23. CONFIRMED — I PF-6 L434 `rm -rf`, 5.2 L511–513; A `LEG.PILES` L1293 names exactly the imported/deleted piles and excludes Q12's.

## 3. Attack items (20 of the EVADES / BLOCKS-WRONGLY set)

1. 1.4 wholesale adjudication — CONFIRMED. A step 9 L1078–1080 (`dismissals.js` over post-`opened` finding entries, `reopened == []`, every instrument); `adjudicated_share` §6.1 L1008; §6.5 L1136.
2. 1.5 rescan by narrowing — CONFIRMED. `config_sha` refusal by every verb (D16 L605–607); §6.5 L1138 `closed_by = adjudicated` naming the entry; `adjudicated_entry` L1007.
3. 1.6 UNMEASURED hat — CONFIRMED as ruling 14 (SUSPECT, reported not fatal) — A L1048, L1127; I 1.6 L274, L276.
4. 2.1 build/test deadlock — CONFIRMED. `GBG_ROUND` (item 1.1); `gbg round build|test` A step 6 L1054–1057, I §B L62.
5. 2.2 dirty rounds dir — CONFIRMED. A D6 L297, step 2 L1020, step 9 L1077, §6.7 L1169–1171 (existing files committed first, then `close` writes its own).
6. 2.3 finding-scope expiry — CONFIRMED as ruling 13 (`overturn_when`, no `expires`) — A D14 L548–549, §7.2 L1237–1241, `EXEMPT.EXPIRED` "finding scope skipped" L1283.
7. 2.4 PIN.TREESHA with absent manifests — CONFIRMED. A D3 L217–219, L1275.
8. 2.5 malformed lane file — CONFIRMED. A D10 L441–442, step 5 L1044 (`NN-<lane>.rejected.json`).
9. 2.7 POL.COLLAPSED on quoted words — CONFIRMED. A L1298 and `SCAN.REGISTER` L1681.
10. 3.3 answer key across rounds — CONFIRMED as ruling 14 (salt + hats forbidden `.gbg/**`); hashed contexts deliberately not adopted (FIXLOG).
11. 4.1 edited pinned copy — CONFIRMED as ruling 6 (`self verify`, `PIN.SELF` L1276, exit 2 from every `round` verb and `gate`).
12. 4.2 re-tag laundered — CONFIRMED. A D16 L608–609 ("tag moved" ⇒ abandon-only), step 9 L1075–1076, §8 arm L1339.
13. 4.3 consumer inputs mid-round — CONFIRMED (ruling 15).
14. 5.1 fixes pushed, round not — CONFIRMED. A step 10 L1090–1092; §11 L1547–1549.
15. 5.3 disabled instrument hides rounds — CONFIRMED. A step 10 L1086–1090; `CFG.VALID` L1278.
16. 6.3 BLOCKED relabel after bank — CONFIRMED. A §6.7 L1165–1168; §6.3 L1107 (BLOCKED only at bank to an ERRORED never-FAILS witness).
17. 7.6 severity self-report — CONFIRMED. A §6.8 L1190–1191, §6.3 L1104; I 1.5 L261.
18. 8.2 wiring grep by comment — CONFIRMED. A D13 L525–530, `WIRE.MAKEDOCS`/`WIRE.RUNTESTS` L1285–1286 (comments and strings stripped; "bare" defined), banners L1309–1310; I 1.7 L315.
19. 8.5 ledger switches the doctor off — CONFIRMED. Non-exemptable set incl. `EXEMPT.*`, `CFG.*`; `target = "*"` on scope `check` refused A L1253–1254, L1282.
20. 9.3 / 9.5 / 10.3 — CONFIRMED. Engine lanes constants A L861–862, §5.4 L976; `julia_test` IS the gate claim + `CFG.SURFACES` content checks L803–804, L1279; sub-env walk D3 L201–204.

## 4. Consistency mismatches (mechanical cross-check)

1. **Id collision the text denies.** §12.C L1731–1735 claims the only shared prefix is `TEST.` and "every id has exactly one meaning", yet `GIT.BRANCH` and `GIT.TRAILER` are BOTH rule ids (§12.A L1665, L1662) AND doctor check ids (§7.3 L1299–1300). With the ledger resolving `RULES.toml` first, a `scope = "check"` exemption on `GIT.BRANCH` resolves to the rule; and `GIT.*` is "exemptable" as a check (D14) while `GIT.TRAILER` the rule is a policy target — two meanings under one id.
2. **Exemptable set stated two ways.** D14 L552: `LEG.*`, `GIT.*` + scopes. §7.2 L1253: `LEG.*`, `GIT.*`, `AUDIT.*` + scopes. Ruling 13's set has no `AUDIT.*` (the id post-dates it). Pick one and say so in both.
3. **`ROUND.toml` field `round`** (§6.1 L986) is not in §10's extension list (L1496–1498) nor in the record — the "complete list" and the "extensions over the record" disagree by one field.
4. **Verb-table completeness claim vs `gbg probe`.** I 1.3 L203 "No other verb exists; a verb used anywhere in this plan is in this table"; Phase 0 V2 (L87) uses `gbg probe` / `gbg probe --fail`. Either a throwaway is declared exempt or the row is added.
5. **`gbg round compare` has two meanings.** D4 L245 ("`gbg round compare` refuses unequal `MAJOR.MINOR`" — round vs round) vs §8 L1350 / I 1.3 L191 (`compare --recorded <file> <round>` — round vs a recorded tally). Neither document defines the two-round form.
6. **`gbg round regrade`** is listed (I 1.3 L191; A step 10 L1094 "explicit") but never defined — what it recomputes on a closed round, and how it differs from `pass open --regrade`.
7. **Phase 3 DoD status word `NOT-INITIALISED`** (I L417) appears nowhere else; the `gbg fleet` row vocabulary (OK / … ) is undefined in A (D4, D14 say "one row per consumer" only).
8. **Revision-2 footers disagree on which dry-run items took the ruling's form**: A L1741–1743 lists (1, 2, 4, 5, 6, 7, 11, 13, 19, 20, 21, 50, 52); I L601–603 lists (1, 2, 3, 4, 5, 6, 7, 11, 18, 21, 33, 52, 54); FIXLOG's table marks 13 rows "Applied (ruling N)". Cosmetic, but three different lists for one fact.
9. **FIXLOG counts vs tables**: §12.A has 91 rows (FIXLOG "90"); §12.B has 39 named scans + `SCAN.CUSTOM.<id>` (FIXLOG "41 + custom").
10. Clean: all 47 doctor ids used in A (outside §7.3) and in I resolve to §7.3; every `SCAN.*` cited outside §12.B (4 ids) and every rule id cited in §12.B or elsewhere (`DOC/TEX/CIT/API/INST/TEST/GIT`) resolves to its table; every dotted config key cited in prose (`docs.retired_claims`, `check-docs.lanes_extra`, `instruments.check-docs.argcov_policy`, `git.branch`, `hooks.work_queue`, `schema.finding_types_extra`, `cost.default`, `citations.require_doi`, `package.julia_test`, …) exists in §5.1; the 18 schema names (D11 L466–468 vs I L304–306), 12 template files (§3 L724–726 vs I L308–319), 25 `gbg/*.py` modules (§3 vs I 1.1), 6 `src/*.jl` files and the `.gbg/scratch/` contents (§4 L748–749 vs D16/I) agree verbatim; exit codes agree everywhere they are restated (gate: open round 1 / no `ROUND.toml` 2 / no rounds dir 2; bank DEAD 2; grade open ids 1; triage scan nothing scanned 2; witnesses empty 2; missing path 2; crash 3); the QUICK set is restated identically in D14, §7.3, D9 and I 1.4; the three "dev pin" WARNs match between D15 L577–578 and I L363, L416; `expires` bound and `overturn_when` agree in D14, §7.2, §7.3; `--profile`/`--strength`/`--no-seed`/`--dry` flags agree between A step 1 and I 1.3; no retired term survives (`GBG_ACTIVE_ROUND`, `GBG_ROUNDS_IN_PROGRESS`, `~/.config/gbg`, `PIN.INTEGRITY`, `AUDIT.COVERED_TEST`, `UNMEASURED`, `SHORT`, `candidates_considered`, `arguments_form_min`, `v0.0.1-probe`, `sync --rewrite-arg-bullets` all 0 hits; `TREE.sha256`, `~/.gbg/state`, `1.1.0`, `gate docs`, `refuted`, `notable` occur only inside dominated-alternative or historical text).

## 5. Residual blockers for the implementing session (I read end to end)

1. **Phase 0 cannot complete before Phase 1.** V2 needs a `gbg probe` verb and a shim; V3 needs "a throwaway push of the skeleton" and a fixture copy; V4 needs `templates/docs.yml.snippet` and a PF branch whose `docs/Project.toml` carries a tool entry at some `rev` (which? `v0.0.1` is deleted after V3); V5 needs `ci.yml`; V6 needs `$DEV`'s `Project.toml`. Only V1 is runnable in Phase 0. State "V2–V6 run after 1.1–1.3 (and V4 after 1.7)" and name V4's rev.
2. **Phase 2 invokes `gbg --dev …` (L378–390) before any shim exists** — the shim is installed in Phase 3 (L410) and `~/.gbg/dev` with it. Either Phase 1 ends with `./install.sh` (never stated) or Phase 2 uses `python3 "$DEV/gbg" --dev …` as Phase 1's DoD does.
3. **`gbg round import` in Phase 2 "writes only under a scratch output directory it names" (L373)** — no option in the verb row (L191) and no stated location; `round grade <each>` and `compare` then have no defined way to find those rounds outside `.gbg/rounds/`. Define `--into <dir>` (or the default) and how the later verbs are pointed at it.
4. **Phase 2 DoD is unverifiable for two rounds.** `compare --recorded <file>` takes "a recorded `CLOSED.md`/marker"; PF `2026-07-22` has no such file (its target is a `CLAUDE.md` sentence, L386), and IT's bug-hunt rounds are `rounds.json` entries. The accepted `<file>` formats, and what `compare` extracts from each, are undefined, so "exits 0 for every imported round" cannot be met as written.
5. **Phase 4 ordering: PF-0 runs `gbg --dev sync` (L428) before PF-1's `gbg --dev init --migrate` (L429) creates `.gbg/config.toml`.** `sync` validates config first (D5), so PF-0's sync is exit 2 on a repo with no `.gbg/`. Move the snippet insertion after PF-1 (the secret and PAT steps can stay first).
6. **PF-4 has no command for the frozen tables.** "tables → `test/method_parity_baseline.toml`", `oracle_registry.jl` "→ `test/oracle_registry.toml`", and `test/pass_audit_baseline.toml` (§4 L765–767) must be produced from PF's current Julia literals; neither `TestHarness` nor any `gbg` verb offers a freeze/convert, and no hand-conversion recipe (which literals, which schema) is given.
7. **Phase 5.1 "against the released `v1.0.0` (not `--dev`)" (L477) is unrunnable before 5.2.** The versioned route needs IT's `.gbg/config.toml` pin and instantiated sub-envs, which IT gets only in 5.2's `init --migrate`. Either run 5.1 through `--dev` with the dev checkout checked out at the `v1.0.0` tag, or split IT's PF-1-equivalent init ahead of 5.1 and say so.
8. **5.2 "round 4 is created `abandoned`" (L505)** — no verb creates an empty abandoned round: `abandon` needs an open round, `import` needs a pile. Define an `import --empty`/`abandon --create` form or put the probe in round 5.
9. **CP has no config delta.** §5 gives SS and IT deltas only; Phase 7 relies on `gbg init` defaults for `check-consistency.hats`/`core`, `finding_types_extra`, `bug-hunt.territories`, `executable_claims`, `guard_symbols`, `invariants_section` — none has a stated default, and `CFG.HATS` needs ≥ 1 hat in the roster (the "write ≥ 1 domain hat" line names the file, not the roster key).
10. **PF-2 discards `.claude/doc-review-prev/` "on the owner's word"** (L430) — not among §A's questions and no default; either a Q13 or a stated default.
11. **`LEG.SENTINELS` (PF-5 L433) matches "the policy sentinel sentences"** — the list, and where the doctor reads it from (a field in `RULES.toml`? the first sentence of each rule?), is undefined in both documents.
12. **`gbg fleet` on a fresh dev checkout with no `[sweep]`** (Phase 3 DoD) and the row states it prints (item 4.7) — the implementer must invent the output contract that the DoD then grep-gates.
13. **1.4 `Config.jl`: "write a 120-line JSON reader or vendor one"** — an open choice; `TOML` is already a dep, so `gbg config --toml` would remove the reader entirely. Minor, but a decision the session will have to make alone.
14. Minor: V4's fallback and PF-0 both assume the `insteadOf` snippet is inserted by `sync` into an existing workflow file — the insertion point inside `docs.yml`/`CI.yml` (before `julia-actions/setup-julia`? before checkout?) is unstated, and `WIRE.CI_AUTH` will grep for it.

## 6. Counts

- Rulings: 21 CONFIRMED, 1 PARTIAL (R20: `round` field missing from §10's extension list), 0 MISSING.
- Review items opened: 23 dry-run (5 BLOCKER + 18 MAJOR) + 20 attack = 43; 43 CONFIRMED (10 in a ruling's form), 0 PARTIAL, 0 MISSING.
- Consistency: 9 mismatches (1 semantic id collision, 1 set stated two ways, 1 field-list gap, 1 verb-table completeness, 2 undefined/overloaded verbs, 1 undefined status word, 2 cosmetic count/list disagreements); everything else cross-checked clean (item 4.10).
- Residual blockers for the implementing session: 12 substantive (5.1–5.12) + 2 minor (5.13–5.14).
