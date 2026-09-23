# The design's §4.3, §6, §10, §12; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Run

`gbg run <instrument>`, `gbg run next`, `gbg run collect`, `gbg run close` and `gbg run abandon`: one
execution of one instrument, a stage at a time.

Each stage is a HANDOFF. Julia cannot launch an agent and only the session can, so `next` writes what
the session needs and exits, the session runs the one fixed driver, and `collect` reads what the agents
wrote. `Runs` refuses any stage but the next, which is what stops a session from grading findings that
were never collected.

Two of the three reader bundles are RENDERED, so a run builds the site itself, from the package's own
`docs/make.jl`, before it launches them, and again before each verifier stage that needs one: what the
build made of a comment or a docstring is visible nowhere else. A reader of the withheld bundle is
launched once per built page, each given that page's text and nothing else. A build that fails leaves
the run where it stood, since a panel launched without its rendered readers is not the panel the rules
were tagged for.

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
const Site = Orchestration.Site

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
- `model` — the careful model its readers run on, or `"session"` for the session's own.
- `sequential` — whether its agents are launched one at a time, so a crash loses one and not the stage.
- `scope` — `:full`, every reader's whole corpus, or `:changed`, only what moved since the last run
  like this one.
- `io` — where the handoff is described.

Exit 0 when it opened, 2 when it did not.

A `:changed` run that has no base READS FULL and says which of the five reasons it is — no closed run of
this reader combination, one that stopped short, an uncommitted record, a moved pin, an edited config —
rather than refusing. The reason is printed because a silent fall back to full is a run whose cost the
session cannot explain, and the owner asked for the cheap run and got the dear one.
"""
function start(root::AbstractString, instrument::Symbol; readers::Symbol = :bound,
               model::AbstractString = "session", sequential::Bool = false, scope::Symbol = :full,
               io::IO = stdout)
    base = ""
    if scope === :changed
        cfg = ConfigIO.read_config(root)
        found = Orchestration.Scope.base(root, instrument, readers, cfg)
        if found === nothing
            why = Orchestration.Scope.why_full(root, instrument, readers, cfg)
            println(io, "run: reading everything — ", why, ".")
            scope = :full
        else
            base = first(found)
            println(io, "run: reading what changed since ", first(base, 8), ", which ", last(found), " read.")
        end
    end
    run = Runs.start(instrument, root; readers, model, sequential, scope, base, io)
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
    passes = run.passes, model = run.model, sequential = run.sequential, scope = run.scope,
    base = run.base, driver = run.driver, already_failing = run.already_failing, dropped = run.dropped,
    unreverted = run.unreverted, kw...)

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
    cfg = ConfigIO.read_config(root)
    # The site is built BEFORE the run moves: a build that failed must leave the run at the stage it was
    # at, rather than at one whose arguments were never written.
    site = ""
    if to === :find || to === :verify || to === :diff
        panel = first(Catalogue.panel(run.instrument, cfg))
        if any(r -> r.site, panel) && !(to === :diff)
            built = Site.build(root, cfg; io)
            built === nothing && return 2
            site = built
        end
    end
    Runs.advance!(root, id, to; io) || return 2
    moved = with(run; stage = to)
    to === :fix && (moved = with(moved; passes = run.passes + 1))
    Runs.save(root, moved)
    to === :close && (println(io, "run: ", id, " is ready to close: gbg run close"); return 0)
    to === :fix && return fix_stage(root, moved, cfg; io)
    (to === :verify || to === :diff) && return verifier_stage(root, moved, cfg, to, site; io)
    roles, extras, site_pages = reader_roles(root, moved, cfg, site; io)
    Agents.write_arguments(root, moved, cfg; roles, extras, site, site_pages, io)
    moved = with(moved; driver = last(Agents.place_driver(root, moved.id)))
    Runs.save(root, moved)                       # the record says which driver these agents went through
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
    Agents.stale_arguments(root, id) && return stale(io, id, stage)
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
    reader_roles(root, run, cfg, site; io = stdout) -> (roles, extras, site_pages)

The agents a reading stage launches, with what each needs beyond its derived reader. The arguments are:

- `root` — the package root.
- `run` — the run, at the stage being launched.
- `cfg` — the package's config.
- `site` — the built site's directory, or `""` where none was built.
- `io` — where the expansion is described.

Returns the roles and their extras, ready for the arguments.

A reader of the WITHHELD bundle is expanded into ONE LAUNCH PER BUILT PAGE, each given that page's text
and nothing else: the bundle is defined as one page alone, and a single agent handed every page at once
would be the reader with siblings that the rules tagged for that bundle were kept away from.
"""
function reader_roles(root::AbstractString, run::Model.Run, cfg::Model.Config, site::AbstractString; io::IO = stdout)
    panel = Catalogue.roles_of(run.instrument, cfg; readers = run.readers)
    roles = Model.AgentRole[]
    extras = Dict{Symbol,Any}()
    built = isempty(site) ? typeof(Site.pages("", cfg, root))() : Site.pages(site, cfg, root)
    units = Site.write_units(Agents.stage_dir(root, run.id), built)
    site_pages = [joinpath(site, p.path) for p in built]
    narrow = run.scope === :changed && !isempty(run.base)
    sets, added = if narrow
        changed = Orchestration.Scope.changed_since(root, run.base)
        Orchestration.Scope.sets_of(cfg, root, changed, run.base), Orchestration.Scope.added_since(root, run.base)
    else
        Dict{Model.FileSet.T,Vector{String}}(), String[]
    end
    skipped = 0
    for r in panel
        if narrow && !Orchestration.Scope.reaches(r, sets)
            skipped += 1
            continue
        end
        if r.site && r.kept_from_code
            isempty(units) && (println(io, "run: `", r.id, "` reads one built page at a time and the site has none; it is not launched"); continue)
            mine = narrow ? filter(u -> Orchestration.Scope.unit_touched(root, cfg, u, sets, added), units) : units
            skipped += length(units) - length(mine)
            for u in mine
                id = Symbol(string(r.id, UNIT_MARK, u.key))
                push!(roles, unit_role(r, id))
                extras[id] = Dict{String,Any}("unit" => u.file, "unit_source" => Site.source_of(root, u.path; cfg))
            end
        else
            push!(roles, r)
        end
    end
    isempty(units) || println(io, "run: ", length(units), " built page(s), one launch each for the reader given a page alone.")
    narrow && println(io, "run: reading what changed since ", first(run.base, 8), "; ", skipped,
                      " launch(es) the change does not reach are not made.")
    return roles, extras, site_pages
end

"What separates a reader's id from the unit it was given, in the key a result file is named by."
const UNIT_MARK = "@"

"The bundle a reader key belongs to: `withheld@guide` is the withheld reader's."
bundle_of(key::Symbol) = Symbol(first(split(String(key), UNIT_MARK)))

# One reader, re-keyed for the unit it is given; everything else about it is the derived reader's.
unit_role(r::Model.AgentRole, id::Symbol) =
    Model.AgentRole(; id, instrument = r.instrument, reads = r.reads, site = r.site,
                    kept_from_code = r.kept_from_code, description = r.description, rules = r.rules,
                    strength = r.strength, cap = r.cap)

"""
    fix_stage(root, run; io = stdout) -> Int

Opens a fix pass: re-anchors every open finding, adds the other copies of what each says, and writes
the workable ones for the session, which edits and commits each through
`gbg docfix commit --finding <id>`. The arguments are:

- `root` — the package root.
- `run` — the run, at its `fix` stage.
- `cfg` — the package's config, which says where its documentation is.
- `io` — where the handoff is described.

Exit 0.

A location that comes back `OUTDATED` is kept and named; the session is not sent there.
"""
function fix_stage(root::AbstractString, run::Model.Run, cfg::Model.Config; io::IO = stdout)
    anchored = Model.Finding[]
    copies = 0
    for f in run.findings
        Runs.closed(run, f.id) && (push!(anchored, f); continue)
        locs = [Runs.reanchor(root, l; since = run.first_commit) for l in f.draft.locations]
        # A finding in the working notes is re-anchored and left alone: extending it to a target page
        # that quotes the same sentence would put a target under a finding that is, by definition,
        # nowhere in one (found in review, 2026-09-23).
        more = f.draft.in_material ? Model.Location[] : other_copies(root, cfg, locs)
        copies += length(more)
        append!(locs, more)
        push!(anchored, Model.Finding(f.id, f.source, f.decider, Model.relocated(f.draft, locs)))
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
            length(todo), " finding(s) to fix, re-anchored",
            copies > 0 ? ", with $copies further copy(s) of what they quote:" : ":")
    for f in todo
        stale = count(l -> l.found === Model.Anchor.OUTDATED, f.draft.locations)
        println(io, "  ", f.id, "  ", f.draft.claim,
                stale > 0 ? "  ($stale location(s) not found again — not to be worked on)" : "")
    end
    waiting = [f for f in Runs.open_findings(run) if Runs.parked(run, f.id)]
    isempty(waiting) || println(io, "  waiting on the owner's answer, not to be worked on: ",
                                join([f.id for f in waiting], ", "))
    println(io, "  the findings: ", relpath(path, root))
    println(io, "  fix each, then: gbg docfix check   (what the guard and the rules make of the edit, committing nothing)")
    println(io, "                  gbg docfix commit --message \"…\" --finding <id>")
    println(io, "  when all are committed: gbg run next")
    println(io, "  check BEFORE each commit, not after the pass: a refused commit costs one edit to")
    println(io, "  understand, and a pass of them costs the pass")
    println(io, "  an edit that changes mathematics is refused by the guard and put to the owner with `gbg ask`; do not make it")
    return 0
end

"""
    other_copies(root, cfg, locations) -> Vector{Model.Location}

Every further place in the documentation that says what these locations say. The arguments are:

- `root` — the package root.
- `cfg` — the package's config, which says where its documentation is.
- `locations` — the finding's own locations, already re-anchored.

Returns the locations to add, none of them one the finding already holds.

A sentence, and above all a FORMULA, is written in more places than the reader who reported it looked
at, and a fix made only where it was reported leaves the rest standing: a fourth copy of a corrected
formula once survived a whole run. So each location's quote is searched for across the documentation,
and so is each expression inside it, which travels between documents without the sentence that carried
it.
"""
function other_copies(root::AbstractString, cfg::Model.Config, locations::Vector{Model.Location})
    have = Set((l.file, l.line) for l in locations)
    out = Model.Location[]
    for l in locations
        l.found === Model.Anchor.OUTDATED && continue
        for needle in vcat([l.text], Texts.formulas(l.text))
            length(strip(needle)) >= 8 || continue     # a fragment shorter than this is not a copy of anything
            for hit in Texts.occurrences(cfg, root, needle)
                Catalogue.target(cfg, hit.file) || continue     # a copy in the working notes is nobody's to fix
                (hit.file, hit.line) in have && continue
                push!(have, (hit.file, hit.line))
                push!(out, hit)
            end
        end
    end
    return out
end

"""
    verifier_stage(root, run, cfg, stage; io = stdout) -> Int

Writes the arguments of a verifier stage: one verifier per workable finding at `verify`, blind to the
diff; one per finding the blind stage called fixed at `diff`, given the fix's diff. The arguments are:

- `root` — the package root.
- `run` — the run.
- `cfg` — the package's config.
- `stage` — `:verify` or `:diff`.
- `site` — the site built for this stage, or `""`.
- `io` — where the handoff is described.

Exit 0.

A verifier is given what the reader that made the finding was given: the withheld reader's finding is
verified on the page alone, the full reader's with the source, a discipline's from its standpoint. A
finding whose reader no longer exists is verified on the full bundle. The blind verifier runs at that
reader's strength; the one reading the diff, a narrower question, at economy.
"""
function verifier_stage(root::AbstractString, run::Model.Run, cfg::Model.Config, stage::Symbol,
                        site::AbstractString; io::IO = stdout)
    panel = first(Catalogue.panel(run.instrument, cfg))
    by_id = Dict(r.id => r for r in panel)
    full = get(by_id, :full, nothing)
    roles = Model.AgentRole[]
    extras = Dict{Symbol,Any}()
    units = isempty(site) ? Dict{String,Any}() :
            Dict(u.key => u for u in Site.write_units(Agents.stage_dir(root, run.id), Site.pages(site, cfg, root)))
    for f in Runs.workable(run)
        if stage === :diff
            k = findlast(x -> x.finding == f.id && x.pass == run.passes, run.fixes)
            (k === nothing || run.fixes[k].blind !== Model.Verdict.FIXED) && continue
        end
        reader = get(by_id, bundle_of(f.source), full)
        reader === nothing && continue
        # A verifier is given what the reader was given. For a reader given ONE PAGE that is the page as
        # it now stands, rebuilt: a page the fix deleted has no verifier, and the finding stays open.
        unit = ""
        if stage === :verify && reader.site && reader.kept_from_code
            key = String(last(split(String(f.source), UNIT_MARK)))
            haskey(units, key) || (println(io, "run: ", f.id, " was found on a page the site no longer has; it stays open"); continue)
            unit = units[key].file
        end
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
        extras[id] = Dict{String,Any}("kind" => "verifier", "finding" => Agents.finding_dict(f),
                                      "finding_id" => f.id, "diff" => diff,
                                      "unit" => unit,
                                      "verdicts" => stage === :verify ? BLIND_VERDICTS : DIFF_VERDICTS)
    end
    Agents.write_arguments(root, run, cfg; roles, extras, site, io)
    isempty(roles) && println(io, "run: no finding needs this stage; collect it to move on")
    return 0
end

# A stage whose arguments predate the wire shape of v2.0.0-rc.13 is neither continued nor collected here:
# read by this version its verdicts would be taken for silence, and a stage is collected once.
function stale(io::IO, id::AbstractString, stage::Symbol)
    println(io, "run: ", id, " is at ", stage, " with arguments written by an older GBGCodingTools, which")
    println(io, "  this version cannot read. Finish the stage with the version that launched it — pin it back,")
    println(io, "  collect, then upgrade — or the owner abandons the run. Nothing was read.")
    return 2
end

"""
    collect(root; io = stdout) -> Int

Reads what the agents of the current stage wrote — findings after a find, verdicts after a verifier
stage, which it grades — and moves the run to its `collect` stage. The arguments are:

- `root` — the package root.
- `io` — where the result goes.

Exit 0 when every role wrote and nothing is open, 1 when findings are open, 2 when a role wrote nothing
or the tree changed under the agents.

A tracked file changed since the launch — a commit, or an edit not yet committed — is exit 2 before
anything is read: the agents read one package and their quotes would be anchored in another, and
nothing distinguishes a finding that moved from one that was fixed. The owner restores the tree or
abandons the run.

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
    since = Agents.launched_at(root, id)
    dirty = Runs.changed_tracked(root)
    if (since !== nothing && since != Agents.head(root)) || !isempty(dirty)
        println(io, "run: the tree changed under the agents of ", launched, "; nothing is collected.")
        isempty(dirty) || println(io, "  changed and not committed: ", join(dirty, ", "))
        since === nothing || since == Agents.head(root) || println(io, "  launched at ", first(since, 8), ", now at ", first(Agents.head(root), 8))
        println(io, "  Restore the tree and collect, or: gbg run abandon")
        return 2
    end
    Agents.stale_arguments(root, id) && return stale(io, id, launched)
    cfg = ConfigIO.read_config(root)
    drafts, verdicts, silent, arrived, wrote = Agents.collect_results(root, id, cfg)
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
    # 1 when something was FOUND, a finding in the working notes included: it is not open — no pass
    # works on it — but it is the owner's to read, and a collect that answered 0 would have hidden it.
    return isempty(Runs.open_findings(run)) && isempty(Runs.in_material(run)) ? 0 : 1
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
    unreverted = copy(run.unreverted)
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
                failed = [c for c in commits if !Runs.revert!(root, c; why = "the verifier believes the code is wrong")]
                append!(unreverted, failed)
                push!(questions, code_question(f, run))
                println(io, "run: ", f.id, isempty(failed) ? " — the fix is reverted and a question stands for the owner" :
                            " — the fix could NOT be reverted (a later fix conflicts), so the edit stays; a question stands for the owner and the run cannot end as evaluated")
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
                failed = [c for c in commits if !Runs.revert!(root, c)]
                append!(unreverted, failed)
                println(io, "run: ", f.id, isempty(failed) ? " — the fix made things worse and is reverted" :
                            " — the fix made things worse and could NOT be reverted (a later fix conflicts); the edit stays and the run cannot end as evaluated")
            end
        end
    end
    return with(run; fixes = fixes, questions = questions, unreverted = unreverted)
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

Close runs two programs before it writes anything.

It BUILDS. A red docs build must not be left on the branch by a run whose whole subject was the
documentation, so close reverts the run's last guarded commit and builds again, and where that is still
red reverts every guarded commit of the run. Each revert goes through the guard like any other edit of
the run. What was reverted is named in the report and its findings stay open, which carries them.

It CLASSIFIES every commit since the run's first commit, and a code change made outside `gbg docfix
commit` ends the run `CANNOT_EVALUATE` with the owner asked to keep or revert it. A review that edited
code behind its own guard has not been reviewed.

What is still open goes to the owner's work queue, one line each, under the heading the end-of-turn hook
does not count.

A RE-BASELINE IS A CLOSING STEP, never a fix pass's (ruled 2026-09-23). Some fixes ADD information that
no rewording returns — binding a term defined nowhere, writing a form out because the compressed one was
not valid code — and those raise the prose-shape numbers a package is held to.

Those numbers are a tracked file, so raising one inside a run is a code change and would end the run
unevaluable; and the ratchet exists so that a raise is deliberate. The run closes first, and the raise
is a SEPARATE commit with its reason: one diff a person reads, rather than a number slipped through
under cover of a fix. Most such findings need no raise at all — of the 28 that tripped on the first real
review, four fifths were the fixer's own verbosity and came back inside budget by writing tersely.
"""
function close_run(root::AbstractString; io::IO = stdout)
    id = open_run(root)
    id === nothing && (println(io, "run: nothing is open here"); return 2)
    # Nothing staged: the close reverts through `revert!`, which refuses over staged work, and a refusal
    # read as "the build was red before" left a breaking fix on the branch (found in review, 2026-09-23).
    staged = something(Git.run(root, "diff", "--cached", "--name-only"), "x")
    isempty(strip(staged)) ||
        (println(io, "run: something is staged; unstage it first (`git restore --staged .`), then close"); return 2)
    Runs.stage_of(root, id) === :close ||
        (println(io, "run: ", id, " is at ", Runs.stage_of(root, id), ", not close"); return 2)
    # Nor anything changed and uncommitted: a revert refuses over it, and a change nobody committed is
    # one the close cannot classify (found in review, 2026-09-23).
    dirty = [p for p in Runs.changed_tracked(root) if !Runs.own_record(p)]
    isempty(dirty) ||
        (println(io, "run: tracked files are changed and not committed: ", join(dirty, ", "), "; commit or discard them, then close"); return 2)
    run = Runs.load(root, id)
    cfg = ConfigIO.read_config(root)

    undone, red, failed = restore_green(root, run, cfg; io)
    unguarded = Runs.unguarded_code(root, run.first_commit)
    stop = isempty(unguarded) ? run.stop : Model.Stop.CANNOT_EVALUATE
    if failed || !isempty(run.unreverted)
        stop = Model.Stop.CANNOT_EVALUATE
        isempty(run.unreverted) || println(io, "run: ", length(run.unreverted), " rejected fix(es) could not be reverted and are still in the tree: ",
                                           join(first.(run.unreverted, 8), ", "), ". The run cannot be evaluated; the owner decides.")
    end
    isempty(undone) || println(io, "run: ", length(undone), " fix(es) were undone to get the build back; the run cannot be evaluated on them.")
    if !isempty(unguarded)
        println(io, "run: code changed outside `gbg docfix commit` since this run started:")
        for c in unguarded; println(io, "  ", c); end
        println(io, "The run ends CANNOT_EVALUATE; keeping or reverting that is the owner's to answer.")
    end

    # Fixes undone are fixes nobody can be said to have verified; a build red for an older reason is
    # not this run's, and the report says so instead.
    stop = isempty(undone) ? stop : Model.Stop.CANNOT_EVALUATE
    closed = with(run; stage = :close, stop = stop)
    queued = stop === Model.Stop.DONE ? queue_leftovers(root, closed) : 0
    dir = Runs.dir(root, id)
    write(joinpath(dir, "report.md"), Render.report(closed, cfg; root, queued, undone = length(undone), red))
    open(joinpath(dir, "run.json"), "w") do f
        GBGCodingTools.JSON3.pretty(f, GBGCodingTools.JSON3.write(Runs.as_dict(closed)))
    end
    rm(joinpath(dir, "run.draft.json"); force = true)
    rm(Agents.scratch_dir(root, id); force = true, recursive = true)   # the agents' files go with the run
    left = Runs.open_findings(closed)
    notes = Runs.in_material(closed)
    println(io, "run: ", id, " closed. ", length(closed.findings), " finding(s), ", length(left), " open",
            isempty(notes) ? "" : ", $(length(notes)) in the working notes for the owner",
            queued > 0 ? "; $queued line(s) went to the work queue." : ".")
    println(io, "  ", relpath(joinpath(dir, "report.md"), root))
    # What the session must commit, named because two files are left dirty by design and only one of
    # them is obvious. The queue is exempt from the fixer's guard while a run is open, so whatever went
    # into it during the run is still uncommitted here.
    queue_dirty = !isempty(something(Git.run(root, "status", "--porcelain", "--", ".claude/WORK_QUEUE.md"), ""))
    println(io, "  Commit .gbg/runs/", id, "/",
            queue_dirty ? " and .claude/WORK_QUEUE.md" : "",
            " — the record and the report",
            queue_dirty ? ", and what this run left on the queue." : ".")
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

A RUN THAT LAUNCHED NOTHING IS DELETED WHOLE, the findings carried into it included [ruled 2026-09-23,
decision 14 of the plan, superseding the ruling of 2026-09-22 that its record made the drop stick]. Such
a run has no standing over findings it never looked at: every finding it holds was carried from the run
that found them, and with its record gone the next start reads past it to that run and carries them
again. Its id is free again.

HOW MANY were dropped is kept, in `dropped`, and a finding a verdict had already CLOSED — fixed and
verified twice, or called no defect — stays on the record with its pass, since the fix stays in the
history and nobody threw it away. Without the count, a record whose open findings are gone and whose
launch count stays says twenty-six readers wrote their files and none of them found anything — of a
run that found a hundred and was stopped. A report is written from the record, so a record that cannot
tell the two apart makes a report that lies.

ITS RECORD AND REPORT ARE COMMITTED, like a closed run's [ruled 2026-09-22, on
[GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/)'s question, after two
abandoned runs left it with no rule to follow]. "Was this package ever reviewed, and
what came of it?" is answered from the repository or not at all, and an attempt that leaves no trace
reads as an attempt that was never made — which is also how an id stays unreusable across a clone, and
how another machine can see that three attempts were made here and why they failed. The argument against
is accumulation, and it is answered where it arises: this verb deletes the run's scratch, which is the
bulky half, and what stays is a record and a page.
"""
function abandon(root::AbstractString; io::IO = stdout)
    id = open_run(root)
    id === nothing && (println(io, "run: nothing is open here"); return 2)
    run = Runs.load(root, id)
    cfg = ConfigIO.read_config(root)
    dir = Runs.dir(root, id)
    # A run that launched nothing is deleted WHOLE, findings carried into it included (ruled 2026-09-23,
    # decision 14, superseding 2026-09-22): it has no standing over findings it never looked at, and
    # with its record gone the next start reads past it to the run that found them, which carries them
    # again. A finding of its own it cannot have — nothing ran — so the second test is a guard, not a case.
    if run.agent_launches == 0 && all(f -> !startswith(f.id, run.id), run.findings)
        rm(Agents.scratch_dir(root, id); force = true, recursive = true)
        rm(dir; force = true, recursive = true)
        println(io, "run: ", id, " abandoned at ", run.stage, " having launched nothing; its record is deleted.")
        if isempty(run.findings)
            println(io, "  It read nothing, carried nothing and changed nothing, so there is nothing to keep")
            println(io, "  and nothing to commit. The id is free again.")
        else
            println(io, "  It read nothing. The ", length(run.findings), " finding(s) it was carrying go back to the run")
            println(io, "  that found them and are carried again by the next start. The id is free again.")
        end
        return 0
    end
    # What the stop throws away is the OPEN findings and the ones in the working notes. A finding fixed
    # and stood behind by two verifiers was not thrown away by anyone: it stays in the record with its
    # pass, since the fix stays in the history, and the report says so rather than "nobody stood behind
    # it" (found in review, 2026-09-23).
    kept = [f for f in run.findings if Runs.closed(run, f.id)]
    stopped = with(run; stage = :close, stop = Model.Stop.OWNER_STOPPED, findings = kept,
                   fixes = [x for x in run.fixes if any(f -> f.id == x.finding, kept)],
                   dropped = length(Runs.open_findings(run)) + length(Runs.in_material(run)))
    write(joinpath(dir, "report.md"), Render.report(stopped, cfg; root))
    open(joinpath(dir, "run.json"), "w") do f
        GBGCodingTools.JSON3.pretty(f, GBGCodingTools.JSON3.write(Runs.as_dict(stopped)))
    end
    rm(joinpath(dir, "run.draft.json"); force = true)
    rm(Agents.scratch_dir(root, id); force = true, recursive = true)
    Runs.write_stage(root, id, length(get(Runs.STAGES, run.instrument, Symbol[])))
    println(io, "run: ", id, " abandoned at ", run.stage, "; ", stopped.dropped, " finding(s) dropped",
            isempty(kept) ? "." : ", $(length(kept)) closed by a verdict and kept on the record.")
    println(io, "  Commit .gbg/runs/", id, "/ — the record and the report. Its agents read this package,")
    println(io, "  and that they were stopped is evidence about it. Its scratch is deleted.")
    return 0
end

"""
    restore_green(root, run, cfg; io = stdout) -> (undone, red, failed)

Puts the documentation back where the run left the build red. The arguments are:

- `root` — the package root.
- `run` — the run being closed.
- `cfg` — the package's config.
- `io` — where the restoring is described.

Returns the commits it reverted, whether the build is still red after the reverting, and whether a
revert failed — which is never read as the build having been red before the run.

The last fix first, because the last fix is what most often broke it and reverting one keeps the rest;
if the build is still red after that, every guarded commit of the run goes, because a run that cannot
say which of its edits broke the build has no business choosing one to keep. A build that fails for a
reason older than the run is not this run's to repair: where reverting everything leaves it red, the
edits are restored and the owner is told the build was already broken.
"""
function restore_green(root::AbstractString, run::Model.Run, cfg::Model.Config; io::IO = stdout)
    Site.build(root, cfg; io = devnull) === nothing || return (String[], false, false)
    mine = Runs.guarded_commits(root, run.first_commit)
    if isempty(mine)
        println(io, "run: the docs build is red and this run committed nothing, so it was red before the run; the owner reads the build")
        return (String[], true, false)
    end
    println(io, "run: the docs build is red at close; the documentation is going back.")
    # A revert that does not apply is a FAILURE, never evidence that the build was red before the run:
    # reading it that way left a breaking fix on the branch (found in review, 2026-09-23).
    if !Runs.revert!(root, first(mine); why = "the docs build was red at close")
        println(io, "run: the last fix, ", first(first(mine), 8), ", could not be reverted; the build is still red and the run cannot be evaluated")
        return (String[], true, true)
    end
    if Site.build(root, cfg; io = devnull) !== nothing
        println(io, "run: reverted the last fix, ", first(first(mine), 8), ", and the build passes again")
        return ([first(mine)], false, false)
    end
    undone = [first(mine)]; failed = false
    for sha in mine[2:end]
        Runs.revert!(root, sha; why = "the docs build was red at close") ? push!(undone, sha) : (failed = true)
    end
    still = Site.build(root, cfg; io = devnull) === nothing
    println(io, failed ? "run: some fixes of this run could not be reverted; the run cannot be evaluated" :
            still ? "run: still red with every fix of this run undone, so the build was broken before it; the owner reads the build" :
            "run: every fix of this run is undone, $(length(undone)) commit(s), and the build passes again")
    return (undone, still, failed)
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
    notes = Runs.in_material(run)
    isempty(open) && isempty(notes) && return 0
    path = joinpath(root, ".claude", "WORK_QUEUE.md")
    text = isfile(path) ? read(path, String) : "# Work queue\n\n"
    lines = String[]
    # What a reader found in the working notes it was given to consult: the owner's, never the fixer's,
    # and listed first because it may be the formula three docstrings copy.
    for f in notes
        l = isempty(f.draft.locations) ? nothing : f.draft.locations[1]
        push!(lines, "- [ ] " * f.id * " IN THE WORKING NOTES, for the owner: " * f.draft.claim *
                     (l === nothing ? "" : " — `" * l.file * "`" * (isempty(l.text) ? "" : " \"" * l.text * "\"")))
    end
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
    o = parse_options(args; valued = ["readers", "model", "scope"])
    root = ConfigIO.require_root("run")
    root === nothing && return 2
    isempty(o.positional) && (println(stderr, "usage: gbg run <instrument> [--readers bound|open|both] [--scope full|changed] [--model <name>] [--sequential] | gbg run next|collect|close|abandon"); return 2)
    what = o.positional[1]
    what == "next" && return next(root)
    what == "collect" && return collect(root)
    what == "close" && return close_run(root)
    what == "abandon" && return abandon(root)
    return start(root, Symbol(replace(what, "-" => "_")); readers = Symbol(get(o.values, "readers", "bound")),
                 scope = Symbol(get(o.values, "scope", "full")),
                 model = get(o.values, "model", "session"), sequential = "sequential" in o.flags)
end
VERBS["run"] = cmd_run

end # module Run
