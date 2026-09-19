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
"""
module Agents

using JSON3

using ...Model
using ...Catalogue
using ...Texts
using ...ConfigIO
using ..Runs

"""
    arguments_path(root, id) -> String

Where a stage's arguments are written for the session to pick up. The arguments are `root`, the package
root, and `id`, the run's id. Returns the path.
"""
arguments_path(root::AbstractString, id::AbstractString) = joinpath(Runs.dir(root, id), "arguments.json")

"""
    results_dir(root, id) -> String

Where the agents write what they found. The arguments are `root`, the package root, and `id`, the run's
id. Returns the directory.

One file per agent, named by its role and its index, so a crashed agent is a missing file rather than a
truncated one: the collector reports which roles wrote nothing, and the design relaunches those once.
"""
results_dir(root::AbstractString, id::AbstractString) = joinpath(Runs.dir(root, id), "results")

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
- `run` — the run, which carries its budget and what it has spent.
- `cfg` — the package's config.
- `roles` — the agent roles this stage launches.
- `io` — where the handoff is described.

Returns the path written.

The BUDGET travels with the arguments, as what is left rather than what was allowed: the driver launches
what it is given, and a stage that recomputed its own allowance from the instrument would spend the
budget again on every pass.
"""
function write_arguments(root::AbstractString, run::Model.Run, cfg::Model.Config;
                         roles::Vector{Model.AgentRole}, io::IO = stdout)
    left = max(0, run.budget.agent_launches - run.agent_launches)
    args = Dict{String,Any}(
        "run" => run.id,
        "instrument" => String(run.instrument),
        "stage" => String(run.stage),
        "package" => cfg.package,
        "root" => root,
        "results_dir" => results_dir(root, run.id),
        "launches_left" => left,
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
    println(io, "run: ", run.id, " is at ", run.stage, "; ", length(roles), " agent(s) to launch, ",
            left, " launch(es) left in the budget.")
    println(io, "  arguments: ", relpath(path, root))
    println(io, "  then: gbg run collect ", run.id)
    return path
end

"""
    collect_results(root, id) -> (findings, missing)

Reads what the agents wrote for one stage. The arguments are `root`, the package root, and `id`, the
run's id. Returns the findings and the roles that wrote nothing.

A role that wrote NOTHING is named rather than counted as clean. A crashed agent and a careful one that
found nothing are the same empty set to a reader, and the design relaunches a missing one once and then
names it — which is why this reports the gap instead of returning only what arrived.

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
    findings = Model.FindingDraft[]
    wrote = String[]
    for role in expected
        path = joinpath(dir, role * ".json")
        isfile(path) || continue
        push!(wrote, role)
        payload = try
            JSON3.read(read(path, String), Dict{String,Any})
        catch
            continue                                   # a malformed file is a missing one; the caller relaunches
        end
        for f in get(payload, "findings", [])
            locs = Model.Location[]
            for l in get(f, "locations", [])
                file = String(get(l, "file", "")); quote_ = String(get(l, "text", ""))
                node = String(get(l, "node", ""))
                push!(locs, Texts.reanchor(root, Model.Location(; file, node, text = quote_, line = 0)))
            end
            push!(findings, Model.FindingDraft(
                rule = get(f, "rule", nothing) === nothing ? nothing : Symbol(f["rule"]),
                locations = locs, claim = String(get(f, "claim", "")),
                evidence = String(get(f, "evidence", "")), fix = String(get(f, "fix", "")),
                maybe_code = get(f, "maybe_code", false)))
        end
    end
    return (findings, setdiff(expected, wrote))
end

end # module Agents
