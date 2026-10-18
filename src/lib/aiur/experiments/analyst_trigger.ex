defmodule Aiur.Experiments.AnalystTrigger do
  @moduledoc false
  use GenServer
  alias Aiur.Events.Exchange
  alias Aiur.Experiments
  alias Aiur.Experiments.{Reader, ReportRecords, SampleStatus}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))

  @impl true
  def init(opts) do
    :ok = Exchange.subscribe("system.experiment.*.*")
    :ok = Exchange.subscribe("experiment.*")
    state = %{enabled: Keyword.get(opts, :enabled, &enabled?/0), request: Keyword.get(opts, :request, &Experiments.analyze/2), interval: Keyword.get(opts, :interval_ms, 60_000)}
    unless opts[:start_paused?], do: send(self(), :reconcile)
    {:ok, state}
  end

  @impl true
  def handle_info({:event, event}, state) do
    if state.enabled.(), do: consume(event, state.request)
    {:noreply, state}
  end

  def handle_info(:reconcile, state) do
    if state.enabled.(), do: reconcile(state.request)
    Process.send_after(self(), :reconcile, state.interval)
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp consume(event, request) do
    event = Map.new(event, fn {key, value} -> {to_string(key), value} end)
    id = event["experiment_id"]
    kind = event["kind"] || event["line_source"]

    route(List.last(String.split(event["topic"] || "", ".")), id, kind, request)
  end

  defp route(event, id, "feature", request) when event in ~w(created preregister), do: request.(id, mode: "spec", trigger: "created", requested_by: "daemon")
  defp route(event, id, _kind, request) when event in ~w(sample_guard_met report_due), do: request.(id, report_opts("sample_guard_met", "interim"))
  defp route("planned_n_met", id, _kind, request), do: request.(id, report_opts("planned_n_met", "confirmatory"))
  defp route("cancelled", id, _kind, _request), do: cancel(id)
  defp route(_event, _id, _kind, _request), do: :ok

  defp reconcile(request) do
    with {:ok, rows} <- Experiments.list(), do: Enum.each(rows, &reconcile_one(&1.id, request))
  end

  defp reconcile_one(id, request) do
    with {:ok, spec, false} <- Reader.spec(id), do: reconcile_spec(spec, request)
  end

  defp reconcile_spec(%{"id" => id, "status" => status}, _request) when status in ~w(cancelled abandoned), do: cancel(id)

  defp reconcile_spec(%{"id" => id, "status" => status} = spec, request) when status in ~w(active report_due) do
    if get_in(spec, ["design", "change", "evidence", "source"]) == "feature", do: request.(id, mode: "spec", trigger: "created", requested_by: "daemon")
    if status == "report_due", do: request.(id, report_opts("sample_guard_met", "interim"))
    request_planned(id, spec, request)
  end

  defp reconcile_spec(_spec, _request), do: :ok

  defp request_planned(id, spec, request) do
    with {:ok, records} <- ReportRecords.read(id),
         %{"planned_n_per_cohort" => n} <- records["preregistration"],
         {:ok, [_ | _] = samples} <- SampleStatus.read(spec) do
      met? = Enum.all?(samples, fn row -> map_size(row.counts) == 2 and Enum.all?(Map.values(row.counts), &(is_integer(&1) and &1 >= n)) end)
      if met?, do: request.(id, report_opts("planned_n_met", "confirmatory"))
    end
  end

  defp cancel(id) do
    with {:ok, requests} <- Experiments.analysis_requests(id) do
      requests |> Enum.filter(&(&1["state"] == "open")) |> Enum.each(&Experiments.cancel_analysis_request(id, &1["request_id"], "experiment cancelled"))
    end
  end

  defp report_opts(trigger, type), do: [mode: "report", trigger: trigger, reason: trigger, analysis_type: type, requested_by: "daemon"]

  defp enabled? do
    Aiur.Config.telemetry_enabled?() and
      case Aiur.Config.settings() do
        {:ok, %{experiments: %{analyst: %{auto_request: enabled}}}} -> enabled
        _unconfigured -> true
      end
  end
end
