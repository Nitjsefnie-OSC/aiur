defmodule Aiur.Orchestrator.DurationCapReleaseTest do
  use ExUnit.Case, async: false

  alias Aiur.Issue
  alias Aiur.Orchestrator.{DurationCapRelease, PauseResume, State}

  setup do
    previous = Application.get_env(:aiur, :duration_cap_release_opts)
    previous_store = Application.get_env(:aiur, :dispatch_budget_store_path)
    previous_retry_store = Application.get_env(:aiur, :duration_cap_retry_store_path)
    budget_path = Path.join(Aiur.TestSupport.tmp_root!("duration-cap-release"), "dispatch-budgets.json")
    File.mkdir_p!(Path.dirname(budget_path))
    Application.put_env(:aiur, :dispatch_budget_store_path, budget_path)
    retry_path = Path.join(Path.dirname(budget_path), "duration-cap-retries.json")
    Application.put_env(:aiur, :duration_cap_retry_store_path, retry_path)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:aiur, :duration_cap_release_opts, previous),
        else: Application.delete_env(:aiur, :duration_cap_release_opts)

      if previous_store,
        do: Application.put_env(:aiur, :dispatch_budget_store_path, previous_store),
        else: Application.delete_env(:aiur, :dispatch_budget_store_path)

      if previous_retry_store,
        do: Application.put_env(:aiur, :duration_cap_retry_store_path, previous_retry_store),
        else: Application.delete_env(:aiur, :duration_cap_retry_store_path)

      Aiur.TestCleanup.rm_rf!(Path.dirname(budget_path))
    end)
  end

  test "a duration-capped run with progress redispatches without an Executor resume" do
    entry = parked_entry() |> Map.put(:workspace_path, "/workspace") |> Map.put(:duration_cap_progress_baseline, "before")
    state = %State{running: %{entry.issue.id => entry}}

    dispatch = fn current, issue, attempt, _host, dispatch_opts ->
      send(self(), {:redispatch, issue.identifier, attempt})

      queued =
        current
        |> Map.put(:running, Map.put(current.running, issue.id, %{control: %{status: :working}}))

      dispatch_opts[:dispatch_result_fun].(queued)
    end

    opts = [
      workspace_probe: fn _path, _host -> {:ok, "after"} end,
      progress_release_target_fun: fn _ -> {:ok, "rework"} end,
      dispatch_fun: dispatch,
      emit_alert_fun: fn topic, _ -> send(self(), {:alert, topic}) end,
      max_retry_attempts: 3,
      duration_cap_retry_count_fun: fn _ -> 0 end,
      increment_duration_cap_retry_fun: fn id ->
        send(self(), {:retry_recorded, id})
        :ok
      end
    ]

    Application.put_env(:aiur, :duration_cap_release_opts, opts)
    released = DurationCapRelease.maybe_release(state, entry, :paused, opts)

    assert Map.has_key?(released.running, entry.issue.id)
    assert_received {:redispatch, "4849", 1}
    assert_received {:retry_recorded, "issue-4849"}
    assert_received {:alert, "ticket.4849.agent.attention.paused-max_agent_duration.resolved"}
  end

  test "a duration-capped run with an exhausted retry budget remains paused and escalates" do
    entry = parked_entry() |> Map.put(:workspace_path, "/workspace") |> Map.put(:duration_cap_progress_baseline, "before") |> Map.put(:retry_attempt, 3)
    state = %State{running: %{entry.issue.id => entry}}
    opts = [workspace_probe: fn _, _ -> {:ok, "after"} end, max_retry_attempts: 3, duration_cap_retry_count_fun: fn _ -> 3 end, emit_alert_fun: fn _, a -> send(self(), {:reason, a[:reason]}) end]
    Application.put_env(:aiur, :duration_cap_release_opts, opts)

    paused = DurationCapRelease.maybe_release(state, entry, :paused, opts)

    assert paused.running[entry.issue.id].control.status == :paused
    assert_received {:reason, "retry budget is spent"}
  end

  test "an inactive ticket with progress remains paused and escalates" do
    entry = parked_entry() |> Map.put(:workspace_path, "/workspace") |> Map.put(:duration_cap_progress_baseline, "before")
    entry = %{entry | issue: %{entry.issue | state: "closed"}}
    state = %State{running: %{entry.issue.id => entry}}
    opts = [workspace_probe: fn _, _ -> {:ok, "after"} end, emit_alert_fun: fn _, a -> send(self(), {:reason, a[:reason]}) end]
    Application.put_env(:aiur, :duration_cap_release_opts, opts)

    paused = DurationCapRelease.maybe_release(state, entry, :paused, opts)

    assert paused.running[entry.issue.id].control.status == :paused
    assert_received {:reason, "ticket state is inactive"}
  end

  test "a duration-capped run without progress remains paused and escalates" do
    entry = parked_entry() |> Map.put(:workspace_path, "/workspace") |> Map.put(:duration_cap_progress_baseline, "same")
    state = %State{running: %{entry.issue.id => entry}}

    opts = [
      workspace_probe: fn _path, _host -> {:ok, "same"} end,
      open_pr_fetcher: fn _ -> {:ok, nil} end,
      emit_alert_fun: fn topic, alert_opts -> send(self(), {:alert, topic, alert_opts[:reason]}) end
    ]

    Application.put_env(:aiur, :duration_cap_release_opts, opts)
    released = DurationCapRelease.maybe_release(state, entry, :paused, opts)

    assert released.running[entry.issue.id].control.status == :paused
    assert Map.has_key?(released.running, entry.issue.id)
    assert_received {:alert, "ticket.4849.agent.attention.paused-max_agent_duration", reason}
    assert reason =~ "workpad-only changes do not count"
  end

  test "a release completing after an issue refresh still frees the runner" do
    parked = parked_entry()
    refreshed = %{parked | issue: %{parked.issue | state: "rework", labels: ["agent:rework"]}}
    state = %State{running: %{"issue-4849" => refreshed}, claimed: MapSet.new(["issue-4849"])}

    released = DurationCapRelease.apply_release(state, {:release, "rework", "reason"}, parked, emit_alert_fun: fn _, _ -> :ok end)

    refute Map.has_key?(released.running, "issue-4849")
    refute MapSet.member?(released.claimed, "issue-4849")
  end

  test "a release completing after an operator resume keeps the resumed runner" do
    parked = parked_entry()
    resumed = parked |> Map.delete(:paused_reason) |> Map.put(:control, %{status: :working})
    state = %State{running: %{"issue-4849" => resumed}}

    kept = DurationCapRelease.apply_release(state, {:release, "rework", "reason"}, parked, emit_alert_fun: fn _, _ -> :ok end)

    assert kept.running["issue-4849"] == resumed
  end

  test "a ready PR with progress releases to human review" do
    released =
      DurationCapRelease.apply_release(
        %State{running: %{"issue-4849" => parked_entry()}},
        {:release, "human-review", "progress was detected"},
        parked_entry(),
        emit_alert_fun: fn _, _ -> :ok end
      )

    refute Map.has_key?(released.running, "issue-4849")
  end

  test "a failed progress release remains paused and reports the failure" do
    entry = parked_entry()
    state = %State{running: %{entry.issue.id => entry}}
    result = DurationCapRelease.apply_release(state, {:error, :timeout}, entry, emit_alert_fun: fn _, opts -> send(self(), {:reason, opts[:reason]}) end)
    assert result.running[entry.issue.id].control.status == :paused
    assert_received {:reason, reason}
    assert reason =~ ":timeout"
  end

  # Guard, passes on main too: other pause causes keep their runner.
  test "an operator pause is not released" do
    Application.put_env(:aiur, :duration_cap_release_opts, [])
    state = %State{running: %{"issue-4849" => Map.put(entry(), :paused_reason, :operator_pause)}}

    {:noreply, paused} = PauseResume.handle_worker_control_state(state, "issue-4849", :paused, %{})

    assert paused.running["issue-4849"].control.status == :paused
    refute_received {:write, _target, _expected}
  end

  defp parked_entry, do: %{entry() | control: %{status: :paused}}

  defp entry do
    %{
      pid: nil,
      ref: nil,
      identifier: "4849",
      issue: %Issue{id: "issue-4849", identifier: "4849", state: "in-progress"},
      started_at: DateTime.add(DateTime.utc_now(), -7200, :second),
      paused_reason: :max_agent_duration,
      control: %{status: :working},
      retry_attempt: 0,
      workspace_path: nil,
      worker_host: nil,
      session_id: "session-1"
    }
  end
end
