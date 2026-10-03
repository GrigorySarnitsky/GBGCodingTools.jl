# The design's §5.2; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Model

Every type the rebuilt package is written in, and nothing else: the enums, the structs and the abstract
types of, with no behaviour and no values attached. It is the bottom module
of the order — `Model` → `Texts` → `Catalogue` → `ConfigIO` → `Engine` → `Render` → `Orchestration` →
`CLI` — so every later module may name these types and none of them may reach upwards.

The enums are scoped, one module each (`Decider.PROGRAM`, `Verdict.FIXED`), so values of different enums
never share a name and a misplaced one is a method error rather than a silent equality.

- [`Location`](@ref) and [`FindingDraft`](@ref), [`Finding`](@ref) — where a defect is, and what is
  reported about it.
- [`Rule`](@ref) with [`ProgramCheck`](@ref), [`AgentCheck`](@ref), [`Example`](@ref) and
  [`Parameter`](@ref) — the rulebook as values.
- [`AgentRole`](@ref), [`Instrument`](@ref), [`AlwaysOn`](@ref), [`Budget`](@ref) — who reads, what
  starts, and what a run may spend.
- [`Question`](@ref) with [`Option`](@ref) and [`Item`](@ref) — the one form for asking the owner.
- [`Config`](@ref), [`Switch`](@ref), [`Deferral`](@ref), [`Setting`](@ref), [`PatternRule`](@ref),
  [`Settled`](@ref) — a package's own settings and the rulings it has already given.
- [`DocFix`](@ref), [`CodeFix`](@ref), [`Run`](@ref), [`Generated`](@ref) — what a run did and what
  writes each generated file.
"""
module Model

# ───────────────────────────────────────────────────────────────────────────────────────── the enums

"What the defects a check or an instrument looks for are in. `PUBLICATION` arrives with the leak scan."
module Intention; @enum T DOCUMENTATION CODE PUBLICATION; end

"Who says a finding is real: a program, an agent whose failing test a program then runs, or an agent."
module Decider; @enum T PROGRAM FAILING_TEST AGENT; end

"Who fixes what was found, from the last column of the instrument table."
module Fixer; @enum T ORDINARY_WORK DOCUMENTATION_FIXER CODE_FIXER REGENERATE OWNER_ONLY; end

"""
What a check reads: a source text, a small file tree, the loaded package with its root (handed
`(pkg, root)`, since it compares the module against its source), the built site, a question, the
repository's history, or what a repository would publish. No build or test may read git, so a `HISTORY`
check runs in the end-of-turn hook and under `gbg check` alone, and a `PUBLICATION` check in `gbg leak`.
"""
module Input; @enum T SOURCE_TEXT FILE_TREE LOADED_MODULE BUILT_SITE QUESTION HISTORY PUBLICATION; end

"A named set of a package's files, found by default patterns the config may override."
module FileSet; @enum T DOCSTRINGS PAGES RATIONALE LITERATE CODE TESTS; end

"""
What deciding one rule requires beyond the unit it is about — the material a reader must be GIVEN.
`NOTHING` is exclusive: the unit alone decides, and more material would change the answer (a term
undefined on the page may be defined in the source, and the rule asks about the page). The others
combine. Tagged on each rule from its own text by three blind readers, 2026-09-19.
"""
module Access; @enum T NOTHING SIBLINGS OTHER_DOCUMENTS SOURCE RENDERED HISTORY CITED_WORK; end

"Which model an agent runs on: the cheaper default, or the most capable."
module Strength; @enum T ECONOMY FULL; end

"How much of a generated path its generator writes: the whole file, a marked block, or TOML entries."
module Part; @enum T WHOLE BLOCK TOML_ENTRIES; end

"A verifier's answer about one fix. `LINE_ONLY` and `MADE_WORSE` come only from the stage that sees the diff."
module Verdict; @enum T FIXED NOT_FIXED LINE_ONLY MADE_WORSE HIDES_CODE_DEFECT NOT_A_DEFECT; end

"Why a run ended, decided by a program and recorded in the run."
module Stop; @enum T DONE CANNOT_EVALUATE OWNER_STOPPED; end

"""
The only three reasons an agent may decide a rule rather than a program: the meaning of a sentence, a
derivation, or a document read in order.
"""
module WhyAgent; @enum T MEANING DERIVATION READING_ORDER; end

"How a location was found again when the text around it moved, or `OUTDATED` when it was not."
module Anchor; @enum T FRESH BY_NODE BY_QUOTE BY_DIFF OUTDATED; end

# ─────────────────────────────────────────────────────────────────────── findings and where they are

"""
    Location

Where a finding is, held still while the text around it moves: the node and the quote survive edits above
them, and the line is only a hint.

A line found again on a later pass is a line of that later tree; mapped from the run's first commit, it
was moved a second time.

# Fields

- `file` — the path, relative to the package root.
- `node` — for a `.jl` file the binding, method or field of a constant documented (`ARGS_FORM.statement`);
  for Markdown the heading path; empty where the file has neither.
- `text` — the quote: the decisive text as it read when the finding was made.
- `line` — the line it was on then, kept as a hint and never taken from an agent.
- `found` — how it was anchored the last time it was looked for.
- `at` — the commit `line` was read at, empty for the commit the run began at.
"""
Base.@kwdef struct Location
    file::String
    node::String = ""
    text::String = ""
    line::Int = 0
    found::Anchor.T = Anchor.FRESH
    at::String = ""
end

"""
    FindingDraft

What an agent or a check reports, before a run gives it an id.

# Fields

- `rule` — the rule it breaks, or `nothing` where no rule names it yet.
- `locations` — every site, each with its own quote.
- `claim` — what is wrong, in one sentence.
- `evidence` — a failing test's path, or the reason to believe the claim.
- `fix` — what would put it right.
- `maybe_code` — the agent believes the code, not the text, is wrong.
- `in_material` — every location is in material a reader was given to consult, not in a target of the
  review; such a finding goes to the owner and never to the fixer.
"""
Base.@kwdef struct FindingDraft
    rule::Union{Symbol,Nothing} = nothing
    locations::Vector{Location} = Location[]
    claim::String
    evidence::String = ""
    fix::String = ""
    maybe_code::Bool = false
    in_material::Bool = false
end

"""
    relocated(d, locations) -> FindingDraft

The same draft with its locations replaced and EVERY other field carried. The arguments are `d`, the
draft, and the new `locations`. Returns the copy.

Two places rebuilt a draft field by field to re-anchor it — the fix stage and the carry-over — and
both silently dropped `in_material` the day it was added, so a finding in the working notes became a
fixer's on the first pass. A field added to the draft is carried here or nowhere.
"""
relocated(d::FindingDraft, locations::Vector{Location}) =
    FindingDraft(rule = d.rule, locations = locations, claim = d.claim, evidence = d.evidence, fix = d.fix,
                 maybe_code = d.maybe_code, in_material = d.in_material)

"""
    Finding

One defect in a run: the draft, the id the run gave it, and who reported it.

# Fields

- `id` — the run's own identifier for it.
- `source` — the check or the agent role that reported it.
- `decider` — what decided that it is real.
- `draft` — what was reported.
"""
struct Finding
    id::String
    source::Symbol
    decider::Decider.T
    draft::FindingDraft
end

# ──────────────────────────────────────────────────────────────────────────── asking the owner

"""
    Option

A possible answer to a question, with what happens if it is chosen.

# Fields

- `label` — the answer itself, in a few words.
- `consequence` — what follows from choosing it, including what it costs.
- `recommended` — whether this is the answer the session recommends.
"""
struct Option
    label::String
    consequence::String
    recommended::Bool
end

"""
    Item

One decision inside a question; items share the question's options and each is answered on its own. 

# Fields

- `text` — the decision, in one sentence.
- `recommended` — the label of the option recommended for this item.
- `sources` — where the reader can see it for himself.
- `answer` — the label chosen, or `nothing` while it is unanswered.
- `direction` — how the owner wants it done, where the answer carried that.
"""
Base.@kwdef struct Item
    text::String
    recommended::String = ""
    sources::Vector{String} = String[]
    answer::Union{String,Nothing} = nothing
    direction::String = ""
end

"""
    Question

A decision put to the owner: plain data, checked against the language rules only when it is put. 

# Fields

- `id` — its identifier, stable once written.
- `decision` — the decision itself, one sentence ending in a question mark.
- `context` — what he needs to know to answer, without jargon.
- `options` — the answers he may give.
- `items` — the separate decisions the options apply to, empty for a single question.
- `exhibit` — commits, changed files and definitions, exempt from the language rules.
- `answer` — the label chosen, for a question with no items.
- `direction` — how he wants it done, where the answer carried that.
"""
Base.@kwdef struct Question
    id::String
    decision::String
    context::String = ""
    options::Vector{Option} = Option[]
    items::Vector{Item} = Item[]
    exhibit::String = ""
    answer::Union{String,Nothing} = nothing
    direction::String = ""
end

# ─────────────────────────────────────────────────────────────────────────────────── the rulebook

"""
    Check

What decides whether a rule is broken: a program, or an agent for one of the three reasons a program
cannot. The two concrete types are [`ProgramCheck`](@ref) and [`AgentCheck`](@ref).
"""
abstract type Check end

"""
    ProgramCheck

A check a program decides, run over one kind of input.

# Fields

- `input` — what it reads.
- `run` — the function itself, `run(x, cfg)::Vector{Location}`; re-run from scratch, so it never needs
  re-anchoring.
- `network` — whether it reaches the network, which keeps it out of every build and test.
"""
struct ProgramCheck <: Check
    input::Input.T
    run::Function
    network::Bool
end

"""
    AgentCheck

A check an agent decides, because a program cannot.

# Fields

- `question` — what the agent is asked about the text in front of it.
- `why` — which of the three admitted reasons this needs an agent for.
"""
struct AgentCheck <: Check
    question::String
    why::WhyAgent.T
end

"""
    RetiredClaim

A phrase a package has retired, and must not assert again.

It carries a PHRASE and never a regular expression. A pattern written in a package's config would be
compiled inside every docs build of that package, which puts a malformed pattern, a pathological one and
an over-broad one into the build; a literal costs nothing and covers what the fleet's own retired claims
need, because what makes them hard to match is line wrapping, which the check handles itself.

# Fields

- `phrase` — the wording itself, matched literally and case-insensitively, with any run of whitespace
  matching any other, so a phrase broken across a line wrap is still found.
- `reason` — what to say instead, shown with every finding.
- `decision` — the record that retired it, where the package keeps one.
"""
Base.@kwdef struct RetiredClaim
    phrase::String
    reason::String
    decision::String = ""
end

"""
    Setting

A package's value for one rule parameter.

# Fields

- `rule` — the rule that reads it.
- `name` — the parameter's name.
- `value` — the value itself.
"""
Base.@kwdef struct Setting
    rule::Symbol
    name::Symbol
    value::Union{String,Symbol,Bool,Int,Vector{String},Vector{RetiredClaim}}
end

"""
    Example

Something a rule's check must judge a known way, so that the check can be shown to match the rule it
names. The concrete types differ by what they materialise into: [`TextExample`](@ref),
[`TreeExample`](@ref), [`ModuleExample`](@ref), [`SiteExample`](@ref), [`QuestionExample`](@ref) and
[`HistoryExample`](@ref).
"""
abstract type Example end

"""
    TextExample

One text, judged by a check that reads a source text.

A rule whose behaviour is a package's to supply cannot otherwise be shown to work, which is what
`settings` answers. A parameter empty by default makes its check silent by default, so every example of
it complies and the rule carries no demonstration that it ever fires.

# Fields

- `fileset` — the file set the text stands for.
- `text` — the text itself.
- `expect` — the locations the check must report, empty when the text complies.
- `clause` — the clause of the rule's statement this example is for.
- `settings` — the package settings the example is judged under, empty for the rule's own defaults.
"""
struct TextExample <: Example
    fileset::FileSet.T
    text::String
    expect::Vector{Location}
    clause::String
    settings::Vector{Setting}
end
TextExample(fileset, text, expect, clause) = TextExample(fileset, text, expect, clause, Setting[])

"""
    TreeExample

A small file tree, judged by a check that reads one.

# Fields

- `files` — each path with its content.
- `expect` — the locations the check must report, empty when the tree complies.
- `clause` — the clause of the rule's statement this example is for.
"""
struct TreeExample <: Example
    files::Vector{Pair{String,String}}
    expect::Vector{Location}
    clause::String
end

"""
    ModuleExample

Julia source loaded into a fresh module, judged by a check that reads the loaded package.

# Fields

- `source` — the source to load.
- `expect` — the locations the check must report, empty when the source complies.
- `clause` — the clause of the rule's statement this example is for.
"""
struct ModuleExample <: Example
    source::String
    expect::Vector{Location}
    clause::String
end

"""
    SiteExample

Pages built into a site, judged by a check that reads the built site.

# Fields

- `pages` — each page path with its content.
- `expect` — the locations the check must report, empty when the pages comply.
- `clause` — the clause of the rule's statement this example is for.
"""
struct SiteExample <: Example
    pages::Vector{Pair{String,String}}
    expect::Vector{Location}
    clause::String
end

"""
    QuestionExample

A question, judged by a check that reads one — the language rules every question put to the owner passes.

# Fields

- `question` — the question itself.
- `expect` — the locations the check must report, empty when the question complies.
- `clause` — the clause of the rule's statement this example is for.
"""
struct QuestionExample <: Example
    question::Question
    expect::Vector{Location}
    clause::String
end

"""
    HistoryExample

A repository built by a shell script in an empty directory, judged by a check that reads the history —
the rules the end-of-turn hook decides.

# Fields

- `script` — the shell lines that build the repository, run in the directory.
- `expect` — the locations the check must report, empty when the repository complies; a history
  location names no file and no line.
- `clause` — the clause of the rule's statement this example is for.
"""
struct HistoryExample <: Example
    script::String
    expect::Vector{Location}
    clause::String
end

"""
    Parameter

A value a rule reads that a package may set for itself, such as how a docstring's first sentence leads.

# Fields

- `name` — what the rule calls it.
- `default` — the value where a package sets none.
"""
struct Parameter{T}
    name::Symbol
    default::T
end

"""
    Rule

One rule of the rulebook, carrying its own statement, the check that decides a violation, and the
examples that show the check matches the statement.

A rule with an access tag is a READER'S rule: the readers of a documentation review are derived from
these tags rather than listed. A rule naming a discipline goes to that discipline's reader where the package
declares it, and to nobody — said in the report — where it does not.

A file set is shared and some rules are not, which is what `files_parameter` answers. Which pages must
carry the provenance banner differs per package and has nothing to do with which pages are rationale.

Expressed as a file set, widening one rule's reach drags every other rule reading that set along with
it. A rule naming a parameter lets a package say which files it means and leave the sets alone.

# Fields

- `id` — its stable identifier.
- `statement` — the rule in plain English; this is its only home.
- `why` — what goes wrong without it.
- `intention` — whether its defects are in documentation or in code.
- `filesets` — the file sets it runs over.
- `files_parameter` — a parameter of globs a package may set to name this rule's files in place of
  `filesets`, or `nothing`.
- `check` — what decides a violation, or `nothing` where nothing does.
- `unchecked_reason` — why it has no check, required when it has none.
- `hook` — the shell lines the end-of-turn hook runs for a rule that reads the history, printing one
  line per violation; empty for every other rule. The check and the hook are one program.
- `parameters` — the values a package may set.
- `examples` — texts, trees, sources, pages or questions the check must judge a known way.

- `access` — what a reader must be given beyond the unit; empty where a program decides it or a
  session keeps it as a habit.
- `discipline` — the catalogued discipline deciding it takes, or `nothing`: any careful reader.
"""
Base.@kwdef struct Rule
    id::Symbol
    statement::String
    why::String = ""
    intention::Intention.T = Intention.DOCUMENTATION
    filesets::Vector{FileSet.T} = FileSet.T[]
    files_parameter::Union{Symbol,Nothing} = nothing
    check::Union{ProgramCheck,AgentCheck,Nothing} = nothing
    unchecked_reason::String = ""
    hook::String = ""
    parameters::Vector{Parameter} = Parameter[]
    examples::Vector{Example} = Example[]
    access::Vector{Access.T} = Access.T[]
    discipline::Union{Symbol,Nothing} = nothing
end

# ────────────────────────────────────────────────────────────────────── who reads, and what runs

"""
    AgentRole

One kind of agent an instrument launches: what it reads, what it is kept from, and which rules it checks.

# Fields

- `id` — its stable identifier.
- `instrument` — the instrument that launches it.
- `reads` — the file sets it is given.
- `site` — whether it reads the built site rather than the source.
- `kept_from_code` — whether the code is withheld from it.
- `description` — who the reader is, in two or three sentences.
- `rules` — the rules it checks; empty makes it an open reader, looking for what no rule names yet.
- `strength` — which model it runs on.
- `cap` — how many distinct defects it may report, the agent saying how many it left out.
"""
Base.@kwdef struct AgentRole
    id::Symbol
    instrument::Symbol
    reads::Vector{FileSet.T} = FileSet.T[]
    site::Bool = false
    kept_from_code::Bool = false
    description::String
    rules::Vector{Symbol} = Symbol[]
    strength::Strength.T = Strength.ECONOMY
    cap::Int
end

"""
    Discipline

A field of expertise a package may declare it needs a reader to have, catalogued once in this package
and shared: a fluid-dynamics theoretician serves two of the science packages.

A reader with a discipline is the same model with a standpoint, not a different model. It is derived
into the panel as an OPEN reader — a specialist reading the whole documentation for whatever is wrong in
its field — bound only to a rule that names its discipline.

# Fields

- `id` — its stable identifier, which a package names in its config's `disciplines`.
- `description` — who the reader is, in two or three sentences.
"""
Base.@kwdef struct Discipline
    id::Symbol
    description::String
end

"""
    Budget

The one ceiling on a run: how many fix passes it may make.

There is no ceiling on agent launches, as ruled 2026-09-21: the design bounds them — a panel over the
units per stage, one relaunch each, one verifier per unit holding open findings — and a run interrupted
before its end is continued, not capped. One pass by default [ruled 2026-09-26: a second pass re-verified
unchanged text and moved a fifth of the verdicts by variance].

# Fields

- `fix_passes` — how many times the open findings may go back to the fixer.
"""
Base.@kwdef struct Budget
    fix_passes::Int = 1
end

"""
    Usage

What one stage's agents cost, as the platform's own records count it.

Recorded by `gbg run cost` from the agents' own transcripts, never from the launch's summary field,
which counts a tenth of the cache activity where nearly all of the cost is [measured on
[GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/), 2026-09-24].

# Fields

- `stage` — the stage, as `Run.stage` names it.
- `pass` — the fix pass it belongs to, `0` for the reading stage.
- `agents` — how many agent records were summed.
- `input`, `cache_write`, `cache_read`, `output` — the token counts, summed over every record.
"""
Base.@kwdef struct Usage
    stage::String
    pass::Int = 0
    agents::Int = 0
    input::Int = 0
    cache_write::Int = 0
    cache_read::Int = 0
    output::Int = 0
end

"""
    Instrument

A review procedure the owner starts, as the design's instrument table prints it.

Its readers are not a field: they are derived from the rules at run time, by the catalogue.

# Fields

- `id` — its stable identifier.
- `purpose` — what it is for.
- `intention` — documentation or code.
- `decider` — what makes a finding real.
- `fixer` — who fixes what it found.
- `when` — when it runs.
- `ends` — when a run ends.
- `budget` — what a run may spend.
- `built` — false while its row is future: no skill, no run.
"""
Base.@kwdef struct Instrument
    id::Symbol
    purpose::String
    intention::Intention.T
    decider::Decider.T
    fixer::Fixer.T
    when::String
    ends::String
    budget::Budget
    built::Bool = true
end

"""
    AlwaysOn

A program check that every build and test runs; nobody starts it and it has no runs.

# Fields

- `id` — its stable identifier.
- `purpose` — what it is for.
- `intention` — whether its defects are in documentation or in code.
- `fixer` — who fixes what it found.
- `decider` — what decides that a finding is real, a program by definition.
- `when` — which builds or tests run it.
"""
Base.@kwdef struct AlwaysOn
    id::Symbol
    purpose::String
    intention::Intention.T
    fixer::Fixer.T
    decider::Decider.T = Decider.PROGRAM
    when::String
end

"""
    Generated

A file, or a part of a file, that a Julia function writes and the wiring check compares.

# Fields

- `paths` — `paths(cfg)::Vector{String}`, the paths it writes in a given package.
- `part` — how much of each path it writes.
- `generator` — the function that writes it, named rather than held, so this value stays below `Render`.
"""
struct Generated
    paths::Function
    part::Part.T
    generator::Symbol
end

# ───────────────────────────────────────────────────────────────── a package's own settings

"""
    Exclusion

Takes some of a package's files out of every rule: part of the package that is not held to the
rulebook at all, as a whole, while it waits for something the owner has named.

# Fields

- `files` — the files, as file-set patterns.
- `reason` — why no rule reads them, shown on the package's own site.
"""
Base.@kwdef struct Exclusion
    files::Vector{String}
    reason::String
end

"""
    Switch

Turns one rule, agent role or instrument off in one package, or in some of its files.

# Fields

- `target` — what is switched off.
- `reason` — why it does not apply here, shown on the package's own site.
- `files` — the files it is off for, empty for the whole package.
"""
Base.@kwdef struct Switch
    target::Symbol
    reason::String
    files::Vector{String} = String[]
end

"""
    Deferral

Says that one rule is owed here and not yet met: a question with a condition on it, where a switch is
an answer. A deferred rule reports nothing in a build or a test — a deferral never fails a build — and
is listed beside the switches on the package's own site and by `gbg check`, so "not yet" is on the
record as owed rather than filed as "does not apply".

# Fields

- `rule` — the rule deferred.
- `until` — what would close it: the condition on which the package means to meet the rule.
"""
Base.@kwdef struct Deferral
    rule::Symbol
    until::String
end

"""
    PatternRule

A rule a package adds for itself: a pattern its own files must not, or must, contain.

# Fields

- `id` — its identifier within the package.
- `statement` — the rule in plain English.
- `filesets` — the file sets it reads.
- `pattern` — the pattern.
- `forbidden` — whether a match breaks it, or its absence.
- `trigger` — if set, a match counts only near a line matching this, reported there.
- `window` — lines either side of a trigger.
- `escape` — a match it accompanies is cleared.
- `skip` — regions between two headings, unread.
- `examples` — texts it must judge a known way.
"""
Base.@kwdef struct PatternRule
    id::Symbol
    statement::String
    filesets::Vector{FileSet.T}
    pattern::Regex
    forbidden::Bool = true
    trigger::Union{Regex,Nothing} = nothing
    window::Int = 0
    escape::Union{Regex,Nothing} = nothing
    skip::Vector{Pair{String,String}} = Pair{String,String}[]
    examples::Vector{TextExample} = TextExample[]
end

"""
    Config

A package's settings, written by hand in `.gbg/config.jl` and read by a parser that evaluates nothing.

# Fields

- `package` — its name.
- `tool` — the version of this package it pins, or `:dev` here.
- `docs_build` — what builds its documentation.
- `test` — what runs its tests.
- `rules` — its own pattern rules.
- `filesets` — file sets, where defaults miss.
- `normative` — the documents that bind it.
- `copies` — each build-time copy and its tracked source.
- `generated` — pages a build writes, which no rule reads.
- `switches` — what is off here, with reasons.
- `deferrals` — what is owed and not yet met, with what closes it.
- `settings` — its values for rule parameters.
- `code_areas` — its code in named areas, one hunter each.

- `disciplines` — the catalogued disciplines its documentation needs read by.
- `material` — documents a reader may consult and never report on: the rationale documents beyond the
  one `architecture_doc` names.
- `claude_documentation` — the headings of its `CLAUDE.md` sections that are documentation.
- `exclusions` — files no rule reads, with the reason.
- `leak_emails` — the email addresses the owner approves for publication.
- `leak_terms` — words never published, as the machines' names: filled by `gbg leak` from this machine's
  `~/.gbg/leak-terms`, and refused in `.gbg/config.jl`, which is itself published.
"""
Base.@kwdef struct Config
    package::String
    tool::Union{VersionNumber,Symbol}
    docs_build::Vector{String} = String[]
    test::Vector{String} = String[]
    rules::Vector{PatternRule} = PatternRule[]
    filesets::Dict{FileSet.T,Vector{String}} = Dict{FileSet.T,Vector{String}}()
    normative::Vector{String} = String[]
    copies::Vector{Pair{String,String}} = Pair{String,String}[]
    generated::Vector{String} = String[]
    switches::Vector{Switch} = Switch[]
    deferrals::Vector{Deferral} = Deferral[]
    settings::Vector{Setting} = Setting[]
    disciplines::Vector{Symbol} = Symbol[]
    code_areas::Vector{Pair{Symbol,Vector{String}}} = Pair{Symbol,Vector{String}}[]
    material::Vector{String} = String[]
    claude_documentation::Vector{String} = String[]
    exclusions::Vector{Exclusion} = Exclusion[]
    leak_emails::Vector{String} = String[]
    leak_terms::Vector{String} = String[]
end

"""
    Settled

A question the owner settled, kept in `.gbg/settled.jl` and given to agents as "do not report". 

# Fields

- `question` — the question it answers.
- `text` — the ruling, in his own words.
- `date` — when he gave it, as `YYYY-MM-DD`.
- `locations` — what the ruling is about, quotes included, re-anchored like any other location.
"""
Base.@kwdef struct Settled
    question::String
    text::String
    date::String
    locations::Vector{Location} = Location[]
end

# ──────────────────────────────────────────────────────────────────────── what a run did

"""
    DocFix

One documentation-fixer attempt at one finding, with the program and agent judgements of it. 

# Fields

- `finding` — the finding it fixed.
- `pass` — which fix pass made it.
- `commit` — the commit it landed in.
- `formula_edit` — whether it changed mathematics, which needs agreement and a numeric check.
- `blind` — the verifier's verdict (one verifier sees the text and the diff since 2026-09-26).
- `with_diff` — a second verifier's verdict, in records from before that; `nothing` since.
- `agreeing_code` — the code the fixer quoted as agreeing with the new text.
- `note` — what the program did to the verdict, if anything: demoted for a quote not in the text, or
  no verifier answered.
"""
Base.@kwdef struct DocFix
    finding::String
    pass::Int
    commit::String = ""
    formula_edit::Bool = false
    blind::Verdict.T
    with_diff::Union{Verdict.T,Nothing} = nothing
    agreeing_code::Union{Location,Nothing} = nothing
    note::String = ""
end

"""
    CodeFix

One approved code fix and the single audit of it, kept with the question that approved it.

# Fields

- `question` — the question whose answer approved it.
- `direction` — how the owner asked for it to be fixed, where he said.
- `attempts` — how many attempts it took.
- `commits` — the commits it landed in.
- `touched_tests` — whether it changed anything under `test/`, which the audit is told first.
- `audit` — the one audit run over it.
- `proportionate` — whether the change was no wider than the defect and the direction.
- `contract_kept` — whether it left every documented contract and default alone.
- `old_input_works` — whether input that worked before still works.
- `concerns` — what the audit raised.
- `note` — the audit's sentence to the owner.
"""
Base.@kwdef struct CodeFix
    question::String
    direction::String = ""
    attempts::Int = 1
    commits::Vector{String} = String[]
    touched_tests::Bool = false
    audit::String = ""
    proportionate::Bool = true
    contract_kept::Bool = true
    old_input_works::Bool = true
    concerns::Vector{String} = String[]
    note::String = ""
end

"""
    Run

One execution of one instrument on one package, stored beside its report.

The count `dropped` is what keeps an abandoned record honest. Stopping a run removes its open findings
from the list — what a verdict had closed stays — and leaves its launch count alone, and those two read
together say that every reader wrote its file and none of them found anything — of a run that found a
hundred. What was thrown away is part of what
happened, and belongs where the run is written down rather than only in a line nobody keeps.

A bound reader carries rules; an open one carries a standpoint and no rule. Bound is the default, and
runs most often.

# Fields

- `id` — its identifier, which names its directory.
- `instrument` — the instrument that ran.
- `tool_version` — the version of this package that ran it.
- `first_commit` — the commit the package was at when it started.
- `budget` — what it was allowed to spend.
- `stage` — the stage it is at.
- `findings` — what it found.
- `fixes` — the documentation fixes it made.
- `questions` — what it asked the owner.
- `code_fixes` — the code fixes its questions were answered with, added as they land.
- `agent_launches` — how many agents it launched.
- `tokens` — what they cost, where the platform reports it.
- `stop` — why it ended.

- `readers` — which readers it launches: `:bound`, `:open` or `:both`.
- `passes` — how many fix passes it has begun; the cap is `budget.fix_passes`.
- `model` — the careful model its readers ran on, or `"session"` where they ran on whatever model the
  session itself was on, which is the default and the only honest answer when nobody named one.
- `sequential` — whether its agents were launched one at a time rather than together.
- `scope`, `base`, `driver` — `:changed` read what moved since `base`; the SHA-256 of the driver used.
- `already_failing` — the rules already violated when it opened, so a fix is held to what it broke.

- `dropped` — how many findings the owner's stop threw away, `0` for every other run.

- `unreverted` — the fix commits a verdict said to revert and git could not, because a later fix
  conflicts; each leaves a rejected edit in the tree, and the run cannot end as evaluated.
- `silent` — the agents that wrote nothing, or nothing readable, after being launched again once; the
  report names each, and none is read as a clean result.
- `rulebook` — the digest of the rules it judged by, which a later `--scope changed` run compares with
  its own: a version number does not move when a development checkout's rules do.
- `pass_since` — the commit the current fix pass began at; its fixes are the commits after it.
- `dropped_ids` — what the owner's stop threw away, kept in `findings` with its text [ruled 2026-09-26]
  and carried nowhere.
- `usage` — what each stage's agents cost, per stage and pass, as `gbg run cost` recorded it.
"""
Base.@kwdef struct Run
    id::String
    instrument::Symbol
    tool_version::String
    first_commit::String
    budget::Budget
    stage::Symbol
    findings::Vector{Finding} = Finding[]
    fixes::Vector{DocFix} = DocFix[]
    questions::Vector{Question} = Question[]
    code_fixes::Vector{CodeFix} = CodeFix[]
    agent_launches::Int = 0
    tokens::Union{Int,Nothing} = nothing
    stop::Stop.T = Stop.DONE
    readers::Symbol = :bound
    passes::Int = 0
    model::String = "session"
    sequential::Bool = false
    scope::Symbol = :full
    base::String = ""
    driver::String = ""
    already_failing::Vector{Symbol} = Symbol[]
    dropped::Int = 0
    unreverted::Vector{String} = String[]
    silent::Vector{String} = String[]
    rulebook::String = ""
    pass_since::String = ""
    dropped_ids::Vector{String} = String[]
    usage::Vector{Usage} = Usage[]
end

end # module Model
