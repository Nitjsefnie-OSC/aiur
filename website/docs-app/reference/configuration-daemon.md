# Daemon configuration

Configuration lives in `.aiur/config` (YAML), and `prompt_file:` and `hooks_file:` point at sibling files. With no local config, Aiur uses `~/.aiur/config` without per-repository init.

Global GitHub startup announces its current-origin target and ensures workflow/marker and complexity labels, without creating model labels.
Omit `tracker.github.repo` for portable defaults; a conflicting explicit repo fails safely. Shared credentials can live in `~/.aiur/.env` using the precedence below.

Older root-level config files are rejected. When moving one, also move the files it references, or rewrite their paths so they still resolve from the new config directory. Supported secret and workspace-root fields resolve `~` and `$VAR` values; other path fields do not generally expand environment references.

## Environment variables

Environment variables are declared once in the env schema (`Aiur.Env.Schema`), which validates them at startup and generates the checked-in `.env.example` (run `mix aiur.env.example` from `src/` to regenerate; a CI check fails when the example drifts from the schema).

- **Layering.** Shell exports win, then `./.env`, then `~/.aiur/.env`: the launcher reads the repository file first and each file fills only unset names, so the home file only fills the gaps. A blank value such as the `GITHUB_TOKEN=` placeholder `aiur init` writes is not a setting and shadows nothing. GitHub credentials (`GITHUB_TOKEN` and the `GITHUB_APP_*` set) resolve as one group: when `./.env` sets any of them, every GitHub credential in `~/.aiur/.env` is ignored, so a machine-wide App never outranks the token a repository configured for itself. When the home value loses either way, the daemon logs a startup warning naming the variable (never its value).
- **Required vs optional.** The only configuration that aborts a boot is the GitHub credential (`GITHUB_TOKEN`, a `gh` keyring login via `gh auth login`, or the complete GitHub App set — `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, and one of `GITHUB_APP_PRIVATE_KEY_PATH` / `GITHUB_APP_PRIVATE_KEY`) and the tracker configuration. Every integration — GitHub App auth, webhooks, Linear, voice, dashboard, Supervisor Decision API, provider keys — is optional; absence disables the feature and is reported once at startup, never a boot failure.
- **All-or-nothing credential groups.** A partially configured group (one dashboard credential without the other, or some but not all GitHub App credentials) fails at startup naming the missing members; a fully absent group is a supported setup.
- **Type validation.** Values that fail their declared type (for example `AIUR_OPENCODE_BRIDGE_PORT=banana`) abort the boot naming the variable and what was expected, instead of failing at first use hours later.
- **Secrets never leak.** Secrets render as an empty placeholder in `.env.example` and are excluded from error text and startup warnings. No real value from any `.env` file reaches the generated example, logs, or error output.
- **Dashboard credentials** (`AIUR_DASHBOARD_USERNAME` / `AIUR_DASHBOARD_PASSWORD`) are values an operator chooses and types into a browser; see [GUI](/guide/gui) for choosing and setting them. Without them the dashboard refuses all requests (fails closed); the CLI and TUI are unaffected.

The generated `.env.example` groups variables under `## Required`, `## Optional - ...` (one section per integration), `## Runtime - launcher-managed`, and `## Development and debugging` headers, with a one-line purpose above each key and a terse right-hand "how to fetch" note aligned to a common column.

## Top-level
| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `max_vertical_panes` | integer | 3 | Caps visible agent chat panes. |
| `pre_warmed_sessions` | integer | 3 | Number of opencode sessions booted early; 0 disables pre-warm. |
| `max_log_history_mb` | integer | 1000 | Caps persistent log history in MB. |
| `prompt_file` | string | nil | Per-repository Liquid prompt template. |
| `debug` | boolean | false | Enables debug-level file logging without the CLI debug flag; background runs already retain normal-level logs. |
| `hooks_file` | file pointer | none | Sibling YAML file merged as the `hooks:` block. |
| `executor_takeover_first_alert_hours` | integer | 8 | First Executor takeover advisory threshold in hours; `0` disables. |
| `executor_takeover_continuous_alert_hours` | integer | 1 | Repeated takeover advisory cadence in hours after the first; `0` disables repeats. |

## executor takeover alerts

Aiur watches nonterminal tickets in the run scope and, once a ticket's **convergence age** crosses a configurable threshold, raises an advisory `needs_attention` alert visible in `aiurdev alerts --needs-attention` and the watch actionable section. The alerts are advisory takeover prompts — they never perform a takeover automatically.

- `executor_takeover_first_alert_hours` (default `8`) — a nonterminal ticket
  first raises the advisory once its convergence age reaches this value.
- `executor_takeover_continuous_alert_hours` (default `1`) — while the ticket
  stays nonterminal and unresolved, the advisory is repeated at most this often.
  A value of `0` disables repeats (first alert only); `0` on the first threshold
  disables the feature. Negative or non-integer values are rejected.

**Convergence age** is `now − min(first_observed_active_work_at, open_pr_created_at)`:

- `first_observed_active_work_at` is persisted durably per ticket in daemon
  state, set once the first time the monitor observes the ticket as nonterminal
  and in scope. A worker restart, redispatch, `max_turns` recycle, or daemon
  restart never resets it.
- `open_pr_created_at` is the creation time of the ticket's open PR (a floor,
  so an already-open PR is never hidden by a freshly installed or restarted
  monitor).

The alert carries actionable evidence.

| Evidence | Detail |
| --- | --- |
| Identity | Ticket and PR. |
| Age | Elapsed convergence age. |
| Activity | Last material push, current live-owner state, and dispatch/restart count. |
| PR health | Base and merge freshness. |
| CI | Current state when available, for tickets already alerted. |

A ticket that becomes terminal or leaves the run scope resolves its active advisory and forgets its convergence state; a re-opened ticket starts a fresh episode.

## monitoring

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `monitoring.daemon_heartbeat_stale_ms` | integer | 3,600,000 | Threshold in milliseconds for recording a retrospective daemon heartbeat gap on Executor startup. A durable `system.daemon.gap` informational event is emitted only when a stale heartbeat is corroborated by the lifecycle journal; its cause is `clean_shutdown` when a stop was recorded and `unknown` for an unclosed start. Missing heartbeat files are ignored. This is not live monitoring and cannot alert while Aiur is stopped. Default is 1 hour (3,600,000 ms). |

## workspace

The `wip_*` keys bound the save of uncommitted work described in [Saved uncommitted work](/reference/cli#saved-uncommitted-work).

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `workspace.root` | string path | tmp `aiur_workspaces` | Root for agent workspaces. |
| `workspace.bootstrap_image` | string | nil | Docker image for warm build-cache seeding. |
| `workspace.bootstrap_image_pull` | boolean | false | Pulls the bootstrap image before seeding. |
| `workspace.wip_max_bytes` | integer | 52428800 | Cap in bytes of one save of uncommitted work (50 MiB). Untracked files past it are skipped; the tracked patch is always kept. |
| `workspace.wip_max_file_bytes` | integer | 10485760 | An untracked file larger than this (10 MiB) is skipped in a save. |
| `workspace.wip_max_dir_files` | integer | 10000 | An untracked directory with more files than this, or a nested repository, is skipped whole. |
| `workspace.wip_command_timeout_ms` | integer | 60000 | Time limit of each `git` and `tar` command of a save. A timeout keeps the workspace, except for a closed ticket. |
| `workspace.wip_retention_bytes` | integer | 2147483648 | Cap in bytes of all of `wip-preserved/` (2 GiB). Closed tickets' saves are pruned first. |
| `workspace.wip_retention_days` | integer | 14 | Saves older than this are pruned. The newest save of an open ticket is never pruned. |

## worker

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `worker.ssh_hosts` | array | `[]` | SSH hosts available for remote execution. Each server must allow `BASH_ENV`, `ENV`, `HOME`, and `ZDOTDIR` through OpenSSH `AcceptEnv`; Aiur neutralizes them before the account shell starts and fails closed if the server rejects them. |
| `worker.max_concurrent_agents_per_host` | integer or nil | nil | Per-host concurrent-agent cap. |

## hooks

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `hooks.after_create` | string or nil | nil | Command after workspace creation. |
| `hooks.before_run` | string or nil | nil | Command before each agent run. |
| `hooks.after_run` | string or nil | nil | Command after each agent run. |
| `hooks.before_remove` | string or nil | nil | Command before workspace removal. |
| `hooks.timeout_ms` | integer | 600000 | Per-hook timeout; 10 minutes by default. |

## pr_watch

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `pr_watch.enabled` | boolean | false | Enables trusted PR comment watching. |
| `pr_watch.watch_label` | string | `watch` | Label suffix enrolling a PR for watching. |
| `pr_watch.command_prefix` | string | `/aiur` | One-off trusted comment command prefix. |

## pr_health

Periodic scan of open pull requests for conditions that stall PRs silently: a
PR authored by a configured human merger (unmergeable by construction, since
GitHub blocks self-approval), a non-draft PR older than `stale_hours` with no
review, and a rework ticket whose PR's own contribution has genuinely changed
since its blocking review.

Findings raise needs-attention alerts in the Executor's alert feed
(`system.pr_health.unmergeable_author` / `system.pr_health.stale_unreviewed` /
`system.pr_health.rework_merge_only`).

Enabling the scan enables the **rework re-queue**: a ticket in
`agent:rework` whose PR's own contribution diff (`merge-base..head`) changed
since the blocking `CHANGES_REQUESTED` review is moved to `agent:human-review`
for the second look — GitHub keeps `reviewDecision = CHANGES_REQUESTED` until
a brand-new review, so nothing else re-queues it.

A PR whose head only moved via merges of the base branch (own contribution
unchanged) is NOT re-queued; it raises `system.pr_health.rework_merge_only` so
the merge-only state is visible distinctly from genuine rework.

A re-queue that the thread-clearance gate refuses (the reworked PR still has
unresolved review threads — the normal state of a rework ticket) raises
`system.pr_health.rework_requeue_failed`; the head is not throttled on a failed
write, so the re-queue retries on the next tick instead of silently stranding
the ticket in rework.

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `pr_health.enabled` | boolean | false | Enables the PR-health scan and the rework re-queue. |
| `pr_health.interval_seconds` | integer | 1800 | How often the scan lists open PRs. |
| `pr_health.stale_hours` | integer | 24 | A non-draft PR older than this with no review is flagged. |

## events

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `events.block_state_debounce_seconds` | integer | 10 | Debounces blocked/unblocked transitions. |
| `events.custom_events_per_turn_max` | integer | 5 | Caps custom events per turn. |
| `events.codeowners_refresh_seconds` | integer | 3600 | CODEOWNERS refresh interval. |

## upgrade

The `aiur run` upgrade-version notice is optional and opt-out: it caches with a
TTL (the registry is contacted at most once a day), fails open and silent when
unreachable, never runs under `aiurdev`, and is channel-aware — a `nightly` or
`next` user is never offered a lower `latest`.

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `upgrade.check_enabled` | boolean | true | Enables the `aiur run` version notice and its registry check. Set false to suppress the check entirely (zero outbound calls). |

`AIUR_UPGRADE_CHECK_DISABLED` (and the legacy `AIUR_NO_UPDATE_NOTIFIER`) are the
environment-variable equivalents; the check also stays silent in CI runs.

## alerts

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `alerts.enabled` | boolean | true | Master alert-sound switch. |
| `alerts.use_os_default_sounds` | boolean | false | Uses built-in OS sounds by category. |
| `alerts.sound_dir` | string path or nil | nil | Directory for custom sound files. |
| `alerts.alerts_file` | string path or nil | bundled alerts file | Topic-to-sound YAML map. |

## observability
| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `observability.dashboard_enabled` | boolean | true | Reserved compatibility setting; use the launch-time `--no-dashboard` flag to suppress the listener in foreground or background mode. |
| `observability.dashboard_writable` | boolean | true | Enables dashboard write paths. Set to `false` to disable them. A dashboard bound beyond loopback refuses to start without both dashboard basic-auth environment variables; a loopback listener binds without them and fails closed (see below). |
| `observability.build_order_funnel_health_check` | boolean | false | Opts into one bounded startup check of the local Build Order endpoint and configured Tailscale Funnel HTTPS 443 target. Leave disabled when Funnel serves another purpose. |
| `observability.refresh_ms` | integer | 1000 | Dashboard data refresh interval. |
| `observability.render_interval_ms` | integer | 16 | Minimum render interval. |
| `observability.capture_tags` | map | `%{}` | Static cohort tags; at most 20 string pairs, 64 characters per key/value. |
| `observability.capture_label_prefixes` | list | `["experiment:", "cohort:", "feature:"]` | Label prefixes captured at dispatch; at most 20. |
| `observability.telemetry_enabled` | boolean | true | Master analytics capture switch; restart to apply. Disabled boots append a local `analytics/capture-gaps.ndjson` marker and `/analytics` shows a capture-off notice. |
| `observability.capture_github_facts` | boolean | true | Enables analytics GitHub fact and repo-timeline reads when the master capture switch is on. |
| `observability.telemetry_retention_max_bytes` | integer | 67108864 | Maximum retained telemetry bytes. |
| `observability.telemetry_retention_max_age_days` | integer | 30 | Maximum retained telemetry age. |
| `observability.telemetry_retention_prune_interval_bytes` | integer or nil | nil | Bytes between retention-prune checks. |

`dashboard_writable` controls authorization, not authentication. Set `AIUR_DASHBOARD_USERNAME` and `AIUR_DASHBOARD_PASSWORD` before use. A loopback listener can bind without them but rejects every dashboard request until both are set. A listener beyond loopback refuses to start without both.

When `observability.build_order_funnel_health_check` is enabled, Aiur checks the configured dashboard bind address at `/build-orders/1` and reads `tailscale funnel status --json` once after dashboard startup. Both command timeouts are five seconds, and timed-out Tailscale processes are terminated.

The one-time check is suppressed when `server.tailscale_funnel: true`. The reconciler reports Funnel health after its initial and periodic attempts, so the startup check cannot alert before reconciliation runs.

HTTP 200, redirects 301/302/304/307/308, and 401 (authentication required) count as reachable. Other statuses, including 201, 204, and 303, do not.

A stale proxy target raises `system.build_order_funnel.target_mismatch`; an unreachable endpoint raises `system.build_order_funnel.target_unreachable`; and an endpoint timeout raises `system.build_order_funnel.target_timeout`.

An unavailable or unparseable Tailscale status raises `system.build_order_funnel.health_check_error`. Tailscale is not detected or queried unless this setting is explicitly enabled.

The supervising-Executor Decision API uses the separate `AIUR_SUPERVISOR_TOKEN` bearer credential. Generate it with `openssl rand -base64 32`, then put `AIUR_SUPERVISOR_TOKEN=<generated-token>` in `~/.aiur/.env` (global) or the repository `.env` (project-local).

An exported value wins, followed by the global file and then the repository file. The value must be at least 32 bytes, bearer-safe, and free of surrounding whitespace. A present non-empty invalid value aborts startup; an absent or empty value leaves the API disabled.

## decisions

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `decisions.supervisor_allowed_kinds` | array | `[]` | Decision kinds an authenticated supervising Executor may answer. Empty means none. |
| `decisions.supervisor_allow_non_reversible` | boolean | false | Allows supervisor policy to cover partially reversible or irreversible decisions. |

These policy keys never grant transport access by themselves. The supervisor API also requires `AIUR_SUPERVISOR_TOKEN`; mutations require the writable and origin gates described above.

## server

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `server.port` | integer | 0 | HTTP port; 0 selects a free OS port. |
| `server.host` | string | `127.0.0.1` | HTTP bind address. Set it explicitly to serve the dashboard beyond the machine; there is no automatic Tailscale detection. |
| `server.tailscale_funnel` | boolean | false | Reconcile an already-enabled Tailscale Funnel HTTPS route on port 443 to the dashboard's current bound host and port at startup and every 30 seconds. Requires the Tailscale CLI and an existing Funnel route; failures raise a Build Order Funnel alert and retry. |

When `server.host` is absent, the dashboard binds `127.0.0.1` (or the `AIUR_DEFAULT_DASHBOARD_HOST` override). A configured value is never replaced by that default. An explicit `--host` remains the highest-precedence override.

Set `server.tailscale_funnel: true` only when this node already has a Funnel route the operator intends to keep. At startup and every 30 seconds, Aiur reads the dashboard's bound host and port and updates the route with `tailscale funnel --bg` when needed.

Before changing a different target, Aiur probes that target's `/build-orders/1`. Any HTTP response makes the reconciler leave the route unchanged and raise `system.build_order_funnel.target_mismatch`.

Only a connection-refused probe counts as stale and permits an update. Timeouts, TLS failures, and other probe errors leave the route unchanged and raise `system.build_order_funnel.health_check_error` with cause `unknown`. Wildcard binds (`0.0.0.0` and `::`) map to loopback for the Funnel target.

Enable this on only one Aiur daemon per node. A second daemon with this key enabled can repoint the route while the owning dashboard restarts and its old target refuses connections.

When `server.tailscale_funnel` is enabled, the reconciler suppresses the separate `observability.build_order_funnel_health_check` startup check and reports its own failures after each reconciliation attempt.

A non-root account needs Tailscale operator access before Aiur can manage the route. Grant it once with `sudo tailscale set --operator=$USER`; then run Aiur as that account.

Aiur does not enable Funnel or create a route. The dashboard's existing authentication remains in place, and the route supports HTTP and WebSocket traffic.

The target probe is a bounded liveness check, not proof of daemon identity or route ownership. A live stale service requires operator intervention. Aiur does not restart, stop, or otherwise manage the Tailscale daemon.

A fixed `server.port` that is already bound — for example a second `aiur` instance on the same host — does not crash the daemon. The second instance logs an explicit startup message naming the port and the conflict, disables only its own dashboard, and keeps running agents.

The durable repository Executor state also records every daemon start and stop in `<repo>.control-lifecycle.json`, with the invoking process's OS pid, parent pid, and hostname. All runs for that repository share the journal, so a second instance or a crash is identifiable after the fact even when each run has a different log directory.

## Resolution & validation notes

- An unset or blank `prompt_file` falls back to the built-in default prompt; a configured unreadable path fails startup.
- A legacy top-level `linear:` section is merged into `tracker.linear`.
- Only `$VAR` environment references resolve; legacy `env:NAME` values remain literal.
- `polling.interval_ms` is rejected by the loader; use `interval_seconds`.
