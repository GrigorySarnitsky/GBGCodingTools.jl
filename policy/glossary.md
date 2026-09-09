# Glossary — the terms the rules use

- **Consumer** — a package that pins the tool: the four GBG packages, and the tool repository itself.
- **Instrument** — one of the four review procedures: `/check-docs`, `/check-consistency`, `/bug-hunt`,
  `/audit-changes`. The word keeps its house meaning of a measuring device.
- **Round** — one run of an instrument, recorded as a tracked directory under `.gbg/rounds/`.
- **Lane / hat** — one agent of an instrument: a hat is a persona in the panel, a lane a surface or
  territory in the other three.
- **Anchor** — a hat or lane that runs at full strength instead of the economy model.
- **Gate** — a program whose non-zero exit blocks a build, a test run or a round's closure.
- **Pinned version** — the exact tool version a consumer names in `.gbg/config.toml`; the doctor's `PIN.*`
  checks compare it with what the sub-environments and the running copy resolve.
- **Managed file** — a file the tool renders into a consumer and hash-checks thereafter; edited only by
  `gbg sync`.
- **Ledger** — the consumer's one file of declared exceptions, `.gbg/exemptions.toml`. The bug-hunt's
  per-finding `fixed | refused | escalated` record is the disposition record, never "the ledger".
- **Witness** — a self-contained test asserting the correct behaviour of the package, observed to fail on
  a defective tree; the only admissible evidence of a code defect.
- **Home / map** — a function docstring is a home (it owns the operation's formula); a module docstring
  is a map (linked one-liners, no formulas).
- **Cold read** — parsing a docstring with the module's source and the design documents withheld; the
  acceptance test for self-containedness.
- **Class sweep** — treating a flagged instance as a sample and fixing every occurrence on every surface.
- **Estimand / estimator** — the population quantity an operation estimates, and the finite-sample rule
  that approximates it; where the package's leading identity is the estimand, the docstring states the
  first before the second.
- **Representation** — how an object is stored or computed (physical, spectral); an object is never
  named by its representation — "a field in spectral representation", never "a spectral field".
- **The house notation set** — upright `\mathrm{i}` and `\mathrm{d}`, coordinate-subscripted
  `\partial_{x_i}`, braced fraction and `\boldsymbol` arguments, no gratuitous `\,`, no manual spacing
  around relations, no `\left`/`\right`, `\mathbb` on capitals and `k` only; the vector notation and the
  admitted `\mathbf` strings are the package's own parameters.
