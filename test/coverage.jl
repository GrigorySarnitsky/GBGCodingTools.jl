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
        @test G.main(["sync", "--check"]) == 0
        # The ConfigError arm, both directions. A consumer's bad config is exit 2 for ANY verb — the arm
        # had no test at all, and before it only three verbs caught the class. A config the verb itself
        # has just written failing to read back is the tool's crash, exit 3, which the arm used to swallow.
        cp_ = joinpath(root, ".gbg", "config.toml"); good = read(cp_, String)
        # An unknown table was the refusal here until 2026-09-17, when the schema that closed the key set
        # was deleted. What still cannot be read is a file that is not TOML, which is the same arm.
        write(cp_, good * "\n[[[not toml\n")
        redirect_stderr(devnull) do
            @test G.main(["config", "show"]) == 2                          # the consumer's mistake: cannot evaluate
            # The rebuilt reader's error is its own type, and reached the crash arm — exit 3 with a
            # backtrace — where the contract promises 2 (found in review, 2026-09-23).
            cj = joinpath(root, ".gbg", "config.jl"); had = isfile(cj) ? read(cj, String) : nothing
            write(cj, "Config(package = f())\n")                             # a call, not data
            try
                @test G.main(["docfix", "check"]) == 2
            finally
                had === nothing ? rm(cj) : write(cj, had)
            end
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
        @test G.main(["config", "show"]) == 0
        # The ledger arm stood here: a consumer's `.gbg/exemptions.toml` that did not parse had to be
        # exit 2 rather than a backtrace (2026-09-15-audit-changes-01). That file is deleted; what a
        # package turns off is a `Switch` in `.gbg/config.jl`, and a config that does not parse is
        # already exit 2 above, by the same arm.
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

# "every doctor check runs without crashing" stood here until 2026-09-17, calling each of the doctor's
# checks and requiring a status rather than an exception. The doctor is deleted: what it judged of a
# package's wiring is the wiring check, which test/wiring.jl drives by flipping a byte in each generated
# path in turn — a stronger test, since it requires the check to FAIL as well as to run.

# The consolidator's golden-manuscript testset stood here until 2026-09-17. `Consolidate` turned a built
# site into one manuscript for the check-consistency panel to read; the panel and the verb went together,
# and the golden file under test/golden/ went with them.
