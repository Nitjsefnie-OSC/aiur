defmodule AiurWeb.OperatorControlCenter.Analytics.LiveConcurrency do
  @moduledoc false

  alias Aiur.Orchestrator

  @spec snapshot_opts(keyword()) :: keyword()
  def snapshot_opts(opts) do
    if Keyword.get(opts, :session, :all) == :current do
      orchestrator = Keyword.get(opts, :orchestrator, Orchestrator)
      timeout = Keyword.get(opts, :snapshot_timeout_ms, 15_000)
      snapshot_fun = Keyword.get(opts, :live_snapshot_fun, &Orchestrator.dashboard_snapshot/2)

      case snapshot_fun.(orchestrator, timeout) do
        {:current, %{running: running}, _freshness} when is_list(running) ->
          [live_concurrency: count(running)]

        {:stale, %{running: running}, freshness} when is_list(running) ->
          [live_concurrency: count(running), live_concurrency_staleness: {:stale, age_ms(freshness)}]

        {:stale, _snapshot, freshness} ->
          [live_concurrency_staleness: {:stale, age_ms(freshness)}]

        _other ->
          []
      end
    else
      []
    end
  rescue
    _error -> []
  catch
    _kind, _reason -> []
  end

  @spec count([map()]) :: non_neg_integer()
  def count(running) do
    Enum.count(running, fn
      %{work_state: state} when state in [:paused, :error, :completed, :deactivated] -> false
      %{work_state: state} when state in ["paused", "error", "completed", "deactivated"] -> false
      _row -> true
    end)
  end

  @doc false
  @spec label(map(), boolean()) :: String.t()
  def label(model, true) do
    kpis = Map.fetch!(model, :kpis)
    count = Map.get(model, :live_concurrency) || Map.fetch!(kpis, :conc_now)
    freshness = Map.get(model, :live_concurrency_staleness)
    "#{count} now#{freshness_label(freshness)}"
  end

  def label(model, false), do: "#{model.kpis.conc_now} at run end"

  defp freshness_label({:stale, age_ms}), do: " (sample #{age_label(age_ms)} old)"
  defp freshness_label(_freshness), do: ""

  defp age_label(age_ms) when age_ms <= 30_000, do: "just now"
  defp age_label(age_ms) when age_ms < 60_000, do: "#{div(age_ms, 1_000)}s"
  defp age_label(age_ms) when age_ms < 3_600_000, do: "#{div(age_ms, 60_000)}m"
  defp age_label(age_ms), do: "#{Float.round(age_ms / 3_600_000, 1)}h"

  defp age_ms(%{age_ms: age_ms}) when is_integer(age_ms) and age_ms >= 0, do: age_ms
  defp age_ms(_freshness), do: 0
end
