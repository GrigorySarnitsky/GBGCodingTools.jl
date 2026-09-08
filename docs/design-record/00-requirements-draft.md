# Requirements draft (pre-survey) — to be refined

R1 Uniformity: four consumers (PF, IT, SS, CP) run the SAME instrument code at the SAME version; a difference between consumers is either declared config or a finding (doctor). Existing differences default to historic artefacts.
R2 Transparency: at any moment one can answer "which instrument version measured this round?", "what does this package deviate in and why?", "what changed in the instrument between two rounds?" from committed artefacts, not transcripts.
R3 Fail-closed: the missing case is the failing case (no config → fail; absent pile → fail; dead lane → fail; zero count → dead agent).
R4 Instrument integrity: instrument changes are their own commits/releases, never folded into a round; a round records the instrument version; a round cannot close under a different version than it opened with (or the closure must be re-graded).
R5 Self-tested: the shared package tests itself (recall_selftest, seeded defects, gate tests, selfcheck) against a fixture consumer; a check that cannot fail is not a check.
R6 Minimal consumer footprint: a consumer holds config + piles + the files that must physically exist (test/regressions/, make.jl one-liner, CLAUDE.md import line); nothing else duplicated.
R7 Polyglot reality: Workflow scripts (JS run by Claude Code, no fs, args only), Python helpers, Julia helpers, shell guards, markdown skills, agent personas, hooks; all versioned together.
R8 Two-machine fleet, Dropbox+GitHub sync; per-machine install must be reproducible; secrets/tokens not in repo.
R9 Migration tractability: each consumer migrates by an ordered checklist with a doctor verifying each step; no big-bang.
R10 Extensibility: adding a 5th package = write config + run scaffold; adding an instrument = one directory with a contract (skill + workflow + engine + selftest + schema).
R11 Measurements are comparable: finding schema and verdict vocabulary are ONE shared schema; per-package extension only via declared fields.
R12 Cost policy shared: economy lanes default, anchors named per package in config, fix phase full strength.
