---
name: fugu-fix
description: Controlled Fugu-lite coding workflow for bug fixes and feature work — plan (Thinker) then implement (Worker) then verify (Verifier) then Fusion review, with a bounded repair loop. Makes minimal edits; never commits, pushes, or touches secret files. Use to actually carry out a change end to end with guardrails.
disable-model-invocation: true
allowed-tools: Read, Edit, MultiEdit, Write, Grep, Glob, Task, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(npm test:*), Bash(npm run:*), Bash(pnpm test:*), Bash(pnpm run:*), Bash(yarn test:*), Bash(yarn run:*), Bash(npx tsc:*), Bash(find:*), Bash(ls:*), Bash(cat package.json)
---

# Fugu-lite Fix

Run a **controlled implementation loop** with separated roles:
**plan → implement → verify → Fusion review → repair**. Make the smallest change that
solves the task and keep the phases distinct.

## Input
`$ARGUMENTS` is the task (e.g. "Fix the login token refresh bug with minimal changes").
If empty, ask for the task once, briefly.

## Hard constraints (always)
- **Never** commit, push, merge, or run destructive commands automatically.
- **Never** edit secret files (`.env*`, keys, `secrets/**`, …).
- Keep changes minimal and on-scope — no opportunistic refactors.
- Before any destructive or irreversible command, ask the user.
- If tests fail for **pre-existing/unrelated** reasons, document that clearly and do
  not try to fix unrelated things.

## Phase 1 — Thinker (plan)
Produce a short plan (you may call `/fugu-plan` or the `fugu-thinker` subagent):
objective, files to touch, constraints, ordered steps, test strategy, verification
commands. Don't over-plan a tiny fix — match plan depth to task size.

## Phase 2 — Worker (implement)
Make the **minimal** code changes from the plan.
- Touch only the files the plan named (plus genuinely required follow-ons).
- Keep the public API stable unless the task requires a change.
- Add/adjust tests for the changed behavior as the plan specified.

## Phase 3 — Verifier (checks)
Run project-appropriate checks (you may call
`${CLAUDE_PLUGIN_ROOT}/scripts/run-checks.sh` or the `fugu-verifier` subagent):
- Detect the package manager from the lockfile.
- Run typecheck / lint / test (and build only if appropriate) when the scripts exist.
- Do not install dependencies without asking.
Report what passed, what failed, and whether failures are caused by this change.

## Phase 4 — Fusion review
Review the final diff with Fusion-lite criteria — call `/fusion-review` (or the four
reviewer subagents + `fusion-judge`). Capture the decision JSON.

## Phase 5 — Repair loop (bounded)
If the Fusion decision is `request_changes`:
- Fix **only** the review-identified issues (and check failures). No new scope.
- Re-run checks and re-review.
- **Maximum 2 repair iterations.** If still failing after 2, stop and hand back to the
  user with the remaining issues and your recommendation (see the template at
  `${CLAUDE_PLUGIN_ROOT}/skills/fugu-fix/templates/repair-instruction.md`).

## Final output
```
# Fugu-lite Fix Result
## Summary            — what you changed and why, in 2–4 lines
## Files Changed      — list with one-line purpose each
## Checks Run         — command → pass/fail (+ pre-existing vs. caused-by-change)
## Fusion Review Decision  — the decision JSON + one-line gloss
## Remaining Risks    — anything still open / not covered
## Suggested Next Step — e.g. review, run app, commit (only if the user asks)
```
Do not commit or push. Leave that to the user.
