# SUMMARY — 2026-09-11-audit-changes-02 (a reading aid, never the input to a fix pass)

25 findings banked, 0 seeded (subtracted below), 25 distinct after deduplication by title; ranked by severity × corroboration (k of 13 lanes).

Capped lanes (candidates_found > reported; re-run narrowed if needed): over-rejection, contract-drift, sweep-completeness, behaviour-change, executing, under-rejection

- **major** (1/13: executing) docs_build_skipped now fails, instead of skipping, a local docs build during an open docs round whose files are uncommitted after HEAD moved — wider than the :disabled defect it fixed — `2026-09-11-audit-changes-02/executing#1`
- **major** (1/13: contract-drift) The DEAD-scan guarantee was reworded to match the code, which exempts a scan whose counter is broken if the ledger ate its hits — `2026-09-11-audit-changes-02/contract-drift#1`
- **major** (1/13: sweep-completeness) policy/instruments.md's Honest limits still state the seeded copy lives inside the project unconditionally — `2026-09-11-audit-changes-02/sweep-completeness#2`
- **major** (1/13: sweep-completeness) TestHarness.jl drops a false Base-collision example the twin test still asserts — `2026-09-11-audit-changes-02/sweep-completeness#1`
- **minor** (1/13: sweep-completeness) Preflight.jl's own D16 citations in tag_tree/stamps were left when a sibling docstring's D-number/section citation was dropped — `2026-09-11-audit-changes-02/sweep-completeness#5`
- **minor** (1/13: over-rejection) A bare local docs build during an open docs round now throws whenever the round's files are uncommitted after HEAD moved, where it used to skip with exit 0 — `2026-09-11-audit-changes-02/over-rejection#1`
- **minor** (1/13: executing) ScanResult/report DEAD contract narrowed to match the code: a zero-population scan with a ledger-exempted hit is now declared not DEAD — `2026-09-11-audit-changes-02/executing#3`
- **minor** (1/13: contract-drift) The prose-shape ratchet baseline was re-baselined in the same change set that grew the units it guards — `2026-09-11-audit-changes-02/contract-drift#2`
- **minor** (1/13: contract-drift) docs_build_skipped now fails the build on the ':committed' problem too, which is wider than the disabled-instrument defect it fixed, and no test covers it — `2026-09-11-audit-changes-02/contract-drift#5`
- **minor** (1/13: contract-drift) Section 6.4 now covers docs rounds but still says only the seeded copies exist during the panel — `2026-09-11-audit-changes-02/contract-drift#3`
- **minor** (1/13: public-contract) docs_build_skipped() now fails a build it used to silently skip — `2026-09-11-audit-changes-02/public-contract#1`
- **minor** (1/13: sweep-completeness) Rounds.jl documents classify_lane's decision ORDER; ARCHITECTURE D10's own enumeration (edited in the same diff) still lists REJECTED last — `2026-09-11-audit-changes-02/sweep-completeness#3`
- **minor** (1/13: behaviour-change) The docs-build skip now also fails on a :committed refusal, which is wider than the disabled-instrument defect it fixed — `2026-09-11-audit-changes-02/behaviour-change#1`
- **minor** (1/13: executing) docs/prose_shape.csv, the ratchet's frozen baseline, was re-baselined in the same window as the prose it guards, silencing 25 GREW hits — `2026-09-11-audit-changes-02/executing#2`
- **minor** (1/13: sweep-completeness) calibrate()'s 'persona' correction leaves rubric-audit.js still calling it the hat's 'own rubric' — `2026-09-11-audit-changes-02/sweep-completeness#4`
- **minor** (1/13: contract-drift) D10's docs-round exception drops the design's own reason for keeping seeded copies inside the project, and says nothing of what that costs — `2026-09-11-audit-changes-02/contract-drift#4`
- **nit** (1/13: executing) ext comment swaps an existing rule id for a design decision about something else — `2026-09-11-audit-changes-02/executing#5`
- **nit** (1/13: public-contract) gate_problems' new element type (Pair{Symbol,String}) is a genuinely new surface, not a change to gate()'s contract — `2026-09-11-audit-changes-02/public-contract#2`
- **nit** (1/13: contract-drift) Demote now defines class_surfaces as 'every OTHER surface', which makes the empty-list demotion contradict its own reasoning — `2026-09-11-audit-changes-02/contract-drift#6`
- **nit** (1/13: under-rejection) The new public gate_problems leaves out two of gate's refusals, and returns 'no problem' where gate never passes vacuously — `2026-09-11-audit-changes-02/under-rejection#1`
- **nit** (1/13: executing) TestHarness.resolve_function docstring's new example `Ledger.read` does not hold when Config is also in `modules` — `2026-09-11-audit-changes-02/executing#4`
- **nit** (1/13: claim-versus-edit) Design.jl calibrate() wording fix ('own rubric' -> 'persona') is a drive-by not itemized in the fix-pass-1 commit message — `2026-09-11-audit-changes-02/claim-versus-edit#1`
- **nit** (1/13: invariants) Passes.jl docstring names a "fifth channel" inside a §5.5 closed vocabulary of four — `2026-09-11-audit-changes-02/invariants#1`
- **nit** (1/13: contract-drift) The Passes module now says carrying applies only after a spent pass budget, but carry_conditions also allows it below the budget — `2026-09-11-audit-changes-02/contract-drift#7`
- **nit** (1/13: behaviour-change) The hard SCAN.PROSE_SHAPE ratchet was re-baselined in the same change that grew the units, including an appended design section — `2026-09-11-audit-changes-02/behaviour-change#2`
