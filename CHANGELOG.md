# Changelog

Every tag has one entry: version, date, MAJOR | MINOR | PATCH, the instruments affected, and
"rates comparable: yes | no" (for a MAJOR, the fixture recall before and after).

## Unreleased

- Phase 1 in progress: the skeleton, the CLI, the ports (see `IMPLEMENTATION.md`).
- 1.6 consolidator acceptance (2026-09-09): `Consolidate.jl` over Gumbo produced byte-equal
  `manuscript-{full,siteonly}.md` pairs against the consumers' `consolidate.py` on PF's build (18 pages,
  1 093 435 / 410 836 chars) and IT's (22 pages, 555 623 / 484 749 chars); the Python is gone. Two
  BeautifulSoup behaviours had to be mirrored: whitespace-only text nodes are kept (Gumbo.jl drops them
  by default) and collapsed to one space, or one newline when they contain one.
- Pre-migration scan census (2026-09-09, the tool's scans run read-only over the two consumers with
  their §5 configs; no ledger yet, so every count is before adjudication — what Phases 4 and 5 will
  meet). PF hard: THIN_SPACE 3, MATHBF 23 (`\mathbf 1` unbraced, `\mathbf{k}` in the generated example
  page — now a `generated` glob in §5.1), LEFTRIGHT 1, FIELD_DOCS 3 (the `NO_FIELD_LIST` trio →
  ledger), PROSE_SHAPE 42 docstrings over the 120-word cap + 8 heading-order, AI_BANNER 1
  (`examples/gpu/rocm/HIST_ROCm.jl`); PF triage: FORMULA_IN_BACKTICKS 9, CODE_IN_MATH 3,
  CITATION_CRAMMED 1, SENTENCE_OPENER 3 (identical to `sentence_openers.py`), SIGNATURE_WIDE 3,
  ABUTTING_SPANS 137 (PF's `` `name` ``\equiv …`` `` notation idiom). IT hard: NEG_THIN_BIGL 11
  (`\exp\!\bigl(`), REF_ABUT_CODE 20 (`[`f`](@ref)`(args)``), FIELD_DOCS 39 (no `The fields are`
  lists), LINK_UNIFORMITY 1, API_PAGE_STRUCTURE 1 (`@index`), AI_BANNER 1 (`docs/ARCHITECTURE.md`),
  DOI_CROSSCHECK 26 (all in the `Phenomenology` leaf IT exempts → ledger glob); IT triage:
  SENTENCE_OPENER 8, ABUTTING_SPANS 10, CODE_IN_MATH 4, the stale-variable custom scan 192 before
  IT's exclusion filter. `gbg init` writes each consumer's `docs/prose_shape.csv` afresh (PF's existing
  file keys its units the same way but counted fenced code and in-fence `#` lines).
- Deferred (recorded, not planned): a private Julia registry as the upgrade of the pin syntax; Julia
  1.12 workspaces to collapse the sub-environment entries; `.claude/rules/` as an alternative policy
  placement; IT's rubric-audit calibration triple as an optional instrument with a verb of its own.
