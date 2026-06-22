#!/usr/bin/env bash
# fusion-fugu-coding :: PreToolUse hook
# Blocks Read/Edit/Write/MultiEdit/NotebookEdit on sensitive files
# (.env, keys, secrets/, credentials, keystores). Fails safe: if the target
# path matches a secret pattern, the call is denied.
set -u

input="$(cat)"

# Extract a string field from tool_input: jq -> python3 -> empty.
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

emit_deny() {
  reason="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg r "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$reason"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
  fi
  exit 0
}

path="$(json_get file_path)"
[ -z "$path" ] && path="$(json_get notebook_path)"
[ -z "$path" ] && path="$(json_get path)"

# Nothing path-like to inspect -> allow (other hooks/rules still apply).
[ -z "$path" ] && exit 0

base="$(basename "$path" 2>/dev/null || printf '%s' "$path")"
msg="Blocked: sensitive file access is not allowed by the fusion-fugu-coding plugin"

# Filename-based matches.
case "$base" in
  .env|.env.*|*.env|*.pem|*.key|*.p12|*.pfx|*.keystore|*.jks|id_rsa|id_ed25519|id_dsa|id_ecdsa|credentials.*)
    emit_deny "$msg ($base)." ;;
esac

# Path-based matches.
case "$path" in
  */secrets/*|secrets/*|*/.ssh/*|*/.aws/credentials*|*/.gnupg/*|*/config/credentials*|*.env.*)
    emit_deny "$msg ($path)." ;;
esac

exit 0
