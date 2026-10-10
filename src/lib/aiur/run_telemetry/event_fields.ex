defmodule Aiur.RunTelemetry.EventFields do
  @moduledoc """
  Metadata the dataset reducer carries from the daemon-side metric events
  (`state_change`, `ci_result`, `pr_ready`, `dependency_cleared`, `ticket_usage`).

  `analytics/lib/analytics/event_fields.py` carries the same list (`EVENT_FIELDS`).
  """

  @fields ~w(from_state to_state blocker head_sha pr_number input_tokens output_tokens cached_tokens cost_amount cost_currency coverage)a

  @spec take(map()) :: %{atom() => term()}
  def take(attributes), do: Map.new(@fields, &{&1, Map.get(attributes, Atom.to_string(&1))})

  @spec resource_evidence() :: [atom()]
  def resource_evidence, do: ~w(
    fleet_capacity_status fleet_capacity_age_ms fleet_capacity_observed_at_ms
    fleet_admission_signal fleet_binding_kind
    build_gate_enabled build_gate_status build_gate_observed_at_ms
  )a
end
