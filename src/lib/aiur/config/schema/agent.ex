defmodule Aiur.Config.Schema.Claude do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    # @config-reference config-configuration-agent-04 agent.claude.command | string | `aiur-claude` | Command launching the Claude backend. |
    field(:command, :string, default: "aiur-claude")
    # @config-reference config-configuration-agent-04 agent.claude.model | string or nil | nil | Optional Claude model override. |
    field(:model, :string)
    # @config-reference config-configuration-agent-04 agent.claude.permission_mode | string | `bypassPermissions` | Claude permission mode. |
    field(:permission_mode, :string, default: "bypassPermissions")
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:command, :model, :permission_mode], empty_values: [])
    |> validate_length(:command, min: 1)
  end
end

defmodule Aiur.Config.Schema.Rtk do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    # Controls whether the analytics panel reports host-level rtk output
    # savings. This does not enable or disable a host-wide rtk hook; the
    # operator owns that hook and must configure it to exclude `gh`.
    # @config-reference config-configuration-agent-00 agent.rtk.enabled
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-00 agent.rtk.enabled | boolean | false | Enables the Agent output compression panel on the analytics page, which reports rtk's host-level output savings when available. Aiur does not install, enable, or disable rtk's hook and does not enforce this setting at agent dispatch. A host-wide rtk hook applies to every agent regardless of this setting; the operator owns the hook and must exclude `gh` (`exclude_commands = ["gh"]` under `[hooks]`), because `gh` in an agent workspace is the GitHub quota guard and rtk must not rewrite it. The analytics panel reports rtk's status, including when its probe detects that `gh` would be rewritten, but cannot disable the hook. At daemon startup Aiur also checks the host hook, independent of this setting, and raises an informational alert when it would rewrite `gh`. |
    field(:enabled, :boolean, default: false)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(schema, attrs) do
    cast(schema, attrs, [:enabled], empty_values: [])
  end
end

defmodule Aiur.Config.Schema.Agent do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Aiur.Config.Schema.{AgentValidation, Claude, Codex, GitIdentity, PricingPolicy, Rtk}

  @primary_key false
  embedded_schema do
    # Deprecated: `priority` wins when present; read the effective value via `Aiur.Config.agent_kind/0`.
    # @config-reference config-configuration-agent-00 agent.kind | string | `codex` | Deprecated default backend; ignored when `agent.priority` is non-empty. |
    field(:kind, :string, default: Aiur.CodingAgent.default_backend())

    # Ordered dispatch preference. Presence enables a backend, the first available entry is the default, and the array is the fallback order when a backend hits a token or usage limit.
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-00 agent.priority | array | `[]` | Ordered dispatch preference as routes (`backend` or `backend:model`); see the Routes section. A non-empty list replaces the legacy kind and fallback settings. |
    field(:priority, {:array, :string}, default: [])
    # Setting #2 (RC opt-in), orthogonal to :kind. Only consulted when the
    # resolved backend is RC-capable. This default is the single flip point
    # for always-remote: change `false` here and every dispatch attaches RC.
    # @config-reference config-configuration-agent-00 agent.remote_control | boolean | false | Opts RC-capable backends into remote control. |
    field(:remote_control, :boolean, default: false)
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-00 agent.relay | boolean | true | Runs local Codex app-server and headless Claude behind a detached relay. `false` uses direct Port transport; remote SSH workers keep their existing transport. |
    field(:relay, :boolean, default: true)
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-00 agent.relay_orphan_timeout_seconds | integer | 1800 | Stops the provider process group after this many seconds without a relay controller. Must be positive. |
    field(:relay_orphan_timeout_seconds, :integer, default: 1_800)
    # When true, a re-dispatch of a ticket the orchestrator already ran (a
    # max_turns recycle or completed-entry replacement) whose codex thread could
    # not be resumed gets continuation guidance instead of the cold-start prompt,
    # so it does not re-run brainstorm/plan over work that already exists.
    # @config-reference config-configuration-agent-00 agent.prior_work_continuation | boolean | true | Lets a resumed ticket continue existing workspace work when policy permits. |
    field(:prior_work_continuation, :boolean, default: true)
    # Lifetime cap on (re)dispatches for one ticket. The per-window thrash
    # breaker resets whenever its window lapses, so a slowly-churning ticket is
    # never circuit-broken. 0 disables the latch.
    # @config-reference config-configuration-agent-00 agent.max_dispatches_per_ticket | integer | 0 | Per-ticket dispatch latch; 0 disables the latch. |
    field(:max_dispatches_per_ticket, :integer, default: 0)
    # Ceiling for new fleet admissions. When omitted (nil), it derives from the
    # measured host capacity (see `Config.default_max_concurrent_agents/1`):
    # schedulers + 1/4 schedulers, which matches the measured ~19-20 concurrent
    # agents on a 16-core host. Explicit config still wins. The load envelope
    # reduces effective concurrency below this ceiling under host pressure.
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-00 agent.max_concurrent_agents | integer or nil | derived from host capacity | Global simultaneous-agent cap; omitted values derive from measured host scheduler capacity. |
    field(:max_concurrent_agents, :integer)
    # Per-scheduler runnable-process ceiling for the instantaneous run-queue
    # dispatch gate. nil disables the gate (the 1-minute load gate and envelope
    # still apply); a positive value holds new dispatch while `procs_running`
    # strictly exceeds `run_queue_threshold * schedulers`, catching short CPU
    # bursts the lagging load average smooths out.
    # @config-reference config-configuration-agent-00 agent.run_queue_threshold | float or nil | nil | Optional per-scheduler runnable ceiling used when CPU PSI is unavailable; null disables it. |
    field(:run_queue_threshold, :float)
    # Fleet-wide cap for agent-launched `mix compile` / `mix test` commands.
    # 0 deliberately disables the gate for Executors who need unrestricted
    # local verification.
    # @config-reference config-configuration-agent-00 agent.max_concurrent_builds | integer | 4 | Caps local agent Mix verification and browser tests; 0 disables the cap. |
    field(:max_concurrent_builds, :integer, default: 4)
    # @config-reference config-configuration-agent-00 agent.build_nice | integer | 10 | CPU nice adjustment (0–19) applied to admitted build commands; 0 preserves launch priority. |
    field(:build_nice, :integer, default: 10)
    # Minimum spacing between local Mix compile/test starts when more than one
    # build may run concurrently. 0 disables start pacing.
    # @config-reference config-configuration-agent-00 agent.build_start_stagger_seconds | integer | 0 | Minimum spacing between local Mix build starts; 0 disables pacing. |
    field(:build_start_stagger_seconds, :integer, default: 0)
    # Optional Linux MemAvailable floor shared by normal dispatch and the local
    # Mix build gate. Omitted means memory admission is disabled.
    # @config-reference config-configuration-agent-00 agent.min_free_memory_mb | integer or nil | nil | Linux MemAvailable floor shared by dispatch and the Mix build gate. |
    field(:min_free_memory_mb, :integer)
    # Absolute wall-clock cap (seconds) on how long any one build-gate slot may
    # be held (#2349). The detached lease holder releases the slot at the cap
    # and the daemon raises a needs-attention alert naming the command. 0
    # disables the backstop.
    # @config-reference config-configuration-agent-00 agent.build_gate_max_hold_seconds | integer | 3600 | Absolute wall-clock cap on a build-gate slot; 0 disables the backstop. |
    field(:build_gate_max_hold_seconds, :integer, default: 3_600)
    # Maximum post-command courtesy window (seconds) the detached holder keeps
    # a slot after the wrapped command exits, gated on a descendant still
    # consuming CPU (#2398). The holder releases the moment the retained tree
    # goes idle, so this is the *ceiling* for a genuinely-busy descendant, not
    # a per-build hold. 0 disables the courtesy.
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-00 agent.build_gate_retain_seconds | integer | 120 | Maximum post-command slot window while a descendant still consumes CPU; 0 disables the courtesy. |
    field(:build_gate_retain_seconds, :integer, default: 120)
    # nil = uncapped (no per-issue turn limit). A YAML value of `none` /
    # `unlimited` (or an absent key) resolves to nil; any present number must
    # be > 0.
    #
    # #2806 asked whether this should default to a finite value, and the answer
    # is no. This cap counts *effort*, not outcome: it cannot tell eleven wasted
    # turns from eleven turns of real work, so any default low enough to stop a
    # spin is also low enough to cut a legitimate long run short. Reaching it
    # does not abort the ticket — the loop hands control back and the
    # orchestrator recycles the ticket with `prior_work: true` — but that costs
    # a fresh provider session and the context rebuild #378 exists to avoid.
    # `max_consecutive_noop_turns` below is the outcome-based bound instead:
    # productive turns are unbounded, unproductive ones are not. Operators who
    # do want an effort cap set this key, or `max_turns_by_complexity`.
    # @config-reference config-configuration-agent-00 agent.max_turns | integer or nil | nil | Per-issue turn cap; nil is uncapped. |
    field(:max_turns, :integer)
    # #2806: how many CONSECUTIVE continuation turns that changed nothing
    # observable (no commit, no push, no working-tree change, no label change,
    # and no new input in the prompt) a run may take before the loop stops and
    # raises a needs-attention alert. A productive turn resets the count, so
    # this never caps a long run of real work — unlike `max_turns`, which does.
    # 0 / `nil` disables the bound.
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-00 agent.max_consecutive_noop_turns | integer | 3 | Consecutive continuation turns with no observable progress before the loop stops; 0 disables the bound. |
    field(:max_consecutive_noop_turns, :integer, default: 3)
    # @config-reference config-configuration-agent-00 agent.max_retry_attempts | integer | 3 | Failed-turn retry count. |
    field(:max_retry_attempts, :integer, default: 3)
    # @config-reference config-configuration-agent-00 agent.max_retry_backoff_ms | integer | 300000 | Retry backoff ceiling in milliseconds. |
    field(:max_retry_backoff_ms, :integer, default: 300_000)
    # @config-reference config-configuration-agent-00 agent.max_concurrent_agents_by_state | map | `%{}` | Per-state caps overriding the global cap. |
    field(:max_concurrent_agents_by_state, :map, default: %{})
    # Provider settings are keyed by the backend's registry name. Built-in
    # schemas remain as typed compatibility views, while a new backend can keep
    # its section here without adding another Ecto embed to this module.
    # Provider-specific map paths are expanded by scripts/check-config-docs.py.
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.enabled | boolean | backend registry default | Explicitly enables or disables dispatch for the backend. `agent.priority` takes precedence by enabling every backend it names. |
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.command | string | backend registry command | Overrides the backend command used for model discovery and setup where supported. |
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.model | string or nil | nil | Selects the backend's default model where the backend accepts a configured model. |
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-06 agent.backend_configs.<backend>.model_discovery | boolean | true | Set `false` to stop aiur asking this backend for its model list. The curated list and any cached list keep working; aiur just stops refreshing them. |
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.default_model | string or nil | backend registry value | Overrides the registry fallback model for an OpenAI-compatible backend; `model` takes precedence. |
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.base_url | URL string | backend registry value | Overrides the registry endpoint for an OpenAI-compatible backend. |
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.api_key_env | string | backend registry value | Names the environment variable containing the backend API key. |
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.management_api_key_env | string or nil | backend registry value | Names the environment variable containing a provider's usage-management API key. |
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.transport | string | backend registry value | Overrides the OpenAI-compatible transport with `chat_completions` or `responses`. |
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.balance_baseline | number or nil | nil | Seeds prepaid-balance usage tracking for backends that expose a balance API. |
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.quirks.reasoning_content_replay | boolean | backend registry value | Replays reasoning content when the backend requires it in later requests. |
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.quirks.text_tool_fallback | boolean | backend registry value | Parses text-encoded tool calls when the backend does not return structured calls. |
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.quirks.openrouter_metadata | boolean | backend registry value | Enables OpenRouter endpoint metadata used for billing attribution. |
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-01 agent.backend_configs.<backend>.quirks.local_concurrency_limit | boolean | backend registry value | Applies aiur's local concurrency slot around backend requests. |
    # @config-reference config-configuration-agent-02 agent.backend_configs.openrouter.provider.order | array of strings or nil | omitted | Preferred upstream providers, most preferred first. |
    # @config-reference config-configuration-agent-02 agent.backend_configs.openrouter.provider.ignore | array of strings or nil | omitted | Upstream providers to exclude. |
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-02 agent.backend_configs.openrouter.provider.allow_fallbacks | boolean or nil | omitted | Whether OpenRouter may cross to another upstream within one request. |
    # @config-reference config-configuration-agent-02 agent.backend_configs.openrouter.provider.sort | string or nil | omitted | `price`, `throughput`, or `latency`. |
    # @config-reference config-configuration-agent-00 agent.backend_configs | map | `%{}` | Provider-specific configuration, including per-backend settings and credentials. |
    field(:backend_configs, :map, default: %{})
    # @config-reference config-configuration-agent-00 agent.routing | map | `%{}` | Maps complexity levels to backend/model/effort routing. |
    field(:routing, :map, default: %{})
    # Derived, never cast: every level's route list when a routing value is a
    # list (`AgentValidation.split_routing_candidates/1`, #3960).
    # @config-reference config-configuration-agent-00 agent.routing_candidates | map | `%{}` | Read-only routes derived from list values in `agent.routing`. |
    field(:routing_candidates, :map, default: %{})
    # @config-reference config-configuration-agent-00 agent.accounts | map | `%{}` | Machine-local account names enabled per harness; list order sets preference. |
    field(:accounts, :map, default: %{})
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-00 agent.account_selection | string | `balance` | Selects an enabled account by weekly utilization, configured order, or remaining usage headroom. |
    field(:account_selection, :string, default: "balance")
    # Headroom dispatch treats a usage reading older than this as unknown (#3960).
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-00 agent.headroom_reading_max_age_seconds | integer | 1800 | Usage readings older than this score as unknown when using headroom account selection. |
    field(:headroom_reading_max_age_seconds, :integer, default: 1800)
    # @config-reference config-configuration-agent-00 agent.switch_model_on_ratelimit | array | `[]` | Deprecated fallback order; ignored when `agent.priority` is non-empty. |
    field(:switch_model_on_ratelimit, {:array, :string}, default: [])
    # Automatic reroute for an ALREADY-RUNNING agent on `rate_limit_primary`
    # that hits usage_limit_exhausted, reverted at a safe boundary once
    # ModelAvailability confirms the primary recovered
    # (Aiur.Orchestrator.RateLimitFallback). Default on, unlike
    # switch_model_on_ratelimit above (opt-in, applies only to a new claim).
    # Both name a registered backend and the pair is validated below; the
    # defaults preserve the historical codex -> claude reroute. "" on the
    # fallback disables it.
    # @config-reference config-configuration-agent-00 agent.rate_limit_primary | string | default backend | Deprecated backend watched for automatic rate-limit recovery. |
    field(:rate_limit_primary, :string, default: Aiur.CodingAgent.default_backend())
    # @config-reference config-configuration-agent-00 agent.rate_limit_fallback | string | `claude` | Deprecated recovery backend; an empty string disables it. |
    field(:rate_limit_fallback, :string, default: Aiur.CodingAgent.default_rate_limit_fallback())
    # @config-reference config-configuration-agent-00 agent.complexity_prompts | map | `%{}` | Adds prompt guidance by complexity level. |
    field(:complexity_prompts, :map, default: %{})
    # @config-reference config-configuration-agent-00 agent.max_turns_by_complexity | map | `%{}` | Per-complexity turn caps. |
    field(:max_turns_by_complexity, :map, default: %{})
    # Backend-agnostic turn/stall timeouts (promoted from codex; claude-repl
    # already reads these via Config.agent_turn_timeout_ms/0).
    # @config-reference config-configuration-agent-00 agent.turn_timeout_ms | integer | 3600000 | Backstop timeout for one turn. |
    field(:turn_timeout_ms, :integer, default: 3_600_000)
    # @config-reference config-configuration-agent-00 agent.stall_timeout_ms | integer | 3600000 | Silent-agent watchdog; 0 disables it. |
    field(:stall_timeout_ms, :integer, default: 3_600_000)
    # Safety checkpoint: pause an agent that has been actively running this
    # many minutes (paused/blocked time excluded). 0 disables it.
    # @config-reference config-configuration-agent-00 agent.max_agent_duration_minutes | integer | 60 | Active-runtime pause checkpoint; 0 disables it. |
    field(:max_agent_duration_minutes, :integer, default: 60)
    # A CI-wait pause releases its dispatch slot. If no terminal CI event is
    # observed in this window, wake the agent for one recovery check.
    # @config-reference config-configuration-agent-00 agent.ci_wait_rewake_minutes | positive integer | 5 | Re-wakes a CI-wait agent for one recovery check when no terminal event arrives. |
    field(:ci_wait_rewake_minutes, :integer, default: 5)
    # @config-reference config-configuration-agent-00 agent.ci_recovery_enabled | boolean | true | Enables automatic CI recovery reruns; false disables them. |
    field(:ci_recovery_enabled, :boolean, default: true)
    # @config-reference config-configuration-agent-00 agent.ci_recovery_max_per_poll | positive integer | 5 | Maximum recovery reruns admitted by one CI poll. |
    field(:ci_recovery_max_per_poll, :integer, default: 5)
    # @config-reference config-configuration-agent-00 agent.ci_recovery_max_per_hour | positive integer | 20 | Maximum recovery reruns admitted in a rolling hour. |
    field(:ci_recovery_max_per_hour, :integer, default: 20)
    # Linux CPU PSI some avg60 percentages; explicit null disables each.
    # @config-reference config-configuration-agent-00 agent.max_cpu_pressure | float or nil | 20.0 | Linux CPU PSI some avg60 ceiling in percent; null disables the gate. |
    field(:max_cpu_pressure, :float, default: 20.0)
    # @config-reference config-configuration-agent-00 agent.target_cpu_pressure | float or nil | 10.0 | Adaptive CPU PSI target in percent; null disables adaptive pressure control. |
    field(:target_cpu_pressure, :float, default: 10.0)
    # Per-scheduler load settings apply only when CPU PSI is unavailable.
    # @config-reference config-configuration-agent-00 agent.max_load_average | float or nil | 1.5 | Per-scheduler load ceiling used when CPU PSI is unavailable; null disables it. |
    field(:max_load_average, :float, default: 1.5)
    # @config-reference config-configuration-agent-00 agent.target_load_average | float or nil | 1.0 | Per-scheduler adaptive target used when CPU PSI is unavailable; null disables it. |
    field(:target_load_average, :float, default: 1.0)
    # @config-reference config-configuration-agent-00 agent.load_resume_max_age_seconds | integer | 21600 | Maximum age in seconds for a host-pressure observation before it is stale. |
    field(:load_resume_max_age_seconds, :integer, default: 21_600)
    # @config-reference config-configuration-agent-00 agent.load_ramp_step | integer | 1 | Per-reconciliation concurrency adjustment while load is recovering. |
    field(:load_ramp_step, :integer, default: 1)
    # @config-reference config-configuration-agent-00 agent.load_cooldown_seconds | integer | 60 | Seconds between successive load-gate reductions. |
    field(:load_cooldown_seconds, :integer, default: 60)
    # nil = derive from schedulers_online/4; 0 disables the runtime synthetic
    # load-generator guard; positive integers cap known generators per agent.
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    # @config-reference config-configuration-agent-00 agent.synthetic_load_process_cap | integer or nil | derived | Per-agent cap for recognized synthetic load generators; nil derives from scheduler count. |
    field(:synthetic_load_process_cap, :integer)
    # false = busy-loop-detected and orphaned generators are reported, not killed.
    # @config-reference config-configuration-agent-00 agent.synthetic_load_kill_detected | boolean | false | Kills a detected busy-loop or orphaned synthetic load generator when enabled. |
    field(:synthetic_load_kill_detected, :boolean, default: false)
    # Cap ERTS scheduler threads on agent-spawned Mix BEAMs via
    # ELIXIR_ERL_OPTIONS="+S N:N". ExUnit defaults max_cases to this value, so
    # four bounds every agent test shape without relying on prompt compliance.
    # @config-reference config-configuration-agent-00 agent.mix_scheduler_cap | integer | 4 | Caps ERTS scheduler threads for agent-launched Mix processes. |
    field(:mix_scheduler_cap, :integer, default: 4)
    # Saturation sentinel (#1429): a daemon-side recorder that appends
    # VM-internal + host diagnostics to saturation.log once 1-min load crosses
    # the escalation threshold, so a crash under saturation (the sparse
    # `erl_child_setup` dump has no stack) is interpretable. Default on; set
    # false to disable the recorder.
    # @config-reference config-configuration-agent-00 agent.saturation_log_enabled | boolean | true | Records host and VM diagnostics when sustained load crosses the saturation threshold. |
    field(:saturation_log_enabled, :boolean, default: true)
    # Minimum seconds a ready-work capacity-starvation condition must persist
    # before `system.dispatch.capacity_starved` / `system.fleet.capacity.starved`
    # raise. The below-target dispatch ramp clears itself within a few poll
    # cycles, so this dwell keeps the intended ramp quiet while a genuine gate
    # that outlives the bound still raises (#2447).
    # @config-reference config-configuration-agent-00 agent.capacity_starvation_alert_after_seconds | integer | 60 | Seconds ready-work capacity starvation must persist before an alert. |
    field(:capacity_starvation_alert_after_seconds, :integer, default: 60)
    # The sliding window over which budget-broker-timeout retries are counted
    # (#2464). The retry rate is the whole signal — the individual retry is
    # uninteresting — and this is how much recent history the rate is measured
    # over. The measured 2026-08-24 fault produced 28 timeouts in ~10 minutes.
    # @config-reference config-configuration-agent-00 agent.budget_broker_rate_window_seconds | integer | 300 | Sliding window for counting budget-broker timeout retries. |
    field(:budget_broker_rate_window_seconds, :integer, default: 300)
    # The retry count within the window above which the broker counts as
    # degraded. Default sits above an isolated timeout (which must page nobody)
    # while keeping "if the normal rate is zero, almost any sustained rate is
    # worth surfacing". Derived from a measured quiet-period baseline, not
    # guessed — this is the knob an operator tunes from their own baseline.
    # @config-reference config-configuration-agent-00 agent.budget_broker_degraded_retry_threshold | integer | 5 | Retries in the window above which the budget broker counts as degraded. |
    field(:budget_broker_degraded_retry_threshold, :integer, default: 5)
    # How long the degraded retry rate must persist before the single
    # `system.github.budget_broker_degraded` alert raises (#2434/#2449 dwell):
    # a momentary blip that clears within this bound produces nothing, a
    # sustained degradation raises exactly once. Kept longer than the rate
    # window so a burst that stops ages out of the window before the dwell
    # completes — the dwell then filters exactly the momentary cases.
    # @config-reference config-configuration-agent-00 agent.budget_broker_degraded_alert_after_seconds | integer | 600 | Dwell before a degraded budget-broker alert is raised. |
    field(:budget_broker_degraded_alert_after_seconds, :integer, default: 600)

    embeds_one(:claude, Claude, on_replace: :update, defaults_to_struct: true)
    embeds_one(:codex, Codex, on_replace: :update, defaults_to_struct: true)
    embeds_one(:git_identity, GitIdentity, on_replace: :update, defaults_to_struct: true)
    embeds_one(:pricing_policy, PricingPolicy, on_replace: :update, defaults_to_struct: true)
    embeds_one(:rtk, Rtk, on_replace: :update, defaults_to_struct: true)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(schema, attrs) do
    schema
    |> cast(
      AgentValidation.prepare_attrs(attrs),
      [
        :kind,
        :priority,
        :remote_control,
        :relay,
        :relay_orphan_timeout_seconds,
        :prior_work_continuation,
        :max_dispatches_per_ticket,
        :max_concurrent_agents,
        :run_queue_threshold,
        :max_concurrent_builds,
        :build_nice,
        :build_start_stagger_seconds,
        :min_free_memory_mb,
        :build_gate_max_hold_seconds,
        :build_gate_retain_seconds,
        :max_turns,
        :max_retry_attempts,
        :max_retry_backoff_ms,
        :max_concurrent_agents_by_state,
        :backend_configs,
        :routing,
        :accounts,
        :account_selection,
        :headroom_reading_max_age_seconds,
        :switch_model_on_ratelimit,
        :rate_limit_primary,
        :rate_limit_fallback,
        :complexity_prompts,
        :max_turns_by_complexity,
        :turn_timeout_ms,
        :stall_timeout_ms,
        :max_agent_duration_minutes,
        :ci_wait_rewake_minutes,
        :ci_recovery_enabled,
        :ci_recovery_max_per_poll,
        :ci_recovery_max_per_hour,
        :max_cpu_pressure,
        :target_cpu_pressure,
        :max_load_average,
        :target_load_average,
        :load_resume_max_age_seconds,
        :load_ramp_step,
        :load_cooldown_seconds,
        :synthetic_load_process_cap,
        :synthetic_load_kill_detected,
        :mix_scheduler_cap,
        :saturation_log_enabled,
        :capacity_starvation_alert_after_seconds,
        :budget_broker_rate_window_seconds,
        :budget_broker_degraded_retry_threshold,
        :budget_broker_degraded_alert_after_seconds
      ],
      empty_values: []
    )
    |> validate_number(:relay_orphan_timeout_seconds, greater_than: 0)
    |> validate_number(:max_concurrent_agents, greater_than: 0)
    |> validate_inclusion(:account_selection, ["balance", "priority", "headroom"])
    |> validate_number(:headroom_reading_max_age_seconds, greater_than: 0)
    |> validate_change(:accounts, &validate_accounts/2)
    |> validate_number(:run_queue_threshold, greater_than: 0)
    |> validate_number(:max_concurrent_builds, greater_than_or_equal_to: 0)
    |> validate_required([:build_nice])
    |> validate_number(:build_nice, greater_than_or_equal_to: 0, less_than_or_equal_to: 19)
    |> validate_number(:build_start_stagger_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:min_free_memory_mb, greater_than: 0)
    |> validate_number(:build_gate_max_hold_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:build_gate_retain_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:max_turns, greater_than: 0)
    |> validate_number(:max_dispatches_per_ticket, greater_than_or_equal_to: 0)
    |> validate_number(:max_retry_attempts, greater_than: 0)
    |> validate_number(:max_retry_backoff_ms, greater_than: 0)
    |> validate_number(:turn_timeout_ms, greater_than: 0)
    |> validate_number(:stall_timeout_ms, greater_than_or_equal_to: 0)
    |> validate_number(:max_agent_duration_minutes, greater_than_or_equal_to: 0)
    |> validate_number(:ci_wait_rewake_minutes, greater_than: 0)
    |> validate_number(:ci_recovery_max_per_poll, greater_than: 0)
    |> validate_number(:ci_recovery_max_per_hour, greater_than: 0)
    |> validate_number(:max_cpu_pressure, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:target_cpu_pressure, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:max_load_average, greater_than: 0)
    |> validate_number(:target_load_average, greater_than: 0)
    |> validate_number(:load_resume_max_age_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:load_ramp_step, greater_than: 0)
    |> validate_number(:load_cooldown_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:synthetic_load_process_cap, greater_than_or_equal_to: 0)
    |> validate_number(:mix_scheduler_cap, greater_than: 0)
    |> validate_number(:capacity_starvation_alert_after_seconds, greater_than: 0)
    |> validate_number(:budget_broker_rate_window_seconds, greater_than: 0)
    |> validate_number(:budget_broker_degraded_retry_threshold, greater_than: 0)
    |> validate_number(:budget_broker_degraded_alert_after_seconds, greater_than: 0)
    |> AgentValidation.validate_backend_configs()
    |> update_change(:max_concurrent_agents_by_state, &AgentValidation.normalize_state_limits/1)
    |> AgentValidation.validate_state_limits(:max_concurrent_agents_by_state)
    |> update_change(:routing, &AgentValidation.normalize_agent_routing/1)
    |> AgentValidation.validate_agent_routing(:routing)
    |> AgentValidation.split_routing_candidates()
    |> AgentValidation.validate_dispatch_selections()
    |> AgentValidation.validate_agent_priority(:priority)
    |> validate_change(:switch_model_on_ratelimit, fn :switch_model_on_ratelimit, backends ->
      known = Aiur.CodingAgent.known_backends()

      cond do
        backends != Enum.uniq(backends) -> [switch_model_on_ratelimit: "must not contain duplicate backends"]
        Enum.all?(backends, &(&1 in known)) -> []
        true -> [switch_model_on_ratelimit: "contains an unknown backend; known backends: #{inspect(known)}"]
      end
    end)
    |> validate_change(:rate_limit_primary, fn :rate_limit_primary, backend ->
      known = Aiur.CodingAgent.known_backends()

      if backend in known,
        do: [],
        else: [rate_limit_primary: "must be a registered backend; known backends: #{inspect(known)}"]
    end)
    |> AgentValidation.validate_rate_limit_fallback()
    |> update_change(:complexity_prompts, &AgentValidation.normalize_complexity_prompts/1)
    |> AgentValidation.validate_complexity_prompts(:complexity_prompts)
    |> update_change(:max_turns_by_complexity, &AgentValidation.normalize_max_turns_by_complexity/1)
    |> AgentValidation.validate_max_turns_by_complexity(:max_turns_by_complexity)
    |> cast_embed(:claude, with: &Claude.changeset/2)
    |> cast_embed(:codex, with: &Codex.changeset/2)
    |> cast_embed(:git_identity, with: &GitIdentity.changeset/2)
    |> cast_embed(:pricing_policy, with: &PricingPolicy.changeset/2)
    |> cast_embed(:rtk, with: &Rtk.changeset/2)
  end

  defp validate_accounts(field, accounts) when is_map(accounts) do
    if Enum.all?(accounts, fn {harness, names} ->
         is_binary(harness) and is_list(names) and Enum.all?(names, &is_binary/1)
       end) do
      []
    else
      [{field, "must map harness names to lists of account names"}]
    end
  end

  defp validate_accounts(field, _accounts), do: [{field, "must be a map"}]
end
