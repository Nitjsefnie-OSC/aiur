defmodule AiurWeb.Build.IndexReader do
  @moduledoc false
  alias Aiur.BuildOrder.{Index, NotQueued}
  alias Aiur.BuildOrder.History.Row
  alias Aiur.BuildOrder.Index.Rows
  alias AiurWeb.Build.{NowRows, PlannedRows}
  alias AiurWeb.OperatorControlCenter.PayloadLoader

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
        loader = Keyword.get(opts, :payload_loader, PayloadLoader)
        NowRows.build(loader.load(:cached).units, repository: repo)
      end)

    parts = Map.put(parts, :now, now)
    active = MapSet.new(producer_rows(now), & &1.num)
    history = %{rows: Map.merge(open_history(parts), Rows.history(parts))}

    prefix =
      case parts[:settings] do
        {:ok, settings} -> settings.tracker.github.label_prefix
        _ -> "agent"
      end

    planned =
      read_part(:planned, dirty, parts, fn ->
        PlannedRows.build(parts[:queue], {:ok, history}, active: active, todo_label: prefix <> ":todo")
      end)

    nq = read_part(:not_queued, dirty, parts, fn -> NotQueued.build(parts[:open], parts[:queue], active: active, label_prefix: prefix) end)
    parts |> Map.put(:planned, planned) |> Map.put(:not_queued, nq)
  end

  defp read_part(key, dirty, previous, fun) do
    if dirty == :all or MapSet.member?(dirty, key), do: Index.safe_read(key, fun), else: previous[key]
  end

  defp producer_rows(%{rows: rows}) when is_map(rows), do: Map.values(rows)
  defp producer_rows(_), do: []

  defp open_history(%{open: %{status: status, tickets: tickets}}) when status in [:available, :stale] do
    Map.new(tickets, fn ticket ->
      {number, ""} = Integer.parse(ticket.identifier)
      {number, %Row{number: number, title: ticket.title, labels: ticket.labels, labels_complete: true, created_at: ticket.created_at, lifecycle: %Aiur.BuildOrder.Lifecycle{state: :open}}}
    end)
  end

  defp open_history(_), do: %{}
end
