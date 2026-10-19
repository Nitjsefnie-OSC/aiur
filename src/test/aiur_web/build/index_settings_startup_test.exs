defmodule AiurWeb.Build.IndexSettingsStartupTest do
  use ExUnit.Case, async: false

  import Aiur.TestSupport, only: [receive_barrier: 1]
  import Aiur.TestSupport.BuildHome.IndexParts, only: [now: 0, parts: 0]

  alias AiurWeb.Build.Index

  test "settings loading retries with backoff and recovers without another signal" do
    parent = self()
    loading = %{parts() | settings: {:error, :workflow_not_loaded}}

    pid =
      start_supervised!(
        {Index,
         name: nil,
         subscribe: fn -> :ok end,
         read: fn
           :all, _previous, _opts ->
             loading

           dirty, _previous, _opts ->
             send(parent, {:settings_retry, self(), dirty})
             receive(do: ({:return, value} -> value))
         end,
         timer: fn server, message, ms ->
           send(parent, {:settings_timer, server, message, ms})
           make_ref()
         end,
         daemon_timer: fn _, _, _ -> make_ref() end,
         daemon_read: fn _ -> %{state: "live", heartbeat_at: 1, observed_at: 2} end,
         clock: &now/0},
        id: :settings_loading_index
      )

    assert {:error, :settings_loading} = Index.window(pid, "Etc/UTC")
    assert_receive {:settings_timer, ^pid, :flush, 500}, 1_000
    send(pid, :flush)
    receive_barrier({:settings_retry, worker, dirty})
    assert dirty == MapSet.new([:settings])
    send(worker, {:return, parts()})
    assert await_ready(pid, 100)
    refute_received {:settings_timer, ^pid, :flush, _delay}
  end

  defp await_ready(_pid, 0), do: false

  defp await_ready(pid, attempts) do
    case Index.window(pid, "Etc/UTC") do
      {:ok, _snapshot} ->
        true

      {:error, :settings_loading} ->
        Process.sleep(5)
        await_ready(pid, attempts - 1)
    end
  end
end
