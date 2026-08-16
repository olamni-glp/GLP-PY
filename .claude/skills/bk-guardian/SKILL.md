---
name: "bk-guardian"
description: "Self-managed per-repo repo-health/integrity daemon. A single auto-ensured background process runs protective & policy modules on independent schedules to keep the PGlite catalog (the irreplaceable system of record) healthy and restorable: a portable logical catalog backup every 6h + a full cluster snapshot every 24h, retained/pruned/integrity-checked/verified-restorable; read-only health & integrity checks across catalog/DuckLake/spill/DBOS-state/schema-baseline/feature-drift/advisory-locks/events + git/version/CHANGELOG + CI/test/coverage, producing correlation-deduped severity-tagged findings; a curated set of idempotent, non-destructive auto-heal repairs (opt-out-able per repo); and an always-on critical-finding pipeline gate that refuses the next stage until the finding is resolved or an informed-consent override (briefing + explicit ack + rationale + scope/expiry) is recorded. Per-repo configurable with a relocatable backup dir, and a status/report surface also queryable via buildkit-co. Advisory & passive: never auto-invokes a /buildkit-* command and is NOT a canonical pipeline stage — its only ways to change observed state are declared opt-out-able repairs and the refusal gate. Hard-depends on buildkit-co for observability (every run/finding/remediation/backup/override is mirrored into the co lake), but core protection + the gate run air-gapped when co's heavy [co] extra is absent. Secrets are redacted before any persist or send; backups are local + gitignored; persistence is additive-only and never touches DBOS/pipeline-state."
argument-hint: "[a situation, e.g. 'is my catalog protected?'] | ensure-running | status | report | module [list|enable|disable|run|opt-out|opt-in] | coverage | findings | resolve <id> --note | gate status | override <finding_id> [--ack --rationale --scope] | backup [now|list|verify|restore|prune] | config [show|set|relocate|init] | install-hook"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-guardian.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). It is either a
natural-language situation ("is my catalog protected?", "why is the pipeline refusing to
start?", "restore yesterday's backup") or a `buildkit-guardian` subcommand. If empty,
summarise the surface below and ask what they want to do.

## What this does

`/bk-guardian` protects and audits the repo's own PGlite catalog and health. It is
**advisory & passive**: it **observes**, **backs up**, and (via the gate) **refuses** — it
**never** switches branches, edits source, pushes, mutates DBOS/pipeline-state, or
auto-invokes specify/clarify/plan/tasks/analyze/implement or any ship/roadmap command
(FR-033). Its only two ways to change observed state are (a) declared, opt-out-able,
idempotent **auto-heal repairs** and (b) the **refusal gate**. It is **NOT a canonical
pipeline stage** — do **not** call the sidecar `start`/`complete` for it.

This skill **conducts**; the deterministic `buildkit-guardian` CLI does the
daemon/backup/check/heal/gate/config work. Every subcommand supports `--json` and
`--project-root`.

## The surface

### Daemon lifecycle (single instance per repo)

- **`config init`** — bootstrap the `guardian_*` tables, seed the built-in modules + default
  config + co routes, write the DB-free backup-path pointer, ensure `.gitignore`. Idempotent.
- **`ensure-running`** — **idempotent, fail-safe, always exits 0**: (re)installs the OS-supervisor
  backstop and starts the daemon if no live instance holds the PID lock; a disabled repo is left
  alone. This is the session-start entry point.
- **`start [--foreground]` / `stop` / `disable` / `enable`** — lifecycle. `disable` removes the
  supervisor entry and blocks auto-ensure relaunch; `stop` leaves the entry intact.
- **`install-hook` / `uninstall-hook`** — register/remove a Claude Code SessionStart hook that runs
  `ensure-running` (the auto-launch surface). Offer to run `install-hook` on first setup.
- **`status` / `report`** — daemon health, per-module schedules + last-run outcomes, recent runs,
  open findings by severity, recent backups (with restore instructions), recent overrides, gate
  state, and a co-query hint.

### Protection (PGlite backups)

- **`backup now [--type logical|snapshot]`** — produce a backup now (consistent serialized read),
  integrity-check, verify restorable, record + emit.
- **`backup list [--type …]` / `backup verify <id>` / `backup prune`** — inspect / re-verify /
  apply the keep-last-N retention floor.
- **`backup restore <id> --yes`** — **destructive recovery** (the only path that replaces the live
  catalog incl. DBOS/pipeline-state); refuses without `--yes`; quiesces the daemon; verifies
  zero-loss post-restore. This is an explicit engineer recovery, distinct from normal operation.

### Modules, checks & coverage

- **`module list | enable <id> | disable <id> | run <id> [--force]`** — protective/policy modules on
  independent cadences; a disabled module records `skipped_by_config` runs.
- **`module opt-out <id> <repair_id>` / `module opt-in <id> <repair_id>`** — toggle a curated
  auto-heal repair per module.
- **`findings [--severity …] [--open]`** — correlation-deduped findings (identity =
  module+check+target); recurrences advance one open row, a materially-changed target supersedes the
  prior.
- **`resolve <finding_id> --note <text>`** — resolve a finding; a **critical** finding REQUIRES a
  note (mirrors co's human-in-the-loop close-gate).
- **`coverage`** — print the declared coverage taxonomy (every named store → covering module or an
  explicit `gap`); exits non-zero on any silent blind spot.

### Critical gate & informed-consent override (always-on)

- The gate is enforced by the pipeline **sidecar** before each stage start (not a subcommand): an
  unresolved **critical** finding refuses the next stage. A guardian *fault* fails open (never blocks
  the engineer); a *real* finding blocks in 100% of cases.
- **`gate status`** — read-only view: `engaged | overridden | cleared`.
- **`override <finding_id>`** — **step 1**: print the risk briefing + the confirm command (records
  nothing). Present that briefing to the engineer.
- **`override <finding_id> --ack <token> --rationale "<why>" [--scope finding_instance|one_time|session]`**
  — **step 2**: record the informed-consent override (briefing + ack + rationale + scope/expiry) and
  mirror it into co. A new/materially-changed critical finding requires a fresh override — there is
  no standing/blanket bypass, and the gate cannot be disabled by config.
- **`override list`** — recent overrides + scope/expiry/consumed state.

### Per-repo configuration

- **`config show`** — current config (enabled, backup_dir, retention, schedules, opt-outs,
  override-policy).
- **`config set [--enabled/--disabled] [--retention-json …] [--module-cadence <id>=<sec>] [--override-policy-json …]`**
  — validate + record (the critical gate is NOT a settable toggle).
- **`config relocate <dir> --yes`** — relocate the backup dir (validate → copy → verify → switch);
  an unwritable/missing target is refused cleanly and the prior location keeps serving.

## Querying guardian's records via buildkit-co

Every run/finding/remediation/backup/override is mirrored into buildkit-co under capability
`guardian`. Mine it two-phase without cross-capability bleed:

```
buildkit-co query --capability guardian [--severity critical] [--since …]
buildkit-co detail --id <obs_id> [--id …]
```

Guardian's own `guardian_*` tables remain the authoritative source of record (the gate reads them,
not co); co is the cross-tool observability surface.

## Advisory boundaries (non-negotiable)

- Passive observer: never mutate observed state except via declared opt-out-able auto-heal repairs
  and the refusal gate; never auto-invoke another `/buildkit-*` command; never call the sidecar
  (not a canonical stage).
- Fail-safe & non-blocking: a module/daemon/backend fault never crashes, blocks, or measurably slows
  foreground work or the pipeline; the gate fails open on a guardian fault but blocks a real critical
  finding.
- Auto-heal repairs are idempotent + non-destructive only; they never touch DBOS/pipeline-state or
  delete engineer data. Restore is an explicit `--yes` recovery, not a repair.
- Secrets are redacted before any persist or send; backups stay local + gitignored.
- Persistence is additive-only (the `guardian_*` tables); DBOS/pipeline-state is never touched.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-guardian` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
