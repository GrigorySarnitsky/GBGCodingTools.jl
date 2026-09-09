# Deferred — 2026-09-09-audit-changes-01

Classes this fix pass could not close, because each is an instrument change that belongs in its own
commit and its own release rather than inside a round that scores it. Carried into
`.claude/WORK_QUEUE.md` at close.

- SCAN.PROSE_SHAPE exempts a page unit already in the baseline from the 120-word and 3-admonition caps,
  and the comment that recorded the lesson — a cap escapable by re-baselining is escaped — was rewritten
  to describe the exemption rather than the code changed to remove it. Whether a baselined page unit
  should be capped too is a design decision, and it changes a hard scan's verdict on every consumer's
  corpus. `2026-09-09-audit-changes-01/executing#6`, `contract-drift#4`.
- The four consumer packages' docstrings were written to the docstring order this release changes, and
  they are frozen until their migration phase. Each migrates at its bump.
  `2026-09-09-audit-changes-01/behaviour-change#5`, `contract-drift#5`.
