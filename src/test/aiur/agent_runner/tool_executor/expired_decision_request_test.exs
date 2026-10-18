defmodule Aiur.AgentRunner.ToolExecutor.ExpiredDecisionRequestTest do
  use ExUnit.Case, async: false

  alias Aiur.AgentRunner.ToolExecutor
  alias Aiur.{DecisionStore, Issue}

  test "an expired blocking request tells the agent how to re-raise it" do
    identifier = "TE-decision-expired-#{System.unique_integer([:positive])}"
    issue = %Issue{identifier: identifier, title: "Test ticket"}
    executor = ToolExecutor.build(issue, nil, nil, %{backend: "codex", thread_id: "thread-expired"})
    payload = %{"blocking" => true}

    first = executor.("emit_event", %{"name" => "decision.requested", "message" => "Deploy now?", "payload" => payload})
    assert first["success"] == true
    decision_id = Jason.decode!(first["output"])["result"]["decision_id"]

    assert {:ok, decision} = DecisionStore.get(decision_id)

    assert {:ok, %{status: :accepted, decision: %{decision_status: :expired}}} =
             DecisionStore.expire(decision_id, "agent_not_running", now: DateTime.add(decision.created_at, 600, :second))

    retry = executor.("emit_event", %{"name" => "decision.requested", "message" => "Deploy now?", "payload" => payload})
    assert retry["success"] == false
    error = Jason.decode!(retry["output"])["error"]

    assert error["message"] ==
             "Decision #{decision_id} expired. Re-raise it with a new source_id; a matching request will supersede this stale blocker."

    assert error["reason"] == "expired_decision_requires_reraise"
  end
end
