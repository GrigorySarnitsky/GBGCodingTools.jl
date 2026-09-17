# Findings — 2026-09-09-check-docs-01

The work list, by id. Fix the CLASS, not the line; a seeded finding (marked) is never fixed in the corpus.

## lane rationale

### `2026-09-09-check-docs-01/rationale#1` [major/high] consolidate.py is described as present/pending across three sections but was already deleted

- docs/ARCHITECTURE.md:135 — "there is no Python (the one transitional exception is D8's `consolidate.py`)."
- docs/ARCHITECTURE.md:448-455 — "The one transitional Python file is `consolidate.py`… is BYTE-COMPARED against it… the Python is deleted in the same commit that passes it… This is the riskiest single port in the plan and is scheduled with the fallback in hand."
- docs/ARCHITECTURE.md:956-958 — repository-layout entry listing `consolidate.py` under `src/CLI/` as a file that still exists
- src/CLI/Consolidate.jl:2-4 — "ACCEPTANCE (1.6) PASSED 2026-09-09: byte-equal output to the Python on a real PF build (18 pages) and a real IT build (22 pages), all four manuscripts; the Python was deleted in that commit."

D1, D8 and the §3 repository-layout tree present `consolidate.py` as a currently-existing transitional Python file with an open, risky, future port ('is scheduled with the fallback in hand', 'is deleted in the same commit that passes it' — future tense). The actual source's own comment in src/CLI/Consolidate.jl records the acceptance test as PASSED on 2026-09-09 and the Python file already deleted in that commit; no .py file exists anywhere in the repository outside .gbg/. The document's own Revision 9 note (line 2498, dated 2026-09-09, same day) even refers to '1.6 acceptance' as an already-measured past event, so the main body (D1/D8/§3) is stale relative to both the code and the document's own revision history. This is exactly the stale-future/deferred claim RULE.DOC.CURRENT forbids ('No stale future, deferred or none-exist claims').

_hint:_ Rewrite D1 (line 135), D8 (lines 448-455) and the §3 file-tree entry (lines 956-958) in past tense: note that the Gumbo/AbstractTrees port of the consolidator passed its byte-comparison acceptance test on 2026-09-09 and consolidate.py was deleted in that commit, so the tool now has zero Python anywhere (not 'one transitional exception'); remove the `consolidate.py` row from the §3 tree.

### `2026-09-09-check-docs-01/rationale#2` [minor/high] D9's 'minimal' dependency enumeration omits Pkg and Random, both real hard dependencies

- docs/ARCHITECTURE.md:559-563 — "The tool declares its own `[deps]`/`[compat]` minimally: the stdlibs `TOML`, `SHA`… `Dates` and `Test`, plus `JSON3`… and `Gumbo` + `AbstractTrees`… both hard dependencies"
- Project.toml:6-15 — `[deps]` lists `Pkg` and `Random` in addition to the six named in the architecture text
- src/CLI/Self.jl:59 — `entry = get(Pkg.dependencies(), PKG_UUID, nothing)`
- src/CLI/Passes.jl:80 — `nonce = bytes2hex(rand(RandomDevice(), UInt8, 16))`

The paragraph enumerates the package's dependency set as if exhaustive ('minimally: the stdlibs TOML, SHA…, Dates and Test, plus JSON3… and Gumbo + AbstractTrees'), but Project.toml also declares `Pkg` and `Random` as hard dependencies, and both are load-bearing: `Pkg.dependencies()` is the mechanism behind `PIN.SELF`/`PIN.TREESHA`/`self verify` that this very document describes at length in D3 and §7.3, and `Random.RandomDevice()` generates the 128-bit pass nonce central to D10's staleness mechanism. A reader following RULE.DOC.CURRENT's bar ('a summary that names only a subset of what the code now provides is stale even if literally true') would be misled about the tool's actual stdlib footprint.

_hint:_ Add `Pkg` (self-verify / pin checks) and `Random` (pass nonce generation) to the dependency list in D9's paragraph.

## lane pages

### `2026-09-09-check-docs-01/pages#1` [major/high] argcov's own docstring never documents its `cfg` or `exempt` parameters in the form its own scan requires

- src/Reflection.jl:154-166 — rendered on docs/src/api/Reflection.md via `GBGCodingTools.Reflection.argcov`
- quote: "argcov(cfg; exempt = (hit -> false)) -> (hits, population, skipped)" … "`exempt(hit)` is the ledger's `[exemption.match]` predicate"

`Reflection.argcov` is the engine behind RULE.DOC.ARGCOV/SCAN.ARGCOV: every signature parameter must appear in the docstring body as a bare code span `` `p` `` or a span carrying its default `` `p = ...` ``. Its own docstring (Reflection.jl:154-165, shown on Reflection.md) never mentions `cfg` as a code span anywhere, and mentions `exempt` only as `` `exempt(hit)` `` — a call expression, which is neither the bare-name nor the with-default form the code's own regex accepts (`Regex("`" * q * "`")` or `Regex("`" * q * "\\s*=[^`]*`")`). I replicated the exact regex logic from Reflection.jl against the literal docstring text and both `cfg` and `exempt` come back undocumented. `argcov`'s own arg-count/keyword combination (1 positional + 1 keyword) does not qualify for the ARGS_THRESHOLD prose exemption either, since that exemption requires `isempty(kw)`, and `exempt` is a keyword — so this docstring is a real trigger, not a legitimate skip. The rendered deviations.md for this package lists no declared exemptions ("(none)"), so this is not a ledger-covered deviation.

_hint:_ Add an explicit arguments clause naming `cfg` (the validated config) and `exempt` as a bare span or `exempt = ...`-style span, e.g. "The arguments are `cfg`, the validated config, and `exempt`, the ledger's per-trigger predicate (default always-false)."

### `2026-09-09-check-docs-01/pages#2` [minor/high] "hats" (a declared package term of art) used on the landing page with no definition or link

- docs/src/index.md:17 — "A consumer carries a `.gbg/` directory: one config file, one exemption ledger, its domain hats, its"

"hat" is one of this package's own declared terms of art — `src/CLI/Init.jl:128` writes `"terms" => tool ? ["consumer", "instrument", "round", "lane", "hat", "anchor", "gate", "pin", "managed file", "ledger"]`, matching the lane brief's list verbatim. "hats" is used exactly once across the whole audited surface, at index.md:17 ("its domain hats"), with no clause explaining what a hat is and no `@ref` link to any page that does (the glossary entry lives only in the rendered policy, `.gbg/policy/glossary.md`, which is not part of the docs site). A cold reader of the landing page has no way to learn what a "domain hat" is.

_hint:_ Add a short clause ("its domain hats — the check-consistency panel's personas —") or link to Rounds/Install/a glossary page on first use.

### `2026-09-09-check-docs-01/pages#3` [minor/high] "lane" (a declared package term of art) used throughout the rounds guide with no definition

- docs/src/guide/rounds.md:7 — "The CLI writes its marker `ROUND.toml`; the lane agents write their lane files"
- docs/src/guide/rounds.md:17-19, 36 — "3. **Lanes** — the printed `Workflow` call; each lane writes `findings/NN-<lane>.json` first."

"lane" is likewise one of the package's declared terms of art (`src/CLI/Init.jl:128`). It is used seven times across rounds.md (lines 7, 16, 17, 18, 19, 36) purely operationally ("lane files", "lane 00-scans", "a DEAD lane") but is never given a defining clause or an `@ref` link stating what a lane conceptually is (per the glossary, "one agent of an instrument … a surface or territory"). A reader coming to this page cold (its stated purpose is to explain what a round is) learns the file-naming mechanics of lanes but not the concept itself.

_hint:_ Add one clause at first use, e.g. "the lane agents — one per surface or territory the instrument covers — write their lane files".

## lane src

### `2026-09-09-check-docs-01/src#1` [major/high] TreeHash.tree_hash never omits empty directories (isempty on a Bool)

- src/TreeHash.jl:47: `isempty(_nonempty(path, skip)) && continue`
- contradicts: src/TreeHash.jl:35-39 docstring: "computed as `git write-tree` would over every file below it: ... empty directories omitted."

`_nonempty(path, skip)` returns a `Bool` (true when the subdirectory holds at least one file below it). The guard wraps that Bool in `isempty(...)`, but `isempty` on a scalar/Bool is always `false` in Julia (verified in a REPL: `isempty(true) == false` and `isempty(false) == false`), so `isempty(_nonempty(path, skip))` is always `false` and the `continue` that is meant to skip an empty directory never fires. Every subdirectory — including a genuinely empty one — is therefore always pushed onto `entries` and given a `40000` tree entry computed by recursing into it (which, for a truly empty directory, yields git's well-known empty-tree hash as the child id). Real `git write-tree` omits empty directories entirely, so whenever the tree being hashed contains an empty directory, `TreeHash.tree_hash` computes a different id than `git write-tree`/`git hash-object -t tree` would for the same tree — directly contradicting both the function's own docstring ("empty directories omitted") and its purpose of reproducing git's object ids for `gbg self verify` (PIN.SELF, PIN.TREESHA) and `gbg selftest --pinned`.

_hint:_ Invert the guard so it actually skips empty directories, e.g. `_nonempty(path, skip) || continue` (or `!_nonempty(path, skip) && continue`).

### `2026-09-09-check-docs-01/src#2` [major/high] rescan_alive can crash with StringIndexError on non-ASCII scan text

- src/CLI/Passes.jl:167: `occursin(strip(last(split(h.text, ": "))[1:min(end, 40)]), loc)`

`last(split(h.text, ": "))[1:min(end, 40)]` slices the string by a raw byte index (40) rather than a character-safe cut. When that string contains a multi-byte UTF-8 character (Greek letters, math glyphs such as ≤ ∈ ∇ ⟨⟩, or an em dash — all routine in this package's scan hit text, e.g. formula-in-backticks or code-in-math hits) whose bytes straddle position 40, Julia raises a `StringIndexError` instead of returning a substring (reproduced directly: `s[1:min(end,40)]` on a string with Greek text throws `StringIndexError` for several byte offsets). `rescan_alive` is called from `Passes.grade` for every `lane == "scans"` finding, so grading a round whose banked scan-hit text happens to break at such a byte offset crashes `gbg round grade` (exit 3) instead of completing the tally. Every other place in this codebase that truncates a string to N characters uses the Unicode-safe `first(s, n)` idiom (e.g. `Reflection.jl`'s `first(h.signature, 70)`, `Witnesses.jl`'s `first(strip(text), 600)`, `Scan.jl`'s `first(sig, 70)`) — this is the one spot that manually indexes by byte instead.

_hint:_ Replace `last(split(h.text, ": "))[1:min(end, 40)]` with `first(last(split(h.text, ": ")), 40)`, matching the Unicode-safe truncation idiom used everywhere else in the codebase.

## lane ext

### `2026-09-09-check-docs-01/ext#1` [minor/high] `Documenter` appears bare (unbacktick­ed) twice in the module docstring, backticked once

- ext/GBGCodingToolsDocumenterExt.jl:4 — "The Documenter extension of `GBGCodingTools`: it defines the body of"
- ext/GBGCodingToolsDocumenterExt.jl:6 — "so no shim call ever loads Documenter."

RULE.DOC.FORMATTED requires every code identifier backticked, never bare. `Documenter` is the name of the extension's trigger package (used as a real identifier at line 10, `using GBGCodingTools, Documenter`), and the docstring itself gets it right in the middle of the same paragraph — line 5, "It loads only where `Documenter` is" — but leaves it bare at the start of the paragraph (line 4, "The Documenter extension") and at the end (line 6, "loads Documenter."). The inconsistency within one three-line docstring makes it an easy, low-risk fix rather than a stylistic judgment call.

_hint:_ Backtick both bare occurrences: "The `Documenter` extension of `GBGCodingTools`" and "so no shim call ever loads `Documenter`."

### `2026-09-09-check-docs-01/ext#2` [nit/medium] `check`'s `verb` argument is never bound as its own code span (ARGCOV run from the signature)

- ext/GBGCodingToolsDocumenterExt.jl:14-19 — `check(verb::AbstractString, code::Integer)` / "Turns a verb's exit code into a build failure: returns `nothing` when `code == 0`, else throws `ErrorException(\"gbg <verb> returned <code>\")`."

RULE.DOC.ARGCOV requires every signature argument, enumerated from the signature, to be documented in the body as a plain span or a span carrying its default. `code` is bound this way (the literal `code == 0` span). `verb` is not: it is referenced only as the common noun "a verb" in prose and inside the `<verb>` placeholder of the error-message template, never as a `` `verb` `` span naming the actual parameter — a mechanical sweep run from the signature would not find `verb` bound.

_hint:_ Add a `` `verb` `` span, e.g. "turns `verb`'s exit code into a build failure", so the sweep finds both parameters bound by name.

## lane built-html

### `2026-09-09-check-docs-01/built-html#1` [major/high] Double-backtick escapes meant to show literal backticks render as broken KaTeX math

- src/Reflection.jl:159 — "carrying its default (`` `n` `` or `` `n = 2` ``)"
- docs/build/api/Reflection.html — rendered <span>$`n`$</span> and <span>$`n = 2`$</span>
- docs/ARCHITECTURE.md:2193 — "rendered LaTeX in ``` `` ``` / ```` ```math ````"
- docs/ARCHITECTURE.md:2269 — "PF `\]\(@ref[^)]*\)\``"
- docs/ARCHITECTURE.md:2272 — "PF `^\s*[-*]\s+\*\*\`` (ledger `RULE.DOC.ARG_BULLET`\u2026)"
- docs/ARCHITECTURE.md:2273 — "list-leader continuation inside an open `` `` `` span"
- docs/ARCHITECTURE.md:2285 — "`` `[^`]*[\u2264\u2265\u2260\u2208\u2209\u2207\u0394\u27e8\u27e9\u2016\u221a\u00d7\u22c5][^`]*` ``"
- docs/ARCHITECTURE.md:2293 — "beside a `` `` `` span, either order"
- docs/build/architecture.html — same row renders <span>$```math$</span>, <code>\]\(@ref[^)]*\)\</code> followed by a bare stray backtick, two split <code> spans plus literal "RULE.DOC.ARG_BULLET` silences\u2026", <span>$$</span> `` (twice), and <span>$`[^`]*[\u2264\u2026]*`$</span>

This build's Documenter/KaTeX setup treats a code span delimited by exactly two backticks as inline math (per the rendered policy's own RULE.TEX.RENDERED_MATH: "Inline math is a double-backtick span"). Seven places in the source text try to show a literal backtick, a backtick-delimited regex, or the project's own ``/```math fence syntax as a worked example, using the classic Markdown trick of a wider or padded backtick delimiter around inner backticks. Because the outer delimiter still measures to a 2-backtick run (or, for SCAN.REF_ABUT_CODE/SCAN.ARG_BULLET_BOLD, a single backtick abutting a literal inner backtick that prematurely closes the span), Documenter hands the content to KaTeX as a formula; a backtick is not valid LaTeX, so KaTeX's fallback leaves the raw, undelimited math source ($`n`$, $```math$, bare $$ with a stray `` left over, split <code> tags plus dangling backtick text, or the whole regex wrapped in $\u2026$) sitting in the rendered prose. None of this is visible from the Markdown/docstring source alone — reading src/Reflection.jl or docs/ARCHITECTURE.md, the intent reads as plain code formatting; the defect exists only in what Documenter actually produced. Three of the seven instances are, ironically, ARCHITECTURE.md's own worked examples of the very math-notation rule they sit inside (RENDERED_MATH, INLINE_MATH_SPLIT, FORMULA_IN_BACKTICKS, ABUTTING_SPANS rows of the scan catalogue), and none of it is caught by SCAN.HTML_RENDERED_MARKUP, which only scans built HTML for surviving `*`/`__` emphasis markers, not stray `$`.

_hint:_ For each location, stop trying to nest backticks inside a 2-backtick-fenced span: either drop to a single plain backtick around a backtick-free literal (`n`, `n = 2`), or describe the delimiter in prose ("a double-backtick span") instead of showing it literally, or use a fenced code block for the regex examples. Rebuild the docs and grep docs/build for `<span>$` containing a backtick to confirm the class is gone.

### `2026-09-09-check-docs-01/built-html#2` [major/high] Four live CLI verbs (bump, fleet, release, selftest) are documented nowhere on the built site

- src/CLI/Bump.jl:65 — "VERBS[\"bump\"] = cmd_bump" (docstring at src/CLI/Bump.jl:4)
- src/CLI/Fleet.jl:151 — "VERBS[\"fleet\"] = cmd_fleet" (docstrings at src/CLI/Fleet.jl:4,11,22,26,37,46,98,108)
- src/CLI/Release.jl:74 — "VERBS[\"release\"] = cmd_release" (docstring at src/CLI/Release.jl:4)
- src/CLI/Selftest.jl:42 — "VERBS[\"selftest\"] = cmd_selftest" (docstring at src/CLI/Selftest.jl:4)
- docs/build/guide/verbs.html — opens "the table is closed, and every verb below is rendered from its own docstring" yet lists none of these four
- docs/src/guide/verbs.md, docs/src/api/CLI.md — no `@docs` block anywhere names Bump, Fleet, Release or Selftest (grep for the four words is empty)
- docs/build/architecture.html §3 — the only site-wide mention is the bare filenames "Doctor.jl Sync.jl Init.jl Fleet.jl Bump.jl Release.jl Install.jl", not a documented verb

All four are real, currently-registered entries of the closed VERBS table (confirmed by grepping every `VERBS["..."] = ` assignment across src/CLI/*.jl: 21 verbs registered, only these four absent from every `@docs` block on the site) and each already carries a complete docstring in source. guide/verbs.html's own opening sentence claims to be the closed, drift-proof table of every verb "rendered from its own docstring so the page cannot drift from the code" — exactly the claim this omission falsifies, since the gap is a missing `@docs` entry, not a hand-copy that drifted. A reader who only reads the built docs cannot discover that `gbg bump`, `gbg fleet`, `gbg release` or `gbg selftest` exist at all. This is visible only by cross-checking the built site's page-by-page @docs coverage against the live VERBS registry in src/ — no single page (nor the source alone) shows the gap.

_hint:_ Add `GBGCodingTools.cmd_bump` (or `bump`), `GBGCodingTools.Fleet` and its verb function, `GBGCodingTools.cmd_release` and `GBGCodingTools.cmd_selftest` to an `@docs` block in docs/src/guide/verbs.md (matching the existing "Machine and self" / "Consumer setup" grouping), rebuild, and confirm all four bindings now appear under docs/build.

### `2026-09-09-check-docs-01/built-html#3` [minor/medium] The module map on the home page has no entry for the scan engine

- docs/build/index.html — the `GBGCodingTools` module docstring lists main, Config, makedocs, TestHarness/Reflection/Witnesses, TreeHash, HtmlWalker, and "The CLI files under src/CLI/" as the whole map
- src/Scan.jl:19,41,67,133,385,477,498 — struct Hit, struct ScanResult, register_scan!, prose_lines, scan_docs, scan_html, write_public_surface are all defined here, at top level, not under src/CLI/
- docs/build/api/CLI.html — Hit, ScanResult, register_scan!, prose_lines, consolidate and write_public_surface are documented under an "Engines" heading with no link from the module map

RULE.DOC.MODULE_MAP requires the module docstring to list one linked one-liner per operation family; RULE.DOC.CURRENT treats a summary naming only a subset of what the code now provides as stale even where every sentence is literally true. `src/Scan.jl` is the deterministic text/HTML scan engine (`gbg scan docs`/`gbg scan html`, the `Hit` and `ScanResult` types, `register_scan!`, `prose_lines`, `write_public_surface`) — a distinct operation family with its own catalogue (`catalog/scans.toml`) and its own two CLI verbs — but it is neither under `src/CLI/` (so the map's one catch-all CLI bullet does not cover it) nor named by any other bullet. The engine does have a home elsewhere on the site (CLI.html, verbs.html), so this is a map-completeness gap rather than a missing-documentation gap.

_hint:_ Add one bullet to the `GBGCodingTools` module docstring in src/GBGCodingTools.jl naming the scan engine, e.g. "`Hit`, `ScanResult`, [`scan_docs`](@ref), [`scan_html`](@ref) — the deterministic text/HTML scan engine over `catalog/scans.toml`", then rebuild.

## lane cold-reader

### `2026-09-09-check-docs-01/cold-reader#1` [major/high] 'consumer' and 'pin' are used, undefined, in the very first sentences a REPL reader sees

- src/GBGCodingTools.jl:5-6: "...at one version pinned by every consumer. A consumer holds data; the tool holds behaviour; the only thing connecting them is a pin."

`?GBGCodingTools` is the first thing a cold reader of this package types, and its module docstring — the map RULE.DOC.MODULE_MAP calls for — opens with two of the package's own terms of art, 'consumer' and 'pin', used as bare nouns with no gloss and no @ref. Both are defined only in the external policy prose (glossary.md, ARCHITECTURE.md §0), which the substrate rule of this lane withholds and which is not part of the docstring surface a `?name` session ever loads. I grepped every docstring in src/ and ext/ for a defining sentence for 'consumer' ("a package that pins the tool", "the four GBG packages", etc.) and found none: the word is used in dozens of docstrings (DocLints.jl, TestHarness.jl, Config.jl, Git.jl, Ledger.jl, Sync.jl, Doctor.jl, Init.jl...) but never once explained. A reader who has not read ARCHITECTURE.md has no way to know a 'consumer' is one of the four sibling GBG packages (or the tool testing itself) rather than, say, an end user of the reviewed package's API.

_hint:_ Add one clause to the GBGCodingTools module docstring that states what a consumer is (e.g. "— a consumer is one of the sibling GBG Julia packages, or the tool testing itself —") and, separately, state what a pin is in plain terms before using it as a bare noun; RULE.DOC.TERMS_DEFINED requires the definition at first use, not a later page.

### `2026-09-09-check-docs-01/cold-reader#2` [major/high] TestHarness's 'element-traffic ledger' collides with the package's own defined term 'Ledger'

- src/TestHarness.jl:11: "the element-traffic ledger ([`TestHarness.CountingArray`](@ref), [`TestHarness.Traffic`](@ref), [`TestHarness.audit`](@ref))"
- src/TestHarness.jl:108: "# ─── element-traffic ledger"
- src/TestHarness.jl:183: "One row of the traffic ledger." (the `audit` docstring)

'Ledger' is one of the package's ten declared terms of art (config: package.terms), with one fixed meaning stated in Ledger.jl's own module docstring: 'the reader of a consumer's exemption ledger `.gbg/exemptions.toml`'. TestHarness.jl reuses the ordinary English word 'ledger' for a completely different mechanism — the CountingArray/Traffic/audit read-write bookkeeping — in its module docstring, a section header and the `audit` docstring itself. A cold reader who has already formed 'ledger = the exemptions file' from Ledger.jl (or from the package's own terms list) hits 'the element-traffic ledger' in TestHarness and must silently discard that referent and build a second, unrelated one — exactly the failure mode the lane brief calls out: an ordinary word carrying a package-specific meaning is overloaded with a second, conflicting package-specific meaning.

_hint:_ Rename the TestHarness concept (e.g. 'the traffic audit' or 'the traffic table', mirroring `traffic_completeness`/`AUDITED_TRAFFIC_OPS`) so 'ledger' stays bound to one referent across the whole package, per RULE.DOC.ONE_NOTATION's 'one notation per concept' applied to prose terms.

### `2026-09-09-check-docs-01/cold-reader#3` [major/high] 'S-class' and 'class G' file-taxonomy letters are used in docstrings but defined nowhere in them

- src/CLI/Init.jl:11 (module docstring): "`init` never renders the G files: that is `gbg sync`"
- src/CLI/Sync.jl:189 (`plan` docstring): "Every generated-managed file (class G) for a consumer"
- src/CLI/Init.jl:450 (`migrate_baselines` docstring): "the textual converter from the consumer's existing test files to the three S-class TOMLs `TestHarness` reads"

The package apparently classifies its managed/generated files by letter (at least G and S appear), a taxonomy that lives in ARCHITECTURE.md — withheld from a cold read — but never in any exported docstring. 'class G' is used once with a one-word gloss ('generated-managed'), which a reader could just about hold onto; but 'S-class' in Init.jl's `migrate_baselines` docstring is used with zero gloss at all, and by then the reader has no earlier anchor for the letter scheme (I grepped every docstring in src/ and ext/ for 'class [A-Z]' or '[A-Z]-class' and found only these three lines, none of which explains the scheme). A competent reader new to the package cannot recover what distinguishes an S-class file from a G-class one, or how many other letters exist.

_hint:_ Either drop the bare letter and say what the class means in the sentence itself ('the three frozen TOML baselines' instead of 'the three S-class TOMLs'), or add one sentence to a central docstring (e.g. Sync's or Init's module doc) naming the classes that appear anywhere in the exported surface.

### `2026-09-09-check-docs-01/cold-reader#4` [minor/high] 'substrate' is used as a field name across three files before it is ever explained as a concept

- src/CLI/Recall.jl:9 (module docstring, first docstring use): "[`Recall.suspect_hats`](@ref) names the hats with two or more seeds on their substrate and zero matches"
- src/CLI/Preflight.jl:167-169 (`resolve_hats`): "Each hat carries `key`, `substrate`, `needs`, `anchor`... and `not_applicable` when its substrate cannot exist here (`html` needs with no built site, `git` with no repository, `rulebook` with no rulebook sections)."

'Substrate' denotes which manuscript view a hat is shown (full manuscript, site-only manuscript, or the built HTML), but that is never stated as a definition anywhere — it must be reverse-engineered from the enumerated example values ('full', 'siteonly', 'html', 'scans' as seen in Passes.jl and Init.jl) scattered across Recall.jl, Preflight.jl, Rounds.jl and Passes.jl. Recall.jl's module docstring — the first docstring to use the word — gives no gloss at all ('their substrate' reads as though the concept is already known). This is exactly an ordinary English word (substrate = the material something sits on) repurposed for a specific, closed-vocabulary field whose values are never listed in one place.

_hint:_ State once, at Preflight.resolve_hats (the docstring with the richest context) or in the Preflight module docstring, that 'substrate' names which manuscript/build view a hat is shown (full | siteonly | html | scans), then let later uses rely on the @ref.

### `2026-09-09-check-docs-01/cold-reader#5` [minor/high] 'round' is used as load-bearing vocabulary in the first files a reader loads, well before any docstring characterizes it

- src/Witnesses.jl:179 (`run`'s docstring, 7th file in the module's own include order): "`dir` — the directory of `.jl` witnesses (the round's `witnesses/`, or `test/regressions/escalated/`)"
- src/CLI/Self.jl:49 (`self_verify`'s docstring): "an edited pinned tree is never allowed to grade a round"

'Round' is one of the package's ten declared terms of art. It is used as settled vocabulary in Witnesses.jl (bare 'the round's witnesses/') and again in Self.jl, both of which load well before RoundFiles.jl — the first module whose docstring gives round any structure at all ('round_dirs', 'ROUND.toml', the :open/:closed/:abandoned states) — and even RoundFiles.jl never states the one-line definition the glossary gives ('one run of an instrument, recorded as a tracked directory under .gbg/rounds/'); it only shows the reader mechanics. A reader proceeding through the package in its own include/documentation order meets 'round' as an assumed concept several files before encountering enough structure to construct a definition, and never meets an explicit one.

_hint:_ Add a one-clause definition of 'round' to the Witnesses module docstring (its first use) or promote RoundFiles's module docstring earlier / add an explicit definitional sentence to it rather than only operational description.

### `2026-09-09-check-docs-01/cold-reader#6` [minor/medium] 'anchor' (a hat/lane running at full strength) is never defined in any docstring

- src/CLI/Preflight.jl:167 (`resolve_hats`): "Each hat carries `key`, `substrate`, `needs`, `anchor` (a `domain_hats` entry may anchor any key)"
- src/CLI/Preflight.jl:229 (`resolve_hunt_lanes`): "the catalogue's two free lanes (anchored)"
- src/CLI/Doctor.jl:281: `push!(errs, "no anchored hat (at least one hat runs at full strength)")` — a runtime error string, not a docstring, so a `?name` reader never sees it

'Anchor' is one of the package's ten declared terms of art, glossed in policy as 'a hat or lane that runs at full strength instead of the economy model'. In the docstring surface it appears only as an opaque boolean field name ('anchor' in a Dict, 'anchored' as a parenthetical) with no sentence anywhere stating what being anchored means. The one place the concept is spelled out in English ('at least one hat runs at full strength') is a doctor check's failure message in Doctor.jl, which lives in executable code, not a docstring — invisible to `?Preflight.resolve_hats` or any other `?name` lookup.

_hint:_ State the meaning of `anchor` once in resolve_hats's or resolve_roster's docstring (e.g. "`anchor` — whether this hat/lane runs at full strength rather than the economy model") since that is where the field is first introduced to a reader.

### `2026-09-09-check-docs-01/cold-reader#7` [minor/medium] 'managed file' (a defined package term) is used pervasively via 'managed' but never stated as a concept

- src/CLI/Sync.jl:8-12 (module docstring): "Renders and checks the managed footprint of a consumer: the skill stubs, ... and the sidecar `.gbg/managed.json`."

'Managed file' is one of the package's own glossary terms ('a file the tool renders into a consumer and hash-checks thereafter; edited only by `gbg sync`'). Sync.jl's module docstring and every function under it (`plan`, `status`, `sync`, `ManagedFile`, `Entry`) use 'managed' as an adjective dozens of times, and a reader can infer a good deal from the mechanics shown (STALE/MODIFIED/OK states, hash comparison), but no docstring anywhere states the concept in one sentence the way the glossary does — a reader must assemble the definition themselves from `classify`, `classify_block` and the `Entry` struct's field docs rather than being told directly.

_hint:_ Add one defining clause to the Sync module docstring, e.g. "a managed file is one this tool renders and hash-checks; a consumer never hand-edits it", ahead of the mechanics.

### `2026-09-09-check-docs-01/cold-reader#8` [minor/medium] the act/state verdict channels, and the 'class_surfaces' field that demotes one, are used before (and largely without) explanation

- src/CLI/Demote.jl:6-7 (`demote`'s docstring, the field's only appearance anywhere in the source): "an act verdict `HONORED` whose `class_surfaces` is empty becomes `LINE-ONLY`"
- src/CLI/Passes.jl:121: "Launch BOTH verifiers exactly as printed (the act verifier sees the diff; the state verifier is blind)"

Demote.jl's `demote` — an early file in the closure-verification group — is the first and only docstring anywhere to use 'act verdict' and 'class_surfaces'; neither is glossed there. 'act' versus 'state' as the two verification channels only gets any contrasting explanation four files later, in Passes.jl's `pass_open` ('the act verifier sees the diff; the state verifier is blind'), and even that never says what the act/state SPLIT is for (checking whether a claimed fix landed, versus whether the underlying defect is now absent). `class_surfaces` — the field the whole `demote` rule turns on — appears nowhere else in the entire source tree (grepped), so a reader has no way to learn what it is meant to hold beyond 'a list that, when empty, demotes the verdict'.

_hint:_ Expand `demote`'s docstring with one clause on what 'act' means (as opposed to 'state') and what class_surfaces records (the surfaces the finding's own text names as swept, per RULE.DOC.CLASS_SWEEP), since this is the field's only documented occurrence.

## lane operational-claims

### `2026-09-09-check-docs-01/operational-claims#1` [major/high] TreeHash.tree_hash does not actually omit empty directories, contradicting its own docstring

- src/TreeHash.jl:38-39: "entries sorted by git's rule ... empty directories omitted."
- src/TreeHash.jl:47: `isempty(_nonempty(path, skip)) && continue`

The docstring of `tree_hash` states "empty directories omitted" and that the function "reproduce[s] the object ids `git hash-object` and `git write-tree` would give". `_nonempty(path, skip)` returns a `Bool` (true/false), not a collection, and in Julia `isempty(::Bool)` is ALWAYS `false` (a scalar is a length-1 iterator) — verified: `julia -e 'println(isempty(true), " ", isempty(false))'` prints `false false`. So `isempty(_nonempty(path, skip)) && continue` NEVER triggers `continue`, and a genuinely empty subdirectory is always pushed into `entries` (as a `40000` tree entry hashing to git's well-known empty-tree id), never skipped. I verified this end-to-end: running the actual `tree_hash` body over a directory holding one empty subdirectory `emptysub` produced a root tree id of `7c334583827af7801cfd13c7d26236b81e34ce34` that INCLUDES an entry for `emptysub`, whereas real `git init && git add -A && git write-tree` on the identical directory gives `4b825dc642cb6eb9a060e54bf8d69288fbee4904` (git's canonical empty tree, since git tracks no empty directories at all). The function's actual behavior therefore directly contradicts both the "empty directories omitted" claim and the "reproduces what `git write-tree` would give" claim whenever the hashed tree contains any recursively-empty directory — a state that can occur in the tool's own consumer trees, e.g. `test/regressions/` right after `gbg init` but before `gbg sync` seeds its README, or an empty round scratch directory. Since `PIN.SELF`/`PIN.TREESHA`/`gbg self verify` and `TreeHash.tree_hash(dir)` in `Preflight.stamps` rely on this function matching git's own tree ids, this can produce a silently wrong tree hash rather than the documented one.

_hint:_ The intended check is "skip a directory that is empty", i.e. `_nonempty(path, skip) || continue` (skip when NOT nonempty), not `isempty(_nonempty(path, skip))`. Fix the condition, add a witness with a genuinely empty subdirectory compared against real `git write-tree`, and re-verify PIN.SELF/PIN.TREESHA against a tree containing one.

### `2026-09-09-check-docs-01/operational-claims#2` [minor/high] Witnesses.run_one can classify a witness :blocked even though it also failed, contradicting "was never seen to fail"

- src/Witnesses.jl:32-33: ":blocked` (the file declares `# blocked: <reason>` and errored) ..." (WitnessResult docstring)
- src/Witnesses.jl:145: "or `:blocked` (it errored, was never seen to fail, and carries a `# blocked: <reason>` header)"
- src/Witnesses.jl:165-168: `if e > 0; blocked === nothing || return WitnessResult(name, :blocked, p, f, e, blocked); ... end`

`run_one`'s docstring and `WitnessResult`'s docstring both state that `:blocked` means the witness "errored, was never seen to fail" — i.e. implying `fails == 0`. But the code's `if e > 0 ... blocked === nothing || return WitnessResult(name, :blocked, p, f, e, blocked)` branch returns `:blocked` purely from `e > 0` (an errored `@test`) and a present `# blocked:` header, without checking `f == 0`. I verified this by constructing a witness file with a `# blocked: …` header whose body contains both `@test 1 == 2` (a genuine failing assertion) and `@test error("boom")` (an errored assertion) in the same `@testset`; running the actual WRAPPER script that `run_one` uses produced `GBG_WITNESS pass=0 fail=1 error=1` — i.e. `f=1` and `e=1` simultaneously — which `run_one`'s logic classifies as `:blocked` (carrying the real fail count `f=1` in the `WitnessResult`, but reported to the operator only as BLOCKED with the header's reason, not as a failure). This means a witness that both encountered an unrelated error AND asserted a real, currently-true defect can be filed away as BLOCKED and never surfaces as the FAIL evidence `RULE.INST.WITNESS` requires, contradicting the documented "was never seen to fail" characterization of the BLOCKED state.

_hint:_ Require `f == 0` before returning `:blocked` in the `e > 0` branch (e.g. `f == 0 && blocked !== nothing && return WitnessResult(...,:blocked,...)`), so a witness that is also observed to fail is reported as `:fail`/`:broken` rather than silently absorbed into BLOCKED.

