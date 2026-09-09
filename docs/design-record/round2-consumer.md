# Round-2 critique — the consumer's advocate

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.


Lens: a Claude Code session opening `GBGCloudPhysics` (CP: 104-line `CLAUDE.md`, `.claude/` holds
only `settings.local.json`, **no `test/Project.toml`** — test deps via root `[extras]`/`[targets]`,
Documenter **1.19** resolved) or `GBGStreamingStatistics` (SS: `julia = "1.11"`, a 2026-07-18 fork,
one untracked `doc-review/` pile, no `test/regressions/`) and being told "check the docs". Every
claim below was checked against the repos and the current Claude Code docs (skills, memory) on
2026-09-06; facts that none of the three proposals verified are marked **UNVERIFIED**.

Abbreviations: **P** = round1-platform, **M** = round1-measurement, **C** = round1-consumer; `CD`,
`CC`, `BH`, `BL` = the four surveys; `FACTS` = facts-claude-code-platform.md.

Facts established here that change verdicts:

- F1. **No current instrument command sets `disable-model-invocation`** (grep over PF/IT/SS
  `.claude/`: zero hits). Today "check the docs" in prose lets the model invoke `/check-docs`. P's
  stub (P:§D6) and C's skill (C:§D6) set `disable-model-invocation: true`; the skills doc says a
  skill so marked has its description **withheld from context** and **Claude is blocked from
  invoking it** ("instructs it not to reproduce the steps another way"). So under P and C, "check
  the docs" spoken in prose reaches a session that cannot see or run the instrument and has been
  told not to imitate it. M does not specify. None of the three notices this behaviour change.
- F2. A `!`-injected command that exits non-zero **aborts the whole skill** (grep-family exit 1
  excepted); injected commands never prompt and **fail the permission check outright** unless
  pre-approved via `allowed-tools`. P's and C's stubs show no `allowed-tools` line. On a machine
  where `gbg` is not allowlisted, every instrument invocation aborts with "permission check
  failed" — fail-closed by accident, and indistinguishable from a real preflight failure.
- F3. A personal-scope skill (`~/.claude/skills/`) **overrides** a project skill of the same name;
  a skill overrides a same-named `.claude/commands/*.md`. Symlinked skill directories are
  supported. C's `gbg-` prefix therefore buys nothing against shadowing that a bare name would
  not also get — it buys only the visible "leftover" (C's `LEG-01`), which the doctor detects
  anyway.
- F4. The external-import approval dialog fires **once per project, per machine**, and declining
  "stays disabled and the dialog doesn't appear again". Only C uses an external import.
- F5. `Base.locate_package` through `julia --project=test` costs **0.10 s** here (P claims 0.4);
  it needs an existing `test/Manifest.toml`, i.e. it is dead on a fresh clone until
  `Pkg.instantiate()` — which is the state in which the owner most needs `gbg doctor`.
- F6. IT's steer-sentence refusal is owner-ruled 2026-08-25 (`IT:CLAUDE.md:179-182`). IT's bare
  `!!! note` rule (`IT:CLAUDE.md:205-207`) carries **no ruling date and no "owner-ruled"** marker.
  C's "both were owner decisions" and P's `DOC.ADMONITION_TITLE (owner-ruled)` are unsupported.
- F7. IT's `\mathbf` ban is self-contradictory on disk: `IT:docs/make.jl:192` bans every
  `\mathbf`, `:199` tells the reader the indicator is `\mathbf{1}`. IT's `OPEN-ITEMS` calls it
  "never dispositioned". It is undecided, not owner-ruled.
- F8. SS's bold-bullet form is in `SS:check-docs.md:52,178-179`, not in the `CLAUDE.md` rubric
  (`SS:CLAUDE.md:355-372` says "own entry in the arguments list", form unstated). PF's ban
  (`guards.sh:98-113`) rests on a **PF-corpus** count (181 plain vs 9 bold); SS's corpus was never
  counted.
- F9. The Workflow tool documents `scriptPath` as "a script file you Wrote earlier" under the
  session directory. **All three** assume an absolute `scriptPath` outside the project (P:
  `~/.julia/packages/…`, M: `~/.gbg/instruments/<tag>/…`, C: `~/.gbg/tools/…`). **UNVERIFIED**
  in every proposal; it is the one assumption whose failure sinks all three D7 answers at once.
- F10. No plugin is installed on this host; `~/.claude/settings.json` carries no `enabledPlugins`.
  M's marketplace route is a wholly new mechanism on both machines; C's and P's are not.

---

## 1. The trace — "check the docs" in CP and SS, step by step

### 1.1 Discovery (identical failure in P and C; unspecified in M)

Session opens in CP after migration. `CLAUDE.md` loads; the managed block loads the policy
(P/M: `@.gbg/policy/00-index.md` relative, no dialog; C: `@~/.gbg/tools/policy/GBG-POLICY.md`,
dialog on first load per machine). The user types "check the docs".

- **P, C:** the skill is `disable-model-invocation: true`. Its description is not in context. If
  the imported policy text says "'check the docs' means run `/check-docs`", the model *tries* and
  is blocked with the instruction not to reproduce the steps. The only correct session behaviour
  is "please type `/check-docs`". That is a defensible consent gate — but it is a **change** from
  today's PF (F1), and neither proposal records it as one. If the policy text does *not* name the
  skill, the CP session falls back to `CP:CLAUDE.md:92-95`'s four bullets and hand-rolls a check —
  exactly the "retype the greps" failure `CD` §7.1 records.
- **C, additionally:** on Enteropia, first session in CP after migration, the dialog appears. If
  the owner declines (or the session is `claude -p`, where the dialog's behaviour is
  **UNVERIFIED**), the import is silently dead and *stays* dead (F4). The session now has no policy,
  no mention of `gbg`, no deviations block — and passes. C's answer is "`/gbg-doctor` asks the
  session to quote the sentinel" — a check that runs only if someone invokes it. This is the
  missing-case-passes antipattern in its purest form: the very mechanism (R3) C invokes elsewhere.
- **M:** skill via plugin `/gbg:check-docs`; whether it is model-invocable is unstated. If the
  plugin is not installed on this machine (F10 — the marketplace add is a per-machine step nothing
  in the consumer records), the skill does not exist and the session hand-rolls. M's doctor checks
  "worktree present" but lists **no check that the plugin is installed and at the pinned tag**.

**Verdict:** the instrument's *entry point* is the least-designed part of all three. Whatever the
skill mechanism, the consumer needs (a) one sentence in the managed `CLAUDE.md` block that binds
the prose request to the skill name and states the consent rule, and (b) a decision — recorded —
on `disable-model-invocation`. None makes (b).

### 1.2 What the skill reads and how it starts the Workflow

- **P:** `.claude/skills/check-docs/SKILL.md` (tracked, hash-stamped). `!` injections run `gbg
  root` and `gbg args check-docs $ARGUMENTS`. `gbg` is the `~/.local/bin` shim → asks Julia for the
  depot path (F5) → `python3 <depot>/gbg/__main__.py`. Failure modes: shim absent (fresh machine),
  `test/Manifest.toml` absent (fresh clone), `gbg` not allowlisted (F2). All three abort the skill
  with a `Shell command failed` line and the CLI's stderr — fail-closed, but the abort text is the
  only diagnostic, and the doctor that would explain it is unreachable by the same failure (F5).
  Then the model reads `<depot>/instruments/check-docs/PROTOCOL.md` — a file under
  `~/.julia/packages/GBGCodingTools/<slug>/`, an opaque path the owner will never open by hand.
  **Tractability:** from the repo alone the owner can read the pin (`test/Project.toml` `[sources]
  rev`) and the stub header version; they cannot read the protocol without Julia telling them
  where it is. Acceptable; the stub should print the resolved path into the round.
- **M:** skill body says "run `gbg check-consistency open`" — a *Bash step the model performs*,
  not a `!` injection. So M loses the free abort of F2 and gets the normal permission prompt. `open`
  then runs the **full docs build** inside a CLI verb (minutes), consolidates, writes `ROUND.toml`
  and **`git add`s it** (M:§4.2 step 2). A CLI that stages files into the owner's index is a
  transparency defect: `git status` shows a staged file the owner did not stage, and a later
  `git commit` of unrelated work sweeps it in. Nothing in R1–R12 asks for this.
- **C:** `~/.claude/skills/gbg-check-docs` → symlink into the Dropbox checkout. `!` block runs
  `"$HOME/.gbg/tools/bin/gbg" preflight check-docs --project "$CLAUDE_PROJECT_DIR"` — correctly
  quoted, correctly the failing-aborts shape, but no `allowed-tools` (F2). Preflight refuses on
  pin ≠ checkout tag, dirty checkout, invalid config, open round, and prints the literal Workflow
  calls. The skill body **is** the protocol (C:§D6) — so the protocol text lives in a Dropbox
  checkout at "whatever tag is checked out", and on the *other* machine mid-Dropbox-sync the
  `SKILL.md` and `bin/gbg` may be from different tags for a minute. `ENV-02` (`git describe
  --exact-match --dirty`) catches a dirty tree, not a half-synced one where every file is
  individually clean. Low probability, zero detectability.

### 1.3 What is written where, and what `git status` shows

| | P | M | C |
|---|---|---|---|
| Round dir | `.gbg/rounds/<date>-<instr>-<n>/` tracked | `.gbg/rounds/<date>-<instr>-<NN>/` tracked | `.gbg/rounds/<instr>/<date>[-n]/` tracked |
| Primary record | markdown lanes + one fenced JSON block each | **JSON** lane files; markdown is a *render* | markdown with fenced JSON per finding |
| Human-readable in `git diff`? | yes | only the render (tracked? unstated) | yes |
| Scratch | gitignored inside the round via a platform-written `.gitignore` | `manuscript/`, `seeded/`, `scratch/` gitignored inside the round | `.gbg/scratch/` gitignored at top |
| Index mutation by tool | none | `git add ROUND.toml` at open | none |
| Files outside `.gbg/` touched per round | none | none | none |
| Managed files that may show MODIFIED | `.claude/skills/*`, `.claude/settings.json`, `.gbg/policy/*`, `CLAUDE.md` block, three `Project.toml` entries | `.gbg/policy/*`, `.gbg/MANIFEST.json`, `CLAUDE.md` block, `.claude/settings.json` hook line | `CLAUDE.md` block, `.gitignore` block, `test/regressions/README.md`, `.gbg/managed.json` |

M's JSON-primary record is the right *machine* choice and the wrong *owner* choice: the
requirement is R2 "answerable from committed artefacts", and the owner answers it by reading a
diff. M's `findings.md` render either is tracked (then two copies, one derived — the drift class
`CD` §7.20 names) or is not (then the diff is JSON). M does not say which. P's and C's "prose plus
one JSON block, parsed by count-agreement" is the honest compromise.

### 1.4 What the closure gate then demands

- **P:** `make.jl` → `DocLints.post` → `gbg gate check-docs check-consistency` (via Julia's
  `run_gate`, which shells `python3`). Exit 2 if `.gbg/rounds/` absent. On CP at first migration
  this is correct: `gbg init` writes `rounds/.keep`, so absence means "never scaffolded". Good.
  Per-finding by id, three closure channels. `SUMMARY.md` never the work list. Sound.
- **M:** identical shape plus tamper detection (recomputed tally ≠ stored → exit 1) and
  `graded_sha256` on every verdict file. The strongest gate of the three, and the only one that
  makes staleness a *failing* property on a fresh clone (mtime is meaningless after checkout —
  M:§4.4 is right and P/C are wrong to keep mtime). But it demands the most from an agent: each
  verifier must copy a 64-hex hash into its output. A hash the agent mistypes → REJECTED → the
  lane reads DEAD → round cannot close. Fail-closed, and a new class of spurious failure with no
  measurement behind it.
- **C:** `closure_gate()` → `gbg round gate --all`; per-`## Finding N` HONORED with non-empty
  `class_surfaces` **array**, or title in `.gbg/adjudicated.md` (title-keyed — the exact gap
  `CC` §5.4 records for untitled headings, which C's own D10 cites and then keeps), or `CLOSED.md`.
  Mtime staleness kept (see above). `max_open_days` = 14 fails the *build* on a round the owner
  merely left open — the docs deploy of an unrelated docstring fix is blocked by an unfinished
  bug-hunt round. That coupling exists in P and M too (any open round fails the build) but C adds
  a calendar.

### 1.5 SS specifically

All three delete the July fork and re-scaffold. The traps the checklists miss:

- SS has **no `test/regressions/`** and no witness-include loop; P/M/C all seed the directory and
  the `runtests.jl` line. Fine. But `Pkg.test()` on SS carries `LoweredCodeUtils = "0.1 - 3.5"`
  in `test/Project.toml` (`BL` §7); adding the tool as a test dep pulls its own compat into that
  resolution. If the tool's `Project.toml` declares any test-side dep (JET, Aqua — P:§D9 says
  `TestHarness.test_gates` runs "Aqua + JET"), the tool now **owns SS's JET/LCU pin problem**
  fleet-wide. Nobody lists the tool's `[deps]`/`[compat]`. **Under-build** (D9).
- SS's `julia = "1.11"` CI lane: if the tool declares `julia = "1.12"` (C:§D9), SS's `test/` env
  fails to resolve on the 1.11 runner → CI red → the "collapse to 1.12" is forced by the tool,
  not chosen by the owner. C presents it as a ruling; it is a side effect.
- SS's one round (`doc-review/`, 82 findings, July, untracked): P and C "import" it; M's `round
  import` too. All three synthesize a marker `closed = "migrated…"`. On a per-finding gate this
  closes 82 findings that were never verified with one account — the wholesale escape used on day
  one. Correct, and each should say so in the account text; only M does.

### 1.6 CP specifically — the checklists are not honest about it

- CP has **no `test/Project.toml`**. P:§D3 renders `[sources]` into "each of `test/Project.toml`,
  `docs/Project.toml`"; C:MIG-6 says "`[sources]`+`[deps]` in `test/` and `docs/` Project.toml";
  M:§D3 likewise. For CP that means *creating* `test/Project.toml`, which switches CP's test
  environment from root `[extras]/[targets]` to a separate project — a change to how `Pkg.test()`
  resolves, to what Aqua's `project_extras` check sees, and to CI. None of the three names it.
  **Under-build** (D13/D17).
- CP resolves **Documenter 1.19** against 1.17 everywhere else. `lint_rendered_markup` and
  `lint_api_page_structure` parse Documenter's HTML/`@docs` output; P/M/C all put them in the
  Julia package with **no Documenter compat bound stated** and a fixture tested on one version.
  **Under-build** (D9/D15).
- CP's docs env pulls SS via `[sources] url` **floating** (no `rev`). P notices ("gains a `rev` as
  part of the same pass"); M and C do not. A floating sibling dep beside a pinned tool dep is the
  one-version rule violated in the same file that states it.
- CP's `CLAUDE.md` says "knobs" five times. P: "fixed, not exempted". C: `POL-02` fails on the
  word. M: "five check-docs findings in its first round". C's is the only one that makes it a
  *doctor* failure, i.e. a migration blocker for a word — over-strict for a check-docs finding,
  but at least visible. Fine either way; P should say which.

---

## 2. D1–D19

**D1 (unit).** All three: one repo. Agreed; forced by R4/R7 and the twin-desync record
(`BL` §1, `CD` §7.8). No dissent.

**D2 (delivery).** Three different answers; none dominates.
- P (Pkg fetches the pinned copy into the depot; Dropbox holds only the dev checkout; shim asks
  Julia). Strengths: the consumer needs no Dropbox and no home-dir state beyond a 25-line shim;
  fresh-clone story is `instantiate` + `doctor`. Weaknesses: F5 (shim dead before instantiate —
  the doctor cannot diagnose the state it exists for; P must make the shim fall back to the
  *dev checkout* inside a consumer too, and say so); the protocol/engine live at an opaque depot
  path; three sub-envs may resolve three slugs. Also: Pkg marks depot packages read-only — fine
  for P (it never writes there) but P's `gbg selftest` "writes nothing" claim should be explicit.
- M (per-machine clone outside Dropbox + a worktree per tag + `~/.gbg/fleet.toml`). Solves staged
  upgrades nobody needs (C is right: one owner, one sweep) and adds `git worktree` metadata in a
  home directory plus a marketplace registration — the most per-machine hidden state of the three.
- C (clone in Dropbox + `~/.gbg/tools` symlink). Zero sync steps; the recorded SS-July-clone
  evidence for "unforced sync steps are skipped" is real (`BL` §3). Cost: `.git` of a *shared
  read* checkout syncing between two live machines, and a fleet-wide single checkout that makes
  every not-yet-bumped consumer's skills abort during a sweep.
- **Verdict:** P's depot route is the most tractable for a *consumer* (every path derivable from a
  committed line), provided the shim is repaired for the uninstantiated case. C's is the most
  *convenient* and least tractable (which tag is the machine on? `git -C ~/.gbg/tools describe`).
  M is over-built. **Failure scenario for C:** Enteropia, `~/.gbg/tools` at v1.3.0 because
  Aiporetne's `git checkout v1.3.0` synced overnight; IT still pins v1.2.0; every IT skill aborts
  with `PIN-01` until IT is bumped — and bumping IT is refused while IT's bug-hunt round is open.
  The escape is `--regrade`, on a round nobody meant to regrade.

**D3 (binding).** All three: `[sources] url + rev` in the sub-envs plus a pin in `.gbg/`. Agreed.
P's "rendered from one pin" and M's `gbg pin set` (one commit) are the same idea; C's PIN-01/02
check three places by hand. **Missing in all three:** the CI runners authenticate private deps by
`GBG_DEPS_TOKEN` (`BL` §7); a *fourth* private repo joins that token's scope — trivial, but the
CI.yml wiring check (P's `WIRING.CI_AUTH`) is the only one that names it. Under-build in M and C.

**D4 (pinning).** P and C: fleet-wide one version, per-consumer pin as the record. M: per-consumer
with a 7-day window. C's argument is decisive: with a Dropbox-synced checkout (C) or a depot
fetch (P), the *rule* is one version; M's window exists only to justify M's worktrees. **P/C win.**

**D5 (config).** All three: one TOML in `.gbg/`, strict schema, no layering, args rendered by the
CLI. Agreed. Two defects: C declares "no env overrides" and then ships `GBG_DEV=1` (stamped, so
visible — but it *is* a layer); C also carries `rubric.in_place_steer = false` **and** a
`[[deviation]]` for the same fact (C:§3), two places that can disagree. M's schema is the most
complete for PF/SS differences (`scans.disabled` with reason, `scans.extra` with a fixture); P's
`finding_types` as the *only* extension point is cleaner but P then admits `[scans.custom]` as a
judgment call — it should just decide. **M's schema, P's "one extension point" discipline.**

**D6 (skills).** P: generated per-consumer `.claude/skills/*/SKILL.md` stubs. M: plugin skills via
a local marketplace (unverified, fallback = P). C: personal-scope symlinked skills, `gbg-` prefix.
- C's mechanism is documented as supported (F3) and leaves **zero** skill files in the consumer.
  But it puts the protocol text outside every consumer's history (R2: "which protocol ran?" is
  answerable only via the stamp + the tools tag), and the `gbg-` prefix costs every `/check-docs`
  reference in four `CLAUDE.md`s and every memory note, for a shadowing benefit F3 shows is
  illusory.
- P's stubs are ≤15 lines, hash-stamped, tracked — the owner sees the version in `git log` of the
  stub; the protocol is a pointer to the pinned copy. Names unchanged. This is the only answer in
  which *the repo alone* tells the owner which protocol a session would load.
- M's plugin route: per-machine `enabledPlugins` state (F10), a plugin cache copy the owner never
  reads, "plugin version irrelevant" — false the day a MAJOR changes the skill's step order.
- **P wins**, with two mandatory repairs: `allowed-tools: Bash(gbg *)` in the stub (F2), and an
  explicit decision on `disable-model-invocation` (F1) recorded in the policy text that binds
  "check the docs" → `/check-docs`.

**D7 (workflow scripts).** All three: one engine per instrument, args-only, catalogues as data,
invoked by absolute `scriptPath` outside the repo. Agreed — and **all three rest on F9,
unverified**. If an outside-project `scriptPath` is refused, the fallback is a generated copy per
consumer (P's class-2 managed file), which every proposal rejected as "the drift generator" without
noticing it is one `gbg sync` away. Day-1 test, before anything else is built. M's "scripts return
liveness only, the CLI tallies" is the right split (P2); P's census agent for `hats.json` keeps an
agent in the denominator loop that M correctly removes (`CC` §6.6). **M's engine contract, P's
placement.**

**D8 (CLI).** All: Python stdlib CLI, Julia only under reflection, exit 0/1/2. M adds exit 3 (tool
defect) — worth keeping; an uncaught exception must not read as "cannot check". P's
`gbg hook <name>` reaching the pinned root through the shim is neat. C's `~/.gbg/tools/bin/gbg`
absolute invocation everywhere is the least tractable spelling. **M's contract; P's dispatch.**

**D9 (Julia side).** P and M: `julia = "1.11"`; C: `"1.12"` and collapse SS. C's reason ("this
host has no 1.11") is a `juliaup add 1.11` away and is not evidence. The tool needs nothing from
1.12 (`[sources]` is 1.11). **P/M win.** All three are silent on the tool's own `[deps]`/`[compat]`
(§1.5) and on Documenter compat (§1.6). P's `run_gate` (Julia shelling `python3` from `make.jl`)
introduces `python3` as a *docs-build* dependency on CI runners — P asserts it is there; the
`.github/workflows/docs.yml` of the four never installed it. Verify.

**D10 (rounds).** All three: tracked rounds, one layout, marker + stamp, per-finding closure.
Differences: M's frozen `findings.json` + `graded_sha256` + tamper check + no mtime; P's
`SEEDED` via `ground_truth.json`; C's title-keyed adjudication (a known hole it cites). **M wins on
the gate; P wins on the artefact format.** M's `git add` at open must go. C's `max_open_days` in
the build gate is a calendar coupled to a deploy — remove, or make it a doctor WARN.

**D11 (schemas).** All three: closed union vocabularies, one JSON schema per artefact kind. M is
the most complete (13 schemas, `UNCLEAR` kept and non-passing). P's "only `finding.type`
extensible" and C's "`x_<pkg>` object" both admit consumer data without touching enums; either
works. **M.**

**D12 (policy prose).** P and M: copied into `.gbg/policy/` with a managed header, relative
import, deviations rendered. C: external import from the checkout + a managed parameters block.
- C's route triggers the dialog (F4), leaves the rubric text out of each consumer's history, and
  edits nothing on a bump that the consumer's diff shows. C's own "prose and check cannot
  disagree" claim then depends on the import having loaded — which the missing case does not
  reveal (§1.1).
- P/M copy ≈700 lines into four repos; on a bump the diff *is* the rubric change per consumer —
  R2 satisfied literally. The cost is four hash-checked copies, which `doctor` polices.
- Neither P nor M nor C considered **`.claude/rules/`** as the *copy* target: a managed
  `.claude/rules/gbg-policy.md` is auto-discovered, needs no `CLAUDE.md` edit, no import line,
  no dialog, and the docs confirm symlinks and path-scoping there. P rejected it only for
  "visibility in `CLAUDE.md` itself"; a one-line pointer in the managed block restores that.
- **P/M win; consider `.claude/rules/` as the placement.** Over-build in M: `<!-- gbg:option … -->`
  variation points inside policy prose — a template language for a rubric; P's rule-ids +
  deviations ledger achieves the same without rendering logic.

**D13 (managed files).** Same four classes in all three. C's "required line, not a managed
`make.jl`" is right (four `make.jl`s carry genuinely different `makedocs` options, `BL` §1). P's
managed **entries** inside Pkg-rewritten `Project.toml`s is the one honest treatment of that file
class. M's "MODIFIED is refused, never merged" is the right policy for class 2. **P, with M's
refusal rule.** Under-build in all three: CP's *creation* of `test/Project.toml` (§1.6).

**D14 (doctor).** C has the most concrete check table (30 ids, exemption shape, no exemption for
`PIN-*`/`CFG-01`/`ROUND-02`/`POL-01`). P's ledger unifies five escape hatches into one file with
expiry — the strongest single idea in any proposal. M's `SELFTEST.<tag>.ok` stamp in the worktree
is a hidden machine-local file. **C's table + P's ledger.** Missing everywhere: a **shim/skill
integrity check** — the installed `~/.local/bin/gbg` (P, M) or `~/.claude/skills/gbg-*` (C) is the
one file every invocation passes through and no doctor hashes it against the tool's copy.

**D15 (self-test).** All three: fixture consumer + perturbation arm per gate + scan-without-fixture
refused. M's "absence arm" (input missing → exit 2) is the missing-case rule applied to the tool
itself; P's four consumer *contracts* validated in the tool's CI is the Pact idea done properly.
**P + M's absence arm.** C's "tools repo CI runs on push" contradicts the fleet's manual-only cost
policy; P/M say manual + tags.

**D16 (change discipline).** Identical in substance (semver, measurement-affecting = MAJOR,
stamped rounds, bump refused with an open round, `--regrade`). M's supersession record on earlier
passes is the most tractable. **M.**

**D17 (migration).** Order PF → IT → SS → CP in all three; agreed. Honesty about deviations:
| Item | P | M | C | Evidence |
|---|---|---|---|---|
| IT steer sentence | ledger deviation, owner-ruled | deviation, owner-ruled | config + deviation | owner-ruled 2026-08-25 (F6) — all correct; C doubles it |
| IT bare `!!! note` | deviation "owner-ruled" | deviation | collapse, "owner to confirm" | **no ruling on disk** (F6); P's label is invented; C's hedge is the honest one |
| IT `\mathbf` | collapse to "only `\mathbf{1}`", "no divergence" | config `notation.banned` | config `mathbf_allowed = []` | undispositioned (F7); P's collapse is defensible but silently changes IT's build lint — must be logged as a decision, not "no divergence" |
| IT `\boldsymbol` | config | config | config | correct |
| IT `main` | collapse, "owner to confirm" | keep as config | collapse, rename | the survey itself lists it both as artefact (`BL`:230) and necessary (`BL`:231); a rename touches docs.yml, GitHub default, both clones, three `inspiration/` mirrors, every memory note — **owner call; M's is the safe default** |
| IT trailer version | collapse | collapse | collapse | owner-ruled 2026-09-04 in PF — correct |
| SS estimand-first | a platform *check* SS contributed | domain hat + finding type + variation point | `rubric.leading_identity` enum | C's is right: it is the same docstring slot with a second value; P's "a check that exists because SS contributed it" is a per-package check in a shared catalogue — the fork in new clothes |
| SS bold bullets | collapse, "confirm" | disabled scan with reason (kept) | collapse + `sed` | F8: PF's ban is a PF-corpus measurement; nobody counted SS. Decide **after** counting SS; M's "kept with reason" is the only one that does not rewrite SS's corpus on a guess |
| SS keyword smoothing controls | ledger deviation | not listed | deviation | all keep; M omits it from its table (M:§5 step 3) — a gap |
| SS `julia = "1.11"` | keep unless owner collapses; doctor checks channel | keep; doctor WARN | collapse | see D9; C's is unsupported |
| CP `persistent_tasks = false` | drop unless CP shows why | exemption with reason or drop | (not listed) | P/M fine |

**D18 (cost policy).** Identical: economy default, anchors in config, never-economised phases in
the engine, `strength` per run. M hard-codes the grounding lanes (`executing`, reproducers,
adjudicators) as non-configurable anchors — right, and P/C leave it to config. **M.**

**D19 (name).** See §6.

---

## 3. The ten most consequential disagreements, ranked

1. **Where the engine lives on the machine (D2/D3/D6).** P: depot via Pkg + generated stubs; M:
   `~/.gbg` worktrees + plugin; C: Dropbox clone + symlinks + personal skills. **Verdict: P**, for
   tractability — every path a session uses derives from a committed line — with the shim
   repaired for the uninstantiated clone and the stubs given `allowed-tools`. C is the fastest to
   set up and the hardest to audit from the repo; M is over-built for a one-owner fleet.
2. **Policy by copy (P/M) vs external import (C) (D12).** **P/M.** The dialog, the silent-decline,
   and the rubric being absent from the consumer's history are three independent losses.
3. **Skill discovery and `disable-model-invocation` (D6, F1).** Nobody decided it. **Verdict:**
   decide it explicitly; if the consent gate is wanted, the managed block must say "the user
   types `/check-docs`; do not imitate it", otherwise the session hand-rolls.
4. **Staleness: hash of the frozen denominator (M) vs mtime (P/C) (D10).** **M.** mtime is
   checkout time on a clone; the gate P/C keep passes vacuously exactly where R2 needs it.
5. **Record format: JSON-primary (M) vs markdown + one JSON block (P/C) (D10/D11).** **P/C**, for
   the owner reading `git diff`; M must state whether its render is tracked.
6. **Julia floor: 1.11 (P/M) vs 1.12 and collapse SS (C) (D9).** **P/M.**
7. **IT `\mathbf`: collapse (P) vs config (M/C) (D17).** **M/C** until the owner dispositions it;
   P's "no divergence" hides a build-lint change.
8. **SS bold bullets: collapse (P/C) vs keep-with-reason (M) (D17).** **M**, pending a count.
9. **Adjudication keyed by id (P/M) vs title (C) (D10).** **P/M**; C cites the hole and keeps it.
10. **CLI mutating the index (`git add` at `open`, M) (D10).** **P/C** — a tool writes files; the
    owner stages them.

---

## 4. Residual judgment calls the evidence cannot settle

1. `disable-model-invocation` on the four instrument skills (consent gate vs today's behaviour).
2. IT `main` → `master` (topology; survey contradicts itself).
3. IT bare `!!! note` (no ruling on disk).
4. IT `\mathbf` (undispositioned; either "only `\mathbf{1}`" fleet-wide or IT keeps its ban).
5. SS bold bullets (count SS's corpus first).
6. SS 1.11 floor (cost: a `juliaup add 1.11` lane on both hosts and in the tool's CI).
7. `.claude/rules/` vs `.gbg/policy/` + `CLAUDE.md` import as the policy placement.
8. Whether the tools repo's CI runs on push (C) or manual + tags (P/M) — the fleet's cost policy
   says the latter.
9. Where the round's human summary lives and whether it is tracked (M).

---

## 5. What all three missed

- **F9** — the outside-project `scriptPath` assumption, untested, load-bearing for D7 in all three.
- **F2** — `allowed-tools` for `!`-injected `gbg` calls; without it the fail-closed abort fires on
  every invocation for the wrong reason.
- **F1** — the discovery consequence of `disable-model-invocation: true`.
- **CP has no `test/Project.toml`**; every checklist assumes one exists.
- **Documenter compat** (1.17 vs CP's 1.19) for the HTML-parsing lints.
- **The tool's own `[deps]`/`[compat]`** and their effect on every consumer's test-env resolution
  (SS's `LoweredCodeUtils` pin is the live example).
- **Shim / installed-skill integrity**: the one file every invocation traverses is hashed by no
  doctor.
- **`.claude/rules/`** as the dialog-free, edit-free policy placement.
- **`python3` on the docs CI runner** as a new build dependency (P's `run_gate`).
- **The consent gate is a session rule, not a skill flag**: the owner's "unasked, run ONLY
  `Pkg.test()`" is about the *user not having asked*; a user who says "check the docs" has asked.
  Encoding consent as `disable-model-invocation` conflates the two.
- **`git diff` of a bump**: only P/M make a policy bump visible in the consumer; nobody shows what
  the *owner* sees in `git status` after `gbg sync` (P: five to nine managed files change at once —
  the stub headers, `settings.json`, seven policy files, three `Project.toml` entries, the
  `CLAUDE.md` block). That is a large, mostly-generated diff per bump; the commit message template
  for it should be part of `gbg bump`.

---

## 6. Naming — with `GBGCodingTools` in mind

Keep **`GBGCodingTools`**. The package is policy + doctor + scaffold + docs lints + test harness +
four review instruments; "instruments" names the last third and would make `using GBGInstruments`
in every `test/` and `docs/` environment misdescribe what is being loaded (a lint is not an
instrument, a `CountingArray` is not a ruler). The word *instrument* keeps its house meaning for
the four review tools, which is what M's argument is actually protecting, and it survives
unchanged as a *term* inside a package called `GBGCodingTools`. The owner's name also costs zero
edits in the four corpora. Second choice `GBGDevTools`, which additionally says "never a runtime
dep" — but the `[sources]`-in-sub-envs placement already says that in code. CLI `gbg`, directory
`.gbg/`, module `GBGCodingTools`: one stem, three spellings, all committed.
