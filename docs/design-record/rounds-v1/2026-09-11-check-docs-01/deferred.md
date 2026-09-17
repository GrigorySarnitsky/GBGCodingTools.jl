# Deferrals of 2026-09-11-check-docs-01 — each is an instrument change, which is its own commit and
# its own release, never an edit inside the round it would score. `gbg round close` carries every
# bullet below into .claude/WORK_QUEUE.md.

- Wire `attack-design.js` (audit-changes) and `rubric-audit.js` (check-consistency) into verbs: build
  their args from the config and the round, print their launch line the way `pass open` prints the
  verifiers', and validate what each writes against a schema of its own. Until then both run only by
  hand, which ARCHITECTURE D17 now says (workflow-scripts#1 of this round).

- `dismissals.js` and `verify-architecture.js` ask one agent per item for `{id, verdict, …}` without
  saying what `id` holds; a paraphrased id is then read as a DEAD auditor by the script's own liveness
  check. Give the `id` property the description "the finding id EXACTLY as given" and end each prompt
  with `Return {id: "<id>", …}`, as `severity-recheck.js` and `verify-act.js` do — better still, stamp
  `id` in the script from the item rather than from the model (workflow-scripts#2 of this round;
  `dismissals.js` is check-docs' own close gate, so it is frozen while this round is open).

- `severity-recheck.js` and `attack-design.js` write `round: A.round` but leave `round` out of their
  required-args guard, so an omitted round is dropped silently rather than refused like every sibling
  script's; add it to both lists (workflow-scripts#3 of this round; `severity-recheck.js` runs at
  check-docs' own carry, so it is frozen while this round is open).
