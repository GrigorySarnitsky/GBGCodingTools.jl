# [The readers of GBGCodingTools](@id gbg-readers)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

!!! warning "The review is switched off here"
    The review reads a package's documentation with the rulebook this package writes; running it here while the rulebook and the run machinery are still being built would grade the tool against rules it is in the middle of changing. It is switched on in Phase 8, when the tool reviews itself last.

A documentation review is read by agents, and which agents they are is not a list anybody keeps: it
follows from the rules. A rule no program can decide carries a tag saying what a reader must be given
to judge it — nothing beyond the one page, the sibling pages, the source, the built site — and the
readers below are the bundles those tags fall into. A rule that names a field of expertise goes to a
reader of that field, which the package declares in its config.

| Reader | Given | Rules it carries |
|---|---|---|
| `withheld` | one built page, and nothing else | 7 |
| `full` | every document and the source | 14 |
| `rendered` | the built site | 2 |
| `plain_sense` | one built page, and nothing else | none: it reports what no rule names |
| `logician` | every document and the source | none: it reports what no rule names |

## `withheld`

A scientist in the package's own fields, new to the package, on a first read of ONE page — every other page, the design documents and the source withheld. Judges only what this page says by itself: a term of the package it uses before it defines, a sentence without a verb, a symbol it binds nowhere, a comment that will not render as prose. Standard mathematics and the field's own vocabulary need no definition; the package's do.

It is given these rules to check:

- [`RULE.DOC.GRAMMAR`](@ref RULE.DOC.GRAMMAR)
- [`RULE.DOC.LITERATE`](@ref RULE.DOC.LITERATE)
- [`RULE.DOC.RETURNS`](@ref RULE.DOC.RETURNS)
- [`RULE.DOC.SELF_CONTAINED`](@ref RULE.DOC.SELF_CONTAINED)
- [`RULE.DOC.TERMS_DEFINED`](@ref RULE.DOC.TERMS_DEFINED)
- [`RULE.TEX.CODE_SPAN_JULIA`](@ref RULE.TEX.CODE_SPAN_JULIA)
- [`RULE.TEX.IMAGINARY`](@ref RULE.TEX.IMAGINARY)

## `full`

A careful reader of the whole documentation with the source beside it: every docstring, every page, the reference list, the notation page and the package's config. Judges what one place says against what the others say and against the code it documents — expanding a formula against the code rather than taking the docstring's word.

It is given these rules to check:

- [`RULE.CIT.NO_INACCESSIBLE`](@ref RULE.CIT.NO_INACCESSIBLE)
- [`RULE.CIT.STYLE`](@ref RULE.CIT.STYLE)
- [`RULE.DOC.ADMONITION_TITLE`](@ref RULE.DOC.ADMONITION_TITLE)
- [`RULE.DOC.ALIASING_BULLET`](@ref RULE.DOC.ALIASING_BULLET)
- [`RULE.DOC.COVERAGE_BASES`](@ref RULE.DOC.COVERAGE_BASES)
- [`RULE.DOC.HOME_ORDER`](@ref RULE.DOC.HOME_ORDER)
- [`RULE.DOC.MODULE_MAP`](@ref RULE.DOC.MODULE_MAP)
- [`RULE.DOC.ONE_HOME`](@ref RULE.DOC.ONE_HOME)
- [`RULE.DOC.ONE_NOTATION`](@ref RULE.DOC.ONE_NOTATION)
- [`RULE.DOC.STEER`](@ref RULE.DOC.STEER)
- [`RULE.DOC.TWO_TIER`](@ref RULE.DOC.TWO_TIER)
- [`RULE.DOC.VARIANT_PAIR`](@ref RULE.DOC.VARIANT_PAIR)
- [`RULE.DOC.VERIFIED`](@ref RULE.DOC.VERIFIED)
- [`RULE.TEX.GREEK_AB`](@ref RULE.TEX.GREEK_AB)

## `rendered`

A reader of the BUILT site, page by page, as a visitor meets it. Judges what the build made of the source: what renders wide, what renders as prose that was meant as code or as code that was meant as prose, what Literate and Markdown made of a comment.

It is given these rules to check:

- [`RULE.DOC.LITERATE_RENDERED`](@ref RULE.DOC.LITERATE_RENDERED)
- [`RULE.TEX.NO_HSCROLL`](@ref RULE.TEX.NO_HSCROLL)

## `plain_sense`

Asks of each sentence whether it means anything and whether it earns its place. Reports the sentence that survives deletion without loss, and the one whose meaning cannot be recovered from the words.

## `logician`

Reads definitions and arguments as formal objects. Reports circularity, equivocation between two senses of one word, a conclusion that does not follow, and an unfalsifiable claim dressed as a specification.

## What no reader here can judge

These rules reach nobody in this package. A review says so at every launch and first in its report, 
because a pass from a reader that cannot recognise the defect is indistinguishable from not looking.

- RULE.DOC.COORD_FREE needs a differential_geometry reader and GBGCodingTools declares none, so nobody judges it

