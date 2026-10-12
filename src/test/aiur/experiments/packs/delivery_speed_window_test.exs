defmodule Aiur.Experiments.Packs.DeliverySpeedWindowTest do
  use ExUnit.Case, async: true
  alias Aiur.Experiments.Packs.DeliverySpeed.{BootWindow, TelemetrySource}
  alias Aiur.RunTelemetry.Summaries

  test "window loads earlier and overlapping summaries once, without reading future or current boots" do
    root = Path.join(System.tmp_dir!(), "delivery-window-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> Aiur.TestCleanup.rm_rf!(root) end)
    times = %{"old" => "2026-10-08T10:00:00Z", "inside" => "2026-10-09T10:00:00Z", "future" => "2026-10-09T12:00:00Z"}

    for {boot, at} <- times do
      body = %{
        records: [
          %{
            kind: "restart",
            boot_id: boot,
            timestamp: at,
            timestamp_iso: at,
            timestamp_ms: DateTime.to_unix(DateTime.from_iso8601(at) |> elem(1), :millisecond),
            schema_version: 3,
            sequence: 1,
            record_id: boot <> ":1",
            attributes: %{event: "daemon_restart"}
          }
        ]
      }

      File.write!(Path.join(root, boot), Jason.encode!(body))
    end

    path = &Path.join(root, &1)

    ctx = %{
      telemetry_enabled: true,
      boot_id: "current",
      telemetry_path: Path.join(root, "missing"),
      summary_boot_ids: fn -> ["old", "inside", "future", "current"] end,
      summary_path: path,
      summary_reader: fn boot ->
        send(self(), {:summary_loaded, boot})
        Summaries.decode_summary(File.read!(path.(boot)))
      end
    }

    window = %{start: ~U[2026-10-09 09:00:00Z], end: ~U[2026-10-09 11:00:00Z]}
    assert {:ok, data} = TelemetrySource.load(window, ctx)
    assert data.earliest_at == ~U[2026-10-08 10:00:00Z]
    assert_received {:summary_loaded, "old"}
    assert_received {:summary_loaded, "inside"}
    refute_received {:summary_loaded, _boot}
  end

  test "unknown prefix bounds keep a summary rather than guessing it lies outside the window" do
    root = Path.join(System.tmp_dir!(), "delivery-bound-#{System.unique_integer([:positive])}")
    File.write!(root, "{")
    on_exit(fn -> File.rm!(root) end)
    assert BootWindow.before_end?(root, "legacy", ~U[2026-10-09 11:00:00Z])
  end
end
