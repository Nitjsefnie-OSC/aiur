defmodule Aiur.MainWatch.FixerTest do
  use Aiur.TestSupport
  alias Aiur.CI.FailureDigest
  alias Aiur.GitHub.MainFixer
  alias Aiur.MainWatch.Fixer

  @watch %{on_red: "dispatch_fixer", fixer_label: "main-fix"}
  @sha String.duplicate("a", 40)
  @signature String.duplicate("b", 64)

  setup do
    store = start_supervised!({Agent, fn -> %{issues: [], comments: [], receipts: %{}, alerts: []} end})

    opts = [
      fixer_app?: true,
      fixer_refresh: fn ->
        send(self(), :refresh_requested)
        :ok
      end,
      fixer_open: fn _, _ -> {:ok, Agent.get(store, & &1.issues)} end,
      fixer_create: fn body, _ ->
        body = Map.update!(body, "labels", &Enum.map(&1, fn name -> %{"name" => name} end))
        issue = Map.merge(body, %{"number" => Agent.get(store, &(length(&1.issues) + 1)), "created_at" => "2026-01-01T00:00:00Z"})
        Agent.update(store, &%{&1 | issues: &1.issues ++ [issue]})
        {:ok, issue}
      end,
      fixer_comment: fn id, body, _ -> Agent.update(store, &%{&1 | comments: &1.comments ++ [{id, body}]}) end,
      fixer_pr_open?: fn _, _ -> {:ok, true} end,
      fixer_alert: fn topic, payload -> Agent.update(store, &%{&1 | alerts: &1.alerts ++ [{topic, payload}]}) end,
      fixer_read: fn key -> Agent.get(store, &Map.get(&1.receipts, key, :miss)) end,
      fixer_write: fn key -> Agent.update(store, &%{&1 | receipts: Map.put(&1.receipts, key, {:ok, %{data: %{"done" => true}}})}) end,
      fixer_snapshot: fn -> %{running: [], idle: []} end,
      now_fun: fn -> 0 end
    ]

    %{store: store, opts: opts}
  end

  test "first red files the labelled ticket and repeat runs comment once", %{store: store, opts: opts} do
    red = observation()
    assert :ok = Fixer.reconcile([red], @watch, opts)
    assert_received :refresh_requested
    [issue] = Agent.get(store, & &1.issues)
    assert Enum.map(issue["labels"], & &1["name"]) == ["agent:todo", "priority:1", "complexity:1", "main-fix"]
    assert MainFixer.marker(issue["body"]) == {@signature, @sha}
    assert issue["body"] =~ "new_failure"
    assert issue["body"] =~ "mix test test/example_test.exs"
    assert issue["body"] =~ "early: true"
    assert issue["body"] =~ "Last green: green"
    assert issue["body"] =~ "This PR waits for full CI"
    assert :ok = Fixer.reconcile([red], @watch, opts)
    assert Agent.get(store, & &1.comments) == []
    red = %{red | run_urls: ["https://github.com/run/2"]}
    assert :ok = Fixer.reconcile([red], @watch, opts)
    assert :ok = Fixer.reconcile([red], @watch, opts)
    assert [{"1", body}] = Agent.get(store, & &1.comments)
    assert body =~ "https://github.com/run/2"
    assert length(Agent.get(store, & &1.issues)) == 1
  end

  test "overlap comments while disjoint tests file a second issue", %{store: store, opts: opts} do
    red = observation()
    :ok = Fixer.reconcile([red], @watch, opts)
    changed = %{red | digest: %{red.digest | signature: String.duplicate("c", 64)}}
    :ok = Fixer.reconcile([changed], @watch, opts)
    assert length(Agent.get(store, & &1.issues)) == 1
    assert [{"1", _}] = Agent.get(store, & &1.comments)
    changed = %{changed | digest: %{changed.digest | signature: String.duplicate("d", 64), tests: [%{identity: "Other :: failure", classification: :new_failure, path: "test/other.exs"}]}}
    :ok = Fixer.reconcile([changed], @watch, opts)
    assert length(Agent.get(store, & &1.issues)) == 2
  end

  test "PAT requires triage and failed writes can retry", %{store: store, opts: opts} do
    failing = Keyword.put(opts, :fixer_create, fn _, _ -> {:error, {:http, 422}} end)
    assert {:error, {:http, 422}} = Fixer.reconcile([observation()], @watch, failing)
    assert Agent.get(store, & &1.issues) == []
    assert [{"system.main.fixer.failed", %{reason: reason}}] = Agent.get(store, & &1.alerts)
    assert reason =~ "422"
    assert :ok = Fixer.reconcile([observation()], @watch, Keyword.put(opts, :fixer_app?, false))
    [issue] = Agent.get(store, & &1.issues)
    assert "needs-triage" in Enum.map(issue["labels"], & &1["name"])
    refute "agent:todo" in Enum.map(issue["labels"], & &1["name"])
    assert Enum.any?(Agent.get(store, & &1.alerts), fn {topic, payload} -> topic == "system.main.fixer.needs_triage" and payload.issue == 1 end)
  end

  test "recovery comments without closing and missing PR raises attention", %{store: store, opts: opts} do
    red = observation()
    :ok = Fixer.reconcile([red], @watch, opts)
    green = %{red | sha: String.duplicate("d", 40), checks: [%{name: "test", conclusion: "success"}]}
    opts = Keyword.put(opts, :fixer_recovered?, true)
    assert :ok = Fixer.reconcile([green], @watch, opts)
    assert [{"1", body}] = Agent.get(store, & &1.comments)
    assert body =~ "main is green at #{green.sha}"
    assert length(Agent.get(store, & &1.issues)) == 1
    assert Agent.get(store, & &1.alerts) == []
    assert :ok = Fixer.reconcile([%{green | sha: String.duplicate("e", 40)}], @watch, opts)
    assert length(Agent.get(store, & &1.comments)) == 1
    :ok = Fixer.reconcile([%{red | digest: %{red.digest | signature: String.duplicate("f", 64), tests: [%{identity: "Other :: failure", classification: :new_failure}]}}], @watch, opts)
    assert :ok = Fixer.reconcile([green], @watch, Keyword.put(opts, :fixer_pr_open?, fn _, _ -> {:ok, false} end))
    assert [{"system.main.fixer.no_pr", %{issue: "2", sha: sha}}] = Agent.get(store, & &1.alerts)
    assert sha == green.sha
  end

  test "alert mode and proven flakes never file a fixer", %{store: store, opts: opts} do
    assert :ok = Fixer.reconcile([observation()], %{on_red: "alert"}, opts)
    red = observation()
    flake = %{red.digest | flake_only: true, tests: Enum.map(red.digest.tests, &Map.put(&1, :classification, :known_flake))}
    assert :ok = Fixer.reconcile([%{red | digest: flake}], @watch, opts)
    assert Agent.get(store, & &1.issues) == []
  end

  test "watchdog reports load hold once at five minutes and leaves running fixer alone", %{store: store, opts: opts} do
    :ok = Fixer.reconcile([observation()], @watch, opts)
    now = DateTime.to_unix(~U[2026-01-01 00:05:00Z], :millisecond)
    opts = Keyword.put(opts, :fixer_snapshot, fn -> %{capacity_hold: %{held?: true, signal: :load}, running: []} end)
    assert :ok = Fixer.reconcile([observation()], @watch, Keyword.put(opts, :now_fun, fn -> now - 1 end))
    assert Agent.get(store, & &1.alerts) == []
    running = Keyword.put(opts, :fixer_snapshot, fn -> %{running: [%{issue_id: "1", work_state: :working}]} end)
    assert :ok = Fixer.reconcile([observation()], @watch, Keyword.put(running, :now_fun, fn -> now end))
    assert Agent.get(store, & &1.alerts) == []
    opts = Keyword.put(opts, :now_fun, fn -> now end)
    assert :ok = Fixer.reconcile([observation()], @watch, opts)
    assert :ok = Fixer.reconcile([observation()], @watch, opts)
    assert [{"system.main.fixer.stalled", %{issue: "1", reason: :load}}] = Agent.get(store, & &1.alerts)
  end

  test "unknown test evidence cannot prove a second failure disjoint", %{store: store, opts: opts} do
    red = observation()
    unknown = %{red | digest: %{red.digest | tests: :unknown}}
    assert :ok = Fixer.reconcile([unknown], @watch, opts)
    known = %{red | digest: %{red.digest | signature: String.duplicate("c", 64)}}
    assert :ok = Fixer.reconcile([known], @watch, opts)
    assert :ok = Fixer.reconcile([%{unknown | digest: %{unknown.digest | signature: String.duplicate("d", 64)}}], @watch, opts)
    assert length(Agent.get(store, & &1.issues)) == 1
    assert length(Agent.get(store, & &1.comments)) == 2
  end

  test "dispatch watchdog does not call a fixer stalled while its PR awaits CI", %{store: store, opts: opts} do
    :ok = Fixer.reconcile([observation()], @watch, opts)

    Agent.update(store, fn state ->
      issues = Enum.map(state.issues, &Map.put(&1, "labels", [%{"name" => "agent:ci-wait"}, %{"name" => "main-fix"}]))
      %{state | issues: issues}
    end)

    opts = Keyword.put(opts, :now_fun, fn -> DateTime.to_unix(~U[2026-01-01 00:10:00Z], :millisecond) end)
    assert :ok = Fixer.reconcile([observation()], @watch, opts)
    assert Agent.get(store, & &1.alerts) == []
  end

  defp observation do
    %{
      sha: @sha,
      last_green_sha: "green",
      run_urls: ["https://github.com/run/1"],
      checks: [%{name: "test", conclusion: "failure"}],
      digest: %FailureDigest{signature: @signature, tests: [%{identity: "Example :: failure", classification: :new_failure, path: "test/example_test.exs"}]},
      suspect_merges: [%{number: 42, early: true}]
    }
  end
end
