# Round-2 critique — the maintainer's red team

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.


Lens: long-run maintainability, mechanism count, hidden complexity, delivery/pinning failure modes.
Proposals: **P** = `round1-platform.md`, **M** = `round1-measurement.md`, **C** = `round1-consumer.md`.
Citations are `P:123` etc. (line numbers in those files), surveys as `BL:` (`survey-buildlints-hooks-policy.md`),
`facts:` (`facts-claude-code-platform.md`).

Two facts I established by running things rather than reading (both change verdicts below):

- **E1.** `Pkg.test()` DOES honour `[sources] X = {url, rev = "<tag>"}` in `test/Project.toml` (Julia
  1.12.7; a throwaway package with a tagged local git "tool"): the tool lands in
  `~/.julia/packages/<Name>/<slug>/` as a full tree with **read-only files** (`-r--r--r--`), and
  the test passed. All three proposals assumed this silently; it holds. **But** `Pkg.test()` builds
  its sandbox in a temp dir and leaves **no `test/Manifest.toml`** — so after a plain `Pkg.test()`,
  `julia --project=test -e 'Base.locate_package(Base.identify_package("X"))'` prints `nothing`
  (measured, 0.14 s). P's shim (`P:68-73`) therefore fails on any machine where only `Pkg.test()`
  has run and nobody instantiated `test/` by hand.
- **E2.** The Workflow tool's `scriptPath` is "a script file you Wrote earlier" (workflow-authoring
  reference) — a path, with no stated restriction to the project tree; scripts cannot call
  `Date.now()`. All three rely on an absolute `scriptPath` outside the repo; that is consistent with
  the reference but still unexercised — a five-minute day-1 check, not a design risk.

Host facts used: no `~/.gbg` exists; `python3` 3.12.3; `juliaup` has **only** 1.12.7; consumer
remotes are **https** (`origin https://github.com/GrigorySarnitsky/…`); CP's CI authenticates the
private dep by `git config url."https://x-access-token:…@github.com/".insteadOf "https://github.com/"`
(`CP/.github/workflows/CI.yml`); every consumer's `$CLAUDE_PROJECT_DIR` contains **two spaces**.

---

## 1. The delivery showdown — one design survives

Three designs: **P** Pkg fetches the pinned copy; a versionless shim finds it. **C** one git clone
in Dropbox + `~/.gbg/tools` symlink + `~/.claude/skills` symlinks. **M** per-machine clone outside
Dropbox + a `git worktree` per tag + shim.

**Verdict: P, with four repairs (§1.4). C fails four concrete scenarios and cannot express the
proposals' own migration plan; M is P re-implemented by hand beside the copy Pkg already makes.**

### 1.1 Scenarios (F = fails, W = works, W* = works after a repair named in §1.4)

| Scenario | P | C | M |
|---|---|---|---|
| S1 Fresh clone of CP on Enteropia, no `~/.gbg`, no Dropbox | W* (E1 caveat) | **F** | W after `install.sh` |
| S2 GitHub CI (no Dropbox, no `~/.gbg`, no shim) builds docs + runs tests | W (`pkgdir`) | **F** unless rewritten | **F** unless rewritten |
| S3 PF pinned 1.0.0 with an OPEN round; IT needs 1.1.0 (P's own plan, `P:908-909`) | W | **F (deadlock)** | W |
| S4 Owner edits the tool on Aiporetne while a session runs on Enteropia | W | **F** | W |
| S5 Mid-round `git pull`/`checkout` of the tool | W (pin is a tree) | **F** | W |
| S6 Path with spaces | W (no Dropbox path in any artefact) | W (symlink hides it) | W |
| S7 `node` absent | W | W | W |
| S8 Two copies of one tag on one machine that can disagree | none | n/a | **yes** (worktree + Pkg copy) |
| S9 Immutability of the pinned copy | read-only files (E1) | none (a live checkout) | worktree is writable; M writes into it (`M:798`) |

**S1, C fails.** Nothing in the consumer names the tool except `@~/.gbg/tools/policy/GBG-POLICY.md`
(`C:107`) and `~/.claude/skills/gbg-*` (`C:167`). On a Dropbox-less machine the import target is
absent — Claude Code drops a missing import silently (C itself records that a declined import
"disables the imports silently", `C:19-21`) — and there is no skill, no doctor, no `gbg`. The
consumer runs with **no policy and no instrument and nothing reports it**: the missing case passes.
C's mitigation (`C:352-355`: `/gbg-doctor` asks the *session* to quote a sentinel) is the graded
party self-reporting, the antipattern every survey names. P: `Pkg.instantiate()` in `docs/` fetches
the copy over the same https+credential path CP already uses; the policy is a **relative** import of
a copy in the repo (`P:409-413`), present by construction.

**S2, C and M fail as written.** Both make `make.jl` call the closure gate through the CLI —
C: `closure_gate()` "shells `gbg round gate`" (`C:256-257`, `C:709-710`), M: `lint_docs` "ends by
calling `run(gbg gate …)`" (`M:225-226`) — and on a runner `~/.gbg/tools` / `~/.gbg/instruments/`
do not exist, so every docs deploy fails the moment the gate is wired. The fix is P's `run_gate`
shape (`P:277-279`): the Julia package always executes `python3 $(pkgdir(GBGCodingTools))/gbg …`.
Once you adopt that, the CLI is **already on every machine and every runner at the pinned version,
for free** — which is the whole argument for P and against maintaining a second delivery channel.
Also: C and M write the `[sources]` URL as `git@github.com:…` (`C:105`, `M:105`); CP's CI rewrites
only `https://github.com/` (`insteadOf`), so the SSH form breaks the existing CI auth on a repo
whose own remote is https. Use https.

**S3, C deadlocks.** C has ONE checkout at ONE tag fleet-wide (`C:126-128`) and refuses `gbg bump`
while a round is open (`C:129-131`). P's migration plan releases 1.1.0 for IT's engine
contributions while PF is at 1.0.0 (`P:908-909`); under C, moving the checkout to v1.1.0 makes
PF's `PIN-01` fail, and PF cannot bump while its round is open. C's D4 says two versions are
"forbidden" and "nobody needs [them] inside a same-day sweep" (`C:139-141`) — but the sweep is
one *sitting* and a migration is weeks; the requirement R9 (no big-bang) is exactly the demand for
two versions to coexist briefly. Note also C's `MIG-1` is `git checkout v1.3.0` **in the shared
Dropbox clone** (`C:776`): every dev edit to the tool needs `master`, so the same clone must flip
tag↔master, breaking every consumer's `PIN-01`/`ENV-02` on both machines each time.

**S4/S5, C fails by Dropbox physics.** A dirty or moved checkout on one host is the other host's
checkout within seconds. C acknowledges it ("one machine's uncommitted instrument edit is visible
on the other", `C:896-897`) and mitigates with `ENV-02` — i.e. **every preflight on the other
machine aborts** until the first machine commits and tags. S5: a `git pull` mid-round changes the
protocol text and the Python gates under a round whose Workflow script was already persisted —
new gates grade old-protocol output, and `round.toml`'s stamp no longer names what ran. Under P
the pinned copy is an immutable tree; under M the worktree is a tag.

**M's real problem is not a failure but redundancy.** After S2's repair, M holds three copies of
the tool per machine (dev checkout in Dropbox, `~/.gbg/instruments/repo` + a worktree per tag, and
the Pkg copy the docs/test envs fetch anyway). Two copies of one tag can disagree (a worktree is
writable, and M *writes* `SELFTEST.<tag>.ok` into it, `M:798`), so a doctor must now prove them
byte-equal — the twin class the whole package exists to abolish. `gbg self ensure`, worktree
add/prune, fetch-on-missing-tag (`M:84-88`) reimplement what `Pkg.instantiate()` does with
tree-hash verification, read-only files, and CI parity. M's stated reason for a clone outside
Dropbox (".git state between two live machines corrupts it", `M:93-94`) is contradicted by the
fleet: all four consumers have lived that way for months (`BL:3`). The one thing M gets right that
P lacks is the **dev-mode story**, taken up in §1.4(d).

### 1.2 Mechanism count (delivery + binding + skills + policy)

| | P | C | M |
|---|---|---|---|
| Copies of the tool per machine | 1 pinned per version (Pkg) + dev | 1 (dev = pinned, shared) | 3 |
| Per-machine install steps | shim (`install.sh`) | clone in Dropbox, symlink, skill symlinks | clone, shim, worktrees, marketplace add |
| Sync steps nothing forces | 0 (Pkg fetches on demand) | 0 (Dropbox) but see S3–S5 | `gbg self ensure` (fail-closed by pin, acceptable) |
| Version surfaces | 1 (the tag) | 1 | 2 (tag + plugin version, `M:159-163`) |
| Consumer files per bump | config + 3 `Project.toml` + 4 stubs + settings + policy copies | config + 2 `Project.toml` | config + 2 `Project.toml` + policy copies |

P's larger per-bump footprint is the cost of R2 (the version is visible in the consumer's history)
and of the plugin limits (`facts:114,121`): no per-project pin, no auto-install, no Workflow
shipping. It is data, not behaviour, and is hash-guarded.

### 1.3 Two-versions and two-consumers, concretely under P

`~/.julia/packages/GBGCodingTools/<slugA>/` (v1.0.0, PF) and `<slugB>/` (v1.1.0, IT) coexist; each
consumer's three manifests resolve to its own slug; the stubs each carry their own root. Verified
mechanism (E1). `gbg fleet` reports the split; the one-version rule is a *policy* the fleet view
enforces with a window, not a mechanism that makes the second version impossible — which is the
right shape, because S3 needs the window.

### 1.4 Repairs P needs (none changes its shape)

- **(a) Julia-free shim resolution.** Because of E1, do not resolve through `--project=test`.
  The shim reads `[tool] version` from `.gbg/config.toml` and picks
  `~/.julia/packages/GBGCodingTools/*/Project.toml` whose `version` equals it; **two matches
  (a re-tagged release) or none → exit 2** with "run `julia --project=docs -e 'using Pkg;
  Pkg.instantiate()'`". The doctor's `PIN.AGREES` compares the `git-tree-sha1` recorded in the
  three manifests to each other (Pkg writes no tree-sha into the package directory, so the
  manifests are the only witnesses) and requires all three to resolve to the one directory the
  shim picked. Cost: 5 ms, no Julia in the shim, no Julia in a Stop hook.
- **(b) Bootstrap without Dropbox.** The shim is 25 lines in the tool; on a fresh machine
  `Pkg.instantiate()` in any consumer's `docs/` puts it at `<slug>/bin/gbg`; document
  `python3 ~/.julia/packages/GBGCodingTools/*/gbg install` as the one bootstrap line. `install.sh`
  from the Dropbox dev checkout stays as the owner's convenience, not the contract.
- **(c) `Pkg.gc()`.** A copy referenced only by a `Pkg.test` sandbox manifest is collectable after
  the default delay; the persistent `docs/Manifest.toml` keeps it alive. `ENV.LOADS` catches the
  loss; `Pkg.instantiate()` restores it. Say so in the doctor's fix hint.
- **(d) Dev mode.** P has no way to run an unreleased tool against a real consumer: the shim falls
  back to the dev checkout only *outside* a consumer (`P:72-73`), and `PIN.NOT_DEV` forbids a
  `dev`'d package. Adopt C's mechanism (`C:288-290`): `gbg --dev …` routes the shim to the dev
  checkout, stamps `tool_version = "dev+<sha>[-dirty]"`, and such a round is **unclosable** except
  by abandon-with-account. Without this, every tool change is tested only on the fixture until a
  release, and releases become throwaway — the freeze rule (R4) would be circumvented by
  "release 1.4.1, 1.4.2, 1.4.3 in one afternoon".

---

## 2. D1–D19

Format per item: best answer → failure scenario for the others → over/under-build.

**D1 One repo.** All three agree; P and C for the right reasons (`P:39-46`, `C:67-72`). M adds a
fifth face, `plugin/` + a marketplace (`M:65-69`), which D6 below rejects. No under-build.

**D2 Delivery.** P (§1). Over-build: M's worktrees, `gbg self ensure`, `SELFTEST.<tag>.ok`; C's
skill symlinks. Under-build in P: (a),(b),(d) of §1.4.

**D3 Binding.** P's `[sources] url+rev` rendered into the three sub-environments from one pin
(`P:107-123`) — E1 verifies the test half. Failure of C/M: SSH URL vs CI's https rewrite (§1.1
S2). Under-build in all three: **tag immutability is asserted nowhere** — `gbg release` must
refuse to re-tag, and `PIN.AGREES` must compare tree-shas, not `rev` strings (§1.4(a)). P's extra
`[compat] = "=1.4.0"` is a cheap second witness; keep it.

**D4 Pinning.** All say fleet-one-version + per-consumer pin; only P and M have a mechanism that
survives S3. M's "WARNING for 7 days after the newer tag's date, FAILURE afterwards" (`M:126-127`)
is the honest form of the window; P's "tolerated only inside one sweep" (`P:149-150`) is prose.
Adopt M's dated window into P's `gbg fleet`.

**D5 Config.** Agreement on `.gbg/config.toml`, strict, single layer. Real defect in all three:
**two validators.** P: "the platform owns the schema as a strict Julia keyword struct **and** …
no, one place: `schema/config.schema.json` … both languages validate against it with a tiny
stdlib validator" (`P:169-173`) — two implementations of a JSON-Schema subset is the twin
`lint_review_closure`/`verify-fixes.js` was (`BL:` §1). M has `src/Config.jl` "strict keyword
struct = the schema" (`M:421`) beside `python/gbg/schema.py` (`M:424`); C has `read_config()`
(`C:261`) beside `bin/gbg`'s validator (`C:149`). **Fix:** Julia never validates; it runs
`gbg config dump --json` through `run_gate` and reads the validated object. One validator, one
error text. Over-build: C's `[git] push_on_commit = true` (`C:585`) — a policy the tool cannot
enforce (it does not commit); P's `[julia] threads_ci` (`P:733`) — nothing reads it.

**D6 Skills.** P's generated per-consumer stubs (`P:192-229`). C's personal-scope symlinks
(`C:165-198`) deliver the protocol at the **checkout's** version, not the consumer's pin — the
skill body IS the protocol in C (`C:181-182`), so a consumer pinned at 1.2.0 runs the 1.3.0
protocol; that is the R4 violation P's stub avoids by pointing at `<pinned root>/PROTOCOL.md`.
C's own D2 argument against `~/.claude/CLAUDE.md` ("applies to every project on the machine … 26
unrelated folders", `C:365-366`) applies verbatim to `~/.claude/skills/gbg-*`. M's plugin route
rests on an unverified local-path marketplace (`M:170-173`, M admits), copies the skill out of
tree, adds a second version, and needs `claude plugin install` per machine (`facts:121-122,371-372`).
**Under-build in P:** the stub tells the model to *Read* `<root>/…/PROTOCOL.md` — a path outside
the project, so Claude Code prompts for `Read` permission (PF's `settings.local.json` carries
explicit cross-tree `Read` allows for exactly this reason, `BL:58`), and the slug changes every
bump so the prompt returns. **Inject the protocol text through the `!` block** (`gbg protocol
check-consistency` prints it; injected output is plain text, `facts:174`) and no external read
exists. Same for the policy: it is a copy in the repo (D12), so nothing outside the repo is ever
read by the model.

**D7 Workflow scripts.** M: engines return liveness only, the CLI computes every tally and knows
the roster from config (`M:184-186`, `M:724`). P keeps IT's census agent writing `hats.json`
(`P:840-841`) — an agent asked to count files because a script cannot see them; the CLI can, so
this is an over-build inherited rather than justified. Verify E2's `scriptPath` on day 1 (all).

**D8 CLI.** All Python stdlib. **M's exit code 3 = tool defect** (`M:208`) is required, not
optional: under 0/1/2 an uncaught Python exception exits 1, which every caller reads as "a hard
finding" — a crashed gate then reads as a *finding* rather than as "could not check". Python floor:
`tomllib` needs 3.11 (P right, `P:34`; M's 3.10 (`M:199`) is wrong; C's 3.12 (`C:225`) is
stricter than the runners need). `julia`-free shim per §1.4(a).

**D9 Julia library.** Agreement on scope; E1 closes the consumption question. Compat floor: P/M
`1.11` (`P:316`, `M:230`), C `1.12` (`C:250`). Maintainer's rule: **declare the floor you test.**
The fleet has only 1.12.7; the tool's CI is manual; so `"1.11"` is an untested claim on the day it
ships. Either `juliaup add 1.11` on one host + a 1.11 lane in the tool's own CI (cheap, minutes),
or collapse SS to 1.12 as C proposes. Owner's call (§4). Under-build in C/M: the gate must be
reached through `pkgdir` (§1.1 S2).

**D10 Rounds.** All tracked under `.gbg/rounds/`. Three real differences, M wins two:
(i) **staleness** — P (`P:852`) and C (`C:701-702`) keep mtime; M's `graded_sha256` (`M:718`) is
right because **a fresh clone sets every mtime to checkout time**, so the mtime gate passes
vacuously on exactly the machine R2 wants to re-grade on; (ii) **record format** — M's JSON
records + rendered markdown (`M:288-289`) vs P/C's markdown with one fenced JSON block: the block
is parseable by stdlib either way, but P's "coverage fails when heading count ≠ block count"
(`P:346-347`) is a second parser and a second failure mode; JSON as the record, markdown as a
render. (iii) **abandon** — M requires the abandoned IDs enumerated (`M:250-252`); adopt.
Over-build: C's `.gbg/requests/` as a tracked pile class (`C:379`) — cross-package requests are
not an instrument artefact and no requirement names them.

**D11 Schemas.** M: `schema_version` on every artefact (`M:282`) is what lets a MAJOR change keep
historical rounds readable; P/C derive it from `tool_version` (workable, implicit). C's
`x_<package>` free objects (`C:320-321`) are an extension nobody reads — over-build; P's
`finding_types` enum closed after merge (`P:385-387`) and M's `domain_type` are equivalent.

**D12 Policy prose.** P and M copy into `.gbg/policy/` with a relative import (`P:407-413`,
`M:299-301`). C's `@~/.gbg/tools/…` (`C:107`, `C:343`) fails S1 and shows a dialog per project per
machine whose decline is silent (`C:20-21`). M's rendered variation points (`M:298-299`) vs P's rule
ids + `deviations.md` (`P:405-407`): for the two slots that are genuinely *alternatives* (leading
identity physical-meaning/estimand; vector notation) a variation point renders ONE statement,
where P's approach hands a hat a rubric saying one thing and a deviations file saying another.
Hybrid: variation points for enumerated slots, ledger for everything else. Under-build in all:
nothing checks that the ≈700 lines cut from PF's `CLAUDE.md` are all present in `policy/` except a
human diff read (`P:901-902`) — write the sentence-level script (C's `LEG-03` sentinels, `C:829`,
are 12 phrases, not the corpus).

**D13 Managed files — enforceability.** Claims vs reality:
- *Hash-in-header* (P, `P:440-442`) is self-contained for `.md`/`.toml`, but **`.claude/settings.json`
  is JSON and cannot carry a `#` header**; and the `[sources]` entries live in files Pkg rewrites.
  So P needs a manifest for at least those — the "one mechanism" claim is false; say "header where
  the format allows, manifest otherwise" and enumerate.
- *Manifest* (C `managed.json`, M `MANIFEST.json`) is itself a managed file; deleting a file and
  its entry is invisible unless the denominator is the **pinned version's template list** — all
  three have `STALE`, so this holds; state it as the invariant.
- *Seeded-once + wiring grep* (`P:446-451`, `C:823-824`): a grep for `lint_docs(` is satisfied by a
  commented-out call. Make the wiring structural: the tool exports a wrapper the consumer must use
  (`GBGCodingTools.makedocs(...)`), and the doctor fails on a **bare** `makedocs(` in `make.jl` —
  hard to satisfy by accident, one grep in the negative direction. `--deep BUILD-01` additionally
  requires the tool's banner line in the build log (a tool-emitted witness, not a self-report).
- *When does any of this run?* P: `run_gate` from `DocLints.pre` and `TestHarness.gate()`
  (`P:277-279`, `P:311`) — only if `doctor --quick` is part of them, which P does not say. C: only
  in a skill preflight (`C:670-672`). M: only by hand. **Under-build in all three:** wire
  `gbg doctor --quick` (files only, milliseconds) into the docs build and `Pkg.test()`, or the
  managed classes are enforced only when someone remembers.
- Every generated command that touches `$CLAUDE_PROJECT_DIR` must quote it (two spaces in every
  consumer path); **put a fixture consumer at a path with a space in the selftest** — none does.

**D14 Doctor.** C's id table (`C:809-838`) is the most tractable. Over-build: P's `CONTRACT.SYNC`
+ `contracts/<consumer>/config.toml` in the tool repo (`P:472`, `P:654-655`) and C's
`tests/contracts/` copies at release (`C:874-876`) — a second copy of every consumer's config in
another repo, drifting between releases: the disease with a check bolted on. The fixture's config
proves the schema; a consumer's config is validated by its own doctor. Delete. Exemption expiry:
P requires `expires` (`P:483`); C uses `reviewed ≤ 365 d` WARN (`C:399`); required expiry with a
FAIL is the only form that rots visibly.

**D15 Self-testing.** Agreement on fixture + perturbation arms. Over-build: M's per-machine
`SELFTEST.<tag>.ok` in the worktree read by the doctor (`M:435`, `M:798-799`) — the bytes are a git
tree; run the selftest at `gbg release` and in the tool's CI, once. Judgment: the tool's own CI on
push (C, `C:420`) vs manual (P/M) — it is the one lane that could test 1.11 (D9).

**D16 Change discipline.** M's `--regrade` "supersedes prior passes, new pass series, closing pass
at the round's current version" (`M:371-374`) is the precise form; P/C's `--regraded` account is
prose. All lack the re-tag refusal (D3).

**D17 Migration.** Same order everywhere. M's Step 0 acceptance test — re-grade PF's and IT's last
closed rounds from banked files and require the same tallies (`M:743-746`) — is the only proof
that the merged engine measures what the copies measured; P and C lack it (under-build). C's
`MIG-n → check id` table (`C:773-785`) is the tractable checklist; keep. P's release-1.1.0-before-IT
step is correct and is what forces D2/D4's two-version window.

**D18 Cost.** Equivalent. M's non-configurable grounding anchors (`M:388-390`) is right.

**D19 Name.** A maintainer's point, not taste: the name is baked into the UUID-bearing package,
`[sources]` in twelve `Project.toml`s, `~/.julia/packages/<Name>`, every stub and policy header —
renaming later is a fleet-wide breaking change, so decide once and never revisit. `GBGCodingTools`
(P, C) keeps "instrument" free for the four things the corpus already calls instruments; M's
`GBGInstruments` names the whole after a part. Owner's call; there is no evidence either way.

---

## 3. The ten most consequential disagreements, ranked

1. **Delivery** — P (Pkg copy) vs C (Dropbox clone + symlink) vs M (worktrees). **P**, with §1.4.
2. **Skills** — per-consumer stubs (P) vs personal symlinks (C) vs plugin (M). **P**, with the
   protocol injected through the `!` block rather than read from outside the project.
3. **Policy reach** — copy + relative import (P, M) vs `@~/…` import (C). **Copy.**
4. **Verdict staleness** — `graded_sha256` (M) vs mtime (P, C). **M** — mtime is vacuous on a clone.
5. **Record format** — JSON records rendered to markdown (M) vs markdown with a fenced block (P, C).
   **M.**
6. **Roster** — CLI-known (M) vs census agent + `hats.json` (P). **M.**
7. **Exit code 3** — M only. **Adopt**; without it a crashed gate reads as a finding.
8. **Config validation** — all three double it (Julia + Python). **One validator (Python), Julia
   consumes JSON.** No proposal says this.
9. **Consumer contracts copied into the tool repo** — P, C. **Drop.**
10. **Julia floor** — 1.11 declared-untested (P, M) vs collapse to 1.12 (C). **Declare what you
    test**; the cheap route is a 1.11 lane in the tool's CI plus `juliaup add 1.11`.

Honourable mentions: M's dated fleet window (adopt); M's enumerated-ID abandon (adopt); M's
`schema_version` (adopt); C's `GBG_DEV` unclosable rounds (adopt into P); M's Step-0 re-grade
acceptance test (adopt).

---

## 4. Residual judgment calls the evidence cannot settle

1. **Julia floor 1.11 vs 1.12** — a cost question (one juliaup channel + a CI lane) against SS's
   declared floor, which nothing on the fleet can currently run.
2. **The tool's own CI on push vs manual** — minutes per push against the free-tier history.
3. **Variation points vs ledger** for the two enumerated rubric slots (D12).
4. **`GBGCodingTools` vs `GBGInstruments`** — irreversible in practice; pick once.
5. **Which historic artefacts collapse** — `main`, SS's bold bullets, IT's bare `!!! note`, CP's
   `persistent_tasks`; every proposal flags them "owner to confirm" and none can do more.
6. **Whether `.claude/settings.json` becomes a generated file** — it is tracked in PF with a hook
   and absent elsewhere; generating it is the only way to hash it, but it also makes the tool own a
   file Claude Code merges with user settings.
7. **Expiring exemptions: required expiry (P) or reviewed-date warning (C).** Required expiry is
   strictly more honest and strictly more annoying.

---

## 5. What all three missed

1. **`Pkg.test()` leaves no `test/Manifest.toml`** (E1) — P's shim as written fails after the very
   command the consumer runs most.
2. **JSON cannot carry a comment header** — P's single-mechanism managed-file claim is false for
   `.claude/settings.json`.
3. **SSH `[sources]` URLs break the fleet's https `insteadOf` CI auth** (C, M).
4. **Tag immutability** is never stated; the doctor compares `rev` strings, not trees; `gbg release`
   never refuses a re-tag.
5. **Two config validators** in every proposal.
6. **Nothing regular runs the doctor** in C and M, and P does not say `doctor` is inside `run_gate`.
7. **The model reading the protocol/policy from outside the project prompts for permission**, and
   under P the path changes every bump; injection through the `!` block removes the class.
8. **No fixture consumer at a path with a space**, though every real consumer has two.
9. **No dev-mode in P** (C has it) — without it R4's freeze is circumvented by patch-release churn.
10. **`Pkg.gc()`** can remove a pinned copy referenced only by a test sandbox; the docs manifest
    keeps it alive by accident, not by design — say so in a doctor hint.
11. **Exit code for a tool crash** (only M).
12. **The re-grade acceptance test for the merged engine** (only M) — the one measurement that
    says the shared package is the same instrument the four copies were.
