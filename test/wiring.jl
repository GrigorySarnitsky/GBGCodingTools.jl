# test/wiring.jl — the wiring check, shown to catch what it exists for (docs/ARCHITECTURE.md §6).
#
# Every file that connects a package to this one is the return value of a Julia function. The check runs
# those functions again and compares. So the test flips one byte in each generated path in turn and
# requires the check to report that path — a check that cannot fail is worse than none, and this one is
# what stands between a hand-edited generated file and a package that believes it is wired.
using Test, GBGCodingTools
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
                b = findfirst(l -> startswith(l, "# gbg:managed begin"), lines)
                e = findfirst(l -> startswith(l, "# gbg:managed end"), lines)
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
