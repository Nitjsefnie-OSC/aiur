defmodule Aiur.Orchestrator.OptimisticLedger do
  @moduledoc "Durable optimistic dispatch attempts; writes are serialized, reads use ETS."
  use GenServer
  require Logger
  alias Aiur.{Alerts, JsonStore}
  alias Aiur.Config.Paths
  alias Aiur.Orchestrator.DispatchPolicy

  @table :aiur_optimistic_starts
  @retention_ms 14 * 86_400_000
  @counters ~w(pushes_absorbed integrations_clean integrations_conflict non_ff_pushes parks resumes_after_park)

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))

  @spec record_start(String.t(), map()) :: :ok | {:error, atom()}
  def record_start(ticket, attrs), do: call({:start, ticket, attrs})

  @spec update_blocker(String.t(), String.t(), map()) :: :ok | {:error, atom()}
  def update_blocker(ticket, blocker, attrs), do: call({:update, ticket, {:blocker, blocker, attrs}})

  @spec bump(String.t(), atom() | String.t(), non_neg_integer()) :: :ok | {:error, atom()}
  def bump(ticket, counter, amount), do: call({:update, ticket, {:bump, to_string(counter), amount}})

  @spec set_status(String.t(), atom() | String.t(), integer()) :: :ok | {:error, atom()}
  def set_status(ticket, status, _at_ms), do: call({:update, ticket, {:status, to_string(status)}})

  @spec close(String.t(), atom() | String.t(), integer()) :: :ok | {:error, atom()}
  def close(ticket, outcome, at_ms) do
    call({:update, ticket, {:close, to_string(outcome), at_ms}})
  end

  @spec close_observed(Aiur.Issue.t()) :: :ok | {:error, atom()}
  def close_observed(issue) do
    if DispatchPolicy.terminal_issue_state?(issue.state, DispatchPolicy.terminal_state_set()) or String.downcase(to_string(issue.state)) == "not_planned",
      do: close(issue.identifier, :discarded, System.system_time(:millisecond)),
      else: :ok
  end

  @spec get(String.t()) :: map() | nil
  def get(ticket), do: records() |> Enum.filter(&(&1["ticket"] == ticket)) |> Enum.max_by(& &1["started_at_ms"], fn -> nil end)

  @spec open_records() :: [map()]
  def open_records, do: Enum.reject(records(), &(&1["status"] == "closed"))

  @spec by_blocker(String.t()) :: [map()]
  def by_blocker(id), do: Enum.filter(open_records(), fn row -> Enum.any?(row["blockers"], &(&1["id"] == id)) end)

  defp records do
    case :ets.lookup(@table, :records) do
      [{:records, rows}] -> rows
      [] -> []
    end
  rescue
    ArgumentError -> []
  end

  defp call(message) do
    GenServer.call(__MODULE__, message)
  catch
    :exit, reason ->
      Logger.warning("Optimistic ledger unavailable: #{inspect(reason)}")
      {:error, :ledger_unavailable}
  end

  @impl true
  def init(opts) do
    :ets.new(@table, [:named_table, :protected, read_concurrency: true])
    state = %{path: nil, records: %{}, writable?: true, alert: Keyword.get(opts, :alert, &Alerts.emit_system/2)}

    case path(opts) do
      {:ok, path} -> load(%{state | path: path}, opts)
      {:error, reason} -> {:ok, unavailable(state, reason)}
    end
  end

  defp load(state, opts) do
    with {:ok, document} <- JsonStore.read(state.path, %{"v" => 1, "records" => %{}}),
         {:ok, rows, writable?} <- decode(document) do
      state = %{state | records: rows, writable?: writable?}
      now = Keyword.get(opts, :now_ms, System.system_time(:millisecond))
      kept = if writable?, do: Map.reject(rows, fn {_id, row} -> row["v"] == 1 and row["status"] == "closed" and row["closed_at_ms"] < now - @retention_ms end), else: rows
      state = if writable? and kept != rows, do: persist(state, kept), else: state
      publish(state.records)
      {:ok, state}
    else
      {:error, reason} -> {:ok, unavailable(state, reason)}
    end
  end

  @impl true
  def handle_call(_message, _from, %{writable?: false} = state), do: {:reply, {:error, :ledger_unavailable}, state}

  def handle_call({:start, ticket, attrs}, _from, state) do
    record = %{
      "v" => 1,
      "ticket" => ticket,
      "attempt_id" => attrs.attempt_id,
      "start_trigger" => to_string(attrs.start_trigger),
      "started_at_ms" => attrs.started_at_ms,
      "blockers" => attrs.blockers,
      "status" => "running",
      "outcome" => nil,
      "closed_at_ms" => nil,
      "counters" => Map.new(@counters, &{&1, 0})
    }

    if valid_record?(attrs.attempt_id, record), do: write_reply(state, Map.put_new(state.records, attrs.attempt_id, record)), else: {:reply, {:error, :invalid_record}, state}
  end

  def handle_call({:update, ticket, operation}, _from, state) do
    current = state.records |> Map.values() |> Enum.filter(&(&1["v"] == 1 and &1["ticket"] == ticket and &1["status"] != "closed")) |> Enum.max_by(& &1["started_at_ms"], fn -> nil end)

    rows =
      Map.new(state.records, fn {id, row} ->
        applies? = match?({:close, _, _}, operation) or (not is_nil(current) and current["attempt_id"] == id)
        {id, if(applies? and row["v"] == 1 and row["ticket"] == ticket and (row["status"] != "closed" or merged_correction?(row, operation)), do: update(row, operation), else: row)}
      end)

    write_reply(state, rows)
  end

  defp merged_correction?(%{"outcome" => "discarded"}, {:close, "merged", _at}), do: true
  defp merged_correction?(_row, _operation), do: false

  defp update(row, {:blocker, id, attrs}) do
    attrs = Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
    Map.update!(row, "blockers", &Enum.map(&1, fn blocker -> if blocker["id"] == id, do: Map.merge(blocker, Map.drop(attrs, ["id", "pr_head_sha_at_start"])), else: blocker end))
  end

  defp update(row, {:bump, counter, amount}) when counter in @counters and is_integer(amount) and amount >= 0,
    do: update_in(row, ["counters", counter], &(&1 + amount))

  defp update(row, {:status, status}) when status in ["running", "parked"], do: Map.put(row, "status", status)

  defp update(row, {:close, outcome, at}) when outcome in ["merged", "merged_after_redo", "discarded"] and is_integer(at) do
    outcome = if outcome == "merged" and row["counters"]["parks"] > 0, do: "merged_after_redo", else: outcome
    Map.merge(row, %{"status" => "closed", "outcome" => outcome, "closed_at_ms" => at})
  end

  defp write_reply(state, rows) do
    next = if rows == state.records, do: state, else: persist(state, rows)
    {:reply, if(next.writable?, do: :ok, else: {:error, :ledger_unavailable}), next}
  end

  defp persist(state, rows) do
    JsonStore.write!(state.path, %{"v" => 1, "records" => rows})
    publish(rows)
    %{state | records: rows}
  rescue
    error -> unavailable(state, error)
  end

  defp publish(rows) do
    visible = for {_id, %{"v" => 1} = row} <- rows, do: row
    :ets.insert(@table, {:records, visible})
  end

  defp unavailable(state, reason) do
    Logger.warning("Optimistic ledger unavailable: #{inspect(reason)}")
    latch = {__MODULE__, :alerted, Process.whereis(Aiur.Supervisor), state.path}

    unless :persistent_term.get(latch, false) do
      :persistent_term.put(latch, true)
      state.alert.("system.optimistic.ledger_unavailable", message: "Optimistic starts cannot be persisted", reason: inspect(reason), needs_attention: true)
    end

    %{state | writable?: false}
  end

  defp path(opts) do
    case Keyword.fetch(opts, :path) do
      {:ok, path} -> {:ok, path}
      :error -> with {:ok, root} <- Paths.decision_state_dir(), do: {:ok, Path.join(root, "optimistic-starts.json")}
    end
  end

  defp decode(%{"v" => 1, "records" => rows}) when is_map(rows) do
    if Enum.all?(rows, fn {id, row} -> valid_record?(id, row) end), do: {:ok, rows, true}, else: {:error, :invalid_records}
  end

  defp decode(%{"v" => version, "records" => rows}) when is_integer(version) and version > 1 and is_map(rows), do: {:ok, rows, false}
  defp decode(_), do: {:error, :invalid_store}

  defp valid_record?(id, %{"v" => 1} = row) do
    row["attempt_id"] == id and is_binary(row["ticket"]) and is_integer(row["started_at_ms"]) and
      is_list(row["blockers"]) and Enum.all?(row["blockers"], &(is_map(&1) and is_binary(&1["id"]))) and
      valid_counters?(row["counters"]) and
      row["status"] in ["running", "parked", "closed"] and (row["status"] != "closed" or is_integer(row["closed_at_ms"]))
  end

  defp valid_record?(_id, %{"v" => v}) when is_integer(v) and v > 1, do: true
  defp valid_record?(_id, _row), do: false

  defp valid_counters?(counters) when is_map(counters), do: Enum.all?(@counters, &(is_integer(counters[&1]) and counters[&1] >= 0))
  defp valid_counters?(_), do: false
end
