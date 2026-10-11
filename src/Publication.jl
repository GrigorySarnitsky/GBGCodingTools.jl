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
using ..Texts
using ..Catalogue
import Downloads, SHA, JSON3

"""
    GITLEAKS

The Gitleaks release the scan runs: its version, the SHA-256 of its Linux x86-64 archive as the release
publishes it, and where it is downloaded from. Both machines are Linux on x86-64; another platform is
refused by [`install`](@ref) rather than guessed at.
"""
const GITLEAKS = (version = "8.30.1",
                  sha256 = "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb",
                  url = "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz",
                  # its default rules, as the release's tag holds them: run with the global allowlist cut
                  # out, which skips `node_modules/`, lock files and images whatever they hold (review)
                  config_sha256 = "e163e53b9e7e8a8511e77271e2b323ed057759542a6d988258afe3a1fa329caf",
                  config_url = "https://raw.githubusercontent.com/gitleaks/gitleaks/v8.30.1/config/gitleaks.toml")

"""
    gitleaks() -> String

Where the pinned Gitleaks is installed on this machine, `~/.gbg/tools/gitleaks-<version>/gitleaks`.
Returns the path, whether or not it is there.
"""
gitleaks() = joinpath(homedir(), ".gbg", "tools", "gitleaks-" * GITLEAKS.version, "gitleaks")
defaults_file() = joinpath(dirname(gitleaks()), "gitleaks-defaults.toml")

"""
    machine_terms() -> Vector{String}

The words this machine's owner never publishes, one per line in `~/.gbg/leak-terms`. They are kept
outside every repository: a list of private words committed with a package is published with it.
Returns them; none where the file is absent.
"""
machine_terms() = (f = joinpath(homedir(), ".gbg", "leak-terms");
                   isfile(f) ? [String(strip(l)) for l in readlines(f) if !isempty(strip(l)) && !startswith(strip(l), "#")] : String[])

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
    defaults = joinpath(dir, "defaults.toml")
    try
        Downloads.download(GITLEAKS.config_url, defaults)
    catch e
        println(io, "gbg install: could not download Gitleaks' default rules: ", sprint(showerror, e)); return 2
    end
    bytes2hex(open(SHA.sha256, defaults)) == GITLEAKS.config_sha256 ||
        (println(io, "gbg install: Gitleaks' default rules are not the pinned ones; refused"); return 2)
    target = dirname(gitleaks())
    mkpath(target)
    run(`tar -xzf $archive -C $target gitleaks`)
    chmod(gitleaks(), 0o755)
    cp(defaults, defaults_file(); force = true)
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
        # a rule of paths alone is applied to every path any commit held, binary or empty, by `scan`
        isempty(p.regex) && continue
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
- `file` — the file it is in, which a switch naming files is matched against; empty where none.
- `fingerprint` — what tells this finding from another of the same rule at the same place.
- `current` — whether the default branch's files hold it still, or only the history does.
"""
Base.@kwdef struct Finding
    rule::Symbol
    detail::String = ""
    place::String
    file::String = ""
    fingerprint::String = ""
    current::Bool = false
end

"""
    ACCEPTED

Where a package records the notes its owner accepts: `.gbg/leak-accepted.txt`, one fingerprint a line,
written by `gbg leak --accept` and committed. It holds hashes alone, so it publishes nothing it names.
"""
const ACCEPTED = joinpath(".gbg", "leak-accepted.txt")

"""
    accepted(root) -> Set{String}

The fingerprints the package at `root` has accepted. The argument is `root`. Returns them; none where the
file is absent.
"""
accepted(root::AbstractString) = (f = joinpath(root, ACCEPTED);
    isfile(f) ? Set(String(strip(l)) for l in readlines(f) if occursin(r"^[0-9a-f]{16}$", strip(l))) : Set{String}())

"""
    blocking(f) -> Bool

Whether a finding must be fixed rather than accepted: its rule is in `Catalogue.Leaks.BLOCKING`. The
argument is `f`, the finding.
"""
blocking(f::Finding) = f.rule in Catalogue.Leaks.BLOCKING

const CREDENTIAL = Symbol("RULE.LEAK.CREDENTIAL")
const NEVER = Symbol("RULE.LEAK.NEVER_PUBLISHED")

# Git and Gitleaks run in an environment nothing of the user's or the scanned repository's can steer:
# no git config — a diff driver or an attributes file hid content — and no Gitleaks configuration from
# the environment, which replaced its credential rules (found in review, 2026-10-02).
# And none that points git elsewhere: `GIT_DIR` set by a hook outranks `-C`, and a replace ref shows a
# clean lookalike where GitHub publishes the commit (found in the second review).
const STEERING = ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR",
                  "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_NAMESPACE", "GIT_REPLACE_REF_BASE",
                  "GIT_CONFIG", "GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT", "GITLEAKS_CONFIG", "GITLEAKS_CONFIG_TOML")
unsteered() = Dict(k => v for (k, v) in ENV if !(k in STEERING) && !startswith(k, "GIT_CONFIG_KEY_") && !startswith(k, "GIT_CONFIG_VALUE_"))
clean(cmd) = setenv(cmd, merge(unsteered(), Dict("GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_NOSYSTEM" => "1",
                                                 "GIT_NO_REPLACE_OBJECTS" => "1")))
git(dir, args...) = read(clean(`git -C $dir $args`), String)

# The type of each object id given, in one `cat-file` rather than one per object, which in a repository
# of tens of thousands of objects is the difference between a second and minutes.
function types_of(repo, ids)
    isempty(ids) && return Dict{String,String}()
    out = read(pipeline(clean(`git -C $repo cat-file "--batch-check=%(objectname) %(objecttype)"`); stdin = IOBuffer(join(ids, '\n') * "\n")), String)
    return Dict(String(a) => String(b) for (a, b) in (split(l) for l in split(out, '\n') if length(split(l)) == 2))
end
reachable(repo, args...) = [String(first(split(l))) for l in split(git(repo, "rev-list", "--objects", args...), '\n') if !isempty(strip(l))]

# The pass a repository cannot silence. Every option below closes a way the review found: the repository
# scanned is a bare mirror, so it has no working tree whose `.gitleaksignore` Gitleaks reads whatever
# flag says otherwise; its `.gitleaks.toml` is overridden by an explicit configuration; an inline
# `gitleaks:allow` hides nothing; merges, the reflog, binary-marked and text-converted files are read.
const LOG_OPTS = "--log-opts=--all --reflog -m --text --no-textconv"

# One Gitleaks pass. `args` are its subcommand and target; `conf` its configuration; `text` its standard
# input. The report lands in a temporary directory, never in the package: its matches are redacted, and
# its author fields are not, so it is read and removed at once.
function pass(args::Vector{String}, conf::AbstractString, dir::AbstractString; text = nothing)
    report = joinpath(dir, "report-$(rand(UInt32)).json")
    ignore = mkpath(joinpath(dir, "no-ignore"))
    cmd = clean(`$(gitleaks()) $args -c $conf -i $ignore --ignore-gitleaks-allow --redact --no-banner --exit-code 0 -f json -r $report`)
    ok = success(text === nothing ? pipeline(cmd; stdout = devnull, stderr = devnull) :
                 pipeline(cmd; stdin = IOBuffer(text), stdout = devnull, stderr = devnull))
    try
        ok && isfile(report) || error("Gitleaks did not run over $(args[1])")
        return JSON3.read(read(report, String))
    finally
        rm(report; force = true)
    end
end

# Both passes over one input: Gitleaks' own rules, from its default configuration given explicitly, then
# this package's alone, where the default allowlist cannot hide a home path.
function both(args::Vector{String}, cfg, dir; text = nothing)
    defaults = joinpath(dir, "defaults.toml")
    isfile(defaults) || write(defaults, without_global_allowlist(read(defaults_file(), String)))
    own = joinpath(dir, "gbg-leak.toml"); write(own, config_toml(cfg))
    return vcat([(own = false, f = f) for f in pass(args, defaults, dir; text)],
                [(own = true, f = f) for f in pass(args, own, dir; text)])
end

# Gitleaks' default rules with the global allowlist that precedes them cut out: what it skips by path —
# dependencies, lock files, images — a published repository publishes all the same.
function without_global_allowlist(text)
    a = findfirst("\n[allowlist]", text); r = findfirst("\n[[rules]]", text)
    (a === nothing || r === nothing || first(a) > first(r)) && error("Gitleaks' default rules do not read as pinned")
    return text[1:first(a)] * text[first(r)+1:end]
end

rule_of(r) = r.own ? Symbol(String(r.f.RuleID)) : CREDENTIAL
detail_of(r) = r.own ? "" : String(r.f.RuleID)
short(sha) = first(String(sha), 8)

"""
    mirror(root, dir; github = false) -> String

A bare mirror of what is scanned: of the repository with every object it holds and a ref for each commit
only its reflog still reaches — a commit pushed and force-pushed away stays on GitHub — or of its
`origin` on GitHub, with the pull requests' refs no clone fetches.

# Arguments

- `root` — the repository.
- `dir` — the temporary directory the mirror is made in.
- `github` — whether GitHub's copy is mirrored instead.

Returns the mirror's path. A mirror has no working tree, so nothing in the repository can tell Gitleaks
to skip.
"""
function mirror(root::AbstractString, dir::AbstractString; github::Bool = false)
    path = joinpath(dir, "mirror.git")
    if github
        # GitHub's copy is fetched with the user's own git, whose credential helper reads a private
        # repository; what is then read of it is read clean.
        url = strip(git(root, "remote", "get-url", "origin"))
        user(cmd) = setenv(cmd, merge(unsteered(), Dict("GIT_NO_REPLACE_OBJECTS" => "1")))
        run(pipeline(user(`git clone -q --mirror $url $path`); stdout = devnull, stderr = devnull))
        run(pipeline(user(`git -C $path fetch -q origin "+refs/pull/*:refs/pull/*"`); stdout = devnull, stderr = devnull))
    else
        run(pipeline(clean(`git clone -q --mirror $root $path`); stdout = devnull, stderr = devnull))
        reached = Set(split(git(path, "rev-list", "--all"), '\n'))
        for (i, sha) in enumerate(unique(split(git(root, "log", "-g", "--format=%H", "--all"), '\n')))
            isempty(sha) || sha in reached ||
                success(pipeline(clean(`git -C $path update-ref refs/gbg-reflog/$i $sha`); stderr = devnull))
        end
    end
    return path
end

"""
    metadata(repo) -> Tuple{String,Vector{String}}

What a repository publishes besides its files' contents: every ref's name, every tag's message and
tagger, every commit's message, each distinct author and committer once, and every path any commit
held. The argument is `repo`, the mirror. Returns the text, one line per line read, and beside it the
place each line came from — a place that names a commit or an index, never the text read.
"""
function metadata(repo::AbstractString)
    lines = String[]; places = String[]
    add(text, place) = for l in split(text, '\n'); push!(lines, l); push!(places, place); end
    # NUL separates what git writes here: a message may hold any other character (found in review).
    # `for-each-ref` ends each record with a newline after its last NUL, and `log -z` a commit with one
    # before its message's: the newline opens the next record's first field, and is not part of it.
    fields(out, n) = (parts = split(out, '\0'); [vcat([lstrip(parts[i], '\n')], parts[i+1:i+n-1]) for i in 1:n:length(parts)-n+1])
    for (sha, name) in fields(git(repo, "for-each-ref", "--format=%(objectname)%00%(refname)%00"), 2)
        add(name, "the name of a ref pointing at " * short(sha))
    end
    # Every tag object the refs reach, a tag of a tag among them, whose inner object no ref names.
    every = reachable(repo, "--all")
    kinds = types_of(repo, every)
    for id in every
        get(kinds, id, "") == "tag" || continue
        head, msg = (parts = split(git(repo, "cat-file", "tag", id), "\n\n"; limit = 2); (parts[1], length(parts) == 2 ? parts[2] : ""))
        for line in split(head, '\n')
            startswith(line, "tagger ") && add(line[8:end], "the tagger of a tag object " * short(id))
            startswith(line, "tag ") && add(line[5:end], "the name in a tag object " * short(id))
        end
        isempty(strip(msg)) || add(msg, "the message of a tag object " * short(id))
    end
    people = Dict{String,Vector{String}}()
    for (sha, a, c, msg) in fields(git(repo, "log", "--all", "-z", "--format=%H%x00%an <%ae>%x00%cn <%ce>%x00%B"), 4)
        add(msg, "the message of commit " * short(sha))
        for who in (a, c); push!(get!(people, who, String[]), short(sha)); end
    end
    for (who, shas) in sort!(collect(people); by = first)
        add(who, "an author or committer, first in commit $(last(shas))")
    end
    return join(lines, '\n'), places
end

"""
    paths(repo) -> Vector{Tuple{String,String}}

Every path any commit of the mirror `repo` added or renamed to, with the commit that first did:
binary files, empty files and renames included, which a scan of patches never shows. Returns the pairs.
"""
function paths(repo::AbstractString)
    # NUL-separated, so a path is read as it is: git otherwise quotes one holding `"`, `\\` or a control
    # character, and a quoted path matched no rule and was printed with its private word (second review).
    # Each commit is `\x01<id>`, then its paths; a commit's first path opens with the newline after it.
    records = Tuple{String,Vector{String}}[]
    for tok in split(git(repo, "log", "--all", "-m", "-z", "--name-only", "--diff-filter=AR", "--format=%x01%H"), '\0')
        tok = startswith(tok, "\n") ? tok[2:end] : tok
        if startswith(tok, "\x01")
            push!(records, (short(tok[2:end]), String[]))
        elseif !isempty(tok) && !isempty(records)
            push!(last(records)[2], tok)
        end
    end
    first_seen = Dict{String,String}()
    for (sha, ps) in reverse(records), p in ps        # oldest first, so the first commit is kept
        haskey(first_seen, p) || (first_seen[p] = sha)
    end
    return sort!([(p, s) for (p, s) in first_seen])
end

"""
    loose_blobs(repo, dir) -> Vector{Tuple{String,String}}

Every blob a ref of the mirror `repo` reaches and no commit's tree does — a tag pointing straight at a
blob — written into `dir`, one file per blob, named by its id. Returns the pairs of file and blob id; a
scan of commits never reads these.
"""
function loose_blobs(repo::AbstractString, dir::AbstractString)
    # A blob a ref reaches and no commit's tree does — a tag of a blob, of a tree — is published and read
    # by no scan of commits. One nothing reaches was never pushed, and is not published.
    commits = git(repo, "rev-list", "--all")
    walked = read(pipeline(clean(`git -C $repo rev-list --objects --stdin`); stdin = IOBuffer(commits)), String)
    held = Set(String(first(split(l))) for l in split(walked, '\n') if !isempty(strip(l)))
    candidates = sort!(collect(setdiff(Set(reachable(repo, "--all")), held)))
    kinds = types_of(repo, candidates)
    out = Tuple{String,String}[]
    for id in candidates
        get(kinds, id, "") == "blob" || continue
        file = joinpath(mkpath(joinpath(dir, "blobs")), id)
        write(file, read(clean(`git -C $repo cat-file blob $id`)))
        push!(out, (file, id))
    end
    return out
end

"""
    github(root; io = stdout) -> Tuple{String,Vector{String},Vector{String},Int}

What the repository's GitHub side publishes outside git, read through `gh`: every issue's and pull
request's title and text, every comment on them, on a pull request's code and on a commit, every review's
text, every release's notes, and every workflow run's log still kept.

# Arguments

- `root` — the repository, whose `origin` names it on GitHub.
- `io` — where progress goes.

Returns the text, the place of each line, what could not be read, said rather than skipped in silence,
and how many logs GitHub refused, which leaves the pass incomplete.
"""
function github(root::AbstractString; io::IO = stdout)
    url = strip(git(root, "remote", "get-url", "origin"))
    m = match(r"github\.com[:/]([^/]+/[^/]+?)(?:\.git)?$", url)
    m === nothing && error("origin is not a GitHub repository: the GitHub side cannot be read")
    slug = m.captures[1]
    lines = String[]; places = String[]
    missed = ["the wiki, the description and topics, release assets, workflow artifacts, discussions and edit history: not read"]
    add(text, place) = for l in split(text, '\n'); push!(lines, l); push!(places, place); end
    api(path, jq) = readlines(`gh api --paginate $path --jq $jq`)
    for row in api("repos/$slug/issues?state=all&per_page=100", ".[] | [(.number|tostring), ((.title // \"\") + \"\\n\" + (.body // \"\"))] | @json")
        n, t = JSON3.read(row); add(t, "issue or pull request #" * n)
        for r in api("repos/$slug/pulls/$n/reviews?per_page=100", ".[] | (.body // \"\") | @json")
            add(JSON3.read(r), "a review of #" * n)
        end
    end
    for (path, what) in (("issues/comments", "a comment on #"), ("pulls/comments", "a review comment on #"))
        for row in api("repos/$slug/$path?per_page=100", ".[] | [((.issue_url // .pull_request_url) | split(\"/\") | last), (.body // \"\")] | @json")
            n, t = JSON3.read(row); add(t, what * n)
        end
    end
    for row in api("repos/$slug/comments?per_page=100", ".[] | [(.id|tostring), (.body // \"\")] | @json")
        n, t = JSON3.read(row); add(t, "commit comment " * n)
    end
    for row in api("repos/$slug/releases?per_page=100", ".[] | [(.id|tostring), ((.name // \"\") + \"\\n\" + (.body // \"\"))] | @json")
        id, t = JSON3.read(row); add(t, "the notes of release id " * id)
    end
    runs = api("repos/$slug/actions/runs?per_page=100", ".workflow_runs[] | .id | tostring")
    println(io, "gbg leak: reading ", length(runs), " workflow run log(s) of ", slug)
    dir = mktempdir(; cleanup = true)
    # Four at a time, each refusal waited out: eight at a time ran into GitHub's rate limit, and a refused
    # log was reported as one no longer kept, so every pass read a different part of the logs and called
    # itself complete (GBGPeriodicFields, 2026-10-11).
    # Once one log is refused after every wait, the rest are not tried: the pass is incomplete either way,
    # and trying them all would take a day and keep the limit hit (review, 2026-10-11).
    given_up = Threads.Atomic{Bool}(false)
    logs = asyncmap(runs; ntasks = 4) do id
        given_up[] && return (id, :refused, "")
        zip = joinpath(dir, id * ".zip")
        status = fetch_log(slug, id, zip)
        status === :refused && (given_up[] = true)
        status === :read || return (id, status, "")
        out = IOBuffer()
        # an archive that does not unpack is a log not read, never one no longer kept
        unpacked = success(pipeline(`unzip -p $zip`; stdout = out, stderr = devnull))
        rm(zip; force = true)
        text = String(take!(out))
        return unpacked ? (id, isempty(text) ? :expired : :read, text) : (id, :refused, "")
    end
    refused = String[]
    for (id, status, text) in logs
        status === :read    ? add(text, "the log of workflow run " * id) :
        status === :expired ? push!(missed, "workflow run $id: its log is no longer kept") :
                              push!(refused, "workflow run $id: its log was refused or failed, after waiting, or not tried once another was")
    end
    append!(missed, refused)
    return join(lines, '\n'), places, missed, length(refused)
end

"""
    fetch_log(slug, id, zip; waits = (0, 30, 90, 270)) -> Symbol

One workflow run's log, downloaded into `zip`: `:read`; `:expired` when GitHub says it keeps it no longer
(404 or 410, or an empty archive); `:refused` when every attempt failed otherwise — a rate limit, a
timeout — which is a log NOT read, never one that is gone.

# Arguments

- `slug` — the repository, `owner/name`.
- `id` — the run.
- `zip` — the file the archive is written to.
- `waits` — the seconds waited before each attempt.
"""
function fetch_log(slug::AbstractString, id::AbstractString, zip::AbstractString; waits = (0, 30, 90, 270))
    for w in waits
        sleep(w)
        err = IOBuffer()
        ok = success(pipeline(`gh api repos/$slug/actions/runs/$id/logs`; stdout = zip, stderr = err))
        ok && return filesize(zip) > 0 ? :read : :expired
        occursin(r"HTTP (404|410)", String(take!(err))) && return :expired
    end
    return :refused
end

# A rule is off only by a switch naming it: an exclusion parks a module from the rulebook, and its files
# are published all the same (found in review, 2026-10-02: HT's Phenomenology).
switched_off(cfg, rule, file) = any(s -> s.target === rule &&
    (isempty(s.files) || (!isempty(file) && any(p -> Texts.glob_matches(p, file), s.files))), cfg.switches)

fingerprint(parts...) = bytes2hex(SHA.sha256(join(string.(parts), '|')))[1:16]

# The config with this machine's private words added: they are never in `.gbg/config.jl`, which is
# published, and the config's other fields are carried over by the type's own field names.
with_terms(cfg::Model.Config, terms) =
    Model.Config(; (f => (f === :leak_terms ? unique(vcat(cfg.leak_terms, terms)) : getfield(cfg, f))
                    for f in fieldnames(Model.Config))...)

"""
    scan(root, cfg; github = false, io = stdout) -> NamedTuple

Every finding of the `RULE.LEAK.*` rules in what the repository at `root` would publish.

# Arguments

- `root` — the repository.
- `cfg` — its config, which approves addresses and switches rules off; the words kept private are this
  machine's, from [`machine_terms`](@ref).
- `github` — whether GitHub's own copy is mirrored, its pull requests' refs included, and its side
  outside git read too, through the network.
- `io` — where progress goes.

Returns `(findings, read, missed, unread)`: the findings, what was read, what could not be, and how many
workflow logs GitHub refused, a pass that is no verdict while it is above zero. Writes nothing
in the repository: everything it reads is mirrored into a temporary directory first.
"""
function scan(root::AbstractString, cfg::Model.Config; github::Bool = false, io::IO = stdout)
    isfile(gitleaks()) && isfile(defaults_file()) ||
        error("Gitleaks $(GITLEAKS.version) is not installed with its pinned default rules: run `gbg install --gitleaks`")
    cfg = with_terms(cfg, machine_terms())
    dir = mktempdir(; cleanup = true)
    repo = mirror(root, dir; github)
    out = Finding[]
    # A path is printed as a place only when no rule finds anything in it: a token or an address in a
    # file's name was printed with the finding until the review (2026-10-02).
    every_path = paths(repo)
    flagged = Set{String}()
    for r in (isempty(every_path) ? [] : both(["stdin"], cfg, dir; text = join(first.(every_path), '\n')))
        1 <= r.f.StartLine <= length(every_path) || continue
        p, s = every_path[r.f.StartLine]
        push!(flagged, p)
        push!(out, Finding(; rule = rule_of(r), detail = detail_of(r), place = "a file's path, first in commit $s",
                           file = p, fingerprint = fingerprint(rule_of(r), p)))
    end
    never = Regex(Catalogue.Leaks.NEVER_FILE)
    for (p, s) in every_path
        occursin(never, p) || continue
        push!(out, Finding(; rule = NEVER, place = (p in flagged ? "a file" : p) * ", first in commit $s",
                           file = p, fingerprint = fingerprint(NEVER, p)))
    end
    label(file) = file in flagged || occursin(r"[\x00-\x1f]", file) ? "a file whose path is reported" : file
    for r in both(["git", repo, LOG_OPTS], cfg, dir)
        file = String(r.f.File)
        push!(out, Finding(; rule = rule_of(r), detail = detail_of(r),
                           place = "commit $(short(r.f.Commit)) $(label(file)):$(r.f.StartLine)", file,
                           fingerprint = fingerprint(rule_of(r), r.f.Commit, file, r.f.StartLine)))
    end
    blobs = loose_blobs(repo, dir)
    if !isempty(blobs)
        names = Dict(basename(f) => id for (f, id) in blobs)
        for r in both(["dir", joinpath(dir, "blobs")], cfg, dir)
            id = get(names, basename(String(r.f.File)), "?")
            push!(out, Finding(; rule = rule_of(r), detail = detail_of(r), place = "blob $(short(id)), held by no commit:$(r.f.StartLine)",
                               fingerprint = fingerprint(rule_of(r), id, r.f.StartLine)))
        end
    end
    # The default branch's files as they stand: a finding they still hold is the owner's to clean, and
    # one only the history holds his to accept (ruled 2026-10-02).
    head = mkpath(joinpath(dir, "head"))
    success(pipeline(clean(`git -C $repo archive HEAD`), clean(`tar -x -C $head`)))
    now_files = Set(split(git(repo, "ls-tree", "-r", "--name-only", "-z", "HEAD"), '\0'; keepempty = false))
    now_rules = Set((rule_of(r), relpath(String(r.f.File), head)) for r in both(["dir", head], cfg, dir))
    out = [Finding(; rule = f.rule, detail = f.detail, place = f.place, file = f.file, fingerprint = f.fingerprint,
                   current = !isempty(f.file) && (f.file in now_files) &&
                             (startswith(f.place, "commit ") ? (f.rule, f.file) in now_rules : true))
           for f in out]
    text, places = metadata(repo)
    commits = count(p -> startswith(p, "the message of commit"), unique(places))
    read_what = ["every commit on every ref and in the reflog, merges and binary-marked files included",
                 "$commits commit message(s), every ref's name, every tag object's name, tagger and message, the authors and committers",
                 "$(length(every_path)) path(s), $(length(blobs)) blob(s) a ref holds and no commit does"]
    missed = String[]
    unread = 0
    github || push!(missed, "what GitHub holds and this clone lacks — pull requests' refs, branches never fetched — and the GitHub side: run with --github")
    # The GitHub side is live, not history: an issue, a comment or a log can be edited or deleted before the
    # repository turns public, so what it holds is the current tier's, never accepted (review, 2026-10-09).
    sources = [(text, places, false)]
    if github
        gtext, gplaces, gmissed, unread = Publication.github(root; io)
        append!(missed, gmissed)
        push!(sources, (gtext, gplaces, true))
        push!(read_what, "GitHub's own copy, its pull requests' refs, and its issues, pull requests, reviews, comments, releases and workflow logs")
    end
    for (t, ps, live) in sources
        isempty(strip(t)) && continue
        start = Dict{String,Int}()
        for (i, p) in enumerate(ps); haskey(start, p) || (start[p] = i); end
        for r in both(["stdin"], cfg, dir; text = t)
            n = r.f.StartLine
            place = 1 <= n <= length(ps) ? ps[n] : "line $n of what was read"
            # the line within its place tells two findings in one message apart, and does not move when
            # another commit is added (second review)
            push!(out, Finding(; rule = rule_of(r), detail = detail_of(r), place,
                               fingerprint = fingerprint(rule_of(r), place, n - get(start, place, n)), current = live))
        end
    end
    return (findings = unique(filter(f -> !switched_off(cfg, f.rule, f.file), out)), read = read_what, missed = missed,
            unread = unread)
end

end # module Publication
