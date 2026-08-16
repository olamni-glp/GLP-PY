---
name: "bk-plan"
description: "Execute the implementation planning workflow using the plan template to generate design artifacts."
argument-hint: "Optional guidance for the planning phase"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/plan.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before planning)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_plan` key
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- When constructing slash commands from hook command names, replace dots (`.`) with hyphens (`-`). For example, `buildkit.git.commit` → `/buildkit-git-commit`.
- For each executable hook, output the following based on its `optional` flag:
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```
  - **Mandatory hook** (`optional: false`):
    ```
    ## Extension Hooks

    **Automatic Pre-Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}

    Wait for the result of the hook command before proceeding to the Outline.
    ```
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

**Sidecar pre-check (DBOS-backed pipeline)**:

Run `python -m buildkit_cli.pipeline.sidecar start plan` from the project root.
If the user passed `--force` or `--rerun` to this skill, append `--force` to the
sidecar invocation (FR-010 default-deny gate). If the sidecar exits non-zero,
abort the skill and surface the sidecar's printed message verbatim. If
`.specify/feature.json` is missing or empty, the sidecar exits 0 with a warning
line — proceed in that case.

**Refinement guidance-resolve (spec-007 FR-005)**:

After the sidecar pre-check, run `python -m buildkit_cli.refine resolve plan`
from the project root. It prints one JSON line
`{"guidance_version_id":…,"stage":"plan","source":"active|baseline","text_path":"<abs path>"}`
and **always exits 0** — it is read-only, never acquires the stage lock, and
on any error falls back to built-in baseline guidance with a one-line stderr
notice (so the stage is never blocked — FR-006). Read the file at `text_path`
and prepend its contents to your planning context as additional guidance.

## Outline

1. **Setup**: Run `.specify/scripts/powershell/setup-plan.ps1 -Json` from repo root and parse JSON for FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Load context**: Read FEATURE_SPEC and `.specify/memory/constitution.md`. Load IMPL_PLAN template (already copied).

3. **Execute plan workflow**: Follow the structure in IMPL_PLAN template to:
   - Fill Technical Context (mark unknowns as "NEEDS CLARIFICATION")
   - Fill Constitution Check section from constitution
   - Evaluate gates (ERROR if violations unjustified)
   - Phase 0: Generate research.md (resolve all NEEDS CLARIFICATION)
   - Phase 1: Generate data-model.md, contracts/, quickstart.md
   - Phase 1: Update agent context by running the agent script
   - Re-evaluate Constitution Check post-design

4. **Stop and report**: Command ends after Phase 2 planning. Report branch, IMPL_PLAN path, and generated artifacts.

**Sidecar post-record (DBOS-backed pipeline)**: On the success path, run
`python -m buildkit_cli.pipeline.sidecar complete plan` from the project root.
On any abort or error before this point, instead run
`python -m buildkit_cli.pipeline.sidecar fail plan --error "<one-line summary>"`.
The sidecar exits non-zero only if the database is unavailable; surface its
message but do not retroactively un-do work that already succeeded.

**Refinement signal-record (spec-007 FR-005)**: On the success path, after
the sidecar post-record, run `python -m buildkit_cli.refine record plan
--mode offline_guidance` from the project root. It records the produced
artifact against the resolved guidance version for later offline refinement.
It always exits 0 and never blocks; ignore its output.

**Story-size confirm-or-update (spec-020 FR-006/FR-007 — advisory, non-blocking)**:
On the success path, surface the feature's current story-point size and let the engineer
confirm / update / decline. This step NEVER blocks stage completion (SC-003).
1. Run `buildkit-size prompt plan --feature <feature-id> --json` (read-only; always exits 0,
   degrading to the built-in default buckets if the catalog is unavailable). Use the active
   feature id (the branch's `NNN-...` slug).
2. Present the returned current size + active scheme buckets to the engineer via
   AskUserQuestion with choices: Confirm unchanged / Update / Decline.
3. Record the chosen response (advisory — ignore any failure):
   - Confirm → `buildkit-size confirm feature <feature-id> --stage plan`
   - Update  → `buildkit-size set feature <feature-id> --label <bucket> --stage plan`
               (add `--points <n>` for a custom value; keep `--label` to retain the bucket name)
   - Decline → `buildkit-size decline feature <feature-id> --stage plan`
If `buildkit-size` is not installed or the catalog is down, skip silently — sizing is advisory.

**Key-configurable-item review/confirm (spec-020 FR-018 — advisory, non-blocking)**:
The plan surfaces concrete configurable decisions (e.g. the default scheme, thresholds, backend
choices). Reconcile the auto-suggested set from `/bk-specify` with the plan and confirm the
authoritative set:
- List current candidates: `buildkit-size config-item list --feature <feature-id> --json`
- Suggest any new plan-level candidate: `buildkit-size config-item suggest --feature <feature-id> --name "<name>" --source auto`
Then ask the engineer via AskUserQuestion to edit / confirm / remove:
- Confirm → `buildkit-size config-item confirm <config_item_id>`
- Remove  → `buildkit-size config-item remove <config_item_id>`
Only **confirmed** items are authoritative and may be sized
(`buildkit-size set config_item <config_item_id> --label <bucket> --feature <feature-id>`).
Non-blocking — if `buildkit-size` is absent or the catalog is down, skip silently.

**Per-stage token record (spec-020 FR-010 — advisory, non-blocking)**:
On the success path, record this stage's token usage (every stage records — a known zero or an
`unavailable` count is still a row, never an omission):
- `buildkit-size tokens record plan --feature <feature-id> --total <N> --method self-reported --model <model>`
  (self-report your token usage for this run; use `--input`/`--output` if known; omit all
  counts to record an `unavailable` 0). Advisory — ignore failures; never block (FR-010/SC-007).

5. **Check for extension hooks**: After reporting, check if `.specify/extensions.yml` exists in the project root.
   - If it exists, read it and look for entries under the `hooks.after_plan` key
   - If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
   - Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
   - For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
     - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
     - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
   - When constructing slash commands from hook command names, replace dots (`.`) with hyphens (`-`). For example, `buildkit.git.commit` → `/buildkit-git-commit`.
   - For each executable hook, output the following based on its `optional` flag:
     - **Optional hook** (`optional: true`):
       ```
       ## Extension Hooks

       **Optional Hook**: {extension}
       Command: `/{command}`
       Description: {description}

       Prompt: {prompt}
       To execute: `/{command}`
       ```
     - **Mandatory hook** (`optional: false`):
       ```
       ## Extension Hooks

       **Automatic Hook**: {extension}
       Executing: `/{command}`
       EXECUTE_COMMAND: {command}
       ```
   - If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

## Phases

### Phase 0: Outline & Research

1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:

   ```text
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

### Phase 1: Design & Contracts

**Prerequisites:** `research.md` complete

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Define interface contracts** (if project has external interfaces) → `/contracts/`:
   - Identify what interfaces the project exposes to users or other systems
   - Document the contract format appropriate for the project type
   - Examples: public APIs for libraries, command schemas for CLI tools, endpoints for web services, grammars for parsers, UI contracts for applications
   - Skip if project is purely internal (build scripts, one-off tools, etc.)

3. **Agent context update**:
   - Update the plan reference between the `<!-- BUILDKIT START -->` and `<!-- BUILDKIT END -->` markers in `CLAUDE.md` to point to the plan file created in step 1 (the IMPL_PLAN path)

**Output**: data-model.md, /contracts/*, quickstart.md, updated agent context file

## Key rules

- Use absolute paths for filesystem operations; use project-relative paths for references in documentation and agent context files
- ERROR on gate failures or unresolved clarifications

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool plan` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
