# templates/ — what `gbg sync`, `gbg init` and `gbg new` render

Every file here is a template the tool renders into a consumer. The renderer (`src/CLI/Sync.jl`)
substitutes `{{key}}` slots from the validated config and the running copy; a slot with no value is
an error, never an empty string. The class letters are those of ARCHITECTURE §4: **G** generated and
hash-managed (`.gbg/managed.json`; an edited copy is MODIFIED and refused), **S** seeded once and owned
by the consumer thereafter (wiring-checked, never rewritten).

| Template | Rendered as | Class | Slots |
|---|---|---|---|
| `SKILL.md.tmpl` | `.claude/skills/<name>/SKILL.md`, one per enabled instrument plus `gbg-doctor` | G | `{{skill.name}}`, `{{skill.description}}`, `{{skill.command}}`, `{{tool.version}}`, `{{package.name}}` |
| `settings.json.tmpl` | `.claude/settings.json` | G | none |
| `queue-guard.sh.tmpl` | `.claude/hooks/queue-guard.sh` (mode 755) | G | none — PF's Stop hook verbatim; it guards `.claude/WORK_QUEUE.md` and never reads `.gbg/rounds/` |
| `WORK_QUEUE.md.seed` | `.claude/WORK_QUEUE.md` | S | none |
| `CLAUDE.md.skeleton` | `CLAUDE.md` (by `gbg new`; the trim target at migration) | S + one G block | `{{package.name}}` |
| `claude-md.block` | the managed block inside `CLAUDE.md` | G | `{{tool.version}}`, `{{sha256}}`, `{{package.name}}`, `{{rubric.leading_identity}}`, `{{notation.vectors}}`, `{{deviations}}` |
| `gitignore.block` | the managed block inside `.gitignore` | G | `{{tool.version}}`, `{{docs.build_dir}}` |
| `make.jl.seed` | `docs/make.jl` | S | `{{package.name}}` |
| `runtests.jl.seed` | `test/runtests.jl` | S | `{{package.name}}` |
| `test-Project.toml.seed` | `test/Project.toml` | S + G entries | `{{package.name}}`, `{{package.uuid}}`, `{{tool.uuid}}`, `{{tool.url}}`, `{{tool.version}}` |
| `CI.yml.snippet`, `docs.yml.snippet` | three fragments each, inserted into `.github/workflows/{CI,docs}.yml` | S (the fragments are checked by `WIRE.CI_AUTH`) | `{{tool.banner}}` |
| `regressions-README.md` | `test/regressions/README.md` | G | `{{tool.version}}` |
| `commit-message.tmpl` | `.gbg/scratch/commit-message.txt` (by `gbg init --migrate`) | — | `{{tool.version}}`, `{{files}}` |
| `bump-message.tmpl` | `.gbg/scratch/bump-message.txt` (by `gbg bump`) | — | `{{from}}`, `{{to}}`, `{{files}}`, `{{abandoned}}` |

**Managed headers.** A G file carries a first-line header where its format allows a comment:
`# gbg:managed <template> v<version> — rewritten by \`gbg sync\`; do not edit` (`#`-commented
formats), `<!-- gbg:managed … -->` (Markdown), none for JSON (the sidecar is the record). The header
is part of the rendered bytes the sidecar hashes. One exception: `queue-guard.sh.tmpl` is copied
byte-for-byte from PF's Stop hook and carries no header, so the upstream text stays comparable; the
sidecar hash is what marks it managed. The two blocks have a shape of their own: `claude-md.block` and
`gitignore.block` are managed INSIDE a file the package owns, between a `gbg:managed begin v<version>`
line — in `<!-- … -->` in `CLAUDE.md`, whose opener also carries `sha256:<hash>` of the block's body
lines, and after `#` in `.gitignore` — and a `gbg:managed end` line; `sync` rewrites only what lies
between the two.

**Snippet fragments.** A `.snippet` holds three fragments, each opened by a line
`# gbg:fragment <auth|run|banner>` and closed by the next opener or the end of the file. `sync`
re-indents a fragment to the indentation of the workflow's `- uses: actions/checkout` step and
inserts: `auth` as the first step after `actions/checkout` (before any `julia-actions/*` step); `run`
in place of the job's build or test step, so its output is tee'd into `gbg-run.log`; `banner` as the
last step. A workflow with no `actions/checkout` step is refused, exit 2. No fragment runs Python.
