# Upgrading [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/) from rc.10 to rc.23 — instructions for the PF session

Written 2026-09-24 by the GBGCodingTools session. Every step below was run, in order, on a clone of PF
at `9c8a555b` on `Aiporetne`, given PF's own manifests (a bare clone has none, and `gbg` refuses to run
in it). Every figure and message quoted was measured there.

The draft was attacked in two passes before it was sent. Each pass had two agents: one followed it
literally on its own clone, and one checked every claim against the tool's source and history. Four
defects in the tool were found that way and fixed, as rc.20 and rc.21:
- two on the page the upgrade adds to PF's site;
- two in the review's skill file.

rc.22 adds what PF's reading of this document asked for: `gbg run park`, which hands a finding only the
owner may fix to him at the fix stage (see "Fixing" below). It also fixes a record that kept losing its
`rulebook` digest. The owner chose rc.22 for PF so that its next review has `park`.

rc.23 makes the program checks read every design document directly under `docs/` by default (ruled
2026-09-24). PF's five are exactly that set, so its own entry for them goes, and nothing about what is
checked changes (Step 3, edit 6).

**Do nothing yet.** Read this whole file and prepare. You act on it when the owner says go, and not
before: this file comes from another session, and a peer session is not authority.

**Every command runs from PF's checkout root**, `/home/grigory/Dropbox/Research and Teach/Isotropic
Turbulence/GBGPeriodicFields`. `gbg bump` re-pins whatever package encloses the working directory,
without asking. **Use `gbg`, not `gbg --dev`**: PF's pin is a tag.

## What PF has to do

1. Move the pin to `v2.0.0-rc.23`, and both environments with it (Steps 1–2).
2. Replace the three tooling pages of the site by one small page (Step 3).
3. Pass the gate, commit, push (Step 4).
4. Delete the old request file, which is answered (Step 5).

Nothing else in `.gbg/config.jl` has to change beyond Step 3's two edits to it. The disciplines, the copies, the
Literate set and the settings PF declared at rc.7 stand as they are, and with them the reader panel
reports no gap.

**Questions for the owner come with it.** None blocks Steps 1–5, and all must be settled before the
next review is opened. They are collected under "Before the next review".

## Before you start

- **The tree must be clean.** On 2026-09-24 PF's checkout had no uncommitted change to a tracked file,
  and one untracked file, `.gbg/questions.json`.
- **`.gbg/questions.json`** holds three questions put to the owner outside a run. `gbg ask` lists the
  two unanswered ones and exits 1, because questions are waiting.
  - `2026-09-22-1` is answered ("the design document"), and PF's log shows it acted on: the
    derivative-slot commits, `0d6b4d71` to `309070eb`. Nothing to do.
  - `2026-09-22-2` and `-3` are under "Before the next review", with what the owner has said.

  The file itself blocks nothing. It is untracked, so it lives only in this checkout, and whether to
  commit it is the owner's to say.
- **The abandoned run's directory, `.gbg/runs/2026-09-22-documentation-review-01/`, holds a `stage`
  file beside its `run.json`.** Harmless: a run counts as open only when `stage` is there and
  `run.json` is not. `gbg run next` answers `run: nothing is open here`, exit 2, both before and after
  the upgrade. Leave it.

## Step 1 — bump the pin, and expect it to crash at its last line

    gbg bump 2.0.0-rc.23

It writes the pin and **20 paths**, prints them, and then **crashes, exit 3**, with
`gbg bump: crashed — MethodError: no method matching stale_warning(::IOStream, ::VersionNumber)`. The
first type depends on where the output goes: `::Base.TTY` at a terminal, `::Base.PipeEndpoint` through
a pipe. Where stdout and stderr are captured together, the crash and its stack trace may print BEFORE
the list.

That crash is a defect of the code that is RUNNING, which is still rc.10, and rc.19 fixed it. The pin
and the 20 files are already written when it happens. So:

- **Go on to Step 2.** Ignore the bump's own line "Commit the config and the rewritten paths
  together…": the commit is Step 4's.
- **Do not bump again.** A second bump to the version already pinned is refused, exit 2, with a
  misleading message:

      bump: no `tool = …` line in .gbg/config.jl to move

The 20 paths are:
- `.gitignore`, `CLAUDE.md`, `test/regressions/README.md`, `.claude/hooks/queue-guard.sh` and
  `.github/actions/gbg-auth/action.yml`;
- the ten files of `.gbg/policy/`;
- the three `.claude/skills/*/SKILL.md`;
- `docs/Project.toml` and `test/Project.toml`.

`.gbg/config.jl` changes too, on the pin line only. No file is new. Eighteen of the 20 are what the tool
calls its generated paths; the other two are the `Project.toml` files, whose `rev` it moves.

## Step 2 — move both environments, check them, then regenerate under the new code

    julia --project=docs -e 'using Pkg; Pkg.update("GBGCodingTools")'
    julia --project=test -e 'using Pkg; Pkg.update("GBGCodingTools")'

**`Pkg.update`, not `Pkg.resolve`.** A resolve can write the new rev while keeping the old code, and
PF has met that twice. `Pkg.update` prints a line like
`GBGCodingTools v2.0.0 …#v2.0.0-rc.23 ⇒ v2.0.0 …#v2.0.0-rc.23`, which reads as if nothing moved. Ignore
it and read the manifests.

**Check both manifests BEFORE `gbg sync`.** `gbg run next` does not tell rc.10 from rc.23, since both
have the verb. In both `docs/Manifest.toml` and `test/Manifest.toml`, the `[[deps.GBGCodingTools]]`
entry must read

    git-tree-sha1 = "1c6e43a4c320067804c49acea1091528345681ea"
    repo-rev = "v2.0.0-rc.23"

That hash is the tree of the tag `v2.0.0-rc.23`; rc.10's is `18e4bae3…`. Until both manifests read
`1c6e43a4…`, run `Pkg.update` for the one that does not, and do not run `gbg sync`: a sync under the
old code writes the old files again, under the new banner. Once both read it:

    gbg sync

The bump regenerated with the code that was running, rc.10, so this sync is what writes rc.23's own
content. Measured, it rewrites **6 paths**:
- `.claude/hooks/queue-guard.sh`;
- `.gbg/policy/switches.md` and `.gbg/policy/docs-rubric.md`;
- the three `.claude/skills/*/SKILL.md`.

## Step 3 — one small page, inside "Design & Internals"

From rc.12 the tool writes ONE page, `docs/src/gbg.md`, and no longer the rules, readers and instruments
pages (ruled 2026-09-23: nothing of the tool belongs among a science package's main pages). The page
says what PF's documentation is held to, links to the rulebook on GBGCodingTools' site, and lists PF's
switches with their reasons. Six edits, the last of them the rationale entry:

1. **`docs/make.jl`, the `pages` vector.** Delete these three lines, currently lines 319–321:

       "Rules" => "gbg-rules.md",
       "Readers" => "gbg-readers.md",
       "Instruments" => "gbg-instruments.md",

   Add one line as the last item of the `"Design & Internals" => Any[ … ]` group, directly after
   `"Performance"   => "performance.md",` and at its indent of six spaces:

         "Documentation tooling" => "gbg.md",

2. **`docs/make.jl`, the comment above the `Render.pages` call**, currently lines 280–283, which
   describes the rules page. Replace its four lines with:

       # The one tooling page — what the documentation is held to, a link to the rulebook on GBGCodingTools'
       # site, and this package's switches with their reasons. It is written AFTER the lints above: those
       # eight walk `docs/src` from disk and know nothing of `generated`, so a page written earlier would
       # become their input.

3. **`.gbg/config.jl`, `generated` and the comment above it.** Replace

       # The rules page is written by `Render.pages` during the docs build. No rule reads a generated
       # page, which matters here more than usual: a page that states the rules quotes every banned
       # spelling in order to ban it.
       generated = ["docs/src/gbg-rules.md", "docs/src/gbg-readers.md",
                    "docs/src/gbg-instruments.md"],

   with

       # The one tooling page, written by `Render.pages` during the docs build: what the documentation
       # is held to, a link to the rulebook, and this package's switches. No rule reads a generated page.
       generated = ["docs/src/gbg.md"],

4. **`.gitignore`, PF's own section** below the managed block. Replace its three lines
   `docs/src/gbg-rules.md`, `docs/src/gbg-readers.md` and `docs/src/gbg-instruments.md` with the one
   line `docs/src/gbg.md`.

5. **Delete the three old files** from your checkout: `docs/src/gbg-rules.md`,
   `docs/src/gbg-readers.md` and `docs/src/gbg-instruments.md`. They are gitignored, so git shows no
   change. But the build no longer writes them, and a stale copy left there would be read as a
   hand-written page.

6. **`.gbg/config.jl`, the rationale entry and its comment.** Since rc.23 the rationale set's default is
   every Markdown file directly under `docs/`, which for PF is exactly its five documents. The owner's
   direction is that PF uses the default. Delete the two comment lines and the `FileSet.RATIONALE` entry
   that open the `filesets` block, keeping `filesets = Dict(` and the `FileSet.LITERATE` entry:

       # The four rationale documents are where this package's mathematics lives, so they are in scope
       # deliberately rather than by the default, which reads none of them.
       filesets = Dict(                                              ← stays
           FileSet.RATIONALE => ["docs/ARCHITECTURE.md", "docs/DECISIONS.md",
                                 "docs/FORMALIZATION.md", "docs/TESTING.md",
                                 "docs/PERFORMANCE.md"],

   Measured: the program rules then read the same five documents as before, and `gbg check` is still
   clean. The readers are unchanged either way: they get only `docs/ARCHITECTURE.md`.

## Step 4 — the gate, then one commit

    julia --project=docs docs/make.jl
    julia --project -e 'using Pkg; Pkg.test()'
    gbg sync --check
    gbg check

Measured on the clone:

- **The docs build** exits 0 in about 1 minute 10 seconds, and writes `docs/src/gbg.md` and `docs/build/gbg/`.
  - Its link to the rulebook answers, and PF's switch reason reads as written.
  - It prints two lines beginning `NOT RUN`, both expected and neither a failure. The first,
    `NOT RUN  RULE.TEX.RENDERED_MATH_SITE, RULE.TEX.RENDERED_MARKUP, RULE.DOC.API_GROUPING,
    RULE.CIT.RESOLVES (before the site is built)`, is printed before the site exists. The second,
    `NOT RUN  RULE.CIT.RESOLVES`, is printed after the build: that rule needs the network, and runs only
    under `gbg check --network`.
  - Documenter also prints size warnings for `architecture.md`, `api/Fields.md` and the search index,
    and "could not auto-detect the building environment", as it did before.
- **`Pkg.test()`** exits 0 in about **9 to 10 minutes**, so give it a timeout of at least 20 minutes. Its
  output includes the line `GBGCodingTools v2.0.0-rc.23 checks`, which is the rulebook running inside
  PF's suite.
- **`gbg sync --check`** prints `sync: 18 generated path(s) and the pin are what v2.0.0-rc.23 writes.`
- **`gbg check`** prints `check: clean — 92 rule(s), 18 generated path(s).`

Then commit, as ONE change. That is **22 tracked files**, all modifications: the 20 paths of Step 1,
`.gbg/config.jl` and `docs/make.jl` (`.gitignore` is among the 20). Stage with `git add -u`; no file is
new. A subject such as

    chore: GBGCodingTools pinned at v2.0.0-rc.23, and one tooling page for three

with PF's own trailer, as `RULE.GIT.TRAILER` states it in `.gbg/policy/git-conventions.md`. Push.

## Step 5 — the open request is answered; delete it

`.gbg/requests/to-GBGCodingTools-2026-09-22-upgrade-runs-the-old-version.md` still reads
**Status: open**. Its status paragraph speaks of two points, but the file has six numbered sections, and
every one is answered:

1. **`bump` writes the old version's files under the new banner** — rc.9. `bump` ends by saying it has
   not finished, and what to run next: the two `Pkg.update` lines and `gbg sync` of Step 2. That closing
   message is exactly what crashed in every bump from rc.9 to rc.18, which is Step 1's crash; rc.19
   fixed it.
2. **`Pkg.resolve` moves the label without the code** — rc.9. `Pkg.update` is the step itself, in that
   message and here.
3. **`RULE.CIT.RESOLVES` reads a `[` inside a math span as a link** — rc.14. A blank line ends a
   logical line, and brackets inside code and math spans do not count.
4. **BLOCKER: the driver does not parse** — rc.8, with a gate that lexes the driver. The note that
   `Workflow` refuses a `scriptPath` outside the working directory is answered in rc.9: a run copies
   the driver into its own scratch and prints the call to make. The review's skill still named the
   pinned driver until rc.21, which now says to make the call the verb printed.
5. **BLOCKER: the driver cannot write its result files** — rc.9. Each agent writes its own result file.
6. **An abandoned run reports a clean result** — rc.10 and rc.11. A run that launched nothing is no
   longer called clean. What an abandon leaves behind is ruled, and the record carries `dropped`, the
   count that was thrown away.

The file says to delete it once concluded. Delete it in a commit of its own, after Step 4's, so that
commit stays the 22 files it is measured at. Same trailer; push. That commit removes the whole
`.gbg/requests/` directory, since the file is the only one in it.

## Before the next review — for the owner

Put these to him before a review is opened. Opening one is his word in any case.

1. **The hand-written review triage in `.claude/WORK_QUEUE.md` would be erased by the next close.**
   - **What it is.** PF's section `## From the last review`, line 197 to the end of the file, is
     hand-written. The abandoned run found 142 findings and fixed 22, and the section triages the rest:
     17 disregarded, 15 waiting on a switch, 4 blocked on the tool, 2 withdrawn and 88 not examined.
     (`004` and `014` appear under two of those headings, so the counts overlap.)
   - **Why it matters.** It is the only record of that triage. Its own pointers to "the run's report"
     are stale, since the report was deleted in `9c8a555b`, and the run's `run.json` holds no findings.
     So **the next run carries none of the 142**: a run carries only what its predecessor's record
     still holds open.
   - **What the upgrade changes in it.** Most of it is overtaken, by the tool session's reading:
     - The 17 disregarded were on the generated pages, which are no longer read (rc.11) and no longer
       exist (rc.12).
     - The 15 waiting on a switch are answered by the `architecture_doc` default (rc.11), and the
       documents they were on are no longer read by any reader (rc.13).
     - Of the 4 blocked on the tool, three are unblocked. `014` and `004` are in
       `examples/HIST_CPU.jl`, which is fixable since rc.11; `004`, the Lamb vector written ``u \times \omega``
       where the name denotes ``\omega \times u``, is a real error and still goes to the owner if the fix touches a
       formula. `033` is docstrings on a bare name, which are documentation since rc.11. `011`, a
       switch, is still the owner's: in a run it is parked, with `gbg run park`.
     - The 2 withdrawn wait for the re-baseline the close allows (rc.11).
   - **Why it cannot just move.** From rc.17 every close rewrites that section whole, even when it has
     nothing to put there. The section holds 14 open `- [ ]` lines, and the Stop hook counts every open
     line outside `## From the last review` and `## Code the owner asked for`. So under any other
     heading it would hold every session to them.
   - **The owner's call:** where it goes — a file of its own, for instance, which nothing counts — and
     whether `004` becomes a finding of the next run or a question now.
2. **`2026-09-22-2`**, whether the wrapping of the example's over-wide code lines goes in as a code
   change. **The owner's direction, 2026-09-24:** it goes in as a code change, which he grants when you
   ask him before making it. The question's premise has moved — since rc.11 a documentation fix may
   touch the example's comments — but a code line is still code. When he has granted it, record it with

       gbg answer 2026-09-22-2 "apply it as a code change"

3. **`2026-09-22-3`**, whether docstrings on a bare name are fixed as code changes, **no longer has a
   premise**: since rc.11 the guard reads such a docstring as documentation. Neither of its options
   ("apply them as code changes", "leave them on the queue") says that, and `gbg answer` has no verb to
   withdraw a question. Tell the owner, and close it the way he says.

## What a review does differently now

None of this is a step. It is what changed between rc.10 and rc.23 in the machinery the owner will next
ask you to run. The protocol itself is `.claude/skills/documentation-review/SKILL.md`, which Step 2
rewrote: follow that, not a restatement of it.

### Terms

These terms are used as the tool uses them:
- **target** — something a user reads, which a reader judges and the fixer may edit: the docstrings,
  the hand-written pages, the Literate examples and `docs/ARCHITECTURE.md`.
- **material** — something a reader may open to judge a target: the source, and what the config's
  `material` lists. A finding located ONLY in material is still collected, but it goes to the owner,
  and the fixer never touches it.
- **unit** — what one launch of a per-unit reader is given: one built page's text, or one Literate
  example's source file.
- **The readers**, by the ids a run prints:
  - `withheld` reads one unit and nothing else, launched once per unit (`withheld@<page>`);
  - `plain_sense` also reads one page alone, once per page (`plain_sense@<page>`);
  - `full` reads the whole documentation with the source beside it;
  - `rendered` reads the built site;
  - `logician`, and one expert per discipline PF declares: `differential_geometry`,
    `spectral_numerics` and `software_architecture`.
- **bound reader** — a reader that checks named rules.
- **open reader** — a reader with a standpoint, reporting what no rule names. A discipline counts as
  open whether or not a rule also binds it, so `differential_geometry`, which carries
  `RULE.DOC.COORD_FREE`, is both.
- **fix pass, blind verifier, diff verifier.** A fix pass is the stage where you fix and commit. Each is
  followed by two verifier stages:
  - the blind verifier reads the text as it now stands, without the change;
  - the diff verifier is then shown the change, for what the blind one called fixed.

  Up to four passes.
- **the settled list** — `.gbg/settled.jl`, the owner's rulings that a finding is not a defect, which
  every later run's agents are told not to report again.
- **`DONE`, `CANNOT_EVALUATE`** — how a run ends: evaluated whole, or with part of it unjudged. What a
  `CANNOT_EVALUATE` run left open is carried into the next run.

### What is read, and by whom

- **Targets only** (rc.13). A finding may be placed in a target or, failing that, in material; only a
  target is ever handed to the fixer. The program checks read every design document under `docs/`
  (rc.23); the readers do not.
- **Each Literate example's source is a unit of its own** (rc.17), for `RULE.DOC.LITERATE`: `withheld`
  reads `examples/HIST_CPU.jl` alone, and `examples/gpu/rocm/HIST_ROCm.jl` alone. The ROCm example has
  no page, so no reader judged it by that rule before. The built example page is attributed to
  `examples/HIST_CPU.jl` through Documenter's `EditURL`, not to the gitignored
  `docs/src/examples/hist_cpu.md`.
- **The count, measured on PF's build.** 16 target pages:
  - `index`, `tutorial`, `gpu`, `notation`, `architecture` and `examples/hist_cpu`;
  - `api` and the nine `api/*` pages.

  With the 2 example sources, the reading stage is:
  - **`--readers bound`** (the default), **21 agents**: `withheld` once per page (16) and once per
    example source (2), plus `full`, `rendered` and `differential_geometry`.
  - **`--readers open`**, **20 agents**: `plain_sense` once per page (16), plus `spectral_numerics`,
    `software_architecture`, `differential_geometry` and `logician`.
  - **`--readers both`**, **40 agents**: 16 × 2 per-page launches, 2 example sources, and the six
    others.

  The default leaves out four readers: `spectral_numerics`, `software_architecture`, `plain_sense` and
  `logician`. Each verifier stage then launches one agent per open finding. There is no launch budget,
  so **put the number to the owner before a run**.
- **The two cold-read rules, `RULE.DOC.TERMS_DEFINED` and `RULE.DOC.SELF_CONTAINED`,** no longer hold a
  design document to a cold read (rc.11). The exception is the one document the `architecture_doc`
  parameter names, by default `docs/ARCHITECTURE.md`.
- **A switch that names files now reaches the readers** (rc.17). A unit whose file the switch names is
  not asked about that rule. A finding is dropped at collect when its rule is switched off for every
  file the finding names.
  - PF's one switch, `RULE.DOC.RETIRED_CLAIMS` on `docs/DECISIONS.md`, is unaffected: that rule is a
    program check, which still reads the decision log, so **the switch stays**.
- **`--scope changed`** (rc.17). A changed-scope run measures from a BASE: the last run with the same
  `--readers` choice that ended `DONE` and whose record is committed. Without such a base it reads
  everything. It also reads everything when:
  - the run's recorded digest of the rulebook, the readers and the driver differs from the current one;
  - `.gbg/config.jl` or `docs/make.jl` has changed since the base;
  - the base is not an ancestor of HEAD.

  A deleted page now counts as a change. PF's last run was abandoned, not `DONE`, so the next run reads
  everything whatever is asked.

### Fixing

- **`gbg docfix commit` needs `--finding <id>` while a run is open** (rc.11). From rc.17 it also
  refuses an id the open run cannot work on: one closed, one located only in material, or one waiting
  on the owner. One finding per commit, as before.
- **A finding whose fix only the owner may make is PARKED** (rc.22, ruled 2026-09-24):

      gbg run park <id> --why "<what the fix would change>"

  - **When:** at a fix stage, for a finding whose fix is a change to `.gbg/config.jl` (a switch, a
    setting, a declared document), to code, or to a formula.
  - **What it does:** it puts a question to the owner on that finding, the same one a verifier's
    `HIDES_CODE_DEFECT` puts. No pass and no verifier works on the finding after that, and `gbg ask`
    and the work queue list it. His "fix the code" puts it on his own list; his "not a defect" closes it.
  - **Why:** before rc.22 such a finding stayed open. A verifier was launched on it every pass to find
    nothing changed, and it reached the owner only at close. `gbg ask` put a question tied to no finding,
    so it did not stop that.
  - **Refusals, exit 2:** outside a fix stage, with no `--why`, or for a finding the run cannot work on
    (closed, located only in material, or already waiting on the owner).
  - This is the route for PF's `011`-like findings, which ask for a switch.
- **A document that is not a target cannot be edited through it** (rc.13). During a run,
  `gbg docfix commit` refuses a change to `DECISIONS.md`, `FORMALIZATION.md`, `TESTING.md` or
  `PERFORMANCE.md`, exit 1. A docstring fix that wants a matching FORMALIZATION edit is the owner's:
  park the finding.
- **It refuses more, from rc.17:**
  - **Something already staged.** It prints "something is already staged; unstage it first", so do not
    `git add` before it.
  - **A message that already contains the text `GBG-Docfix`.** The tool writes its own `GBG-Docfix`
    trailer lines. The `Co-Authored-By` trailer PF's rule asks for is still yours to write in the
    message.
  - **It commits only the paths it classified**, never anything else in the index.
- **The change guard follows two simple rules** (rc.17, both chosen by the owner):
  - **Mathematics** is what Documenter renders as a formula, and every edit to one is the owner's. The
    one exception is turning a code span into a math span with the same text, or back. The skill
    states this exception from rc.21.
  - **In a `.jl` file** only the TEXT inside docstrings and comments that already exist may change;
    everything else stays byte for byte. Adding, removing or moving a docstring or a comment is the
    owner's.
- **A docstring on a bare name** — `"""…""" mean` above per-backend methods — is documentation like any
  other (rc.11).
- **In a Literate example, a `#` comment may become `##`, or the reverse** (rc.18, ruled 2026-09-24).
  That is the fix `RULE.DOC.LITERATE` asks for when a comment inside a loop must not render.
  - The first `#` must stay, so a comment can be neither removed nor turned into a mark such as `#md` or
    `#src`.
  - A code chunk that such a change splits shows up in the docs build, which a run must pass before it
    closes.
  - Before rc.11, no Literate example was fixable at all.
- **The guard refuses a generated page** (rc.11), as it refuses a declared copy and a normative
  document.
- **The session's own files are looked past** (rc.11, rc.15, rc.17): the run's record and scratch,
  `.gbg/questions.json` and `.claude/WORK_QUEUE.md`. `gbg docfix commit`, `gbg docfix check` and the
  `gbg run` verbs ignore them when they ask whether the tree is clean, so a note written in the queue no
  longer blocks a pass.
- **The tree must be clean at two more points** (rc.17). `gbg run next` refuses to move from a fix pass
  to its verifiers while a tracked file is changed and uncommitted, and `gbg run close` refuses a dirty
  tree. Both exit 2.
- **Raising a prose-shape baseline is a closing step** (rc.11). The baseline is PF's tracked
  `docs/prose_shape.csv`, raised with `gbg check --rebaseline`. The run closes first, and the raise is a
  separate commit with its reason, never part of a fix pass.

### Placing and verifying

- **A quote is found as the source spells it first** (rc.17): on one line, then across its wraps. Only
  where no file holds it that way is it matched as the built page reads it. That means links,
  backticks, dollars, emphasis, a docstring's doubled backslash and Literate's comment marks are set
  aside on both sides.
  - On twenty quotes taken from PF's built pages, 8 were placed right before and 20 are now.
  - Over every two-line window of PF's documentation, nothing that was placed before is lost.
  - A quote no file holds, or two files hold, stays unplaced and is reported as such.
- **A verifier is given what its reader had** (rc.17):
  - The blind verifier of a finding made from one unit judges that unit alone.
  - The verifier of a finding made on the built site is handed the site.
  - The diff verifier is shown every commit of the fix, oldest first. When no commit names the
    finding, it is shown every fix of the run, with a line saying so.
- **Duplicates are merged** (rc.17). Findings under the same rule that quote the same words at the same
  place become one, and every reader's claim, evidence and fix is kept in it. Findings under no rule
  merge only when their claims are identical.
- **A silent agent is launched again once per stage and per pass** (rc.17). If it is still silent,
  collect exits 2 and names it, and a silent READER makes the run end `CANNOT_EVALUATE`. A later pass
  never grades an earlier pass's verdict.

### Answering, abandoning, closing

- **`gbg ask`** lists the questions runs put as well as those put outside a run (rc.17), and exits 1
  while any is waiting. An answered question shows its answer in the report.
- **When a blind verifier believes the code is wrong**, the fix is reverted, and the owner is asked "Is
  the code right here, or the documentation?". The question has three options:
  - **"fix the code"** puts the finding on the owner's own list in `.claude/WORK_QUEUE.md`, under
    `## Code the owner asked for` (rc.17). No close rewrites that heading, and the Stop hook does not
    count it.
  - **"fix the documentation instead"** re-makes the reverted edit all or none, and is refused while a
    run is open (rc.17).
  - **"not a defect"**, given to the OPEN run's own question, is recorded at once and written to the
    settled list when the run closes (rc.17). Any other answer that would write the settled list is
    refused while a run is open; answer it after the close.
- **`gbg answer … --settled`** is the flag that also records an answer in the settled list. On a run's
  question it is accepted only with "not a defect" (rc.17).
- **Every close writes the queue section `## From the last review` whole** (rc.17). It holds:
  - what is still open, if the run ended `DONE`;
  - always, the findings located only in material, and the questions an EARLIER run put that still
    wait. Questions put outside a run, like `-2` and `-3`, are not written there.

  The Stop hook does not count this section. See question 1 above.
- **The Stop hook holds a session while a run is open** (rc.11), not only while the queue has open
  lines. Stopping mid-run leaves the run open and resumable. `gbg run abandon` drops findings, and is
  the owner's word only.
- **Abandoning** keeps what was fixed and twice verified on the record (rc.15). A run that launched
  nothing is deleted whole, and what it carried goes back to the run before it (rc.16).
- **Records.** A run record gains `dropped`, `unreverted`, `silent` and `rulebook`; a finding gains
  `in_material`; a location gains `at`. Records written by rc.10 read as before. Before rc.22, every
  stage and every answer erased `rulebook`; a record now keeps it.

**No run has yet been taken to its close over real agents.** PF's first run was abandoned at verify,
and most of the fixes above came from it. Report what breaks rather than working around it.

## Reporting a defect in this package

A tool defect, or a discipline the catalogue lacks, is a tracked file in PF:
`.gbg/requests/to-GBGCodingTools-<date>-<topic>.md`, with a status paragraph on top, deleted when it is
concluded. That is the whole channel. Never an edit in this package's repository from PF's session, and
never a change in PF made to satisfy a finding you believe is wrong.
