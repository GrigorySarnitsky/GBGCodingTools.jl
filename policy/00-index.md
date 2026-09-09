# GBGCodingTools policy — the shared rulebook

This directory is rendered into every consumer as `.gbg/policy/` by `gbg sync` and imported into the
consumer's `CLAUDE.md` through its managed block. It is ONE text for the whole fleet, at the version the
consumer pins; a package-specific rule lives in the package's own `CLAUDE.md`, outside the managed block,
and a rule a package deviates from is a ledger entry in `.gbg/exemptions.toml` with a reason, never an
edit here. Four values vary by package and are substituted at render time: the leading identity of a
docstring, the vector notation, the admonition-title rule and the admitted `\mathbf` strings; the
rendered `deviations.md` lists this package's declared deviations.

Every rule has a stable id in the `RULE.` namespace — `RULE.<FAMILY>.<NAME>` — recorded in `RULES.toml`
with its file, its one-line statement and its sentinel (the first sentence of its paragraph). The
scan catalogue names the rule each scan enforces, and a ledger entry of scope `policy` names the rule it
exempts; the doctor's `LEG.SENTINELS` check refuses a consumer `CLAUDE.md` that restates a rule verbatim
outside the managed block. Each rule's `check` field says what catches its next violation.

The files:

- `docs-rubric.md` — `RULE.DOC.*` and `RULE.API.*`: what a docstring and an API page contain, in what
  order and shape; the two-tier structure; one concept, one home; the doc-edit checklist.
- `latex-idiom.md` — `RULE.TEX.*`: rendered LaTeX, the house notation, the silent-rendering rules and
  the spacing and command idiom.
- `citations.md` — `RULE.CIT.*`: author–year style, DOIs, the inline full reference, no inaccessible source.
- `testing-protocol.md` — `RULE.TEST.*`: gate versus survey, oracle provenance, the definition of done,
  the allocation and traffic contracts, mutation, both directions, a rule with its check.
- `instruments.md` — `RULE.INST.*`: the consent gate, the four instruments, the witness rule, closure,
  seeds, no truncation, frozen mid-round, the cost policy, and the honest limits.
- `git-conventions.md` — `RULE.GIT.*`: commit ⇒ push, the trailer, manual CI, no shims, the branch,
  manifests, cross-package requests.
- `glossary.md` — the terms the rules use, bound once.

The rules load into a session with this index; the rendered copy under `.gbg/policy/` carries the
same lines, and `deviations.md` is this package's ledger of declared deviations:

@.gbg/policy/docs-rubric.md
@.gbg/policy/latex-idiom.md
@.gbg/policy/citations.md
@.gbg/policy/testing-protocol.md
@.gbg/policy/instruments.md
@.gbg/policy/git-conventions.md
@.gbg/policy/glossary.md
@.gbg/policy/deviations.md
