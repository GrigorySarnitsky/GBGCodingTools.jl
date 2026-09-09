# Witnesses.jl — the witness runner: the mechanical half of /bug-hunt. Sources: PF bug-hunt/witnesses.jl
# (directory as argument, the zero-assertion guard) + IT bug-hunt/witnesses.jl (Base.julia_cmd(),
# expect fail|pass, BROKEN ⇒ non-zero, the subset filter, empty ⇒ 2). Added: BLOCKED (a witness whose
# header declares `# blocked: <reason>` and errors is reported apart) and the REFUSAL of any witness
# that `include`s a file or loads anything but the package under test, Test and the stdlib.

"""
    Witnesses

The witness runner of `/bug-hunt`. A witness is a self-contained Julia file asserting the CORRECT
behaviour of the package, so it FAILS on a defective tree and PASSES once the defect is fixed;
[`Witnesses.run`](@ref) executes every witness of a directory in a fresh process and holds the set to
one expectation. The directory is usually a round's — a round being one run of one instrument over one
consumer, recorded as a tracked directory under `.gbg/rounds/`. An agent's account of a program that
fails is not that program; this is.
"""
module Witnesses

import ..GBGCodingTools

export WitnessResult

"""
    WitnessResult

The outcome of one witness file.

The fields are:

- `name` — the file name.
- `status` — `:pass`, `:fail` (an assertion came out false — the witness working), `:broken` (an
  exception outside an assertion, a load error, or a pass with zero assertions — evidence of nothing),
  `:blocked` (the file declares `# blocked: <reason>`, reported its counts, errored and failed nothing;
  a run that reported no counts is `:broken`) or `:refused` (the file loads
  something it may not, or `include`s a file — never run).
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

The reason `path` may not run as a witness, or `nothing`: it `include`s a file, or it `using`s /
`import`s a module other than `package`, `Test`, `Base`, `Core` and the standard library (a witness
cannot be weakened through a helper it loads). Comments are ignored. Returns the message or `nothing`.
"""
function refusal(path::AbstractString, package::AbstractString)
    for (i, raw) in enumerate(eachline(path))
        line = strip(replace(raw, r"#.*$" => ""))
        isempty(line) && continue
        occursin(r"\binclude\s*\(", line) && return "line $i includes a file (`include(` is refused in a witness)"
        m = match(r"^\s*(?:using|import)\s+(.+)$", line)
        m === nothing && continue
        for spec in split(m.captures[1], ',')
            root = String(first(split(strip(split(strip(spec), ':')[1]), '.')))
            isempty(root) && continue
            root in (package, "Test", "Base", "Core") && continue
            root in STDLIBS && continue
            return "line $i loads `$root`, which is not the package under test, Test, or a standard library"
        end
    end
    return nothing
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

"""
    witness_project(root, witness_env, package) -> String

The `--project` a witness runs under. The arguments are:

- `root` — the consumer root.
- `witness_env` — the config's `instruments.bug-hunt.witness_env` (a directory under the root, `test`
  by default).
- `package` — the package name the witness may load.

Returns the project path.
"""
function witness_project(root::AbstractString, witness_env::AbstractString, package::AbstractString)
    env = joinpath(root, witness_env)
    pf = joinpath(env, "Project.toml")
    if isfile(pf)
        p = try GBGCodingTools.TOML.parsefile(pf) catch; Dict() end
        haskey(get(p, "deps", Dict()), package) && return env
    end
    return String(root)
end

# The wrapper the runner executes: it includes the witness inside an outer testset so the counts are
# reported machine-readably on one line, and an exception outside every @test is reported as such.
const WRAPPER = raw"""
using Test
const __gbg_path = ARGS[1]
__gbg_counts = nothing
try
    Test.TESTSET_PRINT_ENABLE[] = false
    __gbg_ts = @testset "gbg witness" begin
        Base.include(Main, __gbg_path)
    end
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

Runs one witness file in a fresh Julia process and classifies the outcome. The arguments are:

- `path` — the witness file.
- `project` — the `--project` it runs under.
- `package` — the package it may load.

The file is first read, never included: a witness that `include`s another file, or that loads
anything outside `package`, `Test` and the standard library, is REFUSED before it runs. The run wraps
the file in an outer testset and prints one machine-readable line `GBG_WITNESS pass= fail= error=`.

From that line the result is `:pass` (assertions and none failing), `:fail` (an assertion failed — the
evidence a hunt wants), `:broken` (an exception outside an assertion, an assertion that threw, or a
pass with ZERO assertions, which is evidence of nothing), or `:blocked` (it errored, failed nothing,
and carries a `# blocked: <reason>` header; one that also failed is `:broken`, its reason naming both
counts, and so is one that reported no counts at all — an exit or a crash — header or not). Returns
the result with the counts and the reason.
"""
function run_one(path::AbstractString; project::AbstractString, package::AbstractString)
    name = basename(path)
    r = refusal(path, package)
    r === nothing || return WitnessResult(name, :refused, 0, 0, 0, r)
    out = IOBuffer()
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$project -e $WRAPPER -- $path`
    proc = Base.run(pipeline(Cmd(cmd; dir = dirname(project), ignorestatus = true); stdout = out, stderr = out))
    text = String(take!(out))
    m = match(r"GBG_WITNESS pass=(\d+) fail=(\d+) error=(\d+)", text)
    blocked = blocked_reason(path)
    if m === nothing
        exc = match(r"GBG_WITNESS_EXCEPTION (.*)", text)
        reason = exc === nothing ? first(strip(text), 600) : String(exc.captures[1])
        # no counts were reported (the process exited or crashed before the wrapper's line): whether it
        # failed is unknown, so it is never :blocked — that state needs a report of zero failures
        return WitnessResult(name, :broken, 0, 0, 0, "no counts reported (the process exited or crashed): " * reason * (blocked === nothing ? "" : "; header: " * blocked))
    end
    p, f, e = parse.(Int, m.captures)
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

Runs every witness under `dir` and holds the set to an expectation. The arguments are:

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
