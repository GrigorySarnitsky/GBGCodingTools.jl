#!/bin/sh
# tools/floor.sh — the floor: the commands every commit of the rebuild passes, each exit 0
# (IMPLEMENTATION.md, "Terms"). Every phase gate calls this file by path rather than a variable,
# because a variable holding `&&` inside `bash -c '…'` is not re-parsed as an operator and such a
# gate passes without running anything.
#
# Usage: tools/floor.sh [package-root]   — the root defaults to this repository.
set -e
cd "${1:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"

# IS THE LAST THING I PUSHED GREEN?
#
# This is asked FIRST, before the tests, because the answer decides whether more work belongs on top.
# Twenty-five consecutive CI runs failed on 2026-09-18 without reaching anyone: the local gate was
# green every time, nothing here looked at the remote, and the owner found out from his inbox.
#
# It REFUSES rather than warns. A printed line is what the previous version of this lesson was, and it
# was read past. The escape is explicit, because the commit that fixes a red CI must be allowed
# through: `FLOOR_IGNORE_CI=1 tools/floor.sh`. Where `gh` is missing or the network is not there, it
# says it could not look — never silence.
# It asks EACH WORKFLOW BY NAME, and says how far behind HEAD its newest run is. The first version of
# this check read `gh run list --branch master --limit 1`, which answers "the newest run of anything" —
# on 2026-09-18 that was the `Docs` workflow, green, while `CI` had been red for two tags. `CI` runs on
# a tag or a manual dispatch (RULE.GIT.CI_MANUAL) and never on a branch push, so "the last run" is
# routinely a different workflow at a different commit, and reading it as a verdict on this one is how
# both v2.0.0-rc.2 and v2.0.0-rc.3 went out red.
#
# An empty conclusion is a run still going, which the first version counted as success.
#
# A green run at ANOTHER commit is reported and not refused. What this check serves is that the owner
# gets no failure mail: a red run refuses, because nothing belongs on top of it. A run behind HEAD is
# not red — CI runs by hand, so it is behind before nearly every commit, and this commit is tested by the
# gate below, not by GitHub. It refused from 2026-09-26 and had to be overridden on every commit, which
# is a check nobody reads (the owner, 2026-09-27).
if [ -z "${FLOOR_IGNORE_CI:-}" ] && [ -z "${1:-}" ]; then
  if command -v gh >/dev/null 2>&1; then
    HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
    for WF in CI Docs; do
      RUN=$(gh run list --workflow "$WF" --limit 1 \
              --json conclusion,status,headSha,url \
              --jq '.[0] | "\(.status)\t\(.conclusion)\t\(.headSha)\t\(.url)"' 2>/dev/null) || RUN=""
      if [ -z "$RUN" ]; then
        echo "floor: could not reach GitHub — the state of the $WF workflow is unknown"
        continue
      fi
      STATUS=$(printf '%s' "$RUN" | cut -f1)
      VERDICT=$(printf '%s' "$RUN" | cut -f2)
      SHA=$(printf '%s' "$RUN" | cut -f3)
      URL=$(printf '%s' "$RUN" | cut -f4)
      case "$VERDICT" in
        success) : ;;
        "")
          echo "floor: the newest $WF run is still $STATUS — its answer is not in yet"
          echo "  $URL" ;;
        *)
          echo "floor: THE NEWEST $WF RUN IS $VERDICT ON GITHUB — fix that before adding to it."
          echo "  $URL"
          echo "  If THIS commit is the fix: FLOOR_IGNORE_CI=1 tools/floor.sh"
          exit 1 ;;
      esac
      # How old is that answer? A green run at a commit twenty behind HEAD has been read here as "green",
      # which is the whole defect restated: it is a verdict on other code.
      if [ -n "$SHA" ] && [ "$SHA" != "$HEAD_SHA" ]; then
        if git cat-file -e "$SHA" 2>/dev/null; then
          BEHIND=$(git rev-list --count "$SHA..HEAD" 2>/dev/null || echo "?")
          echo "floor: the newest $WF run is $BEHIND commit(s) behind HEAD — it did not see this work."
        else
          echo "floor: the newest $WF run is at a commit this clone does not have — it did not see this work."
        fi
        [ "$WF" = "CI" ] && echo "  CI runs on a tag or a dispatch: gh workflow run CI --ref master"
      fi
    done
  else
    echo "floor: no gh on this machine — the workflows' state is unknown"
  fi
fi

# WITHOUT THIS MACHINE'S GIT IDENTITY. A runner has no `user.name` and no `user.email`; a developer's
# machine has both, globally, and hands them to every child process. A test that builds a git repository
# and expects a commit to succeed therefore passed here and failed there — the whole first testset of
# `test/docfix.jl`, on the v2.0.0-rc.2 tag, which is the fourth defect of this shape: the gate measured
# somewhere the failure could not appear. A fixture that needs an identity now sets one in its own
# repository, as a real package does, and this keeps it honest.
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
  julia --project --startup-file=no -e 'using Pkg; Pkg.test()'
julia --project=docs --startup-file=no docs/make.jl

# DOES IT LOAD FROM WHAT GIT ACTUALLY HOLDS?
#
# The two commands above run in this working tree, which is not what anyone else gets. `src/Scans/`
# was emptied on 2026-09-17 and git does not track an empty directory, so it survived here and was
# absent from every clone — and `Scan.jl` read it at load. Every CI run failed for a day while this
# gate stayed green, because this gate ran in the one place the directory still existed.
#
# So: export the tracked files to a temporary directory and load the package there. It catches the
# whole class — an untracked file, an empty directory, anything present here and not in the repository.
# Outside Dropbox, because every repository here is inside it. One `tar` reads the whole path list from
# stdin: piped through `xargs tar`, past xargs's buffer the list was split into two archives and the
# extracting tar stopped at the first one's end, so the export silently lacked the last files (found in
# review, 2026-09-26). Not `git archive HEAD`: the floor runs BEFORE the commit, and HEAD is the last one.
#
# This step and the sweep below are THIS repository's: run with a consumer's root, its root environment
# names no GBGCodingTools, so they are skipped there, as the CI check above is.
if [ -z "${1:-}" ]; then
  echo "floor: loading from the tracked files alone"
  EXPORT=$(mktemp -d)
  trap 'rm -rf "$EXPORT"' EXIT
  git ls-files -z | tar --null -T - -cf - | tar -xf - -C "$EXPORT"
  julia --project="$EXPORT" --startup-file=no -e '
      using Pkg; Pkg.instantiate()
      using GBGCodingTools
      isempty(GBGCodingTools.Catalogue.RULES) && error("the rulebook is empty in a clean export")
      println("floor: loaded ", length(GBGCodingTools.Catalogue.RULES), " rules from the tracked files")'
fi


# THE FLEET SWEEP, when this change could alter what a rule READS and the packages are on this machine.
#
# Two defects of 2026-09-18 were correct on every package being measured and broken on one that was not:
# a rule read files a docs build GENERATES (absent from a clean clone, present in a built tree), and a
# byte-offset slice threw on the two consumers whose prose carries the most Greek. Neither was a
# reporting failure. Both were measuring in one place and concluding about four.
#
# It is not in `Pkg.test()` and must not be: those packages live outside this repository at paths that
# differ by machine, and a test reading them would answer differently on a fresh clone and on CI. This
# gate is a developer's, not a contract, so it may look — and it skips, saying so, where it cannot.
#
# `~/.gbg/fleet` holds one package root per line. Per-machine, like `~/.gbg/dev`, and never synced.
READS='^src/Rules/|^src/Texts\.jl$|^src/Engine/Checks\.jl$'
if [ -z "${1:-}" ] && git diff --name-only HEAD 2>/dev/null | grep -qE "$READS"; then
  if [ -f "$HOME/.gbg/fleet" ]; then
    echo "floor: a rule's reading changed — sweeping the fleet"
    # Every consumer path here holds two spaces, so the roots are built as positional parameters one
    # line at a time. Word-splitting a single string would make four packages into a dozen arguments.
    set --
    while IFS= read -r line; do
      [ -n "$line" ] && set -- "$@" "$line"
    done < "$HOME/.gbg/fleet"
    julia --project --startup-file=no tools/fleet.jl "$@"
  else
    echo "floor: a rule's reading changed, and ~/.gbg/fleet names no packages to sweep — not swept"
  fi
fi
