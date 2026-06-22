# Repair Instruction (bounded loop)

Use this when a Fusion review returns `request_changes` during `/fugu-fix`.

## Rules
- Fix **only** the issues the review identified, plus check failures it pointed to.
- **No new scope.** Do not refactor, rename, or "improve" unrelated code.
- Re-run the same checks after each repair.
- **Hard cap: 2 repair iterations.** Count them.

## Per-iteration record
```
### Repair iteration <n>/2
- Issue addressed: <title> (severity, reviewer)
- Change made: <file(s) + minimal edit>
- Re-check result: <command → pass/fail>
- Re-review decision: <approve | request_changes | needs_human_review>
```

## On exhausting the cap (still failing after 2)
Stop editing and hand back to the user with:
- **What is fixed** vs **what remains** (with evidence).
- **Why it could not be resolved in scope** (e.g. needs a product decision, a larger
  refactor, or more context).
- **Recommended next step** — e.g. widen scope with explicit approval, escalate to a
  human, or split into a follow-up task.

Never exceed the cap silently. Never commit/push to "finish".
