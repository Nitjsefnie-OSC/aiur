Code.require_file("../support/browser_harness/fixture_endpoint_start.ex", __DIR__)

defmodule Aiur.BrowserHarness.FixtureServerTest do
  use ExUnit.Case, async: true

  alias Aiur.BrowserHarness.FixtureEndpointStart

  test "an occupied fixture port is retried with an OS-assigned port" do
    caller = self()
    occupied = {:shutdown, {:failed_to_start_child, Aiur.BrowserHarness.FixtureEndpoint, {:shutdown, {:failed_to_start_child, :listener, :eaddrinuse}}}}

    assert {:ok, ^caller} =
             FixtureEndpointStart.start(
               fn port ->
                 send(caller, {:attempted_port, port})

                 if port == 43_105,
                   do: linked_start_failure(occupied),
                   else: {:ok, caller}
               end,
               43_105
             )

    assert_received {:attempted_port, 43_105}
    assert_received {:attempted_port, 0}
  end

  defp linked_start_failure(reason) do
    pid = spawn_link(fn -> exit(reason) end)
    monitor = Process.monitor(pid)
    assert_receive {:DOWN, ^monitor, :process, ^pid, ^reason}, 1_000
    {:ok, self()}
  end
end
