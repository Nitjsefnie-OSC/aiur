defmodule Aiur.RunTelemetry.LedgerRetention do
  @moduledoc "Checkpoints the canonical telemetry stream before retention deletes lifecycle evidence."
  alias Aiur.RunTelemetry
  alias Aiur.RunTelemetry.{Retention, Summaries}

  @spec prune(Path.t(), keyword()) :: :ok | {:error, term()}
  def prune(path, opts) do
    # Only the daemon's canonical stream contributes to its ledger.
    if Path.expand(path) == Path.expand(RunTelemetry.telemetry_file()) and RunTelemetry.telemetry_enabled?() do
      materialize_opts = Keyword.merge([telemetry_file: path], Keyword.get(opts, :materialize_opts, []))

      case Summaries.materialize(materialize_opts) do
        {:ok, _output} -> Retention.prune(path, Keyword.delete(opts, :materialize_opts))
        {:error, reason} -> {:error, {:ledger_checkpoint_failed, reason}}
      end
    else
      Retention.prune(path, opts)
    end
  end
end
