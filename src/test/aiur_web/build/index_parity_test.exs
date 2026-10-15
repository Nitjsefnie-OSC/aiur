defmodule AiurWeb.Build.IndexParityTest do
  use ExUnit.Case, async: false
  alias Aiur.BuildOrder.Index, as: Core
  alias Aiur.TestSupport.BuildHome.{FixtureSource, IndexSeed}
  alias AiurWeb.Build.{Index, IndexSource, Payload}

  defmodule UsageStub do
    def read(_, _), do: AiurWeb.Build.Usage.read(:locked)
    def subscribe(_), do: :ok
  end

  defmodule FreshnessStub do
    def read_daemon(_), do: %{state: "live", heartbeat_at: 1, observed_at: 2}
  end

  for dataset <- ~w(live noqueue newrepo) do
    @dataset dataset
    test "real stores reproduce the contractual fixture fields for #{@dataset}" do
      dir = Aiur.TestSupport.tmp_root!("index-parity")
      on_exit(fn -> Aiur.TestCleanup.rm_rf!(dir) end)
      seed = IndexSeed.start(@dataset, dir)
      on_exit(fn -> IndexSeed.stop(seed) end)

      index =
        start_supervised!(
          {Index,
           name: nil,
           subscribe: fn -> :ok end,
           read: fn _, _, _ -> seed.parts end,
           daemon_read: &FreshnessStub.read_daemon/1,
           daemon_timer: fn _, _, _ -> make_ref() end,
           clock: fn -> seed.data["now"] end}
        )

      assert {:ok, snapshot} = IndexSource.snapshot(server: index, time_zone: "America/Los_Angeles", financial: :locked, usage: UsageStub, freshness: FreshnessStub)
      actual = Payload.scrub(snapshot)
      assert Payload.validate(Payload.snapshot(snapshot, "parity", 0)) == :ok
      assert {:ok, expected} = FixtureSource.snapshot(dataset: @dataset, time_zone: "America/Los_Angeles")
      assert actual["epics"] == expected["epics"]
      assert actual["order"] == expected["order"]
      assert actual["counts"] == expected["counts"]
      assert Map.take(actual["history"], ~w(from more total undated tz)) == expected["history"]

      assert Map.new(actual["features"], fn {slug, feature} -> {slug, Map.delete(feature, "stats")} end) ==
               Map.new(expected["features"], fn {slug, feature} -> {slug, Map.delete(feature, "stats")} end)

      for sec <- ~w(hist now plan nq) do
        actual_rows = Map.new(actual["sections"][sec], &{&1["id"], comparable(&1)})
        expected_rows = Map.new(expected["sections"][sec], &{&1["id"], comparable(&1)})
        assert actual_rows == expected_rows
        assert Enum.map(actual["sections"][sec], & &1["id"]) == Enum.map(expected["sections"][sec], & &1["id"])
      end

      assert {:ok, whole} = Core.assemble(seed.parts, now: seed.data["now"])
      assert length(whole.hist) == seed.data["history"]["total"]
      IndexSeed.stop(seed)
    end
  end

  defp comparable(row) do
    # Frozen demo ordinals, estimates and display names predate the producer contracts.
    # History has no failed-PR fact; its demo failure becomes a cause-neutral closure.
    row
    |> Map.drop(~w(ord est override dep_states deps_missing start_src))
    |> Map.update!("agent", fn
      nil -> nil
      agent -> Map.delete(agent, "name")
    end)
    |> Map.update!("status", &if(&1 == "failed", do: "closed", else: &1))
    |> Map.update!("pct", &if(row["status"] == "failed", do: nil, else: &1))
    |> Map.update!("deps", &Enum.sort/1)
    |> Map.update!("children", &Enum.sort/1)
  end
end
