# MP-R1 tickets, chunks C1–C5

Written by the C1–C5 ticket researcher on 2026-10-06 at base `45a290e3`. The
coordinator merges this with [README-C6-C11.md](README-C6-C11.md). Contract requests to
other owners: [CONTRACT-REQUESTS-C1-C5.md](CONTRACT-REQUESTS-C1-C5.md). The owned
contract [identity-and-capabilities.md](../../../contracts/identity-and-capabilities.md)
was updated directly.

All 26 tickets are `blocked`: every one waits for **DESIGN-R1** (MP-REQ2). The table
says which have further blockers. "Wave" is the order inside delivery wave 1.

**U0 gate (X-58, RC-19).** Every MP-R1 ticket also waits for U0 review of the prior plan
(`docs/plans/2026-09-29-001-refactor-production-readiness-plan.md`), because RC-19 keeps
that gate for refactor work. This includes the Bucket-2-enabling chunks C2/C3 (RC-12).
U0 has no ticket ID, so the gate is stated here and in [plan.md](../plan.md), not in
`blocked_by`; the MP-R1-C11-T02 recheck does not replace it.

## Ticket table

| ID | Title (short) | Blocked by (besides DESIGN-R1) | Sub-wave |
|---|---|---|---|
| C1-T01 | Manifest, schema, ownership check, CI wiring | — | 1a |
| C1-T02 | Elixir walker, R-declared/R-private, allowlist | C1-T01 | 1b |
| C1-T03 | R-down, R-optional, SCC report | C1-T02 | 1c |
| C1-T04 | TS import walker, R-client | C1-T01 | 1b |
| C1-T05 | Ratchet enforcement (stale entries, prune, growth guard) | C1-T02, C1-T03 | 1d |
| C1-T06 | Build-queue seams; delete MP-E1 scan test | C1-T03, **MP-E1-C1-T06** | after MP-E1 |
| C2-T01 | Machine identity store at first boot | (DESIGN-R1 **S3**) | 1a |
| C2-T02 | `Aiur.Identity` facade, `instance_id` | C2-T01 | 1b |
| C3-T01 | Capability registry (table, monitor, boot_id, revision) | C2-T02 | 1c |
| C3-T02 | Core providers | C3-T01 | 1d |
| C3-T03 | `GET /api/v1/capabilities`, error encoder, concepts page | C3-T01 (DESIGN-R1 **S2, S5**) | 1d |
| C3-T04 | `aiur capabilities` verb, aiurdev routing, CLI docs | C3-T01 (DESIGN-R1 **S1**) | 1d |
| C3-T05 | `system.capabilities.changed` | C3-T01 | 1d |
| C3-T06 | `packages/aiur-contracts` + golden test | C3-T03, C1-T04 | 1e |
| C3-T07 | Optional-component providers | C3-T02 | 1e |
| C4-T01 | Registered semantic config checks | C1-T02 | 1c |
| C4-T02 | Turn-sandbox root contributors | C1-T02 | 1c |
| C4-T03 | Accessors out, pure helpers down (6 edges) | C1-T02 | 1c |
| C4-T04 | Env and global-config startup edges | C1-T02 | 1c |
| C4-T05 | Ownership data and O-config/O-env/O-state rules | C1-T01 | 1b |
| C5-T01 | `DecisionLog` → kernel `Aiur.Journal` | C1-T02, **U6 decision-journal** | after U6 |
| C5-T02 | Bounded and process signalling to kernel | C1-T02 | 1c |
| C5-T03 | `Aiur.Signal` alert + refresh port | C1-T02 | 1c |
| C5-T04 | Lifecycle telemetry through the port; Perf/LogFile reassigned | C5-T03 | 1d |
| C5-T05 | Alert emitters outside orchestrator (39 files, 69 sites) | C5-T03 | 1d |
| C5-T06 | Orchestrator alert emitters (22 files, 91 sites) | C5-T03 | 1d |

Design-gate-only after DESIGN-R1 approval: C1-T01, C2-T01 (needs S3), and everything whose
predecessors are inside this table. External blockers: C1-T06 (MP-E1-C1-T06), C5-T01 (U6).

## Dependency order

```text
C1-T01 ─┬─ C1-T02 ─┬─ C1-T03 ─┬─ C1-T05
       │         │         └─ C1-T06 (after MP-E1-C1-T06)
       │         ├─ C4-T01, C4-T02, C4-T03, C4-T04   (same file config.ex: serialize merges)
       │         ├─ C5-T02
       │         ├─ C5-T03 ─┬─ C5-T04
       │         │         ├─ C5-T05
       │         │         └─ C5-T06
       │         └─ C5-T01 (after U6)
       ├─ C1-T04 ─────────────────────── C3-T06
       └─ C4-T05
C2-T01 ── C2-T02 ── C3-T01 ─┬─ C3-T02 ── C3-T07
                         ├─ C3-T03 ── C3-T06
                         ├─ C3-T04
                         └─ C3-T05
```

## What may run concurrently

- C1-T01 and C2-T01 can start together (C2-T01 adds files; if C1-T01 merged first, the
  same PR adds them to `components.json`).
- After C1-T02: C4-T01..T04, C5-T02 and C5-T03 in parallel; C4-T01..T03 all edit
  `src/lib/aiur/config.ex` and must merge one at a time.
- After C3-T01: C3-T02..T05 in parallel. C3-T03 and MP-R1-C6-T01 both edit `router.ex`:
  merge C3-T03 first (README-C6-C11 agrees).
- C5-T05 and C5-T06 touch disjoint directories; both coordinate with MP-R2-C2-T08, which
  edits the same emitter files (second one rebases).
- C2/C3 (identity, capabilities) and C1/C4/C5 (refactor) are independent tracks.

## Test command used in the tickets

Tickets write the literal command `env -C src -u GITHUB_TOKEN -u GH_TOKEN HOME="$(mktemp -d)"
XDG_CONFIG_HOME="$(mktemp -d)" mise exec -- mix test <paths>` (Phase D replaced the `$TESTCMD`
placeholder). Run it from the root of a **worktree** (never the live
checkout), with an isolated home so `mix test` cannot overwrite
`~/.aiur/github-budget/agent-token` and GitHub tokens are not inherited:

```bash
WT=<worktree>; T="$(mktemp -d)"
env -C "$WT/src" -u GITHUB_TOKEN -u GH_TOKEN HOME="$T" \
  MISE_DATA_DIR="$HOME/.local/share/mise" MISE_CONFIG_DIR="$HOME/.config/mise" \
  mise exec -- mix test <paths>
```

The Python/shell guards (`scripts/check-components.py`, `scripts/test-check-components.sh`)
run from the repository root without that isolation. Every ticket names the production
hunk its new tests must fail without (AGENTS.md); pure renames say "n/a" and name their
regression guards as such.

## Changes to plan and chunks made by Phase C

Recorded in [plan.md §9–§10](../plan.md), [component-map.md](../component-map.md) and
[capability-matrix.md](../capability-matrix.md):

1. **C1:** T06 is now "absorb MP-E1's scan test and the X-1 seams" (RC-11). Self-tests
   no longer have their own ticket: the harness and its `workflow security` step ship in
   **C1-T01**, and each rule ticket ships its fixtures. MP-R1-C10-T04 cites "C1-T06 (checker
   self-tests in workflow security)": that reference should read **C1-T01**.
2. **C2:** `repository` and executor state moved to C3-T02 providers (layering); the
   `session_ref` builder was dropped — MP-E4 owns `SessionRef` (CQ3).
3. **C3:** revision persistence replaced by `boot_id` + in-memory revision; the
   concepts page ships in **C3-T03**, not C3-T07 (docs ship with the change).
   MP-R1-C6-T03 cites "capability concepts page (C3-T07)": it should read **C3-T03**.
   C3-T07 is now the optional-component providers.
4. **C4:** RQ4 decided: no registry-generated `embeds_one`; tickets are organised by the
   24 measured config-layer edges, not by section owner.
5. **C5:** T05 split into T05 (outside orchestrator) and T06 (orchestrator); T02 now moves
   all process signalling (answers Q-1 below).
6. Contract: CR-C6-1 applied (`run_shape.http_listener`, `run_shape.dashboard_pages`).

## Answers to the C6–C11 researcher (README-C6-C11 "Requests to the C1–C5 researcher")

- **Q-1:** accepted. MP-R1-C5-T02 moves the `reap_*`, `process_group_*`,
  `graceful_kill_process_group/1` helpers and `priv/pidfd_reap.py` ownership into
  `Aiur.ProcessTree` (kernel); `RemoteControl` delegates.
- **Q-2:** accepted. `components.schema.json` (C1-T01) allows root `features` and
  `directory_published`.
- **Q-3:** confirmed: the `aiur-contracts` schema ticket is **MP-R1-C3-T06**.
- **Q-4:** confirmed: `github/issues.ex → BuildOrder.Bounded` is fixed by C5-T02;
  `config.ex → BuildOrder.Cadence` by C4-T03 (edge E1).

## Cross-chunk items for the coordinator

- **X-1 (references):** fix the two citations in item 1 and 3 above in C10-T04 and C6-T03.
- **X-2 (overlap) — settled by RC-24:** C5-T03 owns the move and C8-T04 dropped its
  item 1. Original note: MP-R1-C5-T03 (`Aiur.Signal.refresh/0`, `subscribe_refresh/0`) and
  MP-R1-C8-T04 deliverable 1 (move `AiurWeb.ObservabilityPubSub` to core
  `Aiur.ObservabilityPubSub` owned by `event-bus`) remove the same core→web edges.
  Recommendation: C5-T03 owns the refresh hint (the prior survey's signal port #11 lists
  "a 'dashboard should refresh' hint"), and C8-T04 drops its item 1. CR-C8-2 to MP-R2 then
  records the topic as internal invalidation owned by `signal`, not `event-bus`. Either
  choice works; the two tickets must not both ship.
- **X-3:** the C6–C11 README's open item G-1/G-2 are not affected by C1–C5.

## New research questions

None blocking. Two implementation-time measurements are required by the tickets:
the 41-component baseline violation counts (C1-T02/T03 PR bodies) and the `npm ci`
cost of the TS walker in the lint job (C1-T04).

## Recurring refresh and ticket-start size ownership (RC-23)

[MP-R1-C11-T02](MP-R1-C11-T02.md)
owns this procedure. The coordinator or Executor owns the refresh cursor,
serializes research-branch writes, reviews worker drafts, and commits reports
and accepted ticket edits together on `research/refactor-findings`. Workers may
run the tool and draft edits; this process changes neither contracts nor main.

### A. After each move merges

Trigger this after MP-R1 C5–C9 moves and MP-R2/R5/R6/R7 moves changing component
paths, including indexed `components/*.json` entries. Coalesce close merges
into one range. Start the first run at `45a290e3`; thereafter use the last
**fully accepted** refresh SHA. Pin the merged main SHA and research SHA before
running, and record both plus the ledger publication SHA in the report.

From a tooling checkout containing the merged C11-T01 tool, using the repo root
selected explicitly (agent Git commands must always include `-C "$workspace"`):

```sh
python3 -I scripts/plan_refresh.py --repo "$workspace" \
  --from "$last_refresh_sha" --to "$merged_main_sha" \
  --pack docs/research/aiur-mobile-and-platform --pack-ref "$research_sha" \
  --u8-ledger "$published_ledger_csv" --out "$report_path"
```

The ledger argument is a local CSV, not a ref. Export it from U0's newest
published ledger commit, recording that commit separately. For draft validation,
omit `--pack-ref` and point `--pack` at the edited local pack. Keep the full raw
report; split large accepted reports into files of at most 500 lines under
`refresh/<sha>/`, with `refresh/<sha>.md` as the index.

For each affected ticket, including its build-order mirror:

1. `MOVED` and `LINES-SHIFTED`: update citations only after checking the destination
   and cited code at the merged SHA. A combined `LINES-CHANGED` or `SPLIT?` needs
   semantic review before any mechanical replacement.
2. `LINES-CHANGED`, `SPLIT?`, `GONE`: read the new code and rewrite Verified starting
   point. If it invalidates the design, retain existing blockers, add
   `REFRESH-<ticket>-<sha>` and set `status: blocked`; notify the feature owner.
   An unresolved abbreviated or proposed path is not automatically a regression.
3. Append `Refreshed against <sha> on <date> (MP-R1-C11-T02).` to Verified starting
   point only after its review; list the reviewed scope when other citations still
   belong to the old baseline. Change `base_sha` only when **every** citation has
   been verified. Never advance the global cursor with semantic reviews pending.
4. Update migration-plan §4 only for verified completed moves: record
   `moved (<sha>)` and the real target. File survival or a proposed component name
   alone does not prove a migration step shipped. Preserve partial/unresolved rows.
5. Compare all cited contract status/date metadata against the previous accepted
   report or pinned research commit; list changed contracts and citing tickets for
   their owners. The tool reports four contract records; inspect remaining cited
   contracts separately. Do not edit owner contracts or infer missing metadata.
6. When the range touches `orchestrator/issue_sync.ex`,
   `orchestrator/dispatch_policy.ex`, `github/labels.ex`, or `github/issues.ex`,
   re-resolve their current paths and inspect MP-E1-C1's named hooks from its tickets.
   Verify marker recognition, readiness guards, heal exemptions, and the queue's
   single label-writer seam and callers. A grep match alone does not prove the
   queue still calls the seam. Missing hooks go to the move owner as regressions;
   never silently repoint or recreate them here.
7. Commit the accepted report and edits together after coordinator review. Record
   pending owner reviews in the index. A reverted move is handled by the next
   reverse range; a stale-citation worker may draft a ticket-only refresh for the
   coordinator to fold in. Serialize with other research editors.

The current tool compares coordinates at `--from` with `--to`; it does not know
which local citations already refer to `--to`. Replaying the same range is a
reproducibility check, **not** an all-OK acceptance check for shifted citations.
Check refreshed citations directly with `git -C "$workspace" show <sha>:<path>`;
use a target-to-target run only for existence/owner checks, and do not interpret
its OK rows as proof of citation meaning. Until tool replay semantics are enhanced,
record this limitation explicitly rather than claiming an all-OK replay.

### B. At every MP ticket start (binding RC-23)

Run before dispatch/transition from ready to in-progress, including MP-R1's later
tickets. `ready` in this pack means researched; gates and predecessors still apply.
The Executor records each admission in the refresh index with ticket, current main
SHA, intended edited files and owner outcome. Recheck after scope or ledger changes.

1. Identify **edited** files from Implementation steps and actual scope; cited files
   that will not be edited are excluded. The tool scans all citations and therefore
   supplies candidates, not the admission decision. Include new files and tests.
2. Count LF bytes plus one for a nonempty unterminated last line at pinned current
   main. Record predicted final size too. A file at most 500 lines that stays at
   most 500 needs no owner. New or small files may not cross 500; split the work.
3. For every oversized edited file, look up its current path in the newest
   U0-published U8 ledger. Record `size_owner: <package> (<path>, <lines> lines at
   <main sha>, ledger <ledger sha>)`; list all owners when several files qualify.
   Missing row means `UNASSIGNED`: ask U0 and hold that edit before admission.
   MP tickets consume the ledger and never edit it.
4. If the transitional size gate is installed, write the measured no-growth ceiling
   in Compatibility and rollout. Use today's count, not a research-time ceiling.
   Oversized files must remain the same length or shorter; put new code/tests in
   small files. A no-longer-oversized file needs no historical owner.
5. Record the decision in the canonical ticket and build-order mirror. Review one
   oversized example against the actual CSV row and spot-check three refreshed
   citations at the recorded SHA before accepting a refresh.
