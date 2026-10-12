defmodule Aiur.AgentRunner.ReworkHandoff do
  @moduledoc false

  alias Aiur.AgentRunner.TurnLoop
  alias Aiur.Orchestrator.DispatchPolicy

  @spec after_turn(Aiur.Issue.t(), map(), (-> term())) :: term()
  def after_turn(issue, turn_context, continue) do
    if DispatchPolicy.normalize_issue_state(issue.state) == "rework" do
      case TurnLoop.transition_agent_handoff(turn_context, issue) do
        {:handoff, result} -> result
        :none -> continue.()
        {:error, reason} -> {:error, reason}
      end
    else
      continue.()
    end
  end
end
