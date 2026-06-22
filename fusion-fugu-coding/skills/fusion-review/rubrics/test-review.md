# Test Review Rubric

**Goal:** decide whether the *changed behavior* is adequately tested. Judge tests
against the diff, not against an ideal of 100% coverage.

## Look for
- **Missing regression test** for the specific behavior the diff changes/fixes.
- **Missing failure-path tests**: error branches, thrown exceptions, rejected promises.
- **Untested edge cases**: empty/zero/null/boundary inputs touched by the change.
- **Untested async behavior**: ordering, timeouts, retries, cancellation.
- **Brittle tests**: large snapshot assertions, time/randomness/order dependence,
  over-mocking that asserts implementation instead of behavior.
- **Wrong-level tests**: a unit test that mocks away the thing the change actually
  affects, so it would still pass if the code were broken.
- Tests that were not updated to match an intentional behavior change (now asserting
  the old contract, or silently skipped).

## Method
1. Identify exactly what behavior changed.
2. Search the test suite (`grep`/`glob`) for tests covering the changed symbols/paths.
3. For each changed behavior with no test, ask: *can this realistically regress?* Only
   flag when a regression is plausible and would go unnoticed.

## Avoid
- Demanding tests for trivial/throwaway code, generated code, or pure config.
- "Add more tests" with no specific behavior named.
- Coverage-percentage complaints.

## Severity guide
- **high** — changed behavior on a critical path with no test; silent regression likely.
- **medium** — changed behavior with no test, moderate regression risk.
- **low** — minor gap or brittle test worth noting.

## Output (return ONLY this JSON)
```json
{
  "reviewer": "test",
  "issues": [
    {
      "title": "",
      "severity": "low | medium | high",
      "file": "path/to/file or test file",
      "evidence": "which changed behavior is untested and why it can regress",
      "suggested_fix": "the specific test to add (name the case)"
    }
  ]
}
```
If tests are adequate, return `{ "reviewer": "test", "issues": [] }`.
