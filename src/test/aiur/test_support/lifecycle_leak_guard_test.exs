defmodule Aiur.TestSupport.LifecycleLeakGuardTest do
  # Not async: check!/0 drains the suite-wide leak table.
  use Aiur.TestSupport

  alias Aiur.Signal
  alias Aiur.TestSupport.LifecycleLeakGuard

  test "a runner left alive by a finished test is stopped at its first lifecycle write and fails the suite" do
    parent = self()
    previous = Application.get_env(:aiur, :run_telemetry_lifecycle_recorder)
    Application.put_env(:aiur, :run_telemetry_lifecycle_recorder, fn _kind, attrs, _ -> send(parent, {:record, attrs.event}) end)

    on_exit(fn ->
      if previous, do: Application.put_env(:aiur, :run_telemetry_lifecycle_recorder, previous), else: Application.delete_env(:aiur, :run_telemetry_lifecycle_recorder)
    end)

    # A stand-in test process that starts a runner and never stops it.
    {owner, owner_ref} =
      spawn_monitor(fn ->
        LifecycleLeakGuard.track(%{module: LeakProbe, test: :"test leaks its runner"})
        {:ok, runner} = Task.start(fn -> write_on_demand(parent) end)
        send(parent, {:runner, runner})
      end)

    assert_receive {:runner, runner}, 1_000
    assert_receive {:DOWN, ^owner_ref, :process, ^owner, :normal}, 1_000
    on_exit(fn -> Process.exit(runner, :kill) end)

    # Teardown has not finished yet, so the runner's write is still its own test's.
    send(runner, :write)
    assert_receive {:written, ^runner}, 1_000
    assert_received {:record, "agent_spinup"}
    assert :ok = LifecycleLeakGuard.check!()

    LifecycleLeakGuard.finish(owner)
    runner_ref = Process.monitor(runner)
    send(runner, :write)
    assert_receive {:DOWN, ^runner_ref, :process, ^runner, :killed}, 1_000
    refute_received {:written, ^runner}
    refute_received {:record, _event}

    error = assert_raise RuntimeError, &LifecycleLeakGuard.check!/0
    assert error.message =~ "LeakProbe test leaks its runner: {#{inspect(runner)}, "
    assert error.message =~ "wrote agent_spinup"
    assert :ok = LifecycleLeakGuard.check!()
  end

  test "a supervised runner still resolves to its test after the orchestrator that spawned it died" do
    parent = self()

    # Dispatch shape: the test owns an orchestrator, which records a dispatch
    # point and starts an unlinked runner under Aiur.TaskSupervisor.
    {owner, owner_ref} =
      spawn_monitor(fn ->
        LifecycleLeakGuard.track(%{module: LeakProbe, test: :"test leaks a dispatched runner"})

        # A GenServer carries only `$ancestors`, so the runner's `$callers` stops at it.
        {:ok, orchestrator} = Agent.start(fn -> :ok end)

        Agent.update(orchestrator, fn :ok ->
          Signal.lifecycle("4733", "4733:leak", :dispatch, :point)
          {:ok, runner} = Task.Supervisor.start_child(Aiur.TaskSupervisor, fn -> write_on_demand(parent) end)
          send(parent, {:runner, runner})
        end)

        Agent.stop(orchestrator)
      end)

    assert_receive {:runner, runner}, 1_000
    assert_receive {:DOWN, ^owner_ref, :process, ^owner, :normal}, 1_000
    on_exit(fn -> Process.exit(runner, :kill) end)

    LifecycleLeakGuard.finish(owner)
    runner_ref = Process.monitor(runner)
    send(runner, :write)
    assert_receive {:DOWN, ^runner_ref, :process, ^runner, :killed}, 1_000

    error = assert_raise RuntimeError, &LifecycleLeakGuard.check!/0
    assert error.message =~ "LeakProbe test leaks a dispatched runner: {#{inspect(runner)}, "
  end

  defp write_on_demand(parent) do
    receive do
      :write ->
        Signal.lifecycle("4733", "4733:leak", :agent_spinup, :start)
        send(parent, {:written, self()})
        write_on_demand(parent)
    end
  end
end
