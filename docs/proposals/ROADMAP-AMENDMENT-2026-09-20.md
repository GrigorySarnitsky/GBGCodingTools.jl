# Roadmap amendment, 2026-09-20 — readers derived, rules covered

A proposal to amend `docs/ARCHITECTURE.md` (normative), `IMPLEMENTATION.md` (the order of work) and, where
they are made false, `CLAUDE.md`, `docs/PF-WIRING.md`, `docs/ROADMAP.md` and the tool's own site. It
records what has moved since adoption on 2026-09-17 (§1) and the text that makes false (§2); states what
is ruled and, of that, what is built (§3); lists what the review machinery has and lacks (§4); re-orders
the remaining work with gates (§5); and puts every choice that is the owner's in §6, where **unanswered
means unchanged** and the phase needing it waits. Where a phase must design something, §4 names the
question with the session's proposed answer, and §5 states the gate against that answer, naming the
decisions it assumes; a different answer re-cuts the gate.

Draft 8. Drafts 0–7 were attacked from three lenses — implementability against the code, consistency with
the design and the rulings, completeness — drawing 76, 87, 77, 54, 49, 35, 37 and 31 objections, folded in
turn; the eighth round's residue is folded here and the document is handed to the owner with that trajectory
stated. Two admissions belong at the top. `70ca56a` changed values the normative document describes before
the document changed, against its own first paragraph, and added a discipline catalogue without the
question ARCH §13 requires; the session also chose, unasked, the names `bound | open | both` and where
the driver lives; decisions 14a, 28, 32 and 35 put those before the owner after the fact. And one of the
owner's rulings collides with the adopted design in a way only the owner can settle: decision 15c.

## 1. What moved

"Verbatim" rows give the owner's words exactly as the session's memory records them; "paraphrase" rows the
record's sense. Every other row is the session's work, with its commit.

| what | where | date |
|---|---|---|
| 17 agent-decided rules reworded on the owner's word ("Shall we adopt the edited rules?" — adopted with five rulings: API.POSITIONAL's exception is a `Switch`, "I am for the switch"; VARIANT_PAIR's home is ONE_HOME's; LEADING_IDENTITY and RETURNS judge form only, "ok"; LITERATE split, "Recommendation: split it. --- yes"; documents a rule names become config fields, "1. --- config fields"). The taggers' two-to-one splits fell from 9 to 3, rules flagged by at least one tagger from 18 to 8 (13 flag marks in round 1); parameters `notation_page`, `formalization`, `leading_identity`, `admonition_titles`; LITERATE's id kept with its meaning narrowed to the source habits (a narrowing, not a reuse: an older finding under it is still a finding), LITERATE_RENDERED new | `4051b26` | 2026-09-19 |
| RULE.DOC.RETIRED_CLAIMS's `why` says what a decision log does to it (PF's request) | `a13961d` | 2026-09-19 |
| Two tags on 26 rules — 25 from the taggers' round-1 majority, LITERATE_RENDERED's put on by the session (decision 27) — `access` and `needs_discipline` | `70ca56a` | 2026-09-20 |
| The 19 hand-written readers deleted; the panel computed: three bound readers, one bound reader per declared discipline, two open; `AgentRole` kept as the type of a derived reader | `70ca56a` | 2026-09-20 |
| Six disciplines catalogued as first drafts, unattacked; `Config.disciplines`; a config naming an unknown one fails `ConfigIO.validate` — reached by `Harness.test`, `gbg sync` and `gbg check`, not by the docs build's wiring check — and `derive` names it as a gap | `70ca56a` | 2026-09-20 |
| `gbg run … --readers bound\|open\|both`, default bound, recorded on the run; gaps printed at every launch and, in the report, before the findings | `70ca56a` | 2026-09-20 |
| The one driver, tracked at `drivers/run.js` in the tool | `a444df3` | 2026-09-19 |
| Ruling, verbatim: "We tune only the model, reasoning effort stays on default for everyone." | owner | 2026-09-19 |
| Ruling, verbatim: "Out of budget means the review is not finished and we cannot act on it as a whole. It must be finished." Paraphrase: a sequential option, parallel the default | owner | 2026-09-19 |
| Ruling, verbatim: expert hats "launched sparingly, as an option" | owner | 2026-09-19 |
| Ruling, verbatim: "let is have some readers be built from the rules (those that are not covered by deterministic checks). This building, as well as the way we fixed the rules now, should be part of the CodingTools." | owner | 2026-09-20 |
| Ruling, verbatim: "we need to have an option on the tool bounded/free/all (think adversarially on the names)… So the bounded will be run more often." | owner | 2026-09-20 |
| Ruling, verbatim: "a flag to specify if we run the document review on the full corpus (as specified per each reader) or only on things that changed since the tool was last run… it should be run as compared to the latest version of the package when the requested combination was run." | owner | 2026-09-20 |
| Ruling, verbatim: "Let's go with the process that gives smaller number, but set the agents to a careful model." | owner | 2026-09-20 |
| Ruling, verbatim: disciplines "we write them here, because we have a procedure for that, plus some of the domain experts may be shared between the packages"; "when wiring CT into packages, we need to make sure they know that, if anything is needed they prepare a request for you"; an undeclared discipline reported as a gap: "I am for that"; plain_sense and logician "we add them in this package" | owner | 2026-09-20 |
| Ruling, verbatim: "I want to finish the rulebook part of the design. I want every rule to be covered by something." | owner | 2026-09-20 |
| The session's, unanswered: the principle that a rule needing nothing goes to a reader given nothing, and the three bundles it produced (the owner chose "the process that gives smaller number", not the principle by name); a discipline reader carrying every `needs_discipline` rule; the six discipline descriptions; the names `bound | open | both` and `full | changed`; the driver's home; NO_INACCESSIBLE's agent half to the full reader; the scope base per rule rather than per reader combination; every verifier on the careful model; who resumes a paused run | session | 2026-09-20 |

## 2. What the amendment makes false or supersedes

Adoption edits each text; where the value already moved, the text is edited in the adoption commit.
`test/architecture.jl` compares ARCH §3's table cell by cell with the values, so that table and its value
move in one commit.

| text | status | replaced by |
|---|---|---|
| ARCH §2 "Every rule an agent checks belongs to exactly one agent role, which it checks too" | superseded | a `needs_discipline` rule belongs to every declared discipline reader (decision 23 may narrow it); a question-language rule belongs to §8's one agent; every other agent-checked rule to exactly one reader or to a gap the run names — CLASS_SWEEP the one exception until its sitting, counted (§3.1) |
| ARCH §1 "**Full strength** is the most capable model, **economy** the cheaper default"; §4.2 "every other part of a rule, agent role or instrument — id, check, examples, parameters, file sets, strength, lists" and "An agent role's `description` … stays code"; §5.2 `AgentRole.strength = ECONOMY`, "those checking mathematics run at full strength in science packages", "two groups of roles: **code readers** … and **site readers** … A *hat* and a *lane* are both agent roles"; PLAN §8 decision 7's row; `RULE.INST.ECONOMY` | superseded for READERS by the 2026-09-20 ruling (the 2026-09-19 ruling removed the effort dial, not the cheap tier); for the step-5 verifiers, decision 16; decision 7's question survives as 15a and 15d | every reader on the careful model — the most capable, named in the tool and recorded on the run (§3.3); §4.2's code list gains `access`, `needs_discipline` and `Discipline.description` (code, as a role's description is); ECONOMY, decision 30 |
| ARCH §3 table, Documentation review "ends: Nothing is open, or the budget is spent"; §10 `BUDGET_SPENT` "(fix passes or agent launches used up; the open findings go to the record and the queue)"; §10 "A run never … extends its budget"; §10 "Who stops. Inside a run, the program, from the budget fixed at start"; §5.2 `Budget`, `Stop.BUDGET_SPENT`; PLAN Phase 4 gate "a budget-spent run writes its leftovers under the uncounted heading"; PLAN §8 decision 8's row | contradicted by the 2026-09-19 ruling; how far — the agent launches only, or the fix passes too — collides with the 2026-09-16 rulings and is decision 15c; decision 8 is moot (its `gbg ask` entry withdrawn in `40ce760`; its plan row edited at adoption) | the table cell becomes "Nothing is open after its last pass, or the owner ended it" (15c FINISHED) or "Nothing is open, or the owner ended it" (15c UNFINISHED); a run whose agent budget is spent is unfinished and resumable (§3.2); the budget's unit and number, decisions 15a, 15d |
| Conditional, if 15c says UNFINISHED: ARCH §4 "at most four fix passes, and whatever is left carried over"; §4.3 step 7; §10 "Open findings carry over, as ruled"; §10's table row "At most 4 fix passes … Findings open after 4 passes carry over" | contradicted | edited at adoption if 15c says so |
| ARCH §10 `OWNER_STOPPED` as an END; §10 "Once started, a run fixes and verifies to its end without asking again" | in question: a paused run either waits for the owner's word to resume or does not | decisions 15b, 15h |
| ARCH §10 "Nothing else holds a release: no review run, no open finding, no unanswered question, no audit"; PLAN §8 decision 9's default "keep, reason drafted" | the 2026-09-20 ruling "every rule covered by something" supersedes decision 9's default — a drafted reason is not a cover — and so, for the one release `v2.0.0`, an unanswered sitting item holds it, as decision 9's "If the answer is late" column already had it; every other release is held by nothing, as ruled 2026-09-16 | the sentence gains "— except `v2.0.0`, which waits for the rulebook (PLAN §6)"; decision 9's default becomes "unchanged, and `v2.0.0` waits" |
| ARCH §5.2 `Config.roles`, `Instrument.roles`; §5.1 `Catalogue` "roles"; §9's switch list naming "the site readers checking mathematics, notation, typesetting and citations"; PLAN §1 "~40 `AgentRole`s"; PLAN §4 "each package declares … its own `PatternRule`s and `AgentRole`s"; PLAN Phase 4 batch g | superseded by the 2026-09-20 ruling and `70ca56a` | readers derived per config (§3.1); the two `roles` fields, decision 22; a switch names a derived reader's id. §9's "numerical and device-portability roles" and PLAN Phase 8's "four switches" are re-cut when Phase 6 derives the hunt's and the audit's readers |
| ARCH §5.2's type blocks | already false: `Rule` has `files_parameter`, `access`, `needs_discipline`; `Config` has `generated`, `disciplines`; `Setting.value` holds `Vector{RetiredClaim}`; `Run` has `readers`; `Access` and `Discipline` exist; 4b and 4d add `Stop.PAUSED`, `Run.scope`, `Run.sequential`, `Run.model` | re-rendered from `src/Model.jl` at adoption, and from 4b held by a test that the type blocks in ARCH §5.2 equal the structs in `src/Model.jl`, as ARCH §3's table is held today |
| ARCH §5.2 "all site examples in one Documenter build with warnings allowed"; §11 "`test/rules.jl` (which builds one fixture site)" | false today: `test/rules.jl` says "Running Documenter … would test Documenter, not the rule", and `test/Project.toml` has no Documenter | 4b adds the dependency and the in-test build (§5) |
| ARCH §5.3 "hats, lanes and the model catalogue become `AgentRole` values" | superseded | "the tags on the rules and the discipline catalogue become the readers" |
| ARCH §6 "the rules, instruments and switches pages" (the switches page is today a section of the rules page) | not built beyond the rules page | the instruments page and a readers page (4b); the switches section stays where it is |
| ARCH §6's table "the Workflow driver, agents' arguments and output schemas (scratch)"; §11 "Agent output and the driver live in a scratch directory that git ignores"; §11's list "`.gbg/runs/<id>/  run.json and report.md`" | the driver is tracked in the tool at `drivers/run.js` (`a444df3`, the session's choice: one file, versioned with the tool, never copied into a consumer — decision 35); results and arguments are written under the tracked `.gbg/runs/<id>/`, with absolute paths inside; a run also writes `stage` and `run.draft.json` there while open | the driver's home, decision 35; results and arguments to scratch, whose home is decision 34; the list gains the two open-run files |
| ARCH §6 "one `.claude/skills/<instrument>/SKILL.md` per instrument that applies"; §9 (nothing switches an instrument off here); `test/architecture.jl`'s skill line, "No skill at all until the instruments are values that run (Phase 4)", whose hold PLAN Phase 1 puts at Phase 8 ("they leave in Phase 8") | the skill keeps the design's path, `.claude/skills/documentation_review/`; "applies" is `Engine.Checks.applies`, a switch on the instrument's id — this package's config has none, so 4b adds one (a config edit, code) and the test line's comment is reworded to say so; both leave in Phase 8 | 4b, settled item |
| ARCH §11 "The same files in every package" | gains `.gbg/requests/` (RULE.GIT.REQUESTS); gains a per-rule store if decision 25 says so; `.gbg/rounds/.keep` (tracked here) is v1's and goes in the third stroke | edited at adoption; decision 25 |
| ARCH §12 "the instruments whose findings come from agents are not measured … a change to an agent role's wording, rule list or strength cannot be shown to help or hurt" | narrowed | still true of a reader's yield; a rule's TEXT is measured (§3.4) |
| ARCH §13 "`gbg attack` runs agents over this design" | widened (decision 14b) | "over this design and over the rulebook's text" |
| ARCH §13 "A rule … changes through the code fixer on the owner's answer" | narrowed: the code fixer and its audit are an instrument's path for a finding; a rule changed on the owner's direct answer — a sitting's, a tagging proposal's — is the session's commit, as `4051b26` was; the audit's path is closed until Phase 6 anyway (decision 29) | "through the code fixer on the owner's answer to a finding, or by the session on the owner's direct answer" |
| ARCH §4.2 "`test/guard.jl` holds … clause 3" | false: clause 3 (a changed `statement` or `why` literal is documentation) is not implemented; the guard's header says so | 4b, not-built list |
| ARCH §9 "Off in GBGCodingTools" (four switches, two naming reader groups) and `.gbg/config.jl`'s five switches, API.POSITIONAL's reason "this package's own reading panels do not run over it yet" | stale | re-cut at Phase 8; the reason reworded in 4b |
| PLAN §8 decision 10 | not held | the coverage sittings: 14 agent-checked rules whose `WhyAgent` nobody re-examined (decision 10 proper) and 12 tagged rules with no `AgentCheck` (decision 9's question) |
| PLAN §6 batch d | its program rules done; "`NO_INACCESSIBLE` splits into a program rule and an agent rule; the cross-check rule is `network = true`" not built — no rule carries `network = true` and `gbg check --network` runs nothing | the program half in Phase 5 (§5); decision 17 for the agent half |
| PLAN §6 batches f, h, i; decisions 9 and 11 | never held: "keep, reason drafted" was applied to all 34 on 2026-09-17 | the coverage sittings (§5) |
| PLAN §6 batches b, c and the ratchet "zero in Phase 5"; Phase 5's gate on `src/Scans policy catalog`; Phase 5 "`Main.jl` rewritten … the last old verbs" | batches b, c done on 2026-09-17 (`ALLOWANCE = 0`; `src/Scans/` and `policy/` gone; `catalog/scans.toml` still tracked); `Main.jl` and the last old verbs still to do | Phase 5 re-stated (§5) |
| PLAN Phase 4 as one block of 70 commits with one gate; §3 "Stop anywhere" row 4 ("He can ask for a documentation review of PF"); §9's risk row "Phase 4 is nine to twelve sessions"; §11's sizes; §5's version schedule (rc.1 to rc.5 exist; none contains a Phase 4 commit) | the find half is built — ten commits from `71993cc`: two the question language and `gbg ask`/`answer`, three the review machinery (`Runs`, `gbg run`, the driver), one the hand-written readers since deleted, one the rewording, one the derived readers, two the withdrawn decisions — with §4's defects; the fix half is not; row 4 is true only from rc.6 | Phase 4 regrouped and sized (§5) |
| PLAN Phase 8 "`gbg attack`" as the design review's first appearance | its first piece moves to Phase 4 (decision 14b) | §3.4, §5 |
| PLAN throughout: `IT`, `$IT` | renamed GBGHomogeneousTurbulence, `HT`, rc.5 | edited at adoption |
| `CLAUDE.md` "All 97 rules are `Rule` values", "`Orchestration` has not been started" | false since Phase 4a — it claims less built than is; `CLAUDE.md` is code and owed the rewrite in the same commit, a debt of 4a | edited at adoption |
| `docs/ROADMAP.md` (tracked; speaks of `/check-docs` rounds and scan surfaces; cited by PLAN Phase 3) | stale | deleted at adoption, the plan's citation with it |
| `docs/PF-WIRING.md`; `docs/src/guide/config.md` ("`.gbg/config.toml` … `schema/config.schema.json`, `[instruments]`, `[cost]`"); `docs/src/guide/install.md` ("`.gbg/config.toml`", "The doctor's `SELF.CONSUMER` check"); the untracked leftover `docs/src/guide/doctor.md` on disk; `docs/src/index.md` "the roles its AI reviewers adopt"; the site's missing pages for `Roles`, `Orchestration`, `Engine.Questions`, `gbg run|ask|answer`; the rendered rulebook printing "Decided by nothing yet" for the 12 tagged rules with no `AgentCheck` and naming no reader for any rule; `.gbg/policy/glossary.md` without reader, bound, open, bundle, discipline, gap, standpoint, request | false or missing | 4b (§5) |

Conditional row, if decision 31 says a habit is no cover: ARCH gains a testing section holding the
principles of the eight rules of Phase 5's fourth row before they are retired; the rulebook's
`testing-protocol.md` shrinks to what has a check.

Conditional rows, if 4b's absence-finding answer is a node-only location: ARCH §4.1 "a quote it cannot
find is named in the report and given to no fixer", §4.3 step 6 "Every verdict except `NOT_FIXED` needs a
quote", §5.2's `Location`.

## 3. Ruled, and what of it is built

### 3.1 Readers

**Ruled:** readers built from the rules no program decides; the process that gives the smaller number;
every reader on the careful model (that "careful" is ARCH §1's full strength, the most capable, is the
session's reading); disciplines written here and shared, declared by a package, requested
when lacking; an undeclared discipline a reported gap, never a fallback; plain_sense and logician added
here (all 2026-09-20); expert hats as an option (2026-09-19). **The session's** (decisions 14a, 23, 32):
the principle that a rule needing nothing goes to a reader given nothing, and the three bundles; every
`needs_discipline` rule to every declared discipline; the names.

**Built** (`70ca56a`). A rule a program cannot decide carries two tags: `access` — NOTHING (exclusive),
SIBLINGS, OTHER DOCUMENTS, SOURCE, RENDERED, HISTORY, CITED WORK, or a combination — and `needs_discipline`;
25 from the taggers' majority (§3.4), one the session's (decision 27). Three things are written by hand and
are mechanisms under ARCH §13; everything else is computed:

- the **bundles**, tried in order — *withheld*: one unit and nothing else; *full*: siblings + source +
  other documents; *rendered*: the built site + siblings + other documents. A rule goes to the first
  bundle whose material covers its need; a need no bundle covers (HISTORY, CITED WORK, RENDERED + SOURCE)
  is a gap. First-fit over three sets: NOTHING sits only in the first;
- the **discipline catalogue** (`Discipline`: `id`, `description`), declared in `Config.disciplines`
  (decision 28 for the six);
- the **open standpoints**: *plain_sense* on the withheld bundle, *logician* on the full bundle.

From these: one bound reader per bundle a rule lands in; one bound reader per declared discipline, given
the full bundle and that discipline's standpoint, carrying every `needs_discipline` rule; the two open
readers; every reader `Strength.FULL`. Gaps — a rule no bundle covers, and the `needs_discipline` rules
where no discipline is declared — are printed at every launch and in the report before the findings. A
whole-package switch removes a reader or a rule by name. A retagged rule moves readers without any reader
being edited; a reworded rule does not move until retagged, and a tag is code under §4.2. Held by
`test/readers.jl`: NOTHING is never combined; a tagged generic rule is on exactly one bound reader or is a
gap; with no discipline the five `needs_discipline` rules are on no reader and the gap names them; a
whole-package switch removes a reader by name; `select` by `bound`, `open`, `both`.

**Not built.** The careful model is `Strength.FULL`, which the driver maps to the platform's default,
unnamed and unrecorded (4b). Two counts in `test/readers.jl`, ratchets that may only fall until the
sittings settle their items (4b): agent-checked rules of the reader families (`DOC`, `TEX`, `CIT`, `API`)
with no tag — 1, CLASS_SWEEP (ASK.PLAIN is a question rule, §8's agent's, itself unbuilt); tagged rules
with no `AgentCheck` — 12. A `needs_discipline` rule tagged NOTHING is a gap (the code skips the test). A
file-scoped switch reaches no reader: the arguments carry no switches and the brief has no switch
paragraph. `start` refusing an instrument with an empty panel — today a bug hunt opens and launches
nobody (and cannot reach `close` either, §4). Expert hats in open mode (decision 24; built in 4b if
answered, else after). What a withheld reader is handed: today, the file sets — the source included (4b).

### 3.2 A run that is not finished

**Ruled** (2026-09-19): a run whose budget is spent is unfinished, is not acted on as a whole, and must be
finished; a sequential option beside the parallel default. **Built:** nothing — `BUDGET_SPENT` is never
assigned, no verb resumes, the driver launches every role in parallel with no flag. The budget's unit and
number are decisions 15a, 15d (its home stays the `Instrument` value, as the design has it); whether the
four-pass cap is part of "budget" is 15c; the owner's stop, 15b; who resumes, 15h; where a paused run's
results live, 34; the rest is 4b's design (§4).

### 3.3 Which model

**Ruled:** the model is the only carefulness dial; every reader on the careful model. That "careful" is
ARCH §1's full strength, the most capable model, is the session's reading, taken as the meaning of the
ruling.
**Built:** `Strength.FULL` on every reader. **Not built:** the model named in one place in the tool, passed
by the driver, recorded as `Run.model` (4b); the step-5 verifiers' model and what becomes of `Strength.T`
(decisions 16, 16b).

### 3.4 What is measured

**Ruled:** "This building, as well as the way we fixed the rules now, should be part of the CodingTools."
**Done once, by hand** (2026-09-19): three blind readers, given only the rules' text, answer per rule the
unit, the material, the competence and the polarity, and flag UNDERSPECIFIED with a quote; Fleiss' kappa on
material and competence, splits and flags are computed; the majority becomes the tag. Round 0 (27 rules) →
round 1 (25, two procedures removed): material κ 0.74 → 0.90, competence κ 0.93 → 0.91, rules flagged by at
least one tagger 18 → 8, two-to-one material splits 9 → 3, one competence split each round; the 8 untouched
controls gave 1 split and 2 flags, the floor. Kappa is necessary, not sufficient: three round-1 rewrites
named documents no package could declare. Polarity is not carried; what it showed — an ABSENT-polarity
rule (RETURNS, MODULE_MAP, TWO_TIER, COVERAGE_BASES) cannot be reported under a schema demanding a quote per
place — is 4b's question. **Not built:** the verb (4e); the fixtures — the round-1 tagger outputs and the
encoded tables are in the session's scratch directory, not in the repository; filing them under `test/` is
4e's first commit; round 0's flags exist only in transcripts and are not reproducible.

The procedure is a **design review**, not an instrument: it produces proposals — a tag drift, a flag —
that become questions or are dismissed with a reason, and writes nothing, so a tag changes only on an
answer. `gbg attack rules` is its verb; the review over `ARCHITECTURE.md` stays Phase 8's.

## 4. The review machinery: built, not built, defective, accepted, and the open questions

**Built (the find half):** questions and answers outside a run; `Runs` (stages in order, the record,
`unguarded_code`; `Runs.reanchor` with its git step exists, tested by `test/anchors.jl`, and is called by
no verb — `collect` anchors through `Texts.reanchor` with no `since`, so `BY_DIFF` is unreachable through
the verbs); `Agents`; the one driver with its one schema; `Render.report`; the rehearsal over a synthetic
package; the derived panel; `--readers`; the hook's uncounted heading.

**Not built (the fix half and around it):** ARCH §4.3 steps 1–7 — re-anchor before each pass, the guarded
fix, the other-copies search, the formula-edit rule (agreeing code and a numeric check, else a question),
`gbg docfix check`'s actual checks, the blind verifier over a copy exported without history and the diff
verifier, grading, `DocFix` and `Verdict` records — with the verifiers' own output schema, selected on
each stage's arguments, and the collector's path for verdicts; the guard's clause 3, without which a
reworded `statement` is code and no rewording can be committed through `gbg docfix commit`; `gbg docfix
commit` handing the generators' output to the guard (clause 0 never fires from the CLI), and looking past
the open run's own `stage` and `run.draft.json`, which are untracked and so refuse every guarded commit
made inside a run; the pass driver and the four-pass cap (`advance!` admits `pass → pass` without limit;
through the verbs a run reaches one pass, at which `next` launches the reader panel again); a stage
machine that can tell a repeated stage name apart (the bug hunt's list repeats `collect`, and `findfirst`
on the name sends it back to `witnesses` for ever, so a hunt never reaches `close`); refusal to start on a
dirty tree; collect's exit 2 when a tracked file changed under the readers; close's second program; the
work-queue lines at close, and the hook cutting only the section under its heading rather than everything
to the end of the file (anything the owner appends below it is uncounted today); carry-over into the next
run; `Run.questions` in the record and `gbg answer`'s path into it (`answer!` reads and writes
`.gbg/questions.json` only); `Questions.put` has no caller in `src`; settled locations re-anchored before
they are handed to agents; §8's one agent judging ASK.PLAIN, with the rewrite-once path; `Render.skill`
and `Wire` writing `settled.jl`, `questions.json` and the skill at the design's path — where the instrument
is not switched off, with the refusal ARCH §11 requires where the package owns a workflow, `settings.json`,
the work queue or a skill of that name, which `write_all` does not have; the instruments page and a
readers page; the glossary's new terms and `house_terms` with them; sequential launch, with its flag, its
driver key and its record field; `Run.tokens` and `Run.model`; `Release` ported off the legacy config (it
reads `.gbg/config.toml`), and ARCH §10's two printed lines (Phase 6's); the switches handed to readers;
the docs build's wiring check validating the config; `gbg fleet` listing the fleet's open requests to this
package; the fixture's `docs/make.jl` ported to `makedocs(root)` (it calls the legacy `Config.read`);
a retirement register in the catalogue — `Catalogue.RETIRED`, ids with reasons, which `test/conversion.jl`'s
`RETIRED` becomes, since nothing under `src/` can read a test file — and `known_ids` including them, so
`ConfigIO.validate` tolerates a switch on a retired rule's id and a retirement does not redden a consumer
that switched the rule; expert hats in open mode, if decision 24 is answered.

**Defects in what is built:** `Stop.BUDGET_SPENT` never assigned; launches charged at `collect` as the
panel's size whatever the driver launched; a malformed result file counted as a reader that wrote
(`collect_results` records the role before it parses, against its own comment), so `collect` exits clean
where the design says 2; the brief byte-identical across stages; `site = true` hands over a sentence, not
a site; the `docstrings` file set is `src/**/*.jl`, so a reader kept from code is handed the source;
results and arguments one directory per run, overwritten each stage, under the tracked `.gbg/runs/` with
absolute paths inside; no tool policy — withholding is asked for, never enforced; the schema's `checked`
and `candidates_found` fields read by nobody, and the brief never asks for the count; the caps set by feel,
per launch; `Finding.source` the literal `:agent`; `config.normative` on no surface; `GUARD_TRAILER`
written by nothing; CLASS_SWEEP agent-checked and on no reader; a parameter naming a file the package
does not have reported by nothing; the fixture's own config naming page and Literate files that do not
exist (`docs/src/api/fixture.md`, `examples/walkthrough.jl`), and `ConfigIO.validate` not checking file
sets though its docstring says it does; the docs build's wiring check not validating the config; this
package's config switching off no instrument, so a run opens here today.

**Accepted limits, so an owner knows they are accepted:** `README.md` is documentation under §4.2 and on
no reader's surface; `CHANGELOG.md` is code under the guard and unread; figures unread; reading order
across pages nobody's (TERMS_DEFINED is same-page); the rendered rulebook under `.gbg/policy/` not a
surface; a reader's place list may be incomplete and nothing knows; `docs/make.jl`'s `pages` unread, so
an unreachable page is unnoticed; a claim whose truth lies outside the package nobody's; a fenced example
that is not a doctest never runs; a link whose target is outside the source (a dead URL) unchecked;
documentation faithful to code the design forbids reads clean — no rule asks "true to the design", VERIFIED
asks "true of what the code computes", and no reader is told which of source and normative document is
the oracle; withholding and the model enforced only if the platform enforces what the driver passes; a
consumer's docs build that reads legacy review state (PF's `lint_review_closure()`) does so until Phase 7.

**Settled, to build in 4b (no question open):** `Finding.source` the reader's id, as `Model` already
documents it; the careful model named and recorded; results and arguments out of `.gbg/runs/` (their home
is decision 34); the two ratchets of §3.1 and the NOTHING-with-discipline gap; `start` refusing an
instrument with an empty panel; a switch on `documentation_review` in this package's config until Phase 8, and the skill at the design's
path `.claude/skills/documentation_review/` in every consumer where it applies;
a fixture that declares a discipline and whose page and Literate sets exist; a parameter naming a missing
file reported as a gap; the guard's clause-3 examples in both directions, a changed tag among the code
ones; `--sequential` recorded and read by the driver.

**Conditional on a decision:** the four-pass cap as ARCH §4.3 step 7 states it (15c FINISHED); expert hats
in open mode (24).

**Questions each piece must answer before it is built**, each with the session's proposed answer, which
the gates in §5 assume:

- *4b, an unfinished run.* What marks a run paused — proposed: the agent budget spent mid-stage (in
  whatever unit 15a sets), or a stage whose readers are not all collected when a verb next runs; the
  owner's stop mid-stage is 15b's; `CANNOT_EVALUATE` stays for a step that exits 2 or 3, as ARCH §10 has
  it. Who resumes — decision 15h. The per-stage layout — proposed: `<scratch>/<run>/<ordinal>-<stage>/`,
  the scratch root decision 34's. `resume` — proposed: relaunches only uncollected readers into the same
  stage directory, and `collect` reads that directory once, when every reader's file is there. ARCH
  §4.1's relaunch-once — proposed: unchanged, the session's act inside one launch. A resumed stage meeting
  a tree that moved — proposed: collect's exit 2 measured from the stage's launch commit. "Sequential" —
  proposed: the driver launches the roles in series when the arguments say so. A verifier launch per
  FINDING, given the bundle and, for a `needs_discipline` rule, the standpoint of the reader that made it;
  the act verifier also given the diff. A carried finding whose rule now sits on another reader —
  proposed: verified by that reader's bundle; a gap — closed as unjudgeable and said in the report. `gbg
  answer … "fix the code"` before Phase 6 — decision 29. Where close writes in the work queue — proposed:
  under its heading at the foot, reused on later runs, with the hook cutting that section alone.
- *4b, what a reader is given* (the budget's unit depends on it, so it is 4b's). The withheld reader's
  unit per rule — proposed: for a page rule, the built page's article body from a site built inside the
  run by the package's own `docs_build`, excluding pages the config declares generated; a red build at
  `find` is `CANNOT_EVALUATE`, as ARCH §10 has it; for a docstring rule, the same page (the rendered `@docs`
  entry is what a reader meets; TERMS_DEFINED says "page"); for a rationale document also built, one unit,
  anchored to its tracked source through `copies`; for LITERATE, the Literate files actually built. Which
  of the withheld reader's seven rules travel with which unit — proposed: those whose file sets include the
  unit's kind. A docstring no `@docs` block collects — proposed: the full reader's alone, said on the
  readers page. The full bundle's size (decision 26). The rendered reader handed `docs/build`. An absence
  finding — proposed: a location with a node and no quote; `Texts.reanchor` by node alone; the
  other-copies search skipped; grading by node. The caps under per-unit launch — proposed: per launch,
  the count asked for and reported. What a consumer edits to show the readers and instruments pages —
  proposed: `Render.pages` returns them; `gbg sync` prints the two `make.jl` `pages` entries and the two
  `generated` entries the consumer adds, and the wiring check reports them until added.
- *4d, scope.* The flag — proposed: `--scope full | changed`, default `full`, recorded as `Run.scope`. The
  base — decision 25; the session proposes per rule and standpoint, in a store `.gbg/runs/judged.json`
  written at a finished run's close; under "unchanged" (per combination), the commit that added the last
  finished run's `run.json` with that `readers` value, found with `git log -1 -- .gbg/runs/<id>/run.json`;
  either base invalidated — the rule runs full — by a tool bump, a switch or setting changed, or a
  discipline declared since. The diff-to-units mapping — proposed: NOTHING, the units whose text changed;
  SOURCE, the docstrings whose binding's body changed where `Texts` can bound it, else all; SIBLINGS, all
  units when any sibling changed; OTHER DOCUMENTS, all units when the named document changed, the document
  being the rule's own parameter (ONE_NOTATION, COORD_FREE) or another rule's it names (HOME_ORDER through
  ONE_NOTATION's `notation_page`, CIT.STYLE through FULL_INLINE's `references`), or any document of the
  file sets where it names none (VARIANT_PAIR, GREEK_AB, ADMONITION_TITLE, STEER — so a docstring edit
  runs them full); RENDERED, the pages whose source changed; combined tags, the union; open readers, the
  same as the bundle they sit on. A `CANNOT_EVALUATE` run — proposed: not a base. Carried findings in a
  `changed` run — proposed: worked regardless of scope.
- *4e.* Through the one driver — `test/driver.jl` holds that there is one — with a second output schema
  selected by the arguments; what a proposal looks like as a question — proposed: one question per rule
  with a drift, its options the majority tag and the carried tag.
- *Phase 5.* Each item as a question in ARCH §8's form, with its statement, its origin and a proposed
  cover; the sitting's answers recorded in `test/conversion.jl`'s `SITTINGS` list, one line per id; the
  session commits each answered change directly, as `4051b26` was (§2's ARCH §13 row). The 61 items are put as questions into this repository's own `.gbg/questions.json` through `gbg ask`,
  which is where `gbg release --counts` reads the unanswered ones; the count is 61 on the day they are
  put, not zero. The proposals for the 27 items the table below does not cover — CLASS_SWEEP's is in
  §5's opening paragraph: the 12 tagged rules with no `AgentCheck` get one, with
  `WhyAgent` READING_ORDER for HOME_ORDER and MODULE_MAP and MEANING for the rest — except NO_HSCROLL and
  GREEK_AB, which the session proposes become PROGRAM checks (a line's width on the built page; an
  `alpha`/`beta` spelling outside the two named exceptions), by deterministic-first; NO_HSCROLL as a
  program leaves the rendered reader with LITERATE_RENDERED alone; the reader and its one launch stay.
  The 14 agent-checked rules keep their `WhyAgent` unless the sitting objects (NO_INACCESSIBLE, decision
  17).

## 5. The plan, amended

### Phase 4, regrouped

Calibration: `Runs`, `gbg run` and the driver took three commits; the readers one; the fix half is larger
than both together.

- **4a done** (10 commits from `71993cc`): the question language, `gbg ask`/`answer`; `Runs`; the
  hand-written readers; `gbg run` and the rehearsal; the driver; the two decisions, withdrawn; the
  rewording; the derived readers and `--readers`.
- **4b — the review made whole** (50–70 commits, 6–9 sessions): everything §4 lists as not built and
  defective, the settled items, the conditional items whose decisions are answered, and 4b's questions
  answered in their commits; the texts of §2's last row. **Gate** — `test/rehearse.jl` over the `gbg run`
  verbs, on a copy of the fixture in a system temporary directory, `git init`ed, its site built in-process
  by Documenter through `makedocs(root)` from the loaded package (a `Documenter` dependency in
  `test/Project.toml`; `docs/build` is gitignored; the run's own `docs_build` command is asserted to be
  invoked, its result substituted), from reader, fixer and verifier files recorded in one real Workflow launch over the fixture copy — the
  session's launch, as the plan's Phase 4 gate had it, so the verdict schema and the per-unit launch have
  been written through the driver at least once — assuming 4b's proposed answers and decisions 15a
  (launches per stage; under tokens the pause assertion reads a usage figure the driver writes into the
  stage's arguments, and the rehearsal fabricates it), 15c (FINISHED), 15h (the owner's word), 29 (parked)
  and 34 (`.gbg/scratch/`). **4b does not start until 15a, 15c, 15h and 34 are answered**, as §6 says of
  every phase; what follows is the gate under the recommended answers: a review runs to four passes and a fifth is refused; a run whose agent budget is spent
  mid-stage ends `PAUSED`, resumes, relaunches only the uncollected readers, collects each finding once,
  and writes nothing to the work queue (void if 15a says "none"); a run interrupted with one reader
  uncollected is `PAUSED` when the next verb runs, and `resume` refuses without the owner's flag; a `DONE`
  run with findings open after four passes writes one queue line per finding under the uncounted heading,
  and a line the owner appends below that section is still counted; a malformed result file is NAMED and
  `collect` exits 2; a question put at find is in the record at close and `gbg answer` reaches it, one
  from each of the plan's three exits; `HIDES_CODE_DEFECT` produces a question that passes
  `Questions.check`; `MADE_WORSE` reverts; the formula-edit rule produces a question where the code does
  not agree; after `gbg run next` into a pass, `run.draft.json` shows a moved location `BY_DIFF`; collect
  exits 2 when a tracked file changed under the readers; a start on a dirty tree is refused; a bug hunt
  refuses to start, and, by a unit test of `advance!`, a stage list with a repeated name advances to
  `close`; close on a red build restores the documentation through a guarded commit; a second run carries
  the first's open findings and closes one whose text is gone as `OUTDATED`; settled locations are
  re-anchored in the arguments; every withheld launch's arguments name exactly one unit — an article body
  with no navigation, or one Literate file — and for a page unit no `.jl` path, over a fixture whose page
  and Literate sets exist; the rendered reader's arguments name the `docs/build` the test built; a
  verifier's arguments name its finding's reader's bundle and, for a discipline finding, its standpoint,
  and its result file is read through the verdict schema; a file-scoped switch reaches the reader's
  arguments; `--sequential` is recorded and in the arguments; an absence finding is re-anchored, fixed and
  graded by node; the report names the reader behind each finding and `Run.model`; the readers page lists
  the panel, the gaps and a switched-off reader; a guarded commit succeeds while a run is open; nothing
  under `.gbg/runs/` but `run.json`, `report.md` and the open-run files §2 names; `test/guard.jl` holds
  clause 3 in both directions and a changed tag as code; `Wire` on a package that owns a skill of the same
  name prints the difference and exits 1, and writes no skill where the instrument is switched off — as
  this package's config does after 4b's settled item, so `test/architecture.jl`'s skill line holds; the two ratchets
  and the NOTHING-with-discipline test in `test/readers.jl` hold; ARCH §5.2's type blocks equal
  `src/Model.jl`. Not gated, because no test can see it:
  that the platform honours the model and the tool policy the driver passes; `Run.tokens`, if the platform
  reports nothing; the relaunch itself, which is the session's.
- **4f — the six disciplines attacked** (3 sessions, 1 commit): three lenses per description — a
  scientist of that field, a reader of the five rules it would carry, a plain-language reader — attacking
  until a round has no objection of substance; run by this session, judged by the owner as decision 28,
  filed in the design record. Before any package declares one.
- **Release `v2.0.0-rc.6` after 4b and 4f.** Its CHANGELOG entry covers everything since rc.5 (`d72414a`),
  which contains no Phase 4 commit: the five `RULE.ASK.*` rules, `gbg ask`/`answer`, `.gbg/questions.json`,
  `settled.jl`; RETIRED_CLAIMS's `why`; `gbg run` and its verbs, `.gbg/runs/`, the driver, the skill;
  `Question`, `Run`, `Finding` and the other `Model` types; the 17 rewordings and four parameters with
  their defaults; LITERATE narrowed under its id, LITERATE_RENDERED new; the 19 deleted reader ids; the six
  discipline ids; `Rule.access`, `Rule.needs_discipline`, `Config.disciplines`, `Run.readers`, `--readers`;
  what 4b adds — the agent budget's unit, `PAUSED`, `resume`, `--sequential`, `Run.model`,
  `Finding.source`, the per-stage scratch layout, the readers and instruments pages and the two
  `make.jl`/`generated` entries a consumer adds, `Wire`'s new files and its refusals, the glossary's terms;
  and decisions 22, 24, 28 and 30 if answered. `docs/PF-WIRING.md` rewritten in the same release: how a
  review is asked for (the skill), `--readers`, what PF sets (next). **Then PF**: its session proposes
  disciplines — the session here reads them against the five rules; under 23's per-field alternative
  `differential_geometry` would own COORD_FREE and ONE_NOTATION, `spectral_numerics` VERIFIED,
  COVERAGE_BASES and LEADING_IDENTITY; as built each carries all five — sets `formalization` (PF has `docs/FORMALIZATION.md`; the default is none) and
  confirms `notation_page`, `leading_identity` and `admonition_titles` against their defaults, declares
  `copies` for its five built rationale documents (ARCHITECTURE, DECISIONS, FORMALIZATION, TESTING,
  PERFORMANCE),
  narrows its `literate` set to the one built example, bumps, adds the two page entries, and runs the
  review — PF's work, on its own pin, outside this plan's sizes. PF's legacy `.claude` commands and
  `docs/make.jl`'s `lint_review_closure()` stay until Phase 7, as written. A request for a reader or a
  discipline is a file in RULE.GIT.REQUESTS's form, `.gbg/requests/to-CT-<date>-<topic>.md`; `gbg fleet`
  lists the fleet's open ones; the CLAUDE block says so.
- **4d — scope** (10 commits, 1–2 sessions). **Gate**: replayed from recorded files over the same fixture
  copy declaring one discipline, after a finished bound run, assuming decision 25 as recommended (per rule;
  "unchanged" re-cuts the base clause): one edited docstring D, one added sibling docstring S, one edited
  notation page N, one edited hand page H and one edited function body under an unchanged docstring E
  produce exactly the set the §4 mapping gives over the tags as they stand (computed by hand here; a
  retag re-cuts it): the NOTHING page rules (GRAMMAR, SELF_CONTAINED, TERMS_DEFINED, RETURNS,
  CODE_SPAN_JULIA, IMAGINARY) on H and on D's page, LITERATE on nothing; the SIBLINGS rules (TWO_TIER,
  ONE_HOME, ALIASING_BULLET, MODULE_MAP) in full; ONE_NOTATION and HOME_ORDER in full (N changed);
  CIT.STYLE on H alone (its document, the reference list, is unchanged); VARIANT_PAIR, GREEK_AB,
  ADMONITION_TITLE, STEER, LEADING_IDENTITY and COORD_FREE in full (they name no document, or a phrase, or
  an empty parameter, and D is a document of their file sets); VERIFIED and COVERAGE_BASES on D and E (the
  discipline reader's; D's text and E's body changed); API.POSITIONAL in full (SOURCE + OTHER DOCUMENTS,
  the union, naming no document); NO_HSCROLL on H and D's page; LITERATE_RENDERED on nothing; plain_sense
  on H and D's page; logician in full — and nothing else; the base is per rule in `judged.json`; a paused run
  and a `CANNOT_EVALUATE` run write no base; a tool bump, a changed switch and a changed setting since the
  base run each read full; a discipline declared after the run reads full; `Run.scope` is recorded.
  Release `-rc.7`.
- **4e — `gbg attack rules`** (8 commits, 1 session), the fixtures filed first. **Gate**: the arithmetic
  over the filed round-1 fixtures gives κ 0.90 / 0.91, 8 rules flagged, 3 material splits and 1 competence
  split; `test/driver.jl`'s one-driver assertion still holds; a replayed drift becomes a question that
  passes `Questions.check`.

### Phase 5 — the rulebook finished, then CP (7–8 sittings, then 5–7 sessions)

Opens with the **coverage sittings** — decisions 9, 10 and 11 held as the plan said, eight to ten items a
sitting, each item a question in ARCH §8's form: the 34 rules with neither check nor tag; CLASS_SWEEP
(agent-checked, on no reader; it instructs the fixer, who is the session — the CLAUDE block, a skill, or
retirement); the 12 tagged rules with no `AgentCheck` (decision 9's question); the 14 agent-checked rules'
`WhyAgent` (decision 10), NO_INACCESSIBLE among them (decision 17): 61 items. Unanswered means unchanged;
each answered change is the session's commit on that answer (§2's ARCH §13 row). What makes this different
from 2026-09-17: the counts are functions of `Catalogue`, held in one place — `test/readers.jl` and
`test/conversion.jl` assert them, `gbg release --counts` prints them; `test/conversion.jl` carries a
`SITTINGS` list, one line per item answered, and two of the counts may only fall — rules with neither check, nor tag, nor a cover a sitting recorded (a habit counting
only if decision 31 says so, and a rule with one checked clause and one habit clause counting as covered
only if 31's second half says so; 34 today), and agent-checked reader-family rules on no reader (1) — and
`gbg release --counts` prints those two and the unanswered sitting items, refusing nothing; `v2.0.0` is
cut when the owner reads them at zero (§2's ARCH §10 row). The session's proposal per rule:

| cover | rules |
|---|---|
| a program over the tree; `intention = CODE`, so it runs in `Pkg.test()` through `Harness.test`, not in the docs build | GIT.REQUESTS (the file's name and status paragraph; "tracked" is git's and stays a habit); the checkable half of GIT.CI_MANUAL (workflow files dispatch-only, docs deploy on push; "the matrix runs locally" is a habit); GIT.NO_SHIMS narrowed to what a tree walk sees (`@deprecate`, `depwarn`) or kept as a habit |
| a program that reaches the network, run under `gbg check --network` alone — never in a build or a test | the `network = true` program half of NO_INACCESSIBLE (batch d): a DOI or link that resolves to the work it names |
| a program over git state in the end-of-turn hook (regenerated for every consumer at bump; it reads only the work queue today; the sitting says whether a finding prints or blocks the turn; offline it prints "not checked") or in a verb; never in a build or test | GIT.PUSH; GIT.TRAILER (its statement requires the versionless trailer ruled 2026-09-08, and every recent commit here carries a versioned one — the sitting decides which changes); GIT.BRANCH (needs a `branch` parameter, which `Release`'s port needs too); GIT.MANIFEST_TRACKED ("tracked" is git state; its ignore block the wiring check already compares) |
| a test in this repository that the named enforcer exists, wherever it lives, and is called where the rule says — a rule value cannot hold a harness function, which sits above `Catalogue` (batch f) | BUILD_VERIFY (`makedocs`); INST.WITNESS (`Witnesses.run`, Phase 6's move); ORACLE_INDEPENDENT, ALLOC_ZERO, PASS_AUDIT, METHOD_PARITY (`TestHarness.*` — legacy, called from no wired package since the generated `runtests` passes no `contracts`; the sitting says harvested into `Engine.Harness` or wired as they are); RULE_WITH_CHECK, COUNTS_REMEASURED (`test/schemas.jl`) |
| the named enforcer checks nothing of the kind: a reader over tests — an instrument whose object is tests, which does not exist and would need §13's question — or kept as a stated habit (decision 31; if a habit is not a cover, the session proposes these eight are restated as principles in ARCH's testing section and retired as rules, so `v2.0.0` does not wait for Phase 6) | TEST.GATE_VS_SURVEY, MUTATION, BOTH_DIRECTIONS, MISSING_IS_FAILING, DEFINITION_OF_DONE; EXAMPLES_RUN (names `harness:makedocs`, which runs no example — PF's own `make.jl` does); INST.NO_TRUNCATION (names `harness:report`, which checks nothing of the kind); DOC.BATTERY (v2 has one instrument: structural or a habit) |
| **restated** for v2 and held by a test of `Runs` or of the design: the substance stands in ARCH, the words are v1 | SELF_REPORT (ARCH §4.3 steps 5–6), AUDIT_AFTER_CODE (§4.4, the one audit), FROZEN_MIDROUND's first clause (§10 "never … changes an instrument"), CARRY's first clause (§10 "Open findings carry over" — if 15c says FINISHED; else retired), CONSENT (§10 Start; decision 19) |
| retirement on the record (batch h): the machinery is gone — lanes, rounds, the ledger, banked, seeds, `ROUND.toml`, `CARRY_LIMIT`, economy lanes, "four instruments" — or a ruling is against. Decision 30 asks whether these go BEFORE rc.6, since PF's first review would otherwise run under an `instruments.md` describing dead machinery; each goes as its own §8 question naming the id and why | INST.FOUR_OBJECTS, CLOSURE_LOOP, AUDIT_DISPOSED, FIX_FROM_LANES, SEEDS, ECONOMY, the rest of FROZEN_MIDROUND and CARRY |

Then batches f, h and i as the sittings decided; the **third stroke**, the plan's list in full — `Scan.jl`,
`Reflection.jl`, `DocLints.jl`, `HtmlWalker.jl`, `TreeHash.jl`, `CLI/Config.jl`, `CLI/Ledger.jl`,
`.gbg/config.toml` here and in the fixture, the fixture's `.gbg/hats/`, `.gbg/rounds/.keep`,
`catalog/scans.toml`, `TestHarness.jl` harvested or its contracts wired as the sitting said, `Main.jl`
rewritten and the last old verbs; `Witnesses.jl` stays for Phase 6 — with what reads them: this
repository's own `docs/make.jl` (`using GBGCodingTools: TestHarness, Reflection, Witnesses, Config`),
`ext/…Ext.jl`'s `makedocs(cfg::AbstractDict)` and `write_public_surface`, `CLI/Self.jl`'s `TreeHash`,
`CLI/Main.jl`'s `LedgerError`, `test/helpers.jl` (`Config.parse`, `scan_catalog`), `test/schemas.jl`,
`test/config.jl`, `test/scans.jl`, `test/treehash.jl`, `test/coverage.jl`, `test/architecture.jl`'s
`config.toml` line, `test/runtests.jl`'s `run_regressions` and four legacy includes, the site's
`api/{Reflection,TestHarness,Config}.md` and `index.md`'s `run_regressions` link; `LAYERS` gains
`GBGCodingTools.jl`, `CLI/{Main,Bump,Release,Fleet,Install,Self,Git}.jl`, `Rules/citations.jl` (a new-tree
file counted as legacy today) and, if kept, `TestHarness.jl`, and `LEGACY_CEILING` falls to 1
(`Witnesses.jl`); a `CP-WIRING.md` written by this session, saying how
CP's `[extras]`/`[targets]` test declaration becomes a `test/Project.toml` the pin can land in, and which
catalogued disciplines CP's session may propose (`cloud_microphysics`, `turbulence_theory`, as attacked in
4f and ruled in 28); CP wired
by CP's own session, as ruled 2026-09-17, on the last candidate after 4d; `v2.0.0` cut here. **Gate**:
`tools/floor.sh && tools/floor.sh "$PF" && tools/floor.sh "$CP" && test -z "$(git ls-files -- src/Scans
policy catalog .gbg/config.toml .gbg/rounds "fixture/GBG Fixture/.gbg/config.toml" "fixture/GBG
Fixture/.gbg/hats" src/Scan.jl src/Reflection.jl src/DocLints.jl src/HtmlWalker.jl src/TreeHash.jl
src/CLI/Config.jl src/CLI/Ledger.jl)" && julia --project test/conversion.jl && test "$(gbg release
--counts)" = "0 0 0"` — the last a printed line, the hold §2's ARCH §10 row records, not a refusal;
`test/architecture.jl`'s `LEGACY_CEILING = 1` inside the floor holds the rest.

Phase 6 derives the bug hunt's and the change audit's readers by the same procedure over material kinds of
their own — the code under test, the test files, a suite run — which `Access` does not name; no TEST rule
is tagged, and until Phase 6 both instruments refuse to start, the change audit included, so the code
fixer's path (ARCH §4.4) is closed until then (decision 29). Phases 7–9 as written; HT and SS declare
disciplines when wired, from the catalogue as ruled by then; one they need and it lacks goes request file →
this session → the owner's answer → release → bump. `IMPLEMENTATION.md` §11 is re-cut at adoption from the
sizes above: Phase 4, 10 done + 69–89 commits and 11–15 sessions (4f's three included); Phase 5, 7–8
sittings and 5–7 sessions.

## 6. Decisions for the owner

Nothing here has a default: unanswered means unchanged, and the phase that needs it waits. Numbers are
stable across drafts; 15e, 17b, 18 and 21 are withdrawn (15e and 17b re-asked the design and the plan; 18
is inside 30; 21 is a handoff to PF's session, in §5); 33 was never assigned.

| # | question | recommendation |
|---|---|---|
| 14a | Adopt the session's part of the derivation: the nothing-to-nothing principle and first-fit over the three bundles as built | Yes |
| 14b | `gbg attack rules` in Phase 4 (4e), ahead of Phase 8's design review, widening ARCH §13's `gbg attack` to the rulebook's text | Yes |
| 14c | The re-ordering of §5: 4b → 4f → rc.6 → PF → 4d → 4e | Yes |
| 14d | Edit every §2 text at adoption, including the texts `70ca56a` ran ahead of | Yes |
| 15a | The agent budget's unit: unchanged (launches per run) / launches per stage / tokens per run / none. Exhibit, PF under `bound` with two disciplines: the find stage launches the withheld reader once per unit — PF's `pages` lists 21 files, one of them generated, so 20 units, the Literate one among them — plus full, rendered and two disciplines: about 24; `open` adds about 21; each later stage launches two verifiers per open finding. At 40 launches per run the four passes are unreachable | tokens per run if the driver can read the platform's usage, else launches per stage; a spent budget pauses |
| 15b | The owner's stop mid-stage: a pause (resumable) or the `OWNER_STOPPED` end | a pause |
| 15c | A run whose four passes are used with findings open: FINISHED with carry-over (the 2026-09-16 rulings: cap of four, carry-over stays) or UNFINISHED (the 2026-09-19 words read over ARCH §10's "fix passes or agent launches") | finished: the cap is about convergence, the 2026-09-19 ruling about resources |
| 15d | The budget's number, in 15a's unit | for launches per stage, 60; for tokens, set after PF's first run reports one |
| 15f | A paused run the owner does not want resumed: a verb, or nothing (it stays paused, blocking `start`) | a verb |
| 15g | Such a run's findings: dropped or carried | dropped |
| 15h | Who resumes a paused run: only the owner's word (ARCH §10's Start rule and CONSENT), or the next session on its own (ARCH §10's "without asking again" and "it must be finished") | the owner's word |
| 16 | The model of §4.3's step-5 verifiers, blind and diff (step 3's are full strength already) | the careful model |
| 16b | `Strength.T` once no reader is economy: kept for Phase 6's hunters, or removed with `Run.model` alone naming the model | removed |
| 17 | NO_INACCESSIBLE's agent half: retag to OTHER DOCUMENTS and reword its `question` (today it asks reachability) so the full reader judges whether a citation is to something unpublished — now, or at its sitting | at its sitting |
| 19 | INST.CONSENT: a restated rule (ARCH §10 Start), or the CLAUDE block's instruction alone with the rule retired | retired; the instruction stands |
| 20a | Hold the sittings as §5 states, each item a question in §8's form | Yes |
| 20b | `gbg release --counts` prints the three counts and refuses nothing | Yes |
| — | (21 withdrawn: a handoff, in §5's PF step) | |
| 22 | Remove `Config.roles` and `Instrument.roles` (no consumer uses either; a config naming `roles` then exits 2) | Yes |
| 23 | A discipline reader carries every `needs_discipline` rule (built, the session's choice against ARCH §2), or only its field's, needing a field per rule that the taggers could name for two of five | every rule, until a run shows an expert wasting a launch |
| 24a | Expert hats in open mode: their id | `<discipline>_open` |
| 24b | How they are asked for | `--readers` gains `experts`, added to whatever else runs |
| 25 | Refine the scope base from per reader combination (the owner's words; the default) to per rule and standpoint (survives a rule moving readers; needs a store in every package) | per rule, in 4d |
| 26 | The full bundle for PF in one launch (about 27,000 lines and 11 rules), or split along the lattice (siblings-only, other documents, source) | one launch until PF's first run shows it thinning |
| 27 | LITERATE_RENDERED's tag (`rendered`), put on by the session | ratify; the first `gbg attack rules` run reports any drift as a proposal |
| 28 | The six disciplines as catalogued, put to the owner after 4f with the descriptions that survived | Yes to whatever survives |
| 29 | `gbg answer … "fix the code"` before Phase 6: recorded and parked, the report saying the code fixer's path is closed; or refused with exit 2 | recorded and parked |
| 30 | Retire the batch-h rules — FOUR_OBJECTS, CLOSURE_LOOP, AUDIT_DISPOSED, FIX_FROM_LANES, SEEDS, ECONOMY, the v1 parts of FROZEN_MIDROUND and CARRY — before rc.6, each as its own §8 question on the record, so PF's first review runs under a rulebook without dead machinery; or at their sittings | before rc.6 |
| 31 | Is "kept as a stated habit" a cover under "every rule covered by something"? And is a rule with one checked clause and one habit clause covered? | neither: a habit is a rule nobody finds broken; the habit clause is retired or restated |
| 32 | The names `--readers bound \| open \| both` and `--scope full \| changed`, chosen by the session under "think adversarially on the names" — `free` rejected as free-of-charge, `all` as colliding with scope, `rules` as the program checks | ratify |
| 34 | Where a paused run's results and arguments live: `.gbg/scratch/` (already in the generated ignore block and in `Runs.own_record`, so every wired consumer carries it; git-ignored, inside Dropbox, against the working agreement that scratch never lives in a repository — bounded to one directory per run, deleted at close) or a system temporary directory (outside Dropbox; lost between sessions, so a paused run cannot resume in a later one) | `.gbg/scratch/`, bounded and deleted at close |
| 35 | The driver's home: tracked in the tool at `drivers/run.js` (`a444df3`) or in each consumer's scratch as ARCH §6 and §11 say | tracked in the tool |

## 7. What this opens and closes

**Opens, in PF on rc.6.** A reader panel nobody lists: a retagged rule moves readers, a new discipline is
one catalogue entry, a reader is switched off by name. A review that names what it did not judge, the
reader behind each finding and the model that ran; unfinished runs resumed instead of filed; a consumer's
entry point to the instrument; a rewording that can be committed as documentation. **Opens, on 4e:** a
measurable for the rulebook's own text, with its tooling. **Opens, on the sittings:** a `v2.0.0` whose
rulebook has a cover for every rule, shown by three counts a verb prints.

**Closed by the rulings already given:** free-form personas per package (the ruling; the two fields go on
22); the `economy` strength for readers; leftovers filed for want of budget (15c says how far). **Stays
closed until Phase 6:** a bug hunt or change audit, and with the audit the code fixer (29). A reader's
yield stays unmeasured. The fix half is unbuilt until 4b; `CLAUDE.md` claimed less built than is, the
plan's one Phase 4 gate could not tell either way, and this amendment says so.

## 8. Answered on 2026-09-21

The owner answered the blocking decisions in conversation; the record is the memory note
`roadmap-amendment-2026-09-20`. In short: **15a** no agent budget — the design bounds launches; "budget"
in the 2026-09-19 ruling meant the plan's tokens, and an interrupted run continues or restarts. **15c**
finished after four passes, carry-over as ruled. **15h** the next session continues an interrupted run on
its own, saying so in the chat, waiting only if the tree moved. **15b/f/g** `gbg run abandon` ends a run
`OWNER_STOPPED`, findings dropped. **34** `.gbg/scratch/<run>/`, deleted at close. **14a–14d** adopted.
**16** `Strength` stays as a per-agent tier setting (a reasoning-effort setting may join it later); the
blind verifier runs at the tier of the reader whose finding it judges, the diff verifier economy. **22**
both `roles` fields removed. **23**, revised after three fresh reviewers read the record: the four rules
about formulas, notation, coverage and the identity sentence were always a careful generalist's with the
source and are the full reader's; only stating maps without flattening is a geometer's, and names its
discipline (`Rule.discipline = :differential_geometry`, the boolean gone); a declared discipline is an
OPEN expert, bound only to a rule naming it — which answers **24** with no new flag (experts run under
`open` and `both`); the withheld reader is a scientist in the package's fields, new to the package. Built
in the commit that follows this note, with the 28 truncated `why` texts restored from the v1 rulebook
and COORD_FREE's lost allowance ("state the basis and the space it acts on") put back. The claim-ownership
mechanism (each expert marks the claims it owns; the review prints the claims nobody owned) is a later
refinement, to build when a run with experts shows the need.

**Adopted 2026-09-21 (14a–14d):** every §2 text was edited in `docs/ARCHITECTURE.md`, `IMPLEMENTATION.md`, `CLAUDE.md` and the site in the adoption commit, with the two `roles` fields removed (22); this file stays as the record of how the amendment was reached and what the owner answered.
