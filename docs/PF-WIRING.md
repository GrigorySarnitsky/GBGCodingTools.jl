# Upgrading [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/) from rc.23 to rc.30 — instructions for the PF session

Written 2026-09-26 by the GBGCodingTools session. rc.24 to rc.26 answer PF's report of its first full
review (run `2026-09-24-documentation-review-01`, 37 items) and the owner's rulings of 2026-09-26 on
it; rc.27 is Phase 5 of the rebuild, everything before
[GBGHomogeneousTurbulence](https://grigorysarnitsky.github.io/GBGHomogeneousTurbulence.jl/). Every step below
was run on a clone of PF at its head `d8c895fc`, and every figure quoted was measured there.

**Do nothing yet.** Read this whole file and prepare. You act on it when the owner says go, and not
before: this file comes from another session, and a peer session is not authority.

**Every command runs from PF's checkout root**, `/home/grigory/Dropbox/Research and Teach/Isotropic
Turbulence/GBGPeriodicFields`. **Use `gbg`, not `gbg --dev`**: PF's pin is a tag.

## What PF has to do

1. Move the pin to `v2.0.0-rc.30`, and both environments with it (Step 1).
2. Meet the 113 findings the docs build now reports (Step 2), as the owner decides.
3. Pass the gate, commit, push (Step 3).
4. Drop two switches a reworded rule made moot (Step 4).

rc.28 is the full code review of this package: three rules that read no file before now read PF, which
gives 112 of the 113. The last is rc.30's ban on `\left`/`\right`.

## Step 1 — bump, move the environments, regenerate

    gbg bump 2.0.0-rc.30

This time it runs to its end, exit 0: the crash the rc.10 bump had is fixed since rc.19. It writes the
pin and **20 paths** — the same twenty as before: `.gitignore`, `CLAUDE.md`, `test/regressions/README.md`,
the hook, the CI action, the ten files of `.gbg/policy/`, the three skills, and both `Project.toml` — and
ends with `NOT FINISHED`, saying what to run next. That is:

    julia --project=docs -e 'using Pkg; Pkg.update("GBGCodingTools")'
    julia --project=test -e 'using Pkg; Pkg.update("GBGCodingTools")'

**Check both manifests before `gbg sync`.** In `docs/Manifest.toml` and `test/Manifest.toml`, the
`[[deps.GBGCodingTools]]` entry must read

    git-tree-sha1 = "5e46dafeb2bf65bde7fa39b398205ef07eb7b8f5"
    repo-rev = "v2.0.0-rc.30"

rc.23's is `1c6e43a4…`. Until both read `5e46dafe…`, run `Pkg.update` for the one that does not, and
do not run `gbg sync`. Then:

    gbg sync

Measured, it rewrites **9 paths**: `.claude/hooks/queue-guard.sh` (the Stop hook now checks the three
git rules — read it), five rulebook files (`glossary.md`, `docs-rubric.md`, `latex-idiom.md`,
`testing-protocol.md`, `git-conventions.md`) and the three `.claude/skills/*/SKILL.md` (the review's
steps changed; read `documentation-review/SKILL.md` again).

## Step 2 — 113 findings, 112 of them from rules that could not see before

Run `julia --project=docs docs/make.jl`. Measured on the clone, it stops before building, in about 30
seconds, on 113 findings:

- **90 × `RULE.DOC.XLINK`** — the first mention of a name another of PF's modules owns, left bare in a
  docstring: `FiberTensor2` (17), `FiberVector` (13), `spectral_cutoff` (9), `Grid3D` (9), `PointSet`
  (8), and others. Fixed by making the mention a link to its docstring. Standard-library generics (`norm`,
  `dot`, `mul!`) are not reported; 17 of the 90 are in docstrings of `_`-prefixed internals.

- **16 × `RULE.DOC.SIGNATURE_FIDELITY`** — a displayed signature whose names or keywords no longer match
  the method: `norm!` shows `u` and `A` where the method names others; `interpolate!`, `interpolate`,
  `anterpolate!` and `anterpolate` define a `traversal` keyword no signature shows; `Grid3D`'s `origin`
  and the field constructors' `array_type` likewise. Fixed by correcting the docstring to the method.

- **5 × `RULE.DOC.ARGCOV`** — `mul!`'s docstring documents "the two operands" together, so `A`, `u`,
  `a` and `B` have no bullet of their own; and `map!`'s `source`.

- **1 × `RULE.TEX.RENDERED_MATH`** — the inner product of `f` and `g` written in a code span, at
  `docs/ARCHITECTURE.md:387`; written as math it renders.

- **1 × `RULE.TEX.LEFTRIGHT`** — `docs/src/notation.md:20`, a brace sized with `\left\{ … \right.`.
  Rewritten with `\bigl`/`\Bigl`, or — only if the owner says so — listed exactly in
  `leftright_allowed` in `.gbg/config.jl`.

By file: FieldAlgebra 23, FiberSections 18, Reductions 15, Convolution 13, Fields 12, Interpolation 10,
Points 9, GBGPeriodicFields 7, DifferentialOperators 4, notation.md 1, ARCHITECTURE.md 1.

Each is either fixed (they are all documentation: no code changes) or switched off in `.gbg/config.jl`
with a reason, per file where only some files should be exempt.

**Ask the owner which before you start** — fix all 113 now, switch a rule off with a reason, or fix some
and switch the rest; the upgrade cannot be committed with the build red. Two things he should know when
he answers: the link fixes are mechanical and many, and a displayed signature that disagrees with its
method misleads a reader at the REPL.

## Step 3 — the gate, then one commit

    julia --project=docs docs/make.jl
    julia --project -e 'using Pkg; Pkg.test()'
    gbg sync --check
    gbg check

Measured on the clone before Step 2: `Pkg.test()` exits 0 in about 10½ minutes — the three file-decided
git rules run inside it now, and PF is clean on them — and prints `GBGCodingTools v2.0.0 checks — the
config pins v2.0.0-rc.30` (the banner names the version that ran and the pin beside it); `gbg sync
--check` reports `18 generated path(s) and the pin are what v2.0.0-rc.30 writes`. The docs build exits 0
once Step 2 is done, and prints its expected `NOT RUN` line.

`gbg check` now also runs the three hook rules, over the commits not yet pushed: on a PF that is pushed
and on `master` it reports `clean — 92 rule(s), 18 generated path(s)`. On the clone it reported 180
unpushed commits and two of them without a trailer, because the clone's `origin` is a stale fetch with
pushing disabled; that is the clone's artefact, not PF's state, whose `master` is level with `origin/master`.

Then commit the upgrade: **21 tracked files**, all modifications — the 20 paths and `.gbg/config.jl` —
with whatever Step 2 changed, or Step 2's fixes as their own commits before it, as the owner prefers.
`git add -u`; no file is new. PF's own trailer, as `RULE.GIT.TRAILER` states it. Push.

## Step 4 — two switches come out

`RULE.TEX.CODE_SPAN_JULIA` now reads: "A code span holds literal code or input in some language —
Julia, shell, TOML, a path, LaTeX source — and never mathematics, which is written as math." Its old
wording, "only well-formed Julia", is what PF's report item 25 asked to change, and the owner adopted
PF's proposal.

PF's two file-scoped switches on that rule — the one for `docs/src/notation.md` (finding 107) and the
one for the examples and `PERFORMANCE.md` (finding 095) — exist only because of the old wording. Delete
both from `.gbg/config.jl`, run `gbg check`, and commit that on its own.

If `check` then reports the rule on one of those files, the text there is mathematics in a code span:
a finding to fix, not a reason to keep the switch.

## What changed since rc.23

The protocol is `.claude/skills/documentation-review/SKILL.md`, rewritten by Step 1; follow that. What
follows is what changed since the review you ran — first Phase 5, then the items of PF's report.

### Phase 5, from rc.27

**Three git rules run in your test suite now**, from the files: `RULE.GIT.CI_MANUAL` (a test workflow fires
on `workflow_dispatch` and release tags alone; a docs workflow on a branch push), `RULE.GIT.MANIFEST_TRACKED`
(every sub-environment manifest ignored) and `RULE.GIT.REQUESTS` (a request is
`.gbg/requests/to-<PKG>-<date>-<topic>.md` and its first paragraph begins `Status:`). Measured on the clone:
PF is clean on all three.

**Three are checked by the Stop hook**, which Step 1 rewrites: `RULE.GIT.BRANCH`, `PUSH` and `TRAILER`, on
the commits not yet pushed. A turn does not end with an unpushed commit, a commit without a
`Co-Authored-By: … <noreply@anthropic.com>` line, or on a branch other than `master`; the hook says which.
`gbg check` runs the same lines. A build never does.

**The four harness contracts bind a package that declares them** (`RULE.TEST.ORACLE_INDEPENDENT`,
`ALLOC_ZERO`, `PASS_AUDIT`, `METHOD_PARITY`): PF declares none and holds no switch on them, so nothing
changes for PF.

**A third state beside the switch: the deferral.** `Deferral(rule = Symbol("RULE.API.POSITIONAL"), until = "…")`
in `.gbg/config.jl` says a rule is owed and not yet met, with what would close it; it fails no build and is
listed beside the switches. None of PF's switches is one — each is an answer — so none changes.

`gbg config`, `gbg probe` and `gbg scan` no longer exist; `makedocs` takes the root, as PF's `docs/make.jl`
already passes it.


### Verification (items 15, 17, 34–37)

**One verifier per place, with the diff, and one pass** (ruled 2026-09-26). The open findings are
grouped by the unit they sit in — the built page, for a `withheld@…` finding; the example's source;
otherwise the file named first — and one verifier per unit, with at most ten findings, is given those
findings, the unit as it now stands and the diff of the pass's commits.

It answers each by id: `FIXED`, `NOT_FIXED`, `LINE_ONLY`, `MADE_WORSE`, `HIDES_CODE_DEFECT` or
`NOT_A_DEFECT`, each with one verbatim quote. The `diff` stage is gone; a pass is
`fix → verify → collect`. On your run, that would have been about 25–30 launches in place of 187.

The budget is one pass. A fix stage that committed nothing closes the run instead of verifying
unchanged text (item 17).

**Cost is recorded** (items 8, 12, 13, 34). After each collect, `gbg run cost <dir>` sums each agent's
own usage from the transcripts under the directory the `Workflow` result names — the one holding its
`journal.jsonl` — into the run record, per stage and pass, and the report prints the table. The
launch's `usage.subagent_tokens` field is not used anywhere.

### What a verifier could not see (items 18, 19, 20)

- The page text shows a link as `[text](target)`, so a term fixed by linking it to its definition no
  longer reads as the unfixed text.
- A quote of two spans joined by `...` or `…` holds when each span does. The brief also tells the
  verifier to quote ONE verbatim span.
- The driver returns every agent's validated result. **Save the whole `Workflow` return as
  `returned.json`** in the stage's directory, which `gbg run next` names; the collect falls back on it
  for a role whose own file never appeared. Three of your FIXED verdicts were lost that way.

### The grade and the record (items 9, 10, 16, 29, 32)

- A demotion — a quote not in the text, a verdict outside the list, no verifier answering — is written
  on the fix record as `note`, not only printed.
- A silent verifier's findings are graded `NOT_FIXED` and stay open; collect says so. A silent READER
  still makes the run `CANNOT_EVALUATE`.
- `gbg run next` and `collect` name the pass.
- A pass's fixes are the commits since the pass began (`pass_since`), so a later pass shows its own.
- Abandoning keeps the text of what it dropped on the record, marked `dropped_ids`, and the report lists
  each; nothing dropped is carried into the next run.

### Parked findings (items 1, 2, 27, 30)

- A question's id is `<finding>-code`, no longer prefixed with the run's id a second time.
- A parked finding's question offers three answers: `I make the change` (yours; the finding goes on
  your list), `fix it on my ruling` with `--direction "…"` (the fixer's again; `docfix commit --finding`
  accepts the id; a verifier closes it), and `not a defect`.

### The guard and the checks (items 4, 7, 21, 23, 24, 25)

- `gbg docfix commit` refuses a change that breaks a rule the run opened clean on, where `check`
  reported it and `commit` went ahead.
- The prose of a Literate `#md # …` line may change, as any Markdown line's may; its mark stays.
- `RULE.DOC.SHAPE` counts a formula as one word however it is laid out, and no lone dash.
- Inside a run a unit may grow by ten words, or five percent of its recorded count where that is more
  (item 5, ruled 2026-09-26); the close re-records what grew in `docs/prose_shape.csv`, which you
  commit with the record. More than that is refused, as before.
- `RULE.TEX.CODE_SPAN_JULIA` is reworded (Step 3).

- A red build at `gbg run next` names the pass's commits that touched the files it complains about, and
  `docfix check` and `commit` warn of every `@ref` they cannot resolve — a warning, never a refusal
  (item 7, ruled 2026-09-26). A build per commit was declined: two hours per pass on PF.

### Verbs (items 26, 31, 33)

- `gbg run <verb> --help` prints usage and acts on nothing.
- The driver copy a run places has the stage's arguments spliced in: the `Workflow` call passes no
  args, and the arguments file is never typed.
- `gbg check --rebaseline --unit <name>` re-records the named units alone.

### Not changed, by the owner's ruling (items 3, 6, 22)

- A moved formula is still a change the guard refuses, even with its text unchanged; such a finding is
  parked. `RULE.DOC.HOME_ORDER` fixes that move a formula are therefore his.
- A new comment line in a Literate example is still code under the simple rule; park it.
- The rulebook stays imported into `CLAUDE.md`. Item 11 (effort inheritance) and item 14 (about 5% of
  agents writing an unreadable file) are the harness's; the `returned.json` fallback covers the second.

**Still open for the owner, if the last review did not settle them:** where the hand-written triage in
`.claude/WORK_QUEUE.md` goes before the next close rewrites `## From the last review`, and the two
questions in `.gbg/questions.json`. Ask him; do not decide them.

## Reporting a defect in this package

A tool defect, or a discipline the catalogue lacks, is a tracked file in PF:
`.gbg/requests/to-GBGCodingTools-<date>-<topic>.md`, with a status paragraph on top, deleted when it is
concluded. That is the whole channel. Never an edit in this package's repository from PF's session, and
never a change in PF made to satisfy a finding you believe is wrong.
