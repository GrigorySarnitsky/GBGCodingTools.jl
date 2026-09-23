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

A documentation review's pass is `fix → verify → collect → diff → collect`: the session fixes and commits
each finding through the guard, a blind verifier per open finding answers without the diff, and for the
findings it called fixed a second verifier reads the diff. From the last `collect` the run goes back to
`fix` while findings are open and passes remain, else to `close`; from the first `collect` it goes
straight to `close` when nothing was found.
"""
const STAGES = Dict{Symbol,Vector{Symbol}}(
    :documentation_review => [:start, :find, :collect, :fix, :verify, :collect, :diff, :collect, :close],
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
- `readers` — which readers it launches: `:bound`, `:open` or `:both`.
- `model` — the careful model its readers run on, or `"session"` for the session's own.
- `sequential` — whether its agents are launched one at a time rather than together.
- `scope` — `:full`, every reader's whole corpus, or `:changed`, only what moved since `base`.
- `base` — the commit a `:changed` run measures from, empty for a full one.
- `io` — where a refusal is reported.

The base is DECIDED above this module and passed in, because deciding it reads run records through
`Scope`, which is included after this one and may reach back into it; the arrow goes one way.

Returns the run, or `nothing` when one may not start: the instrument is unknown or switched off, it has
no readers, another run is open, or a tracked file is changed and uncommitted.

The budget is fixed HERE, from the instrument's own value, and nothing later raises it. Inside a run the
program stops the work, from this number; across runs the owner does, by asking or not. What the last
closed run of the same instrument left open is CARRIED into this one, re-anchored, under its old id, so
the report says where it came from; a finding parked on a question is not, since the question stands.

A DIRTY tree is refused because close classifies every commit since the first one: an edit that was
already in the tree when the run started would be committed by the fixer under the guard's name, and a
code change would pass as documentation. Untracked files do not count — a built site, a scratch
directory — since nothing commits them unasked.
"""
function start(instrument::Symbol, root::AbstractString; readers::Symbol = :bound,
               model::AbstractString = "session", sequential::Bool = false, scope::Symbol = :full,
               base::AbstractString = "", io::IO = stdout)
    readers in (:bound, :open, :both) ||
        (println(io, "run: readers is bound, open or both, not $readers"); return nothing)
    scope in (:full, :changed) ||
        (println(io, "run: scope is full or changed, not $scope"); return nothing)
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
    dirty = changed_tracked(root)
    if !isempty(dirty)
        println(io, "run: the tree is not clean; commit or stash these first, or close cannot tell the run's changes from yours:")
        for d in dirty; println(io, "  ", d); end
        return nothing
    end
    run = Model.Run(id = new_id(instrument, root), instrument = instrument,
                    tool_version = string(GBG_VERSION[]), first_commit = head_commit(root),
                    budget = inst.budget, stage = :start, readers = readers,
                    model = model, sequential = sequential,
                    scope = scope, base = base,
                    already_failing = failing_now(cfg, root),
                    findings = carry_over(root, instrument))
    isempty(run.findings) || println(io, "run: ", length(run.findings), " finding(s) carried over from ",
                                     first(run.findings).id[1:something(findlast('-', first(run.findings).id), 1)-1])
    mkpath(dir(root, run.id))
    save(root, run)
    write_stage(root, run.id, 1)                # after the record, which the stage file is read against
    return run
end

# The version that ran, recorded so a record says what judged it. Set by the package at load.
const GBG_VERSION = Ref{Any}("dev")

"""
    failing_now(cfg, root) -> Vector{Symbol}

The documentation rules a program finds a violation of right now. The arguments are `cfg`, the package's
config, and `root`, the package root. Returns their ids, without repetition.

A run records these when it starts, so `gbg docfix check` can tell a rule the FIX broke from one that was
already broken when the run opened. Without that baseline a fixer is held to a standard the package did
not meet before it touched anything, and the honest report of a rule it did not break reads as its fault.
"""
failing_now(cfg::Model.Config, root::AbstractString) =
    unique(id for (id, _) in Engine.Checks.run_all(cfg, root; intention = Model.Intention.DOCUMENTATION))

"""
    carry_over(root, instrument) -> Vector{Model.Finding}

What the last closed run of `instrument` in the package at `root` left open and workable, each location
re-anchored on the tree as it is now. The arguments are `root`, the package root, and `instrument`.
Returns the findings, or none where no run of the instrument has closed.

Only the LAST closed run is read: an earlier one's leftovers were carried into it already, or were
dropped when the owner abandoned it, and either way are not this run's to revive.
"""
function carry_over(root::AbstractString, instrument::Symbol)
    runs = joinpath(root, ".gbg", "runs")
    isdir(runs) || return Model.Finding[]
    for d in sort(readdir(runs); rev = true)
        isfile(joinpath(runs, d, "run.json")) || continue
        prev = load(root, d)
        (prev === nothing || prev.instrument !== instrument) && continue
        # Re-anchored through `relocated`, so no field is dropped on the way; and `in_material` is
        # decided AGAIN against the config as it stands, because a record written before the ruling
        # of 2026-09-23 carries findings in the working notes with the flag unset, and carrying those
        # as workable sent the fixer to a file it may not touch, pass after pass, run after run.
        cfg = ConfigIO.read_config(root)
        out = Model.Finding[]
        for f in workable(prev)
            locs = [reanchor(root, l; since = prev.first_commit) for l in f.draft.locations]
            d = Model.relocated(f.draft, locs)
            Catalogue.in_material(cfg, locs) && (d = Model.FindingDraft(rule = d.rule, locations = d.locations,
                claim = d.claim, evidence = d.evidence, fix = d.fix, maybe_code = d.maybe_code, in_material = true))
            push!(out, Model.Finding(f.id, f.source, f.decider, d))
        end
        return out
    end
    return Model.Finding[]
end

"""
    changed_tracked(root) -> Vector{String}

The tracked files changed and not committed in the package at `root`, or none outside a repository. The
argument is `root`, the package root. Returns the paths.
"""
function changed_tracked(root::AbstractString)
    out = try
        readchomp(pipeline(setenv(`git -C $root status --porcelain --untracked-files=no`; dir = root); stderr = devnull))
    catch
        return String[]
    end
    return [String(strip(l[4:end])) for l in split(out, '\n') if length(l) > 3]
end

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
    if here === :collect
        # A collect may close the run when nothing is open, and the last collect of a pass may open the
        # next pass while passes remain.
        push!(candidates, length(order))
        fix = findfirst(==(:fix), order)
        fix !== nothing && at == length(order) - 1 && push!(candidates, fix)
    end
    hit = findfirst(c -> order[c] === to, candidates)
    hit === nothing && (println(io, "run: $id is at $here; the next stage is ",
                                join(sort(unique(String.(order[candidates]))), " or "), ", not $to"); return false)
    if to === :fix && run.passes >= run.budget.fix_passes
        println(io, "run: $id has made its ", run.budget.fix_passes, " pass(es); a further pass is refused, and what is open carries over")
        return false
    end
    if to === :close && here === :collect && at < length(order) - 1 && !isempty(workable(run)) &&
       run.passes < run.budget.fix_passes
        println(io, "run: $id has ", length(workable(run)), " finding(s) to work on; the next stage is fix, not close")
        return false
    end
    write_stage(root, id, candidates[hit])
    return true
end

"""
    closed(run, id) -> Bool

Whether the finding `id` of `run` is closed: a verifier called it not a defect, or the blind verifier
called it fixed and the diff verifier agreed. The arguments are `run` and the finding's id. Returns the
answer; a finding with no verdict yet is open.
"""
closed(run::Model.Run, id::AbstractString) = any(f -> f.finding == id &&
    (f.blind === Model.Verdict.NOT_A_DEFECT ||
     (f.blind === Model.Verdict.FIXED && f.with_diff === Model.Verdict.FIXED)), run.fixes)

"""
    open_findings(run) -> Vector{Model.Finding}

The findings of `run` still open: not closed by a verdict, and not in material. The argument is `run`.
Returns them in the run's order.

A finding in material is never open in this sense: no pass works on it, no verifier is asked about it,
it is not a leftover and is not carried into the next run. It is the owner's from the moment it is
collected, and [`in_material`](@ref) is where it is read.
"""
open_findings(run::Model.Run) = [f for f in run.findings if !closed(run, f.id) && !f.draft.in_material]

"""
    in_material(run) -> Vector{Model.Finding}

The findings of `run` located only in material: what a reader given the working notes to consult found
there. The argument is `run`. Returns them in the run's order.
"""
in_material(run::Model.Run) = [f for f in run.findings if f.draft.in_material]

"""
    parked(run, id) -> Bool

Whether the finding `id` waits on the owner: its last blind verdict was `HIDES_CODE_DEFECT`, the fix is
reverted, and a question stands. The arguments are `run` and the finding's id. Returns the answer.

A parked finding is open — it is nobody's leftover — and is worked on by no pass: the fixer is not sent
back to describe code the verifier believes wrong, and no verifier is asked about it again until the
owner has said which half is right.
"""
function parked(run::Model.Run, id::AbstractString)
    k = findlast(x -> x.finding == id, run.fixes)
    return k !== nothing && run.fixes[k].blind === Model.Verdict.HIDES_CODE_DEFECT
end

"""
    workable(run) -> Vector{Model.Finding}

The open findings a pass may work on: open and not parked. The argument is `run`. Returns them in the
run's order.
"""
workable(run::Model.Run) = [f for f in open_findings(run) if !parked(run, f.id)]

"""
    question_of(root, id) -> Union{Tuple{String,Model.Run,Model.Question},Nothing}

The run holding the question `id`, with the question. The arguments are `root`, the package root, and
`id`, the question's id. Returns the run's id, the run and the question, or `nothing` where no run here
has one.

Runs are searched newest first, open and closed alike: a question raised by a verifier is answered from
the report, and the report is read after the run has closed as often as during it.
"""
function question_of(root::AbstractString, id::AbstractString)
    d = joinpath(root, ".gbg", "runs")
    isdir(d) || return nothing
    for name in sort(readdir(d); rev = true)
        run = load(root, name)
        run === nothing && continue
        k = findfirst(q -> q.id == id, run.questions)
        k === nothing || return (name, run, run.questions[k])
    end
    return nothing
end

"""
    answer!(root, id, option; item = "", direction = "") -> Union{String,Nothing}

Records the owner's answer on a question a RUN put, or the reason it could not be. The arguments are:

- `root` — the package root.
- `id` — the question's id.
- `option` — the label he chose.
- `item` — the item it answers, empty for a question with none.
- `direction` — how he wants it done, where his answer carried that.

Returns the refusal in words, or `nothing` when the answer was recorded.

It writes back to the file the record was read from, so answering a closed run's question amends that
run's record rather than leaving a draft beside it. The refusals are [`Engine.Questions.answer!`](@ref)'s,
in the same words, because the owner types one command and should not have to know which of the two
stores his question came from.
"""
function answer!(root::AbstractString, id::AbstractString, option::AbstractString;
                 item::AbstractString = "", direction::AbstractString = "")
    found = question_of(root, id)
    found === nothing && return "no question here is called $id"
    run_id, run, q = found
    labels = [o.label for o in q.options]
    isempty(labels) || option in labels ||
        return "$option is not one of its options: " * join(labels, ", ")
    if isempty(item)
        isempty(q.items) || return "it is asked per item; name the item"
        q.answer === nothing || return "it was already answered: " * string(q.answer)
        answered = Model.Question(id = q.id, decision = q.decision, context = q.context,
                                  options = q.options, items = q.items, exhibit = q.exhibit,
                                  answer = option, direction = direction)
    else
        j = findfirst(i -> i.text == item, q.items)
        j === nothing && return "no item of $id reads: $item"
        q.items[j].answer === nothing || return "that item was already answered"
        items = copy(q.items)
        items[j] = Model.Item(text = items[j].text, recommended = items[j].recommended,
                              sources = items[j].sources, answer = option, direction = direction)
        answered = Model.Question(id = q.id, decision = q.decision, context = q.context,
                                  options = q.options, items = items, exhibit = q.exhibit,
                                  answer = q.answer, direction = q.direction)
    end
    qs = copy(run.questions)
    qs[findfirst(x -> x.id == id, qs)] = answered
    write_record(root, with_questions(run, qs))
    return nothing
end

# The record carries nineteen fields and an answer changes one of them. Rebuilt here rather than through
# the CLI's `with`, which is a verb's helper and above this module.
with_questions(r::Model.Run, qs::Vector{Model.Question}) =
    Model.Run(id = r.id, instrument = r.instrument, tool_version = r.tool_version,
              first_commit = r.first_commit, budget = r.budget, stage = r.stage,
              findings = r.findings, fixes = r.fixes, questions = qs, code_fixes = r.code_fixes,
              agent_launches = r.agent_launches, tokens = r.tokens, stop = r.stop,
              readers = r.readers, passes = r.passes, model = r.model, sequential = r.sequential,
              scope = r.scope, base = r.base, driver = r.driver, already_failing = r.already_failing,
              dropped = r.dropped)

# The record is written back where it was read: `run.json` for a closed run, the draft for an open one.
# `save` always writes the draft, and `load` prefers `run.json`, so saving a closed run's answer through
# it would write a file nothing reads.
function write_record(root::AbstractString, run::Model.Run)
    final = joinpath(dir(root, run.id), "run.json")
    isfile(final) || return save(root, run)
    open(final, "w") do f; JSON3.pretty(f, JSON3.write(as_dict(run))); end
    return final
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
    "model" => r.model, "sequential" => r.sequential,
    "already_failing" => [String(x) for x in r.already_failing],
    "agent_launches" => r.agent_launches, "tokens" => r.tokens, "stop" => String(Symbol(r.stop)),
    "readers" => String(r.readers), "passes" => r.passes,
    "scope" => String(r.scope), "base" => r.base, "driver" => r.driver, "dropped" => r.dropped,
    "questions" => [question_dict(q) for q in r.questions],
    "fixes" => [Dict{String,Any}("finding" => f.finding, "pass" => f.pass, "commit" => f.commit,
                                  "formula_edit" => f.formula_edit, "blind" => String(Symbol(f.blind)),
                                  "with_diff" => f.with_diff === nothing ? nothing : String(Symbol(f.with_diff)),
                                  "agreeing_code" => f.agreeing_code === nothing ? nothing : loc_dict(f.agreeing_code))
                for f in r.fixes],
    "findings" => [Dict{String,Any}("id" => f.id, "source" => String(f.source),
                                    "decider" => String(Symbol(f.decider)),
                                    "claim" => f.draft.claim, "evidence" => f.draft.evidence,
                                    "fix" => f.draft.fix, "maybe_code" => f.draft.maybe_code,
                                    "in_material" => f.draft.in_material,
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
            fix = get(f, "fix", ""), maybe_code = get(f, "maybe_code", false),
            in_material = get(f, "in_material", false))
        push!(findings, Model.Finding(get(f, "id", ""), Symbol(get(f, "source", "")),
                                      getfield(Model.Decider, Symbol(get(f, "decider", "PROGRAM"))), draft))
    end
    return Model.Run(id = d["id"], instrument = Symbol(d["instrument"]),
                     tool_version = get(d, "tool_version", ""), first_commit = get(d, "first_commit", ""),
                     budget = Model.Budget(fix_passes = get(b, "fix_passes", 4)),
                     stage = Symbol(get(d, "stage", "start")), findings = findings,
                     questions = [question_of(q) for q in get(d, "questions", [])],
                     fixes = [Model.DocFix(finding = f["finding"], pass = f["pass"], commit = get(f, "commit", ""),
                                           formula_edit = get(f, "formula_edit", false),
                                           blind = getfield(Model.Verdict, Symbol(f["blind"])),
                                           with_diff = get(f, "with_diff", nothing) === nothing ? nothing :
                                                       getfield(Model.Verdict, Symbol(f["with_diff"])),
                                           agreeing_code = get(f, "agreeing_code", nothing) === nothing ? nothing :
                                                           loc_of(f["agreeing_code"]))
                              for f in get(d, "fixes", [])],
                     passes = get(d, "passes", 0),
                     agent_launches = get(d, "agent_launches", 0), tokens = get(d, "tokens", nothing),
                     stop = getfield(Model.Stop, Symbol(get(d, "stop", "DONE"))),
                     readers = Symbol(get(d, "readers", "bound")),
                     scope = Symbol(get(d, "scope", "full")), base = get(d, "base", ""),
                     driver = get(d, "driver", ""),
                     model = get(d, "model", "session"), sequential = get(d, "sequential", false),
                     already_failing = Symbol[Symbol(x) for x in get(d, "already_failing", [])],
                     dropped = get(d, "dropped", 0))
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

THE WORK QUEUE IS ON THIS LIST for the same reason and one more. It is the session's note of what it
still owes, read by the end-of-turn hook, and that hook is what holds a session to a run it would
otherwise stop in the middle of. So the queue is most useful exactly while a run is open.

But the fixer classifies every changed file in the tree and refuses the whole commit if one is code, so
writing a single line into the queue made every remaining fix of that pass uncommittable. The session
had to choose between the machine that keeps it working and the machine that lets it work. The queue is
not the package's prose and never was; like the run's record it is the session's to commit at the close.
"""
own_record(path::AbstractString) =
    startswith(path, ".gbg/runs/") || startswith(path, ".gbg/scratch/") ||
    path == ".gbg/questions.json" || path == ".claude/WORK_QUEUE.md"

"""
    GUARD_TRAILER

The line `gbg docfix commit` writes into a commit it made, and the only mark a close trusts. A subject
line can be typed by anyone; what is being looked for is a change that did not pass the guard at all.
"""
const GUARD_TRAILER = "GBG-Docfix: guarded"

"""
    FINDING_TRAILER

The trailer `gbg docfix commit --finding <id>` writes: which finding a guarded commit fixed. The pass
machinery finds a finding's commits by it — to hand the diff verifier the diff, and to revert a fix a
verifier called worse.
"""
const FINDING_TRAILER = "GBG-Docfix-Finding: "

"""
    fix_commits(root, since, id) -> Vector{String}

The commits that `gbg docfix commit --finding` made for one finding, newest first. The arguments are:

- `root` — the package root.
- `since` — the run's first commit; nothing before it is searched.
- `id` — the finding's id.

Returns the shas.
"""
function fix_commits(root::AbstractString, since::AbstractString, id::AbstractString)
    (isempty(since) || since == "unknown") && return String[]
    out = try
        readchomp(pipeline(setenv(`git -C $root log --format=%H --grep=$(FINDING_TRAILER * id) $since..HEAD`; dir = root); stderr = devnull))
    catch
        return String[]
    end
    return [String(l) for l in split(out, '\n') if !isempty(l)]
end

"""
    guarded_commits(root, since) -> Vector{String}

The commits since `since` that passed the change guard, newest first. The arguments are `root`, the
package root, and `since`, the run's first commit. Returns the shas.

These are the run's own edits: what close undoes when it has to put the documentation back.
"""
function guarded_commits(root::AbstractString, since::AbstractString)
    (isempty(since) || since == "unknown") && return String[]
    out = try
        readchomp(pipeline(setenv(`git -C $root log --format=%H --grep=$GUARD_TRAILER $since..HEAD`; dir = root); stderr = devnull))
    catch
        return String[]
    end
    return [String(l) for l in split(out, '\n') if !isempty(l)]
end

"""
    revert!(root, sha) -> Bool

Reverts one guarded commit with a guarded revert, so close's classification sees a documentation change
and not code around the guard. The arguments are `root`, the package root, and `sha`, the commit.
Returns whether it reverted.
"""
function revert!(root::AbstractString, sha::AbstractString)
    ok = try
        run(pipeline(setenv(`git -C $root revert --no-edit $sha`; dir = root); stdout = devnull, stderr = devnull))
        run(pipeline(setenv(`git -C $root commit --amend -q -m "Revert $(first(sha, 8)): a verifier called the fix worse\n\n$GUARD_TRAILER"`; dir = root); stdout = devnull, stderr = devnull))
        true
    catch
        false
    end
    return ok
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
