defmodule Aiur.LandingWatch.MergeQueueWatchdog do
  @moduledoc "Repairs queue entries that stay unmergeable despite a clean, ready PR."

  alias Aiur.Alerts
  alias Aiur.GitHub.Transport
  alias Aiur.LandingWatch.Classifier
  alias Aiur.LandingWatch.{Journal, MergeQueueFailureEvidence, MergeQueueRecoveryAttempt, MergeQueueWatchdogEvidence}
  alias Aiur.PrMerge.Queue

  @threshold_ms 20 * 60_000
  @max_attempts 1

  @spec reconcile([map()], keyword()) :: :ok | {:error, term()}
  def reconcile(observations, opts) do
    now = Keyword.get(opts, :now_ms, System.system_time(:millisecond))

    Enum.reduce_while(observations, :ok, fn observation, :ok ->
      case reconcile_one(observation, now, opts) do
        {:error, _} = error -> {:halt, error}
        _ -> {:cont, :ok}
      end
    end)
  end

  @spec after_reconcile(:ok | {:error, term()}, :ok | {:error, term()}, [map()], keyword()) ::
          :ok | {:error, term()}
  def after_reconcile(process_result, reconcile_result, observations, opts) do
    watchdog_result =
      Keyword.get(opts, :merge_queue_watchdog_fun, &__MODULE__.reconcile/2).(observations, opts)

    first_error([process_result, reconcile_result, watchdog_result])
  end

  defp first_error(results) do
    case Enum.find(results, &match?({:error, _}, &1)) do
      {:error, _} = error -> error
      nil -> :ok
    end
  end

  defp reconcile_one(
         %{
           number: number,
           head: head,
           merge_queue_entry: %{"id" => entry, "state" => _queue_state}
         } = observation,
         now,
         opts
       )
       when is_integer(number) and is_binary(head) and is_binary(entry) do
    if tracked_observation?(observation) do
      track_candidate(observation, now, opts)
    else
      clear_first_seen(number, head, opts)
    end
  end

  defp reconcile_one(%{number: number, head: head}, _now, opts)
       when is_integer(number) and is_binary(head),
       do: clear_first_seen(number, head, opts)

  defp reconcile_one(_, _, _), do: :ok

  defp reserve_first_seen(key, now, opts) do
    Journal.update(opts, fn state ->
      rows = Map.get(state, "unmergeable_queue_entries", %{})

      existing =
        case Map.get(rows, key) do
          row when is_map(row) -> row
          since when is_integer(since) -> %{"since" => since, "attempts" => 0}
          _ -> %{"attempts" => 0}
        end

      since = existing |> Map.get("since") |> earlier_since(now)
      row = Map.put(existing, "since", since)
      {:ok, Map.put(state, "unmergeable_queue_entries", Map.put(rows, key, row)), row}
    end)
  end

  defp earlier_since(existing, candidate) when is_integer(existing), do: min(existing, candidate)
  defp earlier_since(_, candidate), do: candidate

  defp tracked_observation?(%{merge_state_status: status, mergeable: mergeable, merge_queue_entry: %{"state" => state}}),
    do:
      status in ["CLEAN", "UNKNOWN"] and mergeable in ["MERGEABLE", "UNKNOWN"] and
        state in ["UNMERGEABLE", "AWAITING_CHECKS"]

  defp tracked_observation?(_), do: false

  defp track_candidate(observation, now, opts) do
    queue_state = get_in(observation, [:merge_queue_entry, "state"])
    failed_since = failed_group_trigger_since(observation, opts)
    candidate_since = candidate_since(queue_state, failed_since, now)

    case candidate_since do
      since when is_integer(since) -> reserve_candidate(observation, queue_state, since, now, opts)
      _ -> :ok
    end
  end

  defp reserve_candidate(observation, queue_state, since, now, opts) do
    key = "#{observation.number}:#{observation.head}"

    with {:ok, row} <- reserve_first_seen(key, since, opts),
         :ok <- if(queue_state == "UNMERGEABLE", do: maybe_repair(observation, row, now, opts), else: :ok) do
      :ok
    else
      {:error, _} = error -> error
    end
  end

  defp candidate_since("UNMERGEABLE", failed_since, now) when is_integer(failed_since), do: min(failed_since, now)
  defp candidate_since("UNMERGEABLE", _failed_since, now), do: now
  defp candidate_since("AWAITING_CHECKS", failed_since, now) when is_integer(failed_since), do: min(failed_since, now)
  defp candidate_since(_, _, _), do: nil

  defp failed_group_trigger_since(observation, opts) do
    runs = Keyword.get(opts, :completed_merge_group_runs, [])
    base = Keyword.get(opts, :base_branch, Aiur.Config.base_branch())
    MergeQueueFailureEvidence.failed_group_trigger_since_ms(observation.number, runs, base)
  end

  defp maybe_repair(observation, row, now, opts) do
    cond do
      not is_integer(row_since(row)) or now - row_since(row) < @threshold_ms ->
        :ok

      row_attempts(row) >= @max_attempts ->
        maybe_give_up(observation, row, opts)

      not observation_eligible?(observation) ->
        :ok

      true ->
        evidence_opts = Keyword.put(opts, :unmergeable_since_ms, row_since(row))

        case classify_head_failure(observation, evidence_opts) do
          {:ok, failure} ->
            reserve_and_repair(observation, failure, now, opts)

          {:skip, reason} ->
            log_skip(observation, reason)
            :ok

          {:error, reason} ->
            log_skip(observation, reason)
            {:error, reason}
        end
    end
  end

  defp reserve_and_repair(observation, failure, now, opts) do
    case MergeQueueRecoveryAttempt.reserve(observation.number, observation.head, now, opts) do
      {:ok, :reserved} ->
        finish_reserved_repair(observation, failure, opts)

      {:skip, reason} ->
        log_skip(observation, reason)
        :ok

      {:error, reason} ->
        log_skip(observation, reason)
        {:error, reason}
    end
  end

  defp finish_reserved_repair(observation, failure, opts) do
    case repair(observation, opts) do
      :ok ->
        emit_attention(observation.number, observation.head, failure, opts)
        :ok

      {:error, {:attempt_commit_after_dequeue, _reason}} = error ->
        log_skip(observation, :attempt_commit_after_dequeue_failed)
        error

      {:skip, reason} ->
        MergeQueueRecoveryAttempt.release(observation.number, observation.head, opts)
        log_skip(observation, reason)
        :ok

      {:error, reason} = error ->
        MergeQueueRecoveryAttempt.release(observation.number, observation.head, opts)
        log_skip(observation, reason)
        error
    end
  end

  defp classify_head_failure(observation, opts) do
    case Keyword.get(opts, :head_failure_fun) do
      fun when is_function(fun, 2) ->
        case fun.(observation, opts) do
          {:ok, %{classification: kind} = evidence} when kind in [:infra, :inherited, :known_non_pr] -> {:ok, evidence}
          {:ok, %{classification: :pr_caused}} -> {:skip, :pr_caused_merge_group_failure}
          {:skip, _} = skip -> skip
          {:error, _} = error -> error
          _ -> {:skip, :merge_group_failure_not_proven_innocent}
        end

      _ ->
        classify_observed_head_failure(observation, opts)
    end
  end

  defp classify_observed_head_failure(observation, opts) do
    MergeQueueWatchdogEvidence.classify(observation, opts)
  end

  defp row_since(%{"since" => since}) when is_integer(since), do: since
  defp row_since(since) when is_integer(since), do: since
  defp row_since(_), do: 0

  defp row_attempts(%{"attempts" => attempts}) when is_integer(attempts), do: attempts
  defp row_attempts(_), do: 0

  defp observation_eligible?(observation),
    do:
      Map.get(observation, :draft?) == false and
        Map.get(observation, :review_decision) == "APPROVED" and
        is_nil(Map.get(observation, :auto_merge_request))

  defp maybe_give_up(observation, row, opts) do
    if row_attempts(row) == @max_attempts and not Map.get(row, "gave_up_alerted", false) do
      emit_gave_up(observation.number, observation.head, opts)
      mark_gave_up_alerted(observation.number, observation.head, opts)
      :ok
    else
      :ok
    end
  end

  defp clear_first_seen(number, head, opts) do
    key = "#{number}:#{head}"

    Journal.update(opts, fn state ->
      rows = Map.get(state, "unmergeable_queue_entries", %{})
      row = Map.get(rows, key)

      rows =
        case row do
          value when is_map(value) -> Map.put(rows, key, Map.put(value, "since", nil))
          since when is_integer(since) -> Map.put(rows, key, %{"since" => nil, "attempts" => 0})
          _ -> rows
        end

      {:ok, Map.put(state, "unmergeable_queue_entries", rows)}
    end)
  end

  defp mark_gave_up_alerted(number, head, opts) do
    key = "#{number}:#{head}"

    Journal.update(opts, fn state ->
      rows = Map.get(state, "unmergeable_queue_entries", %{})
      row = Map.get(rows, key, %{}) |> Map.put("gave_up_alerted", true)
      {:ok, Map.put(state, "unmergeable_queue_entries", Map.put(rows, key, row))}
    end)
  end

  defp repair(observation, opts) do
    with true <-
           observation.draft? == false and observation.review_decision == "APPROVED" and
             observation.auto_merge_request == nil,
         :ok <- revalidate_queue_entry(observation, opts),
         :ok <- dequeue(observation.node_id, opts),
         :ok <- commit_dequeued_attempt(observation, opts),
         :ok <- revalidate_eligible(%{observation | merge_queue_entry: nil}, opts),
         {:ok, _entry} <- enqueue(observation, opts) do
      :ok
    else
      false -> {:skip, :queue_recovery_observation_ineligible}
      {:error, _} = error -> error
      _ -> {:skip, :queue_recovery_precondition_changed}
    end
  end

  defp commit_dequeued_attempt(observation, opts) do
    case MergeQueueRecoveryAttempt.commit(observation.number, observation.head, opts) do
      {:ok, _committed} -> :ok
      {:error, reason} -> {:error, {:attempt_commit_after_dequeue, reason}}
    end
  end

  defp revalidate_eligible(observation, opts) do
    case Keyword.get(opts, :queue_recovery_revalidate_fun, &revalidate_live_entry/3).(
           observation.number,
           observation.head,
           opts
         ) do
      :ok -> :ok
      {:error, _} = error -> error
      _ -> {:skip, :queue_recovery_precondition_changed}
    end
  end

  defp revalidate_live_entry(number, expected_head, opts) do
    query =
      "query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){id headRefOid isDraft reviewDecision mergeable mergeStateStatus autoMergeRequest{enabledAt} mergeQueueEntry{id} reviews(states:APPROVED,last:1){nodes{commit{oid}}}}}}"

    with {:ok, {owner, repo}} <- Transport.parse_repo(),
         {:ok, token} <- Transport.require_token(opts),
         {:ok, response} <-
           Transport.github_graphql(
             Keyword.get(opts, :request_fun, &Transport.default_request_fun/1),
             token,
             query,
             %{owner: owner, repo: repo, number: number},
             caller: "landing_watch_unmergeable_revalidate"
           ) do
      case response do
        %{"data" => %{"repository" => %{"pullRequest" => pr}}} ->
          validate_live_pr(pr, expected_head)

        _ ->
          {:error, :invalid_queue_recovery_revalidation}
      end
    end
  end

  defp validate_live_pr(pr, expected_head) do
    eligible? =
      pr["headRefOid"] == expected_head and pr["isDraft"] == false and
        pr["mergeable"] == "MERGEABLE" and pr["mergeStateStatus"] == "CLEAN" and
        is_nil(pr["mergeQueueEntry"]) and is_nil(pr["autoMergeRequest"]) and
        Classifier.approved_at_head?(pr)

    if eligible?, do: :ok, else: {:skip, :queue_recovery_precondition_changed}
  end

  defp revalidate_queue_entry(observation, opts) do
    case Keyword.get(opts, :revalidate_queue_fun) do
      fun when is_function(fun, 2) -> fun.(observation, opts)
      _ -> query_live_queue_entry(observation, opts)
    end
  end

  defp query_live_queue_entry(observation, opts) do
    with {:ok, pr} <- fetch_queue_revalidation_pr(observation.number, opts),
         true <- queue_entry_unchanged?(pr, observation) do
      :ok
    else
      {:error, _} = error -> error
      false -> {:skip, :queue_recovery_precondition_changed}
    end
  end

  defp fetch_queue_revalidation_pr(number, opts) do
    query =
      "query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){id headRefOid isDraft reviewDecision mergeable mergeStateStatus autoMergeRequest{enabledAt} mergeQueueEntry{id state} reviews(states:APPROVED,last:1){nodes{commit{oid}}}}}}"

    with {:ok, {owner, repo}} <- Transport.parse_repo(),
         {:ok, token} <- Transport.require_token(opts),
         {:ok, %{"data" => %{"repository" => %{"pullRequest" => pr}}}} <-
           Transport.github_graphql(
             Keyword.get(opts, :request_fun, &Transport.default_request_fun/1),
             token,
             query,
             %{owner: owner, repo: repo, number: number},
             caller: "landing_watch_unmergeable_revalidate"
           ) do
      {:ok, pr}
    end
  end

  defp queue_entry_unchanged?(pr, observation) do
    same_pull_request_head?(pr, observation) and clean_approved_pr?(pr) and
      same_unmergeable_entry?(pr, observation) and Classifier.approved_at_head?(pr)
  end

  defp same_pull_request_head?(pr, observation),
    do: pr["id"] == observation.node_id and pr["headRefOid"] == observation.head

  defp clean_approved_pr?(pr),
    do:
      pr["isDraft"] == false and pr["reviewDecision"] == "APPROVED" and
        pr["mergeable"] == "MERGEABLE" and pr["mergeStateStatus"] == "CLEAN" and
        is_nil(pr["autoMergeRequest"])

  defp same_unmergeable_entry?(pr, observation),
    do:
      get_in(pr, ["mergeQueueEntry", "id"]) == get_in(observation, [:merge_queue_entry, "id"]) and
        get_in(pr, ["mergeQueueEntry", "state"]) == "UNMERGEABLE"

  defp dequeue(node_id, opts) do
    api = graphql_api(opts, "landing_watch_unmergeable_dequeue")

    query =
      "mutation($id: ID!) { dequeuePullRequest(input: {id: $id}) { mergeQueueEntry { id } } }"

    case api.("post", "graphql", %{query: query, variables: %{id: node_id}}) do
      {:ok, %{"data" => %{"dequeuePullRequest" => %{}}}} -> :ok
      {:error, _} = error -> error
      _ -> {:error, :dequeue_unconfirmed}
    end
  end

  defp enqueue(observation, opts) do
    Queue.enqueue(graphql_api(opts, "landing_watch_unmergeable_enqueue"), %{
      node_id: observation.node_id,
      head: observation.head
    })
  end

  defp graphql_api(opts, caller) do
    fn "post", "graphql", %{query: query, variables: variables} ->
      with {:ok, token} <- Transport.require_token(opts),
           do:
             Transport.github_graphql(
               Keyword.get(opts, :request_fun, &Transport.default_request_fun/1),
               token,
               query,
               variables,
               caller: caller
             )
    end
  end

  defp emit_attention(number, head, failure, opts) do
    tests = failure.failing_tests |> List.wrap() |> Enum.uniq()
    tests_text = if tests == [], do: "test names unavailable", else: Enum.join(tests, ", ")
    rebuilt = failure.rebuilt_groups

    message =
      "Merge queue entry for PR ##{number} stayed UNMERGEABLE or had repeated failed merge-group runs for over 20 minutes and was re-enqueued once. Failing tests: #{tests_text}. Rebuilt groups behind this queue head: #{rebuilt}."

    Keyword.get(opts, :alert_emitter, &Alerts.emit_system/2).(
      "system.pr.landing.merge_queue_recovered",
      central: true,
      durable: true,
      needs_attention: true,
      message: message,
      reason: "stale_unmergeable_entry",
      head: head
    )
  end

  defp emit_gave_up(number, head, opts) do
    Keyword.get(opts, :alert_emitter, &Alerts.emit_system/2).(
      "system.pr.landing.merge_queue_recovery_gave_up",
      central: true,
      durable: true,
      needs_attention: true,
      message: "Merge queue recovery for PR ##{number} reached #{@max_attempts} attempts; automatic retries stopped.",
      reason: "merge_queue_recovery_attempt_limit",
      head: head
    )
  end

  defp log_skip(observation, reason) do
    require Logger

    Logger.info("merge queue watchdog skipped PR ##{observation.number} head=#{observation.head} reason=#{inspect(reason)}")
  end
end
