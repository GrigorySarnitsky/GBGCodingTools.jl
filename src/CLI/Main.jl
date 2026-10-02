# Main.jl — argument parsing, `--dev`, `--version`, the verb table, the try/catch → 3.

"""
    VERBS

The closed verb table of the command line: `"<noun> <verb>"` (or a lone `"<noun>"`) to the function that
runs it. Every entry takes the remaining arguments as a `Vector{String}` and returns the exit code as an
`Int`. Each `src/CLI/*.jl` file registers its own verbs at load; nothing else adds to the table, and a verb
that is not in it does not exist.
"""
const VERBS = Dict{String,Function}()

"""
    Options

The parsed command line of one verb: the positional arguments in order and the options by name.

# Fields

- `positional` — every argument that is not an option, in order.
- `flags` — the options given without a value (`--deep`, `--dry-run`), as a set of names without the dashes.
- `values` — the options given with a value (`--only LOAD`, `--reason "…"`, `--profile=core`), name to value.
"""
struct Options
    positional::Vector{String}
    flags::Set{String}
    values::Dict{String,String}
end

"""
    UsageError

A command line a verb cannot run: an option missing its value.

It is the user's mistake, so [`main`](@ref) prints it without a backtrace and returns 2, not the crash
code 3 (found in review, 2026-09-26).

# Fields

- `msg` — the sentence printed.
"""
struct UsageError <: Exception
    msg::String
end
Base.showerror(io::IO, e::UsageError) = print(io, e.msg)

"""
    parse_options(args; valued = String[]) -> Options

Parses `args` into an `Options` record. Any `--name=value` is a value whatever `valued` says; an option
named in `valued` also consumes the following bare argument as its value; every other bare `--name` is a
flag; a lone `--` ends option parsing.

# Arguments

- `args` — the command-line arguments to parse, in order.
- `valued` — the names, without the dashes, of the options that take a value.

Returns the parsed options; an option that is in `valued` but has no value — the end of the arguments,
or the `--` that ends them — is a [`UsageError`](@ref), which [`main`](@ref) turns into exit 2.
"""
function parse_options(args::AbstractVector{<:AbstractString}; valued = String[])
    pos = String[]; flags = Set{String}(); vals = Dict{String,String}()
    i = 1
    while i <= length(args)
        a = String(args[i])
        if a == "--"
            append!(pos, String.(args[i+1:end])); break
        elseif startswith(a, "--")
            body = a[3:end]
            if (k = findfirst('=', body)) !== nothing
                vals[body[1:k-1]] = body[k+1:end]
            elseif body in valued
                (i == length(args) || args[i+1] == "--") && throw(UsageError("--$body needs a value"))
                vals[body] = String(args[i+1]); i += 1
            else
                push!(flags, body)
            end
        else
            push!(pos, a)
        end
        i += 1
    end
    Options(pos, flags, vals)
end

"""
    running_dev() -> Bool

Whether the running copy is a working tree rather than a fetched tag: `GBG_DEV` is set (the `--dev`
route of the shim — `bin/gbg`, the small script `gbg install` copies to `~/.local/bin/gbg` and which
execs [`main`](@ref) — or `main`'s own flag), or the package directory holds a `.git` entry — the dev checkout
loaded by path, as the tool's own `docs/` environment and the fixture's sub-environments do. A copy Pkg
fetched into the depot at a tag has no `.git`. Returns `true` for a working tree.
"""
running_dev() = get(ENV, "GBG_DEV", "") == "1" || ispath(joinpath(pkgdir(GBGCodingTools), ".git"))

"""
    git_stamp(dir) -> String

The `dev+<sha>[-dirty]` stamp of the working tree at `dir`: the short `HEAD` sha and a `-dirty` suffix
when `git status --porcelain` is non-empty. Returns `"dev+unknown"` when `git` fails there.
"""
function git_stamp(dir::AbstractString)
    try
        sha = strip(read(setenv(`git -C $dir rev-parse --short HEAD`, dir = dir), String))
        dirty = !isempty(strip(read(`git -C $dir status --porcelain`, String)))
        return "dev+" * sha * (dirty ? "-dirty" : "")
    catch
        return "dev+unknown"
    end
end

"""
    tool_version() -> String

The version string of the running copy, as every stamp records it: the `Project.toml` version
(`"1.0.0"`) for a copy Pkg fetched at a tag, or `dev+<sha>[-dirty]` for a working tree (see
[`running_dev`](@ref)). Returns the string.
"""
tool_version() = running_dev() ? git_stamp(pkgdir(GBGCodingTools)) : string(pkgversion(GBGCodingTools))

"""
    usage(io = stderr)

Prints the verb table to `io`, one verb per line, sorted. Returns `nothing`.
"""
function usage(io::IO = stderr)
    println(io, "usage: gbg [--dev] <noun> [<verb>] [options]   (exit 0 clean · 1 finding · 2 cannot evaluate · 3 crash)")
    for k in sort!(collect(keys(VERBS)))
        println(io, "  gbg ", k)
    end
    nothing
end

"""
    main(args) -> Int

The one entry point of the command line: the shim execs `julia -e 'using GBGCodingTools;
exit(GBGCodingTools.main(ARGS))'`, and every test of a verb calls it directly. Dispatches `<noun> <verb>`
(or a lone noun) through [`VERBS`](@ref) and returns that function's exit code: 0 clean, 1 substantive
finding, 2 cannot evaluate, 3 crash. A `--dev` first argument sets `GBG_DEV=1` so the stamps read
`dev+<sha>`, exactly as the shim's `--dev` route does. An unknown verb prints the table and returns 2.
Output is never truncated.

An exception escaping a verb is printed with its backtrace to `stderr` and returns 3, so a crash is
never read as a finding. The exceptions are the consumer's own config failing to read or validate — a
[`ConfigIO.ConfigError`](@ref) — and a [`UsageError`](@ref), each the documented exit 2, printed
without a backtrace.
"""
function main(args::AbstractVector{<:AbstractString})::Int
    args = String.(args)
    if !isempty(args) && args[1] == "--dev"
        ENV["GBG_DEV"] = "1"; args = args[2:end]
    end
    if isempty(args) || args[1] in ("--help", "-h", "help")
        usage(); return isempty(args) ? 2 : 0
    end
    if args[1] == "--version"
        println(tool_version()); return 0
    end
    key = args[1]; rest = args[2:end]
    if length(args) >= 2 && haskey(VERBS, args[1] * " " * args[2])
        key = args[1] * " " * args[2]; rest = args[3:end]
    elseif !haskey(VERBS, key)
        println(stderr, "gbg: unknown verb ", join(args[1:min(2, end)], " ")); usage(); return 2
    end
    try
        return Int(VERBS[key](rest))
    catch err
        # A consumer config that cannot be read — a call where data was expected, an unknown field, a
        # switch naming no rule — is the documented exit 2, "cannot evaluate", and not a crash. Caught
        # once here, it is caught for every verb; the old reader's error was caught the same way until
        # Phase 5, and the rebuilt reader's reached the crash arm with a backtrace where the contract
        # promises 2 (found in review, 2026-09-23).
        (err isa GBGCodingTools.ConfigIO.ConfigError || err isa UsageError ||
         err isa GBGCodingTools.Engine.Guard.PublicationRefused) &&
            (println(stderr, "gbg ", key, ": ", sprint(showerror, err)); return 2)
        println(stderr, "gbg ", key, ": crashed — ", sprint(showerror, err))
        Base.show_backtrace(stderr, catch_backtrace()); println(stderr)
        return 3
    end
end
