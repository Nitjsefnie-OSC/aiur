defmodule Aiur.TestSupport.PubSubGuardTest do
  use ExUnit.Case, async: false

  alias Aiur.TestSupport.OrchestratorGuard

  test "verify_restored! reports and restores a terminated Aiur.PubSub child", context do
    assert is_pid(Process.whereis(Aiur.PubSub))
    on_exit(fn -> Aiur.TestSupport.ensure_runtime_children_running() end)
    assert :ok = Supervisor.terminate_child(Aiur.Supervisor, Phoenix.PubSub.Supervisor)

    assert_raise RuntimeError, ~r/PubSubGuardTest: test verify_restored! reports and restores .* left Aiur.PubSub unregistered \(restore: :ok\)/, fn ->
      OrchestratorGuard.verify_restored!(context)
    end

    assert is_pid(Process.whereis(Aiur.PubSub))
  end

  test "verify_suite! reports when the Aiur.PubSub name is missing" do
    pubsub = Process.whereis(Aiur.PubSub)
    assert is_pid(pubsub)
    on_exit(fn -> Process.register(pubsub, Aiur.PubSub) end)
    assert Process.unregister(Aiur.PubSub)

    assert_raise RuntimeError, ~r/test suite found Aiur.PubSub unregistered after .*upper bound only/, fn ->
      OrchestratorGuard.verify_suite!()
    end
  end
end
