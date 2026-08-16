---
name: "bk-backlog"
description: "Durable, per-repo backlog at the front of the front — upstream of /buildkit-roadmap. Capture half-formed feature ideas and issues the moment they appear, link issues to features and legitimate them through a tracked gate, split/combine/recombine issues with preserved lineage, and allocate items to an epic + season to graduate a copy onto the roadmap. Advisory only — it records the engineer's decision and never auto-invokes a pipeline command (FR-012)."
argument-hint: "[init | add-season | capture | edit | link | legitimate | split | combine | recombine | allocate | status | history]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-backlog.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-backlog` is the **front of the front** — the intake surface *upstream
of* `/bk-roadmap`. The pipeline is per-feature and begins at
`/bk-specify`; the roadmap is per-repo and sits upstream of that; the
backlog sits upstream of even the roadmap. It is where half-formed **feature
ideas** and **issues** (tensions/defects) are captured the moment they appear and
kept safely until they are ready to graduate onto the roadmap.

It is **advisory**: it never builds anything and **never auto-invokes**
`/bk-roadmap`, `/bk-specify`, or any other `/buildkit-*` command
(FR-012, SC-007). `allocate` graduates an item onto the roadmap by calling the
`roadmap.store` **library** directly — never by shelling out to a skill. All
backlog data lives in the existing per-repo PGlite catalog (additive `backlog_*`
tables — FR-004); the backlog is **not** a pipeline stage, so this skill uses
**no** sidecar stage gate and **no** refine resolve/record hooks (exactly like
`/bk-roadmap` and `/bk-builder`).

Sub-commands (all reachable as `python -m buildkit_cli.backlog <subcommand>`):

- `init` — ensure the backlog schema; report readiness. **Idempotent** — never
  wipes captured items/links/lineage/allocations/history (FR-001).
- `add-season --name <n> [--id <slug>] [--starts <YYYY-MM-DD>] [--ends <YYYY-MM-DD>]
  [--description <d>]` — create a reusable, time-boxed planning window (FR-006).
- `capture --kind <feature|issue> --title <t> [--id <slug>] [--summary <s>]
  [--detail <d>]` — capture one item; only `kind` + `title` are required. Issues
  start `un-legitimated`; missing fields stay null, never fabricated (FR-002/FR-003).
- `edit <id> --expect-version <n> [--title …] [--summary …] [--detail …]` —
  compare-and-set edit. A stale version surfaces a conflict (refresh and retry),
  never a silent overwrite (FR-015). Editing an `allocated` item warns that a
  graduated roadmap copy exists (FR-016).
- `link <issue_id> --to <feature_ref> --target-kind <backlog|roadmap>` — record a
  **directional** issue→feature link (FR-007). Idempotent; a feature never links
  back.
- `legitimate <issue_id>` — the one **gated** transition (FR-008): succeeds iff
  the issue links to an at-least-committed feature (a roadmap feature, or an
  `allocated` backlog feature). Otherwise refused with a clear reason; the issue
  stays a valid, listed backlog item (SC-004).
- `split <id> --into <id1> [--into <id2> …] [--title …]` — split one item into N
  children; each records lineage to the retained parent and inherits its links.
- `combine --from <id1> --from <id2> [--from …] --into <new-id> --title <t>
  [--kind …]` — combine N items into one child carrying the **union** of links;
  sources retained.
- `recombine --from <id1> [--from …] --into <c1> [--into <c2> …] [--title …]` —
  general M→N reshaping (all-to-all lineage, union of links onto each result).
- `allocate <id> --epic <epic_id> --season <season_id>` — allocate to an epic +
  season and **graduate** a copy onto the roadmap (FR-005). A feature idea
  graduates as a candidate feature; an issue as its own work-item. **Idempotent**
  (FR-017, SC-003): re-allocation surfaces the existing entry, no duplicate. The
  backlog item is **retained**.
- `status` — advisory snapshot: items grouped by kind & state, epic/season for
  allocated items, issue→feature links, legitimation status (FR-014).
- `history [--item <id>]` — the append-only action history with actor +
  timestamp, in order, read through the stable history interface (FR-011).

## Outline

1. Run `python -m buildkit_cli.backlog $ARGUMENTS` from the project root (or
   `buildkit-backlog $ARGUMENTS` if the console script is on PATH). Canonical
   exit codes:
     - exit `0`: success / no-op (idempotent re-init, empty status, already-linked,
       already-allocated).
     - exit `1`: refused — usage/precondition error, unknown item/epic/season/
       target, legitimation without a qualifying link, self-/duplicate lineage
       edge, or an optimistic-concurrency conflict.
     - exit `2`: PGlite/pgdb-runner unavailable (lock held by another session, or
       Node 20+ missing), or a configured history backend unreachable.
2. Print the CLI output **verbatim** for `status` / `history` — the user-facing
   format is the contract surface (contracts/backlog-cli.md). Do not edit,
   summarize, or reformat.
3. If the exit code is non-zero, surface the error message to the user without
   wrapping it in extra prose.

## Story-size confirm-or-update (spec-020 FR-006/FR-007 — advisory, non-blocking)

When you capture or reshape a backlog item, optionally surface and record its story-point size.
Advisory; never blocks the backlog flow (SC-003):

1. `buildkit-size prompt backlog --feature <item-id> --type backlog_item --json`
   (read-only; always exits 0; degrades to the built-in default buckets if the catalog is down).
2. Ask the engineer via AskUserQuestion — Confirm unchanged / Update / Decline — presenting the
   current size + active scheme buckets from the payload.
3. Record the response (advisory — ignore any failure):
   - Confirm → `buildkit-size confirm backlog_item <item-id> --stage backlog`
   - Update  → `buildkit-size set backlog_item <item-id> --label <bucket> --stage backlog`
   - Decline → `buildkit-size decline backlog_item <item-id> --stage backlog`

If `buildkit-size` is not installed or the catalog is unavailable, skip silently — sizing is advisory.

## Per-stage token record (spec-020 FR-010 — advisory, non-blocking)

On the success path, optionally record this stage's token usage (every stage records; backlog
runs before a feature exists, so omit `--feature`):
- `buildkit-size tokens record backlog --total <N> --method self-reported --model <model>`
  (omit all counts to record an `unavailable` 0). Advisory — ignore failures; never block.

## Scope boundary (what the backlog does NOT do)

The backlog **captures → links/legitimates → splits/combines → allocates/
graduates**. It never **scores, prioritises, or specifies** — those belong to
`/bk-roadmap` (WSJF/RICE refinement, build order) and `/bk-specify`
(the per-feature pipeline) respectively (FR-019). Once an item is allocated, the
roadmap's refine → prioritise → promote → specify lifecycle takes over.

## Key invariants

- **Advisory only**: this skill never runs `/buildkit-*` commands. `allocate`
  graduates via the `roadmap.store` library; nothing is auto-specified or
  auto-built (FR-012, SC-007).
- **Capture-anything, lose-nothing**: partial items are valid; sources of a
  split/combine/recombine are always retained; every state-changing action is a
  durable, git-attributed, timestamped row (FR-003/FR-009/FR-011).
- **Legitimation is the one gate**: everywhere else the backlog warns, never
  hard-blocks. Un-legitimated issues remain valid backlog items (FR-008).
- **Concurrency-safe**: `backlog_item` writes use optimistic `row_version`
  compare-and-set; a concurrent edit surfaces a conflict, never a silent
  overwrite (FR-015, SC-008).
- **Resumability sacred**: the backlog only adds `backlog_*` tables and two
  additive nullable `roadmap_feature` columns; it never touches pipeline/DBOS
  state.
- **History behind a stable seam**: all history flows through `backlog/history.py`
  so the DuckLake / server-PostgreSQL backend is a drop-in fast-follow with
  identical recorded semantics (FR-011).

## When to suggest this

- The moment a half-formed feature idea or an issue (tension/defect) appears and
  should be captured before it is lost — even with only a title.
- When triaging issues: linking them to the features they affect and legitimating
  the ones grounded in committed work.
- When an idea or issue is ready to become scheduled roadmap work — `allocate` it
  to an epic + season to graduate it onto `/bk-roadmap`.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-backlog` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
