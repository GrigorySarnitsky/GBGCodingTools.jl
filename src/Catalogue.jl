# The design's §3, §5.3, §6, §9; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Catalogue

What this package knows, as values rather than as files: the always-on checks, the instruments, the
rulebook, and the register of everything a generator writes.

It is the third module of the order and holds DATA — a rule sits here beside the check that decides it,
and nothing here runs anything. What is in it today is the instrument table; the rules arrive with the
conversion and the agent roles with the instruments that launch them.

The table here and the one in the design are compared cell by cell by `test/architecture.jl`: a row whose
purpose, intention, decider, fixer, timing or ending drifts from the document fails the suite, so the
document and the code cannot quietly disagree about what an instrument is for.
"""
module Catalogue

using ..Model
using ..Texts

"""
    ALWAYS_ON

The checks every build and every test runs. Nobody starts one, none of them has a run, and what one finds
is fixed by whoever ran the build or the test as part of the work in hand.
"""
const ALWAYS_ON = Model.AlwaysOn[
    Model.AlwaysOn(
        id = :documentation_checks,
        purpose = "Documentation has the house structure and formatting and renders as written",
        intention = Model.Intention.DOCUMENTATION,
        fixer = Model.Fixer.ORDINARY_WORK,
        when = "Every docs build"),
    Model.AlwaysOn(
        id = :code_checks,
        purpose = "The code keeps its tested contracts and every accepted failing test passes",
        intention = Model.Intention.CODE,
        fixer = Model.Fixer.ORDINARY_WORK,
        when = "Every `Pkg.test()`"),
    Model.AlwaysOn(
        id = :wiring_check,
        purpose = "Every generated file or part of a file equals its generator's output",
        intention = Model.Intention.CODE,
        fixer = Model.Fixer.REGENERATE,
        when = "Every build and test"),
]

"""
    INSTRUMENTS

The review procedures the owner starts, in words or by slash command. Each carries the three values that
separate it from every other — what its defects are in, what decides that a finding is real, and who
fixes what it found — and the two sentences the table prints.

The roles each launches are empty here and are filled in the phase that builds that instrument; the leak
scan is not here at all, because the design marks its row future.
"""
const INSTRUMENTS = Model.Instrument[
    Model.Instrument(
        id = :documentation_review,
        purpose = "Documentation is true to the code, correct, consistent and self-contained; the change guard, the checks and a verifier agent check each fix",
        intention = Model.Intention.DOCUMENTATION,
        decider = Model.Decider.AGENT,
        fixer = Model.Fixer.DOCUMENTATION_FIXER,
        when = "Owner's request",
        ends = "Nothing is open after its last pass, or the owner ended it",
        budget = Model.Budget(fix_passes = 4)),
    Model.Instrument(
        id = :bug_hunt,
        purpose = "The code does what its documentation says",
        intention = Model.Intention.CODE,
        decider = Model.Decider.FAILING_TEST,
        fixer = Model.Fixer.CODE_FIXER,
        when = "Owner's request",
        ends = "Every candidate is confirmed or discarded, once",
        budget = Model.Budget(fix_passes = 0)),
    Model.Instrument(
        id = :change_audit,
        purpose = "A code change is no wider than the defect and the owner's direction and still accepts input that worked before; it grades the fix and changes nothing",
        intention = Model.Intention.CODE,
        decider = Model.Decider.AGENT,
        fixer = Model.Fixer.CODE_FIXER,
        when = "After each approved code fix, and on request",
        ends = "One pass over the change",
        budget = Model.Budget(fix_passes = 0)),
]

"""
    FLEET

Every package this one serves, and itself. Each row carries `name`, the package name; `github`, its
`owner/repo` slug; and `path`, where its checkout sits relative to this repository — `"."` for this one.

ONE home for the fleet. Until 2026-09-18 the roster was `[[consumer]]` rows in `fleet.toml` and the
sibling sites were a second list in `Rules/pages.jl`: the same five packages written twice, in two files,
with nothing comparing them. A rename applied to one alone fails silently in BOTH directions — a package
writing the new name gets no finding from `RULE.DOC.SIBLING_LINK`, which has nothing to say about a name
it does not hold, and a package writing the old name is linked to a URL that 404s. `fleet.toml` keeps
only the sweep state, which a verb writes rather than a person declaring it.
"""
const FLEET = [
    # The tool's own row (D15): pin `dev+<sha>[-dirty]`, OK/RED by its own wiring check, never BEHIND.
    (name = "GBGCodingTools",         github = "GrigorySarnitsky/GBGCodingTools.jl",         path = "."),
    (name = "GBGPeriodicFields",      github = "GrigorySarnitsky/GBGPeriodicFields.jl",      path = "../../Isotropic Turbulence/GBGPeriodicFields"),
    # Renamed from GBGIsotropicTurbulence on 2026-09-18: homogeneity is what a triple-periodic box
    # enforces, and isotropy only what one forcing chooses. The PARENT folder is still "Isotropic
    # Turbulence" — that is the directory on disk, not a stale reference.
    (name = "GBGHomogeneousTurbulence", github = "GrigorySarnitsky/GBGHomogeneousTurbulence.jl", path = "../../Isotropic Turbulence/GBGHomogeneousTurbulence"),
    (name = "GBGStreamingStatistics", github = "GrigorySarnitsky/GBGStreamingStatistics.jl", path = "../../Statistics/GBGStreamingStatistics"),
    (name = "GBGCloudPhysics",        github = "GrigorySarnitsky/GBGCloudPhysics.jl",        path = "../../Cloud Physics/GBGCloudPhysics"),
]

"""
    site_of(slug) -> String

Where a repository's documentation is published, from its `owner/repo` slug. The argument is `slug`.
Returns the GitHub Pages URL.

Derived rather than written down beside the slug, so a row cannot name one repository and a site
belonging to another.
"""
function site_of(slug::AbstractString)
    owner, repo = split(slug, '/')
    return "https://" * lowercase(owner) * ".github.io/" * repo * "/"
end

include("Rules/rendering.jl")     # one file per batch of the conversion
include("Rules/docstrings.jl")
include("Rules/arguments.jl")
include("Rules/latex.jl")
include("Rules/pages.jl")
include("Rules/reflection.jl")
include("Rules/site.jl")
include("Rules/shape.jl")
include("Rules/modules.jl")
include("Rules/questions.jl")
include("Rules/citations.jl")
include("Rules/judgement_api.jl")
include("Rules/judgement_cit.jl")
include("Rules/judgement_doc.jl")
include("Rules/judgement_git.jl")
using .JudgementGit: branch_of
include("Rules/judgement_inst.jl")
include("Rules/judgement_test.jl")
include("Rules/judgement_tex.jl")

include("Roles/documentation_review.jl")

"""
    RULES

The rulebook: every rule as a value, beside the check that decides it and the examples that show the
check matches the statement. The ninety-five rules of `policy/RULES.toml` are converted in batches
, one file of `src/Rules/` per batch; `test/conversion.jl` holds the count still
outstanding, which may only fall.
"""
const RULES = Model.Rule[Rendering.RULES..., Docstrings.RULES..., Arguments.RULES..., Latex.RULES..., Pages.RULES..., Reflection.RULES..., Site.RULES..., Shape.RULES..., Modules.RULES..., Questions.RULES..., Citations.RULES..., JudgementApi.RULES..., JudgementCit.RULES..., JudgementDoc.RULES..., JudgementGit.RULES..., JudgementInst.RULES..., JudgementTest.RULES..., JudgementTex.RULES...]


"""
    Cover

How a rule is covered — what finds it broken. `PROGRAM`: a check that runs in every build or test.
`READER`: an agent of a review, given the material the rule's access tag names (or the one agent that
judges a question's language). `INSTRUCTION`: a rule a session follows while working — pushing on commit,
never truncating a scan, verifying by the build — checked by nothing and meant for the session that reads
the rulebook. The owner ruled on 2026-09-21 that every rule is one of these three, and that a statement
about how this tool itself behaves is the design's, not a rule.
"""
module Cover; @enum T PROGRAM READER INSTRUCTION; end

"""
    cover(rule) -> Cover.T

Which of the three covers a rule has, read off the rule itself. The argument is `rule`. Returns the cover.
"""
cover(rule::Model.Rule) = rule.check isa Model.ProgramCheck ? Cover.PROGRAM :
                          (rule.check isa Model.AgentCheck || !isempty(rule.access)) ? Cover.READER :
                          Cover.INSTRUCTION

"""
    RETIRED

Every rule that has left the rulebook, with the reason and the day: its id is never reused, and a
package's switch naming it is still a legal switch. A retirement is on the record here, in the CHANGELOG
and in the commit that removed the value, as the design's change-control section asks.
"""
const RETIRED = [
    (id = Symbol("RULE.INST.FOUR_OBJECTS"),     date = "2026-09-21", reason = "named four instruments; the design has three, and its §3 table is what says what each audits"),
    (id = Symbol("RULE.INST.CLOSURE_LOOP"),     date = "2026-09-21", reason = "spoke of banked findings, lanes and a plateau — the v1 round machinery, gone; the one-search-per-run rule is ARCH §10's"),
    (id = Symbol("RULE.INST.AUDIT_DISPOSED"),   date = "2026-09-21", reason = "spoke of an audit round's staleness check and re-bank — v1 machinery, gone; the change audit's shape is ARCH §4.4's"),
    (id = Symbol("RULE.INST.FIX_FROM_LANES"),   date = "2026-09-21", reason = "spoke of per-lane findings and a consolidated summary — v1 machinery, gone; a fix pass works from the run's findings by id, ARCH §4.3"),
    (id = Symbol("RULE.INST.SEEDS"),            date = "2026-09-21", reason = "seeding and recall measurement survive in no form (IMPLEMENTATION §7); nothing plants a seed"),
    (id = Symbol("RULE.INST.FROZEN_MIDROUND"),  date = "2026-09-21", reason = "spoke of deferred.md, ROUND.toml and replaced verifier scripts — v1 machinery, gone; that a run never changes an instrument is ARCH §10's"),
    (id = Symbol("RULE.INST.CARRY"),            date = "2026-09-21", reason = "spoke of CARRY_LIMIT, re-rated severities and a draining backlog — v1 machinery, gone; that open findings carry over is ARCH §10's, as ruled 2026-09-16"),
    (id = Symbol("RULE.INST.ECONOMY"),          date = "2026-09-21", reason = "economy lanes by default: the opposite of the 2026-09-20 ruling that every reader runs on the careful model"),
    (id = Symbol("RULE.INST.WITNESS"),          date = "2026-09-21", reason = "a statement of how the bug hunt decides (ARCH §4.4, §10), which a consumer's session cannot act on; the design holds it"),
    (id = Symbol("RULE.INST.SELF_REPORT"),      date = "2026-09-21", reason = "a statement of how a fix is verified — blind, then with the diff (ARCH §4.3 steps 5–6); the design holds it"),
    (id = Symbol("RULE.INST.AUDIT_AFTER_CODE"), date = "2026-09-21", reason = "a statement of when the change audit runs — once, after an approved code fix (ARCH §4.4); the design holds it"),
    (id = Symbol("RULE.TEST.RULE_WITH_CHECK"),  date = "2026-09-21", reason = "a statement about this tool's own rulebook — a rule lands with its check (ARCH §7, test/rules.jl); the design and its test hold it"),
    (id = Symbol("RULE.TEST.COUNTS_REMEASURED"), date = "2026-09-21", reason = "a statement about this tool's own records — a count is re-measured, never cited (ARCH §12); the design holds it"),
]

"""
    DISCIPLINES

The fields of expertise a package may declare it needs a reader to have, catalogued once for the
fleet; `DocumentationReview.DISCIPLINES` holds them.
"""
const DISCIPLINES = DocumentationReview.DISCIPLINES

"""
    panel(instrument, cfg) -> (roles, gaps)

The readers one instrument launches for the package configured by `cfg`, and what they cannot judge.
The arguments are `instrument`, the instrument's id, and `cfg`, the package's config. Returns the
readers — derived from the rules' access tags and the package's declared disciplines, never listed —
and one line per gap: a rule no reader is given, or the discipline rules where no discipline is
declared. An instrument without derived readers returns none.

A role says WHO reads and what is withheld from them; what they are asked comes from the rulebook and
the instrument, so a reworded rule reaches every role without a second copy of it being edited.
"""
function panel(instrument::Symbol, cfg::Model.Config)
    instrument === :documentation_review || return (Model.AgentRole[], String[])
    return DocumentationReview.derive(RULES, cfg)
end

"""
    roles_of(instrument, cfg; readers = :both) -> Vector{Model.AgentRole}

The readers one run launches. The arguments are:

- `instrument` — the instrument's id.
- `cfg` — the package's config.
- `readers` — the run's choice: `:bound` for the readers carrying rules, `:open` for those carrying a
  standpoint and none, `:both`.

Returns the selection from [`panel`](@ref), in its order.
"""
roles_of(instrument::Symbol, cfg::Model.Config; readers::Symbol = :both) =
    DocumentationReview.select(first(panel(instrument, cfg)), readers)

"""
    architecture_doc(cfg) -> String

The one rationale document the review holds to a cold read and reads as a target: the value of the
`architecture_doc` parameter, `docs/ARCHITECTURE.md` unless the package's settings say otherwise. The
argument is `cfg`, the package's config. Returns the path, relative to the package root.
"""
function architecture_doc(cfg::Model.Config)
    value = ""
    for rule in RULES, p in rule.parameters
        p.name === :architecture_doc || continue
        value = String(p.default)
        for s in cfg.settings
            s.rule === rule.id && s.name === p.name && s.value isa AbstractString && (value = String(s.value))
        end
        break
    end
    return replace(value, '\\' => '/')
end

"""
    target(cfg, path) -> Bool

Whether a path is a TARGET of the documentation review: something a user reads, which a reader is given
to judge and a finding may be located in. The arguments are `cfg`, the package's config, and `path`,
relative to the package root. Returns the answer, without touching disk.

The targets are exactly [ruled 2026-09-23]: the docstrings, the hand-written pages, the Literate
examples, and the one document [`architecture_doc`](@ref) names. A generated page or a declared copy is
not one, whatever pattern it matches. Every other rationale document is at most MATERIAL — something a
reader may open to judge a target — and only when the package lists it in `material`; by default nobody
is given it.

The review is for the text a user meets. The working notes a package keeps for the sessions that build
it are not that text, however many of them there are: on the first real review they were 72% of what
the readers were handed, under two rules that had just been ruled not to apply to them.
"""
function target(cfg::Model.Config, path::AbstractString)
    p = replace(path, '\\' => '/')
    isempty(p) && return false
    any(g -> replace(g, '\\' => '/') == p, cfg.generated) && return false
    any(c -> replace(first(c), '\\' => '/') == p, cfg.copies) && return false
    p == architecture_doc(cfg) && return true
    for fs in (Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.LITERATE)
        any(pat -> Texts.glob_matches(pat, p), get(cfg.filesets, fs, Texts.DEFAULT_PATTERNS[fs])) && return true
    end
    return false
end

"""
    missing_documents(cfg, root) -> Vector{String}

Every rule parameter that names a file the package does not have. The arguments are `cfg`, the package's
config, and `root`, the package root. Returns one line per parameter, empty when every named file exists.

A rule that reads "the notation page" and is handed a path to nothing passes silently — no reader is
given a page that is not there, and nothing says so. This is printed with the gaps at every launch and
in the report.
"""
function missing_documents(cfg::Model.Config, root::AbstractString)
    out = String[]
    for rule in RULES, p in rule.parameters
        p.default isa AbstractString || continue
        value = p.default
        for s in cfg.settings
            s.rule === rule.id && s.name === p.name && s.value isa AbstractString && (value = s.value)
        end
        isempty(value) && continue
        (endswith(value, ".md") || occursin('/', value)) || continue
        isfile(joinpath(root, value)) ||
            push!(out, "$(rule.id)'s `$(p.name)` names $value, which is not a file here")
    end
    return out
end

"""
    GENERATED

Every path, or part of a path, that a Julia function writes in a package, with the generator that writes
it. The wiring check regenerates each and compares only that part. It is empty until the generators
exist.
"""
const GENERATED = Model.Generated[]

"""
    axes(x) -> Tuple

The three values that separate one check or instrument from every other: what its defects are in, what
decides that a finding is real, and who fixes what it found. The argument is `x`, an
[`Model.AlwaysOn`](@ref) or an [`Model.Instrument`](@ref). Returns the three, in that order.
"""
axes(x) = (x.intention, x.decider, x.fixer)

"""
    rule(id) -> Union{Model.Rule,Nothing}

The rule with that id, or `nothing` where the rulebook holds none. The argument is `id`, the rule's
identifier. Returns the rule.
"""
rule(id::Symbol) = findfirst(r -> r.id === id, RULES) === nothing ? nothing : RULES[findfirst(r -> r.id === id, RULES)]

# `ALWAYS_ON_RULES` stood here until 2026-09-17: the rules no package could switch off. The owner ruled
# the concept away, and the reasoning is in the design's §9 — the rulebook is the DEFAULT, and a package
# overrides any part of it by saying so where a reader can see it. A switch already names the rule, gives
# the reason, and is rendered into the package's own rulebook and onto its site, so an escape is on the
# record whether or not a refusal exists; what the refusal added was a package with a red build and no
# way out but a MAJOR release of this one.

"""
    known_ids() -> Set{Symbol}

Every id a package's config may name in a switch: each rule of the rulebook, each agent role of each
instrument, and each instrument. Returns the set.
"""
function known_ids()
    ids = Set{Symbol}(r.id for r in RULES)
    for i in INSTRUMENTS; push!(ids, i.id); end
    for a in ALWAYS_ON; push!(ids, a.id); end
    union!(ids, DocumentationReview.READER_IDS)              # a derived reader is switched off by name too
    for r in RETIRED; push!(ids, r.id); end                  # a switch on a retired rule stays legal
    return ids
end

"""
    doc(x) -> String

The docstring of a rule, an agent role, an instrument or an always-on check, written from the value
itself. A rule's prose is written once, in the value, and the docstring a reader sees on the package's own
site is derived from it — so the two cannot disagree, and a rule reworded in one place is reworded in
both.

The argument is `x`, the value to describe. Returns the docstring text, which the source attaches with
`@doc doc(x) x`.
"""
function doc(r::Model.Rule)
    io = IOBuffer()
    println(io, "    ", r.id, "\n")
    println(io, r.statement, "\n")
    isempty(r.why) || println(io, r.why, "\n")
    println(io, "- Intention: ", lowercase(replace(string(r.intention), "_" => " ")), ".")
    println(io, "- Covered by: ", cover_words(r), ".")
    isempty(r.filesets) || println(io, "- Runs over: ", join(lowercase.(string.(r.filesets)), ", "), ".")
    r.check === nothing && cover(r) !== Cover.READER && println(io, "- Unchecked because: ", r.unchecked_reason)
    isempty(r.examples) || println(io, "- Shown by ", length(r.examples), " example(s), over ",
                                  length(unique(e.clause for e in r.examples)), " clause(s).")
    return String(take!(io))
end

function doc(role::Model.AgentRole)
    io = IOBuffer()
    println(io, "    ", role.id, "\n")
    println(io, role.description, "\n")
    println(io, "- Launched by: ", role.instrument, ".")
    println(io, "- Reads: ", isempty(role.reads) ? "nothing named" : join(lowercase.(string.(role.reads)), ", "),
            role.site ? ", as the built site" : "", role.kept_from_code ? "; the code is kept from it" : "", ".")
    println(io, "- Checks: ", isempty(role.rules) ? "no rule by name — an open reader, looking for what no rule names yet" :
                              join(string.(role.rules), ", "), ".")
    println(io, "- Strength: ", lowercase(string(role.strength)), "; at most ", role.cap, " distinct defects.")
    return String(take!(io))
end

function doc(i::Model.Instrument)
    io = IOBuffer()
    println(io, "    ", i.id, "\n")
    println(io, i.purpose, "\n")
    println(io, "- Intention: ", lowercase(replace(string(i.intention), "_" => " ")), ".")
    println(io, "- Decided by: ", lowercase(replace(string(i.decider), "_" => " ")), ".")
    println(io, "- Fixed by: ", lowercase(replace(string(i.fixer), "_" => " ")), ".")
    println(io, "- Runs: ", i.when, ".")
    println(io, "- A run ends when: ", i.ends, ".")
    println(io, "- One run may make ", i.budget.fix_passes, " fix pass(es); what it launches is bounded by",
            " the panel and the passes, not capped.")
    return String(take!(io))
end

function doc(a::Model.AlwaysOn)
    io = IOBuffer()
    println(io, "    ", a.id, "\n")
    println(io, a.purpose, "\n")
    println(io, "- Intention: ", lowercase(replace(string(a.intention), "_" => " ")), ".")
    println(io, "- Fixed by: ", lowercase(replace(string(a.fixer), "_" => " ")), ".")
    println(io, "- Runs: ", a.when, ". It has no runs of its own and nobody starts it.")
    return String(take!(io))
end

check_words(c::Model.ProgramCheck) = "a program" * (c.network ? ", which reaches the network and runs only under `gbg check --network`" : "")
check_words(c::Model.AgentCheck) = "an agent, because this needs " * lowercase(replace(string(c.why), "_" => " "))
check_words(::Nothing) = "nothing yet"

"""
    cover_words(rule) -> String

The rule's cover in words, for the rendered rulebook: the program; the reader and what it is given, with
its discipline where the rule names one; or the instruction. The argument is `rule`. Returns the phrase.
"""
function cover_words(rule::Model.Rule)
    c = cover(rule)
    c === Cover.PROGRAM && return check_words(rule.check)
    c === Cover.INSTRUCTION && return "the session, as an instruction: followed while working, checked by nothing"
    isempty(rule.access) && return check_words(rule.check)            # the question-language agent
    given = join(lowercase.(replace.(String.(Symbol.(rule.access)), "_" => " ")), " + ")
    who = rule.discipline === nothing ? "a reader" : "a $(rule.discipline) reader"
    return who * " given " * given * (rule.check isa Model.AgentCheck ? ", because this needs " *
           lowercase(replace(string(rule.check.why), "_" => " ")) : "")
end

end # module Catalogue
