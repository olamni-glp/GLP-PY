---
name: "bk-registry"
description: "Maintained, reviewed, dual-persisted capability registry + documentation integrity. Seeds Build-Kit's capability→epic→feature→story→issue(release-note) map from the repository into two synchronized sinks — a git-tracked JSON floor (.specify/registry/capabilities.json, authoritative on divergence) + an additive PGlite catalog mirror — reproducing the current map with zero manual transcription and byte-identical re-seeds. Kept current by a fail-safe per-skill touch (a file-marker dirty bit, no PGlite boot) wired into every in-scope buildkit-* skill/tool, and reconciled + drift-reviewed every cycle (both-direction drift: installed_only / registry_only, plus completeness gaps). On ship/release the delimited generated regions of the README capability section, the capability-hierarchy doc, and a release-note view are regenerated from the registry and committed, blocking only on an unresolvable conflict (a hand edit inside a generated region). Advisory & passive: never auto-invokes a /buildkit-* command and never edits source outside hash-delimited generated regions. Secrets are redacted before any persist; persistence is additive-only and never touches DBOS/pipeline-state; the JSON floor works air-gapped (pending_sync) with the catalog deleted."
argument-hint: "[a request, e.g. 'what drifted this cycle?'] | seed [--force] | review [--json] [--strict] | export [--check] [--strict] | status [--json] [--version <v>] | reconcile [--strict] | touch --tool <name>"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-registry.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). It is either a
natural-language request ("what drifted this cycle?", "seed the registry", "what shipped in
v2026.06.06.4?", "regenerate the docs") or a `buildkit-registry` subcommand. If empty, summarise
the surface below and ask what they want to do.

## What this does

`/bk-registry` makes Build-Kit's capability map a **maintained, reviewed, dual-persisted
source of truth** and binds documentation to it. It is **advisory & passive**: it **observes**,
**reconciles**, and **regenerates delimited doc regions** — it **never** switches branches, edits
source outside `BEGIN/END GENERATED` regions, pushes, mutates DBOS/pipeline-state, or auto-invokes
specify/clarify/plan/tasks/analyze/implement or any ship/roadmap command (FR-007).

- **Dual sink** — the git-tracked JSON floor `.specify/registry/capabilities.json` is
  **authoritative on divergence**; the PGlite catalog mirror is a disposable, rebuildable query
  layer. With the catalog deleted, every read serves from JSON and reports `pending_sync` (SC-004).
- **Hybrid authority** — capability/epic taxonomy and curated stories are human-authored &
  authoritative; feature/version/issue/installed-tool facts are auto-derived & reconciled.
  Reconcile never overwrites a `human` node with derived data.
- **Kept current** — a fail-safe **touch** (a file-marker dirty bit, no PGlite boot, always exit 0)
  runs inside every in-scope `buildkit-*` skill/tool; the cycle-boundary `review`/`reconcile`
  consume it and recompute drift from ground truth.

## Subcommands

- `seed [--force]` — build the hierarchy from the repo (specs/, CHANGELOG, git tags, scripts,
  templates, help inventory) + the human taxonomy, write the JSON floor, heal the catalog mirror.
  Idempotent: an unchanged repo re-seeds byte-identically.
- `review [--json] [--strict]` — per-cycle drift (`installed_only` / `registry_only`) + completeness
  gaps + a no-write doc-delta preview. **Advisory**: exit 0 for `in_sync` **and** `drift`; exit 2
  for `conflict`; `--strict` makes drift exit non-zero.
- `export [--check] [--strict]` — deterministically regenerate the generated doc regions; `--check`
  compares only (the mode ship/release use). Byte-identical on an unchanged registry.
- `status [--json] [--version <v>]` — counts + sync state; `--version` answers "what shipped in
  version X, and which is missing a story or a release-note?" from the JSON floor alone.
- `reconcile [--strict]` — heal the catalog mirror from the authoritative JSON floor.
- `touch --tool <name>` — the fail-safe dirty-bit (you never call this by hand; the skills run it).

## Advisory boundaries

Never auto-invokes a pipeline command; edits only hash-delimited generated regions (prose outside is
never read or written); the per-skill touch can never block, slow, or change a host stage's outcome;
persistence is additive-only and never touches DBOS/pipeline-state; secrets are redacted before any
persist; the only default ship block is a hand-edit inside a generated region.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-registry` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
