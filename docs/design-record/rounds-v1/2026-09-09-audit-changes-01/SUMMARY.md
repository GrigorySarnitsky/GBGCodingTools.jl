# SUMMARY — 2026-09-09-audit-changes-01 (a reading aid, never the input to a fix pass)

49 findings banked, 0 seeded (subtracted below), 49 distinct after deduplication by title; ranked by severity × corroboration (k of 13 lanes).

Capped lanes (candidates_found > reported; re-run narrowed if needed): over-rejection, contract-drift, behaviour-change, executing, under-rejection, public-contract

- **blocker** (1/13: executing) The tally schema now validates per_id entries, and the state Passes.grade writes for a witness-verified bug-hunt finding is outside its enum — every such grade throws — `2026-09-09-audit-changes-01/executing#1`
- **blocker** (1/13: contract-drift) The latex-typesetter hat lost the only lawful copy of its own authoritative rulebook — `2026-09-09-audit-changes-01/contract-drift#1`
- **major** (1/13: behaviour-change) SCAN.SIBLING_LINK, a hard scan, now also fails a LATER linked mention — prose that passed before now blocks the docs build — `2026-09-09-audit-changes-01/behaviour-change#2`
- **major** (1/13: executing) Dropping `rulebook` from the latex-typesetter hat's needs forbids it the very file its persona is told to treat as authoritative — `2026-09-09-audit-changes-01/executing#2`
- **major** (1/13: over-rejection) SCAN.SIBLING_LINK gains a second, hard-tier refusal the frozen catalogue row does not declare and no fixture falsifies — `2026-09-09-audit-changes-01/over-rejection#1`
- **major** (1/13: claim-versus-edit) 175fe95 silently added a new hard-fail validation to bank() that no claim in its own message names, and it was broken on arrival — `2026-09-09-audit-changes-01/claim-versus-edit#1`
- **major** (1/13: contract-drift) CFG.SURFACES quietly stopped promising that `docs_build` names docs/make.jl — `2026-09-09-audit-changes-01/contract-drift#3`
- **major** (1/13: under-rejection) SCAN.MATHBF hardcodes `\mathbf{1}` into the allowed set, making `notation.mathbf_allowed` partly inert and this package's own empty list a lie — `2026-09-09-audit-changes-01/under-rejection#3`
- **major** (1/13: sweep-completeness) New .gbg/-containment grep-scoping guard swept into 2 of ~9 workflow scripts that need it — `2026-09-09-audit-changes-01/sweep-completeness#1`
- **major** (1/13: under-rejection) The latex-typesetter hat lost its `rulebook` need, so it is no longer handed the rulebook its persona orders it to read first — `2026-09-09-audit-changes-01/under-rejection#4`
- **major** (1/13: contract-drift) SCAN.PROSE_SHAPE's "caps bind ALWAYS" weakened to match unchanged code, leaving the rule register saying "always" — `2026-09-09-audit-changes-01/contract-drift#4`
- **major** (1/13: over-rejection) The new Workflow-script backtick test rejects any short plain template literal, not just a bare code span inside a prompt — `2026-09-09-audit-changes-01/over-rejection#3`
- **major** (1/13: behaviour-change) SCAN.MATHBF now admits \mathbf{1} unconditionally, so notation.mathbf_allowed no longer controls the scan it names — `2026-09-09-audit-changes-01/behaviour-change#4`
- **major** (1/13: contract-drift) SCAN.SIBLING_LINK gained a second hard-tier hit class that no catalogue row, architecture row or fixture records — `2026-09-09-audit-changes-01/contract-drift#6`
- **major** (1/13: executing) SCAN.MATHBF now hard-codes `\mathbf{1}` over the consumer's configured mathbf_allowed, and only one of the four places that state the contract was amended — `2026-09-09-audit-changes-01/executing#3`
- **major** (1/13: contract-drift) RULE.DOC.HOME_ORDER reordered fleet-wide, with both judging personas rewritten to the new order in the same commit — `2026-09-09-audit-changes-01/contract-drift#5`
- **major** (1/13: executing) Raising the ledger reason bound from 24 to 40 in the schema turns a reported CFG.EXEMPTIONS failure into a crash of sync, scan and the docs build — `2026-09-09-audit-changes-01/executing#4`
- **major** (1/13: behaviour-change) SCAN.ARGS_FORM now parses a different parameter list and counts splats, inverting its verdict on docstrings that were clean — `2026-09-09-audit-changes-01/behaviour-change#1`
- **major** (1/13: over-rejection) A ledger reason of 24-39 characters turns from one doctor FAIL into an exit-3 crash of every ledger-reading verb — `2026-09-09-audit-changes-01/over-rejection#2`
- **major** (1/13: behaviour-change) RULE.DOC.HOME_ORDER reorders the docstring skeleton fleet-wide: a docstring that obeyed the rule now violates it — `2026-09-09-audit-changes-01/behaviour-change#5`
- **major** (1/13: under-rejection) The requirement that `docs_build` name `docs/make.jl` was deleted from the specification instead of being implemented — `2026-09-09-audit-changes-01/under-rejection#5`
- **major** (1/13: contract-drift) A scan that measured nothing is no longer DEAD when it has hits, contradicting its own field docstring — `2026-09-09-audit-changes-01/contract-drift#2`
- **major** (1/13: under-rejection) The DEAD-scan refusal gained a conjunct: a scan whose population counter reads zero no longer stops the run when it happens to have hits — `2026-09-09-audit-changes-01/under-rejection#1`
- **major** (1/13: behaviour-change) exemptions.schema.json reason minLength 24 -> 40 turns a doctor FAIL into a thrown LedgerError in every verb that reads the ledger — `2026-09-09-audit-changes-01/behaviour-change#3`
- **major** (1/13: under-rejection) SCAN.FIELD_DOCS now counts structs it could say nothing about, defeating the vacuous-pass guard its own header still describes — `2026-09-09-audit-changes-01/under-rejection#2`
- **major** (1/13: numerics) exemptions.schema.json reason minLength raised 24→40 turns a graceful per-entry FAIL into a whole-ledger crash — `2026-09-09-audit-changes-01/numerics#1`
- **minor** (1/13: over-rejection) The new RULES.toml test forbids a rule from declaring a mechanical check alongside `panel`, `session` or `weakness` — `2026-09-09-audit-changes-01/over-rejection#6`
- **minor** (1/13: behaviour-change) The DEAD guard now yields to hits: a scan that measured nothing but hit returns exit 1 instead of exit 2 — `2026-09-09-audit-changes-01/behaviour-change#7`
- **minor** (1/13: executing) SCAN.SIBLING_LINK gained a second, hard-tier hit class, so a page that links a sibling package twice now fails the docs build where it passed — `2026-09-09-audit-changes-01/executing#8`
- **minor** (1/13: over-rejection) Moving the signature_fidelity population counter past the EXTENSION-HOMED branch turns a clean all-extension package into exit 2, and the paired `isempty(hits)` relaxation cannot rescue it — `2026-09-09-audit-changes-01/over-rejection#5`
- **minor** (1/13: contract-drift) A ledger reason of 24-39 characters now makes the whole toolchain throw instead of the doctor reporting it — `2026-09-09-audit-changes-01/contract-drift#7`
- **minor** (1/13: over-rejection) bank's new core-finding validation throws instead of returning 2, and fires after the panel and the witness runner have already been paid for — `2026-09-09-audit-changes-01/over-rejection#8`
- **minor** (1/13: claim-versus-edit) Three JSON schemas were tightened inside 175fe95 (a doc-fix commit) with no claim naming them, one of them changing a live crash-vs-report boundary — `2026-09-09-audit-changes-01/claim-versus-edit#2`
- **minor** (1/13: sweep-completeness) IMPLEMENTATION.md still claims 'eighteen schemas' and names two files this diff's own D11 rewrite says don't exist — `2026-09-09-audit-changes-01/sweep-completeness#3`
- **minor** (1/13: behaviour-change) managed.schema.json and tally.schema.json close their open maps, so a sidecar or tally that validated now throws — `2026-09-09-audit-changes-01/behaviour-change#6`
- **minor** (1/13: contract-drift) resolve_function's search-order promise was rewritten to match a resolution order that shadows package functions — `2026-09-09-audit-changes-01/contract-drift#8`
- **minor** (1/13: under-rejection) The new rule-check oracle verifies a `harness:` binding by bare substring — the exact match the same file's other test was narrowed to reject — `2026-09-09-audit-changes-01/under-rejection#7`
- **minor** (1/13: under-rejection) RULE.DOC.SHAPE is registered as mechanically checked in the same commit that records the check does not enforce it on baselined page units — `2026-09-09-audit-changes-01/under-rejection#6`
- **minor** (1/13: reader-consequence) New SCAN.ARGS_FORM enforces a narrower exemption set than the standing RULE.DOC.ARGS_FORM promise — `2026-09-09-audit-changes-01/reader-consequence#1`
- **minor** (1/13: executing) The CFG.SURFACES contract row was rewritten to drop the `docs_build names docs/make.jl` clause while check_paths is byte-identical, and the parallel julia_test clause was left in place — `2026-09-09-audit-changes-01/executing#5`
- **minor** (1/13: executing) The new coverage assertion is wider than the defect: it rejects any interpolation-free template literal in a Workflow script, valid JS included — `2026-09-09-audit-changes-01/executing#7`
- **minor** (1/13: behaviour-change) signature_fidelity stops counting extension-homed bindings, so its population can now fall to zero and mark the scan DEAD — `2026-09-09-audit-changes-01/behaviour-change#8`
- **minor** (1/13: executing) The prose-shape cap contract was rewritten from `Caps bind ALWAYS` to `docstrings and NEW page units only` with the scan code untouched, and the rule it implements still says always — `2026-09-09-audit-changes-01/executing#6`
- **minor** (1/13: public-contract) gbg scan's DEAD/exit-code semantics changed for the population==0-with-hits case — `2026-09-09-audit-changes-01/public-contract#1`
- **minor** (1/13: numerics) signature_fidelity's `examined` counter now silently excludes extension-homed bindings, with no test locking in either value — `2026-09-09-audit-changes-01/numerics#2`
- **minor** (1/13: over-rejection) The schema-coverage test now accepts only two spellings of "a schema is loaded", so a legitimate loader fails it — `2026-09-09-audit-changes-01/over-rejection#7`
- **minor** (1/13: over-rejection) SCAN.ARGS_FORM double-counts a TYPED splat, so a two-argument prose docstring is now told to use bullets — `2026-09-09-audit-changes-01/over-rejection#4`
- **minor** (1/13: sweep-completeness) New module-level glossary duplicates its own 'hat' definition verbatim, unlinked, in the one sibling site the same diff didn't sweep — `2026-09-09-audit-changes-01/sweep-completeness#2`
- **nit** (1/13: under-rejection) SCAN.ARGS_FORM's type exemption was widened from a literal to a whitespace-tolerant regex, skipping docstrings it previously judged — `2026-09-09-audit-changes-01/under-rejection#8`
