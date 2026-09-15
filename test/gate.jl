using Test, GBGCodingTools, TOML
include("helpers.jl")

@testset "gate" begin
    root = fixture_copy("gate")
    cfg = G.Config.read(root)
    @test G.gate(cfg; io = devnull) == 0
    # an open round, written the way preflight writes it
    st = G.Preflight.stamps(cfg)
    rd = joinpath(root, ".gbg", "rounds", "2026-09-09-bug-hunt-01"); mkpath(rd)
    rec = merge(st, Dict{String,Any}("round" => "2026-09-09-bug-hunt-01", "instrument" => "bug-hunt", "schema_version" => 1,
        "head" => something(G.Git.head(root), "0"^40), "roster" => Any[], "cost" => "economy", "strength" => "economy", "hostname" => "test",
        "model_hint" => "sonnet", "opened" => "2026-09-09T00:00:00", "dead_lanes" => String[], "passes" => 0))
    open(joinpath(rd, "ROUND.toml"), "w") do f; TOML.print(f, rec); end
    @test G.gate(cfg; io = devnull) == 1
    @test G.gate(cfg, "check-docs", "check-consistency"; io = devnull) == 0        # a docs build ignores a hunt round
    @test G.gate(cfg, "bug-hunt", "audit-changes"; io = devnull) == 1
    withenv("GBG_ROUND" => "2026-09-09-bug-hunt-01") do
        @test G.gate(cfg; io = devnull) == 0                                        # exactly this round is ignored
    end
    withenv("GBG_ROUND" => "2026-09-09-bug-hunt-02") do
        @test G.gate(cfg; io = devnull) == 1                                        # another name ignores nothing
    end
    # frozen_rounds names what the gate refuses FOR, so the docs wrapper can tell a frozen build from a
    # broken one. Both directions: a hunt round is named to whoever asks about bug-hunt and to nobody
    # asking about the docs instruments, and GBG_ROUND removes it exactly as it does for the gate.
    @test G.frozen_rounds(cfg, "bug-hunt", "audit-changes") == ["2026-09-09-bug-hunt-01"]
    @test isempty(G.frozen_rounds(cfg, "check-docs", "check-consistency"))
    @test G.frozen_rounds(cfg) == ["2026-09-09-bug-hunt-01"]                        # all four when none is named
    withenv("GBG_ROUND" => "2026-09-09-bug-hunt-01") do
        @test isempty(G.frozen_rounds(cfg))                                         # the round's own build is not frozen out
    end
    rm(joinpath(rd, "ROUND.toml"))
    @test G.gate(cfg; io = devnull) == 2                                            # a directory without a marker
    rm(rd; recursive = true)
    rm(joinpath(root, ".gbg", "rounds"); recursive = true)
    @test G.gate(cfg; io = devnull) == 2                                            # ROUND.DIR: never vacuous
    @test isempty(G.frozen_rounds(cfg))                                             # no rounds directory freezes nothing
end

# `gbg release` may cut a CANDIDATE while a round is open — the open-round refusal is guarded by `if !rc`
# on purpose — but the permission was unreachable until 2026-09-12: the release build sets
# GBG_DOCS_NO_SKIP, which turns the docs wrapper's skip back into a refusal, and it named no round, so
# the build refused for every open round and every rc cut mid-round failed its own build step. What
# `release` hands that build is `admitted_rounds`, and this is its contract: it names the open DOCS
# rounds, and under it the build is no longer frozen out. `gbg release` itself has no test at all, which
# is how the dead branch survived; this pins the part of it that can be checked without cutting a tag.
@testset "release admits the open docs rounds to its own build" begin
    root = fixture_copy("release-admits")
    cfg = G.Config.read(root)
    @test G.admitted_rounds(cfg, true) == ""                                              # nothing open: nothing admitted
    st = G.Preflight.stamps(cfg)
    mk(name, inst) = begin
        rd = joinpath(root, ".gbg", "rounds", name); mkpath(rd)
        rec = merge(st, Dict{String,Any}("round" => name, "instrument" => inst, "schema_version" => 1,
            "head" => something(G.Git.head(root), "0"^40), "roster" => Any[], "cost" => "economy", "strength" => "economy",
            "hostname" => "test", "model_hint" => "sonnet", "opened" => "2026-09-09T00:00:00", "dead_lanes" => String[], "passes" => 0))
        open(joinpath(rd, "ROUND.toml"), "w") do f; TOML.print(f, rec); end
    end
    mk("2026-09-09-bug-hunt-01", "bug-hunt")
    @test G.admitted_rounds(cfg, true) == ""                          # a hunt round never froze the docs build
    mk("2026-09-09-check-docs-01", "check-docs")
    @test G.admitted_rounds(cfg, true) == "2026-09-09-check-docs-01"
    @test !isempty(G.frozen_rounds(cfg, "check-docs", "check-consistency"))         # without it, the build is refused
    withenv("GBG_ROUND" => G.admitted_rounds(cfg, true)) do
        @test isempty(G.frozen_rounds(cfg, "check-docs", "check-consistency"))      # with it, the build may run
    end
    # two open docs rounds: BOTH are admitted, comma separated, as Gate.jl parses GBG_ROUND
    mk("2026-09-09-check-consistency-01", "check-consistency")
    @test Set(split(G.admitted_rounds(cfg, true), ",")) ==
          Set(["2026-09-09-check-docs-01", "2026-09-09-check-consistency-01"])
    withenv("GBG_ROUND" => G.admitted_rounds(cfg, true)) do
        @test isempty(G.frozen_rounds(cfg, "check-docs", "check-consistency"))
    end
    @test G.admitted_rounds(cfg, false) == ""                   # a final release admits nothing: it refuses an open round
end

# Admitting a round lifts every refusal the gate makes for it, and a candidate's permission is for ONE:
# the round being open. A round whose fixes were committed without it (`:committed`) is not admitted, so
# the release's own build still refuses (2026-09-12-audit-changes-02). Its own repository, since
# `:committed` reads the working tree's status.
@testset "release admits a round only for being open" begin
    root = fixture_copy("release-committed")
    git(args...) = run(pipeline(setenv(`git -C $root -c user.email=t@t -c user.name=t $args`,
                                       "HOME" => root, "PATH" => ENV["PATH"]); stdout = devnull, stderr = devnull))
    git("init", "-q", "-b", "master"); git("add", "-A"); git("commit", "-q", "-m", "base")
    cfg = G.Config.read(root)
    opening = G.Git.head(root)
    rd = joinpath(root, ".gbg", "rounds", "2026-09-09-check-docs-01"); mkpath(rd)
    rec = merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => "2026-09-09-check-docs-01", "instrument" => "check-docs",
        "schema_version" => 1, "head" => opening, "roster" => Any[], "cost" => "economy", "strength" => "economy",
        "hostname" => "test", "model_hint" => "sonnet", "opened" => "2026-09-09T00:00:00", "dead_lanes" => String[], "passes" => 0))
    open(joinpath(rd, "ROUND.toml"), "w") do f; TOML.print(f, rec); end
    git("add", "-A"); git("commit", "-q", "-m", "the round opens")
    withenv("CI" => nothing, "GBG_ROUND" => nothing) do
        @test G.admitted_rounds(cfg, true) == "2026-09-09-check-docs-01"          # open, and only open
        # a fix committed while the round's own files sit modified: HEAD moved past the opening head
        write(joinpath(root, "src", "FixtureA.jl"), read(joinpath(root, "src", "FixtureA.jl"), String) * "\n")
        git("add", "src"); git("commit", "-q", "-m", "a fix without the round")
        write(joinpath(rd, "notes.md"), "uncommitted\n")
        @test G.admitted_rounds(cfg, true) == ""                                  # :committed as well — not admitted
    end
end

# Both of makedocs' gates skip on one condition (docs_build_skipped): a refusal (exit 1) caused by an open
# round of a docs instrument, with GBG_DOCS_NO_SKIP unset. The gate after Documenter once had no skip, so a
# round opened while the site built turned the build red for a round being open. Both directions.
@testset "a docs build skips, not fails, for an open docs round" begin
    root = fixture_copy("docs-skip")
    cfg = G.Config.read(root)
    id = "2026-09-09-check-docs-01"
    rd = joinpath(root, ".gbg", "rounds", id); mkpath(rd)
    rec = merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => id, "instrument" => "check-docs", "schema_version" => 1,
        "head" => something(G.Git.head(root), "0"^40), "roster" => Any[], "cost" => "economy", "strength" => "economy", "hostname" => "test",
        "model_hint" => "sonnet", "opened" => "2026-09-09T00:00:00", "dead_lanes" => String[], "passes" => 0))
    open(joinpath(rd, "ROUND.toml"), "w") do f; TOML.print(f, rec); end
    @test G.docs_build_skipped(cfg, 1) == [id]                                      # frozen: a skip
    @test isempty(G.docs_build_skipped(cfg, 0)) && isempty(G.docs_build_skipped(cfg, 2))   # passed, or cannot evaluate
    # a refusal the open docs round does not explain ALONE is never a skip: beside an open round of a
    # disabled instrument the build fails (ext#4 of 2026-09-11-check-docs-02; the skip used to swallow it)
    cid = "2026-09-09-check-consistency-01"; crd = joinpath(root, ".gbg", "rounds", cid); mkpath(crd)
    open(joinpath(crd, "ROUND.toml"), "w") do f; TOML.print(f, merge(rec, Dict{String,Any}("round" => cid, "instrument" => "check-consistency"))); end
    off = deepcopy(cfg); off["instruments"]["enabled"] = ["check-docs"]
    @test Set(first.(last(G.gate_problems(off, "check-docs", "check-consistency")))) == Set([:open, :disabled])
    @test !isempty(G.frozen_rounds(off, "check-docs", "check-consistency"))         # the old rule would have skipped
    @test isempty(G.docs_build_skipped(off, 1))                                     # the second refusal fails the build
    rm(crd; recursive = true)
    @test first.(last(G.gate_problems(cfg, "check-docs", "check-consistency"))) == [:open]
    withenv("GBG_DOCS_NO_SKIP" => "1") do
        @test isempty(G.docs_build_skipped(cfg, 1))                                 # release and the deep doctor refuse
    end
    rm(rd; recursive = true)
    @test isempty(G.docs_build_skipped(cfg, 1))                                     # a refusal no docs round explains
end

# A docs round whose fixes were committed without it is the one refusal the skip must never absorb: outside
# CI, with HEAD past the round's opening head and the round's files uncommitted, the build fails; once the
# round is committed it skips again (contract-drift#5 of 2026-09-11-audit-changes-02).
@testset "a docs build fails when a docs round's fixes were committed without it" begin
    root = fixture_copy("docs-committed")
    git(args...) = strip(read(setenv(`git -C $root $args`, "GIT_AUTHOR_NAME" => "t", "GIT_AUTHOR_EMAIL" => "t@t", "GIT_COMMITTER_NAME" => "t", "GIT_COMMITTER_EMAIL" => "t@t", "HOME" => root, "PATH" => ENV["PATH"]), String))
    git("init", "-q", "-b", "master"); git("add", "-A"); git("commit", "-q", "-m", "base")
    cfg = G.Config.read(root)
    id = "2026-09-09-check-docs-01"
    rd = joinpath(root, ".gbg", "rounds", id); mkpath(rd)
    rec = merge(G.Preflight.stamps(cfg), Dict{String,Any}("round" => id, "instrument" => "check-docs", "schema_version" => 1,
        "head" => G.Git.head(root), "roster" => Any[], "cost" => "economy", "strength" => "economy", "hostname" => "test",
        "model_hint" => "sonnet", "opened" => "2026-09-09T00:00:00", "dead_lanes" => String[], "passes" => 0))
    open(joinpath(rd, "ROUND.toml"), "w") do f; TOML.print(f, rec); end
    withenv("CI" => nothing, "GBG_ROUND" => nothing, "GBG_DOCS_NO_SKIP" => nothing) do
        @test G.docs_build_skipped(cfg, 1) == [id]                                  # at the opening head: a skip
        write(joinpath(root, "fix.txt"), "a fix\n"); git("add", "fix.txt"); git("commit", "-q", "-m", "a fix without the round")
        @test :committed in first.(last(G.gate_problems(cfg, "check-docs", "check-consistency")))
        @test isempty(G.docs_build_skipped(cfg, 1))                                  # committed around it: fails
        git("add", "-A"); git("commit", "-q", "-m", "the round, committed")
        @test G.docs_build_skipped(cfg, 1) == [id]                                  # committed with it: a skip again
    end
end
