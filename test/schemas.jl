using Test, GBGCodingTools, JSON3, TOML
include("helpers.jl")

@testset "schemas" begin
    # Three testsets stood here until 2026-09-17: the four shipped JSON schemas, the JSON-Schema-subset
    # validator that read them, and the hat schema's closed `substrate` set. `schema/` and `Schema.jl`
    # are deleted — a schema is a Julia type now, and `ConfigIO` refuses what the types do not admit,
    # which test/configio.jl holds. The file keeps its name because what is left of it still measures
    # prose against the program.
    @testset "no prose cites a count of scans, verbs or checks" begin
        # the config, Init's defaults and the plan all carried "the 39 scans" while the catalogue held 41,
        # and the plan documented `gbg seed` and `gbg recall`, which are not verbs (2026-09-09). A count in
        # prose that a program can measure belongs in the program, not the sentence.
        # IMPLEMENTATION.md left this check on 2026-09-17: the plan there is now the order of the rebuild, so
        # it counts what exists today in order to say what replaces it, and names the verbs of the design
        # being built rather than the verbs registered now. Both are its subject matter, not drift. The
        # config and the sources are still held to it.
        files = [joinpath(TOOL, ".gbg/config.toml")]
        append!(files, [joinpath(r, f) for (r, _, fs) in walkdir(joinpath(TOOL, "src")) for f in fs if endswith(f, ".jl")])
        for f in files
            text = read(f, String)
            @test !occursin(r"\b\d+ scans\b", text)
            @test !occursin(r"\b\d+ (verbs|read-only checks)\b", text)
        end
    end
    # "every shipped schema is read by something" stood here until 2026-09-17. An unread schema drifts
    # from the artefact it names, and the answer to that is now structural: a schema is a Julia type,
    # which nothing can ship without a reader.
    # The three round-artefact testsets stood here until 2026-09-17: a banked bug-hunt finding, the
    # reproduction record, and a disposition's frozen sha. All three drove the round machinery, which
    # is gone; the schemas they validated against went with it.
    @testset "the home page's counts are the real ones" begin
        # every number the home page cites is re-measured here; a cited count nothing asserts drifts
        page = read(joinpath(TOOL, "docs", "src", "index.md"), String)
        n(re) = (m = match(re, page); m === nothing ? -1 : parse(Int, m.captures[1]))
        @test n(r"There are (\d+)\s*\n?\s*verbs") == length(G.VERBS)
        # The scan count left this list on 2026-09-17: there are no scans, and the home page stopped
        # citing a number it would have to keep at zero.
        @test isempty(G.scan_catalog())
        @test n(r"The policy is (\d+) rules") == length(G.Catalogue.RULES)
    end
    @testset "the transitional Python is gone (1.6)" begin
        @test !isfile(joinpath(TOOL, "src", "CLI", "consolidate.py"))
        @test isempty(filter(f -> endswith(f, ".py"), [joinpath(d, f) for (d, _, fs) in walkdir(joinpath(TOOL, "src")) for f in fs]))
    end
    # `RULES.toml matches the policy files` and the `check`-column half of RULE.TEST.RULE_WITH_CHECK stood
    # here until 2026-09-17. Both compared two copies of the rulebook — a TOML register and a directory
    # of prose — and `policy/` is deleted: a rule is one value, and the rulebook is rendered from it.
    # What those testsets guaranteed is asserted below against the one home that is left.
    @testset "every rule declares what catches its next violation (RULE.TEST.RULE_WITH_CHECK)" begin
        for r in G.Catalogue.RULES
            @test r.check !== nothing || !isempty(r.unchecked_reason)   # a check, or why there is none
            @test !isempty(r.statement) && !isempty(r.why)
        end
        # and every one of them reaches the rendered rulebook a session loads: a rule in no file is a
        # rule nobody reads, which is the same silence the register's empty `check` column was
        rendered = join(G.Render.produce(e.generator, G.ConfigIO.read_config(TOOL)) for e in G.Render.POLICY_FILES)
        for r in G.Catalogue.RULES
            @test occursin("### " * String(r.id) * "\n", rendered)
        end
    end
end
