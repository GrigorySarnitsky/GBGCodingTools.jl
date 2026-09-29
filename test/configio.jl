# test/configio.jl — a package's settings are DATA (docs/ARCHITECTURE.md §5.2).
#
# Both directions. Every field type a config can carry round-trips through the reader, and every way of
# smuggling a program into it is refused with the line and the reason: a function call, an interpolated
# string, an unknown constructor, an unknown keyword, a second statement. The reason this is a test
# rather than a convention is that a config is read by every build and every test of the package that
# owns it — evaluating one makes each of those a place to run code.
using Test, GBGCodingTools
include("helpers.jl")

const CIO = G.ConfigIO
const MM = G.Model

function in_config(body, settled = nothing)
    dir = mktempdir(; cleanup = true)
    mkpath(joinpath(dir, ".gbg"))
    write(joinpath(dir, ".gbg", "config.jl"), body)
    settled === nothing || write(joinpath(dir, ".gbg", "settled.jl"), settled)
    return dir
end

const FULL = """
Config(
    package = "GBGFixture",
    tool = :dev,
    docs_build = ["julia", "--project=docs", "docs/make.jl"],
    test = ["julia", "--project", "-e", "using Pkg; Pkg.test()"],
    normative = ["docs/ARCHITECTURE.md"],
    filesets = Dict(FileSet.PAGES => ["docs/src/**/*.md"], FileSet.CODE => ["src/**/*.jl"]),
    copies = ["docs/src/architecture.md" => "docs/ARCHITECTURE.md"],
    switches = [Switch(target = Symbol("RULE.TEX.CODE_IN_MATH"), reason = "no mathematics in this package's prose")],
    settings = [Setting(rule = Symbol("RULE.DOC.COORD_FREE"), name = :formalization, value = "what the operation does")],
    rules = [PatternRule(id = :NO_TODO, statement = "No TODO is left in shipped prose.",
                         fileset = FileSet.PAGES, pattern = r"TODO", forbidden = true)],
    code_areas = [:engine => ["src/Engine/*.jl"]],
)
"""

@testset "the config is data" begin
    @testset "every field type round-trips" begin
        cfg = CIO.read_config(in_config(FULL))
        @test cfg isa MM.Config
        @test cfg.package == "GBGFixture"
        @test cfg.tool === :dev
        @test cfg.docs_build == ["julia", "--project=docs", "docs/make.jl"]
        @test cfg.normative == ["docs/ARCHITECTURE.md"]
        @test cfg.filesets[MM.FileSet.PAGES] == ["docs/src/**/*.md"]
        @test first(cfg.copies) == ("docs/src/architecture.md" => "docs/ARCHITECTURE.md")
        @test cfg.switches[1].target === Symbol("RULE.TEX.CODE_IN_MATH")
        @test cfg.settings[1].value == "what the operation does"
        @test cfg.rules[1].pattern == r"TODO" && cfg.rules[1].forbidden
        @test first(cfg.code_areas) == (:engine => ["src/Engine/*.jl"])
    end

    @testset "a released pin is a version, not a string" begin
        cfg = CIO.read_config(in_config("""Config(package = "P", tool = v"2.0.0")"""))
        @test cfg.tool == v"2.0.0"
    end

    @testset "an empty typed array is none of those" begin
        cfg = CIO.read_config(in_config("""Config(package = "P", tool = :dev, switches = Switch[], normative = String[])"""))
        @test isempty(cfg.switches) && isempty(cfg.normative)
    end

    @testset "nothing that is a program is accepted" begin
        for (label, body) in (
            "a function call"        => """Config(package = "P", tool = getpid())""",
            "a call that reads"      => """Config(package = "P", tool = read("/etc/passwd", String))""",
            "an interpolated string" => """Config(package = "\$(ENV["HOME"])", tool = :dev)""",
            "an unknown constructor" => """Config(package = "P", tool = :dev, switches = [Whatever(x = 1)])""",
            "an unknown keyword"     => """Config(package = "P", tool = :dev, nonsense = 1)""",
            "a second statement"     => """Config(package = "P", tool = :dev)\nrm("/tmp/x"; force = true)""",
            "an unknown enum"        => """Config(package = "P", tool = :dev, filesets = Dict(FileSet.NOWHERE => ["x"]))""",
            "a bare identifier"      => """Config(package = P, tool = :dev)""",
        )
            dir = in_config(body)
            @test_throws CIO.ConfigError CIO.read_config(dir)
            err = try; CIO.read_config(dir); nothing; catch e; e; end
            @test !isempty(err.problems)                       # and it says what was wrong, not just that
            @test occursin("line", first(err.problems)) || occursin("does not accept", first(err.problems))
        end
    end

    @testset "a missing or unparsable file is a refusal, not a crash" begin
        @test_throws CIO.ConfigError CIO.read_config(mktempdir(; cleanup = true))
        @test_throws CIO.ConfigError CIO.read_config(in_config("Config(package = \"P\", tool = :dev"))
    end

    @testset "the settled rulings are data too" begin
        dir = in_config(FULL, """
        [
            Settled(question = "q-2026-09-17-1", text = "Not a defect: the notation is the book's.",
                    date = "2026-09-17",
                    locations = [Location(file = "docs/src/index.md", node = "Guide / Notation", text = "we write u for velocity")]),
        ]
        """)
        rulings = CIO.read_settled(dir)
        @test length(rulings) == 1
        @test rulings[1].date == "2026-09-17"
        @test rulings[1].locations[1].node == "Guide / Notation"
        @test isempty(CIO.read_settled(mktempdir(; cleanup = true)))      # no file is no rulings
    end

    @testset "validate says what the config claims that the package does not have" begin
        dir = in_config(FULL)
        problems = CIO.validate(CIO.read_config(dir), dir)
        @test any(p -> occursin("docs/make.jl", p), problems)             # the command names no file here
        @test any(p -> occursin("docs/ARCHITECTURE.md", p), problems)     # nor does the normative document
        @test any(p -> occursin("matches nothing", p), problems)          # nor do its file sets match a file
        # and with the files in place it says nothing
        mkpath(joinpath(dir, "docs", "src")); mkpath(joinpath(dir, "src"))
        touch(joinpath(dir, "docs", "make.jl")); touch(joinpath(dir, "docs", "ARCHITECTURE.md"))
        touch(joinpath(dir, "docs", "src", "index.md")); touch(joinpath(dir, "src", "GBGFixture.jl"))
        @test isempty(CIO.validate(CIO.read_config(dir), dir))
    end

    @testset "a switch with no reason is refused by validate, not by the reader" begin
        dir = in_config("""Config(package = "P", tool = :dev, switches = [Switch(target = :R, reason = "   ")])""")
        @test any(p -> occursin("gives no reason", p), CIO.validate(CIO.read_config(dir), dir))
    end
end

# The three refusals of §9, and the fourth for a setting. They are in `validate` rather than in the
# reader because they are about what the config CLAIMS, not about whether it is data: a switch naming
# nothing is well-formed and still meaningless.
@testset "what a config may not switch off" begin
    dir = in_config("""Config(package = "P", tool = :dev,
        switches = [Switch(target = :NO_SUCH_RULE, reason = "a reason long enough to count as one")])""")
    problems = CIO.validate(CIO.read_config(dir), dir)
    # the arm turns itself on once a rule has been converted: before that, a name cannot be judged
    @test isempty(G.Catalogue.RULES) ? isempty(problems) : any(p -> occursin("not a rule", p), problems)

    # A deferral is a question with a condition on it (Phase 5): it names a rule, says what would close
    # it, and is not also a switch on the same rule.
    let id = String(first(G.Catalogue.RULES).id)
        ok = in_config("""Config(package = "P", tool = :dev,
            deferrals = [Deferral(rule = Symbol("$id"), until = "the next release")])""")
        cfg = CIO.read_config(ok)
        @test length(cfg.deferrals) == 1 && cfg.deferrals[1].rule === Symbol(id)
        @test isempty(CIO.validate(cfg, ok))
        blank = in_config("""Config(package = "P", tool = :dev, deferrals = [Deferral(rule = Symbol("$id"), until = " ")])""")
        @test any(p -> occursin("what would close it", p), CIO.validate(CIO.read_config(blank), blank))
        unknown = in_config("""Config(package = "P", tool = :dev, deferrals = [Deferral(rule = :NO_SUCH_RULE, until = "soon")])""")
        @test any(p -> occursin("not a rule", p), CIO.validate(CIO.read_config(unknown), unknown))
        both = in_config("""Config(package = "P", tool = :dev,
            switches = [Switch(target = Symbol("$id"), reason = "a reason a reader can weigh")],
            deferrals = [Deferral(rule = Symbol("$id"), until = "soon")])""")
        @test any(p -> occursin("one or the other", p), CIO.validate(CIO.read_config(both), both))
    end

    # and a switch naming a rule that EXISTS is accepted, dots and all
    ok = in_config("""Config(package = "P", tool = :dev,
        switches = [Switch(target = Symbol("RULE.DOC.TABLE_TOP_LEVEL"), reason = "this package ships no tables at all")])""")
    @test isempty(CIO.validate(CIO.read_config(ok), ok))

    # Every rule is switchable (§9, ruled 2026-09-17): a switch against ANY rule of the rulebook is
    # accepted, and what makes it answerable is the reason, which is rendered onto the package's site.
    let dir = mktempdir(; cleanup = true)
        mkpath(joinpath(dir, ".gbg"))
        id = String(first(G.Catalogue.RULES).id)
        write(joinpath(dir, ".gbg", "config.jl"), """
        Config(package = "P", tool = :dev,
               switches = [Switch(target = Symbol("$id"), reason = "a reason a reader can weigh")])
        """)
        @test isempty(G.ConfigIO.validate(G.ConfigIO.read_config(dir), dir))
    end
    @test G.Catalogue.doc(G.Catalogue.INSTRUMENTS[1]) isa String
    @test occursin("Owner's request", G.Catalogue.doc(G.Catalogue.INSTRUMENTS[1]))
    @test occursin("nobody starts it", G.Catalogue.doc(G.Catalogue.ALWAYS_ON[1]))
end

# Every verb of the new tree finds its package with this. It looked for `.gbg/config.toml` — the OLD
# config — until 2026-09-18, so `gbg check`, `sync`, `bump` and `docfix` all died with a MethodError on
# `nothing` the first time one was run from a package `gbg init` had wired. Each worked when handed a
# root, which is how a rehearsal that called the library missed it and running the command line found it.
@testset "a verb finds its package, and says so when there is none" begin
    dir = mktempdir(; cleanup = true)
    deep = joinpath(dir, "src", "inner"); mkpath(deep)
    @test G.ConfigIO.find_root(deep) === nothing               # nothing above it
    mkpath(joinpath(dir, ".gbg"))
    write(joinpath(dir, ".gbg", "config.jl"), """Config(package = "P", tool = :dev)""")
    @test G.ConfigIO.find_root(deep) == abspath(dir)           # found from below
    # a package carrying only the OLD config is not a package to these verbs
    other = mktempdir(; cleanup = true); mkpath(joinpath(other, ".gbg"))
    write(joinpath(other, ".gbg", "config.toml"), "schema = 1\n")
    @test G.ConfigIO.find_root(other) === nothing
    @test cd(() -> G.Check.cmd_check(String[]), other) == 2    # a named refusal, not a crash
end

# A string's value is what Julia evaluates it to. The source text was unquoted before, so a reason
# written over several lines with `\`-newline continuations kept every `\` and the indent after it, and
# reached a consumer's public page that way (found upgrading GBGPeriodicFields, 2026-09-24).
@testset "a string in the config means what Julia makes of it" begin
    body = join([
        "Config(package = \"P\", tool = v\"2.0.0\",",
        "       switches = [Switch(target = Symbol(\"RULE.DOC.RETIRED_CLAIMS\"), files = [\"docs/DECISIONS.md\"],",
        "                          reason = \"A decision log QUOTES a retired claim \\",
        "                                    in order to record it; a \\\"quoted\\\" word\\nand a new line.\"),",
        "                   Switch(target = Symbol(\"RULE.DOC.GRAMMAR\"),",
        "                          reason = \"\"\"",
        "                              Indented, triple-quoted \\",
        "                              and continued.\"\"\")])"], "\n")
    cfg = CIO.read_config(in_config(body))
    @test cfg.switches[1].reason == "A decision log QUOTES a retired claim in order to record it; a \"quoted\" word\nand a new line."
    @test cfg.switches[2].reason == "Indented, triple-quoted and continued."
end

# The code review of 2026-09-26. Each of these was either a backtrace where exit 2 is promised, a value
# read as something it is not, or a claim the config makes that nothing checked.
@testset "the review of 2026-09-26" begin
    problems(body) = try CIO.read_config(in_config(body)); String[] catch e; e isa CIO.ConfigError ? e.problems : rethrow() end
    P = "Config(package = \"P\", tool = :dev, "
    # a dollar is a character: only the parser's children decide interpolation
    @test CIO.read_config(in_config("Config(package = \"a \\\$ b\", tool = :dev)")).package == "a \$ b"
    # a consumer's bad literal is one refusal naming the line, never an exception
    @test only(problems("Config(package = \"P\", tool = v\"not a version\")")) == "line 1: v\"not a version\" is not a version"
    @test occursin("is not a pattern", only(problems(P * "rules = [PatternRule(id = :x, statement = \"s\", fileset = FileSet.PAGES, pattern = r\"(\")])")))
    @test occursin("is not an integer", only(problems(P * "settings = [Setting(rule = :x, name = :y, value = 99999999999999999999999)])")))
    # a raw pattern takes no escapes, and keeps its flags
    let cfg = CIO.read_config(in_config(P * """rules = [PatternRule(id = :x, statement = "s", fileset = FileSet.PAGES, pattern = r"\\\\d"),
                                                     PatternRule(id = :y, statement = "s", fileset = FileSet.PAGES, pattern = r"x"i)])"""))
        @test cfg.rules[1].pattern == r"\\d" && !occursin(cfg.rules[1].pattern, "5")
        @test occursin(cfg.rules[2].pattern, "X")
    end
    # a quoted expression is a program; a repeated keyword and a positional beside keywords are refused
    @test occursin("quoted expression", only(problems("Config(package = \"P\", tool = :(getpid()))")))
    @test occursin("quoted expression", only(problems("Config(package = \"P\", tool = quote getpid() end)")))
    @test occursin("twice", only(problems(P * "switches = [Switch(target = :a, reason = \"x\", reason = \"y\")])")))
    @test occursin("positional", only(problems(P * "switches = [Switch(:dropped, target = :b, reason = \"r\")])")))
    # §5.2 admits keyword calls only: a call positional throughout is refused too, for every constructor
    @test occursin("positional", only(problems(P * "switches = [Switch(:b, \"r\", [\"f\"])])")))
    @test occursin("positional", only(problems("Config(\"P\", :dev)")))
    # a bare `[]` is one line naming the fix, not a MethodError's candidate list
    let p = only(problems(P * "settings = [Setting(rule = Symbol(\"RULE.TEX.MATHBF\"), name = :mathbf_allowed, value = [])])"))
        @test !occursin('\n', p) && occursin("String[]", p)
    end
    # a typed list is built as its type, so a list-valued setting can be written, empty or not
    let cfg = CIO.read_config(in_config(P * """settings = [Setting(rule = Symbol("RULE.TEX.MATHBF"), name = :mathbf_allowed, value = String["x"]),
                                                          Setting(rule = Symbol("RULE.TEX.MATHBF"), name = :mathbf_allowed, value = String[])])"""))
        @test cfg.settings[1].value == ["x"] && cfg.settings[2].value == String[]
    end
    # the settled list survives a dollar, a second ruling and the owner's trailing comment
    let dir = in_config(FULL)
        CIO.append_settled(dir, MM.Settled(question = "q1", text = "keep the \$x\$ form", date = "2026-09-26"))
        CIO.append_settled(dir, MM.Settled(question = "q2", text = "two", date = "2026-09-26"))
        f = joinpath(dir, ".gbg", "settled.jl"); write(f, read(f, String) * "# end of rulings\n")
        CIO.append_settled(dir, MM.Settled(question = "q3", text = "three", date = "2026-09-26"))
        @test [s.question for s in CIO.read_settled(dir)] == ["q1", "q2", "q3"]
        @test CIO.read_settled(dir)[1].text == "keep the \$x\$ form"
    end
    # the owner's comment block above the vector survives an appended ruling, byte for byte
    let dir = in_config(FULL), f = joinpath(dir, ".gbg", "settled.jl")
        head = "# My own notes on these rulings.\n#\n\n# second paragraph\n"
        write(f, head * "[\n]\n")
        CIO.append_settled(dir, MM.Settled(question = "q1", text = "one", date = "2026-09-27"))
        @test startswith(read(f, String), head * "[\n")
        @test [s.question for s in CIO.read_settled(dir)] == ["q1"]
    end
    # a package may switch off, or defer, a pattern rule of its own
    let own = [MM.PatternRule(id = :NO_TODO, statement = "s", fileset = MM.FileSet.PAGES, pattern = r"TODO", forbidden = true)]
        vv(cfg) = CIO.validate(cfg, mktempdir(; cleanup = true))
        @test !any(p -> occursin("NO_TODO", p), vv(MM.Config(package = "P", tool = :dev, rules = own,
                                                          switches = [MM.Switch(target = :NO_TODO, reason = "r")])))
        @test !any(p -> occursin("NO_TODO", p), vv(MM.Config(package = "P", tool = :dev, rules = own,
                                                          deferrals = [MM.Deferral(rule = :NO_TODO, until = "x")])))
        @test any(p -> occursin("NO_TODO", p), vv(MM.Config(package = "P", tool = :dev,
                                                         switches = [MM.Switch(target = :NO_TODO, reason = "r")])))
    end
    # a setting on a retired rule or naming no parameter, and a deferral beside a file switch, are refused
    v(cfg) = CIO.validate(cfg, mktempdir(; cleanup = true))
    @test any(p -> occursin("not a rule", p), v(MM.Config(package = "P", tool = :dev, settings = [MM.Setting(rule = Symbol("RULE.INST.SEEDS"), name = :x, value = 1)])))
    @test any(p -> occursin("no parameter `allowed`", p), v(MM.Config(package = "P", tool = :dev, settings = [MM.Setting(rule = Symbol("RULE.TEX.MATHBF"), name = :allowed, value = 1)])))
    @test any(p -> occursin("one or the other", p), v(MM.Config(package = "P", tool = :dev,
        deferrals = [MM.Deferral(rule = Symbol("RULE.DOC.GRAMMAR"), until = "x")],
        switches = [MM.Switch(target = Symbol("RULE.DOC.GRAMMAR"), reason = "r", files = ["docs/x.md"])])))
    # a per-file switch is the same glob as a file set
    on(pat, file) = G.Engine.Checks.applies(MM.Config(package = "P", tool = :dev, switches = [MM.Switch(target = :R, reason = "r", files = [pat])]), :R; file)
    @test !on("src/**/*.jl", "src/a.jl") && on("src/*.jl", "src/a/b.jl")
    @test on("docs/src/a+b.md", "docs/src/ab.md") && !on("docs/src/a+b.md", "docs/src/a+b.md")
    # An exclusion takes files out of every rule, a built page with its source; it must name files that
    # exist and say why (the owner, 2026-09-29: HT's Phenomenology waits to be extracted, unchecked).
    let ex = MM.Config(package = "P", tool = :dev,
                       exclusions = [MM.Exclusion(files = ["src/phen/**", "docs/src/phen.md"], reason = "waits to be extracted")])
        @test !G.Engine.Checks.applies(ex, Symbol("RULE.DOC.ARGCOV"); file = "src/phen/Spectra.jl")
        @test !G.Engine.Checks.applies(ex, Symbol("RULE.TEX.RENDERED_MARKUP"); file = "docs/build/phen/index.html")
        @test G.Engine.Checks.applies(ex, Symbol("RULE.DOC.ARGCOV"); file = "src/Other.jl")
        d = mktempdir(; cleanup = true)
        mkpath(joinpath(d, "src", "phen")); write(joinpath(d, "src", "phen", "S.jl"), "x = 1\n"); write(joinpath(d, "src", "O.jl"), "y = 2\n")
        mkpath(joinpath(d, "docs", "src")); write(joinpath(d, "docs", "src", "phen.md"), "# P\n")
        @test G.Texts.files(ex, d, MM.FileSet.CODE) == ["src/O.jl"]            # no reader is given them either
        @test !any(p -> occursin("exclusion", p), CIO.validate(ex, d))
        @test any(p -> occursin("matches nothing", p), v(ex))
        @test any(p -> occursin("gives no reason", p), CIO.validate(MM.Config(package = "P", tool = :dev,
                  exclusions = [MM.Exclusion(files = ["src/O.jl"], reason = " ")]), d))
        @test occursin("read by none", G.Render.switches(ex)) && occursin("waits to be extracted", G.Render.switches(ex))
    end
    # a root holding a non-ASCII character
    @test G.Catalogue.normal_path(MM.Config(package = "P", tool = :dev), "/tmp/Ünter/pkg", "/tmp/Ünter/pkg/docs/a.md") == "docs/a.md"
    # a reader switched off leaves its rules as gaps, one each, never silence
    let (_, gaps) = G.Catalogue.panel(:documentation_review, MM.Config(package = "P", tool = :dev, switches = [MM.Switch(target = :withheld, reason = "r")]))
        @test any(g -> occursin("withheld reader, which P has switched off", g), gaps)
    end
    # `gbg check` does not send a network rule to the build or the suite, which never allow the network
    let d = in_config("Config(package = \"P\", tool = :dev)")
        mkpath(joinpath(d, "docs", "src")); write(joinpath(d, "docs", "src", "a.md"), "# A\n\nText.\n")
        out = sprint(io -> G.Check.run(d; intention = MM.Intention.DOCUMENTATION, io))
        @test occursin(r"RULE\.CIT\.RESOLVES — only `gbg check --network`", out)
        @test !occursin(r"RESOLVES[^\n]*the docs build and the test suite", out)
    end
    # and so does a declared discipline switched off
    let (_, gaps) = G.Catalogue.panel(:documentation_review, MM.Config(package = "P", tool = :dev, disciplines = [:differential_geometry],
                                                                       switches = [MM.Switch(target = :differential_geometry, reason = "r")]))
        @test any(g -> occursin("RULE.DOC.COORD_FREE", g) && occursin("differential_geometry reader, which P has switched off", g), gaps)
    end
    # the banner names the version that ran, and the pin beside it where they differ
    @test occursin("the config pins v0.0.1", G.Engine.Harness.banner(MM.Config(package = "P", tool = v"0.0.1")))
    @test G.Engine.Harness.banner(MM.Config(package = "P", tool = :dev)) == "vdev checks"
end

# A package's own rules are run, and the harness runs the rulebook whatever it is handed.
@testset "a package's pattern rules run, and extra rules never replace the rulebook" begin
    dir = in_config("""Config(package = "P", tool = :dev,
        rules = [PatternRule(id = :no_todo, statement = "No TODO is left in shipped prose.", fileset = FileSet.PAGES, pattern = r"TODO"),
                 PatternRule(id = :no_fixme, statement = "No FIXME in the code.", fileset = FileSet.CODE, pattern = r"FIXME")])""")
    mkpath(joinpath(dir, "docs", "src")); mkpath(joinpath(dir, "src"))
    write(joinpath(dir, "docs", "src", "index.md"), "# Page\n\nTODO: write this.\n")
    write(joinpath(dir, "src", "P.jl"), "module P\n# FIXME\nend\n")
    cfg = CIO.read_config(dir)
    found = G.Engine.Checks.run_patterns(cfg, dir)
    @test [(id, l.file, l.line) for (id, l) in found] == [(:no_todo, "docs/src/index.md", 3), (:no_fixme, "src/P.jl", 2)]
    @test [id for (id, _) in G.Engine.Checks.run_patterns(cfg, dir; intention = MM.Intention.CODE)] == [:no_fixme]
    @test any(((id, _),) -> id === :no_todo, G.Engine.Checks.run_all(cfg, dir; intention = MM.Intention.DOCUMENTATION))
    # the harness throws on the package's code rule, and a rule passed to it runs BESIDE the rulebook
    @test_throws ErrorException redirect_stdout(devnull) do; G.Engine.Harness.test(dir); end
    # and names the package's rule on its line, like any other finding
    let msg = try redirect_stdout(devnull) do; G.Engine.Harness.test(dir); end; "" catch e; sprint(showerror, e) end
        @test occursin(r"no_fixme\s+src/P\.jl:2", msg)
    end
    ran = Symbol[]
    spy = MM.Rule(id = :spy, statement = "s", why = "w", intention = MM.Intention.CODE,
                  check = MM.ProgramCheck(MM.Input.FILE_TREE, (r, c) -> (push!(ran, :spy); MM.Location[]), false))
    write(joinpath(dir, "src", "P.jl"), "module P\nend\n")
    redirect_stdout(devnull) do; G.Engine.Harness.test(dir; rules = [spy]); end
    @test ran == [:spy]
    code_rules = count(r -> r.intention === MM.Intention.CODE && r.check isa MM.ProgramCheck, G.Catalogue.RULES)
    @test code_rules > 0                                       # there are rulebook rules the old call dropped
end
