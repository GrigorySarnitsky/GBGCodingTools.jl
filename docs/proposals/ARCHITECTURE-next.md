# GBGCodingTools — architecture

This is the target design, and it is normative: code that disagrees with it is wrong, or this document changes
first. It follows the owner's rulings; no question about it is open. A term in **bold** is defined where it first
appears. The reason for each mechanism is given in brackets: a requirement R1–R11 from the owner, or a failure
observed in use.

Not in this document: the migration order (`IMPLEMENTATION.md`); history and evidence, including the replaced
architecture (`docs/design-record/`).

## 1. Purpose and scope

GBGCodingTools is a Julia package, on the Julia 1.12 floor. It keeps the owner's Julia packages written to one set
of rules, and it helps AI sessions find and fix defects in them without breaking how they work. It serves the four
science packages — GBGPeriodicFields, GBGIsotropicTurbulence, GBGStreamingStatistics, GBGCloudPhysics — and itself.
Each of the five is a **package** below; the **owner** is the person who owns them; a **session** is one Claude Code
conversation working in a package. GBGCodingTools is also called the tooling package here.

It does four things:
1. It holds the **rulebook**: every rule on how documentation and code are written. Each rule is a Julia value that
   carries its statement, the check that decides a violation and, where a program decides, examples that break and
   comply with it [R5, R7].
2. It runs the rules' program checks inside each package's documentation build and test suite, always [R7].
3. It provides **instruments**: procedures the owner asks a session to run, which find defects. Documentation
   defects are fixed without the owner and the fixes are checked; code defects are put to the owner [R1, R2].
4. It generates every file that connects a package to GBGCodingTools, so the five carry the same files [R6].

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
  writes a failing test, and the finding exists only if GBGCodingTools runs it and it fails); *an agent*, quoting
  the text it judges.
- **How found issues are fixed** — *the documentation fixer* (automatic, checked); *the code fixer* (only on the
  owner's answer, checked); *regenerated*; *by the owner only*.

No two rows of the table in §3 have the same three values; `test/architecture.jl` reads the three columns and fails
on a repeat. No further distinction is needed to separate the rows. Every rule an agent checks belongs to exactly
one agent role (§5), and a test checks this too.

## 3. The table

**Always-on checks** are programs run by every build or test; nobody starts them and they have no runs [R7].
**Instruments** run only when the owner asks, in words or by slash command (as ruled). Outside a run, a session
fixes failures in its own work; the two fixers handle the defects the checks and instruments find.

| | Purpose | Intention | Decided by | How found issues are fixed | When it runs | A run ends when |
|---|---|---|---|---|---|---|
| **Documentation checks** (always on) | Documentation has the house structure and formatting and renders as written; re-running the check verifies a fix | Documentation | A program | Documentation fixer | Every docs build | — |
| **Code checks** (always on) | The code keeps its tested contracts and every accepted failing test passes | Code | A program | Code fixer | Every `Pkg.test()` | — |
| **Wiring check** (always on) | Every generated file or part of a file equals its generator's output | Code | A program | Regenerated | Whenever `gbg sync`, `gbg bump` or `gbg release` runs | — |
| **Documentation review** | Documentation is true to the code, correct, consistent and self-contained; the change guard, the checks and a verifier agent check each fix | Documentation | An agent | Documentation fixer | Owner's request | Nothing is open, or the budget is spent |
| **Bug hunt** | The code does what its documentation says | Code | An agent proposes, a program decides | Code fixer | Owner's request | Every candidate is confirmed or discarded, once |
| **Change audit** | A code change is no wider than its reason and still accepts input that worked before; the audit itself changes nothing | Code | An agent | Code fixer | Owner's request | One pass over the change |
| **Leak check** (future) | Nothing secret or personal is published when a repository is made public; findings never enter a tracked file | Publication | A program | Owner only | Owner's request | One pass over every branch, commit and message |

Nothing starts a Change audit by itself: after a code fix, the closing output, the report and a note kept with the
questions remind the owner that one is advisable, and it runs when the owner asks for it (§4.4). Documentation review
and Bug hunt can meet one disagreement between a docstring and its code from opposite sides: the review compares,
the hunt reports
only what a failing test shows. Either way a possible code defect reaches the owner as a question, and an answered
question never returns (§8). Reading documentation beside its code and reading the rendered site without it differ
only in what agents read, so they are one instrument with two groups of agents (§5.2). The leak check attaches later
by adding its rules, a reader of every branch, commit message and `Manifest.toml` path, and one `Instrument` value.
One function, `Guard.refuse_publication`, is called by every writer of a tracked file — run record, report, question
store, settled-rulings file — and exits 2 on text from a publication run [a committed record would publish the leak
it found].

## 4. Finding and fixing

```
FINDING PARTS                        FIXING PARTS
Documentation review ─┐              ┌─ about documentation ─► DOCUMENTATION FIXER ─► guarded commit
Bug hunt ─────────────┼─► collect ───┤     ─► checks ─► verifier, blind then with the diff ─► closed or open
Change audit ─────────┘              └─ about code ─► question to the owner ─► answer:
                                          "fix the code" ─► CODE FIXER ─► the failing test now passes,
                                               tests pass ─► commit ─► a change audit is advised, never started
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
under `docs/src/`; the package's `README.md`; the rationale documents the config names; and, in GBGCodingTools, the
prose of its rules — the `statement` and `why` of a `Rule`, and nothing else in that value. **Everything else is
code** [R2]: other `.jl` files, whole (tests,
`docs/make.jl`, Literate scripts, whose comment marks decide what runs); `Project.toml` and `Manifest.toml`; the
config; stored data code reads, in any format; every generated path and declared copy (§6); CI, hook and skill
files; `CLAUDE.md`; any document the config declares normative, which wins over "rationale" (this document, for
GBGCodingTools) [a fix aligning a specification with code would authorise that code]; and every other part of a
rule, agent role or instrument value — its id, check, examples, parameters, file sets, strength and lists.

The **change guard** is the program `Guard.classify(cfg, path, before, after)`. It returns documentation only when all
of these hold, and code otherwise:
1. the path is on the documentation list, and is neither a generated path nor a declared copy;
2. for `.jl`: both versions parse; removing line numbers, plain string literals standing alone at top level or in a
   struct body (unattached and field docstrings), and docstrings whose text is a plain or `raw"…"` literal and whose
   target is a definition, leaves the same parsed code. A docstring whose target is a call, or a macro call other
   than a defining one (`@kwdef`, `@enum`), in either version, makes the change code: Julia then documents the call
   instead of running it. A docstring with `$(…)`, or a computed `@doc` argument, is never removed;
3. in GBGCodingTools only, differences confined to plain string literals given to the keywords `statement` or `why`
   of a `Rule(…)` call are documentation — any number of them, in any number of files — with the parsed trees
   identical at every other node. A moved, added or removed argument, a changed id, check, example or parameter, or
   an interpolated string in those fields, is code;
4. no changed comment contains a Literate mark (`#src`, `#md`, `#jl`, `#nb`);
5. in every removed docstring and every changed page, every fenced block whose info string starts with `jldoctest`
   or `@` is identical, info string included, and in the same order — this covers doctest input and output,
   `@example`, `@eval`, `@setup`, `@meta`, `@raw`, and the signatures and filters of `@docs`, `@autodocs`, `@index`
   and `@contents`, which Documenter evaluates.

Clause 3 is narrower than "the prose of a rule and of an agent role". An agent role's `description`, like the
`question` of a rule an agent checks, is an instruction handed to an agent: rewording it changes what the instrument
looks for, and no program compares it with anything, so it stays code. A rule's `statement` is also what agents are
told to look for, so rewording it can change what agents report, though it can change no program check; every such
edit is verified as §4.3 step 3 says and listed in the report.

Accepted limit: a longer docstring shifts what `@__LINE__` returns. `test/guard.jl` holds one example per clause, in
both directions [parsed code alone passed changed doctest output, a `@autodocs` filter, and a docstring that stopped
a call from running]. For clause 3 the cases are: two reworded `statement`s and a reworded `why` in one file
(documentation); and a changed check, a changed example, a renamed id, a reordered argument list, an interpolated
statement and a reworded agent-role `description` (code).

### 4.3 The documentation fixer — automatic, with checks

The documentation fixer is the session at full strength, working through `gbg docfix` steps. It starts only inside a
run the owner asked for, and then fixes and verifies without asking again [R1, R2].
1. **Other copies.** Before fixing, a program searches every documentation file for the finding's quoted text and
   for each formula in it, and adds every hit as a possible further location [a fourth copy of a corrected formula
   survived a fix].
2. **Guarded commit.** The fixer edits, then `gbg docfix commit` classifies every changed path in the working tree
   with the change guard. It then regenerates every generated part whose generator reads the prose that changed — the
   policy files and the tooling package's block in `CLAUDE.md` — and puts them in the same commit: a generated file
   equal to its generator's output is not a code change [otherwise a reworded rule would leave the wiring check red].
   It makes the commit on the current branch only if every remaining path is documentation; otherwise it exits 1 and
   commits nothing. The session then pushes. This is the one verb that commits, because the guard must run before a
   commit exists; it replaces the current rule that no verb commits [a code edit committed before the guard ran would
   be pushed].
3. **Formula and rule-statement edits.** An edit that changes mathematics — inside a math span: a symbol, a number or
   a sign; years in citations do not count — is made automatically only when the fixer both quotes an expression from
   the body of the documented method that agrees with the new text and supplies a numeric check: a few lines of Julia,
   run by the program in scratch, that evaluate the new formula and the method on several inputs drawn across the
   documented domain, all of which must agree [one input chosen by the fixer passes at a symmetric or unit value while
   a sign, a dropped term or a wrong factor survives]. Otherwise the finding becomes a question. A reworded rule
   statement (§4.2 clause 3) is treated the same way, because no program compares a statement with the check it names.
   Both kinds are verified blind at full strength — the verifier of a statement is given the rule's check and its
   examples — and listed in the report [a docstring was "fixed" to contradict code that was itself wrong; a fix wrote
   false mathematics].
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
3. The change is committed on the current branch and pushed, as ruled: there is no separate branch and no approval
   step. Failing tests of unanswered questions wait in `test/regressions/escalated/` (as ruled), which `Pkg.test()`
   never runs. On "fix the code" and a passing change, the test moves unchanged into `test/regressions/`; on any
   other answer it is deleted.
4. The program that verified and committed the change records `audit_advised`, with those commits, in
   `.gbg/questions.json`, and the closing output and the run's report say a Change audit over them is advisable — an
   audit caught two regressions the failing tests missed in one science package. `gbg run start` and `gbg release`
   print the outstanding ones, so a fix that landed unaudited stays visible after the terminal is closed. Nothing
   starts an audit and nothing waits for one: no release, push or run is held back, and the reminder never goes into
   the work queue, which is for work the owner asked for.

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
Render         the generators and the wiring check                 ← the docs build uses nothing below this line
Orchestration  Agents (arguments), Runs
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
    examples::Vector{Example} = Example[]      # a program check needs them; a rule an agent checks needs none
end
```

Program rules whose input is a question run when a question is put (§8); agent-checked rules run only inside
instruments. `test/rules.jl` materialises every example — a text; a temporary file tree; a source string loaded into
a fresh module; all site examples in one Documenter build with warnings allowed, each page in its own directory (a
strict build writes nothing once one example breaks) — and requires the check's locations to equal `expect`. For a
program check, every clause of the statement needs a breaking example and a complying text that differs from a
breaking one as little as possible [a yes/no example passes a check that always fires; about 25 of today's 59 coded
rules read file trees, the loaded package or the built site]. A rule an agent checks needs no example, because no
program reads it.

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
is right". Site readers checking mathematics run at full strength in science packages [two full-strength readers
once found 4 planted defects each, where ten economy readers found 2 between them]. A *hat* and a *lane* are both
agent roles. The `cap` exists because agent output is limited [two readers were cut off at the output limit].

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

"A package's settings, written by hand in `.gbg/config.jl`."
Base.@kwdef struct Config
    package::String; tool::Union{VersionNumber,Symbol}          # :dev only in GBGCodingTools' own checkout
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
own parser (JuliaSyntax, part of Julia 1.12), so a finding points to the field's line in the source. The generated
pages that show the rules stay outside the file set the site readers get, and the generated policy files carry
statements without examples, because a rules page is by construction full of text that breaks the rules: a reader
given it would spend its budget reporting the examples, and the fix would be refused, examples being code.

### 5.3 What becomes Julia

The rule prose, the rule register and the scan catalogue become `Rule` values beside their checks, and the fixture's
defects their `Example`s. Hats, lanes and the model catalogue become `AgentRole` values, the hats' defect lists
becoming agent-checked rules. Instrument protocols and Workflow scripts become `Instrument` values, `Runs` stages
and one fixed driver. JSON schemas become Julia constructors, with agents' output schemas generated from the types.
`config.toml` and the exemptions ledger become `config.jl` (`Switch`, `Setting`) and `settled.jl`; templates and
`managed.json` become `Render` generators and the `GENERATED` registry.

## 6. Generation

Every non-Julia file a program or an agent reads is written by a Julia function [R6]. Prose for people — `README.md`,
pages, this document, `CHANGELOG.md` — is written by hand; a table in it that restates Julia values is compared with
them by a test, as §3's table is.

| File, or part of a file | Read by | Written by |
|---|---|---|
| `.gbg/policy/*.md` (statements, no examples); the tooling package's block in `CLAUDE.md` | sessions | `Render.policy` |
| one `.claude/skills/<instrument>/SKILL.md` per instrument that applies | Claude Code | `Render.skill` |
| the Workflow driver, agents' arguments and output schemas (scratch) | the Workflow tool, agents | `Agents` |
| `.gbg/runs/<id>/run.json`, `report.md`; `.gbg/questions.json` | the owner | `Runs`, `Render.report` |
| the pin in `docs/Project.toml` and `test/Project.toml` | Pkg | `Render.pin` |
| the tooling package's block in `.gitignore`, CI workflow files | git, GitHub | `Render.gitignore`, `Render.ci` |
| the rules, instruments and switches pages of each site | readers | `Render.pages`, called by `docs/make.jl` |

`Catalogue.GENERATED` lists every generated path or part — a whole file, a marked block inside a file, or the entries
of a TOML table — with its generator; a package's declared copies count as generated. The wiring check regenerates
each part and compares only that part (TOML entries as parsed values, since Pkg rewrites the files) [a header line
cannot mark a JSON or skill file, a fixer could delete it, and comparing all of `CLAUDE.md` always fails]. Because a
generated part equal to its generator's output is not a code change, `gbg docfix commit` may regenerate and commit
the parts a reworded rule statement feeds — the policy files and the `CLAUDE.md` block — inside the same commit
(§4.3), so a prose fix never leaves the wiring check red.

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
formula edit without agreement and a numeric check), Bug hunt's, Change audit's, the code fixer's failures, rule
counterexamples, and proposed program checks. The wiring check regenerates, or exits 2 when it cannot read the
config; the session then asks the owner through a `Question` kept outside a run.

**How the language rules are applied.** `Questions.check(q, cfg)` runs whenever a question is put, inside a run or
outside one, never when a record is read [an older record would otherwise fail to load under a newer rule]. It selects,
at that moment, every program rule in `RULES` whose input is a question, so no rule text is copied and a changed rule
applies to the next question. These check, for example: a decision of one sentence ending in a question mark; a
length limit; no rule id, finding id, file path or code name in the decision or context (these go in `items` and
`exhibit`); no word on the rule's list of the tooling package's own terms (a `Parameter`). The agent-checked language
rules — plain, self-contained, no invented jargon — are judged by one agent before questions are shown, over a run's
questions together or over a single question put outside a run. A failing question is rewritten once; if it still
fails, it is shown with the failed rule named. `report.md` ends with the rendered questions; `test/questions.jl`
checks every question form the tooling package builds.

**Answers.** `gbg answer <question> <option>` records the owner's answer: in the run record for a run's questions,
otherwise in `.gbg/questions.json`, which also holds the `audit_advised` notes of §4.4 — a note, not a question, so
nothing waits on it. An answered question never returns: grading and later runs skip any finding
whose question has an answer. An owner's "not a defect, do not ask again" appends a `Settled` value to
`.gbg/settled.jl`, tied to the question id and quoting the lines it is about. Only `Agents` reads that file, to tell
agents "do not report", and only while every quoted line still reads as quoted; no build, test or check reads it
[settled design choices were raised again in 4 of 87 findings, and one false finding topped a reader's list twice].

## 9. Applicability

A package turns an element off with a `Switch` naming it and giving the reason, and sets a variant with a `Setting`
[R10]. Every element that is off is listed in the config and shown, with its reason, on the package's documentation
site; an unknown target or a missing reason is exit 2. Rules that catch text rendering wrongly (a stray `$`, a formula
in backticks) and the docstring-structure rules stay on everywhere; a test builds a page with such a fault under
GBGCodingTools' own switches and requires the build to fail.

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

**Start.** A run starts only on the owner's request, in words or by slash command (as ruled). No gate, check, fix or
other run starts one [8 of 15 rounds on GBGCodingTools were opened by the session or by a gate]. Once started, the
run fixes and verifies to its end without asking again. `gbg run start <instrument>` exits 2 when the working tree is
not clean or another run is open, and records the version of GBGCodingTools, the first commit and the budget.

**Carried findings, and the two places they live.** Open findings carry over, as ruled. The run record keeps them
with their ids, locations and quotes: the machine's copy, which the next run of that instrument starts from, before
its own search. At close, every instrument also writes one line per leftover into `.claude/WORK_QUEUE.md`, the
owner's list — a documentation review's unfixed findings, a Bug hunt's confirmed defects whose question is
unanswered, a Change audit's concerns — so that everything still owed sits where the owner already looks. Those lines
go under a heading the end-of-turn guard does not count, so the list never makes a session work on something the
owner has not asked about [a session held to that list could only edit by hand, without guard or verifier, or open a
run nobody asked for]. The guard is otherwise unchanged, and holds a session to the items the owner put there. The
report keeps no second list of leftovers: it names the run record, and says how many lines went to the work queue.

**Work.** `Runs` orders the stages; the session launches each one (§6). Documentation review: start → find → collect →
up to 4 passes (§4.3) → close. Bug hunt: start → hunt → collect → agents write failing tests → `gbg run` runs them →
collect → close. Change audit: start → audit, with the package's named tests run as evidence → collect → close. Close
writes `run.json` and `report.md`; the session commits and pushes them, shows the report and its questions, and ends.

**End**, decided by a program: `DONE`; `BUDGET_SPENT` (fix passes or agent launches used up; the open findings go to
the record and the queue);
`CANNOT_EVALUATE` (a step exited 2 or 3; the instrument is not repaired inside the run) [three rounds were abandoned
and scripts were replaced inside a round]; `OWNER_STOPPED`. Close also runs two programs:
- it classifies every commit since the run's first commit; if any changed code outside `gbg docfix commit`, the run
  ends `CANNOT_EVALUATE` and the owner is asked to keep or revert it, with an exhibit the program writes;
- it runs `gbg docfix check`; if the build is red, it restores the documentation to the last commit that passed and
  commits that through `gbg docfix commit` [a red docs build would otherwise stay on the branch].

**A run never** searches twice, extends its budget, commits code, starts another run, or changes an instrument
(instruments are code). Discarded bug-hunt candidates are listed with their passing tests [one was a real blocker].

**Across runs.** No build, test or wiring check reads a run record, the question store or the settled rulings
[review state turned science tests red]. The work-queue file and the end-of-turn guard that holds a session to it stay
as ruled; the close of a run is the only verb that writes to that file, one line per leftover, under the heading the
guard does not count.

**Release** of GBGCodingTools needs a clean tree on `master`, pushed; a green `Pkg.test()`, a green docs build and a
green wiring check; and the `CHANGELOG.md` entry; the tag is never moved. `gbg release` prints, and the tag message
and that entry carry, two lines it does not act on: the commits whose keep-or-revert question is still open, and how
many confirmed failing tests wait unanswered in `test/regressions/escalated/` [both are real defects that no release
looked at]. Nothing else holds a release either: no review run, no open finding, no unanswered question, and no audit
[a release that waited on a review, which waited on fixes, which were audited, is the loop the owner stopped].

**Who stops.** Inside a run, the program, from the budget fixed at start; across runs, the owner, by asking or not.

| Mechanism | The failure it prevents | Its cost |
|---|---|---|
| One search per run; the finding list fixed at collect | Repeated searches never settled | A defect the search missed waits for the next run |
| At most 4 fix passes | Rounds of 9 and 15 passes | Findings open after 4 passes carry over |
| Carried findings, in the record and the work queue | A leftover forgotten between reviews | The next review starts with the last one's leftovers |
| Guarded commit; classification and build check at close | Code changed, or a red build pushed, through a documentation fix | A documentation fix needing code waits for the owner |
| Code findings end as questions | Audit verdicts drove code changes without review | Owner attention per code change |
| Nothing outside the run machinery reads run records | Review state turned science tests red, and held releases | What is owed is read from the work queue, not enforced |
| A crashed step ends the run | Abandoned rounds; scripts replaced mid-round | That run's agent launches are lost |

## 11. How GBGCodingTools plugs into a package

**The pinned version.** `Config.tool` names one released version (as ruled). `gbg sync` writes it into the docs and
test environments' `[sources]` and `[compat]`. `gbg bump` runs only on the owner's request; it first runs the new
version's checks on the package and exits 1, changing nothing, with counts per new rule when any fails; else it
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

**The same files in every package**, including GBGCodingTools, created by `gbg init`:

```
.gbg/config.jl               written by hand
.gbg/settled.jl              the owner's settled rulings, appended on "do not ask again"
.gbg/questions.json          questions put outside a run, with their answers
.gbg/policy/*.md             generated
.gbg/runs/<id>/              run.json and report.md
.claude/skills/*/SKILL.md    generated, one per instrument that applies
.claude/WORK_QUEUE.md        the owner's list: the items he wrote, which the end-of-turn guard holds a session to,
                             and, under a heading that guard does not count, one line per leftover from each run
CLAUDE.md                    the tooling package's block generated; the rest belongs to the package
test/regressions/            accepted failing tests; escalated/ holds those awaiting an answer
```

Agent output and the driver live in a scratch directory that git ignores.

## 12. What is shown to work, and what is not

**Program checks** are shown to work by their examples (§5.2): every check is run on every example of its rule, and
its locations must equal what the example expects, in both directions and for every clause.

**The instruments whose findings come from agents are not measured.** Nothing plants known defects to count how many
are found. This is a deliberate limit, not a plan: it means that a change to an agent role's wording, to its rule
list or to its model strength cannot be shown to help or hurt, and that the judgement of whether these instruments
are worth their cost stays the owner's, from what their reports contain. What is recorded per run is factual and
cheap: how many findings were reported, how many were verified as fixed, how many carried over, how many agent
launches were used and, when the platform reports it, how many tokens.

## 13. Change control and growth

A rule, agent role or instrument is code in GBGCodingTools, apart from the prose fields of §4.2: it changes through
the code fixer on the owner's answer, is released as a tag that is never moved, and reaches a package through
`gbg bump` [R2]. It never changes during a run. A design review, adversarial or not, proposes and never applies:
each proposal becomes a question or is dismissed with its reason. `gbg attack` starts such a review.

**Growth limit.** A code change adding a mechanism — a rule, agent role, instrument, run stage, verb or refusal — names,
in its question to the owner, the requirement or measured failure it answers and what it replaces; without one it is
not added.
