# Changelog

Every tag has one entry: version, date, MAJOR | MINOR | PATCH, the instruments affected, and
"rates comparable: yes | no" (for a MAJOR, the fixture recall before and after).

## Unreleased

**This cycle is MAJOR, not MINOR.** Two closed vocabularies moved, which §5.5 makes MAJOR on its own:
the tally's `per_id.state` widened from six values to ten so a re-run witness's status can be recorded,
and `managed.schema.json` and `tally.schema.json` closed their previously open per-entry maps, so a
sidecar or tally an older copy wrote can now fail validation. Both are in §6.3. The fixture recall is
unchanged either side, since no scan's hit set moved with them.

**`TestHarness.resolve_function` resolves a colliding name to the package, not to `Base`.** A name a
package module OWNS is searched before anything else. Ordering the externals last, as an earlier commit
in this cycle claimed to do, changed nothing at all: `isdefined(pkg, :read)` is true through the implicit
`using Base`, so `pkg` decided every collision before the modules were reached, and 421 names resolved
identically either way. For this package `read`, `list` and `report` now denote `Config.read`,
`Rounds.list` and `Scan.report`. A consumer whose public surface collides with a `Base` export through a
submodule will see `method_parity`'s counts move, which is the count being right rather than a
regression, and its frozen row is re-recorded at the bump.

**A docstring's order changed fleet-wide, and every consumer's prose is affected.**
`RULE.DOC.HOME_ORDER` put the caveat admonition at position (4), before the formula, the citation and
the cross-links; it now puts it last, before the fields list, which is where `RULE.DOC.ADMONITION_TITLE`
and the enforced shape rule always had it. The two rules contradicted each other and one of them had to
move. A docstring written to the old order becomes an outlier at the consumer's next round, so the four
science packages migrate their docstrings when they bump, not before: the rulebook they obey is the one
they pin. The two judging personas were rewritten in the same commit as the rule.

**Three JSON schemas were tightened** in a commit whose message did not name them: `managed` and `tally`
closed their per-entry maps, and `exemptions` raised its `reason` floor. The last was reverted, because
`Ledger.read` throws where the doctor would have named the entry and carried on; the other two stand,
and a sidecar an older copy wrote now names itself in the refusal.

MINOR so far. The self-application sweep's remainder is closed. New: `SCAN.ARGS_FORM` (triage) for the
argument-form rule, which had no enforcer; `test/coverage.jl` driving `main()` and its exit contract,
every doctor check as a callable, every Workflow script's shape, the consolidator against a golden
manuscript, `Rounds.prepare` end to end, and a round of each of the four instruments. Repairs: the
trailer check fails rather than warns; `AUDIT.GAP` no longer reports absence as contiguity and runs in
the quick set; `SCAN.SIGNATURE_FIDELITY` compares 190 bindings where it compared none, resolving names to
the module that owns them; the four reflection scans run at all, the fixture being a test dependency now
and `loaded` asserted; the docs build stops waiving unresolved cross references; the managed sidecar, the
seed ground truth and each reproduction record are validated against the schemas that name them, two
superseded schemas are deleted, and `witness_env` is a string in the bug-hunt schema, without which that
instrument could not open a round. `RULE.API.POSITIONAL` is declared unenforceable in the ledger.
`RULE.CIT.FULL_INLINE` is rewritten to the form the fleet actually uses and PF has used
all along: a docstring cites author-year in its prose and carries the full reference in a `# References`
section at its end, one bullet per work with the title clickable to the DOI. The rule had said the full
reference goes inline in the prose, which no package does and which reads badly. `SCAN.DOI_CROSSCHECK`
gains the check the rewrite needs: a title-as-link outside a docstring's `# References` section is a
hit, with the `prose-reference` fixture class and a canonical clean twin; the lone `Reference: …` form
stays legal. `surfaces.data` is a new OPTIONAL surface, empty in every consumer: the comment prose of
a package's data and script files, with a reader per kind (`#` comments, `//` comments, and a JSON
file's `description` strings). Only a full-line comment is prose. It is on in this package, where it
adds 79 files and 319 prose lines that no scan had ever read; `all` does not include it, so no
existing scan changed meaning. An adversarial sweep asked where the tool fails to apply its own machinery to itself; 46
claims, 31 stood, none refuted. Seven were defects that had never fired because three instruments have
never run here: the dismissal closure gate compared an `items_sha` the script never wrote (so no round
with an adjudication could close), the architecture verifier wrote a file its schema rejected, a
bug-hunt schema carried a cross-file `$ref` the validator refuses, five call sites bypassed
`Witnesses.witness_project` (so no witness here could load the package), `audit_kind` decided prose by a
`docs/` prefix (so `docs/make.jl` was prose), a hand-written page was declared a build product, and
`package.modules` named nine of eighteen submodules. This package's own `.gbg/` is populated for the
first time: five `/check-docs` lanes over the scripts, catalogues, rulebook, templates and schemas that
no surface reaches, four bug-hunt territories mirroring the modules, the audit's guard symbols and
executable claims, and a seed catalogue so an empty hat is falsifiable. Four testing and rubric rules
whose subject does not exist here are declared in the ledger rather than left silently unenforced.
`SCAN.HTML_STRAY_MATH` (hard) catches prose that Julia Markdown read as math — a
double-backtick span quoting backticked syntax, which KaTeX leaves raw on the page; three shipped on the
generated rules page and are fixed. With it, `RULE.INST.FROZEN_MIDROUND` says where a deferral goes: one
line in the round's `deferred.md`, carried by `gbg round close` into `.claude/WORK_QUEUE.md`, whose Stop
hook holds the next session to it. `RULE.INST.AUDIT_AFTER_CODE` gates a `/check-docs` round's close on a closed
`/audit-changes` round whenever its fix pass touched the `src` or `ext` surfaces, as a hunt's close has
always been gated (the rc.1 round changed three code behaviours unaudited); a prose-only pass is not
gated. The owner's home-page review adds `RULE.DOC.SIBLING_LINK` and the hard `SCAN.SIBLING_LINK`
(the first mention of a sibling GBG package in a page or docstring links to its documentation site; names
and sites from the shipped `fleet.toml`; fixture class `bare-sibling`), and the home page drops its AI
banner: `RULE.DOC.AI_BANNER` now states fleet-wide that the home page never carries it, the owner
reviewing that one page in every package, and `SCAN.AI_BANNER` enforces it — the scan reads the
hand-written pages now, which the design record already claimed and the catalogue did not give it, so
the drift check covers them too. The noun "pin" gives way to "pinned version" in every page, docstring,
message and template (the `PIN.*` check ids keep the word). Instruments affected: check-docs, check-consistency, audit-changes (the lane, panel, act
and state scripts gain a scribe: the validated object is written over the lane's own Write-first file, so
a value outside a closed set never reaches the bank — found by the rc.1 round, whose built-html lane was
quarantined twice). CLI: `round bank` keeps no first-sight sha for a quarantined lane and `round rerun`
forgets the lanes it re-runs; `Git.run` keeps the environment (an annotated tag needs an identity); a dev
checkout on a clean tag stamps its rounds with the tag, and a round so stamped keeps reading its tool
stamps from the tag while it exists (D16: the fix commits past the tag are not a moved tool; `pass open
--regrade` re-stamps whatever moved, the tool stamps included). Skill stubs: the preflight line is the
documented bang-backtick form; the bare `!command` line the first rc rendered is not expanded by the
client at all (Phase 1.9 V2). Tests: the suite resolves the fixture's `test/` environment once, so a
fresh clone's witnesses load `GBGFixture` (the first CI dispatch failed there). Rates comparable: yes.

The rc.1 `/check-docs` round (2026-09-09-check-docs-01, 22 findings) fixed in code: `TreeHash.tree_hash`
now omits an empty directory as `git write-tree` does; the rescan needle is cut in characters, not
bytes; a witness that both failed and errored is `:broken`, never `:blocked`. In prose: the module map
defines consumer and pin and names the scan engine; the verbs page carries `fleet`, `bump`, `release`
and `selftest`; the design record's consolidator passages are in the past tense; no double-backtick
span nests a backtick; the terms lane, hat, substrate, anchor, managed file, round and the act/state
split are defined where first used; the traffic bookkeeping is an audit, not a ledger.

## 1.0.0-rc.1 — 2026-09-09

The first release candidate: MAJOR (the first). Instruments affected: all four, first issue. Rates
comparable: no (no earlier version).

- The package as `IMPLEMENTATION.md` Phase 1 states it: the CLI (`gbg <noun> <verb>`, every verb of the
  closed table), the config and its schema with the eighteen artefact schemas, the policy layer with
  `RULES.toml`, the templates and `sync`, `init` with the baseline and seed migration, the doctor's
  full check table, the text-scan engine with the 39 catalogued scans, the Documenter wrapper and the
  built-HTML scans, the test harness, the witness runner, the four instruments' protocols, catalogues
  and Workflow scripts, and the round machinery (preflight, prepare, bank, pass open, grade, close,
  abandon) with the seeds, recall and demotion engines.
- The tool is its own fifth consumer: its `.gbg/`, its managed files, its site through its own wrapper,
  its tests ending in `TestHarness.gate()`.
- The fixture `fixture/GBG Fixture/` with its defects corpus (42 planted classes, 20 clean twins), and
  the self-test suite over it.
- Revision 9 of the architecture: Workflow payloads are files, args carry paths.
- Nothing pins this tag; it exists so the tool's first `/check-docs` round over its own docs opens at
  a clean tag.


- Phase 1 in progress: the skeleton, the CLI, the ports (see `IMPLEMENTATION.md`).
- 1.6 consolidator acceptance (2026-09-09): `Consolidate.jl` over Gumbo produced byte-equal
  `manuscript-{full,siteonly}.md` pairs against the consumers' `consolidate.py` on PF's build (18 pages,
  1 093 435 / 410 836 chars) and IT's (22 pages, 555 623 / 484 749 chars); the Python is gone. Two
  BeautifulSoup behaviours had to be mirrored: whitespace-only text nodes are kept (Gumbo.jl drops them
  by default) and collapsed to one space, or one newline when they contain one.
- Pre-migration scan census (2026-09-09, the tool's scans run read-only over the two consumers with
  their §5 configs; no ledger yet, so every count is before adjudication — what Phases 4 and 5 will
  meet). PF hard: THIN_SPACE 3, MATHBF 23 (`\mathbf 1` unbraced, `\mathbf{k}` in the generated example
  page — now a `generated` glob in §5.1), LEFTRIGHT 1, FIELD_DOCS 3 (the `NO_FIELD_LIST` trio →
  ledger), PROSE_SHAPE 42 docstrings over the 120-word cap + 8 heading-order, AI_BANNER 1
  (`examples/gpu/rocm/HIST_ROCm.jl`); PF triage: FORMULA_IN_BACKTICKS 9, CODE_IN_MATH 3,
  CITATION_CRAMMED 1, SENTENCE_OPENER 3 (identical to `sentence_openers.py`), SIGNATURE_WIDE 3,
  ABUTTING_SPANS 137 (PF's `` `name` ``\equiv …`` `` notation idiom). IT hard: NEG_THIN_BIGL 11
  (`\exp\!\bigl(`), REF_ABUT_CODE 20 (`[`f`](@ref)`(args)``), FIELD_DOCS 39 (no `The fields are`
  lists), LINK_UNIFORMITY 1, API_PAGE_STRUCTURE 1 (`@index`), AI_BANNER 1 (`docs/ARCHITECTURE.md`),
  DOI_CROSSCHECK 26 (all in the `Phenomenology` leaf IT exempts → ledger glob); IT triage:
  SENTENCE_OPENER 8, ABUTTING_SPANS 10, CODE_IN_MATH 4, the stale-variable custom scan 192 before
  IT's exclusion filter. `gbg init` writes each consumer's `docs/prose_shape.csv` afresh (PF's existing
  file keys its units the same way but counted fenced code and in-fence `#` lines).
- Deferred (recorded, not planned): a private Julia registry as the upgrade of the pin syntax; Julia
  1.12 workspaces to collapse the sub-environment entries; `.claude/rules/` as an alternative policy
  placement; IT's rubric-audit calibration triple as an optional instrument with a verb of its own.
