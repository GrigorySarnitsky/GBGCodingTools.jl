# The docstring rubric (`RULE.DOC.*`, `RULE.API.*`)

The organizing spec for every user-facing docstring and API page. Two audiences, one rule each: a
module docstring is a map; a function docstring is a home.

### RULE.DOC.TWO_TIER
A module docstring is a map and a function docstring is a home. The map states what the module is, its
scope and place in the architecture, and its invariants — then a linked one-liner per operation family,
and no formulas; every formula lives in the operation's own docstring.

### RULE.DOC.HOME_ORDER
A function docstring is ordered: identity, when-to-use, arguments, one formula, citation, links, caveats.
In full: (1) a plain one-sentence identity in the user's terms; (2) when to use it, versus the
alternatives; (3) each argument (positional and keyword) and its effect; (4) one formula if a clean one
exists, never overflowing; (5) an inline citation for a named or published method and none for a
classical one; (6) cross-links; (7) the caveats a user needs, as an admonition where load-bearing — the
last block of the home's PROSE. Then the sections that are not prose, in this order and no other: the
`# References` section of `RULE.CIT.FULL_INLINE`, then `# Fields`, which is last (`RULE.DOC.SHAPE`, and
the shape scan reads any heading after `# Fields` as a hit). Three rules each used to claim the end of a
docstring; the order lives here, and they defer to it. Excluded:
implementation internals (a `#` comment), unexplained specialist jargon, architectural rationale and the
formal apparatus (the rationale documents).

### RULE.DOC.LEADING_IDENTITY
Item (1) of the home is a plain one-sentence identity that leads with what the operation means, not how
it is computed. For this package the identity leads with {{rubric.leading_identity}}: an operation
computed in a derived representation still states what it does to the real object first — with the
explicit relation — and gives the derived form it uses after; an estimator states the population
quantity it estimates, in standard probability notation, before the estimator. Where no clean form
exists, say so briefly rather than forcing one.

### RULE.DOC.ONE_HOME
One concept has one home: one docstring per operation, on the bare binding, and a generic carries one
docstring, never one per method. Per-scheme or per-representation specifics live in the scheme's or the
representation's own docstring, linked. Across an `f`/`f!` pair the in-place `!` form is the home — it
owns the formula and the kernel and is listed first — and the allocating form and any operator alias is a
thin wrapper that leads with the one-sentence meaning and `@ref`-links the home, carrying no second copy
of the formula.

### RULE.DOC.VARIANT_PAIR
The review unit is the operation's whole variant set, so the defining math appears once across an
`f`/`f!` or getter/setter pair and the wrapper carries no display formula. Typed twice, the math drifts —
one member writing a partial one way and its twin another — and a within-string check cannot see it; a
lane that groups each operation's generics and diffs them can.

### RULE.DOC.ARGS_FORM
A docstring documenting three or more arguments, or any keyword argument, uses the bulleted form led by
`The arguments are:`; with fewer, the arguments are bound in running prose, and the two forms are never
mixed in one docstring. The threshold counts what one signature takes, not the distinct names across
type-specialised overloads. Exempt: a thin allocating wrapper, which documents no arguments at all; an
internal `_`-prefixed helper, which documents its arguments in whatever form reads best; and a single
element-type keyword bound in one prose clause.

### RULE.DOC.FIELDS
A type that stores named, user-readable fields documents them under `The fields are`, one bullet per
field, every bullet a real field and every field a bullet; prose is reserved for the one-sentence identity
above the list. A type docstring is constructor-first: identity, the constructor and its arguments, an
example where construction is non-obvious, then the demoted fields list.

### RULE.DOC.ADMONITION_TITLE
An admonition title is plain text stating the caveat, so a reader skimming the page learns the hazard
without opening the block. For this package the rule is {{docs.admonition_titles}}: either every `!!!`
block carries a custom descriptive title, or a block carrying one load-bearing claim does while a general
aside may stay a bare `!!! note`. A caveat admonition is the last substantive block of a docstring,
before the fields list.

### RULE.DOC.STEER
Every `!` form that has an allocating sibling carries the in-place steer sentence verbatim, after the
identity paragraph and before the arguments, naming its own destination argument. The sentence is
"Use this in-place form when `destination` is already allocated; the allocating \[`f`\](@ref) returns a
fresh result instead", with `destination` replaced by the argument the signature actually has. A `!` form
with no allocating sibling and a setter take no such sentence.

### RULE.DOC.ALIASING_BULLET
An operation-specific statement of whether the destination may alias an input lives in the destination
argument's bullet, not as standalone prose. The package-wide guarantee lives in the module docstring and
is not repeated per operation; an operation states it for itself only when it has an operation-specific
reason, or when its contract is the contrary one.

### RULE.DOC.INTERNAL_API
An `## Internal API` section splits into `### Types` and `### Functions` only when it holds both kinds,
comes last on its page, and opens with the same disclaimer sentence. A section documenting only functions
uses a single unlabelled block and no `###` at all.

### RULE.DOC.REF_ABUT
A `@ref` never abuts a second code span, because two adjacent monospace chips render with a visible seam.
Write the whole call as the link text with an explicit target: a Markdown link whose text is the
backticked call and whose destination is `@ref` followed by the bare name.

### RULE.DOC.API_GROUPING
API pages are math-grouped under hand-written headers via explicit `@docs` blocks, each object once, an
`f`/`f!` pair together with the `!` home first, no `@index`, and no empty block. A group is ordered by
increasing complexity of its objects; a page leads with its headline operations, then the supporting
types and schemes they take. `checkdocs = :exports` guards a dropped export, and every derived public
operation has a home on a public page.

### RULE.DOC.COVERAGE_BASES
A reduction documents every base it supports, not just one. A measure reduction over a grid and the same
reduction over a point set are both stated where the operation is documented.

### RULE.DOC.GRAMMAR
Every sentence has a subject and a verb; no verbless fragments, noun stacks, `label:` colon tags or
comma splices. Concise means few words, not missing verbs — compact prose that still reads as sentences
aloud.

### RULE.DOC.SENTENCE_OPENER
A sentence opens with a capitalized ordinary word, never a lowercase code identifier or a math formula.
A lowercase start is reworded so an ordinary word leads; the identifier is never capitalized, its binding
being lowercase by nature. Exempt: a bullet or list item, a `#` code comment (but not a Literate example's
full-line prose comment, which renders), a heading, fenced code, and a capitalized type, module or file
opener.

### RULE.DOC.VERIFIED
Correctness is verified, not asserted: every formula, normalization, adjoint relation and cross-scheme
equivalence is checked by expanding it against the code. A plausible "X is just Y" is a false claim until
the expansion matches. Run this as a positive verification — enumerate every formula, constant, relation
and quantifier and verify each — not as a read-through; a false-but-plausible statement is as invisible as
an unbound symbol. Category and type errors are their own class: an object conflated with its
representation, an operator with its parameter, a rate with its time-integral, a scalar with the field it
reduces; type every object from the code.

### RULE.DOC.SELF_CONTAINED
A rationale document reads top to bottom without another file: every piece of notation, a math symbol or
a code identifier, is introduced in plain language at its first use. Later uses may be bare; universally
standard mathematics may stand unglossed. A decision-log entry browsed on its own meets the same bar.

### RULE.DOC.TERMS_DEFINED
A term of art naming a package concept is defined in a clause or `@ref`-linked on its first use, and the
acceptance test is the cold read. A docstring can bind every symbol and still be unreadable to someone
who has not read the module, because its terms of art are nouns, not symbols; parse it with the module's
context withheld, and a noun that silently assumes the package's context is the defect.

### RULE.DOC.CURRENT
Every claim matches the code's present state, and a summary that names only a subset of what the code now
provides is stale even if every sentence is literally true. No stale future, deferred or none-exist
claims; each module and operation summary still names everything added since it was written, against the
current exports and method set. Retired phrasings a package bans are listed in its config and scanned.

### RULE.DOC.CLASS_SWEEP
A flagged instance is a sample of a class: characterize the class, sweep every surface for it, and fix
all occurrences in one pass, reporting the class and the count. Fixing only the pointed-at line and
waiting to be handed the next instance is the failure this rule exists to stop. After a class fix,
enumerate the surfaces from the finding's own text, not from memory, and re-measure.

### RULE.DOC.BATTERY
"Check the docs" means the complete battery over every surface, never one check or one file. When asked
to check, review or audit the documentation in any words, run the full matrix — every check across every
surface — and report it; do not run one check, sweep one file, and stop.

### RULE.DOC.LITERATE
A Literate example is a rendered documentation page: every full-line `# ` comment becomes prose, its math
is LaTeX, and a comment that must stay in the code uses `##`. A full-line comment inside a control-flow
block splits the code fence, so reserve full-line `# ` for narrative prose at statement boundaries. An
underscored identifier in that prose is backticked, or Markdown parses it as an italic span.

### RULE.DOC.BUILD_VERIFY
A documentation edit is verified by the full docs build exiting 0, never by a diff, a lint subset, or a
grep of a log. A lint run standalone cannot see a dangling reference, and grepping a log for error text
passes a build that died at load. After editing a Literate example, regenerate it and read the output.

### RULE.DOC.TABLE_TOP_LEVEL
A Markdown table is top-level, never indented inside a list item, and no cell holds a literal `|`. The
renderer will not form a table inside an indented item and falls back to literal pipes; inside a list use
a nested bullet list, and write a norm bar as LaTeX, never as a bare pipe.

### RULE.DOC.ONE_NOTATION
One notation per concept and one concept per notation; a local use yields to a package-wide glyph. Before
introducing a symbol, check it is not a synonym for one already in use, and check the section for the
glyph and confirm it is free. When an edit introduces a symbol, retire the old one.

### RULE.DOC.COORD_FREE
Maps and pairings are stated intrinsically, and coordinate or matrix machinery that buries the structure
is confined to the formalization document. Component notation for a genuine fiber algebra is fine; the
rule targets flattening a structured space to a bare vector. Where a basis form is needed to mirror the
code, state the basis and the space it acts on.

### RULE.DOC.LINKS
Cross-referencing is discriminating-minimalist: backtick every code identifier and promote to `@ref` only
where a reader would genuinely jump and there is one clear destination. Link a target at most once per
docstring; never link the docstring's own binding, its arguments, option tokens, struct fields or `Base`
names; a family of built-ins is one catalogue destination unless the members are distinct types a reader
must choose between; sibling names in one list are all linked or all plain, never a mix. The at-home
test: if a sentence would sit equally well in the target's own docstring, cut it and link, the
function's own defining formula and validity clauses always staying.

### RULE.DOC.SIBLING_LINK
The first mention of a sibling GBG package in a page, a rationale document, a Literate example or a
docstring is a link to that package's documentation site, written `[`Package`](https://<owner>.github.io/Package.jl/)`.
A later mention in the same unit does not link that site again — it is a bare code span, or a deep link
to a named page of the site, which is a cross-reference rather than the repetition this rule is about.
A package never links its own name. The names and sites come from the fleet registry the tool ships
(`fleet.toml`), so the target is one string in every package.

### RULE.DOC.NO_DEAD_REFS
A rendered docstring or a thrown error message cites no section number, repo path or inaccessible
source, and reads complete at the REPL where links are dead. A cross-reference adds depth one hop away;
it never carries a fact the reader needs. Section citations and design rationale stay in `#` comments and
the rationale documents.

### RULE.DOC.AI_BANNER
Every AI-written rationale page and Literate example carries the one provenance banner verbatim, and the
banner is identical wherever it appears. The banner is the two lines
`!!! info "Written by AI, not regularly reviewed"` and
`    This page is written by AI and is not reviewed regularly by a human.`; a Literate file carries
them as `# ` comment lines, and a drifted copy is a finding. The site's home page (`docs/src/index.md`)
never carries the banner in any package: the owner reviews that one page in every package, and a banner
there would be false. A package that wants the banner on more of its pages says so in its own
`CLAUDE.md`.

### RULE.DOC.SHAPE
A docstring's longest paragraph stays within 120 words and it carries at most three admonitions, no unit
grows past its recorded baseline, `# Arguments` precedes any column-0 admonition, and `# Fields` is last.
The caps bind on every docstring and every page unit that is new; a page unit already in the baseline is
held by the ratchet alone, which is the one place the baseline is the whole of the check. A paragraph is
a run of lines between blank ones, so a Markdown table is ONE paragraph however long: that is why the
caps bind on docstrings, where a table is rare, and why an inherited page section is held by the ratchet.
A docstring that has taken three or more rounds of patches is rewritten whole rather than appended to
again; the shape baseline is re-recorded deliberately, never by accident.

### RULE.DOC.MODULE_MAP
A module docstring lists one linked one-liner per operation family and carries no formula. Its order is
identity, then the contents list, then an optional trailing remark.

### RULE.DOC.ARG_BULLET
An argument or field bullet names its argument in a plain code span, never a bold one. The form is a
list item holding the backticked name, an em dash and what it is, one bullet per argument.

### RULE.DOC.SIGNATURE_MIRROR
A docstring signature mirrors the code's types, and only the docstring wraps, to at most 88 columns with a
hanging indent under the first argument. An argument typed in the method is typed in the docstring; one
the code leaves untyped stays untyped; the source definition is left exactly as written.

### RULE.DOC.SIGNATURE_FIDELITY
The displayed signature set and the defined method table agree per exported binding, and the symmetric
difference is reported. A displayed keyword no method has is a stale signature; a defined keyword no
signature shows is unadvertised. A triage scan: an inner constructor deliberately omitted, an extended
external generic and a `kwargs...` passthrough produce legitimate asymmetries.

### RULE.DOC.XLINK
A cross-module name is `@ref`-linked at its first mention in a docstring, qualified so the link resolves.
An unqualified cross-module `@ref` does not resolve, and the author who downgrades it to a bare span
creates a link that is silently missing rather than broken.

### RULE.DOC.ARGCOV
Every argument in a docstring signature, positional and keyword, is documented in its body, and the sweep
runs from the signature. An argument that surfaces only inside a formula reads as bound by use and slips
past a symbol sweep; the accepted forms are a plain span and a span carrying the default. For this package
the check is a {{instruments.check-docs.argcov_policy}} tier.

### RULE.DOC.REGISTER
A tunable is an option, a setting or a keyword argument — never a "knob" or a "tweak". The reference
register is neutral across every authored surface: docstrings, rationale documents, doc pages, `#`
comments and testset names.

### RULE.DOC.RETURNS
A type docstring leads with its constructor, and a `-> Type` arrow or a `Returns x.` sentence states the
result where the identity sentence does not. A mutator whose signature carries no arrow says what it
returns in a sentence before any caveat; a signature carries an arrow only where the return type is fixed
by the signature; arrow and sentence never both appear.

### RULE.API.POSITIONAL
A result-affecting argument is positional, a performance hint or a builder's cost and accuracy tunable is a
keyword, and every exception is recorded. In an operation, every argument that affects the result is
positional, defaults included; an argument that cannot change the result is a keyword. An exception is a
ledger deviation with its reason.

## The doc-edit checklist

Run all of these on every documentation change, most strictly on a rationale document, each as a
positive procedure: enumerate, then verify each item. (1) Correct — `RULE.DOC.VERIFIED`. (2)
Self-contained — `RULE.DOC.SELF_CONTAINED`, `RULE.DOC.TERMS_DEFINED`, `RULE.DOC.ARGCOV`. (3) Notation —
`RULE.DOC.ONE_NOTATION` and `latex-idiom.md`. (4) Formatted, bidirectional — math is LaTeX never
backticks, every code identifier backticked never bare, and the silent-rendering rules. (5) Current and
complete — `RULE.DOC.CURRENT`. (6) Cited — `citations.md`. (7) Across variant pairs —
`RULE.DOC.VARIANT_PAIR`. Order the work code before docs: the docs describe the code, so the reverse
order writes every affected docstring twice.
