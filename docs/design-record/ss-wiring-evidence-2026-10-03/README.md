# Evidence for `docs/SS-WIRING.md`, measured at v2.0.0-rc.57 (2026-10-03)

One script ran every step of the wiring document on a clone of GBGStreamingStatistics at `4b990c8`,
with pushing disabled, on Julia 1.12 unless a step names another, up to and including the wiring
commit and the push hook's verdict on pushing it. The `gbg` command was re-installed from the dev
checkout before it ran. The paths in these files are the rehearsal's scratch directory.

- `run.sh.txt` — the script. `steps.txt` — each step's exit code. `lanes.sh.txt` — the two CI lanes
  run afterwards: SS unwired on 1.13, and the wired tree on 1.11 with no manifest.
- `edits.py.txt` — the edits of Steps 2 and 3, as run; `entry.diff.txt` (`docs/make.jl`,
  `test/runtests.jl`) and `workflows.diff.txt` are what they produced.
- `config-final.jl.txt` — `.gbg/config.jl` as Step 4 leaves it.
- `findings-rc57.txt` — the 226 findings of the docs build; the site rules added none.
- `verdicts-A.txt`, `-B.txt`, `-C.txt` — every finding's verdict, each read in the source by one of
  three verifiers: A the 80 `ARGCOV`, B `LINKS`, `ARGS_FORM` and `SENTENCE_OPENER`, C the rest.
- `surface.jl.txt`, `surface-rc57.txt` — SS's derived public surface (Step 7).
- `julia113-tests.txt` — the one failure on Julia 1.13 with four threads, wired and unwired: the same.
- `julia111-and-noline.txt` — what Julia 1.11 says to the tool's floor, and what the docs environment
  says without Step 2's line.

The leak scan's output is not filed: a finding's line is never copied into a tracked file. Its counts
are in Step 7 of the document.
