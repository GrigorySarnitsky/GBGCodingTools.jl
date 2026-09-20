# The design's §4.5, §5.2, §10, §12; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Runs

One execution of one instrument: the stages in order, the record on disk, and finding a location again
after the text has moved under it.

It is the seventh module of the order. **Nothing a consumer's build, test or wiring check runs may reach
it** — review state turned a science package's tests red once, and the rule that came out of that is
enforced by `test/architecture.jl` rather than remembered.

A run never searches twice, never extends its budget, never starts another run and never changes an
instrument: an instrument is code, and a run that repaired its own machinery is what rounds that patched
their own scripts taught.
"""
module Runs

using Dates, JSON3

using ...Model
using ...Catalogue
using ...Texts
using ...ConfigIO
using ...Engine

"""
    STAGES

The stages each instrument passes through, in order. A stage out of order is refused: the session
launches each one, and a session that skipped `collect` would grade findings nobody had read back.
"""
const STAGES = Dict{Symbol,Vector{Symbol}}(
    :documentation_review => [:start, :find, :collect, :pass, :close],
    :bug_hunt            => [:start, :hunt, :collect, :witnesses, :collect, :close],
    :change_audit        => [:start, :audit, :collect, :close],
)

"""
    dir(root, id) -> String

Where one run's record lives. The arguments are `root`, the package root, and `id`, the run's id.
Returns the directory, which is named by the id.
"""
dir(root::AbstractString, id::AbstractString) = joinpath(root, ".gbg", "runs", id)

"""
    new_id(instrument, root) -> String

An identifier for a new run of `instrument` in the package at `root`: the date, the instrument and the
next number that day. The arguments are `instrument`, the instrument's id, and `root`, the package root.
Returns the id.

Numbered rather than stamped with a time, so two runs of one instrument on one day sort in the order
they happened and a reader can say "the second one" without converting a clock.
"""
function new_id(instrument::Symbol, root::AbstractString)
    day = string(Dates.today())
    base = day * "-" * replace(String(instrument), "_" => "-")
    taken = isdir(joinpath(root, ".gbg", "runs")) ? readdir(joinpath(root, ".gbg", "runs")) : String[]
    n = count(d -> startswith(d, base), taken) + 1
    return base * "-" * lpad(n, 2, '0')
end

"""
    start(instrument, root; io = stdout) -> Union{Model.Run,Nothing}

Opens a run of `instrument` in the package at `root`. The arguments are:

- `instrument` — the instrument to run.
- `root` — the package root.
- `io` — where a refusal is reported.

Returns the run, or `nothing` when one may not start.

The budget is fixed HERE, from the instrument's own value, and nothing later raises it. Inside a run the
program stops the work, from this number; across runs the owner does, by asking or not.
"""
function start(instrument::Symbol, root::AbstractString; readers::Symbol = :bound, io::IO = stdout)
    readers in (:bound, :open, :both) ||
        (println(io, "run: readers is bound, open or both, not $readers"); return nothing)
    i = findfirst(x -> x.id === instrument, Catalogue.INSTRUMENTS)
    i === nothing && (println(io, "run: no instrument is called $instrument"); return nothing)
    inst = Catalogue.INSTRUMENTS[i]
    cfg = ConfigIO.read_config(root)
    Engine.Checks.applies(cfg, instrument) ||
        (println(io, "run: $instrument is switched off in this package"); return nothing)
    # An instrument with no derived readers would open, launch nobody and close clean: the bug hunt and
    # the change audit until Phase 6 derives theirs.
    isempty(first(Catalogue.panel(instrument, cfg))) &&
        (println(io, "run: $instrument has no readers yet; nothing would be launched"); return nothing)
    open = [d for d in (isdir(joinpath(root, ".gbg", "runs")) ? readdir(joinpath(root, ".gbg", "runs")) : String[])
            if isfile(joinpath(root, ".gbg", "runs", d, "stage")) && !isfile(joinpath(root, ".gbg", "runs", d, "run.json"))]
    isempty(open) || (println(io, "run: ", first(open), " is still open; a run never starts another"); return nothing)
    run = Model.Run(id = new_id(instrument, root), instrument = instrument,
                    tool_version = string(GBG_VERSION[]), first_commit = head_commit(root),
                    budget = inst.budget, stage = :start, readers = readers)
    mkpath(dir(root, run.id))
    save(root, run)
    write_stage(root, run.id, 1)                # after the record, which the stage file is read against
    return run
end

# The version that ran, recorded so a record says what judged it. Set by the package at load.
const GBG_VERSION = Ref{Any}("dev")

"""
    head_commit(root) -> String

The commit the package is at, or `"unknown"` where git cannot say. The argument is `root`, the package
root. Returns the hash.

A run records where it started so its close can classify every commit made since — which is how a code
change slipped in outside the guard is found rather than assumed absent.
"""
function head_commit(root::AbstractString)
    # `stderr` to `devnull`: a package that is not a git repository is an ordinary case — the fixture,
    # a temporary tree — and git prints "fatal: not a git repository" to the terminal on its way to the
    # `catch` below. A handled condition that still prints is a verb telling a reader something failed
    # when nothing did.
    out = try
        readchomp(pipeline(setenv(`git -C $root rev-parse HEAD`; dir = root); stderr = devnull))
    catch
        return "unknown"
    end
    return out
end

"""
    stage_of(root, id) -> Symbol

The stage a run has reached. The arguments are `root`, the package root, and `id`, the run's id. Returns
the stage, or `:none` where there is no such run.
"""
function stage_of(root::AbstractString, id::AbstractString)
    path = joinpath(dir(root, id), "stage")
    isfile(path) || return :none
    return Symbol(last(split(strip(read(path, String)))))
end

"""
    stage_index(root, id) -> Int

Where in its instrument's stage list a run stands. The arguments are `root`, the package root, and `id`,
the run's id. Returns the position, or 0 where there is no such run.

The position is kept beside the name because a name is not unique: the bug hunt's list holds `collect`
twice, and a machine that found its place by name went from the second `collect` back to `witnesses`
for ever. A stage file written before this carried the name alone and is read as the first stage of
that name.
"""
function stage_index(root::AbstractString, id::AbstractString)
    path = joinpath(dir(root, id), "stage")
    isfile(path) || return 0
    parts = split(strip(read(path, String)))
    length(parts) == 2 && return parse(Int, parts[1])
    run = load(root, id)
    run === nothing && return 0
    at = findfirst(==(Symbol(parts[end])), get(STAGES, run.instrument, Symbol[]))
    return at === nothing ? 0 : at
end

# The stage file: the position and the name, so a repeated name is still one place.
write_stage(root::AbstractString, id::AbstractString, at::Int) =
    (run = load(root, id); write(joinpath(dir(root, id), "stage"), string(at, " ", String(get(STAGES, run.instrument, Symbol[])[at]))))

"""
    advance!(root, id, to; io = stdout) -> Bool

Moves a run to its next stage, and refuses any other. The arguments are:

- `root` — the package root.
- `id` — the run's id.
- `to` — the stage being asked for.
- `io` — where a refusal is reported.

Returns whether the run moved.

The ORDER is the point. The session launches each stage itself, so nothing but this stops a session
from grading findings that were never collected, or closing a run whose passes never ran; a stage out of
order is exit 2 in the verb above, never a warning.
"""
function advance!(root::AbstractString, id::AbstractString, to::Symbol; io::IO = stdout)
    run = load(root, id)
    run === nothing && (println(io, "run: no run is called $id"); return false)
    order = get(STAGES, run.instrument, Symbol[])
    at = stage_index(root, id)
    at == 0 && (println(io, "run: $id is at $(stage_of(root, id)), which is not a stage of $(run.instrument)"); return false)
    here = order[at]
    # A stage may repeat where the instrument repeats it — a documentation review's passes, a bug hunt's
    # second collect — and may never go backwards or skip one. The candidates are POSITIONS: a pass
    # repeats in place, a second collect is the next position, and `close` is reached by position too.
    candidates = Int[]
    at + 1 <= length(order) && push!(candidates, at + 1)
    here === :pass && push!(candidates, at)
    hit = findfirst(c -> order[c] === to, candidates)
    hit === nothing && (println(io, "run: $id is at $here; the next stage is ",
                                join(sort(unique(String.(order[candidates]))), " or "), ", not $to"); return false)
    write_stage(root, id, candidates[hit])
    return true
end

# ────────────────────────────────────────────────────────────────── the record on disk

"""
    save(root, run) -> String

Writes a run's record. The arguments are `root`, the package root, and `run`, the run. Returns the path.

The record is JSON: a verb writes it, nothing hand-edits it, and it is read back by this module alone.
That is the opposite of `config.jl`, which a person writes and a parser refuses to evaluate.
"""
function save(root::AbstractString, run::Model.Run)
    path = joinpath(dir(root, run.id), "run.draft.json")
    mkpath(dirname(path))
    open(path, "w") do f; JSON3.pretty(f, JSON3.write(as_dict(run))); end
    return path
end

"""
    load(root, id) -> Union{Model.Run,Nothing}

Reads a run's record back. The arguments are `root`, the package root, and `id`, the run's id. Returns
the run, or `nothing` where there is none.

The language rules are NOT re-applied to the questions in it. A question was written under whatever
rules stood when it was put, and judging an old record by today's would fail to load it.
"""
function load(root::AbstractString, id::AbstractString)
    for name in ("run.json", "run.draft.json")
        path = joinpath(dir(root, id), name)
        isfile(path) || continue
        return from_dict(JSON3.read(read(path, String), Dict{String,Any}))
    end
    return nothing
end

as_dict(r::Model.Run) = Dict{String,Any}(
    "id" => r.id, "instrument" => String(r.instrument), "tool_version" => r.tool_version,
    "first_commit" => r.first_commit, "stage" => String(r.stage),
    "budget" => Dict("fix_passes" => r.budget.fix_passes),
    "agent_launches" => r.agent_launches, "tokens" => r.tokens, "stop" => String(Symbol(r.stop)),
    "readers" => String(r.readers),
    "questions" => [question_dict(q) for q in r.questions],
    "findings" => [Dict{String,Any}("id" => f.id, "source" => String(f.source),
                                    "decider" => String(Symbol(f.decider)),
                                    "claim" => f.draft.claim, "evidence" => f.draft.evidence,
                                    "fix" => f.draft.fix, "maybe_code" => f.draft.maybe_code,
                                    "rule" => f.draft.rule === nothing ? nothing : String(f.draft.rule),
                                    "locations" => [loc_dict(l) for l in f.draft.locations]) for f in r.findings])

loc_dict(l::Model.Location) = Dict{String,Any}("file" => l.file, "node" => l.node, "text" => l.text,
                                               "line" => l.line, "found" => String(Symbol(l.found)))

loc_of(d) = Model.Location(; file = get(d, "file", ""), node = get(d, "node", ""),
                            text = get(d, "text", ""), line = get(d, "line", 0),
                            found = getfield(Model.Anchor, Symbol(get(d, "found", "FRESH"))))

question_dict(q::Model.Question) = Dict{String,Any}(
    "id" => q.id, "decision" => q.decision, "context" => q.context, "exhibit" => q.exhibit,
    "answer" => q.answer, "direction" => q.direction,
    "options" => [Dict{String,Any}("label" => o.label, "consequence" => o.consequence, "recommended" => o.recommended)
                  for o in q.options],
    "items" => [Dict{String,Any}("text" => i.text, "recommended" => i.recommended, "sources" => i.sources,
                                 "answer" => i.answer, "direction" => i.direction) for i in q.items])

question_of(d::AbstractDict) = Model.Question(
    id = d["id"], decision = get(d, "decision", ""), context = get(d, "context", ""),
    exhibit = get(d, "exhibit", ""), answer = get(d, "answer", nothing), direction = get(d, "direction", ""),
    options = [Model.Option(o["label"], get(o, "consequence", ""), get(o, "recommended", false))
               for o in get(d, "options", [])],
    items = [Model.Item(text = i["text"], recommended = get(i, "recommended", ""),
                        sources = String[String(x) for x in get(i, "sources", [])],
                        answer = get(i, "answer", nothing), direction = get(i, "direction", ""))
             for i in get(d, "items", [])])

function from_dict(d::AbstractDict)
    b = get(d, "budget", Dict("fix_passes" => 0))
    findings = Model.Finding[]
    for f in get(d, "findings", [])
        draft = Model.FindingDraft(
            rule = get(f, "rule", nothing) === nothing ? nothing : Symbol(f["rule"]),
            locations = [loc_of(l) for l in get(f, "locations", [])],
            claim = get(f, "claim", ""), evidence = get(f, "evidence", ""),
            fix = get(f, "fix", ""), maybe_code = get(f, "maybe_code", false))
        push!(findings, Model.Finding(get(f, "id", ""), Symbol(get(f, "source", "")),
                                      getfield(Model.Decider, Symbol(get(f, "decider", "PROGRAM"))), draft))
    end
    return Model.Run(id = d["id"], instrument = Symbol(d["instrument"]),
                     tool_version = get(d, "tool_version", ""), first_commit = get(d, "first_commit", ""),
                     budget = Model.Budget(fix_passes = get(b, "fix_passes", 4)),
                     stage = Symbol(get(d, "stage", "start")), findings = findings,
                     questions = [question_of(q) for q in get(d, "questions", [])],
                     agent_launches = get(d, "agent_launches", 0), tokens = get(d, "tokens", nothing),
                     stop = getfield(Model.Stop, Symbol(get(d, "stop", "DONE"))),
                     readers = Symbol(get(d, "readers", "bound")))
end


"""
    unguarded_code(root, since) -> Vector{String}

Every commit since `since` that changed CODE without going through the change guard. The arguments are
`root`, the package root, and `since`, the commit the run started at. Returns one line per commit, each
naming it and the files that make it code.

This is the first of the two programs a run's close runs, and it is why a run records where it started.
A review that edited code behind its own guard has not been reviewed: the guard is what decides that a
change is documentation and may be committed without asking, so a code change made around it is exactly
the thing nobody looked at. The run ends `CANNOT_EVALUATE` and the owner is asked to keep or revert.

A commit `gbg docfix commit` made is recognised by the trailer it writes, not by its subject line: a
subject can be typed by anyone, and the point here is to find changes that did not pass the guard.
"""
function unguarded_code(root::AbstractString, since::AbstractString)
    (isempty(since) || since == "unknown") && return String[]
    cfg = try ConfigIO.read_config(root) catch; return String[] end
    log = try
        readchomp(pipeline(setenv(`git -C $root log --format=%H%x1f%s%x1f%b%x1e $since..HEAD`; dir = root); stderr = devnull))
    catch
        return String[]
    end
    out = String[]
    for entry in split(log, '\x1e'; keepempty = false)
        parts = split(strip(entry, ['\n']), '\x1f')
        length(parts) >= 2 || continue
        sha, subject = String(parts[1]), String(parts[2])
        body = length(parts) >= 3 ? String(parts[3]) : ""
        occursin(GUARD_TRAILER, body) && continue          # it passed the guard
        code = String[]
        for f in changed_files(root, sha)
            own_record(f) && continue
            at(rev) = try
                readchomp(pipeline(setenv(`git -C $root show $rev:$f`; dir = root); stderr = devnull))
            catch
                ""
            end
            # `Guard.classify`, not `on_documentation_list`. The list says only where documentation MAY
            # live; whether one change IS documentation is what the guard decides, by reading both
            # versions. Asking the list instead called every edit to a `.jl` file documentation — which
            # is the one answer this program exists to refuse.
            Engine.Guard.classify(cfg, f, at(sha * "^"), at(sha)).documentation || push!(code, f)
        end
        isempty(code) && continue
        push!(out, first(sha, 8) * "  " * subject * "  [" * join(first(code, 4), ", ") *
                   (length(code) > 4 ? ", …" : "") * "]")
    end
    return out
end

"""
    changed_files(root, sha) -> Vector{String}

The files one commit touched. The arguments are `root`, the package root, and `sha`, the commit. Returns
the paths, empty where git cannot say.
"""
function changed_files(root::AbstractString, sha::AbstractString)
    out = try
        readchomp(pipeline(setenv(`git -C $root show --name-only --format= $sha`; dir = root); stderr = devnull))
    catch
        return String[]
    end
    return [String(f) for f in split(out, '\n') if !isempty(f)]
end

"""
    own_record(path) -> Bool

Whether a path is a run's OWN record rather than the package's work. The argument is `path`. Returns
whether close should look past it.

A session commits what a run wrote — that is the design — so a run's record, its arguments and its
results appear in the history between its first commit and its close. Counted as code they would end
every run `CANNOT_EVALUATE` on its own artefacts, which is a check that fires on itself and on nothing
else. The package's own `.gbg/config.jl` is NOT excluded: that is the owner's file, and a change to it
during a run is exactly the kind of thing worth asking about.
"""
own_record(path::AbstractString) =
    startswith(path, ".gbg/runs/") || startswith(path, ".gbg/scratch/") || path == ".gbg/questions.json"

"""
    GUARD_TRAILER

The line `gbg docfix commit` writes into a commit it made, and the only mark a close trusts. A subject
line can be typed by anyone; what is being looked for is a change that did not pass the guard at all.
"""
const GUARD_TRAILER = "GBG-Docfix: guarded"

# ──────────────────────────────────────────────────────────── finding a location again

"""
    reanchor(root, loc) -> Model.Location

Where a finding's location is now. The arguments are `root`, the package root, and `loc`, the location
made earlier. Returns the located copy, carrying how it was found.

`Texts.reanchor` is tried first: the node, then the quote, neither of which needs anything but the file.
Where both fail, the old LINE is mapped through `git` across the changes since — `BY_DIFF`. The git step
lives here and not in `Texts` because nothing a consumer's build or test runs may read git state, and
`Texts` is reached from both.

If all three fail the location is `OUTDATED` and is never pointed at whatever now sits on that line: the
report names it, the fixer is not sent there, and a verifier that needs it is given the changed regions.
"""
function reanchor(root::AbstractString, loc::Model.Location; since::AbstractString = "")
    found = Texts.reanchor(root, loc)
    found.found === Model.Anchor.OUTDATED || return found
    isempty(since) && return found
    # A file that is GONE is outdated whatever git says. `git diff` over a path that no longer exists
    # prints nothing, and an empty patch otherwise means "nothing moved" — so without this the deleted
    # file came back `BY_DIFF` at its original line, which is the one answer the design forbids.
    isfile(joinpath(root, loc.file)) || return found
    line = mapped_line(root, loc, since)
    line === nothing && return found
    return Model.Location(; file = loc.file, node = Texts.node_at(root, loc.file, line), text = loc.text,
                           line = line, found = Model.Anchor.BY_DIFF)
end

"""
    mapped_line(root, loc, since) -> Union{Int,Nothing}

The line a location's old line became, read out of git's own diff. The arguments are:

- `root` — the package root.
- `loc` — the location, whose `line` is the one being mapped.
- `since` — the commit the finding was made at.

Returns the new line, or `nothing` where the diff does not say.

The hunk headers are what is read, not the patch text: each says where a span began and how far it
moved, which is enough to carry a line across edits above it without reading content at all.

A line INSIDE a changed span maps to where that span now begins. This is the case `BY_DIFF` exists for
and it would otherwise be unreachable: it is tried only after the node and the quote have both failed,
and both fail precisely when the text there was rewritten — so a mapping that gave up on a rewritten
span would fire only where the quote had already succeeded. Pointing at the start of the region that
replaced it is a different claim from pointing at whatever now sits on the old line NUMBER, which the
design forbids and which is what an unmapped line would be.
"""
function mapped_line(root::AbstractString, loc::Model.Location, since::AbstractString)
    patch = try
        readchomp(setenv(`git -C $root diff -U0 $since -- $(loc.file)`; dir = root))
    catch
        return nothing
    end
    isempty(patch) && return loc.line
    offset = 0
    for m in eachmatch(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"m, patch)
        old_start = parse(Int, m.captures[1])
        old_len = m.captures[2] === nothing ? 1 : parse(Int, m.captures[2])
        new_start = parse(Int, m.captures[3])
        new_len = m.captures[4] === nothing ? 1 : parse(Int, m.captures[4])
        old_start > loc.line && break                       # the hunk is below the line; it cannot move it
        if old_len > 0 && old_start <= loc.line < old_start + old_len
            new_len == 0 && return nothing                  # the span was deleted outright
            return new_start
        end
        offset += new_len - old_len
    end
    line = loc.line + offset
    return line >= 1 ? line : nothing
end

end # module Runs
