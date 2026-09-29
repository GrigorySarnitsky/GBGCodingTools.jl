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
import TOML

# ─────────────────────────────────────────────────────────────── the three the files decide

# The lines of a workflow's `on:` mapping: from the key to the next top-level key. An inline form
# (`on: [push, pull_request]`) is that one line.
#
# The key may be quoted — YAML reads a bare `on` as a boolean, so `"on":` is common — and a comment is
# not a trigger: a commented-out `# pull_request:` was read as one.
function trigger_block(lines)
    i = findfirst(l -> occursin(r"^[\"']?on[\"']?\s*:", l), lines)
    i === nothing && return 0, String[]
    j = findnext(l -> occursin(r"^[\"']?[A-Za-z_-]+[\"']?\s*:", l), lines, i + 1)
    return i, [replace(String(l), r"(^|\s)#.*$" => "") for l in lines[i:(j === nothing ? end : j - 1)]]
end

# Whether the triggers fire on a branch push: `push` with branches, or `push` with no filter at all —
# `on: push`, `on: [push]`, or a bare `push:` key — which is every branch. A `push` filtered to tags
# alone is not a branch push.
function branch_push(block::AbstractString)
    occursin(r"\bpush\b", block) || return false
    occursin("branches", block) && return true
    m = match(r"(?m)^(\s*)push\s*:\s*$", block)
    m === nothing && return !occursin(r"\btags\b", block)      # the inline forms
    ind = length(m.captures[1])
    after = split(block[m.offset + ncodeunits(m.match):end], '\n')
    filters = String[]
    for l in after
        isempty(strip(l)) && continue
        length(match(r"^\s*", l).match) > ind || break
        push!(filters, l)
    end
    return !any(l -> occursin(r"\btags(-ignore)?\s*:", l), filters)
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
            branch_push(block) ||
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
        # A bare `push:` is every branch push; one filtered to tags is not a branch push.
        Model.TreeExample([".github/workflows/docs.yml" => "name: Docs\n\non:\n  push:\n\njobs:\n  build:\n    steps:\n      - run: julia --project=docs docs/make.jl\n"],
                          Model.Location[], "docs deploy on push"),
        Model.TreeExample([".github/workflows/docs.yml" => "name: Docs\n\non:\n  push:\n    tags: ['*']\n\njobs:\n  build:\n    steps:\n      - run: julia --project=docs docs/make.jl\n"],
                          [Model.Location(; file = ".github/workflows/docs.yml", line = 3)], "docs deploy on push"),
        # A commented-out trigger is not a trigger; a quoted key is still the key.
        Model.TreeExample([".github/workflows/CI.yml" => "name: CI\n\non:\n  workflow_dispatch:\n  # pull_request:\n  push:\n    tags: [\"*\"]\n\njobs:\n  test:\n    steps:\n      - uses: julia-actions/julia-runtest@v1\n"],
                          Model.Location[], "CI is manual-only"),
        Model.TreeExample([".github/workflows/CI.yml" => "name: CI\n\n\"on\":\n  pull_request:\n\njobs:\n  test:\n    steps:\n      - uses: julia-actions/julia-runtest@v1\n"],
                          [Model.Location(; file = ".github/workflows/CI.yml", line = 3)], "CI is manual-only"),
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

# With no upstream nothing has ever been pushed: every commit on the branch is unpushed, which is the
# rule's case rather than a reason to be silent.
const PUSH_HOOK = raw"""
git rev-parse --verify -q HEAD >/dev/null 2>&1 || return 0
if ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  n=$(git rev-list --count HEAD 2>/dev/null) || return 0
  [ "$n" = "0" ] || echo "no upstream; $n commit(s) never pushed: commit ⇒ push"
  return 0
fi
n=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null) || return 0
[ "$n" = "0" ] || echo "$n commit(s) not pushed: commit ⇒ push"
return 0
"""

const TRAILER_HOOK = raw"""
git rev-parse --verify -q HEAD >/dev/null 2>&1 || return 0
range='@{upstream}..HEAD'
git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 || range=HEAD
for c in $(git rev-list "$range" 2>/dev/null); do
  msg=$(git log -1 --format=%B "$c")
  printf '%s\n' "$msg" | grep -Fxq 'Co-Authored-By: Anthropic Claude <noreply@anthropic.com>' || echo "$(git log -1 --format=%h "$c") does not carry the trailer 'Co-Authored-By: Anthropic Claude <noreply@anthropic.com>'"
  printf '%s\n' "$msg" | grep -Eq '^Co-Authored-By: .*<noreply@anthropic\.com>' && ! printf '%s\n' "$msg" | grep -Eq '^Co-Authored-By: Anthropic Claude <noreply@anthropic\.com>$' && echo "$(git log -1 --format=%h "$c") carries a versioned Co-Authored-By trailer"
  printf '%s\n' "$msg" | grep -Eq '^Claude-Session:' && echo "$(git log -1 --format=%h "$c") carries a Claude-Session line"
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
`gbg check` reports and what the hook refuses to end a turn over cannot disagree. Where `bash` or `git`
is missing it returns one location whose text begins `cannot evaluate: `.
"""
function hooked(fragment::AbstractString)
    return function (root::AbstractString, cfg::Model.Config)
        # Without bash or git the fragment has nothing to say either way, and silence would read as
        # clean: one location saying so, which `gbg check` turns into exit 2.
        for tool in ("bash", "git")
            Sys.which(tool) === nothing &&
                return [Model.Location(; file = "", line = 0, text = "cannot evaluate: `$tool` is not on the path")]
        end
        script = "set -u\ncd \"\$1\" || exit 0\nGBG_BRANCH=\"\$2\"\ngbg_rule() {\n" * fragment * "\n}\ngbg_rule\n"
        said = try
            read(pipeline(ignorestatus(`bash -c $script _ $root $(branch_of(cfg))`); stderr = devnull), String)
        catch e
            return [Model.Location(; file = "", line = 0, text = "cannot evaluate: bash did not run ($(sprint(showerror, e)))")]
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
const TRAILER = "\n\nCo-Authored-By: Anthropic Claude <noreply@anthropic.com>"

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
        # No upstream at all is the state in which nothing has ever been pushed.
        Model.HistoryExample("export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t\n" *
                             "git init -q -b master && git commit -q --allow-empty -m 'first$TRAILER'\n",
                             [Model.Location(; file = "", line = 0)], "commit ⇒ push"),
    ])

const TRAILER_RULE = Model.Rule(
    id = Symbol("RULE.GIT.TRAILER"),
    statement = "Every commit ends with the versionless 'Co-Authored-By: Anthropic Claude <noreply@anthropic.com>' trailer, and no other Co-Authored-By or Claude-Session line; never [skip ci].",
    why = "The trailer names no model version on purpose (ruled 2026-09-08): the model in use changes often and the versions supersede each other, so a version in the trailer is a fact about the day rather than about the work, and it goes stale in the one place git never lets anyone correct it.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.HISTORY, hooked(TRAILER_HOOK), false),
    hook = TRAILER_HOOK,
    examples = [
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'second'\n", [Model.Location(; file = "", line = 0)], "carries the trailer"),
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'second$TRAILER'\n", Model.Location[], "carries the trailer"),
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'second [skip ci]$TRAILER'\n", [Model.Location(; file = "", line = 0)], "never [skip ci]"),
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'second, run it$TRAILER'\n", Model.Location[], "never [skip ci]"),
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'second\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'\n",
                             [Model.Location(; file = "", line = 0), Model.Location(; file = "", line = 0)], "no other Co-Authored-By line"),
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'third$TRAILER'\n", Model.Location[], "no other Co-Authored-By line"),
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'second$TRAILER\nClaude-Session: https://claude.ai/x'\n",
                             [Model.Location(; file = "", line = 0)], "no Claude-Session line"),
        Model.HistoryExample(REPO * "git commit -q --allow-empty -m 'second, again$TRAILER'\n", Model.Location[], "no Claude-Session line"),
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
    local_paths(root, cfg) -> Vector{Model.Location}

Every path outside the repository that a committed environment file names: a `path` source in a
`Project.toml`'s `[sources]`, or a `path` entry in a `Manifest.toml`. The arguments are `root`, the package
root, and `cfg`, its config. Returns one location per path.

The environments read are the root and every one at most two directories deep, as for
`RULE.GIT.MANIFEST_TRACKED`; a file the ignore rules hold is local and skipped, since it is never
committed. An absolute path is reported wherever it points, because it names this machine's layout; a
relative one is reported when it leads out of the repository.
"""
function local_paths(root::AbstractString, cfg::Model.Config)
    out = Model.Location[]
    skip = Texts.ignored(root)
    envs = [""]
    for d in sort(readdir(root))
        p = joinpath(root, d)
        (isdir(p) && !startswith(d, ".")) || continue
        isfile(joinpath(p, "Project.toml")) && push!(envs, d)
        for e in sort(readdir(p))
            q = joinpath(p, e)
            isdir(q) && !startswith(e, ".") && isfile(joinpath(q, "Project.toml")) && push!(envs, d * "/" * e)
        end
    end
    home = rstrip(normpath(abspath(root)), '/')
    # Absolute on ANY host: a Windows path read on Linux is not relative, nor the reverse (found in review).
    absolute(s) = isabspath(s) || startswith(s, '/') || occursin(r"^[A-Za-z]:[\\/]", s) || startswith(s, "\\\\")
    outside(env, s) = absolute(s) ||
        !startswith(rstrip(normpath(joinpath(home, env, replace(s, '\\' => '/'))), '/') * "/", home * "/")
    for env in envs, name in ("Project.toml", "Manifest.toml")
        rel = isempty(env) ? name : env * "/" * name
        file = joinpath(root, rel)
        (isfile(file) && !skip(rel)) || continue
        doc = try TOML.parsefile(file) catch; continue end
        paths = String[]
        if name == "Project.toml"
            for (_, src) in get(doc, "sources", Dict{String,Any}())
                src isa AbstractDict && haskey(src, "path") && push!(paths, String(src["path"]))
            end
        else
            for (_, entries) in get(doc, "deps", Dict{String,Any}()), e in entries
                e isa AbstractDict && haskey(e, "path") && push!(paths, String(e["path"]))
            end
        end
        lines = split(read(file, String), '\n')
        # A path's line is the one whose `path = "…"` value, read as TOML reads it, is the path: searching
        # the raw text missed an escaped path and took a comment naming it (found in review).
        value(l) = (m = match(r"^[^#]*\bpath\s*=\s*(\"(?:[^\"\\\\]|\\\\.)*\")", l); m === nothing ? nothing :
                    try TOML.parse("v = " * m.captures[1])["v"] catch; nothing end)
        for s in unique(paths)
            outside(env, s) || continue
            n = something(findfirst(l -> value(l) == s, lines), 0)
            push!(out, Model.Location(; file = rel, line = n,
                text = "names the path `$s`, outside the repository: a clone or a runner cannot resolve it"))
        end
    end
    return out
end

const LOCAL_PATH = Model.Rule(
    id = Symbol("RULE.GIT.LOCAL_PATH"),
    statement = "No committed environment file, a `Project.toml`'s `[sources]` or a `Manifest.toml`, names a path outside the repository.",
    why = "A path outside the repository exists on the machine that wrote it and nowhere else: GBGPeriodicFields committed docs and test projects whose `[sources]` named this package's Dropbox checkout, and its docs build failed on the runner while every local run passed (2026-09-18).",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.FILE_TREE, local_paths, false),
    examples = [
        Model.TreeExample(["docs/Project.toml" => "[deps]\n\n[sources]\nX = {path = \"/home/someone/X\"}\n"],
                          [Model.Location(; file = "docs/Project.toml", line = 4)], "names a path outside the repository"),
        Model.TreeExample(["docs/Project.toml" => "[deps]\n\n[sources]\nX = {path = \"..\"}\n"],
                          Model.Location[], "names a path outside the repository"),
        Model.TreeExample(["docs/Manifest.toml" => "[[deps.X]]\npath = \"../../elsewhere/X\"\nuuid = \"1\"\n", "docs/Project.toml" => "[deps]\n"],
                          [Model.Location(; file = "docs/Manifest.toml", line = 2)], "names a path outside the repository"),
        Model.TreeExample([".gitignore" => "docs/Manifest.toml\n", "docs/Manifest.toml" => "[[deps.X]]\npath = \"/home/someone/X\"\nuuid = \"1\"\n", "docs/Project.toml" => "[deps]\n"],
                          Model.Location[], "names a path outside the repository"),
        # a Windows path on any host, and the entry's line rather than a comment naming the same path
        Model.TreeExample(["docs/Project.toml" => "[deps]\n\n[sources]\nX = {path = \"C:\\\\Users\\\\me\\\\X\"}\n"],
                          [Model.Location(; file = "docs/Project.toml", line = 4)], "names a path outside the repository"),
        Model.TreeExample(["docs/Project.toml" => "# was /home/someone/X\n[deps]\n\n[sources]\nX = {path = \"/home/someone/X\"}\n"],
                          [Model.Location(; file = "docs/Project.toml", line = 5)], "names a path outside the repository"),
    ])

"""
    RULES

The rules of this family: three programs over the files, three programs in the end-of-turn hook, one
instruction.
"""
const RULES = Model.Rule[CI_MANUAL, MANIFEST_TRACKED, LOCAL_PATH, REQUESTS, BRANCH, PUSH, TRAILER_RULE, NO_SHIMS]

end # module JudgementGit
