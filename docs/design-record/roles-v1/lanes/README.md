# catalog/lanes — the engine lanes (constants)

One TOML per instrument. A lane has `key`, `kind` (`code` | `prose` for the audit; `surface` | `cross` for
check-docs; `free` for the hunt), `anchor` (runs at full strength — a constant of the catalogue, never
config), and `brief` (the prompt body). Placeholders `{package.*}` and `{audit.guard_symbols}`,
`{audit.invariants}` are filled by the CLI. Consumer config can only ADD to these lists (`lanes_extra`
in check-docs, `territories` in the hunt); it can drop none.
