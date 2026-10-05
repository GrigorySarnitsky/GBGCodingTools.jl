# The design's §7; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.Records

The two rules that name the tool's own records: `RULE.GIT.RECORDS`, that they are committed, and
`RULE.GIT.TRACKED`, that nothing but a package's own files and these is. Both read git, which no build
or test runs, so the scan that keeps review state out of every other rule's file exempts this one, and
a test holds the exemption to that fact.
"""
module Records

using ...Model
using ..JudgementGit: hooked, REPO, TRAILER

# A record the tool keeps for the owner, left uncommitted, exists on one machine only: GBGPeriodicFields'
# question store, holding two of his answers, sat untracked from 2026-09-22 through two runs and two
# upgrades, and nothing said so (PF's report, 2026-10-02). An open run's directory is committed at its
# close, and the hook stops at an open run before it reaches these rules; `gbg check` skips it here.
const RECORDS_HOOK = raw"""
git rev-parse --git-dir >/dev/null 2>&1 || return 0
seen=""
while IFS= read -r line; do
  p=${line:3}
  case "$p" in
    .gbg/runs/*) d=${p#.gbg/runs/}; d=".gbg/runs/${d%%/*}"
                 [ -f "$d/stage" ] && [ ! -f "$d/run.json" ] && continue
                 case " $seen " in *" $d "*) continue ;; esac
                 seen="$seen $d"; p="$d/" ;;
  esac
  echo "$p is a record the tool keeps for the owner, not committed: commit it"
done < <(git status --porcelain --untracked-files=all -- .gbg/questions.json .gbg/runs 2>/dev/null)
return 0
"""

const RECORDS = Model.Rule(
    id = Symbol("RULE.GIT.RECORDS"),
    statement = "A record the tool keeps for the owner — `.gbg/questions.json`, and a closed run under `.gbg/runs/` — is committed, never left untracked or modified; an open run's is committed at its close.",
    why = "It holds the owner's rulings and the runs' findings. Uncommitted, they exist on one machine only, and a session on the other neither sees them nor knows that a question's id is taken. No verb commits it: `gbg answer` and the review's skill say so, and the session commits.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.HISTORY, hooked(RECORDS_HOOK), false),
    hook = RECORDS_HOOK,
    examples = [
        Model.HistoryExample(REPO * "mkdir -p .gbg && echo '[]' > .gbg/questions.json\n",
                             [Model.Location(; file = "", line = 0)], "is committed"),
        Model.HistoryExample(REPO * "mkdir -p .gbg && echo '[]' > .gbg/questions.json && git add .gbg/questions.json && " *
                             "git commit -q -m 'the store$TRAILER'\n", Model.Location[], "is committed"),
        # an answer recorded in a committed store is a modification, and reported
        Model.HistoryExample(REPO * "mkdir -p .gbg && echo '[]' > .gbg/questions.json && git add .gbg/questions.json && " *
                             "git commit -q -m 'the store$TRAILER' && echo '[1]' > .gbg/questions.json\n",
                             [Model.Location(; file = "", line = 0)], "is committed"),
        # an open run is committed at its close; a closed one is reported once, not once per file
        Model.HistoryExample(REPO * "mkdir -p .gbg/runs/r1 && echo collect > .gbg/runs/r1/stage && echo x > .gbg/runs/r1/args.json\n",
                             Model.Location[], "an open run's is committed at its close"),
        Model.HistoryExample(REPO * "mkdir -p .gbg/runs/r1 && echo collect > .gbg/runs/r1/stage && echo x > .gbg/runs/r1/args.json && " *
                             "echo '{}' > .gbg/runs/r1/run.json\n",
                             [Model.Location(; file = "", line = 0)], "an open run's is committed at its close"),
    ])

# What a package may track (PF's request of 2026-10-05, the owner's yes). GBGPeriodicFields' repository
# held a multi-GPU proposal, notes to other sessions, a triage note, old review rounds, the pre-tool
# instruments and a per-machine settings file, committed because git was the easiest way to carry a
# note between machines; a public release would have published all of it. A path is allowed when it is
# one of these files or under one of these directories; anything else a package keeps is a per-file
# `Switch` with its reason, each package's own (the owner, 2026-10-05: none listed here).
const TRACKED_FILES = ["Project.toml", "README.md", "LICENSE", "LICENSE.md", "CHANGELOG.md", ".gitignore", "CLAUDE.md",
                       ".gbg/config.jl", ".gbg/questions.json", ".gbg/settled.jl", ".gbg/leak-accepted.txt",
                       ".claude/settings.json", ".claude/WORK_QUEUE.md"]
const TRACKED_DIRS = ["src/", "ext/", "test/", "docs/", "examples/", "benchmark/", ".github/",
                      ".gbg/policy/", ".gbg/requests/", ".gbg/runs/", ".claude/hooks/", ".claude/skills/"]

"""
    tracked_allowed(path) -> Bool

Whether a package may track `path`, relative to its root, without a switch. The argument is `path`.
Returns the verdict: one of the allowed files, or a path under an allowed directory, a documentation
build excepted.
"""
tracked_allowed(path::AbstractString) =
    path in TRACKED_FILES ||
    (any(d -> startswith(path, d), TRACKED_DIRS) && !startswith(path, "docs/build/"))

"""
    tracked(root, cfg) -> Vector{Model.Location}

Every path git tracks in the package at `root` that it may not track. The arguments are `root`, the
package root, and `cfg`, which this rule does not read. Returns one location per path, naming it, so a
per-file switch can declare it with its reason.
"""
function tracked(root::AbstractString, cfg)
    Sys.which("git") === nothing &&
        return [Model.Location(; file = "", line = 0, text = "cannot evaluate: `git` is not on the path")]
    # outside a repository nothing is tracked, and the rule has nothing to say, as every git rule does there
    success(pipeline(`git -C $root rev-parse --git-dir`; stdout = devnull, stderr = devnull)) || return Model.Location[]
    listed = try
        read(pipeline(ignorestatus(`git -C $root ls-files -z`); stderr = devnull), String)
    catch e
        return [Model.Location(; file = "", line = 0, text = "cannot evaluate: git did not run ($(sprint(showerror, e)))")]
    end
    return [Model.Location(; file = String(f), line = 0,
                            text = "`$f` is tracked and is none of the package's own files: move a draft or a note to `inspiration/`, or declare the file with its reason")
            for f in split(listed, '\0') if !isempty(f) && !tracked_allowed(f)]
end

const TRACKED = Model.Rule(
    id = Symbol("RULE.GIT.TRACKED"),
    statement = "A package's git tracks only the package and the tool's files: `src/`, `ext/`, `test/`, `docs/` but its build, `examples/`, `benchmark/`, `.github/`, `Project.toml`, `README.md`, a `LICENSE`, `CHANGELOG.md`, `.gitignore` and `CLAUDE.md`; `.gbg/config.jl`, `.gbg/policy/`, `.gbg/requests/`, `.gbg/questions.json`, `.gbg/settled.jl`, `.gbg/runs/` and `.gbg/leak-accepted.txt`; `.claude/settings.json`, `.claude/hooks/`, `.claude/skills/` and `.claude/WORK_QUEUE.md`. A draft or a note between sessions lives in `inspiration/`, which git ignores; any other file is declared with its reason.",
    why = "Git carried notes between machines because it was the easiest way, and a public release would have published them: one package held a design proposal, notes to other sessions and old review rounds. `inspiration/` reaches both machines through Dropbox, so no note needs git, and a file kept on purpose says why.",
    intention = Model.Intention.CODE,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.HISTORY, tracked, false),
    examples = [
        Model.HistoryExample(REPO * "mkdir -p src && echo x > src/A.jl && echo n > notes.md && git add src notes.md && " *
                             "git commit -q -m 'a note$TRAILER'\n",
                             [Model.Location(; file = "notes.md", line = 0)], "tracks only the package and the tool's files"),
        Model.HistoryExample(REPO * "mkdir -p src docs/src && echo x > src/A.jl && echo p > docs/src/index.md && " *
                             "echo n > README.md && git add src docs README.md && git commit -q -m 'the package$TRAILER'\n",
                             Model.Location[], "tracks only the package and the tool's files"),
        # a documentation build is no documentation; a staged file counts as tracked, before any commit
        Model.HistoryExample(REPO * "mkdir -p docs/build && echo h > docs/build/index.html && git add docs/build\n",
                             [Model.Location(; file = "docs/build/index.html", line = 0)], "`docs/` but its build"),
        Model.HistoryExample(REPO * "mkdir -p docs/src && echo p > docs/src/index.md && git add docs\n",
                             Model.Location[], "`docs/` but its build"),
        # the tool's own files, the ones `gbg release` and the owner's records need among them
        Model.HistoryExample(REPO * "mkdir -p .gbg/requests .claude/hooks && echo r > .gbg/requests/to-X.md && " *
                             "echo h > .claude/hooks/queue-guard.sh && echo c > CHANGELOG.md && echo s > .gbg/settled.jl && " *
                             "git add .gbg .claude CHANGELOG.md\n",
                             Model.Location[], "tracks only the package and the tool's files"),
        # a note between sessions belongs in `inspiration/`, which git ignores
        Model.HistoryExample(REPO * "mkdir -p .claude && echo n > .claude/to-PF-reply.md && git add .claude\n",
                             [Model.Location(; file = ".claude/to-PF-reply.md", line = 0)], "a note between sessions lives in `inspiration/`"),
        Model.HistoryExample(REPO * "mkdir -p inspiration && echo n > inspiration/to-PF-reply.md && echo inspiration/ > .gitignore && git add .gitignore\n",
                             Model.Location[], "a note between sessions lives in `inspiration/`"),
    ])

"""
    RULES

The rules of this file.
"""
const RULES = Model.Rule[RECORDS, TRACKED]

end # module Records
