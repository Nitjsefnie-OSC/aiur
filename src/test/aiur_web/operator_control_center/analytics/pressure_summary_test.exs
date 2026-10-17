defmodule AiurWeb.OperatorControlCenter.Analytics.PressureSummaryTest do
  use ExUnit.Case, async: true

  alias AiurWeb.OperatorControlCenter.Analytics.Presenter

  test "keeps the latest effective cap only while its sample is current" do
    series = [
      %{timestamp_ms: 1, fleet_capacity_status: "current", fleet_agents_occupied: 15, fleet_agents_effective: 16},
      %{timestamp_ms: 2, fleet_capacity_status: "current", fleet_agents_occupied: 15, fleet_agents_effective: 16}
    ]

    pressure = Presenter.pressure_summary(series)
    assert pressure.latest_effective_capacity == 16

    unavailable = Enum.map(1..500, fn _ -> %{timestamp_ms: 4, fleet_capacity_status: "unavailable"} end)
    stale = Presenter.pressure_summary([List.first(series) | unavailable])
    assert stale.latest_effective_capacity == nil
  end
end
