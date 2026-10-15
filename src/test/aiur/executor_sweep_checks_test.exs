defmodule Aiur.ExecutorSweep.ChecksTest do
  use ExUnit.Case, async: true

  alias Aiur.ExecutorSweep.Checks

  test "puts the 23-hour unreviewed PR first and includes age" do
    now = ~U[2026-10-15 18:20:00Z]

    snapshot = %{
      tickets: [%{number: 4429, labels: ["agent:human-review"]}],
      pull_requests: [
        %{number: 4447, issue_number: 4429, state: "open", draft: false, head_sha: "abc", reviewed_head_sha: nil, ready_at: ~U[2026-10-14 19:08:00Z]}
      ]
    }

    assert [finding] = Checks.unreviewed_prs(snapshot, now, 10)
    assert finding.kind == "unreviewed_human_review_pr"
    assert finding.priority == 1
    assert finding.age_ms == 23 * 60 * 60 * 1_000 + 12 * 60 * 1_000
    assert finding.message =~ "23h 12m"
  end

  test "requires a review on the current head and a strict threshold exceedance" do
    now = ~U[2026-10-15 18:20:00Z]
    ticket = %{number: 4, labels: ["agent:human-review"]}
    base = %{number: 5, issue_number: 4, state: "open", draft: false, head_sha: "new", reviewed_head_sha: nil, ready_at: ~U[2026-10-15 18:10:00Z]}
    snapshot = %{tickets: [ticket], pull_requests: [base]}
    assert [] = Checks.unreviewed_prs(snapshot, now, 10)
    assert [finding] = Checks.unreviewed_prs(%{snapshot | pull_requests: [%{base | ready_at: ~U[2026-10-15 18:09:59Z]}]}, now, 10)
    assert finding.age_ms == 10 * 60 * 1_000 + 1_000

    assert [] = Checks.unreviewed_prs(%{snapshot | pull_requests: [%{base | reviewed_head_sha: "new"}]}, now, 1)
  end
end
