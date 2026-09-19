# The design's §6, §10, §12; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Run

`gbg run <instrument>`, `gbg run next`, `gbg run collect` and `gbg run close`: one execution of one
instrument, a stage at a time.

Each stage is a HANDOFF. Julia cannot launch an agent and only the session can, so `next` writes what
the session needs and exits, the session runs the one fixed driver, and `collect` reads what the agents
wrote. `Runs` refuses any stage but the next, which is what stops a session from grading findings that
were never collected.

Exit 0 clean, 1 when something was found, 2 when a stage could not be evaluated.
"""
module Run

using ..GBGCodingTools: GBGCodingTools, Catalogue, ConfigIO, Engine, Model, Orchestration, Render,
                        parse_options, VERBS

const Runs = Orchestration.Runs
const Agents = Orchestration.Agents

"""
    open_run(root) -> Union{String,Nothing}

The run that is open in the package at `root`, or `nothing` where none is. The argument is `root`, the
package root. Returns the run's id.

A run is open from the moment it starts until `close` writes its record. Every verb below finds its run
this way rather than being told, since a run never starts another and there is therefore never a choice.
"""
function open_run(root::AbstractString)
    dir = joinpath(root, ".gbg", "runs")
    isdir(dir) || return nothing
    for d in sort(readdir(dir); rev = true)
        isfile(joinpath(dir, d, "stage")) && !isfile(joinpath(dir, d, "run.json")) && return d
    end
    return nothing
end

"""
    start(root, instrument; io = stdout) -> Int

Opens a run and writes its first stage's arguments. The arguments are:

- `root` — the package root.
- `instrument` — the instrument to run.
- `io` — where the handoff is described.

Exit 0 when it opened, 2 when it did not.
"""
function start(root::AbstractString, instrument::Symbol; io::IO = stdout)
    run = Runs.start(instrument, root; io)
    run === nothing && return 2
    println(io, "run: opened ", run.id, ".")
    return next(root; io)
end

"""
    next(root; io = stdout) -> Int

Moves the open run to its next stage and writes what the session needs to launch it. The arguments are:

- `root` — the package root.
- `io` — where the handoff is described.

Exit 0 when it moved, 2 when it could not.

It writes the arguments and EXITS. The session launches the driver itself, because only a session can;
a verb that waited for agents would be a verb that cannot run.
"""
function next(root::AbstractString; io::IO = stdout)
    id = open_run(root)
    id === nothing && (println(io, "run: nothing is open here"); return 2)
    run = Runs.load(root, id)
    here = Runs.stage_of(root, id)
    order = get(Runs.STAGES, run.instrument, Symbol[])
    at = findfirst(==(here), order)
    at === nothing && (println(io, "run: $id is at $here, which is not a stage of $(run.instrument)"); return 2)
    at == length(order) && (println(io, "run: ", id, " is at ", here, ", its last stage; close it"); return 2)
    to = order[at + 1]
    Runs.advance!(root, id, to; io) || return 2
    cfg = ConfigIO.read_config(root)
    moved = Model.Run(id = run.id, instrument = run.instrument, tool_version = run.tool_version,
                      first_commit = run.first_commit, budget = run.budget, stage = to,
                      findings = run.findings, agent_launches = run.agent_launches, stop = run.stop)
    Runs.save(root, moved)
    to === :close && (println(io, "run: ", id, " is ready to close: gbg run close"); return 0)
    Agents.write_arguments(root, moved, cfg; roles = Catalogue.roles_of(run.instrument), io)
    return 0
end

"""
    collect(root; io = stdout) -> Int

Reads what the agents wrote for the stage just launched. The arguments are:

- `root` — the package root.
- `io` — where the result goes.

Exit 0 when every role wrote, 1 when findings were collected, 2 when a role wrote nothing.

A role that wrote NOTHING is exit 2, not a quiet zero. A crashed agent and a careful one that found
nothing are the same empty set here, and the design relaunches a silent role once before naming it —
which cannot happen if its silence is read as a clean result.
"""
function collect(root::AbstractString; io::IO = stdout)
    id = open_run(root)
    id === nothing && (println(io, "run: nothing is open here"); return 2)
    drafts, silent = Agents.collect_results(root, id)
    run = Runs.load(root, id)
    findings = Model.Finding[]
    for (i, d) in pairs(drafts)
        push!(findings, Model.Finding(string(id, "-", lpad(i, 3, '0')), :agent,
                                      Model.Decider.AGENT, d))
    end
    collected = Model.Run(id = run.id, instrument = run.instrument, tool_version = run.tool_version,
                          first_commit = run.first_commit, budget = run.budget, stage = run.stage,
                          findings = vcat(run.findings, findings),
                          agent_launches = run.agent_launches + length(Catalogue.roles_of(run.instrument)),
                          stop = run.stop)
    Runs.save(root, collected)
    println(io, "run: collected ", length(findings), " finding(s) from ",
            length(Catalogue.roles_of(run.instrument)) - length(silent), " reader(s).")
    if !isempty(silent)
        println(io, "run: these wrote nothing, and are not clean — relaunch them once, then name them:")
        for s in silent; println(io, "  ", s); end
        return 2
    end
    return isempty(findings) ? 0 : 1
end

"""
    close_run(root; io = stdout) -> Int

Writes the run's record and its report, and ends it. The arguments are:

- `root` — the package root.
- `io` — where the result goes.

Exit 0 when it closed clean, 1 when it closed with findings open, 2 when it could not be evaluated.

Close runs one program before it writes anything: it classifies every commit since the run's first
commit, and a code change made outside `gbg docfix commit` ends the run `CANNOT_EVALUATE` with the owner
asked to keep or revert it. A review that edited code behind its own guard has not been reviewed.
"""
function close_run(root::AbstractString; io::IO = stdout)
    id = open_run(root)
    id === nothing && (println(io, "run: nothing is open here"); return 2)
    Runs.stage_of(root, id) === :close ||
        (println(io, "run: ", id, " is at ", Runs.stage_of(root, id), ", not close"); return 2)
    run = Runs.load(root, id)
    cfg = ConfigIO.read_config(root)

    unguarded = Runs.unguarded_code(root, run.first_commit)
    stop = isempty(unguarded) ? run.stop : Model.Stop.CANNOT_EVALUATE
    if !isempty(unguarded)
        println(io, "run: code changed outside `gbg docfix commit` since this run started:")
        for c in unguarded; println(io, "  ", c); end
        println(io, "The run ends CANNOT_EVALUATE; keeping or reverting that is the owner's to answer.")
    end

    closed = Model.Run(id = run.id, instrument = run.instrument, tool_version = run.tool_version,
                       first_commit = run.first_commit, budget = run.budget, stage = :close,
                       findings = run.findings, questions = run.questions,
                       agent_launches = run.agent_launches, stop = stop)
    dir = Runs.dir(root, id)
    write(joinpath(dir, "report.md"), Render.report(closed, cfg))
    open(joinpath(dir, "run.json"), "w") do f
        GBGCodingTools.JSON3.pretty(f, GBGCodingTools.JSON3.write(Runs.as_dict(closed)))
    end
    rm(joinpath(dir, "run.draft.json"); force = true)
    println(io, "run: ", id, " closed. ", length(closed.findings), " finding(s).")
    println(io, "  ", relpath(joinpath(dir, "report.md"), root))
    stop === Model.Stop.CANNOT_EVALUATE && return 2
    return isempty(closed.findings) ? 0 : 1
end

function cmd_run(args)
    o = parse_options(args)
    root = ConfigIO.require_root("run")
    root === nothing && return 2
    isempty(o.positional) && (println(stderr, "usage: gbg run <instrument> | gbg run next|collect|close"); return 2)
    what = o.positional[1]
    what == "next" && return next(root)
    what == "collect" && return collect(root)
    what == "close" && return close_run(root)
    return start(root, Symbol(replace(what, "-" => "_")))
end
VERBS["run"] = cmd_run

end # module Run
