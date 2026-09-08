I have read every file in scope (PF: the 400-line command plus six scripts and both manifests; IT: the 296-line command plus seven scripts, both manifests and `INVENTORY.md`; SS: the 200-line command; CP: `CLAUDE.md`, `docs/make.jl`, the docs tree), the lint bodies of all four `docs/make.jl`, PF's `check-consistency/verify-fixes.js` and `coverage.py` headers, PF's two banked check-docs piles, and the four `CLAUDE.md` rubric sections. Paths below are relative to each package root; `PF:`, `IT:`, `SS:`, `CP:` prefix the package.

# `/check-docs` across four packages — survey

## 1. PROTOCOL

### PF — `.claude/commands/check-docs.md` (400 lines, last commit 2026-09-04)

| Phase | Where | What |
|---|---|---|
| Cost modes | :10-23 | Economy lanes (Sonnet) by default; full strength only on explicit request; the **fix phase is never economized**; all modes end at zero open findings. |
| Surfaces | :25-47 | **Six**: `ARCHITECTURE.md`; `FORMALIZATION/TESTING/PERFORMANCE.md`; every `src/*.jl` docstring (nine modules named); `docs/src/` pages; the Literate examples (`examples/HIST_CPU.jl` + GPU sibling, "a rendered doc page"); **the BUILT HTML** (`docs/build/api/*/index.html`). |
| Checks | :49-106 | **Seven**: Correct (prose ↔ `FORMALIZATION.md` ↔ test chain), Self-contained (+ signature-driven argument coverage + terms of art / cold read), Notation (one symbol per concept, coordinate-free), Formatted bidirectional (+ the TeX idiom set), Current & complete, Cited, **Consistent across variant pairs** (relational). |
| Built-HTML questions | :111-143 | Five: nothing public under "Internal API"; nothing twice; nothing public missing (diffed against `test/public_surface.jl`); every Internal-API blurb matches its block; no markup rendered literally (**build-enforced** by `lint_rendered_markup()`, deliberately NOT duplicated into `guards.sh` — :140-143). |
| Mechanism | :145-355 | Fan-out subagents per surface (economy) + two cross-cutting lanes (family, cold-reader, with the `?name` substrate rule :155-161); the deterministic tier as **`guards.sh`** with hard (must-be-empty) and soft (triage, never fails) scans :182-235; four non-grep backstops as scripts :237-268; the surface-6 Python bucketing script inline :310-341; triage; rebuild verified **by exit code** :348-354; commit + push on `master` :355. |
| Fix verification | :357-390 (added 2026-08-27) | **Bank** each lane as `NN-<lane>.md` (`## Finding N` sections); run `check-consistency/verify-fixes.js` with this instrument's `lanes`; run `coverage.py`; **loop fix → verify over the same banked set**, never re-run the lanes; dismissals are graded verdicts. |
| Closure / stop | :377-385 + `docs/make.jl:297-419` | Converges because the denominator is fixed; **build-enforced**: `lint_review_closure()` fails `make.jl` on any banked pile with a non-HONORED/non-adjudicated finding; escape = committed `CLOSED.md` in the pile. Both PF piles carry one (`.claude/check-docs-2026-09-01/CLOSED.md`, `.claude/doc-review-checkdocs/CLOSED.md`). |
| Report | :392-400 | Full matrix incl. FORMALIZATION coverage, family lane, cold-reader lane, surface-6 audit. |

### IT — `.claude/commands/check-docs.md` (296 lines, last commit 2026-08-27)

| Phase | Where | What |
|---|---|---|
| Cost modes | :11-23 | Verbatim port of PF's paragraph ("Ported from PF 2026-08-06, with its postmortem"). |
| Surfaces | :25-42 | **Four**: `ARCHITECTURE.md` (with the §11 decision-log history exemption :27-29); `src/*.jl` docstrings (ten modules + `Phenomenology` submodules); `docs/src/` pages; the BUILT HTML ("ported from PF"). No Literate examples, no other rationale docs. |
| Checks | :44-106 | Seven, same headings as PF. **Unique to IT:** check 1's **OPERATIONAL claims** half :58-74 (defaults, "the value" where the body branches, documented errors, ordering/timing claims, no-allocation claims, claims about what the code does NOT do) — added 2026-08-22 after two live falsehoods survived every lane and a 23-hat panel. Check 4 adds "no `\mathbf` (build-enforced)" and `\mid` :89,96. |
| Built-HTML questions | :217-239 | Three (once-and-only-once; every export landed; blurb matches). |
| Mechanism | :108-286 | Fan-out is a **Workflow script** (`check-docs/lanes.js`) — six surface lanes + family + cold-reader; **"the `src/*.jl` surface agents own check 1's operational half"** :113-115. Deterministic scans are **inline bash to retype** :129-155 (no `guards.sh`), two inline backstops :159-179, four scripts :181-185 (`abutting_spans.py`, `xlink.jl`, `doi_crosscheck.py`, `signature_fidelity.jl`). Rebuild by exit code + `git checkout -- docs/Project.toml` :246-252; push on `main` :286. |
| Closure | :253-284 | "Close the banked findings … not optional"; the **two-activities** split (closure loop vs. searching again) :259-270, credited to PF; plateau stop with the measured 43→69→76→95→93→90% series; the 2026-08-17 measurement that one instrument (`xlink.jl`) undid another's fix :274-279. **But nothing in the `.md` or `lanes.js` banks the lane output** — `lanes.js` returns `{results}` to the runner (:93) and has no `Write` — so the "banked findings" the section refers to do not exist for this instrument. |
| Build gate | `docs/make.jl:254-300` | `lint_review_closure()` reads **tracked markers** `.claude/review-rounds/*.md` (round-level `closed:` line), plus the reverse direction: a banked `.claude/doc-review` pile with no marker fails :281-294. Only one marker exists and it is a `/check-consistency` round. |

### SS — `.claude/commands/check-docs.md` (200 lines, last commit 2026-07-18, no script dir)

| Phase | Where | What |
|---|---|---|
| Cost modes | — | **None.** |
| Surfaces | :10-19 | Four: `ARCHITECTURE.md`; the three rationale docs; `src/*.jl` + `ext/…HDF5Ext.jl` docstrings; `docs/src/` pages. No built HTML, no examples. |
| Checks | :21-99 | **Six**: Correct (estimator consistent for its estimand + a statistics category-error list), Self-contained (**must emit a `symbol | binding` table and an `arg | binding` table** :42-55), **Estimand first** (unique, :56-58), Formatted (the longest version — the full TeX idiom set inline :59-88), Current & complete, Cited (+ the bullet-list reference block rule). No variant-pair check, no family/cold-reader lanes. |
| Mechanism | :104-194 | Fan-out subagents (no cost mode); **every deterministic scan is prose in one 80-line bullet** :109-189, each grep quoted inline, with SS-only scans (bare un-lateralized sizer :151-158, `\quad.*\quad` :168, backticked half-open interval :114-116, bold-arg-bullet form :178-179, register scan reaching `CLAUDE.md test` :181). Rebuild "must be clean" :192-193 (no exit-code rule). |
| Fix / closure | :190-191, :196-200 | "fix EVERY genuine finding in one pass"; "Done only when every cell is covered and the build is clean". **No banking, no verifier, no closure gate.** |

### CP — nothing under `.claude/commands`

`CP:CLAUDE.md:92-95` carries a four-bullet **five-point check** (Correct / Self-contained / Formatted / Current / Cited), "fix the class", "verify by building", and the top-level-tables rule — the PF checklist headings without any procedure. `CP:docs/make.jl` (57 lines) has **no lint functions** (only `remove_jupyter_files`, `copy_rationale_pages`; strict `makedocs` default). Evidence the rules were not ported: `CP:CLAUDE.md:41,44,47,57,97` itself says "knobs" five times, the word every other package's register scan bans.

### Protocol diff (PF vs IT vs SS)

| Element | PF | IT | SS |
|---|---|---|---|
| Cost modes | yes (origin) | yes (ported) | no |
| Surfaces | 6 (+examples, +3 rationale docs, +built HTML) | 4 | 4 (no built HTML) |
| Operational-claims check | no | **yes** (:58-74) | no |
| Variant-pair (family) lane | yes | yes | no |
| Cold-reader lane | yes (substrate rule) | yes (persona in `lanes.js:72`) | no |
| Symbol/arg **tables** required in the report | no | no | **yes** (:42-55) |
| Deterministic tier | `guards.sh` + 5 scripts | inline greps + 6 scripts | inline prose only |
| Sentence-opener scan | computed script | one-line grep (the form PF retired) | absent |
| Banking to disk | mandated (:366-370) | not done (`lanes.js` returns) | none |
| Fix verifier | `verify-fixes.js` + `coverage.py` | none named for this instrument | none |
| Closure gate | verdict-level lint over piles | round-level lint over markers | none |
| Stop rule | all HONORED/adjudicated; plateau | plateau | build clean |
| Branch | `master` | `main` | unstated |

## 2. EXECUTION MODEL

**Who spawns what.**
- **PF**: the main session spawns Agent-tool subagents directly (`check-docs.md:147` "Fan out subagents across the surfaces"); no Workflow script for the lanes. Lanes must `Write` `NN-<lane>.md` into a pile (:366-370). Verification uses two Workflow-style scripts borrowed from `/check-consistency`: `verify-fixes.js` (calls `agent(...)` per lane, `model: 'sonnet'` in economy — :144-157; takes `{pile, repo, range, strength, lanes, adjudicated, findings_per_hat}` — :20-25, :50, :58, :125) and `coverage.py` (plain Python, exit 1 on any unverified/short/missing lane — :22). Deterministic scripts are run by the session via Bash.
- **IT**: the fan-out **is** a Workflow script — `check-docs/lanes.js` (`export const meta`, `phase('Lanes')`, `await parallel(lanes.map(... agent(...)))`, `agentType: 'general-purpose'`, `model: 'sonnet'` when economy — :10-14, :77-88). It writes no files and returns `{results}` (:93). Deterministic scans are inline bash in the `.md` plus six scripts run via Bash.
- **SS**: main session spawns subagents; every scan retyped from prose.
- **No script in any package spawns a `claude` CLI subprocess.** The only agent-spawning code is Workflow scripts using the harness `agent()` API (IT `lanes.js`, PF/IT `verify-fixes.js`).

**Per-script inventory.**

| Script | Lang | Reads | Writes / exit | Invocation |
|---|---|---|---|---|
| PF `guards.sh` (133 l.) | bash | `docs/` (tables), `docs src examples` (register), `src` + `DOCS_MD` array :21-23 (`docs/*.md`, `docs/src/{notation,index,tutorial,api}.md`, `docs/src/api/*.md`, `examples/HIST_CPU.jl`, `examples/gpu/*/*.jl`); calls the three `.py` backstops | stdout; exit 0 clean / 1 any `hard` hit / 2 bad root :16-19; **self-checks that every `.py` in the dir is invoked by a `hard`/`soft` line** (:118-130, `doi_crosscheck.py` exempted :127) | `.claude/commands/check-docs/guards.sh [repo-root]` |
| PF `sentence_openers.py` (142) | py3 | `surfaces()` :55-60 = `src/*.jl` + the same docs list + examples; prose-only via docstring/fence/Literate state machine :63-89 | stdout; exit **0 even with hits** (triage), **1 if it scanned nothing** :132-134 | `guards.sh:90` (`soft`) |
| PF `field_docs.py` (142) | py3 | `src/*.jl`, `ext/*.jl` :94; regex-pairs `"""…"""` with the following `struct` :39 | stdout `GHOST/UNDOC/NOLIST/STALE/DEAD LANE`; exit 1 on any finding :138 | `guards.sh:97` (`hard`) |
| PF `link_uniformity.py` (83) | py3 | `export` lists in `src/*.jl` :45-53; docstring bodies | exit 1 on a mixed run **or if no exports parsed** :58-60 | `guards.sh:112` (`hard`) |
| PF `doi_crosscheck.py` (45) | py3 | `src/*.jl`; **whole** `docs/ARCHITECTURE.md` :34 | `MISSING`/`info:` lines; exit 1 if missing :44 | standalone (`check-docs.md:240`); deliberately not via `guards.sh` |
| PF `argcov.jl` (113) | julia (no project needed) | `src/*.jl` :64 | counts to stdout; **never non-zero** (triage) | `julia --startup-file=no …/argcov.jl [root]` (`check-docs.md:243`) |
| PF `check-consistency/verify-fixes.js` | Workflow JS | banked pile, `git diff <range>` | lanes `Write` `<pile>/closure/NN-<lane>.md` :155; returns tally; mechanical demotion in post-processing :211-216 | Workflow tool with args |
| PF `check-consistency/coverage.py` | py3 | `<pile>/[0-9][0-9]-*.md` + `<pile>/closure/` :38-40 | exit 1 on short/missing/**empty pile** :40-42 | `python3 coverage.py <pile> [closure|state]` |
| IT `lanes.js` (92) | Workflow JS | args `{repo, strength}` :16-18; agents read the repo | returns `{results}`; **no file output** | Workflow tool |
| IT `argcov.jl` (62) | julia | `src/*.jl` cwd-relative :32 | count; **exit 1 on any gap** :61 | `julia --startup-file=no …/argcov.jl` (`.md:179`) |
| IT `abutting_spans.py` (44) | py3 | `SURFACES` :26-31 (`src/*.jl`, `src/phenomenology/*.jl`, `docs/src/*.md`, `docs/src/api/**`, `ARCHITECTURE.md`) | count; always exit 0 | `.md:181` |
| IT `doi_crosscheck.py` (51) | py3 | `ARCHITECTURE.md` from `## References` :21; `src/*.jl` minus `Phenomenology` :31 | exit 1 on any problem :53 | `.md:183` |
| IT `dupref.jl` (23) | julia | `src/*.jl` | count; no exit code | not listed in the `.md` at all (only in `MANIFEST.txt`) |
| IT `xlink.jl` (73) | julia, `using GBGIsotropicTurbulence` (needs `--project`) | `MODS` :3-4; `src/<Mod>.jl` | dry-run count; **`APPLY=1` rewrites `src/` in place** :60-68 | `.md:182` |
| IT `signature_fidelity.jl` (140) | julia, loads package | docstring signature blocks via `pathof` :60-62; `methods()` reflection :101-113 | triage lines; no exit code | `.md:184` |

## 3. CONFIG COUPLING

(a) = supplyable by a per-package config; (b) = logic that genuinely differs; (c) = historic artefact.

**PF `check-docs.md`**
- :29-30 module list `FiberSections, Fields, FieldAlgebra, …` — (a).
- :206-208 `DOCS_MD="docs/ARCHITECTURE.md docs/FORMALIZATION.md … examples/HIST_CPU.jl examples/gpu/*/*.jl"` — (a).
- :121-129 the unexported-Base expectation list (`size, eltype, … show`) and the decision-82 `show` note — (a).
- :338-339 `julia --project=test -e 'using GBGPeriodicFields; include("test/public_surface.jl"); … package_operations()'` — (a), but it presumes a package-specific derived-surface file exists.
- :263 "detected by PF's own 'Allocating form of' spelling" — (a) an idiom string.
- :355 "Commit + push on `master`" vs IT :286 "`main`" — (a).
- :178-180 "Set the doc list once:" followed by nothing — (c) dangling from the `guards.sh` extraction.
- :270-307 the inline pre-extraction Python/Julia kept "as the readable source of truth" — (c): the inline argcov at **:302 still contains `p = strip(split(p, ";")[end])`**, the exact bug `argcov.jl:37-43` documents as silently dropping the last positional argument. The `.md` contradicts its own script.

**PF `guards.sh`**
- :21-23 `DOCS_MD` (same list) — (a).
- :115 the wide-signature `awk` hardcodes nine `src/*.jl` filenames while every other scan uses `src` — (c).
- :113 `hard "argument bullet is not bolded" grep … src ext` — (b): SS's rubric REQUIRES the bold form (`SS:check-docs.md:52,178-179`, `SS:CLAUDE.md:363-372` region); PF forbids it.
- :48 table scan over `docs`, :49 register over `docs src examples` — (a).

**PF `sentence_openers.py`** :56-59 the docs list + `examples/…` — (a) (fourth copy of the surface list; the `.md`, `guards.sh`, this file, and `_doc_lint_sources()` in `make.jl:44-58` each carry one).
**PF `field_docs.py`** :76-89 `NO_FIELD_LIST = {"FieldSpectralMultipliers": …, "NUFFT": …, "_FiberGather": …}` with reasons — (a), and stale entries are self-detected :126-132.
**PF `doi_crosscheck.py`** :34 `docs/ARCHITECTURE.md` — (a). 
**PF `argcov.jl`** :93 `occursin("Allocating form of", body)` — (a) idiom string; :85 `_`-prefix exemption and :97 `< 3 && !has_keyword` — the rubric's own numbers, (a)/(b).
**PF `link_uniformity.py`** — no package datum (reads `export` lists); operator exclusion :19-20 is the PF/IT style rule.

**IT `check-docs.md`**
- :27-29 "§11's decision log is append-only history" — (a) (PF's lint cuts at `## 13. Decision log`, `make.jl:198`).
- :30-33 module list; :130-131 `DOCS_MD` incl. `docs/src/observables_cache.md`, `docs/src/api/phenomenology/*.md` — (a).
- :137 `grep -rnE '\\mathbf'` must be empty — **(b)**: IT bans `\mathbf` outright; PF and SS prescribe `\mathbf{1}` for the indicator (`PF:check-docs.md:165`, `SS:check-docs.md:88`).
- :139-140 unbraced-fraction regex `\\[dt]?frac\s*[^{\s\\\\]` (catches `\tfrac N2`) and the `\boldsymbol` scan — (b) broader than PF's `frac[0-9]`.
- :150 stale math-variable names `uh|phih|velocity|vorticity` with an exclusion list — (a) notation patterns, IT-only.
- :161-171 Phenomenology exemption — (a).
- :234-235 `names(GBGIsotropicTurbulence)` — (a).
- :250-251 `git checkout -- docs/Project.toml` **alone** — (a) build detail.
- :154 the one-line sentence-opener grep — (c): PF replaced it (`sentence_openers.py:8-23` explains it is structurally blind to line-initial and paragraph-initial openers).
- :159-179 inline DOI Python — (c): DOI-only logic superseded by `doi_crosscheck.py` (title + decoded DOI + retired-form refusal); :179-180 a ` ```bash` fence opens without the previous block closing — malformed markdown.

**IT `lanes.js`**
- :40 `PREAMBLE` — a one-paragraph package description — (a).
- :51 "This corpus was just through a large rename (integrator->scheme, …) so weight this check heavily" — (c): a dated snapshot baked into a persistent prompt.
- :57-73 the six lane substrates (file lists) and personas; :72 "first-year turbulence graduate student … an epoch, a slot, a deposit …" — (a).

**IT `xlink.jl`** :3-4 `MODS`, :1 package, :64 `"@ref GBGIsotropicTurbulence." * owner` — (a). **IT `signature_fidelity.jl`** :15 `PKG`, :84-85 module tuple, :102 `occursin("GBGIsotropicTurbulence", …)` — (a). **IT `abutting_spans.py`** :26-31 `SURFACES` — (a). **IT `doi_crosscheck.py`** :21 `## References`, :31 Phenomenology — (a). **IT `argcov.jl`** :50 identifier class `[A-Za-zα-ωΑ-Ω][…̂]*` admits Greek and hatted names; PF :54 is ASCII-only — (b), see §4.

**SS `check-docs.md`**
- :12-19 surfaces incl. `ext/GBGStreamingStatisticsHDF5Ext.jl` — (a).
- :56-58 **Estimand first** — (b) domain rubric.
- :74 "the `inspiration/GBGPeriodicFields.jl` `anterpolate!` convention" — (c): cites a gitignored sibling clone as the style reference.
- :80-81 "SS has no vector/tensor notation, so the sibling `\mathbf`→`\boldsymbol` and `\partial_i` house-set guards are deliberately not ported" — (b), recorded.
- :119-189 every scan carries `--exclude={architecture,formalization,testing,performance}.md` — (a) generated-copy names.
- :52,178-179 arguments as `- **`arg`**` bullets — (b), conflicts with `PF:guards.sh:113`.

## 4. DIVERGENCES (same-named files; PF vs IT)

**`check-docs.md`**
- **Banking + verification**: PF :357-390 mandates banking, `verify-fixes.js` (with the `lanes` argument that `verify-fixes.js:44-50` says exists "which is what lets /check-docs be verified at all"), `coverage.py`, and the fix-only loop. IT :253-284 describes the same closure philosophy and credits PF, but its lanes bank nothing and IT's `verify-fixes.js` has no `lanes` argument (grep empty) — so IT's check-docs findings are exactly "prose into the runner's context, where it evaporated", the failure PF :359-364 records. **PF wins**, on IT's own stated principle.
- **Deterministic tier as a program**: PF `guards.sh` vs IT inline bash. IT :125-127 quotes PF's `| head -5` incident and still asks the operator to retype the scans. `guards.sh:4-13` and `sentence_openers.py:17-20` are the postmortems; **PF wins**.
- **Operational-claims check** (IT :58-74): absent in PF. **IT wins**; it is a genuine gap in PF's check 1.
- **Sentence openers**: PF computed script vs IT one-line grep; `sentence_openers.py:8-23` — the grep "reported 0 while nine were live". **PF wins**.
- **Built-HTML questions**: PF five (incl. Q3 diff against a derived public surface, Q5 build-enforced) vs IT three. PF wins on coverage; IT's Q2 uses `names(Module)` which needs no test-side helper.
- **Surfaces**: PF covers examples and all rationale docs; IT covers only `ARCHITECTURE.md`. Not a divergence of quality — IT has no `FORMALIZATION/TESTING/PERFORMANCE.md`.

**`argcov.jl`**
- Both fixed the `;`-splitting bug the same day and cross-credit each other (PF :37-43, IT :15-21, :46-47).
- IT accepts the `` `arg = default` `` documentation form (:52-53); PF does not — PF would flag a keyword documented that way. IT better.
- IT's identifier regex (:50) admits `α`, `β`, `û`; **PF's (:54) is ASCII-only, so a Greek argument is silently dropped from the sweep**, while PF's header (:14-16) claims α/β are merely "triage". IT better here.
- PF applies the rubric's three exemptions (:73-100) and reports counts per exemption — 0 candidates over 198 exemptions, falsified with a fixture (`check-docs.md:259-265`); IT has none and **exits 1** on any hit (:61), treating it as must-be-empty. Which is right depends on the rubric: IT's corpus uses `# Arguments` sections (fewer prose-form docstrings) so the unfiltered sweep is quieter there. PF's exemption design is the transferable idea; the exit-code policy is a rubric-config choice.

**`doi_crosscheck.py`**
- PF (:22-44): any `doi.org/…` in `src/*.jl` must appear anywhere in `ARCHITECTURE.md`; reports the reverse direction as info; exit 1 on missing.
- IT (:24-48): only the `[*Title*](https://doi.org/…)` form, scoped to `## References`, DOI compared **decoded** (:35), **title compared** (:40-44), refuses the retired `[doi:…]` label (:46-48), exempts `Phenomenology`.
- IT is stricter and self-verifying on format; PF's catches a bare DOI in any form and gives the unused-reference information. Neither is a superset; a shared version needs IT's checks plus PF's regex breadth and info direction.

**`MANIFEST.txt` / `manifest.py`**
- PF `check-docs/MANIFEST.txt` lists **3 of 6** scripts (regenerated 2026-08-27; `field_docs.py`, `link_uniformity.py`, `sentence_openers.py` landed 2026-09-02/03 per `git log`). `manifest.py:7-9` claims the purpose "cannot go stale on its own" — true of the purpose column, false of the file list. IT's is current (7 of 7). PF's root-manifest extension (`manifest.py:12-17`) is the useful addition.

**`make.jl` prose ratchet** (not same-named but the same instrument): IT `lint_docstring_shape()` makes the caps bind ALWAYS (`IT:docs/make.jl:120-126` — explains the re-baseline-in-same-commit and rename-frozen holes); PF's port `lint_prose_shape()` applies the caps only to units absent from the baseline (`PF:docs/make.jl:512-515`), so PF still has both holes IT closed. PF extended the unit to pages/sections (`PF:docs/make.jl:~207-230` comment) — IT lacks that. Each has half.

**`lint_review_closure()`**: PF reads verdict files per finding, mtime-based staleness, the emptiness predicate synced with `verify-fixes.js` (`PF:make.jl:~340-395`); IT reads a tracked round marker and additionally fails on an unmarked pile (`IT:make.jl:281-294`). PF is per-finding (stronger); IT survives a fresh clone (PF tracks its piles — 51 files under `.claude/check-docs-2026-09-01` + `doc-review-checkdocs` per `git ls-files` — which is PF's answer to the same constraint). `IT:INVENTORY.md:79-84` states both constraints.

**No counterpart.** PF-only: `guards.sh`, `sentence_openers.py`, `field_docs.py`, `link_uniformity.py`; build lints `lint_swallowed_escapes`, `lint_retired_claims`, `lint_api_page_structure`, `lint_rendered_markup`, `lint_ai_banner`. IT-only: `lanes.js`, `abutting_spans.py`, `dupref.jl`, `xlink.jl`, `signature_fidelity.jl`; build lint `lint_docstring_shape`'s structural checks (`# Arguments` before caveats, `# Fields` last — `IT:make.jl:96-104`). SS/CP: no scripts.

## 5. RUBRIC SOURCE

- The rubric lives in each package's **`CLAUDE.md`**, and each command file defers to it: `PF:check-docs.md:108-109`, `IT:check-docs.md:8-9`, `SS:check-docs.md:101-102` ("`CLAUDE.md` … holds the authoritative definitions; this command runs all of them").
- **PF**: `CLAUDE.md` "Documentation policy — the docstring rubric" + "Style" (the whole file is 2685 lines; the rubric sections embed session postmortems).
- **IT**: `CLAUDE.md:135-320` "Documentation policy — physical-meaning first" + `:322-362` "Doc-edit checklist". A hand-adapted copy of PF's with **owner-ruled deviations recorded inline**: no verbatim in-place-steer sentence (`:~190` "deliberately not adopted (owner-ruled 2026-08-25)"), list-first module maps ("deliberately tighter than PF's map rule"), the title-as-link citation form adopted from PF, `\boldsymbol`/`\mid`, type docstring = constructor-first.
- **SS**: `CLAUDE.md:225-383` "Documentation policy — estimand first" — again PF's structure adapted (`:227` "the exact mirror of PF's physical-meaning-first rule"), with estimator-variant-block rules, bold-arg bullets, and the deliberate absence of `\mathbf`/`\partial_i` guards.
- **CP**: `CLAUDE.md:80-95` — five headings and four rules; `:80` says "`docs/ARCHITECTURE.md` §3 is the authoritative source".
- **Duplication measured** (phrase grep over the four `CLAUDE.md`): "Function docstring = home" PF=1 IT=1 SS=0 CP=0; "The arguments are:" PF/IT only; "Neutral reference register" PF/IT/SS; "Doc-edit checklist" PF/IT/SS; "sample of a class" all four; "four shape rules", "Cost register", "Positional vs keyword", "Silent-rendering-failure" PF only; "Estimand first" SS only. So the rubric is **triplicated by hand-adaptation** (PF → IT → SS, CP a stub), and inside IT it is **quadruplicated**: `CLAUDE.md`, `check-docs.md:44-106`, `lanes.js:46-53` (`PREAMBLE` restates the six checks in plain text), and `lint_docstring_shape` encodes the structural half. PF triplicates too: `CLAUDE.md`, `check-docs.md:49-106`, and `guards.sh`/`argcov.jl` comments carrying the rubric's numbers (`argcov.jl:73-79`).

## 6. Build-lint overlap

| Package | `docs/make.jl` lint functions | `makedocs` options |
|---|---|---|
| PF | `lint_ai_banner`, `lint_inline_math`, `lint_notation_variants` (bare `\partial_[ijk]`, unbraced `\frac[0-9]`), `lint_swallowed_escapes`, `lint_retired_claims`, `lint_api_page_structure`, `lint_prose_shape`, `lint_review_closure`, `lint_rendered_markup` (post-`makedocs`) | `checkdocs = :exports`, `doctest = true` |
| IT | `lint_inline_math`, `lint_notation_variants` (bare partial, `\mathbf`, unbraced frac incl. `\tfrac N2`, unbraced `\boldsymbol`, `\mathbb` digit), `lint_docstring_shape`, `lint_review_closure` | `checkdocs = :exports`, `doctest = false` |
| SS | `lint_inline_math` only | `checkdocs = :exports`, `doctest = true` |
| CP | none | Documenter strict default |

Overlap classification (PF/IT battery scan ↔ lint):
- **Both battery and lint**: inline math on one line (all three lints; PF/IT `.md` mark it "build-enforced"); bare-index partial (`PF:guards.sh:50` hard ↔ `lint_notation_variants`; IT `.md:136` ↔ lint); unbraced fraction (`guards.sh:53-54` ↔ lint; IT `.md:139` ↔ lint); IT: `\mathbf` (`.md:137` ↔ lint), `\boldsymbol` (`.md:140` ↔ lint), `\mathbb` digit (`.md:142` ↔ lint). PF's `\mathbb`-digit is battery-only (`guards.sh:59-60`); SS's is battery-only.
- **Battery only** (no lint anywhere): indented tables, neutral register, gratuitous `\,`, `\!` before `\bigl`, `\!\!`, `@ref`-abutting-code (PF), `\left/\right`, manual `\;`, sentence openers, field-list fidelity, link uniformity, bold arg bullets, wide signatures, dead `§`-refs, crammed citations, DOI cross-check, argument coverage, code-in-math, split formula, stray `$`, built-HTML placement Q1-4, IT's abutting spans / cross-module links / duplicate refs / signature fidelity / stale variable names.
- **Lint only** (no battery scan): swallowed escapes, retired claims, API page structure, prose/docstring shape ratchet, review closure, AI banner, rendered markup (PF `.md:140-143` explicitly refuses to duplicate it into `guards.sh`).

## 7. Design constraints / lessons a shared package must honour

1. **Never truncate output; a count is not a verdict** — `PF:guards.sh:11-13`, `check-docs.md:188-194`; IT `.md:125-127` quotes it.
2. **Hard vs triage tiers; triage never fails the run** — `guards.sh:26-44`; `sentence_openers.py:33-35`; `signature_fidelity.jl:10-12`.
3. **The missing case is the failing case** (dead-lane detection everywhere): `sentence_openers.py:132-134`, `field_docs.py:122-124`, `link_uniformity.py:58-60`, `coverage.py:40-42`, `guards.sh:118-130` (a scan that vanishes must be detected apart from its result), `PF:make.jl` dead-lane clause in `lint_review_closure`.
4. **Falsify every zero with a fixture that reaches the broken branch** — `PF:argcov.jl:18-32`, `IT:argcov.jl:15-30`, `IT:make.jl:269-282` (six arms), `field_docs.py:20-22`.
5. **A check narrower than its spec is worse than absent** — `guards.sh:77-89`; `.claude/check-docs-2026-09-01/CLOSED.md` "Instrument findings" item 1.
6. **Bank findings to disk; verify from the banked set; loop the fix, never the battery; stop on a plateau** — `PF:check-docs.md:357-390`, `IT:check-docs.md:259-270`; `verify-fixes.js:20-25` (a range is REQUIRED).
7. **Workflow scripts cannot write files** — `coverage.py:3-6`, `IT:make.jl:285-291`; so banking and the closure record must live outside the Workflow (PF: the lanes' `Write`; IT: a tracked marker).
8. **One predicate, one place; twins drift** — `PF:make.jl` "deliberately a TWIN … edit the two together" + `doc-review-checkdocs/CLOSED.md` (the twin went stale for a day); `check-docs.md:140-143`.
9. **Self-reported fields only where the missing case fails; staleness from the filesystem** — `PF:make.jl` mtime comment; `IT:INVENTORY.md:56`.
10. **Instruments are frozen; a change is its own commit, never folded into the round it scores** — `IT:INVENTORY.md:92-107`; `check-docs-2026-09-01/CLOSED.md` "reported, NOT silently patched".
11. **A closure gate must not pass vacuously on a fresh clone** — `IT:INVENTORY.md:81-84`, `IT:make.jl:281-294`; PF answers it by tracking piles (51 files).
12. **Exemptions are enumerated with reasons and checked for staleness** — `field_docs.py:73-89,126-132`; `argcov.jl:73-100` counts each exemption class.
13. **Verify a build by exit code, never by grepping the log** — `PF:.md:348-354`, `IT:.md:246-250`.
14. **One instrument can undo another's edits; re-measure after every later sweep; mutating tools default to dry-run** — `IT:.md:274-279`, `xlink.jl:36-40`, `:71` (`APPLY=1`).
15. **Comment-line filters are part of the check** — `guards.sh:67-70`; `abutting_spans.py:38`.
16. **The cold-reader substrate must be the real `?name` view (module docstring + every method)** — `PF:.md:155-161`, `IT:lanes.js:72-74`.
17. **Idiom strings as detection keys are config** — `argcov.jl:89-93` ("Allocating form of"), `field_docs.py:44` ("The fields are").
18. **Rubric divergences are owner-ruled and must stay configurable, not silently unified**: `\mathbf` banned (IT lint) vs `\mathbf{1}` prescribed (`PF:.md:165`, `SS:.md:88`); bold arg bullets required (`SS:.md:52,178`) vs forbidden (`PF:guards.sh:113`); the in-place steer sentence "deliberately not adopted" (`IT:CLAUDE.md`); Estimand-first (`SS:.md:56-58`); `argcov` exit policy (PF triage vs IT gate).
19. **A derived manifest still needs regeneration** — `PF:check-docs/MANIFEST.txt` lists 3 of 6 scripts against `manifest.py:7-9`'s claim.
20. **Inline "readable source of truth" copies rot** — `PF:.md:302` retains the bug `argcov.jl` fixed; `IT:.md:159-172` retains the DOI-only check `doi_crosscheck.py` superseded. Whatever the shared package does with the `.md`, it must not keep a second executable copy of a script inside it.