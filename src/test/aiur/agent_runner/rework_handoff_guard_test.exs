defmodule Aiur.AgentRunner.ReworkHandoffGuardTest do
  use ExUnit.Case, async: true

  alias Aiur.AgentRunner.ReworkHandoffGuard
  alias Aiur.AgentRunner.ToolExecutor
  alias Aiur.Issue

  test "rework handback refuses a review finding without a new commit" do
    issue = %Issue{id: "gid-rework-checklist", identifier: "4180", state: "rework"}

    assert {:blocked, [reason]} =
             ReworkHandoffGuard.handoff_blockers(issue, "human-review", nil, nil,
               rework_head_sha: "review-sha",
               open_pr_fetcher: fn _ -> {:ok, %{"number" => 7}} end,
               rework_checklist: [
                 %{
                   "id" => "thread-1",
                   "file" => "lib/a.ex",
                   "status" => "fixed",
                   "commit" => "new-sha"
                 }
               ],
               review_checklist_fetcher: fn _ -> {:ok, [%{"id" => "thread-1"}]} end,
               pull_request_status_fetcher: fn _ ->
                 {:ok, %{draft?: false, mergeable: "MERGEABLE"}}
               end,
               rework_commits_since_review: [],
               rework_touched_files: ["lib/a.ex"]
             )

    assert reason =~ "no new commits since the review"
  end

  test "rework ci-wait handback refuses when no commit follows the review" do
    issue = %Issue{id: "gid-rework-ci-wait-noop", identifier: "4180", state: "rework"}

    assert {:blocked, [reason]} =
             ReworkHandoffGuard.handoff_blockers(issue, "ci-wait", nil, nil,
               rework_head_sha: "review-sha",
               open_pr_fetcher: fn _ -> {:ok, %{"number" => 7}} end,
               rework_checklist: [],
               review_checklist_fetcher: fn _ -> {:ok, []} end,
               pull_request_status_fetcher: fn _ ->
                 {:ok, %{draft?: false, mergeable: "MERGEABLE"}}
               end,
               rework_commits_since_review: [],
               rework_touched_files: []
             )

    assert reason =~ "no new commits since the review"
  end

  test "rework handback names an unchecked review finding" do
    issue = %Issue{id: "gid-rework-unchecked", identifier: "4180", state: "rework"}

    assert {:blocked, reasons} =
             ReworkHandoffGuard.handoff_blockers(issue, "human-review", nil, nil,
               rework_head_sha: "review-sha",
               open_pr_fetcher: fn _ -> {:ok, %{"number" => 7}} end,
               rework_commits_since_review: ["new-sha"],
               rework_checklist: [
                 %{
                   "id" => "thread-1",
                   "file" => "lib/a.ex",
                   "status" => "fixed",
                   "commit" => "new-sha"
                 }
               ],
               review_checklist_fetcher: fn _ ->
                 {:ok, [%{"id" => "thread-1"}, %{"id" => "thread-2"}]}
               end,
               pull_request_status_fetcher: fn _ ->
                 {:ok, %{draft?: false, mergeable: "MERGEABLE"}}
               end,
               rework_commits_since_review: ["new-sha"],
               rework_touched_files: ["lib/a.ex"]
             )

    assert Enum.any?(reasons, &(&1 =~ "finding thread-2 is unchecked"))
  end

  test "rework handback flags a fixed finding whose file was not touched" do
    issue = %Issue{id: "gid-rework-untouched", identifier: "4180", state: "rework"}

    assert {:blocked, reasons} =
             ReworkHandoffGuard.handoff_blockers(issue, "human-review", nil, nil,
               rework_head_sha: "review-sha",
               open_pr_fetcher: fn _ -> {:ok, %{"number" => 7}} end,
               rework_commits_since_review: ["new-sha"],
               rework_checklist: [
                 %{
                   "id" => "thread-1",
                   "file" => "lib/a.ex",
                   "status" => "fixed",
                   "commit" => "new-sha"
                 }
               ],
               review_checklist_fetcher: fn _ -> {:ok, [%{"id" => "thread-1"}]} end,
               pull_request_status_fetcher: fn _ ->
                 {:ok, %{draft?: false, mergeable: "MERGEABLE"}}
               end,
               rework_commits_since_review: ["new-sha"],
               rework_touched_files: ["lib/other.ex"]
             )

    assert Enum.any?(
             reasons,
             &(&1 =~ "finding thread-1 marked fixed but its file was not touched")
           )
  end

  test "rework handback requires evidence for disputed findings and matches numeric GitHub ids" do
    issue = %Issue{id: "gid-rework-disputed", identifier: "4180", state: "rework"}

    opts = [
      rework_head_sha: "review-sha",
      open_pr_fetcher: fn _ -> {:ok, %{"number" => 7}} end,
      review_checklist_fetcher: fn _ -> {:ok, [%{"id" => 1234, "path" => "lib/a.ex", "line" => 8}]} end,
      pull_request_status_fetcher: fn _ -> {:ok, %{draft?: false, mergeable: "MERGEABLE"}} end,
      rework_commits_since_review: ["new-sha"],
      rework_touched_files: []
    ]

    assert {:blocked, reasons} =
             ReworkHandoffGuard.handoff_blockers(
               issue,
               "human-review",
               nil,
               nil,
               Keyword.put(opts, :rework_checklist, [%{"id" => "1234", "file" => "lib/a.ex", "status" => "disputed"}])
             )

    assert Enum.any?(reasons, &(&1 =~ "finding 1234 disputed without evidence"))

    assert :allow =
             ReworkHandoffGuard.handoff_blockers(
               issue,
               "human-review",
               nil,
               nil,
               Keyword.put(opts, :rework_checklist, [%{"id" => "1234", "file" => "lib/a.ex", "status" => "disputed", "evidence" => "The requested API does not exist."}])
             )
  end

  test "rework handback refuses a draft PR and a conflicting PR" do
    issue = %Issue{id: "gid-rework-pr-state", identifier: "4180", state: "rework"}
    findings = [%{"id" => "thread-1"}]

    checklist = [
      %{
        "id" => "thread-1",
        "file" => "lib/a.ex",
        "status" => "disputed",
        "evidence" => "The requested API does not exist."
      }
    ]

    base_opts = [
      rework_head_sha: "review-sha",
      open_pr_fetcher: fn _ -> {:ok, %{"number" => 7}} end,
      rework_checklist: checklist,
      review_checklist_fetcher: fn _ -> {:ok, findings} end,
      rework_commits_since_review: ["new-sha"],
      rework_touched_files: []
    ]

    for {status, expected} <- [
          {%{draft?: true, mergeable: "MERGEABLE"}, "still a draft"},
          {%{draft?: false, mergeable: "CONFLICTING"}, "conflicts with its base"}
        ] do
      assert {:blocked, [reason]} =
               ReworkHandoffGuard.handoff_blockers(
                 issue,
                 "human-review",
                 nil,
                 nil,
                 Keyword.put(base_opts, :pull_request_status_fetcher, fn _ -> {:ok, status} end)
               )

      assert reason =~ expected
    end
  end

  test "same-head rework hand-back with failed required checks returns an error and does not write" do
    issue = %Issue{id: "gid-rework", identifier: "4180", state: "rework"}
    test_pid = self()

    executor =
      ToolExecutor.build(issue, nil, nil, %{},
        rework_head_sha: "same-head",
        rework_commits_since_review: ["next-head"],
        coordination_runner: fn _key, operation, _opts -> operation.() end,
        ticket_state_writer: fn _issue_id, _state ->
          send(test_pid, :unexpected_write)
          :ok
        end,
        open_pr_fetcher: fn _ -> {:ok, %{"head" => %{"sha" => "same-head", "number" => 7}}} end,
        review_checklist_fetcher: fn _ -> {:ok, []} end,
        pull_request_status_fetcher: fn _ -> {:ok, %{draft?: false, mergeable: "MERGEABLE"}} end,
        pull_request_fetcher: fn _ -> {:ok, %{"isDraft" => false, "mergeable" => "MERGEABLE"}} end,
        required_checks_fetcher: fn _ ->
          send(test_pid, :required_checks_read)
          {:ok, [%{name: "lint", app_id: nil}]}
        end,
        commit_ci_status_fetcher: fn _ ->
          {:ok,
           %{
             check_runs: [
               %{"id" => 1, "name" => "lint", "status" => "completed", "conclusion" => "failure"}
             ],
             commit_status: %{}
           }}
        end,
        no_op_rework_alert: fn issue_arg, checks, message ->
          send(test_pid, {:attention, issue_arg.identifier, checks, message})
        end
      )

    response = executor.("aiur_set_ticket_state", %{"state" => "human-review"})

    assert_receive :required_checks_read, 100
    assert response["success"] == false
    assert response["output"] =~ "lint"
    assert_receive {:attention, "4180", ["lint"], message}, 100
    assert message =~ "latest rework comment"
    refute_received :unexpected_write
  end

  test "same-head rework hand-back with green required checks writes human-review despite a non-blocking failure" do
    issue = %Issue{id: "gid-rework-green", identifier: "4180", state: "rework"}
    test_pid = self()

    executor =
      ToolExecutor.build(issue, nil, nil, %{},
        rework_head_sha: "same-head",
        rework_commits_since_review: ["next-head"],
        coordination_runner: fn _key, operation, _opts -> operation.() end,
        ticket_state_writer: fn issue_id, state ->
          send(test_pid, {:state_write, issue_id, state})
          :ok
        end,
        open_pr_fetcher: fn _ -> {:ok, %{"head" => %{"sha" => "same-head", "number" => 7}}} end,
        review_checklist_fetcher: fn _ -> {:ok, []} end,
        pull_request_status_fetcher: fn _ -> {:ok, %{draft?: false, mergeable: "MERGEABLE"}} end,
        required_checks_fetcher: fn _ ->
          send(test_pid, :required_checks_read)
          {:ok, [%{name: "lint", app_id: nil}]}
        end,
        commit_ci_status_fetcher: fn _ ->
          {:ok,
           %{
             check_runs: [
               %{"id" => 1, "name" => "lint", "status" => "completed", "conclusion" => "success"},
               %{
                 "id" => 2,
                 "name" => "quarantined tests (non-blocking)",
                 "status" => "completed",
                 "conclusion" => "failure"
               }
             ],
             commit_status: %{}
           }}
        end,
        no_op_rework_alert: fn _issue, _checks, _message -> send(test_pid, :unexpected_alert) end
      )

    response = executor.("aiur_set_ticket_state", %{"state" => "human-review"})

    assert_receive :required_checks_read, 100
    assert response["success"]
    assert_receive {:state_write, "gid-rework-green", "human-review"}, 100
    refute_received :unexpected_alert
  end

  test "rework hand-back writes human-review when required checks failed on the old dispatch head" do
    issue = %Issue{id: "gid-rework-moved", identifier: "4180", state: "rework"}
    test_pid = self()

    executor =
      ToolExecutor.build(issue, nil, nil, %{},
        rework_head_sha: "old",
        coordination_runner: fn _key, operation, _opts -> operation.() end,
        ticket_state_writer: fn issue_id, state ->
          send(test_pid, {:state_write, issue_id, state})
          :ok
        end,
        open_pr_fetcher: fn _ -> {:ok, %{"head" => %{"sha" => "new", "number" => 7}}} end,
        review_checklist_fetcher: fn _ -> {:ok, []} end,
        pull_request_status_fetcher: fn _ -> {:ok, %{draft?: false, mergeable: "MERGEABLE"}} end,
        required_checks_fetcher: fn _ -> {:ok, [%{name: "lint", app_id: nil}]} end,
        commit_ci_status_fetcher: fn "old" ->
          {:ok,
           %{
             check_runs: [
               %{"id" => 1, "name" => "lint", "status" => "completed", "conclusion" => "failure"}
             ],
             commit_status: %{}
           }}
        end,
        no_op_rework_alert: fn _issue, _checks, _message -> send(test_pid, :unexpected_alert) end
      )

    response = executor.("aiur_set_ticket_state", %{"state" => "human-review"})

    assert response["success"]
    assert_receive {:state_write, "gid-rework-moved", "human-review"}, 100
    refute_received :unexpected_alert
  end

  test "ci-wait and human-review handoffs fail until the PR body names the live head" do
    head = String.duplicate("c", 40)
    base = String.duplicate("d", 40)
    issue = %Issue{id: "gid-evidence", identifier: "4611", state: "in-progress"}
    test_pid = self()

    # The first `aiur pre-pr` ran before `gh pr create`, so the body still holds a placeholder head.
    stale =
      "## Local tests\n\nPolicy: partial\nTested head: #{String.duplicate("a", 40)}\nBase: main @ #{base}\nSelection: focused\n- `mix test` -> pass\n"

    fresh =
      String.replace(stale, "Tested head: " <> String.duplicate("a", 40), "Tested head: " <> head)

    executor = fn body ->
      ToolExecutor.build(issue, nil, nil, %{},
        coordination_runner: fn _key, operation, _opts -> operation.() end,
        ticket_state_writer: fn issue_id, state ->
          send(test_pid, {:state_write, issue_id, state})
          :ok
        end,
        open_pr_fetcher: fn "4611" ->
          {:ok, %{"number" => 4622, "body" => body, "head" => %{"sha" => head}}}
        end
      )
    end

    for state <- ["ci-wait", "human-review"] do
      response = executor.(stale).("aiur_set_ticket_state", %{"state" => state})
      refute response["success"]
      error = Jason.decode!(response["output"])["error"]
      assert error["reason"] == "stale_pr_body_evidence"
      assert error["message"] =~ "Run `aiur pre-pr` again after `gh pr create`"
      refute_received {:state_write, _, _}
    end

    backticked = String.replace(fresh, "Tested head: " <> head, "Tested head: `#{head}`")
    refute executor.(backticked).("aiur_set_ticket_state", %{"state" => "ci-wait"})["success"]

    assert executor.(fresh).("aiur_set_ticket_state", %{"state" => "ci-wait"})["success"]
    assert_receive {:state_write, "gid-evidence", "ci-wait"}, 100
  end
end
