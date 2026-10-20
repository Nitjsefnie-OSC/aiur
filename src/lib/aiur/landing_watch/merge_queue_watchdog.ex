defmodule Aiur.LandingWatch.MergeQueueWatchdog do
  @moduledoc "Repairs queue entries that stay unmergeable despite a clean, ready PR."

  alias Aiur.Alerts
  alias Aiur.GitHub.{CiReadiness, Client, Transport}
  alias Aiur.LandingWatch.{Classifier, Journal}
  alias Aiur.PrMerge.Queue

  @threshold_ms 5 * 60_000

  @spec reconcile([map()], keyword()) :: :ok | {:error, term()}
  def reconcile(observations, opts) do
    now = Keyword.get(opts, :now_ms, System.system_time(:millisecond))

    Enum.reduce_while(observations, :ok, fn observation, :ok ->
      case reconcile_one(observation, now, opts) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp reconcile_one(%{number: number, head: head, mergeable: "MERGEABLE", merge_state_status: "CLEAN", merge_queue_entry: %{"id" => entry, "state" => "UNMERGEABLE"}} = observation, now, opts)
       when is_integer(number) and is_binary(head) and is_binary(entry) do
    key = "#{number}:#{head}"

    with {:ok, since} <- reserve_first_seen(key, now, opts),
         true <- now - since >= @threshold_ms,
         :ok <- required_checks_pass?(head, opts),
         :ok <- repair(observation, opts),
         :ok <- clear_first_seen(number, head, opts) do
      emit_attention(number, head, opts)
    else
      false -> :ok
      {:error, :required_check_failed} -> :ok
      {:error, _} = error -> error
    end
  end

  defp reconcile_one(%{number: number, head: head}, _now, opts) when is_integer(number) and is_binary(head),
    do: clear_first_seen(number, head, opts)

  defp reconcile_one(_, _, _), do: :ok

  defp reserve_first_seen(key, now, opts) do
    Journal.update(opts, fn state ->
      rows = Map.get(state, "unmergeable_queue_entries", %{})
      since = Map.get(rows, key, now)
      {:ok, Map.put(state, "unmergeable_queue_entries", Map.put(rows, key, since)), since}
    end)
  end

  defp clear_first_seen(number, head, opts) do
    key = "#{number}:#{head}"

    Journal.update(opts, fn state ->
      rows = Map.delete(Map.get(state, "unmergeable_queue_entries", %{}), key)
      {:ok, Map.put(state, "unmergeable_queue_entries", rows)}
    end)
  end

  defp required_checks_pass?(head, opts) do
    with {:ok, checks} <- Keyword.get(opts, :required_checks_fun, &CiReadiness.fetch_required_checks/1).(opts),
         true <- is_list(checks) and checks != [],
         {:ok, %{check_runs: runs, commit_status: status}} <- Keyword.get(opts, :ci_status_fun, &Client.fetch_commit_ci_status/2).(head, opts),
         true <- status["state"] == "success",
         true <- Enum.all?(checks, fn check -> Enum.any?(runs, &(&1["name"] == check.name and &1["conclusion"] == "success")) end) do
      :ok
    else
      false -> {:error, :required_check_failed}
      {:error, _} = error -> error
      _ -> {:error, :required_check_failed}
    end
  end

  defp repair(observation, opts) do
    with true <- observation.draft? == false and observation.review_decision == "APPROVED" and observation.auto_merge_request == nil,
         :ok <- revalidate_queue_entry(observation, opts),
         :ok <- dequeue(observation.node_id, opts),
         :ok <- revalidate_eligible(%{observation | merge_queue_entry: nil}, opts),
         {:ok, _entry} <- enqueue(observation, opts) do
      :ok
    else
      false -> {:error, :queue_recovery_observation_ineligible}
      {:error, _} = error -> error
      _ -> {:error, :queue_recovery_failed}
    end
  end

  defp revalidate_eligible(observation, opts) do
    case Keyword.get(opts, :revalidate_fun, &revalidate_live_entry/3).(observation.number, observation.head, opts) do
      :ok -> :ok
      {:error, _} = error -> error
      _ -> {:error, :queue_recovery_revalidation_failed}
    end
  end

  defp revalidate_live_entry(number, expected_head, opts) do
    query =
      "query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){id headRefOid isDraft reviewDecision mergeable mergeStateStatus autoMergeRequest{enabledAt} mergeQueueEntry{id} reviews(states:APPROVED,last:1){nodes{commit{oid}}}}}}"

    with {:ok, {owner, repo}} <- Transport.parse_repo(),
         {:ok, token} <- Transport.require_token(opts),
         {:ok, %{"data" => %{"repository" => %{"pullRequest" => pr}}}} <-
           Transport.github_graphql(Keyword.get(opts, :request_fun, &Transport.default_request_fun/1), token, query, %{owner: owner, repo: repo, number: number},
             caller: "landing_watch_unmergeable_revalidate"
           ),
         true <-
           pr["headRefOid"] == expected_head and pr["isDraft"] == false and pr["mergeable"] == "MERGEABLE" and
             pr["mergeStateStatus"] == "CLEAN" and is_nil(pr["mergeQueueEntry"]) and is_nil(pr["autoMergeRequest"]) and
             Classifier.approved_at_head?(pr) do
      :ok
    else
      {:error, _} = error -> error
      false -> {:error, :queue_recovery_precondition_changed}
      _ -> {:error, :invalid_queue_recovery_revalidation}
    end
  end

  defp revalidate_queue_entry(observation, opts) do
    case Keyword.get(opts, :revalidate_queue_fun) do
      fun when is_function(fun, 2) -> fun.(observation, opts)
      _ -> query_live_queue_entry(observation, opts)
    end
  end

  defp query_live_queue_entry(observation, opts) do
    query =
      "query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){id headRefOid isDraft reviewDecision mergeable mergeStateStatus autoMergeRequest{enabledAt} mergeQueueEntry{id state} reviews(states:APPROVED,last:1){nodes{commit{oid}}}}}}"

    with {:ok, {owner, repo}} <- Transport.parse_repo(),
         {:ok, token} <- Transport.require_token(opts),
         {:ok, %{"data" => %{"repository" => %{"pullRequest" => pr}}}} <-
           Transport.github_graphql(Keyword.get(opts, :request_fun, &Transport.default_request_fun/1), token, query, %{owner: owner, repo: repo, number: observation.number},
             caller: "landing_watch_unmergeable_revalidate"
           ),
         true <-
           pr["id"] == observation.node_id and pr["headRefOid"] == observation.head and pr["isDraft"] == false and
             pr["reviewDecision"] == "APPROVED" and pr["mergeable"] == "MERGEABLE" and pr["mergeStateStatus"] == "CLEAN" and
             is_nil(pr["autoMergeRequest"]) and get_in(pr, ["mergeQueueEntry", "id"]) == get_in(observation, [:merge_queue_entry, "id"]) and
             get_in(pr, ["mergeQueueEntry", "state"]) == "UNMERGEABLE" and Classifier.approved_at_head?(pr) do
      :ok
    else
      {:error, _} = error -> error
      false -> {:error, :queue_recovery_precondition_changed}
      _ -> {:error, :invalid_queue_recovery_revalidation}
    end
  end

  defp dequeue(node_id, opts) do
    api = graphql_api(opts, "landing_watch_unmergeable_dequeue")
    query = "mutation($id: ID!) { dequeuePullRequest(input: {id: $id}) { mergeQueueEntry { id } } }"

    case api.("post", "graphql", %{query: query, variables: %{id: node_id}}) do
      {:ok, %{"data" => %{"dequeuePullRequest" => %{}}}} -> :ok
      {:error, _} = error -> error
      _ -> {:error, :dequeue_unconfirmed}
    end
  end

  defp enqueue(observation, opts) do
    Queue.enqueue(graphql_api(opts, "landing_watch_unmergeable_enqueue"), %{node_id: observation.node_id, head: observation.head})
  end

  defp graphql_api(opts, caller) do
    fn "post", "graphql", %{query: query, variables: variables} ->
      with {:ok, token} <- Transport.require_token(opts),
           do: Transport.github_graphql(Keyword.get(opts, :request_fun, &Transport.default_request_fun/1), token, query, variables, caller: caller)
    end
  end

  defp emit_attention(number, head, opts) do
    message = "Merge queue entry for PR ##{number} stayed UNMERGEABLE for over five minutes while the PR is MERGEABLE/CLEAN and required checks pass; the entry was re-enqueued."

    Keyword.get(opts, :alert_emitter, &Alerts.emit_system/2).("system.pr.landing.merge_queue_recovered",
      central: true,
      durable: true,
      needs_attention: true,
      message: message,
      reason: "stale_unmergeable_entry",
      head: head
    )
  end
end
