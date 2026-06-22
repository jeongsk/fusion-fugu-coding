---
name: fugu-plan
description: Fugu-lite Thinker planning for a coding task before any edits. Classifies the task, inspects only relevant files, and produces an execution plan (objective, files, constraints, steps, test strategy, risks, rollback, verification commands, and a ready-to-use worker prompt). Does NOT edit files. Use before starting a non-trivial change.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Task, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(find:*), Bash(ls:*)
---

# Fugu-lite Plan (Thinker)

Plan a coding task before implementation. This is the **Thinker** role: think, don't
build. **Do not edit any files in this skill.**

## Input
`$ARGUMENTS` is the task to plan (e.g. "Add refresh-token retry for expired sessions").
If empty, ask for the task in one short prompt.

## Process
You may run this inline or delegate to the `fugu-thinker` subagent via the Task tool
(preferred for an isolated, focused plan). Either way:

1. **Understand the task.** If genuinely ambiguous in a way that changes the plan,
   state your assumption explicitly and proceed — don't stall on questions.
2. **Inspect relevant files only** (grep/glob/read). Never read secret files.
3. **Classify** the task: `bugfix | feature | refactor | test | docs | architecture`.
4. **Detect the project** (package manager from lockfile, test/lint/typecheck/build
   scripts) so verification commands are real. You may run
   `${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh`.
5. **Produce the plan** using the template at
   `${CLAUDE_PLUGIN_ROOT}/skills/fugu-plan/templates/execution-plan.md`.

## Principles
- Smallest change that fully solves the task. Keep public APIs stable unless the task
  requires otherwise.
- Make risks and a rollback path explicit.
- Verification commands must be concrete and runnable.
- Do not edit files. The deliverable is the plan.

## Output
Emit the filled-in execution plan. End with a **Suggested Worker Prompt**: a
ready-to-paste instruction for Claude Code (or `/fugu-fix`) to execute the plan.
