# Wiring GBGPeriodicFields — instructions for the PF session

Written 2026-09-17 by the GBGCodingTools session, after rehearsing the whole of it on a scratch clone
of PF at `8b15c967`. Nothing was committed to PF and nothing in PF was touched; the rehearsal ran in a
temporary directory outside Dropbox.

Read this whole file before running anything. It is written for the Claude session that works in PF.

**Every command is `gbg --dev`, not `gbg`.** While PF's pin is `:dev`, the installed shim refuses to run
in a package that is not inside the GBGCodingTools repository — deliberately, so a consumer cannot
silently resolve against an unregistered checkout. `gbg --dev <verb>` uses the checkout registered in
`~/.gbg/dev` and works from anywhere. This stops being necessary when PF pins a released version.

## What you are doing, and what you are not

You are putting PF under `GBGCodingTools` for the first time. That means one new file PF owns
(`.gbg/config.jl`), a set of files GBGCodingTools writes, and then a report of everything the rulebook
finds in PF's documentation.

**You are not required to make PF clean.** The phase ends when PF's build and tests are green under
whatever PF declares — a rule PF does not accept is switched off in `.gbg/config.jl` with a written
reason, and that reason is rendered onto PF's own documentation site where a reader can weigh it. Fixing
and switching are both legitimate answers. Declaring nothing and leaving the build red is not.

## Step 1 — wire it

    gbg --dev init

That writes `.gbg/config.jl` if PF has none, then writes everything that config generates. On the
rehearsal it wrote 16 paths and exited 0. Expect these, and know what each one does to a file PF
already has:

| Path | What happens |
|---|---|
| `.gbg/config.jl` | **new, and PF's own.** Never rewritten by any verb. Read it before committing. |
| `CLAUDE.md` | a marked block is inserted **at the head**; the rest of the file is untouched |
| `.gitignore` | a marked block is appended; the rest is untouched |
| `.claude/hooks/queue-guard.sh` | **overwritten whole.** PF's current hook is replaced by the fleet's, which differs: the fleet's version does not count items under a `## From the last review` heading. Read the diff before committing. |
| `.claude/settings.json` | PF's Stop hook entry is **merged in**; every other hook, permission and setting PF holds is kept |
| `test/regressions/README.md` | overwritten whole |
| `.gbg/policy/*.md` (8 files) | new: the rulebook, written from the rule values |
| `docs/Project.toml`, `test/Project.toml` | this package's `[deps]`, `[sources]` and `[compat]` entries set; every other entry kept |
| `.github/actions/gbg-auth/action.yml` | new: the composite action a workflow uses to fetch this package on a runner |

Everything except `.gbg/config.jl` is a **generated file**: it is the return value of a Julia function,
`gbg sync` rewrites it, and a hand edit is lost at the next sync. The wiring check reports drift on
every build so nothing is lost silently. If you want one of them different, the change belongs in
GBGCodingTools, not in PF.

**The pin, and what it blocks.** `init` writes `tool = :dev`, which points `docs/Project.toml` at an
absolute path to the GBGCodingTools checkout on this machine. `v2.0.0-rc.1` is tagged (2026-09-18) but
that does NOT change this: a prerelease is never pinned, and `gbg bump 2.0.0-rc.1` refuses with exit 2.
The candidate exists so `gbg install` can put a versioned CLI on each machine.

So until **2.0.0 final**, PF is wired for this machine only. Two consequences, both fine for now and
neither a thing to work around: PF's CI cannot resolve this package (a path source does not exist on a
runner), and the second host needs its own checkout at the same path. When 2.0.0 is cut, `gbg bump
2.0.0` moves the pin and rewrites everything that depends on it — and only then do the CI steps below
matter.

## Step 2 — hand the package to the tool, in three lines

`gbg init` writes files; it does not edit PF's own code. Three lines are PF's to add, and the wiring
check reports each until they are there.

**`test/runtests.jl`** — without this the test suite runs no rule of the rulebook, and is green about it:

    GBGCodingTools.Engine.Harness.test(dirname(@__DIR__); checks = (GBGCodingTools.Render.wiring,))

**`docs/make.jl`** — call `GBGCodingTools.makedocs(cfg; …)` in place of `Documenter.makedocs`, and write
the rules page before it, listing the returned path in `pages`:

    GBGCodingTools.Render.pages(GBGCodingTools.ConfigIO.read_config(ROOT), ROOT)

That page is how a reader sees the rules and what PF has switched off. Add `docs/src/gbg-rules.md` to
`generated` in `.gbg/config.jl` and to `.gitignore`, so no rule reads it — a page that states the rules
quotes every banned spelling in order to ban it.

**`.github/workflows/*.yml`** — once PF pins a released version, each workflow needs, after checkout and
before any `julia-actions` step:

    - uses: ./.github/actions/gbg-auth
      with:
        token: ${{ secrets.GBG_DEPS_TOKEN }}

Not yet, while the pin is a path: `ci_drift` reports nothing for a dev pin.

## Step 3 — declare PF's file sets

The seed config declares none, so the defaults apply: `src/**/*.jl` and `ext/**/*.jl` for code and
docstrings, `docs/src/**/*.md` for pages, `examples/**/*.jl` for Literate, `test/**/*.jl` for tests, and
**nothing for rationale**.

That last one matters: PF's `docs/ARCHITECTURE.md`, `FORMALIZATION.md`, `TESTING.md` and
`PERFORMANCE.md` — 19,700 lines — are not read at all unless PF names them. Decide deliberately whether
they are in scope. Naming them roughly triples what the rulebook reports, because those documents are
where PF's mathematics lives. Either answer is defensible; an undeclared default is not a decision.

    filesets = Dict(
        FileSet.RATIONALE => ["docs/ARCHITECTURE.md", "docs/FORMALIZATION.md",
                              "docs/TESTING.md", "docs/PERFORMANCE.md"],
    )

## Step 4 — read what it finds

    gbg --dev check

Measured on a clone of PF at `b18db597` on 2026-09-18, with the DEFAULT file sets (no rationale
documents): **108 findings over 13 of the 97 rules**, plus the two wiring findings Step 2 clears. Five
more rules cannot run without a built site or a loaded module; they run inside `docs/make.jl` and
`Pkg.test()` once PF calls them.

**These move as you work.** The same measurement at `8b15c967`, two hours earlier, gave 107 over 12 —
`ARGS_FORM` 5 → 7, `SIGNATURE_MIRROR` 3 → 1. Re-measure on your own HEAD; the table below is for
knowing which classes to expect and roughly how big each is, not for checking off a count.

| Rule | Findings | What it is, and what I think of it |
|---|---|---|
| `RULE.TEX.ONE_SPAN` | 35 | One idiom of the module maps, mechanically fixable without losing the link — see below. |
| `RULE.DOC.SHAPE` | 30 | Paragraphs past the house cap: `convolve!` has one of 174 words, `exponential_convolve!` one of 232. Real prose work. |
| `RULE.DOC.LINKS` | 21 | The same target linked twice in one docstring, mostly in the long module maps. Each finding names both lines. |
| `RULE.DOC.ARGS_FORM` | 7 | Three-or-more arguments written as prose where the bulleted form is required, and one the other way. |
| `RULE.DOC.AI_BANNER` | 4 | Two Literate examples carry no provenance banner, two carry a drifted copy. |
| `RULE.DOC.SIGNATURE_MIRROR` | 1 | A displayed signature past the house column. |
| `RULE.DOC.FIELDS` | 3 | A type whose field list does not document every field it has — genuine gaps. |
| `RULE.CIT.DOI` | 2 | Hockney & Eastwood and Brandt & Lubrecht are cited with no DOI on the title. |
| `SIBLING_LINK`, `MATHBF`, `BLOCK_LIST`, `SENTENCE_OPENER`, `RENDERED_MATH` | 1 each | One-line fixes, except `MATHBF`, which is a config line: PF must declare which `\mathbf{…}` strings it uses. |

### The largest class, `RULE.TEX.ONE_SPAN` (35)

Thirty-two of the 35 are one construct, with and without a link:

    - [`gradient`](@ref) ``\equiv \nabla`` raises the tensor order …
    Compute the gradient (`gradient` ``\equiv \nabla``) of a field …

PF is doing something the rulebook had no form for: **binding a code name to the mathematical object it
denotes**, so a module map can be read from either side — by someone who knows ``\nabla`` and wants the
function, or who knows `gradient` and wants the operator. GBGStreamingStatistics does the same thing in
its own prose. It is a real and recurring need in a mathematical package, and PF invented `≡` and
adjacency for it because nothing else was offered.

The rule now states the house form, and it is apposition — the two spans kept apart by a connective:

    - [`gradient`](@ref) (``\nabla``) raises the tensor order …
    Compute the gradient (`gradient`, ``\nabla``) of a field …

A parenthesis, an em dash, a comma or a colon all serve. `≡` is not a connective; it is the thing the
connective replaces, and dropping it is how mathematical writing has always done this — "the gradient
operator ∇", not "gradient ≡ ∇".

Do NOT move the name into the formula as `` ``\texttt{gradient} \equiv \nabla`` ``. That also satisfies
the check, and until 2026-09-18 the rule's own example recommended it, but it is worse: it emits no
`<code>` element, so the name is set in the math renderer's monospace and loses the styling every other
name on the page has, and a link wrapped round the whole formula makes `≡` and `∇` links to `gradient`.
`\texttt{…}` is for a name that is an OPERAND of the formula — `` ``\texttt{maxiter} \le n`` `` — which
is what `RULE.TEX.CODE_IN_MATH` is about.

The remaining three findings are not namings at all, just two adjacent facts (`` ``512^3`` `Float64` ``);
a connective fixes those too.

## Step 5 — what this package now owns, and what it does not

**This step applies to every package, not only PF.** Whoever adapts this file for the next one carries
it over unchanged.

`gbg init` installs a line at the head of your `CLAUDE.md`: *nothing restates a rule outside the
rulebook*. A package that has been developed for a year violates that from the minute it is wired,
because its own instructions grew before the rulebook existed. PF's `CLAUDE.md` is 2,753 lines and its
§Style is about 590 of them; GBGIsotropicTurbulence's is 505 and GBGStreamingStatistics' 680.
GBGCloudPhysics' is 134 and restates nothing, which is the proof that this is accumulated habit rather
than something wiring requires.

**No program finds the duplication.** Four measurements say so: no rule statement appears VERBATIM in
any of the four packages (0 of 97, every time), and a loose lexical match reports 158 candidates from
181 paragraphs. A middle threshold matches on document length rather than on content — 85 of 97 rules
"present" in PF's file and 12 of 97 in CloudPhysics', which measures only that one file is twenty times
longer. So this is a judgement a reader makes once per package, and the point of this step is to tell
that reader what to look for BEFORE they spend a day inside the file.

### The four kinds, and only two are this package's business

1. **Prose restating a rule.** The bulk of the problem. It goes, and the rulebook carries it.
2. **A mechanism this package has SUPERSEDED.** See the list below — and read the date on each.
3. **Conventions that are genuinely the package's own.** PF's representation qualifier trailing what it
   qualifies; "operators are not spectral". Another package will never want them and this one must not
   lose them. They become `PatternRule`s in `.gbg/config.jl`, so they are checked rather than merely
   written down.
4. **Records — closures, round artefacts, decision logs, cross-package requests.** Not style, not
   rules, and none of this package's business. Leave them alone. Filing them under "Style" is much of
   why one `CLAUDE.md` is five times another's.

### Superseded TODAY, with the evidence

- **A package's own prose-shape lint** — PF's `lint_prose_shape` in `docs/make.jl`. `RULE.DOC.SHAPE`
  reads the same baseline file, `docs/prose_shape.csv`, with the same keys: 381 of PF's 381 units match
  its recorded rows, and the rule reports 0. Same input, same verdict.
- **The end-of-turn hook** — `.claude/hooks/queue-guard.sh` is written by `Render.hook` and overwritten
  on every `gbg sync`. The fleet's version differs from PF's: it does not count items under a
  `## From the last review` heading.

### NOT superseded, however much it looks it

- **The four slash commands under `.claude/commands/`.** They are the package's OWN battery — a
  self-contained protocol that calls no `gbg` verb. This package's replacement, the
  `documentation_review` instrument, does not exist until Phase 4. Cutting them now removes a working
  capability and puts nothing in its place.
- **`test/exhaustive/` (1,003 lines in PF).** Its filenames — `checks.jl`, `selfcheck.jl`,
  `classify_checks.jl` — read like documentation linting and are nothing of the sort: it is a property
  sweep over the package's own operation surface (metadata, preservation, determinism, finiteness, type
  stability), plus a harness that checks ITSELF because every false finding it ever produced was a
  defect in the harness. Nothing here supersedes any of it. I nearly listed it as a candidate to cut,
  from the filenames, without opening the file.
- **Anything whose supersession you cannot demonstrate.** The test is not what a file is called or
  where it sits. It is: *this rule reads the same input and produces the same verdict*. Two of the three
  items I first believed were superseded failed that test, and one of them would have taken the most
  valuable testing in the package with it.

**A supersession has a date.** The question is never "does this package own that eventually" but "does
it own it today". Ask it item by item, and where the answer is Phase 4 or Phase 5, write that down and
leave the mechanism running.

### This reconciliation is not finished when the wiring is

Do not treat this step as a task with an end. Most of the conflicts have not happened yet, because most
of this package does not exist yet: the instruments arrive in Phase 4 and the last of the old engines
goes in Phase 5, and each of those supersedes something a consumer is still running. A mechanism that is
correct to keep today is one you will be asked to cut in two months, and you will not be asked by a
program — the list above is a snapshot with a date on it, not a contract.

Two consequences worth writing into the package's own notes rather than only acting on:

- **Record what you decided to keep, and why.** "The four slash commands stay until the
  `documentation_review` instrument exists" is worth one line in the package's `CLAUDE.md`, because the
  session that meets them in Phase 4 will otherwise re-derive the whole question, and may get it wrong
  in the other direction.
- **Expect the rulebook to move under you.** It has changed four times in the two days PF has been
  wired, twice because PF's own prose showed a rule was wrong. A finding that was correct last week may
  be gone, and prose you rewrote to satisfy a rule may now satisfy a different one. Re-measure before
  acting on any list older than a day; the counts in this document carry the date they were taken for
  exactly that reason.

## Step 6 — fix, or switch, and say which

A switch is a line in `.gbg/config.jl`:

    switches = [
        Switch(target = Symbol("RULE.DOC.SHAPE"), files = ["docs/PERFORMANCE.md"],
               reason = "the measurement tables here are one paragraph per run by design; \
                         splitting them would separate a number from the conditions it was measured under"),
    ]

Write the reason so that a reader who disagrees can argue with it. "Does not apply here" is not a
reason; it is the claim the reason is supposed to support. And before writing one, check that the rule
really cannot be satisfied — I claimed `ONE_SPAN` forced PF to drop its `@ref` links, and it does not;
a switch resting on that would have been a false record on PF's own site.

The reason is not a formality — it is rendered into `.gbg/policy/switches.md` and onto PF's site, and it
is the only thing a later reader has. Write it for them. A switch may also name files, so a rule can be
off for one document and on everywhere else.

## What the rehearsal already fixed, so you do not meet it

Wiring the scratch clone found nine defects in GBGCodingTools. All nine are fixed and pushed; the
numbers above are after the fixes. They are listed here so that if you see one of these shapes, you
know it is a tool defect and should be reported rather than worked around:

1. The `CLAUDE.md` block was appended to the **foot** of the file — on PF, line 2,744 of 2,753.
2. `.claude/settings.json` was written whole, which would have deleted PF's own hooks and permissions.
3. `gbg init` took the package name from the **directory**, not `Project.toml`.
4. Nothing refused a config whose name disagreed with `Project.toml`. That one wrong field turned every
   mention PF makes of its own name into an unlinked-sibling finding: 19 of them, 18 false.
5. The identifier pattern was ASCII-only in four places, so `φ::F` was not a field and the docstring
   documenting it was reported as documenting a ghost. There is now one Unicode-aware pattern.
6. `RULE.TEX.RENDERED_MATH` reported `⋅`, `×`, `64×64×64` and a call as mathematics-in-code. All eight
   of its PF findings were false.
7. `RULE.TEX.SPACING` reported every correct `\\,\\mathrm{d}x`: its exemption was written in the page's
   spelling, and a docstring must double every LaTeX backslash. All ten were false.
8. `RULE.TEX.CODE_IN_MATH` read `ck_a` and `ac - bd` as identifiers. Two letters is a product, not a
   name; the threshold is three now.
9. `RULE.DOC.LINKS` reported all 21 repeats at the docstring's first line, leaving you to search a
   seventy-line module map for the second link. Each names both lines now.

That is 39 false findings out of the 145 the first run produced. If a class of findings looks wrong to
you in the same way, it probably is — say so rather than editing PF to satisfy it.

## The gate

PF is done when `julia --project=docs docs/make.jl` and `Pkg.test()` both exit 0, `gbg sync --check`
is clean, and the tree is committed. Both commands run the rulebook themselves; there is no separate
step and no report to file.
