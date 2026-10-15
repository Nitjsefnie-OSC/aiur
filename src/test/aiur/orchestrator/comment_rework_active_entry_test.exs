defmodule Aiur.Orchestrator.CommentReworkActiveEntryTest do
  @moduledoc "Regression coverage for reviews delivered to completed worker entries."

  use Aiur.TestSupport

  alias Aiur.{AgentQueueStore, Issue}
  alias Aiur.Orchestrator.{CommentWake, State}

  @issue_number "2814"

  defp base_state(running) do
    %State{
      queue_store: AgentQueueStore.new(),
      running: running,
      completed: MapSet.new(),
      claimed: MapSet.new(),
      retry_attempts: %{},
      last_polled_issues: %{},
      todo_over_capacity_alert_active: false,
      agent_totals: nil,
      agent_rate_limits: nil,
      codex_totals: nil,
      codex_rate_limits: nil,
      poll_interval_ms: 60_000,
      max_concurrent_agents: nil,
      session_max_concurrent_agents: nil,
      effective_concurrent_agents: nil,
      load_envelope_state: %{last_decrease_ms: nil, cpu_snapshot: nil},
      next_poll_due_at_ms: nil,
      poll_check_in_progress: nil,
      tick_timer_ref: nil,
      tick_token: nil,
      initial_dispatch_cycle: false,
      events_etag: nil,
      events_last_id: nil,
      github_comments_since: %{},
      github_comment_issue_updated_at: %{},
      github_connectivity: %{},
      github_poll_delays: %{},
      github_command_scan_since: nil
    }
  end

  # The shape observed on every failing ticket: the provider's turn has
  # completed, the entry is still in `state.running`, and `control.status` is
  # `:completed` rather than `:deactivated`.
  defp completed_running_entry do
    %{
      "2814" => %{
        identifier: @issue_number,
        issue: %Issue{
          id: @issue_number,
          identifier: @issue_number,
          state: "human-review",
          title: "t",
          labels: ["agent:human-review"]
        },
        pid: nil,
        telemetry_attempt_id: "ticket-2814:test",
        control: %{status: :completed, version: 1}
      }
    }
  end

  defp human_review_issue do
    %Issue{
      id: @issue_number,
      identifier: @issue_number,
      state: "human-review",
      title: "t",
      labels: ["agent:human-review"]
    }
  end

  # A body-only `gh pr review --request-changes`: live against the current head,
  # by a trusted author, opening no review thread at all.
  defp changes_requested_review_event(issue, overrides) do
    %{
      topic: "ticket.#{@issue_number}.pr.review_comment",
      author_trusted?: true,
      comment: %{
        "state" => "CHANGES_REQUESTED",
        "body" => "two blockers before this can merge",
        "submitted_at" => "2026-09-26T04:09:44Z"
      },
      pull_request: %{
        "review_decision" => "CHANGES_REQUESTED",
        "head_committed_at" => "2026-09-26T03:59:38Z"
      },
      issue_state_fetcher: fn _ids -> {:ok, [issue]} end,
      open_pr_fetcher: fn _issue_key -> {:ok, %{"number" => 337, "head" => %{"sha" => "52617e7"}}} end
    }
    |> Map.merge(overrides)
  end

  setup do
    write_workflow_file!(Aiur.Workflow.workflow_file_path(), tracker_kind: "memory")

    Application.put_env(:aiur, :memory_tracker_issues, [human_review_issue()])
    Application.put_env(:aiur, :memory_tracker_recipient, self())
    Application.put_env(:aiur, :comment_rework_retry_delay_ms, 5)

    on_exit(fn -> Application.delete_env(:aiur, :comment_rework_retry_delay_ms) end)

    :ok
  end

  test "an idle ci-wait ticket is discovered and a changes-requested review routes it to rework" do
    issue = %{human_review_issue() | state: "ci-wait", labels: ["agent:ci-wait"]}
    Application.put_env(:aiur, :memory_tracker_issues, [issue])
    state = base_state(%{})

    event = changes_requested_review_event(issue, %{unresolved_threads_fetcher: fn _pr -> {:ok, []} end})

    CommentWake.maybe_transition_idle_issue_to_rework(
      %{state | last_polled_issues: %{issue.id => issue}},
      @issue_number,
      :pr_review,
      event,
      1
    )

    assert_receive {:memory_tracker_state_update, @issue_number, "rework"}, 2_000
  end

  for body <- ["Update the stale base before merge", "## Blocking: stale base must be updated"] do
    test "a trusted blocking COMMENTED review #{inspect(body)} in human-review routes without inline threads" do
      issue = human_review_issue()

      event =
        changes_requested_review_event(issue, %{
          comment: %{"state" => "COMMENTED", "body" => unquote(body), "submitted_at" => "2026-09-26T04:09:44Z"},
          pull_request: %{"review_decision" => "REVIEW_REQUIRED", "head_committed_at" => "2026-09-26T03:59:38Z"},
          unresolved_threads_fetcher: fn _pr -> {:ok, []} end
        })

      CommentWake.maybe_reactivate_on_comment(base_state(completed_running_entry()), @issue_number, :pr_review, event)

      assert_receive {:memory_tracker_state_update, @issue_number, "rework"}, 2_000
    end
  end

  for ticket_state <- ["human-review", "ci-wait"],
      body <- ["No blockers; waiting on CI", "Looks good; no blockers", "All blockers resolved"] do
    test "a trusted clean COMMENTED review #{inspect(body)} in #{ticket_state} does not route to rework" do
      issue = %{human_review_issue() | state: unquote(ticket_state), labels: ["agent:" <> unquote(ticket_state)]}
      Application.put_env(:aiur, :memory_tracker_issues, [issue])

      event =
        changes_requested_review_event(issue, %{
          comment: %{"state" => "COMMENTED", "body" => unquote(body), "submitted_at" => "2026-09-26T04:09:44Z"},
          pull_request: %{"review_decision" => "REVIEW_REQUIRED", "head_committed_at" => "2026-09-26T03:59:38Z"},
          unresolved_threads_fetcher: fn _pr -> {:ok, []} end
        })

      CommentWake.maybe_reactivate_on_comment(base_state(%{}), @issue_number, :pr_review, event)

      refute_received {:memory_tracker_state_update, @issue_number, "rework"}
      assert {:ok, [%Issue{state: state}]} = Aiur.Tracker.fetch_issue_states_by_ids([@issue_number])
      assert state == unquote(ticket_state)
    end
  end
end
