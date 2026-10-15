defmodule Aiur.ExecutorSweep do
  @moduledoc "Periodic local-state checks that keep Executor actions visible."
  use GenServer

  alias Aiur.ExecutorSweep.{Checks, SnapshotCache}
  alias Aiur.ExecutorSweep.Wake

  @interval_ms 5 * 60 * 1_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))

  @spec findings(keyword()) :: [map()]
  def findings(opts \\ []) do
    snapshot = Keyword.get_lazy(opts, :snapshot, &SnapshotCache.read/0)
    now = Keyword.get(opts, :now, DateTime.utc_now())
    threshold = Keyword.get(opts, :unreviewed_pr_minutes, configured_threshold())
    Checks.all(snapshot, now, unreviewed_pr_minutes: threshold)
  end

  @spec run(keyword()) :: :ok
  def run(opts \\ []) do
    findings = findings(opts)

    if Keyword.get(opts, :json, false) do
      result = %{findings: findings}
      result = if Keyword.get(opts, :apply, false), do: Map.put(result, :applied, []), else: result
      IO.puts(Jason.encode!(result))
    else
      if findings == [], do: IO.puts("Executor sweep: no findings")
      Enum.each(findings, &IO.puts("P#{&1.priority} #{&1.message} Action: #{&1.action}"))
      if Keyword.get(opts, :apply, false), do: IO.puts("No safe reversible actions are available to apply.")
    end

    :ok
  end

  @impl true
  def init(opts) do
    send(self(), :sweep)

    {:ok,
     %{seen: MapSet.new(), sweep_fun: Keyword.get(opts, :sweep_fun, &findings/0), publish_fun: Keyword.get(opts, :publish_fun, &publish/1), interval_ms: Keyword.get(opts, :interval_ms, @interval_ms)}}
  end

  @impl true
  def handle_info(:sweep, state) do
    findings = state.sweep_fun.()
    fingerprints = MapSet.new(findings, &fingerprint/1)
    new_findings = Enum.reject(findings, &(fingerprint(&1) in state.seen))
    Enum.each(new_findings, state.publish_fun)
    Process.send_after(self(), :sweep, state.interval_ms)
    {:noreply, %{state | seen: fingerprints}}
  end

  defp publish(finding), do: Wake.publish(finding)

  defp fingerprint(finding) do
    finding
    |> Map.take([:kind, :ticket, :issue_number, :pull_request, :head_sha, :decision, :merge_group, :queue_set, :service, :failure_class, :failed_checks])
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp configured_threshold do
    case Aiur.Config.settings() do
      {:ok, settings} -> settings.executor.sweep.unreviewed_pr_minutes
      _ -> 10
    end
  end
end
