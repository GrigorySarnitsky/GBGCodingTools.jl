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

A documentation review's pass is two stages. At `fix` the open findings are re-anchored and written
for the session, which commits each through `gbg docfix commit --finding <id>` or parks it. At `verify`
one verifier per UNIT holding open findings — a built page, an example's source, a file — is given
those findings, the text as it now stands and the diff of the pass, and answers each with a verdict and
a quote (one verifier with the diff, and one pass, ruled 2026-09-26 on the measurements of
[GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/)). The grade is a
program's: a verdict without a quote the current text holds is
`NOT_FIXED`, with the demotion recorded; `MADE_WORSE` and `HIDES_CODE_DEFECT` revert the commit, the
second with a question to the owner.

Exit 0 clean, 1 when something was found, 2 when a stage could not be evaluated.
"""
module Run

using ..GBGCodingTools: GBGCodingTools, Catalogue, ConfigIO, Docfix, Engine, Git, Model, Orchestration, Render, Texts,
                        parse_options, VERBS

const Runs = Orchestration.Runs
const Agents = Orchestration.Agents
const Site = Orchestration.Site

"What a verifier may answer about one finding."
const VERDICTS = ["FIXED", "NOT_FIXED", "LINE_ONLY", "MADE_WORSE", "HIDES_CODE_DEFECT", "NOT_A_DEFECT"]
"How many findings one verifier is handed at most; a unit with more gets several verifiers."
const VERIFY_CAP = 10

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
    start(root, instrument; readers = :bound, model = "session", sequential = false,
          scope = :full, io = stdout) -> Int

Opens a run and writes its first stage's arguments.

# Arguments

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
# dropped on the way through a stage — the questions were, once, and `rulebook` was, from the day it was
# added until this read the fields off the type instead of a list written by hand (2026-09-24).
with(run::Model.Run; kw...) =
    Model.Run(; (f => (haskey(kw, f) ? kw[f] : getfield(run, f)) for f in fieldnames(Model.Run))...)

"""
    next(root; io = stdout) -> Int

Moves the open run to its next stage and writes what the session needs to launch it.

# Arguments

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
    # Verifiers read the tree as committed: launched over an uncommitted edit they judge text that is in
    # no commit, and the collect then refuses the dirty tree with no way forward (review, 2026-09-23).
    if order[at] === :fix || to === :verify
        dirty = [p for p in Runs.changed_tracked(root) if !Runs.own_record(p)]
        isempty(dirty) || (println(io, "run: tracked files are changed and not committed: ", join(dirty, ", "),
                                    ". Commit each fix with `gbg docfix commit --finding <id>`, or discard it, then gbg run next"); return 2)
    end
    # A fix stage is left when each finding it works on is committed or parked, as the stage's own text
    # says: SS left one with 98 of 100 untouched (2026-10-16), and with one pass in the budget its verifiers
    # would have judged unchanged text and closed the run with all 98 on the owner's queue. Two kinds are
    # exempt: a finding none of whose places was found again when the stage opened, whose text was gone
    # before the pass; and one the owner answered "fix it on my ruling", which has been to him already and
    # cannot be parked again — named here, so that it is not left in silence.
    if order[at] === :fix
        unworked = [f for f in Runs.workable(run)
                    if isempty(Runs.pass_commits(root, pass_start(run), run, f.id)) &&
                       !(!isempty(f.draft.locations) && all(l -> l.found === Model.Anchor.OUTDATED, f.draft.locations))]
        ruled = [f for f in unworked if f.id in run.ruled]
        untouched = [f for f in unworked if !(f.id in run.ruled)]
        if !isempty(untouched)
            println(io, "run: ", length(untouched), " finding(s) of this pass are neither committed nor parked: ",
                    join([f.id for f in untouched], ", "), ".")
            println(io, "  For each: fix it and `gbg docfix commit --message \"…\" --finding <id>` (a change that fixes")
            println(io, "  several names them all: `--finding <id>,<id>`); or, where a fix already committed fixed it,")
            println(io, "  `gbg run covered <id> --by <the finding that commit names>`; where a commit made outside")
            println(io, "  `gbg docfix commit` fixed it, `gbg run covered <id> --by-commit <sha>`, which the guard reads first;")
            println(io, "  or `gbg run park <id> --why \"…\"` where only the owner may make the fix or you believe it is")
            println(io, "  no defect. Then gbg run next.")
            return 2
        end
        isempty(ruled) || println(io, "run: answered \"fix it on my ruling\" and not fixed this pass, so judged as they stand: ",
                                  join([f.id for f in ruled], ", "))
    end
    if order[at] === :collect
        if isempty(Runs.workable(run))
            to = :close
        elseif to === :fix || to === :close
            to = run.passes < run.budget.fix_passes ? :fix : :close
        end
    end
    # A fix stage that committed nothing has nothing to verify: verifiers launched over unchanged text
    # answer by variance (a fifth of PF's verdicts moved that way, 2026-09-24) and cost a stage. The run
    # closes instead, and what is open goes to the owner's queue.
    if order[at] === :fix && to === :verify && isempty(Runs.guarded_commits(root, pass_start(run); run))
        println(io, "run: pass ", run.passes, " committed no fix, so there is nothing to verify; the run closes with what is open on the owner's queue.")
        to = :close
    end
    cfg = ConfigIO.read_config(root)
    # The site is built BEFORE the run moves: a build that failed must leave the run at the stage it was
    # at, rather than at one whose arguments were never written.
    site = ""
    if to === :find || to === :verify
        panel = first(Catalogue.panel(run.instrument, cfg))
        if any(r -> r.site, panel)
            # The build's output is kept, so a red build after a fix stage can name the pass's commits
            # that touched the files it complains about (ruled 2026-09-26: nine dead references once
            # surfaced together after eighty commits, with no word on which made them).
            log = IOBuffer()
            built = Site.build(root, cfg; io = log)
            print(io, String(take!(copy(log))))
            if built === nothing
                order[at] === :fix && blame_build(root, run, String(take!(log)); io)
                return 2
            end
            site = built
        end
    end
    Runs.advance!(root, id, to; io) || return 2
    moved = with(run; stage = to)
    # the pass's fixes are the commits after this point, not every commit since the run began: a pass
    # that committed nothing showed the previous pass's commit on every finding (found by PF, 2026-09-24)
    to === :fix && (moved = with(moved; passes = run.passes + 1, pass_since = Runs.head_commit(root)))
    Runs.save(root, moved)
    to === :close && (println(io, "run: ", id, " is ready to close: gbg run close"); return 0)
    to === :fix && return fix_stage(root, moved, cfg; io)
    to === :verify && return verifier_stage(root, moved, cfg, site; io)
    roles, extras, site_pages = reader_roles(root, moved, cfg, site; io)
    # The sha comes from the placement write_arguments made, WITH the arguments spliced in. A second
    # placement here, passing none, rewrote the driver without them: every fresh find stage handed the
    # session a driver whose `args` was undefined (found verifying the review's fixes, 2026-09-27).
    Agents.write_arguments(root, moved, cfg; roles, extras, site, site_pages, io)
    moved = with(moved; driver = Agents.driver_sha(root, moved.id))
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

Continues a launched, uncollected stage after an interruption.

# Arguments

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
    println(io, "  arguments: ", relpath(Agents.arguments_path(root, id), root), "  (spliced into the driver: pass no args)")
    println(io, "  driver:    ", relpath(c.driver, root))
    println(io, "  launch it: Workflow({scriptPath: \"", relpath(c.driver, root), "\"})")
    println(io, "  then: gbg run collect")
    return 0
end

"""
    reader_roles(root, run, cfg, site; io = stdout) -> (roles, extras, site_pages)

The agents a reading stage launches, with what each needs beyond its derived reader.

# Arguments

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
            # A rule judged on a Literate example's SOURCE goes to a reader given that file alone; a built
            # page cannot show a comment's habits, and an example with no page was read by nobody (found
            # in review, 2026-09-23). The rest are the page's.
            on_page = filter(!on_source, r.rules)
            of_source = filter(on_source, r.rules)
            if isempty(r.rules) || !isempty(on_page)
                if isempty(units)
                    println(io, "run: `", r.id, "` reads one built page at a time and the site has none; it is not launched")
                else
                    mine = narrow ? filter(u -> Orchestration.Scope.unit_touched(root, cfg, u, sets, added), units) : units
                    skipped += length(units) - length(mine)
                    for u in mine
                        src = Site.source_of(root, u.path; cfg)
                        # A switch naming this page's file turns its rule off for this launch.
                        rules = filter(x -> Engine.Checks.applies(cfg, x; file = src), on_page)
                        !isempty(r.rules) && isempty(rules) && (skipped += 1; continue)
                        id = Symbol(string(r.id, UNIT_MARK, u.key))
                        push!(roles, unit_role(r, id; rules))
                        extras[id] = Dict{String,Any}("unit" => u.file, "unit_source" => src)
                    end
                end
            end
            if !isempty(of_source)
                srcs = source_units(cfg, root)
                touched(u) = u.path in get(sets, Model.FileSet.LITERATE, String[]) || u.path in added
                mine = narrow ? filter(touched, srcs) : srcs
                skipped += length(srcs) - length(mine)
                for u in mine
                    rules = filter(x -> Engine.Checks.applies(cfg, x; file = u.path), of_source)
                    isempty(rules) && (skipped += 1; continue)
                    id = Symbol(string(r.id, UNIT_MARK, u.key))
                    push!(roles, unit_role(r, id; rules))
                    extras[id] = Dict{String,Any}("unit" => u.file, "unit_source" => u.path, "source_unit" => true)
                end
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

# The commit a pass's fixes are counted from: where the pass began, or the run's first commit for a
# record written before that was recorded.
pass_start(run::Model.Run) = isempty(run.pass_since) ? run.first_commit : run.pass_since

"""
    blame_build(root, run, log; io = stdout) -> Vector{String}

Names the pass's commits that touched the files a failed docs build complains about.

# Arguments

- `root` — the package root.
- `run` — the run.
- `log` — the build's output.
- `io` — where the names are written.

Returns the lines written, empty where the log names no file the pass touched.

The build runs once per pass and is the one judge of a cross-reference; what it lacked was a pointer
from its complaint back to the commit that made it.
"""
function blame_build(root::AbstractString, run::Model.Run, log::AbstractString; io::IO = stdout)
    named = Set{String}(replace(m.match, '\\' => '/') for m in eachmatch(r"(?:docs|src|ext|examples)/[A-Za-z0-9_./-]+\.(?:md|jl)", log))
    isempty(named) && return String[]
    out = String[]
    for sha in reverse(Runs.guarded_commits(root, pass_start(run); run))
        files = something(Git.run(root, "show", "--format=", "--name-only", sha), "")
        hit = [f for f in split(files, '\n') if !isempty(f) && any(n -> endswith(n, f) || endswith(f, n), named)]
        isempty(hit) && continue
        fids = Runs.fixed_by(root, run, sha)
        push!(out, first(sha, 8) * "  " * (isempty(fids) ? "no finding" : join(fids, ",")) * "  " * join(hit, ", "))
    end
    if !isempty(out)
        println(io, "run: the build complains about files these commits of pass ", run.passes, " touched — fix through `gbg docfix commit --finding <id>`:")
        for l in out; println(io, "  ", l); end
    end
    return out
end

"What separates a reader's id from the unit it was given, in the key a result file is named by."
const UNIT_MARK = "@"

"The bundle a reader key belongs to: `withheld@guide` is the withheld reader's."
bundle_of(key::Symbol) = Symbol(first(split(String(key), UNIT_MARK)))

# One reader, re-keyed for the unit it is given, with the rules that apply to that unit; everything else
# about it is the derived reader's.
unit_role(r::Model.AgentRole, id::Symbol; rules::Vector{Symbol} = r.rules) =
    Model.AgentRole(; id, instrument = r.instrument, reads = r.reads, site = r.site,
                    kept_from_code = r.kept_from_code, description = r.description, rules,
                    strength = r.strength, cap = r.cap)

# Whether a rule is judged on a Literate example's source file rather than on a page: it runs over the
# examples and nothing else. `RULE.DOC.LITERATE` says so in its statement; its sibling, judged on the
# built page, needs the site and never reaches the reader given nothing.
function on_source(id::Symbol)
    r = Catalogue.rule(id)
    return r !== nothing && r.filesets == [Model.FileSet.LITERATE]
end

"The key prefix of a unit that is a Literate example's source file rather than a built page."
const SOURCE_UNIT = "source-"

# Every Literate example as a unit of its own: the file itself, which is where the rule is judged.
# The key carries a digest of the path, so `a-b.jl` and `a.b.jl` are two units, not one result file.
source_units(cfg::Model.Config, root::AbstractString) =
    [(path = f, key = SOURCE_UNIT * replace(f, r"[^A-Za-z0-9_]+" => "-") * "-" * first(bytes2hex(GBGCodingTools.SHA.sha1(f)), 6),
      file = joinpath(root, f))
     for f in Texts.files(cfg, root, Model.FileSet.LITERATE)]

"""
    fix_stage(root, run, cfg; io = stdout, reanchor = true) -> Int

Opens a fix pass: re-anchors every open finding, adds the other copies of what each says, and writes
the workable ones for the session, which edits and commits each through
`gbg docfix commit --finding <id>`.

# Arguments

- `root` — the package root.
- `run` — the run, at its `fix` stage.
- `cfg` — the package's config, which says where its documentation is.
- `io` — where the handoff is described.
- `reanchor` — whether the findings are found again; `false` keeps the places found when the pass
  opened, for a pass resumed by `gbg run back`, whose own commits would otherwise make a finding they
  changed in passing read as gone before the pass, and exempt.

Exit 0.

A location that comes back `OUTDATED` is kept and named; the session is not sent there.
"""
function fix_stage(root::AbstractString, run::Model.Run, cfg::Model.Config; io::IO = stdout, reanchor::Bool = true)
    anchored = Model.Finding[]
    copies = 0
    for f in (reanchor ? run.findings : Model.Finding[])
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
    reanchor && (run = with(run; findings = anchored); Runs.save(root, run))
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
    println(io, "                  gbg docfix commit --message \"…\" --finding <id>   (one change fixing several: --finding <id>,<id>)")
    println(io, "  one whose fix only the owner may make (the config, code, a formula), or that you believe is no defect:")
    println(io, "                  gbg run park <id> --why \"…\"")
    println(io, "  when all are committed or parked: gbg run next   (it refuses while one is neither)")
    println(io, "  check BEFORE each commit, not after the pass: a refused commit costs one edit to")
    println(io, "  understand, and a pass of them costs the pass")
    println(io, "  an edit that changes mathematics is refused by the guard and put to the owner with `gbg ask`; do not make it")
    return 0
end

"""
    other_copies(root, cfg, locations) -> Vector{Model.Location}

Every further place in the documentation that says what these locations say.

# Arguments

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
    verifier_stage(root, run, cfg, site; io = stdout) -> Int

Writes the verify stage's arguments: one verifier per UNIT that holds open findings, each given those
findings, the unit as it now stands, and the diff of the pass.

# Arguments

- `root` — the package root.
- `run` — the run.
- `cfg` — the package's config.
- `site` — the site built for this stage, or `""`.
- `io` — where the handoff is described.

Exit 0.

A unit is what the reader that made the finding was given: the built page, for a finding of the reader
given one page alone; the example's source file, for one made on it; and otherwise the file the finding
names first, with the reader's surfaces. A unit with more than [`VERIFY_CAP`](@ref) open findings gets
several verifiers. The verifier sees the diff: one per finding, blind to the change, was wrong on 47% of
its not-fixed verdicts on GBGPeriodicFields and paid the same fixed context 187 times (ruled 2026-09-26).
"""
function verifier_stage(root::AbstractString, run::Model.Run, cfg::Model.Config, site::AbstractString; io::IO = stdout)
    panel = first(Catalogue.panel(run.instrument, cfg))
    by_id = Dict(r.id => r for r in panel)
    full = get(by_id, :full, nothing)
    roles = Model.AgentRole[]
    extras = Dict{Symbol,Any}()
    built = isempty(site) ? typeof(Site.pages("", cfg, root))() : Site.pages(site, cfg, root)
    units = Dict{String,Any}(u.key => u for u in Site.write_units(Agents.stage_dir(root, run.id), built))
    for u in source_units(cfg, root); units[u.key] = u; end
    site_pages = [joinpath(site, p.path) for p in built]
    groups = Dict{String,Vector{Model.Finding}}()
    order = String[]
    for f in Runs.workable(run)
        reader = get(by_id, bundle_of(f.source), full)
        reader === nothing && continue
        key = if reader.site && reader.kept_from_code
            k = String(last(split(String(f.source), UNIT_MARK)))
            # A page the fix deleted has no verifier, and the finding stays open.
            haskey(units, k) || (println(io, "run: ", f.id, " was found on a page the site no longer has; it stays open"); continue)
            "unit-" * k
        elseif isempty(f.draft.locations)
            "file-none"
        else
            "file-" * replace(f.draft.locations[1].file, r"[^A-Za-z0-9_]+" => "-")
        end
        haskey(groups, key) || (groups[key] = Model.Finding[]; push!(order, key))
        push!(groups[key], f)
    end
    for key in order
        fs = groups[key]
        chunks = [fs[i:min(i + VERIFY_CAP - 1, end)] for i in 1:VERIFY_CAP:length(fs)]
        for (n, chunk) in enumerate(chunks)
            f1 = first(chunk)
            reader = get(by_id, bundle_of(f1.source), full)
            id = Symbol(string("verify-", key, length(chunks) > 1 ? "-$n" : ""))
            unit = startswith(key, "unit-") ? String(units[key[6:end]].file) : ""
            of_source = startswith(key, "unit-" * SOURCE_UNIT)
            diff = fix_diff(root, run, chunk)
            text = "You VERIFY the fixes made for the findings in the file named below, " *
                   (length(chunk) == 1 ? "one finding" : "$(length(chunk)) findings") *
                   " of one place, with the text as it now stands and the diff of the change in front of you. " *
                   (isempty(unit) ? "" : "The findings were made by the reader `$(f1.source)` from one unit alone, and that unit as it now stands is what you judge the text on. ") *
                   "For EACH finding, by its id, answer FIXED (the defect is gone everywhere the finding names), NOT_FIXED, " *
                   "LINE_ONLY (gone at some locations and not others), MADE_WORSE (the change broke something the old text had right), " *
                   "HIDES_CODE_DEFECT (the documentation now describes code that looks wrong) or NOT_A_DEFECT (the finding was mistaken). " *
                   (isempty(diff) ? "This run committed no change for these, so there is no diff: judge the current text. " : "") *
                   "Quote, for each, the decisive words of the CURRENT text, as ONE verbatim span — the diff is read, never quoted; a verdict whose quote is not in the text counts as NOT_FIXED."
            # Never kept from the code, whoever found them: a verifier reads the diff, and a diff of a
            # docstring is the source's (ruled 2026-09-26). The driver has no withheld paragraph for one.
            push!(roles, Model.AgentRole(; id, instrument = run.instrument, reads = reader.reads, site = reader.site,
                                         kept_from_code = false,
                                         description = text * " The reader's standpoint: " * reader.description,
                                         rules = unique(Symbol[f.draft.rule for f in chunk if f.draft.rule !== nothing]),
                                         strength = reader.strength, cap = length(chunk)))
            extras[id] = Dict{String,Any}("kind" => "verifier", "finding" => [Agents.finding_dict(f) for f in chunk],
                                          "finding_id" => join([f.id for f in chunk], ", "), "diff" => diff,
                                          "unit" => unit, "source_unit" => of_source, "verdicts" => VERDICTS)
        end
    end
    Agents.write_arguments(root, run, cfg; roles, extras, site, site_pages, io)
    isempty(roles) && println(io, "run: no finding needs this stage; collect it to move on")
    return 0
end

"""
    fix_diff(root, run, fs) -> String

The change a verifier is shown for the findings of one unit.

# Arguments

- `root` — the package root.
- `run` — the run.
- `fs` — the findings.

Returns the diff text, empty where the pass has committed nothing at all.

Every commit of this pass that names one of the findings, oldest first, and not only the newest: a fix
made in two commits was shown half of it. Findings with no commit of their own were fixed, if at all, by
another's — a copy or a duplicate — and are shown every fix of the pass, with a line saying so; until
2026-09-24 the verifier was told it had a diff and given none (found in review, 2026-09-23).
"""
function fix_diff(root::AbstractString, run::Model.Run, fs::AbstractVector{Model.Finding})
    since = pass_start(run)
    all = Runs.guarded_commits(root, since; run)                  # newest first
    mine = Set{String}(c for f in fs for c in Runs.pass_commits(root, since, run, f.id))
    named = [c for c in all if c in mine]
    shas = isempty(named) ? all : named
    isempty(shas) && return ""
    body = something(Git.run(root, "show", "--format=commit %H%n%n%B", reverse(shas)...), "")
    isempty(named) || return body
    return "# No commit names these findings. Below is every fix this pass has made: the defect may have\n" *
           "# been fixed by another finding's change, or not at all.\n\n" * body
end

# A stage whose arguments predate the wire shape of v2.0.0-rc.13 is neither continued nor collected here:
# read by this version its verdicts would be taken for silence, and a stage is collected once.
function stale(io::IO, id::AbstractString, stage::Symbol)
    println(io, "run: ", id, " is at ", stage, " with arguments written by an older GBGCodingTools, which")
    println(io, "  this version cannot read. Finish the stage with the version that launched it — pin it back,")
    println(io, "  collect, then upgrade — or the owner abandons the run. Nothing was read.")
    return 2
end

# How many roles this stage's arguments hold: each was launched at least once.
function stage_roles(root, id)
    path = Agents.arguments_path(root, id)
    isfile(path) || return 0
    return length(get(GBGCodingTools.JSON3.read(read(path, String), Dict{String,Any}), "roles", []))
end

"""
    collect(root; io = stdout) -> Int

Reads what the agents of the current stage wrote — findings after a find, verdicts after a verifier
stage, which it grades — and moves the run to its `collect` stage.

# Arguments

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
    # the run's own records and the queue are the session's, and an answer to an older run's question
    # amends that run's record: neither is the tree the agents read (review, 2026-09-23)
    dirty = [p for p in Runs.changed_tracked(root) if !Runs.own_record(p)]
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
    # A role that wrote nothing readable is launched ONCE more before the stage moves on, and then named:
    # a silent reader is not a clean one (found in review, 2026-09-23: the stage moved on at once, and
    # the report said every reader wrote).
    # Once per STAGE — verifier keys repeat across passes — and a relaunched agent that then writes is
    # not silent (both found in review, 2026-09-23). The relaunched set lives in the stage's own scratch.
    mark = joinpath(Agents.stage_dir(root, id), "relaunched-" * string(run.passes))
    again = isfile(mark) ? String[strip(l) for l in eachline(mark) if !isempty(strip(l))] : String[]
    fresh = setdiff(silent, again)
    if !isempty(fresh)
        for k in fresh; rm(joinpath(Agents.results_dir(root, id), k * ".json"); force = true); end
        mkpath(dirname(mark)); write(mark, join(vcat(again, fresh), '\n'))
        println(io, "run: ", length(fresh), " agent(s) wrote nothing readable: ", join(fresh, ", "), ".")
        println(io, "  Launch them once more — gbg run next marks exactly them — then collect again.")
        return 2
    end
    # every role of the stage was launched at least once, and the relaunched ones once more
    n_launched = stage_roles(root, id) + length(again)
    Runs.advance!(root, id, :collect; io) || return 2
    if launched === :verify
        run = grade(root, run, verdicts; cfg, io)
        run = with(run; stage = :collect, agent_launches = run.agent_launches + n_launched,
                   silent = unique(vcat(run.silent, silent)))
        Runs.save(root, run)
        println(io, "run: pass ", run.passes, ": collected ", length(verdicts), " verdict(s) from ", wrote, " verifier(s); ",
                length(Runs.open_findings(run)), " finding(s) open.")
    else
        findings = Model.Finding[]
        offset = length(run.findings)
        # A finding under a rule the package switched off for every file it names is the switch's, not
        # the fixer's: a reader is not told which files a switch names (found in review, 2026-09-23).
        off = [x for x in drafts if switched_off(cfg, last(x))]
        isempty(off) || println(io, "run: ", length(off), " finding(s) under a rule switched off for the files they name are dropped")
        drafts = merge_same(setdiff(drafts, off), cfg)
        for (i, (role, d)) in pairs(drafts)
            # The finding names the reader that made it: with readers derived, the id is what says which
            # bundle and which standpoint stood behind the claim.
            push!(findings, Model.Finding(string(id, "-", lpad(offset + i, 3, '0')), Symbol(role),
                                          Model.Decider.AGENT, d))
        end
        run = with(run; stage = :collect, findings = vcat(run.findings, findings),
                   agent_launches = run.agent_launches + n_launched, silent = unique(vcat(run.silent, silent)))
        Runs.save(root, run)
        println(io, "run: collected ", length(findings), " finding(s) from ", wrote, " reader(s).")
    end
    if !isempty(silent)
        println(io, "run: these wrote nothing even launched again, and are not clean; the report names them:")
        for s in silent; println(io, "  ", s); end
        launched === :verify && println(io, "  The findings they were to judge are graded NOT_FIXED and stay open; the run goes on.")
        return 2                                  # a role that wrote NOTHING is exit 2, never a quiet zero
    end
    # 1 when something was FOUND, a finding in the working notes included: it is not open — no pass
    # works on it — but it is the owner's to read, and a collect that answered 0 would have hidden it.
    return isempty(Runs.open_findings(run)) && isempty(Runs.in_material(run)) ? 0 : 1
end

# Whether a draft's rule is switched off for every file the draft names, or for the whole package.
switched_off(cfg::Model.Config, d::Model.FindingDraft) =
    d.rule !== nothing && !isempty(d.locations) &&
    all(l -> !Engine.Checks.applies(cfg, d.rule; file = l.file), d.locations)

"""
    merge_same(drafts, cfg) -> Vector{Tuple{String,Model.FindingDraft}}

One finding per defect: two drafts are merged into the first when they are under the same rule and
quote the same words at the same place — and, under no rule, make the same claim. The arguments are
`drafts`, each with the reader that made it, and `cfg`, the package's config, which says whether the
merged locations are working notes. Returns the merged list, in the order the first of each group came.

Several readers see the same sentence, and each filed it: one defect became three findings, three
verifiers and one fix commit, which left two verifiers with no change of their own to read (found in
review, 2026-09-23). What merges is narrow on purpose. A shared LINE is not a shared defect: a paragraph
is often one line, one reader's two classes under one rule share a site, and two open readers can say
two different things of one sentence — merging those lost the second fix (found in review,
2026-09-24). The merged finding keeps every location, and the other readers' claims, evidence and
fixes in its evidence.
"""
function merge_same(drafts::AbstractVector, cfg::Model.Config)
    out = Tuple{String,Model.FindingDraft}[]
    quoted(d) = Set((l.file, l.line, Texts.flatten(l.text)) for l in d.locations
                    if l.found !== Model.Anchor.OUTDATED && !isempty(strip(l.text)))
    same(a, b) = a.rule == b.rule && !isempty(intersect(quoted(a), quoted(b))) &&
                 (a.rule !== nothing || Texts.flatten(a.claim) == Texts.flatten(b.claim))
    for (role, d) in drafts
        k = findfirst(x -> same(last(x), d), out)
        if k === nothing
            push!(out, (String(role), d))
            continue
        end
        r0, d0 = out[k]
        locs = copy(d0.locations)
        for l in d.locations
            any(m -> (m.file, m.line, m.text) == (l.file, l.line, l.text), locs) || push!(locs, l)
        end
        also = "Also reported by `" * String(role) * "`: " * d.claim *
               (isempty(d.evidence) ? "" : " Evidence: " * d.evidence) *
               (isempty(d.fix) ? "" : " Fix proposed: " * d.fix)
        out[k] = (r0, Model.FindingDraft(rule = d0.rule, locations = locs, claim = d0.claim,
                                         evidence = isempty(d0.evidence) ? also : d0.evidence * "\n\n" * also,
                                         fix = d0.fix, maybe_code = d0.maybe_code || d.maybe_code,
                                         in_material = Catalogue.in_material(cfg, locs)))
    end
    return out
end

"""
    grade(root, run, verdicts; cfg, io = stdout) -> Model.Run

Applies a verify stage's verdicts.

# Arguments

- `root` — the package root.
- `run` — the run.
- `verdicts` — each finding's id to its `(verdict, quote)`.
- `cfg` — the package's config, which the language rules read when a question is put.
- `io` — where a downgraded verdict, a revert or a question's failed rule is reported.

Returns the run with its fixes, and on one verdict its questions, updated.

A verdict a program cannot ground is `NOT_FIXED`, and the record says why: a quote not in the text, a
verdict outside the allowed list, or no verifier answering for the finding. Until 2026-09-26 a demotion
was one terminal line and nothing durable (found by PF, 2026-09-24). `MADE_WORSE` reverts the finding's
commits of this pass; `HIDES_CODE_DEFECT` reverts them and puts a question to the owner, replacing an
answered one of the same finding, so the finding waits again rather than carrying two.
"""
function grade(root::AbstractString, run::Model.Run, verdicts; cfg::Model.Config = ConfigIO.read_config(root), io::IO = stdout)
    fixes = copy(run.fixes)
    questions = copy(run.questions)
    unreverted = copy(run.unreverted)
    # Three steps, in this order, because a commit may fix several findings (2026-10-16). Every verdict is
    # judged first, on the text the verifiers read: a revert made for one finding would otherwise demote
    # the next one's quote, which that revert took out. Each finding's commits are read before any revert,
    # so a shared commit is reverted once and not taken for no fix at all.
    todo = Runs.workable(run)
    own = Dict(f.id => Runs.pass_commits(root, pass_start(run), run, f.id) for f in todo)
    graded = Dict{String,Model.Verdict.T}()
    for f in todo
        answered = haskey(verdicts, f.id)
        v, quote_ = answered ? verdicts[f.id] : ("NOT_FIXED", "")
        note = answered ? "" : "no verifier answered for it"
        if !(v in VERDICTS)
            note = "the verifier answered `$v`, which is not a verdict; read as NOT_FIXED"
            v = "NOT_FIXED"
        elseif v != "NOT_FIXED" && !quote_holds(root, f, quote_)
            note = "the verifier said $v, but its quote is not in the text; read as NOT_FIXED"
            println(io, "run: ", f.id, " — ", note)
            v = "NOT_FIXED"
        end
        graded[f.id] = getfield(Model.Verdict, Symbol(v))
        push!(fixes, Model.DocFix(finding = f.id, pass = run.passes,
                                  commit = isempty(own[f.id]) ? "" : first(own[f.id]), blind = graded[f.id], note = note))
    end
    undone = Set{String}()
    cause = Dict{String,String}()                       # each commit reverted, and the finding whose verdict did it
    for f in todo
        verdict = graded[f.id]
        commits = [c for c in own[f.id] if !(c in undone)]
        if verdict === Model.Verdict.HIDES_CODE_DEFECT
            failed = [c for c in commits if !Runs.revert!(root, c; why = "the verifier believes the code is wrong")]
            append!(unreverted, failed); union!(undone, setdiff(commits, failed))
            for c in setdiff(commits, failed); cause[c] = f.id; end
            q = put_question(code_question(f, run), cfg; io)
            # One question per finding: parked, answered "fix it on my ruling", fixed and judged again,
            # the finding would carry an answered question and an unanswerable second one under the
            # same id, and `parked` read the first.
            k = findfirst(x -> x.id == q.id, questions)
            if k !== nothing && questions[k].answer !== nothing
                # the owner's earlier ruling is carried into the new question rather than overwritten:
                # it is what the fix was made on (found verifying the review's fixes, 2026-09-27)
                old = questions[k]
                q = with_context(q, q.context * " Your earlier answer was \"" * old.answer * "\"" *
                                    (isempty(old.direction) ? "" : ", with the direction \"" * old.direction * "\"") * ".")
            end
            k === nothing ? push!(questions, q) : (questions[k] = q)
            println(io, "run: ", f.id, isempty(failed) ? " — the fix is reverted and a question stands for the owner" :
                        " — the fix could NOT be reverted (a later fix conflicts), so the edit stays; a question stands for the owner and the run cannot end as evaluated")
        elseif verdict === Model.Verdict.MADE_WORSE && !isempty(commits)
            failed = [c for c in commits if !Runs.revert!(root, c)]
            append!(unreverted, failed); union!(undone, setdiff(commits, failed))
            for c in setdiff(commits, failed); cause[c] = f.id; end
            println(io, "run: ", f.id, isempty(failed) ? " — the fix made things worse and is reverted" :
                        " — the fix made things worse and could NOT be reverted (a later fix conflicts); the edit stays and the run cannot end as evaluated")
        end
    end
    # A finding whose fix was in a commit reverted for ANOTHER finding is no longer fixed, whatever its own
    # verdict said: the text it was judged on has gone back. Its verifier's verdict stays on the record,
    # and this is written after it.
    for f in todo
        graded[f.id] in (Model.Verdict.FIXED, Model.Verdict.LINE_ONLY) || continue
        lost = intersect(own[f.id], undone)
        isempty(lost) && continue
        note = Runs.REVERTED_FOR * join(unique([cause[c] for c in lost]), ", ") * "; read as NOT_FIXED"
        println(io, "run: ", f.id, " — ", note)
        push!(fixes, Model.DocFix(finding = f.id, pass = run.passes, commit = first(own[f.id]),
                                  blind = Model.Verdict.NOT_FIXED, note = note))
    end
    return with(run; fixes = fixes, questions = questions, unreverted = unreverted)
end

# Whether a verifier's quote is in the current text of a file the finding names. A quote written as two
# spans joined by "..." or "…" holds when each span does: matched whole, a correct verdict was demoted
# because the joined string is in no file (found by PF, 2026-09-24).
function quote_holds(root::AbstractString, f::Model.Finding, quote_::AbstractString)
    parts = [String(strip(x)) for x in split(String(quote_), r"\.\.\.|…") if !isempty(strip(x))]
    isempty(parts) && return false
    files = unique(l.file for l in f.draft.locations)
    return all(parts) do part
        any(files) do file
            Texts.reanchor(root, Model.Location(; file, text = part, line = 0); loose = false).found !== Model.Anchor.OUTDATED
        end
    end
end

# A question put inside a run passes the language rules like one put outside it (§8): the question is
# put whatever they find, and what they find is printed with the rule named, as `gbg ask` does. Until
# 2026-09-26 a parked finding's `--why` reached the owner unjudged, rule ids and paths and all.
# A copy of `q` with another context; every other field is carried.
with_context(q::Model.Question, context::AbstractString) =
    Model.Question(; (f => getfield(q, f) for f in fieldnames(Model.Question) if f !== :context)..., context = String(context))

function put_question(q::Model.Question, cfg::Model.Config; io::IO = stdout)
    failed = Engine.Questions.report(q, cfg)
    isempty(failed) || (println(io, "run: question ", q.id, " does not read as it should, and is put anyway:"); print(io, failed))
    return q
end

# The question a HIDES_CODE_DEFECT verdict puts: the documentation was made to describe code that looks
# wrong, the edit is reverted, and the owner says which half is right.
function code_question(f::Model.Finding, run::Model.Run)
    Model.Question(id = Runs.code_question_id(run, f.id),
                   decision = "Is the code right here, or the documentation?",
                   context = "A fix made the documentation describe what the code does, and the verifier reading the result believes the code itself is wrong. The edit is reverted until you answer.",
                   options = [Model.Option("fix the code", "the code is changed on your direction; the documentation keeps its old text", true),
                              Model.Option("fix the documentation instead", "the reverted edit is made again and stands", false),
                              Model.Option("not a defect", "nothing changes, and the finding is closed", false)],
                   exhibit = f.draft.claim * "\n" * join(["$(l.file): $(l.text)" for l in f.draft.locations], "\n"))
end

"""
    close_run(root; io = stdout) -> Int

Writes the run's record and its report, and ends it.

# Arguments

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
    # a fix the close undid is no longer a fix: its finding is open again, and is carried
    # A finding a verifier called no defect stays closed: what it was judged on is not the text.
    for sha in undone, fid in Runs.fixed_by(root, run, sha)
        k = findlast(x -> x.finding == fid, run.fixes)
        k !== nothing && run.fixes[k].blind === Model.Verdict.NOT_A_DEFECT && continue
        run = with(run; fixes = vcat(run.fixes, [Model.DocFix(finding = fid, pass = run.passes, commit = sha,
                                                               blind = Model.Verdict.NOT_FIXED)]))
    end
    unguarded = Runs.unguarded_code(root, run.first_commit; run)
    stop = isempty(unguarded) ? run.stop : Model.Stop.CANNOT_EVALUATE
    # A silent READER leaves part of the package unjudged, so the run cannot end as evaluated. A silent
    # verifier does not: its fix is graded NOT_FIXED, and its finding stays open and is carried.
    silent_readers = [k for k in run.silent if !startswith(k, "verify-")]
    if !isempty(silent_readers)
        stop = Model.Stop.CANNOT_EVALUATE
        println(io, "run: ", length(silent_readers), " reader(s) wrote nothing, so what they were to judge was not judged; the run cannot end as evaluated.")
    end
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
    # Always: findings in the working notes and questions waiting are carried by no run, so a close
    # that did not end DONE must not lose them; open findings go to the queue only on DONE, since a run
    # that could not be evaluated carries them instead (review, 2026-09-23).
    queued = queue_leftovers(root, closed; open_too = stop === Model.Stop.DONE)
    dir = Runs.dir(root, id)
    report = Render.report(closed, cfg; root, queued, undone = length(undone), red)
    Engine.Guard.refuse_publication(report, "a run's report")
    write(joinpath(dir, "report.md"), report)
    open(joinpath(dir, "run.json"), "w") do f
        GBGCodingTools.JSON3.pretty(f, GBGCodingTools.JSON3.write(Runs.as_dict(closed)))
    end
    rm(joinpath(dir, "run.draft.json"); force = true)
    # A "not a defect" the owner gave this run's question while it was open is settled now that it has
    # closed: written then, the settled list blocked the run's own collect and fixes.
    for q in closed.questions
        q.answer == GBGCodingTools.Answer.NOT_A_DEFECT || continue
        GBGCodingTools.Answer.settle!(root, q.id, isempty(q.direction) ? q.answer : q.direction)
    end
    # What the run's fixes grew within the ratchet's allowance is recorded now, with the record, so the
    # growth is one visible commit rather than a refusal at the next build [ruled 2026-09-26].
    grown = Catalogue.Shape.record_grown(root, cfg)
    if !isempty(grown)
        println(io, "run: ", length(grown), " unit(s) of prose grew within the allowance and are re-recorded in ", Catalogue.Shape.BASELINE, "; commit it with the record:")
        for g in grown; println(io, "  ", g); end
    end
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
is never reused.

# Arguments

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
GBGPeriodicFields's question, after two
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
    # Launched means an agent RAN: a stage interrupted before its collect has results on disk and no
    # launches counted yet, and deleting it threw away what its readers wrote (review, 2026-09-23).
    ran = run.agent_launches > 0 || (isdir(Agents.results_dir(root, id)) && !isempty(readdir(Agents.results_dir(root, id))))
    if !ran && all(f -> !startswith(f.id, run.id), run.findings)
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
    # What the stop throws away is the OPEN findings and the ones in the working notes: none is carried
    # into the next run. Their TEXT stays on the record, marked dropped [ruled 2026-09-26]: two runs'
    # findings were kept only as a count, and a triage made of them pointed at nothing. A finding fixed
    # and verified was not thrown away by anyone and stays with its pass (found in review, 2026-09-23).
    gone = vcat([f.id for f in Runs.open_findings(run)], [f.id for f in Runs.in_material(run)])
    # A dropped finding's question goes with it: left standing, every later close asked the owner about
    # a finding nobody held, and his answer would have re-opened nothing.
    asked = Set(Runs.code_question_id(run, g) for g in gone)
    questions = [q for q in run.questions if !(q.answer === nothing && q.id in asked)]
    stopped = with(run; stage = :close, stop = Model.Stop.OWNER_STOPPED, questions,
                   dropped = length(gone), dropped_ids = unique(vcat(run.dropped_ids, gone)))
    kept = [f for f in stopped.findings if !(f.id in stopped.dropped_ids)]
    report = Render.report(stopped, cfg; root)
    Engine.Guard.refuse_publication(report, "a run's report")
    write(joinpath(dir, "report.md"), report)
    open(joinpath(dir, "run.json"), "w") do f
        GBGCodingTools.JSON3.pretty(f, GBGCodingTools.JSON3.write(Runs.as_dict(stopped)))
    end
    rm(joinpath(dir, "run.draft.json"); force = true)
    rm(Agents.scratch_dir(root, id); force = true, recursive = true)
    Runs.write_stage(root, id, length(get(Runs.STAGES, run.instrument, Symbol[])))
    println(io, "run: ", id, " abandoned at ", run.stage, " (pass ", run.passes, "); ", stopped.dropped, " finding(s) dropped — their text stays on the record",
            isempty(kept) ? "." : " — and $(length(kept)) closed by a verdict or the owner's answer.")
    println(io, "  Commit .gbg/runs/", id, "/ — the record and the report. Its agents read this package,")
    println(io, "  and that they were stopped is evidence about it. Its scratch is deleted.")
    return 0
end

"""
    restore_green(root, run, cfg; io = stdout) -> (undone, red, failed)

Puts the documentation back where the run left the build red.

# Arguments

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
    mine = Runs.guarded_commits(root, run.first_commit; run)
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
    if still && !failed
        # Red with every fix undone: the build was broken before the run, and the fixes were not the
        # cause. They are put back, as the docstring says (review, 2026-09-23: they were left undone).
        back = Runs.reverted_by(root, run.first_commit, undone)
        restored = all(r -> Runs.revert!(root, r; why = "the build was red before the run; the fix is restored"), back)
        println(io, restored ? "run: still red with every fix of this run undone, so the build was broken before it; the fixes are restored and the owner reads the build" :
                               "run: still red with every fix undone, and the fixes could not all be restored; the run cannot be evaluated")
        return (restored ? String[] : undone, true, !restored)
    end
    println(io, failed ? "run: some fixes of this run could not be reverted; the run cannot be evaluated" :
            "run: every fix of this run is undone, $(length(undone)) commit(s), and the build passes again")
    return (undone, still, failed)
end

# An agent's text on one line: a newline in a claim would start a new queue item, or a heading, of its own
one_line(t) = replace(String(t), r"\s*[\r\n]+\s*" => " ")

"The heading of the work queue's section the end-of-turn hook does not count."
const QUEUE_HEADING = "## From the last review"

"""
    queue_leftovers(root, run; open_too = true) -> Int

Writes one line per open finding into `.claude/WORK_QUEUE.md`, under the heading the end-of-turn hook
does not count, creating the file or the section where there is none.

# Arguments

- `root` — the package root.
- `run` — the closed run.
- `open_too` — whether every open finding goes, or only those parked on the owner's answer.

Returns how many lines went.

Each line names the file, the node and the quote rather than a line number, which is stale by the time
the owner reads it. The section is the last review's and is replaced whole; the owner's own sections
stay as they were.
"""
function queue_leftovers(root::AbstractString, run::Model.Run; open_too::Bool = true)
    # A finding waiting on the owner's answer is carried by no run, and its line is the only place the
    # queue names its question: it is listed whether or not the run ended DONE (found in review, 2026-09-24).
    open = [f for f in Runs.open_findings(run) if open_too || Runs.parked(run, f.id)]
    notes = Runs.in_material(run)
    waiting = [(rid, q) for (rid, q) in Runs.open_questions(root) if rid != run.id]
    path = joinpath(root, ".claude", "WORK_QUEUE.md")
    text = isfile(path) ? read(path, String) : ""
    lines = String[]
    # What a reader found in the working notes it was given to consult: the owner's, never the fixer's,
    # and listed first because it may be the formula three docstrings copy.
    for f in notes
        l = isempty(f.draft.locations) ? nothing : f.draft.locations[1]
        push!(lines, "- [ ] " * f.id * " IN THE WORKING NOTES, for the owner: " * one_line(f.draft.claim) *
                     (l === nothing ? "" : one_line(" — `" * l.file * "`" * (isempty(l.text) ? "" : " \"" * l.text * "\""))))
    end
    for f in open
        where_ = ""
        if !isempty(f.draft.locations)
            l = f.draft.locations[1]
            where_ = " — `" * l.file * "`" * (isempty(l.node) ? "" : " (" * l.node * ")") *
                     (isempty(l.text) ? "" : " \"" * l.text * "\"")
        end
        push!(lines, "- [ ] " * f.id * " " * one_line(f.draft.claim) * one_line(where_) *
                     (Runs.parked(run, f.id) ? " — waits on the owner's answer: `gbg answer " * Runs.code_question_id(run, f.id) * " \"<option>\"`" : ""))
    end
    # a question an EARLIER run put, still unanswered: its finding is carried nowhere, so it stays here
    for (rid, q) in waiting
        push!(lines, "- [ ] " * q.id * " waits on the owner's answer (run " * rid * "): `gbg answer " * q.id * " \"<option>\"`")
    end
    # The section is the EXACT heading line to the next heading of any level, and it is rewritten every
    # close — emptied when nothing is left — so an earlier run's lines never outlive their findings, and
    # no text of the owner's around it is touched (found in review, 2026-09-23).
    ls = split(text, '\n')
    i = findfirst(==(QUEUE_HEADING), rstrip.(ls))
    before, after = if i === nothing
        (ls, String[])
    else
        j = findnext(l -> startswith(l, "#"), ls, i + 1)
        (ls[1:i-1], j === nothing ? String[] : ls[j:end])
    end
    while !isempty(before) && isempty(strip(before[end])); pop!(before); end
    section = isempty(lines) ? String[] : vcat([QUEUE_HEADING, ""], lines, [""])
    isempty(before) && isempty(section) && isempty(after) && return 0
    head = isempty(before) ? ["# Work queue", ""] : vcat(before, [""])
    out = join(vcat(head, section, after), '\n')
    endswith(out, '\n') || (out *= "\n")
    mkpath(dirname(path))
    Engine.Guard.refuse_publication(out, ".claude/WORK_QUEUE.md")
    write(path, out)
    return length(lines)
end

"""
    covered(root, id, by = ""; commit = "", io = stdout) -> Int

Records that a commit already made fixed the finding `id`: a fix of the finding `by`, or the commit
`commit`, made outside `gbg docfix commit` and read by the change guard here.

# Arguments

- `root` — the package root.
- `id` — the finding fixed.
- `by` — the finding whose commits of this pass fixed it; one of `by` and `commit`.
- `commit` — a commit of this pass that no `gbg docfix commit` made.
- `io` — where the outcome is reported.

Exit 0 when it is recorded; 1 when the guard calls `commit` code, or the tree breaks a rule the run
opened clean on; 2 when no run is open, the run is not at a fix stage, a finding is not one this pass
works on, `id` and `by` are the same, `by` has no fix commit this pass, or `commit` is not a commit of
this pass, is a merge, was made by the guard, or was reverted.

A change that fixes several findings names them all when it is committed (`--finding <id>,<id>`). The
option `by` is for the one found afterwards: the commit exists, nothing is left to commit, and `gbg run
next` would otherwise refuse the finding for ever (found reviewing rc.74, 2026-10-16).

The option `commit` is for a fix a session committed with git alone: before rc.74 its finding was judged
on the text as it stood, and the refusal rc.74 added left no way through but undoing correct work (the
owner, 2026-10-16). The guard reads the commit as the close will, with no ruling's licence, and refuses
it on any code. Credited, it is the run's own edit: the finding's verifier reads it, a verdict against
it reverts it, and the close can undo it with the rest.
"""
function covered(root::AbstractString, id::AbstractString, by::AbstractString = ""; commit::AbstractString = "", io::IO = stdout)
    rid = open_run(root)
    rid === nothing && (println(io, "run: nothing is open here"); return 2)
    run = Runs.load(root, rid)
    Runs.stage_of(root, rid) === :fix ||
        (println(io, "run: record a covered finding at a fix stage; ", rid, " is at ", Runs.stage_of(root, rid)); return 2)
    (isempty(id) || isempty(by) == isempty(commit)) &&
        (println(io, "usage: gbg run covered <finding> --by <finding> | gbg run covered <finding> --by-commit <sha>"); return 2)
    work = Set(f.id for f in Runs.workable(run))
    id in work || (println(io, "run: ", id, " is not a finding this pass of ", rid, " works on"); return 2)
    isempty(commit) || return credit(root, rid, run, id, commit; io)
    id == by && (println(io, "run: a finding does not cover itself"); return 2)
    by in work || (println(io, "run: ", by, " is not a finding this pass of ", rid, " works on"); return 2)
    isempty(Runs.fix_commits(root, pass_start(run), by; run)) &&
        (println(io, "run: ", by, " has no fix committed this pass, so it covers nothing yet"); return 2)
    entry = id * "\t" * by
    entry in run.covered && (println(io, "run: ", id, " is already recorded as covered by ", by); return 0)
    Runs.save(root, with(run; covered = vcat(run.covered, [entry])))
    println(io, "run: ", id, " is covered by the fix of ", by, "; its verifier reads that diff, and a revert of it reopens both")
    return 0
end

# The `--by-commit` half of `covered`: the commit is read by the guard as the close reads every commit,
# and credited only when it is documentation throughout.
function credit(root::AbstractString, rid::AbstractString, run::Model.Run, id::AbstractString, commit::AbstractString; io::IO = stdout)
    full = Git.run(root, "rev-parse", "--verify", "--quiet", commit * "^{commit}")
    (full === nothing || isempty(strip(full))) && (println(io, "run: ", commit, " is not a commit here"); return 2)
    full = String(strip(full))
    since = pass_start(run)
    # of this pass: after the commit the pass began at, and on the branch
    (Git.run(root, "merge-base", "--is-ancestor", full, "HEAD") !== nothing && full != since &&
     (isempty(since) || Git.run(root, "merge-base", "--is-ancestor", since, full) !== nothing)) ||
        (println(io, "run: ", first(full, 8), " is not a commit of this pass, which began at ", first(since, 8)); return 2)
    # a merge shows no change of its own, while its side carries whatever it carries (found in review)
    parents = split(strip(something(Git.run(root, "log", "-1", "--format=%P", full), "")))
    length(parents) > 1 &&
        (println(io, "run: ", first(full, 8), " is a merge, which shows no change of its own; credit the commits it brought in"); return 2)
    body = String.(strip.(split(something(Git.run(root, "log", "-1", "--format=%B", full), ""), '\n')))
    Runs.GUARD_TRAILER in body &&
        (println(io, "run: ", first(full, 8), " was made by the guard and names its findings; a finding it fixed in passing is recorded with --by"); return 2)
    full in Runs.reverted(root, since) &&
        (println(io, "run: ", first(full, 8), " was reverted, so it fixes nothing now"); return 2)
    entry = id * "\t" * full
    entry in run.credited && (println(io, "run: ", id, " is already credited with ", first(full, 8)); return 0)
    cfg = ConfigIO.read_config(root)
    code = Runs.code_of(root, cfg, full)
    if !isempty(code)
        println(io, "run: refused — the guard calls ", length(code), " file(s) of ", first(full, 8), " code: ", join(code, ", "))
        println(io, "  Nothing was recorded. A code change waits for the owner's answer: park the finding, and the close")
        println(io, "  puts the commit to him.")
        return 1
    end
    broke = Docfix.broken_by_change(root)
    if !isempty(broke)
        println(io, "run: refused — the tree breaks ", length(broke), " rule(s) that passed when the run opened: ", join(String.(broke), ", "))
        println(io, "  Nothing was recorded. Fix the text so that it passes, as `gbg docfix commit` would have required.")
        return 1
    end
    Runs.save(root, with(run; credited = vcat(run.credited, [entry])))
    println(io, "run: ", id, " is credited with ", first(full, 8), "; it is the run's edit now: its verifier reads that diff, and a verdict against it reverts it")
    return 0
end

"""
    back(root; io = stdout) -> Int

Returns the open run from a verify stage to the fix stage before it, while no verifier of that stage has
written a verdict.

# Arguments

- `root` — the package root.
- `io` — where the outcome is reported.

Exit 0 when the run is back at its fix stage, with the findings listed as `gbg run next` lists them
there; 2 when no run is open, the run is not at a verify stage, or a verdict of it has been written.

A run never goes back over anything an agent judged: that is what `Runs.advance!` refuses, and
this does not loosen it. A verify stage none of whose verifiers has written is only arguments on disk,
so dropping them loses nothing. SS reached such a stage on 2026-10-16 with 98 of its 100 findings
untouched, before `gbg run next` refused that, and nothing but a hand edit of the record led back.
"""
function back(root::AbstractString; io::IO = stdout)
    id = open_run(root)
    id === nothing && (println(io, "run: nothing is open here"); return 2)
    run = Runs.load(root, id)
    order = get(Runs.STAGES, run.instrument, Symbol[])
    at = Runs.stage_index(root, id)
    (at >= 2 && order[at] === :verify && order[at - 1] === :fix) ||
        (println(io, "run: ", id, " is at ", Runs.stage_of(root, id), "; only a verify stage goes back, to its fix stage"); return 2)
    stage = Agents.stage_dir(root, id)
    results = Agents.results_dir(root, id)
    wrote = (isdir(results) && !isempty(readdir(results))) || isfile(joinpath(stage, "returned.json"))
    wrote && (println(io, "run: a verifier of ", id, " has written, so its stage is not undone; gbg run next continues it"); return 2)
    rm(stage; recursive = true, force = true)
    Runs.write_stage(root, id, at - 1)
    moved = with(run; stage = :fix)
    Runs.save(root, moved)
    println(io, "run: ", id, " is back at fix (pass ", run.passes, "); the verify stage's arguments are dropped, and no verifier may be running.")
    return fix_stage(root, moved, ConfigIO.read_config(root); io, reanchor = false)
end

"""
    park(root, id; why, io = stdout) -> Int

Hands one finding to the owner, at a fix stage: a question about it is put, and no pass works on it
again until he answers.

# Arguments

- `root` — the package root.
- `id` — the finding.
- `why` — what the fix would change that the fixer may not, in a sentence.
- `io` — where the outcome is written.

Exit 0 when it parked the finding, 2 when it could not: no run is open, the run is not at a fix stage,
the finding is not one the run can work on, or no reason was given.

A finding whose fix is a change to the config, to code or to a formula cannot be committed by the fixer
and cannot be verified, since nothing changes. Left open it cost a verifier every pass and reached the
owner only at close. Parked, it reaches him now, and his answer does what the same answer does to a
verifier's code question: "fix the code" puts it on his own list, "not a defect" closes it.
"""
function park(root::AbstractString, id::AbstractString; why::AbstractString = "", io::IO = stdout)
    rid = open_run(root)
    rid === nothing && (println(io, "run: nothing is open here"); return 2)
    run = Runs.load(root, rid)
    Runs.stage_of(root, rid) === :fix ||
        (println(io, "run: park a finding at a fix stage; ", rid, " is at ", Runs.stage_of(root, rid)); return 2)
    isempty(strip(why)) && (println(io, "run: say what the fix would change that you may not: --why \"…\""); return 2)
    k = findfirst(f -> f.id == id, Runs.workable(run))
    k === nothing && (println(io, "run: ", id, " is not a finding this run can work on — closed, in material, already waiting on the owner, or unknown"); return 2)
    f = Runs.workable(run)[k]
    # A finding is put to the owner once: parked again after his ruling, it recorded more files under that
    # same ruling with no new answer (review, 2026-10-06).
    any(q -> q.id == Runs.code_question_id(run, id), run.questions) &&
        (println(io, "run: ", id, " was put to the owner already; his answer stands, and it is not parked again"); return 2)
    q = put_question(Runs.owner_question(run, f, why), ConfigIO.read_config(root); io)
    # the files the question shows are what a ruling on it licenses, recorded now
    Runs.save(root, with(run; questions = vcat(run.questions, [q]),
                         licences = vcat(run.licences, [id * "\t" * file for file in Runs.licence_of(f)])))
    println(io, "run: ", id, " is parked; no pass works on it until the owner answers:")
    println(io, "  gbg answer ", q.id, " \"", Runs.OWNER_ANSWER, "\"  |  \"", Runs.RULED_ANSWER, "\" --direction \"…\"  |  \"", Runs.NOT_A_DEFECT_ANSWER, "\"")
    return 0
end

"""
    cost(root, dir; io = stdout) -> Int

Records what the last launched stage's agents cost, summed from their own transcripts.

# Arguments

- `root` — the package root.
- `dir` — the directory holding the launch's transcripts: every `.jsonl` file under it is read, and
  each message with a `usage` counts once, however many lines carry its id.
- `io` — where the totals are written.

Exit 0 when recorded, 2 when no run is open, the directory holds no usage, or the run is not at a
collect.

The launch's own summary field counts a tenth of the real cost — it leaves out most of the cache
reads and writes, which are nearly all of it [measured on GBGPeriodicFields, 2026-09-24: 17.9M reported
against 164.6M summed] — and nothing recorded a cost at all; the record's `tokens` stayed empty. The
transcripts are the reliable source, and the skill tells the session where the launch names them.
"""
function cost(root::AbstractString, dir::AbstractString; io::IO = stdout)
    id = open_run(root)
    id === nothing && (println(io, "run: nothing is open here"); return 2)
    run = Runs.load(root, id)
    order = get(Runs.STAGES, run.instrument, Symbol[])
    at = Runs.stage_index(root, id)
    (at >= 2 && order[at] === :collect) || (println(io, "run: record a cost at the collect of the stage it belongs to; ", id, " is at ", order[at]); return 2)
    isdir(dir) || (println(io, "run: no directory at ", dir); return 2)
    agents = 0; input = 0; cw = 0; cr = 0; output = 0
    for (here, _, files) in walkdir(dir), f in files
        endswith(f, ".jsonl") || continue
        seen = false
        # A message with several content blocks — thinking and text, text and a tool call — is written
        # as one line per block, each carrying the message's whole usage: summed per line, a stage
        # cost about two and a half times what was paid (measured on a PF transcript, 2026-09-26).
        ids = Set{String}()
        for line in eachline(joinpath(here, f))
            d = try GBGCodingTools.JSON3.read(line, Dict{String,Any}) catch; continue end
            m = get(d, "message", nothing); m isa AbstractDict || continue
            u = get(m, "usage", nothing); u isa AbstractDict || continue
            mid = get(m, "id", nothing)
            mid isa AbstractString && (mid in ids ? continue : push!(ids, String(mid)))
            input += Int(get(u, "input_tokens", 0)); output += Int(get(u, "output_tokens", 0))
            cw += Int(get(u, "cache_creation_input_tokens", 0)); cr += Int(get(u, "cache_read_input_tokens", 0))
            seen = true
        end
        seen && (agents += 1)
    end
    agents == 0 && (println(io, "run: no transcript under ", dir, " carries a usage record; nothing recorded"); return 2)
    stage = String(order[at - 1])
    entry = Model.Usage(; stage, pass = run.passes, agents, input, cache_write = cw, cache_read = cr, output)
    others = [u for u in run.usage if !(u.stage == stage && u.pass == run.passes)]
    Runs.save(root, with(run; usage = vcat(others, [entry])))
    println(io, "run: ", stage, " (pass ", run.passes, "): ", agents, " agent(s); input ", input, ", cache write ", cw,
            ", cache read ", cr, ", output ", output, " tokens. Recorded.")
    return 0
end

function cmd_run(args)
    o = parse_options(args; valued = ["readers", "model", "scope", "why", "by", "by-commit"])
    root = ConfigIO.require_root("run")
    root === nothing && return 2
    isempty(o.positional) && (println(stderr, "usage: gbg run <instrument> [--readers bound|open|both] [--scope full|changed] [--model <name>] [--sequential] | gbg run next|back|collect|close|abandon | gbg run park <finding> --why \"…\" | gbg run covered <finding> --by <finding> | --by-commit <sha>"); return 2)
    what = o.positional[1]
    # A help flag on any verb prints usage and does nothing: `gbg run abandon --help` abandoned PF's
    # run (2026-09-24), and a help flag on the one irreversible verb must never act.
    if "help" in o.flags || "h" in o.flags
        println(stderr, "usage: gbg run <instrument> [--readers bound|open|both] [--scope full|changed] [--model <name>] [--sequential] | gbg run next|back|collect|close|abandon | gbg run park <finding> --why \"…\" | gbg run covered <finding> --by <finding> | --by-commit <sha> | gbg run cost <dir>")
        return 0
    end
    what == "next" && return next(root)
    what == "collect" && return collect(root)
    what == "close" && return close_run(root)
    what == "abandon" && return abandon(root)
    what == "back" && return back(root)
    what == "covered" && return covered(root, length(o.positional) >= 2 ? o.positional[2] : "", get(o.values, "by", "");
                                        commit = get(o.values, "by-commit", ""))
    what == "park" && return park(root, length(o.positional) >= 2 ? o.positional[2] : ""; why = get(o.values, "why", ""))
    what == "cost" && return cost(root, length(o.positional) >= 2 ? o.positional[2] : "")
    return start(root, Symbol(replace(what, "-" => "_")); readers = Symbol(get(o.values, "readers", "bound")),
                 scope = Symbol(get(o.values, "scope", "full")),
                 model = get(o.values, "model", "session"), sequential = "sequential" in o.flags)
end
VERBS["run"] = cmd_run

end # module Run
