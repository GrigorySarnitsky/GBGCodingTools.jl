# Witnesses.jl — the witness runner: the mechanical half of /bug-hunt. Sources: PF bug-hunt/witnesses.jl
# (directory as argument, the zero-assertion guard) + IT bug-hunt/witnesses.jl (Base.julia_cmd(),
# expect fail|pass, BROKEN ⇒ non-zero, the subset filter, empty ⇒ 2). Added: BLOCKED (a witness whose
# header declares `# blocked: <reason>` and errors is reported apart) and the REFUSAL of any witness
# that loads code, forges its verdict, or loads anything but the package under test, Test and the stdlib.

"""
    Witnesses

The witness runner of `/bug-hunt`. A witness is a self-contained Julia file asserting the CORRECT
behaviour of the package, so it FAILS on a defective tree and PASSES once the defect is fixed;
[`Witnesses.run`](@ref) executes every witness of a directory in a fresh process and holds the set to
one expectation, reporting each file as a [`WitnessResult`](@ref). The directory is usually a run's —
one run of one instrument over one consumer, recorded under `.gbg/runs/<id>/`. An agent's account of
a program that fails is not that program; this is.
"""
module Witnesses

import ..GBGCodingTools
import ..GBGCodingTools: Texts

export WitnessResult

const JS = Base.JuliaSyntax

"""
    WitnessResult

The outcome of one witness file.

# Fields

- `name` — the file name.
- `status` — `:pass`, `:fail` (an assertion came out false — the witness working), `:broken` (an
  exception outside an assertion, a load error, or a pass with zero assertions — evidence of nothing),
  `:blocked` (the file declares `# blocked: <reason>`, reported its counts, errored and failed nothing;
  a run that reported no counts is `:broken`) or `:refused` (the file names what
  [`refusal`](@ref) refuses — never run).
- `passes`, `fails`, `errors` — the Test counts the run reported (zeros when it did not get that far).
- `reason` — the blocked reason, the refusal, or the first lines of a broken run's output.
"""
struct WitnessResult
    name::String
    status::Symbol
    passes::Int
    fails::Int
    errors::Int
    reason::String
end

const STDLIBS = Set(String.(readdir(Sys.STDLIB)))

"""
    refusal(path, package) -> Union{String,Nothing}

The reason `path` may not run as a witness, or `nothing`. Refused: the NAME, anywhere in the file and
however it is reached — called, aliased (`const inc = include`), passed (`invokelatest(include, …)`),
qualified or quoted — of `include`, `include_string`, `evalfile`, `require`, `eval`, `invokelatest`,
`exit` or `ccall`, and the macros `@eval` and `@ccall`; `ARGS` and any `__gbg_` name, which are the
runner's; a method defined on another module's function (`Test.f(x) = …`, `import Test: f`); and a
`using` or `import` of anything but `package`, `Test`, `Base`, `Core` and the standard library. The first
kind loads code the runner never read; the second and third are how a witness forges its verdict, by
exiting 0 after a failed assertion or redefining how Test counts one. Read from the parse tree, so a
spelling over several lines or inside a macro is seen; a file that does not parse is refused too.
Returns the message or `nothing`.
"""
function refusal(path::AbstractString, package::AbstractString)
    tree = try
        JS.parseall(JS.SyntaxNode, read(path, String); filename = path)
    catch err
        return "the file does not parse: " * sprint(showerror, err)
    end
    return refusal_in(tree, package)
end

# Refused as NAMES rather than as call heads: a call-head check let `const inc = include; inc("h.jl")`
# and `invokelatest(include, "h.jl")` through (found verifying the review's fixes, 2026-09-27).
const FORBIDDEN = Set([:include, :include_string, :evalfile, :require, :eval, :invokelatest, :exit, :ccall, :ARGS])
const FORBIDDEN_MACROS = Set([Symbol("@eval"), Symbol("@ccall")])

function refusal_in(node, package)
    k = JS.kind(node); cs = something(JS.children(node), ())
    line = JS.source_line(node)
    if k === JS.K"using" || k === JS.K"import"
        for root in import_roots(node)
            root in (package, "Test", "Base", "Core") && continue
            root in STDLIBS && continue
            return "line $line loads `$root`, which is not the package under test, Test, or a standard library"
        end
        # `import M: f` and `import M.f` are how a function of M is extended; `using` is enough to call
        # it, and a macro imported by name (`import Test: @test`) extends nothing
        k === JS.K"import" && any(imported_function, cs) &&
            return "line $line imports a function by name, which is how another module's function is redefined (refused in a witness)"
    elseif k === JS.K"Identifier" && node.val isa Symbol
        name = node.val
        name in FORBIDDEN && return "line $line names `$name`, which a witness may not (it loads code or forges the verdict)"
        startswith(String(name), "__gbg") && return "line $line names `$name`, which is the runner's own"
    elseif string(k) in ("MacroName", "macro_name") && Symbol("@", Texts.macro_name(node)) in FORBIDDEN_MACROS
        return "line $line calls `@$(Texts.macro_name(node))`, which runs code the runner never read (refused in a witness)"
    elseif k === JS.K"function" && !isempty(cs) && JS.kind(signature_head(cs[1])) === JS.K"."
        return "line $line defines a method of another module's function, which can redefine how Test counts (refused in a witness)"
    end
    for c in cs
        r = refusal_in(c, package)
        r === nothing || return r
    end
    return nothing
end

# Whether one clause of an `import` names a function rather than a module or a macro.
function imported_function(c)
    kid = something(JS.children(c), ())
    JS.kind(c) === JS.K":" && return any(imported_function_path, kid[2:end])
    return JS.kind(c) === JS.K"importpath" && length(kid) > 1 && imported_function_path(c)
end
imported_function_path(p) = (kid = something(JS.children(p), ()); !isempty(kid) && JS.kind(last(kid)) === JS.K"Identifier")

# The name a method definition defines: the call under any `where` and return-type annotation.
function signature_head(sig)
    while JS.kind(sig) in (JS.K"where", JS.K"::") && !isempty(something(JS.children(sig), ()))
        sig = first(JS.children(sig))
    end
    cs = something(JS.children(sig), ())
    return JS.kind(sig) === JS.K"call" && !isempty(cs) ? cs[1] : sig
end

# The first identifier of every path a `using` or `import` names: `Test, Helper` gives both, `Test: a`
# gives `Test`, and `A.B` gives `A`.
function import_roots(node)
    out = String[]
    walk(n) = begin
        if JS.kind(n) === JS.K"importpath"
            cs = something(JS.children(n), ())
            isempty(cs) || push!(out, strip(String(JS.sourcetext(cs[1]))))
        elseif JS.kind(n) === JS.K":"
            cs = something(JS.children(n), ())
            isempty(cs) || walk(cs[1])                 # `using A: b, c` loads A alone
        else
            foreach(walk, something(JS.children(n), ()))
        end
    end
    walk(node)
    return out
end

"""
    blocked_reason(path) -> Union{String,Nothing}

The reason in a `# blocked: <reason>` header on one of the first five lines of `path`, or `nothing`.
Returns the reason text.
"""
function blocked_reason(path::AbstractString)
    for (i, line) in enumerate(eachline(path))
        i > 5 && break
        m = match(r"^\s*#\s*blocked:\s*(.+?)\s*$", line)
        m === nothing || return String(m.captures[1])
    end
    return nothing
end

# The wrapper the runner executes: it includes the witness inside an outer testset, exits 0 on a clean
# run, 1 on a failing assertion and 3 on an exception outside every @test — the exit code is the
# verdict — and prints the counts on one line, as the detail.
const WRAPPER = raw"""
using Test
const __gbg_path = ARGS[1]
__gbg_counts = nothing
try
    __gbg_run() = @testset "gbg witness" begin
        Base.include(Main, __gbg_path)
    end
    # Test's print switch is a Ref on Julia 1.12 and a ScopedValue on 1.13, where assigning it is a
    # MethodError and every witness read as broken (found checking 1.13, 2026-09-28)
    __gbg_ts = Test.TESTSET_PRINT_ENABLE isa Base.RefValue ?
        (Test.TESTSET_PRINT_ENABLE[] = false; __gbg_run()) :
        Base.ScopedValues.with(__gbg_run, Test.TESTSET_PRINT_ENABLE => false)
    global __gbg_counts = Test.get_test_counts(__gbg_ts)
catch err
    if err isa Test.TestSetException
        println("GBG_WITNESS pass=", err.pass, " fail=", err.fail, " error=", err.error)
        exit(1)
    end
    println("GBG_WITNESS_EXCEPTION ", sprint(showerror, err))
    exit(3)
end
if __gbg_counts !== nothing
    c = __gbg_counts
    p = c isa Tuple ? c[1] : c.passes;  f = c isa Tuple ? c[2] : c.fails;  e = c isa Tuple ? c[3] : c.errors
    cp = c isa Tuple ? c[5] : c.cumulative_passes; cf = c isa Tuple ? c[6] : c.cumulative_fails; ce = c isa Tuple ? c[7] : c.cumulative_errors
    println("GBG_WITNESS pass=", p + cp, " fail=", f + cf, " error=", e + ce)
    exit((f + cf + e + ce) == 0 ? 0 : 1)
end
"""

"""
    run_one(path; project, package) -> WitnessResult

Runs one witness file in a fresh Julia process and classifies the outcome.

# Arguments

- `path` — the witness file.
- `project` — the `--project` it runs under.
- `package` — the package it may load.

The file is first read, never included: a witness that loads another file, or that loads anything
outside `package`, `Test` and the standard library, is REFUSED before it runs. The run wraps the file
in an outer testset; THE EXIT CODE IS THE VERDICT — 0 clean, 1 an assertion failed, 3 an exception
outside every assertion — and the counts line the wrapper prints is the detail. A witness runs in the
wrapper's own process, so nothing the wrapper holds is secret from it: a token on the line was readable
by the witness it was meant to exclude (found verifying the review's fixes, 2026-09-27). What keeps the
exit code the wrapper's is [`refusal`](@ref); the LAST counts line is read, and one that disagrees with
the exit code is `:broken`.

The result is `:pass` (exit 0 with assertions), `:fail` (exit 1 — the evidence a hunt wants), `:broken`
(exit 3, an assertion that threw, a pass with ZERO assertions, which is evidence of nothing, or no
counts at all), or `:blocked` (an assertion threw, none failed, and it carries a `# blocked: <reason>`
header; one that also failed is `:broken`, its reason naming both counts, and so is one that reported no
counts at all — an exit or a crash — header or not). Returns the result with the counts and the reason.
"""
function run_one(path::AbstractString; project::AbstractString, package::AbstractString)
    name = basename(path)
    r = refusal(path, package)
    r === nothing || return WitnessResult(name, :refused, 0, 0, 0, r)
    out = IOBuffer()
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$project -e $WRAPPER -- $path`
    # the working directory is the project's: a directory as given, or the directory of a project FILE
    proc = Base.run(pipeline(Cmd(cmd; dir = isdir(project) ? project : dirname(project), ignorestatus = true);
                             stdout = out, stderr = out))
    text = String(take!(out))
    code = proc.exitcode
    # the last line: the wrapper prints after the witness has finished
    ms = collect(eachmatch(r"^GBG_WITNESS pass=(\d+) fail=(\d+) error=(\d+)$"m, text))
    m = isempty(ms) ? nothing : last(ms)
    blocked = blocked_reason(path)
    if m === nothing
        exc = match(r"GBG_WITNESS_EXCEPTION (.*)", text)
        reason = exc === nothing ? first(strip(text), 600) : String(exc.captures[1])
        # no counts were reported (the process exited or crashed before the wrapper's line): whether it
        # failed is unknown, so it is never :blocked — that state needs a report of zero failures
        return WitnessResult(name, :broken, 0, 0, 0, "no counts reported (exit $code; the process exited or crashed): " * reason * (blocked === nothing ? "" : "; header: " * blocked))
    end
    p, f, e = parse.(Int, m.captures)
    # the counts must say what the exit code says, or the line is not the wrapper's
    (code == 0 && f + e == 0) || (code == 1 && f + e > 0) ||
        return WitnessResult(name, :broken, p, f, e, "exit $code disagrees with the counts it reported (pass=$p fail=$f error=$e)")
    if e > 0
        # :blocked only when nothing failed: a witness that was seen to fail is evidence, never filed away
        f == 0 && blocked !== nothing && return WitnessResult(name, :blocked, p, f, e, blocked)
        return WitnessResult(name, :broken, p, f, e, (f > 0 ? "$f assertion(s) failed AND " : "") * "an assertion threw: " * first(strip(text), 600))
    end
    f > 0 && return WitnessResult(name, :fail, p, f, e, "")
    p == 0 && return WitnessResult(name, :broken, p, f, e, "passed with ZERO assertions — a witness that asserts nothing is evidence of nothing")
    return WitnessResult(name, :pass, p, f, e, "")
end

"""
    run(dir; expect, package, project, names = String[], io = stdout) -> (code, results)

Runs every witness under `dir` and holds the set to an expectation.

# Arguments

- `dir` — the directory of `.jl` witnesses (the round's `witnesses/`, or `test/regressions/escalated/`).
- `expect` — `:fail` (a hunt's bank: every witness must fail on this tree) or `:pass` (after the fix).
- `package` — the package a witness may load.
- `project` — the `--project` the witnesses run under.
- `names` — restrict the run to the files whose names contain one of these.
- `io` — where the per-witness lines and the summary go.

An empty directory is a refusal (nothing was verified), exit 2, as is any REFUSED witness. A witness
that PASSES when failure was expected is a PHANTOM (the defect does not exist) and one that FAILS when
a pass was expected is UNFIXED; either is exit 1. A BROKEN witness is exit 1 too — evidence of nothing
in either direction. BLOCKED witnesses are reported apart and do not fail the run.

Returns the exit code and the per-witness results.
"""
function run(dir::AbstractString; expect::Symbol, package::AbstractString, project::AbstractString,
             names::AbstractVector{<:AbstractString} = String[], io::IO = stdout)
    expect in (:fail, :pass) || throw(ArgumentError("expect must be :fail or :pass"))
    isdir(dir) || (println(io, "REFUSING: no witness directory at $dir"); return (2, WitnessResult[]))
    files = sort!([joinpath(dir, f) for f in readdir(dir) if endswith(f, ".jl") && isfile(joinpath(dir, f))])
    if !isempty(names)
        files = filter(f -> any(n -> occursin(n, basename(f)), names), files)
    end
    if isempty(files)
        println(io, "REFUSING: no witnesses found in $dir — nothing was verified, and an empty run is not a success")
        return (2, WitnessResult[])
    end
    results = [run_one(f; project, package) for f in files]
    for r in results
        tag = uppercase(String(r.status))
        detail = r.status in (:pass, :fail) ? "  (pass=$(r.passes) fail=$(r.fails))" : "  — " * r.reason
        println(io, rpad(tag, 8), r.name, detail)
    end
    n = length(results)
    count(s) = Base.count(r -> r.status == s, results)
    println(io, "\n$n witness(es): $(count(:pass)) pass, $(count(:fail)) fail, $(count(:broken)) broken, $(count(:blocked)) blocked, $(count(:refused)) refused")
    println(io, "expectation: every witness must $(uppercase(String(expect)))")
    count(:refused) > 0 && (println(io, "!! a REFUSED witness loads what it may not; fix it before anything is graded"); return (2, results))
    wrong = filter(r -> r.status == (expect == :fail ? :pass : :fail), results)
    if !isempty(wrong)
        println(io, expect == :fail ?
            "\n!! PHANTOM — these witnesses PASS on the current tree, so the defect they claim does not exist. Withdraw the finding." :
            "\n!! UNFIXED — these witnesses still FAIL, so the fix did not land (or landed on the wrong site).")
        foreach(r -> println(io, "   !! ", r.name), wrong)
    end
    if count(:broken) > 0
        println(io, "\n!! BROKEN — evidence of NOTHING in either direction; repair or discard, never count as a proven bug:")
        foreach(r -> r.status == :broken && println(io, "   !! ", r.name, " — ", r.reason), results)
    end
    if count(:blocked) > 0
        println(io, "\n-- BLOCKED (reported apart; the reason is the header's):")
        foreach(r -> r.status == :blocked && println(io, "   -- ", r.name, " — ", r.reason), results)
    end
    return ((isempty(wrong) && count(:broken) == 0) ? 0 : 1, results)
end

end # module Witnesses
