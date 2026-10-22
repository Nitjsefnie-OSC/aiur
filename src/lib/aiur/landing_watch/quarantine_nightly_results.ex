defmodule Aiur.LandingWatch.QuarantineNightlyResults do
  @moduledoc false

  alias Aiur.Config.TrackerSettings
  alias Aiur.GitHub.CIRecovery

  @spec fetch(keyword()) :: {:ok, [atom()]} | {:error, term()}
  def fetch(opts) do
    case Keyword.get(opts, :nightly_quarantine_results_fun) do
      fun when is_function(fun, 1) -> fun.(opts)
      _ -> fetch_runs(opts)
    end
  end

  defp fetch_runs(opts) do
    case CIRecovery.read("/actions/runs?event=schedule&status=completed&per_page=20", opts) do
      {:ok, %{"workflow_runs" => runs}} when is_list(runs) ->
        runs
        |> Enum.filter(&(&1["name"] == "ci" and &1["head_branch"] == TrackerSettings.base_branch(opts) and is_integer(&1["id"])))
        |> Enum.reduce_while({:ok, []}, &append_result(&1, &2, opts))

      {:error, _} = error ->
        error

      _ ->
        {:error, :invalid_quarantine_nightly_runs}
    end
  end

  defp append_result(run, {:ok, acc}, opts) do
    case CIRecovery.jobs(run["id"], opts) do
      {:ok, jobs} -> {:cont, {:ok, acc ++ [Enum.find_value(jobs, :unknown, &job_status/1)]}}
      {:error, _} = error -> {:halt, error}
    end
  end

  defp job_status(%{"name" => "quarantined tests (non-blocking)"} = job) do
    failed_step? =
      Enum.any?(job["steps"] || [], fn step ->
        step["name"] == "Run quarantined tests" and
          (step["outcome"] == "failure" or step["conclusion"] == "failure")
      end)

    cond do
      failed_step? -> :failure
      job["conclusion"] == "success" -> :success
      job["conclusion"] in ["failure", "timed_out", "cancelled"] -> :failure
      true -> :unknown
    end
  end

  defp job_status(_job), do: nil
end
