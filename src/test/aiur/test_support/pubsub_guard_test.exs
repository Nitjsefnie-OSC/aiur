defmodule Aiur.TestSupport.PubSubGuardTest do
  use ExUnit.Case, async: false

  alias Aiur.TestSupport.OrchestratorGuard

  test "verify_restored! names and restores a missing Aiur.PubSub", context do
    pubsub = Process.whereis(Aiur.PubSub)
    assert is_pid(pubsub)
    assert Process.unregister(Aiur.PubSub)

    on_exit(fn -> Process.register(pubsub, Aiur.PubSub) end)

    assert_raise RuntimeError, ~r/PubSubGuardTest: test verify_restored! names and restores .* left Aiur.PubSub unregistered/, fn ->
      OrchestratorGuard.verify_restored!(context)
    end

    assert is_nil(Process.whereis(Aiur.PubSub))
  end

  test "verify_suite! names the last test when Aiur.PubSub is unregistered" do
    pubsub = Process.whereis(Aiur.PubSub)
    assert is_pid(pubsub)
    assert Process.unregister(Aiur.PubSub)

    on_exit(fn -> Process.register(pubsub, Aiur.PubSub) end)

    assert_raise RuntimeError, ~r/test suite found Aiur.PubSub unregistered after .*upper bound only/, fn ->
      OrchestratorGuard.verify_suite!()
    end
  end
end
