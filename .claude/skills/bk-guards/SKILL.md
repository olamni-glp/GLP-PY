---
name: "bk-guards"
description: "Advisory, read-only shift-left toolchain integrity guards (spec-053). One capability, three independently-runnable sub-checks plus a combined pass: template-contract (a skill template's documented CLI steps vs. the live-introspected CLI contract — unknown subcommand/flag, out-of-order step, missing-producer artifact), enforcement (CLI args and persisted state fields that are declared but never read/enforced), and threat-model (security/integrity-critical guards, marked by an explicit machine-readable marker, whose spec lacks an enumerated threat model of {conditions, evidence, evasions}). Emits a structured JSON report + human summary with honest per-target coverage. Advisory by default (never gates a stage unless a finding is explicitly opted into a gate) and read-only w.r.t. code/templates/specs/git/DBOS state; never auto-invokes a pipeline command (FR-010/FR-011)."
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-guards.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-guards` runs advisory, read-only integrity guards over the buildkit toolchain so
implementation-vs-contract drift and declared-but-unenforced gaps are caught at implement time
rather than during review. It **never** mutates the artifacts it inspects and **never**
auto-invokes another `/buildkit-*` command — you run the recommended fix yourself.

## Surface

Run everything (combined pass over the whole toolchain):

```
buildkit-guards check --all          # human summary; exit 0 clean / 1 findings / 2 env error
buildkit-guards check --all --json   # structured envelope for analyze/review surfaces
```

Run one guard:

```
buildkit-guards template-contract --template .claude/skills/bk-marathon/SKILL.md
buildkit-guards enforcement --target buildkit-marathon
buildkit-guards threat-model --spec specs/053-toolchain-integrity-guards/spec.md
```

Global options (any subcommand, before or after it): `--json`, `--quiet`, `--repo-root PATH`.

## Exit codes (advisory)

- `0` — clean or not-applicable
- `1` — findings present (advisory signal only; does not gate a stage unless you opt a finding into a gate)
- `2` — environment / usage error

A coverage gap (a unit that could not be parsed) is reported in-band and never by itself forces a
non-zero exit — so a clean result never masks an unchecked unit (SC-006).

## Boundaries

Advisory & read-only. It analyzes and reports; it does not switch branches, edit source, write the
catalog, or auto-invoke a pipeline command. Turning any finding into a hard gate is an explicit,
opt-in engineer choice (FR-010).
