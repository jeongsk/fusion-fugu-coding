# fusion-fugu-coding

A Claude Code plugin that adds a **multi-reviewer code review committee** (Fusion-lite)
and a **controlled plan → fix → verify orchestration** (Fugu-lite) on top of Claude
Code. Claude Code stays the executor; this plugin supplies repeatable orchestration and
specialized review perspectives, plus safety guardrails.

- **Fusion-lite** — several specialized reviewers (bug, test, security, architecture)
  inspect the same diff, then a judge merges their findings into one structured
  decision. Inspired by OpenRouter Fusion (panel + judge synthesis).
- **Fugu-lite** — Thinker / Worker / Verifier roles with a bounded repair loop, built
  from skills + subagents + hooks. Inspired by Sakana AI Fugu / TRINITY / Conductor.
  It does **not** train any model — it approximates the roles with prompts.

---

## 1. What this plugin does

| Command | Role | What it does |
|---------|------|--------------|
| `/fusion-fugu-coding:fusion-review` | Review committee | Multi-agent review of the current git diff / a ref range / a file. Returns a structured decision JSON + human summary. |
| `/fusion-fugu-coding:fugu-plan` | Thinker | Plans a coding task before any edits: classification, files, steps, tests, risks, rollback, verification commands, and a ready-to-use worker prompt. **No edits.** |
| `/fusion-fugu-coding:fugu-fix` | Worker + loop | Controlled `plan → implement → verify → fusion review → repair` loop (max 2 repair iterations). Minimal edits, never commits/pushes. |
| `/fusion-fugu-coding:fugu-verify` | Verifier | Verifies current changes: runs detected checks, secret-scans the diff, runs a Fusion review, returns a decision. **No edits** unless you ask. |

> **Command names are namespaced by the plugin.** Inside Claude Code they appear as
> `/fusion-fugu-coding:fusion-review`, etc. (the plan's shorthand `/fusion-review` is
> the same command without the prefix). Type `/` and start typing `fusion` or `fugu`
> to find them.

It also ships:

- **7 subagents** in `agents/` — `bug-reviewer`, `test-reviewer`, `security-reviewer`,
  `architecture-reviewer`, `fusion-judge`, `fugu-thinker`, `fugu-verifier`.
- **Safety hooks** in `hooks/` — block sensitive-file reads, require confirmation for
  destructive shell commands, log post-edit diffs, optional async typecheck.
- **Deterministic helper scripts** in `scripts/` — diff collection, project detection,
  best-effort checks, secret scanning, diff summarization.

---

## 2. Installation

### Option A — local dev (fastest)

Run Claude Code with the plugin directory:

```bash
claude --plugin-dir /path/to/fusion-fugu-coding
```

After editing plugin files during development, reload without restarting:

```
/reload-plugins
```

### Option B — via the bundled marketplace

This repo's root contains `.claude-plugin/marketplace.json`. From Claude Code:

```
/plugin marketplace add /path/to/this/repo
/plugin install fusion-fugu-coding@fusion-fugu-marketplace
```

### Verify it loaded

Type `/` and you should see `fusion-fugu-coding:fusion-review`, `…:fugu-plan`,
`…:fugu-fix`, `…:fugu-verify`. The hooks register automatically.

Requirements: `git`, plus `python3` and/or `jq` for the scripts/hooks (both are used
with graceful fallbacks). For Node projects, the verifier uses your existing
`package.json` scripts and the package manager implied by your lockfile.

---

## 3. Commands

### `/fusion-fugu-coding:fusion-review [target]`
Multi-agent review. `target` may be empty (current working-tree diff), a file path, a
git ref/range (`main..HEAD`, a branch, a SHA), or a free-text intent to review the diff
against. Spawns the four reviewers (in parallel when subagents are available), then the
judge. Output:

```json
{
  "decision": "approve | request_changes | needs_human_review",
  "severity": "none | low | medium | high | critical",
  "summary": "…",
  "issues": [
    { "title": "…", "severity": "…", "file": "…", "evidence": "…",
      "suggested_fix": "…", "reviewer": "bug | test | security | architecture" }
  ],
  "confidence": "low | medium | high",
  "follow_up_commands": ["…"]
}
```
followed by a short *what changed / safe to merge? / fix first* summary.

### `/fusion-fugu-coding:fugu-plan "<task>"`
Produces a `Fugu-lite Plan` (objective, classification, relevant files, constraints,
implementation steps, test strategy, risk checklist, verification commands, and a
**Suggested Worker Prompt**). Does not edit files.

### `/fusion-fugu-coding:fugu-fix "<task>"`
Runs the controlled loop and emits a `Fugu-lite Fix Result` (summary, files changed,
checks run, fusion decision, remaining risks, next step). Minimal edits, bounded repair
(≤2), never commits/pushes.

### `/fusion-fugu-coding:fugu-verify [scope]`
Inspects status/diff, detects the package manager and scripts, runs available checks,
secret-scans the diff, runs a Fusion review, and returns a decision. No edits.

---

## 4. Example workflows

**Review before merging**
```
/fusion-fugu-coding:fusion-review
# or review a branch against main:
/fusion-fugu-coding:fusion-review main..HEAD
```

**Plan, then implement a fix with guardrails**
```
/fusion-fugu-coding:fugu-plan "Add refresh token retry for expired sessions"
/fusion-fugu-coding:fugu-fix  "Fix the login token refresh bug with minimal changes"
/fusion-fugu-coding:fugu-verify
```

**Just verify the current changes**
```
/fusion-fugu-coding:fugu-verify
```

---

## 5. Safety rules (enforced or instructed)

1. **No auto-merge, no auto-push, no auto-commit.** Commits happen only when you ask.
2. **Secret files are off-limits.** A `PreToolUse` hook denies reads/edits of `.env*`,
   `*.pem`, `*.key`, `id_rsa`/`id_ed25519`, `secrets/**`, `config/credentials.*`,
   `*.p12`/`*.pfx`, `.ssh/**`, `.aws/credentials`. Secret values are never printed.
3. **Destructive shell commands require confirmation.** A `PreToolUse` hook returns
   `ask` for `rm -rf`, `sudo`, `chmod 777`, `curl|wget | sh`, `git push --force`,
   `git reset --hard`, `git clean -f`, `docker prune`, `kill -9`, `mkfs`,
   `dd of=/dev/…`, fork bombs.
4. **Diff-based review** is preferred; changes are kept minimal and on-scope.
5. **Bounded repair loop** — `/fugu-fix` repairs at most twice, then hands back.
6. **Evidence over speculation** — reviewers report only grounded, actionable issues;
   thin-evidence items become `needs_human_review`.

These guardrails are defense-in-depth on top of Claude Code's own permission system —
they are not a substitute for reviewing what the agent does.

---

## 6. Known limitations

- **Heuristic, not a sandbox.** The bash hook uses pattern matching; a sufficiently
  obfuscated command can evade it. Keep Claude Code's permission prompts on.
- **Secret scan is regex-based.** It catches common token shapes and key blocks; it
  will miss novel/proprietary formats and may false-positive on high-entropy strings.
- **Review quality depends on the diff and the model.** Very large diffs are summarized
  and reviewed incrementally; coverage is stated, not guaranteed.
- **Command names are namespaced** (`/fusion-fugu-coding:…`), not the bare `/fusion-review`.
- **Node-centric checks.** `detect-project.sh` / `run-checks.sh` understand
  npm/pnpm/yarn/bun + `package.json` scripts. Other ecosystems: run their checks
  manually (or extend the scripts).
- **Subagents may be unavailable** in some contexts; the skills fall back to simulating
  the four perspectives sequentially.
- **The optional auto-typecheck hook is off by default** (set
  `FUSION_FUGU_AUTOCHECK=1` to enable). It never runs your full test suite.

---

## 7. Recommended usage

- Use **`/fugu-plan` first** for anything non-trivial; paste its *Suggested Worker
  Prompt* into `/fugu-fix` (or run `/fugu-fix` directly for small, well-scoped fixes).
- Use **`/fusion-review`** as a pre-commit / pre-PR gate. Treat `request_changes` and
  `needs_human_review` as stop signals.
- Use **`/fugu-verify`** right before you commit, to attribute any failures to *this*
  change vs. pre-existing ones.
- Keep commits in **your** hands — the plugin will never do it for you.

---

## 8. Layout

```
fusion-fugu-coding/
  .claude-plugin/plugin.json      # manifest
  README.md
  skills/
    fusion-review/ SKILL.md  rubrics/{bug,test,security,architecture,judge}.md  examples/review-output.json
    fugu-plan/     SKILL.md  templates/execution-plan.md
    fugu-fix/      SKILL.md  templates/repair-instruction.md
    fugu-verify/   SKILL.md  rubrics/verification-rubric.md
  agents/ bug-reviewer.md test-reviewer.md security-reviewer.md architecture-reviewer.md
          fusion-judge.md fugu-thinker.md fugu-verifier.md
  hooks/  hooks.json
          prevent-secret-read.sh block-dangerous-bash.sh
          collect-diff-after-edit.sh run-checks-after-change.sh
  scripts/ get-diff.sh detect-project.sh run-checks.sh secret-scan.sh summarize-diff.sh
```

## 9. Design mapping

- **OpenRouter Fusion → Fusion-lite**: panel reviewers + judge synthesis;
  consensus/contradiction/blind-spot resolution; one structured final answer.
- **Sakana Fugu / TRINITY / Conductor → Fugu-lite**: Thinker / Worker / Verifier roles,
  task decomposition, a bounded repair loop, and worker-prompt generation.
- **Claude Code primitives**: skills (slash-command workflows), subagents (reviewers),
  hooks (safety/lifecycle), scripts (deterministic checks).

This plugin is intentionally local, practical, and Claude Code-native. It does not add a
web app, an LLM gateway, model training, or any external Fusion/Fugu API.
