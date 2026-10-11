defmodule Aiur.MainWatch.CanaryTest do
  use ExUnit.Case, async: true
  alias Aiur.MainWatch.Canary

  test "stale canary reruns newest cancelled run or requests attention" do
    runs = [%{id: 3, status: "completed", conclusion: "success", attempt: 1}, %{id: 2, status: "completed", conclusion: "cancelled", attempt: 1}]
    assert {:rerun, 2} = Canary.decide(0, runs, 45, true, 46 * 60_000)
    assert {:attention, :actions_write_unavailable} = Canary.decide(0, runs, 45, false, 46 * 60_000)
    assert {:attention, :no_cancelled_run} = Canary.decide(0, [], 45, true, 46 * 60_000)
  end

  test "disabled, fresh and active rerun canaries do nothing" do
    runs = [%{id: 2, status: "in_progress", conclusion: nil, attempt: 2}]
    assert :noop = Canary.decide(0, [], 0, true, 46 * 60_000)
    assert :noop = Canary.decide(0, [], 45, true, 44 * 60_000)
    assert :noop = Canary.decide(0, runs, 45, true, 46 * 60_000)
  end
end
