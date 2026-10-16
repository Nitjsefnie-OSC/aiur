defmodule Aiur.LandingWatch.MergeGroupQuarantine do
  @moduledoc "Records repeated test failures from unrelated merge-group PRs."

  alias Aiur.GitHub.{CIRecovery, FailureEvidence, PullRequests}
  alias Aiur.LandingWatch.{FlakeRecorder, Journal, QuarantinePR}
  alias Aiur.TestQuarantine.Detector

  def process_completed(runs, base, opts) do
    runs
    |> Enum.filter(&(&1["conclusion"] == "failure" and is_integer(&1["id"])))
    |> Enum.reduce_while(:ok, fn run, :ok ->
      case process_run(run, base, opts) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp process_run(run, base, opts) do
    with prs when prs != [] <- run_prs(run, base),
         {:ok, jobs} <- Keyword.get(opts, :jobs_fun, &CIRecovery.jobs/2).(run["id"], opts),
         {:ok, failures} <- test_failures(jobs, opts) do
      Enum.reduce_while(failures, :ok, fn failure, :ok ->
        case maybe_quarantine(failure, run, prs, opts) do
          :ok -> {:cont, :ok}
          {:error, _} = error -> {:halt, error}
        end
      end)
    else
      [] -> :ok
      {:error, _} = error -> error
      _ -> :ok
    end
  end

  defp maybe_quarantine(%{path: path} = failure, run, prs, opts) when is_binary(path) do
    with {:ok, at_ms} <- run_time(run),
         :ok <- record_observations(failure, run, prs, path, at_ms, opts),
         {:ok, rows} <- Journal.failure_observations(opts),
         {:ok, candidate} <- repeated(rows, failure),
         :ok <- record_flake(candidate, failure, run, opts) do
      :ok
    end
  end

  defp maybe_quarantine(_failure, _run, _prs, _opts), do: :ok

  defp record_observations(failure, run, prs, path, at_ms, opts) do
    Enum.reduce_while(prs, :ok, fn pr, :ok ->
      case Keyword.get(opts, :changed_paths_fun, &PullRequests.fetch_pull_request_changed_paths/2).(pr, opts) do
        {:ok, paths} when is_list(paths) ->
          if path in paths do
            {:cont, :ok}
          else
            row = %{
              "identity" => "#{failure.module} :: #{failure.name}",
              "pr" => pr,
              "run_url" => run["html_url"],
              "at_ms" => at_ms,
              "path" => path
            }

            case Journal.record_failure_observation(row, opts) do
              :ok -> {:cont, :ok}
              {:error, _} = error -> {:halt, error}
            end
          end

        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end

  defp repeated(rows, failure) do
    identity = "#{failure.module} :: #{failure.name}"
    normalized = Enum.map(rows, &%{identity: &1["identity"], pr: &1["pr"], run_url: &1["run_url"], at_ms: &1["at_ms"], path: &1["path"]})

    case Detector.repeated(normalized, System.system_time(:millisecond), fn _pr -> {:ok, []} end) do
      {:ok, candidates} -> {:ok, Enum.find(candidates, &(&1.identity == identity))}
      {:error, _} = error -> error
    end
  end

  defp record_flake(nil, _failure, _run, _opts), do: :ok

  defp record_flake(candidate, failure, run, opts) do
    issue_recorded_fun = fn ticket -> open_quarantine(candidate, ticket, opts) end

    Keyword.get(opts, :flake_recorder, &FlakeRecorder.record/4).(
      failure,
      run,
      [],
      Keyword.put(opts, :issue_recorded_fun, issue_recorded_fun)
    )
  end

  defp open_quarantine(candidate, ticket, opts) do
    claim = "quarantine-pr :: " <> candidate.identity

    case Journal.claim_flake(claim, opts) do
      {:ok, :already_claimed} ->
        :ok

      {:ok, :new} ->
        result = Keyword.get(opts, :quarantine_pr_fun, &QuarantinePR.open/3).(candidate, ticket, opts)
        if match?({:error, _}, result), do: Journal.release_flake(claim, opts) |> release_result(result), else: :ok

      {:error, _} = error ->
        error
    end
  end

  defp release_result(:ok, result), do: result
  defp release_result({:error, reason}, _result), do: {:error, {:quarantine_pr_claim_release_failed, reason}}

  defp test_failures(jobs, opts) do
    jobs
    |> Enum.filter(&(&1["conclusion"] == "failure"))
    |> Enum.reduce_while({:ok, []}, fn job, {:ok, acc} ->
      case check_run_id(job) do
        nil ->
          {:cont, {:ok, acc}}

        id ->
          case Keyword.get(opts, :annotations_fun, &FailureEvidence.annotations/2).(id, opts) do
            {:ok, annotations} -> {:cont, {:ok, acc ++ annotation_failures(annotations, job["name"] || "unknown job")}}
            {:error, reason} -> {:halt, {:error, {:merge_group_annotations_unavailable, reason}}}
          end
      end
    end)
  end

  defp annotation_failures(annotations, job) do
    Enum.flat_map(annotations, fn
      %{"title" => "aiur-test-failure", "message" => message} = annotation when is_binary(message) ->
        case String.split(message, " :: ", parts: 3) do
          [class, module, name] when class in ["known-flake", "new-failure"] and module != "" and name != "" ->
            excerpt = annotation["raw_details"] || annotation["description"] || message
            [%{module: module, name: name, job: job, path: annotation["path"], excerpt: String.slice(String.trim(to_string(excerpt)), 0, 500)}]

          _ ->
            []
        end

      _ ->
        []
    end)
  end

  defp check_run_id(%{"check_run_id" => id}) when is_integer(id), do: id

  defp check_run_id(%{"check_run_url" => url}) when is_binary(url) do
    case Regex.run(~r{/check-runs/(\d+)\z}, url, capture: :all_but_first) do
      [id] -> String.to_integer(id)
      _ -> nil
    end
  end

  defp check_run_id(_), do: nil

  defp run_prs(run, base) do
    prefix = "gh-readonly-queue/#{base}/"
    branch = run["head_branch"] || ""
    if String.starts_with?(branch, prefix), do: pr_numbers(branch), else: []
  end

  defp pr_numbers(branch), do: Regex.scan(~r/pr-(\d+)-/, branch, capture: :all_but_first) |> List.flatten() |> Enum.map(&String.to_integer/1) |> Enum.uniq()

  defp run_time(%{"created_at" => timestamp}) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, date, _offset} -> {:ok, DateTime.to_unix(date, :millisecond)}
      _ -> {:error, :invalid_merge_group_timestamp}
    end
  end

  defp run_time(_), do: {:error, :missing_merge_group_timestamp}
end
