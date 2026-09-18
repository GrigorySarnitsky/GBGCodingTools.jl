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
if [ -z "${FLOOR_IGNORE_CI:-}" ] && [ -z "${1:-}" ]; then
  if command -v gh >/dev/null 2>&1; then
    LAST=$(gh run list --branch master --limit 1 --json conclusion,displayTitle,url 2>/dev/null) || LAST=""
    if [ -z "$LAST" ]; then
      echo "floor: could not reach GitHub — the last run's state is unknown"
    else
      VERDICT=$(printf '%s' "$LAST" | sed -n 's/.*"conclusion":"\([^"]*\)".*/\1/p')
      case "$VERDICT" in
        success|"") : ;;
        *)
          echo "floor: THE LAST PUSH IS $VERDICT ON GITHUB — fix that before adding to it."
          printf '%s\n' "$LAST" | tr ',' '\n' | grep -E '"(displayTitle|url)"' | sed 's/^/  /'
          echo "  If THIS commit is the fix: FLOOR_IGNORE_CI=1 tools/floor.sh"
          exit 1 ;;
      esac
    fi
  else
    echo "floor: no gh on this machine — the last run's state is unknown"
  fi
fi

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
# Outside Dropbox, because every repository here is inside it.
echo "floor: loading from the tracked files alone"
EXPORT=$(mktemp -d)
trap 'rm -rf "$EXPORT"' EXIT
git ls-files -z | xargs -0 tar -cf - | tar -xf - -C "$EXPORT"
julia --project="$EXPORT" --startup-file=no -e '
    using Pkg; Pkg.instantiate()
    using GBGCodingTools
    isempty(GBGCodingTools.Catalogue.RULES) && error("the rulebook is empty in a clean export")
    println("floor: loaded ", length(GBGCodingTools.Catalogue.RULES), " rules from the tracked files")'


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
if git diff --name-only HEAD 2>/dev/null | grep -qE "$READS"; then
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
