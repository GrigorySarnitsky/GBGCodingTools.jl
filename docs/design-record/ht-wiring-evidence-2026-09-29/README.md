# Evidence for `docs/HT-WIRING.md`, measured at v2.0.0-rc.47 (2026-09-29)

One script ran every step of the wiring document on a clone of GBGHomogeneousTurbulence at `f14c5a6`,
with pushing disabled, on Julia 1.12 unless a step names 1.13, up to and including the wiring commit and
the push hook's verdict on pushing it. The `gbg` command was re-installed from the dev checkout before
it ran. The paths in these files are the rehearsal's scratch directory.

- `rc47-run.sh.txt` — the script. `rc47-steps.txt` — each step's exit code.
- `docs-project-edit.py.txt` — the four lines Step 2 adds to `docs/Project.toml`, as run.
- `entry.diff.txt` — the edits to `docs/make.jl` and `test/runtests.jl` (Step 3).
- `workflows.diff.txt` — the edits to both workflows (Step 3).
- `findings-rc47.txt` — the 129 findings of the docs build and the 2 of the site rules.
- `verdicts-rc46.txt` — every finding's verdict at the rc.46 run, each finding read in the source by one
  of three verifiers. The rc.47 run's findings are the rc.46 run's, line for line: rc.47 changed two rules' wording and
  no check.
- `docs-build-without-step2-lines.txt` — the docs build of the wired clone with `docs/Project.toml` as
  `bump` wrote it, without Step 2's lines.
- `surface.jl.txt`, `surface-rc47.txt` — HT's derived public surface, with and without Phenomenology.
- `julia113-tests.txt` — HT's suite on Julia 1.13 with four threads, unwired (at the rc.46 run) and
  wired at rc.47: the same 13 failures in `test/memory_audit.jl`.
- `test-exclusion.txt` — the exclusion widened by `test/phenomenology.jl` after the run, measured on the
  wired clone.
- `ht-test-audit-c016f95.md` — HT's tests read against the four harness contracts, at `c016f95` and
  rc.31 (Step 7).
