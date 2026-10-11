defmodule Aiur.PrMerge.Record do
  @moduledoc false
  alias Aiur.ControlCLI.Protocol
  alias Aiur.Events.Publisher
  alias Aiur.JSONSafe
  @spec append(map(), String.t()) :: :ok | {:error, term()}
  def append(record, root) do
    with :ok <- File.mkdir_p(root), do: File.write(Path.join(root, "merges.ndjson"), Jason.encode!(record) <> "\n", [:append, :sync])
  end

  @spec notify(map()) :: :ok | {:error, term()}
  def notify(record) do
    case System.get_env("AIUR_PR_MERGE_ENGINE") do
      nil -> {:error, :no_launcher}
      engine -> notify(engine, record)
    end
  end

  defp notify(engine, record) do
    encoded = record |> Jason.encode!() |> Base.encode64()

    case System.cmd("bash", [engine, "__pr-merge-record", encoded], stderr_to_stdout: true, env: [{"GH_TOKEN", nil}, {"GITHUB_TOKEN", nil}]) do
      {_output, 0} -> :ok
      {_output, _status} -> {:error, :daemon_unavailable}
    end
  end

  @spec watcher_state() :: map()
  def watcher_state do
    case System.get_env("AIUR_PR_MERGE_ENGINE") do
      nil ->
        %{}

      engine ->
        engine |> state_request() |> decode_state()
    end
  end

  defp state_request(engine), do: System.cmd("bash", [engine, "__pr-merge-state"], stderr_to_stdout: true, env: [{"GH_TOKEN", nil}, {"GITHUB_TOKEN", nil}])

  defp decode_state({json, 0}) do
    case Jason.decode(String.trim(json)) do
      {:ok, state} when is_map(state) -> state
      _ -> %{}
    end
  end

  defp decode_state(_response), do: %{}

  @spec print_watcher_state() :: :ok
  def print_watcher_state do
    module = Module.concat([Aiur, MainWatch])
    state = if Code.ensure_loaded?(module) and function_exported?(module, :state, 0), do: module.state(), else: %{}
    IO.puts(Jason.encode!(JSONSafe.normalize(state)))
    Protocol.exit_marker(0)
  end

  @spec publish(String.t()) :: :ok
  def publish(encoded) do
    with {:ok, json} <- Base.decode64(encoded),
         {:ok, record} when is_map(record) <- Jason.decode(json),
         {:ok, _id, _subscribers} <- Publisher.publish("system.pr.merged", record, source: :pr_merge_cli) do
      Protocol.exit_marker(0)
    else
      _ -> Protocol.exit_marker(1)
    end
  end
end
