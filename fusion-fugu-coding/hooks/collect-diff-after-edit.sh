#!/usr/bin/env bash
# fusion-fugu-coding :: PostToolUse hook (async)
# Appends a lightweight diff summary to the plugin run log after file edits.
# Does NOT run a full review and never blocks. Best-effort and silent.
set -u

# Persist across plugin updates when available; fall back to a temp dir.
log_dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/fusion-fugu-coding}"
mkdir -p "$log_dir" 2>/dev/null || exit 0
log_file="$log_dir/run-log.txt"

proj="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$proj" 2>/dev/null || exit 0

# Only act inside a git work tree.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

ts="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown-time')"
{
  printf '\n=== %s :: post-edit diff summary ===\n' "$ts"
  git diff --stat 2>/dev/null | tail -n 40
} >> "$log_file" 2>/dev/null

exit 0
