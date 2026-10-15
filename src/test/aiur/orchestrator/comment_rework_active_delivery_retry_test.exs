defmodule Aiur.Orchestrator.CommentReworkActiveDeliveryRetryTest do
  use Aiur.TestSupport
  import ExUnit.CaptureLog

  alias Aiur.{AgentQueueStore, Issue}
  alias Aiur.Orchestrator.{CommentWake, State}

  @issue_number "4601"

  defp issue do
    %Issue{id: @issue_number, identifier: @issue_number, state: "human-review", title: "t", labels: ["agent:human-review"]}
  end

  defp state do
    ticket = issue()

    %State{
      queue_store: AgentQueueStore.new(),
      running: %{
        @issue_number => %{
          identifier: @issue_number,
          issue: ticket,
          pid: nil,
          telemetry_attempt_id: "ticket-4601:test",
          control: %{status: :completed, version: 1}
        }
      },
      completed: MapSet.new(),
      claimed: MapSet.new(),
      retry_attempts: %{},
      last_polled_issues: %{},
      github_comments_since: %{},
      github_comment_issue_updated_at: %{},
      github_connectivity: %{},
      github_poll_delays: %{},
      github_command_scan_since: nil
    }
  end

  defp review_event(overrides) do
    %{
      author_trusted?: true,
      comment: %{"state" => "CHANGES_REQUESTED", "body" => "please fix", "submitted_at" => "2026-09-26T04:09:44Z"},
      pull_request: %{"review_decision" => "CHANGES_REQUESTED", "head_committed_at" => "2026-09-26T03:59:38Z"},
      open_pr_fetcher: fn _ -> {:ok, %{"number" => 337, "head" => %{"sha" => "52617e7"}}} end,
      issue_state_fetcher: fn _ -> {:ok, [issue()]} end
    }
    |> Map.merge(overrides)
  end

  setup do
    write_workflow_file!(Aiur.Workflow.workflow_file_path(), tracker_kind: "memory")
    Application.put_env(:aiur, :memory_tracker_issues, [issue()])
    Application.put_env(:aiur, :memory_tracker_recipient, self())
    Application.put_env(:aiur, :comment_rework_retry_delay_ms, 5)
    on_exit(fn -> Application.delete_env(:aiur, :comment_rework_retry_delay_ms) end)
    :ok
  end

  test "transient gate failure retries a changes-requested review on a completed entry" do
    reads = :counters.new(1, [])

    event =
      review_event(%{
        unresolved_threads_fetcher: fn _ ->
          :counters.add(reads, 1, 1)
          if :counters.get(reads, 1) == 1, do: {:error, {:github, :http, %{status: 502}}}, else: {:ok, []}
        end
      })

    current = state()
    capture_log(fn -> CommentWake.maybe_reactivate_on_comment(current, @issue_number, :pr_review, event, 1) end)
    assert_receive {:retry_comment_rework, @issue_number, :pr_review, retried_event, 2}, 2_000
    capture_log(fn -> CommentWake.maybe_reactivate_on_comment(current, @issue_number, :pr_review, retried_event, 2) end)
    assert_receive {:memory_tracker_state_update, @issue_number, "rework"}, 2_000
  end
end
