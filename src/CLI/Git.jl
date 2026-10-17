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

`git -C root args...` with stderr discarded; the stdout with trailing whitespace removed, or `nothing`
on a non-zero exit or when git is absent.

Trailing only, never leading. `git status --porcelain` puts the status in the first two columns, so an
unstaged modification begins with a space (`" M path"`), and a full `strip` deleted it — from the first
line alone, since only that line touches the start of the output. [`Git.porcelain`](@ref) then read the
code as `"M "` and the path from column 4 as `gbg/exemptions.toml`, one character short, matching no
watched path.

So `CFG.TORN` called a modified pinned file unmodified whenever that file sorted first, and sort order is
what hid it: with any other file ahead of it the pinned one kept its space and the guard fired normally
(2026-09-12-check-docs-01, work queue). `--stat` output is indented the same way and was losing its first
line's alignment for the same reason.
"""
function run(root::AbstractString, args...)
    argv = String[string(a) for a in args]
    try
        # addenv, never setenv: setenv would drop HOME and the user's identity, and an annotated tag
        # needs both (found when `gbg release` could not tag)
        return String(rstrip(read(pipeline(addenv(`git -C $root $argv`, "LC_ALL" => "C"); stderr = devnull), String)))
    catch
        return nothing
    end
end

"""
    Git.said(root, args...) -> (ok, said)

`git -C root args...` for a command that writes — a tag, a push — where a failure must be reported with
git's own reason. The arguments are `root`, the repository, and `args`, git's arguments. Returns whether
it succeeded and what it printed, stdout and stderr together; a missing identity or a remote refusing a
push was a line with no cause while [`Git.run`](@ref) discarded stderr (found in review, 2026-09-26).
"""
function said(root::AbstractString, args...)
    argv = String[string(a) for a in args]
    out = IOBuffer()
    ok = try
        success(pipeline(addenv(`git -C $root $argv`, "LC_ALL" => "C"); stdout = out, stderr = out))
    catch err
        print(out, sprint(showerror, err)); false
    end
    return ok, String(rstrip(String(take!(out))))
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

Whether one commit is an ancestor of (or equal to) another (`git merge-base --is-ancestor`).

# Arguments

- `root` — the repository the two commits are read in.
- `a` — the commit tested as the ancestor.
- `b` — the commit tested as the descendant; `a` equal to `b` counts as an ancestor.

Returns the boolean; false outside a repository.
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

`git status --porcelain` seen from a consumer, as `(status, path)` pairs with paths relative to the
consumer root.

# Arguments

- `root` — the consumer root the status is read from and the paths are made relative to.
- `untracked` — with `untracked = false` untracked files are left out.

Porcelain paths are relative to the repository top, so for a consumer nested inside a larger
repository (the fixture inside the tool's) they are translated and paths outside the consumer are
dropped — the tool's own modified files are not the fixture's. Empty outside a repository.
"""
function porcelain(root; untracked::Bool = true)
    # NUL separated, so no path is quoted: a quoted path read back as a path named a file that does not
    # exist, and every fix to a page whose name holds a space or a non-ASCII letter was refused as new
    # (found in review, 2026-09-23). Renames are off, so every entry is one path.
    out = try
        read(pipeline(addenv(`git -C $root status --porcelain -z --no-renames $(untracked ? "--untracked-files=all" : "--untracked-files=no")`,
                             "LC_ALL" => "C"); stderr = devnull), String)
    catch
        nothing
    end
    out === nothing && return Tuple{String,String}[]
    top = run(root, "rev-parse", "--show-toplevel")
    prefix = (top === nothing || realpath(top) == realpath(root)) ? "" : relpath(realpath(root), realpath(top)) * "/"
    pairs = Tuple{String,String}[]
    for l in split(out, '\0')
        length(l) < 4 && continue
        path = String(l[4:end])
        if !isempty(prefix)
            startswith(path, prefix) || continue
            path = path[length(prefix)+1:end]
        end
        push!(pairs, (String(l[1:2]), path))
    end
    return pairs
end

"""
    Git.diff(root, range, paths) -> String

The diff of a commit range restricted to a set of paths.

# Arguments

- `root` — the repository the diff is taken in.
- `range` — the commit range, `<base>..<head>`.
- `paths` — the paths the diff is restricted to.

Returns the patch text, empty outside a repository.
"""
diff(root, range, paths) = something(run(root, "diff", range, "--", paths...), "")

"""
    Git.diffstat(root, range, paths) -> String

The `--stat` summary of the diff of a commit range restricted to a set of paths.

# Arguments

- `root` — the repository the diff is taken in.
- `range` — the commit range.
- `paths` — the paths the diff is restricted to.

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

The files changed in a commit range under a set of paths (`git diff --name-only`).

# Arguments

- `root` — the repository the diff is taken in.
- `range` — the commit range.
- `paths` — the paths the listing is restricted to.

Returns the relative paths.
"""
changed_paths(root, range, paths) = String.(filter(!isempty, split(something(run(root, "diff", "--name-only", range, "--", paths...), ""), '\n')))

end # module Git
