---
pageClass: cli-reference
---
# CLI operations

## Inspect and operate a running daemon

A `workspace_retained` row means provider exit is unproven, or the recovery audit could not be written. It reports the retention age (or `since unknown` for leases saved before retention tracking) and raises one `workspace_lease_retained` attention per lease.

Time alone never releases the lease, and a release call that times out returns `{:error, :release_timeout}`.

Use `aiur stop` for graceful provider containment; restarting alone does not clear persisted ownership. Only a local hold with verified reboot proof is eligible for `aiur workspace-recover <ticket-identifier> <generation>`.

A `workspace_ownership_waiting` row reports the held generation and provider-exit proof state. A reboot changes a local hold with recorded boot ID to `boot_changed_release_pending`. The guardian releases it automatically after writing its durable recovery audit record.

Before release, the daemon appends and fsyncs an audit record with actor, ticket, generation, proof, and timestamp to `workspace-ownership/workspace-recovery-audit.ndjson` in its state directory. Automatic releases identify the guardian; operator retries identify the daemon's OS account.

If writing fails, the lease stays held and status names `aiur workspace-recover <ticket-identifier> <generation>` as the retry command; legacy receipts, remote providers, same-boot holds, and unreadable boot IDs are ineligible.

| Syntax | Default or important interaction | Runnable example |
| --- | --- | --- |
| `aiur help` | Prints the current launcher usage. | `aiur help` |
| `aiur doctor [--repair]` | Reports mise shims pointing into agent build-bin directories. `--repair` explicitly consents to regenerating shims with the real mise binary. Startup and `status` also warn; they never repair automatically. | `aiur doctor --repair` |
| `aiur status` | Shows daemon, Decision projection health (stale timestamp and age, or `age unknown`), and capacity status, including `WAKES CURSOR <id> PENDING <count>` for the durable Executor inbox and `AGENTS occupied/max (binding: ...)`. Dispatch admission names Linux CPU PSI `some avg60` pressure in percent and its ceiling, or explicitly identifies the load fallback when PSI is unavailable. Memory holds name available MB and the configured floor. The `DISPATCH LOAD` line remains a diagnostic alongside pressure; high load alone does not hold dispatch while PSI is available. Every admission measurement carries `sampled=<n>s ago`, the age of the reading it was taken from, and gains a trailing `STALE` once the daemon has not refreshed it within two poll intervals (never sooner than a minute, never later than five) — so a `load=` figure minutes older than the live `LOAD` line beside it is visible as such rather than reading as current. A GitHub quota hold includes its resource, measured remaining/limit, and observation time, and becomes `github_quota stale` after two missed probes. Other bindings include `config max_concurrent_agents`, `AIMD envelope`, `paused reservations`, `ticket supply`, `session max_concurrent_agents`, or `none`; `ticket supply` means a recent poll found no queued ticket; `idle backoff active (no dispatchable demand at last poll; polling.idle_widen_factor=5.0, next poll in 599s; ...)` means the last poll found nothing and the daemon widened its cadence by design — the countdown is `polling.intervals.dispatch × polling.idle_widen_factor`, and `aiur --todo <id>` collapses it; `has not polled yet` is shown only when the last tracker fetch failed. When slots are free, the binding also names the effective ceiling's source (`ticket supply; ceiling: config max_concurrent_agents` vs `idle backoff active (...; ceiling: session max_concurrent_agents)`) so a restart that dropped a live `set max-agents` reads as config-sourced rather than as the operator's last command. When a build-gate lease is held or queued, `status` also prints `BUILD GATE HOLDER slot=… pid=… command="…" held=…` (and `BUILD GATE QUEUED … waiting=…`) so a pinned lease is attributable without reading process trees. | `aiur status` |
| `aiur workspace-recover <ticket-identifier> <generation>` | Releases only the named held workspace generation after the daemon verifies its recorded local boot ID changed. Read the ticket identifier and generation from status; a live lease, stale generation, same-boot hold, or missing proof is refused. The audit log and workspace ownership telemetry record successful recovery. | `aiur workspace-recover ENG-123 7` |
| `aiur capabilities [--json]` | Reports identity, repository, Executor and sorted capability states, reasons and dependencies, with observation age and freshness. JSON matches the HTTP report. Works with `--no-dashboard`; needs a running daemon. Reports exit 0 even when capabilities are unavailable. | `aiur capabilities --json` |
| `aiur usage` | Prints provider-meter observations, known headroom, and available reset times. Retained stale readings carry a `[stale]` label alongside their observation age; Muse readings identify the current host and unverified account. | `aiur usage` |
| `aiur github-cost` | Ranks GitHub API spend by the call site that caused it, in points and points per hour, and prints the reconciliation against the credential's own window beside it. Prints the admission ledger's retention window (one rolling hour) on the same screen, so the ledger is never reconciled against a longer `/rate_limit` span. Reads the meter the daemon already keeps and issues no GitHub request of its own. Defaults to the `graphql` budget. | `aiur github-cost` |
| `aiur github-cost --budget core` | Selects one budget: `graphql`, `core`, or `all`. The two budgets are never summed into one number because GitHub bills them separately, on separate windows. | `aiur github-cost --budget core` |
| `aiur github-cost --format records` | Chooses `auto`, `table`, or line-oriented `records` output. | `aiur github-cost --format records` |
| `aiur github-cost --json` | Emits the ranking as one versioned envelope. | `aiur github-cost --json` |
| `aiur github-usage` | Prints per-actor (daemon vs each agent workspace) GitHub usage: Core, GraphQL and `search` `used`/`limit` with reset times, read from the shared admission broker's `admissions`. Limits are request-count ceilings (the broker sees requests, not GraphQL points); `0` in the config means no ceiling. Issues no GitHub request of its own. | `aiur github-usage` |
| `aiur github-usage --json` | Emits the per-actor usage as one versioned envelope. | `aiur github-usage --json` |
| `aiur agents` | Prints each active agent's state and current activity, including startup and scheduled retries. `starting` means a worker was dispatched but no provider turn has started. `retrying` means no worker is live; the row includes the last failure reason and time when known. `aiur status` and `aiur watch` use the same startup and retry distinction. A Codex process that exits before handshake also leaves its numeric exit status and a bounded, redacted diagnostic in the daemon's `<logs-root>/log/<repo>.<ticket>.startup-failures.ndjson`, correlated with the `agent_spinup` telemetry attempt. The file retains the last 50 records. An agent with an open decision, or one that asked for input, reads `waiting` with `(waiting_for_human: <cause>)`, the same wait `aiur status` prints as `waiting=waiting_for_human`. A `rework` label alone is agent-owned work and never reads as waiting for a human. | `aiur agents` |
| `aiur units` | Reads the Dashboard Units projection. Choose `--scope live\|unfinished\|all\|none`, repeat `--condition active\|alert\|paused\|queued\|finished` (`queued` means waiting for dispatch or retry, unrelated to `agent:queued` membership), choose `--format auto\|table\|records`, or add `--json`. | `aiur units --scope unfinished --condition active` |
| `aiur units --condition alert` | Repeats to require any of the selected Unit conditions. | `aiur units --condition alert --condition paused` |
| `aiur units --format records` | Chooses `auto`, `table`, or line-oriented `records` output. | `aiur units --format records` |
| `aiur watch` | Shows changed fleet rows by default. | `aiur watch` |
| `aiur watch --full` | Prints all fleet rows. | `aiur watch --full` |
| `aiur watch --changes` | Makes the changed-rows default explicit. | `aiur watch --changes` |
| `aiur watch --once` | Requests the one-shot form. | `aiur watch --once` |
| `aiur watch --interval 5` | Re-renders until interrupted. The interval must be a positive number of seconds. | `aiur watch --interval 5` |
| `aiur alerts` | Shows every open attention item plus the latest 100 other retained alerts, oldest first, with an `event: "alert_feed_truncated"` JSON notice when older rows are omitted. `--limit <n>` (positive integer) changes that cap; `--all` removes it. Repeated active attentions carry the latest event’s `timestamp` and text; `first_seen_at` retains the opening time. | `aiur alerts` |
| `aiur alerts --needs-attention` | Filters to unresolved alerts requiring Executor action. Never truncated. | `aiur alerts --needs-attention` |
| `aiur set max-agents 6` | Changes the live session cap without editing config. The new cap applies to live state at once (`status` reflects it), and a raise pulls the next scheduled dispatch cycle forward without crossing the GitHub poll floor. Lower or unchanged caps keep the cadence. It does not rewrite the next launch's config; a restart drops it, and `aiur status` then shows the ceiling as `config max_concurrent_agents` rather than as the operator's last command. | `aiur set max-agents 6` |
| `aiur pause` | Turns on the global pause switch. It stops new provisioning and cooperatively holds the fleet. The switch is persisted with its source and survives restart; a failed persisted-state read starts paused. | `aiur pause` |
| `aiur resume` | Turns off that global switch. Lifting the pause schedules a prompt poll, so a ramp resumes dispatch within one base interval rather than waiting out the idle poll backoff. | `aiur resume` |
| `aiur pause 142 143` | Requests a safe-boundary pause for named tickets. | `aiur pause 142,143` |
| `aiur pause --all` | Requests a pause for every active ticket. | `aiur pause --all` |
| `aiur resume 142` | Resumes a paused ticket, including one whose pause is still pending, or starts an idle eligible ticket. It also reactivates a deactivated agent and starts a new worker for a completed one, as the dashboard and API do, and names the prior state (`was: deactivated`, `was: completed`). It reports `already running` only when a live worker is working the ticket, and `already running (sleeping ...)` for an idle agent whose stream closed. A queue-held idle ticket reports `build_queue_hold`; use `aiur queue release` first. It refuses by name an agent whose worker failed to start (the retry schedule owns that restart), an agent whose worker is gone, and an idle ticket held by an open blocking decision, which it names by id; answer the decision, then resume. | `aiur resume 142` |
| `aiur resume --all` | Resumes every individually paused ticket. | `aiur resume --all` |
| `aiur reset-budget 142` | Clears a named ticket's dispatch-budget latch. It does not accept `--all`; `resume` cannot clear this latch. | `aiur reset-budget 142` |
| `aiur message 142 "Check review"` | Enqueues Executor text on the native agent queue. Aiur may interrupt at a safe point, queue it for the next turn, auto-resume a paused entry, or reactivate a deactivated entry. Text must be nonblank and at most 8,000 characters. The command reports what it observed: `delivered message to #142` once the agent has claimed it, otherwise `queued message for #142 (request N); delivery is unconfirmed`. Both are successful enqueues and exit 0 — a queued message is normally claimed at the agent's next checkpoint. | `aiur message 142 "Check the latest review"` |
| `aiur message 142 --message-id ID "Check review"` | Names this send. A repeat with the same id, ticket and text returns the first copy and queues nothing new. The same id with other text is refused. Use it only to retry a send whose outcome was unknown. | `aiur message 142 --message-id cli-1a2b "Check the latest review"` |
| `aiur stop` | Gracefully stops the BEAM and its tmux lifetime session, reaping agent process trees and workspace-rooted descendants before a final launcher backstop removes stragglers. A stopped daemon makes `stop` and `--todo` exit nonzero. | `aiur stop` |
| `aiur restart` | Stops the running session, refreshes the release, and starts it again detached. See [Restart semantics](#restart-semantics). | `aiur restart` |
| `aiur restart --no-build` | Bounces the daemon on whatever release is already on disk. Use it for a fast restart, or to bounce without taking uncommitted source edits live. It has no effect on the installed `aiur`, which never builds. It cannot rescue a failed development rebuild: that removes the incomplete release, so there is nothing left to start, and `restart` says so instead of suggesting it. | `aiur restart --no-build` |
| `aiur upgrade` | Installs the newer `aiur-cli` on your channel (`latest`, `next`, or `nightly`) and reports the version before and after, with the restart step to actually pick it up. Refuses under the `aiurdev` development launcher (`scripts/aiurdev upgrade`), for Homebrew installs (releases are npm-only right now), and while a daemon is running — pass `--force` to upgrade a live install anyway. It never downgrades: a `nightly` or `next` user is measured against their own channel, never against a lower `latest`. | `aiur upgrade` |
| `aiur upgrade --force` | Upgrades even while a daemon is running. The running daemon keeps the old code until you restart it; in-flight agents are unaffected until then. | `aiur upgrade --force` |
| `aiur cleanup-stale` | Lists and reaps stale manual-smoke processes and sockets. | `aiur cleanup-stale` |
| `aiur cleanup-stale --dry-run` | Reports stale leftovers without reaping them. | `aiur cleanup-stale --dry-run` |

Waiting rows in `aiur agents`, `aiur status` and `aiur watch` append the reason, owner and elapsed age, for example `· backing_off · RetryEngine · 45s`. Idle tickets appear alongside running workers and retries.

An unrecorded start reads `since unknown`, never zero. Dependency and lifetime-latch waits always read `since unknown`: a blocker edge has no recorded start, and the latch stores only a dispatch count.

`status`, `agents` and `watch` always print the fleet snapshot age, including fresh snapshots, as in `FLEET SNAPSHOT 2s old` and `CAPACITY OBSERVATION 2s old`. Rows carry their own observation age. A missing observation renders `age unavailable`, never zero. Retry rows read `since daemon start <UTC time>`, because retry state resets on daemon restart.

The JSON `observations` map covers fleet, capacity, per-ticket tracker data, retries and the dispatch sample; each has `observed_at` and `age_ms`. Capacity slot counts use the captured state time; cached load fields use `capacity.dispatch_observation`. Durable launch evidence lives in the run log directory's `<repo>.<ticket>.startup-failures.ndjson`.

The status JSON payload adds `waiting: {reason, owner, cause, since, age_ms}` to running, retry and idle rows. Unknown causes use `unknown`; unknown timestamps and ages are `null`. Ages describe the snapshot's observation.

Existing `waiting_reason` atoms remain unchanged. A pending lifecycle fence changes the owner, cause and since, and adds sorted `pending_item_ids` to JSON and text output. Review events queued for a completed worker start its replacement at once, so a new turn can acknowledge delivery; live workers keep their provider-delivery fences during long turns.

For completed or exited providers, a fence expires on the first dispatch poll two minutes after its first pending input, so lifecycle reconciliation continues without claiming delivery succeeded; the `lifecycle_fence_expired` alert names the stuck IDs. Unacknowledged failed or claimed items return to pending for rework; acknowledged items are not replayed.

Per-ticket `aiur resume` and `aiur reset-budget` perform tracker reads and label writes outside the orchestrator process, so slow tracker requests do not hold up its control calls. Budget changes and resume eligibility checks remain serialized in the orchestrator.

If the orchestrator does not answer a per-ticket `aiur resume` or `aiur reset-budget` mutation in time, the command exits 124 and reports `outcome unknown`. The queued request may still apply after the command exits. Check the ticket status and log before retrying; a reset is confirmed by its completed dispatch-budget reset alert.

If the daemon does not answer `aiur message` in time, the command prints `outcome unknown`, the send's message id and the exact retry command, and exits 124. The daemon may still queue the message. Check the ticket log first: a queued message is logged with the tag `queued item=N`.

Only a retry with the same `--message-id` is safe. It returns the first copy instead of queueing a second one. The same text sent without that id is a new message. The HTTP API accepts an optional `message_id` too; a request without one is never deduplicated.

### Restart semantics

| Restart case | Result |
| --- | --- |
| Installed `aiur` | Bounces the pinned release without building. |
| Development release | Refreshes between stop and start, then boots current code. |
| Daemon already stopped | Starts it. |
| Daemon still answers after stop | Aborts rather than rebuilding underneath it. |

Any failure after the stop, whether a failed rebuild, a failed start, or an interrupt, reports that the daemon is stopped and was not restarted. Restart uses the same graceful agent-tree and workspace-descendant reap as `stop` before refreshing or starting the release.

A restart can make Aiur delete or recreate a ticket workspace that still has uncommitted changes or commits not held by a remote. Aiur saves local work first; see [Saved uncommitted work](#saved-uncommitted-work).

Under `scripts/aiurdev`, `restart` verifies that the refreshed release came from the expected checkout and commit.

| Development refresh evidence | Result |
| --- | --- |
| Rebuild verified against the expected checkout and commit | Starts the rebuilt release. |
| Rebuild cannot be verified | Leaves the daemon stopped, exits with code 70, and names the unconfirmed builder. |
| Custom build command without verification support | Starts and reports the result as unverified. |

### Saved uncommitted work

Before Aiur deletes or recreates a local ticket workspace that has uncommitted changes or commits not held by a remote, it saves them in `wip-preserved/<workspace>/<timestamp>/` under the runtime state directory. The directories have mode 0700 and the files 0600, because untracked files can hold secrets.

Each save holds these files:

| File | Content |
| --- | --- |
| `tracked.patch` | A binary patch of the staged and unstaged tracked changes. |
| `untracked.tar` | The untracked files that are not ignored and are within the size bounds. |
| `unpushed-commits.bundle` | The commits that no remote-tracking ref holds, if there are any. |
| `manifest.json` | HEAD, branch, file lists, `skipped_untracked` and the restore commands. |

The save has bounds, set by the `workspace.wip_*` keys in the [configuration reference](/reference/configuration#workspace). A skipped untracked path is listed with its size under `skipped_untracked`. A skip never stops the delete.

The restore commands apply the patch to the current HEAD, so they work also when the old branch was deleted after a squash merge. Only a bundle brings old commits back, on a local `aiur-wip/<timestamp>` branch.

The next agent turn of the same ticket starts with the restore commands, and `ticket.<n>.workspace.wip_preserved` gives the path. Delivery is at least once: after a crash, the notice can repeat. If the ticket closes first, the notice expires and a reopened ticket does not get it.

If the save fails, Aiur keeps the workspace. An open ticket stays paused as a preflight failure until an Executor resume. A closed ticket's save that times out is the exception: Aiur writes a manifest-only save, deletes the workspace and raises `ticket.<n>.workspace.wip_preservation_incomplete`.

Aiur cannot save the work of a dirty workspace on a remote worker, so it keeps that workspace. Each workspace raises `ticket.<n>.workspace.wip_preservation_failed` once for each reason, and the message says whether the ticket is held or closed.

To delete a kept workspace without a save, create the empty file `wip-preserved/<workspace>/discard-dirty-workspace` under the runtime state directory. Then resume the ticket, or restart Aiur for a closed ticket. Aiur deletes the workspace, raises `ticket.<n>.workspace.wip_discarded` and removes the file.

The discard file is a deliberate operator signal outside the workspace, not an access control. Agents run as the same Unix user without a filesystem sandbox, so an agent can create the file too. It gives no capability that the same user does not already have. Real isolation needs a sandbox, which Aiur does not provide.

If a closed ticket's cleanup crashes before the delete, Aiur keeps the workspace. The terminal sweep at the next Aiur start tries again. If a new run of a reopened ticket holds the workspace when the delete is due, Aiur keeps the workspace and the save, and the notice does not expire.

To recover saved work by hand, run the `restore_commands` of `manifest.json` in order in a clone of the repository. Change the first command, `cd`, to point at that clone.

## Build history epic commands

Overrides are local: these commands never write GitHub labels or report effective epics, and agents use `aiur_set_epic` with daemon-bound identity.

| Command | Behavior |
| --- | --- |
| `aiur epic set <epic> <ids…> [--source cli\|backfill-agent] [--as <who>] [--json]` | Atomic, up to 200 IDs (optional `#`; duplicates count once). Only configured general epics; feature epics and `unsorted` are refused. |
| `aiur epic clear <ids…> [--as <who>] [--json]` | Remove overrides; absent entries are unchanged. |
| `aiur epic show [<ids…>] [--json]` | Stored epic, actor, source, confirmation, time. Removed keys are ignored; unreadable config gives `epic_known: null`. |
| `aiur epic list [--json]` | Configured keys and labels in order. Config errors refuse writes and list without defaults. |
| Identity | Actor defaults to `cli:$USER`; `--as` accepts 1–64 letters, digits, dots, underscores or hyphens. Source defaults to actor; `backfill-agent` is unconfirmed. CLI cannot claim agent identity. |
| Repeats | Same epic/source/confirmation is unchanged. Changed results and journal retain the previous assignment. |
| Recovery | Unsafe journals are unavailable. Move corrupt `epic-overrides.json` aside in the instance’s `epic-overrides` directory, then restart; GitHub cannot rebuild overrides. First-write sync failure after rename leaves reads/writes unavailable until restart. |
| Exit codes | 0 success; 1 refusal/unavailability; 64 usage; 124 RPC timeout with unknown outcome. Retrying an identical set is safe. |

## Dashboard page commands

`aiur units`, `aiur commands`, `aiur build-orders`, and `aiur analytics` are read-only terminal forms of the corresponding Dashboard pages and show the same data.

| Command | Page view and important inputs | Example |
| --- | --- | --- |
| `aiur units` | Filtered Units catalog; use `--scope`, repeated `--condition`, `--format`, or `--json`. | `aiur units --scope unfinished --condition alert --json` |
| `aiur commands [decision-id]` | Durable decision inbox, or one selected decision. Use `--filter all\|open\|blocking\|resolved`, `--blocking`, `--ticket`, `--search`, `--cursor`, `--limit`, and `--json`. `--ticket` and `--search` require `--filter all`. | `aiur commands --filter blocking --json` |
| `aiur queue show [--queue NAME] [--json]` | Read held queue state, start order, prerequisites, progress, and source ages; optionally select a named queue. | `aiur queue show --queue paseo --json` |
| `aiur queue add <ids…> [--after N] [--queue NAME] [--at POS] [--start-on TRIGGER]` | Adds tickets to a list (default name: `default`); `--after` adds local prerequisite edges; positions are zero-based. | `aiur queue add 142 143 --queue paseo --after 141 --at 0` |
| `aiur queue add --build-order <root> [--queue NAME] [--start-on TRIGGER]` | Adopts a Build Order root, optionally naming its queue and selecting its start trigger. | `aiur queue add --build-order 141 --queue roadmap` |
| `aiur queue set <queue> --start-on <trigger\|default>` | Sets the queue prerequisite trigger: `issue_closed`, `pr_merged` (default), `pr_approved`, `pr_ci_green`, or `pr_opened`. Later stages satisfy earlier triggers; `default` follows config. Existing lists reject a different override on `add`; use `set`. Invalid values exit 64. JSON includes `start_trigger`, `start_trigger_source` (`queue`/`config`), `start_trigger_override`, and prerequisite `stage`/`trigger`/`optimistic`. Tightening withdraws unclaimed todo; running agents continue. | `aiur queue set paseo --start-on pr_opened` |
| `aiur queue remove <ids…>` | Removes list members and their membership markers. | `aiur queue remove 142 143` |
| `aiur queue reorder <id> --to POS` | Moves one ticket within its list to a zero-based position. | `aiur queue reorder 143 --to 0` |
| `aiur queue hold <id\|--queue NAME>` | Persists an item or whole-queue hold, stopping promotion. | `aiur queue hold --queue paseo` |
| `aiur queue recover [--force]` | Rebuilds missing/corrupt state from open queued markers as an ordered, held list; force discards healthy saved order and edges. | `aiur queue recover` |
| `aiur queue clear --remove-markers --yes` | Dequeues all items and removes queued markers from every open issue, keeping todo. | `aiur queue clear --remove-markers --yes` |
| `aiur queue release <id\|--queue NAME>` | Clears holds and overrides on the selected item or every member of the named queue. | `aiur queue release 142` |
| `aiur build-orders [root]` | Build Order catalog without a root; one root adds graph, execution, and activity detail. | `aiur build-orders 1567 --json` |
| `aiur analytics` | Analytics snapshot, including whole-host fleet/build pressure. Human output reports peaks, latest measured capacities, the binding admission signal with measured load, and longest live build wait; `--json` includes the timestamped pressure series. Choose `--range run\|full`, an ISO-8601 `--since`/`--until` window, an optional numeric `--build-order`, or `--json`. | `aiur analytics --range full --build-order 1567 --json` |
| `aiur analytics --range full` | Selects the current run or all retained analytics observations. | `aiur analytics --range full` |
| `aiur analytics --since 2026-08-01T00:00:00Z` | Sets the inclusive ISO-8601 start of an analytics window. | `aiur analytics --since 2026-08-01T00:00:00Z` |
| `aiur analytics --until 2026-08-02T00:00:00Z` | Sets the exclusive ISO-8601 end of an analytics window. | `aiur analytics --until 2026-08-02T00:00:00Z` |
| `aiur analytics --build-order 1567` | Limits analytics to one numeric Build Order root. | `aiur analytics --build-order 1567` |

### Output contract

Every `--json` result is one versioned envelope with `schema_version`, `page`, `snapshot.captured_at`, `request`, `sources`, `data`, and `auxiliary`. `snapshot.captured_at` is when the command ran; it is not a claim that every source was observed then.

`aiur build-orders --json` uses schema version 2. Its completion objects report `progress_resolution: "empty"` with `progress: null` when a Build Order has no members, distinguishing an observed empty plan from 0% progress.

Member, wave, lane, and graph completion objects on a selected root also carry `progress_stale_count` and `progress_stale_observed_at`. These report the number of resolved members using a last-known activity reading, rather than a live reading or accepted lifecycle completion, plus the oldest such reading.

Human output prints the same state as `80% (last known 12m ago)`, measured from `snapshot.captured_at`. An open member with no usable activity reading is `unresolved`, rather than a resolved 0%.

A member closed without completing (not planned, duplicate, cancelled) is resolved 0% regardless of any earlier reading. Catalog root completion is lifecycle-derived and does not carry these fields.

`aiur build-orders <root>` requests a read when its graph is missing or stale, without requiring the Dashboard open. Concurrent reads coalesce and provider retry delays still apply. The command returns the held graph while refresh runs, preserving its observation time and stale status.

For a missing graph, `data.graph.status` and `sources.planning_graph.state` are `loading`. Run the command again to get the completed read. `provider_unavailable` means that a read failed.

Each source reports `state`, `observed_at`, `age_ms`, `freshness`, `partial`, and machine-readable `reasons`, while human output prints the same labelled state and age because a number without observation age is not actionable.

Fleet-capacity and build-gate evidence have independent source states: stale fleet samples do not erase current build measurements; unavailable daemon process metrics do not erase whole-host pressure; and missing values remain `null` in JSON and `unavailable` in human output rather than becoming zero.

| Source condition | Output contract |
| --- | --- |
| Unavailable, stale, partial, invalid, or unknown observation time | Remains `null` or field-level status in JSON and a labelled warning in human output; it never becomes `0`, `[]`, or `{}` merely because the command could not measure it. |
| Observed empty source or valid zero-result filter | May return an empty collection. |
| Separately derived value, such as provider spend | Lives under `auxiliary` with its own source metadata. |

## Experiments

[Experiments](../concepts/experiments) use control RPC and require a running daemon.

| Command | What it does | Example |
| --- | --- | --- |
| `aiur experiments list [--status <status>] [--kind before_after\|ab] [--json]` | Lists experiment summaries; corrupt specs appear as unreadable rows. | `aiur experiments list --status active --json` |
| `aiur experiments show <id> [--json]` | Shows spec, phase, journal tail, annotations, snapshot references and read-only state. | `aiur experiments show delivery-change --json` |
| `aiur experiments create --from <file\|-> [--draft] [--no-freeze] [--json]` | Imports a JSON spec from a caller file or stdin. Repeating a spec key returns the existing experiment. | `cat spec.json \| aiur experiments create --from -` |
| `aiur experiments create --title <title> --line <type>:<ref>[@time] --metric <pack>/<metric>[:direction]` | Creates a before/after experiment; repeat `--metric` to add metrics. Direction defaults to decrease. | `aiur experiments create --title smoke --line manual:smoke@2026-10-09T00:00:00Z --metric delivery-speed/start_to_merge:decrease --draft` |
| `aiur experiments create --draft` | Creates a draft rather than the default active status. | `aiur experiments create --from spec.json --draft` |
| `aiur experiments create --no-freeze` | Suppresses the default baseline-freeze request and its unavailable warning. | `aiur experiments create --from spec.json --no-freeze` |
| `aiur experiments create --hypothesis <text>` | Sets the quick-form hypothesis; default is empty. | `aiur experiments create --title smoke --line manual:smoke@2026-10-09T00:00:00Z --metric delivery-speed/start_to_merge --hypothesis faster` |

Quick creation also accepts `--hypothesis`, `--draft`, `--no-freeze` and `--json`; manual lines need a UTC timestamp, while tag/commit times can resolve from base history.
JSON stdout contains the facade result; stderr carries errors and unavailable-freeze warnings. Exit codes: 0 success, 1 refused, 64 invalid usage. Newer specs refuse writes.

## Operational facts that change an incident response

| Fact | Response |
| --- | --- |
| **Dispatch needs `agent:todo`.** | `AGENTS 0/32 (binding: ticket supply)` means a recent poll found no queued ticket. If it instead reads `idle backoff active (... polling.idle_widen_factor=5.0, next poll in ...)`, the daemon has not looked since its last idle poll — run `aiur --todo <id>` (which wakes a prompt poll and keeps the base cadence until the ticket is seen), add the label, or trigger a refresh so the work is seen. `has not polled yet` means the last tracker fetch failed. |
| **Global pause is durable.** | Use `aiur status` and `aiur resume` before treating a silent restarted fleet as broken. |
| **CI readiness uses an operator-only token.** | Run `aiur init` with `AIUR_CI_READINESS_TOKEN` that can read repository contents, Actions, and administration settings. Init saves a non-secret assessment beside `.aiur/config`; the normal launcher removes the token before starting the daemon and agents. Repeat init when the assessment expires or the repository's CI rules change. |
| **A base refresh affects approval ownership.** | With `require_last_push_approval`, route a base refresh through the ticket agent so the Executor does not become the ineligible last pusher. |

### aiur queue
`aiur queue show` reads the running daemon without refreshing upstream data. Human output shows source ages and freshness, `start on <trigger>` (`(default)` follows config), and items in start order with needed/current stages or `optimistic`. Missing evidence renders as `unknown`; stale evidence carries its age. See [Start trigger](/concepts/build-orders#start-trigger) for the ladder and review-read cost. `--queue NAME` selects a queue by name; an unknown name is an error.

`--json` emits schema version 1 (`page: "build-queue"`): instance, snapshot capture time, server status, sources, and queues with progress and item prerequisites, rank, promotion time, and attention. It includes no ticket titles or bodies.

Mutations print each ticket's outcome; partial success exits 1 and names refusals. Agent workspace mutations and invalid arguments exit 64. Engine and daemon guards block workspace changes; dispatch authorization still applies. Timeouts exit 124: run `aiur queue show` before retrying. Build Order queues cannot be edited as lists.

Clear persists unmark intents before paced writes; crashes resume on restart. A budget hold reports `writes_paused`; rerun after it lifts. Wait for successful clear before downgrading; `agent:todo` remains dispatchable. The build queue uses the `agent:queued` membership marker; `aiur units --condition queued` still means tickets carrying `agent:todo`.

`queue show` exit codes: 0 for `running` or `writes_paused`; 1 for `disabled`, `unsupported_tracker`, `store_unavailable`, or a refused selection; 64 for invalid launcher arguments; 124 for an RPC timeout. Refusal statuses still print their read model.
