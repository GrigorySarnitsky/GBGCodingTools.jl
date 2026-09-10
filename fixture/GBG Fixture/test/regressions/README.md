<!-- gbg:managed regressions-README.md vdev — rewritten by `gbg sync`; do not edit -->
# `test/regressions/` — witnesses, promoted

Each file here began as a **witness** from `/bug-hunt`: a self-contained `@testset` asserting the
correct behaviour, written *before* the fix and **observed to fail** on the tree that had the defect.
It is promoted here **unchanged** when the fix lands, so the test that proves the fix is literally the
test that proved the bug.

That "unchanged" is the whole discipline. A witness edited to suit the fix has stopped being evidence:
it no longer records what was wrong, only what the fixer decided to assert afterwards. If a witness
needs changing to pass, the fix is wrong or the witness was — resolve that, do not adjust the test.

**Naming.** `<operation>-<one-line-symptom>.jl`, e.g. `weighted_inner-complex-weight-accepted.jl`.

**A file here must:**
- be runnable on its own (`julia --project test/regressions/<file>.jl`), since it was, as a witness;
- assert the correct behaviour against an **oracle** — an identity, a documented contract, a hand
  computation — never against another package operation alone (`RULE.TEST.ORACLE_INDEPENDENT`);
- carry a header comment naming the defect, the date, and the commit that fixed it.

`runtests.jl` includes every `.jl` file in this directory through
`GBGCodingTools.TestHarness.run_regressions(@__DIR__)`, so a promoted witness is a permanent gate.
The directory holds only this file until the first confirmed finding; that is the honest state, not a
gap.

**Two side directories, run only on request.** `escalated/` holds witnesses that failed on a defect
the package chose not to fix yet; each carries a header line `# overturn_when: <condition>` and is
re-run by `gbg doctor --deep`, which reports one that has started to pass. `blocked/` holds witnesses
that need a device this host lacks; each carries `# blocked: <reason>` and is re-run by `--deep` on a
host that has it. Neither is included by `runtests.jl`.
