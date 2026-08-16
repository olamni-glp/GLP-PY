---
name: "bk-plan-order"
description: "Advisory, catalog-backed cross-feature dependency + ordering analyzer. Given a set of feature ids (e.g. 009 010 011a) it classifies their branches parallel-vs-stacked via git ancestry against the integration branch, detects files edited by more than one feature's tasks.md (merge-coordination vs hard-ordering), counts MVP/full tasks per feature, and recommends an implementation ordering + branch strategy — emitted as structured JSON for /bk-implement and persisted as append-only run history in the buildkit PGlite catalog. Advisory: read-only w.r.t. git refs + files, never switches branches, edits files, or auto-invokes a pipeline command (FR-011)."
argument-hint: "run <feature_id>... [--integration-branch <branch>] [--json] | history | init"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-plan-order.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-plan-order` answers, before a multi-feature implementation run, *"how do I
safely implement these features together?"*. It is the mechanized form of the manual
reasoning that unblocks parallel feature work: are the branches parallel or stacked,
where do they collide, and in what order should they land.

It is **advisory** and **read-only**: it never switches branches, edits files, opens the
pipeline catalog, or invokes `/bk-implement` or any other `/buildkit-*` command
(FR-011/FR-015). It records a recommendation; the engineer decides. It is **not** a
pipeline stage — there are no sidecar/refine hooks (like `/bk-roadmap` and
`/bk-backlog`).

## How to run it

```
buildkit-plan-order run 009 010 011a          # analyze + persist + render
buildkit-plan-order history                   # list recent persisted runs
buildkit-plan-order init                       # ensure schema; report run count
```

`run` options:

- `--integration-branch <branch>` — branch the features are compared against (default `develop`).
- `--actor <id>` — override the recorded actor (default: git `user.email`).
- `--json` — emit the structured `PlanOrderReport` (schema_version "1", incl. `run_id`).

Each `run` is **persisted as append-only history in the buildkit PGlite catalog** (same pattern as
`/bk-roadmap` and `/bk-backlog`); if the catalog is unreachable, `run` exits 2.

## What it reports

1. **Parallel vs stacked** — for each feature pair, computed from git ancestry against the
   integration branch, plus each feature's common base commit.
2. **Shared-file dependencies** — files appearing in more than one feature's `tasks.md`,
   each classified as a *merge-coordination point* (additive parallel edits) or a *hard
   ordering constraint* (heuristic — labeled as such; you decide).
3. **Task counts** — per feature, MVP (P1) vs full scope.
4. **Recommendation** — an implementation ordering and a branch strategy
   (`independent_prs` vs `stacked_integration`) with trade-offs.

## Feeding the plan into an implement run

```
buildkit-plan-order run 009 010 011a --json > plan-order.json
```

The JSON is consumable by `/bk-implement` for a multi-feature run: use
`recommendation.ordering` for sequence and `shared_files` flagged `ordering` as hard gates.
This command **prints** the recommended next step — it never runs `/bk-implement` for you.

## Exit codes

- `0` — success (including the partial case where some ids were unresolved, reported in-band).
- `1` — usage error (no subcommand, or `run` with no feature ids).
- `2` — environment error (integration branch unresolvable, `git` unavailable, or the buildkit PGlite catalog unreachable).

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-plan-order` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
