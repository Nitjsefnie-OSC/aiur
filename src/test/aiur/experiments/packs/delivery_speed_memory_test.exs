defmodule Aiur.Experiments.Packs.DeliverySpeedMemoryTest do
  use ExUnit.Case, async: true
  alias Aiur.Experiments.Packs.DeliverySpeed
  alias Aiur.RunTelemetry.Dataset

  @window %{start: ~U[2026-10-09 09:00:00Z], end: ~U[2026-10-09 14:00:00Z]}
  @fixtures Path.expand("../../../fixtures/experiments/telemetry", __DIR__)

  setup do
    root = Path.join(System.tmp_dir!(), "delivery-memory-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> Aiur.TestCleanup.rm_rf!(root) end)
    {:ok, prior} = Dataset.build(Path.join(@fixtures, "boot-a.ndjson"))
    summary = Path.join(root, "prior.json")
    File.write!(summary, Jason.encode!(Aiur.JSONSafe.normalize(prior)))
    owner = self()

    ctx = %{
      telemetry_enabled: true,
      boot_id: "boot-b",
      telemetry_path: Path.join(@fixtures, "boot-b.ndjson"),
      summary_boot_ids: fn -> ["boot-a"] end,
      summary_path: fn "boot-a" -> summary end,
      telemetry_reader_options: [on_open: fn path -> send(owner, {:opened_summary, path}) end]
    }

    %{ctx: ctx, summary: summary}
  end

  test "second evaluation reuses bounded retained history and keeps first dispatch", %{ctx: ctx, summary: summary} do
    for _iteration <- 1..2 do
      {coverage, rows} = DeliverySpeed.observations(["start_to_merge"], @window, ctx)["start_to_merge"]
      assert coverage.state == :captured
      assert Enum.find(rows, &(&1.unit_id == "ticket:101")).value == 9_000_000
      assert Enum.find(rows, &(&1.unit_id == "ticket:101")).at == ~U[2026-10-09 10:00:00Z]
    end

    assert_received {:opened_summary, ^summary}
    refute_received {:opened_summary, _path}
  end

  test "changed summary metadata invalidates cached history", %{ctx: ctx, summary: summary} do
    DeliverySpeed.observations(["start_to_merge"], @window, ctx)
    File.write!(summary, "\n", [:append])
    DeliverySpeed.observations(["start_to_merge"], @window, ctx)
    assert_received {:opened_summary, ^summary}
    assert_received {:opened_summary, ^summary}
    refute_received {:opened_summary, _path}
  end

  test "truncated history reports its neutral reason and no observations", %{ctx: ctx} do
    opts = Keyword.put(ctx.telemetry_reader_options, :max_records, 1)
    ctx = Map.put(ctx, :telemetry_reader_options, opts)
    assert {%{state: :unavailable, reason: :truncated}, []} = DeliverySpeed.observations(["start_to_merge"], @window, ctx)["start_to_merge"]
  end
end
