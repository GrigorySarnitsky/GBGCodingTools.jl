# Passes.jl — the verification half of a round: `gbg round pass open`, `grade`, `close` (ARCHITECTURE
# §6.2 steps 7–9, §6.5, §6.7, §6.8). The demotion is Demote.jl; the args renderer is Preflight's.

"""
    Passes

The verification half of a round. Each pass has two verifiers, both agents the session launches:

- the **act verifier** sees the fix pass's diff and grades what it did to each open finding, in a
  closed vocabulary: `HONORED` (the ask landed by the right means, and `class_surfaces` lists every
  other surface carrying the same class with whether the diff swept it), `LINE-ONLY` (the instance
  is fixed, the class is alive), `ADJACENT`, `INSERTED`, `NEW-DEFECT`, `SCOPE-CREEP`, `UNDONE`
  (nothing in the diff addresses it) and `LAUNDERED` (closed by declaring it acceptable);
- the **state verifier** never sees the diff and grades whether the
  defect is in the tree now: `PRESENT` (its default), `PARTIAL`, `REGRESSED`, `ABSENT`,
  `NOT-A-DEFECT` or `UNCLEAR`.

[`GBGCodingTools.demote`](@ref) turns an `HONORED` whose list is empty or names an unswept surface
into `LINE-ONLY`. [`Passes.pass_open`](@ref) opens a verification pass (nonce, range, expected counts, the regenerated
manuscripts, the verifiers' Workflow calls); [`Passes.grade`](@ref) validates the verdict files, applies
the demotion and the four closure channels — `honored`, `adjudicated`, `seeded` and `rescan` — and
writes the tally; [`Passes.close`](@ref) checks every closing condition of the instrument
([`GBGCodingTools`](@ref) binds the term) in order, carries what a spent pass budget left open (the
fifth channel, `carried`) and stamps the round closed.
"""
module Passes

using TOML, JSON3, Dates, SHA, Random
using ..GBGCodingTools: GBGCodingTools, Config, Ledger, Sync, RoundFiles, Git, Preflight, Rounds, Witnesses, demote,
      load_schema, instrument_schema, validate, consolidate, scan_catalog, run_scan, self_verify

const RoundError = Rounds.RoundError
const FAVOURABLE = ("ABSENT", "NOT-A-DEFECT")

read_json(p) = JSON3.read(read(p, String), Dict{String,Any})
write_json(p, d) = (mkpath(dirname(p)); open(p, "w") do f; JSON3.pretty(f, JSON3.write(d)); println(f); end)
findings_of(dir) = read_json(joinpath(dir, "findings.json"))["findings"]
pass_dir(dir, k) = joinpath(dir, "verdicts", "pass-$k")

# ---- pass open ---------------------------------------------------------------------------------------------

function findings_text_file(path, findings)
    io = IOBuffer()
    for f in findings
        println(io, "--- ", f["id"], " ---")
        println(io, "title: ", f["title"]); println(io, "lane: ", f["lane"], "   type: ", get(f, "type", ""), "   severity: ", f["severity"], "   confidence: ", f["confidence"])
        for l in f["locations"]; println(io, "location: ", l); end
        haskey(f, "contradicts") && !isempty(f["contradicts"]) && println(io, "contradicts: ", f["contradicts"])
        for k in ("file", "second_location", "mechanism", "witness_plan", "observed", "before", "after", "why_it_matters", "justified", "previously_worked", "evidence")
            haskey(f, k) && !isempty(string(f[k])) && println(io, k, ": ", f[k])
        end
        println(io, "description: ", f["description"])
        haskey(f, "resolution_hint") && !isempty(f["resolution_hint"]) && println(io, "hint: ", f["resolution_hint"])
        haskey(f, "claimed_fix") && println(io, "claimed fix: ", f["claimed_fix"])
        println(io)
    end
    mkpath(dirname(path)); write(path, String(take!(io)))
    return path
end

# ---- what a pass verifies -------------------------------------------------------------------------

"""
    finding_files(root, finding) -> Vector{String}

Every repository file a finding names in its `locations`. The argument `root` is the consumer root, a
candidate path being kept only when it is a file there, and `finding` is one banked finding.

A location is free text (`path:line — quoted`), so each path-shaped token is kept only when it is a
file in the tree. Returns the paths, deduplicated.
"""
function finding_files(root::AbstractString, finding::AbstractDict)
    out = String[]
    for l in get(finding, "locations", String[])
        for m in eachmatch(r"[A-Za-z0-9_][A-Za-z0-9_./\-]*\.[A-Za-z0-9]+", String(l))
            f = String(m.match)
            isfile(joinpath(root, f)) && !(f in out) && push!(out, f)
        end
    end
    return out
end


"""
    CARRY_LIMIT

How many rounds a finding may be carried before it stops being a deferral and becomes neglect. At the
limit `close` refuses the carry and the owner decides: a finding that has survived three batteries is
not waiting for time, it is waiting for a ruling.
"""
const CARRY_LIMIT = 3

carry_file(cfg::AbstractDict) = joinpath(cfg["root"], ".gbg", "carried.toml")

"""
    severity_ratings(dir) -> Dict{String,String}

The blind re-ratings of `severity.json` under the round directory `dir`, id → severity, validated
against `schema/severity.schema.json`. Returns an empty dictionary when the file is absent — an
unrated finding keeps its lane's own rating, and the caller decides whether an absent file is fatal.
"""
function severity_ratings(dir::AbstractString)
    p = joinpath(dir, "severity.json")
    isfile(p) || return Dict{String,String}()
    d = read_json(p)
    errs = validate(load_schema("severity"), d)
    isempty(errs) || throw(RoundError("severity.json does not validate: " * first(errs)))
    return Dict(String(r["id"]) => String(r["severity"]) for r in d["ratings"])
end

"""
    carry_ledger(cfg) -> Dict

`.gbg/carried.toml`, the findings a round closed by carrying them into the next round of their
instrument, and the backlog at each release. The argument is `cfg`, the validated config.

A carried finding is real, unfixed, and re-banked next time rather than left to be found again: a fresh
battery is a fresh search, and a finding trusted to rediscovery is a finding dropped. Only `minor` and
`nit` carry, on a severity re-rated by someone other than the lane that reported it — the moment
severity licenses a deferral it stops being a label and becomes a lever. Returns the ledger, empty when
the file is absent.
"""
function carry_ledger(cfg::AbstractDict)
    p = carry_file(cfg)
    isfile(p) || return Dict{String,Any}("schema_version" => 1, "carried" => Any[], "history" => Any[])
    d = Dict{String,Any}(TOML.parsefile(p))
    errs = validate(load_schema("carried"), d)
    isempty(errs) || throw(RoundError(".gbg/carried.toml does not validate: " * first(errs)))
    haskey(d, "carried") || (d["carried"] = Any[]); haskey(d, "history") || (d["history"] = Any[])
    return d
end

"""
    save_carry(cfg, led)

Writes the carry ledger `led` back to `.gbg/carried.toml` for the consumer `cfg`, with the banner that
says no hand edits it. Returns nothing.
"""
function save_carry(cfg::AbstractDict, led::AbstractDict)
    open(carry_file(cfg), "w") do f
        println(f, "# .gbg/carried.toml — written by `gbg round close --carry`, never edited by hand. Each entry is a")
        println(f, "# real, unfixed finding a round closed by carrying it into the next round of its instrument.")
        TOML.print(f, led)
    end
    return nothing
end

"""
    carry_outstanding(cfg, instrument) -> Vector{Dict}

The carried findings of `instrument` still owed a fix, for the consumer `cfg`. `gbg round bank` re-banks
them so the closure loop sees them again; they never reach the searching panel, exactly as an
adjudicated title does not. Returns the entries.
"""
carry_outstanding(cfg::AbstractDict, instrument::AbstractString) =
    [Dict{String,Any}(e) for e in carry_ledger(cfg)["carried"] if String(e["instrument"]) == instrument]

"""
    quote_probe(root, finding) -> Vector{String}

Every file the finding NAMES in which its own quoted text still stands verbatim. The arguments are
`root`, the consumer root, and `finding`, one banked finding.

A location is written `path:lines — "…"`, and the quoted text is handed to both verifiers as a computed
fact so neither spends a tool call establishing it: 22% of this round's blind verdicts cited a grep the
CLI can run in milliseconds.

It is EVIDENCE, never a gate. The quote is the site's identifying text as often as the defect's: over
the 56 findings of `2026-09-09-check-docs-02`, a round that closed every id honestly, 19 quotes still
stood — `templates#3` quoting a filename, `cold-reader#1` a sentence that was always correct. Closing on
a vanished quote would miss the class that moved; OPENING on a surviving one would have held a third of
that round open with no way out. Only the verifier decides. It searches the named file alone, so a
quotation of the defect in a changelog cannot hold its own fix open. Returns the files.
"""
function quote_probe(root::AbstractString, finding::AbstractDict)
    out = String[]
    for l in get(finding, "locations", String[])
        s = String(l)
        m = match(r"^([A-Za-z0-9_][A-Za-z0-9_./\-]*\.[A-Za-z0-9]+)", s)
        m === nothing && continue
        file = String(m.captures[1]); p = joinpath(root, file)
        (isfile(p) && !(file in out)) || continue
        text = read(p, String)
        for q in eachmatch(r"\"([^\"\n]{12,200})\"", s)
            frag = strip(String(q.captures[1]))
            length(frag) >= 12 && occursin(frag, text) && (push!(out, file); break)
        end
    end
    return out
end

"""
    class_candidates(cfg, finding; cap = 24) -> Vector{String}

Every place in the tree that writes down a rule or scan id the finding cites, as `file:line`. The
arguments are `cfg`, the validated config; `finding`, one banked finding; and `cap`, the most sites
returned.

This is the checklist the act verifier ([`GBGCodingTools.Passes`](@ref) binds it) marks instead of
inventing. A class rarely lives where it was
quoted: `operational-claims#7` of `2026-09-09-check-docs-02` was one comment overstating what
`SCAN.SIBLING_LINK` enforces, and it lived in four places — the scan's file header, the docstring above
its function, the rule's paragraph in `policy/`, and its row in the design's scan catalogue. The verifier
found one per pass and the round paid three passes to enumerate a set a grep names at once. A site the
tool cannot name is still the verifier's to add; what changes is that a site nobody looked at is now
visibly unmarked rather than unthought-of. Returns the sites.
"""
function class_candidates(cfg::AbstractDict, finding::AbstractDict; cap::Int = 24)
    root = cfg["root"]
    text = string(finding["title"], " ", get(finding, "description", ""), " ", join(get(finding, "locations", String[]), " "))
    ids = unique(String(m.match) for m in eachmatch(r"\b(?:SCAN|RULE)\.[A-Z0-9_]+(?:\.[A-Z0-9_]+)?\b", text))
    isempty(ids) && return String[]
    # a scan and the rule it enforces are two ends of one thing: a finding that cites only the scan is
    # about the rule's prose as well, and the catalogue already records which is which
    for row in scan_catalog()
        (row["id"] in ids || row["rule"] in ids) && union!(ids, [String(row["id"]), String(row["rule"])])
    end
    out = String[]
    for rel in candidate_files(root)
        f = basename(rel)
        endswith(f, ".jl") || endswith(f, ".md") || endswith(f, ".toml") || endswith(f, ".json") || endswith(f, ".js") || continue
        f == "CHANGELOG.md" && continue                           # history, not a surface the class lives on
        local lines
        try; lines = readlines(joinpath(root, rel)); catch; continue; end
        for (n, l) in enumerate(lines)
            any(id -> occursin(id, l), ids) || continue
            push!(out, "$rel:$n")
            length(out) >= cap && return sort!(out)
        end
    end
    return sort!(out)
end

# The files a class can live on: those git would track (`ls-files`), so a gitignored build product —
# regenerated from its source, never swept by a fix — is never offered to a verifier as a surface to
# sweep; outside a work tree, every file under the root. Round state and the session's own files are
# never offered either way. Returns root-relative paths, sorted.
function candidate_files(root::AbstractString)
    skip = (".git", ".gbg", "build", ".tmp", "node_modules", ".claude")
    listed = Git.run(root, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
    rels = String[]
    if listed === nothing
        for (dir, dirs, files) in walkdir(root)
            filter!(d -> !(d in skip), dirs)
            append!(rels, [relpath(joinpath(dir, f), root) for f in files])
        end
    else
        append!(rels, String.(split(listed, '\0'; keepempty = false)))
    end
    return sort!(filter(r -> !(first(splitpath(r)) in skip), rels))
end

"""
    last_graded(dir, k) -> Int

The highest pass below `k` that was GRADED — the one that has a `tally.json` — or 0 when none was. The
arguments are `dir`, the round directory, and `k`, the pass being opened or graded.

A pass that was opened and never graded is superseded, not evidence: reading `k - 1` blindly made an
abandoned pass erase what the last real one decided, so a round whose every id was closed came back
with all of them open, the sweep check refused the next pass over findings nobody had reopened, and a
regrade would have re-verified the whole round. Returns the pass number.
"""
function last_graded(dir::AbstractString, k::Int)
    for j in (k - 1):-1:1
        isfile(joinpath(pass_dir(dir, j), "tally.json")) && return j
    end
    return 0
end

"""
    pass_budget(cfg, dir, rec, k) -> (used, cap)

How much of a round's pass budget is spent before pass `k`, and the budget itself. The arguments are:

- `cfg` — the validated config.
- `dir` — the round directory.
- `rec` — the round record.
- `k` — the pass about to open, or one past the last graded pass when closing.

`cap` is the instrument's `max_passes`; 0, or an instrument without the key, is no budget. A graded pass
counts unless its `pass.toml` says `counted = false`, which `pass_open` writes for a `--regrade` whose fix
range changed no covered file: re-stamping a moved config verifies no new fix and costs no budget, or a
ledger edit after the last pass would leave the round able neither to regrade nor to close. An ungraded
pass bought nothing and counts nothing. Returns the passes used and the cap.
"""
function pass_budget(cfg::AbstractDict, dir::AbstractString, rec::AbstractDict, k::Int)
    cap = Int(get(get(cfg["instruments"], rec["instrument"], Dict{String,Any}()), "max_passes", 0))
    used = count(1:(k - 1)) do j
        pd = pass_dir(dir, j)
        isfile(joinpath(pd, "tally.json")) && isfile(joinpath(pd, "pass.toml")) &&
            get(TOML.parsefile(joinpath(pd, "pass.toml")), "counted", true)
    end
    return (used, cap)
end

"""
    pass_scope(cfg, dir, rec, k) -> (scope, prev_open, suspects, range)

Which finding ids the next pass must verify, and the range of the fix pass it grades. The arguments are:

- `cfg` — the validated config.
- `dir` — the round directory.
- `rec` — the round record.
- `k` — the number of the pass about to open.

Pass 1 verifies every id. Later passes verify the ids left open by the previous pass, plus any id that
pass closed whose named locations the fix pass has touched again — a closed finding can only regress
where its own evidence lives, and the diff says whether anything went near it — and any it closed that
names no location at all, which is re-verified every pass rather than never, silence about where a
defect lives being no evidence that it is gone.

An id the previous pass left `pending_state` — graded by the act verifier, never read by the state verifier,
the two verifiers [`GBGCodingTools.Passes`](@ref) binds — is a suspect too, or nothing would read it again. The suspects are re-checks, which `pass_open` sends to
the state verifier alone. Returns the scope, the previously open ids, the suspects and the fix pass's
commit range; `scope === nothing` means every id.
"""
function pass_scope(cfg::AbstractDict, dir::AbstractString, rec::AbstractDict, k::Int)
    root = cfg["root"]; head = something(Git.head(root), "0"^40)
    k > 1 || return (nothing, String[], String[], "$(rec["head"])..$head")
    j = last_graded(dir, k)
    j == 0 && return (nothing, String[], String[], "$(rec["head"])..$head")
    prevtally = joinpath(pass_dir(dir, j), "tally.json")
    prevpass = joinpath(pass_dir(dir, j), "pass.toml")
    tally = read_json(prevtally)
    from = isfile(prevpass) ? get(TOML.parsefile(prevpass), "head", rec["head"]) : rec["head"]
    range = "$from..$head"
    prev_open = String.(tally["open_ids"])
    # an id the act verifier closed with no state reading is neither open nor closed; unless it is re-read
    # here it is never read again (2026-09-10-check-docs-03 left two such ids out of scope for seven passes)
    pending = String.(get(tally, "pending_state", String[]))
    touched = Set(Git.changed_paths(root, range, Preflight.covered_paths(cfg)))
    suspects = copy(pending)
    for f in findings_of(dir)
        id = f["id"]
        (id in prev_open || id in pending || f["lane"] == "scans") && continue
        named = finding_files(root, f)
        # A finding that names no file in the tree cannot be checked against the diff, so it is re-verified
        # every pass rather than never: silence about where a defect lives is not evidence it is gone.
        (isempty(named) || any(x -> x in touched, named)) && push!(suspects, id)
    end
    return (sort!(unique(vcat(prev_open, suspects))), prev_open, suspects, range)
end

"""
    unswept(cfg, dir, ids, range) -> Vector{Pair{String,Vector{String}}}

Every open finding whose own named locations the fix pass did not touch. The arguments are:

- `cfg` — the validated config.
- `dir` — the round directory.
- `ids` — the ids the fix pass was meant to address; a seeded id and a `scans` id are skipped, the one
  never being fixed in the corpus and the other closing by rescan.
- `range` — the fix pass's commit range.

A finding names where its class lives; a fix that changes one of those files and none of the others has
fixed a line, and the verifiers have to spend a whole pass discovering it. Returns each id with the
files it names that the range left alone, empty when every id was swept.
"""
# The stamps `pass open --regrade` re-stamps, and whether the tag moved: every stamp that moved, except a
# `tool_tree_sha` that moved under an unchanged released `tool_version` — the tag itself moving, which
# `close` refuses as abandon-only; re-stamping it once let refuse, regrade, close pass the round on it.
function restamped(st::AbstractDict, rec::AbstractDict)
    moved = [x for x in ("config_sha", "tool_version", "tool_rev", "tool_tree_sha") if st[x] != get(rec, x, nothing)]
    tag_moved = "tool_tree_sha" in moved && st["tool_version"] == get(rec, "tool_version", nothing) && !startswith(st["tool_version"], "dev")
    return (tag_moved ? filter(!=("tool_tree_sha"), moved) : moved), tag_moved
end

function unswept(cfg::AbstractDict, dir::AbstractString, ids::AbstractVector, range::AbstractString)
    root = cfg["root"]
    # the diff is asked for the WHOLE tree: scoping it to the covered paths while the named set is not
    # scoped at all makes a fix outside them — a policy file, a catalogue, an instrument — never clear
    touched = Set(Git.changed_paths(root, range, String[]))
    out = Pair{String,Vector{String}}[]
    want = Set(String.(ids))
    for f in findings_of(dir)
        f["id"] in want || continue
        (get(f, "seeded", false) || f["lane"] == "scans") && continue   # never fixed in the corpus; closed by rescan
        named = finding_files(root, f)
        isempty(named) && continue                                      # nothing named: see `pass_scope`, which
                                                                        # re-verifies such a finding every pass
        missed = [x for x in named if !(x in touched)]
        isempty(missed) || push!(out, f["id"] => missed)
    end
    return out
end

"""
    pass_open(cfg, round; regrade = false, sweep_ok = false, full_state = false, io = stdout) -> Int

`gbg round pass open <round> [--regrade] [--sweep-ok] [--full-state]`: opens a verification pass. The arguments are:

- `cfg` — the validated config.
- `round` — the round id.
- `full_state` — kept for the command line; it changes nothing, since the state verifier
  ([`GBGCodingTools.Passes`](@ref) binds both verifiers) reads every id in scope on every pass.
- `regrade` — accept a changed stamp (`config_sha`, or the tool stamps) and re-stamp it; the round is
  re-graded from here, and the pass records `regrade = true`.
- `sweep_ok` — open even though an open finding names a file the fix pass did not touch
  (`Passes.unswept`), for the fix that rightly lives somewhere else.
- `io` — where the calls and messages are printed.

A pass after the first verifies only what `Passes.pass_scope` returns, and refuses to open at all
while an open finding's own named locations are untouched by every fix pass since bank, since a pass
spent discovering that a fix stopped at the line it quoted is a pass wasted.

The act verifier grades the OPEN ids against this fix
pass's diff; a closed id back in scope is a re-check, read by the state verifier alone, because the
question is whether it regressed and its fix is not in this diff. It refuses, too, once the pass budget
is spent (`pass_budget`): the round then closes by carrying what is still open.

It refuses a changed `config_sha` unless `regrade`, and a regrade never re-stamps a `tool_tree_sha` that
moved under an unchanged released `tool_version` — the tag moving, which `close` refuses; it creates
`verdicts/pass-<k>/pass.toml` with the
nonce, `head`, `range = <opening head>..HEAD`, the scope, the expected verdict count per lane and the
stamps; for
the doc instruments rebuilds under `GBG_ROUND` and regenerates the manuscripts; writes the findings'
unabridged text as a payload file; prints the verifiers' Workflow calls rendered by Preflight's
renderer. Returns the exit code.
"""
function pass_open(cfg::AbstractDict, round::AbstractString; regrade::Bool = false, sweep_ok::Bool = false,
                   full_state::Bool = false, io::IO = stdout)
    dir, rec = Rounds.guard(cfg, round; io, allow_config_change = regrade)
    haskey(rec, "banked") || (println(io, "pass open: $round is not banked yet"); return 2)
    root = cfg["root"]; inst = rec["instrument"]
    k = rec["passes"] + 1; pd = pass_dir(dir, k); mkpath(joinpath(pd, "act")); mkpath(joinpath(pd, "state"))
    st = Preflight.stamps(cfg; record = rec)
    if regrade
        moved, tag_moved = restamped(st, rec)
        tag_moved && println(io, "pass open --regrade: the tool's tree hash moved under the same version — the tag moved; not re-stamped, and close will refuse the round as abandon-only")
        for x in moved; rec[x] = st[x]; end
        println(io, "pass open --regrade: re-stamped ", isempty(moved) ? "nothing (the stamps had not moved)" : join(moved, ", "))
    end
    head = something(Git.head(root), "0"^40)
    all_findings = findings_of(dir)
    scope, prev_open, suspects, fixrange = pass_scope(cfg, dir, rec, k)
    # the pass budget: past it, what is still open is carried at close rather than verified again
    counted = !(regrade && isempty(Git.changed_paths(root, fixrange, Preflight.covered_paths(cfg))))
    used, cap = pass_budget(cfg, dir, rec, k)
    if cap > 0 && counted && used >= cap
        isfile(joinpath(pd, "pass.toml")) || rm(pd; recursive = true, force = true)
        println(io, "pass open: refused — the pass budget is spent ($used of $cap). gbg round close $round carries every id still open into the next $inst round.")
        return 2
    end
    # A CLOSED id back in scope is asked whether it REGRESSED, and only the state verifier can answer:
    # the act verifier reads this fix pass's diff, where a fix made in an earlier pass is not, so all it
    # could say is UNDONE — 22 of 2026-09-10-check-docs-03's 40 ids closed by adjudication for that alone.
    rechecked = scope === nothing ? String[] : suspects
    # Never on an audit round: its concerns are disposed and its tree must NOT move, so nothing is ever
    # touched, every concern naming a covered file counts as unswept, and no audit pass could open at all.
    if !sweep_ok && inst != "audit-changes"
        # every fix pass since bank, not only this one: a location fixed and swept in pass 1 is not
        # "untouched" at pass 2 (13 ids of 2026-09-10-check-docs-03 needed --sweep-ok for that alone)
        sincebank = "$(rec["head"])..$head"
        missed = unswept(cfg, dir, isempty(prev_open) && scope === nothing ? [f["id"] for f in all_findings] : prev_open, sincebank)
        if !isempty(missed)
            println(io, "pass open: refused — the fix passes since bank ($sincebank) left a named location of an open finding untouched:")
            for (id, fs) in missed; println(io, "  $id — ", join(fs, ", ")); end
            println(io, "Fix the CLASS at every location the finding names, or re-open with --sweep-ok when the fix rightly lives elsewhere.")
            return 2
        end
    end
    findings = scope === nothing ? all_findings : [f for f in all_findings if f["id"] in scope || f["lane"] == "scans"]
    if scope !== nothing
        println(io, "pass $k scope: $(length(prev_open)) still open", isempty(suspects) ? "" : ", $(length(suspects)) closed id(s) re-checked because the fix pass touched what they name",
                " — $(length(all_findings) - length(findings)) finding(s) carried forward closed")
    end
    expected_act = Dict{String,Int}(); expected_state = Dict{String,Int}()
    for f in findings
        expected_state[f["lane"]] = get(expected_state, f["lane"], 0) + 1
        (get(f, "seeded", false) || f["id"] in rechecked) || (expected_act[f["lane"]] = get(expected_act, f["lane"], 0) + 1)
    end
    # The state verifier reads the whole scope every pass: the open ids, and the closed ones back in scope,
    # which only it can answer for (above). An id it does not read is `pending_state` at grade and is
    # re-read next pass; `close` refuses while one remains. `full_state` is kept for the command line and
    # changes nothing: the scope is already everything this pass owes a reading.
    j_prev = last_graded(dir, k)
    last_pass = cap > 0 && used + 1 >= cap
    state_findings = findings
    if k > 1 && !isfile(joinpath(pass_dir(dir, k - 1), "tally.json"))
        println(io, "pass open: pass $(k - 1) was opened and never graded — its build and payloads bought nothing. Grade every pass, or the loop pays for verdicts it never reads.")
    end
    nonce = bytes2hex(rand(RandomDevice(), UInt8, 16))
    pass = merge(Dict{String,Any}("pass" => k, "nonce" => nonce, "opened" => Rounds.timestamp(), "head" => head, "range" => "$(rec["head"])..$head",
                                  "fix_range" => fixrange, "state_ids" => [f["id"] for f in state_findings],
                                  "rechecked" => rechecked, "counted" => counted,
                                  "expected" => expected_state, "regrade" => regrade),
                 (scope === nothing ? Dict{String,Any}() : Dict{String,Any}("scope" => scope)),
                 Dict(x => st[x] for x in ("tool_version", "tool_rev", "tool_tree_sha", "config_sha")))
    errs = validate(load_schema("pass"), pass); isempty(errs) || throw(RoundError("pass.toml would not validate: " * join(errs, "; ")))
    open(joinpath(pd, "pass.toml"), "w") do f; TOML.print(f, pass); end
    k > 1 && begin
        prev = joinpath(pass_dir(dir, k - 1), "pass.toml")
        if isfile(prev); p = TOML.parsefile(prev); p["superseded_by"] = k; open(prev, "w") do f; TOML.print(f, p); end; end
    end
    rec["passes"] = k; Rounds.save(dir, rec)
    graded_sha = rec["findings_sha"]
    payload = joinpath(Preflight.payload_dir(cfg, round), "pass-$k"); mkpath(payload)
    fpath = findings_text_file(joinpath(payload, "findings.md"), findings)
    ledger = Ledger.read(cfg)
    probe = Dict{String,Any}(f["id"] => quote_probe(root, f) for f in findings if f["lane"] != "scans")
    candidates = Dict{String,Any}(f["id"] => class_candidates(cfg, f) for f in findings if f["lane"] != "scans")
    open(joinpath(pd, "probe.json"), "w") do fh
        JSON3.pretty(fh, JSON3.write(Dict("quote_still_stands" => probe, "class_candidates" => candidates))); println(fh)
    end
    base = Dict{String,Any}("schema_version" => 1, "round" => round, "round_dir" => dir, "pass_dir" => pd, "repo" => root, "nonce" => nonce,
                            "quote_probe" => probe, "class_candidates" => candidates,
                            "graded_sha256" => graded_sha, "package" => Preflight.package_block(cfg), "models" => Dict("economy" => Preflight.economy_model()),
                            "strength" => rec["strength"], "adjudicated_titles" => Preflight.adjudicated_titles(cfg, ledger), "findings_path" => fpath)
    wdir = Preflight.workflow_dir(cfg, round)
    println(io, "pass $k opened for $round — nonce $nonce, range $(pass["range"])")
    if inst in ("check-consistency", "check-docs")
        manuscripts = nothing
        if inst == "check-consistency"
            full = joinpath(payload, "manuscript-full.md"); site = joinpath(payload, "manuscript-siteonly.md")
            # A build and a manuscript are a function of the tree. A pass that opens at the same clean HEAD
            # as the last one rebuilds the site and re-consolidates it to produce the same bytes; a regrade
            # or an ungraded pass paid that twice for nothing. Reuse is refused on a dirty tree, where HEAD
            # names nothing about what would be built.
            prevp = k > 1 ? joinpath(Preflight.payload_dir(cfg, round), "pass-$(k - 1)") : ""
            keyf = joinpath(payload, "build.key"); prevkey = joinpath(prevp, "build.key")
            reuse = k > 1 && isempty(Git.porcelain(root)) && isfile(prevkey) && chomp(read(prevkey, String)) == head &&
                    isfile(joinpath(prevp, "manuscript-full.md")) && isfile(joinpath(prevp, "manuscript-siteonly.md"))
            if reuse
                cp(joinpath(prevp, "manuscript-full.md"), full; force = true)
                cp(joinpath(prevp, "manuscript-siteonly.md"), site; force = true)
                println(io, "pass open: HEAD has not moved since pass $(k - 1) and the tree is clean — the build and both manuscripts are reused")
            else
                log = joinpath(Preflight.scratch_dir(cfg, round), "pass-$k-build.log")
                code = Rounds.run_under_round(cfg, round, cfg["package"]["docs_build"]; log)
                code == 0 || (println(io, "pass open: the docs build failed (exit $code) — see $log; the pass stays open, fix and re-run pass open"); return 2)
                build = joinpath(root, cfg["surfaces"]["built_html"])
                consolidate(build, String.(cfg["instruments"]["check-consistency"]["design_docs_withheld"]); out_full = full, out_siteonly = site)
            end
            isempty(Git.porcelain(root)) && write(keyf, head)
            manuscripts = Dict("full" => full, "siteonly" => site)
        end
        lanes = [Dict("nn" => lpad(i, 2, '0'), "key" => r["key"], "substrate" => get(r, "substrate", "")) for (i, r) in enumerate(rec["roster"])
                 if !get(r, "not_applicable", false) && (get(expected_state, r["key"], 0) > 0 || r["key"] == "scans")]
        inst == "check-docs" && pushfirst!(lanes, Dict("nn" => "00", "key" => "scans", "substrate" => "scans"))
        # the act verifier reads the diff of THIS fix pass, not of the round: at pass 15 of
        # 2026-09-09-check-docs-02 `range` was 456 files and 36,559 insertions where the work was 9 files
        # and 499, and every lane agent re-read all of it to grade six ids
        act = merge(base, Dict("range" => fixrange, "mode" => "lanes",
                    "lanes" => [Dict("nn" => l["nn"], "key" => l["key"], "expected" => get(expected_act, l["key"], 0)) for l in lanes if l["key"] != "scans" && get(expected_act, l["key"], 0) > 0],
                    "findings" => [Dict("id" => f["id"], "lane" => f["lane"], "n" => f["n"], "title" => f["title"]) for f in findings if !get(f, "seeded", false) && f["lane"] != "scans" && !(f["id"] in rechecked)]))
        expected_blind = Dict{String,Int}()
        for f in state_findings; f["lane"] == "scans" || (expected_blind[f["lane"]] = get(expected_blind, f["lane"], 0) + 1); end
        state = merge(base, Dict("lanes" => [Dict("nn" => l["nn"], "key" => l["key"], "substrate" => l["substrate"], "expected" => get(expected_blind, l["key"], 0)) for l in lanes if l["key"] != "scans" && get(expected_blind, l["key"], 0) > 0],
                      "findings" => [Dict("id" => f["id"], "lane" => f["lane"], "n" => f["n"], "title" => f["title"], "seeded" => get(f, "seeded", false)) for f in state_findings if f["lane"] != "scans"],
                      "source_scope" => ["src", "ext", "docs/src", "docs"]))
        manuscripts === nothing || (state["manuscripts"] = manuscripts)
        Preflight.save_args(cfg, round, "pass-$k-act", act); Preflight.save_args(cfg, round, "pass-$k-state", state)
        nact = length(act["findings"])
        last_pass && println(io, "\nThis is pass $(used + 1) of $cap: whatever is still open after it is carried into the next $inst round at close.")
        println(io, nact > 0 ? "\nLaunch BOTH verifiers exactly as printed — the act verifier grades the $nact open id(s) against this fix pass's diff; the state verifier reads all $(length(state_findings)) in scope, the $(length(rechecked)) re-checked closed id(s) among them — then gbg round grade $round:\n" :
                              "\nNo id is open, so the act verifier has nothing to grade. Launch the state verifier exactly as printed — it reads the $(length(rechecked)) re-checked closed id(s) for regression — then gbg round grade $round:\n")
        nact > 0 && println(io, Preflight.workflow_call(joinpath(wdir, "verify-act.js"), act), "\n")
        println(io, Preflight.workflow_call(joinpath(wdir, "verify-state.js"), state))
        println(io, "\n(lane 00-scans is closed by rescan at grade, never by a verdict)")
    elseif inst == "bug-hunt"
        arch = [f for f in findings if get(f, "kind", "") == "architecture"]
        for f in arch
            rp = joinpath(dir, "reproductions", replace(f["id"], "/" => "__", "#" => "_") * ".json")
            isfile(rp) && (f["claimed_fix"] = get(get(read_json(rp), "disposition", Dict()), "reason", ""))
        end
        findings_text_file(joinpath(payload, "findings.md"), findings)
        if isempty(arch)
            println(io, "no architecture-class finding: the runtime and api-semantics classes re-run mechanically at grade; run gbg round grade $round")
        else
            a = merge(base, Dict("range" => pass["range"], "findings" => [Dict("id" => f["id"], "title" => f["title"]) for f in arch]))
            delete!(a, "adjudicated_titles"); delete!(a, "strength"); delete!(a, "round_dir")
            Preflight.save_args(cfg, round, "pass-$k-architecture", a)
            println(io, "\nLaunch the architecture verifier exactly as printed, then gbg round grade $round:\n")
            println(io, Preflight.workflow_call(joinpath(wdir, "verify-architecture.js"), a))
        end
    else
        println(io, "an audit round has no adversarial verifier (§6.8): the disposition gate is the closure — record dispositions in audit.json, then gbg round grade $round")
    end
    return 0
end

# ---- grade -------------------------------------------------------------------------------------------------

function read_verdicts(pd, kind, lane, nonce, sha, schema_name)
    p = joinpath(pd, kind, lane * ".json")
    isfile(p) || return (:dead, nothing, "absent")
    d = try read_json(p) catch; return (:dead, nothing, "unparsable") end
    errs = validate(load_schema(schema_name), d)
    isempty(errs) || return (:dead, nothing, "invalid: " * first(errs))
    d["pass_nonce"] == nonce || return (:rejected, nothing, "pass_nonce mismatch (a copy-forward verdict)")
    d["graded_sha256"] == sha || return (:rejected, nothing, "graded_sha256 mismatch (graded against another finding set)")
    return (:ok, d, "")
end

# the first 40 characters (never bytes: a hit's text carries Greek and math glyphs) of a hit's quoted line
hit_needle(text::AbstractString) = first(strip(last(split(text, ": "))), 40)

function rescan_alive(cfg, f)
    m = match(r"^(SCAN\.[A-Z0-9_.]+) — ", f["title"]); m === nothing && return true
    id = m.captures[1]
    row = findfirst(r -> r["id"] == id, scan_catalog())
    row === nothing && return true
    r = run_scan(cfg, scan_catalog()[row])
    loc = first(f["locations"]); file = first(split(loc, ':'))
    return any(h -> h.file == file && occursin(hit_needle(h.text), loc), r.hits) || any(h -> h.file == file, r.hits) && length(r.hits) > 0
end

function ledger_adjudication(ledger, id, opened::AbstractString)
    od = Date(first(opened, 10))
    for e in ledger
        e["scope"] == "finding" && e["target"] == id && e["recorded"] >= od && length(e["reason"]) >= 40 && haskey(e, "overturn_when") && return e
    end
    return nothing
end

"""
    grade(cfg, round; io = stdout) -> Int

`gbg round grade <round>`: grades the latest pass. The arguments are:

- `cfg` — the validated config.
- `round` — the round id.
- `io` — where the tally lines are printed.

It validates the pass's verdict files (a wrong nonce or sha is REJECTED, an absent file with a
non-zero expectation is DEAD ⇒ exit 2), carries forward the entry of every id outside the pass's
`scope` (they were closed and nothing since went near what they name), applies the demotion to the
rest, then the closure channels per id —
`honored`, `adjudicated`, `seeded`, `rescan`; for a hunt the disposition records and the witness
re-run; for an audit the disposition gate after the severity re-check — and writes `tally.json` and
`tally.md` with the pass series and the plateau signal.

A re-checked id — closed earlier, back in scope — keeps the act verdict that closed it: it stays closed
while the state verifier still reads it absent, and reopens when that reading finds it back.

Exit 1 while `open_ids` is non-empty, and equally while any id is `pending_state` — read by the act
verifier and not by the state verifier, the two verifiers [`GBGCodingTools.Passes`](@ref) binds — 0 only
when every id is closed.
"""
function grade(cfg::AbstractDict, round::AbstractString; io::IO = stdout)
    dir, rec = Rounds.guard(cfg, round; io, allow_config_change = true)
    k = rec["passes"]; k >= 1 || (println(io, "grade: no pass opened yet — gbg round pass open $round"); return 2)
    pd = pass_dir(dir, k); pass = TOML.parsefile(joinpath(pd, "pass.toml"))
    if !get(pass, "regrade", false) && Preflight.config_sha(cfg) != rec["config_sha"]
        println(io, "grade: the config stamp moved since the round opened — .gbg/config.toml, .gbg/hats/ or .gbg/exemptions.toml ",
                "changed, and a new ledger entry moves it too. Pass $k cannot be graded under it: gbg round pass open $round ",
                "--regrade opens pass $(k + 1), and pass $k's verdicts are set aside ungraded."); return 2
    end
    inst = rec["instrument"]; all_findings = findings_of(dir); ledger = Ledger.read(cfg)
    # A scoped pass verifies the open ids and the closed ones the fix pass touched again; every other
    # id keeps the entry the pass that closed it wrote, so a closed finding does not reopen for want of
    # a verdict nobody was asked for.
    scope = get(pass, "scope", nothing)
    carried = Dict{String,Any}()
    if scope !== nothing
        j = last_graded(dir, k)
        j == 0 || (carried = Dict{String,Any}(String(i) => e for (i, e) in read_json(joinpath(pass_dir(dir, j), "tally.json"))["per_id"] if !(String(i) in scope)))
    end
    findings = scope === nothing ? all_findings : [f for f in all_findings if f["id"] in scope || f["lane"] == "scans"]
    # a closed id back in scope keeps the act verdict that closed it; only its state reading is fresh
    rechecked = Set(String.(get(pass, "rechecked", String[])))
    jp = last_graded(dir, k)
    prevper = jp == 0 ? Dict{String,Any}() : Dict{String,Any}(read_json(joinpath(pass_dir(dir, jp), "tally.json"))["per_id"])
    per_id = copy(carried); dead = String[]; rejected = String[]; demoted = 0; adjudicated = 0; pending = String[]
    # the rates are over the ROUND, not over this pass: counting a scoped pass's demotions and
    # adjudications against a denominator of every banked id writes a zero rate into the tally that
    # `gbg fleet --diff` compares, for a round that adjudicated half its findings in an earlier pass
    for e in values(carried)
        get(e, "act_demoted", false) && (demoted += 1)
        get(e, "closed_by", nothing) == "adjudicated" && (adjudicated += 1)
    end
    opened = rec["opened"]
    if inst in ("check-consistency", "check-docs")
        lanes = unique(f["lane"] for f in findings if f["lane"] != "scans")
        acts = Dict{String,Any}(); states = Dict{String,Any}()
        for lane in lanes
            nn = something(findfirst(r -> r["key"] == lane, rec["roster"]), 0); nnlabel = lpad(nn, 2, '0')
            exp_act = count(f -> f["lane"] == lane && !get(f, "seeded", false) && !(f["id"] in rechecked), findings); exp_state = count(f -> f["lane"] == lane, findings)
            if exp_act > 0
                st, d, note = read_verdicts(pd, "act", "$nnlabel-$lane", pass["nonce"], rec["findings_sha"], "verdict-act")
                st == :ok ? (for v in d["verdicts"]; acts[v["id"]] = v; end) : st == :rejected ? push!(rejected, "act/$nnlabel-$lane: $note") : push!(dead, "act/$nnlabel-$lane: $note")
            end
            if exp_state > 0
                st, d, note = read_verdicts(pd, "state", "$nnlabel-$lane", pass["nonce"], rec["findings_sha"], "verdict-state")
                st == :ok ? (for v in d["verdicts"]; states[v["id"]] = v; end) : st == :rejected ? push!(rejected, "state/$nnlabel-$lane: $note") : push!(dead, "state/$nnlabel-$lane: $note")
            end
        end
        for f in findings
            id = f["id"]; entry = Dict{String,Any}("act" => nothing, "act_demoted" => false, "state" => nothing, "closed_by" => nothing)
            if f["lane"] == "scans"
                alive = rescan_alive(cfg, f)
                if !alive
                    m = match(r"^(SCAN\.[A-Z0-9_.]+) — ", f["title"]); sid = m === nothing ? "" : m.captures[1]
                    e = findfirst(x -> x["id"] == sid && x["scope"] == "scan" && x["recorded"] >= Date(first(opened, 10)), ledger)
                    if e === nothing; entry["closed_by"] = "rescan" else entry["closed_by"] = "adjudicated"; entry["adjudicated_entry"] = "$(ledger[e]["id"])@$(ledger[e]["target"])"; adjudicated += 1; end
                end
                per_id[id] = entry; continue
            end
            a = get(acts, id, nothing); s = get(states, id, nothing)
            if a !== nothing
                a2, dm = demote(a); entry["act"] = a2["verdict"]; entry["act_demoted"] = dm; dm && (demoted += 1)
            end
            s === nothing || (entry["state"] = s["verdict"])
            fav = s !== nothing && s["verdict"] in FAVOURABLE
            # A re-check asks whether a closed id REGRESSED. The act verdict that closed it stands — its fix
            # is outside this pass's range, so the act verifier was not asked (`pass_open`) — and the blind
            # reading decides: still absent, it stays closed; back, it reopens for the next fix pass.
            prev = get(prevper, id, nothing)
            if id in rechecked && !get(f, "seeded", false) && prev !== nothing && get(prev, "act", nothing) == "HONORED"
                entry["act"] = "HONORED"; entry["rechecked"] = true
                if s === nothing
                    push!(pending, id)
                elseif fav
                    entry["closed_by"] = "honored"
                else
                    e = ledger_adjudication(ledger, id, opened)
                    e !== nothing && (entry["closed_by"] = "adjudicated"; entry["adjudicated_entry"] = "$(e["id"])@$(e["target"])"; adjudicated += 1)
                end
                per_id[id] = entry; continue
            end
            # the state verifier judges the open ids mid-round (`pass.toml`'s `state_ids`); an id the act
            # verifier closed without one is PENDING — it drives no fix pass and closes no round, and
            # `close` refuses while one stands, so the last pass is always a full blind sweep
            # `per_id.state` is a closed vocabulary (§6.3) and holds what a verifier SAID; an id nobody
            # was asked about is recorded in the tally's own `pending_state`, not by widening the set
            asked = !haskey(pass, "state_ids") || id in pass["state_ids"]
            if !asked && s === nothing && entry["act"] == "HONORED"
                push!(pending, id); per_id[id] = entry; continue
            end
            if get(f, "seeded", false)
                fav && (entry["closed_by"] = "seeded")
            elseif entry["act"] == "HONORED" && fav
                entry["closed_by"] = "honored"
            else
                e = ledger_adjudication(ledger, id, opened)
                e !== nothing && (entry["closed_by"] = "adjudicated"; entry["adjudicated_entry"] = "$(e["id"])@$(e["target"])"; adjudicated += 1)
            end
            per_id[id] = entry
        end
    elseif inst == "bug-hunt"
        project = Witnesses.witness_project(cfg["root"], cfg["instruments"]["bug-hunt"]["witness_env"], cfg["package"]["name"])
        st, arch, note = (any(f -> get(f, "kind", "") == "architecture", findings) ? read_verdicts(pd, "act", "architecture", pass["nonce"], rec["findings_sha"], "architecture-fix") : (:ok, Dict("verdicts" => []), ""))
        st == :ok || (st == :rejected ? push!(rejected, "act/architecture: $note") : push!(dead, "act/architecture: $note"))
        archv = st == :ok ? Dict(v["id"] => v for v in arch["verdicts"]) : Dict{String,Any}()
        for f in findings
            id = f["id"]; entry = Dict{String,Any}("act" => nothing, "act_demoted" => false, "state" => nothing, "closed_by" => nothing)
            rp = joinpath(dir, "reproductions", replace(id, "/" => "__", "#" => "_") * ".json")
            disp = isfile(rp) ? get(read_json(rp), "disposition", Dict("state" => "open")) : Dict("state" => "open")
            dstate = get(disp, "state", "open")
            if dstate == "refused" && length(get(disp, "reason", "")) >= 24
                entry["closed_by"] = "adjudicated"; entry["adjudicated_entry"] = "reproductions: refused"; adjudicated += 1
            elseif dstate == "escalated" && haskey(disp, "overturn_when")
                entry["closed_by"] = "adjudicated"; entry["adjudicated_entry"] = "reproductions: escalated"; adjudicated += 1
            elseif dstate == "fixed"
                if get(f, "kind", "") == "architecture"
                    v = get(archv, id, nothing); entry["act"] = v === nothing ? nothing : v["verdict"]
                    v !== nothing && v["verdict"] == "FIXED" && (entry["closed_by"] = "honored")
                else
                    wp = joinpath(dir, get(f, "witness_path", ""))
                    if isfile(wp)
                        code, results = Witnesses.run(dirname(wp); expect = :pass, package = cfg["package"]["name"], project, names = [basename(wp)], io = devnull)
                        r = isempty(results) ? nothing : first(results)
                        entry["state"] = r === nothing ? nothing : uppercase(String(r.status))
                        r !== nothing && r.status == :pass && (entry["closed_by"] = "honored")
                    end
                end
            end
            per_id[id] = entry
        end
    else
        audit = isfile(joinpath(dir, "audit.json")) ? read_json(joinpath(dir, "audit.json")) : Dict{String,Any}("dispositions" => Dict())
        sev = isfile(joinpath(dir, "severity.json")) ? severity_ratings(dir) : nothing
        sev === nothing && !isempty(findings) && (println(io, "grade: the severity re-check has not run — gbg audit-changes bank $round printed its Workflow call; run it first (\"serious\" is counted after the re-check)"); return 2)
        rank = Dict("blocker" => 4, "major" => 3, "minor" => 2, "nit" => 1)
        for f in findings
            id = f["id"]; entry = Dict{String,Any}("act" => nothing, "act_demoted" => false, "state" => nothing, "closed_by" => nothing)
            s = max(rank[f["severity"]], rank[get(sev, id, f["severity"])])
            gated = s >= 3 || get(f, "previously_worked", "no") in ("yes", "unknown")
            disp = get(audit["dispositions"], id, nothing)
            if !gated
                entry["closed_by"] = "honored"
            elseif disp !== nothing && (disp["state"] == "fixed" || (disp["state"] == "refused" && length(get(disp, "reason", "")) >= 24) || (disp["state"] == "escalated" && haskey(disp, "overturn_when")))
                entry["closed_by"] = disp["state"] == "fixed" ? "honored" : "adjudicated"; disp["state"] != "fixed" && (entry["adjudicated_entry"] = "audit.json: " * disp["state"]; adjudicated += 1)
            end
            per_id[id] = entry
        end
    end
    if !isempty(dead) || !isempty(rejected)
        foreach(d -> println(io, "  DEAD      ", d), dead); foreach(r -> println(io, "  REJECTED  ", r), rejected)
        println(io, "grade: the pass is incomplete — re-launch the verifier(s) named above for this pass (same nonce), then grade again")
        isempty(dead) || return 2
    end
    pending_state = sort!(unique(pending))
    open_ids = sort!([id for (id, e) in per_id if e["closed_by"] === nothing && !(id in pending_state)])
    prev_open = k > 1 && isfile(joinpath(pass_dir(dir, k - 1), "tally.json")) ? length(read_json(joinpath(pass_dir(dir, k - 1), "tally.json"))["open_ids"]) : -1
    flat = 0
    for j in k-1:-1:1
        tj = joinpath(pass_dir(dir, j), "tally.json"); isfile(tj) || break
        length(read_json(tj)["open_ids"]) == length(open_ids) ? (flat += 1) : break
    end
    bank = isfile(joinpath(dir, "bank.json")) ? read_json(joinpath(dir, "bank.json")) : Dict{String,Any}()
    closed = count(e -> e["closed_by"] !== nothing, values(per_id))
    tally = Dict{String,Any}("schema_version" => 1, "round" => round, "pass" => k, "per_id" => per_id,
        "totals" => Dict("findings" => length(all_findings), "seeded" => count(f -> get(f, "seeded", false), all_findings), "closed" => closed, "open" => length(open_ids)),
        "demoted_by_rule" => demoted, "adjudicated_share" => isempty(all_findings) ? 0.0 : adjudicated / length(all_findings),
        "suspect_hats" => get(bank, "suspect_hats", String[]), "dead_lanes" => dead, "rejected_files" => rejected, "open_ids" => open_ids,
        "pending_state" => pending_state,
        "plateau" => Dict("passes_flat" => flat), "recall" => get(bank, "recall", Dict()))
    errs = validate(load_schema("tally"), tally); isempty(errs) || throw(RoundError("tally.json would not validate: " * join(errs, "; ")))
    write_json(joinpath(pd, "tally.json"), tally)
    md = IOBuffer()
    println(md, "# Tally — $round pass $k\n\n$(closed)/$(length(all_findings)) closed, $(length(open_ids)) open; demoted by rule: $demoted; adjudicated share: $(Base.round(tally["adjudicated_share"]; digits = 2)); plateau: $flat pass(es) flat.\n")
    for id in sort!(collect(keys(per_id)))
        e = per_id[id]
        println(md, "- `$id` act=$(something(e["act"], "—"))$(e["act_demoted"] ? " (demoted)" : "") state=$(something(e["state"], "—")) → $(something(e["closed_by"], "OPEN"))", haskey(e, "adjudicated_entry") ? " [$(e["adjudicated_entry"])]" : "")
    end
    write(joinpath(pd, "tally.md"), String(take!(md)))
    series = join(("pass $j: $(length(read_json(joinpath(pass_dir(dir, j), "tally.json"))["open_ids"])) open" for j in 1:k if isfile(joinpath(pass_dir(dir, j), "tally.json"))), " → ")
    println(io, "grade: $series")
    flat >= 2 && println(io, "grade: PLATEAU — the open count has not moved for $flat passes; adjudicate what is not a defect, or gbg round abandon")
    isempty(open_ids) || (println(io, "grade: $(length(open_ids)) open id(s): ", join(open_ids, ", ")); return 1)
    isempty(pending_state) || (println(io, "grade: 0 open, $(length(pending_state)) awaiting a state reading — gbg round pass open $round (the next pass sweeps them; nothing closes on the act verifier alone)"); return 1)
    println(io, "grade: every id closed — gbg round close $round"); return 0
end

# ---- close -------------------------------------------------------------------------------------------------

"""
    audit_after_code(cfg, rec) -> Vector{String}

`RULE.INST.AUDIT_AFTER_CODE` for a documentation round: the refusals when the fix pass of the round
`rec` changed code and no closed `/audit-changes` round based at its opening head read the LAST of that
code — an audit closed before a later fix pass touched `src` or `ext` again covers what it saw, not what
came after. The arguments are `cfg`, the validated config, and `rec`, the round record. A pass that
touched only prose is not gated. Returns the refusals, empty when none applies.
"""
function audit_after_code(cfg::AbstractDict, rec::AbstractDict)
    root = cfg["root"]
    dirs = code_dirs(cfg)
    isempty(dirs) && return String[]
    touched = Git.changed_paths(root, "$(rec["head"])..HEAD", dirs)
    isempty(touched) && return String[]
    base = first(rec["head"], 8)
    exists, covers = audit_coverage(cfg, rec["head"], dirs)
    covers && return String[]
    exists || return ["the fix pass changed code (" * join(first(touched, 3), ", ") * (length(touched) > 3 ? ", …" : "") *
                      ") and no closed audit-changes round has base = $base — run /audit-changes --base $base and close it"]
    return ["the audit based at $base does not cover the round's last code change — run /audit-changes --base $base again after the last fix pass, and close it"]
end

# the leading directory of each `src`/`ext` surface glob (`src/**/*.jl` → `src`), as git pathspecs
code_dirs(cfg::AbstractDict) = unique(filter(!isempty, [rstrip(String(first(split(String(g), r"[*?\[]"; limit = 2))), '/')
                                                        for g in vcat(get(cfg["surfaces"], "src", String[]), get(cfg["surfaces"], "ext", String[]))]))

"""
    audit_coverage(cfg, head, dirs) -> (exists, covers)

Whether a closed `/audit-changes` round is based at the commit `head`, and whether one of them read the
last change under `dirs`. The arguments are:

- `cfg` — the validated config.
- `head` — the opening head of the round that needs the audit.
- `dirs` — the code paths the audit must cover, as git pathspecs.

An audit covers what it saw: one closed before a later fix touched `dirs` again leaves that change
unaudited, and an audit whose head is unreachable proves nothing either way. With no `dirs` there is no
later change to miss, so any based audit covers. Returns the two flags.
"""
function audit_coverage(cfg::AbstractDict, head::AbstractString, dirs::AbstractVector)
    root = cfg["root"]
    audits = [r for r in RoundFiles.rounds(cfg)
              if r.state == :closed && r.round["instrument"] == "audit-changes" && get(r.round, "base", "") == head]
    isempty(dirs) && return (!isempty(audits), !isempty(audits))
    covers = any(audits) do r
        ah = String(get(r.round, "head", ""))
        !isempty(ah) && Git.run(root, "cat-file", "-e", ah * "^{commit}") !== nothing &&
            isempty(Git.changed_paths(root, "$ah..HEAD", dirs))
    end
    return (!isempty(audits), covers)
end

"""
    carry_deferrals(cfg, dir, round; io = stdout) -> Int

Carries a round's deferrals into the session work queue (`RULE.INST.FROZEN_MIDROUND`). The arguments are:

- `cfg` — the validated config.
- `dir` — the round directory.
- `round` — the round id.
- `io` — where the carried lines are printed.

A fix pass that cannot make a change inside the round — an instrument change, which is its own commit and
release — writes one line per deferral in `<round>/deferred.md`; `#` lines and blank lines are ignored.
Each line becomes an open item of `.claude/WORK_QUEUE.md`, whose Stop hook then refuses to let a session
end while it stands, so a deferral outlives the context that made it. A line already in the queue is not
added twice. Returns the number of items added, zero when the file or the queue is absent.
"""
function carry_deferrals(cfg::AbstractDict, dir::AbstractString, round::AbstractString; io::IO = stdout)
    src = joinpath(dir, "deferred.md")
    queue = joinpath(cfg["root"], ".claude", "WORK_QUEUE.md")
    (isfile(src) && isfile(queue)) || return 0
    # An item is a BULLET, not a line: a bullet that wraps is one item, and prose outside every bullet is
    # not an item at all. Reading line by line turned one round's deferred.md into 38 queue fragments,
    # each half a sentence, and the Stop hook then held the session to prose.
    items = String[]
    for l in strip.(readlines(src))
        if startswith(l, "- ") || startswith(l, "* ")
            push!(items, strip(l[nextind(l, 1):end]))
        elseif !isempty(items) && !isempty(l) && !startswith(l, "#")
            items[end] *= " " * l                                  # the continuation of the bullet above
        end
    end
    items = [replace(i, r"\s+" => " ") for i in items if !isempty(i)]
    isempty(items) && return 0
    text = read(queue, String); added = 0
    open(queue, "a") do f
        for it in items
            body = "$it (deferred by $round)"
            occursin(body, text) && continue
            println(f, "- [ ] ", body); added += 1
        end
    end
    added > 0 && println(io, "close: carried $added deferral(s) into .claude/WORK_QUEUE.md — the Stop hook now holds the session to them")
    return added
end

function dismissal_items(cfg, dir, rec, findings, ledger)
    items = Dict{String,Any}[]
    od = Date(first(rec["opened"], 10))
    for e in ledger
        e["scope"] == "finding" && e["recorded"] >= od && push!(items, Dict("id" => e["target"], "title" => "ledger adjudication of $(e["target"])", "location" => get(e, "evidence", ""),
                                                                           "claim" => e["reason"], "verdict" => "adjudicated", "reasoning" => get(e, "overturn_when", "")))
    end
    rdir = joinpath(dir, "reproductions")
    if rec["instrument"] == "bug-hunt" && isdir(rdir)
        for f in readdir(rdir)
            r = read_json(joinpath(rdir, f))
            v = r["verdict"]; d = get(r, "disposition", Dict("state" => ""))
            if v in ("NOT-REPRODUCED", "WITNESS-WRONG", "NOT-A-DEFECT", "ALREADY-COVERED") || get(d, "state", "") == "refused"
                push!(items, Dict("id" => r["id"], "title" => r["title"], "location" => get(r, "witness_path", ""), "claim" => r["observed"],
                                  "verdict" => get(d, "state", "") == "refused" ? "refused" : v, "reasoning" => get(d, "state", "") == "refused" ? get(d, "reason", "") : get(r, "evidence", "")))
            end
        end
    end
    if rec["instrument"] == "audit-changes" && isfile(joinpath(dir, "audit.json"))
        for (id, d) in read_json(joinpath(dir, "audit.json"))["dispositions"]
            d["state"] == "refused" && push!(items, Dict("id" => id, "title" => "refused audit concern $id", "location" => "", "claim" => "", "verdict" => "refused", "reasoning" => get(d, "reason", "")))
        end
    end
    return items
end

# `dismissals.json` assembled by the CLI from the auditors' own files, for when the script's final writer
# did not write it. Each auditor writes its verdict to `vdir`, a directory the item set's sha names, so a
# file written for another item set is never read; the id is taken from the file name, never from what
# the model retyped. An item without a valid file is dead. Returns the object, or `nothing` when the
# directory holds no valid verdict at all.
function assemble_dismissals(items, vdir::AbstractString, round::AbstractString, sha::AbstractString)
    isdir(vdir) || return nothing
    vschema = load_schema("dismissal")["properties"]["verdicts"]["items"]
    verdicts = Dict{String,Any}[]; dead = String[]
    for it in items
        p = joinpath(vdir, replace(it["id"], "/" => "__", "#" => "_") * ".json")
        raw = isfile(p) ? (try read_json(p) catch; nothing end) : nothing
        v = raw isa AbstractDict ? Dict{String,Any}(k => raw[k] for k in ("verdict", "evidence", "what_would_bite") if haskey(raw, k)) : nothing
        v === nothing || (v["id"] = it["id"])
        v !== nothing && isempty(validate(vschema, v)) ? push!(verdicts, v) : push!(dead, it["id"])
    end
    isempty(verdicts) && return nothing
    tally = Dict{String,Any}(); for v in verdicts; tally[v["verdict"]] = get(tally, v["verdict"], 0) + 1; end
    reopened = [v["id"] for v in verdicts if v["verdict"] != "DISMISSAL-SOUND"]
    return Dict{String,Any}("schema_version" => 1, "round" => round, "items_sha" => sha, "tally" => tally, "verdicts" => verdicts,
                            "reopened" => reopened, "dead" => dead, "complete" => isempty(dead) && isempty(reopened))
end

function items_file(path, items)
    io = IOBuffer()
    for d in items
        println(io, "--- ", d["id"], " ---"); for k in ("title", "location", "claim", "verdict", "reasoning"); println(io, k, ": ", get(d, k, "")); end; println(io)
    end
    mkpath(dirname(path)); write(path, String(take!(io))); return path
end

"""
    carry_conditions(cfg, dir, rec, findings, carry, io; at_cap = false) -> (Vector{String}, Dict{String,String})

The refusals when a round would close by carrying the ids `carry`, and the re-rated severity of each.
The arguments are `cfg`, the validated config; `dir` and `rec`, the round's directory and record;
`findings`, the banked findings; `carry`, the ids asked for; `io`, where the launch line is printed; and
`at_cap`, whether the round has spent its pass budget (`pass_budget`).

Three conditions. The id must be OPEN, or `pending_state` — a closed one is not carried, it is done. Its
severity must have been re-rated by `severity-recheck.js`, whose ratings the CLI compares against the
lane's own; below the pass budget the re-rating must be `minor` or `nit`, a serious finding being fixed,
adjudicated or escalated rather than deferred, while past it any severity rides and severity decides
instead whether a final release may cite the round. And it must not already have been carried
[`CARRY_LIMIT`](@ref) times. Returns the refusals and the re-ratings.
"""
function carry_conditions(cfg::AbstractDict, dir::AbstractString, rec::AbstractDict, findings::AbstractVector,
                          carry::AbstractVector, io::IO; at_cap::Bool = false)
    fails = String[]; rerated = Dict{String,String}()
    k = rec["passes"]; tj = joinpath(pass_dir(dir, k), "tally.json")
    t = isfile(tj) ? read_json(tj) : Dict{String,Any}("open_ids" => String[])
    openids = Set(String.(vcat(t["open_ids"], get(t, "pending_state", String[]))))
    known = Dict(f["id"] => f for f in findings)
    for id in carry
        haskey(known, id) || (push!(fails, "--carry $id: no such banked finding"); continue)
        id in openids || push!(fails, "--carry $id: it is not open in pass $k; a closed finding is done, not carried")
    end
    sev = joinpath(dir, "severity.json")
    ratings = severity_ratings(dir)
    missing_ = [id for id in carry if !haskey(ratings, id) && haskey(known, id)]
    if !isempty(missing_)
        payload = joinpath(Preflight.payload_dir(cfg, rec["round"]), "severity"); mkpath(payload)
        ip = joinpath(payload, "items.md")
        open(ip, "w") do f
            for id in missing_
                x = known[id]
                println(f, "--- ", id, " ---"); println(f, "title: ", x["title"])
                for l in x["locations"]; println(f, "location: ", l); end
                println(f, "description: ", x["description"]); println(f)
            end
        end
        a = Dict{String,Any}("schema_version" => 1, "round" => rec["round"], "out" => sev,
                             "subject" => "the documentation of $(cfg["package"]["name"])",
                             "items" => [Dict("id" => id) for id in missing_], "items_path" => ip,
                             "models" => Dict("economy" => Preflight.economy_model()))
        Preflight.save_args(cfg, rec["round"], "severity", a)
        push!(fails, "the severity of $(length(missing_)) carry candidate(s) has not been re-rated — the reporting lane's own rating cannot license its own deferral. Launch:\n    " *
                     Preflight.workflow_call(joinpath(Preflight.workflow_dir(cfg, rec["round"]), "severity-recheck.js"), a) *
                     "\n  then close again with the same --carry")
    end
    led = carry_ledger(cfg); before = Dict(String(e["id"]) => e for e in led["carried"])
    for id in carry
        haskey(ratings, id) || continue
        rerated[id] = ratings[id]
        ratings[id] in ("minor", "nit") || at_cap ||
            push!(fails, "--carry $id: re-rated $(ratings[id]); below the pass budget a serious finding is fixed, adjudicated or escalated, never carried")
        e = get(before, id, nothing)
        e === nothing || Int(e["carries"]) < CARRY_LIMIT ||
            push!(fails, "--carry $id: carried $(e["carries"])× already (limit $CARRY_LIMIT) — this is not a deferral any more; escalate it")
    end
    return (fails, rerated)
end

"""
    close(cfg, round; carry = String[], io = stdout) -> Int

`gbg round close <round>`: checks every closing condition in the instrument's order and stamps the
round closed. The arguments are:

- `cfg` — the validated config.
- `round` — the round id.
- `io` — where the refusals are listed.

The conditions: the latest pass fully closed, no
dead lane, the round's files committed, the stamps unchanged (tool version and config, else regrade;
tool tree sha, else abandon-only), the opening head an ancestor of HEAD, the dismissal auditor run over
every adjudication and refusal with `reopened == []` (its Workflow call is printed when it has not
run), the hunt's witness, promotion, test and audit conditions, and for a check-docs round whose fix
pass changed code, [`Passes.audit_after_code`](@ref). Then `closed`, `closed_head` and the
tally sha are stamped.

`carry` names the ids this round closes by carrying them into the next round of its instrument, which
`carry_conditions` gates. Once the pass budget is spent (`pass_budget`) an empty `carry` means every
id still open or never blind-read, and a serious one rides too: its severity then decides whether a
final release may cite the round, not whether the round may close.

Returns 0 when closed, 1 when a condition is unmet — a moved `config_sha` or `tool_version` among them,
since a regrade answers those — and 2 for a `tool_tree_sha` that moved under an unchanged
`tool_version`, which is the tag itself moving.

That last one leaves the round abandon-only: `pass open --regrade` re-stamps `config_sha`,
`tool_version` and `tool_rev`, and never `tool_tree_sha` under an unchanged non-dev `tool_version`, so
no regrade can make a moved tag read as unmoved.
"""
function close(cfg::AbstractDict, round::AbstractString; carry::AbstractVector = String[], io::IO = stdout)
    dir, rec = Rounds.guard(cfg, round; io, allow_config_change = true)
    root = cfg["root"]; inst = rec["instrument"]; k = rec["passes"]
    fails = String[]; at_cap = false
    haskey(rec, "banked") || push!(fails, "not banked")
    tj = joinpath(pass_dir(dir, k), "tally.json")
    if k == 0 || !isfile(tj)
        push!(fails, "no graded pass")
    else
        t = read_json(tj)
        used, cap = pass_budget(cfg, dir, rec, k + 1)
        at_cap = cap > 0 && used >= cap
        pend = String.(get(t, "pending_state", String[]))
        # the budget is spent: every id still open, and every one never blind-read, is carried — no pass can
        # open to verify them, so waiting on one would leave the round unable to close at all
        if at_cap && isempty(carry) && !(isempty(t["open_ids"]) && isempty(pend))
            carry = sort!(unique(vcat(String.(t["open_ids"]), pend)))
            println(io, "close: the pass budget is spent ($used of $cap) — carrying the $(length(carry)) id(s) still open: ", join(carry, ", "))
        end
        stillopen = [id for id in t["open_ids"] if !(id in carry)]
        isempty(stillopen) || push!(fails, "$(length(stillopen)) open id(s) in pass $k" * (isempty(carry) ? "" : " beyond the $(length(carry)) carried"))
        unread = [p for p in pend if !(p in carry)]
        isempty(unread) || push!(fails, "$(length(unread)) id(s) the state verifier never read at this head — gbg round pass open $round, which sweeps them")
        isempty(t["dead_lanes"]) || push!(fails, "dead lane(s) in pass $k: " * join(t["dead_lanes"], ", "))
    end
    isempty(rec["dead_lanes"]) || push!(fails, "dead lanes at bank: " * join(rec["dead_lanes"], ", "))
    rel = relpath(dir, root)
    dirty = [p for (_, p) in Git.porcelain(root) if startswith(p, rel * "/") || p == rel]
    isempty(dirty) || push!(fails, "the round's files are not committed: " * join(first(dirty, 5), ", ") * (length(dirty) > 5 ? " …" : ""))
    st = Preflight.stamps(cfg; record = rec)
    latest_regrade = k >= 1 && isfile(joinpath(pass_dir(dir, k), "pass.toml")) && get(TOML.parsefile(joinpath(pass_dir(dir, k), "pass.toml")), "regrade", false)
    (st["config_sha"] == rec["config_sha"] || latest_regrade) || push!(fails, "config changed since open — gbg round pass open $round --regrade")
    (st["tool_version"] == rec["tool_version"] || latest_regrade) || push!(fails, "tool version moved ($(rec["tool_version"]) → $(st["tool_version"])) — regrade")
    if st["tool_tree_sha"] != rec["tool_tree_sha"] && st["tool_version"] == rec["tool_version"] && !startswith(st["tool_version"], "dev")
        println(io, "close: the tool's tree hash changed under the same version — the tag moved; this round is abandon-only"); return 2
    end
    head = something(Git.head(root), "")
    Git.is_ancestor(root, rec["head"], head) || push!(fails, "the opening head $(first(rec["head"], 8)) is not an ancestor of HEAD — gbg round pass open $round --regrade")
    findings = isfile(joinpath(dir, "findings.json")) ? findings_of(dir) : Dict{String,Any}[]
    ledger = Ledger.read(cfg)
    items = dismissal_items(cfg, dir, rec, findings, ledger)
    dj = joinpath(dir, "dismissals.json")
    if !isempty(items)
        want_sha = bytes2hex(sha256(JSON3.write(items)))
        vdir = joinpath(dir, "dismissals", first(want_sha, 12))
        # validated, not just read: the script, this gate and dismissal.schema.json disagreed on the file's
        # shape for as long as no round had an adjudication to close (found 2026-09-09)
        d = isfile(dj) ? (try read_json(dj) catch; nothing end) : nothing
        errs = d === nothing ? ["absent or unparsable"] : validate(load_schema("dismissal"), d)
        if !(isempty(errs) && get(d, "items_sha", "") == want_sha)
            # the script's own final write is missing, stale or invalid (a classifier blocked it on two of
            # five runs): the CLI assembles the file from the auditors' own verdict files instead
            assembled = assemble_dismissals(items, vdir, round, want_sha)
            if assembled !== nothing
                write_json(dj, assembled); d = assembled; errs = String[]
                println(io, "close: dismissals.json assembled from the auditors' own files ($(length(assembled["verdicts"])) of $(length(items)))")
            end
        end
        isfile(dj) && !isempty(errs) && errs != ["absent or unparsable"] && push!(fails, "dismissals.json is invalid: " * first(errs))
        ok = d !== nothing && isempty(errs) && get(d, "items_sha", "") == want_sha && d["complete"] && isempty(d["reopened"])
        if !ok
            mkpath(vdir)
            payload = joinpath(Preflight.payload_dir(cfg, round), "dismissals"); ip = items_file(joinpath(payload, "items.md"), items)
            a = Dict{String,Any}("schema_version" => 1, "round" => round, "repo" => root, "package" => Preflight.package_block(cfg),
                                 "items" => [Dict("id" => d["id"], "title" => d["title"]) for d in items], "items_path" => ip, "out" => dj,
                                 "verdicts_dir" => vdir, "models" => Dict("economy" => Preflight.economy_model()), "items_sha" => want_sha)
            Preflight.save_args(cfg, round, "dismissals", a)
            push!(fails, "the dismissal audit over $(length(items)) dismissal(s)/adjudication(s) has not run (or does not hold) — launch:\n    " *
                         Preflight.workflow_call(joinpath(Preflight.workflow_dir(cfg, round), "dismissals.js"), a) *
                         "\n  then close again (the script writes $dj; items_sha $want_sha is copied from its args)")
        end
    end
    if inst == "bug-hunt"
        append!(fails, hunt_close_conditions(cfg, dir, rec, findings; io, carry))
    elseif inst == "check-docs"
        append!(fails, audit_after_code(cfg, rec))
    elseif inst == "audit-changes"
        aj = joinpath(dir, "audit.json")
        if isfile(aj)
            a = read_json(aj)
            bad = [c for c in get(a, "executable_claims", Any[]) if c["exit"] != 0]
            isempty(bad) || push!(fails, "executable claim(s) failed at bank: " * join((c["command"] for c in bad), "; "))
            stale = Git.changed_paths(root, "$(a["head"])..HEAD", Preflight.covered_paths(cfg))
            Git.run(root, "cat-file", "-e", a["head"] * "^{commit}") === nothing ? push!(fails, "staleness UNCHECKABLE: the audited head $(first(a["head"], 8)) is unreachable") :
                (isempty(stale) || push!(fails, "stale: covered paths changed since the audited head: " * join(first(stale, 5), ", ")))
        else
            push!(fails, "audit.json absent — gbg audit-changes bank $round")
        end
    end
    rerated = Dict{String,String}()
    if !isempty(carry)
        cf, rerated = carry_conditions(cfg, dir, rec, findings, carry, io; at_cap)
        append!(fails, cf)
    end
    if !isempty(fails)
        println(io, "close: refused —"); foreach(f -> println(io, "  - ", f), fails); return 1
    end
    # the ledger moves: what this round carried joins it, what this round CLOSED leaves it
    led = carry_ledger(cfg); entries = led["carried"]
    closed_ids = Set(id for (id, e) in read_json(tj)["per_id"] if get(e, "closed_by", nothing) !== nothing)
    filter!(e -> !(String(e["id"]) in closed_ids), entries)
    # a carried hunt finding whose witness PASSED at this round's bank reproduces no more and was not
    # re-banked, so no close would ever name it closed: it leaves the ledger here, never re-banked for ever
    before = length(entries)
    banked = Set(String(f["id"]) for f in findings)
    inst == "bug-hunt" && filter!(e -> String(e["instrument"]) != inst || String(e["id"]) in banked, entries)
    pruned = length(entries) < before
    known = Dict(f["id"] => f for f in findings)
    for id in carry
        f = known[id]; i = findfirst(e -> String(e["id"]) == id, entries)
        if i === nothing
            push!(entries, Dict{String,Any}("id" => id, "instrument" => inst, "round" => round, "severity" => rerated[id],
                "lane" => String(get(f, "lane", "")), "type" => String(get(f, "type", "")), "confidence" => String(get(f, "confidence", "")),
                "title" => f["title"], "locations" => String.(f["locations"]), "description" => f["description"],
                "carries" => 1, "first_carried" => Rounds.timestamp(), "last_carried" => Rounds.timestamp()))
            i = length(entries)
        else
            entries[i]["carries"] = Int(entries[i]["carries"]) + 1
            entries[i]["last_carried"] = Rounds.timestamp(); entries[i]["severity"] = rerated[id]
        end
        # a hunt finding carries its evidence: the next hunt's bank copies in and re-runs the witness it names
        inst == "bug-hunt" && merge!(entries[i], hunt_carry_fields(root, dir, id))
    end
    (isempty(carry) && isempty(closed_ids) && !pruned) || save_carry(cfg, led)
    carry_deferrals(cfg, dir, round; io)
    rec["closed"] = Rounds.timestamp(); rec["closed_head"] = head
    used = [e["target"] for e in ledger if e["scope"] == "finding" && startswith(e["target"], round * "/")]
    rec["closed_by"] = Dict{String,Any}("adjudicated" => used, "tally_sha" => RoundFiles.sha256_file(tj))
    isempty(carry) || (rec["closed_by"]["carried"] = sort!(collect(String.(carry))))
    Rounds.save(dir, rec)
    isempty(carry) || println(io, "close: carried $(length(carry)) finding(s) into the next $inst round — they are re-banked there, never rediscovered: ", join(carry, ", "))
    println(io, "close: $round CLOSED at $(first(head, 8)) — commit ⇒ push the round (ROUND.toml changed); cite the closure per lane and id in the message")
    return 0
end

strip_provenance(text) = join(Iterators.dropwhile(l -> startswith(strip(l), "#") || isempty(strip(l)), split(text, '\n')), "\n")

# What a carried hunt finding needs to be re-banked with its evidence: its kind, the verdict it was
# confirmed with and what was observed, from its reproduction record in the round `dir`, and its witness
# file relative to `root`. Empty when the finding has no record.
function hunt_carry_fields(root::AbstractString, dir::AbstractString, id::AbstractString)
    rp = joinpath(dir, "reproductions", replace(id, "/" => "__", "#" => "_") * ".json")
    isfile(rp) || return Dict{String,Any}()
    r = read_json(rp)
    out = Dict{String,Any}("kind" => String(r["kind"]), "verdict" => String(r["verdict"]),
                           "observed" => String(get(r, "observed", "")), "evidence" => String(get(r, "evidence", "")))
    haskey(r, "witness_path") && (out["witness"] = relpath(joinpath(dir, r["witness_path"]), root))
    return out
end

# The disposition conditions of a hunt's close: every confirmed finding fixed (its witness passing and
# promoted), refused or escalated, and the arithmetic over them. A carried finding rides into the next
# round and owes this one no disposition, so the ids in `carry` are left out of both. Returns the fails.
function hunt_disposition_fails(cfg, dir, rec; carry = String[])
    fails = String[]; root = cfg["root"]
    project = Witnesses.witness_project(root, cfg["instruments"]["bug-hunt"]["witness_env"], cfg["package"]["name"])
    rdir = joinpath(dir, "reproductions")
    reps = [r for r in (isdir(rdir) ? [read_json(joinpath(rdir, f)) for f in readdir(rdir)] : Dict{String,Any}[]) if !(String(r["id"]) in carry)]
    confirmed = [r for r in reps if r["verdict"] in ("REPRODUCED", "EVIDENCED")]
    # dispositions may change (they are the record of the fix pass), but verdicts, witness shas and ids may not
    haskey(rec, "reproductions_sha") && RoundFiles.reproductions_sha(rdir) != rec["reproductions_sha"] &&
        push!(fails, "reproductions/ changed since bank in a field other than a disposition — verdicts, witness shas and ids are frozen there")
    for r in reps
        d = get(r, "disposition", Dict("state" => "open")); s = d["state"]
        r["verdict"] in ("REPRODUCED", "EVIDENCED") || continue
        s in ("fixed", "refused", "escalated") || push!(fails, "$(r["id"]) has no disposition (fixed | refused ≥ 24 chars | escalated with overturn_when) — a dropped finding")
        s == "refused" && length(get(d, "reason", "")) < 24 && push!(fails, "$(r["id"]): refusal reason shorter than 24 characters")
        s == "escalated" && !haskey(d, "overturn_when") && push!(fails, "$(r["id"]): escalated without overturn_when")
        if s == "fixed" && r["kind"] != "architecture"
            wp = joinpath(dir, get(r, "witness_path", "")); name = basename(wp)
            if isfile(wp)
                _, results = Witnesses.run(dirname(wp); expect = :pass, package = cfg["package"]["name"], project, names = [name], io = devnull)
                (isempty(results) || first(results).status != :pass) && push!(fails, "$(r["id"]): its witness $name does not PASS under the runner")
                promoted = joinpath(root, "test", "regressions", name)
                if !isfile(promoted)
                    push!(fails, "$(r["id"]): witness $name not promoted into test/regressions/")
                else
                    bytes2hex(sha256(strip_provenance(read(promoted, String)))) == bytes2hex(sha256(strip_provenance(read(wp, String)))) ||
                        push!(fails, "$(r["id"]): the promoted body of $name differs from the bank-time witness (a witness edited to pass is not evidence)")
                end
            else
                push!(fails, "$(r["id"]): fixed but its witness file is missing")
            end
        end
        if s == "escalated" && r["kind"] != "architecture"
            wp = joinpath(dir, get(r, "witness_path", "")); isfile(wp) && push!(fails, "$(r["id"]): escalated — move its witness to witnesses/escalated/ (never promoted)")
        end
    end
    nf = count(r -> get(get(r, "disposition", Dict()), "state", "") == "fixed", confirmed); nr = count(r -> get(get(r, "disposition", Dict()), "state", "") == "refused", confirmed); ne = count(r -> get(get(r, "disposition", Dict()), "state", "") == "escalated", confirmed)
    nf + nr + ne == length(confirmed) || push!(fails, "disposition arithmetic: fixed $nf + refused $nr + escalated $ne ≠ confirmed $(length(confirmed))")
    return fails
end

function hunt_close_conditions(cfg, dir, rec, findings; io, carry = String[])
    fails = hunt_disposition_fails(cfg, dir, rec; carry); root = cfg["root"]
    log = joinpath(Preflight.scratch_dir(cfg, dir |> basename), "close-test.log")
    code = Rounds.run_under_round(cfg, basename(dir), cfg["package"]["julia_test"]; log)
    code == 0 || push!(fails, "Pkg.test() under GBG_ROUND exit $code — $log")
    exists, covers = audit_coverage(cfg, rec["head"], code_dirs(cfg))
    b8 = first(rec["head"], 8)
    exists || push!(fails, "no closed audit-changes round with base = $b8 (this hunt's opening head) — run /audit-changes --base $b8 and close it")
    exists && !covers && push!(fails, "the audit based at $b8 does not cover this hunt's last code change — run /audit-changes --base $b8 again after the last fix, and close it")
    blocked = joinpath(dir, "witnesses", "blocked")
    isdir(blocked) && !isempty(readdir(blocked)) && println(io, "close: BLOCKED witnesses (re-run by gbg doctor --deep on a host with the device): ", join(readdir(blocked), ", "))
    all_dirty = Git.porcelain(root)
    isempty(all_dirty) || push!(fails, "the tree is not clean ($(length(all_dirty)) path(s))")
    ahead = Git.run(root, "rev-list", "--count", "@{u}..HEAD")
    ahead !== nothing && ahead != "0" && push!(fails, "$ahead commit(s) not pushed")
    return fails
end

end # module Passes
