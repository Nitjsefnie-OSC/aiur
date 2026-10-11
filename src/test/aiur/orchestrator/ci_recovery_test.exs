defmodule Aiur.Orchestrator.CiRecoveryTest do
  use Aiur.TestSupport
  import ExUnit.CaptureIO
  import Aiur.OrchestratorDeactivateSupport
  alias Aiur.CI.FailureDigest
  alias Aiur.ControlCLI.CiWait
  alias Aiur.Events.GithubCIPoller.Recovery, as: CiRecovery
  alias Aiur.GitHub.CIRecoveryStore, as: CiRecoveryStore
  alias Aiur.GitHub.ResourceStore
  alias Aiur.{Issue, JsonStore}
  alias Aiur.Orchestrator.CiLifecycle
  alias Aiur.Orchestrator.StatusReport.SnapshotPayload
  alias Aiur.OrchestratorDeactivateSupport.CIWatcherGitHubClient

  setup do
    write_workflow_file!(Aiur.Workflow.workflow_file_path(), tracker_kind: "github", tracker_repo: "owner/repo")
    ResourceStore.clear(:ci_failure_digest, "owner", "repo")
    ResourceStore.clear(:flake_issues, "owner", "repo")
    root = Aiur.TestSupport.tmp_root!("ci_recovery")
    File.mkdir_p!(root)
    path = Path.join(root, "recovery.json")
    agent = start_supervised!({Agent, fn -> %{attempt: 1, requests: [], behind: false, queued: false, changed: ["src/lib/other.ex"], permission: true, advance: true, extra: [], known: false} end})

    request = fn req ->
      state = Agent.get_and_update(agent, fn state -> {state, %{state | requests: state.requests ++ [req]}} end)
      response(req, state, agent, path)
    end

    issue = %Issue{id: "3864", identifier: "3864", state: "ci-wait"}
    result = %{target: "3864", pr_number: 42, head_sha: "head-1", decision: :failed, failures: [%{name: "test"}]}

    opts = [
      request_fun: request,
      ci_recovery_path: path,
      alert_emitter: fn topic, details ->
        send(self(), {:attention, topic, details})
        :ok
      end
    ]

    on_exit(fn ->
      ResourceStore.clear(:ci_failure_digest, "owner", "repo")
      ResourceStore.clear(:flake_issues, "owner", "repo")
    end)

    %{issue: issue, result: result, opts: opts, agent: agent, path: path}
  end

  test "unrelated test gets exactly one failed-job rerun, persisted across observations", ctx do
    assert %{decision: :pending, recovery: "rerun_requested"} = recover(ctx)
    assert %{decision: :failed} = recover(ctx)
    assert %{decision: :failed} = recover(ctx)
    assert writes(ctx) == [{:post, "/actions/runs/99/rerun-failed-jobs"}]
    assert {:ok, %{"heads" => %{"head-1" => %{"runs" => [%{"id" => 99, "attempt" => 1}]}}}} = CiRecoveryStore.read("3864", 42, ctx.opts)
    refute_received {:attention, _, _}
  end

  test "unknown or independent check failures never rerun", ctx do
    Agent.update(ctx.agent, &%{&1 | extra: [%{"annotation_level" => "failure", "message" => "coverage too low"}]})
    assert %{decision: :failed} = recover(ctx)
    assert writes(ctx) == []
  end

  test "a changed failing test is delivered to rework", ctx do
    Agent.update(ctx.agent, &%{&1 | changed: ["src/test/untouched_test.exs"]})
    assert %{decision: :failed} = recover(ctx)
    assert writes(ctx) == []
  end

  test "a known flake reruns even when its file is changed", ctx do
    Agent.update(ctx.agent, &%{&1 | known: true, changed: ["src/test/untouched_test.exs"]})
    assert %{decision: :pending, recovery: "rerun_requested"} = recover(ctx)
    assert length(writes(ctx)) == 1
  end

  test "permission failure raises one attention and never retries the write", ctx do
    Agent.update(ctx.agent, &%{&1 | permission: false})
    assert %{decision: :pending, recovery: "rerun_failed"} = recover(ctx)
    assert_received {:attention, "ticket.3864.pr.ci_recovery.rerun_failed", details}
    assert details[:message] =~ "UntouchedTest :: fails"
    recover(ctx)
    recover(ctx)
    refute_received {:attention, "ticket.3864.pr.ci_recovery.rerun_failed", _}
    assert length(writes(ctx)) == 1
  end

  test "safe stale base uses an expected-head update once", ctx do
    Agent.update(ctx.agent, &%{&1 | behind: true})
    assert %{decision: :pending, recovery: "base_update_requested"} = recover(ctx)
    assert %{decision: :pending, recovery: "base_update_pending"} = recover(ctx)
    assert writes(ctx) == [{:put, "/pulls/42/update-branch"}]
    assert Enum.find(requests(ctx), &(&1.method == :put)).body == %{expected_head_sha: "head-1"}
  end

  test "queued PRs are left alone", ctx do
    Agent.update(ctx.agent, &%{&1 | queued: true, behind: true})
    assert %{decision: :pending, recovery: "merge_queue"} = recover(ctx)
    assert writes(ctx) == []
    refute_received {:attention, _, _}
  end

  test "three failed handoffs raise one attention naming tests, then hold", ctx do
    for n <- 1..3 do
      result = %{ctx.result | head_sha: "cycle-#{n}"} |> Map.put(:ci_failure_digest, %FailureDigest{tests: [%{identity: "UntouchedTest :: fails"}]})
      assert :ok = CiRecovery.record_failure(ctx.issue, result, ctx.opts)
    end

    assert_received {:attention, "ticket.3864.pr.ci_recovery.loop", details}
    assert details[:message] =~ "3 failed CI/rework cycles"
    assert details[:message] =~ "UntouchedTest :: fails"
    assert %{decision: :pending, recovery: "loop"} = recover(ctx)
    assert %{decision: :pending, recovery: "loop"} = recover(ctx)
    refute_received {:attention, "ticket.3864.pr.ci_recovery.loop", _}
    assert writes(ctx) == []
    assert :ok = CiRecovery.record_pass(ctx.issue, ctx.result, ctx.opts)
    assert %{decision: :pending, recovery: "rerun_requested"} = recover(ctx)
  end

  test "corrupt journal fails closed before GitHub writes", ctx do
    for content <- ["invalid json", Jason.encode!(%{"3864" => %{"pr" => 42}})] do
      File.write!(ctx.path, content)
      assert %{decision: :pending, recovery: "evidence_unavailable"} = recover(ctx)
      assert writes(ctx) == []
    end
  end

  test "rerun waiting does not deliver the old failure; ten-minute delay escalates", ctx do
    Agent.update(ctx.agent, &%{&1 | advance: false})
    first_opts = Keyword.put(ctx.opts, :ci_recovery_now, 1000)
    CiRecovery.recover(ctx.issue, ctx.result, first_opts)
    assert %{decision: :pending, recovery: "rerun_pending"} = CiRecovery.recover(ctx.issue, ctx.result, Keyword.put(ctx.opts, :ci_recovery_now, 1100))
    refute_received {:attention, "ticket.3864.pr.ci_recovery.rerun_stuck", _}
    assert %{recovery: "rerun_stuck"} = CiRecovery.recover(ctx.issue, ctx.result, Keyword.put(ctx.opts, :ci_recovery_now, 1600))
    assert_received {:attention, "ticket.3864.pr.ci_recovery.rerun_stuck", _}
  end

  test "lifecycle holds the rerun then hands a full current-head pass to the agent", ctx do
    setup_lifecycle(ctx)

    poll = fn state, result ->
      CiLifecycle.poll_github_ci(state, ctx.opts ++ [ci_issue_fetcher: fn _ -> {:ok, [ctx.issue]} end, ci_poller: fn _, _ -> {:ok, %{results: [result], errors: []}} end])
    end

    state = poll.(empty_orchestrator_state(), ctx.result)
    refute_received {:ci_watcher_update, "3864", "rework"}
    assert state.ci_lifecycle.poll_cache["3864"].recovery == "rerun_requested"
    snapshot = SnapshotPayload.snapshot_payload(state)
    assert capture_io(fn -> CiWait.print(snapshot) end) =~ "CI WAIT 3864 PR #42: rerun_requested"
    assert state.running == %{}
    poll.(state, %{ctx.result | decision: :passed, failures: []})
    assert_received {:ci_watcher_update, "3864", "in-progress"}
    assert length(writes(ctx)) == 1
  end

  test "status lists held CI even without a running agent", ctx do
    output =
      capture_io(fn -> CiWait.print(%{ci_wait: [%{identifier: "3864", pr_number: 42, recovery: "loop", failures: ctx.result.failures}]}) end)

    assert output == "CI WAIT 3864 PR #42: loop (test)\n"
  end

  test "lifecycle counts three same-head rework cycles and keeps the fourth held", ctx do
    setup_lifecycle(ctx)
    Agent.update(ctx.agent, &%{&1 | changed: ["src/test/untouched_test.exs"]})

    state =
      Enum.reduce(1..3, empty_orchestrator_state(), fn n, state ->
        issue = %{ctx.issue | updated_at: DateTime.from_unix!(n)}
        state = lifecycle_poll(state, ctx, issue)
        assert_received {:ci_watcher_update, "3864", "rework"}
        state
      end)

    assert_received {:attention, "ticket.3864.pr.ci_recovery.loop", details}
    assert details[:message] =~ "UntouchedTest :: fails"
    state = lifecycle_poll(state, ctx, %{ctx.issue | updated_at: DateTime.from_unix!(4)})
    refute_received {:ci_watcher_update, "3864", "rework"}
    refute_received {:attention, "ticket.3864.pr.ci_recovery.loop", _}
    assert state.ci_lifecycle.poll_cache["3864"].recovery == "loop"
    agent = control_test_agent(self())
    on_exit(fn -> if Process.alive?(agent), do: Process.exit(agent, :kill) end)
    parked = human_review_running_state("3864", agent).running["3864"]
    parked = %{parked | issue: ctx.issue, control: confirmed_control(:paused)} |> Map.put(:paused_reason, :ci_wait)
    state = %{state | running: %{"3864" => parked}} |> CiLifecycle.arm_ci_wait_rewake(ctx.issue)
    timer = state.ci_lifecycle.rewakes["3864"]
    Process.cancel_timer(timer.timer_ref)
    state = CiLifecycle.handle_ci_wait_rewake(state, "3864", timer.token, issue_fetcher: fn _ -> {:ok, [ctx.issue]} end)
    refute_received {:ci_watcher_update, "3864", "in-progress"}
    assert state.running["3864"].issue.state == "ci-wait"
  end

  defp lifecycle_poll(state, ctx, issue) do
    CiLifecycle.poll_github_ci(state, ctx.opts ++ [ci_issue_fetcher: fn _ -> {:ok, [issue]} end, ci_poller: fn _, _ -> {:ok, %{results: [ctx.result], errors: []}} end])
  end

  defp setup_lifecycle(ctx) do
    previous = Application.get_env(:aiur, :github_client_module)
    recipient = Application.get_env(:aiur, :ci_watcher_recipient)
    store = Application.get_env(:aiur, :ci_approval_store_path)
    Application.put_env(:aiur, :github_client_module, CIWatcherGitHubClient)
    Application.put_env(:aiur, :ci_watcher_recipient, self())
    Application.put_env(:aiur, :ci_approval_store_path, ctx.path <> ".approvals")

    on_exit(fn ->
      restore_application_env(:github_client_module, previous)
      restore_application_env(:ci_watcher_recipient, recipient)
      restore_application_env(:ci_approval_store_path, store)
    end)
  end

  defp recover(ctx), do: CiRecovery.recover(ctx.issue, ctx.result, ctx.opts)
  defp requests(ctx), do: Agent.get(ctx.agent, & &1.requests)

  defp writes(ctx),
    do:
      requests(ctx)
      |> Enum.reject(&(&1.method == :get or &1.url == "https://api.github.com/graphql"))
      |> Enum.map(&{&1.method, URI.parse(&1.url).path |> String.replace_prefix("/repos/owner/repo", "")})

  defp response(%{method: :post, url: "https://api.github.com/graphql"}, state, _, _) do
    ok(%{
      "data" => %{
        "repository" => %{
          "pullRequest" => %{
            "state" => "OPEN",
            "headRefOid" => "head-1",
            "isDraft" => false,
            "baseRefName" => "main",
            "mergeable" => "MERGEABLE",
            "mergeStateStatus" => if(state.behind, do: "BEHIND", else: "CLEAN"),
            "mergeQueueEntry" => if(state.queued, do: %{"id" => "queued"}, else: nil)
          }
        }
      }
    })
  end

  defp response(%{method: method, url: url}, state, agent, path) when method in [:put, :post] do
    assert {:ok, entries} = JsonStore.read(path)

    if method == :post do
      assert get_in(entries, ["3864", "heads", "head-1", "runs"]) == [%{"id" => 99, "attempt" => 1}]
      if state.permission and state.advance, do: Agent.update(agent, &%{&1 | attempt: &1.attempt + 1})
    else
      assert get_in(entries, ["3864", "updated", "sha"]) == "head-1"
    end

    assert String.contains?(url, "rerun-failed-jobs") or String.ends_with?(url, "update-branch")
    if state.permission, do: {:ok, %{status: 202, body: %{}}}, else: {:ok, %{status: 403, body: %{"message" => "Resource not accessible by integration"}}}
  end

  defp response(%{url: url}, state, _, _) do
    cond do
      String.contains?(url, "/check-runs?") ->
        ok(%{"check_runs" => [%{"id" => 1, "name" => "test", "status" => "completed", "conclusion" => "failure", "html_url" => "https://github.com/owner/repo/actions/runs/99/job/1"}]})

      String.ends_with?(url, "/status") ->
        ok(%{"statuses" => []})

      String.contains?(url, "/annotations?") ->
        ok([%{"title" => "aiur-test-failure", "annotation_level" => "failure", "message" => "new-failure :: UntouchedTest :: fails", "path" => "src/test/untouched_test.exs"}] ++ state.extra)

      String.contains?(url, "/contents/") ->
        ok(%{"encoding" => "base64", "content" => Base.encode64(if(state.known, do: "UntouchedTest :: fails", else: ""))})

      String.contains?(url, "/issues?") ->
        ok([])

      String.contains?(url, "/files?") ->
        ok(Enum.map(state.changed, &%{"filename" => &1, "status" => "modified"}))

      String.ends_with?(url, "/actions/runs/99") ->
        ok(%{"head_sha" => "head-1", "run_attempt" => state.attempt, "status" => "completed"})
    end
  end

  defp ok(body), do: {:ok, %{status: 200, body: body, headers: []}}
end
