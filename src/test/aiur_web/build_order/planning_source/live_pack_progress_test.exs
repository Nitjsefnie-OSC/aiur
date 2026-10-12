defmodule AiurWeb.BuildOrder.PlanningSource.LivePackProgressTest do
  use ExUnit.Case, async: false

  alias Aiur.Orchestrator.{SnapshotCache, SnapshotStore}
  alias Aiur.TrackerIdentity
  alias AiurWeb.BuildOrder.PlanningSource.LivePackProgress

  test "reads poll labels without waiting for an unresponsive Orchestrator mailbox" do
    {:ok, identity} =
      TrackerIdentity.from_github(
        %{"number" => 4101, "node_id" => "I_live_4101"},
        {"acme", "widgets"},
        {"acme", "widgets"}
      )

    original = Process.whereis(Aiur.Orchestrator)
    if is_pid(original), do: Process.unregister(Aiur.Orchestrator)
    busy = spawn(fn -> Process.sleep(:infinity) end)
    Process.register(busy, Aiur.Orchestrator)
    retained = SnapshotCache.get(Aiur.Orchestrator)

    :ok =
      SnapshotStore.publish(Aiur.Orchestrator, %{
        running: [%{tracker_identity: identity, labels: ["agent:rework"]}],
        retrying: [],
        idle: []
      })

    on_exit(fn ->
      Process.exit(busy, :kill)
      if retained, do: SnapshotCache.put(Aiur.Orchestrator, retained), else: SnapshotStore.forget(Aiur.Orchestrator)

      if is_pid(original) and Process.alive?(original) and is_nil(Process.whereis(Aiur.Orchestrator)),
        do: Process.register(original, Aiur.Orchestrator)
    end)

    task = Task.async(fn -> LivePackProgress.current_poll_labels() end)
    key = TrackerIdentity.github_key(identity)
    assert {:ok, %{^key => ["agent:rework"]}} = Task.yield(task, 2_000)
  end
end
