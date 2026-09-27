# Code review of 2026-09-26 — the record

The full code review the owner asked for before PF bumps and HT is wired, over commit `9a81d50`
(`v2.0.0-rc.27`). Eight independent reviewers, one per module group, each reading its files whole
against `docs/ARCHITECTURE.md` and the invariants of `CLAUDE.md`, returning findings with quoted
evidence (the brief is in the session's scratch; its rules: a defect is a concrete input for which the
code does the wrong thing, style is not a finding, evidence is quoted or the finding is discarded).

"Fixed in the review commit" is the commit titled "The code review of 2026-09-26: 138 of 143 findings
fixed" (a commit cannot name its own hash). EVERY finding is recorded here, verified against the code by this session before anything is changed,
and given a fate: `fixed <commit>`, `refused <why>`, or `owner` (a decision that is his). The owner
asked for this so that "later you can check if you actually fixed them all": a finding without a fate
here is an open one.

Groups: A Render/ext/Wire · B Docfix/Check/Answer/Guard/Questions/Checks · C the upkeep verbs and the
shim · D Model/ConfigIO/Catalogue/Harness/TestHarness/Witnesses/Roles · E Rules (rendering, latex,
docstrings, arguments, reflection, modules) · F Rules (pages, citations, shape, site, questions,
judgement_*) · G Texts · H the run path since rc.24.

## Group A — Render, the extension, Wire (15 findings)

### A-1: The first `gbg init` never checks collisions, so it silently overwrites the package's own files at generated paths
- file: src/CLI/Wire.jl:62 · severity: major · confidence: confirmed
- evidence: `if isfile(path)` … `clash = Render.collisions(cfg, root)` — the collision check sits inside the branch taken only when `.gbg/config.jl` already exists; the first run falls through to `write(path, …)` then `return sync(root; io)`.
- failure: a package with no config, holding its own `.claude/skills/bug-hunt/SKILL.md` and `.github/actions/gbg-auth/action.yml` → `Wire.init` exits 0 and both files are replaced by generated text (reproduced) → ARCHITECTURE §11 says init "never overwrites what the package wrote itself … prints the difference for each collision and exits 1". The docstring says exit "0 … 2" while the re-run collision path returns 1.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `init` runs the collision check on the first run too, against the config it would write; a refusal writes nothing.

### A-2: `gbg sync` overwrites a package's own file at any generated path, so a path added in a newer version replaces a hand-written file on upgrade
- file: src/Render.jl:1489 · severity: major · confidence: confirmed
- evidence: `isfile(full) && read(full, String) == want && continue` / `write(full, want)` — no `generated_here` test; `Wire.sync` calls `write_all` with no collision check.
- failure: wired package, owner adds `test/regressions/README.md` of his own (or the tool adds a new generated path in the version he upgrades to) → `gbg sync` exits 0 and the file is replaced (reproduced); the same package's re-run `init` refuses it with exit 1.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `write_all` never overwrites a whole file that fails `generated_here`; `sync` prints the refused paths and exits 1.

### A-3: `gbg init` run from inside `docs/` still wires `docs/` as a package called `docs`
- file: src/CLI/Wire.jl:144 · severity: major · confidence: confirmed
- evidence: `while !isfile(joinpath(root, "Project.toml"))` — every consumer's `docs/` holds a `Project.toml`, so the loop stops at once; `name` is empty and falls back to `basename(abspath(root))`.
- failure: `cd PF/docs; gbg init` → `docs/.gbg/config.jl` written with `package = "docs"` (reproduced; exit 2 from the following sync).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `Wire.package_root` stops only at a `Project.toml` that has a `name`.

### A-4: `write_pin` crashes on any sub-environment `Project.toml` holding a non-string value, so `gbg sync`/`init` exit 3 instead of 2
- file: src/Render.jl:428 · severity: major · confidence: confirmed
- evidence: `println(io, k, " = ", v isa AbstractDict ? … : repr(String(v)))` and `for k in sort!(collect(keys(proj[sec])))` — the whole file is re-serialised by hand; only strings and one-level string dicts are handled.
- failure: `test/Project.toml` with `[targets]\ntest = ["Test"]` → `MethodError: no method matching String(::Vector{String})`; a top-level `description = "x"` → `keys` walks the string (both reproduced).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `write_pin` writes with `TOML.print`; `[targets]` and `description` kept; fixture files byte-identical.

### A-5: A managed block that ends the file without a trailing newline is drift `gbg sync` cannot repair and does not report
- file: src/Render.jl:1185 · severity: minor · confidence: confirmed
- evidence: `return join(lines[first_i:last_i], '\n') * "\n"` then `replace(text, have => want)`; `new == text && continue`.
- failure: `.gitignore` = `"mine/\n" * chomp(stale block)` → `replace` matches nothing, sync prints "already wired; nothing written", while `wiring` keeps reporting drift (reproduced).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the block is found and replaced by line range (`block_spans`, `with_block`).

### A-6: `block_of` takes the first line that mentions the begin marker, so a package's own prose above the block is eaten on sync
- file: src/Render.jl:1182 · severity: minor · confidence: confirmed
- evidence: `first_i = findfirst(l -> occursin(BEGIN_MARK, l), lines)` … `replace(text, have => want)`.
- failure: `CLAUDE.md` whose own text mentions "`gbg:managed begin`" above the block → after `gbg sync` that paragraph is gone (reproduced).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a marker line must be a comment opener followed by the marker.

### A-7: A file that holds the block twice keeps both after sync, and the wiring check reads it as clean
- file: src/Render.jl:1485 · severity: minor · confidence: confirmed
- evidence: `replace(text, have => want)` replaces every occurrence; `block_of` compares only the first.
- failure: `.gitignore` with the block twice → sync rewrites both, marker count stays 2, `wiring` reports nothing (reproduced).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `with_block` drops a second block; the wiring check reports a repeated block.

### A-8: `write_settings` crashes on an unparsable `.claude/settings.json` instead of exit 2
- file: src/Render.jl:267 · severity: minor · confidence: confirmed
- evidence: `settings_drift(root) === nothing && return false` (returns "does not parse" here, so it does not return) then `JSON3.read(...)` with no catch.
- failure: `settings.json` = `{ not json` → `ArgumentError` out of `gbg sync` (reproduced), exit 3 with a backtrace.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — an unparsable `settings.json` is a `ConfigError`, exit 2, not rewritten.

### A-9: The settings merge matches one literal spelling, so a hook entry in any other spelling is kept and a second one added
- file: src/Render.jl:249 · severity: minor · confidence: confirmed
- evidence: `get(h, "command", "") == HOOK_COMMAND && return nothing` and `push!(stops, …)` — nothing removes a stale `queue-guard.sh` entry.
- failure: existing entry `"$CLAUDE_PROJECT_DIR/.claude/hooks/queue-guard.sh"` (no inner quotes) → after sync `Stop` holds 2 entries (reproduced); the hook runs twice per stop.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — any Stop entry ending in `queue-guard.sh` is replaced by the one written entry; drift reports duplicates.

### A-10: `ci_drift` reports every workflow, not the ones that resolve this package, so a standard TagBot workflow turns the suite and the build red
- file: src/Render.jl:515 · severity: major · confidence: confirmed
- evidence: `occursin("./.github/actions/gbg-auth", …) && continue` — the only exemption; the docstring says "Every GitHub workflow … that resolves this package without authenticating first".
- failure: released pin + `.github/workflows/TagBot.yml` → `WIRING … does not use ./.github/actions/gbg-auth` (reproduced), a finding in `Pkg.test()` and the build with nothing to fix.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `ci_drift` reports only workflows with `julia-actions/` or `julia `.

### A-11: A hook that lost its execute bit is neither restored by sync nor reported by the wiring check
- file: src/Render.jl:1489 · severity: minor · confidence: confirmed
- evidence: `isfile(full) && read(full, String) == want && continue` precedes `g.generator === :hook && chmod(full, 0o755)`.
- failure: `queue-guard.sh` at mode 644 with correct content → sync leaves 644, `wiring` says nothing (reproduced); Claude Code cannot exec the hook.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the wiring check reports a non-executable hook; `write_all` restores the mode.

### A-12: The `GENERATED` and module docstrings say the instrument skills are not in the register; they are
- file: src/Render.jl:1133 · severity: minor · confidence: confirmed
- evidence: docstring: "the instrument skills … are not in the register"; code: `(map(i -> (path = skill_path(i.id), …), Catalogue.INSTRUMENTS))...`. Module docstring: "it may name `Model`, `Texts`, `Catalogue` and `ConfigIO`, and nothing above" while line 27 is `using ..Engine`.
- failure: a reader trusts the docstring → two false beliefs.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `GENERATED` and module docstrings describe the register and imports as they are.

### A-13: The extension's failure message names a `gbg check --site` that does not exist
- file: ext/GBGCodingToolsDocumenterExt.jl:83 · severity: minor · confidence: confirmed
- evidence: `check("check --site", …)` → `error("gbg $verb returned $code")`; `Check.jl` parses no `site` flag.
- failure: a post-build finding → "gbg check --site returned 1", and re-running that command gets an unknown-flag answer.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the extension's failure messages name the step that ran.

### A-14: The seed config names `docs/make.jl` unconditionally, so `gbg init` on a package with no docs build writes a config its own sync refuses
- file: src/CLI/Wire.jl:38 · severity: minor · confidence: confirmed
- evidence: `docs_build = ["julia", "--project=docs", "docs/make.jl"],` in `CONFIG_SEED`; `validate` pushes "docs_build names docs/make.jl, which is not a file here".
- failure: package with no `docs/make.jl` → "init: wrote .gbg/config.jl" then exit 2, nothing else written (reproduced).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `config_seed` writes `docs_build`/`test` only where `docs/make.jl`/`test/runtests.jl` exist.

### A-15: `call_drift` accepts only the fully-qualified spelling, and the design's own example does not name a binding
- file: src/Render.jl:555 · severity: minor · confidence: confirmed
- evidence: `occursin(c.want, live)` with `want = "GBGCodingTools.Engine.Harness.test"`; ARCHITECTURE §11 shows `GBGCodingTools.Harness.test(…)`, and `isdefined(GBGCodingTools, :Harness)` is `false`.
- failure: a `runtests.jl` written from the design → `UndefVarError`; one written as `using GBGCodingTools.Engine: Harness; Harness.test(…)` → runs yet is reported as not calling it.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `Render.harness_called` accepts `Engine.Harness.test`, `Harness.test`, and a `Harness.test` imported from the Engine.

A read: src/Render.jl whole, the extension, src/CLI/Wire.jl; the rendered hook exercised under `bash -n` and five states, with and without a space in `CLAUDE_PROJECT_DIR` — no finding there; the extension reads no git or review state.

## Group C — the upkeep verbs, the shim, the floor (19 findings)

### C-1: `bump`'s guard runs the RUNNING version's rules, not the new version's, so it cannot refuse what it exists to refuse
- file: src/CLI/Bump.jl:83
- severity: major
- confidence: confirmed
- evidence: `found = counts(cfg, root)` … `for rule in Catalogue.RULES` (Bump.jl:45); module docstring: "It runs the new version's checks FIRST and refuses to move the pin while any of them finds something"; ARCHITECTURE §11: "`gbg bump` … first runs the new version's checks on the package and exits 1"; bin/gbg:31 `P="$d/docs"` → the consumer's docs Manifest, which holds the OLD pin; PF-WIRING.md:25–33 runs `gbg bump 2.0.0-rc.27` first and `Pkg.update("GBGCodingTools")` after.
- failure: a consumer pinned at rc.23 runs `gbg bump 2.0.0-rc.27` through the shim → the loaded code is rc.23, so `Catalogue.RULES` is rc.23's rulebook, which the package already satisfies → the guard passes trivially, the pin moves, and rc.27's new opinions redden the next build — the exact case §11 says bump prevents. `stale_warning` admits the REGENERATION is stale but says nothing about the guard being stale; the module and `bump` docstrings state the opposite.
- fix: refuse (exit 2) when `pkgversion(GBGCodingTools)` is not the version being pinned, telling the session to move the environments first; or reorder the documented procedure and say in the docstring which version's rules the guard runs.
- verified: yes, by reading (2026-09-26) · fate: owner — should `bump` refuse (exit 2) when the running version is not the one being pinned? Docstring and output now name the version whose rules ran.

### C-2: `gbg fleet` grades a consumer wired exactly at its pin as `RED WIRING`, because the wiring check renders with the dev tree's generators
- file: src/CLI/Fleet.jl:86
- severity: major
- confidence: confirmed
- evidence: `fails = GBGCodingTools.Wire.sync(p; check = true, io = devnull) == 0 ? String[] : ["WIRING"]`; docstring: "one whose generated files are adrift is `RED`". Reproduced: `G.Fleet.rows()` at 9a81d50 gives `GBGPeriodicFields  v2.0.0-rc.23  RED  WIRING`, exit 1; the drift is eight rulebook/skill files "not what `gbg sync` writes now" — rc.27's text versus rc.23's, which is what PF's pin writes.
- failure: any consumer pinned at a released version older than the dev tree → `RED`, exit 1, whenever a generator's text changed since that release — i.e. between every two candidates. The scorecard cannot distinguish "unwired" from "wired at its pin".
- fix: compare against the pinned version's output (run the consumer's own docs environment for the check), or label the row `BEHIND`/"dev writes differently" rather than `RED`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a released-pin consumer differing from dev output is graded `AT-PIN` (exit 0), not `RED`.

### C-3: A valued option given without its value is a crash (exit 3 with a backtrace), not a usage error
- file: src/CLI/Main.jl:54
- severity: minor
- confidence: confirmed
- evidence: `i == length(args) && throw(ArgumentError("--$body needs a value"))`; Main.jl:156 `println(stderr, "gbg ", key, ": crashed — ", …); Base.show_backtrace(…); return 3`. Reproduced: `G.main(["install", "--dev-checkout"])` returns 3.
- failure: `gbg install --dev-checkout` (typo) → "crashed" with a Julia backtrace and exit 3, where a user's mistake is the documented exit 2 without a backtrace.
- fix: catch `ArgumentError` from `parse_options` in `main` (or in each verb) and return 2 with the message.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `UsageError` from `parse_options`; `main` prints it without a backtrace and returns 2.

### C-4: `parse_options` consumes `--` as the value of a valued option
- file: src/CLI/Main.jl:55
- severity: minor
- confidence: confirmed
- evidence: `vals[body] = String(args[i+1]); i += 1` with no check that `args[i+1] != "--"`; docstring: "a lone `--` ends option parsing". Reproduced: `parse_options(["--v", "--"]; valued = ["v"])` gives `values = Dict("v" => "--")` and no error.
- failure: `gbg study rules --votes -- file.tsv` → `votes = "--"`, `file.tsv` positional; the verb then reports "no such file: --" instead of the missing-value error.
- fix: treat a following `--` like the end of the arguments (throw the same `ArgumentError`).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a valued option followed by `--` is a missing-value `UsageError`.

### C-5: The shim's awk reads a `tool = :dev` inside a comment as the pin
- file: bin/gbg:25
- severity: minor
- confidence: confirmed
- evidence: `v=$(awk '/tool[ \t]*=[ \t]*:dev/{print "dev"; exit} /tool[ \t]*=[ \t]*v"/{sub(/^.*v"/,""); sub(/".*$/,""); print; exit}' "$d/.gbg/config.jl")` — no anchor to the line start, no exclusion of `#`. Reproduced: a config whose line 1 is `# this checkout carries tool = :dev while the rebuild runs` and line 2 `Config(package = "X", tool = v"2.0.0")` prints `dev`; `tool = v"2.0.0",  # was v"1.0.0"` prints `1.0.0` (greedy `^.*v"`).
- failure: a consumer whose config comments on the pin in those words → route (4), "pin is dev but no enclosing GBGCodingTools repository", exit 2, while `ConfigIO` reads the same file as pinned at 2.0.0. (The trailing-comment case is harmless today: `v` is only compared with `dev`.)
- fix: anchor the pattern to `^[ \t]*tool` and drop the `sub(/^.*v"/…)` greed (`sub(/^[^"]*"/,"")`).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the shim's awk skips comments, takes the leftmost `tool = …`, no greedy strip.

### C-6: `tree_hash` marks a file executable on any `x` bit; git and Pkg use the owner bit alone
- file: src/CLI/Self.jl:18
- severity: minor
- confidence: confirmed
- evidence: `_mode(path) = islink(path) ? "120000" : (filemode(path) & 0o111) != 0 ? "100755" : "100644"`; Pkg `GitTools.gitmode`: `return !iszero(filemode(p) & 0o100)`. Reproduced: a file with mode `0o654` → git `write-tree` `25b3f9b7…` (ls-files shows `100644`), `G.tree_hash` `5b2542bc…`.
- failure: a fetched copy holding a file with a group/other execute bit and no owner bit → `self verify` reports "the pinned copy was edited" (exit 2) on an unedited tree.
- fix: `(filemode(path) & 0o100) != 0`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `_mode` reads the owner execute bit only.

### C-7: `tree_hash` writes an entry for a directory that holds only skipped names; `skip` is not applied where the docstring says it is
- file: src/CLI/Self.jl:61
- severity: minor
- confidence: confirmed
- evidence: `function _nonempty(dir, skip)` … `for (_, _, files) in walkdir(dir; follow_symlinks = false); isempty(files) || return true` — `skip` is never read; docstring: "`skip` — entry names ignored at any level". Reproduced: `a` plus `sub/.git/HEAD` → git `aaff7498…` (index holds only `a`), `G.tree_hash` `fa94a900…` (an entry `40000 sub <empty-tree>`, which git never writes).
- failure: a running copy with a nested `.git` (or any name in `skip`) as the only content of a subdirectory hashes differently from git → `self verify` FAIL on an unedited tree.
- fix: filter `skip` in `_nonempty`'s walk (prune `dirs` and `files` by `skip`).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `_nonempty` applies `skip`.

### C-8: `tools/floor.sh <package-root>` can never pass: the clean-export step loads the tool from the consumer's root environment
- file: tools/floor.sh:96
- severity: major
- confidence: confirmed
- evidence: header "Usage: tools/floor.sh [package-root]"; line 9 `cd "${1:-…}"`; lines 95–98 `git ls-files -z | xargs -0 tar -cf - | tar -xf - -C "$EXPORT"` … `julia --project="$EXPORT" … 'using Pkg; Pkg.instantiate(); using GBGCodingTools'` — unconditional. A consumer's root `Project.toml` lists no `GBGCodingTools` (ARCHITECTURE §5.1; PF's names it only in `docs/Project.toml`); line 125 `julia --project … tools/fleet.jl` is a path that exists only here.
- failure: `tools/floor.sh "$PF"` (the gate IMPLEMENTATION.md §3/§5/§7 writes as `tools/floor.sh "$1"`) → the export step fails with "Package GBGCodingTools not found", exit 1, after the consumer's tests and docs build passed.
- fix: run the export/load step (and the sweep) only when `$1` is empty, as the CI step already does.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the export/load step and the sweep run only when `$1` is empty.

### C-9: A green run at another commit passes the floor; the file says it refuses
- file: tools/floor.sh:57
- severity: minor
- confidence: confirmed
- evidence: `if [ -n "$SHA" ] && [ "$SHA" != "$HEAD_SHA" ]; then … echo "floor: the newest $WF run is $BEHIND commit(s) behind HEAD — it did not see this work."` — no `exit`; lines 55–56 call this "the whole defect restated: it is a verdict on other code"; lines 16–17 "It REFUSES rather than warns. A printed line is what the previous version of this lesson was, and it was read past."
- failure: CI green at a commit twenty behind HEAD → two echo lines and the floor continues to green; the `release` verb's `ci_verdict` is the only place the same-commit condition holds.
- fix: either exit 1 when the newest CI run is behind HEAD (with the same `FLOOR_IGNORE_CI` escape) or reword the header to say the behind-HEAD case is only reported.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `floor.sh` exits 1 when the newest run is not at HEAD; `FLOOR_IGNORE_CI=1` bypasses.

### C-10: The clean export silently loses files once the tracked path list passes xargs's 128 KiB buffer
- file: tools/floor.sh:95
- severity: minor
- confidence: plausible
- evidence: `git ls-files -z | xargs -0 tar -cf - | tar -xf - -C "$EXPORT"`. Measured: 1394 tracked paths, 108,542 bytes; `xargs --show-limits`: "Size of command buffer we are actually using: 131072". Reproduced the mechanism: `(tar -cf - a; tar -cf - b) | tar -tf -` lists only `a` (GNU tar stops at the first end-of-archive marker).
- failure: when the tracked paths exceed ~128 KiB (about 20 KiB from now; `docs/design-record/` grows every session), xargs runs `tar` twice, the second archive is discarded, and the export lacks the last files in sorted order (`test/…` last) — the load step passes on an export that is not the tracked tree, which is the class this step exists to catch.
- fix: `git archive HEAD | tar -xf - -C "$EXPORT"` (tracked files, no argument list), or `xargs -0 tar -rf "$EXPORT.tar"` (append) then extract once.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — one `tar --null -T -` reads the whole list (the fixer's `git archive HEAD` exported the previous commit, since the floor runs before a commit; corrected by the session).

### C-11: `release`'s docstring names a gate that no longer exists and understates what `skip_tests` skips
- file: src/CLI/Release.jl:94
- severity: minor
- confidence: confirmed
- evidence: docstring: "`skip_tests` — skips `Pkg.test()`, the docs build and the deep doctor" and "`gbg doctor --deep` is green at the root"; body lines 128–130: "`gbg doctor --deep` was the third gate here until 2026-09-17, when the doctor was deleted"; lines 121–138 put the `sync --check` and the CI verdict inside `if !skip_tests` too.
- failure: a reader of the docstring expects a doctor gate that does not exist, and expects `skip_tests = true` to still ask GitHub and check the wiring; it does neither.
- fix: rewrite the two sentences to the four gates the body runs and say `skip_tests` skips all four.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `release` docstring lists the four gates; `skip_tests` skips all four.

### C-12: `git tag` and `git push` failures are reported without git's reason
- file: src/CLI/Release.jl:139
- severity: minor
- confidence: confirmed
- evidence: `Git.run(root, "tag", "-a", "v$ver", "-m", …) === nothing && (println(io, "release: git tag failed"); return 3)`; Git.jl:34 `read(pipeline(addenv(…); stderr = devnull), String)` — stderr discarded for every call; likewise Release.jl:125 `success(pipeline(…; stdout = devnull, stderr = devnull))` for `Pkg.test()` and the docs build, then "refused — $label failed".
- failure: a tag refused for a missing identity, a push refused by the remote, or a failing test suite → one line with no cause; the Git.jl docstring itself records that "`gbg release` could not tag" was found the hard way. A network/remote failure on push also returns 3, the crash code, though it is a named condition and no exception escaped.
- fix: for the two write commands and the two subprocess gates, capture stderr and print it under the refusal line; return 2 for the push failure.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `Git.said` captures git's output; tag/push failures print git's reason and return 2; failed gates print their last 40 lines.

### C-13: `ci_verdict` reads only the newest 30 runs, and any one success at the sha counts
- file: src/CLI/Release.jl:34
- severity: minor
- confidence: plausible
- evidence: `gh run list --workflow CI --limit 30 --json headSha,status,conclusion --jq …select(.headSha==\"$sha\")…`; line 41 `occursin("completed success", runs) && return nothing`.
- failure: a dispatch at this commit older than 30 CI runs → "CI has no run at $sha", refused, though the run exists; and a sha with runs `completed success,completed failure` (a re-run that went red) → passes on the older success.
- fix: `gh run list --commit $sha` (or a larger limit) and require the NEWEST run at the sha to be a success.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `ci_verdict` asks `gh run list --commit <sha> --limit 1`; the newest run at the commit must succeed.

### C-14: `Fleet.rows`'s `deep` does nothing, and the docstrings describe a doctor and a status set the code does not have
- file: src/CLI/Fleet.jl:53
- severity: minor
- confidence: confirmed
- evidence: `function rows(; deep::Bool = false)` — `deep` is not referenced in the body (grep: lines 48, 53, 114 only); docstring: "`deep` — run every check, the `--deep` ones included, as each consumer's doctor pass instead of the `QUICK` set"; module docstring lists `OK`, `NOT-INITIALISED`, `BEHIND` or `RED` while line 71 pushes `status = "MISSING"`.
- failure: `gbg fleet --deep` is accepted and changes nothing; the docstrings promise a doctor deleted on 2026-09-17.
- fix: drop the flag and the sentence; list `MISSING`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the `deep` option dropped; module docstring lists `MISSING` and `AT-PIN`.

### C-15: `Fleet.latest_tag` is dead, and `fleet.toml` says `gbg bump` writes a sweep that nothing writes
- file: src/CLI/Fleet.jl:29
- severity: minor
- confidence: confirmed
- evidence: `function latest_tag(root)` is defined at Fleet.jl:29 and referenced nowhere else (grep over `src`, `test`, `tools`); fleet.toml:1–2 "written by `gbg bump` and read by `gbg fleet`" and line 9 `[sweep]  # written by `gbg bump` when a bump leaves the fleet at two versions` — `Bump.jl` never opens `fleet.toml`, and no source writes a `sweep` key.
- failure: a reader takes `latest_tag` for a live part of the scorecard and expects a bump to open the 7-day window; the window (`started`) can only be hand-edited, which the comment says is not how it is set.
- fix: delete `latest_tag`; either write the sweep from `bump` or correct the comment.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `Fleet.latest_tag` deleted; `fleet.toml` says the sweep is set by hand.

### C-16: `bump` exits 0 for a state it prints as `NOT FINISHED`
- file: src/CLI/Bump.jl:99
- severity: minor
- confidence: plausible
- evidence: `stale_warning(io, version); return 0` after `println(io, "NOT FINISHED. What was just written is this version's content under a v", version, " banner:")`.
- failure: the pin and the generated files disagree by construction (the docstring says so: "every generated file it writes is the old version's content under the new version's banner"), and the verb returns the clean code; a session reading exit codes — the contract, "a log is never grepped for a verdict" — sees a finished bump.
- fix: return 1 (or a named code) while the running version differs from the pinned one, and 0 only when `pkgversion(GBGCodingTools) == version`.
- verified: yes, by reading (2026-09-26) · fate: owner — goes with C-1: should `bump` exit non-zero while the running version is not the pinned one? It would make the documented bump-first procedure always exit 1.

### C-17: `Study.read_round` drops a short row without a word
- file: src/Study.jl:100
- severity: minor
- confidence: confirmed
- evidence: `length(cells) < length(head) && continue`. Reproduced: a round whose `DOC.GRAMMAR` row lacks its last `C_f` cell (an editor trimming a trailing tab) reads as `rules = ["DOC.SHAPE"]`.
- failure: a vote file with one truncated row → that rule vanishes from the count, the kappas and the drift, and the report says "1 rule(s)" where the file has two; a `_f` cell missing is precisely the case of an empty last column trimmed on save.
- fix: pad a short row with empty cells (the flag column is documented as optional) or report the row and exit 2.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a row short of trailing `_f` cells is padded; any other short row is exit 2.

### C-18: A vote file without a `rule` column is a crash (exit 3), not a bad input (exit 2)
- file: src/Study.jl:102
- severity: minor
- confidence: confirmed
- evidence: `rule = String(cells[col["rule"]])` — `col` is a `Dict` built from the header; reproduced: a header `id\tA_w\tA_c` throws `KeyError`, which `StudyCmd.rules` does not catch and `main` prints with a backtrace as 3.
- failure: `gbg study rules --votes wrong.tsv` → "crashed" with a backtrace for a consumer's own malformed file.
- fix: check `haskey(col, "rule")` and each `<R>_c` column in `read_round` and return the documented 2 from the verb.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `read_round` refuses a file without `rule` or a reader's `_c` column; exit 2.

### C-19: The shim's `--dev` route checks nothing about the checkout's environment, unlike the pinned route
- file: bin/gbg:12
- severity: minor
- confidence: plausible
- evidence: `shift; P=$(devpath) || exit 2; GBG_DEV=1; export GBG_DEV` then line 36 `exec julia --startup-file=no --project="$P" -e "$JL"`; the pinned route, line 32, first does `grep -q 'GBGCodingTools' "$P/Manifest.toml" … || { echo "gbg: package not instantiated in $P"; …; exit 2; }`. The root `Manifest.toml` is git-ignored (`.gitignore:17`).
- failure: on a fresh clone registered with `gbg install --dev-checkout`, `gbg --dev fleet` fails inside Julia with a package-loading error rather than the shim's "run: julia --project … Pkg.instantiate()" line.
- fix: apply the same manifest check to `$P` on the `--dev` route.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the shim's `--dev` route refuses a checkout with no `Manifest.toml`.

READ: src/CLI/Main.jl, src/CLI/Bump.jl, src/CLI/Release.jl, src/CLI/Fleet.jl, src/CLI/Install.jl, src/CLI/Self.jl, src/CLI/Git.jl, src/CLI/StudyCmd.jl, src/Study.jl, bin/gbg, tools/floor.sh (all completely); ARCHITECTURE.md §11; IMPLEMENTATION.md §5; test/cli.jl, test/release.jl, test/study.jl, test/counts.jl; tools/fleet.jl, fleet.toml; the parts of Render.jl (version_tag, write_all, wiring, write_pin, GENERATED), Wire.jl (sync), ConfigIO.jl (require_root, find_root, the `v"…"` branch), Catalogue.jl (FLEET, RETIRED, branch_of) that these files call.
SKIPPED: src/CLI/Wire.jl, Check.jl, Docfix.jl, Answer.jl, Run.jl beyond the functions the group's files call (another group's); Pkg's GitTools.jl beyond `gitmode` and the `.git` skip; the `release` tag/push path was not executed (a tag is permanent) — its refusals were read, not run.


## Group B — Docfix, Check, Answer, Guard, Questions, Checks (13 findings)

### B-1: A per-file switch is matched by a different glob than every other file pattern — `src/**/*.jl` does not switch `src/a.jl` off, `src/*.jl` switches `src/a/b.jl` off, and `a+b.md` matches `ab.md`
- file: src/Engine/Checks.jl:44
- severity: major
- confidence: confirmed
- evidence: `any(pattern -> occursin(Regex("^" * replace(replace(pattern, "." => "\\."), "*" => ".*") * "\$"), file), s.files) && return false` — while `Texts.glob_matches` (src/Texts.jl:96-97) escapes every metacharacter, maps `**/` to `(?:.*/)?` and `*` to `[^/]*`.
- failure: reproduced: `Switch(files = ["src/**/*.jl"])` leaves the rule ON for `src/a.jl` (`**/` becomes `.*/`, which needs a slash); `Switch(files = ["src/*.jl"])` turns it OFF for `src/a/b.jl`; `Switch(files = ["docs/src/a+b.md"])` does not match `docs/src/a+b.md` and does match `docs/src/ab.md`; `(a).md` is a regex group. The same pattern spelling that names a file set in `.gbg/config.jl` means something else on a switch, and the switch's reason is rendered on the site as if it were in force.
- fix: `any(pat -> Texts.glob_matches(pat, file), s.files)`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `applies` matches per-file switches with `Texts.glob_matches`; tested with `**/`, `*`, `a+b.md`.

### B-2: `gbg docfix commit` never hands the guard what the generators produce, so clause 0 is unreachable from the CLI and a reworded rule statement cannot be committed with the policy files it feeds
- file: src/CLI/Docfix.jl:377
- severity: major
- confidence: confirmed
- evidence: `return commit(root, msg; finding = get(o.values, "finding", ""))` — `generated` keeps its default `Dict{String,String}()` (line 114); no caller anywhere passes `generated` (grep over src/). ARCHITECTURE §4.3 step 2: "`gbg docfix commit` regenerates every generated part whose generator reads the prose that changed — the policy files and the tooling package's block in `CLAUDE.md` — and classifies every changed path … which leaves those regenerated parts out by its clause 0."
- failure: in GBGCodingTools, reword a `statement` and run `gbg sync` → `.gbg/policy/*.md` change → `on_documentation_list` refuses every generated path (Guard.jl:158) → "not a path where documentation lives (clause 1)" → exit 1, nothing committed. Without the sync the wiring check reports drift on the next build. Either way the automatic path §4.3 step 3 promises for a rule statement does not exist.
- fix: in `cmd_docfix`, build `generated` from `Render.GENERATED` (each generator's current output) and pass it to `commit`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `Docfix.generated_now(root)` supplies each generator's output to `commit` and `check`, so clause 0 is reachable.

### B-3: `gbg check` prints "clean" over every rule while five rules never ran — those that read the built site or the loaded module — and says nothing about it
- file: src/CLI/Check.jl:47
- severity: major
- confidence: confirmed
- evidence: `found = Engine.Checks.run_all(cfg, root; intention, network, history = true)` — no `pkg`, no `site`; `run_rule` returns `Model.Location[]` for `LOADED_MODULE` when `pkg === nothing` (Checks.jl:142) and for `BUILT_SITE` when `site === nothing` (Checks.jl:147); `Checks.not_run` is called by nothing in this verb. Then line 55: `println(io, "check: clean — ", length(Catalogue.RULES), " rule(s), ", …)`.
- failure: three `BUILT_SITE` rules (src/Rules/site.jl:64,126,201) and two `LOADED_MODULE` rules (src/Rules/modules.jl:98,283) are skipped silently; a package broken on any of them gets exit 0 and "clean — N rule(s)". The exit code is the contract, and 0 here means "nothing found by the rules I could run", which is not what it prints.
- fix: print `Checks.not_run(cfg; network)` as "not run here: …" and drop the "N rule(s)" count, or build the site and load the package as the harness does.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `Check.run` prints the rules `not_run` and no longer claims a rule total when clean.

### B-4: The comment in `run_rule` claims `run_all` returns the rules it could not run; it returns nothing of the kind
- file: src/Engine/Checks.jl:139-141
- severity: minor
- confidence: confirmed
- evidence: `# passes nothing, and the rule is NOT silently skipped: it is the caller's business to say so, which \`run_all\` does by returning the rules it could not run.` — `run_all` (lines 185-198) returns `Vector{Tuple{Symbol,Model.Location}}` of findings only; the list of rules not run is `not_run`, a separate function no CLI verb calls.
- failure: a reader (and `Check.run`, see B-3) takes the skip as reported when it is silent.
- fix: reword the comment to name `not_run`, and make the callers call it.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the `run_rule` comment names `not_run`, which `Check.run` now calls.

### B-5: Clause 3 lets the literal pieces of an interpolated `statement` be reworded, which the design calls code
- file: src/Engine/Guard.jl:343-345
- severity: minor
- confidence: confirmed
- evidence: `strip(String(JS.sourcetext(kc[1]))) in ("statement", "why") && JS.kind(kc[2]) === JS.K"string"` then `cut_text!(cut, kc[2])` — `cut_text!` cuts the `String` children of any `string` node, interpolated or not. ARCHITECTURE §4.2 clause 3: "differences confined to plain string literals … an interpolated string in those fields, is code."
- failure: reproduced in the tooling config: `statement = "one $(x) two"` → `statement = "one, reworded $(x) two"` returns `documentation = true`, "the prose of a rule … (clause 3)". test/guard.jl:341 covers only plain → interpolated.
- fix: in the clause-3 branch, cut the string only when all its children are `String` tokens.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — clause 3 cuts `statement`/`why` only when every child of the string is a plain `String` token.

### B-6: The commit is made from the working tree, not from the index the "moved" check verified
- file: src/CLI/Docfix.jl:219
- severity: minor
- confidence: confirmed
- evidence: `Git.run(root, "commit", "-m", message * "\n\n" * trailers, "--", [r.path for r in rs]...)` — `git commit -- <pathspec>` commits the working-tree content of those paths, ignoring the index. Reproduced in a scratch repo: stage "classified", write "changed-after-add", `git commit -- f.md` → `HEAD:f.md` is "changed-after-add". Lines 149-152 say "The bytes classified are the bytes committed … after staging the index is compared with it".
- failure: a writer that changes a file after the hash comparison (lines 196-198) and before the commit gets its bytes committed under the guard trailer, unclassified; the comparison guards a window the commit then reopens.
- fix: since nothing else is staged (line 146-148) and the index was verified, commit the index: drop the pathspec from the `git commit`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `git commit` with no pathspec commits the verified index. No test: the race is not reproducible deterministically.

### B-7: `math_changed(…; jl = true)` does not read the Literate comments its docstring says it reads
- file: src/Engine/Guard.jl:102-103
- severity: minor
- confidence: confirmed
- evidence: `tb = jl ? something(texts_of(before), String[String(before)]) : …` — `texts_of` is called without `literate = true`, so `regions` treats the file as ordinary source and returns docstrings only. Docstring, line 86-87: "whose mathematics is read in its docstrings and in the comments Literate renders".
- failure: reproduced: `math_changed("# The energy is $E = h$.\nx = 1\n", "# The energy is $E = 2h$.\nx = 1\n"; jl = true)` returns `String[]`, while `classify` on the same text as `examples/x.jl` refuses under clause 6. Only test/guard.jl:388 calls it, on a page, so nothing live is wrong; the docstring is false about the body.
- fix: give `math_changed` a `literate` keyword and pass it to `texts_of`, or drop the claim.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `math_changed` takes `literate` and passes it to `texts_of`.

### B-8: The `Guard` module docstring describes a rule the code no longer applies
- file: src/Engine/Guard.jl:16-18
- severity: minor
- confidence: confirmed
- evidence: `A docstring whose target is a call rather than a definition is not documentation at all — Julia then documents the call instead of running it — and neither is one built by interpolation.` — `walk_docs!` cuts every `K"doc"` string's `String` tokens whatever the target (line 331-332), and `cut_text!` cuts the literal pieces of an interpolated docstring (line 360; test/guard.jl:177-178 asserts that a `$(SIGNATURES)` docstring is reworded as documentation).
- failure: reproduced: `"doc"\nfoo(1)\n` → `"doc, reworded"\nfoo(1)\n` is "docstrings, comments or prose only". The docstring states the opposite of the simple rule of 2026-09-23 that `regions` documents at lines 261-267.
- fix: reword the module docstring to the simple rule.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the Guard module docstring states the simple rule of 2026-09-23.

### B-9: A fence opened inside a `#md` block is not caught — `prose_runs` skips every `#md` line
- file: src/Engine/Guard.jl:398-399
- severity: minor
- confidence: confirmed
- evidence: `m = match(r"^[ \t]*#( (.*)|)$", l)` / `if m !== nothing && !startswith(lstrip(l), "##")` — a `#md # ` line does not match, so no run is formed from a `#md` block, and the `open-fence` signature (lines 308-310) is never raised for it; `literate_markdown` (line 432) does strip `#md` but is used only for `texts`.
- failure: reproduced: `#md # Text.\n#md # more\nx = 1\n` → `#md # Text.\n#md # ```\nx = 1\n` is "docstrings, comments or prose only"; the open fence swallows the code chunk that follows on the rendered page. ARCHITECTURE §4.2 clause 2: "a prose run may not leave a fence open".
- fix: form prose runs from `literate_markdown`'s lines rather than from raw `# ` lines.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `prose_runs` is built from `literate_lines`, so a fence opened in a `#md` block is caught.

### B-10: A Literate prose line that mentions a mark mid-line cannot be reworded — the guard reads any occurrence of `#md` as a mark, Literate reads only a line's start or end
- file: src/Engine/Guard.jl:294
- severity: minor
- confidence: confirmed
- evidence: `elseif occursin(r"^##?( |$)", c) && !any(m -> occursin(m, c), LITERATE_MARKS)` — falls through to "any other mark: exactly as it is" (line 304).
- failure: reproduced: `# Prose about #md lines.\n` → `# Prose about the #md lines.\n` in `examples/x.jl` is refused as "the code changed … (clause 2)". A documentation fix to an example's prose that names the marks (the rule that explains them is a natural place) is parked on the owner.
- fix: test the mark at the start of the comment or at its end (`occursin(r"(^|\s)#!?(?:md|jl|nb|src)$", c)`), as Literate does.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `has_mark` reads a Literate mark only at a comment's start or end.

### B-11: A display formula turned into a plain code fence with the same text passes as a "respelling"
- file: src/Engine/Guard.jl:116-119
- severity: minor
- confidence: confirmed
- evidence: `respelled = last.(sb) == last.(sa) && multiset_minus(mb, inline_math(sb)) == multiset_minus(ma, inline_math(sa))` — `parsed_math` pushes every `Markdown.LaTeX` node, display and inline alike, into `spans` (line 59), so `multiset_minus(mb, inline_math(sb))` is always empty and the whole test is "the span texts are equal in order".
- failure: reproduced on `docs/src/i.md`: `$$\nE = h\n$$` → "```\nE = h\n```" is "docstrings, comments or prose only". A formula the page rendered is gone from it; §4.3 step 3 counts "a formula … removed" as a change the owner answers. The design's exception is an inline code span for an inline math span.
- fix: record whether each LaTeX node is display (the parser's block vs inline position) and let only inline code ↔ inline math count as respelling.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — formulas are tagged inline or display; a respelling keeps every display; a ```math fence turned into ``` is refused.

### B-12: `unresolved_refs` warns on references Documenter resolves, including one it finds in its own source
- file: src/CLI/Docfix.jl:325-330
- severity: minor
- confidence: confirmed
- evidence: `for m in eachmatch(r"\[([^\]]+)\]\(@ref(?:\s+([^)]+))?\)", text)` over the whole file, and `(target in known || bare in known || any(k -> endswith(k, "." * bare), known)) && continue` where `known` holds only this package's names.
- failure: reproduced on the fixture: `` [`Base.sum(x)`](@ref) `` (a call form Documenter resolves to the binding) and `` [`sum`](@ref Base.sum) `` (a binding of another loaded module) are both reported; and run over the package's own files, `src/CLI/Docfix.jl` reports the target `", t,"` — the regex literal on line 325 matched itself. A warning, never a refusal, so the cost is noise on every commit that touches such a file, and a warning that is always there is not read.
- fix: strip a trailing call from the target, exempt targets whose first component is a module the package does not define (`Base`, `Core`, a `[deps]` name), and read only the prose (`Texts.prose_text`) of a `.jl` file.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `unresolved_refs` reads only prose of `.jl` files, strips call forms, skips Base/Core/Main and `[deps]` targets.

### B-13: `--settled` on the open run's own "not a defect" question is refused, while the same answer without the flag is accepted and deferred
- file: src/CLI/Answer.jl:112-118
- severity: minor
- confidence: confirmed
- evidence: `if open_here !== nothing && (settled || (of_run && option == NOT_A_DEFECT))` / `if of_run && first(found) == open_here && !settled` / `deferred = true` / `else` refuse "answer it once the run has closed".
- failure: `gbg answer <fid>-code "not a defect" --settled` while that run is open → exit 2 and nothing recorded; `gbg answer <fid>-code "not a defect"` → recorded and settled at close (Run.jl:940-943). The flag adds nothing the option does not already say (line 129-130 refuses it with any other option), so the refusal is only a trap for the owner who reads the usage line and types it.
- fix: drop `&& !settled` from the deferral condition.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the open run's own "not a defect" answer is deferred with or without `--settled`.

READ: src/CLI/Docfix.jl, src/CLI/Check.jl, src/CLI/Answer.jl, src/Engine/Guard.jl, src/Engine/Questions.jl, src/Engine/Checks.jl (all complete); docs/ARCHITECTURE.md §4, §8, §9; test/guard.jl (the interpolation, clause 3, clause 0 sets); the parts of src/Orchestration/Runs.jl, src/CLI/Run.jl, src/CLI/Git.jl, src/CLI/Main.jl, src/Texts.jl, src/Model.jl and src/ConfigIO.jl these six call.
SKIPPED: the rest of Runs.jl and Run.jl (another group's), Render.jl, the Rules files beyond their input kinds, Harness.jl, the ext — outside group B.

## Group H — the run path since rc.24 (11 findings)

### H-1: A continued or relaunched stage runs on a driver whose spliced arguments still mark every role `launch: true`
- file: src/CLI/Run.jl:219 (also src/Orchestration/Agents.jl:388, src/Orchestration/Agents.jl:277, drivers/run.js:17)
- severity: major
- confidence: confirmed
- evidence: Agents.continue_stage rewrites only the arguments file — `r["launch"] = !readable` … `write(path, JSON3.write(args))   # compact: nobody reads this file, the session TYPES it`; the driver reads `const args = globalThis.args;`, which `place_driver` splices in from `read(arguments, String)` only when it is called, and the sole caller is `next` after a fresh `write_arguments` (`Run.jl:194 moved = with(moved; driver = last(Agents.place_driver(root, moved.id)))`). `Run.continue_stage` prints `arguments: …` and `then: gbg run collect` and never re-places the driver.
- failure: a stage interrupted after some roles wrote, or a collect that named silent roles (`Launch them once more — gbg run next marks exactly them`) → `gbg run next` marks the missing roles in `arguments.json` → the session launches `.gbg/scratch/<id>/run.js`, whose embedded `args.roles` all still carry `launch: true` → every role of the stage is launched again, paying the whole stage and overwriting results that had arrived; nothing "marks exactly them" where the driver reads. Should re-splice the updated arguments into the driver copy (call `place_driver(root, id; arguments = path)` from `continue_stage`).
- fix: have `Agents.continue_stage` (or `Run.continue_stage`) call `place_driver(root, id; arguments = arguments_path(root, id))` after rewriting the arguments, and print the driver path as `write_arguments` does.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `Agents.continue_stage` re-places the driver with the rewritten arguments; `Run.continue_stage` prints its path.

### H-2: `gbg run cost` counts each agent message's usage once per content block, about 2.5× the real figure
- file: src/CLI/Run.jl:1246
- severity: major
- confidence: confirmed
- evidence: `for line in eachline(joinpath(here, f))` … `m = get(d, "message", nothing)` … `u = get(m, "usage", nothing)` … `input += Int(get(u, "input_tokens", 0))` — every line carrying `message.usage` is summed with no de-duplication by `message.id`. Measured on a real Workflow directory of this session (`…/subagents/workflows/wf_69b356fd-ed8/`): `agent-acb30c48f021dd9c1.jsonl usage lines 28 distinct ids 15`; on a PF session transcript: 21316 usage lines against 8614 distinct `message.id`, 6525 ids with identical repeated `usage`, cache-read summed over lines 9.60e9 vs 3.85e9 de-duplicated.
- failure: a transcript in which an assistant turn has a thinking block and a text block (or text and a tool_use) is written as two lines with the same `message.id` and the same `usage` → the stage's recorded `Usage` is roughly 2.5× what was paid → the report and the design's cost figures (`164.6M summed` in the docstring) are inflated. Should sum once per `message.id`.
- fix: keep a `Set` of `message.id` per file and add a record's usage only the first time its id is seen.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `cost` counts each `message.id` once per transcript; tested with one message on two lines.

### H-3: The verifier is told it may quote from the diff, but `grade` demotes any quote that is not in the current files
- file: src/CLI/Run.jl:554 (also drivers/run.js:163, src/CLI/Run.jl:820)
- severity: major
- confidence: confirmed
- evidence: brief in Julia: `"Quote, for each, the decisive words of the current text or the diff, as ONE verbatim span; …"`; brief in the driver: `'and the decisive QUOTE (at most 25 words, ONE verbatim span exactly as it appears in the current text'`, `'or the diff — never two fragments joined by "…", never a paraphrase). A verdict whose quote is not in'`; grade: `quote_holds` searches only `files = unique(l.file for l in f.draft.locations)` with `Texts.reanchor(root, Model.Location(; file, text = part, line = 0); loose = false)`, and `v != "NOT_FIXED" && !quote_holds(root, f, quote_)` → `v = "NOT_FIXED"`.
- failure: a verifier answers `MADE_WORSE` or `HIDES_CODE_DEFECT` and, as told, quotes the decisive old words from the diff's removed lines (the natural quote for "the change broke something the old text had right") → the quote is in no current file → the verdict becomes `NOT_FIXED`, no revert happens, no question is put, and the broken fix stays in the tree. The design (§4.3 step 6) says the quote must be in the current text; the brief must say the same, or the grade must also accept a span of the diff it wrote.
- fix: drop "or the diff" from both briefs (or, for `MADE_WORSE`/`HIDES_CODE_DEFECT`, also accept a span found in the `.diff` file written for that role).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — "or the diff" removed from both briefs; both say to quote the CURRENT text.

### H-4: The driver's "SOURCE withheld" paragraph for verifiers is unreachable — Julia writes every verifier with `kept_from_code = false`
- file: src/CLI/Run.jl:556 (also drivers/run.js:134)
- severity: minor
- confidence: confirmed
- evidence: `push!(roles, Model.AgentRole(; id, instrument = run.instrument, reads = reader.reads, site = reader.site, kept_from_code = false,` for every verifier chunk; driver: `const withheld = role.kept_from_code ? 'The SOURCE and the design documents are withheld from you, as they were from the reader: judge the text alone.' : '';`.
- failure: a verifier of the withheld reader's findings is never told the source is withheld, though §4.3 step 5 gives it "what the reader that found them was given (§5.3)"; the driver branch is dead code a reader takes as live. Either pass the reader's `kept_from_code` through or delete the branch.
- fix: write `kept_from_code = reader.kept_from_code` on the verifier role (the `site && kept_from_code` combination is what `reader_roles` uses to expand units, so guard that use if changed).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the unreachable withheld paragraph deleted from `verifierBrief`; `kept_from_code = false` kept with its reason.

### H-5: Questions put inside a run (`park`, `HIDES_CODE_DEFECT`) never pass the language rules
- file: src/CLI/Run.jl:1210 (also src/CLI/Run.jl:804, src/Engine/Questions.jl:42)
- severity: major
- confidence: confirmed
- evidence: `q = Runs.owner_question(run, f, why)` / `Runs.save(root, with(run; questions = vcat(run.questions, [q])))` and `push!(questions, code_question(f, run))` — neither calls `Engine.Questions.check`/`report`; the only caller in the package is `src/CLI/Answer.jl:273 Engine.Questions.put(q, root, cfg; io)` (`gbg ask`). ARCHITECTURE §8: "`Questions.check(q, cfg)` runs whenever a question is put, inside a run or out of one".
- failure: `gbg run park <id> --why "RULE.DOC.X in src/Foo.jl needs a Switch"` → the `--why` becomes `context` verbatim, with rule ids, paths and the tool's own terms → recorded and shown in `report.md` and the work queue with no rule named as failed, which is what §8 forbids ("shown with the failed rule named").
- fix: run `Engine.Questions.report(q, cfg)` in `park` and `grade` and print its lines before saving, as `put` does.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `park` and `grade` questions run `Engine.Questions.report` and print the failed rules.

### H-6: A finding parked, answered "fix it on my ruling", then judged `HIDES_CODE_DEFECT` gets a second question under the same id that can never be answered
- file: src/CLI/Run.jl:804 (also src/Orchestration/Runs.jl:398, src/Orchestration/Runs.jl:452, src/Orchestration/Runs.jl:627)
- severity: minor
- confidence: plausible
- evidence: `push!(questions, code_question(f, run))` with `id = Runs.code_question_id(run, f.id)` — no check that a question of that id exists; `answer_of` uses `findfirst(q -> q.id == code_question_id(run, id), run.questions)` and `parked` returns `false` as soon as `answer_of(run, id) === nothing || return false`; `answer!` refuses `q.answer === nothing || return "it was already answered: "` on the first match.
- failure: park → owner answers `RULED_ANSWER` (finding workable again, Runs.jl:383) → fixer edits → verifier says `HIDES_CODE_DEFECT` → a second `<fid>-code` question is appended; `parked` reads the first (answered) one and says not parked, so the finding is worked on again next run; `open_questions` lists the second forever and `gbg answer <fid>-code` refuses with "already answered".
- fix: in `grade`, replace an existing question of that id (or suffix the pass) rather than appending.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `grade` replaces an existing question of the same id instead of appending.

### H-7: `write_arguments` clears the results directory but not the stage's `returned.json`, so the fallback can grade a role on an older launch's return
- file: src/Orchestration/Agents.jl:251 (also src/Orchestration/Agents.jl:316)
- severity: minor
- confidence: plausible
- evidence: `rm(results_dir(root, run.id); recursive = true, force = true)` with the comment "its results directory still held the last pass's files: a verifier that wrote nothing this pass was graded on its old verdict"; `returned_results` reads `joinpath(stage_dir(root, id), "returned.json")`, which lives beside, not under, `results`, and nothing removes it.
- failure: a stage directory reused (a `Budget` with `fix_passes > 1`, or any rewrite of a stage's arguments) → a verifier that writes nothing and returns nothing this time is served last time's `returned.json` entry → counted as `wrote`, its old verdict graded again — the defect the `rm` was added for, through the other door.
- fix: `rm(joinpath(stage_dir(root, run.id), "returned.json"); force = true)` beside the results directory.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `write_arguments` removes the stage's `returned.json` with the results directory.

### H-8: `revert!` and `REVERT_TRAILER` docstrings claim a close checks a revert is "exactly that commit's inverse"; no such check exists
- file: src/Orchestration/Runs.jl:1024 (also src/Orchestration/Runs.jl:963)
- severity: minor
- confidence: confirmed
- evidence: `revert!` docstring: "marking the revert with the commit it undoes, so a close can check that it is exactly that commit's inverse"; `REVERT_TRAILER`: "A close skips such a commit only when it is exactly that commit's inverse, so the trailer alone buys nothing."; `unguarded_code`'s own comment: "simplified 2026-09-23: recognising "exact" reverts took four review passes and still had holes; this needs no recognition" — every commit is classified, a revert only tolerated for a clause-6 refusal.
- failure: a reader of the two docstrings believes a forged trailer is checked against the inverse diff; the body classifies the revert like any commit. The docstrings are false about the code.
- fix: reword both to what `unguarded_code` does (classified like every commit; a mathematics-only refusal tolerated on a revert).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `revert!` and `REVERT_TRAILER` docstrings describe what `unguarded_code` does.

### H-9: `STAGES`, `closed` and `parked` docstrings still describe the blind-then-diff two-verifier pass and a loop over passes
- file: src/Orchestration/Runs.jl:34 (also src/Orchestration/Runs.jl:356, src/Orchestration/Runs.jl:442)
- severity: minor
- confidence: confirmed
- evidence: `STAGES`: "A documentation review's pass is `fix → verify → collect → diff → collect`: … a blind verifier per open finding answers without the diff, and for the findings it called fixed a second verifier reads the diff. From the last `collect` the run goes back to `fix` while findings are open and passes remain" — the value is `[:start, :find, :collect, :fix, :verify, :collect, :close]` and `Budget.fix_passes = 1`; `closed`: "a verifier called it not a defect, or the blind verifier called it fixed and the diff verifier agreed"; `parked`: "A blind verifier's `HIDES_CODE_DEFECT`".
- failure: the module's map of the stages names a `diff` stage that is not in the list and a loop the budget forbids; a session reading the docstring plans for a stage that `advance!` refuses.
- fix: rewrite the three docstrings to the one-verifier, one-pass shape (`Run`'s module docstring already has it).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `STAGES`, `closed` and `parked` docstrings describe the one-verifier, one-pass shape.

### H-10: `abandon` drops a parked finding but leaves its question open, so every later close asks the owner about a finding nobody holds
- file: src/CLI/Run.jl:1037 (also src/Orchestration/Runs.jl:486, src/CLI/Run.jl:1155)
- severity: minor
- confidence: confirmed
- evidence: `gone = vcat([f.id for f in Runs.open_findings(run)], …)` — `open_findings` includes parked findings — and the questions are untouched; `open_questions` returns every `q.answer === nothing` of every run; `queue_leftovers` writes `"- [ ] " * q.id * " waits on the owner's answer (run " * rid * "): …"` for each.
- failure: park `X-003`, then `gbg run abandon` → `X-003` is in `dropped_ids` and carried nowhere; `X-003-code` stays unanswered → each subsequent close puts "waits on the owner's answer" on the queue for a finding the abandon said was not wanted; answering it `RULED_ANSWER` re-opens nothing (the id is dropped).
- fix: on abandon, answer or remove the questions of dropped findings (or exclude questions of `dropped_ids` in `open_questions`).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `abandon` removes the unanswered questions of dropped findings.

### H-11: "I make the change" says "the finding goes on your list", but nothing lists it
- file: src/Orchestration/Runs.jl:472 (also src/CLI/Run.jl:1131, src/Orchestration/Runs.jl:425)
- severity: minor
- confidence: confirmed
- evidence: option: `Model.Option(OWNER_ANSWER, "the change is yours: the finding goes on your list, and the run leaves it", true)`; `open_findings` excludes `!owner_took(run, f.id)`; `queue_leftovers` writes `open = [f for f in Runs.open_findings(run) …]`, `notes` and `waiting` (unanswered questions) only; `carry_over` takes `workable(prev)`; `Render.report` names neither `to_owner` nor `owner_took` (grep empty).
- failure: the owner answers "I make the change" → the finding leaves `open_findings`, is not queued at close, is not carried into the next run, and the answered question's line leaves the queue; the only trace is the answered question inside `run.json`/`report.md`. The consequence text promises a list entry the code never writes.
- fix: include `Runs.to_owner(run)` in `queue_leftovers` with a "yours to change" line, or reword the option.
- verified: yes, by reading (2026-09-26) · fate: refused — already done: `gbg answer … "I make the change"` writes the finding under "## Code the owner asked for" (`Answer.owner_line!`, verified); a close line would list it twice.

READ: src/CLI/Run.jl, src/Orchestration/Runs.jl, src/Orchestration/Agents.jl, src/Orchestration/Site.jl, src/Orchestration/Scope.jl, drivers/run.js (all complete); docs/ARCHITECTURE.md §4.3, §4.4, §4.5, §8, §10; the referenced parts of src/Model.jl, src/Catalogue.jl (`target`), src/Engine/Checks.jl (`applies`), src/Engine/Questions.jl (`check`, `put`), src/CLI/Git.jl (`run`), src/Texts.jl (`reanchor` signature), test/rehearse.jl (the continue_stage test).
SKIPPED: src/Render.jl (report rendering, another group), src/CLI/Answer.jl beyond its `reverts_of` and `put` call sites, test/driver.jl beyond confirming it does not cover re-splicing, `StudyCmd`'s tagger arguments (the `taggerBrief` path is written elsewhere).

## Group F — Rules — pages, citations, shape, site, questions, judgement_* (20 findings)

### F-1: `RULE.DOC.SHAPE` reads review state (`.gbg/runs`) inside the docs build, so a build's verdict depends on whether a run is open
- file: src/Rules/shape.jl:162
- severity: major
- confidence: confirmed
- evidence: `function run_open(root::AbstractString)` / `dir = joinpath(root, ".gbg", "runs")` / `return any(d -> isfile(joinpath(dir, d, "stage")) && !isfile(joinpath(dir, d, "run.json")), readdir(dir))` and shape.jl:215 `slack = run_open(root) ? allowance : (n -> 0)`; the rule is `Model.Intention.DOCUMENTATION` with a `FILE_TREE` check (shape.jl:343-345), and `ext/GBGCodingToolsDocumenterExt.jl:53` runs `run_all(cfg, root; intention = DOCUMENTATION, …)` in every docs build.
- failure: reproduced: a unit recorded at 500 words grown to 505; with `.gbg/runs/r1/stage` present and no `run.json` the check reports 0 findings, without it 1. A docs build on a tree with an open run (a `stage` file is not gitignored, and the hook tells a session to leave a run OPEN across sessions, so it can be committed) answers differently from a fresh clone or CI — the core invariant in CLAUDE.md ("nothing a consumer's docs build … runs may read review state").
- fix: pass the allowance in from the caller that knows a run is open (`gbg run`/`docfix`), and never consult `.gbg/runs` from the check.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `Shape.run_open` replaced by process-local `IN_RUN`, set by `docfix` while a run is open; architecture test forbids `.gbg/runs` in rules/checks.

### F-2: `record_grown` re-records EVERY grown unit at close, not "what grew within the allowance", and so resets the ratchet on any growth
- file: src/Rules/shape.jl:179
- severity: major
- confidence: confirmed
- evidence: `(b !== nothing && any(now .> b)) || continue` / `base[key] = (max(now[1], b[1]), max(now[2], b[2]), max(now[3], b[3]))` — `allowance` is never consulted; docstring (shape.jl:175-177): "what a run's fixes grew within the allowance is written to the baseline"; `src/CLI/Run.jl:946` calls it unconditionally at close.
- failure: reproduced: a unit recorded at 3 words rewritten to 500 (far past `allowance(3) == 10`, and with no run open at all) — `prose_shape` reports `GREW: words 3→500`; `record_grown` returns `["p.md § Notes: words 3→500 …"]` and rewrites the CSV; `prose_shape` afterwards reports nothing. Growth the build would refuse — including growth by the owner's own edits, unrelated to the run — is silently baselined at the next close. The module docstring's promise ("The baseline is rewritten only deliberately, with a reason") does not hold.
- fix: re-record only units whose growth is within `allowance` of the recorded numbers, and only those the run's own fixes touched.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `record_grown` re-records only growth within `allowance` of the recorded numbers.

### F-3: a unit's key carries a positional `(n)` suffix, so inserting a same-named section earlier re-points every later duplicate's baseline row
- file: src/Rules/shape.jl:64
- severity: minor
- confidence: confirmed
- evidence: `function unique_key(key)` / `n = 2` / `while haskey(out, key * " ($n)"); n += 1; end` — the suffix is the order of encounter, the very thing the comment at shape.jl:106-109 says a positional key must not be ("would move every later one when an item is inserted — silently re-pointing the baseline rows").
- failure: reproduced: a page with `## Notes` (2 words), `## Other`, `## Notes` (100 words) gives keys `Notes`, `Notes (2)`=100; inserting a new `## Notes` at the top gives `Notes`, `Notes (2)`=2, `Notes (3)`=100 — the 100-word unit is now NEW (held to caps, its ratchet lost) and the row `Notes (2)` now measures a different unit; the reverse edit reports a false GREW. Same for two `.jl` files with the same basename and signature (`basename(f)` at shape.jl:81).
- fix: key duplicates by something stable (the heading path, or the file's relative path rather than its basename), or report a collision instead of numbering it.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — no positional suffix; shared basenames use the path; a real clash is reported.

### F-4: `RULE.CIT.DOI` reports any bullet containing an author–year citation as "a reference with no DOI"
- file: src/Rules/citations.jl:27
- severity: major
- confidence: confirmed
- evidence: `const REFERENCE_LINE = r"^\s*(Reference:|-\s+.*\((19|20)\d\d[a-z]?\))"` and citations.jl:56-61 `occursin(REFERENCE_LINE, line) || continue` … `push!(out, … "a reference with no DOI or Open Library link on its title: …")`.
- failure: reproduced: `- Kolmogorov (1941) gives the 5/3 law.` and `- The fix landed (2024).` are both reported. `RULE.CIT.STYLE` REQUIRES author–year in prose; a bullet list summarising results by author–year (or a changelog bullet with a year) is not a reference entry, and the statement ("every reference carries a clickable DOI") does not forbid it.
- fix: require a reference SHAPE (a title in italics, or a journal/publisher after the year) rather than any bullet with a year in parentheses.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a reference bullet needs a reference shape (italic title, or pages after the year).

### F-5: a DOI containing parentheses is truncated at its first `)`, so `RULE.CIT.RESOLVES` asks the resolver for a wrong URL
- file: src/Rules/citations.jl:339
- severity: major
- confidence: confirmed
- evidence: `eachmatch(r"\[([^\]]*)\]\((https://(?:doi\.org|openlibrary\.org)/[^)\s]+)\)", …)`; likewise `TITLE_LINK = r"\[(\*[^\]]+?\*)\]\((https://doi\.org/[^)\s]*)\)"` (citations.jl:25) and `DOI_RE = r"doi\.org/[^\s\)\]\"]+"` (citations.jl:23).
- failure: reproduced with a canned resolver: `[*A method*](https://doi.org/10.1016/0021-9991(84)90019-3)` → the resolver is asked `https://doi.org/10.1016/0021-9991(84`. Pre-2000 Elsevier DOIs carry `(yy)` routinely; against the real resolver that URL is 404 and a correct reference is reported as "does not resolve". `FULL_INLINE` truncates both sides the same way so its DOI comparison only works by accident, and its "DOI … absent from the canonical list" message would print the truncated DOI.
- fix: match the URL by balanced parentheses (or up to the `)` that is followed by end-of-link context), as `Texts.unwrapped` already balances brackets.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — DOIs match balanced parenthesised groups in all three patterns.

### F-6: `Citations.sources` drops every glob a package names for its docstring set and silently reads all of `src/` and `ext/` instead
- file: src/Rules/citations.jl:181
- severity: major
- confidence: confirmed
- evidence: `named = get(cfg.filesets, Model.FileSet.DOCSTRINGS, String[])` / `files = [p for p in named if isfile(joinpath(root, p))]` / `isempty(files) || return files` — then a walk of `src/`+`ext/` that also skips `Texts.ignored`. The same defect is recorded as fixed in shape.jl:327-329 ("Reading the package's patterns with `isfile` dropped every GLOB").
- failure: a package whose config sets `filesets = Dict(DOCSTRINGS => ["src/Public/**/*.jl"])` (a pattern, which is what `DEFAULT_PATTERNS` itself uses) has `RULE.CIT.FULL_INLINE` read every `.jl` under `src/` and `ext/` — including gitignored ones, which `Texts.files` excludes — while every other DOCSTRINGS rule honours the config. The docstring ("what the config's docstring set names") is false.
- fix: `return Texts.files(cfg, root, Model.FileSet.DOCSTRINGS)`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `Citations.sources` is `Texts.files(cfg, root, DOCSTRINGS)`.

### F-7: the `RULES` docstrings in citations.jl and pages.jl are attached to nothing; `const RULES` has no docstring in either module
- file: src/Rules/citations.jl:274
- severity: minor
- confidence: confirmed
- evidence: citations.jl:274-283 `"""\n    RULES\n\nThe rules of this batch.\n"""` followed by a `# ───` comment and the `RESOLVER` docstring, with `const RULES = …` at line 383 bare; pages.jl:380-385 the same, with `const RULES` bare at line 472. Reproduced: `@doc GBGCodingTools.Catalogue.Citations.RULES` and `@doc …Pages.RULES` both return `nothing`.
- failure: the docstring the file shows for `RULES` documents nothing (ARCHITECTURE §7 names "docstrings in the source attached to nothing" as a defect a program finds), and the binding it was written for is undocumented at the REPL.
- fix: move the two docstrings onto their `const RULES` lines.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — both RULES docstrings sit on their `const RULES`.

### F-8: `RULE.DOC.AI_BANNER` exempts a Markdown page as "a script" when any hard-wrapped prose line starts with `module `, `function `, `import `, `const `, `struct `, `using ` or `macro `
- file: src/Rules/pages.jl:43
- severity: major
- confidence: confirmed
- evidence: `is_script = occursin(r"(?m)^(using|import|function|const|module|struct|macro)\s", unfenced)` / `is_script && !occursin(LITERATE_HEADING, text) && return Model.Location[]` — applied to every file the rule reads, `.md` pages included; a Markdown page never carries a `# #` Literate heading.
- failure: reproduced: the rationale page `# Design\n\nThe map is what a\nmodule docstring says about itself.\n` with no banner → 0 locations. In this package every page must carry the banner (`banner_pages = ["docs/src/**/*.md", "docs/ARCHITECTURE.md"]`); a page whose wrapping happens to put "module", "function" or "const" at a line start passes without it — the same silent-pass class the test at test/rules.jl:342-350 was written against.
- fix: apply the script test only to `.jl` files (the runner hands the check the text only; give it the file, or decide by `endswith(file, ".jl")` in `reading`).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the script exemption also needs the text to parse as Julia.

### F-9: `sibling_link` never reads the `sibling_sites` setting its docstring says a package overrides with, and `Setting.value` cannot hold one
- file: src/Rules/pages.jl:325
- severity: minor
- confidence: confirmed
- evidence: `for (name, site) in SIBLING_SITES.default` — the only read; `cfg.settings` is not consulted anywhere in `sibling_link`. Docstring pages.jl:302-303: "A package overrides this with a [`Model.Setting`](@ref)". `Model.Setting.value::Union{String,Symbol,Bool,Int,Vector{String},Vector{RetiredClaim}}` (Model.jl:297) admits no `Vector{Pair}`.
- failure: the rule is rendered with a settable parameter that no config can set and no check would honour; the docstring is false about the code.
- fix: drop the override claim and the parameter, or read the setting.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the false override claim and the unusable parameter removed.

### F-10: `RULE.DOC.NO_DEAD_REFS` says "a docstring or error message" but the check reads docstrings only
- file: src/Rules/pages.jl:216
- severity: minor
- confidence: confirmed
- evidence: statement `"A docstring or error message cites no section number and no inaccessible source; it reads complete at the REPL."` with `filesets = [Model.FileSet.DOCSTRINGS]`; the runner hands a DOCSTRINGS rule `Texts.prose_text(…; comments = false)` (Checks.jl:129-130), which keeps docstring lines alone.
- failure: `error("see §4 of the design")` in the source is never read; what the statement forbids is missed.
- fix: read `CODE` (raw source) for the `§` pattern inside string literals, or narrow the statement.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — statement narrowed to docstrings.

### F-11: `ci_manual` reads commented-out trigger lines as triggers, misses a quoted `"on":` key, and reports a docs workflow on a bare `push:`
- file: src/Rules/judgement_git.jl:22
- severity: major
- confidence: confirmed
- evidence: `i = findfirst(l -> occursin(r"^on:", l), lines)` (only an unquoted key); `wrong = occursin(r"pull_request|schedule|branches", block)` on the raw block with comments; docs branch `occursin(r"\bpush\b", block) && occursin("branches", block) ||` push a finding.
- failure: reproduced: (a) a test workflow `on:\n  workflow_dispatch:\n  # pull_request:\n  push:\n    tags: ["*"]` — compliant — is reported "runs on a branch push, a pull request or a schedule"; (b) `"on":\n  pull_request:` with `julia-runtest` (quoting `on` is common because YAML reads bare `on` as a boolean) is skipped and reported clean; (c) a docs workflow `on:\n  push:` (every branch push, which satisfies "docs deploy on push") is reported "does not run on a branch push".
- fix: strip `#…` comments before matching, accept `^["']?on["']?:`, and treat a bare `push:` (or `on: push`) as a branch push.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — comments stripped; quoted `"on":` accepted; a bare `push:` is a branch push.

### F-12: `RULE.GIT.PUSH` passes a repository with commits and no upstream — the one state in which nothing has ever been pushed
- file: src/Rules/judgement_git.jl:191
- severity: major
- confidence: confirmed
- evidence: `git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 || return 0` at the head of `PUSH_HOOK` (and of `TRAILER_HOOK`, line 198). The comment at 182-183 justifies silence only "where git or a repository is missing".
- failure: reproduced: `git init -b master`, two commits, no remote → `PUSH.check.run(root, cfg)` returns `[]`; `gbg check` and the end-of-turn hook both report the commit ⇒ push rule met. A branch whose upstream was deleted behaves the same. The trailer rule is likewise silent on every commit of such a repository.
- fix: when there is no upstream and `git rev-list --count HEAD` is nonzero, print "no upstream; N commit(s) never pushed".
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — with no upstream the push rule reports the commits never pushed; the trailer rule checks them all.

### F-13: `hooked` reports a history rule clean when `bash` is absent instead of "cannot evaluate"
- file: src/Rules/judgement_git.jl:220
- severity: minor
- confidence: plausible
- evidence: `said = try read(pipeline(ignorestatus(`bash -c …`)…), String) catch "" end  # no bash: nothing to say` and `Checks.not_run` (Checks.jl:215-226) lists no HISTORY rule.
- failure: on a host without `bash` (or with `git` missing, where every fragment `return 0`s), `gbg check` runs the three git rules, gets nothing, and exits 0 — a check that could not run is reported clean rather than as exit 2, against "a crash is never reported as a finding" and the `not_run` promise that a caller "can say what it did not check rather than reporting clean".
- fix: return a distinguishable "could not run" from `hooked` and have `gbg check` exit 2 on it.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `hooked` returns a "cannot evaluate: …" location when bash or git is missing; `gbg check` exits 2 on it.

### F-14: `page_bindings` looks for `<article class="docstring">`; Documenter 1.x renders `<details class="docstring">`, so `RULE.DOC.API_GROUPING` finds zero docstrings on every real site
- file: src/Rules/site.jl:150
- severity: blocker
- confidence: confirmed
- evidence: `if t === :article && "docstring" in Texts.classes(n)`; the built page `docs/build/api/Catalogue.html` (Documenter 1.19.0 per docs/Manifest.toml) holds `<details class="docstring" open="true"><summary id="GBGCodingTools.Catalogue"><a class="docstring-binding" href="#GBGCodingTools.Catalogue">…`.
- failure: reproduced on this package's own built site: `page_bindings` over every page returns 0 bindings while `Texts.elements(art, e -> tagname(e) === :details && "docstring" in classes(e))` finds 9 on one page; `api_grouping(build)` returns `[]`. The rule ("one docstring has one home; a Base function the package extends is public") is blind in every consumer build and reports clean. Its four `SiteExample`s pass for the wrong reason: they are written in markup Documenter does not emit.
- fix: match `details` (and keep `article` for older Documenter), and take the binding anchor as `a.docstring-binding` rather than the first `<a>`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `details.docstring` and `article.docstring` both matched; binding from `a.docstring-binding`; examples in Documenter 1.x markup.

### F-15: `rendered_math` reports one unrendered display formula once per enclosing block
- file: src/Rules/site.jl:46
- severity: minor
- confidence: confirmed
- evidence: `for el in Texts.elements(art, e -> Texts.tagname(e) in (:span, :div, :p))` / `t = strip(Texts.text_of(el))` — a `div` whose only text is its `p`'s formula has the same stripped text.
- failure: reproduced: `<div><p>\[x = `y`\]</p></div>` → 2 locations for one span; Documenter wraps display math in nested blocks routinely, so each real defect is counted twice or more.
- fix: report only elements with no matching descendant (innermost), or the `p.math-container` alone.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — only the innermost block holding an unrendered span is reported.

### F-16: `rendered_markup` reports a glob or a product in prose as unrendered markup, once per asterisk
- file: src/Rules/site.jl:110
- severity: minor
- confidence: confirmed
- evidence: `for m in eachmatch(r"\*\*?[^\s*]|(?<![\w\\])__[^\s_]", line)` — any `*` followed by a non-space character.
- failure: reproduced: `<p>every *.md file under docs, and 2*3 is six</p>` → two locations, both with the same excerpt. Neither asterisk is markup that failed to render (Markdown left them because they are not emphasis), so the statement "no markup shows as literal characters" does not forbid them; a page with a wildcard in prose is reported on every build.
- fix: match a PAIRED unrendered span (`\*[^*\n]+\*`, `\*\*[^*\n]+\*\*`, `__…__`) and report one location per line.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a paired unrendered span is required, one location per line.

### F-17: the `Site.RULES` docstring says "None carries examples"; all three rules carry `SiteExample`s
- file: src/Rules/site.jl:222
- severity: minor
- confidence: confirmed
- evidence: `The rules of this batch. None carries examples: an example of a built site is a site, and the design's own answer is that site examples are materialised in one Documenter build — which arrives with the instrument that needs it.` against `examples = [ Model.SiteExample(…` at site.jl:65, 127 and 202.
- failure: the docstring is false about the code, and describes a materialisation (a Documenter build) that test/rules.jl:74-84 explicitly does not do.
- fix: rewrite the docstring.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the Site.RULES docstring says what the examples are.

### F-18: `RULE.ASK.NO_COORDINATES` reports "e.g." and "i.e." as a qualified name
- file: src/Rules/questions.jl:85
- severity: minor
- confidence: confirmed
- evidence: `r"\b[A-Za-z_][A-Za-z0-9_]*\.[a-z][A-Za-z0-9_]*\b" => "a qualified name"`.
- failure: reproduced: decision `Should the cap stay, e.g. at 120 words?` → `["a qualified name in the decision: e.g"]`. An ordinary English abbreviation — which `one_decision` (questions.jl:35) explicitly allows for — is reported as a code coordinate on every question that uses it; `put` prints the failed rule to the owner.
- fix: exclude `e.g`, `i.e` (and require the first segment to be at least two characters, or a capital) in the qualified-name pattern.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — e.g., i.e., etc., vs., cf. excluded (the "two characters needed before the dot" this line first said was never the program; corrected at verification).

### F-19: a package-added house term is compiled as a regular expression, unescaped
- file: src/Rules/questions.jl:145
- severity: minor
- confidence: confirmed
- evidence: `occursin(Regex("(?<![A-Za-z])" * replace(t, " " => "\\s+") * "(?![A-Za-z])", "i"), masked)` where `t` comes from `s.value` of the `:house_terms` setting; contrast `retired_claims` (pages.jl:421-425), which escapes "so nothing a package writes in its config is compiled as a pattern".
- failure: a term such as `C++` or `f(x)` in a package's config throws (`C++` is not a valid pattern) or matches the wrong text (`f(x)` matches "fx") the next time any question is put in that package.
- fix: escape `t` as `retired_claims` does.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — house terms escaped before the pattern is built.

### F-20: four rules read a setting by name alone, so a setting declared under ANY rule's id is honoured, while `Checks.reading` (tested) requires the rule to match
- file: src/Rules/citations.jl:108
- severity: minor
- confidence: confirmed
- evidence: `s.name === :references && s.value isa String && (where_ = s.value)`; likewise pages.jl:415 `s.name === :retired_claims && …`, questions.jl:69-70 `s.name === :decision_words …`, questions.jl:139 `s.name === :house_terms …`; `ConfigIO.validate` (ConfigIO.jl:374-376) checks only that `st.rule` is a rule, not that it owns the parameter. `Checks.reading` (Checks.jl:74) requires `s.rule === rule.id`, and test/rules.jl:384-390 asserts "A setting naming another rule's parameter is not this rule's file list".
- failure: `Setting(rule = RULE.DOC.SIBLING_LINK, name = :references, value = "notes/refs.md")` — a typo in the rule id — redirects `RULE.CIT.FULL_INLINE`'s canonical list; the two conventions disagree and the config says nothing.
- fix: either validate `(rule, name)` against the rule's `parameters` in `ConfigIO.validate`, or read settings through one helper that checks the rule.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the five settings are read only under their own rule's id.

READ: src/Rules/pages.jl, src/Rules/citations.jl, src/Rules/shape.jl, src/Rules/site.jl, src/Rules/questions.jl, src/Rules/judgement_git.jl, src/Rules/judgement_api.jl, src/Rules/judgement_cit.jl, src/Rules/judgement_doc.jl, src/Rules/judgement_inst.jl, src/Rules/judgement_test.jl, src/Rules/judgement_tex.jl, src/Engine/Checks.jl, src/Engine/Questions.jl (whole); test/rules.jl (materialiser and rulebook loop); the relevant parts of src/Texts.jl (files/expand/unwrapped/docstrings/prose_text/masks/ignored/signature_line), src/Model.jl (types), src/Render.jl (hook and hook_rules), src/Catalogue.jl (FLEET/site_of/cover), src/Roles/documentation_review.jl (reader derivation), ext/GBGCodingToolsDocumenterExt.jl, src/CLI/Run.jl close, ConfigIO.validate, docs/ARCHITECTURE.md §7–§8, .gbg/config.jl.
SKIPPED: the rest of src/Texts.jl, src/Orchestration/*, src/CLI/* beyond the Shape and Checks call sites, and the other rule files (arguments, docstrings, latex, modules, reflection, rendering) — other groups' files; the judgement_* files carry no program checks, so beyond their statements, `access` tags and reader coverage (verified: every READER-cover rule is bound to a bundle by its access tag) there was nothing to run.

## Group G — Texts (17 findings)

### G-1: `page_text` crashes with `UndefVarError` on any page holding a link — `getattr` is never imported
- file: src/Texts.jl:1232
- severity: blocker
- confidence: confirmed
- evidence: `using Gumbo: parsehtml, HTMLDocument, HTMLElement, HTMLText, children` (line 23) and `href = t === :a ? String(something(getattr(n, "href", nothing), "")) : ""` (line 1232); `isdefined(Texts, :getattr)` is `false`; `T.page_text(T.article_of(parsehtml("<article class=\"content\"><p><a href=\"x\">here</a></p></article>")))` throws `UndefVarError: getattr not defined in GBGCodingTools.Texts`.
- failure: `Site.pages` (src/Orchestration/Site.jl:135) calls `page_text` on every built article; every Documenter article carries `<a class="docs-heading-anchor">` in each heading, so the first real built site crashes the run (exit 3, not a finding). The one test (test/anchors.jl:432) uses a page with no `<a>`, so it cannot fail. Added in 0a6bb66 today.
- fix: add `getattr` to the `using Gumbo:` list (or write `get(n.attributes, "href", "")` as `attr` does) and give the test a link.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `page_text` reads href through `attr` (no `getattr`); new test page carries a heading anchor and a link.

### G-2: a gitignore pattern holding a regex metacharacter, or an escaped trailing space, is compiled unescaped — `foo(1).txt` ignores `foo1.txt` and `foo\ ` / `x)` throw out of `ignored`
- file: src/Texts.jl:626
- severity: major
- confidence: confirmed
- evidence: `body = replace(line, "." => "\\.", "**" => "\0", "*" => "[^/]*", "?" => "[^/]")` — only the dot is escaped; `push!(rules, (Regex("^" * … * body * tail * "\$"), negated))`. With a `.gitignore` of `foo(1).txt`: `ignored(root)("foo(1).txt") == false`, `("foo1.txt") == true` (git: the reverse). `gitignore_rules_of("foo\\ ")` and `gitignore_rules_of("x)")` throw `ErrorException` (PCRE compile error). `[!a]*.md` (git's negated class) excludes `a.md` and keeps `b.md`.
- failure: any consumer `.gitignore` line with `(`, `)`, `+`, `{`, `|`, `^`, `$` or a trailing `\ ` → `ignored` (called by `files`, called by every check and every `place`/`occurrences`) either misclassifies or throws → a whole run exits 3 on a consumer's ordinary ignore file, not a finding and not "cannot evaluate". The same class was fixed in `glob_matches` on 2026-09-23 (line 94) and not here.
- fix: escape every regex metacharacter except the gitignore wildcards `*`, `?`, `[`…`]` before building the regex (and translate `[!` to `[^`), and unescape `\ `, `\#`, `\!`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — one `wildcard_source` grammar escapes every metacharacter but the wildcards; `[!…]` classes; `\\ `/`\\#`/`\\!` unescape.

### G-3: `**` at the start or in the middle of a gitignore pattern requires at least one directory — `**/build` misses `build` at the root, `a/**/b` misses `a/b`
- file: src/Texts.jl:627-630
- severity: major
- confidence: confirmed
- evidence: `body = replace(body, "\0" => ".*")` then `anchored = … occursin('/', strip(line, '/'))` so `**/build` → `^.*/build(?:/.*)?$` and `a/**/b` → `^a/.*/b(?:/.*)?$`. Measured: `ignored(root)("build") == false` with `.gitignore` = `**/build` (git check-ignore: true); `("docs/gen") == false` with `docs/**/gen` (git: true).
- failure: a package ignoring `**/build` or `docs/**/generated` has its root `build/` (and every file under it) READ as source by every check and by `place`/`occurrences` — the "264 findings against 108 real ones" case this predicate exists for.
- fix: render a leading `**/` as `(?:.*/)?` and a mid-pattern `/**/` as `/(?:.*/)?`, as git does.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `**/` at start and `/**/` mid become `(?:.*/)?`, as git reads them.

### G-4: a nested `.gitignore` is applied to the directory holding it with an empty relative path, so `*` + `!keep.md` (the idiom for keeping a directory) excludes the whole directory, re-inclusions included
- file: src/Texts.jl:575-590
- severity: major
- confidence: confirmed
- evidence: `startswith(f, prefix) || continue; rest = f[nextind(f, 0, length(prefix) + 1):end]` — for `f = "data/"` and the level `data/`, `rest == ""`, and `^(?:.*/)?[^/]*(?:/.*)?$` (the `*` rule) matches the empty string; the closure then tests every parent: `decide(join(parts[1:k], '/') * "/") && return true`. With `data/.gitignore` = `*\n!keep.md\n!.gitignore\n`: `ignored(root)("data/keep.md") == true`, `("data/.gitignore") == true`; git check-ignore says both are tracked.
- failure: a consumer keeping `docs/src/generated/` (or any directory) with the `*`/`!` idiom has every re-included page in it dropped from every file set and every search, silently.
- fix: skip a level whose prefix equals the path being decided (git applies a `.gitignore` only to paths strictly below its directory), or never test `rest == ""`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a nested `.gitignore` applies only strictly below its directory; the `*` + `!keep.md` idiom keeps what it says.

### G-5: `.github/.gitignore` (and any `.git*` directory's) is skipped as if it were `.git/`
- file: src/Texts.jl:565
- severity: minor
- confidence: confirmed
- evidence: `startswith(rel, ".git") && continue` — `rel` is `.github` for that directory. Measured: `.github/.gitignore` = `secret.md` → `ignored(root)(".github/secret.md") == false`; git: ignored.
- failure: a file under `.github/` the package ignores is read; low reach since no file set defaults there.
- fix: `rel == ".git" || startswith(rel, ".git/")`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — only `.git` and `.git/…` are skipped when collecting `.gitignore` levels.

### G-6: `expand` escapes only the dot, so a directory name with `(`, `)`, `+`, `{` … is walked wrongly, and disagrees with `glob_matches` on the same pattern
- file: src/Texts.jl:105
- severity: minor
- confidence: confirmed
- evidence: `rx = Regex("^" * replace(replace(replace(pattern, "." => "\\."), "**/" => "\0"), "*" => "[^/]*") * "\$")` against `glob_matches`'s `lit = replace(pat, r"([.^$|?()\[\]{}+\\])" => s"\\\1")` with the comment "found in review, 2026-09-23". Measured with files `docs/n (old)/y.md` and `docs/n old/y.md`: `expand(root, "docs/n (old)/*.md") == ["docs/n old/y.md"]` while `glob_matches` accepts only `docs/n (old)/y.md`. Same for `docs/a+b/*.md` → `["docs/ab/x.md"]`.
- failure: a file set pattern naming such a directory reads the wrong files, and the guard/target test (`glob_matches`) and the walk (`expand`) disagree about which paths are targets.
- fix: build both regexes through one function.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `expand`, `glob_matches` and the gitignore rules build their regex through `wildcard_source`.

### G-7: a docstring given through `@doc` (`@doc raw"""…""" f(x) = x`) is invisible to `docstrings`, `definitions` names only its definition, and `prose_text` blanks the whole block
- file: src/Texts.jl:426
- severity: major
- confidence: confirmed
- evidence: `if JS.kind(c) === JS.K"doc"` is the only branch that makes a `DocBlock`; `@doc raw"""…""" h(x) = x` parses as `macrocall`, not `doc`. Measured: `docstrings(path)` returns no block for it and `prose_text(path)` gives six empty lines where the docstring stands (while the same file's `"""…""" m(x) = 1` is returned).
- failure: every DOCSTRINGS rule (they read `prose_text`, src/Engine/Checks.jl:130) reads nothing of a docstring written with `@doc`, the form the raw-string idiom for LaTeX (`@doc raw"""`) needs; findings there cannot anchor by node either. §4.2 counts every docstring as documentation.
- fix: in `docs!` and `walk!`, treat a `macrocall` whose macro is `@doc` with a string (or `raw`-string macrocall) first argument and a definition second as a doc node.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `@doc <string|raw"…"> def` is a doc node for `docstrings`, `definitions` and `prose_text`.

### G-8: a docstring on `abstract type`, on a bare name, on a method signature or on a plain assignment gets node `""` and no definition span
- file: src/Texts.jl:241-281
- severity: major
- confidence: confirmed
- evidence: `bound_name` has branches for `function`, `macro`, `struct`, `const`/`global`, `=` with a call lhs, `macrocall`, `module` and `return nothing` otherwise — no `abstract`, `primitive`, `Identifier`, `call` or plain `=`. Measured: `"""…""" abstract type A end`, `"""…""" f`, `"""…""" g(::Int)`, `"""…""" k = 1` all give `DocBlock.node == ""` and `definitions` lists none of them (`["h", "m", "TEMPLATE"]` for the fixture).
- failure: GBGPeriodicFields has 7 and GBGHomogeneousTurbulence 11 documented `abstract type`s; a finding in any of those docstrings has no node (§4.5: the node is "the binding or method documented"), so it re-anchors only by quote across the whole file, and `node_at` reports `""` for it in every location the run records.
- fix: name `abstract`/`primitive` by their first identifier, a bare `Identifier` by itself, and a `call` by its callee.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — abstract/primitive types, a bare identifier, a call signature and a plain assignment get a name.

### G-9: `definitions`/`docstrings` docstrings claim a file that does not parse yields nothing; with `ignore_errors = true` it yields a partial list
- file: src/Texts.jl:302-303, 393
- severity: minor
- confidence: confirmed
- evidence: "A file that does not parse yields an empty list rather than an error" and "a file that does not parse yields none" against `JS.parseall(JS.SyntaxNode, src; filename = path, ignore_errors = true)`. Measured on `f(x) = 1\nfunction g(\n` (plus a docstring): `definitions` → `["f", "g"]`, `docstrings` → 1 block.
- failure: the docstring is false about the body; a caller relying on "empty means broken" (e.g. to skip a file mid-edit) gets a list.
- fix: reword the docstrings to say a broken file yields what parsed.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — both docstrings say a file that does not parse yields what parsed.

### G-10: a file-set pattern ending in `**` (`docs/**`) matches one directory level only, in both `expand` and `glob_matches`
- file: src/Texts.jl:97, 105
- severity: minor
- confidence: confirmed
- evidence: only `"**/"` is rewritten (`replace(…, "**/" => "\0")`), so a trailing `**` falls to `"*" => "[^/]*"` twice. Measured with `docs/top.md` and `docs/deep/er/z.md`: `expand(root, "docs/**") == ["docs/top.md"]`; `glob_matches("docs/**", "docs/deep/er/z.md") == false`. The docstring says "`**` spanning directories".
- failure: a consumer config declaring `examples/**` or `docs/**` as a file set reads only the top level of it and silently misses the rest.
- fix: rewrite a trailing `/**` as `(?:/.*)?` and a bare `**` as `.*`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a trailing `/**` (or `**` alone) matches everything below.

### G-11: `headings` toggles fences on any line starting with three backticks, so a four-backtick fence holding a three-backtick one, or a `~~~` fence, yields headings from code
- file: src/Texts.jl:794
- severity: minor
- confidence: confirmed
- evidence: `startswith(strip(line), "```") && (fenced = !fenced)`. Measured on "# Top\n\n````markdown\n```\n# not a heading\n```\n````\n\n## Real\n\n~~~\n# also not\n~~~\n": headings are `["Top", "not a heading", "not a heading / Real", "also not"]`; the docstring says "A heading inside a fenced code block is not a heading."
- failure: a page that shows a fenced example (Documenter/Markdown tutorials do) gets wrong heading paths for every section after it, so `node_at`, `heading_path` and BY_NODE re-anchoring name the wrong node.
- fix: track the fence's character and length and close only on a matching line, as CommonMark does.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `headings` tracks the fence's character and length, CommonMark style.

### G-12: `reading_line` leaves the backslash of an escaped dollar, so a page quote holding `$` never meets its source
- file: src/Texts.jl:982-983
- severity: minor
- confidence: confirmed
- evidence: `l = replace(l, r"\\[\[\]()]" => "")` then `replace(l, r"[`$*\[\]]" => "")` — `\$` is neither. Measured: `reading_line("costs \\\$5 here") == "costs \\5 here"`, `reading_line("costs \\\\\$5 here"; escaped = true) == "costs \\5 here"`, while the page reads `costs $5 here` → `costs 5 here`.
- failure: a reader quoting a rendered dollar sign (a price, a shell variable, `\$` in a Markdown page) is not placed in `:read` form and the location goes `OUTDATED`/unplaced.
- fix: include `\$` in the delimiter regex at line 982.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `reading_line` deletes a backslash run before `$`.

### G-13: `formulas` reads the text between two escaped dollars as a formula
- file: src/Texts.jl:1055
- severity: minor
- confidence: confirmed
- evidence: `eachmatch(r"(?<!\$)\$([^\$\n]{2,})\$(?!\$)", t)` has no exclusion for a preceding backslash. Measured: `formulas("costs \\\$5 and \\\$6 today") == ["5 and \\"]` (the backslash counts as `mathlike`, so the prose filter lets it through).
- failure: a fix pass (src/CLI/Run.jl:475) searches every document for the bogus formula `5 and \`; harmless when unfound, and a wrong "copy" when a rationale document repeats the sentence.
- fix: `(?<![\$\\])` on the opening dollar.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `formulas` does not open a formula on an escaped dollar.

### G-14: a constant built with `Rule(; id = …)` (keywords after a semicolon) gets no keyword-field nodes
- file: src/Texts.jl:363-367
- severity: minor
- confidence: confirmed
- evidence: `if JS.kind(c) === JS.K"call"` then `for a in …children(c)`: `JS.kind(a) === JS.K"="` — keywords after `;` sit under a `K"parameters"` child, which the loop never opens as a call. Measured: `const R1 = Rule(; id = :a, statement = "s")` yields `["R1"]` only, while `const R2 = Rule(id = :b, …)` yields `R2.id`, `R2.examples`, `R2.text`, `R2.text`. The docstring of `definitions` promises "each keyword field of a constant that is written as a keyword call".
- failure: no rule in this package writes `Rule(;` today, so unreached here; a `PatternRule(; …)` written that way loses the `.statement` node.
- fix: also descend into a `K"parameters"` child of the call.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `keyword_fields!` descends into a call's `parameters` child.

### G-15: `walk!`'s `prefix` is always `""`, so the qualified-name branch is dead code that reads as live
- file: src/Texts.jl:315, 333, 336, 345, 350
- severity: minor
- confidence: confirmed
- evidence: `walk!(out, tree, src, "")`, `walk!(out, kids[2], src, "")`, `walk!(out, c, src, "")` — every call passes `""` or the unchanged `prefix`; `isempty(prefix) ? name : prefix * "." * name` never takes the second branch. Measured: `g` inside `module Inner` is named `"g"`, not `"Inner.g"`.
- failure: none in behaviour; a reader takes the module-qualified naming as real, and two same-named definitions in two submodules of one file are one name to `find_nodes`.
- fix: drop the parameter, or actually pass the module name (then `node_at` and every stored `node` must agree).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the dead `prefix` parameter of `walk!` dropped; the docstring says names are bare inside submodules.

### G-16: `bound_name` names a callable-struct method `c::C`, a tuple constant `P, Q`, and an `@enum` nothing
- file: src/Texts.jl:247-248, 257-260, 266-273
- severity: minor
- confidence: confirmed
- evidence: `function (c::C)(x) end` → `node_text(first(JS.children(sig)))` gives `"c::C"`; `const P, Q = 1, 2` → `"P, Q"`; `@enum E a b` → `""` (no child of the macrocall binds). All three measured with a docstring on each.
- failure: a finding in such a docstring anchors to a name no location will ever carry (`c::C`) or to none; adds to G-8.
- fix: for a `parens`/`::` callee take the type name; for a tuple lhs the first name; for `@enum` the first identifier argument.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — callable-struct method named by its type, tuple constant by its first name, `@enum E` by `E`.

### G-17: `occurrences` re-parses the file for every hit (`node_at` → `definitions`/`headings`), 2.2 s for one quote on GBGPeriodicFields
- file: src/Texts.jl:1012-1013
- severity: minor
- confidence: confirmed
- evidence: `for line in flattened_lines(…)` `push!(out, Model.Location(; file, node = node_at(root, file, line), …))` and `node_at` calls `definitions(path)` (a full JuliaSyntax parse plus `line_range`, which scans the source from byte 1 per node) or `headings(path)`. Measured: `occurrences(cfg, PF, "the grid")` = 235 hits in 2.18 s; `place` 0.18 s; `flattened_lines(big, "the")` on a 5,770-line page 0.48 s (the `length(SubString(hay, 1, …))` per hit). Nothing quadratic in the document length was found: `unwrapped` 3 ms, `headings` 1 ms, `wrapped_lines` 84 ms on the same page.
- failure: a fix pass runs `occurrences` per finding and per formula (src/CLI/Run.jl:475); a hundred findings with short formulas cost minutes, not a wrong answer.
- fix: compute the spans once per file and look each hit up.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `nodes_of` parses once per file; `flattened_lines` counts characters incrementally.

READ: src/Texts.jl (all 1,260 lines); docs/ARCHITECTURE.md §4.2, §4.5, §5.1; src/Engine/Checks.jl:118-140; src/Orchestration/Site.jl:120-143; test/anchors.jl:415-445.
SKIPPED: the rules that call these readers (src/Rules/*), the guard and the CLI — other groups' files; Windows path handling (no host to test it on).

## Group D — Model, ConfigIO, Catalogue, Harness, TestHarness, Witnesses, Roles (24 findings)

### D-1: A ruling or a config string containing `$` is refused as "interpolated", and `append_settled` writes exactly that form, so one ruling with a `$` makes `.gbg/settled.jl` unreadable for every later read
- file: src/ConfigIO.jl:216 (and src/ConfigIO.jl:162)
- severity: major
- confidence: confirmed
- evidence: `occursin("\$", text) && (push!(problems, "line $line: an interpolated string is not data: …"); return nothing)` — checked on the SOURCE text after the interpolation check on line 215 has already passed; `println(io, "    Settled(question = ", repr(s.question), ",")` — `repr` writes `\$`.
- failure: `Config(package = "a \$ b", tool = :dev)` → REFUSED "an interpolated string is not data" (reproduced). `append_settled(root, Settled(text = "keep the \$x\$ form", …))` then `read_settled(root)` → ConfigError "line 7: an interpolated string is not data" (reproduced): the owner's whole record is exit 2 until hand-edited, though no interpolation exists. Line 214–215 already refuses real interpolation (a non-`String` child); the `$` scan is redundant and wrong for the escaped form.
- fix: drop the `occursin("\$", …)` line; the parser's child kinds already decide interpolation.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the `$` scan dropped; the parser's children decide interpolation.

### D-2: `append_settled` breaks the file's format on the second append, and a trailing comment after the closing `]` swallows the new ruling and leaves the file unparsable
- file: src/ConfigIO.jl:160
- severity: major
- confidence: confirmed
- evidence: `print(io, rstrip(rstrip(strip(existing), ']')))` followed by `println(io, "    Settled(question = ", …)` — no newline between the old tail and the new entry; a trailing `# …` after `]` is not stripped.
- failure: two appends give `            ]),    Settled(question = "q2",` on one line (reproduced; docstring says "formatted the way the rest of the file is"). A file ending `] # end of rulings` (an ordinary owner edit) gives `] # end of rulings    Settled(question = "q1",` — the ruling lands inside the comment and `read_settled` → ConfigError "the file does not parse: extra tokens after end of expression" (reproduced): the owner's record is lost to exit 2.
- fix: parse the existing file with `read_value`, and rewrite the closing `]` after a newline; refuse (ConfigError) when the tail after the last `]` is not whitespace.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `append_settled` reads the rulings as data and rewrites the file whole; an unreadable file is a ConfigError.

### D-3: A consumer's mistake in `r"…"`, `v"…"` or an over-long integer is an uncaught exception — exit 3 with a backtrace, not the documented ConfigError / exit 2
- file: src/ConfigIO.jl:243 (also :245, :223)
- severity: major
- confidence: confirmed
- evidence: `return VersionNumber(unquote(text[2:end]))`, `return Regex(unquote(text[2:end]))`, `return parse(Int, replace(text, "_" => ""))` — none inside a try; src/CLI/Main.jl:155 maps only `ConfigIO.ConfigError` to 2.
- failure: `tool = v"not a version"` → ArgumentError; `pattern = r"("` → "PCRE compilation error"; `value = 99999999999999999999999` → OverflowError (all reproduced). The docstring of `read_value` promises "Throws ConfigError listing every refusal", and CLAUDE.md: "a consumer's mistake is never a backtrace".
- fix: wrap the three conversions like `construct` does and push a "line N: … is not a version / pattern / integer" problem.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a bad `v"…"`, `r"…"` or overflowing integer is one ConfigError line.

### D-4: A `r"…"` literal is read through string-escape unquoting and loses its flags, so a package pattern rule silently means a different pattern
- file: src/ConfigIO.jl:245 (and :301)
- severity: major
- confidence: confirmed
- evidence: `return Regex(unquote(text[2:end]))` with `unquote(s) = replace(strip(s, '"'), "\\\"" => "\"", "\\\\" => "\\", "\\n" => "\n")`.
- failure: a config `r"\\d"` (Julia: the raw pattern `\\d`, a literal backslash then `d`) becomes `r"\d"` (any digit); `r"x"i` becomes the pattern `x"i` with no flag (both reproduced); `r"\\"` (a valid Julia regex matching one backslash) crashes "PCRE: \ at end of pattern" (reproduced). A raw-string macro takes no `\"`/`\\`/`\n` escapes.
- fix: take the pattern from the parser's string child (`node.val` as line 221 does for strings) and the flags from the trailing identifier, then `Regex(pattern, flags)`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a regex is read from the parser's string child with its flags.

### D-5: `:(…)` and `quote … end` are accepted as a Symbol of their source text, though the reader is documented to refuse anything but a literal
- file: src/ConfigIO.jl:228
- severity: minor
- confidence: confirmed
- evidence: `elseif k === JS.K"quote"                                   # :a_symbol` / `return Symbol(strip(text, ':'))` — `K"quote"` also covers `:(expr)` and `quote…end`.
- failure: `tool = :(getpid())` → accepted as `Symbol("(getpid())")`; `tool = quote getpid() end` → `Symbol("quote getpid() end")` (both reproduced). Nothing is evaluated, but a program-shaped value passes as data with a nonsense symbol instead of a refusal naming the line.
- fix: accept `K"quote"` only when its one child is a `K"Identifier"`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a quote node is accepted only as `:Identifier`.

### D-6: A repeated keyword silently takes the last value, and positional arguments are silently dropped when any keyword is present
- file: src/ConfigIO.jl:283 (and :307)
- severity: minor
- confidence: confirmed
- evidence: `kwargs[Symbol(node_name(kid[1]))] = build(kid[2], path, problems)` (a Dict assignment); `return isempty(kwargs) ? T(positional...) : T(; kwargs...)`.
- failure: `Switch(target = :a, reason = "x", reason = "y")` → reason "y" (Julia itself refuses a duplicate keyword); `Switch(:dropped, target = :b, reason = "r")` → `:dropped` vanishes without a word (both reproduced). Positional-only calls (`Switch(:b, "r", ["f"])`) are also accepted, where the design (§5.2) admits "keyword calls to the constructors".
- fix: push a problem on a repeated keyword and on a positional argument.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a repeated keyword, and a positional argument beside keywords, are refused.

### D-7: A typed array literal is not narrowed, so `Setting(value = String["x"])` is refused while `["x"]` is accepted, and an empty list-valued setting cannot be written at all
- file: src/ConfigIO.jl:241
- severity: minor
- confidence: confirmed
- evidence: `return Any[build(c, path, problems) for c in cs[2:end]]` (the `K"ref"` arm; the `K"vect"` arm on line 234 calls `narrow`), against `Setting.value::Union{String,Symbol,Bool,Int,Vector{String},Vector{RetiredClaim}}`.
- failure: `value = String["x"]` → "Setting(…) does not accept what it was given — Cannot convert"; `value = []` and `value = String[]` → the same (all reproduced). The comment on line 236 calls the typed literal "the one documented way" a config says none. The `narrow` docstring (line 70) also claims "every field of Model typed Vector{String} refuses one", which is false for a plain `Vector{String}` field (convert works) and true only for the Union.
- fix: build `Vector{T}` from the named element type in the `K"ref"` arm.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `T[…]` is built as `Vector{T}`; the `narrow` docstring corrected.

### D-8: `validate` accepts a `Setting` on a retired rule, a `Setting` whose parameter name no rule has, and a deferral beside a file-scoped switch on the same rule
- file: src/ConfigIO.jl:375 (and :371, :469 of src/Catalogue.jl)
- severity: minor
- confidence: confirmed
- evidence: `judge_names && !(st.rule in known) && push!(problems, …)` where `known_ids()` does `for r in RETIRED; push!(ids, r.id); end`; the deferral check `any(s -> s.target === d.rule && isempty(s.files), cfg.switches)`; nothing compares `st.name` with `rule.parameters`.
- failure: `Setting(rule = Symbol("RULE.INST.SEEDS"), name = :x, value = 1)` and `Deferral(RULE.DOC.GRAMMAR) + Switch(RULE.DOC.GRAMMAR, files = ["docs/x.md"])` → `validate` returns `String[]` (reproduced); a setting `name = :allowed` misspelt for `:mathbf_allowed` is read by nobody (`Catalogue` matches `s.name === p.name`) and reported by nobody. §9: "A rule cannot be both switched off and deferred."
- fix: check `st.name` against the named rule's parameters, and refuse a setting on a retired id and a deferral with any switch on the rule.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `validate` refuses a setting on a retired/unknown rule or unknown parameter, and a deferral beside any switch on the rule.

### D-9: A package's own `PatternRule`s (`Config.rules`) are rendered into the rulebook and never run by any build, test or check
- file: src/Engine/Harness.jl:52 (and src/Render.jl:980 — the only reader of `cfg.rules`)
- severity: major
- confidence: confirmed
- evidence: `for rule in rules` / `rule.intention === Model.Intention.CODE || continue` / `append!(found, Checks.run_rule(rule, cfg, root))` — `cfg.rules` is never consulted; `grep -rn "\.rules\b" src ext` finds only `Render.jl:980 if !isempty(cfg.rules)` outside Model/ConfigIO.
- failure: a config with `rules = [PatternRule(id = :no_todo, …, pattern = r"TODO", forbidden = true)]` is accepted, its statement is printed in `.gbg/policy/` as a rule of the package ("A rule a package adds for itself is a `PatternRule` in the same file"), and a page full of `TODO` passes every build and test. The examples it carries are also verified by nothing.
- fix: run each `PatternRule` over its file set in `Checks.run_all`/`Harness.test` and the docs wrapper, and materialise its examples in the same place the rulebook's are.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `Checks.run_patterns` runs a package's `PatternRule`s in `run_all` and `Harness.test` (their examples are still checked by nothing — noted).

### D-10: `Harness.test(root; rules = MY_RULES)` — the call §11 prints — runs the package's rules INSTEAD of the rulebook's code rules
- file: src/Engine/Harness.jl:44
- severity: major
- confidence: confirmed
- evidence: `function test(root::AbstractString; rules = Catalogue.RULES, checks = (), contracts = nothing)` … `for rule in rules`; docs/ARCHITECTURE.md:792 `GBGCodingTools.Harness.test(MyPackage; rules = MY_RULES)` and §5.2 "a package rule needing a function lives in the package's own tests as a `Rule` passed to `Harness.test`".
- failure: a consumer following the design passes its one extra rule and the six `RULE.GIT.*` code checks silently stop running in its `Pkg.test()`; the suite stays green. (The signature also takes a root string where the design shows the module.)
- fix: run `Catalogue.RULES` always and append the `rules` argument to it (rename it `extra`).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `Harness.test` always runs `Catalogue.RULES`, then `extra`; §11 and §5.2 show `Engine.Harness.test(root; extra = …)`.

### D-11: The banner names the PIN, not the version that ran
- file: src/Engine/Harness.jl:46 (and :70)
- severity: minor
- confidence: confirmed
- evidence: `println("GBGCodingTools ", tool_name(cfg), " checks")` with `tool_name(cfg) = cfg.tool isa VersionNumber ? "v" * string(cfg.tool) : "vdev"`; docstring: "Prints one banner line naming the version that ran, which a consumer's CI reads to know the suite was this package's".
- failure: a consumer whose test Manifest resolved an older release than `Config.tool` names (the Pkg.resolve trap recorded on PF, rc.5 running under an rc.6 pin) prints the pin; CI reads the wrong version as having run.
- fix: print `pkgversion(GBGCodingTools)` (as `CLI/Main.jl:101` does), and the pin beside it when the two differ.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the banner names `pkgversion`, and the pin beside it when they differ.

### D-12: `Catalogue.GENERATED` is an empty constant nothing reads; the live registry is `Render.GENERATED`
- file: src/Catalogue.jl:431
- severity: minor
- confidence: confirmed
- evidence: `const GENERATED = Model.Generated[]` with the docstring "It is empty until the generators exist."; every reader (`src/Render.jl:705,1111,1419,1467`, `src/CLI/Check.jl:56`, `src/CLI/Wire.jl:121`) names `Render.GENERATED`; §5.1 places `GENERATED — data` in `Catalogue`.
- failure: a reader of the design or of `Catalogue` takes the empty registry as the register of generated files; the design's module table does not describe the code.
- fix: delete it, or move `Render.GENERATED`'s table here and have `Render` read it.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the empty `Catalogue.GENERATED` deleted; §5.1 and §6 name `Render.GENERATED`.

### D-13: Stale docstrings and comments describe the conversion as in progress and the module as holding only the instrument table
- file: src/Catalogue.jl:9 (also :153–155, src/ConfigIO.jl:357–360)
- severity: minor
- confidence: confirmed
- evidence: "What is in it today is the instrument table; the rules arrive with the conversion and the agent roles with the instruments that launch them."; "The ninety-five rules of `policy/RULES.toml` are converted in batches"; "While the ninety-five rules are being converted, `RULES` is short by construction … this arm turns itself on when the conversion ratchet reaches zero" guarding `judge_names = !isempty(Catalogue.RULES)`.
- failure: `policy/RULES.toml` and `policy/` no longer exist (CLAUDE.md: "There are NO scans and no `policy/`"); the rulebook is complete; the guard is dead and its comment sends a reader to a file that is gone.
- fix: reword the three, and drop `judge_names`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the stale Catalogue docstrings reworded; `judge_names` removed.

### D-14: `normal_path` slices an absolute path by character count, so a root with a non-ASCII character returns a wrong (absolute) path
- file: src/Catalogue.jl:311
- severity: minor
- confidence: confirmed
- evidence: `p = p[length(r)+2:end]` after `startswith(p, r * "/")`.
- failure: `normal_path(cfg, "/tmp/Ünter/pkg", "/tmp/Ünter/pkg/docs/a.md")` → `"/docs/a.md"` (reproduced) instead of `"docs/a.md"`: the finding is then "outside the package" by the next line's logic or anchored to a path that does not exist. Not reachable with the fleet's current ASCII paths.
- fix: `p = p[ncodeunits(r)+2:end]` (or `chopprefix(p, r * "/")`).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `normal_path` uses `chopprefix`.

### D-15: The design's printed types drift from the code and the test that claims to compare them checks five structs only
- file: src/Model.jl:466 (and :330, :869–879; docs/ARCHITECTURE.md §5.2; test/architecture.jl:171–177)
- severity: minor
- confidence: confirmed
- evidence: code `files_parameter::Union{Symbol,Nothing} = nothing` on `Rule`, `settings::Vector{Setting}` on `TextExample`, and `passes, model, sequential, scope, base, driver, already_failing, dropped, unreverted, silent, rulebook` on `Run` — none printed in §5.2; the test's "every struct it prints, with the fields it names on them" loop is `for (name, fields) in (:Location => …, :FindingDraft => …, :Finding => …, :Option => …, :Switch => …)`.
- failure: §5.2 is "normative" and "compared cell by cell" (Catalogue docstring), yet three printed types no longer describe the values; the comparison cannot fail for them. Also §5.1 says `Model — no behaviour` while `Model.relocated` is a function (src/Model.jl:141) and the `Cover` enum lives in `Catalogue` (src/Catalogue.jl:170), and lists `applies` under `ConfigIO` where it lives in `Engine.Checks`.
- fix: print the fields in §5.2 and make the test parse every printed struct's field list.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — §5.2 prints the missing fields; §5.1 corrected; test/architecture.jl compares all 31 printed structs' fields.

### D-16: `package_operations` misses a generic of a Base submodule the package extends
- file: src/TestHarness.jl:55
- severity: minor
- confidence: confirmed
- evidence: `for mod in Base.loaded_modules_array()` … `for name in names(mod; all = true, imported = true)` — top-level modules only; docstring: "plus every external generic a package module extends".
- failure: a module defining `Base.Broadcast.broadcasted(::typeof(+), a::X, b::X)` → `package_operations` returns `[:op!, :show]` without `:broadcasted` (reproduced). An in-place submodule generic a package extends (`Base.Broadcast.materialize!`, which PF calls throughout `FiberSections.jl`) never enters the required set, so `allocation_completeness`/`traffic_completeness` pass without a row for it.
- fix: walk submodules recursively (`names(mod; all = true)` filtered to `Module`s) or accept an `externals` list as `method_parity` does.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `package_operations` walks submodules of loaded modules.

### D-17: `all_package_functions` leaves out the umbrella module's own internals, so an audited unexported umbrella function is reported as a phantom
- file: src/TestHarness.jl:76
- severity: minor
- confidence: confirmed
- evidence: `owned = Set(modules)` / `for mod in modules, name in names(mod; all = true, imported = true)` — `pkg` is not walked (line 43 of `package_operations` does include it); docstring: "Every function name a package module owns methods of, internal helpers included".
- failure: `all_package_functions(ProbePkg, Module[])` → `[:op!, :show]`, missing the umbrella's `helper!` (reproduced); `@alloc_below 1 helper!(x)` then fails "audited names that match no real function" in `allocation_completeness` (line 163).
- fix: iterate `vcat(modules, [pkg])` as `package_operations` does.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `all_package_functions` includes the umbrella module.

### D-18: `resolve_function` crashes when a sibling module binds the name to a non-function constant
- file: src/TestHarness.jl:371
- severity: minor
- confidence: confirmed
- evidence: `owned = [m for m in modules if isdefined(m, name) && parentmodule(getfield(m, name)) === m]`.
- failure: module A `dims(x) = x`, module B `const dims = (1, 2)`; `resolve_function(:dims, pkg, [A, B])` → `MethodError: no method matching parentmodule(::Tuple{Int64, Int64})` (reproduced), which `method_parity` records as an error rather than a count.
- fix: test `getfield(m, name) isa Function` before `parentmodule`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `resolve_function` checks `isa Function` before `parentmodule`.

### D-19: `audit` crashes on a row name whose first character is whitespace, `(` or `∘`
- file: src/TestHarness.jl:258
- severity: minor
- confidence: confirmed
- evidence: `push!(AUDITED_TRAFFIC_OPS, Symbol(match(r"^[^\s(∘]+", name).match))`.
- failure: `audit(() -> nothing, "(x)")` → `FieldError` on `nothing.match` (reproduced); a mislabelled row aborts the testset with a backtrace instead of a named failure.
- fix: check the match for `nothing` and `error("row name $name has no leading operation token")`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `audit` raises a named error for a row name with no operation token.

### D-20: `thread_digest` starts a child Julia process from inside a consumer's `Pkg.test()`, which §5.1 forbids
- file: src/TestHarness.jl:607
- severity: minor
- confidence: plausible
- evidence: `return readchomp(`$(Base.julia_cmd()) --startup-file=no --project=$project -t$threads -e $src`)`; docs/ARCHITECTURE.md §5.1: "What runs inside a consumer's build or test stays offline and starts no child process, because CI must give the same answer every time"; Harness docstring (src/Engine/Harness.jl:9): "starts no child process".
- failure: a consumer's suite calling `thread_digest` (the PF threading test it was harvested from) starts a second Julia; the design's exception table admits `git`, the docs build, tests and witnesses on the instrument side only.
- fix: either admit it in §5.1's table with its reason, or move the cross-`-t` probe to a `gbg` verb.
- verified: yes, by reading (2026-09-26) · fate: owner — should `thread_digest`, which starts a child Julia inside a consumer's `Pkg.test()`, be admitted in §5.1's exception table, or move to a `gbg` verb?

### D-21: `Witnesses.refusal` is evaded by `include_string`, `evalfile`, a multi-line `using`, and `@eval using`
- file: src/Witnesses.jl:61 (and :62)
- severity: minor
- confidence: confirmed
- evidence: `occursin(r"\binclude\s*\(", line) && return …`; `m = match(r"^\s*(?:using|import)\s+(.+)$", line)`; docstring: "a witness cannot be weakened through a helper it loads".
- failure: `include_string(Main, read("h.jl", String))`, `evalfile("h.jl")`, `using Test,\n      Helper` and `@eval using Helper` all return `nothing` from `refusal` (reproduced) and run; a witness can load a helper that redefines what it asserts on.
- fix: parse the file with JuliaSyntax and refuse any `using`/`import` node not in the allowed set and any call named `include`, `include_string`, `evalfile`, `require`, `eval`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `refusal` walks the parse tree; include/include_string/evalfile/require/eval/@eval refused however qualified.

### D-22: `Witnesses.run_one` takes its verdict from a line grepped out of the child's log, with the exit code ignored
- file: src/Witnesses.jl:167 (and :169)
- severity: minor
- confidence: confirmed
- evidence: `Cmd(cmd; dir = dirname(project), ignorestatus = true)` then `m = match(r"GBG_WITNESS pass=(\d+) fail=(\d+) error=(\d+)", text)`; CLAUDE.md: "Exit codes are the contract; a log is never grepped for a verdict."
- failure: a witness that itself prints `GBG_WITNESS pass=1 fail=0 error=0` (stdout and stderr are merged into `out`) is graded `:pass` whatever it did; the wrapper's own `exit(0|1|3)` is computed and then thrown away.
- fix: read the exit code as the verdict and the counts line as detail; refuse a mismatch.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the exit code is the verdict; a counts line with a token the witness cannot see must agree with it.

### D-23: `Witnesses` carries dead code and docstrings from the deleted v1 config and rounds
- file: src/Witnesses.jl:102 (and :13–14, :95, :167)
- severity: minor
- confidence: confirmed
- evidence: `function witness_project(root, witness_env, package)` — called by nothing in `src/` or `test/` (`grep -rn witness_project`); its docstring names "the config's `instruments.bug-hunt.witness_env`", a key of the deleted `config.toml`; the module docstring says a round is "recorded as a tracked directory under `.gbg/rounds/`" where the design has `.gbg/runs/<id>/`. `Cmd(cmd; dir = dirname(project))` treats `project` as a file, while every caller (test/witnesses.jl:6) passes a directory, so the cwd is that directory's PARENT — the package's parent when `project` is the root.
- failure: a reader takes `witness_project` and `.gbg/rounds/` as live; a witness run with `project = root` executes with the working directory outside the package.
- fix: delete `witness_project`, reword the two docstrings, and use `dir = isdir(project) ? project : dirname(project)`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `witness_project` deleted; docstrings name `.gbg/runs/<id>/`; the working directory is `project` when a directory.

### D-24: A bundle switched off drops the rules bound to it without a gap, though a rule no reader is given must be reported as one
- file: src/Roles/documentation_review.jl:167
- severity: minor
- confidence: confirmed
- evidence: `for b in BUNDLES` / `isempty(bound[b.id]) && continue` / `off(cfg, b.id) && continue` — the ids in `bound[b.id]` are then reported nowhere; docstring of `derive`: "the gaps: one line for each tagged rule that no reader is given"; §5.2: "A rule no reader can be given … is a gap, printed at every launch and first in the report; there is no fallback".
- failure: `Switch(target = :withheld, reason = …)` silently unjudges every NOTHING-tagged rule; the report says nothing, and "a pass from a reader that cannot recognise the defect is indistinguishable from not looking".
- fix: push one gap line per rule in `bound[b.id]` when the bundle is off, naming the switch.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `derive` adds a gap line per rule bound to a switched-off bundle.

READ: src/Model.jl, src/ConfigIO.jl, src/Catalogue.jl, src/Engine/Harness.jl, src/TestHarness.jl, src/Witnesses.jl, src/Roles/documentation_review.jl (all completely); docs/ARCHITECTURE.md §5.1–5.3, §9, §10, §11; test/configio.jl, test/witnesses.jl, test/architecture.jl §5.2 block; src/Engine/Checks.jl `applies`, `run_rule`, `reading`; fixture/GBG Fixture/test/runtests.jl.
SKIPPED: src/Rules/*.jl (the rule values themselves — another group's), src/Render.jl and src/Orchestration/* beyond grep for callers, src/Texts.jl beyond `expand`'s signature; the LOADED_MODULE branch of `Harness.test` was not pursued because no CODE rule has that input today (checked by listing the rules).

## Group E — Rules — rendering, latex, docstrings, arguments, reflection, modules (24 findings)

# Group E findings

### E-1: `RULE.DOC.XLINK` and `RULE.DOC.SIGNATURE_FIDELITY` read no file under a real config: they iterate `cfg.filesets[CODE]` as a file list, which is a list of GLOB PATTERNS and is empty by default
- file: src/Rules/modules.jl:58 (and :180)
- severity: blocker
- confidence: confirmed
- evidence: `for f in get(cfg.filesets, Model.FileSet.CODE, String[])` … `path = joinpath(loaded.root, f); isfile(path) || continue` (modules.jl:58-60 and :180-182); `Config.filesets` is documented as "its file sets, where the defaults miss" and `Texts.files` resolves `get(cfg.filesets, fileset, DEFAULT_PATTERNS[fileset])` through `expand` (Texts.jl:66-79). GBGPeriodicFields' `.gbg/config.jl` sets only `FileSet.LITERATE`; probe: `get(cfg.filesets, M.FileSet.CODE, String[])` on a default `Config` prints `String[]`.
- failure: any package that does not list every CODE file by name (every real one: PF sets no CODE set; a package that sets `"src/**/*.jl"` fails `isfile`) → both checks visit zero files and report clean → two rules are dead everywhere except in their own `ModuleExample`s, whose test config lists `src/Example.jl` literally.
- fix: resolve the files with `Texts.files(cfg, root, Model.FileSet.CODE)` in `xlink` and `displayed_signatures`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `xlink` and `displayed_signatures` resolve files through `Texts.files(cfg, root, CODE)`.

### E-2: `displayed_signatures` never strips a `-> Type` return annotation (regex written `\$` inside `r"…"`), so every signature with one parses as a lambda and is silently dropped
- file: src/Rules/modules.jl:194
- severity: major
- confidence: confirmed
- evidence: `ex = try Meta.parse(replace(signature, r"\s*->.*\$" => "")) catch; nothing end` — inside an `r"…"` literal `\$` is the regex escape for a literal dollar; probe: `match(r"\s*->.*\$", "f(x) -> y")` is `nothing`, `replace(...)` returns `"f(x) -> y"` unchanged. `Meta.parse("f(x) -> y")` is an `Expr(:->)`, and `harvest!` returns on anything but `:call`/`:where` (line 158-159).
- failure: a docstring `measure(u; tol = 1e-6) -> Float64` over `measure(u; atol = 1e-6)` → no displayed signature harvested → `RULE.DOC.SIGNATURE_FIDELITY` reports nothing. The rubric's own signatures carry `-> T` (this package's docstrings do throughout), so the rule is blind to the standard form. Both examples of the rule omit the arrow and pass for the wrong reason.
- fix: `r"\s*->.*$"` (as `argcov` at reflection.jl:39 spells it).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the return-annotation pattern is `r"\\s*->.*$"`; examples with `-> Float64`.

### E-3: `signature_fidelity` throws away the file it knows and reports every finding at `file = ""`, `line = 0`
- file: src/Rules/modules.jl:215, :262-271
- severity: major
- confidence: confirmed
- evidence: `shown, shown_kw, elided, _ = displayed_signatures(root, cfg)` — the fourth value is `shown_in`, "the bindings … with the file" (docstring line 150-151), discarded; every push is `Model.Location(; file = "", line = 0, text = …)`.
- failure: a real disagreement → a finding that names no file and no line; `Checks.run_rule` keeps it (`keep(l) = isempty(l.file) || …`) so a per-file `Switch` can never silence it, and nothing downstream can anchor it (`Texts.reanchor` needs a file) or send a fixer to it. The rule's own examples expect `Location(; file = "", line = 0)`, which documents the defect rather than catching it.
- fix: carry `shown_in[name]` (and the docstring's line) into the location.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — every finding carries the docstring's file, line and node; signatures keyed by (name, file).

### E-4: `RULE.TEX.LEFTRIGHT` reports the paired form its statement calls correct: `\left(` and `\right)` are hits
- file: src/Rules/latex.jl:213
- severity: major
- confidence: confirmed
- evidence: `r"\\left(?![a-zA-Z]|\\\{)|\\right(?![a-zA-Z]|\.)"` — `\left` is reported unless followed by a letter or `\{`, `\right` unless followed by a letter or `.`. Statement (line 211): "A sized delimiter names what it sizes: \left( pairs with \right), and neither stands alone." Probe: `The norm ``\left( u \right)`` here.` → 1 finding; `\left\{ u \right\}` → 1 finding (`\right\}` is not in the lookahead); on the docstring surface `\\left\\{` → 1 finding (the lookahead is written in the page's spelling). `\leftarrow` passes only because `a` is a letter.
- failure: any correctly paired `\left( … \right)`, `\left[ … \right]`, `\left\{ … \right\}` → reported as a violation of a rule whose statement names exactly that as the correct form; and pairing — what the statement and the why ("An unpaired sizing command is a LaTeX error") are about — is never checked: `\left( u` alone with no `\right` is reported for the same reason as the paired one, and `\left.` (a legitimate empty delimiter) is reported while `\right.` is not.
- fix: either the statement says the house does not use `\left`/`\right` at all (the fixture's `left_right(u)` defect suggests that is the intent) or the check counts `\left` against `\right` per span.
- verified: yes, by reading (2026-09-26) · fate: fixed bdf40de — ruled 2026-09-27: banned, except per formula the owner allows (`leftright_allowed`)

### E-5: `RULE.TEX.MATHBB` reports `\mathbb{1}`, which its statement admits
- file: src/Rules/latex.jl:197
- severity: minor
- confidence: confirmed
- evidence: `r"\\mathbb\s*\{?\s*[0-9]"`; statement: "A blackboard-bold digit is not a set; the identity is written \mathbb{1} only where it means one." Probe: `The identity ``\mathbb{1}`` here.` → 1 finding.
- failure: the one spelling the statement grants is reported; the sibling `RULE.TEX.MATHBF` grants `\mathbf{1}` unconditionally (latex.jl:293), so the two identities are treated oppositely.
- fix: exclude `\mathbb{1}` / `\mathbb 1` from the pattern, or reword the statement to forbid every digit.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a lone \\mathbb{1} is admitted, as the statement grants.

### E-6: `RULE.TEX.ONE_SPAN`'s relation regex matches the prefix of ordinary control words, so a formula opening with `\exp`, `\int`, `\infty`, `\eta`, `\ell`, `\left`, `\epsilon`, `\end` … after a code span is reported as "continuing into the name"
- file: src/Rules/rendering.jl:246-248
- severity: major
- confidence: confirmed
- evidence: `RELATION = "(?:=|\\\\equiv|\\\\neq?|\\\\g?eq?|\\\\l?eq?|\\\\to|…|\\\\in|<|>)"`, `OPEN_LEFT = Regex("^" * raw"\s*" * RELATION)` — no word boundary after the control word, and `\\g?eq?` / `\\l?eq?` both reduce to `\e`. Probe (each one finding): `` `kernel` ``\exp(-r^2)`` ``, `` `total` ``\int u\,dx`` ``, `` `x` ``\left( a \right)`` ``, `` `n` ``\infty`` ``, `` `eps` ``\eta`` ``, `` `k` ``\ell`` ``.
- failure: a code span followed by a finished formula that begins with any of `\e…`, `\in…`, `\le…`, `\ge…`, `\to…`, `\ne…`, `\sim…` — the statement's own "finished formula … is left as it is" case — is reported as a split formula with no rewrite; a physics package's docstrings are full of `\exp`, `\int`, `\eta`, `\epsilon`, `\ell`, `\infty`.
- fix: end each control word in the relation with `(?![A-Za-z])`, and spell `\le`, `\leq`, `\ge`, `\geq`, `\eq` out rather than as `\\l?eq?`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — relation control words end at a word boundary; \\le, \\leq, \\ge, \\geq, \\ne spelled out.

### E-7: `RULE.TEX.CODE_IN_MATH` reports `e^{-ikx}`, `\exp(ikx)` and `\frac{abc}{2}` as code identifiers
- file: src/Rules/rendering.jl:63, :68, :113-114
- severity: major
- confidence: confirmed
- evidence: `MATH_BRACED_INDEX = r"[_^]\{[a-z]+\}"` (letters only: `^{-ikx}` is not stripped), `BARE_WORD = r"[a-z]{3,}"` over what remains. Probe: `` ``e^{-ikx}`` `` → 1, `` ``\exp(ikx)`` `` → 1, `` ``\frac{abc}{2}`` `` → 1; `` ``\sin(kx)`` `` → 0 only because `kx` is two letters.
- failure: the plane wave `e^{-ikx}` / `\exp(ikx)` — the most common exponent in a spectral package — is reported as "a code identifier inside a math span" with no rewrite (`\texttt{ikx}` would be wrong).
- fix: strip the whole braced group after `_`/`^` whatever it holds, and treat a run adjacent to `i` and a wavenumber letter as a product; or lift the bare-word threshold to four letters where the run is inside an exponent or a function argument.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a whole braced group after _ or ^ is stripped; inside a group a word needs four letters.

### E-8: `RULE.DOC.FIELDS` reports a documented OUTER CONSTRUCTOR as "documents no fields": `struct_fields` looks up the struct by the docstring's node NAME, and a constructor's node is the type's name
- file: src/Rules/docstrings.jl:152-160, :178
- severity: major
- confidence: confirmed
- evidence: `for d in Texts.docstrings_of(src); fields = struct_fields(lines, d.node)` … `occursin(Regex("\\bstruct\\s+" * … node …), line) && (opened = true)`; probe with a documented `struct Grid` (field list correct) and a documented `Grid(n; L = 1.0) = Grid(n)` → `L12: Grid stores n and documents no fields` at the constructor's docstring.
- failure: every documented outer constructor (`Grid(n; L)`, `Field(grid, data)`, …) in the same file as its struct → a false FIELDS finding demanding a field list in a constructor docstring, where the rubric wants an argument list.
- fix: pair the docstring with its own node's kind (`bound_name` knows it is a `struct`), not with the first `struct <name>` in the file.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a docstring is paired with the definition under it in the parse tree.

### E-9: `struct_fields` is a text scan that sees only `    name::Type` lines: untyped fields, `const` fields and `@kwdef` defaults without a type are invisible, so a correct docstring is reported for a ghost and an incomplete one passes
- file: src/Rules/docstrings.jl:188, :146-148
- severity: minor
- confidence: confirmed
- evidence: `m = match(Regex("^\\s{2,}(" * Texts.NAME * ")\\s*::"), line)`; docstring line 138 and 146: `field_docs(path, cfg)` (the function takes `src`) and "It reads the parse tree rather than the text" — it does not. Probe: `struct S; a; b::Int; end` with bullets for `a` and `b` → `S documents a, which it does not have`; `mutable struct S; const a::Int; b; end` documented with `a`, `b` → 0 findings (both fields invisible, the type skipped by `isempty(fields) && continue`).
- failure: a correct docstring is reported for a ghost of a real untyped field; a struct whose every field is untyped or `const` is never checked at all, with or without a field list.
- fix: read the fields from the parse tree, as the docstring claims.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — fields are read from the parse tree; the `field_docs` docstring corrected.

### E-10: `RULE.DOC.ARGCOV` reports an argument documented with a type in its bullet (`` `tol::Float64` ``) as undocumented
- file: src/Rules/reflection.jl:49-50
- severity: major
- confidence: confirmed
- evidence: `documented = occursin(Regex("`" * q * "(?:\\.\\.\\.)?`"), d.text) || occursin(Regex("`" * q * "\\s*=[^`]*`"), d.text)` — only `` `name` ``, `` `name...` `` and `` `name = …` `` count. Probe: bullets `` - `a::Int` — …``, `` - `tol::Float64` — …`` → `` `a` … is undocumented``, `` `tol` … is undocumented``. The rubric's `RULE.DOC.ARG_BULLET` asks only for "a plain code span", and the same package's `FIELD_NAME` (docstrings.jl:135) accepts `` `name::Type` `` for a field bullet.
- failure: a package that writes the type in its argument bullets → every such argument reported undocumented.
- fix: accept `` `name::…` `` alongside `` `name = …` ``.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `name::Type` in a bullet documents the argument.

### E-11: `RULE.DOC.ARGCOV` reads only the FIRST displayed signature, so arguments that appear only in a wider second signature are never checked
- file: src/Rules/reflection.jl:39
- severity: minor
- confidence: confirmed
- evidence: `signature = replace(Texts.signature_line(d.text), …)`; `Texts.signature_line` returns "the indented call on its first non-empty line"; `RULE.DOC.ARGS_FORM` in the same batch uses `Texts.signature_lines` "the WIDEST of the displayed signatures, not the first" (arguments.jl:43-55). Probe: `f(a)` then `f(a, b, c, d)` with only `a` documented → 0 findings.
- failure: the docstring form the tool's own `Texts.signature_lines` docstring cites (`weighted_inner(f, w)` / `weighted_inner(f, g, w)`) → the third argument is never held to the statement "Every argument in a docstring's signature … is documented".
- fix: union the parameters of every displayed signature.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — ARGCOV takes the union of every displayed signature.

### E-12: `RULE.DOC.CURRENT` resolves a rule id by PREFIX, so a stale or truncated id passes whenever a live id begins with it
- file: src/Rules/reflection.jl:224
- severity: minor
- confidence: confirmed
- evidence: `mention(id) = any(k -> k != id && startswith(k, id), known)`. Probe: `RULE.DOC.ARG`, `RULE.DOC.LINK`, `RULE.DOC.FIELD` → 0 findings (each is a prefix of `RULE.DOC.ARGCOV`, `RULE.DOC.LINKS`, `RULE.DOC.FIELDS`).
- failure: exactly the renamed-rule case the statement exists for — a rule renamed by lengthening (`LINK` → `LINKS`, `FIELD` → `FIELDS`) — reads as resolving.
- fix: `startswith(k, id * ".")`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — an id resolves exactly, or as a family prefix followed by ".".

### E-13: `exported_names` runs past the `export` line into whatever follows until a blank line, so a docstring's or comment's words become "exported names"
- file: src/Rules/reflection.jl:147
- severity: minor
- confidence: confirmed
- evidence: `r"^export\s+(.+?)(?=^\s*$|^\w)"ms`. Probe: `"export foo\n\"\"\"\n    bar(x)\n\nDoes.\n…"` → `Set(["bar", "x", "foo"])`; `"export foo\n# a comment with words\n\nbar(x) = x\n"` → `Set(["with", "words", "a", "comment", "foo"])`.
- failure: `RULE.DOC.LINK_UNIFORMITY` treats `x`, `a`, `with` … as public names, so a run of argument names beside one link is reported.
- fix: stop the capture at the first line that is not a continuation (does not end in `,` or is not indented).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `exported_names` reads the export line and its comma continuations only.

### E-14: `RULE.DOC.LINK_UNIFORMITY` counts as "public" only the names exported in the SAME FILE, so the fixture's own planted defect and every cross-file run are missed
- file: src/Rules/reflection.jl:164, :171
- severity: major
- confidence: confirmed
- evidence: `public = exported_names(src)` … `bare = [… if m.captures[1] in public && …]`. The fixture plants `mixed_link_run(u)`: "Related: [`twice`](@ref) and `scale!` share the loop." (`fixture/GBG Fixture/defects/Defects.jl:115-117`) with `scale!` exported at `fixture/GBG Fixture/src/GBGFixture.jl:19`; running the rule over `defects/Defects.jl` as CODE → `RULE.DOC.LINK_UNIFORMITY (0)`. In GBGPeriodicFields `ext/GBGPeriodicFieldsHDF5Ext.jl` sees 0 exported names, so no run in the extension's docstrings can ever be reported.
- failure: a docstring in one file linking `f` and leaving `g` bare, where `g` is exported from the module file (the usual layout: exports in `src/Package.jl`, docstrings elsewhere) → nothing reported, against "In one run of names, either every name is linked or none is".
- fix: gather the exports once over every CODE file (or from the loaded module) rather than per file.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — LINK_UNIFORMITY is a FILE_TREE check gathering exports over every CODE file.

### E-15: `RULE.TEX.INLINE_ONE_LINE` carries its open-span state across paragraphs and docstrings, so one odd double-backtick anywhere in a file turns every later bullet in the file into a finding
- file: src/Rules/latex.jl:248-253
- severity: major
- confidence: confirmed
- evidence: `inspan = false` once before the loop; `isodd(count(TWO_BACKTICK, String(line))) && (inspan = !inspan)` with no reset on a blank line or a new docstring. Probe: docstring `f` holding one lone marker, then docstring `g` with a bullet → `:11 - `y` and more.` reported in `g`. Over this package's `docs/src/gbg-rules.md` (one lone marker at line 474, "unset, it is ``.") → 29 findings on the glossary bullets at lines 778-790, three hundred lines away.
- failure: the statement is "opens and closes on one line", so an open span cannot survive a blank line; the check instead makes one stray marker (a generated empty code span, a docstring quoting the marker) poison every list after it in the file, and the reported lines are not where the defect is.
- fix: reset `inspan` on a blank line (and report the line that opened the span).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — a blank line resets the open-span state; the finding names the opening line.

### E-16: `RULE.TEX.MATHBF` cannot admit a bold string with nested braces: the match stops at the first `}`
- file: src/Rules/latex.jl:299
- severity: minor
- confidence: confirmed
- evidence: `eachmatch(r"\\mathbf(\{[^}]*\})?", …)`, `m.match in allowed`. Probe with `mathbf_allowed = ["\\mathbf{\\hat{k}}"]` and text ``\mathbf{\hat{k}}`` → `\mathbf{\hat{k} in: …` reported.
- failure: a package that lists `\mathbf{\hat{k}}` (a unit vector) in its config still has every use reported; the reported text is a truncated, unbalanced `\mathbf{\hat{k}`.
- fix: match braces by depth.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — \\mathbf's argument matched by brace depth.

### E-17: `RULE.TEX.RENDERED_MATH` reports a `$` string in a code block of a docstring as dollar mathematics, because a docstring's fenced code is handed to the rule as prose
- file: src/Rules/latex.jl:75, :100 (with src/Texts.jl:462-480 `prose_text` keeping every line of a docstring, code blocks included)
- severity: minor
- confidence: confirmed
- evidence: `DOLLAR_MATH = r"\$[^$\n]*[\\_^{}][^$\n]*\$"`, applied to the unmasked `raw` line. Probe: a fenced ```` ```julia ```` block holding `name = "\$(a)_\$(b)"` → `L4: name = "\$(a)_\$(b)"` reported as "never between dollar signs".
- failure: a docstring showing a file-naming example (`"\$(prefix)_\$(i).h5"`) or any interpolation with `_`, `{`, `}` or `\` between two dollars → a rendered-math finding on code; the statement is about mathematics.
- fix: skip fenced blocks in `prose_text` (or in the check) and mask code spans before the dollar test.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — fenced blocks skipped and code spans masked before the dollar test.

### E-18: `RULE.DOC.TABLE_TOP_LEVEL` reports an indented table inside a fenced code block of a page
- file: src/Rules/rendering.jl:20, :32-35 (with src/Engine/Checks.jl:129-131 handing a PAGES file whole)
- severity: minor
- confidence: confirmed
- evidence: `INDENTED_TABLE = r"^[ \t]+\|[-:| ]+\|"` over every line; `text = fs === DOCSTRINGS ? prose_text(…) : read(joinpath(root, file), String)`. Probe: a page with ```` ```markdown ```` holding `  |---|---|` → `L5` reported.
- failure: a Markdown page that shows an example of Markdown (a tooling page, a style page) → reported for a table that is not a table.
- fix: mask fenced blocks before the pattern rules run over a page.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `indented_table` skips fenced blocks.

### E-19: `RULE.TEX.RENDERED_MATH` misses a formula in a code span whenever it has no whitespace: `` `u×v` `` and `` `∇⋅u` `` pass
- file: src/Rules/latex.jl:110
- severity: minor
- confidence: confirmed
- evidence: `length(split(strip(span))) == 1 && !occursin(r"\s", strip(span)) && continue     # `⋅` and its like` — any whitespace-free span is skipped, not only a lone operator. Probe: `The cross `u×v` here and `∇⋅u`.` → 0 findings; `The bound `x ≤ y`.` → 1.
- failure: the same formula, written tight, is not reported; the statement forbids mathematics in a code span regardless of spacing.
- fix: skip only a span that is a single glyph (`length(strip(span)) == 1`).
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — only a single-glyph code span is skipped.

### E-20: `RULE.TEX.SPACING` exempts `\,\mathrm{d}x` while its statement forbids every thin space, and reports `\, \mathrm{d}x` and `\,dx` while its docstring calls the differential idiom
- file: src/Rules/latex.jl:144, :158, :174
- severity: minor
- confidence: confirmed
- evidence: pattern `r"\\,(?!\\mathrm[ {]d)"`; docstring: "The exception is the one the rule states: a thin space before a differential is idiom, not tuning."; statement: "Spacing inside a formula is the renderer's: no thin space, …" — no exception stated. Probe: ``\int f \, \mathrm{d}x`` and ``\int f\,dx`` → both reported.
- failure: a reader of the rulebook is told `\,` is never allowed while the check allows one spelling of it; the docstring's exception is neither in the statement nor honoured for `\, \mathrm{d}x` (a space after the comma) or `\,dx`.
- fix: state the exception in the statement and make the lookahead accept `\s*\\mathrm` and a bare `d`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the differential exception accepted in all spellings; statement reworded to state it.

### E-21: `RULE.DOC.ARGS_FORM` never checks the colon its statement requires
- file: src/Rules/arguments.jl:18, :91
- severity: minor
- confidence: confirmed
- evidence: `BULLETED = r"The\s+arguments\s+are\b[^\n]*\n\s*\n?\s*[-*]\s"` (comment line 14-17: "one that demands a colon misses a consumer that writes the marker without one"); statement: "use the bulleted form, led by the marker phrase and a colon". Probe: "The arguments are" (no colon) followed by three bullets → 0 findings.
- failure: the check accepts a form the statement forbids; the rendered rulebook and the program disagree on what a docstring must write.
- fix: either drop "and a colon" from the statement or require it in `BULLETED`.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the check requires the colon; the statement kept.

### E-22: `RULE.TEX.ONE_SPAN` cannot see a formula longer than 60 characters, so a long naming after a code span is not reported
- file: src/Rules/rendering.jl:235
- severity: minor
- confidence: confirmed
- evidence: `ABUT_MATH = raw"``[^`\n]{1,60}``"`. Probe: `` `atol` ``\equiv \varepsilon_{\mathrm{abs}} + … + \delta`` `` (inner length 90) → 0 findings; the same with a short formula (the rule's first example) → 1.
- failure: exactly the "a symbol and then its definition" case the statement names — the longest formulas — is the one the check drops.
- fix: bound the span by the absence of backticks and newlines only.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — the 60-character cap on the math span removed.

### E-23: `RULE.DOC.LINKS` reports the wrong line when a docstring opens with a blank line
- file: src/Rules/reflection.jl:103 (with src/Texts.jl:432 stripping leading newlines from the body)
- severity: minor
- confidence: confirmed
- evidence: `at = d.line + 1 + count(==('\n'), d.text[1:prevind(d.text, m.offset)])   # the body opens after the delimiter`; `body = strip(replace(raw, …), '\n')`. Probe: `"""\n\n    f(x)\n\nSee [`g`](@ref) and [`g`](@ref) again.\n"""` → reported at line 4; the links are on line 5.
- failure: the finding sends the fixer one line above the repeat for each leading blank line the docstring has.
- fix: compute the offset from the raw docstring text rather than the stripped body.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — `Docstrings.body_line` gives the real opening line; used by LINKS, BLOCK_LIST, FULL_INLINE.

### E-24: `RULE.DOC.LINKS` compares link TEXT, not link TARGET, so `[`g`](@ref)` and `[`g(x)`](@ref g)` are two targets and `[`g`](@ref)` and `[`g`](@ref h)` are one
- file: src/Rules/reflection.jl:101-104
- severity: minor
- confidence: confirmed
- evidence: `for m in eachmatch(r"\[`([^`]+)`\]\(@ref[^)]*\)", d.text); t = String(m.captures[1])` — the explicit target after `@ref` is matched and discarded. Probe: "See [`g`](@ref) and [`g(x)`](@ref g) again." → 0 findings.
- failure: the statement caps "a target"; the docstring form the rubric itself recommends for a call (`[`measure(u)`](@ref measure)`, rendering.jl:228) is a second link to the same target that is never reported.
- fix: key on the explicit `@ref target` when present, else on the text stripped of its call parentheses.
- verified: yes, by reading (2026-09-26) · fate: fixed in the review commit — LINKS keys on the explicit @ref target, else the text without call parentheses.

READ: src/Rules/rendering.jl, src/Rules/latex.jl, src/Rules/docstrings.jl, src/Rules/arguments.jl, src/Rules/reflection.jl, src/Rules/modules.jl, src/Engine/Checks.jl (whole); src/Texts.jl lines 36-110, 130-210, 236-310, 395-530, 636-790 (the helpers the rules call: files/expand, unwrapped/wrapped_lines, NAME, bound_name, docstrings_of, prose_text, doc_span, mask_*/single_escapes, signature_line(s), argument_list, parameters, slots, arity); test/rules.jl 25-80 (how examples are materialised); the rendered statements in .gbg/policy/docs-rubric.md and latex-idiom.md; fixture/GBG Fixture/defects/Defects.jl (as a corpus).
SKIPPED: the rest of src/Texts.jl (HTML, reanchoring, headings), Model.jl beyond Config/Setting, the other Rules files (pages, site, shape, citations, questions, judgement_*), Render/Orchestration/CLI — other groups; the fixture's src and GBGPeriodicFields were run over as corpora (both clean under their own configs, so no false positive was measured there) but not read.

## Verification of the fixes (2026-09-27)

"Fixed in the verification commit" is the commit titled "Verifying the code review's fixes".
Four independent verifiers, read-only, re-ran each `fixed` finding's failure input against the review
commit, and confirmed each `refused`/`owner` reason. What they found is recorded here with its own fate;
everything else they confirmed.

### Groups A and C — 30 confirmed, 2 regressions, 2 owner reasons hold
- A-15 REGRESSION: `harness_called` accepted `GBGCodingTools.Harness.test` and `using GBGCodingTools: Harness`, neither of which names a binding, so a suite written that way passed the wiring check and threw. · fate: fixed in the verification commit (both refused; tested)
- C-2 REGRESSION: AT-PIN was asked before BEHIND, so a stale released pin outside the sweep window graded 0. · fate: fixed in the verification commit (BEHIND first)
- V-1: `runs_hook` matched any command ending in `queue-guard.sh`, so a package's own `my-queue-guard.sh` Stop hook would be deleted by the merge. · fate: fixed in the verification commit
- V-2: the `ci_drift` docstring named CompatHelper as a workflow with no Julia step; it runs Julia and is reported. · fate: fixed in the verification commit (docstring)
- noted: after C-9 the floor refuses whenever the newest CI run is not at HEAD, which under manual CI is nearly always · fate: owner — keep the refusal (dispatch CI before each commit) or warn when behind and refuse only when red?

### Groups G and H — 26 confirmed, 1 regression, H-11's refusal holds
- G-6 REGRESSION: the shared grammar made `?` and `[…]` wildcards in FILE-SET patterns, which escaped them deliberately on 2026-09-23 (`glob_matches("docs/[x].md", "docs/[x].md")` became false). · fate: fixed in the verification commit (`classes = false` for file-set patterns)
- V-3 (older than the review, from the rc.24 splice): `Run.next` placed the driver a second time WITHOUT its arguments after `write_arguments` spliced them, so every fresh find stage handed the session a driver whose `args` was undefined. Only the continued and verify stages were tested. · fate: fixed in the verification commit (`Agents.driver_sha`; tested on the fresh stage)
- V-4: H-6's replacement overwrites the owner's earlier RULED answer and direction with the new question, keeping it nowhere. · fate: fixed in the verification commit (the earlier answer and direction are carried into the new question's context; tested)
- V-5: POSIX classes (`[[:alpha:]]`) in a `.gitignore` are not read as git reads them. · fate: refused — no consumer uses one; noted for when one does
- V-6: H-5 prints the failed language rules to the terminal only; `report.md` does not name them. · fate: fixed in the verification commit (the report prints them under the question)

### Groups B and D — 33 confirmed, 1 regression, 2 not fixed, D-20's owner reason holds
- B-11 REGRESSION: a formula in a Markdown table cell is read as display, so respelling an inline code span as inline math inside a table cell is refused (clause 6); the old tree accepted it. · fate: fixed in the verification commit (a formula in a table cell is inline; tested)
- D-6 NOT FIXED: a positional-only constructor call is still accepted, though §5.2 admits keyword calls only. · fate: fixed in the verification commit (every constructor refuses positional arguments; no real config writes one)
- D-22 NOT FIXED: the token is visible to the witness, so a witness can forge the tokened counts line and `exit(0)` after a failing test. · fate: fixed in the verification commit (the token removed; `exit`, `ccall`, `ARGS`, `__gbg_*`, methods on another module's function and `import M: f` are refused; the verdict is the exit code)
- V-7 (D-21 residue): `const inc = include; inc(…)` and `invokelatest(include, …)` get past `refusal`. · fate: fixed in the verification commit (the loader names are refused anywhere, aliased, passed, qualified or quoted)
- V-8 (D-24's class): a declared discipline switched off drops its rules with no gap line. · fate: fixed in the verification commit (one gap line per rule of a switched-off discipline)
- V-9: a package cannot switch off its own PatternRule — `validate` refuses the switch. · fate: fixed in the verification commit (`validate` accepts a switch or deferral naming one of the package's own rules)
- V-10: `Check.run` lists the network rule under what builds and suites run. · fate: fixed in the verification commit (network rules listed on their own line)
- V-11: `append_settled` rewriting the file whole deletes the owner's comments. · fate: fixed in the verification commit (the leading comment block is kept byte for byte; the docstring says comments between rulings are not)
- V-12: `Harness.test` prints a PatternRule finding without its rule id. · fate: fixed in the verification commit (every finding printed with its rule id)
- D-7 residue: a bare `[]` setting dumps a raw MethodError. · fate: fixed in the verification commit (a bare `[]` is one ConfigError line)
- D-13 residue: one stale comment, src/Catalogue.jl:127. · fate: fixed in the verification commit (reworded)
- V-13 (the session's own): `driver_sha`'s docstring was placed between `place_driver`'s docstring and its function, so the tree did not load. Caught by the verifier before any commit. · fate: fixed in the verification commit

### Groups E and F — 37 confirmed, 6 regressions, E-4's owner reason holds
- E-3 REGRESSION: signatures keyed by (name, file) — one function whose methods are documented in two files now gives false "defined keyword appears in no displayed signature". · fate: fixed in the verification commit (keys grouped by the function they resolve to; the union checked per function; findings keep file and line)
- E-7 REGRESSION: the whole `_`/`^` group is dropped before the word test, so `e^{-maxiter}`, `u_{grid_size}` are no longer reported. · fate: fixed in the verification commit (a sub/superscript group is dropped only if it holds no name (five letters, or an underscored word))
- F-1 REGRESSION: the allowance is granted only inside `docfix`; the site build a run launches is a child process and strict, so a fix within the allowance turns the fix→verify build red and is reverted at close. · fate: fixed in the verification commit (`Site.build` starts its child with `GBG_RUN_ALLOWANCE=1`; a CI or plain build never sets it)
- F-3 REGRESSION: the new unit keys do not match GBGPeriodicFields' recorded rows (`… (2)`, `… (3)`), so PF's docs build turns red on upgrade. · fate: fixed in the verification commit (units fall back to the key the old algorithm gave; `prose_shape` over PF reports 0 again)
- F-4 REGRESSION: a plain reference with neither an italic title nor pages after the year is no longer reported as lacking a DOI. · fate: fixed in the verification commit (an author list, year and capitalised title is a reference line again)
- F-18 REGRESSION: the fix says two characters before the dot are needed; `io.write` is still reported, so the program is not the claim. · fate: fixed in the verification commit (the pattern is any `a.b` except e.g./i.e./etc./vs./cf.; `io.write` is reported, as a coordinate should be. F-18's first fate line misdescribed the fix)
- V-14: `Docstrings.body_line` misreads an `@doc raw"""` opener, reporting a line early. · fate: fixed in the verification commit (`body_line` reads past `@doc ` before the opener)
- V-15: `indented_table` and `rendered_math` fence only on ```, not `~~~`. · fate: fixed in the verification commit (`~~~` fences recognised by both rules)
- V-16: the differential lookahead also exempts `a\,d_k` and `a\,dk`. · fate: fixed in the verification commit (`a\,d_k` is reported; `a\,dk` stays exempt, indistinguishable from `\,dx`)
- V-17: a prose-shape collision between two docstrings sharing a 60-character signature prefix tells the author to add a heading, which a docstring cannot have. · fate: fixed in the verification commit (a collision between docstrings appends `(line N)` to the later key; the heading advice is for page sections only)

## Found rehearsing GBGPeriodicFields' upgrade to rc.28 (2026-09-27)

The first run of the now-live `RULE.DOC.XLINK`, `SIGNATURE_FIDELITY` and `ARGCOV` over a real package
(PF, 173 findings) showed two false-positive classes in XLINK, both fixed with tests:

- V-18: the file's module was taken from the first line matching `module <word>`, and a docstring's
  prose line "module for what the point layer provides" named PF's `FieldAlgebra` module `for`, so every
  function of it was foreign to itself (8 findings). · fate: fixed in the rc.29 commit (only a declaration
  line: the name and nothing after it but a comment)
- V-19: a Base or standard-library generic a package module extends and re-exports (`norm`, `dot`,
  `mul!`, `tr`, `det`, `cross`) was credited to that module, so every sibling's mention of `norm` was
  foreign (53 findings). · fate: fixed in the rc.29 commit (such a generic is owned by no package module)

The 112 findings left in PF were sampled and read as genuine: 90 bare first mentions of a sibling
module's own types and functions, 16 displayed signatures whose names no longer match the method, 5
arguments no bullet documents, 1 formula in a code span. They are PF's to fix or switch off, on the
owner's word.
