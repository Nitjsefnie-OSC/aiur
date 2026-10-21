defmodule Aiur.LandingWatch.MergeQueueWatchdogTest do
  use ExUnit.Case, async: true

  alias Aiur.LandingWatch.MergeQueueWatchdog

  defp observation_raw do
    %{
      "id" => "PR_17",
      "headRefOid" => "head-17",
      "isDraft" => false,
      "reviewDecision" => "APPROVED",
      "mergeable" => "MERGEABLE",
      "mergeStateStatus" => "CLEAN",
      "autoMergeRequest" => nil,
      "mergeQueueEntry" => nil,
      "reviews" => %{"nodes" => [%{"commit" => %{"oid" => "head-17"}}]}
    }
  end

  test "completed merge-group evidence reaches the watchdog after a routing error" do
    run = %{"id" => 81, "event" => "merge_group", "status" => "completed", "conclusion" => "failure", "head_branch" => "gh-readonly-queue/main/pr-17-head"}

    request = fn
      %{method: :get, url: url} ->
        runs = if String.contains?(url, "status=completed"), do: [run], else: []
        {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}

      %{method: :post, body: %{"query" => query}} ->
        cond do
          query =~ "dequeuePullRequest" -> {:ok, %{status: 200, body: %{"data" => %{"dequeuePullRequest" => %{}}}}}
          query =~ "pullRequest(number:" -> {:ok, %{status: 200, body: %{"data" => %{"repository" => %{"pr_0" => observation_raw()}}}}}
          true -> flunk("unexpected GraphQL request: #{query}")
        end
    end

    observation = %{
      number: 17,
      base: "main",
      head: "head-17",
      node_id: "PR_17",
      draft?: false,
      review_decision: "APPROVED",
      auto_merge_request: nil,
      mergeable: "MERGEABLE",
      merge_state_status: "CLEAN",
      merge_queue_entry: %{"id" => "entry-17", "state" => "UNMERGEABLE", "pullRequest" => %{"headRefOid" => "head-17"}},
      raw: %{}
    }

    assert {:error, :routing_fixture_failure} =
             Aiur.LandingWatch.LandingReconciliation.process(
               [observation],
               [
                 journal_path: temp_journal(),
                 token: "test-gh-token",
                 base_branch: "main",
                 request_fun: request,
                 live_observations_fun: fn observations, _ -> {:ok, observations} end,
                 jobs_fun: fn _, _ -> {:error, :routing_fixture_failure} end,
                 merge_queue_watchdog_fun: fn _, opts ->
                   send(self(), {:watchdog_evidence, opts[:completed_merge_group_runs], opts[:all_observations]})
                   :ok
                 end
               ],
               fn _, _ -> :ok end
             )

    assert_received {:watchdog_evidence, [^run], [^observation]}
  end

  defp observation(number, overrides \\ %{}) do
    Map.merge(
      %{
        number: number,
        head: "head-#{number}",
        node_id: "PR_#{number}",
        draft?: false,
        review_decision: "APPROVED",
        auto_merge_request: nil,
        mergeable: "MERGEABLE",
        merge_state_status: "CLEAN",
        merge_queue_entry: %{"id" => "entry-#{number}", "state" => "UNMERGEABLE"}
      },
      Map.new(overrides)
    )
  end

  defp temp_journal do
    path =
      Path.join(
        System.tmp_dir!(),
        "merge-queue-watchdog-#{System.unique_integer([:positive])}.json"
      )

    on_exit(fn -> Aiur.TestCleanup.rm_rf!(path) end)
    path
  end

  defp check_opts(parent, number, overrides \\ []) do
    head = "head-#{number}"

    base_opts = [
      head_failure_fun: fn _, _ ->
        {:ok, %{classification: :inherited, failing_tests: ["test/aiur/example_test.exs:42"], rebuilt_groups: 6}}
      end,
      revalidate_queue_fun: fn _, _ -> :ok end,
      queue_recovery_revalidate_fun: fn ^number, ^head, _ ->
        send(parent, :revalidated)
        :ok
      end,
      request_fun: fn
        %{method: :post, body: %{"query" => query}} ->
          cond do
            query =~ "dequeuePullRequest" ->
              send(parent, :dequeued)
              {:ok, %{status: 200, body: %{"data" => %{"dequeuePullRequest" => %{}}}}}

            query =~ "enqueuePullRequest" ->
              {:ok,
               %{
                 status: 200,
                 body: %{
                   "data" => %{
                     "enqueuePullRequest" => %{
                       "mergeQueueEntry" => %{
                         "id" => "new",
                         "pullRequest" => %{
                           "id" => "PR_#{number}",
                           "headRefOid" => "head-#{number}"
                         }
                       }
                     }
                   }
                 }
               }}
          end
      end,
      alert_emitter: fn topic, attrs ->
        send(parent, {:attention, topic, attrs})
        :ok
      end
    ]

    Keyword.merge(base_opts, overrides)
  end

  test "waits twenty minutes, then repairs once and reports failing tests and rebuilt groups" do
    path = temp_journal()
    parent = self()
    observation = observation(47)
    opts = [journal_path: path, token: "test-gh-token"] ++ check_opts(parent, 47)

    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_000))
    refute_received :dequeued

    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 301_000))
    refute_received :dequeued

    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_201_000))
    assert_received :dequeued
    assert_received :revalidated

    assert_received {:attention, "system.pr.landing.merge_queue_recovered", attrs}
    assert attrs[:message] =~ "UNMERGEABLE for over 20 minutes"
    assert attrs[:message] =~ "test/aiur/example_test.exs:42"
    assert attrs[:message] =~ "containing this PR: 6"
    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 2_401_000))
    refute_received :dequeued
  end

  test "does not requeue a failure selected by the PR diff" do
    path = temp_journal()
    observation = observation(48)

    opts = [
      journal_path: path,
      head_failure_fun: fn _, _ ->
        {:ok, %{classification: :pr_caused, failing_tests: ["test/aiur/changed_test.exs:9"]}}
      end,
      request_fun: fn _ -> flunk("a PR-caused failure must not be dequeued or enqueued") end
    ]

    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_000))
    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_201_000))
    refute_received :dequeued
  end

  test "does not consume the repair attempt when revalidation fails" do
    path = temp_journal()
    parent = self()
    observation = observation(49)
    attempts = Agent.start_link(fn -> 0 end) |> elem(1)

    opts =
      [journal_path: path, token: "test-gh-token"] ++
        check_opts(parent, 49,
          revalidate_queue_fun: fn _, _ ->
            count = Agent.get_and_update(attempts, &{&1, &1 + 1})
            if count == 0, do: {:error, :transient_read_failure}, else: :ok
          end
        )

    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_000))

    assert {:error, :transient_read_failure} =
             MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_201_000))

    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_202_000))
    assert_received :dequeued
  end

  test "uses merge-group failure evidence and counts earlier runs containing the head" do
    path = temp_journal()
    parent = self()
    observation = observation(55)

    failed_run = %{
      "id" => 900,
      "event" => "merge_group",
      "conclusion" => "failure",
      "head_branch" => "gh-readonly-queue/main/pr-55-head",
      "created_at" => "2026-10-21T12:20:00Z"
    }

    earlier_group = %{
      "id" => 899,
      "event" => "merge_group",
      "head_branch" => "gh-readonly-queue/main/pr-55-head-pr-61-next",
      "created_at" => "2026-10-21T12:19:00Z"
    }

    opts =
      [journal_path: path, token: "test-gh-token"] ++
        check_opts(parent, 55,
          jobs_fun: fn 900, _ -> {:ok, [%{"id" => 901, "name" => "test", "conclusion" => "failure"}]} end,
          completed_merge_group_runs: [earlier_group, failed_run],
          all_observations: [observation],
          base_branch: "main",
          failure_classifier_options_fun: fn _, _, _, _ ->
            [
              job_log_fun: fn _, _ -> {:ok, "mix test test/aiur/flaky_test.exs:17 known flaky failure"} end,
              changed_paths_fun: fn _, _ -> {:ok, []} end,
              changed_paths_by_pr: %{55 => []},
              failed_on_main_fun: fn path, _ -> path == "test/aiur/flaky_test.exs" end,
              known_failure_patterns: []
            ]
          end
        )

    opts = Keyword.delete(opts, :head_failure_fun)
    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_000))
    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_201_000))
    assert_received :dequeued
    assert_received {:attention, "system.pr.landing.merge_queue_recovered", attrs}
    assert attrs[:message] =~ "test/aiur/flaky_test.exs"
    assert attrs[:message] =~ "containing this PR: 1"
  end

  test "ignores failed merge-group runs from before the current unmergeable period" do
    path = temp_journal()
    observation = observation(56)

    old_run = %{
      "id" => 910,
      "event" => "merge_group",
      "conclusion" => "failure",
      "head_branch" => "gh-readonly-queue/main/pr-56-head",
      "created_at" => "2026-10-21T12:00:00Z"
    }

    opts = [
      journal_path: path,
      completed_merge_group_runs: [old_run],
      request_fun: fn _ -> flunk("stale evidence must not authorize recovery") end
    ]

    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_000))
    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_201_000))
    refute_received :dequeued
  end

  test "does not dequeue if the fresh queue read shows the entry became mergeable" do
    path = temp_journal()
    parent = self()
    observation = observation(50)

    opts =
      [journal_path: path, token: "test-gh-token"] ++
        check_opts(parent, 50, revalidate_queue_fun: fn _, _ -> {:skip, :queue_recovery_precondition_changed} end)

    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_000))
    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_201_000))
    refute_received :dequeued
  end

  test "does not dequeue when the real fresh read shows the entry became mergeable" do
    path = temp_journal()
    parent = self()
    observation = observation(54)

    opts =
      [journal_path: path, token: "test-gh-token"] ++
        check_opts(parent, 54,
          request_fun: fn
            %{method: :post, body: %{"query" => query}} = call ->
              cond do
                query =~ "mergeQueueEntry{id state}" ->
                  send(parent, :fresh_queue_read)

                  {:ok,
                   %{
                     status: 200,
                     body: %{
                       "data" => %{
                         "repository" => %{
                           "pullRequest" => %{
                             "id" => "PR_54",
                             "headRefOid" => "head-54",
                             "isDraft" => false,
                             "reviewDecision" => "APPROVED",
                             "mergeable" => "MERGEABLE",
                             "mergeStateStatus" => "CLEAN",
                             "autoMergeRequest" => nil,
                             "mergeQueueEntry" => %{"id" => "entry-54", "state" => "MERGEABLE"},
                             "reviews" => %{"nodes" => [%{"commit" => %{"oid" => "head-54"}}]}
                           }
                         }
                       }
                     }
                   }}

                query =~ "dequeuePullRequest" ->
                  flunk("a changed queue entry must prevent dequeue")

                true ->
                  flunk("unexpected GraphQL request: #{inspect(call)}")
              end
          end
        )

    opts = opts |> Keyword.delete(:revalidate_queue_fun) |> Keyword.delete(:queue_recovery_revalidate_fun)

    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_000))
    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_201_000))

    assert_received :fresh_queue_read
    refute_received :dequeued
  end

  test "malformed live PR revalidation returns an error instead of crashing the poll" do
    path = temp_journal()
    parent = self()
    observation = observation(53)

    opts =
      [journal_path: path, token: "test-gh-token"] ++
        check_opts(parent, 53,
          request_fun: fn
            %{body: %{"query" => query}} = call ->
              cond do
                query =~ "mergeQueueEntry{id state}" ->
                  {:ok,
                   %{
                     status: 200,
                     body: %{
                       "data" => %{
                         "repository" => %{
                           "pullRequest" => %{
                             "id" => "PR_53",
                             "headRefOid" => "head-53",
                             "isDraft" => false,
                             "reviewDecision" => "APPROVED",
                             "mergeable" => "MERGEABLE",
                             "mergeStateStatus" => "CLEAN",
                             "autoMergeRequest" => nil,
                             "mergeQueueEntry" => %{"id" => "entry-53", "state" => "UNMERGEABLE"},
                             "reviews" => %{"nodes" => [%{"commit" => %{"oid" => "head-53"}}]}
                           }
                         }
                       }
                     }
                   }}

                query =~ "mergeQueueEntry{id}" ->
                  {:ok, %{status: 200, body: %{"data" => %{"repository" => %{}}}}}

                Map.get(call, :method) == :post and query =~ "dequeuePullRequest" ->
                  {:ok, %{status: 200, body: %{"data" => %{"dequeuePullRequest" => %{}}}}}
              end
          end
        )

    opts = Keyword.delete(opts, :queue_recovery_revalidate_fun)

    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_000))

    assert {:error, :invalid_queue_recovery_revalidation} =
             MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_201_000))
  end

  for state <- ["AWAITING_CHECKS", "MERGEABLE", "LOCKED"] do
    test "does not touch queue entries in #{state}" do
      path = temp_journal()
      parent = self()

      observation =
        observation(51, merge_queue_entry: %{"id" => "entry-51", "state" => unquote(state)})

      opts =
        [journal_path: path] ++
          check_opts(parent, 51, request_fun: fn _ -> flunk("#{unquote(state)} entries must not be mutated") end)

      assert :ok =
               MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1_000))

      assert :ok =
               MergeQueueWatchdog.reconcile(
                 [observation],
                 Keyword.put(opts, :now_ms, 1_201_000)
               )

      refute_received :dequeued
      refute_received :revalidated
    end
  end

  test "stops after one repair attempt and emits one give-up attention" do
    path = temp_journal()
    parent = self()
    observation = observation(52)
    opts = [journal_path: path, token: "test-gh-token"] ++ check_opts(parent, 52)

    for now <- [1_000, 1_201_000, 2_401_000, 3_601_000] do
      assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, now))
    end

    assert_received :dequeued
    refute_received :dequeued
    assert_received {:attention, "system.pr.landing.merge_queue_recovered", _}
    refute_received {:attention, "system.pr.landing.merge_queue_recovered", _}

    assert_received {:attention, "system.pr.landing.merge_queue_recovery_gave_up", attrs}
    assert attrs[:reason] == "merge_queue_recovery_attempt_limit"

    refute_received {:attention, "system.pr.landing.merge_queue_recovery_gave_up", _}
  end

  test "does not requeue a conflicting PR even after the watchdog interval" do
    observation = observation(49, mergeable: "CONFLICTING")
    path = temp_journal()

    assert :ok = MergeQueueWatchdog.reconcile([observation], journal_path: path, now_ms: 1_000)

    assert :ok =
             MergeQueueWatchdog.reconcile([observation],
               journal_path: path,
               now_ms: 301_000,
               request_fun: fn _ ->
                 flunk("conflicting PRs must never be dequeued or enqueued")
               end
             )
  end
end
