# [The rules GBGCodingTools is held to](@id gbg-rules)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

Generated at build time from the rule values in GBGCodingTools vdev. Each rule carries its own check and the examples that show the check matches it, so this
text and the program that enforces it cannot disagree. A rule's id is stable and is what a
finding, a switch and a report all name.

## Documentation and API — `RULE.DOC.*`, `RULE.API.*`

What a docstring and an API page contain, in what order and in what shape. 42 rules, written from the rule values themselves,
so a rule reworded here was reworded in the program that checks it.

#### [`RULE.API.POSITIONAL`](@id RULE.API.POSITIONAL)
A result-affecting argument is positional; a performance hint or a builder cost/accuracy tunable is a keyword; exceptions are recorded.

In an operation, every argument that affects the result is positional, defaults included; an argument that cannot change the result is a keyword. An exception is a ledger deviation with its reason.

Decided by an agent, because this needs meaning.

#### [`RULE.DOC.ADMONITION_TITLE`](@id RULE.DOC.ADMONITION_TITLE)
Every !!! block carries a custom descriptive title (docs.admonition_titles: always, or load-bearing only).

For this package the rule is {{docs.admonition_titles}}: either every `!!!` block carries a custom descriptive title, or a block carrying one load-bearing claim does while a general aside may stay a …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.DOC.AI_BANNER`](@id RULE.DOC.AI_BANNER)
A rationale page and a rendered Literate example carry the provenance banner, verbatim; a script that is never rendered is not a page and carries none.

A banner reworded in one package is a banner a reader learns to skim past in all of them.

Decided by a program.
This package may set `banner_pages`; unset, it is `String[]`.

#### [`RULE.DOC.ALIASING_BULLET`](@id RULE.DOC.ALIASING_BULLET)
An operation-specific aliasing statement lives in the destination bullet; the package-wide guarantee lives in the module docstring.

The package-wide guarantee lives in the module docstring and is not repeated per operation; an operation states it for itself only when it has an operation-specific reason, or when its contract is …

Decided by an agent, because this needs meaning.

#### [`RULE.DOC.API_GROUPING`](@id RULE.DOC.API_GROUPING)
One docstring has one home on the built site, and a Base function the package extends is public.

Two homes for one docstring is two things to keep true, and the second teaches a reader nothing.

Decided by a program.

#### [`RULE.DOC.ARGCOV`](@id RULE.DOC.ARGCOV)
Every argument in a docstring's signature, positional and keyword, is documented in its body.

A reader passing an argument the docstring never mentions has to read the source to learn what it does.

Decided by a program.

#### [`RULE.DOC.ARGS_FORM`](@id RULE.DOC.ARGS_FORM)
Three or more arguments, or any keyword, use the bulleted form, led by the marker phrase and a colon; fewer are bound in running prose; the two are never mixed.

A reader looking for one argument of many needs a list; a reader of a two-argument call needs a sentence.

Decided by a program.

#### [`RULE.DOC.ARG_BULLET`](@id RULE.DOC.ARG_BULLET)
An argument or field bullet names its argument in a plain code span, never a bold one.

Bold marks emphasis; a name set in bold reads as a heading over the paragraph rather than as the argument.

Decided by a program.

#### [`RULE.DOC.BATTERY`](@id RULE.DOC.BATTERY)
'Check the docs' means the complete battery over every surface, never one check or one file.

When asked to check, review or audit the documentation in any words, run the full matrix — every check across every surface — and report it; do not run one check, sweep one file, and stop.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.DOC.BUILD_VERIFY`](@id RULE.DOC.BUILD_VERIFY)
A doc edit is verified by the full docs build exiting 0, never by a diff, a lint subset or a log grep.

A lint run standalone cannot see a dangling reference, and grepping a log for error text passes a build that died at load. After editing a Literate example, regenerate it and read the output.

Decided by nothing yet. Nothing checks it: the rulebook does not check it: harness:makedocs enforces it inside a package's own test suite

#### [`RULE.DOC.CLASS_SWEEP`](@id RULE.DOC.CLASS_SWEEP)
A flagged instance is a sample of a class: sweep every surface for the class and fix all in one pass.

Fixing only the pointed-at line and waiting to be handed the next instance is the failure this rule exists to stop. After a class fix, enumerate the surfaces from the finding's own text, not from …

Decided by an agent, because this needs meaning.

#### [`RULE.DOC.COORD_FREE`](@id RULE.DOC.COORD_FREE)
Maps and pairings are stated intrinsically; matrix/flattening machinery is confined to the formalization doc.

Component notation for a genuine fiber algebra is fine; the rule targets flattening a structured space to a bare vector. Where a basis form is needed to mirror the code, state the basis and the …

Decided by an agent, because this needs meaning.

#### [`RULE.DOC.COVERAGE_BASES`](@id RULE.DOC.COVERAGE_BASES)
A measure reduction documents every base it supports.

A measure reduction over a grid and the same reduction over a point set are both stated where the operation is documented.

Decided by an agent, because this needs meaning.

#### [`RULE.DOC.CURRENT`](@id RULE.DOC.CURRENT)
No stale claim: a rule cited by id names a rule that exists, and a retired phrasing is not used.

A citation of something renamed or removed reads exactly like one that resolves, which is why it survives.

Decided by a program.

#### [`RULE.DOC.FIELDS`](@id RULE.DOC.FIELDS)
A type with named fields documents them under "The fields are", one bullet per field: every bullet a real field, and every field a bullet.

A field list that has drifted is worse than none: it names what does not exist and hides what does.

Decided by a program.

#### [`RULE.DOC.GRAMMAR`](@id RULE.DOC.GRAMMAR)
Every sentence has a subject and a verb; concise means few words, not missing verbs.

Concise means few words, not missing verbs — compact prose that still reads as sentences aloud.

Decided by an agent, because this needs meaning.

#### [`RULE.DOC.HOME_ORDER`](@id RULE.DOC.HOME_ORDER)
A function docstring is ordered: identity, when-to-use, arguments, one formula, citation, links, caveats, then `# References`, then `# Fields` last; internals, jargon and rationale are excluded.

In full: (1) a plain one-sentence identity in the user's terms; (2) when to use it, versus the alternatives; (3) each argument (positional and keyword) and its effect; (4) one formula if a clean one …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.DOC.INTERNAL_API`](@id RULE.DOC.INTERNAL_API)
An API page puts its internal section last, holds no empty block of collected docstrings, and is never indexed.

Internals in the middle of the public surface, and an index on a hand-grouped page, both make a reader work around the page.

Decided by a program.

#### [`RULE.DOC.LEADING_IDENTITY`](@id RULE.DOC.LEADING_IDENTITY)
Item (1) is a plain one-sentence identity, physical-meaning first or estimand first (rubric.leading_identity).

For this package the identity leads with {{rubric.leading_identity}}: an operation computed in a derived representation still states what it does to the real object first — with the explicit …

Decided by an agent, because this needs meaning.

#### [`RULE.DOC.LINKS`](@id RULE.DOC.LINKS)
Cross-referencing is discriminating: a target is linked at most once in one docstring, at its first genuine mention.

A second link to the same target is invisible in the rendered text and tells the reader nothing new.

Decided by a program.

#### [`RULE.DOC.LINK_UNIFORMITY`](@id RULE.DOC.LINK_UNIFORMITY)
In one run of names, either every name is linked or none is.

A list where one name links and the next does not reads as though the difference meant something.

Decided by a program.

#### [`RULE.DOC.LITERATE`](@id RULE.DOC.LITERATE)
A Literate example is a rendered page: full-line # comments are prose, their math is LaTeX, control-flow-internal comments use ##.

A full-line comment inside a control-flow block splits the code fence, so reserve full-line `# ` for narrative prose at statement boundaries. An underscored identifier in that prose is backticked, …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.DOC.MODULE_MAP`](@id RULE.DOC.MODULE_MAP)
A module docstring lists one linked one-liner per operation family and no formula.

Its order is identity, then the contents list, then an optional trailing remark.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.DOC.NO_DEAD_REFS`](@id RULE.DOC.NO_DEAD_REFS)
A docstring or error message cites no section number and no inaccessible source; it reads complete at the REPL.

At the REPL there are no links: a section number cannot be followed, and it is renumbered besides.

Decided by a program.

#### [`RULE.DOC.ONE_HOME`](@id RULE.DOC.ONE_HOME)
One concept, one home: one docstring per operation on the bare binding; the ! form owns the formula and is listed first; every other variant is a thin wrapper that @ref-links the home and carries no second formula.

Per-scheme or per-representation specifics live in the scheme's or the representation's own docstring, linked. Across an `f`/`f!` pair the in-place `!` form is the home — it owns the formula and the …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.DOC.ONE_NOTATION`](@id RULE.DOC.ONE_NOTATION)
One notation per concept and one concept per notation; a local use yields to a package-wide glyph.

Before introducing a symbol, check it is not a synonym for one already in use, and check the section for the glyph and confirm it is free. When an edit introduces a symbol, retire the old one.

Decided by an agent, because this needs derivation.

#### [`RULE.DOC.REF_ABUT`](@id RULE.DOC.REF_ABUT)
A cross-reference never abuts a second code span; the whole call is the link text.

The two render as adjacent monospace chips with a seam, as though the name had been cut in half.

Decided by a program.

#### [`RULE.DOC.REGISTER`](@id RULE.DOC.REGISTER)
A tunable is an option, a setting or a keyword argument, never a `knob` or a `tweak`.

The house register is plain and exact; `knob` is neither, and reads as though the value did not matter.

Decided by a program.

#### [`RULE.DOC.RETURNS`](@id RULE.DOC.RETURNS)
A type docstring leads with its constructor; a '-> Type' arrow or a 'Returns x.' sentence states the result where the identity sentence does not.

A mutator whose signature carries no arrow says what it returns in a sentence before any caveat; a signature carries an arrow only where the return type is fixed by the signature; arrow and sentence …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.DOC.SELF_CONTAINED`](@id RULE.DOC.SELF_CONTAINED)
A rationale doc reads top to bottom without another file: every symbol is bound in plain language at first use.

Later uses may be bare; universally standard mathematics may stand unglossed. A decision-log entry browsed on its own meets the same bar.

Decided by an agent, because this needs reading order.

#### [`RULE.DOC.SENTENCE_OPENER`](@id RULE.DOC.SENTENCE_OPENER)
A sentence opens with a capitalised ordinary word, never a lowercase identifier or a formula; bullets, comments, headings and fenced code are exempt.

At a full stop a reader cannot tell a new sentence beginning with a lowercase name from the old one running on.

Decided by a program.

#### [`RULE.DOC.SHAPE`](@id RULE.DOC.SHAPE)
A paragraph of prose stays inside the house cap, an admonition count stays inside its own, and prose that was here before the cap may shrink but never grow.

Prose grows by accretion: each addition is small, nobody rewrites, and the paragraph nobody can read was never written in one sitting.

Decided by a program.

#### [`RULE.DOC.SIBLING_LINK`](@id RULE.DOC.SIBLING_LINK)
The first mention of a sibling package links to that package's site; later mentions are bare.

A reader meeting the name for the first time must be able to reach it, and a fourth link teaches nothing.

Decided by a program.
This package may set `sibling_sites`; unset, it is `["GBGCodingTools" => "https://grigorysarnitsky.github.io/GBGCodingTools.jl/", "GBGPeriodicFields" => "https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/", "GBGHomogeneousTurbulence" => "https://grigorysarnitsky.github.io/GBGHomogeneousTurbulence.jl/", "GBGStreamingStatistics" => "https://grigorysarnitsky.github.io/GBGStreamingStatistics.jl/", "GBGCloudPhysics" => "https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/"]`.

#### [`RULE.DOC.SIGNATURE_FIDELITY`](@id RULE.DOC.SIGNATURE_FIDELITY)
The signature a docstring displays and the methods the module defines agree, argument for argument.

A displayed signature is what a reader calls; one the method table has moved past is a call that fails.

Decided by a program.

#### [`RULE.DOC.SIGNATURE_MIRROR`](@id RULE.DOC.SIGNATURE_MIRROR)
A docstring's signature block fits the house column and repeats only as much of the method as a reader needs.

A signature wider than the column wraps in the rendered page and in every terminal that shows it.

Decided by a program.

#### [`RULE.DOC.STEER`](@id RULE.DOC.STEER)
Every ! form with an allocating sibling carries the verbatim in-place steer sentence, naming its own destination argument.

The sentence is the template below — a template, not a link: `destination` is replaced by the argument the signature actually has and `f` by the allocating sibling's own name, so the `@ref` resolves …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.DOC.TABLE_TOP_LEVEL`](@id RULE.DOC.TABLE_TOP_LEVEL)
A Markdown table is top-level, never indented inside a list item.

Markdown reads an indented block as code, so an indented table renders as the pipes and dashes themselves.

Decided by a program.

#### [`RULE.DOC.TERMS_DEFINED`](@id RULE.DOC.TERMS_DEFINED)
A term of art is defined in a clause or @ref-linked on first use; the acceptance test is the cold read.

A docstring can bind every symbol and still be unreadable to someone who has not read the module, because its terms of art are nouns, not symbols; parse it with the module's context withheld, and a …

Decided by an agent, because this needs meaning.

#### [`RULE.DOC.TWO_TIER`](@id RULE.DOC.TWO_TIER)
A module docstring is a map (linked one-liners, no formulas); a function docstring is a home.

The map states what the module is, its scope and place in the architecture, and its invariants — then a linked one-liner per operation family, and no formulas; every formula lives in the operation's …

Decided by an agent, because this needs reading order.

#### [`RULE.DOC.VARIANT_PAIR`](@id RULE.DOC.VARIANT_PAIR)
Across an f/f! or getter/setter pair the defining math appears once; the wrapper carries no display formula (the review unit is the variant set).

Typed twice, the math drifts — one member writing a partial one way and its twin another — and a within-string check cannot see it; a lane that groups each operation's generics and diffs them can.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.DOC.VERIFIED`](@id RULE.DOC.VERIFIED)
Every formula, normalization, adjoint relation and cross-scheme equivalence is verified by expansion against the code, never asserted.

A plausible 'X is just Y' is a false claim until the expansion matches. Run this as a positive verification — enumerate every formula, constant, relation and quantifier and verify each — not as a …

Decided by an agent, because this needs meaning.

#### [`RULE.DOC.XLINK`](@id RULE.DOC.XLINK)
A name another module owns is linked at its first mention in a docstring, qualified so the link resolves.

A reader meeting a name from elsewhere has nowhere to go: the docstring in front of him does not define it.

Decided by a program.



## LaTeX idiom — `RULE.TEX.*`

What renders, and how mathematics is written so that it renders the same way everywhere. 18 rules, written from the rule values themselves,
so a rule reworded here was reworded in the program that checks it.

#### [`RULE.TEX.BOLDSYMBOL_BRACED`](@id RULE.TEX.BOLDSYMBOL_BRACED)
A bold symbol braces its argument.

Unbraced, it bolds the next character alone and leaves the rest of the name upright.

Decided by a program.

#### [`RULE.TEX.CODE_IN_MATH`](@id RULE.TEX.CODE_IN_MATH)
A code identifier never sits inside a math span; inside a formula it is written \texttt{…}.

The renderer sets a run of letters in a math span as a product of italic single letters, not as a name. That remedy is for a name taking part in a formula which says more than the name itself: where the formula only names what the code denotes, the name stays a code span and a connective joins the two (`RULE.TEX.ONE_SPAN`).

Decided by a program.

#### [`RULE.TEX.CODE_SPAN_JULIA`](@id RULE.TEX.CODE_SPAN_JULIA)
A backtick span holds only well-formed Julia, never code-looking math.

A half-open interval, an inequality, a product, a lone `≤` or `·` glyph is LaTeX; the real operators `×`, `⋅` and `≈` backticked are code and stay.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.TEX.FRAC_BRACED`](@id RULE.TEX.FRAC_BRACED)
Both arguments of a fraction are braced.

An unbraced fraction takes one character as its numerator and silently drops the rest.

Decided by a program.

#### [`RULE.TEX.GREEK_AB`](@id RULE.TEX.GREEK_AB)
The accumulation scalars are Unicode α/β everywhere; the two named ASCII holdouts stay.

A hand-written operation spelling them `alpha`/`beta` is drift; a flag naming the α/β variant and an external window-shape `beta` in an English-register block are the recorded exceptions.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.TEX.IMAGINARY`](@id RULE.TEX.IMAGINARY)
The imaginary unit is upright \mathrm{i}; i, j, k are indices.

Never a bare italic `i`, never `\imath` or `\mathbb{i}`; the differential is likewise upright, `\,\mathrm{d}x`.

Decided by an agent, because this needs derivation.

#### [`RULE.TEX.INLINE_ONE_LINE`](@id RULE.TEX.INLINE_ONE_LINE)
An inline math span opens and closes on one line, never across a list or blockquote marker.

A marker inside an open span lands in the formula, and the prose after it renders as mathematics.

Decided by a program.

#### [`RULE.TEX.LEFTRIGHT`](@id RULE.TEX.LEFTRIGHT)
A sized delimiter names what it sizes: \left( pairs with \right), and neither stands alone.

An unpaired sizing command is a LaTeX error, and the whole formula fails to render.

Decided by a program.

#### [`RULE.TEX.MATHBB`](@id RULE.TEX.MATHBB)
A blackboard-bold digit is not a set; the identity is written \mathbb{1} only where it means one.

A blackboard digit renders as an outline numeral, which means nothing to a reader of mathematics.

Decided by a program.

#### [`RULE.TEX.MATHBF`](@id RULE.TEX.MATHBF)
Bold is admitted only for the strings a package lists, plus the identity, which every package is granted.

Bold means one thing in one package and another in the next; unlisted, it is a reader's guess.

Decided by a program.
This package may set `mathbf_allowed`; unset, it is `String[]`.

#### [`RULE.TEX.NO_HSCROLL`](@id RULE.TEX.NO_HSCROLL)
No horizontal scroll: hand-wrap long signatures and display formulas with aligned/gathered.

Neither a rendered code block nor display math auto-wraps; inline math reflows and is exempt. Never pack several equations on one line behind `\quad`.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.TEX.ONE_SPAN`](@id RULE.TEX.ONE_SPAN)
A code span and a math span are never set against each other where the formula continues into or out of the name: where it says more than the name — a definition, or a symbol and then its definition — the name goes inside it as \texttt{…}, and where it only names what the code denotes, a connective joins the two. A formula finished at the edge the name sits on is not continued by it and is left as it is.

Abutting spans render as two disjoint runs at different sizes, leaving the reader to guess whether the second continues the first, qualifies it, or defines it. Apposition says which: `atol` (``\varepsilon``) keeps the name styled as code — clickable, and the same as every other name on the page — while `\texttt{atol}` is the math renderer's monospace, and a link wrapped round the whole formula makes its every operator a link to the name.

Decided by a program.

#### [`RULE.TEX.PARTIAL`](@id RULE.TEX.PARTIAL)
A partial derivative names its index as a symbol, not as a bare letter subscript.

A bare index reads as a variable named i rather than as the direction differentiated in.

Decided by a program.

#### [`RULE.TEX.RENDERED_MARKUP`](@id RULE.TEX.RENDERED_MARKUP)
No markup shows on the built page as literal characters.

Asterisks meant to set emphasis, shown as asterisks, are the mark of prose nobody read after building.

Decided by a program.

#### [`RULE.TEX.RENDERED_MATH`](@id RULE.TEX.RENDERED_MATH)
Mathematics is written in a double-backtick span: never between dollar signs, and never inside a code span.

Dollars render as literal text and a code span renders as monospace; neither comes out as mathematics.

Decided by a program.

#### [`RULE.TEX.RENDERED_MATH_SITE`](@id RULE.TEX.RENDERED_MATH_SITE)
On the built page, every math span has rendered: none still shows its own markup.

A span that renders as its own source is a formula the reader never sees, and the source looks right.

Decided by a program.

#### [`RULE.TEX.SPACING`](@id RULE.TEX.SPACING)
Spacing inside a formula is the renderer's: no thin space, no medium or thick space, no negative thin space before a sized delimiter, and none of them doubled.

Hand spacing is tuned to one renderer at one font size and is wrong in every other setting.

Decided by a program.

#### [`RULE.TEX.SWALLOWED_ESCAPE`](@id RULE.TEX.SWALLOWED_ESCAPE)
Inside a Julia docstring every LaTeX backslash is doubled; a single-backslash escape is swallowed by the parser.

Julia consumes the escape when it reads the string, so the formula never reaches the documentation build at all.

Decided by a program.



## Citations — `RULE.CIT.*`

Author–year in the prose, the full reference where the reader can reach it, a DOI on every title. 5 rules, written from the rule values themselves,
so a rule reworded here was reworded in the program that checks it.

#### [`RULE.CIT.BLOCK_LIST`](@id RULE.CIT.BLOCK_LIST)
References are listed one to a line, never run together with semicolons.

A reader looking for one reference in a semicolon-separated run has to parse the whole paragraph.

Decided by a program.

#### [`RULE.CIT.DOI`](@id RULE.CIT.DOI)
Every reference carries a clickable DOI, or an Open Library link for a book, on its title.

A DOI a reader cannot click is a string to retype; one written as a bare label is indistinguishable from prose.

Decided by a program.

#### [`RULE.CIT.FULL_INLINE`](@id RULE.CIT.FULL_INLINE)
A docstring cites author–year in its prose and carries the full reference in a `# References` section, identical to the canonical entry in title and DOI.

A full reference mid-sentence takes the reader's eye out of the sentence, and a hand-copied entry drifts from the one the package keeps.

Decided by a program.
This package may set `references`; unset, it is `docs/ARCHITECTURE.md`.

#### [`RULE.CIT.NO_INACCESSIBLE`](@id RULE.CIT.NO_INACCESSIBLE)
Never cite an inaccessible source on any user-facing surface: not a gitignored monograph, an accompanying thesis, an appendix or figure the reader cannot open, nor working notes.

A citation the reader cannot follow is the author telling themselves where they got it; the reader is left with an assertion and nowhere to check it.

Decided by an agent, because this needs meaning.

#### [`RULE.CIT.STYLE`](@id RULE.CIT.STYLE)
In-text author–year: author-prominent takes a parenthesized year; up to 3 authors are named, 'First et al.' for four or more.

Keep enough surnames to disambiguate two works that would otherwise collide. An eponymous method name takes no year unless the work is actually cited.

Decided by an agent, because this needs meaning.



## Testing protocol — `RULE.TEST.*`

What a test is for, where its oracle comes from, and when a thing is done. 12 rules, written from the rule values themselves,
so a rule reworded here was reworded in the program that checks it.

#### [`RULE.TEST.ALLOC_ZERO`](@id RULE.TEST.ALLOC_ZERO)
Every in-place ! operator is allocation-free and in the audit; a deliberate materializer gets a bounded guard; where a bound covers another nondeterminism a configuration pins the true zero.

The audit runs on the CPU, where a materialized temporary is visible; the completeness of its rows is derived from the export list, never remembered.

Decided by nothing yet. Nothing checks it: the rulebook does not check it: harness:TestHarness.allocation_completeness enforces it inside a package's own test suite

#### [`RULE.TEST.BOTH_DIRECTIONS`](@id RULE.TEST.BOTH_DIRECTIONS)
Test the check in both directions; a check that cannot fail is not a check; a self-reported field is acceptable only when the missing case is the failing case.

The flattering direction is the one nobody guards: a check that demotes sound answers is stopped being read, and a check nobody reads passes everything.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.TEST.COUNTS_REMEASURED`](@id RULE.TEST.COUNTS_REMEASURED)
A count nothing asserts is re-measured, never cited; a drop is a finding.

A test count, a testset count, a coverage figure — each is measured at the time it is stated.

Decided by nothing yet. Nothing checks it: the rulebook does not check it: test:test/schemas.jl enforces it inside a package's own test suite

#### [`RULE.TEST.DEFINITION_OF_DONE`](@id RULE.TEST.DEFINITION_OF_DONE)
A feature is done when its correctness tests, performance test, four guiding docs, remaining docs, benchmarks (built AND run) and examples (run) are each verified.

'Should work' is not done: a step is done when its verification command exits 0 and the exit code was observed. Grep the docs for stale deferred, none-exist and future claims about whatever was just …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.TEST.EXAMPLES_RUN`](@id RULE.TEST.EXAMPLES_RUN)
Shipped examples are executed after any public-surface change; nothing else runs them.

An example is both a rendered page and a downloadable script; the docs build renders it without running it, and a call that no longer dispatches is found only by running it.

Decided by nothing yet. Nothing checks it: the rulebook does not check it: harness:makedocs enforces it inside a package's own test suite

#### [`RULE.TEST.GATE_VS_SURVEY`](@id RULE.TEST.GATE_VS_SURVEY)
Pkg.test() is a gate; the exhaustive suite is a survey; a specific oracle and every completeness guard go in the gate.

A gate re-checks claims already known and must be green or the change does not ship; a survey searches for combinations nobody enumerated and is read, not passed. A universal oracle over a product …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.TEST.METHOD_PARITY`](@id RULE.TEST.METHOD_PARITY)
The public method set is frozen per generic and per module; any change moves a number.

The per-module count is derived from ownership over the whole function surface, internals included, so a method defined under a qualified name cannot hide.

Decided by nothing yet. Nothing checks it: the rulebook does not check it: harness:TestHarness.method_parity enforces it inside a package's own test suite

#### [`RULE.TEST.MISSING_IS_FAILING`](@id RULE.TEST.MISSING_IS_FAILING)
The missing case is the failing case: derived denominators, absence arms, zero count = dead.

An empty witness directory, an empty ledger, an unparsable status — each fails; 'nothing to check' is not 'all clear'.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.TEST.MUTATION`](@id RULE.TEST.MUTATION)
A symmetric fixture cannot see an asymmetric defect; a self-referential assertion cannot see a shared defect; a stated convention must be falsifiable by its fixture.

Inject the defect and require the suite to catch it; a fixture that cannot reach the broken branch proves nothing about it.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.TEST.ORACLE_INDEPENDENT`](@id RULE.TEST.ORACLE_INDEPENDENT)
Every public value-returning operation is classified in the oracle registry; relational-only coverage is a finding.

The classes are analytic (a closed form derived independently of the package), independent (a direct computation written in the test), property (an invariant that pins the operation without …

Decided by nothing yet. Nothing checks it: the rulebook does not check it: harness:TestHarness.oracle_registry enforces it inside a package's own test suite

#### [`RULE.TEST.PASS_AUDIT`](@id RULE.TEST.PASS_AUDIT)
Every audited operation has a frozen per-array traffic row with a named holder for any gap.

A raised count is a fusion regression unless a new holder justifies it; the frozen values are refrozen in the same commit as the change, with the reason.

Decided by nothing yet. Nothing checks it: the rulebook does not check it: harness:TestHarness.traffic_completeness enforces it inside a package's own test suite

#### [`RULE.TEST.RULE_WITH_CHECK`](@id RULE.TEST.RULE_WITH_CHECK)
A rule and its check land in the same commit; a stated rule without a check is a known weakness.

A rule is written by whoever has just fixed an instance, at the moment they are most confident the class is handled — which is precisely when nobody builds the check; afterwards the rule's presence …

Decided by nothing yet. Nothing checks it: the rulebook does not check it: test:test/schemas.jl enforces it inside a package's own test suite



## Instruments — `RULE.INST.*`

How a review runs: consent, witnesses, closure, cost, and the limits it must state. 13 rules, written from the rule values themselves,
so a rule reworded here was reworded in the program that checks it.

#### [`RULE.INST.AUDIT_AFTER_CODE`](@id RULE.INST.AUDIT_AFTER_CODE)
A fix pass that changed code is audited before its round closes — always for a hunt, and for a check-docs round whose pass touched src or ext — by an audit that read the round's last code change.

`/bug-hunt` always qualifies, and so does a `/check-docs` round whose pass touched the `src` or `ext` surfaces: closing refuses until a `/audit-changes` round based at the closing round's opening …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.INST.AUDIT_DISPOSED`](@id RULE.INST.AUDIT_DISPOSED)
An audit round is closed by disposing its concerns, never by correcting them inside it; a correction rides the next change set, which the next audit covers.

A correction moves the tree, the staleness check then refuses the close, and there is no re-bank; the round would be permanently unclosable. Each gated concern takes a disposition record instead, …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.INST.CARRY`](@id RULE.INST.CARRY)
A round may close by carrying a finding into the next round of its instrument — a minor or nit at will, anything still open once its pass budget is spent — on a re-rated severity; it is re-banked there, never rediscovered. A round refuses to close by carrying a finding already carried CARRY_LIMIT (3) times — the owner rules on it instead — and a final release refuses while a carried blocker or major stands, while anything has been carried CARRY_LIMIT times, or while the backlog is not draining.

The budget is `max_passes` verification passes, 3 by default: every pass re-runs both verifiers, and past the third 2026-09-10-check-docs-03 spent six more re-verif

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.INST.CLOSURE_LOOP`](@id RULE.INST.CLOSURE_LOOP)
The closure loop runs over the banked findings by id, never by re-running the battery; abandon is the only wholesale exit and names every open id.

Closing a banked round terminates because the denominator is fixed; re-running the lanes over a just-edited corpus is a new search with no fixed point. Stop on a plateau — three passes flat within …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.INST.CONSENT`](@id RULE.INST.CONSENT)
Unasked, run only Pkg.test(); every instrument, survey, benchmark and panel runs only on the user's request, in words or by slash.

The correct output when one would be informative is to name it and its cost and wait. This is a consent boundary, not licence to leave work unfinished: finish the code, run the gate, and report what …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.INST.ECONOMY`](@id RULE.INST.ECONOMY)
Economy lanes by default; the five never-economised phases; strength = full on explicit request.

A cheap lane's false positive is caught downstream; a false negative in a lane with no downstream verifier is why some lanes are anchors and stay at full strength in every mode.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.INST.FIX_FROM_LANES`](@id RULE.INST.FIX_FROM_LANES)
A fix pass is driven from the per-lane findings by id, never from the consolidated summary.

Consolidation is lossy by design, which is what makes it readable; a severity in the summary never overrides the lane's own, and closure is reported per lane and per id.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.INST.FOUR_OBJECTS`](@id RULE.INST.FOUR_OBJECTS)
The four instruments audit different objects: changes, source prose, rendered prose, code.

A flawless docstring on a function returning the wrong number passes both prose instruments; an edit that is a correct fix and still wider than the defect passes the hunt; each exists for what the …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.INST.FROZEN_MIDROUND`](@id RULE.INST.FROZEN_MIDROUND)
An instrument is never changed mid-round; a change is its own commit and release; a deferral is written in the round's deferred.md and carried into the work queue at close; a round whose own frozen verifiers or auditors cannot run has those differing copies replaced by gbg round scripts --reason, never a lens, recorded in ROUND.toml.

A change the round wanted and could not make is written one line per deferral in the round's `deferred.md`, and `gbg round close` carries each into `.claude/WORK_QUEUE.md`, where the Stop hook holds …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.INST.NO_TRUNCATION`](@id RULE.INST.NO_TRUNCATION)
A scan output is never truncated (head, tail, a limit); count first, then read all.

Adding a limit to keep the output readable is how a class gets half-swept and reported closed; a deterministic check that depends on who types it is not deterministic.

Decided by nothing yet. Nothing checks it: the rulebook does not check it: harness:report enforces it inside a package's own test suite

#### [`RULE.INST.SEEDS`](@id RULE.INST.SEEDS)
A seeded finding is never fixed in the corpus and never enters the ledger.

Seeds are planted in a disposable copy to measure recall; the ground truth reaches no hat; a class at zero seeded recall is unmeasured, not clean; and recording a seed as adjudicated would hand the …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.INST.SELF_REPORT`](@id RULE.INST.SELF_REPORT)
Self-reported closure is not closure; the act verifier sees the diff, the state verifier is blind; the demotion is mechanical.

Both default to the unfavourable verdict so a truncated lane fails safe; a zero count is a dead lane rather than a clean hat; the denominator never comes from the party being measured; and a …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.INST.WITNESS`](@id RULE.INST.WITNESS)
A static claim about code is a hypothesis; the only evidence is a program that fails; a fixed witness is promoted unchanged.

A passing witness means not a bug, discarded however good the argument; no witness writable means a latent hazard, reported and not fixed; a failing witness is the finding and, once the fix lands, …

Decided by nothing yet. Nothing checks it: the rulebook does not check it: harness:Witnesses.run enforces it inside a package's own test suite



## Git conventions — `RULE.GIT.*`

What a commit carries, where it goes, and what is never committed. 7 rules, written from the rule values themselves,
so a rule reworded here was reworded in the program that checks it.

#### [`RULE.GIT.BRANCH`](@id RULE.GIT.BRANCH)
The working branch is git.branch (master by default; a rename is a consumer decision).

A rename is a decision about the package, never bundled with a tooling adoption.

Decided by nothing yet. Nothing checks it: the rulebook does not check it: doctor:GIT.BRANCH checks the wiring of a package, not its text

#### [`RULE.GIT.CI_MANUAL`](@id RULE.GIT.CI_MANUAL)
CI is manual-only; the matrix runs locally before a commit; docs deploy on push.

Before committing a code change, run the gate locally; a documentation-only change needs a load and the docs build. The docs build is therefore the per-push enforcement point, and the doctor, the …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.GIT.MANIFEST_TRACKED`](@id RULE.GIT.MANIFEST_TRACKED)
Sub-environment manifests are gitignored; a tracked root manifest is a declared deviation.

A stale sub-environment manifest is resolved locally when precompilation breaks; CI resolves its own.

Decided by nothing yet. Nothing checks it: the rulebook does not check it: doctor:WIRE.GITIGNORE checks the wiring of a package, not its text

#### [`RULE.GIT.NO_SHIMS`](@id RULE.GIT.NO_SHIMS)
The API is not frozen; no backward-compatibility shims.

Errors found later are fixed one by one; architectural soundness is judged on the full picture first.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.GIT.PUSH`](@id RULE.GIT.PUSH)
Commit ⇒ push, directly on the configured branch; no feature branches.

The repository is private and synced across machines through GitHub, so work is committed on the default branch and pushed in the same step; GitHub is the cross-machine sync path and the docs site …

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.GIT.REQUESTS`](@id RULE.GIT.REQUESTS)
A cross-package request is a tracked file .gbg/requests/to-<PKG>-<date>-<topic>.md in the requester with a status paragraph on top; a concluded request is deleted.

The requests directory holds what is still awaiting the other package and nothing else.

Decided by nothing yet. Nothing checks it: no program decides it yet: it is a habit the rulebook states and a reader keeps

#### [`RULE.GIT.TRAILER`](@id RULE.GIT.TRAILER)
Every commit ends with the versionless 'Co-Authored-By: Anthropic Claude <noreply@anthropic.com>' trailer; never [skip ci].

The trailer names no model version on purpose: the model in use changes often and the versions supersede each other, so a version in the trailer is a fact about the day rather than about the work, …

Decided by nothing yet. Nothing checks it: the rulebook does not check it: doctor:GIT.TRAILER checks the wiring of a package, not its text



## [Glossary](@id glossary)

The terms the rules use. A rule may use any of these without defining it; a term not here is defined
where it is used, or it is not a term of art.

- **consumer** — a package that pins this one and receives its wiring.
- **rule** — one statement with one check and the examples that show the check matches it. Its id is
  `RULE.<FAMILY>.<NAME>`, stable for the life of the rule.
- **check** — what decides that a rule was broken: a program, or an agent where no program can.
- **clause** — one requirement of a statement. A rule with three clauses owes three breaking examples
  and three complying ones.
- **switch** — a package turning a rule off, wholly or for named files, with its reason. It replaces
  the exemption ledger: there is no expiry and no ceremony, only a reason a reader can weigh.
- **file set** — which of a package's files a rule runs over: docstrings, code, pages, rationale,
  Literate examples, tests.
- **finding** — one violation at one location, with the rule that found it.
- **location** — where a finding is: the file, the node (a binding, or a heading path), the quote as
  it read then, and the line as a hint only.
- **generated file** — a file written by a Julia function of this package. Editing one by hand is
  drift, which the wiring check reports and `gbg sync` repairs.
- **pin** — the one version of this package a consumer uses, named in its sub-environments.
- **intention** — whether a change or a finding is in documentation or in code. Documentation is safe
  to fix without asking; code is not.


## What GBGCodingTools has switched off

Each entry names a rule this package does not hold itself to, and why. A rule listed
here is read as the entry states it.

- `RULE.TEST.ALLOC_ZERO` — no in-place operator over element storage exists here: this package's `!` functions mutate a registry, a dictionary or a string buffer, and an allocation bound on them measures the Julia runtime, not the package (the whole package)
- `RULE.TEST.PASS_AUDIT` — the traffic audit counts reads and writes per array element; this package holds no array whose traffic is a correctness property, so a frozen row would record the runtime's behaviour and nothing of the package's (the whole package)
- `RULE.TEST.EXAMPLES_RUN` — this package ships no Literate examples: a worked example of a review instrument is a review, which is recorded rather than executed as a script (the whole package)
- `RULE.DOC.LEADING_IDENTITY` — the leading identity of a docstring is the physical meaning of the quantity it computes; this package computes no physical quantity, so its docstrings lead with what the operation does, which the rule's own parameter already admits (the whole package)
- `RULE.API.POSITIONAL` — no program decides whether an argument affects the result, and this package's own reading panels do not run over it yet; it is switched off here until they do (the whole package)



