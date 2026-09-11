# Sync.jl — `gbg sync [--check]`: every generated-managed file rendered from the pinned templates under
# the current config (ARCHITECTURE D12, D13, §4). The renderer here is the ONE renderer: `init`, `new`,
# `bump` and the doctor's MANAGED.* checks all call into it.

"""
    Sync

Renders and checks the managed footprint of a consumer — a managed file is one the tool renders into
the consumer and hash-checks thereafter, edited only by `gbg sync`, never by hand: the skill stubs, the Stop hook and its
`settings.json`, the policy copy under `.gbg/policy/`, the regressions README, the managed blocks of
`CLAUDE.md` and `.gitignore`, the tool's entries in every sub-environment `Project.toml`, the CI
fragments, and the sidecar `.gbg/managed.json`. [`Sync.plan`](@ref) computes what every managed file
must contain; [`Sync.status`](@ref) compares the tree with it; [`Sync.sync`](@ref) writes. Two of the
parts it renders are documented on their own: [`Sync.managed_block`](@ref), the managed block of
`CLAUDE.md` or `.gitignore`, and [`Sync.subenv_entries`](@ref), the tool's `[deps]`, `[sources]` and
`[compat]` entries in one sub-environment.
"""
module Sync

using TOML, SHA, JSON3, Dates
using ..GBGCodingTools: GBGCodingTools, PKG_NAME, PKG_UUID, Config, Ledger, tool_version, running_dev, parse_options, VERBS,
      load_schema, validate

const TOOL_URL = "https://github.com/GrigorySarnitsky/GBGCodingTools.jl.git"
const INSTRUMENTS = ("check-docs", "check-consistency", "bug-hunt", "audit-changes")
const SKILL_DESCRIPTION = Dict(
    "check-docs" => "Run the COMPLETE documentation-quality battery over every surface — scans, reflection checks, the build, the judgment lanes — then bank, fix, verify and close the round",
    "check-consistency" => "Fresh-eyed multi-hat panel over the rendered documentation site — consolidate, run the hats, bank, fix, verify and close the round",
    "bug-hunt" => "Static hunt, dynamic confirmation — hunters hypothesise, reproducers write failing witnesses; bank, fix, promote and close the round",
    "audit-changes" => "Were these edits justified, and did they silently change behaviour? Lanes over a diff range, the executable claims run by the CLI",
    "gbg-doctor" => "The health check of this package's tooling — config, pinned version, managed files, wiring, ledger, rounds; read-only unless run --deep",
)
const POLICY_FILES = ("00-index.md", "docs-rubric.md", "latex-idiom.md", "citations.md", "testing-protocol.md",
                      "instruments.md", "git-conventions.md", "glossary.md")

struct SyncError <: Exception
    msg::String
end
Base.showerror(io::IO, e::SyncError) = print(io, "sync: ", e.msg)

templates_dir() = joinpath(pkgdir(GBGCodingTools), "templates")
policy_dir() = joinpath(pkgdir(GBGCodingTools), "policy")
template(name::AbstractString) = read(joinpath(templates_dir(), name), String)
sha256hex(s::AbstractString) = bytes2hex(sha256(codeunits(s)))

"""
    render(text, slots) -> String

Substitutes every `{{key}}` in `text` from `slots`. A key with no value is a `SyncError`, never an
empty string. Returns the rendered text.
"""
function render(text::AbstractString, slots::AbstractDict)
    out = replace(text, r"\{\{([a-z0-9_.-]+)\}\}" => function (m)
        key = m[3:end-2]
        haskey(slots, key) || throw(SyncError("template slot {{$key}} has no value"))
        slots[key]
    end)
    return String(out)
end

"""
    pin(cfg) -> String

The pinned version as the config states it: `"1.0.0"` or the literal `"dev"`. Returns the string.
"""
pin(cfg::AbstractDict) = String(cfg["tool"]["version"])

"""
    tool_root() -> String

The root of the running copy's repository (`pkgdir(GBGCodingTools)`). Returns the absolute path.
"""
tool_root() = pkgdir(GBGCodingTools)

function package_uuid(root::AbstractString)
    p = joinpath(root, "Project.toml")
    isfile(p) || return ""
    return String(get(TOML.parsefile(p), "uuid", ""))
end

const IDENTITY_TEXT = Dict(
    "physical-meaning" => "the physical meaning — what the operation does to its object, before how it is computed",
    "estimand" => "the estimand — the quantity the operation estimates, before the estimator that computes it")
const IDENTITY_SHORT = Dict("physical-meaning" => "physical meaning", "estimand" => "estimand")
const VECTORS_TEXT = Dict(
    "component" => "component notation with index letters",
    "boldsymbol" => "bold italic `\\boldsymbol{u}`",
    "none" => "not used (the package has no vector quantities)")
const VECTORS_SHORT = Dict("component" => "component notation", "boldsymbol" => "bold italic `\\boldsymbol`", "none" => "none")
const ADMONITION_TEXT = Dict(
    "always" => "always: every `!!!` block carries a custom descriptive title",
    "load-bearing" => "load-bearing only: a `!!!` block whose content the reader must not skip carries a custom title, and a plain note may keep the default")

"""
    deviations(cfg, ledger) -> Vector{Dict}

The ledger entries that declare a deviation from the shared policy — scope `policy`, `scan`, `lint` or
`harness` — live (not expired). Returns them in file order.
"""
deviations(cfg::AbstractDict, ledger) = filter(e -> e["scope"] in ("policy", "scan", "lint", "harness") &&
                                                      !(haskey(e, "expires") && e["expires"] < today()), ledger)

"""
    slots(cfg; ledger = Ledger.read(cfg)) -> Dict{String,String}

Every slot value the templates and the policy files use. The arguments are:

- `cfg` — the validated config.
- `ledger` — the ledger entries (the declared deviations come from them).

Returns the dictionary, keyed by slot name.
"""
function slots(cfg::AbstractDict; ledger = Ledger.read(cfg))
    root = cfg["root"]; v = pin(cfg)
    devs = deviations(cfg, ledger)
    devtext = isempty(devs) ? "(none)" : join(("`$(e["id"])` on `$(e["target"])` — $(e["reason"])" for e in devs), "; ")
    allowed = String.(cfg["notation"]["mathbf_allowed"])
    Dict{String,String}(
        "tool.version" => v,
        "tool.uuid" => string(PKG_UUID),
        "tool.url" => TOOL_URL,
        "tool.banner" => "GBGCodingTools v",
        "package.name" => cfg["package"]["name"],
        "package.uuid" => package_uuid(root),
        "rubric.leading_identity" => IDENTITY_TEXT[cfg["rubric"]["leading_identity"]],
        "rubric.leading_identity.short" => IDENTITY_SHORT[cfg["rubric"]["leading_identity"]],
        "notation.vectors" => VECTORS_TEXT[cfg["notation"]["vectors"]],
        "notation.vectors.short" => VECTORS_SHORT[cfg["notation"]["vectors"]],
        "notation.mathbf_allowed" => isempty(allowed) ? "none" : join(("`" * a * "`" for a in allowed), ", "),
        "docs.admonition_titles" => ADMONITION_TEXT[cfg["docs"]["admonition_titles"]],
        "docs.build_dir" => isempty(cfg["surfaces"]["built_html"]) ? "docs/build" : cfg["surfaces"]["built_html"],
        "instruments.check-docs.argcov_policy" => cfg["instruments"]["check-docs"]["argcov_policy"],
        "deviations" => devtext,
        "sha256" => "",                      # filled per block by managed_block
    )
end

# ---- the plan --------------------------------------------------------------------------------------------

"""
    ManagedFile

One generated-managed file of the plan. The fields are:

- `path` — relative to the consumer root.
- `template` — the template it is rendered from.
- `content` — the rendered bytes.
- `mode` — the file mode (`0o755` for the hook).
"""
struct ManagedFile
    path::String
    template::String
    content::String
    mode::UInt16
end

managed_header(fmt::Symbol, name, v) = fmt == :hash ? "# gbg:managed $name v$v — rewritten by `gbg sync`; do not edit\n" :
                                        fmt == :html ? "<!-- gbg:managed $name v$v — rewritten by `gbg sync`; do not edit -->\n" : ""

"""
    render_policy(cfg, s; ledger) -> Vector{ManagedFile}

The policy copy: every `policy/*.md` with its slots substituted under a managed header, plus
`deviations.md` rendered from the ledger. The arguments are:

- `cfg` — the validated config.
- `s` — the slot values.
- `ledger` — the ledger entries.

Returns the files, paths under `.gbg/policy/`.
"""
function render_policy(cfg::AbstractDict, s::AbstractDict; ledger)
    v = pin(cfg); out = ManagedFile[]
    for f in POLICY_FILES
        body = render(read(joinpath(policy_dir(), f), String), s)
        push!(out, ManagedFile(joinpath(".gbg", "policy", f), "policy/" * f, managed_header(:html, "policy/" * f, v) * body, 0o644))
    end
    io = IOBuffer()
    print(io, managed_header(:html, "policy/deviations.md", v))
    println(io, "# Declared deviations — $(cfg["package"]["name"])\n")
    println(io, "Rendered by `gbg sync` from `.gbg/exemptions.toml`: every live entry of scope `policy`, `scan`, `lint`")
    println(io, "or `harness`. A rule listed here is disabled or refined for this package, with the reason and the date")
    println(io, "it lapses; a reading model treats the rule as the entry states it.\n")
    devs = deviations(cfg, ledger)
    if isempty(devs)
        println(io, "(none)")
    else
        for e in devs
            m = get(e, "match", nothing)
            refine = m === nothing ? "" : " — refined by " * join(("$k = `$(m[k])`" for k in sort!(collect(keys(m)))), ", ")
            println(io, "- `$(e["id"])` (scope $(e["scope"]), target `$(e["target"])`)$refine: $(e["reason"]) [recorded $(e["recorded"])",
                    haskey(e, "expires") ? ", expires $(e["expires"])]" : "]")
        end
    end
    push!(out, ManagedFile(joinpath(".gbg", "policy", "deviations.md"), "policy/deviations.md", String(take!(io)), 0o644))
    return out
end

"""
    plan(cfg; ledger = Ledger.read(cfg)) -> Vector{ManagedFile}

Every generated-managed file for a consumer: one skill stub per enabled instrument ([`GBGCodingTools`](@ref) binds the term) plus
`gbg-doctor`, `.claude/settings.json`, `.claude/hooks/queue-guard.sh`, the policy copy and
`test/regressions/README.md`. The arguments are:

- `cfg` — the validated config.
- `ledger` — the ledger entries.

The two managed blocks and the sub-environment entries are planned by [`managed_block`](@ref) and
[`subenv_entries`](@ref). Returns the list.
"""
function plan(cfg::AbstractDict; ledger = Ledger.read(cfg))
    s = slots(cfg; ledger); v = pin(cfg)
    out = ManagedFile[]
    skill = template("SKILL.md.tmpl")
    for name in vcat([i for i in INSTRUMENTS if i in cfg["instruments"]["enabled"]], ["gbg-doctor"])
        ss = merge(s, Dict("skill.name" => name, "skill.description" => SKILL_DESCRIPTION[name],
                           "skill.command" => name == "gbg-doctor" ? "gbg doctor" : "gbg preflight $name \$ARGUMENTS"))
        push!(out, ManagedFile(joinpath(".claude", "skills", name, "SKILL.md"), "SKILL.md.tmpl", render(skill, ss), 0o644))
    end
    push!(out, ManagedFile(joinpath(".claude", "settings.json"), "settings.json.tmpl", render(template("settings.json.tmpl"), s), 0o644))
    push!(out, ManagedFile(joinpath(".claude", "hooks", "queue-guard.sh"), "queue-guard.sh.tmpl", template("queue-guard.sh.tmpl"), 0o755))
    append!(out, render_policy(cfg, s; ledger))
    push!(out, ManagedFile(joinpath("test", "regressions", "README.md"), "regressions-README.md", render(template("regressions-README.md"), s), 0o644))
    return out
end

# ---- the managed blocks ----------------------------------------------------------------------------------

const BLOCKS = Dict(
    "CLAUDE.md" => (template = "claude-md.block", begin_re = r"^<!-- gbg:managed begin.*-->\s*$"m, end_line = "<!-- gbg:managed end -->"),
    ".gitignore" => (template = "gitignore.block", begin_re = r"^# gbg:managed begin.*$"m, end_line = "# gbg:managed end"),
)

"""
    managed_block(cfg, file, s) -> String

The rendered managed block for one file. The arguments are:

- `cfg` — the validated config.
- `file` — `"CLAUDE.md"` or `".gitignore"`.
- `s` — the slot values.

The `CLAUDE.md` header's `sha256` is the sha256 of the block's body lines (between the markers), so an
edited body no longer matches its header. Returns the block text ending in a newline.
"""
function managed_block(cfg::AbstractDict, file::AbstractString, s::AbstractDict)
    b = BLOCKS[file]
    ss = merge(s, Dict("sha256" => "0"^64))
    if file == "CLAUDE.md"
        ss["rubric.leading_identity"] = s["rubric.leading_identity.short"]
        ss["notation.vectors"] = s["notation.vectors.short"]
    end
    text = render(template(b.template), ss)
    lines = split(text, '\n'; keepempty = true)
    body = join(lines[2:findlast(==(b.end_line), lines)-1], "\n")
    ss["sha256"] = sha256hex(body)
    return render(template(b.template), ss)
end

"""
    split_block(text, file) -> (before, block, after)

Splits the text of `file` around its managed block; `block` is `nothing` when the file carries none
(then `before` is the whole text and `after` is empty). Returns the three strings.
"""
function split_block(text::AbstractString, file::AbstractString)
    b = BLOCKS[file]
    m = match(b.begin_re, text)
    m === nothing && return (String(text), nothing, "")
    start = m.offset
    e = findnext(b.end_line, text, start)
    e === nothing && return (String(text), nothing, "")
    stop = last(e)
    stop = min(lastindex(text), nextind(text, stop))            # include the newline after the end marker
    text[stop] == '\n' || (stop = prevind(text, stop) < stop ? last(e) : stop)
    return (String(text[1:prevind(text, start)]), String(text[start:stop]), String(text[nextind(text, stop):end]))
end

"""
    with_block(text, file, block) -> String

`text` with its managed block replaced by `block`, or the block inserted at the top when the file has
none (a blank line separates it from what follows). The arguments are:

- `text` — the file's current text.
- `file` — which block markers apply (`"CLAUDE.md"` or `".gitignore"`).
- `block` — the rendered block.

Returns the new text.
"""
function with_block(text::AbstractString, file::AbstractString, block::AbstractString)
    before, old, after = split_block(text, file)
    old === nothing && return endswith(block, "\n") ? block * (isempty(text) ? "" : "\n" * text) : block * "\n\n" * text
    return before * block * after
end

# ---- sub-environment entries -----------------------------------------------------------------------------

"""
    subenv_entries(cfg, envdir) -> Dict

The `[deps]`, `[sources]` and `[compat]` entries for the tool in the sub-environment at `envdir`
(relative to the root): pinned at a release, the https url and `rev = "v<version>"` with `[compat] =
"=<version>"`; pinned at `dev`, a `path` source resolving to the tool repository and no compat. Returns
`Dict("deps" => uuid, "sources" => Dict, "compat" => String or nothing)`.
"""
function subenv_entries(cfg::AbstractDict, envdir::AbstractString)
    v = pin(cfg)
    if v == "dev"
        # relative when the tool repository encloses the consumer (the fixture) or IS it (docs/ → ".."); a
        # dev checkout elsewhere is named absolutely rather than by a chain of "../".
        troot = abspath(tool_root()); croot = abspath(cfg["root"])
        p = (croot == troot || startswith(croot, troot * "/")) ? relpath(troot, joinpath(croot, envdir)) : troot
        return Dict("deps" => string(PKG_UUID), "sources" => Dict("path" => p), "compat" => nothing)
    end
    return Dict("deps" => string(PKG_UUID), "sources" => Dict("url" => TOOL_URL, "rev" => "v" * v), "compat" => "=" * v)
end

"""
    render_project(cfg, envdir) -> (text, changed)

The sub-environment `Project.toml` at `envdir` with the tool's entries set as [`subenv_entries`](@ref)
states, every other entry kept, sections in Pkg's order. Returns the new text and whether it differs
from the file.
"""
function render_project(cfg::AbstractDict, envdir::AbstractString)
    path = joinpath(cfg["root"], envdir, "Project.toml")
    proj = isfile(path) ? TOML.parsefile(path) : Dict{String,Any}()
    e = subenv_entries(cfg, envdir)
    get!(proj, "deps", Dict{String,Any}())[PKG_NAME] = e["deps"]
    get!(proj, "sources", Dict{String,Any}())[PKG_NAME] = e["sources"]
    if e["compat"] === nothing
        haskey(proj, "compat") && delete!(proj["compat"], PKG_NAME)
        haskey(proj, "compat") && isempty(proj["compat"]) && delete!(proj, "compat")
    else
        get!(proj, "compat", Dict{String,Any}())[PKG_NAME] = e["compat"]
    end
    io = IOBuffer()
    top = [k for k in ("name", "uuid", "authors", "version") if haskey(proj, k)]
    for k in top; TOML.print(io, Dict(k => proj[k])); end
    isempty(top) || println(io)
    for sec in vcat(["deps", "sources", "compat"], sort!([k for k in keys(proj) if !(k in ("name", "uuid", "authors", "version", "deps", "sources", "compat"))]))
        haskey(proj, sec) || continue
        println(io, "[", sec, "]")
        for k in sort!(collect(keys(proj[sec])))
            val = proj[sec][k]
            if val isa AbstractDict
                println(io, k, " = {", join(("$kk = $(repr(String(vv)))" for (kk, vv) in sort!(collect(val); by = first)), ", "), "}")
            else
                println(io, k, " = ", repr(String(val)))
            end
        end
        println(io)
    end
    text = rstrip(String(take!(io))) * "\n"
    return (text, !isfile(path) || read(path, String) != text)
end

# ---- CI fragments ----------------------------------------------------------------------------------------

"""
    fragments(snippet) -> Dict{String,String}

The three fragments of a `.snippet` template, keyed `auth`, `run`, `banner`, each a block of lines
starting at `- name:` with relative indentation. Returns the dictionary.
"""
function fragments(snippet::AbstractString)
    out = Dict{String,String}(); key = nothing; buf = String[]
    for l in split(snippet, '\n')
        m = match(r"^# gbg:fragment (\w+)", l)
        if m !== nothing
            key === nothing || (out[key] = rstrip(join(buf, "\n")))
            key = m.captures[1]; buf = String[]
        elseif key !== nothing
            push!(buf, l)
        end
    end
    key === nothing || (out[key] = rstrip(join(buf, "\n")))
    for k in ("auth", "run", "banner"); haskey(out, k) || throw(SyncError("snippet lacks the $k fragment")); end
    return out
end

step_name(block) = (m = match(r"^\s*-\s+name:\s*(.+?)\s*$"m, block); m === nothing ? "" : String(m.captures[1]))

"""
    insert_fragments(yaml, frags; run_marker) -> String

The workflow text with the three fragments placed at the fixed insertion points. The arguments are:

- `yaml` — the workflow file's text.
- `frags` — the fragments keyed `auth`, `run`, `banner`.
- `run_marker` — the regex that finds the job's build or test step.

`auth` goes first after the `actions/checkout` step, `run` in place of the build or test step (the
first step matching `run_marker`, or the one a previous sync placed), `banner` last; a fragment already
present (matched by its `- name:`) is replaced in place, so the operation is idempotent. A workflow
with no `actions/checkout` step is a `SyncError`. Returns the new text.
"""
function insert_fragments(yaml::AbstractString, frags::AbstractDict; run_marker::Regex)
    lines = String.(split(yaml, '\n'))
    ci = findfirst(l -> occursin(r"^\s*-\s+uses:\s*['\"]?actions/checkout", l), lines)
    ci === nothing && throw(SyncError("no `actions/checkout` step in the workflow; the fragments have no insertion point"))
    indent = match(r"^(\s*)-", lines[ci]).captures[1]
    isstep(l) = startswith(l, indent * "- ")
    # the steps list: from the checkout step's list start to the end of the list (a non-empty line with less indentation)
    first_step = ci
    while first_step > 1 && (isstep(lines[first_step-1]) || (startswith(lines[first_step-1], indent * " ") || isempty(strip(lines[first_step-1])))); first_step -= 1; end
    while first_step <= ci && !isstep(lines[first_step]); first_step += 1; end
    last_line = ci
    while last_line < length(lines) && (isempty(strip(lines[last_line+1])) || startswith(lines[last_line+1], indent * " ") || isstep(lines[last_line+1])); last_line += 1; end
    while last_line > ci && isempty(strip(lines[last_line])); last_line -= 1; end
    # split the list into step blocks
    starts = [i for i in first_step:last_line if isstep(lines[i])]
    blocks = [join(lines[starts[k]:(k < length(starts) ? starts[k+1]-1 : last_line)], "\n") for k in eachindex(starts)]
    blocks = [rstrip(b) for b in blocks]
    reindent(frag) = join((isempty(l) ? l : indent * l for l in split(frag, '\n')), "\n")
    names = Dict(k => step_name(v) for (k, v) in frags)
    # the run step: the first block matching the marker, else the block a previous sync already placed
    rk = something(findfirst(b -> occursin(run_marker, b), blocks), findfirst(b -> step_name(b) == names["run"], blocks), 0)
    rk == 0 && throw(SyncError("no step matches the build/test step pattern $(run_marker.pattern); cannot place the run fragment"))
    blocks[rk] = reindent(frags["run"])
    # auth and banner: any previously placed copy is dropped, then each is placed afresh
    kept = [b for b in blocks if !(step_name(b) in (names["auth"], names["banner"]))]
    ck = findfirst(b -> occursin(r"uses:\s*['\"]?actions/checkout", b), kept)
    ck === nothing && throw(SyncError("the checkout step vanished while re-placing fragments"))
    out = String[]
    for (k, b) in enumerate(kept)
        push!(out, b)
        k == ck && push!(out, reindent(frags["auth"]))
    end
    push!(out, reindent(frags["banner"]))
    new_lines = vcat(lines[1:first_step-1], split(join(out, "\n"), '\n'), lines[last_line+1:end])
    return join(new_lines, "\n")
end

const WORKFLOWS = (
    ("CI.yml", "CI.yml.snippet", r"julia-actions/julia-runtest|Pkg\.test\(\)"),
    ("docs.yml", "docs.yml.snippet", r"docs/make\.jl"),
)

"""
    render_workflows(cfg) -> Vector{Tuple{String,String,Bool}}

For each of `.github/workflows/CI.yml` and `docs.yml` that exists: its path, the text with the
fragments inserted, and whether that differs from the file. Returns the list.
"""
function render_workflows(cfg::AbstractDict)
    s = slots(cfg); out = Tuple{String,String,Bool}[]
    for (file, snippet, marker) in WORKFLOWS
        path = joinpath(cfg["root"], ".github", "workflows", file)
        isfile(path) || continue
        text = read(path, String)
        new = insert_fragments(text, fragments(render(template(snippet), s)); run_marker = marker)
        push!(out, (joinpath(".github", "workflows", file), new, new != text))
    end
    return out
end

# ---- status and sync -------------------------------------------------------------------------------------

sidecar_path(cfg) = joinpath(cfg["root"], ".gbg", "managed.json")

sha_files(paths) = sha256hex(join((isfile(p) ? read(p, String) : "" for p in paths), "\n\0"))

"""
    config_sha(cfg) -> String

sha256 over `config.toml`, `hats/*.toml` (sorted) and `exemptions.toml`, in that order; the stamp
every round records and the render input the sidecar records.
"""
function config_sha(cfg::AbstractDict)
    g = joinpath(cfg["root"], ".gbg")
    hats = isdir(joinpath(g, "hats")) ? sort!([joinpath(g, "hats", f) for f in readdir(joinpath(g, "hats")) if endswith(f, ".toml")]) : String[]
    return sha_files(vcat([joinpath(g, "config.toml")], hats, [joinpath(g, "exemptions.toml")]))
end

"""
    inputs_sha(cfg) -> String

The hash of everything a render depends on: the pinned version, [`config_sha`](@ref) (config, hats, ledger), and
the templates and policy files of the running copy. Recorded in the sidecar at render time: while it
is unchanged a fresh render equals the recorded one, so ANY divergence of a managed file is a hand
edit — MODIFIED whatever its sidecar entry says (a file and its entry edited together, attack 8.4);
when it changed, a file equal to its recorded sha is merely STALE and is re-rendered.
"""
function inputs_sha(cfg::AbstractDict)
    files = String[]
    for d in (templates_dir(), policy_dir()), f in readdir(d)
        push!(files, joinpath(d, f))
    end
    return sha256hex(pin(cfg) * "\n" * config_sha(cfg) * "\n" * sha_files(sort!(files)))
end

"""
    read_sidecar(cfg) -> Dict

`.gbg/managed.json` parsed and validated against `schema/managed.schema.json`, or an empty record when
absent. The argument is `cfg`, the validated config. Throws a [`SyncError`](@ref) on a sidecar that does
not validate, since every managed-file verdict is read from it, and the message names the entry: the
schema closed its `files` map after a release that never validated it, so a sidecar an older copy wrote
can fail here and the reader must be told which line to look at. Returns the dictionary with a `files` map.
"""
function read_sidecar(cfg::AbstractDict)
    p = sidecar_path(cfg)
    isfile(p) || return Dict{String,Any}("files" => Dict{String,Any}())
    d = JSON3.read(read(p, String), Dict{String,Any})
    errs = validate(load_schema("managed"), d)                  # the schema existed and nothing read it
    isempty(errs) || throw(SyncError("$(relpath(p, cfg["root"])) does not validate: " * join(errs, "; ") *
                                     " — a sidecar written before its schema was closed; delete it and re-run gbg sync"))
    haskey(d, "files") || (d["files"] = Dict{String,Any}())
    return d
end

"""
    Entry

One line of a sync status. The fields are:

- `path` — the managed path (a block is `<file>#gbg:managed`).
- `state` — `:OK`, `:MISSING`, `:STALE`, `:MODIFIED`, `:UNMANAGED` or `:ORPHAN`.
- `detail` — one line for the reader.
"""
struct Entry
    path::String
    state::Symbol
    detail::String
end

function classify(root, sidecar, path, fresh, inputs_same::Bool)
    full = joinpath(root, path)
    rec = get(sidecar["files"], path, nothing)
    isfile(full) || return Entry(path, :MISSING, "not rendered yet")
    cur = read(full, String)
    cur == fresh && return Entry(path, rec === nothing ? :STALE : :OK, rec === nothing ? "up to date but unrecorded in managed.json" : "")
    rec === nothing && return Entry(path, :UNMANAGED, "an unmanaged file sits at a managed path; remove it before sync renders here")
    inputs_same && return Entry(path, :MODIFIED, "edited by hand since it was rendered (the render inputs are unchanged); sync refuses to overwrite it")
    sha256hex(cur) == rec["sha256"] && return Entry(path, :STALE, "an older render (v$(rec["version"])); re-rendered")
    return Entry(path, :MODIFIED, "edited by hand since it was rendered; sync refuses to overwrite it")
end

function classify_block(root, sidecar, file, fresh, inputs_same::Bool)
    full = joinpath(root, file); key = file * "#gbg:managed"
    rec = get(sidecar["files"], key, nothing)
    isfile(full) || return Entry(key, :MISSING, "$file absent; the block is seeded with the file")
    _, old, _ = split_block(read(full, String), file)
    old === nothing && return Entry(key, :MISSING, "no managed block in $file yet")
    old == fresh && return Entry(key, rec === nothing ? :STALE : :OK, "")
    rec === nothing && return Entry(key, :UNMANAGED, "a block sits in $file that managed.json does not record")
    inputs_same && return Entry(key, :MODIFIED, "the managed block in $file was edited (the render inputs are unchanged); sync refuses to overwrite it")
    sha256hex(old) == rec["sha256"] && return Entry(key, :STALE, "an older render; re-rendered")
    return Entry(key, :MODIFIED, "the managed block in $file was edited; sync refuses to overwrite it")
end

"""
    status(cfg; ledger = Ledger.read(cfg)) -> Vector{Entry}

Compares the tree with a fresh render of every managed file and block, and lists sidecar entries whose
file is no longer planned (`ORPHAN`). The arguments are:

- `cfg` — the validated config.
- `ledger` — the ledger entries.

Returns the entries; `MANAGED.HASH` fails on any `MODIFIED` or `UNMANAGED`, `MANAGED.STALE` on any
`STALE`, `MISSING` or `ORPHAN`.
"""
function status(cfg::AbstractDict; ledger = Ledger.read(cfg))
    root = cfg["root"]; sidecar = read_sidecar(cfg); s = slots(cfg; ledger)
    inputs_same = get(sidecar, "inputs_sha", "") == inputs_sha(cfg)
    out = Entry[]
    planned = Set{String}()
    for f in plan(cfg; ledger)
        push!(planned, f.path); push!(out, classify(root, sidecar, f.path, f.content, inputs_same))
    end
    for file in ("CLAUDE.md", ".gitignore")
        push!(planned, file * "#gbg:managed"); push!(out, classify_block(root, sidecar, file, managed_block(cfg, file, s), inputs_same))
    end
    for k in sort!(collect(keys(sidecar["files"])))
        k in planned || push!(out, Entry(k, :ORPHAN, "recorded in managed.json but no longer planned by v$(pin(cfg))"))
    end
    return out
end

function write_managed(root, f::ManagedFile)
    full = joinpath(root, f.path); mkpath(dirname(full))
    write(full, f.content); chmod(full, f.mode)
end

"""
    sync(cfg; check = false, io = stdout, ledger = Ledger.read(cfg)) -> Int

`gbg sync [--check]`. The arguments are:

- `cfg` — the validated config.
- `check` — compare only, write nothing.
- `io` — where the status lines go.
- `ledger` — the ledger entries.

It renders every managed file and block, seeds `.claude/WORK_QUEUE.md` when absent, writes the tool's
entries into every sub-environment `Project.toml` that lists it, inserts the CI fragments, and
rewrites `.gbg/managed.json`; idempotent. It refuses (exit 2) on a `MODIFIED` or `UNMANAGED` file and
writes nothing then. With `check = true` the exit is 1 when anything would change, else 0. Returns the
exit code.
"""
function sync(cfg::AbstractDict; check::Bool = false, io::IO = stdout, ledger = Ledger.read(cfg))
    root = cfg["root"]
    entries = status(cfg; ledger)
    projects = [(env, render_project(cfg, env)...) for env in GBGCodingTools.tool_sub_envs(root)]
    workflows = render_workflows(cfg)
    bad = filter(e -> e.state in (:MODIFIED, :UNMANAGED), entries)
    drift = filter(e -> e.state != :OK, entries)
    for e in entries
        e.state == :OK && !check && continue
        println(io, "  ", rpad(String(e.state), 9), " ", e.path, isempty(e.detail) ? "" : "  — " * e.detail)
    end
    for (env, _, changed) in projects
        changed && println(io, "  ENTRIES   $env/Project.toml  — [deps]/[sources]/[compat] for $PKG_NAME")
    end
    for (path, _, changed) in workflows
        changed && println(io, "  FRAGMENTS $path  — auth, run and banner steps")
    end
    queue = joinpath(root, ".claude", "WORK_QUEUE.md")
    seed_queue = !isfile(queue)
    seed_queue && println(io, "  SEED      .claude/WORK_QUEUE.md  — the checklist header, once")
    if !isempty(bad)
        println(io, "sync: refused — $(length(bad)) managed file(s) edited by hand or unmanaged at a managed path; restore or remove them (the design never merges).")
        return 2
    end
    changing = !isempty(drift) || any(p -> p[3], projects) || any(w -> w[3], workflows) || seed_queue
    if check
        println(io, changing ? "sync --check: the tree is behind the render." : "sync --check: every managed file is current.")
        return changing ? 1 : 0
    end
    s = slots(cfg; ledger); v = pin(cfg)
    files = Dict{String,Any}()
    for f in plan(cfg; ledger)
        write_managed(root, f)
        files[f.path] = Dict("template" => f.template, "version" => v, "sha256" => sha256hex(f.content))
    end
    for file in ("CLAUDE.md", ".gitignore")
        full = joinpath(root, file)
        block = managed_block(cfg, file, s)
        text = isfile(full) ? read(full, String) :
               (file == "CLAUDE.md" ? render(template("CLAUDE.md.skeleton"), s) : "")
        write(full, with_block(text, file, block))
        files[file * "#gbg:managed"] = Dict("template" => BLOCKS[file].template, "version" => v, "sha256" => sha256hex(block))
    end
    for (env, text, changed) in projects
        changed && write(joinpath(root, env, "Project.toml"), text)
    end
    for (path, text, changed) in workflows
        changed && write(joinpath(root, path), text)
    end
    seed_queue && (mkpath(dirname(queue)); write(queue, template("WORK_QUEUE.md.seed")))
    mkpath(joinpath(root, ".gbg"))
    open(sidecar_path(cfg), "w") do sio
        JSON3.pretty(sio, JSON3.write(Dict("schema_version" => 1, "tool_version" => v, "inputs_sha" => inputs_sha(cfg),
                                            "rendered" => Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS"), "files" => files)))
        println(sio)
    end
    println(io, "sync: $(length(files)) managed files and blocks rendered under v$v; $(count(p -> p[3], projects)) project file(s) and $(count(w -> w[3], workflows)) workflow(s) updated.")
    return 0
end

"""
    cmd_sync(args) -> Int

`gbg sync [--check]`: the CLI face of [`Sync.sync`](@ref) over the config found from the working
directory. Returns the exit code.
"""
function cmd_sync(args)
    o = parse_options(args)
    cfg = Config.read()
    # a sidecar an older copy wrote can fail the schema this release closed; that is a refusal to name
    # and a next step to give, never a backtrace out of a verb whose whole job is to repair managed files
    try
        return sync(cfg; check = "check" in o.flags)
    catch err
        err isa SyncError || rethrow()
        println(stderr, "sync: ", sprint(showerror, err))
        return 2
    end
end
VERBS["sync"] = cmd_sync

end # module Sync
