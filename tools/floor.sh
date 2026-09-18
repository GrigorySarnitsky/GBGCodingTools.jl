#!/bin/sh
# tools/floor.sh — the floor: the commands every commit of the rebuild passes, each exit 0
# (IMPLEMENTATION.md, "Terms"). Every phase gate calls this file by path rather than a variable,
# because a variable holding `&&` inside `bash -c '…'` is not re-parsed as an operator and such a
# gate passes without running anything.
#
# Usage: tools/floor.sh [package-root]   — the root defaults to this repository.
set -e
cd "${1:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
julia --project --startup-file=no -e 'using Pkg; Pkg.test()'
julia --project=docs --startup-file=no docs/make.jl

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
