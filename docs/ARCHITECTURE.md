# GBGCodingTools — architecture

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

This is the target design, and it is normative: code that disagrees with it is wrong, or this document changes first.
It follows the owner's rulings; no question about it is open. A term in **bold** is defined where it first appears, and
the reason for each mechanism is given in brackets: a requirement R1–R10 from the owner, or a failure seen in the past.
R11 asked for a short normative architecture in plain words: this document is its whole answer. Not in it: the
migration order (`IMPLEMENTATION.md`); history and evidence, with the replaced architecture (`docs/design-record/`).

## 1. Purpose and scope

GBGCodingTools is a Julia package, on the Julia 1.12 floor. It keeps the owner's Julia packages written to one set of
rules, and it helps AI sessions find and fix defects in them without breaking how they work. It serves the four science
packages — [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/),
[GBGHomogeneousTurbulence](https://grigorysarnitsky.github.io/GBGHomogeneousTurbulence.jl/),
[GBGStreamingStatistics](https://grigorysarnitsky.github.io/GBGStreamingStatistics.jl/),
[GBGCloudPhysics](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/) — and itself. Each of the
five is a **package** below; the **owner** is the person who owns them; a **session** is one Claude Code conversation
working in a package. GBGCodingTools is also called the tooling package here.

It does four things:
1. It holds the **rulebook**: every rule on how documentation and code are written, each a Julia value carrying its
   statement, the check that decides a violation and, where a program decides, examples that break and comply [R5, R7].
2. It runs the rules' program checks inside each package's documentation build and test suite, always [R7].
3. It provides **instruments**: procedures the owner asks a session to run, which find defects. Documentation defects
   are fixed without the owner and the fixes are checked; code defects are put to the owner [R1, R2].
4. It generates every file that connects a package to GBGCodingTools, so the five carry the same files [R6].

It is not: needed by anyone who only uses a science package (it is a developer-side dependency, §5.1); a reviewer that
runs unasked, apart from the one audit an approved fix carries with it (§4.4); a place for plans or history; and not a
defence against a session that forges files. It guards against honest, overconfident mistakes: a program, not a
session, decides whether a change is safe and when work stops.

A **finding** is one reported defect with every place it occurs. A **run** is one execution of one instrument on one
package. An **agent** is a model instance a session launches to read and report. A **failing test** is a small test,
written by an agent, that fails on the package as it is. **Careful** is the most capable model, and every reader of a review runs on it [ruled 2026-09-20];
`Strength` stays a per-agent setting, `FULL` or `ECONOMY`. Every `gbg` command exits 0 (nothing found), 1 (findings), 2 (cannot evaluate) or 3 (crash); no
verdict is read from a log, and no check's output is shortened.

## 2. How the checks and instruments differ

The owner's three distinctions are used, each with one value per check or instrument [R3, R4]:

- **Intention** — what the defects it looks for are in. *Documentation*: docstrings, comments, hand-written pages and
  rationale documents, as §4.2 lists exactly. *Code*: everything else, including stored data that code reads. The
  future leak scan alone has a third value, *publication*, because a leaked password is neither [R8].
- **Decided by** — who says a finding is real. *A program*; *an agent proposes and a program decides* (the agent writes
  a failing test, and the finding exists only if GBGCodingTools runs it and it fails); *an agent*, quoting it.
- **How found issues are fixed** — *by whoever ran the build or test*, as ordinary work; *the documentation fixer*
  (automatic, checked); *the code fixer* (only on the owner's answer, checked); *regenerated*; *by the owner only*.

No two rows of the table in §3 have the same three values; `test/architecture.jl` reads those three columns from
`ALWAYS_ON` and `INSTRUMENTS` and fails on a repeat, and no further distinction is needed to separate them. The last
two columns are fields of the same values (§5.2) — an always-on check has no run, so its ending is a dash — and the
test compares the whole table. Every rule has one of three **covers** (§7): a program, a reader, or an instruction the
session follows. A rule a reader judges belongs to exactly one reader, or the run reports it as a gap; a rule naming a
discipline belongs to that discipline's reader; a question-language rule to §8's one agent.

## 3. The table

**Always-on checks** are programs run by every build and test; nobody starts them and they have no runs [R7]. What they
find is fixed by whoever ran that build or test, as part of the work in hand: no run, no verifier, no question.
**Instruments** run only when the owner asks, in words or by slash command (as ruled), with the one exception §10's
start rule writes down. The two fixers exist only for what an instrument found. An instrument's name says so: a
**check** is always on, and a **review**, **hunt**, **audit** or **scan** is an instrument the owner starts; a new one
is named the same way. Inside the code the word "check" keeps its ordinary meaning (`Rule.check`, `Questions.check`,
`gbg docfix check`), and names nothing that runs on its own.

| | Purpose | Intention | Decided by | How found issues are fixed | When it runs | A run ends when |
|---|---|---|---|---|---|---|
| **Documentation checks** (always on) | Documentation has the house structure and formatting and renders as written | Documentation | A program | Whoever ran it, as ordinary work | Every docs build | — |
| **Code checks** (always on) | The code keeps its tested contracts and every accepted failing test passes | Code | A program | Whoever ran it, as ordinary work | Every `Pkg.test()` | — |
| **Wiring check** (always on) | Every generated file or part of a file equals its generator's output | Code | A program | Regenerated by `gbg sync`, `gbg bump` or `gbg release` | Every build and test | — |
| **Documentation review** | Documentation is true to the code, correct, consistent and self-contained; the change guard, the checks and a verifier agent check each fix | Documentation | An agent | Documentation fixer | Owner's request | Nothing is open after its last pass, or the owner ended it |
| **Bug hunt** (future) | The code does what its documentation says | Code | An agent proposes, a program decides | Code fixer | Owner's request | Every candidate is confirmed or discarded, once |
| **Change audit** (future) | A code change is no wider than the defect and the owner's direction and still accepts input that worked before; it grades the fix and changes nothing | Code | An agent | Code fixer | After each approved code fix, and on request | One pass over the change |
| **Leak scan** (future) | Nothing secret or personal is published when a repository is made public; it writes nothing but session output | Publication | A program | Owner only | Owner's request | One pass over every branch, commit and message |

A Change audit starts by itself in exactly one place: once, over an approved code fix that has gone green (§4.4) —
superseding the earlier ruling that an audit was only advised, since the owner asked to be told not just that a bug was
fixed but how well. It never audits its own follow-ups, and §10's start rule carries the exception in full.
Documentation review and Bug hunt can meet one disagreement between a docstring and its code from opposite sides: the
review compares, the hunt reports only what a failing test shows; either way a possible code defect reaches the owner
as a question, and an answered question never returns (§8).

Three rows are marked future and are built only when the owner asks: the Bug hunt and the Change audit, deferred on
2026-09-21 so that the documentation half reaches the four science packages first, and the leak scan, future from the
start. Deferring the two code rows defers the code fixer with them, and with it the one place an instrument starts
itself — an audit over an approved code fix — so until they are built nothing in this package changes code, and a code
defect an instrument meets is what it already was: a question to the owner. The table test (§6) reads all three as
future.

The leak scan is built later, by adding its rules, a reader of every branch, commit message and `Manifest.toml` path,
one `Instrument` value and the `PUBLICATION` intention — none of which exists yet, so the table test (§6) reads that
row as the one marked future. It writes no tracked file: no run record, report or work-queue line. Its findings are
printed in the session that ran it, where the owner reads them and acts. `Guard.refuse_publication` is called by every
writer of a tracked file — run record, report, question store, settled rulings, work queue — and exits 2 on text from a
publication run.

## 4. Finding and fixing

```
FINDING PARTS                        FIXING PARTS
Documentation review ─┐              ┌─ about documentation ─► DOCUMENTATION FIXER ─► guarded commit
Bug hunt ─────────────┼─► collect ───┤     ─► checks ─► verifier, blind then with the diff ─► closed or open
Change audit ─────────┘              └─ about code ─► question ─► the owner's answer, with any direction:
                                          "fix the code" ─► CODE FIXER ─► attempts until green (3 at most) ─► commit
                                               ─► ONE CHANGE AUDIT ─► its grade and concerns to the owner
                                          "fix the documentation instead" ─► DOCUMENTATION FIXER
                                          "not a defect" ─► optionally recorded as settled (§8)
```

An always-on check has no run: a red build or test is fixed by whoever ran it as part of the work in hand, and the
wiring check's answer is to regenerate (§3). The two fixers below are for what an instrument found. **Finding and
fixing are separate parts** [R1]: a check or an instrument finds and hands what it found to a fixer, which fixes. What
keeps them apart is who does the work — a fix is graded by agents that did not find the defect and are not told how it
was fixed (§4.3 step 5), or by an audit that found neither (§4.4). A fix pass is a stage of a run and spends its
budget; the judgement of that pass belongs to someone else.

**Why only agent findings are rationed.** When a program decides, fixing may repeat until the check passes, with no
limit: the check is the same question every time, answers the same way on the same input, and says itself when the work
is done. When an agent decides, a fresh reading of edited text is a new opinion, not the same question again, and
nothing guarantees it ever reports nothing: hence one search per run, at most four fix passes, and whatever is left
carried over [reviews re-reading after each fix ran 9 and 15 passes without settling]. The code fixer's three attempts
(§4.4) are not this rationing: they are a judgement about the fixer, not about the loop.

### 4.1 Finding, and the handoff

Agents write one result file each into the run's scratch directory (`.gbg/scratch/<run>/`, §11) and nothing else: **collect** turns those files into
findings and exits 2 when a tracked file changed while agents ran. An agent whose file is missing or malformed is
relaunched once, then named in the report. Collect gives each finding an id and fixes the list, so a run never searches
twice, and anchors every location (§4.5): the agent gives the file, the quote and, where it knows it, the node; the
program fills in the rest, including the line, which it never takes from an agent, and a quote it cannot find is named
in the report and given to no fixer. A location in a declared build-time copy (§6) moves to the same node and quote in
its tracked source when the copy is identical to it, and is otherwise dropped and reported [fixes landed in a copy the
build then overwrote].

A finding goes to the documentation fixer when its instrument's intention is documentation and its agent did not mark
it as a possible code defect; otherwise it becomes a question. The change guard has the last word (§4.2).

### 4.2 What is documentation, and the change guard

**Documentation** is exactly: docstrings and comments in `.jl` files under `src/` and `ext/`; hand-written Markdown
under `docs/src/`; the package's `README.md`; the rationale documents the config names; and, in GBGCodingTools, the
prose of its rules — the `statement` and `why` of a `Rule`, and nothing else in that value. **Everything else is code**
[R2]: other `.jl` files, whole (tests, `docs/make.jl`, Literate scripts, whose comment marks decide what runs);
`Project.toml` and `Manifest.toml`; the config; stored data code reads, in any format; every generated path and
declared copy (§6); CI, hook and skill files; `CLAUDE.md`; any document the config declares normative, which wins over
"rationale" (this document, for GBGCodingTools) [a fix aligning a specification with code would authorise that code];
and every other part of a rule, agent role, discipline or instrument — id, check, examples, parameters, file sets,
the access and discipline tags, strength, lists.

The **change guard** is the program `Guard.classify(cfg, path, before, after, generated)`, where `generated` is what
that path's generator produces now, or `nothing` where no generator writes it. The caller supplies it: the guard lives
in `Engine`, which may not reach `Render` (§5.1), so the verb holding the generators — `gbg docfix commit`, and the
wiring check — regenerates and hands the text in, and no layer below `CLI` calls a generator [as ruled]. The guard
returns documentation only when all of these hold, and code otherwise:
0. a generated path or declared copy whose new content is exactly `generated` is left out of the classification: it
   merely follows whatever else the commit changed, and any other content there is code. This is what lets a reworded
   rule statement be committed with the policy files it feeds (§4.3 step 2);
1. the path is on the documentation list;
2. for `.jl`: both versions parse; removing line numbers, plain string literals standing alone at top level or in a
   struct body (unattached and field docstrings), and docstrings whose text is a plain or `raw"…"` literal and whose
   target is a definition, leaves the same parsed code. A docstring whose target is a call, or a macro call other than
   a defining one (`@kwdef`, `@enum`), makes the change code: Julia then documents the call instead of running it. A
   docstring with `$(…)`, or a computed `@doc` argument, is never removed;
3. in GBGCodingTools only, differences confined to plain string literals given to the keywords `statement` or `why` of
   a `Rule(…)` call are documentation — any number of them, in any number of files — with the parsed trees identical at
   every other node; a moved, added or removed argument, a changed id, check, example or parameter, or an interpolated
   string in those fields, is code;
4. no changed comment contains a Literate mark (`#src`, `#md`, `#jl`, `#nb`);
5. in every removed docstring and every changed page, every fenced block whose info string starts with `jldoctest` or
   `@` is identical, info string included, and in the same order — doctest input and output, `@example`, `@eval`,
   `@setup`, `@meta`, `@raw`, and the signatures and filters of `@docs`, `@autodocs`, `@index` and `@contents`.

Clause 3 is narrower than "the prose of a rule and of an agent role". An agent role's or a discipline's `description`, like the
`question` of a rule an agent checks, is an instruction to an agent: rewording it changes what the instrument looks for
and no program compares it with anything, so it stays code. A rule's `statement` is read by agents too, so it is not
simply documentation either: it is the one code-like text the fixer may touch, and only under §4.3 step 3, listed in
the report.

Accepted limit: a longer docstring shifts what `@__LINE__` returns — the same shift that moves every line below an
edit, which is why a finding is anchored to a node and a quote (§4.5). `test/guard.jl` holds one example per clause, in
both directions [parsed code alone passed changed doctest output, a `@autodocs` filter, and a docstring that stopped a
call from running]. For clause 3: two reworded `statement`s and a reworded `why` in one file (documentation); a changed
check, id, tag or argument order, an interpolated statement and a reworded `description` (code); and the same rewording
outside the tooling package (code).

### 4.3 The documentation fixer — automatic, with checks

The documentation fixer is the session on the careful model, working through `gbg docfix` steps. It starts only inside a
run the owner asked for, and then fixes and verifies without asking again [R1, R2].
1. **Re-anchor, then other copies.** Every pass begins by re-anchoring the open findings (§4.5); a location that comes
   back `OUTDATED` is named in the report and not worked on. A program then searches every documentation file for the
   finding's quote and each formula in it, adding every hit as a further location, anchored like the rest [a fourth
   copy of a corrected formula survived a fix].
2. **Guarded commit.** The fixer edits, then `gbg docfix commit` regenerates every generated part whose generator reads
   the prose that changed — the policy files and the tooling package's block in `CLAUDE.md` — and classifies every
   changed path in the working tree with the change guard, which leaves those regenerated parts out by its clause 0. It
   commits all of them on the current branch if every classified path came back documentation, else exits 1 and commits
   nothing; the session then pushes. This is the one verb that commits, because the guard must run before a commit
   exists, replacing the old rule that no verb commits [a code edit committed before the guard ran would be pushed].
3. **Formula and rule-statement edits.** An edit that changes mathematics — inside a math span: a symbol, a number or
   a sign; years in citations do not count — is **never made automatically**: the change guard refuses it (clause 6) and
   the finding becomes a question for the owner [ruled 2026-09-21]. The rule considered before that, and declined, was
   an automatic edit backed by a quote from the documented method's body plus a numeric check the program ran; the
   reason it was declined is that both halves make the CODE the oracle, so code that is itself wrong certifies prose
   matching it, and the tool would be executing Julia an agent had just written. A reworded rule statement (§4.2
   clause 3) stays automatic but is verified blind on the careful model, the verifier being given the rule's check and
   its examples, because no program compares a statement with the check it names. Both kinds are listed in the report
   [a docstring was "fixed" to contradict code that was itself wrong; a fix wrote false mathematics].
4. **Checks.** `gbg docfix check` runs the documentation checks, doctests and docs build; a check that passed at the
   run's first commit and fails now is exit 1.
5. **Verifier, blind first.** `gbg run next` re-anchors the findings (§4.5) and writes the blind stage's arguments from
   the anchors it got, so the text a verifier is sent is the text the finding is about. A verifier is given what the
   reader that made the finding was given (§5.3) — one built page alone for the withheld reader's, the whole material
   with the source for the full reader's, a discipline's standpoint for its own — and reads, in a copy of the tree
   exported without git history, each finding, the current text at its locations — or, for an `OUTDATED` one, the
   file's changed regions — and every region the pass changed, without the old text or the fixer's explanation. The
   blind verifier runs at the tier of the reader whose finding it judges; the diff verifier runs economy [ruled
   2026-09-21]. It answers `FIXED`, `NOT_FIXED`, `HIDES_CODE_DEFECT` (the documentation describes
   code that looks wrong) or `NOT_A_DEFECT`. Only after that stage is collected does `gbg run next` write the second,
   for `FIXED` findings only, which sees the diff and may answer `LINE_ONLY` (fixed at some locations only) or
   `MADE_WORSE` [blind reading caught false mathematics; the diff stage caught 11 of 13 fixes made at one line only].
6. **Grade.** A program applies the verdicts. Every verdict except `NOT_FIXED` needs a quote the program finds in the
   current text, or it becomes `NOT_FIXED`. `MADE_WORSE` reverts the edit; `HIDES_CODE_DEFECT` reverts it and asks the
   owner — unless the owner already answered "fix the documentation instead", when the edit stands and is listed. A
   `NOT_A_DEFECT` closes the finding for this run, listed but never stored.
7. **Passes.** Open findings return to step 1, up to 4 [verified fixes rose 16 → 39 → 55 → 74 % over four passes in one
   package, 43 → 69 → 76 → 95 % in another, then 93 and 90].

### 4.4 The code fixer — only on the owner's answer

The code fixer is the session making a code change the owner asked for [R2].
1. **Approval, and direction.** A code finding becomes an item of a question (§8) and nothing is touched until the
   owner answers "fix the code"; a run's code findings form one question with an answer per item [a hunt confirms 9 to
   21 defects]. The answer may carry the owner's **direction** — how he wants it fixed — recorded with the question,
   handed to the fixer, and handed to the audit as part of what the change is measured against.
2. **Attempts, on the deterministic oracle.** The fix then repeats until the failing test goes from failing to passing
   and `Pkg.test()` and the docs build are green; it may loop because the oracle is the same question every time and
   answers the same way (§4), so it ends by passing. Three guards: the failing test is frozen for the loop and an
   attempt that edits it does not count [weakening the test is the cheapest way to pass]; any change under `test/` is
   named first to the audit [a fix that also edits the test that would have caught it is the shape an audit exists
   for]; and after three failed attempts the loop stops and the attempts, with what each failed on, go to the owner as
   a question [in the owner's words: if the same problem is not fixed in three attempts, there is reason to believe the
   fixer cannot fix it cleanly — a judgement about the fixer, not the budget of §4].
3. **Commit.** The change is committed on the current branch and pushed; there is no separate branch. The failing test
   of a question the owner has not yet answered is committed by `gbg run close` into `test/regressions/escalated/` —
   the one code path a run may add to, since nothing there is run or referenced and a witness left in scratch is lost.
   `Pkg.test()` never runs that directory; on a green fix the code fixer moves the test unchanged into
   `test/regressions/`, and on any other answer deletes it.
4. **One audit, and a grade.** A Change audit then runs once over that change, without the owner asking. It is given
   the finding, the owner's direction and the diff, and returns concerns and a **grade**: whether the change was no
   wider than the defect and that direction, whether it changed a default or a documented contract, and whether input
   that worked before still works [an audit caught two regressions the failing tests missed]. Both reach the owner with
   the fix, in the `CodeFix` kept with its question (§5.2) — in the run record when the question came from a run, in
   the question store otherwise — and in the run's report: not only that it is fixed, but how well.
5. **No recursion.** The audit never audits its own follow-ups: a concern the owner wants fixed is a new question, and
   on his approval it loops as above and gets its own single audit. Nothing chains on its own and every step waits on
   an answer [fix → audit → fix, each audit fixed inside the next, is the loop that had to be stopped].

### 4.5 Where a finding is, while the text moves

A line number is not a place: a fix earlier in a file moves every line after it, four passes compound that, and a
carried finding's lines were read at an older commit, so a stale number points at whatever now sits there — which is
how a fix lands in the wrong paragraph. So a **location** (§5.2) is the file; the **node** — for `.jl` the binding or
method documented, or the field of a constant when the text is a generated docstring (`ARGS_FORM.statement`), for
Markdown the heading path, empty where there is none of these; the **quote**, the decisive text as it read then; and
the line, kept only as a hint.

**Re-anchoring** runs before each fix pass, before each verifier stage, and when a finding is carried into a later run.
`Texts.reanchor` does the two steps that need only files: **the node** — parse the file with Julia's own parser
(JuliaSyntax, part of Julia 1.12) and find the named definition, or scan the Markdown headings — and then the quote
inside it (`BY_NODE`); failing that, **the quote alone**, nearest the old line when there are several (`BY_QUOTE`).
`Runs.reanchor` is the wrapper a run calls: it tries `Texts.reanchor` first and, when that fails, maps **the old line**
by `git` through the changes since the finding was made (`BY_DIFF`) — which is why the git step lives there, not in
`Texts` (§5.1). If all three fail the location is `OUTDATED`, never pointed at whatever now sits on that line: the
report names it, the fixer is not sent there, and a verifier that needs it is given the file's changed regions.

## 5. The Julia object model

### 5.1 Modules, types first

Each module uses only the modules above it. A rule's check may use only `Model` and `Texts`, which is why rules sit
beside their checks in `Catalogue`, above the machinery that runs them. What executes inside a consumer's build or test
— the harness and the `makedocs` wrapper — may not reach `Orchestration`, where run records live; the tooling package's
own test files may, since they test it. `test/architecture.jl` parses the sources and fails on any reference, qualified
or imported, that breaks either rule.

```
Model          every struct and enum; no behaviour, no values
Texts          reading docstrings, pages and the built site, given a Config value; anchoring by node and quote
Catalogue      RULES (src/Rules/*.jl, each rule beside its checks), INSTRUMENTS, ALWAYS_ON, DISCIPLINES, RETIRED,
               the reader derivation (Roles), GENERATED — data
ConfigIO       the literal-only readers of config.jl and settled.jl; validate; applies
Engine         Checks, Harness, Guard, Questions.check's programs   ← the harness reaches no further
Render         the generators and the wiring check                  ← the makedocs wrapper reaches no further
Orchestration  Agents (arguments), Runs, and Runs.reanchor's git step
CLI            the gbg verbs, each a function returning an exit code
```

**What must be Julia, and what may be borrowed.** The skeleton is Julia because of what it is for: the types, the rules
with their checks and examples, the agent roles, the instruments and the generators are what the owner reads, what
Documenter renders on the package's own site, and what its own instruments read when pointed at it; a rulebook in
another language could be neither reviewed as values nor checked by the machinery it describes. Beyond the skeleton
there is no thrift: packages and external programs are used wherever they do the job better, which replaces the older
rule of no Python and no child process beyond a few named commands, still carried in `CLAUDE.md` [as ruled].

One boundary stays: whose dependency this is. GBGCodingTools is a **developer-side** dependency: it lives in each
package's `docs/` and `test/` environments, which `gbg sync` writes, and never in the package's own `[deps]`, so `]add
GBGPeriodicFields` pulls none of it and no user of a science package resolves it. What it brings — JSON3, Gumbo and the
rest — is paid for there, by the developer. What runs inside a consumer's build or test stays offline and starts no
child process, because CI must give the same answer every time; the instrument side, run only when the owner asks, is
free, and already starts `git`, the docs build, the tests and witnesses. Settled case by case:

| Job | Answer | Reason, and what it costs |
|---|---|---|
| The Workflow driver | one fixed JavaScript file, tracked in this package at `drivers/run.js` and run from the pinned version's depot, never copied into a consumer [ruled 2026-09-21]; `test/driver.jl` holds it to the arguments `Agents` writes | the Workflow tool runs JavaScript and nothing else; no JavaScript parser, since `node` is not installed here, so a driver it cannot parse shows up as exit 2 |
| Reading `config.jl` and `settled.jl`; the Markdown heading path | hand-rolled: Julia's parser plus forty lines of "these literals only"; ten lines of heading scan | a parser package would be no shorter, a sandbox to evaluate in reopens the hole the reader closes, and Julia's Markdown standard library drops the line an anchor needs |
| Searching text | Julia | 627 Markdown and Julia files of a science package, 8.6 MB, in 60 ms; `ripgrep` is not installed here |
| Records, agent schemas, the built site | JSON3 and Gumbo | 100 ms and 5 ms to load, once per process, against writing a parser and an HTML reader; both are paid for in the developer's `docs/` and `test/` environments, never in a user's |
| Diffs, hashes, history | `git`, an external program | every workflow here needs it already, and a diff reimplemented in Julia would be strictly worse |

### 5.2 Types

Enums are scoped (`module Decider; @enum T …; end`) so values of different enums never share a name.

```julia
module Intention; @enum T DOCUMENTATION CODE; end          # PUBLICATION arrives with the leak scan
module Decider;   @enum T PROGRAM FAILING_TEST AGENT; end
module Fixer;     @enum T ORDINARY_WORK DOCUMENTATION_FIXER CODE_FIXER REGENERATE OWNER_ONLY; end
module Input;     @enum T SOURCE_TEXT FILE_TREE LOADED_MODULE BUILT_SITE QUESTION; end
module FileSet;   @enum T DOCSTRINGS PAGES RATIONALE LITERATE CODE TESTS; end
module Strength;  @enum T ECONOMY FULL; end; module Part; @enum T WHOLE BLOCK TOML_ENTRIES; end
module Verdict;   @enum T FIXED NOT_FIXED LINE_ONLY MADE_WORSE HIDES_CODE_DEFECT NOT_A_DEFECT; end
module Stop;      @enum T DONE CANNOT_EVALUATE OWNER_STOPPED; end
module Access;    @enum T NOTHING SIBLINGS OTHER_DOCUMENTS SOURCE RENDERED HISTORY CITED_WORK; end  # what a reader is given
module WhyAgent;  @enum T MEANING DERIVATION READING_ORDER; end
module Anchor;    @enum T FRESH BY_NODE BY_QUOTE BY_DIFF OUTDATED; end
"Where a finding is: the node and the quote hold it still while the text around it moves; the line is a hint (§4.5)."
Base.@kwdef struct Location       # node: for `.jl` the binding, method or field of a constant documented
    file::String; node::String = ""; text::String = ""   # (`ARGS_FORM.statement`), for `.md` the heading path;
    line::Int = 0; found::Anchor.T = Anchor.FRESH        # text: the quote. The line is a hint, `found` its anchoring
end
"What an agent or a check reports, before a run gives it an id."
Base.@kwdef struct FindingDraft
    rule::Union{Symbol,Nothing}; locations::Vector{Location}   # every site, each with its own quote
    claim::String; evidence::String; fix::String               # evidence: a failing test's path, or a reason
    maybe_code::Bool = false                                   # the agent thinks the code, not the text, is wrong
    in_material::Bool = false     # located only in material a reader was given to consult: the owner's, never the fixer's (§10)
end
"One defect in a run: the draft, its id, and who reported it."
struct Finding; id::String; source::Symbol; decider::Decider.T; draft::FindingDraft; end
```

A **file set** is a named set of a package's files, found by default patterns the config may override. A check's
**input** is what it reads: a source text, a small file tree, the loaded package, the built site, or a question.

```julia
"A possible answer, with what happens if it is chosen and what it costs."
struct Option; label::String; consequence::String; recommended::Bool; end
"One decision inside a question; items share the question's options, and each is answered on its own."
Base.@kwdef struct Item
    text::String; recommended::String; sources::Vector{String}
    answer::Union{String,Nothing} = nothing; direction::String = ""   # this item's answer, and any direction with it
end
"A decision put to the owner; plain data, checked only when it is put."
Base.@kwdef struct Question
    id::String; decision::String; context::String; options::Vector{Option}; items::Vector{Item} = Item[]
    exhibit::String = ""              # commits, changed files and definitions: exempt from the language rules
    answer::Union{String,Nothing} = nothing; direction::String = ""   # for a question with no items (§4.4)
end
"What decides a violation: a program, or an agent for one of the reasons in WhyAgent."
abstract type Check end
struct ProgramCheck <: Check; input::Input.T; run::Function; network::Bool; end  # run(x, cfg)::Vector{Location}
# it returns file and line, adding node and quote where its parse already holds them; re-run from scratch, it never
# needs re-anchoring. `network = true` keeps it out of every build and test: only `gbg check --network` runs it (§11)
struct AgentCheck   <: Check; question::String; why::WhyAgent.T; end
"Something a rule's check must judge a known way; `expect` lists the locations it must report, empty if it complies.
An example's locations carry file and line only: a fixture is built fresh each run, so nothing can drift under it."
abstract type Example end
struct TextExample     <: Example; fileset::FileSet.T; text::String; expect::Vector{Location}; clause::String; end
struct TreeExample     <: Example; files::Vector{Pair{String,String}}; expect::Vector{Location}; clause::String; end
struct ModuleExample   <: Example; source::String; expect::Vector{Location}; clause::String; end
struct SiteExample     <: Example; pages::Vector{Pair{String,String}}; expect::Vector{Location}; clause::String; end
struct QuestionExample <: Example; question::Question; expect::Vector{Location}; clause::String; end
"A value a rule reads that a package may set, such as how a docstring's first sentence leads."
struct Parameter{T}; name::Symbol; default::T; end
"One rule of the rulebook."
Base.@kwdef struct Rule
    id::Symbol; statement::String; why::String   # statement: the rule in plain English, its only home
    intention::Intention.T; filesets::Vector{FileSet.T}   # documentation rules run in the docs build, code rules in
    check::Union{ProgramCheck,AgentCheck,Nothing}         # Pkg.test(); one whose input is QUESTION in neither (§8)
    unchecked_reason::String = ""; parameters::Vector{Parameter} = Parameter[]  # reason: required with no check
    examples::Vector{Example} = Example[]      # a program check needs them; a rule an agent checks needs none
    access::Vector{Access.T} = Access.T[]      # what a reader must be given beyond the unit; empty: no reader's
    discipline::Union{Symbol,Nothing} = nothing  # the catalogued discipline deciding it takes, or any careful reader
end
```

`test/rules.jl` materialises every example — a text; a temporary file tree; a source string loaded into a fresh module;
a site example's pages written as the rendered HTML a reader meets, not a Documenter build (that would test Documenter,
not the rule) — and requires the check's locations to equal `expect` in file and line. For a program
check, every clause of the statement needs a breaking example and a complying text that differs from a breaking one as
little as possible [a yes/no example passes a check that always fires]; a rule an agent checks needs none.

```julia
"One reader an instrument launches, DERIVED from the rules (§5.3): what it reads, what it is kept from, which rules."
Base.@kwdef struct AgentRole
    id::Symbol; instrument::Symbol; reads::Vector{FileSet.T}; site::Bool = false; kept_from_code::Bool = false
    description::String                  # who the reader is, in two or three sentences
    rules::Vector{Symbol}; strength::Strength.T = Strength.ECONOMY  # rule ids; empty makes an open reader
    cap::Int   # distinct defects reported, the agent saying how many it left out [readers were cut off at the limit]
end
"A field of expertise a package may declare, catalogued once here and shared; a declared one is an open expert reader."
Base.@kwdef struct Discipline; id::Symbol; description::String; end
"The one ceiling on a run: its fix passes. Launches are bounded by the design, not capped [ruled 2026-09-21]."
Base.@kwdef struct Budget; fix_passes::Int = 4; end
"An instrument the owner starts, with its three values from §2 and the two prose columns of that table."
Base.@kwdef struct Instrument
    id::Symbol; purpose::String; intention::Intention.T; decider::Decider.T; fixer::Fixer.T
    when::String; ends::String                  # the last two columns of §3, in the same words
    budget::Budget                              # its readers are derived at run time, not a field
end
"A program check that every build and test runs; its decider is a program by definition."
Base.@kwdef struct AlwaysOn
    id::Symbol; purpose::String; intention::Intention.T; fixer::Fixer.T
    decider::Decider.T = Decider.PROGRAM; when::String
end
"Generated files or parts of files: which paths for a package, which part, and which generator writes it."
struct Generated; paths::Function; part::Part.T; generator::Symbol; end   # paths(cfg)::Vector{String}
```

**Readers are derived, not listed** [ruled 2026-09-20]. A rule no program decides carries `access` — what a reader must
be given beyond the unit it is about: NOTHING (exclusive: the unit alone, since more would change the answer), SIBLINGS,
OTHER DOCUMENTS, SOURCE, RENDERED, HISTORY, CITED WORK, or a combination — put on from the rule's own text by three blind
readers (§12), and, where its own words are a field's, `discipline`. `Roles.derive` computes the panel: three **bound
readers**, one per bundle of material a rule lands in, tried in order — *withheld* (one built page or Literate file
alone), *full* (siblings + source + other documents), *rendered* (the built site) — a rule going to the first bundle that
covers its need; one reader per discipline the package declares in `Config.disciplines`, an **open expert** reading the
whole documentation for what is wrong in its field, bound only to a rule naming that discipline; and two **open
standpoints** with no rule, *plain_sense* on one page and *logician* on the whole [the two highest yields in the one
review that recorded them]. A rule no reader can be given, and a rule naming an undeclared discipline, is a **gap**,
printed at every launch and first in the report; there is no fallback, because a pass from a reader that cannot
recognise the defect is indistinguishable from not looking. The three bundles, the two standpoints and the discipline
catalogue are the hand-written mechanisms (§13); a package writes none — one it needs and the catalogue lacks is
requested from the tooling session. Every reader runs on the careful model; `gbg run … --readers bound|open|both`
chooses which are launched, `bound` by default. An open reader's findings name no rule, so the reason for trusting it is
its standpoint, and a finding that recurs becomes a rule (§7).

**Targets and material** [ruled 2026-09-23]. What a reader is GIVEN is decided by audience, not by file type. A
**target** is what a user reads — a docstring, a hand-written page under `docs/src/`, a Literate example, and the one
document `architecture_doc` names — and is the only place a finding may be located and the only thing the fixer is ever
handed. **Material** is what a reader may open to judge a target and never report on: the source, plus whatever the
package lists in `Config.material`, empty by default. Every other rationale document is read by nobody unless listed:
not launched over, not handed to the full reader or a discipline, not walked on the site — the site walk keeps only a
page whose source is a target, so a build-time copy of the working notes drops out by construction. A finding located
only in material is kept, marked `in_material` at collect, reported in its own section and routed to the owner,
unfixed and unverified [it may be the formula three docstrings copy]; `gbg docfix commit --finding` refuses an edit to
such a document. Program checks are untouched and run over the file sets they declare. `Catalogue.target` is the one
predicate, and a change to a non-target rationale document reaches no reader under a changed scope. [On
GBGPeriodicFields the full reader and each discipline had been handed four working-notes documents, ~164,000 tokens,
under two rules that had that day been ruled not to apply to them.]

```julia
"Turns one rule, agent role or instrument off in one package, or in some of its files, with the reason."
Base.@kwdef struct Switch; target::Symbol; reason::String; files::Vector{String} = String[]; end
"A package's value for one rule parameter; a list-valued parameter is set the same way."
Base.@kwdef struct Setting; rule::Symbol; name::Symbol; value::Union{String,Symbol,Bool,Int,Vector{String},Vector{RetiredClaim}}; end
"A rule a package adds for itself: a pattern its files must not (or must) contain, with examples."
Base.@kwdef struct PatternRule
    id::Symbol; statement::String; fileset::FileSet.T; pattern::Regex; forbidden::Bool; examples::Vector{TextExample}
end
"A package's settings, written by hand in `.gbg/config.jl`."
Base.@kwdef struct Config
    package::String; tool::Union{VersionNumber,Symbol}   # a released version, or :dev in GBGCodingTools' own checkout
    docs_build::Vector{String}; test::Vector{String}; rules::Vector{PatternRule} = PatternRule[]
    filesets::Dict{FileSet.T,Vector{String}} = Dict{FileSet.T,Vector{String}}(); normative::Vector{String} = String[]
    copies::Vector{Pair{String,String}} = Pair{String,String}[]  # build-time copy => tracked source
    generated::Vector{String} = String[]      # pages written at build time; no rule reads one
    switches::Vector{Switch} = Switch[]; settings::Vector{Setting} = Setting[]
    material::Vector{String} = String[]       # documents a reader may consult and never report on (§10)
    disciplines::Vector{Symbol} = Symbol[]    # the catalogued disciplines its readers need; never a reader of its own
    code_areas::Vector{Pair{Symbol,Vector{String}}} = Pair{Symbol,Vector{String}}[]  # one hunter per area (§10)
end
"A question the owner settled, kept in `.gbg/settled.jl` and given to agents as 'do not report'."
Base.@kwdef struct Settled                        # locations: what the ruling is about, quotes included
    question::String; text::String; date::String; locations::Vector{Location}   # date as "YYYY-MM-DD"
end
```

`.gbg/config.jl` and `.gbg/settled.jl` are never evaluated (§5.1): `ConfigIO` parses them and accepts only literals
(strings, numbers, symbols, enum names, `v"…"`, `r"…"`, vectors, pairs, dictionaries) and keyword calls to the
constructors above; a function call, interpolation, unknown keyword or unknown id is exit 2 [a module holding only the
config type still ran `getpid()` through it]. A test round-trips every field type; a package rule needing a function
lives in the package's own tests as a `Rule` passed to `Harness.test`; new rulings are appended as text.

```julia
"One documentation-fixer attempt at one finding, with the program and agent judgements of it."
Base.@kwdef struct DocFix
    finding::String; pass::Int; commit::String; formula_edit::Bool
    blind::Verdict.T; with_diff::Union{Verdict.T,Nothing} = nothing  # the blind verdict (§4.3 step 5), then the
                                                                     # diff stage's, for a FIXED finding only
    agreeing_code::Union{Location,Nothing} = nothing  # anchored like any other: its quote is the code line itself
end
"One approved code fix and the single audit of it; kept with its question (§4.4)."
Base.@kwdef struct CodeFix
    question::String; direction::String = ""   # the answer that approved it, and any direction it carried
    attempts::Int; commits::Vector{String}; touched_tests::Bool; audit::String   # audit: the one run over it
    proportionate::Bool; contract_kept::Bool; old_input_works::Bool   # the grade the audit returned
    concerns::Vector{String}; note::String     # its concerns, and its sentence to the owner
end
"One run, stored beside report.md as .gbg/runs/<id>/run.json through JSON3 (enums and `nothing` round-trip)."
Base.@kwdef struct Run
    id::String; instrument::Symbol; tool_version::String; first_commit::String; budget::Budget; stage::Symbol
    findings::Vector{Finding}; fixes::Vector{DocFix}; questions::Vector{Question}
    code_fixes::Vector{CodeFix} = CodeFix[]   # the fixes its questions were answered with, added as they land
    agent_launches::Int; tokens::Union{Int,Nothing}; stop::Stop.T   # launches as they arrive: a record, not a cap
    readers::Symbol = :bound                  # which readers this run launches: bound, open or both
end
```

**Rule docstrings.** Each `Rule`, `AgentRole` and `Instrument` constant gets its docstring from `doc(x)`, attached by a
`@doc doc(x) x` call in the source. The rule that source docstrings match the loaded module's compares only literal
docstrings, and requires every other docstring in the module to come from such a call, found in the source. Each
example is fenced with one more backtick than the longest run inside it, so its own fences and doctests stay inert.
`doc(x)` also returns which field each docstring line came from, located with Julia's own parser, so a finding in such
a docstring anchors to that field — node `ARGS_FORM.statement`, say — not to a line of a text no file holds. The
generated pages showing the rules stay outside the file set the site readers get, and the generated policy files carry
statements without examples, because a rules page is by construction full of text that breaks the rules, which a reader
would spend its budget reporting and no fixer could touch.

### 5.3 What becomes Julia

The rule prose, the rule register and the scan catalogue become `Rule` values beside their checks, the fixture's
defects their `Example`s; the tags on the rules and the discipline catalogue become the readers, derived at run time,
the hats' briefs surviving only as the two open standpoints and the disciplines' descriptions; instrument protocols and Workflow scripts become `Instrument` values, `Runs` stages and one fixed
driver; JSON schemas become Julia constructors, with agents' output schemas generated from the types; `config.toml` and
the exemptions ledger both become `config.jl`, an exemption being a `Switch` there, while `settled.jl` is new and holds
only the owner's rulings; templates and `managed.json` become `Render` generators and the `GENERATED` registry.

## 6. Generation

Every non-Julia file that a program or an agent reads **as data** is written by a Julia function [R6]. Prose written by
a person for people — `README.md`, the pages, this document, `CHANGELOG.md` — is written by hand, and an agent reads it
as the text under review; a table in such prose restating Julia values is compared with them by a test, as §3's table
is, with the three rows marked future read as future.

| File, or part of a file | Read by | Written by |
|---|---|---|
| `.gbg/policy/*.md` (statements, no examples); the tooling package's block in `CLAUDE.md` | sessions | `Render.policy` |
| one `.claude/skills/<instrument>/SKILL.md` per instrument that applies | Claude Code | `Render.skill` |
| agents' arguments and output schemas, under `.gbg/scratch/<run>/` | the Workflow tool, agents | `Agents`; the driver itself is this package's tracked `drivers/run.js` |
| the pin in `docs/Project.toml` and `test/Project.toml` | Pkg | `Render.pin` |
| the tooling package's block in `.gitignore`, the CI workflow files, the end-of-turn hook | git, GitHub, Claude Code | `Render.gitignore`, `Render.ci`, `Render.hook` |
| one small page on each consumer's site, under its design or internals section: what the documentation is held to, a link to this package's site, and the switches with their reasons — nothing else of the tool [ruled 2026-09-23; the rulebook, readers and instruments pages it replaced are §3 of the decision log] | readers of a consumer's site | `Render.pages`, called by `docs/make.jl` |
| the rulebook as a page, grouped by cover, an anchor per rule, with the glossary — on this package's own site alone | readers of this site | `Render.rulebook_page`, called by this package's `docs/make.jl` only |

`Catalogue.GENERATED` lists every generated path or part — a whole file, a marked block, or the entries of a TOML
table — with its generator; a package's declared copies count as generated. Run records, reports and the question store
are not in it: they record what happened, written by `Runs` and `Render.report`, and nothing regenerates or compares
them. The wiring check regenerates each part and compares only that part, TOML entries as parsed values since Pkg
rewrites the files [a header line cannot mark a JSON or skill file, and comparing all of `CLAUDE.md` always fails].
Because a generated part equal to its generator's output is not a code change, `gbg docfix commit` may regenerate and
commit the parts a reworded rule statement feeds (§4.3), so a prose fix never leaves that check red.

The Workflow driver is one fixed script: it launches the agents its arguments list and reports which wrote their files.
Julia cannot launch agents, and only the session can call the Workflow tool, so each stage is a handoff: `gbg run next`
writes the stage's arguments and exits, the session runs the Workflow, `gbg run collect` reads the results, and `Runs`
refuses any stage out of order. A Julia test checks the driver reads every key `Agents` writes. An agent's output
schema asks, for each place, the file, the quote and the node it read; the program fills in the line itself (§4.1).

## 7. Deterministic first

**When an agent may check a rule** [R7]. Only when deciding it needs the meaning of a sentence (is this claim true of
the code), a derivation (is this formula right), or a document read in order (is this term defined before its first
use) — the three `WhyAgent` values. Whatever a pattern, a parser, reflection on the loaded package or the Documenter
build can decide is a `ProgramCheck` from the start; that includes a docstring's stated defaults and argument names
against the signature, and docstrings in the source attached to nothing [five such went unfound]. A partly decidable
rule splits into a program rule and an agent rule. **Every rule has one of three covers**, read off the rule
(`Catalogue.cover`): a program; a reader, given the material the rule's `access` tag names; or an **instruction** the
session follows while working — how to commit, what to run unasked, how to read what a scan prints — checked by nothing
and saying so in `unchecked_reason`. A statement about how this tool itself behaves is this document's, not a rule
[ruled 2026-09-21]. The rules page groups the rules by cover.

**A check is shown to match its rule** by `test/rules.jl` (§5.2). Bug hunt can also be pointed at the rules, where a
failing test is a text the rule forbids but its check lets pass, or the reverse; only the owner decides what a rule
means, so each becomes a question, and on "yes" the text becomes an example and the code fixer changes the check.

**A recurring agent finding becomes a program check.** Each verified documentation fix leaves its commit — the text
before, which broke the rule, and after, which complies — in the run record, and the report lists the fixes per
agent-checked rule. When a rule recurs, the session proposes a program check as a code change; those pairs are its
first examples, and `test/rules.jl` must pass on them.

## 8. Asking the owner

`Question` is the one form for asking a person anything [R9]: the documentation fixer's (a possible code defect; any
edit that would change mathematics), Bug hunt's, Change audit's concerns, the code fixer's approvals
and the attempts that hit its cap, the keep-or-revert a run's close puts when code changed outside the guarded commit
(§10), rule counterexamples, and proposed program checks. The wiring check regenerates, or exits 2 when it cannot read
the config, and the session then asks through a `Question` kept outside a run.

**How the language rules are applied.** `Questions.check(q, cfg)` runs whenever a question is put, inside a run or out
of one, never when a record is read [an older record would fail to load under a newer rule]. It selects, at that
moment, every program rule in `RULES` whose input is a question, so no rule text is copied and a changed rule applies
to the next question. These check, for example: a decision of one sentence ending in a question mark; a length limit;
no rule id, finding id, file path or code name in the decision or context (those go in `items` and `exhibit`); no word
on the rule's list of the tooling package's own terms (a `Parameter`). The agent-checked language rules — plain,
self-contained, no invented jargon — are judged by one agent before questions are shown. A failing question is
rewritten once, then shown with the failed rule named; `report.md` ends with the rendered questions, and
`test/questions.jl` checks every question form built.

**Answers.** `gbg answer <question> [item] <option> [direction]` records the answer, and any direction with it, on the
question or the named item: in the run record for a run's questions, otherwise in `.gbg/questions.json`. Each
question's `CodeFix` (§4.4) is written beside it in the same place. An answered question never returns: grading and
later runs skip any finding whose question has an answer, unless the answer was "fix the documentation instead" — that
finding waits for the next run of its instrument, where the documentation fixer takes it. An owner's "not a defect, do
not ask again" appends a `Settled` value to `.gbg/settled.jl`, tied to the question id and holding the anchored
locations it covers. `ConfigIO` parses that file and `Agents` is its only reader, telling agents "do not report" while
each of those locations still re-anchors (§4.5); no build, test or check reads it [settled choices were raised again in
4 of 87 findings].

## 9. Applicability

A package turns a rule, an agent role or a whole instrument off with a `Switch` naming it and giving the reason, and
sets a variant with a `Setting` [R10]. Every element that is off is listed in the config and shown, with its reason, on
the package's documentation site; an unknown target or a missing reason is exit 2.

**Every rule is switchable. There is no set a package may not escape** [as ruled 2026-09-17]. The rulebook is the
DEFAULT, and a package overrides any part of it by saying so where a reader can see it. An earlier draft marked some
rules — the ones catching text that renders wrongly, and the docstring-structure rules — as always on, and that mark was
never set, because the two things it would have bought are already bought by the switch itself. A switch cannot be
silent: it names the rule, gives the reason, and is rendered into the package's own rulebook and onto the one small
tooling page of its site, so the escape is on the record either way. What the mark added was only the refusal — and its cost is a package with a red
build and no way out but a MAJOR release of this one, which makes this package the obstacle rather than the help.

Off in GBGCodingTools, with reasons — the second and third are its declared deviations today, the first and fourth new:
- the LaTeX notation and spacing rules and the citation rules — its documentation contains no mathematics and cites no
  literature;
- the allocation and memory-traffic contracts — no operation here writes into array storage whose traffic matters;
- running Literate examples — it ships none;
- the documentation review itself, until Phase 8 turns self-application on; what Bug hunt and Change audit derive as
  readers (Phase 6) is switched off here when they exist.

Settings here: a docstring's first sentence says what the operation does (science packages: the physical meaning of
what it computes); the "written by AI" banner is on every page.

## 10. How a run starts, works and stops

**Start.** A run starts only on the owner's request, in words or by slash command (as ruled), with one exception: the
single Change audit of an approved code fix (§4.4), which the owner's "fix the code" authorises with the fix and which
starts nothing further. Nothing else — no gate, no check, no other fix, no other run — starts a run [in the past, 8 of
15 rounds here were opened by the session or by a gate]. Once started, a run fixes and verifies to its end without
asking again. A run **interrupted** before its end — an outage, the plan's tokens gone, a session that ended — is
continued by the next session on its own, which says so in the chat and waits only if the tree moved since; nothing of
an unfinished stage is taken. `gbg run abandon` ends one the owner does not want continued, as `OWNER_STOPPED`, its
findings dropped [ruled 2026-09-21]. `gbg run <instrument> --readers bound|open|both` says which readers (§5.2), bound
by default; `--scope full|changed` (Phase 4d) whether the whole corpus is read or what changed since the last finished
run of that combination, a tool bump or a config or switch change since making the next run full [ruled 2026-09-21].
`gbg run start` exits 2 when the working tree is not clean, another run is open, or the instrument has no readers, and
records the version of GBGCodingTools, the first commit, the readers and the pass budget.

**Carried findings, and the two places they live.** Open findings carry over, as ruled. The run record keeps them with
their ids and anchored locations: the machine's copy, which the next run of that instrument starts from, before its own
search. That next run re-anchors each one first (§4.5); what comes back `OUTDATED` — the text it was about is gone or
rewritten past recognition — is closed as no longer locatable and said so in the report, not carried for ever. At
close, every instrument but the leak scan also writes one line per leftover into `.claude/WORK_QUEUE.md`, the owner's
list — a review's unfixed findings, a hunt's confirmed defects whose question is unanswered, an audit's concerns — each
naming the file, the node and the quote rather than a line number, stale by the time the owner reads it. Those lines go
under a heading the end-of-turn guard does not count, so the list never makes a session work on something the owner has
not asked about [a session held to that list could only edit by hand or open a run nobody asked for]. The report keeps
no second list of leftovers: it names the run record and says how many lines went to the queue.

**Work.** `Runs` orders the stages; the session launches each one (§6). Documentation review: start → find → collect →
up to 4 passes (§4.3) → close. Bug hunt: start → hunt, one hunter per code area of the config and the open readers →
collect → agents write failing tests → `gbg run witnesses` runs them → collect → close. Change audit: start → audit →
collect → close, the package's named tests run as evidence. `gbg run close` writes `run.json` and `report.md` — for a
leak scan, neither (§3). The session commits and pushes what was written, shows the report and questions, and ends.

**End**, decided by a program and recorded in `Run.stop`, whatever the §3 table's ordinary ending says: `DONE`
(nothing open, or the fourth pass made and what is open carried over [ruled 2026-09-21: the pass cap is about
convergence, not a budget]); `CANNOT_EVALUATE` (a step exited 2 or 3; the instrument is not repaired inside the run, which rounds that patched their
own scripts showed the need of); `OWNER_STOPPED`. Close also runs two programs:
- it classifies every commit since the run's first commit; if any changed code outside `gbg docfix commit`, the run
  ends `CANNOT_EVALUATE` and the owner is asked to keep or revert it, with an exhibit the program writes;
- it runs `gbg docfix check`; if the build is red, it restores the documentation to the last commit that passed and
  commits that through `gbg docfix commit` [a red docs build would otherwise stay on the branch].

**A run never** searches twice, makes a fifth pass, commits code outside `test/regressions/escalated/` (§4.4 step 3),
starts another run, or changes an instrument (instruments are code); discarded bug-hunt candidates are listed with
their passing tests [one was a real blocker].

**Across runs.** No build, test or wiring check reads a run record, the question store or the settled rulings [review
state turned science tests red]. The work-queue file and the end-of-turn guard that holds a session to it stay as
ruled; a run's close is the only verb writing to that file, one line per leftover, under the uncounted heading.

**Release** of GBGCodingTools needs a clean tree on `master`, pushed; a green `Pkg.test()`, a green docs build and a
green wiring check; and the `CHANGELOG.md` entry; the tag is never moved. `gbg release --counts` prints, for
`v2.0.0` alone, what still holds that release (IMPLEMENTATION §6). `gbg release` prints, and the tag message and
that entry carry, two lines it does not act on: the commits whose keep-or-revert question is still open, and how many
confirmed failing tests wait unanswered in `test/regressions/escalated/`. Nothing else holds a release: no review run,
no open finding, no unanswered question, no audit.

**Who stops.** Inside a run, the program, from the pass cap; there is no ceiling on launches — the panel over the
units, one relaunch each, two verifiers per open finding per pass and four passes bound a run by design [ruled
2026-09-21]. Across runs, the owner, by asking or not. A
program-decided loop needs no budget: it ends itself by passing (§4); the code fixer's three attempts are a judgement
about the fixer, not a budget (§4.4 step 2).

| Mechanism | The failure it prevents | Its cost |
|---|---|---|
| One search per run; the finding list fixed at collect | Repeated searches never settled | A defect the search missed waits for the next run |
| At most 4 fix passes | Rounds of 9 and 15 passes | Findings open after 4 passes carry over |
| Carried findings, in the record and the work queue | A leftover forgotten between reviews | The next review starts with the last one's leftovers |
| Locations anchored to a node and a quote, re-anchored before each use | A fix or a verifier sent to a line that has since moved | A finding whose text is gone closes as no longer locatable |
| Guarded commit; classification and build check at close | Code changed, or a red build pushed, through a documentation fix | A documentation fix needing code waits for the owner |
| Code findings end as questions | Audit verdicts drove code changes without review | Owner attention per code change |
| Attempts loop on the failing test, at most 3 | A fix nobody can find turning into a speculative rewrite | After three failures the owner reads the attempts and decides |
| One audit after each approved fix, never after itself | Fix → audit → fix, the chain the owner was lost in | One audit's agent time per approved fix |
| Nothing outside the run machinery reads run records | Review state turned science tests red, and held releases | What is owed is read from the work queue, not enforced |
| A crashed step ends the run | Abandoned rounds; scripts replaced mid-round | That run's agent launches are lost |
| An interrupted run continues in the next session | A review lost to an outage or the plan's tokens | The next session's first act, said in the chat |

## 11. How GBGCodingTools plugs into a package

**The pinned version.** `Config.tool` names one released version (as ruled) — `:dev` only in the tooling package's own
checkout — which `gbg sync` writes into the docs and test environments, and into neither package's own dependencies.
`gbg bump` runs only on the owner's request; it first runs the new version's checks on the package and exits 1,
changing nothing, with counts per new rule when any fails; else it changes the pin and regenerates every generated part
[a new check would otherwise redden a build on old text].

**Inside a science package's `Pkg.test()`** the code rules run and the wiring check compares, and **inside its docs
build** the documentation rules run and the wiring check compares again; regenerating anything is left to `gbg sync`,
`gbg bump` and `gbg release`, so a build only reports what has drifted. GBGCodingTools' own test suite runs more, being
the tooling package's: `test/rules.jl` (which materialises every example), `test/guard.jl`, `test/anchors.jl`,
`test/questions.jl` and `test/architecture.jl`.

```julia
GBGCodingTools.Harness.test(MyPackage; rules = MY_RULES)      # test/runtests.jl: contracts, accepted failing tests
GBGCodingTools.makedocs(GBGCodingTools.ConfigIO.read_config(path); sitename = "MyPackage", pages = [...])
```

The package's own preparation (Literate output, copied rationale pages) runs in `docs/make.jl` before `makedocs`; its
outputs are declared copies or generated paths. `makedocs` runs the documentation rules over the source, then
`Documenter.makedocs`, then the rules over the built site, and throws on any finding. Both entry points are
deterministic and offline, agree on a fresh clone and on CI, and never read run records, questions, settled rulings or
git state. A used file set matching no file is exit 2, and literal docstrings in the source must match the loaded
module's [a check with no input reports clean].

**The same files in every package**, including GBGCodingTools, created by `gbg init`:

```
.gbg/config.jl               written by hand
.gbg/settled.jl              the owner's settled rulings, appended on "do not ask again"
.gbg/questions.json          questions put outside a run, with their answers
.gbg/policy/*.md             generated
.gbg/runs/<id>/              run.json and report.md; while a run is open, its stage file and draft record
.gbg/scratch/<id>/           the agents' arguments and results, git-ignored, deleted at close
.gbg/requests/               requests to another package (RULE.GIT.REQUESTS); a reader or discipline asked of the tooling session is one
.claude/skills/*/SKILL.md    generated, one per instrument that applies
.claude/WORK_QUEUE.md        the owner's items, guarded; under an unguarded heading, each run's leftovers
.claude/settings.json        the end-of-turn hook, generated
CLAUDE.md                    the tooling package's block generated; the rest belongs to the package
docs/, test/Project.toml     the pin, generated into both environments
.gitignore, CI workflows     the tooling package's block and its workflow files, generated
test/regressions/            accepted failing tests; escalated/ holds those awaiting an answer
```
Agent output lives under `.gbg/scratch/`, which git ignores; the driver is this package's own tracked file (§5.1).

**`gbg init` never overwrites what the package wrote itself.** Four of those paths are commonly a package's own before
the tooling arrives — a CI workflow, `.claude/settings.json`, the work queue, and a skill whose name is already taken by
one of the package's commands. Where a file exists and did not come from a generator, `init` writes everything else,
prints the difference for each collision and exits 1; the owner moves or keeps his own file and runs it again [a
generated file silently replacing a hand-written workflow is the one wiring mistake that is noticed late]. Unwiring a
package is reverting the commits that wired it, after which `gbg` finds no config there and refuses.

## 12. What is shown to work, and what is not

**Program checks** are shown to work by their examples (§5.2): every check is run on every example of its rule, and its
locations must equal what the example expects, in both directions and for every clause. **Re-anchoring** is shown the
same way, by `test/anchors.jl`, which uses `Runs.reanchor` and so is one of the tooling package's own tests (§5.1): a
`.jl` and a Markdown fixture found again after lines are inserted above them, after a binding is renamed, after the
quote is reworded, and after both are gone (`OUTDATED`, never a guess).

**The instruments whose findings come from agents are not measured**: nothing plants known defects to count how many
are found. This is a deliberate limit, not a plan: a change to an agent role's wording, rule list or strength cannot be
shown to help or hurt, and whether they are worth their cost stays the owner's judgement, from what their reports
contain. Every number in brackets is past evidence — from the science packages' review rounds and this package's own —
kept as the reason a mechanism exists; nothing re-measures them from now on, so a role once justified by such a number
stays justified only by it. Each run records what is factual and cheap: findings reported, fixes verified, items
carried over, agent launches used and, where the platform reports it, tokens.

**One thing about the rulebook is measured**: whether a rule's text says one thing. Three blind readers, given only the
rules' text, tag what deciding each needs; their agreement (Fleiss' kappa) and the rules they flag as underspecified
are reported, and the majority becomes the tag. Round 0 → 1 on 2026-09-19: material 0.74 → 0.90, flags 18 → 8, splits 9
The rule wording study (Phase 4e) is that procedure as a verb; it proposes, and a tag changes only on an answer.

## 13. Change control and growth

A rule, agent role, discipline or instrument is code in GBGCodingTools, apart from the prose fields of §4.2: it changes
through the code fixer on the owner's answer to a finding, or by the session on the owner's direct answer, is released as a tag that is never moved, and reaches a package through `gbg bump`
[R2]; it never changes during a run. A **design review** is FUTURE WORK, not an instrument, and has no row in §3: `gbg
attack` would run agents over this design and produce proposals, never findings, each becoming a question to the owner or
dismissed with its reason. It would write no tracked file — no run record, no report, no work-queue line — so it has no
row in §6 either: its proposals reach the owner as questions in the session that ran it, the way a leak scan's findings do
[as ruled]. Deferred on 2026-09-21 so that this package reaches its consumers sooner; nothing depends on it, and nothing
it would check is unchecked meanwhile, because the rulebook's TEXT is the subject of the rule wording study (§12) and not
of an attack. Two things are asked of it whenever it is built. It attacks a MECHANISM — a reader panel, a guard, a lens
set — and never prose, and it demands of every attacker a concrete EVADING EXAMPLE: the defect that passes, where it
sits, and why each part of the mechanism misses it. An attack that only collects objections converges by narrowing what
the thing under attack claims, which is a measured failure of this project and not a hypothetical one [the six discipline
texts, seven rounds to no objection, filed in `docs/design-record/08-discipline-attack.md`].

**Retiring a rule.** A rule leaves the rulebook by having its value removed, which is a code change like any other: the
owner's answer names the id and why the rule is no longer worth keeping, `Catalogue.RETIRED` and the `CHANGELOG` entry
record the removal, the id is never reused [an id reused for a different rule makes every older record lie], and a
switch naming it stays legal. This is the
counterpart of `unchecked_reason`, which says why a rule no program can check is kept: retirement is how one that should
not be kept is dropped on the record rather than quietly [as ruled].

**Growth limit.** A code change adding a mechanism — a rule, a bundle or standpoint of readers, a discipline, an
instrument, run stage, verb or refusal —
names, in its question, the requirement or failure it answers and what it replaces; without one it is not added.
