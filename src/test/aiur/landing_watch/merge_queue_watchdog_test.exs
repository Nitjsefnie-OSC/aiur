defmodule Aiur.LandingWatch.MergeQueueWatchdogTest do
  use ExUnit.Case, async: true

  alias Aiur.LandingWatch.{Journal, MergeQueueWatchdog}

  test "requeues a persistent unmergeable entry only after five minutes with passing PR checks" do
    path = Path.join(System.tmp_dir!(), "merge-queue-watchdog-#{System.unique_integer([:positive])}.json")
    on_exit(fn -> Aiur.TestCleanup.rm_rf!(path) end)
    parent = self()

    observation = %{
      number: 47,
      head: "head-47",
      node_id: "PR_47",
      draft?: false,
      review_decision: "APPROVED",
      auto_merge_request: nil,
      mergeable: "MERGEABLE",
      merge_state_status: "CLEAN",
      merge_queue_entry: %{"id" => "entry-47", "state" => "UNMERGEABLE"}
    }

    opts = [
      journal_path: path,
      token: "test-gh-token",
      required_checks_fun: fn _ -> {:ok, [%{name: "ci"}]} end,
      ci_status_fun: fn "head-47", _ -> {:ok, %{check_runs: [%{"name" => "ci", "conclusion" => "success"}], commit_status: %{"state" => "success"}}} end,
      revalidate_queue_fun: fn _, _ -> :ok end,
      revalidate_fun: fn 47, "head-47", _ ->
        send(parent, :revalidated)
        :ok
      end,
      request_fun: fn
        %{method: :post, body: %{"query" => query}} when is_binary(query) ->
          cond do
            query =~ "dequeuePullRequest" ->
              send(parent, :dequeued)
              {:ok, %{status: 200, body: %{"data" => %{"dequeuePullRequest" => %{}}}}}

            query =~ "enqueuePullRequest" ->
              {:ok, %{status: 200, body: %{"data" => %{"enqueuePullRequest" => %{"mergeQueueEntry" => %{"id" => "new-entry", "pullRequest" => %{"id" => "PR_47", "headRefOid" => "head-47"}}}}}}}
          end
      end,
      alert_emitter: fn topic, _ ->
        send(parent, {:attention, topic})
        :ok
      end
    ]

    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1000))
    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 301_000))
    assert_received :dequeued
    assert_received :revalidated
    assert_received {:attention, "system.pr.landing.merge_queue_recovered"}
    assert {:ok, state} = Journal.state(opts)
    refute Map.has_key?(state["unmergeable_queue_entries"], "47:head-47")
  end

  test "does not dequeue when the PR's own required check failed" do
    path = Path.join(System.tmp_dir!(), "merge-queue-watchdog-failed-#{System.unique_integer([:positive])}.json")
    on_exit(fn -> Aiur.TestCleanup.rm_rf!(path) end)

    observation = %{
      number: 48,
      head: "head-48",
      mergeable: "MERGEABLE",
      merge_state_status: "CLEAN",
      merge_queue_entry: %{"id" => "entry-48", "state" => "UNMERGEABLE"}
    }

    opts = [
      journal_path: path,
      now_ms: 301_000,
      request_fun: fn _ -> flunk("a failed PR check must prevent any queue mutation") end,
      required_checks_fun: fn _ -> {:ok, [%{name: "ci"}]} end,
      ci_status_fun: fn _, _ -> {:ok, %{check_runs: [%{"name" => "ci", "conclusion" => "failure"}], commit_status: %{"state" => "failure"}}} end
    ]

    assert :ok = MergeQueueWatchdog.reconcile([observation], Keyword.put(opts, :now_ms, 1000))
    assert :ok = MergeQueueWatchdog.reconcile([observation], opts)
  end

  test "does not requeue a conflicting PR even after the watchdog interval" do
    path = Path.join(System.tmp_dir!(), "merge-queue-watchdog-conflict-#{System.unique_integer([:positive])}.json")
    on_exit(fn -> Aiur.TestCleanup.rm_rf!(path) end)

    observation = %{
      number: 49,
      head: "head-49",
      mergeable: "CONFLICTING",
      merge_state_status: "CLEAN",
      merge_queue_entry: %{"id" => "entry-49", "state" => "UNMERGEABLE"}
    }

    assert :ok = MergeQueueWatchdog.reconcile([observation], journal_path: path, now_ms: 1000)

    assert :ok =
             MergeQueueWatchdog.reconcile(
               [observation],
               journal_path: path,
               now_ms: 301_000,
               request_fun: fn _ -> flunk("conflicting PRs must never be dequeued or enqueued") end
             )
  end
end
