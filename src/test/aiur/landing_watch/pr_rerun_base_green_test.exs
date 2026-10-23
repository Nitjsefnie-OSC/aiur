defmodule Aiur.LandingWatch.PrRerunBaseGreenTest do
  use ExUnit.Case, async: true

  alias Aiur.LandingWatch.PrRerun

  @started "2026-10-14T10:00:00Z"
  @started_ms 1_791_972_000_000

  test "a later passing base check refreshes an approved auto-merge PR while main stayed green" do
    parent = self()
    path = Path.join(System.tmp_dir!(), "landing-base-green-#{System.unique_integer([:positive])}.json")
    ExUnit.Callbacks.on_exit(fn -> Aiur.TestCleanup.rm_rf!(path) end)

    history = [
      %{completed_at: @started_ms - 60_000, checks: [%{name: "audit", conclusion: "success"}]},
      %{completed_at: @started_ms + 60_000, checks: [%{name: "audit", conclusion: "success"}]}
    ]

    observation = %{
      number: 17,
      node_id: "PR_node",
      head: "head-sha",
      draft?: false,
      review_decision: "APPROVED",
      merge_queue_entry: nil,
      auto_merge_request: %{"enabledAt" => "2026-10-14T09:00:00Z"},
      rest: %{"head" => %{"ref" => "aiur/17-work"}},
      raw: %{"reviewDecision" => "APPROVED", "headRefOid" => "head-sha", "isDraft" => false},
      reviews: [%{"commit" => %{"oid" => "head-sha"}}]
    }

    run = %{
      "run_id" => 99,
      "name" => "audit",
      "status" => "completed",
      "conclusion" => "failure",
      "started_at" => @started,
      "workflow_jobs" => [%{"id" => 7, "name" => "audit", "conclusion" => "failure", "steps" => [%{"conclusion" => "failure"}]}]
    }

    opts = [
      actions_run_fun: fn 99, _ -> {:ok, %{"path" => ".github/workflows/ci.yml"}} end,
      workflow_definitions_fun: fn ".github/workflows/ci.yml", "main", _ -> {:ok, %{"audit" => %{"name" => "audit"}}} end,
      ci_merges_fun: fn _ -> {:ok, []} end,
      recent_main_failure_paths: [],
      known_failure_patterns: [],
      job_log_fun: fn _, _ -> {:ok, "unrecognized test failure"} end,
      main_history_fun: fn -> history end,
      changed_paths_fun: fn _, _ -> {:ok, ["src/lib/aiur/feature.ex"]} end,
      base_branch: "main",
      rerun_fun: fn _, _ -> send(parent, :rerun) && {:ok, %{}} end,
      base_changes_fun: fn "head-sha", "main", _ -> {:ok, ["README.md"]} end,
      update_branch_fun: fn 17, "head-sha", _ -> send(parent, :updated) && {:ok, %{}} end,
      observe_refresh_fun: fn _, _ -> {:ok, %{"headRefOid" => "refreshed-head"}} end,
      approval_carry_classifier: fn _, _, _, _ -> :identical end,
      comment_fun: fn _, _, _ -> {:ok, %{}} end,
      job_log_fun: fn _, _ -> {:ok, "unrecognized test failure"} end,
      journal_path: path,
      now_ms: @started_ms + 3_600_000
    ]

    assert :ok = PrRerun.handle_failure(observation, %{failures: [%{name: "audit"}]}, [run], opts)
    assert_received :updated
    refute_received :rerun
  end
end
