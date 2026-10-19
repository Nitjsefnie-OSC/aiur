defmodule Aiur.GitHub.BudgetPriorityTest do
  use ExUnit.Case, async: false

  alias Aiur.GitHub.Budget

  setup do
    root = Aiur.TestSupport.tmp_root!("github-budget-priority")
    File.mkdir_p!(root)
    previous = Application.get_env(:aiur, :github_budget_enabled?)
    Application.put_env(:aiur, :github_budget_enabled?, true)

    on_exit(fn ->
      Aiur.TestCleanup.rm_rf!(root)
      restore_env(previous)
    end)

    %{root: root}
  end

  test "main-watch admission uses reserved global and endpoint capacity", %{root: root} do
    opts = [state_dir: root, max_inflight: 2, max_inflight_per_endpoint: 2, requests_per_minute: 20, stagger_ms: 0, timeout_ms: 1_000]
    ordinary = request("shared-token", "/repos/owner/repo/issues/1477")
    main_watch = Map.put(request("shared-token", "/repos/owner/repo/issues/1478"), :priority, :main_watch)

    assert {:ok, ordinary_lease} = Budget.acquire(ordinary, opts)
    assert {:ok, watcher_lease} = Budget.acquire(main_watch, opts)
    assert %{inflight: %{"issues" => 2}} = Budget.snapshot("shared-token", opts)

    assert :ok = Budget.release(watcher_lease, opts)
    assert :ok = Budget.release(ordinary_lease, opts)
  end

  defp request(token, path), do: %{method: :get, url: "https://api.github.com#{path}", token: token}

  defp restore_env(nil), do: Application.delete_env(:aiur, :github_budget_enabled?)
  defp restore_env(value), do: Application.put_env(:aiur, :github_budget_enabled?, value)
end
