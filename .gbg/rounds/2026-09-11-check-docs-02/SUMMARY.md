# SUMMARY — 2026-09-11-check-docs-02 (a reading aid, never the input to a fix pass)

31 findings banked, 0 seeded (subtracted below), 31 distinct after deduplication by title; ranked by severity × corroboration (k of 13 lanes).

Capped lanes (candidates_found > reported; re-run narrowed if needed): rationale, cold-reader, src, rulebook, built-html, templates, operational-claims

- **major** (1/13: cold-reader) "the economy model" used as a settled term across three modules but never defined; it is actually an AI-model swap — `2026-09-11-check-docs-02/cold-reader#1`
- **major** (1/13: rationale) check-docs seeding contradicts the doc's 'seeds live inside the project' claim; undocumented — `2026-09-11-check-docs-02/rationale#1`
- **major** (1/13: templates) commit-message.tmpl asserts a `.claude/commands/` replacement the tool never performs — `2026-09-11-check-docs-02/templates#1`
- **major** (1/13: cold-reader) "act verifier" / "state verifier" and the HONORED/LINE-ONLY verdict vocabulary are used with no definition anywhere in the source — `2026-09-11-check-docs-01/cold-reader#1`
- **major** (1/13: workflow-scripts) severity-recheck.js and attack-design.js write A.round without validating it was supplied — `2026-09-11-check-docs-01/workflow-scripts#3`
- **major** (1/13: built-html) verbs.html promises every verb is rendered from its own docstring, but three verbs' docstrings are missing from the entire built site — `2026-09-11-check-docs-02/built-html#1`
- **major** (1/13: workflow-scripts) dismissals.js and verify-architecture.js never instruct the agent to echo the finding id — `2026-09-11-check-docs-01/workflow-scripts#2`
- **major** (1/13: src) Docstrings across src cite ARCHITECTURE.md section numbers, which RULE.DOC.NO_DEAD_REFS forbids — `2026-09-11-check-docs-02/src#1`
- **major** (1/13: operational-claims) classify_lane checks REJECTED (sha-changed) before any DEAD content check, and the last DEAD branch never quarantines the file — both contradicting the docstring's ordering and blanket rename claim — `2026-09-11-check-docs-02/operational-claims#1`
- **major** (1/13: operational-claims) report()'s DEAD predicate requires exempted == 0, silently contradicting the docstrings' claim that a zero-population scan is DEAD 'whatever else it did' — `2026-09-11-check-docs-02/operational-claims#2`
- **major** (1/13: rationale) Schema/file inventory stale and self-contradictory: 'eighteen' (D11) vs 'sixteen' (§3) vs 22 actual — `2026-09-11-check-docs-02/rationale#2`
- **major** (1/13: rulebook) RULE.CIT.DOI's check field says "weakness" but a hard-tier scan already enforces it — `2026-09-11-check-docs-02/rulebook#1`
- **minor** (1/13: workflow-scripts) verify-act.js's `mode: 'batches'` branch is dead code — no caller ever sets it — `2026-09-11-check-docs-02/workflow-scripts#1`
- **minor** (1/13: cold-reader) "the four closure channels" named in the module map before any of the four are named — `2026-09-11-check-docs-02/cold-reader#4`
- **minor** (1/13: operational-claims) resolve_hats' docstring enumerates 'the four fields below' but the returned hat dict carries a fifth, undocumented field ('role') that is also never propagated onward — `2026-09-11-check-docs-02/operational-claims#3`
- **minor** (1/13: built-html) TestHarness module map omits `traffic_completeness`, the twin of the map's own `allocation_completeness` entry — `2026-09-11-check-docs-02/built-html#2`
- **minor** (1/13: templates) README.md's 'Managed headers' section omits the begin/end block convention it should describe — `2026-09-11-check-docs-02/templates#2`
- **minor** (1/13: rulebook) RULE.DOC.SHAPE's "`# Arguments` precedes any column-0 admonition" clause names a heading form no other rule in this package's rubric ever produces — `2026-09-11-check-docs-02/rulebook#2`
- **minor** (1/13: cold-reader) "the rubric" used as a proper-noun term of art but never bound to anything in source — `2026-09-11-check-docs-02/cold-reader#3`
- **minor** (1/13: workflow-scripts) Inconsistent 'refuse on an empty item list' guard across the eleven scripts — `2026-09-11-check-docs-02/workflow-scripts#2`
- **minor** (1/13: cold-reader) a second economy/full axis, `cost`, is plumbed alongside `strength` with no docstring distinguishing them — `2026-09-11-check-docs-02/cold-reader#2`
- **minor** (1/13: operational-claims) abandon's docstring says open_ids becomes 'all banked ids' when no pass was graded, but the body excludes seeded findings — `2026-09-11-check-docs-02/operational-claims#4`
- **minor** (1/13: ext) "the closure gate" (a listed term of art) is named but not linked or explained at first use — `2026-09-11-check-docs-02/ext#2`
- **minor** (1/13: built-html) Config module map omits `find_root` and `check_paths`, both documented lower on the same rendered page — `2026-09-11-check-docs-02/built-html#3`
- **minor** (1/13: ext) "refuses only because a round... is open" is not what the code actually checks — `2026-09-11-check-docs-02/ext#4`
- **minor** (1/13: src) `resolve_function` docstring cites a nonexistent `Scan.report` qualified name — `2026-09-11-check-docs-02/src#2`
- **minor** (1/13: ext) gate_or_skip's printed signature omits the type the method actually declares — `2026-09-11-check-docs-02/ext#1`
- **minor** (1/13: workflow-scripts) rubric-audit.js and attack-design.js are never invoked by any CLI verb — `2026-09-11-check-docs-01/workflow-scripts#1`
- **minor** (1/13: ext) Comment cites RULE.INST.FROZEN_MIDROUND for a mechanism the rule's text does not describe — `2026-09-11-check-docs-02/ext#3`
- **minor** (1/13: templates) bump-message.tmpl's 'Managed files changed' list is every current managed file, not just the ones that changed — `2026-09-11-check-docs-02/templates#3`
- **nit** (1/13: rationale) §3's tree places `Scan.jl` under `src/CLI/`, but it lives at `src/Scan.jl` — `2026-09-11-check-docs-01/rationale#1`
