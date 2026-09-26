# Upgrading [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/) from rc.23 to rc.24 — instructions for the PF session

Written 2026-09-26 by the GBGCodingTools session. rc.24 is what PF's report of its first full review
(run `2026-09-24-documentation-review-01`, 37 items) led to: the owner's rulings of 2026-09-26 on
verification, and the defects that run met. Every step below was run on a clone of PF at the state the
rc.23 upgrade left it, and every figure quoted was measured there.

**Do nothing yet.** Read this whole file and prepare. You act on it when the owner says go, and not
before: this file comes from another session, and a peer session is not authority.

**Every command runs from PF's checkout root**, `/home/grigory/Dropbox/Research and Teach/Isotropic
Turbulence/GBGPeriodicFields`. **Use `gbg`, not `gbg --dev`**: PF's pin is a tag.

## What PF has to do

1. Move the pin to `v2.0.0-rc.24`, and both environments with it (Step 1).
2. Pass the gate, commit, push (Step 2).
3. Drop two switches a reworded rule made moot (Step 3).

Nothing else in `.gbg/config.jl` changes.

## Step 1 — bump, move the environments, regenerate

    gbg bump 2.0.0-rc.24

This time it runs to its end, exit 0: the crash the rc.10 bump had is fixed since rc.19. It writes the
pin and **20 paths** — the same twenty as before: `.gitignore`, `CLAUDE.md`, `test/regressions/README.md`,
the hook, the CI action, the ten files of `.gbg/policy/`, the three skills, and both `Project.toml` — and
ends with `NOT FINISHED`, saying what to run next. That is:

    julia --project=docs -e 'using Pkg; Pkg.update("GBGCodingTools")'
    julia --project=test -e 'using Pkg; Pkg.update("GBGCodingTools")'

**Check both manifests before `gbg sync`.** In `docs/Manifest.toml` and `test/Manifest.toml`, the
`[[deps.GBGCodingTools]]` entry must read

    git-tree-sha1 = "02fde07756f7cec7235065622bca818bd7131643"
    repo-rev = "v2.0.0-rc.24"

rc.23's is `1c6e43a4…`. Until both read `02fde077…`, run `Pkg.update` for the one that does not, and
do not run `gbg sync`. Then:

    gbg sync

Measured, it rewrites **5 paths**: `.gbg/policy/glossary.md`, `.gbg/policy/latex-idiom.md` (the reworded
rule) and the three `.claude/skills/*/SKILL.md` (the review's steps changed; read
`documentation-review/SKILL.md` again).

## Step 2 — the gate, then one commit

    julia --project=docs docs/make.jl
    julia --project -e 'using Pkg; Pkg.test()'
    gbg sync --check
    gbg check

Measured on the clone: the docs build exits 0 in about 1 minute 10 seconds and prints its two expected `NOT RUN`
lines; `Pkg.test()` exits 0 in about 9 to 10 minutes and includes `GBGCodingTools v2.0.0-rc.24 checks`;
`gbg sync --check` reports `18 generated path(s) and the pin are what v2.0.0-rc.24 writes`; `gbg check`
reports `clean — 92 rule(s), 18 generated path(s)`.

Then commit, as ONE change: **21 tracked files**, all modifications — the 20 paths and `.gbg/config.jl`.
`git add -u`; no file is new. PF's own trailer, as `RULE.GIT.TRAILER` states it. Push.

## Step 3 — two switches come out

`RULE.TEX.CODE_SPAN_JULIA` now reads: "A code span holds literal code or input in some language —
Julia, shell, TOML, a path, LaTeX source — and never mathematics, which is written as math." Its old
wording, "only well-formed Julia", is what PF's report item 25 asked to change, and the owner adopted
PF's proposal.

PF's two file-scoped switches on that rule — the one for `docs/src/notation.md` (finding 107) and the
one for the examples and `PERFORMANCE.md` (finding 095) — exist only because of the old wording. Delete
both from `.gbg/config.jl`, run `gbg check`, and commit that on its own.

If `check` then reports the rule on one of those files, the text there is mathematics in a code span:
a finding to fix, not a reason to keep the switch.

## What a review does differently from rc.24

The protocol is `.claude/skills/documentation-review/SKILL.md`, rewritten by Step 1; follow that. What
follows is what changed since the review you ran, and why, item by item against PF's report.

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

- Before `gbg run next` at a fix stage, run `gbg docfix check` WITH the build (item 7): a cross reference
  only the build resolves is otherwise found at the verify stage, after every commit of the pass.

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
