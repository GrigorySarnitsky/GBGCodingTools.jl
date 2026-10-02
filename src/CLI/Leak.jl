# The design's §3.1; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Leak

`gbg leak [--all] [--github]`: the leak scan, over the package it is run in or, with `--all`, over every
package of this machine's fleet and this one. It prints its findings in the session that ran it and
writes no tracked file: a report listing the leaks would be one. Exit 0 when nothing was found, 1 when
something was, 2 when a repository could not be read.
"""
module Leak

using ..GBGCodingTools: GBGCodingTools, ConfigIO, Model, Publication, parse_options, VERBS

"""
    MARK

What opens every line the scan prints. A writer of a tracked file refuses text holding it
(`Engine.Guard.refuse_publication`), so a finding cannot be carried into a record by copying it.
"""
const MARK = GBGCodingTools.Engine.Guard.LEAK_MARK

"""
    roots(all) -> Vector{String}

The repositories one scan reads: the package the command runs in, or with `all` every root
`~/.gbg/fleet` names and the dev checkout `~/.gbg/dev` names. The argument is `all`. Returns them.
"""
function roots(all::Bool)
    all || return (r = ConfigIO.require_root("leak"); r === nothing ? String[] : [r])
    out = String[]
    for file in (joinpath(homedir(), ".gbg", "fleet"), joinpath(homedir(), ".gbg", "dev")), line in (isfile(file) ? readlines(file) : String[])
        p = strip(line); isempty(p) || startswith(p, "#") || push!(out, p)
    end
    return unique(out)
end

"""
    scan(root; github = false, io = stdout) -> Int

Scans the repository at `root` and prints each finding on a line of its own, then what was read and
what could not be.

# Arguments

- `root` — the repository.
- `github` — whether the GitHub side is read too.
- `io` — where it prints.

Returns 0 when nothing was found, 1 when something was, 2 when it could not read the repository.
"""
function scan(root::AbstractString; github::Bool = false, io::IO = stdout)
    # A config that cannot be read stops this repository's scan, not the others of `--all` (review).
    name = basename(rstrip(root, '/'))
    cfg, result = try
        c = isfile(joinpath(root, ".gbg", "config.jl")) ? ConfigIO.read_config(root) : Model.Config(package = name, tool = :dev)
        c, Publication.scan(root, c; github, io)
    catch e
        # a config error quotes the line it could not read, which may be what the scan exists to keep in
        why = e isa ConfigIO.ConfigError ? "its .gbg/config.jl does not read; run `gbg check` there" :
                                           replace(sprint(showerror, e), '\n' => ' ')
        println(io, MARK, " ", name, ": cannot read it — ", why); return 2
    end
    println(io, MARK, " ", cfg.package, ": ", length(result.findings), " finding(s)")
    # The count first, by rule and by file, so a long list is read in its shape before its lines; every
    # line still follows, since a list cut short is reported as covered while half of it survives.
    byrule = Dict{Symbol,Int}(); byfile = Dict{String,Int}()
    for f in result.findings
        byrule[f.rule] = get(byrule, f.rule, 0) + 1
        m = match(r"^commit \S+ (.+):\d+$", f.place)
        key = m === nothing ? f.place : m.captures[1]
        byfile[key] = get(byfile, key, 0) + 1
    end
    for (r, n) in sort!(collect(byrule); by = last, rev = true); println(io, MARK, "   ", lpad(n, 5), "  ", r); end
    for (k, n) in sort!(collect(byfile); by = last, rev = true); println(io, MARK, "   ", lpad(n, 5), "  in ", k); end
    for f in sort(result.findings; by = f -> (String(f.rule), f.place))
        println(io, MARK, "   ", f.rule, isempty(f.detail) ? "" : " (" * f.detail * ")", "  ", f.place,
                isempty(f.fingerprint) ? "" : "  [" * f.fingerprint * "]")
    end
    println(io, MARK, "   read: ", join(result.read, "; "))
    for m in result.missed; println(io, MARK, "   NOT READ: ", m); end
    return isempty(result.findings) ? 0 : 1
end

function cmd_leak(args)
    o = parse_options(args)
    rs = roots("all" in o.flags)
    isempty(rs) && return 2
    codes = [scan(r; github = "github" in o.flags) for r in rs]
    return any(==(2), codes) ? 2 : any(==(1), codes) ? 1 : 0
end
VERBS["leak"] = cmd_leak

end # module Leak
