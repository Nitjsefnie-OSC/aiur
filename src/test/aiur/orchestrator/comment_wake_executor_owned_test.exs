defmodule Aiur.Orchestrator.CommentWakeExecutorOwnedTest do
  use ExUnit.Case, async: true

  alias Aiur.Issue
  alias Aiur.Orchestrator.{CommentWake, State}

  test "trusted comments do not route an Executor-held ticket to rework" do
    state = %State{running: %{}, completed: MapSet.new(), claimed: MapSet.new(), retry_attempts: %{}}

    issue = %Issue{
      id: "5077",
      identifier: "5077",
      state: "human-review",
      labels: ["agent:human-review"],
      executor_owner: "codex"
    }

    event = %{
      author_trusted?: true,
      comment: %{"body" => "please fix"},
      issue_state_fetcher: fn _ids -> {:ok, [issue]} end,
      open_pr_fetcher: fn _issue_key -> {:ok, %{"number" => 42, "head" => %{"sha" => "abc123"}}} end,
      unresolved_threads_fetcher: fn _pr -> {:ok, [%{"id" => "thread-1"}]} end
    }

    assert CommentWake.maybe_transition_idle_issue_to_rework(
             state,
             "5077",
             "issue comment",
             event,
             1
           ) == state

    refute_received {:state_write, _, _, _}
  end
end
