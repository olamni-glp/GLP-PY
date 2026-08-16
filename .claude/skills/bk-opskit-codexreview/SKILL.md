---
name: "bk-opskit-codexreview"
description: "BK-OpsKit codexreview: local Codex CLI code review of the working diff with persisted verdicts, a cached fast path (<2 s on a cache hit), secret-scan refusal on the diff, finding classification, and BreenLake trend emission (degrade-to-outbox). Advisory — never switches branches, blocks a merge, or auto-invokes a buildkit-* command (FR-027)."
argument-hint: "[classify | clear-cache] [--base <ref>] [--paths <p>]… [--focus <text>] [--force] [--max-seconds <n>] [--reasoning-effort <e>] [--allow-secrets-in-diff --secret-override-reason <text>]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-opskit-codexreview.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-opskit-codexreview` is the code-review surface of BK-OpsKit (round-trips to
`buildkit-opskit codexreview`). It runs a local Codex CLI review of the working diff,
persists the verdict + artefacts, caches per `(branch, diff, focus)` for the fast path,
refuses on a secret-bearing diff (override is recorded to the audit trail), and emits
review trends to BreenLake through the outbox seam.

## How to run it

```
buildkit-opskit codexreview
buildkit-opskit codexreview --base <ref> --focus <text> --force
buildkit-opskit codexreview classify
buildkit-opskit codexreview clear-cache
```

`--paths <p>` (repeatable) scopes the diff; `--max-seconds <n>` bounds the Codex
subprocess; `--reasoning-effort <e>` sets the Codex effort. A secret-bearing diff refuses
unless `--allow-secrets-in-diff` is given with a recorded `--secret-override-reason <text>`.

## Exit codes (ratified S4 contract)

- `0` — review completed (findings are advisory output, never a gate).
- `1` — usage error / malformed input (e.g. an unclassifiable payload).
- `2` — refusal (secret-bearing diff without the recorded override) or environment error.

## Boundaries (do NOT) — FR-027

- Advisory only: auto-invokes **no** buildkit-* pipeline command; switches **no** git branch;
  blocks **no** merge.
- The diff's secret scan refuses by default; the override is explicit + audit-recorded.
- Verdicts/cache rows land additively in buildkit's PGlite catalog; outputs secret-redacted (FR-024).

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-opskit` from the project root — it
always exits 0 (fail-safe; never blocks). Ignore its output.
