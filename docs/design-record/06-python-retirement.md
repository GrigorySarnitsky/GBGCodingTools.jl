# Python retirement — owner-ordered (2026-09-08); mapping to apply together with IT's amendments

Principle: every deterministic engine is Julia inside the one package; JS only for Workflow scripts; sh only for the shim and the Stop hook (pure bash, no Julia at Stop time — IT's ruling). No Python anywhere, not even transitional, unless IT's list keeps consolidate.py (then it ships INSIDE the package as the one documented exception until the Gumbo/AbstractTrees port is byte-compared).

CLI: `gbg` stays the verb surface. The shim `~/.local/bin/gbg` (POSIX sh) resolves the pinned copy exactly as before, then execs
  `julia --startup-file=no --project="<pinned>/cli" -e 'using GBGCodingTools; exit(GBGCodingTools.CLI.main(ARGS))' -- "$@"`
where `<pinned>/cli/Project.toml` is a tiny app environment the package ships (depends on the package itself by relative `[sources] path = ".."`, plus TOML/SHA/Dates/JSON3/Gumbo). Startup 2–5 s accepted for every verb; the skill `!` block pays it once at load (IT accepted the same).
Modules: gbg/*.py → src/CLI/*.jl one-to-one (Doctor, Sync, Init, Fleet, Bump, Release, Install, Tree (git blob/tree hashing in Julia), Preflight, Rounds, Gate, Demote, Scan + Scans/<id>.jl, Seed, Recall, Consolidate, Witnesses, Audit, Hunt, Selftest); `run_gate` becomes an in-process call (no child process) — `GBGCodingTools.makedocs` calls `Gate.run(...)` directly and `error()`s on non-zero status.
Validator: ONE validator stays true — now Julia: JSONSchema.jl (maintained) over the TOML.parsefile Dict, or a typed `ConsumerConfig` struct with explicit unknown-key rejection if the bridge is awkward (IT's fallback). `Config.jl` no longer shells out.
Hook: `queue-guard.sh` pure bash (PF's existing script, stamped verbatim); `gbg hook queue-guard` verb deleted.
Scans: `catalog/scans.toml` stays the registry; each scan is a Julia function in `src/Scans/`; the "one text-scan engine" invariant is unchanged (Julia now, no Python twin).
Doctor: `ENV.PYTHON` deleted; `ENV.JULIA` (≥ 1.11, juliaup) kept; CI snippets drop the python3 step.
Selftest: `Pkg.test()` of the package IS the selftest (`gbg selftest` = a thin wrapper running Pkg.test on the pinned copy from a temp env); IT's ruling that selftest is not in preflight is already mine.
Cost note for the record: Python was chosen for 30 ms startup in `!` blocks and hooks; the hook is now bash (no cost) and the `!` block pays one Julia start per skill load — the trade the owner accepted by retiring Python.
