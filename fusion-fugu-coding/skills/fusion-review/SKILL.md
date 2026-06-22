---
name: fusion-review
description: Fusion-lite multi-agent code review of the current git diff or a provided patch/file. Spawns bug, test, security, and architecture reviewers, then a judge merges findings into one structured decision. Use for PR review, pre-merge checks, final verification, and bug/security/test sweeps.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Task, Bash(git diff:*), Bash(git status:*), Bash(git show:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git branch:*)
---

# Fusion Review

You are running a **Fusion-lite** multi-perspective code review: several specialized
reviewers inspect the same change, then a judge merges their findings into one
structured, actionable decision.

Follow the safety principles in `${CLAUDE_PLUGIN_ROOT}/README.md`: never auto-merge,
never auto-push, never commit, never read secret files, and prefer evidence over
speculation.

## 1. Determine the review target

`$ARGUMENTS` holds the review target or instructions (may be empty). Interpret it:

- Empty → review the current uncommitted working-tree changes.
- A file path → review that file's changes (`git diff -- <path>`), or the whole
  file if it is untracked/unchanged.
- A git ref / range (e.g. `main..HEAD`, `origin/main...`, a branch, a SHA) →
  `git diff <range>`.
- A free-text task description → use it as the *intent* the change should satisfy,
  and review the current diff against that intent.

Collect context with read-only git only:

1. `git rev-parse --is-inside-work-tree` — confirm we are in a repo. If not, ask the
   user to paste a unified diff or point at a file.
2. `git status --short`
3. `git diff --stat` (and `--stat` for the chosen range)
4. `git diff` (the chosen target)

If there is **no diff** and no patch was provided, ask whether to review:
(a) the current branch vs its base, (b) a specific file, or (c) a pasted patch.
Do not invent changes to review.

If the diff is large (say > ~1500 changed lines or many files), first summarize the
changed files, then review the highest-risk files; state explicitly what you did and
did not deep-review.

## 2. Run four reviewer perspectives

Review along four perspectives. **Prefer real subagents** — spawn them with the Task
tool, in parallel, one per perspective, so each reasons in an isolated context:

| Perspective   | Subagent (`subagent_type`) | Rubric |
|---------------|----------------------------|--------|
| Bug           | `bug-reviewer`             | `rubrics/bug-review.md` |
| Test          | `test-reviewer`            | `rubrics/test-review.md` |
| Security      | `security-reviewer`        | `rubrics/security-review.md` |
| Architecture  | `architecture-reviewer`    | `rubrics/architecture-review.md` |

Give each subagent: the diff (or how to obtain it), the changed file list, and the
user's stated intent if any. Instruct each to return **only** a JSON object:

```json
{ "reviewer": "bug | test | security | architecture", "issues": [ /* see rubric */ ] }
```

If the Task tool / subagents are unavailable, **simulate** the four perspectives
yourself, sequentially, applying each rubric file in
`${CLAUDE_PLUGIN_ROOT}/skills/fusion-review/rubrics/` one at a time. Keep the
perspectives genuinely separate — do not let one bleed into another.

### Reviewer rules (all perspectives)

Each finding must include: concrete evidence tied to the diff/repo, a file path
(and line/hunk when available), a severity, and a minimal suggested fix.

- Report **actionable, grounded** issues only. No style-only nits, no speculative
  "could be nicer", no broad rewrites.
- If evidence is insufficient to assert a bug, mark it `needs_human_review` rather
  than asserting it.
- Security: never open `.env`/secret files; if the diff exposes a secret, flag it
  immediately and do not echo the value.

## 3. Judge step — merge into one decision

Apply `rubrics/judge-rubric.md` (you may spawn the `fusion-judge` subagent with the
four reviewer JSONs, or merge inline). The judge must:

1. Prefer concrete evidence over speculation.
2. Deduplicate overlapping findings (same root cause → one issue).
3. Downgrade weak/low-evidence findings.
4. Escalate only issues that can break runtime, security, data integrity, or deploy
   safety.
5. If reviewers disagree on a high-impact point, expose the disagreement.
6. Keep every surviving issue actionable.

Emit the final decision as JSON (schema in
`${CLAUDE_PLUGIN_ROOT}/skills/fusion-review/examples/review-output.json`):

```json
{
  "decision": "approve | request_changes | needs_human_review",
  "severity": "none | low | medium | high | critical",
  "summary": "one or two sentences",
  "issues": [
    {
      "title": "issue title",
      "severity": "low | medium | high | critical",
      "file": "path/to/file",
      "evidence": "why this is likely a real issue, grounded in the diff",
      "suggested_fix": "minimal fix suggestion",
      "reviewer": "bug | test | security | architecture"
    }
  ],
  "confidence": "low | medium | high",
  "follow_up_commands": ["recommended command or check"]
}
```

### Decision rules

Return **approve** only when:
- no high-confidence correctness/security/test issues remain, and
- changed behavior is covered by tests, or the lack of tests is acceptable and
  explained, and
- no secret or credential risk is present.

Return **request_changes** when:
- there is a likely bug, or
- a security risk exists, or
- tests are missing for changed behavior that can regress, or
- the implementation contradicts the user's stated request.

Return **needs_human_review** when:
- evidence is insufficient, or
- behavior depends on product/business rules, or
- reviewers disagree on a high-impact point.

## 4. Final human-readable summary

After the JSON, add a short plain-language summary:

- **What changed** — one or two lines.
- **Safe to merge?** — yes / no / needs human, and the single most important reason.
- **Fix first** — the ordered list of must-fix items (or "nothing blocking").

Keep prose short. The JSON is the contract; the summary is the courtesy.
