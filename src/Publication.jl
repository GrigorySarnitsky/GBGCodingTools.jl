# The design's §3.1; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Publication

The leak scan's engine: what a repository would publish if it were made public, read whole, and the
`RULE.LEAK.*` rules applied to it. Nothing in a build, a test or a hook calls it — it reads git and, on
a flag, the network — so it sits above `Engine`, which must answer alike on a fresh clone and on CI.

- [`install`](@ref) — the pinned Gitleaks, checked against its published checksum.
- [`scan`](@ref) — every commit on every branch and tag, the commit metadata, and on a flag the GitHub
  side, through two passes: Gitleaks' own credential rules, then this package's rules alone.
- [`config_toml`](@ref) — this package's rules as Gitleaks reads them, rendered from their values.

A finding names its rule, its place and a fingerprint, never the text it matched.
"""
module Publication

using ..Model
using ..Catalogue
using ..Engine
import Downloads, SHA, JSON3

"""
    GITLEAKS

The Gitleaks release the scan runs: its version, the SHA-256 of its Linux x86-64 archive as the release
publishes it, and where it is downloaded from. Both machines are Linux on x86-64; another platform is
refused by [`install`](@ref) rather than guessed at.
"""
const GITLEAKS = (version = "8.30.1",
                  sha256 = "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb",
                  url = "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz")

"""
    gitleaks() -> String

Where the pinned Gitleaks is installed on this machine, `~/.gbg/tools/gitleaks-<version>/gitleaks`.
Returns the path, whether or not it is there.
"""
gitleaks() = joinpath(homedir(), ".gbg", "tools", "gitleaks-" * GITLEAKS.version, "gitleaks")

"""
    install(; io = stdout) -> Int

Downloads the pinned Gitleaks, refuses it unless its SHA-256 is the one the release publishes, and puts
it where [`gitleaks`](@ref) says.

# Arguments

- `io` — where it reports.

Returns 0 when it is installed, 2 when the platform is not Linux on x86-64, the download fails, or the
checksum differs.
"""
function install(; io::IO = stdout)
    (Sys.islinux() && Sys.ARCH === :x86_64) ||
        (println(io, "gbg install: the pinned Gitleaks is for Linux on x86-64, not this machine"); return 2)
    dir = mktempdir(; cleanup = true)
    archive = joinpath(dir, "gitleaks.tar.gz")
    try
        Downloads.download(GITLEAKS.url, archive)
    catch e
        println(io, "gbg install: could not download Gitleaks ", GITLEAKS.version, ": ", sprint(showerror, e)); return 2
    end
    got = bytes2hex(open(SHA.sha256, archive))
    got == GITLEAKS.sha256 ||
        (println(io, "gbg install: Gitleaks' archive has SHA-256 ", got, ", not the published ", GITLEAKS.sha256, "; refused"); return 2)
    target = dirname(gitleaks())
    mkpath(target)
    run(`tar -xzf $archive -C $target gitleaks`)
    chmod(gitleaks(), 0o755)
    println(io, "gbg install: Gitleaks ", GITLEAKS.version, " at ", gitleaks(), ", its checksum verified")
    return 0
end

"""
    config_toml(cfg) -> String

This package's `RULE.LEAK.*` rules as a Gitleaks configuration: one `[[rules]]` table per pattern
`Catalogue.Leaks.patterns` gives for the package, with the matches it allows. The argument is
`cfg`, the package's config. Returns the text. It does not extend Gitleaks' own rules: those run in a
pass of their own, whose global allowlist would otherwise hide a home path on purpose.
"""
function config_toml(cfg::Model.Config)
    io = IOBuffer()
    println(io, "# Rendered by GBGCodingTools from the RULE.LEAK.* rules; written to a temporary file per scan.")
    for p in Catalogue.Leaks.patterns(cfg)
        println(io, "\n[[rules]]\nid = \"", p.id, "\"\ndescription = \"", p.id, "\"")
        isempty(p.regex) || println(io, "regex = '''", p.regex, "'''")
        isempty(p.path) || println(io, "path = '''", p.path, "'''")
        isempty(p.allow) && continue
        println(io, "[[rules.allowlists]]\nregexTarget = \"match\"\nregexes = [", join(("'''" * a * "'''" for a in p.allow), ", "), "]")
    end
    return String(take!(io))
end

"""
    Finding

One thing a repository would publish that a rule forbids, without the thing itself.

# Fields

- `rule` — the rule's id.
- `detail` — which of Gitleaks' credential rules matched, for a credential; empty otherwise.
- `place` — where: the commit and the file's line, a commit's metadata, or a place on GitHub.
- `fingerprint` — what tells this finding from another of the same rule at the same place.
"""
Base.@kwdef struct Finding
    rule::Symbol
    detail::String = ""
    place::String
    fingerprint::String = ""
end

const CREDENTIAL = Symbol("RULE.LEAK.CREDENTIAL")

# One Gitleaks pass. `args` are its subcommand and options; `text` goes to its standard input. The report
# lands in a temporary file, never in the package, and every finding in it is redacted.
function pass(args::Vector{String}, dir::AbstractString; text = nothing)
    report = joinpath(dir, "report-$(rand(UInt32)).json")
    cmd = `$(gitleaks()) $args --redact --no-banner --exit-code 0 -f json -r $report`
    ok = success(text === nothing ? pipeline(cmd; stdout = devnull, stderr = devnull) :
                 pipeline(cmd; stdin = IOBuffer(text), stdout = devnull, stderr = devnull))
    ok && isfile(report) || error("Gitleaks did not run: $(join(args, ' '))")
    found = JSON3.read(read(report, String))
    rm(report; force = true)
    return found
end

# Both passes over one input: Gitleaks' own rules, then this package's alone.
function both(args::Vector{String}, cfg, dir; text = nothing)
    conf = joinpath(dir, "gbg-leak.toml")
    write(conf, config_toml(cfg))
    return vcat([(own = false, f = f) for f in pass(args, dir; text)],
                [(own = true, f = f) for f in pass(vcat(args, ["-c", conf]), dir; text)])
end

rule_of(r) = r.own ? Symbol(String(r.f.RuleID)) : CREDENTIAL
detail_of(r) = r.own ? "" : String(r.f.RuleID)

"""
    metadata(root) -> Tuple{String,Vector{String}}

What a repository publishes besides its files: every branch's and tag's name, every tag's message, every
commit's message, and each distinct author and committer, `name <address>`, once. The argument is `root`.
Returns the text, one line per line read, and beside it the place each line came from.
"""
function metadata(root::AbstractString)
    lines = String[]; places = String[]
    add(text, place) = for l in split(text, '\n'); push!(lines, l); push!(places, place); end
    git(args...) = read(`git -C $root $args`, String)
    for ref in split(git("for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes", "refs/tags"), '\n')
        isempty(ref) || add(ref, "the name of " * ref)
    end
    for entry in split(git("for-each-ref", "--format=%(refname:short)%1f%(contents)%1e", "refs/tags"), '\x1e')
        parts = split(strip(entry, '\n'), '\x1f'; limit = 2)
        length(parts) == 2 && !isempty(strip(parts[2])) && add(parts[2], "the message of tag " * parts[1])
    end
    people = Dict{String,Vector{String}}()
    for entry in split(git("log", "--all", "--format=%H%x1f%an <%ae>%x1f%cn <%ce>%x1f%B%x1e"), '\x1e')
        parts = split(strip(entry, '\n'), '\x1f'; limit = 4)
        length(parts) == 4 || continue
        sha = first(parts[1], 8)
        add(parts[4], "the message of commit " * sha)
        for who in parts[2:3]; push!(get!(people, who, String[]), sha); end
    end
    for (who, shas) in sort!(collect(people); by = first)
        add(who, "the author or committer of $(length(unique(shas))) commit(s), first $(last(shas))")
    end
    return join(lines, '\n'), places
end

"""
    github(root; io = stdout) -> Tuple{String,Vector{String},Vector{String}}

What the repository's GitHub side publishes, read through `gh`: every issue's and pull request's title
and text, every comment on them and on a pull request's code, every release's notes, and every workflow
run's log still kept.

# Arguments

- `root` — the repository, whose `origin` names it on GitHub.
- `io` — where progress goes.

Returns the text, the place of each line, and what could not be read, said rather than skipped in
silence.
"""
function github(root::AbstractString; io::IO = stdout)
    url = strip(read(`git -C $root remote get-url origin`, String))
    m = match(r"github\.com[:/]([^/]+/[^/]+?)(?:\.git)?$", url)
    m === nothing && error("origin is not a GitHub repository: the GitHub side cannot be read")
    slug = m.captures[1]
    lines = String[]; places = String[]; missed = String[]
    add(text, place) = for l in split(text, '\n'); push!(lines, l); push!(places, place); end
    api(path, jq) = readlines(`gh api --paginate $path --jq $jq`)
    for row in api("repos/$slug/issues?state=all&per_page=100", ".[] | [(.number|tostring), ((.title // \"\") + \"\\n\" + (.body // \"\"))] | @json")
        n, t = JSON3.read(row); add(t, "issue or pull request #" * n)
    end
    for (path, what) in (("issues/comments", "a comment on #"), ("pulls/comments", "a review comment on #"))
        for row in api("repos/$slug/$path?per_page=100", ".[] | [((.issue_url // .pull_request_url) | split(\"/\") | last), (.body // \"\")] | @json")
            n, t = JSON3.read(row); add(t, what * n)
        end
    end
    for row in api("repos/$slug/releases?per_page=100", ".[] | [.tag_name, ((.name // \"\") + \"\\n\" + (.body // \"\"))] | @json")
        tag, t = JSON3.read(row); add(t, "the notes of release " * tag)
    end
    runs = api("repos/$slug/actions/runs?per_page=100", ".workflow_runs[] | .id | tostring")
    println(io, "gbg leak: reading ", length(runs), " workflow run log(s) of ", slug)
    dir = mktempdir(; cleanup = true)
    for id in runs
        zip = joinpath(dir, id * ".zip")
        ok = success(pipeline(`gh api repos/$slug/actions/runs/$id/logs`; stdout = zip, stderr = devnull))
        ok || (push!(missed, "workflow run $id: its log is no longer kept"); continue)
        text = read(ignorestatus(`unzip -p $zip`), String)
        add(text, "the log of workflow run " * id)
        rm(zip; force = true)
    end
    return join(lines, '\n'), places, missed
end

"""
    scan(root, cfg; github = false, io = stdout) -> NamedTuple

Every finding of the `RULE.LEAK.*` rules in what the repository at `root` would publish.

# Arguments

- `root` — the repository.
- `cfg` — its config, which approves addresses, keeps words private and switches findings off.
- `github` — whether the GitHub side is read too, through the network.
- `io` — where progress goes.

Returns `(findings, read, missed)`: the findings, what was read, and what could not be. Writes nothing
in the repository.
"""
function scan(root::AbstractString, cfg::Model.Config; github::Bool = false, io::IO = stdout)
    isfile(gitleaks()) || error("Gitleaks $(GITLEAKS.version) is not installed: run `gbg install --gitleaks`")
    dir = mktempdir(; cleanup = true)
    out = Finding[]
    for r in both(["git", root, "--log-opts=--all"], cfg, dir)
        push!(out, Finding(; rule = rule_of(r), detail = detail_of(r),
                           place = "commit $(first(String(r.f.Commit), 8)) $(r.f.File):$(r.f.StartLine)",
                           fingerprint = String(r.f.Fingerprint)))
    end
    text, places = metadata(root)
    commits = count(p -> startswith(p, "the message of commit"), unique(places))
    read_what = ["every commit on every branch and tag, $commits commit message(s), $(count(startswith("the name of"), places)) ref name(s), the authors and committers"]
    missed = String[]
    sources = [(text, places)]
    if github
        gtext, gplaces, missed = Publication.github(root; io)
        push!(sources, (gtext, gplaces))
        push!(read_what, "the GitHub side: issues, pull requests, comments, releases, workflow logs")
    end
    for (t, ps) in sources
        isempty(strip(t)) && continue
        for r in both(["stdin"], cfg, dir; text = t)
            place = 1 <= r.f.StartLine <= length(ps) ? ps[r.f.StartLine] : "line $(r.f.StartLine) of what was read"
            push!(out, Finding(; rule = rule_of(r), detail = detail_of(r), place,
                               fingerprint = bytes2hex(SHA.sha256(string(rule_of(r), '|', place, '|', r.f.StartLine)))[1:16]))
        end
    end
    # A switch on a rule, for the package or for the files it names, is honoured as on any rule.
    keep(f) = begin
        file = occursin(r"^commit \S+ (.+):\d+$", f.place) ? match(r"^commit \S+ (.+):\d+$", f.place).captures[1] : ""
        isempty(file) ? Engine.Checks.applies(cfg, f.rule) : Engine.Checks.applies(cfg, f.rule; file)
    end
    return (findings = unique(filter(keep, out)), read = read_what, missed = missed)
end

end # module Publication
