---
name: check-consistency
description: Fresh-eyed multi-hat panel over the rendered documentation site — consolidate, run the hats, bank, fix, verify and close the round (GBGCodingTools vdev, GBGCodingTools)
allowed-tools: Bash(gbg *)
---
<!-- gbg:managed SKILL.md.tmpl vdev — rewritten by `gbg sync`; do not edit -->
The preflight below validates the config, runs the quick doctor set (`QUICK` — the checks that hold on any machine, with no build and no
network) and `gbg self verify`, opens the
round, and prints this instrument's protocol, the exact `Workflow` call and the next step. A non-zero
exit aborts the skill here; nothing below it is a fallback. (`/gbg-doctor` runs `gbg doctor` and opens
no round: the doctor is not an instrument.)

!`gbg preflight check-consistency $ARGUMENTS`

Follow the protocol printed above, exactly and to its end.
