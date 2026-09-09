<!-- gbg:managed policy/deviations.md vdev — rewritten by `gbg sync`; do not edit -->
# Declared deviations — GBGCodingTools

Rendered by `gbg sync` from `.gbg/exemptions.toml`: every live entry of scope `policy`, `scan`, `lint`
or `harness`. A rule listed here is disabled or refined for this package, with the reason and the date
it lapses; a reading model treats the rule as the entry states it.

- `RULE.TEST.ALLOC_ZERO` (scope policy, target `*`): no in-place operator over element storage exists here: this package's `!` functions mutate a registry, a dictionary or a string buffer, and an allocation bound on them measures the Julia runtime, not the package [recorded 2026-09-09, expires 2027-09-09]
- `RULE.TEST.PASS_AUDIT` (scope policy, target `*`): the traffic audit counts reads and writes per array element; this package holds no array whose traffic is a correctness property, so a frozen row would record the runtime's behaviour and nothing of the package's [recorded 2026-09-09, expires 2027-09-09]
- `RULE.TEST.EXAMPLES_RUN` (scope policy, target `*`): this package ships no Literate examples: its `literate` surface is empty by design, since a worked example of a review instrument is a round, which is recorded under .gbg/rounds/ rather than executed as a script [recorded 2026-09-09, expires 2027-09-09]
- `RULE.DOC.LEADING_IDENTITY` (scope policy, target `*`): the leading identity of a docstring is the physical meaning of the quantity it computes; this package computes no physical quantity, so its docstrings lead with what the operation does, which the rubric's own parameterisation already admits [recorded 2026-09-09, expires 2027-09-09]
- `RULE.API.POSITIONAL` (scope policy, target `*`): no program decides whether an argument affects the result: the rule is semantic, so no scan or doctor check can exist for it. It is `panel` in RULES.toml's `check` field — carried by a reading panel, which under `RULE.TEST.RULE_WITH_CHECK` is an answer and not an unpaid debt [recorded 2026-09-09, expires 2027-09-09]
