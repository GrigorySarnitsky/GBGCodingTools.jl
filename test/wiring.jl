# test/wiring.jl — the wiring check, shown to catch what it exists for (docs/ARCHITECTURE.md §6).
#
# Every file that connects a package to this one is the return value of a Julia function. The check runs
# those functions again and compares. So the test flips one byte in each generated path in turn and
# requires the check to report that path — a check that cannot fail is worse than none, and this one is
# what stands between a hand-edited generated file and a package that believes it is wired.
using Test, Pkg, GBGCodingTools
include("helpers.jl")

const RN = G.Render
const MW = G.Model

function wired_package()
    dir = mktempdir(; cleanup = true)
    mkpath(joinpath(dir, ".gbg"))
    write(joinpath(dir, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
    cfg = G.ConfigIO.read_config(dir)
    write(joinpath(dir, ".gitignore"), "# the package's own line\n*.tmp\n")
    RN.write_all(cfg, dir)
    return dir, cfg
end

@testset "the wiring check" begin
    @testset "a freshly written package is clean" begin
        dir, cfg = wired_package()
        @test isempty(RN.wiring(cfg, dir))
    end

    @testset "one changed byte in any generated path is reported" begin
        for g in RN.GENERATED
            dir, cfg = wired_package()
            full = joinpath(dir, g.path)
            text = read(full, String)
            # the change must land INSIDE the generated part: for a block file the package's own lines
            # sit around it and are none of this package's business
            lines = split(text, '\n')
            inside = if g.part == MW.Part.BLOCK
                # the marker is matched anywhere in the line, as `Render.block_of` matches it: the
                # comment syntax differs by file and the block is the same block
                b = findfirst(l -> occursin(RN.BEGIN_MARK, l), lines)
                e = findfirst(l -> occursin(RN.END_MARK, l), lines)
                findfirst(i -> b < i < e && !isempty(strip(lines[i])), eachindex(lines))
            else
                findfirst(i -> !isempty(strip(lines[i])), eachindex(lines))
            end
            lines[inside] = lines[inside] * " "
            write(full, join(lines, '\n'))
            drift = RN.wiring(cfg, dir)
            @test length(drift) == 1
            @test first(drift).file == g.path
        end
    end

    # The line this package tells a consumer to write must PARSE. It did not: `@__DIR__ |> dirname` is a
    # parse error, because a macro call takes the rest of the line as its arguments, and the line had
    # been copied verbatim into two suites before anything ran it.
    @testset "the line a consumer is told to write is valid Julia" begin
        @test Meta.parse(RN.runtests_call()) isa Expr
        @test occursin("Harness.test", RN.runtests_call())
    end

    # A package whose suite does not call the harness runs no rule and is green about it; likewise a
    # build that calls Documenter directly. Both directions, on both files.
    @testset "a package that does not call in is reported" begin
        dir = mktempdir(; cleanup = true)
        mkpath(joinpath(dir, "test")); mkpath(joinpath(dir, "docs"))
        write(joinpath(dir, "test", "runtests.jl"), "using Test\n@test true\n")
        write(joinpath(dir, "docs", "make.jl"), "using Documenter\nmakedocs()\n")
        @test length(RN.call_drift(dir)) == 2
        write(joinpath(dir, "test", "runtests.jl"), RN.runtests_call() * "\n")
        write(joinpath(dir, "docs", "make.jl"), "GBGCodingTools.makedocs(cfg)\n")
        @test isempty(RN.call_drift(dir))
        # commented out is not called
        write(joinpath(dir, "docs", "make.jl"), "# GBGCodingTools.makedocs(cfg)\nmakedocs()\n")
        @test length(RN.call_drift(dir)) == 1
        # and a package with neither file is not told to grow one
        rm(joinpath(dir, "test", "runtests.jl")); rm(joinpath(dir, "docs", "make.jl"))
        @test isempty(RN.call_drift(dir))
    end

    # The two banners this package's OWN workflows grep for. Each step exists to catch a green job that
    # ran a bare `Pkg.test()` or called Documenter directly, and each is a regular expression in a YAML
    # file that nothing connected to the string it matches. Phase 2 renamed the test banner from `gate` to
    # `checks`, the CI step kept greping `gate`, and every push after it was red on a step whose only
    # subject was its own staleness — found on the v2.0.0-rc.3 tag, not before.
    @testset "the workflows grep for the banners this package actually prints" begin
        dir, cfg = wired_package()
        banners = Dict("CI.yml" => "GBGCodingTools " * G.Engine.Harness.tool_name(cfg) * " checks",
                       "docs.yml" => "GBGCodingTools " * G.Engine.Harness.tool_name(cfg) * " makedocs")
        root = pkgdir(GBGCodingTools)
        for (file, banner) in banners
            path = joinpath(root, ".github", "workflows", file)
            isfile(path) || continue                       # a clone without the workflows is not a failure
            pats = [m.captures[1] for m in eachmatch(r"grep -Eq '([^']+)' gbg-run\.log", read(path, String))]
            @test !isempty(pats)                           # the step is still there to be checked
            @test any(p -> occursin(Regex(p), banner), pats)
        end
    end

    # `release` refuses to tag a commit CI has not passed. The two live paths — green at HEAD, and no run
    # at an older commit — are exercised by hand against GitHub, because a test may not reach the network.
    # What IS testable offline is the deliberate way past it, which exists so a release is never wedged by
    # a machine without `gh`; it must short-circuit before anything else is consulted.
    @testset "the CI refusal has a deliberate way past it" begin
        withenv("GBG_RELEASE_IGNORE_CI" => "1") do
            @test GBGCodingTools.ci_verdict(pkgdir(GBGCodingTools), "0" ^ 40) === nothing
        end
    end

    # A prerelease pin, which was refused outright until 2026-09-18. Pkg throws `invalid version
    # specifier` on a prerelease in compat, so the rev and the compat bound MUST differ: the rev is the
    # full tag and the bound is the base version, which is what `release` forces `Project.toml` to say
    # before it will tag a candidate at all. Measured against a real resolve from GitHub, not asserted.
    @testset "a prerelease is pinned by its tag and guarded by its base version" begin
        dir, _ = wired_package()
        write(joinpath(dir, ".gbg", "config.jl"), """Config(package = "Sample", tool = v"2.0.0-rc.1")""")
        cfg = G.ConfigIO.read_config(dir)
        entries = RN.pin_entries(cfg, dir, "test")
        @test entries["sources"][RN.PKG]["rev"] == "v2.0.0-rc.1"    # the tag is what pins
        @test entries["compat"][RN.PKG] == "=2.0.0"                 # and Pkg can read the bound
        @test Pkg.Types.semver_spec(entries["compat"][RN.PKG]) isa Pkg.Types.VersionSpec
        # a release is unchanged: base and tag are the same string there
        write(joinpath(dir, ".gbg", "config.jl"), """Config(package = "Sample", tool = v"2.0.0")""")
        released = RN.pin_entries(G.ConfigIO.read_config(dir), dir, "test")
        @test released["sources"][RN.PKG]["rev"] == "v2.0.0"
        @test released["compat"][RN.PKG] == "=2.0.0"
    end

    # A runner cannot fetch a private dependency without a credential, and a workflow that omits the
    # step fails at resolve time with a message about a missing package. Only a RELEASED pin needs it:
    # a checkout resolves over a path. Both directions, both pins.
    @testset "a released pin needs its workflows to authenticate" begin
        dir, _ = wired_package()
        mkpath(joinpath(dir, ".github", "workflows"))
        write(joinpath(dir, ".github", "workflows", "CI.yml"), "jobs:\n  test:\n    steps:\n      - uses: actions/checkout@v6\n")
        dev = G.ConfigIO.read_config(dir)
        @test isempty(RN.ci_drift(dev, dir))                       # a checkout needs no credential
        write(joinpath(dir, ".gbg", "config.jl"), """Config(package = "Sample", tool = v"2.0.0")""")
        pinned = G.ConfigIO.read_config(dir)
        @test length(RN.ci_drift(pinned, dir)) == 1                # a release does
        write(joinpath(dir, ".github", "workflows", "CI.yml"),
              "jobs:\n  test:\n    steps:\n      - uses: ./.github/actions/gbg-auth\n")
        @test isempty(RN.ci_drift(pinned, dir))
        rm(joinpath(dir, ".github"); recursive = true)
        @test isempty(RN.ci_drift(pinned, dir))                    # a package with no workflows is told nothing
    end

    # The ONE page a consumer's site carries about this tool (ruled 2026-09-23): what the documentation is
    # held to, a link to where the rulebook lives, and what this package has customised — nothing else.
    # This tool is the instrument of the package's developer, and its workings are no concern of the
    # package's users. Not compared by the wiring check: it is written at build time, and it is in every
    # package's `generated` list precisely so that no rule reads it.
    @testset "a consumer's page is small: the link and the switches, and no rulebook" begin
        dir, cfg = wired_package()
        written = RN.pages(cfg, dir)
        @test written == ["gbg.md"]
        text = read(joinpath(dir, RN.TOOLING_PAGE), String)
        @test occursin(RN.TOOL_SITE, text)                          # where the rulebook lives
        # under the version directory Documenter publishes to, at the page the rulebook is built as
        @test occursin("(" * RN.RULES_URL * ")", text)
        @test RN.RULES_URL == RN.TOOL_SITE * "dev/" * splitext(basename(RN.RULES_PAGE))[1] * "/"
        @test occursin("Written by AI", text)
        @test !occursin("(@id RULE.", text)                        # no rule is rendered here
        @test count("\n", text) < 40                               # and it stays small
        for r in G.Catalogue.RULES
            @test !occursin(r.statement, text)
        end
        @test !occursin(RN.BEGIN_MARK, text)                       # the managed markers do not leak onto a page

        # what the package has switched off is on it, with the reason and the scope
        off = G.Model.Config(package = cfg.package, tool = cfg.tool, filesets = cfg.filesets,
                             switches = [G.Model.Switch(target = :documentation_review,
                                                        reason = "the tool reviews itself last"),
                                         G.Model.Switch(target = Symbol("RULE.CIT.DOI"),
                                                        reason = "the references are preprints",
                                                        files = ["docs/src/notes.md"])])
        RN.pages(off, dir)
        text = read(joinpath(dir, RN.TOOLING_PAGE), String)
        @test occursin("the tool reviews itself last", text)
        @test occursin("the references are preprints", text)
        @test occursin("`docs/src/notes.md`", text)
        # and the two pages that used to be written are not
        @test !isfile(joinpath(dir, "docs", "src", "gbg-readers.md"))
        @test !isfile(joinpath(dir, "docs", "src", "gbg-instruments.md"))
    end

    # The rulebook is still published, on this package's own site alone, with an anchor per rule so a
    # consumer's page and a finding anywhere can link to the rule by its id.
    @testset "the rulebook page carries every rule, with an anchor each" begin
        dir, cfg = wired_package()
        @test RN.rulebook_page(cfg, dir) == ["gbg-rules.md"]
        text = read(joinpath(dir, RN.RULES_PAGE), String)
        for r in G.Catalogue.RULES
            @test occursin("(@id " * String(r.id) * ")", text)     # linkable from a finding elsewhere
            @test occursin(r.statement, text)                      # and the statement itself is on it
        end
        @test occursin("(@id glossary)", text)                     # the terms the rules use
        @test !occursin(RN.BEGIN_MARK, text)
    end

    # A generated file silently replacing a hand-written workflow is the one wiring mistake that is
    # noticed late, so `gbg init` stops on a path the package wrote itself and writes nothing.
    @testset "init keeps what the package wrote itself" begin
        dir, cfg = wired_package()
        @test isempty(RN.collisions(cfg, dir))                 # everything there came from a generator

        # the package's own CI action, and its own skill of a name the tool also uses
        own = joinpath(dir, RN.CI_ACTION)
        mkpath(dirname(own)); write(own, "name: the package's own action\non: [push]\n")
        skill = joinpath(dir, RN.skill_path(:bug_hunt))
        write(skill, "# /bug-hunt — the package had this command first\n")
        clash = RN.collisions(cfg, dir)
        @test sort(first.(clash)) == sort([RN.CI_ACTION, RN.skill_path(:bug_hunt)])
        @test occursin("the package's own action", last(first(filter(c -> first(c) == RN.CI_ACTION, clash))))

        @test G.Wire.init(dir; io = devnull) == 1              # it stops
        @test read(own, String) == "name: the package's own action\non: [push]\n"   # and writes nothing
        @test occursin("had this command first", read(skill, String))

        # moved away, it wires
        rm(own); rm(skill)
        @test G.Wire.init(dir; io = devnull) == 0
        @test occursin(RN.BEGIN_MARK, read(own, String))
        @test occursin(RN.BEGIN_MARK, read(skill, String))
        @test isempty(RN.collisions(cfg, dir))
    end

    @testset "a missing generated file is reported, not passed over" begin
        dir, cfg = wired_package()
        rm(joinpath(dir, ".claude", "settings.json"))
        drift = RN.wiring(cfg, dir)
        @test length(drift) == 1 && first(drift).file == ".claude/settings.json"
        @test occursin("absent", first(drift).text)
    end

    @testset "a managed block leaves the rest of its file alone" begin
        dir, cfg = wired_package()
        ignore = joinpath(dir, ".gitignore")
        @test occursin("# the package's own line", read(ignore, String))       # written around, not over
        write(ignore, replace(read(ignore, String), "*.tmp" => "*.tmp\n*.bak"))
        @test isempty(RN.wiring(cfg, dir))                                     # the package's own lines are its own
    end

    @testset "a block that has been deleted outright is reported" begin
        dir, cfg = wired_package()
        ignore = joinpath(dir, ".gitignore")
        write(ignore, "# only the package's own lines now\n*.tmp\n")
        drift = RN.wiring(cfg, dir)
        @test length(drift) == 1 && occursin("block is absent", first(drift).text)
    end

    # A skill file is a command a person can type. An instrument the package switched off must not have
    # one, or the command is an invitation to an error message.
    @testset "a switched-off instrument keeps no skill" begin
        dir, cfg = wired_package()
        for i in G.Catalogue.INSTRUMENTS
            @test isfile(joinpath(dir, RN.skill_path(i.id)))
        end
        text = read(joinpath(dir, RN.skill_path(:documentation_review)), String)
        @test occursin("gbg run documentation-review", text)
        @test occursin("gbg run close", text)
        @test occursin("gbg docfix commit", text)            # it has fix passes
        @test !occursin("gbg docfix commit", read(joinpath(dir, RN.skill_path(:bug_hunt)), String))

        off = G.Model.Config(package = cfg.package, tool = cfg.tool, filesets = cfg.filesets,
                             switches = [G.Model.Switch(target = :documentation_review,
                                                        reason = "not while the tool is being rebuilt")])
        # the switches page changes too, since the switch is now one of them
        @test RN.write_all(off, dir) == [".gbg/policy/switches.md", RN.skill_path(:documentation_review)]
        @test !isfile(joinpath(dir, RN.skill_path(:documentation_review)))
        @test !isdir(dirname(joinpath(dir, RN.skill_path(:documentation_review))))
        @test isempty(RN.wiring(off, dir))                    # and its absence is not drift
        @test isempty(RN.write_all(off, dir))                 # nothing to do the second time
        # one left behind after the switch IS drift
        mkpath(dirname(joinpath(dir, RN.skill_path(:documentation_review))))
        write(joinpath(dir, RN.skill_path(:documentation_review)), "stale")
        drift = RN.wiring(off, dir)
        @test length(drift) == 1 && occursin("switched off", first(drift).text)
    end

    @testset "write_all is idempotent, and says what it changed" begin
        dir, cfg = wired_package()
        @test isempty(RN.write_all(cfg, dir))                                  # nothing to do the second time
        rm(joinpath(dir, ".claude", "settings.json"))
        @test RN.write_all(cfg, dir) == [".claude/settings.json"]
    end

    @testset "the hook it writes is executable and guards against its own loop" begin
        dir, cfg = wired_package()
        p = joinpath(dir, ".claude", "hooks", "queue-guard.sh")
        @test Sys.isexecutable(p)
        text = read(p, String)
        @test occursin("stop_hook_active", text)                               # or a session is trapped
        @test occursin("From the last review", text)                           # the heading it must not count
    end

    @testset "this package's own wiring is what its generators write" begin
        @test isempty(RN.wiring(G.ConfigIO.read_config(TOOL), TOOL))
    end
end

# The skill is what a session follows, and it still named the pinned driver after rc.9 made a run copy
# its own and print the call, so the step it gave was the one `Workflow` refuses; and it stated the
# formula rule without the one respelling the guard allows (both found preparing GBGPeriodicFields'
# upgrade, 2026-09-24).
@testset "the review's skill launches what the verb prints, and states the formula rule whole" begin
    _, cfg = wired_package()
    text = RN.skill(cfg, :documentation_review)
    @test occursin("the `Workflow` call the verb just printed", text)
    @test !occursin("run the ONE driver, `drivers/run.js` of the pinned", text)
    @test occursin("turning a code span into a math span", text)
end
