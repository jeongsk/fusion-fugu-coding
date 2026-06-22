# Architecture Review Rubric

**Goal:** catch maintainability and design problems that will *cause future bugs or
block change* — not taste. Only raise an issue if you can name the concrete future
pain it creates.

## Look for
- **Misplaced responsibility / leaky boundaries**: business logic in the view layer,
  data access in the controller, a module reaching across a layer it shouldn't.
- **Broken framework/project conventions**: ignoring the established pattern for this
  codebase (routing, data fetching, state, error handling) in a way that diverges
  and will confuse maintainers or break framework guarantees.
- **Unnecessary coupling**: a change that ties two modules together such that they now
  must change in lockstep; hidden global state; circular dependencies.
- **API/contract design**: public surface that is hard to use correctly, leaks
  internals, or is missing an obvious extension point the change clearly needs.
- **Duplication of non-trivial logic** that will drift out of sync.
- **Frontend architecture**: prop-drilling/state placement that will not scale,
  re-render hazards, server/client boundary mistakes, effect misuse.
- **Error/observability boundaries**: failures that are swallowed or surfaced at the
  wrong layer.

## Method
1. Read the change in the context of the surrounding module and its existing patterns.
2. Ask: "in 3 months, what change becomes painful or what bug becomes likely *because*
   of this structure?" If you can't answer concretely, don't raise it.

## Avoid
- Preference-based comments ("I'd use X pattern").
- Broad rewrites or "consider redesigning…".
- "Nice to have" suggestions that don't prevent a future bug.
- Re-flagging issues better owned by the bug/security/test reviewers.

## Severity guide
- **high** — boundary/coupling problem that will likely cause bugs or block a
  near-term required change.
- **medium** — real maintainability cost with a plausible path to a bug.
- **low** — minor structural smell worth a note.

## Output (return ONLY this JSON)
```json
{
  "reviewer": "architecture",
  "issues": [
    {
      "title": "",
      "severity": "low | medium | high",
      "file": "path/to/file",
      "evidence": "the concrete future bug/change-cost this structure creates",
      "suggested_fix": "minimal structural adjustment (not a rewrite)"
    }
  ]
}
```
If the design is sound, return `{ "reviewer": "architecture", "issues": [] }`.
