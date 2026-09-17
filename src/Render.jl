"""
    Render

Every file that connects a package to this one, written by a Julia function (`docs/ARCHITECTURE.md` §6).
There is no template language and no template directory: a generated file is the return value of a
function that takes the package's config, so what a package receives is decided in Julia, beside the
values it is derived from, and can be compared with what is on disk by running the function again.

That comparison is the WIRING CHECK, which every build and every test runs: a generated file that has
been hand-edited, or that a newer version of this package would write differently, is a finding rather
than a silent divergence. Regenerating is left to `gbg sync`, `gbg bump` and `gbg release`, so a build
reports drift and never repairs it.

This is the sixth module of the order: it may name `Model`, `Texts`, `Catalogue` and `ConfigIO`, and
nothing above. What it writes today is the WIRING — the pin, the ignore block, the end-of-turn hook, the
settings that install it, the CI workflows and the regressions note. The rendered rulebook waits for the
rules to be Julia, and the skills wait for the instruments (`IMPLEMENTATION.md` Phases 4 and 5), so
`gbg sync` still renders those two from the old templates.
"""
module Render

using ..Model
using ..Catalogue

const BEGIN_MARK = "# gbg:managed begin"
const END_MARK = "# gbg:managed end"

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
    $BEGIN_MARK $(version_tag(cfg)) — rewritten by `gbg sync`; do not edit
    .gbg/scratch/
    docs/build/
    docs/Manifest.toml
    test/Manifest.toml
    benchmark/Manifest.toml
    .claude/settings.local.json
    *.cov
    $END_MARK
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
    settings(cfg) -> String

The `.claude/settings.json` that installs the end-of-turn hook in a package. The argument is `cfg`, the
package's config. Returns the file.
"""
function settings(cfg::Model.Config)
    return """
    {
      "hooks": {
        "Stop": [
          {
            "hooks": [
              {
                "type": "command",
                "command": "\\"\$CLAUDE_PROJECT_DIR\\"/.claude/hooks/queue-guard.sh"
              }
            ]
          }
        ]
      }
    }
    """
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

    `escalated/` holds the failing tests of defects the owner has not yet ruled on. `Pkg.test()` never runs
    that directory: a confirmed defect nobody has approved a fix for must not turn a package red.

    Naming: `<operation>-<one-line-symptom>.jl`, as in `weighted_inner-complex-weight-accepted.jl`.
    """
end

"""
    pin_entries(cfg) -> Dict{String,Any}

What a sub-environment's `Project.toml` says about this package: the compat bound for a released pin, or
the path source for a checkout. The argument is `cfg`, the package's config. Returns the entries, keyed by
the TOML table they belong in.
"""
function pin_entries(cfg::Model.Config)
    cfg.tool isa VersionNumber || return Dict{String,Any}("sources" => Dict("GBGCodingTools" => Dict("path" => "..")))
    return Dict{String,Any}("compat" => Dict("GBGCodingTools" => "=" * string(cfg.tool)))
end

"""
    runtests_call() -> String

The line a package's `test/runtests.jl` ends with: the harness, handed the wiring check. The harness sits
below the generators in the module order and so cannot reach that check itself; a consumer gets both by
being given both, in one line it can read. Returns the line.
"""
runtests_call() = "GBGCodingTools.Engine.Harness.test(@__DIR__ |> dirname; checks = (GBGCodingTools.Render.wiring,))"

# ─────────────────────────────────────────────────────────────────────────── the register and the check

"""
    GENERATED

Every path this module writes in a package, with how much of it is written. A path is here only when a
generator writes it today: the rendered rulebook and the instrument skills are still rendered from the old
templates and are not in the register, so the wiring check does not claim to hold them.
"""
const GENERATED = [
    (path = ".gitignore",                  part = Model.Part.BLOCK,        generator = :gitignore),
    (path = ".claude/hooks/queue-guard.sh", part = Model.Part.WHOLE,       generator = :hook),
    (path = ".claude/settings.json",       part = Model.Part.WHOLE,        generator = :settings),
    (path = "test/regressions/README.md",  part = Model.Part.WHOLE,        generator = :regressions_note),
]

"""
    produce(name, cfg) -> String

What one generator writes now. The arguments are `name`, the generator's name as the register holds it,
and `cfg`, the package's config. Returns the content.
"""
function produce(name::Symbol, cfg::Model.Config)
    name === :gitignore && return gitignore(cfg)
    name === :hook && return hook(cfg)
    name === :settings && return settings(cfg)
    name === :regressions_note && return regressions_note(cfg)
    error("no generator named $name")
end

"""
    block_of(text) -> Union{String,Nothing}

The marked block inside a file this package shares with the package that owns it, or `nothing` where the
file holds none. The argument is `text`, the file's content. Returns the block, markers included.
"""
function block_of(text::AbstractString)
    lines = split(text, '\n')
    first_i = findfirst(l -> startswith(l, BEGIN_MARK), lines)
    last_i = findfirst(l -> startswith(l, END_MARK), lines)
    (first_i === nothing || last_i === nothing || last_i < first_i) && return nothing
    return join(lines[first_i:last_i], '\n') * "\n"
end

"""
    wiring(cfg, root) -> Vector{Model.Location}

Every generated path of the package at `root` that is not what its generator writes now: one location per
path, quoting the first line that differs. The arguments are `cfg`, the package's config, and `root`, the
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
    return out
end

first_difference(a::AbstractString, b::AbstractString) =
    something(findfirst(i -> get(split(a, '\n'), i, nothing) != get(split(b, '\n'), i, nothing),
                        1:max(count(==('\n'), a), count(==('\n'), b)) + 1), 1)

"""
    write_all(cfg, root) -> Vector{String}

Writes every generated path of the package at `root` and returns the paths it changed. The arguments are
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
            new = have === nothing ? text * "\n" * want : replace(text, have => want)
            new == text && continue
            write(full, new)
        else
            isfile(full) && read(full, String) == want && continue
            write(full, want)
        end
        g.generator === :hook && chmod(full, 0o755)
        push!(changed, g.path)
    end
    return changed
end

end # module Render
