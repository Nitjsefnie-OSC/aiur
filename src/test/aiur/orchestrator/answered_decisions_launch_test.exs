defmodule Aiur.Orchestrator.AnsweredDecisionsLaunchTest do
  use Aiur.TestSupport

  alias Aiur.{DecisionStore, Issue}
  alias Aiur.Orchestrator.{Dispatcher, State, TrackerTasks}

  test "the next dispatch puts the durable answer in runner launch options", %{test: test} do
    parent = self()
    dir = Aiur.TestSupport.tmp_root!("answered-decisions-launch")
    on_exit(fn -> Aiur.TestCleanup.rm_rf!(dir) end)

    store =
      start_supervised!(
        {DecisionStore,
         name: nil,
         state_dir: dir,
         filesystem_sync_fun: fn -> :ok end,
         dispatch_delay_ms: 0,
         retry_delays_ms: [],
         dispatcher: fn _decision, _opts -> {:error, :no_running_agent} end,
         answer_comment_publisher: fn _decision -> :ok end}
      )

    ticket = %{identifier: "5491", title: "Carry decisions", url: nil}
    source = %{agent_id: "agent-5491", session_id: "session-before", event_id: nil}

    assert {:ok, %{decision: decision}} =
             DecisionStore.request(
               %{
                 "question" => "Which rollout?",
                 "blocking" => true,
                 "source_id" => "launch-#{test}",
                 "options" => [%{"id" => "ship", "label" => "Ship it"}]
               },
               [ticket: ticket, source: source],
               store
             )

    accepted_at = DateTime.from_naive!(~N[2026-10-20 18:02:03], "Etc/UTC")

    assert {:ok, _answer} =
             DecisionStore.answer(
               decision.decision_id,
               %{"idempotency_key" => "launch-answer", "expected_version" => 1, "custom_response" => "Proceed verbatim"},
               [actor: %{kind: :operator, id: "operator-1"}, now: accepted_at],
               store
             )

    pending = wait_for_decision(store, decision.decision_id, & &1.pending_for_session?)
    issue = %Issue{id: "5491", identifier: "5491", title: "Carry decisions", state: "todo", selected_backend: "codex"}

    state =
      Dispatcher.dispatch_issue(
        %State{snapshot_key: self(), max_concurrent_agents: 4, effective_concurrent_agents: 4},
        issue,
        nil,
        nil,
        decision_store: store,
        issue_fetcher: fn _ids -> {:ok, [issue]} end,
        blocked_by_hydrator: fn candidate -> {:ok, candidate} end,
        runner: fn _dispatched, _recipient, opts -> send(parent, {:runner_options, opts}) end
      )
      |> apply_dispatch_result()

    assert_receive {:runner_options, opts}, 1_000
    assert [%{action_id: action_id, question: "Which rollout?", answer: "Proceed verbatim", actor: "operator: operator-1", accepted_at: ^accepted_at}] = opts[:answered_decisions]
    assert action_id == pending.active_action_id
    refute wait_for_decision(store, decision.decision_id, &(!&1.pending_for_session?)).pending_for_session?
    assert Map.has_key?(state.running, issue.id)
  end

  defp apply_dispatch_result(%State{} = state) do
    receive do
      {reference, result} when is_reference(reference) ->
        {:handled, dispatched} = TrackerTasks.result(state, reference, result)
        dispatched
    after
      1_000 -> flunk("dispatch validation did not finish")
    end
  end

  defp wait_for_decision(store, decision_id, predicate, attempts \\ 100)
  defp wait_for_decision(_store, _decision_id, _predicate, 0), do: flunk("decision did not reach expected state")

  defp wait_for_decision(store, decision_id, predicate, attempts) do
    {:ok, decision} = DecisionStore.get(decision_id, store)

    if predicate.(decision) do
      decision
    else
      Process.sleep(10)
      wait_for_decision(store, decision_id, predicate, attempts - 1)
    end
  end
end
