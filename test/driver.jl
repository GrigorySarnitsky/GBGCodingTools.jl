# test/driver.jl — the Julia side and the driver read the same arguments (docs/ARCHITECTURE.md §6).
#
# `Orchestration.Agents` writes `arguments.json`; `drivers/run.js` reads it and launches the readers.
# The two halves run in different programs, minutes apart, and nothing but this connects them: a key
# added in Julia and never read in the driver is silently ignored, and a key the driver reads that Julia
# stopped writing is `undefined` at the moment a reader is launched.
#
# Neither failure shows up in a Julia test of the Julia half, or in a review of either file alone. What
# is held here is the JOIN, which is the only place it can be held — `node` is not installed on every
# machine the suite runs on, so the driver is read as text rather than executed.
using Test, GBGCodingTools
include("helpers.jl")

const DRIVER = joinpath(TOOL, "drivers", "run.js")

"""Every key the Julia side writes into a stage's arguments, at the top level and inside a role."""
function written_keys()
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".gbg")); mkpath(joinpath(root, "docs", "src"))
    write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
    write(joinpath(root, "docs", "src", "guide.md"), "# Guide\n\nProse.\n")
    cfg = G.ConfigIO.read_config(root)
    run = G.Orchestration.Runs.start(:documentation_review, root; io = devnull)
    path = G.Orchestration.Agents.write_arguments(root, run, cfg;
                roles = G.Catalogue.roles_of(:documentation_review), io = devnull)
    args = G.JSON3.read(read(path, String), Dict{String,Any})
    role_keys = isempty(args["roles"]) ? String[] : sort(collect(keys(args["roles"][1])))
    return (sort(collect(keys(args))), role_keys)
end

@testset "the driver and the Julia side read one set of arguments" begin
    @test isfile(DRIVER)
    driver = read(DRIVER, String)
    top, role = written_keys()

    @testset "every top-level key Julia writes is read by the driver" begin
        for key in top
            # `root` and `package` are read through interpolation, the rest by name; both are a
            # mention of the key in the driver's text.
            @test occursin("args." * key, driver) || occursin("args[\"" * key * "\"]", driver)
        end
    end

    @testset "every key of a role is read by the driver" begin
        for key in role
            @test occursin("role." * key, driver) || occursin("role[\"" * key * "\"]", driver)
        end
    end

    # The other direction: the driver must not read a key nobody writes. `undefined` at the moment a
    # reader is launched is a prompt missing a paragraph, with nothing raised anywhere.
    @testset "the driver reads no key Julia has stopped writing" begin
        for m in eachmatch(r"\bargs\.([a-z_]+)", driver)
            @test String(m.captures[1]) in top
        end
        for m in eachmatch(r"\brole\.([a-z_]+)", driver)
            @test String(m.captures[1]) in role
        end
    end

    # The schema is the contract the collector reads back, and the LINE is deliberately not in it.
    @testset "the driver asks for what the collector reads, and not for a line" begin
        @test occursin("'file'", driver) && occursin("'text'", driver)
        @test occursin("required: ['file', 'text']", driver)
        @test !occursin("line:", driver)                     # a line an agent reported is not the file's
        for key in ("claim", "evidence", "fix", "rule", "maybe_code", "locations", "node")
            @test occursin(key, driver)
        end
    end

    @testset "it is one driver, not one per instrument" begin
        @test length(filter(f -> endswith(f, ".js"), readdir(joinpath(TOOL, "drivers")))) == 1
        # and it names no instrument, or it would be eleven scripts again wearing one name
        for instrument in ("documentation_review", "bug_hunt", "change_audit")
            @test !occursin(instrument, driver)
        end
    end
end
