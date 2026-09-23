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
#
# It is also held that the file PARSES, for one defect class. On 2026-09-22 an apostrophe inside a
# single-quoted string — `'…read the file's changed regions'` — ended the literal early, and the
# harness refused the script before any agent started. Every instrument and every stage was dead, in
# the one file all of them go through, and nothing here noticed: this test read the driver for the keys
# it mentions and never asked whether it was JavaScript. The fixture runs could not have caught it
# either, since they launch no agent. Reported by the GBGPeriodicFields session, which met it on the
# first real run.
using Test, GBGCodingTools
include("helpers.jl")

const DRIVER = joinpath(TOOL, "drivers", "run.js")

"""
A scan over JavaScript for the defect class of 2026-09-22: a single-quoted literal ended early by an
apostrophe inside it, leaving bare identifiers where an expression belongs.

It LEXES rather than greps, because a regex cannot tell `'a', b: 'c'` — two literals with code between
them — from one literal that closed in the wrong place; a regex tried first reported thirteen defects in
a file that had none. It is not a parser: it knows strings, template literals, comments and the `\${…}`
holes templates open, and nothing else about the language. A real parser was tried and rejected — the
one available here refuses top-level `await`, which this driver uses and which is valid — so a gate
built on it would fail on correct files, which is worse than the defect.
"""
function js_code_only(text::AbstractString)
    out = IOBuffer()
    i, n = firstindex(text), lastindex(text)
    while i <= n
        c = text[i]
        if c == '/' && i < n && text[nextind(text, i)] == '/'
            while i <= n && text[i] != '\n'; i = nextind(text, i); end
        elseif c == '/' && i < n && text[nextind(text, i)] == '*'
            i = nextind(text, i, 2)
            while i <= n && !(text[i] == '*' && i < n && text[nextind(text, i)] == '/'); i = nextind(text, i); end
            i = min(n + 1, nextind(text, i, 2))
        else
            print(out, c); i = nextind(text, i)
        end
    end
    return String(take!(out))
end

function js_string_defects(text::AbstractString)
    out = String[]
    line_of(i) = count(==('\n'), text[1:prevind(text, i)]) + 1
    stack = Any[(:code, 0)]                       # (kind, brace depth inside a `${…}`)
    i, n = firstindex(text), lastindex(text)
    while i <= n
        c = text[i]
        kind, depth = last(stack)
        if kind === :template
            if c == '\\';                    i = min(n + 1, nextind(text, i, 2))
            elseif c == '`';                   pop!(stack); i = nextind(text, i)
            elseif c == '$' && i < n && text[nextind(text, i)] == '{'
                push!(stack, (:code, 0));      i = nextind(text, i, 2)
            else                               i = nextind(text, i)
            end
            continue
        end
        if c == '/' && i < n && text[nextind(text, i)] == '/'
            while i <= n && text[i] != '\n'; i = nextind(text, i); end
        elseif c == '/' && i < n && text[nextind(text, i)] == '*'
            i = nextind(text, i, 2)
            while i <= n && !(text[i] == '*' && i < n && text[nextind(text, i)] == '/'); i = nextind(text, i); end
            i = min(n + 1, nextind(text, i, 2))
        elseif c == '`'
            push!(stack, (:template, 0));      i = nextind(text, i)
        elseif c == '"' || c == '\''
            q, at = c, i
            i = nextind(text, i)
            closed = false
            while i <= n
                if text[i] == '\\';    i = min(n + 1, nextind(text, i, 2))
                elseif text[i] == q;     closed = true; i = nextind(text, i); break
                elseif text[i] == '\n';  break
                else                     i = nextind(text, i)
                end
            end
            if !closed
                push!(out, "line $(line_of(at)): a $q literal is not closed on its line")
            elseif i <= n && (isletter(text[i]) || isdigit(text[i]) || text[i] == '_')
                push!(out, "line $(line_of(at)): a $q literal ends immediately before `$(text[i])`, " *
                           "which is what an apostrophe inside it looks like")
            end
        elseif c == '{' && length(stack) > 1
            stack[end] = (:code, depth + 1);   i = nextind(text, i)
        elseif c == '}' && length(stack) > 1
            depth == 0 ? pop!(stack) : (stack[end] = (:code, depth - 1))
            i = nextind(text, i)
        else
            i = nextind(text, i)
        end
    end
    return out
end

"""Every key the Julia side writes into a stage's arguments, at the top level and inside a role."""
function written_keys()
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".gbg")); mkpath(joinpath(root, "docs", "src"))
    write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
    write(joinpath(root, "docs", "src", "guide.md"), "# Guide\n\nProse.\n")
    cfg = G.ConfigIO.read_config(root)
    run = G.Orchestration.Runs.start(:documentation_review, root; io = devnull)
    path = G.Orchestration.Agents.write_arguments(root, run, cfg;
                roles = G.Catalogue.roles_of(:documentation_review, cfg), io = devnull)
    args = G.JSON3.read(read(path, String), Dict{String,Any})
    # A role as the DRIVER sees it, after it rehydrates one from the wire: the role's own keys, the
    # keys of its kind, and the three paths it builds from the key and a directory.
    role_keys = if isempty(args["roles"])
        String[]
    else
        r = args["roles"][1]
        sort(unique(vcat(collect(keys(r)), collect(keys(args["kinds"][r["kind"]])),
                         ["result_file", "finding_file", "diff_file"])))
    end
    return (sort(collect(keys(args))), role_keys)
end

"""
Write one verify stage of `n` findings, each finding and each diff of `size` characters, into a fresh
package, and return the size in bytes of the arguments file the session would have to type.
"""
function arguments_bytes(n::Int, size::Int)
    root = mktempdir(; cleanup = true)
    mkpath(joinpath(root, ".gbg")); mkpath(joinpath(root, "docs", "src"))
    write(joinpath(root, ".gbg", "config.jl"), """Config(package = "Sample", tool = :dev)""")
    write(joinpath(root, "docs", "src", "guide.md"), "# Guide\n\nProse.\n")
    cfg = G.ConfigIO.read_config(root)
    run = G.Orchestration.Runs.start(:documentation_review, root; io = devnull)
    text = repeat("w ", size ÷ 2)
    roles = G.Model.AgentRole[]; extras = Dict{Symbol,Any}()
    for i in 1:n
        id = Symbol("verify-f$i")
        push!(roles, G.Model.AgentRole(; id, instrument = :documentation_review,
                                       reads = [G.Model.FileSet.PAGES], site = true, kept_from_code = true,
                                       description = "the one standpoint", rules = [:RULE_X],
                                       strength = G.Model.Strength.FULL, cap = 1))
        extras[id] = Dict{String,Any}("kind" => "verifier", "finding_id" => "f$i", "unit" => "u.txt",
                                      "finding" => Dict("id" => "f$i", "claim" => text,
                                                        "locations" => [Dict("file" => "a.md", "text" => text)]),
                                      "diff" => text, "verdicts" => ["FIXED", "NOT_FIXED"])
    end
    path = G.Orchestration.Agents.write_arguments(root, run, cfg; roles, extras, io = devnull)
    return filesize(path)
end

@testset "the driver and the Julia side read one set of arguments" begin

    # What this SANDBOX allows, which is a different question from whether the file is JavaScript — and
    # the one that let a second launch-blocking defect through a candidate that parsed. A workflow script
    # has no filesystem and no Node API; `import()` is refused; and `Date.now()`, `Math.random()` and an
    # argless `new Date()` throw, because they would break resume. None is visible from Julia, none is
    # visible to a parser, and a fixture run reaches none of them. So they are listed.
    @testset "the driver uses nothing the workflow sandbox refuses" begin
        driver = read(DRIVER, String)
        # Comments are stripped first: this file EXPLAINS what the sandbox refuses, and a check that
        # read its own explanation as a violation would be unusable — the same collision as `discipline:`
        # against a ban on `line:`, met the same week.
        code = js_code_only(driver)
        for refused in ("import(", "require(", "'node:", "\"node:", "process.", "Date.now()",
                        "Math.random()", "new Date()")
            @test !occursin(refused, code)
        end
        # And the reason the first of those is not there any more: the agent writes its own result file.
        @test occursin("result_file", driver)
        @test occursin("write your answer as JSON", driver)
    end

    # The cheapest gate on the one file every instrument goes through, and the one that was missing.
    @testset "the driver is JavaScript, for the class that stopped every instrument" begin
        driver = read(DRIVER, String)
        @test isempty(js_string_defects(driver))

        # The scan is worth only what it catches, so it is shown catching the real thing: the 2026-09-22
        # line VERBATIM, as the driver carried it when the harness refused the file before any agent
        # started. It is quoted here rather than made by editing the driver, because the line it was
        # made from has since been rewritten away — a gate that borrows its specimen from the file it
        # guards loses the specimen the moment that file changes, and then proves nothing while still
        # passing.
        @test !isempty(js_string_defects(
            raw"""  const note = l.found === 'OUTDATED' ? '  [not found again — read the file's changed regions]' : '';"""))

        # And shown NOT firing on the shapes that surround it, or it would be noise rather than a gate.
        @test isempty(js_string_defects(raw"const a = 'one', b = 'two';"))
        @test isempty(js_string_defects(raw"const s = 'it\'s fine';"))          # an escaped apostrophe
        @test isempty(js_string_defects(raw"// a reader's comment, not code"))
        @test isempty(js_string_defects(raw"const t = `a ${x ? 'y' : ''} b`;")) # a template with holes
        @test !isempty(js_string_defects(raw"const s = 'the file's name';"))
    end
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

    # THE GATE ON WHAT A LAUNCH COSTS THE SESSION. A workflow script has no filesystem, so the session
    # TYPES the arguments into the launching call, and every byte is a byte of its context. The first
    # real review paid 733 KB for one verify stage, because each role carried its finding, its diff and
    # its brief in full. Two properties hold it down now, and both are asserted rather than trusted: the
    # file's size does not depend on the size of what the agents will read, and a role costs a bounded
    # number of bytes over the stage's fixed part. Neither number is a measurement of this machine; both
    # are the SHAPE, which is what a regression would change.
    @testset "the arguments file does not grow with what the agents read" begin
        small = arguments_bytes(40, 40)
        large = arguments_bytes(40, 40_000)
        @test small == large                                      # findings and diffs are paths, not values
        # the marginal cost of a role: everything a role carries that is its own, and nothing else
        per_role = (arguments_bytes(80, 40) - arguments_bytes(40, 40)) / 40
        @test per_role < 120
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
        # A WORD boundary, not a substring: the tagger's `discipline:` ends in `line:`, and the bare
        # substring failed on it the day that field was added (2026-09-22). What is forbidden is a
        # `line` PROPERTY — a line an agent reported is its count of the text it was shown, not the file's.
        @test !occursin(r"\bline:", driver)
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
