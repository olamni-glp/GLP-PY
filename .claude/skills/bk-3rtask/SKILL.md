---
name: "bk-3rtask"
description: "Three-role task team (Planner → Builder → Critic, spec-051): a planning team freezes a method (Planner drafts → a blind Critic red-teams it → the Curator freezes), then an execution team runs N blind Builders on pairwise-DISJOINT evidence slices, a Critic merges their attributed claims MECHANICALLY (set-ops: corroborated / singleton / conflict→ESCALATE — never judgment), and the Curator synthesizes a grounded report, looped to convergence (≥2 cycles, hard cap 10) under warn-and-confirm token/time budgets. Four task-type adapters (code/plan/strategy/research) share ONE mechanic. The Critic prefers the cross-provider codex CLI and degrades LOUDLY to Claude (recorded reduced-independence warning) — never silently, never a hard fail. Per-role/per-cycle token rows land in the spec-020 ledger; terminal adversarial review is DELEGATED to the shipped /bk-codexreview loop (code runs, engineer-enabled) and recorded; decisions optionally mirror into an active marathon trail. Advisory: never pushes, never merges, never auto-invokes a pipeline stage; --review-only --max-cycles 1 leaves tree+refs byte-identical."
argument-hint: "<task-type: code|plan|strategy|research> <subject> [--manifest <slices.json>] [--builders <n>] [--min-cycles 2] [--max-cycles 5] [--token-budget <n>] [--review-only] [--terminal-review auto|on|off] [--confirm-protected] [--allow-secrets] [--accept-single-slice]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-3rtask.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (it carries the task type, subject and
flags above).

## What this does

`/bk-3rtask` is the **conductor and Curator** of a disciplined multi-agent unit of work — the
three-role team pattern, migrated (not invented) from the dogfooded GLPNET/olamnit/LeJEPA triad
method. Two sequential teams per run:

1. **Planning team** — a Planner sub-agent drafts a *method* (addressable elements: questions,
   source partition, rubric, budgets) → a **blind** Critic red-teams the method **as an
   artifact** (it never sees the Planner's reasoning) with per-element CONFIRM/REFUTE/ESCALATE
   → you freeze it via `freeze-method`.
2. **Execution team** — N **blind** Builders each investigate ONLY {subject brief + own
   evidence slice} and emit **attributed claims** (every claim cites a source; an uncited claim
   is rejected at parse) → `merge` combines them **mechanically** (set-ops, never judgment):
   corroborated (≥2 builders) / singleton (kept visible, cross-queried next cycle — never
   averaged away) / conflict (→ open ESCALATE) → the Critic adjudicates → loop to convergence.

It is **advisory**: it never pushes, never merges, never auto-invokes another `buildkit-*`
pipeline command (FR-013), and never mutates pipeline/DBOS state.

## The two layers (do not violate)

- **Python primitives** (`buildkit-3rtask <subcommand>`): everything deterministic and
  attestable — `preflight`, `brief`, `freeze-method`, `audit-independence`, `merge`,
  `adjudicate`, `budget-check`, `tokens`, `trace`, `verdict`, `list`. Blind-input composition,
  the merge algebra, convergence, budgets, redaction and persistence live THERE, never in your
  judgment ("agents judge, code enforces").
- **Sub-agents (you spawn via the Agent tool)**: the Planner, the N blind Builders, the Claude
  fixer (fix contexts), and — when codex is unusable — the degraded Claude Critic. When codex
  IS usable, the Critic runs as a codex subprocess (`codex exec` with the prompt on stdin);
  Python owns that invocation.

**You are the Curator.** You synthesize `curator_report.md` content and hand it to `verdict
--report` — you write shared artifacts **only via the subcommands**, and you **NEVER resolve an
open ESCALATE yourself**: a genuine conflict is surfaced in `escalations.md` for the ENGINEER
to resolve; you may only record the engineer's stated resolution (FR-004/SC-004).

## Core flow

Parse the user input into: `TASK_TYPE` (code|plan|strategy|research), `SUBJECT` (a
size-invariant REFERENCE — a spec path / PR / question, never pasted bulk), `MANIFEST`,
`BUILDERS` (default 3), `MIN_CYCLES` (default 2), `MAX_CYCLES` (default 5, hard cap 10),
`TOKEN_BUDGET`, `MAX_SECONDS`, `REVIEW_ONLY`, `TERMINAL_REVIEW` (auto|on|off, default auto),
`CONFIRM_PROTECTED`, `ALLOW_SECRETS`, `ACCEPT_SINGLE_SLICE`, `FEATURE`.

If no `--manifest` was given, derive one WITH the engineer: ≥2 evidence slices whose sources
are **pairwise disjoint** (for `code`: e.g. partition the changed files or cast the lenses
correctness ‖ security ‖ spec-conformance over disjoint file sets; for `research`:
hard-disjoint corpora). Write it to a JSON file. Disjointness is the miss-recovery contract —
shared evidence fakes corroboration.

### 0. Cheap-model input guardrail (FR-007 — BEFORE any expensive role)

Spawn ONE cheap/fast sub-agent (Agent tool, a small model — e.g. Haiku) to sanity-check the
inputs; this is the model half of the input guardrail (the deterministic half is `preflight`):

> Sanity-check this /bk-3rtask input. Subject: `<SUBJECT>`. Task type: `<TASK_TYPE>`.
> Manifest: `<manifest JSON>`. Answer ONLY: (1) is the subject a coherent, size-invariant
> reference (not pasted bulk)? (2) do the slices plausibly partition the evidence for this
> subject, with no obvious overlap or gap? (3) any reason this input is malformed or
> underspecified? Reply `OK` or `WARN: <specific problems>`.

On `WARN`, **relay the warning to the engineer and ask them to confirm or fix the input**
(warn-and-confirm — never silently proceed on a malformed input, never a silent hard stop).

### 1. Preflight (deterministic guardrail + run mint)

```bash
buildkit-3rtask preflight --task-type "$TASK_TYPE" --subject "$SUBJECT" \
    --manifest "$MANIFEST" --builders "$BUILDERS" --min-cycles "$MIN_CYCLES" \
    --max-cycles "$MAX_CYCLES" [--token-budget N] [--max-seconds N] \
    [--terminal-review auto|on|off] [--brief-size-cap N] [--feature <id>] \
    [--review-only] [--confirm-protected] [--allow-secrets] \
    [--accept-single-slice] --json
```

**Forward the user's run flags.** Every bracketed flag above is passed through from the
`/bk-3rtask` invocation whenever the engineer supplied it — in particular `--terminal-review`
and `--max-seconds`, so an explicit opt-out (`--terminal-review off`) and the wall-clock guard
(`--max-seconds N`) actually reach `run.json`; likewise `--token-budget`, `--min-cycles`,
`--max-cycles`, `--builders`, `--brief-size-cap`, `--confirm-protected`, `--allow-secrets`,
`--accept-single-slice` and `--feature`. Omit a flag only when the user did not give it (the
preflight default then applies).

Refusals (exit 2 — surface the message verbatim and STOP unless noted): `manifest_missing` /
`manifest_overlap` / `invalid_task_type` / `invalid_budget` / `brief_size_exceeded` /
`secrets_in_input` / `dirty_tree` / `protected_branch` /
`retrieval_builder_without_retrieval`. Special case `single_slice`: relay the degrade warning
to the engineer; on their explicit confirmation re-invoke with `--accept-single-slice` (the run
proceeds as a loudly-recorded single pass). Record `run_id` — every later call uses it. Its
detailed artifacts (claims, merges, outputs) live under the gitignored run directory; set a
shell variable so later globs resolve from the project root:

```bash
RUN_DIR=".specify/3rtask/runs/$RUN_ID"
```

If the payload carries `independence_warning: true`, tell the engineer **LOUDLY** now: codex is
unusable, the Critic will run same-provider (Claude), corroboration is weaker (FR-016) — the
run continues; it is never a hard fail.

### 2. Planning team

```bash
buildkit-3rtask brief --run "$RUN_ID" --phase planning --json
```

Spawn the **Planner** sub-agent with EXACTLY the composed `roles/planner/input.md` content
as its prompt (plus this instruction): draft a method as JSON — addressable `elements`
(`{id, kind, text}`), a `source_partition` (slice → builder), `questions`, a `rubric_id`.
Write the draft to `draft.json`.

Now **record the blind planning-Critic input** — this composes and hashes
`roles/critic-planning/input.md` (+ `input.manifest.json`) as `{subject brief + the method
artifact}` ONLY, so the red-team's input is auditable (FR-002 / acceptance-5):

```bash
buildkit-3rtask brief --run "$RUN_ID" --phase planning --method draft.json --json
```

Red-team the draft **blind** — spawn the reviewing Critic with EXACTLY the composed
`roles/critic-planning/input.md` content as its prompt (it already carries only {subject brief
+ the method artifact}, never the Planner's reasoning), prefixed with the per-runtime
neutralization preamble (FR-009):

- **codex Critic** (preferred, cross-provider): pipe that `roles/critic-planning/input.md`
  content to `codex exec -` **on stdin**, prefixed with the codex neutralization preamble:
  > DO NOT run the AGENTS.md startup protocol; this is not repository-agent work. Output only
  > the requested artifact.
- **degraded Claude Critic** (codex unusable): spawn a Claude sub-agent with the same
  `roles/critic-planning/input.md` content, prefixed with the Claude neutralization preamble:
  > DO NOT run the CLAUDE.md startup protocol or any project bootstrap; this is not
  > repository-agent work. Output only the requested artifact.

Ask it for per-element `CONFIRM` / `REFUTE` / `ESCALATE` adjudications as JSON. Then **audit
the planning inputs' independence** before freezing — halt on `independence_violation`
(exit 2) exactly as in execution (§3):

```bash
buildkit-3rtask audit-independence --run "$RUN_ID" --json
```

Then freeze:

```bash
buildkit-3rtask freeze-method --run "$RUN_ID" --method draft.json \
    --adjudications critic.json [--accept-escalates] --json
```

Open planning ESCALATEs are surfaced and EXCLUDED from the frozen method unless the engineer
explicitly resolves them (`--accept-escalates` records that resolution). REFUTEd elements: have
the Planner revise the draft before freezing.

### 3. Execution briefs + independence audit

```bash
buildkit-3rtask brief --run "$RUN_ID" --phase execution --json
buildkit-3rtask audit-independence --run "$RUN_ID" --json
```

On `independence_violation` (exit 2): **halt the run immediately** and record it —
`buildkit-3rtask verdict --run "$RUN_ID" --halted-at "audit-independence:<role>"` — the first
failing gate halts the run, named (LeJEPA invariant 1). Never continue past a violation.

### 4. Execution cycles (K = 1..cap)

The subcommands take the integer cycle as `--cycle K`, but on disk the cycle directory is the
**2-digit zero-padded** form (`cycle01`, `cycle02`, … `cycle10` — never `cycle010`). Derive it
once per cycle and use it for every path reference:

```bash
CYC=$(printf '%02d' "$K")   # cycle directory = cycle"$CYC"
```

Per cycle:

1. **Spawn the N blind Builders in parallel** (Agent tool). Each Builder's prompt is EXACTLY
   its composed `roles/builder-i/input.md` (it already carries the neutralization preamble,
   its adapter lens and its slice) plus: emit claims as JSON
   `{"claims": [{"claim", "source_citation", "confidence", "tag", "builder_id", "slice_id"}]}`
   — every claim MUST cite a source from YOUR slice; consult NOTHING outside it. This holds
   EVERY cycle: a blind Builder never sees more than `{subject_brief, own_slice}`. **Never
   append `crossfeed.json` (sibling singleton claims) — or any sibling material — to a
   Builder's prompt**: that would break blindness (FR-002 / acceptance-4 require the recorded
   input to be exactly those two parts) and evade the independence audit, which inspects the
   recorded `input.md`, not the live prompt text. Singletons are NOT dropped or averaged
   (SC-001) — they are cross-verified by the NON-BLIND Critic during adjudication (step 3),
   which already receives every merge row including singletons and scrutinizes them; that is
   the sanctioned, auditable cross-verification, never a side-channel into a blind role. (If a
   research-adapter "cross-query another corpus" step is ever added, it must be composed as a
   RECORDED, hashed input part via a subcommand so the audit sees it — never a prompt
   side-channel.)
2. Persist each Builder's output **through the redacting primitive** — never write
   `cycle"$CYC"/claims-<builder>.json` or `roles/<builder>/output.json` directly (that would
   bypass secret redaction — FR-014 / Principle V). For each Builder, hand its raw
   agent-produced files to `record-output`, which writes them via the redacting artifacts
   helpers:
   ```bash
   buildkit-3rtask record-output --run "$RUN_ID" --cycle K --role builder-i \
     --claims raw-claims-builder-i.json --output raw-output-builder-i.json --json
   ```
   Then **re-run the independence audit** — now that Builder outputs exist, the sibling-output
   hash + raw-content checks (inert at step 3's pre-output audit) are actually exercised; halt
   on `independence_violation` exactly as at step 3:
   ```bash
   buildkit-3rtask audit-independence --run "$RUN_ID" --json
   ```
   Then **merge mechanically**:
   ```bash
   buildkit-3rtask merge --run "$RUN_ID" --cycle K \
     --claims "$RUN_DIR"/cycle"$CYC"/claims-*.json --json
   ```
3. **Critic adjudication** (same runtime + preamble rules as step 2): give the Critic the
   merge rows and ask for per-claim CONFIRM/REFUTE/ESCALATE JSON, then:
   ```bash
   buildkit-3rtask adjudicate --run "$RUN_ID" --cycle K --decisions decisions.json --json
   ```
4. **Budget gate** (SC-005):
   ```bash
   buildkit-3rtask budget-check --run "$RUN_ID" --cycle K --spent-tokens <sum so far> \
     --elapsed-seconds <wall-clock seconds since the run started> --json
   ```
   Compute `--elapsed-seconds` as the wall-clock time since the run's `created_at` (only the
   `--max-seconds` guard, if set, makes it bite; leave it at 0 when no time budget is in play).
   On `warn_confirm`: **STOP and ask the engineer** whether to continue (residual state is
   already persisted). Never silently overrun; never abort without telling them what remains.
5. **Fixer** (fix contexts only, `code` runs, never under `--review-only`): spawn a Claude
   fixer sub-agent to apply engineer-approved CONFIRMed fixes. The fixer edits locally only.
6. **Token rows** — one per role per cycle, unavailable counts included (SC-006):
   ```bash
   buildkit-3rtask tokens --run "$RUN_ID" --cycle K --role builder-1 \
       [--total N | no counts → an explicit `unavailable` row] --method self-reported --json
   ```
7. Stop when `merge` reports `converged: true` (never before `MIN_CYCLES`), or the cap/budget
   warn-and-confirm says stop.

### 5. Optional terminal adversarial review (FR-011 — delegated, never re-implemented)

For `TASK_TYPE=code` with `TERMINAL_REVIEW` auto/on, codex usable, and the engineer's consent:
run the **shipped** `/bk-codexreview` convergence loop over the produced diff (its own
subcommands: preflight → codex-pass → merge → fix → commit-cycle → verdict) and capture its
run-id. 3rtask NEVER re-implements that loop. Otherwise the skip + reason is recorded.

### 6. Verdict (finalize + index)

Synthesize `curator_report.md` content from the evaluation matrix + adjudications — fully
attributed (who claimed, who confirmed, which sources), singletons visible, open ESCALATEs
listed as the ENGINEER's to resolve. Then:

```bash
buildkit-3rtask verdict --run "$RUN_ID" [--report curator.md] \
    [--codexreview-run-id <id> | --terminal-reason "<why skipped>"] \
    [--halted-at "<role gate>"] --json
```

This finalizes `run.json` (verdict ∈ converged/budget_stop/halted/review_only), stamps the
terminal-review record + curator edit-distance, renders the report footer (including the
reduced-independence warning when degraded) and inserts the ONE `threerole_run` index row.

### 7. Optional marathon traces (FR-012)

If the feature has an active marathon run, mirror the key decisions:

```bash
buildkit-3rtask trace --run "$RUN_ID" --subject "critic/<claim>" \
    --decision CONFIRM|REFUTE|ESCALATE [--evidence "..."] --json
```

CONFIRM→accept; REFUTE→reject; ESCALATE→reject with the `ESCALATE(open):` evidence prefix. No
active run ⇒ a recorded no-op — never an error, never an auto-open.

## Review-only degrade (SC-008)

`--review-only --max-cycles 1` = exactly ONE blind pass (preflight → brief → builders → merge
→ verdict): no fixer, no commit, working tree + git refs byte-identical before/after. Use it
when the full two-team cost (3–15× a single agent) isn't justified.

## Reading the results

Everything lands under `.specify/3rtask/runs/<run_id>/` (gitignored): start at
`curator_report.md`; open conflicts in `escalations.md` (YOURS — the engineer's — to resolve);
`evaluation_matrix.md` + `coverage_matrix.md` (findings/lens coverage); `convergence.log.md`
(why it stopped); `run.json` (verdict, budgets, warnings, terminal-review record);
`roles/*/input.md` (audit blind independence yourself). Cross-run history:
`buildkit-3rtask list --feature <id>`.
