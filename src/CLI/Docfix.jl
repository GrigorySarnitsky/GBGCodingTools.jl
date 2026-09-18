# The design's §4.3; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Docfix

`gbg docfix commit`: the one verb that commits. It classifies every changed file in the working tree with
the change guard and commits only when every one of them came back documentation; otherwise it commits
nothing and says which file stopped it.

Why a verb commits at all, when no other does: the guard must run BEFORE a commit exists. A session that
committed first and asked afterwards would already have pushed the code it was not allowed to touch.

This is the runaway-session defence, and it is useful before any fixer exists: a session doing
documentation work can commit through it and find out, from a program rather than from its own judgement,
whether what it did was documentation.
"""
module Docfix

using ..GBGCodingTools: GBGCodingTools, ConfigIO, Engine, Git, Model, parse_options, VERBS

"""
    changed_files(root) -> Vector{String}

Every file of the working tree that differs from the last commit, tracked or not, each as a path relative
to `root`. The argument is `root`, the package root. Returns the paths, sorted.
"""
changed_files(root::AbstractString) = sort!(unique(p for (_, p) in Git.porcelain(root; untracked = true)))

"""
    at_head(root, path) -> Union{String,Nothing}

The file's content at `HEAD`, or `nothing` where the commit does not hold it — a file the working tree
has added. The arguments are `root`, the package root, and `path`, the file. Returns the content.
"""
at_head(root::AbstractString, path::AbstractString) = Git.run(root, "show", "HEAD:" * path)

"""
    rulings(root; generated = Dict{String,String}()) -> Vector{Engine.Guard.Ruling}

What the guard says about every changed file of the working tree at `root`. The arguments are:

- `root` — the package root.
- `generated` — the current output of each generated path's generator, which the caller supplies because
  the generators live above the guard.

Returns one ruling per changed file.
"""
function rulings(root::AbstractString; generated::AbstractDict = Dict{String,String}())
    cfg = ConfigIO.read_config(root)
    out = Engine.Guard.Ruling[]
    for path in changed_files(root)
        full = joinpath(root, path)
        after = isfile(full) ? read(full, String) : nothing
        push!(out, Engine.Guard.classify(cfg, path, at_head(root, path), after;
                                         generated = get(generated, path, nothing)))
    end
    return out
end

"""
    commit(root, message; io = stdout, generated = Dict{String,String}()) -> Int

Commits every changed file of the working tree at `root` when the guard calls all of them documentation,
and commits nothing otherwise. The arguments are:

- `root` — the package root.
- `message` — the commit message.
- `io` — where the report goes.
- `generated` — the current output of each generated path's generator.

Exit 0 when it committed, 1 when a file was code and nothing was committed, 2 when there was nothing to
commit or the config could not be read. Returns the exit code.
"""
function commit(root::AbstractString, message::AbstractString; io::IO = stdout,
                generated::AbstractDict = Dict{String,String}())
    Git.is_repo(root) || (println(io, "docfix: $root is not a git working tree"); return 2)
    rs = rulings(root; generated)
    isempty(rs) && (println(io, "docfix: nothing has changed"); return 2)
    code = [r for r in rs if !r.documentation]
    if !isempty(code)
        println(io, "docfix: refused — ", length(code), " of ", length(rs), " changed file(s) are code:")
        for r in code; println(io, "  - ", r.path, ": ", r.reason); end
        println(io, "Nothing was committed. A code change waits for the owner's answer.")
        return 1
    end
    Git.run(root, "add", "--all", ".") === nothing && (println(io, "docfix: git add failed"); return 3)
    Git.run(root, "commit", "-m", message) === nothing && (println(io, "docfix: git commit failed"); return 3)
    println(io, "docfix: committed ", length(rs), " documentation file(s).")
    for r in rs; println(io, "  - ", r.path); end
    return 0
end

"""
    check(root; io = stdout) -> Int

Prints what the guard says about the working tree and changes nothing: the same rulings `commit` would
act on. The arguments are:

- `root` — the package root.
- `io` — where the report goes.

Exit 0 when every changed file is documentation, 1 when any is code, 2 when nothing has changed. Returns
the exit code.
"""
function check(root::AbstractString; io::IO = stdout)
    rs = rulings(root)
    isempty(rs) && (println(io, "docfix: nothing has changed"); return 2)
    for r in rs
        println(io, "  ", r.documentation ? "DOC " : "CODE", "  ", rpad(r.path, 44), r.reason)
    end
    return any(r -> !r.documentation, rs) ? 1 : 0
end

function cmd_docfix(args)
    o = parse_options(args; valued = ["message"])
    root = ConfigIO.require_root("docfix")
    root === nothing && return 2
    sub = isempty(o.positional) ? "" : o.positional[1]
    if sub == "check"
        return check(root)
    elseif sub == "commit"
        msg = get(o.values, "message", "")
        isempty(msg) && (println(stderr, "usage: gbg docfix commit --message \"…\""); return 2)
        return commit(root, msg)
    end
    println(stderr, "usage: gbg docfix check | gbg docfix commit --message \"…\"")
    return 2
end
VERBS["docfix"] = cmd_docfix

end # module Docfix
