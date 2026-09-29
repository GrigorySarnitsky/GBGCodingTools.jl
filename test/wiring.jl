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
        write(joinpath(dir, ".github", "workflows", "CI.yml"),
              "jobs:\n  test:\n    steps:\n      - uses: actions/checkout@v6\n      - uses: julia-actions/julia-runtest@v1\n")
        dev = G.ConfigIO.read_config(dir)
        @test isempty(RN.ci_drift(dev, dir))                       # a checkout needs no credential
        write(joinpath(dir, ".gbg", "config.jl"), """Config(package = "Sample", tool = v"2.0.0")""")
        pinned = G.ConfigIO.read_config(dir)
        @test length(RN.ci_drift(pinned, dir)) == 1                # a release does
        # a workflow that resolves nothing — TagBot, a linter — is not told to authenticate: it turned
        # every build and test of a released pin red with nothing to fix (found in review, 2026-09-26)
        write(joinpath(dir, ".github", "workflows", "TagBot.yml"),
              "jobs:\n  TagBot:\n    steps:\n      - uses: JuliaRegistries/TagBot@v1\n")
        @test [l.file for l in RN.ci_drift(pinned, dir)] == [".github/workflows/CI.yml"]
        write(joinpath(dir, ".github", "workflows", "CI.yml"),
              "jobs:\n  test:\n    steps:\n      - uses: ./.github/actions/gbg-auth\n      - run: julia --project -e 'using Pkg; Pkg.test()'\n")
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
        @test RN.write_all(off, dir).changed == [".gbg/policy/switches.md", RN.skill_path(:documentation_review)]
        @test !isfile(joinpath(dir, RN.skill_path(:documentation_review)))
        @test !isdir(dirname(joinpath(dir, RN.skill_path(:documentation_review))))
        @test isempty(RN.wiring(off, dir))                    # and its absence is not drift
        @test isempty(RN.write_all(off, dir).changed)         # nothing to do the second time
        # one of OURS left behind after the switch IS drift (a file there without the marker is the
        # package's own, and neither drift nor ours to delete)
        mkpath(dirname(joinpath(dir, RN.skill_path(:documentation_review))))
        write(joinpath(dir, RN.skill_path(:documentation_review)), RN.skill(cfg, :documentation_review))
        drift = RN.wiring(off, dir)
        @test length(drift) == 1 && occursin("switched off", first(drift).text)
    end

    @testset "write_all is idempotent, and says what it changed" begin
        dir, cfg = wired_package()
        @test isempty(RN.write_all(cfg, dir).changed)                          # nothing to do the second time
        rm(joinpath(dir, ".claude", "settings.json"))
        @test RN.write_all(cfg, dir).changed == [".claude/settings.json"]
    end

    # A deferral is rendered beside the switches, with what would close it, so "owed" is on the record
    # where "does not apply" is (Phase 5).
    @testset "a deferral is listed beside the switches" begin
        id = first(G.Catalogue.RULES).id
        cfg = G.Model.Config(package = "Sample", tool = :dev,
                             deferrals = [G.Model.Deferral(rule = id, until = "its pages are rewritten")])
        page = RN.switches(cfg)
        @test occursin("Deferred, not switched off", page)
        @test occursin("`$id` — until its pages are rewritten", page)
        @test !occursin("Deferred", RN.switches(G.Model.Config(package = "Sample", tool = :dev)))
    end

    @testset "the hook it writes is executable and guards against its own loop" begin
        dir, cfg = wired_package()
        p = joinpath(dir, ".claude", "hooks", "queue-guard.sh")
        @test Sys.isexecutable(p)
        text = read(p, String)
        @test occursin("stop_hook_active", text)                               # or a session is trapped
        @test occursin("From the last review", text)                           # the heading it must not count
    end

    # The three git rules are programs in this hook (Phase 5), each the rule's own lines: shown on a
    # repository the way the rule's examples are, and read by `gbg check` from the same lines — never by
    # a build, which sees nothing of the history.
    @testset "the hook holds a session to the git rules" begin
        root = mktempdir(; cleanup = true)
        mkpath(joinpath(root, ".claude")); mkpath(joinpath(root, ".gbg"))
        write(joinpath(root, ".gbg", "config.jl"), """Config(package = "P", tool = :dev)""")
        env = ["GIT_AUTHOR_NAME" => "t", "GIT_AUTHOR_EMAIL" => "t@t", "GIT_COMMITTER_NAME" => "t", "GIT_COMMITTER_EMAIL" => "t@t"]
        git(args...) = run(pipeline(setenv(`git -C $root $args`, env; dir = root); stdout = devnull, stderr = devnull))
        git("init", "-q", "-b", "master"); git("commit", "-q", "--allow-empty", "-m", "first")
        git("init", "-q", "--bare", ".origin.git"); git("remote", "add", "origin", joinpath(root, ".origin.git"))
        git("push", "-q", "-u", "origin", "master")
        sh = joinpath(root, "hook.sh"); write(sh, RN.hook(G.ConfigIO.read_config(root))); chmod(sh, 0o755)
        function fire()
            err = IOBuffer()
            p = run(pipeline(setenv(`bash $sh`, ["CLAUDE_PROJECT_DIR" => root]; dir = root);
                             stdin = IOBuffer("{}"), stdout = devnull, stderr = err); wait = false)
            wait(p); return p.exitcode, String(take!(err))
        end
        @test first(fire()) == 0                                         # pushed, on master: the turn may end
        git("commit", "-q", "--allow-empty", "-m", "second")             # not pushed, and no trailer
        code, msg = fire()
        @test code == 2
        @test occursin("RULE.GIT.PUSH", msg) && occursin("RULE.GIT.TRAILER", msg) && !occursin("RULE.GIT.BRANCH", msg)
        cfg = G.ConfigIO.read_config(root)
        found = G.Engine.Checks.run_all(cfg, root; history = true)
        @test Set(String(id) for (id, _) in found) == Set(["RULE.GIT.PUSH", "RULE.GIT.TRAILER"])
        @test isempty(G.Engine.Checks.run_all(cfg, root))               # a build sees nothing of the history
        @test !any(id -> startswith(String(id), "RULE.GIT."), G.Engine.Checks.not_run(cfg))   # and is not told it missed them
        git("checkout", "-q", "-b", "feature")
        @test occursin("RULE.GIT.BRANCH", last(fire()))
        # the loop guard covers this too, or a session that cannot push is trapped
        held = IOBuffer()
        p = run(pipeline(setenv(`bash $sh`, ["CLAUDE_PROJECT_DIR" => root]; dir = root);
                         stdin = IOBuffer("""{"stop_hook_active": true}"""), stdout = devnull, stderr = held); wait = false)
        wait(p); @test p.exitcode == 0
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
    @test occursin("a math span with the same text, or back", text)
    @test occursin("gbg run park <id> --why", text)            # a finding only the owner may fix is parked
end

# The code review of 2026-09-26, group A: each of these failed on the tree it was found in.
@testset "what the review of 2026-09-26 found in the wiring" begin

    # `init` asked about collisions only when a config already existed, so the one run that writes a
    # package's first wiring was the one that never asked, and wrote over the package's own files.
    @testset "the FIRST init keeps what the package wrote itself" begin
        dir = mktempdir(; cleanup = true)
        write(joinpath(dir, "Project.toml"), "name = \"Sample\"\nuuid = \"7f0c3a5e-1b2d-4c3e-9f4a-5b6c7d8e9f02\"\n")
        own = joinpath(dir, RN.CI_ACTION); mkpath(dirname(own)); write(own, "name: the package's own action\n")
        skill = joinpath(dir, RN.skill_path(:bug_hunt)); mkpath(dirname(skill)); write(skill, "# /bug-hunt, the package's\n")
        @test G.Wire.init(dir; io = devnull) == 1
        @test !isfile(joinpath(dir, ".gbg", "config.jl"))          # nothing was written, the config included
        @test read(own, String) == "name: the package's own action\n"
        @test read(skill, String) == "# /bug-hunt, the package's\n"
        rm(own); rm(skill)
        @test G.Wire.init(dir; io = devnull) == 0
        @test occursin("package = \"Sample\"", read(joinpath(dir, ".gbg", "config.jl"), String))
    end

    # `sync` wrote over any file at a generated path, so a path a newer version generates replaced a
    # hand-written file on upgrade, while the same package's re-run `init` refused it.
    @testset "sync refuses the package's own file at a generated path, and writes the rest" begin
        dir, cfg = wired_package()
        note = joinpath(dir, "test", "regressions", "README.md")
        write(note, "# The package's own note on its regressions\n")
        rm(joinpath(dir, ".gbg", "policy", "glossary.md"))
        out = IOBuffer()
        @test G.Wire.sync(dir; io = out) == 1
        @test occursin("test/regressions/README.md", String(take!(out)))
        @test read(note, String) == "# The package's own note on its regressions\n"      # kept
        @test isfile(joinpath(dir, ".gbg", "policy", "glossary.md"))                     # the rest was written
        @test [l.file for l in RN.wiring(cfg, dir)] == ["test/regressions/README.md"]    # and it stays reported
        # a switched-off instrument's skill of the package's own is not deleted either
        off = G.Model.Config(package = cfg.package, tool = cfg.tool, filesets = cfg.filesets,
                             switches = [G.Model.Switch(target = :bug_hunt, reason = "the package has its own")])
        write(joinpath(dir, RN.skill_path(:bug_hunt)), "# /bug-hunt, the package's\n")
        RN.write_all(off, dir)
        @test read(joinpath(dir, RN.skill_path(:bug_hunt)), String) == "# /bug-hunt, the package's\n"
        @test !any(l -> l.file == RN.skill_path(:bug_hunt), RN.wiring(off, dir))
    end

    # Every consumer's `docs/` holds a `Project.toml`, so `gbg init` run there wired `docs/` as a package
    # called `docs`; a package is a `Project.toml` that names one.
    @testset "the package root is the Project.toml that names a package" begin
        dir = mktempdir(; cleanup = true)
        write(joinpath(dir, "Project.toml"), "name = \"Sample\"\n")
        mkpath(joinpath(dir, "docs", "src")); write(joinpath(dir, "docs", "Project.toml"), "[deps]\n")
        @test G.Wire.package_root(joinpath(dir, "docs", "src")) == dir
        @test G.Wire.package_root(joinpath(dir, "docs")) == dir
        @test G.Wire.package_root(dir) == dir
        @test G.Wire.package_root(mktempdir(; cleanup = true)) === nothing
    end

    # The pin writer re-serialised the whole file by hand and handled a string and a table of strings:
    # a `[targets]` list or a top-level `description` was a crash, and `gbg sync` exit 3 with it.
    @testset "the pin is written into whatever else the environment holds" begin
        dir, cfg = wired_package()
        pj = joinpath(dir, "test", "Project.toml")
        write(pj, "description = \"the tests\"\n\n[deps]\nTest = \"8dfed614-e22c-5e08-85e1-65c5234f0b40\"\n\n[compat]\njulia = \"1.12\"\n\n[targets]\ntest = [\"Test\"]\n")
        @test RN.write_pin(cfg, dir, "test")
        back = TOML.parsefile(pj)
        @test back["description"] == "the tests" && back["targets"]["test"] == ["Test"] && back["compat"]["julia"] == "1.12"
        @test haskey(back["sources"], RN.PKG) && haskey(back["deps"], RN.PKG)
        @test RN.pin_drift(cfg, dir, "test") === nothing
        @test !RN.write_pin(cfg, dir, "test")                       # and it is stable
        @test !occursin("[sources.", read(pj, String))              # inline, as Pkg writes it
    end

    # The block was found by substring, with a trailing newline the file did not have, so a block that
    # ended its file could not be repaired; a marker mentioned in the package's own prose above the
    # block began the block there, and the prose was eaten; and a block written twice stayed twice.
    @testset "a managed block is found by its marker lines, once, and repaired wherever it ends" begin
        dir, cfg = wired_package()
        ignore = joinpath(dir, ".gitignore")
        stale = replace(RN.gitignore(cfg), "*.cov" => "*.old")
        write(ignore, "mine/\n" * chomp(stale))                     # the block ends the file, no newline
        @test length(RN.wiring(cfg, dir)) == 1
        @test RN.write_all(cfg, dir).changed == [".gitignore"]
        @test isempty(RN.wiring(cfg, dir))
        @test startswith(read(ignore, String), "mine/\n")

        claude = joinpath(dir, "CLAUDE.md")
        prose = "The `gbg:managed begin` marker below is the tool's; this paragraph is ours.\n\n"
        write(claude, prose * read(claude, String))
        @test isempty(RN.wiring(cfg, dir))                          # a mention is not a marker
        @test isempty(RN.write_all(cfg, dir).changed)
        @test startswith(read(claude, String), prose)               # and the paragraph survives a sync

        write(ignore, read(ignore, String) * "\n" * stale)          # the block twice
        drift = RN.wiring(cfg, dir)
        @test length(drift) == 1 && occursin("appears 2 times", first(drift).text)
        RN.write_all(cfg, dir)
        @test count(RN.BEGIN_MARK, read(ignore, String)) == 1
        @test isempty(RN.wiring(cfg, dir))
    end

    # The settings merge matched one literal spelling of the hook's command: an entry in any other
    # spelling was kept and a second one added, and the hook ran twice per stop. A file that does not
    # parse was a crash, exit 3, where the consumer's bad file is 2.
    @testset "one Stop entry runs the hook, whatever spelling it was in" begin
        dir, cfg = wired_package()
        path = joinpath(dir, ".claude", "settings.json")
        other = "\$CLAUDE_PROJECT_DIR/.claude/hooks/queue-guard.sh"
        write(path, JSON3.write(Dict("permissions" => Dict("allow" => ["Bash(ls)"]),
                                     "hooks" => Dict("Stop" => [Dict("hooks" => [Dict("type" => "command", "command" => other)]),
                                                                Dict("hooks" => [Dict("type" => "command", "command" => "echo mine")])]))))
        @test RN.settings_drift(dir) !== nothing
        @test RN.write_settings(dir)
        doc = JSON3.read(read(path, String), Dict{String,Any})
        cmds = [h["command"] for e in doc["hooks"]["Stop"] for h in e["hooks"]]
        @test count(c -> endswith(c, "queue-guard.sh"), cmds) == 1
        @test RN.HOOK_COMMAND in cmds && "echo mine" in cmds        # the package's own hook stays
        @test doc["permissions"]["allow"] == ["Bash(ls)"]           # and so does the rest of the file
        @test RN.settings_drift(dir) === nothing
        write(path, "{ not json")
        @test_throws G.ConfigIO.ConfigError RN.write_settings(dir)
    end

    # Every push does the docs build (the owner, 2026-09-29): the push hook is installed once beside the
    # package's own hooks, lets a command that does not push through, and stops a push whose build fails.
    @testset "the push hook runs the docs build before a push, and a failing build stops it" begin
        dir, cfg = wired_package()
        path = joinpath(dir, ".claude", "settings.json")
        @test RN.settings_drift(dir) === nothing
        doc = JSON3.read(read(path, String), Dict{String,Any})
        pre = only(doc["hooks"]["PreToolUse"])
        @test pre["matcher"] == "Bash" && only(pre["hooks"])["command"] == RN.PUSH_COMMAND
        @test only(pre["hooks"])["timeout"] == RN.PUSH_TIMEOUT
        # the package's own PreToolUse hook stays, and a missing push hook is drift that sync restores
        doc["hooks"]["PreToolUse"] = [Dict("matcher" => "Edit", "hooks" => [Dict("type" => "command", "command" => "echo mine")])]
        write(path, JSON3.write(doc))
        @test occursin("push-gate.sh", RN.settings_drift(dir))
        @test RN.write_settings(dir) && RN.settings_drift(dir) === nothing
        cmds = [h["command"] for e in JSON3.read(read(path, String), Dict{String,Any})["hooks"]["PreToolUse"] for h in e["hooks"]]
        @test "echo mine" in cmds && count(==(RN.PUSH_COMMAND), cmds) == 1
        # the script itself, over a build that passes and one that fails
        julia = joinpath(Sys.BINDIR, "julia")
        quick = G.Model.Config(package = cfg.package, tool = :dev, docs_build = [julia, "--startup-file=no", "docs/make.jl"])
        script = joinpath(dir, ".claude", "hooks", "push-gate.sh")
        write(script, RN.push_gate(quick)); chmod(script, 0o755)
        mkpath(joinpath(dir, "docs"))
        gate(command) = begin
            payload = JSON3.write(Dict("tool_name" => "Bash", "tool_input" => Dict("command" => command)))
            err = IOBuffer()
            p = run(pipeline(setenv(`$script`, "CLAUDE_PROJECT_DIR" => dir, "PATH" => ENV["PATH"]);
                             stdin = IOBuffer(payload), stdout = devnull, stderr = err); wait = false)
            wait(p)
            (p.exitcode, String(take!(err)))
        end
        write(joinpath(dir, "docs", "make.jl"), "error(\"the build failed\")\n")
        @test gate("git status --short")[1] == 0                          # not a push: no build at all
        code, msg = gate("git push -q origin master")
        @test code == 2 && occursin("PUSH STOPPED", msg) && occursin("the build failed", msg)
        @test gate("git -C \"$dir\" push")[1] == 2
        write(joinpath(dir, "docs", "make.jl"), "println(\"built\")\n")
        @test gate("git push origin master")[1] == 0
    end

    # A hook at mode 644 with the right content was neither restored nor reported, and Claude Code
    # cannot exec it.
    @testset "a hook that lost its execute bit is reported and restored" begin
        dir, cfg = wired_package()
        p = joinpath(dir, ".claude", "hooks", "queue-guard.sh")
        chmod(p, 0o644)
        drift = RN.wiring(cfg, dir)
        @test length(drift) == 1 && occursin("not executable", first(drift).text)
        @test RN.write_all(cfg, dir).changed == [".claude/hooks/queue-guard.sh"]
        @test Sys.isexecutable(p)
        @test isempty(RN.wiring(cfg, dir))
    end

    # The seed named `docs/make.jl` unconditionally, so `init` on a package with no docs build wrote a
    # config its own sync then refused.
    @testset "init on a package with no docs build writes a config its sync accepts" begin
        dir = mktempdir(; cleanup = true)
        write(joinpath(dir, "Project.toml"), "name = \"Bare\"\n")
        mkpath(joinpath(dir, "test")); write(joinpath(dir, "test", "runtests.jl"), RN.runtests_call() * "\n")
        @test G.Wire.init(dir; io = devnull) == 0
        text = read(joinpath(dir, ".gbg", "config.jl"), String)
        @test !occursin("docs_build", text) && occursin("Pkg.test()", text)
        @test G.Wire.sync(dir; check = true, io = devnull) == 0
    end

    # A suite that brings `Harness` in with `using` calls it as `Harness.test`: the check knew the full
    # spelling alone. A spelling that names no binding is not a call, however close it looks.
    @testset "the harness is recognised in every spelling a suite may call it by" begin
        @test RN.harness_called("using GBGCodingTools.Engine\nHarness.test(dirname(@__DIR__))")
        @test RN.harness_called("using GBGCodingTools.Engine: Harness, Checks\nHarness.test(dirname(@__DIR__))")
        @test RN.harness_called("import GBGCodingTools.Engine.Harness\nHarness.test(dirname(@__DIR__))")
        # neither names a binding that exists: `Harness` lives in `Engine`, not at the top level
        @test !RN.harness_called("using GBGCodingTools: Harness\nHarness.test(dirname(@__DIR__))")
        @test !RN.harness_called("GBGCodingTools.Harness.test(dirname(@__DIR__))")
        @test RN.harness_called(RN.runtests_call())
        @test !RN.harness_called("using GBGCodingTools\nHarness.test(dirname(@__DIR__))")   # nothing brought it in
        @test !RN.harness_called("using GBGCodingTools.Engine\n@test true")
    end
end

# Found wiring GBGHomogeneousTurbulence (2026-09-28): every wiring finding said "run `gbg sync`", which
# writes none of a package's build script, test entry point or workflows; and the tooling page a build
# writes was not in the ignore block, so a package committed it or listed it by hand.
@testset "a wiring finding names what fixes it, and the tooling page is ignored" begin
    @test RN.remedy(G.Model.Location(; file = ".gitignore")) == "run `gbg sync`"
    @test RN.remedy(G.Model.Location(; file = ".claude/settings.json")) == "run `gbg sync`"
    for f in ("docs/make.jl", "test/runtests.jl", ".github/workflows/CI.yml")
        @test occursin("edit this file", RN.remedy(G.Model.Location(; file = f)))
    end
    @test occursin("\ndocs/src/gbg.md\n", RN.gitignore(G.Model.Config(package = "P", tool = :dev)))
end

# Found wiring GBGHomogeneousTurbulence (2026-09-28): `gbg check`'s summary counted a build script that
# does not call in as a "generated path adrift", which it is not and which `gbg sync` does not repair.
@testset "gbg check's summary does not call the package's own files generated" begin
    dir, cfg = wired_package()
    mkpath(joinpath(dir, "docs"))
    write(joinpath(dir, "docs", "make.jl"), "using Documenter\nmakedocs()\n")
    out = sprint(io -> G.Check.run(dir; intention = MW.Intention.CODE, io))
    @test !occursin("generated path(s) adrift", out)
    @test occursin("1 wiring finding(s) (0 for `gbg sync`, 1 in the package's own files)", out)
end

# The `gbg` command, run as a shell script with a stand-in `julia` so no Julia starts: a first wiring is
# told the exact command, and a copy that has fallen behind the dev checkout says so (2026-09-29).
@testset "the gbg command: the first-wiring hint and a stale copy" begin
    shim = joinpath(pkgdir(GBGCodingTools), "bin", "gbg")
    home = mktempdir(; cleanup = true); fakebin = mktempdir(; cleanup = true)
    write(joinpath(fakebin, "julia"), "#!/bin/sh\nexit 0\n"); chmod(joinpath(fakebin, "julia"), 0o755)
    env = ["HOME" => home, "PATH" => fakebin * ":" * ENV["PATH"]]
    runshim(script, args, dir) = begin
        err = IOBuffer()
        p = run(pipeline(setenv(`sh $script $args`, env...; dir); stdout = devnull, stderr = err); wait = false)
        wait(p); (p.exitcode, String(take!(err)))
    end
    bare = mktempdir(; cleanup = true)
    code, msg = runshim(shim, ["init"], bare)
    @test code == 2 && occursin("gbg --dev init", msg)
    @test !occursin("gbg --dev init", runshim(shim, ["check"], bare)[2])
    # a dev checkout whose bin/gbg is this script: no warning; a different one: the warning
    dev = mktempdir(; cleanup = true)
    mkpath(joinpath(dev, "bin")); cp(shim, joinpath(dev, "bin", "gbg")); write(joinpath(dev, "Manifest.toml"), "")
    mkpath(joinpath(home, ".gbg")); write(joinpath(home, ".gbg", "dev"), dev * "\n")
    installed = joinpath(mktempdir(; cleanup = true), "gbg"); cp(shim, installed)
    @test !occursin("differs", runshim(installed, ["--dev", "check"], bare)[2])
    write(installed, read(shim, String) * "\n# an older copy\n")
    @test occursin("run: gbg --dev install", runshim(installed, ["--dev", "check"], bare)[2])
end
