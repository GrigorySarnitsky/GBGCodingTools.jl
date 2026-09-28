# Evidence behind `docs/PF-WIRING.md` (2026-09-28)

PF's upgrade from rc.30 to rc.36, rehearsed on a clone at PF's head `e395c0de`.

- `run.sh.txt` and `steps.txt` — the rehearsal and each step's exit code.
- `findings.txt` — the 85 findings of the docs build, the same on Julia 1.12 and 1.13.
- `verdicts-args.txt` and `verdicts-fields-argcov.txt` — each verifier's verdict on every finding.
- `test-113-failure.txt` — PF's own test that fails on Julia 1.13 and passes on 1.12.
- `check-rc30-same-head.txt` — `gbg check` under PF's rc.30 pin at the same head: clean.
