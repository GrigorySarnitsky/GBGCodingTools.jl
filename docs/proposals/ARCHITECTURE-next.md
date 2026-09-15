# GBGCodingTools — architecture

This is the target design, and it is normative: code that disagrees with it is wrong, or this document changes
first. Where a choice belongs to the owner, the body follows the owner's standing ruling (or states the default
chosen) and §14 asks the question. A term in **bold** is defined where it first appears. The reason for each
mechanism is given in brackets: a requirement R1–R11 from the owner, or a failure observed in use.

Not in this document: the migration order (`IMPLEMENTATION.md`); history and evidence, including the replaced
architecture (`docs/design-record/`).

## 1. Purpose and scope

GBGCodingTools is a Julia package, on the Julia 1.12 floor. It keeps the owner's Julia packages written to one set
of rules, and it helps AI sessions find and fix defects in them without breaking how they work. It serves the four
science packages — GBGPeriodicFields, GBGIsotropicTurbulence, GBGStreamingStatistics, GBGCloudPhysics — and itself.
Each of the five is a **package** below; the **owner** is the person who owns them; a **session** is one Claude Code
conversation working in a package.

It does four things:
1. It holds the **rulebook**: every rule on how documentation and code are written. Each rule is a Julia value that
   carries its statement, the check that decides a violation, and examples that break and comply with it [R5, R7].
2. It runs the rules' program checks inside each package's documentation build and test suite, always [R7].
3. It provides **instruments**: procedures the owner asks a session to run, which find defects. Documentation
   defects are fixed without the owner and the fixes are checked; code defects are put to the owner [R1, R2].
4. It generates every file that connects a package to the tool, so the five packages carry the same files [R6].

It is not: needed by anyone who only uses a science package (it is a docs and test dependency); a reviewer that runs
without being asked; a place for plans or history; and not a defence against a session that forges files. It guards
against honest, overconfident mistakes: a program, not a session, decides whether a change is safe and when work
stops.

A **finding** is one reported defect with every place it occurs. A **run** is one execution of one instrument on
one package. An **agent** is a model instance a session launches to read and report. A **failing test** is a small
test, written by an agent, that fails on the package as it is. **Full strength** is the most capable model;
**economy**, the default, is a cheaper one. Every `gbg` command exits 0 (nothing found), 1 (findings), 2 (cannot
evaluate) or 3 (crash); no verdict is read from a log, and no check's output is shortened.

## 2. How the checks and instruments differ

The owner's three distinctions are used, each with one value per check or instrument [R3, R4]:

- **Intention** — what the defects it looks for are in. *Documentation*: docstrings, comments, hand-written pages
  and rationale documents, as §4.2 lists exactly. *Code*: everything else, including stored data that code reads.
  The future leak check alone has a third value, *publication*, because a leaked password is neither [R8].
- **Decided by** — who says a finding is real. *A program*; *an agent proposes and a program decides* (the agent
  writes a failing test and the finding exists only if the tool runs it and it fails); *an agent*, quoting the text.
- **How found issues are fixed** — *the documentation fixer* (automatic, checked); *the code fixer* (only on the
  owner's answer, checked); *regenerated* by the tool; *by the owner only*.

No two rows of the table in §3 have the same three values; `test/architecture.jl` reads the three columns and fails
on a repeat. No further distinction is needed to separate the rows. Every rule an agent checks belongs to exactly
one agent role (§5), and a test checks this too.

## 3. The table

**Always-on checks** are programs run by every build or test; nobody starts them and they have no runs [R7].
**Instruments** run only when the owner asks, in words or by slash command (standing ruling; §14 Q2). Outside a
run, a session fixes failures in its own work; the two fixers handle defects the tool finds.

| | Purpose | Intention | Decided by | How found issues are fixed | When it runs | A run ends when |
|---|---|---|---|---|---|---|
| **Documentation checks** (always on) | Documentation has the house structure and formatting and renders as written; re-running the check verifies a fix | Documentation | A program | Documentation fixer | Every docs build | — |
| **Code checks** (always on) | The code keeps its tested contracts and every accepted failing test passes | Code | A program | Code fixer | Every `Pkg.test()` | — |
| **Wiring check** (always on) | Every generated file or part of a file equals its generator's output | Code | A program | Regenerated | Whenever `gbg sync`, `gbg bump` or `gbg release` runs | — |
| **Documentation review** | Documentation is true to the code, correct, consistent and self-contained; the change guard, the checks and a verifier agent check each fix | Documentation | An agent | Documentation fixer | Owner's request | Nothing is open, or the budget is spent |
| **Bug hunt** | The code does what its documentation says | Code | An agent proposes, a program decides | Code fixer | Owner's request | Every candidate is confirmed or discarded, once |
| **Change audit** | A code change is no wider than its reason and still accepts input that worked before; the audit itself changes nothing | Code | An agent | Code fixer | Owner's request | One pass over the change |
| **Leak check** (future) | Nothing secret or personal is published when a repository is made public; findings never enter a tracked file | Publication | A program | Owner only | Owner's request | One pass over every branch, commit and message |

The standing ruling counts each code fix as a request for one Change audit (§4.4; §14 Q5). Documentation review and
Bug hunt can meet one disagreement between a docstring and its code from opposite sides: the review reads and
compares, the hunt reports only what a failing test shows. Either way a possible code defect reaches the owner as a
question, and an answered question never returns (§8). Reading documentation beside its code and reading the
rendered site without it differ only in what agents read, so they are one instrument with two groups of agents
(§5.2). The leak check attaches later by adding its rules, a reader of every branch, commit message and
`Manifest.toml` path, and one `Instrument` value. One function, `Guard.refuse_publication`, is called by every writer
of a tracked file — run record, report, question store, settled-rulings file — and exits 2 on text from a
publication run [a committed record would publish the leak it found].

## 4. Finding and fixing

```
FINDING PARTS                        FIXING PARTS
Documentation review ─┐              ┌─ about documentation ─► DOCUMENTATION FIXER ─► guarded commit
Bug hunt ─────────────┼─► collect ───┤     ─► checks ─► verifier, blind then with the diff ─► closed or open
Change audit ─────────┘              └─ about code ─► question to the owner ─► answer:
                                          "fix the code" ─► CODE FIXER ─► the failing test now passes,
                                               tests pass ─► commit ─► Change audit ─► owner keeps or reverts
                                          "fix the documentation instead" ─► DOCUMENTATION FIXER
                                          "not a defect" ─► optionally recorded as settled (§8)
```

An always-on check has no run: a failing build or test goes straight to the fixer named in its §3 row.

### 4.1 Finding, and the handoff

The checks and instruments find; none fixes [R1]. Agents write one result file each into a scratch directory and
nothing else: **collect** (the step that turns agent files into findings) exits 2 when a tracked file changed while
agents ran. An agent whose file is missing or malformed is relaunched once, then named in the report. Collect gives
each finding an id and fixes the list, so a run never searches twice [fresh searches over edited files never
settled: 90 → 40 → 21 findings in one package; hunts of 20, 9, 17, 21, 17 in another]. A location in a declared
build-time copy (a page `docs/make.jl` copies from a tracked file) is mapped to the same line of its tracked source
when the copy is identical to it, and is otherwise dropped and named in the report [fixes landed in a copy the build
then overwrote].

A finding goes to the documentation fixer when its instrument's intention is documentation and its agent did not
mark it as a possible code defect; otherwise it becomes a question. The change guard has the last word (§4.2).

### 4.2 What is documentation, and the change guard

**Documentation** is exactly: docstrings and comments in `.jl` files under `src/` and `ext/`; hand-written Markdown
under `docs/src/`; the package's `README.md`; and the rationale documents the config names. **Everything else is
code** [R2]: other `.jl` files, whole (tests, `docs/make.jl`, Literate scripts, whose comment marks decide what runs);
`Project.toml` and `Manifest.toml`; the config; stored data code reads, in any format; every generated path and
declared copy (§6); CI, hook and skill files; `CLAUDE.md`; any document the config declares normative, which wins
over "rationale" (this document, for the tool) [a fix aligning a specification with code would authorise that code];
and, in this tool, every rule, agent role and instrument value with its text.

The **change guard** is the program `Guard.classify(cfg, path, before, after)`. It returns documentation only when all
of these hold, and code otherwise:
1. the path is on the documentation list, and is neither a generated path nor a declared copy;
2. for `.jl`: both versions parse; removing line numbers, plain string literals standing alone at top level or in a
   struct body (unattached and field docstrings), and docstrings whose text is a plain or `raw"…"` literal and whose
   target is a definition, leaves the same parsed code. A docstring whose target is a call, or a macro call other
   than a defining one (`@kwdef`, `@enum`), in either version, makes the change code: Julia then documents the call
   instead of running it. A docstring with `$(…)`, or a computed `@doc` argument, is never removed;
3. no changed comment contains a Literate mark (`#src`, `#md`, `#jl`, `#nb`);
4. in every removed docstring and every changed page, every fenced block whose info string starts with `jldoctest`
   or `@` is identical, info string included, and in the same order — this covers doctest input and output,
   `@example`, `@eval`, `@setup`, `@meta`, `@raw`, and the signatures and filters of `@docs`, `@autodocs`, `@index`
   and `@contents`, which Documenter evaluates.

Accepted limit: a longer docstring shifts what `@__LINE__` returns. `test/guard.jl` holds one example per clause, in
both directions [parsed code alone passed changed doctest output, a `@autodocs` filter, and a docstring that stopped
a call from running].

### 4.3 The documentation fixer — automatic, with checks

The documentation fixer is the session at full strength, working through `gbg docfix` steps [R1, R2].
1. **Other copies.** Before fixing, a program searches every documentation file for the finding's quoted text and
   for each formula in it, and adds every hit as a possible further location [a fourth copy of a corrected formula
   survived a fix].
2. **Guarded commit.** The fixer edits, then `gbg docfix commit` classifies every changed path in the working tree
   with the change guard and makes the commit only if all are documentation; otherwise it exits 1 and commits
   nothing. The session then pushes. This is the one verb that commits, because the guard must run before a commit
   exists; it replaces the current rule that no verb commits [a code edit committed before the guard ran would be
   pushed].
3. **Formula edits.** An edit that changes mathematics — inside a math span: a symbol, a number or a sign; years in
   citations do not count — is made automatically only when the fixer both quotes an expression from the body of the
   documented method that agrees with the new text and supplies a numeric check: a few lines of Julia, run by the
   program in scratch, that evaluate the new formula and the method on one input and pass. Otherwise the finding
   becomes a question. Formula edits are verified at full strength and listed in the report [a docstring was "fixed"
   to contradict code that was itself wrong; a fix wrote false mathematics].
4. **Checks.** `gbg docfix check` runs the documentation checks, doctests and docs build; a check that passed at the
   run's first commit and fails now is exit 1.
5. **Verifier, blind first.** `gbg run next` writes the blind stage's arguments. A verifier agent reads, in a copy of
   the tree exported without git history, each finding, the current text at its locations and of every region the
   pass changed, and the code that text documents — without the old text or the fixer's explanation. It answers
   `FIXED`, `NOT_FIXED`, `HIDES_CODE_DEFECT` (the documentation now describes code that looks wrong) or
   `NOT_A_DEFECT`. Only after that stage is collected does `gbg run next` write the second stage, for `FIXED`
   findings only, which is given the diff and may answer `LINE_ONLY` (fixed at some locations only) or `MADE_WORSE`
   [blind reading caught false mathematics; a verifier shown the diff caught 11 of 13 fixes made at one line only].
6. **Grade.** A program applies the verdicts. Every verdict except `NOT_FIXED` needs a quote the program finds in the
   current text, or it becomes `NOT_FIXED`. `MADE_WORSE` reverts the edit. `HIDES_CODE_DEFECT` reverts the edit and
   turns the finding into a question — unless the owner already answered "fix the documentation instead", in which
   case the edit stands and the verdict is listed. A `NOT_A_DEFECT` closes the finding for this run and is listed,
   never stored.
7. **Passes.** Open findings return to step 1, up to 4 passes [the share of fixes verified rose over four passes
   (16 → 39 → 55 → 74 % in one package; 43 → 69 → 76 → 95 % in another, then 93 and 90)].

### 4.4 The code fixer — only on the owner's answer

The code fixer is the session making a code change the owner asked for [R2].
1. A code finding becomes an item of a question (§8). Nothing is changed. A run's code findings form one question
   with an answer per item [a hunt confirms 9 to 21 defects; one question each costs the owner hours].
2. On "fix the code", the session changes the code. A program checks that each failing test fails before the change
   and passes after it, and that `Pkg.test()` and the docs build pass. A change that fails these is not committed and
   its failure becomes a question, rather than further attempts.
3. The change is committed straight to `master` and pushed (standing ruling; §14 Q1). Failing tests of unanswered
   questions wait in `test/regressions/escalated/` (standing ruling), which `Pkg.test()` never runs. On "fix the
   code" and a passing change, the test moves unchanged into `test/regressions/`; on any other answer it is deleted.
4. Change audit runs once over the change (standing ruling; §14 Q5). The owner is then asked, as a `Question` whose
   exhibit the program writes (the commits, changed files and definitions, and the audit's concerns), whether to
   keep or revert. A concern the owner wants fixed is a new change, audited in turn. `gbg release` refuses while a
   keep-or-revert question about a commit in the release is unanswered.

## 5. The Julia object model

### 5.1 Modules, types first

Each module uses only the modules above it, and no build or test refers to `Orchestration`, where run records live;
`test/architecture.jl` parses the sources and fails on any reference, qualified or imported, that breaks either rule
[types spread over behaviour modules force import cycles].

```
Model          every struct and enum; no behaviour, no values
Texts          reading docstrings, pages and the built site, given a Config value
Catalogue      RULES (src/Rules/*.jl, each rule beside its check functions), INSTRUMENTS, ALWAYS_ON, agent roles,
               and GENERATED, the registry of generated paths, as data
ConfigIO       the literal-only readers of config.jl and settled.jl; validate; applies
Engine         Checks, Harness, Guard, Questions.check's programs  ← Pkg.test() uses nothing below this line
Render         the generators and the wiring check                ← the docs build uses nothing below this line
Orchestration  Agents (arguments), Runs, Measure
CLI            the gbg verbs, each a function returning an exit code
```

### 5.2 Types

Enums are scoped (`module Decider; @enum T …; end`) so values of different enums never share a name.

```julia
module Intention; @enum T DOCUMENTATION CODE; end          # PUBLICATION arrives with the leak check
module Decider;   @enum T PROGRAM FAILING_TEST AGENT; end
module Fixer;     @enum T DOCUMENTATION_FIXER CODE_FIXER REGENERATE OWNER_ONLY; end
module Input;     @enum T SOURCE_TEXT FILE_TREE LOADED_MODULE BUILT_SITE QUESTION; end
module FileSet;   @enum T DOCSTRINGS PAGES RATIONALE LITERATE CODE TESTS; end
module Strength;  @enum T ECONOMY FULL; end
module Verdict;   @enum T FIXED NOT_FIXED LINE_ONLY MADE_WORSE HIDES_CODE_DEFECT NOT_A_DEFECT; end
module Stop;      @enum T DONE BUDGET_SPENT CANNOT_EVALUATE OWNER_STOPPED; end
module WhyAgent;  @enum T MEANING DERIVATION READING_ORDER; end
module Part;      @enum T WHOLE BLOCK TOML_ENTRIES; end

"A place: a path relative to the package root (a field name, for a question), and a line."
struct Location; file::String; line::Int; end

"What an agent or a check reports, before a run gives it an id."
Base.@kwdef struct FindingDraft
    rule::Union{Symbol,Nothing}; locations::Vector{Location}   # every site of the defect
    claim::String; evidence::String; fix::String               # evidence: a quote, or a failing test's path
    maybe_code::Bool = false                                   # the agent thinks the code, not the text, is wrong
    serious::Bool = false                                      # holds back this tool's final release while open
end

"One defect in a run: the draft, its id, and who reported it."
struct Finding; id::String; source::Symbol; decider::Decider.T; draft::FindingDraft; end
```

A **file set** is a named set of a package's files, found by default patterns the config may override. A check's
**input** is what it reads: a source text, a small file tree, the loaded package, the built site, or a question.

```julia
"A possible answer, with what happens if it is chosen and what it costs."
struct Option; label::String; consequence::String; recommended::Bool; end

"One decision inside a question; several items share the question's options."
struct Item; text::String; recommended::String; sources::Vector{String}; end

"A decision put to the owner; plain data, checked only when it is put."
Base.@kwdef struct Question
    id::String; decision::String; context::String; options::Vector{Option}
    items::Vector{Item} = Item[]
    exhibit::String = ""              # commits, changed files and definitions: exempt from the language rules
    answer::Union{String,Nothing} = nothing
end

"What decides a violation: a program, or an agent for one of the reasons in WhyAgent."
abstract type Check end
struct ProgramCheck <: Check; input::Input.T; run::Function; network::Bool; end  # run(x, cfg)::Vector{Location}
struct AgentCheck   <: Check; question::String; why::WhyAgent.T; end

"Something a rule's check must judge a known way; `expect` lists the locations it must report, empty if it complies."
abstract type Example end
struct TextExample     <: Example; fileset::FileSet.T; text::String; expect::Vector{Location}; clause::String; end
struct TreeExample     <: Example; files::Vector{Pair{String,String}}; expect::Vector{Location}; clause::String; end
struct ModuleExample   <: Example; source::String; expect::Vector{Location}; clause::String; end
struct SiteExample     <: Example; pages::Vector{Pair{String,String}}; expect::Vector{Location}; clause::String; end
struct QuestionExample <: Example; question::Question; expect::Vector{Location}; clause::String; end

"A value a rule reads that a package may set, such as how a docstring's first sentence leads."
struct Parameter{T}; name::Symbol; default::T; end

"One rule of the rulebook."
Base.@kwdef struct Rule
    id::Symbol; statement::String; why::String   # statement: the rule in plain English, its only home
    intention::Intention.T                       # documentation rules run in the docs build, code rules in Pkg.test()
    filesets::Vector{FileSet.T}
    check::Union{ProgramCheck,AgentCheck,Nothing}
    unchecked_reason::String = ""                # required when check is nothing
    parameters::Vector{Parameter} = Parameter[]
    examples::Vector{Example}
end
```

Program rules whose input is a question run when a question is put (§8); agent-checked rules run only inside
instruments. `test/rules.jl` materialises every example — a text; a temporary file tree; a source string loaded into
a fresh module; all site examples in one Documenter build with warnings allowed, each page in its own directory (a
strict build writes nothing once one example breaks) — and requires the check's locations to equal `expect`. Every
clause needs a breaking example and a complying text that differs from a breaking one as little as possible [a
yes/no example passes a check that always fires; about 25 of today's 59 coded rules read file trees, the loaded
package or the built site]. An agent-checked rule carries at least one breaking `TextExample`, used by measurement.

```julia
"One kind of agent an instrument launches: what it reads, what it is kept from, and which rules it checks."
Base.@kwdef struct AgentRole
    id::Symbol; instrument::Symbol
    reads::Vector{FileSet.T}; site::Bool = false; kept_from_code::Bool = false
    description::String                  # who the reader is, in two or three sentences
    rules::Vector{Symbol}                # AgentCheck rule ids; empty makes an open reader
    strength::Strength.T = Strength.ECONOMY
    cap::Int                             # distinct defects reported; the agent states how many it left out
end

"The ceiling on one run; reaching any part of it ends the run."
Base.@kwdef struct Budget; fix_passes::Int = 4; agent_launches::Int; end

"An instrument the owner starts, with its three values from §2."
Base.@kwdef struct Instrument
    id::Symbol; purpose::String
    intention::Intention.T; decider::Decider.T; fixer::Fixer.T
    roles::Vector{AgentRole}; budget::Budget
end

"A program check that every build or test runs."
Base.@kwdef struct AlwaysOn; id::Symbol; purpose::String; intention::Intention.T; fixer::Fixer.T; end

"Generated files or parts of files: which paths for a package, which part, and which generator writes it."
struct Generated; paths::Function; part::Part.T; generator::Symbol; end   # paths(cfg)::Vector{String}
```

An **open reader** is an agent role with no rule list, looking for what no rule names yet [unlisted readers found 9
defects at a third of the cost]. Documentation review has two groups of roles: **code readers**, which read each
docstring or page with the code it describes and own rules such as "the formula matches the code"; and **site
readers**, which read the built site as text with the code kept from them and own rules such as "the derivation
is right". Site readers checking mathematics run at full strength in science packages [on planted defects, two
full-strength readers found 4 each, ten economy readers 2 between them]. A *hat* and a *lane* are both agent roles.
The `cap` exists because agent output is limited [two readers were cut off at the output limit].

```julia
"Turns one rule or agent role off in one package, or in some of its files, with the reason."
Base.@kwdef struct Switch; target::Symbol; reason::String; files::Vector{String} = String[]; end

"A package's value for one rule parameter."
Base.@kwdef struct Setting; rule::Symbol; name::Symbol; value::Union{String,Symbol,Bool,Int}; end

"A rule a package adds for itself: a pattern its files must not (or must) contain, with examples."
Base.@kwdef struct PatternRule
    id::Symbol; statement::String; fileset::FileSet.T; pattern::Regex; forbidden::Bool
    examples::Vector{TextExample}
end

"A package's settings for the tool, written by hand in `.gbg/config.jl`."
Base.@kwdef struct Config
    package::String; tool::Union{VersionNumber,Symbol}          # :dev only in the tool's own checkout
    docs_build::Vector{String}; test::Vector{String}
    filesets::Dict{FileSet.T,Vector{String}} = Dict{FileSet.T,Vector{String}}()
    normative::Vector{String} = String[]
    copies::Vector{Pair{String,String}} = Pair{String,String}[]  # build-time copy => tracked source
    switches::Vector{Switch} = Switch[]; settings::Vector{Setting} = Setting[]
    roles::Vector{AgentRole} = AgentRole[]                      # the package's own expert readers
    code_areas::Vector{Pair{Symbol,Vector{String}}} = Pair{Symbol,Vector{String}}[]  # how Bug hunt splits the code
    rules::Vector{PatternRule} = PatternRule[]
end

"A question the owner settled, kept in `.gbg/settled.jl` and given to agents as 'do not report'."
Base.@kwdef struct Settled
    question::String; text::String; date::String                # date as "YYYY-MM-DD"
    quotes::Vector{Pair{Location,String}}                       # the lines the ruling is about, as they read
end
```

`.gbg/config.jl` and `.gbg/settled.jl` are never evaluated. `ConfigIO` parses them and accepts only literals
(strings, numbers, symbols, enum names, `v"…"`, `r"…"`, vectors, pairs, dictionaries) and keyword calls to the
constructors above; a function call, an interpolation, an unknown keyword, or an unknown rule or role id is exit 2
[a module holding only the config type still ran `getpid()` through it]. A test round-trips every field type through
the reader. A package rule that needs a function lives in the package's own tests as a `Rule` passed to
`Harness.test`. New settled rulings are appended to `settled.jl` as text.

```julia
"One documentation-fixer attempt at one finding, with the program and agent judgements of it."
Base.@kwdef struct DocFix
    finding::String; pass::Int; commit::String
    formula_edit::Bool; agreeing_code::Union{Location,Nothing}; verdict::Verdict.T
end

"One run, stored beside report.md as .gbg/runs/<id>/run.json through JSON3 (enums and `nothing` round-trip)."
Base.@kwdef struct Run
    id::String; instrument::Symbol; tool_version::String; first_commit::String; budget::Budget
    stage::Symbol                                               # the last stage collected; stages run in order
    findings::Vector{Finding}; fixes::Vector{DocFix}; questions::Vector{Question}
    agent_launches::Int; tokens::Union{Int,Nothing}; stop::Stop.T
end
```

**Rule docstrings.** Each `Rule`, `AgentRole` and `Instrument` constant gets its docstring from `doc(x)`, attached by
a `@doc doc(x) x` call in the source. The rule that source docstrings match the loaded module's compares only
docstrings written as literals, and requires every other docstring in the module to come from such a call, found in
the source. Each example is fenced with one more backtick than the longest run of backticks inside it, so its own
fences and doctests stay inert. `doc(x)` also returns which field each docstring line came from, located with Julia's
own parser (JuliaSyntax, part of Julia 1.12), so a finding points to the field's line in the source. Examples are
never written into the policy files or agents' arguments, and the rules pages are left out of what site readers get;
a test checks this [an agent reading the examples would be handed the planted defects].

### 5.3 What becomes Julia

The rule prose, the rule register and the scan catalogue become `Rule` values beside their checks, and the fixture's
defects and seeds their `Example`s. Hats, lanes and the model catalogue become `AgentRole` values, the hats' defect
lists becoming agent-checked rules. Instrument protocols and Workflow scripts become `Instrument` values, `Runs`
stages and one fixed driver. JSON schemas become Julia constructors, with agents' output schemas generated from the
types. `config.toml` and the exemptions ledger become `config.jl` (`Switch`, `Setting`) and `settled.jl`; templates
and `managed.json` become `Render` generators and the `GENERATED` registry.

## 6. Generation

Every non-Julia file a program or an agent reads is written by a Julia function [R6]. Prose for people — `README.md`,
pages, this document, `CHANGELOG.md` — is written by hand; a table in it that restates Julia values is compared with
them by a test, as §3's table is.

| File, or part of a file | Read by | Written by |
|---|---|---|
| `.gbg/policy/*.md` (statements, no examples); the tool's block in `CLAUDE.md` | sessions | `Render.policy` |
| one `.claude/skills/<instrument>/SKILL.md` per instrument that applies | Claude Code | `Render.skill` |
| the Workflow driver, agents' arguments and output schemas (scratch) | the Workflow tool, agents | `Agents` |
| `.gbg/runs/<id>/run.json`, `report.md`; `.gbg/questions.json` | the owner; release | `Runs`, `Render.report` |
| the tool's entries in `docs/Project.toml` and `test/Project.toml` | Pkg | `Render.pin` |
| the tool's block in `.gitignore`, CI workflow files | git, GitHub | `Render.gitignore`, `Render.ci` |
| the rules, instruments and switches pages of each site | readers | `Render.pages`, called by `docs/make.jl` |

`Catalogue.GENERATED` lists every generated path or part — a whole file, a marked block inside a file, or the entries
of a TOML table — with its generator; a package's declared copies count as generated. The wiring check regenerates
each part and compares only that part (TOML entries as parsed values, since Pkg rewrites the files) [a header line
cannot mark a JSON or skill file, a fixer could delete it, and comparing all of `CLAUDE.md` always fails].

The Workflow driver is one fixed script of a few dozen lines: it launches the agents its arguments list and reports
which wrote their files. Julia cannot launch agents; only the session can call the Workflow tool. So each stage is a
handoff: `gbg run next` writes the stage's arguments and exits; the session runs the Workflow; `gbg run collect` reads
the results. `Runs` records the stage and refuses any stage out of order. A Julia test checks the driver reads every
key `Agents` writes; a driver the Workflow tool cannot parse ends the run with exit 2.

## 7. Deterministic first

**When an agent may check a rule** [R7]. Only when deciding it needs the meaning of a sentence (is this claim true of
the code), a derivation (is this formula right), or a document read in order (is this term defined before its first
use) — the three `WhyAgent` values. Whatever a pattern, a parser, reflection on the loaded package or the Documenter
build can decide is a `ProgramCheck` from the start; that includes a docstring's stated defaults and argument names
against the signature, and docstrings present in the source but attached to nothing [five orphaned docstrings were
found by no instrument]. A partly decidable rule is split into a program rule and an agent rule. A rule with no check
states why in `unchecked_reason` and is listed as unchecked on the rules page.

**A check is shown to match its rule** by `test/rules.jl` (§5.2). Bug hunt can also be pointed at the rules. There, a
failing test is a text the rule forbids but its check lets pass, or the reverse. Only the owner decides what a rule
means, so each becomes a question; on "yes" the text becomes an example and the code fixer changes the check.

**A recurring agent finding becomes a program check.** Each verified documentation fix leaves its commit — the text
before, which broke the rule, and after, which complies — in the run record. The report lists, per agent-checked
rule, the fixes it had. When a rule recurs, the session proposes a program check as a code change; those pairs are
its first examples, and `test/rules.jl` must pass on them.

## 8. Asking the owner

`Question` is the one form for asking a person anything [R9]: the documentation fixer's (a possible code defect; a
formula edit without agreement and a numeric check), Bug hunt's, Change audit's, the code fixer's (failures;
keep-or-revert), rule counterexamples, proposed program checks, and §14. The wiring check regenerates, or exits 2 when
it cannot read the config; the session then asks the owner through a `Question` kept outside a run.

**How the language rules are applied.** `Questions.check(q, cfg)` runs whenever a question is put, inside a run or
outside one, never when a record is read [an older record would otherwise fail to load under a newer rule]. It selects,
at that moment, every program rule in `RULES` whose input is a question, so no rule text is copied and a changed rule
applies to the next question. These check, for example: a decision of one sentence ending in a question mark; a
length limit; no rule id, finding id, file path or code name in the decision or context (these go in `items` and
`exhibit`); no word on the rule's list of the tool's own terms (a `Parameter`). The agent-checked language rules —
plain, self-contained, no invented jargon — are judged by one agent before questions are shown, over a run's questions
together or over a single question put outside a run. A failing question is rewritten once; if it still fails, it is
shown with the failed rule named. `report.md` ends with the rendered questions; `test/questions.jl` checks every
question form the tool builds and the questions of §14.

**Answers.** `gbg answer <question> <option>` records the owner's answer: in the run record for a run's questions,
otherwise in `.gbg/questions.json`. An answered question never returns: grading and later runs skip any finding
whose question has an answer. An owner's "not a defect, do not ask again" appends a `Settled` value to
`.gbg/settled.jl`, tied to the question id and quoting the lines it is about. Only `Agents` reads that file, to tell
agents "do not report", and only while every quoted line still reads as quoted; no build, test or check reads it
[settled design choices were raised again in 4 of 87 findings, and one false finding topped a reader's list twice].

## 9. Applicability

A package turns an element off with a `Switch` naming it and giving the reason, and sets a variant with a `Setting`
[R10]. Every element that is off is listed in the config and shown, with its reason, on the package's documentation
site; an unknown target or a missing reason is exit 2. Rules that catch text rendering wrongly (a stray `$`, a formula
in backticks) and the docstring-structure rules stay on everywhere; a test builds a page with such a fault under the
tool's own switches and requires the build to fail.

Off in GBGCodingTools, with reasons. The second and third items are its declared deviations today; the first and
fourth are new with this design:
- the LaTeX notation and spacing rules, the citation rules, and the site readers checking mathematics, notation,
  typesetting and citations — its documentation contains no mathematics and cites no literature;
- the allocation and memory-traffic contracts — no operation here writes into array storage whose traffic matters;
- running Literate examples — it ships none;
- the numerical and device-portability roles of Bug hunt and Change audit — it has no numerical kernels or device
  arrays.

Settings here: a docstring's first sentence says what the operation does (science packages: the physical meaning of
what it computes); the "written by AI" banner is on every page.

## 10. How a run starts, works and stops

**Start.** A run starts only on the owner's request, in words or by slash command (standing ruling; §14 Q2), with one
exception already ruled: Change audit after a code fix (§4.4). No gate, check or other run starts one [8 of 15 rounds
on this tool were opened by the session or by a gate]. `gbg run start <instrument>` exits 2 when the working tree is
not clean or another run is open, and records the tool version, the first commit and the budget.

**Carried findings.** Open findings carry over, as ruled (§14 Q7). A run's record lists them, and the next run of that
instrument starts from them before its own search. This tool's final release waits while a finding marked serious is
open. Only `Runs` and `gbg release` read them.

**Work.** `Runs` orders the stages; the session launches each one (§6). Documentation review: start → find → collect →
up to 4 passes (§4.3) → close. Bug hunt: start → hunt → collect → agents write failing tests → the tool runs them →
collect → close. Change audit: start → audit, with the package's named tests run as evidence → collect → close. Close
writes `run.json` and `report.md`; the session commits and pushes them, shows the report and its questions, and ends.

**End**, decided by a program: `DONE`; `BUDGET_SPENT` (fix passes or agent launches used up; open findings listed);
`CANNOT_EVALUATE` (a step exited 2 or 3; the instrument is not repaired inside the run) [three rounds were abandoned
and scripts were replaced inside a round]; `OWNER_STOPPED`. Close also runs two programs:
- it classifies every commit since the run's first commit; if any changed code outside `gbg docfix commit`, the run
  ends `CANNOT_EVALUATE` and the owner is asked to keep or revert it, with an exhibit the program writes;
- it runs `gbg docfix check`; if the build is red, it restores the documentation to the last commit that passed and
  commits that through `gbg docfix commit` [a red docs build would otherwise stay on `master`].

**A run never** searches twice, extends its budget, commits code, starts another run, or changes an instrument
(instruments are code). Discarded bug-hunt candidates are listed with their passing tests [one was a real blocker].

**Across runs.** No build, test or wiring check reads a run record, the question store or the settled rulings
[review state turned science tests red]. The work-queue file and the end-of-turn guard that holds a session to it stay
as ruled (§14 Q3); no `gbg` verb writes to that file.

**Release of this tool** follows the standing checklist (§14 Q4). `master` is clean; `Pkg.test()`, the docs build and
the wiring check pass; `CHANGELOG.md` has its entry. Then a release candidate is tagged, and a Documentation review run
ends `DONE` or `BUDGET_SPENT`. The run may start at the candidate or at any later commit whose changes since the
candidate are all documentation by the change guard. Before the final tag, each of its questions has an answer, no
finding marked serious is open, and no keep-or-revert question is unanswered. A crashed run is restarted at the
current commit; a new candidate is needed only if code changed since the last one. `gbg release` reads only the
`stop`, `answer` and open `serious` fields from the raw JSON, so a change to the record's type cannot block it.

**Who stops.** Inside a run, the program, from the budget fixed at start; across runs, the owner, by asking or not.

| Mechanism | The failure it prevents | Its cost |
|---|---|---|
| One search per run; the finding list fixed at collect | Repeated searches never settled | A defect the search missed waits for the next run |
| At most 4 fix passes | Rounds of 9 and 15 passes | Findings open after 4 passes carry over |
| Guarded commit; classification and build check at close | Code changed, or a red build pushed, through a documentation fix | A documentation fix needing code waits for the owner |
| Code findings end as questions | Audit verdicts drove code changes without review | Owner attention per code change |
| No build or test reads run records | Review state turned science tests red | Only this tool's release looks at a run |
| A crashed step ends the run | Abandoned rounds; scripts replaced mid-round | That run's agent launches are lost |

## 11. How the tool plugs into a package

**The pinned version.** `Config.tool` names one released version (standing ruling). `gbg sync` writes it into the
docs and test environments' `[sources]` and `[compat]`. `gbg bump` runs only on the owner's request; it first runs the
new version's checks on the package and exits 1, changing nothing, with counts per new rule when any fails; else it
changes the pin and regenerates every generated part [a new program check would turn the package's build red on text
that already existed].

**Inside `Pkg.test()`** only the code rules run, and **inside the docs build** only the documentation rules:

```julia
GBGCodingTools.Harness.test(MyPackage; rules = MY_RULES)      # test/runtests.jl: contracts, accepted failing tests
GBGCodingTools.makedocs(GBGCodingTools.ConfigIO.read_config(path); sitename = "MyPackage", pages = [...])
```

The package's own preparation (Literate output, copied rationale pages) runs in `docs/make.jl` before `makedocs`; its
outputs are declared copies or generated paths. `makedocs` runs the documentation rules over the source, then
`Documenter.makedocs`, then the rules over the built site, and throws on any finding. Both entry points are
deterministic and offline, agree on a fresh clone and on CI, and never read run records, questions, settled rulings or
git state. A used file set that matches no file is exit 2, and literal docstrings in the source must match those the
loaded module reports [a check with no input reports clean].

**The same files in every package**, including this tool, created by `gbg init`:

```
.gbg/config.jl               written by hand
.gbg/settled.jl              the owner's settled rulings, appended on "do not ask again"
.gbg/questions.json          questions put outside a run, with their answers
.gbg/policy/*.md             generated
.gbg/runs/<id>/              run.json and report.md
.claude/skills/*/SKILL.md    generated, one per instrument that applies
CLAUDE.md                    the tool's block generated; the rest belongs to the package
test/regressions/            accepted failing tests; escalated/ holds those awaiting an answer
```

Agent output and the driver live in a scratch directory that git ignores; planted copies live outside the package.

## 12. Showing that an instrument works

**Program checks** are shown to work by their examples (§5.2). **The instruments whose findings come from agents** are
measured only when the owner asks, by `gbg calibrate <instrument>`, the command you asked for (§14 Q8) [R7; the only
valid measurement on this tool found 4 of 12 planted defects, and two others never delivered their planted defects].
The breaking examples of the agent-checked rules that apply, and defects the owner found by reading, are planted at
random positions into a copy of the package in a temporary directory outside it; the positions are recorded only
after the agents finish. Code readers read docstrings from the copy's source files, and site readers read the copy's
own built site, never the loaded original; the rules pages are left out. Nothing is fixed.

**The measurement is checked before it is reported** [a zero was nearly reported as a valid result]:
1. delivery is checked by content: for every agent role that checks a planted rule, the planted text is present in the
   files that agent is given; otherwise exit 2;
2. a finding counts only when it names the planted rule, its location is within the planted lines, and its quoted
   evidence appears there in the copy; one planted example per finding;
3. the program matching findings to planted defects is tested first: perfect findings score all found; the same
   findings moved off the planted lines, or none, score none.

The report gives the share of planted examples found and of findings that matched one; measurements are compared only
with the same examples, roles and model strength.

## 13. Change control and growth

A rule, agent role or instrument is code in this tool: it changes through the code fixer on the owner's answer, is
released as a tag that is never moved, and reaches a package through `gbg bump` [R2]. It never changes during a run.
A design review, adversarial or not, proposes and never applies: each proposal becomes a question or is dismissed
with its reason. `gbg attack` starts such a review.

**Growth limit.** A code change adding a mechanism — a rule, agent role, instrument, run stage, verb or refusal — names,
in its question to the owner, the requirement or measured failure it answers and what it replaces; without one it is
not added.

## 14. Questions for the owner

**Q1. Should a code fix wait on a separate branch until you accept it, instead of going straight to the main branch?**
You ruled that every commit goes straight to the main branch, and the design keeps that. A separate branch keeps a
change you have not read out of the main branch, at one merge per accepted change. Straight in is simpler, but a
wrong change is live, with its documentation published, until you read it.

**Q2. Should an instrument start only from a slash command you type, rather than also from a request in words?** You
ruled that either starts one, and the design keeps that. Slash only means a session cannot start one by misreading
you; 8 of the 15 review runs on this tool were started by the session or by a gate. Words are more convenient.

**Q3. Should the end-of-turn guard and the work-queue file be removed from every package?** You ruled both into every
package; the guard keeps a session from ending its turn while the file lists open items. Removing them means nothing
keeps a session working on items you did not ask for now, and unfinished items survive only as unanswered questions;
keeping them keeps long jobs going without you.

**Q4. Should a release of this tool still wait on a documentation review started at a trial version, with every
question it raised answered?** Your release checklist requires it. Keeping it costs one review and your answers per
release. Dropping it means a release needs only passing tests, documentation build and file checks, and can ship
with known problems listed in a report; the release waiting on a review was part of the loop you saw.

**Q5. Should every code fix still be audited once before you are asked to keep it?** You ruled that code changed by a
fix is audited, and the design keeps that; in the turbulence package the audit caught two regressions the failing
tests missed. The cost is agent time on every change, and each concern you ask to fix leads to another audit.

**Q6. In this tool, should wording fixes to a rule's own text be made automatically, or brought to you?** Agents and
sessions act on a rule's text, so the design brings each change to you. You do not review this package's prose;
automatic fixing would save your time, but a reworded rule can change what is enforced.

**Q7. Should unfinished findings stop carrying over from one review to the next, and stop holding back a release of
this tool?** You ruled that they carry over and that serious ones hold back the final release; the design keeps that.
Carrying over keeps a known problem from being forgotten. The cost: a review can block a release, and each review
starts with the last one's leftovers, part of the loop you saw. If you drop it, leftovers are listed in the review's
report, and you decide whether to start a review that fixes them.

**Q8. Should the instruments whose findings come from AI agents be measured at all, by planting known defects and
counting how many are found?** The design keeps measurement, only when you ask, and refuses to report a result unless
the planted defects reached every agent. Dropping it removes a part that has produced one valid result so far;
keeping it is the only way to tell whether a change to the agents helped.
