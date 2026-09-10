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
        @test G.main(["round", "list"]) == 0
        @test G.main(["scan"]) == 2                                    # a verb missing its noun
        @test G.main(["doctor", "--only", "CFG.VALID"]) == 0
        @test G.main(["gate"]) == 0                                    # no open round
    end
    @test Set(keys(G.VERBS)) == Set(k for k in keys(G.VERBS))          # the table is a table, not a closure
    @test length(G.VERBS) >= 20
end

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

# A Markdown code span in prompt prose: a bare backtick pair holding a short run, PRECEDED by prose —
# a lowercase word or a sentence end, and a space — where an ordinary template literal follows `=`, `(`,
# `,` or `:`. A comma and a colon were in that lookbehind and are not: `{phase: `Review`}` and
# `f(a, `b`)` are ordinary JavaScript, and so is a literal after `return`, `case`, `await` and the rest
# of the keywords excluded here — a guard that flags six ordinary forms to catch one defect is a guard
# nobody can leave switched on.
const SPAN_IN_PROSE = r"(?<=[a-z.] )(?<!return )(?<!yield )(?<!throw )(?<!typeof )(?<!await )(?<!case )(?<!else )(?<!new )(?<!in )(?<!of )(?<!do )(?<!delete )(?<!instanceof )(?<!\\)`[^`\n\$,)}]{1,60}(?<!\\)`"

@testset "every Workflow script is well formed" begin
    scripts = [joinpath(r, f) for i in ("check-docs", "check-consistency", "bug-hunt", "audit-changes")
               for (r, _, fs) in walkdir(joinpath(TOOL, "instruments", i, "workflow")) for f in fs if endswith(f, ".js")]
    @test length(scripts) == 11
    for s in scripts
        text = read(s, String)
        # the meta block the runner requires, as a pure literal at the top
        @test occursin(r"^export const meta = \{"m, text)
        @test occursin(r"\bname:\s*'", text) && occursin(r"\bdescription:\s*'", text)
        # No JS runtime exists in this environment, so this is not a parse. It is the check that catches
        # the failure actually seen: a template literal left open, which makes every following line part
        # of a string. Backticks outside `//` and `/* */` comments must pair, and no block comment is left
        # open. A brace count is not attempted: a regex literal and a nested template defeat one without a parser.
        code = replace(text, r"//[^\n]*" => "", r"/\*.*?\*/"s => "")
        @test iseven(count(==('`'), code))
        # An even count is not enough, and a round proved it: a Markdown code span written into prompt
        # prose with BARE backticks (`--glob …`) pairs, yet closes the template literal it sits in and
        # reopens it, so the file stops parsing. A code span in prompt text is `\``-escaped. What marks
        # it apart from an ordinary short template literal is what PRECEDES it: prose, a word and a
        # space, where a literal follows `=`, `(` or `,`. Without that the rule would read "no short
        # template literal without an interpolation", which is not the rule and not anyone's to impose.
        @test !occursin(SPAN_IN_PROSE, code)
    end
end

@testset "a bare code span in a Workflow prompt is caught" begin
    # RULE.TEST.BOTH_DIRECTIONS, and in both: the check must fail on the defect it was written for and
    # must pass ordinary JavaScript, since it polices every future edit to eleven frozen scripts.
    broken = replace(read(joinpath(TOOL, "instruments", "bug-hunt", "workflow", "hunt.js"), String), "\\`" => "`")
    code = replace(broken, r"//[^\n]*" => "", r"/\*.*?\*/"s => "")
    @test occursin(SPAN_IN_PROSE, code)
    for prose in ("scope every search with `--glob '!.gbg/**'`.", "Nothing under `.gbg/` is yours to open")
        @test occursin(SPAN_IN_PROSE, prose)
    end
    for js in ("const banner = `ready`", "log(`ok`)", "x = `a b c`", "const q = `\${x}/y`", "x = `Audit`;",
               "return `done`", "const o = {phase: `Review`}", "f(a, `b`)", "case `x`:", "yield `v`",
               "await `x`", "arr.map(x => `y`)")
        @test !occursin(SPAN_IN_PROSE, js)                       # valid JavaScript is not a finding
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

@testset "prepare builds each instrument's substrate" begin
    # `Rounds.prepare` — the scan battery, the reflection checks, the build under GBG_ROUND, the built-HTML
    # scans, and for the panel the consolidated and seeded manuscripts — had no test at all, and with it the
    # whole scan → finding → rescan closure path was unexercised (self-application sweep, 2026-09-09).
    root = fixture_copy("prepare")
    # the copy's docs environment carries the original's stale manifest: resolve it once, with the stdlib
    # back on the load path (under `Pkg.test()` the inherited one names the sandbox and no stdlib)
    let proj = joinpath(root, "docs"), sep = Sys.iswindows() ? ";" : ":"
        rm(joinpath(proj, "Manifest.toml"); force = true)
        run(addenv(`$(Base.julia_cmd()) --startup-file=no --project=$proj -e "using Pkg; Pkg.instantiate()"`,
                   "JULIA_LOAD_PATH" => "@" * sep * "@stdlib"))
    end
    cfg = G.Config.read(root)
    cd(root) do
        @test G.Preflight.preflight(cfg, "check-docs"; io = devnull) == 0
        round = only(filter(r -> r.state == :open, G.RoundFiles.rounds(cfg))).name
        @test G.Rounds.prepare(cfg, round; io = devnull) == 0
        scratch = G.Preflight.scratch_dir(cfg, round)
        report = read(joinpath(scratch, "scans.txt"), String)
        @test occursin("=== REFLECTION CHECKS ===", report)           # the reflection half ran
        @test occursin("SCAN.REGISTER", report)                        # and the scan half
        @test isfile(joinpath(scratch, "build.log"))                   # the docs build ran under GBG_ROUND
        lane = joinpath(root, ".gbg", "rounds", round, "findings", "00-scans.json")
        @test isfile(lane)                                             # every hard hit banked as lane 00-scans
        banked = JSON3.read(read(lane, String), Dict{String,Any})
        @test banked["lane"] == "scans" && banked["candidates_found"] == length(banked["findings"])
        # a hard scan finding closes by RESCAN, never by a verdict: the channel exists and is reachable
        for f in banked["findings"]; @test occursin(r"^SCAN\.[A-Z0-9_.]+ — ", f["title"]); end
        @test G.Rounds.abandon(cfg, round, "the prepare test's round, never graded"; io = devnull) == 0
    end
end

@testset "a round of every instrument reaches its substrate" begin
    # The lifecycle was tested for check-docs only, so the preflight and prepare branches of the other
    # three instruments ran nowhere (self-application sweep, 2026-09-09).
    for inst in ("check-consistency", "bug-hunt", "audit-changes")
        root = fixture_copy("inst-" * inst)
        cfg = G.Config.read(root)
        cd(root) do
            base = inst == "audit-changes" ? "HEAD" : nothing
            code = G.Preflight.preflight(cfg, inst; io = devnull, base)
            @test code == 0
            round = only(filter(r -> r.state == :open, G.RoundFiles.rounds(cfg))).name
            rec = G.RoundFiles.read_round(joinpath(root, ".gbg", "rounds", round))
            @test rec["instrument"] == inst && !isempty(rec["roster"])
            args = JSON3.read(read(joinpath(G.Preflight.workflow_dir(cfg, round), "main.args.json"), String), Dict{String,Any})
            @test haskey(args, "round") && args["round"] == round
            @test all(!haskey(args, k) for k in ("policy", "persona", "brief"))   # payloads are paths, never text
            @test G.Rounds.abandon(cfg, round, "the per-instrument preflight test's round"; io = devnull) == 0
        end
    end
end
