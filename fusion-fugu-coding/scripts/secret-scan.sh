#!/usr/bin/env bash
# fusion-fugu-coding :: scan the current diff for likely secrets.
# Prints only <file> :: <redacted match type> — NEVER the secret value.
# Usage: secret-scan.sh [git diff args]   (default: working-tree diff)
#        secret-scan.sh --cached          (staged diff)
# Exit 0 = clean, 3 = potential secrets found, 1 = could not scan.
set -u

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git work tree; nothing to scan." >&2
  exit 1
fi

# All positional args are forwarded to `git diff` (e.g. --cached, a ref/range).
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 unavailable; cannot run structured secret scan." >&2
  echo "Falling back to a coarse grep (redacted):" >&2
  git diff "$@" | grep -nEi 'BEGIN [A-Z ]*PRIVATE KEY|OPENAI_API_KEY|ANTHROPIC_API_KEY|GITHUB_TOKEN|AWS_SECRET_ACCESS_KEY|AWS_ACCESS_KEY_ID|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]|ghp_[A-Za-z0-9]|xox[baprs]-' \
    | sed -E 's/=.*/= [REDACTED]/' | sed -E 's/(sk-|ghp_|xox.-)[A-Za-z0-9_-]+/\1[REDACTED]/g' || echo "No obvious secrets found."
  exit 0
fi

# Write the diff to a temp file. We cannot pipe it to `python3 - <<'PY'` because the
# heredoc would itself become python's stdin, discarding the diff.
tmp_diff="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/ffc-diff.$$")"
trap 'rm -f "$tmp_diff"' EXIT
git diff "$@" > "$tmp_diff" 2>/dev/null

DIFF_FILE="$tmp_diff" python3 - <<'PY'
import os, re, sys

patterns = [
    ("Private key block",            re.compile(r'BEGIN [A-Z0-9 ]*PRIVATE KEY')),
    ("OpenAI API key (sk-)",         re.compile(r'\bsk-[A-Za-z0-9-]{16,}')),
    ("OpenAI/Anthropic key var",     re.compile(r'\b(OPENAI_API_KEY|ANTHROPIC_API_KEY)\b\s*[:=]')),
    ("GitHub token (ghp_/gho_/ghs_)", re.compile(r'\bgh[posu]_[A-Za-z0-9]{20,}')),
    ("GitHub token var",             re.compile(r'\bGITHUB_TOKEN\b\s*[:=]\s*\S')),
    ("Slack token (xox*)",           re.compile(r'\bxox[baprs]-[A-Za-z0-9-]{8,}')),
    ("AWS access key id",            re.compile(r'\bAKIA[0-9A-Z]{16}\b')),
    ("AWS access key var",           re.compile(r'\bAWS_ACCESS_KEY_ID\b\s*[:=]\s*\S')),
    ("AWS secret access key",        re.compile(r'\bAWS_SECRET_ACCESS_KEY\b\s*[:=]\s*\S')),
    ("Google API key",               re.compile(r'\bAIza[0-9A-Za-z_\-]{20,}')),
    ("Generic secret/token assignment",
     re.compile(r'\b(secret|token|password|passwd|api[_-]?key)\b\s*[:=]\s*["\']?[A-Za-z0-9/\+=_\-]{16,}', re.I)),
]

path = os.environ.get("DIFF_FILE", "")
cur_file = None
findings = []
seen = set()

try:
    fh = open(path, "r", errors="replace")
except Exception:
    print("No diff to scan.")
    sys.exit(0)

with fh:
    for raw in fh:
        line = raw.rstrip("\n")
        if line.startswith("+++ "):
            p = line[4:].strip()
            if p.startswith("b/"):
                p = p[2:]
            cur_file = None if p == "/dev/null" else p
            continue
        if line.startswith("diff --git") or line.startswith("+++"):
            continue
        if not line.startswith("+"):
            continue  # only added lines
        content = line[1:]
        for label, rx in patterns:
            if rx.search(content):
                key = (cur_file or "?", label)
                if key not in seen:
                    seen.add(key)
                    findings.append(key)

if not findings:
    print("No obvious secrets found in the scanned diff.")
    sys.exit(0)

print("POTENTIAL SECRETS DETECTED (values redacted):")
for f, label in findings:
    print("  %s :: %s" % (f, label))
print("")
print("Do NOT commit these. Remove the secret, rotate it if it was ever pushed,")
print("and load it from an environment variable or secret manager instead.")
sys.exit(3)
PY
rc=$?
exit "$rc"
