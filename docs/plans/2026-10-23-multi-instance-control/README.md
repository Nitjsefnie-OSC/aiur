# Multi-instance control plane — planning pack

- **Feature slug:** `multi-instance-control` · **Display label:** Multi-instance control plane · **Ticket prefix:** MIC · **plan_version:** 1
- **Researched at:** `ab0c21424` (origin/main, 2026-10-23)
- **Plan:** [`../2026-10-23-001-feat-multi-instance-control-plan.md`](../2026-10-23-001-feat-multi-instance-control-plan.md)
- **Graph:** [`graph.json`](graph.json) · **Decisions:** [`questions-or-commands.md`](questions-or-commands.md) · **Deferred:** [`deferred-findings.md`](deferred-findings.md) · **Validation:** [`validation-report.md`](validation-report.md)
- **Status of this pack:** proposed, not promoted. No GitHub issue, label, or daemon was changed.

## Request

Operator, 2026-10-23, verbatim:

> "At the moment, I have to run an executor agent on each machine to manage each IR instance. As we're thinking about how we will support running IR on multiple machines with features like setting in the config which tickets will be owned by which IR instance, I'd like to also build this in such a way that a single agent from a single machine can update portions of the config in external machines. For example, having a single executor coordinate on instances running on different machines. I'm even wondering if we make the CLI support passing that command off externally."

Then: "do a deep research spike on this work. Use compound engineering skills like brainstorm and plan to write up tickets and deeply document all of the tickets in documentation before we add actual tickets at GitHub." ("IR" is dictation for Aiur.)

## Boundary and authority

- Planning only. Commit and push of this branch and a draft PR are authorized. GitHub ticket creation is **not** authorized; the Executor promotes later on the operator's word.
- Source precedence: operator decisions > this pack's decisions > GitHub (for existing tickets) > Aiur runtime > prose here.
- Finite boundary: R1-R19 in the plan. The run ends when MIC-010 merges with its evidence.
- Calibration: the operator gave no ticket-count estimate. The pack has 10 new tickets (26 points) plus 6 amendments to existing tickets, against 6 hypothesis pieces. The extra tickets come from splits that keep each PR independently green: the call validator apart from its HTTP route (security review on a pure module), the wake-ack server change apart from the client merge, and a loopback-distribution check that no existing ticket owns.

## Reconciliation with existing tickets

| Hypothesis piece | Owner after this plan | New or amend |
|---|---|---|
| 1. `aiur --instance <name> <cmd>`, registry | MIC-003, MIC-004 | new |
| 2. Control API with scoped tokens and audit | MIC-001, MIC-002 on top of #5945 | new + amend #5945 (A1) |
| 3. Remote config as validated, build-aware data | MIC-007 | new (extends existing `aiur set`) |
| 4. Ticket ownership as data | MIC-008 on top of #5947 | new + amend #5947 (A3) |
| 5. One Executor for all instances | MIC-005, MIC-006 | new |
| 6. Security | MIC-009; TLS at proxy stays #5942; tailnet sign-in stays #5611 | new + amend #5939/#5940 (A4) |
| Roster CLI overlap | #5950 | amend (A2) |
| Guide | #5954 | amend (A5) |

### Proposed amendments to existing tickets

Apply when promoting; edit the ticket bodies, not this file.

- **A1 — #5945:** split the hard block on #5942. Acceptance 1, 2 and 4 (tokens, scopes, sending a token) need no public sign-in and may merge first; only acceptance 3 (refuse basic auth beyond loopback) waits for #5942. Add: bearer-authenticated routes do not pass `api_write` (no cookies, so the Origin/`X-Aiur-Request` CSRF checks do not apply; `src/lib/aiur_web/routes/decisions.ex:12` shows the current requirement), and the plug assigns `conn.assigns.token_name` for MIC-002's audit. Without A1, the chain is #5611 → #5942 → #5945 → MIC-002, and the first remote slice waits on sign-in work it does not use.
- **A2 — #5950:** replace acceptance 3 (`aiur status --all-instances`) with "plain `aiur status` shows a roster section when a lease store is configured"; live per-instance detail is `aiur --instance all status` (MIC-004). Add each instance's `server.public_url` to the roster record so the operator can copy it into the registry.
- **A3 — #5947:** the heartbeat record also carries `instance.owns`, `instance.pool` (MIC-008), and the build version. Record the store choice (default Postgres, D3) and how home instances reach it.
- **A4 — #5939 and #5940:** the container entrypoint exports the engine's loopback distribution flags and a cookie from the environment or volume, never the release's `releases/COOKIE`; MIC-009 makes a miss fail at boot.
- **A5 — #5954:** add "Control several instances from one machine" (registry, tokens, `--instance`, fleet Executor), written by MIC-010 if #5954 merges first.
- **A6 — #5945, #5948, #5949, #5950, #5951:** replace the `{T6}`/`{T9}` placeholders with #5942/#5947 (DF-4).

## Lanes

| Lane (epic column) | Icon | Tickets | Earliest phase |
|---|---|---|---|
| transport | `arrows-right-left` | MIC-001, MIC-002, MIC-003, MIC-004 | 1 |
| executor | `bolt` | MIC-005, MIC-006 | 1 |
| config-ownership | `adjustments-horizontal` | MIC-007, MIC-008 | 1 |
| safety-acceptance | `shield-check` | MIC-009, MIC-010 | 1 |

Machine lanes: PC owns MIC-001, 002, 005, 006, 008, 009, 010; NUC owns MIC-003, 004, 007 (balanced so both start in phase 1).

## Graph and waves

Hard dependencies (`depends_on`), from `graph.json`:

```mermaid
flowchart LR
  E5945["#5945 tokens (amended A1)"] --> M2
  E5947["#5947 claim lease"] --> M8
  M1["MIC-001 call contract"] --> M2["MIC-002 control endpoint"]
  M3["MIC-003 --instance"] --> M4["MIC-004 --instance all"]
  M7["MIC-007 aiur set"] --> M8["MIC-008 ownership rules"]
  M2 --> M6["MIC-006 one Executor"]
  M4 --> M6
  M5["MIC-005 deferred ack"] --> M6
  M2 --> M10["MIC-010 acceptance"]
  M4 --> M10
  M6 --> M10
  M7 --> M10
  M8 --> M10
  M9["MIC-009 loopback check"] --> M10
```

| Phase | Members (antichain) | Points | Kevin can try after |
|---|---|---|---|
| 1 | MIC-001, MIC-003, MIC-005, MIC-007, MIC-009 (+ #5945, #5947 already filed) | 13 | `aiur set agent.max_concurrent_builds 2`, `aiur set --list`; `aiur doctor` distribution line |
| 2 | MIC-002, MIC-004, MIC-008 | 8 | **`aiur --instance nuc status`**, `aiur --instance all agents`, `instance.owns` |
| 3 | MIC-006 | 3 | one Executor for PC and NUC |
| 4 | MIC-010 | 2 | full acceptance |

- **Depth:** 4 phases (budget 5).
- **Critical path:** #5945 → MIC-002 → MIC-006 → MIC-010, with MIC-001 parallel to #5945. Without amendment A1 it lengthens by #5611 (PR 5903) and #5942.
- **Spine (first-slot staffing):** #5945 and MIC-001 (both unblock MIC-002, the transport every remote feature uses), then MIC-003.
- **Same-phase serializations:** none. `serializes_with` edges point at in-flight tickets outside the pack: MIC-002 ~ #5942 (`router.ex`), MIC-003 ~ #5939 (`aiur-engine.sh`), MIC-008 ~ #5948/#5949 (lease record shape).
- **Hot file:** `website/docs-app/reference/cli.md` (500-line cap) is edited by seven tickets in different sections; recorded as an exception, not an edge. Each PR consolidates rows to stay at or under 500 lines.
- **Dropped data-flow edges** and the ticket that reconnects each: `graph.json` `integration_ledger` (all reconnected by MIC-010 or named merge order).

## Hypotheses the code changed

1. **"A control API that returns the same JSON envelopes as the CLI."** There is no shared envelope (`commands_cli.ex`, `github_cost_cli.ex`, `feature_cli.ex` each build their own) and most mutating commands print text only. Changed to: forward the CLI's own allowlisted call and return its output verbatim (KTD1). Parity is structural.
2. **"Every CLI control command over HTTPS."** `stop`, `restart`, run, `init`, `doctor`, `upgrade`, `cleanup-stale`, `pre-pr` are bash or local-BEAM and manage host processes; `listen` streams. About 45 RPC commands become remote; the rest are refused by name.
3. **"`~/.aiur/instances.yaml`."** `~/.aiur/instances/<key>/` already exists for dashboard secrets. Renamed `~/.aiur/remote-instances.yaml`.
4. **"New keys reaching an older build crash the orchestrator."** Not true at this commit: unknown keys are dropped silently (`schema.ex:202-214`), and since #3980 a rejected hot reload keeps the last good config. The 2026-10-10 crashes were invalid values of known keys on a build without #3980. Remaining risks are a silent no-op for an unknown key and a boot crash on an invalid file; MIC-007 validates at write time in the receiving build and never lets an override stop boot.
5. **"Ownership rules in the shared coordination store."** Changed to per-instance config published through #5947 heartbeats; the lease already guarantees one dispatcher.
6. **"`executor-wait --instance all` merges the streams."** Confirmed, with two prerequisites the hypothesis missed: the daemon acknowledges a batch before an HTTP reply is delivered (needs MIC-005), and `wake_id` is a per-journal counter, so records need their instance name and one cursor per instance.
7. **"Erlang distribution never leaves localhost."** True only on the bash engine path; the daemon's documented refusal is not implemented, and the release falls back to a baked cookie. New MIC-009.
8. **"Scoped tokens, read vs control."** #5945 already defines `read`/`write`; reuse those names.
9. **"`repo_global` services list."** No such key; it is `instance.role` read once at boot (`src/lib/aiur.ex:77-83`). #5948 owns making it dynamic.

## Discovery policy

P0/P1 acceptance blockers found during execution become tickets in this collection with `discovered_from`. Contained review findings return to the owning ticket. Everything else goes to `deferred-findings.md`. If created tickets outpace merged tickets by more than 3, stop creating and report.

## Executor handoff

1. Read the plan's Goal Capsule, this README, and `questions-or-commands.md`. Use `aiur-run`; write a three-to-five-sentence goal that names this collection, the stop condition (MIC-010 merged with evidence), and that promotion needs the operator's word.
2. On the operator's go-ahead, promote: apply amendments A1-A6 to the existing tickets; create MIC-001 to MIC-010 from `tickets/*.md` verbatim with `feature:multi-instance-control`, `priority:1`, the lane label (`agent:queued` for PC, the NUC prefix for NUC tickets), and `area:daemon`/`area:cli`/`area:ui` as fits; write native `blocked_by` links from `graph.json`; `aiur feature create multi-instance-control` and `aiur feature add`; enqueue. Read back with `aiur feature show multi-instance-control --json` and `aiur queue show --json`. Record the MIC → issue number map in this README and freeze the ticket documents.
3. Dispatch first: #5945 (after A1), MIC-001, MIC-003.
4. Fresh state comes from `gh issue list -R aiur-team/aiur --label feature:multi-instance-control` and `aiur agents`; nothing in this pack is live state.
5. Unresolved human gates: none blocking; D1-D13 proceed on defaults.
