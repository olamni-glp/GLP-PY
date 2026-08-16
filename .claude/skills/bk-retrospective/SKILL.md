---
name: "bk-retrospective"
description: "Advisory post-cycle retrospective. Turns one completed per-feature cycle (specify→ship, keyed by feature_id) into an action-focused, root-caused, durable lessons-learned: gathers the cycle's /bk-codify notes, /bk-codexreview artifacts, and pipeline-stage + sizing/token history; diagnoses & groups root causes (systematic vs one-off); proposes engineer-confirmed roadmap items with duplicate-flagging; surfaces skillify/toolify opportunities; produces trackable improvement actions; captures feedback; and emits a durable cataloged Markdown report. Refines its own root-cause inference via the spec-022 GEPA engine when the [refine] extra exists, else runs on baseline inference. Advisory only: never auto-invokes a /buildkit-* command, never auto-writes the roadmap (per-item confirm only), never mutates pipeline/DBOS state."
argument-hint: "[feature_id of a completed cycle, e.g. 022-buildkit-retrospective] | run <feature_id> | list | show <retro_id> | finding/proposal/action/skillify/feedback ... | report <retro_id>"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-retrospective.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The argument is the
`feature_id` of a **completed** cycle to retrospect. If empty, resolve the active feature from
`.specify/feature.json`; if none, ask the user which `feature_id` to retrospect.

## What this does

`/bk-retrospective <feature_id>` conducts a structured, advisory retrospective over **one
completed per-feature cycle**. It is **read-only with respect to your pipeline**: it records a
durable lessons-learned and nothing else. It **never** switches branches, edits source, runs
tests, pushes, mutates pipeline/DBOS state, auto-writes the roadmap, or auto-invokes
`/bk-implement` or any other `/buildkit-*` command (FR-019). It is **NOT a canonical
pipeline stage** — do **not** call the sidecar `start`/`complete` for it (R12).

This skill **conducts**; the deterministic `buildkit-retrospective` CLI does the gather / persist
/ format / propose-gate work. The **root-cause and skillify reasoning is yours** (the LLM's) —
that reasoning prompt is the artifact the spec-022 GEPA engine refines (FR-016).

## Conducting flow

### 1. Gather the cycle inputs (FR-012)

Run from the project root:

```
buildkit-retrospective run <feature_id> --json
```

This gathers the cycle's `/bk-codify` notes, `/bk-codexreview` artifacts under
`reviews/`, `stage_transition` history, the spec-020 token report, and `size_estimate` history;
secret-redacts every gathered text (FR-020); creates a `draft` retrospective; and returns
`retro_id`, `report_path`, and `inputs_summary` (including a **`missing`** list). **State any
missing source explicitly in your analysis — never fail on it** (Edge Case). Pass `--no-optimize`
to force baseline inference.

### 2. Resolve the inference guidance (FR-016)

Read the active root-cause/skillify inference prompt the engine may have refined at
`.specify/.refine-cache/retro-inference-<feature_id>.txt`; if absent, use the built-in baseline
inference prompt (it is the floor — the retrospective always runs without the `[refine]` extra).
Prepend it to your reasoning context. The `run` step already recorded any `optimization_run_id`.

### 3. Diagnose root causes (your reasoning — use Agent sub-agents)

Reason over the gathered bundle. Trace each symptom to its **root cause**, not the surface
symptom. **Group** related findings under a shared `--group` key and **classify** each as
`systematic` (recurring/structural) or `one_off`. Attach concrete **evidence refs** back to the
exact codify note / codexreview finding / stage row / sizing or token metric. For a thorough
cycle, spawn parallel Agent sub-agents over distinct lenses (sizing/token drift, process gaps,
tooling friction, quality signals) and reconcile.

Record each finding:

```
buildkit-retrospective finding add <retro_id> --title "<root cause>" \
    --class systematic|one_off --group <group-key> \
    --evidence '[{"kind":"sizing","ref":"se-feature-<id>"}]' --detail "<why>"
```

### 4. Propose roadmap items — engineer-confirmed only (FR-014)

For findings worth acting on at the roadmap level, format a proposal. `proposal add`
auto-flags a likely **duplicate** against the existing roadmap (overlap heuristic):

```
buildkit-retrospective proposal add <retro_id> --from-finding <fid> \
    --title "<feature title>" --problem "<problem>" --value "<value>"
buildkit-retrospective proposal list <retro_id> --json    # shows duplicate_flag/ref
```

**Present each proposal to the engineer and obtain explicit confirmation.** Only on a confirmed
"yes" run — this is the ONLY path that writes a roadmap row (surfaces a duplicate warning first):

```
buildkit-retrospective proposal confirm <proposal_id>
```

Dismiss the rest (`proposal dismiss <proposal_id>`). **Never confirm without the engineer's
explicit go-ahead.**

### 5. Surface skillify / toolify opportunities (FR-015)

Where work was improvised on the fly or a tool was missing/weak, record it:

```
buildkit-retrospective skillify add <retro_id> --kind net_new|enhancement \
    --title "<opportunity>" --tool <buildkit-tool> --rationale "<why>" [--improvised]
```

### 6. Produce trackable improvement actions (FR-025)

Every actionable improvement becomes an `action`, always labeled systematic vs one-off and
tracked to closure:

```
buildkit-retrospective action add <retro_id> --kind codify_win|fix_failing \
    --class systematic|one_off --area "<target area>" --title "<action>"
```

Close actions with `action apply <action_id>` / `action dismiss <action_id>`.

### 6b. Close the loop — action lifecycle, staleness, linkage (spec-027)

Beyond the flat `apply`/`dismiss`, each action carries a **richer, owned, dated, audited
lifecycle** layered additively over the legacy row (the lifecycle record is authoritative and
reconciles one-directionally back into the legacy `status` in the same transaction, so the
section-6 commands keep working). All of this is **advisory** — no auto-close, no roadmap write,
no pipeline auto-invoke.

**Lifecycle (US1)** — own it, date it, advance it, with a full attributed history:

```
buildkit-retrospective action own <id> --owner "<team-or-person>"   # ≤200 chars, redacted
buildkit-retrospective action due <id> --date 2026-06-20            # UTC YYYY-MM-DD ('' clears)
buildkit-retrospective action advance <id> --to in_progress|blocked|deferred|done|dismissed \
    [--note "<why>"] [--expect-version <n>]
buildkit-retrospective action reopen <id> [--to open|in_progress] [--note "<why>"]  # terminal only
buildkit-retrospective action touch <id> [--note "<why>"]           # reset the staleness clock
buildkit-retrospective action status  <id>                          # status/owner/due/idle + legacy
buildkit-retrospective action history <id> --json                   # every change, never lost
```

A disallowed transition (e.g. `done → blocked`) is refused cleanly and leaves the action
unchanged; leaving a terminal state is **only** via `reopen`. Concurrent edits surface a conflict
(refresh & retry), never a silent overwrite.

**Stale / overdue surface (US2)** — one command answers "what's overdue or stale, owned by whom?"
across **all** retrospectives, most-urgent-first; terminal actions never appear; an empty result
is a clean success:

```
buildkit-retrospective stale [--threshold <days>] [--feature <id>] [--owner <text>]
buildkit-retrospective config get-threshold        # default 14 when unset
buildkit-retrospective config set-threshold <days> # per-repo default (last-writer-wins, >0)
```

`--threshold` is a per-run what-if and does **not** change the stored default. Staleness is
deterministic (the clock is bumped by writes only, never reads).

**Linkage + offer-to-close (US3)** — link an action to the roadmap feature / backlog item that
delivers it (existence-validated, no dangling links; many links per action; soft-removable):

```
buildkit-retrospective action link  <id> --kind roadmap_feature|backlog_item --target <id>
buildkit-retrospective action links <id> [--all]    # each link + the item's CURRENT state
buildkit-retrospective action unlink <link_id>      # soft-retire (history preserved)
buildkit-retrospective reconcile [--feature <id>]   # OFFER-only: surface delivered-link actions
buildkit-retrospective reconcile --apply <action_id># engineer-confirmed close → done
```

`reconcile` reads the linked item's delivered-state **read-only** and only **offers** to close;
it changes nothing until you run `--apply` (the confirmation). It never writes the
roadmap/backlog and never auto-invokes a pipeline command. **Surface the offer to the engineer
(AskUserQuestion) and obtain explicit confirmation before running `--apply`.**

### 7. Capture feedback (FR-017)

```
buildkit-retrospective feedback add <retro_id> --rating <1-5> --text "<engineer feedback>"
```

### 8. Emit the durable report (FR-018)

```
buildkit-retrospective report <retro_id>
```

Renders + writes the attributed, timestamped Markdown report to
`.specify/retrospective/<feature_id>/<UTC>.md`, secret-redacts it, and marks the retrospective
`complete`. Re-running a retrospective for the same feature **never loses** a prior one (SC-008).

### 9. Record tokens (FR-023, advisory)

The per-stage token spend for this retrospective is recorded on the spec-020 ledger under the
`retrospective` stage (advisory — a catalog hiccup never blocks the flow).

## Advisory boundaries (non-negotiable)

- Never auto-invoke another `/buildkit-*` command.
- Never auto-write the roadmap — a roadmap row appears **only** via an explicit
  `proposal confirm` you ran after the engineer agreed.
- Never push, never mutate pipeline/DBOS state, never call the sidecar (not a canonical stage).
- Secrets are redacted before any persistence or external send.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-retrospective` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
