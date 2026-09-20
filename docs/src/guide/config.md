# [The config](@id config)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

`.gbg/config.jl` is the one file a [consumer](@ref install) writes by hand. It holds one `Config(…)` value
and is read as DATA: only literals and the constructors of `Model` are accepted, so a function call or an
interpolation is refused. `gbg init` writes a first one; `gbg sync` writes everything the config generates.

What it states: the package's name and the version it pins; its build and test commands; its file sets where
the defaults miss; its normative and rationale documents, copies and generated pages; the rules it switches off,
each with its reason; its values for rule parameters — the notation page, the formalization document, how a first
sentence leads, which admonitions need a title, the retired claims, the banner pages.

It also names the disciplines its readers need, from the tool's catalogue, its own pattern rules, and its code
areas. It writes no readers: one it needs and the tool lacks is requested from the tool's session.

The old reader of `.gbg/config.toml` remains until Phase 5:

```@docs
GBGCodingTools.Config.read
GBGCodingTools.Config.parse
GBGCodingTools.Config.surface_files
GBGCodingTools.Config.resolve_anchor
```
