---
name: "bk-onboard"
description: "Guided clone→first-green-spec onboarding. Runs ordered environment-readiness checks (Python, git + identity, Node, vendored PGlite runner, project init) and, for any missing prerequisite, prints an actionable fix rather than failing opaquely (spec-009 FR-009). When ready, prints the guided path to a first completed spec (<30-min self-serve target, SC-004)."
argument-hint: "(no arguments)"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-onboard.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-onboard` takes a new engineer from a fresh clone to their first
completed ("green") spec. It first runs ordered **environment-readiness
checks** and, for every missing prerequisite, prints a concrete, actionable
remediation (FR-009) — never an opaque failure. When the environment is ready
it prints the guided path through the pipeline.

Checks (in order): Python 3.11+, `git`, configured git identity (used for
advisory claim authorship), Node 20+ (the PGlite catalog runs in a Node child
process), the vendored `pgdb-runner/node_modules`, and project initialization
(`.specify/`).

## Outline

1. Run `buildkit onboard` from the project root (or
   `python -m buildkit_cli.onboard`). It prints the readiness table and the
   guided next steps. Exit code:
     - `0`: environment ready.
     - `1`: one or more prerequisites missing (each annotated with a fix).
2. Print the CLI output verbatim. If any check failed, help the user resolve
   the flagged item, then re-run.
3. Once green, follow the printed path: advisory-claim the spec with
   `buildkit lock <spec-id>`, then `/bk-specify` →
   `/bk-plan` → `/bk-tasks` → `/bk-implement`, and confirm
   with `buildkit-builder`.

## Key invariants

- **Actionable, never opaque**: every failing check names how to fix it (FR-009).
- **Advisory**: onboarding never seizes a claim or runs a `/buildkit-*` command
  for the user; it guides.
- **No new datastore**: the readiness checks are pure environment probes.

## When to suggest this

- A new engineer has just cloned the repo and asks "how do I get started".
- Someone hits an opaque environment error and needs a readiness checklist.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-onboard` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
