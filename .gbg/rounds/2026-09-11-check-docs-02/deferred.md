# Deferred — 2026-09-11-check-docs-02

Instrument changes this round could not make (RULE.INST.FROZEN_MIDROUND); `close` carries each bullet
into `.claude/WORK_QUEUE.md`.

- `workflow-scripts#1`: `verify-act.js`'s `mode: 'batches'` branch has no caller (`Passes.jl` always
  passes `mode = "lanes"`); wire a caller with a test, or delete the branch, the `mode` arg and the
  header's "mode ∈ lanes|batches".
- `workflow-scripts#2`: `lanes.js`, `panel.js`, `hunt.js`, `audit.js`, `verify-state.js` and
  `verify-act.js`'s lanes path run an empty roster silently; add the `if (!A.<list>.length) throw`
  guard the other four scripts carry.
- `rulebook#1`: `RULE.CIT.DOI`'s `check` in `policy/RULES.toml` says `weakness` while
  `SCAN.DOI_CROSSCHECK`'s header names `RULE.CIT.DOI` and its `require_doi` loop enforces a DOI on
  every reference; make the rule register and the scan agree (the rc.7 CHANGELOG said the scan
  enforces `RULE.CIT.FULL_INLINE` only).
- `rulebook#2`: `RULE.DOC.SHAPE` orders a `# Arguments` heading that `RULE.DOC.ARGS_FORM` never
  produces; drop the clause, or name the heading as the form some consumers use instead.
- `ext#1`'s class: `RULE.DOC.SIGNATURE_MIRROR` says an argument typed in the method is typed in the
  docstring, yet its register entry names only `SCAN.SIGNATURE_WIDE`, which checks width. Measured at
  pass 2: 451 bare arguments across 247 docstrings of `src/` (Rounds.jl 55, Passes.jl 52, Preflight.jl
  44, ...). Build the mirror half as a scan, then either sweep the corpus in one deliberate change or
  narrow the rule to what the house style is; the owner decides which.
- A carried check-docs finding fixed between rounds cannot close: the act verifier reads only this
  round's fix range and grades it `UNDONE` (four of `2026-09-11-check-docs-01`'s five carried ids at
  rc.9). A re-banked carried id should go to the state verifier alone, as a closed id back in scope does.
- Seeded recall at rc.9 was 0/6 — every seed a one-word mutation (a count, an exit-code meaning, a
  quantifier, an inverted rule, a false mechanism, a vocabulary swap) — with rationale, src, family,
  cold-reader and operational-claims SUSPECT. With `.gbg/attacks/2026-09-11-attack-check-docs-01` (18
  gaps, 2 fatal), the lens set needs its next revision: a lane over the prose no lane reads (CLAUDE.md,
  README, CHANGELOG, PROTOCOL.md, make.jl's page text), "one claim, many homes" in place of `family`,
  and each lane's `checked[]` checked against its roster.
