defmodule Aiur.BrowserHarness.IndexLiveFixture do
  @moduledoc false
  use Phoenix.Controller, formats: []
  alias Aiur.TestSupport.BuildHome.{FixtureSource, IndexSeed}
  alias AiurWeb.Build.{Index, IndexSource}

  defmodule Daemon do
    def read_daemon(_), do: %{state: "live", heartbeat_at: 1_791_408_000_000, observed_at: 1_791_408_000_000}
  end

  def configure(conn, _params) do
    name = __MODULE__.Index

    unless Process.whereis(name) do
      dir = Path.join(System.tmp_dir!(), "aiur-index-live-#{System.unique_integer([:positive])}")
      seed = IndexSeed.start("live", dir)
      # Fixture server owns these temporary stores for its lifetime.
      Enum.each(seed.processes, &Process.unlink/1)
      {:ok, pid} = Index.start_link(name: name, subscribe: fn -> :ok end, read: fn _, _, _ -> seed.parts end, daemon_read: &Daemon.read_daemon/1, clock: fn -> seed.data["now"] end)
      Process.unlink(pid)
    end

    Application.put_env(:aiur, :build_data_source, {IndexSource, [server: name, usage: FixtureSource, freshness: Daemon]})
    query = if conn.query_string == "", do: "", else: "?" <> conn.query_string
    redirect(conn, to: "/build" <> query)
  end
end
