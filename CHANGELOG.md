# Changelog

Every tag has one entry: version, date, MAJOR | MINOR | PATCH, the instruments affected, and
"rates comparable: yes | no" (for a MAJOR, the fixture recall before and after).

## 1.0.0-rc.7 — 2026-09-11

MAJOR on rc.6. Instruments affected: bug-hunt (the reproduction record), audit-changes (its bank),
check-consistency (two hat personas) and the docs build of every consumer (`makedocs`' return value and
both of its gates). Rates comparable: **no** for check-consistency — the doc-policy and naming-policy
hats now read the authored source and report at its file:line, and doc-policy enforces the aliasing
placement, so those two hats may report what they did not; yes for the other three. The fixture recall
is unchanged, before and after: every planted class of `fixture/GBG Fixture/defects.toml` still hit and
every clean twin still silent, asserted per class in `test/scans.jl`. No scan changed since rc.6 (one
docstring in `Scan.jl`), and the two personas are the only change to what a lane reads.

**The Julia floor is 1.12.** `julia = "1.12"` in the tool's and the fixture's `[compat]`,
`JULIA_FLOOR = v"1.12"` (so `gbg install` and the doctor's `ENV.JULIA` refuse 1.11), and CI's 1.11 lane
is gone: both lanes run 1.12, one thread and four. The 1.11 floor served GBGStreamingStatistics alone,
and the owner raises it to 1.12, every consumer's version (ruling 2026-09-11). A session still on 1.11
cannot resolve this release.

From 2026-09-11-check-docs-01 (closed at the pass budget, 22 closed, 5 carried) and the audit that covered
its code, 2026-09-11-audit-changes-01:

**A confirmed bug-hunt finding banks.** `hunt_bank!` writes `disposition.state = "open"` for every
REPRODUCED or EVIDENCED finding and validates the record at once, against an enum without `open`: the
first confirmed finding of any hunt threw. The enum admits it, and ARCHITECTURE §6.3 records it as the
state bank writes before any disposition (MAJOR under §5.5: widened from three values to four).

**An audit lane's verdict must agree with its findings.** A lane that says `CLEAN` and reports a concern,
or `CONCERNS` and reports none, is quarantined as DEAD by `classify_lane`, recorded in `dead_lanes`, and
re-run by the `gbg round rerun` bank prints; `audit-changes bank` refuses it before running the
executable claims. Before, the required `verdict` was read by nothing. (The first version of this check,
in the fix pass, printed a rerun that rerun refused, read quarantined files, and crashed on a null
`findings`; the audit caught all three.)

**`makedocs` says whether it built.** It returns `true` for a build that ran (Documenter's own result is
`nothing` unless `debug = true`, the frozen skip's value too, so a deploy guard on it could never fire),
and `nothing` when either gate skips for an open docs round — the gate after Documenter now skips like
the one before it rather than failing, the site built and not deployed. The tool's own site therefore
deploys on a push or a tag once no docs round is open; it had not deployed since 2026-09-09.

**`init` rewrites a seeded `test/Project.toml` only for a `dev` pin**, whose seed names a tag that does
not resolve; never for the tool itself or a release pin.

**The rule register tells a weakness from a panel.** Under RULE.TEST.RULE_WITH_CHECK's last sentence,
`panel` is for a rule no program could decide: RULE.DOC.HOME_ORDER, ONE_HOME, VARIANT_PAIR, MODULE_MAP
and RULE.CIT.DOI stay `weakness` (a check could exist and none is built; SCAN.DOI_CROSSCHECK enforces
RULE.CIT.FULL_INLINE, not CIT.DOI), and RULE.TEX.IMAGINARY is `panel`. The five RULE.TEST rules a panel
was said to read — no instrument reads a test suite's construction against them — are `weakness`.

From the instrument changes 2026-09-10-check-docs-03 and 2026-09-11-check-docs-01 deferred, each frozen
while a round of its instrument ran:

**A pass is refused only for what no fix pass touched.** `pass open`'s unswept refusal compared a
finding's named locations with this fix pass's diff alone, so a location fixed and verified in pass 1 was
"untouched" at every later pass; it now reads every fix pass since bank.

**A regrade cannot walk a moved tag.** `pass open --regrade` re-stamped every moved stamp, so refuse,
regrade, close passed a round on a force-moved tag; it never re-stamps `tool_tree_sha` under an unchanged
released version (`Passes.restamped`). `grade` says plainly when the config stamp moved and which pass's
verdicts a regrade sets aside.

**The verifiers' binding fields come from args.** `verify-act.js` and `verify-state.js` stamp
`pass_nonce` and `graded_sha256` into the scribe's file from their args, logging a lane that returned
other values; `dismissals.js`, `verify-architecture.js` and `severity-recheck.js` take each id from the
item, so a paraphrase can no longer read as a dead auditor; `severity-recheck.js` and `attack-design.js`
require `round`.

**`dismissals.json` no longer rests on one agent.** Each dismissal auditor writes its own verdict under
`dismissals/<items_sha[1:12]>/`, and `close` assembles the file from them when the script's final write
is missing or stale.

**What reaches a verifier as settled is the owner's not-a-defect rulings.** A finding-scope ledger entry
gains `ruling = "not-a-defect" | "scoped"` (default `not-a-defect`); only the first reaches the panel and
verifier prompts, so an adjudication that closed a real defect no longer tells every later round not to
flag it. (MAJOR: a new key in the ledger schema's closed set.)

**The class checklist offers only files a fix can reach.** `class_candidates` reads what git would
track, never a gitignored build product. **A docs lane is SUSPECT on its own files**: `suspect_hats` takes
each lane's file list, so a lane handed no seed in its files is not flagged for missing one. **The
doctor passes a disposed hunt round**: `reproductions_sha` hashes the records with their disposition
removed — the one field recorded after bank — in bank, the doctor and close alike, and close now compares it.

Rates comparable: the unswept, class and SUSPECT changes alter what a round reports about itself, never
what a lane sees.

**The severity re-check costs a fraction of what it did.** It spent one agent per finding — 1.52M
tokens to re-rate the 33 concerns of 2026-09-11-audit-changes-01, near the 2.23M of the audit lanes that
found them. `severity-recheck.js` now rates several findings per agent (`batch`, default 6), each still
on its own block alone, and an agent answers only for the ids it was handed. `audit-changes bank` sends
it only the concerns a re-rating can move across the disposition gate: the gate takes the more serious
rating, so a `major`, a `blocker` or a concern gated by `previously_worked` is gated whatever the
re-rating says (23 of those 33; the other 10 would have gone to two agents). A carry still re-rates every candidate, since a carry takes the
re-rating alone.

**Two checks on the instruments themselves get verbs.** `gbg attack <instrument>` renders an
instrument's live roster as a design and puts `attack-design.js`'s four attackers against it, the
subject from `catalog/attack/<instrument>.toml` or `--subject`; `gbg calibrate` scores the
check-consistency hats against the defects a human read found, recorded by the owner in
`.gbg/human-findings.toml`, each hat run blind on the passage alone. Records live under `.gbg/attacks/`
and `.gbg/calibrations/`; `gbg attack read` and `gbg calibrate read` validate what the scripts wrote
(`schema/attack.schema.json`, `schema/rubric-audit.schema.json`). Before, both scripts shipped with no
verb and ran only by hand. Four new verbs (25), four new schemas.

**A bug hunt has a pass budget, and carries with its evidence.** `instruments.bug-hunt.max_passes`
(default 3) gives the hunt the budget the two doc instruments have; past it `close` carries every
finding still open. A carried hunt finding owes its round no disposition, and its carry entry records
its kind, verdict and witness: the next hunt's bank copies the witness in under a name of its own and
re-runs it, confirming a defect that still fails and dropping from the ledger one that no longer does.
Before, nothing could carry a hunt finding: it arrived with no witness and no verdict and could never
close. (`schema/carried.schema.json` gains five optional hunt fields.)

**The Workflow scripts share one prelude.** The args object, the model choice, the scribe and the id
and nonce stamps lived in up to eleven copies, and a fix to one had to be made in each. They are now
`instruments/prelude.js`, spliced into each script at its `// gbg:prelude` line by
`Preflight.install_script` whenever a script is copied into a round or a design-check record; a test
assembles all eleven and refuses a missing splice or a name declared twice. No script's behaviour changes.

The rest is prose: the module map names the round machinery and every module's docstring names its
exports; Passes binds the act and state verifiers; the skill template says what `/gbg-doctor` runs;
ARCHITECTURE and IMPLEMENTATION correct `Scan.jl`'s place, the prose-shape file, D18's five audit anchors
and that `attack-design.js` and `rubric-audit.js` run by hand.

## 1.0.0-rc.6 — 2026-09-11

MAJOR on rc.5. Instruments affected: check-docs and check-consistency (the closure loop: who reads a
re-check, the pass budget, carrying), bug-hunt (the audit it waits on), and every instrument's
`abandon`. Rates comparable: **no** — an `adjudicated_share` from an earlier round counts ids that would
now close `honored`, and a round's carried set may now hold a serious finding. The fixture recall is
unchanged: nothing here changes what a lane or a scan sees.

**A re-check asks whether an id regressed.** A closed id back in scope — the fix pass having touched a
file it names — used to be regraded by the act verifier over this pass's diff alone, which cannot hold a
fix made earlier, so all it could say was `UNDONE`, and nothing but a ledger entry could close the id
again. 2026-09-10-check-docs-03 closed 22 of 40 ids that way and spent seven dismissal-audit readings
failing to certify them. A re-check now goes to the blind verifier alone, and `grade` keeps the id
closed on the act verdict that closed it while that reading is still `ABSENT`. An id left
`pending_state` is re-read the next pass; before, it fell out of every scope for good.

**A pass budget.** `max_passes` (3 by default for both doc instruments) bounds a round. Past it `pass
open` refuses, and `close` carries every id still open into the next round of its instrument on a blind
severity re-check — a `blocker` or `major` included, since the budget and not the severity stopped the
loop. Severity decides releasability instead: a final release refuses while a carried serious finding
stands. A `--regrade` that verifies no new fix spends none of the budget.

**The audit must cover the last fix.** A round whose fix passes changed code accepted any closed
`/audit-changes` round based at its opening head, one closed before a later fix pass touched code again
included. It now needs an audit that read the round's last code change.

**Abandoning keeps what a round owes.** `gbg round abandon` carries the round's `deferred.md` into the
work queue as `close` does.

Vocabularies (§6.3; MAJOR under §5.5): `carried.toml`'s `severity` gains `blocker` and `major`;
`pass.toml` gains `rechecked` and `counted`; a tally entry gains `rechecked`; the config gains
`max_passes` under `instruments.check-docs` and `instruments.check-consistency`.

## 1.0.0-rc.5 — 2026-09-10

PATCH on rc.4, and again its content is one defect the seeded round found in the seeding. Nine of the
thirteen `/check-docs` lane surfaces are DIRECTORIES — `catalog`, `policy`, `schema`, `templates`,
`docs/build` and the four `instruments/*/workflow` trees — and the disposable copy took files and
skipped the rest, so six lanes read a corpus that was partly or wholly absent. Four raised it as a
blocker, which is the lanes behaving correctly; `rulebook` and `schemas` reported on the fragments they
could still reach, which is worse, because those read as ordinary findings. Directories are copied
whole now, and `prepare` refuses unless every surface reached the copy: a lane reading nothing reports
nothing, and nothing is what a clean lane reports too. Round `2026-09-10-check-docs-02` is abandoned
over it, with its 39 findings and its recall figure of 2/6 recorded but not citable. Instruments
affected: check-docs (seeding only). Rates comparable: yes.

## 1.0.0-rc.4 — 2026-09-10

PATCH on rc.3, and its whole content is one defect the first seeded round found in the seeding itself:
a seed's occurrence index was counted against the whole manuscript while the offsets it compared were
page-relative, so the planter asked for one occurrence past the end of the page and skipped the seed
silently. `prepare` reported six planted and the copy carried none. The same arithmetic sat in the
shipped `Seeds.plant` site-only branch, never yet run, where it would have planted into the full
manuscript and not the site-only one — two manuscripts disagreeing, and a wrong recall denominator for
every `siteonly` hat. `plant_files` now returns only seeds whose text actually moved, and a prepare that
plants fewer than it planned refuses. Instruments affected: check-docs, check-consistency (seeding
only). Rates comparable: yes — no round has ever been seeded, so nothing measured moves.

## 1.0.0-rc.3 — 2026-09-10

The third release candidate: MAJOR. Instruments affected: check-docs (seeded lanes, the closure loop,
the demotion predicate), check-consistency and audit-changes (the same closure engine and verifier
scripts). Rates comparable: **no** — the demotion predicate moved, so a `HONORED` share from an earlier
round counts a different thing, and `closed_by` gained `carried`. The fixture recall is unchanged (every
planted class of `fixture/GBG Fixture/defects.toml` still hit, every clean twin still silent, asserted
per class in `test/scans.jl`); what changed is the standard a fix is held to, not what the scans see.


**`/check-docs` rounds can be seeded, so the lanes are measured and not merely believed.** Seeding
existed for `/check-consistency` alone, and that instrument has never run here: both real rounds record
`recall = {}` and `seeded = 0`. Every claim about what the lanes catch — and every "rates comparable"
line in this file — has rested on the lanes' own report of their own denominator, which
`RULE.INST.SELF_REPORT` forbids by name.

A consistency round seeds one consolidated manuscript. A docs round's corpus is the source tree, which
must not be mutated, so `Rounds.seed_docs_corpus!` copies every file its lanes list to a disposable root
outside the repository, plants the catalogue there, and repoints the lanes' `repo` at the copy. A lane's
`files` are relative and identical on both sides, so every path a finding reports is a real path and the
fix pass edits the corpus the findings describe; a seeded defect exists nowhere to be fixed, and closes
through the `seeded` channel. `Seeds.file_manuscript` shows the files to the existing selector in the
page-marked shape it already understands, the page name being the path, and `Seeds.plant_files` applies
each seed to its file by occurrence within that page.

The ground truth is NOT written at prepare: `bank` recomputes it from the untouched tree and the round's
salt, exactly as a consistency round recomputes from the unseeded manuscripts, so nothing on disk
between the two can answer the panel. `bank` then marks the seeded findings, records recall per class
and the suspect lanes, and destroys the copy. Turned on for this package: all six classes of
`.gbg/seeds.toml` plant into the lane surfaces with none skipped.

**A round may close by CARRYING a finding, and `RULE.INST.CARRY` says which.** The long fix-verify tail
had two exits — fix it, or adjudicate it — and when neither fits, the pressure goes into a prose
adjudication, which is how the last round collected two LAUNDERED verdicts. There is a third honest
answer: the finding is real, it is not fixed, and it rides into the next round of its instrument.

Severity decides eligibility, not a quota: a `blocker` or a `major` is fixed, adjudicated or escalated,
a `minor` or a `nit` may be carried. On the last round that is 35 of 56 eligible, including
`operational-claims#7`, the minor whose four surfaces cost three passes — while both majors that
reopened at pass 12 would have stayed to be fixed, which is what happened anyway. The severity that
licenses a carry is a re-rating by `severity-recheck.js`, never the reporting lane's own: a rating that
can defer a finding is one its author has a reason to lower. That script already existed and is copied
into every round's workflow directory; `/check-docs` had simply never called it.

A carried finding is written forward whole into `.gbg/carried.toml` and re-banked into the next round
AFTER its lanes have run, so it reaches the closure loop and never the searching panel — a finding
trusted to rediscovery is a finding dropped, and `bank` refuses rather than orphan one whose lane the
roster no longer runs. There is no per-round cap: a final release refuses while the backlog is not
smaller than at the previous release, and refuses outright anything carried three times. `closed_by`
gains `carried`, a closed vocabulary, so this is MAJOR; `Release.cites_round` counts a carried id as
disposed and the backlog conditions live in the release.

**The demotion rule reads the checklist instead of counting it, and the checklist is computed.** An act
verifier grading a fix must list every surface the finding's class lives on and mark each swept or not.
The rule demoted `HONORED` to `LINE-ONLY` when that list was EMPTY — and in the 571 act verdicts of
`2026-09-09-check-docs-02` it fired **zero times**, because the list was never empty. Over the same
verdicts it admitted **21 closures whose own list named a surface `swept: false`**, across 13 ids,
`templates#3` five times naming `src/CLI/Sync.jl` — a contradiction the verifier wrote down, the tool
accepted, and the release shipped. §9's fork, demotion by content or by emptiness, is settled by that
measurement in favour of content: a `HONORED` verdict with any unswept surface is now `LINE-ONLY`.

Only 3 of the 21 were an id's final verdict, so that round would have ended with three ids open rather
than fifty-six closed — and one of the three is a `minor`, which `RULE.INST.CARRY` now lets ride. The
two changes are complements: one raises the standard, the other bounds its cost.

`Passes.class_candidates` greps every place the tree writes down a rule or scan id the finding cites,
following the scan/rule pair through `catalog/scans.toml` so a finding naming only the scan still
reaches the rule's prose. On `operational-claims#7`, whose four surfaces cost three passes at one per
pass, it names the scan's header, the rule's paragraph in `policy/docs-rubric.md` and the §12.B
catalogue row in one call. The verifier marks that list and adds what a grep cannot know; a site nobody
checked is visibly unmarked instead of unthought-of, and the verifier is told the demotion rule plainly:
if the class is alive somewhere, LINE-ONLY is the verdict, not a penalty. The demotion predicate is
measurement-affecting under D16, so this is MAJOR.

**The closure loop stops paying for what it already knows.** A cost forensics pass over the two real
rounds fitted the bill: the act verifier costs ~81k tokens per LANE-UNIT and ~12k per id, so **77% of a
pass is fixed overhead**, and 61 of the 67 id-verifications in the last round's tail were closed ids
re-checked for regression, whose measured yield of genuine regressions across both rounds is 4 in 475.

Four changes, none of which alters what a verifier may conclude:

- **The act verifier reads the fix pass's own diff.** It was handed `range`, the whole round: at pass 15
  of `2026-09-09-check-docs-02` that was 456 files and 36,559 insertions, re-read by three lane agents to
  grade six ids whose work was 9 files and 499 lines. `pass_scope` had computed the incremental range
  since the last GRADED pass and thrown it away. `pass.toml` records both, `fix_range` being what the
  verifier gets.
- **The blind verifier judges the open ids mid-round, and everything on a pass that could close.** Over
  860 verdict pairs it uniquely blocked 6 ids, all in passes 2, 6 and 8, while costing half the verifier
  bill in the four passes that cost most. What keeps it honest: an id the act verifier closes with no
  blind reading is `pending_state` — not closed, not open, driving no fix — and `close` refuses while one
  stands, so a round still ends with a full blind sweep and nothing ever closes on one reading.
  `--full-state` forces the sweep early.
- **The quote probe.** The CLI greps each finding's own quoted text in the files that finding names and
  hands the answer to both verifiers, which spent 22% of their blind evidence strings re-establishing it.
  It is evidence and never a gate: over the 56 findings of a round that closed every id honestly, 19
  quotes still stood, because a location quotes the site's identifying text as often as the defect's.
  Gating on it would have held a third of that round open with no way out.
- **A build is not re-run at an unmoved, clean HEAD.** `pass open` rebuilt the site and re-consolidated
  both manuscripts every pass; a regrade at the same head paid for byte-identical output twice.

Also: `pass open` says so when the previous pass was opened and never graded — passes 9 and 11 of that
round bought nothing at all. Rates comparable: yes; no verdict vocabulary, closure predicate or scan
threshold moved, and `per_id.state` still holds only what a verifier said.

## 1.0.0-rc.2 — 2026-09-10

The second release candidate: MAJOR. Instruments affected: check-docs, check-consistency,
audit-changes (the lane, panel, act and state scripts; the round lifecycle for all four). Rates
comparable: yes — no scan's hit set moved this cycle and the fixture recall is unchanged either side,
every planted class of `fixture/GBG Fixture/defects.toml` still hit and every clean twin still silent,
which `test/scans.jl` asserts per class in both directions.

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

**A closure pass now verifies what is open, and `pass open` REFUSES by default.** Two changes to the
closure loop, made after the second documentation round spent ten passes and most of its cost
re-verifying findings that were already closed. A pass past the first is scoped: it verifies the open
ids plus every closed id whose named files the fix pass touched again (a finding that names no file is
always a suspect), the carried verdicts come forward into the tally, and a lane with nothing in scope is
not dispatched at all. And `gbg round pass open` refuses, exit 2, when the fix pass left untouched a
file an open finding names — five of that round's ten passes were spent discovering that a fix had
stopped at the line it quoted. This is a behaviour change at a verb that used to succeed: a pass over a
fix that deliberately swept nothing (an adjudication, a rescan-only pass) now needs `--sweep-ok`, which
records the choice in `pass.toml`. An audit round is exempt, since it has no fix pass at all
(`RULE.INST.AUDIT_DISPOSED`, new: an audit is closed by disposing its concerns, never by correcting them
inside it, because a correction moves the tree and the staleness check then refuses the close for good —
learned by making `2026-09-09-audit-changes-01` permanently unclosable and abandoning it).

**The `substrate` vocabulary drops the four values that narrowed nothing.** It named six views of the
corpus — `full`, `siteonly`, `rawhtml`, `docstrings`, `rulebook`, `none` — and the panel splits the
manuscript exactly once, `siteonly` against `full`. The other four were briefs over the full text
wearing the name of a corpus, no hat in the catalogue ever took one, and the consumer-facing
`domain_hats` schema already admitted only two. What else a hat is handed is `needs`, which exists and
works. A closed vocabulary shrank, which §5.5 makes MAJOR; nothing a hat sees changed, so no finding
moves and rates stay comparable. Found by `2026-09-09-check-docs-02/operational-claims#10`, adjudicated
inside that round because the remedy was a vocabulary change, and carried out here after it closed.

**A pass that was opened and never graded no longer erases the last one that was.** `pass_scope` and
`grade` read pass `k - 1`'s tally, so an opened-and-superseded pass — one with a `pass.toml` and no
`tally.json` — read as "nothing was ever decided". A round whose every id was closed came back with all
of them open: the sweep check then refused the next pass over findings nobody had reopened, and a
regrade would have re-verified the whole round at full cost. `Passes.last_graded` walks back to the
newest pass that has a tally, and both call sites use it.

**The dev-round rule moves to the door, and stops being a trap.** D4 and D16 both said a dev-stamped
round is unclosable except by abandon; the attack review marked that defence DEFEATED; no verb
enforced it. `Passes.close` had the string only to exempt a dev round from the tag-moved refusal. So
this tool closed its own audit round at `dev+f897ee0`, and `ROUND.DEV` — a FAIL, in the quick set,
non-exemptable, on a record frozen at close, with `abandon` refusing a closed round — made a fact about
a finished round the reason `Pkg.test()` and every docs build refused, permanently and with no repair.
Five changes, one property: a refusal belongs where the answer is still cheap.

`Preflight.dev_round` refuses to OPEN a `/check-docs` or `/check-consistency` round at the tool root
while the tool names no released version; nothing is spent and the round does not exist. `/bug-hunt`
and `/audit-changes` read `base..HEAD`, off a tag by construction, and are never refused — which is
also why `ROUND.DEV` no longer names them: it is now a WARN over closed documentation rounds alone,
saying they are records rather than measurements and that no release may cite them. `Release.cites_round`
is where "the released version was reviewed" is actually enforced, on the one round a release leans on,
and it is FIXED: it compared a tag-stripped stamp (`1.0.0-rc.1`) with a tag (`v1.0.0-rc.1`), so the
final-release precondition was unsatisfiable and would have rejected a correctly stamped round.
`abandon` now takes a closed round stamped dev, keeping `closed` on the record beside `abandoned`, so
the state has an exit. And `ROUND.FROZEN` covers the stamps: its shas hashed the evidence and not the
record, so re-stamping a frozen `ROUND.toml` — the one repair that falsifies rather than fixes — passed
unseen; each stamp form now names its own revision and the three check each other.

Instruments affected: none of the scripts; the round lifecycle for all four. A round closed before this
release keeps its stamp and its meaning. Rates comparable: yes.

**A docs build during a round is SKIPPED, not failed.** `RULE.INST.FROZEN_MIDROUND` freezes the
instruments while a round is open, and the `makedocs` wrapper enforced that by failing: every push
during the second documentation round turned the Docs workflow red — twenty-five in a row — so a red
run stopped meaning anything. The wrapper now prints `makedocs: SKIPPED — <round> open`, builds
nothing and returns `nothing`, which is exit 0. `GBGCodingTools.frozen_rounds` is the new predicate
that separates a frozen build from a broken one; the gate's own refusal is held back when it is only
that. `GBG_DOCS_NO_SKIP=1` restores the refusal, and `gbg release` and the deep doctor's `SELF.DOCS`
both set it — a release never accepts a build that did not happen. A consumer's `make.jl` must guard
its `deploydocs` on the wrapper's return, or it publishes the previous run's directory; `WIRE.MAKEDOCS`
fails an unguarded `deploydocs(` at column 0, and the seed says so.

**A scan may carry a note, and `SCAN.SIGNATURE_FIDELITY` uses one.** A registered scan returns
`(hits, population)` as before, or `(hits, population, note)`; `run_scan` carries the third element into
the result, where a DEAD line prints it. Signature fidelity counts only the bindings it COMPARED, so a
package whose displayed surface is homed entirely in an extension that is not loaded measures nothing
and reads DEAD — correctly, but until now with no reason given. The note names the skipped bindings.

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
