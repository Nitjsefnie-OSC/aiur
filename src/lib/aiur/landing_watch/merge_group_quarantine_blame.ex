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
    paths = MergeGroupFailureEvidence.test_paths(log)
    main_failures = Keyword.get(opts, :recent_main_failure_paths, [])

    Enum.any?(paths, fn path ->
      Enum.any?(prs, &path_touched_by_pr?(path, &1, opts)) or
        (path not in main_failures and single_test_area_change?(path, prs, opts))
    end)
  end

  defp single_test_area_change?(test_path, prs, opts) do
    Enum.count(prs, fn pr ->
      case get_in(opts, [:changed_paths_by_pr, pr]) do
        paths when is_list(paths) -> test_area_changed?(test_path, paths)
        _ -> false
      end
    end) == 1
  end

  defp test_area_changed?("src/test/" <> rest, changed_paths) do
    area = rest |> Path.dirname() |> then(&Path.join("src/lib", &1))
    Enum.any?(changed_paths, &(is_binary(&1) and String.starts_with?(&1, area <> "/")))
  end

  defp test_area_changed?(_test_path, _changed_paths), do: false

  defp path_touched_by_pr?(path, pr, opts) do
    case get_in(opts, [:changed_paths_by_pr, pr]) do
      paths when is_list(paths) -> QuarantineEvidence.touched?(path, paths)
      _ -> false
    end
  end
end
