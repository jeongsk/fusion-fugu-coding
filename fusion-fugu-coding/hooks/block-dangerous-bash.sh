#!/usr/bin/env bash
# fusion-fugu-coding :: PreToolUse hook (Bash)
# Requires explicit user confirmation ("ask") for destructive shell commands.
# Default posture: do not silently run dangerous commands. The user can still
# approve when the action is intended.
set -u

input="$(cat)"

json_get() {
  field="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r --arg f "$field" '.tool_input[$f] // empty' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(d.get("tool_input",{}).get(sys.argv[1],"") or "")' "$field" 2>/dev/null
  fi
}

emit() {
  decision="$1"; reason="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg d "$decision" --arg r "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":sys.argv[1],"permissionDecisionReason":sys.argv[2]}}))' "$decision" "$reason"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$decision" "$reason"
  fi
  exit 0
}

cmd="$(json_get command)"
[ -z "$cmd" ] && exit 0

reasons=""
flag() { reasons="${reasons:+$reasons; }$1"; }
m() { printf '%s' "$cmd" | grep -Eiq "$1"; }

# rm with recursive + force
if m 'rm[[:space:]]+-[[:alnum:]]*r[[:alnum:]]*f' || m 'rm[[:space:]]+-[[:alnum:]]*f[[:alnum:]]*r' \
   || ( m 'rm[[:space:]]+-[[:alnum:]]*r' && m 'rm[[:space:]]+.*-[[:alnum:]]*f' ); then
  flag "recursive force remove (rm -rf)"
fi
# privilege escalation
m '(^|[[:space:];&|(])sudo[[:space:]]' && flag "privilege escalation (sudo)"
# world-writable chmod
( m 'chmod' && m '(^|[[:space:]])0?777([[:space:]]|$)' ) && flag "world-writable permissions (chmod 777)"
# pipe remote script into a shell
m '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash|zsh|dash)([[:space:]]|$)' && flag "pipe network download into a shell (curl|wget | sh)"
# git history/force hazards
if m 'git[[:space:]]+push' && m '(--force([^-]|$)|--force-with-lease|[[:space:]]-[[:alnum:]]*f([[:space:]]|$))'; then
  flag "force push (git push --force / -f)"
fi
m 'git[[:space:]]+reset[[:space:]].*--hard' && flag "discard changes (git reset --hard)"
m 'git[[:space:]]+clean[[:space:]].*-[[:alnum:]]*f' && flag "delete untracked files (git clean -f)"
m 'git[[:space:]]+checkout[[:space:]]+--[[:space:]]+\.' && flag "discard working tree (git checkout -- .)"
# container/system cleanup
m 'docker[[:space:]]+(system[[:space:]]+)?prune' && flag "docker prune (removes containers/images/volumes)"
# forceful kill
m 'kill[[:space:]]+(-9|-s[[:space:]]*(9|KILL)|-KILL)' && flag "force kill (kill -9)"
# disk / device destruction
m 'mkfs(\.|[[:space:]])' && flag "format filesystem (mkfs)"
m 'dd[[:space:]].*of=/dev/' && flag "raw write to device (dd of=/dev/...)"
m '>[[:space:]]*/dev/(sd|nvme|disk)' && flag "overwrite block device"
# fork bomb
m ':\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:' && flag "fork bomb"

if [ -n "$reasons" ]; then
  emit "ask" "fusion-fugu-coding flagged a potentially destructive command — confirm only if you intend it: $reasons."
fi

exit 0
