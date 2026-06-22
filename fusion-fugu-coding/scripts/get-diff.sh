#!/usr/bin/env bash
# fusion-fugu-coding :: collect the current change for review.
# Usage: get-diff.sh [<git-ref-or-range>] [-- <path>...]
# No args -> current working-tree diff. Read-only.
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git work tree. Provide a patch or a file path instead." >&2
  exit 1
fi

echo "## git status (short)"
git status --short
echo ""
echo "## git diff --stat"
git diff --stat "$@"
echo ""
echo "## git diff"
git diff "$@"
