# The design's §4.6; the coordinates live here rather than in a docstring, which must read complete at
# the REPL.
"""
    Scope

What a run reads: everything, or only what changed since the last one like it.

`--scope full` gives every reader its whole corpus. `--scope changed` asks two questions instead. WHERE
does "since" start — the BASE, which is per reader combination, because a run launched with `bound`
readers has said nothing about what an `open` reader would find. And WHICH readers does a change reach,
which is not one answer but one per reader: an edited function body reaches the reader given the source
and not the one the code is kept from, and an edited page reaches the reader given that page and not the
twenty others launched beside it.

**A base is a commit, not a run.** It is the commit that ADDED the last finished run's record, so the
tree it names is the tree that run read. A run that stopped short says nothing about the corpus it never
finished reading, so only `DONE` is a base.

**Four things invalidate a base**, and each is a case where the last run's silence stops meaning
"clean":

- the rules moved, which the run's recorded digest of the rulebook says;
- `.gbg/config.jl` changed, because a switch, a file set or a declared discipline decides what is read
  and by whom;
- the docs build's script changed, which decides what every page is built from;
- the base is not an ancestor of HEAD, after a rebase or a reset, so a diff against it is not the
  history that happened.
An invalidated base reads `full`, which is the safe direction: the cost is a run nobody needed, and the
cost the other way is a defect nobody looked for.
"""
module Scope

using ...Model
using ...Catalogue
using ...Texts
using ...ConfigIO

using ..Runs
using ..Site

"The one file a package writes itself; a change to it can move what is read and by whom."
const CONFIG = ".gbg/config.jl"

# git is asked here the way `Runs` asks it, by process rather than through the verb layer's helper, which
# is included after this module and which nothing at this rank may reach: `stderr` to `devnull` because a
# tree that is no repository — the fixture, a temporary directory — is an ordinary case, not an error to
# print.
function git(root::AbstractString, args::AbstractString...)
    return try
        readchomp(pipeline(setenv(`git -C $root $args`; dir = root); stderr = devnull))
    catch
        nothing
    end
end

# Whether git answered yes to a question it answers by exit code alone.
function git_ok(root::AbstractString, args::AbstractString...)
    return try
        success(pipeline(setenv(`git -C $root $args`; dir = root); stderr = devnull))
    catch
        false
    end
end

"""
    base(root, instrument, readers, cfg) -> Union{Tuple{String,String},Nothing}

The commit a `changed` run measures from, with the run that earned it. The arguments are:

- `root` — the package root.
- `instrument` — the instrument about to run.
- `readers` — the reader combination it will launch, which the base is per.
- `cfg` — the package's config, read for the tool version the pin names.

Returns the commit and the run's id, or `nothing` where there is no base and the run must read `full`.
"""
function base(root::AbstractString, instrument::Symbol, readers::Symbol, cfg::Model.Config)
    dir = joinpath(root, ".gbg", "runs")
    isdir(dir) || return nothing
    for d in sort(readdir(dir); rev = true)
        isfile(joinpath(dir, d, "run.json")) || continue
        run = Runs.load(root, d)
        run === nothing && continue
        (run.instrument === instrument && run.readers === readers) || continue
        run.stop === Model.Stop.DONE || continue        # a paused or unevaluable run read no whole corpus
        commit = added_at(root, joinpath(".gbg", "runs", d, "run.json"))
        commit === nothing && return nothing            # the record is not committed: nothing to measure from
        invalid(root, run, commit, cfg) === nothing || return nothing
        return (commit, d)
    end
    return nothing
end

"""
    why_full(root, instrument, readers, cfg) -> String

Why this run reads everything, in the words a session prints. The arguments are:

- `root` — the package root.
- `instrument` — the instrument about to run.
- `readers` — the reader combination it will launch.
- `cfg` — the package's config.

Returns the reason, or `""` where a base stands and the run may read only what changed.
"""
function why_full(root::AbstractString, instrument::Symbol, readers::Symbol, cfg::Model.Config)
    dir = joinpath(root, ".gbg", "runs")
    isdir(dir) || return "no run of $instrument has closed here"
    for d in sort(readdir(dir); rev = true)
        isfile(joinpath(dir, d, "run.json")) || continue
        run = Runs.load(root, d)
        run === nothing && continue
        (run.instrument === instrument && run.readers === readers) || continue
        run.stop === Model.Stop.DONE ||
            return "the last $readers run, $d, stopped as $(lowercase(replace(String(Symbol(run.stop)), "_" => " ")))"
        commit = added_at(root, joinpath(".gbg", "runs", d, "run.json"))
        commit === nothing && return "$d's record is not committed, so there is no commit to measure from"
        why = invalid(root, run, commit, cfg)
        return why === nothing ? "" : why
    end
    return "no $readers run of $instrument has closed here"
end

# The invalidations, in the order they are cheapest to decide. Returns the reason or `nothing`.
#
# The rules are compared by what they SAY: the digest the run recorded against the rulebook running now.
# A record from before the digest compares the version that ran with the version running — the pin was
# compared before, and a run records the running version, so a development checkout never matched and
# a tool whose rules moved under an unchanged pin kept its base (found in review, 2026-09-23).
function invalid(root::AbstractString, run::Model.Run, commit::AbstractString, cfg::Model.Config)
    if !isempty(run.rulebook)
        run.rulebook == Catalogue.digest() ||
            return "the rules moved since $(run.id), so its silence was about other rules"
    else
        now = string(Runs.GBG_VERSION[])
        run.tool_version == now ||
            return "the tool moved from $(run.tool_version) to $now, so the rules are not the ones that run read"
    end
    git_ok(root, "merge-base", "--is-ancestor", commit, "HEAD") ||
        return "$(first(commit, 8)) is not an ancestor of HEAD, so a diff against it is not this history"
    isempty(changed_in(root, commit, CONFIG)) ||
        return "$CONFIG changed since $(first(commit, 8)), so what is read and by whom may have moved"
    # The build script decides which pages exist, what Literate makes of an example and how mathematics
    # renders; a change to it can move every page at once, and no page's own source says so.
    script = build_script(cfg)
    isempty(script) || isempty(changed_in(root, commit, script)) ||
        return "$script changed since $(first(commit, 8)), so what the site is built from may have moved"
    return nothing
end

# The docs build's script, as the config's command names it — the one `.jl` argument — or Documenter's
# own convention where the command names none.
function build_script(cfg::Model.Config)
    k = findfirst(a -> endswith(a, ".jl"), cfg.docs_build)
    return k === nothing ? "docs/make.jl" : replace(cfg.docs_build[k], '\\' => '/')
end

"""
    added_at(root, path) -> Union{String,Nothing}

The commit that added `path`. The arguments are `root`, the package root, and `path`, relative to it.
Returns the commit, or `nothing` where git does not know the file.
"""
function added_at(root::AbstractString, path::AbstractString)
    out = git(root, "log", "--diff-filter=A", "-n", "1", "--format=%H", "--", path)
    return out === nothing || isempty(strip(out)) ? nothing : String(strip(out))
end

"""
    changed_since(root, commit) -> Vector{String}

Every tracked file that differs between `commit` and HEAD. The arguments are `root`, the package root,
and `commit`, the base. Returns the paths, relative to the root, with separators as git writes them.
"""
function changed_since(root::AbstractString, commit::AbstractString)
    out = git(root, "diff", "--name-only", commit * "..HEAD")
    out === nothing && return String[]
    return [String(l) for l in split(strip(out), '\n') if !isempty(strip(l))]
end

# The files of `commit..HEAD` that are exactly `path`; used to decide whether the config moved.
changed_in(root::AbstractString, commit::AbstractString, path::AbstractString) =
    filter(f -> f == path, changed_since(root, commit))

"""
    added_since(root, commit) -> Vector{String}

Every tracked file that `commit..HEAD` ADDED. The arguments are `root`, the package root, and `commit`,
the base. Returns the paths. A page added since is one no reader has read, which is why it is asked for
separately from the changed ones.
"""
function added_since(root::AbstractString, commit::AbstractString)
    out = git(root, "diff", "--name-only", "--diff-filter=A", commit * "..HEAD")
    out === nothing && return String[]
    return [String(l) for l in split(strip(out), '\n') if !isempty(strip(l))]
end

"""
    sets_of(cfg, root, changed) -> Dict{Model.FileSet.T,Vector{String}}

Which file set each changed file belongs to. The arguments are:

- `cfg` — the package's config.
- `root` — the package root.
- `changed` — the paths that moved.
- `commit` — the base, or empty to skip the docstring comparison below.

Returns one entry per set that any changed file falls in.

A file falls in two sets at once — a `.jl` file under `src/` is both `DOCSTRINGS` and `CODE` — and the
two reach different readers, so the name alone is not enough. A file whose DOCSTRINGS did not move is
not a documentation change however much of it was rewritten: that is the difference between an edited
docstring, which the reader given one page must read again, and an edited function body, which it may
not see at all. The docstrings of both versions are extracted and compared, which needs `commit`, the
base; pass `""` and every source file counts as both, the safe direction.
"""
function sets_of(cfg::Model.Config, root::AbstractString, changed::AbstractVector{<:AbstractString},
                 commit::AbstractString = "")
    want = Set(replace(f, '\\' => '/') for f in changed)
    # A file the diff DELETED is in no listing of the tree, and was dropped here: the notation page gone
    # relaunched nobody, though a rule reads every other page against it (found in review, 2026-09-23).
    gone = [f for f in want if !isfile(joinpath(root, f))]
    out = Dict{Model.FileSet.T,Vector{String}}()
    for fs in instances(Model.FileSet.T)
        hits = filter(f -> replace(f, '\\' => '/') in want, Texts.files(cfg, root, fs))
        pats = get(cfg.filesets, fs, Texts.DEFAULT_PATTERNS[fs])
        append!(hits, [f for f in gone if any(p -> Texts.glob_matches(p, f), pats)])
        fs === Model.FileSet.DOCSTRINGS && !isempty(commit) &&
            (hits = filter(f -> prose_moved(root, f, commit), hits))
        # A rationale document that is not a target is read by nobody, so a change to it reaches
        # nobody: without this, appending one line to a decision log relaunched every reader whose
        # sets name rationale, to read everything but that log.
        fs === Model.FileSet.RATIONALE && (hits = filter(f -> Catalogue.target(cfg, f), hits))
        isempty(hits) || (out[fs] = hits)
    end
    return out
end

"""
    prose_moved(root, path, commit) -> Bool

Whether the docstrings of `path` differ between `commit` and the tree. The arguments are:

- `root` — the package root.
- `path` — the file, relative to the root.
- `commit` — the base to compare against.

Returns the answer, and `true` where either version cannot be read or parsed — an unreadable file is
read again rather than skipped.
"""
function prose_moved(root::AbstractString, path::AbstractString, commit::AbstractString)
    before = git(root, "show", commit * ":" * path)
    before === nothing && return true                   # added since, or not in that tree
    full = joinpath(root, path)
    isfile(full) || return true
    return prose_of(before, path) != prose_of(read(full, String), path)
end

# Every docstring of one source text, as a set, so a docstring that moved down the file is not a change.
function prose_of(src::AbstractString, filename::AbstractString)
    return try
        Set(d.text for d in Texts.docstrings_of(src; filename))
    catch
        nothing                                          # unparseable: `prose_moved` reads that as moved
    end
end

"""
    reaches(role, sets) -> Bool

Whether anything in `sets` reaches `role`. The arguments are `role`, a derived reader, and `sets`, what
[`sets_of`](@ref) returned. Returns the answer.

A change reaches a role when the set it falls in is one the role READS, or when it is code, the code is
not kept from the role, and the role is an open reader or carries a rule that needs the source. That is
why an edited function body reaches the reader with the source beside it and neither the reader given
one page alone nor the reader of the built site, without any of them being named here.
"""
function reaches(role::Model.AgentRole, sets::AbstractDict)
    for fs in role.reads
        isempty(get(sets, fs, String[])) || return true
    end
    role.kept_from_code && return false
    isempty(get(sets, Model.FileSet.CODE, String[])) && return false
    # Code reaches a bound reader only through a rule that needs the source: the reader of the built
    # site is not kept from the code, but nothing it judges can move when a function body does (found
    # in review, 2026-09-23). An open reader reads with the source beside it, and is reached.
    isempty(role.rules) && return true
    return any(role.rules) do id
        r = Catalogue.rule(id)
        r === nothing || Model.Access.SOURCE in r.access
    end
end

"""
    unit_touched(root, cfg, unit, sets, added) -> Bool

Whether the built page `unit` must be read again. The arguments are:

- `root` — the package root.
- `cfg` — the package's config, which names the copies a built page may have been made from.
- `unit` — one of [`Site.write_units`](@ref)'s pages.
- `sets` — what [`sets_of`](@ref) returned.
- `added` — the files added since the base.

Returns the answer.

Three ways a page changes. Its own source changed. Its source is NEW, so no reader has read it. Or a
docstring changed and this page collects docstrings — which is decided by reading the page's source for
an `@docs` block, the only statement in the tree of which docstrings a page gathers. A page with no
source at all is read again: it was built from something this cannot see.
"""
function unit_touched(root::AbstractString, cfg::Model.Config, unit, sets::AbstractDict,
                      added::AbstractVector{<:AbstractString})
    # With the config, so a page built from a declared copy is judged by its SOURCE — the architecture
    # document's page was never re-read under a changed scope while this resolved to the copy.
    src = Site.source_of(root, unit.path; cfg)
    isempty(src) && return true
    here = replace(src, '\\' => '/')
    here in (replace(a, '\\' => '/') for a in added) && return true
    for fs in (Model.FileSet.PAGES, Model.FileSet.RATIONALE, Model.FileSet.LITERATE)
        here in (replace(f, '\\' => '/') for f in get(sets, fs, String[])) && return true
    end
    isempty(get(sets, Model.FileSet.DOCSTRINGS, String[])) && return false
    return collects_docstrings(joinpath(root, src))
end

# Whether a page gathers docstrings, which Documenter states one way: an `@docs` block. Read from the
# SOURCE rather than the built page, because the built page shows the result and not the instruction.
function collects_docstrings(path::AbstractString)
    isfile(path) || return true
    for line in eachline(path)
        startswith(strip(line), "```@docs") && return true
        startswith(strip(line), "```@autodocs") && return true
    end
    return false
end

end # module Scope
