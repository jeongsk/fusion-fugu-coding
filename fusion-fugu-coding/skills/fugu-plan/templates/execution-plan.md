# Fugu-lite Plan

## Objective
<One or two sentences: what success looks like, in user-visible terms.>

## Task Classification
<bugfix | feature | refactor | test | docs | architecture> — <one line of why.>

## Relevant Files
- `path/to/file` — <role in this change; what will change here.>
- `path/to/other` — <read-only context / caller / test.>

## Constraints
- <Public API stability, performance budget, framework conventions, no new deps, etc.>
- Safety: no auto-commit/push, no secret files, ask before destructive ops.

## Implementation Plan
1. <Smallest first step, tied to a specific file/function.>
2. <Next step.>
3. <…> (keep steps minimal and ordered; avoid unrelated refactors.)

## Test Strategy
- <Which existing tests cover this; which new test(s) to add and the exact case(s).>
- <How to test the failure path / edge cases introduced.>

## Risk Checklist
- [ ] Could this break callers of a changed function?
- [ ] Any async/race/error-handling risk?
- [ ] Any security/secret/auth surface touched?
- [ ] Migration/back-compat/data implications?
- [ ] What is explicitly out of scope?

## Verification Commands
```bash
# Use the detected package manager + existing scripts; e.g.
pnpm typecheck
pnpm lint
pnpm test path/to/relevant.test.ts
```

## Suggested Worker Prompt
> <A ready-to-paste instruction for Claude Code / /fugu-fix that captures the
> objective, the files to touch, the constraints, and the verification commands —
> specific enough to execute without re-deriving this plan.>
