defmodule Aiur.GitHub.ReadCacheRequiredChecksTest do
  use ExUnit.Case, async: false

  alias Aiur.GitHub.{ReadCache, ReadCache.Metrics, ReadCache.Policy}

  setup do
    await_read_cache()
    ReadCache.reset()
    on_exit(&ReadCache.reset/0)
    :ok
  end

  test "required-check configuration is a repository-config read" do
    request = rest("https://api.github.com/repos/aiur-team/aiur/branches/main/protection")

    assert {:cache, :repo_config, 300_000} = Policy.classify(request)
  end

  test "caches an unprotected branch response" do
    request = rest("https://api.github.com/repos/aiur-team/aiur/branches/main/protection")
    response = {:ok, %{status: 404, body: %{"message" => "Not Found"}}}

    assert ^response = ReadCache.through(request, fn -> response end)
    assert ^response = ReadCache.through(request, fn -> flunk("cached 404") end)
    assert %{hit: 1, miss: 1, deposit: 1} = Metrics.snapshot().callers["ci_required_checks"]
  end

  defp rest(url), do: %{method: :get, url: url, caller: "ci_required_checks"}

  defp await_read_cache(attempts \\ 100)

  defp await_read_cache(attempts) do
    cond do
      ReadCache.snapshot().available? -> :ok
      attempts > 0 -> Process.sleep(10) || await_read_cache(attempts - 1)
      true -> start_supervised!({ReadCache, sweep_interval_ms: 0})
    end
  end
end
