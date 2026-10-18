defmodule Aiur.GitHub.LabelsExecutorOwnerTest do
  use ExUnit.Case, async: true

  alias Aiur.GitHub.Labels

  test "owner marker is seeded and recognized as a marker rather than a state" do
    labels = Labels.label_set("agent", ["codex"])

    assert "agent:executor" in labels
    refute "agent:executor" in Labels.state_labels("agent")
    assert Labels.executor_label_prefix("agent") == "agent:executor:"
    assert Labels.marker_suffix?("executor:codex")
    refute Labels.marker_suffix?("executorfake")
    refute Labels.marker_suffix?("agent:executor:codex")
    assert Labels.describe("agent:executor:codex") == "Executor-owned by codex: no dispatch, no fleet slot"
  end
end
