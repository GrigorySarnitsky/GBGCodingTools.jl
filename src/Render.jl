# The design's §6; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Render

Every file that connects a package to this one, written by a Julia function.
There is no template language and no template directory: a generated file is the return value of a
function that takes the package's config, so what a package receives is decided in Julia, beside the
values it is derived from, and can be compared with what is on disk by running the function again.

That comparison is the WIRING CHECK, which every build and every test runs: a generated file that has
been hand-edited, or that a newer version of this package would write differently, is a finding rather
than a silent divergence. Regenerating is left to `gbg sync`, `gbg bump` and `gbg release`, so a build
reports drift and never repairs it.

This is the sixth module of the order: it may name `Model`, `Texts`, `Catalogue` and `ConfigIO`, and
nothing above. What it writes today is the WIRING — the ignore block, the end-of-turn hook, the settings
that install it, the regressions note — and the RULEBOOK a session loads, rendered from the rule values
themselves, so a rule cannot be reworded in the text without being reworded in the program that enforces
it. The instrument skills wait for the instruments.
"""
module Render

using TOML, JSON3

using ..Model
using ..Catalogue

# The marker a generated block carries. It is matched anywhere in the line rather than at its start,
# because the comment syntax differs by file — `#` in a shell script or a `.gitignore`, `<!-- -->` in
# Markdown — and one marker the reader recognises in every file is worth more than one parser per format.
const BEGIN_MARK = "gbg:managed begin"
const END_MARK = "gbg:managed end"

"""
    version_tag(cfg) -> String

How a generated file names the version that wrote it: `vdev` in a checkout, `v2.0.0` for a released pin.
The argument is `cfg`, the package's config. Returns the tag.
"""
version_tag(cfg::Model.Config) = cfg.tool isa VersionNumber ? "v" * string(cfg.tool) : "vdev"

"""
    gitignore(cfg) -> String

The block this package owns inside a package's `.gitignore`: the scratch directory, the built site, the
manifests of the sub-environments, the local settings file and coverage output. The argument is `cfg`,
the package's config. Returns the block, marked at both ends so the rest of the file is the package's own.
"""
function gitignore(cfg::Model.Config)
    return """
    # $BEGIN_MARK $(version_tag(cfg)) — rewritten by `gbg sync`; do not edit
    .gbg/scratch/
    docs/build/
    docs/Manifest.toml
    test/Manifest.toml
    benchmark/Manifest.toml
    .claude/settings.local.json
    *.cov
    # $END_MARK
    """
end

"""
    hook(cfg) -> String

The end-of-turn hook: the script that refuses to let a session stop while an item of its work queue is
open. The argument is `cfg`, the package's config. Returns the script.

Two things in it are load-bearing. The loop guard — a hook that blocks again while already holding the
session open would trap it with no way out — and the rule that an item is closed only when it is done,
since an item closed to end the turn is the defect the hook exists to prevent. A run's own leftovers go
under a heading this hook does not count, so a review never puts a session to work on something the owner
has not asked about.
"""
function hook(cfg::Model.Config)
    return """
    #!/usr/bin/env bash
    # STOP HOOK — refuses to let the session end while committed work is open.
    # Written by GBGCodingTools $(version_tag(cfg)); do not edit.
    #
    # CONTRACT. `.claude/WORK_QUEUE.md` holds one line per item, `- [ ]` open, `- [x]` done. While any
    # item is open this exits 2, which Claude Code treats as "do not stop", feeding stderr back as the
    # reason. Closing an item is an edit that shows in the diff, so the queue cannot be silently emptied.
    #
    # WHY IT IS A HOOK AND NOT A RULE. Told "continue with everything, don't stop in the middle", a
    # session finished three of five queued items and reported status with the other two labelled
    # "remaining queue". Stopping to narrate IS stopping. Every earlier defence was a sentence in
    # CLAUDE.md, and a rule written down reads as compliance while nothing checks it.
    #
    # THE LOOP GUARD IS LOAD-BEARING. `stop_hook_active` is true when the session is already being held
    # open by this hook; blocking again there would trap it forever. It is the difference between a
    # harness and a cage.
    #
    # THE UNCOUNTED HEADING. Lines under "## From the last review" are NOT counted: a run's leftovers are
    # the owner's list to act on when he chooses, and holding a session to them would be a review setting
    # a session to work nobody asked for.
    set -uo pipefail
    payload=\$(cat)
    if grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' <<<"\$payload"; then
      exit 0
    fi

    queue="\${CLAUDE_PROJECT_DIR:-.}/.claude/WORK_QUEUE.md"
    [[ -f "\$queue" ]] || exit 0

    counted=\$(sed '/^## From the last review/,\$d' "\$queue")
    open_items=\$(grep -nE '^[[:space:]]*- \\[ \\]' <<<"\$counted" || true)
    [[ -z "\$open_items" ]] && exit 0

    {
      echo "WORK QUEUE IS NOT EMPTY — you committed to finishing these before reporting back:"
      echo
      sed 's/^/  /' <<<"\$open_items"
      echo
      echo "Continue working. Close each item in .claude/WORK_QUEUE.md by changing '- [ ]' to '- [x]'"
      echo "ONLY when it is actually done and verified — an item closed to end the turn is the defect"
      echo "this hook exists to prevent. If an item is genuinely blocked, mark it '- [x]' and record the"
      echo "blocker on the same line, so the block is visible in the diff rather than silent."
    } >&2
    exit 2
    """
end

"""
    HOOK_COMMAND

The one line `.claude/settings.json` must carry for this package: the command that runs the end-of-turn
hook. It is matched literally, so a package may hold any number of other hooks beside it.
"""
const HOOK_COMMAND = "\"\$CLAUDE_PROJECT_DIR\"/.claude/hooks/queue-guard.sh"

"""
    settings_drift(root) -> Union{String,Nothing}

What `.claude/settings.json` gets wrong about the end-of-turn hook in the package at `root`, or
`nothing` where it installs it. The argument is `root`, the package root. Returns the fault, in words.

Only this package's own Stop hook is looked for. The file is the PACKAGE's — it may hold its own hooks,
its own permissions and its own settings — so a whole-file comparison would report every one of them as
drift, and writing the file whole would delete them.
"""
function settings_drift(root::AbstractString)
    path = joinpath(root, ".claude", "settings.json")
    isfile(path) || return ".claude/settings.json is absent"
    doc = try
        JSON3.read(read(path, String), Dict{String,Any})
    catch
        return ".claude/settings.json does not parse"
    end
    # The file is read as JSON rather than as text: the command holds quotes, which JSON escapes, so a
    # substring search over the raw file never matches what was written into it.
    for entry in get(get(doc, "hooks", Dict{String,Any}()), "Stop", Any[])
        for h in get(entry, "hooks", Any[])
            get(h, "command", "") == HOOK_COMMAND && return nothing
        end
    end
    return "no Stop hook runs .claude/hooks/queue-guard.sh"
end

"""
    write_settings(root) -> Bool

Adds this package's Stop hook to `.claude/settings.json` in the package at `root`, keeping every other
hook and setting the file holds. The argument is `root`, the package root. Returns whether it changed.

The entry is added to the `Stop` list rather than replacing it: a package that has its own stop hook
keeps it and gets this one as well.
"""
function write_settings(root::AbstractString)
    settings_drift(root) === nothing && return false
    path = joinpath(root, ".claude", "settings.json")
    doc = isfile(path) ? JSON3.read(read(path, String), Dict{String,Any}) : Dict{String,Any}()
    hooks = get!(doc, "hooks", Dict{String,Any}())
    stops = get!(hooks, "Stop", Any[])
    push!(stops, Dict("hooks" => [Dict("type" => "command", "command" => HOOK_COMMAND)]))
    mkpath(dirname(path))
    open(path, "w") do io; JSON3.pretty(io, JSON3.write(doc)); println(io); end
    return true
end

"""
    regressions_note(cfg) -> String

The note in `test/regressions/`, where the failing tests of confirmed defects are kept. The argument is
`cfg`, the package's config. Returns the note.
"""
function regressions_note(cfg::Model.Config)
    return """
    <!-- gbg:managed regressions-note $(version_tag(cfg)) — rewritten by `gbg sync`; do not edit -->
    # `test/regressions/` — the failing tests of defects that were fixed

    Each file here began as the FAILING TEST of a bug hunt: a self-contained `@testset` asserting the
    correct behaviour, written before the fix and observed to fail on the tree that had the defect. It is
    moved here unchanged when the fix lands, so the test that proves the fix is the test that proved the
    bug.

    That "unchanged" is the whole discipline. A test edited to suit the fix has stopped being evidence: it
    no longer records what was wrong, only what the fixer decided to assert afterwards. If one needs
    changing to pass, either the fix is wrong or the test was — settle that, do not adjust the test.

    Each file must also:

    - be runnable on its own (`julia --project test/regressions/<file>.jl`), since it was, as a witness;
    - assert the correct behaviour against an ORACLE — an identity, a documented contract, a hand
      computation — never against another operation of the same package alone, which proves only that
      two things agree;
    - carry a header comment naming the defect, the date, and the commit that fixed it.

    `escalated/` holds the failing tests of defects the owner has not yet ruled on. A runner that walks
    this directory must not descend into it: a confirmed defect nobody has approved a fix for must not
    turn a package red.

    Naming: `<operation>-<one-line-symptom>.jl`, as in `weighted_inner-complex-weight-accepted.jl`.
    """
end

const PKG = "GBGCodingTools"
const PKG_UUID = "3aee1de0-bb62-4679-b1c5-a861fbcaaa51"
const PKG_URL = "https://github.com/GrigorySarnitsky/GBGCodingTools.jl.git"

"""
    SUBENVS

The sub-environments of a package that must see this one: the documentation build and the test suite.
Both run this package's checks, so both name it, and a package whose two environments disagree about
which version to use gets two different answers from the same commit.
"""
const SUBENVS = ["docs", "test"]

"""
    pin_entries(cfg, root, envdir) -> Dict{String,Any}

What one sub-environment's `Project.toml` must say about this package: the dependency, and either the
released version with its compat bound or the path to the checkout. The arguments are:

- `cfg` — the package's config, which carries the pin.
- `root` — the package root.
- `envdir` — the sub-environment, `"docs"` or `"test"`.

Returns the entries, keyed by the TOML table each belongs in; a table whose value is `nothing` must be
absent, which is how a checkout is distinguished from a release rather than merely left unstated.

A checkout is named by a relative path where this package's repository encloses the consumer, or is it,
and absolutely otherwise: a chain of `../` out of one repository and into another breaks the moment
either moves.

A PRERELEASE pin names the full tag as its `rev` and its BASE version in `compat`. The two differ
because Pkg refuses a prerelease in a version specifier outright — `semver_spec("=2.0.0-rc.1")` throws
`invalid version specifier` — while `release` already refuses to tag `vX.Y.Z-rc.N` unless `Project.toml`
says `X.Y.Z`, so the base is what a consumer resolving that tag actually reads. The tag is what pins;
compat is the guard that the tree behind it is the version it claims to be.
"""
function pin_entries(cfg::Model.Config, root::AbstractString, envdir::AbstractString)
    deps = Dict{String,Any}(PKG => PKG_UUID)
    if cfg.tool isa VersionNumber
        v = cfg.tool
        base = string(VersionNumber(v.major, v.minor, v.patch))
        return Dict{String,Any}("deps" => deps,
                                "sources" => Dict{String,Any}(PKG => Dict("url" => PKG_URL, "rev" => "v" * string(v))),
                                "compat" => Dict{String,Any}(PKG => "=" * base))
    end
    here = abspath(something(pkgdir(@__MODULE__), root)); there = abspath(root)
    path = (there == here || startswith(there, here * "/")) ? relpath(here, joinpath(there, envdir)) : here
    return Dict{String,Any}("deps" => deps,
                            "sources" => Dict{String,Any}(PKG => Dict("path" => path)),
                            "compat" => nothing)
end

"""
    pin_drift(cfg, root, envdir) -> Union{String,Nothing}

What one sub-environment's `Project.toml` gets wrong about this package, or `nothing` where it gets it
right. The arguments are:

- `cfg` — the package's config, which carries the pin.
- `root` — the package root.
- `envdir` — the sub-environment.

Returns the first disagreement, in words.

Only this package's own entries are compared, as parsed values: Pkg rewrites these files whenever it
resolves, so comparing the text would report every ordinary `Pkg.add` as drift.
"""
function pin_drift(cfg::Model.Config, root::AbstractString, envdir::AbstractString)
    path = joinpath(root, envdir, "Project.toml")
    isfile(path) || return "$envdir/Project.toml is absent"
    have = TOML.parsefile(path)
    for (table, want) in pin_entries(cfg, root, envdir)
        got = get(get(have, table, Dict{String,Any}()), PKG, nothing)
        if want === nothing
            got === nothing || return "[$table] names $PKG, and a checkout carries no $table entry"
            continue
        end
        got === nothing && return "[$table] does not name $PKG"
        got == want[PKG] || return "[$table] $PKG is `$got`, and the pin says `$(want[PKG])`"
    end
    return nothing
end

"""
    write_pin(cfg, root, envdir) -> Bool

Sets this package's entries in one sub-environment's `Project.toml`, keeping every other entry and
Pkg's own section order. The arguments are:

- `cfg` — the package's config, which carries the pin.
- `root` — the package root.
- `envdir` — the sub-environment.

Returns whether the file changed.
"""
function write_pin(cfg::Model.Config, root::AbstractString, envdir::AbstractString)
    path = joinpath(root, envdir, "Project.toml")
    proj = isfile(path) ? TOML.parsefile(path) : Dict{String,Any}()
    for (table, want) in pin_entries(cfg, root, envdir)
        if want === nothing
            haskey(proj, table) && delete!(proj[table], PKG)
            haskey(proj, table) && isempty(proj[table]) && delete!(proj, table)
        else
            get!(proj, table, Dict{String,Any}())[PKG] = want[PKG]
        end
    end
    io = IOBuffer()
    top = [k for k in ("name", "uuid", "authors", "version") if haskey(proj, k)]
    for k in top; TOML.print(io, Dict(k => proj[k])); end
    isempty(top) || println(io)
    rest = sort!([k for k in keys(proj) if !(k in ("name", "uuid", "authors", "version", "deps", "sources", "compat"))])
    for sec in vcat(["deps", "sources", "compat"], rest)
        haskey(proj, sec) || continue
        println(io, "[", sec, "]")
        for k in sort!(collect(keys(proj[sec])))
            v = proj[sec][k]
            println(io, k, " = ", v isa AbstractDict ?
                    "{" * join(("$kk = $(repr(String(vv)))" for (kk, vv) in sort!(collect(v); by = first)), ", ") * "}" :
                    repr(String(v)))
        end
        println(io)
    end
    # One trailing newline, not the blank line each section loop leaves: a generated file that differs
    # from the package's own only in trailing whitespace is churn in every diff that touches it.
    text = rstrip(String(take!(io))) * "\n"
    isfile(path) && read(path, String) == text && return false
    mkpath(dirname(path)); write(path, text)
    return true
end

"""
    runtests_call() -> String

The line a package's `test/runtests.jl` ends with: the harness, handed the wiring check. The harness sits
below the generators in the module order and so cannot reach that check itself; a consumer gets both by
being given both, in one line it can read. Returns the line.

It is `dirname(@__DIR__)`, not `@__DIR__ |> dirname`: a macro call takes the rest of the line as its
arguments, so the second spelling is a parse error. This line is copied into consumers verbatim, and it
was wrong in both places that already held it.
"""
runtests_call() = "GBGCodingTools.Engine.Harness.test(dirname(@__DIR__); checks = (GBGCodingTools.Render.wiring,))"

"""
    CI_ACTION

Where the composite action this package writes for a consumer's CI lives.
"""
const CI_ACTION = ".github/actions/gbg-auth/action.yml"

"""
    ci(cfg) -> String

The composite GitHub action a consumer's workflows call before resolving their environment: the token
rewrite that lets a private dependency be fetched on a runner. The argument is `cfg`, the package's
config, which this generator does not read. Returns the action file.

It is a whole FILE that a workflow names in one line, not a fragment spliced into the workflow. A
fragment has to be inserted at the right indentation inside somebody else's `steps:` list, and getting
that wrong produces YAML that is valid and does nothing. A `uses:` line is one line, and the wiring
check can read it the way it reads any other call.

Only a package pinned to a RELEASED version needs this. A checkout resolves this package over a path,
and a path needs no credential.
"""
function ci(cfg::Model.Config)
    return """
    # $BEGIN_MARK $(version_tag(cfg)) — rewritten by `gbg sync`; do not edit
    name: GBG private dependencies
    description: Lets a runner fetch the GBG packages, which are private repositories.
    inputs:
      token:
        description: A token that can read the GBG repositories.
        required: true
    runs:
      using: composite
      steps:
        - shell: bash
          # Before any julia-actions step: Pkg fetches the pinned tool over https, and this rewrite is
          # what lets a private repository resolve on the runner.
          run: git config --global url."https://x-access-token:\${{ inputs.token }}@github.com/".insteadOf "https://github.com/"
    # $END_MARK
    """
end

"""
    ci_drift(cfg, root) -> Vector{Model.Location}

Every GitHub workflow in the package at `root` that resolves this package without authenticating first.
The arguments are `cfg`, the package's config, and `root`, the package root. Returns one location per
workflow.

Nothing is reported for a package pinned to a checkout, which needs no credential, or for one with no
workflows at all.
"""
function ci_drift(cfg::Model.Config, root::AbstractString)
    cfg.tool isa VersionNumber || return Model.Location[]
    dir = joinpath(root, ".github", "workflows")
    isdir(dir) || return Model.Location[]
    out = Model.Location[]
    for f in sort!(readdir(dir))
        (endswith(f, ".yml") || endswith(f, ".yaml")) || continue
        path = joinpath(".github", "workflows", f)
        occursin("./.github/actions/gbg-auth", read(joinpath(dir, f), String)) && continue
        push!(out, Model.Location(; file = path,
            text = "does not use `./.github/actions/gbg-auth`, so a runner cannot fetch this package"))
    end
    return out
end

"""
    CALLS

The two files a package must hand to this one, and what each must name. A package whose `runtests.jl`
does not call the harness runs no rule in its test suite, and one whose `make.jl` calls
`Documenter.makedocs` directly runs none in its build — in both cases silently, and green.

This is checked by reading the files rather than by grepping a CI log for a banner, which is what the
tree being replaced did. A log grep answers only on the machine that produced the log; reading the call
answers on every machine, before anything is pushed, and it is the same answer.
"""
const CALLS = [
    (path = "test/runtests.jl", names = "Harness.test",
     want = "GBGCodingTools.Engine.Harness.test", why = "the test suite runs no rule of the rulebook"),
    (path = "docs/make.jl", names = "GBGCodingTools.makedocs",
     want = "GBGCodingTools.makedocs", why = "the documentation build runs no rule of the rulebook"),
]

"""
    call_drift(root) -> Vector{Model.Location}

Every file of [`CALLS`](@ref) in the package at `root` that does not call into this package. The argument
is `root`, the package root. Returns one location per file, and none where a file is absent — a package
with no documentation build has nothing to wire, and saying otherwise would make this package's
opinions a requirement to have one.
"""
function call_drift(root::AbstractString)
    out = Model.Location[]
    for c in CALLS
        full = joinpath(root, c.path)
        isfile(full) || continue
        # A commented-out call is not a call. The line must survive with the name on it, uncommented.
        live = join([l for l in eachline(full) if !startswith(strip(l), "#")], "\n")
        occursin(c.want, live) && continue
        push!(out, Model.Location(; file = c.path,
            text = "nothing here calls `$(c.names)`, so $(c.why)"))
    end
    return out
end

# ──────────────────────────────────────────────────────────────────────────────── the rendered rulebook

"""
    POLICY_FILES

One rendered rulebook file per family of rule ids, with the families it carries and the sentence that
opens it. `RULE.API.*` shares a file with `RULE.DOC.*`: an API page and a docstring are one subject, and
splitting them would put the two halves of "one concept, one home" in two files.
"""
const POLICY_FILES = [
    (generator = :policy_docs, path = ".gbg/policy/docs-rubric.md", families = [:DOC, :API],
     title = "Documentation and API — `RULE.DOC.*`, `RULE.API.*`",
     opening = "What a docstring and an API page contain, in what order and in what shape."),
    (generator = :policy_latex, path = ".gbg/policy/latex-idiom.md", families = [:TEX],
     title = "LaTeX idiom — `RULE.TEX.*`",
     opening = "What renders, and how mathematics is written so that it renders the same way everywhere."),
    (generator = :policy_citations, path = ".gbg/policy/citations.md", families = [:CIT],
     title = "Citations — `RULE.CIT.*`",
     opening = "Author–year in the prose, the full reference where the reader can reach it, a DOI on every title."),
    (generator = :policy_testing, path = ".gbg/policy/testing-protocol.md", families = [:TEST],
     title = "Testing protocol — `RULE.TEST.*`",
     opening = "What a test is for, where its oracle comes from, and when a thing is done."),
    (generator = :policy_instruments, path = ".gbg/policy/instruments.md", families = [:INST],
     title = "Instruments — `RULE.INST.*`",
     opening = "How a review runs: consent, witnesses, closure, cost, and the limits it must state."),
    (generator = :policy_git, path = ".gbg/policy/git-conventions.md", families = [:GIT],
     title = "Git conventions — `RULE.GIT.*`",
     opening = "What a commit carries, where it goes, and what is never committed."),
    # A family with no ancestor: nothing in the old tree checked how a person was addressed. These read a
    # question rather than a file, and they run at the moment one is put.
    (generator = :policy_asking, path = ".gbg/policy/asking.md", families = [:ASK],
     title = "Asking the owner — `RULE.ASK.*`",
     opening = "One decision, short, in his words rather than this package's, with every identifier moved out of the sentence."),
]

"""
    family_of(id) -> Symbol

The family an id belongs to: the middle word of `RULE.<FAMILY>.<NAME>`. The argument is `id`, the rule's
identifier. Returns the family.
"""
family_of(id::Symbol) = Symbol(split(String(id), '.')[2])

"""
    rule_section(rule) -> String

One rule as the rendered rulebook shows it: its heading, its statement, why it exists, what decides a
violation, and the values a package may set. The argument is `rule`, the rule. Returns the section.

No example is shown. A rulebook page carrying an example of a rule being broken is by construction full
of text that breaks the rules it states, which a reader spends its budget reporting and no fixer may
touch; the examples live in the rule value, where `test/rules.jl` runs them.
"""
function rule_section(rule::Model.Rule)
    io = IOBuffer()
    println(io, "### ", rule.id)
    println(io, rule.statement)
    isempty(rule.why) || (println(io); println(io, rule.why))
    println(io)
    println(io, "Decided by ", Catalogue.check_words(rule.check), ".",
            rule.check === nothing ? " Nothing checks it: " * rule.unchecked_reason : "")
    for p in rule.parameters
        println(io, "This package may set `", p.name, "`; unset, it is `", p.default, "`.")
    end
    return String(take!(io))
end

"""
    policy_file(cfg, entry) -> String

One file of the rendered rulebook: its heading, its opening sentence, and every rule of the families it
carries, in id order. The arguments are `cfg`, the package's config, and `entry`, the row of
[`POLICY_FILES`](@ref) to render. Returns the file.
"""
function policy_file(cfg::Model.Config, entry)
    rules = sort([r for r in Catalogue.RULES if family_of(r.id) in entry.families], by = r -> String(r.id))
    io = IOBuffer()
    println(io, "<!-- gbg:managed begin ", version_tag(cfg), " — rewritten by `gbg sync`; do not edit -->")
    println(io, "# ", entry.title, "\n")
    println(io, entry.opening, " ", length(rules), " rules, written from the rule values themselves,")
    println(io, "so a rule reworded here was reworded in the program that checks it.\n")
    for r in rules
        println(io, rule_section(r))
    end
    println(io, "<!-- gbg:managed end -->")
    return String(take!(io))
end

"""
    claude_block(cfg) -> String

The block this package owns at the top of a package's `CLAUDE.md`: the import of the rulebook, and the
two standing instructions a session needs before it has read anything. The argument is `cfg`, the
package's config. Returns the block, marked at both ends so the rest of the file is the package's own.

It imports and does not restate. A block that listed the rules, or what this package has switched off,
would be a second copy of the rulebook in the one file every session reads first — and the copy that
is read is the copy that drifts.
"""
function claude_block(cfg::Model.Config)
    return """
    <!-- $BEGIN_MARK $(version_tag(cfg)) — rewritten by `gbg sync`; do not edit -->
    @.gbg/policy/00-index.md

    The rulebook above is the whole of it: the rules, the terms they use, and what $(cfg.package) has
    switched off with its reason. Nothing restates a rule outside it — a rule quoted in two files is a
    rule that will be reworded in one.

    Unasked, run `Pkg.test()` and nothing else. What a rule finds is reported, never fixed silently:
    documentation may be fixed without asking, and anything else waits for an answer.
    <!-- $END_MARK -->
    """
end

"""
    policy_paths() -> Vector{String}

Every file of the rendered rulebook, in the order a reader meets them: the rule families as
[`POLICY_FILES`](@ref) lists them, then the glossary, then what this package has switched off. Returns
the paths, relative to the package root.
"""
policy_paths() = vcat([e.path for e in POLICY_FILES], [".gbg/policy/glossary.md", ".gbg/policy/switches.md"])

"""
    policy_index(cfg) -> String

The rulebook's index: what the rulebook is, how a package escapes a rule, and the import of every other
file, which is how a session loads the whole of it. The argument is `cfg`, the package's config.
Returns the file.
"""
function policy_index(cfg::Model.Config)
    io = IOBuffer()
    println(io, "<!-- gbg:managed begin ", version_tag(cfg), " — rewritten by `gbg sync`; do not edit -->")
    println(io, "# The rulebook\n")
    println(io, """
    One text for every package that pins GBGCodingTools, at the version this package pins. Every rule has
    a stable id, `RULE.<FAMILY>.<NAME>`, which is never renamed and never reused: a finding, a switch and
    a report all name a rule by it.

    This directory is WRITTEN, not edited. Each rule is a Julia value carrying its statement, the check
    that decides a violation, and the examples that show the check matches the statement; these files are
    rendered from those values by `gbg sync`, so a rule cannot be reworded here without being reworded in
    the program that enforces it, and the two cannot drift.

    A package that a rule does not fit does not edit it. It declares a `Switch` in its own `.gbg/config.jl`,
    naming the rule and the reason, for the whole package or for named files; `switches.md` lists what this
    package has declared, and a session reads a switched rule as the switch states it. A rule a package
    adds for itself is a `PatternRule` in the same file, and is nobody else's.\n""")
    println(io, "The files:\n")
    for e in POLICY_FILES
        n = count(r -> family_of(r.id) in e.families, Catalogue.RULES)
        println(io, "- `", basename(e.path), "` — ", e.opening, " (", n, " rules)")
    end
    println(io, "- `glossary.md` — the terms the rules use, bound once.")
    println(io, "- `switches.md` — what this package has switched off, and why.\n")
    for path in policy_paths()
        println(io, "@", path)
    end
    println(io, "<!-- gbg:managed end -->")
    return String(take!(io))
end

"""
    glossary(cfg) -> String

The terms the rules use, bound once so that every rule may use them without redefining them. The
argument is `cfg`, the package's config. Returns the file.
"""
function glossary(cfg::Model.Config)
    return """
    <!-- gbg:managed begin $(version_tag(cfg)) — rewritten by `gbg sync`; do not edit -->
    # Glossary

    The terms the rules use. A rule may use any of these without defining it; a term not here is defined
    where it is used, or it is not a term of art.

    - **consumer** — a package that pins this one and receives its wiring.
    - **rule** — one statement with one check and the examples that show the check matches it. Its id is
      `RULE.<FAMILY>.<NAME>`, stable for the life of the rule.
    - **check** — what decides that a rule was broken: a program, or an agent where no program can.
    - **clause** — one requirement of a statement. A rule with three clauses owes three breaking examples
      and three complying ones.
    - **switch** — a package turning a rule off, wholly or for named files, with its reason. It replaces
      the exemption ledger: there is no expiry and no ceremony, only a reason a reader can weigh.
    - **file set** — which of a package's files a rule runs over: docstrings, code, pages, rationale,
      Literate examples, tests.
    - **finding** — one violation at one location, with the rule that found it.
    - **location** — where a finding is: the file, the node (a binding, or a heading path), the quote as
      it read then, and the line as a hint only.
    - **generated file** — a file written by a Julia function of this package. Editing one by hand is
      drift, which the wiring check reports and `gbg sync` repairs.
    - **pin** — the one version of this package a consumer uses, named in its sub-environments.
    - **intention** — whether a change or a finding is in documentation or in code. Documentation is safe
      to fix without asking; code is not.
    <!-- gbg:managed end -->
    """
end

"""
    switches(cfg) -> String

What this package has switched off, and why: one entry per `Switch` in its config, and a rule a package
adds for itself listed after them. The argument is `cfg`, the package's config. Returns the file.

A switch is read as part of the rulebook: a session that has loaded the rules has loaded what this
package does not hold itself to, which is the only way a rule can be escaped.
"""
function switches(cfg::Model.Config)
    io = IOBuffer()
    println(io, "<!-- gbg:managed begin ", version_tag(cfg), " — rewritten by `gbg sync`; do not edit -->")
    println(io, "# What ", cfg.package, " has switched off\n")
    if isempty(cfg.switches)
        println(io, "Nothing. Every rule of the rulebook applies here as written.\n")
    else
        println(io, "Each entry names a rule this package does not hold itself to, and why. A rule listed")
        println(io, "here is read as the entry states it.\n")
        for s in cfg.switches
            scope = isempty(s.files) ? "the whole package" : join("`" .* s.files .* "`", ", ")
            println(io, "- `", s.target, "` — ", s.reason, " (", scope, ")")
        end
        println(io)
    end
    if !isempty(cfg.rules)
        println(io, "Rules this package adds for itself, which are nobody else's:\n")
        for r in cfg.rules
            println(io, "- `", r.id, "` — ", r.statement)
        end
        println(io)
    end
    println(io, "<!-- gbg:managed end -->")
    return String(take!(io))
end

"""
    RULES_PAGE

Where `pages` writes the rulebook into a consumer's site, relative to the package root.
"""
const RULES_PAGE = "docs/src/gbg-rules.md"

"""
    pages(cfg, root) -> Vector{String}

Writes the site pages that show a package what it is held to, and returns the paths written relative to
`docs/src/`, which is the form a `docs/make.jl` lists in its `pages`. The arguments are `cfg`, the
package's config, and `root`, the package root.

Today that is one page: every rule of the rulebook, and what this package has switched off with its
reason. A switch is answerable because a reader can see it, and the rendered rulebook under `.gbg/` is
not somewhere a reader of the documentation goes.

This page is written at BUILD time and belongs in the package's `generated` list, so that no rule reads
it. A page that states the rules is by construction full of text that breaks them — it quotes the
banned spellings in order to ban them — and a reader sent to fix it would spend its whole budget there.
"""
function pages(cfg::Model.Config, root::AbstractString)
    io = IOBuffer()
    println(io, "# [The rules ", cfg.package, " is held to](@id gbg-rules)\n")
    println(io, "!!! info \"Written by AI, not regularly reviewed\"\n    This page is written by AI and is not reviewed regularly by a human.\n")
    println(io, "Generated at build time from the rule values in GBGCodingTools ", version_tag(cfg),
                ". Each rule carries its own check and the examples that show the check matches it, so this")
    println(io, "text and the program that enforces it cannot disagree. A rule's id is stable and is what a")
    println(io, "finding, a switch and a report all name.\n")
    for path in policy_paths()
        body = produce(only(g.generator for g in GENERATED if g.path == path), cfg)
        for line in split(body, '\n')
            (occursin(BEGIN_MARK, line) || occursin(END_MARK, line)) && continue
            m = match(r"^### (RULE\.[A-Z]+\.[A-Z_]+)\s*$", line)
            # The glossary binds the terms every rule uses, so the rest of a site links to it by name.
            g = match(r"^# (Glossary)\s*$", line)
            if g !== nothing
                println(io, "## [Glossary](@id glossary)")
                continue
            end
            # Every rule gets an anchor under its own id, so a finding elsewhere on the site can link to
            # the rule that produced it; every other heading drops a level to sit under this page's own.
            println(io, m !== nothing ? "#### [`" * m.captures[1] * "`](@id " * m.captures[1] * ")" :
                        startswith(line, "#") ? "#" * line : line)
        end
        println(io)
    end
    full = joinpath(root, RULES_PAGE)
    mkpath(dirname(full))
    write(full, String(take!(io)))
    return [relpath(RULES_PAGE, "docs/src")]
end

# ─────────────────────────────────────────────────────────────────────────── the register and the check

"""
    GENERATED

Every path this module writes in a package, with how much of it is written. A path is here only when a
generator writes it today: the instrument skills wait for the instruments and are not in the register, so
the wiring check does not claim to hold them.
"""
const GENERATED = [
    (path = ".gitignore",                  part = Model.Part.BLOCK,        generator = :gitignore),
    (path = ".claude/hooks/queue-guard.sh", part = Model.Part.WHOLE,       generator = :hook),
    (path = "test/regressions/README.md",  part = Model.Part.WHOLE,        generator = :regressions_note),
    (path = "CLAUDE.md",                   part = Model.Part.BLOCK,        generator = :claude_block),
    (path = CI_ACTION,                     part = Model.Part.WHOLE,        generator = :ci),
    (path = ".gbg/policy/00-index.md",     part = Model.Part.WHOLE,        generator = :policy_index),
    (path = ".gbg/policy/glossary.md",     part = Model.Part.WHOLE,        generator = :glossary),
    (path = ".gbg/policy/switches.md",     part = Model.Part.WHOLE,        generator = :switches),
    (map(e -> (path = e.path, part = Model.Part.WHOLE, generator = e.generator), POLICY_FILES))...,
]

"""
    produce(name, cfg) -> String

What one generator writes now. The arguments are `name`, the generator's name as the register holds it,
and `cfg`, the package's config. Returns the content.
"""
function produce(name::Symbol, cfg::Model.Config)
    name === :gitignore && return gitignore(cfg)
    name === :hook && return hook(cfg)
    name === :regressions_note && return regressions_note(cfg)
    name === :policy_index && return policy_index(cfg)
    name === :glossary && return glossary(cfg)
    name === :switches && return switches(cfg)
    name === :claude_block && return claude_block(cfg)
    name === :ci && return ci(cfg)
    for e in POLICY_FILES
        name === e.generator && return policy_file(cfg, e)
    end
    error("no generator named $name")
end

"""
    block_of(text) -> Union{String,Nothing}

The marked block inside a file this package shares with the package that owns it, or `nothing` where the
file holds none. The argument is `text`, the file's content. Returns the block, markers included.
"""
function block_of(text::AbstractString)
    lines = split(text, '\n')
    first_i = findfirst(l -> occursin(BEGIN_MARK, l), lines)
    last_i = findfirst(l -> occursin(END_MARK, l), lines)
    (first_i === nothing || last_i === nothing || last_i < first_i) && return nothing
    return join(lines[first_i:last_i], '\n') * "\n"
end

"""
    wiring(cfg, root) -> Vector{Model.Location}

Every generated path of the package at `root` that is not what its generator writes now, and each
sub-environment whose pin disagrees with the config: one location per path, quoting the first line that
differs. The arguments are `cfg`, the package's config, and `root`, the
package root. A path that does not exist at all is reported the same way, since a package missing a
generated file is as wired-wrongly as one holding a stale copy. Returns the locations.
"""
function wiring(cfg::Model.Config, root::AbstractString)
    out = Model.Location[]
    for g in GENERATED
        full = joinpath(root, g.path)
        want = produce(g.generator, cfg)
        if !isfile(full)
            push!(out, Model.Location(; file = g.path, text = "the file is absent"))
            continue
        end
        text = read(full, String)
        have = g.part === Model.Part.BLOCK ? block_of(text) : text
        have === nothing && (push!(out, Model.Location(; file = g.path, text = "the managed block is absent")); continue)
        have == want && continue
        push!(out, Model.Location(; file = g.path, line = first_difference(have, want),
                                   text = "this file is not what `gbg sync` writes now"))
    end
    # The two calls that make any of this run at all, and the one a runner needs.
    append!(out, call_drift(root))
    append!(out, ci_drift(cfg, root))
    # `.claude/settings.json` is the package's own file too: only this package's hook is looked for.
    why = settings_drift(root)
    why === nothing || push!(out, Model.Location(; file = ".claude/settings.json", text = why))
    # The pin is entries inside a file Pkg owns and rewrites, so only this package's own entries are
    # compared, and as parsed values: comparing the text would report every `Pkg.add` as drift.
    for envdir in SUBENVS
        why = pin_drift(cfg, root, envdir)
        why === nothing || push!(out, Model.Location(; file = joinpath(envdir, "Project.toml"), text = why))
    end
    return out
end

first_difference(a::AbstractString, b::AbstractString) =
    something(findfirst(i -> get(split(a, '\n'), i, nothing) != get(split(b, '\n'), i, nothing),
                        1:max(count(==('\n'), a), count(==('\n'), b)) + 1), 1)

"""
    write_all(cfg, root) -> Vector{String}

Writes every generated path of the package at `root`, sets the pin in each sub-environment, and returns
the paths it changed. The arguments are
`cfg`, the package's config, and `root`, the package root. A marked block is replaced inside the file that
holds it and the rest of that file is left alone; anything else is written whole.
"""
function write_all(cfg::Model.Config, root::AbstractString)
    changed = String[]
    for g in GENERATED
        full = joinpath(root, g.path)
        want = produce(g.generator, cfg)
        mkpath(dirname(full))
        if g.part === Model.Part.BLOCK && isfile(full)
            text = read(full, String)
            have = block_of(text)
            # A file that has no block yet gets one at its HEAD, not its foot. `CLAUDE.md`'s block
            # carries the import of the rulebook, and a session reads that file from the top: appended
            # to a 2,700-line file it is read last or not at all. `.gitignore` does not care, and the
            # head is right there too.
            new = have === nothing ? want * "\n" * text : replace(text, have => want)
            new == text && continue
            write(full, new)
        else
            isfile(full) && read(full, String) == want && continue
            write(full, want)
        end
        g.generator === :hook && chmod(full, 0o755)
        push!(changed, g.path)
    end
    write_settings(root) && push!(changed, ".claude/settings.json")
    for envdir in SUBENVS
        write_pin(cfg, root, envdir) && push!(changed, joinpath(envdir, "Project.toml"))
    end
    return changed
end

end # module Render
