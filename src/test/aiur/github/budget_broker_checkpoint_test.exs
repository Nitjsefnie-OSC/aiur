defmodule Aiur.GitHub.BudgetBrokerCheckpointTest do
  use ExUnit.Case, async: false

  test "a dead checkpoint worker triggers the in-request WAL fallback" do
    root = Aiur.TestSupport.tmp_root!("budget-broker-checkpoint")
    File.mkdir_p!(root)
    on_exit(fn -> Aiur.TestCleanup.rm_rf!(root) end)

    script = """
    import importlib.util, sqlite3, sys
    spec = importlib.util.spec_from_file_location("metrics", sys.argv[1])
    metrics = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(metrics)
    db = sys.argv[2]
    conn = sqlite3.connect(db, isolation_level=None)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("CREATE TABLE values_table(value)")
    conn.execute("INSERT INTO values_table VALUES (1)")
    metrics.CHECKPOINT_THREAD = None
    metrics.CHECKPOINT_REQUESTS = __import__("queue").Queue(maxsize=1)
    metrics.CHECKPOINT_REQUESTS.put(db)
    status = metrics.recover_checkpoint_if_needed(db, conn)
    assert metrics.LAST_SUCCESSFUL_CHECKPOINT_NS is not None
    assert conn.execute("PRAGMA wal_checkpoint(PASSIVE)").fetchone()[2] >= 2
    conn.close()
    """

    metrics = Path.expand("../../../priv/github_budget_metrics.py", __DIR__)
    db = Path.join(root, "fallback.sqlite3")
    assert {output, 0} = System.cmd("python3", ["-c", script, metrics, db], stderr_to_stdout: true)
    assert output =~ "fallback checkpoint ran"
  end
end
