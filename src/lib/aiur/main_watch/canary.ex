defmodule Aiur.MainWatch.Canary do
  @moduledoc "Pure stale-run canary decision; the server owns the once-per-window latch."

  @spec decide(integer(), [map()], non_neg_integer(), boolean(), integer()) :: :noop | {:rerun, integer()} | {:attention, atom()}
  def decide(last_completed_at, runs, minutes, actions_write, now_ms) do
    cond do
      minutes == 0 or now_ms - last_completed_at < minutes * 60_000 -> :noop
      Enum.any?(runs, &(&1.attempt > 1 and &1.status != "completed")) -> :noop
      not actions_write -> {:attention, :actions_write_unavailable}
      true -> cancelled_run(runs)
    end
  end

  defp cancelled_run(runs) do
    case Enum.find(runs, &(&1.status == "completed" and &1.conclusion == "cancelled")) do
      nil -> {:attention, :no_cancelled_run}
      run -> {:rerun, run.id}
    end
  end
end
