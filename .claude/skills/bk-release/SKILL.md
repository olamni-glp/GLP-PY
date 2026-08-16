---
name: "bk-release"
description: "Standalone release cut — release-branch → pyproject bump (different-day) → CHANGELOG stamp → release PR → tag → back-merge PR. Use when develop is already ahead of main and you want to cut a version without a fresh feature PR (e.g. after a hotfix landed via a manual PR)."
argument-hint: "[--from-branch <branch>] [--no-edit] [--allow-empty-changelog] [--dry-run] [--json]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-release.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-release` is the **release primitive** of the four shipping
surfaces — `buildkit ship` minus the feature-PR prefix. Use it when
`develop` is already ahead of `main` (e.g. a hotfix landed via a
manual PR, or you're cutting an interim release of accumulated
develop commits).

The skill is a thin delegation to the `buildkit release` CLI (FR-001).
All logic lives in `src/buildkit_cli/ship/release.py`.

### What it does, in order

1. Pre-checks: `gh` available + authenticated; tag conflict pre-check.
2. Compute ShipPlan (no feature-id; sourced from current branch).
3. Short-circuit: `git rev-list main..develop` empty → exit `0`
   with the message *"develop is at the same commit as main; no
   changes to release"*.
4. Checkout `develop` (or `--from-branch`); pull `--ff-only`.
5. Cut `release/v<calver>` (idempotent).
6. Bump `pyproject.toml` version (different-day only — same-day
   re-ships leave it alone).
7. CHANGELOG: seed `[Unreleased]` from commits since the last tag
   if empty (FR-004a) → opens `$EDITOR` unless `--no-edit`; stamp
   `[Unreleased]` → `[v<calver>] - YYYY-MM-DD`; re-insert empty
   `[Unreleased]` above.
8. Commit `release: v<calver>` on the release branch.
9. Push release branch (sets upstream on first push).
10. Open release PR `--base main --head release/v<calver>`
    (idempotent: reuses existing).
11. Merge release PR.
12. `git tag -a v<calver> -m "Release v<calver>"` and push the tag.
13. Open back-merge PR `--base develop --head main` (idempotent).
14. Merge back-merge PR.
15. Reinstall CLI (`pip install -e .[refine]`, falls back to `-e .`);
    failure → exit `5` (warning), not `4`.

## Run the CLI

```bash
buildkit release $ARGUMENTS
```

JSON form:

```bash
buildkit release --json $ARGUMENTS 2>release.json
```

JSON envelope is in `specs/016-shipping-skills/contracts/release-cli.md`.

## Exit codes

- `0` — released (or no changes to release; or `--dry-run`).
- `1` — usage error.
- `2` — environment error (no `gh`, …).
- `3` — pre-condition (empty `[Unreleased]` without `--allow-empty-changelog` or `--no-edit`).
- `4` — mid-workflow failure (tag conflict, merge blocked, …).
- `5` — post-step warning (CLI reinstall failed).

## Per-stage token record (spec-020 FR-010 — advisory, non-blocking)

This is a mechanical (no-LLM) stage — record a **known zero** (FR-010 edge: a zero is a row,
not an omission; distinct from `unavailable`):
- `buildkit-size tokens record release --total 0 --method measured` (add `--feature <feature-id>` if a feature is active).
Advisory — ignore failures; never block.

## Notes

- This is the standalone-release surface. For the full pipeline
  (feature-PR prefix + release), use `/bk-ship`.
- `--from-branch` lets you cut a release from any branch (default:
  `develop`).
- The "develop ≡ main" short-circuit means it's safe to run
  speculatively — no work happens if there's nothing to release.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-release` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
