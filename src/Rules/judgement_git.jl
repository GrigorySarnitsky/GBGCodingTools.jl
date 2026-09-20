# The design's §7; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.JudgementGit

The `RULE.GIT.*` rules that no program decides: those an agent judges, and those nothing checks at
all. Each carries its statement and the reason it exists, so a reader of the rulebook sees the same
text whether a program enforces it or a person does.

A rule with no check states why in `unchecked_reason` rather than pretending to one; a rule an agent
decides says which of the three admitted reasons a program cannot.
"""
module JudgementGit

using ...Model

const PUSH = Model.Rule(
    id = Symbol("RULE.GIT.PUSH"),
    statement = "Commit ⇒ push, directly on the configured branch; no feature branches.",
    why = "The repository is private and synced across machines through GitHub, so work is committed on the default branch and pushed in the same step; GitHub is the cross-machine sync path and the docs site deploys on push. Stage with `git add -u` plus every new file by name, never `-A`.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const TRAILER = Model.Rule(
    id = Symbol("RULE.GIT.TRAILER"),
    statement = "Every commit ends with the versionless 'Co-Authored-By: Anthropic Claude <noreply@anthropic.com>' trailer; never [skip ci].",
    why = "The trailer names no model version on purpose: the model in use changes often and the versions supersede each other, so a version in the trailer is a fact about the day rather than about the work, and it goes stale in the one place git never lets anyone correct it.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const CI_MANUAL = Model.Rule(
    id = Symbol("RULE.GIT.CI_MANUAL"),
    statement = "CI is manual-only; the matrix runs locally before a commit; docs deploy on push.",
    why = "Before committing a code change, run the gate locally; a documentation-only change needs a load and the docs build. The docs build is therefore the per-push enforcement point, and the doctor, the hard scans and the gate stay inside it.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const NO_SHIMS = Model.Rule(
    id = Symbol("RULE.GIT.NO_SHIMS"),
    statement = "The API is not frozen; no backward-compatibility shims.",
    why = "Errors found later are fixed one by one; architectural soundness is judged on the full picture first.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const BRANCH = Model.Rule(
    id = Symbol("RULE.GIT.BRANCH"),
    statement = "The working branch is git.branch (master by default; a rename is a consumer decision).",
    why = "A rename is a decision about the package, never bundled with a tooling adoption.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const MANIFEST_TRACKED = Model.Rule(
    id = Symbol("RULE.GIT.MANIFEST_TRACKED"),
    statement = "Sub-environment manifests are gitignored; a tracked root manifest is a declared deviation.",
    why = "A stale sub-environment manifest is resolved locally when precompilation breaks; CI resolves its own.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

const REQUESTS = Model.Rule(
    id = Symbol("RULE.GIT.REQUESTS"),
    statement = "A cross-package request is a tracked file .gbg/requests/to-<PKG>-<date>-<topic>.md in the requester with a status paragraph on top; a concluded request is deleted.",
    why = "The requests directory holds what is still awaiting the other package and nothing else.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: followed while working, checked by nothing")

"""
    RULES

The rules of this family that no program decides.
"""
const RULES = Model.Rule[PUSH, TRAILER, CI_MANUAL, NO_SHIMS, BRANCH, MANIFEST_TRACKED, REQUESTS]

end # module JudgementGit
