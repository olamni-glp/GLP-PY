---
name: "bk-help"
description: "Advisory tool inventory & guided invocation for the buildkit toolchain. Lists every installed tool grouped by canonical pipeline stage, drills into any one tool for how-to guidance, recommends the right tool + next step from a natural-language situation, and helps author an agreed, enforceable custom workflow (ordered tool invocations + decision/exception branches) that is persisted in the buildkit catalog and exported to Markdown/HTML (mandatory) and Word/PDF (best-effort) with an embedded Mermaid diagram. Advisory only — it composes copy-runnable invocations and hands them back; it never executes or auto-invokes a buildkit-* command, and the enforcement gate refuses out-of-order steps without ever running one (FR-007)."
argument-hint: "[a situation, e.g. 'what order do I build these features in?'] | info <tool> | list | reconcile"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-help.md"
user-invocable: true
disable-model-invocation: false
---



## User Input

```text
$ARGUMENTS
```

## What this does

`/bk-help` answers two everyday questions: *"which buildkit tool do I need
right now, and how exactly do I run it?"* — and, for recurring multi-step jobs,
*"can we agree a repeatable, enforceable sequence and share it?"*.

It is **advisory** (FR-007). It reads the inventory, recommends, and **composes a
copy-runnable invocation that it hands back to you** — it never runs a
`buildkit-*` command for you. The custom-workflow enforcement gate *records
progress and refuses out-of-order steps*; it never executes a step.

> **Advisory-only banner — keep this true:** nothing in this skill or its CLI
> ever executes or auto-invokes a `buildkit-*` command. The deepest action it
> takes is persisting an agreed plan and refusing an out-of-order step.

## The deterministic core (shell out to the CLI)

All inventory/drill-down facts come from the model-free CLI — **always prefer
shelling out to it over reciting tool names from memory**, so the answer matches
installed reality (FR-002/FR-014):

```
python -m buildkit_cli.help list --json        # full inventory grouped by stage (+drift)
python -m buildkit_cli.help info <tool> --json # one tool's guidance card
python -m buildkit_cli.help reconcile --json   # drift only: ok/curated_only/installed_only
```

(`buildkit help …` is the same surface for a human in a terminal.) Consume the
JSON as context; never hand-maintain a tool list.

## US1 — "Show me the whole toolbox"

Run `python -m buildkit_cli.help list` and present the stage-grouped inventory:
intake → spec → plan → tasks → analyze → implement → ship/release → git
primitives → lifecycle. Surface any drift section verbatim — it is data, not an
error. `buildkit help` lists itself (FR-012).

## US2 — "Tell me about one tool"

Run `python -m buildkit_cli.help info <tool>`. Relay purpose, when-to-use,
prerequisites, inputs, outputs, at least one runnable example, advisory
boundaries, and the related before/after tools. If the user misspells a tool,
the CLI returns the closest matches — offer them rather than guessing.

## US3 — "Which tool, and how do I run it?"

1. Load the inventory JSON as context.
2. From the user's situation, **recommend the tool(s) + the next pipeline step**,
   with a one-line rationale for each.
3. On request, **compose the exact copy-runnable invocation string for a tool
   that actually appears in `list --json`** (never invent a tool name) and
   present it in a fenced block — e.g. for "what order do I build these in?",
   `buildkit-plan-order run 009 010 011a` / `/bk-plan-order`; for "capture
   this idea", `/bk-backlog`. Derive the verb from that tool's
   `info <tool>` example so the command is real and runnable.
4. **Hand it back — do not run it.** Re-state the advisory banner if the user
   expects execution.

## US4 — "Compose an agreed, enforceable custom workflow"

For a recurring multi-step job, converge on a plan and persist it:

1. **Converge to *agreed*** — propose an ordered sequence of real tools (each a
   tool that appears in the inventory) with a rationale per step, iterating with
   the user until they explicitly agree (FR-016). Persist the plan as you go via
   the CLI authoring verbs, then agree it once the user signs off (edits are
   **frozen** after `agree` — author changes in a fresh draft):
   ```
   buildkit help workflow create "<title>" "<use case>"          # → prints <id>
   buildkit help workflow add-step <id> --position 1 --tool buildkit-roadmap \
       --invocation "buildkit-roadmap status" --rationale "start from the roadmap"
   buildkit help workflow add-branch <id> --kind exception \
       --condition "CI red on the release PR" --action "fix forward then re-run" --from-step 2
   buildkit help workflow agree <id>                              # draft → agreed (FR-016)
   ```
   Do not register/export before the user has agreed (Edge "Plan not yet agreed").
2. **Capture exceptions as branches** — for each likely failure or decision
   point ("CI red on the release PR", "develop already ahead of main"), record a
   `decision`/`exception` branch with a predefined action (FR-017) via
   `add-branch` above.
3. **Validate + register** via the storage primitives:
   ```
   buildkit help workflow show <id>        # review the persisted plan
   buildkit help workflow validate <id>    # FR-021: every step tool installed?
   buildkit help workflow register <id>    # FR-018/FR-022: requires agreed + validated
   ```
   `register` refuses unless the plan is agreed AND every step tool is installed.
4. **Track progress through the advisory ordinal gate** (refuses out-of-order):
   ```
   buildkit help workflow gate <id> --step 1 --to done
   buildkit help workflow gate <id> --step 3 --to in_progress   # REFUSED if step 2 not done (SC-009)
   ```
5. **Export a shareable doc** with a Mermaid diagram matching the agreed
   sequence (SC-007):
   ```
   buildkit help workflow export <id> --format md   --out plan.md     # always works
   buildkit help workflow export <id> --format html --out plan.html   # always works (Mermaid via CDN)
   buildkit help workflow export <id> --format pdf  --out plan.pdf     # best-effort; degrades w/ message
   ```
   Word/PDF degrade gracefully when their renderer is absent (FR-019) — relay
   the message and offer Markdown/HTML.

The agreed plan is **catalog-persisted**, never session-only (FR-023), and
visible to `/bk-builder`'s read view. Builder reports it; it does not run
it (builder-integration contract).

## Exit codes (the CLI)

- `0` — success (a render with drift is still `0`; a best-effort export that
  degrades is still `0`).
- `1` — usage / validation / gate-refusal (unknown tool, draft not agreed,
  uninstalled step tool, out-of-order gate).
- `2` — the buildkit PGlite catalog is unavailable (workflow subcommands only).

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-help` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
