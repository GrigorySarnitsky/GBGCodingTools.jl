<!-- gbg:managed begin vdev — rewritten by `gbg sync`; do not edit -->
# What GBGCodingTools has switched off

Each entry names a rule this package does not hold itself to, and why. A rule listed
here is read as the entry states it.

- `RULE.TEST.ALLOC_ZERO` — no in-place operator over element storage exists here: this package's `!` functions mutate a registry, a dictionary or a string buffer, and an allocation bound on them measures the Julia runtime, not the package (the whole package)
- `RULE.TEST.PASS_AUDIT` — the traffic audit counts reads and writes per array element; this package holds no array whose traffic is a correctness property, so a frozen row would record the runtime's behaviour and nothing of the package's (the whole package)
- `RULE.TEST.EXAMPLES_RUN` — this package ships no Literate examples: a worked example of a review instrument is a review, which is recorded rather than executed as a script (the whole package)
- `RULE.DOC.LEADING_IDENTITY` — the leading identity of a docstring is the physical meaning of the quantity it computes; this package computes no physical quantity, so its docstrings lead with what the operation does, which the rule's own parameter already admits (the whole package)
- `RULE.API.POSITIONAL` — no program decides whether an argument affects the result, and this package's own reading panels do not run over it yet; it is switched off here until they do (the whole package)
- `documentation_review` — the review reads a package's documentation with the rulebook this package writes; running it here while the rulebook and the run machinery are still being built would grade the tool against rules it is in the middle of changing. It is switched on in Phase 8, when the tool reviews itself last (the whole package)

<!-- gbg:managed end -->
