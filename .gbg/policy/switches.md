<!-- gbg:managed begin vdev — rewritten by `gbg sync`; do not edit -->
# What GBGCodingTools has switched off

Each entry names a rule this package does not hold itself to, and why. A rule listed
here is read as the entry states it.

- `RULE.TEST.EXAMPLES_RUN` — this package ships no Literate examples: a worked example of a review instrument is a review, which is recorded rather than executed as a script (the whole package)
- `RULE.DOC.LEADING_IDENTITY` — the leading identity of a docstring is the physical meaning of the quantity it computes; this package computes no physical quantity, so its docstrings lead with what the operation does, which the rule's own parameter already admits (the whole package)
- `documentation_review` — the review reads a package's documentation with the rulebook this package writes; running it here while the rulebook and the run machinery are still being built would grade the tool against rules it is in the middle of changing. It is switched on in Phase 8, when the tool reviews itself last (the whole package)

Deferred, not switched off: each of these is owed here and not yet met, and reports nothing
until the package meets it. What would close each is stated.

- `RULE.API.POSITIONAL` — until this package's own documentation review runs, in Phase 8: no program decides whether an argument affects the result, and the reader that does has not read this package yet

<!-- gbg:managed end -->
