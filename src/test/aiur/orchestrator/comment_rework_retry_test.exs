defmodule Aiur.Orchestrator.CommentReworkRetryTest do
  use ExUnit.Case, async: true

  alias Aiur.Orchestrator.CommentReworkRetry

  test "broker timeouts keep retrying past the ordinary comment retry limit" do
    assert CommentReworkRetry.limit_reached?(5, :something_new, 5)
    refute CommentReworkRetry.limit_reached?(5, :github_budget_broker_timeout, 5)
    refute CommentReworkRetry.limit_reached?(50, {:github, :local_hold, %{reason: :github_budget_broker_timeout}}, 5)
    assert CommentReworkRetry.attempt_label(6, :github_budget_broker_timeout, 5) == "6/until success"
  end
end
