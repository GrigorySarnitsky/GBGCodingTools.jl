# Upgrading GBGPeriodicFields to rc.10, and its first review — instructions for the PF session

Written 2026-09-21 by the GBGCodingTools session, at `v2.0.0-rc.7`. Every figure was measured on a fresh
clone of PF at `03534c53`, and the draft was then put to three adversarial passes — one following it
literally, one checking every claim against the source, one hunting omissions. They found the review
section unexecutable as first written, an upgrade step that silently leaves PF running the old version,
and eight wrong figures. What survives is below.

Read this whole file before running anything.

**This is no longer a wiring document.** PF was wired on 2026-09-18 and pins `v2.0.0-rc.5`. Its
`.gbg/config.jl` exists, its `docs/make.jl` and `test/runtests.jl` call this package, and `gbg check`
reports nothing. What follows is the upgrade to rc.7, what rc.7 asks PF to declare that rc.5 could not
express, and what to know before the first documentation review.

**Every command runs from PF's checkout root**, `/home/grigory/Dropbox/Research and Teach/Isotropic
Turbulence/GBGPeriodicFields`. `gbg bump` re-pins whatever package encloses the working directory, with
no confirmation: run it one directory wrong and it silently re-pins that package instead. An agent
attacking this file did exactly that during the measurements.

**`gbg`, not `gbg --dev`.** PF's pin is a tag, so the installed shim runs in PF.

**Steps 1 to 3 are this session's, and are one change. Step 4 is not this session's at all.** A run
starts when the owner asks for it and on nothing else. This file was written by another session, and a
peer session is not authority.

## What changed between rc.5 and rc.7

**The rule set is 92, down from 98.** Thirteen rules were retired on the owner's word of 2026-09-21,
each with its reason in `Catalogue.RETIRED` and its id never reused: eight named machinery that no
longer exists (`RULE.INST.FOUR_OBJECTS`, `CLOSURE_LOOP`, `AUDIT_DISPOSED`, `FIX_FROM_LANES`, `SEEDS`,
`FROZEN_MIDROUND`, `CARRY`, `ECONOMY`) and five stated how the tool itself behaves, which the design
holds (`RULE.INST.WITNESS`, `SELF_REPORT`, `AUDIT_AFTER_CODE`; `RULE.TEST.RULE_WITH_CHECK`,
`COUNTS_REMEASURED`). A switch naming a retired id stays legal and is ignored; PF declares none of them.

**Seven rules are new.** Five are the `RULE.ASK.*` family — `ONE_DECISION`, `SHORT`, `PLAIN`,
`NO_HOUSE_TERMS`, `NO_COORDINATES` — which govern how a question is put to the owner and which the new
`asking.md` renders. The sixth is `RULE.CIT.RESOLVES`: every DOI or Open Library link on a title must
answer, and answer with the work the title names. It reaches the network, so it runs only under `gbg
check --network`, never in a build or a test; run it, and fix and commit what it reports, before a
review opens, since a fix made afterwards is a commit landing under the agents. The seventh is
`RULE.DOC.LITERATE_RENDERED`, judged on what the build made of a Literate example's comments — read it
before narrowing the Literate set in Step 3.

**Every rule now carries one of three covers** — checked by a program, judged by a reader, or an
instruction to the session — and the rules page is grouped by them. Nothing for PF to do.

**The documentation review exists.** rc.5 had no instrument at all. Step 4 is about it.

## Step 1 — bump the pin, then move the manifests

    gbg bump 2.0.0-rc.10

On a fresh clone of PF it rewrote **20 paths** and exited 0. `bump` refuses to move the pin while the
rules of the version it is RUNNING find anything in PF — which, through the shim, is the version the
manifest still holds, not the one you are moving to. PF is clean under both, verified over all 92 rc.7
rules, so it goes through.

What the bump brings that rc.5 did not write:

| Path | What it is |
|---|---|
| `.gbg/policy/asking.md` | **new**: the five `RULE.ASK.*` rules. The rulebook is nine files, not eight. |
| `.claude/skills/documentation-review/SKILL.md` | **new**: the instrument's protocol in six steps. Generated; do not hand-edit it. |
| `.claude/skills/bug-hunt/`, `.claude/skills/change-audit/` | **new**, and both describe instruments that do not exist. See Step 5. |
| `.gbg/policy/*.md` (the nine PF already had), the `CLAUDE.md` block, `.gitignore`, `.claude/hooks/queue-guard.sh`, `test/regressions/README.md`, `.github/actions/gbg-auth/action.yml` | rewritten at the new version |
| `docs/Project.toml`, `test/Project.toml` | `rev = "v2.0.0-rc.10"`; `compat` stays `=2.0.0` |

Commit the config and the rewritten paths together: the pin and what it generates are one change. Stage
with `git add -u` plus the four new files by name — `.gbg/policy/asking.md` and the three
`.claude/skills/*/SKILL.md`.

**Then move both sub-environments onto the new tag. This is the step that is easy to miss and breaks
everything after it.**

    julia --project=docs -e 'using Pkg; Pkg.update("GBGCodingTools")'
    julia --project=test -e 'using Pkg; Pkg.update("GBGCodingTools")'
    gbg sync

**`Pkg.update`, not `Pkg.resolve`, and then `gbg sync` again.** Three separate traps, and PF met all
three on 2026-09-22 going from rc.5 to rc.7.

`bump` rewrites the `rev` in both `Project.toml`s and writes no manifest, and `Pkg.instantiate()` does
not move a changed rev. That much a resolve fixes. But a resolve writes the new rev while KEEPING the
old tree hash where Pkg's clone has never fetched the tag — so the manifest reads `v2.0.0-rc.7` and the
code that loads is still rc.5. Only `Pkg.update` fetches. This has now happened twice, at rc.4 and at
rc.7.

And `bump` regenerates with the code that is RUNNING, which at that moment is still the old version. So
the files it wrote are the old version's content under the new version's banner: PF got sixteen paths
where twenty were due, without the new rulebook file or the three skills. `gbg sync` again, after the
environments have moved, is what repairs it. `gbg bump` says all of this when it finishes, since
rc.8.

Check it took before anything else:

    gbg run next

must answer that nothing is open here, not `unknown verb run`. That one line is what exposed both
version traps; it is load-bearing, not a formality.

## Step 2 — the two pages the build now writes

`Render.pages` returned one path at rc.5 and returns **three** at rc.7: `gbg-rules.md`,
`gbg-readers.md` and `gbg-instruments.md`. The readers page is the one that matters — it prints, on PF's
own site, which agents read PF's documentation, what each is given, and the whole standpoint text of
each.

PF's `docs/make.jl` already calls the generator and lists only the rules page. Its `pages` vector holds

        "Rules" => "gbg-rules.md",

at line 319, indented four spaces; add two siblings directly after it, at the same indentation:

        "Readers" => "gbg-readers.md",
        "Instruments" => "gbg-instruments.md",

Add both to `generated` in `.gbg/config.jl`, and both to `.gitignore` beside `docs/src/gbg-rules.md` —
in PF's own section, **not** inside the `gbg:managed` block, which `gbg sync` rewrites. A generated page
that is not in `generated` is read by every rule, and a page that states the rulebook quotes every
banned spelling in order to ban it.

Leave the generator call where it is, at line 284. It runs before `makedocs` and after what remains of
PF's own lint block, and the ordering was reasoned once; nothing here needs it moved.

## Step 3 — declare what rc.5 could not express

### The disciplines — a proposal for the owner, not a decision for this session

A rule that needs a field of expertise names it, and the package declares which fields its documentation
needs a reader for. With none declared, the derivation reports a gap and nobody judges that rule:

    RULE.DOC.COORD_FREE needs a differential_geometry reader and GBGPeriodicFields declares none, so nobody judges it

That is PF's only such gap today. The catalogue holds six disciplines: differential geometry, Fourier
pseudo-spectral numerics, turbulence theory, cloud microphysics, statistical estimation and software
architecture. The three that look like PF's are

    disciplines = [:differential_geometry, :spectral_numerics, :software_architecture],

Declared, PF's panel goes from five readers and one gap to **eight readers and no gaps**. Only
`differential_geometry` carries a rule; the other two are open readers, which report what is wrong in
their field that no rule names.

**Which of the six is the owner's to settle, not this session's.** It is a question about PF's science,
not about its tooling: a declared discipline is an expert reading the whole corpus from that field, and
a wrong one spends a panel on the wrong questions. Put it to him with the six standpoints in front of
him, which the readers page prints. Those standpoints were rewritten on 2026-09-21 as experts with a
licence to judge whether the method, the model or the decomposition is the right one, each judgement
naming the standard applied and the alternative preferred, so that PF can disagree with a finding rather
than only accept or ignore it. He adopted them after a blind comparison over the real packages.

A discipline PF needs and the catalogue lacks is requested from this package's session and never written
in PF.

### The four file parameters, of which PF sets one

`RULE.DOC.COORD_FREE` bans matrix and flattening machinery outside the one document where it belongs,
and takes that file as a parameter. PF has the document, so name it — as a new entry **inside the
existing `settings = [ … ]` list**, beside the `RULE.TEX.MATHBF` setting:

        Setting(rule = Symbol("RULE.DOC.COORD_FREE"), name = :formalization, value = "docs/FORMALIZATION.md"),

Unset, the rule reads as "and nowhere when none is named", which is the wrong statement for PF.

Three more file parameters have defaults, and a default is not a confirmation: `notation_page`
(`docs/src/notation.md`), `references` (`docs/ARCHITECTURE.md` — it must name the document that actually
carries the reference list), and `sibling_sites`. Check each against PF and set it where the default is
wrong. A parameter naming a file the package does not have is printed as a gap at every launch, and a
rule handed a path to nothing passes silently.

### The build-time copies

PF's `docs/make.jl` copies five rationale documents into `docs/src/` as lowercase siblings. The copy is
what the site renders and what a reader of the built site quotes; the source is where a fix belongs.
Declare the pairs:

    copies = [
        "docs/src/architecture.md" => "docs/ARCHITECTURE.md",
        "docs/src/decisions.md" => "docs/DECISIONS.md",
        "docs/src/formalization.md" => "docs/FORMALIZATION.md",
        "docs/src/testing.md" => "docs/TESTING.md",
        "docs/src/performance.md" => "docs/PERFORMANCE.md",
    ],

The change guard refuses a fix landing in a declared copy, because the next build overwrites it. Without
the declaration a fixer edits the copy, a verifier sees the fix, and the build throws it away. This
matters now and did not at rc.5, because the review's fix half is what is new. Nothing redirects the
fixer from the copy to its source; the refusal is what sends it to ask.

### The Literate set

The default `examples/**/*.jl` is **four** files for PF: `HIST_CPU.jl`, which Literate renders into the
site; `examples/gpu/rocm/HIST_ROCm.jl`, a second GPU example the site does not render; and
`hist_postprocess.jl` and `plot_hist.jl`, which are scripts the example calls.

Narrowing to the rendered example only —

        FileSet.LITERATE => ["examples/HIST_CPU.jl"],

in the same `filesets` dict as the rationale set — drops `HIST_ROCm.jl` from `RULE.DOC.LITERATE` and
from the new `RULE.DOC.LITERATE_RENDERED`. It is in scope today and passes both. Decide deliberately
whether it belongs in the set rather than losing it to a narrowing aimed at the two scripts.

### Then commit

Steps 1 to 3 are one change and are committed together, with the docs build green. `gbg run` refuses a
tree with uncommitted changes to tracked files, so an unfinished upgrade blocks the review — and a run
that opened on a dirty tree could not tell its own edits from yours.

## Step 4 — the review, when the owner asks for it

**The protocol is `.claude/skills/documentation-review/SKILL.md`, which Step 1 wrote.** It is generated
from the instrument's own value, it is six numbered steps, and it is the thing to follow. This section
does not restate it — a protocol quoted in two places is a protocol that will be reworded in one. What
follows is what the skill does not say and PF needs to know.

**Open it with the readers you actually want:**

    gbg run documentation-review --readers both

`--readers` defaults to `bound`, which on PF launches four readers and leaves out `spectral_numerics`
and `software_architecture` — the two open experts Step 3 exists to declare. Pass `both`, or they never
run.

**The verb never launches an agent.** `gbg run documentation-review` opens the run, builds the site and
writes the first stage's arguments, then stops. Launching is this session's: Julia cannot launch an
agent, which is why the verb stopped. Then `gbg run collect`, then `gbg run next` for the next stage,
and launch again. A session that types `next`, `collect`, `close` and never launches anything sits at
the first stage forever and then collects nothing.

**The verb puts the driver where you can launch it**, and prints the path and the call. Since rc.8 it
copies `drivers/run.js` out of the pinned package into the run's own scratch and prints the
`Workflow({scriptPath: …})` line to use. Before that it named the pinned path under
`~/.julia/packages/`, which the `Workflow` tool refuses because it lies outside the working directory —
so every consumer had to discover that and copy the file by hand, as PF did. The run also records the
driver's SHA-256, so its record says which driver its agents actually went through.

**`gbg run next` at a collect position exits 2**, saying every agent wrote and to run `gbg run collect`.
That is the signal to collect, not a failure.

**Eight readers is eight standpoints, not eight agents.** Two of them — the reader given one built page
with everything else withheld, and the plain-sense standpoint beside it — are launched once per built
page. PF's site is twenty-three pages after Step 2, so the reading stage is roughly fifty agents at
`--readers both`. Each verifier stage then launches one per open finding, for up to four passes. There
is no launch budget; the owner removed it on 2026-09-21. **Put the count and its cost to the owner
before the first run**, and let him choose whether the first one is the whole panel or the bound half.

**What to do with a finding — three things, and no fourth.**

- **Fix it**, where the fix is documentation. One finding per commit, through
  `gbg docfix commit --message "…" --finding <id>`, which asks the change guard before the commit
  exists. That trailer is how the diff verifier finds the diff and how a bad fix is reverted; a commit
  carrying two findings can be reverted for neither. `gbg docfix check` says what the change broke, and
  says separately what was already broken when the run opened.
- **Leave it open**, where you think the reader is wrong. Do not fix it and do not close it. Say why in
  the run's report; it survives the passes and goes to the owner's work queue at close, which is where a
  disagreement belongs.
- **Ask**, where the fix would touch code or anything inside a math span. Every edit inside a math span
  is the owner's, always, without exception.

**Never switch a rule or a reader off to dispose of a finding, and never touch `.gbg/config.jl` while a
run is open.** The config is code; a change to it during a run is found at close and ends the run
`CANNOT_EVALUATE`. A switch is a decision about the package, made with the owner and outside a run.

**While a stage is out, nothing touches the tree.** A commit, an uncommitted edit to a tracked file, a
pull — any of them and `gbg run collect` exits 2 and reads nothing, because a quote anchored in one tree
cannot be trusted against another. Do no other work in PF while a run is open. This repository is inside
Dropbox, and a sync landing on a tracked file mid-stage has the same effect; it is waited out.

**Push the guarded commits as you make them.** The run may revert some of them — a verifier returning
`MADE_WORSE` or `HIDES_CODE_DEFECT`, or a red build at close — and each revert is itself a guarded
commit, so nothing is rewritten. Those two verdicts are the verifier's, not the change guard's: the
guard only rules a change documentation or code. Never amend or rebase a guarded commit; the trailer is
how the run reads it back.

**The run builds PF's site with PF's own `docs/make.jl`,** before the reading stage and before every
blind verifier stage. Budget for six or more full builds in one run, and make sure the build is green
and every banked round under `.claude/` carries its closure **before** the run opens: PF's own
`lint_review_closure` fails the build on an unclosed round, and a failed build leaves the run stalled
with nothing launched.

**A run out of budget is unfinished and resumable, never abandoned and never filed as leftovers.** Leave
the tree as the stage found it, say in the chat that the run is open and at which stage, and stop. The
next session runs `gbg run next`, which relaunches only what did not write. The one case it stops for
the owner is the tree having moved since the launch. `gbg run abandon` **drops the run's findings**, so
it is the owner's word and never a way out of a stuck stage.

**At close**, the report is written and what is still open goes into `.claude/WORK_QUEUE.md` under
`## From the last review`. That section is the owner's list: PF's Stop hook does not count it, on
purpose, because a review setting a session to work nobody asked for is what that heading exists to
prevent. Do not tick those lines and do not start working them because they are there. Commit
`.gbg/runs/<id>/` — the record and the report — yourself: `gbg docfix commit` deliberately leaves them
out, and nobody else commits them.

**The question channel was wired shut until rc.7, and is the reason to pin rc.7 rather than rc.6.** A
question a verifier raises lives in the run's own record, and the command the report named could not
reach it; and nothing in the tool ever created a question outside a run, so the listing verb always said
nothing was waiting. Both are fixed at rc.7. Answering that the reader was wrong now also records a
settled ruling, which every later run's agents are told not to report, so the same parked finding does
not come back next time.

**Nothing in this machinery has met a real agent.** Every rehearsal was a fixture run. Report what
breaks rather than working around it.

## Step 5 — what PF owns and what this package now owns

**This step applies to every package.** Whoever adapts this file for the next one carries it over.

`gbg init` installed a line at the head of PF's `CLAUDE.md`: nothing restates a rule outside the
rulebook. PF's `CLAUDE.md` is 2,756 lines. No program finds the duplication — no rule statement appears
verbatim in it, because nobody copy-pastes a rule, they paraphrase it — so this is a judgement a reader
makes once, and this step says what to look for.

Four kinds, and two are this package's business:

1. **Prose restating a rule.** The bulk. It goes; the rulebook carries it.
2. **A mechanism this package has SUPERSEDED.** The list is below, and each entry has a date.
3. **Conventions genuinely PF's own.** The representation qualifier trailing what it qualifies;
   "operators are not spectral". They can be recorded as `PatternRule`s in `.gbg/config.jl`, but
   **nothing executes a `PatternRule` today**: it is rendered onto the switches page and checked by
   nothing. Do not trade a live convention for one on the promise that it is enforced.
4. **Records** — decision logs, closures, cross-package requests. Not style, not rules, not this
   package's business.

One paragraph of PF's `CLAUDE.md` still says the shared tooling package is designed and not built, and
that nothing in PF changes before it is. Step 1 has just made that false. It describes a state of the
world rather than a convention, so correcting it is documentation and needs no answer — but correct it,
rather than leaving a standing instruction that contradicts every step above.

### Superseded, with the date

- **The end-of-turn hook** (2026-09-18). `Render.hook` writes it; every `gbg sync` overwrites it.
- **`lint_prose_shape`** (2026-09-18, already retired in PF).
- **`check-docs` and `check-consistency` under `.claude/commands/`** — superseded **in principle,
  today**: `documentation_review` reads the same documentation and answers the same questions, through
  readers derived from the rulebook rather than a lane list PF maintains. **Do not cut them before the
  first review has closed.** The test of supersession is that the replacement reads the same input and
  produces the same verdict, and no run has yet met a real agent. Run the review, compare what it found
  with what the last `check-docs` round found, and then decide — a judgement for a person with evidence,
  not a deletion to schedule.

### Not superseded, however much it looks it

- **`bug-hunt` and `audit-changes` under `.claude/commands/`.** The skill files the bump wrote for them
  read like complete working protocols and say nowhere that they are not: `gbg run bug-hunt` answers
  that it has no readers yet and that nothing would be launched, and exits 2. PF's own commands are the
  working ones and stay until Phase 7. Where the names collide, the command is the real one.
- **`test/exhaustive/` (7,272 lines of Julia).** Its filenames read like documentation linting; it is a
  property sweep over PF's operation surface. Nothing here replaces any of it.
- **Anything whose supersession you cannot demonstrate.** Of three items an earlier draft of this file
  certified, two failed that test and one would have taken the most valuable testing in the package.

## The gate

PF is done when `julia --project=docs docs/make.jl` and `Pkg.test()` both exit 0, `gbg sync --check` is
clean, the tree is committed, and **no run is left open** — `gbg run next` says whether one is. Both
commands run the rulebook themselves; there is no separate step and no report to file.

**Run the gate in your own checkout, not from a clone, and do not trust a clone that says it passed.**
A clone cannot run the docs build at all, for two reasons that have nothing to do with this upgrade.
Both manifests are gitignored and `docs/Project.toml` lists `GBGPeriodicFields` in `[deps]` with no
source for it, so instantiating there fails with `expected package GBGPeriodicFields to be registered`;
and with the package developed in past that, Documenter then refuses a repository cloned from a local
path with `Unable to automatically determine remote for main repo`. What was measured on the clone,
with every change of Steps 1 to 3 applied, is `Pkg.test()`, which exits 0 over PF's whole suite
including the rulebook. The docs build was not measured and is yours to run.

A note on what `gbg check` alone proves: it reports over the rules it can decide without a loaded module
or a built site, so six rules do not run in it — five that need the package or the site, and
`RULE.CIT.RESOLVES`, which needs the network. Those run inside the docs build and the test suite, which
is why the gate is the gate.

## Reporting a defect in this package

A tool defect, or a discipline the catalogue lacks, is a tracked file in PF:
`.gbg/requests/to-GBGCodingTools-<date>-<topic>.md`, with a status paragraph on top, deleted when it is
concluded. That is the whole channel. Never an edit in this package's repository from PF's session, and
never a change in PF made to satisfy a finding you believe is wrong.

Fourteen defects in this package were found by rehearsing the wiring and by three adversarial passes over
the rc.1 draft of this file, and all are fixed. Since then: a git race in every directory walk, and a run
that committed its own scratch files. If a class of findings looks wrong to you in the same way, it
probably is — say so rather than editing PF to satisfy it.
