# SUMMARY — 2026-09-10-check-docs-03 (a reading aid, never the input to a fix pass)

40 findings banked, 3 seeded (subtracted below), 37 distinct after deduplication by title; ranked by severity × corroboration (k of 13 lanes).

Capped lanes (candidates_found > reported; re-run narrowed if needed): rationale, pages, workflow-scripts, cold-reader, src, ext, rulebook, operational-claims, catalogues, schemas

- **blocker** (1/13: rationale) ARCHITECTURE.md claims makedocs "error()s on any non-zero return"; code SKIPS (exit 0) on a frozen docs round — `2026-09-10-check-docs-03/rationale#1`
- **major** (1/13: operational-claims) close()'s "2 on a stamp mismatch" is true for only one of three stamp mismatches — `2026-09-10-check-docs-03/operational-claims#2`
- **major** (1/13: cold-reader) `anchor` carries three unrelated technical senses, none flagged as overloaded at its first (or second) use — `2026-09-10-check-docs-03/cold-reader#1`
- **major** (1/13: pages) index.md mischaracterizes TestHarness's oracle engine as requiring "an independent reference" for every operation — `2026-09-10-check-docs-03/pages#2`
- **major** (1/13: workflow-scripts) verify-act.js's mode=batches guard claims full coverage but only checks that the batches array is non-empty — `2026-09-10-check-docs-03/workflow-scripts#4`
- **major** (1/13: workflow-scripts) Every one of the 11 workflow scripts writes A.schema_version into its banked artifact without validating it was supplied — `2026-09-10-check-docs-03/workflow-scripts#2`
- **major** (1/13: operational-claims) classify_lane()'s enumerated :dead causes omit the zero-findings/empty-checked[] case — `2026-09-10-check-docs-03/operational-claims#3`
- **major** (1/13: rulebook) 00-index.md says "Four values vary by package" but the templates carry five — `2026-09-10-check-docs-03/rulebook#1`
- **major** (1/13: schemas) tally.schema.json's per_id.state enum omits REFUSED, a real witness status, so grade can crash — `2026-09-10-check-docs-03/schemas#1`
- **major** (1/13: operational-claims) grade()'s exit-code contract omits the pending_state exit-1 case — `2026-09-10-check-docs-03/operational-claims#1`
- **major** (1/13: rationale) ARCHITECTURE.md attributes package_operations() to TestHarness, but the code defines/exports it from Reflection — `2026-09-10-check-docs-03/rationale#2`
- **major** (1/13: workflow-scripts) verify-act.js and verify-state.js read A.package at top level without guarding it, unlike sibling verify-architecture.js — `2026-09-10-check-docs-03/workflow-scripts#1`
- **major** (1/13: cold-reader) "the quick doctor set" is used as settled terminology 16 files before `QUICK` is defined — `2026-09-10-check-docs-03/cold-reader#2`
- **major** (1/13: workflow-scripts) rubric-audit.js's Blind-run pipeline stage converts a dead agent into a truthy 'reported nothing' result, so a dead hat is never flagged dead — `2026-09-10-check-docs-03/workflow-scripts#3`
- **minor** (1/13: schemas) pass.schema.json's probe_open is declared but never written by any code path — `2026-09-10-check-docs-03/schemas#3`
- **minor** (1/13: catalogues) Three rulebook hats call rulebook-section access a `substrate`, which the catalogue defines as something else — `2026-09-10-check-docs-03/catalogues#1`
- **minor** (1/13: cold-reader) `Recall`'s module docstring uses `substrate`, `siteonly` and `roster` a file before `Preflight` defines them — `2026-09-10-check-docs-03/cold-reader#3`
- **minor** (1/13: operational-claims) prepare()'s docstring documents seeding for check-consistency but is silent on the identical behaviour for check-docs — `2026-09-10-check-docs-03/operational-claims#9`
- **minor** (1/13: workflow-scripts) hunt.js's free-lane preamble never explains candidates_found, unlike the territory-lane preamble — `2026-09-10-check-docs-03/workflow-scripts#7`
- **minor** (1/13: pages) rounds.md's demotion rule names only half of the actual trigger condition — `2026-09-10-check-docs-03/pages#3`
- **minor** (1/13: src) pass_scope's docstring omits the unconditional-suspect branch for location-less findings — `2026-09-10-check-docs-03/src#2`
- **minor** (1/13: cold-reader) "surface" is used from its very first appearance as a package concept but never itself defined — `2026-09-10-check-docs-03/cold-reader#4`
- **minor** (1/13: operational-claims) cmd_install()'s "Returns 0 when both files are written" is false for the default invocation — `2026-09-10-check-docs-03/operational-claims#5`
- **minor** (1/13: operational-claims) bank()'s "Any DEAD lane ⇒ exit 2" undercounts what actually blocks banking — `2026-09-10-check-docs-03/operational-claims#6`
- **minor** (1/13: operational-claims) init()'s unconditional refusal of an existing config.toml does not hold under --dry-run — `2026-09-10-check-docs-03/operational-claims#8`
- **minor** (1/13: operational-claims) release()'s closure criterion understates what cites_round() actually accepts — `2026-09-10-check-docs-03/operational-claims#7`
- **minor** (1/13: schemas) audit.schema.json declares staleness and severity_recheck, but nothing ever writes them — `2026-09-10-check-docs-03/schemas#2`
- **minor** (1/13: built-html) RULE.DOC.STEER's template sentence leaves a literal unresolved Markdown link in the rendered page — `2026-09-10-check-docs-03/built-html#1`
- **minor** (1/13: workflow-scripts) Four sibling scripts each require a schema arg they never read in the script body — `2026-09-10-check-docs-03/workflow-scripts#5`
- **minor** (1/13: src) the top-level module map's 'The engines:' list omits Consolidate, paired with HtmlWalker everywhere else — `2026-09-10-check-docs-03/src#3`
- **minor** (1/13: src) cites_round's docstring omits the legitimate 'carried' closure channel — `2026-09-10-check-docs-03/src#1`
- **minor** (1/13: ext) check() docstring signature omits the method's explicit argument types — `2026-09-10-check-docs-03/ext#1`
- **nit** (1/13: schemas) carried.schema.json alone declares JSON Schema draft-07 while every sibling schema declares 2020-12 — `2026-09-10-check-docs-03/schemas#4`
- **nit** (1/13: catalogues) hats/README.md documents a `{policy.<file>}` placeholder no generic hat ever uses — `2026-09-10-check-docs-03/catalogues#2`
- **nit** (1/13: operational-claims) page_bindings()'s docstring omits the id-attribute fallback the code actually uses — `2026-09-10-check-docs-03/operational-claims#10`
- **nit** (1/13: catalogues) check-docs.toml's `family` lane names itself "CHECK 7", a number the catalogue never defines — `2026-09-10-check-docs-03/catalogues#3`
- **nit** (1/13: workflow-scripts) verify-act.js threads the CLI-computed 'expected' verdict count into each unit but never uses it as a completeness check — `2026-09-10-check-docs-03/workflow-scripts#6`
