defmodule Aiur.ControlCall.Allowlist do
  @moduledoc false
  alias Aiur.ControlCall.Allowlist.Facade

  @agent [:Aiur, :AgentControlCLI]
  @handoff [:Aiur, :Handoff, :CLI]
  @session [:Aiur, :HarnessSessionCLI]
  @ticket_usage [:Aiur, :TicketUsageCLI]
  @sweep [:Aiur, :ExecutorSweep, :CLI]
  @pr_merge [:Aiur, :PrMerge, :Record]

  # Each signature has {scope, positional constraints, keyword constraints}.
  @agent_rows [
    {:status, 0, :read, [], %{status_timeout_ms: :positive, section_timeout_ms: :positive}},
    {:status, 1, :read, [:keyword], %{status_timeout_ms: :positive, section_timeout_ms: :positive}},
    {:agents, 0, :read, [], %{}},
    {:agents, 1, :read, [:keyword], %{all: :boolean}},
    {:watch, 0, &__MODULE__.watch_scope/1, [], %{mode: {:enum, [:full, :summary]}, json: :boolean}},
    {:watch, 1, &__MODULE__.watch_scope/1, [:keyword], %{mode: {:enum, [:full, :summary]}, json: :boolean}},
    {:alerts, 1, &__MODULE__.alerts_scope/1, [:keyword], %{argv: :literal_list, json: :boolean}},
    {:executor_sweep, 1, &__MODULE__.sweep_scope/1, [:keyword], %{argv: :literal_list, json: :boolean}},
    {:commands, 0, :read, [], %{}},
    {:commands, 1, :read, [:keyword], %{json: :boolean}},
    {:units, 0, :read, [], %{}},
    {:units, 1, :read, [:keyword], %{json: :boolean}},
    {:feature, 1, &__MODULE__.show_scope/1, [:keyword], %{argv: :literal_list, ids: :string_list, json: :boolean, who: :string}},
    {:feature, 0, &__MODULE__.show_scope/1, [], %{}},
    {:epic, 1, &__MODULE__.show_scope/1, [:keyword], %{argv: :literal_list, ids: :string_list, json: :boolean, who: :string}},
    {:epic, 0, &__MODULE__.show_scope/1, [], %{}},
    {:build_orders, 0, :read, [], %{}},
    {:build_orders, 1, :read, [:keyword], %{argv: :literal_list, json: :boolean}},
    {:queue, 0, &__MODULE__.show_scope/1, [], %{argv: :literal_list, json: :boolean}},
    {:queue, 1, &__MODULE__.show_scope/1, [:keyword], %{argv: :literal_list, json: :boolean}},
    {:analytics, 0, :read, [], %{}},
    {:analytics, 1, :read, [:keyword], %{argv: :literal_list, json: :boolean}},
    {:github_cost, 0, :read, [], %{}},
    {:github_cost, 1, :read, [:keyword], %{argv: :literal_list, json: :boolean}},
    {:experiments, 0, &__MODULE__.experiment_scope/1, [], %{argv: :literal_list, verb: {:enum, [:show, :list, :status, :create, :update, :run, :cancel]}, json: :boolean}},
    {:experiments, 1, &__MODULE__.experiment_scope/1, [:keyword], %{argv: :literal_list, verb: {:enum, [:show, :list, :status, :create, :update, :run, :cancel]}, json: :boolean}},
    {:capabilities, 1, :read, [:keyword], %{json: :boolean}},
    {:capabilities, 0, :read, [], %{}},
    {:github_usage, 0, :read, [], %{}},
    {:github_usage, 1, :read, [:keyword], %{argv: :literal_list, json: :boolean}},
    {:ticket_estimate, 0, &__MODULE__.estimate_scope/1, [], %{}},
    {:ticket_estimate, 1, &__MODULE__.estimate_scope/1, [:keyword], %{id: :positive, hours: {:regex, ~r/^\d+(\.\d+)?$/}, clear: :boolean, reason: :string, by: :string, json: :boolean}},
    {:executor_answer, 1, :write, [:keyword], %{decision_id: :string, option_id: :string, expected_version: :positive, confirmation: :string, who: :string, actor: :string}},
    {:operator_answer, 1, :deny, [:keyword], %{decision_id: :string, operator: :boolean, option_id: :string, expected_version: :positive, confirmation: :string}},
    {:operator_answer_preview, 1, :deny, [:keyword], %{decision_id: :string, operator: :boolean, option_id: :string, expected_version: :positive, confirmation: :string}},
    {:executor_escalate, 1, :write, [:keyword], %{argv: :literal_list, decision_id: :string, expected_version: :positive, who: :string, actor: :string}},
    {:executor_reclassify, 1, :write, [:keyword], %{argv: :literal_list, decision_id: :string, expected_version: :positive, authority: :string, who: :string, actor: :string}},
    {:executor_moot, 1, :write, [:keyword], %{argv: :literal_list, decision_id: :string, expected_version: :positive, reason: :string, who: :string, actor: :string}},
    {:executor_wait, 1, &__MODULE__.wait_scope/1, [:keyword], %{timeout_ms: :positive, json: :boolean, as: {:regex, ~r/^[A-Za-z0-9._-]+$/}, session_id: :string, harness: :string, env: :env}},
    {:executor_wait, 0, :write, [], %{}},
    {:executor_roster, 0, :read, [], %{}},
    {:executor_roster, 1, :read, [:keyword], %{json: :boolean}},
    {:executor_fast_forward, 1, :write, [:positive], %{}},
    {:executor_fast_forward, 2, :write, [:positive, :keyword], %{}},
    {:executor_claim, 1, :write, [:keyword], %{as: {:regex, ~r/^[A-Za-z0-9._-]+$/}}},
    {:executor_claim, 0, :write, [], %{}},
    {:executor_release, 1, :write, [:keyword], %{as: {:regex, ~r/^[A-Za-z0-9._-]+$/}}},
    {:executor_release, 0, :write, [], %{}},
    {:executor_revoke, 1, :write, [:string], %{}},
    {:executor_revoke, 2, :write, [:string, :keyword], %{now: :integer}},
    {:executor_emit, 2, :write, [:string, :string], %{}},
    {:executor_subscribe, 1, :write, [:string], %{}},
    {:executor_unsubscribe, 1, :write, [:string], %{}},
    {:executor_subscriptions, 0, :read, [], %{}},
    {:executor_listen_validate, 1, :read, [:string], %{}},
    {:todo, 1, :write, [:string_list], %{only: :boolean, budget_ms: :positive, emit_exit_marker: :boolean}},
    {:todo, 2, :write, [:string_list, :keyword], %{only: :boolean, budget_ms: :positive, emit_exit_marker: :boolean}},
    {:reset_budget, 1, :write, [:string_list], %{}},
    {:pause_global, 0, :write, [], %{}},
    {:resume_global, 0, :write, [], %{}},
    {:set_max_agents, 1, :write, [:positive], %{}},
    {:message, 2, :write, [:string, :string], %{}},
    {:message, 3, :write, [:string, :string, :string], %{}},
    {:pause, 1, :write, [:string_list], %{}},
    {:resume, 1, :write, [:string_list], %{}},
    {:park, 1, :write, [:string_list], %{}},
    {:take, 2, :write, [:string_list, :string], %{}},
    {:release, 2, :write, [:string_list, :string], %{}},
    {:recover_workspace, 2, :write, [:string, :positive], %{}},
    {:usage, 0, :read, [], %{}},
    {:usage, 1, :deny, [:atom], %{}},
    {:usage, 2, :deny, [:atom, :keyword], %{}},
    {:accounts, 1, :read, [:boolean], %{}},
    {:accounts, 2, :read, [:boolean, {:nullable, :string}], %{}},
    {:usage_bar, 1, :deny, [:integer], %{}},
    {:prepare_handoff, 0, :deny, [], %{}},
    {:main_watch_state, 0, :deny, [], %{}},
    {:main_watch_inherited?, 2, :deny, [:any, :any], %{}},
    {:executor_listen, 0, :deny, [], %{}},
    {:executor_listen, 1, :deny, [:keyword], %{}}
  ]

  @rows Enum.map(@agent_rows, fn {function, arity, class, positional, options} -> {{@agent, function, arity}, %{class: class, positional: positional, options: options}} end) ++
          [
            {{@handoff, :report, 0}, %{class: :read, positional: [], options: %{json: :boolean, wait_ms: :non_negative, expected_id: :string}}},
            {{@handoff, :report, 1}, %{class: :read, positional: [:keyword], options: %{json: :boolean, wait_ms: :non_negative, expected_id: :string}}},
            {{@handoff, :agents, 0}, %{class: :read, positional: [], options: %{}}},
            {{@session, :rpc, 1}, %{class: :read, positional: [:keyword], options: %{json: :boolean}}},
            {{@ticket_usage, :rpc, 2}, %{class: :read, positional: [:string, :keyword], options: %{json: :boolean}}},
            {{@sweep, :rpc, 1}, %{class: &__MODULE__.sweep_scope/1, positional: [:keyword], options: %{argv: :literal_list, json: :boolean}}},
            {{@pr_merge, :print_watcher_state, 0}, %{class: :deny, positional: [], options: %{}}},
            {{@pr_merge, :publish, 1}, %{class: :deny, positional: [:string], options: %{}}}
          ]
  @table Map.new(@rows)
  @spec fetch([atom()], atom(), non_neg_integer()) :: {:ok, map()} | :error
  def fetch(segments, function, arity), do: Map.fetch(@table, {segments, function, arity})

  @spec entries() :: map()
  def entries, do: @table

  @spec facade_functions() :: [{atom(), non_neg_integer()}]
  def facade_functions, do: Facade.functions()

  @spec watch_scope(list()) :: :read | :write
  def watch_scope(args), do: if(option(args, :mode) == :full, do: :read, else: :write)

  @spec wait_scope(list()) :: :write
  def wait_scope(_args), do: :write

  @spec estimate_scope(list()) :: :read | :write
  def estimate_scope(args), do: if(option(args, :hours) || option(args, :clear, false), do: :write, else: :read)

  @spec alerts_scope(list()) :: :read | :write
  def alerts_scope(args), do: if(Enum.any?(option(args, :argv, []), &(&1 in ["ack", :ack])), do: :write, else: :read)

  @spec sweep_scope(list()) :: :read | :write
  def sweep_scope(args), do: if(Enum.any?(option(args, :argv, []), &(&1 in ["apply", :apply])), do: :write, else: :read)

  @spec show_scope(list()) :: :read | :write
  def show_scope(args), do: if(option(args, :verb) in [:show, :list] or first_argv(args) in [:show, :list, "show", "list"], do: :read, else: :write)

  @spec experiment_scope(list()) :: :read | :write
  def experiment_scope(args), do: if(option(args, :verb) in [:show, :list, :status] or first_argv(args) in [:show, :list, :status, "show", "list", "status"], do: :read, else: :write)
  defp first_argv(args), do: args |> List.wrap() |> Enum.find_value([], fn item -> if is_list(item) and Keyword.keyword?(item), do: Keyword.get(item, :argv), else: nil end) |> List.first()
  defp option(args, key, default \\ nil), do: Enum.find_value(List.wrap(args), default, fn item -> if is_list(item) and Keyword.keyword?(item), do: Keyword.get(item, key), else: nil end)
end
