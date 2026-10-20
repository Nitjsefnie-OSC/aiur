defmodule Aiur.TestSupport.PubSubGuardTest do
  use ExUnit.Case, async: false

  alias Aiur.TestSupport.OrchestratorGuard

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
