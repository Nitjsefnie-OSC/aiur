defmodule Aiur.ControlCLI.ExecutorOwnershipTest do
  use Aiur.TestSupport

  import ExUnit.CaptureIO

  alias Aiur.AgentControlCLI

  setup do
    :ok = write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "memory")
    Application.put_env(:aiur, :memory_tracker_issues, [])
    Application.put_env(:aiur, :memory_tracker_recipient, self())
    :ok
  end

  test "take writes the Executor owner marker and release removes only its own marker" do
    issue = %Issue{id: "5077", identifier: "5077", title: "Executor work", state: "todo", labels: []}
    Application.put_env(:aiur, :memory_tracker_issues, [issue])
    previous_owner = System.get_env("AIUR_EXECUTOR_OWNER")
    System.put_env("AIUR_EXECUTOR_OWNER", "codex")

    on_exit(fn ->
      if previous_owner, do: System.put_env("AIUR_EXECUTOR_OWNER", previous_owner), else: System.delete_env("AIUR_EXECUTOR_OWNER")
    end)

    output = capture_io(fn -> AgentControlCLI.take(["5077"]) end)
    assert output =~ "ticket #5077 held by codex"
    assert_received {:memory_tracker_add_label, "5077", "agent:executor:codex"}

    Application.put_env(:aiur, :memory_tracker_issues, [%{issue | labels: ["agent:executor:codex"]}])
    System.put_env("AIUR_EXECUTOR_OWNER", "other")
    refused = capture_io(fn -> capture_io(:stderr, fn -> AgentControlCLI.release(["5077"]) end) end)
    assert refused =~ "owned by another Executor"

    System.put_env("AIUR_EXECUTOR_OWNER", "codex")
    released = capture_io(fn -> AgentControlCLI.release(["5077"]) end)
    assert released =~ "Executor hold released for #5077"
    assert_received {:memory_tracker_remove_label, "5077", "agent:executor:codex"}
  end
end
