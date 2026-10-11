defmodule Aiur.Orchestrator.OptimisticLedgerTest do
  use Aiur.TestSupport
  alias Aiur.Orchestrator.{MembershipLifecycle, OptimisticLedger}
  alias Aiur.JsonStore

  setup do
    :ok = Supervisor.terminate_child(Aiur.Supervisor, OptimisticLedger)
    on_exit(fn -> Supervisor.restart_child(Aiur.Supervisor, OptimisticLedger) end)
    path = Path.join(System.tmp_dir!(), "optimistic-ledger-#{System.unique_integer([:positive])}/starts.json")
    on_exit(fn -> File.rm_rf(Path.dirname(path)) end)
    {:ok, path: path}
  end

  defp start(path, opts \\ []), do: start_supervised!({OptimisticLedger, [path: path] ++ opts})

  defp attrs(attempt \\ "attempt", at \\ 100) do
    %{attempt_id: attempt, start_trigger: :pr_opened, started_at_ms: at, blockers: [%{"id" => "12", "pr_number" => 30, "pr_head_sha_at_start" => "original", "pr_state" => "open"}]}
  end

  test "starts, updates and counters survive process restart without losing attempts", %{path: path} do
    start(path)
    assert :ok = OptimisticLedger.record_start("10", attrs())
    assert OptimisticLedger.get("10")["counters"]["parks"] == 0
    assert :ok = OptimisticLedger.update_blocker("10", "12", %{last_head_sha: "new", pr_head_sha_at_start: "overwrite"})
    assert :ok = OptimisticLedger.bump("10", :parks, 1)
    assert :ok = OptimisticLedger.set_status("10", :parked, 200)
    assert :ok = OptimisticLedger.record_start("10", attrs("retry", 300))
    assert :ok = OptimisticLedger.record_start("11", attrs("other", 300))
    assert :ok = OptimisticLedger.bump("10", :parks, 2)
    stop_supervised!(OptimisticLedger)
    start(path)
    assert length(OptimisticLedger.open_records()) == 3
    assert Enum.sort(Enum.map(OptimisticLedger.by_blocker("12"), & &1["attempt_id"])) == ["attempt", "other", "retry"]
    assert OptimisticLedger.get("10")["attempt_id"] == "retry"
    assert OptimisticLedger.get("10")["counters"]["parks"] == 2
    assert {:ok, stored} = JsonStore.read(path)
    old = stored["records"]["attempt"]
    assert old["status"] == "parked"
    assert old["counters"]["parks"] == 1
    assert hd(old["blockers"])["last_head_sha"] == "new"
    assert hd(old["blockers"])["pr_head_sha_at_start"] == "original"
  end

  test "close selects merged_after_redo and removes closed attempts from blocker reads", %{path: path} do
    start(path)
    OptimisticLedger.record_start("10", attrs())
    OptimisticLedger.record_start("11", attrs("other"))
    OptimisticLedger.bump("10", :parks, 1)
    assert :ok = OptimisticLedger.close("10", :merged, 500)
    assert :ok = OptimisticLedger.bump("10", :parks, 1)
    assert :ok = OptimisticLedger.set_status("absent", :parked, 600)
    assert OptimisticLedger.get("10")["outcome"] == "merged_after_redo"
    assert OptimisticLedger.get("10")["closed_at_ms"] == 500
    assert Enum.map(OptimisticLedger.by_blocker("12"), & &1["ticket"]) == ["11"]
    assert :ok = OptimisticLedger.close("11", :merged, 501)
    assert OptimisticLedger.get("11")["outcome"] == "merged"
    assert :ok = OptimisticLedger.close("absent", :merged, 501)
    assert OptimisticLedger.get("absent") == nil
  end

  test "terminal membership observation discards an idle dependent", %{path: path} do
    start(path)
    OptimisticLedger.record_start("10", attrs())
    assert :ok = MembershipLifecycle.record(%Issue{id: "10", identifier: "10", state: "not_planned"}, :completed)
    assert OptimisticLedger.get("10")["status"] == "closed"
    assert OptimisticLedger.get("10")["outcome"] == "discarded"
  end

  test "title-case terminal tracker states close records but active observations do not", %{path: path} do
    start(path)
    OptimisticLedger.record_start("10", attrs())
    assert :ok = MembershipLifecycle.record(%Issue{identifier: "10", state: "In Progress"}, :completed)
    assert OptimisticLedger.get("10")["status"] == "running"
    assert :ok = MembershipLifecycle.record(%Issue{identifier: "10", state: "Cancelled"}, :cancelled)
    assert OptimisticLedger.get("10")["outcome"] == "discarded"
  end

  test "a late confirmed merge corrects discard without later terminal observations undoing it", %{path: path} do
    start(path)
    OptimisticLedger.record_start("10", attrs())
    OptimisticLedger.close("10", :discarded, 500)
    OptimisticLedger.close("10", :merged, 501)
    OptimisticLedger.close_observed(%Issue{identifier: "10", state: "closed"})
    assert OptimisticLedger.get("10")["outcome"] == "merged"
  end

  test "boot prunes only known closed records older than fourteen days", %{path: path} do
    now = 20 * 86_400_000
    start(path)

    for {ticket, days} <- [{"old", 15}, {"recent", 13}] do
      OptimisticLedger.record_start(ticket, attrs(ticket))
      OptimisticLedger.close(ticket, :discarded, now - days * 86_400_000)
    end

    OptimisticLedger.record_start("open", attrs("open"))
    stop_supervised!(OptimisticLedger)
    start(path, now_ms: now)
    assert OptimisticLedger.get("old") == nil
    assert OptimisticLedger.get("recent")["outcome"] == "discarded"
    assert OptimisticLedger.get("open")["status"] == "running"
    assert {:ok, stored} = JsonStore.read(path)
    refute Map.has_key?(stored["records"], "old")
  end

  test "corrupt store refuses writes and alerts once across ledger restarts", %{path: path} do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "broken")
    parent = self()
    alert = fn name, opts -> send(parent, {:alerted, name, opts}) end
    start(path, alert: alert)
    assert_received {:alerted, "system.optimistic.ledger_unavailable", _}
    assert {:error, :ledger_unavailable} = OptimisticLedger.record_start("10", attrs())
    assert OptimisticLedger.open_records() == []
    stop_supervised!(OptimisticLedger)
    start(path, alert: alert)
    refute_received {:alerted, "system.optimistic.ledger_unavailable", _}
    assert File.read!(path) == "broken"
  end

  test "write failure preserves the last durable snapshot and refuses subsequent writes", %{path: path} do
    start(path, alert: fn _, _ -> :ok end)
    OptimisticLedger.record_start("10", attrs())
    File.rm!(path)
    File.mkdir!(path)
    assert {:error, :ledger_unavailable} = OptimisticLedger.bump("10", :parks, 1)
    assert OptimisticLedger.get("10")["counters"]["parks"] == 0
    assert {:error, :ledger_unavailable} = OptimisticLedger.record_start("11", attrs("other"))
  end

  test "unknown document versions are read-only and never pruned", %{path: path} do
    document = %{"v" => 2, "records" => %{"future" => %{"v" => 2, "unknown" => true}}}
    JsonStore.write!(path, document)
    start(path)
    assert {:error, :ledger_unavailable} = OptimisticLedger.record_start("10", attrs())
    assert {:ok, ^document} = JsonStore.read(path)
  end

  test "unknown record versions are preserved while supported records remain writable", %{path: path} do
    future = %{"v" => 2, "status" => "closed", "closed_at_ms" => 0}
    JsonStore.write!(path, %{"v" => 1, "records" => %{"future" => future}})
    start(path)
    assert :ok = OptimisticLedger.record_start("10", attrs())
    assert {:ok, stored} = JsonStore.read(path)
    assert stored["records"]["future"] == future
    assert OptimisticLedger.get("10")["attempt_id"] == "attempt"
  end

  test "valid JSON with invalid record fields fails closed", %{path: path} do
    JsonStore.write!(path, %{"v" => 1, "records" => %{"bad" => %{"v" => 1, "ticket" => "10"}}})
    before = File.read!(path)
    start(path, alert: fn _, _ -> :ok end)
    assert {:error, :ledger_unavailable} = OptimisticLedger.record_start("10", attrs())
    assert File.read!(path) == before
  end
end
