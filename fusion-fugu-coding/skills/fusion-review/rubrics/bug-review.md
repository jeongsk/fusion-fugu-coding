# Bug Review Rubric

**Goal:** find real runtime/logic defects introduced or exposed by the change.

## Look for
- Logic errors and broken assumptions (off-by-one, inverted conditions, wrong operator).
- Null/undefined/`None` dereferences; unchecked optional access; missing guards.
- Async/concurrency bugs: unawaited promises, races, lost errors in `catch`,
  unhandled rejections, shared mutable state, ordering assumptions.
- State bugs: stale closures, mutation of inputs, incorrect caching/memoization,
  reused references.
- Error handling: swallowed exceptions, wrong error type, failure paths that leave
  partial state.
- API/contract violations: wrong argument order/shape, changed return type, broken
  callers, mismatched units, boundary/empty-input handling.
- Resource issues: leaked handles/connections, missing cleanup, unbounded growth.
- Off-nominal inputs: empty arrays, zero, negative, very large, unicode, timezones.

## Method
1. Read the changed hunks. Then read the nearby/related code and the callers of any
   changed function — a diff can be correct in isolation but break a caller.
2. Check the tests for the changed area to see which assumptions are enforced.
3. For each candidate bug, write the concrete trigger ("when X is empty, line N throws").

## Avoid
- Style-only comments, naming preferences, formatting.
- Large refactor suggestions or architecture opinions (that is another reviewer's job).
- Speculative "might be slow/ugly" without a concrete failing path.

## Severity guide
- **critical** — crashes/corrupts data on a common path, or breaks a core contract.
- **high** — wrong result or crash on a realistic path.
- **medium** — bug on an edge case or uncommon path.
- **low** — minor robustness gap unlikely to trigger.

## Output (return ONLY this JSON)
```json
{
  "reviewer": "bug",
  "issues": [
    {
      "title": "",
      "severity": "low | medium | high | critical",
      "file": "path/to/file",
      "evidence": "concrete trigger grounded in the diff/related code",
      "suggested_fix": "minimal fix"
    }
  ]
}
```
If you find nothing grounded, return `{ "reviewer": "bug", "issues": [] }`.
