defmodule Aiur.Experiments.TelemetryHistory do
  @moduledoc "Cached, bounded lifecycle and fleet history shared by experiment evaluations."
  alias Aiur.Experiments.TelemetryReader
  alias Aiur.RunTelemetry.{RetainedCache, Summaries}

  @doc "Retained file metadata invalidates the projection; live telemetry is never cached."
  @spec read(String.t() | nil, map()) :: {:ok, map()} | {:error, term()}
  def read(current, ctx \\ %{}) do
    path = Map.get(ctx, :summary_path, &Summaries.run_summary_path/1)
    sources = Map.get(ctx, :summary_boot_ids, &Summaries.summary_boot_ids/0).() |> Enum.reject(&(&1 == current)) |> Enum.map(&%{path: path.(&1), format: :summary})

    identity =
      Enum.map(sources, fn source ->
        case File.stat(source.path, time: :posix) do
          {:ok, stat} -> {source.path, stat.size, stat.mtime}
          {:error, reason} -> {source.path, reason}
        end
      end)

    opts = Map.get(ctx, :telemetry_reader_options, [])
    key = {identity, opts}
    # Keep historical first dispatch and prerequisite merges, without retaining full datasets.
    window = %{start: ~U[0000-01-01 00:00:00Z], end: ~U[9999-12-31 23:59:59Z]}
    RetainedCache.fetch(__MODULE__, key, fn -> TelemetryReader.read(window, sources, opts) end, max_value_bytes: 8 * 1024 * 1024)
  end
end
