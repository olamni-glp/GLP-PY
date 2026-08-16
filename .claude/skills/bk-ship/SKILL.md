---
name: "bk-ship"
description: "End-to-end shipping conductor: commit any pending work, run preflight, push, open a feature PR, merge it, cut a release branch, bump pyproject (different-day only), stamp CHANGELOG, push the release PR, merge it, tag, back-merge main→develop, and reinstall the CLI. One command per ship. Idempotent — re-run after a mid-workflow failure picks up where it left off."
argument-hint: "[-m <msg>] [--force] [--skip-preflight] [--allow-secrets] [--no-edit] [--dry-run] [--json]"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-ship.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-ship` is the **end-to-end shipping conductor** — the top of
the four shipping surfaces. It codifies the ~20-step manual GitFlow +
CalVer recipe every feature 012-015 walked by hand. One command:
feature lands on `main` as a tagged release with `develop` back-merged.

It is **unified, verified, and resumable** (spec-033):

- **Unified / non-blocking** — the default path drives feature-PR → merge →
  release → tag → back-merge → reinstall in a *single* invocation. The two
  documented mid-flow stops are gone: an empty CHANGELOG `[Unreleased]` is
  auto-seeded from the commit range and the flow proceeds non-interactively
  (even under `--no-edit`); the different-day-only pyproject bump policy is
  unchanged. Real blockers still stop with clarity (see below).
- **Verified** — after the flow runs, ship *observes* the resulting
  git/PR/tag/back-merge/CLI state and reports overall success **only when every
  required outcome is confirmed**. "Success" never means merely that a
  subprocess exited zero.
- **Resumable** — re-invoking after a stop recomputes the plan and skips any
  stage whose verification already passes; the verification pass is itself the
  resume oracle. No new state, no run-ledger (state is observed from git/gh).

The skill is a thin delegation to the `buildkit ship` CLI (FR-001).
All logic lives in `src/buildkit_cli/ship/ship.py`; the read-only verification
observers live in `src/buildkit_cli/ship/verify.py`.

> The short twin `/bk-ship` (spec-031) behaves identically — it is a
> byte-identical alias derived at setup, so every enhancement here applies to it
> automatically.

### What it does, in order

1. **Pre-check**: not on a feature branch / no remote / no `gh` /
   no `.specify/feature.json` → refuse cleanly (exit `2`).
2. **Compute ShipPlan**: branch, feature id, next CalVer tag, next
   pyproject version, release branch name, PR titles. Logged verbatim
   under `--dry-run`.
3. **Pipeline-state advisory check** (FR-008): refuses if `implement`
   ≠ `complete` unless `--force` is set. Warns + skips if
   `pipeline.cli status` is unreachable (FR-007 fail-safe).
4. **Secrets scan** (FR-009): refuses on `.env`/`*.key`/etc. paths
   unless `--allow-secrets` is set or `ShipConfig.auto_allow_secrets`
   is true.
5. **Commit** (if dirty): delegates to `buildkit commit` with the
   derived `<type>(#<feature-id>): <summary>` message — or `-m` if
   given.
6. **Preflight** (FR-005a): runs each `ShipConfig.preflight_commands`
   entry; non-zero exit refuses unless `--skip-preflight`.
7. **Push**: sets upstream on first push, runs `git push`. Never
   `--force` / `--force-with-lease`.
8. **Feature PR**: idempotent — reuses an open or merged PR if
   present, otherwise `gh pr create --base develop --head <branch>`.
9. **Merge feature PR**: `gh pr merge <PR#> --merge` (or
   squash/rebase per `pr_merge_style`). Refuses if branch
   protection blocks; re-run resumes from this step.
10. **Cut release branch**: `release/v<calver>` from `develop`
    (idempotent).
11. **Bump pyproject.toml** version — *only on a different-day ship*.
    Same-day re-ships leave pyproject alone; the `-N` suffix lives only
    on the tag and CHANGELOG entry.
12. **Stamp CHANGELOG**: if `[Unreleased]` is empty, **auto-seed it from
    the commit range and proceed non-interactively** (no editor stall, no
    `changelog_empty` exit — even under `--no-edit`; spec-033 D-004); then
    move `[Unreleased]` → `[v<calver>] - YYYY-MM-DD` and re-insert an empty
    `[Unreleased]` above. The only remaining stop is the genuinely-unseedable
    case (no commits at all), which still asks for `--allow-empty-changelog`.
13. **Commit release-prep**: `release: v<calver>` on the release
    branch.
14. **Push release branch**.
15. **Release PR**: `--base main --head release/v<calver>` (idempotent).
16. **Merge release PR** → main now holds the release.
17. **Tag**: `git tag -a v<calver> -m "Release v<calver>"` then push
    the tag. Refuses on tag conflict (re-run not safe — manual
    cleanup required).
18. **Back-merge PR**: `main → develop`. Mandatory per
    `docs/BRANCHING.md` — carries the version bump + CHANGELOG stamp
    back to `develop`.
19. **Merge back-merge PR**.
20. **Reinstall CLI**: `pip install -e .[refine]` (falls back to `-e .`).
    Failure → exit `5` (warning), not `4` — workflow succeeded but
    local CLI is stale.
21. **Verification gate** (spec-033 FR-002/FR-005): a read-only pass observes
    the actual state — feature PR merged, release PR merged, tag present
    (local **and** remote), back-merge landed (`origin/main` fully contained in
    `origin/develop`), and CLI reinstalled — and ship reports overall success
    **iff every required outcome is confirmed**. A required outcome that ran but
    didn't land (e.g. a missing tag or an un-landed back-merge) ⇒ exit `4`
    naming the stage. The five observed outcomes are printed in the final report
    (and serialized into the `--json` envelope's `verifications` array).

## Run the CLI

```bash
buildkit ship $ARGUMENTS
```

JSON form:

```bash
buildkit ship --json $ARGUMENTS 2>ship.json
```

JSON envelope is in `specs/016-shipping-skills/contracts/ship-cli.md`.

## Post-ship reconciliation — offer-and-apply (spec-042, advisory)

**Only after a fully-successful ship** (exit `0`, or exit `5` which is still success). A ship that
failed (exit `2`/`3`/`4`) or a `--dry-run` offers **nothing**. A successful ship already surfaces the
three reconciliation gaps in its report (and the `--json` envelope's `reconciliation` array) for the
record; this step lets the engineer act on them. It is **advisory and additive**: declining any offer,
or any failure within it, never changes the ship's reported success.

Re-detect the same gaps (one shared engine, read-only — zero mutations):

```bash
buildkit ship reconcile --json
```

For each gap with `status == "present"`, present it to the engineer (AskUserQuestion: **Run now** /
**Decline**) and, on accept, run that gap's `recommended_command`, then record the decision:

- **close_out** — run `buildkit-retrospective run <feature_id>` then
  `buildkit-retrospective report <retro_id>` (deterministic capture), and **recommend** the full
  guided `/bk-close` for interactive action reconciliation. **Never** auto-invoke `/bk-close`
  (Constitution I / FR-002).
- **roadmap_advance** — run `python -m buildkit_cli.roadmap advance <roadmap_feature_id> --to released`
  (the `recommended_command` carries the resolved id). A `not_applicable` gap (no roadmap entry, e.g. a
  hotfix) is skipped with a one-line note.
- **sidecar_implement** — run `python -m buildkit_cli.pipeline.sidecar reconcile implement`. An
  `unknown` gap (pipeline bridge unavailable) is skipped (US3.3).

Record each engineer decision (fail-safe; never blocks):

```bash
buildkit ship reconcile record --gap <close_out|roadmap_advance|sidecar_implement> \
  --decision <accepted|declined|skipped|errored> [--note "<why>"]
```

If every gap is `already_done`/`not_applicable`, report **"nothing to reconcile"** and continue.
A **non-interactive** ship (no engineer to confirm) is **surface-only** — the gaps are reported but
nothing is applied (declining is the safe default). The standalone `buildkit ship reconcile` (and
manual `/bk-close` + `roadmap advance`) remain the do-it-later fallback (FR-012).

### Reconciliation advisory boundaries (non-negotiable)

- **Offer, never auto-apply**: each reconciliation runs **only on explicit engineer confirmation**;
  the `buildkit ship` CLI never prompts and never auto-applies (FR-011).
- **Never auto-invoke** a `/buildkit-*` pipeline command; `/bk-close` is **recommended**, never run
  (Constitution I / FR-007).
- **Additive only** — all writes go through the existing additive CLIs and the additive
  `sidecar reconcile implement`; no existing record is mutated or removed (Constitution II / FR-006).
- Idempotent — re-running on an already-reconciled feature is a no-op (FR-008); secrets are redacted
  before the decision audit is persisted (Constitution V / FR-009).

## Exit codes

- `0` — success (or `--dry-run` printed the plan).
- `1` — usage error.
- `2` — environment error (no `gh`, no remote, not on feature branch, …).
- `3` — pre-condition failed (pipeline-state gate, secrets, …).
- `4` — mid-workflow failure (push rejected, PR merge blocked, tag
  conflict) **or a final verification that failed** (a stage ran but its
  observed outcome is missing — e.g. tag absent, back-merge not landed).
  Resume hint emitted; **re-run is safe** in most cases (tag conflict needs
  manual cleanup).
- `5` — post-step warning (CLI reinstall failed). Ship succeeded;
  local CLI is stale.

## Idempotency & resumability

Every step probes "is this already done?" via `git`/`gh` reads, and the final
verification pass is the resume oracle: re-running after a mid-workflow stop
recomputes the plan and skips any stage whose observed state already satisfies
its verification — no duplicate PRs, branches, or tags. State is observed, never
stored (no run-ledger; spec-033 FR-003).

## Per-stage token record (spec-020 FR-010 — advisory, non-blocking)

This is a mechanical (no-LLM) stage — record a **known zero** (FR-010 edge: a zero is a row,
not an omission; distinct from `unavailable`):
- `buildkit-size tokens record ship --total 0 --method measured` (add `--feature <feature-id>` if a feature is active).
Advisory — ignore failures; never block.

## Notes

- Use `/bk-release` to cut a release without a feature PR prefix
  (for hotfixes that landed via manual PR).
- Use `/bk-commit` or `/bk-push` for the lower-layer
  primitives mid-feature.
- The `--dry-run` plan output is exactly what the live ship will do —
  paste it into the PR description.

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-ship` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
