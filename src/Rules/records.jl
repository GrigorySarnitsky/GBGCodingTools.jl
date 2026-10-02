# The design's §7; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.Records

`RULE.GIT.RECORDS`, alone in its file: the one rule that names the tool's own records. Its only check
is a hook over git, which no build or test runs, so the scan that keeps review state out of every other
rule's file exempts this one, and a test holds the exemption to that fact.
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

"""
    RULES

The rule of this file.
"""
const RULES = Model.Rule[RECORDS]

end # module Records
