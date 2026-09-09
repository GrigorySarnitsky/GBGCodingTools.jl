# [The config](@id config)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

`.gbg/config.toml` is the one config file of a consumer: one layer, closed keys, validated by
`schema/config.schema.json` through the tool's own validator. `gbg init` writes it from the package tree;
`gbg config --toml` prints it with every default materialised; `gbg schema config` prints the schema.

The sections: `[tool]` (the pinned version), `[package]` (name, description, modules, the test and build
commands), `[paths]`, `[git]`, `[surfaces]` (the ONE copy of every surface list: rationale documents,
pages, generated copies, source, extensions, Literate examples, the built site, the history and
references anchors, the glossary file, and any data or script surface whose comments are prose), `[docs]` (doctest, admonition titles, the Base allowance, retired claims),
`[rubric]`, `[notation]`, `[citations]`, `[instruments]` with one table per instrument, `[cost]`,
`[schema]`, `[[scans.custom]]`.

Four values vary by package and are substituted into the rendered policy: `rubric.leading_identity`,
`notation.vectors`, `docs.admonition_titles`, `notation.mathbf_allowed` (which never forbids
`\mathbf{1}`, the indicator and identity every package is granted); the fifth variation point,
`instruments.check-docs.argcov_policy`, is a tier. Everything else about the instruments is a constant
of the tool, and changing one is a MAJOR release.

```@docs
GBGCodingTools.Config.read
GBGCodingTools.Config.parse
GBGCodingTools.Config.surface_files
GBGCodingTools.Config.resolve_anchor
GBGCodingTools.validate
GBGCodingTools.load_schema
```
