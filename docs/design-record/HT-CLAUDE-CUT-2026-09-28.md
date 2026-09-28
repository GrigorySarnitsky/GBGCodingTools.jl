# What GBGHomogeneousTurbulence's `CLAUDE.md` restates of the rulebook — measured 2026-09-28

A reader compared HT's `CLAUDE.md` (505 lines, at HT's head `c016f95`; unchanged at `8c7ab73`) passage by
passage with the rulebook HT loads once wired (GBGCodingTools v2.0.0-rc.32's `.gbg/policy/*.md`), under
HT's config as wiring writes it: no switches, no settings, no declared harness contracts.

Each passage is marked `DUPLICATE` (delete it), `TRIM` (cut what goes, keep what stays), `CONFLICT` (HT's
text says something the rule contradicts: a question for the owner, not for the session) or `kept` (HT's
own). A passage restating one of the four harness contracts is kept while HT has not declared that
contract: until it does, it is HT's only statement of it.

The list is a measurement, not a ruling: HT's session checks each item against the text before acting.
Since the measurement, the owner's rulings settle three conflicts, each in the rule's favour:

- L211–213, `RULE.DOC.ARGS_FORM`: argument lists are an `# Arguments` section, and any keyword means the
  list (ruled 2026-09-28).
- L282–287, `RULE.TEX.LEFTRIGHT`: `\left`/`\right` is banned except in a formula the owner allows by
  name (ruled 2026-09-27). HT's blanket exemptions go; each formula HT wants kept is a question for him.
- L391–393, `RULE.GIT.TRAILER`: the trailer is versionless (ruled 2026-09-08).

Five rule statements changed between v2.0.0-rc.32 and v2.0.0-rc.34, so the items naming them are
re-checked against the rc.34 text before acting: `RULE.CIT.DOI` (a work stating "no DOI" may link its
stable public record), `RULE.DOC.ARGS_FORM`, `RULE.DOC.FIELDS` (a `# Fields` section),
`RULE.DOC.HOME_ORDER` and `RULE.DOC.SIGNATURE_MIRROR` (88 columns, as rendered). They are L147–155,
L156–165, L209–210, L211–213 and L214–217.

Totals, in lines: DUPLICATE 8, TRIM 154, CONFLICT 64 (13 passages), kept 279.

### Lines 1–94: preamble, Modules and wiring, Core invariants
- kept: L1–94. Note: L85–88 "The hot loop (`step!`) is in-place and allocation-free AT FIELD SCALE…" is KEEP. It binds only if HT declares RULE.TEST.ALLOC_ZERO (`allocation_completeness`). Once HT declares it, the "at field scale" qualifier is looser than the rule, which requires every `!` operator to be allocation-free, and would become a CONFLICT.

### Lines 95–134: Style
- L130–134 TRIM RULE.DOC.ONE_HOME — "**Docstrings vs comments.** Prefer docstrings…" — goes: "One docstring per operation, on the bare binding"; stays: `#` only for non-intuitive why, `function f end` / bare imported name, comments stay Unicode.
- kept: L95–129

### Lines 136–321: Documentation policy — physical-meaning first
- L138–140 TRIM RULE.DOC.TWO_TIER — "The organizing spec for every user-facing docstring…" — goes: "a module docstring is a map; a function or type docstring is a home"; stays: the pointer to `docs/src/notation.md` as the reader's copy.
- L143–146 TRIM RULE.DOC.TWO_TIER, RULE.DOC.MODULE_MAP — "**Module docstring = map.** What the module is…" — goes: map = linked one-liner per operation, no formulas; stays: "no Mori–Zwanzig framing or architecture rationale — those live in `ARCHITECTURE.md`". (Inside HT this is at odds with L233–235, "no essay before the list".)
- L147–155 CONFLICT RULE.DOC.HOME_ORDER, RULE.CIT.FULL_INLINE, RULE.CIT.DOI — "**Function docstring = home**, in this order…" — (i) HT's order puts caveats at (4), before the formula (5) and the citation (6). The rule's order is identity, when-to-use, arguments, formula, citation, links, caveats, then `# References`, then `# Fields`. (ii) HT puts the FULL reference inline in the prose. The rule wants author–year in the prose and the full reference in a `# References` section. (iii) HT exempts `Phenomenology`'s compact labelled `[doi:10.…]` link with no title. RULE.CIT.DOI wants the DOI on the title, and HT has no Switch for it. HT's own parts stay whatever the owner decides: `doi_crosscheck.py`, percent-encoding `()` `<>`, the rule that every §References entry has a citing docstring, and a citation that names the method may open the identity sentence. The author-truncation sentence restates RULE.CIT.STYLE.
- L156–165 TRIM RULE.DOC.RETURNS, RULE.DOC.HOME_ORDER — "**Type docstring = home, constructor-first**…" — goes: lead with the constructor, `# Fields` last; stays: name the plain positional constructor only where a reader would call it, with HT's list of types and the "claim about who builds the value" reasoning.
- L167–174 TRIM RULE.DOC.LEADING_IDENTITY — "**Physical meaning first — even for spectral-representation operations.**…" — goes: physical meaning with explicit formula first, then derived form, "where no clean form exists, say so briefly"; stays: the `dissipation` reference example, the integrating-factor example, "every diagnostic states the physical quantity before the numerical method".
- L176–183 CONFLICT RULE.DOC.STEER — "**One concept, one home.** One docstring per operation…" — HT declines the steer sentence (owner-ruled 2026-08-25, with the `vorticity_physical!` reason), but HT's `.gbg/config.jl` has no Switch on RULE.DOC.STEER, so the rule binds as written. L176–180 by itself duplicates RULE.DOC.ONE_HOME and RULE.DOC.VARIANT_PAIR.
- L185–194 CONFLICT RULE.DOC.XLINK — "**Cross-referencing — a link earns its place.**…" — HT links only where a reader would jump and does not link `Base` except the `@extref` set. RULE.DOC.XLINK links every name another module owns at its first mention. Also a TRIM of RULE.DOC.LINKS: goes (1) "at most once per docstring — its first genuine mention"; stays (2)–(4), meaning never link the own binding, arguments or fields, one destination per family, the at-home test, and the `@extref` backend-type exception.
- L196–200 TRIM RULE.DOC.NO_DEAD_REFS — "**No dead references on the user-facing surface.**…" — goes: complete at the REPL, no section number; stays: thrown error messages, decision-log entries, repo paths, "a cross-reference never carries a fact the reader needs".
- L206–208 CONFLICT RULE.DOC.ADMONITION_TITLE — "An **admonition takes a custom title** when it carries one load-bearing claim…" — HT's practice is `load-bearing only`, but it has not set `admonition_titles`, so the default `always` binds. HT's own addition stays: "the title is plain text".
- L209–210 DUPLICATE RULE.DOC.HOME_ORDER, RULE.DOC.ADMONITION_TITLE — "A **caveat admonition is the last substantive block**…"
- L211–213 CONFLICT RULE.DOC.ARGS_FORM — "A type gets a bulleted **`# Arguments`** section when its keywords are independent…" — HT decides by independence, not count, and folds keywords into prose. The rule says any keyword means the bulleted form.
- L214–217 TRIM RULE.DOC.ARGS_FORM — "A **function** docstring documenting three or more arguments…" — goes: the three-or-more / any-keyword / never-mix rule; stays: the marker phrase "The arguments are:".
- L226–228 CONFLICT RULE.DOC.RETURNS — "A **`Returns x.` sentence** is required of any in-place mutator…" — HT exempts every pure function. The rule exempts only a function whose identity sentence names the result. HT's own part stays: a named-tuple return states its shape.
- L229–232 TRIM RULE.DOC.RETURNS — "A signature carries a **`-> Type` arrow** only where…" — goes: arrow only where fixed by the signature, arrow and sentence never both; stays: the reduction returning the field's element type says so in prose, and the `-> arg` mutator idiom.
- L233–235 TRIM RULE.DOC.MODULE_MAP — "A **module map is identity → contents list → optional trailing remark**…" — goes: the order; stays: "HT's four-role maps stay list-first (owner-ratified 2026-08-25)". The PF comparison is stale. RULE.DOC.TWO_TIER's why still says "scope, place, invariants — then a linked one-liner".
- L237–247 TRIM RULE.DOC.SHAPE — "**Watch the shape, not only the sentence.**…" — goes: the growth-by-accretion principle and the cap on paragraphs and admonitions; stays: the rule to rewrite whole after three or more rounds of patches, `lint_docstring_shape()`, `docs/docstring_shape.csv`, `DOCSTRING_SHAPE_BASELINE=1`, and the 2026-08-19 instances.
- L249–253 TRIM RULE.DOC.API_GROUPING — "**API pages are logically grouped.**…" — goes: "each object appears once"; stays: explicit `@docs`, never `@autodocs`, the `f`/`f!` pair together with `!` first, homogeneous blocks, `checkdocs = :exports`.
- L255–263 CONFLICT RULE.TEX.MATHBB, RULE.TEX.MATHBF — "**Notation** (glossary: `docs/src/notation.md`…" — "never upright `\mathbf`" forbids the identity `\mathbf{1}`, which RULE.TEX.MATHBB requires and RULE.TEX.MATHBF grants. Also a TRIM of RULE.TEX.PARTIAL, RULE.TEX.IMAGINARY and RULE.DOC.ONE_NOTATION: goes `\partial_{x_i}` never `\partial_i`, upright `\mathrm{i}`, the notation page as single reference; stays: bold italic vectors, the `\boldsymbol{\kappa}`/`\kappa`/`k`/`\varkappa` set, `\varphi` never `\theta`, `\mathbb P` / `\mathcal P`, Re set through `\nu`.
- L265–269 CONFLICT RULE.TEX.ONE_SPAN — "**Bind each code object to its symbol on first mention**…" — HT always merges the name into one `\texttt{dissipation} \equiv \varepsilon` span. RULE.TEX.ONE_SPAN (and RULE.TEX.CODE_IN_MATH's why) keeps a name that only names what the code denotes as a code span joined by a connective, as in `atol` (``\varepsilon``). HT's own part stays: bind each code object to its symbol on first mention.
- L271–273 DUPLICATE RULE.TEX.CODE_IN_MATH — "**Silent-rendering micro-rules**… (a) A code identifier never sits inside…"
- L273–274 CONFLICT RULE.TEX.ONE_SPAN — "(b) A formula is one LaTeX span — never split…" — this is the older absolute wording. The rule now allows code span + connective where the formula does not continue into the name.
- L274–277 TRIM RULE.TEX.INLINE_ONE_LINE — "(c) **Inline math stays on ONE source line**…" — goes: the rule; stays: `docs/make.jl`'s `lint_inline_math()`.
- L277–279 TRIM RULE.TEX.NO_HSCROLL — "(d) No horizontal scroll…" — goes: the rule, `aligned`/`gathered`, no auto-wrap; stays: the hanging indent under the first argument, and `split`.
- L279–282 CONFLICT RULE.TEX.CODE_SPAN_JULIA — "(e) A backtick span holds only **well-formed Julia**…" — this is the retired wording ("only well-formed Julia", reworded 2026-09-26). The rule now admits shell, TOML, paths and LaTeX source. HT also bans a backticked `−`, which the rule does not list.
- L282–287 CONFLICT RULE.TEX.LEFTRIGHT — "(f) **TeX idiom** (adopted from PF 2026-08-06…" — HT exempts the `\left\{ \dots \right.` system idiom and the arrow commands, but `leftright_allowed` is unset (empty). Also a TRIM of RULE.TEX.FRAC_BRACED, RULE.TEX.BOLDSYMBOL_BRACED, RULE.TEX.MATHBB and RULE.TEX.SPACING: goes braced arguments, no `\mathbb` on a digit, `\,` only before the differential, no `\;`/`\:`; stays: "a conditional bar is `\mid`".
- L289–294 TRIM RULE.DOC.VERIFIED — "**Correctness is verified, not asserted.**…" — goes: verify every formula, normalization and "X is just Y" by expansion; stays: HT's normalizations list and the two examples (the derivative-skewness bug, `C = \tfrac47\sqrt{15/2}`).
- L296–306 TRIM RULE.DOC.VERIFIED — "**Category/type errors are their own class**…" — goes: the general class and "type every object from the code"; stays: HT's physics list (field vs representation, "never 'spectral field'", `\varepsilon` vs a dissipation field, `k` vs `E(\kappa)`, `\mathcal E` vs `\nu`, `\mathbb P` vs `\mathcal P`, spectral density vs energy, the dimensionally incomplete law).
- L308–312 TRIM RULE.DOC.GRAMMAR, RULE.DOC.SENTENCE_OPENER — "**Prose is grammatical.**…" — goes: subject and verb, "concise means few words", no lowercase identifier opener, the exemptions; stays: the named fragment kinds (noun-stacks, `label:` tags, comma splices) and the `dissipation` example.
- L314–321 TRIM RULE.DOC.REGISTER — "**Neutral reference register.**…" — goes: "never a 'knob'"; stays: the "axis / post-hoc choice" vocabulary, neutral tone on `@testset` names, and the no-invented-aliases ruling (*front door*).
- kept: L136–137, L141–142, L166, L175, L184, L195, L201–205, L218–225, L236, L248, L254, L264, L270, L288, L295, L307, L313

### Lines 322–363: Doc-edit checklist
- L325–329 TRIM RULE.DOC.BATTERY, RULE.DOC.CLASS_SWEEP, RULE.DOC.VERIFIED — "The battery the `/check-docs` command…" — goes: every surface, positive procedure, "a flagged instance is a sample of a class"; stays: the pointer to `.claude/commands/check-docs.md` and the list of HT's surfaces.
- L335–339 TRIM RULE.DOC.VERIFIED — "1. **Correct** — every formula…" — goes: the formula, relation, quantifier and category-error check; stays: "quote the decisive line", and the diagnostic must match the quantity it claims.
- L340–345 TRIM RULE.DOC.SELF_CONTAINED, RULE.DOC.ARGCOV, RULE.DOC.TERMS_DEFINED — "2. **Self-contained** — every symbol bound…" — goes: symbol bound at first use, every argument documented, term of art defined, cold read; stays: the `domain` / `buffers` instance.
- L346–349 TRIM RULE.DOC.ONE_NOTATION — "3. **Notation** — one symbol per concept…" — goes: one symbol per concept and one concept per symbol; stays: the house glyph list and the naming convention (both HT's own, restating L109–116 and L255–263).
- L350–354 TRIM RULE.TEX.RENDERED_MATH, RULE.TEX.CODE_IN_MATH, RULE.TEX.ONE_SPAN, RULE.TEX.INLINE_ONE_LINE, RULE.DOC.TABLE_TOP_LEVEL, RULE.TEX.NO_HSCROLL — "4. **Formatted (bidirectional)**…" — goes: those restatements; stays: "every code identifier backticked, never bare" and the 88-column figure. The "no `\mathbf`" clause carries the same identity CONFLICT (RULE.TEX.MATHBB) as L255–263.
- L355–359 TRIM RULE.TEST.DEFINITION_OF_DONE, RULE.DOC.CURRENT — "5. **Current & complete**…" — goes: no stale future / deferred / none-exist claims; stays: a subset-naming summary is stale, checked against the current exports and method set.
- L361–363 DUPLICATE RULE.DOC.VARIANT_PAIR, RULE.DOC.ONE_HOME — "Plus, **across variant pairs**…"
- kept: L322–324, L330–334, L360

### Lines 364–404: Verification workflow, Working agreements
- L390 DUPLICATE RULE.GIT.NO_SHIMS — "The API is not frozen; do not build backward-compatibility shims."
- L391–393 CONFLICT RULE.GIT.TRAILER — "**Commit ⇒ push, on `master`.**…" — the trailer "Co-Authored-By: Claude Opus 4.8" names a model version. The rule requires the versionless "Co-Authored-By: Anthropic Claude". The rest (commit ⇒ push on `master`, never `[skip ci]`) duplicates RULE.GIT.PUSH, RULE.GIT.BRANCH and RULE.GIT.TRAILER.
- kept: L364–389, L394–404. Note: L368–380 "The suite includes three audits over the shared op model…" is KEEP. The frozen ledgers refrozen in the same commit citing the decision, and the named holder for residual distance, bind only if HT declares RULE.TEST.PASS_AUDIT (`traffic_completeness`). The memory audit's completeness over field-scale arrays binds only if HT declares RULE.TEST.ALLOC_ZERO (`allocation_completeness`). Until then this is HT's only statement of them.

### Lines 405–505: Known weaknesses — self-guards
- L456–476 TRIM RULE.DOC.CLASS_SWEEP — "**Fixing the instance, not the class**…" — goes: the rule sentence at L471–473, "after any class fix, enumerate the surfaces from the finding's own text — not from memory — and re-run…"; stays: the 11-of-13 measurement, the three recurring shapes (a)–(c), and the 2026-08-17 instances.
- L499–505 TRIM RULE.TEST.MUTATION, RULE.TEST.MISSING_IS_FAILING — "The rule: **when you write a rule down, name what would catch its next violation**…" — goes: "a sweep reporting zero is the one to distrust — falsify it against a fixture carrying a known positive"; stays: a rule and its check in the same commit, and the stated-denominator preference ("CLEAN over 98 bindings").
- kept: L405–455, L477–498

Line counts: a line in overlapping passages is counted once, under its most severe mark (CONFLICT, then TRIM, then DUPLICATE).

TOTAL: 8, 154, 64, 279
