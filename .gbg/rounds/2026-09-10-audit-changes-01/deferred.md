# Deferred — 2026-09-10-audit-changes-01

Every concern disposed `fixed` in this round names a correction the NEXT change set carries, which the
next audit covers. An audit round is never corrected inside it, so this file is where that commitment
lives, and `close` carries these lines into `.claude/WORK_QUEUE.md`.

The 44 corrections owed, by what they belong to:

- **The scoped pass and the sweep refusal**, both added this week to make a round cheaper, and both
  wrong in ways the round found by running them. `pass open` refuses every audit round outright, because
  an audit's tree must not move and so nothing is ever touched. The tally's `demoted_by_rule` and
  `adjudicated_share` count only the ids in the pass's scope against a denominator of every banked id,
  so a round that adjudicated ten of forty writes a zero rate into the tally `gbg fleet --diff` reads.
  `unswept` compares a whole-tree file set against a covered-paths-only diff, so a fix outside the
  covered paths can never clear it. A finding whose locations name no real file is exempt from
  re-verification for ever. And the round-lifecycle test was re-baselined to assert the refusal, so
  nothing exercises the default path any more.
- **`TestHarness.resolve_function`.** The reorder is inert: `pkg` is searched first and `isdefined`
  is true for every Base export through the implicit `using Base`, so the externals tuple is unreachable
  for exactly the names the fix cited. 421 names resolve identically either way. The docstring it gained
  states a contract the code does not keep, and the commit message claims a code fix that changed no
  behaviour.
- **Two closed vocabularies shipped as MINOR.** The tally's `state` went from six values to ten and two
  artefact schemas closed their maps, which §5.5 makes MAJOR. §6.3, the closed-vocabulary table, was
  never touched, and `gbg sync` now throws uncaught on a sidecar an older copy wrote.
- **Three scans over-reach.** The argument-form scan's element-type exemption fires on a keyword's name
  alone; it counts a bare splat so a prose-form `f(x; kwargs...)` is a hit; the sibling rule's new
  later-mention half is hard-tier and its pattern matches any URL under a sibling's site; and
  `check_paths` scans the build command by regex, so a refusal the config schema makes unreachable sits
  beside a per-token existence check that fires on any `.jl`-shaped word.
- **A rule that now contradicts its own next sentence.** RULE.TEST.RULE_WITH_CHECK counts `session`, "a
  working agreement no artefact records", as a check, two lines above "someone remembering this rule is
  not enforcement". Six rules rest on it.
- **Sweeps that stopped short**, again: the indicator-glyph exception reached five sites but not the
  rule table, the register statement or the typesetting hat; the shape rule's ratchet clause reached the
  scan catalogue but not its own policy paragraph; the panel-versus-weakness distinction was not carried
  into this package's own deviation entry; and `--sweep-ok` is absent from the build plan's verb table.
- **A fleet rule appended with no id.** The "an audit is disposed, never corrected inside" sentence went
  into RULE.INST.AUDIT_AFTER_CODE's paragraph without an id of its own, a register statement or a check.

Three concerns are escalated rather than owed, each with the condition that would overturn it: the two
halves of the docstring-order contradiction with `RULE.CIT.FULL_INLINE`, which cannot both be last, and
the shape caps on a page unit already in the baseline.
