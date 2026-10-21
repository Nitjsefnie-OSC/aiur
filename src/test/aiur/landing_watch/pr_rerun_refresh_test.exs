defmodule Aiur.LandingWatch.PrRerunRefreshTest do
  use ExUnit.Case, async: true

  alias Aiur.LandingWatch

  test "base refresh uses the observed approved head and comments without rerunning" do
    parent = self()

    assert :ok =
             LandingWatch.process(observation(),
               approved_fun: fn _, _ -> {:ok, true} end,
               required_checks_fun: fn _ -> {:ok, [%{name: "ci gate", app_id: nil}]} end,
               ci_status_fun: fn _, _ -> {:ok, %{check_runs: [failed_gate()], commit_status: %{"state" => "success", "statuses" => []}}} end,
               jobs_fun: fn 99, _ -> {:ok, jobs()} end,
               main_history_fun: fn -> [] end,
               base_branch: "main",
               changed_paths_fun: fn _, _ -> {:ok, ["src/lib/aiur/feature.ex"]} end,
               actions_run_fun: fn 99, _ -> {:ok, %{"path" => ".github/workflows/ci.yml"}} end,
               workflow_definitions_fun: fn _, "main", _ -> {:ok, %{"gate" => %{"name" => "ci gate"}}} end,
               job_log_fun: fn _, _ -> {:ok, "unclassified failure"} end,
               known_failure_patterns: [],
               recent_main_failure_paths: [],
               base_changes_fun: fn _, _, _ -> {:ok, ["README.md"]} end,
               update_branch_fun: fn 17, "head-sha", _ ->
                 send(parent, :refresh_observed_head)
                 {:ok, %{}}
               end,
               comment_fun: fn 17, body, _ ->
                 send(parent, {:comment, body})
                 {:ok, %{}}
               end,
               rework_fun: fn _, _, _ ->
                 send(parent, :rework)
                 :ok
               end,
               rerun_fun: fn _, _ ->
                 send(parent, :rerun)
                 {:ok, %{}}
               end,
               journal_path: journal_path(),
               now_ms: 1_791_975_600_000
             )

    assert_received :refresh_observed_head
    assert_received {:comment, body}
    assert body =~ "updated the branch from the base"
    refute_received :rerun
    refute_received :rework
  end

  test "transient runner failure reruns while retaining the current merge ref" do
    parent = self()
    run = Map.put(failed_gate(), "run_id", 99)

    assert :ok =
             LandingWatch.process(observation(),
               approved_fun: fn _, _ -> {:ok, true} end,
               required_checks_fun: fn _ -> {:ok, [%{name: "ci gate", app_id: nil}]} end,
               ci_status_fun: fn _, _ -> {:ok, %{check_runs: [run], commit_status: %{"state" => "success", "statuses" => []}}} end,
               jobs_fun: fn 99, _ -> {:ok, [%{"name" => "ci gate", "conclusion" => "failure", "steps" => [%{"conclusion" => "failure"}]}]} end,
               job_log_fun: fn _, _ -> {:ok, "Error: The runner lost communication with the server."} end,
               rerun_fun: fn 99, _ ->
                 send(parent, :rerun)
                 {:ok, %{}}
               end,
               update_branch_fun: fn _, _, _ ->
                 send(parent, :update_branch)
                 {:ok, %{}}
               end,
               comment_fun: fn _, _, _ -> {:ok, %{}} end,
               rework_fun: fn _, _, _ ->
                 send(parent, :rework)
                 :ok
               end,
               journal_path: journal_path(),
               now_ms: 1_791_975_600_000
             )

    assert_received :rerun
    refute_received :update_branch
  end

  defp observation do
    %{
      number: 17,
      node_id: "PR_node",
      head: "head-sha",
      draft?: false,
      review_decision: "APPROVED",
      reviews: [%{"commit" => %{"oid" => "head-sha"}}],
      merge_queue_entry: nil,
      auto_merge_request: nil,
      rest: %{"head" => %{"ref" => "aiur/17-work"}},
      raw: %{"reviewDecision" => "APPROVED", "headRefOid" => "head-sha", "isDraft" => false}
    }
  end

  defp failed_gate do
    %{"id" => 50, "run_id" => 99, "name" => "ci gate", "status" => "completed", "conclusion" => "failure", "started_at" => "2026-10-14T10:00:00Z", "check_suite" => %{"id" => 100}}
  end

  defp jobs do
    [%{"id" => 8, "name" => "ci gate", "conclusion" => "failure", "steps" => [%{"conclusion" => "failure"}], "started_at" => "2026-10-14T10:06:00Z", "completed_at" => "2026-10-14T10:06:05Z"}]
  end

  defp journal_path do
    path = Path.join(System.tmp_dir!(), "landing-refresh-#{System.unique_integer([:positive])}.json")
    ExUnit.Callbacks.on_exit(fn -> Aiur.TestCleanup.rm_rf!(path) end)
    path
  end
end
