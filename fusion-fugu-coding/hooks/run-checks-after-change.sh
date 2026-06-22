#!/usr/bin/env bash
# fusion-fugu-coding :: PostToolUse hook (async, OPT-IN)
# Runs a fast typecheck after edits, but ONLY when explicitly enabled with
#   export FUSION_FUGU_AUTOCHECK=1
# Off by default so edits never trigger surprise background work. Never blocks;
# results are written to the plugin run log. Full test runs belong in
# /fugu-verify, not in an automatic hook.
set -u

[ "${FUSION_FUGU_AUTOCHECK:-0}" = "1" ] || exit 0

log_dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/fusion-fugu-coding}"
mkdir -p "$log_dir" 2>/dev/null || exit 0
log_file="$log_dir/run-log.txt"

proj="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$proj" 2>/dev/null || exit 0
[ -f package.json ] || exit 0

# Detect package manager from lockfile.
pm=""
if [ -f pnpm-lock.yaml ]; then pm="pnpm"
elif [ -f yarn.lock ]; then pm="yarn"
elif [ -f package-lock.json ]; then pm="npm"
else exit 0
fi

# Only run if a typecheck script exists.
has_typecheck=0
if command -v python3 >/dev/null 2>&1; then
  has_typecheck="$(python3 -c 'import json,sys
try:
    d=json.load(open("package.json"))
    print(1 if "typecheck" in d.get("scripts",{}) else 0)
except Exception:
    print(0)' 2>/dev/null)"
fi
[ "$has_typecheck" = "1" ] || exit 0

ts="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown-time')"
{
  printf '\n=== %s :: auto typecheck (%s run typecheck) ===\n' "$ts" "$pm"
  "$pm" run typecheck 2>&1 | tail -n 30
  printf '(exit: %s)\n' "$?"
} >> "$log_file" 2>&1

exit 0
