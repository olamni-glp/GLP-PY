---
name: "bk-scheduler"
description: "CRDT-native, multi-node CPM/PERT work scheduler as a first-class buildkit tool. Derives an honest, calendar-projected critical-path/PERT plan (P50/P80/P95), a capability-fit dispatch ranking that never strands work, and a 9-column board fold from a file-based CRDT substrate — grow-only per-actor JSONL op-logs under a resolvable sched_root, merged on read (union-by-id, byte-divergence quarantined), R2-totally-ordered, single-writer-leased (R10 heartbeat). Actors self-report availability + capabilities + claims (opt-in; a caps report never injects availability). CRDT-versioned dependency edges carry lineage and are deterministically cycle-safe; PERT node variance is measured from actuals (uncalibrated nodes flagged); view freshness is correct-by-construction (equal-frontier content self-heal). The engine is stdlib-only and root-parametric so one installed tool schedules any number of boards. Advisory & passive: it never auto-invokes a /buildkit-* command and is NOT a canonical pipeline stage; it mirrors every cycle into continuous observability (co) and records one additive scheduler_cycle metadata row so other buildkit tools can observe scheduler activity. Secrets are redacted before any persist/send; catalog persistence is additive-only and never touches DBOS/pipeline-state — the file-CRDT substrate is the system of record."
argument-hint: "[a natural-language request, or a subcommand: cycle|loop|onboard|plan|board|report|status|doctor|root|version] [--actor A] [--root R] [--json]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-scheduler.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). It is either a
natural-language request ("run a scheduling cycle", "what's the critical path?", "onboard me",
"is the board healthy?") or a `buildkit-scheduler` subcommand. If empty, summarise the surface
below and ask what they want.

## What this does

`/bk-scheduler` derives an honest CPM/PERT schedule + capability-fit dispatch ranking for a
multi-node work board held as a **file-based CRDT**. It is **advisory & passive**: it derives
views and ranks ready work, but **never** invokes a `/buildkit-*` command, is **not** a canonical
pipeline stage, and makes **no** `feature_pipeline`/DBOS mutation. The only state it writes is (a)
the calling actor's own grow-only JSONL streams under `sched_root` (single-writer) and (b)
disposable derived view artifacts; the machine-catalog `scheduler_cycle` row + the co mirror are
additive interoperability metadata only.

The **substrate** is grow-only, append-only, per-actor segmented JSONL under a resolvable
`sched_root` (`ops/ caps/ calendar/ signals/ …`), merged on read by union-by-id with byte-divergent
duplicates quarantined (never silently picked), R2-totally-ordered `(timestamp, actor, seq)`. Board
state is **derived, never stored** (a 9-column exactly-one-state fold). A per-actor R10 heartbeat
lease (30s beat / 120s lease) enforces single-writer: a fresh foreign heartbeat forces read-only
degradation rather than a second writer. No wall-clock stamp is ever written into a view body.

The **engine** is stdlib-only and root-parametric — every function takes the `sched_root` it
operates on — so one installed tool schedules any number of boards on the machine.

## Surface

**Mutating (single-writer — write the calling actor's own streams)**
- `cycle --actor A [--host H] [--root R]` — run one scheduling cycle (merge-on-read → rebuild
  plan/allocation/board views → ready-undispatched detection → staleness scan → gap cards → R9
  hourly report → co mirror → epoch signal). Idempotent per report-hour. Prints the critical path,
  P50/P80/P95 finish, unbounded set, and cycle edges. Degrades (read-only, exit 0) under a fresh
  foreign heartbeat.
- `loop --actor A [--hours N] [--cycle-seconds S] [--beat-seconds B] [--stop-file F]` — the daemon:
  one cycle per interval over a bounded horizon, beating the heartbeat between cycles, stopping
  cleanly when the stop-file appears. Blocks for the horizon.
- `onboard --actor A [--role R] [--cap C ...] [--tool T ...] [--skill S ...]
  [--avail-hours N | --window ISO_START/ISO_END ...] [--claim WP ...]` — self-report capabilities,
  availability (opt-in only — a caps-only report never injects availability), and ready-WP claims.

**Read-only (derive, never write)**
- `plan [--root R]` — the CPM/PERT plan view: critical path, P50/P80/P95, unbounded, cycle edges,
  default-calendar assignees.
- `board [--root R]` — the 9-column board fold with per-state WP counts.
- `report [--root R]` — the R9 hour-keyed report envelope (`--json` for the full body).
- `status [--root R]` — quick health: root existence, actors, critical-path length, unbounded
  count, fallback-used flag, co availability.
- `doctor [--root R]` — diagnostics: root resolution, actors, stale actors (heartbeat lease),
  fallback-used, co + catalog availability.
- `root [--root R]` — print the resolved `sched_root` (R1 indirection).

**Version**
- `version` — the installed buildkit/scheduler version (no DB).

Every subcommand accepts `--root R` (else R1-resolved), `--feature F` (else resolved from
`.specify/feature.json`), `--home H`, and `--json` (emits a `{"schema_version":"1", …}` envelope).
Exit codes: 0 success/no-op · 1 refused (single-writer refusal / usage) · 2 machine-catalog
unavailable (only the optional metadata write) · 3 version skew. Mutating commands need an actor
identity (`--actor`, else `SCHEDULER_ACTOR`) and may write only that actor's streams.

## Boundaries

Advisory & passive. It **never** auto-invokes a `/buildkit-*` command, is **not** a pipeline stage,
makes no `feature_pipeline`/DBOS mutation, and never force-commits or bypasses git hooks. Its system
of record is the on-disk file-CRDT substrate; the catalog + co are additive observability sinks that
degrade to a no-op when absent. All persisted/emitted free text is secret-redacted first. Committing
and pushing the per-actor `caps/calendar/ops` files after `onboard`/`cycle` is the engineer's step.

Run `python -m buildkit_cli.registry touch --tool buildkit-scheduler` from the project root after
this command (fail-safe registry dirty-bit; always exits 0, never blocks).
