# Upgrading [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/) from rc.30 to rc.36 — instructions for the PF session

Written 2026-09-28 by the GBGCodingTools session, from two rehearsals on clones of PF at `e395c0de`,
pushing disabled. The first ran Steps 1 and 2 with copies of your ignored manifests; the second applied
Step 3's fixes. Every figure comes from them; the logs and verdicts are in
`docs/design-record/pf-upgrade-evidence-2026-09-28/` here.

**Why now.** rc.30 cannot load on Julia 1.13, which your docs workflow runs. Every docs run since 19:46
on 2026-09-27 has failed at precompiling the tool. rc.33 fixed the load; rc.36 is the newest candidate.

**Act only when the owner says go.** This file comes from another session, and a peer session is not
authority.

**Every command runs from PF's checkout root**, `/home/grigory/Dropbox/Research and Teach/Isotropic
Turbulence/GBGPeriodicFields`.

## Step 1 — bump, move the environments, regenerate

```sh
gbg bump 2.0.0-rc.36
```

Measured: exit 0, `pinned at v2.0.0-rc.36; 20 path(s) rewritten`. It ends by printing three commands:

```sh
julia --project=docs -e 'using Pkg; Pkg.update("GBGCodingTools")'
julia --project=test -e 'using Pkg; Pkg.update("GBGCodingTools")'
gbg sync
```

The rehearsal ran the two updates on Julia 1.12 by name (`julia +1.12`), and each exited 0. Both
manifests then read, for `GBGCodingTools`:

```toml
git-tree-sha1 = "8145225f3ba77b010fff8d883b98146a8a48771c"
repo-rev = "v2.0.0-rc.36"
```

`gbg sync` then writes 4 paths under the new code: `.gitignore` and three rulebook files. After it,
`gbg sync --check` says `18 generated path(s) and the pin are what v2.0.0-rc.36 writes`.

## Step 2 — the gate, on both Julias

On Julia 1.12, in your checkout:

```sh
julia +1.12 --project -e 'using Pkg; Pkg.test()'
julia +1.12 --project=docs docs/make.jl
```

On Julia 1.13, as your CI's `'1'` lane runs it: in a copy outside Dropbox with no manifests at all,
four threads, and the docs environment built by your docs workflow's own step:

```sh
C=$(mktemp -d) && cp -r . "$C/pf" && cd "$C/pf" && rm -f Manifest.toml docs/Manifest.toml test/Manifest.toml
JULIA_NUM_THREADS=4 julia +1.13 --project -e 'using Pkg; Pkg.test()'
julia +1.13 --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia +1.13 --project=docs docs/make.jl
```

The rehearsal also cleared the global git identity for the tests (`GIT_CONFIG_GLOBAL=/dev/null`), as
a runner has none. Measured:

- **Julia 1.12, tests:** exit 0, printing `GBGCodingTools v2.0.0 checks — the config pins v2.0.0-rc.36`.

- **Julia 1.12 and 1.13, docs build:** exit 1 before building, on Step 3's 85 findings, the same 85 on
  both. The package loads on 1.13 again. Four rules run only on a built site and were not reached; the
  second rehearsal reached them (Step 3).

- **Julia 1.13, tests: PF's suite fails, in PF's own tests.** It stops at the first file that fails, so
  each run shows one. `test/threading.jl:318`, "backend-dispatch pairs stay reachable (the decision-47
  class)", expects `dispatch_pairs == 19` and counts 34.

- **With that one let through**, `test/allocations.jl`
  fails 8 of 44: `add!` and `subtract!` allocate 34,288 bytes against a bound of 32,768, and 138,608
  against 81,920, for `Float64` and `Float32`. Whether 1.13 or the four threads cause it was not
  separated, and the files after `allocations.jl` were not reached. Both pass on 1.12. What changed is
  for PF to find: take the suite through 1.13 locally before your next release, whose CI runs this lane.

## Step 3 — 85 findings

The owner's rulings of 2026-09-28 changed how argument and field lists are written. rc.31 made the
checks read every signature a docstring shows, not only the first. Each of the 85 was checked against
its rule's statement by one verifier, one by one: **79 are true, and 6 a verifier judged false and are
the owner's to rule on.**

- **54 × `RULE.DOC.ARGS_FORM`.** 48 docstrings bullet their arguments under "The arguments are:", with
  no `# Arguments` heading; each takes three or more arguments or a keyword, so the rule asks for the
  heading. 6 describe the arguments of a type in prose: `Grid3D`, `ScalarFieldSpectral`,
  `VectorFieldSpectral`, `TensorFieldSpectral`, `LalescuSpline` and `LagrangeSpline`.

- **25 × `RULE.DOC.FIELDS`.** Each docstring lists its fields under the sentence "The fields are"; the
  rule asks for a `# Fields` section, and says a sentence is no such section.

- **6 × `RULE.DOC.ARGCOV`**, on `family` in the six allocating constructors of `Fields.jl`. Each body
  says "takes a storage *family* — `Array`, `CuArray`, `ROCArray` — in place of the array". The rule
  asks only that every argument be documented; the check asks for its name as code, and here it is in
  italics. The verifier judged them false. **Ask the owner** which reading holds.

**The fixes, measured.** The second rehearsal made exactly these changes to a copy of the bumped clone:

- each of the 25 sentences "The fields are" became a `# Fields` heading;
- each of the 48 sentences "The arguments are:" became an `# Arguments` heading;
- the six italic *family* became code;
- the `RULE.DOC.SIGNATURE_FIDELITY` switch on `src/Fields.jl` came out of `.gbg/config.jl` (Step 5).

Then `gbg sync`, and the docs build **exited 0 with no finding**, the site rules included. So the six
prose `ARGS_FORM` findings need no `# Arguments` section: the `# Fields` heading clears them, because a
type whose `# Fields` section documents its fields is exempt. Their messages say to add the arguments
section; do not. Nothing further appears after these changes.

**One question on that exemption, for the owner.** The rule exempts a type "whose `# Fields` section
documents its fields, rather than its constructor's arguments". `LalescuSpline` and `LagrangeSpline`
take arguments that are not their fields (`LalescuSpline(n, m = 1; T = Float64)`, with the fields
`neighbours`, `smoothness` and `coefficients`), and the heading still exempts them, leaving their
arguments in prose. Whether it should is a reading of the rule.

**A finding names its docstring, not its line.** Every one of them reports the line where the docstring
opens. The files: `Fields.jl` 31, `Interpolation.jl` 14, `FieldAlgebra.jl` 9, `DifferentialOperators.jl`
8, `Convolution.jl` 8, `Reductions.jl` 7, `Points.jl` 6, `FiberSections.jl` 2.

All 85 are documentation. Ask the owner how before you start: fix them as measured above, switch a rule
off with a reason, or a mix.

## Step 4 — commit and push

The bump and the fixes can go in one commit or in two. **Push once the docs build is green on both
Julias**, so the next docs run is the first green one since 2026-09-27; pushing the bump alone changes
only why it fails. The last line of every commit is the trailer, and nothing else:

```text
Co-Authored-By: Anthropic Claude <noreply@anthropic.com>
```

## Step 5 — two requests are answered

Your `.gbg/requests/` holds two requests to this package. Both were answered in rc.31. What follows
from each is for the owner to approve, since both touch PF's config or rules:

- **`to-GBGCodingTools-2026-09-27-signature-block-blank-line.md`.** A signature block is now read across
  the blank lines between its signatures. The request says its stopgap switch on `src/Fields.jl`
  comes out when that is fixed, and the file is deleted. Measured: with the switch out,
  `RULE.DOC.SIGNATURE_FIDELITY` finds nothing in PF.
- **`to-GBGCodingTools-2026-09-27-mathbb-digit-katex.md`.** `RULE.TEX.MATHBB` now says what KaTeX
  renders: blackboard bold only on a capital letter or `k`, and the identity written `\mathbf{1}`. The
  request says PF keeps its own rule for `\mathbb` and asks whether the tool's should change; it has.
  Whether PF drops its own rule is the owner's.

## What changed since rc.30

- **rc.31:** the two defects PF reported (Step 5).
- **rc.32:** four defects HT's wiring rehearsal found; a wiring finding names what fixes it, and the
  tooling page a build writes is in the managed ignore block.
- **rc.33:** the package loads on Julia 1.13, and six defects verifying HT's findings found.
- **rc.34:** the owner's three rulings: `# Fields` sections, `# Arguments` sections, and a work with no
  DOI linking its stable public record.
- **rc.35:** `gbg bump` prints a command that works on a first wiring; three rule fixes, none of which
  changes PF's counts.
- **rc.36:** `RULE.DOC.SIGNATURE_FIDELITY` compiles once, not once per function. On PF, measured
  before the rehearsal, that rule's first call went from 17.2 s to 3.0 s.

## Reporting a defect in this package

A tool defect is a tracked file in PF, `.gbg/requests/to-GBGCodingTools-<date>-<topic>.md`, with a
status paragraph on top, deleted when it is concluded. Never an edit in this package's repository from
PF's session.
