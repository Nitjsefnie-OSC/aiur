defmodule AiurWeb.OperatorControlCenter.Analytics.LiveConcurrencyTest do
  use ExUnit.Case, async: true

  alias AiurWeb.OperatorControlCenter.Analytics.LiveConcurrency

  test "counts adopted running entries and excludes paused entries" do
    running = [%{work_state: :working, adopted_from: "prior boot"} | Enum.map(1..10, &%{work_state: :working, adopted_from: "prior boot #{&1}"})]

    assert LiveConcurrency.count(running) == 11
    assert LiveConcurrency.count([%{work_state: :working}, %{work_state: :paused}]) == 1
  end

  test "live count keeps stale sample age visible and retained models say run end" do
    model = %{live_concurrency: 11, live_concurrency_staleness: {:stale, 600_000}, kpis: %{conc_now: 2}}

    assert LiveConcurrency.label(model, true) == "11 now (sample 10m old)"
    assert LiveConcurrency.label(model, false) == "2 at run end"
  end
end
