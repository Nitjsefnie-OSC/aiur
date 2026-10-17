defmodule Aiur.TestSupport.LifecycleLeakGuardTest do
  # Not async: the guard tables are suite-wide.
  use Aiur.TestSupport

  alias Aiur.Signal
  alias Aiur.TestSupport.LifecycleLeakGuard

  test "teardown fails the test that leaves a dispatched runner alive" do
    parent = self()
    previous_signal = Application.get_env(:aiur, :signal)
    Application.put_env(:aiur, :signal, lifecycle_sink: LifecycleLeakGuard)

    on_exit(fn -> Application.put_env(:aiur, :signal, previous_signal) end)

    owner =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    runner =
      spawn(fn ->
        receive do
          :write ->
            Signal.lifecycle("4733", "4733:leak", :agent_spinup, :start)
            send(parent, {:written, self()})
        end
      end)

    name = "LeakProbe test leaks its dispatched runner"

    :ets.insert(:"Elixir.Aiur.TestSupport.LifecycleLeakGuard.Tests", {owner, name, false})
    :ets.insert(:"Elixir.Aiur.TestSupport.LifecycleLeakGuard.Owners", {runner, owner})

    error = assert_raise RuntimeError, fn -> LifecycleLeakGuard.finish!(owner, nil) end
    assert error.message =~ name
    assert error.message =~ inspect(runner)
    refute Process.alive?(runner)
    refute_received {:written, ^runner}

    Process.exit(owner, :kill)
  end

  test "a live runner is detected by its owning test teardown" do
    previous_signal = Application.get_env(:aiur, :signal)
    Application.put_env(:aiur, :signal, lifecycle_sink: LifecycleLeakGuard)
    on_exit(fn -> Application.put_env(:aiur, :signal, previous_signal) end)

    owner = LifecycleLeakGuard.track(%{module: LeakProbe, test: :"test leaks a dispatched runner"})
    {:ok, orchestrator} = Agent.start(fn -> :ok end)

    runner =
      Task.async(fn ->
        Agent.get(orchestrator, fn _ -> :ok end)

        receive do
          :never -> :ok
        end
      end)

    test_pid = self()
    Process.put(:"$callers", [test_pid])
    runner_pid = runner.pid
    :ets.insert(Elixir.Aiur.TestSupport.LifecycleLeakGuard.Owners, {runner_pid, owner})
    Process.unlink(runner_pid)
    Process.exit(orchestrator, :kill)

    error = assert_raise RuntimeError, fn -> LifecycleLeakGuard.finish!(owner, nil) end
    assert error.message =~ "LeakProbe test leaks a dispatched runner"
    assert error.message =~ inspect(runner_pid)
    refute Process.alive?(runner_pid)
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
