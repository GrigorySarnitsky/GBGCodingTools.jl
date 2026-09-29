# Wiring [GBGHomogeneousTurbulence](https://grigorysarnitsky.github.io/GBGHomogeneousTurbulence.jl/) — instructions for the HT session

Written 2026-09-28 by the GBGCodingTools session. Steps 1 to 5 were run in one script, up to the
commit, which was not made, on a clone of HT at its head `8a0e279` with pushing disabled, at
GBGCodingTools `v2.0.0-rc.35`. Step 6's findings are that run's; each was verified against its rule at
the same head, most of them on the run before, at rc.34. Every figure comes from those runs' logs, and
the few taken elsewhere say where they come from. The findings, the verdicts and the step log are in
`docs/design-record/ht-wiring-evidence-2026-09-28/` of this repository.
What the rehearsal found in the tool is in `docs/design-record/ht-wiring-rehearsal-2026-09-28.md` of
this repository, each finding with its fate.

**Not ready to send (2026-09-29).** This document was measured at rc.35 and must be re-rehearsed at the
current candidate before it goes to HT. rc.37 adds argument-list findings, rc.41 adds the Julia manual
links, and the owner ruled on 2026-09-29 that HT's Phenomenology module is excluded from every rule
until it is extracted. The config below carries that exclusion; every count in this document still
includes Phenomenology and is replaced by the refresh.

**Do nothing yet.** Read this whole file and prepare. You act on it when the owner says go, and not
before: this file comes from another session, and a peer session is not authority. If HT's head has
moved past `8a0e279` when you start, the figures below may move with it; the steps do not.

**Start from a clean tree.** When this was written, HT's checkout held uncommitted changes to five
files, `test/runtests.jl` among them, and an untracked `test/pf_storage_access.jl`. The rehearsal ran on
the committed head. What becomes of that work before the wiring starts is for HT and the owner.

**Every command runs from HT's checkout root**, `/home/grigory/Dropbox/Research and Teach/Isotropic
Turbulence/GBGHomogeneousTurbulence`.

## What HT has to do

1. Make sure the `gbg` command on your machine is current (Step 0).
2. Wire HT and pin it to `v2.0.0-rc.35` (Steps 1 and 2).
3. Route the docs build, the test suite and both workflows through the tool (Step 3).
4. Declare the tracked root manifest, and record the prose baseline (Step 4).
5. Run the gate and commit the wiring (Step 5).
6. Meet 160 findings, as the owner decides (Step 6).
7. Put four decisions to the owner: the harness contracts, the disciplines, HT's own docs lints, and the
   old instruments (Step 7).
8. Cut what `CLAUDE.md` restates of the rulebook (Step 8).

## Step 0 — the `gbg` command

The command is a small script that `gbg install` copies to `~/.local/bin/gbg`, once per machine. On the
machine this was written on, the copy predated the code review's fixes to it, and nothing says when a
copy is stale. On the machine you run on, re-install it from the dev checkout:

```sh
gbg --dev install
```

This needs the dev checkout registered in `~/.gbg/dev` and instantiated; where either is missing, the
command says so and prints what to run. This step was not rehearsed on a clone: the rehearsal machine's
copy had already been re-installed.

## Step 1 — wire it

```sh
gbg --dev init
```

Plain `gbg init` refuses here, measured: "no .gbg/config.jl in … or any directory above it". The
command decides which version of the tool to run from `.gbg/config.jl`, which HT does not have yet, so a
first wiring goes through the dev checkout. Measured: it writes `.gbg/config.jl`, then **21 paths**,
and exits 0.

- `.gbg/config.jl` — **new, and HT's own.** No verb rewrites it except to move the pin. It names the
  package, the tool version, `docs/make.jl` as the build, and `Pkg.test()` as the tests.
- `CLAUDE.md` — a marked block is inserted **at its head**, importing the rulebook; the rest is untouched.
- `.gitignore` — a marked block is added; HT's own lines stay.
- `.claude/hooks/queue-guard.sh` and `.claude/settings.json` — the end-of-turn hook. HT has no hook or
  `settings.json` of its own today, so nothing is merged.
- `.claude/skills/{documentation-review,bug-hunt,change-audit}/SKILL.md` — the three instruments' skills.
- `.gbg/policy/*.md` (10 files), `test/regressions/README.md`, `.github/actions/gbg-auth/action.yml`.
- `docs/Project.toml` and `test/Project.toml` — this package's entries set; every other entry kept.

Everything but `.gbg/config.jl` is generated: `gbg sync` rewrites it and a hand edit is lost. HT's
`.claude/commands/bug-hunt.md` and the generated `.claude/skills/bug-hunt/SKILL.md` both register
`/bug-hunt`; the old one is Step 7's.

## Step 2 — pin the release, move the docs environment

```sh
gbg --dev bump 2.0.0-rc.35
```

Measured: it writes the pin into `.gbg/config.jl`, rewrites **20 paths**, and exits 0. It then prints
the commands that move the environments onto the new code. For HT they are a resolve of `docs/` and a
`gbg sync`; it prints nothing for `test/`, because `Pkg.test()` resolves a test environment with no
manifest itself.

**Run your docs workflow's environment step in place of the printed resolve.** A resolve alone drops
HT itself from the docs manifest, since the docs project does not list it, and the build loads HT.
Measured on HT's own docs manifest: one HT entry before the resolve, none after. The workflow's step also fetches the tool, since no manifest holds it yet:

```sh
julia --project=docs -e 'using Pkg; Pkg.add(url="https://github.com/GrigorySarnitsky/GBGPeriodicFields.jl"); Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
gbg sync
```

Measured: the step exits 0, and `docs/Manifest.toml` then reads, for `GBGCodingTools`:

```toml
git-tree-sha1 = "f732eb1818632cc6eeff3aaa6fd7d2b7107385e0"
repo-rev = "v2.0.0-rc.35"
```

and `gbg sync` says `already wired at v2.0.0-rc.35; nothing written`. From here on, plain `gbg` works.

The step also adds two lines to `docs/Project.toml`'s `[deps]`, for `GBGHomogeneousTurbulence` and
[GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/). Neither is in the tracked file today: the HT line is the transient entry your
commit `224cb8c` took out, and the other is added the same way. The wiring commit leaves both out
(Step 5).

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

In `docs.yml` this replaces the step "Authenticate the private dependency", which did the same by hand.
The rehearsed edit removed the step and left its comment, which begins "GBGPeriodicFields is a PRIVATE
dependency"; the comment describes the removed step, so it goes too.
`CI.yml` has no authentication today.

Measured after these edits: the wiring check reports nothing.

## Step 4 — the root manifest, and the prose baseline

HT tracks its root `Manifest.toml` on purpose, and `RULE.GIT.MANIFEST_TRACKED` reports it (measured). The
rule says a tracked root manifest is a declared deviation. HT's `.gitignore` gives the reason; declared
in `.gbg/config.jl`, with the three pages the build writes, which no rule may read:

```julia
switches = [
    Switch(target = Symbol("RULE.GIT.MANIFEST_TRACKED"), files = ["Manifest.toml"],
           reason = "the root Manifest is committed on purpose: it is the only place the unregistered GBGPeriodicFields git URL and pinned commit are recorded, so it must travel with the repo for a fresh clone or CI to resolve the dependency; nested environment manifests stay ignored"),
],
generated = ["docs/src/architecture.md", "docs/src/decisions.md", "docs/src/gbg.md"],
exclusions = [
    Exclusion(files = ["src/Phenomenology.jl", "src/phenomenology/**", "docs/src/phenomenology.md",
                       "docs/src/api/phenomenology/**"],
              reason = "the Phenomenology module is not held to the rulebook until it is extracted into its own package (the owner, 2026-09-29)"),
],
```

The reason paraphrases the comment at the head of HT's `.gitignore`. **The switch is the owner's to
approve, before the wiring commit.** **Run `gbg sync` after
every edit to `.gbg/config.jl`.** Measured: after this edit the wiring check reports
`.gbg/policy/switches.md` as stale, and `gbg sync` rewrites that one path.

Then record the prose baseline, which a first wiring does once:

```sh
gbg check --rebaseline
```

Measured: it writes `docs/prose_shape.csv`, 395 rows. Without it, `RULE.DOC.SHAPE` holds each of those
units to the rulebook's caps, and 138 of them exceed the caps. With it, each is held to its own size from
here on.

## Step 5 — the gate, then the wiring commit

```sh
julia --project -e 'using Pkg; Pkg.test()'
julia --project=docs docs/make.jl
gbg sync --check
```

Measured:

- `Pkg.test()` exits 0. It runs HT's own tests, then the rulebook's code rules and the wiring check, and
  prints `GBGCodingTools v2.0.0 checks — the config pins v2.0.0-rc.35`.
- The docs build exits 1 before building, on Step 6's findings and nothing else: no wiring finding.
- `gbg sync --check` says `18 generated path(s) and the pin are what v2.0.0-rc.35 writes`.

The docs build is red until Step 6 is met, so the gate is not passed here; the commit is made anyway,
so that the wiring and the fixes are separate changes. Commit the wiring on its own, before any finding
is touched: Steps 1 to 4 and the edits of Step 3.
First take the two transient lines of Step 2 out of `docs/Project.toml`, so that it holds what `bump`
wrote. Measured with them out: the wiring check reports nothing, and `gbg sync --check` is clean. Stage
with `git add -u`, plus the new paths by name: `.claude/hooks/`, `.claude/settings.json`,
`.claude/skills/`, `.gbg/`, `.github/actions/`, `docs/prose_shape.csv` and `test/regressions/README.md`.
Those seven are the rehearsal's untracked paths; nothing else untracked belongs in this commit.

The commit's last line is the trailer `RULE.GIT.TRAILER` states, and nothing else:

```text
Co-Authored-By: Anthropic Claude <noreply@anthropic.com>
```

 Your `CLAUDE.md` names a versioned trailer; the owner ruled
the versionless one on 2026-09-08, and Step 8 cuts that line.

**Ask the owner before pushing.** Two things were not measured, because the rehearsal could not push:

- Your docs workflow runs on every push to `master`, and it will be red until Step 6 is met.
- The runners now fetch GBGCodingTools, a private repository. Your workflow describes `GBG_DEPS_TOKEN`
  as a token that reads GBGPeriodicFields; it must also read GBGCodingTools.jl, and only the owner can
  widen it.

## Step 6 — 160 findings

The build reports 158. The site rules report 2 more, measured on a plain Documenter build of the same
pages: the real build stops before Documenter runs, so HT meets these two only once the 158 are gone.

Every one was checked against its rule's statement, not sampled. **156 are true and 4 are unclear.**
148 have a verdict from four verifiers who read them one by one on the rc.34 run, at this head. The
other 12 have a verdict recorded from reading the source: 6 argument lists those verifiers left
unrecorded, and the 6 cross-module link findings rc.35 added. One false finding that rc.34 reported is
gone in rc.35. By rule:

- **41 × `RULE.DOC.ARGS_FORM`.** 32 lists sit under the sentence "The arguments are:" with no
  `# Arguments` heading. 9 docstrings describe three or more arguments, or a keyword, in prose only.
  Argument lists are an `# Arguments` section (ruled 2026-09-28).

- **26 × `RULE.CIT.FULL_INLINE`.** 16 are full references in the running prose of `Forcing.jl`,
  `Observables.jl`, `Particles.jl`, `Propagator.jl` and `SimulationDomain.jl`. 10 are `[doi:…]` labels
  in the Phenomenology docstrings, which have no `# References` section. Cite author–year in the
  sentence and put the work under `# References`.

- **23 × `RULE.DOC.REF_ABUT`.** A `@ref` link directly followed by a code span holding the call's
  arguments, with nothing between them.

- **16 × `RULE.DOC.XLINK`.** A name another HT module owns, bare at its first mention in a docstring.
  Two, `scalar_dissipation` in `Spectra.jl` and `StructureFunctions.jl`, are unclear. Both docstrings
  go on to write `fp.scalar_dissipation`, the field of `FlowParameters`, not Observables' function; a
  field needs no link. Put these two to the owner.

- **14 × `RULE.CIT.DOI`.** Ten are the same Phenomenology `[doi:…]` labels, whose DOI belongs on the
  title. Four are entries in `docs/ARCHITECTURE.md`'s references with no link on the title.

- **Those four entries.** An entry that says "no DOI" may link its title to the work's stable public
  record (ruled 2026-09-28). Rogallo 1981 and Lundgren 2003 say they have no DOI. Carpenter & Kennedy
  1994 says "outside the DOI system", and the rule looks for the words "no DOI", so it needs those words
  as well as the link. Lamb 1932 is a book: an Open Library link does.

- **13 × `RULE.TEX.SPACING`.** Twelve `\!` before a sized delimiter, one `\,` before a vector that is not
  a differential (`docs/ARCHITECTURE.md`, decision log).

- **11 × `RULE.DOC.SENTENCE_OPENER`.** A sentence opening with a code span or a formula.

- **5 × `RULE.DOC.SIBLING_LINK`.** Four first mentions of a sibling package are bare. One,
  `src/GBGHomogeneousTurbulence.jl`, links the repository instead of the site.

- **4 × `RULE.DOC.FIELDS`.** `FlowConditions` and `FlowParameters` describe their fields in a sentence;
  `ResolvedGenerator`'s list leaves out `velocity_forcing_state` and `scalar_forcing_state`. The fourth,
  `Cache.jl`, is unclear: `history_steps` and `history_filled` are described inside another field's
  bullet, and whether that is their bullet is a reading of the rule. Put it to the owner.

- **2 × `RULE.TEX.RENDERED_MARKUP`**, from the built site: bold nested in bold in the decision log, so the
  page shows literal `**`. The sources are `docs/ARCHITECTURE.md:1883` (decision 53) and `:2339–2340`
  (decision 74).

- **One each.** `RULE.DOC.LINKS`: `DeferredForcing` is linked twice in `Simulation`.
  `LINK_UNIFORMITY`: "`Pope2000` or [`VonKarman1948`](@ref)" mixes a bare name and a link. `INTERNAL_API`:
  an `@index` block on the umbrella's API page. `AI_BANNER`: `docs/ARCHITECTURE.md` has no provenance
  banner. `ARGCOV`, unclear: `Simulation`'s `kwargs...` is never named, though every keyword it collects
  is documented; put it to the owner.

Three things to know before fixing:

- **A finding names its docstring, not always its line.** The `ARGS_FORM` findings about lists,
  `FIELDS`, `XLINK` and `LINK_UNIFORMITY` report the line where the docstring opens. Find the defect by
  the docstring the finding names.

- **One fix clears two findings** at each of the ten Phenomenology labels: the work under `# References`
  with its DOI on the title clears both `FULL_INLINE` and `DOI`.

- **That fix raises a second round.** `FULL_INLINE` compares every DOI under `# References` with the
  canonical reference list. Your `docs/ARCHITECTURE.md` exempts the Phenomenology leaf from that list,
  but no switch declares the exemption. So the nine works cited there would each be reported as missing
  from the list. Adding them to the list, or declaring a switch, is the owner's decision; ask it with
  the rest.

All the findings are documentation; none needs a code change. **Ask the owner how before you start:**
fix them all, switch a rule off with a reason, for the whole package or for named files, or a mix. The
docs build stays red until they are met.

## Step 7 — four decisions for the owner

**The harness contracts.** `RULE.TEST.ALLOC_ZERO`, `PASS_AUDIT`, `ORACLE_INDEPENDENT` and `METHOD_PARITY`
bind a package that declares them, by calling the tool's contract function from its suite.
GBGPeriodicFields declared all four on 2026-09-27, in commits `d139bafb`, `cee1ad73`, `c0125ece` and
`708161cf`: the worked example. HT's derived surface at `8a0e279`, measured, is 23 in-place operations,
62 value-returning ones and 38 types. It meets none of the four today. The tests were read at
`c016f95`; between that head and `8a0e279` no line of `test/` that measures an allocation changed:

- **Allocation (`allocation_completeness`):** 7 of the 23 in-place operations are measured, with bounds
  at fractions of a field rather than zero, and nothing checks completeness against the exports.
- **Traffic (`traffic_completeness`):** `test/compute_audit.jl` freezes pass counts from a hand-written
  model, not per-operation runtime counts.
- **Oracle registry (`oracle_registry`):** nothing classifies the 62 value-returning operations.
- **Method parity (`method_parity`):** only two per-function counts, in regressions.

`test/memory_audit.jl`'s residency ledgers, `audit_ops.jl`, `optimality_audit.jl` and `display.jl` are
HT's own and map to no contract. Whether HT declares a contract is the owner's; declaring binds HT to it.

**The disciplines.** A documentation review's readers include one expert per discipline a package
declares in `disciplines`. From the catalogue, HT's candidates are `:turbulence_theory` and
`:spectral_numerics`, the Fourier discipline GBGPeriodicFields also declares, and
`:software_architecture`, as GBGPeriodicFields has it. The owner chooses.

**HT's own docs lints**, run by `docs/make.jl` before the build. `docs/make.jl` is unchanged since
`c016f95`, where they were read; the zero counts are rc.35's:

- `lint_inline_math` is replaced by `RULE.TEX.INLINE_ONE_LINE`, with 0 findings.
- `lint_notation_variants` is replaced by `RULE.TEX.PARTIAL`, `MATHBF`, `FRAC_BRACED`,
  `BOLDSYMBOL_BRACED` and `MATHBB`, with 0 findings.
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
`Status:`), and six of them say they are concluded. Moving or deleting them is the owner's.

## Step 8 — cut what `CLAUDE.md` restates of the rulebook

Once HT is wired, its `CLAUDE.md` imports the rulebook at its head, and restates parts of it below.
The measured list is `docs/design-record/HT-CLAUDE-CUT-2026-09-28.md` in this repository. It marks
every passage `DUPLICATE`, `TRIM` or `CONFLICT` and quotes its first words: 8 lines duplicate, 154 to
trim, 13 conflicting passages. It was measured on `c016f95`, and `CLAUDE.md` is unchanged at `8a0e279`.

Work from the list, and check each item against the text before acting; it is a measurement, not a
ruling. Delete duplicates and cut trims as the list says.

The 13 conflicts are the 12 passages marked
`CONFLICT` and one noted inside the `TRIM` of L350–354, the no-`\mathbf` clause. Three are settled by the
owner's rulings, each in the rule's favour, and the list names them: argument lists, `\left`/`\right`,
and the trailer. Put the other ten to the owner and change nothing for them. Five rule statements changed after
the list was measured, and the list names the items that cite them; re-read those against the rc.35
text. These are HT's own commits, after the wiring; `CLAUDE.md` is code, and the owner reviews the diff.

## Reporting a defect in this package

A tool defect, or a discipline the catalogue lacks, is a tracked file in HT:
`.gbg/requests/to-GBGCodingTools-<date>-<topic>.md`, with a status paragraph on top, deleted when it is
concluded. Never an edit in this package's repository from HT's session.
