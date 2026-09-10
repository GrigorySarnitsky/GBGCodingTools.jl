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
    write(b, read(b, String) * "\n"); git("add", "-A"); git("commit", "-q", "-m", "the other")
    @test isempty(G.Passes.unswept(cfg, dir, ["r/x#1"], "$base..HEAD"))                      # silent when swept
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

# The blind verifier judges the OPEN ids mid-round, not every id every pass: over this round's 860
# verdict pairs it uniquely blocked 6, all early, while costing half the verifier bill in the four
# passes that cost the most. What keeps that honest is that an id the act verifier closes without a
# blind reading is PENDING — not closed, not open, driving no fix — and `close` refuses while one
# stands, so the round always ends with a full blind sweep. Both directions here: the id that was read
# closes, the id that was not goes pending and blocks the close until it is read.
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
        "banked" => "2026-01-01T00:00:01", "findings_sha" => G.RoundFiles.sha256_file(fj)))
    write_round(dir, rec)
    nonce = "a"^32
    # the blind verifier was asked for #1 alone; #2 is a suspect the act verifier re-confirmed
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
    @test occursin("blind verifier never read", String(take!(io3)))
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
