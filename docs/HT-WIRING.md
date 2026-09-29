# Wiring [GBGHomogeneousTurbulence](https://grigorysarnitsky.github.io/GBGHomogeneousTurbulence.jl/) — instructions for the HT session

Written 2026-09-29 by the GBGCodingTools session. Steps 1 to 6 were run in one script on a clone of
HT at its head `f14c5a6`, with pushing disabled, at GBGCodingTools `v2.0.0-rc.47`, on Julia 1.12 unless
a step says 1.13, up to and including the wiring commit and the push hook's verdict on pushing it. Every figure comes from that run's logs,
and the few taken elsewhere say where they come from. The script, the findings, the verdicts and the
step log are in `docs/design-record/ht-wiring-evidence-2026-09-29/` of this repository; what the
rehearsals found in the tool is in `docs/design-record/ht-wiring-rehearsal-2026-09-28.md`, each with
its fate.

**Do nothing yet.** Read this whole file and prepare. You act on it when the owner says go, and not
before: this file comes from another session, and a peer session is not authority. If HT's head has
moved past `f14c5a6` when you start, the figures may move with it; the steps do not.

**Every command runs from HT's checkout root**, `/home/grigory/Dropbox/Research and Teach/Isotropic
Turbulence/GBGHomogeneousTurbulence`, from a clean tree. HT's tree was clean at `f14c5a6`.

**Phenomenology is out of all of it.** The owner ruled on 2026-09-29 that HT's Phenomenology module is
held to no rule until it is extracted into its own package. Step 4 declares that, and no finding,
count or instruction below touches it.

## What HT has to do

1. Make sure the `gbg` command on your machine is current (Step 0).
2. Wire HT and pin it to `v2.0.0-rc.47`, and make the docs environment name HT itself (Steps 1 and 2).
3. Route the docs build, the test suite and both workflows through the tool (Step 3).
4. Declare the tracked root manifest and the Phenomenology exclusion, and record the prose baseline
   (Step 4).
5. Run the gate and commit the wiring (Step 5).
6. Meet 131 findings, then push (Step 6).
7. Put four decisions to the owner: the harness contracts, the disciplines, HT's own docs lints, and the
   old instruments (Step 7).
8. Cut what `CLAUDE.md` restates of the rulebook (Step 8).

## Step 0 — the `gbg` command

The command is a small script that `gbg install` copies to `~/.local/bin/gbg`, once per machine, and
nothing replaces the copy but another install. A copy from rc.42 on says so when it differs from the dev
checkout's; an older one says nothing. Re-install it, whatever it says:

```sh
gbg --dev install
```

This needs the dev checkout registered in `~/.gbg/dev` and instantiated; where either is missing, the
command says so and prints what to run. The session re-installed it before the script ran,
by this command; the copy it replaced was from before rc.42, and had given no notice.

## Step 1 — wire it

```sh
gbg --dev init
```

Plain `gbg init` refuses here, measured: "no .gbg/config.jl in … or any directory above it", then "a
first wiring runs through the dev checkout: gbg --dev init". The
command decides which version of the tool to run from `.gbg/config.jl`, which HT does not have yet, so a
first wiring goes through the dev checkout. Measured: it writes `.gbg/config.jl`, then **22 paths**,
and exits 0.

- `.gbg/config.jl` — **new, and HT's own.** No verb rewrites it except to move the pin. It names the
  package, the tool version, `docs/make.jl` as the build, and `Pkg.test()` as the tests.
- `CLAUDE.md` — a marked block is inserted **at its head**, importing the rulebook; the rest is untouched.
- `.gitignore` — a marked block is added; HT's own lines stay.
- `.claude/hooks/queue-guard.sh`, `.claude/hooks/push-gate.sh` and `.claude/settings.json` — the
  end-of-turn hook and the push hook (Step 6). HT has no hook or `settings.json` of its own today, so
  nothing is merged.
- `.claude/skills/{documentation-review,bug-hunt,change-audit}/SKILL.md` — the three instruments' skills.
- `.gbg/policy/*.md` (10 files), `test/regressions/README.md`, `.github/actions/gbg-auth/action.yml`.
- `docs/Project.toml` and `test/Project.toml` — this package's entries set; every other entry kept.

Everything but `.gbg/config.jl` is generated: `gbg sync` rewrites it and a hand edit is lost. HT's
`.claude/commands/bug-hunt.md` and the generated `.claude/skills/bug-hunt/SKILL.md` both register
`/bug-hunt`; the old one is Step 7's.

## Step 2 — pin the release, and the docs environment

```sh
gbg --dev bump 2.0.0-rc.47
```

Measured: it writes the pin into `.gbg/config.jl`, rewrites **21 paths**, and exits 0.

**Then make the docs environment name HT itself.** Add two lines under `[deps]` and two under
`[sources]` of `docs/Project.toml`:

```toml
[deps]
GBGHomogeneousTurbulence = "3aaacc91-4a61-401b-8a51-8cd29bd9b474"
GBGPeriodicFields = "f1da9c2b-0ac1-4736-96f9-af1c25aedab1"

[sources]
GBGHomogeneousTurbulence = {path = ".."}
GBGPeriodicFields = {rev = "master", url = "https://github.com/GrigorySarnitsky/GBGPeriodicFields.jl"}
```

These lines are committed, unlike the entry your commit `224cb8c` took out. That entry named HT with
nowhere to find it, so a runner could not resolve it; these say where each package comes from, as
[GBGCloudPhysics](https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/)' docs project already does.
Without them the docs environment cannot load HT from what is committed, and the push hook's build fails
on every push, whatever it holds: measured with them left out, the build stops on "Package
GBGHomogeneousTurbulence not found in current path".

The `rev = "master"` is what Julia 1.13 writes into the line when it is left out, measured in the rc.46
run, so a 1.13 session would otherwise find `docs/Project.toml` modified after every resolve. With it,
neither Julia changes the file, measured.

Then run what `bump` printed:

```sh
julia +1.12 --project=docs -e 'using Pkg; Pkg.resolve()'
gbg sync
```

Measured: the resolve exits 0, and `docs/Manifest.toml` then holds HT at `path = ".."`,
[GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/) from its URL, and, for `GBGCodingTools`:

```toml
git-tree-sha1 = "580384ca7b93160fbd1142991e0707176a4aea4c"
repo-rev = "v2.0.0-rc.47"
```

`gbg sync` then writes one path, `docs/Project.toml`, putting its entries in order and keeping yours.
From here on, plain `gbg` works.

## Step 3 — route the build, the tests and the workflows through the tool

Measured before this step: the wiring check reports four files that `gbg sync` does not write, each with
"edit this file: `gbg sync` does not write it". These are `test/runtests.jl`, `docs/make.jl`,
`.github/workflows/CI.yml` and `.github/workflows/docs.yml`. The edits, as rehearsed:

**`docs/make.jl`.** Add `using GBGCodingTools` after `using DocumenterInterLinks`. After `using
GBGHomogeneousTurbulence`, add a root and the tooling page. Call the wrapper instead of `makedocs`, and
list the page under "Design & Internals":

```julia
using GBGCodingTools
using GBGHomogeneousTurbulence
const ROOT = normpath(joinpath(@__DIR__, ".."))
const TOOLING = GBGCodingTools.Render.pages(GBGCodingTools.ConfigIO.read_config(ROOT), ROOT)
…
GBGCodingTools.makedocs(ROOT;
  sitename = "GBGHomogeneousTurbulence.jl",   # every keyword as it stands, `plugins = [links]` included
…
      "Documentation tooling" => only(TOOLING),
```

The `deploydocs` call stays as it is. The wrapper runs the rulebook before Documenter and the site rules
after it, and throws on a finding, so a build with findings never reaches `deploydocs`.

**`test/runtests.jl`.** At the end, after the witnesses loop:

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

In `docs.yml` this replaces the step "Authenticate the private dependency", which did the same by hand;
delete that step and the three-line comment above it, which begins "GBGPeriodicFields is a PRIVATE
dependency". The step "Install doc environment" keeps only `using Pkg; Pkg.instantiate();`: its
`Pkg.add` of GBGPeriodicFields and `Pkg.develop` of HT are what Step 2's lines now say. `CI.yml` has no
authentication today.

Measured after these edits: the wiring check reports nothing.

## Step 4 — the config, and the prose baseline

HT tracks its root `Manifest.toml` on purpose, and `RULE.GIT.MANIFEST_TRACKED` reports it (measured).
The rule says a tracked root manifest is a declared deviation. Add to `.gbg/config.jl`, after the lines
`init` wrote, the switch that declares it, the three pages the build writes, which no rule may read,
and the Phenomenology exclusion:

```julia
switches = [
    Switch(target = Symbol("RULE.GIT.MANIFEST_TRACKED"), files = ["Manifest.toml"],
           reason = "the root Manifest is committed on purpose: it is the only place the unregistered GBGPeriodicFields git URL and pinned commit are recorded, so it must travel with the repo for a fresh clone or CI to resolve the dependency; nested environment manifests stay ignored"),
],
generated = ["docs/src/architecture.md", "docs/src/decisions.md", "docs/src/gbg.md"],
exclusions = [
    Exclusion(files = ["src/Phenomenology.jl", "src/phenomenology/**", "docs/src/phenomenology.md",
                       "docs/src/api/phenomenology/**", "test/phenomenology.jl"],
              reason = "the Phenomenology module is not held to the rulebook until it is extracted into its own package (the owner, 2026-09-29)"),
],
```

The switch's reason paraphrases the comment at the head of HT's `.gitignore`. **The switch is the
owner's to approve, before the wiring commit**; the exclusion is the owner's ruling already. The
script ran it without `test/phenomenology.jl`; added afterwards to the wired clone, it changed no
finding of `gbg check`, of `Pkg.test()` or of the docs build, measured. An excluded
file is read by no rule, and a name its module owns needs no link from anywhere else.

**Run `gbg sync` after every edit to `.gbg/config.jl`.** Measured: after this edit the wiring check
reports `.gbg/policy/switches.md` as stale, and `gbg sync` rewrites that one path.

Then record the prose baseline, which a first wiring does once:

```sh
gbg check --rebaseline
```

Measured: it writes `docs/prose_shape.csv`, 349 rows. Without it, `RULE.DOC.SHAPE` holds each of those
units to the rulebook's caps, and 143 of them exceed the caps. With it, each is held to its own size from
here on.

## Step 5 — the gate, then the wiring commit

```sh
julia +1.12 --project -e 'using Pkg; Pkg.test()'
julia +1.12 --project=docs docs/make.jl
gbg sync --check
```

Run it on Julia 1.12, HT's compat floor and the first lane of its CI; on 1.13 HT's own suite fails, as
below. Measured on Julia 1.12:

- `Pkg.test()` exits 0. It runs HT's own tests, then the rulebook's code rules and the wiring check, and
  prints `GBGCodingTools v2.0.0 checks — the config pins v2.0.0-rc.47`.
- The docs build exits 1 before building, on Step 6's findings and nothing else: no wiring finding.
- `gbg sync --check` says `19 generated path(s) and the pin are what v2.0.0-rc.47 writes`.

Commit the wiring on its own, before any finding is touched: Steps 1 to 4 and the edits of Step 3.
Stage with `git add -u`, plus the new paths by name: `.claude/hooks/`, `.claude/settings.json`,
`.claude/skills/`, `.gbg/`, `.github/actions/`, `docs/prose_shape.csv` and `test/regressions/README.md`.
Those seven are the rehearsal's untracked paths; nothing else untracked belongs in this commit. Measured:
the tree is clean after the commit, and `gbg sync --check` still is.

The commit's last line is the trailer `RULE.GIT.TRAILER` states, and nothing else:

```text
Co-Authored-By: Anthropic Claude <noreply@anthropic.com>
```

Your `CLAUDE.md` names a versioned trailer; the owner ruled the versionless one on 2026-09-08, and
Step 8 cuts that line.

**Do not push yet.** The push hook runs the docs build before every push a session makes, and a failing
build stops the push (the owner's ruling of 2026-09-29). Measured on the wiring commit: the hook stops
the push and lists the 129 findings of the build, and nothing else. The wiring commit goes out with the
fixes of Step 6. Until then `gbg check` also reports `RULE.GIT.PUSH`, "1 commit(s) not pushed", which
the push clears.

**On Julia 1.13**, HT's CI lane `'1'`: the docs build reports the same 129 findings, measured, and
`Pkg.test()` with four threads fails 13 tests in `test/memory_audit.jl`, at lines 719 and 740. That is
HT's own: the same 13 fail on HT's head unwired, measured in the rc.46 run. The suite stops there, before the tool's
checks at its end. What to do about it is for HT and the owner.

## Step 6 — 131 findings, then the push

The build reports 129. The site rules report 2 more, measured on a plain Documenter build of the same
pages: the real build stops before Documenter runs, so HT meets these two only once the 129 are gone.

Every one was checked against its rule's statement, one by one, at `f14c5a6`, by three verifiers, each
reading one share of them in the source at the rc.46 run, whose findings are these line for line: **all 131 are true**, and
each finding's line points at the defect, but for the two site findings, which name the built page. For an argument list the line is where the
defect begins: a list under "The arguments are" at that sentence, a list under another sentence at its
first bullet, and prose that should be a list at the docstring's opening line. The verdicts are
`verdicts-rc46.txt` in the evidence. By rule:

- **45 × `RULE.DOC.ARGS_FORM`.** 35 lists sit under a sentence, "The arguments are:" or another, with no
  `# Arguments` heading. 10 docstrings describe three or more arguments, or a keyword, in prose only.
  Argument lists are an `# Arguments` section (ruled 2026-09-28), a type's constructor arguments
  included, and several arguments may head one bullet together (ruled 2026-09-29).

- **16 × `RULE.CIT.FULL_INLINE`.** Full references in the running prose of `Forcing.jl`,
  `Observables.jl`, `Particles.jl`, `Propagator.jl` and `SimulationDomain.jl`. Cite author–year in the
  sentence and put the work under the docstring's `# References`.

- **13 × `RULE.DOC.XLINK`.** A name another HT module owns, bare at its first mention in a docstring.
  A name inside a code expression, as `helper(2x)`, owes no link; one on its own does.

- **13 × `RULE.DOC.SENTENCE_OPENER`.** A sentence opening with a code span, a formula or a lowercase
  link.

- **10 × `RULE.TEX.SPACING`.** Nine `\!` before a sized delimiter, one `\,` before a vector that is not
  a differential (`docs/ARCHITECTURE.md`, decision log).

- **9 × `RULE.DOC.REF_ABUT`.** A `@ref` link directly followed by a code span holding the call's
  arguments, with nothing between them.

- **5 × `RULE.DOC.SIBLING_LINK`.** Four first mentions of a sibling package are bare. One,
  `src/GBGHomogeneousTurbulence.jl`, links the repository instead of the site.

- **5 × `RULE.DOC.JULIA_MANUAL`.** Two docstrings use a keyword splat and three a `do` block without
  linking the Julia manual's section on it:
  [keyword arguments](https://docs.julialang.org/en/v1/manual/functions/#Keyword-Arguments) and
  [do-block syntax](https://docs.julialang.org/en/v1/manual/functions/#Do-Block-Syntax-for-Function-Arguments).

- **4 × `RULE.CIT.DOI`.** Entries in `docs/ARCHITECTURE.md`'s references with no link on the title. An
  entry that says "no DOI" may link its title to the work's stable public record (ruled 2026-09-28).
  Rogallo 1981 and Lundgren 2003 say they have no DOI. Carpenter & Kennedy 1994 says "outside the DOI
  system", and the rule looks for the words "no DOI", so it needs those words as well as the link. Lamb
  1932 is a book: an Open Library link does.

- **3 × `RULE.DOC.FIELDS`.** Every field is at the head of a bullet under `# Fields`, alone or with
  others (ruled 2026-09-29). `FlowConditions` describes its four fields in one sentence, with no
  bullets; `ResolvedGenerator`'s list leaves out two; `ObservablesCache` describes `history_steps` and
  `history_filled` inside another field's bullet.

- **2 × `RULE.DOC.SIGNATURE_MIRROR`.** `predicted_stationary_state`'s signature is 96 and 89 columns
  wide, over 88.

- **2 × `RULE.TEX.RENDERED_MARKUP`**, from the built site: bold nested in bold in the decision log, so
  the page shows literal `**`. The sources are `docs/ARCHITECTURE.md:1887–1888` (decision 53) and `:2343–2344`
  (decision 74).

- **One each.** `RULE.DOC.LINKS`: `DeferredForcing` is linked twice in `Simulation`. `INTERNAL_API`: an
  `@index` block on the umbrella's API page. `AI_BANNER`: `docs/ARCHITECTURE.md` has no provenance
  banner. `ARGCOV`: `Simulation`'s `kwargs...` is never named; a keyword splat is named as code like
  any argument (ruled 2026-09-29).

All the findings are documentation, and documentation is fixed without asking. A rule switched off,
for the whole package or for named files, is config, and that is the owner's. **Commit the fixes, run
the docs build until it exits 0, then push**: the hook runs the same build, on the default `julia`, and
lets the push through. Julia 1.13 reports the same findings, measured.

**Ask the owner before the first push.** The runners now fetch GBGCodingTools, a private repository.
Your workflows describe `GBG_DEPS_TOKEN` as a token that reads GBGPeriodicFields; it must also read
GBGCodingTools.jl, and only the owner can widen it. This was not measured: the rehearsal could not push.

## Step 7 — four decisions for the owner

**The harness contracts.** `RULE.TEST.ALLOC_ZERO`, `PASS_AUDIT`, `ORACLE_INDEPENDENT` and `METHOD_PARITY`
bind a package that declares them, by calling the tool's contract function from its suite.
GBGPeriodicFields declared all four on 2026-09-27, in commits `d139bafb`, `cee1ad73`, `c0125ece` and
`708161cf`: the worked example. HT's derived surface at `f14c5a6`, measured without Phenomenology, is 23
in-place operations, 53 value-returning ones and 25 types. It meets none of the four today. The tests were read at `c016f95`, in `ht-test-audit-c016f95.md` of
the evidence; between that head and `f14c5a6` no line of `test/` that measures an allocation changed:

- **Allocation (`allocation_completeness`):** 7 of the in-place operations are measured, with bounds
  at fractions of a field rather than zero, and nothing checks completeness against the exports.
- **Traffic (`traffic_completeness`):** `test/compute_audit.jl` freezes pass counts from a hand-written
  model, not per-operation runtime counts.
- **Oracle registry (`oracle_registry`):** nothing classifies the value-returning operations.
- **Method parity (`method_parity`):** only two per-function counts, in regressions.

`test/memory_audit.jl`'s residency ledgers, `audit_ops.jl`, `optimality_audit.jl` and `display.jl` are
HT's own and map to no contract. Whether HT declares a contract is the owner's; declaring binds HT to it.

**The disciplines.** A documentation review's readers include one expert per discipline a package
declares in `disciplines`. From the catalogue, HT's candidates are `:turbulence_theory` and
`:spectral_numerics`, the Fourier discipline GBGPeriodicFields also declares, and
`:software_architecture`, as GBGPeriodicFields has it. The owner chooses.

**HT's own docs lints**, run by `docs/make.jl` before the build. `docs/make.jl` is unchanged since
`c016f95`, where they were read; once the baseline of Step 4 is recorded, none of the rules
named below reports anything at rc.47. They read no excluded file, so Phenomenology's files, which HT's
lints do read, would lose those checks with the lints:

- `lint_inline_math` is replaced by `RULE.TEX.INLINE_ONE_LINE`.
- `lint_notation_variants` is replaced by `RULE.TEX.PARTIAL`, `MATHBF`, `FRAC_BRACED`,
  `BOLDSYMBOL_BRACED` and `MATHBB`.
- `lint_docstring_shape` and `docs/docstring_shape.csv` are partly replaced by `RULE.DOC.SHAPE`, which
  reads its own baseline. Its structure guards around `# Fields` have no program equivalent.
- `lint_lamb_vector_sign` is HT's own (decision 93), and it stays: a package pattern rule cannot express
  its window of lines.
- `lint_review_closure` reads the old review rounds under `.claude/`, which the tool's review replaces;
  it has nothing current to read once they go.

Which lints to delete is the owner's.

**The old instruments.** `.claude/` holds 278 tracked files: the in-tree instruments, their review data
and 11 request files. Deleting the instruments is Phase 7 of the tool's plan, after a documentation
review has run in HT and the owner has read its report, not now. The request files are not where
`RULE.GIT.REQUESTS` looks (`.gbg/requests/`, named `to-<PKG>-<date>-<topic>.md`, first paragraph
`Status:`). Moving or deleting them is the owner's.

## Step 8 — cut what `CLAUDE.md` restates of the rulebook

Once HT is wired, its `CLAUDE.md` imports the rulebook at its head, and restates parts of it below.
The measured list is `docs/design-record/HT-CLAUDE-CUT-2026-09-28.md` in this repository. It marks
every passage `DUPLICATE`, `TRIM` or `CONFLICT` and quotes its first words: 8 lines duplicate, 154 to
trim, 13 conflicting passages, by its own count, which counts a line in overlapping passages once.
It was measured on `c016f95` against rc.32's rulebook, and `CLAUDE.md` is unchanged at `f14c5a6`.

Work from the list, and check each item against the text before acting; it is a measurement, not a
ruling. Delete duplicates and cut trims as the list says.

The 13 conflicts are the 12 passages marked `CONFLICT` and one noted inside the `TRIM` of L350–354, the
no-`\mathbf` clause. Three are settled by the owner's rulings, each in the rule's favour, and the list
names them: argument lists, `\left`/`\right`, and the trailer. Put the other ten to the owner and change
nothing for them, less the part of L147–155 about Phenomenology's `[doi:…]` labels, which the
exclusion has made moot.

Rules changed after the list was measured: `ARGS_FORM`, `FIELDS`, `ARGCOV`, `XLINK`, `CIT.DOI`,
`HOME_ORDER`, `SIGNATURE_MIRROR` and `INST.CONSENT` were reworded, and `JULIA_MANUAL`, `FENCED_CODE`
and `LOCAL_PATH` are new. Re-read every item that cites one of them against the rc.47 text. These are
HT's own commits, after the wiring; `CLAUDE.md` is code, and the owner reviews the diff.

## Reporting a defect in this package

A tool defect, or a discipline the catalogue lacks, is a tracked file in HT:
`.gbg/requests/to-GBGCodingTools-<date>-<topic>.md`, with a status paragraph on top, deleted when it is
concluded. Never an edit in this package's repository from HT's session.
