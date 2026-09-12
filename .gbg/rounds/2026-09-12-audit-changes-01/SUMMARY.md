# SUMMARY — 2026-09-12-audit-changes-01 (a reading aid, never the input to a fix pass)

18 findings banked, 0 seeded (subtracted below), 18 distinct after deduplication by title; ranked by severity × corroboration (k of 13 lanes).

Capped lanes (candidates_found > reported; re-run narrowed if needed): claim-versus-edit, over-rejection, contract-drift, behaviour-change, under-rejection, free-reader

- **major** (1/13: under-rejection) The ConfigError→exit 2 arm sits at main()'s outermost catch, so a config the TOOL just wrote is reported as the user's bad config, without a backtrace — `2026-09-12-audit-changes-01/under-rejection#1`
- **minor** (1/13: under-rejection) Two guards the design promised are withdrawn from the contract rather than built, with the code left exactly as it was — `2026-09-12-audit-changes-01/under-rejection#2`
- **minor** (1/13: free-reader) main()'s own docstring is now false for a ConfigError, and no test covers the new branch — `2026-09-12-audit-changes-01/free-reader#1`
- **minor** (1/13: contract-drift) RULE.CIT.NO_INACCESSIBLE's check now names a src-only scan whose canonical rule is a different one, so a policy waiver of either rule misses — `2026-09-12-audit-changes-01/contract-drift#3`
- **minor** (1/13: behaviour-change) The prose-shape ratchet's ceilings were raised in the same commit as the prose they measure — `2026-09-12-audit-changes-01/behaviour-change#2`
- **minor** (1/13: over-rejection) The Step-0 import design was narrowed to the CLI's restriction instead of the CLI being fixed — `2026-09-12-audit-changes-01/over-rejection#1`
- **minor** (1/13: claim-versus-edit) c7db4e5's own itemized claim omits two of its own files — `2026-09-12-audit-changes-01/claim-versus-edit#1`
- **minor** (1/13: contract-drift) Removing ORPHAN from D10 left a dangling article: the paragraph now reads "or live. An A lane file no roster entry expects..." — `2026-09-12-audit-changes-01/contract-drift#1`
- **minor** (1/13: public-contract) main()'s exit-code behavior changed but its own docstring still claims exit 3 unconditionally — `2026-09-12-audit-changes-01/public-contract#1`
- **minor** (1/13: sweep-completeness) The new 'consumer' glossary link was swept to three guide pages but not to the two others that use the same unglossed term — `2026-09-12-audit-changes-01/sweep-completeness#1`
- **minor** (1/13: contract-drift) The new PINNED/MANAGED taxonomy files the sync sidecar `.gbg/managed.json` under "the tool never renders", which `gbg sync` rewrites on every run — `2026-09-12-audit-changes-01/contract-drift#2`
- **minor** (1/13: under-rejection) The prose-shape ratchet is re-recorded in the same commit as the growth it would have caught, and one paragraph crosses the rule's own 120-word cap under cover of it — `2026-09-12-audit-changes-01/under-rejection#3`
- **minor** (1/13: sweep-completeness) ARCHITECTURE.md now says round import needs a config the CLI does not yet allow skipping, but IMPLEMENTATION.md's Phase 2 plan still asserts the old, false claim — `2026-09-12-audit-changes-01/sweep-completeness#2`
- **minor** (1/13: behaviour-change) Main's blanket ConfigError catch also reclassifies mid-verb failures, after side effects, as exit 2 — `2026-09-12-audit-changes-01/behaviour-change#1`
- **minor** (1/13: over-rejection) RULE.INST.CARRY's new CARRY_LIMIT clause names the release refusal and hides the close refusal — `2026-09-12-audit-changes-01/over-rejection#2`
- **nit** (1/13: contract-drift) verify-act.js's rewritten args header drops `round_dir`, which the CLI always sends, and adds `batch?`, which no CLI path ever sends — `2026-09-12-audit-changes-01/contract-drift#4`
- **nit** (1/13: over-rejection) The prose-span guard dropped the `of` exemption that no defect implicated — `2026-09-12-audit-changes-01/over-rejection#3`
- **nit** (1/13: contract-drift) The signature-types measurement was replaced by "a handful" while the ID_RESOLVES counts beside it were kept as a dated snapshot — `2026-09-12-audit-changes-01/contract-drift#5`
