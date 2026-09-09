---
name: gbg-doctor
description: The read-only health check of this package's tooling — config, pin, managed files, wiring, ledger, rounds (GBGCodingTools vdev, GBGFixture)
allowed-tools: Bash(gbg *)
---
<!-- gbg:managed SKILL.md.tmpl vdev — rewritten by `gbg sync`; do not edit -->
The preflight below validates the config, runs the quick doctor and `gbg self verify`, opens the
round, and prints this instrument's protocol, the exact `Workflow` call and the next step. A non-zero
exit aborts the skill here; nothing below it is a fallback. (`/gbg-doctor` runs `gbg doctor` and opens
no round: the doctor is not an instrument.)

!`gbg doctor`

Follow the protocol printed above, exactly and to its end.
