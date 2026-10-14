---
artifact_contract: ce-unified-plan/v1
artifact_readiness: planned-with-blockers
feature_id: MP-E4
bucket: 2-platform
base_main_sha: 45a290e3
date: 2026-10-06
owner_gate: DESIGN-E4
contracts_owned: [MP-CT-conversations-transcripts-anchors]
contracts_consumed: [events-and-replay (MP-R2), harness-adapter (MP-R7), listener-mode (MP-E7), command-request-resolution (MP-E2), identity]
prior_units: [U4, U6, U8]
prior_boundaries: [RUN, WEB, SD, BUS, DEC, PRJ]
---

# MP-E4 — Dashboard conversations and event navigation: plan

Chunks: [chunks.md](chunks.md). Owned contract:
[../../contracts/conversations-transcripts-anchors.md](../../contracts/conversations-transcripts-anchors.md).
Owner gate: [../../owner-design-tasks/DESIGN-E4.md](../../owner-design-tasks/DESIGN-E4.md).

## 1. Goal

Show the full worker and Executor transcripts in the dashboard, with event jump
points (progress updates, pushes, PR creation, merges, Command requests) that
take the operator to the conversation position where they happened. Keep the
event ↔ instance ↔ agent/session ↔ position relationship as data that phone and
watch (MP-N6) reuse. Write access is only: send a message (through the listener
mode, MP-E7) and answer that agent's open Commands (D15). Logs are never
rewritten; controls stay where they are.

## 2. Repository findings (extends baseline E4)

### 2.1 Transcript storage today — none of it is a complete history

| Store | Shape | Durability | Evidence |
| --- | --- | --- | --- |
| Workspace `logs/agent.ndjson` + `agent.md` | The backend message map as-is; always `event`, `timestamp`; no id, no seq. Append only, no rotation. | Deleted with the workspace (`File.rm_rf`). Not written at all for remote workers. Rewritten (old prefix + new, temp + rename) on workspace rebuild. | `agent_event_log.ex:23-48,24`; `workspace/remove.ex:25,61`; `workspace/reconstruction` merge (`finish_promotion`) |
| IssueLog `.agent_events.jsonl` | `role, body, timestamp, msg_id, sequence, turn_id, payload`; body cut to 1,000 chars, diffs to 2,000; records over 16 KiB reduced. | Per-launch log root: "does not survive a daemon restart". | `issue_log.ex:37,680-805`; `config/paths.ex:27-36` |
| IssueLog `.log` / `.events.log` | Human lines and bus markers `[event:<kind>] id=<id> topic`. | Per launch. | `issue_log.ex:298-327,946-971` |
| `Aiur.LiveConversation` | Normalized messages; states `:live|:ended|:known_empty|:stale|:unavailable|:restart_unknown`. | Memory only; 80 messages / 64 KB; generation is a per-BEAM integer. | `live_conversation.ex:6-47,680-687`; `retention.ex:6-10`; `dispatcher.ex:2494` |
| `Aiur.SessionHandle` | `{backend, thread_id}` per ticket. | Durable (`runtime_state_dir`), resumable local backends only. | `session_handle.ex:2-20`; `session_resume.ex:150-160` |
| Event publication log | `tool_call_id`, `topic`, `event_id`, status per agent `emit_event`. | Per launch, fsynced, never read by the daemon. | `event_publication_log.ex:1-36`; `tool_executor.ex:423-503` |

**Single ingest point for worker transcripts:** the closure built by
`AgentRunner.MessageHandler` (`agent_runner/message_handler.ex:52-63`) sees every
normalized backend message and its `transcript_event` for every backend and for
remote workers too. It already fans out to `AgentEventLog`, transcript broadcast
and `LiveConversation`. The journal tee belongs there.

### 2.2 Readers and UI today

| Surface | Source and window | Evidence |
| --- | --- | --- |
| Conversation drawer (`/chat/:owner/:repository/:identifier`) | `LiveConversation` snapshot (80 messages); states labelled Live / Ended / Stale / Unavailable / Continuity unknown | `router.ex:141`; `operator_control_center/conversation_drawer/presenter.ex:5-213`; `dashboard_live.ex:2254-2267` |
| Agent log modal | `AgentLog.read_workspace/1`: whole file read, last 80 messages, no cursor | `agent_log_modal.ex:148-162`; `agent_log.ex:25,42-53,147-159` |
| `GET /api/v1/:issue_identifier/events` | `AgentEventFeed.list/2`: limit ≤ 50, byte-offset cursor into the per-launch JSONL | `router.ex:191`; `agent_event_feed.ex:76-91,310-329` |
| Stream Deck logs | `StreamdeckLogs.load/1`: 50 newest transcript rows + 40 bus events; "last event at or before" anchoring | `streamdeck_logs.ex:306-338,628-635`; `agent_event_feed.ex:106-114` |
| Send | LiveView `send-operator-message` → `AgentChat.send/3`; API `POST /api/v1/:id/messages`; gated by `observability.dashboard_writable` (schema default **true**; the router comment still says "disabled by default") | `dashboard_live.ex:640-661,2662-2693`; `router.ex:55-62,151-164`; `config/schema/observability.ex:12` |
| Commands answer | `/commands/:decision_id`; `answer-decision` etc. | baseline E2 |

`dashboard_live.ex` is 2,903 lines at `45a290e3` (U8 package `WEB`). New
conversation code goes into new modules.

### 2.3 Milestone and event model to reuse

- Bus event ids are durable (`events/id_generator.ex:2-11`); `bus_events/2`
  returns `%{id, kind, topic, label, body, timestamp}` (`agent_event_feed.ex:231-244`).
- Labels exist for progress, phase, blocked/unblocked, paused, comment, PR
  opened/merged, review comment, CI, decision requested/seen/resolved
  (`agent_event_feed.ex:52-72`). **Missing:** `branch.push` (pushes) and
  `executor.*`.
- Pushes are observed by `ls-remote` polling every 30 s
  (`events/ls_remote_ticker.ex:4`) or by webhook; their time is observation time.
- `Decision.source.session_id` is the provider thread id
  (`tool_executor.ex:602,691`), so a Command can find its session.

## 3. Proposed boundaries

```text
aiur_conversations  NEW component (projection family PRJ, prior boundary #28)
  Conversation.Journal        single writer per conversation; positions; sessions; gaps
  Conversation.Ingest         worker tee (MessageHandler) + Executor (MP-E3) + importer
  Conversation.History        list_entries / list_sessions / subscribe (contract §7)
  Conversation.Anchors        resolver: exact | causal | observed | unanchored (contract §10)
  Conversation.JumpPoints     catalogue: topic → kind/label (extends AgentEventFeed labels)
aiur_web
  ConversationLive / component  full chronology + event rail; worker and Executor modes
  JSON: /api/v1/conversations/:id/{entries,sessions,anchors}
Stream Deck (MP-R6)
  StreamdeckLogs → calls Conversation.Anchors(:observed rule) and History (behaviour-preserving)
```

Required deps: event bus ids/history (BUS), `TrackerIdentity`, and the send router
`Aiur.Listener.send/3` (core per RC-36; its `:legacy` mode keeps today's `AgentChat`
behaviour, RC-05). Optional: Commands (MP-E2), Executor (MP-E3). The journal must
work without the dashboard running (it is daemon-side).

## 4. Alternatives and recommendation

### 4.1 Where full history lives

| Option | For | Against |
| --- | --- | --- |
| A. **New durable append-only journal** per conversation outside workspace and launch dirs, with a writer-assigned `pos` | Survives restart and workspace removal; one position space for anchors; same for workers and Executor; meets brief §3 "retain complete transcripts". | New store, new disk usage; must not slow the agent message path. |
| B. Make the IssueLog root durable and use byte offsets | Smallest code change. | Byte offsets differ per file and producer (`issue_log.ex:114-116`); bodies already truncated to 1,000 chars; three formats; IssueLog also feeds agents' replay, so changing it is cross-cutting. |
| C. Read provider transcripts on demand | No copy. | Workers' files die with the workspace; Codex app-server workers have no file aiur owns; no shared positions. |

**Recommendation: A.** IssueLog stays as is (it feeds `BootstrapDigest`). The
journal is a separate, display-oriented record. Writes are batched off the
message path (cast to the writer; the writer fsyncs per batch) so a slow disk
cannot stall a turn.

### 4.2 How events point into conversations

| Option | Verdict |
| --- | --- |
| Timestamps only (StreamdeckLogs rule) | Kept as the `observed` fallback. Ambiguous under bursts and clock skew. |
| **Strongest-provable precision ladder** (exact tool-call match → causal command match → observed → unanchored), stored as append-only anchors | **Chosen.** Exact for agent-emitted events (progress, phase, Command request) because `tool_call_id` and `event_id` are already recorded together. |
| Inject markers into transcripts | Rejected: rewrites the agent's input; logs are never rewritten. |

### 4.3 What "write" means (settled, D15)

Send a message (via MP-E7) and answer that agent's open Commands. Pause,
resume, interrupt and spawn stay where they are today (drawer `Pause`, TUI,
CLI). No editing, hiding or deleting of entries.

## 5. Send path before and after MP-E7

RC-05 (Phase C) and CR-E4-8 settle it (X-51): MP-E7-C1–C3 ship in wave 3 ahead of
the E3/E4 write chunks, and E7-C3 ships behind a flag that keeps today's behaviour
(`:legacy`, which still calls `AgentChat.send/3`, `agent_chat.ex:14-19`). E4-C6
therefore ships once, on `Aiur.Listener.send/3`, with no interim `AgentChat` step
(MP-E4-C6-T01); the overlay shows the listener receipts. The Executor composer is
enabled only when MP-E3 reports an attached session (otherwise disabled with the
reason).

## 6. Non-happy paths

| Case | Behaviour |
| --- | --- |
| No transcript yet | "No messages yet" (known empty) distinct from "unavailable". Reuse the drawer state vocabulary (`presenter.ex:188-213`). |
| History before the journal existed | Importer reads workspace `agent.ndjson` (if present) and current-launch IssueLog JSONL once, writes them as an `import` session, preceded by a `pre_journal` gap. Never claims completeness it lacks (`complete_from_start: false`). |
| Daemon restart mid-turn | `LiveConversation` already marks `:restart_unknown`; the journal ends the session `daemon_restart_unknown` and continues. |
| Remote worker | Expected to work because the `MessageHandler` closure runs in the daemon while only `AgentEventLog` skips remote hosts (`agent_event_log.ex:24`). Phase C must confirm this on an SSH worker (RQ-E4-5). |
| Duplicate messages (Codex deltas, replay) | `assistant_delta` skipped as `LiveConversation` does (`message_handler.ex:131-134`); entry `id` dedup. |
| Event with no session covering it | `unanchored`; shown in the rail without a jump. |
| Two events at the same position | Both listed on that position, ordered by `event_id`. |
| Long history (tens of thousands of entries) | Paged by `pos`, 50 default / 200 max; "load older" and "jump to start" use cursors; anchor jump loads `around: pos`. |
| Journal write failure (disk full) | Message path unaffected; a `gap` (`source_unreadable`) is written when writing resumes; one alert. |
| Reader behind live tail | Subscribe + `after: pos` catch-up; no gap from reconnect. |
| Command answered elsewhere | Command contract wins (first answer); the inline answer form shows resolved state from the Command store, not from the conversation. |
| Read-only dashboard | Full read; no composer; no Command answer buttons (same gate as today). |

## 7. Privacy and security

- Journal files 0600 in a 0700 dir; no public route; dashboard auth for reads.
- Bodies/output capped at 16 KiB for command/tool results and 64 KiB for
  other kinds (RQ-E4-1), with head/tail truncation flagged; reasoning stored,
  display per DESIGN-E4.
- Phone (MP-N6) deep links carry `conversation_id` + `pos`/`anchor_id` only; the
  body is fetched over the paired, authorized channel (MP-N2/N4).
- **Read-time masking (Phase D, security M5):** device principals always receive
  bodies passed through `SecretRedactor.redact/1` and `redact_urls/1`, flagged
  `redacted: true`; the journal is never rewritten. The dashboard default is DESIGN-E4
  decision 4 (proposed: mask, reveal on loopback). Masking is pattern-based and
  best-effort, so the view still says transcripts may contain secrets (C2-T01, C2-T02,
  C5-T02).
- **Operator provenance (Phase D, security M6):** a worker entry is `operator` only with
  daemon delivery evidence; other provider `user` records are `provider_input`
  (C1-T01).

## 8. Acceptance criteria

1. A worker whose workspace was removed still has its full conversation in the
   dashboard after a daemon restart.
2. Every entry has a `pos`; paging `before`/`after`/`around` returns contiguous,
   non-overlapping pages; reconnect with `after: last_pos` yields no gap and no
   duplicate (property test).
3. A progress update emitted by `emit_event` anchors `exact` to the tool-call
   entry; a test fails if the resolver falls back to `observed` when the
   publication record exists.
4. `pr.merged` by another actor anchors `observed` to the last entry at or
   before `observed_at`; an event before the first session is `unanchored` and
   rendered without a jump (mutation test: replacing `unanchored` with "nearest
   entry" fails).
5. A Command opens its requester's conversation at the request position.
6. Pushes (`branch.push`) appear as jump points with the head sha.
7. Selecting a jump point loads `around: pos` and highlights the entry within
   one round trip.
8. The Stream Deck logs projection produces identical keys for its existing
   fixtures after it is moved onto the shared anchor rule
   (`streamdeck_logs_test.exs` unchanged and green).
9. No code path writes to a provider transcript or edits a journal line
   (static test: journal module exposes append-only functions only).
10. The journal tee adds no synchronous disk I/O to the agent message closure
    (test with a blocked writer: the closure returns).

## 9. Chunk summary (detail in [chunks.md](chunks.md))

| Chunk | Outcome | Depends on |
| --- | --- | --- |
| MP-E4-C1 | Durable conversation journal (contract §3–§6) + worker tee | MP-R2 event ids (exist today); identity |
| MP-E4-C2 | History API: paging, sessions, live subscribe, JSON routes | C1 |
| MP-E4-C3 | Anchor resolver + persisted anchors | C1, MP-R2 history read, MP-E2 source fields |
| MP-E4-C4 | Jump-point catalogue (push, executor, Commands) + Command→conversation links | C3 |
| MP-E4-C5 | Dashboard conversation view (worker; Executor mode for MP-E3) | C2, C4, **DESIGN-E4** |
| MP-E4-C6 | Write surface: composer on `Aiur.Listener.send/3` (RC-05; no AgentChat step) + inline answer of this agent's open Commands | C5, MP-E2, MP-E7-C1–C3 (wave 3) |
| MP-E4-C7 | Stream Deck logs on the shared anchor rule | C3, coordinate MP-R6 |
| MP-E4-C8 | Importer for pre-journal history + retention/privacy docs | C1 |

## 10. Open questions

**Owner (Kevin), in DESIGN-E4:**
- OQ-E4-1. Layout: one chronology with an event rail, or a split event list + transcript? (Designer's call; brief says Kevin designs it.)
- OQ-E4-2. Which jump-point kinds are on by default, and is CI/comments noise?
- OQ-E4-3. Show reasoning and raw tool output by default, collapsed, or hidden?
- OQ-E4-4. Dashboard masking default (devices are always masked, security M5): mask with loopback reveal (proposed), or raw? = DESIGN-E4 decision 4.
- OQ-E4-5. Retention: confirm "keep forever, no automatic pruning" (brief §3 implies yes).
- OQ-E4-6. Does the existing drawer stay as the quick view with a link to the full view, or is it replaced?

**Research (Phase C):**
- RQ-E4-1. Journal throughput and size: **measured 2026-10-14**, ticket MP-E4-C1-T00 (#4453); census, projections and recommendations below.
- RQ-E4-6. Does the bus event's tool call id match a transcript entry? **Census 2026-10-06:** 1,851 of 2,164 completed publications matched a tool entry `msg_id` in the same launch; re-measured in MP-E4-C3-T02.
- RQ-E4-2. `causal` matching rules for `git push` / `gh pr create` / `gh pr merge` command entries across Codex and Claude output shapes; false-positive rate on recorded transcripts.
- RQ-E4-3. Whether IssueLog's `observed_at` for bus events and the journal's `observed_at` share one clock (both daemon) — confirm for webhook-sourced events.
- RQ-E4-5. Confirm the `MessageHandler` closure runs daemon-side for SSH workers, so the journal tee covers them.
- RQ-E4-4. Import fidelity: which backends' workspace `agent.ndjson` can be replayed through `transcript_event_from/3` offline.

### RQ-E4-1 — completed census, 2026-10-14 (#4453)

Read-only measurement of the available fleet journals, taken during the 20:33 UTC census session.
Executor confirmed dispatch was not load-held (load about 6 on 16 cores; 3 agents
running). Configured `agent.max_concurrent_agents` is **16**. The seven-day window
starts **2026-10-07 00:00 UTC** and ends at each scan's read time.

| Source / window / whole-record cap | Usable files | entries/h/agent p50 / p90 / max | bytes/h/agent p50 / p90 / max | bytes/ticket p50 / p90 / max | Records over cap | Fleet GB/day p50 / p90 |
| --- | --- | --- | --- | --- | --- | --- |
| IssueLog, available history | 155 | 64 / 175 / 480 | 30KB / 99KB / 307KB | 76KB / 186KB / 0.84MB | n/a | 0.012 / 0.038 |
| IssueLog, Oct 7–14 | 155 | 62 / 158 / 480 | 30KB / 99KB / 307KB | 75KB / 186KB / 0.84MB | n/a | 0.012 / 0.038 |
| Workspace, available history, 64 KiB | 676 | 63 / 436 / 1079 | 401KB / 3.54MB / 11.31MB | 1712KB / 8.85MB / 47.25MB | 11214 | 0.154 / 1.359 |
| Workspace, Oct 7–14, 64 KiB | 341 | 92 / 544 / 1079 | 604KB / 4.48MB / 11.31MB | 1630KB / 5.41MB / 18.22MB | 2951 | 0.232 / 1.720 |
| Workspace, available history, 32 KiB | 676 | 63 / 436 / 1079 | 339KB / 2.61MB / 8.25MB | 1410KB / 6.98MB / 34.64MB | 23202 | 0.130 / 1.002 |
| Workspace, Oct 7–14, 32 KiB | 341 | 92 / 541 / 1079 | 485KB / 3.46MB / 8.25MB | 1338KB / 4.79MB / 16.38MB | 6067 | 0.186 / 1.329 |
| Workspace, available history, 16 KiB | 676 | 63 / 436 / 1079 | 255KB / 1.95MB / 5.38MB | 1091KB / 5.13MB / 23.40MB | 37684 | 0.098 / 0.749 |
| Workspace, Oct 7–14, 16 KiB | 341 | 92 / 541 / 1079 | 397KB / 2.57MB / 5.38MB | 1091KB / 3.93MB / 14.22MB | 12119 | 0.152 / 0.987 |

**Population and method.** There are 5 available launch directories, dated
October 12 and 14, so the IssueLog history and seven-day samples cover the same
short available period, not seven complete days. Workspace discovery found
752 files (12.07 GB raw); 392 had mtimes on or after October 7. Recent mtimes
are not the recent-event population: the live rows filter each record's timestamp.
Usable files have journal-relevant records spanning at least 0.05 hours (3 minutes).
Oversize counts include matching records in *all scanned files*, including files
excluded from the rate table for shorter spans. Bytes/ticket means one ticket-launch
file for IssueLog and one workspace lifetime/window for ndjson, not a deduplicated
conversation total. Rates use first-to-last selected event, including idle time;
resumes and long-lived workspaces depress historical rates.

IssueLog excludes `assistant_delta`; ndjson selects `payload.method ==
"item/completed"` or `event` in `transcript`, `alert`, then caps the entire serialized
record at 64/32/16 KiB. These are **storage proxies**, not strict bounds on the
future journal: IssueLog already truncates bodies, while ndjson includes protocol
noise and can omit normalized events; per-field journal caps and metadata differ
from the whole-record cap used here. Projections are decimal GB/day, computed as
`bytes/h/agent × 16 × 24`, assuming all configured agents work continuously at
that sample quantile (sorted sample at index `floor(p × n)`, without interpolation).
They are capacity scenarios, not observed fleet disk growth
or a claimed saving. Concurrent appends explain small differences between scans;
invalid/torn lines are skipped, and records without valid timestamps are excluded
from the live window. Free home disk at measurement: **1.2 TiB** (`df -h`: 1.9T
size, 671G used, 37% used).

**Cross-check.** The available IssueLog has 314,059 deltas out of 346,253 records
(90.70%); deltas are again the majority. Its other 32,194 records have no top-level
`kind` (the script labels them `unknown`), but are included. The later live scan
sees one additional non-delta record. No bodies or source lines were printed.

**Recommendation for C1-T01.** The 64 KiB p90 projection is **1.359 GB/day** for
available workspaces and **1.720 GB/day** for the live window, both above 1 GB/day.
Adopt **16 KiB for `command` and `tool_result` body/output**, **64 KiB for `message`
and `diff`** (other kinds retain the 64 KiB ceiling): `@max_body_bytes = 65_536`,
`@max_tool_body_bytes = 16_384`. The all-16-KiB row is a lower-cap scenario, not
an estimate of that mixed policy: its actual size remains unmeasured and may
exceed 1 GB/day. Even the recent all-16-KiB scenario is **0.987 GB/day**,
leaving little headroom for metadata or a busier fleet. Keep **`@segment_bytes = 8_388_608` (8 MiB)**: even the conservative
64 KiB p90 bytes/ticket is 8.85 MB historical and 5.41 MB live, below 64 MiB.
C1-T01 must include the omission marker inside the selected byte budget, preserve
UTF-8 boundaries, and use smaller retained ends for the 16 KiB tool cap.
Retention remains an owner decision; this census does not approve pruning or
keep-forever. DESIGN-E4 decision 5 receives the measured proxy scenarios below.

**Verbatim aggregate outputs** (historical and recent runs, in table order):

```text
record_kind_counts={"assistant_delta": 314059, "unknown": 32194} invalid_lines=0
source=issue_log ticket_launches=155 deltas_excluded since=None
entries/h/agent p50=64 p90=175 max=480
bytes/h/agent p50=30KB p90=99KB max=307KB
bytes/ticket p50=76KB p90=186KB max=0.84MB total=15.7MB

record_kind_counts={"assistant_delta": 314059, "unknown": 32195} invalid_lines=0
source=issue_log ticket_launches=155 deltas_excluded since=2026-10-07 00:00:00+00:00
entries/h/agent p50=62 p90=158 max=480
bytes/h/agent p50=30KB p90=99KB max=307KB
bytes/ticket p50=75KB p90=186KB max=0.84MB total=15.7MB

source=workspace cap=65536 workspaces=676 records_over_cap=11214 since=None
entries/h/agent p50=63 p90=436 max=1079
bytes/h/agent p50=401KB p90=3.54MB max=11.31MB
bytes/workspace p50=1712KB p90=8.85MB max=47.25MB total=2377.4MB

source=workspace cap=65536 workspaces=341 records_over_cap=2951 since=2026-10-07 00:00:00+00:00
entries/h/agent p50=92 p90=544 max=1079
bytes/h/agent p50=604KB p90=4.48MB max=11.31MB
bytes/workspace p50=1630KB p90=5.41MB max=18.22MB total=839.3MB

source=workspace cap=32768 workspaces=676 records_over_cap=23202 since=None
entries/h/agent p50=63 p90=436 max=1079
bytes/h/agent p50=339KB p90=2.61MB max=8.25MB
bytes/workspace p50=1410KB p90=6.98MB max=34.64MB total=1842.2MB

source=workspace cap=32768 workspaces=341 records_over_cap=6067 since=2026-10-07 00:00:00+00:00
entries/h/agent p50=92 p90=541 max=1079
bytes/h/agent p50=485KB p90=3.46MB max=8.25MB
bytes/workspace p50=1338KB p90=4.79MB max=16.38MB total=703.3MB

source=workspace cap=16384 workspaces=676 records_over_cap=37684 since=None
entries/h/agent p50=63 p90=436 max=1079
bytes/h/agent p50=255KB p90=1.95MB max=5.38MB
bytes/workspace p50=1091KB p90=5.13MB max=23.40MB total=1362.5MB

source=workspace cap=16384 workspaces=341 records_over_cap=12119 since=2026-10-07 00:00:00+00:00
entries/h/agent p50=92 p90=541 max=1079
bytes/h/agent p50=397KB p90=2.57MB max=5.38MB
bytes/workspace p50=1091KB p90=3.93MB max=14.22MB total=566.2MB
```

**Reproduction.** The two Python snippets in MP-E4-C1-T00 were run from an isolated
scratch directory using `nice python3 -I`. The IssueLog snippet additionally
counts record kinds; both snippets reject missing timestamps for `--since`, and
the workspace snippet adds the same `--since` option. Synthetic fixture checks
passed for selection, delta exclusion, timestamp filtering, oversize counting
and torn-line handling. Commands (no production code or tests added):

```sh
nice python3 -I "$S/census_issue_log.py" ~/.aiur/logs
nice python3 -I "$S/census_issue_log.py" ~/.aiur/logs --since 2026-10-07
for cap in 65536 32768 16384; do
  CAP_BYTES=$cap nice python3 -I "$S/census_workspace_ndjson.py" ~/code/aiur-workspaces
  CAP_BYTES=$cap nice python3 -I "$S/census_workspace_ndjson.py" ~/code/aiur-workspaces --since 2026-10-07
done
```

## 11. Plan-refresh note

If MP-R1/R2/R6/R7 land first: `aiur_conversations` sits in the projections
family (#28 `PRJ`); `MessageHandler` moves with `RUN` (#18) under R7, and the
tee becomes a subscription to the adapter's normalized transcript stream;
`StreamdeckLogs` anchoring moves to the shared resolver as part of MP-R6's
shared-projection split (E4-C7 and R6 must not both do it — coordinator to
assign). Event ids and history reads come from the `aiur_events` API (R2)
instead of `IssueLog.event_history/2`. If E4 precedes them, C1–C3 expose only
the contract interfaces above so the refactor moves, not rewrites, them.
