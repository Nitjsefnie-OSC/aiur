defmodule Aiur.Orchestrator.AgentTeardownTest do
  use Aiur.TestSupport

  alias Aiur.GitHub.Labels
  alias Aiur.{Issue, Tracker, Workflow}
  alias Aiur.Orchestrator.{AgentTeardown, State}

  test "teardown helpers tolerate absent process identifiers" do
    assert AgentTeardown.terminate_task(nil) == :ok
  end

  test "terminal teardown clears transient reason labels and preserves blocked" do
    write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "memory")
    labels = Labels.reason_modifier_labels("agent")
    Application.put_env(:aiur, :memory_tracker_issues, [%Issue{id: "7", identifier: "7", state: "done", labels: labels}])

    assert %State{} = AgentTeardown.terminate_running_issue(%State{}, "7", false)
    assert {:ok, [%Issue{labels: ["agent:blocked"]}]} = Tracker.fetch_issue_states_by_ids(["7"])
  end
end
