# The design's §4.1, §5.3; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Roles.DocumentationReview

Who reads a package during a documentation review, and what each of them is given — DERIVED from the
rules, not listed.

Until 2026-09-20 this file held nineteen readers written by hand, twelve of them given identical
material on the identical model and differing only in the sentence saying who they were. What replaced
them is a computation over two tags each reader's rule carries: what deciding it requires a reader to
be GIVEN (`Rule.access`) and, for the rare rule whose own words are a field's, which field
(`Rule.discipline`). Three blind readers put the access tags on from the rules' text alone and agreed on
them (Fleiss' kappa 0.90 in round 1; 0.74 in round 0, before the rewording).

The readers come in two kinds. A BOUND reader carries rules: one per bundle of material under one
principle — a reader given more material can decide any rule needing less, except that a rule needing
NOTHING goes to a reader given nothing, because more material would change the answer — plus, for a rule
that names a discipline, that discipline's reader where the package declares it.

An OPEN reader carries a standpoint and no checklist, and finds what no rule names: the two standpoints
here, whose yield was recorded highest in the one review that recorded it, and one expert per discipline
the package declares — the same model with a specialist's standpoint, reading the whole documentation for
what is wrong in its field. On 2026-09-21 the owner ruled, on the record of what checked each rule before,
that formulas true of the code, notation, coverage and the identity sentence are a careful generalist's
with the source open, not an expert's; only stating maps without flattening is a geometer's.

A rule no reader can be given — one needing the network, or git history, or a discipline the package does
not declare — is reported as a GAP: a reader that cannot recognise the defect returns a pass
indistinguishable from not looking.

**`kept_from_code` and `site` are the load-bearing fields.** The withheld reader's whole value is that
the source and the other pages are not in front of it; it reads the BUILT page, which is exactly one
page with nothing else in it.
"""
module DocumentationReview

using ...Model

const FS = Model.FileSet
const AC = Model.Access
const INSTRUMENT = :documentation_review

"""
    DISCIPLINES

The fields of expertise a package may declare, catalogued once and shared across the fleet. A package
names the ones it needs in its config's `disciplines`; one it needs and this list lacks is requested
from the tool's session, which adds it here for everyone. First written 2026-09-20 from the readers the
old tree kept per package; rewritten 2026-09-21 as experts with a licence to judge, after the attack and
the blind comparison of 2026-09-21.
"""
const DISCIPLINES = Model.Discipline[
    Model.Discipline(id = :differential_geometry,
        description = "A differential geometer judges whether the structure the package names — the manifold with its coordinates and origin, frame, orientation, metric and measure, the group its operations are claimed invariant under, and the identifications between objects, such as vector with covector by the metric — is the structure its statements use, and whether each statement keeps to it. It traces each sign, argument order and measure to the structure it rests on, and asks which continuum identities the discretization keeps, where, and which it loses. It reports a structure a statement rests on that no page declares or two declare differently, an identification used where its hypothesis fails, a structure named that nothing uses, and a declared choice whose reason leaves a geometer's objection standing. Each filing names the standard, the alternative and, where a reason is stated, what it leaves unanswered."),
    Model.Discipline(id = :spectral_numerics,
        description = "A numerical analyst of Fourier pseudo-spectral methods judges whether the discretization is apt for the use the documentation declares and whether its claims about it hold. It reads the transforms, their normalization and conjugate-symmetric half, the Nyquist planes, dealiasing and the band it leaves against the scales computed, spectral differentiation, shell-binned spectral estimators as lattice quadratures, interpolation and anterpolation between grid and points, time stepping with its stability, order and stiff-term treatment, and the floating-point precision any stated number or equality depends on. A spectrum's sampling variance is the statistician's and the law it is compared with the theorist's. It reports a claimed property the scheme lacks though code matches formula; an estimator given the name of the continuous quantity it approximates with no word on where the two differ; a method that falls short of the declared use, stating that use, the requirement it implies and the measure of the shortfall; an error, convergence or cost claim without its order and regime; a claim made for one precision and true in another; and a scheme cited but varied without saying so. Each names the standard applied and the alternative."),
    Model.Discipline(id = :turbulence_theory,
        description = "A theorist of turbulence judges whether the package's physics is stated as the field states it — or, where it departs, says so and converts — never against how the grid estimates a quantity. It reads laws, constants and scales against their papers in value, convention, attribution and validity range; the relations theory fixes between constants; the hypotheses each result rests on — homogeneity, isotropy, stationarity, scale separation, a box average for the ensemble — and whether each is stated, met by the documented runs and testable by the shipped diagnostics; whether those runs reach each law's validity range; and what the forcing does to the statistics measured there. It reports a departure from a source; a relation the theory fixes between constants stated separately; a value or floor neither cited nor derived, placed where its source does not put it, or placed without saying what fails below it, reported as unsupported and never re-set; a hypothesis unstated, unmet or untestable; a diagnostic whose definition is not the quantity its name denotes, its estimator being the analyst's; and a choice whose stated reason a result contradicts, an unmet hypothesis undermines or a different question answers. Each filing names that result, hypothesis or question, the field's alternative, and what the reason leaves unanswered."),
    Model.Discipline(id = :cloud_microphysics,
        description = "A cloud microphysicist judges whether the model fits the regime its documentation claims and its examples run. It reads the moist thermodynamics and its linearization, activation, the growth laws and their defaults, the supersaturation budgets over water and ice, the size distribution and its reductions to moments or to one radius, ice nucleation, glaciation and collection, the processes omitted, the microphysical side of each turbulence closure — what the particles do to the supersaturation they see, the turbulence law itself being the theorist's — and whether the package's levels of model, from parcel to resolved simulation, are consistent levels of one hierarchy. It reports an assumption or an omitted process, such as spherical particles or no ventilation, given no reason for the regime; a default or example value implausible at its stated conditions, or given with no conditions to judge it by; a law or constant used outside the phase, size or range its source states; a symbol used against the source the documentation cites or, where it cites none, against the usual one, named; a level of the hierarchy defining a quantity unlike the one it approximates; and a stated reason that leaves a physical question open. Each names the source, the alternative and the open question."),
    Model.Discipline(id = :statistical_estimation,
        description = "A statistician judges whether each documented estimator, selector and diagnostic is the right tool for its question under the package's declared use. It reads the sampling model behind every standard error, bias, rate and stability claim — the independence, stationarity and weighting each sample count assumes, or the effective sample size under weights or dependence that replaces it — the regime where each property holds, and the tests as the documentation's evidence for them; a spectrum's estimator is the spectral analyst's. It reports a standard error, bias, rate, stability claim or estimand stated without the assumption it needs or false for the declared use; an estimate with no estimand; an uncertainty the data cannot support; and a choice a named alternative would better serve by a named criterion. Each quotes the package's reason and what it leaves unanswered, an absent reason being the finding."),
    Model.Discipline(id = :software_architecture,
        description = "A software architect judges the design as the documentation states it against what the package is for and the changes it expects, in Julia's terms: a method may sit beside its operation family or beside its type, and a generic extended in several modules is not split. It reads the modules and their responsibilities, the interfaces and dependency direction between them, each invariant and the mechanism the documentation says keeps it, the quality attributes the design buys and at what cost, and the reasons recorded for each decision with the alternatives rejected. It reports a module whose parts change for different reasons or whose responsibility is not stated; a responsibility placed where a change the documentation expects would ripple across parts; a dependency against the stated layering, or a declared policy of reaching into siblings' unexported names rather than exporting them; an interface no part states or wider than the parts name; a concept two modules own or two names denote; a contract stated at two strictnesses in two places, or whose grain — entry, aggregate or call — is unfixed; a duty put on the caller with no word on what its breach does; a quality attribute claimed without its cost; a mechanism a simpler design would replace, that design and what it gives up named; an invariant with no stated mechanism, or left to care where a named enforcement would hold it, with its cost; and a decision whose recorded reason does not answer the objection stated. Each names the principle, the alternative and the recorded decision it answers, quoting what the reason leaves unanswered or that none is recorded; an alternative the recorded reason already weighs is not reported unless the reader says why the weighing is wrong."),
]

# ── the bundles of material a bound reader may be given ──────────────────────────────────────────
#
# Three, in the order a rule is tried against them. `given` is the material; a rule fits a bundle when
# everything it needs is in `given`. The first bundle a rule fits is the one it goes to, which is the
# merging principle above — and NOTHING sits only in the first, so a rule needing nothing can go nowhere
# else.

const WITHHELD = (
    id = :withheld, given = Set([AC.NOTHING]),
    reads = [FS.PAGES, FS.DOCSTRINGS, FS.LITERATE, FS.RATIONALE], site = true, kept_from_code = true,
    description = "A scientist in the package's own fields, new to the package, on a first read of ONE page — every other page, the design documents and the source withheld. Judges only what this page says by itself: a term of the package it uses before it defines, a sentence without a verb, a symbol it binds nowhere, a comment that will not render as prose. Standard mathematics and the field's own vocabulary need no definition; the package's do.",
    cap = 10)

const FULL = (
    id = :full, given = Set([AC.SIBLINGS, AC.OTHER_DOCUMENTS, AC.SOURCE]),
    reads = [FS.RATIONALE, FS.PAGES, FS.DOCSTRINGS, FS.LITERATE], site = false, kept_from_code = false,
    description = "A careful reader of the whole documentation with the source beside it: every docstring, every page, the reference list, the notation page and the package's config. Judges what one place says against what the others say and against the code it documents — expanding a formula against the code rather than taking the docstring's word.",
    cap = 10)

const RENDERED = (
    id = :rendered, given = Set([AC.RENDERED, AC.SIBLINGS, AC.OTHER_DOCUMENTS]),
    reads = [FS.PAGES, FS.DOCSTRINGS, FS.LITERATE], site = true, kept_from_code = false,
    description = "A reader of the BUILT site, page by page, as a visitor meets it. Judges what the build made of the source: what renders wide, what renders as prose that was meant as code or as code that was meant as prose, what Literate and Markdown made of a comment.",
    cap = 8)

const BUNDLES = [WITHHELD, FULL, RENDERED]

# ── the open standpoints ──────────────────────────────────────────────────────────────────────────
#
# Two, on the two bundles whose readers exist anyway. In the one review whose yield was recorded
# (GBGHomogeneousTurbulence, 2026-08-24) a plain-sense reader had 18 of 18 findings fixed and a
# logician 22 of 22, the two highest counts on the panel. This is the one list a hand still writes.

const STANDPOINTS = [
    (id = :plain_sense, bundle = WITHHELD,
     description = "Asks of each sentence whether it means anything and whether it earns its place. Reports the sentence that survives deletion without loss, and the one whose meaning cannot be recovered from the words.",
     cap = 8),
    (id = :logician, bundle = FULL,
     description = "Reads definitions and arguments as formal objects. Reports circularity, equivocation between two senses of one word, a conclusion that does not follow, and an unfalsifiable claim dressed as a specification.",
     cap = 6),
]

"""
    READER_IDS

Every id a derived reader can have: the three bundles, the two standpoints and every catalogued
discipline. A package's `Switch` may name any of them, which is how a reader is turned off.
"""
const READER_IDS = Set{Symbol}(vcat([b.id for b in BUNDLES], [s.id for s in STANDPOINTS],
                                    [d.id for d in DISCIPLINES]))

"The ids of the discipline readers, which `select` counts as open whether or not a rule binds them."
const DISCIPLINE_IDS = Set{Symbol}(d.id for d in DISCIPLINES)

# A switch on the whole package turns a reader or a rule off; one on named files does not, since a
# reader is not launched per file.
off(cfg::Model.Config, id::Symbol) = any(s -> s.target === id && isempty(s.files), cfg.switches)

role(b, rules::Vector{Symbol}; id = b.id, description = b.description, cap = b.cap) =
    Model.AgentRole(; id, instrument = INSTRUMENT, reads = b.reads, site = b.site,
                    kept_from_code = b.kept_from_code, description, rules,
                    strength = Model.Strength.FULL, cap)

"""
    derive(rules, cfg) -> (roles, gaps)

The readers a documentation review of the package configured by `cfg` launches, computed from the
rules that carry an access tag. The arguments are `rules`, the rulebook, and `cfg`, the package's
config. Returns the readers, bound first and open after, and the gaps: one line for each tagged rule
that no reader is given, including a rule naming a discipline the package does not declare.

Every reader runs on the careful model — the owner's ruling of 2026-09-19 that the model is the only
carefulness dial, and of 2026-09-20 that the smaller panel runs careful. A bundle no rule lands in is
not launched. A declared discipline is launched whether or not a rule binds it: it is an open reader
first, and bound to the rules that name it.
"""
function derive(rules::Vector{Model.Rule}, cfg::Model.Config)
    tagged = [r for r in rules if !isempty(r.access) && !off(cfg, r.id)]
    roles = Model.AgentRole[]
    gaps = String[]

    # The bound readers, one per bundle a rule lands in.
    bound = Dict{Symbol,Vector{Symbol}}(b.id => Symbol[] for b in BUNDLES)
    for r in tagged
        r.discipline === nothing || continue
        need = Set(r.access)
        if AC.NOTHING in need && length(need) > 1
            push!(gaps, "$(r.id) is tagged NOTHING together with more, and NOTHING is exclusive; it goes to no reader until its tag is one thing")
            continue
        end
        at = findfirst(b -> need ⊆ b.given, BUNDLES)
        if at === nothing
            push!(gaps, "$(r.id) needs " * join(lowercase.(replace.(String.(Symbol.(r.access)), "_" => " ")), " + ") *
                        ", which no reader is given")
            continue
        end
        push!(bound[BUNDLES[at].id], r.id)
    end
    for b in BUNDLES
        isempty(bound[b.id]) && continue
        if off(cfg, b.id)
            # The rules bound to a reader the package switched off go to nobody, and that is a gap per
            # rule, not silence: a switch on `withheld` unjudged every NOTHING-tagged rule without a word
            # (found in review, 2026-09-26).
            for id in bound[b.id]
                push!(gaps, "$id is bound to the $(b.id) reader, which $(cfg.package) has switched off, so nobody judges it")
            end
            continue
        end
        push!(roles, role(b, bound[b.id]))
    end

    # The discipline readers: one per declared discipline, given the full bundle, carrying the rules
    # that name it, open beyond them. A rule naming an undeclared discipline is a gap by name.
    for id in cfg.disciplines
        any(d -> d.id === id, DISCIPLINES) ||
            push!(gaps, "$(cfg.package) declares the discipline $id, which the catalogue does not have")
    end
    for r in tagged
        r.discipline === nothing && continue
        AC.NOTHING in r.access &&
            (push!(gaps, "$(r.id) names a discipline and is tagged NOTHING; a discipline reader is given the full bundle, so it goes to no reader until one of the two changes"); continue)
        r.discipline in cfg.disciplines ||
            push!(gaps, "$(r.id) needs a $(r.discipline) reader and $(cfg.package) declares none, so nobody judges it")
    end
    for d in DISCIPLINES
        d.id in cfg.disciplines || continue
        mine = [r.id for r in tagged if r.discipline === d.id && !(AC.NOTHING in r.access)]
        if off(cfg, d.id)
            # the same as a switched-off bundle reader: its rules are gaps, one each, never silence
            for id in mine
                push!(gaps, "$id needs the $(d.id) reader, which $(cfg.package) has switched off, so nobody judges it")
            end
            continue
        end
        # What no rule names is this reader's; what a rule names is the rule's, and a second report of it
        # under the expert's name is one defect counted twice. The source is in front of this reader
        # because the full bundle carries it, and the sentence says what it is for.
        text = d.description * " An open reader — bound to no rule beyond those it is handed by id — reads the whole documentation and reports whatever is wrong in its field that no rule names; a defect a rule does name is reported under that rule's id, as the rulebook in .gbg/policy/ states it, not as the field's. The code is context for reading the documentation, never the thing under review." *
               (isempty(mine) ? "" : " The rule(s) it is handed are this reader's to judge.")
        push!(roles, role(FULL, mine; id = d.id, description = text, cap = 8))
    end

    # The open readers.
    for s in STANDPOINTS
        off(cfg, s.id) && continue
        push!(roles, role(s.bundle, Symbol[]; id = s.id, description = s.description, cap = s.cap))
    end
    return roles, gaps
end

"""
    select(roles, readers) -> Vector{Model.AgentRole}

The readers one run launches. The arguments are `roles`, the derived panel, and `readers`, the run's
choice: `:bound` for the readers carrying rules, `:open` for the readers carrying a standpoint — the two
standpoints and every discipline reader, whether or not a rule binds it — and `:both`. Returns the
selection, in the panel's order.

A discipline reader that a rule binds is in both: the default run judges the rule, and an open run has
the expert read for whatever else is wrong in its field.
"""
function select(roles::Vector{Model.AgentRole}, readers::Symbol)
    readers === :both && return roles
    readers === :bound && return filter(r -> !isempty(r.rules), roles)
    readers === :open && return filter(r -> isempty(r.rules) || r.id in DISCIPLINE_IDS, roles)
    throw(ArgumentError("readers is bound, open or both, not $readers"))
end

end # module DocumentationReview
