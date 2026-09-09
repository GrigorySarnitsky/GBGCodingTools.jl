# [Install](@id install)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

The tool reaches a machine in two ways, both per machine and never synced: the **pinned copy** Pkg
fetches into the consumer's `docs/` environment, and the **shim** `~/.local/bin/gbg` that executes it.

## The pinned version

Every sub-environment of a consumer that lists the tool (`docs/`, `test/`, `benchmark/`) carries the
same three entries, rendered by [`gbg sync`](@ref GBGCodingTools.Sync.sync) from the pinned version in
`.gbg/config.toml`:

```toml
[deps]
GBGCodingTools = "3aee1de0-bb62-4679-b1c5-a861fbcaaa51"
[sources]
GBGCodingTools = {url = "https://github.com/GrigorySarnitsky/GBGCodingTools.jl.git", rev = "v1.0.0"}
[compat]
GBGCodingTools = "=1.0.0"
```

`julia --project=docs -e 'using Pkg; Pkg.instantiate()'` fetches the tagged tree. The tool is never a
dependency of the package proper.

## The shim

```sh
julia --startup-file=no --project=docs -e 'using GBGCodingTools; exit(GBGCodingTools.main(ARGS))' -- install --dev-checkout "<dev checkout>"
```

[`gbg install`](@ref GBGCodingTools.cmd_install) copies `bin/gbg` to `~/.local/bin/gbg` and, with the
option, writes `~/.gbg/dev`. The shim is POSIX `sh`: it walks up to the nearest `.gbg/config.toml`,
reads the pinned version, and executes `julia --project=<root>/docs` on the copy that environment resolved — so
`gbg` in a consumer always runs that consumer's pinned version. One consumer is routed differently: a
consumer pinned at `dev` that is not itself the tool's checkout — the fixture, which sits inside that
checkout — resolves against the enclosing tool repository's root rather than its own `docs/`. `gbg --dev …`
runs the registered dev checkout instead; `GBG_DEV=1` marks it.

## The dev checkout

The owner's working tree of the tool is a consumer of itself: `gbg --dev init` at its root writes a
config pinned `dev`, `gbg --dev sync` renders its managed files, and its `docs/Project.toml` resolves the
tool by `path = ".."`. The doctor's `SELF.CONSUMER` check holds this in place.
