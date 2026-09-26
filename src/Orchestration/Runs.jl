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
using ...Render
import SHA

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
    :documentation_review => [:start, :find, :collect, :fix, :verify, :collect, :close],
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
    # the run records and the work queue are the session's, looked past by the fixer and the close alike
    dirty = [p for p in changed_tracked(root) if !own_record(p)]
    if !isempty(dirty)
        println(io, "run: the tree is not clean; commit or stash these first, or close cannot tell the run's changes from yours:")
        for d in dirty; println(io, "  ", d); end
        return nothing
    end
    run = Model.Run(id = new_id(instrument, root), instrument = instrument,
                    tool_version = string(GBG_VERSION[]), first_commit = head_commit(root),
                    rulebook = rulebook_digest(cfg, instrument),
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

"""
    rulebook_digest(cfg, instrument) -> String

The SHA-256 of what a run's agents are given to judge by: every rule's section of the rendered
rulebook, the readers the package's panel derives — each one's id, standpoint, rules and material —
and the driver that writes their briefs. The arguments are `cfg`, the package's config, and
`instrument`, the instrument. Returns the hex digest.

A later `--scope changed` run reads everything again when its own differs: the silence of a run judged
by other rules, or read by other readers, says nothing about these. A digest of the rule statements
alone missed a reworded `why`, a rule moved from a program to a reader, and a reader added (found in
review, 2026-09-24); the version number, compared before, does not move on a development checkout.
"""
function rulebook_digest(cfg::Model.Config, instrument::Symbol)
    io = IOBuffer()
    for r in Catalogue.RULES
        println(io, Render.rule_section(r))
    end
    for r in first(Catalogue.panel(instrument, cfg))
        println(io, r.id, '\t', r.description, '\t', join(string.(r.rules), ","), '\t',
                join(string.(r.reads), ","), '\t', r.site, '\t', r.kept_from_code, '\t', r.cap)
    end
    driver = joinpath(pkgdir(Model), "drivers", "run.js")
    isfile(driver) && write(io, read(driver))
    return bytes2hex(SHA.sha256(take!(io)))
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
            locs = [reanchor(root, Model.Location(file = Catalogue.normal_path(cfg, root, l.file), node = l.node,
                                                  text = l.text, line = l.line, found = l.found, at = l.at);
                             since = prev.first_commit) for l in f.draft.locations]
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
    # A fix stage that committed nothing has nothing to verify and closes (found by PF, 2026-09-24).
    here === :fix && push!(candidates, length(order))
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
function closed(run::Model.Run, id::AbstractString)
    # The owner's answer closes it — the reader was wrong, or the documentation stands as fixed.
    answer_of(run, id) in (NOT_A_DEFECT_ANSWER, DOCS_ANSWER) && return true
    # Otherwise the LATEST verdict does. An earlier FIXED is not the finding's state once a later pass,
    # or a close that reverted the fix to get the build back, has said otherwise (found in review,
    # 2026-09-23: a fix undone at close left its finding "closed", carried nowhere and lost).
    k = findlast(f -> f.finding == id, run.fixes)
    k === nothing && return false
    f = run.fixes[k]
    # One verifier since 2026-09-26, so `with_diff` is nothing; a record from before carries the second
    # verdict, which must agree.
    return f.blind === Model.Verdict.NOT_A_DEFECT ||
           (f.blind === Model.Verdict.FIXED && (f.with_diff === nothing || f.with_diff === Model.Verdict.FIXED))
end

"The options of a code question, as the owner answers them."
const CODE_ANSWER = "fix the code"
const DOCS_ANSWER = "fix the documentation instead"
const NOT_A_DEFECT_ANSWER = "not a defect"
"""
The options of a parked finding's question, beside "not a defect": the owner makes the change himself,
which is what "fix the code" means on a code question and reads wrongly where the change is a switch or
a formula [found by PF, 2026-09-24]; or the fixer makes it on his ruling, given in `--direction`, after
which the finding is open and workable again and a verifier closes it [ruled 2026-09-26].
"""
const OWNER_ANSWER = "I make the change"
const RULED_ANSWER = "fix it on my ruling"

"Whether the owner took the finding as his own to change: `fix the code` or `I make the change`."
owner_took(run::Model.Run, id::AbstractString) = answer_of(run, id) in (CODE_ANSWER, OWNER_ANSWER)

"""
    answer_of(run, id) -> Union{String,Nothing}

The owner's answer to the code question a run put about finding `id`, or `nothing` while none is
given. The arguments are `run` and the finding's `id`. Returns the option he chose.
"""
function answer_of(run::Model.Run, id::AbstractString)
    k = findfirst(q -> q.id == code_question_id(run, id), run.questions)
    return k === nothing ? nothing : run.questions[k].answer
end

# The id of the question a run puts about one of its findings. A finding's id already carries the run's,
# so nothing is prefixed: `<run>-<run>-004-code` was the result before (found by PF, 2026-09-24).
"The id of a run's question about one of its findings: the finding's id and `-code`."
code_question_id(run::Model.Run, id::AbstractString) = string(id, "-code")

"""
    to_owner(run) -> Vector{Model.Finding}

The findings the owner answered "fix the code" on: no pass works on them and none is carried; each is
his, with the direction he gave. The argument is `run`. Returns them in the run's order.
"""
to_owner(run::Model.Run) = [f for f in run.findings if owner_took(run, f.id)]

"""
    open_findings(run) -> Vector{Model.Finding}

The findings of `run` still open: not closed by a verdict, and not in material. The argument is `run`.
Returns them in the run's order.

A finding in material is never open in this sense: no pass works on it, no verifier is asked about it,
it is not a leftover and is not carried into the next run. It is the owner's from the moment it is
collected, and [`in_material`](@ref) is where it is read.
"""
open_findings(run::Model.Run) = [f for f in run.findings if !closed(run, f.id) && !f.draft.in_material &&
                                                             !owner_took(run, f.id) && !(f.id in run.dropped_ids)]

"""
    in_material(run) -> Vector{Model.Finding}

The findings of `run` located only in material: what a reader given the working notes to consult found
there. The argument is `run`. Returns them in the run's order.
"""
in_material(run::Model.Run) = [f for f in run.findings if f.draft.in_material]

"""
    parked(run, id) -> Bool

Whether the finding `id` waits on the owner: a question about it stands, unanswered. The arguments are
`run` and the finding's id. Returns the answer.

Two things put one. A blind verifier's `HIDES_CODE_DEFECT`, where the fix is reverted and the owner is
asked which half is right; and the fixer's `gbg run park`, for a finding whose fix only the owner may
make — a change to the config, to code or to a formula. Before the second existed such a finding stayed
open, a verifier was launched on it every pass to find nothing changed, and it reached the owner only at
close (found reviewing [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/)' first run, 2026-09-24).

A parked finding is open — it is nobody's leftover — and is worked on by no pass: no fixer is sent to it
and no verifier is asked about it again until the owner has answered.
"""
function parked(run::Model.Run, id::AbstractString)
    answer_of(run, id) === nothing || return false          # answered: no longer waiting
    return any(q -> q.id == code_question_id(run, id), run.questions)
end

"""
    owner_question(run, f, why) -> Model.Question

The question `gbg run park` puts: the finding needs a change only the owner may make. The arguments are:

- `run` — the run.
- `f` — the finding.
- `why` — the fixer's reason.

Returns the question, under the finding's own question id, so every answer does what the same answer
does to a verifier's code question.
"""
owner_question(run::Model.Run, f::Model.Finding, why::AbstractString) = Model.Question(
    id = code_question_id(run, f.id),
    decision = "This finding needs a change only you may make. Will you make it?",
    context = String(strip(why)),
    options = [Model.Option(OWNER_ANSWER, "the change is yours: the finding goes on your list, and the run leaves it", true),
               Model.Option(RULED_ANSWER, "the fixer makes it as your --direction says; the finding is open again, and a verifier closes it", false),
               Model.Option(NOT_A_DEFECT_ANSWER, "nothing changes, and the finding is closed", false)])

"""
    open_questions(root) -> Vector{Tuple{String,Model.Question}}

Every question a run in the package at `root` put and the owner has not answered, newest run first,
with that run's id. The argument is `root`. Returns the pairs.

A parked finding is not carried into the next run, since the question stands; so the question itself
is what must stay in sight — listed by `gbg ask` and on the work queue after every close — or the
finding is lost once the queue's section is rewritten (found in review, 2026-09-23).
"""
function open_questions(root::AbstractString)
    d = joinpath(root, ".gbg", "runs")
    out = Tuple{String,Model.Question}[]
    isdir(d) || return out
    for name in sort(readdir(d); rev = true)
        run = load(root, name)
        run === nothing && continue
        for q in run.questions
            q.answer === nothing && push!(out, (name, q))
        end
    end
    return out
end

"""
    finding_of(root, sha) -> Union{String,Nothing}

The finding a guarded fix commit names in its trailer, or `nothing`. The arguments are `root` and the
commit `sha`. Returns the finding's id.
"""
function finding_of(root::AbstractString, sha::AbstractString)
    body = git_out(root, "log", "-1", "--format=%b", sha)
    body === nothing && return nothing
    for l in strip.(split(body, '\n'))
        startswith(l, FINDING_TRAILER) && return String(strip(l[length(FINDING_TRAILER)+1:end]))
    end
    return nothing
end

"""
    reverted_by(root, since, fixes) -> Vector{String}

The reverts this package made of the given fix commits since `since`, newest first. The arguments are:

- `root` — the package root.
- `since` — the run's first commit.
- `fixes` — the fix commits' full shas.

Returns the revert shas — what puts those fixes back.
"""
function reverted_by(root::AbstractString, since::AbstractString, fixes::AbstractVector)
    log = git_out(root, "log", "--format=%H%x1f%b%x1e", "$since..HEAD")
    log === nothing && return String[]
    out = String[]
    for e in split(log, '\x1e'; keepempty = false)
        p = split(strip(e, ['\n']), '\x1f')
        for l in strip.(split(length(p) >= 2 ? String(p[2]) : "", '\n'))
            startswith(l, REVERT_TRAILER) && String(strip(l[length(REVERT_TRAILER)+1:end])) in fixes && push!(out, String(p[1]))
        end
    end
    return out
end

"""
    reverts_of(root, since, id) -> Vector{String}

The reverts this package made of finding `id`'s fixes since `since`, newest first. The arguments are:

- `root` — the package root.
- `since` — the run's first commit.
- `id` — the finding's id.

Returns the shas — what re-applies the documentation when the owner answers that it was right after
all.
"""
function reverts_of(root::AbstractString, since::AbstractString, id::AbstractString)
    log = git_out(root, "log", "--format=%H%x1f%b%x1e", "$since..HEAD")
    log === nothing && return String[]
    mine = Set{String}(); out = String[]
    entries = [split(strip(e, ['\n']), '\x1f') for e in split(log, '\x1e'; keepempty = false)]
    for p in entries
        lines = strip.(split(length(p) >= 2 ? String(p[2]) : "", '\n'))
        (FINDING_TRAILER * id) in lines && push!(mine, String(p[1]))
    end
    for p in entries
        lines = strip.(split(length(p) >= 2 ? String(p[2]) : "", '\n'))
        for l in lines
            startswith(l, REVERT_TRAILER) && String(strip(l[length(REVERT_TRAILER)+1:end])) in mine && push!(out, String(p[1]))
        end
    end
    return out
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

# An answer changes one field of the record, and every other is carried over by name off the type: the
# list written out here by hand dropped `rulebook` on every answer (found 2026-09-24).
with_questions(r::Model.Run, qs::Vector{Model.Question}) =
    Model.Run(; (f => (f === :questions ? qs : getfield(r, f)) for f in fieldnames(Model.Run))...)

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
    "scope" => String(r.scope), "base" => r.base, "driver" => r.driver, "dropped" => r.dropped, "unreverted" => r.unreverted, "silent" => r.silent, "rulebook" => r.rulebook,
    "pass_since" => r.pass_since, "dropped_ids" => r.dropped_ids,
    "questions" => [question_dict(q) for q in r.questions],
    "fixes" => [Dict{String,Any}("finding" => f.finding, "pass" => f.pass, "commit" => f.commit,
                                  "formula_edit" => f.formula_edit, "blind" => String(Symbol(f.blind)),
                                  "with_diff" => f.with_diff === nothing ? nothing : String(Symbol(f.with_diff)),
                                  "agreeing_code" => f.agreeing_code === nothing ? nothing : loc_dict(f.agreeing_code),
                                  "note" => f.note)
                for f in r.fixes],
    "usage" => [Dict{String,Any}("stage" => u.stage, "pass" => u.pass, "agents" => u.agents, "input" => u.input,
                                 "cache_write" => u.cache_write, "cache_read" => u.cache_read, "output" => u.output)
                for u in r.usage],
    "findings" => [Dict{String,Any}("id" => f.id, "source" => String(f.source),
                                    "decider" => String(Symbol(f.decider)),
                                    "claim" => f.draft.claim, "evidence" => f.draft.evidence,
                                    "fix" => f.draft.fix, "maybe_code" => f.draft.maybe_code,
                                    "in_material" => f.draft.in_material,
                                    "rule" => f.draft.rule === nothing ? nothing : String(f.draft.rule),
                                    "locations" => [loc_dict(l) for l in f.draft.locations]) for f in r.findings])

loc_dict(l::Model.Location) = Dict{String,Any}("file" => l.file, "node" => l.node, "text" => l.text,
                                               "line" => l.line, "found" => String(Symbol(l.found)), "at" => l.at)

loc_of(d) = Model.Location(; file = get(d, "file", ""), node = get(d, "node", ""),
                            text = get(d, "text", ""), line = get(d, "line", 0),
                            found = getfield(Model.Anchor, Symbol(get(d, "found", "FRESH"))), at = get(d, "at", ""))

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
                                                           loc_of(f["agreeing_code"]),
                                           note = get(f, "note", ""))
                              for f in get(d, "fixes", [])],
                     usage = [Model.Usage(stage = String(get(u, "stage", "")), pass = get(u, "pass", 0),
                                          agents = get(u, "agents", 0), input = get(u, "input", 0),
                                          cache_write = get(u, "cache_write", 0), cache_read = get(u, "cache_read", 0),
                                          output = get(u, "output", 0))
                              for u in get(d, "usage", [])],
                     pass_since = get(d, "pass_since", ""),
                     dropped_ids = String[String(x) for x in get(d, "dropped_ids", [])],
                     passes = get(d, "passes", 0),
                     agent_launches = get(d, "agent_launches", 0), tokens = get(d, "tokens", nothing),
                     stop = getfield(Model.Stop, Symbol(get(d, "stop", "DONE"))),
                     readers = Symbol(get(d, "readers", "bound")),
                     scope = Symbol(get(d, "scope", "full")), base = get(d, "base", ""),
                     driver = get(d, "driver", ""),
                     model = get(d, "model", "session"), sequential = get(d, "sequential", false),
                     already_failing = Symbol[Symbol(x) for x in get(d, "already_failing", [])],
                     dropped = get(d, "dropped", 0),
                     unreverted = String[String(x) for x in get(d, "unreverted", [])],
                     silent = String[String(x) for x in get(d, "silent", [])],
                     rulebook = get(d, "rulebook", ""))
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

Every commit is classified, the guard's own included: the trailer `gbg docfix commit` writes is typed
text, and a code change amended into a guarded commit, or a plain commit carrying the trailer, would
otherwise go unread. A revert this package made is classified too; only a refusal for mathematics alone
is not counted on it, since a revert may put back a formula its fix removed and mathematics is not code.
"""
function unguarded_code(root::AbstractString, since::AbstractString)
    (isempty(since) || since == "unknown") && return String[]
    cfg = try ConfigIO.read_config(root) catch; return String[] end
    log = git_out(root, "log", "--format=%H%x1f%s%x1f%b%x1e", "$since..HEAD")
    log === nothing && return String[]
    out = String[]
    for entry in split(log, '\x1e'; keepempty = false)
        parts = split(strip(entry, ['\n']), '\x1f')
        length(parts) >= 2 || continue
        sha, subject = String(parts[1]), String(parts[2])
        body = length(parts) >= 3 ? String(parts[3]) : ""
        # EVERY commit is classified, the guard's and its reverts included; a trailer is typed text and
        # proves nothing. What this looks for is CODE changed around the guard. A revert this package
        # made may put a formula back that its fix had taken out, so for a commit carrying the revert
        # mark a refusal for mathematics alone is not counted — mathematics is not code, and a forged
        # mark buys nothing else (simplified 2026-09-23: recognising "exact" reverts took four review
        # passes and still had holes; this needs no recognition).
        revert = any(l -> startswith(strip(l), REVERT_TRAILER), split(body, '\n'))
        code = String[]
        for (status, f, odd) in touched(root, sha)
            own_record(f) && continue
            odd && (push!(code, f); continue)          # a symlink, a submodule, a mode change: never prose
            before = status == "A" ? nothing : git_file(root, sha * "^", f)
            after = status == "D" ? nothing : git_file(root, sha, f)
            # a side git could not read, where the status says it exists, is code: an unreadable file
            # is not one anybody checked
            ((status != "A" && before === nothing) || (status != "D" && after === nothing)) &&
                (push!(code, f); continue)
            r = Engine.Guard.classify(cfg, f, before, after)
            r.documentation || (revert && occursin("(clause 6)", r.reason)) || push!(code, f)
        end
        isempty(code) && continue
        push!(out, first(sha, 8) * "  " * subject * "  [" * join(first(code, 4), ", ") *
                   (length(code) > 4 ? ", …" : "") * "]")
    end
    return out
end

# git, its output exactly as git wrote it — no stripping — or `nothing` where git failed.
function git_out(root::AbstractString, args...)
    try
        read(pipeline(setenv(`git -C $root -c core.quotePath=false $(collect(args))`; dir = root); stderr = devnull), String)
    catch
        nothing
    end
end

git_file(root, rev, path) = git_out(root, "show", "$rev:$path")

# Each file a commit touched, with its status (A, M, D, T; a rename is read as its delete and its add)
# and whether it is ODD — a symlink or a submodule on either side, or a mode change — which is never
# prose, since the docs build follows a link and runs what it finds (found in review, 2026-09-23). NUL
# separated, so no name is quoted: a quoted name read back failed on both sides and was called unchanged.
function touched(root::AbstractString, sha::AbstractString)
    raw = git_out(root, "show", "--raw", "--no-renames", "-z", "--format=", sha)
    raw === nothing && return Tuple{String,String,Bool}[]
    parts = split(raw, '\0')
    out = Tuple{String,String,Bool}[]
    i = 1
    while i <= length(parts)
        rec = lstrip(parts[i], '\n')
        if startswith(rec, ":") && i + 1 <= length(parts)
            fields = split(lstrip(rec, ':'))
            modes = [m for m in fields if occursin(r"^[0-7]{6}$", m)]
            status = String(first(last(fields), 1))
            live = [m for m in modes if m != "000000"]
            odd = any(m -> m in ("120000", "160000"), live) || length(unique(live)) > 1 || status == "T"
            push!(out, (status == "T" ? "M" : status, String(parts[i+1]), odd))
            i += 2
        else
            i += 1
        end
    end
    return out
end

# The fixes a revert this package made has undone, by the full sha its mark names. Bookkeeping, not a
# boundary: every commit is classified anyway, and `docfix commit` refuses a message typing the mark.
function reverted(root::AbstractString, since::AbstractString)
    out = Set{String}()
    (isempty(since) || since == "unknown") && return out
    log = git_out(root, "log", "--format=%b%x1e", "$since..HEAD")
    log === nothing && return out
    for body in split(log, '\x1e'; keepempty = false)
        lines = strip.(split(body, '\n'))
        GUARD_TRAILER in lines || continue
        for l in lines
            startswith(l, REVERT_TRAILER) && push!(out, String(strip(l[length(REVERT_TRAILER)+1:end])))
        end
    end
    return out
end

"""
    changed_files(root, sha) -> Vector{String}

The files one commit touched. The arguments are `root`, the package root, and `sha`, the commit. Returns
the paths, unquoted, empty where git cannot say.
"""
changed_files(root::AbstractString, sha::AbstractString) = [f for (_, f, _) in touched(root, sha)]

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
    REVERT_TRAILER

The trailer a revert this package makes carries, naming the commit it undoes. A close skips such a
commit only when it is exactly that commit's inverse, so the trailer alone buys nothing.
"""
const REVERT_TRAILER = "GBG-Docfix-Revert: "

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
    # The WHOLE trailer line, not a substring: `…-100` is a prefix of `…-1000`, and a substring match
    # handed one finding's diff to another's verifier and reverted the wrong fix (found in review,
    # 2026-09-23). A finding's own commits, less any a revert this package made has undone.
    log = git_out(root, "log", "--format=%H%x1f%b%x1e", "$since..HEAD")
    log === nothing && return String[]
    undone = reverted(root, since)
    mine = String[]
    for entry in split(log, '\x1e'; keepempty = false)
        parts = split(strip(entry, ['\n']), '\x1f')
        sha = String(parts[1]); lines = strip.(split(length(parts) >= 2 ? String(parts[2]) : "", '\n'))
        (FINDING_TRAILER * id) in lines && !(sha in undone) && push!(mine, sha)
    end
    return mine
end

"""
    guarded_commits(root, since) -> Vector{String}

The commits since `since` that passed the change guard, newest first. The arguments are `root`, the
package root, and `since`, the run's first commit. Returns the shas.

These are the run's own edits: what close undoes when it has to put the documentation back.
"""
function guarded_commits(root::AbstractString, since::AbstractString)
    (isempty(since) || since == "unknown") && return String[]
    # A fix commit, not a revert: close undoes the run's EDITS, and undoing a revert would put back a
    # fix a verifier rejected (found in review, 2026-09-23). Nor one a revert already undid.
    log = git_out(root, "log", "--format=%H%x1f%b%x1e", "$since..HEAD")
    log === nothing && return String[]
    undone = reverted(root, since)
    out = String[]
    for entry in split(log, '\x1e'; keepempty = false)
        parts = split(strip(entry, ['\n']), '\x1f')
        sha = String(parts[1]); lines = strip.(split(length(parts) >= 2 ? String(parts[2]) : "", '\n'))
        GUARD_TRAILER in lines && !(sha in undone) &&
            !any(l -> startswith(l, REVERT_TRAILER), lines) && push!(out, sha)
    end
    return out
end

"""
    revert!(root, sha) -> Bool

Reverts one guarded commit, marking the revert with the commit it undoes, so a close can check that it
is exactly that commit's inverse. The arguments are `root`, the package root, `sha`, the commit, and
`why`, the reason written into the message. Returns whether it reverted: refused while anything is
staged, and a revert that does not apply is aborted and leaves the tree as it was.
"""
function revert!(root::AbstractString, sha::AbstractString; why::AbstractString = "a verifier called the fix worse")
    # Never over staged work: a revert commits the index, and an abort resets it, so work staged by
    # someone else was either committed inside the revert or destroyed (found in review, 2026-09-23).
    staged = git_out(root, "diff", "--cached", "--name-only")
    (staged === nothing || !isempty(strip(staged))) && return false
    full = something(git_out(root, "rev-parse", sha), sha) |> strip
    msg = "Revert " * first(full, 8) * ": " * why * "\n\n" * GUARD_TRAILER * "\n" * REVERT_TRAILER * full
    try
        run(pipeline(setenv(`git -C $root revert --no-commit $full`; dir = root); stdout = devnull, stderr = devnull))
        run(pipeline(setenv(`git -C $root commit -q -m $msg`; dir = root); stdout = devnull, stderr = devnull))
        return true
    catch
        # the index was clean, so aborting touches only what the revert itself staged
        try run(pipeline(setenv(`git -C $root revert --abort`; dir = root); stdout = devnull, stderr = devnull)) catch end
        return false
    end
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
    now = head_commit(root)
    found.found === Model.Anchor.OUTDATED || return stamped(found, now)
    since = isempty(loc.at) ? since : loc.at             # the tree the line was last read in
    isempty(since) && return found
    # A file that is GONE is outdated whatever git says. `git diff` over a path that no longer exists
    # prints nothing, and an empty patch otherwise means "nothing moved" — so without this the deleted
    # file came back `BY_DIFF` at its original line, which is the one answer the design forbids.
    isfile(joinpath(root, loc.file)) || return found
    line = mapped_line(root, loc, since)
    line === nothing && return found
    return Model.Location(; file = loc.file, node = Texts.node_at(root, loc.file, line), text = loc.text,
                           line = line, found = Model.Anchor.BY_DIFF, at = now == "unknown" ? "" : String(now))
end

# The location with the commit its line was read at. Re-anchoring runs where the tree is clean — a run
# starts and collects only on one, and a fix pass follows commits — so HEAD is the tree the line is in.
stamped(l::Model.Location, now::AbstractString) = now in ("", "unknown") ? l :
    Model.Location(; file = l.file, node = l.node, text = l.text, line = l.line, found = l.found, at = String(now))

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
    loc.line >= 1 || return nothing                     # line 0 was never a place; there is nothing to carry
    isempty(patch) && return loc.line
    offset = 0
    for m in eachmatch(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"m, patch)
        old_start = parse(Int, m.captures[1])
        old_len = m.captures[2] === nothing ? 1 : parse(Int, m.captures[2])
        new_start = parse(Int, m.captures[3])
        new_len = m.captures[4] === nothing ? 1 : parse(Int, m.captures[4])
        # The hunk is below the line and cannot move it. A pure insertion (`-n,0`) is AFTER line n, so
        # one right after the finding's line is below it too.
        (old_len == 0 ? old_start >= loc.line : old_start > loc.line) && break
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
