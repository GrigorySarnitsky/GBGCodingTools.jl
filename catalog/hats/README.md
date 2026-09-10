# catalog/hats — the generic hats

One TOML file per generic hat: `key`, `role` (one line), `substrate` (`full` — the whole rendered site incl.
the design docs; `siteonly` — the design docs withheld), `needs` (extra grants beyond the manuscript:
`source`, `rulebook`, `html`, `git`), `anchor` (runs at full strength; generic hats default `false`),
`persona` (the prompt body). Placeholders `{package.name}`, `{package.description}`, `{package.domain}`,
`{package.terms}`, `{package.deliberate_absences}`, `{package.rulebook_sections}` and `{policy.<file>}`
are filled by the CLI from the consumer's config when it renders the Workflow args. `{policy.<file>}`
reads the rendered `.gbg/policy/<file>.md` and no generic hat uses it today; a consumer's own domain hat
may, which is why `substitute` fills it. Domain hats never
live here: a consumer's are its own `.gbg/hats/*.toml` with the same fields.
