# The design's §4.1, §5.3; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Roles.DocumentationReview

Who reads a package during a documentation review, and what each of them is given — DERIVED from the
rules, not listed.

Until 2026-09-20 this file held nineteen readers written by hand, twelve of them given identical
material on the identical model and differing only in the sentence saying who they were. What replaced
them is a computation over two tags each reader's rule carries: what deciding it requires a reader to
be GIVEN (`Rule.access`) and whether it needs the package's discipline (`Rule.needs_discipline`). Three
blind readers put those tags on from the rules' text alone, and agreed on them (Fleiss' kappa 0.90 on
the material, 0.91 on the discipline).

The readers come in two kinds. A BOUND reader carries rules: one per bundle of material under one
principle — a reader given more material can decide any rule needing less, except that a rule needing
NOTHING goes to a reader given nothing, because more material would change the answer — plus one per
discipline the package declares, carrying every rule that needs one.

An OPEN reader carries a standpoint and no rule, and finds what no rule names; the two here are the two
whose yield was recorded highest in the one review that recorded it.

A rule no reader can be given — one needing the network, or git history — is reported as a GAP, as is
a discipline rule in a package that declares no discipline: a reader that cannot recognise the defect
returns a pass indistinguishable from not looking.

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
old tree kept per package, and not yet attacked.
"""
const DISCIPLINES = Model.Discipline[
    Model.Discipline(id = :differential_geometry,
        description = "A differential geometer reading the mathematics as it is written: maps and pairings stated on the spaces they act on, a fibre kept distinct from its coordinates, an intrinsic object never flattened to a bare vector without saying so. Reports a formula whose stated objects are not the objects the operation acts on."),
    Model.Discipline(id = :spectral_numerics,
        description = "A numerical analyst of Fourier and spectral methods: transforms, their normalizations, aliasing, truncation and the discrete forms of continuous operators. Reports a normalization or an adjoint stated in the prose that the discrete operation does not have."),
    Model.Discipline(id = :turbulence_theory,
        description = "A theoretician of fluid turbulence: statistical descriptions of a flow, spectra, structure functions, closures and the assumptions each rests on. Reports a physical quantity named for something it is not, and an assumption used but not stated."),
    Model.Discipline(id = :cloud_microphysics,
        description = "A cloud physicist: droplet populations, their moments, growth and collision processes, and the parameterizations that stand in for them. Reports a rate, a moment or a distribution documented under the wrong name or the wrong units."),
    Model.Discipline(id = :statistical_estimation,
        description = "A statistician reading each documented quantity as an estimator: its estimand, its bias, what it converges to and under what sampling. Reports an identity sentence that names a computation where it should name what is being estimated."),
    Model.Discipline(id = :software_architecture,
        description = "A senior Julia programmer judging the design AS DOCUMENTED, not as implemented. Reports a documented design that is incoherent, that contradicts itself across pages, or that no competent implementation could satisfy."),
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
    description = "A competent newcomer's first read of ONE page, with every other page, the design documents and the source withheld. Judges only what this page says by itself: a term it uses before it defines, a sentence without a verb, a symbol it binds nowhere, a comment that will not render as prose.",
    cap = 10)

const FULL = (
    id = :full, given = Set([AC.SIBLINGS, AC.OTHER_DOCUMENTS, AC.SOURCE]),
    reads = [FS.RATIONALE, FS.PAGES, FS.DOCSTRINGS, FS.LITERATE], site = false, kept_from_code = false,
    description = "A careful reader of the whole documentation with the source beside it: every docstring, every page, the reference list, the notation page and the package's config. Judges what one place says against what the others say and against the code it documents.",
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
that no reader is given, and one for the discipline rules where the package declares no discipline.

Every reader runs on the careful model — the owner's ruling of 2026-09-19 that the model is the only
carefulness dial, and of 2026-09-20 that the smaller panel runs careful. A bundle no rule lands in is
not launched.
"""
function derive(rules::Vector{Model.Rule}, cfg::Model.Config)
    tagged = [r for r in rules if !isempty(r.access) && !off(cfg, r.id)]
    roles = Model.AgentRole[]
    gaps = String[]

    # The bound readers, one per bundle a rule lands in.
    placed = Set{Symbol}()
    bound = Dict{Symbol,Vector{Symbol}}(b.id => Symbol[] for b in BUNDLES)
    for r in tagged
        r.needs_discipline && continue
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
        push!(bound[BUNDLES[at].id], r.id); push!(placed, r.id)
    end
    for b in BUNDLES
        isempty(bound[b.id]) && continue
        off(cfg, b.id) && continue
        push!(roles, role(b, bound[b.id]))
    end

    # The discipline readers: every rule needing a discipline, to each discipline the package declares.
    expert = [r.id for r in tagged if r.needs_discipline]
    declared = [d for d in DISCIPLINES if d.id in cfg.disciplines]
    for id in cfg.disciplines
        any(d -> d.id === id, DISCIPLINES) ||
            push!(gaps, "$(cfg.package) declares the discipline $id, which the catalogue does not have")
    end
    if !isempty(expert) && isempty(declared)
        push!(gaps, string(length(expert), " rule(s) need a discipline and ", cfg.package,
                           " declares none, so nobody judges them: ", join(String.(expert), ", ")))
    end
    for d in declared
        off(cfg, d.id) && continue
        push!(roles, role(FULL, expert; id = d.id, description = d.description, cap = 8))
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
choice: `:bound` for the readers carrying rules, `:open` for those carrying none, `:both`. Returns the
selection, in the panel's order.
"""
function select(roles::Vector{Model.AgentRole}, readers::Symbol)
    readers === :both && return roles
    readers === :bound && return filter(r -> !isempty(r.rules), roles)
    readers === :open && return filter(r -> isempty(r.rules), roles)
    throw(ArgumentError("readers is bound, open or both, not $readers"))
end

end # module DocumentationReview
