defmodule Aiur.AgentRunner.ReworkHandoff do
  @moduledoc false

  alias Aiur.AgentRunner.TurnLoop
  alias Aiur.Orchestrator.{DispatchPolicy, ReworkGate}

  @spec after_turn(Aiur.Issue.t(), map(), (-> term())) :: term()
  def after_turn(issue, turn_context, continue) do
    if DispatchPolicy.normalize_issue_state(issue.state) == "rework" do
      maybe_handoff(issue, turn_context, continue)
    else
      continue.()
    end
  end

  defp maybe_handoff(issue, turn_context, continue) do
    opts = Keyword.take(turn_context.opts, [:open_pr_fetcher])

    case ReworkGate.open_pr(issue.identifier, opts) do
      {:ok, pull_request} ->
        case ReworkGate.head_sha(pull_request) do
          head when is_binary(head) and head != "" ->
            baseline = Keyword.get(turn_context.opts, :rework_head_sha)
            maybe_handoff_for_head(turn_context, issue, pull_request, head, baseline, continue)

          _no_head ->
            continue.()
        end

      _unavailable_or_missing ->
        continue.()
    end
  end

  defp maybe_handoff_for_head(_turn_context, _issue, _pull_request, head, head, continue)
       when is_binary(head) and head != "",
       do: continue.()

  defp maybe_handoff_for_head(turn_context, issue, pull_request, _head, _baseline, continue),
    do: handoff(turn_context, issue, pull_request, continue)

  defp handoff(turn_context, issue, pull_request, continue) do
    opts = Keyword.put(turn_context.opts, :open_pr_fetcher, fn _identifier -> {:ok, pull_request} end)

    case TurnLoop.transition_agent_handoff(%{turn_context | opts: opts}, issue) do
      {:handoff, result} -> result
      :none -> continue.()
      {:error, reason} -> {:error, reason}
    end
  end
end
