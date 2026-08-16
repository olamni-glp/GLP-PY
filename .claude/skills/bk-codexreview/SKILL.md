---
name: "bk-codexreview"
description: "Strategy-driven, plan-first, scored code review. By DEFAULT a team of local Claude review sub-agents and the local codex CLI plan the review together (independent draft plans → one deterministically-merged standardized plan), agree a convergence-cycle count the engineer approves, then execute it adversarially (cross-critique CONFIRM/REFUTE/ESCALATE) over a bounded number of cycles (≤ approved, hard cap 10, ≥2 passes). Findings are scored deterministically on an evidence-gated 0–10 rubric, and the review context is delivered as a size-invariant BRIEF (spec + changed-files list, NEVER the diff body) so a huge diff cannot overflow the context window. --review-only --max-cycles 1 reproduces today's read-only single-shot. Per-cycle/per-reviewer token usage is recorded via the spec-020 ledger; an advisory token/time budget warns + asks to confirm beyond the cap. Never pushes, never mutates pipeline state, refuses on a dirty tree or protected branch (without --confirm-protected). Advisory: it never blocks a merge and never auto-invokes another buildkit-* command."
argument-hint: "[--review-only] [--scope diff|<path>|repo] [--aspect <descriptor>] [--max-cycles <n>] [--reviewers <n>] [--confirm-protected] [--base <ref>] [--reasoning-effort low|medium|high] [--allow-secrets-in-diff] [--max-seconds <n>]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-codexreview.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (it carries the flags below).

## What this does

`/bk-codexreview` is the **conductor** for a **strategy-driven, plan-first, scored** review. By
default a team of **local Claude review sub-agents** and the **local codex CLI** plan the review
together, agree a convergence-cycle count you approve, then execute it adversarially over a bounded
number of cycles — until a cycle surfaces **no new finding** (deterministic convergence) or the
**approved count / hard cap of 10** is reached. The deterministic work (the size-invariant brief,
secret pre-scan, plan merge, finding identity/merge/convergence, cross-critique, scoring, the
checkpoint commit, token recording, the budget guardrail, the verdict) lives in the
`buildkit-codexreview` console subcommands you call below; **you** (the agent) orchestrate the loop
and spawn the sub-agents.

It is **advisory**: it edits/commits **locally only**, never pushes, never mutates pipeline/DBOS
state, never blocks a merge, and never auto-invokes another `buildkit-*` command.

## The two layers (do not violate)

- **Python primitives** (`buildkit-codexreview <subcommand>`): everything deterministic — `brief`,
  `plan-merge`, `merge` (identity/convergence/cross-critique), `score`, `budget-check`,
  `commit-cycle`, `verdict`, `strategy`, `rollback`.
- **Sub-agents (you spawn via the Agent tool)**: the Claude **review team** (independent planning +
  execution + cross-critique + scoring), the **moderator** (plan merge resolution), and the
  **fixer** (fix mode). A plain Python process cannot spawn a Claude sub-agent, so the loop is yours.

## Overflow-proof context (US1 — the field-incident fix)

The review **never embeds the diff body**. `brief` builds a **size-invariant** context — the feature
`spec.md` path (the models read it) + the **changed-files list** — and each model investigates the
code directly with read-only repo access. Prompt size is **O(number of changed files)**, independent
of diff size: a ~84-file / 349 KB+ diff reviews without a context-window overflow. `reviews/` is
excluded from the change set (FR-003) so the review's own artifacts never re-enter scope.

## Core flow (plan-first, scored — the default)

Run from the repo root. Parse the user flags into: `STRATEGY` (default `standard-code-review`),
`SCOPE` (default `diff`), `ASPECT` (default `general`), `MAX_CYCLES` (engineer-approved; default 10,
hard cap 10), `MIN_PASSES` (default 2), `REVIEWERS` (default 1), `BASE`, `TOKEN_BUDGET`,
`TIME_BUDGET_S`, `CONFIRM_PROTECTED`, `REASONING`, `MAX_SECONDS`, `ALLOW_SECRETS`.

### 0. Framing (cycle 0 — engineer params)

Identify the review type + change kind (languages / size / risk) from the changed-files list. Confirm
the parameters with the engineer using sensible defaults (strategy, max cycles, scope, focus,
reviewer count). These are **the engineer's** to set (FR-006). Show the selected strategy:

```bash
buildkit-codexreview strategy show --strategy "$STRATEGY" --json
```

### 1. Preflight (once, before cycle 1)

```bash
buildkit-codexreview preflight --scope "$SCOPE" [--base "$BASE"] [--aspect "$ASPECT"] \
    [--confirm-protected] [--allow-secrets-in-diff] --json
```

If it refuses (exit 2 — `empty_scope` / `secrets_in_diff` / `dirty_tree` / `protected_branch` /
`codex_not_found` / `codex_not_usable`), **surface the message verbatim and STOP**. Otherwise record
`run_id`, `base`, `branch`. Use this `run_id` for **every** cycle and the final verdict. Note the
`reviews_gitignored` flag + `self_navigation_residual` (FR-005) in your summary.

### 2. Build the brief (overflow-proof, secret-scanned)

```bash
buildkit-codexreview brief --scope "$SCOPE" [--base "$BASE"] [--aspect "$ASPECT"] \
    --strategy "$STRATEGY" --require-codex --json
```

This **secret-scans the content of the changed files FIRST** (FR-004) and refuses (exit 2
`secrets_in_diff`, naming `relpath:line`) on a hit. The returned `brief_text` is the **identical
context** you hand to BOTH codex and the Claude reviewers. If `file_count_extreme` is true, note the
change is unusually broad. Re-build the brief each cycle (the fixer mutates content → re-scan).

### 3. Independent draft plans (cycle 1 — no peeking, FR-007)

Spawn the **Claude review sub-agent team** and run **codex** to each draft a plan **independently**,
using the strategy's planning instructions (`strategy show` → `planning_instructions`). Neither team
sees the other's plan. The codex planner is told (its block carries the **merge contract**) that its
plan **will be merged afterward by a different agent/human**, so it must be standalone,
self-contained, and dedup-friendly (explicit `dimension` + `target_file`, `must_do` vs optional).

Each team emits a `ReviewPlan` JSON (`team`, `items:[{dimension, target_file, description, must_do}]`,
`proposed_cycle_count`, `risk_ranked_areas`, `notes`). Write them to
`reviews/<branch>/<run_id>/cycle01/plan-claude.json` and `plan-codex.json`.

### 4. Merge the plans (deterministic + moderator, FR-009)

```bash
buildkit-codexreview plan-merge --claude "…/cycle01/plan-claude.json" \
    --codex "…/cycle01/plan-codex.json" --out "…/cycle01" --json
```

`plan-merge` deterministically **unions + dedups** by `(dimension, target_file)`, surfaces
**contradictions** (opposing `must_do`), assigns **primary ownership** per dimension, and writes
`plan-merged.json`. If it refuses `single_plan` (exit 2 — one team produced no plan), surface it and
ask the engineer rather than proceeding on one plan. By **default an automated moderator sub-agent**
reviews the merged plan + the surfaced contradictions and finalizes ownership/resolution; the
**engineer MAY override**. The moderator's resolution is validated against the deterministic merge.

### 5. Agree + recommend a cycle count → engineer approves (FR-010)

Both teams agree the merged plan and jointly recommend a convergence-cycle count (use
`proposed_cycle_count_range` from `plan-merge`). The **engineer approves** the final `MAX_CYCLES`
(≤ 10). If the two recommendations are irreconcilable, the engineer decides.

### 6. Execute (cycles 3..N, ≤ approved, cap 10, ≥ MIN_PASSES, early-exit)

For each execution cycle `K`, compute `cycle0K`:

**a. Review against the merged plan.** Run codex with the **brief form** + the merged plan, and spawn
`REVIEWERS` Claude reviewers in parallel over the **same** brief + plan:

```bash
buildkit-codexreview codex-pass --cycle K --scope "$SCOPE" [--base "$BASE"] [--aspect "$ASPECT"] \
    --strategy "$STRATEGY" --plan "…/cycle01/plan-merged.json" --run "<run_id>" \
    --out "…/cycle0K" [--cross-feed "…/cycle0(K-1)/crossfeed.json"] \
    --reasoning-effort "$REASONING" --max-seconds "$MAX_SECONDS" [--allow-secrets-in-diff] --json
```

`--strategy`/`--plan` select the **brief** form automatically (no diff body). `codex-pass` runs the
strategy's **deterministic checks** (`deterministic_checks` → secret-scan / unscoped-query search /
type-check) so "must-not" rules are backed by tooling, not model judgement alone (FR-014); the
results + gate verdicts are in the payload's `deterministic_checks`. Each Claude reviewer returns
strict finding JSON (`claude-i.json`) **plus** per-finding `axis_scores` for the rubric.

**b. Cross-critique.** Each team marks the other team's findings CONFIRM / REFUTE / ESCALATE; a
REFUTE **requires counter-evidence** (`file:line` + reasoning). Collect the verdicts into
`crosscritique.json` (`{critiques:[{path,line_start,line_end,issue_class,by_team,verdict,counter_evidence}]}`).

**c. Merge + convergence (deterministic).**

```bash
buildkit-codexreview merge --cycle K --out "…/cycle0K" \
    --codex "…/cycle0K/codex.json" [--claude "…/cycle0K/claude-i.json" ...] \
    [--prev "…/cycle0(K-1)"] --crosscritique "…/cycle0K/crosscritique.json" \
    --scope "$SCOPE" [--aspect "$ASPECT"] --json
```

`merge` de-dups by identity, **drops naming-only findings** (no concrete `path` — FR-013), records
cross-critique verdicts (a validly-refuted finding is dropped from the surfaced set but logged), and
computes convergence over the **combined identity set** (the authoritative signal — FR-015). Read
`converged`, `new_count`, `surfaced_count`, `refuted_count`.

**d. Score (deterministic, advisory).**

```bash
buildkit-codexreview score --findings "…/cycle0K/result.json" --strategy "$STRATEGY" \
    [--mode selection|refinement] [--refinement-target 0.90] \
    [--adversarial "…/cycle0K/codex-rescore.json"] [--gates "…/cycle0K/gates.json"] \
    --out "…/cycle0K" --json
```

Scores are **pure Python** on the evidence-gated rubric — the model supplies per-axis bands, Python
does the arithmetic (never the model). A load-bearing axis with no cited proof → HOLD/FAIL **even if
the weighted total is high**; any NO-GO gate disqualifies; the codex adversarial pass may **only
lower** a score. Two-scorer dissent is logged (`score-dissent.json`), never averaged. The score is
**advisory** — it never gates a merge and never replaces convergence.

**e. Convergence / early-exit.** If `converged` is true **and** at least `MIN_PASSES` cycles have run,
the loop is done → go to the verdict. (A single empty pass must NOT short-circuit to clean — SC-004.)

**f. Fix (fix mode only).** If the surfaced set is non-empty, spawn **one Claude fixer sub-agent**
(distinct from any reviewer — FR-002) with the surfaced findings; then commit the checkpoint:

```bash
buildkit-codexreview commit-cycle --cycle K --max-cycles "$MAX_CYCLES" --scope "$SCOPE" \
    [--aspect "$ASPECT"] --out "…/cycle0K" [--confirm-protected] --json
```

**g. Budget guardrail (warn + confirm — FR-037).** After each cycle:

```bash
buildkit-codexreview budget-check --run "<run_id>" [--token-budget "$TOKEN_BUDGET"] \
    [--time-budget-s "$TIME_BUDGET_S"] --json
```

Defaults are `--token-budget 500000` / `--time-budget-s 3600`. If `crossed` is true, **warn the
engineer and ask them to confirm** continuing — it **never hard-blocks** (always exit 0).

**h. Next cycle.** Carry `cycle0K/crossfeed.json` as the next cycle's `--cross-feed`; set `--prev` to
`cycle0K`; continue until convergence (≥ `MIN_PASSES`) or `MAX_CYCLES`.

### 7. Verdict (always)

```bash
buildkit-codexreview verdict --run "<run_id>" --out "reviews/<branch>/<run_id>" \
    --mode fix --max-cycles "$MAX_CYCLES" --min-passes "$MIN_PASSES" --scope "$SCOPE" \
    [--aspect "$ASPECT"] [--base "$BASE"] --json
```

Writes `run.json` + `verdict.md`: `converged@K` / `capped@N` / `clean` / `unconfirmed`, residual
findings, per-cycle checkpoints, unreviewed units, the advisory `weighted_overall` + any load-bearing
HOLD/FAIL (non-gating — FR-016/SC-009), and the budget state. The reviewer **never blocks a merge**.

## US5 — GEPA `quality` acceleration (optional, fail-safe)

When the strategy binds an `optimization_strategy_ref` (the `refine` Strategy id) and the `[refine]`
extra is installed, the planner sets the strategy's `budget` + `optimizer_settings`, and the refine
engine optimizes the **`quality`** objective (the normalized rubric `weighted_overall`) alongside the
minimize objectives. The REFINEMENT-mode `refinement_target` (e.g. 0.90) is the **stop signal**
(`score --mode refinement --refinement-target` reports `target_met`). The integration is **fail-safe
(inherited)**: a broken/absent optimizer (or `optimization_strategy_ref=None`) → the review completes
on **baseline** with a recorded `failed` optimization state; it never crashes the stage (FR-034).

## The fallback (opt-in single-shot — D9/FR-038)

```text
/bk-codexreview --review-only --max-cycles 1 --scope diff   # today's read-only single-shot
```

Reproduces the legacy `codex review --base <ref>` form verbatim (the `base` form, no strategy/plan)
at `reviews/<branch>/<UTC>/codex.md`. **Retained, not removed** — its back-compat tests stay green.
The `buildkit-codexreview` console entry with no subcommand does exactly this single pass (a direct
Python call cannot spawn the team); the default plan-first flow is this skill's job.

## Scope & aspect (`--scope` / `--aspect`)

- `--scope diff` (default) reviews the branch diff vs `--base`; `--scope <path>` / `repo` sweep
  tracked files (minus vendored excludes **and `reviews/`**). The brief carries the changed-files
  list for any scope; the secret pre-scan covers the changed-file content before any send.
- `--aspect <descriptor>` (e.g. `security`, `error-handling`) focuses the review; default `general`.

## Rollback

```bash
buildkit-codexreview rollback --cycle K --json      # revert one cycle's checkpoint
buildkit-codexreview rollback --run <run_id> --json # revert the whole run's checkpoints
```

Default uses `git revert --no-edit` (safe). `--hard` (a reset) requires `--confirm`. Never pushes.

## Constraints (hard)

- **Never push, never mutate pipeline/DBOS state** (FR-035). The only writes are working-tree edits,
  local commits, on-disk artifacts under `reviews/` (gitignored), and the advisory token ledger.
- **Advisory throughout** — the verdict/score/budget never block a merge; `budget-check` warns +
  asks confirm, never aborts. The reviewer never auto-invokes another `buildkit-*` command.
- **Fix mode needs a clean tree on a non-protected branch.** Dirty → refuse; protected
  (`main`/`master`/`develop`) → refuse unless `--confirm-protected`.
- **Reviewer ≠ fixer** (FR-002): codex + the Claude reviewers only review; a separate Claude fixer
  applies fixes.
- **Secret pre-scan runs every cycle** over the changed-file content (FR-004), because the fixer
  mutates content between cycles. Override only with `--allow-secrets-in-diff`.
- **Convergence is deterministic** — computed by `merge` over the `(path, range, class)` identity
  set, never by your judgement; the score and cross-critique inform but never replace it (FR-015).
- **Bounded** — never more than the engineer-approved count or the hard cap of 10; ≥ `MIN_PASSES`
  (default 2) before declaring converged/clean.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | loop completed (converged / capped / clean / review-only); also every advisory subcommand (`budget-check`) |
| 1 | internal error |
| 2 | refusal (codex unavailable, empty scope, secrets, dirty tree, protected branch, `single_plan`, unknown `strategy`) |
| 3 | codex exited non-zero or timed out (partial artifact persisted) — stop the loop |

## Per-cycle / per-reviewer token record (spec-020 ledger, advisory)

`codex-pass` records the codex token each cycle automatically. For each Claude reviewer/fixer the
harness exposes usage for, record it too (never fabricate counts — omit for an `unavailable` 0):

```bash
buildkit-codexreview tokens --cycle K --reviewer claude-1 --total <N> --method self-reported \
    --run "<run_id>" [--feature <id>] --scope "$SCOPE" [--aspect "$ASPECT"] --json
```

Advisory and non-blocking — a catalog failure prints a notice and the loop continues.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-codexreview` from the project root. It marks
the capability registry possibly-stale and **always exits 0** (fail-safe; never blocks). Ignore output.
