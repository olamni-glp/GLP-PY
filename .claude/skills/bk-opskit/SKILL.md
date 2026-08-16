---
name: "bk-opskit"
description: "BK-OpsKit: buildkit-native operator-session + AWS VPC operations toolkit (spec-054 merge). Named operator contexts (init/list/show/switch — credential POINTERS only, never material), read-only AWS discovery over the 54-leaf resource registry (describe/get/list/sts only; posture + refusal gates exit 2 and never auto-remediate), a Codex-CLI code-review loop with persistence + BreenLake trends, the baseline AWS tagging schema (load/certify/validate — pure, no-event validate hot path), PGLite cluster-upgrade tooling, and the advisory info/doc/where surfaces over the authoritative bk-opskit-integration.md. State is additive in buildkit's PGlite catalog; every output path is secret-redacted. Advisory — never switches branches, blocks a merge, or auto-invokes a buildkit-* command (FR-027)."
argument-hint: "[init <name> --vpc-id --region --account-id | list | show <name> | switch <name> | discover [--tier 1-4|--complete] [--confirm] | codexreview | tagging load|certify|validate | pglite-upgrade <verb> | info | doc [--sections] | where] [--json]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-opskit.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-opskit` is **BK-OpsKit** — the buildkit-native home for the OpsKit operator-session +
AWS-VPC-operations toolkit, fully merged and hardened by spec-054 (R4 component architecture:
`cli/`, `kernel/`, `registry/`, `components/{discover,tagging,codexreview,init,…}`).

It carries five capability families, each also reachable as its own sub-skill
(`/bk-opskit-init`, `/bk-opskit-discover`, `/bk-opskit-codexreview`, `/bk-opskit-tagging`,
`/bk-opskit-envset`):

- **Operator contexts** — named operator/VPC/region/account bindings that drive
  connect/assess/discover. Credential *pointers* at most; credential material is never stored,
  echoed, or persisted.
- **Discovery** — read-only AWS resource discovery across the 54 registry-dispatched resource
  leaves (per-VPC and per-account), tiered 1–4, with posture gates that refuse (exit 2) rather
  than remediate.
- **Codexreview** — local Codex CLI code review with cached verdicts, secret-scan refusal on
  the diff, and BreenLake trend emission.
- **Tagging** — the baseline AWS asset tagging schema: `load` a certified schema, `certify` a
  baseline, `validate` assets against it (pure, side-effect-free hot path; DB-backed rule kinds
  degrade to an explicit `org_enum_unavailable` finding when the baseline is absent).
- **PGLite upgrade** — the gated cluster-upgrade flow (clusters / quiesce-check / snapshot /
  backup / dry-run / revendor / restore / verify / rollback).

The advisory `info` / `doc` / `where` surfaces still resolve the authoritative
`bk-opskit-integration.md` (the component→target map and merge contract).

## How to run it

```
buildkit-opskit init <name> --vpc-id <vpc-…> --region <r> --account-id <12-digit>
buildkit-opskit list
buildkit-opskit show <name>
buildkit-opskit switch <name>
buildkit-opskit discover --tier 1 --confirm
buildkit-opskit codexreview
buildkit-opskit tagging validate
buildkit-opskit pglite-upgrade clusters
buildkit-opskit info
buildkit-opskit doc --sections
buildkit-opskit where
```

Line by line: create an OpsContext · list configured contexts · one context's bindings +
posture · switch the active context · read-only discovery (tiers 1-4, or `--complete`) ·
Codex review of the working diff · validate assets against the certified baseline ·
cluster-upgrade tooling · what BK-OpsKit is · the integration document's path (+ section
index) · package path + registered surfaces.

Most subcommands accept `--json`; `info`/`doc` accept `--project-root <path>`. From a coding
agent, `/bk-opskit` reaches the same surface.

## Exit codes (ratified S4 contract)

- `0` — success.
- `1` — usage error / malformed input (bad flags, malformed schema name, unparseable edits).
- `2` — refusal or environment error (posture gate, loose permissions, missing doc/context,
  AWS posture override malformed inputs excepted per the S4 re-map).

## Boundaries (do NOT) — FR-027, Constitution I & VII

- Advisory only: it auto-invokes **no** `/bk-*` or `buildkit-*` pipeline command.
- It switches **no** branch, edits/stages/commits **no** repo file outside its declared
  outputs, and blocks **no** merge.
- AWS interaction is **read-only** (describe/get/list/sts); posture/refusal gates refuse with
  exit 2 and never auto-remediate.
- It writes **no** secret to a durable sink: every output path is secret-redacted first
  (FR-024); credential material is never persisted (credential pointers only).

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-opskit` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
