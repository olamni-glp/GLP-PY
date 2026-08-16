---
name: "bk-builder"
description: "Advisory pipeline status, switch, history, and team coordinator for buildkit's buildkit workflows. Reports per-stage state for every feature, who holds which spec, recommends the next /buildkit-* command to run, never invokes one itself (FR-012)."
argument-hint: "[status|coordinator|switch <feature_id>|history [--stage <s>] [--status <s>]]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-builder.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-builder` is the **advisory orchestrator** for the buildkit pipeline.
It reports where every feature stands and recommends the next `/buildkit-*`
command to run. It does **not** invoke `/buildkit-*` commands itself (FR-012);
the user remains the actor who drives each stage.

Sub-commands:

- `/bk-builder` (default) — project-wide status + per-stage state for the
  active feature + recommendation.
- `/bk-builder status` — same as default.
- `/bk-builder coordinator` — **team-coordinator roll-up** over *every*
  active spec: holder, claim kind, current stage, blocked status, with
  near-expiry (<15 min) leases and recent takeovers flagged prominently
  (spec-009 FR-005/FR-006/FR-007). Read-only and advisory: it never invokes a
  `/buildkit-*` command (FR-008). Pair with `buildkit lock`/`lease`/`claims`.
- `/bk-builder switch <feature_id>` — pause the current active feature
  and activate `<feature_id>`. Both transitions are recorded durably (R7).
- `/bk-builder history [--stage <s>] [--status <s>]` — chronological
  transitions for the active feature, newest first.

## Outline

1. Run `python -m buildkit_cli.pipeline.cli $ARGUMENTS` from the project root
   (or `buildkit-builder $ARGUMENTS` if the console script is on PATH). The
   CLI exits non-zero on database errors:
     - exit `1`: invalid sub-command or unknown feature.
     - exit `2`: PGlite/pgdb-runner unavailable (most likely the lock is held
       by another session or Node 20+ is missing).
2. Print the CLI output verbatim. Do not edit, summarize, or reformat — the
   user-facing format is the contract surface (contracts/pipeline-cli.md).
3. If exit code is non-zero, surface the error message to the user without
   wrapping it in extra prose.

## Key invariants

- **Advisory only**: this skill never runs `/buildkit-*` commands. The
  recommendation it prints is for the user to copy/paste.
- **Read-mostly**: the skill writes to the database only via the `switch`
  sub-command. `status` and `history` are read-only.
- **Eager drift**: every status query runs drift detection inline (FR-008).
  Stale-but-recorded "complete" stages will surface a drift annotation if
  the on-disk artifact is missing.

## When to suggest this

- The user asks "where am I in the pipeline" or "what should I run next".
- After a session crash or interruption mid-stage.
- When juggling multiple features and needing to switch between them.
- When investigating why a stage is stuck.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-builder` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
