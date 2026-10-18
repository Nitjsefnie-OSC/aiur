defmodule Aiur.GitHub.ResourceStore.CheckpointTest do
  use Aiur.TestSupport

  alias Aiur.GitHub.ResourceStore
  alias Aiur.GitHub.ResourceStore.Checkpoint

  test "an unchanged periodic checkpoint skips rendering", %{path: path} do
    restart_store!(path)
    key = ResourceStore.key(:issue, "owner", "repo", 9901)
    ResourceStore.put_resource(key, %{"number" => 9901})
    assert :ok = ResourceStore.flush()

    test_pid = self()
    handler_id = "resource-store-checkpoint-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        handler_id,
        [:aiur, :github, :resource_store, :checkpoint],
        fn _event, measurements, metadata, pid ->
          send(pid, {:checkpoint, measurements, metadata})
        end,
        test_pid
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    send(Process.whereis(ResourceStore), :checkpoint)

    assert_receive {:checkpoint, %{entries: 1}, %{result: :unchanged}}, 1_000
    assert ResourceStore.data(key) == %{"number" => 9901}
  end

  test "a mutation after flush makes the next periodic checkpoint write", %{path: path} do
    restart_store!(path)
    first_key = ResourceStore.key(:issue, "owner", "repo", 9901)
    second_key = ResourceStore.key(:issue, "owner", "repo", 9902)
    ResourceStore.put_resource(first_key, %{"number" => 9901})
    assert :ok = ResourceStore.flush()

    test_pid = self()
    handler_id = "resource-store-checkpoint-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        handler_id,
        [:aiur, :github, :resource_store, :checkpoint],
        fn _event, measurements, metadata, pid ->
          send(pid, {:checkpoint, measurements, metadata})
        end,
        test_pid
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    ResourceStore.put_resource(second_key, %{"number" => 9902})
    send(Process.whereis(ResourceStore), :checkpoint)

    assert_receive {:checkpoint, %{entries: 2}, %{result: :written}}, 1_000
    assert {:ok, contents} = File.read(path)
    assert %{"entries" => entries} = Jason.decode!(contents)
    assert Map.has_key?(entries, "issue|owner|repo|9902")
  end

  test "forgetting an entry removes it from the next periodic checkpoint", %{path: path} do
    restart_store!(path)
    key = ResourceStore.key(:issue, "owner", "repo", 9903)
    ResourceStore.put_resource(key, %{"number" => 9903})
    assert :ok = ResourceStore.flush()
    ResourceStore.forget(key)

    test_pid = self()
    handler_id = "resource-store-checkpoint-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        handler_id,
        [:aiur, :github, :resource_store, :checkpoint],
        fn _event, measurements, metadata, pid -> send(pid, {:checkpoint, measurements, metadata}) end,
        test_pid
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    send(Process.whereis(ResourceStore), :checkpoint)

    assert_receive {:checkpoint, %{entries: 0}, %{result: :written}}, 1_000
    assert {:ok, contents} = File.read(path)
    assert %{"entries" => %{}} = Jason.decode!(contents)
  end

  test "checkpoint encoding reuses unchanged entries and refreshes only a dirty key", %{path: path} do
    restart_store!(path)
    first_key = ResourceStore.key(:issue, "owner", "repo", 9904)
    second_key = ResourceStore.key(:issue, "owner", "repo", 9905)
    first_entry = %{recorded_at_ms: 1}
    second_entry = %{recorded_at_ms: 1}
    parent = self()

    encode = fn entry ->
      send(parent, {:encoded, entry})
      Jason.encode!(entry)
    end

    Checkpoint.cached_entry(first_key, first_entry, encode)
    Checkpoint.cached_entry(second_key, second_entry, encode)
    Checkpoint.cached_entry(first_key, first_entry, encode)
    assert_received {:encoded, ^first_entry}
    assert_received {:encoded, ^second_entry}
    refute_received {:encoded, _entry}

    Checkpoint.mark_entry_dirty(first_key)
    Checkpoint.cached_entry(first_key, first_entry, encode)
    assert_received {:encoded, ^first_entry}
    Checkpoint.cached_entry(second_key, second_entry, encode)
    refute_received {:encoded, _entry}
  end

  setup do
    dir = Aiur.TestSupport.tmp_root!("aiur-resource-store-checkpoint")
    File.mkdir_p!(dir)
    path = Path.join(dir, "github_resources.json")

    on_exit(fn ->
      Application.delete_env(:aiur, :github_resource_store_path)
      ResourceStore.reset()
      Aiur.TestCleanup.rm_rf!(dir)
    end)

    {:ok, path: path}
  end

  defp stop_store! do
    case Process.whereis(ResourceStore) do
      nil ->
        :ok

      pid ->
        ref = Process.monitor(pid)
        Supervisor.terminate_child(Aiur.Supervisor, ResourceStore)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        after
          5_000 -> flunk("ResourceStore did not stop")
        end
    end
  end

  defp restart_store!(path) do
    stop_store!()
    Application.put_env(:aiur, :github_resource_store_path, path)
    {:ok, _pid} = Supervisor.restart_child(Aiur.Supervisor, ResourceStore)
    :ok
  end
end
