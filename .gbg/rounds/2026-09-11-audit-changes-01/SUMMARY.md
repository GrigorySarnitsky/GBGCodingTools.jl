# SUMMARY — 2026-09-11-audit-changes-01 (a reading aid, never the input to a fix pass)

33 findings banked, 0 seeded (subtracted below), 33 distinct after deduplication by title; ranked by severity × corroboration (k of 13 lanes).

Capped lanes (candidates_found > reported; re-run narrowed if needed): reader-consequence, claim-versus-edit, over-rejection, contract-drift, behaviour-change, executing, under-rejection, public-contract, free-reader

- **major** (1/13: over-rejection) audit_bank's new verdict refusal prints a rerun remedy that `gbg round rerun` refuses: a first bank has no recovery path — `2026-09-11-audit-changes-01/over-rejection#1`
- **major** (1/13: contract-drift) The new audit-bank refusal prints a `gbg round rerun` command that rerun itself refuses — `2026-09-11-audit-changes-01/contract-drift#1`
- **major** (1/13: contract-drift) The disposition-state closed vocabulary was widened in the schema to fit the code; §6.3 still says three values — `2026-09-11-audit-changes-01/contract-drift#2`
- **major** (1/13: executing) A lane file with "findings": null now crashes audit_bank (MethodError, exit 3); base quarantined it as DEAD with exit 2 — `2026-09-11-audit-changes-01/executing#2`
- **major** (1/13: public-contract) makedocs' return value silently changes from always-nothing to true-on-success — `2026-09-11-audit-changes-01/public-contract#1`
- **major** (1/13: free-reader) audit-changes bank's new lane-verdict-contradiction refusal prints a rerun command that is always refused — `2026-09-11-audit-changes-01/free-reader#1`
- **major** (1/13: reader-consequence) audit-changes bank's new lane-verdict-contradiction message tells the session to run a `gbg round rerun` that will always be refused — `2026-09-11-audit-changes-01/reader-consequence#1`
- **major** (1/13: executing) The new verdict check reads quarantined *.rejected.json files, so a stale one blocks every later audit bank — `2026-09-11-audit-changes-01/executing#1`
- **major** (1/13: behaviour-change) audit_bank's new verdict refusal prints a rerun remedy that `gbg round rerun` refuses: the round cannot be banked — `2026-09-11-audit-changes-01/behaviour-change#1`
- **minor** (1/13: under-rejection) makedocs now returns true on a built site, so the unchanged deploy guard in docs/make.jl passes where it used to refuse every build — `2026-09-11-audit-changes-01/under-rejection#1`
- **minor** (1/13: behaviour-change) hunt.js free-lane prompt now says the brief is the ONE .gbg/ file, contradicting the preamble's invariants grant — `2026-09-11-audit-changes-01/behaviour-change#5`
- **minor** (1/13: contract-drift) Six program-decidable rules moved from `weakness` to `panel`, which by the rule's own text hides owed checks — `2026-09-11-audit-changes-01/contract-drift#3`
- **minor** (1/13: executing) makedocs' public return value changes from nothing to true on a completed build (the measurement claim holds) — `2026-09-11-audit-changes-01/executing#5`
- **minor** (1/13: public-contract) gbg audit-changes bank gains a new exit-2 refusal path for input it previously ran to completion on — `2026-09-11-audit-changes-01/public-contract#3`
- **minor** (1/13: behaviour-change) lane_verdict_contradictions also reads quarantined `*.rejected.json` files, which nothing removes — `2026-09-11-audit-changes-01/behaviour-change#2`
- **minor** (1/13: free-reader) New lane self-report check treats every non-CLEAN verdict string as CONCERNS, silently accepting a malformed verdict the schema would otherwise reject — `2026-09-11-audit-changes-01/free-reader#2`
- **minor** (1/13: behaviour-change) init now rewrites every seeded test/Project.toml through render_project: wider than the dev-pin defect — `2026-09-11-audit-changes-01/behaviour-change#4`
- **minor** (1/13: under-rejection) The prose-shape ratchet was re-baselined in the same change set: 20 ceilings raised, including a module docstring from 422 to 589 words — `2026-09-11-audit-changes-01/under-rejection#2`
- **minor** (1/13: over-rejection) The contradiction check runs before schema validation: a schema-invalid lane file now crashes or is misreported instead of being quarantined as DEAD — `2026-09-11-audit-changes-01/over-rejection#3`
- **minor** (1/13: sweep-completeness) docs/make.jl (the tool's own docs build) not swept when templates/make.jl.seed's makedocs-return-value contract was corrected — `2026-09-11-audit-changes-01/sweep-completeness#1`
- **minor** (1/13: under-rejection) Six rules moved from `weakness` to `panel`, dropping the unpaid-check marker on rules a program can decide, RULE.CIT.DOI among them — `2026-09-11-audit-changes-01/under-rejection#3`
- **minor** (1/13: public-contract) gbg init's --dry-run preview no longer matches what a real run writes for test/Project.toml — `2026-09-11-audit-changes-01/public-contract#2`
- **minor** (1/13: claim-versus-edit) Init.jl's templates#2 fix widens test/ sub-environment rendering to the self-consumer branch it explicitly excludes — `2026-09-11-audit-changes-01/claim-versus-edit#1`
- **minor** (1/13: over-rejection) A CLEAN lane that reports findings is now refused outright; before, its findings were banked and had to be disposed — `2026-09-11-audit-changes-01/over-rejection#2`
- **minor** (1/13: behaviour-change) makedocs' return value changes from `nothing` to `true` for every normal build, and every push to master now deploys — `2026-09-11-audit-changes-01/behaviour-change#3`
- **minor** (1/13: contract-drift) audit_bank's docstring does not mention its new refusal — `2026-09-11-audit-changes-01/contract-drift#4`
- **minor** (1/13: executing) audit-changes bank now refuses (exit 2) a CLEAN lane that reports findings, which the generic bank accepted before — `2026-09-11-audit-changes-01/executing#3`
- **minor** (1/13: executing) init now re-renders a freshly seeded test/Project.toml: it strips the seed's comment and, on the tool-itself branch, adds the tool entry its own comment forbids — `2026-09-11-audit-changes-01/executing#4`
- **minor** (1/13: contract-drift) The makedocs SKIPPED exception was narrowed in the prose to fit the code, contradicting the stated rationale — `2026-09-11-audit-changes-01/contract-drift#5`
- **nit** (1/13: behaviour-change) doc-policy and naming-policy hat personas widen what the check-consistency panel reports — `2026-09-11-audit-changes-01/behaviour-change#6`
- **nit** (1/13: contract-drift) makedocs now returns `true` instead of Documenter's `nothing` on a completed build — `2026-09-11-audit-changes-01/contract-drift#6`
- **nit** (1/13: executing) The hard-tier prose-shape baseline was re-baselined in the same change set as 19 units that outgrew it — `2026-09-11-audit-changes-01/executing#6`
- **nit** (1/13: contract-drift) Init's new `push!(envs, "test")` also fires on the tool-as-own-consumer branch, contradicting the comment just above it — `2026-09-11-audit-changes-01/contract-drift#7`
