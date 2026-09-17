# Wiring GBGPeriodicFields — instructions for the PF session

Written 2026-09-17 by the GBGCodingTools session, after rehearsing the whole of it on a scratch clone
of PF at `8b15c967`. Nothing was committed to PF and nothing in PF was touched; the rehearsal ran in a
temporary directory outside Dropbox.

Read this whole file before running anything. It is written for the Claude session that works in PF.

## What you are doing, and what you are not

You are putting PF under `GBGCodingTools` for the first time. That means one new file PF owns
(`.gbg/config.jl`), a set of files GBGCodingTools writes, and then a report of everything the rulebook
finds in PF's documentation.

**You are not required to make PF clean.** The phase ends when PF's build and tests are green under
whatever PF declares — a rule PF does not accept is switched off in `.gbg/config.jl` with a written
reason, and that reason is rendered onto PF's own documentation site where a reader can weigh it. Fixing
and switching are both legitimate answers. Declaring nothing and leaving the build red is not.

## Step 1 — wire it

    gbg init

That writes `.gbg/config.jl` if PF has none, then writes everything that config generates. On the
rehearsal it wrote 15 paths and exited 0. Expect these, and know what each one does to a file PF
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

Everything except `.gbg/config.jl` is a **generated file**: it is the return value of a Julia function,
`gbg sync` rewrites it, and a hand edit is lost at the next sync. The wiring check reports drift on
every build so nothing is lost silently. If you want one of them different, the change belongs in
GBGCodingTools, not in PF.

**The pin.** `init` writes `tool = :dev`, which points `docs/Project.toml` at an absolute path to the
GBGCodingTools checkout on this machine. That is right only while 2.0.0 is unreleased. When
`v2.0.0-rc.1` is tagged, run `gbg bump 2.0.0-rc.1`; after that PF's environments carry a version, not a
path, and PF builds the same way on any machine and on CI.

## Step 2 — declare PF's file sets

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

## Step 3 — read what it finds

    gbg check

On the rehearsal, with the DEFAULT file sets (no rationale documents), PF reported **107 findings over
12 of the 97 rules**. Five more rules could not run at all without a built site or a loaded module; they
run inside `docs/make.jl` and `Pkg.test()` once PF calls them.

| Rule | Findings | What it is, and what I think of it |
|---|---|---|
| `RULE.TEX.ONE_SPAN` | 35 | One idiom of the module maps, mechanically fixable without losing the link — see below. |
| `RULE.DOC.SHAPE` | 30 | Paragraphs past the house cap: `convolve!` has one of 174 words, `exponential_convolve!` one of 232. Real prose work. |
| `RULE.DOC.LINKS` | 21 | The same target linked twice in one docstring, mostly in the long module maps. Each finding names both lines. |
| `RULE.DOC.ARGS_FORM` | 5 | Three-or-more arguments written as prose where the bulleted form is required, and one the other way. |
| `RULE.DOC.AI_BANNER` | 4 | Two Literate examples carry no provenance banner, two carry a drifted copy. |
| `RULE.DOC.SIGNATURE_MIRROR` | 3 | Displayed signatures 89–93 columns wide, past the house column. |
| `RULE.DOC.FIELDS` | 3 | A type whose field list does not document every field it has — genuine gaps. |
| `RULE.CIT.DOI` | 2 | Hockney & Eastwood and Brandt & Lubrecht are cited with no DOI on the title. |
| `SIBLING_LINK`, `MATHBF`, `BLOCK_LIST`, `SENTENCE_OPENER` | 1 each | One-line fixes, except `MATHBF`, which is a config line: PF must declare which `\mathbf{…}` strings it uses. |

### The largest class, `RULE.TEX.ONE_SPAN` (35), and how to fix it

Almost all 35 are one idiom of PF's module maps:

    - [`gradient`](@ref) ``\equiv \nabla`` raises the tensor order …

**Add a connective. Do not move the name into the formula.**

    - [`gradient`](@ref) (``\nabla``) raises the tensor order …

The rule matches a code span and a math span separated by nothing but whitespace, so any word or mark
between them satisfies it: `(``\nabla``)`, `— ``\nabla`` —`, `, which is ``\nabla``,`, `: ``\nabla```.
All four were run against `ONE_SPAN`, `REF_ABUT`, `CODE_IN_MATH` and `RENDERED_MATH`; none fires. The
edit is two characters a line.

The other form that satisfies the rule — putting the name inside the formula, which is what
`RULE.TEX.CODE_IN_MATH` prescribes for a name that is genuinely part of one — is WORSE here, and the
rendered HTML says why:

    [``\texttt{gradient} \equiv \nabla``](@ref gradient)
      → <a href="#gradient"><span>$\texttt{gradient} \equiv \nabla$</span></a>

    [`gradient`](@ref) (``\nabla``)
      → <a href="#gradient"><code>gradient</code></a> (<span>$\nabla$</span>)

Two things go wrong in the first. There is no `<code>` element at all: the name is set by the math
renderer's monospace font, so it loses the code styling every other function name on the page has, and a
reader scanning a forty-entry map for the things they can click loses the cue. And the whole formula
sits inside the anchor, so `≡` and `∇` are hyperlinks to `gradient`, which is not true of either.

`CODE_IN_MATH` is about a name that belongs to a formula — `\texttt{maxiter} \le n`, where the name is
an operand. Here the name is not an operand: the line says "this function IS that operator", which is a
relation between code and mathematics, not a formula containing both. Saying it with a connective is
what the sentence meant in the first place, and the rule is really pointing at the missing connective
rather than at the split formula its `why` describes.

## Step 4 — fix, or switch, and say which

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
