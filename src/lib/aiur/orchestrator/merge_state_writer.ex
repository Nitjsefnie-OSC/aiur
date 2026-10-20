defmodule Aiur.Orchestrator.MergeStateWriter do
  @moduledoc false

  alias Aiur.{Issue, Tracker}
  alias Aiur.Orchestrator.TicketTransition

  @operator_hold_labels ["needs-triage", "human:todo", "agent:paused", "agent:parked"]

  @spec write_if_current(String.t(), String.t()) :: :ok | {:error, term()}
  def write_if_current(identifier, target) do
    case Tracker.fetch_issue_states_by_ids([to_string(identifier)]) do
      {:ok, [%Issue{state: state}]} when is_binary(state) ->
        TicketTransition.write_state(identifier, target,
          writer: :comment_wake,
          expected_state: state,
          refuse_labels: @operator_hold_labels
        )

      {:ok, _} ->
        {:error, :merge_issue_state_unavailable}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
