I have read every file in the survey. Here is the report.

---

# `/check-consistency` across PF, IT and SS — a survey for the shared-instrument design

All paths are relative to `/home/grigory/Dropbox/Research and Teach/`. `PF` = `Isotropic Turbulence/GBGPeriodicFields`, `IT` = `Isotropic Turbulence/GBGIsotropicTurbulence`, `SS` = `Statistics/GBGStreamingStatistics`. `CC/` abbreviates `.claude/commands/check-consistency/`.

## 0. Inventory (what exists where)

| File | PF | IT | SS |
|---|---|---|---|
| `check-consistency.md` | 307 lines | 440 | 124 |
| `panel.js` | 180 (12 hats) | 339 (27 hats, 10 core) | 113 (11 hats) |
| `verify.js` (state auditor) | 186 | 269 | — |
| `verify-fixes.js` (act auditor) | 238 | 224 | — |
| `consolidate.py` | 114 | 109 | 113 |
| `coverage.py` | 81 | 73 | — |
| `recall.py` / `seed_defects.py` | 88 / 98 | 110 / 88 | — |
| `recall_selftest.py` | 115 | — | — |
| `rubric_audit.js`, `rubric_extract.py`, `rubric_prep.py`, `severity_recheck.js` | — | 166 / 83 / 46 / 58 | — |
| `MANIFEST.txt` | yes | yes | — |
| `.claude/doc-review-adjudicated.md` | 164 lines, per-finding | 131 lines, bullet list | — |
| closure gate in `docs/make.jl` | `lint_review_closure` L297–419 | `lint_review_closure` L254–302 (**exists**, contrary to the task's framing) | — |
| `commands/INVENTORY.md` | — | 121 lines (the 2026-08-27 harmonization fact base) | — |

SS is a frozen 2026-07-17 snapshot of PF's pre-August design: sequential loop, no adjudicated list, no cost modes, no verifiers, no calibration, no closure gate. Every SS file is dated Jul 15–18; PF and IT last moved on 2026-08-27 / 2026-09-01.

---

## 1. PROTOCOL per package

### 1.1 PF (`PF/.claude/commands/check-consistency.md`)

Phases, in order:
1. Build docs, require `make.jl` exit 0 (L89–97).
2. `consolidate.py docs/build → manuscript-full.md, manuscript-siteonly.md` (L98–103).
3. Archive prior pile: `mv .claude/doc-review .claude/doc-review-prev` (L104–110).
4. (Optional, described in a separate section) `seed_defects.py` on both manuscripts before the round; `recall.py` after (L136–182).
5. Panel: `Workflow({scriptPath: panel.js, args:{full, siteonly, rawhtml, pile, adjudicated, strength}})` (L111–130). Hats run in parallel since 2026-08-27 (L16–21).
6. Consolidate into `00-SUMMARY.md` + an Artifact dashboard; subtract seeded hits first (L131–134, L160–164).
7. Fix pass (only on the user's word) driven from the banked `NN-*.md`, never the summary (L203–216).
8. Verification pair: `verify-fixes.js` (sees diff) and `verify.js` (blind), then `coverage.py <pile> [closure|state]` as a mandatory external gate (L217–277).
9. Loop to a plateau — "three rounds flat within noise, with no dead lanes, is closure" (L275–277); the loop runs over the banked findings, never by re-running lanes (CLAUDE.md; `doc-review/CLOSED.md` L62–65).
10. Build-enforced closure: `lint_review_closure()` fails `docs/make.jl` while any `.claude/doc-review*` pile has a finding neither HONORED in `closure/` nor named in the adjudicated file; escape is a committed `CLOSED.md` in the pile dir (`docs/make.jl` L277–296, L314–318).

Cost modes (L66–82): economy is default; ten hats on `sonnet`, two anchors (`spectral-methods-mathematician`, `differential-geometer`) at the session model; `strength:"full"` on explicit request. Verification/consolidation/fix never economized.

Adjudicated mechanism: `.claude/doc-review-adjudicated.md` injected into every hat's preamble (`panel.js` L30–35, L70) and both verifiers (`verify.js` L51–61; `verify-fixes.js` L54–64). Entries are per-finding and end with `Settles, verbatim: <title>` (`adjudicated.md` L28, L52, L73–74, L124–134) so the lint can match the first 40 characters of a banked finding's title (`make.jl` L392–395). Header rule: "Nothing merely FIXED belongs here" (L7–8).

Seeded-defect calibration (L136–182): 8-class catalog in `seed_defects.py` L39–56; deterministic nth-occurrence; `recall.py` per-class/per-hat; `recall_selftest.py` with arms A–D plus the skipped-class path (L20–28, L81–106). A skipped class is UNDEFINED, never zero (`recall.py` L32–36, L79–80).

Verdict of the last round (`doc-review/CLOSED.md`): 67 findings, 11 seeded, 56 real; 39/67 → 59/67 → 59/67 HONORED then a fourth pass; 3 of 8 seeds undetected (L53–58).

### 1.2 IT (`IT/.claude/commands/check-consistency.md`)

Same skeleton with these differences:
- Panel has a **profile**: `core` (10 hats, measured on 2026-08-22: full panel 5.94 M tokens/184 findings vs 1.64 M/58, the 17 extra hats buying 14 unique blocker-or-major findings, L110–124), `full`, or explicit `hats:[...]` subset. Admission to core needs unique significant findings across more than one run (L121–124); dormancy by passive accumulation (L126–132).
- Panel writes `<pile>/hats.json` (roster) and `verify.js` reads it; a missing manifest is fatal (L86–91; `panel.js` L288–296; `verify.js` L57–76).
- Step 4b seeding is mandated "every round" (L258–274).
- Consolidation rules: corroboration has a denominator (k of n hats whose substrate could see it, L279–282); a capped hat is reported as truncated (L282–284); **no unenumerated bucket** — a per-hat closure table (L286–291).
- Step 6: `verify.js` (blind, verdicts PRESENT/PARTIAL/REGRESSED/ABSENT/NOT-A-DEFECT, default PRESENT, L322–336) → `coverage.py` → loop to convergence over the banked findings (L338–361), with the "rate only means anything at a fixed instrument" caveat (L349–358).
- Step 7: `verify-fixes.js` is for **human read-through piles** (owner's verbatim words as spec), batched by finding-number ranges, `batches` required (L372–388).
- Cost modes (L190–210): economy default; **four** anchors — `turbulence-theoretician`, `dimensional`, `plain-sense`, `logician`; free readers deliberately on economy (`panel.js` L99–101).
- Closure gate: `docs/make.jl` L254–302 reads **tracked markers** in `.claude/review-rounds/<date>-<instrument>.md`; a round is closed by a non-empty `closed:` line (L261); an unmarked non-empty `.claude/doc-review` pile fails the build locally (L277–294). No per-finding strength (L244–251, "NOT BUILT"). Escape = `closed:` line with an account, even "abandoned" (`review-rounds/README.md` L21–34).
- Adjudicated: same file, injected into hats (`panel.js` L86) and both verifiers, defaulting to the conventional path if not passed (`verify.js` L39; `verify-fixes.js` L41). Entries are short bullets, not title-matched by any script (`adjudicated.md` L3–6).
- Extra instruments: `rubric_audit.js` (blind test of whether a hat's verbatim persona finds a user-found defect; scorer defaults to MISSED, L24–25, L144–146), `rubric_extract.py`/`rubric_prep.py` (substrate/defect disjointness with a contamination assertion, `rubric_prep.py` L35–46), `severity_recheck.js` (blind severity re-rating on `sonnet`, L46–56).

### 1.3 SS (`SS/.claude/commands/check-consistency.md`)

Build → consolidate → archive → sequential `Workflow` panel (L80–90) → `00-SUMMARY.md` + Artifact (L91–94). Discipline block (L96–113) has collect-only, verify-before-trust, no laundering, dispositions in `00-SUMMARY.md` ("A later run reads this so it does not re-flag", L109–111 — but nothing injects it into hats), and fix-the-class. No cost modes, no adjudicated file, no verifiers, no calibration, no closure gate. Piles untracked (L123–124). One round ever ran (`doc-review/00-SUMMARY.md`: 82 raw findings, 1.73 M tokens, 73 min, all dispositions recorded inline).

### 1.4 Protocol diff (PF vs IT)

| Aspect | PF | IT |
|---|---|---|
| Hat set | fixed 12, all run | 27 defined, `core` 10 default, `profile`/`hats` selection |
| Roster to verifiers | hardcoded array in 3 files (`verify.js` L41–43, `verify-fixes.js` L47–49; `coverage.py` L15–18 guards drift) | `hats.json` emitted by the panel |
| Anchors | 2 | 4 |
| Verification pair | both run over the **hat pile**; `verify.js` reads the regenerated manuscript only | `verify.js` over hat pile with repo grep; `verify-fixes.js` over **owner-worded** piles, batched |
| Closure gate | per-finding, reads pile + `closure/` verdicts + adjudicated titles + mtimes; escape `CLOSED.md` | per-round tracked marker with `closed:`; unmarked-pile local check |
| Seeding | optional section; "the catalog is PF's own and must stay that way" (L154) | mandated every round (step 4b) |
| Self-test of recall | `recall_selftest.py` script | comment in `recall.py` header (L14–34) instructing a human |
| Plateau rule | 3 flat rounds, no dead lanes (L275–277) | 3 flat rounds "each surfacing different marginal items" (L358–361) |

---

## 2. EXECUTION MODEL

**All three `panel.js` files are Workflow-tool scripts, not `claude -p` subprocesses.** The evidence is the API surface they use: `export const meta = {name, description, phases}` (PF L16–20; IT L19–23; SS L10–14), a global `args` (PF L24; SS L16), `phase('Panel')`, `agent(prompt, {label, phase, schema, agentType:'general-purpose', model})`, `parallel([...thunks])` (PF L134; IT L315), `pipeline(items, fn, fn2)` (IT `verify.js` L201; `rubric_audit.js` L111), `log()`, and a returned object. The `.md` command files instruct the main session to call `Workflow({ scriptPath, args })` (PF L114–120; IT L241–247; SS L83–87). PF and IT defensively parse `args` as a JSON string (PF `panel.js` L22–24; IT L25–28); SS reads `args.full` directly (L16–19).

Model selection: economy hats get `model:'sonnet'`; anchors get no override and so run at the session model (PF L135–137; IT L316–318). Census/manifest helper agents are pinned to `sonnet` (PF `verify.js` L124; IT `verify.js` L66, L129; IT `panel.js` L296). SS never sets `model` — every hat runs at the session model.

A Workflow script cannot see the filesystem or write files (PF `coverage.py` L4–6; IT `verify.js` L59–61; IT `make.jl` L246–248). Consequences that shape every script: hats are told to `Write` their file FIRST, then return the object (PF `panel.js` L156–159); the roster is fetched by an agent (IT `verify.js` L62–69); the denominator comes from a census agent or a caller-supplied `findings_per_hat` (PF `verify.js` L104–128; IT `verify.js` L118–145); the mechanical demotion runs in post-processing and never reaches the banked markdown (PF `make.jl` L361–367).

### Reads / writes / schemas

| Script | Reads | Writes | Returned object / exit |
|---|---|---|---|
| `consolidate.py` (all three) | `docs/build/**/index.html` (skips `search`, `assets`) | `manuscript-full.md`, `manuscript-siteonly.md` with `===== PAGE: <title> =====` banners and `[ADMONITION]` markers | prints page count; exit 0 |
| `seed_defects.py` | both manuscripts | mutates both in place; `ground_truth.json` = `{seeded:[{id,class,description,page,original_context,mutated_context}], skipped:[class]}` (PF L88–93; IT L80–85) | exit 0 even when classes skip |
| `panel.js` | adjudicated file (by the hats); manuscripts | `<pile>/NN-<key>.md` (hats); IT also `<pile>/hats.json` (L295) | PF `{results, dead}`; IT `{results, dead, empty, complete, hats_run}` |
| Finding schema (all) | | `{hat, candidates_considered (PF/IT), findings:[{type, severity: blocker/major/minor/nit, confidence: high/medium/low, title, locations[], contradicts, description, resolution_hint}]}`; `type` enum differs per package (PF L52 has `math`,`normalization`; IT L61 `physics`,`dimensional`; SS L30 `statistics`,`normalization`) | |
| PF `verify.js` | `<pile>/NN-<key>.md`, regenerated manuscripts, adjudicated | `<pile>/state/NN-<key>.md` (L149) | `{clearedRate, tally, checked, deadLanes, results}`; states `PRESENT/ABSENT/UNCLEAR/NEVER-A-DEFECT` (L73) |
| PF `verify-fixes.js` | pile, `git diff <range>` in repo, adjudicated | `<pile>/closure/NN-<key>.md`, first line `RANGE: <range>` (L155) | `{honoredRate, tally, graded, deadLanes, results}`; verdicts `HONORED/LINE-ONLY/NEW-DEFECT/SCOPE-CREEP/UNDONE/LAUNDERED` (L76); `class_surfaces` is a **string** (L78) |
| IT `verify.js` | `<pile>/hats.json`, hat file, `src/`, `docs/src/`, `docs/ARCHITECTURE.md`, `docs/build`, `CLAUDE.md`, adjudicated | `<pile>/closure/<hat>.md` (L210) | `{tally, anomalies, hats_run, complete, results}`; verdicts `PRESENT/PARTIAL/REGRESSED/ABSENT/NOT-A-DEFECT` (L157); `surviving_class` for PARTIAL (L159) |
| IT `verify-fixes.js` | a single pile file, `git diff <range>`, corpus, adjudicated | `${REPO}/.claude/doc-review/fix-audit/batch-<a>-<b>.md` (L160, path hardcoded) | `{tally, demoted_by_script, anomalies, batches, complete, results}`; verdicts add `ADJACENT`, `INSERTED` and a `question` field `fidelity/strategy/implementation/scope/none` (L67–68); `class_surfaces` is an **array** (L70) |
| `coverage.py` | `<pile>/NN-*.md` and `<pile>/<subdir>/NN-*.md` | stdout table | PF: exit 1 on `MISSING`/`SHORT`/`PARSED TO ZERO`/`ORPHAN`/no banked files (L45–47, L79–81); IT: exit 1 on bad, **exit 2** on no hat files (L62–64) |
| `recall.py` | `ground_truth.json`, `<pile>/NN-*.md` | stdout | no non-zero exit |
| `recall_selftest.py` (PF) | — | temp dirs | exit 1 on any arm failing (L109–114) |
| PF `make.jl` `lint_review_closure` | `.claude/doc-review*` (not `-prev`), `closure/`, `CLOSED.md`, adjudicated | — | `error()` fails the docs build (L402–416) |
| IT `make.jl` `lint_review_closure` | `.claude/review-rounds/*.md`, `.claude/doc-review` dir | — | `error()` fails the build (L291–301) |
| IT `rubric_extract.py` / `rubric_prep.py` | git at `BASELINE="b16a7df"` (L20), `.claude/doc-reading-pile-2026-08-15.md` (L21) | `.claude/rubric-audit/{findings.json,index.json,substrate/NN.txt,defect/NN.md}` | contamination check prints CLEAN/LEAK (`rubric_prep.py` L46) |
| IT `rubric_audit.js` | `{repo, base, hats:[{key,persona}], index}` | — | `{tally CAUGHT/PARTIAL/MISSED, unassigned, gaps, scores, byHat, complete}` |
| IT `severity_recheck.js` | `{items_path, count}` JSON | — | one `{id, severity, reason}` per item |

File-naming: PF banks contiguous `01`–`12`; IT numbers by index in the **full** 27-hat array, so a core run banks `01,02,03,04,06,12,18,21,22,27` (`panel.js` L254–258; `doc-review/hats.json`). PF's `make.jl` accepts both heading forms hats emit — `## Finding N — title` and `## N. title` — because the two anchor hats used the second and parsed to zero (L321–329). Verdict files: PF `**Verdict:** HONORED` / `**Verdict**: HONORED` both accepted (L370–374); IT `**VERDICT: ABSENT**` (sample `doc-review-prev/closure/04-consistency-matrix.md`). `coverage.py` in both accepts `VERDICT: X` and standalone `**X**` (PF L36–41; IT L30–35), but PF's TOKEN carries both PF vocabularies while IT's carries only the state set (IT L34) — pointing IT's coverage at a `fix-audit/` dir would count zero.

Two vestiges: PF `verify-fixes.js` L155 still asks each lane to stamp `RANGE:` as its first line although `make.jl` L346–350 records that all eight lanes ignored it and staleness moved to mtime; and both PF and IT `panel.js` L1 still say "sequential" in the header.

---

## 3. THE HAT CATALOGUE

Tier: **A** = anchor (session model), **E** = economy (`sonnet`), **S** = session model because no cost mode exists (SS). Coupling: **G** generic, **G+** generic lens whose persona text is parameterized with package terms, **D** domain-specific, **X** package-only.

### PF (`PF/CC/panel.js` L73–130), 12 hats, order = presentation

| # | key | tier | role | coupling; quote |
|---|---|---|---|---|
| 01 | consistency-matrix | E | matrix every recurring entity, diff across pages | G+ — "the field f, the transform F, the wavenumber k" (L75) |
| 02 | software-architect | E | documented design as a senior Julia dev | G+ — "the base⊗fiber section model, the physical/spectral representation split, the code-generation layer" (L78) |
| 03 | spectral-methods-mathematician | **A** | transform pair, 1/N, iκ sign, Nyquist split, Parseval, Hermitian symmetry, spline order | D — whole persona is pseudospectral theory (L83) |
| 04 | differential-geometer | **A** | fiber-bundle/section model, base vs fiber, measure taxonomy, adjoints between the right spaces | D/X — "a SECTION of a flat tensor bundle E = B x V … pi ∘ s = id_B" (L93) |
| 05 | gpu-kernel-practitioner | E | allocation-free/no-scalar-indexing/plan-reuse/fusion/parity claims | G+ — "invariant 6", "`_assign!`", "a strided dot" (L96) |
| 06 | structure-consistency | E, SITEONLY | infer the docstring template, flag outliers | G (template shape is PF's rubric, L99) |
| 07 | latex-typesetter | E, + source + CLAUDE.md | TeX idiom against the house rulebook | G mechanism, X house set — "`\\partial_{x_i}`; COMPONENT notation … NOT \\boldsymbol" (L104–113); substrate names PF's `CLAUDE.md` §Style block titles (L109) |
| 08 | api-user | E | drive the library from docs alone | G+ — "build a field, transform it, take a gradient, convolve, reduce, interpolate" (L116) |
| 09 | normalization-convention-auditor | E | every factor/sign/ordering convention identical across pages | D — "the projector I - k k^T / |k|^2 … the N/M rescaling" (L119) |
| 10 | citations-integrity | E | author-year consistency, DOI matching, no inaccessible source | G+ — named methods list is PF's (L122) |
| 11 | style-editor | E, + raw HTML | majority-style uniformity + silent render failures | G+ — register rules ("never particle/tracer") (L125) |
| 12 | cold-reader | E, SITEONLY | Fourier-literate newcomer's cold read | G+ — term list "a base, a fiber, a section, … a cutoff" (L128) |

### IT (`IT/CC/panel.js` L91–252), 27 hats; `core: true` on 10; order = priority and file numbering

| # | key | tier / core | role | coupling; quote |
|---|---|---|---|---|
| 01–03 | free-reader-a / b / c | E, core | no checklist; three independent samples (a: sceptical colleague, b: adoption decision, c: teach it next week) | G — no package terms at all (L102–109) |
| 04 | consistency-matrix | E, core | as PF | G+ — "each physical quantity (symbol, formula, normalization, units, code name)" (L112) |
| 05 | software-architect | E | as PF | G+ — "the spectral state, the deposit-driven cache with its slot=register merge, the generator protocol" (L115) |
| 06 | turbulence-theoretician | **A**, core | physical laws, constants, derived scales, and the category/type-error class | D — "eps = nu<|omega|^2> … S ~ -0.5 … L11/L22/L_E" (L120–122) |
| 07 | dns-practitioner | E | numerical methods + performance claims; dealias band consistency | D — "2/3 vs sqrt(2)N/3 … IF-RK2 and low-storage RK3" (L125) |
| 08 | external-standard | E (dormant) | domain's required-content checklist; absence is a finding | D — "kappa_max eta … Batchelor-scale … CFL" (L134) |
| 09 | existence-auditor | E (dormant) | should this public form exist; is the set complete | G — quotes IT purposes as examples only (L141) |
| 10 | quantifier-auditor | E (dormant) | every every/all/none checked member by member | G — examples are IT's two real misses (L144) |
| 11 | conjunction-coverage | E (dormant) | caveat × reachable option space | G mechanism, IT option axes named (L151) |
| 12 | logician | **A**, core | circularity, equivocation, non sequitur, unfalsifiability | G (L160) |
| 13 | conceptual-clarity | E (dormant) | identity/category confusions in non-physics prose | G (L163) |
| 14 | structure-consistency | E, SITEONLY (dormant) | as PF, plus the binding DIRECTION RULE | G (L166) |
| 15 | latex-typesetter | E (dormant) | as PF with IT's house set | X house set — "BOLD ITALIC \\boldsymbol{u} — never upright \\mathbf … \\varphi never \\theta" (L174) — note this is the **opposite** vector convention to PF's |
| 16 | api-user | E (dormant) | as PF | G+ — "assemble a Simulation, spin it up, observe it with a run! callback" (L181) |
| 17 | reader-standpoint | E (dormant) | what a reader can set/read that yields a wrong number silently; a recorded decision does not immunize | G (L188) |
| 18 | dimensional | **A**, core | dimensional consistency + normalizations | D — "the 2*varkappa in scalar dissipation … sqrt(2)N/3 vs (2 sqrt(2)/3) kappa_Ny" (L193) |
| 19 | citations-integrity | E (dormant) | as PF | G+ — IT's method list (L196) |
| 20 | style-editor | E (dormant) | as PF, plus DIRECTION RULE | G+ (L199) |
| 21 | cold-reader | E, core, SITEONLY | first-year grad student; two sharpenings (ordinary English words with package meanings; ordered read) | G+ — "a boundary, a deposit, a stamp, an epoch, a slot" (L202–204) |
| 22 | plain-sense | **A**, core | does the sentence mean anything / earn its place; delete test | G (L206) |
| 23 | naming-policy | E, + CLAUDE.md + src (dormant) | public surface vs the written naming rules; rulebook outranks corpus | X — the four rules are IT's (L227–231) |
| 24 | doc-policy | E, + CLAUDE.md + src (dormant) | each docstring vs the written documentation policy | X — map/home/constructor-first rules (L234–238) |
| 25 | invariants-and-decisions | E, + CLAUDE.md + §11 (dormant) | code and docs vs recorded invariants and decision log, both ways | X — the five invariants are inlined (L243) |
| 26 | fossil-and-drift | E, + repo + git (dormant) | the only history-aware hat; text orphaned by a rename | G mechanism (L247) |
| 27 | pf-parity | E, core, + PF clone | divergences from the sibling PF never deliberately decided | X — substrate `${REPO}/inspiration/GBGPeriodicFields` (L249) |

The `.md` table (L51–75) lists 23 rows in a different numbering and says "24 defined" (L45), while `panel.js` defines 27 and its `meta.description` says "27-expert" (L21): the command file's map has drifted from the script.

### SS (`SS/CC/panel.js` L58–91), 11 hats, all S, sequential

| # | key | role | coupling |
|---|---|---|---|
| 01 | consistency-matrix | matrix + the estimand/estimator/estimate category pass | G+ — "an ESTIMAND vs its ESTIMATOR vs a single ESTIMATE" (L60) |
| 02 | software-architect | as PF | G+ — "the mergeable-monoid / cone interface" (L63) |
| 03 | statistics-theoretician | estimand definitions, estimator consistency, constants | D — "the binned KDE with int K = 1 and the 1/(nh) normalization" (L66) |
| 04 | streaming-stability-practitioner | one-pass/fixed-memory claims, numerical stability of updates | D — "power-sums-about-the-bin-CENTER … the shift-formula recombination" (L69) |
| 05 | structure-consistency (SITEONLY) | estimand-first template outliers | G mechanism, X template (L72) |
| 06 | latex-typesetter (+ source + CLAUDE.md) | TeX idiom; substrate notes `.jl` doubled backslashes (L74) | G mechanism, X rulebook block names |
| 07 | api-user | drive from docs; estimand stated before estimator | G+ (L78) |
| 08 | normalization-convention-auditor | density vs mass vs count; 1/(nh); moment normalizations | D (L81) |
| 09 | citations-integrity | as PF, no named-method list | G (L84) |
| 10 | style-editor (+ raw HTML) | as PF; estimand symbols | G+ (L87) |
| 11 | cold-reader (SITEONLY) | first-year statistics grad student | G+ — "the summary", "the cone", "leverage" (L90) |

Generic across all three by name: `consistency-matrix`, `software-architect`, `structure-consistency`, `latex-typesetter`, `api-user`, `citations-integrity`, `style-editor`, `cold-reader` (8). Domain anchors: PF's two mathematicians, IT's theoretician+dimensional, SS's theoretician+streaming practitioner+normalization auditor. IT-only generic lenses: three free readers, logician, plain-sense, existence, quantifier, conjunction, conceptual-clarity, reader-standpoint, fossil-and-drift, the three rulebook hats, and the cross-package `pf-parity`.

---

## 4. CONFIG COUPLING — every package-specific datum, classified

**(a) Config data** (would become per-package config):
- The PREAMBLE package description paragraph: PF `panel.js` L62; IT L76; SS L45. Also in the verifier preambles: PF `verify.js` L82, `verify-fixes.js` L86; IT `verify.js` L167, `verify-fixes.js` L88.
- The "do not flag these deliberate absences" clause: PF L70 ("physics-free and time-free BY DESIGN"); IT L87 (statistics layer, sheared frame, inertial particles, LES, high-Schmidt); SS has none.
- The design-doc withholding set in `consolidate.py`: PF `DESIGN_DOCS = ("architecture","formalization","testing","performance")` L24; IT `("architecture","observables_cache")` L102; SS `DESIGN = (…,'internals')` L98. Otherwise the three `consolidate.py` are byte-identical in logic (diff output above).
- Finding `type` enums (PF L52, IT L61, SS L30).
- Every persona string (§3), the anchor flags, `core` flags.
- The `latex-typesetter` substrate: source globs (PF L108 includes `examples/*.jl`; IT L170 does not; SS L74) and the CLAUDE.md block titles it must read (PF L109; IT L171; SS L74).
- Seed catalogs: PF `seed_defects.py` L39–56 (8 classes anchored to PF text); IT L31–48 (8 classes anchored to IT text). PF `.md` L154: "the catalog is PF's own and must stay that way".
- `SITEONLY_HATS` (PF `verify.js` L47: `api-user`, `cold-reader` — note the panel's SITEONLY hats are `structure-consistency` and `cold-reader` (L99, L128), so this list is itself inconsistent with `panel.js`).
- The hardcoded `PANEL_HATS` rosters (PF `verify.js` L41–43, `verify-fixes.js` L47–49).
- Paths: pile prefix `doc-review` (PF `make.jl` L307), adjudicated path (PF `make.jl` L300; IT `verify.js` L39), `REVIEW_ROUNDS` (IT `make.jl` L252), the pile dirs the unmarked check scans (IT `make.jl` L284 — whose first tuple element contains a **zero-width space** before `.claude`, so it can never match a real directory), IT's corpus list for verifiers (`verify.js` L173, L191), IT `verify-fixes.js` output path `${REPO}/.claude/doc-review/fix-audit/` (L160), IT `pf-parity` substrate `${REPO}/inspiration/GBGPeriodicFields` (L249).
- Rulebook section names inlined into rulebook hats (IT L227–231 naming rules; L236 doc policy; L243 invariants).

**(b) Genuinely different logic** (must be resolved, not parameterized):
- IT profile/subset selection and index-stable numbering (`panel.js` L254–286) vs PF's fixed roster.
- Roster manifest `hats.json` (IT) vs hardcoded arrays + `coverage.py` ORPHAN detection (PF `coverage.py` L70–76).
- PF's state verifier is manuscript-only (`verify.js` L88) and reads the regenerated manuscripts; IT's greps the repo corpus and knows `CLAUDE.md` (`verify.js` L191–195) and has PARTIAL/`surviving_class`.
- PF `verify-fixes.js` is per-hat lanes over the hat pile; IT's is per-batch over one owner-worded file with `batches` required (L50–56) and eight verdicts + a `question` axis.
- Demotion predicate (§5).
- `recall.py`: PF keeps unverifiable seeds in the denominator and prints them (L55, L81–83); IT removes them from `truth` (L68–69).
- `coverage.py`: PF `FINDING` regex `#{2,4}` and dual vocabularies; IT `#{2,3}` and state vocabulary only; exit codes differ (§2).
- Closure gates (§5).
- PF has `recall_selftest.py`; IT has the rubric triple and `severity_recheck.js`.

**(c) Historic artefacts** (not to be carried):
- "sequential" in both PF and IT `panel.js` L1 and PF L14–15; SS's sequential loop is real (L95–112).
- PF `verify-fixes.js` L155 `RANGE:` stamp request (superseded by mtime, `make.jl` L346–350).
- PF `verify-fixes.js` L184–192: comments describing the retired vocabulary predicate, kept above the replacement note L193–210.
- IT `verify.js` L43–47 "KEEP THIS LIST IN STEP" retained above the "RETIRED" line L56.
- IT `.md` L302–304 still says `ALL_HATS` is a hand-maintained mirror; `.md` L187 "the full 15-hat run"; `.md` table vs 27 hats.
- IT `rubric_extract.py` L20–22: `BASELINE = "b16a7df"`, a specific pile path, `OUT` — a one-off experiment's constants.
- IT `INVENTORY.md` L68 and the task brief both say PF has the closure lint and IT does not; IT ported one on 2026-08-27 (`make.jl` L212–218, marker README).
- IT `.claude/README.md` L19 says `doc-review-round1/` is "regenerated every run"; it is tracked in git.

---

## 5. DIVERGENCES between same-named files, with a judgment

### 5.1 Demotion predicate (HONORED → LINE-ONLY)
- PF `verify-fixes.js` L211: `cs.length >= 60 && /\s/.test(cs) && !/^(n\/?a|none|see above|as noted)\b/i.test(cs)` on a **string**; twin in `make.jl` L388–389. The comment block L193–210 records the 2026-09-01 change from a fixed vocabulary ("SIX of six demotions were spurious, on notation alone") and admits the trade: "a substantive but WRONG class answer now passes".
- IT `verify-fixes.js` L206: `Array.isArray(a.class_surfaces) && a.class_surfaces.length` on a schema **array**; L189–203 explains "EMPTINESS, deliberately, and that is the whole of it … anything that parses the CONTENT of those strings would be re-introducing PF's bug", with five falsification cases including the verbatim phrasing PF had rejected (L198–203).
- **Judgment: IT's is better**, and PF's own file says so (L200–203, "IT's shape and the one CLAUDE.md records as winning"). PF's current predicate is still content-shaped: a true, terse answer under 60 characters demotes. The cost is that IT's needs a structured field, which the markdown-reading gate in PF's `make.jl` does not have (L375 regex-extracts a string) — the banked verdict artifact must carry a machine-readable class list for the array form to reach the gate.

### 5.2 Staleness of verdict files
- PF `make.jl` L342–356: `mtime(verdict_file) < mtime(lane)` fails the lane; all verdict mtimes must fall within a 6-hour bucket or the round is "incoherent" (L402–407). Comment L346–350: the `RANGE:` self-stamp "was in the prompt and all eight lanes ignored it".
- IT: no staleness check anywhere in the check-consistency scripts. The gate reads only the presence of a non-empty `closed:` line (L261). The answer-key leak is handled by prohibition instead: verifiers are forbidden to read any `closure*` dir and told to scope searches with `rg --glob '!.claude/**'` (`verify.js` L171–173; `.md` L315–321 recommends archiving prior verdicts outside the pile).
- **Judgment: PF's mtime is better** ("needs no compliance", `make.jl` L350; IT `INVENTORY.md` L56 concedes "PF — mtime needs no compliance"), but the 6-hour coherence rule already misfired once and forced a `CLOSED.md` (PF `doc-review-checkdocs/CLOSED.md` L33–40). IT's search-scoping rule is complementary, not competing, and belongs beside it.

### 5.3 Verdict sets
- State: PF `PRESENT/ABSENT/UNCLEAR/NEVER-A-DEFECT`; IT `PRESENT/PARTIAL/REGRESSED/ABSENT/NOT-A-DEFECT`. IT's `PARTIAL` "is the verdict that earns the instrument" (`.md` L331) and carries `surviving_class`; PF moved the class question entirely to the act verifier.
- Act: PF six; IT eight (`ADJACENT`, `INSERTED`) plus `question`. The extra two encode IT's recorded fixer failures "fix by insertion" and "a synonym is not the name they chose" (L99–117).
- **Judgment:** no single winner; the sets encode different objects. IT's act verifier audits owner-worded piles and needs fidelity verdicts; PF's audits panel piles. A shared package needs one union vocabulary because `coverage.py` and any gate parse it — PF's `coverage.py` L39–40 already anticipates a union.

### 5.4 The closure gate
- PF `make.jl` L297–419: per-finding; a pile is open until each finding is HONORED (with a substantive class answer, L368–391) in `closure/` or its title (first 40 chars) appears in the adjudicated file (L392–395); `CLOSED.md` escape (L314–318); dead-lane rule (L330–338); mtime staleness. Only `.claude/doc-review*` dirs except `-prev` are scanned (L307), so PF's tracked `check-docs-2026-09-01/` round is **not** gated at all despite carrying a `CLOSED.md`. `.claude/doc-review/` is gitignored (PF `.gitignore` L20–21) while `doc-review-checkdocs/` and `check-docs-2026-09-01/` are tracked — so on a fresh clone the gate covers only the two tracked rounds.
- IT `make.jl` L254–302: per-round; reads tracked markers; `closed:` non-empty closes; an unmarked non-empty `.claude/doc-review` fails locally (L277–294). Falsified in six arms (L232–242); arm 5 "fired for real on its first run". Explicitly not per-finding (L244–251), with the reason: PF's gate "read 30 HONORED against the script's authoritative 23" because it reads the grader's markdown before demotion.
- **Judgment:** each has the hole the other closed. PF is stronger per finding but vacuous on a clone for its gitignored pile (IT `make.jl` L220–224; `INVENTORY.md` L81–84); IT survives a clone but certifies only that "a human wrote an account" (README L27–30). PF's `doc-review/CLOSED.md` L8–30 documents two further per-finding holes: seeded findings (nothing to fix, cannot be adjudicated) and hats that write untitled `## Finding N` headings (no title to match).

### 5.5 Per-finding adjudication vs wholesale escape
- PF: adjudicated entries carry `Settles, verbatim:` titles for machine matching (`adjudicated.md` L28, L52, L73, L124–134); `CLOSED.md` used once for a panel round (`doc-review/CLOSED.md`) and twice for `/check-docs` rounds.
- IT: adjudicated entries are prose bullets read by agents only (`adjudicated.md` L3–6); the one closing channel is the wholesale `closed:` line (README L21–30). IT's own inventory names this as a deferred gap: "IT currently has only the wholesale escape (`closed:`), which PF warns is the one you reach for when there is no per-finding alternative" (`INVENTORY.md` L118–121).
- **Judgment: PF's per-finding, title-keyed channel is better**, subject to the two structural gaps above, and IT's `closed:` account requirement ("abandoned" is a legitimate account, README L32–34) is the right shape for the wholesale escape.

### 5.6 Smaller divergences
- Roster: IT `hats.json` (structural) vs PF three hardcoded copies guarded by `coverage.py` ORPHAN (L70–76). IT's shape is better; PF's `coverage.py` L13–18 says as much.
- Census: both use a census agent with `findings_per_hat` override; IT additionally fails hard when the census cannot count (`verify.js` L139–144); PF logs and continues (L128).
- Panel concurrency: PF and IT `parallel`; SS sequential. IT logs `empty` hats separately from `dead` (L333–338); PF logs "returned empty — NOT the same as dead" (L173–176) and `TRUNCATED` when `candidates_considered > findings` (L174).
- `recall.py` treatment of unverifiable seeds: PF reports and keeps them; IT drops them from the denominator (L68–69). PF's is the more conservative reading ("their recall is UNDEFINED too", L81–83).
- `coverage.py` on a clean lane: PF's `PARSED TO ZERO` is an error even for a lane that states "No findings" (`check-docs-2026-09-01/CLOSED.md` L43–49), while PF's `make.jl` accepts the phrase (L335) — an internal inconsistency inside PF.

---

## 6. DESIGN CONSTRAINTS / LESSONS a shared package must honour

Each with the file:line that states or evidences it.

1. **The missing case must be the failing case.** IT `make.jl` L220–224, `review-rounds/README.md` L7–10; PF `coverage.py` L45–47 (no banked files → exit 1), L60–62 (parse-to-zero is an error); IT `coverage.py` L59–64 (empty dir → exit 2); PF `verify.js` L128 (no denominator → say so); PF `make.jl` L330–338 (zero-parse lane is dead unless it says "no findings"); IT `INVENTORY.md` L81–84 (a gate reading only an untracked pile passes vacuously).
2. **A fix pass is driven from the banked per-hat files, never the consolidated summary; closure is reported per hat and per finding number.** PF `.md` L203–216 (19 of 20 findings lost in a parenthetical; a major relayed as "soft"); IT `.md` L410–420; IT `.md` L286–291 (no unenumerated bucket; per-hat closure table).
3. **Instruments are frozen; an instrument change is its own commit, never folded into a round it is scoring.** IT `INVENTORY.md` L92–107 (PF at `faa164a1`, IT at `fdeba74`); PF `check-docs-2026-09-01/CLOSED.md` L56–59 ("Instruments are frozen … Two were surfaced by this round and are left for that"); PF `doc-review/CLOSED.md` L29–30. Corollary: a rate sequence is meaningful only at a fixed instrument (IT `.md` L349–358).
4. **Seeds must never enter the adjudicated file, and never drive a fix.** PF `doc-review/CLOSED.md` L20–22 (adjudicated is injected into every future hat's preamble, seeds are deterministic and reused); PF `.md` L160–164; `seed_defects.py` PF L23–26, IT L20–22; consolidation subtracts seeded hits before the summary (PF `.md` L162; IT `.md` L270–272). The contradiction with the closure gate is open (PF CLAUDE.md; `doc-review/CLOSED.md` L14–30).
5. **The loop runs over the banked findings, never by re-running lanes; stop at a plateau, not a good round.** PF `.md` L275–277; PF `verify-fixes.js` L235–238 (43→69→76→95→93→90 %, round 2 hid eleven LINE-ONLYs); IT `.md` L338–361; PF `doc-review/CLOSED.md` L62–65 (tally held while composition changed — not a plateau).
6. **The denominator never comes from the graded party.** PF `verify.js` L96–103, L112–115 (census agent; `findings_per_hat` removes any agent from the loop); IT `verify.js` L102–117 ("no agent both sets the denominator and is measured against it"); disagreement between self-report and census is logged, not overridden (PF L162–165; IT L248–252).
7. **Demotion is applied mechanically in post-processing and its mechanical share is reported separately.** IT `verify-fixes.js` L182–188, L216–219; PF L175–178; PF `.md` L231–234.
8. **A gate must read the grader's verdicts, never the graded party's file** — and a Workflow script cannot write files, so verdict artifacts are written by agents pre-demotion. IT `make.jl` L244–251; PF `make.jl` L361–367 (30 HONORED read against the script's 23).
9. **Default to the unfavourable verdict; a truncated lane fails safe.** PF `verify.js` L89; PF `verify-fixes.js` L99; IT `verify.js` L16–19, L179–186 ("That inversion is what licenses the economy lane").
10. **A zero count is a dead lane, not a clean hat; dead, empty and truncated are three different things.** PF `panel.js` L154–179; IT `panel.js` L326–338; IT `verify.js` L216–235 (misread in both directions on 2026-08-18); PF `.md` L282–291 (`candidates_considered`).
11. **The adjudicated list must reach hats and both verifiers; nothing merely fixed is listed there, so absence proves nothing.** PF `verify.js` L51–61; `verify-fixes.js` L54–64; PF `adjudicated.md` L7–8; IT `verify.js` L34–39; IT `verify-fixes.js` L137–142 ("An assistant-authored dismissal is LAUNDERED").
12. **Two verifiers with deliberately opposite information: the state auditor is blind to the diff, the act auditor must see it; disagreements are the interesting cells.** PF `verify.js` L4–13, L183–186; PF `verify-fixes.js` L12–18; IT `verify.js` L9–23; IT `verify-fixes.js` L9–17.
13. **The roster is emitted by the panel and read by the verifiers, never hand-maintained.** IT `panel.js` L288–296; IT `verify.js` L48–57; PF `coverage.py` L13–18, L70–76 (ORPHAN as the fallback detector).
14. **Hats are blind to prior rounds except the adjudicated file** (fresh eyes caught a false sentence a fix pass introduced). PF `panel.js` L30–35; PF `.md` L122–128; IT `panel.js` L34–39.
15. **A self-check is a script, not a note; fixtures are built in the test, not drawn from the catalog.** PF `recall_selftest.py` L7–18 ("A test passing over a catalog is a property of the CATALOG, not of the code"); IT `recall.py` L14–34 is the note form; IT `INVENTORY.md` L71–75 names this as the piece it would take first.
16. **A skipped seed class is UNDEFINED, excluded from the denominator, and named.** PF `recall.py` L32–36, L79–88; IT `recall.py` L40–45, L104–110.
17. **Test the check in both directions — the flattering one too.** PF `recall.py` L20–26 (arm C: not falsely high); PF `verify-fixes.js` L205–210 (a spurious-demotion column stops being read); IT `verify-fixes.js` L196–203 (five cases); IT `make.jl` L232–242 (six gate arms, arm 4 the "rubber stamp" one); PF `make.jl` L357–360 (counting the word HONORED inflated 2 to 6).
18. **The seeded manuscripts are disposable; the panel measures yield and must not be read as coverage.** PF `.md` L138–147; `seed_defects.py` PF L5–16; PF `00-SUMMARY.md` "Calibration first" block (the normalization auditor missed the planted N/M inversion).
19. **Corroboration carries a denominator; a capped hat is not a complete hat.** IT `.md` L279–284.
20. **Verdict and findings files are the durable record because a returned object can come back empty.** PF `verify.js` L149; PF `coverage.py` L4–7; IT `coverage.py` L9–12.
21. **Archive previous verdicts where a corpus search cannot reach them.** IT `.md` L315–321; IT `verify.js` L171–173.
22. **The seed catalog and personas are per-package; the mechanism is shared.** PF `seed_defects.py` L2–3; PF `.md` L154–157; IT `INVENTORY.md` L44–49.
23. **The core profile is measured, built upwards, and admission needs more than one run.** IT `.md` L110–124; IT `panel.js` L259–270 (72 % self-reproduction between arms).
24. **Majority-as-norm hats are detectors, never verdicts; rulebook hats outrank the corpus.** IT `.md` L149–153, L161–169; IT `panel.js` L166, L199, L221–225.
25. **Staleness is read from the filesystem; a self-reported field is acceptable only when the missing case is the failing case.** PF `make.jl` L346–350; IT `INVENTORY.md` L56.
26. **A rule stated in a command file is not enforced; move it into an exit code.** PF `make.jl` L277–286 (16.1 % honored on a round reported "all closed"); IT `make.jl` L212–218.

Two open contradictions the shared design inherits rather than resolves: the seeds-vs-closure-gate conflict (item 4; PF CLAUDE.md "unresolved"), and the untitled-findings gap in title-keyed adjudication (PF `doc-review/CLOSED.md` L24–27). IT's `INVENTORY.md` L77–84 states the two constraints already agreed for a shared gate: it must become a script both builds call, and it must fail when the pile it expects is absent.