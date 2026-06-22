#!/usr/bin/env bash
# fusion-fugu-coding :: compact summary of a diff for triage / large-change review.
# Usage: summarize-diff.sh [<git-ref-or-range>] [-- <path>...]
# Read-only. Prints file count, churn, per-file +/-, and a few risk hints.
set -u

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git work tree; provide a patch or file instead." >&2
  exit 1
fi

echo "## Change summary"
git diff --shortstat "$@" 2>/dev/null || true
echo ""

echo "## Files changed (added / removed / path)"
git diff --numstat "$@" 2>/dev/null | awk '{ printf "  +%-6s -%-6s %s\n", $1, $2, $3 }'
echo ""

# Risk hints — surface files that often warrant closer review.
echo "## Review hints"
files="$(git diff --name-only "$@" 2>/dev/null)"
hint() { printf '%s\n' "$files" | grep -Eiq "$1" && echo "  - $2"; }
hint '\.env|secret|credential|\.pem|\.key' "touches secret/credential-looking paths — security reviewer should look closely (do NOT open the file)"
hint '(^|/)(auth|login|session|token|password|crypto)' "touches auth/session/crypto — security-sensitive"
hint '(migration|schema|\.sql)' "touches DB schema/migrations — check data integrity & rollback"
hint '(package\.json|lock|requirements|go\.mod|Cargo\.toml)' "dependency/manifest change — check supply-chain & version pinning"
hint '(Dockerfile|\.ya?ml|\.tf|deploy|k8s|helm)' "infra/CI/deploy config — check deploy safety"
hint '(test|spec)' "includes test changes — confirm they cover the new behavior"
[ -z "$files" ] && echo "  (no files in range)"
echo ""
echo "Tip: for very large diffs, review the highest-churn and security-hint files first."
