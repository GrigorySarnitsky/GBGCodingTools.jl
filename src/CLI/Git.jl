# Git.jl — the few git questions the round verbs, the gate and the doctor ask, in one place.

"""
    Git

Thin readers over a consumer's repository: [`Git.run`](@ref) returns a command's output or `nothing`,
[`Git.head`](@ref), [`Git.is_ancestor`](@ref), [`Git.porcelain`](@ref) (modified and untracked paths),
[`Git.diff`](@ref), [`Git.log`](@ref). Nothing here writes; `git add` is never called by the tool.
"""
module Git

"""
    Git.run(root, args...) -> Union{String,Nothing}

`git -C root args...` with stderr discarded; the stripped stdout, or `nothing` on a non-zero exit or
when git is absent.
"""
function run(root::AbstractString, args...)
    argv = String[string(a) for a in args]
    try
        return String(strip(read(pipeline(setenv(`git -C $root $argv`, "LC_ALL" => "C"); stderr = devnull), String)))
    catch
        return nothing
    end
end

"""
    Git.head(root) -> Union{String,Nothing}

The full sha of `HEAD`, or `nothing` outside a repository.
"""
head(root) = run(root, "rev-parse", "HEAD")

"""
    Git.is_repo(root) -> Bool
"""
is_repo(root) = run(root, "rev-parse", "--is-inside-work-tree") == "true"

"""
    Git.is_ancestor(root, a, b) -> Bool

Whether commit `a` is an ancestor of (or equal to) commit `b` in the repository at `root`
(`git merge-base --is-ancestor`). Returns the boolean; false outside a repository.
"""
function is_ancestor(root, a, b)
    try
        return success(pipeline(`git -C $root merge-base --is-ancestor $a $b`; stderr = devnull, stdout = devnull))
    catch
        return false
    end
end

"""
    Git.porcelain(root; untracked = true) -> Vector{Tuple{String,String}}

`git status --porcelain` in the repository at `root`, as `(status, path)` pairs; with `untracked =
false` untracked files are left out. Returns the pairs, relative to `root`; empty outside a repository.
"""
function porcelain(root; untracked::Bool = true)
    out = run(root, "status", "--porcelain", untracked ? "--untracked-files=all" : "--untracked-files=no")
    out === nothing && return Tuple{String,String}[]
    pairs = Tuple{String,String}[]
    for l in split(out, '\n')
        isempty(l) && continue
        push!(pairs, (String(l[1:2]), String(strip(l[4:end]))))
    end
    return pairs
end

"""
    Git.diff(root, range, paths) -> String

The diff of `range` (`<base>..<head>`) restricted to `paths`, in the repository at `root`. Returns the
patch text, empty outside a repository.
"""
diff(root, range, paths) = something(run(root, "diff", range, "--", paths...), "")

"""
    Git.diffstat(root, range, paths) -> String

The `--stat` summary of the diff of `range` restricted to `paths`, in the repository at `root`.
Returns the text.
"""
diffstat(root, range, paths) = something(run(root, "diff", "--stat", range, "--", paths...), "")

"""
    Git.log(root, range) -> String

`git log --format="%h %s" range`.
"""
log(root, range) = something(run(root, "log", "--format=%h %s", range), "")

"""
    Git.changed_paths(root, range, paths) -> Vector{String}

The files changed in `range` under `paths`, in the repository at `root` (`git diff --name-only`).
Returns the relative paths.
"""
changed_paths(root, range, paths) = String.(filter(!isempty, split(something(run(root, "diff", "--name-only", range, "--", paths...), ""), '\n')))

end # module Git
