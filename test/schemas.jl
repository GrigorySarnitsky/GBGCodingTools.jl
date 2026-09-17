using Test, GBGCodingTools, JSON3, TOML
include("helpers.jl")

@testset "schemas" begin
    names = [replace(f, ".schema.json" => "") for f in readdir(joinpath(TOOL, "schema")) if endswith(f, ".schema.json")]
    @test length(names) >= 4 && length(names) == length(unique(names))   # derived, never a cited count
    for n in names
        s = G.load_schema(n)
        @test s["type"] == "object"
    end
    @testset "validator keywords" begin
        s = Dict("type" => "object", "additionalProperties" => false, "required" => ["a"],
                 "properties" => Dict("a" => Dict("type" => "integer", "minimum" => 1), "b" => Dict("type" => ["string", "null"]),
                                      "c" => Dict("allOf" => [Dict("required" => ["a"])])))
        @test isempty(G.validate(s, Dict("a" => 2, "b" => nothing)))
        @test !isempty(G.validate(s, Dict("a" => 0)))                      # minimum
        @test !isempty(G.validate(s, Dict("a" => 1, "z" => 1)))            # closed keys
        @test !isempty(G.validate(s, Dict("b" => "x")))                    # required
        @test !isempty(G.validate(Dict("type" => "string", "pattern" => "^v"), "1.0"))
    end
    @testset "every hat validates" begin
        hat = G.load_schema("hat")
        # substrate holds the two views the panel actually delivers. It named four more — rawhtml,
        # docstrings, rulebook, none — that narrowed nothing and no hat ever took; what ELSE a hat is
        # handed is `needs`. Both directions, so the set cannot quietly grow back.
        @test Set(hat["properties"]["substrate"]["enum"]) == Set(["full", "siteonly"])
        base = Dict("key" => "k", "role" => "a role long enough", "persona" => "p"^100, "substrate" => "full")
        @test isempty(G.validate(hat, base))
        @test any(e -> occursin("substrate", e), G.validate(hat, merge(base, Dict("substrate" => "rawhtml"))))
        # The 22 shipped hat files moved to docs/design-record/roles-v1/ on 2026-09-17 and are validated
        # nowhere now; the schema itself, and the closed `substrate` set above, are still held.
    end
    # The instrument scripts' schema testset stood here until 2026-09-17: the eleven Workflow scripts
    # and the four instrument schemas are filed under docs/design-record/, and one fixed driver
    # replaces them (docs/ARCHITECTURE.md §6).
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
    @testset "every shipped schema is read by something" begin
        # five schemas were shipped and loaded by no code path; two were superseded by the instrument
        # schemas and deleted, three are wired. An unread schema drifts from the artefact it names.
        src = join([read(f, String) for f in vcat([joinpath(r, x) for (r, _, fs) in walkdir(joinpath(TOOL, "src")) for x in fs if endswith(x, ".jl")],
                                                  [joinpath(TOOL, "ext", x) for x in readdir(joinpath(TOOL, "ext"))])], "\n")
        for f in readdir(joinpath(TOOL, "schema"))
            endswith(f, ".schema.json") || continue
            name = replace(f, ".schema.json" => "")
            # the name must appear QUOTED on a line that is about schemas, never merely somewhere in
            # the source: `finding` matched a coincidental substring and the schema was validated
            # against nothing. Naming the two loaders instead would make this test the author of the
            # code — a third loader would be reported as no loader at all.
            @test any(l -> occursin("\"" * name * "\"", l) && (occursin("schema", lowercase(l)) || occursin("read_verdicts", l)),
                      split(src, "\n"))
        end
    end
    # The three round-artefact testsets stood here until 2026-09-17: a banked bug-hunt finding, the
    # reproduction record, and a disposition's frozen sha. All three drove the round machinery, which
    # is gone; the schemas they validated against went with it.
    @testset "the home page's counts are the real ones" begin
        # every number the home page cites is re-measured here; a cited count nothing asserts drifts
        page = read(joinpath(TOOL, "docs", "src", "index.md"), String)
        n(re) = (m = match(re, page); m === nothing ? -1 : parse(Int, m.captures[1]))
        @test n(r"There are (\d+)\s*\n?\s*verbs") == length(G.VERBS)
        @test n(r"(\d+) scans? over docstrings") == length(G.scan_catalog())
        @test n(r"(\d+) checks that a package is wired correctly") == length(G.Doctor.CHECKS)
        @test n(r"The policy is (\d+) rules") == length(TOML.parsefile(joinpath(TOOL, "policy", "RULES.toml"))["rule"])
    end
    @testset "the transitional Python is gone (1.6)" begin
        @test !isfile(joinpath(TOOL, "src", "CLI", "consolidate.py"))
        @test isempty(filter(f -> endswith(f, ".py"), [joinpath(d, f) for (d, _, fs) in walkdir(joinpath(TOOL, "src")) for f in fs]))
    end
    @testset "RULES.toml matches the policy files" begin
        rules = TOML.parsefile(joinpath(TOOL, "policy", "RULES.toml"))["rule"]
        # the two sets, each derived — a hard-coded count drifts silently (RULE.TEST.COUNTS_REMEASURED),
        # which it did: two rules were added and this test still asserted the old number
        headings = Set{String}()
        for f in readdir(joinpath(TOOL, "policy"); join = true)
            endswith(f, ".md") || continue
            for m in eachmatch(r"^### (RULE\.[A-Z]+\.[A-Z_]+)\s*$"m, read(f, String)); push!(headings, m.captures[1]); end
        end
        @test Set(r["id"] for r in rules) == headings
        for r in rules
            text = replace(read(joinpath(TOOL, "policy", r["file"]), String), r"\s+" => " ")
            @test occursin(r["sentinel"], text)
            @test occursin("### " * r["id"], read(joinpath(TOOL, "policy", r["file"]), String))
        end
    end
    @testset "every rule declares what catches its next violation (RULE.TEST.RULE_WITH_CHECK)" begin
        rules = TOML.parsefile(joinpath(TOOL, "policy", "RULES.toml"))["rule"]
        scans = Set(s["id"] for s in TOML.parsefile(joinpath(TOOL, "catalog", "scans.toml"))["scan"])
        checks = Set(first.(G.Doctor.CHECKS))
        srctext = join(read(joinpath(d, f), String) for (d, _, fs) in walkdir(joinpath(TOOL, "src")) for f in fs if endswith(f, ".jl"))
        for r in rules
            cs = get(r, "check", String[])
            @test !isempty(cs)                                  # a rule with no class is the silence the rule forbids
            for c in cs
                if startswith(c, "scan:")
                    @test c[6:end] in scans
                elseif startswith(c, "doctor:")
                    @test c[8:end] in checks
                elseif startswith(c, "test:")
                    @test isfile(joinpath(TOOL, c[6:end]))
                elseif startswith(c, "harness:")
                    # the binding must be DEFINED in the source, not merely mentioned: `report(` occurs
                    # in a comment as readily as in the function this rule rests on
                    @test occursin(Regex("function\\s+" * last(split(c[9:end], '.')) * "\\b"), srctext)
                elseif startswith(c, "rule:")
                    # converted: the rule is a value now, and test/rules.jl shows its check matches it
                    @test Symbol(c[6:end]) in Set(r.id for r in G.Catalogue.RULES)
                else
                    @test c in ("panel", "weakness")             # judged by a running panel, or owed
                end
            end
        end
    end
end
