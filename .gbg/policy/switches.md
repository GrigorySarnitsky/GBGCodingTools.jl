<!-- gbg:managed begin vdev — rewritten by `gbg sync`; do not edit -->
# What GBGCodingTools has switched off

Each entry names a rule this package does not hold itself to, and why. A rule listed
here is read as the entry states it.

- `RULE.GIT.TRACKED` — the toy consumer package the tool's tests run over: a package of its own, tracked as the tests' input (`fixture/**`)
- `RULE.GIT.TRACKED` — the commit gate (`tools/floor.sh`) and the fleet sweep (`tools/fleet.jl`) every commit of this package runs (`tools/**`)
- `RULE.GIT.TRACKED` — the `gbg` launcher that `gbg install` copies onto each machine (`bin/**`)
- `RULE.GIT.TRACKED` — the one Workflow driver every review launches its agents through (`drivers/**`)
- `RULE.GIT.TRACKED` — the first-install script that puts the `gbg` command on a machine (`install.sh`)
- `RULE.GIT.TRACKED` — the sweep state `gbg fleet` reads: when a release leaves the fleet at two versions, and since when (`fleet.toml`)
- `RULE.GIT.TRACKED` — the plan of the rebuild, phase by phase, with each phase's gate (`IMPLEMENTATION.md`)
- `RULE.TEST.EXAMPLES_RUN` — this package ships no Literate examples: a worked example of a review instrument is a review, which is recorded rather than executed as a script (the whole package)
- `RULE.DOC.LEADING_IDENTITY` — the leading identity of a docstring is the physical meaning of the quantity it computes; this package computes no physical quantity, so its docstrings lead with what the operation does, which the rule's own parameter already admits (the whole package)
- `documentation_review` — the review reads a package's documentation with the rulebook this package writes; running it here while the rulebook and the run machinery are still being built would grade the tool against rules it is in the middle of changing. It is switched on in Phase 8, when the tool reviews itself last (the whole package)
- `RULE.LEAK.HOME_PATH` — internal records no user reads, holding the checkout and scratch paths of how the work was done; credentials, files never published, addresses, private terms and manifest paths are still checked there (the owner, 2026-10-03) (`docs/design-record/**`, `docs/PF-WIRING.md`, `docs/HT-WIRING.md`)
- `RULE.LEAK.SYNCED_PATH` — internal records no user reads, holding the checkout and scratch paths of how the work was done; credentials, files never published, addresses, private terms and manifest paths are still checked there (the owner, 2026-10-03) (`docs/design-record/**`, `docs/PF-WIRING.md`, `docs/HT-WIRING.md`)
- `RULE.LEAK.SCRATCH_PATH` — internal records no user reads, holding the checkout and scratch paths of how the work was done; credentials, files never published, addresses, private terms and manifest paths are still checked there (the owner, 2026-10-03) (`docs/design-record/**`, `docs/PF-WIRING.md`, `docs/HT-WIRING.md`)
- `RULE.LEAK.SESSION_LINK` — internal records no user reads, holding the checkout and scratch paths of how the work was done; credentials, files never published, addresses, private terms and manifest paths are still checked there (the owner, 2026-10-03) (`docs/design-record/**`, `docs/PF-WIRING.md`, `docs/HT-WIRING.md`)
- `RULE.LEAK.HOME_PATH` — invented test data: made-up user names, documentation domains, a made-up session id, the scan's own patterns — each line read and confirmed invented on 2026-10-03 (`test/leak.jl`, `test/publication.jl`, `test/rules.jl`, `test/scope.jl`, `src/Rules/leaks.jl`, `src/Rules/judgement_git.jl`)
- `RULE.LEAK.SYNCED_PATH` — invented test data: made-up user names, documentation domains, a made-up session id, the scan's own patterns — each line read and confirmed invented on 2026-10-03 (`test/leak.jl`, `test/publication.jl`, `test/rules.jl`, `test/scope.jl`, `src/Rules/leaks.jl`, `src/Rules/judgement_git.jl`)
- `RULE.LEAK.SESSION_LINK` — invented test data: made-up user names, documentation domains, a made-up session id, the scan's own patterns — each line read and confirmed invented on 2026-10-03 (`test/leak.jl`, `test/publication.jl`, `test/rules.jl`, `test/scope.jl`, `src/Rules/leaks.jl`, `src/Rules/judgement_git.jl`)
- `RULE.LEAK.SCRATCH_PATH` — invented test data: made-up user names, documentation domains, a made-up session id, the scan's own patterns — each line read and confirmed invented on 2026-10-03 (`test/leak.jl`, `test/publication.jl`, `test/rules.jl`, `test/scope.jl`, `src/Rules/leaks.jl`, `src/Rules/judgement_git.jl`)
- `RULE.LEAK.EMAIL` — invented test data: made-up user names, documentation domains, a made-up session id, the scan's own patterns — each line read and confirmed invented on 2026-10-03 (`test/leak.jl`, `test/publication.jl`, `test/rules.jl`, `test/scope.jl`, `src/Rules/leaks.jl`, `src/Rules/judgement_git.jl`)

Deferred, not switched off: each of these is owed here and not yet met, and reports nothing
until the package meets it. What would close each is stated.

- `RULE.API.POSITIONAL` — until this package's own documentation review runs, in Phase 8: no program decides which arguments are required or select a method, and the reader that does has not read this package yet

<!-- gbg:managed end -->
