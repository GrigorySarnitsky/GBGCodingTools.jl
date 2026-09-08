# Shared-instrument surface survey — PF / IT / SS / CP

Base `$B` = `/home/grigory/Dropbox/Research and Teach/`. PF = `$B/Isotropic Turbulence/GBGPeriodicFields`, IT = `$B/Isotropic Turbulence/GBGIsotropicTurbulence`, SS = `$B/Statistics/GBGStreamingStatistics`, CP = `$B/Cloud Physics/GBGCloudPhysics`. Sections 1, 4, 5, 6 were gathered by four parallel investigations (each read the files in full and diffed same-named bodies); 2, 3, 7 I read directly. Facts only; no architecture proposed. "Artefact" below means a difference that looks like a fork-and-drift; "necessary" means a difference tied to the package's domain or repo topology.

---

## 1. Build-enforced doc lints (`docs/make.jl`)

Sizes: PF **689** lines, IT **398**, SS **115**, CP **56**. None shells out to any script (`run(` absent in all four); external scripts are only *named in prose* (PF:134 `guards.sh`, PF:411/415 `verify-fixes.js`/`doc-review-adjudicated.md`). Every failure is `error(...)` (nonzero exit); `error(` sites PF 10, IT 9, SS 1, CP 0.

### Matrix: lint × package

| Lint | PF | IT | SS | CP |
|---|---|---|---|---|
| `_doc_lint_sources` (shared file set) | 44–57: `src/*.jl` + four rationale docs + `docs/src/**/*.md` minus 4 generated copies | 28–39 **variant**: only `ARCHITECTURE.md`; generated = `architecture.md, decisions.md` | absent (inlined in `lint_inline_math` 14–24) | absent |
| `lint_inline_math` (list-leader continuation of a ``…`` span) | 67–97 (31) | 154–183 (30) — **identical code**, comment-only diff | 11–49 (39) — **older ancestor**: `leader = r"^\s*…"` (SS:12, unbounded) vs PF/IT `r"^\s{0,3}…"`; toggle `isodd(count("\"\"\"", line))` (SS:32) vs `strip(line) == "\"\"\""` | absent |
| `lint_notation_variants` | 104–123: 2 regexes `\\partial_[ijk]`, `\\[dt]?frac[0-9]` | 188–209: **5** regexes — adds `\\mathbf`, `\\boldsymbol(?!\{)`, `\\mathbb\s*\{?\s*[0-9]`; frac rule `\\[dt]?frac\s*[^{\s]` (catches `\tfrac N2`) | absent | absent |
| `lint_swallowed_escapes` (unescaped `\n`/`\t` in docstrings) | 144–164 | absent | absent | absent |
| `lint_retired_claims` (8 decision-60 phrases, §13 exempt) | 181–217 | absent | absent | absent |
| `lint_api_page_structure` (`## Internal API` last, no empty `@docs`) | 231–248 | absent | absent | absent |
| Shape ratchet | `lint_prose_shape` 489–534 + 421–487; `docs/prose_shape.csv` (`unit,words,longest_paragraph,admonitions`, **612 rows**: 319 docstrings + 293 md sections); re-baseline `PROSE_SHAPE_BASELINE=1` **or missing CSV auto-writes** (491); caps 120/3 on NEW units only | `lint_docstring_shape` 110–151 + 69–108; `docs/docstring_shape.csv` (`key,longest_paragraph_words,admonitions,total_words`, **159 rows**, docstrings only, commas as U+FF0C); `DOCSTRING_SHAPE_BASELINE=1`; **missing CSV is an error** (123); caps bind on ALL docstrings (138–140) | absent | absent |
| Docstring STRUCTURE guard (`# Arguments` before any `!!!`, `# Fields` last) | absent | inside `_docstring_shapes` 96–104 | absent | absent |
| `lint_review_closure` | 297–419 (123): reads **untracked** piles `.claude/doc-review*`, per-lane `closure/` verdicts, `doc-review-adjudicated.md`; fails on dead lane, verdict older than lane (mtime), `honored+dismissed < findings`, verdict mtimes spanning >1 six-hour bucket; HONORED needs `class_surfaces` answer ≥60 chars (388–389, "twin of verify-fixes.js"); escape = committed `CLOSED.md` in the pile (318) | 254–302 (49) — **same name, different mechanism**: reads **tracked** markers `.claude/review-rounds/*.md`, fails on a marker lacking `closed:` (261) or a pile no marker names (283–294); never parses verdicts. Line 284 tuple `("​.claude/doc-review", ".claude/doc-review")` — first entry begins with **U+200B**, a dead path | absent | absent |
| `lint_ai_banner` (AI-provenance banner on rationale docs + tutorial + Literate example) | 548–568 | absent | absent | absent |
| `lint_rendered_markup` (post-`makedocs`, literal `**`/`__` in built HTML) | 653–682, runs at 684 AFTER makedocs | absent | absent | absent |
| Sentence-opener scan | not in make.jl (script `.claude/commands/check-docs/sentence_openers.py`) | absent | absent | absent |
| Table-indentation guard | not in any make.jl (PF CLAUDE.md names it as a manual grep) | — | — | — |
| `checkdocs` | `:exports` (610) | `:exports` (360) | `:exports` (85) | absent (default) |
| `doctest` | `true` (611) | `false` (361, "no runnable examples yet") | `true` (86) | absent |
| `warnonly`/`linkcheck`/`strict` | none | none | none | none |
| `size_threshold_ignore` | 608 (`architecture.md`, `performance.md`) | — | — | — |
| `plugins` | — | `DocumenterInterLinks` (362) | — | — |
| Run order | all lints before `using Documenter` (570–580); `lint_rendered_markup` after | all before (304–308); nothing after | lint at 51, before `copy_rationale_pages` 63 | no lints; `copy_rationale_pages` 13–20 ("Mirrors GBGPeriodicFields' docs/make.jl", 12) |

### Provenance and drift (from `git log -S`)
- `lint_inline_math`: SS `72a10de` 2026-06-24 (earliest) → PF `b0e4b713` 2026-07-02 ("adopt the doc-quality transfer from GBGStreamingStatistics") → IT `5ceefe4` 2026-07-06. SS never received the two later tightenings (leader bound, docstring toggle). No source comment in PF/IT credits SS; PF's memory/CLAUDE.md does.
- `lint_notation_variants`: PF `f46e2861` 2026-07-02; IT 2026-07-06 then extended. **Cross-package contradiction:** IT bans `\mathbf` outright (IT:192) while PF's CLAUDE.md prescribes `\mathbf{1}` for the indicator — IT's own OPEN-ITEMS.md B3-M43 records "the `\mathbf` ban is a PF-parity divergence never dispositioned".
- Shape ratchet: IT `b4d045f` 2026-08-19 → PF `cf10e2ee` 2026-08-27, "Ported from GBGIsotropicTurbulence 2026-08-27, and EXTENDED from its docstrings-only scope to the pages" (PF:251–252). Rewritten, not copied: different CSV schema/column order, key format, paragraph counting (IT skips list/fence/table blocks, PF counts every blank-line block), admonition regex (`^!!! ` vs `!!! `), cap scope, env var name, missing-file behaviour.
- `lint_review_closure`: both 2026-08-27 (PF `2a43a724`, IT `fdeba74`, "Ported in shape from the PF session"), opposite designs (untracked pile + `CLOSED.md` vs tracked marker + `closed:` line). IT's marker design is the one that satisfies the "missing case must fail on a fresh clone" constraint PF's own CLAUDE.md states; PF's reads the untracked pile.
- `copy_rationale_pages`: PF 13–17 ≡ SS 57–61 (identical); CP copies one doc + SVG; IT splits `ARCHITECTURE.md` at `## 11. Decision log` into two pages.

### `.claude/commands/check-docs/` guard scripts (named by make.jl prose only)
PF: `argcov.jl`, `doi_crosscheck.py`, `field_docs.py`, `guards.sh`, `link_uniformity.py`, `sentence_openers.py`. IT: `abutting_spans.py`, `argcov.jl`, `doi_crosscheck.py`, `dupref.jl`, `lanes.js`, `signature_fidelity.jl`, `xlink.jl`. SS: no `check-docs/` dir (only `check-docs.md` 200 lines + `check-consistency/{panel.js 113, consolidate.py 113}` dated 2026-07-15/18 — a **July-vintage fork** untouched since). CP: no `.claude/commands/` at all.

---

## 2. Hooks and settings

### PF-only harness
- `PF/.claude/settings.json` (14 lines): one `Stop` hook → `"$CLAUDE_PROJECT_DIR"/.claude/hooks/queue-guard.sh`. **No other package has `settings.json`, `hooks/`, or `WORK_QUEUE.md`**; `~/.claude/settings.json` has no `hooks` key.
- `queue-guard.sh` (40 lines, tracked): exits 0 if payload has `"stop_hook_active": true` (the loop guard, :20–22); reads `${CLAUDE_PROJECT_DIR:-.}/.claude/WORK_QUEUE.md`; any `- [ ]` line → prints the open items to stderr and `exit 2` (:27–40). Contract in its header (:11–13): closing an item is a diff-visible edit.
- `WORK_QUEUE.md` (168 lines, tracked): 15 dated "## Open (authorised …)" blocks, 2026-08-27 → 08-31, **every item `- [x]`** — nothing open. Its format (`- [ ]` = open) collides with IT's untracked `OPEN-ITEMS.md`, which uses `- [ ]` for its live remainder; the hook is PF-local so nothing fires there.

### `settings.local.json` ×4
| | PF | IT | SS | CP |
|---|---|---|---|---|
| `autoMemoryDirectory` | `~/Dropbox/Research and Teach/AI Helpers/claude-memory/GBGPeriodicFields` | …`/GBGIsotropicTurbulence` | …`/GBGStreamingStatistics` | …`/GBGCloudPhysics` |
| `permissions.allow` entries | 20 (julia/Pkg invocations, `git add/commit/push/fetch`, `WebFetch(domain:www.fftw.org)`, `WebSearch`, `Read` on the whole IT tree and SS tree, `rocm-smi`, `Workflow(deep-research)`) | **none** | 2 (`git ls-remote`, a CRAN `curl -sI`) | 3 (`git rev-list`, `find inspiration`, `python3 -m json.tool`) |
| git-tracked? | **yes** (in `git ls-files .claude`) | no | no | no |
Shared: the memory-dir key (identical shape; memory dirs exist with 37/53/8/19 files). Differs: the allowlists are accumulated per-session and PF's grants cross-tree `Read` on IT and SS — the read channel for sibling sources. No secrets in any file. PF's memory note calls this file "gitignored-but-synced"; in PF it is in fact tracked, in the other three untracked and not ignored.

### `.claude` tracking policy (differs per package — artefact, not necessity)
- PF (`.gitignore:17–21`): ignores only `doc-review/`, `doc-review-prev/`; tracks 90 files incl. `WORK_QUEUE.md`, `settings.local.json`, `doc-review-adjudicated.md`, two banked rounds with `CLOSED.md`, `to-IT-*.md`, all commands.
- IT (`.gitignore` has no `.claude` line): piles untracked by convention (`.claude/README.md:3` "never committed — only the instrument files under `.claude/commands/` are tracked" — **stale**: git also tracks `README.md`, `arch-research/`, `archive/`, `audit-changes/latest.json`, `bug-hunt/OPEN-DEFECTS.md`, `review-rounds/`); `pf-request-*`, `ss-request-*`, `OPEN-ITEMS.md`, `doc-review*/` are `??`.
- SS: tracks 5 files (two `.md` commands + `check-consistency/`); `doc-review/` (7 July files) untracked, not ignored.
- CP: tracks nothing under `.claude`.
- Branch: IT is on **`main`** (docs.yml deploys on `main`); PF/SS/CP on `master`.

---

## 3. Cross-session request convention

**Where a request lives.** In the *requester's* `.claude/`, named for the *target*: IT holds `pf-request-<date>[-<topic>].md` ×8 (2026-08-23 → 09-05) and `ss-request-2026-08-28-online-correlator.md`; all **untracked** in IT (`git status` `??`) and reach PF only via Dropbox — PF's CLAUDE.md:2068 cites the path `GBGIsotropicTurbulence/.claude/pf-request-2026-08-29-cpu-kernel-performance.md` directly. PF's replies are `to-IT-<topic>-<date>.md` ×2 in PF's `.claude/`, **tracked** in PF. So the two directions differ in tracking (artefact).

**Structure** (from the eight IT files): H1 `# Request from GBGIsotropicTurbulence (IT) — <date>, against GBGPeriodicFields <master|0.1.0>[: topic]` (later ones `# PF request (<date>): topic`); a `**From**` line naming the originating work; priority-ordered numbered items, each stating the *need* not the API ("Surface design is yours; the requests state the need, not the API", `pf-request-2026-08-23.md:10–12`), with measurements reproduced, an acceptance criterion, and often a failing witness held IT-side; a "What I am not asking for" section; "Evidence available on request".

**Answer/closure.** The request file is edited **in place at the top** with a blockquote or bold STATUS paragraph carrying both packages' decision numbers, commit, and the closing sentence "This file is now a record" / "Channel closed again after the reply" — e.g. `pf-request-2026-09-05-reality-projection.md:3` ("STATUS: SHIPPED by PF (decision 83, master 352699a1) and WIRED into IT (decision 88, same day)"), `pf-request-2026-08-24-allocator.md:3–5` ("DELIVERED 2026-08-24 (same day), PF decision 74 … Wired in IT decision 64"). The PF-side reply files use the older protocol: "adversarial triage, per-item dispositions, a decline recorded as a decision. Every headline number was reproduced on PF's side before dispositioning" (`to-IT-triage-reply-2026-07-19.md:3–8`), verdict line "ship 1, 2, 5, 6, 7; defer 3, 4; decline the general fusion API" (:10).

**`pf-request-2026-08-27-instruments.md` (134 lines)** — the one instrument request: "Not an API request" (:3). Three mechanisms, explicitly not code: (1) a measured hat profile (`core` flag + `PROFILE` selector, "built UPWARDS", backed by the 5.94 M-token/184-finding vs 1.64 M/58 paired arm, :24–44); (2) two verifiers with opposite information — `verify.js` state/blind, `verify-fixes.js` act/diff, verdicts `HONORED/LINE-ONLY/NEW-DEFECT/SCOPE-CREEP/UNDONE/LAUNDERED`, unfavourable default, zero count = dead agent, plateau stopping rule (:48–82); (3) `/bug-hunt` with the witness rule (:86–119). "What I am not asking for" (:123–134): not IT's core list, schema, or scripts verbatim. Answered: PF's `witnesses.jl` header "Ported from GBGIsotropicTurbulence 2026-08-27 (mechanism only)"; PF now has `verify.js`, `verify-fixes.js`, `bug-hunt/`, `test/regressions/`; PF CLAUDE.md:907 "the last two ported from IT 2026-08-27".

**Supporting conventions.** `IT/.claude/README.md` (52 lines, tracked, "Re-verified 2026-08-20") is an index of live-vs-settled piles. `IT/.claude/OPEN-ITEMS.md` (639 lines, untracked) header: "RE-VERIFIED 2026-08-30 … of its 107 items, 91 are CLOSED, 12 SUPERSEDED, 2 PARTIAL, 6 OPEN"; live remainder as `- [ ]` checkboxes. `IT/.claude/commands/INVENTORY.md` (121 lines, tracked) is the fact base for the shared package — sizes (IT 33 files/4583 lines; PF 17/1977), the zero-coupling list, the four behavioural divergences table — and PF's CLAUDE.md carries the same content inline ("PF keeps the same content in its own `CLAUDE.md`", INVENTORY.md:5–6). Both trees carry `.claude/commands/MANIFEST.txt` + `manifest.py` ("Format agreed with the IT session 2026-08-27 so either package can diff toolboxes in a single read"); PF's variant adds a root manifest for directory-less commands (`manifest.py:12–17`), and the two scripts differ by 206 lines. Cross-reads happen through gitignored `inspiration/` clones: IT's `inspiration/GBGPeriodicFields` is byte-identical to live PF (2026-09-05), CP's clone is 1–2 days behind, SS's is a **July** snapshot.

---

## 4. CLAUDE.md policy overlap

Sizes: PF **2685** lines, IT **504**, SS **680**, CP **104**. Policy-vs-specific estimate (method: block-by-block, ±5%): PF ≈ 687 policy / 1998 specific; IT ≈ 323 / 181 (≈ 222 / 282 if its `## Known weaknesses` self-guards are counted specific); SS ≈ 197 / 483; CP ≈ 12 / 92.

### Matrix (IDENT = near-verbatim; PARA = paraphrased; ABS; CONTRA)

| Rule | PF | IT | SS | CP |
|---|---|---|---|---|
| a two-tier rubric | 183–199 | PARA 137–164 (6 items not 7; + type tier; map "deliberately tighter than PF's", 233) | ABS (estimand-first 225–238) | ABS |
| b one concept, one home | 201–209, 867–873 | PARA 175–182 | dispatch half only 217–218 | ABS |
| c shape rules | 211–246 | ≥3-args IDENT 213–216 ("PF's numeric rule, adopted 2026-08-24"); admonition titles **CONTRA** 205–207 (bare `!!! note` allowed for asides); in-place steer **CONTRA** 179–182 ("deliberately not adopted, owner-ruled 2026-08-25"); aliasing ABS | ABS | ABS |
| d notation glyphs + `notation.md` | 283–290 | PARA 254–262 (+IT glyph set; `\boldsymbol` never `\mathbf`) | ABS by declaration 278–279 | ABS |
| e LaTeX + code↔symbol binding | 352–365 | PARA 264–268 | PARA 250–262 | PARA 87, 92 (no binding) |
| f silent-rendering (a)–(d) | 366–389 | PARA 270–278 | PARA 253–270 (cites "the `inspiration/GBGPeriodicFields.jl` convention — its `anterpolate!`", 266) | ABS |
| g LaTeX idiom / `\left` ban | 390–420 | PARA 281–286 ("adopted from PF 2026-08-06") | near-IDENT 280–295 (SS lists `\!` before `\left(` as correct, 291 — contradicting its own ban) | ABS |
| h citations / DOI / never inaccessible | 522–548 | PARA 149–153, 393–402 (adopted 08-24/25) | PARA 342–348 (**no DOI rule**) | PARA 87, 92 |
| i sentence-opener (script) | 295–310 | PARA 308–311 (older; no script) | ABS | ABS |
| j prose grammatical | 291–294 | IDENT 307–308 | ABS | ABS |
| k never "knob" | 460–463 | PARA 313–314 | near-IDENT 296–299 | **CONTRA in practice** ("Damköhler knobs" at 41, 44, 47, 57, 97) |
| l cost register, not time | 492–504 | ABS | ABS | ABS |
| m complete battery + economy lanes | 732–749 | battery only 324–325 | battery only 378–381 | ABS |
| n 12-hat panel / per-hat reports | 606–637, 744–749 | ABS | ABS | ABS |
| o self-reported closure / LINE-ONLY / plateau | 935–947 | PARA 455–475 (same 11-of-13 measurement; no plateau) | ABS | ABS |
| p build-enforced closure, CLOSED.md | 948–960 | ABS (its marker mechanism lives in `review-rounds/README.md`, not CLAUDE.md) | ABS | ABS |
| q seeded-vs-closure contradiction | 961–976 | ABS | ABS | ABS |
| r both directions | 977–993 | half 500–503 ("a sweep reporting zero is the one to distrust") | ABS | ABS |
| s consent gate | 896–906 | ABS | ABS | ABS |
| t four instruments / witness rule | 907–934 | ABS as policy (mentions 462, 482) | ABS | ABS |
| u definition of done | 1004–1065 (6 items) | ABS | PARA 389–411 (3 items) | PARA 97 (golden master) |
| v commit⇒push + trailer | 2665–2672 (`master`; `Anthropic Claude`, no version, "user-decided 2026-09-04") | **CONTRA** 390–392 (`main`; `Claude Opus 4.8`) | **CONTRA** 671–674 (`master`; `Claude Opus 4.8`) | ABS |
| w CI manual-only | 2673–2685 | ABS (though SS:679 names IT as sharing it) | PARA 675–680 | PARA 32 |
| x tables top-level | 830–836 | PARA 350 | ABS | PARA 95 |
| y one notation per concept | 837–850 | PARA 345 | PARA 363 | ABS |
| z no hidden HTML comments | 660–666 | ABS | ABS | ABS |
| aa Literate = rendered page | 782–800 | ABS | ABS | ABS |
| bb verify by building (exit 0) | 801–813 | weak 380–381 | weak 419 | PARA 94 (older wording) |
| cc fix the class | 724–731 | IDENT 327–328 | IDENT 380–381 | PARA 93 |
| dd style / docstrings-vs-comments / Greek α/β | 324–338, 480–491 | IDENT 96–97, 129–133; Greek ABS | IDENT 191–198, 215–218; Greek ABS | PARA 82, 85; ABS |
| ee positional vs keyword | 464–479 | ABS | **CONTRA** 200–213 (smoothing controls are keywords though result-affecting) | ABS |
| ff hostname | 1446, 1481; `~/.claude/CLAUDE.md`:5, 13 | ABS | ABS | ABS |

Doc-edit checklist: PF and CP use Correct/Self-contained/Formatted/Current/**Cited**; IT (334–358) and SS (351–378) replace item 3 with **Notation** and fold argument coverage into Self-contained.

### Paraphrase drift, quoted
1. "knob": PF:460 "an **option** (or *keyword argument*, *setting*, *choice* — the spline order `(n, m)` …)"; SS:296 "an **option** (or, where it reads better, a *keyword argument*, a *setting*, or a post-hoc *choice* — e.g. the bandwidth)"; IT:313 "an *option* / *setting* / *axis* / post-hoc *choice*".
2. Admonitions: PF:221 "Every `!!!` block carries a **custom descriptive title** … never a bare `!!! warning`"; IT:205 "takes a custom title when it carries one load-bearing claim …, and stays a bare `!!! note` when it is a general aside".
3. Silent rule (a): PF:369 "(`gradient` → eight italics, not the word)"; SS:255 "(`xlo` → x·l·o); backtick it, or wrap it in `\texttt{}`"; IT:271 "backtick it, or ``\texttt{}``-wrap it inside a formula".
4. Family links: PF:883 "one catalogue destination, not five — … unless the members are distinct types a reader must CHOOSE between"; SS:313 "2–3 links per family bullet, never five, never one"; IT:188 "(a glossary table is the exception …)".
5. Verify by building: PF:801 "'building' means the full … EXITING 0"; CP:94 "the strict build is the source of truth for broken `@ref`s"; IT:380/SS:419 "Docs build … must be clean".
6. Author truncation: PF:524 "keep enough surnames to disambiguate two works"; IT:151 "the full author list lives only in the `§References` entry"; SS:342 bare rule.

### Rules present elsewhere but not in PF (for completeness)
IT: constructor-first type docstrings (155–164); `# Fields` demoted header; `-> Type` arrow rule, `Returns x.` sentence, display-vs-inline formula rule (201–234); `lint_docstring_shape` + "watch the shape" (236–246); `\mid`, `\varphi` never `\theta`, κ/k/ϰ set; "No invented aliases"; "Order the work: code before docs"; "Belongs-in-PF/SS → raise, don't reimplement" (76–80); the whole `## Known weaknesses — self-guards` (404–504) incl. "when you write a rule down, name what would catch its next violation … A rule and its check belong in the same commit" (498–500). SS: object→query→smoothing→modifiers argument order; estimand-first; estimator-variant blocks; grep-enforced thin-space/braced-group idiom (271–279); fully-qualified `@ref` link table (320–324); every estimator ships a standard error + `check_standard_error` (398–406). CP: 2-space "deliberately not Julia's standard 4"; no subscripts in identifiers; `SKIP_GOLDEN` under `CI`.

### Ordering and provenance
Section order differs: PF puts Documentation policy before Style (and most doc rules inside Style); IT/SS put Style first; IT alone gives the checklist its own `##`. IT stamps every PF import with a date (08-06 TeX idiom; 08-24 ≥3-args, DOI-on-title; 08-25 full inline ref, steer declined, map tighter; decision 87 ← PF decision 82). PF stamps imports from IT (907, 948–949) and cites IT's 11-of-13 measurement (941). SS points at PF five times (227, 266, 330, 339, 679); the memory note records the reverse transfer (PF `b0e4b713` ← SS). CP cites PF (32) and IT (21). SS and CP carry no rule-level dates.

---

## 5. Test-side generic guards

PF `test/`: 35 top-level files + `regressions/` (3 witnesses + README) + `exhaustive/` (17 files, 8,000+ lines) + `gpu/`. IT: 15 files + **131** witnesses in `regressions/` (no README). SS: 25 files + `gpu/`. CP: 7 files, no `test/Project.toml` (deps via root `[extras]`/`[targets]`).

### Matrix

| Guard idea | PF | IT | SS | CP | Verdict |
|---|---|---|---|---|---|
| Aqua `test_all` | `aqua.jl:12–14` (no options) | **absent** (no Aqua dep) | `aqua.jl:7–9` | `aqua.jl:5–10` `persistent_tasks = false` | independent one-liners; CP drifted (option) |
| JET `@test_call target_modules` | `jet.jl:17, 45–68` (21 calls; `PACKAGE_MODULES` names **4 of 8** modules — `public_surface.jl:14–18` names all 8) | absent | `jet.jl:11, 16–67` (44 calls, local `mods` tuple) | absent | same idiom, independent |
| `@alloc_below` macro + `AUDITED_OPS` + `field_threshold = threshold + 4096·nthreads` | `allocations.jl:45–61, 107` | raw `@allocated` ×15 (`memory_audit.jl:700,708,729`, …) | raw ×~4 (`allocations.jl:15–30`) | raw ×2 | macro is PF-only |
| Allocation completeness derived from surface (`inplace_operations()` minus audited minus exemptions; stale-exemption + phantom checks) | `allocations.jl:600–624` | absent | absent | absent | PF only |
| `CountingArray` traffic harness (atomic read/write counters, `get_backend` forward, `Traffic{role,frozen,ideal,holder}`, `audit`) | `pass_audit.jl:57–95, 102–122` | absent | absent | absent | PF only |
| Frozen-cost + ideal + named holder discipline | `pass_audit.jl:87–95, 117–118` (dynamic) | `optimality_audit.jl:68–72,126,133` `struct Holder`; `compute_audit.jl:106,170` (static projection); PF credits IT `pass_audit.jl:16–18` | absent | absent | independent implementations of one idea |
| Regeneration env var | `PASS_AUDIT_PRINT=1` (:52) | `AUDIT_PRINT=1` (`compute_audit.jl:33,244`) | — | — | same protocol, different name |
| Frozen method counts + `detect_ambiguities` + derived per-module baseline | `method_parity.jl:16–17, 58, 277–318`; frozen tables 22–55, 78–270 (190 lines are refreeze history) | absent | absent | absent | PF only |
| Oracle-provenance registry (`:analytic/:independent/:property/:relational/:structural`; fails on unclassified and relational-only; citation checker) | `oracle_registry.jl:11–17, 146–198` | absent | absent | absent | PF only |
| Contract-by-construction battery | — | — | `testcontracts.jl:28–81` (`check_point_estimator`, `check_standard_error`, 18 call sites); pure `testoracles.jl` module | — | SS-only alternative mechanism |
| Ownership-derived public surface (`package_operations()` walking `loaded_modules_array`, not `names`) | `public_surface.jl:27–74` (included by 8 files) | absent | absent | absent | PF only |
| Regression-witness auto-include loop | `runtests.jl:47–52` + `regressions/README.md` (naming `<op>-<symptom>.jl`) | `runtests.jl:27–31` (`replace(splitext(witness)[1], "-" => "_")` vs PF `replace(regression_file[1:end-3], '-' => '_')`); naming `<round>-<hat>-<n>[-symptom].jl` (`bug-hunt.md:221`) | absent | absent | copy with cosmetic drift; naming diverged |
| Exhaustive survey (method-table-derived invocations, universal checks, ledger, per-method coverage ledger, selfcheck) | `exhaustive/*` | absent | absent | absent | PF only |
| Absence gate / peer rejections / context matrix / entry points (typeintersect- and lowered-IR-derived denominators) | `absence_gate.jl:43`, `peer_rejections.jl:45`, `context_matrix.jl:67–97`, `context_entrypoints.jl:131` | absent | absent | absent | PF only |
| Derived display gate (`package_struct_types()` + `has_display` + 7 properties) | `display.jl:36–75` | `display.jl:51–102` — **copy with drift**: adds `!(object isa UnionAll)` clause (65–66), planted-type falsification (100–102), bounds 30/300/900 vs 20/200; header "its decision 82, adopted here as decision 87" | absent | absent | IT's UnionAll fix not back-ported |
| Backend-agnostic GPU suite + thin per-backend entries | `gpu/suite.jl` (944), `rocm/`+`cuda/` (24 each; `adapt` twins) | absent (`memory_audit.jl:313–330` discovers a device inside the CPU suite) | `gpu/suite.jl` (96), `rocm/` only; hand-built device twins (`suite.jl:24–28`), no `device_array_type`; `AMDGPU = "2"` vs PF `"2.5"` | absent | copy with drift |
| Cross-`-t` subprocess bitwise check | `threading.jl:348, 400, 488` | absent | absent | absent | PF only |
| Benchmark-report GFM parse | `results_format.jl:17–43` | absent | absent | absent | PF only |
| Wrapper-module `runtests.jl` | 8–40 | 7–21 | 7–26 | single `@testset`; `SKIP_GOLDEN = haskey(ENV,"CI")` (13) | PF/IT/SS same idiom |
| Mutation audit (decision 52) | **no script** — manual protocol, `docs/ARCHITECTURE.md:2889–2925` | none | none | none | absent everywhere as code |

Instrument scripts under `.claude/commands/` (PF 30 files, IT 41, SS 5, CP 0): same-named files differ substantially — `bug-hunt/witnesses.jl` 72 vs 112 lines (172 changed), `manifest.py` 116 vs 110 (206 changed), `check-consistency/recall.py` 88 vs 110 (PF arms A–C, IT A–D). **The three "zero-coupling" paths PF's CLAUDE.md lists under `bug-hunt/` (`gate.py`, `coverage.py`, `argcov.jl`) do not exist there in either tree** — they live at `audit-changes/gate.py`, `check-consistency/coverage.py`, `check-docs/argcov.jl`.

Test deps: PF `Aqua = "0.8"`, JET **no compat**, `LoweredCodeUtils = "3 - 3.5"`; SS `Aqua = "0.8"`, JET no compat, `LoweredCodeUtils = "0.1 - 3.5"` (same JET-driven bound, different spelling); IT none of Aqua/JET; CP `Aqua = "0.8"` via `[extras]`.

---

## 6. Benchmark-side tooling

**Only PF owns any benchmark script.** IT: no `benchmark/`; zero hits for `BenchmarkTools|@benchmarkable|gcsample|CHAR_SIZES|canary` outside `inspiration/`; what it has instead are the three suite-resident cost audits (`memory_audit.jl` 732, `compute_audit.jl` 391, `optimality_audit.jl` 453 over `audit_ops.jl` 613) — frozen working-set/transform-count ledgers, not timing. SS: `benchmark/Project.toml` (3 lines) + `README.md` (9 lines, "Scaffold stage — not yet populated"); `.gitignore` pre-ignores `benchmark/results/`. CP: nothing.

PF `benchmark/` (3181 lines of tooling; `results/` gitignored; `RESULTS.md` 983 lines + six `baselines/*.json` tracked):

| Piece | File:lines | Engine vs package-specific |
|---|---|---|
| Canary judge | `regress.jl` (224): 12 mechanism canaries at 128³ `Float64` (:78–91); baseline `baselines/$(gethostname())-<cpu-tN|cuda|rocm>.json` (:93–96); `judge(…; time_tolerance = 0.25)` (:199); exit 1 regression / 2 no baseline / 3 selfcheck; CPU inversion alarm threaded ≤ 1.1·serial (:209–221); `--freeze` refreeze-with-reason protocol (:9–11) | engine 1–45, 93–105, 113–224; fixtures/canary table 46–91 |
| Sweep | `characterize.jl` (180): builds one (class,size,type) at a time (:143–172); `CHAR_SIZES/CHAR_TYPES/CHAR_SKIP`; archive tags `commit=,measured=,kernel=,microcode=,governor=,smt=,thp=,threads=` (:106–134); `characterize.sh` (60): `THREADS`, `CPU_TAG`, `GPU_BACKEND` | engine except `include("benchmarks.jl")` |
| gcsample policy | `benchmarks.jl:129–204` `apply_gcsample_policy!(suite; device_used, reclaim)`, constants :76–99 — **duplicated locally in `regress.jl:113–164`** | engine (device hooks injected) |
| Suite builder | `benchmarks.jl:34–53` `build_suite(; array_type, types, sizes, skip, registry)` — fixed dispatch table, one `add_<class>!` line per class; `CLASSES` (:29) duplicated in `report.jl:16` and `triage.jl:79` | package-specific |
| Merge / splice | `merge_parts.jl` (32; hard-coded `t8-part-<N>.json` prefix, forward+reverse verify); `replace_class.jl` (73; backup, bit-identical untouched-row check, restore on failure) | fully generic |
| Report | `report.jl` (211): `label_of` (:21–32), `ROW_ALIASES` (:46–60), vintage line (:66–86), one hard-coded header `println` (:96–134, host/fleet prose), `include("triage.jl")`, `history_section()` shelling `python3 history_regressions.py` (:179–204) | tables/labels/alias generic; header prose + `CLASSES` specific |
| History scan | `history_regressions.py` (114): walks `git log -- benchmark/RESULTS.md`, regime floors `CPU_FLOOR/AMD_FLOOR/NV_FLOOR` dated (:66–70), card-name heuristics `"7900"/"6700"` (:69) | generic except floor dates/card names |
| Tiny-grid gate | `gate.jl` (69): `sizes = (16,)`, `samples = evals = 1`, exit 1 on failure or mutated transfer point set (:55–58, 69) | engine except `point_positions` (:57) |
| Born-slow triage | `triage.jl` (242): thread-flatness (:90–133), declared peers table (:139–152), `TRIAGE_KNOWN` (:43–50), selftest with hard-coded fixture row (:225); **label parser duplicated** from `report.jl` (:196–205, "keep the two in step") | sections generic; tables specific |
| Kernel resources | `kernel_resources.jl` (29) + `_rocm.jl` (15, parses `NumVgprs/ScratchSize/Occupancy`) + `_cuda.jl` (14, "NOT yet run on a CUDA host") | backend files generic |
| Classes | `algebra` 23, `fft` 45, `operators` 29, `convolution` 75, `reductions` 64, `transfer` 86, `storage` 60 (device-only), `threading` 55 (standalone) | package |
| Studies | `study_fiberwise_simd.jl` (114, self-declared deletable), `study_walk_scatter.jl` (28) | one-off |
| GPU envs | `gpu/{cuda,rocm}/runbenchmarks.jl` 47/46 (near-identical); `cuda/Project.toml` pins `CUDA_Compiler_jll = "=0.5.1"` | — |
| README | 81 lines; its `## Layout` (:7–17) omits 12 of the files (`regress`, `characterize`, `gate`, `report`, `triage`, `merge_parts`, `replace_class`, `history_regressions`, `kernel_resources*`, `storage`, `convolution`) — stale | — |

Archives: 21 JSON + 7 backups, `cpu-<cputag>-t<N>.json` / `gpu-<card>.json` plus legacy bare names; BenchmarkTools `save` format, 20–44 MB, date in the `measured=` tag not the filename. Copies of the suite exist only as gitignored `inspiration/` mirrors: IT byte-identical (2026-09-05), CP behind by `reality_projection!` rows / `ROW_ALIASES` / `kernel_resources*` / refrozen Aiporetne baselines, SS a July snapshot (957 lines, `RESULTS.md` "commit 0a5e1f6").

---

## 7. Julia versions and Project.toml conventions

| | PF | IT | SS | CP |
|---|---|---|---|---|
| `[compat] julia` | `"1.12"` | `"1.12"` | **`"1.11"`** | `"1.12"` ("the fleet's") |
| version | 0.1.0 | 0.1.0 (depends on PF `"0.1.0"`) | 0.1.0 | 0.1.0 (depends on SS `"0.1.0"` via `[sources] url = github`) |
| stdlib compat style | `"1.10"` | `"1.11"`, `"1.11.1"` | `"1.10"`/`"1.11"` | `"1"` |
| CI.yml | manual + tags; matrix `{1.12×1t, '1'×4t}` | same | manual + tags; `{**1.11**×1t, '1'×4t}` | manual + tags; `{1.12, '1'}` **no `JULIA_NUM_THREADS`**; needs `GBG_DEPS_TOKEN` |
| docs.yml | on push to `master`; `Pkg.develop` + instantiate | on push to **`main`**; `Pkg.add(url=PF)` + develop; `GBG_DEPS_TOKEN` | `master`; develop | `master`; plain `Pkg.instantiate()` (both deps under `[sources]`); token |
| test deps | `test/Project.toml`: Aqua `"0.8"`, JET (no compat), HDF5 `"0.17"`, `LoweredCodeUtils = "3 - 3.5"`, KA, Adapt, FFTW, Random, Statistics | `test/Project.toml`: HDF5, Logging, PF, Random, Test (**no Aqua/JET**) | `test/Project.toml`: Aqua `"0.8"`, JET, HDF5, `LoweredCodeUtils = "0.1 - 3.5"`, SpecialFunctions | **root `[extras]`/`[targets]`**: Aqua `"0.8"`, Test `"1"` |
| docs deps | Documenter, Literate, pkg (no compat) | Documenter, DocumenterInterLinks (**package not declared**; added at CI time) | Documenter, pkg | Documenter, pkg, SS with `[sources]` |
| resolved Documenter | 1.17.0 | 1.17.0 | 1.17.0 | **1.19.0** |
| other resolved | Literate 2.21.0; JET 0.11.4; Aqua 0.8.16; LCU 3.5.3; BenchmarkTools 1.8.0; KA 0.9.41 (test 0.9.42) | DocumenterInterLinks 1.1.0; Adapt 4.6.1 | JET 0.11.4; Aqua 0.8.16; LCU 3.5.3 | KA 0.9.42; Adapt 4.7.0 |
| Manifest `julia_version` | 1.12.7 | 1.12.7 | **1.12.6** | 1.12.7 |
| root Manifest tracked? | no | **yes** (`.gitignore:5–6` `!/Manifest.toml`, "only place the unregistered GBGPeriodicFields git URL + pinned commit are recorded") | no | no |
| benchmark env | `BenchmarkTools = "1"`, `[sources] path = ".."` | none | Project.toml only, no compat | none |

Host state: `juliaup` on Aiporetne has **only** `release` 1.12.7 installed — SS's 1.11 floor lane (and the memory note "both Julia 1.11 + release installed") cannot currently be run locally here. No package puts a compat bound on Documenter, Literate, JET, or BenchmarkTools' plugins; the only pinned tooling versions are Aqua `0.8`, LoweredCodeUtils ≤ 3.5, and `CUDA_Compiler_jll = "=0.5.1"` in PF's CUDA sub-envs.

---

## Cross-cutting observations (facts, for the design to weigh)

- **Duplication with drift inside PF itself**: gcsample probe (`benchmarks.jl` vs `regress.jl`), archive label parser (`report.jl` vs `triage.jl`), `CLASSES` ×3, two "package modules" lists (`jet.jl:17` vs `public_surface.jl:14–18`), `lint_review_closure`'s `class_surfaces` predicate declared a "twin" of `verify-fixes.js` (and once desynced for a day per `doc-review-checkdocs/CLOSED.md:9–22`).
- **Historic artefacts** (fork-and-drift, not domain): SS's June `lint_inline_math` and July `check-consistency` fork; the trailer text (`Claude Opus 4.8` in IT/SS vs versionless in PF); IT on `main`; `.claude` tracking policies; request files tracked in PF but not IT; the display-gate `UnionAll` fix and regression-loop spelling; SS's GPU suite building twins by hand where PF uses `adapt`; CP's `persistent_tasks = false`; IT's stale `.claude/README.md` tracking claim; PF's stale benchmark README layout list.
- **Necessary differences** (domain or topology): SS's 1.11 floor; IT's tracked root Manifest and PAT-authenticated private dep (same for CP); IT's `main` docs branch; IT `doctest = false`; IT/CP having no benchmark or GPU suite (IT's cost audits are the solver's counterpart); SS's estimand-first rubric and argument-order convention; PF's cost-register rule (a time-free library); the `\mathbf` divergence is *recorded as undispositioned* on IT's side rather than settled.
- **Contradictions a shared policy text would have to resolve**: admonition titles (PF always custom / IT bare `!!! note` allowed); in-place steer sentence (IT declined); positional-vs-keyword (SS keywords result-affecting smoothing controls); `\mathbf` (IT build-bans, PF prescribes `\mathbf{1}`); closure-gate mechanism (PF untracked pile + `CLOSED.md` vs IT tracked marker + `closed:`); shape-ratchet CSV schemas and cap scope; witness file naming; the `verify.js`/`verify-fixes.js` verdict sets (IT INVENTORY.md flags the bug-hunt verdict set as a schema divergence).