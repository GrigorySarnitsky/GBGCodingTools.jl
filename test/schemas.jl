using Test, GBGCodingTools, JSON3, TOML
include("helpers.jl")

@testset "schemas" begin
    names = [replace(f, ".schema.json" => "") for f in readdir(joinpath(TOOL, "schema")) if endswith(f, ".schema.json")]
    @test length(names) >= 16 && length(names) == length(unique(names))   # derived, never a cited count
    for n in names
        s = G.load_schema(n)
        @test s["type"] == "object"
    end
    for inst in ("check-docs", "check-consistency", "bug-hunt", "audit-changes")
        s = G.instrument_schema(inst)
        @test haskey(s["properties"], "args") && haskey(s["properties"], "lane_file")
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
        for f in readdir(joinpath(TOOL, "catalog", "hats"); join = true)
            endswith(f, ".toml") && @test isempty(G.validate(hat, TOML.parsefile(f)))
        end
    end
    @testset "every instrument script writes what its schema requires" begin
        # the dismissal file's three shapes (the script, the schema and the close gate) disagreed for as
        # long as no round had an adjudication to close (2026-09-09). These bind the two artefacts that
        # nothing else compares: the object a script stringifies, and the schema the CLI validates it with.
        function written_keys(js, marker)          # the top-level keys of the object literal after `marker`
            i = findfirst(marker, js); i === nothing && return String[]
            s = js[last(i):end]; o = findfirst('{', s); depth = 0; keys_ = String[]; cur = IOBuffer(); at_key = true
            for c in s[o:end]
                if c == '{' || c == '[' || c == '('; depth += 1; depth > 1 && (at_key = false)
                elseif c == '}' || c == ']' || c == ')'
                    depth -= 1; depth == 1 && (at_key = true)
                    depth == 0 && (k = strip(String(take!(cur))); isempty(k) || push!(keys_, k); break)
                elseif depth == 1 && (c == ',' || c == ':')
                    k = strip(String(take!(cur))); isempty(k) || (at_key && push!(keys_, k)); at_key = (c == ',')
                elseif depth == 1 && at_key; write(cur, c)
                end
            end
            return [String(strip(k)) for k in keys_ if occursin(r"^[A-Za-z_][A-Za-z0-9_]*$", strip(k))]
        end
        for (inst, script, marker, schema) in (("bug-hunt", "dismissals.js", "JSON.stringify({", "dismissal"),
                                               ("bug-hunt", "verify-architecture.js", "const file = {", "architecture-fix"))
            js = read(joinpath(TOOL, "instruments", inst, "workflow", script), String)
            keys_ = written_keys(js, marker)
            @test !isempty(keys_)
            req = JSON3.read(read(joinpath(TOOL, "schema", schema * ".schema.json"), String), Dict{String,Any})["required"]
            for k in req; @test String(k) in keys_; end                       # the script writes every required key
            props = keys(JSON3.read(read(joinpath(TOOL, "schema", schema * ".schema.json"), String), Dict{String,Any})["properties"])
            for k in keys_; @test k in props; end                     # and writes nothing the schema forbids
        end
        # no instrument schema carries a cross-file reference, which the validator refuses by design
        for i in ("check-docs", "check-consistency", "bug-hunt", "audit-changes")
            s = read(joinpath(TOOL, "instruments", i, "schema.json"), String)
            for m in eachmatch(r"\"\$ref\"\s*:\s*\"([^\"]+)\"", s); @test startswith(m.captures[1], "#/"); end
        end
    end
    @testset "no prose cites a count of scans, verbs or checks" begin
        # the config, Init's defaults and the plan all carried "the 39 scans" while the catalogue held 41,
        # and the plan documented `gbg seed` and `gbg recall`, which are not verbs (2026-09-09). A count in
        # prose that a program can measure belongs in the program, not the sentence.
        files = [joinpath(TOOL, f) for f in ("IMPLEMENTATION.md", ".gbg/config.toml")]
        append!(files, [joinpath(r, f) for (r, _, fs) in walkdir(joinpath(TOOL, "src")) for f in fs if endswith(f, ".jl")])
        for f in files
            text = read(f, String)
            @test !occursin(r"\b\d+ scans\b", text)
            @test !occursin(r"\b\d+ (verbs|read-only checks)\b", text)
        end
        # the first word after `gbg` must open a registered verb (a flag or a sub-verb may follow): the plan
        # documented `gbg seed` and `gbg recall`, which are functions called inside prepare and bank, never verbs
        heads = Set(first(split(k)) for k in keys(G.VERBS))
        plan = read(joinpath(TOOL, "IMPLEMENTATION.md"), String)
        for m in eachmatch(r"`gbg (?:--\w+ )?([a-z][a-z-]*)", plan)
            after = replace(SubString(plan, m.offset, min(lastindex(plan), m.offset + 80)), r"\s+" => " ")
            occursin("does not exist", after) && continue          # a deliberate mention of a non-verb
            occursin("hook queue-guard", after) && continue         # named twice, both times to deny it
            @test m.captures[1] in heads
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
    @testset "a bug-hunt finding banks against the core schema" begin
        # The regression this pins: `bank` validated every finding against schema/finding.schema.json,
        # which closes its property set, while a bug-hunt finding carries its own `kind`, `verdict`,
        # `file`, `line`, `mechanism` — so every real hunt bank threw on its first finding.
        hunt = Dict{String,Any}("type" => "operational", "severity" => "major", "confidence" => "high",
                                "title" => "a title long enough", "locations" => ["src/X.jl:1"],
                                "description" => "a description long enough to pass",
                                "kind" => "runtime", "verdict" => "REPRODUCED", "observed" => "what happened",
                                "file" => "src/X.jl", "line" => 1, "mechanism" => "why it happens",
                                "id" => "2026-09-09-bug-hunt-01/free#1", "lane" => "free", "n" => 1, "seeded" => false)
        core = G.load_schema("finding")
        @test !isempty(G.validate(core, hunt))                             # the defect, both directions
        @test isempty(G.validate(core, Dict{String,Any}(k => v for (k, v) in hunt if k in keys(core["properties"]))))
    end
    @testset "the home page's counts are the real ones" begin
        # every number the home page cites is re-measured here; a cited count nothing asserts drifts
        page = read(joinpath(TOOL, "docs", "src", "index.md"), String)
        n(re) = (m = match(re, page); m === nothing ? -1 : parse(Int, m.captures[1]))
        @test n(r"There are (\d+)\s*\n?\s*verbs") == length(G.VERBS)
        @test n(r"(\d+) scans over docstrings") == length(G.scan_catalog())
        @test n(r"(\d+) read-only checks") == length(G.Doctor.CHECKS)
        @test n(r"The policy is (\d+) rules") == length(TOML.parsefile(joinpath(TOOL, "policy", "RULES.toml"))["rule"])
    end
    @testset "the transitional Python is gone (1.6)" begin
        @test !isfile(joinpath(TOOL, "src", "CLI", "consolidate.py"))
        @test isempty(filter(f -> endswith(f, ".py"), vcat([joinpath(d, f) for (d, _, fs) in walkdir(joinpath(TOOL, "src")) for f in fs],
                                                          [joinpath(d, f) for (d, _, fs) in walkdir(joinpath(TOOL, "instruments")) for f in fs])))
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
                else
                    @test c in ("panel", "weakness")             # judged by a running panel, or owed
                end
            end
        end
    end
end
