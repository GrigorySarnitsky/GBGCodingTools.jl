# The design's §3.1; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Leak

`gbg leak [--all] [--github] [--accept] [--not-credential <fingerprint> --why "…"]`: the leak scan, over the package it is run in or, with `--all`, over every
package of this machine's fleet and this one. It prints its findings in the session that ran it and
writes no tracked file but `.gbg/leak-accepted.txt`, on `--accept` or `--not-credential`: a report
listing the leaks would be one. Exit 0 when nothing was found, 1 when something was, 2 when a
repository could not be read or a record was refused.
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
    scan(root; github = false, accept = false, not_credential = nothing, why = "",
         local_only = false, io = stdout) -> Int

Scans the repository at `root` and prints each finding on a line of its own, then what was read and
what could not be.

# Arguments

- `root` — the repository.
- `github` — whether the GitHub side is read too.
- `accept` — whether the notes only the history holds are recorded as accepted, in
  `.gbg/leak-accepted.txt`; a blocking finding never is.
- `not_credential` — a credential finding the owner judged false, by fingerprint, recorded with `why`;
  refused (exit 2) unless the scan reads the GitHub side and finds exactly one such finding, a
  credential the current files do not hold: neither what it matched, under any name, nor its file
  unchanged. A finding so recorded leaves the blocking tier.
- `why` — his reason: one line of at least 12 characters, holding nothing the scan reports.
- `local_only` — judges `not_credential` without the GitHub side; for this verb's self-tests only.
- `io` — where it prints.

Returns 0 when nothing new was found, 1 when something was, 2 when it could not read the repository.
"""
function scan(root::AbstractString; github::Bool = false, accept::Bool = false,
              not_credential::Union{Nothing,AbstractString} = nothing, why::AbstractString = "",
              local_only::Bool = false, io::IO = stdout)
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
    # Three tiers (the owner, 2026-10-02): a credential or a never-published file is fixed; a note the
    # current files hold is cleaned when it is cheap; a note only the history holds may be accepted.
    taken = Publication.accepted(root)
    # A credential the owner judged false is recorded with his reason, never in bulk, and only where the
    # history alone holds it: a false match in a deleted file is no reason to rewrite history, and one in
    # the current files is removed instead (GBGHomogeneousTurbulence, 2026-10-22).
    if not_credential !== nothing
        same = [f for f in result.findings if f.fingerprint == not_credential]
        reason = String(strip(why))
        problem = !(github || local_only) ? "--not-credential is judged against what GitHub holds: run it with --github" :
                  isempty(same) ? "this scan found no finding [$not_credential]" :
                  length(same) > 1 ? "[$not_credential] names $(length(same)) findings; a record names one" :
                  only(same).rule !== Publication.CREDENTIAL ? "[$not_credential] is not a credential finding; only one is recorded so" :
                  only(same).current ? "[$not_credential] is in the current files; remove it there instead" :
                  not_credential in Publication.not_credentials(root) ? "[$not_credential] is recorded already" :
                  (length(reason) < 12 || occursin(r"[\x00-\x1f\x7f]", reason) || occursin(MARK, reason)) ?
                      "--why needs the owner's reason, one line of at least 12 characters" :
                  # the reason is published with the file: a credential pasted into it would be too
                  !isempty(Publication.both(["stdin"], Publication.with_terms(cfg, Publication.machine_terms()),
                                            mktempdir(; cleanup = true); text = reason)) ?
                      "--why holds something the scan reports; write the reason without it" : nothing
        problem === nothing || (println(io, MARK, " ", cfg.package, ": not recorded — ", problem); return 2)
        file = joinpath(root, Publication.ACCEPTED)
        mkpath(dirname(file))
        # a hand-edited file may end without a newline, which would join the record to its last line
        lead = isfile(file) && filesize(file) > 0 && !endswith(read(file, String), '\n') ? "\n" : ""
        open(file, "a") do out; print(out, lead); println(out, not_credential, "  ", Publication.NOT_CREDENTIAL, reason); end
        println(io, MARK, " ", cfg.package, ": recorded [", not_credential, "] as not a credential, in ", Publication.ACCEPTED, ": commit it")
    end
    judged = Publication.not_credentials(root)
    cleared(f) = f.rule === Publication.CREDENTIAL && !f.current && f.fingerprint in judged
    fresh = [f for f in result.findings if Publication.blocking(f) ? !cleared(f) : !(f.fingerprint in taken)]
    tiers = [("BLOCKING — fix it: revoke a credential, then remove it; one the owner judges false that only the history holds is recorded with `gbg leak --github --not-credential <fingerprint> --why \"…\"`", filter(Publication.blocking, fresh)),
             ("notes in the current files — clean them when it is cheap", filter(f -> !Publication.blocking(f) && f.current, fresh)),
             ("notes only the history holds — accept them with `gbg leak --accept`", filter(f -> !Publication.blocking(f) && !f.current, fresh))]
    println(io, MARK, " ", cfg.package, ": ", length(fresh), " finding(s): ", length(tiers[1][2]), " blocking, ",
            length(tiers[2][2]), " in the current files, ", length(tiers[3][2]), " only in history; ",
            length(result.findings) - length(fresh), " accepted before")
    for (title, fs) in tiers
        isempty(fs) && continue
        println(io, MARK, " ", title, ":")
        # the count first, by rule and by file, so a long list is read in its shape before its lines;
        # every line still follows, since a list cut short is reported as covered while half survives
        byrule = Dict{Symbol,Int}(); byfile = Dict{String,Int}()
        for f in fs
            byrule[f.rule] = get(byrule, f.rule, 0) + 1
            m = match(r"^commit \S+ (.+):\d+$", f.place)
            key = m === nothing ? f.place : m.captures[1]
            byfile[key] = get(byfile, key, 0) + 1
        end
        for (r, n) in sort!(collect(byrule); by = last, rev = true); println(io, MARK, "   ", lpad(n, 5), "  ", r); end
        for (k, n) in sort!(collect(byfile); by = last, rev = true); println(io, MARK, "   ", lpad(n, 5), "  in ", k); end
        for f in sort(fs; by = f -> (String(f.rule), f.place))
            println(io, MARK, "   ", f.rule, isempty(f.detail) ? "" : " (" * f.detail * ")", "  ", f.place,
                    isempty(f.fingerprint) ? "" : "  [" * f.fingerprint * "]")
        end
    end
    if accept
        # the lines already there are kept as written, a judged credential's reason with them
        file = joinpath(root, Publication.ACCEPTED)
        kept = isfile(file) ? [String(strip(l)) for l in readlines(file) if !isempty(strip(l))] : String[]
        new = sort!([fp for fp in Set(f.fingerprint for f in tiers[3][2]) if !(fp in taken)])
        mkpath(dirname(file))
        write(file, join(vcat(kept, new), '\n') * "\n")
        println(io, MARK, "   accepted ", length(tiers[3][2]), " note(s) only the history holds, into ",
                Publication.ACCEPTED, " (", length(kept) + length(new), " in all): commit it")
        fresh = vcat(tiers[1][2], tiers[2][2])
    end
    println(io, MARK, "   read: ", join(result.read, "; "))
    for m in result.missed; println(io, MARK, "   NOT READ: ", m); end
    # A log GitHub refused is one not read: the scan is no verdict then, clean or not (2026-10-11).
    if result.unread > 0
        println(io, MARK, " INCOMPLETE: ", result.unread, " workflow log(s) were not read — GitHub refused them or the download failed,",
                " after waiting; this pass says nothing of them. Run it again later; `gh api rate_limit` shows when the limit resets.")
        return 2
    end
    return isempty(fresh) ? 0 : 1
end

function cmd_leak(args)
    o = parse_options(args; valued = ["not-credential", "why"])
    rs = roots("all" in o.flags)
    isempty(rs) && return 2
    marked = get(o.values, "not-credential", nothing)
    marked === nothing && haskey(o.values, "why") && (println(stderr, "gbg leak: --why goes with --not-credential <fingerprint>"); return 2)
    marked !== nothing && length(rs) != 1 && (println(stderr, "gbg leak: --not-credential names one package's finding; run it there, without --all"); return 2)
    codes = [scan(r; github = "github" in o.flags, accept = "accept" in o.flags, not_credential = marked,
                  why = get(o.values, "why", "")) for r in rs]
    return any(==(2), codes) ? 2 : any(==(1), codes) ? 1 : 0
end
VERBS["leak"] = cmd_leak

end # module Leak
