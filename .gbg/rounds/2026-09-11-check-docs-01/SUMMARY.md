# SUMMARY — 2026-09-11-check-docs-01 (a reading aid, never the input to a fix pass)

27 findings banked, 3 seeded (subtracted below), 24 distinct after deduplication by title; ranked by severity × corroboration (k of 13 lanes).

Capped lanes (candidates_found > reported; re-run narrowed if needed): rationale, cold-reader, src, rulebook, built-html, templates, operational-claims, catalogues, schemas

- **blocker** (1/13: schemas) reproduction.schema.json's disposition.state enum omits "open", the value the tool itself writes — `2026-09-11-check-docs-01/schemas#1`
- **major** (1/13: src) The package's own top-level module docstring is not a map of the module any more — `2026-09-11-check-docs-01/src#1`
- **major** (1/13: schemas) audit-changes lane_file schema requires a self-reported verdict (CLEAN/CONCERNS) that no code path ever reads — `2026-09-11-check-docs-01/schemas#2`
- **major** (1/13: catalogues) audit-changes.toml's anchor flags contradict the D18 they cite — `2026-09-11-check-docs-01/catalogues#1`
- **major** (1/13: templates) test-Project.toml.seed always writes a git rev source, breaking a dev-pinned consumer's first Pkg.instantiate() — `2026-09-11-check-docs-01/templates#2`
- **major** (1/13: cold-reader) "act verifier" / "state verifier" and the HONORED/LINE-ONLY verdict vocabulary are used with no definition anywhere in the source — `2026-09-11-check-docs-01/cold-reader#1`
- **major** (1/13: templates) SKILL.md.tmpl's shared body text is false when rendered for the gbg-doctor skill — `2026-09-11-check-docs-01/templates#1`
- **major** (1/13: templates) make.jl.seed's deploydocs-guard comment describes a check that can never distinguish its two cases — `2026-09-11-check-docs-01/templates#3`
- **major** (1/13: rulebook) RULE.DOC.ALIASING_BULLET is tagged check=["panel"] but no hat or lane names its actual (placement) requirement — `2026-09-11-check-docs-01/rulebook#2`
- **major** (1/13: rulebook) Six rules tagged check=["weakness"] are already checked by a panel, contradicting RULE.TEST.RULE_WITH_CHECK's own bar — `2026-09-11-check-docs-01/rulebook#1`
- **major** (1/13: workflow-scripts) rubric-audit.js and attack-design.js are never invoked by any CLI verb — `2026-09-11-check-docs-01/workflow-scripts#1`
- **minor** (1/13: rulebook) Five testing-protocol rules tagged check=["panel"] have no corresponding hat/lane/workflow reference in the available ground truth — `2026-09-11-check-docs-01/rulebook#3`
- **minor** (1/13: workflow-scripts) hunt.js's free-lane prompt references invariants that were never named — `2026-09-11-check-docs-01/workflow-scripts#4`
- **minor** (1/13: rationale) D9 cites `src/Scans/ProseShape.jl`, but the file is `src/Scans/prose_shape.jl` — `2026-09-11-check-docs-01/rationale#2`
- **minor** (1/13: rationale) §3's tree places `Scan.jl` under `src/CLI/`, but it lives at `src/Scan.jl` — `2026-09-11-check-docs-01/rationale#1`
- **minor** (1/13: src) apply_ledger's docstring overstates when a wildcard ledger entry disables a scan — `2026-09-11-check-docs-01/src#2`
- **minor** (1/13: catalogues) doc-policy and naming-policy carry a `source` grant their persona text never invokes — `2026-09-11-check-docs-01/catalogues#2`
- **minor** (1/13: cold-reader) "shim" is used at its first two mentions (Main.jl) before any docstring says what a shim is — `2026-09-11-check-docs-01/cold-reader#2`
- **minor** (1/13: workflow-scripts) severity-recheck.js and attack-design.js write A.round without validating it was supplied — `2026-09-11-check-docs-01/workflow-scripts#3`
- **minor** (1/13: operational-claims) makedocs docstring implies the open-round skip applies to both gate calls; only the first has it — `2026-09-11-check-docs-01/operational-claims#3`
- **minor** (1/13: workflow-scripts) dismissals.js and verify-architecture.js never instruct the agent to echo the finding id — `2026-09-11-check-docs-01/workflow-scripts#2`
- **minor** (1/13: operational-claims) bank() docstring claims reproductions/ is already written by an exit where it is not — `2026-09-11-check-docs-01/operational-claims#2`
- **nit** (1/13: src) TestHarness's module map omits its own exported counting helper — `2026-09-11-check-docs-01/src#3`
- **nit** (1/13: workflow-scripts) attack-design.js's header comment documents an args field the code never reads — `2026-09-11-check-docs-01/workflow-scripts#5`
