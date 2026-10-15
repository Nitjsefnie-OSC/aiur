defmodule Aiur.LandingWatch.MergeGroups do
  @moduledoc "Cancels active merge-group runs that no longer belong to the live queue."

  alias Aiur.Config.TrackerSettings
  alias Aiur.GitHub.{CIRecovery, Client, Errors, Transport}
  alias Aiur.LandingWatch

  alias Aiur.LandingWatch.{
    Attribution,
    Journal,
    MergeFailureClassifier,
    MergeFailureOptions,
    MergeGroupFailureEvidence,
    Observer
  }

  alias Aiur.PrMerge.Queue

  @page_limit 5

  @spec cancel_stale([map()], keyword()) :: :ok | {:error, term()}
  def cancel_stale(observations, opts \\ [])

  def cancel_stale(observations, opts) when is_list(observations) do
    with {:ok, base} <- base_branch(opts),
         {:ok, {owner, repo}} <- Transport.parse_repo(),
         {:ok, token} <- Transport.require_token(opts),
         {:ok, runs} <- active_runs(owner, repo, token, opts),
         {:ok, completed} <- completed_runs(owner, repo, token, opts),
         {:ok, fresh_observations} <- live_observations(observations, opts) do
      with :ok <- process_completed(completed, fresh_observations, base, opts),
           {:ok, reconciled_observations} <- live_observations(fresh_observations, opts) do
        live =
          Map.new(
            Enum.map(reconciled_observations, &live_entry(&1, base))
            |> Enum.reject(&is_nil/1)
          )

        cancel_runs(Enum.filter(runs, &stale?(&1, base, live)), opts)
      end
    end
  end

  def cancel_stale(_, _), do: {:error, :invalid_queue_observations}

  defp live_observations(fallback, opts) do
    case Keyword.get(opts, :live_observations_fun, &Observer.refresh_queue/2).(fallback, opts) do
      {:ok, observations} when is_list(observations) -> {:ok, observations}
      {:error, _} = error -> error
      _ -> {:error, :invalid_live_queue_observations}
    end
  end

  defp live_entry(%{base: base, number: number, merge_queue_entry: entry} = observation, base)
       when is_integer(number) and is_map(entry),
       do:
         {number,
          %{
            head: Map.get(observation, :head),
            committed_at: Map.get(observation, :head_committed_at),
            queue_head: get_in(entry, ["pullRequest", "headRefOid"])
          }}

  defp live_entry(_observation, _base), do: nil

  defp stale?(
         %{"id" => id, "event" => "merge_group", "status" => status, "head_branch" => branch} =
           run,
         base,
         live
       )
       when is_integer(id) and status in ["queued", "in_progress", "waiting", "requested"] and
              is_binary(branch) do
    prefix = "gh-readonly-queue/#{base}/pr-"

    if String.starts_with?(branch, prefix) do
      branch
      |> then(&Regex.scan(~r/pr-(\d+)-/, &1, capture: :all_but_first))
      |> List.flatten()
      |> Enum.map(&String.to_integer/1)
      |> Enum.any?(&(not current_entry?(Map.get(live, &1), run)))
    else
      false
    end
  end

  defp stale?(_run, _base, _live), do: false

  defp current_entry?(nil, _run), do: false

  defp current_entry?(%{head: head, committed_at: committed_at, queue_head: queue_head}, %{
         "created_at" => created_at
       })
       when is_binary(head) and is_binary(committed_at) and is_binary(queue_head) and
              is_binary(created_at) do
    queue_head == head and timestamp_at_or_after?(created_at, committed_at)
  end

  defp current_entry?(_entry, _run), do: true

  defp timestamp_at_or_after?(created_at, committed_at) do
    with {:ok, run_time, _} <- DateTime.from_iso8601(created_at),
         {:ok, head_time, _} <- DateTime.from_iso8601(committed_at) do
      DateTime.compare(run_time, head_time) in [:eq, :gt]
    else
      _ -> false
    end
  end

  defp cancel_runs(runs, opts) do
    Enum.reduce(runs, :ok, &cancel_if_ok(&1, &2, opts))
  end

  defp cancel_if_ok(_run, {:error, _} = error, _opts), do: error

  defp cancel_if_ok(run, :ok, opts) do
    case Keyword.get(opts, :cancel_fun, &CIRecovery.cancel/2).(run["id"], opts) do
      :ok -> :ok
      {:error, reason} -> {:error, {:merge_group_cancel_failed, run["id"], reason}}
    end
  end

  defp active_runs(owner, repo, token, opts) do
    request = Keyword.get(opts, :request_fun, &Transport.default_request_fun/1)

    ["queued", "in_progress", "waiting", "requested"]
    |> Enum.reduce_while({:ok, []}, fn status, {:ok, acc} ->
      url =
        "#{Transport.base_url()}/repos/#{owner}/#{repo}/actions/runs?" <>
          URI.encode_query(%{event: "merge_group", per_page: 100, status: status})

      case read_pages(request, token, url, [], 0) do
        {:ok, runs} -> {:cont, {:ok, acc ++ runs}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, runs} ->
        {:ok, runs |> Enum.filter(&(&1["event"] == "merge_group")) |> Enum.uniq_by(& &1["id"])}

      {:error, _} = error ->
        error
    end
  end

  defp completed_runs(owner, repo, token, opts) do
    request = Keyword.get(opts, :request_fun, &Transport.default_request_fun/1)

    url =
      "#{Transport.base_url()}/repos/#{owner}/#{repo}/actions/runs?" <>
        URI.encode_query(%{event: "merge_group", per_page: 100, status: "completed"})

    with {:ok, runs} <- read_pages(request, token, url, [], 0),
         do: {:ok, Enum.filter(runs, &(&1["event"] == "merge_group"))}
  end

  defp process_completed(runs, observations, base, opts) do
    failures =
      Enum.filter(
        runs,
        &(&1["conclusion"] in ["failure", "cancelled", "timed_out", "startup_failure"] and
            is_integer(&1["id"]))
      )

    has_observed_pr? =
      Enum.any?(failures, fn run ->
        Enum.any?(
          pr_numbers(run["head_branch"]),
          &Enum.any?(observations, fn pr -> pr.number == &1 end)
        )
      end)

    opts = if has_observed_pr?, do: prepare_failure_evidence(opts, base), else: opts

    Enum.reduce(failures, :ok, fn run, result ->
      if result == :ok,
        do: process_claimed_failed_group(run, runs, observations, base, opts),
        else: result
    end)
  end

  defp prepare_failure_evidence(opts, base) do
    opts
    |> Keyword.put(
      :recent_main_failure_paths,
      MergeGroupFailureEvidence.recent_main_paths(base, opts)
    )
    |> Keyword.put(:known_failure_patterns, MergeGroupFailureEvidence.known_patterns(opts))
  end

  defp process_claimed_failed_group(run, runs, observations, base, opts) do
    case Journal.claim_merge_group_run(run["id"], opts) do
      {:ok, :already_claimed} -> :ok
      {:ok, :new} -> process_new_failed_group(run, runs, observations, base, opts)
      {:error, _} = error -> error
    end
  end

  defp process_new_failed_group(run, runs, observations, base, opts) do
    case process_failed_group(run, runs, observations, base, opts) do
      :ok ->
        :ok

      {:error, _} = error ->
        _ = Journal.release_merge_group_run(run["id"], opts)
        error
    end
  end

  defp process_failed_group(run, runs, observations, base, opts) do
    case run_prs(run, base) do
      {:ok, []} -> :ok
      {:ok, prs} -> process_failed_group_for_prs(run, runs, observations, prs, opts)
    end
  end

  defp process_failed_group_for_prs(run, _runs, observations, prs, opts) do
    with {:ok, jobs} <- Keyword.get(opts, :jobs_fun, &CIRecovery.jobs/2).(run["id"], opts),
         {:ok, {classification, failure}} <-
           MergeFailureClassifier.classify(
             run,
             jobs,
             observations,
             classifier_options(run, prs, jobs, opts)
           ) do
      case classification do
        :infra ->
          requeue_group_prs(prs, observations, run, "infrastructure failure", opts)

        :inherited ->
          requeue_group_prs(prs, observations, run, "inherited merge-group failure", opts)

        :known_non_pr ->
          requeue_group_prs(prs, observations, run, "known non-PR failure", opts)

        :pr_caused ->
          route_failed_prs(prs, observations, failure, run, opts)
      end
    else
      {:error, _} = error -> error
    end
  end

  defp classifier_options(run, prs, jobs, opts) do
    MergeFailureOptions.build(run, prs, jobs, opts, &job_log/2)
  end

  defp job_log(job, opts) do
    case job["id"] do
      id when is_integer(id) ->
        case CIRecovery.read("/actions/jobs/#{id}/logs", opts) do
          {:ok, %{"log" => log}} when is_binary(log) -> {:ok, log}
          {:ok, log} when is_binary(log) -> {:ok, log}
          {:error, reason} -> {:error, reason}
          _ -> {:error, :invalid_actions_job_log}
        end

      _ ->
        {:error, :missing_actions_job_id}
    end
  end

  defp route_failed_prs(_prs, _observations, nil, _run, _opts), do: :ok

  defp route_failed_prs(prs, observations, failure, run, opts) do
    failures = [failure_to_map(failure)]
    run_link = run_url(run["id"], opts)

    prs
    |> Enum.map(&Enum.find(observations, fn observation -> observation.number == &1 end))
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(:ok, &rework_if_ok(&1, &2, failures, run_link, opts))
  end

  defp failure_to_map(failure),
    do: %{
      name: failure.job["name"] || "Failed merge-group test",
      excerpt: String.slice(failure.log, 0, 500)
    }

  defp run_url(run_id, opts) do
    case Keyword.get(opts, :repo_fun, &Transport.parse_repo/0).() do
      {:ok, {owner, repo}} -> "https://github.com/#{owner}/#{repo}/actions/runs/#{run_id}"
      _ -> "https://github.com/actions/runs/#{run_id}"
    end
  end

  defp rework_if_ok(_pr, {:error, _} = error, _failures, _run_link, _opts), do: error

  defp rework_if_ok(pr, :ok, failures, run_link, opts),
    do: LandingWatch.rework(pr, failures, Keyword.put(opts, :run_url, run_link))

  defp requeue_group_prs(numbers, observations, run, reason, opts) do
    now = Keyword.get(opts, :now_ms, System.system_time(:millisecond))
    identity = "merge-group-requeue-#{run["id"]}"

    Enum.reduce_while(numbers, :ok, fn number, result ->
      requeue_number(number, result, observations, run, reason, identity, now, opts)
    end)
  end

  defp requeue_number(
         _number,
         {:error, _} = error,
         _observations,
         _run,
         _reason,
         _identity,
         _now,
         _opts
       ),
       do: {:halt, error}

  defp requeue_number(number, :ok, observations, run, reason, identity, now, opts) do
    case Enum.find(observations, &(&1.number == number)) do
      nil -> {:cont, :ok}
      pr -> requeue_observed_pr(pr, number, run, reason, identity, now, opts)
    end
  end

  defp requeue_observed_pr(pr, number, run, reason, identity, now, opts) do
    if eligible_for_group_requeue?(pr, opts) do
      reserve_and_enqueue(pr, number, run, reason, identity, now, opts)
    else
      {:cont, :ok}
    end
  end

  defp reserve_and_enqueue(pr, number, run, reason, identity, now, opts) do
    case Journal.claim_alert(number, pr.head, identity, opts) do
      {:ok, :already_claimed} -> {:cont, :ok}
      {:ok, :new} -> requeue_claimed_pr(pr, number, run, reason, identity, now, opts)
      {:error, _} = error -> {:halt, error}
    end
  end

  defp requeue_claimed_pr(pr, number, run, reason, identity, now, opts) do
    case Journal.reserve_merge_group_requeue(now, opts) do
      :ok ->
        enqueue_and_comment(pr, number, run, reason, identity, opts)

      {:error, :merge_group_requeue_limit_reached} ->
        release_claim(number, pr.head, identity, opts, :ok)

      {:error, _} = error ->
        {:halt, error}
    end
  end

  defp enqueue_and_comment(pr, number, run, reason, identity, opts) do
    case enqueue(pr, pr.node_id, pr.head, opts) do
      {:ok, entry} -> confirm_requeue(pr, entry, number, run, reason, identity, opts)
      {:error, _} = error -> release_claim(number, pr.head, identity, opts, error)
    end
  end

  defp confirm_requeue(pr, entry, number, run, reason, identity, opts) do
    case Journal.mark_landed(pr.number, pr.head, entry, opts) do
      :ok ->
        case comment_requeue(pr, run, reason, opts) do
          :ok -> {:cont, :ok}
          {:error, _} = error -> {:halt, error}
        end

      {:error, _} = error ->
        release_claim(number, pr.head, identity, opts, error)
    end
  end

  defp release_claim(number, head, identity, opts, result) do
    _ = Journal.release_alert(number, head, identity, opts)

    case result do
      :ok -> {:halt, :ok}
      {:error, _} = error -> {:halt, error}
    end
  end

  defp eligible_for_group_requeue?(
         %{number: number, head: head, merge_queue_entry: nil, auto_merge_request: nil} = pr,
         opts
       ) do
    pr.draft? == false and pr.review_decision == "APPROVED" and is_binary(head) and
      is_binary(pr.node_id) and
      Keyword.get(opts, :approved_fun, fn _, _ -> {:ok, true} end).(number, opts) == {:ok, true} and
      Keyword.get(opts, :revalidate_fun, &Observer.revalidate_approved_head/3).(
        number,
        head,
        opts
      ) == :ok and
      Keyword.get(opts, :attribution_fun, fn ticket ->
        Attribution.pull_request_clean?(ticket.number, opts)
      end).(pr) == {:ok, :clean}
  end

  defp eligible_for_group_requeue?(_pr, _opts), do: false

  defp comment_requeue(pr, run, reason, opts) do
    body =
      "Landing watcher requeued this approved PR after merge group run ##{run["id"]} failed due to #{reason}."

    Keyword.get(opts, :comment_fun, fn number, text, options ->
      Client.create_comment(to_string(number), text, options)
    end).(pr.number, body, opts)
  end

  defp run_prs(run, base) do
    branch = Map.get(run, "head_branch", "")
    prefix = "gh-readonly-queue/#{base}/"

    prs =
      if is_binary(branch) and String.starts_with?(branch, prefix),
        do: pr_numbers(branch),
        else: []

    {:ok, prs}
  end

  defp pr_numbers(branch) when is_binary(branch) do
    Regex.scan(~r/pr-(\d+)-/, branch, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.to_integer/1)
    |> Enum.uniq()
  end

  defp pr_numbers(_), do: []

  defp enqueue(_pr, node_id, head, opts) do
    case Keyword.get(opts, :enqueue_fun) do
      fun when is_function(fun, 3) -> fun.(node_id, head, opts)
      _ -> enqueue_with_github(node_id, head, opts)
    end
  end

  defp enqueue_with_github(node_id, head, opts) do
    api = fn "post", "graphql", %{query: query, variables: variables} ->
      with {:ok, token} <- Transport.require_token(opts),
           do:
             Transport.github_graphql(
               Keyword.get(opts, :request_fun, &Transport.default_request_fun/1),
               token,
               query,
               variables,
               caller: "landing_watch_merge_group_requeue"
             )
    end

    Queue.enqueue(api, %{node_id: node_id, head: head})
  end

  defp read_pages(_request, _token, _url, _acc, @page_limit),
    do: {:error, :merge_group_run_list_too_large}

  defp read_pages(request, token, url, acc, page) do
    case request.(%{
           method: :get,
           url: url,
           token: token,
           caller: "landing_watch_merge_group_runs"
         }) do
      {:ok, %{status: 200, body: %{"workflow_runs" => runs}} = response} when is_list(runs) ->
        case Transport.parse_next_page_url(Map.get(response, :headers, [])) do
          nil -> {:ok, acc ++ runs}
          next -> read_pages(request, token, next, acc ++ runs, page + 1)
        end

      {:ok, %{status: _} = response} ->
        {:error, Errors.github_status_error(response)}

      {:error, reason} ->
        {:error, Errors.classify_error({:error, reason})}
    end
  end

  defp base_branch(opts) do
    case Keyword.fetch(opts, :base_branch) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, _} -> {:error, :invalid_landing_base_branch}
      :error -> {:ok, TrackerSettings.base_branch()}
    end
  rescue
    error -> {:error, {:landing_base_branch_unavailable, Exception.message(error)}}
  end
end
