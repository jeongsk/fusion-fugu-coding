# Security Review Rubric

**Goal:** find security, privacy, and secret-handling defects introduced or exposed by
the change. Be concrete and evidence-based — security theater helps no one.

## Hard rules
- **Never open `.env`, `.env.*`, `*.pem`, `*.key`, `id_rsa`, `secrets/**`, credential
  files, keystores (`*.p12`/`*.pfx`).** Review only the diff and ordinary source.
- **Never print a secret value.** If the diff contains one, report the file + a
  redacted match type (e.g. "AWS secret key") — not the value.

## Look for
- **Hardcoded secrets / committed credentials**: API keys, tokens, passwords,
  private keys appearing in the diff. Flag immediately.
- **Injection**: SQL/NoSQL, command/shell, code `eval`, template, LDAP, path
  traversal — anywhere user input reaches an interpreter without parameterization.
- **AuthN/AuthZ**: missing/weak auth checks, broken access control, IDOR, privilege
  escalation, trusting client-supplied identity/role.
- **SSRF / unsafe fetch**: user-controlled URLs, internal metadata endpoints.
- **XSS / output encoding**: unescaped user data in HTML/DOM, `dangerouslySetInnerHTML`,
  unsanitized markdown.
- **Unsafe shell/file usage**: `child_process` with interpolation, `shell: true`,
  unvalidated paths, archive extraction (zip-slip).
- **Crypto / secret handling**: weak/rolled-own crypto, predictable randomness for
  security, secrets in logs/URLs/error messages, tokens with no expiry.
- **Deserialization / SSTI / prototype pollution**; permissive CORS; missing input
  validation on a trust boundary.
- **Dependency risk**: newly added dependency that is unexpected/typo-squatted or
  fetched insecurely.

## Method
1. Trace untrusted input from entry point to sink. A finding needs both a source
   (attacker-controllable) and a sink (dangerous use).
2. Prefer "here is the input, here is the unsafe sink, here is the impact" over labels.

## Severity guide
- **critical** — exposed secret, RCE, auth bypass, trivial injection on a reachable path.
- **high** — exploitable injection/SSRF/XSS/access-control gap with realistic reach.
- **medium** — security weakness needing specific preconditions.
- **low** — hardening gap / defense-in-depth.

## Output (return ONLY this JSON)
```json
{
  "reviewer": "security",
  "issues": [
    {
      "title": "",
      "severity": "low | medium | high | critical",
      "file": "path/to/file",
      "evidence": "source -> sink -> impact, grounded in the diff (no secret values)",
      "suggested_fix": "minimal, specific remediation"
    }
  ]
}
```
If nothing is grounded, return `{ "reviewer": "security", "issues": [] }`.
