defmodule Aiur.Orchestrator.Reconciler.NonterminalExecutorOwnedTest do
  use ExUnit.Case, async: true

  alias Aiur.Issue
  alias Aiur.Orchestrator.Reconciler.Nonterminal
  alias Aiur.Orchestrator.State

  test "taking a running issue terminates its fleet worker" do
    issue = %Issue{
      id: "5077",
      identifier: "owner/repo#5077",
      state: "in-progress",
      executor_owner: "codex"
    }

    running = %{issue.id => %{issue: issue, control: %{status: :working}}}
    state = %State{running: running}

    assert {^state, [{:terminate, "5077", false}]} =
             Nonterminal.reconcile_nonterminal_issue_state(
               state,
               issue,
               MapSet.new(["todo", "in-progress"]),
               MapSet.new(["done"]),
               fn _, _ -> :ok end
             )
  end
end
