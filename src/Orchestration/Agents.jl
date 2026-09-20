# The design's §4.1, §6; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Agents

What one stage of a run hands to the agents that read the package, and what it reads back.

**Julia cannot launch an agent and only the session can**, so every stage is a handoff: `gbg run next`
writes this module's arguments and exits, the session runs the one fixed Workflow driver, and `gbg run
collect` reads what the agents wrote. Nothing here starts a process.

The arguments are a file rather than a return value for the same reason: the two halves run in different
programs, minutes apart, and a file is what survives that. `test/driver.jl` checks the driver reads every
key written here, so a key added in Julia and never read is caught rather than silently ignored.

Everything the agents write, and the arguments they are given, lives under `.gbg/scratch/<run>/`, one
directory per stage instance — git-ignored, so it is never committed, and inside the package, so a run
interrupted in one session is continued in the next (ruled 2026-09-21). Closing the run deletes it.
"""
module Agents

using JSON3

using ...Model
using ...Catalogue
using ...Texts
using ...ConfigIO
using ..Runs

"""
    scratch_dir(root, id) -> String

Where a run's agents work: `.gbg/scratch/<id>/`. The arguments are `root`, the package root, and `id`,
the run's id. Returns the directory.
"""
scratch_dir(root::AbstractString, id::AbstractString) = joinpath(root, ".gbg", "scratch", id)

"""
    stage_dir(root, id) -> String

The current stage's directory under the run's scratch: `<position>-<stage>`, so two passes, or the bug
hunt's two collects, do not overwrite each other. The arguments are `root`, the package root, and `id`,
the run's id. Returns the directory.
"""
stage_dir(root::AbstractString, id::AbstractString) =
    joinpath(scratch_dir(root, id), string(Runs.stage_index(root, id), "-", String(Runs.stage_of(root, id))))

"""
    arguments_path(root, id) -> String

Where the current stage's arguments are written for the session to pick up. The arguments are `root`,
the package root, and `id`, the run's id. Returns the path.
"""
arguments_path(root::AbstractString, id::AbstractString) = joinpath(stage_dir(root, id), "arguments.json")

"""
    results_dir(root, id) -> String

Where the agents of the current stage write what they found. The arguments are `root`, the package root,
and `id`, the run's id. Returns the directory.

One file per agent, named by its role, so a crashed agent is a missing file rather than a truncated one:
the collector reports which roles wrote nothing, and the design relaunches those once.
"""
results_dir(root::AbstractString, id::AbstractString) = joinpath(stage_dir(root, id), "results")

"""
    surfaces(cfg, root) -> Vector{Pair{String,Vector{String}}}

The documentation surfaces an agent may be pointed at, each with its files. The arguments are `cfg`, the
package's config, and `root`, the package root. Returns one pair per surface that has any files.

A surface with no files is left out rather than sent empty. An agent handed nothing reports nothing and
is indistinguishable from one that read carefully and found nothing, which is the reading a clean report
must not admit.
"""
function surfaces(cfg::Model.Config, root::AbstractString)
    out = Pair{String,Vector{String}}[]
    for fs in (Model.FileSet.RATIONALE, Model.FileSet.PAGES, Model.FileSet.DOCSTRINGS, Model.FileSet.LITERATE)
        files = Texts.files(cfg, root, fs)
        isempty(files) || push!(out, lowercase(String(Symbol(fs))) => files)
    end
    return out
end

"""
    write_arguments(root, run, cfg; roles, io = stdout) -> String

Writes what the session needs to launch one stage. The arguments are:

- `root` — the package root.
- `run` — the run.
- `cfg` — the package's config.
- `roles` — the agent roles this stage launches.
- `io` — where the handoff is described.

Returns the path written.

Every role is launched: nothing caps launches, as ruled 2026-09-21 — the panel over the units, one
relaunch each and the pass cap bound a run by design, and a run cut short by an outage is continued.
"""
function write_arguments(root::AbstractString, run::Model.Run, cfg::Model.Config;
                         roles::Vector{Model.AgentRole}, io::IO = stdout)
    args = Dict{String,Any}(
        "run" => run.id,
        "instrument" => String(run.instrument),
        "stage" => String(run.stage),
        "package" => cfg.package,
        "root" => root,
        "results_dir" => results_dir(root, run.id),
        "settled" => [Dict{String,Any}("question" => s.question, "text" => s.text,
                                       "locations" => [Dict("file" => l.file, "text" => l.text) for l in s.locations])
                      for s in ConfigIO.read_settled(root)],
        "surfaces" => Dict{String,Any}(name => files for (name, files) in surfaces(cfg, root)),
        "roles" => [Dict{String,Any}("key" => String(r.id),
                                     "reads" => [lowercase(String(Symbol(fs))) for fs in r.reads],
                                     "site" => r.site, "kept_from_code" => r.kept_from_code,
                                     "description" => r.description,
                                     "rules" => [String(x) for x in r.rules],
                                     "strength" => lowercase(String(Symbol(r.strength))),
                                     "cap" => r.cap,
                                     "result_file" => joinpath(results_dir(root, run.id), String(r.id) * ".json"))
                    for r in roles])
    path = arguments_path(root, run.id)
    mkpath(dirname(path)); mkpath(results_dir(root, run.id))
    open(path, "w") do f; JSON3.pretty(f, JSON3.write(args)); end
    println(io, "run: ", run.id, " is at ", run.stage, "; ", length(roles), " agent(s) to launch.")
    println(io, "  arguments: ", relpath(path, root))
    println(io, "  then: gbg run collect ", run.id)
    return path
end

"""
    collect_results(root, id) -> (findings, silent, arrived)

Reads what the agents wrote for the current stage. The arguments are `root`, the package root, and `id`,
the run's id. Returns the findings, each with the role that made it; the roles that count as having
written nothing; and how many result files arrived at all.

A role counts as SILENT when its file is missing, when it does not parse, or when it reports no finding
and an empty `checked` list — the brief says an empty `checked` reads as a reader that did nothing, and
this is where that is kept. A crashed agent and a careful one that found nothing are the same empty set
to a reader, and the design relaunches a silent one once and then names it.

The LINE is filled in here, never taken from an agent: an agent reports the file, the quote and the node
it read, and a line it also reported would be its count of the text it was shown, not the file's.
"""
function collect_results(root::AbstractString, id::AbstractString)
    dir = results_dir(root, id)
    args_path = arguments_path(root, id)
    expected = String[]
    if isfile(args_path)
        args = JSON3.read(read(args_path, String), Dict{String,Any})
        expected = [String(r["key"]) for r in get(args, "roles", [])]
    end
    findings = Tuple{String,Model.FindingDraft}[]
    wrote = String[]
    arrived = 0
    for role in expected
        path = joinpath(dir, role * ".json")
        isfile(path) || continue
        arrived += 1
        payload = try
            JSON3.read(read(path, String), Dict{String,Any})
        catch
            continue                                   # malformed: silent, as if nothing had arrived
        end
        found = get(payload, "findings", [])
        checked = get(payload, "checked", [])
        isempty(found) && isempty(checked) && continue  # nothing found and nothing examined: silent
        push!(wrote, role)
        for f in found
            locs = Model.Location[]
            for l in get(f, "locations", [])
                file = String(get(l, "file", "")); quote_ = String(get(l, "text", ""))
                node = String(get(l, "node", ""))
                push!(locs, Texts.reanchor(root, Model.Location(; file, node, text = quote_, line = 0)))
            end
            push!(findings, (role, Model.FindingDraft(
                rule = get(f, "rule", nothing) === nothing ? nothing : Symbol(f["rule"]),
                locations = locs, claim = String(get(f, "claim", "")),
                evidence = String(get(f, "evidence", "")), fix = String(get(f, "fix", "")),
                maybe_code = get(f, "maybe_code", false))))
        end
    end
    return (findings, setdiff(expected, wrote), arrived)
end

end # module Agents
