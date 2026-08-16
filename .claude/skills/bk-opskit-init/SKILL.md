---
name: "bk-opskit-init"
description: "BK-OpsKit operator contexts: bootstrap a named OpsContext (operator/VPC/region/account binding — credential POINTERS only, never material) and manage the set (list / show / switch). State is additive in buildkit's PGlite catalog; every output path is secret-redacted. Advisory — never switches branches, blocks a merge, or auto-invokes a buildkit-* command (FR-027)."
argument-hint: "<name> --vpc-id <vpc-…> --region <r> --account-id <12-digit> [--schema-name] [--org-detail-file <path>] [--overwrite] [--json] — or: list | show <name> | switch <name>"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-opskit-init.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-opskit-init` is the operator-context surface of BK-OpsKit (round-trips to
`buildkit-opskit init` and its siblings). An **OpsContext** is a named
operator/VPC/region/account binding that drives connect/assess/discover. It stores
credential *pointers* at most — credential material is never stored, echoed, or persisted.

## How to run it

```
buildkit-opskit init <name> --vpc-id <vpc-id> --region <region> --account-id <account-id>
buildkit-opskit init <name> --vpc-id <vpc-id> --region <region> --account-id <account-id> --schema-name <s> --overwrite
buildkit-opskit list
buildkit-opskit show <name>
buildkit-opskit switch <name>
```

`init` verifies the binding read-only (sts/ec2), snapshots the catalog first
(refuses without `pg_dump`), archives any overwritten row, and records the context in
buildkit's PGlite catalog. `--org-detail-file <path>` attaches engineer-supplied org
context; `--json` on every subcommand emits machine-readable output.

## Exit codes (ratified S4 contract)

- `0` — success.
- `1` — usage error / malformed input (e.g. an invalid schema name).
- `2` — refusal or environment error (posture gate, missing pg_dump, unknown context).

## Boundaries (do NOT) — FR-027

- Advisory only: auto-invokes **no** buildkit-* pipeline command; switches **no** git branch.
- AWS interaction is **read-only** (describe/get/list/sts); refusals exit 2, never remediate.
- Credential material is never persisted or echoed; outputs are secret-redacted (FR-024).

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-opskit` from the project root — it
always exits 0 (fail-safe; never blocks). Ignore its output.
