# Brief for a round-1 architect

You are designing ONE shared instrument/tooling package for four private sibling Julia packages
(GBGPeriodicFields "PF", GBGIsotropicTurbulence "IT", GBGStreamingStatistics "SS",
GBGCloudPhysics "CP"), each developed in Claude Code sessions on a two-machine fleet (home
`Aiporetne`, office `Enteropia`; every repo lives in a Dropbox-synced folder AND on private GitHub;
Claude memory syncs via Dropbox; hosts run Linux, Julia 1.12 via juliaup, python3, NO node on
PATH — the existing `.js` instruments are Claude Code WORKFLOW scripts run by the Workflow tool,
sandboxed, no filesystem, config only via `args`).

The owner's goals, verbatim: "extremely well-thought, so the package is transparent, easy to
maintain and flexible to accommodate all our packages. Its application to the packages should also
be transparent and tractable. It should target making our packages more uniform, so existing
differences often should be treated as historic artefacts rather than necessary."

Read, in this order (all in this directory):
  00-requirements-draft.md, 01-decision-points.md,
  survey-checkdocs.md, survey-check-consistency.md, survey-bughunt-auditchanges.md,
  survey-buildlints-hooks-policy.md, facts-claude-code-platform.md, theory-patterns.md
Also read the "Planned directions" block about the shared instrument package in
"/home/grigory/Dropbox/Research and Teach/Isotropic Turbulence/GBGPeriodicFields/CLAUDE.md"
(grep for "shared instrument package is DEFERRED") and IT's
".claude/commands/INVENTORY.md" (already summarised in the surveys). You may open any file in the
four repos to check a fact, read-only.

Deliverable: a complete architecture proposal, as markdown, written to the output path you are
given. It MUST:
1. Answer EVERY decision point D1–D19 explicitly, in numbered order, with (a) the choice, (b) the
   requirement(s) and evidence (file:line from the surveys) that force it, (c) the alternatives
   considered and why each is dominated. A decision without a named alternative is incomplete.
2. Give the repository layout of the shared package (tree with one-line purposes) and the exact
   footprint left in a consumer package (tree) — every file, and for each whether it is
   config / generated-managed / seeded-once-then-owned / tracked-pile.
3. Give the config schema (TOML) for a consumer, complete enough that PF's and SS's real
   differences can be expressed, and state what is deliberately NOT configurable.
4. Give the run-time contract of one instrument end to end (skill → config → workflow args →
   agents → banked pile → verifiers → gate → closure), naming the exit codes and file formats.
5. State the migration plan per consumer (order, steps, what is deleted, which differences are
   collapsed as historic artefacts and which are kept as declared deviations with a reason).
6. State how the package tests itself and what "provably best" can honestly mean here: a list of
   requirement → decision entailments, and the residual judgment calls.
7. Propose a name with a two-line justification (the owner's working name is GBGCodingTools).
Be concrete (paths, file names, key names, command lines). Prefer fewer mechanisms over more. Do
not pad. Length: as long as needed, no longer than ~1500 lines.
