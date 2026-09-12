using Test, GBGCodingTools, TOML, JSON3
include("helpers.jl")

# One round lifecycle without agents: preflight → (hand-written lane files) → bank → pass open →
# (hand-written verdicts) → grade → close refusals, on a fresh copy of the fixture. The instrument is
# check-docs with a hand-planted lane file; `prepare` is exercised on its scan half only through the
# engine (the build is the fixture's own test).
# the needle grade uses to re-find a hard-scan hit is cut in characters, never bytes (rc.1 round, src#2)
@testset "hit needle" begin
    s = "docs/x.md:3: " * "αβγδε ≤ ∇ ⟨u⟩ "^6
    @test length(G.Passes.hit_needle(s)) == 40
    @test G.Passes.hit_needle("a: short") == "short"
end

# RULE.INST.AUDIT_AFTER_CODE: a check-docs round whose fix pass touched src/ or ext/ refuses to close
# until an audit-changes round based at its opening head is closed; a prose-only pass is not gated. The
# copy is made its own repository, since it lives inside the tool's and must not commit into it.
@testset "a documentation round that changed code needs its audit" begin
    root = fixture_copy("audit-gate")
    cfg = G.Config.read(root)
    git(args...) = run(pipeline(`git -C $root -c user.email=t@t -c user.name=t $args`; stdout = devnull, stderr = devnull))
    git("init", "-q", "-b", "master"); git("add", "-A"); git("commit", "-q", "-m", "base")
    @test isempty(G.Passes.audit_after_code(cfg, Dict{String,Any}("head" => "HEAD")))       # nothing changed
    src = joinpath(root, "src", "FixtureA.jl"); write(src, read(src, String) * "\n")
    git("add", "-A"); git("commit", "-q", "-m", "a code edit")
    fails = G.Passes.audit_after_code(cfg, Dict{String,Any}("head" => "HEAD~1"))
    @test length(fails) == 1 && occursin("src/FixtureA.jl", fails[1]) && occursin("audit-changes", fails[1])
    note = joinpath(root, "docs", "src", "notation.md"); write(note, read(note, String) * "\n")
    git("add", "-A"); git("commit", "-q", "-m", "a prose edit")
    @test isempty(G.Passes.audit_after_code(cfg, Dict{String,Any}("head" => "HEAD~1")))     # prose only: not gated
    # an audit must have READ the round's last code change, not merely exist: one closed before a later
    # fix pass touched `src` again covers what it saw. Both directions, at the audit's own head.
    base = chomp(read(`git -C $root rev-parse "HEAD~2"`, String))
    rec = Dict{String,Any}("head" => base)
    @test length(G.Passes.audit_after_code(cfg, rec)) == 1                 # code changed, no audit at all
    ad = joinpath(root, ".gbg", "rounds", "2026-01-02-audit-changes-01"); mkpath(ad)
    audited(h) = write_round(ad, merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => "2026-01-02-audit-changes-01",
        "instrument" => "audit-changes", "schema_version" => 1, "head" => h, "base" => base,
        "roster" => Any[], "cost" => "economy", "strength" => "economy", "hostname" => "t", "model_hint" => "sonnet",
        "opened" => "2026-01-02T00:00:00", "dead_lanes" => String[], "passes" => 0, "closed" => "2026-01-02T00:00:01")))
    audited(chomp(read(`git -C $root rev-parse HEAD`, String)))
    @test isempty(G.Passes.audit_after_code(cfg, rec))                    # it read up to HEAD: covered
    write(src, read(src, String) * "\n"); git("add", "-A"); git("commit", "-q", "-m", "a later code edit")
    fails = G.Passes.audit_after_code(cfg, rec)
    @test length(fails) == 1 && occursin("does not cover", fails[1])      # closed before the last fix
    audited(chomp(read(`git -C $root rev-parse HEAD`, String)))
    @test isempty(G.Passes.audit_after_code(cfg, rec))                    # re-run after it: covered again
end

# A hat that needs the rulebook is unusable only when the rulebook is empty. The gate tested the
# consumer's OWN extra sections, though the shared policy is rendered whatever that list holds, so
# latex-typesetter — told to read latex-idiom.md and treat it as authoritative — vanished from every
# consumer that had added no sections of its own. Both directions: present with no sections, and absent.
@testset "a rulebook hat drops only when there is no rulebook" begin
    root = fixture_copy("rulebook-need")
    cp_ = joinpath(root, ".gbg", "config.toml")
    write(cp_, replace(read(cp_, String), r"^rulebook_sections = .*$"m => "rulebook_sections = []"))
    cfg = G.Config.read(root)
    @test isempty(cfg["package"]["rulebook_sections"])                     # a consumer that adds none
    lt(c) = only(h for h in G.Preflight.resolve_hats(c) if h["key"] == "latex-typesetter")
    @test "rulebook" in lt(cfg)["needs"] && !lt(cfg)["not_applicable"]     # the shared policy is its grant
    for f in readdir(joinpath(root, ".gbg", "policy"); join = true); rm(f); end
    @test lt(G.Config.read(root))["not_applicable"]                        # no rulebook at all: nothing to read
end

# The refusal that keeps a documentation round citable is at the DOOR: a /check-docs or
# /check-consistency round at the tool root will not open while the tool names no released version,
# because a round graded by an unreleased tool compares with nothing and no release may cite it. Both
# directions and both scopes: a tag stamp opens, an audit round is never refused (it reads base..HEAD
# and is off-tag by construction), and a consumer that is not the tool root is not this rule's business.
@testset "a documentation round will not open at a dev stamp" begin
    tcfg = G.Config.read(TOOL)
    dev = Dict{String,Any}("tool_version" => "dev+abc1234")
    tagged = Dict{String,Any}("tool_version" => "1.0.0-rc.1")
    r = G.Preflight.dev_round(tcfg, "check-docs", dev)
    @test r !== nothing && occursin("dev+abc1234", r) && occursin("release", r)
    @test G.Preflight.dev_round(tcfg, "check-consistency", dev) !== nothing
    @test G.Preflight.dev_round(tcfg, "check-docs", tagged) === nothing        # a released instrument
    @test G.Preflight.dev_round(tcfg, "audit-changes", dev) === nothing        # off-tag by construction
    @test G.Preflight.dev_round(tcfg, "bug-hunt", dev) === nothing
    @test G.Preflight.dev_round(G.Config.read(FIXTURE), "check-docs", dev) === nothing   # not the tool root
    # `gbg release` writes the carry ledger after it tags, so the commit of that write puts HEAD one past
    # the tag (rc.8 could not open its own round): a HEAD past the latest tag by `.gbg/` commits alone still
    # runs the released instrument; one past it by anything else, or a dirty tree, does not
    dir = joinpath(TMP, "data-since-tag"); mkpath(joinpath(dir, "src")); mkpath(joinpath(dir, ".gbg"))
    git(args...) = strip(read(setenv(`git -C $dir $args`, "GIT_AUTHOR_NAME" => "t", "GIT_AUTHOR_EMAIL" => "t@t", "GIT_COMMITTER_NAME" => "t", "GIT_COMMITTER_EMAIL" => "t@t", "HOME" => dir, "PATH" => ENV["PATH"]), String))
    write(joinpath(dir, "src", "a.jl"), "a\n"); git("init", "-q"); git("add", "-A"); git("commit", "-q", "-m", "one")
    @test G.Preflight.data_since_tag(dir) === nothing                                  # no tag at all
    git("tag", "-a", "v1.0.0-rc.1", "-m", "rc.1")
    write(joinpath(dir, ".gbg", "carried.toml"), "history = []\n"); git("add", "-A"); git("commit", "-q", "-m", "ledger")
    @test G.Preflight.data_since_tag(dir) == "1.0.0-rc.1"                              # only the package's records moved
    write(joinpath(dir, ".gbg", "carried.toml"), "history = [1]\n")
    @test G.Preflight.data_since_tag(dir) === nothing                                  # a dirty tree
    git("add", "-A"); git("commit", "-q", "-m", "ledger again")
    write(joinpath(dir, "src", "a.jl"), "b\n"); git("add", "-A"); git("commit", "-q", "-m", "code")
    @test G.Preflight.data_since_tag(dir) === nothing                                  # the tool itself moved
end

# `gbg release` leans on ONE round: the closed /check-docs round stamped with the latest rc tag, every
# id honored or adjudicated. The stamp is written without the `v` and the tag list carries it, so the
# raw comparison this replaced could never be true — the precondition was unsatisfiable and would have
# rejected a correctly stamped round. Both directions: the tag must match and the ids must be closed.
@testset "the release finds the round it cites" begin
    root = fixture_copy("cites")
    cfg = G.Config.read(root)
    rd = joinpath(root, ".gbg", "rounds", "2026-01-01-check-docs-01"); mkpath(joinpath(rd, "verdicts", "pass-1"))
    st = G.Preflight.stamps(cfg)
    rec = merge(st, Dict{String,Any}("round" => "2026-01-01-check-docs-01", "instrument" => "check-docs",
        "schema_version" => 1, "head" => "0"^40, "roster" => Any[], "cost" => "economy", "strength" => "economy",
        "hostname" => "t", "model_hint" => "sonnet", "opened" => "2026-01-01T00:00:00", "dead_lanes" => String[],
        "passes" => 1, "closed" => "2026-01-02T00:00:00"))
    rec["tool_version"] = "1.0.0-rc.1"; rec["tool_rev"] = "v1.0.0-rc.1"
    write_round(rd, rec)
    tally(state) = Dict("per_id" => Dict("r/lane#1" => Dict("closed_by" => state)))
    write(joinpath(rd, "verdicts", "pass-1", "tally.json"), JSON3.write(tally("honored")))
    @test G.cites_round(cfg, "v1.0.0-rc.1")
    @test !G.cites_round(cfg, "v1.0.0-rc.2")                  # a round of the previous candidate
    write(joinpath(rd, "verdicts", "pass-1", "tally.json"), JSON3.write(tally("abandoned")))
    @test !G.cites_round(cfg, "v1.0.0-rc.1")                  # an id that was never closed
end

# A closed round stamped dev has an exit. Nothing else does: a state a check can name and no verb can
# leave is a trap, and the repair reached for instead is editing a frozen record.
@testset "a closed dev-stamped round can still be abandoned" begin
    root = fixture_copy("unclose")
    cfg = G.Config.read(root)
    rd = joinpath(root, ".gbg", "rounds", "2026-01-01-bug-hunt-01"); mkpath(rd)
    st = G.Preflight.stamps(cfg)
    rec = merge(st, Dict{String,Any}("round" => "2026-01-01-bug-hunt-01", "instrument" => "bug-hunt",
        "schema_version" => 1, "head" => "0"^40, "roster" => Any[], "cost" => "economy", "strength" => "economy",
        "hostname" => "t", "model_hint" => "sonnet", "opened" => "2026-01-01T00:00:00", "dead_lanes" => String[],
        "passes" => 0, "closed" => "2026-01-02T00:00:00"))
    rec["tool_version"] = "1.0.0-rc.1"; rec["tool_rev"] = "v1.0.0-rc.1"; write_round(rd, rec)
    # a closed round stamped with a TAG is a release's evidence: abandon does not take it back
    @test_throws G.Rounds.RoundError G.Rounds.abandon(cfg, "2026-01-01-bug-hunt-01", "a released round is not re-openable"; io = devnull)
    rec["tool_version"] = "dev+abc1234"; rec["tool_rev"] = "abc1234" * "0"^33; write_round(rd, rec)
    @test G.Rounds.abandon(cfg, "2026-01-01-bug-hunt-01", "closed at a dev stamp, which no release may cite"; io = devnull) == 0
    back = G.RoundFiles.read_round(rd)
    @test G.RoundFiles.state(back) == :abandoned && haskey(back, "closed")     # the closing is still on the record
end

# RULE.INST.AUDIT_DISPOSED: bank tells an audit round to record dispositions and NEVER to run a fix pass,
# because a correction inside the round moves the tree and the staleness check then refuses the close for
# good. Both directions: every other instrument is still told the fix pass comes next.
@testset "bank sends an audit round to dispositions, not to a fix pass" begin
    a = G.Rounds.bank_next("audit-changes", "2026-01-01-audit-changes-01")
    @test occursin("record a disposition", a) && occursin("NEVER a fix pass", a)
    @test !occursin("the fix pass on the owner's word", a)
    for inst in ("check-docs", "bug-hunt", "check-consistency")
        n = G.Rounds.bank_next(inst, "2026-01-01-$inst-01")
        @test occursin("the fix pass on the owner's word", n) && !occursin("disposition", n)
    end
end

# An audit lane's `verdict` is a self-report the schema requires; the bank keeps it only where the lane's
# own findings bear it out (RULE.TEST.BOTH_DIRECTIONS). A contradiction is a DEAD lane like any other:
# quarantined, recorded in `dead_lanes`, so the `gbg round rerun` the refusal prints is one rerun accepts
# (it once printed a rerun that rerun refused, stranding the round), and it is refused before the
# executable claims run. Only schema-valid roster lane files are judged: a stale quarantined copy is
# never read, and a `findings` of the wrong shape is the schema's to refuse — never a crash.
@testset "an audit lane's verdict must agree with its findings" begin
    root = fixture_copy("audit-verdict")
    cfg = G.Config.read(root)
    id = "2026-01-01-audit-changes-01"
    rd = joinpath(root, ".gbg", "rounds", id); fd = joinpath(rd, "findings"); mkpath(fd)
    keys_ = ("executing", "numerics", "invariants", "free-reader")
    write_round(rd, merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => id, "instrument" => "audit-changes",
        "schema_version" => 1, "head" => "0"^40, "base" => "0"^40, "cost" => "economy", "strength" => "economy",
        "roster" => Any[Dict{String,Any}("key" => k, "anchor" => false, "substrate" => "code") for k in keys_],
        "hostname" => "t", "model_hint" => "sonnet", "opened" => "2026-01-01T00:00:00", "dead_lanes" => String[], "passes" => 0)))
    concern(i) = Dict("type" => "operational", "severity" => "minor", "confidence" => "high", "title" => "a concern number $i",
        "locations" => ["src/X.jl:1"], "description" => "a description long enough to pass", "before" => "b",
        "after" => "a", "why_it_matters" => "it matters", "justified" => "no", "evidence" => "e")
    lane(key, v, n) = Dict("schema_version" => 1, "round" => id, "lane" => key, "verdict" => v, "checked" => ["the diff"],
        "candidates_found" => n, "findings" => [concern(i) for i in 1:n])
    put(nn, key, v, n) = write(joinpath(fd, "$nn-$key.json"), JSON3.write(lane(key, v, n)))
    put("01", "executing", "CLEAN", 0); put("02", "numerics", "CONCERNS", 2)
    put("03", "invariants", "CLEAN", 0); put("04", "free-reader", "CONCERNS", 1)
    rec = G.RoundFiles.read_round(rd)
    @test isempty(G.lane_contradictions(rd, rec))                           # agreeing self-reports
    write(joinpath(fd, "03-invariants.rejected.json"), JSON3.write(lane("invariants", "CLEAN", 1)))
    @test isempty(G.lane_contradictions(rd, rec))                           # a quarantined copy is never read
    put("03", "invariants", "CLEAN", 1); put("04", "free-reader", "CONCERNS", 0)
    @test G.lane_contradictions(rd, rec) == ["invariants", "free-reader"]
    st, _, _, note = G.Rounds.classify_lane(rd, "audit-changes", Dict("nn" => "03", "key" => "invariants"))
    @test st == :dead && occursin("contradicts", note) && isfile(joinpath(fd, "03-invariants.rejected.json"))
    put("03", "invariants", "CLEAN", 1)                                     # the quarantined lane, back
    out = IOBuffer()
    @test G.audit_bank(cfg, id; io = out) == 2
    s = String(take!(out))
    @test !occursin("claim gate", s) && occursin("--lanes free-reader,invariants", s)   # before any claim ran
    @test sort(G.RoundFiles.read_round(rd)["dead_lanes"]) == ["free-reader", "invariants"]
    r = IOBuffer(); G.Rounds.rerun(cfg, id, ["invariants", "free-reader"]; io = r)
    @test !occursin("not DEAD or REJECTED", String(take!(r)))              # the printed remedy is accepted
    write(joinpath(fd, "01-executing.json"), JSON3.write(merge(lane("executing", "CLEAN", 0), Dict("findings" => nothing))))
    @test isempty(G.lane_contradictions(rd, rec))                           # the wrong shape: the schema's
    st, _, _, note = G.Rounds.classify_lane(rd, "audit-changes", Dict("nn" => "01", "key" => "executing"))
    @test st == :dead && occursin("invalid", note)                          # DEAD on the schema, not a crash
end

# The audit's severity re-check reads only the concerns a re-rating can move across the disposition gate:
# grade takes the more serious rating, so a major or a previously-working concern is gated whatever the
# re-rating says. Both directions (23 of 33 concerns once went to it for nothing).
@testset "the audit re-rates only what the gate could still move" begin
    c(sev, pw) = (d = Dict{String,Any}("id" => "r/l#$(sev)-$(pw)", "severity" => sev); pw === nothing || (d["previously_worked"] = pw); d)
    fs = [c("minor", nothing), c("nit", "no"), c("minor", "yes"), c("nit", "unknown"), c("major", nothing), c("blocker", "no")]
    @test [x["id"] for x in G.recheck_candidates(fs)] == ["r/l#minor-nothing", "r/l#nit-no"]
    @test isempty(G.recheck_candidates([c("major", "no"), c("minor", "yes")]))
end

# The check-docs roster is data-driven in three ways a round pays for on every lane, and each has a
# direction that fails SILENTLY: a slice that quietly spans the whole document, a glob handed to the agent
# as the literal string `instruments/*/PROTOCOL.md`, and a finding budget baked into the brief where no
# config can move it. None of the three raises an error when it is wrong; the round just costs the same and
# reads less.
@testset "the check-docs roster: slices, globs and the budget" begin
    d = mktempdir()
    write(joinpath(d, "R.md"), join([join(vcat(["## §$i"], fill("body line", 40)), "\n") for i in 1:6], "\n"))
    cfgd = Dict{String,Any}("root" => d)
    total = length(readlines(joinpath(d, "R.md")))
    s3 = G.Preflight.rationale_slices(cfgd, "R.md", 3)
    @test length(s3) == 3
    @test first(s3)[1] == 1 && last(s3)[2] == total                  # the slices COVER the document
    for k in 2:3; @test s3[k][1] == s3[k - 1][2] + 1; end            # contiguous: no gap, no overlap
    @test all(sl -> startswith(sl[3], "§"), s3)                      # each named by its own headings
    @test G.Preflight.rationale_slices(cfgd, "R.md", 1) == [(1, total, "the whole document")]
    # fewer headings than slices is ONE lane, never n lanes over a document that cannot be cut
    write(joinpath(d, "S.md"), "## only\nx\ny\n")
    @test length(G.Preflight.rationale_slices(cfgd, "S.md", 3)) == 1

    tcfg = G.Config.read(TOOL)                                       # the tool takes three rationale lanes
    roster = G.Preflight.resolve_checkdocs_lanes(tcfg)
    @test count(l -> startswith(l["key"], "rationale"), roster) == 3
    @test any(l -> l["key"] == "rationale", roster)                  # the key the carried findings name
    @test any(l -> l["key"] == "one-home", roster) && !any(l -> l["key"] == "family", roster)
    amb = only([l for l in roster if l["key"] == "ambient"])
    @test all(f -> isfile(joinpath(TOOL, f)), amb["files"])          # the glob reached it as real files
    @test count(f -> endswith(f, "PROTOCOL.md"), amb["files"]) == 4
    brief = first(roster)["brief"]
    @test occursin("budget is 20 FINDINGS", brief) && !occursin("{lane.cap}", brief)
    @test occursin("ONE DEFECT PER CLASS", brief)
    # a lane with a surface has a checklist; the cross lanes, which have no files, have none
    @test !isempty(G.Preflight.claim_checklist(tcfg, ["docs/ARCHITECTURE.md"]))
    @test isempty(G.Preflight.claim_checklist(tcfg, String[]))

    # ONE home for the expansion, and the hunt uses it too: `src/Scans/*.jl` reached the agent as the
    # literal pattern until 2026-09-12, so a territory of forty-five files was one string in its prompt.
    hl = G.Preflight.resolve_hunt_lanes(tcfg)
    @test !any(l -> any(f -> occursin("*", f), l["files"]), hl)
    @test length(only([l for l in hl if l["key"] == "scans"])["files"]) > 10
    @test G.Preflight.expand_globs(TOOL, ["catalog"]) == ["catalog"]   # a directory is not a glob: kept
    @test G.Preflight.expand_globs(TOOL, ["nosuch/*.jl"]) == ["nosuch/*.jl"]   # matching nothing: kept, not dropped
end

# gbg attack and gbg calibrate check the instruments themselves, outside any round. An attack renders the
# instrument's live roster as the design and fills its subject's placeholders; a calibration refuses
# without human findings and hands the blind hats the passage, never the defect. Each `read` exits on
# what the result says and refuses one that is absent, invalid or incomplete. Both directions throughout.
@testset "attack and calibrate: the instruments checked from outside a round" begin
    root = fixture_copy("design-checks")
    cfg = G.Config.read(root)
    out = IOBuffer()
    @test G.attack(cfg, "nonesuch"; io = out) == 2
    @test G.attack(cfg, "audit-changes"; io = out) == 0
    s = String(take!(out))
    id = only(readdir(joinpath(root, ".gbg", "attacks")))
    rd = joinpath(root, ".gbg", "attacks", id)
    design = read(joinpath(rd, "design.md"), String)
    @test all(r -> occursin("## " * r["key"], design), G.Preflight.resolve_roster(cfg, "audit-changes"))
    subj = TOML.parsefile(joinpath(rd, "subject.toml"))
    @test occursin(cfg["package"]["name"], subj["object"]) && !any(v -> occursin("{package.", v), values(subj))
    @test occursin("attack-design.js", s) && occursin("gbg attack read $id", s)
    @test G.attack_read(cfg, id; io = devnull) == 2                                   # no result yet
    res(gaps, dead) = write(joinpath(rd, "attack.json"), JSON3.write(Dict("schema_version" => 1, "round" => id,
        "bySeverity" => Dict(), "gaps" => gaps, "dead" => dead, "complete" => isempty(dead))))
    gap = Dict("severity" => "fatal", "gap" => "g", "evading_example" => "e", "why_each_lane_misses" => "w",
               "proposed_lens" => "p", "role" => "logician")
    res(Any[], String[]);          @test G.attack_read(cfg, id; io = devnull) == 0     # sound
    res([gap], String[]);          @test G.attack_read(cfg, id; io = devnull) == 1     # a gap is a finding
    res(Any[], ["measurement"]);   @test G.attack_read(cfg, id; io = devnull) == 2     # a dead attacker: untested
    res([Dict("severity" => "grave")], String[]); @test G.attack_read(cfg, id; io = devnull) == 2   # invalid

    @test G.calibrate(cfg; io = devnull) == 2                                         # no human findings yet
    write(joinpath(root, ".gbg", "human-findings.toml"), """
    [[finding]]
    id = "h-1"
    title = "a quantifier the code does not keep"
    page = "Home"
    passage = "The spacing h is uniform at every node of the grid."
    defect = "The grid is uniform only in the interior; the boundary spacing differs."
    recorded = 2026-09-11
    """)
    out = IOBuffer()
    @test G.calibrate(cfg; io = out) == 0
    cid = only(readdir(joinpath(root, ".gbg", "calibrations")))
    a = JSON3.read(read(joinpath(G.Preflight.workflow_dir(cfg, cid), "calibrate.args.json"), String))
    @test length(a.items) == 1 && !isempty(a.hats) && occursin("rubric-audit.js", String(take!(out)))
    passage = read(String(a.items[1].substrate_path), String)
    @test occursin("uniform at every node", passage) && !occursin("boundary spacing", passage)   # blind: never the defect
    cr = joinpath(root, ".gbg", "calibrations", cid, "rubric-audit.json")
    cal(v) = write(cr, JSON3.write(Dict("schema_version" => 1, "round" => cid,
        "tally" => Dict("CAUGHT" => Int(v == "CAUGHT"), "PARTIAL" => 0, "MISSED" => Int(v == "MISSED")),
        "unassigned" => Any[], "misassigned" => Any[], "orphaned" => String[],
        "gaps" => v == "CAUGHT" ? Any[] : [Dict("id" => "h-1", "hat" => "doc-policy", "verdict" => v, "evidence" => "nothing reported on this")],
        "scores" => [Dict("id" => "h-1", "hat" => "doc-policy", "verdict" => v, "evidence" => "e")],
        "byHat" => Dict("doc-policy" => ["h-1"]))))
    cal("CAUGHT"); @test G.calibrate_read(cfg, cid; io = devnull) == 0
    cal("MISSED"); @test G.calibrate_read(cfg, cid; io = devnull) == 1
end

# A bug hunt has a pass budget too, and what it carries brings its evidence: the carry entry names the
# confirmation and the witness, the next hunt's bank copies the witness in under a name none of that
# round's own can take, and a carried finding owes the round that carried it no disposition. Before,
# a carried hunt finding arrived with no witness and no verdict and could never close.
@testset "a bug hunt carries its open findings with their witnesses" begin
    cfg = G.Config.read(FIXTURE)
    @test cfg["instruments"]["bug-hunt"]["max_passes"] == 3                    # every consumer's default
    root = mktempdir(); old = joinpath(root, ".gbg", "rounds", "2026-01-01-bug-hunt-01")
    mkpath(joinpath(old, "witnesses")); mkpath(joinpath(old, "reproductions"))
    id = "2026-01-01-bug-hunt-01/free-modules#1"
    write(joinpath(old, "witnesses", "w1.jl"), "using Test\n@test 1 == 2\n")
    write(joinpath(old, "reproductions", replace(id, "/" => "__", "#" => "_") * ".json"), JSON3.write(Dict(
        "schema_version" => 1, "id" => id, "title" => "a defect of some length", "kind" => "runtime", "severity" => "major",
        "verdict" => "REPRODUCED", "observed" => "FAILS", "evidence" => "e", "witness_path" => "witnesses/w1.jl",
        "disposition" => Dict("state" => "open"))))
    fields = G.Passes.hunt_carry_fields(root, old, id)
    @test fields["verdict"] == "REPRODUCED" && fields["witness"] == ".gbg/rounds/2026-01-01-bug-hunt-01/witnesses/w1.jl"
    new = joinpath(root, ".gbg", "rounds", "2026-02-01-bug-hunt-01"); mkpath(new)
    e = merge(Dict{String,Any}("id" => id, "round" => "2026-01-01-bug-hunt-01"), fields)
    g = G.Rounds.rebank_hunt_carried!(Dict{String,Any}("id" => id), e, root, new)
    @test g["verdict"] == "REPRODUCED" && g["kind"] == "runtime" && isfile(joinpath(new, g["witness_path"]))
    @test startswith(basename(g["witness_path"]), "carried_")                  # never a name of the round's own
    # the round that carries it owes it no disposition; an open finding it does not carry is a dropped one
    @test isempty(G.Passes.hunt_disposition_fails(cfg, old, Dict{String,Any}(); carry = [id]))
    @test any(f -> occursin("has no disposition", f), G.Passes.hunt_disposition_fails(cfg, old, Dict{String,Any}()))
end

# RULE.INST.FROZEN_MIDROUND: a deferral written in the round's deferred.md is carried into the work
# queue at close, where the Stop hook holds the next session to it; a note nothing reads is not a mechanism.
@testset "a round's deferrals reach the work queue" begin
    root = fixture_copy("deferrals")
    cfg = G.Config.read(root)
    dir = joinpath(root, ".gbg", "rounds", "2026-01-01-check-docs-01"); mkpath(dir)
    queue = joinpath(root, ".claude", "WORK_QUEUE.md")
    @test G.Passes.carry_deferrals(cfg, dir, "r"; io = devnull) == 0            # no deferred.md: nothing
    # an item is a BULLET, not a line: a wrapped bullet is ONE item and prose outside every bullet is none,
    # or a round's deferred.md becomes one queue fragment per line and the Stop hook holds a session to prose
    write(joinpath(dir, "deferred.md"),
          "# a comment is not an item\n\nA paragraph outside every bullet is not an item either.\n\n" *
          "- SCAN.X: the class this round\n  could not fix\n")
    @test G.Passes.carry_deferrals(cfg, dir, "2026-01-01-check-docs-01"; io = devnull) == 1
    @test occursin("- [ ] SCAN.X: the class this round could not fix (deferred by 2026-01-01-check-docs-01)", read(queue, String))
    @test !occursin("A paragraph outside every bullet", read(queue, String))
    @test G.Passes.carry_deferrals(cfg, dir, "2026-01-01-check-docs-01"; io = devnull) == 0   # never twice
    # abandoning drops the round's record, not what it owes: the deferral still reaches the queue
    write(joinpath(dir, "deferred.md"), "- SCAN.Y: owed whatever became of the round\n")
    write_round(dir, merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => "2026-01-01-check-docs-01",
        "instrument" => "check-docs", "schema_version" => 1, "head" => "0"^40, "roster" => Any[], "cost" => "economy",
        "strength" => "economy", "hostname" => "t", "model_hint" => "sonnet", "opened" => "2026-01-01T00:00:00",
        "dead_lanes" => String[], "passes" => 0)))
    @test G.Rounds.abandon(cfg, "2026-01-01-check-docs-01", "superseded by a tool change"; io = devnull) == 0
    @test occursin("- [ ] SCAN.Y: owed whatever became of the round (deferred by 2026-01-01-check-docs-01)", read(queue, String))
end

# A pass verifies what is still open, plus a closed id the fix pass has touched again; and it refuses to
# open while an open finding names a file the fix pass left alone. Both directions: the sweep check must
# fire on the fix that stopped at one location, and stay silent when every named location moved.
@testset "a pass verifies what is open, and refuses an unswept fix" begin
    root = fixture_copy("scope")
    cfg = G.Config.read(root)
    git(args...) = run(pipeline(`git -C $root -c user.email=t@t -c user.name=t $args`; stdout = devnull, stderr = devnull))
    git("init", "-q", "-b", "master"); git("add", "-A"); git("commit", "-q", "-m", "base")
    dir = joinpath(root, ".gbg", "rounds", "2026-01-01-check-docs-01"); mkpath(dir)
    a = joinpath(root, "src", "FixtureA.jl"); b = joinpath(root, "docs", "src", "notation.md")
    two = Dict{String,Any}("id" => "r/x#1", "lane" => "src", "n" => 1, "title" => "t",
                           "locations" => ["src/FixtureA.jl:1 — quoted", "docs/src/notation.md:2 — quoted", "no/such/file.jl:9"])
    write(joinpath(dir, "findings.json"), JSON3.write(Dict("schema_version" => 1, "round" => "r", "findings" => [two])))

    @test G.Passes.finding_files(root, two) == ["src/FixtureA.jl", "docs/src/notation.md"]   # only real files
    base = chomp(read(`git -C $root rev-parse HEAD`, String))
    write(a, read(a, String) * "\n"); git("add", "-A"); git("commit", "-q", "-m", "one of the two")
    missed = G.Passes.unswept(cfg, dir, ["r/x#1"], "$base..HEAD")
    @test length(missed) == 1 && missed[1][2] == ["docs/src/notation.md"]                    # fires on the half-fix
    mid = chomp(read(`git -C $root rev-parse HEAD`, String))
    write(b, read(b, String) * "\n"); git("add", "-A"); git("commit", "-q", "-m", "the other")
    @test isempty(G.Passes.unswept(cfg, dir, ["r/x#1"], "$base..HEAD"))                      # silent when swept
    # the second fix pass's range alone calls the first pass's fix untouched; pass open therefore asks
    # from the round's opening head, every fix pass since bank
    @test G.Passes.unswept(cfg, dir, ["r/x#1"], "$mid..HEAD") == ["r/x#1" => ["src/FixtureA.jl"]]
    @test isempty(G.Passes.unswept(cfg, dir, String[], "$base..HEAD"))                       # nothing open, nothing to sweep

    rec = Dict{String,Any}("head" => base, "passes" => 0)
    @test G.Passes.pass_scope(cfg, dir, rec, 1)[1] === nothing                               # pass 1 verifies every id
    pd = joinpath(dir, "verdicts", "pass-1"); mkpath(pd)
    open(joinpath(pd, "pass.toml"), "w") do f; TOML.print(f, Dict("head" => base)); end
    write(joinpath(pd, "tally.json"), JSON3.write(Dict("open_ids" => String[], "per_id" => Dict("r/x#1" => Dict("closed_by" => "honored")))))
    scope, prev, susp, _ = G.Passes.pass_scope(cfg, dir, rec, 2)
    @test isempty(prev) && susp == ["r/x#1"] && scope == ["r/x#1"]         # closed, but the fix pass went near it again

    # a finding naming no file in the tree is re-verified every pass, never exempted for ever
    nofile = Dict{String,Any}("id" => "r/y#1", "lane" => "src", "n" => 1, "title" => "t", "locations" => ["nowhere at all"])
    write(joinpath(dir, "findings.json"), JSON3.write(Dict("schema_version" => 1, "round" => "r", "findings" => [nofile])))
    @test G.Passes.pass_scope(cfg, dir, rec, 2)[1] == ["r/y#1"]
    @test isempty(G.Passes.unswept(cfg, dir, ["r/y#1"], "$base..HEAD"))    # and it never trips the refusal

    # A pass OPENED and never graded is superseded, not evidence. Reading k-1 blindly let it erase what
    # the last graded pass decided: a round whose every id was closed came back with all of them open,
    # so the sweep check refused the next pass over findings nobody had reopened and a regrade would
    # have re-verified the whole round. Both directions: the ungraded pass is skipped, and a round with
    # no graded pass at all still verifies everything.
    write(joinpath(dir, "findings.json"), JSON3.write(Dict("schema_version" => 1, "round" => "r", "findings" => [two])))
    ungraded = joinpath(dir, "verdicts", "pass-2"); mkpath(ungraded)
    open(joinpath(ungraded, "pass.toml"), "w") do f; TOML.print(f, Dict("head" => base, "regrade" => true)); end
    @test G.Passes.last_graded(dir, 3) == 1 && G.Passes.last_graded(dir, 2) == 1 && G.Passes.last_graded(dir, 1) == 0
    scope3, prev3, _, _ = G.Passes.pass_scope(cfg, dir, rec, 3)
    @test isempty(prev3) && scope3 == ["r/x#1"]                            # pass 1's tally, not pass 2's absence
    rm(joinpath(pd, "tally.json"))
    @test G.Passes.pass_scope(cfg, dir, rec, 3)[1] === nothing             # nothing graded yet: verify everything
    # an id the state verifier never read is re-read next pass whether or not the fix went near it, or it
    # is read never: 2026-09-10-check-docs-03 left two such ids out of every scope for seven passes
    quietf = Dict{String,Any}("id" => "r/z#1", "lane" => "src", "n" => 1, "title" => "t", "locations" => ["Project.toml:1 — untouched"])
    write(joinpath(dir, "findings.json"), JSON3.write(Dict("schema_version" => 1, "round" => "r", "findings" => [quietf])))
    pend(p) = write(joinpath(pd, "tally.json"), JSON3.write(Dict("open_ids" => String[], "pending_state" => p,
                                                                  "per_id" => Dict("r/z#1" => Dict("act" => "HONORED")))))
    pend(String[]);   @test isempty(G.Passes.pass_scope(cfg, dir, rec, 2)[1])      # read, untouched: not in scope
    pend(["r/z#1"]);  @test G.Passes.pass_scope(cfg, dir, rec, 2)[3] == ["r/z#1"]  # never read: re-checked
    # a finding carried in from an earlier round was often fixed after that round closed and before this one
    # opened: the first fix range starts where the carrying round closed, or the act verifier grades the fix
    # UNDONE at every pass (four ids of 2026-09-11-check-docs-01, carried again at rc.9)
    now = chomp(read(`git -C $root rev-parse HEAD`, String))
    od = joinpath(root, ".gbg", "rounds", "2025-12-31-check-docs-01"); mkpath(od)
    open(joinpath(od, "ROUND.toml"), "w") do f; TOML.print(f, Dict("closed_head" => base)); end
    carried = Dict{String,Any}("id" => "2025-12-31-check-docs-01/src#1", "lane" => "src", "n" => 2, "title" => "t",
                               "locations" => ["Project.toml:1"], "carried_from" => "2025-12-31-check-docs-01 (carry 1)")
    write(joinpath(dir, "findings.json"), JSON3.write(Dict("schema_version" => 1, "round" => "r", "findings" => [quietf, carried])))
    rnow = Dict{String,Any}("head" => now, "passes" => 0)
    @test G.Passes.carried_base(cfg, dir, rnow) == base                     # where the carrying round closed
    @test G.Passes.pass_scope(cfg, dir, rnow, 1)[4] == "$base..$now"
    write(joinpath(dir, "findings.json"), JSON3.write(Dict("schema_version" => 1, "round" => "r", "findings" => [quietf])))
    @test G.Passes.carried_base(cfg, dir, rnow) == now                      # nothing carried: the opening head
end

# A tree that moved under an unchanged released version is the tag moving: close refuses the round as
# abandon-only, and a regrade must not re-stamp that away (refuse, regrade, close once passed a round on
# a moved tag). Both directions: a moved version, or a dev stamp, re-stamps the tree with the rest.
@testset "a regrade never re-stamps a moved tag" begin
    rec = Dict{String,Any}("config_sha" => "c", "tool_version" => "1.0.0-rc.6", "tool_rev" => "r", "tool_tree_sha" => "t")
    st(; kw...) = merge(rec, Dict{String,Any}(String(k) => v for (k, v) in kw))
    @test G.Passes.restamped(st(tool_tree_sha = "t2", config_sha = "c2"), rec) == (["config_sha"], true)
    @test G.Passes.restamped(st(tool_tree_sha = "t2", tool_version = "1.0.0-rc.7", tool_rev = "r2"), rec) ==
          (["tool_version", "tool_rev", "tool_tree_sha"], false)
    dev = merge(rec, Dict{String,Any}("tool_version" => "dev+abc1234"))
    @test G.Passes.restamped(merge(dev, Dict{String,Any}("tool_tree_sha" => "t2")), dev) == (["tool_tree_sha"], false)
    @test G.Passes.restamped(rec, rec) == (String[], false)
end

# dismissals.json no longer rests on the script's final writer, which a classifier blocked on two of five
# runs: each auditor writes its own verdict to a file its ITEM names — the id and a hash of the text audited
# — and close assembles the file from them. The id is the item's, an out-of-set verdict or a missing file is
# dead, and an empty directory assembles nothing.
@testset "close assembles dismissals.json from the auditors' own files" begin
    vdir = mktempdir(); r = "2026-01-01-check-docs-01"; sha = "a"^64
    items = [Dict{String,Any}("id" => "$r/src#1", "title" => "t1", "reasoning" => "because"),
             Dict{String,Any}("id" => "$r/src#2", "title" => "t2", "reasoning" => "because")]
    @test G.Passes.assemble_dismissals(items, vdir, r, sha) === nothing                        # nothing written
    put(it, v) = write(joinpath(vdir, G.Passes.item_key(it) * ".json"),
                       JSON3.write(Dict("id" => "a paraphrase", "verdict" => v, "evidence" => "quoted lines settle it")))
    put(items[1], "DISMISSAL-SOUND")
    d = G.Passes.assemble_dismissals(items, vdir, r, sha)
    @test d["verdicts"][1]["id"] == "$r/src#1" && d["dead"] == ["$r/src#2"] && !d["complete"]  # the id is the item's
    put(items[2], "PROBABLY-FINE")
    @test G.Passes.assemble_dismissals(items, vdir, r, sha)["dead"] == ["$r/src#2"]             # out of the closed set
    put(items[2], "DISMISSAL-SOUND")
    d = G.Passes.assemble_dismissals(items, vdir, r, sha)
    @test d["complete"] && isempty(d["reopened"]) && d["items_sha"] == sha
    @test isempty(G.validate(G.load_schema("dismissal"), d))                                    # what close validates

    # A verdict is bought against the TEXT it audited. Re-running after one disposition changed re-buys that
    # item and keeps the rest: keyed by the set's sha instead, three runs over ten, seven and six refusals
    # cost 1.48M tokens where the changed items alone were worth 0.15M (2026-09-11-audit-changes-02).
    moved = [items[1], merge(items[2], Dict{String,Any}("reasoning" => "a different reason entirely"))]
    @test G.Passes.item_key(moved[1]) == G.Passes.item_key(items[1])                            # untouched: same file
    @test G.Passes.item_key(moved[2]) != G.Passes.item_key(items[2])                            # its text moved
    d = G.Passes.assemble_dismissals(moved, vdir, r, sha)
    @test [v["id"] for v in d["verdicts"]] == ["$r/src#1"] && d["dead"] == ["$r/src#2"]         # one kept, one to re-buy
end

# The class checklist is COMPUTED, not invented: every place the tree writes down a rule or scan id the
# finding cites, plus the other end of the scan/rule pair, because a finding that names only the scan is
# about the rule's prose too. This is what makes a class enumerable in one pass instead of one site per
# pass. Both directions: a finding citing an id gets its sites, a finding citing none gets nothing.
@testset "the class checklist is computed from the ids a finding cites" begin
    tcfg = G.Config.read(TOOL)
    f = Dict{String,Any}("id" => "r/x#1", "title" => "SCAN.SIBLING_LINK's header overstates what it enforces",
                         "description" => "d"^24, "locations" => ["src/Scans/sibling_link.jl:1"])
    sites = G.Passes.class_candidates(tcfg, f)
    @test any(s -> startswith(s, "src/Scans/sibling_link.jl:"), sites)      # the scan itself
    @test any(s -> startswith(s, "policy/docs-rubric.md:"), sites)          # the RULE's paragraph, via the pair
    @test any(s -> startswith(s, "docs/ARCHITECTURE.md:"), sites)           # the catalogue and rule tables
    @test !any(s -> startswith(s, "docs/src/architecture.md:") || startswith(s, "docs/build/"), sites)   # gitignored copies: never swept
    @test !any(s -> startswith(s, ".gbg/"), sites)                          # never a round's own answer key
    @test !any(s -> s == "CHANGELOG.md", sites) && !any(s -> startswith(s, "CHANGELOG.md:"), sites)
    quiet = Dict{String,Any}("id" => "r/y#1", "title" => "a docstring reads badly", "description" => "d"^24,
                             "locations" => ["src/CLI/Gate.jl:8"])
    @test isempty(G.Passes.class_candidates(tcfg, quiet))                   # no id cited, nothing computed
end

# A HONORED verdict whose own checklist leaves a surface unswept says two things at once: the fix landed,
# and here is where the class still lives. The second is the true one. Emptiness alone fired 0 times in
# 571 verdicts of the last round while admitting 21 such closures, one of them five times.
@testset "a HONORED verdict that names an unswept surface is a LINE-ONLY" begin
    swept(b) = [Dict("surface" => "src/CLI/Sync.jl:154", "swept" => b, "evidence" => "e"^12)]
    v, d = G.demote(Dict("verdict" => "HONORED", "class_surfaces" => swept(false)))
    @test v["verdict"] == "LINE-ONLY" && d && v["demoted_from"] == "HONORED"
    v, d = G.demote(Dict("verdict" => "HONORED", "class_surfaces" => swept(true)))
    @test v["verdict"] == "HONORED" && !d                                   # every surface swept: it stands
    v, d = G.demote(Dict("verdict" => "HONORED", "class_surfaces" => vcat(swept(true), swept(false))))
    @test v["verdict"] == "LINE-ONLY" && d                                  # one unswept is enough
    v, d = G.demote(Dict("verdict" => "HONORED", "class_surfaces" => Any[]))
    @test v["verdict"] == "LINE-ONLY" && d                                  # the emptiness half still holds
    v, d = G.demote(Dict("verdict" => "LAUNDERED", "class_surfaces" => swept(false)))
    @test v["verdict"] == "LAUNDERED" && !d                                 # only HONORED is demoted
end

# A round may close by CARRYING a finding into the next round of its instrument, which is what breaks
# the long fix-verify tail: the finding is real and unfixed, and it is re-banked next time rather than
# left to be rediscovered. Severity decides eligibility — a serious finding is fixed, adjudicated or
# escalated, never deferred — and the severity that decides is the RE-RATED one, because the moment a
# rating licenses a deferral the reporting lane acquires a reason to under-rate. All three refusals and
# the accepting path are exercised here.
@testset "a round closes by carrying, and only what severity allows" begin
    root = fixture_copy("carry")
    cfg = G.Config.read(root)
    rd = joinpath(root, ".gbg", "rounds", "2026-01-01-check-docs-01")
    pd = joinpath(rd, "verdicts", "pass-1"); mkpath(pd)
    ids = ["2026-01-01-check-docs-01/src#$i" for i in 1:2]
    fs = [Dict{String,Any}("id" => ids[i], "lane" => "src", "n" => i, "title" => "t$i", "severity" => "minor",
                           "confidence" => "high", "type" => "structure", "locations" => ["src/FixtureA.jl:$i — \"q$i\""],
                           "description" => "d"^24) for i in 1:2]
    write(joinpath(rd, "findings.json"), JSON3.write(Dict("schema_version" => 1, "round" => "2026-01-01-check-docs-01", "findings" => fs)))
    st = G.Preflight.stamps(cfg)
    rec = merge(st, Dict{String,Any}("round" => "2026-01-01-check-docs-01", "instrument" => "check-docs", "schema_version" => 1,
        "head" => something(G.Git.head(root), "0"^40), "roster" => Any[Dict("key" => "src", "substrate" => "full", "anchor" => false)],
        "cost" => "economy", "strength" => "economy", "hostname" => "t", "model_hint" => "sonnet", "opened" => "2026-01-01T00:00:00",
        "dead_lanes" => String[], "passes" => 1, "banked" => "2026-01-01T00:00:01",
        # a docs round closes only over a RECORDED green build (`gbg round build` writes this), so the
        # red build that rode through two graded passes of 2026-09-12-check-docs-01 cannot reach close
        "build" => Dict{String,Any}("code" => 0, "head" => something(G.Git.head(root), "0"^40), "at" => "2026-01-01T00:00:03"),
        "findings_sha" => G.RoundFiles.sha256_file(joinpath(rd, "findings.json"))))
    write_round(rd, rec)
    per = Dict(ids[1] => Dict("act" => "HONORED", "act_demoted" => false, "state" => "ABSENT", "closed_by" => "honored"),
               ids[2] => Dict("act" => "LINE-ONLY", "act_demoted" => false, "state" => "PRESENT", "closed_by" => nothing))
    write(joinpath(pd, "tally.json"), JSON3.write(Dict("schema_version" => 1, "round" => "2026-01-01-check-docs-01", "pass" => 1,
        "per_id" => per, "totals" => Dict("findings" => 2, "seeded" => 0, "closed" => 1, "open" => 1), "demoted_by_rule" => 0,
        "adjudicated_share" => 0.0, "suspect_hats" => String[], "dead_lanes" => String[], "rejected_files" => String[],
        "open_ids" => [ids[2]], "pending_state" => String[], "plateau" => 0)))
    open(joinpath(pd, "pass.toml"), "w") do f
        TOML.print(f, Dict("pass" => 1, "nonce" => "b"^32, "opened" => "2026-01-01T00:00:02", "head" => rec["head"],
                           "range" => "$(rec["head"])..$(rec["head"])", "expected" => Dict("src" => 2), "regrade" => false,
                           "tool_version" => rec["tool_version"], "tool_rev" => rec["tool_rev"],
                           "tool_tree_sha" => rec["tool_tree_sha"], "config_sha" => rec["config_sha"]))
    end
    conds(carry) = first(G.Passes.carry_conditions(cfg, rd, rec, fs, carry, devnull))
    # a CLOSED id is done, not carried; and no re-rating means no carry, whatever the lane said
    @test any(f -> occursin("not open", f), conds([ids[1]]))
    @test any(f -> occursin("not been re-rated", f), conds([ids[2]]))
    sev = joinpath(rd, "severity.json")
    rate(s) = write(sev, JSON3.write(Dict("schema_version" => 1, "round" => "2026-01-01-check-docs-01",
                                          "ratings" => [Dict("id" => ids[2], "severity" => s, "reason" => "r"^12)])))
    rate("major"); @test any(f -> occursin("never carried", f), conds([ids[2]]))   # serious: fix it
    rate("minor"); @test isempty(conds([ids[2]]))                                   # minor: it may go
    # and the round closes on it, with the finding written forward whole
    @test G.Passes.close(cfg, "2026-01-01-check-docs-01"; carry = [ids[2]], io = devnull) == 0
    led = TOML.parsefile(joinpath(root, ".gbg", "carried.toml"))
    e = only(led["carried"])
    @test e["id"] == ids[2] && e["severity"] == "minor" && e["carries"] == 1 && e["instrument"] == "check-docs"
    @test e["title"] == "t2" && !isempty(e["locations"])                            # re-bankable, not just a note
    @test G.RoundFiles.state(G.RoundFiles.read_round(rd))== :closed
    @test G.RoundFiles.read_round(rd)["closed_by"]["carried"] == [ids[2]]
    # the limit: a finding that has ridden CARRY_LIMIT rounds is not a deferral any more
    e["carries"] = G.Passes.CARRY_LIMIT
    open(joinpath(root, ".gbg", "carried.toml"), "w") do f; TOML.print(f, led); end
    @test any(f -> occursin("escalate", f), conds([ids[2]]))
end

# A closed id back in scope — the fix pass touched a file it names — is asked whether it REGRESSED, and by
# the state verifier alone: its fix is not in this pass's diff, so the act verifier could only ever say
# UNDONE, and in 2026-09-10-check-docs-03 that closed 22 of 40 ids by adjudication instead of by their
# fixes. The act verdict that closed it stands. All three outcomes: still absent, back, and unread.
@testset "a re-checked id is asked whether it regressed, by the state verifier alone" begin
    root = fixture_copy("recheck")
    cfg = G.Config.read(root)
    name = "2026-01-01-check-docs-01"
    dir = joinpath(root, ".gbg", "rounds", name)
    p1 = joinpath(dir, "verdicts", "pass-1"); p2 = joinpath(dir, "verdicts", "pass-2")
    mkpath(p1); mkpath(joinpath(p2, "act")); mkpath(joinpath(p2, "state"))
    ids = ["$name/src#$i" for i in 1:3]
    fs = [Dict{String,Any}("id" => ids[i], "lane" => "src", "n" => i, "title" => "t$i", "severity" => "minor",
                           "confidence" => "high", "type" => "structure", "locations" => ["src/FixtureA.jl:$i — \"q$i\""],
                           "description" => "d"^24) for i in 1:3]
    fj = joinpath(dir, "findings.json")
    write(fj, JSON3.write(Dict("schema_version" => 1, "round" => name, "findings" => fs)))
    head = something(G.Git.head(root), "0"^40)
    rec = merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => name, "instrument" => "check-docs", "schema_version" => 1,
        "head" => head, "roster" => Any[Dict("key" => "src", "substrate" => "full", "anchor" => false)],
        "cost" => "economy", "strength" => "economy", "hostname" => "t", "model_hint" => "sonnet",
        "opened" => "2026-01-01T00:00:00", "dead_lanes" => String[], "passes" => 2,
        "banked" => "2026-01-01T00:00:01", "findings_sha" => G.RoundFiles.sha256_file(fj)))
    write_round(dir, rec)
    honored = Dict("act" => "HONORED", "act_demoted" => false, "state" => "ABSENT", "closed_by" => "honored")
    write(joinpath(p1, "tally.json"), JSON3.write(Dict("schema_version" => 1, "round" => name, "pass" => 1,
        "per_id" => Dict(id => honored for id in ids), "totals" => Dict("findings" => 3, "seeded" => 0, "closed" => 3, "open" => 0),
        "demoted_by_rule" => 0, "adjudicated_share" => 0.0, "suspect_hats" => String[], "dead_lanes" => String[],
        "rejected_files" => String[], "open_ids" => String[], "pending_state" => String[], "plateau" => 0)))
    stamp(d, extra) = open(joinpath(d, "pass.toml"), "w") do f
        TOML.print(f, merge(Dict{String,Any}("nonce" => "c"^32, "opened" => "2026-01-01T00:00:02", "head" => head,
            "range" => "$head..$head", "fix_range" => "$head..$head", "expected" => Dict("src" => 3), "regrade" => false,
            "tool_version" => rec["tool_version"], "tool_rev" => rec["tool_rev"],
            "tool_tree_sha" => rec["tool_tree_sha"], "config_sha" => rec["config_sha"]), extra))
    end
    stamp(p1, Dict("pass" => 1))
    stamp(p2, Dict("pass" => 2, "nonce" => "d"^32, "scope" => ids, "rechecked" => ids, "state_ids" => ids))
    # no act file at all: none is owed for a re-check. The state verifier: one absent, one back, one unread.
    write(joinpath(p2, "state", "01-src.json"), JSON3.write(Dict("schema_version" => 1, "lane" => "src",
        "graded_sha256" => rec["findings_sha"], "pass_nonce" => "d"^32,
        "verdicts" => [Dict("id" => ids[1], "verdict" => "ABSENT", "evidence" => "searched the corpus"),
                       Dict("id" => ids[2], "verdict" => "PRESENT", "evidence" => "the sentence is back")])))
    @test G.Passes.grade(cfg, name; io = devnull) == 1                     # one regressed: not clean
    tal = JSON3.read(read(joinpath(p2, "tally.json"), String), Dict{String,Any})
    @test isempty(tal["dead_lanes"])                                      # no act lane was owed, none is dead
    e1, e2 = tal["per_id"][ids[1]], tal["per_id"][ids[2]]
    @test e1["closed_by"] == "honored" && e1["act"] == "HONORED" && e1["rechecked"] == true   # still absent: stays closed
    @test e2["closed_by"] === nothing && e2["state"] == "PRESENT"                           # back: reopened
    @test tal["open_ids"] == [ids[2]] && tal["pending_state"] == [ids[3]]                   # unread: re-read next pass
end

# A round has a budget of passes (`max_passes`, 3 by default). Past it no pass opens, and `close` carries
# what is still open into the next round — a serious finding too, since the budget and not the severity
# is what stopped the loop; severity then decides whether a final release may cite the round. Both
# directions: below the budget a serious finding is fixed, not carried, and a --regrade that verified no
# new fix spends nothing; at it the pass is refused and the close carries the rest.
@testset "three passes, then what is still open is carried" begin
    root = fixture_copy("budget")
    cfg = G.Config.read(root)
    @test cfg["instruments"]["check-docs"]["max_passes"] == 3
    name = "2026-01-01-check-docs-01"
    dir = joinpath(root, ".gbg", "rounds", name); mkpath(dir)
    ids = ["$name/src#$i" for i in 1:2]
    fs = [Dict{String,Any}("id" => ids[i], "lane" => "src", "n" => i, "title" => "t$i", "severity" => "major",
                           "confidence" => "high", "type" => "structure", "locations" => ["src/FixtureA.jl:$i — \"q$i\""],
                           "description" => "d"^24) for i in 1:2]
    fj = joinpath(dir, "findings.json")
    write(fj, JSON3.write(Dict("schema_version" => 1, "round" => name, "findings" => fs)))
    head = something(G.Git.head(root), "0"^40)
    rec = merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => name, "instrument" => "check-docs", "schema_version" => 1,
        "head" => head, "roster" => Any[Dict("key" => "src", "substrate" => "full", "anchor" => false)],
        "cost" => "economy", "strength" => "economy", "hostname" => "t", "model_hint" => "sonnet",
        "opened" => "2026-01-01T00:00:00", "dead_lanes" => String[], "passes" => 3,
        "build" => Dict{String,Any}("code" => 0, "head" => head, "at" => "2026-01-01T00:00:02"),
        "banked" => "2026-01-01T00:00:01", "findings_sha" => G.RoundFiles.sha256_file(fj)))
    write_round(dir, rec)
    per = Dict(ids[1] => Dict("act" => "LINE-ONLY", "act_demoted" => false, "state" => "PRESENT", "closed_by" => nothing),
               ids[2] => Dict("act" => "HONORED", "act_demoted" => false, "state" => "ABSENT", "closed_by" => "honored"))
    passfile(j, counted) = open(joinpath(dir, "verdicts", "pass-$j", "pass.toml"), "w") do f
        TOML.print(f, Dict("pass" => j, "nonce" => string(j)^32, "opened" => "2026-01-01T00:00:02", "head" => head,
            "range" => "$head..$head", "fix_range" => "$head..$head", "expected" => Dict("src" => 2), "regrade" => !counted,
            "counted" => counted, "tool_version" => rec["tool_version"], "tool_rev" => rec["tool_rev"],
            "tool_tree_sha" => rec["tool_tree_sha"], "config_sha" => rec["config_sha"]))
    end
    for j in 1:3
        mkpath(joinpath(dir, "verdicts", "pass-$j"))
        write(joinpath(dir, "verdicts", "pass-$j", "tally.json"), JSON3.write(Dict("schema_version" => 1, "round" => name, "pass" => j,
            "per_id" => per, "totals" => Dict("findings" => 2, "seeded" => 0, "closed" => 1, "open" => 1), "demoted_by_rule" => 0,
            "adjudicated_share" => 0.0, "suspect_hats" => String[], "dead_lanes" => String[], "rejected_files" => String[],
            "open_ids" => [ids[1]], "pending_state" => String[], "plateau" => 0)))
        passfile(j, j != 2)                                              # pass 2: a regrade that verified no new fix
    end
    write(joinpath(dir, "severity.json"), JSON3.write(Dict("schema_version" => 1, "round" => name,
        "ratings" => [Dict("id" => ids[1], "severity" => "major", "reason" => "r"^12)])))
    # below the budget: two passes spent, and a serious finding is fixed, not carried
    @test G.Passes.pass_budget(cfg, dir, rec, 4) == (2, 3)
    io = IOBuffer(); @test G.Passes.close(cfg, name; io) == 1
    @test occursin("1 open id(s) in pass 3", String(take!(io)))
    io = IOBuffer(); @test G.Passes.close(cfg, name; carry = [ids[1]], io) == 1
    @test occursin("never carried", String(take!(io)))
    # at the budget: no fourth pass, and close carries the rest, serious or not
    passfile(2, true)
    @test G.Passes.pass_budget(cfg, dir, rec, 4) == (3, 3)
    io = IOBuffer(); @test G.Passes.pass_open(cfg, name; io) == 2
    @test occursin("budget is spent", String(take!(io)))
    @test !isdir(joinpath(dir, "verdicts", "pass-4"))                     # nothing half-opened left behind
    io = IOBuffer(); @test G.Passes.close(cfg, name; io) == 0
    @test occursin("carrying the 1 id(s) still open", String(take!(io)))
    e = only(TOML.parsefile(joinpath(root, ".gbg", "carried.toml"))["carried"])
    @test e["id"] == ids[1] && e["severity"] == "major"
    @test G.RoundFiles.read_round(dir)["closed_by"]["carried"] == [ids[1]]
    # severity now decides the release: a carried serious finding holds it back, a minor one does not
    led(sev) = Dict{String,Any}("carried" => [Dict{String,Any}("id" => "x", "severity" => sev, "carries" => 1)], "history" => Any[])
    @test any(f -> occursin("serious finding is carried", f), G.carry_release_fails(led("major")))
    @test isempty(G.carry_release_fails(led("minor")))
end

# Nothing closes on one reading. An id the act verifier closes with no state reading is PENDING — not
# closed, not open, driving no fix — and `close` refuses while one stands; `pass_scope` re-reads it next
# pass. Both directions here: the id that was read closes, the id that was not goes pending and blocks
# the close until it is read.
@testset "nothing closes on one reading: pending_state" begin
    root = fixture_copy("blind-scope")
    cfg = G.Config.read(root)
    dir = joinpath(root, ".gbg", "rounds", "2026-01-01-check-docs-01")
    pd = joinpath(dir, "verdicts", "pass-1"); mkpath(joinpath(pd, "act")); mkpath(joinpath(pd, "state"))
    lane = rec_lane = "src"
    fs = [Dict{String,Any}("id" => "2026-01-01-check-docs-01/src#$i", "lane" => lane, "n" => i, "title" => "t$i", "severity" => "minor",
                           "confidence" => "high", "type" => "structure", "locations" => ["src/FixtureA.jl:1 — \"q$i\""],
                           "description" => "d"^24) for i in 1:2]
    fj = joinpath(dir, "findings.json")
    write(fj, JSON3.write(Dict("schema_version" => 1, "round" => "2026-01-01-check-docs-01", "findings" => fs)))
    st = G.Preflight.stamps(cfg)
    rec = merge(st, Dict{String,Any}("round" => "2026-01-01-check-docs-01", "instrument" => "check-docs", "schema_version" => 1,
        "head" => something(G.Git.head(root), "0"^40), "roster" => Any[Dict("key" => lane, "substrate" => "full", "anchor" => false)],
        "cost" => "economy", "strength" => "economy", "hostname" => "t", "model_hint" => "sonnet",
        "opened" => "2026-01-01T00:00:00", "dead_lanes" => String[], "passes" => 1,
        "build" => Dict{String,Any}("code" => 0, "head" => something(G.Git.head(root), "0"^40), "at" => "2026-01-01T00:00:02"),
        "banked" => "2026-01-01T00:00:01", "findings_sha" => G.RoundFiles.sha256_file(fj)))
    write_round(dir, rec)
    nonce = "a"^32
    # the state verifier was asked for #1 alone; #2 is a suspect the act verifier re-confirmed
    open(joinpath(pd, "pass.toml"), "w") do f
        TOML.print(f, Dict("pass" => 1, "nonce" => nonce, "opened" => "2026-01-01T00:00:02", "head" => rec["head"],
                           "range" => "$(rec["head"])..$(rec["head"])", "fix_range" => "$(rec["head"])..$(rec["head"])",
                           "expected" => Dict(lane => 2), "regrade" => false, "state_ids" => ["2026-01-01-check-docs-01/src#1"],
                           "tool_version" => rec["tool_version"], "tool_rev" => rec["tool_rev"],
                           "tool_tree_sha" => rec["tool_tree_sha"], "config_sha" => rec["config_sha"]))
    end
    surf = [Dict("surface" => "src/FixtureA.jl:1", "swept" => true, "evidence" => "the only site")]
    write(joinpath(pd, "act", "01-$lane.json"), JSON3.write(Dict("schema_version" => 1, "lane" => lane,
        "graded_sha256" => rec["findings_sha"], "pass_nonce" => nonce,
        "verdicts" => [Dict("id" => f["id"], "verdict" => "HONORED", "question" => "none", "evidence" => "e"^12,
                            "class_surfaces" => surf) for f in fs])))
    write(joinpath(pd, "state", "01-$lane.json"), JSON3.write(Dict("schema_version" => 1, "lane" => lane,
        "graded_sha256" => rec["findings_sha"], "pass_nonce" => nonce,
        "verdicts" => [Dict("id" => "2026-01-01-check-docs-01/src#1", "verdict" => "ABSENT", "evidence" => "searched the corpus")])))
    @test G.Passes.grade(cfg, "2026-01-01-check-docs-01"; io = devnull) == 1     # not clean: one is unread
    tal = JSON3.read(read(joinpath(pd, "tally.json"), String), Dict{String,Any})
    @test tal["per_id"]["2026-01-01-check-docs-01/src#1"]["closed_by"] == "honored"                     # read twice: closed
    @test tal["per_id"]["2026-01-01-check-docs-01/src#2"]["closed_by"] === nothing
    @test tal["per_id"]["2026-01-01-check-docs-01/src#2"]["state"] === nothing   # nobody was asked
    @test tal["open_ids"] == String[] && tal["pending_state"] == ["2026-01-01-check-docs-01/src#2"]     # pending is not open
    io3 = IOBuffer(); @test G.Passes.close(cfg, "2026-01-01-check-docs-01"; io = io3) == 1
    @test occursin("state verifier never read", String(take!(io3)))
    # read it, and the round closes
    write(joinpath(pd, "state", "01-$lane.json"), JSON3.write(Dict("schema_version" => 1, "lane" => lane,
        "graded_sha256" => rec["findings_sha"], "pass_nonce" => nonce,
        "verdicts" => [Dict("id" => f["id"], "verdict" => "ABSENT", "evidence" => "searched the corpus") for f in fs])))
    p2 = TOML.parsefile(joinpath(pd, "pass.toml")); p2["state_ids"] = ["2026-01-01-check-docs-01/src#1", "2026-01-01-check-docs-01/src#2"]
    open(joinpath(pd, "pass.toml"), "w") do f; TOML.print(f, p2); end
    @test G.Passes.grade(cfg, "2026-01-01-check-docs-01"; io = devnull) == 0
    tal = JSON3.read(read(joinpath(pd, "tally.json"), String), Dict{String,Any})
    @test isempty(tal["pending_state"]) && tal["per_id"]["2026-01-01-check-docs-01/src#2"]["closed_by"] == "honored"
end

# The quote probe is EVIDENCE, never a gate. It reports whether a finding's own quoted text still
# stands in a file the finding named, so no verifier spends a tool call establishing it — and it decides
# nothing, because the quote is the site's identifying text as often as the defect's. Both directions:
# it finds a surviving quote, and it stays silent when the text is gone or the file is not named.
@testset "the quote probe reports, and decides nothing" begin
    root = fixture_copy("probe")
    a = joinpath(root, "src", "FixtureA.jl"); write(a, read(a, String) * "\n# the offending sentence stands here\n")
    f = Dict{String,Any}("id" => "r/x#1", "lane" => "src", "n" => 1, "title" => "t",
                         "locations" => ["src/FixtureA.jl:1 — \"the offending sentence stands here\"",
                                         "docs/src/notation.md:2 — \"a sentence that was never written\""])
    @test G.Passes.quote_probe(root, f) == ["src/FixtureA.jl"]
    write(a, replace(read(a, String), "# the offending sentence stands here\n" => ""))
    @test isempty(G.Passes.quote_probe(root, f))                       # gone from the file it named
    nofile = Dict{String,Any}("id" => "r/y#1", "locations" => ["nowhere at all — \"the offending sentence\""])
    @test isempty(G.Passes.quote_probe(root, nofile))
    # a quotation elsewhere in the tree is not the defect: the probe reads the named file alone, or a
    # changelog entry describing the fix would report its own defect for ever
    write(joinpath(root, "CHANGELOG.md"), "fixed: \"the offending sentence stands here\"\n")
    @test isempty(G.Passes.quote_probe(root, f))
end

# `gbg round build` RECORDS its verdict into ROUND.toml, and `close` reads it back. Nothing recorded a
# build before 2026-09-12, so 2026-09-12-check-docs-01 graded two passes against a corpus whose docs
# build did not pass: prepare built green at open, a fix pass's prose edits moved SCAN.PROSE_SHAPE's
# ratchet, and no verb looked again until pass 3 ran the build by hand. Both directions, and cheaply —
# `docs_build` is swapped for a shell one-liner, because what is under test is the RECORDING, not
# Documenter. A red build is recorded as red: it is not forgotten, and close refuses on it.
@testset "round build records its verdict for close to read" begin
    root = fixture_copy("buildrec")
    cfg = G.Config.read(root)
    name = "2026-01-01-check-docs-01"
    dir = joinpath(root, ".gbg", "rounds", name); mkpath(joinpath(dir, "findings"))
    write_round(dir, merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => name, "instrument" => "check-docs",
        "schema_version" => 1, "head" => something(G.Git.head(root), "0"^40), "roster" => Any[], "cost" => "economy",
        "strength" => "economy", "hostname" => "t", "model_hint" => "sonnet", "opened" => "2026-01-01T00:00:00",
        "dead_lanes" => String[], "passes" => 0)))
    cfg["package"]["docs_build"] = "true"
    @test G.Rounds.build(cfg, name; io = devnull) == 0
    b = G.RoundFiles.read_round(dir)["build"]
    @test b["code"] == 0 && !isempty(b["head"]) && haskey(b, "at")
    cfg["package"]["docs_build"] = "exit 1"
    @test G.Rounds.build(cfg, name; io = devnull) == 1
    @test G.RoundFiles.read_round(dir)["build"]["code"] == 1            # red is RECORDED, never forgotten
end

# A round's scripts are frozen at preflight, so a script defect the round ITSELF finds cannot be repaired
# for that round's own verifiers: 2026-09-12-check-docs-01 left two verifiers unparseable in its scratch
# copy and refreshed them by hand, which left no trace that the frozen scripts had moved. The verb records
# every refresh, and APPENDS — a record keeping only the last one would hide exactly what it exists to show.
@testset "refreshing a round's frozen scripts is recorded" begin
    root = fixture_copy("refresh")
    cfg = G.Config.read(root)
    name = "2026-01-01-check-docs-01"
    dir = joinpath(root, ".gbg", "rounds", name); mkpath(joinpath(dir, "findings"))
    write_round(dir, merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => name, "instrument" => "check-docs",
        "schema_version" => 1, "head" => something(G.Git.head(root), "0"^40), "roster" => Any[], "cost" => "economy",
        "strength" => "economy", "hostname" => "t", "model_hint" => "sonnet", "opened" => "2026-01-01T00:00:00",
        "dead_lanes" => String[], "passes" => 0)))
    @test !haskey(G.RoundFiles.read_round(dir), "scripts_refreshed")     # nothing recorded before one runs
    @test G.Rounds.refresh_scripts(cfg, name; io = devnull) == 0
    @test isfile(joinpath(G.Preflight.workflow_dir(cfg, name), "lanes.js"))
    r = G.RoundFiles.read_round(dir)
    @test length(r["scripts_refreshed"]) == 1 && haskey(r["scripts_refreshed"][1], "at")
    @test G.Rounds.refresh_scripts(cfg, name; io = devnull) == 0
    @test length(G.RoundFiles.read_round(dir)["scripts_refreshed"]) == 2  # APPENDED, never overwritten
end

# `gbg release` had NO test at all, and that is how a branch which could never succeed survived nine
# releases: it was UNTESTABLE as written, reading pkgdir(GBGCodingTools) directly, so it could only ever
# act on the real checkout. It takes a `root` now, defaulting to the same thing. Every case here REFUSES
# on purpose — the accepting path tags and pushes, and a test must never cut a tag — and each asserts on
# the refusal's own MESSAGE, because `fails` accumulates and a bare exit 2 would pass for any reason at
# all, which is the vacuity this item exists to end.
@testset "gbg release refuses, and says which condition failed" begin
    @test G.release("not-a-version"; io = devnull, skip_tests = true) == 2   # before any root is read
    root = fixture_copy("release")
    git(args...) = run(pipeline(setenv(`git -C $root -c user.email=t@t -c user.name=t $args`,
                                       "HOME" => root, "PATH" => ENV["PATH"]); stdout = devnull, stderr = devnull))
    git("init", "-q", "-b", "master"); git("add", "-A"); git("commit", "-q", "-m", "base")
    # an ABSENT changelog is a named refusal, not a crash: a bare read threw SystemError out of the verb
    # — exit 3 — where every sibling condition is a line in `fails` and exit 2. This test found that.
    io0 = IOBuffer(); @test G.release("9.9.9"; io = io0, skip_tests = true, root) == 2
    @test occursin("CHANGELOG.md is absent", String(take!(io0)))
    write(joinpath(root, "CHANGELOG.md"), "# Changelog\n")
    git("add", "-A"); git("commit", "-q", "-m", "changelog")
    io = IOBuffer()
    @test G.release("9.9.9"; io, skip_tests = true, root) == 2
    out = String(take!(io))
    @test occursin("CHANGELOG.md has no", out)          # present, but carries no 9.9.9 entry
    @test occursin("Project.toml version is", out)      # nor is its version 9.9.9
    # a dirty tree is its own refusal, named separately
    write(joinpath(root, "CHANGELOG.md"), "## 9.9.9 — 2026-01-01\n")
    io2 = IOBuffer(); @test G.release("9.9.9"; io = io2, skip_tests = true, root) == 2
    @test occursin("the tree is not clean", String(take!(io2)))
end

# The conditions a test of `release` itself can NEVER reach: past the refusal list the verb runs
# `git tag` and `git push`, so every case above refuses on purpose and the rc-versus-final split stayed
# unexercised — which is exactly where the unreachable branch lived until 2026-09-12. `release_fails` is
# the refusal list lifted out, reading the tree and writing nothing, so each condition can be asked
# directly. Both directions on the split: a CANDIDATE tolerates an open round, a FINAL release does not.
@testset "release_fails: the conditions past the refusals, and the rc split" begin
    root = fixture_copy("release-fails")
    cfg = G.Config.read(root)
    git(args...) = run(pipeline(setenv(`git -C $root -c user.email=t@t -c user.name=t $args`,
                                       "HOME" => root, "PATH" => ENV["PATH"]); stdout = devnull, stderr = devnull))
    # BOTH headings: the changelog check matches the FULL version, so a candidate needs its own entry and
    # does not inherit the base version's — `## 0.1.0 —` does not satisfy a release of `0.1.0-rc.1`
    write(joinpath(root, "CHANGELOG.md"), "## 0.1.0-rc.1 — 2026-01-01\n\n## 0.1.0 — 2026-01-01\n")
    git("init", "-q", "-b", "master"); git("add", "-A"); git("commit", "-q", "-m", "base")
    clean(rc) = G.release_fails(cfg, root, rc ? "0.1.0-rc.1" : "0.1.0", "0.1.0", rc)
    # a candidate over a clean tree with a matching changelog and version: nothing refuses it
    @test isempty(clean(true))
    # a FINAL release asks more, and says so: no rc tag to lean on
    @test any(f -> occursin("no v0.1.0-rc.N tag", f), clean(false))
    # an OPEN round refuses a final release and NOT a candidate — the split that was unreachable
    rd = joinpath(root, ".gbg", "rounds", "2026-01-01-check-docs-01"); mkpath(rd)
    write_round(rd, merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => "2026-01-01-check-docs-01",
        "instrument" => "check-docs", "schema_version" => 1, "head" => something(G.Git.head(root), "0"^40),
        "roster" => Any[], "cost" => "economy", "strength" => "economy", "hostname" => "t",
        "model_hint" => "sonnet", "opened" => "2026-01-01T00:00:00", "dead_lanes" => String[], "passes" => 0)))
    @test any(f -> occursin("open round(s)", f), clean(false))
    @test !any(f -> occursin("open round(s)", f), clean(true))     # a candidate may be cut mid-round
    # and the carry ledger is consulted for a final release: a serious carried finding holds it back
    led = Dict("schema_version" => 1, "history" => Any[], "carried" => [Dict("id" => "r/x#1",
        "instrument" => "check-docs", "round" => "r", "severity" => "major", "lane" => "src",
        "title" => "t", "locations" => ["src/FixtureA.jl:1 — \"q\""], "description" => "d"^24,
        "carries" => 1, "first_carried" => "2026-01-01T00:00:00")])
    open(joinpath(root, ".gbg", "carried.toml"), "w") do fh; TOML.print(fh, led); end
    git("tag", "-a", "v0.1.0-rc.1", "-m", "rc.1")
    @test any(f -> occursin("a serious finding is carried", f), clean(false))
end

@testset "round lifecycle" begin
    root = fixture_copy("round")
    cfg = G.Config.read(root)
    cd(root) do
        io = IOBuffer()
        dry = G.Preflight.preflight(cfg, "check-docs"; dry = true, io)
        dry_out = String(take!(io))
        dry == 0 || println("preflight --dry refused:\n", dry_out)      # the reason, when the arm fails inside the suite
        @test dry == 0
        @test occursin("would open", dry_out)
        @test G.Preflight.preflight(cfg, "check-docs"; io) == 0
        out = String(take!(io))
        @test occursin("Workflow({scriptPath:", out) && occursin("lanes.js", out)
        rounds = G.RoundFiles.rounds(cfg)
        @test length(rounds) == 1 && rounds[1].state == :open
        round = rounds[1].name; dir = rounds[1].dir
        rec = rounds[1].round
        @test rec["instrument"] == "check-docs" && rec["config_sha"] == G.Preflight.config_sha(cfg)
        @test isfile(joinpath(G.Preflight.workflow_dir(cfg, round), "lanes.js"))
        @test isfile(joinpath(G.Preflight.payload_dir(cfg, round), "policy.md"))
        args = JSON3.read(read(joinpath(G.Preflight.workflow_dir(cfg, round), "main.args.json"), String), Dict{String,Any})
        @test all(l -> isfile(l["brief_path"]), args["lanes"])
        @test !haskey(args, "policy")                                         # payloads are paths, never text
        # a second preflight of the same instrument is refused
        @test G.Preflight.preflight(cfg, "check-docs"; io = devnull) == 2
        # the gate refuses a build now, except under GBG_ROUND. The fixture's round can share its id with
        # a real round of the tool (same date, same instrument), and `gbg round test` exports that id to
        # this very suite: the refusal is asserted with the variable cleared.
        withenv("GBG_ROUND" => nothing) do; @test G.gate(cfg, "check-docs"; io = devnull) == 1; end
        withenv("GBG_ROUND" => round) do; @test G.gate(cfg, "check-docs"; io = devnull) == 0; end
        # lane files by hand: every roster lane, one finding in the first, then bank
        lanes = [Dict("nn" => lpad(i, 2, '0'), "key" => r["key"]) for (i, r) in enumerate(rec["roster"])]
        for (k, l) in enumerate(lanes)
            f = Dict("schema_version" => 1, "round" => round, "lane" => l["key"], "candidates_found" => k == 1 ? 1 : 0,
                     "checked" => ["src/FixtureA.jl"], "findings" => k == 1 ? [Dict("type" => "structure", "severity" => "minor", "confidence" => "high",
                        "title" => "a planted finding for the lifecycle test", "locations" => ["src/FixtureA.jl:1: the module docstring"],
                        "description" => "the lifecycle test's one finding, closed by an adjudication below")] : Any[])
            open(joinpath(dir, "findings", "$(l["nn"])-$(l["key"]).json"), "w") do fh; JSON3.write(fh, f); end
        end
        # lane 00-scans as prepare writes it (the scan half alone; the build is the fixture's test)
        open(joinpath(dir, "findings", "00-scans.json"), "w") do fh
            JSON3.write(fh, Dict("schema_version" => 1, "round" => round, "lane" => "scans", "candidates_found" => 0, "checked" => ["scan docs"], "findings" => Any[]))
        end
        # a DEAD lane first: remove one file, bank must refuse and freeze nothing
        victim = joinpath(dir, "findings", "$(lanes[end]["nn"])-$(lanes[end]["key"]).json"); vtext = read(victim, String); rm(victim)
        @test G.Rounds.bank(cfg, round; io = devnull) == 2
        @test !isfile(joinpath(dir, "findings.json"))
        # an INVALID lane file next (a type outside the closed set): quarantined, no first-sight sha kept,
        # rerun forgets the lane, and the replacement the re-run writes banks (the rc.1 round hit this)
        bad = JSON3.read(vtext, Dict{String,Any}); bad["candidates_found"] = 1
        bad["findings"] = [Dict("type" => "formatted", "severity" => "minor", "confidence" => "high", "title" => "a type outside the closed set",
                                "locations" => ["src/FixtureA.jl:1: x"], "description" => "the closed vocabulary refuses this type")]
        open(victim, "w") do fh; JSON3.write(fh, bad); end
        @test G.Rounds.bank(cfg, round; io = devnull) == 2
        @test isfile(victim * ".rejected.json") || isfile(replace(victim, ".json" => ".rejected.json"))
        @test !haskey(get(G.RoundFiles.read_round(dir), "lane_shas", Dict()), lanes[end]["key"])
        @test G.Rounds.rerun(cfg, round, [lanes[end]["key"]]; io = devnull) == 0
        write(victim, vtext)
        # what an earlier round carried is re-banked here, after the lanes have run and so out of the
        # panel's sight; a carried finding naming a lane this round does not run is refused, not orphaned
        led = Dict("schema_version" => 1, "carried" => [Dict("id" => "2026-01-01-check-docs-01/src#9",
            "instrument" => "check-docs", "round" => "2026-01-01-check-docs-01", "severity" => "minor",
            "lane" => "no-such-lane", "title" => "carried in", "locations" => ["src/FixtureA.jl:1 — \"x\""],
            "description" => "d"^24, "carries" => 1, "first_carried" => "2026-01-01T00:00:00")])
        open(joinpath(root, ".gbg", "carried.toml"), "w") do fh; TOML.print(fh, led); end
        @test G.Rounds.bank(cfg, round; io = devnull) == 2                     # orphaned: refused, not banked
        led["carried"][1]["lane"] = lanes[1]["key"]
        open(joinpath(root, ".gbg", "carried.toml"), "w") do fh; TOML.print(fh, led); end
        @test G.Rounds.bank(cfg, round; io = devnull) == 0
        @test isfile(joinpath(dir, "findings.json")) && isfile(joinpath(dir, "findings.md"))
        rec = G.RoundFiles.read_round(dir)
        @test haskey(rec, "findings_sha") && haskey(rec, "banked")
        findings = JSON3.read(read(joinpath(dir, "findings.json"), String), Dict{String,Any})["findings"]
        @test length(findings) == 2 && findings[1]["id"] == "$round/$(lanes[1]["key"])#1"
        # the carried finding rode in whole, keeping the id of the round that first found it
        @test findings[2]["id"] == "2026-01-01-check-docs-01/src#9" && occursin("carry 1", findings[2]["carried_from"])
        @test findings[2]["n"] == 2 && findings[2]["lane"] == lanes[1]["key"]
        # a changed config refuses every round verb until a regrade
        cpath = joinpath(root, ".gbg", "config.toml"); ctext = read(cpath, String)
        write(cpath, ctext * "\n# a comment changes the sha\n")
        @test_throws G.Rounds.RoundError G.Rounds.guard(G.Config.read(root), round; io = devnull)
        write(cpath, ctext)
        # pass open, then verdicts by hand, then grade
        # the sweep check refuses a pass whose fix touched none of what the open findings name; this
        # lifecycle plants verdicts instead of fixing, so it says so rather than pretending otherwise
        @test G.Passes.pass_open(cfg, round; io = devnull) == 2
        # the DEFAULT path — the fix that swept every named location, so no flag is needed — is exercised
        # by the testset above, which drives the predicate pass_open branches on to empty and back
        @test G.Passes.pass_open(cfg, round; sweep_ok = true, io) == 0
        out = String(take!(io)); @test occursin("verify-act.js", out) && occursin("verify-state.js", out)
        pd = joinpath(dir, "verdicts", "pass-1"); pass = TOML.parsefile(joinpath(pd, "pass.toml"))
        # the act verifier reads the fix pass's own diff, not the round's: handing it `range` made every
        # lane agent re-read every commit since the round opened to grade one fix
        @test haskey(pass, "fix_range") && pass["fix_range"] == pass["range"]     # pass 1: they coincide
        aargs = JSON3.read(read(joinpath(G.Preflight.workflow_dir(cfg, round), "pass-1-act.args.json"), String), Dict{String,Any})
        @test aargs["range"] == pass["fix_range"]
        @test haskey(aargs, "quote_probe") && isfile(joinpath(pd, "probe.json"))  # evidence, computed once
        @test pass["state_ids"] == [f["id"] for f in findings]                    # pass 1 is a full blind sweep
        id = findings[1]["id"]; id2 = findings[2]["id"]; lane = lanes[1]
        swept = [Dict("surface" => "src/FixtureA.jl:1", "swept" => true, "evidence" => "the only site")]
        act = Dict("schema_version" => 1, "lane" => lane["key"], "graded_sha256" => rec["findings_sha"], "pass_nonce" => pass["nonce"],
                   "verdicts" => [Dict("id" => id, "verdict" => "HONORED", "question" => "none", "evidence" => "x"^12, "class_surfaces" => Any[]),
                                  Dict("id" => id2, "verdict" => "HONORED", "question" => "none", "evidence" => "y"^12, "class_surfaces" => swept)])
        state = Dict("schema_version" => 1, "lane" => lane["key"], "graded_sha256" => rec["findings_sha"], "pass_nonce" => pass["nonce"],
                     "verdicts" => [Dict("id" => id, "verdict" => "ABSENT", "evidence" => "searched everywhere"),
                                    Dict("id" => id2, "verdict" => "ABSENT", "evidence" => "searched everywhere")])
        open(joinpath(pd, "act", "$(lane["nn"])-$(lane["key"]).json"), "w") do fh; JSON3.write(fh, act); end
        open(joinpath(pd, "state", "$(lane["nn"])-$(lane["key"]).json"), "w") do fh; JSON3.write(fh, state); end
        @test G.Passes.grade(cfg, round; io = devnull) == 1                      # HONORED with no class_surfaces is demoted: open
        t = JSON3.read(read(joinpath(pd, "tally.json"), String), Dict{String,Any})
        @test t["per_id"][id]["act"] == "LINE-ONLY" && t["per_id"][id]["act_demoted"] && t["demoted_by_rule"] == 1
        # a copy-forward verdict (wrong nonce) is REJECTED
        act["pass_nonce"] = "0"^32
        open(joinpath(pd, "act", "$(lane["nn"])-$(lane["key"]).json"), "w") do fh; JSON3.write(fh, act); end
        io2 = IOBuffer(); G.Passes.grade(cfg, round; io = io2); @test occursin("REJECTED", String(take!(io2)))
        # honored properly closes it
        act["pass_nonce"] = pass["nonce"]; act["verdicts"][1]["class_surfaces"] = [Dict("surface" => "src/FixtureA.jl:1", "swept" => true, "evidence" => "the only site")]
        open(joinpath(pd, "act", "$(lane["nn"])-$(lane["key"]).json"), "w") do fh; JSON3.write(fh, act); end
        @test G.Passes.grade(cfg, round; io = devnull) == 0
        t = JSON3.read(read(joinpath(pd, "tally.json"), String), Dict{String,Any})
        @test t["per_id"][id]["closed_by"] == "honored" && isempty(t["open_ids"]) && isempty(t["pending_state"])
        # close: the copy is untracked in the tool's repository, so "committed" holds vacuously; the
        # closing head is the tool's HEAD and the opening head is an ancestor of it
        # A docs round closes only over a recorded green build. The record is written here rather than by
        # calling `Rounds.build`, which would run the fixture's real Documenter build inside the unit
        # suite; the verb's own recording is pinned directly by the testset above, so the behaviour is
        # exercised somewhere rather than stubbed everywhere.
        let r = G.RoundFiles.read_round(dir)
            r["build"] = Dict{String,Any}("code" => 0, "head" => something(G.Git.head(root), "0"^40), "at" => "2026-01-01T00:00:09")
            G.Rounds.save(dir, r)
        end
        @test G.Passes.close(cfg, round; io = devnull) == 0
        rec = G.RoundFiles.read_round(dir)
        @test G.RoundFiles.state(rec) == :closed && haskey(rec["closed_by"], "tally_sha")
        @test G.gate(cfg; io = devnull) == 0
        # a closed round is frozen: ROUND.FROZEN sees a tampered tally
        tj = joinpath(pd, "tally.json"); write(tj, read(tj, String) * "\n")
        checks, _ = G.Doctor.run(cfg; only = ["ROUND.FROZEN"], io = devnull)
        @test first(checks).status == :FAIL
        # this round closed at a dev stamp, so no release may cite it and abandon still takes it — the exit
        # that a closed dev round would otherwise not have. A tag-stamped one is refused (the testset above).
        @test G.Rounds.abandon(cfg, round, "closed at a dev stamp, which no release may cite"; io = devnull) == 0
        @test G.RoundFiles.state(G.RoundFiles.read_round(dir)) == :abandoned
    end
end
