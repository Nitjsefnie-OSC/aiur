defmodule Aiur.Experiments.Analyst do
  @moduledoc false
  use GenServer
  require Logger
  alias Aiur.Experiments
  alias Aiur.Experiments.{AnalysisDispatch, AnalysisRequests, AnalystBrief}
  alias Aiur.Tracker

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))

  @spec analyze(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze(id, opts \\ []) do
    GenServer.call(Keyword.get(opts, :server, __MODULE__), {:analyze, id, opts}, 180_000)
  catch
    :exit, {:noproc, _call} -> {:error, :analyst_unavailable}
    :exit, {:timeout, _call} -> {:error, :outcome_unknown}
  end

  @impl true
  def init(opts) do
    deps = %{
      create: Keyword.get(opts, :create, &Tracker.create_issue/1),
      find: Keyword.get(opts, :find, &Tracker.find_issue/1),
      labels: Keyword.get(opts, :labels, &Tracker.ensure_labels/1),
      promote: Keyword.get(opts, :promote, &promote/1),
      clock: Keyword.get(opts, :clock, fn -> System.system_time(:millisecond) end),
      alert: Keyword.get(opts, :alert, &alert/1)
    }

    state = %{deps: deps, interval: Keyword.get(opts, :interval_ms, 60_000)}
    unless opts[:start_paused?], do: send(self(), :retry)
    {:ok, state}
  end

  @impl true
  def handle_call({:analyze, id, opts}, _from, state), do: {:reply, run(id, opts, state.deps), state}

  @impl true
  def handle_info(:retry, state) do
    retry_open(state.deps)
    Process.send_after(self(), :retry, state.interval)
    {:noreply, state}
  end

  defp run(id, opts, deps) do
    with :ok <- Experiments.reconcile_analysis_requests(id),
         {:ok, mode} <- mode(id, opts),
         {:ok, request} <- Experiments.request_analysis(id, mode, Keyword.put_new(opts, :requested_by, if(opts[:local], do: "local", else: "operator"))),
         {:ok, attrs} <- AnalystBrief.build(id, request),
         {:ok, request} <- dispatch(request, attrs, opts, deps) do
      {:ok, %{"request" => request, "brief" => attrs.body, "ticket" => request["ticket"]}}
    end
  end

  defp mode(id, opts) do
    case opts[:mode] do
      nil -> AnalysisRequests.default_mode(id)
      mode when mode in ~w(spec report) -> {:ok, mode}
      _invalid -> {:error, :invalid_analysis_mode}
    end
  end

  defp dispatch(request, attrs, opts, deps), do: if(opts[:local], do: {:ok, request}, else: AnalysisDispatch.ticket(request, attrs, deps))

  defp retry_open(deps) do
    with {:ok, rows} <- Experiments.list(), do: Enum.each(rows, &retry_experiment(&1.id, deps))
  end

  defp retry_experiment(id, deps) do
    with :ok <- Experiments.reconcile_analysis_requests(id), {:ok, requests} <- Experiments.analysis_requests(id), do: Enum.each(requests, &retry_one(&1, deps))
  end

  defp retry_one(request, deps) do
    if request["state"] == "open" and request["dispatch_requested"] and retry_due?(request, deps.clock.()) do
      with {:ok, attrs} <- AnalystBrief.build(request["experiment_id"], request), do: AnalysisDispatch.ticket(request, attrs, deps)
    end
  end

  defp retry_due?(%{"ticket" => ticket} = request, now) when not is_nil(ticket) do
    request["analysis_type"] == "confirmatory" and request["routing_promoted"] != true and (request["promotion_next_attempt_ms"] || 0) <= now
  end

  defp retry_due?(request, now), do: (request["next_attempt_ms"] || 0) <= now

  defp alert(request) do
    Aiur.Alerts.emit_system("system.experiments.analyst_failed",
      message: "Analysis ticket unavailable for #{request["experiment_id"]}; request #{request["request_id"]} remains open",
      needs_attention: true
    )
  end

  defp promote(number) do
    id = to_string(number)
    with :ok <- Tracker.add_label(id, "complexity:3"), do: Tracker.remove_label(id, "complexity:2")
  end
end
