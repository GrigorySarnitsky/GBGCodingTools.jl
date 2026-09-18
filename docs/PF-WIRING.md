# Wiring GBGPeriodicFields — instructions for the PF session

Written 2026-09-18 by the GBGCodingTools session. Every figure below was re-measured on a fresh clone of
PF at `b18db597` after three adversarial passes over an earlier draft found the gate unreachable, the
counts stale, and five defects in this package's own code. Nothing was committed to PF and nothing in PF
was touched.

Read this whole file before running anything. It is written for the Claude session that works in PF.

**Every command is `gbg --dev`, not `gbg`.** While PF's pin is `:dev`, the installed shim refuses to run
in a package outside the GBGCodingTools repository — deliberately, so a consumer cannot silently resolve
against an unregistered checkout. `gbg --dev <verb>` uses the checkout registered in `~/.gbg/dev` and
works from anywhere. That applies to the gate commands at the foot of this file too.

**Run `gbg --dev init` from PF's root.** It walks up to the nearest `Project.toml`, so a subdirectory
still finds PF — but read the path it prints before going on.

**The numbers here are a shape, not a target.** The rulebook changed six times on 2026-09-18, four of
them because PF's own prose showed a rule was wrong. Re-measure; use the table to know which classes to
expect and roughly how big each is.

## What you are doing, and what you are not

You are putting PF under `GBGCodingTools` for the first time: one new file PF owns (`.gbg/config.jl`),
a set of files this package writes, three lines PF adds itself, then a report of what the rulebook finds.

**You are not required to make PF clean.** The phase ends when PF's build and tests are green under
whatever PF declares — a rule PF does not accept is switched off in `.gbg/config.jl` with a written
reason, rendered onto PF's own site. Fixing and switching are both legitimate. Declaring nothing and
leaving the build red is not.

**If PF is already wired**, `init` prints `.gbg/config.jl exists and is kept — this is 'gbg sync'` and
writes no config; `sync` then rewrites the generated paths. The table below will not reproduce, and the
diff will hold your own editorial work interleaved with the generated changes. Diffing against the last
commit before wiring is the only clean way to tell them apart.

## Step 1 — wire it

    gbg --dev init

On a fresh clone it wrote **17 paths** and exited 0: six modified, eleven new.

| Path | What happens |
|---|---|
| `.gbg/config.jl` | **new, and PF's own.** No verb regenerates it; `gbg bump` rewrites its `tool = …` line and nothing else. |
| `CLAUDE.md` | a marked block is inserted **at the head**; the rest is untouched |
| `.gitignore` | a marked block is inserted **at the head** too — not appended |
| `.claude/hooks/queue-guard.sh` | **overwritten whole.** PF's hook is replaced by the fleet's, which differs: the fleet's does not count items under a `## From the last review` heading. Read the diff. |
| `test/regressions/README.md` | overwritten whole |
| `.gbg/policy/*.md` | **nine** new files: the rulebook |
| `.github/actions/gbg-auth/action.yml` | new: the composite action a workflow uses to fetch this package on a runner |
| `docs/Project.toml`, `test/Project.toml` | this package's `[deps]` and `[sources]` entries set; every other entry kept |
| `.claude/settings.json` | **not touched on PF** — its Stop hook is already right. Where one is missing the entry is merged in, keeping every other hook and setting. |

The nine policy files, the hook, the regressions note, the ignore block, the CI action and the
`CLAUDE.md` block are **generated**: each is the return value of a Julia function, `gbg sync` rewrites
it, and a hand edit is lost at the next sync. The two `Project.toml`s and `settings.json` are
**entry-merged** — only this package's own entries are written, everything else kept.

**The pin, and what it blocks.** `init` writes `tool = :dev`, which puts an absolute path to the
GBGCodingTools checkout into both `Project.toml`s. `v2.0.0-rc.1` is tagged but does not change this: a
prerelease is never pinned, and `gbg bump 2.0.0-rc.1` refuses with exit 2. So until **2.0.0 final** PF is
wired for this machine only — its CI cannot resolve a path source, and a second host needs a checkout at
the same path. Consequences to expect, not problems to work around.

**Commit the new paths by name.** `.gbg/` and `.github/actions/` are untracked, and the fleet agreement
is `git add -u` plus new files by name. Staged with `-u` alone, the commit ships a `CLAUDE.md` whose
first line imports a file that is not in the repository.

## Step 2 — hand the package to the tool, in three lines

`init` writes files; it does not edit PF's code. Three lines are PF's own, and the wiring check reports
two of them until they are there. **`gbg sync` does not write these** — the report says "run `gbg sync`"
and is wrong about that; it is a known defect of the report, not a hint.

**`test/runtests.jl`** — without this, `Pkg.test()` runs no rule and is green about it. PF's `runtests.jl`
does not load this package, so the `using` is part of the change:

    using GBGCodingTools
    GBGCodingTools.Engine.Harness.test(dirname(@__DIR__); checks = (GBGCodingTools.Render.wiring,))

**`docs/make.jl`** — PF's loads `Documenter` but not this package, and defines no `ROOT`:

    using GBGCodingTools
    const ROOT = normpath(joinpath(@__DIR__, ".."))

then call the wrapper **with the package root**, in place of `Documenter.makedocs`:

    GBGCodingTools.makedocs(ROOT; sitename = …, pages = …)

It takes the ROOT, not a config object. An earlier draft said `makedocs(cfg; …)`, which needs the old
`.gbg/config.toml` that `gbg init` does not write — the gate was unreachable, and one of the three ways
a session would try to repair it passes the wiring check while the build dies.

Write the rules page before that call and list what it returns in `pages`:

    GBGCodingTools.Render.pages(GBGCodingTools.ConfigIO.read_config(ROOT), ROOT)

Add `docs/src/gbg-rules.md` to `generated` in `.gbg/config.jl` and to `.gitignore`. **Place the call
after PF's own lint block**, not before: those eight lints walk `docs/src` from disk and know nothing
about `generated`, so a rules page written before them becomes their input.

**`.github/workflows/*.yml`** — once PF pins a released version, each workflow needs, after checkout and
before any `julia-actions` step:

    - uses: ./.github/actions/gbg-auth
      with:
        token: ${{ secrets.GBG_DEPS_TOKEN }}

Not yet, while the pin is a path: `ci_drift` reports nothing for a dev pin.

## Step 3 — decide PF's file sets

The seed declares none, so the defaults apply: `src/**/*.jl` and `ext/**/*.jl` for code and docstrings,
`docs/src/**/*.md` for pages, `examples/**/*.jl` for Literate, `test/**/*.jl` for tests, and **nothing
for rationale**.

PF's `docs/ARCHITECTURE.md`, `FORMALIZATION.md`, `TESTING.md` and `PERFORMANCE.md` — 9,084 lines — are
therefore unread. Declaring them is a real decision and multiplies what is reported by about 3.4×
(65 → 220 on the clone), because those documents are where PF's mathematics lives.

    filesets = Dict(
        FileSet.RATIONALE => ["docs/ARCHITECTURE.md", "docs/FORMALIZATION.md",
                              "docs/TESTING.md", "docs/PERFORMANCE.md"],
    )

Declaring one set no longer disturbs the others — until 2026-09-18 doing so silently stopped
`RULE.DOC.SHAPE` reading PF's code and pages at all, which matters if you read an older copy of this
file.

**108 of those 220 would be `RULE.DOC.SHAPE` on the rationale documents, and they are not PF's to fix.**
See Step 5 before you declare them.

## Step 4 — read what it finds

    gbg --dev check

Measured on a fresh clone at `b18db597`, default file sets: **65 findings over 10 of the 97 rules**, plus
the two wiring findings Step 2 clears. Three more rules cannot run without a built site and two without a
loaded module; they run inside `docs/make.jl` and `Pkg.test()` once PF calls them.

| Rule | Findings | What it is |
|---|---|---|
| `RULE.TEX.ONE_SPAN` | 30 | The naming idiom — see below. |
| `RULE.DOC.LINKS` | 21 | The same target linked twice in one docstring, mostly in the long module maps. Each finding names both lines. |
| `RULE.DOC.AI_BANNER` | 4 | Three Literate examples carry no provenance banner; one carries a drifted copy. |
| `RULE.DOC.FIELDS` | 3 | A type whose field list does not document every field — see below. |
| `RULE.CIT.DOI` | 2 | Hockney & Eastwood and Brandt & Lubrecht, cited with no DOI on the title. |
| `RENDERED_MATH`, `SIGNATURE_MIRROR`, `MATHBF`, `SENTENCE_OPENER`, `BLOCK_LIST` | 1 each | One-line fixes, except `MATHBF` — a config line, given in Step 6. |

### `RULE.TEX.ONE_SPAN` (30)

All 30 are one idiom of PF's module maps:

    - [`gradient`](@ref) ``\equiv \nabla`` raises the tensor order …

**Add a connective; do not move the name into the formula.**

    - [`gradient`](@ref) (``\nabla``) raises the tensor order …

A parenthesis, em dash, comma or colon all serve, and `≡` disappears — it is not a connective, it is what
the connective replaces. The other form that satisfies the check, with the name set inside the formula as
`\texttt{…}`, is worse: it emits no `<code>` element, so the name loses the styling every other name on
the page carries, and a link round the whole formula makes each operator in it a link to the name.

An attributive modifier — a finished formula before the type it qualifies — is no longer reported at all,
so none of these 30 are that.

### `RULE.DOC.FIELDS` (3)

The owner has ruled: **report all fields, and drop any "user-readable" qualifier.** A full field list
helps a reader understand the architecture and shows up a bad one. The rule already does exactly this —
every bullet a real field, and every field a bullet — so all three findings stand, including the internal
`_FiberGather`, and no rule change is coming. A field documented in a paragraph rather than in the bullet
list does not satisfy it.

## Step 5 — what this package now owns, and what it does not

**This step applies to every package, not only PF.** Whoever adapts this file for the next one carries it
over unchanged.

`gbg init` installs a line at the head of your `CLAUDE.md`: *nothing restates a rule outside the
rulebook*. A package developed for a year violates that from the minute it is wired, because its own
instructions grew before the rulebook existed. PF's `CLAUDE.md` is 2,753 lines and its §Style about 572
of them; GBGIsotropicTurbulence's is 505 and GBGStreamingStatistics' 680. GBGCloudPhysics' is 134 and
restates nothing, which shows this is accumulated habit rather than something wiring requires.

**No program finds the duplication.** The one reproducible measurement is that no rule statement appears
VERBATIM in any of the four packages — 0 of 97, every time — because nobody copy-pastes a rule, they
paraphrase it. Looser matching was tried and abandoned; those figures are not reproducible from anything
in the repository and are not quoted here. So this is a judgement a reader makes once per package, and
this step exists to tell that reader what to look for before they spend a day inside the file.

### The four kinds, and only two are this package's business

1. **Prose restating a rule.** The bulk. It goes, and the rulebook carries it.
2. **A mechanism this package has SUPERSEDED.** Read the list below, and the date on each.
3. **Conventions genuinely the package's own.** PF's representation qualifier trailing what it qualifies;
   "operators are not spectral". Another package will never want them and this one must not lose them.
   They can be recorded as `PatternRule`s in `.gbg/config.jl` — but **nothing executes a `PatternRule`
   today**: it is rendered onto the switches page and checked by nothing. Do not trade a live convention
   in `CLAUDE.md` for one on the promise that it is enforced.
4. **Records — closures, round artefacts, decision logs, cross-package requests.** Not style, not rules,
   and none of this package's business. Leave them alone.

### Superseded today, with the evidence

- **The end-of-turn hook.** `.claude/hooks/queue-guard.sh` is written by `Render.hook` and overwritten on
  every `gbg sync`.

That is the whole list.

### NOT superseded, however much it looks it

- **PF's `lint_prose_shape`.** An earlier draft told PF to delete it and was wrong twice over. With the
  default file sets `RULE.DOC.SHAPE` reaches 381 of the 639 rows in `docs/prose_shape.csv` — PF's lint
  also reads `docs/*.md` and `docs/src/api/*.md`, which the defaults do not. Declare the rationale
  documents to close that gap and the two disagree outright: the rule reports **108 GREW findings** on
  units PF's lint passes, because for a numbered top-level item PF's lint does not push the item's own
  line into the unit and `Rules.Shape.units` does. Same baseline file, same keys, **different metrics**.
  Keep the lint. Raising a ceiling is `PROSE_SHAPE_BASELINE=1` inside it, and there is no replacement for
  that yet.
- **The four slash commands under `.claude/commands/`.** They are PF's OWN battery — a self-contained
  protocol calling no `gbg` verb. This package's replacement, the `documentation_review` instrument, does
  not exist until Phase 4. Cutting them removes a working capability and puts nothing in its place.
- **`test/exhaustive/` (7,177 lines).** Its filenames read like documentation linting and are nothing of
  the sort: a property sweep over PF's own operation surface — metadata, preservation, determinism,
  finiteness, type stability — plus a harness that checks itself. Nothing here supersedes any of it.
- **Anything whose supersession you cannot demonstrate.** The test is not what a file is called or where
  it sits: *this rule reads the same input and produces the same verdict*. Of the three items an earlier
  draft certified, two failed that test, and one would have taken the most valuable testing in the
  package with it.

**A supersession has a date.** The question is never "does this package own that eventually" but "does it
own it today". Where the answer is Phase 4 or Phase 5, write that down and leave the mechanism running.

### This reconciliation is not finished when the wiring is

Most of the conflicts have not happened yet, because most of this package does not exist yet: the
instruments arrive in Phase 4 and the last of the old engines goes in Phase 5, and each supersedes
something a consumer is still running. A mechanism correct to keep today is one a later session will be
asked to cut — by a person, not a program.

- **Record what you decided to keep, and why.** "The four slash commands stay until `documentation_review`
  exists" is one line in PF's `CLAUDE.md` that saves the Phase 4 session re-deriving the question, and
  possibly getting it wrong the other way.
- **Expect the rulebook to move under you.** Re-measure before acting on any list older than a day.

## Step 6 — fix, or switch, and say which

A switch is a line in `.gbg/config.jl`:

    switches = [
        Switch(target = Symbol("RULE.DOC.LINKS"), files = ["src/Convolution.jl"],
               reason = "the module map links each operation where it is introduced and again in the index, for a reader arriving from elsewhere"),
    ]

Keep the reason on one line. It is rendered into `.gbg/policy/switches.md` and onto PF's site, and a Julia
line continuation inside the string lands a stray backslash there.

A per-file switch works on every rule now; until 2026-09-18 it was a silent no-op on any rule reading the
tree, the built site or the loaded module, while its reason was published regardless.

A variant is a `Setting`. This is the whole of the `RULE.TEX.MATHBF` remedy:

    settings = [
        Setting(rule = Symbol("RULE.TEX.MATHBF"), name = :mathbf_allowed, value = ["\\mathbf{k}"]),
    ]

**A malformed `.gbg/config.jl` is fatal, not a finding.** Both `Pkg.test()` and the docs build read it
before anything else and neither guards the read, so a typo — a switch naming an id that is not a rule, a
`Setting` whose `name` is a string rather than a symbol — is a red suite and a dead build. Run
`gbg --dev check` after any config edit; it reports the same error as exit 2, with the line.

Write the reason so a reader who disagrees can argue with it. "Does not apply here" is not a reason; it is
the claim a reason should support. And check the rule really cannot be satisfied first — an earlier draft
of this file asserted a conflict between the rulebook and PF's house style that did not exist.

## The gate

PF is done when `julia --project=docs docs/make.jl` and `Pkg.test()` both exit 0, `gbg --dev sync --check`
is clean, and the tree is committed. Both commands run the rulebook themselves; there is no separate step
and no report to file.

## What the rehearsals and the adversarial passes already fixed

Fourteen defects in this package: nine from rehearsing the wiring, five from three adversarial passes over
an earlier draft of this file. Listed so that if you meet one of these shapes you know it is a tool defect
to report rather than something to work around.

1. The `CLAUDE.md` block was appended to the FOOT of the file — on PF, line 2,744 of 2,753.
2. `.claude/settings.json` was written whole, which would have deleted a package's own hooks.
3. `gbg init` took the package name from the DIRECTORY, not `Project.toml`.
4. Nothing refused a config whose name disagreed with `Project.toml` — 19 findings, 18 of them false.
5. The identifier pattern was ASCII-only, so `φ::F` was not a field and the docstring documenting it was
   reported as documenting a ghost.
6. `RULE.TEX.RENDERED_MATH` reported `⋅`, `×`, `64×64×64` and a call as mathematics set in code.
7. `RULE.TEX.SPACING` reported every correct differential: its exemption was written in the page's
   spelling, and a docstring doubles every LaTeX backslash.
8. `RULE.TEX.CODE_IN_MATH` read two-letter products as identifiers.
9. `RULE.DOC.LINKS` reported every repeat at the docstring's first line.
10. `makedocs` needed a config file `gbg init` does not write — the gate was unreachable.
11. Declaring a file set silently stopped `RULE.DOC.SHAPE` reading anything else.
12. A per-file switch was a no-op on most rules, while its reason was published.
13. `gbg init` wired the working directory rather than the package.
14. `Setting(value = […])` was refused, so `MATHBF`'s only remedy could not be written.

If a class of findings looks wrong to you in the same way, it probably is — say so rather than editing PF
to satisfy it.
