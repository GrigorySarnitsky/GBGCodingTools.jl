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
    settings = [Setting(rule = Symbol("RULE.DOC.TABLE_TOP_LEVEL"), name = :leading, value = "what the operation does")],
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
