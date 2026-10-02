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

This is the sixth module of the order: it may name `Model`, `Texts`, `Catalogue`, `ConfigIO` and
`Engine`, and nothing above. What it writes today is the WIRING — the ignore block, the end-of-turn hook,
the settings that install it, the regressions note — the RULEBOOK a session loads, rendered from the rule
values themselves, so a rule cannot be reworded in the text without being reworded in the program that
enforces it, and one SKILL per instrument that applies.
"""
module Render

using TOML, JSON3

using ..Model
using ..Catalogue
using ..ConfigIO
using ..Engine

# The marker a generated block carries. A marker LINE is the mark at the head of a comment — `#` in a
# shell script or a `.gitignore`, `<!--` in Markdown — with nothing but whitespace before the opener, so
# one predicate reads every file. A line that mentions the mark in its prose is not a marker: a
# `CLAUDE.md` whose own text discussed the marker above the block lost that paragraph on the next sync,
# when the block was taken to begin at the first line that contained the words (found in review, 2026-09-26).
const MANAGED_MARK = "gbg:managed"
const BEGIN_MARK = MANAGED_MARK * " begin"
const END_MARK = "gbg:managed end"
is_begin(line::AbstractString) = occursin(r"^\s*(?:#|<!--)\s*gbg:managed begin\b", line)
is_end(line::AbstractString) = occursin(r"^\s*(?:#|<!--)\s*gbg:managed end\b", line)

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
    docs/src/gbg.md
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
    ids = hook_rule_ids()
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
    # AN OPEN RUN HOLDS THE SESSION TOO, and for the reason this hook exists at all: a run is walked
    # stage by stage BY THE SESSION — Julia cannot launch an agent — so a session that stops in the middle
    # has spent its agents for nothing and left a run that blocks the next one. The queue cannot catch
    # that, because a run writes its queue lines at CLOSE, which is the point it has not reached. Found
    # when the first real review stopped between stages to report (GBGPeriodicFields, 2026-09-22).
    #
    # ABANDONING IS NOT THE WAY OUT and is not offered as one: it DROPS the findings. A session that
    # cannot go on leaves the run OPEN and says where it stands; the next session continues it, and a
    # stage whose agents already answered is not relaunched. Abandoning is the owner's call, for a run he
    # does not want continued.
    #
    # THE UNCOUNTED HEADINGS. Lines under "## From the last review", and under "## Code the owner asked
    # for" — his list of code to change, which no session is held to — are NOT counted, up to the next
    # heading: a run's leftovers are the owner's list to act on when he chooses, and holding a session to
    # them would be a review setting a session to work nobody asked for. A section the owner adds below
    # it is his, and counted.
    set -uo pipefail
    payload=\$(cat)
    if grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' <<<"\$payload"; then
      exit 0
    fi

    runs="\${CLAUDE_PROJECT_DIR:-.}/.gbg/runs"
    if [[ -d "\$runs" ]]; then
      for d in "\$runs"/*/; do
        [[ -f "\$d/stage" && ! -f "\$d/run.json" ]] || continue
        id=\$(basename "\$d")
        {
          echo "A RUN IS OPEN — \$id, at stage \$(cat "\$d/stage" 2>/dev/null || echo '?')."
          echo
          echo "A run is walked stage by stage by YOU: the verb writes each stage's arguments and exits,"
          echo "because Julia cannot launch an agent. Stopping in the middle spends its agents for nothing"
          echo "and leaves a run that blocks the next one."
          echo
          echo "  Continue it:  gbg run next   (or collect, or close — whichever it is waiting for)"
          echo "  Or stop here: leave it OPEN and say which run and which stage, so the next session"
          echo "                picks it up. Nothing is lost; a stage whose agents answered is not relaunched."
          echo
          echo "Do NOT abandon it to end the turn: 'gbg run abandon' DROPS its findings. That is the"
          echo "owner's call, for a run he does not want continued."
        } >&2
        exit 2
      done
    fi

    # THE GIT RULES. RULE.GIT.BRANCH, RULE.GIT.PUSH and RULE.GIT.TRAILER ask about the branch and the
    # commits — what no build or test may read, since a fresh clone and CI must answer alike — so they
    # are checked HERE, at the end of the turn, on what is not yet pushed. A hook check is weaker than
    # a build check: a hook can be skipped and a failing test cannot, and the rulebook says so beside
    # each. Every function below is the rule's own lines, spliced from the rule value, so `gbg check`
    # and this script are one program and cannot disagree.
    $(hook_rules(cfg))
    GBG_BRANCH="$(Catalogue.branch_of(cfg))"
    git_said=""
    for r in $(join(ids, " ")); do
      fn="gbg_rule_\${r//./_}"
      out=\$(cd "\${CLAUDE_PROJECT_DIR:-.}" && "\$fn" 2>/dev/null) || out=""
      [[ -n "\$out" ]] && git_said+="\$(printf '%s\\n' "\$out" | sed "s/^/  \$r  /")"\$'\\n'
    done
    if [[ -n "\$git_said" ]]; then
      {
        echo "THE GIT RULES ARE NOT MET — the turn does not end on a branch or a commit the rulebook refuses:"
        echo
        printf '%s' "\$git_said"
        echo
        echo "Push what is committed (commit ⇒ push), on the working branch, with the trailer on every"
        echo "commit — or say why you cannot, so the owner decides. A hook can be skipped; do not."
      } >&2
      exit 2
    fi

    queue="\${CLAUDE_PROJECT_DIR:-.}/.claude/WORK_QUEUE.md"
    [[ -f "\$queue" ]] || exit 0

    # The leftovers section is the EXACT heading line, up to the next heading of ANY level, and the
    # lines printed carry their number in the file (found in review, 2026-09-23: a section of the
    # owner's under a `#` heading, or one whose name began with the leftovers', went uncounted).
    open_items=\$(awk '{ h = \$0; sub(/[ \t\r]+\$/, "", h) }
                        h == "## From the last review" || h == "## Code the owner asked for" {skip=1; next}
                        /^#/ {skip=0}
                        !skip && /^[[:space:]]*- \\[ \\]/ {print NR ":" \$0}' "\$queue")
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
    hook_rules(cfg) -> String

The shell functions the end-of-turn hook defines for the rules that read the history: one per rule
carrying `hook` lines, named `gbg_rule_<id with _ for .>`, its body the rule's own lines. The argument
is `cfg`, the package's config. Returns the functions as text.
"""
function hook_rules(cfg::Model.Config)
    io = IOBuffer()
    for r in Catalogue.RULES
        isempty(r.hook) && continue
        println(io, "    gbg_rule_", replace(String(r.id), "." => "_"), "() {")
        for line in split(strip(r.hook), '\n'); println(io, "      ", line); end
        println(io, "    }")
    end
    return String(take!(io))
end

"""
    hook_rule_ids() -> Vector{String}

The ids of the rules the end-of-turn hook checks, in rulebook order. Returns them as strings.
"""
hook_rule_ids() = [String(r.id) for r in Catalogue.RULES if !isempty(r.hook)]

"""
    push_gate(cfg) -> String

The push hook: the script that runs the package's docs build before every push a session makes, and
stops the push when the build fails. The argument is `cfg`, the package's config, whose `docs_build` is the
command it runs, the standard one where it is empty. Returns the script.

Claude Code runs it before every shell command, with the call on standard input; a command that is not a
push passes at once. The owner ruled on 2026-09-29 that every push does the docs build: until then a
session ran only `Pkg.test()` before pushing, and one package pushed a broken cross-reference sixteen
times, each one a docs run that failed on GitHub and a mail to the owner.
"""
function push_gate(cfg::Model.Config)
    # An empty setting is the build every wiring seeds, as `Scope` reads it too.
    cmd = isempty(cfg.docs_build) ? ["julia", "--project=docs", "docs/make.jl"] : cfg.docs_build
    build = join((shell_quote(a) for a in cmd), " ")
    return """
    #!/usr/bin/env bash
    # PUSH HOOK — the docs build runs before every push of this package, and a build that fails stops it.
    # Written by GBGCodingTools $(version_tag(cfg)); do not edit.
    #
    # CONTRACT. Claude Code runs this before every shell command (PreToolUse), with the call as JSON on
    # standard input. A command that pushes this package — `git push` in any spelling, or `gbg release`,
    # which pushes a tag — first runs the package's docs build, in the package root; exit 2 stops the push
    # and hands stderr back as the reason, exit 0 lets it through.
    #
    # WHY. The owner's ruling of 2026-09-29: every push does the docs build. A session ran only
    # `Pkg.test()` before pushing, so a broken cross-reference reached GitHub sixteen times in one package.
    #
    # WHAT IS READ. Only the command and the directory it runs in, decoded from the JSON: the call's
    # description is prose, and matching the whole payload ran a build for any command that merely named a
    # push. A quoted string and a heredoc body are data, not commands, unless a shell is told to run them.
    # A push from another repository is that repository's to judge, not this one's; and a push while
    # tracked files are uncommitted is stopped, since the build reads the tree and the push sends the commit
    # (all four found in review, 2026-09-29).
    set -uo pipefail
    payload=\$(cat)

    # The string value of a top-level key of the call, its escapes decoded.
    field() {
      printf '%s' "\$payload" | awk -v key="\\"\$1\\"" '
        { s = s \$0 "\\n" }
        END {
          i = index(s, key); if (i == 0) exit
          s = substr(s, i + length(key)); sub(/^[ \\t\\n]*:[ \\t\\n]*"/, "", s)
          out = ""
          for (k = 1; k <= length(s); k++) {
            c = substr(s, k, 1)
            if (c == "\\\\") { k++; e = substr(s, k, 1)
              if (e == "n") out = out "\\n"; else if (e == "t") out = out "\\t"; else out = out e
              continue }
            if (c == "\\"") break
            out = out c
          }
          printf "%s", out
        }'
    }
    cmd=\$(field command)
    here=\$(field cwd)
    [ -n "\$here" ] || here="\${CLAUDE_PROJECT_DIR:-.}"

    # Whether the command pushes, and every directory it moves to (`cd`, `git -C`) on the way.
    verdict=\$(printf '%s\\n' "\$cmd" | awk '
      tag != "" { t = \$0; gsub(/^[ \\t]+|[ \\t]+\$/, "", t); if (t == tag) tag = ""; next }
      {
        raw = \$0; line = \$0
        if (match(line, /<<-?[ \\t]*["\\047]?[A-Za-z_][A-Za-z0-9_]*["\\047]?/)) {
          h = substr(line, RSTART, RLENGTH); gsub(/^<<-?[ \\t]*["\\047]?|["\\047]?\$/, "", h); tag = h
        }
        if (line ~ /(^|[ \\t;&|(])(ba|z)?sh[ \\t]+-c[ \\t]/) gsub(/["\\047]/, " ", line)     # the shell runs the quoted text
        else { gsub(/"[^"]*"/, "\\"\\"", line); gsub(/\\047[^\\047]*\\047/, "\\047\\047", line) }
        s = raw
        while (match(s, /(^|[ \\t;&|(])cd[ \\t]+("[^"]*"|\\047[^\\047]*\\047|[^ \\t;&|)]+)/)) {
          d = substr(s, RSTART, RLENGTH); sub(/^[ \\t;&|(]*cd[ \\t]+/, "", d); print "DIR\\t" d; s = substr(s, RSTART + RLENGTH)
        }
        s = raw
        while (match(s, /git[ \\t]+-C[ \\t]+("[^"]*"|\\047[^\\047]*\\047|[^ \\t;&|)]+)/)) {
          d = substr(s, RSTART, RLENGTH); sub(/^git[ \\t]+-C[ \\t]+/, "", d); print "DIR\\t" d; s = substr(s, RSTART + RLENGTH)
        }
        if (!pushes && line ~ /(^|[;&|( \\t])git([ \\t]+(-C[ \\t]+[^ \\t;&|]+|-c[ \\t]+[^ \\t;&|]+|--[^ \\t;&|]+))*[ \\t]+commit([^A-Za-z0-9_-]|\$)/) commits = 1
        if (line ~ /(^|[;&|( \\t])git([ \\t]+(-C[ \\t]+[^ \\t;&|]+|-c[ \\t]+[^ \\t;&|]+|--[^ \\t;&|]+))*[ \\t]+push([^A-Za-z0-9_-]|\$)/ ||
            line ~ /(^|[;&|( \\t])gbg(dev)?([ \\t]+--dev)?[ \\t]+release([ \\t;&|]|\$)/) pushes = 1
      }
      END { if (pushes) print "PUSH"; if (pushes && commits) print "COMMITS" }')
    case "\$verdict" in *PUSH*) ;; *) exit 0 ;; esac

    # Which repository is pushed: the call's directory, moved by each `cd` and `-C` in turn.
    root=\$(cd "\${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 0
    where="\$here"
    while IFS="\$(printf '\\t')" read -r kind d; do
      [ "\$kind" = "DIR" ] || continue
      d=\${d#\\"}; d=\${d%\\"}; d=\${d#\\'}; d=\${d%\\'}
      case "\$d" in
        '\$CLAUDE_PROJECT_DIR'|'\${CLAUDE_PROJECT_DIR}') d="\${CLAUDE_PROJECT_DIR:-.}" ;;
        '~'|'~/'*) d="\$HOME\${d#\\~}" ;;
        '\$'*) d="" ;;
      esac
      [ -n "\$d" ] || { where=""; break; }
      case "\$d" in /*) where="\$d" ;; *) where="\$where/\$d" ;; esac
    done <<EOF
    \$verdict
    EOF
    if [ -n "\$where" ]; then
      target=\$(cd "\$where" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || target=""
      [ -n "\$target" ] && [ "\$target" != "\$root" ] && exit 0      # another repository's push: not this one's
    fi

    # A command that commits before it pushes is checked on the tree it is about to commit; any other push
    # while tracked files are uncommitted is stopped.
    case "\$verdict" in *COMMITS*) committing=1 ;; *) committing=0 ;; esac
    if [ "\$committing" = 0 ] && [ -n "\$(git -C "\$root" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
      echo "PUSH STOPPED: tracked files are uncommitted. The docs build reads the tree and the push sends the commit; commit first, then push." >&2
      exit 2
    fi
    cd "\$root" || exit 0
    log=\$(mktemp)
    if $build >"\$log" 2>&1; then
      rm -f "\$log"
      exit 0
    fi
    {
      echo "PUSH STOPPED: the docs build failed, and every push does the docs build (the owner, 2026-09-29)."
      echo "What it reported, every finding and error line:"
      grep -E '^  (RULE\\.|WIRING|CONFIG)|ERROR|Error' "\$log"
      echo "The whole output: \$log"
    } >&2
    exit 2
    """
end

# A word as a POSIX shell reads it literally: every consumer path holds spaces.
shell_quote(s::AbstractString) = occursin(r"^[A-Za-z0-9_./=+-]+$", s) ? String(s) : "'" * replace(String(s), "'" => "'\\''") * "'"

"""
    remedy(l) -> String

What fixes one wiring finding: `gbg sync` for a path this package writes, and an edit by the package for
the ones it only checks — its build script, its test entry point, its workflows. The argument is `l`, the
finding. Returns the phrase. Every finding said "run `gbg sync`" until 2026-09-28, which writes none of
the second kind (found wiring [GBGHomogeneousTurbulence](https://grigorysarnitsky.github.io/GBGHomogeneousTurbulence.jl/)).
"""
remedy(l::Model.Location) =
    (any(g -> g.path == l.file, GENERATED) || l.file == ".claude/settings.json") ? "run `gbg sync`" :
        "edit this file: `gbg sync` does not write it"

"""
    HOOK_COMMAND

The one line `.claude/settings.json` must carry for this package: the command that runs the end-of-turn
hook. It is matched literally, so a package may hold any number of other hooks beside it.
"""
const HOOK_COMMAND = "\"\$CLAUDE_PROJECT_DIR\"/.claude/hooks/queue-guard.sh"

"""
    PUSH_COMMAND

The line `.claude/settings.json` carries for the push hook, run before every shell command: see
[`push_gate`](@ref). A docs build takes minutes, so its entry allows an hour, far past Claude Code's
default of a minute, which would end the build and let the push through.
"""
const PUSH_COMMAND = "\"\$CLAUDE_PROJECT_DIR\"/.claude/hooks/push-gate.sh"
const PUSH_TIMEOUT = 3600

"""
    settings_drift(root) -> Union{String,Nothing}

What `.claude/settings.json` gets wrong about this package's two hooks in the package at `root`, or
`nothing`. The argument is `root`, the package root. Returns the fault, in words.

Only this package's own Stop hook is looked for. The file is the PACKAGE's — it may hold its own hooks,
its own permissions and its own settings — so a whole-file comparison would report every one of them as
drift, and writing the file whole would delete them. The hook is recognised by the script it runs, in
any spelling, and must be installed once in the one spelling written here: a second entry in another
spelling runs it twice per stop.
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
    ours = [get(h, "command", "") for entry in get(get(doc, "hooks", Dict{String,Any}()), "Stop", Any[])
            for h in get(entry, "hooks", Any[]) if runs_hook(get(h, "command", ""))]
    isempty(ours) && return "no Stop hook runs .claude/hooks/queue-guard.sh"
    ours == [HOOK_COMMAND] || return "the Stop hook running .claude/hooks/queue-guard.sh is not written once, as `gbg sync` writes it"
    push = [(entry, h) for entry in get(get(doc, "hooks", Dict{String,Any}()), "PreToolUse", Any[])
            for h in get(entry, "hooks", Any[]) if runs_push(get(h, "command", ""))]
    isempty(push) && return "no PreToolUse hook runs .claude/hooks/push-gate.sh"
    length(push) == 1 && get(first(push)[1], "matcher", "") == "Bash" &&
        get(first(push)[2], "command", "") == PUSH_COMMAND && get(first(push)[2], "timeout", 0) == PUSH_TIMEOUT &&
        return nothing
    return "the PreToolUse hook running .claude/hooks/push-gate.sh is not written once, as `gbg sync` writes it"
end

# Whether a hook command runs this package's hook, whatever its quoting: the entry's spelling changed
# once already, and a merge matching one literal spelling kept the old entry and added the new one.
runs_hook(command) = command isa AbstractString && occursin(r"(^|[/\"'\s])queue-guard\.sh$", rstrip(command, ['"', '\'', ' ']))
runs_push(command) = command isa AbstractString && occursin(r"(^|[/\"'\s])push-gate\.sh$", rstrip(command, ['"', '\'', ' ']))

"""
    write_settings(root) -> Bool

Installs this package's two hooks in `.claude/settings.json` in the package at `root`, keeping every
other hook and setting. The argument is `root`, the package root. Returns whether it
changed.

Every entry running the hook, in whatever spelling, is replaced by the one entry written here; the rest
of the `Stop` list stays, so a package that has its own stop hook keeps it and gets this one as well. A
file that does not parse is refused — a [`ConfigIO.ConfigError`](@ref), the consumer's exit 2 — rather
than rewritten, since the package's own settings would go with it.
"""
function write_settings(root::AbstractString)
    settings_drift(root) === nothing && return false
    path = joinpath(root, ".claude", "settings.json")
    doc = Dict{String,Any}()
    if isfile(path)
        doc = try
            JSON3.read(read(path, String), Dict{String,Any})
        catch err
            throw(ConfigIO.ConfigError(".claude/settings.json", ["the file does not parse: " * sprint(showerror, err)]))
        end
    end
    hooks = get!(doc, "hooks", Dict{String,Any}())
    stops = get!(hooks, "Stop", Any[])
    for entry in stops
        entry isa AbstractDict && haskey(entry, "hooks") && filter!(h -> !runs_hook(get(h, "command", "")), entry["hooks"])
    end
    filter!(entry -> !(entry isa AbstractDict && haskey(entry, "hooks") && isempty(entry["hooks"])), stops)
    push!(stops, Dict("hooks" => [Dict("type" => "command", "command" => HOOK_COMMAND)]))
    pres = get!(hooks, "PreToolUse", Any[])
    for entry in pres
        entry isa AbstractDict && haskey(entry, "hooks") && filter!(h -> !runs_push(get(h, "command", "")), entry["hooks"])
    end
    filter!(entry -> !(entry isa AbstractDict && haskey(entry, "hooks") && isempty(entry["hooks"])), pres)
    push!(pres, Dict("matcher" => "Bash",
                     "hooks" => [Dict("type" => "command", "command" => PUSH_COMMAND, "timeout" => PUSH_TIMEOUT)]))
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
released version with its compat bound or the path to the checkout.

# Arguments

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
right.

# Arguments

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
Pkg's own section order.

# Arguments

- `cfg` — the package's config, which carries the pin.
- `root` — the package root.
- `envdir` — the sub-environment.

Returns whether the file changed.

The file is written as Pkg writes it, by the TOML writer with Pkg's key order and inline `[sources]`
tables, so whatever else the environment holds — a `[targets]` list, a `description` — goes back as it came.
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
    inline = Base.IdSet{Dict}()
    for s in values(get(proj, "sources", Dict{String,Any}())); s isa Dict && push!(inline, s); end
    order = ["name", "uuid", "keywords", "license", "desc", "version", "workspace", "deps", "weakdeps",
             "sources", "extensions", "compat"]
    text = sprint(io -> TOML.print(io, proj; inline_tables = inline, sorted = true,
                                   by = k -> (something(findfirst(==(k), order), length(order) + 1), k)))
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
workflows at all. A workflow that runs no Julia step — TagBot, a linter — resolves nothing and is not told to
authenticate; one that runs Julia for any reason, CompatHelper included, is.
"""
function ci_drift(cfg::Model.Config, root::AbstractString)
    cfg.tool isa VersionNumber || return Model.Location[]
    dir = joinpath(root, ".github", "workflows")
    isdir(dir) || return Model.Location[]
    out = Model.Location[]
    for f in sort!(readdir(dir))
        (endswith(f, ".yml") || endswith(f, ".yaml")) || continue
        path = joinpath(".github", "workflows", f)
        text = read(joinpath(dir, f), String)
        (occursin("julia-actions/", text) || occursin("julia ", text)) || continue
        occursin("./.github/actions/gbg-auth", text) && continue
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
    (path = "test/runtests.jl", names = "Harness.test", calls = live -> harness_called(live),
     why = "the test suite runs no rule of the rulebook"),
    (path = "docs/make.jl", names = "GBGCodingTools.makedocs", calls = live -> occursin("GBGCodingTools.makedocs", live),
     why = "the documentation build runs no rule of the rulebook"),
]

"""
    harness_called(live) -> Bool

Whether the uncommented text `live` of a `runtests.jl` calls the harness: by its full name, or as
`Harness.test` once a `using` or `import` line has brought `GBGCodingTools.Engine`, or `Harness` out of
it, into scope. The argument is `live`, the text. Returns the answer.

Both are the same call. A check that knew the full spelling alone reported a suite that runs every rule
as running none (found in review, 2026-09-26).
"""
function harness_called(live::AbstractString)
    # `GBGCodingTools.Harness.test` is NOT accepted: no such binding exists, and accepting it passed the
    # wiring check for a suite that then threw (found verifying the review's fixes, 2026-09-27).
    occursin("GBGCodingTools.Engine.Harness.test", live) && return true
    occursin("Harness.test", live) || return false
    return any(eachsplit(live, '\n')) do l
        m = match(r"^\s*(?:using|import)\s+(.*)$", l)
        m === nothing && return false
        spec = m.captures[1]
        k = findfirst(':', spec)
        k === nothing ? occursin(r"\bGBGCodingTools\.Engine\b", spec) :
            occursin(r"\bGBGCodingTools\.Engine\s*$", spec[1:prevind(spec, k)]) && occursin(r"\bHarness\b", spec[k+1:end])
    end
end

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
        c.calls(live) && continue
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
     opening = "What a session runs or sends unasked, and how it reads what a scan prints."),
    (generator = :policy_git, path = ".gbg/policy/git-conventions.md", families = [:GIT],
     title = "Git conventions — `RULE.GIT.*`",
     opening = "What a commit carries, where it goes, and what is never committed."),
    # A family with no ancestor: nothing in the old tree checked how a person was addressed. These read a
    # question rather than a file, and they run at the moment one is put.
    (generator = :policy_asking, path = ".gbg/policy/asking.md", families = [:ASK],
     title = "Asking the owner — `RULE.ASK.*`",
     opening = "One decision, short, in his words rather than this package's, with every identifier moved out of the sentence."),
    # What a repository may not publish when it is made public; only `gbg leak` decides these (§3.1).
    (generator = :policy_publication, path = ".gbg/policy/publication.md", families = [:LEAK],
     title = "Publication — `RULE.LEAK.*`",
     opening = "What a repository may not publish when it is made public: no credential, nothing personal, nothing never meant for a reader."),
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
    println(io, "Covered by ", Catalogue.cover_words(rule), ".",
            rule.check === nothing && Catalogue.cover(rule) !== Catalogue.Cover.READER ?
                " Nothing checks it: " * rule.unchecked_reason : "")
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
four standing instructions a session needs before it has read anything. The argument is `cfg`, the
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

    Unasked, run `Pkg.test()` and nothing else; before every push the docs build runs too, through the
    push hook, and a failing build stops the push. What a rule finds is reported, never fixed silently:
    documentation may be fixed without asking, and anything else waits for an answer.

    The readers of a review are derived from the rules and the tool's catalogue of disciplines. A
    reader or a discipline this package needs and the tool lacks is requested of the tool, as a request
    file the owner has approved, never written here.

    A run an earlier session left open is continued before anything else, and the chat says so:
    `gbg run next` says what to launch or that the stage is ready to collect, and the run goes on to
    its close. It waits for the owner only when `gbg run next` says the tree moved since the launch.
    <!-- $END_MARK -->
    """
end


# The banner every page of a consumer's site carries, and this package's own rule requires on all of them.
const BANNER = "!!! info \"Written by AI, not regularly reviewed\"\n    This page is written by AI and is not reviewed regularly by a human.\n"

"""
    collisions(cfg, root) -> Vector{Pair{String,String}}

Every generated path the package at `root` already holds and did not get from a generator. The
arguments are `cfg`, the package's config, and `root`, the package root. Returns the path and its first
line, one pair each, empty when nothing collides.

A generated file says so in its first lines — the managed marker, or this package's name where the file
is a script that cannot carry one; a file at the same path saying neither is the package's own —
a CI workflow it wrote, a skill whose name one of its own commands already had. `gbg init` writes
everything else and stops on these, because a generated file silently replacing a hand-written workflow
is the one wiring mistake that is noticed late. Files this package merges into rather than writes whole
(`.claude/settings.json`) and files it only appends to (the work queue) cannot collide and are not here.
"""
function collisions(cfg::Model.Config, root::AbstractString)
    out = Pair{String,String}[]
    for g in GENERATED
        g.part === Model.Part.WHOLE && wanted(cfg, g) || continue
        full = joinpath(root, g.path)
        isfile(full) || continue
        text = read(full, String)
        generated_here(text) && continue              # it came from a generator, and is ours to rewrite
        push!(out, g.path => opening_line(text))
    end
    return out
end

opening_line(text::AbstractString) = isempty(text) ? "(empty)" : String(first(split(text, '\n')))

# Whether a file says, in its opening lines, that this package wrote it. The marker is what most
# generated files carry; the hook is a shell script whose first line must be its shebang, and it says so
# in the sentence under it instead. Only the opening is read: a file that MENTIONS the marker far below
# is discussing it, not claiming it.
generated_here(text::AbstractString) =
    any(l -> occursin(MANAGED_MARK, l) || occursin("Written by GBGCodingTools", l),
        first(split(text, '\n'), 5))

"""
    wanted(cfg, g) -> Bool

Whether the package configured by `cfg` is to have the generated part `g`. The arguments are `cfg` and
`g`, one entry of [`GENERATED`](@ref). Returns the answer.

Everything is wanted but the skill of an instrument switched off here or not built: a skill file is a
command a person can type, and one for an instrument that refuses to start invites an error message.
What is not wanted is deleted, and the wiring check reports one left behind.
"""
function wanted(cfg::Model.Config, g)
    startswith(String(g.generator), "skill_") || return true
    id = Symbol(SubString(String(g.generator), ncodeunits("skill_") + 1))
    return built(id) && Engine.Checks.applies(cfg, id)
end

# Whether an instrument's runs exist yet. The bug hunt's and the change audit's skills were written into
# every wired package while both refused to start, and a session told HT it had them (the owner, 2026-09-30).
built(id::Symbol) = only(i for i in Catalogue.INSTRUMENTS if i.id === id).built

"""
    skill_path(instrument) -> String

Where one instrument's skill file goes: `.claude/skills/<instrument>/SKILL.md`, the instrument's id with
its underscores as dashes, which is what a person types after the slash. The argument is `instrument`,
the instrument's id. Returns the path.
"""
skill_path(instrument::Symbol) = joinpath(".claude", "skills", replace(String(instrument), "_" => "-"), "SKILL.md")

"""
    leak_skill(cfg) -> String

The leak scan's skill: one program, `gbg leak`, and what a session does with what it prints. The argument
is `cfg`, the package's config. Returns the file's text.
"""
function leak_skill(cfg::Model.Config)
    i = only(x for x in Catalogue.INSTRUMENTS if x.id === :leak_scan)
    return """
    <!-- $BEGIN_MARK $(version_tag(cfg)) — rewritten by `gbg sync`; do not edit -->
    # /leak-scan

    $(i.purpose).

    Run it when the owner asks for it, and not otherwise; it ends after $(lowercase(first(i.ends, 1)) * SubString(i.ends, 2)).

    ## The steps

    1. `gbg leak` in the package, `gbg leak --all` for every package of this machine's fleet, with
       `--github` to read the GitHub side too — issues, pull requests, comments, release notes, workflow
       logs — which needs the network. Where Gitleaks is missing it says so: `gbg install --gitleaks`.
    2. Read what it printed, all of it: the count by rule and by file, every finding — its rule, where it
       is, a fingerprint — and what it could not read. A finding never shows the text it found, and the
       session does not go and read that text in: whatever a session reads, it sends to its model.
    3. Report to the owner in the session, and stop. What to do about each finding is his.

    ## What it may not do

    - It writes no tracked file: every writer of a record refuses text a leak scan printed.
    - It never removes a leak, from a file or from the history: a rewrite is the owner's to make, and a
      credential found is revoked, not only removed.
    - It never switches a `RULE.LEAK.*` rule off, nor approves an address in `leak_emails`: the owner does.

    <!-- $END_MARK -->
    """
end

"""
    skill(cfg, instrument) -> String

The skill file that runs one instrument: what it is for, and the exact sequence of verbs, ending in a
closed run. The arguments are `cfg`, the package's config, and `instrument`, the instrument's id.
Returns the file.

It carries NO rule and no judgement of its own. What a reader is given, which rules it checks and how
many passes there are follow from the rulebook and the instrument's own value, and the verbs print them
at each step; a skill that repeated any of it would be a second copy to reword. What it does hold is the
ORDER, because the order is not discoverable from any one verb: a session that stopped after collecting
would leave a run open, and the stage machine cannot start the driver itself.
"""
function skill(cfg::Model.Config, instrument::Symbol)
    instrument === :leak_scan && return leak_skill(cfg)
    i = only(x for x in Catalogue.INSTRUMENTS if x.id === instrument)
    name = replace(String(instrument), "_" => "-")
    fixes = i.budget.fix_passes > 0
    io = IOBuffer()
    println(io, "<!-- ", BEGIN_MARK, " ", version_tag(cfg), " — rewritten by `gbg sync`; do not edit -->")
    println(io, "# /", name, "\n")
    println(io, i.purpose, ".\n")
    println(io, """
    Run it when the owner asks for it, and not otherwise: nothing else starts a run. It ends when
    $(lowercase(first(i.ends, 1)) * SubString(i.ends, 2)).

    **Run it to its end in one sitting.** Every step below is one command, and the run is not finished
    until `gbg run close` has written its report. A run left open blocks the next one, and a session
    that stopped in the middle has spent its agents for nothing.

    ## The steps

    1. `gbg run $name` — opens the run and writes the first stage's arguments. Add `--readers open` or
       `--readers both` for the open readers, `--model <name>` to name the careful model, `--sequential`
       to launch one agent at a time. It refuses a tree with uncommitted changes to tracked files.
    2. Launch the agents with the `Workflow` call the verb just printed: the driver at the path it names,
       copied into the run's own scratch with the stage's arguments spliced in, so the call passes no
       args. Never the pinned package's own `drivers/run.js`, which `Workflow` refuses because it lies
       outside the working directory. Julia cannot launch an agent and only this session can, which is
       why the verb stopped here.
    3. Save what the `Workflow` RETURNED — the whole object — as `returned.json` in the stage's own
       directory, which the verb named: the collect falls back on it for an agent whose result file never
       appeared. Then `gbg run collect`, which reads what the agents wrote. Exit 2 means a role wrote
       nothing, or the tree moved under them; the first is relaunched once, the second is the owner's to
       answer.
    4. `gbg run cost <dir>` — records what the stage's agents cost, from the transcripts under the
       directory the `Workflow` result names (the one holding its `journal.jsonl`). The launch's own
       token figure counts a tenth of the real cost; the transcripts are the source. Then
       `gbg run next`, which moves to the next stage and says what it wants. Repeat 2 to 4 until it says
       the run is ready to close.""")
    if fixes
        println(io, """
    5. At a FIX stage it writes the open findings instead of launching agents. Fix each in the
       documentation and commit it with `gbg docfix commit --message "…" --finding <id>`, which asks the
       change guard first and refuses a change that breaks a rule the run opened clean on; it also names
       every cross-reference it cannot resolve, as a warning. Never edit code or the config here, and
       never change a formula — what the page renders as mathematics;
       turning a code span into a math span with the same text, or back, is the one respelling allowed.
       A finding whose fix needs any of those is PARKED for the owner with
       `gbg run park <id> --why "<what it would change>"`: a question about it stands, and no pass works
       on it until he answers. `gbg run next` then builds the site, and a red build names the pass's
       commits that touched the files it complains about: fix those with further docfix commits. One
       verifier per place then judges the pass's fixes with the diff; a pass that committed nothing
       closes the run instead.
    6. `gbg run close` — writes the record and the report, and puts what is still open on the owner's
       work queue. COMMIT `.gbg/runs/<id>/` yourself, and `.gbg/questions.json` if it changed:
       `gbg docfix commit` leaves both out on purpose, and nothing else commits them. A fix may grow a unit of prose by a small allowance — ten words, or five
       percent — and the close re-records what grew in the prose-shape baseline: commit that file with
       the record. More than the allowance is refused inside a run, as a code change would be. A run ENDED EARLY with `gbg run abandon` keeps its
       record only if an agent RAN, and is committed the same way; one that launched nothing is deleted by the
       verb, id and all, and any findings it was carrying go back to the run that found them.""")
    else
        println(io, "5. `gbg run close` — writes the record and the report.")
    end
    println(io, """
    ## What it may not do

    - It never starts another run, never raises the budget, and never edits the instrument.
    - It never fixes what it was not asked to fix: $(i.intention === Model.Intention.DOCUMENTATION ?
      "this instrument's findings are documentation's, and a code defect becomes a question" :
      "this instrument reports and grades; the code is changed only on the owner's answer").
    - `gbg run abandon` ends a run the owner does not want continued. Its findings are dropped.
    """)
    println(io, "<!-- ", END_MARK, " -->")
    return String(take!(io))
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
    - **deferral** — a package saying a rule is owed here and not yet met, with what would close it. A
      switch is an answer; a deferral is a question with a condition on it. It fails no build.
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
    - **operation family** — an operation together with its variants: the allocating and in-place
      forms, a getter and its setter, the methods of one name across representations. A module map
      lists one entry per family; the family's home docstring is the one `RULE.DOC.ONE_HOME` names.
    - **instrument** — one review procedure with one question, started only on the owner's request.
    - **run** — one execution of one instrument, with its own record, its own report and its own id.
      A run never starts another.
    - **stage** — one step of a run, in a fixed order. The session launches each; a stage out of order
      is refused.
    - **reader** — an agent given some of the documentation and asked what is wrong with it. Which
      readers a review has follows from the rules, not from a list.
    - **bundle** — what a reader is given: one built page alone, the whole documentation with the
      source, or the built site. A rule's tag says which bundle can judge it.
    - **unit** — the one page a reader of the first bundle is given. That reader is launched once per
      unit, so that what it cannot see is what the rule needs it not to see.
    - **pass** — one round of fixing and verifying inside a run. A documentation review makes one,
      after which what is still open goes to the owner's queue.
    - **verifier** — an agent that judges whether the fixes of one place fixed their findings, with
      the text as it now stands and the diff of the pass in front of it.
    - **cover** — what decides a rule is broken: a program, a reader, or nothing, the last being an
      instruction the session follows while working.
    - **discipline** — a field of expertise a package declares it needs a reader to have. A rule naming
      a discipline the package does not declare is a gap.
    - **gap** — a rule no reader of this package can be given what it needs to judge. A run says so at
      every launch and first in its report.
    - **settled** — a decision the owner has already given, kept in `.gbg/settled.jl` and given to every
      reader as "do not report this again".
    <!-- gbg:managed end -->
    """
end

"""
    switches(cfg) -> String

What this package has switched off, and why: one entry per `Switch` in its config, then what it has
deferred — owed and not yet met, each with what would close it — and a rule a package adds for itself
listed after them. The argument is `cfg`, the package's config. Returns the file.

A switch is read as part of the rulebook: a session that has loaded the rules has loaded what this
package does not hold itself to, which is the only way a rule can be escaped.
"""
function switches(cfg::Model.Config)
    io = IOBuffer()
    println(io, "<!-- gbg:managed begin ", version_tag(cfg), " — rewritten by `gbg sync`; do not edit -->")
    println(io, "# What ", cfg.package, " has switched off\n")
    if isempty(cfg.switches)
        println(io, isempty(cfg.exclusions) ? "Nothing. Every rule of the rulebook applies here as written.\n" :
                                              "No rule is switched off; the files below are read by none.\n")
    else
        println(io, "Each entry names a rule this package does not hold itself to, and why. A rule listed")
        println(io, "here is read as the entry states it.\n")
        for s in cfg.switches
            scope = isempty(s.files) ? "the whole package" : join("`" .* s.files .* "`", ", ")
            println(io, "- `", s.target, "` — ", s.reason, " (", scope, ")")
        end
        println(io)
    end
    if !isempty(cfg.exclusions)
        println(io, "Excluded from every rule: no rule reads these files, and no reader is given them.\n")
        for e in cfg.exclusions
            println(io, "- ", join("`" .* e.files .* "`", ", "), " — ", e.reason)
        end
        println(io)
    end
    if !isempty(cfg.deferrals)
        println(io, "Deferred, not switched off: each of these is owed here and not yet met, and reports nothing")
        println(io, "until the package meets it. What would close each is stated.\n")
        for d in cfg.deferrals
            println(io, "- `", d.rule, "` — until ", d.until)
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
    TOOLING_PAGE

Where `pages` writes the one page a consumer's site carries about this tool, relative to the package
root.
"""
const TOOLING_PAGE = "docs/src/gbg.md"

"""
    RULES_PAGE

Where `rulebook_page` writes the rulebook, relative to the package root. Only this package's own site
calls it; a consumer's page links here instead.
"""
const RULES_PAGE = "docs/src/gbg-rules.md"

"The address of this package's own site, which a consumer's tooling page links to."
const TOOL_SITE = "https://grigorysarnitsky.github.io/GBGCodingTools.jl/"

"""
    RULES_URL

The published rulebook on this package's site, which a consumer's tooling page links to. Documenter
publishes under a version directory — `dev/` from `master`, and `stable/` only once a release is
tagged, which none yet is — so the page is under `dev/`; the address without it answered 404 on every
consumer's site (found upgrading [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/), 2026-09-24).
"""
const RULES_URL = TOOL_SITE * "dev/gbg-rules/"

"""
    pages(cfg, root) -> Vector{String}

Writes the ONE page a consumer's site carries about this tool, and returns its path relative to
`docs/src/`, which is the form a `docs/make.jl` lists in its `pages`. The arguments are `cfg`, the
package's config, and `root`, the package root.

The page is small by ruling [2026-09-23]: a line saying what the documentation is held to, a link to
this package's own site where the rulebook lives, and what this package has customised against the
defaults — every switch with its reason, and any rule it adds for itself. Nothing else. This tool is
the instrument of the package's developer, and its workings are of no concern to the package's users;
the page exists only so that an override is on the record where a reader of the documentation can find
it, and it belongs under the site's design or internals section, never among the main pages.

Until that ruling the generator wrote three pages — the whole rulebook with an anchor per rule, a
readers page and an instruments page — and a physics library's site had three of its ten top-level
entries describing review tooling. The rulebook is still rendered, by [`rulebook_page`](@ref), on this
package's own site alone, which is what the link here points at.

The page is written at BUILD time and belongs in the package's `generated` list, so that no rule reads
it and no fixer edits it.
"""
function pages(cfg::Model.Config, root::AbstractString)
    io = IOBuffer()
    println(io, "# [Documentation tooling](@id gbg)\n")
    println(io, BANNER)
    println(io, "The documentation of ", cfg.package, " is held to the rulebook of ",
                "[GBGCodingTools](", TOOL_SITE, ") ", version_tag(cfg), ": a documentation rubric, the")
    println(io, "LaTeX idiom, the citation style, and a testing protocol. The rules themselves are on")
    println(io, "[that package's site](", RULES_URL, "), each under a stable id. What follows is only")
    println(io, "what this package does differently from the defaults.\n")
    # The switches and the package's own rules, from the same generator that writes them into the
    # rulebook a session loads, so the page and the rulebook cannot disagree; its markers are dropped
    # and its heading sits under this page's own.
    for line in split(switches(cfg), '\n')
        (occursin(BEGIN_MARK, line) || occursin(END_MARK, line)) && continue
        println(io, startswith(line, "# ") ? "#" * line : line)
    end
    full = joinpath(root, TOOLING_PAGE)
    mkpath(dirname(full))
    write(full, String(take!(io)))
    return [relpath(TOOLING_PAGE, "docs/src")]
end

"""
    rulebook_page(cfg, root) -> Vector{String}

Writes the rulebook as a page — every rule with its statement, reason and check, grouped by what covers
it, each under an anchor named by its id, with the glossary and this package's switches — and returns
its path relative to `docs/src/`. The arguments are `cfg`, the package's config, and `root`, the
package root.

Only this package's own `docs/make.jl` calls it [ruled 2026-09-23]: the rulebook is this tool's to
publish, and a consumer's site links here rather than carrying a copy. The anchors are what make a rule
id linkable from anywhere, and keeping them in one place is what keeps the links from multiplying.

A page that states the rules is by construction full of text that breaks them — it quotes the banned
spellings in order to ban them — so it is written at BUILD time and is in this package's `generated`
list, where no rule reads it.
"""
function rulebook_page(cfg::Model.Config, root::AbstractString)
    io = IOBuffer()
    println(io, "# [The rules ", cfg.package, " is held to](@id gbg-rules)\n")
    println(io, "!!! info \"Written by AI, not regularly reviewed\"\n    This page is written by AI and is not reviewed regularly by a human.\n")
    println(io, "Generated at build time from the rule values in GBGCodingTools ", version_tag(cfg),
                ". Each rule carries its own check and the examples that show the check matches it, so this")
    println(io, "text and the program that enforces it cannot disagree. A rule's id is stable and is what a")
    println(io, "finding, a switch and a report all name.\n")
    # Every rule gets an anchor under its own id, so a finding elsewhere on the site can link to the rule
    # that produced it; every other heading drops a level to sit under this page's own.
    relevel(line) = (m = match(r"^### (RULE\.[A-Z]+\.[A-Z_]+)\s*$", line);
                     m !== nothing ? "#### [`" * m.captures[1] * "`](@id " * m.captures[1] * ")" :
                     startswith(line, "#") ? "#" * line : line)
    # The rules are grouped by what covers them (ruled 2026-09-21): a program, a reader, or the session
    # following an instruction — so a reader of the page sees at once which rules something finds broken.
    groups = [(Catalogue.Cover.PROGRAM, "Checked by a program",
               "These run in every build and every test of the package; a breach is a red build."),
              (Catalogue.Cover.READER, "Judged by a reader",
               "No program can decide these. A documentation review hands each to the reader given what it needs; a rule needing more than any reader is given is reported as not judged."),
              (Catalogue.Cover.INSTRUCTION, "Instructions to the session",
               "These are followed while working and checked by nothing: they tell a session how to commit, what to run unasked, and how to read what a scan prints.")]
    for (c, title, opening) in groups
        rules = sort([r for r in Catalogue.RULES if Catalogue.cover(r) === c], by = r -> String(r.id))
        println(io, "## ", title, " — ", length(rules), "\n")
        println(io, opening, "\n")
        for r in rules
            for line in split(rule_section(r), '\n'); println(io, relevel(line)); end
            println(io)
        end
    end
    for path in (".gbg/policy/glossary.md", ".gbg/policy/switches.md")
        body = produce(only(g.generator for g in GENERATED if g.path == path), cfg)
        for line in split(body, '\n')
            (occursin(BEGIN_MARK, line) || occursin(END_MARK, line)) && continue
            # The glossary binds the terms every rule uses, so the rest of a site links to it by name.
            g = match(r"^# (Glossary)\s*$", line)
            g !== nothing && (println(io, "## [Glossary](@id glossary)"); continue)
            println(io, relevel(line))
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
generator writes it today — the rulebook files from [`POLICY_FILES`](@ref), and one skill per
instrument of the catalogue — so the wiring check holds exactly what is generated.
"""
const GENERATED = [
    (path = ".gitignore",                  part = Model.Part.BLOCK,        generator = :gitignore),
    (path = ".claude/hooks/queue-guard.sh", part = Model.Part.WHOLE,       generator = :hook),
    (path = ".claude/hooks/push-gate.sh",  part = Model.Part.WHOLE,        generator = :push_gate),
    (path = "test/regressions/README.md",  part = Model.Part.WHOLE,        generator = :regressions_note),
    (path = "CLAUDE.md",                   part = Model.Part.BLOCK,        generator = :claude_block),
    (path = CI_ACTION,                     part = Model.Part.WHOLE,        generator = :ci),
    (path = ".gbg/policy/00-index.md",     part = Model.Part.WHOLE,        generator = :policy_index),
    (path = ".gbg/policy/glossary.md",     part = Model.Part.WHOLE,        generator = :glossary),
    (path = ".gbg/policy/switches.md",     part = Model.Part.WHOLE,        generator = :switches),
    (map(e -> (path = e.path, part = Model.Part.WHOLE, generator = e.generator), POLICY_FILES))...,
    (map(i -> (path = skill_path(i.id), part = Model.Part.WHOLE, generator = Symbol("skill_", i.id)),
         Catalogue.INSTRUMENTS))...,
]

"""
    produce(name, cfg) -> String

What one generator writes now. The arguments are `name`, the generator's name as the register holds it,
and `cfg`, the package's config. Returns the content.
"""
function produce(name::Symbol, cfg::Model.Config)
    name === :gitignore && return gitignore(cfg)
    name === :hook && return hook(cfg)
    name === :push_gate && return push_gate(cfg)
    name === :regressions_note && return regressions_note(cfg)
    name === :policy_index && return policy_index(cfg)
    name === :glossary && return glossary(cfg)
    name === :switches && return switches(cfg)
    name === :claude_block && return claude_block(cfg)
    name === :ci && return ci(cfg)
    for e in POLICY_FILES
        name === e.generator && return policy_file(cfg, e)
    end
    for i in Catalogue.INSTRUMENTS
        name === Symbol("skill_", i.id) && return skill(cfg, i.id)
    end
    error("no generator named $name")
end

"""
    block_spans(lines) -> Vector{UnitRange{Int}}

Where the marked blocks are in a file this package shares with the package that owns it: one range of
line numbers per block, from its begin marker to its end marker. The argument is `lines`, the file's
lines. Returns the ranges, in order; a file holds one block when it is wired, and a second is drift.
"""
function block_spans(lines::AbstractVector{<:AbstractString})
    spans = UnitRange{Int}[]
    i = 1
    while (b = findnext(is_begin, lines, i)) !== nothing
        e = findnext(is_end, lines, b + 1)
        e === nothing && break
        push!(spans, b:e); i = e + 1
    end
    return spans
end

"""
    block_of(text) -> Union{String,Nothing}

The marked block inside a file this package shares with the package that owns it, or `nothing` where the
file holds none. The argument is `text`, the file's content. Returns the first block, markers included.
"""
function block_of(text::AbstractString)
    lines = split(text, '\n')
    spans = block_spans(lines)
    isempty(spans) && return nothing
    return join(lines[first(spans)], '\n') * "\n"
end

"""
    with_block(text, want) -> String

The file `text` with its marked block replaced by `want`, and every further block removed: a block
this package wrote twice is one block's worth of stale text, not the package's own. The arguments are
`text`, the file, and `want`, the block to write. Returns the new file; one with no block yet gets it at
its head.

By lines, never by substring: the block is compared with a trailing newline, and a file whose block
ended it without one matched nothing and could not be repaired (found in review, 2026-09-26).
"""
function with_block(text::AbstractString, want::AbstractString)
    lines = split(text, '\n')
    spans = block_spans(lines)
    # A file that has no block yet gets one at its HEAD, not its foot. `CLAUDE.md`'s block carries the
    # import of the rulebook, and a session reads that file from the top: appended to a 2,700-line file
    # it is read last or not at all. `.gitignore` does not care, and the head is right there too.
    isempty(spans) && return want * "\n" * text
    out = String[]
    for (i, l) in enumerate(lines)
        i == first(first(spans)) && append!(out, split(chomp(want), '\n'))
        any(s -> i in s, spans) && continue
        push!(out, l)
    end
    return join(out, '\n')
end


# ─────────────────────────────────────────────────────────── what a run hands back to the owner

"""
    report(run, cfg; root = "", queued = 0, undone = 0, red = false) -> String

What one run found, as the page the owner reads.

# Arguments

- `run` — the finished run.
- `cfg` — the package's config.
- `root` — the package root, for the documents no reader was given; empty to skip them.
- `queued` — how many lines went to the work queue.
- `undone` — how many fixes were reverted because the docs build was red at close.
- `red` — whether the build was red at close with no fix to account for it.

Returns the Markdown.

It reports the WHOLE run, the parts that did not work included: a stage that could not be evaluated, a
location that could not be found again, a budget that ran out with findings still open. A report that
printed only what went well would make the two endings — nothing left to do, and no budget left to do it
with — read the same.

It keeps no second list of leftovers. What is owed goes to the package's work queue, one line each, and
the report says how many went and names the record, so the two cannot disagree about the count.
"""
function report(run::Model.Run, cfg::Model.Config; root::AbstractString = "", queued::Int = 0,
                undone::Int = 0, red::Bool = false)
    io = IOBuffer()
    println(io, "# ", titlecase(replace(String(run.instrument), "_" => " ")), " — ", run.id)
    println(io)
    # The provenance banner, taken from the RULE that defines it rather than copied: a report is a page
    # like any other, and a second copy of the banner here is the drift that rule exists to catch.
    println(io, Catalogue.Pages.BANNER)
    println(io)
    println(io, "Run `", run.id, "` of `", cfg.package, "`, by GBGCodingTools ", run.tool_version,
            ", from commit `", first(run.first_commit, 8), "`.")
    println(io)

    # The ending first, because it decides how the rest is read: findings still open after a spent
    # budget are not the same as none.
    ended = run.stop === Model.Stop.DONE ? "It ran to the end." :
            run.stop === Model.Stop.CANNOT_EVALUATE ? "**It could not be evaluated.** A step exited 2 or 3, and an instrument is never repaired inside a run." :
            "**The owner stopped it.**"
    println(io, ended, " It launched ", run.agent_launches, " agent(s), with the ",
            run.readers === :both ? "bound and open" : String(run.readers), " readers, and made ",
            run.passes, " of ", run.budget.fix_passes, " fix pass(es).",
            queued > 0 ? " $queued line(s) went to the work queue, under the heading the end-of-turn hook does not count." : "")
    println(io)
    if !isempty(run.usage)
        # What it cost, from the agents' own transcripts; the launch's summary field is not used, since it
        # counts a tenth of the cache activity where nearly all of the cost is.
        println(io, "| Stage | Pass | Agents | Cache write | Cache read | Input | Output |")
        println(io, "|---|---|---|---|---|---|---|")
        for u in run.usage
            println(io, "| ", u.stage, " | ", u.pass, " | ", u.agents, " | ", u.cache_write, " | ", u.cache_read,
                    " | ", u.input, " | ", u.output, " |")
        end
        println(io)
        println(io, "Tokens, summed from each agent's transcript by `gbg run cost`.")
        println(io)
    end
    if !isempty(run.silent)
        # A reader that wrote nothing is not a clean reader, and the report says which (found in review,
        # 2026-09-23: collect said the report would name them, and it did not).
        println(io, "!!! warning \"Readers that wrote nothing\"\n    ", length(run.silent),
                " agent(s) wrote nothing readable, even launched a second time: ", join(run.silent, ", "),
                ". What they were to judge was not judged.\n")
    end
    if undone > 0
        println(io, "!!! warning \"The documentation was put back\"\n    The docs build was red when this run closed, so ",
                undone, " of its fixes were reverted through the guard. What they were for is open again.\n")
    end
    if red
        println(io, "!!! warning \"The site does not build\"\n    The docs build was red at close and no fix of this run accounts for it. Nothing here was judged against a built site.\n")
    end

    # What no reader of this package could judge, before the findings: a report with no finding under
    # a rule nobody read must not read as a pass of that rule.
    gaps = vcat(last(Catalogue.panel(run.instrument, cfg)),
                isempty(root) ? String[] : Catalogue.missing_documents(cfg, root))
    if !isempty(gaps)
        println(io, "## Not judged — ", length(gaps))
        println(io)
        println(io, "No reader of this package was given what these need. Nothing below says anything about them.")
        println(io)
        for g in gaps; println(io, "- ", g); end
        println(io)
    end

    if run.dropped > 0
        # STOPPED IS NOT CLEAN, and the record alone cannot tell them apart without this number: what
        # was open when the owner stopped is gone from the list and the launch count is untouched.
        # Reported whenever anything was thrown away, kept findings or not — an abandon that kept one
        # fixed finding and dropped another said nothing about the second (found in review, 2026-09-23).
        println(io, "## ", run.dropped, " finding(s) were thrown away")
        println(io)
        gone = [f for f in run.findings if f.id in run.dropped_ids]
        if isempty(gone)
            # a record from before the texts were kept (ruled 2026-09-26)
            println(io, "The owner stopped this run, so what its readers reported was dropped and none of it")
            println(io, "is written down here. This page says NOTHING about ", cfg.package,
                        ": it was looked at, something was")
            println(io, "seen, and nobody stood behind it. Whatever it was opened to look for is still open.")
        else
            println(io, "The owner stopped this run. What its readers reported and nobody had yet stood behind")
            println(io, "is carried into no later run; it is listed here so that a triage can name it.")
            println(io)
            for f in gone
                l = isempty(f.draft.locations) ? nothing : f.draft.locations[1]
                println(io, "- `", f.id, "` ", f.draft.claim,
                        l === nothing ? "" : " — `" * l.file * "`" * (l.line > 0 ? ":" * string(l.line) : ""))
            end
        end
        println(io)
    end
    if isempty(run.findings) && run.dropped > 0
        nothing                                             # said above; nothing was kept to list
    elseif isempty(run.findings) && run.agent_launches == 0
        # NOTHING READ is not NOTHING FOUND. A run that launched no agent has no evidence about this
        # package at all, and a report saying its documentation was read and found clean — under the
        # banner, on a page anyone may open — is worse than no report. This is the dead-lane-read-as-clean
        # failure the instrument exists to prevent, appearing in the instrument's own output; the driver
        # already refuses to read silence as a clean result one level down, and the close did not apply
        # that rule to a run whose silence was total. Found by GBGPeriodicFields on two abandoned runs,
        # 2026-09-22.
        println(io, "## Nothing was read")
        println(io)
        println(io, "No agent was launched, so this run says NOTHING about ", cfg.package,
                    ": not that it is clean, not that it is not. Whatever it was")
        println(io, "opened to look for has not been looked for.")
    elseif isempty(run.findings)
        println(io, "## Nothing was found")
        println(io)
        println(io, isempty(run.silent) ? "Every reader that was launched wrote its file, and none of them reported a defect." :
                    "Every reader that wrote reported no defect; the ones named above wrote nothing, so this is not a clean result.")
    else
        # What was found in the WORKING NOTES comes first and apart (ruled 2026-09-23): a reader given
        # the design documents as material to consult found something there. It was never a fixer's —
        # those documents are not targets of the review — and it may be the most valuable line on the
        # page, a formula the API's docstrings copy. It is the owner's to read.
        notes = [f for f in run.findings if f.draft.in_material]
        if !isempty(notes)
            println(io, "## In the working notes — ", length(notes))
            println(io)
            println(io, "Found in documents the readers were given to consult and not to judge. Nothing here was")
            println(io, "fixed or verified; each is for the owner, with the reader's own words.")
            println(io)
            for f in notes
                println(io, "### ", f.id, "  ", f.draft.claim)
                println(io)
                println(io, "Reported by `", f.source, "`.")
                println(io)
                isempty(f.draft.evidence) || (println(io, f.draft.evidence); println(io))
                for l in f.draft.locations
                    println(io, "- `", l.file, "`", isempty(l.text) ? "" : "  \"" * l.text * "\"")
                end
                println(io)
            end
        end
        judged = [f for f in run.findings if !f.draft.in_material && !(f.id in run.dropped_ids)]   # the dropped are listed above
        println(io, "## Findings — ", length(judged))
        println(io)
        isempty(judged) && println(io, "None in the targets: every reader that was launched wrote its file, and none reported a defect in a document under review.\n")
        for f in judged
            println(io, "### ", f.id, "  ", f.draft.claim)
            println(io)
            f.draft.rule === nothing || println(io, "Rule: `", f.draft.rule, "`.  ")
            println(io, "Reported by `", f.source, "`, decided by ",
                    f.decider === Model.Decider.PROGRAM ? "a program" :
                    f.decider === Model.Decider.FAILING_TEST ? "a failing test" : "an agent",
                    startswith(f.id, run.id) ? "." : "; carried over from an earlier run, which left it open.")
            println(io)
            isempty(f.draft.evidence) || (println(io, f.draft.evidence); println(io))
            isempty(f.draft.fix) || (println(io, "**Fix.** ", f.draft.fix); println(io))
            f.draft.maybe_code && println(io, "!!! warning \"The code may be what is wrong\"\n    The reader believed the documentation and the code disagree, and that the code is the wrong half. That is a question for the owner, not a documentation fix.\n")
            for l in f.draft.locations
                stale = l.found === Model.Anchor.OUTDATED
                println(io, "- `", l.file, "`", l.line > 0 ? ":" * string(l.line) : "",
                        isempty(l.node) ? "" : "  (" * l.node * ")",
                        stale ? "  — **the text here has moved and was not found again**" : "")
            end
            # The passes, as a program graded them: the verifier's verdict, a second one where a record
            # from before 2026-09-26 carries it, and what the program did to the verdict.
            for x in run.fixes
                x.finding == f.id || continue
                println(io, "- pass ", x.pass, ": verifier `", x.blind, "`",
                        x.with_diff === nothing ? "" : ", with the diff `" * string(x.with_diff) * "`",
                        isempty(x.commit) ? "" : "  (commit `" * first(x.commit, 8) * "`)",
                        isempty(x.note) ? "" : " — " * x.note)
            end
            println(io)
        end
    end

    stale = [(f, l) for f in run.findings for l in f.draft.locations if l.found === Model.Anchor.OUTDATED]
    if !isempty(stale)
        println(io, "## Locations that could not be found again — ", length(stale))
        println(io)
        println(io, "The text each of these named has changed since it was read. They are named rather than")
        println(io, "pointed at whatever now sits on the old line, and no fix was attempted at any of them.")
        println(io)
    end

    if !isempty(run.questions)
        println(io, "## Questions")
        println(io)
        for q in run.questions
            println(io, "### ", q.id)
            println(io)
            println(io, q.decision)
            println(io)
            isempty(q.context) || (println(io, q.context); println(io))
            for o in q.options
                println(io, "- **", o.label, "**", o.recommended ? " (recommended)" : "", " — ", o.consequence)
            end
            for i in q.items
                println(io, "  * ", i.text)
            end
            # §8: a question that fails the language rules is shown with the failed rule named, in the
            # report the owner reads and not only in the terminal it was put from (verified 2026-09-27)
            failed = Engine.Questions.report(q, cfg)
            isempty(failed) || (println(io); println(io, "This question does not read as the rules ask:"); println(io); println(io, "```"); print(io, failed); println(io, "```"))
            println(io)
            # an answered question says what the owner decided, and stops asking
            q.answer === nothing ? println(io, "Answer with: `gbg answer ", q.id, " \"<option>\"`") :
                                   println(io, "**Answered:** ", q.answer, isempty(q.direction) ? "" : " — " * q.direction)
            println(io)
        end
    end
    return String(take!(io))
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
        if !wanted(cfg, g)
            isfile(full) && generated_here(read(full, String)) && push!(out, Model.Location(; file = g.path,
                text = built(Symbol(SubString(String(g.generator), ncodeunits("skill_") + 1))) ?
                       "this instrument is switched off here and keeps no skill file" :
                       "this instrument is not built yet and keeps no skill file"))
            continue
        end
        want = produce(g.generator, cfg)
        if !isfile(full)
            push!(out, Model.Location(; file = g.path, text = "the file is absent"))
            continue
        end
        text = read(full, String)
        if g.part === Model.Part.BLOCK
            n = length(block_spans(split(text, '\n')))
            n == 0 && (push!(out, Model.Location(; file = g.path, text = "the managed block is absent")); continue)
            n > 1 && (push!(out, Model.Location(; file = g.path, text = "the managed block appears $n times")); continue)
        end
        have = g.part === Model.Part.BLOCK ? block_of(text) : text
        if have != want
            push!(out, Model.Location(; file = g.path, line = first_difference(have, want),
                                       text = "this file is not what `gbg sync` writes now"))
        elseif g.generator in (:hook, :push_gate) && !Sys.isexecutable(full)
            # the mode is part of the file: a hook Claude Code cannot exec guards nothing
            push!(out, Model.Location(; file = g.path, text = "the hook is not executable"))
        end
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
    write_all(cfg, root) -> (changed, refused)

Writes every generated path of the package at `root`, sets the pin in each sub-environment, and returns
the paths it changed and the paths it refused. The arguments are
`cfg`, the package's config, and `root`, the package root. A marked block is replaced inside the file that
holds it and the rest of that file is left alone; anything else is written whole.

A whole file at a generated path that did not come from a generator is the package's own, and is
refused — returned with its first line, and never written over — as `gbg init` refuses it before
writing anything. `gbg sync` wrote over it, so a path a newer version generates replaced a hand-written
file on upgrade (found in review, 2026-09-26).
"""
function write_all(cfg::Model.Config, root::AbstractString)
    changed = String[]; refused = Pair{String,String}[]
    for g in GENERATED
        full = joinpath(root, g.path)
        if !wanted(cfg, g)
            isfile(full) && generated_here(read(full, String)) || continue
            rm(full; force = true)                       # a switched-off or unbuilt instrument keeps no skill
            isdir(dirname(full)) && isempty(readdir(dirname(full))) && rm(dirname(full))
            push!(changed, g.path)
            continue
        end
        want = produce(g.generator, cfg)
        mkpath(dirname(full))
        if g.part === Model.Part.BLOCK && isfile(full)
            text = read(full, String)
            new = with_block(text, want)
            new == text && continue
            write(full, new)
        elseif isfile(full)
            have = read(full, String)
            generated_here(have) || (push!(refused, g.path => opening_line(have)); continue)
            if have == want
                # the content is right; the mode may not be, and the hook's mode is part of it
                (g.generator in (:hook, :push_gate) && !Sys.isexecutable(full)) || continue
            else
                write(full, want)
            end
        else
            write(full, want)
        end
        g.generator in (:hook, :push_gate) && chmod(full, 0o755)
        push!(changed, g.path)
    end
    write_settings(root) && push!(changed, ".claude/settings.json")
    for envdir in SUBENVS
        write_pin(cfg, root, envdir) && push!(changed, joinpath(envdir, "Project.toml"))
    end
    return (changed = changed, refused = refused)
end

end # module Render
