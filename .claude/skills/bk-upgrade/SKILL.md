---
name: "bk-upgrade"
description: "Migrate a legacy speckit-branded project to buildkit naming, and upgrade an existing buildkit project's installed artifacts to a chosen version (from a source repo/ref/path or in-place). Safe by default: branch + opaque catalog backup before any mutation, dry-run preview, idempotent, never wipes DBOS state."
argument-hint: "[status|migrate|apply] [--target <dir>] [--dry-run] [--source repo|local|in-place] [--ref <git-ref>] [--source-path <dir>] [--yes]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-upgrade.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-upgrade` is the project self-upgrade & legacy-migration tool
(feature 008). It does two things, both **safe by default**:

1. **migrate** — rename a legacy `speckit`-branded project to `buildkit`
   (skills, `.specify/` trees, manifests, workflow-registry, scripts,
   templates, docs), reusing feature-002's litigated token rules and
   justified-exclusion classes. User-authored specs/constitution are never
   rewritten.
2. **apply** — refresh an already-buildkit project's installed artifacts to a
   chosen buildkit version, from a source repo/ref, a local checkout, or
   in-place from the project's own bundled `buildkit_cli` (no network).

Every non-dry-run mutation is preceded by: a git-repo check (refuse if not), a
fresh feature branch in the target, and a **timestamped, non-overwriting**
opaque backup of the live workflow catalog (`.opskit-pglite`/`pgdb`/state).
The catalog is never parsed, pruned, or deleted.

## Outline

1. **Status first (read-only)**: run
   `python -m buildkit_cli.upgrade status --target <dir>` and report
   `installed_kind`, git state, and detected catalog paths.
2. **Preview**: run the same `migrate`/`apply` command with `--dry-run`. This
   performs **zero** writes, creates no branch, and no backup. Present the
   full plan (renames, rewrites, token count, exclusions) to the operator.
3. **Confirm**: surface the branch that will be created and the backup
   location, and the dirty-tree state, before proceeding. If the target has
   uncommitted changes, stop unless the user passes `--yes`.
4. **Apply**: on explicit confirmation, run the real
   `python -m buildkit_cli.upgrade {migrate|apply} --target <dir> [--source …
   --ref …]`. Then echo the completion `RunReport` verbatim (result, files
   changed, tokens replaced, backup dir, branch, source).
5. **Idempotent**: re-running on an already-migrated/current project reports
   `result=noop` and changes nothing.

Exit discipline: 0 success/no-op, 1 refused (non-git / uncommitted / usage),
2 unexpected error. `--dry-run` always exits 0.

## Reversal

`git checkout <prior-branch>` in the target, then restore from
`<target>/.buildkit-upgrade-backup/<UTC>/` if catalog/state recovery is needed.
The tool never performs destructive cleanup itself.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-upgrade` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
