# SUMMARY — 2026-09-15-audit-changes-01 (a reading aid, never the input to a fix pass)

42 findings banked, 0 seeded (subtracted below), 42 distinct after deduplication by title; ranked by severity × corroboration (k of 13 lanes).

Capped lanes (candidates_found > reported; re-run narrowed if needed): reader-consequence, over-rejection, invariants, contract-drift, behaviour-change, executing, under-rejection, public-contract, free-reader

- **major** (1/13: contract-drift) A policy waiver of a rule that a two-rule scan also enforces now throws, for any target — `2026-09-15-audit-changes-01/contract-drift#1`
- **major** (1/13: reader-consequence) install.md widens "consumer" to include the fixture, then cites the glossary as binding a definition that excludes it — `2026-09-15-audit-changes-01/reader-consequence#1`
- **major** (1/13: invariants) round.schema.json's scripts_refreshed shape was tightened with no MAJOR bump, invalidating an already-frozen closed round — `2026-09-15-audit-changes-01/invariants#1`
- **major** (1/13: executing) A policy waiver of a two-rule scan's second rule, accepted at base, now crashes gbg scan docs and the makedocs hard-scan gate with exit 3 — `2026-09-15-audit-changes-01/executing#1`
- **major** (1/13: behaviour-change) A policy waiver of RULE.DOC.API_GROUPING (or RULE.CIT.DOI / NO_INACCESSIBLE), any target, now crashes scans and fails the QUICK doctor — `2026-09-15-audit-changes-01/behaviour-change#1`
- **major** (1/13: free-reader) scripts_refreshed[] gains three required fields with no schema_version gate, breaking any round already recorded under the old 2-field contract — `2026-09-15-audit-changes-01/free-reader#1`
- **major** (1/13: free-reader) A policy waiver on a scan's non-canonical rule, previously honored (if over-broadly), now throws an uncaught LedgerError instead of failing gracefully — `2026-09-15-audit-changes-01/free-reader#2`
- **major** (1/13: under-rejection) Claim checklist floor narrowed: 140 lines gone, the backticked exit contract among them — `2026-09-15-audit-changes-01/under-rejection#2`
- **major** (1/13: over-rejection) A policy waiver of any rule some scan enforces non-canonically is now a hard error, including where that rule is canonical elsewhere or the target is not * — `2026-09-15-audit-changes-01/over-rejection#1`
- **major** (1/13: public-contract) `gbg round scripts` overhaul rejects the old invocation and can make historical round records unreadable — `2026-09-15-audit-changes-01/public-contract#2`
- **major** (1/13: numerics) CLAIM_EXIT's rewritten third alternative silently stops matching real, unchanged exit-contract prose — `2026-09-15-audit-changes-01/numerics#1`
- **major** (1/13: under-rejection) Seed-skip refusal deleted: a check-consistency round planting zero seeds now opens — `2026-09-15-audit-changes-01/under-rejection#1`
- **major** (1/13: public-contract) A previously-working exemptions.toml waiver now crashes scans instead of running — `2026-09-15-audit-changes-01/public-contract#1`
- **major** (1/13: contract-drift) FROZEN_MIDROUND gains an exception whose stated condition the verb never checks — `2026-09-15-audit-changes-01/contract-drift#2`
- **minor** (1/13: under-rejection) gbg round scripts: unchecked precondition, and replacements that leave no record — `2026-09-15-audit-changes-01/under-rejection#5`
- **minor** (1/13: under-rejection) Prose-shape ratchet raised on over-cap page units the same change set grew — `2026-09-15-audit-changes-01/under-rejection#3`
- **minor** (1/13: under-rejection) close now accepts builds from prepare and pass open, including dirty-tree builds — `2026-09-15-audit-changes-01/under-rejection#7`
- **minor** (1/13: under-rejection) gbg round build exits 0 when its ROUND.toml record fails to save — `2026-09-15-audit-changes-01/under-rejection#4`
- **minor** (1/13: behaviour-change) A check-docs round's state-verifier scope now follows check-consistency's latex_source_globs, which can only add — `2026-09-15-audit-changes-01/behaviour-change#3`
- **minor** (1/13: over-rejection) gbg round scripts <round>, the base form, is now refused without --reason, and the CLI usage line still omits the flag — `2026-09-15-audit-changes-01/over-rejection#3`
- **minor** (1/13: behaviour-change) On a root with no git HEAD, `round scripts` replaces scripts and then throws before recording anything — `2026-09-15-audit-changes-01/behaviour-change#5`
- **minor** (1/13: sweep-completeness) The 'BATCH is a constant, not an overridable arg' fix applied to verify-act.js/verify-state.js but not to severity-recheck.js's identical pattern — `2026-09-15-audit-changes-01/sweep-completeness#3`
- **minor** (1/13: sweep-completeness) install.md's broadened 'consumer' definition points at the glossary entry it contradicts — `2026-09-15-audit-changes-01/sweep-completeness#2`
- **minor** (1/13: executing) The claim-checklist narrowing drops claims of the very kinds it targets: backticked exit codes and subject—predicate clauses split at a spaced dash — `2026-09-15-audit-changes-01/executing#4`
- **minor** (1/13: executing) gbg round scripts --reason replaces the frozen scripts BEFORE refusing on a missing HEAD, so the refresh is never recorded — `2026-09-15-audit-changes-01/executing#3`
- **minor** (1/13: behaviour-change) Claim checklist narrowed past the version-string defect: about 55% of quantifier items dropped, some genuine claims with them — `2026-09-15-audit-changes-01/behaviour-change#2`
- **minor** (1/13: under-rejection) Step-0 import relaxations apply to every round and every directory — `2026-09-15-audit-changes-01/under-rejection#6`
- **minor** (1/13: behaviour-change) `gbg round scripts` needs --reason, and the schema now rejects records the base verb wrote — `2026-09-15-audit-changes-01/behaviour-change#4`
- **minor** (1/13: over-rejection) A ROUND.toml written by the base scripts verb no longer validates, making its round unloadable and every gate fatal — `2026-09-15-audit-changes-01/over-rejection#4`
- **minor** (1/13: free-reader) latex_source_globs changes from replace-when-set to always-union-with-the-four-defaults, removing any way to narrow the panel's source surface — `2026-09-15-audit-changes-01/free-reader#3`
- **minor** (1/13: executing) A seeded check-consistency round that plants NO seed now opens (exit 0); base refused it, and the check-docs path still does — `2026-09-15-audit-changes-01/executing#2`
- **minor** (1/13: contract-drift) Claim checklist's quantifier class cut by half; guide exit-contract line dropped — `2026-09-15-audit-changes-01/contract-drift#5`
- **minor** (1/13: sweep-completeness) PINNED/MANAGED reclassification of managed.json swept into 3 docstrings but left stale in 4 user-facing sites — `2026-09-15-audit-changes-01/sweep-completeness#1`
- **minor** (1/13: sweep-completeness) RULE.INST.CARRY's new round-close refusal clause reached RULES.toml and policy/instruments.md's substance but not its ARCHITECTURE.md §12.A mirror row — `2026-09-15-audit-changes-01/sweep-completeness#4`
- **minor** (1/13: over-rejection) A git root with no HEAD is newly refused by round build and round scripts, and scripts refuses only after it has already replaced the frozen copies — `2026-09-15-audit-changes-01/over-rejection#2`
- **minor** (1/13: contract-drift) round.schema tightened in place, and a tool-written record it refuses is reported as exit 2 — `2026-09-15-audit-changes-01/contract-drift#3`
- **minor** (1/13: contract-drift) latex_source_globs flipped from replacing the default surfaces to adding to them — `2026-09-15-audit-changes-01/contract-drift#4`
- **minor** (1/13: numerics) CLAIM_TOOL_ID's `gbg <verb>` alternative now requires a literal backtick, narrower than the disclosed rationale — `2026-09-15-audit-changes-01/numerics#2`
- **nit** (1/13: over-rejection) AUDIT.GAP now warns when an audit's base equals the previous closed head but that commit is unreachable — `2026-09-15-audit-changes-01/over-rejection#5`
- **nit** (1/13: executing) script_sources' docstring says a later name replaces none already taken; the code replaces it — `2026-09-15-audit-changes-01/executing#5`
- **nit** (1/13: contract-drift) A count base deliberately kept out of ARCHITECTURE is back, justified by a false 'every count' — `2026-09-15-audit-changes-01/contract-drift#6`
- **nit** (1/13: behaviour-change) AUDIT.GAP: equal base/closed-head strings now WARN when the commit is unreachable — `2026-09-15-audit-changes-01/behaviour-change#6`
