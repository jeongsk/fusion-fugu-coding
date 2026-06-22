---
name: fugu-verify
description: Fugu-lite Verifier for the current changes — inspects git status/diff, detects the package manager and scripts, runs typecheck/lint/test/build where available, scans for secrets, runs a Fusion-lite review, and produces an approve / request_changes / needs_human_review decision. Does NOT implement new changes unless the user explicitly asks. Use to check work before committing.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Task, Bash(git status:*), Bash(git diff:*), Bash(git show:*), Bash(git log:*), Bash(npm test:*), Bash(npm run:*), Bash(pnpm test:*), Bash(pnpm run:*), Bash(yarn test:*), Bash(yarn run:*), Bash(npx tsc:*), Bash(find:*), Bash(ls:*), Bash(cat package.json)
---

# Fugu-lite Verify (Verifier)

Verify the **current** changes without implementing new ones. **Do not modify files
unless the user explicitly asks.** Apply the rubric at
`${CLAUDE_PLUGIN_ROOT}/skills/fugu-verify/rubrics/verification-rubric.md`.

## Input
`$ARGUMENTS` may narrow the scope (a path or "the last commit"). If empty, verify the
current uncommitted working-tree changes.

## Process
You may delegate to the `fugu-verifier` subagent via the Task tool, or run inline.

1. **Inspect** `git status --short` and `git diff` — know exactly what changed.
2. **Detect the project** (you may run
   `${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh`):
   - `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm.
   - Read `package.json` scripts: `test`, `typecheck`, `lint`, `build`.
3. **Run reasonable checks** that exist (you may run
   `${CLAUDE_PLUGIN_ROOT}/scripts/run-checks.sh`). Do **not** install dependencies;
   skip missing tools and say so.
4. **Secret scan** the diff (`${CLAUDE_PLUGIN_ROOT}/scripts/secret-scan.sh`); never
   print secret values.
5. **Fusion-lite review** of the diff — call `/fusion-review` (or the reviewer
   subagents + `fusion-judge`).
6. Distinguish failures **caused by this change** from **pre-existing/unrelated** ones,
   with evidence.

## Output
A short report plus the Fusion-style decision JSON:
```json
{
  "decision": "approve | request_changes | needs_human_review",
  "severity": "none | low | medium | high | critical",
  "summary": "",
  "issues": [],
  "confidence": "low | medium | high",
  "follow_up_commands": []
}
```
Plus, in prose: the checks you ran (command → result), pre-existing vs. caused-by-change
failures, remaining risks, and whether it is safe to commit. **Do not commit or push.**
