# Tracker and polling configuration

## tracker

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `tracker.kind` | string | required | Selects `linear`, `github`, or `memory`. |
| `tracker.propagate_blocker_pushes` | boolean or nil | nil | Unset enables optimistic queue members; otherwise false. Cascade direct blocker pushes into idle dependents. Coalesces for 2 seconds, at most 2 propagations concurrently. Live agents pull themselves; conflicts dispatch rework. |
| `tracker.restack_after_blocker_merge` | boolean | true | Fast-forward restack idle GitHub dependents after a blocker squash-merges. Requires git 2.40+. Live agents restack themselves; false disables only the daemon path. |
| `tracker.base_branch` | string | required | Branch agents target with PRs. `aiur init` offers the repository default read from GitHub, but there is no runtime fallback: an unset value raises. |
| `tracker.active_states` | array | tracker-specific | States eligible for dispatch. GitHub values are lifecycle label slugs such as `todo` and `in-progress`, not display names. |
| `tracker.terminal_states` | array | tracker-specific | States that stop work. GitHub values are lifecycle label slugs such as `done`. |
| `tracker.terminal_fence_grace_seconds` | integer | 30 | How long a terminal tracker observation remains lifecycle-fenced while an authoritative queued item is still undelivered. |
| `tracker.github.max_inflight` | integer | 4 | Cap on concurrent tracker HTTP requests across all endpoints (1-100). |
| `tracker.github.max_inflight_per_endpoint` | integer | 2 | Cap on concurrent requests to any single tracker endpoint (1-100). Must not exceed `tracker.github.max_inflight`. |
| `tracker.github.requests_per_minute` | integer | 120 | Tracker request budget per minute (1-10000). Lower it when the tracker rate-limits Aiur. |
| `tracker.github.stagger_ms` | integer | 75 | Delay inserted between tracker requests, in milliseconds (0-5000), so a poll cycle does not burst. |
| `tracker.github.daemon_core_limit_per_hour` | integer | 3000 | Hourly billable Core (REST) response ceiling for the daemon actor. A `304` is reconciled as free. When the daemon hits the ceiling, only its requests hold until the rolling hour rolls back under it. `0` disables. |
| `tracker.github.daemon_graphql_limit_per_hour` | integer | 4500 | Hourly billable GraphQL response ceiling for the daemon actor. `0` disables. Raised from 2000 because the guard now books the high-level GraphQL-on-the-wire reads (`gh pr view/list/status/checks`, `gh issue view/list/status`, `gh search issues/prs`, `gh api graphql`) to the GraphQL window, and the App-token daemon alone measures ~3,400-4,300 such requests per hour. |
| `tracker.github.daemon_search_limit_per_hour` | integer | 600 | Hourly billable ceiling for GitHub's separate `search` pool (`gh search repos/code/commits/users` hit REST `/search/*`, metered at roughly 30 requests per minute rather than 5,000/hour). `0` disables. |
| `tracker.github.agent_core_limit_per_hour` | integer | 250 | Hourly billable Core (REST) response ceiling for each agent workspace. When one agent hits it, only that agent holds. `0` disables. |
| `tracker.github.agent_graphql_limit_per_hour` | integer | 600 | Hourly billable GraphQL response ceiling for each agent workspace. `0` disables. Raised from 375 so a single agent's normal loop (`pr view`/`issue view`/`pr checks`) has headroom once high-level GraphQL commands book to the GraphQL window. |
| `tracker.github.agent_search_limit_per_hour` | integer | 600 | Hourly billable ceiling against the `search` pool for each agent workspace. `0` disables. Kept separate from core and graphql because GitHub meters the search pool independently and it throttles first. |
| `tracker.github.credentials` | array | `[]` | Additional GitHub credentials the daemon spreads read traffic across, so one exhausted budget does not stop the fleet. Empty — the default — means one credential resolved exactly as before. See [Credential pooling](/apis/github#credential-pooling). |
| `tracker.github.credentials.id` | string | required | Lowercase identifier naming this credential in `aiur github-usage` and `aiur github-cost`. Must be unique. |
| `tracker.github.credentials.kind` | string | `machine_user` | One of `app_installation`, `machine_user` or `human`. Set it to `human` for a real person's token so Aiur keeps writes off that identity. |
| `tracker.github.credentials.identity` | string | nil | The GitHub login this credential authenticates as. Reporting only, so a usage row names an account rather than a hash. |
| `tracker.github.credentials.token_env` | string | required except for `app_installation` | Environment variable holding the token. An `app_installation` credential mints its own and needs none. A variable that is not exported drops the credential from the pool rather than failing boot. |
| `tracker.github.credentials.writes` | boolean | `false` | Whether this credential may carry writes (comments, labels, merges, PR creation). A `human` credential cannot be set to `true`: GitHub attributes the write to that person and it breaks the agent-authors / human-reviews separation the merge policy depends on. |
| `tracker.github.credentials.enabled` | boolean | `true` | Set to `false` to keep a credential in the file but out of the pool, for a token being rotated or an account temporarily rate-limited. |
| `tracker.github.repo` | string | the checkout's `origin` remote | GitHub owner/name used by Aiur. Omitted or left blank, it auto-detects from the `origin` remote of the directory the daemon was launched from — both for the repository Aiur polls and for the repository tracker identities are qualified by, which is what lets several daemons for different repositories share one `~/.aiur/config`. A value that is present but not `owner/name` is rejected rather than auto-detected, so a typo cannot silently redirect a fleet at whatever checkout it happens to run from. Set it explicitly whenever the daemon should track a repository other than its own checkout. |
| `tracker.github.label_prefix` | string | `agent` | Prefixes lifecycle labels. |
| `tracker.github.bot_account` | string | nil | Login the **agents** publish as — the account that pushes branches, opens pull requests, and comments for a ticket. This is an identity, not the credential: the credential is `GITHUB_TOKEN`. During fresh setup, `aiur init` asks whether agents use your own account or a separate bot account; it derives the former without asking for the login again and asks for the latter once. If the known posting credential names a different account, setup keeps that separate identity rather than recording an untrue shared account. In a non-interactive or `--force` run, valid resolved defaults are used and invalid ones are omitted rather than retried. Re-running `aiur init` preserves an existing value. When no `tracker.github.github_app.account` is set this login also stands in as the daemon's own identity for self-loop suppression. |
| `tracker.github.identity_mode` | string | `separate_account` | Whether the agents post as a login no human uses (`separate_account`) or share the operator's own login (`single_account`). Stated, never inferred: nothing compares `bot_account` against the token's viewer login to guess, because that guess is wrong in both directions and silently changes which comments wake an agent. Under `separate_account` the author login proves authorship and nothing else is needed. Under `single_account` it proves nothing, so Aiur appends an invisible HTML-comment marker to comments it writes and suppresses only comments carrying it — anything unmarked, including every comment posted before this existed, reads as human and wakes the agent. Any other value is rejected at config load. |
| `tracker.github.github_app.account` | string | nil | Optional. The GitHub App bot login (`<app-slug>[bot]`) the **daemon** writes as when App credentials are configured (see [GitHub](/apis/github#github-app-authentication)). Set it only when the daemon's identity differs from the agents': an App installation token can never write as `tracker.github.bot_account`, so one key naming both would make every agent-authorship check demand a login no agent holds. Leave it unset for a single-identity install — self-loop suppression, PR command handling and the CODEOWNERS self-include then fall back to `tracker.github.bot_account` exactly as before. Only the login lives here; the App credentials stay in `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID` and `GITHUB_APP_PRIVATE_KEY_PATH`. |
| `tracker.github.trusted_accounts` | array | `[]` | Usernames allowed to direct agents. |
| `tracker.github.allowed_users` | array | `[]` | GitHub logins allowed to use trusted operator paths. |
| `tracker.github.allowed_contributors` | map | nil | Whole intake allow-list: `users: [42]`, `orgs: [{id: 77, login: acme}]`. Positive numeric int64 ids; logins address the membership API only. Present empty map/null admits nobody; present key skips `.github/ALLOWED-CONTRIBUTORS`. Invalid entries fail startup validation. Reload/restart applies changes and alerts with added/removed entries. |
| `tracker.github.human_mergers` | array | `[]` | Explicit human-only post-merge attribution allowlist; also the identity allowlist for the planned `aiur pr merge` command. Never inherits CODEOWNERS, bot accounts, trusted accounts or dispatch users. |
| `tracker.github.planning_root_limit` | integer | 100 | Maximum Build Order planning roots fetched in one cycle. |
| `tracker.github.planning_page_budget` | integer | 4 | Maximum GitHub planning pages fetched in one cycle. |
| `tracker.github.planning_call_budget` | integer | 4 | Maximum GitHub planning calls fetched in one cycle. |
| `tracker.linear.api_key` | string | env fallback | Linear API key; `$VAR` resolves from the environment. |
| `tracker.linear.project_slug` | string | nil | Linear project polled by Aiur. |
| `tracker.linear.endpoint` | string | `https://api.linear.app/graphql` | Linear GraphQL endpoint. |
| `tracker.linear.assignee` | string | env fallback | Linear assignee filter. |

## polling

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `polling.interval_seconds` | integer | 120 | Seconds between tracker polls. The repo-events firehose shares this tick. |
| `polling.intervals` | map of class → integer | `%{}` | Per-class poll cadences in seconds. Each key names a poll class — `dispatch`, `ci`, `review`, `planning`, `firehose` — and overrides `interval_seconds` for that class only. A class with no entry falls back to `interval_seconds`, so an unset map keeps today's single-interval behaviour exactly. `0` means the class is on-demand — no timer, refreshed only when a consumer explicitly asks — which is the recommended value for `planning`. (`firehose` is not recommended at any value: its loop rides the dispatch tick and is not gated, so an entry would be a dead knob.) `dispatch` must be a positive integer: the dispatch tick always runs, so `dispatch: 0` is rejected. `review` only diverges on a repo proven webhook-backed — on a polling repo its safety net stays at the dispatch rate. An unknown class key or a negative value is rejected. |
| `polling.idle_widen_factor` | float | 5.0 | Multiplier applied while no agents are actively running. Must be between 1.0 and 100.0. |
| `polling.usage_interval_seconds` | integer | 300 | Seconds between provider-meter probes. Values below 120 are rejected to avoid provider rate-limit degradation. |
| `polling.view_state_sweep_seconds` | integer | 900 | Seconds between runs of the view-state reconciliation sweep. It exists only to recover a webhook delivery that was lost, so it is a recovery bound rather than a refresh interval — a delivery that arrives updates the dashboard immediately and for free, and shortening this makes nothing fresher. The open-backlog and ad-hoc-overlay sources are event-sourced and not swept at all; the sweep reconciles the daemon-owned Build Order pack-status projection (which writes `status.json` on disk and stays on this cadence until it is moved to the event stream too) and runs the issue-family divergence watermark — a single bounded `updated_at`-ordered head page that keeps webhook loss detectable and re-converges a dropped delivery. |

Freshness thresholds follow this cadence. You do not set them separately.

- The **effective** interval is a class's interval after `idle_widen_factor`,
  `webhooks.poll_widen_factor` and GitHub's poll floors are applied.
- Since #2309 each poll loop resolves its interval by naming the class it
  serves, and `polling.intervals` lets those classes diverge. The classes:

  | Class | Polls | Why it gets its own cadence |
  | --- | --- | --- |
  | `dispatch` | open issues and `agent:*` labels (the dispatch trigger) | Cheap (conditional REST, usually `304`) and urgent. The default for every unlisted class and for un-named `PollCadence` reads. |
  | `ci` | check state on a pull request with work in flight | Expensive GraphQL and urgent, but only while a PR is actually in flight (the loop is demand-scoped). `intervals.ci` is deliberately not recommended: the loop rides the dispatch tick, so a value below `dispatch` is inert (the loop can never fire more often than the tick) and one above it *slows* CI detection — a stale CI read has agent-visible consequences. Leave it unset to inherit `interval_seconds`. |
  | `review` | comments and review threads | Expensive GraphQL, moderately urgent, and webhook-covered for comment *arrival* — the poll is a safety net, so minutes is defensible. The divergence is enforced, not asserted: on a repo not proven webhook-backed the class resolves to the dispatch cadence, so the safety net never silently slows on a polling repo. |
  | `planning` | Build Order catalog, pack status, ad-hoc listings | The most expensive reads and the least urgent. Recommended value `0` (on-demand): the catalog's only consumers are web pages and it is demand-gated, so it needs no timer. |
  | `firehose` | repo events | Already self-regulating via GitHub's `X-Poll-Interval`; the class exists so status can show its configured cadence, not to change its loop. The firehose loop is **not gated** on a class cadence — it rides the dispatch tick — so no value is recommended: leave it unset to inherit `interval_seconds`. An entry would be a dead knob. |

- The dashboard, the Units catalog and Build Order ticket history all judge
  staleness against the effective interval of the class they mean: the
  orchestrator snapshot readers derive from `dispatch`, Build Order catalog and
  ticket history from `planning`.
- Build Order's remaining `graph_catalog_refresh_ms` — the failure-backoff base
  for the catalog scope, the window after which the catalog snapshot is shown
  as ageing, and the floor the labelled-read cadence rides on — is derived from
  the effective `planning` interval, so an idle fleet widens the Build Order
  backoff exactly as it widens the tracker poll.
- The catalog itself is event-sourced (#2313): the page renders the store
  projection, there is no recurring sweep, and the only GitHub reads are the
  rare reconciliation (daemon boot and degraded webhook delivery). It is not
  demand-gated by who is looking — the reconciliation is the daemon-owned
  writer that re-converges the store — and it needs no timer. A selected root's
  staleness window and failure backoff are therefore re-based on delivery
  latency (`webhooks.silence_threshold_seconds`), the gap after which
  degradation triggers the reconciliation, rather than on a poll cadence.
- So a change to an interval needs no matching threshold edit.
- `aiur status` prints the effective value and the live interval per class, for
  example:
  ```
  POLL idle backoff active: interval=1200s base=120s factor=5.0x
  POLL class intervals: ci=120s dispatch=120s firehose=120s planning=0s review=300s
  ```
  `0s` means the class is on-demand: no timer, refreshed only when a consumer
  asks. `ci` sits at the dispatch cadence because the loop rides the tick and is
  deliberately not given its own interval; `review` shows its configured value
  only while the repo is proven webhook-backed.
- The idle widening only applies once the daemon has observed an idle cycle:
  a freshly restarted fleet starts at the base interval, and a live fleet with
  dispatchable tickets keeps the base interval so work is not left waiting
  behind a backed-off sweep (#2138).

## webhooks

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `webhooks.repos` | list of `owner/name` | `[]` | Repos expected to deliver webhooks. A hint only. A listed repo keeps polling at full rate until it actually delivers. |
| `webhooks.silence_threshold_seconds` | integer | 900 | How long a proven repo may go without a delivery before it degrades back to full polling and raises a needs-attention alert. |
| `webhooks.sweep_interval_seconds` | integer | 60 | How often proven repos are checked for silence. |
| `webhooks.poll_widen_factor` | float | 2.0 | Multiplier applied to `polling.interval_seconds` for repos proven webhook-backed. Values below 1.0 are rejected. |

See [GitHub polling and webhooks](/apis/github) for the setup story and runtime states.
