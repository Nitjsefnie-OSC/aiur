defmodule Aiur.MergePolicyCLIMainWatchTest do
  use ExUnit.Case, async: true

  test "red status includes observed time and fixer" do
    time = DateTime.to_unix(~U[2026-10-09 14:02:00Z], :millisecond)
    assert Aiur.MergePolicyCLI.main_state(%{status: :red, red_since: time, fixer_ticket: 4100}) == "main=red since 14:02 (#4100)"
  end

  test "unknown cannot claim green and missing red time stays unavailable" do
    assert Aiur.MergePolicyCLI.main_state(%{status: :unknown}) == "main=unknown"
    assert Aiur.MergePolicyCLI.main_state(%{status: :green}) == "main=green"
    assert Aiur.MergePolicyCLI.main_state(%{status: :green, unavailable: true}) == "main=green (unavailable)"
    assert Aiur.MergePolicyCLI.main_state(%{status: :red, red_since: nil}) == "main=red"
  end

  test "main CI events and canary wake the Executor" do
    for topic <- ["system.main.ci.failed", "system.main.ci.failed.resolved", "system.main.ci.flaked", "system.main.ci.canary", "system.main.ci.unavailable"] do
      assert topic in Aiur.ExecutorBindings.patterns()
    end
  end
end
