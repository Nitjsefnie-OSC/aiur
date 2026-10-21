defmodule AiurWeb.HostAllowlistTest do
  use Aiur.TestSupport, async: true

  alias Aiur.TestSupport.EndpointStubs
  alias AiurWeb.HostAllowlist

  test "rejects a foreign Host before downstream endpoint plugs" do
    EndpointStubs.put(allowed_hosts: ["dashboard.example"])
    conn = Plug.Test.conn(:get, "/") |> then(&%{&1 | host: "attacker.example"})
    conn = HostAllowlist.call(conn, [])

    assert conn.status == 403
    assert conn.halted
    assert conn.resp_body == "Forbidden"
  end

  test "accepts an allowlisted Host with a port" do
    EndpointStubs.put(allowed_hosts: ["dashboard.example"])
    conn = Plug.Test.conn(:get, "/") |> then(&%{&1 | host: "dashboard.example"})

    assert %Plug.Conn{halted: false} = HostAllowlist.call(conn, [])
  end

  test "allows configured public hosts and loopback with request ports" do
    assert HostAllowlist.allowed_hosts("https://dashboard.example.com") ==
             ["dashboard.example.com", "localhost", "127.0.0.1", "[::1]", "::1"]
  end

  test "derives websocket origins from the public URL and loopback" do
    assert HostAllowlist.origins("https://dashboard.example.com:8443") == [
             "https://dashboard.example.com:8443",
             "//localhost",
             "//127.0.0.1",
             "//[::1]"
           ]
  end
end
