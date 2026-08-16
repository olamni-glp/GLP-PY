---
name: "bk-opskit-envset"
description: "BK-OpsKit envset: capture the OPSKIT_* environment profile — which of the known configuration variables (home, shell, PGlite URL/data/backup dirs, snapshot/breenlake/tag-guard toggles, per-VPC/per-account bindings, CTO overrides) are set, with values secret-redacted before any echo, plus honest flagging of unknown OPSKIT_* names. The one sub-skill carrying its own module (FR-045). Read-only: it never mutates the environment. Advisory — never switches branches, blocks a merge, or auto-invokes a buildkit-* command (FR-027)."
argument-hint: "[--json | --export]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-opskit-envset.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-opskit-envset` is the environment-profile surface of BK-OpsKit (round-trips to
`buildkit-opskit envset`, which carries its own module — the one non-wrapper sub-skill,
FR-045). It captures the OPSKIT_* profile of the calling environment: every variable in
the known vocabulary is reported set/unset, any other `OPSKIT_*` name found is flagged as
outside the vocabulary, and **every echoed value passes the kernel secret-redactor
first** — a value that trips it is emitted in redacted form with a stderr warning.

## How to run it

```
buildkit-opskit envset
buildkit-opskit envset --json
buildkit-opskit envset --export
```

The default output is one aligned row per known variable. `--json` emits a single
machine-readable object (`known` / `unknown`). `--export` emits re-sourceable
`export NAME="value"` lines for the variables that are set.

## Exit codes (ratified S4 contract)

- `0` — success (the capture itself cannot refuse).
- `1` — usage error (unknown flag).

## Boundaries (do NOT) — FR-027

- Read-only: it never sets, unsets, or rewrites an environment variable.
- Advisory only: auto-invokes **no** buildkit-* pipeline command; switches **no** git branch.
- Secret material never reaches stdout — values are redacted before echo (FR-024).

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-opskit` from the project root — it
always exits 0 (fail-safe; never blocks). Ignore its output.
