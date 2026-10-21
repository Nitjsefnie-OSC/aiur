defmodule Aiur.LandingWatch.MergeQueueWatchdog do
  @moduledoc "Repairs queue entries that stay unmergeable despite a clean, ready PR."

  alias Aiur.Alerts
  alias Aiur.GitHub.{CIRecovery, Transport}
  alias Aiur.LandingWatch.Classifier
  alias Aiur.LandingWatch.{Journal, LocalRead, MergeFailureClassifier, MergeGroupFailureProcessor}
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
  def after_reconcile({:error, _} = error, _reconcile, _observations, _opts), do: error
  def after_reconcile(:ok, {:error, _} = error, _observations, _opts), do: error

  def after_reconcile(:ok, :ok, observations, opts) do
    Keyword.get(opts, :merge_queue_watchdog_fun, &__MODULE__.reconcile/2).(observations, opts)
  end

  defp reconcile_one(
         %{
           number: number,
           head: head,
           mergeable: "MERGEABLE",
           merge_state_status: "CLEAN",
           merge_queue_entry: %{"id" => entry, "state" => "UNMERGEABLE"}
         } = observation,
         now,
         opts
       )
       when is_integer(number) and is_binary(head) and is_binary(entry) do
    key = "#{number}:#{head}"

    with {:ok, row} <- reserve_first_seen(key, now, opts),
         :ok <- maybe_repair(observation, row, now, opts) do
      :ok
    else
      {:error, _} = error -> error
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

      row = Map.put(existing, "since", Map.get(existing, "since") || now)
      {:ok, Map.put(state, "unmergeable_queue_entries", Map.put(rows, key, row)), row}
    end)
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

        with {:ok, failure} <- classify_head_failure(observation, evidence_opts),
             {:ok, _reserved} <- reserve_attempt(observation.number, observation.head, opts),
             :ok <- repair(observation, opts),
             {:ok, _committed} <- commit_attempt(observation.number, observation.head, opts) do
          emit_attention(observation.number, observation.head, failure, opts)

          :ok
        else
          {:skip, reason} ->
            log_skip(observation, reason)
            :ok

          {:error, reason} ->
            log_skip(observation, reason)
            {:error, reason}
        end
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
    runs = Keyword.get(opts, :completed_merge_group_runs, [])
    base = Keyword.get(opts, :base_branch, "main")

    since_ms = Keyword.get(opts, :unmergeable_since_ms, 0)

    run =
      runs
      |> Enum.filter(fn item ->
        item["conclusion"] in ["failure", "cancelled", "timed_out", "startup_failure"] and
          is_integer(item["id"]) and observation.number in run_pr_numbers(item["head_branch"], base) and
          run_in_unmergeable_window?(item, since_ms)
      end)
      |> Enum.max_by(&(&1["run_started_at"] || &1["created_at"] || ""), fn -> nil end)

    case run do
      nil -> {:skip, :no_completed_failed_merge_group}
      failed_run -> classify_failed_run(failed_run, runs, observation, base, opts)
    end
  end

  defp run_in_unmergeable_window?(run, since_ms) do
    started_at = parse_time(run["run_started_at"] || run["created_at"])
    since = if is_integer(since_ms), do: DateTime.from_unix!(since_ms, :millisecond), else: DateTime.from_unix!(0)
    DateTime.compare(started_at, since) in [:eq, :gt]
  end

  defp classify_failed_run(run, runs, observation, base, opts) do
    prs = run_pr_numbers(run["head_branch"], base)
    observations = Keyword.get(opts, :all_observations, [observation])

    with {:ok, jobs} <- LocalRead.run(Keyword.get(opts, :jobs_fun, &CIRecovery.jobs/2), [run["id"], opts], opts),
         {:ok, {classification, failure}} <-
           MergeFailureClassifier.classify(
             run,
             jobs,
             Enum.filter(observations, &(&1.number in prs)),
             Keyword.get(opts, :failure_classifier_options_fun, &MergeGroupFailureProcessor.classifier_options/4).(
               run,
               prs,
               jobs,
               opts
             )
           ) do
      case classification do
        :pr_caused ->
          {:skip, :pr_caused_merge_group_failure}

        kind when kind in [:infra, :inherited, :known_non_pr] ->
          {:ok,
           %{
             classification: kind,
             failing_tests: failure |> then(&if(&1, do: &1.log, else: "")) |> test_names(),
             rebuilt_groups: rebuilt_group_count(runs, run, prs, base, Keyword.get(opts, :unmergeable_since_ms)),
             run_id: run["id"]
           }}
      end
    else
      {:error, reason} -> {:skip, {:merge_group_evidence_unavailable, reason}}
      other -> {:skip, {:merge_group_evidence_unavailable, other}}
    end
  end

  defp run_pr_numbers(branch, base) when is_binary(branch) do
    prefix = "gh-readonly-queue/#{base}/"

    if String.starts_with?(branch, prefix) do
      Regex.scan(~r/pr-(\d+)-/, branch, capture: :all_but_first) |> List.flatten() |> Enum.map(&String.to_integer/1)
    else
      []
    end
  end

  defp run_pr_numbers(_, _), do: []

  defp rebuilt_group_count(runs, failed_run, prs, base, since_ms) do
    failed_time = parse_time(failed_run["created_at"] || failed_run["run_started_at"])
    since_time = if is_integer(since_ms), do: DateTime.from_unix!(since_ms, :millisecond), else: DateTime.from_unix!(0)

    Enum.count(runs, fn run ->
      run["event"] == "merge_group" and run["id"] != failed_run["id"] and
        Enum.any?(run_pr_numbers(run["head_branch"], base), &(&1 in prs)) and
        DateTime.compare(parse_time(run["created_at"]), since_time) in [:eq, :gt] and
        DateTime.compare(parse_time(run["created_at"]), failed_time) != :gt
    end)
  end

  defp parse_time(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, time, _} -> time
      _ -> DateTime.from_unix!(0)
    end
  end

  defp parse_time(_), do: DateTime.from_unix!(0)

  defp test_names(log) do
    Regex.scan(~r/((?:test\/)?[\w.\/-]+_test\.exs(?::\d+)?|test [^\r\n]+)/, log, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp reserve_attempt(number, head, opts) do
    key = "#{number}:#{head}"

    Journal.update(opts, fn state ->
      rows = Map.get(state, "unmergeable_queue_entries", %{})
      row = Map.get(rows, key, %{"since" => 0, "attempts" => 0})

      if row_attempts(row) >= @max_attempts do
        {:ok, state, {:error, :recovery_attempt_limit}}
      else
        # A leftover pending flag means the process stopped mid-repair. Clear it and retry.
        updated = Map.put(row, "recovery_pending", true)
        {:ok, Map.put(state, "unmergeable_queue_entries", Map.put(rows, key, updated)), {:reserved, updated}}
      end
    end)
    |> case do
      {:ok, {:reserved, _row}} -> {:ok, :reserved}
      {:ok, {:error, reason}} -> {:error, reason}
      {:error, _} = error -> error
    end
  end

  defp commit_attempt(number, head, opts) do
    key = "#{number}:#{head}"

    Journal.update(opts, fn state ->
      rows = Map.get(state, "unmergeable_queue_entries", %{})
      row = Map.get(rows, key, %{"since" => 0, "attempts" => 0})

      if Map.get(row, "recovery_pending", false) do
        updated = Map.update(row, "attempts", 1, &(&1 + 1)) |> Map.delete("recovery_pending")
        {:ok, Map.put(state, "unmergeable_queue_entries", Map.put(rows, key, updated)), {:ok, updated}}
      else
        {:ok, state, {:error, :recovery_reservation_lost}}
      end
    end)
    |> case do
      {:ok, {:ok, row}} when is_map(row) -> {:ok, row}
      {:ok, {:error, reason}} -> {:error, reason}
      {:error, _} = error -> error
    end
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
         :ok <- revalidate_eligible(%{observation | merge_queue_entry: nil}, opts),
         {:ok, _entry} <- enqueue(observation, opts) do
      :ok
    else
      false -> {:skip, :queue_recovery_observation_ineligible}
      {:error, _} = error -> error
      _ -> {:skip, :queue_recovery_precondition_changed}
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
      "Merge queue entry for PR ##{number} stayed UNMERGEABLE for over 20 minutes and was re-enqueued once. Failing tests: #{tests_text}. Earlier merge-group runs containing this PR: #{rebuilt}."

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
