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
- The sweep check added this round (`pass open` refuses while an open finding names an untouched file)
  requires EVERY named location to move. That is right for a check-docs finding, whose `locations` are
  the sites of the defect, and wrong for an audit finding, whose locations also carry the blast radius
  it cites as evidence: this round's own fix pass tripped it nineteen times, every one of them a file
  the finding named as evidence rather than as a place needing a change. Either the check counts one
  named location as enough, or `locations` gains a way to say which entries are defect sites. It is a
  change to the closure engine, which scores every round, so it waits for its own release.
  Found by running the check, not by reading it.
