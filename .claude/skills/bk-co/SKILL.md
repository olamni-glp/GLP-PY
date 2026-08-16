---
name: "bk-co"
description: "Native continuous-observability framework. One fail-safe, non-blocking capture() with declared deterministic routing records every buildkit capability's observations into a split store — a compact filterable profile in the additive PGlite co_* catalog (system of record) plus long-text detail + analytics in a lazy DuckLake (DuckDB-over-parquet) lake. Mine it two-phase (a cheap compact filter, then opt-in detail), derive case status by replay over re-hosted CO semantics (per-run sessions, entry+action event-sourcing, a critical human-in-the-loop close gate), optionally tail live ZeroMQ streams or expose an MCP-like shell, and ingest every shipped tool's catalog state via passive read-only adapters. Advisory & passive: never mutates observed state, never auto-invokes a /buildkit-* command, and is NOT a canonical pipeline stage (it instruments stages passively via the sidecar). Secrets are redacted before any persist or send; persistence is additive-only."
argument-hint: "[a situation, e.g. 'what failed in the last plan?'] | capture | query | detail | case status | route [list|add|check] | session [show|archive] | import-co | stream tail | mcp serve | relocate | backend | init | replay"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-co.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). It is either a
natural-language situation ("what failed in the last plan?", "stream live pipeline events")
or a `buildkit-co` subcommand. If empty, summarise the surface below and ask what they want to do.

## What this does

`/bk-co` instruments and mines buildkit's own activity. It is **advisory & passive**: it
**observes** and records its own observations; it **never** mutates observed state, switches
branches, edits source, pushes, mutates pipeline/DBOS state, or auto-invokes
specify/clarify/plan/tasks/analyze/implement or any ship/roadmap command (FR-032). It is **NOT a
canonical pipeline stage** — do **not** call the sidecar `start`/`complete` for it.

This skill **conducts**; the deterministic `buildkit-co` CLI does the capture / route / persist /
query / configure work. Every subcommand supports `--json` and `--project-root`/`--actor`.

## The surface

- **`init`** — bootstrap the co_* tables, seed the default route taxonomy, and create the lake dir.
- **`capture --capability <c> --sub-capability <s> --kind event|entry|action [--compact-json … --detail-json … --severity … --action … --correlation-id …]`** — emit one observation. Fail-safe: it always exits 0 with a declared outcome (`recorded`/`unclassified`/`rejected`/`spilled`); a backend outage spills to disk and replays idempotently (`replay`). Secrets are redacted before any persist/send.
- **`query [--capability --severity --since --until --channel --stream …]`** — phase-1 compact filter (no detail read); a single-capability filter returns only that segment (zero cross-capability bleed).
- **`detail --id <obs_id> [--id …]`** — phase-2: fetch long-text detail only for the selected ids (the explicit opt-in to the firehose).
- **`case status --entry-id <obs_id>`** — replay-derived status of an entry+action case (the entry row is never mutated).
- **`route list | route add … | route check --capability <c> [--sub-capability <s>]`** — inspect/extend the declared `(capability, sub_capability) → (channel, stream)` table; new capabilities extend it by adding rows, not code.
- **`session show | session archive`** (`--session-id`/`--run-id`) — per-run session lifecycle; archival preserves history.
- **`import-co --path <file.co> [--source-label <l>]`** — optionally import legacy hatzinor `.co` JSONL history onto the unified model, idempotent by source key.
- **`stream tail --channel <c> [--stream <s>]`** — subscribe live (optional/lazy ZeroMQ); a slow/absent subscriber is dropped, never blocking capture, and the durable record stays complete.
- **`mcp serve`** — start the optional MCP-like shell over the schema-versioned framework boundary (lazy; absent runtime → refuses cleanly, the core path still works).
- **`relocate --to <dir>`** — relocate the lake (validate → copy → verify → switch); a missing/unwritable target is refused cleanly and the prior location keeps serving.
- **`backend --to pglite|postgres [--dsn …]`** — switch the catalog backing as a config-only change; the capture/query contract is unchanged.

## Reusable framework (for other tools)

Other tools (e.g. buildkit-guardian, buildkit-deploy) consume `buildkit_cli.co.framework` directly —
a storage-opaque, `SCHEMA_VERSION`-versioned surface (`emit` / `filter` / `fetch_detail` /
`subscribe` / `case_status` / sessions / cases) with compact-default progressive disclosure. They
never need to know the lake/catalog internals, and the PGlite↔Postgres switch and lake relocation
are invisible to them.

## Advisory boundaries (non-negotiable)

- Passive observer: never mutate observed state, never auto-invoke another `/buildkit-*` command,
  never call the sidecar (not a canonical stage).
- Capture is fail-safe and non-blocking — it never raises into or blocks the observed operation.
- Secrets are redacted before any persistence or external send.
- Persistence is additive-only (the co_* tables); DBOS/pipeline-state is never touched.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-co` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
