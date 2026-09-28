#!/usr/bin/env bash
# PUSH HOOK — the docs build runs before every push, and a build that fails stops the push.
# Written by GBGCodingTools vdev; do not edit.
#
# CONTRACT. Claude Code runs this before every shell command (PreToolUse), with the call as JSON on
# standard input. A command that pushes runs the package's docs build first, in the package root; exit
# 2 stops the push and hands stderr back as the reason, exit 0 lets it through.
#
# WHY. The owner's ruling of 2026-09-29: every push does the docs build. A session ran only
# `Pkg.test()` before pushing, so a broken cross-reference reached GitHub sixteen times in one package.
set -uo pipefail
payload=$(cat)
printf '%s' "$payload" | grep -qE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([^[:alnum:]_-]|$)' || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
log=$(mktemp)
if julia --project=docs docs/make.jl >"$log" 2>&1; then
  rm -f "$log"
  exit 0
fi
{
  echo "PUSH STOPPED: the docs build failed, and every push does the docs build (the owner, 2026-09-29)."
  echo "What it reported, every finding and error line:"
  grep -E '^  (RULE\.|WIRING|CONFIG)|ERROR|Error' "$log"
  echo "The whole output: $log"
} >&2
exit 2
