---
name: "bk-push"
description: "Push primitive: commits any uncommitted work via /bk-commit then pushes the current branch. Sets upstream on first push (-u origin <branch>); never --force, never --force-with-lease. Composable inside /buildkit-ship."
argument-hint: "[-m <msg>] [--allow-secrets] [--allow-skip-hooks] [--dry-run] [--json]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-push.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-push` is the **push primitive** of the four shipping
surfaces. It pushes the current branch upstream — committing any
uncommitted work first by delegating to `/bk-commit`.

The skill is a thin delegation to the `buildkit push` CLI (FR-001).

### Behaviour

1. If the working tree is dirty, invokes `buildkit commit` with any
   forwarded flags (`-m`, `--allow-secrets`, `--allow-skip-hooks`).
   If commit refuses (exit `3`/`4`), push refuses with the same exit.
2. Determines the upstream:
   - If the branch has an upstream (`@{u}` resolves), pushes there.
   - Otherwise, pushes with `-u origin <current-branch>` to set the
     upstream on first push.
3. Runs `git push` (never with `--force` / `--force-with-lease`).
4. Prints the branch, upstream, and pushed sha.

## Run the CLI

```bash
buildkit push $ARGUMENTS
```

JSON form:

```bash
buildkit push --json $ARGUMENTS 2>push.json
```

JSON envelope is in `specs/016-shipping-skills/contracts/push-cli.md`.

## Exit codes

- `0` — pushed (or nothing to push).
- `2` — no `origin` remote / detached HEAD.
- `3` — commit refused (secrets without `--allow-secrets`, etc.).
- `4` — `git push` rejected (non-fast-forward, branch protection).
  Stderr propagated. Resume hint: `pull/rebase first or resolve manually
  — never --force`.

## Per-stage token record (spec-020 FR-010 — advisory, non-blocking)

This is a mechanical (no-LLM) stage — record a **known zero** (FR-010 edge: a zero is a row,
not an omission; distinct from `unavailable`):
- `buildkit-size tokens record push --total 0 --method measured` (add `--feature <feature-id>` if a feature is active).
Advisory — ignore failures; never block.

## Notes

- For force-push intent, use plain `git push --force-with-lease` —
  `/bk-push` deliberately does **not** expose force semantics
  (FR-006).
- For the full conductor pipeline (push → PR → merge → release → tag
  → back-merge), use `/bk-ship`.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-push` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
