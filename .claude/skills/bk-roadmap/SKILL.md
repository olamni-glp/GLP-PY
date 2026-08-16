---
name: "bk-roadmap"
description: "Durable, per-repo roadmap at the front of the buildkit pipeline. Capture epics & richly-profiled candidate features, refine & prioritise them with WSJF+RICE in an AI-guided review, detect inter-feature dependencies, and hand off one prepared feature at a time to /buildkit-specify. Advisory only — it records the engineer's decision and never auto-invokes a pipeline command (FR-014)."
argument-hint: "[init | add-epic | add-feature | edit-feature | review [propose-scores|set-score|rank|override|signoff|deps] | add-dependency | confirm-dependency | promote | brief | next | link | status]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-roadmap.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-roadmap` is the **missing front of the pipeline** — the roadmap-shaped
sibling of `/bk-builder`. The buildkit pipeline is per-feature and begins
at `/bk-specify`; the roadmap is **per-repo** and sits *upstream* of it.
It is where epics and candidate features are captured with rich profiles,
refined and prioritised with engineers, checked for inter-feature dependencies,
and handed off — one prepared, ready-to-build feature at a time.

It is **advisory**: it never builds anything and **never auto-invokes**
`/bk-specify` or any other `/buildkit-*` command (FR-014). It informs the
engineer's decision and records it durably. All roadmap data lives in the
existing per-repo PGlite catalog (additive `roadmap_*` tables — FR-004); the
roadmap is **not** a pipeline stage, so this skill uses **no** sidecar stage
gate and **no** refine resolve/record hooks (exactly like `/bk-builder`).

Sub-commands (all reachable as `python -m buildkit_cli.roadmap <subcommand>`):

- `init` — ensure the roadmap schema; report readiness. **Idempotent** — never
  wipes captured work (FR-001).
- `add-epic --name <n> [--description <d>]` — create an epic (FR-002).
- `add-feature --title <t> [--epic <id>] [--problem …] [--target-user …]
  [--value …] [--effort …] [--risk …] [--notes …] [--touched-area <a> …]` —
  capture a candidate feature with its profile (FR-002/FR-003).
- `edit-feature <id> --expect-version <n> [profile flags…]` — compare-and-set
  edit. A stale version surfaces a conflict (refresh and retry), never a silent
  overwrite (FR-018). Editing a `specified` feature warns (FR-015 edge case).
- `review [--seed-from-last]` — open an interactive review session (see below).
  Sub-ops: `propose-scores <id>`, `set-score <id> --wsjf-inputs <json>
  --rice-inputs <json>`, `rank`, `override <id> --review-id <r> --rank <n>
  [--rationale …]`, `signoff --review-id <r> --expect-version <n>`, `deps`.
- `add-dependency --prerequisite <id> --dependent <id>` — explicit hard
  dependency (FR-009).
- `confirm-dependency <dependency_id>` — promote a heuristic overlap edge to a
  hard ordering constraint (FR-009).
- `promote <id> [--confirm]` — internal `refined → promoted` transition.
  Profile gaps warn but `--confirm` is always honored; never auto-promotes,
  never hard-blocks (FR-012).
- `brief <id>` — render the `/bk-specify` brief for a feature (FR-013).
- `next` — recommend the single next feature to build (top-ranked promoted,
  dependency-satisfied, not-yet-specified) and print the exact
  `/bk-specify` command + brief. **Never runs it** (FR-014, SC-005/006).
- `link [--auto]` — scan `specs/` and link new spec dirs to promoted features by
  slug; on link the feature → `specified` (FR-015). Runs opportunistically at
  the top of every subcommand.
- `status` — advisory snapshot: epics → grouped features → state, WSJF/RICE,
  rank, and dependency flags (FR-016).
- `export [--out-dir <path>] [--stdout] [--quiet]` — write the full roadmap as a
  deterministic, secret-redacted, GitHub-trackable JSON snapshot to
  `.specify/roadmap-sync/exports/<hostname>__<repo>__<timestamp>.json` (spec-043
  FR-001…FR-005a). Re-exporting unchanged state is byte-identical (timestamp is
  filename-only). The journal is the system of record; HEAD is rebuildable.
- `import [--in-dir <path>] [--file <p> …] [--dry-run] [--rebuild-manifest]
  [--quiet]` — apply not-yet-imported export files, merging idempotently by
  `guid` (CRDT union). Slot (slug) collisions resolve first-claim-wins with the
  loser non-destructively re-sequenced; applied files are dual-tracked in PGlite
  + a gitignored JSON manifest (FR-007, FR-012…FR-019).
- `replay [--from-files <dir>] [--verify] [--quiet]` — rebuild HEAD
  deterministically from the journal (disaster recovery / new-host bootstrap).
  `--from-files` imports first; `--verify` asserts HEAD matches the projection
  without mutating it (FR-008, FR-009). Order-independent.

These three are **advisory & additive** like the rest of the roadmap CLI — none
auto-invokes a `/bk-*` command, and the CRDT schema evolution is a strictly
additive, idempotent migration (no roadmap row is ever deleted).

## Outline

1. Run `python -m buildkit_cli.roadmap $ARGUMENTS` from the project root (or
   `buildkit-roadmap $ARGUMENTS` if the console script is on PATH). Canonical
   exit codes:
     - exit `0`: success / no-op (idempotent re-init, empty status, dry actions).
     - exit `1`: refused — usage/precondition error, unknown epic/feature/
       dependency, unmet promotion gate without `--confirm`, or an
       optimistic-concurrency conflict.
     - exit `2`: PGlite/pgdb-runner unavailable (lock held by another session,
       or Node 20+ missing).
2. Print the CLI output **verbatim** for `status` / `next` / `brief` — the
   user-facing format is the contract surface (contracts/roadmap-cli.md). Do not
   edit, summarize, or reformat.
3. If the exit code is non-zero, surface the error message to the user without
   wrapping it in extra prose.

## Story-size confirm-or-update (spec-020 FR-006/FR-007 — advisory, non-blocking)

When you capture or refine a roadmap feature, optionally surface and record its story-point
size. Advisory; never blocks the roadmap flow (SC-003):

1. `buildkit-size prompt roadmap --feature <roadmap-feature-id> --type roadmap_item --json`
   (read-only; always exits 0; degrades to the built-in default buckets if the catalog is down).
2. Ask the engineer via AskUserQuestion — Confirm unchanged / Update / Decline — presenting the
   current size + active scheme buckets from the payload.
3. Record the response (advisory — ignore any failure):
   - Confirm → `buildkit-size confirm roadmap_item <roadmap-feature-id> --stage roadmap`
   - Update  → `buildkit-size set roadmap_item <roadmap-feature-id> --label <bucket> --stage roadmap`
   - Decline → `buildkit-size decline roadmap_item <roadmap-feature-id> --stage roadmap`

If `buildkit-size` is not installed or the catalog is unavailable, skip silently — sizing is advisory.

## Per-stage token record (spec-020 FR-010 — advisory, non-blocking)

On the success path, optionally record this stage's token usage (every stage records; the
roadmap runs before a per-feature pipeline exists, so omit `--feature`):
- `buildkit-size tokens record roadmap --total <N> --method self-reported --model <model>`
  (omit all counts to record an `unavailable` 0). Advisory — ignore failures; never block.

## The AI-guided `review` flow

`review` is the one interactive, AI-guided surface — in the spirit of
`/bk-clarify`: **the skill converses, the CLI persists.** A good session:

1. `review` (optionally `--seed-from-last`) to open a session; note the
   `review_id` it prints.
2. For each candidate, run `review propose-scores <id>` to get AI-proposed
   WSJF + RICE inputs from the profile. Discuss and refine them **with the
   engineer** — the proposal is a starting point, not a decision. Fill profile
   gaps first (`edit-feature`) when inputs are unanswerable.
3. Record the engineer-confirmed inputs with `review set-score <id>
   --wsjf-inputs <json> --rice-inputs <json>`. A feature missing a required
   input scores `NULL` and is held out of the confident ranking — never scored
   zero (FR-005).
4. `review rank` to show the deterministic score-proposed order (tie-break:
   WSJF↓ → RICE↓ → job_size↑ → created_at↑ → feature_id↑ — FR-019). Present it
   with the inputs that produced each score.
5. The engineer reorders as they see fit: `review override <id> --review-id <r>
   --rank <n> --rationale <why>`. Overrides are recorded with attribution +
   timestamp + rationale (FR-007/FR-008).
6. `review deps` to detect dependencies and show the **build order** next to the
   **priority order** so any conflict is visible; confirm heuristic overlaps
   with `confirm-dependency`.
7. `review signoff --review-id <r> --expect-version <n>` to persist the refined
   profiles + ranking and mark features `refined`. The next session seeds from
   it.

## Key invariants

- **Advisory only**: this skill never runs `/buildkit-*` commands. `next` and
  `brief` print the exact `/bk-specify` command for the engineer to run.
- **Engineer is the deciding layer**: WSJF + RICE are advisory inputs; scores
  are AI-proposed and engineer-confirmed (FR-006/FR-007). Nothing is
  auto-ranked or auto-promoted.
- **Durable + attributed**: every refinement, override, promotion, dependency,
  and spec-link is a durable, git-attributed, timestamped row — prior decisions
  are never lost (FR-008).
- **Concurrency-safe**: feature/review writes use optimistic `row_version`
  compare-and-set; a concurrent edit surfaces a conflict, never a silent
  overwrite (FR-018, SC-007).
- **Resumability sacred**: the roadmap only adds `roadmap_*` tables; it never
  touches pipeline/DBOS state.

## When to suggest this

- Before any `/bk-specify`, to decide *what* to build next from a
  prioritised, dependency-aware backlog.
- When the user asks "what should we build next", "what's on the roadmap", or
  wants to capture/triage candidate features and epics.
- When juggling many candidate features and needing a deterministic,
  reviewable prioritisation with dependency-aware build order.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-roadmap` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
