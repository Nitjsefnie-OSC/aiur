defmodule Aiur.Orchestrator.DurationCapReleaseTest do
  use ExUnit.Case, async: false

  alias Aiur.Issue
  alias Aiur.Orchestrator.{DurationCapRelease, PauseResume, State}

  setup do
    previous = Application.get_env(:aiur, :duration_cap_release_opts)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:aiur, :duration_cap_release_opts, previous),
        else: Application.delete_env(:aiur, :duration_cap_release_opts)
    end)
  end

  test "a duration-capped run with progress redispatches without an Executor resume" do
    entry = parked_entry() |> Map.put(:workspace_path, "/workspace") |> Map.put(:duration_cap_progress_baseline, "before")
    state = %State{running: %{entry.issue.id => entry}}

    dispatch = fn current, issue, _attempt, _host, _opts ->
      send(self(), {:redispatch, issue.identifier})
      %{current | running: Map.put(current.running, issue.id, %{control: %{status: :working}})}
    end

    opts = [
      workspace_probe: fn _path, _host -> {:ok, "after"} end,
      progress_release_target_fun: fn _ -> {:ok, "rework"} end,
      dispatch_fun: dispatch,
      emit_alert_fun: fn topic, _ -> send(self(), {:alert, topic}) end,
      max_retry_attempts: 3
    ]

    Application.put_env(:aiur, :duration_cap_release_opts, opts)
    released = DurationCapRelease.maybe_release(state, entry, :paused, opts)

    assert Map.has_key?(released.running, entry.issue.id)
    assert_received {:redispatch, "4849"}
    assert_received {:alert, "ticket.4849.agent.attention.paused-max_agent_duration.resolved"}
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
    assert reason =~ "no commits, workpad changes"
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
