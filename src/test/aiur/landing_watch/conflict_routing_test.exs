defmodule Aiur.LandingWatch.ConflictRoutingTest do
  use ExUnit.Case, async: true

  alias Aiur.LandingWatch

  @green %{"id" => 60, "name" => "ci gate", "status" => "completed", "conclusion" => "success", "check_suite" => %{"id" => 101}}

  test "one cycle moves an approved green PR that conflicts with main to rebase-only rework" do
    parent = self()

    assert :ok = LandingWatch.poll(cycle_opts(parent, conflicting(nil), "human-review"))

    refute_received {:withdraw, _}
    assert_received {:transition, "17", "rework", [writer: :landing_watch, expected_state: "human-review"]}
    assert_received {:comment, "17", body}
    assert body =~ "Rebase only"
    assert body =~ "conflicts with `main`"
    assert body =~ "Make no other change"
    assert body =~ "approval at `head-sha`"
    assert_received {:remove_label, "17", "agent:paused"}
    refute_received {:enqueued, _}
  end

  test "a conflicting merge queue entry is dequeued before its ticket is routed the same way" do
    parent = self()

    assert :ok = LandingWatch.poll(cycle_opts(parent, conflicting(%{"id" => "MQE_1"}), "merging"))

    assert {:messages, [{:withdraw, 17}, {:transition, "17", "rework", _}, {:comment, "17", body}, {:remove_label, "17", "agent:paused"}]} =
             Process.info(self(), :messages)

    assert body =~ "Rebase only"
  end

  test "a failed dequeue leaves the ticket alone so the next cycle retries" do
    parent = self()
    opts = Keyword.put(cycle_opts(parent, conflicting(%{"id" => "MQE_1"}), "merging"), :withdraw_fun, fn _ -> {:error, :boom, []} end)

    assert {:error, {:conflict_withdrawal_failed, :boom}} = LandingWatch.poll(opts)
    refute_received {:transition, _, _, _}
    refute_received {:comment, _, _}
  end

  test "a ticket already in rework is not commented again" do
    parent = self()

    assert :ok = LandingWatch.poll(cycle_opts(parent, conflicting(nil), "rework"))

    refute_received {:transition, _, _, _}
    refute_received {:comment, _, _}
    refute_received {:enqueued, _}
  end

  defp cycle_opts(parent, observation, ticket_state) do
    [
      observe_fun: fn _ -> {:ok, [observation]} end,
      journal_prune_fun: fn _, _ -> :ok end,
      queue_reconcile_fun: fn _, _ -> :ok end,
      approved_fun: fn _, _ -> {:ok, true} end,
      required_checks_fun: fn _ -> {:ok, [%{name: "ci gate", app_id: nil}]} end,
      ci_status_fun: fn _, _ -> {:ok, %{check_runs: [@green], commit_status: %{"state" => "success", "statuses" => []}}} end,
      revalidate_fun: fn _, _, _ -> :ok end,
      attribution_fun: fn _ -> {:ok, :clean} end,
      enqueue_fun: fn pr ->
        send(parent, {:enqueued, pr.head})
        {:ok, "entry-1"}
      end,
      ticket_state_fun: fn "17", _ -> {:ok, ticket_state} end,
      withdraw_fun: fn number ->
        send(parent, {:withdraw, number})
        {:ok, [:dequeued]}
      end,
      transition_fun: fn id, target, options ->
        send(parent, {:transition, id, target, options})
        :ok
      end,
      comment_fun: fn id, body ->
        send(parent, {:comment, id, body})
        :ok
      end,
      remove_label_fun: fn id, label ->
        send(parent, {:remove_label, id, label})
        :ok
      end,
      pause_label: "agent:paused",
      alert_emitter: fn _, _ -> :ok end
    ]
  end

  defp conflicting(entry) do
    %{
      number: 17,
      node_id: "PR_node",
      head: "head-sha",
      base: "main",
      draft?: false,
      review_decision: "APPROVED",
      mergeable: "CONFLICTING",
      merge_state_status: "DIRTY",
      merge_queue_entry: entry,
      auto_merge_request: nil,
      rest: %{"head" => %{"ref" => "aiur/17-work"}},
      raw: %{"reviewDecision" => "APPROVED", "headRefOid" => "head-sha", "isDraft" => false, "reviews" => %{"nodes" => [%{"commit" => %{"oid" => "head-sha"}}]}}
    }
  end
end
