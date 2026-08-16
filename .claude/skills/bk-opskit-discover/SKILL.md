---
name: "bk-opskit-discover"
description: "BK-OpsKit discovery: tiered (1-4) read-only AWS resource discovery over the 54-leaf resource registry (per-VPC + per-account), dispatched against the active OpsContext. describe/get/list/sts only; posture + refusal gates exit 2 and never auto-remediate. Advisory — never switches branches, blocks a merge, or auto-invokes a buildkit-* command (FR-027)."
argument-hint: "[--tier 1|2|3|4 | --complete] [--confirm]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-opskit-discover.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-opskit-discover` is the discovery surface of BK-OpsKit (round-trips to
`buildkit-opskit discover`). It enumerates AWS resources across the 54
registry-dispatched resource leaves (per-VPC and per-account families), tiered 1-4,
persisting snapshots + posture findings. Discovery is strictly **read-only** —
every AWS call is describe/get/list/sts; the posture gates refuse (exit 2) rather
than remediate.

## How to run it

```
buildkit-opskit discover
buildkit-opskit discover --tier 1 --confirm
buildkit-opskit discover --complete --confirm
```

Without `--confirm` the run is a dry-run. `--tier <1-4>` picks the discovery tier and is
mutually exclusive with `--complete` (the backup-only flow against the most recent
successful run).

## Exit codes (ratified S4 contract)

- `0` — success (including a clean dry-run).
- `1` — usage error / malformed input.
- `2` — refusal (posture gate, missing/stale context, tier gate) or environment error.

## Boundaries (do NOT) — FR-027

- Advisory only: auto-invokes **no** buildkit-* pipeline command; switches **no** git branch.
- AWS interaction is **read-only**; refusal gates exit 2 and never auto-remediate.
- Writes only its declared outputs (`vpcs/` and catalog rows); outputs secret-redacted (FR-024).

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-opskit` from the project root — it
always exits 0 (fail-safe; never blocks). Ignore its output.
