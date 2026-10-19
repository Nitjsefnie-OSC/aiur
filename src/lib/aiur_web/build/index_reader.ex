defmodule AiurWeb.Build.IndexReader do
  @moduledoc false
  alias Aiur.BuildOrder.Index
  alias AiurWeb.Build.{Freshness, NowRows, PlannedRows}

  @spec read(MapSet.t() | :all, map(), keyword()) :: map()
  def read(dirty, previous, opts) do
    core = Index.read_core_parts(dirty, opts)
    parts = Map.merge(previous, core)

    repo =
      case parts[:repository] do
        {:ok, repo} -> repo
        _ -> nil
      end

    now =
      read_part(:now, dirty, parts, fn ->
        snapshot_fun = Keyword.get(opts, :running_rows_fun, &Freshness.read_running_rows/1)

        case snapshot_fun.(opts) do
          {:ok, agents} when is_list(agents) ->
            rows = Enum.map(agents, &now_row/1) |> Enum.reject(&is_nil/1)
            NowRows.build(%{status: :ready, snapshot: %{rows: rows}}, repository: repo)

          {:error, :timeout} ->
            {:error, :running_snapshot_timeout}

          {:error, _unavailable} ->
            {:error, :running_snapshot_unavailable}
        end
      end)

    parts = Map.put(parts, :now, now)
    active = MapSet.new(producer_rows(now), & &1.num)
    context = Index.planning_context(parts, active)

    planned =
      read_part(:planned, dirty, parts, fn ->
        PlannedRows.build(parts[:queue], context.history_snapshot, active: active, todo_label: context.todo_label)
      end)

    nq = read_part(:not_queued, dirty, parts, fn -> context.not_queued end)
    parts |> Map.put(:planned, planned) |> Map.put(:not_queued, nq)
  end

  defp read_part(key, dirty, previous, fun) do
    if dirty == :all or MapSet.member?(dirty, key), do: Index.safe_read(key, fun), else: previous[key]
  end

  defp producer_rows(%{rows: rows}) when is_map(rows), do: Map.values(rows)
  defp producer_rows(_), do: []

  defp now_row(%{identifier: _identifier, state: :running} = summary), do: now_row(summary, :running)
  defp now_row(%{identifier: _identifier, work_state: :retrying} = summary), do: now_row(summary, :retrying)

  defp now_row(%{identifier: _identifier, state: :paused, session_id: session} = summary) when is_binary(session),
    do: now_row(summary, :running)

  defp now_row(_summary), do: nil

  defp now_row(summary, bucket) do
    identity = Map.get(summary, :tracker_identity)

    %{
      identity: identity,
      runtime: %{bucket: bucket, work_state: Map.get(summary, :work_state, :working)},
      reasons: %{waiting: nil, pause: Map.get(summary, :pause_reason)},
      timestamps: %{started_at: Map.get(summary, :started_at)},
      effort: nil,
      open_command_count: 0,
      progress: nil
    }
  end
end
