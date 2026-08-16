---
name: "bk-close"
description: "Post-ship close-out: one guided pass that runs the feature's retrospective and reconciles its open follow-up actions — feature resolved from .specify/feature.json (explicit id overrides). A curated, post-ship-framed entry point over the existing buildkit-retrospective (spec-022) + action-tracking (spec-027) CLIs. Advisory & additive: never advances the roadmap, never auto-invokes a /buildkit-* pipeline command, mutates/removes no existing record."
argument-hint: "[feature_id of a shipped feature, e.g. 033-unified-ship-close]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-close.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The argument, if present,
is the `feature_id` of a **shipped** feature to close out — it **overrides** the active feature
resolved from `.specify/feature.json`.

## What this does

`/bk-close [<feature_id>]` is the **post-ship close-out** — the one command you run *after*
a feature ships to tie off the loop. It collapses two everyday post-ship flows into a single
guided pass:

1. a **retrospective** over the just-shipped cycle (wins/improvements captured additively), and
2. **reconciliation of the feature's open follow-up actions** (advance / reopen / close each).

It is a **skill-only macro** — it adds no new CLI, table, or migration. All work runs through the
existing **deterministic** `buildkit-retrospective` CLI (spec-022 retrospective + spec-027
action-tracking); this skill **conducts and frames** it for the post-ship moment.

It is **advisory and additive** (non-negotiable — see boundaries below): it **never** advances or
mutates the roadmap feature lifecycle (FR-007b), **never** auto-invokes `/bk-implement` or
any other `/buildkit-*` pipeline command (FR-009), and **never** mutates or removes an existing
record — every write goes through the existing additive retrospective/action paths (FR-010).

> The short twin `/bk-close` (spec-031) behaves identically — it is a byte-identical alias derived
> at setup.

> This is **NOT a canonical pipeline stage** — do **not** call the sidecar `start`/`complete` for
> it (same rule as `/bk-retrospective`).

## Conducting flow

### 1. Resolve the feature (FR-007a)

Resolve the `feature_id` to close out, in this order:

1. the explicit `$ARGUMENTS` feature-id, if given;
2. otherwise the active feature from `.specify/feature.json`
   (`pipeline/feature.py:read_feature_file` → `feature_id`).

If neither yields a feature id, **ask the engineer which `feature_id` to close out — do not
guess** (advisory: paths/ambiguity → ask).

### 2. Shipped check (graceful — FR-011)

Observe whether the feature actually **shipped** before retrospecting it — a close-out is intended
*post-ship*. Read-only signals (no mutation):

- a release tag exists for the cycle, and/or
- the feature branch / feature PR merged to `main`
  (e.g. `git tag --list`, `gh pr list --search "<feature_id>" --state merged`).

If the feature has not shipped: **advise** that close-out is meant to run after the feature ships,
and either **skip** or proceed **read-only** at the engineer's choice (AskUserQuestion). It never
errors and never fabricates retrospective context — the not-shipped path is a graceful no-op, not
a failure.

### 3. Retrospective pass (additive — FR-007, FR-010)

Run the existing retrospective flow for the resolved feature, capturing wins/improvements
**additively** and writing the dual-sink disk mirror `.specify/retrospective/<feature_id>/<UTC>.md`:

```
buildkit-retrospective run <feature_id> --json        # gather + draft (secret-redacted)
# … record findings / skillify as warranted …
buildkit-retrospective finding add <retro_id> --title "<root cause>" --class systematic|one_off …
buildkit-retrospective report <retro_id>              # render + persist the durable report
```

Follow `/bk-retrospective`'s reasoning steps (diagnose root causes, group, attach evidence).
**Roadmap proposals are recorded only on explicit engineer confirmation** (`proposal confirm`) —
never confirm without the engineer's go-ahead (FR-009). Re-running for the same feature **never
loses** a prior retrospective.

### 4. Action reconciliation — first-class step (FR-008, FR-011)

Surface the feature's **open follow-up actions** and let the engineer decide each — this is the
close-out's headline step, not an afterthought:

```
buildkit-retrospective stale --feature <feature_id>      # what's overdue/stale for this feature
buildkit-retrospective reconcile --feature <feature_id>  # OFFER-only: delivered-link actions
```

For each surfaced action, present it to the engineer (AskUserQuestion) and record their decision
via the existing spec-027 lifecycle CLI — **advance**, **reopen**, or **close**:

```
buildkit-retrospective action advance <id> --to in_progress|blocked|deferred|done|dismissed [--note "<why>"]
buildkit-retrospective action reopen  <id> [--to open|in_progress] [--note "<why>"]   # terminal only
buildkit-retrospective action touch   <id> [--note "<why>"]                           # reset staleness clock
buildkit-retrospective reconcile --apply <action_id>                                  # engineer-confirmed close → done
```

`reconcile --apply` and `action advance --to done` close an action **only on explicit
confirmation**. If there are **no linked/open actions**, report **"nothing to reconcile"** and
continue — the retrospective still runs (graceful empty; FR-011).

### 5. Report & recommend (advisory)

Summarize the captured wins/improvements and **each action decision**. You may **recommend** (do
**not** run) a logical next step — e.g. "consider `/bk-roadmap` to promote a confirmed
proposal." Recommending is allowed; auto-invoking is not (FR-009).

## Advisory boundaries (non-negotiable)

- **Never advance or mutate the roadmap feature lifecycle** (FR-007b) — close-out records
  decisions; promoting a feature on the roadmap stays a separate, explicit step.
- **Never auto-invoke** another `/buildkit-*` pipeline command (FR-009; Constitution I).
- **Additive only** — mutate or remove **no** existing record; all writes go through the existing
  retrospective/action paths (FR-010; Constitution II).
- Never push, never mutate pipeline/DBOS state, never call the sidecar (not a canonical stage).
- Secrets are redacted before any persistence or external send (inherited from the retrospective
  CLI).

## Notes

- Use `/bk-retrospective <feature_id>` directly for a retrospective that is **not**
  post-ship-framed, or when you don't want the action-reconciliation step foregrounded.
- A feature that hasn't shipped yet is fine — close advises and degrades gracefully (step 2).

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-close` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
