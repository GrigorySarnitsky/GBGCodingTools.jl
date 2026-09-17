# SUMMARY — 2026-09-12-audit-changes-02 (a reading aid, never the input to a fix pass)

36 findings banked, 0 seeded (subtracted below), 36 distinct after deduplication by title; ranked by severity × corroboration (k of 10 lanes).

Capped lanes (candidates_found > reported; re-run narrowed if needed): invariants, behaviour-change, executing, claim-versus-edit, under-rejection, over-rejection

- **major** (1/10: free-reader) close()'s new docs-build staleness check trusts an unreachable recorded head as 'not stale' instead of refusing — `2026-09-12-audit-changes-02/free-reader#1`
- **major** (1/10: claim-versus-edit) Two 'one home' consolidation claims are only partly done; the old duplicate sites survive untouched — `2026-09-12-audit-changes-02/claim-versus-edit#1`
- **major** (1/10: behaviour-change) One rotted seed anchor now refuses the whole round where the round used to run with the rest planted — `2026-09-12-audit-changes-02/behaviour-change#3`
- **major** (1/10: executing) close gained a build precondition no documented procedure satisfies; the tests were amended to supply it instead — `2026-09-12-audit-changes-02/executing#1`
- **major** (1/10: behaviour-change) close refuses every docs round that has no ROUND.toml build record, including every round already open — `2026-09-12-audit-changes-02/behaviour-change#2`
- **major** (1/10: executing) close's new staleness test reads an unreachable build head as fresh — the sibling it cites guards that exact case — `2026-09-12-audit-changes-02/executing#4`
- **major** (1/10: public-contract) apply_ledger widened so one waiver can silently disable a sibling rule's enforcement — `2026-09-12-audit-changes-02/public-contract#1`
- **major** (1/10: over-rejection) A seeded round now refuses to open when ONE seed class has no anchor, where it used to plant the rest and name the class — `2026-09-12-audit-changes-02/over-rejection#1`
- **major** (1/10: over-rejection) close now demands a build record only `gbg round build` can write — every round open at this commit, and every round built through prepare or pass open, is refused — `2026-09-12-audit-changes-02/over-rejection#2`
- **major** (1/10: invariants) a ledger waiver that used to be silently void now silences the entire scan, including hits of rules the consumer never named — `2026-09-12-audit-changes-02/invariants#3`
- **major** (1/10: under-rejection) A policy waiver on ANY rule a scan enforces now disables the whole scan, withdrawing enforcement of rules the consumer never exempted — `2026-09-12-audit-changes-02/under-rejection#1`
- **major** (1/10: over-rejection) The widened waiver resolution silently switches OFF two scans nobody exempted, for ledgers written under the old rule — `2026-09-12-audit-changes-02/over-rejection#4`
- **major** (1/10: executing) a policy waiver now silences two scans it was inert on, and the docstring books that hazard as inherited — `2026-09-12-audit-changes-02/executing#3`
- **major** (1/10: over-rejection) A consumer that set latex_source_globs now has docs/src and docs/ REMOVED from the hat's source surface — the key replaces the four surfaces instead of adding to them — `2026-09-12-audit-changes-02/over-rejection#3`
- **major** (1/10: behaviour-change) source_globs repurposes latex_source_globs, narrowing the authored-source substrate for any consumer that set it — `2026-09-12-audit-changes-02/behaviour-change#4`
- **major** (1/10: executing) latex_source_globs repurposed as the hat's whole source surface: a consumer that set it loses three of the four surfaces it used to read — `2026-09-12-audit-changes-02/executing#2`
- **major** (1/10: behaviour-change) A policy waiver on a sibling rule now disables the whole scan, withdrawing enforcement nobody exempted — `2026-09-12-audit-changes-02/behaviour-change#1`
- **major** (1/10: under-rejection) The panel's authored-source grant is REPLACED by latex_source_globs, so a consumer that set that key loses ext/, docs/src/ and docs/ from five hats' reading surface — `2026-09-12-audit-changes-02/under-rejection#3`
- **major** (1/10: under-rejection) close's new build-staleness branch fails open: any git failure, and the `0`×40 head build records itself, make it pass vacuously — `2026-09-12-audit-changes-02/under-rejection#2`
- **major** (1/10: behaviour-change) The quantifier class enlarges every lane's mandatory claim checklist by a third to two fifths — `2026-09-12-audit-changes-02/behaviour-change#5`
- **major** (1/10: invariants) close() gets a brand-new, universally-required docs-build gate that nothing in the normal lifecycle populates — `2026-09-12-audit-changes-02/invariants#1`
- **major** (1/10: invariants) a partially-anchored seed catalogue escalates from a tolerated, logged skip to a hard refusal, in two call sites, with no test either way — `2026-09-12-audit-changes-02/invariants#2`
- **minor** (1/10: executing) prepare turns a printed warning into a hard refusal and leaves its own now-dead skipped-classes branch standing — `2026-09-12-audit-changes-02/executing#6`
- **minor** (1/10: public-contract) gbg round close now refuses check-docs/check-consistency rounds with no recorded build, rejecting a previously-successful invocation — `2026-09-12-audit-changes-02/public-contract#2`
- **minor** (1/10: claim-versus-edit) The seed-anchor refusal (f64b542) leaves two now-unreachable 'skipped classes' branches behind it — `2026-09-12-audit-changes-02/claim-versus-edit#2`
- **minor** (1/10: free-reader) The new required arg source_globs was added to the schema and to the message it feeds, but not to panel.js's own contract comment or its own required-key guard — `2026-09-12-audit-changes-02/free-reader#2`
- **minor** (1/10: behaviour-change) gbg round scripts unfreezes a round's Workflow scripts mid-round, and its own docstring still says nothing does — `2026-09-12-audit-changes-02/behaviour-change#7`
- **minor** (1/10: public-contract) gbg round prepare now refuses on any partially-unanchored seed catalogue, rejecting a previously-tolerated invocation — `2026-09-12-audit-changes-02/public-contract#3`
- **minor** (1/10: over-rejection) `gbg round build` now mutates ROUND.toml — an undocumented side effect that can make the verb fail where it used to run — `2026-09-12-audit-changes-02/over-rejection#6`
- **minor** (1/10: free-reader) A seed catalogue with any class that cannot anchor now hard-refuses prepare, where it previously proceeded on the classes that did plant — `2026-09-12-audit-changes-02/free-reader#3`
- **minor** (1/10: behaviour-change) Admitting the open rounds to the release build also waives the gate's committed-without-the-round refusal — `2026-09-12-audit-changes-02/behaviour-change#6`
- **minor** (1/10: under-rejection) gbg release now admits every open docs round to its own SELF.DOCS build, suppressing the gate's per-round refusals including :committed — `2026-09-12-audit-changes-02/under-rejection#4`
- **minor** (1/10: under-rejection) release gained a `root` keyword while `running_dev()` still tests the RUNNING copy, so the guard no longer names the checkout that gets tagged and pushed — `2026-09-12-audit-changes-02/under-rejection#5`
- **minor** (1/10: over-rejection) The quantifier class adds ~500 mandatory checklist items corpus-wide — the padding the adjacent comment warns against — `2026-09-12-audit-changes-02/over-rejection#5`
- **minor** (1/10: executing) three of the new comments' cited measurements do not reproduce, and one counts two homes this diff created — `2026-09-12-audit-changes-02/executing#7`
- **minor** (1/10: executing) the quantifier class enlarges every lane's mandatory checklist by 46%, a burden the affordability comment never measures — `2026-09-12-audit-changes-02/executing#5`
