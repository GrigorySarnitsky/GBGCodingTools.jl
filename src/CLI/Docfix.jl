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

using ..GBGCodingTools: GBGCodingTools, Catalogue, ConfigIO, Engine, Git, Model, Orchestration, Render, Texts, parse_options, VERBS
using TOML

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
function at_head(root::AbstractString, path::AbstractString)
    # EXACTLY as committed: `Git.run` strips trailing newlines, and the guard compares bytes, so every
    # file read that way looked changed at its last line (found 2026-09-23, with the byte-exact rule)
    try
        read(pipeline(`git -C $root -c core.quotePath=false show HEAD:$path`; stderr = devnull), String)
    catch
        nothing
    end
end

"""
    rulings(root; generated = Dict{String,String}(), contents = nothing)
        -> Vector{Engine.Guard.Ruling}

What the guard says about every changed file of the working tree at `root`.

# Arguments

- `root` — the package root.
- `generated` — the current output of each generated path's generator, which the caller supplies because
  the generators live above the guard.
- `contents` — each changed file's content as the caller read it, so what is classified is exactly what
  is then staged; read from disk when not given.

Returns one ruling per changed file.
"""
function rulings(root::AbstractString; generated::AbstractDict = Dict{String,String}(),
                 contents::Union{AbstractDict,Nothing} = nothing)
    cfg = ConfigIO.read_config(root)
    out = Engine.Guard.Ruling[]
    for path in changed_files(root)
        full = joinpath(root, path)
        after = contents !== nothing ? get(contents, path, nothing) : isfile(full) ? read(full, String) : nothing
        push!(out, Engine.Guard.classify(cfg, path, at_head(root, path), after;
                                         generated = get(generated, path, nothing)))
    end
    return out
end

# The changed paths that are working notes — rationale documents that are not targets of the review —
# which the fixer may not touch while a run is open. One list for `commit` and `check`, so the two agree.
function working_notes(root::AbstractString, rs)
    cfg = ConfigIO.read_config(root)
    rationale = Texts.files(cfg, root, Model.FileSet.RATIONALE)
    return [r.path for r in rs if !Catalogue.target(cfg, r.path) && r.path in rationale]
end

# The run open in this package, or `nothing`. Read from the files rather than through `CLI.Run`, which
# is a sibling verb and no verb may call another.
function open_run_id(root::AbstractString)
    dir = joinpath(root, ".gbg", "runs")
    isdir(dir) || return nothing
    for d in sort(readdir(dir); rev = true)
        isfile(joinpath(dir, d, "stage")) && !isfile(joinpath(dir, d, "run.json")) && return d
    end
    return nothing
end

"""
    generated_now(root) -> Dict{String,String}

What every generator writes in the package at `root` now, keyed by path, for the guard's clause 0: a
whole file is its generator's output, and a file holding a managed block is the file as it stands with
that block replaced, which is what `gbg sync` would leave there. The argument is `root`. Returns the map.

Without it clause 0 was unreachable from the command line, and a reworded rule statement could not be
committed with the policy files it feeds (found in review, 2026-09-26).
"""
function generated_now(root::AbstractString)
    cfg = ConfigIO.read_config(root)
    out = Dict{String,String}()
    for g in Render.GENERATED
        Render.wanted(cfg, g) || continue
        want = Render.produce(g.generator, cfg)
        if g.part === Model.Part.BLOCK
            full = joinpath(root, g.path)
            isfile(full) || continue
            text = read(full, String)
            have = Render.block_of(text)
            out[g.path] = have === nothing ? want * "\n" * text : replace(text, have => want)
        else
            out[g.path] = want
        end
    end
    return out
end

# The documentation rules as the fixer is held to them: `RULE.DOC.SHAPE`'s allowance inside a run is a
# verb's to grant, since this verb knows a run is open and a build must never know (review, 2026-09-26).
function rules_now(cfg::Model.Config, root::AbstractString)
    Catalogue.Shape.IN_RUN[] = open_run_id(root) !== nothing
    try
        return unique(id for (id, _) in Engine.Checks.run_all(cfg, root; intention = Model.Intention.DOCUMENTATION))
    finally
        Catalogue.Shape.IN_RUN[] = false
    end
end

"""
    commit(root, message; io = stdout, generated = Dict(), finding = "") -> Int

Commits every changed file of the working tree at `root` when the guard calls all of them documentation,
and commits nothing otherwise.

# Arguments

- `root` — the package root.
- `message` — the commit message.
- `io` — where the report goes.
- `generated` — the current output of each generated path's generator.
- `finding` — the id of the finding this commit fixes, written as a trailer so the run's verifiers can
  find the diff and revert it; empty outside a fix pass.

Exit 0 when it committed; 1 when a file was code, or was working notes while a run is open, and nothing
was committed; 2 when there was nothing to commit, or a run is open and no finding was named; 3 when git
failed. An unreadable config throws, which the CLI reports as exit 2. Returns the exit code.

WHILE A RUN IS OPEN THE FINDING IS REQUIRED. Everything the pass machinery does afterwards is keyed on
that trailer: the verifier reading the diff is handed the diff of the commits that name its finding, and
a fix a verifier calls worse is reverted by reverting them. A fix committed without it is invisible to
both — it is never verified, its finding stays open into the next pass, and nothing says why. That is
not a fault a message can warn about after the fact, because by then the commit exists and the trailer
cannot be added without rewriting history the run has already read.
"""
function commit(root::AbstractString, message::AbstractString; io::IO = stdout,
                generated::AbstractDict = Dict{String,String}(), finding::AbstractString = "")
    Git.is_repo(root) || (println(io, "docfix: $root is not a git working tree"); return 2)
    if isempty(finding)
        open_id = open_run_id(root)
        if open_id !== nothing
            println(io, "docfix: refused — run ", open_id, " is open and this commit names no finding.")
            println(io, "  Commit each fix with --finding <id>. The verifiers find a fix by that trailer,")
            println(io, "  so one committed without it is never verified and its finding stays open.")
            println(io, "  A change that belongs to no finding waits until the run is closed.")
            return 2
        end
    end
    # A finding id is a name, not text: one carrying a newline wrote a revert trailer into the commit,
    # after which close could never undo that fix (found in review, 2026-09-23).
    isempty(finding) || occursin(r"^[A-Za-z0-9][A-Za-z0-9._:@+-]*$", finding) ||
        (println(io, "docfix: refused — `", escape_string(finding), "` is not a finding id"); return 2)
    # A finding the open run closed, or never had, is not this pass's to fix: a commit for one was never
    # verified and left it closed over an unverified edit (review, 2026-09-23).
    if !isempty(finding)
        rid = open_run_id(root)
        if rid !== nothing
            r = Orchestration.Runs.load(root, rid)
            r === nothing || finding in [f.id for f in Orchestration.Runs.workable(r)] ||
                (println(io, "docfix: refused — ", finding, " is not a finding this pass of ", rid, " works on"); return 2)
        end
    end
    # The run's marks are the tool's to write. A message typing one — a guard or revert trailer — could
    # otherwise make the close skip a commit or hide another fix (found in review, 2026-09-23).
    occursin("GBG-Docfix", message) &&
        (println(io, "docfix: refused — the message carries a GBG-Docfix trailer, which only the tool writes"); return 2)
    # Nothing staged beforehand: the commit below commits exactly what the guard ruled on, and a refusal
    # resets exactly that, so nobody's staged work is swept in or lost.
    pre = Git.run(root, "diff", "--cached", "--name-only")
    (pre === nothing || !isempty(strip(pre))) &&
        (println(io, "docfix: refused — something is already staged; unstage it first (`git restore --staged .`)"); return 2)
    # The bytes classified are the bytes committed. Each file is read ONCE, classified from that read,
    # and after staging the index is compared with it: a file another writer changed in between is
    # refused, where before the guard read one version and `git add` staged another (found in review,
    # 2026-09-23).
    snap = Dict{String,String}()
    for p in changed_files(root)
        f = joinpath(root, p); isfile(f) && (snap[p] = read(f, String))
    end
    # An open run's own record — its stage file, its draft — sits untracked in the tree while the run
    # works, and is the session's to commit at close, not the fixer's now.
    rs = filter(r -> !Orchestration.Runs.own_record(r.path), rulings(root; generated, contents = snap))
    isempty(rs) && (println(io, "docfix: nothing has changed"); return 2)
    # While a run is open, a rationale document that is not a TARGET of the review is not the fixer's
    # either (ruled 2026-09-23): the guard rightly calls an edit to it documentation, but the run was
    # never about it, and a fix landing there is a pass spent on the package's working notes.
    if !isempty(finding)
        notes = working_notes(root, rs)
        if !isempty(notes)
            println(io, "docfix: refused — ", length(notes), " changed file(s) are working notes, not targets of the review:")
            for n in notes; println(io, "  - ", n); end
            println(io, "Nothing was committed. A finding located there is the owner's, never the fixer's.")
            return 1
        end
    end
    code = [r for r in rs if !r.documentation]
    if !isempty(code)
        println(io, "docfix: refused — ", length(code), " of ", length(rs), " changed file(s) are code:")
        for r in code; println(io, "  - ", r.path, ": ", r.reason); end
        println(io, "Nothing was committed. A code change waits for the owner's answer.")
        return 1
    end
    # A change that breaks a rule the run opened clean on is refused here, not reported and committed:
    # `check` said "broken by the change" and `commit` went ahead (found by PF, 2026-09-24). The docs
    # build is not run here; it is `check`'s, and the verify stage's.
    broke = broken_by_change(root)
    if !isempty(broke)
        println(io, "docfix: refused — the change breaks ", length(broke), " rule(s) that passed when the run opened:")
        for id in broke; println(io, "  ", id); end
        println(io, "Nothing was committed. Fix the text so that it passes, or park the finding.")
        return 1
    end
    warn_refs(root, [r.path for r in rs]; io)
    Git.run(root, "add", "--", [r.path for r in rs]...) === nothing && (println(io, "docfix: git add failed"); return 3)
    moved = String[]
    for r in rs
        haskey(snap, r.path) || continue                    # a deletion: nothing to compare
        # compared as git would store the bytes read, so a file git normalises on staging is not "moved"
        want = try readchomp(pipeline(IOBuffer(snap[r.path]), `git -C $root hash-object --path=$(r.path) --stdin`)) catch; "" end
        have = something(Git.run(root, "rev-parse", ":" * r.path), "")
        (isempty(want) || want != have) && push!(moved, r.path)
    end
    # a mode change or a symlink, which the close would call code, is refused here, not after
    raw = something(Git.run(root, "diff", "--cached", "--raw", "--no-renames", "--", [r.path for r in rs]...), "")
    for l in split(raw, '\n')
        m = match(r"^:(\d{6}) (\d{6}) \S+ \S+ \S+\t(.*)$", l)
        m === nothing && continue
        was, now = m.captures[1], m.captures[2]
        if (was != now && was != "000000" && now != "000000") || now in ("120000", "160000")
            push!(moved, String(m.captures[3]))
        end
    end
    if !isempty(moved)
        Git.run(root, "reset", "-q", "--", [r.path for r in rs]...)
        println(io, "docfix: refused — what was staged is not what was classified: ", join(moved, ", "))
        println(io, "Nothing was committed. Another writer changed it, or it is a symlink or its mode")
        println(io, "changed, which is never prose; run it again once nothing else is writing the tree.")
        return 1
    end
    # The trailer is the mark a run's close trusts: a commit carrying it passed this guard. The INDEX is
    # committed, with no pathspec: `git commit -- <path>` takes the working tree's bytes, which reopens
    # the window the comparison above just closed (found in review, 2026-09-26).
    trailers = Orchestration.Runs.GUARD_TRAILER * (isempty(finding) ? "" : "\n" * Orchestration.Runs.FINDING_TRAILER * finding)
    if Git.run(root, "commit", "-m", message * "\n\n" * trailers) === nothing
        # unstage what this call staged, or every later fix and revert refuses on it
        Git.run(root, "reset", "-q", "--", [r.path for r in rs]...)
        println(io, "docfix: git commit failed; nothing is left staged")
        return 3
    end
    println(io, "docfix: committed ", length(rs), " documentation file(s).")
    for r in rs; println(io, "  - ", r.path); end
    return 0
end

"""
    check(root; build = true, io = stdout) -> Int

Says what the guard makes of the working tree, and what the documentation rules make of it, and changes
nothing.

# Arguments

- `root` — the package root.
- `build` — whether to run the docs build too, which is where the doctests and the rendered rules are;
  `true` by default.
- `io` — where the report goes.

Exit 1 when a changed file is code, or when a documentation rule that was clean at the run's first commit
is broken now, or when the build fails; 2 when nothing has changed; 0 otherwise. The build runs only when
something has changed, since a tree nobody touched was built as it stands.

Outside a run there is no first commit to compare with, so a broken rule is reported and not counted: what
the change caused cannot be told from what it inherited, and saying so is the honest answer.

A rule already broken when the run opened is NAMED AND NOT COUNTED. The fixer is answerable for what its
edit broke; holding it to a defect it inherited would make every pass of every run red from the first,
and a signal that is always red is not read.
"""
function check(root::AbstractString; build::Bool = true, io::IO = stdout)
    # The same tree `commit` sees: the run's own record and the work queue are the session's to commit
    # at the close and are looked past here too, or the check the fixer is told to run before every
    # commit is red for every edit while a run is open (found in review, 2026-09-23).
    rs = filter(r -> !Orchestration.Runs.own_record(r.path), rulings(root; generated = generated_now(root)))
    run_open = open_run_id(root) !== nothing
    notes = run_open ? working_notes(root, rs) : String[]
    for r in rs
        println(io, "  ", r.path in notes ? "NOTE" : r.documentation ? "DOC " : "CODE", "  ", rpad(r.path, 44),
                r.path in notes ? "working notes, not a target of the open run" : r.reason)
    end
    isempty(rs) && println(io, "docfix: the working tree has no change to classify")
    warn_refs(root, [r.path for r in rs]; io)
    bad = any(r -> !r.documentation, rs) || !isempty(notes)

    cfg = ConfigIO.read_config(root)
    before = baseline(root)
    now = rules_now(cfg, root)
    if before === nothing
        # No run is open, so nothing says which of these the change caused. They are reported and not
        # counted: a verb that blamed a fixer for what it inherited would be read as noise and ignored.
        isempty(now) || println(io, "docfix: no run is open, so nothing says whether the change caused these: ",
                                join(sort(now), ", "))
    else
        broke = sort(setdiff(now, before))
        inherited = sort(intersect(now, before))
        isempty(inherited) || println(io, "docfix: already broken when the run opened, and not this fix's: ",
                                      join(inherited, ", "))
        if !isempty(broke)
            println(io, "docfix: broken by the change —")
            for id in broke; println(io, "  ", id); end
            bad = true
        end
    end

    if build && !isempty(rs)
        Orchestration.Site.build(root, cfg; io) === nothing &&
            (println(io, "docfix: the docs build does not pass"); bad = true)
    end
    return bad ? 1 : isempty(rs) ? 2 : 0
end

"""
    unresolved_refs(root, paths) -> Vector{Tuple{String,String}}

Every `@ref` in the given files whose target is found among none of the package's documented names,
the `@id`s and the headings of its pages. The arguments are `root`, the package root, and `paths`, the
files to read, relative to it. Returns `(file, target)` pairs.

A WARNING'S evidence, never a refusal's: only Documenter resolves a reference exactly, with the modules
loaded, and this reads the text alone. It exists because nine references to nothing were committed over
eighty fixes and surfaced together at the build ([GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/), 2026-09-24); a build per commit was
declined as too costly [ruled 2026-09-26].
"""
function unresolved_refs(root::AbstractString, paths::AbstractVector{<:AbstractString})
    cfg = ConfigIO.read_config(root)
    known = Set{String}()
    for fs in (Model.FileSet.DOCSTRINGS, Model.FileSet.LITERATE), f in Texts.files(cfg, root, fs)
        for d in Texts.definitions(joinpath(root, f))
            push!(known, d.name); push!(known, String(last(split(d.name, '.'))))
        end
        for m in eachmatch(r"@id\s+([^\s)\]]+)", read(joinpath(root, f), String)); push!(known, String(m.captures[1])); end
    end
    for fs in (Model.FileSet.PAGES, Model.FileSet.RATIONALE), f in Texts.files(cfg, root, fs)
        text = read(joinpath(root, f), String)
        for h in Texts.headings(joinpath(root, f)); push!(known, String(last(split(h.name, " / ")))); end
        for m in eachmatch(r"@id\s+([^\s)\]]+)", text); push!(known, String(m.captures[1])); end
    end
    # A target whose first component is a module this package does not define — `Base`, `Core`, a
    # dependency — is Documenter's to resolve with that module loaded, and never named here.
    foreign = Set(["Base", "Core", "Main"])
    for proj in (joinpath(root, "Project.toml"), joinpath(root, "docs", "Project.toml"))
        isfile(proj) || continue
        d = try TOML.parsefile(proj) catch; Dict{String,Any}() end
        union!(foreign, keys(get(d, "deps", Dict{String,Any}())))
    end
    out = Tuple{String,String}[]
    for p in paths
        full = joinpath(root, p)
        (isfile(full) && (endswith(p, ".md") || endswith(p, ".jl"))) || continue
        # the PROSE of a Julia file: a regex literal in its code once matched itself (review, 2026-09-26)
        text = endswith(p, ".jl") ? Texts.prose_text(full) : read(full, String)
        for m in eachmatch(r"\[([^\]]+)\]\(@ref(?:\s+([^)]+))?\)", text)
            target = strip(replace(String(something(m.captures[2], m.captures[1])), '`' => '"'), ['"', ' '])
            target = strip(replace(target, '"' => ""))
            target = replace(target, r"\(.*\)$" => "")            # a call form names its binding
            isempty(target) && continue
            String(first(split(target, '.'))) in foreign && continue
            bare = String(last(split(target, '.')))
            (target in known || bare in known || any(k -> endswith(k, "." * bare), known)) && continue
            push!(out, (p, target))
        end
    end
    return unique(out)
end

# Prints the references the change leaves unresolved, as a warning the build will decide.
function warn_refs(root::AbstractString, paths; io::IO = stdout)
    refs = try unresolved_refs(root, paths) catch; Tuple{String,String}[] end
    isempty(refs) && return
    println(io, "docfix: ", length(refs), " cross-reference(s) I cannot resolve — the docs build decides; if it fails, look here first:")
    for (f, t) in refs; println(io, "  ", f, ": [", t, "](@ref)"); end
end

# The documentation rules the change broke: found now and not when the open run started. Empty where no
# run is open, since nothing then says what the change caused.
function broken_by_change(root::AbstractString)
    before = baseline(root)
    before === nothing && return Symbol[]
    cfg = ConfigIO.read_config(root)
    return sort(setdiff(rules_now(cfg, root), before))
end

# What a program already found when the open run started, or `nothing` where no run is open.
function baseline(root::AbstractString)
    dir = joinpath(root, ".gbg", "runs")
    isdir(dir) || return nothing
    for d in sort(readdir(dir); rev = true)
        isfile(joinpath(dir, d, "stage")) && !isfile(joinpath(dir, d, "run.json")) || continue
        run = Orchestration.Runs.load(root, d)
        return run === nothing ? nothing : run.already_failing
    end
    return nothing
end

function cmd_docfix(args)
    o = parse_options(args; valued = ["message", "finding"])
    root = ConfigIO.require_root("docfix")
    root === nothing && return 2
    sub = isempty(o.positional) ? "" : o.positional[1]
    if sub == "check"
        return check(root; build = !("no-build" in o.flags))
    elseif sub == "commit"
        msg = get(o.values, "message", "")
        isempty(msg) && (println(stderr, "usage: gbg docfix commit --message \"…\" [--finding <id>]"); return 2)
        return commit(root, msg; generated = generated_now(root), finding = get(o.values, "finding", ""))
    end
    println(stderr, "usage: gbg docfix check [--no-build] | gbg docfix commit --message \"…\" [--finding <id>]")
    return 2
end
VERBS["docfix"] = cmd_docfix

end # module Docfix
