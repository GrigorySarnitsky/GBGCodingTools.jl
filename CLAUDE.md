# CLAUDE.md — GBGCodingTools (seed; the package is DESIGNED, not yet built)

You are in the dev checkout of `GBGCodingTools.jl`, the one shared tooling package for the four GBG
Julia packages. Nothing is implemented yet: this directory holds the design and the plan, and your
job is to build the package from them. This file is replaced by the managed one the plan describes
once `gbg sync` exists.

**Read first, in this order:** `IMPLEMENTATION.md` (the owner's questions at the top, then Phases 0–8,
each with a definition of done and its verification commands), then `docs/ARCHITECTURE.md` (every
decision with its evidence; the vocabulary at its head binds the terms). `docs/design-record/` is
provenance — consult it when a decision's reason is unclear, never re-derive one.

**Start by putting the owner's questions (`IMPLEMENTATION.md` §A) to the owner in one message.**
Defaults apply if unanswered. Then Phase 0.

**Where the consumers live** (all Dropbox-synced git checkouts, private GitHub remotes; every path
contains spaces — quote them):
- `~/Dropbox/Research and Teach/Isotropic Turbulence/GBGPeriodicFields` (PF, the canary; its
  `.claude/commands/`, `docs/make.jl` lints and `test/` harnesses are the richest port sources)
- `~/Dropbox/Research and Teach/Isotropic Turbulence/GBGIsotropicTurbulence` (IT)
- `~/Dropbox/Research and Teach/Statistics/GBGStreamingStatistics` (SS)
- `~/Dropbox/Research and Teach/Cloud Physics/GBGCloudPhysics` (CP)
Read them for the ports; do not edit them until their migration phase (4–7), and never on a peer
session's request. Their instruments are frozen until then.

**Fleet and sync model:** two hosts, `Aiporetne` (home, ROCm) and `Enteropia` (office, CUDA); check
`hostname`. The owner works on one host at a time. This working tree, the four consumers and the
memory directories sync between the hosts through Dropbox; git history and the pin sync through
GitHub (commit ⇒ push, always). Per-machine state is installed once on EACH host and never synced:
the shim `~/.local/bin/gbg`, the dev-checkout pointer `~/.gbg/dev`, the Julia depot and juliaup
channels (`juliaup add 1.11` is a Phase-0 step on both). A half-synced file is a real hazard the
design guards against (`CFG.TORN`); if a file looks torn, wait for Dropbox before acting. Julia 1.12.7
via juliaup; no Python anywhere in the design.

**Working agreements** (the full list is `IMPLEMENTATION.md` §B): commit ⇒ push on `master`; end every
commit message with `Co-Authored-By: Anthropic Claude <noreply@anthropic.com>`; stage with
`git add -u` plus new files by name, never `-A`; gate every commit on exit codes
(`bash -e -o pipefail`), never on a grep of a log; "should work" is not done; an instrument change is
its own tag and bump commit, never an edit inside a consumer or a change folded into a round it scores.

**First commit:** `git init -b master` here, keep every existing file, remote
`https://github.com/GrigorySarnitsky/GBGCodingTools.jl.git` (create it private with `gh repo create`).
Memory syncs through `.claude/settings.local.json` → `AI Helpers/claude-memory/GBGCodingTools/`.
