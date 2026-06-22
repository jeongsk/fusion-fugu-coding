#!/usr/bin/env bash
# fusion-fugu-coding :: best-effort project checks.
# Runs typecheck, lint, test (and build only with --build) using the detected
# package manager + existing package.json scripts. Never installs dependencies.
# Usage: run-checks.sh [--build] [--no-test] [--no-lint] [--no-typecheck]
set -u

dir="${PWD}"
do_build=0; do_test=1; do_lint=1; do_typecheck=1
for a in "$@"; do
  case "$a" in
    --build) do_build=1 ;;
    --no-test) do_test=0 ;;
    --no-lint) do_lint=0 ;;
    --no-typecheck) do_typecheck=0 ;;
  esac
done

cd "$dir" 2>/dev/null || { echo "cannot cd to $dir"; exit 1; }

if [ ! -f package.json ]; then
  echo "No package.json found in $dir — nothing to check here."
  echo "If this is not a Node project, run the project's own checks manually."
  exit 0
fi

pm="npm"
if [ -f pnpm-lock.yaml ]; then pm="pnpm"
elif [ -f yarn.lock ]; then pm="yarn"
elif [ -f package-lock.json ]; then pm="npm"
fi
echo "Package manager: $pm"

has_script() {
  command -v python3 >/dev/null 2>&1 || return 1
  python3 -c 'import json,sys
try:
    d=json.load(open("package.json"))
except Exception:
    sys.exit(1)
sys.exit(0 if sys.argv[1] in (d.get("scripts",{}) or {}) else 1)' "$1"
}

run_one() {
  label="$1"; script="$2"
  if has_script "$script"; then
    echo ""
    echo ">>> $label: $pm run $script"
    if "$pm" run "$script"; then
      echo "<<< $label: PASS"
    else
      code=$?
      echo "<<< $label: FAIL (exit $code)"
      overall=1
    fi
  else
    echo ">>> $label: skipped (no \"$script\" script)"
  fi
}

overall=0
[ "$do_typecheck" = "1" ] && { has_script typecheck && run_one "typecheck" "typecheck" || { has_script type-check && run_one "typecheck" "type-check" || echo ">>> typecheck: skipped (no typecheck script)"; }; }
[ "$do_lint" = "1" ] && run_one "lint" "lint"
[ "$do_test" = "1" ] && run_one "test" "test"
[ "$do_build" = "1" ] && run_one "build" "build"

echo ""
if [ "$overall" = "0" ]; then
  echo "RESULT: all attempted checks passed (or were skipped)."
else
  echo "RESULT: one or more checks FAILED — see output above."
fi
echo "Note: dependencies were NOT installed automatically. If a tool is missing, install deps and re-run."
exit "$overall"
