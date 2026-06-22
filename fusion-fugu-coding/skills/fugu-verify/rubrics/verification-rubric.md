# Verification Rubric

**Goal:** decide whether the current change is correct, tested, and safe to hand off —
without changing it.

## Checklist
1. **Scope** — does the diff match the stated intent? Anything unexpected/out of scope?
2. **Build/typecheck** — runs clean? New type errors introduced by this change?
3. **Lint** — new violations introduced by this change (ignore pre-existing noise)?
4. **Tests**
   - Do existing tests pass?
   - Is the changed behavior covered (happy path + failure/edge path)?
   - Any test skipped/weakened to make it pass?
5. **Secrets** — does the diff add a secret/credential? (Run the secret scan. Never
   print values.)
6. **Failure attribution** — for every failure, is it **caused by this change** or
   **pre-existing/unrelated**? Show the evidence (e.g. failure also reproduces on the
   base ref).
7. **Risk** — runtime, security, data-integrity, or deploy-safety concerns remaining?

## Running checks
- Detect the package manager from the lockfile; use existing `package.json` scripts.
- Do **not** install dependencies. If a tool is missing, skip and report it.
- Prefer running only the relevant test files when the suite is large/slow.

## Decision
- **approve** — checks that can run pass, changed behavior is covered (or the gap is
  acceptable and explained), no secret risk, no unresolved high/critical issue.
- **request_changes** — a check fails because of this change, a real bug/security/test
  gap exists, or the diff contradicts the intent.
- **needs_human_review** — checks can't run, evidence is thin, or the decision depends
  on product/business rules.

## Honesty rules
- Never claim success for a check you didn't actually run.
- State clearly when nothing could be verified (no scripts / missing tools) — that is
  `needs_human_review`, not `approve`.
