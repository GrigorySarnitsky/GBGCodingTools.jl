# The design's §4.1, §4.3, §6; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Agents

What one stage of a run hands to the agents that read the package, and what it reads back.

**Julia cannot launch an agent and only the session can**, so every stage is a handoff: `gbg run next`
writes this module's arguments and exits, the session runs the one fixed Workflow driver, and `gbg run
collect` reads what the agents wrote. Nothing here starts a process.

The arguments are a file rather than a return value for the same reason: the two halves run in different
programs, minutes apart, and a file is what survives that. `test/driver.jl` checks the driver reads every
key written here, so a key added in Julia and never read is caught rather than silently ignored.

Two kinds of agent are launched through the same arguments: a READER, given surfaces and rules and
returning findings, and a VERIFIER, given one finding and returning a verdict on its fix. Every role
carries the same keys — a reader's `finding` is empty — so the driver reads one shape.

A reader of the WITHHELD bundle is launched once per UNIT: its `unit` names a file holding one built
page's text and nothing else, and its surfaces are not listed, because a reader that is given the whole
documentation is not the reader the rule was tagged for.

Everything the agents write, and the arguments they are given, lives under `.gbg/scratch/<run>/`, one
directory per stage instance — git-ignored, so it is never committed, and inside the package, so a run
interrupted in one session is continued in the next (ruled 2026-09-21): the arguments record the commit
they were written at, each role carries a LAUNCH mark, and continuing a stage clears the mark of every
role whose result already arrived. Closing the run deletes it.
"""
module Agents

using JSON3
import SHA

using ...Model
using ...Catalogue
using ...Texts
using ...ConfigIO
using ..Runs

"""
    ECONOMY_MODEL

The model an agent of `ECONOMY` strength runs on. The careful model is the run's own, named when it was
started and `"session"` where nobody named one, since the session's model is then the honest answer;
this one is named here because no run chooses it — the economy tier is what the tool calls economy.
"""
const ECONOMY_MODEL = "sonnet"

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
    finding_dict(f) -> Dict

One finding as a verifier is handed it: its id, claim, rule and every location with the text as it
reads now. The argument is `f`, the finding. Returns the dictionary.
"""
finding_dict(f::Model.Finding) = Dict{String,Any}(
    "id" => f.id, "claim" => f.draft.claim, "fix" => f.draft.fix,
    "rule" => f.draft.rule === nothing ? nothing : String(f.draft.rule),
    "locations" => [Dict{String,Any}("file" => l.file, "node" => l.node, "text" => l.text, "line" => l.line,
                                     "found" => String(Symbol(l.found))) for l in f.draft.locations])

"""
    write_arguments(root, run, cfg; roles, extras, site, io) -> String

Writes what the session needs to launch one stage. The arguments are:

- `root` — the package root.
- `run` — the run.
- `cfg` — the package's config.
- `roles` — the agent roles this stage launches, readers or verifiers.
- `extras` — per role id, what a role needs beyond the derived reader: `kind`, `finding`, `diff` and
  `verdicts` for a verifier; `unit` and `unit_source` for a reader given one built page.
- `site` — the built site's directory, for the reader that reads the whole of it; empty where none was
  built.
- `io` — where the handoff is described.

Returns the path written.

Every role is launched: nothing caps launches, as ruled 2026-09-21 — the panel over the units, one
relaunch each and the pass cap bound a run by design, and a run cut short by an outage is continued.

WHAT THIS FILE COSTS IS WHY IT IS SHAPED THIS WAY. A workflow script has no filesystem, so the session
cannot hand the driver a path: it types the arguments into the launching call, and every byte here is a
byte of the session's context. Two things made that file large and neither had to be in it.

The first is the same brief written out once per role. A stage's instruction to its verifiers is one
paragraph and does not vary; the standpoint a reader carries is a page and is shared by every unit that
reader is launched over. Written per role, one paragraph becomes a hundred and forty copies. They go
into `briefs`, each once, and a role names the one it was given.

The second is the material a verifier judges — the finding, with the text quoted at every location, and
the diff of the fix made for it. That is the bulk of the file and no part of it is the script's to read:
the script only names it in a brief, and the agent has file tools. So each is written beside the
arguments and passed as a PATH, which is what a reader given one built page has always been given. The
file's size no longer depends on the size of a finding or a diff, and `test/driver.jl` holds it there.

The third is the rest of a role. Nine of its fields were the same for every role of one shape and three
were the key with a directory around it, so a role cost about 435 bytes of which 57 were its own. The
shared fields go into `kinds`, keyed by their value so nothing is classified by hand, and the two
directories go into `dirs`; the driver rehydrates each role once from those. What is left per role is
what is its own, and the test bounds it.
"""
function write_arguments(root::AbstractString, run::Model.Run, cfg::Model.Config;
                         roles::Vector{Model.AgentRole}, extras::AbstractDict = Dict{Symbol,Any}(),
                         site::AbstractString = "", io::IO = stdout)
    args = Dict{String,Any}(
        "run" => run.id,
        "commit" => head(root),
        "instrument" => String(run.instrument),
        "stage" => String(run.stage),
        "pass" => run.passes,
        "package" => cfg.package,
        "root" => root,
        "results_dir" => results_dir(root, run.id),
        "site" => String(site),
        "sequential" => run.sequential,
        "models" => Dict{String,Any}("full" => run.model, "economy" => ECONOMY_MODEL),
        "settled" => [Dict{String,Any}("question" => s.question, "text" => s.text,
                                       "locations" => [Dict("file" => l.file, "text" => l.text) for l in s.locations])
                      for s in ConfigIO.read_settled(root)],
        "surfaces" => Dict{String,Any}(name => files for (name, files) in surfaces(cfg, root)))
    briefs = Dict{String,String}()          # the text, once, under the key a role names
    keys_of = Dict{String,String}()         # the text seen before, and the key it was given
    kinds = Dict{String,Any}()              # the fields shared by every role of one shape, once
    kind_of = Dict{Any,String}()            # the shape seen before, and the key it was given
    side = joinpath(scratch_dir(root, run.id), "material")
    isempty(roles) || mkpath(side)
    args["briefs"] = briefs
    args["kinds"] = kinds
    args["dirs"] = Dict{String,Any}("results" => results_dir(root, run.id), "material" => side)
    args["roles"] = [begin
        x = get(extras, r.id, Dict{String,Any}())
        brief = get!(keys_of, r.description) do
            k = "b" * string(length(keys_of) + 1)
            briefs[k] = r.description
            k
        end
        found = get(x, "finding", nothing)
        found === nothing || open(joinpath(side, String(r.id) * ".json"), "w") do f
            JSON3.pretty(f, JSON3.write(found))
        end
        diff = String(get(x, "diff", ""))
        isempty(diff) || write(joinpath(side, String(r.id) * ".diff"), diff)
        # Everything identical across the roles of one shape, keyed by its VALUE so the table is as
        # small as the stage's variety and no field has to be classified by hand: a reader's shape is
        # its own, a verifier's is shared by every finding under the same rule and reader.
        shape = Dict{String,Any}("kind" => get(x, "kind", "reader"),
                                 "reads" => [lowercase(String(Symbol(fs))) for fs in r.reads],
                                 "site" => r.site, "kept_from_code" => r.kept_from_code,
                                 "brief" => brief,
                                 "rules" => [String(y) for y in r.rules],
                                 "strength" => lowercase(String(Symbol(r.strength))),
                                 "cap" => r.cap,
                                 "diff" => !isempty(diff),
                                 "verdicts" => get(x, "verdicts", String[]))
        kind = get!(kind_of, shape) do
            k = "k" * string(length(kind_of) + 1)
            kinds[k] = shape
            k
        end
        Dict{String,Any}("key" => String(r.id), "kind" => kind, "launch" => true,
                         "unit" => get(x, "unit", ""), "unit_source" => get(x, "unit_source", ""),
                         "finding" => get(x, "finding_id", ""))
    end for r in roles]
    path = arguments_path(root, run.id)
    mkpath(dirname(path)); mkpath(results_dir(root, run.id))
    write(path, JSON3.write(args))   # compact: nobody reads this file, the session TYPES it
    driver, sha = place_driver(root, run.id)
    println(io, "run: ", run.id, " is at ", run.stage, "; ", length(roles), " agent(s) to launch.")
    println(io, "  arguments: ", relpath(path, root))
    println(io, "  driver:    ", relpath(driver, root), "  (", first(sha, 12), ")")
    println(io, "  launch it: Workflow({scriptPath: \"", relpath(driver, root), "\", args: <the arguments file>})")
    println(io, "  then: gbg run collect")
    return path
end

"""
    place_driver(root, id) -> Tuple{String,String}

Puts the driver where the session can launch it from, and says which one it put. The arguments are
`root`, the package root, and `id`, the run's id. Returns the path it wrote and the SHA-256 of the file,
which is what a record means by "which driver this run used".

The pinned driver lives under `~/.julia/packages/`, and the `Workflow` tool refuses a script outside the
working directory — so naming the pinned path directly cannot work, in any consumer, ever. Every package
would otherwise discover that and copy the file by hand, as [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/) did on 2026-09-22, and no
record would say which driver the run had actually used. The copy is byte for byte, into the run's own
scratch, which is gitignored and deleted at close.
"""
function place_driver(root::AbstractString, id::AbstractString)
    src = joinpath(pkgdir(Model), "drivers", "run.js")
    dest = joinpath(scratch_dir(root, id), "run.js")
    mkpath(dirname(dest))
    cp(src, dest; force = true)
    return dest, bytes2hex(SHA.sha256(read(dest)))
end

# The commit the package is at, or "" outside a repository; what a continued stage is compared against.
function head(root::AbstractString)
    try
        readchomp(pipeline(setenv(`git -C $root rev-parse HEAD`; dir = root); stderr = devnull))
    catch
        ""
    end
end

"""
    result_file(args, role) -> String
    kind_of_role(args, role) -> String

What a role's result path and kind are, read back from the arguments as the driver reads them. The
arguments are `args`, the parsed arguments file, and `role`, one entry of its `roles`. Returns the
path a role's agent writes its result to, and the role's kind (`reader`, `verifier`, `tagger`).

A role carries only what is its own — its key, its kind's name, its unit and its finding — and the
rest is looked up: the shared fields under `kinds`, the two directories under `dirs`. These two are
the Julia side of that lookup, and `test/driver.jl` holds the driver to reading the same keys.
"""
result_file(args::AbstractDict, role::AbstractDict) =
    joinpath(String(args["dirs"]["results"]), String(role["key"]) * ".json")
kind_of_role(args::AbstractDict, role::AbstractDict) =
    String(get(get(get(args, "kinds", Dict()), String(role["kind"]), Dict()), "kind", "reader"))

"""
    launched_at(root, id) -> Union{String,Nothing}

The commit the current stage's arguments were written at, or `nothing` where none were. The arguments
are `root`, the package root, and `id`, the run's id. Returns the commit.
"""
function launched_at(root::AbstractString, id::AbstractString)
    path = arguments_path(root, id)
    isfile(path) || return nothing
    return String(get(JSON3.read(read(path, String), Dict{String,Any}), "commit", ""))
end

"""
    continue_stage(root, id) -> Union{NamedTuple,Nothing}

Prepares the current stage to be launched again after an interruption: every role whose result file
already arrived has its launch mark cleared, so the driver relaunches only what is missing and the
collect still expects every role. The arguments are `root`, the package root, and `id`, the run's id.
Returns `(missing, total, moved)` — the roles still to launch, how many there were, and whether the tree
is at a different commit than when the stage was written — or `nothing` where no arguments exist.

Nothing of an unfinished stage is taken: a result that arrived stands, one that did not is asked for
again, and a stage launched against one commit and continued against another is reported as MOVED
rather than mixed, since the readers would then have read two different packages.
"""
function continue_stage(root::AbstractString, id::AbstractString)
    path = arguments_path(root, id)
    isfile(path) || return nothing
    args = JSON3.read(read(path, String), Dict{String,Any})
    missing = String[]
    for r in get(args, "roles", [])
        r["launch"] = !isfile(result_file(args, r))
        r["launch"] && push!(missing, String(r["key"]))
    end
    write(path, JSON3.write(args))   # compact: nobody reads this file, the session TYPES it
    moved = String(get(args, "commit", "")) != head(root)
    return (missing = missing, total = length(get(args, "roles", [])), moved = moved)
end

"""
    collect_results(root, id, cfg) -> (findings, verdicts, silent, arrived, wrote)

Reads what the agents wrote for the current stage. The arguments are:

- `root` — the package root.
- `id` — the run's id.
- `cfg` — the package's config, which says where its documentation is.

Returns the findings, each with the role that made it; the verdicts, one per verifier role
that answered, as `(verdict, quote)`; the roles that count as having written nothing; how many result
files arrived at all; and how many roles wrote something that counts.

A role counts as SILENT when its file is missing, when it does not parse, when a reader reports no finding
and an empty `checked` list — the brief says an empty `checked` reads as a reader that did nothing, and
this is where that is kept — or when a verifier gives no verdict. A crashed agent and a careful one that
found nothing are the same empty set to a reader, and the design relaunches a silent one once and then
names it.

The LINE is filled in here, never taken from an agent: an agent reports the file, the quote and the node
it read, and a line it also reported would be its count of the text it was shown, not the file's.

The FILE may be corrected here too. A reader given one built page names the file that page is written
in, which is right for the page's own prose and wrong for a sentence the build rendered from a docstring
in the source; where the named file does not hold the quote, the documentation is searched for it, and a
quote exactly one file holds is placed there.
"""
function collect_results(root::AbstractString, id::AbstractString, cfg::Model.Config)
    dir = results_dir(root, id)
    args_path = arguments_path(root, id)
    expected = Dict{String,String}()                            # role key => kind
    if isfile(args_path)
        args = JSON3.read(read(args_path, String), Dict{String,Any})
        for r in get(args, "roles", []); expected[String(r["key"])] = kind_of_role(args, r); end
    end
    findings = Tuple{String,Model.FindingDraft}[]
    verdicts = Dict{String,Tuple{String,String}}()
    wrote = String[]
    arrived = 0
    for (role, kind) in sort(collect(expected))
        path = joinpath(dir, role * ".json")
        isfile(path) || continue
        arrived += 1
        payload = try
            JSON3.read(read(path, String), Dict{String,Any})
        catch
            continue                                   # malformed: silent, as if nothing had arrived
        end
        if kind == "verifier"
            v = String(get(payload, "verdict", ""))
            isempty(v) && continue
            verdicts[role] = (v, String(get(payload, "quote", "")))
            push!(wrote, role)
            continue
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
                found = Texts.reanchor(root, Model.Location(; file, node, text = quote_, line = 0))
                if found.found === Model.Anchor.OUTDATED
                    placed = Texts.place(cfg, root, quote_)
                    placed === nothing || (found = placed)
                end
                push!(locs, found)
            end
            push!(findings, (role, Model.FindingDraft(
                rule = get(f, "rule", nothing) === nothing ? nothing : Symbol(f["rule"]),
                locations = locs, claim = String(get(f, "claim", "")),
                evidence = String(get(f, "evidence", "")), fix = String(get(f, "fix", "")),
                maybe_code = get(f, "maybe_code", false))))
        end
    end
    return (findings, verdicts, setdiff(collect(keys(expected)), wrote), arrived, length(wrote))
end

end # module Agents
