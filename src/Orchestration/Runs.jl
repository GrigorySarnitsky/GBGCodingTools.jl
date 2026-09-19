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
function start(instrument::Symbol, root::AbstractString; io::IO = stdout)
    i = findfirst(x -> x.id === instrument, Catalogue.INSTRUMENTS)
    i === nothing && (println(io, "run: no instrument is called $instrument"); return nothing)
    inst = Catalogue.INSTRUMENTS[i]
    cfg = ConfigIO.read_config(root)
    Engine.Checks.applies(cfg, instrument) ||
        (println(io, "run: $instrument is switched off in this package"); return nothing)
    open = [d for d in (isdir(joinpath(root, ".gbg", "runs")) ? readdir(joinpath(root, ".gbg", "runs")) : String[])
            if isfile(joinpath(root, ".gbg", "runs", d, "stage")) && !isfile(joinpath(root, ".gbg", "runs", d, "run.json"))]
    isempty(open) || (println(io, "run: ", first(open), " is still open; a run never starts another"); return nothing)
    run = Model.Run(id = new_id(instrument, root), instrument = instrument,
                    tool_version = string(GBG_VERSION[]), first_commit = head_commit(root),
                    budget = inst.budget, stage = :start)
    mkpath(dir(root, run.id))
    write(joinpath(dir(root, run.id), "stage"), "start")
    save(root, run)
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
    out = try
        readchomp(setenv(`git -C $root rev-parse HEAD`; dir = root))
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
    return Symbol(strip(read(path, String)))
end

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
    here = stage_of(root, id)
    at = findfirst(==(here), order)
    at === nothing && (println(io, "run: $id is at $here, which is not a stage of $(run.instrument)"); return false)
    # A stage may repeat where the instrument repeats it — a documentation review's passes, a bug hunt's
    # second collect — and may never go backwards or skip one.
    nexts = Set{Symbol}([order[min(at + 1, length(order))]])
    order[at] === :pass && push!(nexts, :pass)
    order[at] === :collect && at + 1 <= length(order) && push!(nexts, order[at])
    to in nexts || (println(io, "run: $id is at $here; the next stage is ", join(sort(collect(nexts)), " or "),
                            ", not $to"); return false)
    write(joinpath(dir(root, id), "stage"), String(to))
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
    "budget" => Dict("fix_passes" => r.budget.fix_passes, "agent_launches" => r.budget.agent_launches),
    "agent_launches" => r.agent_launches, "tokens" => r.tokens, "stop" => String(Symbol(r.stop)),
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

function from_dict(d::AbstractDict)
    b = get(d, "budget", Dict("fix_passes" => 0, "agent_launches" => 0))
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
                     budget = Model.Budget(fix_passes = b["fix_passes"], agent_launches = b["agent_launches"]),
                     stage = Symbol(get(d, "stage", "start")), findings = findings,
                     agent_launches = get(d, "agent_launches", 0), tokens = get(d, "tokens", nothing),
                     stop = getfield(Model.Stop, Symbol(get(d, "stop", "DONE"))))
end

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
