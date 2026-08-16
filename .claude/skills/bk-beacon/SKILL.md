---
name: "bk-beacon"
description: "Shared team information radiator (PoC demonstrator). A single freestanding beacon that proves the end-to-end chain: a Claude Code agent (over MCP) -> a C# QHState-RTOS host ('the OS') -> a durable PGlite-tracked mailbox + a fixed QH state machine (+ static-macaroon verify-before-act) -> three co-operating runtimes (C# + Gleam/AtomVM + Python) -> a WebSocket -> a Blazor SPA (web worker + per-component FE mailbox + FE state machine) that renders JSON, with all display/use-case control driven from the back end. Advisory & non-blocking: never auto-invokes a /bk-* pipeline command nor mutates an observed repo; additive-only persistence; secrets are redacted before any persist or send."
argument-hint: "[a goal, e.g. 'stand up a beacon' or 'switch the radiator to the roadmap'] | doctor | init <name> [location] | host [--ws-port <n>] | web [--port <n>] | join [--repo <r>] [--machine <m>] [--version <v>] | update [--version <v>] | list | worker | mcp"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "buildkit"
  source: "templates/commands/buildkit-beacon.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). It is either a
natural-language goal ("stand up a beacon", "switch the radiator to the roadmap", "why is a repo
showing idle?") or a `beacon` subcommand. If empty, summarise the surface below and ask what they
want to do.

## What this does

`/bk-beacon` stands up and drives a **shared team information radiator** — a single beacon that
displays each joined repo×machine's pipeline state on a LAN screen, all controlled from the back
end. It is **advisory & non-blocking**: it **never** auto-invokes `specify`/`clarify`/`plan`/
`tasks`/`analyze`/`implement` or any ship/roadmap command, never mutates an observed repo's
pipeline/DBOS/source state, and a down/unreachable beacon never gates a reporter's pipeline
(FR-017, SC-004). Persistence is additive-only; all reported/transmitted text is secret-redacted
before persist or send.

This skill **conducts**; the deterministic `python -m buildkit_cli.beacon <subcommand>` CLI does
the work. Every subcommand accepts `--json` (machine-readable) and `--home <dir>` (an explicit
beacon home, overriding the active pointer). Exit codes: `0` ok · `1` invalid args / refused ·
`2` store/backend unavailable.

> **PYTHONPATH:** the beacon code lives in the worktree's `src/`. Run every command with
> `PYTHONPATH` including `<worktree>\src` (see `beacon/docs/GETTING-STARTED.md`).

## The surface

- **`doctor`** — advisory runtime-presence check (Python/.NET/Node/WSL Gleam/AtomVM). Always
  exit 0; never blocks. Run this first.
- **`init <name> [location]`** — create the beacon home + its PGlite store, apply the additive
  `beacon_*` schema, generate the shared macaroon secret, and record the active-home pointer.
  Run-as-process for the PoC (the Windows-service daemon is deferred).
- **`host [--ws-port N] [--duration-ms M]`** — run the C# QHState-RTOS host: the WebSocket
  transport + the display active objects + (with a home) the store-driven RadiatorAo. Launches
  the beacon's PGlite via the Node bridge and writes `<home>/transport.json`.
- **`web [--port P] [--ws-url URL]`** — serve the Blazor SPA radiator (static publish) and write
  `beacon-config.json` so the SPA's web worker connects to the running host.
- **`join [--repo R] [--machine M] [--machine-type workstation|satellite] [--person P] [--version V] [--addr A]`**
  — register a (repo×machine) with the beacon (defaults: repo = cwd name, machine = hostname).
  Same repo on two machines => two rows, never merged (FR-006).
- **`update [--repo R] [--machine M] [--version V]`** — reconcile the reported buildkit version
  (+ a planned-only roadmap snapshot).
- **`list`** — read-only enumeration of joined (repo×machine) with stage/status; derives `idle`
  from a `last_seen` threshold.
- **`worker [--request PATH] [--result PATH]`** — the Python reporting/integration worker
  (roadmap reconcile) the C# host launches over the mailbox-file seam (reply-as-event).
- **`mcp`** — run the FastMCP server (agent->beacon) exposing `join`/`stage_report`/
  `version_report`/`display_control`/`list`. Mutating tools are macaroon-gated and commit through
  a single-writer funnel.
- **`announce`** — *(round-two, D2 stub)* timed announcements.
- **`install`/`uninstall`/`start`/`stop`/`restart`/`status`** — *(round-two, D16/D17 stubs)*
  Windows-service daemon lifecycle; the PoC runs as a process with explicit-address discovery.

## How to drive it

- **Stand up** (one host, one machine): `doctor` -> `init demo "<home>"` -> `host` -> `web`, then
  open the SPA on a LAN device. See `beacon/docs/GETTING-STARTED.md`.
- **Report from a repo:** `join` then `update` (or wire the advisory stage-emit hook).
- **Switch the display / page / rotate:** an authorized agent calls the MCP `display_control`
  tool (verb `set`/`page`/`rotate`) — never a button on the screen (FR-036). For a worked
  agent flow see `beacon/docs/USER-GUIDE.md` ("How an agent communicates with the beacon").
- **Full option reference, caveats, and known issues:** `beacon/docs/REFERENCE.md`.

Authoritative scope is the spec's `## Pilot Scope — PoC Demonstrator`; round-two items
(announcements/presence/history, production exactly-once + broadcast, full GLPNET/real macaroon,
Windows-service daemon + mDNS, Syncfusion polish, scale/federation) are deferred and tracked in
`specs/037-bk-beacon-pilot/round-two-deferred.md`.
