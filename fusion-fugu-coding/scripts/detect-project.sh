#!/usr/bin/env bash
# fusion-fugu-coding :: detect package manager, framework, scripts, monorepo.
# Outputs JSON to stdout. Read-only. Best-effort; missing data -> null/empty.
set -u

dir="${1:-$PWD}"
cd "$dir" 2>/dev/null || { echo '{"error":"cannot cd to project dir"}'; exit 0; }

# Package manager from lockfile.
pm="unknown"
if [ -f pnpm-lock.yaml ]; then pm="pnpm"
elif [ -f yarn.lock ]; then pm="yarn"
elif [ -f package-lock.json ]; then pm="npm"
elif [ -f bun.lockb ] || [ -f bun.lock ]; then pm="bun"
fi

# Monorepo signals.
monorepo="false"
[ -f pnpm-workspace.yaml ] && monorepo="true"
[ -f lerna.json ] && monorepo="true"
[ -f turbo.json ] && monorepo="true"
[ -f nx.json ] && monorepo="true"

if [ ! -f package.json ]; then
  printf '{"package_manager":"%s","has_package_json":false,"monorepo":%s,"framework":null,"scripts":{}}\n' \
    "$pm" "$monorepo"
  exit 0
fi

if command -v python3 >/dev/null 2>&1; then
  python3 - "$pm" "$monorepo" <<'PY'
import json, sys
pm, monorepo = sys.argv[1], sys.argv[2] == "true"
try:
    d = json.load(open("package.json"))
except Exception as e:
    print(json.dumps({"package_manager": pm, "has_package_json": True,
                      "error": "unparseable package.json", "monorepo": monorepo}))
    sys.exit(0)

scripts = d.get("scripts", {}) or {}
deps = {}
deps.update(d.get("dependencies", {}) or {})
deps.update(d.get("devDependencies", {}) or {})

def has(*names): return any(n in deps for n in names)
framework = None
if has("next"): framework = "next"
elif has("nuxt"): framework = "nuxt"
elif has("@remix-run/react", "@remix-run/node"): framework = "remix"
elif has("@angular/core"): framework = "angular"
elif has("svelte", "@sveltejs/kit"): framework = "svelte"
elif has("vue"): framework = "vue"
elif has("react"): framework = "react"
elif has("express", "fastify", "koa", "@nestjs/core"): framework = "node-server"

known = ["test", "typecheck", "type-check", "tsc", "lint", "build", "check"]
detected = {k: scripts[k] for k in known if k in scripts}

# workspaces field is another monorepo signal
if d.get("workspaces"):
    monorepo = True

print(json.dumps({
    "package_manager": pm,
    "has_package_json": True,
    "monorepo": monorepo,
    "framework": framework,
    "scripts": detected,
    "all_script_names": sorted(scripts.keys()),
}, indent=2))
PY
else
  printf '{"package_manager":"%s","has_package_json":true,"monorepo":%s,"framework":null,"note":"python3 unavailable; scripts not parsed"}\n' \
    "$pm" "$monorepo"
fi
