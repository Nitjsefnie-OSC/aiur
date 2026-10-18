defmodule Aiur.GitHub.ResourceStore.CheckpointTest do
  use Aiur.TestSupport

  alias Aiur.GitHub.ResourceStore

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
