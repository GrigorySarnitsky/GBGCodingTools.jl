using Test, GBGCodingTools, TOML, JSON3
include("helpers.jl")

# The machinery the suite reached through nothing: the entry point and its exit contract, every doctor
# check as a callable, the fan-out scripts as text, and the consolidator against a golden manuscript.
# Each of these was found unexercised by the self-application sweep of 2026-09-09.

@testset "the exit contract of main()" begin
    root = fixture_copy("main-exit")
    cd(root) do
        @test G.main(["probe"]) == 0                                   # 0 clean
        @test G.main(["probe", "--fail"]) == 2                         # 2 cannot evaluate
        @test G.main(["no-such-verb"]) == 2                            # an unknown verb is not a crash
        @test G.main(String[]) == 2                                    # no verb at all
        @test G.main(["scan"]) == 2                                    # a verb missing its noun
        @test G.main(["doctor", "--only", "CFG.VALID"]) == 0
        # The ConfigError arm, both directions. A consumer's bad config is exit 2 for ANY verb — the arm
        # had no test at all, and before it only three verbs caught the class. A config the verb itself
        # has just written failing to read back is the tool's crash, exit 3, which the arm used to swallow.
        cp_ = joinpath(root, ".gbg", "config.toml"); good = read(cp_, String)
        write(cp_, good * "\n[no_such_section]\nx = 1\n")
        redirect_stderr(devnull) do
            @test G.main(["sync", "status"]) == 2                          # the consumer's mistake: cannot evaluate
            G.VERBS["__reads_what_it_wrote"] = args -> (G.Config.read_written(root); 0)
            try
                @test G.main(["__reads_what_it_wrote"]) == 3               # the tool's own write: a crash
            finally
                delete!(G.VERBS, "__reads_what_it_wrote")
            end
        end
        @test_throws G.Config.ConfigWrittenError G.Config.read_written(root)
        @test !(G.Config.ConfigWrittenError <: G.Config.ConfigError)       # a subtype would be caught as exit 2
        write(cp_, good)
        @test G.main(["sync", "status"]) == 0
        # the consumer's LEDGER is its own file too: one that does not parse is exit 2, not a crash with a
        # backtrace (2026-09-15-audit-changes-01)
        lp = joinpath(root, ".gbg", "exemptions.toml"); keep = read(lp, String)
        write(lp, keep * "\n[[exemption]\nthis is not toml\n")
        redirect_stdout(devnull) do; redirect_stderr(devnull) do
            @test G.main(["scan", "docs", "--only", "SCAN.REGISTER"]) == 2
        end; end
        write(lp, keep)
    end
    @test Set(keys(G.VERBS)) == Set(k for k in keys(G.VERBS))          # the table is a table, not a closure
    @test length(G.VERBS) >= 12
end

# Nine testsets stood here until 2026-09-17. Three read the eleven Workflow scripts as text (their
# shape, the shared prelude, a bare code span in a prompt), three held a lane's brief, script and
# schema to one another, and three drove `prepare` and a round of each instrument. The scripts are
# filed under docs/design-record/instruments-v1/ and the round machinery under machinery-v1/; what
# replaces them is one fixed driver and the run stages of docs/ARCHITECTURE.md §6 and §10, and the
# rehearsal that will exercise them is named in IMPLEMENTATION.md Phase 4.

@testset "every doctor check runs without crashing" begin
    root = fixture_copy("doctor-all")
    cfg = G.Config.read(root)
    ids = [id for (id, _) in G.Doctor.CHECKS]
    @test length(ids) == length(unique(ids))                           # no id registered twice
    for id in ids
        id in G.Doctor.DEEP && continue                                # the deep set builds and tests; not here
        checks, _ = G.Doctor.run(cfg; only = [id], io = devnull)
        @test length(checks) == 1
        @test checks[1].status in (:PASS, :FAIL, :WARN, :NA)           # a status, never an exception
        @test checks[1].id == id
    end
end

@testset "the consolidator against a golden manuscript" begin
    # The Julia port's only evidence was a byte comparison run by hand once (Consolidate.jl's header).
    # This pins its output on a tracked corpus, so a rendering rule cannot drift unnoticed.
    dir = joinpath(TMP, "consolidate"); mkpath(dir)
    site = joinpath(FIXTURE, "defects", "html", "clean")
    full = joinpath(dir, "full.txt"); site_only = joinpath(dir, "site.txt")
    pages, nfull, nsite = G.consolidate(site, String[]; out_full = full, out_siteonly = site_only)
    text = read(full, String)
    @test pages == 2 && nfull == length(text) && nsite == nfull        # nothing withheld: the two agree
    @test occursin("===== PAGE: api =====", text) && occursin("===== PAGE: page =====", text)
    @test occursin("# ", text)                                          # a heading rendered as Markdown
    golden = joinpath(TOOL, "test", "golden", "clean-manuscript.txt")
    if isfile(golden)
        @test read(golden, String) == text                              # byte-for-byte, or the port drifted
    else
        mkpath(dirname(golden)); write(golden, text)
        @test_broken false                                              # first run writes it; commit it
    end
    _, _, n2 = G.consolidate(site, ["api"]; out_full = full, out_siteonly = site_only)
    @test n2 < nfull                                                    # a withheld word removes a page
end

