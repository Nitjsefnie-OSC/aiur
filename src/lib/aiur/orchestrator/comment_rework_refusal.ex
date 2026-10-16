defmodule Aiur.Orchestrator.CommentReworkRefusal do
  @moduledoc false

  alias Aiur.Alerts

  @spec emit(String.t() | integer(), map(), term()) :: :ok | term()
  def emit(issue_number, event, reason) do
    emit_alert_fun =
      case Map.get(event, :emit_alert_fun) do
        fun when is_function(fun, 2) -> fun
        _ -> &Alerts.emit_system/2
      end

    identifier = to_string(issue_number)

    emit_alert_fun.(
      "ticket.#{identifier}.agent.attention.review_rework_refused",
      issue: identifier,
      message:
        "Ticket #{identifier} received a CHANGES_REQUESTED review but was not moved to rework " <>
          "(#{inspect(reason)}); it is still sitting in its review state.",
      reason:
        "The rework gate refused the transition for a live changes-requested review, and a review " <>
          "submission is delivered only once, so nothing re-derives it. Remedy: move the ticket to " <>
          "rework or re-review it after addressing the gate condition.",
      needs_attention: true,
      severity: "warning",
      central: true
    )
  end
end
