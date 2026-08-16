---
name: "bk-codify"
description: "Advisory in-the-moment win/improvement capture. Records one note when a buildkit process/skill/tool worked better than normal (a win) or could have worked better (an improvement); dual-writes it to a git-tracked on-disk Markdown file and the durable per-repo PGlite catalog, auto-deriving a bounded context snapshot (active feature, pipeline stage, subject, git branch+commit, actor, time) and secret-redacting all persisted text. Feeds a future /buildkit-retrospective. Advisory only: never switches branches, edits source, or auto-invokes a pipeline command."
argument-hint: "[the win/improvement to capture, e.g. 'implement re-ran completed tasks']"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-codify.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## What this does

`/bk-codify` captures **one in-the-moment note** when a buildkit process, skill, or tool
worked better than normal (a **win**) or could have worked better (an **improvement**) — the
moment you notice it, in a single step. Every capture **dual-writes**: a human-readable,
git-tracked Markdown file under `.specify/codify/notes/<note-id>.md` (the durable floor) **and**
a mirror row in the per-repo buildkit catalog, linked by a shared note id. The notes feed a
future `/bk-retrospective`.

It is **advisory and read-only with respect to your pipeline**: it records a note and nothing
else. It **never** switches branches, edits source, runs tests, or auto-invokes
`/bk-implement` or any other `/buildkit-*` command (FR-009). The capture is append-only —
the only way to neutralize a bad or sensitive note is `withdraw` (which redacts the body and
preserves the record + history, never a hard delete).

## The two surfaces

- **This skill** (`/bk-codify`) — interactive: it *infers* a suggested polarity + subject
  from your description and asks you to **confirm**, enriches context automatically, then calls
  the CLI.
- **The CLI** (`buildkit codify`) — deterministic and flag-based. It carries **no model**: it
  never infers polarity/subject; those are required flags (FR-002).

## How to run it (you, the agent)

1. **Elicit the moment.** Take the user's free text (`$ARGUMENTS`). If it is empty, ask one
   short question: *"What just happened — a win worth keeping, or something that could have
   worked better?"*
2. **Infer + confirm classification.**
   - **polarity**: infer `win` (something worked better than normal) or `improvement`
     (something could have worked better). State your inference and ask the user to confirm or
     correct it before capturing — never guess silently.
   - **subject**: infer the tool/skill/stage/process the moment concerns (e.g.
     `buildkit-implement`, `plan`, `buildkit-ship`). Confirm it.
   - Optionally suggest a couple of **tags** (e.g. `dx`, `idempotency`).
3. **Context is automatic — do NOT type it.** The CLI derives the bounded context snapshot
   (active feature, pipeline stage, git branch + short commit, actor, timestamp) itself. Outside
   any active feature this still works (feature/stage are simply empty).
4. **Capture** by invoking the CLI once (this is the only action this skill takes):

   ```
   buildkit codify capture "<verbatim feedback>" --polarity <win|improvement> --subject <subject> [--tag <t> ...]
   ```

5. **Confirm back** to the user: report the note id, the disk path, and whether the catalog
   mirror succeeded or is pending (a catalog outage still saves the note to disk — exit 0).

## Secret safety (FR-022)

All persisted text (your message **and** the auto-derived context) is secret-scanned and any
match (`AKIA…`, `ghp_…`, `sk-…`, PEM blocks, `password=…`, real connection strings) is replaced
with `[REDACTED:<kind>]` **before** anything is written to either destination. Nothing detected
is ever persisted.

## Retrieve & hand off (later)

```
buildkit codify list [--feature <id>] [--stage <s>] [--polarity <p>] [--subject <s>] [--tag <t>] [--status <s>]
buildkit codify list --json        # the stable, versioned retrospective handoff view
buildkit codify show <note-id>     # full note + event history
buildkit codify status <note-id> --set addressed   # non-destructive: leaves the default "new" view
buildkit codify withdraw <note-id> # redact the body in both sinks; record + history preserved
buildkit codify reconcile          # disk-authoritative: re-mirror any pending/edited disk notes
```

## Boundaries (do NOT)

- Do **not** run any other `/buildkit-*` command as a side effect of capturing (advisory only).
- Do **not** ask the user to type the context — derive it.
- Do **not** edit, withdraw, or re-classify an existing note unless the user explicitly asks.
- Do **not** invent a polarity or subject without confirming with the user.

## Examples

```
/bk-codify when implement crashed it re-ran tasks that were already complete
# → infer polarity=improvement, subject=buildkit-implement; confirm; then:
#   buildkit codify capture "when implement crashed it re-ran tasks that were already complete" \
#       --polarity improvement --subject buildkit-implement --tag idempotency
```

**Registry upkeep (spec-028 FR-004)**: run
`python -m buildkit_cli.registry touch --tool buildkit-codify` from the project root. It marks the
capability registry possibly-stale and **always exits 0** (fail-safe; never blocks this stage).
Ignore its output.
