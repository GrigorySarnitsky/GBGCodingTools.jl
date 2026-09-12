# Preflight.jl — `gbg preflight <instrument>` (ARCHITECTURE D6, D7, §6.2 step 2; Revision 9): validates,
# checks, OPENS the round, copies the instrument's Workflow scripts into the project, writes the payload
# files, and prints the protocol, the exact Workflow call and the next step. It owns THE Workflow-args
# renderer; `pass open` and `round rerun` call it for their calls.

"""
    Preflight

The opener of a round and the one renderer of the args of a Workflow — the instrument's `workflow/*.js`
script, which the session running the round launches. [`Preflight.preflight`](@ref) is the verb;
[`Preflight.resolve_roster`](@ref) turns config and catalogue into the numbered hats or lanes;
[`Preflight.write_payloads`](@ref) writes every large payload as a file under the round's scratch;
[`Preflight.render_args`](@ref) builds the small args object naming those paths;
[`Preflight.workflow_call`](@ref) prints the call the session launches verbatim.
"""
module Preflight

using TOML, JSON3, Dates, SHA
using ..GBGCodingTools: GBGCodingTools, PKG_NAME, Config, Ledger, Sync, RoundFiles, Git, Doctor, TreeHash, Witnesses,
      parse_options, VERBS, tool_version, running_dev, git_stamp, self_verify, load_schema, validate, doctor

struct PreflightError <: Exception
    msg::String
end
Base.showerror(io::IO, e::PreflightError) = print(io, "preflight: ", e.msg)

const SCHEMA_VERSION = 1

# ---- paths ------------------------------------------------------------------------------------------------

scratch_dir(cfg, round) = joinpath(cfg["root"], ".gbg", "scratch", round)
workflow_dir(cfg, round) = joinpath(scratch_dir(cfg, round), "workflow")
payload_dir(cfg, round) = joinpath(workflow_dir(cfg, round), "payload")
round_dir(cfg, round) = joinpath(RoundFiles.rounds_dir(cfg), round)
instrument_dir(instrument) = joinpath(pkgdir(GBGCodingTools), "instruments", instrument)

"""
    next_round_id(cfg, instrument) -> String

`<yyyy-mm-dd>-<instrument>-<NN>`, NN the first number not yet used by a round of that instrument on
that date.
"""
function next_round_id(cfg::AbstractDict, instrument::AbstractString)
    d = Dates.format(today(), dateformat"yyyy-mm-dd")
    existing = Set(r.name for r in RoundFiles.rounds(cfg))
    n = 1
    while "$d-$instrument-$(lpad(n, 2, '0'))" in existing; n += 1; end
    return "$d-$instrument-$(lpad(n, 2, '0'))"
end

# ---- stamps -----------------------------------------------------------------------------------------------

sha_hex(s::AbstractString) = bytes2hex(sha256(codeunits(s)))
sha_files(paths) = Sync.sha_files(paths)

"""
    config_sha(cfg) -> String

The config stamp every round and pass records — [`Sync.config_sha`](@ref), the one definition.
"""
config_sha(cfg::AbstractDict) = Sync.config_sha(cfg)

"""
    catalog_sha() -> String

sha256 over every `catalog/**/*.toml` of the running copy, sorted by path.
"""
function catalog_sha()
    files = String[]
    for (d, _, fs) in walkdir(joinpath(pkgdir(GBGCodingTools), "catalog")), f in fs
        endswith(f, ".toml") && push!(files, joinpath(d, f))
    end
    return sha_files(sort!(files))
end

function seed_catalog_sha(cfg::AbstractDict)
    p = joinpath(cfg["root"], cfg["instruments"]["check-consistency"]["seed_catalog"])
    return isfile(p) ? RoundFiles.sha256_file(p) : "none"
end

const TAG_VERSION = r"^\d+\.\d+\.\d+(-rc\.\d+)?$"

"""
    tag_tree(dir, ver) -> Union{String,Nothing}

The git tree id the tag `v<ver>` of the repository `dir` points at, or `nothing` when there is no such
tag. The tree a tag names is what a round stamped with that version was measured against; the
`TreeHash` of a clean checkout of the tag equals this id.
"""
tag_tree(dir::AbstractString, ver::AbstractString) = Git.run(dir, "rev-parse", "-q", "--verify", "refs/tags/v$ver^{tree}")

"""
    data_since_tag(dir) -> Union{Nothing,String}

The released version a clean checkout past its latest tag still runs, or `nothing`. The argument `dir`
is the tool's checkout. Every commit since the latest `vX.Y.Z[-rc.N]` tag must touch only `.gbg/` —
the package's own records, never the tool's behaviour — and the tree must be clean.

`gbg release` writes the carry ledger's history line after it tags, and that commit put `HEAD` one
past the tag: while any finding was carried, the documentation round a release exists to open could
never open at it. The stamps then name the tag, its commit and its tree, exactly as on the tag itself.
"""
function data_since_tag(dir::AbstractString)
    Git.porcelain(dir) |> isempty || return nothing
    tag = Git.run(dir, "describe", "--tags", "--abbrev=0")
    (tag === nothing || !occursin(r"^v\d+\.\d+\.\d+(-rc\.\d+)?$", tag)) && return nothing
    moved = Git.run(dir, "diff", "--name-only", "$tag..HEAD", "--", ".", ":(exclude).gbg")
    return moved !== nothing && isempty(moved) ? tag[2:end] : nothing
end

"""
    stamps(cfg; record = nothing) -> Dict

The tool and config stamps every `ROUND.toml` and `pass.toml` of the consumer `cfg` records:
`tool_version` (the pinned version, or `dev+<sha>[-dirty]` from the working tree), `tool_rev`, `tool_tree_sha`,
`config_sha`, `catalog_sha`, `seed_catalog_sha`. The arguments are:

- `cfg` — the validated config of the consumer whose rounds record the stamps.
- `record` — the `ROUND.toml` of a round already open: a dev checkout whose round was stamped with a
  tag keeps reading its tool stamps from that tag while the tag exists, so the fix commits that
  move `HEAD` past the tag are not a moved tool; a moved TAG is.
"""
function stamps(cfg::AbstractDict; record = nothing)
    dir = pkgdir(GBGCodingTools)
    dev = running_dev()
    # a dev checkout sitting cleanly on a released or prerelease tag is stamped with that tag (D16): the
    # tool's own rounds open at `vX.Y.Z-rc.N` and close normally; off a tag it is `dev+<sha>[-dirty]`
    ver = nothing
    if dev
        rv = record === nothing ? "" : String(get(record, "tool_version", ""))
        if occursin(TAG_VERSION, rv) && tag_tree(dir, rv) !== nothing
            ver = rv
        else
            tag = Git.run(dir, "describe", "--exact-match", "--tags", "--dirty")
            ver = tag !== nothing && occursin(r"^v\d+\.\d+\.\d+(-rc\.\d+)?$", tag) ? tag[2:end] : data_since_tag(dir)
        end
    end
    Dict{String,Any}(
        "tool_version" => dev ? (ver === nothing ? git_stamp(dir) : ver) : String(cfg["tool"]["version"]),
        "tool_rev" => dev ? (ver === nothing ? something(Git.head(dir), "unknown") : something(Git.run(dir, "rev-parse", "-q", "--verify", "refs/tags/v$ver^{commit}"), "unknown")) :
                            "v" * String(cfg["tool"]["version"]),
        "tool_tree_sha" => (dev && ver !== nothing) ? tag_tree(dir, ver) : TreeHash.tree_hash(dir),   # the tag's tree, not the working tree's
        "config_sha" => config_sha(cfg),
        "catalog_sha" => catalog_sha(),
        "seed_catalog_sha" => seed_catalog_sha(cfg))
end

"""
    dev_round(cfg, instrument, st) -> Union{Nothing,String}

The refusal when a documentation round would open with no released instrument to name, or `nothing`
when it may open. The arguments are:

- `cfg` — the validated config.
- `instrument` — the instrument the round was asked for.
- `st` — the stamps `Preflight.stamps` computed for it.

A `/check-docs` or `/check-consistency` round is a measurement, and a `dev`-stamped round is
unclosable: a round graded by an unreleased tool compares with nothing and can be cited by no release.
That refusal belongs where it can still be acted on — the round is not opened, and nothing is spent —
rather than after the record is frozen and every verb refuses. An audit or hunt round reads
`base..HEAD` and is off-tag by construction, so it is never refused here.

The limit: this is the tool's own root, where the stamp is the working tree's. A consumer driven by
`gbg --dev` still records a `dev` stamp; `PIN.NOT_DEV` warns while it does, and `ROUND.DEV` names the
round afterwards.
"""
function dev_round(cfg::AbstractDict, instrument::AbstractString, st::AbstractDict)
    instrument in ("check-docs", "check-consistency") || return nothing
    here(x) = normpath(joinpath(abspath(String(x)), "."))       # a config root carries a trailing slash
    here(cfg["root"]) == here(pkgdir(GBGCodingTools)) || return nothing
    v = String(get(st, "tool_version", ""))
    startswith(v, "dev") || return nothing
    return "the tool root is at `$v`, which names no released instrument. A documentation round is a " *
           "measurement: one graded here compares with no other round and no release may cite it (D16). " *
           "Tag first — `gbg release <ver>-rc.<n>` — and open the round at the tag."
end

"""
    repoint_lanes(cfg, round, dest) -> String

Rewrites a round's lane args so the agents read the corpus at `dest` instead of the repository. The
arguments are `cfg`, the validated config; `round`, the round id; and `dest`, the corpus root.

Only `repo` moves: a lane's `files` are relative and identical in both trees, and every path a lane
reports is therefore a path in the real repository too. This is how a seeded documentation round shows
its readers a mutated corpus without mutating anything. Returns the args file it rewrote.
"""
function repoint_lanes(cfg::AbstractDict, round::AbstractString, dest::AbstractString)
    p = joinpath(workflow_dir(cfg, round), "main.args.json")
    a = JSON3.read(read(p, String), Dict{String,Any})
    a["repo"] = dest
    open(p, "w") do f; JSON3.pretty(f, JSON3.write(a)); println(f); end
    return p
end

# ---- substitution -----------------------------------------------------------------------------------------

function section_text(root::AbstractString, anchor::AbstractString)
    file, line, n = Config.resolve_anchor(root, anchor)
    line == 0 && return ""
    lines = readlines(joinpath(root, file))
    m = match(r"^(#{1,6})", lines[line]); level = m === nothing ? 6 : length(m.captures[1])
    out = [lines[line]]
    for l in lines[line+1:end]
        mm = match(r"^(#{1,6})\s", l)
        mm !== nothing && length(mm.captures[1]) <= level && break
        push!(out, l)
    end
    return join(out, "\n")
end

"""
    substitute(text, cfg; extra = Dict()) -> String

Fills the catalogue placeholders in `text` from `cfg`: `{package.name}`, `{package.description}`,
`{package.domain}`, `{package.terms}`, `{package.deliberate_absences}`, `{package.rulebook_sections}`,
`{policy.<file>}`, `{audit.guard_symbols}`, `{audit.invariants}`, `{hunt.entry_point}`, `{lane.<name>}`
(a per-lane value the resolver passes, never a config key), and any key of `extra`. The arguments are:

- `text` — the persona or brief.
- `cfg` — the validated config.
- `extra` — further slot values.

A placeholder with no value is left as written (a brace pair inside prose is never an error). Returns
the filled text.
"""
function substitute(text::AbstractString, cfg::AbstractDict; extra = Dict{String,String}())
    pk = cfg["package"]; root = cfg["root"]
    list(v) = isempty(v) ? "(none recorded)" : join(String.(v), "; ")
    vals = Dict{String,String}(
        "package.name" => pk["name"], "package.description" => pk["description"], "package.domain" => pk["domain"],
        "package.terms" => list(pk["terms"]), "package.deliberate_absences" => list(pk["deliberate_absences"]),
        "package.rulebook_sections" => list(pk["rulebook_sections"]),
        "audit.guard_symbols" => list(cfg["instruments"]["audit-changes"]["guard_symbols"]),
        "audit.invariants" => haskey(cfg["instruments"]["audit-changes"], "invariants_section") ? section_text(root, cfg["instruments"]["audit-changes"]["invariants_section"]) : "(no invariants section recorded)",
        "hunt.entry_point" => "src/$(pk["name"]).jl")
    merge!(vals, extra)
    return String(replace(text, r"\{(package\.[a-z_]+|policy\.[a-z0-9-]+|audit\.[a-z_]+|hunt\.[a-z_]+|lane\.[a-z_]+)\}" => function (m)
        key = m[2:end-1]
        haskey(vals, key) && return vals[key]
        if startswith(key, "policy.")
            f = joinpath(root, ".gbg", "policy", key[8:end] * ".md")
            isfile(f) && return read(f, String)
        end
        return m
    end))
end

# ---- rosters ----------------------------------------------------------------------------------------------

function hat_file(cfg, key)
    for p in (joinpath(cfg["root"], ".gbg", "hats", key * ".toml"), joinpath(pkgdir(GBGCodingTools), "catalog", "hats", key * ".toml"))
        isfile(p) && return p
    end
    throw(PreflightError("hat $key has no persona file (catalogue or .gbg/hats/)"))
end

"""
    resolve_hats(cfg; profile = nothing, explicit = String[]) -> Vector{Dict}

The check-consistency roster. The arguments are:

- `cfg` — the validated config.
- `profile` — `all`, `core` or `explicit`; the config's own when `nothing`.
- `explicit` — the hat keys an explicit profile names.

A hat — one persona of the `check-consistency` panel, bound in [`GBGCodingTools`](@ref) — carries
`key`; the persona with its placeholders filled; the four fields below; and `role`, the one-line
description from the hat's catalogue file, which nothing downstream of the roster reads.

`substrate` names the view of the corpus the hat works in — the closed set of `schema/hat.schema.json`,
two values because the panel splits the manuscript once: `full` and `siteonly` (the public pages').
What ELSE a hat is handed is `needs`, never a substrate value; the set named four more views that
narrowed nothing and no hat took. `needs` holds the
requirement tags (`html`, `git`, `rulebook`) `not_applicable` is computed from, and `not_applicable`
says the substrate cannot exist here (`html` needs with no built site, `git` with no repository,
`rulebook` with an empty rulebook, which is the rendered policy and not the consumer's sections alone).

`anchor` is whether the hat runs at full strength rather than on the economy model
(`Preflight.economy_model`); a `domain_hats`
entry may anchor any key. It is unrelated to the other two senses of the word: the `file#heading`
anchors of [`Config.resolve_anchor`](@ref), and the regular expression marking where a seed is planted
(`Seeds.select`).

Returns the list in config order.
"""
function resolve_hats(cfg::AbstractDict; profile = nothing, explicit = String[])
    cc = cfg["instruments"]["check-consistency"]
    prof = something(profile, cc["profile"])
    keys_ = prof == "core" ? cc["core"] : prof == "explicit" ? explicit : cc["hats"]
    isempty(keys_) && throw(PreflightError("profile $prof names no hats"))
    anchors = Dict(d["key"] => d for d in cc["domain_hats"])
    # A hat that NEEDS the rulebook is unusable only when the rulebook it would be handed is empty. The
    # gate tested `rulebook_sections` — the consumer's OWN extra anchored sections — though `rulebook_text`
    # renders the whole shared policy whatever that list holds, so every rulebook-needing hat silently
    # vanished from a consumer that had added no sections of its own. latex-typesetter is one: it is told
    # to read `latex-idiom.md` and treat it as authoritative, and that file is always there.
    rulebook_absent = isempty(strip(rulebook_text(cfg)))
    out = Dict{String,Any}[]
    for key in keys_
        h = TOML.parsefile(hat_file(cfg, key))
        needs = String.(get(h, "needs", String[]))
        anchor = get(h, "anchor", false) || (haskey(anchors, key) && anchors[key]["anchor"])
        substrate = haskey(anchors, key) ? anchors[key]["substrate"] : get(h, "substrate", "full")
        na = ("html" in needs && isempty(cfg["surfaces"]["built_html"])) || ("git" in needs && !Git.is_repo(cfg["root"])) ||
             ("rulebook" in needs && rulebook_absent)
        push!(out, Dict("key" => key, "substrate" => substrate, "needs" => needs, "anchor" => anchor, "not_applicable" => na,
                        "persona" => substitute(h["persona"], cfg), "role" => get(h, "role", "")))
    end
    return out
end

lane_catalog(instrument) = TOML.parsefile(joinpath(pkgdir(GBGCodingTools), "catalog", "lanes", instrument * ".toml"))

"""
    expand_globs(root, files) -> Vector{String}

`files` with every glob replaced by the files it names, in order and deduplicated. The arguments are
`root`, the consumer root, and `files`, a lane's or a territory's list.

A pattern matching nothing is KEPT as written: a directory a lane names (`catalog`, `policy`) is not a
glob, and dropping it would silently empty that lane. Both roster resolvers share this one home, because
a lane receives its files VERBATIM in its prompt — an unexpanded `src/Scans/*.jl` reaches the agent as a
pattern rather than as the files it names, and the same unexpanded string never matches the engine's own
surface list when a refinement is subtracted from it. Returns the expanded list.
"""
expand_globs(root::AbstractString, files) =
    unique!(reduce(vcat, (isempty(Config.glob_files(root, String(g))) ? [String(g)] : Config.glob_files(root, String(g)) for g in files); init = String[]))

# A cited COUNT ("the four closure channels", "eighteen schemas") and an EXIT-CODE claim ("refuses, exit
# 2"). Both read as true and are checked by nothing: the count was right when it was written, the exit code
# was the verb's before a branch moved. They are the two mechanical classes that did NOT survive being
# measured as scans (see src/Scans/id_resolves.jl for the measurement and the third class, which did), so
# they are handed to the lane as an enumerated checklist instead of being guessed at on a read-through.
const CLAIM_NUMBER = r"\b(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|hundred)[\s-]+[a-z]{3,}s\b"i
# The third alternative is this house's OWN phrasing of the contract — "the exit contract is 0 clean, 1
# substantive finding, 2 cannot evaluate, 3 crash" — which the first two miss, because they want a digit
# within two words of `exit`. src/GBGCodingTools.jl contributed ZERO checklist items until it was added,
# and the seeded `exit-code-drift` mutation was planted in exactly that line, invisible to the checklist
# built to catch it (2026-09-12-check-docs-01). The digit is REQUIRED near the phrase: `exit contract`
# alone occurs on 12 lines corpus-wide, most of them bare mentions in a list of topics, and a checklist
# padded with unverifiable items is the shape that got the quantifier class dropped as unaffordable.
const CLAIM_EXIT = r"\bexits?\s+(?:with\s+)?(?:code\s+)?[0-3]\b|\bexit\s+code\s+[0-3]\b|\bexit\s+contract\b[^.]{0,60}?[0-3]\b"i
# The QUANTIFIER class, narrowed until it was affordable. A quantifier alone matches 2526 lines of this
# corpus and was dropped as unaffordable when the checklist was built; two of the five planted seeds were
# quantifier mutations ("every" → "almost every", a deleted "never") and BOTH were missed, so the class
# that cost too much to check was also the class the round could not catch. Narrowed to a quantifier in a
# line that also names a tool identifier — where a universal is a claim ABOUT this tool and not ordinary
# prose — it is a fraction of that. The conjunction is spelled in code rather than as one regex with
# stacked lookaheads so the reader can see it is an AND.
const CLAIM_QUANTIFIER = r"\b(?:every|never|always|all|none|any|only)\b"i
const CLAIM_TOOL_ID = r"\b(?:RULE|SCAN|CFG|SELF|PIN|ROUND|EXEMPT|WIRE|MANAGED|LEG|POL|GIT|AUDIT|BUILD)\.[A-Z_]+\b|\bgbg\s+[a-z]+\b"
const CLAIM_TEXT = (".jl", ".md", ".toml", ".json", ".js", ".tmpl", ".sh", ".csv", ".seed", ".snippet", ".block", ".skeleton")

# A lane's `files` may name a directory (`catalog`, `policy`) or a build tree; the checklist is over the
# text files under them. A very large file is skipped rather than truncated: the checklist is a floor under
# the lane's reading, and a silently halved one would read as a complete list.
function checklist_files(root::AbstractString, files)
    out = String[]
    for f in files
        p = joinpath(root, f)
        if isdir(p)
            for (r, _, fs) in walkdir(p), fn in fs
                q = joinpath(r, fn)
                any(e -> endswith(fn, e), CLAIM_TEXT) && filesize(q) <= 524288 && push!(out, relpath(q, root))
            end
        elseif isfile(p) && any(e -> endswith(f, e), CLAIM_TEXT) && filesize(p) <= 524288
            push!(out, String(f))
        end
    end
    return unique!(out)
end

"""
    claim_checklist(cfg, files; range = nothing) -> Vector{String}

The mechanical floor under one check-docs lane: every cited NUMBER, every EXIT-CODE claim and every
QUANTIFIER claim found on `files`, one Markdown bullet each, tagged `count`, `exit` or `quantifier` and
carrying the file, the line and the line's text. The arguments are:

- `cfg` — the validated config.
- `files` — the lane's own surface.
- `range` — a `(first, last)` line range, for a lane holding a SLICE of one document: only the claims
  inside it are the lane's. Without it a slice lane would be handed the whole document's checklist, which
  is the payload the slicing exists to divide.

The lane discharges each item in `claims_checked[]` with a verdict and its evidence, which is what turns a
claim that reads as true into a claim someone measured. Returns the bullets, empty when the surface
carries none — a lane with an empty checklist is given no checklist file at all.
"""
function claim_checklist(cfg::AbstractDict, files; range = nothing)
    root = cfg["root"]; out = String[]
    for f in checklist_files(root, files)
        lines = try readlines(joinpath(root, f)) catch; continue end
        for (n, l) in enumerate(lines)
            range === nothing || (first(range) <= n <= last(range)) || continue
            s = strip(l)
            (isempty(s) || length(s) > 400) && continue
            ex = occursin(CLAIM_EXIT, s)
            num = occursin(CLAIM_NUMBER, s)
            # a line carrying both a cited number and a universal is tagged by the number: it is the more
            # mechanically checkable of the two, and the lane owes a verdict either way
            qu = occursin(CLAIM_QUANTIFIER, s) && occursin(CLAIM_TOOL_ID, s)
            (ex || num || qu) || continue
            push!(out, "- [" * (ex ? "exit" : num ? "count" : "quantifier") * "] `$f:$n` — " * first(s, 220))
        end
    end
    return out
end

"""
    rationale_slices(cfg, file, n) -> Vector{Tuple{Int,Int,String}}

`file` cut into `n` contiguous slices on its own top-level (`## `) headings, balanced by line count, as
`(first_line, last_line, heading_range)`. The arguments are `cfg`, the validated config; `file`, the
rationale document; and `n`, the number of slices.

One design document of several thousand lines is one lane's surface only in name: the lane that must hold
all of it holds none of it closely. Cutting on headings rather than on line counts alone keeps a slice a
readable unit, and the first slice keeps the lane key `rationale`, so a finding carried from an earlier
round still names a lane this round runs. Returns one slice when `n` is 1 or the document has too few
headings to cut.
"""
function rationale_slices(cfg::AbstractDict, file::AbstractString, n::Integer)
    lines = readlines(joinpath(cfg["root"], file)); total = length(lines)
    idx = [i for (i, l) in enumerate(lines) if startswith(l, "## ")]
    (n <= 1 || length(idx) < n) && return [(1, total, "the whole document")]
    idx[1] == 1 || pushfirst!(idx, 1)
    secs = [(idx[k], k == length(idx) ? total : idx[k + 1] - 1, strip(replace(lines[idx[k]], r"^#+\s*" => ""))) for k in eachindex(idx)]
    out = Tuple{Int,Int,String}[]; i = 1
    for k in 1:n
        i > length(secs) && break
        j = i
        if k == n
            j = length(secs)
        else
            target = round(Int, total * k / n)
            while j < length(secs) && secs[j][2] < target; j += 1; end
        end
        title = i == j ? secs[i][3] : secs[i][3] * " … " * secs[j][3]
        push!(out, (secs[i][1], secs[j][2], title))
        i = j + 1
    end
    return out
end

"""
    resolve_checkdocs_lanes(cfg) -> Vector{Dict}

The check-docs lanes, a lane being one agent's share of the round — here one surface of the corpus,
with the brief for reading it. One surface lane per non-empty surface key (`rationale`, `pages`, `src`,
`ext`, `literate`, `built-html`) carrying the catalogue's surface brief and its files, refined by
`lanes_extra` (a file named there leaves the engine's lane and joins the extra lane), then the
catalogue's cross lanes (`one-home`, `cold-reader`, `operational-claims`).

Two config values shape the roster rather than the briefs. `rationale_lanes` cuts the rationale surface
into that many lanes by [`rationale_slices`](@ref), the first keeping the key `rationale`; the rest are
`rationale-2`, `rationale-3`, and so on. `finding_cap` fills the surface brief's `{lane.cap}`: it bounds
a lane's FINDINGS, which are classes, never the sites a class names.

A glob in `lanes_extra.files` is expanded here, so a refinement written as `instruments/*/PROTOCOL.md`
both reaches its lane as real paths and is subtracted from the engine's lanes. Returns the list.
"""
function resolve_checkdocs_lanes(cfg::AbstractDict)
    cat = lane_catalog("check-docs"); sb = cat["surface"]
    cd = cfg["instruments"]["check-docs"]
    extra = cd["lanes_extra"]
    cap = string(get(cd, "finding_cap", 20))
    brief(text) = substitute(text, cfg; extra = Dict("lane.cap" => cap))
    # a glob reaches the lane as the files it names ([`expand_globs`](@ref)); `taken` then subtracts the
    # same strings the engine's own surfaces hold, which a raw glob never matched
    extra_files = Dict(e["key"] => expand_globs(cfg["root"], e["files"]) for e in extra)
    taken = Set(f for fs in values(extra_files) for f in fs)
    out = Dict{String,Any}[]
    for key in ("rationale", "pages", "src", "ext", "literate")
        files = filter(f -> !(f in taken), Config.surface_files(cfg, key))
        isempty(files) && continue
        if key == "rationale" && length(files) == 1 && get(cd, "rationale_lanes", 1) > 1
            slices = rationale_slices(cfg, first(files), get(cd, "rationale_lanes", 1))
            for (k, (a, b, title)) in enumerate(slices)
                push!(out, Dict("key" => k == 1 ? "rationale" : "rationale-$k", "kind" => "surface", "anchor" => sb["anchor"], "files" => files, "lines" => (a, b),
                                "brief" => brief(sb["brief"]) * "\n\nYOUR SURFACE IS ONE SLICE of `$(first(files))`: LINES $(a)–$(b), which are $title. Read exactly that range (`Read` with an offset and a limit) and audit only it. The rest of the document belongs to the sibling `rationale` lanes of this same round and is theirs to report — but you may READ outside your slice whenever your own sections depend on it, since a claim is judged against the whole document."))
            end
            continue
        end
        push!(out, Dict("key" => key, "kind" => "surface", "anchor" => sb["anchor"], "files" => files,
                        "brief" => brief(sb["brief"]) * "\n\nYOUR SURFACE IS THE `$key` SURFACE: the files listed in your prompt, every one read fully."))
    end
    isempty(cfg["surfaces"]["built_html"]) || push!(out, Dict("key" => "built-html", "kind" => "surface", "anchor" => sb["anchor"], "files" => [cfg["surfaces"]["built_html"]],
        "brief" => brief(sb["brief"]) * "\n\nYOUR SURFACE IS THE BUILT HTML under `$(cfg["surfaces"]["built_html"])`: what each `@docs`/`@autodocs` block actually collected is visible only here — read every API page's rendered content, and check each page blurb against what its block holds."))
    for e in extra
        push!(out, Dict("key" => e["key"], "kind" => "surface", "anchor" => sb["anchor"], "files" => extra_files[e["key"]],
                        "brief" => brief(sb["brief"]) * "\n\nYOUR SURFACE (a refinement of the engine's lanes): " * e["brief"] * "."))
    end
    for l in cat["lane"]
        push!(out, Dict("key" => l["key"], "kind" => l["kind"], "anchor" => l["anchor"], "files" => String[], "brief" => brief(l["brief"])))
    end
    return out
end

"""
    resolve_hunt_lanes(cfg) -> Vector{Dict}

The bug-hunt lanes: the config's `territories` (kind `territory`) followed by the catalogue's two free
lanes (anchored). A territory's globs are expanded ([`expand_globs`](@ref)) — a hunter is handed its
files verbatim, so `src/Scans/*.jl` must arrive as the files it names and not as the pattern. Returns
the list.
"""
function resolve_hunt_lanes(cfg::AbstractDict)
    out = Dict{String,Any}[]
    for t in cfg["instruments"]["bug-hunt"]["territories"]
        push!(out, Dict("key" => t["key"], "kind" => "territory", "anchor" => false, "files" => expand_globs(cfg["root"], t["files"]), "brief" => substitute(t["brief"], cfg)))
    end
    for l in lane_catalog("bug-hunt")["lane"]
        push!(out, Dict("key" => l["key"], "kind" => l["kind"], "anchor" => l["anchor"], "files" => String[], "brief" => substitute(l["brief"], cfg)))
    end
    return out
end

"""
    resolve_audit_lanes(cfg, kind) -> Vector{Dict}

The audit-changes lanes of the catalogue whose `kind` the round's kind selects (`code`, `prose`, or
both for `both`). Returns the list.
"""
function resolve_audit_lanes(cfg::AbstractDict, kind::AbstractString)
    out = Dict{String,Any}[]
    for l in lane_catalog("audit-changes")["lane"]
        (kind == "both" || l["kind"] == kind) || continue
        push!(out, Dict("key" => l["key"], "kind" => l["kind"], "anchor" => l["anchor"], "files" => String[], "brief" => substitute(l["brief"], cfg)))
    end
    return out
end

number!(roster) = (for (i, r) in enumerate(roster); r["nn"] = lpad(i, 2, '0'); end; roster)

"""
    resolve_roster(cfg, instrument; kw...) -> Vector{Dict}

The numbered roster of an instrument: hats for check-consistency, lanes otherwise; `nn` assigned in
order from `01`. The arguments are:

- `cfg` — the validated config.
- `instrument` — one of `check-docs`, `check-consistency`, `bug-hunt`, `audit-changes`, the four
  review procedures [`GBGCodingTools`](@ref) binds.
- `kw...` — the resolver's own keywords: `profile` and `explicit` for check-consistency's hats
  (`Preflight.resolve_hats`), `kind` for the audit's lanes.
"""
function resolve_roster(cfg::AbstractDict, instrument::AbstractString; profile = nothing, explicit = String[], kind = "both")
    roster = instrument == "check-consistency" ? resolve_hats(cfg; profile, explicit) :
             instrument == "check-docs" ? resolve_checkdocs_lanes(cfg) :
             instrument == "bug-hunt" ? resolve_hunt_lanes(cfg) : resolve_audit_lanes(cfg, kind)
    return number!(roster)
end

roster_record(roster) = [Dict{String,Any}("key" => r["key"], "anchor" => r["anchor"], "substrate" => get(r, "substrate", get(r, "kind", "")),
                                          (get(r, "not_applicable", false) ? ["not_applicable" => true] : [])...) for r in roster]

# ---- payloads and args ------------------------------------------------------------------------------------

function rulebook_text(cfg::AbstractDict)
    io = IOBuffer()
    pdir = joinpath(cfg["root"], ".gbg", "policy")
    for f in Sync.POLICY_FILES
        p = joinpath(pdir, f); isfile(p) || continue
        println(io, "--- rendered policy file $f ---\n", read(p, String), "\n")
    end
    p = joinpath(pdir, "deviations.md"); isfile(p) && println(io, "--- rendered policy file deviations.md ---\n", read(p, String), "\n")
    for a in cfg["package"]["rulebook_sections"]
        println(io, "--- rulebook section $a ---\n", section_text(cfg["root"], a), "\n")
    end
    return String(take!(io))
end

"""
    write_payloads(cfg, instrument, round, roster; base = nothing) -> Dict{String,Any}

Writes every large payload of the instrument under `.gbg/scratch/<round>/workflow/payload/`. The
arguments are:

- `cfg` — the validated config.
- `instrument` — the instrument name.
- `round` — the round id.
- `roster` — the resolved hats or lanes; each gains its `persona_path` or `brief_path`, and a check-docs
  lane whose surface carries any gains its `claims_path`.
- `base` — the audit's base commit (required for `audit-changes`).

The files: personas (`hats/<key>.md`), the rulebook (`rulebook.md`), the policy (`policy.md`), briefs
(`lanes/<key>.md`), check-docs' claim checklists (`claims/<key>.md`), the invariants
(`invariants.md`), and for the audit the diff, diffstat and claims of `base..HEAD` over the covered
paths. The manuscripts are written by `gbg round prepare`; their paths are returned here so the args
can name them. Returns the paths.
"""
function write_payloads(cfg::AbstractDict, instrument::AbstractString, round::AbstractString, roster; base = nothing)
    pd = payload_dir(cfg, round); mkpath(pd)
    paths = Dict{String,Any}()
    if instrument == "check-consistency"
        mkpath(joinpath(pd, "hats"))
        for h in roster
            p = joinpath(pd, "hats", h["key"] * ".md"); write(p, "### " * h["key"] * "\n\n" * h["persona"] * "\n"); h["persona_path"] = p
        end
        write(joinpath(pd, "rulebook.md"), rulebook_text(cfg)); paths["rulebook_path"] = joinpath(pd, "rulebook.md")
        paths["manuscripts"] = Dict("full" => joinpath(pd, "manuscript-full.md"), "siteonly" => joinpath(pd, "manuscript-siteonly.md"))
    else
        mkpath(joinpath(pd, "lanes"))
        for l in roster
            p = joinpath(pd, "lanes", l["key"] * ".md"); write(p, "### lane " * l["key"] * " (" * l["kind"] * ")\n\n" * l["brief"] * "\n"); l["brief_path"] = p
        end
    end
    if instrument == "check-docs"
        write(joinpath(pd, "policy.md"), rulebook_text(cfg)); paths["policy_path"] = joinpath(pd, "policy.md")
        # A lane whose surface carries no cited number and no exit-code claim is given NO checklist file:
        # an empty one would ask for an empty `claims_checked[]`, which reads the same as a lane that
        # skipped the step.
        mkpath(joinpath(pd, "claims"))
        for l in roster
            # the built-HTML lane's surface is GENERATED: a claim rendered there belongs to the source that
            # rendered it, and the lane owning that source already carries it
            l["key"] == "built-html" && continue
            items = claim_checklist(cfg, l["files"]; range = get(l, "lines", nothing))
            isempty(items) && continue
            p = joinpath(pd, "claims", l["key"] * ".md")
            write(p, "### claim checklist — lane " * l["key"] * " (" * string(length(items)) * " items)\n\n" *
                     "Every line below is a claim the CLI found on your surface and cannot settle. Discharge each in `claims_checked[]`.\n\n" *
                     join(items, "\n") * "\n")
            l["claims_path"] = p
        end
    end
    if instrument in ("bug-hunt", "audit-changes")
        inv = substitute("{audit.invariants}", cfg)
        write(joinpath(pd, "invariants.md"), inv); paths["invariants_path"] = joinpath(pd, "invariants.md")
    end
    if instrument == "audit-changes"
        base === nothing && throw(PreflightError("audit-changes needs --base <commit>"))
        covered = covered_paths(cfg)
        range = "$base..HEAD"
        write(joinpath(pd, "diff.patch"), Git.diff(cfg["root"], range, covered)); paths["diff_path"] = joinpath(pd, "diff.patch")
        write(joinpath(pd, "diffstat.txt"), Git.diffstat(cfg["root"], range, covered)); paths["diffstat_path"] = joinpath(pd, "diffstat.txt")
        write(joinpath(pd, "claims.txt"), Git.log(cfg["root"], range)); paths["claims_path"] = joinpath(pd, "claims.txt")
    end
    return paths
end

"""
    covered_paths(cfg) -> Vector{String}

The audit's covered paths: `src`, `test`, `ext`, `docs`, `Project.toml` plus every `[paths]` entry.
"""
covered_paths(cfg) = unique(vcat(["src", "test", "ext", "docs", "Project.toml"], String.(values(cfg["paths"]))))

"""
    audit_kind(cfg, base) -> String

`prose` when the diff touches only files of the config's rationale, page and Literate surfaces, `code`
when it touches none of them, `both` otherwise (an empty diff is `both`, so every lane runs and reports
it empty). The arguments are `cfg`, the validated config, and `base`, the commit the range starts at.
"""
function audit_kind(cfg::AbstractDict, base::AbstractString)
    changed = Git.changed_paths(cfg["root"], "$base..HEAD", covered_paths(cfg))
    isempty(changed) && return "both"
    # prose is what the config CALLS prose — its rationale, page and Literate surfaces — never a `docs/`
    # prefix: `docs/make.jl` is code, and a consumer's prose need not live under `docs/` at all. A path the
    # surfaces do not claim (a deleted file, a catalogue, a template) counts as code, the safe direction.
    prose_files = Set(vcat((Config.surface_files(cfg, k) for k in ("rationale", "pages", "literate"))...))
    prose = all(p -> p in prose_files, changed); code = all(p -> !(p in prose_files), changed)
    return prose ? "prose" : code ? "code" : "both"
end

package_block(cfg) = Dict("name" => cfg["package"]["name"], "description" => cfg["package"]["description"], "domain" => cfg["package"]["domain"],
                          "terms" => cfg["package"]["terms"], "deliberate_absences" => cfg["package"]["deliberate_absences"])
"""
    economy_model() -> String

The name of the economy model [`GBGCodingTools.Config`](@ref) defines, read from the tool's model
catalogue. Returns the model name.
"""
economy_model() = TOML.parsefile(joinpath(pkgdir(GBGCodingTools), "catalog", "models.toml"))["economy"]
finding_types(cfg) = vcat(["math", "notation", "structure", "citation", "style", "operational", "currency", "self-containment"], String.(cfg["schema"]["finding_types_extra"]))

# The reasons of the finding-scope entries that rule a finding NOT a defect, which every panel and verifier
# prompt presents as settled. A `scoped` ruling closes a real defect without a fix and is never shown:
# 26 such reasons once told every later round not to flag defects that were real.
adjudicated_titles(cfg, ledger) =
    String[e["reason"] for e in ledger if e["scope"] == "finding" && get(e, "ruling", "not-a-defect") == "not-a-defect"]

const PREAMBLES = Dict(
    "check-consistency" => "You are one hat of a fresh-eyed expert panel auditing the RENDERED documentation of the Julia package {package.name} — {package.description}. The package's field is {package.domain}; its terms of art are {package.terms}.",
    "check-docs" => "You are one lane of the complete documentation-quality battery over the SOURCE of the Julia package {package.name} — {package.description}. The package's field is {package.domain}; its terms of art are {package.terms}.",
    "bug-hunt" => "You are one lane of a bug hunt over the Julia package {package.name} — {package.description} (field: {package.domain}). A static claim about code is a hypothesis; the only admissible evidence is a program that fails.",
)

"""
    render_args(cfg, instrument, round, roster, paths; strength, cost, opened, base, head, kind, ledger) -> Dict

The Workflow args of the instrument's main script (its `schema.json` `args`): small scalars and the
payload paths, never a payload. The arguments are:

- `cfg` — the validated config.
- `instrument` — the instrument name.
- `round` — the round id.
- `roster` — the resolved hats or lanes with their payload paths.
- `paths` — the payload paths [`write_payloads`](@ref) returned.
- `strength` — `economy` or `full`, which alone decides whether a lane or hat that is not an anchor
  runs on the economy model (`Preflight.economy_model`); `cost` — the config's `cost.default`, copied
  into a consistency round's args and read by no script; `opened` — the round's opening timestamp.
- `base`, `head`, `kind` — the audit's commits and kind (`nothing` elsewhere).
- `ledger` — the ledger entries (the adjudicated titles come from them).

The result is validated against the schema before it is returned. Returns the args.
"""
function render_args(cfg::AbstractDict, instrument::AbstractString, round::AbstractString, roster, paths;
                     strength = "economy", cost = "economy", opened = "", base = nothing, head = nothing, kind = nothing, ledger = Ledger.read(cfg))
    root = cfg["root"]; rd = round_dir(cfg, round)
    a = Dict{String,Any}("schema_version" => SCHEMA_VERSION, "round" => round, "round_dir" => rd, "repo" => root,
                         "models" => Dict("economy" => economy_model()), "strength" => strength, "package" => package_block(cfg))
    if instrument == "check-consistency"
        a["rawhtml"] = joinpath(root, cfg["surfaces"]["built_html"])
        a["preamble"] = substitute(PREAMBLES[instrument], cfg)
        a["manuscripts"] = paths["manuscripts"]; a["rulebook_path"] = paths["rulebook_path"]
        a["hats"] = [Dict("nn" => h["nn"], "key" => h["key"], "persona_path" => h["persona_path"], "substrate" => h["substrate"], "needs" => h["needs"], "anchor" => h["anchor"]) for h in roster if !h["not_applicable"]]
        a["adjudicated_titles"] = adjudicated_titles(cfg, ledger); a["finding_types"] = finding_types(cfg); a["cost"] = cost; a["opened"] = opened
        a["finding_cap"] = get(cfg["instruments"]["check-consistency"], "finding_cap", 25)
        # The AUTHORED SOURCE a `needs: source` hat is sent to. Resolved HERE and never in the script:
        # panel.js carried `src/`, `ext/`, `docs/src/` and `docs/` as literals, which the core invariant
        # forbids, while `latex_source_globs` — validated, written by `gbg init`, documented in §5 — had
        # no reader anywhere, so a consumer naming `examples/*.jl` had its Literate surface silently never
        # read, and the hat was still required to quote findings at their source file:line
        # (2026-09-12-check-docs-01 schemas#1, and its dismissal overturned by the audit's auditor).
        globs = String.(get(cfg["instruments"]["check-consistency"], "latex_source_globs", String[]))
        a["source_globs"] = isempty(globs) ? ["src", "ext", "docs/src", "docs"] : globs
    elseif instrument == "check-docs"
        a["preamble"] = substitute(PREAMBLES[instrument], cfg); a["policy_path"] = paths["policy_path"]; a["finding_types"] = finding_types(cfg)
        a["lanes"] = [merge(Dict{String,Any}("nn" => l["nn"], "key" => l["key"], "kind" => l["kind"], "brief_path" => l["brief_path"], "files" => l["files"], "anchor" => l["anchor"]),
                            haskey(l, "claims_path") ? Dict{String,Any}("claims_path" => l["claims_path"]) : Dict{String,Any}()) for l in roster]
    elseif instrument == "bug-hunt"
        bh = cfg["instruments"]["bug-hunt"]
        a["preamble"] = substitute(PREAMBLES[instrument], cfg)
        a["lanes"] = [Dict("nn" => l["nn"], "key" => l["key"], "kind" => l["kind"], "brief_path" => l["brief_path"], "files" => l["files"], "anchor" => l["anchor"]) for l in roster]
        a["oracles"] = bh["oracles"]; a["witness_env"] = bh["witness_env"]
        a["witness_cmd"] = "julia --project=\"$(Witnesses.witness_project(root, bh["witness_env"], cfg["package"]["name"]))\" --startup-file=no"
        a["invariants_path"] = paths["invariants_path"]
        a["finding_cap"] = get(bh, "finding_cap", 6)
    else
        a["base"] = base; a["head"] = head; a["kind"] = kind; a["covered"] = covered_paths(cfg)
        a["diff_path"] = paths["diff_path"]; a["diffstat_path"] = paths["diffstat_path"]; a["claims_path"] = paths["claims_path"]
        a["lanes"] = [Dict("nn" => l["nn"], "key" => l["key"], "kind" => l["kind"], "brief_path" => l["brief_path"], "anchor" => l["anchor"]) for l in roster]
        a["finding_cap"] = get(cfg["instruments"]["audit-changes"], "finding_cap", 8)
    end
    schema = GBGCodingTools.instrument_schema(instrument)
    errs = validate(schema["properties"]["args"], a; root = schema)
    isempty(errs) || throw(PreflightError("rendered args do not validate (a tool defect):\n  " * join(errs, "\n  ")))
    return a
end

"""
    copy_scripts(cfg, instrument, round) -> String

Copies `instruments/<instrument>/workflow/*.js` of the running copy (and the verifiers and auditors a
round of that instrument may need) into `.gbg/scratch/<round>/workflow/` — V1: a Workflow `scriptPath`
must lie inside the project. The arguments are:

- `cfg` — the validated config.
- `instrument` — the instrument name.
- `round` — the round id.

Returns the directory.
"""
function copy_scripts(cfg::AbstractDict, instrument::AbstractString, round::AbstractString)
    src = joinpath(instrument_dir(instrument), "workflow"); dst = workflow_dir(cfg, round); mkpath(dst)
    for f in readdir(src)
        endswith(f, ".js") && install_script(joinpath(src, f), joinpath(dst, f))
    end
    # the verifiers and auditors of other instruments a round may need (dismissals, severity, verifiers)
    for other in ("check-consistency", "bug-hunt")
        other == instrument && continue
        for f in ("verify-act.js", "verify-state.js", "severity-recheck.js", "dismissals.js")
            p = joinpath(instrument_dir(other), "workflow", f); isfile(p) && install_script(p, joinpath(dst, f))
        end
    end
    return dst
end

"""
    install_script(src, dst) -> String

Copies the Workflow script `src` to `dst` with the shared prelude, `instruments/prelude.js`, spliced in at
its one `// gbg:prelude` line; a script without the marker is copied unchanged. A Workflow script cannot
import, so this is how the eleven scripts share their helpers (the args object, the model choice, the
scribe, the id and nonce stamps) instead of each keeping a copy that drifts. Every copy of a script into
a round or a design-check record goes through here. Throws when the marker appears more than once.
Returns `dst`.
"""
function install_script(src::AbstractString, dst::AbstractString)
    text = read(src, String)
    marker = "// gbg:prelude"
    n = length(findall(marker, text))
    n > 1 && throw(PreflightError("$src carries the prelude marker $n times"))
    if n == 1
        prelude = read(joinpath(pkgdir(GBGCodingTools), "instruments", "prelude.js"), String)
        text = replace(text, marker => rstrip(prelude); count = 1)
    end
    mkpath(dirname(dst)); write(dst, text)
    return dst
end

"""
    workflow_call(script, a) -> String

The exact text the session launches: `Workflow({scriptPath: "<script>", args: <json>})`.
"""
workflow_call(script::AbstractString, a::AbstractDict) = "Workflow({scriptPath: " * JSON3.write(script) * ", args: " * JSON3.write(a) * "})"

function save_args(cfg, round, name, a)
    p = joinpath(workflow_dir(cfg, round), name * ".args.json"); mkpath(dirname(p))
    open(p, "w") do io; JSON3.pretty(io, JSON3.write(a)); println(io); end
    return p
end

main_script(instrument) = Dict("check-consistency" => "panel.js", "check-docs" => "lanes.js", "bug-hunt" => "hunt.js", "audit-changes" => "audit.js")[instrument]

# ---- the verb ----------------------------------------------------------------------------------------------

"""
    torn_check(cfg; io = stderr) -> Bool

`CFG.TORN` as preflight and every round verb run it. The arguments are:

- `cfg` — the validated config.
- `io` — where a torn file is named.

A MANAGED file is one the tool renders into the consumer and hash-checks thereafter, edited only by
`gbg sync` ([`GBGCodingTools.Sync`](@ref)); a PINNED file is one the consumer itself owns and the tool
never renders — the config, the ledger, the seed catalogue, the sync sidecar, the hat personas, the
sub-environment manifests — but which must still never drift outside its own write path
([`Doctor.pinned_and_managed`](@ref) is the list). Returns true when neither kind is modified.
"""
function torn_check(cfg::AbstractDict; io::IO = stderr)
    checks, code = Doctor.run(cfg; only = ["CFG.TORN"], io = devnull)
    c = first(checks)
    c.status == :FAIL && println(io, "CFG.TORN: ", c.detail)
    return c.status != :FAIL
end

"""
    preflight(cfg, instrument; profile = nothing, hats = String[], strength = "economy", no_seed = false, dry = false, base = nothing, io = stdout) -> Int

`gbg preflight <instrument> [--profile all|core|explicit] [--hats a,b] [--strength full] [--no-seed] [--dry] [--base <commit>]`.
The arguments are:

- `cfg` — the validated config.
- `instrument` — one of `check-docs`, `check-consistency`, `bug-hunt`, `audit-changes`, the four
  review procedures [`GBGCodingTools`](@ref) binds.
- `profile` — the check-consistency profile (`all`, `core`, `explicit`); the config's when `nothing`.
- `hats` — the keys an explicit profile names.
- `strength` — `economy` (the default) or `full`.
- `no_seed` — open an unseeded round; it applies to check-consistency and, where the config turns
  `seed_rounds` on, to check-docs.
- `dry` — open and write nothing; print the round id and paths that would be used.
- `base` — the audit's base commit (required for `audit-changes`).
- `io` — where the protocol, the call and the next step are printed.

It runs the quick doctor set — the `QUICK` selection of [`GBGCodingTools.doctor`](@ref) — `CFG.TORN`
and `gbg self verify`; refuses (exit 2) an open round of this
instrument or an uncommitted change under a closed or abandoned round; opens the round (writes
`ROUND.toml`, never `git add`); copies the scripts and writes the payloads; prints the protocol, the
Workflow call and the next step. Returns the exit code.
"""
function preflight(cfg::AbstractDict, instrument::AbstractString; profile = nothing, hats = String[], strength = "economy",
                   no_seed::Bool = false, dry::Bool = false, base = nothing, io::IO = stdout)
    instrument in Sync.INSTRUMENTS || (println(io, "preflight: unknown instrument $instrument"); return 2)
    instrument in cfg["instruments"]["enabled"] || (println(io, "preflight: $instrument is not enabled in .gbg/config.toml"); return 2)
    root = cfg["root"]
    code = doctor(cfg, :QUICK; io)
    code == 0 || (println(io, "preflight: the quick doctor set (QUICK) failed — fix the FAIL lines above (or exempt an exemptable one)"); return 2)
    torn_check(cfg; io) || (println(io, "preflight: refused — a pinned file (one the consumer owns and the tool never renders) or a managed file (one `gbg sync` renders and hash-checks) is modified in the working tree (CFG.TORN)"); return 2)
    sv = self_verify(root; io = devnull)
    sv == 0 || (println(io, "preflight: gbg self verify exit $sv — the running copy is not the pinned one"); return 2)
    rounds = RoundFiles.rounds(cfg)
    for r in rounds
        r.state == :open && r.round["instrument"] == instrument && (println(io, "preflight: refused — $(r.name) is an open $instrument round; close or abandon it first"); return 2)
    end
    dirty = [p for (_, p) in Git.porcelain(root)]
    for r in rounds
        r.state in (:closed, :abandoned) || continue
        rel = relpath(r.dir, root)
        any(p -> startswith(p, rel * "/"), dirty) && (println(io, "preflight: refused — uncommitted change under the $(String(r.state)) round $(r.name); commit or restore it"); return 2)
    end
    if instrument == "audit-changes"
        base === nothing && (println(io, "preflight: audit-changes needs --base <commit> — the commit the norm is pinned at"); return 2)
        Git.run(root, "cat-file", "-e", base * "^{commit}") === nothing && (println(io, "preflight: --base $base is not a commit of this repository"); return 2)
    end
    refusal = dev_round(cfg, instrument, stamps(cfg))
    refusal === nothing || (println(io, "preflight: refused — ", refusal); return 2)
    round = next_round_id(cfg, instrument)
    kind = instrument == "audit-changes" ? audit_kind(cfg, base) : "both"
    roster = resolve_roster(cfg, instrument; profile, explicit = hats, kind)
    if dry
        println(io, "preflight --dry: would open $round with $(length(roster)) $(instrument == "check-consistency" ? "hats" : "lanes") (", join((r["key"] for r in roster), ", "), ")")
        println(io, "  scripts → ", workflow_dir(cfg, round)); println(io, "  payloads → ", payload_dir(cfg, round)); println(io, "  round → ", round_dir(cfg, round))
        return 0
    end
    cc = cfg["instruments"]["check-consistency"]
    dcfg = cfg["instruments"]["check-docs"]
    seeding = !no_seed && ((instrument == "check-consistency" && cc["seed_rounds"]) ||
                           (instrument == "check-docs" && get(dcfg, "seed_rounds", false)))
    seedcat = instrument == "check-docs" ? get(dcfg, "seed_catalog", ".gbg/seeds.toml") : cc["seed_catalog"]
    seeding && !isfile(joinpath(root, seedcat)) && (println(io, "preflight: seed_rounds = true but $seedcat is absent (CFG.SEEDS); --no-seed to run unseeded"); return 2)
    st = stamps(cfg)
    opened = Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS")
    head = something(Git.head(root), "0"^40)
    rd = round_dir(cfg, round); mkpath(joinpath(rd, "findings"))
    rec = merge(st, Dict{String,Any}("round" => round, "instrument" => instrument, "schema_version" => SCHEMA_VERSION, "head" => head,
        "roster" => roster_record(roster), "cost" => cfg["cost"]["default"], "strength" => strength, "hostname" => gethostname(),
        "model_hint" => economy_model(), "opened" => opened, "dead_lanes" => String[], "passes" => 0))
    instrument == "audit-changes" && (rec["base"] = something(Git.run(root, "rev-parse", base), base); rec["kind"] = kind)
    seeding && (rec["seed_salt"] = round)
    rec_errs = validate(load_schema("round"), rec)
    if !isempty(rec_errs)
        # `kind` is not a ROUND.toml field; keep it out of the marker and in args
        delete!(rec, "kind"); rec_errs = validate(load_schema("round"), rec)
        isempty(rec_errs) || (println(io, "preflight: ROUND.toml would not validate — a tool defect:\n  ", join(rec_errs, "\n  ")); return 3)
    end
    open(joinpath(rd, "ROUND.toml"), "w") do f
        println(f, "# ROUND.toml — written by gbg preflight; the CLI's marker, never edited by hand (ARCHITECTURE §6.1)")
        TOML.print(f, rec)
    end
    scripts = copy_scripts(cfg, instrument, round)
    paths = write_payloads(cfg, instrument, round, roster; base)
    a = render_args(cfg, instrument, round, roster, paths; strength, cost = cfg["cost"]["default"], opened,
                    base = get(rec, "base", nothing), head, kind)
    save_args(cfg, round, "main", a)
    println(io, read(joinpath(instrument_dir(instrument), "PROTOCOL.md"), String))
    println(io, "\n════════ ROUND OPENED: $round ════════")
    println(io, "round directory: $rd\nscripts and payloads: $scripts")
    if instrument == "check-consistency"
        println(io, "\nNEXT: gbg round prepare $round      (builds the docs under GBG_ROUND, consolidates the manuscripts", seeding ? ", plants the seeds)" : ")")
        println(io, "THEN launch the panel exactly as printed here:\n")
    elseif instrument == "check-docs"
        println(io, "\nNEXT: gbg round prepare $round      (scans, reflection checks, the build, the built-HTML scans; banks lane 00-scans", seeding ? "; plants the seeds into a disposable copy of the lane files, which the lanes read in place of the working tree)" : ")")
        println(io, "THEN launch the lanes exactly as printed here:\n")
    elseif instrument == "bug-hunt"
        println(io, "\nNEXT: launch the hunt exactly as printed here (no prepare step; the witnesses go to $rd/witnesses/):\n")
    else
        println(io, "\nkind = $kind, base = $(rec["base"]), head = $head; the diff, diffstat and claims are under $(payload_dir(cfg, round))")
        println(io, "NEXT: launch the audit exactly as printed here:\n")
    end
    println(io, workflow_call(joinpath(scripts, main_script(instrument)), a))
    println(io, "\nAFTER the Workflow returns: gbg round bank $round" * (instrument == "audit-changes" ? "   (gbg audit-changes bank $round runs the executable claims first)" : ""))
    return 0
end

function cmd_preflight(args)
    o = parse_options(args; valued = ["profile", "hats", "strength", "base"])
    isempty(o.positional) && (println(stderr, "usage: gbg preflight <instrument> [--profile all|core|explicit] [--hats a,b] [--strength full] [--no-seed] [--dry] [--base <commit>]"); return 2)
    cfg = Config.read()
    hats = haskey(o.values, "hats") ? String.(split(o.values["hats"], ',')) : String[]
    return preflight(cfg, o.positional[1]; profile = get(o.values, "profile", nothing), hats, strength = get(o.values, "strength", "economy"),
                     no_seed = "no-seed" in o.flags, dry = "dry" in o.flags, base = get(o.values, "base", nothing))
end
VERBS["preflight"] = cmd_preflight

end # module Preflight
