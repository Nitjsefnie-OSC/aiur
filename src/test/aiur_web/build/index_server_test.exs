defmodule AiurWeb.Build.IndexServerTest do
  use ExUnit.Case, async: false
  import Aiur.TestSupport, only: [receive_barrier: 1]
  import Aiur.TestSupport.BuildHome.IndexParts
  alias Aiur.BuildOrder.Index, as: Core
  alias AiurWeb.Build.Index

  setup do
    Core.subscribe()
    parent = self()
    opts = [name: nil, subscribe: fn -> :ok end,
      read: fn dirty, _previous, _opts ->
        send(parent, {:read_started, self(), dirty})
        receive do
          {:return, parts} -> parts
          :crash -> exit(:killed_read)
        end
      end,
      timer: fn pid, message, ms -> send(parent, {:timer, pid, message, ms}); make_ref() end,
      daemon_timer: fn _pid, _, _ -> make_ref() end,
      daemon_read: fn _ -> %{state: "live", heartbeat_at: 1, observed_at: 2} end,
      clock: &now/0]
    pid = start_supervised!({Index, opts})
    receive_barrier({:read_started, worker, :all})
    :erlang.trace(pid, true, [:receive])
    send(worker, {:return, parts()})
    result_barrier(pid)
    drain_changes()
    %{pid: pid}
  end

  test "40 signals schedule one read and broadcast one diff to all subscribers", %{pid: pid} do
    subscribers = for _ <- 1..4, do: subscriber()
    # Trace production calls rather than VM-global memory, which unrelated processes can change.
    :erlang.trace(pid, true, [:call, :set_on_spawn])
    :erlang.trace_pattern({:persistent_term, :put, 2}, true, [])
    on_exit(fn -> :erlang.trace_pattern({:persistent_term, :put, 2}, false, []) end)
    for _ <- 1..40, do: send(pid, {:running_changed, %{}})
    :sys.get_state(pid)
    assert_received {:timer, ^pid, :flush, 250}
    refute_received {:timer, ^pid, :flush, _}
    refute_received {:read_started, _, _}
    send(pid, :flush)
    receive_barrier({:read_started, worker, dirty})
    assert MapSet.member?(dirty, :now)
    send(worker, {:return, put_in(parts(), [:now, :rows], %{"12" => now_row(12)})})
    result_barrier(pid)
    assert_received {:build_changes, change}
    assert Enum.map(change.upsert, & &1.id) == ["12"]
    assert change.resync == false
    refute Map.has_key?(change, :sections)
    refute Map.has_key?(change.set, :usage)
    refute_received {:build_changes, _}
    for subscriber <- subscribers do
      assert {:message_queue_len, count} = Process.info(subscriber, :message_queue_len)
      assert count <= 1
      send(subscriber, :stop)
    end
    refute_received {:trace, _, :call, {:persistent_term, :put, _}}
  end

  test "no-op reread emits nothing; a slow read leaves cached windows available", %{pid: pid} do
    send(pid, {:running_changed, %{}})
    :sys.get_state(pid)
    send(pid, :flush)
    receive_barrier({:read_started, worker, _dirty})
    {micros, {:ok, snapshot}} = :timer.tc(fn -> GenServer.call(pid, {:window, "Etc/UTC"}) end)
    assert micros < 100_000
    assert snapshot.sections.now == []
    send(worker, {:return, parts()})
    result_barrier(pid)
    refute_received {:build_changes, _}
  end

  test "signals during a read survive as one following window; moves do not remove the same id", %{pid: pid} do
    send(pid, {:build_progress_changed, %{}})
    :sys.get_state(pid)
    send(pid, :flush)
    receive_barrier({:read_started, worker, _})
    send(pid, {:running_changed, %{}})
    :sys.get_state(pid)
    first = put_in(parts(), [:planned, :rows], [plan_row(12), plan_row(41)])
    send(worker, {:return, first})
    result_barrier(pid)
    assert_received {:build_changes, _}
    assert_received {:timer, ^pid, :flush, 250}
    send(pid, :flush)
    receive_barrier({:read_started, worker, _})
    second = parts() |> put_in([:now, :rows], %{"12" => now_row(12)}) |> put_in([:planned, :rows], [plan_row(640)])
    send(worker, {:return, second})
    result_barrier(pid)
    assert_received {:build_changes, change}
    assert Enum.map(change.upsert, & &1.id) == ~w(12 640)
    assert change.remove == ["41"]
    refute_received {:build_changes, _}
  end

  test "read task failure keeps the owner alive and marks affected sources unavailable", %{pid: pid} do
    send(pid, {:running_changed, %{}})
    :sys.get_state(pid)
    send(pid, :flush)
    receive_barrier({:read_started, worker, _})
    send(worker, :crash)
    receive_barrier({:trace, ^pid, :receive, {:DOWN, _ref, :process, ^worker, :killed_read}})
    :sys.get_state(pid)
    assert Process.alive?(pid)
    assert_received {:build_changes, %{resync: true} = changes}
    refute Map.has_key?(changes, :sections)
    assert {:error, :epic_config_unavailable} = GenServer.call(pid, {:window, "Etc/UTC"})
  end

  defp subscriber do
    parent = self()
    pid = spawn_link(fn ->
      Core.subscribe()
      send(parent, {:subscribed, self()})
      receive do: (:stop -> :ok)
    end)
    receive_barrier({:subscribed, ^pid})
    pid
  end

  defp result_barrier(pid) do
    receive_barrier({:trace, ^pid, :receive, {_ref, %{settings: _settings}}})
    :sys.get_state(pid)
  end
  defp drain_changes do
    receive do
      {:build_changes, _} -> drain_changes()
    after
      0 -> :ok
    end
  end
end
