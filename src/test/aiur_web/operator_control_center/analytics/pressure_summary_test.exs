defmodule AiurWeb.OperatorControlCenter.Analytics.PressureSummaryTest do
  use ExUnit.Case, async: true

  alias AiurWeb.OperatorControlCenter.Analytics.Presenter

  test "keeps latest occupied count and effective cap in the same current sample" do
    series = [
      %{fleet_capacity_status: "current", fleet_agents_occupied: 15, fleet_agents_effective: 16},
      %{fleet_capacity_status: "empty", fleet_agents_occupied: nil, fleet_agents_effective: nil},
      %{fleet_capacity_status: "current", fleet_agents_occupied: 17, fleet_agents_effective: 20}
    ]

    pressure = Presenter.pressure_summary(series)
    assert pressure.latest_occupied == 17
    assert pressure.latest_effective_capacity == 20

    missing = List.replace_at(series, 2, %{fleet_capacity_status: "current", fleet_agents_occupied: 17, fleet_agents_effective: nil})
    assert Presenter.pressure_summary(missing).latest_effective_capacity == nil
  end
end
