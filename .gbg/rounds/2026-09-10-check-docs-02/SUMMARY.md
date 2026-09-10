# SUMMARY — 2026-09-10-check-docs-02 (a reading aid, never the input to a fix pass)

39 findings banked, 2 seeded (subtracted below), 37 distinct after deduplication by title; ranked by severity × corroboration (k of 13 lanes).

Capped lanes (candidates_found > reported; re-run narrowed if needed): rationale, cold-reader, src, ext, rulebook, operational-claims, schemas

- **blocker** (1/13: catalogues) The catalogues surface assigned to this lane is entirely absent from the round's ground-truth checkout — `2026-09-10-check-docs-02/catalogues#1`
- **blocker** (1/13: built-html) Assigned surface docs/build does not exist in the round's ground truth — dead lane, not a clean one — `2026-09-10-check-docs-02/built-html#1`
- **blocker** (1/13: templates) This lane's assigned surface was not included in the round's ground-truth checkout — `2026-09-10-check-docs-02/templates#1`
- **blocker** (1/13: workflow-scripts) The whole workflow-scripts surface is absent — nothing on this lane can be evaluated — `2026-09-10-check-docs-02/workflow-scripts#1`
- **major** (1/13: src) release()'s closing condition for the cited rc round is narrower than what cites_round actually accepts — `2026-09-10-check-docs-02/src#5`
- **major** (1/13: operational-claims) Rounds.close: "2 on a stamp mismatch" is true for only one of three stamp mismatches — `2026-09-10-check-docs-02/operational-claims#1`
- **major** (1/13: cold-reader) 'bank' is used as a load-bearing term of art in four docstrings before any docstring defines it — `2026-09-10-check-docs-02/cold-reader#1`
- **major** (1/13: rationale) D9 and §7.3 describe makedocs as erroring on any gate failure; the code silently skips the build instead when a docs round is open — `2026-09-10-check-docs-02/rationale#1`
- **major** (1/13: cold-reader) A fourth, undisambiguated colloquial sense of 'anchor' appears after three technical senses were already carefully told apart — `2026-09-10-check-docs-02/cold-reader#2`
- **major** (1/13: operational-claims) Rounds.classify_lane omits the zero-findings/empty-checked path to :dead — `2026-09-10-check-docs-02/operational-claims#3`
- **major** (1/13: src) makedocs docstring claims every non-zero check errors, but the closure gate's non-zero return is swallowed as a skip — `2026-09-10-check-docs-02/src#2`
- **major** (1/13: src) pass_open's displayed signature omits its real full_state keyword — `2026-09-10-check-docs-02/src#1`
- **major** (1/13: pages) index.md links to headings that do not exist anywhere in the docs source — `2026-09-10-check-docs-02/pages#1`
- **major** (1/13: operational-claims) Release.release: cites_round's closure test is narrower in the docstring than in the code — `2026-09-10-check-docs-02/operational-claims#2`
- **major** (1/13: operational-claims) Rounds.seed_docs_corpus! has two distinct exit-2 paths but the docstring names only one — `2026-09-10-check-docs-02/operational-claims#4`
- **major** (1/13: schemas) Design record and a source comment wrongly claim per-instrument schemas $ref finding.schema.json — `2026-09-10-check-docs-02/schemas#2`
- **major** (1/13: src) demote()'s rendered docstring cites a bare section number, which RULE.DOC.NO_DEAD_REFS forbids — `2026-09-10-check-docs-02/src#3`
- **major** (1/13: rulebook) LEADING_IDENTITY deviation claims a parameterisation escape hatch that does not exist — `2026-09-10-check-docs-02/rulebook#1`
- **major** (1/13: src) gbg selftest --pinned's docstring claims it runs the QUICK doctor, but the code runs a bespoke narrower selection — `2026-09-10-check-docs-02/src#4`
- **major** (1/13: schemas) The assigned surface directory schema/ is absent from this round's /tmp snapshot — `2026-09-10-check-docs-02/schemas#1`
- **minor** (1/13: operational-claims) Git.changed_paths's docstring doesn't flag that an empty `paths` means UNRESTRICTED, not "no paths" — `2026-09-10-check-docs-02/operational-claims#6`
- **minor** (1/13: src) formula_in_backticks.jl's comment misstates its own regex's real false positives — `2026-09-10-check-docs-02/src#7`
- **minor** (1/13: src) SCAN.XLINK's suggested manual fix uses a different link form than Reflection.xlink's own auto-apply — `2026-09-10-check-docs-02/src#6`
- **minor** (1/13: src) apply_ledger's docstring overstates when a scan-scope wildcard entry fully disables a scan — `2026-09-10-check-docs-02/src#9`
- **minor** (1/13: ext) check()'s docstring signature omits the method's argument types — `2026-09-10-check-docs-02/ext#3`
- **minor** (1/13: rulebook) STEER and RETURNS are mechanically checkable rules with no scan implementing them — `2026-09-10-check-docs-02/rulebook#3`
- **minor** (1/13: operational-claims) Install.cmd_install: "Returns 0 when both files are written" overstates the normal (no --dev-checkout) path — `2026-09-10-check-docs-02/operational-claims#5`
- **minor** (1/13: rulebook) FULL_INLINE's unconditional 'one bullet per work' contradicts BLOCK_LIST's lone-citation form — `2026-09-10-check-docs-02/rulebook#2`
- **minor** (1/13: rationale) D5's list of supported JSON-Schema-subset keywords omits minLength/minimum/maximum, which Schema.jl already validates — `2026-09-10-check-docs-02/rationale#2`
- **minor** (1/13: ext) Module docstring uses the term of art "consumer" unglossed and unlinked — `2026-09-10-check-docs-02/ext#2`
- **minor** (1/13: cold-reader) 'act verifier' / 'state verifier' are introduced as already-known jargon in a single dense docstring with no prior binding — `2026-09-10-check-docs-02/cold-reader#3`
- **minor** (1/13: operational-claims) Fleet's docstrings enumerate four row statuses; the code produces a fifth ("MISSING") — `2026-09-10-check-docs-02/operational-claims#7`
- **minor** (1/13: schemas) ARCHITECTURE D11's 'Sixteen schemas' enumeration omits carried.schema.json — `2026-09-10-check-docs-02/schemas#3`
- **minor** (1/13: schemas) carried.schema.json alone declares JSON Schema draft-07 instead of 2020-12 — `2026-09-10-check-docs-02/schemas#4`
- **minor** (1/13: src) Fleet.rows' MISSING status is never named in either docstring's enumeration — `2026-09-10-check-docs-02/src#8`
- **nit** (1/13: operational-claims) Audit.audit_bank's "afterwards it prints the severity re-check" is conditional, not unconditional — `2026-09-10-check-docs-02/operational-claims#8`
- **nit** (1/13: src) cmd_install's docstring overstates that success always means two files were written — `2026-09-10-check-docs-02/src#10`
