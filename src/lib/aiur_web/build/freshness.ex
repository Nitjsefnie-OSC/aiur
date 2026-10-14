defmodule AiurWeb.Build.Freshness do
  @moduledoc """
  Maps store freshness to payload v1 without inventing observation times.

  Current snapshots are live; unavailable orchestrators are offline; other
  stale snapshots are stale. Unpublished or invalid snapshots are unknown.
  The heartbeat is the data's timestamp; observed_at is the server read time.

  Usable healthy providers are ok; partial healthy providers are incomplete.
  Stale providers stay stale, unavailable/invalid providers are unavailable,
  and explicitly disabled sources remain disabled. Unknown input is unavailable.
  """
  alias Aiur.BuildOrder.ProviderHealth
  alias Aiur.{Orchestrator, PollCadence}
  alias AiurWeb.Endpoint

  @spec daemon(term(), integer()) :: map()
  def daemon({status, _, md}, now_ms) when status in [:current, :stale] and is_map(md) do
    heartbeat = ms(Map.get(md, :observed_at))
    state = if heartbeat, do: daemon_state(status, Map.get(md, :reason)), else: "unknown"
    %{state: state, heartbeat_at: heartbeat, observed_at: now_ms}
  end

  def daemon(:orchestrator_unavailable, now_ms), do: %{state: "offline", heartbeat_at: nil, observed_at: now_ms}
  def daemon(_, now_ms), do: %{state: "unknown", heartbeat_at: nil, observed_at: now_ms}

  @spec read_daemon(keyword()) :: map()
  def read_daemon(opts \\ []) do
    orchestrator = Keyword.get(opts, :orchestrator, Endpoint.config(:orchestrator) || Orchestrator)
    timeout = Keyword.get_lazy(opts, :timeout, fn -> PollCadence.snapshot_tolerance_ms(Endpoint.config(:snapshot_timeout_ms) || 15_000, class: :dispatch) end)
    daemon(Orchestrator.dashboard_snapshot(orchestrator, timeout), System.os_time(:millisecond))
  end

  @spec push_daemon?(term(), map()) :: boolean()
  def push_daemon?(%{state: state} = old, %{state: state} = new),
    do: state != "live" and Map.get(old, :heartbeat_at) != Map.get(new, :heartbeat_at)

  def push_daemon?(_, _), do: true

  @spec source(term()) :: map()
  def source(%ProviderHealth{state: :healthy} = health) do
    if ProviderHealth.usable?(health),
      do: entry("ok", health.observed_at, nil),
      else: entry("incomplete", health.observed_at, :incomplete)
  end

  def source(%ProviderHealth{state: :stale} = health), do: entry("stale", health.observed_at, health.failure)

  def source(%ProviderHealth{state: state} = health) when state in [:unavailable, :structurally_invalid],
    do: entry("unavailable", health.observed_at, health.failure || state)

  def source({:current, _, md}) when is_map(md), do: entry("ok", Map.get(md, :observed_at), nil)
  def source({:stale, _, md}) when is_map(md), do: entry("stale", Map.get(md, :observed_at), Map.get(md, :reason))
  def source(reason) when reason in [:snapshot_unpublished, :orchestrator_unavailable], do: entry("unavailable", nil, reason)
  def source({:disabled, reason}), do: entry("disabled", nil, reason)
  def source(_), do: entry("unavailable", nil, :unknown)

  defp daemon_state(:current, _), do: "live"
  defp daemon_state(:stale, :orchestrator_unavailable), do: "offline"
  defp daemon_state(:stale, _), do: "stale"
  defp entry(state, time, reason), do: %{state: state, observed_at: ms(time), reason: if(is_nil(reason), do: nil, else: to_string(reason))}
  defp ms(%DateTime{} = time), do: DateTime.to_unix(time, :millisecond)

  defp ms(time) when is_binary(time) do
    case DateTime.from_iso8601(time) do
      {:ok, time, _} -> ms(time)
      _ -> nil
    end
  end

  defp ms(_), do: nil
end
