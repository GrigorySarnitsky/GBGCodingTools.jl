# The design's §4.1, §5.3; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Roles.DocumentationReview

Who reads a package during a documentation review, and what each of them is given.

These are batch g, converted from the twenty-two `hats` of the old tree. What survives the conversion is
the READING — who the reader is, what they see, and what is withheld from them. What does not survive is
the prompt: a hat carried several hundred words that restated rules, sharpenings and output formats, and
the design assembles those from the rulebook and the instrument instead, so a reworded rule reaches every
role without a second copy of it being edited.

**`kept_from_code` and `site` are the load-bearing fields.** A reader who can see the source cannot judge
whether the prose stands on its own; the cold reader's whole value is that the design documents and the
module are withheld, and the old catalogue recorded that as `substrate = "siteonly"`.
"""
module DocumentationReview

using ...Model

const FS = Model.FileSet

"""
    ROLES

The readers a documentation review launches. Each carries its own cap, so a role that reports by CLASS —
one finding listing every site — is not cut off partway through a class it has already found.
"""
const ROLES = Model.AgentRole[

    # ── readers with nothing withheld ────────────────────────────────────────────────────────────

    Model.AgentRole(
        id = :api_user, instrument = :documentation_review,
        reads = [FS.PAGES, FS.DOCSTRINGS, FS.LITERATE],
        description = "A scientist trying to use the library from its documentation alone. Reports what they could not do, what they had to guess, and what they got wrong by following the text as written.",
        strength = Model.Strength.ECONOMY, cap = 8),

    Model.AgentRole(
        id = :software_architect, instrument = :documentation_review,
        reads = [FS.RATIONALE, FS.PAGES, FS.DOCSTRINGS],
        description = "A senior Julia programmer judging the design AS DOCUMENTED, not as implemented. Reports a documented design that is incoherent, that contradicts itself across pages, or that no competent implementation could satisfy.",
        strength = Model.Strength.ECONOMY, cap = 8),

    Model.AgentRole(
        id = :logician, instrument = :documentation_review,
        reads = [FS.RATIONALE, FS.PAGES, FS.DOCSTRINGS],
        description = "Reads definitions and arguments as formal objects. Reports circularity, equivocation between two senses of one word, a conclusion that does not follow, and an unfalsifiable claim dressed as a specification.",
        strength = Model.Strength.FULL, cap = 6),

    Model.AgentRole(
        id = :quantifier_auditor, instrument = :documentation_review,
        reads = [FS.RATIONALE, FS.PAGES, FS.DOCSTRINGS],
        description = "Checks every quantified claim member by member against the set it ranges over. Reports the member that breaks an `every`, `never`, `always` or `only` — a universal true when written and false of one case since.",
        strength = Model.Strength.FULL, cap = 6),

    Model.AgentRole(
        id = :conceptual_clarity, instrument = :documentation_review,
        reads = [FS.RATIONALE, FS.PAGES, FS.DOCSTRINGS],
        description = "Hunts identity and category confusions: an object named as its own representation, an operator as its parameter, a rate as its integral, a scalar as the field it reduces.",
        strength = Model.Strength.FULL, cap = 6),

    Model.AgentRole(
        id = :existence_auditor, instrument = :documentation_review,
        reads = [FS.DOCSTRINGS, FS.PAGES],
        description = "Asks of each public form whether it should exist at all, and whether the set of forms is complete and coherent. Reports a missing sibling as readily as a superfluous form.",
        strength = Model.Strength.FULL, cap = 6),

    Model.AgentRole(
        id = :reader_standpoint, instrument = :documentation_review,
        reads = [FS.DOCSTRINGS, FS.PAGES],
        description = "Looks for what a reader could set or read that yields a wrong number SILENTLY. Reports the argument, default or combination whose documented meaning differs from its effect with no error raised.",
        strength = Model.Strength.FULL, cap = 6),

    # ── readers with the code withheld, which is what they are for ───────────────────────────────

    Model.AgentRole(
        id = :cold_reader, instrument = :documentation_review,
        reads = [FS.PAGES], site = true, kept_from_code = true,
        description = "A competent newcomer's first top-to-bottom read of the published site, with the design documents and the source withheld. Reports every term used before it is defined, naming where the reader FIRST met it — a term glossed on a later page is still a defect at the earlier one.",
        strength = Model.Strength.ECONOMY, cap = 10),

    Model.AgentRole(
        id = :structure_consistency, instrument = :documentation_review,
        reads = [FS.DOCSTRINGS], kept_from_code = true,
        description = "Judges the uniformity of the docstrings' logical organisation with the design documents withheld. Reports a docstring ordered differently from its siblings, or carrying a section they do not.",
        strength = Model.Strength.ECONOMY, cap = 8),

    Model.AgentRole(
        id = :plain_sense, instrument = :documentation_review,
        reads = [FS.PAGES, FS.DOCSTRINGS], kept_from_code = true,
        description = "Asks of each sentence whether it means anything and whether it earns its place. Reports the sentence that survives deletion without loss, and the one whose meaning cannot be recovered from the words.",
        strength = Model.Strength.ECONOMY, cap = 8),

    # ── readers of the built site, which is what a reader actually meets ─────────────────────────

    Model.AgentRole(
        id = :style_editor, instrument = :documentation_review,
        reads = [FS.PAGES, FS.DOCSTRINGS], site = true,
        description = "Judges internal uniformity of notation, skeleton, register and rendering, and reads the rendered HTML as well as the source. Reports what renders differently from its neighbours.",
        strength = Model.Strength.ECONOMY, cap = 8),

    Model.AgentRole(
        id = :latex_typesetter, instrument = :documentation_review,
        reads = [FS.PAGES, FS.DOCSTRINGS], site = true,
        description = "Judges the typesetting itself against the house idiom, at the source line rather than in the rendered page. Reports what a reader sees that the writer did not intend.",
        strength = Model.Strength.ECONOMY, cap = 8),

    # ── readers with no checklist, which is why there are three of them ──────────────────────────
    #
    # Three standpoints, not three copies. A free reader finds what no rule names yet, and one reader's
    # blind spot is another's subject: the sceptic signing the manuscript, the engineer deciding whether
    # to adopt it, and the lecturer who must teach it next week do not miss the same things.

    Model.AgentRole(
        id = :free_reader_sceptic, instrument = :documentation_review,
        reads = [FS.RATIONALE, FS.PAGES, FS.DOCSTRINGS],
        description = "An expert reader with no checklist: a sceptical colleague asked to put their name to the manuscript. Reports whatever they would not sign, whether or not a rule names it.",
        strength = Model.Strength.FULL, cap = 6),

    Model.AgentRole(
        id = :free_reader_adopter, instrument = :documentation_review,
        reads = [FS.RATIONALE, FS.PAGES, FS.DOCSTRINGS],
        description = "An expert reader with no checklist, deciding whether to adopt the package for their own work. Reports what would stop them, and what they could not find out without reading the source.",
        strength = Model.Strength.FULL, cap = 6),

    Model.AgentRole(
        id = :free_reader_teacher, instrument = :documentation_review,
        reads = [FS.RATIONALE, FS.PAGES, FS.DOCSTRINGS],
        description = "An expert reader with no checklist, preparing to teach the package next week. Reports what they could not explain from the documentation, and the order in which it defeats a learner.",
        strength = Model.Strength.FULL, cap = 6),

    # ── the spine, and the readers that cross the whole corpus ───────────────────────────────────

    Model.AgentRole(
        id = :consistency_matrix, instrument = :documentation_review,
        reads = [FS.RATIONALE, FS.PAGES, FS.DOCSTRINGS],
        description = "The spine of the panel: builds a matrix of every recurring entity and diffs it across all pages. Reports the entity described two ways, which no reader of one page can see.",
        strength = Model.Strength.FULL, cap = 10),

    Model.AgentRole(
        id = :conjunction_coverage, instrument = :documentation_review,
        reads = [FS.DOCSTRINGS, FS.PAGES],
        description = "Crosses each caveat against the option space that can reach it. Reports the combination the documentation never addresses, and the caveat that cannot be true of every case it is attached to.",
        strength = Model.Strength.FULL, cap = 6),

    Model.AgentRole(
        id = :citations_integrity, instrument = :documentation_review,
        reads = [FS.RATIONALE, FS.PAGES],
        description = "Checks author–year citations against the references they name, and each claim against what its source actually says. Reports a citation that does not support the sentence attached to it.",
        strength = Model.Strength.ECONOMY, cap = 6),

    # `fossil_and_drift` reads GIT HISTORY, which is why it is a role of a run and could never be a rule:
    # nothing inside a consumer's build or test may read git state (§5.1).
    Model.AgentRole(
        id = :fossil_and_drift, instrument = :documentation_review,
        reads = [FS.RATIONALE, FS.PAGES, FS.DOCSTRINGS],
        description = "Finds text orphaned by a later rename or redesign, through the repository's history. Reports the sentence that was true of a thing that no longer exists under that name.",
        strength = Model.Strength.FULL, cap = 6),
]

end # module DocumentationReview
