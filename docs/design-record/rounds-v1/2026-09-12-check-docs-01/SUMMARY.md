# SUMMARY — 2026-09-12-check-docs-01 (a reading aid, never the input to a fix pass)

37 findings banked, 0 seeded (subtracted below), 37 distinct after deduplication by title; ranked by severity × corroboration (k of 16 lanes).

Capped lanes (candidates_found > reported; re-run narrowed if needed): pages, rationale-2, cold-reader, src, one-home, templates, operational-claims, catalogues, schemas

- **blocker** (1/16: workflow-scripts) Unescaped backtick breaks the template literal, so the script fails to parse — `2026-09-12-check-docs-01/workflow-scripts#1`
- **major** (1/16: workflow-scripts) The per-lane finding SCHEMA is looser than the shape `gbg round bank` enforces, so schema-valid output can still fail bank — `2026-09-12-check-docs-01/workflow-scripts#5`
- **major** (1/16: cold-reader) "pinned file" (as opposed to "managed file") is never defined in any docstring at all — `2026-09-12-check-docs-01/cold-reader#2`
- **major** (1/16: cold-reader) Half the act/state verdict vocabulary is glossed, half is bare, in the same enumeration — `2026-09-12-check-docs-01/cold-reader#3`
- **major** (1/16: rationale-2) GIT.TRAILER's doctor-table severity contradicts the deliberately-implemented code — `2026-09-12-check-docs-01/rationale-2#1`
- **major** (1/16: rationale) §3's tree places `Scan.jl` under `src/CLI/`, but it lives at `src/Scan.jl` — `2026-09-11-check-docs-01/rationale#1`
- **major** (1/16: cold-reader) "managed file" is used as a settled term of art well before it is ever defined — `2026-09-12-check-docs-01/cold-reader#1`
- **major** (1/16: one-home) policy/RULES.toml's one-line statement for RULE.INST.CARRY drops one of the three real release-blocking conditions — `2026-09-12-check-docs-01/one-home#2`
- **major** (1/16: rulebook) RULE.DOC.SHAPE's "`# Arguments` precedes any column-0 admonition" clause names a heading form no other rule in this package's rubric ever produces — `2026-09-11-check-docs-02/rulebook#2`
- **major** (1/16: rationale-3) The Step-0 instrument-equivalence section describes gbg round import <pile> / round compare as built, but the CLI refuses both — `2026-09-12-check-docs-01/rationale-3#1`
- **major** (1/16: rationale-2) AUDIT.GAP's doctor-table description names the wrong field (head instead of closed_head) — `2026-09-12-check-docs-01/rationale-2#2`
- **major** (1/16: workflow-scripts) dismissals.js and verify-architecture.js never instruct the agent to echo the finding id — `2026-09-11-check-docs-01/workflow-scripts#2`
- **major** (1/16: rationale-3) gbg round import is claimed to need no .gbg/config.toml and to run self verify first, but cmd_round requires the config unconditionally and import_empty never calls self_verify — `2026-09-12-check-docs-01/rationale-3#2`
- **major** (1/16: one-home) Three scans that enforce two rules each have their second rule silently dropped from catalog/scans.toml and, for two of the three, from policy/RULES.toml's `check` field too — `2026-09-12-check-docs-01/one-home#1`
- **major** (1/16: workflow-scripts) rubric-audit.js and attack-design.js are never invoked by any CLI verb — `2026-09-11-check-docs-01/workflow-scripts#1`
- **major** (1/16: rationale) D10's round-lane 'ORPHAN' classification has no implementation — `2026-09-12-check-docs-01/rationale#3`
- **major** (1/16: src) A malformed or unreadable .gbg/config.toml crashes most verbs (exit 3) instead of exit 2 — `2026-09-12-check-docs-01/src#1`
- **major** (1/16: rulebook) RULE.CIT.DOI's check field says "weakness" but a hard-tier scan already enforces it — `2026-09-11-check-docs-02/rulebook#1`
- **minor** (1/16: workflow-scripts) verify-act.js's `mode: 'batches'` branch is dead code — no caller ever sets it — `2026-09-11-check-docs-02/workflow-scripts#1`
- **minor** (1/16: src) close()'s docstring documents `carry` outside its own bulleted "The arguments are:" list, mixing forms — `2026-09-12-check-docs-01/src#2`
- **minor** (1/16: schemas) config.schema.json permits two consumer knobs no engine ever reads — `2026-09-12-check-docs-01/schemas#1`
- **minor** (1/16: workflow-scripts) hunt.js redeclares `laneFile`, shadowing the prelude's shared helper of the same name — `2026-09-12-check-docs-01/workflow-scripts#4`
- **minor** (1/16: rationale-3) Historical measurement lines (e.g. SCAN.ID_RESOLVES's 964/11, SIGNATURE_MIRROR's 247/251) are stated as bare current-reading facts with no reproducible current-tree pointer — `2026-09-12-check-docs-01/rationale-3#3`
- **minor** (1/16: pages) config.md undercounts the package-specific config values by one — `2026-09-12-check-docs-01/pages#1`
- **minor** (1/16: workflow-scripts) attack-design.js cites a 'nine defects' figure with no corroborating source in the repository — `2026-09-12-check-docs-01/workflow-scripts#6`
- **minor** (1/16: workflow-scripts) severity-recheck.js and attack-design.js write A.round without validating it was supplied — `2026-09-11-check-docs-01/workflow-scripts#3`
- **minor** (1/16: workflow-scripts) Inconsistent 'refuse on an empty item list' guard across the eleven scripts — `2026-09-11-check-docs-02/workflow-scripts#2`
- **minor** (1/16: workflow-scripts) Header 'Args' comments have drifted from the scripts' actual required or used parameters — `2026-09-12-check-docs-01/workflow-scripts#3`
- **minor** (1/16: catalogues) SCAN.DOI_CROSSCHECK's catalogued rule omits RULE.CIT.DOI, which RULES.toml and the scan's own comment attribute to it — `2026-09-12-check-docs-01/catalogues#1`
- **minor** (1/16: rationale) Cited docstring/argument counts are stale against the current source — `2026-09-12-check-docs-01/rationale#1`
- **minor** (1/16: pages) "consumer" is used repeatedly across the pages surface without ever being defined or @ref-linked — `2026-09-12-check-docs-01/pages#2`
- **minor** (1/16: workflow-scripts) verify-state.js carries a copy-pasted comment referencing STRATEGY, a concept it does not have — `2026-09-12-check-docs-01/workflow-scripts#2`
- **minor** (1/16: templates) README's "Managed headers" rule (first-line header, one exception) is false for SKILL.md.tmpl — `2026-09-12-check-docs-01/templates#1`
- **minor** (1/16: ext) gate_or_skip's printed signature omits the type the method actually declares — `2026-09-11-check-docs-02/ext#1`
- **minor** (1/16: rationale) Instrument schema.json does not $ref schema/finding.schema.json as described — `2026-09-12-check-docs-01/rationale#2`
- **nit** (1/16: operational-claims) Rounds module docstring says rerun "re-launches" dead lanes; it only prints the call — `2026-09-12-check-docs-01/operational-claims#1`
- **nit** (1/16: cold-reader) "swept" is used in Passes' docstring one module before it is defined in Demote's — `2026-09-12-check-docs-01/cold-reader#4`
