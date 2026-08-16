---
name: "bk-owo"
description: "OWO mapping plugin: classify every class and relationship of a target OWL ontology across the 12 Olamni World Ontology dimensions, level by level — an engineer-in-the-loop `map` interview (optionally assisted by a pre-checked predictor estimate), an `automap` draft predictor, per-term append-only versioning with complete provenance, a coverage ledger with resume, corroboration-provider feedback, SSSOM/Markdown export, and an optional GEPA/DSPy fidelity-gated optimization loop. Advisory & human-gated: nothing becomes authoritative without the engineer's recorded approval; the source ontology and owo.ttl are never mutated."
argument-hint: "[map|automap|approve|coverage|history|export|corroborate|optimize|status] [--target <ontology>] [--term <IRI>] …"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-owo.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## What this does

`/bk-owo` maps any OWL ontology onto the **Olamni World Ontology (OWO)**: for **every class
and every object property**, one classification in **each of the 12 OWO dimensions, level by
level**. Level 0 (`owo:object`) is implicit and **never recorded**. A dimension that does not
apply is recorded once as a **level-1 Mapping-Undefined → `owo:UNDEFINED`** (a mapping-layer
sentinel, never added to `owo.ttl`), with a required reason — undefined at level 1 implies
undefined at every deeper level. Every mapping is **versioned per term** (append-only,
content-hash idempotent) and carries **complete provenance** (source, method, author, machine,
date, tool + OWO + target versions).

The skill is the conversational front; the deterministic tool is the `buildkit-owo` console
script. **Advisory only / never auto-invoke**: this skill never invokes another `/buildkit-*`
pipeline command, and NOTHING becomes authoritative without the engineer's recorded approval.

## Backbone resolution

Every backbone-dependent action needs `--owo <path-to-owo.ttl>` (or the `BUILDKIT_OWO_TTL`
env var). In the lejepa repo the backbone of record is
`research/onto-mesh-harvest/owo/owo.ttl`.

## Actions

### `map` — interview one term (the default flow)

1. Run `buildkit-owo coverage --target <T> --json` to find the next unmapped term (or take the
   engineer's `--term IRI`).
2. **Conduct the interview conversationally, dimension 1→12.** For each dimension ask *does it
   apply?* — if yes, present that dimension's level-1 choices (then level 2–4 within the chosen
   branch) from the backbone; if no, collect the **reason** (required). Never offer level 0;
   never offer a deeper node once the dimension is marked undefined.
3. Collect the engineer's decisions into an answers JSON file (see below) and ask the engineer
   explicitly to approve the commit. Declining = `"approve": false` → the tool stores nothing.
4. Run `buildkit-owo map --target <T> --term <IRI> --answers <file> --json` and report the
   result (version id, idempotent no-op, corroboration flags).

Answers file shape:

```json
{
  "approve": true,
  "dimensions": {
    "object": {"applies": true, "levels": ["owo:constructional-object", "owo:relationship"]},
    "object-moment-category": {"applies": false, "reason": "moments describe the person"},
    "object-symbolic-category": {"accept": true}
  }
}
```

`{"accept": true}` is valid only in assisted mode for dimensions the predictor pre-checked.

### `map --assisted` — pre-checked estimate (faster, still engineer-approved)

Add `--assisted`: dimensions the predictor scores at **confidence ≥ 0.80** (configurable via
`--assist-threshold`) arrive pre-checked; below-threshold dimensions are **flagged** and MUST
be answered explicitly. Present the pre-checked estimates for accept-or-change; the committed
record notes `predicted` vs `engineer_changed` per dimension. **LLM text comparison is
agent-side**: when the engineer asks for a semantic comparison, YOU perform it in
conversation and the decision lands in the answers file — the tool makes no LM calls.

### `automap` — drafts for a whole ontology

`buildkit-owo automap --target <T> --all --json` predicts all 12 dimensions per term with
per-dimension confidence and writes **status=draft** versions. Drafts are NEVER authoritative:
walk the engineer through review, then promote each accepted draft with `approve`.
Uniformly-low-confidence terms surface as `needs_full_interview` — run the full `map`
interview for those.

### `approve` — the human gate

`buildkit-owo approve --version <VERSION_ID> --rationale "<why>"` records the engineer's
dated attestation and appends the promoted authoritative version. Only run this after the
engineer's explicit instruction — never self-approve.

### `coverage` / `status` — progress + resume

`coverage` enumerates every class + relationship (mapped/unmapped + the next-unmapped resume
pointer). `status` adds pending drafts, stale-OWO-backbone flags,
`corroboration-insufficient` flags, and the adopted-predictor fidelity (or
`insufficient-corpus`).

### `history` — versions + diff

`buildkit-owo history --term <IRI> [--diff 1 2]` lists the term's append-only version line
with provenance; `--diff` names the changed dimensions.

### `export` — SSSOM / Markdown mirrors

`buildkit-owo export --target <T> --format sssom|markdown [--out <path>]
[--include-drafts] [--reverse]`. Authoritative-only by default; deterministic row order; the
catalog remains the system of record.

### `corroborate` — provider feedback (changes nothing)

`buildkit-owo corroborate --term <IRI> --target <T> --json` runs the configured corroboration
providers **in parallel** over the term's stored mapping and reports per-dimension
agree/disagree with scores. Feedback only — the engineer has the final say.

### `optimize` — GEPA/DSPy fidelity loop (engineer-initiated; `[owo-opt]` extra)

`buildkit-owo optimize [--candidate-only] [--lm-responses <file>] --json` builds a seeded
train/held-out split from **approved** mappings and evaluates candidate automap programs. The
**regression gate** rejects any candidate below the **90% hard floor (95% target)**; every
evaluation is recorded append-only. Until the approved corpus is large enough it reports
`insufficient-corpus` and changes nothing. Only run when the engineer explicitly asks to
optimize.

**The LM is agent-side (FR-016)**: when asked to optimize, YOU perform the LLM text
comparisons for the corpus terms and write the answers to a JSON file
`{"<term_iri>": {"<dimension>": "<level1 iri>"}}`, then pass it via `--lm-responses` — the
tool itself makes no LM calls. Without `--lm-responses` (and without the extra's optimizer
configured) the run reports honestly and adopts nothing.

## Exit codes

`0` success/no-op · `1` refused (bad selection / malformed target / gate) · `2` PGlite/DB
unavailable · `3` missing `[owo]`/`[owo-opt]` extra (the message contains the install hint).

## Boundaries (Constitution II/VI; FR-013)

- Advisory only; never auto-invokes a `/buildkit-*` command or pipeline stage.
- Human gates are never self-recorded: interview commits need the engineer's in-session
  approval; automap drafts need an explicit `approve`.
- Append-only, idempotent store; re-running an unchanged mapping creates no version.
- The target ontology and the `owo.ttl` backbone are read-only, always.
- All persisted/emitted free text is secret-redacted.
