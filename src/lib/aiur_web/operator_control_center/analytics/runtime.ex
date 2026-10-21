defmodule AiurWeb.OperatorControlCenter.Analytics.Runtime do
  @moduledoc "Loads Analytics outside the HTTP request and LiveView event loop."

  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [start_async: 3]

  alias Aiur.PollCadence
  alias Aiur.RunTelemetry.RetainedCache
  alias AiurWeb.OperatorControlCenter.Analytics.Presenter
  alias AiurWeb.OperatorControlCenter.{AwaitingCommands, DashboardShell}

  @cache_table AiurWeb.OperatorControlCenter.Analytics.Runtime.Cache

  @load_timeout_ms 15_000
  @load_tick_ms 1_000

  @spec load(Phoenix.LiveView.Socket.t(), keyword(), (-> map())) :: Phoenix.LiveView.Socket.t()
  def load(socket, scope_opts, rtk_loader) do
    token = make_ref()
    started_at = System.monotonic_time(:millisecond)
    timeout_ms = Application.get_env(:aiur, :analytics_load_timeout_ms, @load_timeout_ms)
    Process.send_after(self(), {:analytics_load_tick, token}, @load_tick_ms)
    Process.send_after(self(), {:analytics_load_timeout, token}, timeout_ms)

    opts =
      [
        range: socket.assigns.range,
        session: if(socket.assigns.range == :full, do: :cross, else: :current),
        telemetry_file: Application.get_env(:aiur, :analytics_telemetry_file),
        orchestrator: AiurWeb.EndpointConfig.get(:orchestrator) || Aiur.Orchestrator,
        snapshot_timeout_ms: PollCadence.snapshot_tolerance_ms(AiurWeb.EndpointConfig.get(:snapshot_timeout_ms) || 15_000)
      ] ++ scope_opts

    {cached, cache_key} = cached_model(opts)

    socket =
      socket
      |> assign(
        model: cached,
        chart_model: cached,
        time_domain: nil,
        provider_spend: if(cached, do: %{state: :unavailable}, else: %{state: :loading}),
        selected: if(cached, do: MapSet.new(cached.actors, & &1.key), else: MapSet.new()),
        source: if(cached, do: source_info(cached), else: nil),
        unavailable: if(cached, do: nil, else: :loading),
        analytics_refreshing?: false,
        analytics_timed_out?: false,
        analytics_cache_key: cache_key,
        rtk: %{state: :absent, title: "Loading compression data", message: "Analytics loading is in progress."},
        now: DateTime.utc_now()
      )
      |> assign(analytics_load_token: token, analytics_load_started_at: started_at, analytics_load_elapsed_seconds: 0, analytics_load_timeout_seconds: timeout_ms / 1_000)

    socket = if cached, do: assign(socket, :analytics_refreshing?, true), else: socket
    start_async(socket, :analytics_model, fn -> {Presenter.load(opts), rtk_loader.()} end)
  end

  @spec handle_info(term(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:analytics_load_tick, token}, %{assigns: %{unavailable: :loading, analytics_load_token: token}} = socket) do
    elapsed = div(System.monotonic_time(:millisecond) - socket.assigns.analytics_load_started_at, 1_000)
    Process.send_after(self(), {:analytics_load_tick, token}, @load_tick_ms)
    {:noreply, assign(socket, :analytics_load_elapsed_seconds, elapsed)}
  end

  def handle_info({:analytics_cached_refresh, token, opts, rtk_loader}, %{assigns: %{analytics_load_token: token}} = socket) do
    Process.send_after(self(), {:analytics_refresh_started, token, opts, rtk_loader}, 10)
    {:noreply, assign(socket, :analytics_refreshing?, true)}
  end

  def handle_info({:analytics_refresh_started, token, opts, rtk_loader}, %{assigns: %{analytics_load_token: token}} = socket) do
    {:noreply, start_async(socket, :analytics_model, fn -> {Presenter.load(opts), rtk_loader.()} end)}
  end

  def handle_info({:analytics_load_timeout, token}, %{assigns: %{unavailable: :loading, analytics_load_token: token}} = socket) do
    {:noreply, socket |> Phoenix.LiveView.cancel_async(:analytics_model) |> assign(unavailable: :timeout, analytics_timed_out?: true)}
  end

  def handle_info({:analytics_load_timeout, token}, %{assigns: %{analytics_refreshing?: true, analytics_load_token: token}} = socket) do
    {:noreply, socket |> Phoenix.LiveView.cancel_async(:analytics_model) |> assign(:analytics_refreshing?, false) |> assign(:analytics_timed_out?, true)}
  end

  def handle_info({:analytics_load_tick, _token}, %{assigns: %{analytics_refreshing?: true}} = socket), do: {:noreply, socket}
  def handle_info({:decision_changed, _decision_id, _version}, socket), do: {:noreply, AwaitingCommands.refresh(socket)}
  def handle_info(:awaiting_commands_tick, socket), do: {:noreply, AwaitingCommands.tick(socket)}
  def handle_info(message, socket), do: DashboardShell.handle_info(message, socket)

  @doc false
  @spec cache_result(term(), {:ok, Presenter.model()} | {:unavailable, atom()}) :: :ok
  def cache_result(_key, {:unavailable, _reason}), do: :ok

  def cache_result(key, {:ok, model}), do: RetainedCache.put(@cache_table, key, model, max_entries: 8, max_value_bytes: 8 * 1024 * 1024)

  defp cached_model(opts) do
    key = cache_key(opts)
    {RetainedCache.lookup(@cache_table, key), key}
  end

  defp cache_key(opts) do
    {Keyword.get(opts, :session, :current), Keyword.get(opts, :build_order), Keyword.get(opts, :tickets), Keyword.get(opts, :cache_identity)}
  end

  defp source_info(model) do
    observed_at = parse_observed_at(model.source_observed_at)
    %{kind: :retained, boot_id: model.source_boot_id, observed_at: observed_at, age_ms: freshness_age(observed_at), freshness: if(observed_at, do: :stale, else: :unknown)}
  end

  defp freshness_age(nil), do: nil
  defp freshness_age(%DateTime{} = timestamp), do: max(DateTime.diff(DateTime.utc_now(), timestamp, :millisecond), 0)

  defp parse_observed_at(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, timestamp, _offset} -> timestamp
      _invalid -> nil
    end
  end

  defp parse_observed_at(_value), do: nil
end
