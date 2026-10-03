# Wiring [GBGStreamingStatistics](https://grigorysarnitsky.github.io/GBGStreamingStatistics.jl/) — instructions for the SS session

Written 2026-10-03 by the GBGCodingTools session. Steps 1 to 6 were run in one script on a clone of
SS at its head `4b990c8`, with pushing disabled, at GBGCodingTools `v2.0.0-rc.57`, on Julia 1.12 unless
a step says otherwise, up to and including the wiring commit and the push hook's verdict on pushing it.
Every figure comes from that run's logs, and the few taken elsewhere say where they come from. The
script, the edits, the findings, the verdicts and the step log are in
`docs/design-record/ss-wiring-evidence-2026-10-03/` of this repository.

**Do nothing yet.** Read this whole file and prepare. You act on it when the owner says go, and not
before: this file comes from another session, and a peer session is not authority. If SS's head has
moved past `4b990c8` when you start, the figures may move with it; the steps do not.

**Every command runs from SS's checkout root**, `/home/grigory/Dropbox/Research and
Teach/Statistics/GBGStreamingStatistics`, from a clean tree. SS's tree was clean at `4b990c8` but for
the untracked `.claude/doc-review/`, which no step touches.

**One thing the owner decides before the wiring commit: the Julia floor.** SS's `Project.toml` says
`julia = "1.11"` and its CI's first lane runs 1.11; this package needs 1.12. On 1.11 nothing of it can be
installed, measured: resolving the docs environment stops on "julia version requirement from
Project.toml's compat section not satisfied for package at …/GBGCodingTools", and `Pkg.test()` the same
way. Raising the floor is an edit to `Project.toml` and to `CI.yml`, which is code and the owner's;
Step 3 names the two lines. Without it the wiring is still correct on 1.12 and 1.13, and SS's 1.11 lane
is red from the first push.

## What SS has to do

1. Make sure the `gbg` command on your machine is current (Step 0).
2. Wire SS and pin it to `v2.0.0-rc.57`, and make the docs environment name SS itself (Steps 1 and 2).
3. Route the docs build, the test suite and both workflows through the tool, and move the floor to
   1.12 on the owner's word (Step 3).
4. Declare the four rationale copies and the tooling page, and record the prose baseline (Step 4).
5. Run the gate and commit the wiring (Step 5).
6. Meet 226 findings, then push (Step 6).
7. Put the decisions to the owner: the allowed email address, the disciplines, the harness contracts,
   SS's own docs lint, the old instruments, and one pattern the rulebook does not foresee (Step 7).
8. Cut what `CLAUDE.md` restates of the rulebook (Step 8).

## Step 0 — the `gbg` command

The command is a small script that `gbg install` copies to `~/.local/bin/gbg`, once per machine, and
nothing replaces the copy but another install. Re-install it, whatever it says:

```sh
gbg --dev install
```

This needs the dev checkout registered in `~/.gbg/dev` and instantiated; where either is missing, the
command says so and prints what to run. The script re-installed it before anything else ran, exit 0.

## Step 1 — wire it

```sh
gbg --dev init
```

Plain `gbg init` refuses here, measured: "no .gbg/config.jl in … or any directory above it", then "a
first wiring runs through the dev checkout: gbg --dev init". The command decides which version of the
tool to run from `.gbg/config.jl`, which SS does not have yet, so a first wiring goes through the dev
checkout. Measured: it writes `.gbg/config.jl`, then **22 paths**, and exits 0.

- `.gbg/config.jl` — **new, and SS's own.** No verb rewrites it except to move the pin. It names the
  package, the tool version, `docs/make.jl` as the build, and `Pkg.test()` as the tests.

- `CLAUDE.md` — a marked block of 20 lines is inserted **at its head**, importing the rulebook; the
  rest is untouched.

- `.gitignore` — a marked block of 11 lines is added at its head; SS's own lines stay. The block
  ignores `docs/src/gbg.md`, the tooling page the build writes, and `.claude/settings.local.json`,
  which SS has and does not track.

- `.claude/hooks/queue-guard.sh`, `.claude/hooks/push-gate.sh` and `.claude/settings.json` — the
  end-of-turn hook and the push hook (Step 6). SS has no `settings.json` of its own today, only the
  local one, so nothing is merged.

- `.claude/skills/documentation-review/SKILL.md` and `.claude/skills/leak-scan/SKILL.md` — the two
  instruments that exist. SS's own `.claude/commands/check-docs.md` and `check-consistency.md` are its
  old in-tree instruments; nothing of the tool's takes their names, and they go in Step 7's time.

- `.gbg/policy/*.md` (11 files), `test/regressions/README.md`, `.github/actions/gbg-auth/action.yml`.

- `docs/Project.toml` and `test/Project.toml` — this package's entries set; every other entry kept.

Everything but `.gbg/config.jl` is generated: `gbg sync` rewrites it and a hand edit is lost.

## Step 2 — pin the release, and the docs environment

```sh
gbg --dev bump 2.0.0-rc.57
```

Measured: it writes the pin into `.gbg/config.jl`, rewrites **21 paths**, and exits 0.

**Then make the docs environment name SS itself.** Add one line under `[sources]` of
`docs/Project.toml`, which `bump` has just created there:

```toml
[sources]
GBGStreamingStatistics = {path = ".."}
```

SS's `docs/Project.toml` already lists SS under `[deps]` with nowhere to find it, and `docs.yml` makes
up for that on the runner with a `Pkg.develop` of the checkout. This line says it in the file, which
is what the push hook's build and a fresh clone read; Step 3 then drops the `Pkg.develop`. Measured with
the line left out and no manifest: `Pkg.instantiate()` of the docs environment stops on "expected
package `GBGStreamingStatistics [f7630e6d]` to be registered", which is what a fresh clone and the
runner would meet.

Then run what `bump` printed:

```sh
julia +1.12 --project=docs -e 'using Pkg; Pkg.resolve()'
gbg sync
```

Measured: the resolve exits 0, and `docs/Manifest.toml` then holds SS at `path = ".."` and, for
`GBGCodingTools`:

```toml
git-tree-sha1 = "80a0f467e4dcc7e981a2c50b596654c34337d307"
repo-rev = "v2.0.0-rc.57"
```

`gbg sync` then says "already wired at v2.0.0-rc.57; nothing written": since rc.57 the pin is edited
in place, so your line stays where you put it. Where `bump` prints a second command for `test/`, run it
too; it printed one here because the clone's test manifest did not hold the tool. From here on, plain
`gbg` works.

## Step 3 — route the build, the tests and the workflows through the tool

Measured before this step: the wiring check reports four files that `gbg sync` does not write, each
with "edit this file: `gbg sync` does not write it". These are `test/runtests.jl`, `docs/make.jl`,
`.github/workflows/CI.yml` and `.github/workflows/docs.yml`. The edits, as rehearsed
(`entry.diff.txt` and `workflows.diff.txt` in the evidence):

**`docs/make.jl`.** After `using Documenter`, add `using GBGCodingTools`; after
`using GBGStreamingStatistics`, a root and the tooling page. Call the wrapper instead of `makedocs`,
and list the page under "Design & Internals":

```julia
using Documenter
using GBGCodingTools
using GBGStreamingStatistics
const ROOT = normpath(joinpath(@__DIR__, ".."))
const TOOLING = GBGCodingTools.Render.pages(GBGCodingTools.ConfigIO.read_config(ROOT), ROOT)
…
GBGCodingTools.makedocs(ROOT;
  sitename  = "GBGStreamingStatistics.jl",   # every keyword as it stands, `doctest = true` included
…
      "Internals"     => "internals.md",
      "Documentation tooling" => only(TOOLING),
```

`lint_inline_math()` and `copy_rationale_pages()` stay where they are for now (Step 7). The
`deploydocs` call stays as it is. The wrapper runs the rulebook before Documenter and the site rules
after it, and throws on a finding, so a build with findings never reaches `deploydocs`.

**`test/runtests.jl`.** At the end, after the last `module … end` line:

```julia
using GBGCodingTools
GBGCodingTools.Engine.Harness.test(dirname(@__DIR__); checks = (GBGCodingTools.Render.wiring,))
```

**`.github/workflows/CI.yml` and `docs.yml`.** Right after `actions/checkout`, in both:

```yaml
- uses: ./.github/actions/gbg-auth
  with:
    token: ${{ secrets.GBG_DEPS_TOKEN }}
```

The secret exists in SS's repository already (`gh secret list`: `GBG_DEPS_TOKEN`, set 2026-09-09),
and the fleet token it holds reads this package: no step of the owner's here. In `docs.yml` the step
"Install doc environment" keeps only `julia --color=yes --project=docs -e 'using Pkg;
Pkg.instantiate()'`: its `Pkg.develop` is what Step 2's line now says.

**The floor, on the owner's word:** `julia = "1.12"` in `Project.toml`'s `[compat]`, and
`version: '1.11'` → `'1.12'` in `CI.yml`'s matrix, with its comment "the package's minimum (compat
floor)" still true. Neither was made in the rehearsal, which ran on 1.12 and 1.13.

Measured after the four edits: the wiring check reports nothing.

## Step 4 — the config, and the prose baseline

SS tracks no manifest, so no switch is due, unlike HT. What the config declares is where the build
writes: the four rationale documents it copies into `docs/src/` as lowercase siblings, and the tooling
page. Add to `.gbg/config.jl`, after the lines `init` wrote:

```julia
    # The one tooling page, written by `Render.pages` during the docs build. No rule reads a generated page.
    generated = ["docs/src/gbg.md"],
    # The docs build copies each rationale document into `docs/src/` as a lowercase sibling, and the
    # copy is what the site renders. A fix belongs in the source; the change guard refuses one landing
    # in a copy, which the next build would overwrite.
    copies = [
        "docs/src/architecture.md" => "docs/ARCHITECTURE.md",
        "docs/src/formalization.md" => "docs/FORMALIZATION.md",
        "docs/src/testing.md" => "docs/TESTING.md",
        "docs/src/performance.md" => "docs/PERFORMANCE.md",
    ],
```

The whole file as rehearsed is `config-final.jl.txt` in the evidence. **Run `gbg sync` after every edit
to `.gbg/config.jl`.** Measured: this edit changes no generated file and no finding; the four copies
are ignored files, which no rule read before either, and the declaration is for the change guard.

Then record the prose baseline, which a first wiring does once:

```sh
gbg check --rebaseline
```

Measured: it writes `docs/prose_shape.csv`, 148 rows. Without it, `RULE.DOC.SHAPE` holds each of those
units to the rulebook's caps, and 45 of them exceed the caps. With it, each is held to its own size from
here on.

## Step 5 — the gate, then the wiring commit

```sh
julia +1.12 --project -e 'using Pkg; Pkg.test()'
julia +1.12 --project=docs docs/make.jl
gbg sync --check
```

Measured on Julia 1.12:

- `Pkg.test()` exits 0. It runs SS's own suite — JET, Aqua and HDF5 included — then the rulebook's code
  rules and the wiring check, and prints `GBGCodingTools v2.0.0 checks — the config pins v2.0.0-rc.57`.
- The docs build exits 1 before building, on Step 6's findings and nothing else: no wiring finding.
- `gbg sync --check` exits 0.

Commit the wiring on its own, before any finding is touched: Steps 1 to 4 and the edits of Step 3.
Stage with `git add -u`, plus the new paths by name: `.claude/hooks/`, `.claude/settings.json`,
`.claude/skills/`, `.gbg/`, `.github/actions/`, `docs/prose_shape.csv` and `test/regressions/README.md`.
Those seven are the rehearsal's untracked paths; `.claude/doc-review/` is not among them and does not
belong in this commit. Measured: 28 files, 1,578 lines added and 6 removed; the tree is clean after the
commit, and `gbg sync --check` still is. `gbg check` then reports 210 findings: Step 6's 209 that run
outside a build, and `RULE.GIT.PUSH`, "1 commit(s) not pushed", which the push clears.

The commit's last line is the trailer `RULE.GIT.TRAILER` states, and nothing else:

```text
Co-Authored-By: Anthropic Claude <noreply@anthropic.com>
```

Your `CLAUDE.md` names a versioned trailer; the owner ruled the versionless one on 2026-09-08, and
Step 8 cuts that line.

**Do not push yet.** The push hook runs the docs build before every push a session makes, and a failing
build stops the push. Measured on the wiring commit: the hook prints "PUSH STOPPED: the docs build
failed" and lists the 226 findings of the build, and nothing else. The wiring commit goes out with the
fixes of Step 6.

**On Julia 1.13**, SS's CI lane `'1'`: the docs build reports the same 226 findings, measured. `Pkg.test()`
with four threads fails one test, `test/hyperstatistics.jl:45`, the equality of a `merge!` with
`weight = 1` against the plain `merge!`. That is SS's own: the same test fails the same way on SS's head
unwired, measured on a plain clone with Julia 1.13 and four threads (`julia113-tests.txt`), and the suite
stops there, before the tool's checks at its end. What to do about it is for SS and the owner.

## Step 6 — 226 findings, then the push

The build reports 226: the 209 `gbg check` reports, plus 13 `RULE.DOC.XLINK` and 4
`RULE.DOC.SIGNATURE_FIDELITY`, which need the loaded package. The site rules, measured on a plain
Documenter build of the same pages, add none. That plain build exits 0: SS's doctests pass, with one
warning of Documenter's own, `architecture.md` over its size threshold.

Every one was checked against its rule's statement, one by one, at `4b990c8`, by three verifiers, each
reading one share of them in the source: **216 are true, 6 are the checks' own, and 4 the
statement does not decide**. The verdicts are `verdicts-{A,B,C}.txt` in
the evidence. The false ones are defects of the checks, not of SS, and are this package's to fix; they
are listed at the end of this step. By rule:

- **80 × `RULE.DOC.ARGCOV`.** An argument of the signature is not named as code in the body. In 19 of
  the 20 units it is `summary`, written in prose as "the summary". 15 docstrings — every
  `*_standard_error` and `*_with_standard_error` reader — say "Arguments: as for [`f`](@ref)" and name
  none; the rule's text has no delegation, so they are true under it, and whether it should is Step 7's
  question. The reported line is the docstring's opening line, since the defect is an absence.

- **27 × `RULE.DOC.LINKS`.** A name linked twice in one docstring; the line is the second link.

- **25 × `RULE.DOC.ARGS_FORM`.** 23 units describe three or more arguments, or a keyword, with no
  `# Arguments` section, the 15 delegating readers among them; `expectation` and `read_histogram` have
  the section with two arguments and no keyword, where the rule wants prose. Argument lists are an
  `# Arguments` section (ruled 2026-09-28), and several arguments may head one bullet (ruled 2026-09-29).

- **22 × `RULE.TEX.ONE_SPAN`.** A code span followed at once by a math span, the
  name and then its symbol, SS's own idiom for binding the two; `docs/ARCHITECTURE.md` carries most of them. The
  idiom is one of Step 8's conflicts.

- **22 × `RULE.DOC.SENTENCE_OPENER`.** A sentence opening with a code span, a formula or a lowercase
  link. 21 are true; one is the check's.

- **15 × `RULE.CIT.FULL_INLINE`.** A full reference in the running prose, under a `References:` label
  or a `Reference:` sentence. Cite author–year in the sentence and put the work under the docstring's
  `# References`.

- **13 × `RULE.DOC.XLINK`.** A name another SS module owns, bare at its first mention in a docstring.

- **4 × `RULE.DOC.AI_BANNER`.** The four rationale documents carry no provenance banner.

- **4 × `RULE.DOC.REF_ABUT`.** A `@ref` link directly followed by a code span holding the call's
  arguments, with nothing between them.

- **4 × `RULE.DOC.SIGNATURE_FIDELITY`.** The docstring's signature line differs from the method below it.

- **2 × `RULE.TEX.SPACING`, 2 × `RULE.DOC.FIELDS`.** Every field is at the head of a bullet under
  `# Fields` (ruled 2026-09-29).

- **One each.** `RULE.TEX.RENDERED_MATH`, `RULE.TEX.CODE_IN_MATH` (a name set in a math span), `RULE.DOC.SIGNATURE_MIRROR` (over 88 columns), `RULE.DOC.SIBLING_LINK` (a bare first mention
  of a sibling package), `RULE.DOC.INTERNAL_API` and `RULE.CIT.DOI`.

All the findings are documentation, and documentation is fixed without asking. A rule switched off,
for the whole package or for named files, is config, and that is the owner's. **Commit the fixes, run
the docs build until it exits 0, then push**: the hook runs the same build and lets the push through.
Fixing grows prose, so run `gbg check --rebaseline` after the fixes, as HT had to.

**The checks' own defects, met here** — reported to this package, not for SS to work around; until they
are fixed, a finding of theirs is dropped with the reason:

- `RULE.DOC.ARGCOV` does not see an argument named inside a longer code span: `from` and `weight` of
  `merge!` are named in the call form the docstring quotes at `src/Accumulators.jl:67`, and both are
  reported (2 findings). It also takes a double-backtick math span for code, so a few arguments named
  only in mathematics went unreported; the count would be higher, not lower.

- `RULE.DOC.SENTENCE_OPENER` forgets the sentence at a fenced math block: at
  `src/ConditionalDensity.jl:245` the display above ends in a comma and the next paragraph continues
  the sentence (1 finding).

- `RULE.TEX.SPACING` misses the differential allowance when the span is written `\,\mathrm du` without
  braces or wraps after `\mathrm`: `docs/FORMALIZATION.md:12` and `src/Expectations.jl:298` (2 findings).

- `RULE.TEX.RENDERED_MATH` takes a comparison of `degree` with a number at `docs/TESTING.md:93`, written
  as code with the Unicode operator, for mathematics in a code span (1 finding).

- `RULE.DOC.SIGNATURE_FIDELITY` reads the positional NAMES: its 4 findings are `observe!`, `scale!` and
  `observe_pairs!`, whose docstrings sit on interface stubs in `Accumulators` and name the receiver
  `summary` where the methods in `Histograms` name it `h`, with the same arity, positions and types. The
  statement says "agree, argument for argument", its why speaks of a call that fails, and a call with the
  displayed signature succeeds; whether a name counts is the rule's to say, so these 4 are neither fixed
  nor dropped until it does.

- `RULE.CIT.FULL_INLINE` reports a `References:` block one entry at a time and left out the Rosenblatt
  entry at `src/ConditionalDensity.jl:154` beside the reported one at 155; fixing the block fixes both.

## Step 7 — the decisions for the owner

**The allowed email address.** `gbg leak` on the wired clone, measured: 136 findings — none blocking,
2 in the current files, 134 only in the history. The 2 are `RULE.LEAK.EMAIL` on the `authors` line of
`Project.toml`, the owner's own address; for this package he allowed it as the one address, with
`leak_emails = ["grigory@sarnitsky.se"]` in the config. The 134 are 133 session links in commit messages
and one address, which `gbg leak --accept` records once he says so; it writes `.gbg/leak-accepted.txt`,
to be committed. The GitHub side was not read; `--github` reads it.

**The disciplines.** A documentation review's readers include one expert per discipline a package
declares in `disciplines`. From the catalogue, SS's candidates are `:statistical_estimation` and
`:software_architecture`, as [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/) has the latter. The owner chooses.

**The harness contracts.** `RULE.TEST.ALLOC_ZERO`, `PASS_AUDIT`, `ORACLE_INDEPENDENT`, `METHOD_PARITY`,
`SEED_PARITY` and `DEVICE_COST` bind a package that declares them, by calling the tool's contract
function from its suite. SS's derived surface at `4b990c8`, measured, is 9 modules, 38 operations — 4
in-place, `merge!`, `observe!`, `observe_pairs!` and `scale!`, and 34 value-returning — and 4 types.
`test/allocations.jl` measures the in-place four already, `test/oracles.jl` and `test/testoracles.jl`
hold its oracles, and `test/gpu/` compares ROCm against the CPU; none calls a contract function. Which
to declare is the owner's; declaring binds SS to it. The ROCm environment `test/gpu/rocm/` does not name
the tool, and need not until SS declares a contract that runs there.

**SS's own docs lint.** `docs/make.jl` runs `lint_inline_math()` before the build; `RULE.TEX.INLINE_ONE_LINE`
decides the same thing and reports nothing at `4b990c8`. The lint reads the four rationale documents too,
which the rule also reads. Whether to delete it is the owner's.

**The old instruments.** `.claude/commands/` holds 5 tracked files, the in-tree `check-docs` and
`check-consistency`, and `.claude/doc-review/` an untracked round. Deleting the instruments is Phase 7 of
the tool's plan, after a documentation review has run in SS and the owner has read its report
(decision 12), not now.

**A pattern the rulebook does not foresee.** Fifteen `*_standard_error` readers document their arguments
by delegation, "Arguments: as for [`f`](@ref)", and `RULE.DOC.ARGCOV` and `RULE.DOC.ARGS_FORM` each
count that as nothing: 30 of the 226 findings. The fix under the rules is to repeat the list in each;
the alternative is a rule that admits delegation to a named sibling. That is a change to the rulebook,
which is this package's and the owner's, and SS should not wait for it.

## Step 8 — cut what `CLAUDE.md` restates of the rulebook

Once SS is wired, its `CLAUDE.md` imports the rulebook at its head, and restates parts of it below.
The measured list is `docs/design-record/SS-CLAUDE-CUT-2026-10-03.md` in this repository, over the
680 lines at `4b990c8` against rc.57's rulebook: 7 lines duplicate, 71 to trim, 99 lines in 9 passages
conflict, 503 are SS's own.

Work from the list, and check each item against the text before acting; it is a measurement, not a
ruling. Delete duplicates and cut trims as the list says. Three conflicts are settled by the owner's
rulings, each in the rule's favour, and the list names them: the trailer, `\left`/`\right`, and the
code-span wording. Put the other six to the owner and change nothing for them. The first is the largest:
SS's L209–210 make bandwidth, kernel, degree and method keyword arguments, and `RULE.API.POSITIONAL` says
an argument that changes the result is positional; that is SS's whole exported surface, and the answer is
a switch or a redesign, neither of them the session's.

These are SS's own commits, after the wiring; `CLAUDE.md` is code, and the owner reviews the diff.

## Reporting a defect in this package

A tool defect, or a discipline the catalogue lacks, is a tracked file in SS:
`.gbg/requests/to-GBGCodingTools-<date>-<topic>.md`, with a status paragraph on top, deleted when it is
concluded. Never an edit in this package's repository from SS's session.
