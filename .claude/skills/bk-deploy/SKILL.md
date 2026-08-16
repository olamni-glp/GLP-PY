---
name: "bk-deploy"
description: "Out-of-repo deployment + per-machine install registry. Owns a single shared deployment home OUTSIDE any repo (a per-user home under the OS user-data dir by default) into which buildkit versions install under versioned dirs (<home>/versions/<version>/), keeps each target repo's heavy operational data (PGlite catalog + DuckLake lake) under <home>/targets/<hash>/ (never in the repo, which retains only its .specify/ config), and maintains a per-machine registry of every repo (target) on the host where buildkit is installed/activated, pinning each to a chosen installed version. Lifecycle: deploy (install + register, idempotent re-deploy) | list (enumerate targets) | version (home + installed versions + default) | home / home --set (print / relocate the shared home) | latest all|<repo> (advance to newest installed) | tidy (dry-run-by-default prune of orphaned versions + confirmation-gated per-target de-install). Mirrors every registry-affecting event into buildkit-co (capability 'deploy') fail-safe. Advisory & passive: never auto-invokes a /buildkit-* command, the sidecar, or a target's buildkit run; secrets are redacted before persist/mirror; persistence is additive-only and never touches DBOS/pipeline-state; the PGlite registry is authoritative, co is observability only."
argument-hint: "[a request, e.g. 'deploy this repo' or 'where is my home?'] | deploy [--version <v>] [--source-mode artifact|checkout|source_ref] [--note <t>] | list [--json] | version [--json] | home [--set <path>] [--json] | latest all|<repo> [--json] | tidy [<repo>] [--remove-data] [--apply] [--json]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-deploy.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). It is either a
natural-language request ("deploy this repo", "where is my deployment home?", "move the home
to D:\\buildkit", "upgrade everything to the latest", "clean up old versions") or a
`buildkit-deploy` subcommand. If empty, summarise the surface below and ask what they want.

## What this does

`/bk-deploy` makes buildkit's install location a **shared, versioned, out-of-repo**
home and keeps a **per-machine registry** of the repos that use it. It is **advisory &
passive**: it installs files and pins versions but **never** runs a target's buildkit, never
invokes specify/clarify/plan/tasks/analyze/implement or any ship/roadmap command, and adds
**no** sidecar/pipeline hook (the key divergence from buildkit-guardian).

- **Shared out-of-repo home** — resolved **DB-free** with precedence
  `BUILDKIT_DEPLOY_HOME` env → per-machine pointer `<user-data>/buildkit/deploy-home.path`
  → per-user default `<user-data>/buildkit/deploy-home/`. The repo keeps only `.specify/`;
  the PGlite catalog + DuckLake lake live under `<home>/targets/<hash>/` (0 install/DB bytes
  in the repo working tree).
- **Authoritative registry** — the additive `buildkit.deploy_*` PGlite tables are the system
  of record (home, installed versions, targets, events, config, relocations). Every
  registry-affecting event is **also** mirrored into buildkit-co (capability `deploy`)
  fail-safe — a missing `[co]` extra or a lake outage never blocks a deploy/list/tidy.
- **Idempotent + safe** — re-deploy of a complete version is a no-op; mutating commands
  serialise on a single per-home advisory lock (reads take none); a target is never
  hard-deleted (vanished path → `missing`, de-install → `deinstalled` tombstone, re-deploy
  reactivates the same canonical-path row); relocation uses validate → copy → verify →
  switch → record and refuses cleanly (prior home still serving) on any failure.

## Subcommands

Run the console script `buildkit-deploy <subcommand>` (exit `0` success/no-op/dry-run,
`1` refused/usage, `2` DB unavailable). Every command supports `--json` (a single
`"schema_version":"1"` document to stdout, nothing else). Global options:
`--project-root PATH` (the target repo), `--home PATH` / `BUILDKIT_DEPLOY_HOME` (override
the home).

- **`deploy [--version V] [--source-mode artifact|checkout|source_ref] [--source-path P]
  [--note T]`** — install version `V` (default: this buildkit's version) into the shared
  home and register/reactivate the current repo as a target pinned to it. Idempotent.
  *Mutating — takes the lock.*
- **`list`** — enumerate every registered target on this machine (canonical path, pinned
  version, status, last-deployed), ordered by canonical path; a vanished repo path shows
  `missing`. *Read-only — no lock.*
- **`version`** — report the resolved home, every installed version, and the current default
  (greatest CalVer among integrity-complete; non-CalVer dirs surfaced `calver:false`).
  *Read-only — no lock.*
- **`home` / `home --set PATH [--note T]`** — print the active home (DB-free) / relocate it
  (validate → copy → verify → switch → record). *Print is read-only; `--set` is mutating.*
- **`latest all` / `latest <repo>`** — re-pin every active target / one named target to the
  newest installed version (CalVer ordering, not wall-clock). Already-latest is a clean
  no-op. *Mutating — takes the lock.*
- **`tidy [--apply]` / `tidy <repo> --remove-data [--apply]`** — **dry-run by default**:
  preview the removal set and mutate nothing. `--apply` prunes orphaned version dirs
  (keep-current + keep-last-N floor, never a version pinned by an active target); the
  `<repo> --remove-data` form de-installs a named target and removes **only** that target's
  store. Data removal is never implicit. *Mutating — takes the lock.*

## Advisory boundaries (FR-022/023/024)

- **Never** auto-invokes a `/buildkit-*` pipeline command, the sidecar, or a target's
  buildkit run.
- **Fail-safe observability** — the buildkit-co mirror degrades to a no-op/spill under any
  outage; the PGlite registry remains authoritative.
- **Secret-redacted + additive-only** — every persisted free-text field (notes, paths) is
  scrubbed via `codify.redact`; persistence adds only `deploy_*` tables (migration 0018) and
  never touches DBOS/pipeline-state (resumability sacred).

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-deploy` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this tool).
Ignore its output.
