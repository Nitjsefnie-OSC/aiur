# Configuration reference: agent

Sections of the [configuration reference](/reference/configuration) covering `agent`, host-pressure admission, `agent.claude`, `agent.codex`, and model discovery.

## agent

| Key | Type | Default | Controls | <!-- generated-reference:config-configuration-agent-00 -->
| --- | --- | --- | --- |
| `agent.account_selection` | string | `balance` | Selects an enabled account by weekly utilization, configured order, or remaining usage headroom. |
| `agent.accounts` | map | `%{}` | Machine-local account names enabled per harness; list order sets preference. |
| `agent.backend_configs` | map | `%{}` | Provider-specific configuration, including per-backend settings and credentials. |
| `agent.budget_broker_degraded_alert_after_seconds` | integer | 600 | Dwell before a degraded budget-broker alert is raised. |
| `agent.budget_broker_degraded_retry_threshold` | integer | 5 | Retries in the window above which the budget broker counts as degraded. |
| `agent.budget_broker_rate_window_seconds` | integer | 300 | Sliding window for counting budget-broker timeout retries. |
| `agent.build_gate_max_hold_seconds` | integer | 3600 | Absolute wall-clock cap on a build-gate slot; 0 disables the backstop. |
| `agent.build_gate_retain_seconds` | integer | 120 | Maximum post-command slot window while a descendant still consumes CPU; 0 disables the courtesy. |
| `agent.build_nice` | integer | 10 | CPU nice adjustment (0–19) applied to admitted build commands; 0 preserves launch priority. |
| `agent.build_start_stagger_seconds` | integer | 0 | Minimum spacing between local Mix build starts; 0 disables pacing. |
| `agent.capacity_starvation_alert_after_seconds` | integer | 60 | Seconds ready-work capacity starvation must persist before an alert. |
| `agent.ci_recovery_enabled` | boolean | true | Enables automatic CI recovery reruns; false disables them. |
| `agent.ci_recovery_max_per_hour` | positive integer | 20 | Maximum recovery reruns admitted in a rolling hour. |
| `agent.ci_recovery_max_per_poll` | positive integer | 5 | Maximum recovery reruns admitted by one CI poll. |
| `agent.ci_wait_rewake_minutes` | positive integer | 5 | Re-wakes a CI-wait agent for one recovery check when no terminal event arrives. |
| `agent.complexity_prompts` | map | `%{}` | Adds prompt guidance by complexity level. |
| `agent.git_identity.email` | string or nil | nil | Commit author and committer email for agent workspaces. |
| `agent.git_identity.name` | string or nil | nil | Commit author and committer name for agent workspaces. |
| `agent.headroom_reading_max_age_seconds` | integer | 1800 | Usage readings older than this score as unknown when using headroom account selection. |
| `agent.kind` | string | `codex` | Deprecated default backend; ignored when `agent.priority` is non-empty. |
| `agent.load_cooldown_seconds` | integer | 60 | Seconds between successive load-gate reductions. |
| `agent.load_ramp_step` | integer | 1 | Per-reconciliation concurrency adjustment while load is recovering. |
| `agent.load_resume_max_age_seconds` | integer | 21600 | Maximum age in seconds for a host-pressure observation before it is stale. |
| `agent.max_agent_duration_minutes` | integer | 60 | Active-runtime pause checkpoint; 0 disables it. |
| `agent.max_concurrent_agents` | integer or nil | derived from host capacity | Global simultaneous-agent cap; omitted values derive from measured host scheduler capacity. |
| `agent.max_concurrent_agents_by_state` | map | `%{}` | Per-state caps overriding the global cap. |
| `agent.max_concurrent_builds` | integer | 4 | Caps local agent Mix verification and browser tests; 0 disables the cap. |
| `agent.max_consecutive_noop_turns` | integer | 3 | Consecutive continuation turns with no observable progress before the loop stops; 0 disables the bound. |
| `agent.max_cpu_pressure` | float or nil | 20.0 | Linux CPU PSI some avg60 ceiling in percent; null disables the gate. |
| `agent.max_dispatches_per_ticket` | integer | 0 | Per-ticket dispatch latch; 0 disables the latch. |
| `agent.max_load_average` | float or nil | 1.5 | Per-scheduler load ceiling used when CPU PSI is unavailable; null disables it. |
| `agent.max_retry_attempts` | integer | 3 | Failed-turn retry count. |
| `agent.max_retry_backoff_ms` | integer | 300000 | Retry backoff ceiling in milliseconds. |
| `agent.max_turns` | integer or nil | nil | Per-issue turn cap; nil is uncapped. |
| `agent.max_turns_by_complexity` | map | `%{}` | Per-complexity turn caps. |
| `agent.min_free_memory_mb` | integer or nil | nil | Linux MemAvailable floor shared by dispatch and the Mix build gate. |
| `agent.mix_scheduler_cap` | integer | 4 | Caps ERTS scheduler threads for agent-launched Mix processes. |
| `agent.pricing_policy.avoid_peak_pricing` | boolean | `true` | Routes around peak-pricing windows through `agent.priority`; false follows the list exactly and never changes spend reporting. Unknown windows fail toward not rerouting. `mix aiur.pricing_window` shows the current window and next boundary. |
| `agent.prior_work_continuation` | boolean | true | Lets a resumed ticket continue existing workspace work when policy permits. |
| `agent.priority` | array | `[]` | Ordered dispatch preference as routes (`backend` or `backend:model`); see the Routes section. A non-empty list replaces the legacy kind and fallback settings. |
| `agent.rate_limit_fallback` | string | `claude` | Deprecated recovery backend; an empty string disables it. |
| `agent.rate_limit_primary` | string | default backend | Deprecated backend watched for automatic rate-limit recovery. |
| `agent.relay` | boolean | true | Runs local Codex app-server and headless Claude behind a detached relay. `false` uses direct Port transport; remote SSH workers keep their existing transport. |
| `agent.relay_orphan_timeout_seconds` | integer | 1800 | Stops the provider process group after this many seconds without a relay controller. Must be positive. |
| `agent.remote_control` | boolean | false | Opts RC-capable backends into remote control. |
| `agent.routing` | map | `%{}` | Maps complexity levels to backend/model/effort routing. |
| `agent.routing_candidates` | map | `%{}` | Read-only routes derived from list values in `agent.routing`. |
| `agent.rtk.enabled` | boolean | false | Enables the Agent output compression panel on the analytics page, which reports rtk's host-level output savings when available. Aiur does not install, enable, or disable rtk's hook and does not enforce this setting at agent dispatch. A host-wide rtk hook applies to every agent regardless of this setting; the operator owns the hook and must exclude `gh` (`exclude_commands = ["gh"]` under `[hooks]`), because `gh` in an agent workspace is the GitHub quota guard and rtk must not rewrite it. The analytics panel reports rtk's status, including when its probe detects that `gh` would be rewritten, but cannot disable the hook. At daemon startup Aiur also checks the host hook, independent of this setting, and raises an informational alert when it would rewrite `gh`. |
| `agent.run_queue_threshold` | float or nil | nil | Optional per-scheduler runnable ceiling used when CPU PSI is unavailable; null disables it. |
| `agent.saturation_log_enabled` | boolean | true | Records host and VM diagnostics when sustained load crosses the saturation threshold. |
| `agent.stall_timeout_ms` | integer | 3600000 | Silent-agent watchdog; 0 disables it. |
| `agent.switch_model_on_ratelimit` | array | `[]` | Deprecated fallback order; ignored when `agent.priority` is non-empty. |
| `agent.synthetic_load_kill_detected` | boolean | false | Kills a detected busy-loop or orphaned synthetic load generator when enabled. |
| `agent.synthetic_load_process_cap` | integer or nil | derived | Per-agent cap for recognized synthetic load generators; nil derives from scheduler count. |
| `agent.target_cpu_pressure` | float or nil | 10.0 | Adaptive CPU PSI target in percent; null disables adaptive pressure control. |
| `agent.target_load_average` | float or nil | 1.0 | Per-scheduler adaptive target used when CPU PSI is unavailable; null disables it. |
| `agent.turn_timeout_ms` | integer | 3600000 | Backstop timeout for one turn. |

### Routes in `agent.priority`

Each entry is a **route**, not just a backend name. A route uses the same grammar `agent.routing` has always used:

```
<backend>[:<model>[:<effort>]][+remote]
```

- `claude`: the backend's own direct connection, exactly as before.
- `openrouter:anthropic/claude-sonnet-5`: that model reached through OpenRouter.

A colon-free entry means what it has always meant, so **existing configs need no change**.

If a hot-reloaded `.aiur/config` fails validation, the daemon keeps running on the last good config. It raises a `system.config.reload_rejected` alert, and `aiur status` shows `CONFIG RELOAD REJECTED` until a corrected file loads.

The effort segment must be one the backend accepts. Headless `claude` takes no effort segment, so write `claude:sonnet`. Append `+remote` to route through the Claude REPL, which accepts `low`, `medium`, `high`, `xhigh` and `max`: `claude:sonnet:medium+remote`.

```yaml
agent:
  priority:
    - claude                                # Anthropic direct
    - openrouter:anthropic/claude-sonnet-5  # same model, billed by OpenRouter
    - codex                                 # OpenAI direct
    - openrouter:moonshotai/kimi-k2.7-code  # no direct Moonshot key: OpenRouter only

  backend_configs:
    openrouter:
      provider:
        order: [Anthropic, "Together AI"]
        allow_fallbacks: true
        ignore: [Azure]
        sort: price

  pricing_policy:
    avoid_peak_pricing: true
```

**A model reachable two ways may appear twice, and the order is the fallback order.** Duplicate *routes* are rejected; duplicate backends are not.

| Model name | Behavior |
| --- | --- |
| Full provider slug | Canonical form and cost-reporting key. |
| Short family alias | Resolves to the newest matching concrete slug before the request, so normal pricing applies. |
| Alias claimed by multiple vendors | Rejected during config load. |
| Aggregator ID beginning with `~` | Rejected because its target can change during a run. |

**OpenRouter needs an explicit model.** It fronts a catalog rather than a product, so a bare `openrouter` entry is a config error.

**An untagged model never falls back to OpenRouter implicitly.** Bare `claude` means direct-only, always. Routing through OpenRouter is something you write.

#### What happens when a route fails

A session-limit refusal pauses the worker without spending a retry. Aiur trusts the Claude CLI's own API-error marker (aiur-claude forwards it as `provider_error`) or CLI stderr, never assistant text alone. A configured, eligible fallback can take over. Otherwise a valid reset time allows resume on a later poll, subject to capacity and operator pauses.

A Claude reset timestamp that already passed is discarded. Without a valid deadline, recovery requires a fresh provider observation. Pending resume requests retain their identity until acknowledgment, leaving other paused tickets eligible on subsequent polls.

A Codex usage-limit refusal (`codexErrorInfo: usageLimitExceeded` on an `error` notification or a failed `turn/completed`) takes the same path. Aiur reads only the error fields, never assistant or tool text. The ticket status reads `provider_limited`, not `waiting_for_human`.

The Codex reset comes from the exhausted window's numeric `resetsAt` in `account/rateLimits`. Without it, Aiur reads the refusal text, such as "try again at Sep 21st, 2026 6:26 PM", and rounds it up to the end of that minute.

The text names no zone. Aiur reads it in `agent.codex.reset_time_zone`, or in the daemon host's zone when that key is unset. A clock time that passed in the last two hours, or a date without a year that passed in the last day, is not moved a day or a year ahead.

A text reset that already passed never resumes the worker at once. Aiur sets the reset to the refusal time plus `agent.codex.reset_min_delay_seconds` (default 300). A future text reset and the numeric `resetsAt` are kept as they are.

A usage-limit refusal that comes within two hours of the previous one for the same backend backs off. The second refusal holds the backend for 10 minutes, and each later one doubles the hold, to at most one hour. A later provider reset still wins.

Claude clock hints with an IANA timezone are converted to UTC; unknown reset times require a fresh recovery observation.

| Cause | Behaviour |
| --- | --- |
| **No API key configured** | The route is skipped at selection time and the next entry is used. Named once at startup in the log, not per claim. If *every* entry lacks its key, aiur fails loudly rather than dispatching nothing. |
| **Usage or rate limit (429)** | Advances to the next entry and records the backend in `model-usage.json` with its reset time. Self-healing. |
| **Transient error (5xx, timeout, malformed response)** | Retries, then advances **for that claim only**, and raises an operator attention. Deliberately *not* written to `model-usage.json`: that file means "rate-limited until `reset_at`", and recording an outage there would make the outage indistinguishable from a quota event. |
| **Auth rejected (401)** | Does **not** advance. Hard failure plus an attention. A key that is present and wrong is a config error, and falling through would move spend silently onto another route while the broken credential stayed hidden. |

#### `agent.backend_configs.<backend>`

| Key | Type | Default | Controls | <!-- generated-reference:config-configuration-agent-01 -->
| --- | --- | --- | --- |
| `agent.backend_configs.<backend>.api_key_env` | string | backend registry value | Names the environment variable containing the backend API key. |
| `agent.backend_configs.<backend>.balance_baseline` | number or nil | nil | Seeds prepaid-balance usage tracking for backends that expose a balance API. |
| `agent.backend_configs.<backend>.base_url` | URL string | backend registry value | Overrides the registry endpoint for an OpenAI-compatible backend. |
| `agent.backend_configs.<backend>.command` | string | backend registry command | Overrides the backend command used for model discovery and setup where supported. |
| `agent.backend_configs.<backend>.default_model` | string or nil | backend registry value | Overrides the registry fallback model for an OpenAI-compatible backend; `model` takes precedence. |
| `agent.backend_configs.<backend>.enabled` | boolean | backend registry default | Explicitly enables or disables dispatch for the backend. `agent.priority` takes precedence by enabling every backend it names. |
| `agent.backend_configs.<backend>.management_api_key_env` | string or nil | backend registry value | Names the environment variable containing a provider's usage-management API key. |
| `agent.backend_configs.<backend>.model` | string or nil | nil | Selects the backend's default model where the backend accepts a configured model. |
| `agent.backend_configs.<backend>.quirks.local_concurrency_limit` | boolean | backend registry value | Applies aiur's local concurrency slot around backend requests. |
| `agent.backend_configs.<backend>.quirks.openrouter_metadata` | boolean | backend registry value | Enables OpenRouter endpoint metadata used for billing attribution. |
| `agent.backend_configs.<backend>.quirks.reasoning_content_replay` | boolean | backend registry value | Replays reasoning content when the backend requires it in later requests. |
| `agent.backend_configs.<backend>.quirks.text_tool_fallback` | boolean | backend registry value | Parses text-encoded tool calls when the backend does not return structured calls. |
| `agent.backend_configs.<backend>.transport` | string | backend registry value | Overrides the OpenAI-compatible transport with `chat_completions` or `responses`. |

#### `agent.backend_configs.openrouter`

These settings control the OpenRouter *transport*; selection lives entirely in `agent.priority`.

| Key | Type | Default | Controls | <!-- generated-reference:config-configuration-agent-02 -->
| --- | --- | --- | --- |
| `agent.backend_configs.openrouter.provider.allow_fallbacks` | boolean or nil | omitted | Whether OpenRouter may cross to another upstream within one request. |
| `agent.backend_configs.openrouter.provider.ignore` | array of strings or nil | omitted | Upstream providers to exclude. |
| `agent.backend_configs.openrouter.provider.order` | array of strings or nil | omitted | Preferred upstream providers, most preferred first. |
| `agent.backend_configs.openrouter.provider.sort` | string or nil | omitted | `price`, `throughput`, or `latency`. |

#### `agent.backend_configs.muse`

Select `muse` in `agent.priority` to dispatch native Muse sessions. `aiur init` asks separately before trusting an agent workspace; selecting Muse alone leaves that trust disabled. Enable it only for workspaces whose skills and rules you intend Muse to load. Muse CLI authentication is handled by `muse auth` outside Aiur's config.

Local Muse sessions retain a native session handle across Aiur restarts. Aiur starts a fresh session only when Muse explicitly reports that the stored session was not found. Other resume errors, including a busy session, timeout, or mismatched session identity, remain failures to preserve conversation continuity.

Remote workers and Claude Remote Control are unsupported for Muse.

| Key | Type | Default | Controls | <!-- generated-reference:config-configuration-agent-03 -->
| --- | --- | --- | --- |
| `agent.backend_configs.muse.approval_mode` | string | `onRequest` | Muse approval mode: `allowAll`, `promptUnmatched`, `onRequest`, or `denyUnmatched`. |
| `agent.backend_configs.muse.command` | non-empty string | `muse serve` | Command launching the native Muse MSP server. |
| `agent.backend_configs.muse.model` | string or nil | nil | Optional Muse model override; omit to use the CLI default. |
| `agent.backend_configs.muse.provider_id` | string or nil | nil | Optional Muse provider identifier. |
| `agent.backend_configs.muse.trust_workspace` | boolean | `false` | Allows Muse to load workspace-local skills and rules. `aiur init` asks explicitly before writing `true`. |

#### Cost attribution

| Cost case | Attribution |
| --- | --- |
| `openrouter:anthropic/claude-sonnet-5` | Uses OpenRouter's price row because OpenRouter bills the request, even when Anthropic serves it upstream. |
| Same model through direct and OpenRouter routes | Keeps separate identities and may carry different rates. |

Local Codex turns use Aiur's shared build admission.

| Build-gate behavior | Detail |
| --- | --- |
| Admission failure | Mix does not run and the ticket reports status `125`. Repair the reported metadata or lock directory, `flock`, or `python3` dependency, then restart or re-dispatch the agent. |
| `BUILD GATE DEGRADED` | Stop the old fleet, confirm no old Mix verification remains, then clear only the legacy records named in the message. |
| `BUILD GATE HOLDER` / `BUILD GATE QUEUED` | `aiur status` names every held lease: `slot=`, the owning `pid`, the quoted `command`, and how long it has been `held` (or `waiting` while queued). This tells a correctly-busy gate apart from one pinned by a leaked or dead process. A slot whose command process group is gone renders as `held without a command` (and its HOLDER line gains `(command gone)`), so `BUILD GATE n/n active` never claims work is happening when nothing is. |
| Hold-timeout backstop | A slot held past `agent.build_gate_max_hold_seconds` (default 1h) is released by the lease holder itself, which logs and leaves a durable `slot-N.hold-timeout` marker. `aiur status` prints those as `BUILD GATE TIMEOUT` lines, and the daemon raises a needs-attention alert naming the command — the same backstop bounds both a leaked holder waiting on reparented daemons and a `--trace` run that monopolises a slot. |
| Post-command retain | After the wrapped command exits, the holder keeps the slot only while a descendant is still consuming CPU (`agent.build_gate_retain_seconds`, default 120s, is the ceiling for that busy descendant). A descendant tree that goes idle for one second is treated as an adopted session daemon (`dbus-daemon`, `gnome-keyring-daemon`), so the slot is released immediately and nothing is signalled — the keyring daemon holds the fleet's GitHub credential. The effective retain is observable in `aiur status` (`retain_seconds=`) and in the `lease_retained` gate log line. |
| Dead holder | A lease whose holder has exited is released automatically: Linux releases the flock with the process, and the PID fallback reclaims a slot whose recorded owner and process group are gone. A legitimately long-running build with a live holder keeps its lease; only the absolute max-hold backstop reaps by elapsed time. |
| Browser tests | Playwright CLI runs (including `src/browser`) share the host cap and serialize per workspace; only the wrapper holds the workspace lock, so a crashed run's surviving browser child does not keep it. Run only affected browser specs locally; CI runs the full harness. |
| Explicit opt-out | Set `agent.max_concurrent_builds: 0`, set `agent.build_start_stagger_seconds: 0`, and omit `agent.min_free_memory_mb`. This removes every build safeguard. |

Build admission covers direct `mix compile`, `mix test`, `mix lint`, `mix credo` and `mix dialyzer`, `mix do` compounds (`+` or comma), `elixir -S mix`, and `mise exec` / `mise x` after `--` or in a simple `-c` / `--command` string. One compound or nested wrapper chain holds one live-token lease.

Reviewer worktrees run `<repo>/scripts/build-gate mise exec -- mix lint` from `src/`. Set the fleet's `AIUR_BUILD_GATE_DIR` and `AIUR_BUILD_GATE_SLOTS` (required) and copy its other `AIUR_BUILD_*` and `AIUR_MIN_FREE_MEMORY_MB` values. The command holds one `review` lease shown in `aiur status`, keeps its exit status, and fails closed.

Malformed compounds and command strings that could hide a Mix build fail with status `125`. This is a cooperative PATH/shell boundary: aliases of Aiur's wrappers are canonicalized, but deliberately invoking a separate real executable by absolute, relative, or symlinked path bypasses the entrypoint and is not admitted.

## Host-pressure fleet admission

Fleet admission uses CPU PSI and configured reserves, falling back to load when PSI is unavailable, and fails open on missing reserve measurements.

| Signal | Admission behavior |
| --- | --- |
| CPU pressure and AIMD | `agent.max_cpu_pressure` and `agent.target_cpu_pressure` use Linux CPU PSI `some avg60` percentages. After 3 fresh overload samples and `agent.load_cooldown_seconds`, AIMD floors its reduction at half occupied slots or the recorded safe level, capped at the current envelope; it adds `agent.load_ramp_step` only below 80% of target. |
| PSI-unavailable fallback | `agent.max_load_average`, `agent.target_load_average`, and optional `agent.run_queue_threshold` use per-scheduler load and run queue; CPU corroboration applies when available, otherwise raw load. Status explicitly names the fallback. |
| Memory, file descriptors, and provider limits | Defer new dispatch while their configured reserve or limit is exhausted. Build occupancy does not defer dispatch; build concurrency, stagger, and nice throttle bursts separately. |
| Recovery | Gates reopen when pressure clears; unavailable CPU pressure does not count as a zero-pressure recovery sample. |

| Hold signal | Where it appears |
| --- | --- |
| Idle rows | `backing off` |
| Dashboard and status | `capacity_hold` with CPU pressure percent or free memory and its threshold; load fallback is explicitly identified. |
| Telemetry | `capacity_hold` and `capacity_resumed` |
| Alert feed | Debounced `system.fleet.capacity.backoff` |

Holds limit only new admissions. Running agents and agent-spawned sub-agents continue.

## agent.claude

| Key | Type | Default | Controls | <!-- generated-reference:config-configuration-agent-04 -->
| --- | --- | --- | --- |
| `agent.claude.command` | string | `aiur-claude` | Command launching the Claude backend. |
| `agent.claude.model` | string or nil | nil | Optional Claude model override. |
| `agent.claude.permission_mode` | string | `bypassPermissions` | Claude permission mode. |

## agent.codex

Codex settings belong under `agent.codex`; a legacy root-level `codex:` section is rejected with a migration hint rather than silently falling back to defaults.

| Key | Type | Default | Controls | <!-- generated-reference:config-configuration-agent-05 -->
| --- | --- | --- | --- |
| `agent.codex.approval_policy` | string or map | `untrusted` | Runtime policy: `untrusted`, `on-failure`, `on-request`, `granular`, or `never`. |
| `agent.codex.command` | string | `codex app-server` | Command launching the Codex app server. |
| `agent.codex.read_timeout_ms` | integer | 5000 | Codex app-server read timeout. |
| `agent.codex.reset_min_delay_seconds` | integer | 300 | Least wait before a resume when the Codex usage-limit text names a reset that already passed. |
| `agent.codex.reset_time_zone` | string or nil | nil | IANA zone for the reset time in Codex usage-limit text. Nil uses the daemon host's zone. For a remote `worker_host`, set the worker's zone: Aiur cannot read it. The numeric `resetsAt` needs no zone and wins when present. |
| `agent.codex.thrash_max_per_window` | integer | 6 | Rapid restart limit per window. |
| `agent.codex.thrash_window_seconds` | integer | 60 | Thrash-counting sliding window. |
| `agent.codex.thread_sandbox` | string | `workspace-write` | Thread sandbox mode. |
| `agent.codex.turn_sandbox_policy` | map or nil | nil | Explicit per-turn sandbox policy. For local `workspaceWrite`, `writableRoots` contains optional daemon-host extras; every entry must already exist and be writable. Aiur derives the current issue workspace and enabled shared GitHub budget root. Git checkouts also receive write access to their Git metadata and `.agents` directory so tracked skills links can be updated; `.codex` keeps its default protection. Configured extras are not forwarded to SSH workers. |

## Model discovery

Aiur ships a curated model list per backend (`Aiur.CodingAgent.backends/0`). Providers release models faster than that list is edited, so for OpenAI-compatible backends aiur also asks the provider's own catalogue endpoint which models it currently serves, and caches the answer.

Discovery **extends** the curated list without replacing registry-owned effort vocabularies, capabilities, family aliases, presentation, or `aiur init` choices, and curated metadata wins when an ID collides.

| Backend | Endpoint | Credential | Returns |
| --- | --- | --- | --- |
| `openrouter` | `GET https://openrouter.ai/api/v1/models` | none required (sent when `OPENROUTER_API_KEY` is set, so the request is attributed to your account) | identifiers, context window, **and pricing** |
| `deepseek` | `GET https://api.deepseek.com/models` | `DEEPSEEK_API_KEY` | identifiers only |
| `kimi` | `GET https://api.moonshot.ai/v1/models` | `MOONSHOT_API_KEY` | identifiers only |

`codex` and `claude` are not listed: they answer `model/list` over their own CLI transport, which `aiur init` already asks. Anthropic's `GET /v1/models` (`x-api-key`
plus `anthropic-version`) has an adapter for operators who point an OpenAI-compatible
backend straight at it; it returns identifiers and display names, no pricing.

### Cache, TTL, and cold start

| Property | Value |
| --- | --- |
| Location | `model-catalog.json`, beside the active workflow config and `model-usage.json` |
| TTL | 24 hours |
| Refresh trigger | Lazy and backgrounded; reading the usable model set schedules a refresh only when the cache is older than the TTL. |
| Cold offline start | the discovered set is empty and aiur uses exactly the curated list, i.e. it behaves as it did before discovery existed |
| Corrupt cache | treated as absent; falls back to the curated list |

Writes are atomic (temp file plus rename) and a concurrent refresh is a no-op rather than a duplicate request.

**Config validation never makes a network call.** Validation reads the cache and nothing else. An absent or stale cache means "cannot verify", and a model aiur cannot
verify is **accepted**, never rejected.

### Identifiers aiur refuses

Two classes of catalogue id are rejected at ingest, with the reason recorded in the
cache under `rejected`:

- **`reserved_routing_separator`**: an id containing `:`, such as
  `moonshotai/kimi-k2.7-code:batch`. Aiur routing values are `backend:model:effort`, so
  `openrouter:moonshotai/kimi-k2.7-code:batch` would parse `batch` as a reasoning
  effort. Pin such a variant only if and when aiur gains a way to escape the separator.
- **`unstable_identifier_prefix`**: an id starting with `~`, such as
  `~moonshotai/kimi-latest`, which OpenRouter uses for a non-canonical pointer rather
  than an addressable model.

### Pricing is advisory

| Pricing rule | Behavior |
| --- | --- |
| Fetched OpenRouter price | Recorded in the cache for comparison but never written into the curated price table. |
| Curated row | Always wins attribution. |
| Difference above 5% | Logs both numbers as price drift without letting vendor data rewrite reported spend. |

A discovered model with **no** curated price row is usable but visibly unpriced: its
usage reports unknown cost with an `unknown_price_model` coverage reason. It is never
costed at zero. A refresh logs how many discovered models are unpriced.

### Per-backend opt-out

| Key | Type | Default | Controls | <!-- generated-reference:config-configuration-agent-06 -->
| --- | --- | --- | --- |
| `agent.backend_configs.<backend>.model_discovery` | boolean | true | Set `false` to stop aiur asking this backend for its model list. The curated list and any cached list keep working; aiur just stops refreshing them. |

```yaml
agent:
  backend_configs:
    openrouter:
      model_discovery: false
```
