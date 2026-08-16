---
name: "bk-opskit-tagging"
description: "BK-OpsKit tagging: the baseline AWS asset tagging schema — load the canonical schema document, certify the baseline against the constitution + goldens, and validate asset tag sets (pure, side-effect-free, no-event hot path; DB-backed rule kinds degrade to an explicit org_enum_unavailable finding when the baseline is absent — never a silent pass). Advisory — never switches branches, blocks a merge, or auto-invokes a buildkit-* command (FR-027)."
argument-hint: "load [--project-root <p>] | certify [--project-root <p>] | validate --tags <json> --context <json> [--schema <file>] [--json]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-opskit-tagging.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-opskit-tagging` is the tagging surface of BK-OpsKit (round-trips to
`buildkit-opskit tagging`). It owns the certified tag-schema baseline: `load` brings the
canonical schema document into buildkit's catalog, `certify` checks the baseline against
the constitution + goldens, and `validate` checks an asset's tag set against the
certified rules — a pure, side-effect-free hot path that emits **no** events. When a
DB-backed rule kind (org_sourced_enum / cost_allocation) has no persisted baseline, the
result is an explicit `org_enum_unavailable` finding — never a silent pass, never a crash.

## How to run it

```
buildkit-opskit tagging load
buildkit-opskit tagging certify
buildkit-opskit tagging validate --tags <tags-json> --context <context-json>
buildkit-opskit tagging validate --tags <tags-json> --context <context-json> --schema <schema-file>
```

`--project-root <p>` overrides artifact resolution for load/certify; `--schema <file>`
is the explicit test/override seam (a pure caller needs no engine); `--json` on every
subcommand emits machine-readable output. Schema-supplied regexes are structurally
screened against ReDoS at the choke-point before compilation.

## Exit codes (ratified S4 contract)

- `0` — success (a validate run with findings still exits 0 — findings are data).
- `1` — usage error / malformed input (bad JSON shapes, malformed schema).
- `2` — refusal or environment error (missing artifact, uncertifiable baseline).

## Boundaries (do NOT) — FR-027

- Advisory only: auto-invokes **no** buildkit-* pipeline command; switches **no** git branch.
- `validate` is pure and emits no events; nothing here calls AWS.
- Baseline rows land additively in buildkit's PGlite catalog; outputs secret-redacted (FR-024).

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-opskit` from the project root — it
always exits 0 (fail-safe; never blocks). Ignore its output.
