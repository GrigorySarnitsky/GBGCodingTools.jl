# Changelog

Every tag has one entry: version, date, and MAJOR | MINOR | PATCH. Entries up to 1.0.0-rc.11 also
carry "instruments affected" and "rates comparable", which the 2.0.0 line drops: the instruments are
being rebuilt, and nothing measures a recall rate any more.

## 2.0.0-rc.35 — 2026-09-28

PATCH, four tool defects that rehearsing and verifying GBGHomogeneousTurbulence's first wiring found:

- **`gbg bump` prints a command that works on a first wiring.** It printed `Pkg.update("GBGCodingTools")`
  for both environments, which fails where no manifest holds the tool yet ("expected package to be
  registered"). It now prints an update where a manifest holds the tool, a resolve where none does, and
  nothing for a test environment with no manifest, which `Pkg.test()` resolves itself.
- **RULE.DOC.SIGNATURE_FIDELITY strips a precomposed hat.** `û` (U+00FB, the spelling Julia's normalised
  identifiers hold) was not read as `u`, so `f(û)` over the method `f(u)` was reported.
- **RULE.DOC.XLINK judges the first mention, as its statement says.** A name linked anywhere in the
  docstring counted as linked, so a bare first mention with a later link was never reported.
- **RULE.DOC.LINK_UNIFORMITY's message** names the names, not `SubString{String}[…]`.

Measured: GBGHomogeneousTurbulence loses 1 false finding and gains 6 genuine ones; GBGPeriodicFields'
counts under the three rules are unchanged at 0.

## 2.0.0-rc.34 — 2026-09-28

MINOR, three rulings of the owner's (2026-09-28), which change what a package's documentation must say:

- **Field lists are a `# Fields` section**, one bullet per field, compared with the struct: every bullet
  a real field and every field a bullet. A sentence "The fields are …" is no such section.
- **Argument lists are an `# Arguments` section** wherever the bulleted form is required (three or more
  arguments, or any keyword). Fewer are still bound in prose, "The arguments are `a`, the first, and `b`,
  the second." A type whose `# Fields` section documents its fields is exempt.
- **A work with no DOI links its stable public record**: an entry that says "no DOI" may carry on its
  title an https link to the work's public record (NASA's technical-report server, an institute's page).

Measured with the new rules: GBGPeriodicFields 54 argument lists and 25 field lists to convert;
GBGHomogeneousTurbulence 41 and 4 (its other 29 `# Fields` sections, of 33, pass);
GBGStreamingStatistics 23 and 2; GBGCloudPhysics 61 and 27. This package's own 154 docstrings are
converted.

## 2.0.0-rc.33 — 2026-09-28

PATCH. **This package loads on Julia 1.13.** It reads source with the parser bundled with the Julia that
runs, and 1.13's renames and reshapes a macro call's name (`MacroName` → a `macro_name` node,
`StringMacroName` → `StrMacroName`); naming a kind the parser lacks is an error when the package loads, so
every consumer whose workflow runs `version: '1'` had a docs build that died before any check. Macro names
are now read through one helper that knows both, and the witness runner handles 1.13's `Test`, whose print
switch became a `ScopedValue`. CI's matrix gains the newest Julia. Found by GBGPeriodicFields, whose docs
deploy stopped. Also in this candidate: the six defects the verification of HT's findings found (a
sibling's name inside a link target, argument coverage, finding lines inside a wrapped run, the `[doi:…]`
label form, the rendered signature width, `gbg check`'s summary).

## 2.0.0-rc.32 — 2026-09-28

PATCH, four defects the rehearsal of GBGHomogeneousTurbulence's first wiring found:

- **A wiring finding names what fixes it.** Every one said "run `gbg sync`", which writes none of a
  package's `docs/make.jl`, `test/runtests.jl` or workflows; those now say to edit the file.
- **`docs/src/gbg.md`, the tooling page a build writes, is in the managed ignore block.**
- `RULE.DOC.HOME_ORDER`'s why claimed a check the prose-shape rule does not make; corrected.
- This package's `make.jl` guarded its deploy with a condition that could never hold; removed.

## 2.0.0-rc.31 — 2026-09-28

PATCH, two defects GBGPeriodicFields reported upgrading to rc.30:

- **A docstring's signature block is read across the blank lines between its signatures.** It stopped at
  the first blank line, so `RULE.DOC.SIGNATURE_FIDELITY`, `ARGCOV` and `ARGS_FORM` never read a later
  signature: a keyword it showed was reported missing, and a stale name there passed.
- **`RULE.TEX.MATHBB` says what KaTeX renders:** blackboard bold only on a capital letter or `k`, and the
  identity written `\mathbf{1}`. It told authors to write `\mathbb{1}`, which renders as a plain 1.

## 2.0.0-rc.30 — 2026-09-27

MINOR, the owner's answers to the review's open questions:

- **`RULE.TEX.LEFTRIGHT`: `\left` and `\right` are banned**, except in a formula a package lists in the
  new `leftright_allowed` setting — each exactly, on the owner's answer. A package using them elsewhere
  gets a finding per formula.
- **`RULE.GIT.TRAILER` restored to the ruling of 2026-09-08**: every commit ends with exactly
  `Co-Authored-By: Anthropic Claude <noreply@anthropic.com>`, no versioned trailer and no Claude-Session
  line. rc.27 had loosened it to any Co-Authored-By line.
- **`gbg bump` checks nothing before moving the pin**: its pre-check ran the old version's rules and could
  refuse nothing; the next build under the new version judges the package.
- A consumer's build or test may start a child Julia process; what it may not read is git state, review
  state or the network.

## 2.0.0-rc.29 — 2026-09-27

PATCH, two false positives in `RULE.DOC.XLINK`, found by the first run of the rules the review brought to
life over a real package (GBGPeriodicFields, 173 findings at rc.28). The file's module was taken from any
line reading `module <word>`, so a docstring's prose "module for what …" named a module `for`; and a
standard-library generic a package module extends (`norm`, `dot`, `mul!`) was credited to that module,
so every sibling's mention of `norm` was reported. PF's count falls to 112, each read as genuine.

## 2.0.0-rc.28 — 2026-09-27

MINOR: **the full code review.** Eight independent reviewers read the whole tree; 143 findings, each
recorded with its fate in `docs/design-record/code-review-2026-09-26.md`: 138 fixed, 1 refused, 4 left to
the owner. Four verifiers then re-ran every fix's failing input: 12 fixes were incomplete and 17 more
defects were found, all fixed. What a consumer meets:

- **Rules that had been blind now read:** `RULE.DOC.API_GROUPING` (it looked for markup Documenter 1.x
  does not emit), `RULE.DOC.XLINK` and `RULE.DOC.SIGNATURE_FIDELITY` (they read no file under a real
  config). A package may see new findings from them: a docstring's displayed signature that no longer
  matches its method is one, fixed as documentation.
- **`gbg sync` and `gbg init` no longer overwrite a package's own file** at a generated path; they list it
  and exit 1. `write_pin` keeps `[targets]`; a broken `settings.json` is exit 2.
- **A review run:** the find stage's driver carries its arguments (it did not since rc.24); cost counts
  each message once; a relaunched stage relaunches only the missing roles; questions put inside a run pass
  the language rules; the prose allowance inside a run reaches the site build.
- **Config:** positional constructor calls, repeated keywords, bad `v"…"`/`r"…"`, a setting naming a
  parameter its rule lacks, are each one ConfigError line (exit 2). A ruling containing `$` no longer
  makes `.gbg/settled.jl` unreadable. A package's `PatternRule`s now run.
- `Harness.test(root; extra = …)` adds rules to the rulebook's instead of replacing them.
- The gitignore grammar reads `**`, escapes and nested files as git does.

## 2.0.0-rc.27 — 2026-09-26

MINOR: **Phase 5, everything before GBGHomogeneousTurbulence.** The third stroke is deleted — `Scan.jl`,
`Reflection.jl`, `DocLints.jl`, `HtmlWalker.jl`, `TreeHash.jl`, the old `Config` and `Ledger`, `.gbg/config.toml`,
`catalog/` — with the verbs `config`, `probe` and `scan`; what still had a reader was harvested (the derived public
surface into `TestHarness`, the tree hash into `Self.jl`). `makedocs` takes the package ROOT and nothing else.

**The git rules are programs.** `RULE.GIT.CI_MANUAL`, `MANIFEST_TRACKED` and `REQUESTS` run in every test suite from
the files: a test workflow fires on `workflow_dispatch` and release tags alone, every sub-environment manifest is
ignored (a tracked root manifest is declared by a file-scoped switch), a request is `to-<PKG>-<date>-<topic>.md`
opening with `Status:`. `RULE.GIT.BRANCH`, `PUSH` and `TRAILER` are checked by the Stop hook, on what is not yet
pushed — the hook `gbg sync` writes carries each rule's own lines, and `gbg check` runs the same lines; a build never
does. The rulebook says beside each that a hook check is weaker than a build check. `TRAILER` now reads "carries a
`Co-Authored-By: … <noreply@anthropic.com>` trailer". `NO_SHIMS` stays an instruction.

**The four harness contracts bind a package that declares them** by calling the contract from its suite; a package
that has not is not bound. A package's switches on them that only said "no such storage here" are moot.

**The deferral.** `Deferral(rule = …, until = …)` in `.gbg/config.jl`: the rule is owed here and not yet met, with
what would close it. It reports nothing in a build or test, fails neither, is rendered beside the switches on the
package's site and in its rulebook, and printed by `gbg check`. A switch on the same rule is refused.

**A retired rule states its fate**, MOVED to a design section that must exist or OBSOLETE. `gbg release --counts`
prints what still holds `v2.0.0` — 0. Also fixed: a file under an excluded directory is excluded whatever a nested
`.gitignore` says, as git decides it.

## 2.0.0-rc.26 — 2026-09-26

PATCH, one ruling on PF's item 7: nine cross-references that resolve to nothing were committed under
`docfix check --no-build` over eighty commits and surfaced together at the verify stage's build, with no word on which
commits made them. **A red build at `gbg run next` now names the pass's commits that touched the files it complains
about.** And **`docfix check` and `commit` warn of every `@ref` they cannot resolve** among the package's documented
names, headings and `@id`s — a warning, never a refusal, since only Documenter resolves a reference exactly. A build
per commit was considered and declined: a minute per fix, two hours per pass on GBGPeriodicFields.

## 2.0.0-rc.25 — 2026-09-26

PATCH, one ruling. **Inside a run, a unit of prose may grow by a small allowance** (ruled 2026-09-26, PF's item 5): ten
words, or five percent of its recorded count where that is more, on the unit and on its longest paragraph. A fix that
had to ADD a qualifier to be correct was refused for one word and paid for it by cutting elsewhere. Outside a run the
ratchet is strict, and the close re-records what grew, with the run's record, so the growth is one visible commit.

## 2.0.0-rc.24 — 2026-09-26

MINOR. **Verification rebuilt on the measurements of GBGPeriodicFields' first full review** (run
`2026-09-24-documentation-review-01`, 37 items reported), and the defects it met fixed. Upgrade before the next review.

**One verifier per place, with the diff, one pass** (ruled 2026-09-26). Pass 1 of that review launched 187 verifiers,
each starting at ~146k tokens of fixed context, for $349 against $52 for the whole reading stage; the blind stage was
wrong on 47% of its not-fixed verdicts and the diff stage made the one real catch; a second pass re-verified unchanged
text and moved 22% of verdicts by variance for $118. Now the open findings are grouped by the unit they sit in and ONE
verifier per unit (at most ten findings) judges them all, with the unit as it now stands and the diff of the pass, and
answers each by id; the `diff` stage is gone, a pass is `fix → verify → collect`, and the budget is one pass. A fix
stage that committed nothing closes the run instead of verifying unchanged text.

**What a verifier could not see, and what the grade lost.** The page text shows a link as `[text](target)`, so a term
fixed by linking it to its definition no longer reads as the unfixed text (ten findings failed that way). A quote of
two spans joined by "…" holds when each span does. The driver returns each agent's validated result, the session saves
it as `returned.json` beside the results, and the collect falls back on it for a role whose own file never appeared
(three FIXED verdicts were counted silent). A demotion — quote not in the text, no answer, a verdict outside the list —
is written on the `DocFix` as `note`, not only printed. A pass's fixes are the commits since the pass began
(`Run.pass_since`), so a later pass no longer shows the earlier pass's commit on every finding.

**Cost is recorded.** `gbg run cost <dir>` sums each agent's own usage from the launch's transcripts into the record
(`Run.usage`), per stage and pass, and the report prints the table. The launch's summary field counted a tenth of the
real cost — 17.9M reported against 164.6M measured — and nothing recorded a cost at all.

**Parked findings.** A parked finding's question offers `I make the change` (the owner's; his list), `fix it on my
ruling` (the fixer's again, with his `--direction`; a verifier then closes it; `docfix commit --finding` accepts the id)
and `not a defect`. Question ids are `<finding>-code`, no longer with the run's id doubled in front.

**The program checks and the guard.** `gbg docfix commit` refuses a change that breaks a rule the run opened clean on,
where `check` reported it and `commit` went ahead. A Literate `#md # …` line's prose may change, as any Markdown line's
may. `RULE.DOC.SHAPE` counts a formula as one word however it is laid out, and no lone dash. `RULE.TEX.CODE_SPAN_JULIA`
is reworded on PF's request: a code span holds literal code or input in any language, and never mathematics.

**Verbs.** `gbg run <verb> --help` prints usage and acts on nothing (`abandon --help` abandoned a run). `gbg run next`
and `collect` name the pass. Abandoning a run keeps the text of what it dropped, marked `dropped_ids`, so a triage can
name it; nothing dropped is carried. The driver copy a run places has the stage's arguments spliced in, so the launch
passes no args. `gbg check --rebaseline --unit <name>` re-records the named units alone. The record's two hand-written
field lists are gone: `with` and `with_questions` copy every field off the type, having dropped `rulebook`.

**Not changed, by ruling:** a moved formula is still a change the guard refuses, and a new comment line in a Literate
example is still code; both are parked. The rulebook stays imported into every package's `CLAUDE.md`.

## 2.0.0-rc.23 — 2026-09-24

MINOR, one ruling. **The program checks read a package's design documents by default** (ruled 2026-09-24): the
rationale set's default is every Markdown file directly under `docs/`, where it was none. Deterministic checks are cheap
and carry no risk of an agent's misreading, so a package that declares nothing now has its design documents held to the
LaTeX, citation and structure rules, where only the reader agents saw its architecture document before. Which of them a
READER is given is unchanged: `architecture_doc` and `material` decide it. **A package that declares no rationale set
may meet new findings at its next build**, in its own design documents; one that declares a set is unaffected. Here,
35 were found in `docs/ARCHITECTURE.md` and `docs/PF-WIRING.md`: six fixed, and the paragraph lengths re-baselined.

**The guard refused a fix to `docs/ARCHITECTURE.md` in every package that declared no rationale set**, although that
document is a target of the review: it compared the set's raw entries, with no default. It reads the set by pattern and
with its default now, as every other file set is read.

## 2.0.0-rc.22 — 2026-09-24

MINOR, one ruling. **`gbg run park <id> --why "…"` hands a finding to the owner at the fix stage** (ruled
2026-09-24). A finding whose fix only the owner may make — a change to the config, to code or to a formula — could be
neither committed nor verified. Left open, it cost a verifier every pass and reached the owner only at close; and the
fixer's `gbg ask` put a question that was tied to no finding. Parking puts the question a `HIDES_CODE_DEFECT` verdict
puts, under the finding's own id: no pass works on it, `gbg ask` and the work queue list it, and "fix the code" puts it
on the owner's list while "not a defect" closes it. The review's skill and the fix stage's handoff name the verb.

**The run record kept losing its `rulebook` digest.** Two helpers rebuilt the record from a list of fields written by
hand, and neither named `rulebook`, added in rc.17, so every stage and every answer erased the digest that
`--scope changed` compares, and such a run fell back to comparing versions. Both take the fields from the type now, and
a test holds them to every field.

## 2.0.0-rc.21 — 2026-09-24

PATCH. **The review's skill said two things the tool no longer does**, and a session follows the skill.

- **Its launch step named the pinned package's `drivers/run.js`**, which `Workflow` refuses because it lies outside the
  working directory; since rc.9 a run copies the driver into its own scratch and prints the call to make. The step now
  says to make the call the verb printed.
- **Its formula rule said never to change what is inside a math span**, without the one respelling the guard allows:
  a code span turned into a math span with the same text, or back.

Found by the adversarial passes over GBGPeriodicFields' upgrade document.

## 2.0.0-rc.20 — 2026-09-24

PATCH. Two defects on the one tooling page a consumer's site carries, found rehearsing GBGPeriodicFields'
upgrade. **Upgrade before the next docs build is published.**

- **Its link to the rulebook answered 404.** It pointed at the site's root, and Documenter publishes under a version
  directory: `dev/` from `master`, and `stable/` only once a release is tagged. It points at `dev/gbg-rules/` now.
- **A switch's reason kept its line continuations.** A string in `.gbg/config.jl` was read by unquoting its source
  text, so a reason written over several lines with `\`-newline kept every `\` and the indent after it — on the
  consumer's page and in its `switches.md`. A string's value is now what the parser gives, which is what Julia
  evaluates; triple-quoted strings, which the old reading also got wrong, come out right too.

## 2.0.0-rc.19 — 2026-09-24

PATCH. **`gbg bump` crashed after doing its work.** It wrote the pin and every generated file, printed the list, and
then died on its closing message — the one saying what is not yet finished — with a `MethodError` and exit 3, because
the message was written for a version string and handed a version number. Every bump from rc.9 to rc.18 did this; no test ran
`bump` to its end, and one does now. Found rehearsing GBGPeriodicFields' upgrade on a clone. A bump RUN BY an older
version still crashes this way, since the running code is the one it is moving away from: the files are written, and
the upgrade goes on.

## 2.0.0-rc.18 — 2026-09-24

PATCH, one ruling. **In a Literate example, `#` and `##` may be turned into each other by a documentation fix**
(ruled 2026-09-24). `RULE.DOC.LITERATE` asks for a comment inside a loop to be written `##`, and under the simple
rule that change of a comment's kind was code, so every such finding went to the owner. Which one a line is decides
only whether it shows on the page; a code chunk it splits is caught by the docs build, which a run must pass to close.
The first `#` stays, so a comment can be neither removed nor turned into a mark such as `#md` or `#src`.

## 2.0.0-rc.17 — 2026-09-24

PATCH. **Upgrade before running a review.** A run record gains `rulebook`, and a location gains `at`;
older records read as before. Nothing a consumer must change in its config.

**The run path, reviewed and fixed** — about fifty defects found by a review of every step a review run
takes, each reproduced, most of them on GBGPeriodicFields; then a second review of those fixes, whose
nineteen findings are fixed here too.

- *The change guard* follows two simple rules the owner chose: mathematics is what Documenter renders as
  a formula, and a `.jl` file may change only inside the text of its existing docstrings and comments.
- *The stage machine* loses nothing between steps:
  - A finding the owner asked to have fixed in the code goes on the owner's list in the work queue.
  - An answer is checked before anything is recorded, and re-making reverted edits is all or none.
  - "Not a defect" for the open run's own question is settled when the run closes, and any other answer
    that would write the settled list waits for the close.
  - A silent agent is launched again once per stage and pass, a later pass never reads an earlier one's
    results, and a silent reader leaves the run unevaluated.
  - A waiting question stays on the queue whether or not the run ended evaluated.
- *Placing a finding* finds a quote first as the source spells it and then as the built page reads it
  (markup, wraps, escaped backslashes, Literate's comment marks):
  - A Literate page is its example, through Documenter's `EditURL`.
  - The node walker names every definition by its callee.
  - A line is mapped through git once, from the commit it was read at, and never from line 0.
  - On twenty real page quotes, 8 were placed right before and 20 are now.
- *What each agent is given*:
  - A Literate example's source is a unit of its own for `RULE.DOC.LITERATE`.
  - The page text keeps code and blocks.
  - A verifier is given what its reader was, and a diff verifier every commit of the fix.
  - Per-file switches reach readers.
  - Duplicate findings under one rule at one quote are merged, every reader's claim and fix kept.
  - `--scope changed` sees deletions and build-script changes, and compares a digest of the rulebook, the
    readers and the driver instead of a version.

## 2.0.0-rc.16 — 2026-09-23

PATCH, one ruling.

**Abandoning a run that launched nothing deletes it whole, carried findings included** (ruled 2026-09-23, decision 14;
supersedes 2026-09-22). Such a run has no standing over findings it never looked at: every finding it holds was carried
from the run that found them, and with its record gone the next start reads past it to that run and carries them
again. Before, the record stayed and its `dropped` count ended the chain — the previous run's leftovers were lost by a
run that had read nothing, and the report said something had been seen and nobody stood behind it.

## 2.0.0-rc.15 — 2026-09-23

PATCH. **Upgrade before running a review**: rc.13 and rc.14 do not route a working-notes finding correctly past the
first fix pass. Nothing a consumer must change in its config.

**Twelve defects in rc.11–rc.14, found by three independent reviewers of that day's diff and each reproduced.** The
targets-and-material design of rc.13 did not hold where it mattered most: the fix stage and the carry-over rebuilt a
finding field by field and dropped `in_material`, so a finding in the working notes became the fixer's on the first
pass (`Model.relocated` now carries every field, and a pre-ruling record's findings are re-classified when carried);
the copy-finder still extended a finding into the working notes; `--scope changed` still relaunched every whole-corpus
reader when a decision log changed, and never re-read the architecture page; `architecture_doc` honoured a setting on
only one of its two rules; `in_material` meant "in no target", so an absolute path, a `./` prefix, a README or a test
file routed a finding to the owner as working notes (paths are normalised now, a copy resolves to its source, and
material means material); the architecture document was a target the readers were not handed unless the rationale set
named it; the rendered reader was pointed at the whole built site, working notes included, and now gets the kept pages
by name. Elsewhere: `abandon` counted a fixed and twice-verified finding as thrown away (it keeps those on the record
now); `gbg docfix check`, which the fix stage tells the session to run before every commit, was red for every edit
while a run was open because it did not look past the run's record and the queue as `commit` does, and the two now
share one list; an arguments file written before rc.13's wire shape was misread as silence rather than refused; and the
driver key-coverage test passed for one field by substring. **The figures in rc.13's entry were wrong**: measured on
GBGPeriodicFields' build, the withheld reader launches over 16 pages, not 18, and what each whole-corpus reader stops
being handed is about 164,000 tokens; "35,000", "212,000" and "72 percent" measured nothing, and a role costs about
130 bytes with a real run id, not 95. The rc.13 entry is corrected in place.

## 2.0.0-rc.14 — 2026-09-23

PATCH. **`RULE.CIT.RESOLVES` no longer reads a `[` inside a math span as a link opening**, the last open item of
GBGPeriodicFields' request of 2026-09-22. The unwrapper joined hard-wrapped lines until brackets balanced and counted
brackets it had not masked, so the `[` of a half-open interval written ``[a, b)`` absorbed eighteen lines across two
paragraphs, up to the next reference's `]`, and a correct DOI was reported as resolving to the wrong title. A blank
line now ends a logical line, and brackets inside code and math spans do not count. The math-span mask is separate
from the code-span mask, because the LaTeX rules read their mathematics inside exactly those spans.

## 2.0.0-rc.13 — 2026-09-23

PATCH. Nothing a consumer must change; `material` is optional and empty by default.

**Targets and material** (ruled 2026-09-23). The review is for the text a user reads. Agents are now given TARGETS —
docstrings, the hand-written pages, the Literate examples, and the one document `architecture_doc` names — and a
finding may be located only there; only a target is ever handed to the fixer. MATERIAL is what a reader may open to
judge a target and never report on: the source, plus what a package lists in the new config field `material`, empty by
default. Every other rationale document is read by nobody unless listed. The site walk keeps only target pages, so the
copies a build makes of the working notes are never launched over; the collect marks a finding located only in
material and routes it to the owner in its own section of the report, unfixed and unverified, because it may be the
formula three docstrings copy; `gbg docfix commit --finding` refuses an edit to such a document. Program checks are
untouched. On GBGPeriodicFields, measured through the walk on its build: the withheld reader launches over 16 pages, the
architecture page among them, and the full reader and each discipline stop being handed four documents of about
164,000 tokens under two cold-read rules that had been ruled not to apply to them. [Figures corrected in rc.15; this
entry first said 18 launches and 35,000 tokens, which measured nothing.] `docs/PF-WIRING.md` says what, if anything, a consumer adds.

**The launch's arguments carry only what is each role's own.** The shared fields of a stage's roles go once into a
`kinds` table, the two directories once into `dirs`, and the file is written compact; a role is six short fields and
about 130 bytes with a real run id in its keys. A verify stage of 142 findings is about 19 KB whether the findings are
40 characters or 40,000, and
`test/driver.jl` now holds both properties — the size does not depend on what the agents read, and a role's marginal
cost is bounded — so this cannot grow back unnoticed. The gate found the pretty-printing on its first run.

## 2.0.0-rc.12 — 2026-09-23

PATCH, one ruling. **Upgrade before the next docs build**: the three pages a consumer's `docs/make.jl` lists are gone.

**Nothing of the tool on a consumer's main pages** (ruled 2026-09-23). GBGCodingTools is the instrument of the
packages' developer, and its workings are of no concern to the packages' users — yet three of the ten top-level
entries on GBGPeriodicFields' site were the rulebook, a reader roster and an instrument list, and the first was 45 KB
of tooling prose on a physics library's site. `Render.pages` now writes ONE small page, `gbg.md`, for the site's design
or internals section: what the documentation is held to, a link to this package's own site where the rulebook lives, and
the package's switches with their reasons. The readers page and the instruments page are deleted. The rulebook is still
published, by the new `Render.rulebook_page`, on this package's own site alone, where a consumer's page and any finding
link to a rule by its id. **A consumer's `docs/make.jl`, `generated` list and `.gitignore` change on upgrade**;
`docs/PF-WIRING.md` says exactly how.

## 2.0.0-rc.11 — 2026-09-23

PATCH, and everything in it comes from GBGPeriodicFields running the documentation review over real
agents. **Upgrade if you are going to run one.**

**A stopped run reported itself clean.** Abandoning empties a run's list of findings and leaves its
launch count alone, so a run that found a hundred and forty-two and was stopped looked, in its own
record, exactly like one that read everything and found nothing — and its report said so, under the
provenance banner, on a page anyone may open. This is the THIRD reading of the same failure; the first
two were fixed in rc.10 and this one was left standing. The record now carries `dropped`, the count
that was thrown away, and the report has a branch that says what happened. The record's round trip is
gated too: its writer and its reader are written by hand side by side, nothing made them agree, and a
field that reaches one and not the other is silently the default on the next load with no test failing.

**A docstring on a bare name was code.** The change guard dropped a docstring only when its target was
a definition, so `"""…""" mean` above methods written one per backend — the way a whole generic is
documented — made every edit to that prose wait for the owner. Nineteen targets in GBGPeriodicFields,
every operator of its field algebra and every reduction; NONE in GBGCodingTools, which documents no
generic that way. Removing such a docstring leaves the name alone, which runs nothing, so the edit is
documentation. A docstring on a CALL still is not, for the reason it never was.

**Launching a stage cost the session half a megabyte.** A workflow script has no filesystem, so the
session cannot hand the driver a path: it types the arguments into the launching call, and every byte
of that file is a byte of its context. A stage's instruction to its verifiers and the standpoint a
reader carries are the same text for every role that shares them, and written per role one paragraph
became a hundred and forty copies; they move to a table, each once. The finding a verifier judges and
the diff of the fix made for it are the bulk of the file and no part of it is the script's to read, so
both are now written beside the arguments and passed as PATHS, which is what a reader given one built
page has always been given.

**The work queue and the fixer were fighting.** The queue is the session's note of what it still owes,
and the end-of-turn hook reads it to keep a session walking a run to its end — so it is most useful
while a run is open. But `gbg docfix commit` classifies every changed file and refuses the whole commit
if one is code, and the queue was code, so writing one line into it made every remaining fix of that
pass uncommittable. The queue joins the run's own record on the list the fixer looks past, and the
close now names it when it is dirty.

**A fix committed without its finding is never verified.** The pass machinery is keyed on that trailer:
the diff verifier is handed the diff of the commits naming its finding, and a fix called worse is
reverted by reverting them. So while a run is open `gbg docfix commit` REFUSES without `--finding`; a
change belonging to no finding waits for the close. The fix stage also now prints `gbg docfix check`
above the commit — a refused commit costs one edit to understand, and a pass of them costs the pass.

**The two cold-read rules no longer hold a design document to a cold read** (ruled 2026-09-23, from GBGPeriodicFields's
first real review). `RULE.DOC.TERMS_DEFINED` and `RULE.DOC.SELF_CONTAINED` ask whether a text stands alone, which is
the right question for a docstring — somebody genuinely meets one at the REPL — and for a page a reader arrives at
from outside. It is the wrong question for a document that exists to explain one architecture and may assume the rest
of itself: satisfying it means re-binding the same vocabulary on every page, which is what the one-home rule forbids.
Both now name a parameter, `architecture_doc`, defaulting to `docs/ARCHITECTURE.md`: that one rationale document is
still held to a cold read, since it carries the requirement itself, and every other is exempt. A DEFAULT rather than
a switch each package writes, because every package that opts its design documents in meets this, and a default
nobody finds until it hurts is not a default. The volume says the same: of that review's locations, the rationale
documents carried 75 of 194 for one rule and 159 of 272 for the other.

**A RE-BASELINE IS A CLOSING STEP, never a fix pass's** (ruled 2026-09-23). Some of a review's fixes ADD information
no rewording returns — binding a term defined nowhere, writing a form out because the compressed one was not valid
code — and those raise the prose-shape numbers a package is held to. Those numbers are a tracked file, so raising one
inside a run is a code change that would end the run unevaluable, and the ratchet exists so a raise is deliberate. So
the run closes first and the raise is a separate commit with its reason: one diff a person reads, rather than a
number slipped through under cover of a fix. Most such findings need no raise — of the 28 that tripped on the first
real review, four fifths were the fixer's own verbosity and came back inside budget by writing tersely.

**A Literate example was readable and unfixable.** Two rules judge one, and the change guard's path list admitted
no file under `examples/`, so every finding on one could only park on the owner's queue. Reported by
GBGPeriodicFields, which had a verified fix it could not commit. The hole was not its own: the DEFAULT pattern is
`examples/**/*.jl`, so every package with an examples directory had it whether or not it declared the set. The path
list now matches the Literate patterns, and NOTHING downstream changed, because nothing downstream was wrong — a
Literate file is not a third kind of thing beside documentation and code, it is a `.jl` file, and the clauses after
the path already decide per CHANGE: clause 2 parses both versions and refuses any change to the code itself, clause 4
refuses a change that moves a Literate mark, clause 5 an executed block. A comment may be edited in such a file and a
statement may not, and that is settled by Julia's own parser rather than by guessing what a `#` means.

**The stop hook holds a session open while a RUN is open**, not only while the work queue is. A run is walked stage
by stage BY THE SESSION, since Julia cannot launch an agent, so a session that stops in the middle has spent its
agents for nothing and left a run that blocks the next one — and the queue cannot catch it, because a run writes its
queue lines at CLOSE, the point it has not reached. The hook's own comment had recorded the general failure for
months: stopping to narrate is stopping. Abandoning is NOT offered as the way out, and the message warns against it:
it drops the findings, and a session looking for a way to end its turn would take it. A session that cannot go on
leaves the run OPEN and says where it stands; the next one continues it, and a stage whose agents answered is not
relaunched. The loop guard is untouched, so a session already held is never blocked twice.

**The built-page walk could not hear what the package had declared**, and that one omission caused three faults at
once. It took a directory and no config, while the file surfaces dropped both generated pages and declared copies in
a single filter with the reason written beside them. Found on GBGPeriodicFields's first real run: 26 readers, 142
findings.

**Readers were launched against the pages that state the rulebook.** Three of them, returning seventeen findings
against text that quotes every banned spelling in order to ban it — the exact waste `generated` exists to prevent,
and which the file surfaces had always prevented.

**A rationale document and its build-time copy were read as two places.** Thirty-one findings of that run cited a
source and its copy as separate locations, so the corpus was read twice and a reader's cap spent twice on one page;
four cited ONLY the copy, where a fix lands in output the next build overwrites. The walk now skips a copy's page,
and where a copy is read through the site anyway, a finding is reported under the SOURCE — the file the text is
written in, and the one a fix survives in.

**The change guard now refuses a generated path**, as it already refused a copy and a normative document, and for
both of that pair's reasons: a fix there is gone at the next build, and the page is by construction full of the
violations it documents. It was missing, so a fix to one of those three pages would have been accepted.

## 2.0.0-rc.10 — 2026-09-22

**A run that launched nothing said the package was clean.** Both runs GBGPeriodicFields abandoned wrote "Every reader
wrote its file and none of them reported a defect" three lines below a sentence saying 0 agents had launched. That is
the dead-lane-read-as-clean failure the instrument exists to prevent, in the instrument's own output, under the
provenance banner, on a page anyone may open — a document asserting a package was read and found clean when it was
never read is worse than no document. The report now says "Nothing was read", and says the run says NOTHING about the
package: not that it is clean, not that it is not. The distinction is drawn on whether an AGENT RAN, not on how the
run ended, since a run stopped after its readers reported is a different thing from one that never launched.

**What abandoning a run leaves behind now turns on whether there is anything in it** (ruled 2026-09-22, on
GBGPeriodicFields's question after two abandoned runs left it with no rule to follow). A run that launched NO agent
and was CARRYING nothing is deleted outright, record and all, and its id is free again: it read nothing, carried
nothing and changed nothing, so what it would leave is a record saying a run happened beside a page saying nothing
happened in it. Everything else keeps its record and report, and the session commits them like a closed run's —
whether a package was reviewed and what came of it is answered from the repository or not at all, and an escape that
leaves a committed artifact survives while one that leaves nothing gets quietly disabled.

**Two cases keep the record, and the second is the one that nearly went wrong.** A run whose AGENTS RAN: they read
the package, and that they were stopped, with whatever they had found, is evidence about it. And a run that launched
nothing but was CARRYING findings from the last closed run: abandoning it DROPS those findings, and the record is what
makes the drop stick — delete it and the next run reads past it to the run before, and the dropped findings come
back. The first draft of this rule deleted on launches alone and the rehearsal caught exactly that, within the hour.
`gbg run abandon` says which case it took; the generated protocol states both.

## 2.0.0-rc.9 — 2026-09-22

**SECOND BLOCKER FIXED: the driver could not write a result file.** rc.8 parsed and then failed at the next step —
`const fs = await import('node:fs/promises')`, which a workflow script may not do: it has no filesystem and no Node
API, and `import()` is refused outright, so there is no spelling of that function that works. It was the only
filesystem use in the file and the load-bearing one: every role's findings went through it, so the collector read
files the driver was structurally unable to write, and no stage of any instrument could ever have completed. Found by
GBGPeriodicFields at rc.8, which again declined to patch a pinned file.

**The agent writes its own result file**, which is what that session proposed and is better than returning the
findings up to the session. The property the old code protected is kept: the collector stays a separate program
reading files minutes later, and a session carrying every finding out of a workflow's return value would be the
courier for the thing the guard exists to check. The agent has file tools; the driver hands it the path, and it both
WRITES the file and RETURNS the object, so a role returning nothing is still named silent and a file that never
appeared is named by the collect.

**A gate for what the SANDBOX refuses, which is a different question from whether the file is JavaScript.** Both
launch-blocking defects of this week lived in that gap: one was invalid JavaScript, the other was valid JavaScript
the sandbox will not run. `test/driver.jl` now checks the driver, with comments stripped, for `import(`, `require(`,
a `node:` specifier, `process.`, and the three constructs that break resume — `Date.now()`, `Math.random()` and an
argless `new Date()`. Comments are stripped because this file explains those restrictions and would otherwise flag
its own explanation, the same collision as a field named `discipline` against a ban on `line:`. The three
resume-breaking constructs are absent, so no third blocker of that kind is waiting.

**The three findings GBGPeriodicFields reported with the driver defect are fixed.** All three were met on the first
real upgrade and the first real run, and each would have met every other consumer in turn.

**A run places its own driver, and records which one it used.** The `Workflow` tool refuses a script outside the
working directory, so the pinned `~/.julia/packages/…/drivers/run.js` could never be named directly — every consumer
would have discovered that and copied the file by hand, as PF did, with nothing recording which driver had actually
run. `gbg run` now copies it byte for byte into the run's own scratch, prints the path and the `Workflow({scriptPath:
…})` call to make, and writes the driver's SHA-256 into the run record.

**`gbg bump` says that it has not finished.** The pin moves first and the regeneration follows, but the regeneration
runs on the code that is LOADED — still the old version, since the manifests have not moved — so every file it writes
is the old version's content under the new version's banner. PF got sixteen paths where twenty were due, without the
new rulebook file or three skills, and the drift is invisible until a build runs the wiring check. It cannot be fixed
by regenerating harder: the right content does not exist in that process. `bump` now prints the two commands that move
the environments and tells the session to sync again under the new code.

**`Pkg.update`, not `Pkg.resolve`.** A resolve writes the new rev while KEEPING the old tree hash wherever Pkg's clone
has never fetched the tag, so the manifest reads the new version and the old code loads. Only an update fetches. Twice
now, at rc.4 and at rc.7. `docs/PF-WIRING.md` said to resolve, which is how PF met it; it now says update, is
retargeted to rc.8, and records that asking `gbg run next` for its state is what exposed both version traps.

## 2.0.0-rc.8 — 2026-09-22

**The design review is deferred to Phase 11, on request.** It stood at the end of Phase 8; the owner moved it on
2026-09-21 to reach PF and HT sooner. Nothing depends on it and deferring it leaves nothing unchecked: the rulebook's
TEXT is the rule wording study's subject, not an attack's. Two conditions are recorded on it for whenever it is built,
both from a measured failure rather than a preference — it attacks a MECHANISM and never prose, and every attacker owes
a concrete evading example, the defect that gets through and why each part of the mechanism misses it. An attack that
only collects objections converges by narrowing what the thing under attack claims, which is what seven rounds over the
six discipline texts did.

**BLOCKER FIXED: the driver did not parse, so no instrument could launch an agent.** One apostrophe inside a
single-quoted string — "read the file's changed regions" — ended the literal early, and the harness refused the script
before any agent started. Every instrument and every stage went through that one file, so all of them were dead at
rc.7. Found by the GBGPeriodicFields session on the first real run, which is the first time the driver had ever been
handed to the harness; it declined to patch a pinned file and reported it instead.

**The gate that was missing is worth more than the fix.** `test/driver.jl` read the driver for the keys it mentions
and never asked whether it was JavaScript, and no fixture run could have caught it either, since a fixture run
launches no agent. It now lexes the file for the defect's class: a single-quoted literal ended early, or left open on
its line. Not a parser — the only one available here refuses top-level `await`, which the driver legitimately uses, so
a gate built on it would reject correct files — and not a regex, which reported thirteen defects in a file that had
none, because a regex cannot tell two adjacent literals from one that closed in the wrong place. The test shows it
catching the real line and staying silent on an escaped apostrophe, an apostrophe in a comment, adjacent literals and
a template with holes.

**Phase 5's three open questions are answered** (owner, 2026-09-22), so the phase that cuts `2.0.0` builds rulings
rather than asking them. The seven git instructions split three ways: three become programs in the test suite, three
become programs in the end-of-turn hook because they read git state and so may never run in a build, and one stays an
instruction because what counts as a backward-compatibility shim is judgement. The four harness contracts stop being
fleet law in their present form — the fleet law is that SOME testing exists, while its structure, type, size and
robustness are the package's — and are reworded to bind a package that has declared the capability. The eleven
remaining instructions stay rules, the two instrument ones included.

**A third state beside applies and switched off: the DEFERRAL.** A switch says a rule does not apply, and is an
answer. A deferral says a package means to meet a rule and has not yet, and is a question with a condition on it.
Recording "not yet" as a switch buries an intention in a file nobody revisits and publishes "does not apply" where the
truth is "owed". A deferral is rendered beside the switches, printed by a verb, and never fails a build. Any rule a
package means to meet later has this shape, not only a testing one.

**A retired rule will say where its content went**, MOVED to a named design section with a test that the section
exists, or OBSOLETE and held by nothing. Today a retirement records an id, a date and a reason; eleven of the thirteen
reasons name a section and nothing asserts one is there.

**A run can read only what changed** (Phase 4d). `gbg run <instrument> --scope changed` measures from the commit that
added the record of the last finished run with the same readers — per reader combination, since a bound run says nothing
about what an open reader would find. Five conditions send it back to full and each is printed rather than silently
applied: no such closed run, one that stopped short, an uncommitted record, a moved pin, an edited config. Which readers
a change reaches follows from the reader's own two fields, the sets it reads and whether code is kept from it, so an
edited function body reaches the reader with the source beside it and not the reader given one page. A `.jl` file is
DOCSTRINGS and CODE at once, so its docstrings are compared between the base and the head: a file whose prose did not
move is a code change only.

**The rule wording study is a program** (Phase 4e), and is no longer called an attack. Three readers are given a rule's
text alone and answer what deciding it needs, whether it needs a discipline, and whether the wording left them guessing;
their agreement is the result, measured as Fleiss' kappa. A rule they split on is reported; a rule whose majority answer
differs from the tag the rulebook carries becomes a question to the owner, because a tag is code and changes on his
answer and never on a measurement. `gbg study rules --votes <file>` reports a round, exit 1 while anything is open. The
votes of the two rounds of 2026-09-19 had never been filed — the four numbers in the plan rested on a session transcript
— and are now `test/tagging/`, where the suite reproduces both.

**The fleet order is PF, HT, SS, CP.** Set by the owner on 2026-09-21, who wants the periodic fields and turbulence
packages on this one first. Phase 5 now wires HT, with an `HT-WIRING.md`, and Phase 7 takes SS and CP with the
`CP-WIRING.md`. Nothing in the order was ever a dependency: every wiring needs the rulebook and the documentation
review, and both exist. What the old order bought is recorded rather than dropped — CP was second because it shares
none of PF's habits and would expose a config assumption shaped around one package, and with HT second the two are
alike enough for such an assumption to survive both. That argument is now Phase 7's to make.

**The bug hunt, the code fixer and the change audit are deferred to a phase on request.** Phase 6 was the largest
remaining phase and nothing before or after it depends on what it builds, so Phase 7 — the last two science packages
wired, and the legacy deletions — now follows Phase 5 directly; those deletions always waited on a real documentation
review having run in each package, never on a hunt. What the deferral costs is recorded where it falls: this package
changes no code until the phase is built, so a code defect an instrument meets stays a question to the owner;
`Witnesses.jl` stays, so the legacy ceiling rests at 1; `gbg release` prints neither of its two code lines; and the
design's table marks the Bug hunt and Change audit rows future, beside the leak scan, which is how the table test reads
them.

**Phase 4e is renamed the rule wording study**, because calling it an attack imported the convergence reading of a
method this project has now measured as harmful. It converges on nothing: blind taggers are given only a rule's text
and their agreement is the result. Phase 4b is marked done, which it has been since 2026-09-21.

## 2.0.0-rc.7 — 2026-09-21

PATCH. **The question channel is wired at both ends.** A question a RUN puts lives in that run's own
record, and `gbg answer` read only `.gbg/questions.json`, so the instruction every run's report printed
— answer this with `gbg answer` — replied that no question had that id. The one escape hatch for a
documentation fix that would hide a code defect therefore ended nowhere: the fix reverted, the finding
parked, and the question written where nobody could act on it. `answer` now tries the standalone store
and then the run records, newest first, open and closed alike, and writes back to the file the record
came from, since `save` always writes the draft and `load` prefers the final record. Answering that the
reader was wrong records a settled ruling without the flag, carrying the finding's own locations, so a
later run's readers are not sent to raise it again.

And nothing in `src/` ever called `Questions.put`: only the tests did. The standalone store was written
by no verb and no instrument, so `gbg ask` always answered that nothing was waiting, `gbg answer` had
nothing to answer, and every instrument's rendered skill told a session to put a question with `gbg
ask`, which lists them. `gbg ask` now puts one when given a decision and lists when given none; its
options arrive as one value cut on `|`, because the shared option parser keeps one value per name.
Fewer than two options is refused, a notification not being a decision.

`docs/PF-WIRING.md` is rewritten for this line and targets rc.7: PF was wired at rc.5 and is clean, so
it is an upgrade document, not a wiring one.

## 2.0.0-rc.6 — 2026-09-21

MAJOR. **92 rules.** `RULE.CIT.RESOLVES` is new: every DOI or Open Library link on a title answers,
and with the work the title names — a program that reaches the network and runs only under `gbg check
--network`; `RULE.CIT.NO_INACCESSIBLE`, its reader half, no longer asks whether a link answers and is
the full reader's. Thirteen retired on the owner's word of 2026-09-21, each with its reason in
`Catalogue.RETIRED` and its id never reused: eight named machinery that no longer exists (INST
FOUR_OBJECTS, CLOSURE_LOOP, AUDIT_DISPOSED, FIX_FROM_LANES, SEEDS, FROZEN_MIDROUND, CARRY, ECONOMY) and
five stated how this tool itself behaves, which the design holds (INST WITNESS, SELF_REPORT,
AUDIT_AFTER_CODE; TEST RULE_WITH_CHECK, COUNTS_REMEASURED). A switch on a retired id stays legal.

**Every rule has one of three covers**, read off the rule and shown on every rendered rule and on the
site's rules page, which is grouped by it: checked by a program; judged by a reader given the material
its access tag names; or an instruction to the session, followed while working and checked by nothing.

The reader panel is derived from the rules (`Roles.derive`); one rule names a discipline
(COORD_FREE, differential geometry); a declared discipline is an open expert. No launch budget. The
stage machine advances by position. Agents' files under `.gbg/scratch/<run>/`, deleted at close.

**The review's fix half runs.** A documentation review's pass is `fix → verify → collect → diff →
collect`, up to four passes: `gbg run next` at `fix` re-anchors the open findings and writes them for the
session, which commits each through `gbg docfix commit --finding <id>` (a trailer the run reads back);
at `verify` one blind verifier per open finding, given what the reader that found it was given and never
the diff, answers `FIXED`, `NOT_FIXED`, `HIDES_CODE_DEFECT` or `NOT_A_DEFECT` with a quote; at `diff` a
second verifier, at economy, reads the diff of each fix called fixed and answers `FIXED`, `LINE_ONLY` or
`MADE_WORSE`. `gbg run collect` grades: a verdict whose quote is not in the text is `NOT_FIXED`;
`MADE_WORSE` reverts the fix with a guarded revert; `HIDES_CODE_DEFECT` reverts it, puts a question to
the owner and parks the finding, which no pass touches again; a fifth pass is refused and what is open
goes to `.claude/WORK_QUEUE.md`, one line each under the heading the hook does not count. `collect` now
moves the run to its `collect` stage itself and is refused a second time; the driver relaunches a silent
agent once before the collect names it. `gbg run abandon` ends the open run as `OWNER_STOPPED` with its
findings dropped, and a start on a tree with uncommitted tracked changes is refused. A run interrupted
at a launched stage is continued by `gbg run next`: the roles that wrote are kept, the rest are marked
to launch again, and the tree having moved since the launch is the one case it stops for the owner;
the session block in `CLAUDE.md` gains the instruction to continue such a run first and say so. A
collect over a tree that changed under the agents, by a commit or an uncommitted edit, is exit 2 and
reads nothing. What a run leaves open the next run of the same instrument carries, re-anchored and
under the old id, which the report says.

**A run builds the site it reads.** Two of the three reader bundles are rendered, so `gbg run next`
runs the package's own `docs/make.jl` before the reading stages and before each blind verifier stage,
and a build that fails leaves the run where it stood. The reader of the withheld bundle is launched
ONCE PER BUILT PAGE, each given that page's article body in a file of its own and no surface list; its
verifier is given the same page, rebuilt after the fix. A quote that page carried but does not hold —
one the build rendered from a docstring — is searched for across the documentation, and a quote exactly
one file holds is placed there, so the fixer is sent to the file the sentence is written in. **The six disciplines were attacked and then rebuilt as experts** (Phase 4f): seven rounds of
adversarial lenses took the descriptions from thirty-two substantive objections to none, and the owner
judged the survivors auditors — checkers of stated claims against a fixed standard, with no judgement of
whether the model, method, estimator or decomposition was the right one. The six were rewritten with an
explicit licence to judge appropriateness, each judgement naming the standard applied, the alternative
and what the stated reason leaves unanswered so that the owner can disagree; in two blind comparisons
against the seven-round texts, judges reading the real packages chose the expert text in every field, on
findings that change what is computed or decided rather than a sentence. The seams between neighbouring
readers stay in the texts. The sentence the derivation appends to every discipline routes a defect a rule
names to that rule's id rather than asking the reader to withhold it, and says the code is context and
never the thing under review. `docs/design-record/08-discipline-attack.md` is the record.
The other changes since rc.5 are in the commits from `71993cc`.

## 2.0.0-rc.5 — 2026-09-18

MAJOR. **98 rules**, one more than rc.4, and two changes a consumer will feel.

**`RULE.DOC.RETIRED_CLAIMS` is new.** A phrase a package has retired does not reappear in its
documentation: the check is the fleet's, the list is each package's own and empty by default. Entries are
`RetiredClaim(phrase = …, reason = …, decision = …)` in `.gbg/config.jl`, carrying a LITERAL phrase — a
pattern written in a package's config would be compiled inside every docs build of that package.
Whitespace is flattened and matching is case-insensitive, so a phrase broken across a line wrap is still
found, which is what a pattern was wanted for. The rule states its own limit in `why`: nothing in a
repository knows a claim was retired, so the check is only as good as a list kept by the party being
checked.

**`RULE.DOC.AI_BANNER` can be told which pages it covers.** It compared verbatim and always had; what it
could not do was reach the pages a package requires the banner on, because it read `rationale` and
`literate` and those are a different question. A package sets `banner_pages` and names them. The general
mechanism is `Model.Rule.files_parameter`, since a file set is shared and some rules are not. Its drift
message is also fixed: a page whose banner TITLE had been reworded reported as carrying no banner.

**GBGIsotropicTurbulence is GBGHomogeneousTurbulence**, and the fleet has one home — `Catalogue.FLEET`,
with the sibling-site table derived from it. `fleet.toml` keeps only the sweep state.

**`gbg fleet` reported every package as NOT-INITIALISED**, having looked for the `.gbg/config.toml` that
Phase 2 deleted.

Consumer-visible in `Model`: `Setting.value` widens to hold `Vector{RetiredClaim}`, and `TextExample`
gains `settings`, without which a rule whose behaviour a package supplies cannot be shown to fire at all.

## 2.0.0-rc.4 — 2026-09-18

MAJOR. **This is the candidate to pin.** rc.2 and rc.3 each went out with a red CI and are superseded by
this one; their tags stand, as every tag does.

**The CI step that proves the suite ran was greping a banner Phase 2 renamed.** `Engine.Harness.test`
prints `GBGCodingTools v<version> checks`; the step looked for `… gate`. It could not pass, so it was
testing nothing but its own staleness, and it was hidden behind the git-identity failure until that was
fixed. A test now reads the grep patterns out of both workflow files and requires each to match the
banner the code prints, and is shown to fail when the stale pattern is put back.

## 2.0.0-rc.3 — 2026-09-18

MAJOR. rc.2 with its CI green. Pin this one, not rc.2.

**`test/docfix.jl` needed a git identity it did not have.** The fixture repository passed one to the
commit its own setup makes and not to the commit the VERB makes, which is a child process of its own; on
a developer's machine that fell back to the global config and on a runner there is none. rc.2's tag went
out red on three tests. The fixture now sets an identity in its own repository, as a real package does,
and `tools/floor.sh` runs the suite with the global and system git config neutralised, so this machine
can no longer answer a question CI will be asked.

## 2.0.0-rc.2 — 2026-09-18

MAJOR. The same rulebook as rc.1, rehearsed against a real consumer for a day. rc.1 said it existed so a
package could pin it and `gbg bump` then refused every prerelease, which is the first thing fixed here.

**A package may pin a prerelease.** A tag is immutable whether or not it carries `-rc.N`. The rendering
follows: the `rev` is the full tag and the `[compat]` bound is the base version, because Pkg throws
`invalid version specifier` on a prerelease in compat and `release` already forces `Project.toml` to
carry the base at any candidate tag.

**Nineteen rule defects, every one found by running against a package this package does not own.** The
shape rule keyed a docstring by its binding rather than its signature, grandfathering 30 findings; it
now keys a numbered item under its enclosing heading, which the consumer's own lint did better first.
The argument-form rule read a fraction of each signature, five ways. Both citation rules split a wrapped
reference. The banner rule reasoned about a Julia file as though it were the page it produces. A rule
read files the package's own nested `.gitignore` excludes — 264 findings that were never there. A node
boundary inside a multi-byte name crashed a rule on the two consumers whose prose carries the most Greek.

**Every finding names the rule that made it.** A report that printed only the message left a reader to
infer the class from the wording, and a class inferred from wording is a class miscounted.

**`gbg check --rebaseline`**, so a ratchet the rules own can be closed by the verb that owns it.

**The gate measures where the thing runs.** `tools/floor.sh` now asks GitHub about the last push before
it starts, loads the package from its tracked files alone, and sweeps every consumer when a rule's
reading changed. Four defects reached a tag because the gate ran somewhere the failure could not appear:
a built tree, the library instead of the command line, one consumer instead of four, this machine instead
of a clone.

Still not here: the instruments, the agent roles and the run record (`Orchestration`).

## 2.0.0-rc.1 — 2026-09-18

MAJOR, and a rewrite rather than a change. Every public surface of 1.0.0 is gone: the verbs, the config
format, the home of the rulebook, and the way a package is checked at all. The eleven `v1.0.0-rc.*` tags
stand and 1.0.0 is never released.

**The rulebook is Julia.** All 97 rules are `Rule` values under `src/Rules/`, each carrying its own
statement, the reason it exists, the check that decides a violation, and the examples that show the
check matches the statement — one that breaks each clause and one that complies. `test/rules.jl` runs
every example, so a rule cannot be reworded without the program that enforces it being reworded too.
`policy/` (the prose and `RULES.toml`) and `catalog/scans.toml` are deleted; what a session reads,
`.gbg/policy/`, is written from the values by `Render.policy`.

**There are no scans.** Every one of the 44 text scans became a rule. The engine around them survives
with an empty registry and goes in the next phase.

**A package is checked by what it already runs.** The wiring check — `Render.wiring` — runs inside every
docs build and every test run, so a generated file that was hand-edited is a finding at the moment
someone builds. `gbg doctor` and its 41 checks are deleted; `gbg sync --check` answers the same question
and nothing has to be run on request.

**Everything a package receives is a Julia function's return value.** No templates, no hash sidecar:
`schema/`, `templates/`, `.gbg/managed.json` and `.gbg/exemptions.toml` are gone. A JSON-Schema subset
validator is replaced by the types themselves.

**A package overrides any rule it likes.** A `Switch` in its own `.gbg/config.jl` names the rule and
gives a reason, which is rendered into its rulebook and onto its site. There is no set a package may
not escape: that concept was removed on the owner's ruling, since a switch is already on the record and
the refusal only bought a red build with no way out.

**Verbs:** `init`, `sync`, `check`, `docfix`, `bump`, `release`, `fleet`, `install`, `self verify`,
`config`, `scan`, `probe`. `bump` refuses to move a pin while the new version's rules find anything,
printing the count per rule.

Not yet here, and why this is a candidate: the instruments, the agent roles and the run record
(`Orchestration`) are not built, and no package is wired to this version yet. This tag exists so one
can be — a consumer cannot pin a path.

## 1.0.0-rc.11 — 2026-09-12

PATCH on rc.10. Instruments affected: all four — `verify-act.js` and `verify-state.js` are copied into
every round's workflow directory, so the break reached each of them; bug-hunt additionally gains schema
floors on three of its own fields. Rates comparable: **yes** — no lane's or verifier's judgement changed,
because the two scripts could not run at all, and the bug-hunt floors reject only degenerate output (a
one-word title, a mechanism too short to be the `description` that banking already requires).

**A blocker rc.10 shipped, found by the round rc.10 was cut for.** `verify-act.js:126` and
`verify-state.js:113` carried a BARE backtick pair around `lane_files` inside the prompt template
literal, closing the literal early: neither file parsed. The verifier batching introduced it, no
verification pass had run since, and `gbg round pass open` on the very next round — the one open now —
would have launched two scripts that cannot parse. The escape is restored, matching every other
backticked term in those files.

**The guard that should have caught it was keyed on a word rather than on syntax.** `SPAN_IN_PROSE`
flags a Markdown code span in prompt prose and is swept over all eleven scripts on every test run, but it
exempted `in ` and `of `, written for the JavaScript operators. The English preposition matched the
exemption meant for the operator, so the suite stayed green through every run of rc.10 over an
unparseable file. Both exemptions are gone and the two prose forms are pinned as must-catch cases;
neither operator is followed by a template literal anywhere in the scripts or the prelude, so the
exemption protected nothing and hid the one class the guard exists for.

**bug-hunt's own schemas were looser than the shape `bank` enforces.** `CANDIDATE_SCHEMA.candidates.title`
and `VERDICT_SCHEMA.title` in `hunt.js` took a bare string, and so did `mechanism`, which `hunt.js:155`
copies verbatim into the banked finding's `description` — while `schema/finding.schema.json` requires a
`title` of 8 characters and a `description` of 20 at bank. A lane could therefore return schema-valid
output that fails banking. The three fields now carry the floors the core schema already demanded. Found
by `2026-09-12-check-docs-01`'s `workflow-scripts#5`, which graded LINE-ONLY when the first fix reached
only the two titles and left `mechanism` bare.

**Documentation corrections from the same round.** `CFG.TORN`'s pass message, ARCHITECTURE's preflight
step 2 and its §7.3 row now separate a PINNED file (consumer-owned, never rendered) from a MANAGED file
(`gbg sync` renders and hash-checks it), one word having carried both. `IMPLEMENTATION.md` drops `ORPHAN`
from D10's class list: `bank` iterates the roster, so a lane file no roster entry expects is never
classified at all. `Passes`' module docstring splits its verifier paragraph to come under
`RULE.DOC.SHAPE`'s 120-word cap while keeping the inline gloss of SWEPT, which a cold reader meets one
module before `Demote` defines it.

**`docs/prose_shape.csv` was re-baselined twice, deliberately.** A fix pass that adds the glosses its
findings demand will always trip the ratchet, so a reset with a stated reason is a normal end-of-round
step rather than a workaround; each is its own commit. The second corrects the first, which had frozen
that docstring with a required gloss missing.

## 1.0.0-rc.10 — 2026-09-12

MAJOR on rc.9. Instruments affected: check-docs and check-consistency (a carried finding's first fix
range; the verifier and panel scripts' empty-roster refusals), bug-hunt and audit-changes (the same
refusal in their scripts), and every consumer's doctor (`BUILD.DOCS`) and scan report (the DEAD rule).
Rates comparable: **no**, for all four — every instrument's reporting UNIT moved from sites to classes, so
a finding count either side of this release is not the same measurement; and for the docs instruments a
carried finding fixed between rounds can now close `honored`, where it was graded `UNDONE` for ever. The
fixture recall is unchanged: no scan's hit set moved.

The corrections `2026-09-11-audit-changes-02` disposed as `fixed`, the deferrals of
`2026-09-11-check-docs-02` that were not the owner's to decide, and the live defects the check-docs attack
named and that round's lanes missed:

**A carried finding can close.** A finding carried from an earlier round is usually fixed after that round
closes, and the next round's act verifier read only its own range, so it graded the fix `UNDONE` at every
pass: four ids of 2026-09-11-check-docs-01 were carried twice that way, three of them serious. A round's
first fix range now starts where the rounds it re-banked from closed (`Passes.carried_base`); a finding
the round banked itself cannot have been fixed before it opened, so nothing else moves.

**A zero-population scan is DEAD whatever the ledger removed.** `report` spared a scan that measured
nothing when the ledger had exempted its hits — exactly the broken counter the DEAD rule exists to expose,
since the ledger never changes a population. The promise is restored and the code keeps it.

**The deep doctor asks for the build itself.** `BUILD.DOCS` sets `GBG_DOCS_NO_SKIP`, as `SELF.DOCS` and
`gbg release` do, so a docs build skipped for an open round no longer PASSes it; the five places that said
"the deep doctor" sets it are now true of every deep check. During an open docs round `gbg doctor --deep`
fails `BUILD.DOCS` in every consumer.

**A docs build fails when a docs round's fixes were committed without it,** where it used to skip
(2026-09-11-check-docs-02's `ext#4`, `gate_problems`); now tested. A round's own build runs through
`gbg round build` and CI sets `CI`, so neither meets it.

**The check-docs lane set, rebuilt — and one option dropped because it was measured first.** The round of
2026-09-11 returned 0/6 seeded recall with five lanes SUSPECT, and the design attack named eighteen gaps.
Five changes follow, and a sixth was refused by its own measurement. A lane now reports CLASSES, never
sites: a recurring defect is ONE finding whose `locations` name every site, which is `RULE.DOC.CLASS_SWEEP`
applied where the finding is WRITTEN rather than only where it is fixed — the rulebook always said it and
the lane brief never did, so a class split across five findings spent five of the budget and let a sweep
close four while the fifth survived. `finding_cap` (20) is now a config value reaching the brief as a slot,
and it bounds findings, so a class with forty sites costs one. `rationale_lanes` (3 here) cuts a
single-document rationale surface on its own `## ` headings, the first slice keeping the key `rationale` so
a carried finding still names a lane the round runs. `one-home` replaces `family`, which enumerated f/f!
pairs this package does not have and returned nothing: it works claim-outward — pick a claim, search for
its other homes — because a second home in a file the lane never opened is exactly what a per-surface lane
cannot see. A new `ambient` lane reads the prose that no lane read, measured file by file against every
surface and every lane: `CLAUDE.md`, `README.md`, the four instrument `PROTOCOL.md` — the instruments' own
specifications — `docs/make.jl` and `install.sh`; `CHANGELOG.md` and `IMPLEMENTATION.md` are deliberately
excluded, being append-only records whose past truth would read as staleness. A glob in `lanes_extra.files`
is now expanded, so a refinement written as a pattern both reaches its lane as real paths and is subtracted
from the engine's lanes, which it silently was not before.

**Each lane is handed a computed claim checklist, and only one mechanical class became a scan.** Three
classes were proposed for the deterministic half; all three were measured over this package's own surfaces
before any was built, and one survived. `SCAN.ID_RESOLVES` (triage, `RULE.DOC.CURRENT`) is it: a
`RULE.`/`SCAN.`/doctor id in prose that resolves to no row of the running copy's registers, so an id
renamed in the tool lights up every consumer sentence still citing the old one — 964 references here, 11
unresolved, all 11 artefacts of the pattern, which is why a family prefix, a wildcard stem and the
`history_exempt` section are not hits. The other two were refused: a cited COUNT names a contextual subset
rather than an inventory in 17 of 24 in-surface cases ("two rules", "three verbs"), with no lexical signal
separating the readings, so that scan would have shipped 17 false positives and no true one; and an
unresolved PATH is usually a consumer's file the rationale describes on purpose, 143 of 1705. Both now
reach the lane as a computed CHECKLIST instead (`claims/<key>.md`, `claims_path` in args): every cited
number and exit-code claim on that lane's own surface, each discharged in `claims_checked[]` with a verdict
and the evidence that settled it. A claim that reads as true and is checked by nothing is the class these
rounds kept returning; enumerating it is what turns reading into a procedure.

**A third proposed mechanism was refused the same way, and is recorded so it is not re-proposed.** The
design attack asked that each lane's `checked[]` be checked against its roster. Measured over all six
closed check-docs rounds it misfires in both directions: where a roster exists the lanes already list it
(`src`, 78 files, reported 72–78 path-like entries every round, so the check would mark the best-covered
lane `:partial` for a 2–8% shortfall), and where coverage actually failed it is blind, since `family` —
zero findings in all six rounds — is a cross lane carrying no files to compare against. The falsifiable
version, the files a lane OPENED rather than the files it claims, needs a per-agent tool-call log that
Workflow does not expose. What the gap did produce is the claim checklist above: the CLI supplies the
enumeration, so a lane cannot under-enumerate its own denominator, only visibly fail to answer it.

**What check-docs learned, applied to the other three instruments.** Tuning one instrument is a proxy for
tuning all of them, so the same questions were put to the hats, the hunt and the audit — and three of the
findings were defects rather than improvements.

**Three instruments carried their cap INSIDE a Workflow script.** `hunt.js` said "your 6 most substantial
candidates", `audit.js` "your 8 most substantial findings", `panel.js` "at most your 25 MOST SIGNIFICANT
findings" — package policy numbers sitting in the files whose one rule is that no package datum lives in
them. Each is now `instruments.<name>.finding_cap`, rendered into args and REQUIRED by that instrument's
args schema, so a missing cap is loud rather than a silent fall back to a literal. The defaults are the
three numbers as they stood, so no round's behaviour changes by this alone.

**None of the three told its agents to report classes.** `RULE.DOC.CLASS_SWEEP` is fleet-wide and was
stated in no brief but check-docs'. A hat now reports ONE finding per class whose `locations` name every
page; an audit lane ONE concern per class naming every hunk; a hunter ONE candidate per MECHANISM — with
the caveat the transfer needed, since a witness is what makes a hunt candidate real, so a class no single
program can demonstrate is genuinely several and is split exactly there. `candidates_found` moves with it
in all three: it counts classes now, not sites, or TRUNCATED would stop meaning anything.

**A bug-hunt territory handed its globs to the agent AS globs.** `resolve_hunt_lanes` passed
`src/Scans/*.jl` to the hunter verbatim — forty-five files arriving as one pattern — the same defect fixed
in check-docs' `lanes_extra` one commit earlier and missed next door. Both resolvers now share one
`expand_globs`, which keeps a pattern that matches nothing (a directory a lane names) rather than dropping
it and silently emptying that lane.

**Three `src` files were in no territory at all.** `src/CLI/Design.jl`, `src/CLI/Consolidate.jl` and the
module entry point `src/GBGCodingTools.jl` were named by no hunt lane. Design.jl holds `attack` and
`calibrate`, whose option parsing shipped broken in rc.7 and crashed on every invocation; the entry point
is the file `{hunt.entry_point}` points the free lanes at. All three are covered now, and a new doctor
check `CFG.TERRITORIES` (WARN, in `QUICK`, NA where no territory is configured) reports any `src` file a
territory list misses, so the gap cannot quietly return. The doctor has 50 checks.

**A verification pass batches its lanes.** Each verifier ran one agent per lane, and every act agent read
the whole fix-pass diff: in 2026-09-11-check-docs-02's first pass that was 255KB bought nine times, about
half of the pass's 1.17M tokens. Lanes are now grouped into units of at most six findings (`batch` in the
scripts' args, 6 by default), one agent per unit, each writing one file per lane — `grade`, the lane
files and their schema are untouched — and the state verifier groups only lanes that read the same
substrate. The act verifier still reads the whole diff, which is what lets it see a fix made outside the
files a finding names. One scribe per unit replaces one per lane (`scribeAll`), and a unit's lanes come
back in `lane_files`, each found by its own `lane` field.

**A re-run of the dismissal audit buys only what changed.** Each auditor's verdict was filed under a
directory the whole item set's sha named, so changing one disposition invalidated every verdict: over
2026-09-11-audit-changes-02's three runs — ten refusals, then seven, then six, after the auditor overturned
four — that cost 1.48M tokens where the changed items alone were worth about 0.15M. A verdict now lives at
`dismissals/<id>__<sha of the text audited>.json`, keyed by the item's own claim, verdict and reasoning, and
`close` sends the auditor only the items whose file is missing or invalid, saying how many it kept.

**How much of a method a signature repeats is a variation point, `rubric.signature_types`.** The narrowed
form is the default (`names`), and a package that wants the stricter one sets `mirror`: an argument the
method types is typed in the signature, one it leaves untyped stays untyped. PF takes `mirror` — its
config in ARCHITECTURE §5.1, written when PF migrates — where a kernel's argument types are the contract a
caller reads; this package, SS, IT and CP take the default. The rule's sentinel is now its invariant half
(the method's argument order, the 88-column wrap, the source definition untouched) with the choice in a
substituted sentence, as `RULE.DOC.LEADING_IDENTITY` already does, so a rendered policy still reads as one
statement. `SCAN.SIGNATURE_TYPED` checks whichever form the package took: under `names` a type in the
signature's argument list, under `mirror` an argument the method types and the signature leaves bare, read
from the definition the docstring documents. Six values now vary by package, not five.

**`RULE.DOC.SIGNATURE_MIRROR` is narrowed to the house form, on the owner's ruling.** It required every
type the method declares to be repeated in the docstring's signature line, and nothing checked that half:
its register entry named only `SCAN.SIGNATURE_WIDE`, which measures width. Measured over `src/` and `ext/`,
451 arguments across 247 docstrings omitted a type the method declares, and 4 signatures carried one — so
the rule described almost nothing that was written. It now reads: the signature shows the argument names
and defaults, in the method's order and without types, and a type belongs to that argument's bullet under
`The arguments are:`. `SCAN.SIGNATURE_TYPED` (triage, src and ext) enforces it, with a fixture pair; the
four typed signatures (`counting`, `audit`, the extension's `check` and `gate_or_skip`) are corrected. The
88-column half and `SCAN.SIGNATURE_WIDE` are unchanged. `2026-09-11-check-docs-02/ext#1`, carried for the
old form, is adjudicated `not-a-defect` in the ledger: what it asked for is what the rule now forbids.

**Empty rosters refuse.** `lanes.js`, `panel.js`, `hunt.js`, `audit.js`, `verify-state.js` and
`verify-act.js` throw on an empty roster or scope, as the other four scripts did; `verify-act.js`'s
`batches` mode, which nothing called, is gone with its `mode` argument.

**The rule register.** `RULE.CIT.DOI` is checked by `SCAN.DOI_CROSSCHECK`, whose `require_doi` loop
enforces a DOI on every reference; the rc.7 entry above was wrong to say the scan enforces
`RULE.CIT.FULL_INLINE` alone. `RULE.DOC.SHAPE` orders an `# Arguments` heading only where a consumer uses
one in place of `RULE.DOC.ARGS_FORM`'s bulleted form (its sentinel changed with it).

The rest is prose: `rounds.md` no longer says a fix pass cannot be committed around an open round,
`verbs.md` files the gate's refusal under exit 1, `install.md` says which version the shim runs after a
bump, the doctor is read-only except `--deep`, ARCHITECTURE counts five closure channels and orders the
lane statuses as `classify_lane` does, the docs-round seeded copy's cost is stated in D10, §6.4, §11 and
the policy's honest limits, the economy model has one home, `gate_problems` says which refusals it omits,
and CLAUDE.md defines `gbgdev` and states where the release is.

## 1.0.0-rc.9 — 2026-09-11

PATCH on rc.8. Instruments affected: check-docs and check-consistency (where their rounds may open).
Rates comparable: yes.

**A documentation round opens after the release that exists to open it.** `gbg release` appends the
carry ledger's history line after it tags, and while any finding is carried that write is a change the
session must commit, one commit past the tag. Preflight stamped every HEAD not exactly on a tag as
`dev+<sha>` and refused the round, so rc.7 and rc.8 each tagged a round that could not open.
`Preflight.data_since_tag` now stamps a clean checkout with its latest tag when every commit since
touched only `.gbg/`, the package's own records; its commit and tree are the tag's, as on the tag itself.
A commit anywhere else, or a dirty tree, is `dev` as before.

## 1.0.0-rc.8 — 2026-09-11

PATCH on rc.7. Instruments affected: none (the `gbg attack` verb). Rates comparable: yes.

**`gbg attack <instrument>` runs.** In rc.7 its verb read the option fields `pos` and `vals`, which the
parsed options do not have (`positional`, `values`), so every invocation crashed with exit 3; the tests
called `attack` as a function and never through the dispatch. `test/coverage.jl` now drives all four
design-check verbs through `main`.

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
