---
name: check-docs
description: Run the COMPLETE documentation-quality battery over every surface — scans, reflection checks, the build, the judgment lanes — then bank, fix, verify and close the round (GBGCodingTools vdev, GBGCodingTools)
allowed-tools: Bash(gbg *)
---
<!-- gbg:managed SKILL.md.tmpl vdev — rewritten by `gbg sync`; do not edit -->
The command below runs first. For an instrument it is the preflight: it validates the config, runs the
quick doctor set (`QUICK` — the checks that hold on any machine, with no build and no network) and
`gbg self verify`, opens the round, and prints this instrument's protocol, the exact `Workflow` call
and the next step — for `/check-docs`, the next step is `gbg round prepare`, which prints the call. For `/gbg-doctor` it is `gbg doctor`, which opens no round — the doctor is not an
instrument — and prints one line per check. A non-zero exit aborts the skill here; nothing below it
is a fallback.

!`gbg preflight check-docs $ARGUMENTS`

Follow what it printed, exactly and to its end: an instrument's protocol step by step, or, for the
doctor, each check that did not pass.
