Code.require_file("../support/browser_harness/fixture_endpoint_start.ex", __DIR__)

defmodule Aiur.BrowserHarness.FixtureServerTest do
  use ExUnit.Case, async: true

  alias Aiur.BrowserHarness.FixtureEndpointStart

  test "an occupied fixture port is retried with an OS-assigned port" do
    caller = self()

    assert {:ok, :started} =
             FixtureEndpointStart.start(
               fn port ->
                 send(caller, {:attempted_port, port})

                 if port == 43_105,
                   do: {:error, {:shutdown, {:failed_to_start_child, :listener, :eaddrinuse}}},
                   else: {:ok, :started}
               end,
               43_105
             )

    assert_received {:attempted_port, 43_105}
    assert_received {:attempted_port, 0}
  end
end
