---
name: "bk-marathon"
description: "Durable, resumable run harness layered over the per-feature buildkit pipeline (specify→plan→tasks→implement→ship) for bigger features: a pre-organized in-flight backlog (park now / sequence later via fractional order keys), forward-looking fine-grained step intake + expansion-with-lineage at ANY stage, objective resume-from-state, invocation-time crash recovery + scoped-commit re-drive, append-only verification traces, approval gates, and a HARD discharge gate with a recorded informed-consent override (briefing + ack + rationale). Workflow state lives as additive marathon_* rows in the shared out-of-repo machine catalog under the deploy home (survives repo deletion/re-clone on the same machine), mirrored to a per-run Markdown file + the DuckLake lake so CO feeds CO. Single participant now; the participant-aware model is the multi-participant foundation. Advisory & passive: never auto-invokes a /buildkit-* command and is NOT a canonical pipeline stage; secrets are redacted before any persist/send; persistence is additive-only and never touches DBOS/pipeline-state."
argument-hint: "[a natural-language request, or a subcommand: open|resume|status|position|doctor|discharge|capture|expand|park|sequence|backlog|step-start|checkpoint|trace|gate|discharge-item|override|version]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-marathon.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). It is either a
natural-language request ("open a marathon for this feature", "what's next?", "park this idea",
"can I discharge?") or a `buildkit-marathon` subcommand. If empty, summarise the surface below
and ask what they want.

## What this does

`/bk-marathon` gives a bigger feature a **durable, resumable run** layered *over* the per-feature
pipeline. It is **advisory & passive**: it records and organizes the engineer's run and *reports*
the next pipeline step, but **never** runs `specify/clarify/plan/tasks/analyze/implement` or any
ship/roadmap command, and adds **no** sidecar/pipeline hook. State is additive-only and never
touches `feature_pipeline`/DBOS.

The run lives in the **shared machine catalog** under the deploy home (resolved DB-free), isolated
by `run_id`/`feature_id` rather than a per-run cluster, so it survives repo deletion and a fresh
checkout/clone **on the same machine** (cross-machine sync is out of scope). The catalog is the
system of record; a per-run Markdown mirror under the deploy-home target dir + the DuckLake lake
are the other two sinks.

## Surface

**Run lifecycle**
- `open` — create (or resolve the existing active) run for the feature; at most one active run per
  feature; stamps the creating version.
- `resume` — reconstruct full state objectively from persisted rows; re-drive a complete-but-
  uncommitted checkpoint; refuses (exit 3) if the installed version < the run's creating version.
- `status` / `position` — read-only "what's next" derived purely from persisted state (<30 s).
- `doctor` — read-only diagnostics: lock holder/liveness, in-flight steps, pending re-drives,
  CO/lake availability.
- `discharge` — close the run **iff** every checklist item is satisfied and every backlog item is
  terminal/deferred; otherwise refuse (exit 1) and **name the blockers** — unless an override exists.

**Intake / backlog**
- `capture --kind {latent-requirement|issue|bug|missing-prerequisite|idea} --title T [--stage S]`
- `expand --item ID --steps "a,b,c"` (preserves parent→child lineage)
- `park --item ID` / `sequence --item ID [--after STEP | --before STEP]`
- `resolve --item ID` (mark done) / `defer --item ID` (explicitly defer — terminal for discharge)
- `backlog [--state {parked|sequenced|all}]` (read-only)

**Steps / checkpoints / verification**
- `step-start --step ID`
- `checkpoint --step ID [--paths p1,p2] [--summary S] [-m MSG] [--allow-skip-hooks]` — writes the
  durable `complete` row FIRST, then a **scoped commit** of exactly `--paths` (never `-A`/`--force`;
  hooks run unless `--allow-skip-hooks`); refuses on a secret-pattern path.
- `trace --subject S --decision {accept|reject} [--evidence E] [--score N]` (append-only).

**Gates**
- `gate present --step ID --ref REF` / `gate decide --step ID {--approve|--change}`
- `discharge-item add --description D` / `discharge-item satisfy --item ID`
- `override --ack TOKEN --rationale R` (informed-consent discharge override; auditable)

**Version**
- `version` — the installed Marathon/buildkit version (deep-deploy converges every target).

Every subcommand accepts `--feature F` (else resolved from `.specify/feature.json`), `--home H`,
and `--json` (emits a `{"schema_version":"1", …}` envelope). Exit codes: 0 success/no-op · 1
refused (gate blocked / read-only second holder / usage) · 2 PGlite/DB unavailable · 3 version skew.

A second concurrent shell detecting a live lock holder runs **read-only** and warns (advisory lock,
FR-001a). All persisted/emitted free text is secret-redacted first.

## Boundaries

Advisory only. It **never** auto-invokes a `/buildkit-*` command, is **not** a pipeline stage, makes
no `feature_pipeline`/DBOS mutation, and never force-commits or bypasses hooks unless explicitly
asked. Run the recommended next pipeline command yourself.
