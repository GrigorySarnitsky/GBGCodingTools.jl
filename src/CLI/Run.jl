# The design's §4.3, §6, §10, §12; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Run

`gbg run <instrument>`, `gbg run next`, `gbg run collect`, `gbg run close` and `gbg run abandon`: one
execution of one instrument, a stage at a time.

Each stage is a HANDOFF. Julia cannot launch an agent and only the session can, so `next` writes what
the session needs and exits, the session runs the one fixed driver, and `collect` reads what the agents
wrote. `Runs` refuses any stage but the next, which is what stops a session from grading findings that
were never collected.

A documentation review's pass is four stages. At `fix` the open findings are re-anchored and written
for the session, which edits and commits each through `gbg docfix commit --finding <id>`. At `verify`
one blind verifier per open finding, given what the reader that found it was given and never the diff,
answers `FIXED`, `NOT_FIXED`, `HIDES_CODE_DEFECT` or `NOT_A_DEFECT`, with a quote. At `diff` a second
verifier reads the diff of each fix called fixed and answers `FIXED`, `LINE_ONLY` or `MADE_WORSE`. The
grade is a program's: a verdict without a quote the current text holds is `NOT_FIXED`; `MADE_WORSE` and
`HIDES_CODE_DEFECT` revert the commit, the second with a question to the owner.

Exit 0 clean, 1 when something was found, 2 when a stage could not be evaluated.
"""
module Run

using ..GBGCodingTools: GBGCodingTools, Catalogue, ConfigIO, Engine, Git, Model, Orchestration, Render, Texts,
                        parse_options, VERBS

const Runs = Orchestration.Runs
const Agents = Orchestration.Agents

"What the blind verifier may answer."
const BLIND_VERDICTS = ["FIXED", "NOT_FIXED", "HIDES_CODE_DEFECT", "NOT_A_DEFECT"]
"What the verifier reading the diff may answer."
const DIFF_VERDICTS = ["FIXED", "LINE_ONLY", "MADE_WORSE"]

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
    start(root, instrument; readers = :bound, io = stdout) -> Int

Opens a run and writes its first stage's arguments. The arguments are:

- `root` — the package root.
- `instrument` — the instrument to run.
- `readers` — which readers the run launches: `:bound`, `:open` or `:both`.
- `io` — where the handoff is described.

Exit 0 when it opened, 2 when it did not.
"""
function start(root::AbstractString, instrument::Symbol; readers::Symbol = :bound, io::IO = stdout)
    run = Runs.start(instrument, root; readers, io)
    run === nothing && return 2
    println(io, "run: opened ", run.id, ".")
    return next(root; io)
end

# The run rebuilt with some fields changed. Every verb writes the record this way, so no field is
# dropped on the way through a stage — the questions were, once.
with(run::Model.Run; kw...) = Model.Run(; id = run.id, instrument = run.instrument, tool_version = run.tool_version,
    first_commit = run.first_commit, budget = run.budget, stage = run.stage, findings = run.findings,
    fixes = run.fixes, questions = run.questions, code_fixes = run.code_fixes,
    agent_launches = run.agent_launches, tokens = run.tokens, stop = run.stop, readers = run.readers,
    passes = run.passes, kw...)

"""
    next(root; io = stdout) -> Int

Moves the open run to its next stage and writes what the session needs to launch it. The arguments are:

- `root` — the package root.
- `io` — where the handoff is described.

Exit 0 when it moved, 2 when it could not.

It writes the arguments and EXITS. The session launches the driver itself, because only a session can;
a verb that waited for agents would be a verb that cannot run. From a collect it chooses: `close` when
no finding can be worked on or the passes are used, else the pass's next stage.

At a stage whose agents were launched and not collected — a run interrupted, and continued by the next
session — it CONTINUES the stage rather than skipping it: the roles that wrote are kept, the rest are
marked to launch again, and it says so. It stops, exit 2, when the tree is at a different commit than
the stage was launched at, which is the one case the owner is waited for.
"""
function next(root::AbstractString; io::IO = stdout)
    id = open_run(root)
    id === nothing && (println(io, "run: nothing is open here"); return 2)
    run = Runs.load(root, id)
    order = get(Runs.STAGES, run.instrument, Symbol[])
    at = Runs.stage_index(root, id)                 # by position: a stage name may repeat
    at == 0 && (println(io, "run: $id is at $(Runs.stage_of(root, id)), which is not a stage of $(run.instrument)"); return 2)
    at == length(order) && (println(io, "run: ", id, " is at ", order[at], ", its last stage; close it"); return 2)
    to = order[at + 1]
    to === :collect && return continue_stage(root, id, order[at]; io)
    if order[at] === :collect
        if isempty(Runs.workable(run))
            to = :close
        elseif to === :fix || to === :close
            to = run.passes < run.budget.fix_passes ? :fix : :close
        end
    end
    Runs.advance!(root, id, to; io) || return 2
    cfg = ConfigIO.read_config(root)
    moved = with(run; stage = to)
    to === :fix && (moved = with(moved; passes = run.passes + 1))
    Runs.save(root, moved)
    to === :close && (println(io, "run: ", id, " is ready to close: gbg run close"); return 0)
    to === :fix && return fix_stage(root, moved; io)
    (to === :verify || to === :diff) && return verifier_stage(root, moved, cfg, to; io)
    Agents.write_arguments(root, moved, cfg; roles = Catalogue.roles_of(run.instrument, cfg; readers = run.readers), io)
    # What no reader of this package can judge is said at every launch, not only in the report: a
    # discipline rule in a package that declares no discipline is a gap the session should see now.
    gaps = vcat(last(Catalogue.panel(run.instrument, cfg)), Catalogue.missing_documents(cfg, root))
    if !isempty(gaps)
        println(io, "run: not judged here —")
        for g in gaps; println(io, "  ", g); end
    end
    return 0
end

"""
    continue_stage(root, id, stage; io = stdout) -> Int

Continues a launched, uncollected stage after an interruption. The arguments are:

- `root` — the package root.
- `id` — the run's id.
- `stage` — the stage the run is at.
- `io` — where the handoff is described.

Exit 0 when there is something to launch again, 2 when every role wrote (collect it), when the tree
moved since the launch, or when the stage was never written.
"""
function continue_stage(root::AbstractString, id::AbstractString, stage::Symbol; io::IO = stdout)
    c = Agents.continue_stage(root, id)
    c === nothing && (println(io, "run: ", id, " is at ", stage, " with no arguments written; abandon it"); return 2)
    if c.moved
        println(io, "run: ", id, " was launched at ", stage, " against another commit, and the tree has moved since.")
        println(io, "  The readers would read a different package than the ones that already wrote. The owner decides:")
        println(io, "  gbg run abandon, and start again on the tree as it is now — or restore the tree and continue.")
        return 2
    end
    if isempty(c.missing)
        println(io, "run: ", id, " is at ", stage, " and every agent wrote; gbg run collect")
        return 2
    end
    println(io, "run: continuing ", id, " at ", stage, ": ", c.total - length(c.missing), " of ", c.total,
            " agent(s) wrote before the interruption; launching again: ", join(c.missing, ", "))
    println(io, "  arguments: ", relpath(Agents.arguments_path(root, id), root))
    println(io, "  then: gbg run collect")
    return 0
end

"""
    fix_stage(root, run; io = stdout) -> Int

Opens a fix pass: re-anchors every open finding and writes the workable ones for the session, which
edits and commits each through `gbg docfix commit --finding <id>`. The arguments are:

- `root` — the package root.
- `run` — the run, at its `fix` stage.
- `io` — where the handoff is described.

Exit 0.

A location that comes back `OUTDATED` is kept and named; the session is not sent there.
"""
function fix_stage(root::AbstractString, run::Model.Run; io::IO = stdout)
    anchored = Model.Finding[]
    for f in run.findings
        Runs.closed(run, f.id) && (push!(anchored, f); continue)
        locs = [Runs.reanchor(root, l; since = run.first_commit) for l in f.draft.locations]
        push!(anchored, Model.Finding(f.id, f.source, f.decider,
              Model.FindingDraft(rule = f.draft.rule, locations = locs, claim = f.draft.claim,
                                 evidence = f.draft.evidence, fix = f.draft.fix, maybe_code = f.draft.maybe_code)))
    end
    run = with(run; findings = anchored)
    Runs.save(root, run)
    todo = Runs.workable(run)
    dir = Agents.stage_dir(root, run.id)
    mkpath(dir)
    path = joinpath(dir, "findings.json")
    open(path, "w") do f
        GBGCodingTools.JSON3.pretty(f, GBGCodingTools.JSON3.write([Agents.finding_dict(x) for x in todo]))
    end
    println(io, "run: ", run.id, " fix pass ", run.passes, " of ", run.budget.fix_passes, "; ",
            length(todo), " finding(s) to fix, re-anchored:")
    for f in todo
        stale = count(l -> l.found === Model.Anchor.OUTDATED, f.draft.locations)
        println(io, "  ", f.id, "  ", f.draft.claim,
                stale > 0 ? "  ($stale location(s) not found again — not to be worked on)" : "")
    end
    waiting = [f for f in Runs.open_findings(run) if Runs.parked(run, f.id)]
    isempty(waiting) || println(io, "  waiting on the owner's answer, not to be worked on: ",
                                join([f.id for f in waiting], ", "))
    println(io, "  the findings: ", relpath(path, root))
    println(io, "  fix each, then: gbg docfix commit --message \"…\" --finding <id>; when all are committed: gbg run next")
    return 0
end

"""
    verifier_stage(root, run, cfg, stage; io = stdout) -> Int

Writes the arguments of a verifier stage: one verifier per workable finding at `verify`, blind to the
diff; one per finding the blind stage called fixed at `diff`, given the fix's diff. The arguments are:

- `root` — the package root.
- `run` — the run.
- `cfg` — the package's config.
- `stage` — `:verify` or `:diff`.
- `io` — where the handoff is described.

Exit 0.

A verifier is given what the reader that made the finding was given: the withheld reader's finding is
verified on the page alone, the full reader's with the source, a discipline's from its standpoint. A
finding whose reader no longer exists is verified on the full bundle. The blind verifier runs at that
reader's strength; the one reading the diff, a narrower question, at economy.
"""
function verifier_stage(root::AbstractString, run::Model.Run, cfg::Model.Config, stage::Symbol; io::IO = stdout)
    panel = first(Catalogue.panel(run.instrument, cfg))
    by_id = Dict(r.id => r for r in panel)
    full = get(by_id, :full, nothing)
    roles = Model.AgentRole[]
    extras = Dict{Symbol,Any}()
    for f in Runs.workable(run)
        if stage === :diff
            k = findlast(x -> x.finding == f.id && x.pass == run.passes, run.fixes)
            (k === nothing || run.fixes[k].blind !== Model.Verdict.FIXED) && continue
        end
        reader = get(by_id, f.source, full)
        reader === nothing && continue
        commits = Runs.fix_commits(root, run.first_commit, f.id)
        diff = stage === :diff && !isempty(commits) ? something(Git.run(root, "show", "--format=", first(commits)), "") : ""
        id = Symbol(string(stage, "-", f.id))
        text = stage === :verify ?
            "You VERIFY one fix, blind: you are not shown the change, only the text as it now stands. " *
            "The finding below was made by the reader `$(f.source)`, and you are given what that reader was given. " *
            "Read the current text at every location and answer FIXED (the defect is gone everywhere), NOT_FIXED, " *
            "HIDES_CODE_DEFECT (the documentation now describes code that looks wrong) or NOT_A_DEFECT (the finding was mistaken). " *
            "Quote the decisive current text; a verdict without a quote counts as NOT_FIXED." :
            "You VERIFY one fix with the diff in front of you. The blind verifier called it FIXED; you check the change itself. " *
            "Answer FIXED, LINE_ONLY (fixed at some locations and not others) or MADE_WORSE (the change broke something the old text had right). " *
            "Quote the decisive words of the diff or of the current text."
        push!(roles, Model.AgentRole(; id, instrument = run.instrument, reads = reader.reads, site = reader.site,
                                     kept_from_code = stage === :verify ? reader.kept_from_code : false,
                                     description = text * " The reader's standpoint: " * reader.description,
                                     rules = f.draft.rule === nothing ? Symbol[] : [f.draft.rule],
                                     strength = stage === :verify ? reader.strength : Model.Strength.ECONOMY, cap = 1))
        extras[id] = Dict{String,Any}("kind" => "verifier", "finding" => Agents.finding_dict(f), "diff" => diff,
                                      "verdicts" => stage === :verify ? BLIND_VERDICTS : DIFF_VERDICTS)
    end
    Agents.write_arguments(root, run, cfg; roles, extras, io)
    isempty(roles) && println(io, "run: no finding needs this stage; collect it to move on")
    return 0
end

"""
    collect(root; io = stdout) -> Int

Reads what the agents of the current stage wrote — findings after a find, verdicts after a verifier
stage, which it grades — and moves the run to its `collect` stage. The arguments are:

- `root` — the package root.
- `io` — where the result goes.

Exit 0 when every role wrote and nothing is open, 1 when findings are open, 2 when a role wrote nothing.

A role that wrote NOTHING is exit 2, not a quiet zero. A crashed agent and a careful one that found
nothing are the same empty set here; the driver relaunches a silent role once, and what is still silent
after that is named here, never read as a clean result. A stage is collected once: the results are read
in whole and the run moves on, so a second collect is refused rather than counting the same findings twice.
"""
function collect(root::AbstractString; io::IO = stdout)
    id = open_run(root)
    id === nothing && (println(io, "run: nothing is open here"); return 2)
    run = Runs.load(root, id)
    order = get(Runs.STAGES, run.instrument, Symbol[])
    at = Runs.stage_index(root, id)
    launched = order[at]
    (at < length(order) && order[at + 1] === :collect) ||
        (println(io, "run: ", id, " is at ", launched, ", which launches nothing to collect; gbg run next"); return 2)
    drafts, verdicts, silent, arrived, wrote = Agents.collect_results(root, id)
    Runs.advance!(root, id, :collect; io) || return 2
    if launched === :verify || launched === :diff
        run = grade(root, run, launched, verdicts; io)
        run = with(run; stage = :collect, agent_launches = run.agent_launches + arrived)
        Runs.save(root, run)
        println(io, "run: collected ", length(verdicts), " verdict(s) from ", wrote, " verifier(s); ",
                length(Runs.open_findings(run)), " finding(s) open.")
    else
        findings = Model.Finding[]
        offset = length(run.findings)
        for (i, (role, d)) in pairs(drafts)
            # The finding names the reader that made it: with readers derived, the id is what says which
            # bundle and which standpoint stood behind the claim.
            push!(findings, Model.Finding(string(id, "-", lpad(offset + i, 3, '0')), Symbol(role),
                                          Model.Decider.AGENT, d))
        end
        run = with(run; stage = :collect, findings = vcat(run.findings, findings),
                   agent_launches = run.agent_launches + arrived)
        Runs.save(root, run)
        println(io, "run: collected ", length(findings), " finding(s) from ", wrote, " reader(s).")
    end
    if !isempty(silent)
        println(io, "run: these wrote nothing, and are not clean; the report names them:")
        for s in silent; println(io, "  ", s); end
        return 2
    end
    return isempty(Runs.open_findings(run)) ? 0 : 1
end

"""
    grade(root, run, stage, verdicts; io = stdout) -> Model.Run

Applies a verifier stage's verdicts. The arguments are:

- `root` — the package root.
- `run` — the run.
- `stage` — `:verify` or `:diff`.
- `verdicts` — each verifier's role key to its `(verdict, quote)`.
- `io` — where a downgraded verdict or a revert is reported.

Returns the run with its fixes, and on one verdict its questions, updated.

Every verdict but `NOT_FIXED` needs a quote the current text holds, or it becomes `NOT_FIXED`.
`MADE_WORSE` reverts the finding's commit; `HIDES_CODE_DEFECT` reverts it and puts a question to the
owner; `NOT_A_DEFECT` closes the finding for this run. A blind verifier that did not answer leaves the
finding open, with `NOT_FIXED` recorded so the report shows it was asked.
"""
function grade(root::AbstractString, run::Model.Run, stage::Symbol, verdicts; io::IO = stdout)
    fixes = copy(run.fixes)
    questions = copy(run.questions)
    allowed = stage === :verify ? BLIND_VERDICTS : DIFF_VERDICTS
    for f in Runs.workable(run)
        key = string(stage, "-", f.id)
        answered = haskey(verdicts, key)
        v, quote_ = answered ? verdicts[key] : ("NOT_FIXED", "")
        v in allowed || (v = "NOT_FIXED")
        if v != "NOT_FIXED" && !quote_holds(root, f, quote_)
            println(io, "run: ", f.id, " — the verifier's quote is not in the text; ", v, " becomes NOT_FIXED")
            v = "NOT_FIXED"
        end
        verdict = getfield(Model.Verdict, Symbol(v))
        commits = Runs.fix_commits(root, run.first_commit, f.id)
        if stage === :verify
            push!(fixes, Model.DocFix(finding = f.id, pass = run.passes,
                                      commit = isempty(commits) ? "" : first(commits), blind = verdict))
            if verdict === Model.Verdict.HIDES_CODE_DEFECT
                isempty(commits) || Runs.revert!(root, first(commits))
                push!(questions, code_question(f, run))
                println(io, "run: ", f.id, " — the fix is reverted and a question stands for the owner")
            end
        else
            answered || continue                             # the diff stage asked only about the fixed
            k = findlast(x -> x.finding == f.id && x.pass == run.passes, fixes)
            k === nothing && continue
            old = fixes[k]
            fixes[k] = Model.DocFix(finding = old.finding, pass = old.pass, commit = old.commit,
                                    formula_edit = old.formula_edit, blind = old.blind, with_diff = verdict,
                                    agreeing_code = old.agreeing_code)
            if verdict === Model.Verdict.MADE_WORSE && !isempty(commits)
                Runs.revert!(root, first(commits))
                println(io, "run: ", f.id, " — the fix made things worse and is reverted")
            end
        end
    end
    return with(run; fixes = fixes, questions = questions)
end

# Whether a verifier's quote is in the current text of a file the finding names.
function quote_holds(root::AbstractString, f::Model.Finding, quote_::AbstractString)
    isempty(strip(quote_)) && return false
    for file in unique(l.file for l in f.draft.locations)
        loc = Texts.reanchor(root, Model.Location(; file, text = String(strip(quote_)), line = 0))
        loc.found === Model.Anchor.OUTDATED || return true
    end
    return false
end

# The question a HIDES_CODE_DEFECT verdict puts: the documentation was made to describe code that looks
# wrong, the edit is reverted, and the owner says which half is right.
function code_question(f::Model.Finding, run::Model.Run)
    Model.Question(id = string(run.id, "-", f.id, "-code"),
                   decision = "Is the code right here, or the documentation?",
                   context = "A fix made the documentation describe what the code does, and the verifier reading the result believes the code itself is wrong. The edit is reverted until you answer.",
                   options = [Model.Option("fix the code", "the code is changed on your direction; the documentation keeps its old text", true),
                              Model.Option("fix the documentation instead", "the reverted edit is made again and stands", false),
                              Model.Option("not a defect", "nothing changes, and the finding is closed", false)],
                   exhibit = f.draft.claim * "\n" * join(["$(l.file): $(l.text)" for l in f.draft.locations], "\n"))
end

"""
    close_run(root; io = stdout) -> Int

Writes the run's record and its report, and ends it. The arguments are:

- `root` — the package root.
- `io` — where the result goes.

Exit 0 when it closed clean, 1 when it closed with findings open, 2 when it could not be evaluated.

Close runs one program before it writes anything: it classifies every commit since the run's first
commit, and a code change made outside `gbg docfix commit` ends the run `CANNOT_EVALUATE` with the owner
asked to keep or revert it. A review that edited code behind its own guard has not been reviewed. What
is still open goes to the owner's work queue, one line each, under the heading the end-of-turn hook does
not count.
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

    closed = with(run; stage = :close, stop = stop)
    queued = stop === Model.Stop.DONE ? queue_leftovers(root, closed) : 0
    dir = Runs.dir(root, id)
    write(joinpath(dir, "report.md"), Render.report(closed, cfg; root, queued))
    open(joinpath(dir, "run.json"), "w") do f
        GBGCodingTools.JSON3.pretty(f, GBGCodingTools.JSON3.write(Runs.as_dict(closed)))
    end
    rm(joinpath(dir, "run.draft.json"); force = true)
    rm(Agents.scratch_dir(root, id); force = true, recursive = true)   # the agents' files go with the run
    left = Runs.open_findings(closed)
    println(io, "run: ", id, " closed. ", length(closed.findings), " finding(s), ", length(left), " open",
            queued > 0 ? "; $queued line(s) went to the work queue." : ".")
    println(io, "  ", relpath(joinpath(dir, "report.md"), root))
    stop === Model.Stop.CANNOT_EVALUATE && return 2
    return isempty(left) ? 0 : 1
end

"""
    abandon(root; io = stdout) -> Int

Ends the open run as `OWNER_STOPPED`, its findings dropped, and writes its record and report so the id
is never reused. The arguments are:

- `root` — the package root.
- `io` — where the result goes.

Exit 0 when a run was abandoned, 2 when none was open.

The findings are DROPPED, not queued: the owner stopping a run is the owner saying its findings are not
wanted, and a leftover line from a run nobody finished would be read as a finding somebody stood behind.
What the run committed through the guard stays; a fix already verified is not undone by stopping.
"""
function abandon(root::AbstractString; io::IO = stdout)
    id = open_run(root)
    id === nothing && (println(io, "run: nothing is open here"); return 2)
    run = Runs.load(root, id)
    cfg = ConfigIO.read_config(root)
    stopped = with(run; stage = :close, stop = Model.Stop.OWNER_STOPPED, findings = Model.Finding[],
                   fixes = Model.DocFix[])
    dir = Runs.dir(root, id)
    write(joinpath(dir, "report.md"), Render.report(stopped, cfg; root))
    open(joinpath(dir, "run.json"), "w") do f
        GBGCodingTools.JSON3.pretty(f, GBGCodingTools.JSON3.write(Runs.as_dict(stopped)))
    end
    rm(joinpath(dir, "run.draft.json"); force = true)
    rm(Agents.scratch_dir(root, id); force = true, recursive = true)
    Runs.write_stage(root, id, length(get(Runs.STAGES, run.instrument, Symbol[])))
    println(io, "run: ", id, " abandoned at ", run.stage, "; ", length(run.findings), " finding(s) dropped.")
    return 0
end

"The heading of the work queue's section the end-of-turn hook does not count."
const QUEUE_HEADING = "## From the last review"

"""
    queue_leftovers(root, run) -> Int

Writes one line per open finding into `.claude/WORK_QUEUE.md`, under the heading the end-of-turn hook
does not count, creating the file or the section where there is none. The arguments are `root`, the
package root, and `run`, the closed run. Returns how many lines went.

Each line names the file, the node and the quote rather than a line number, which is stale by the time
the owner reads it. The section is the last review's and is replaced whole; the owner's own sections
stay as they were.
"""
function queue_leftovers(root::AbstractString, run::Model.Run)
    open = Runs.open_findings(run)
    isempty(open) && return 0
    path = joinpath(root, ".claude", "WORK_QUEUE.md")
    text = isfile(path) ? read(path, String) : "# Work queue\n\n"
    lines = String[]
    for f in open
        where_ = ""
        if !isempty(f.draft.locations)
            l = f.draft.locations[1]
            where_ = " — `" * l.file * "`" * (isempty(l.node) ? "" : " (" * l.node * ")") *
                     (isempty(l.text) ? "" : " \"" * l.text * "\"")
        end
        push!(lines, "- [ ] " * f.id * " " * f.draft.claim * where_ *
                     (Runs.parked(run, f.id) ? " — waits on the owner's answer to the run's question" : ""))
    end
    block = join(lines, "\n") * "\n"
    if occursin(QUEUE_HEADING, text)
        head, rest = split(text, QUEUE_HEADING; limit = 2)
        m = match(r"\n## ", rest)
        tail = m === nothing ? "" : rest[m.offset:end]
        text = head * QUEUE_HEADING * "\n\n" * block * tail
    else
        text = rstrip(text) * "\n\n" * QUEUE_HEADING * "\n\n" * block
    end
    mkpath(dirname(path))
    write(path, text)
    return length(lines)
end

function cmd_run(args)
    o = parse_options(args; valued = ["readers"])
    root = ConfigIO.require_root("run")
    root === nothing && return 2
    isempty(o.positional) && (println(stderr, "usage: gbg run <instrument> [--readers bound|open|both] | gbg run next|collect|close|abandon"); return 2)
    what = o.positional[1]
    what == "next" && return next(root)
    what == "collect" && return collect(root)
    what == "close" && return close_run(root)
    what == "abandon" && return abandon(root)
    return start(root, Symbol(replace(what, "-" => "_")); readers = Symbol(get(o.values, "readers", "bound")))
end
VERBS["run"] = cmd_run

end # module Run
