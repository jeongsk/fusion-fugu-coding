Claude Code 플러그인은 현재 skills, agents/subagents, hooks, MCP servers, slash command workflow를 묶는 확장 단위로 보는 게 맞습니다. Anthropic 공식 예제에도 code-review, feature-dev, plugin-dev 같은 플러그인이 있고, 플러그인은 커스텀 slash command, specialized agents, hooks, MCP 서버를 포함할 수 있다고 설명되어 있습니다.  
또 Claude Code의 skills는 .claude/skills/<name>/SKILL.md 구조로 만들고 /skill-name 형태로 실행할 수 있으며, 기존 custom command도 skills로 통합되는 방향입니다.  
subagent는 독립 context에서 특정 작업을 수행하는 specialized assistant이고, hooks는 Claude Code lifecycle의 특정 시점에 shell/HTTP/LLM prompt를 실행할 수 있습니다.  

아래 문서를 그대로 Claude Code에 전달하면 됩니다.

Handoff: Claude Code Plugin — Fusion-lite + Fugu-lite Coding Orchestrator

0. Goal

Build a Claude Code plugin that helps with coding tasks using a lightweight version of two ideas:

1. Fusion-lite
    * A multi-reviewer workflow inspired by OpenRouter Fusion.
    * Multiple specialized reviewers inspect the same diff or implementation plan.
    * A judge step merges their findings into a structured decision.
2. Fugu-lite
    * A lightweight coding orchestration workflow inspired by Sakana AI Fugu/TRINITY/Conductor.
    * It does not train a real orchestrator model.
    * It uses Claude Code skills, subagents, and hooks to approximate:
        * Thinker
        * Worker
        * Verifier
        * Repair loop

The plugin should be usable directly inside Claude Code as slash commands/skills.

Primary target:

/fusion-review
/fugu-plan
/fugu-fix
/fugu-verify

The first MVP should prioritize Fusion-lite PR/diff review because it is easier, safer, and immediately useful. Fugu-lite should be implemented after the review workflow works reliably.

⸻

1. Product Summary

Create a Claude Code plugin named:

fusion-fugu-coding

The plugin should provide:

1. /fusion-review
   Multi-agent diff review with bug, test, security, architecture reviewers and a judge.
2. /fugu-plan
   Thinker-style planning command for complex coding tasks.
3. /fugu-fix
   Guided implementation workflow:
   plan → implement → run checks → fusion-review → repair if needed.
4. /fugu-verify
   Verifier command:
   run tests, inspect diff, check risks, produce approval/request-changes decision.

This plugin should not try to replace Claude Code’s built-in file editing, Bash, Read, Write, or MCP capabilities.

Instead:

Claude Code remains the execution runtime.
The plugin provides repeatable orchestration instructions and specialized review agents.

⸻

2. Design Principles

Follow these principles strictly:

1. Do not auto-merge.
2. Do not auto-push.
3. Do not commit unless the user explicitly asks.
4. Prefer git diff based review.
5. Keep implementation changes minimal.
6. Ask for human approval before destructive operations.
7. Treat .env, credentials, tokens, private keys, and secrets as forbidden.
8. Use repair loops with max iteration limits.
9. Separate planning, execution, verification, and review.
10. Prefer structured output over long prose.

For coding tasks, the intended roles are:

Fugu-lite = controller / manager
Claude Code = executor runtime
Fusion-lite = review committee
Subagents = specialized reviewers
Hooks = safety and verification guardrails

⸻

3. Expected Plugin Layout

Implement the plugin with this structure if compatible with the current Claude Code plugin format:

fusion-fugu-coding/
  README.md
  plugin.json                    # If required by current Claude Code plugin format
  skills/
    fusion-review/
      SKILL.md
      rubrics/
        bug-review.md
        test-review.md
        security-review.md
        architecture-review.md
        judge-rubric.md
      examples/
        review-output.json
    fugu-plan/
      SKILL.md
      templates/
        execution-plan.md
    fugu-fix/
      SKILL.md
      templates/
        repair-instruction.md
    fugu-verify/
      SKILL.md
      rubrics/
        verification-rubric.md
  agents/
    bug-reviewer.md
    test-reviewer.md
    security-reviewer.md
    architecture-reviewer.md
    fusion-judge.md
    fugu-thinker.md
    fugu-verifier.md
  hooks/
    prevent-secret-read.sh
    block-dangerous-bash.sh
    collect-diff-after-edit.sh
    run-checks-after-change.sh
  scripts/
    get-diff.sh
    detect-project.sh
    run-checks.sh
    secret-scan.sh
    summarize-diff.sh

If Claude Code’s current plugin format differs, adapt the directory structure while preserving the same capabilities.

⸻

4. MVP Scope

Build in phases.

Phase 1 — Fusion-lite Review

Implement /fusion-review.

Input:

Optional arguments:
- current git diff
- PR diff
- specific file path
- user-provided task description

Behavior:

1. Collect current git diff.
2. If no diff exists, ask whether to review the current branch, a file, or a user-provided patch.
3. Spawn specialized review perspectives:
   - bug reviewer
   - test reviewer
   - security reviewer
   - architecture reviewer
4. Merge findings using fusion judge.
5. Return structured decision:
   - approve
   - request_changes
   - needs_human_review
6. Include severity:
   - none
   - low
   - medium
   - high
   - critical
7. Include actionable issues only.
8. Filter obvious false positives.

Output format:

{
  "decision": "approve | request_changes | needs_human_review",
  "severity": "none | low | medium | high | critical",
  "summary": "short summary",
  "issues": [
    {
      "title": "issue title",
      "severity": "low | medium | high | critical",
      "file": "path/to/file",
      "evidence": "why this is likely a real issue",
      "suggested_fix": "minimal fix suggestion",
      "reviewer": "bug | test | security | architecture"
    }
  ],
  "confidence": "low | medium | high",
  "follow_up_commands": [
    "recommended command or check"
  ]
}

Important:

Do not output generic advice.
Only report issues grounded in the diff or repository evidence.
If evidence is insufficient, mark the item as needs_human_review instead of asserting it as a bug.

⸻

5. Reviewer Agent Specifications

Create these specialized agents if Claude Code plugin agents are supported.

5.1 bug-reviewer

Purpose:

Find runtime bugs, logic errors, broken assumptions, async race conditions, null/undefined errors, state bugs, and API contract violations.

Allowed behavior:

- Read changed files.
- Read nearby related files.
- Inspect tests.
- Use grep/search.

Avoid:

- Style-only comments.
- Large refactor suggestions.
- Unrelated architecture opinions.

Return:

{
  "reviewer": "bug",
  "issues": []
}

⸻

5.2 test-reviewer

Purpose:

Check whether tests cover the changed behavior.

Focus:

- Missing regression tests.
- Missing failure-path tests.
- Brittle snapshots.
- Untested async behavior.
- Untested edge cases.

Return only test issues that are justified by the diff.

⸻

5.3 security-reviewer

Purpose:

Check security, privacy, secret handling, injection, auth, authorization, SSRF, XSS, unsafe shell usage, token exposure, and dangerous file access.

Hard rules:

- Never read .env or secret files.
- Do not print secrets.
- If a diff appears to expose a secret, flag it immediately.

⸻

5.4 architecture-reviewer

Purpose:

Check maintainability, API boundaries, separation of concerns, framework conventions, frontend architecture, and unnecessary coupling.

Avoid:

- Preference-based comments.
- Overly broad rewrites.
- “Nice to have” suggestions unless they prevent future bugs.

⸻

5.5 fusion-judge

Purpose:

Merge reviewer outputs into one decision.

Judge rules:

1. Prefer concrete evidence over speculation.
2. Deduplicate overlapping findings.
3. Downgrade weak findings.
4. Escalate only if the issue can break runtime, security, data integrity, or deploy safety.
5. If reviewers disagree, expose the disagreement.
6. Final answer must be actionable.

⸻

6. Skill: /fusion-review

Create:

skills/fusion-review/SKILL.md

Suggested frontmatter:

---
name: fusion-review
description: Multi-agent code review for current git diff or provided patch. Use for PR review, final verification, bug/security/test review, and merge readiness checks.
disable-model-invocation: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git diff*)
  - Bash(git status*)
  - Bash(git show*)
  - Bash(git log*)
---

Skill body:

# Fusion Review
You are running a Fusion-lite multi-perspective code review.
## Input
Use $ARGUMENTS as the review target or instructions.
If no explicit diff is provided:
1. Run `git status --short`.
2. Run `git diff --stat`.
3. Run `git diff`.
4. If the diff is too large, summarize changed files first and review incrementally.
## Review Process
Perform four perspectives:
1. Bug reviewer
2. Test reviewer
3. Security reviewer
4. Architecture reviewer
Use subagents if available. If subagents are not available, simulate the four perspectives sequentially.
## Reviewer Rules
Each reviewer must produce:
- concrete findings only
- file path when available
- severity
- evidence
- suggested minimal fix
Do not include style-only comments.
## Judge Step
Merge reviewer outputs into a final JSON decision:
```json
{
  "decision": "approve | request_changes | needs_human_review",
  "severity": "none | low | medium | high | critical",
  "summary": "",
  "issues": [],
  "confidence": "low | medium | high",
  "follow_up_commands": []
}

Approval Rules

Return approve only when:

* no high-confidence correctness/security/test issues remain
* changed behavior is covered by tests or the lack of tests is acceptable and explained
* no secret or credential risk is present

Return request_changes when:

* there is a likely bug
* security risk exists
* tests are missing for changed behavior that can regress
* implementation contradicts the user request

Return needs_human_review when:

* evidence is insufficient
* behavior depends on product/business rules
* reviewers disagree on a high-impact point

Final Response

After the JSON, provide a short human-readable summary:

* What changed
* Whether it is safe to merge
* What must be fixed first

---
## 7. Skill: /fugu-plan
Create:
```text
skills/fugu-plan/SKILL.md

Purpose:

Plan complex coding tasks before implementation.

Suggested frontmatter:

---
name: fugu-plan
description: Create a Fugu-lite implementation plan using Thinker/Worker/Verifier roles before code changes.
disable-model-invocation: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git status*)
  - Bash(find *)
---

Behavior:

1. Understand the user task.
2. Inspect relevant files only.
3. Identify task type:
   - bugfix
   - feature
   - refactor
   - test
   - docs
   - architecture
4. Produce a plan with:
   - objective
   - relevant files
   - constraints
   - implementation steps
   - test strategy
   - risks
   - rollback strategy
   - verification commands
5. Do not edit files.

Output format:

# Fugu-lite Plan
## Objective
## Task Classification
## Relevant Files
## Constraints
## Implementation Plan
## Test Strategy
## Risk Checklist
## Verification Commands
## Suggested Worker Prompt

The Suggested Worker Prompt should be a ready-to-use instruction for Claude Code to execute the implementation.

⸻

8. Skill: /fugu-fix

Create:

skills/fugu-fix/SKILL.md

Purpose:

Run a controlled implementation loop:
plan → implement → verify → fusion review → repair.

Suggested frontmatter:

---
name: fugu-fix
description: Controlled coding workflow for bug fixes and feature work using plan, implementation, verification, review, and repair loop.
disable-model-invocation: true
allowed-tools:
  - Read
  - Edit
  - MultiEdit
  - Grep
  - Glob
  - Bash(git status*)
  - Bash(git diff*)
  - Bash(npm test*)
  - Bash(pnpm test*)
  - Bash(yarn test*)
  - Bash(npm run*)
  - Bash(pnpm run*)
  - Bash(yarn run*)
---

Workflow:

1. Thinker phase
   - Create implementation plan.
   - Identify files.
   - Define constraints.
2. Worker phase
   - Make minimal code changes.
   - Avoid unrelated refactors.
   - Keep public API stable unless requested.
3. Verifier phase
   - Run project-appropriate checks.
   - Prefer package manager detected from lockfile.
   - Run typecheck/lint/test when available.
4. Fusion review phase
   - Review final diff using Fusion-lite criteria.
   - If issues are found, enter repair loop.
5. Repair loop
   - Maximum 2 repair iterations.
   - Fix only review-identified issues.
   - Do not introduce new scope.

Important constraints:

- Never commit automatically.
- Never push automatically.
- Never edit secret files.
- Before destructive commands, ask the user.
- If tests fail for unrelated pre-existing reasons, document that clearly.

Final output:

# Fugu-lite Fix Result
## Summary
## Files Changed
## Checks Run
## Fusion Review Decision
## Remaining Risks
## Suggested Next Step

⸻

9. Skill: /fugu-verify

Create:

skills/fugu-verify/SKILL.md

Purpose:

Verify current changes without implementing new changes.

Suggested frontmatter:

---
name: fugu-verify
description: Verify current code changes using tests, diff inspection, and Fusion-lite review. Does not implement new changes unless user explicitly asks.
disable-model-invocation: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git status*)
  - Bash(git diff*)
  - Bash(npm test*)
  - Bash(pnpm test*)
  - Bash(yarn test*)
  - Bash(npm run*)
  - Bash(pnpm run*)
  - Bash(yarn run*)
---

Behavior:

1. Inspect current git status.
2. Inspect current diff.
3. Detect project package manager:
   - pnpm-lock.yaml → pnpm
   - yarn.lock → yarn
   - package-lock.json → npm
4. Detect available scripts from package.json:
   - test
   - typecheck
   - lint
   - build
5. Run reasonable verification commands.
6. Run Fusion-lite review.
7. Produce final decision.

Do not modify files unless the user explicitly asks.

⸻

10. Hooks

Implement hooks only if current Claude Code plugin hooks support this format.

10.1 Secret Protection Hook

Goal:

Block reading or printing sensitive files.

Deny patterns:

.env
.env.*
*.pem
*.key
id_rsa
id_ed25519
secrets/**
config/credentials.*
*.p12
*.pfx

Hook behavior:

If a tool call attempts to read or display these files, block and explain:
"Blocked: sensitive file access is not allowed by fusion-fugu-coding plugin."

⸻

10.2 Dangerous Bash Hook

Block or require confirmation for:

rm -rf
sudo
chmod -R 777
curl ... | sh
wget ... | sh
git push --force
git reset --hard
git clean -fd
docker system prune
kill -9

Behavior:

- Block by default.
- Allow only if user explicitly requested and confirmed.

⸻

10.3 Post-Edit Diff Collector

After file edits:

1. Run git diff --stat.
2. Save lightweight summary to plugin run log if supported.
3. Do not run full review automatically unless user invoked /fugu-fix.

⸻

10.4 Optional Async Test Hook

If safe and supported:

After file changes, run lightweight checks in the background.

Example:

pnpm typecheck
pnpm test -- --runInBand

Only run if scripts exist.

⸻

11. Scripts

Implement helper scripts if useful.

scripts/get-diff.sh

#!/usr/bin/env bash
set -euo pipefail
git status --short
echo ""
git diff --stat
echo ""
git diff

scripts/detect-project.sh

Detect:

- package manager
- framework
- test scripts
- build scripts
- monorepo packages

Output JSON.

scripts/secret-scan.sh

Scan staged/current diff for suspicious secrets.

Patterns:

OPENAI_API_KEY
ANTHROPIC_API_KEY
GITHUB_TOKEN
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
PRIVATE KEY
sk-
ghp_
xoxb-

Do not print the secret value. Print only file path and redacted match type.

scripts/run-checks.sh

Run best-effort checks:

1. package manager detection
2. script detection
3. typecheck if available
4. lint if available
5. test if available
6. build if requested or appropriate

Do not install dependencies automatically unless user confirms.

⸻

12. README Requirements

Create a README with:

1. What this plugin does
2. Installation
3. Commands
4. Example workflows
5. Safety rules
6. Known limitations
7. Recommended usage

Example usage:

/fusion-review
/fugu-plan "Add refresh token retry for expired sessions"
/fugu-fix "Fix the login token refresh bug with minimal changes"
/fugu-verify

⸻

13. Acceptance Criteria

The implementation is complete when:

1. Plugin can be installed or copied into a Claude Code project.
2. /fusion-review works on current git diff.
3. /fusion-review returns structured decision JSON.
4. /fugu-plan produces a usable implementation plan without editing files.
5. /fugu-fix performs a controlled plan → edit → verify → review loop.
6. /fugu-verify verifies current changes without editing files.
7. Secret files are protected.
8. Dangerous bash commands are blocked or require confirmation.
9. README explains installation and usage.
10. Plugin works in a sample TypeScript/Next.js repository.

⸻

14. Implementation Order

Do the work in this order:

1. Inspect current Claude Code plugin format and examples.
2. Create minimal plugin skeleton.
3. Implement /fusion-review first.
4. Add reviewer agents.
5. Add fusion judge.
6. Test against a small sample diff.
7. Implement /fugu-plan.
8. Implement /fugu-verify.
9. Implement /fugu-fix.
10. Add hooks and safety scripts.
11. Write README.
12. Run self-review using /fusion-review.

Do not start with hooks or complex automation. The first working milestone must be /fusion-review.

⸻

15. Research Mapping

Use this mapping when designing behavior:

OpenRouter Fusion idea:
- panel reviewers
- judge synthesis
- consensus/contradiction/blind spot extraction
- structured final answer
Sakana Fugu / TRINITY / Conductor idea:
- Thinker / Worker / Verifier roles
- dynamic task decomposition
- executor selection
- repair loop
- prompt generation for worker agents
Claude Code plugin implementation:
- skills for slash-command workflows
- subagents for specialized reviewers
- hooks for safety and lifecycle controls
- scripts for deterministic checks

⸻

16. Non-goals

Do not implement:

1. A separate web app.
2. A separate LLM gateway.
3. Model training.
4. Real OpenRouter Fusion API integration.
5. Real Sakana Fugu API integration.
6. Automatic commit/push/merge.
7. Autonomous long-running background agents.
8. Custom external MCP server unless needed later.

This plugin should be local, practical, and Claude Code-native.

⸻

17. Final Deliverable

Return:

1. File tree
2. Created files
3. Key design choices
4. How to install
5. How to test
6. Example command outputs
7. Known limitations
8. Next improvements

After implementation, run a self-review:

/fusion-review

Then fix high-confidence issues only.