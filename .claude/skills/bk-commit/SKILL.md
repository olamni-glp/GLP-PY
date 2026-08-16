---
name: "bk-commit"
description: "Single-commit primitive: derives a feat/fix/docs/test/chore commit message from the working-tree diff, refuses on secret-pattern paths, never bypasses git hooks unless asked. Composable inside /bk-push and /bk-ship — usable on its own mid-feature."
argument-hint: "[-m <msg>] [--allow-secrets] [--allow-skip-hooks] [--dry-run] [--json]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-commit.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-commit` is the **commit primitive** of the four shipping
surfaces (`/bk-commit`, `/bk-push`, `/bk-release`,
`/bk-ship`). It creates **one** new git commit from the working
tree, with a derived commit message and a built-in refusal on staged
secrets.

The skill is a **thin delegation** to the `buildkit commit` CLI — all
logic lives in `src/buildkit_cli/ship/commit.py` (FR-001). The skill's
job is to invoke the CLI in `--json` mode, render the result for the
engineer, and surface the exit code.

### Behaviour

1. Reads `git status --porcelain` to discover the working-tree diff.
2. If the tree is clean, exits `0` with `nothing to commit`.
3. Applies the `secret_patterns` filter (FR-009 — defaults: `.env`,
   `.env.*`, `credentials*.json`, `*.key`, `*.pem`, `id_rsa*`, `*.p12`,
   `*.pfx`, `secrets/*`). On any hit and no `--allow-secrets`, refuses
   with exit `3` and the offending paths.
4. Derives a `<type>(#<feature-id>): <summary>` message from the diff
   (research §R6 heuristic — `feat` for new src/, `fix` for modified
   src + new tests, `test`, `docs`, `chore`), unless `-m` is supplied.
5. Stages everything (`git add -A`), runs `git commit` (with
   `--no-verify` only if `--allow-skip-hooks` is set, surfacing a
   warning).
6. Prints the new commit sha + first line of the message.

## Run the CLI

```bash
buildkit commit $ARGUMENTS
```

Pass `--json` to get the structured envelope on stderr:

```bash
buildkit commit --json $ARGUMENTS 2>commit.json
```

The JSON envelope shape is in
`specs/016-shipping-skills/contracts/commit-cli.md`.

## Exit codes

- `0` — commit created (or clean tree, nothing to do).
- `1` — usage error.
- `2` — not in a git repo / detached HEAD.
- `3` — secret-pattern paths staged and no `--allow-secrets`.
- `4` — `git commit` failed (hook rejection, etc.); stderr verbatim.

## Per-stage token record (spec-020 FR-010 — advisory, non-blocking)

This is a mechanical (no-LLM) stage — record a **known zero** (FR-010 edge: a zero is a row,
not an omission; distinct from `unavailable`):
- `buildkit-size tokens record commit --total 0 --method measured` (add `--feature <feature-id>` if a feature is active).
Advisory — ignore failures; never block.

## Notes

- This skill never passes `--admin`, `--force`, or `--no-verify` unless
  the engineer explicitly opts in via `--allow-skip-hooks` (and even
  then surfaces a warning).
- Use `/bk-push` to commit-then-push in one step; use
  `/bk-ship` to commit, preflight, push, open a PR, merge it, cut
  the release, tag, and back-merge in one step.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-commit` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
