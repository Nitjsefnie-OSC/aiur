defmodule Aiur.Orchestrator.MergeTransitionTest do
  use Aiur.TestSupport

  alias Aiur.GitHub.IssueState
  alias Aiur.Orchestrator.{CommentWake, MergeTransition, State}

  setup do
    write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "github", tracker_repo: "owner/repo", tracker_label_prefix: "agent")
    :ok
  end

  test "GitHub closing keyword before the merge write completes an already done ticket without an alert" do
    issue = %{"state" => "closed", "labels" => [%{"name" => "agent:done"}, %{"name" => "agent:queued"}], "body" => "private issue body"}
    parent = self()

    log =
      capture_log(fn ->
        merge(issue, fn state, identifier ->
          send(parent, {:resumed, identifier})
          state
        end)
      end)

    assert_received {:resumed, "3778"}
    assert_received :terminated
    refute log =~ "merge_terminal_write_failed"
    refute log =~ "private issue body"
  end

  test "a closed ticket with an active label still alerts using only the reason name" do
    issue = %{"state" => "closed", "labels" => [%{"name" => "agent:rework"}], "body" => String.duplicate("private issue body", 500)}

    log = capture_log(fn -> merge(issue) end)
    refute_received :terminated

    assert log =~ "ticket.3778.agent.attention.merge_terminal_write_failed"
    assert log =~ "no_state_label_written"
    refute log =~ "private issue body"
    refute log =~ "ticket was not closed"
  end

  test "future regression guard: only closed issues with only the done state label satisfy the merge" do
    for {state, labels} <- [{"open", ["agent:done"]}, {"closed", []}, {"closed", ["agent:cancelled"]}, {"closed", ["agent:done", "agent:rework"]}, {"closed", ["other:done"]}] do
      outcome = {"rework", {:error, {:no_state_label_written, %{"state" => state, "labels" => Enum.map(labels, &%{"name" => &1})}}}}
      assert MergeTransition.normalize(outcome) == outcome
    end
  end

  test "future regression guard: other failures retain their outcome and have bounded cause names" do
    assert MergeTransition.normalize({"done", {:error, :timeout}}) == {"done", {:error, :timeout}}
    assert MergeTransition.reason_name(:timeout) == :timeout
    assert MergeTransition.reason_name({:github, :permission, %{status: 403}}) == :permission
    assert MergeTransition.reason_name({:github, :local_hold, %{body: "private"}}) == :local_hold
    assert MergeTransition.reason_name(%{body: "private"}) == :unknown
  end

  test "transient terminal label failure retries and completes the merged ticket" do
    {:ok, attempts} = Agent.start_link(fn -> 0 end)
    on_exit(fn -> if Process.alive?(attempts), do: Agent.stop(attempts) end)

    updater = fn "3778", "done" ->
      Agent.get_and_update(attempts, fn count ->
        next = count + 1
        {if(next == 1, do: {:error, {:github, :timeout, %{reason: :timeout}}}, else: :ok), next}
      end)
    end

    merge(
      %{"state" => "closed", "labels" => [%{"name" => "agent:done"}]},
      fn state, _id -> state end,
      target_state: "done",
      update_issue_state_fun: updater,
      merge_terminal_write_sleep_fun: fn _ -> :ok end
    )

    assert_receive :terminated
    assert Agent.get(attempts, & &1) == 2
  end

  test "transient non-terminal merge target failure is retried" do
    {:ok, attempts} = Agent.start_link(fn -> 0 end)
    on_exit(fn -> if Process.alive?(attempts), do: Agent.stop(attempts) end)
    parent = self()

    updater = fn "3778", "human-review" ->
      result =
        Agent.get_and_update(attempts, fn count ->
          next = count + 1
          {if(next == 1, do: {:error, {:github, :timeout, %{reason: :timeout}}}, else: :ok), next}
        end)

      send(parent, {:human_review_write, result})
      result
    end

    merge(
      %{"state" => "open", "labels" => [%{"name" => "agent:in-progress"}]},
      fn state, _id -> state end,
      target_state: "human-review",
      update_issue_state_fun: updater,
      merge_terminal_write_sleep_fun: fn _ -> :ok end
    )

    assert_receive {:human_review_write, :ok}
    assert Agent.get(attempts, & &1) == 2
  end

  test "terminal write alert reports the GitHub classification" do
    log =
      capture_log(fn ->
        merge(
          %{"state" => "closed", "labels" => []},
          fn state, _id -> state end,
          update_issue_state_fun: fn _id, _target -> {:error, {:github, :permission, %{status: 403}}} end,
          merge_terminal_write_sleep_fun: fn _ -> :ok end
        )
      end)

    assert log =~ "merge_terminal_write_failed"
    assert log =~ "reason=permission"
  end

  test "transient terminal write retries stop at the configured attempt limit" do
    {:ok, attempts} = Agent.start_link(fn -> 0 end)
    on_exit(fn -> if Process.alive?(attempts), do: Agent.stop(attempts) end)
    parent = self()

    updater = fn _id, _target ->
      next = Agent.get_and_update(attempts, fn count -> {count + 1, count + 1} end)
      send(parent, {:write_attempt, next})
      {:error, {:github, :timeout, %{reason: :timeout}}}
    end

    log =
      capture_log(fn ->
        merge(
          %{"state" => "closed", "labels" => []},
          fn state, _id -> state end,
          target_state: "done",
          update_issue_state_fun: updater,
          merge_terminal_write_sleep_fun: fn delay -> send(parent, {:retry_delay, delay}) end
        )
      end)

    assert Agent.get(attempts, & &1) == 3
    assert_receive {:write_attempt, 1}
    assert_receive {:write_attempt, 2}
    assert_receive {:write_attempt, 3}
    assert_receive {:retry_delay, 100}
    assert_receive {:retry_delay, 200}
    refute_receive {:retry_delay, _}
    refute_receive :terminated
    assert log =~ "reason=timeout"
  end

  defp merge(issue, resume \\ fn state, _identifier -> state end, opts \\ []) do
    request_fun = fn request ->
      case request.method do
        :get -> {:ok, %{status: 200, body: issue}}
        :delete -> {:ok, %{status: 200, body: []}}
        other -> flunk("unexpected write: #{other}")
      end
    end

    context = %{
      request_fun: request_fun,
      token: "test-token",
      owner: "owner",
      repo: "repo",
      issue_number: "3778",
      issue_url: "https://api.github.com/repos/owner/repo/issues/3778",
      prefix: "agent",
      opts: [request_fun: request_fun]
    }

    parent = self()
    ticket = %Aiur.Issue{id: "3778", identifier: "3778", state: "rework"}
    state = %State{running: %{"3778" => %{issue: ticket, identifier: "3778"}}, completed: MapSet.new(), claimed: MapSet.new(["3778"])}

    CommentWake.mark_pr_merged_issue_done(state, "3778",
      pr_body: "Closes #3778",
      target_state: Keyword.get(opts, :target_state),
      open_pull_requests_fun: fn _identifier -> {:ok, [%{"number" => 3779, "review_decision" => "CHANGES_REQUESTED"}]} end,
      unresolved_threads_fetcher: fn _pr -> {:ok, [%{"id" => "remaining-thread"}]} end,
      update_issue_state_fun: Keyword.get(opts, :update_issue_state_fun, fn "3778", target -> IssueState.apply_issue_state_update(context, issue, target, "agent:#{target}") end),
      merger_allowed_fun: fn _login -> true end,
      clear_session_handle_fun: fn "3778" -> :ok end,
      terminate_running_issue_fun: fn current, "3778", true ->
        send(parent, :terminated)
        current
      end,
      observe_membership_fun: fn _identity, _lifecycle -> :ok end,
      mark_reconciled_fun: fn _identifier -> :ok end,
      set_terminal_verification_pending_fun: fn _identity, _pending -> :ok end,
      resume_blockees_fun: resume,
      merge_terminal_write_sleep_fun: Keyword.get(opts, :merge_terminal_write_sleep_fun, fn _ -> :ok end)
    )
  end
end
