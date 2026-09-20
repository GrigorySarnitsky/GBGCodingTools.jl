# [The rules GBGCodingTools is held to](@id gbg-rules)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

Generated at build time from the rule values in GBGCodingTools vdev. Each rule carries its own check and the examples that show the check matches it, so this
text and the program that enforces it cannot disagree. A rule's id is stable and is what a
finding, a switch and a report all name.

## Checked by a program — 42

These run in every build and every test of the package; a breach is a red build.

#### [`RULE.ASK.NO_COORDINATES`](@id RULE.ASK.NO_COORDINATES)
A question's decision and context name no rule, file or piece of code; those go in its items and its exhibit.

A decision carrying an identifier asks the owner to hold a coordinate in his head before he can reach the question, and the question is the part he is being asked about. A name in backticks is exempt: quoting one is how a question says which exact name it means.

Covered by a program.


#### [`RULE.ASK.NO_HOUSE_TERMS`](@id RULE.ASK.NO_HOUSE_TERMS)
A question is written in the owner's words, not in this package's.

He is being asked about his own work. A question written in the tool's vocabulary is answerable only by someone who has read the tool, which makes the answer the tool's rather than his.

Covered by a program.
This package may set `house_terms`; unset, it is `["fileset", "file set", "ratchet", "anchor", "wiring check", "managed block", "pin", "switch", "rulebook", "instrument", "lane", "hat", "round", "harness", "consumer"]`.


#### [`RULE.ASK.ONE_DECISION`](@id RULE.ASK.ONE_DECISION)
A question's decision is one sentence, and it ends in a question mark.

Two sentences in a decision are two decisions, and the owner answers with one option: whichever he meant, the other is recorded as answered and was not.

Covered by a program.


#### [`RULE.ASK.SHORT`](@id RULE.ASK.SHORT)
A question's decision and its context are short enough to read in one pass; its exhibit is not measured.

What does not fit belongs in the exhibit, which holds the commits, the diffs and the definitions the owner reads to decide. A limit on the exhibit would push the evidence out of the question instead of shortening the question.

Covered by a program.
This package may set `decision_words`; unset, it is `40`.
This package may set `context_words`; unset, it is `150`.


#### [`RULE.CIT.BLOCK_LIST`](@id RULE.CIT.BLOCK_LIST)
References are listed one to a line, never run together with semicolons.

A reader looking for one reference in a semicolon-separated run has to parse the whole paragraph.

Covered by a program.


#### [`RULE.CIT.DOI`](@id RULE.CIT.DOI)
Every reference carries a clickable DOI, or an Open Library link for a book, on its title.

A DOI a reader cannot click is a string to retype; one written as a bare label is indistinguishable from prose.

Covered by a program.


#### [`RULE.CIT.FULL_INLINE`](@id RULE.CIT.FULL_INLINE)
A docstring cites author–year in its prose and carries the full reference in a `# References` section, identical to the canonical entry in title and DOI.

A full reference mid-sentence takes the reader's eye out of the sentence, and a hand-copied entry drifts from the one the package keeps.

Covered by a program.
This package may set `references`; unset, it is `docs/ARCHITECTURE.md`.


#### [`RULE.DOC.AI_BANNER`](@id RULE.DOC.AI_BANNER)
A rationale page and a rendered Literate example carry the provenance banner, verbatim; a script that is never rendered is not a page and carries none.

A banner reworded in one package is a banner a reader learns to skim past in all of them.

Covered by a program.
This package may set `banner_pages`; unset, it is `String[]`.


#### [`RULE.DOC.API_GROUPING`](@id RULE.DOC.API_GROUPING)
One docstring has one home on the built site, and a Base function the package extends is public.

Two homes for one docstring is two things to keep true, and the second teaches a reader nothing.

Covered by a program.


#### [`RULE.DOC.ARGCOV`](@id RULE.DOC.ARGCOV)
Every argument in a docstring's signature, positional and keyword, is documented in its body.

A reader passing an argument the docstring never mentions has to read the source to learn what it does.

Covered by a program.


#### [`RULE.DOC.ARGS_FORM`](@id RULE.DOC.ARGS_FORM)
Three or more arguments, or any keyword, use the bulleted form, led by the marker phrase and a colon; fewer are bound in running prose; the two are never mixed.

A reader looking for one argument of many needs a list; a reader of a two-argument call needs a sentence.

Covered by a program.


#### [`RULE.DOC.ARG_BULLET`](@id RULE.DOC.ARG_BULLET)
An argument or field bullet names its argument in a plain code span, never a bold one.

Bold marks emphasis; a name set in bold reads as a heading over the paragraph rather than as the argument.

Covered by a program.


#### [`RULE.DOC.CURRENT`](@id RULE.DOC.CURRENT)
No stale claim: a rule cited by id names a rule that exists, and a retired phrasing is not used.

A citation of something renamed or removed reads exactly like one that resolves, which is why it survives.

Covered by a program.


#### [`RULE.DOC.FIELDS`](@id RULE.DOC.FIELDS)
A type with named fields documents them under "The fields are", one bullet per field: every bullet a real field, and every field a bullet.

A field list that has drifted is worse than none: it names what does not exist and hides what does.

Covered by a program.


#### [`RULE.DOC.INTERNAL_API`](@id RULE.DOC.INTERNAL_API)
An API page puts its internal section last, holds no empty block of collected docstrings, and is never indexed.

Internals in the middle of the public surface, and an index on a hand-grouped page, both make a reader work around the page.

Covered by a program.


#### [`RULE.DOC.LINKS`](@id RULE.DOC.LINKS)
Cross-referencing is discriminating: a target is linked at most once in one docstring, at its first genuine mention.

A second link to the same target is invisible in the rendered text and tells the reader nothing new.

Covered by a program.


#### [`RULE.DOC.LINK_UNIFORMITY`](@id RULE.DOC.LINK_UNIFORMITY)
In one run of names, either every name is linked or none is.

A list where one name links and the next does not reads as though the difference meant something.

Covered by a program.


#### [`RULE.DOC.NO_DEAD_REFS`](@id RULE.DOC.NO_DEAD_REFS)
A docstring or error message cites no section number and no inaccessible source; it reads complete at the REPL.

At the REPL there are no links: a section number cannot be followed, and it is renumbered besides.

Covered by a program.


#### [`RULE.DOC.REF_ABUT`](@id RULE.DOC.REF_ABUT)
A cross-reference never abuts a second code span; the whole call is the link text.

The two render as adjacent monospace chips with a seam, as though the name had been cut in half.

Covered by a program.


#### [`RULE.DOC.REGISTER`](@id RULE.DOC.REGISTER)
A tunable is an option, a setting or a keyword argument, never a `knob` or a `tweak`.

The house register is plain and exact; `knob` is neither, and reads as though the value did not matter.

Covered by a program.


#### [`RULE.DOC.RETIRED_CLAIMS`](@id RULE.DOC.RETIRED_CLAIMS)
A phrase a package has retired does not reappear in its documentation.

A claim retired once is retired because it was wrong, and the way a wrong claim comes back is that somebody copies the sentence that carried it. A DECISION LOG quotes what it retires, in order to record that it was retired, so this rule fires on a package's own history and is right to: keep the log in a file of its own and switch the rule off for that file, never for the design document the log was buried in, which is where the guard is worth most. The check is only as good as the list, and the list is kept by the party being checked: nothing in a repository knows that a claim was retired, so a claim dropped from the list is invisible here, and a ban whose reason was itself later overturned stays in force until someone notices.

Covered by a program.
This package may set `retired_claims`; unset, it is `GBGCodingTools.Model.RetiredClaim[]`.


#### [`RULE.DOC.SENTENCE_OPENER`](@id RULE.DOC.SENTENCE_OPENER)
A sentence opens with a capitalised ordinary word, never a lowercase identifier or a formula; bullets, comments, headings and fenced code are exempt.

At a full stop a reader cannot tell a new sentence beginning with a lowercase name from the old one running on.

Covered by a program.


#### [`RULE.DOC.SHAPE`](@id RULE.DOC.SHAPE)
A paragraph of prose stays inside the house cap, an admonition count stays inside its own, and prose that was here before the cap may shrink but never grow.

Prose grows by accretion: each addition is small, nobody rewrites, and the paragraph nobody can read was never written in one sitting.

Covered by a program.


#### [`RULE.DOC.SIBLING_LINK`](@id RULE.DOC.SIBLING_LINK)
The first mention of a sibling package links to that package's site; later mentions are bare.

A reader meeting the name for the first time must be able to reach it, and a fourth link teaches nothing.

Covered by a program.
This package may set `sibling_sites`; unset, it is `["GBGCodingTools" => "https://grigorysarnitsky.github.io/GBGCodingTools.jl/", "GBGPeriodicFields" => "https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/", "GBGHomogeneousTurbulence" => "https://grigorysarnitsky.github.io/GBGHomogeneousTurbulence.jl/", "GBGStreamingStatistics" => "https://grigorysarnitsky.github.io/GBGStreamingStatistics.jl/", "GBGCloudPhysics" => "https://grigorysarnitsky.github.io/GBGCloudPhysics.jl/"]`.


#### [`RULE.DOC.SIGNATURE_FIDELITY`](@id RULE.DOC.SIGNATURE_FIDELITY)
The signature a docstring displays and the methods the module defines agree, argument for argument.

A displayed signature is what a reader calls; one the method table has moved past is a call that fails.

Covered by a program.


#### [`RULE.DOC.SIGNATURE_MIRROR`](@id RULE.DOC.SIGNATURE_MIRROR)
A docstring's signature block fits the house column and repeats only as much of the method as a reader needs.

A signature wider than the column wraps in the rendered page and in every terminal that shows it.

Covered by a program.


#### [`RULE.DOC.TABLE_TOP_LEVEL`](@id RULE.DOC.TABLE_TOP_LEVEL)
A Markdown table is top-level, never indented inside a list item.

Markdown reads an indented block as code, so an indented table renders as the pipes and dashes themselves.

Covered by a program.


#### [`RULE.DOC.XLINK`](@id RULE.DOC.XLINK)
A name another module owns is linked at its first mention in a docstring, qualified so the link resolves.

A reader meeting a name from elsewhere has nowhere to go: the docstring in front of him does not define it.

Covered by a program.


#### [`RULE.TEX.BOLDSYMBOL_BRACED`](@id RULE.TEX.BOLDSYMBOL_BRACED)
A bold symbol braces its argument.

Unbraced, it bolds the next character alone and leaves the rest of the name upright.

Covered by a program.


#### [`RULE.TEX.CODE_IN_MATH`](@id RULE.TEX.CODE_IN_MATH)
A code identifier never sits inside a math span; inside a formula it is written \texttt{…}.

The renderer sets a run of letters in a math span as a product of italic single letters, not as a name. That remedy is for a name taking part in a formula which says more than the name itself: where the formula only names what the code denotes, the name stays a code span and a connective joins the two (`RULE.TEX.ONE_SPAN`).

Covered by a program.


#### [`RULE.TEX.FRAC_BRACED`](@id RULE.TEX.FRAC_BRACED)
Both arguments of a fraction are braced.

An unbraced fraction takes one character as its numerator and silently drops the rest.

Covered by a program.


#### [`RULE.TEX.INLINE_ONE_LINE`](@id RULE.TEX.INLINE_ONE_LINE)
An inline math span opens and closes on one line, never across a list or blockquote marker.

A marker inside an open span lands in the formula, and the prose after it renders as mathematics.

Covered by a program.


#### [`RULE.TEX.LEFTRIGHT`](@id RULE.TEX.LEFTRIGHT)
A sized delimiter names what it sizes: \left( pairs with \right), and neither stands alone.

An unpaired sizing command is a LaTeX error, and the whole formula fails to render.

Covered by a program.


#### [`RULE.TEX.MATHBB`](@id RULE.TEX.MATHBB)
A blackboard-bold digit is not a set; the identity is written \mathbb{1} only where it means one.

A blackboard digit renders as an outline numeral, which means nothing to a reader of mathematics.

Covered by a program.


#### [`RULE.TEX.MATHBF`](@id RULE.TEX.MATHBF)
Bold is admitted only for the strings a package lists, plus the identity, which every package is granted.

Bold means one thing in one package and another in the next; unlisted, it is a reader's guess.

Covered by a program.
This package may set `mathbf_allowed`; unset, it is `String[]`.


#### [`RULE.TEX.ONE_SPAN`](@id RULE.TEX.ONE_SPAN)
A code span and a math span are never set against each other where the formula continues into or out of the name: where it says more than the name — a definition, or a symbol and then its definition — the name goes inside it as \texttt{…}, and where it only names what the code denotes, a connective joins the two. A formula finished at the edge the name sits on is not continued by it and is left as it is.

Abutting spans render as two disjoint runs at different sizes, leaving the reader to guess whether the second continues the first, qualifies it, or defines it. Apposition says which: `atol` (``\varepsilon``) keeps the name styled as code — clickable, and the same as every other name on the page — while `\texttt{atol}` is the math renderer's monospace, and a link wrapped round the whole formula makes its every operator a link to the name.

Covered by a program.


#### [`RULE.TEX.PARTIAL`](@id RULE.TEX.PARTIAL)
A partial derivative names its index as a symbol, not as a bare letter subscript.

A bare index reads as a variable named i rather than as the direction differentiated in.

Covered by a program.


#### [`RULE.TEX.RENDERED_MARKUP`](@id RULE.TEX.RENDERED_MARKUP)
No markup shows on the built page as literal characters.

Asterisks meant to set emphasis, shown as asterisks, are the mark of prose nobody read after building.

Covered by a program.


#### [`RULE.TEX.RENDERED_MATH`](@id RULE.TEX.RENDERED_MATH)
Mathematics is written in a double-backtick span: never between dollar signs, and never inside a code span.

Dollars render as literal text and a code span renders as monospace; neither comes out as mathematics.

Covered by a program.


#### [`RULE.TEX.RENDERED_MATH_SITE`](@id RULE.TEX.RENDERED_MATH_SITE)
On the built page, every math span has rendered: none still shows its own markup.

A span that renders as its own source is a formula the reader never sees, and the source looks right.

Covered by a program.


#### [`RULE.TEX.SPACING`](@id RULE.TEX.SPACING)
Spacing inside a formula is the renderer's: no thin space, no medium or thick space, no negative thin space before a sized delimiter, and none of them doubled.

Hand spacing is tuned to one renderer at one font size and is wrong in every other setting.

Covered by a program.


#### [`RULE.TEX.SWALLOWED_ESCAPE`](@id RULE.TEX.SWALLOWED_ESCAPE)
Inside a Julia docstring every LaTeX backslash is doubled; a single-backslash escape is swallowed by the parser.

Julia consumes the escape when it reads the string, so the formula never reaches the documentation build at all.

Covered by a program.


## Judged by a reader — 27

No program can decide these. A documentation review hands each to the reader given what it needs; a rule needing more than any reader is given is reported as not judged.

#### [`RULE.API.POSITIONAL`](@id RULE.API.POSITIONAL)
In an operation, an argument that can change the result is positional, defaults included; an argument that cannot change the result — a performance hint, a builder's cost/accuracy tunable — is a keyword. An exception is a `Switch` on this rule in the package's own config, with its reason.

In an operation, every argument that affects the result is positional, defaults included; an argument that cannot change the result is a keyword. An exception is a `Switch` on this rule, with its reason.

Covered by a reader given source + other documents, because this needs meaning.


#### [`RULE.ASK.PLAIN`](@id RULE.ASK.PLAIN)
A question reads plainly, stands on its own, and invents no word for something that already has one.

A question is read once, by someone who was doing something else. Whether it can be answered without opening anything is a matter of meaning, which no program decides.

Covered by an agent, because this needs meaning.


#### [`RULE.CIT.NO_INACCESSIBLE`](@id RULE.CIT.NO_INACCESSIBLE)
Never cite an inaccessible source on any user-facing surface: not a gitignored monograph, an accompanying thesis, an appendix or figure the reader cannot open, nor working notes.

A citation the reader cannot follow is the author telling themselves where they got it; the reader is left with an assertion and nowhere to check it.

Covered by a reader given cited work + other documents, because this needs meaning.


#### [`RULE.CIT.STYLE`](@id RULE.CIT.STYLE)
An in-text citation is author–year. An author-prominent citation puts the year in parentheses. Up to three authors are named in full; four or more are written 'First et al.'. The author count is read from the package's reference list, the file RULE.CIT.FULL_INLINE's `references` names.

Keep enough surnames to disambiguate two works that would otherwise collide. An eponymous method name takes no year unless the work is actually cited.

Covered by a reader given other documents, because this needs meaning.


#### [`RULE.DOC.ADMONITION_TITLE`](@id RULE.DOC.ADMONITION_TITLE)
Every !!! block carries a custom descriptive title. Where this rule's `admonition_titles` is `load-bearing only`, a block need carry one only when text elsewhere relies on the block's content; a general aside may keep its default title.

For this package the rule is what `admonition_titles` says: either every `!!!` block carries a custom descriptive title, or a block carrying one load-bearing claim does while a general aside may stay a bare `!!! note`. A caveat admonition is the last substantive block of a docstring, before the fields list.

Covered by a reader given other documents + siblings.
This package may set `admonition_titles`; unset, it is `always`.


#### [`RULE.DOC.ALIASING_BULLET`](@id RULE.DOC.ALIASING_BULLET)
An aliasing statement specific to one operation — one that names that operation's own arguments — lives in the bullet for its destination argument. The package-wide aliasing guarantee lives once, in the module docstring, and is not repeated per operation.

The package-wide guarantee lives in the module docstring and is not repeated per operation; an operation states it for itself only when it has an operation-specific reason, or when its contract is the contrary one.

Covered by a reader given siblings, because this needs meaning.


#### [`RULE.DOC.COORD_FREE`](@id RULE.DOC.COORD_FREE)
Maps and pairings are stated intrinsically, without flattening a structured space to a bare vector; matrix and flattening machinery appears only in the package's formalization document — the file this rule's `formalization` names — and nowhere when none is named. Where a basis form is needed to mirror the code, the docstring states the basis and the space it acts on.

Component notation for a genuine fiber algebra is fine; the rule targets flattening a structured space to a bare vector. Where a basis form is needed to mirror the code, state the basis and the space it acts on.

Covered by a differential_geometry reader given other documents, because this needs meaning.
This package may set `formalization`; unset, it is ``.


#### [`RULE.DOC.COVERAGE_BASES`](@id RULE.DOC.COVERAGE_BASES)
An operation that reduces a field over a measure documents every base the code supports for it — the reduction over a grid and the same reduction over a point set are both stated where the operation is documented.

A measure reduction over a grid and the same reduction over a point set are both stated where the operation is documented.

Covered by a reader given source, because this needs meaning.


#### [`RULE.DOC.GRAMMAR`](@id RULE.DOC.GRAMMAR)
Every sentence has a subject and a verb; concise means few words, not missing verbs.

Concise means few words, not missing verbs — compact prose that still reads as sentences aloud.

Covered by a reader given nothing, because this needs meaning.


#### [`RULE.DOC.HOME_ORDER`](@id RULE.DOC.HOME_ORDER)
A function docstring is ordered: identity, when-to-use, arguments, one formula, citation, links, caveats, then `# References`, then `# Fields` last. Implementation internals and design rationale are excluded; so is any term that neither the surrounding sentence nor the package's notation page — the file RULE.DOC.ONE_NOTATION's `notation_page` names — defines.

In full: (1) a plain one-sentence identity in the user's terms; (2) when to use it, versus the alternatives; (3) each argument (positional and keyword) and its effect; (4) one formula if a clean one exists, never overflowing; (5) an inline citation for a named or published method and none for a classical one; (6) cross-links; (7) the caveats a user needs, as an admonition where load-bearing — the last block of the home's PROSE. Then the sections that are not prose, in this order and no other: the `# References` section of `RULE.CIT.FULL_INLINE`, then `# Fields`, which is last (`RULE.DOC.SHAPE`, and the shape scan reads any heading after `# Fields` as a hit). Three rules each used to claim the end of a docstring; the order lives here, and they defer to it. Excluded: implementation internals (a `#` comment), unexplained specialist jargon, architectural rationale and the formal apparatus (the rationale documents).

Covered by a reader given other documents.


#### [`RULE.DOC.LEADING_IDENTITY`](@id RULE.DOC.LEADING_IDENTITY)
Item (1) of a docstring is one plain sentence saying what the operation computes — the physical meaning first, or the estimand first, as this rule's `leading_identity` sets for the package. Whether that sentence is true of the code is RULE.DOC.VERIFIED's question, not this rule's.

For this package the identity leads with what `leading_identity` names: an operation computed in a derived representation still states what it does to the real object first — with the explicit relation — and gives the derived form it uses after; an estimator states the population quantity it estimates, in standard probability notation, before the estimator. Where no clean form exists, say so briefly rather than forcing one.

Covered by a reader given other documents, because this needs meaning.
This package may set `leading_identity`; unset, it is `physical meaning`.


#### [`RULE.DOC.LITERATE`](@id RULE.DOC.LITERATE)
In the source file of a Literate example, every full-line # comment is prose that will render, any mathematics in such a comment is LaTeX, and a comment inside control flow is written ## so that it does not render. The rule is judged on the source file; what the page made of it is RULE.DOC.LITERATE_RENDERED's question.

A full-line comment inside a control-flow block splits the code fence, so reserve full-line `# ` for narrative prose at statement boundaries. An underscored identifier in that prose is backticked, or Markdown parses it as an italic span.

Covered by a reader given nothing.


#### [`RULE.DOC.LITERATE_RENDERED`](@id RULE.DOC.LITERATE_RENDERED)
The built page of a Literate example shows its prose as prose: no stray `#`, no italics or code block that a comment's underscores or indentation produced, no mathematics split or broken across comment lines, and no comment landing inside a code fence. The rule is judged on the built page.

What a `#` comment becomes is decided by Literate and then by Markdown, and neither is visible in the source: `a_b and c_d` renders as italic, a comment beginning `# 1.` becomes a list item, four spaces of indentation become a code block, and mathematics split across two comment lines is not mathematics. The habits in the source are RULE.DOC.LITERATE's; this rule reads what they produced.

Covered by a reader given rendered.


#### [`RULE.DOC.MODULE_MAP`](@id RULE.DOC.MODULE_MAP)
A module docstring lists one linked one-liner per operation family and no formula.

Its order is identity, then the contents list, then an optional trailing remark.

Covered by a reader given siblings.


#### [`RULE.DOC.ONE_HOME`](@id RULE.DOC.ONE_HOME)
One concept, one home: one docstring per operation on the bare binding; the ! form owns the formula and is listed first; every other variant is a thin wrapper that @ref-links the home and carries no second formula.

Per-scheme or per-representation specifics live in the scheme's or the representation's own docstring, linked. Across an `f`/`f!` pair the in-place `!` form is the home — it owns the formula and the kernel and is listed first — and the allocating form and any operator alias is a thin wrapper that leads with the one-sentence meaning and `@ref`-links the home, carrying no second copy of the formula.

Covered by a reader given siblings.


#### [`RULE.DOC.ONE_NOTATION`](@id RULE.DOC.ONE_NOTATION)
One symbol denotes one concept and one concept is denoted by one symbol, as the package's notation page records — the file this rule's `notation_page` names; a local use that conflicts with the notation page is the one that changes.

Before introducing a symbol, check it is not a synonym for one already in use, and check the section for the glyph and confirm it is free. When an edit introduces a symbol, retire the old one.

Covered by a reader given other documents + siblings, because this needs derivation.
This package may set `notation_page`; unset, it is `docs/src/notation.md`.


#### [`RULE.DOC.RETURNS`](@id RULE.DOC.RETURNS)
A type docstring leads with its constructor. A function docstring whose identity sentence does not name the result states it with a '-> Type' arrow or a 'Returns x.' sentence. Whether the stated result is what the code returns is RULE.DOC.VERIFIED's question, not this rule's.

A mutator whose signature carries no arrow says what it returns in a sentence before any caveat; a signature carries an arrow only where the return type is fixed by the signature; arrow and sentence never both appear.

Covered by a reader given nothing.


#### [`RULE.DOC.SELF_CONTAINED`](@id RULE.DOC.SELF_CONTAINED)
A rationale doc reads top to bottom without another file: every symbol is bound in plain language at first use.

Later uses may be bare; universally standard mathematics may stand unglossed. A decision-log entry browsed on its own meets the same bar.

Covered by a reader given nothing, because this needs reading order.


#### [`RULE.DOC.STEER`](@id RULE.DOC.STEER)
Every ! form with an allocating sibling carries the in-place steer sentence, verbatim from the template this rule's `why` gives, with `destination` replaced by the ! form's own destination argument and `f` by the allocating sibling's name.

The sentence is a template, not a link: `destination` is replaced by the argument the signature actually has and `f` by the allocating sibling's own name, written as an `@ref` link, so the link resolves. The template: Use this in-place form when `destination` is already allocated; the allocating `f` returns a fresh result instead.

Covered by a reader given siblings + other documents.


#### [`RULE.DOC.TERMS_DEFINED`](@id RULE.DOC.TERMS_DEFINED)
A term of art is defined in a clause, or @ref-linked to its definition, before its first use on the same page. The test is a cold read of that page alone.

A docstring can bind every symbol and still be unreadable to someone who has not read the module, because its terms of art are nouns, not symbols; parse it with the module's context withheld, and a noun that silently assumes the package's context is the defect.

Covered by a reader given nothing, because this needs meaning.


#### [`RULE.DOC.TWO_TIER`](@id RULE.DOC.TWO_TIER)
A module docstring is a map: one linked one-line entry per operation family, and no formula. A function docstring is a home: the one place where that operation's identity, arguments and defining formula are stated in full.

The map states what the module is, its scope and place in the architecture, and its invariants — then a linked one-liner per operation family, and no formulas; every formula lives in the operation's own docstring.

Covered by a reader given siblings, because this needs reading order.


#### [`RULE.DOC.VARIANT_PAIR`](@id RULE.DOC.VARIANT_PAIR)
Across an f/f! pair or a getter/setter pair, the defining mathematics appears once, in the docstring of the member that is the home under RULE.DOC.ONE_HOME; the other member carries no display formula. The pair is one unit for this rule.

Typed twice, the math drifts — one member writing a partial one way and its twin another — and a within-string check cannot see it; a lane that groups each operation's generics and diffs them can.

Covered by a reader given other documents.


#### [`RULE.DOC.VERIFIED`](@id RULE.DOC.VERIFIED)
Every formula, normalization, adjoint relation and cross-scheme equivalence stated in the documentation is true of what the code computes, established by expanding the statement against the code, never taken on the docstring's word.

A plausible 'X is just Y' is a false claim until the expansion matches. Run this as a positive verification — enumerate every formula, constant, relation and quantifier and verify each — not as a read-through; a false-but-plausible statement is as invisible as an unbound symbol. Category and type errors are their own class: an object conflated with its representation, an operator with its parameter, a rate with its time-integral, a scalar with the field it reduces; type every object from the code.

Covered by a reader given source, because this needs meaning.


#### [`RULE.TEX.CODE_SPAN_JULIA`](@id RULE.TEX.CODE_SPAN_JULIA)
A backtick span holds only well-formed Julia, never code-looking math.

A half-open interval, an inequality, a product, a lone `≤` or `·` glyph is LaTeX; the real operators `×`, `⋅` and `≈` backticked are code and stay.

Covered by a reader given nothing.


#### [`RULE.TEX.GREEK_AB`](@id RULE.TEX.GREEK_AB)
The accumulation scalars are written as Unicode α and β wherever they appear. Two ASCII spellings stay, both named in this rule's `why`: a flag whose name carries the α/β variant, and an external window-shape parameter `beta` inside an English-register block.

A hand-written operation spelling them `alpha`/`beta` is drift; a flag naming the α/β variant and an external window-shape `beta` in an English-register block are the recorded exceptions.

Covered by a reader given other documents.


#### [`RULE.TEX.IMAGINARY`](@id RULE.TEX.IMAGINARY)
The imaginary unit is upright \mathrm{i}; i, j, k are indices.

Never a bare italic `i`, never `\imath` or `\mathbb{i}`; the differential is likewise upright, `\,\mathrm{d}x`.

Covered by a reader given nothing, because this needs derivation.


#### [`RULE.TEX.NO_HSCROLL`](@id RULE.TEX.NO_HSCROLL)
No horizontal scroll: hand-wrap long signatures and display formulas with aligned/gathered.

Neither a rendered code block nor display math auto-wraps; inline math reflows and is exempt. Never pack several equations on one line behind `\quad`.

Covered by a reader given rendered.


## Instructions to the session — 22

These are followed while working and checked by nothing: they tell a session how to commit, what to run unasked, and how to read what a scan prints.

#### [`RULE.DOC.BATTERY`](@id RULE.DOC.BATTERY)
'Check the docs' means the complete battery over every surface, never one check or one file.

When asked to check, review or audit the documentation in any words, run the full matrix — every check across every surface — and report it; do not run one check, sweep one file, and stop.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.DOC.BUILD_VERIFY`](@id RULE.DOC.BUILD_VERIFY)
A doc edit is verified by the full docs build exiting 0, never by a diff, a lint subset or a log grep.

A lint run standalone cannot see a dangling reference, and grepping a log for error text passes a build that died at load. After editing a Literate example, regenerate it and read the output.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.DOC.CLASS_SWEEP`](@id RULE.DOC.CLASS_SWEEP)
A flagged instance is a sample of a class: sweep every surface for the class and fix all in one pass.

Fixing only the pointed-at line and waiting to be handed the next instance is the failure this rule exists to stop. After a class fix, enumerate the surfaces from the finding's own text, not from memory, and re-measure.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.GIT.BRANCH`](@id RULE.GIT.BRANCH)
The working branch is git.branch (master by default; a rename is a consumer decision).

A rename is a decision about the package, never bundled with a tooling adoption.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.GIT.CI_MANUAL`](@id RULE.GIT.CI_MANUAL)
CI is manual-only; the matrix runs locally before a commit; docs deploy on push.

Before committing a code change, run the gate locally; a documentation-only change needs a load and the docs build. The docs build is therefore the per-push enforcement point, and the doctor, the hard scans and the gate stay inside it.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.GIT.MANIFEST_TRACKED`](@id RULE.GIT.MANIFEST_TRACKED)
Sub-environment manifests are gitignored; a tracked root manifest is a declared deviation.

A stale sub-environment manifest is resolved locally when precompilation breaks; CI resolves its own.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.GIT.NO_SHIMS`](@id RULE.GIT.NO_SHIMS)
The API is not frozen; no backward-compatibility shims.

Errors found later are fixed one by one; architectural soundness is judged on the full picture first.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.GIT.PUSH`](@id RULE.GIT.PUSH)
Commit ⇒ push, directly on the configured branch; no feature branches.

The repository is private and synced across machines through GitHub, so work is committed on the default branch and pushed in the same step; GitHub is the cross-machine sync path and the docs site deploys on push. Stage with `git add -u` plus every new file by name, never `-A`.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.GIT.REQUESTS`](@id RULE.GIT.REQUESTS)
A cross-package request is a tracked file .gbg/requests/to-<PKG>-<date>-<topic>.md in the requester with a status paragraph on top; a concluded request is deleted.

The requests directory holds what is still awaiting the other package and nothing else.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.GIT.TRAILER`](@id RULE.GIT.TRAILER)
Every commit ends with the versionless 'Co-Authored-By: Anthropic Claude <noreply@anthropic.com>' trailer; never [skip ci].

The trailer names no model version on purpose: the model in use changes often and the versions supersede each other, so a version in the trailer is a fact about the day rather than about the work, and it goes stale in the one place git never lets anyone correct it.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.INST.CONSENT`](@id RULE.INST.CONSENT)
Unasked, run only Pkg.test(); every instrument, survey, benchmark and panel runs only on the user's request, in words or by slash.

The correct output when one would be informative is to name it and its cost and wait. This is a consent boundary, not licence to leave work unfinished: finish the code, run the gate, and report what remains unverified and why. "Check the docs" is such a request: it means run `/check-docs`.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.INST.NO_TRUNCATION`](@id RULE.INST.NO_TRUNCATION)
A scan output is never truncated (head, tail, a limit); count first, then read all.

Adding a limit to keep the output readable is how a class gets half-swept and reported closed; a deterministic check that depends on who types it is not deterministic.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.TEST.ALLOC_ZERO`](@id RULE.TEST.ALLOC_ZERO)
Every in-place ! operator is allocation-free and in the audit; a deliberate materializer gets a bounded guard; where a bound covers another nondeterminism a configuration pins the true zero.

The audit runs on the CPU, where a materialized temporary is visible; the completeness of its rows is derived from the export list, never remembered.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session until a package wires the harness contract `TestHarness.allocation_completeness`, which no wired package calls today; checked by nothing until then


#### [`RULE.TEST.BOTH_DIRECTIONS`](@id RULE.TEST.BOTH_DIRECTIONS)
Test the check in both directions; a check that cannot fail is not a check; a self-reported field is acceptable only when the missing case is the failing case.

The flattering direction is the one nobody guards: a check that demotes sound answers is stopped being read, and a check nobody reads passes everything.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.TEST.DEFINITION_OF_DONE`](@id RULE.TEST.DEFINITION_OF_DONE)
A feature is done when its correctness tests, performance test, four guiding docs, remaining docs, benchmarks (built AND run) and examples (run) are each verified.

'Should work' is not done: a step is done when its verification command exits 0 and the exit code was observed. Grep the docs for stale deferred, none-exist and future claims about whatever was just implemented.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.TEST.EXAMPLES_RUN`](@id RULE.TEST.EXAMPLES_RUN)
Shipped examples are executed after any public-surface change; nothing else runs them.

An example is both a rendered page and a downloadable script; the docs build renders it without running it, and a call that no longer dispatches is found only by running it.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.TEST.GATE_VS_SURVEY`](@id RULE.TEST.GATE_VS_SURVEY)
Pkg.test() is a gate; the exhaustive suite is a survey; a specific oracle and every completeness guard go in the gate.

A gate re-checks claims already known and must be green or the change does not ship; a survey searches for combinations nobody enumerated and is read, not passed. A universal oracle over a product goes in the survey, and anything that may legitimately be non-green goes there too, because a suppressed failure reads as a pass.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.TEST.METHOD_PARITY`](@id RULE.TEST.METHOD_PARITY)
The public method set is frozen per generic and per module; any change moves a number.

The per-module count is derived from ownership over the whole function surface, internals included, so a method defined under a qualified name cannot hide.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session until a package wires the harness contract `TestHarness.method_parity`, which no wired package calls today; checked by nothing until then


#### [`RULE.TEST.MISSING_IS_FAILING`](@id RULE.TEST.MISSING_IS_FAILING)
The missing case is the failing case: derived denominators, absence arms, zero count = dead.

An empty witness directory, an empty ledger, an unparsable status — each fails; 'nothing to check' is not 'all clear'.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.TEST.MUTATION`](@id RULE.TEST.MUTATION)
A symmetric fixture cannot see an asymmetric defect; a self-referential assertion cannot see a shared defect; a stated convention must be falsifiable by its fixture.

Inject the defect and require the suite to catch it; a fixture that cannot reach the broken branch proves nothing about it.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session: followed while working, checked by nothing


#### [`RULE.TEST.ORACLE_INDEPENDENT`](@id RULE.TEST.ORACLE_INDEPENDENT)
Every public value-returning operation is classified in the oracle registry; relational-only coverage is a finding.

The classes are analytic (a closed form derived independently of the package), independent (a direct computation written in the test), property (an invariant that pins the operation without computing it), relational (compared only against other package operations — legitimate as a second layer, never as the only one) and structural (returns metadata or storage). A new operation fails the registry until someone classifies it, which is the moment to notice it has no independent oracle.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session until a package wires the harness contract `TestHarness.oracle_registry`, which no wired package calls today; checked by nothing until then


#### [`RULE.TEST.PASS_AUDIT`](@id RULE.TEST.PASS_AUDIT)
Every audited operation has a frozen per-array traffic row with a named holder for any gap.

A raised count is a fusion regression unless a new holder justifies it; the frozen values are refrozen in the same commit as the change, with the reason.

Covered by the session, as an instruction: followed while working, checked by nothing. Nothing checks it: an instruction to the session until a package wires the harness contract `TestHarness.traffic_completeness`, which no wired package calls today; checked by nothing until then


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
- **operation family** — an operation together with its variants: the allocating and in-place
  forms, a getter and its setter, the methods of one name across representations. A module map
  lists one entry per family; the family's home docstring is the one `RULE.DOC.ONE_HOME` names.


## What GBGCodingTools has switched off

Each entry names a rule this package does not hold itself to, and why. A rule listed
here is read as the entry states it.

- `RULE.TEST.ALLOC_ZERO` — no in-place operator over element storage exists here: this package's `!` functions mutate a registry, a dictionary or a string buffer, and an allocation bound on them measures the Julia runtime, not the package (the whole package)
- `RULE.TEST.PASS_AUDIT` — the traffic audit counts reads and writes per array element; this package holds no array whose traffic is a correctness property, so a frozen row would record the runtime's behaviour and nothing of the package's (the whole package)
- `RULE.TEST.EXAMPLES_RUN` — this package ships no Literate examples: a worked example of a review instrument is a review, which is recorded rather than executed as a script (the whole package)
- `RULE.DOC.LEADING_IDENTITY` — the leading identity of a docstring is the physical meaning of the quantity it computes; this package computes no physical quantity, so its docstrings lead with what the operation does, which the rule's own parameter already admits (the whole package)
- `RULE.API.POSITIONAL` — no program decides whether an argument affects the result, and this package's own reading panels do not run over it yet; it is switched off here until they do (the whole package)



