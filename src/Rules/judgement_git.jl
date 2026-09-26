# The design's §7; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.JudgementGit

The `RULE.GIT.*` rules, split three ways (ruled 2026-09-22). Three are decided from the FILES and run
in every test suite: the workflow triggers, the ignore file, a request's name and opening.

Three ask about commits and branches — what no build or test may read, since a fresh clone and CI
must answer alike — and are programs in the end-of-turn hook, each carrying the shell lines the hook
runs. A hook check is weaker than a build check, because a hook can be skipped and a failing test
cannot; the rulebook says so beside each. One stays an instruction: what counts as a shim is judgement.
"""
module JudgementGit

using ...Model
using ...Texts

# ─────────────────────────────────────────────────────────────── the three the files decide

# The lines of a workflow's `on:` mapping: from the key to the next top-level key. An inline form
# (`on: [push, pull_request]`) is that one line.
function trigger_block(lines)
    i = findfirst(l -> occursin(r"^on:", l), lines)
    i === nothing && return 0, String[]
    j = findnext(l -> occursin(r"^[A-Za-z_-]+:", l), lines, i + 1)
    return i, lines[i:(j === nothing ? end : j - 1)]
end

"""
    ci_manual(root, cfg) -> Vector{Model.Location}

`RULE.GIT.CI_MANUAL` over `.github/workflows/`: a workflow that runs the tests (it names
`julia-runtest`, `Pkg.test()` or `runtests.jl`) fires on `workflow_dispatch` and release tags alone —
no branch push, no pull request, no schedule; a workflow that builds the documentation and runs no
tests fires on a branch push. The arguments are `root`, the package, and `cfg`, its config. Returns
one location per workflow, at its `on:` line.
"""
function ci_manual(root::AbstractString, cfg::Model.Config)
    out = Model.Location[]
    dir = joinpath(root, ".github", "workflows")
    isdir(dir) || return out
    for f in sort(readdir(dir))
        endswith(f, ".yml") || endswith(f, ".yaml") || continue
        rel = joinpath(".github", "workflows", f)
        lines = split(read(joinpath(dir, f), String), '\n')
        text = join(lines, '\n')
        i, on = trigger_block(lines)
        i == 0 && continue
        block = join(on, '\n')
        if occursin(r"julia-runtest|Pkg\.test\(\)|runtests\.jl", text)
            wrong = occursin(r"pull_request|schedule|branches", block) ? "a branch push, a pull request or a schedule" :
                    occursin(r"\bpush\b", block) && !occursin("tags", block) ? "every push" : ""
            isempty(wrong) || push!(out, Model.Location(; file = rel, line = i,
                text = "the test workflow runs on $wrong; CI is manual-only, `workflow_dispatch` and release tags"))
        elseif occursin(r"docs/make\.jl|julia-docdeploy", text)
            occursin(r"\bpush\b", block) && occursin("branches", block) ||
                push!(out, Model.Location(; file = rel, line = i,
                    text = "the docs workflow does not run on a branch push; docs deploy on push"))
        end
    end
    return out
end

const CI_MANUAL = Model.Rule(
    id = Symbol("RULE.GIT.CI_MANUAL"),
    statement = "CI is manual-only, `workflow_dispatch` and release tags; the matrix runs locally before a commit; docs deploy on push.",
    why = "Before committing a code change, run the gate locally; a documentation-only change needs a load and the docs build. The docs build is therefore the per-push enforcement point, and the rules that read the built site run inside it.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.FILE_TREE, ci_manual, false),
    examples = [
        Model.TreeExample([".github/workflows/CI.yml" => "name: CI\n\non:\n  push:\n    branches: [master]\n\njobs:\n  test:\n    steps:\n      - uses: julia-actions/julia-runtest@v1\n"],
                          [Model.Location(; file = ".github/workflows/CI.yml", line = 3)], "CI is manual-only"),
        Model.TreeExample([".github/workflows/CI.yml" => "name: CI\n\non:\n  workflow_dispatch:\n  push:\n    tags: '*'\n\njobs:\n  test:\n    steps:\n      - uses: julia-actions/julia-runtest@v1\n"],
                          Model.Location[], "CI is manual-only"),
        Model.TreeExample([".github/workflows/CI.yml" => "name: CI\n\non: [push, pull_request]\n\njobs:\n  test:\n    steps:\n      - run: julia --project -e 'using Pkg; Pkg.test()'\n"],
                          [Model.Location(; file = ".github/workflows/CI.yml", line = 3)], "CI is manual-only"),
        Model.TreeExample([".github/workflows/docs.yml" => "name: Docs\n\non:\n  workflow_dispatch:\n\njobs:\n  build:\n    steps:\n      - run: julia --project=docs docs/make.jl\n"],
                          [Model.Location(; file = ".github/workflows/docs.yml", line = 3)], "docs deploy on push"),
        Model.TreeExample([".github/workflows/docs.yml" => "name: Docs\n\non:\n  push:\n    branches:\n      - master\n  workflow_dispatch:\n\njobs:\n  build:\n    steps:\n      - run: julia --project=docs docs/make.jl\n"],
                          Model.Location[], "docs deploy on push"),
    ])

"""
    manifest_tracked(root, cfg) -> Vector{Model.Location}

`RULE.GIT.MANIFEST_TRACKED` over the ignore file: every sub-environment — a directory at most two deep
holding a `Project.toml` — has its `Manifest.toml` ignored, and a `Manifest.toml` at the root that is
not ignored is reported against that file, which a switch naming it declares. The arguments are
`root`, the package, and `cfg`, its config. Returns the locations.
"""
function manifest_tracked(root::AbstractString, cfg::Model.Config)
    out = Model.Location[]
    skip = Texts.ignored(root)
    envs = String[]
    for d in sort(readdir(root))
        p = joinpath(root, d)
        (isdir(p) && !startswith(d, ".")) || continue
        isfile(joinpath(p, "Project.toml")) && push!(envs, d)
        for e in sort(readdir(p))
            q = joinpath(p, e)
            isdir(q) && !startswith(e, ".") && isfile(joinpath(q, "Project.toml")) && push!(envs, d * "/" * e)
        end
    end
    for env in envs
        m = env * "/Manifest.toml"
        skip(m) || push!(out, Model.Location(; file = ".gitignore", line = 0,
            text = "$m is not ignored; a sub-environment manifest is gitignored"))
    end
    isfile(joinpath(root, "Manifest.toml")) && !skip("Manifest.toml") &&
        push!(out, Model.Location(; file = "Manifest.toml", line = 0,
            text = "the root manifest is tracked; a switch naming this file declares the deviation"))
    return out
end

const MANIFEST_TRACKED = Model.Rule(
    id = Symbol("RULE.GIT.MANIFEST_TRACKED"),
    statement = "Sub-environment manifests are gitignored; a tracked root manifest is a declared deviation, a switch naming the file.",
    why = "A stale sub-environment manifest is resolved locally when precompilation breaks; CI resolves its own.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.FILE_TREE, manifest_tracked, false),
    examples = [
        Model.TreeExample([".gitignore" => "docs/Manifest.toml\n", "docs/Project.toml" => "[deps]\n", "test/Project.toml" => "[deps]\n"],
                          [Model.Location(; file = ".gitignore", line = 0)], "sub-environment manifests are gitignored"),
        Model.TreeExample([".gitignore" => "Manifest.toml\n", "docs/Project.toml" => "[deps]\n", "test/Project.toml" => "[deps]\n"],
                          Model.Location[], "sub-environment manifests are gitignored"),
        Model.TreeExample([".gitignore" => "docs/Manifest.toml\n", "Manifest.toml" => "# v2\n", "docs/Project.toml" => "[deps]\n"],
                          [Model.Location(; file = "Manifest.toml", line = 0)], "a tracked root manifest is declared"),
        Model.TreeExample([".gitignore" => "docs/Manifest.toml\n/Manifest.toml\n", "Manifest.toml" => "# v2\n", "docs/Project.toml" => "[deps]\n"],
                          Model.Location[], "a tracked root manifest is declared"),
    ])

const REQUEST_NAME = r"^to-[A-Za-z0-9]+-\d{4}-\d{2}-\d{2}-[a-z0-9]+(?:-[a-z0-9]+)*\.md$"

"""
    requests(root, cfg) -> Vector{Model.Location}

`RULE.GIT.REQUESTS` over `.gbg/requests/`: every file there is named `to-<PKG>-<date>-<topic>.md`, and
its first paragraph — after an optional heading — begins `Status:`. The arguments are `root`, the
package, and `cfg`, its config. Returns the locations.
"""
function requests(root::AbstractString, cfg::Model.Config)
    out = Model.Location[]
    dir = joinpath(root, ".gbg", "requests")
    isdir(dir) || return out
    for f in sort(readdir(dir))
        rel = joinpath(".gbg", "requests", f)
        isfile(joinpath(dir, f)) || continue
        occursin(REQUEST_NAME, f) || push!(out, Model.Location(; file = rel, line = 0,
            text = "named outside `to-<PKG>-<date>-<topic>.md`"))
        lines = split(read(joinpath(dir, f), String), '\n')
        first = findfirst(l -> !isempty(strip(l)) && !startswith(strip(l), "#"), lines)
        first === nothing || occursin(r"^\**Status\**:", strip(lines[first])) ||
            push!(out, Model.Location(; file = rel, line = first, text = "the first paragraph does not begin `Status:`"))
        first === nothing && push!(out, Model.Location(; file = rel, line = 0, text = "the request has no status paragraph"))
    end
    return out
end

const REQUESTS = Model.Rule(
    id = Symbol("RULE.GIT.REQUESTS"),
    statement = "A cross-package request is a tracked file .gbg/requests/to-<PKG>-<date>-<topic>.md in the requester, whose first paragraph begins `Status:`; a concluded request is deleted.",
    why = "The requests directory holds what is still awaiting the other package and nothing else.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.FILE_TREE, requests, false),
    examples = [
        Model.TreeExample([".gbg/requests/fourier-reader.md" => "Status: open, sent 2026-09-26.\n\nA Fourier reader.\n"],
                          [Model.Location(; file = ".gbg/requests/fourier-reader.md", line = 0)], "named to-<PKG>-<date>-<topic>.md"),
        Model.TreeExample([".gbg/requests/to-GBGCodingTools-2026-09-26-fourier-reader.md" => "Status: open, sent 2026-09-26.\n\nA Fourier reader.\n"],
                          Model.Location[], "named to-<PKG>-<date>-<topic>.md"),
        Model.TreeExample([".gbg/requests/to-GBGCodingTools-2026-09-26-fourier-reader.md" => "# A Fourier reader\n\nThe package needs a reader for its spectral pages.\n"],
                          [Model.Location(; file = ".gbg/requests/to-GBGCodingTools-2026-09-26-fourier-reader.md", line = 3)], "first paragraph begins Status:"),
        Model.TreeExample([".gbg/requests/to-GBGCodingTools-2026-09-26-fourier-reader.md" => "# A Fourier reader\n\n**Status:** open, sent 2026-09-26.\n\nThe package needs a reader for its spectral pages.\n"],
                          Model.Location[], "first paragraph begins Status:"),
    ])

# ─────────────────────────────────────────────────────────── the three the end-of-turn hook decides

# Each fragment is the body of a shell function the hook defines, run in the package root with
# `GBG_BRANCH` set; it prints one line per violation and returns 0 always. Where git or a repository is
# missing it prints nothing: the hook then has nothing to say, and says nothing.
const BRANCH_HOOK = raw"""
b=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || return 0
[ "$b" = "$GBG_BRANCH" ] || echo "on branch '$b'; the working branch is '$GBG_BRANCH'"
return 0
"""

const PUSH_HOOK = raw"""
git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 || return 0
n=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null) || return 0
[ "$n" = "0" ] || echo "$n commit(s) not pushed: commit ⇒ push"
return 0
"""

const TRAILER_HOOK = raw"""
git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 || return 0
for c in $(git rev-list '@{upstream}..HEAD' 2>/dev/null); do
  msg=$(git log -1 --format=%B "$c")
  printf '%s\n' "$msg" | grep -Eq '^Co-Authored-By: .*<noreply@anthropic\.com>' || echo "$(git log -1 --format=%h "$c") carries no Co-Authored-By trailer"
  printf '%s\n' "$msg" | grep -Fq '[skip ci]' && echo "$(git log -1 --format=%h "$c") says [skip ci]"
done
return 0
"""

"""
    hooked(fragment) -> Function

The check of a rule the end-of-turn hook decides: runs `fragment` — the hook's own shell lines for the
rule — in the package root, with `GBG_BRANCH` set to the configured branch, and reads one location per
line it prints. The argument is `fragment`, the lines. Returns `run(root, cfg)::Vector{Model.Location}`.

The hook and this check are ONE program: the hook renderer splices the same lines into the script, so what
`gbg check` reports and what the hook refuses to end a turn over cannot disagree.
"""
function hooked(fragment::AbstractString)
    return function (root::AbstractString, cfg::Model.Config)
        script = "set -u\ncd \"\$1\" || exit 0\nGBG_BRANCH=\"\$2\"\ngbg_rule() {\n" * fragment * "\n}\ngbg_rule\n"
        said = try
            read(pipeline(ignorestatus(`bash -c $script _ $root $(branch_of(cfg))`); stderr = devnull), String)
        catch
            ""                                            # no bash: nothing to say
        end
        return [Model.Location(; file = "", line = 0, text = String(strip(l)))
                for l in split(said, '\n') if !isempty(strip(l))]
    end
end

const WORKING_BRANCH = Model.Parameter(:branch, "master")

"""
    branch_of(cfg) -> String

The branch the package configured by `cfg` works on. The argument is `cfg`, the package's config.
Returns the branch name, `master` where the package has not set one.

`gbg release` refuses to tag from any other branch, and the hook reads it here rather than keeping
its own idea of the name: the rule and the two programs that enforce it cannot then disagree.
"""
function branch_of(cfg)
    name = WORKING_BRANCH.default
    for s in cfg.settings
        s.rule === Symbol("RULE.GIT.BRANCH") && s.name === :branch && s.value isa AbstractString &&
            (name = String(s.value))
    end
    return name
end

# The repositories the hook's examples are shown on, built by a script in an empty directory. Every
# commit is authored by a fixed name so the script runs the same on a machine with no git identity.
const REPO = "export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t\n" *
             "git init -q -b master && git commit -q --allow-empty -m 'first' && " *
             "git init -q --bare .origin.git && git remote add origin .origin.git && git push -q -u origin master\n"
const TRAILER = "\n\nCo-Authored-By: Claude <noreply@anthropic.com>"

const BRANCH = Model.Rule(
    id = Symbol("RULE.GIT.BRANCH"),
    statement = "The working branch is the one `branch` names, `master` unless the package sets it; a rename is the package's decision.",
    why = "A rename is a decision about the package, never bundled with a tooling adoption.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    parameters = Model.Parameter[WORKING_BRANCH],
    check = Model.ProgramCheck(Model.Input.HISTORY, hooked(BRANCH_HOOK), false),
    hook = BRANCH_HOOK,
    examples = [
        Model.HistoryExample(REPO * "git checkout -q -b feature\n", [Model.Location(; file = "", line = 0)], "the working branch"),
        Model.HistoryExample(REPO, Model.Location[], "the working branch"),
    ])

const PUSH = Model.Rule(
    id = Symbol("RULE.GIT.PUSH"),
    statement = "Commit ⇒ push, directly on the configured branch; no feature branches.",
    why = "The repository is private and synced across machines through GitHub, so work is committed on the default branch and pushed in the same step; GitHub is the cross-machine sync path and the docs site deploys on push. Stage with `git add -u` plus every new file by name, never `-A`.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.HISTORY, hooked(PUSH_HOOK), false),
    hook = PUSH_HOOK,
    examples = [
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'second$TRAILER'\n", [Model.Location(; file = "", line = 0)], "commit ⇒ push"),
        Model.HistoryExample(REPO, Model.Location[], "commit ⇒ push"),
    ])

const TRAILER_RULE = Model.Rule(
    id = Symbol("RULE.GIT.TRAILER"),
    statement = "Every commit carries a `Co-Authored-By: … <noreply@anthropic.com>` trailer; never [skip ci].",
    why = "The trailer names the session as co-author, so a commit's provenance is in the one place git never lets anyone correct it; the model in use changes often, and a version in the trailer is a fact about the day rather than about the work.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.HISTORY, hooked(TRAILER_HOOK), false),
    hook = TRAILER_HOOK,
    examples = [
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'second'\n", [Model.Location(; file = "", line = 0)], "carries the trailer"),
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'second$TRAILER'\n", Model.Location[], "carries the trailer"),
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'second [skip ci]$TRAILER'\n", [Model.Location(; file = "", line = 0)], "never [skip ci]"),
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'second, run it$TRAILER'\n", Model.Location[], "never [skip ci]"),
    ])

# ──────────────────────────────────────────────────────────────────── the one that stays an instruction

const NO_SHIMS = Model.Rule(
    id = Symbol("RULE.GIT.NO_SHIMS"),
    statement = "The API is not frozen; no backward-compatibility shims.",
    why = "Errors found later are fixed one by one; architectural soundness is judged on the full picture first.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session: what counts as a shim is judgement; followed while working, checked by nothing")

"""
    RULES

The rules of this family: three programs over the files, three programs in the end-of-turn hook, one
instruction.
"""
const RULES = Model.Rule[CI_MANUAL, MANIFEST_TRACKED, REQUESTS, BRANCH, PUSH, TRAILER_RULE, NO_SHIMS]

end # module JudgementGit
