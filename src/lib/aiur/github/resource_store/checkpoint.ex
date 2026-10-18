defmodule Aiur.GitHub.ResourceStore.Checkpoint do
  @moduledoc false

  require Logger

  alias Aiur.Fs

  @revision_table __MODULE__.Revision
  @event [:aiur, :github, :resource_store, :checkpoint]

  @spec init() :: atom()
  def init do
    :ets.new(@revision_table, [:named_table, :public, :set, write_concurrency: true])
    :ets.insert(@revision_table, {:revision, 0})
  end

  @spec mark_dirty() :: pos_integer() | :ok
  def mark_dirty do
    :ets.update_counter(@revision_table, :revision, 1, {:revision, 0})
  rescue
    ArgumentError -> :ok
  end

  @spec run(map(), (:ets.table() -> {:ok, iodata()} | {:error, term()}), keyword()) ::
          {:ok, map()} | {{:error, term()}, map()}
  def run(%{path: nil} = state, _render, _opts), do: {:ok, state}

  def run(%{table: table, path: path} = state, render, opts) do
    revision = revision()

    if not Keyword.get(opts, :force, false) and revision == state.last_written_revision do
      :telemetry.execute(@event, %{entries: :ets.info(table, :size)}, %{result: :unchanged})
      {:ok, state}
    else
      write_checkpoint(state, revision, table, path, render)
    end
  end

  defp write_checkpoint(state, revision, table, path, render) do
    with {:ok, encoded} <- render.(table),
         digest = :erlang.md5(encoded),
         false <- digest == state.last_written,
         :ok <- write(path, encoded) do
      :telemetry.execute(@event, %{entries: :ets.info(table, :size)}, %{result: :written})
      {:ok, %{state | last_written: digest, last_written_revision: revision}}
    else
      true ->
        {:ok, %{state | last_written_revision: revision}}

      {:error, reason} = error ->
        Logger.warning("GitHub.ResourceStore checkpoint failed; reason=#{inspect(reason)}")
        {error, state}
    end
  end

  defp revision do
    case :ets.lookup(@revision_table, :revision) do
      [{:revision, revision}] -> revision
      _other -> 0
    end
  rescue
    ArgumentError -> 0
  end

  defp write(path, encoded) do
    with :ok <- File.mkdir_p(Path.dirname(path)) do
      Fs.atomic_write(path, encoded, fsync: true, mode: 0o600)
    end
  rescue
    error -> {:error, Exception.message(error)}
  end
end
