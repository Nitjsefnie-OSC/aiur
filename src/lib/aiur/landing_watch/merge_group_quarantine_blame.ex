defmodule Aiur.LandingWatch.MergeGroupQuarantineBlame do
  @moduledoc false

  alias Aiur.LandingWatch.{MergeFailureClassifier, MergeFailureOptions, MergeGroupFailureEvidence, QuarantineEvidence}

  @spec put_recent_main_paths(keyword(), String.t(), keyword(), [map()]) :: keyword()
  def put_recent_main_paths(opts, _base, _original_opts, []),
    do: Keyword.put(opts, :recent_main_failure_paths, [])

  def put_recent_main_paths(opts, base, original_opts, _runs) do
    case MergeGroupFailureEvidence.recent_main_paths(base, original_opts) do
      {:ok, paths} -> Keyword.put(opts, :recent_main_failure_paths, paths)
      {:error, _reason} -> opts
    end
  end

  @spec pr_caused_failure?(map(), [integer()], [map()], keyword()) :: {:ok, boolean()} | {:error, term()}
  def pr_caused_failure?(run, prs, jobs, opts) do
    options = MergeFailureOptions.build(run, prs, jobs, opts, &MergeGroupFailureEvidence.job_log/2)

    case MergeFailureClassifier.classify(run, jobs, [], options) do
      {:ok, {:pr_caused, %{log: log}}} -> {:ok, blamed_test_path?(log, prs, options)}
      {:ok, _} -> {:ok, false}
      {:error, _} = error -> error
    end
  end

  defp blamed_test_path?(log, prs, opts) do
    Enum.any?(MergeGroupFailureEvidence.test_paths(log), fn path ->
      Enum.any?(prs, &path_touched_by_pr?(path, &1, opts))
    end)
  end

  defp path_touched_by_pr?(path, pr, opts) do
    case get_in(opts, [:changed_paths_by_pr, pr]) do
      paths when is_list(paths) -> QuarantineEvidence.touched?(path, paths)
      _ -> false
    end
  end
end
