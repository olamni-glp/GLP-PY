---
name: "bk-size"
description: "Advisory story-point sizing & per-stage token tracking across the buildkit pipeline. Assign durable, history-tracked sizes to any work item (feature/user story/key configurable item/task/roadmap/backlog) using a configurable scheme (default nano/micro/mini/midi/maxi/saga), confirm-or-update the size at every stage, roll child estimates up against the parent (warn-only), record per-stage token usage for every stage, and report per-stage/per-feature cost. Advisory & additive only — it never blocks, gates, or auto-invokes a pipeline command (FR-014)."
argument-hint: "[init | set | show | history | confirm | decline | prompt | config-item [suggest|list|confirm|remove] | rollup | tokens [record|report] | scheme [list|show|define|set-active] | summary]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-size.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## What this does

`buildkit-size` is the advisory, additive, catalog-backed home of story-point sizing and
per-stage token tracking. It records a durable, attributed, append-only history for every size
change, supports a configurable sizing scheme (built-in default `nano=1, micro=3, mini=7,
midi=11, maxi=17, saga=35`), and keeps an append-only per-stage token ledger that spans **every**
stage — including implement, codexreview, and the mechanical commit/push/ship/release CLIs.

It is **advisory & additive**: it never blocks, gates, or auto-invokes a pipeline command
(FR-014, SC-007); rollup divergence is warn-only and never auto-corrected (FR-009); switching the
active scheme never rewrites stored points (FR-013); and the token ledger never writes
DBOS/workflow state.

## Subcommands

- `init` — ensure the sizing schema; report counts. **Idempotent**.
- `set <work_item_type> <work_item_id> (--label <bucket> | --points <int>) [--feature <id>] [--stage <s>] [--expect-version <n>]`
  — assign or update the current size (optimistic `row_version` CAS → exit 1 on conflict).
- `show <work_item_type> <work_item_id>` — current size + scheme relation (`in-scheme | custom`).
- `history <work_item_type> <work_item_id>` — full append-only history, oldest→newest.
- `confirm <work_item_type> <work_item_id> [--stage <s>]` — record `confirmed_unchanged` (FR-006).
- `decline <work_item_type> <work_item_id> [--stage <s>]` — record `declined` (FR-007); no size set.
- `prompt <stage> --feature <id> [--type <t>] [--id <id>] --json` — **read-only** confirm-or-update
  payload for a skill template (always exit 0; degrades to default buckets if the catalog is down).
- `config-item suggest|list|confirm|remove` — engineer-confirmed key configurable items (FR-018);
  only **confirmed** items may be sized.
- `rollup --feature <id>` — sum of child estimates vs the parent feature; flags divergence
  advisorily (FR-009).
- `tokens record <stage> [...] | tokens report [--feature <id>]` — per-stage token ledger + a
  reconciling cost report (FR-010/FR-011).
- `scheme list|show|define|set-active` — define/activate an alternative sizing scheme without
  losing existing point estimates (FR-012/FR-013).
- `summary --feature <id>` — a single advisory view composing size + history + rollup + tokens
  (FR-016/SC-004).

`<work_item_type>` ∈ `feature | user_story | config_item | task | roadmap_item | backlog_item`.

## Outline

1. Run `python -m buildkit_cli.sizing $ARGUMENTS` from the project root (or
   `buildkit-size $ARGUMENTS` if the console script is on PATH). Canonical exit codes:
     - exit `0`: success / no-op (idempotent init, empty view, recorded decline, advisory rollup).
     - exit `1`: refused — usage/precondition error, unknown entity, optimistic-concurrency
       conflict, or sizing an unconfirmed config item.
     - exit `2`: PGlite/pgdb-runner unavailable (lock held by another session, or Node 20+ missing).
2. Print the CLI output **verbatim** for `show` / `history` / `rollup` / `tokens report` /
   `scheme` / `summary` — the contract surface is `contracts/cli-commands.md` /
   `contracts/json-shapes.md`. Do not edit, summarize, or reformat.
3. If the exit code is non-zero, surface the error message to the user without wrapping it in
   extra prose.

## Key invariants

- **Advisory & additive** — never blocks, gates, or auto-invokes a pipeline command (FR-014).
- **Engineer is the deciding layer** — confirm/update/decline and config-item confirmation are
  always the engineer's call; the tool only records the decision.
- **No silent loss** — every size change is mirrored to append-only history; a scheme change
  preserves raw points (an out-of-bucket value is merely shown as `custom`).
- **Every stage records tokens** — a known/zero or `unavailable` count is still a row, never an
  omission; the per-feature total always reconciles to the sum of records.

## When to suggest this

Suggest `/bk-size` whenever an engineer wants to size a unit of work at any granularity,
confirm/update a size at a pipeline stage, understand child-vs-parent divergence, swap the
sizing scheme, or see per-stage/per-feature token cost — without it ever blocking the pipeline.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-size` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
